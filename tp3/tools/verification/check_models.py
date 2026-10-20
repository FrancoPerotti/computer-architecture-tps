"""Estímulos dirigidos; solo biblioteca estándar. Ejecutar desde cualquier cwd."""

import copy
from fractions import Fraction
import json
from pathlib import Path
import re
import unittest

from controller_model import ControllerModel, Events, GLOBAL_STATES, PROFILES, Response, STATES, TIMER_LIMIT
from pc_recovery_model import RecoveryModel, silence_ms


ROOT = Path(__file__).resolve().parents[2]
CATALOG = json.loads((ROOT / "docs/verification/cases.json").read_text())
GROUPS = {g["id"]: g for g in CATALOG["groups"]}
WITNESSES = {}
GLOBAL_SEEN = {profile: set() for profile in PROFILES}


class ObservedModel(ControllerModel):
    def tick(self, e=Events()):
        WITNESSES.setdefault((self.profile, self.state), copy.deepcopy(self))
        result = super().tick(e)
        WITNESSES.setdefault((self.profile, self.state), copy.deepcopy(self))
        GLOBAL_SEEN[self.profile].update(self.global_visited)
        return result


def fixture(profile, global_state="READY"):
    m = ObservedModel(profile)
    m.global_state = global_state
    m.image_size = 0 if global_state in {"NO_IMAGE", "LOADING"} else 16
    if global_state in {"RUNNING", "HALT_DRAIN_AUTO", "FAULT_DRAIN_AUTO"}:
        m.state, m.owed = "WAIT_RUN_END", True
    return m


def byte(m, value, **events):
    return m.tick(Events(rx=value, activity=True, **events))


def header(m, size):
    byte(m, 1)
    result = None
    for b in size.to_bytes(5, "little"):
        result = byte(m, b)
    return result


def content(m, size, data=None):
    header(m, size)
    m.tick(Events(done=True))
    for i in range(size):
        result = byte(m, data[i] if data is not None else i & 255)
    return result


class CatalogChecks(unittest.TestCase):
    """Integridad y referencias del catálogo; no ejecución de sus casos RTL."""

    def test_ids_counts_and_reuse(self):
        groups = CATALOG["groups"]
        self.assertEqual(len(GROUPS), len(groups))
        cases = [c for g in groups for c in g["cases"]]
        ids = {c["id"] for c in cases}
        self.assertEqual(len(ids), len(cases))
        replays = []
        for g in groups:
            with self.subTest(group=g["id"]):
                self.assertEqual(g["case_count"], len(g["cases"]))
                self.assertEqual(len(g["reuse_groups"]), len(set(g["reuse_groups"])))
                self.assertTrue(set(g["reuse_groups"]) <= GROUPS.keys())
                for c in g["cases"]:
                    self.assertRegex(c["id"], re.escape(g["id"]) + r"/C[0-9]{3}$")
                    self.assertIsInstance(c["inputs"], dict)
                    self.assertTrue(c["expected"])
                    self.assertTrue(c["kind"])
                    self.assertTrue(c["origins"])
                    self.assertTrue(all(isinstance(x, str) and x for x in c["origins"]))
                replay = g.get("replay_cases", [])
                self.assertEqual(len(replay), len(set(replay)))
                self.assertTrue(set(replay) <= ids)
                replays.extend(replay)
        for reference in re.findall(r"TEST-[A-Z]+-[0-9]+/C[0-9]+", json.dumps(CATALOG)):
            self.assertIn(reference, ids)

        def visit(group, ancestors=()):
            self.assertNotIn(group, ancestors, "Ciclo de reutilización")
            for reused in GROUPS[group]["reuse_groups"]:
                visit(reused, ancestors + (group,))

        for group in GROUPS:
            visit(group)
        plan = (ROOT / "docs/verification/verification_plan.md").read_text()
        self.assertIn(f"{len(cases)} variantes canónicas en {len(groups)} grupos", plan)
        self.assertIn(f"Las {len(replays)} reejecuciones de placa", plan)

    def test_sources_requirements_and_contracts(self):
        documents = {}

        def read(path):
            if path not in documents:
                text = path.read_text()
                headings = re.findall(r"^#+ (.+)$", text, re.M)
                anchors = {re.sub(r"[^\w\s-]", "", h.strip().lower()).replace(" ", "-")
                           for h in headings}
                anchors.update(re.findall(r'<a\s+id="([^"]+)"', text))
                documents[path] = text, anchors
            return documents[path]

        def resolve(link):
            filename, _, anchor = link.partition("#")
            path = ROOT / "docs/verification" / filename
            self.assertTrue(path.is_file(), link)
            text, anchors = read(path.resolve())
            self.assertIn(anchor, anchors, link)
            return text

        requirement_ids = set(re.findall(r"REQ-[A-Z]+-[0-9]+",
                                         (ROOT / "docs/requirements.md").read_text()))
        for g in GROUPS.values():
            with self.subTest(group=g["id"]):
                text = resolve(g["source"])
                anchor = g["source"].split("#")[1]
                section = text.split(f'<a id="{anchor}"></a>', 1)[1].split('<a id=', 1)[0]
                self.assertRegex(section, r"\*\*Tipo de estímulo:\*\* .+")
                for field in ("Requisitos", "Contratos"):
                    line = re.search(r"\*\*" + field + r":\*\* (.+)", section)
                    self.assertIsNotNone(line, field)
                    links = re.findall(r"\[([^]]+)\]\(([^)]+)\)", line[1])
                    self.assertTrue(links, field)
                    for label, link in links:
                        # Los contratos pueden enlazar al documento completo.
                        resolve(link) if "#" in link else read((ROOT / "docs/verification" / link).resolve())
                        if field == "Requisitos":
                            self.assertIn(label, requirement_ids)
                count = re.search(r"prueba tiene ([0-9]+) casos canónicos", section)
                if count:
                    self.assertEqual(int(count[1]), g["case_count"])


