"""PC-I05: durable JSONL, independent recovery, corruption and write failure."""

import json
import os
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from software.tests.viewrv.serial_fixture import literal
from software.viewrv.adapters.files import FileStorage
from software.viewrv.contracts import ApplicationError
from software.viewrv.core.evidence import RecordWriter
from software.viewrv.core.protocol import decode_fixed, decode_memory
from software.viewrv.core.records import parse_record
from software.viewrv.core.storage import StorageQueue


def start(mode="debug"):
    return {
        "mode": mode,
        "program_id": str(uuid4()),
        "source_version": str(uuid4()),
        "source_text": "# ñ\naddi x1,x0,5\nhalt\n",
        "author": None,
        "started_at": "2026-10-30T16:00:00.000Z",
        "processor_profile": {
            "profile_id": "tp3-riscv",
            "revision": 1,
            "memory_profile": "REFERENCE",
        },
    }


def observation(index=1, state=5):
    wire = literal("TEST-UART-007/C007")
    capture = decode_memory(decode_fixed(wire[2:230], "REFERENCE", "STEP", 2), b"", "REFERENCE")
    capture["global_state"] = state
    return {
        "step_index": index,
        "snapshot": capture,
        "breakpoint_hits": [],
        "interpretation": {
            "instruction_locations": [
                {"latch": label, "pc": capture[key]["pc"], "line": None}
                for label, key in (
                    ("IF/ID", "if_id"),
                    ("ID/EX", "id_ex"),
                    ("EX/MEM", "ex_mem"),
                    ("MEM/WB", "mem_wb"),
                )
                if capture[key]["valid"]
            ],
            "changes": {
                "previous_step_index": index - 1 if index > 1 else None,
                "register_changes": [],
                "memory_changes": [],
                "latch_changes": [],
                "global_changes": [],
            },
            "cycle_activity": [
                {"stage": stage, "status": "unavailable", "pc": None, "blocks": []}
                for stage in ("IF", "ID", "EX", "MEM", "WB")
            ],
            "limitations": [
                {
                    "code": "FIXTURE_ACTIVITY_UNAVAILABLE",
                    "section": "cycle_activity",
                    "message": "Controlled record fixture; educational participation unavailable.",
                }
            ],
        },
    }


def end(count, status="interrupted"):
    return {
        "execution_status": status,
        "outcome": {
            "ended_at": "2026-10-30T16:00:01.000Z",
            "interruption_reason": "user_request" if status == "interrupted" else None,
            "failure": None,
        },
        "observation_count": count,
        "limitations": [],
    }


def unit(identity, kind, data):
    return {"schema_version": 1, "session_id": identity, "record_type": kind, "data": data}


def lines(*units):
    return b"".join((json.dumps(value, ensure_ascii=False) + "\n").encode() for value in units)


