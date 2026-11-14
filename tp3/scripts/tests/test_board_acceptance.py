"""Comprobaciones del ejecutor UART de la aceptación física."""

import unittest

from scripts.verification_manifest import index_manifest, read_manifest
from tools.board_acceptance.__main__ import execute
from tools.board_acceptance.fixture import ScriptedPort, frame, smoke_port
from tools.board_acceptance.plans import DMEM, replay_plans, smoke
from tools.board_acceptance.uart import Link, WireError, compare


def link(port):
    """Conecta el puerto de pruebas al reloj virtual."""
    return Link(port, lambda *_: None, now=port.monotonic, pause=port.sleep)


class AcceptanceTests(unittest.TestCase):
    """Regresión de selección, framing y comparación del ejecutor."""

    def test_exact_selection_and_setup(self):
        """Verifica los IDs y la relocación de un JALR dependiente de DMEM."""
        plans = dict(replay_plans())
        self.assertEqual(len(plans), 151)
        self.assertNotIn("TEST-EXEC-004/C006", plans)
        self.assertEqual(
            [case_id for case_id, plan in plans.items() if plan.pending], ["TEST-UART-013/C009"]
        )
        image = plans["TEST-PIPE-005/C008"].images[0]
        self.assertEqual(
            image.block_pc + 8, plans["TEST-PIPE-005/C008"].actions[-1]["expected"]["rf"][1]
        )
        self.assertIn("sw x31,0(x0)", image.setup)

    def test_smoke_exchange_order_and_snapshots(self):
        """Valida el intercambio completo y su orden."""
        port = smoke_port()
        execute(link(port), smoke(), 3)
        port.complete()

    def test_open_recovers_before_sending_a_command(self):
        """Conserva el tráfico inicial y espera silencio antes del primer TX."""
        port = ScriptedPort([(b"\x05", b"\x05\x03")])
        port.pending = b"\x00\xff"
        events = []
        uart = Link(port, lambda *event: events.append(event), now=port.monotonic)
        uart.synchronize_open()
        self.assertGreaterEqual(port.time, 6.1)
        self.assertEqual(events, [("rx", "00 ff")])
        uart.command(5, 3)
        port.complete()

    def test_rejected_five_byte_size_and_incomplete_payload(self):
        """Verifica el campo de 40 bits y el silencio tras timeout."""
        port = ScriptedPort(
            [
                (bytes.fromhex("01 04 00 00 00 01"), b"\x01\x06"),
                (bytes.fromhex("01 08 00 00 00 00"), b"\x01\x01"),
                (bytes.fromhex("0b 00 00"), b"\x01\x08"),
            ]
        )
        uart = link(port)
        uart.load_header(2**32 + 4, 6)
        uart.incomplete_load(8, b"\x0b\x00\x00")
        self.assertGreaterEqual(port.time, 0.300)
        port.complete()

    def test_reject_wrong_opcode_and_truncated_load_acceptance(self):
        """Comprueba que el host detiene el envío ante un ACK inválido."""
        for reply, message in ((b"\x02\x01", "se esperaba"), (b"\x01", "timeout RX")):
            with self.subTest(reply=reply):
                port = ScriptedPort([(b"\x05", b"\x05\x03"), (b"\x01\x04\x00\x00\x00\x00", reply)])
                with self.assertRaisesRegex(WireError, message):
                    link(port).load(b"\x0b\x00\x00\x00")
                port.complete()

    def test_catalogue_snapshot_preserves_all_latch_fields(self):
        """Compara el cuerpo literal canónico con los 34 campos."""
        manifest = read_manifest()
        _, cases = index_manifest(manifest)
        case = cases["TEST-UART-007/C001"][1]
        response = bytes(case["expected"]["response_bytes"])
        port = ScriptedPort([(b"\x03", response)])
        snapshot = link(port).snapshot("step", None, 3)
        self.assertEqual(snapshot["rf"], [0x01010101 * register for register in range(32)])
        self.assertEqual(snapshot["count"], 0x0102030405060708)
        self.assertEqual(snapshot["fault_cause"], 5)
        self.assertEqual(snapshot["fault_pc"], 0x11223344)
        for latch, fields in manifest["latch_fixture"].items():
            self.assertEqual(snapshot[latch], {field["name"]: field["value"] for field in fields})
        port.complete()

    def test_maximum_snapshot_and_64_bit_count(self):
        """Verifica el máximo cuerpo REFERENCE y un contador sin signo."""
        entries = tuple((a, a % 256) for a in range(DMEM))
        reply = frame(op=2, result=10, state=10, pc=28, count=2**64 - 1, memory=entries)
        self.assertEqual(len(reply), 10470)
        port = ScriptedPort([(b"\x02", b"\x02\x01" + reply)])
        state = link(port).snapshot("run", 10, 3)
        self.assertEqual(state["count"], 2**64 - 1)
        self.assertEqual(state["memory"], [list(entry) for entry in entries])
        port.complete()

    def test_invalid_counts_and_memory_order(self):
        """Rechaza cuentas y direcciones incompatibles con el protocolo."""
        for entries in (((5, 0), (5, 0)), ((6, 1), (5, 2)), ((DMEM, 0),)):
            with self.subTest(entries=entries):
                reply = frame(op=3, result=2, state=5, pc=4, count=1, memory=entries)
                with self.assertRaisesRegex(WireError, "dirección DMEM"):
                    link(ScriptedPort([(b"\x03", reply)])).snapshot("step", 5, 3)
        reply = bytearray(frame(op=3, result=2, state=5, pc=4, count=1))
        reply[229] = 1
        with self.assertRaisesRegex(WireError, "used_count"):
            link(ScriptedPort([(b"\x03", reply)])).snapshot("step", 5, 3)

    def test_independent_snapshot_comparison_rejects_wrong_register(self):
        """Verifica el diagnóstico de una discrepancia de RF."""
        with self.assertRaisesRegex(WireError, r"Debug.rf\[1\]"):
            compare({"rf": [0, 7]}, {"rf": [0, 0]})


if __name__ == "__main__":
    unittest.main()