class ControllerChecks(unittest.TestCase):
    def test_commands_from_manifest(self):
        """TEST-UART-003: fase UART, aceptación, bytes LOAD y eco."""
        for profile in PROFILES:
            for case in GROUPS["TEST-UART-003"]["cases"]:
                with self.subTest(profile=profile, case=case["id"]):
                    i, expected = case["inputs"], case["expected"]
                    m = fixture(profile, i["state"])
                    m.state = i["transport_phase"]
                    if m.state == "RECEIVE_LOAD_SIZE":
                        m.index = 1
                    elif m.state == "RECEIVE_LOAD_DATA":
                        m.size, m.remaining = 8, i["remaining_bytes"]
                    data = bytes.fromhex(i["LOAD_header"]) if "LOAD_header" in i else [i.get("opcode", i.get("byte"))]
                    outputs = [byte(m, b) for b in data]
                    if i["transport_phase"] == "WAIT_RUN_END":
                        self.assertTrue(all(o["request"] is None for o in outputs))
                        self.assertEqual(m.state, "RECOVER_RX")
                        self.assertFalse(any(r.opcode in (1, 4, 5) for _, r in m.captures))
                        self.assertEqual(m.image_size, 16)
                    elif "opcode" in i:
                        if m.state == "WAIT_STEP_END":
                            o = m.tick(Events(prepare_done=True))
                            self.assertTrue(o["fire"])
                        wanted = expected["response"]
                        pair = tuple(wanted) if isinstance(wanted, list) else tuple(
                            int(x, 16) for x in wanted[:5].split())
                        self.assertEqual((m.response.opcode, m.response.result), pair)
                    else:
                        self.assertIsNone(outputs[0]["request"])
                        self.assertEqual(outputs[0]["delivery"], m.state == "RECEIVE_LOAD_DATA")

    def test_all_opcodes(self):
        for profile in PROFILES:
            for opcode in range(256):
                m = fixture(profile)
                o = byte(m, opcode)
                self.assertEqual(o["request"], opcode if opcode in (2, 3) else None)
                if opcode not in range(1, 6):
                    self.assertEqual(m.response, Response(opcode, 12))
                elif opcode == 1:
                    self.assertEqual(m.state, "RECEIVE_LOAD_SIZE")
                    self.assertFalse(m.busy)

    def test_load_from_manifest(self):
        """TEST-UART-004: quinto byte, escritura final y publicación."""
        for case in GROUPS["TEST-UART-004"]["cases"]:
            i = case["inputs"]
            with self.subTest(case=case["id"]):
                m = fixture(i["profile"])
                size = i.get("N40", i.get("N"))
                if "N40" in i:
                    o = header(m, size)
                    self.assertIsNone(o["request"])
                    self.assertEqual(m.response, Response(1, 6))
                    self.assertEqual(m.image_size, 16)
                    m.tick(Events(done=True))
                    self.assertEqual(m.state, "WAIT_COMMAND")
                    continue
                data = bytes(size) if i.get("content_word") == 0 else bytes(x & 255 for x in range(size))
                o = content(m, size, data)
                self.assertTrue(o["delivery"] and o["load_ok"])
                self.assertEqual(m.remaining, 0)
                self.assertEqual(m.state, "WAIT_PREP_DONE")
                self.assertTrue(m.prepare_active)
                for index in range(size // 4):
                    self.assertEqual(m.imem[index], int.from_bytes(data[4*index:4*index+4], "little"))
                o = m.tick(Events(prepare_done=True))
                publication = m.edge
                self.assertTrue(o["publish"])
                self.assertIsNone(o["response"])
                self.assertFalse(o["fire"])
                self.assertEqual(m.image_size, size)
                m.tick()
                self.assertEqual(m.captures[-1], (publication + 1, Response(1, 2)))
                m.tick(Events(done=True))
                self.assertEqual(m.state, "WAIT_COMMAND")

    def test_timeout_from_manifest(self):
        """TEST-UART-005: error > byte > timeout; límites precargados."""
        for profile in PROFILES:
            for case in GROUPS["TEST-UART-005"]["cases"]:
                i, expected = case["inputs"], case["expected"]
                with self.subTest(profile=profile, case=case["id"]):
                    m = fixture(profile)
                    byte(m, 1)
                    size_phase = i["phase"] == "RECEIVE_LOAD_SIZE"
                    prefix = 4 if i.get("byte_completes_phase") else i.get("received_bytes", 2)
                    for b in (8).to_bytes(5, "little")[:prefix if size_phase else 5]:
                        byte(m, b)
                    if not size_phase:
                        m.tick(Events(done=True))
                        for n in range(i.get("content_offset", i.get("received_bytes", 0))):
                            byte(m, n)
                    before = dict(m.imem)
                    m.timer = TIMER_LIMIT - (i.get("valid_byte_event") == "T-1")
                    events = i.get("events", "byte" if "valid_byte_event" in i else "timeout")
                    o = m.tick(Events(rx=0 if "byte" in events else None,
                                      error="error" in events, activity=True))
                    if expected.get("winner") == "error" or "T_clocks" in i:
                        self.assertEqual(m.state, "RECOVER_RX")
                        self.assertEqual(m.response.result, 9 if "error" in events else 7 if size_phase else 8)
                        self.assertFalse(o["delivery"])
                        self.assertEqual(m.imem, before)
                    else:
                        self.assertNotEqual(m.state, "RECOVER_RX")
                        if i.get("byte_completes_phase"):
                            self.assertEqual(m.state, "WAIT_LOAD_ACCEPT_SENT" if size_phase else "WAIT_PREP_DONE")
                        else:
                            self.assertEqual(m.timer, 0)

    def test_run_crossings_from_manifest(self):
        """TEST-UART-012: Stop, captura única, recuperación y RESET."""
        for profile in PROFILES:
            for case in GROUPS["TEST-UART-012"]["cases"]:
                i = case["inputs"]
                with self.subTest(profile=profile, case=case["id"]):
                    m = fixture(profile)
                    byte(m, 2)
                    terminal = dict(halt=i["terminal"] == "FINISHED", fault=i["terminal"] == "FAULT")
                    crossing = i["crossing"][0]
                    if crossing == "A":
                        m.tick(Events(**terminal))
                        self.assertTrue(m.debug_select and m.owed)
                        m.tick()
                        self.assertEqual(len(m.captures), 1)
                        m.tick(Events(done=True))
                    elif crossing == "B":
                        m.tick(Events(done=True, **terminal))
                        self.assertEqual(m.state, "WAIT_RUN_END")
                    else:
                        m.tick(Events(done=True))
                        if crossing in "DE":
                            byte(m, 5)
                            self.assertEqual(m.state, "RECOVER_RX")
                        if crossing == "F":
                            byte(m, 4, **terminal)
                            self.assertFalse(m.owed)
                            self.assertEqual(m.response, Response(4, 1))
                            m.tick(Events(done=True))
                            self.assertTrue(m.reset_request)
                            m.tick()
                            self.assertEqual(m.global_state, "NO_IMAGE")
                            self.assertFalse(any(r.debug for _, r in m.captures))
                            continue
                        m.tick(Events(**terminal))
                    stop_edge = m.edge
                    if crossing == "G":
                        byte(m, 4)
                    else:
                        m.tick()
                    self.assertFalse(m.owed)
                    self.assertTrue(m.hold and m.busy)
                    result = Response(2, 10 if i["terminal"] == "FINISHED" else 11, True)
                    self.assertEqual(m.response, result)
                    if crossing in "AB":
                        self.assertEqual(m.captures[-1][0], stop_edge + 1)
                    fires = m.cpu_fires
                    byte(m, 4)  # RESET UART durante Debug se consume sin efecto.
                    self.assertTrue(m.hold and m.busy)
                    self.assertFalse(m.reset_request)
                    self.assertEqual(m.cpu_fires, fires)
                    if crossing == "D":
                        m.timer = TIMER_LIMIT
                        m.tick()
                        self.assertEqual(m.state, "RECOVER_RX")
                    if crossing == "E":
                        m.tick(Events(activity=True))
                    m.tick(Events(done=True))
                    self.assertFalse(m.hold)
                    if crossing in "DE":
                        self.assertEqual(m.state, "RECOVER_RX")
                        m.timer = TIMER_LIMIT
                        m.tick()
                    self.assertEqual(m.state, "WAIT_COMMAND")
                    self.assertEqual(sum(r == result for _, r in m.captures), 1)

    def test_step_preparation_and_drains(self):
        """TEST-UART-010 y TEST-EXEC-007: un ciclo STEP y estados Global."""
        for profile in PROFILES:
            loaded = ObservedModel(profile)
            content(loaded, 4)
            loaded.tick(Events(prepare_done=True))
            for terminal in ("FINISHED", "FAULT"):
                for opcode in (2, 3):
                    m = fixture(profile, terminal)
                    start = m.cpu_fires
                    byte(m, opcode)
                    self.assertEqual(m.cpu_fires, start)
                    if opcode == 2:
                        m.tick(Events(done=True))
                    self.assertTrue(m.prepare_active)
                    o = m.tick(Events(prepare_done=True))
                    self.assertTrue(o["fire"])
                    self.assertEqual(m.cpu_fires, start + 1)
                    if opcode == 3:
                        self.assertEqual(m.response, Response(3, 2, True))
                        self.assertFalse(o["debug_before"])
                        self.assertTrue(m.debug_select)
                        byte(m, 1)
                        self.assertEqual(m.cpu_fires, start + 1)
                        self.assertTrue(m.hold)
            for opcode in (2, 3):
                for fault in (False, True):
                    m = fixture(profile)
                    byte(m, opcode)
                    m.tick(Events(done=True))
                    e = dict(halt=not fault, fault=fault, empty=False)
                    byte(m, 3, **e) if opcode == 3 else m.tick(Events(**e))
                    self.assertIn("DRAIN", m.global_state)
                    if opcode == 3:
                        m.tick(Events(done=True))
                        byte(m, 3)
                    else:
                        m.tick()
                    self.assertEqual(m.global_state, "FAULT" if fault else "FINISHED")
            self.assertEqual(GLOBAL_SEEN[profile], set(GLOBAL_STATES))

    def test_recovery_activity_and_run_return(self):
        """TEST-UART-006: actividad domina R y RUN no se detiene."""
        for profile in PROFILES:
            m = fixture(profile)
            byte(m, 2)
            m.tick(Events(done=True))
            byte(m, 5)
            for e in (Events(activity=True), Events(rx=4, activity=True), Events(error=True, activity=True)):
                m.timer = TIMER_LIMIT
                m.tick(e)
                self.assertEqual((m.state, m.timer), ("RECOVER_RX", 0))
                self.assertEqual(m.global_state, "RUNNING")
            m.timer = TIMER_LIMIT
            m.tick()
            self.assertEqual(m.state, "WAIT_RUN_END")
            self.assertTrue(m.owed)
            self.assertEqual(len(m.captures), 1)

    def test_reset_discard_from_manifest(self):
        """TEST-UART-013/C011–C016: fixtures locales de las ventanas."""
        for profile in PROFILES:
            for case in GROUPS["TEST-UART-013"]["cases"][10:]:
                i = case["inputs"]
                m = fixture(profile, i["state"])
                m.state, m.owed = i["transport_phase"], i["run_result_required"]
                if i["response_busy_before"]:
                    m.response = Response(2 if m.owed else 1, 1)
                o = byte(m, 4)
                self.assertEqual(m.state, i["transport_phase"])
                self.assertIsNone(o["response"])
                self.assertFalse(m.reset_request)

    def test_z_reset_all_phases(self):
        """Reset desde testigos de cada fase; no se fuerza un próximo estado."""
        for profile in PROFILES:
            m = fixture(profile)
            content(m, 4)
            m.tick(Events(prepare_done=True))
            m.tick()
            m.tick(Events(done=True))
            byte(m, 2)
            m.tick(Events(done=True))
            byte(m, 5)
            m.tick(Events(halt=True))
            m.tick()
            m.tick(Events(done=True))
            m.timer = TIMER_LIMIT
            m.tick()
            byte(m, 3)
            m.tick(Events(prepare_done=True))
            m.tick(Events(done=True))
            byte(m, 4)
        self.assertEqual(set(WITNESSES), {(p, s) for p in PROFILES for s in STATES})
        for key, witness in list(WITNESSES.items()):
            with self.subTest(profile=key[0], state=key[1]):
                m = copy.deepcopy(witness)
                m.tick(Events(reset=True))
                self.assertEqual((m.state, m.global_state, m.image_size), ("WAIT_COMMAND", "NO_IMAGE", 0))
                self.assertFalse(m.owed or m.hold or m.busy or m.reset_request)
                self.assertIsNone(m.tick()["response"])


class LinkBudgetChecks(unittest.TestCase):
    """Cotas documentales: no se simulan tramas ni se mide el DUT."""

    CLOCKS_PER_MS = 50_000
    FRAME_CLOCKS = 10 * 16 * 163
    BYTE_CLOCKS = FRAME_CLOCKS + 1 + 2  # Separación y producción.
    SHORT_CLOCKS = 2 * BYTE_CLOCKS + 16

    @staticmethod
    def list_deadline_ms(k):
        return (5 * k * 10 * 1000 + 19199) // 19200 + 200

    def test_budgets_from_manifest(self):
        for case in GROUPS["TEST-UART-014"]["cases"]:
            i, expected = case["inputs"], case["expected"]
            capacity = PROFILES[i["profile"]][1]
            with self.subTest(case=case["id"]):
                if "N" in i:
                    self.assertEqual(expected["prepare_clocks"], capacity + 1)
                    deadline = Fraction(i["N"] * 10 * 1000, 19200) + 201
                    self.assertAlmostEqual(expected["LOAD_done_deadline_ms"], float(deadline))
                elif "request" in i:
                    self.assertEqual(expected["bound_clocks"], self.SHORT_CLOCKS)
                else:
                    k = i["K"]
                    self.assertEqual(expected["response_length"], 230 + 5 * k)
                    self.assertEqual(expected["fixed_bound_clocks"], 230 * self.BYTE_CLOCKS + capacity + 16)
                    self.assertEqual(expected["list_bound_clocks"],
                                     (5 * k + 1) * self.BYTE_CLOCKS + capacity + 16 if k else 0)
                    self.assertEqual(expected["total_bound_clocks"],
                                     (230 + 5 * k) * self.BYTE_CLOCKS + 2 * capacity + 16)

    def test_bounds_fit_protocol_windows(self):
        for profile, (imem, capacity) in PROFILES.items():
            with self.subTest(profile=profile):
                self.assertLess(capacity + 1, self.CLOCKS_PER_MS)
                # CHECK_READY: incluir recepción de la solicitud y consumo RX.
                self.assertLess(self.FRAME_CLOCKS + 1 + self.SHORT_CLOCKS,
                                200 * self.CLOCKS_PER_MS)
                # LOAD: contenido continuo, preparación, DONE y coordinación.
                for n in range(4, imem + 1, 4):
                    bound = n * self.FRAME_CLOCKS + capacity + 1 + self.SHORT_CLOCKS + 16
                    deadline = Fraction(n * 10 * 1000, 19200) + 201
                    self.assertLess(bound, deadline * self.CLOCKS_PER_MS)
                # La cota fija incluye dos bytes de cabecera conservadoramente.
                self.assertLess(230 * self.BYTE_CLOCKS + capacity + 16,
                                319 * self.CLOCKS_PER_MS)
                for k in range(1, capacity + 1):
                    bound = (5 * k + 1) * self.BYTE_CLOCKS + capacity + 16
                    self.assertLess(bound, self.list_deadline_ms(k) * self.CLOCKS_PER_MS)
                maximum_debug = (230 + 5 * capacity) * self.BYTE_CLOCKS + 2 * capacity + 16
                self.assertLess(maximum_debug, silence_ms(profile) * self.CLOCKS_PER_MS)


class RecoveryChecks(unittest.TestCase):
    def query(self, profile):
        m = RecoveryModel(profile, snapshot=b"previous")
        self.assertIsNone(m.advance(m.quiet_ms - 1))
        self.assertEqual(m.advance(m.quiet_ms), 5)
        return m, m.now

    def test_query_fragmentation_and_buffer(self):
        for profile in PROFILES:
            self.assertEqual(silence_ms(profile), 6100 if profile == "REFERENCE" else 3400)
            for result in (3, 4):
                for fragmented in (False, True):
                    m, t = self.query(profile)
                    if fragmented:
                        m.advance(t + 10, b"\x05")
                        self.assertEqual(m.state, "QUERY")
                        m.advance(t + 20, bytes([result, 0xAA]))
                    else:
                        m.advance(t + 20, bytes([5, result, 0xAA]))
                    self.assertEqual(m.state, "QUERY_OK")
                    self.assertEqual(m.trailing, b"\xaa")
                    self.assertFalse(m.reset_used)
                    self.assertEqual(m.snapshot, b"previous")

    def test_silence_processes_pending_bytes_first(self):
        for profile in PROFILES:
            m = RecoveryModel(profile)
            t = m.quiet_ms
            self.assertIsNone(m.advance(t, b"pending"))
            self.assertIsNone(m.advance(2*t - 1))
            self.assertEqual(m.advance(2*t), 5)
            m = RecoveryModel(profile)
            m.advance(20, connected=False)
            m.advance(1000)
            self.assertIsNone(m.advance(1000 + t - 1))
            self.assertEqual(m.advance(1000 + t), 5)

    def test_reset_confirmation_and_single_attempt(self):
        for profile in PROFILES:
            for reply in (b"\x04\x01", b"", b"\x04", b"\x04\x02", b"\xaa\x04\x01", b"\x02\x0a\x04\x01"):
                m, t = self.query(profile)
                self.assertEqual(m.advance(t + 200), 4)
                self.assertTrue(m.reset_used)
                m.advance(t + 210, reply[:1])
                m.advance(t + 220, reply[1:])
                m.advance(t + 400)
                self.assertEqual(m.state, "RESET_CONFIRMED" if reply == b"\x04\x01" else "FAILED")
                m.advance(t + 100000, b"\x04\x01")
                self.assertEqual([op for _, op in m.sent], [5, 4])
            m, t = self.query(profile)
            m.advance(t + 200)
            m.advance(t + 201, connected=False)
            m.advance(t + 100000)
            self.assertEqual(m.state, "FAILED")
            self.assertEqual([op for _, op in m.sent], [5, 4])

    def test_bad_query_requires_second_silence(self):
        for profile in PROFILES:
            for reply in (b"\xaa\x05\x03", b"\x05\xff", b"\x05"):
                m, t = self.query(profile)
                m.advance(t + 10, reply)
                m.advance(t + 200)
                self.assertEqual(m.state, "SILENCE_RESET")
                t = m.since + m.quiet_ms
                self.assertIsNone(m.advance(t, b"\x04\x01"))
                self.assertEqual(m.advance(t + m.quiet_ms), 4)
                m.advance(m.now + 10, b"\x04\x01")
                self.assertEqual(m.state, "RESET_CONFIRMED")
                self.assertEqual([op for _, op in m.sent], [5, 4])

    def test_deadline_and_scope(self):
        for profile in PROFILES:
            m, t = self.query(profile)
            m.advance(t + 200, b"\x05\x03")
            self.assertEqual(m.state, "QUERY_OK")
            m, t = self.query(profile)
            m.advance(t + 201, b"\x05\x03")
            self.assertEqual(m.state, "SILENCE_RESET")
        with self.assertRaises(ValueError):
            RecoveryModel(interrupted=1)

    def test_fpga_nonterminating_run_recovered_by_reset(self):
        for profile in PROFILES:
            fpga = fixture(profile)
            byte(fpga, 2)
            fpga.tick(Events(done=True))
            pc, t = self.query(profile)
            self.assertIsNone(byte(fpga, 5)["response"])
            self.assertEqual(fpga.state, "RECOVER_RX")
            self.assertEqual(pc.advance(t + 200), 4)
            # El timeout de consulta abarca R; saltar solo el contador FPGA.
            fpga.timer = TIMER_LIMIT
            fpga.tick()
            self.assertEqual(fpga.state, "WAIT_RUN_END")
            self.assertEqual(byte(fpga, 4)["response"], Response(4, 1))
            pc.advance(t + 210, b"\x04")
            pc.advance(t + 220, b"\x01")
            fpga.tick(Events(done=True))
            fpga.tick()
            self.assertEqual((pc.state, fpga.global_state), ("RESET_CONFIRMED", "NO_IMAGE"))

    def test_fpga_terminal_wins_recovery_reset(self):
        for profile in PROFILES:
            fpga = fixture(profile)
            byte(fpga, 2)
            fpga.tick(Events(done=True))
            pc, t = self.query(profile)
            byte(fpga, 5)
            fpga.timer = TIMER_LIMIT
            fpga.tick()
            self.assertEqual(pc.advance(t + 200), 4)
            fpga.tick(Events(halt=True))
            self.assertEqual(byte(fpga, 4)["response"], Response(2, 10, True))
            pc.advance(t + 210, b"\x02\x0a\x04\x01")
            pc.advance(t + 100000)
            self.assertEqual(pc.state, "FAILED")
            self.assertEqual([op for _, op in pc.sent], [5, 4])
            self.assertFalse(fpga.reset_request)


if __name__ == "__main__":
    if not __debug__:
        raise SystemExit("Ejecutar sin -O: las invariantes del modelo usan assert.")
    controller_doc = (ROOT / "docs/architecture/debug/protocol_controller.md").read_text()
    documented_states = re.findall(r"^\|\s*`11'b[01]{11}`\s*\|\s*`(\w+)`", controller_doc, re.M)
    if tuple(documented_states) != STATES:
        raise SystemExit("Los estados del modelo no coinciden con la tabla del Controller.")
    global_doc = (ROOT / "docs/architecture/session/execution_control.md").read_text()
    global_states = re.findall(r"^\|\s*`(\w+)`\s*\|\s*[01]\s*\|.*`[01]{8}`\s*\|", global_doc, re.M)
    if tuple(global_states) != GLOBAL_STATES:
        raise SystemExit("Los estados del modelo no coinciden con la tabla Global.")
    unittest.main(verbosity=2)
