"""PC-I05 sessions over the real serial service and controlled literal UART bytes."""

import asyncio
import threading
from copy import deepcopy
from uuid import uuid4

from software.tests.viewrv.serial_fixture import literal
from software.tests.viewrv.test_preparation import PreparationFixture
from software.tests.viewrv.test_storage import until
from software.viewrv.adapters.assembler import PythonAssembler
from software.viewrv.contracts import ApplicationError

IMAGE = bytes.fromhex("930050000b000000")


def wire(state=5, cycle=1, run=False):
    value = bytearray(literal("TEST-UART-007/C007"))
    if run:
        value[:2] = bytes((2, state))
    value[2] = state
    value[8:16] = cycle.to_bytes(8, "little")
    # Literal offsets from the approved UART layout, not a production encoder.
    value[150:154] = (0).to_bytes(4, "little")
    value[161:165] = (4).to_bytes(4, "little")
    return bytes(value)


class SessionFixture(PreparationFixture):
    async def asyncSetUp(self):
        await super().asyncSetUp()
        self.replies(b"\x05\x03")
        await self.board.prepare(self.owner)
        self.sessions = self.app.session_service
        self.programs = self.app.program_service
        self.program = self.programs.create(self.owner, "addi x1,x0,5\nhalt\n")
        self.capture = {
            key: self.program[key] for key in ("program_id", "source_version", "source_text")
        }
        await self.programs.assemble(self.owner, **self.capture)
        self.release = threading.Event()
        self.release.set()

    async def asyncTearDown(self):
        self.release.set()
        await super().asyncTearDown()

    def load_reply(self, reply=b"\x01\x02", accepted=b"\x01\x01"):
        self.replies(b"\x05\x03")
        self.port.script.append((b"\x01\x08\x00\x00\x00\x00", [(0, accepted)]))
        if accepted == b"\x01\x01":
            self.port.script.append((IMAGE, [(0, reply)] if reply else []))

    async def load(self):
        self.load_reply()
        return await self.sessions.load(self.owner, **self.capture)

    async def debug(self, **options):
        await self.load()
        return await self.sessions.debug_start(
            self.owner,
            **{key: self.capture[key] for key in ("program_id", "source_version")},
            **options,
        )

    def step_reply(self, state=5, cycle=1):
        self.port.script.append((b"\x03", [(0, wire(state, cycle))]))

    def gate_reads(self):
        self.release.clear()
        entered = threading.Event()
        original = self.port.read

        def read(size):
            entered.set()
            if not self.release.wait(5):
                raise TimeoutError("Controlled STEP gate not released")
            return original(size)

        self.port.read = read
        return entered


class RealAssemblerSessionTests(SessionFixture):
    async def test_real_translation_loads_exact_image_and_binds_breakpoint_to_original_line(self):
        """TEST-PC-003 / TEST-PC-017: real assembler image/map survive LOAD with exact CRLF source."""
        self.programs.assembler = PythonAssembler()
        source = "# contador ñ\r\ninicio:\r\naddi x1,x0,3\r\nbne x1,x0,inicio\r\nhalt\r\n"
        p = self.programs.create(self.owner, source)
        captured = {key: p[key] for key in ("program_id", "source_version", "source_text")}
        translated = await self.programs.assemble(self.owner, **captured)
        image = bytes.fromhex("93003000e39e00fe0b000000")
        self.assertEqual(translated["image"], list(image))
        self.assertEqual(
            translated["pc_to_line"],
            [{"pc": 0, "line": 3}, {"pc": 4, "line": 4}, {"pc": 8, "line": 5}],
        )
        self.replies(b"\x05\x03")
        self.port.script.extend(
            [(b"\x01\x0c\x00\x00\x00\x00", [(0, b"\x01\x01")]), (image, [(0, b"\x01\x02")])]
        )
        await self.sessions.load(self.owner, **captured)
        opened = await self.sessions.debug_start(
            self.owner, program_id=p["program_id"], source_version=p["source_version"]
        )
        shown = await self.sessions.show(self.owner, opened["session_id"])
        self.assertEqual(shown["source_text"], source)
        added = self.sessions.breakpoints(self.owner, "add", line=4, latch="ID/EX")
        self.assertIn({"pc": 4, "line": 4, "latch": "ID/EX"}, added["breakpoints"])
        self.assertIn(image, [data for _, data in self.port.writes])
        await self.sessions.debug_control(self.owner, stop=True)

    async def test_real_source_error_prevents_load_and_preserves_previous_image(self):
        """TEST-PC-003 / TEST-PC-015: source diagnostics cannot replace a confirmed image."""
        await self.load()
        previous = deepcopy(self.app.loaded_image)
        self.programs.assembler = PythonAssembler()
        p = self.programs.create(self.owner, "# inválido\nunknown x1,x0,5\n")
        captured = {key: p[key] for key in ("program_id", "source_version", "source_text")}
        before = len(self.port.writes)
        with self.assertRaises(ApplicationError) as caught:
            await self.programs.assemble(self.owner, **captured)
        self.assertEqual(caught.exception.code, "ASSEMBLY_SOURCE_ERROR")
        self.assertEqual(caught.exception.details["line"], 2)
        with self.assertRaises(ApplicationError):
            await self.sessions.load(self.owner, **captured)
        self.assertEqual(len(self.port.writes), before)
        self.assertEqual(self.app.loaded_image, previous)


