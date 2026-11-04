"""PC-I02: storage faults, recovery and preferences (TEST-PC-010/012/020/026)."""

import asyncio
import json
import os
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from software.tests.viewrv.controlled import ControlledAssembler
from software.tests.viewrv.record_cases import RecordFilesTests as RecordFilesTests
from software.tests.viewrv.record_cases import RecordRecoveryTests as RecordRecoveryTests
from software.viewrv.adapters.files import DEFAULT_PREFERENCES, FileStorage, durable_write
from software.viewrv.contracts import ApplicationError
from software.viewrv.core.application import Application
from software.viewrv.core.storage import StorageQueue


async def until(predicate, timeout=3):
    async with asyncio.timeout(timeout):
        while not predicate():
            await asyncio.sleep(0.01)


class RecordingStorage(FileStorage):
    def __init__(self, root):
        super().__init__(root / "data", root / "config")
        self.recovery_writes = []
        self.source_writes = []
        self.fail_recovery = False
        self.fail_source = False
        self.fail_preferences = False
        self.fail_delete = False
        self.source_entered = threading.Event()
        self.source_release = threading.Event()
        self.source_release.set()

    def write_recovery(self, value):
        if self.fail_recovery:
            raise PermissionError("Controlled recovery failure")
        self.recovery_writes.append(dict(value))
        return super().write_recovery(value)

    def write_source(self, path, text, allow_create=False):
        self.source_entered.set()
        if not self.source_release.wait(10):
            raise TimeoutError("Controlled source gate not released")
        if self.fail_source:
            raise PermissionError("Controlled source failure")
        self.source_writes.append((path, text))
        return super().write_source(path, text, allow_create)

    def write_preferences(self, value):
        if self.fail_preferences:
            raise PermissionError("Controlled preference failure")
        return super().write_preferences(value)

    def delete_recovery(self, identity):
        if self.fail_delete:
            raise PermissionError("Controlled delete failure")
        return super().delete_recovery(identity)


class FilesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.storage = FileStorage(self.root / "data", self.root / "config")

    def test_pc_010_recovery_is_additional_json_and_preserves_exact_text(self):
        identity, version = str(uuid4()), str(uuid4())
        snapshot = {
            "schema_version": 1,
            "program_id": identity,
            "source_version": version,
            "text": "# ñ\r\naddi x1,x0,5\n",
            "source_path": None,
            "is_open": True,
            "example_id": None,
        }
        path = Path(self.storage.write_recovery(snapshot))
        self.assertEqual(json.loads(path.read_text()), snapshot)
        self.assertEqual(self.storage.read_recoveries(), ([snapshot], []))
        self.assertFalse(list(path.parent.glob("*.tmp")))

    def test_pc_010_failed_replace_keeps_previous_complete_copy(self):
        path = self.root / "program.s"
        path.write_text("old\n")
        with patch(
            "software.viewrv.adapters.files.publish_file",
            side_effect=OSError("Controlled replace error"),
        ):
            with self.assertRaises(OSError):
                durable_write(path, "new\n")
        self.assertEqual(path.read_text(), "old\n")
        self.assertFalse(list(self.root.glob("*.tmp")))

    @unittest.skipIf(os.name == "nt", "Linux directory sync order")
    def test_pc_010_confirmation_requires_file_and_directory_sync(self):
        path = self.root / "program.s"
        calls = []
        real_sync, real_replace = os.fsync, os.replace
        with (
            patch(
                "software.viewrv.adapters.files.os.fsync",
                side_effect=lambda fd: (calls.append("sync"), real_sync(fd))[1],
            ),
            patch(
                "software.viewrv.adapters.files.os.replace",
                side_effect=lambda a, b: (calls.append("replace"), real_replace(a, b))[1],
            ),
        ):
            durable_write(path, "current\n")
        self.assertEqual(calls, ["sync", "replace", "sync"])

    def test_pc_010_invalid_recovery_is_preserved_without_inventing_programs(self):
        self.storage.recovery.mkdir(parents=True)
        invalid = self.storage.recovery / f"{uuid4()}.json"
        invalid.write_bytes(b"{partial")
        snapshots, warnings = self.storage.read_recoveries()
        self.assertEqual(snapshots, [])
        self.assertEqual(warnings[0]["code"], "RECOVERY_INVALID")
        self.assertEqual(invalid.read_bytes(), b"{partial")

    def test_pc_012_preferences_missing_invalid_and_original_backup(self):
        self.assertEqual(self.storage.read_preferences(), (DEFAULT_PREFERENCES, []))
        self.storage.preferences.parent.mkdir(parents=True)
        original = b"{invalid\xff"
        self.storage.preferences.write_bytes(original)
        self.assertEqual(self.storage.read_preferences()[1][0]["code"], "PREFERENCES_INVALID")
        self.storage.write_preferences({**DEFAULT_PREFERENCES, "default_author": "Franco"})
        (backup,) = self.storage.preferences.parent.glob("preferences.invalid-*.json")
        self.assertEqual(backup.read_bytes(), original)
        self.assertEqual(self.storage.read_preferences()[0]["default_author"], "Franco")

    def test_pc_020_missing_source_is_not_automatically_recreated(self):
        path = self.root / "missing.s"
        with self.assertRaises(FileNotFoundError):
            self.storage.write_source(str(path), "text", False)
        self.assertFalse(path.exists())
        self.storage.write_source(str(path), "text", True)
        self.assertEqual(path.read_text(), "text")

    def test_pc_002_source_errors_keep_distinct_codes_and_paths(self):
        path = self.root / "file.s"
        with self.assertRaises(ApplicationError) as caught:
            self.storage.read_source(str(path))
        self.assertEqual(caught.exception.code, "SOURCE_NOT_FOUND")
        path.write_bytes(b"\xff")
        with self.assertRaises(ApplicationError) as caught:
            self.storage.read_source(str(path))
        self.assertEqual(caught.exception.code, "SOURCE_ENCODING_INVALID")
        self.assertEqual(caught.exception.details["path"], str(path))


class ConservationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.storage = RecordingStorage(self.root)
        self.assembler = ControlledAssembler()
        self.application = Application(str(uuid4()))
        await self.application.initialize(self.storage, self.assembler)
        self.service = self.application.program_service
        self.owner = self.application.register("gui", str(uuid4()))["work_id"]
        self.gates = []

    async def asyncTearDown(self):
        for gate in self.gates:
            gate.set()
        self.storage.source_release.set()
        self.assembler.release.set()
        await self.application.shutdown()
        self.temp.cleanup()

    def create(self):
        return self.service.get(self.service.create(self.owner)["program_id"])

    def edit(self, program, text):
        version = str(uuid4())
        self.service.update(self.owner, program.program_id, version, text)
        return version

    async def test_pc_010_source_autosave_respects_earlier_read_of_same_file(self):
        path = self.root / "ordered.s"
        path.write_text("A")
        p = self.service.get((await self.service.open(self.owner, str(path)))["program_id"])
        await self.service.flush(p)
        gate, entered = threading.Event(), threading.Event()
        self.gates.append(gate)

        def blocker():
            entered.set()
            gate.wait(10)

        blocked = self.service.queue.submit(lambda: (blocker, ()))
        await until(entered.is_set)
        read = self.service.queue.submit(
            lambda: (self.storage.read_source, (str(path),)), keys=(str(path),)
        )
        self.edit(p, "B")
        p.wake.set()
        await until(lambda: len(self.service.queue.pending) >= 3)
        gate.set()
        await blocked
        self.assertEqual((await read)[1], "A")
        await self.service.flush(p)
        self.assertEqual(path.read_text(), "B")

    async def test_pc_010_autosave_deadline_is_not_reset_by_continuous_edits(self):
        p = self.create()
        started = asyncio.get_running_loop().time()
        for index in range(7):
            self.edit(p, f"# edit {index}\n")
            await asyncio.sleep(0.15)
        await until(lambda: p.recovery_version is not None)
        self.assertLess(asyncio.get_running_loop().time() - started, 1.9)
        self.assertTrue(self.storage.recovery_writes)
        await self.service.flush(p)
        self.assertEqual(p.recovery_version, p.source_version)

    async def test_pc_026_reopened_program_cannot_skip_conservation_after_previous_owner_finishes(
        self,
    ):
        p = self.create()
        self.edit(p, "previously conserved")
        await self.service.close(self.owner, p.program_id, p.source_version, p.source_text)
        self.application.register("cli")
        await self.application.finish_registered(self.owner)
        following = self.application.register("gui", str(uuid4()))["work_id"]
        await self.service.recover(following, p.program_id)
        self.storage.fail_recovery = True
        with self.assertRaises(ApplicationError) as caught:
            await self.application.finish_registered(following)
        self.assertEqual(caught.exception.code, "CODE_SAVE_FAILED")
        self.assertIn(following, self.application.works)
        self.storage.fail_recovery = False
        await self.application.finish_registered(following)

    async def test_pc_010_pending_saves_take_latest_revision_per_program(self):
        gate = threading.Event()
        self.gates.append(gate)
        entered = threading.Event()

        def blocker():
            entered.set()
            gate.wait(10)

        blocked = self.service.queue.submit(lambda: (blocker, ()))
        await until(entered.is_set)
        first, second = self.create(), self.create()
        first.wake.set()
        second.wake.set()
        await until(lambda: len(self.service.queue.pending) >= 2)
        self.edit(first, "B")
        final = self.edit(first, "C")
        other = self.edit(second, "independent")
        gate.set()
        await blocked
        await self.service.flush(first)
        await self.service.flush(second)
        self.assertEqual(first.recovery_version, final)
        self.assertEqual(second.recovery_version, other)
        writes = [
            row for row in self.storage.recovery_writes if row["program_id"] == first.program_id
        ]
        self.assertTrue(all(row["source_version"] == final for row in writes))

    async def test_pc_010_old_confirmation_does_not_mark_new_revision_saved(self):
        path = self.root / "source.s"
        path.write_text("A")
        p = self.service.get((await self.service.open(self.owner, str(path)))["program_id"])
        self.storage.source_release.clear()
        self.gates.append(self.storage.source_release)
        first = self.edit(p, "B")
        p.wake.set()
        await until(self.storage.source_entered.is_set)
        second = self.edit(p, "C")
        self.assertNotEqual(p.saved_version, second)
        self.storage.source_release.set()
        await self.service.flush(p)
        self.assertIn((str(path), "B"), self.storage.source_writes)
        self.assertEqual(path.read_text(), "C")
        self.assertEqual(p.saved_version, second)
        self.assertNotEqual(first, second)

    async def test_pc_017_old_explicit_save_cannot_falsely_confirm_newer_text(self):
        path = self.root / "program.s"
        path.write_text("A")
        p = self.service.get((await self.service.open(self.owner, str(path)))["program_id"])
        original = p.source_version
        current = self.edit(p, "B")
        await self.service.flush(p)
        self.assertEqual(path.read_text(), "B")
        subscription = self.application.subscribe(self.owner)
        await self.service.save(self.owner, p.program_id, original, "A")
        self.assertEqual(path.read_text(), "B")
        self.assertEqual(p.saved_version, current)
        messages = []
        while not subscription.pending.empty():
            messages.append(subscription.pending.get_nowait())
        self.assertTrue(
            any(
                row.get("data", {}).get("programs", [{}])[0].get("saved_version") == original
                for row in messages
                if row and row.get("data", {}).get("programs")
            )
        )

    async def test_pc_017_save_as_does_not_attribute_old_destination_confirmation_to_new_file(self):
        old = self.root / "old.s"
        old.write_text("A")
        p = self.service.get((await self.service.open(self.owner, str(old)))["program_id"])
        original = p.source_version
        current = self.edit(p, "B")
        await self.service.flush(p)
        new = self.root / "new.s"
        original_write = self.storage.write_source

        def controlled(path, text, allow_create=False):
            if path == str(new) and text == "B":
                raise PermissionError("New destination cannot save B")
            return original_write(path, text, allow_create)

        self.storage.write_source = controlled
        with self.assertRaises(ApplicationError):
            await self.service.save(self.owner, p.program_id, original, "A", str(new))
        self.assertEqual(new.read_text(), "A")
        self.assertEqual(p.source_path, str(new))
        self.assertEqual(p.saved_version, original)
        self.assertEqual(p.recovery_version, current)
        self.storage.write_source = original_write

    async def test_pc_026_storage_failure_blocks_close_and_retry_succeeds(self):
        p = self.create()
        self.edit(p, "recoverable")
        self.storage.fail_recovery = True
        with self.assertRaises(ApplicationError) as caught:
            await self.service.close(self.owner, p.program_id, p.source_version, p.source_text)
        self.assertEqual(caught.exception.code, "CODE_SAVE_FAILED")
        self.assertTrue(p.is_open)
        self.assertEqual(caught.exception.details["failures"][0]["target"], "recovery")
        self.storage.fail_recovery = False
        await self.service.close(self.owner, p.program_id, p.source_version, p.source_text)
        self.assertFalse(p.is_open)
        self.assertFalse(
            json.loads((self.storage.recovery / f"{p.program_id}.json").read_text())["is_open"]
        )

    async def test_pc_026_discard_failure_keeps_program_editable(self):
        p = self.create()
        await self.service.flush(p)
        self.storage.fail_delete = True
        with self.assertRaises(ApplicationError) as caught:
            await self.service.discard(self.owner, p.program_id)
        self.assertEqual(caught.exception.code, "RECOVERY_DELETE_FAILED")
        self.assertIn(p.program_id, self.service.programs)
        self.edit(p, "still editable")
        self.storage.fail_delete = False
        await self.service.discard(self.owner, p.program_id)
        self.assertNotIn(p.program_id, self.service.programs)

    async def test_pc_020_recovery_keeps_missing_association_until_save_as(self):
        path = self.root / "old.s"
        path.write_text("source")
        p = self.service.get((await self.service.open(self.owner, str(path)))["program_id"])
        await self.service.flush(p)
        await self.service.shutdown()
        path.unlink()
        restored = Application(str(uuid4()))
        await restored.initialize(self.storage, self.assembler)
        try:
            recovered = restored.program_service.get(p.program_id)
            self.assertEqual(recovered.source_text, "source")
            self.assertEqual(recovered.source_version, p.source_version)
            self.assertFalse(path.exists())
            other = self.root / "new.s"
            await restored.program_service.save(
                self.owner,
                recovered.program_id,
                recovered.source_version,
                recovered.source_text,
                str(other),
            )
            self.assertEqual(other.read_text(), "source")
            self.assertFalse(path.exists())
        finally:
            await restored.shutdown()

    async def test_pc_012_preference_write_failure_does_not_publish_new_values(self):
        before = self.application.preferences.copy()
        self.storage.fail_preferences = True
        with self.assertRaises(ApplicationError) as caught:
            await self.service.preferences_update(self.owner, {"ui_zoom": 1.25})
        self.assertEqual(caught.exception.code, "PREFERENCES_WRITE_FAILED")
        self.assertEqual(self.application.preferences, before)
        self.storage.fail_preferences = False
        result = await self.service.preferences_update(
            self.owner, {"ui_zoom": 1.25, "default_author": None}
        )
        self.assertEqual(result["preferences"]["ui_zoom"], 1.25)
        for value in (float("nan"), float("inf"), 0.1, True):
            with self.subTest(value=value), self.assertRaises(ApplicationError):
                await self.service.preferences_update(self.owner, {"ui_zoom": value})

    async def test_pc_026_work_finish_requires_save_or_explicit_discard(self):
        p = self.create()
        self.edit(p, "pending")
        other = self.application.register("cli")["work_id"]
        self.storage.fail_recovery = True
        with self.assertRaises(ApplicationError):
            await self.application.execute(
                self.owner, "work finish", lambda: self.application.finish_registered(self.owner)
            )
        self.assertIn(self.owner, self.application.works)
        result = await self.application.execute(
            self.owner, "work finish", lambda: self.application.finish_registered(self.owner, True)
        )
        self.assertEqual(
            result["discarded_sources"],
            [{"program_id": p.program_id, "source_version": p.source_version}],
        )
        self.assertIn(other, self.application.works)
        self.assertFalse(self.application.shutting_down)


class SchedulerTests(unittest.IsolatedAsyncioTestCase):
    async def test_pc_010_code_priority_respects_file_dependencies(self):
        queue = StorageQueue()
        gate, entered = threading.Event(), threading.Event()
        order, threads = [], []

        def operation(name, block=False):
            threads.append(threading.get_ident())
            if block:
                entered.set()
                gate.wait(10)
            order.append(name)

        first = queue.submit(lambda: (operation, ("running", True)), keys=("other",))
        await until(entered.is_set)
        ordinary = queue.submit(lambda: (operation, ("ordinary",)), keys=("other2",))
        dependency = queue.submit(lambda: (operation, ("dependency",)), keys=("file",))
        urgent = queue.submit(lambda: (operation, ("code",)), priority=0, keys=("file",))
        gate.set()
        await asyncio.gather(first, ordinary, dependency, urgent)
        await queue.close()
        self.assertEqual(order, ["running", "ordinary", "dependency", "code"])
        self.assertEqual(len(set(threads)), 1)
        self.assertNotEqual(threads[0], threading.get_ident())
