"""PC-I03: literal protocol vectors, timing boundaries and controlled UART faults."""

import asyncio
import os
import select
import threading
import time
import unittest
from unittest.mock import patch

from software.tests.viewrv.serial_fixture import Clock, ScriptedPort, literal
from software.viewrv.adapters.serial import SerialTransport, select_port
from software.viewrv.contracts import ApplicationError
from software.viewrv.core.protocol import (
    debug_recovery_milliseconds,
    decode_fixed,
    decode_memory,
    list_milliseconds,
    load_header,
    load_recovery_milliseconds,
    load_seconds,
)
from software.viewrv.core.serial_service import SerialService


async def until(predicate):
    end = asyncio.get_running_loop().time() + 3
    while not predicate():
        if asyncio.get_running_loop().time() >= end:
            raise AssertionError("Timed out waiting for worker")
        await asyncio.sleep(0.005)


PROFILES = ("REFERENCE", "ALT_1000")
IMAGE = bytes.fromhex("930050000b000000")


class LayoutTests(unittest.TestCase):
    def test_normative_budgets_and_40_bit_lengths(self):
        with self.assertRaises(ValueError):
            SerialTransport("UNKNOWN_PROFILE")
        self.assertEqual(load_header(2**32), bytes.fromhex("010000000001"))
        self.assertEqual(load_header(2**40 - 1), b"\x01" + b"\xff" * 5)
        self.assertEqual(load_header(8), bytes.fromhex("010800000000"))
        for value in (-1, 2**40, True):
            with self.assertRaises(ValueError):
                load_header(value)
        self.assertEqual([list_milliseconds(k) for k in (2, 1000, 2048)], [206, 2805, 5534])
        self.assertEqual([load_recovery_milliseconds(n) for n in (32, 1024)], [300, 800])
        self.assertEqual([debug_recovery_milliseconds(p) for p in PROFILES], [6100, 3400])
        self.assertAlmostEqual(load_seconds(8), 8 * 10 / 19200 + 0.201)

    def test_literal_snapshot_all_fields_and_invalid_latches_are_preserved(self):
        for profile in PROFILES:
            for index in range(1, 8):
                with self.subTest(profile=profile, vector=index):
                    wire = literal(f"TEST-UART-007/C{index:03}")
                    snapshot = decode_memory(
                        decode_fixed(wire[2:230], profile, "STEP", 2), b"", profile
                    )
                    self.assertEqual(
                        snapshot,
                        {
                            "global_state": 5 if index == 7 else 11,
                            "image_valid": True,
                            "pc": 0x12345678,
                            "cycle_count": "72623859790382856",
                            "fault_cause": 5,
                            "fault_pc": 0x11223344,
                            "registers": [0x01010101 * i for i in range(32)],
                            "if_id": {
                                "valid": index not in (2, 3),
                                "pc": 0x01234567,
                                "instruction": 0x89ABCDEF,
                                "fetch_fault_valid": index == 2,
                                "fetch_fault_cause": 1,
                            },
                            "id_ex": {
                                "valid": index != 4,
                                "pc": 0x89ABCDEF,
                                "instruction": 0x01234567,
                                "rs1": 31,
                                "rs2": 30,
                                "rd": 29,
                                "rs1_value": 0x01234567,
                                "rs2_value": 0x89ABCDEF,
                                "immediate": 0x01234567,
                                "alu_op": 0x2B,
                                "alu_src": 1,
                                "result_sel": 2,
                                "flow_op": 5,
                                "mem_op": 8,
                                "reg_write": True,
                            },
                            "ex_mem": {
                                "valid": index != 5,
                                "pc": 0x01234567,
                                "instruction": 0x89ABCDEF,
                                "rd": 31,
                                "reg_write": True,
                                "mem_op": 8,
                                "ex_result": 0x01234567,
                                "store_data": 0x89ABCDEF,
                            },
                            "mem_wb": {
                                "valid": index != 6,
                                "pc": 0x89ABCDEF,
                                "instruction": 0x01234567,
                                "rd": 31,
                                "reg_write": True,
                                "wb_value": 0x89ABCDEF,
                            },
                            "used_count": 0,
                            "memory": [],
                        },
                    )
                    self.assertIsInstance(snapshot["image_valid"], bool)
                    self.assertIsInstance(snapshot["if_id"]["fetch_fault_valid"], bool)
                    for name in ("if_id", "id_ex", "ex_mem", "mem_wb"):
                        self.assertIsInstance(snapshot[name]["valid"], bool)
                        if "reg_write" in snapshot[name]:
                            self.assertIsInstance(snapshot[name]["reg_write"], bool)
                    self.assertEqual(snapshot["pc"], 0x12345678)
                    self.assertEqual(snapshot["cycle_count"], "72623859790382856")
                    self.assertEqual(snapshot["fault_pc"], 0x11223344)
                    self.assertEqual(snapshot["fault_cause"], 5)
                    self.assertEqual(snapshot["registers"], [0x01010101 * i for i in range(32)])
                    self.assertEqual(snapshot["if_id"]["instruction"], 0x89ABCDEF)
                    self.assertEqual(snapshot["if_id"]["fetch_fault_cause"], 1)
                    self.assertEqual(snapshot["id_ex"]["rs1"], 31)
                    self.assertEqual(snapshot["id_ex"]["rs2_value"], 0x89ABCDEF)
                    self.assertEqual(snapshot["id_ex"]["alu_op"], 0x2B)
                    self.assertEqual(snapshot["id_ex"]["flow_op"], 5)
                    self.assertEqual(snapshot["ex_mem"]["store_data"], 0x89ABCDEF)
                    self.assertEqual(snapshot["mem_wb"]["wb_value"], 0x89ABCDEF)
                    if index in (2, 3):
                        self.assertFalse(snapshot["if_id"]["valid"])
                    if index == 2:
                        self.assertTrue(snapshot["if_id"]["fetch_fault_valid"])
                    if index == 4:
                        self.assertFalse(snapshot["id_ex"]["valid"])
                    if index == 5:
                        self.assertFalse(snapshot["ex_mem"]["valid"])
                    if index == 6:
                        self.assertFalse(snapshot["mem_wb"]["valid"])

    def test_full_64_bits_and_unsigned_data(self):
        body = bytearray(literal()[2:])
        body[6:14] = b"\xff" * 8
        body[19 + 4 : 19 + 8] = b"\xff" * 4
        value = decode_fixed(body, "REFERENCE", "STEP", 2)
        self.assertEqual(value["cycle_count"], "18446744073709551615")
        self.assertEqual(value["registers"][1], 4294967295)

    def test_counts_padding_and_memory_integrity_before_publication(self):
        for profile in PROFILES:
            for field, value in ((1, 2), (147, 2), (156, 2), (167, 32), (182, 64), (218, 2)):
                body = bytearray(literal()[2:])
                body[field] = value
                with self.subTest(profile=profile, field=field):
                    with self.assertRaises(ValueError):
                        decode_fixed(body, profile, "STEP", 2)
            body = bytearray(literal()[2:])
            body[223:228] = (2**32).to_bytes(5, "little")
            with self.assertRaises(ValueError):
                decode_fixed(body, profile, "STEP", 2)
            body[223:228] = (3).to_bytes(5, "little")
            snapshot = decode_fixed(body, profile, "STEP", 2)
            data = bytes.fromhex("000000003401000000560300000000")
            self.assertEqual(
                decode_memory(snapshot, data, profile)["memory"],
                [
                    {"address": 0, "value": 52},
                    {"address": 1, "value": 86},
                    {"address": 3, "value": 0},
                ],
            )
            for invalid in (
                data[:-1],
                data[:5] + data[:5] + data[10:],
                data[5:10] + data[:5] + data[10:],
                data[:10]
                + (2048 if profile == "REFERENCE" else 1000).to_bytes(4, "little")
                + b"\x00",
            ):
                with self.assertRaises(ValueError):
                    decode_memory(snapshot, invalid, profile)