class SessionTests(SessionFixture):
    async def test_breakpoints_survive_reloading_same_revision_and_do_not_move_to_new_revision(
        self,
    ):
        """TEST-PC-005: breakpoints survive reloading same revision and do not move to new revision."""
        await self.debug()
        self.sessions.breakpoints(self.owner, "add", pc=0, latch="IF/ID")
        await self.sessions.debug_control(self.owner, stop=True)
        await self.load()
        restored = await self.sessions.debug_start(
            self.owner,
            program_id=self.capture["program_id"],
            source_version=self.capture["source_version"],
        )
        self.assertEqual(restored["breakpoints"], [{"pc": 0, "line": 1, "latch": "IF/ID"}])
        await self.sessions.debug_control(self.owner, stop=True)
        version = str(uuid4())
        changed = {
            **self.capture,
            "source_version": version,
            "source_text": "# changed\naddi x1,x0,5\nhalt\n",
        }
        self.programs.update(self.owner, changed["program_id"], version, changed["source_text"])
        await self.programs.assemble(self.owner, **changed)
        self.load_reply()
        await self.sessions.load(self.owner, **changed)
        new = await self.sessions.debug_start(
            self.owner, program_id=changed["program_id"], source_version=version
        )
        self.assertEqual(new["breakpoints"], [])

    async def test_drain_states_do_not_stop_continue_before_terminal(self):
        """TEST-PC-006: drain states do not stop continue before terminal."""
        for sequence in ((5, 7, 10), (5, 9, 11)):
            await self.debug()
            before = sum(data == b"\x03" for _, data in self.port.writes)
            for index, state in enumerate(sequence, 1):
                self.step_reply(state, index)
            result = await self.sessions.step(self.owner, continuing=True)
            self.assertEqual(result["stop_reasons"], ["terminal"])
            self.assertEqual(result["last_step"]["step_index"], 3)
            self.assertEqual(result["last_step"]["snapshot"]["global_state"], sequence[-1])
            self.assertEqual(sum(data == b"\x03" for _, data in self.port.writes) - before, 3)
            await self.sessions.debug_control(self.owner, stop=True)

    async def test_run_limit_is_reported_as_interruption_and_no_terminal_snapshot_is_invented(self):
        """TEST-PC-016: run limit is reported as interruption and no terminal snapshot is invented."""
        await self.load()
        self.port.script.extend([(b"\x02", [(0, b"\x02\x01")]), (b"\x04", [(0, b"\x04\x01")])])
        result = await self.sessions.run(
            self.owner,
            program_id=self.capture["program_id"],
            source_version=self.capture["source_version"],
            limit_seconds=0.03,
        )
        self.assertIsNone(result["snapshot"])
        self.assertEqual(result["interruption"], {"reason": "time_limit"})
        logs = await self.sessions.logs(session_id=result["session_id"])
        self.assertEqual(logs["observations"], [])
        self.assertEqual(logs["outcome"]["interruption_reason"], "time_limit")

    async def test_explicit_run_rejection_does_not_publish_or_record_an_unstarted_session(self):
        """TEST-PC-003: explicit run rejection does not publish or record an unstarted session."""
        await self.load()
        self.port.script.append((b"\x02", [(0, b"\x02\x04")]))
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.run(
                self.owner,
                program_id=self.capture["program_id"],
                source_version=self.capture["source_version"],
            )
        self.assertEqual(caught.exception.code, "RUN_REJECTED")
        self.assertEqual(set(caught.exception.details), {"program_id", "source_version"})
        self.assertFalse(self.sessions.known)
        self.assertIsNone(self.app.works[self.owner]["session_id"])
        self.assertEqual(self.app.loaded_image["status"], "loaded")
        self.assertFalse(self.storage.records.exists())

    async def test_only_done_confirms_image_and_missing_or_stale_assembly_never_sends_load(self):
        """TEST-PC-017: only done confirms image and missing or stale assembly never sends load."""
        before = len(self.port.writes)
        self.programs.update(self.owner, self.capture["program_id"], str(uuid4()), "changed\n")
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.load(self.owner, **self.capture)
        self.assertEqual(caught.exception.code, "SOURCE_VERSION_MISMATCH")
        self.assertEqual(len(self.port.writes), before)

    async def test_load_confirmed_context_and_rejected_reload_preserves_previous_image(self):
        """TEST-PC-003: load confirmed context and rejected reload preserves previous image."""
        result = await self.load()
        self.assertEqual(
            result,
            {
                "program_id": self.capture["program_id"],
                "source_version": self.capture["source_version"],
                "byte_count": 8,
            },
        )
        self.assertEqual(self.app.loaded_image["status"], "loaded")
        self.load_reply(accepted=b"\x01\x06")
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.load(self.owner, **self.capture)
        self.assertEqual(caught.exception.code, "LOAD_REJECTED")
        self.assertEqual(caught.exception.details, result)
        self.assertEqual(self.app.loaded_image, {"status": "loaded", **result})

    async def test_lost_done_invalidates_image_recovers_without_reloading_and_keeps_context(self):
        """TEST-PC-003: lost done invalidates image recovers without reloading and keeps context."""
        await self.load()
        self.load_reply(reply=None)
        self.replies(b"\x05\x03")
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.load(self.owner, **self.capture)
        self.assertEqual(caught.exception.code, "LOAD_RESULT_UNCONFIRMED")
        self.assertEqual(caught.exception.details["byte_count"], 8)
        self.assertEqual(self.app.loaded_image["status"], "unknown")
        self.assertFalse(self.app.board["recovery_pending"])
        self.assertEqual(sum(data == IMAGE for _, data in self.port.writes), 2)

    async def test_debug_opens_without_step_and_protects_exact_revision(self):
        """TEST-PC-005: debug opens without step and protects exact revision."""
        opened = await self.debug()
        self.assertIsNone(opened["snapshot"])
        self.assertFalse(any(data == b"\x03" for _, data in self.port.writes))
        self.assertTrue(self.programs.get(self.capture["program_id"]).edit_protected)
        with self.assertRaises(ApplicationError) as caught:
            self.programs.update(self.owner, self.capture["program_id"], str(uuid4()), "edit\n")
        self.assertEqual(caught.exception.code, "PROGRAM_PROTECTED")
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.run(self.owner)
        self.assertEqual(caught.exception.code, "OPERATION_CONFLICT")
        await self.sessions.debug_control(self.owner, stop=True)
        self.assertFalse(self.programs.get(self.capture["program_id"]).edit_protected)

    async def test_gui_references_are_required_and_mismatches_do_not_operate_uart(self):
        """TEST-PC-017: gui references are required and mismatches do not operate uart."""
        await self.load()
        before = len(self.port.writes)
        for options, code in (
            ({}, "INVALID_ARGUMENT"),
            ({"program_id": self.capture["program_id"]}, "INVALID_ARGUMENT"),
            (
                {"program_id": self.capture["program_id"], "source_version": str(uuid4())},
                "SOURCE_VERSION_MISMATCH",
            ),
        ):
            with self.assertRaises(ApplicationError) as caught:
                await self.sessions.run(self.owner, **options)
            self.assertEqual(caught.exception.code, code)
        self.assertEqual(len(self.port.writes), before)

    async def test_multiple_breakpoint_hits_and_retention_are_reported_per_new_capture(self):
        """TEST-PC-005: multiple breakpoint hits and retention are reported per new capture."""
        opened = await self.debug()
        self.sessions.breakpoints(self.owner, "add", line=1, latch="IF/ID")
        self.sessions.breakpoints(self.owner, "add", pc=4, latch="ID/EX")
        for index in (1, 2):
            self.step_reply(cycle=index)
            result = await self.sessions.step(self.owner, continuing=True)
            self.assertEqual(result["session_id"], opened["session_id"])
            self.assertEqual(result["stop_reasons"], ["breakpoint"])
            self.assertEqual(len(result["last_step"]["breakpoint_hits"]), 2)
            self.assertEqual(result["last_step"]["step_index"], index)
        self.assertEqual(sum(data == b"\x03" for _, data in self.port.writes), 2)

    async def test_breakpoint_validation_does_not_choose_neighbor_or_reevaluate_previous_step(self):
        """TEST-PC-005: breakpoint validation does not choose neighbor or reevaluate previous step."""
        await self.debug()
        for fields, code in (
            ({"pc": 2, "latch": "IF/ID"}, "INVALID_BREAKPOINT_LOCATION"),
            ({"pc": 0, "line": 1, "latch": "IF/ID"}, "INVALID_ARGUMENT"),
            ({"pc": 0, "latch": "EX"}, "INVALID_ARGUMENT"),
        ):
            with self.assertRaises(ApplicationError) as caught:
                self.sessions.breakpoints(self.owner, "add", **fields)
            self.assertEqual(caught.exception.code, code)
        self.step_reply()
        step = await self.sessions.step(self.owner)
        self.sessions.breakpoints(self.owner, "add", pc=0, latch="IF/ID")
        self.assertEqual(step["breakpoint_hits"], [])
        show = await self.sessions.show(session_id=step["session_id"])
        self.assertEqual(show["last_observation"]["breakpoint_hits"], [])
        with self.assertRaises(ApplicationError) as caught:
            self.sessions.breakpoints(self.owner, "add", pc=0, latch="IF/ID")
        self.assertEqual(caught.exception.code, "BREAKPOINT_ALREADY_EXISTS")
        self.sessions.breakpoints(self.owner, "remove", line=1, latch="IF/ID")
        with self.assertRaises(ApplicationError) as caught:
            self.sessions.breakpoints(self.owner, "remove", line=1, latch="IF/ID")
        self.assertEqual(caught.exception.code, "BREAKPOINT_NOT_FOUND")

    async def test_pause_waits_for_one_pending_step_and_no_step_is_queued(self):
        """TEST-PC-005: pause waits for one pending step and no step is queued."""
        await self.debug()
        self.step_reply()
        entered = self.gate_reads()
        pending = asyncio.create_task(self.sessions.step(self.owner, continuing=True))
        await until(entered.is_set)
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.step(self.owner)
        self.assertEqual(caught.exception.code, "OPERATION_CONFLICT")
        pausing = asyncio.create_task(self.sessions.debug_control(self.owner))
        await asyncio.sleep(0.01)
        self.assertFalse(pausing.done())
        self.release.set()
        result, paused = await asyncio.gather(pending, pausing)
        self.assertIn("pause_requested", result["stop_reasons"])
        self.assertEqual(result["last_step"], paused["last_step"])
        self.assertEqual(sum(data == b"\x03" for _, data in self.port.writes), 1)

    async def test_terminal_remains_inspectable_stop_preserves_fault_and_rejects_further_steps(
        self,
    ):
        """TEST-PC-006: terminal remains inspectable stop preserves fault and rejects further steps."""
        opened = await self.debug()
        self.step_reply(state=11)
        step = await self.sessions.step(self.owner)
        show = await self.sessions.show(session_id=opened["session_id"])
        self.assertEqual(show["execution_status"], "fault")
        self.assertTrue(show["debug_open"])
        with self.assertRaises(ApplicationError):
            await self.sessions.step(self.owner)
        stopped = await self.sessions.debug_control(self.owner, stop=True)
        self.assertIn("terminal", stopped["stop_reasons"])
        self.assertEqual(
            (await self.sessions.show(session_id=step["session_id"]))["execution_status"], "fault"
        )

    async def test_restart_only_creates_identity_after_confirmed_reload_and_retains_breakpoints(
        self,
    ):
        """TEST-PC-005: restart only creates identity after confirmed reload and retains breakpoints."""
        opened = await self.debug()
        self.sessions.breakpoints(self.owner, "add", pc=0, latch="IF/ID")
        self.step_reply()
        await self.sessions.step(self.owner)
        self.load_reply(accepted=b"\x01\x06")
        with self.assertRaises(ApplicationError):
            await self.sessions.restart(self.owner)
        self.assertEqual(self.app.works[self.owner]["session_id"], opened["session_id"])
        self.assertTrue((await self.sessions.show(session_id=opened["session_id"]))["debug_open"])
        self.load_reply()
        new = await self.sessions.restart(self.owner)
        self.assertNotEqual(new["session_id"], opened["session_id"])
        self.assertEqual(len(new["breakpoints"]), 1)
        self.assertIsNone(new["snapshot"])
        self.assertFalse((await self.sessions.show(session_id=opened["session_id"]))["debug_open"])

    async def test_durable_queries_do_not_send_uart_or_consume_steps_and_historical_records_are_independent(
        self,
    ):
        """TEST-PC-030: durable queries do not send uart or consume steps and historical records are independent."""
        opened = await self.debug()
        self.step_reply()
        await self.sessions.step(self.owner)
        await self.sessions.debug_control(self.owner, stop=True)
        before = len(self.port.writes)
        first = await self.sessions.steps(session_id=opened["session_id"])
        second = await self.sessions.steps(session_id=opened["session_id"])
        self.assertEqual(first, second)
        self.assertEqual([step["step_index"] for step in first["steps"]], [1])
        self.assertEqual(
            (await self.sessions.steps(session_id=opened["session_id"], after=1))["steps"], []
        )
        logs = await self.sessions.logs(session_id=opened["session_id"])
        self.assertEqual(logs["source_text"], self.capture["source_text"])
        self.assertEqual(logs["record_status"], "complete")
        self.sessions.known.clear()
        recovered = await self.sessions.show(session_id=opened["session_id"])
        self.assertFalse(recovered["debug_open"])
        self.assertEqual(recovered["last_observation"]["step_index"], 1)
        self.assertEqual(len(self.port.writes), before)

    async def test_record_disabled_keeps_last_observation_without_inventing_history(self):
        """TEST-PC-009 / TEST-PC-030: record disabled keeps last observation without inventing history."""
        opened = await self.debug(record=False)
        self.step_reply()
        await self.sessions.step(self.owner)
        show = await self.sessions.show(session_id=opened["session_id"])
        self.assertEqual(show["evidence"]["record_status"], "disabled")
        self.assertEqual(show["evidence"]["observation_status"], "available")
        steps = await self.sessions.steps(session_id=opened["session_id"])
        self.assertEqual(steps["steps"], [])
        self.assertEqual(steps["limitations"][-1]["code"], "EVIDENCE_UNAVAILABLE")

    async def test_observer_cannot_control_and_explicit_queries_do_not_change_cli_default(self):
        """TEST-PC-029: observer cannot control and explicit queries do not change cli default."""
        opened = await self.debug()
        self.assertEqual(
            (await self.sessions.show(self.other, opened["session_id"]))["session_id"],
            opened["session_id"],
        )
        for action in (
            lambda: self.sessions.step(self.other),
            lambda: self.sessions.run(self.other),
        ):
            with self.assertRaises(ApplicationError) as caught:
                await action()
            self.assertEqual(caught.exception.code, "BOARD_CONTROL_CONFLICT")
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.show(self.other)
        self.assertEqual(caught.exception.code, "SESSION_SELECTION_REQUIRED")

    async def test_disconnect_during_continue_finishes_pending_capture_closes_and_unprotects(self):
        """TEST-PC-024: disconnect during continue finishes pending capture closes and unprotects."""
        opened = await self.debug()
        self.step_reply()
        entered = self.gate_reads()
        pending = asyncio.create_task(self.sessions.step(self.owner, continuing=True))
        await until(entered.is_set)
        disconnecting = asyncio.create_task(self.board.disconnect(self.owner))
        await asyncio.sleep(0.01)
        self.assertFalse(disconnecting.done())
        self.release.set()
        await asyncio.gather(pending, disconnecting)
        show = await self.sessions.show(session_id=opened["session_id"])
        self.assertFalse(show["debug_open"])
        self.assertEqual(show["execution_status"], "interrupted")
        self.assertEqual(self.app.board["connection_status"], "closed")
        self.assertFalse(self.programs.get(self.capture["program_id"]).edit_protected)
        self.assertEqual(sum(data == b"\x03" for _, data in self.port.writes), 1)

    async def test_run_terminal_uses_bound_source_and_source_edits_do_not_replace_it(self):
        """TEST-PC-017: run terminal uses bound source and source edits do not replace it."""
        await self.load()
        self.programs.update(self.owner, self.capture["program_id"], str(uuid4()), "new text\n")
        self.port.script.append((b"\x02", [(0, b"\x02\x01" + wire(10, 7, run=True))]))
        result = await self.sessions.run(
            self.owner, **{key: self.capture[key] for key in ("program_id", "source_version")}
        )
        self.assertEqual(result["source_version"], self.capture["source_version"])
        self.assertEqual(result["snapshot"]["global_state"], 10)
        self.assertIsNone(result["interruption"])
        logs = await self.sessions.logs(session_id=result["session_id"])
        self.assertEqual(logs["source_text"], self.capture["source_text"])
        self.assertEqual(logs["record_status"], "complete")
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.steps(session_id=result["session_id"])
        self.assertEqual(caught.exception.code, "SESSION_MODE_MISMATCH")

    async def test_run_stop_confirmed_reset_and_unconfirmed_reset_have_distinct_results(self):
        """TEST-PC-023: run stop confirmed reset and unconfirmed reset have distinct results."""
        for confirmed in (True, False):
            if self.app.board["recovery_pending"]:
                self.replies(b"\x05\x03")
                await self.app.serial_service.request("RECOVER", {"retry_reset": True})
            await self.load()
            self.port.script.extend(
                [(b"\x02", [(0, b"\x02\x01")]), (b"\x04", [(0, b"\x04\x01")] if confirmed else [])]
            )
            baseline = sum(data == b"\x02" for _, data in self.port.writes)
            running = asyncio.create_task(
                self.sessions.run(
                    self.owner,
                    program_id=self.capture["program_id"],
                    source_version=self.capture["source_version"],
                )
            )
            await until(lambda: sum(data == b"\x02" for _, data in self.port.writes) > baseline)
            stopping = asyncio.create_task(self.sessions.run_stop(self.owner))
            result, stopped = await asyncio.gather(running, stopping, return_exceptions=True)
            if confirmed:
                self.assertEqual(result, stopped)
                self.assertIsNone(result["snapshot"])
                self.assertEqual(result["interruption"], {"reason": "user_request"})
                self.assertEqual(self.app.loaded_image["status"], "none")
            else:
                self.assertEqual(result.code, "RUN_RESULT_UNCONFIRMED")
                self.assertEqual(stopped.code, "RESET_UNCONFIRMED")
                self.assertEqual(result.details, stopped.details)
                self.assertTrue(self.app.board["recovery_pending"])

    async def test_terminal_already_started_wins_over_run_stop_without_reset(self):
        """TEST-PC-023: terminal already started wins over run stop without reset."""
        await self.load()
        self.port.script.append((b"\x02", [(0, b"\x02\x01" + wire(10, 4, run=True))]))
        entered = threading.Event()
        original = self.port.read
        self.release.clear()

        def read(size):
            if size == 228:
                entered.set()
                if not self.release.wait(5):
                    raise TimeoutError("Controlled terminal body gate")
            return original(size)

        self.port.read = read
        running = asyncio.create_task(
            self.sessions.run(
                self.owner,
                program_id=self.capture["program_id"],
                source_version=self.capture["source_version"],
            )
        )
        await until(entered.is_set)
        stopping = asyncio.create_task(self.sessions.run_stop(self.owner))
        await asyncio.sleep(0.01)
        self.release.set()
        result, stopped = await asyncio.gather(running, stopping)
        self.assertEqual(result, stopped)
        self.assertEqual(result["snapshot"]["global_state"], 10)
        self.assertIsNone(result["interruption"])
        self.assertFalse(any(data == b"\x04" for _, data in self.port.writes))

    async def test_edit_after_load_begins_preserves_captured_version_and_rejects_other_run_reference(
        self,
    ):
        """TEST-PC-017: edit after load begins preserves captured version and rejects other run reference."""
        self.load_reply()
        entered = self.gate_reads()
        loading = asyncio.create_task(self.sessions.load(self.owner, **self.capture))
        await until(entered.is_set)
        new_version = str(uuid4())
        self.programs.update(
            self.owner, self.capture["program_id"], new_version, "edited during LOAD\n"
        )
        self.release.set()
        result = await loading
        self.assertEqual(result["source_version"], self.capture["source_version"])
        self.assertEqual(self.sessions.image["source_text"], self.capture["source_text"])
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.run(
                self.owner, program_id=self.capture["program_id"], source_version=new_version
            )
        self.assertEqual(caught.exception.code, "SOURCE_VERSION_MISMATCH")

    async def test_step_failure_closes_debug_but_retains_last_complete_capture_as_previous(self):
        """TEST-PC-005: step failure closes debug but retains last complete capture as previous."""
        opened = await self.debug()
        self.step_reply()
        first = await self.sessions.step(self.owner)
        self.port.script.append((b"\x03", [(0, wire(cycle=2)[:20])]))
        self.replies(b"\x05\x03")
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.step(self.owner)
        self.assertEqual(caught.exception.code, "STEP_RESULT_UNCONFIRMED")
        self.assertEqual(caught.exception.details["session_id"], opened["session_id"])
        show = await self.sessions.show(session_id=opened["session_id"])
        self.assertEqual(show["last_observation"]["step_index"], first["step_index"])
        self.assertEqual(show["execution_status"], "interrupted")
        self.assertFalse(show["debug_open"])
        self.assertEqual(show["outcome"]["interruption_reason"], "communication_failure")

    async def test_first_record_write_failure_keeps_execution_and_code_conservation_available(self):
        """TEST-PC-021: first record write failure keeps execution and code conservation available."""
        original = self.storage.append_record
        calls = []

        def append(value):
            calls.append(deepcopy(value))
            if value["record_type"] == "observation" and value["data"]["step_index"] == 2:
                raise PermissionError("Controlled evidence write failure")
            return original(value)

        self.storage.append_record = append
        opened = await self.debug()
        current = self.sessions.known[opened["session_id"]]
        for index in (1, 2, 3):
            self.step_reply(cycle=index)
            await self.sessions.step(self.owner)
            await current.writer.finish()
        self.assertEqual(current.writer.status, "failed")
        self.assertEqual(current.last["step_index"], 3)
        self.assertEqual(
            [
                value["data"]["step_index"]
                for value in calls
                if value["record_type"] == "observation"
            ],
            [1, 2],
        )
        self.assertEqual(
            [
                value["step_index"]
                for value in (await self.sessions.steps(session_id=opened["session_id"]))["steps"]
            ],
            [1],
        )
        other = self.programs.create(self.owner, "kept source\n")
        self.assertEqual(await self.programs.flush(self.programs.get(other["program_id"])), [])
        await self.sessions.debug_control(self.owner, stop=True)
        await self.load()
        new = await self.sessions.debug_start(
            self.owner,
            program_id=self.capture["program_id"],
            source_version=self.capture["source_version"],
        )
        await self.sessions.debug_control(self.owner, stop=True)
        self.assertEqual(self.sessions.known[new["session_id"]].writer.status, "complete")
        self.assertTrue(self.app.preferences["record_by_default"])

    async def test_restart_uncertainty_closes_old_debug_without_creating_a_new_identity(self):
        """TEST-PC-005: restart uncertainty closes old debug without creating a new identity."""
        opened = await self.debug()
        self.load_reply(reply=None)
        self.replies(b"\x05\x03")
        with self.assertRaises(ApplicationError) as caught:
            await self.sessions.restart(self.owner)
        self.assertEqual(caught.exception.code, "LOAD_RESULT_UNCONFIRMED")
        self.assertEqual(list(self.sessions.known), [opened["session_id"]])
        self.assertFalse(self.app.works[self.owner]["debug_open"])
        self.assertFalse(self.programs.get(self.capture["program_id"]).edit_protected)
