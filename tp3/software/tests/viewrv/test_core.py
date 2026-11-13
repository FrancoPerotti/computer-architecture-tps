"""PC-I01: variantes de TEST-PC-008, TEST-PC-015 y TEST-PC-017."""

import asyncio
import tempfile
import unittest
from pathlib import Path
from uuid import uuid4

from software.tests.viewrv.controlled import ControlledAssembler, Result
from software.tests.viewrv.session_cases import (
    RealAssemblerSessionTests as RealAssemblerSessionTests,
)
from software.tests.viewrv.session_cases import SessionTests as SessionTests
from software.tests.viewrv.test_storage import RecordingStorage, until
from software.viewrv.adapters.assembler import PythonAssembler
from software.viewrv.contracts import STATE_BLOCKS, ApplicationError
from software.viewrv.core.application import Application


class WorkAndStateTests(unittest.TestCase):
    def setUp(self):
        self.application = Application(str(uuid4()))

    def gui(self):
        return self.application.register("gui", str(uuid4()))["work_id"]

    def test_pc_008_query_does_not_register_or_claim_board(self):
        before = self.application.state()
        self.assertEqual(
            self.application.cli_status(),
            {
                "work_id": None,
                "pending_commands": [],
                "owns_board": False,
                "session_id": None,
                "debug_open": False,
            },
        )
        self.assertEqual(before, self.application.state())
        self.assertEqual(self.application.revision, 0)

    def test_pc_008_registration_is_idempotent_per_interface(self):
        reference = str(uuid4())
        a = self.application.register("cli")
        b = self.application.register("gui", reference)
        self.assertEqual(a, self.application.register("cli"))
        self.assertEqual(b, self.application.register("gui", reference))
        self.assertNotEqual(a, b)
        self.assertNotEqual(b["work_id"], self.gui())
        self.assertEqual(self.application.revision, 3)
        self.assertFalse(any(work["owns_board"] for work in self.application.works.values()))

    def test_pc_017_finishing_gui_keeps_cli_and_other_gui(self):
        cli = self.application.register("cli")["work_id"]
        gui, other = self.gui(), self.gui()
        result = self.application.finish(gui)
        self.assertEqual(
            result, {"work_id": gui, "finished": True, "discarded_sources": [], "warnings": []}
        )
        self.assertEqual(set(self.application.works), {cli, other})
        self.assertFalse(self.application.shutting_down)
        self.application.finish(cli)
        self.assertFalse(self.application.shutting_down)
        self.application.finish(other)
        self.assertTrue(self.application.shutting_down)
        with self.assertRaises(ApplicationError) as caught:
            self.application.register("cli")
        self.assertEqual(caught.exception.code, "CORE_SHUTTING_DOWN")

    def test_pc_017_missing_work_does_not_finish_another(self):
        cli = self.application.register("cli")["work_id"]
        with self.assertRaises(ApplicationError) as caught:
            self.application.finish(str(uuid4()))
        self.assertEqual(caught.exception.code, "WORK_NOT_ACTIVE")
        self.assertIn(cli, self.application.works)

    def test_pc_008_initial_view_and_updates_share_an_atomic_boundary(self):
        gui = self.gui()
        subscription = self.application.subscribe(gui)
        self.assertEqual(set(subscription.initial["data"]), STATE_BLOCKS)
        self.assertEqual(subscription.initial["state_revision"], 1)
        self.application.register("cli")
        self.assertEqual(len(subscription.initial["data"]["works"]), 1)
        update = subscription.pending.get_nowait()
        self.assertEqual(update["state_revision"], 2)
        self.assertEqual(set(update["data"]), {"works"})
        self.assertEqual(len(update["data"]["works"]), 2)
        self.assertEqual(subscription.initial["data"]["loaded_image"]["status"], "unknown")

    def test_pc_008_subscribing_does_not_advance_revision(self):
        gui = self.gui()
        first = self.application.subscribe(gui)
        second = self.application.subscribe(gui)
        self.assertEqual(first.initial, second.initial)
        self.assertEqual(self.application.revision, 1)

    def test_pc_008_slow_subscriber_closes_without_blocking_other_clients(self):
        gui = self.gui()
        slow, fast = self.application.subscribe(gui), self.application.subscribe(gui)
        for _ in range(33):
            self.gui()
            self.assertEqual(fast.pending.get_nowait()["type"], "update")
        self.assertTrue(slow.closed)
        self.assertIsNone(slow.pending.get_nowait())
        self.assertFalse(fast.closed)
        self.assertIn(gui, self.application.works)
        self.assertFalse(self.application.shutting_down)

    def test_pc_017_closing_one_subscription_keeps_other_work(self):
        first, second = self.gui(), self.gui()
        first_stream, second_stream = (
            self.application.subscribe(first),
            self.application.subscribe(second),
        )
        self.application.finish(first)
        self.assertTrue(first_stream.closed)
        self.assertFalse(second_stream.closed)
        self.assertEqual(second_stream.pending.get_nowait()["data"]["works"][0]["work_id"], second)

    def test_pc_008_each_subscriber_owns_its_snapshot(self):
        gui = self.gui()
        first, second = self.application.subscribe(gui), self.application.subscribe(gui)
        self.application.register("cli")
        message = first.pending.get_nowait()
        message["data"]["works"].clear()
        self.assertEqual(len(second.pending.get_nowait()["data"]["works"]), 2)
        self.assertEqual(len(self.application.works), 2)


class ProgramTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.storage = RecordingStorage(self.root)
        self.assembler = ControlledAssembler()
        self.app = Application(str(uuid4()))
        await self.app.initialize(
            self.storage, self.assembler, {"addition": {"source_text": "addi x1,x0,5\nhalt\n"}}
        )
        self.service = self.app.program_service
        self.owner = self.app.register("gui", str(uuid4()))["work_id"]

    async def asyncTearDown(self):
        self.storage.source_release.set()
        self.assembler.release.set()
        await self.app.shutdown()
        self.temp.cleanup()

    def create(self):
        return self.service.get(self.service.create(self.owner)["program_id"])

    def edit(self, p, text):
        version = str(uuid4())
        self.service.update(self.owner, p.program_id, version, text)
        return version

    async def test_pc_002_reopening_open_file_keeps_unsaved_model_and_identity(self):
        path = self.root / "program.s"
        path.write_text("original")
        p = self.service.get((await self.service.open(self.owner, str(path)))["program_id"])
        version = self.edit(p, "unsaved")
        path.unlink()
        again = await self.service.open(self.owner, str(path))
        self.assertEqual(again["program_id"], p.program_id)
        self.assertEqual(again["source_version"], version)
        self.assertEqual(again["source_text"], "unsaved")
        self.assertFalse(path.exists())

    async def test_pc_002_example_is_an_independent_editable_copy(self):
        first = self.service.open_example(self.owner, "addition")
        second = self.service.open_example(self.owner, "addition")
        self.assertNotEqual(first["program_id"], second["program_id"])
        self.assertIsNone(first["source_path"])
        self.edit(self.service.get(first["program_id"]), "changed")
        self.assertEqual(self.service.examples["addition"]["source_text"], second["source_text"])

    async def test_pc_017_revision_uuid_is_stable_without_edit_and_cannot_be_reused(self):
        p = self.create()
        original = p.source_version
        same = self.service.update(self.owner, p.program_id, original, "")
        self.assertEqual(same["source_version"], original)
        self.edit(p, "B")
        for version, text in ((original, ""), (p.source_version, "other"), (str(uuid4()), "B")):
            with self.assertRaises(ApplicationError):
                self.service.update(self.owner, p.program_id, version, text)
        self.assertEqual(p.source_text, "B")

    async def test_pc_017_assembly_uses_captured_text_while_edit_and_save_continue(self):
        p = self.create()
        version = self.edit(p, "addi x1,x0,5\nhalt\n")
        self.assembler.release.clear()
        task = asyncio.create_task(
            self.app.execute(
                self.owner,
                "program assemble",
                lambda: self.service.assemble(
                    self.owner,
                    program_id=p.program_id,
                    source_version=version,
                    source_text=p.source_text,
                ),
            )
        )
        await until(self.assembler.started.is_set)
        current = self.edit(p, "current revision\n")
        await self.service.flush(p)
        self.assertEqual(p.recovery_version, current)
        self.assertIn(
            "program assemble",
            self.app.cli_status()["pending_commands"]
            if self.app.cli_status()["work_id"]
            else self.app.works[self.owner]["pending_commands"],
        )
        self.assembler.release.set()
        result = await task
        self.assertEqual(result["source_version"], version)
        self.assertEqual(result["image"], list(bytes.fromhex("930050000b000000")))
        self.assertEqual(self.assembler.inputs, ["addi x1,x0,5\nhalt\n"])
        self.assertEqual(p.source_version, current)
        self.assertEqual(p.source_text, "current revision\n")
        self.assertEqual(self.app.state()["assemblies"][0]["source_version"], version)

    async def test_pc_002_diagnostic_internal_failure_and_empty_translation_are_distinct(self):
        p = self.create()
        for source, code, line in [
            ("invalid\n", "ASSEMBLY_SOURCE_ERROR", 1),
            ("internal\n", "ASSEMBLY_INTERNAL_ERROR", None),
        ]:
            version = self.edit(p, source)
            with self.assertRaises(ApplicationError) as caught:
                await self.service.assemble(
                    self.owner, program_id=p.program_id, source_version=version, source_text=source
                )
            self.assertEqual(caught.exception.code, code)
            self.assertEqual(caught.exception.details["source_version"], version)
            if line:
                self.assertEqual(caught.exception.details["line"], line)
            self.assertIsNone(self.app.state()["assemblies"][0]["image"])
        version = self.edit(p, "")
        result = await self.service.assemble(
            self.owner, program_id=p.program_id, source_version=version, source_text=""
        )
        self.assertEqual(result["image"], [])
        self.assertEqual(result["pc_to_line"], [])

    async def test_pc_002_malformed_assembler_result_cannot_publish_partial_translation(self):
        p = self.create()
        version = self.edit(p, "input")
        self.assembler.assemble = lambda text: Result(b"\x01", {0: 1})
        with self.assertRaises(ApplicationError) as caught:
            await self.service.assemble(
                self.owner, program_id=p.program_id, source_version=version, source_text="input"
            )
        self.assertEqual(caught.exception.code, "ASSEMBLY_INTERNAL_ERROR")
        self.assertIsNone(self.app.state()["assemblies"][0]["image"])

    async def test_pc_017_protected_program_rejects_modification_and_discard(self):
        p = self.create()
        p.edit_protected = True
        with self.assertRaises(ApplicationError) as caught:
            self.edit(p, "change")
        self.assertEqual(caught.exception.code, "PROGRAM_PROTECTED")
        with self.assertRaises(ApplicationError) as caught:
            await self.service.discard(self.owner, p.program_id)
        self.assertEqual(caught.exception.code, "PROGRAM_PROTECTED")
        p.edit_protected = False
        self.edit(p, "allowed")

    async def test_pc_017_file_assembly_does_not_overwrite_open_editor_text(self):
        path = self.root / "source.s"
        path.write_text("file revision")
        p = self.service.get((await self.service.open(self.owner, str(path)))["program_id"])
        version = self.edit(p, "unsaved editor revision")
        cli = self.app.register("cli")["work_id"]
        result = await self.service.assemble(cli, source_path=str(path))
        self.assertNotEqual(result["source_version"], version)
        self.assertEqual(p.source_text, "unsaved editor revision")
        self.assertEqual(self.assembler.inputs, ["file revision"])

    async def test_pc_026_closed_tabs_stay_recoverable_and_reopen_flags_are_preserved(self):
        closed, opened = self.create(), self.create()
        self.edit(closed, "closed")
        self.edit(opened, "opened")
        await self.service.close(
            self.owner, closed.program_id, closed.source_version, closed.source_text
        )
        await self.service.flush(opened)
        restored = Application(str(uuid4()))
        await restored.initialize(self.storage, self.assembler)
        try:
            closed_again = restored.program_service.get(closed.program_id)
            open_again = restored.program_service.get(opened.program_id)
            self.assertFalse(closed_again.is_open)
            self.assertTrue(open_again.is_open)
            self.assertEqual(closed_again.source_version, closed.source_version)
            self.assertEqual(open_again.source_text, "opened")
        finally:
            await restored.shutdown()

    async def test_pc_026_old_save_completion_cannot_reopen_closed_document(self):
        p = self.create()
        version = self.edit(p, "A")
        target = self.root / "file.s"
        self.storage.source_release.clear()
        save = asyncio.create_task(
            self.service.save(self.owner, p.program_id, version, "A", str(target))
        )
        await until(self.storage.source_entered.is_set)
        close = asyncio.create_task(self.service.close(self.owner, p.program_id, version, "A"))
        await asyncio.sleep(0.02)
        with self.assertRaises(ApplicationError):
            self.edit(p, "should not be sent after close")
        self.storage.source_release.set()
        await save
        await close
        self.assertFalse(p.is_open)
        self.assertFalse(self.app.state()["programs"][0]["is_open"])

    async def test_pc_026_disconnected_http_waiter_does_not_abandon_storage_job(self):
        p = self.create()
        version = self.edit(p, "retained")
        self.storage.source_release.clear()
        path = self.root / "file.s"
        waiter = asyncio.create_task(
            self.app.execute(
                self.owner,
                "program save",
                lambda: self.service.save(self.owner, p.program_id, version, "retained", str(path)),
            )
        )
        await until(self.storage.source_entered.is_set)
        waiter.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await waiter
        self.assertIn("program save", self.app.works[self.owner]["pending_commands"])
        self.storage.source_release.set()
        await until(lambda: not self.app.tasks)
        self.assertEqual(path.read_text(), "retained")
        self.assertEqual(p.saved_version, version)

    def test_real_assembler_adapter_does_not_implement_or_fake_translation(self):
        from unittest.mock import patch

        result = Result(b"", {})
        with patch("software.viewrv.adapters.assembler.import_module") as module:
            module.return_value.assemble.return_value = result
            self.assertIs(PythonAssembler().assemble("source"), result)
            module.assert_called_once_with("software.assembler")
            module.return_value.assemble.assert_called_once_with("source")