class TransportCase(unittest.TestCase):
    def make(self, profile, script=(), **kwargs):
        clock = Clock()
        port = ScriptedPort(clock, script, **kwargs)
        transport = SerialTransport(profile, lambda name: port, clock)
        transport.prepared()
        transport.port = port
        transport.port_name = "controlled"
        return transport, port, clock

    def call(self, transport, operation, parameters=None, control=None):
        return transport.execute(operation, parameters or {}, control or threading.Event())


class ExchangeTests(TransportCase):
    def test_pc003_load_checks_ready_and_keeps_header_payload_and_done_separate(self):
        for profile in PROFILES:
            engine, port, clock = self.make(
                profile,
                [
                    (b"\x05", [(0.01, b"\x05"), (0.02, b"\x03")]),
                    (bytes.fromhex("010800000000"), [(0.01, b"\x01"), (0.02, b"\x01")]),
                    (IMAGE, [(0.01, b"\x01\x02")]),
                ],
                max_write=1,
            )
            result = self.call(engine, "LOAD", {"image": IMAGE})
            self.assertEqual(result, {"byte_count": 8, "image_status": "confirmed"})
            self.assertEqual(
                b"".join(data for _, data in port.writes),
                b"\x05" + bytes.fromhex("010800000000") + IMAGE,
            )
            self.assertGreaterEqual(port.writes[7][0], 0.04)
            self.assertFalse(port.script)
            self.assertIsNone(engine.last_snapshot)

    def test_pc003_rejected_load_never_sends_payload_and_preserves_prior_image(self):
        for profile in PROFILES:
            for result in (4, 6, 7, 9):
                engine, port, _ = self.make(
                    profile,
                    [(b"\x05", [(0, b"\x05\x03")]), (load_header(8), [(0, bytes([1, result]))])],
                )
                with self.assertRaises(ApplicationError) as caught:
                    self.call(engine, "LOAD", {"image": IMAGE})
                self.assertEqual(caught.exception.code, "LOAD_REJECTED")
                self.assertEqual(caught.exception.details["image_status"], "preserved")
                self.assertFalse(port.script)
                self.assertEqual(engine.context is not None, result in (7, 9))

    def test_pc003_lost_acceptance_and_done_are_uncertain_not_rejections(self):
        for profile in PROFILES:
            for accepted in (False, True):
                script = [
                    (b"\x05", [(0, b"\x05\x03")]),
                    (load_header(8), [(0, b"\x01\x01")] if accepted else []),
                ]
                if accepted:
                    script.append((IMAGE, []))
                engine, port, _ = self.make(profile, script)
                with self.assertRaises(ApplicationError) as caught:
                    self.call(engine, "LOAD", {"image": IMAGE})
                self.assertEqual(caught.exception.code, "LOAD_RESULT_UNCONFIRMED")
                self.assertEqual(engine.context["byte_count"], 8)
                self.assertGreater(port.flushed_output, 0)

    def test_pc007_fragment_every_boundary_and_byte_without_new_step(self):
        wire = literal()
        for profile in PROFILES:
            for split in range(1, len(wire)):
                engine, port, _ = self.make(
                    profile, [(b"\x03", [(0, wire[:split]), (0.001, wire[split:])])]
                )
                result = self.call(engine, "STEP")
                self.assertEqual(result["snapshot"]["cycle_count"], "72623859790382856")
                self.assertEqual(len(port.writes), 1)
            engine, _, _ = self.make(
                profile, [(b"\x03", [(i * 0.0005, bytes([value])) for i, value in enumerate(wire)])]
            )
            self.assertEqual(self.call(engine, "STEP")["snapshot"]["global_state"], 11)

    def test_pc007_truncation_keeps_last_complete_snapshot_and_never_publishes_partial(self):
        wire = literal()
        for profile in PROFILES:
            for length in (0, 1, 2, 3, 20, 149, 224, 229):
                engine, _, _ = self.make(
                    profile, [(b"\x03", [(0, wire)]), (b"\x03", [(0, wire[:length])])]
                )
                previous = self.call(engine, "STEP")["snapshot"]
                with self.assertRaises(ApplicationError) as caught:
                    self.call(engine, "STEP")
                self.assertEqual(caught.exception.code, "STEP_RESULT_UNCONFIRMED")
                self.assertIs(engine.last_snapshot, previous)
                self.assertIsNotNone(engine.context)

    def test_pc007_deadlines_are_per_phase_not_per_fragment(self):
        wire = literal()
        for profile in PROFILES:
            for fragments, okay in (
                ([(0.199, wire[:2]), (0.517, wire[2:])], True),
                ([(0.201, wire)], False),
                ([(0, wire[:2]), (0.2, wire[2:100]), (0.320, wire[100:])], False),
            ):
                engine, _, _ = self.make(profile, [(b"\x03", fragments)])
                if okay:
                    self.call(engine, "STEP")
                else:
                    with self.assertRaises(ApplicationError):
                        self.call(engine, "STEP")

    def test_pc016_run_has_no_implicit_limit_and_fault_is_a_complete_result(self):
        terminal = b"\x02\x0b" + literal()[2:]
        for profile in PROFILES:
            engine, port, clock = self.make(
                profile, [(b"\x02", [(0, b"\x02\x01"), (100, terminal)])]
            )
            result = self.call(engine, "RUN")
            self.assertEqual(result["snapshot"]["global_state"], 11)
            self.assertIsNone(result["interruption"])
            self.assertGreaterEqual(clock(), 100)
            self.assertEqual(len(port.writes), 1)
            self.assertTrue(all(timeout <= 0.05 for _, _, timeout in port.reads))

    def test_pc016_limit_starts_after_acceptance_and_ends_at_first_terminal_byte(self):
        terminal = b"\x02\x0b" + literal()[2:]
        for profile in PROFILES:
            engine, port, _ = self.make(
                profile,
                [(b"\x02", [(0.19, b"\x02\x01"), (0.28, terminal[:1]), (0.45, terminal[1:])])],
            )
            self.assertIsNotNone(self.call(engine, "RUN", {"max_seconds": 0.1})["snapshot"])
            self.assertEqual(len(port.writes), 1)
            engine, port, _ = self.make(
                profile, [(b"\x02", [(0.19, b"\x02\x01")]), (b"\x04", [(0, b"\x04\x01")])]
            )
            result = self.call(engine, "RUN", {"max_seconds": 0.1})
            self.assertEqual(result["interruption"], {"reason": "time_limit"})
            self.assertAlmostEqual(port.writes[-1][0], 0.29)

    def test_pc023_run_stop_terminal_race_and_unconfirmed_reset(self):
        for profile in PROFILES:
            for wins in (True, False):
                engine, port, clock = self.make(
                    profile,
                    [
                        (b"\x02", [(0, b"\x02\x01")]),
                        (b"\x04", [(0, b"\x02\x0b" + literal()[2:])] if wins else []),
                    ],
                )
                control = threading.Event()
                clock.at(0.1, control.set)
                if wins:
                    self.assertIsNotNone(self.call(engine, "RUN", control=control)["snapshot"])
                else:
                    with self.assertRaises(ApplicationError) as caught:
                        self.call(engine, "RUN", control=control)
                    self.assertEqual(caught.exception.code, "RUN_RESULT_UNCONFIRMED")
                    self.assertTrue(engine.context["reset_used"])
                self.assertEqual(sum(data == b"\x04" for _, data in port.writes), 1)

    def test_pc025_selection_never_substitutes_a_missing_remembered_port(self):
        candidates = [{"id": "A", "description": "serial"}]
        self.assertEqual(select_port(candidates), "A")
        self.assertEqual(select_port(candidates, "A", "missing"), "A")
        for candidates, explicit, remembered, code in (
            (candidates, None, "missing", "PORT_NOT_FOUND"),
            ([], None, None, "PORT_SELECTION_REQUIRED"),
            ([{"id": "A"}, {"id": "B"}], None, None, "PORT_SELECTION_REQUIRED"),
        ):
            with self.assertRaises(ApplicationError) as caught:
                select_port(candidates, explicit, remembered)
            self.assertEqual(caught.exception.code, code)

    def test_unknown_context_needs_preparation_before_open_or_any_tx(self):
        for profile in PROFILES:
            calls = []
            engine = SerialTransport(profile, lambda name: calls.append(name))
            with self.assertRaises(ApplicationError) as caught:
                self.call(engine, "OPEN", {"port": "A"})
            self.assertEqual(caught.exception.code, "BOARD_PREPARATION_REQUIRED")
            self.assertEqual(calls, [])