class RecordRecoveryTests(unittest.TestCase):
    def test_inconsistent_measured_references_and_invalid_previous_values_are_not_valid_units(self):
        """TEST-PC-022: inconsistent measured references and invalid previous values are not valid units."""
        identity = str(uuid4())
        opening = unit(identity, "start", start())
        invalid = []
        value = observation()
        value["breakpoint_hits"] = [{"pc": 0, "line": 1, "latch": "IF/ID"}]
        invalid.append(value)
        value = observation()
        value["interpretation"]["instruction_locations"][0]["pc"] = 0
        invalid.append(value)
        value = observation()
        value["interpretation"]["changes"]["previous_step_index"] = 1
        invalid.append(value)
        value = observation(2)
        value["interpretation"]["changes"]["register_changes"] = [
            {"register": 1, "previous": "wrong"}
        ]
        invalid.append(value)
        value = observation(2)
        value["interpretation"]["changes"]["latch_changes"] = [
            {"latch": "IF/ID", "field": "valid", "previous": 1}
        ]
        invalid.append(value)
        for value in invalid:
            with self.subTest(value=value):
                record = parse_record(
                    lines(opening, unit(identity, "observation", value)), identity
                )
                self.assertEqual(record["observations"], [])
                self.assertEqual(record["record_status"], "incomplete")

    def setUp(self):
        self.identity = str(uuid4())
        self.opening = unit(self.identity, "start", start())

    def test_complete_record_preserves_source_large_unsigned_values_and_latch_validity(self):
        """TEST-PC-009: complete record preserves source large unsigned values and latch validity."""
        step = observation()
        step["snapshot"]["registers"][31] = 2**32 - 1
        step["snapshot"]["cycle_count"] = str(2**64 - 1)
        step["snapshot"]["if_id"]["valid"] = False
        step["interpretation"]["instruction_locations"] = [
            item
            for item in step["interpretation"]["instruction_locations"]
            if item["latch"] != "IF/ID"
        ]
        content = lines(
            self.opening,
            unit(self.identity, "observation", step),
            unit(self.identity, "end", end(1)),
        )
        record = parse_record(content, self.identity)
        self.assertEqual(record["record_status"], "complete")
        self.assertEqual(record["start"], self.opening["data"])
        self.assertEqual(record["observations"], [step])

    def test_interrupted_zero_observations_is_a_complete_record(self):
        """TEST-PC-009: interrupted zero observations is a complete record."""
        record = parse_record(
            lines(self.opening, unit(self.identity, "end", end(0))), self.identity
        )
        self.assertEqual(record["record_status"], "complete")
        self.assertEqual(record["observations"], [])
        self.assertEqual(record["end"]["observation_count"], 0)

    def test_partial_last_line_keeps_prior_units_without_claiming_active_execution(self):
        """TEST-PC-022: partial last line keeps prior units without claiming active execution."""
        record = parse_record(
            lines(self.opening, unit(self.identity, "observation", observation()))
            + b'{"schema_version":',
            self.identity,
        )
        self.assertEqual(record["record_status"], "incomplete")
        self.assertEqual(record["execution_status"], "unknown")
        self.assertEqual(len(record["observations"]), 1)
        self.assertIsNone(record["end"])

    def test_invalid_middle_unit_and_missing_steps_keep_original_indices(self):
        """TEST-PC-022: invalid middle unit and missing steps keep original indices."""
        content = (
            lines(self.opening, unit(self.identity, "observation", observation()))
            + b"broken JSON\n"
        )
        content += lines(
            unit(self.identity, "observation", observation(3)), unit(self.identity, "end", end(3))
        )
        record = parse_record(content, self.identity)
        self.assertEqual([value["step_index"] for value in record["observations"]], [1, 3])
        self.assertEqual(record["record_status"], "incomplete")

    def test_other_identity_schema_duplicate_indices_and_malformed_snapshots_are_discarded(self):
        """TEST-PC-009: other identity schema duplicate indices and malformed snapshots are discarded."""
        bad = [
            unit(str(uuid4()), "observation", observation(2)),
            {**unit(self.identity, "observation", observation(2)), "schema_version": True},
            unit(self.identity, "observation", observation(1)),
        ]
        for field, value in (
            ("registers", [0]),
            ("cycle_count", 2**64 - 1),
            ("image_valid", 1),
            ("used_count", True),
        ):
            step = observation(2)
            step["snapshot"][field] = value
            bad.append(unit(self.identity, "observation", step))
        record = parse_record(
            lines(
                self.opening,
                unit(self.identity, "observation", observation()),
                *bad,
                unit(self.identity, "end", end(1)),
            ),
            self.identity,
        )
        self.assertEqual(len(record["observations"]), 1)
        self.assertEqual(record["record_status"], "incomplete")

    def test_without_valid_start_rejects_instead_of_inventing_source(self):
        """TEST-PC-022: without valid start rejects instead of inventing source."""
        for opening in (
            b"",
            lines(unit(self.identity, "observation", observation())),
            lines({**self.opening, "schema_version": 2}),
        ):
            with self.subTest(opening=opening), self.assertRaises(ApplicationError) as caught:
                parse_record(opening, self.identity, "record.jsonl")
            self.assertEqual(caught.exception.code, "RECORD_INVALID")

    def test_terminal_survives_missing_or_contradictory_end(self):
        """TEST-PC-022: terminal survives missing or contradictory end."""
        for suffix in (b"", lines(unit(self.identity, "end", end(1, "finished")))):
            record = parse_record(
                lines(self.opening, unit(self.identity, "observation", observation(state=11)))
                + suffix,
                self.identity,
            )
            self.assertEqual(record["execution_status"], "fault")
            self.assertEqual(record["record_status"], "incomplete")
            self.assertIsNone(record["end"])

    def test_known_write_failure_is_not_erased_by_a_saved_end(self):
        """TEST-PC-021: known write failure is not erased by a saved end."""
        closing = end(0)
        closing["limitations"] = [
            {"code": "RECORD_WRITE_FAILED", "section": "record", "message": "known failure"}
        ]
        self.assertEqual(
            parse_record(lines(self.opening, unit(self.identity, "end", closing)), self.identity)[
                "record_status"
            ],
            "failed",
        )

    def test_run_has_only_one_terminal_observation_and_no_step_fields(self):
        """TEST-PC-009: run has only one terminal observation and no step fields."""
        self.opening["data"]["mode"] = "run"
        value = {"snapshot": observation(state=10)["snapshot"]}
        good = parse_record(
            lines(
                self.opening,
                unit(self.identity, "observation", value),
                unit(self.identity, "end", end(1, "finished")),
            ),
            self.identity,
        )
        self.assertEqual(good["record_status"], "complete")
        bad = parse_record(
            lines(self.opening, unit(self.identity, "observation", observation(state=10))),
            self.identity,
        )
        self.assertEqual(bad["observations"], [])

    def test_non_utf8_and_duplicate_json_keys_do_not_destroy_other_units(self):
        """TEST-PC-022: non utf8 and duplicate json keys do not destroy other units."""
        content = (
            lines(self.opening)
            + b'{"schema_version":1,"schema_version":1}\n\xff\n'
            + lines(unit(self.identity, "end", end(0)))
        )
        record = parse_record(content, self.identity)
        self.assertEqual(record["record_status"], "incomplete")
        self.assertIsNotNone(record["end"])