class RecoveryTests(TransportCase):
    # Reuse only fixture helpers; tests exercise the real adapter and its clock.
    def fail_step(self, engine):
        with self.assertRaises(ApplicationError):
            self.call(engine, "STEP")

    def test_pc023_pc024_io_loss_in_load_and_run_phases_never_replays_or_replaces_snapshot(self):
        prefix = literal()
        cases = (
            (
                "LOAD",
                [
                    (b"\x05", [(0, b"\x05\x03")]),
                    (load_header(8), [(0, b"\x01"), (0.01, OSError("gone"))]),
                ],
                "load_header",
            ),
            (
                "LOAD",
                [
                    (b"\x05", [(0, b"\x05\x03")]),
                    (load_header(8), [(0, b"\x01\x01")]),
                    (IMAGE, [(0, b"\x01"), (0.01, OSError("gone"))]),
                ],
                "load_done",
            ),
            ("RUN", [(b"\x02", [(0, b"\x02"), (0.01, OSError("gone"))])], "run_acceptance"),
            ("RUN", [(b"\x02", [(0, b"\x02\x01"), (0.01, OSError("gone"))])], "run_execution"),
            (
                "RUN",
                [(b"\x02", [(0, b"\x02\x01\x02\x0b" + prefix[2:100]), (0.01, OSError("gone"))])],
                "debug_fixed",
            ),
        )
        for profile in PROFILES:
            for operation, script, phase in cases:
                with self.subTest(profile=profile, operation=operation, phase=phase):
                    engine, port, _ = self.make(profile, [(b"\x03", [(0, prefix)]), *script])
                    previous = self.call(engine, "STEP")["snapshot"]
                    with self.assertRaises(ApplicationError) as caught:
                        self.call(
                            engine, operation, {"image": IMAGE} if operation == "LOAD" else {}
                        )
                    self.assertEqual(caught.exception.code, operation + "_RESULT_UNCONFIRMED")
                    self.assertEqual(engine.context["phase"], phase)
                    self.assertEqual(engine.context["operation"], operation)
                    self.assertIs(engine.last_snapshot, previous)
                    self.assertFalse(port.script)
                    self.assertFalse(engine.context["reset_used"])

    def test_open_failure_and_confirmed_reset_with_lost_query_preserve_confirmation_details(self):
        for profile in PROFILES:
            engine = SerialTransport(profile, lambda name: (_ for _ in ()).throw(OSError("denied")))
            engine.prepared()
            with self.assertRaises(ApplicationError) as caught:
                self.call(engine, "OPEN", {"port": "selected"})
            self.assertEqual(caught.exception.details["port"], "selected")
            self.assertEqual(caught.exception.details["reset_status"], "not_attempted")
            engine, _, _ = self.make(profile, [(b"\x04", [(0, b"\x04\x01")]), (b"\x05", [])])
            with self.assertRaises(ApplicationError) as caught:
                self.call(engine, "RESET")
            self.assertEqual(caught.exception.code, "BOARD_CONNECTION_FAILED")
            self.assertEqual(caught.exception.details["reset_status"], "confirmed")
            self.assertEqual(engine.context["reset_status"], "confirmed")

    def test_pc007_debug_silence_restarts_on_each_byte_including_boundary(self):
        for profile in PROFILES:
            window = debug_recovery_milliseconds(profile) / 1000
            engine, port, clock = self.make(
                profile, [(b"\x03", []), (b"\x05", [(0.01, b"\x05"), (0.02, b"\x03\x99")])]
            )
            self.fail_step(engine)
            port.schedule(window, b"old debug")
            result = self.call(engine, "RECOVER")
            self.assertEqual(result, {"ready": True, "reset_status": "not_attempted"})
            self.assertGreaterEqual(port.writes[-1][0], 0.2 + 2 * window - 0.000001)
            self.assertEqual(port.read(1), b"\x99", "No RX flush may follow a valid query")

    def test_pc007_wrong_prefix_never_scans_for_a_ready_pair_and_waits_again(self):
        for profile in PROFILES:
            window = debug_recovery_milliseconds(profile) / 1000
            engine, port, _ = self.make(
                profile,
                [
                    (b"\x03", []),
                    (b"\x05", [(0, b"\x99\x05\x03")]),
                    (b"\x04", [(0.01, b"\x04"), (0.02, b"\x01")]),
                ],
            )
            self.fail_step(engine)
            self.assertEqual(self.call(engine, "RECOVER")["reset_status"], "confirmed")
            self.assertGreaterEqual(port.writes[-1][0], 0.2 + 2 * window - 0.000001)
            self.assertEqual([data for _, data in port.writes], [b"\x03", b"\x05", b"\x04"])

    def test_pc007_silent_query_goes_to_reset_after_200ms_not_a_second_debug_window(self):
        for profile in PROFILES:
            window = debug_recovery_milliseconds(profile) / 1000
            engine, port, _ = self.make(
                profile, [(b"\x03", []), (b"\x05", []), (b"\x04", [(0, b"\x04\x01")])]
            )
            self.fail_step(engine)
            self.call(engine, "RECOVER")
            self.assertAlmostEqual(port.writes[-1][0], 0.4 + window)
            self.assertGreaterEqual(port.writes[-1][0] - port.writes[-2][0], 0.1)

    def test_pc007_partial_or_invalid_query_requires_second_full_silence(self):
        for profile in PROFILES:
            window = debug_recovery_milliseconds(profile) / 1000
            for reply in (b"\x05", b"\x05\x09"):
                engine, port, _ = self.make(
                    profile, [(b"\x03", []), (b"\x05", [(0, reply)]), (b"\x04", [(0, b"\x04\x01")])]
                )
                self.fail_step(engine)
                self.call(engine, "RECOVER")
                self.assertGreaterEqual(port.writes[-1][0], 0.2 + 2 * window - 0.000001)

    def test_pc023_unconfirmed_automatic_reset_cannot_be_renewed_by_reopen(self):
        for profile in PROFILES:
            engine, port, clock = self.make(
                profile, [(b"\x03", []), (b"\x05", []), (b"\x04", [(0, b"\x04")])]
            )
            self.fail_step(engine)
            with self.assertRaises(ApplicationError):
                self.call(engine, "RECOVER")
            self.assertTrue(engine.context["reset_used"])
            context = dict(engine.context)
            self.call(engine, "CLOSE")
            reopened = ScriptedPort(clock, [(b"\x05", [(0, b"\x05\x04")])])
            engine.factory = lambda name: reopened
            with self.assertRaises(ApplicationError):
                self.call(engine, "OPEN", {"port": "same"})
            self.assertEqual(reopened.writes, [])
            self.assertEqual(engine.context, context)
            with self.assertRaises(ApplicationError):
                self.call(engine, "STEP")
            # This is a separate, explicit user retry, not a side effect of OPEN.
            result = self.call(engine, "RECOVER", {"retry_reset": True})
            self.assertEqual(result, {"ready": False, "reset_status": "not_attempted"})

    def test_pc023_reset_write_failure_consumes_attempt_before_touching_driver(self):
        for profile in PROFILES:
            engine, port, _ = self.make(profile, [(b"\x03", []), (b"\x05", [])])
            write = port.write

            def fail(data):
                if data == b"\x04":
                    raise OSError("USB disconnected on RESET write")
                return write(data)

            port.write = fail
            self.fail_step(engine)
            with self.assertRaises(ApplicationError) as caught:
                self.call(engine, "RECOVER")
            self.assertTrue(engine.context["reset_used"])
            self.assertEqual(caught.exception.details["reset_status"], "unconfirmed")
            before = len(port.writes)
            with self.assertRaises(ApplicationError):
                self.call(engine, "RECOVER")
            self.assertEqual(len(port.writes), before)

    def test_pc024_load_recovery_repeats_only_window_and_query(self):
        for profile in PROFILES:
            engine, port, _ = self.make(
                profile,
                [
                    (b"\x05", [(0, b"\x05\x03")]),
                    (load_header(8), []),
                    (b"\x05", []),
                    (b"\x05", [(0, b"\x05\x03")]),
                ],
            )
            with self.assertRaises(ApplicationError):
                self.call(engine, "LOAD", {"image": IMAGE})
            failed_at = engine.clock()
            result = self.call(engine, "RECOVER")
            self.assertTrue(result["ready"])
            self.assertAlmostEqual(port.writes[-2][0], failed_at + 0.3)
            self.assertAlmostEqual(port.writes[-1][0], failed_at + 0.8)
            self.assertEqual(
                [data for _, data in port.writes], [b"\x05", load_header(8), b"\x05", b"\x05"]
            )

    def test_pc024_check_before_load_uses_debug_recovery_when_no_load_was_sent(self):
        for profile in PROFILES:
            engine, port, _ = self.make(profile, [(b"\x05", []), (b"\x05", [(0, b"\x05\x03")])])
            with self.assertRaises(ApplicationError):
                self.call(engine, "LOAD", {"image": IMAGE})
            self.assertEqual(engine.context["operation"], "CHECK_READY")
            self.call(engine, "RECOVER")
            self.assertAlmostEqual(
                port.writes[-1][0], 0.2 + debug_recovery_milliseconds(profile) / 1000
            )

    def test_pc024_io_loss_keeps_partial_out_and_context_across_close_open(self):
        for profile in PROFILES:
            wire = literal()
            engine, port, clock = self.make(
                profile,
                [(b"\x03", [(0, wire)]), (b"\x03", [(0, wire[:100]), (0.01, OSError("USB gone"))])],
            )
            previous = self.call(engine, "STEP")["snapshot"]
            self.fail_step(engine)
            self.assertIs(engine.last_snapshot, previous)
            context = dict(engine.context)
            self.call(engine, "CLOSE")
            self.assertEqual(engine.context, context)
            reopened = ScriptedPort(clock, [(b"\x05", [(0, b"\x05\x03")])])
            engine.factory = lambda name: reopened
            started = clock()
            self.call(engine, "OPEN", {"port": "same"})
            self.assertGreaterEqual(
                reopened.writes[0][0] - started,
                debug_recovery_milliseconds(profile) / 1000 - 0.000001,
            )
            self.assertIs(engine.last_snapshot, previous)
            self.assertIsNone(engine.context)

    def test_pc003_explicit_load_abort_after_acceptance_is_failed_not_uncertain(self):
        for profile in PROFILES:
            for result in (8, 9):
                engine, _, _ = self.make(
                    profile,
                    [
                        (b"\x05", [(0, b"\x05\x03")]),
                        (load_header(8), [(0, b"\x01\x01")]),
                        (IMAGE, [(0, bytes([1, result]))]),
                    ],
                )
                with self.assertRaises(ApplicationError) as caught:
                    self.call(engine, "LOAD", {"image": IMAGE})
                self.assertEqual(caught.exception.code, "LOAD_FAILED")
                self.assertEqual(caught.exception.details["image_status"], "invalid")

    def test_pc003_load_listens_for_abort_while_transmitting_and_stops_remaining_bytes(self):
        for profile in PROFILES:
            image = IMAGE * 32
            engine, port, _ = self.make(
                profile,
                [
                    (b"\x05", [(0, b"\x05\x03")]),
                    (load_header(256), [(0, b"\x01\x01")]),
                    (image[:64], [(0, b"\x01\x09")]),
                ],
            )
            with self.assertRaises(ApplicationError) as caught:
                self.call(engine, "LOAD", {"image": image})
            self.assertEqual(caught.exception.code, "LOAD_FAILED")
            self.assertEqual(
                b"".join(data for _, data in port.writes), b"\x05" + load_header(256) + image[:64]
            )
            self.assertEqual(engine.context["byte_count"], 256)

    def test_pc003_write_time_and_done_share_one_content_deadline(self):
        for profile in PROFILES:
            engine, port, clock = self.make(
                profile,
                [(b"\x05", [(0, b"\x05\x03")]), (load_header(8), [(0, b"\x01\x01")]), (IMAGE, [])],
            )
            write = port.write

            def slow(data):
                result = write(data)
                if data == IMAGE:
                    clock.advance(clock() + load_seconds(8) + 0.001)
                return result

            port.write = slow
            with self.assertRaises(ApplicationError) as caught:
                self.call(engine, "LOAD", {"image": IMAGE})
            self.assertEqual(caught.exception.code, "LOAD_RESULT_UNCONFIRMED")
            self.assertEqual(engine.context["phase"], "load_content")

    def test_run_and_step_rejections_do_not_become_cpu_faults_or_recovery(self):
        for profile in PROFILES:
            for operation, opcode, code in (
                ("RUN", 2, "RUN_REJECTED"),
                ("STEP", 3, "STEP_REJECTED"),
            ):
                for rejection in (4, 5):
                    engine, _, _ = self.make(
                        profile, [(bytes([opcode]), [(0, bytes([opcode, rejection]))])]
                    )
                    with self.assertRaises(ApplicationError) as caught:
                        self.call(engine, operation)
                    self.assertEqual(caught.exception.code, code)
                    self.assertIsNone(engine.context)
                    self.assertIsNone(engine.last_snapshot)

    def test_busy_check_before_load_never_sends_header(self):
        for profile in PROFILES:
            engine, port, _ = self.make(profile, [(b"\x05", [(0, b"\x05\x04")])])
            with self.assertRaises(ApplicationError) as caught:
                self.call(engine, "LOAD", {"image": IMAGE})
            self.assertEqual(caught.exception.code, "BOARD_NOT_READY")
            self.assertEqual(len(port.writes), 1)
            self.assertIsNone(engine.context)

    def test_pc003_wide_invalid_size_header_is_transmitted_without_allocating_image(self):
        class WideLength(bytes):
            def __len__(self):
                return 2**32

        for profile in PROFILES:
            engine, port, _ = self.make(
                profile,
                [
                    (b"\x05", [(0, b"\x05\x03")]),
                    (bytes.fromhex("010000000001"), [(0, b"\x01\x06")]),
                ],
            )
            with self.assertRaises(ApplicationError) as caught:
                self.call(engine, "LOAD", {"image": WideLength()})
            self.assertEqual(caught.exception.code, "LOAD_REJECTED")
            self.assertEqual(port.writes[-1][1], bytes.fromhex("010000000001"))

    def test_pc007_maximum_memory_and_list_deadline_for_each_profile(self):
        for profile, count in (("REFERENCE", 2048), ("ALT_1000", 1000)):
            fixed = bytearray(literal())
            fixed[225:230] = count.to_bytes(5, "little")
            memory = b"".join(
                address.to_bytes(4, "little") + bytes([address % 256]) for address in range(count)
            )
            for offset, okay in ((-0.001, True), (0.001, False)):
                delay = list_milliseconds(count) / 1000 + offset
                engine, _, _ = self.make(profile, [(b"\x03", [(0, bytes(fixed)), (delay, memory)])])
                if okay:
                    snapshot = self.call(engine, "STEP")["snapshot"]
                    self.assertEqual(snapshot["used_count"], count)
                    self.assertEqual(
                        snapshot["memory"][-1], {"address": count - 1, "value": (count - 1) % 256}
                    )
                else:
                    with self.assertRaises(ApplicationError):
                        self.call(engine, "STEP")
                    self.assertIsNone(engine.last_snapshot)

    def test_pc007_decoding_time_does_not_extend_memory_reception_deadline(self):
        for profile in PROFILES:
            fixed = bytearray(literal())
            fixed[225:230] = (2).to_bytes(5, "little")
            memory = bytes.fromhex("00000000340100000000")
            engine, _, clock = self.make(profile, [(b"\x03", [(0, bytes(fixed)), (0.25, memory)])])

            def slow_decode(*args):
                clock.advance(clock() + 0.1)
                return decode_fixed(*args)

            with patch("software.viewrv.adapters.serial.decode_fixed", slow_decode):
                with self.assertRaises(ApplicationError):
                    self.call(engine, "STEP")
            self.assertIsNone(engine.last_snapshot)

    def test_pc016_terminal_header_and_body_still_have_deadlines_after_run_limit_ends(self):
        terminal = b"\x02\x0b" + literal()[2:]
        for profile in PROFILES:
            engine, port, _ = self.make(
                profile,
                [(b"\x02", [(0, b"\x02\x01"), (0.09, terminal[:1]), (0.291, terminal[1:])])],
            )
            with self.assertRaises(ApplicationError):
                self.call(engine, "RUN", {"max_seconds": 0.1})
            self.assertEqual(len(port.writes), 1)
            self.assertIsNone(engine.last_snapshot)

    def test_check_ready_busy_and_normal_reset_confirmation(self):
        for profile in PROFILES:
            engine, _, _ = self.make(
                profile,
                [
                    (b"\x05", [(0, b"\x05\x04")]),
                    (b"\x04", [(0.01, b"\x04"), (0.02, b"\x01")]),
                    (b"\x05", [(0, b"\x05\x03")]),
                ],
            )
            self.assertFalse(self.call(engine, "CHECK_READY")["ready"])
            self.assertTrue(engine.checked)
            self.assertEqual(
                self.call(engine, "RESET"), {"reset_status": "confirmed", "ready": True}
            )


class ThreadTests(unittest.IsolatedAsyncioTestCase):
    async def test_cancelled_disconnect_waiter_still_finishes_exchange_and_closes_uart(self):
        entered, release = threading.Event(), threading.Event()
        calls = []

        class Transport:
            def execute(self, operation, parameters, control, progress):
                calls.append(operation)
                if operation == "RUN":
                    entered.set()
                    release.wait(2)
                return {}

            def status(self):
                return {}

            def close(self):
                pass

        service = SerialService(Transport())
        try:
            service.submit("RUN")
            await until(entered.is_set)
            closing = asyncio.create_task(service.disconnect())
            await asyncio.sleep(0.01)
            closing.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await closing
            with self.assertRaises(ApplicationError):
                service.submit("STEP")
            release.set()
            await until(lambda: not service.busy and not service.closing)
            self.assertEqual(calls, ["RUN", "CLOSE"])
        finally:
            release.set()
            await service.shutdown()

    async def test_reservation_survives_dequeue_and_notification_is_processed_on_loop(self):
        entered, release = threading.Event(), threading.Event()
        worker_ids = []
        notices = []
        callback_ids = []

        class Transport:
            def execute(self, operation, parameters, control, progress):
                worker_ids.append(threading.get_ident())
                entered.set()
                release.wait(2)
                return {
                    "operation": operation,
                    "interrupted": control.is_set(),
                    "parameters": parameters,
                }

            def status(self):
                return {"connection_status": "closed"}

            def close(self):
                worker_ids.append(threading.get_ident())

        def notified(notice):
            callback_ids.append(threading.get_ident())
            notices.append(notice)
            with self.assertRaises(ApplicationError):
                service.submit("STEP")

        service = SerialService(Transport(), notified)
        try:
            params = {"image": b"captured"}
            future = service.submit("LOAD", params)
            params["image"] = b"later"
            await until(entered.is_set)
            self.assertTrue(service.mailbox.empty(), "The worker has dequeued the request")
            with self.assertRaises(ApplicationError):
                service.submit("STEP")
            release.set()
            result = await future
            self.assertEqual(result["parameters"]["image"], b"captured")
            self.assertEqual(callback_ids, [threading.get_ident()])
            first = service.thread.ident
            await service.request("CLOSE")
            await service.request("OPEN")
            self.assertEqual(service.thread.ident, first)
            self.assertTrue(all(notice["observed_at"] <= time.monotonic() for notice in notices))
        finally:
            release.set()
            await service.shutdown()
        self.assertEqual(len(set(worker_ids)), 1)
        self.assertNotEqual(worker_ids[0], threading.get_ident())
        self.assertFalse(service.thread.is_alive())

    async def test_cancelled_waiter_keeps_operation_and_fresh_control_per_request(self):
        entered, release = threading.Event(), threading.Event()
        controls = []

        class Transport:
            def execute(self, operation, parameters, control, progress):
                controls.append(control)
                entered.set()
                release.wait(2)
                return {}

            def status(self):
                return {}

            def close(self):
                pass

        service = SerialService(Transport())
        try:
            waiter = asyncio.create_task(service.request("RUN"))
            await until(entered.is_set)
            waiter.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await waiter
            self.assertTrue(service.busy)
            with self.assertRaises(ApplicationError):
                service.submit("STEP")
            service.interrupt()
            self.assertTrue(controls[0].is_set())
            release.set()
            await until(lambda: not service.busy)
            await service.request("STEP")
            self.assertIsNot(controls[0], controls[1])
            self.assertFalse(controls[1].is_set())
        finally:
            release.set()
            await service.shutdown()

    async def test_pc024_disconnect_waits_for_load_step_or_run_terminal_and_resets_only_running(
        self,
    ):
        for profile in PROFILES:
            for operation, phase in (
                ("LOAD", "load_header"),
                ("LOAD", "load_done"),
                ("STEP", "step_header"),
                ("STEP", "debug_fixed"),
                ("RUN", "run_execution"),
                ("RUN", "debug_fixed"),
            ):
                with self.subTest(profile=profile, operation=operation, phase=phase):
                    clock = Clock()
                    entered, release = threading.Event(), threading.Event()
                    if operation == "LOAD":
                        script = [
                            (b"\x05", [(0, b"\x05\x03")]),
                            (load_header(8), [(0, b"\x01\x01")]),
                            (IMAGE, [(0.01, b"\x01\x02")]),
                        ]
                    elif operation == "STEP":
                        script = [(b"\x03", [(0, literal())])]
                    elif phase == "debug_fixed":
                        script = [(b"\x02", [(0, b"\x02\x01\x02\x0b" + literal()[2:])])]
                    else:
                        script = [(b"\x02", [(0, b"\x02\x01")]), (b"\x04", [(0, b"\x04\x01")])]
                    port = ScriptedPort(clock, script)
                    engine = SerialTransport(profile, lambda name: port, clock)
                    engine.prepared()
                    engine.port = port
                    engine.port_name = "controlled"
                    read = port.read

                    def gated(size):
                        if engine.phase == phase and not release.is_set():
                            entered.set()
                            if not release.wait(min(0.05, port.timeout)):
                                clock.advance(clock() + min(0.05, port.timeout))
                                return b""
                        return read(size)

                    port.read = gated
                    service = SerialService(engine)
                    try:
                        future = service.submit(
                            operation, {"image": IMAGE} if operation == "LOAD" else {}
                        )
                        await until(entered.is_set)
                        closing = asyncio.create_task(service.disconnect())
                        await asyncio.sleep(0.01)
                        with self.assertRaises(ApplicationError):
                            service.submit("STEP")
                        release.set()
                        await closing
                        result = await future
                        if operation in {"STEP", "RUN"} and phase != "run_execution":
                            self.assertIsNotNone(result["snapshot"])
                        self.assertEqual(port.closed, True)
                        self.assertFalse(port.script)
                        self.assertTrue(
                            service.thread.is_alive(), "Closing UART must not terminate its worker"
                        )
                    finally:
                        release.set()
                        await service.shutdown()

    async def test_shutdown_of_live_run_resolves_reset_before_thread_exit(self):
        clock = Clock()
        port = ScriptedPort(clock, [(b"\x02", [(0, b"\x02\x01")]), (b"\x04", [(0, b"\x04\x01")])])
        engine = SerialTransport("REFERENCE", lambda name: port, clock)
        engine.prepared()
        engine.port = port
        accepted = asyncio.Event()
        service = SerialService(
            engine,
            lambda notice: (
                accepted.set()
                if notice["kind"] == "progress" and notice["data"].get("phase") == "run_accepted"
                else None
            ),
        )
        future = service.submit("RUN")
        await asyncio.wait_for(accepted.wait(), 2)
        await service.shutdown()
        self.assertEqual((await future)["reset_status"], "confirmed")
        self.assertTrue(port.closed)
        self.assertFalse(service.thread.is_alive())