class RecordFilesTests(unittest.IsolatedAsyncioTestCase):
    async def test_summary_enumeration_retains_only_last_capture_but_validates_full_count(self):
        """TEST-PC-009: summary enumeration retains only last capture but validates full count."""
        writer = RecordWriter(self.identity, self.queue, self.storage, True)
        writer.append("start", start())
        for index in range(1, 6):
            writer.append("observation", observation(index))
        writer.append("end", end(5))
        await writer.finish()
        records, limitations = self.storage.list_records()
        self.assertEqual(limitations, [])
        self.assertEqual(records[0]["record_status"], "complete")
        self.assertEqual([value["step_index"] for value in records[0]["observations"]], [5])
        self.assertEqual(len(self.storage.read_record(self.identity)["observations"]), 5)

    async def test_inaccessible_record_directory_is_reported_instead_of_an_empty_enumeration(self):
        """TEST-PC-022: inaccessible record directory is reported instead of an empty enumeration."""
        with patch.object(
            Path, "iterdir", side_effect=PermissionError("Controlled record directory denied")
        ):
            records, limitations = self.storage.list_records()
        self.assertEqual(records, [])
        self.assertEqual(limitations[0]["code"], "RECORD_READ_FAILED")

    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.storage = FileStorage(self.root / "data", self.root / "config", self.root / "state")
        self.queue = StorageQueue()
        self.identity = str(uuid4())

    async def asyncTearDown(self):
        await self.queue.close()
        self.temp.cleanup()

    async def test_incremental_durable_units_and_existing_file_is_never_overwritten(self):
        """TEST-PC-009: incremental durable units and existing file is never overwritten."""
        writer = RecordWriter(self.identity, self.queue, self.storage, True)
        writer.append("start", start())
        await writer.finish()
        self.assertEqual(self.storage.read_record(self.identity)["record_status"], "incomplete")
        writer.append("observation", observation())
        writer.append("end", end(1))
        await writer.finish()
        self.assertEqual(writer.status, "complete")
        self.assertEqual(self.storage.read_record(self.identity)["record_status"], "complete")
        path = self.storage.records / f"{self.identity}.jsonl"
        if os.name != "nt":
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        original = path.read_bytes()
        with self.assertRaises(FileExistsError):
            self.storage.append_record(unit(self.identity, "start", start()))
        self.assertEqual(path.read_bytes(), original)

    async def test_first_write_failure_stops_all_queued_and_later_writes(self):
        """TEST-PC-021: first write failure stops all queued and later writes."""
        calls = []

        def failed(value):
            calls.append(deepcopy(value))
            raise PermissionError("controlled failure")

        self.storage.append_record = failed
        writer = RecordWriter(self.identity, self.queue, self.storage, True)
        writer.append("start", start())
        writer.append("observation", observation())
        writer.append("end", end(1))
        await writer.finish()
        writer.append("observation", observation(2))
        await writer.finish()
        self.assertEqual(len(calls), 1)
        self.assertEqual(writer.status, "failed")
        self.assertEqual(writer.limitations[0]["code"], "RECORD_WRITE_FAILED")
        self.assertEqual(await self.queue.submit(lambda: (lambda: 42, ())), 42)

    async def test_disabled_writer_does_not_create_a_file(self):
        """TEST-PC-009: disabled writer does not create a file."""
        writer = RecordWriter(self.identity, self.queue, self.storage, False)
        writer.append("start", start())
        writer.append("end", end(0))
        await writer.finish()
        self.assertEqual(writer.status, "disabled")
        self.assertFalse(self.storage.records.exists())

    async def test_partial_enumeration_recovers_valid_record_and_reports_invalid_one(self):
        """TEST-PC-022: partial enumeration recovers valid record and reports invalid one."""
        self.storage.append_record(unit(self.identity, "start", start()))
        (self.storage.records / f"{uuid4()}.jsonl").write_bytes(b"bad JSON\n")
        records, limitations = self.storage.list_records()
        self.assertEqual([value["session_id"] for value in records], [self.identity])
        self.assertEqual(limitations[0]["code"], "RECORD_INVALID")