@unittest.skipUnless(os.name == "posix", "PTY verification requires POSIX; Windows remains pending")
class NativeSerialTests(unittest.IsolatedAsyncioTestCase):
    async def exchange(self, profile, script, actions):
        master, slave = os.openpty()
        path = os.ttyname(slave)
        errors = []
        observed = []
        master_closed = threading.Event()

        def board():
            try:
                for expected, response in script:
                    received = bytearray()
                    deadline = time.monotonic() + 3
                    while len(received) < len(expected):
                        if time.monotonic() >= deadline:
                            raise AssertionError(f"Board timed out for {expected.hex()}")
                        readable, _, _ = select.select([master], [], [], 0.05)
                        if readable:
                            received.extend(os.read(master, len(expected) - len(received)))
                    assert bytes(received) == expected, (received, expected)
                    observed.append(bytes(received))
                    if response is None:
                        os.close(master)
                        master_closed.set()
                        return
                    # Real system calls, fragmented headers/body; no injected port.
                    for offset in range(0, len(response), 37):
                        os.write(master, response[offset : offset + 37])
                        time.sleep(0.001)
            except Exception as error:
                errors.append(error)

        peer = threading.Thread(target=board, name="viewrv-test-board")
        peer.start()
        engine = SerialTransport(profile)
        service = SerialService(engine)
        try:
            await service.request("PREPARED")
            await service.request("OPEN", {"port": path})
            self.assertEqual(engine.port.baudrate, 19200)
            self.assertEqual(
                (engine.port.bytesize, engine.port.parity, engine.port.stopbits), (8, "N", 1)
            )
            await actions(service)
            await service.disconnect()
        finally:
            await service.shutdown()
            os.close(slave)
            while peer.is_alive():
                await asyncio.sleep(0.01)
            if not master_closed.is_set():
                os.close(master)
        self.assertFalse(errors, errors)
        self.assertEqual(len(observed), len(script))

    async def test_pyserial_real_pty_load_step_run_reset_in_both_profiles(self):
        for profile in PROFILES:
            script = [
                (b"\x05", b"\x05\x03"),
                (b"\x05", b"\x05\x03"),
                (bytes.fromhex("010800000000"), b"\x01\x01"),
                (IMAGE, b"\x01\x02"),
                (b"\x03", literal()),
                (b"\x02", b"\x02\x01\x02\x0b" + literal()[2:]),
                (b"\x04", b"\x04\x01"),
                (b"\x05", b"\x05\x03"),
            ]

            async def actions(service):
                self.assertEqual((await service.request("LOAD", {"image": IMAGE}))["byte_count"], 8)
                self.assertEqual((await service.request("STEP"))["snapshot"]["pc"], 0x12345678)
                self.assertEqual((await service.request("RUN"))["snapshot"]["global_state"], 11)
                self.assertEqual((await service.request("RESET"))["reset_status"], "confirmed")

            await self.exchange(profile, script, actions)

    async def test_pyserial_load_timeout_then_recovery_does_not_cancel_next_query_or_replay_image(
        self,
    ):
        for profile in PROFILES:
            script = [
                (b"\x05", b"\x05\x03"),
                (b"\x05", b"\x05\x03"),
                (load_header(8), b""),
                (b"\x05", b"\x05\x03"),
                (b"\x03", literal()),
            ]

            async def actions(service):
                with self.assertRaises(ApplicationError) as caught:
                    await service.request("LOAD", {"image": IMAGE})
                self.assertEqual(caught.exception.code, "LOAD_RESULT_UNCONFIRMED")
                self.assertTrue((await service.request("RECOVER"))["ready"])
                self.assertIsNotNone((await service.request("STEP"))["snapshot"])

            await self.exchange(profile, script, actions)

    async def test_pyserial_peer_loss_reports_uncertainty_without_snapshot(self):
        for profile in PROFILES:
            script = [(b"\x05", b"\x05\x03"), (b"\x03", None)]

            async def actions(service):
                with self.assertRaises(ApplicationError) as caught:
                    await service.request("STEP")
                self.assertEqual(caught.exception.code, "STEP_RESULT_UNCONFIRMED")
                self.assertIsNone(service.transport.last_snapshot)
                self.assertIsNotNone(service.transport.context)

            await self.exchange(profile, script, actions)
