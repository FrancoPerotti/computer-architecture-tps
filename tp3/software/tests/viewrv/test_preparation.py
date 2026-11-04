"""PC-I04: selection, phases, ownership, resource integrity and supervised children."""

import asyncio
import hashlib
import json
import os
import sys
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from uuid import uuid4

import httpx

from software.tests.viewrv.controlled import ControlledAssembler
from software.tests.viewrv.preparation_fixture import DEVICE, PORT, ControlledProgrammer
from software.tests.viewrv.serial_fixture import Clock, ScriptedPort
from software.tests.viewrv.test_storage import RecordingStorage, until
from software.viewrv.adapters.http import create_app
from software.viewrv.adapters.programmer import (
    HardwareAssets,
    OpenFPGALoader,
    child_environment,
    parse_scan,
)
from software.viewrv.adapters.serial import SerialTransport
from software.viewrv.contracts import ApplicationError
from software.viewrv.core.application import Application
from software.viewrv.core.board_selection import association, select_device, select_uart
from software.viewrv.core.storage import StorageQueue

PROFILE = {"profile_id": "tp3-riscv", "revision": 1, "memory_profile": "REFERENCE"}


def scan(rows=()):
    columns = ("Bus", "device", "vid:pid", "probe_type", "manufacturer", "serial", "product")
    widths = (4, 7, 14, 14, 16, 18)

    def line(values):
        return "".join(str(value).ljust(width) for value, width in zip(values, widths)) + values[-1]

    return line(columns) + "\n" + "\n".join(line(row) for row in rows) + "\n"


class SelectionTests(unittest.TestCase):
    def test_scan_fixed_columns_serial_with_spaces_and_opaque_ids(self):
        table = scan(
            [
                (
                    1,
                    9,
                    "0x0403:0x6010",
                    "FTDI2232",
                    "Digilent Inc",
                    "210183 TEST",
                    "Digilent USB Device",
                )
            ]
        )
        result = parse_scan(table)
        self.assertEqual(result[0]["id"], "serial:210183 TEST")
        self.assertEqual(result[0]["selector"], ["--usb-serial-num", "210183 TEST"])
        self.assertEqual(result[0]["description"], "Digilent Inc Digilent USB Device")
        self.assertEqual(parse_scan(scan()), [])
        self.assertEqual(parse_scan(scan(), "No USB devices found"), [])

    def test_scan_permissions_partial_output_and_invalid_rows_are_not_empty_enumeration(self):
        for output, error in (
            (scan(), "Error: can't open device"),
            ("unknown format", ""),
            (scan() + "broken row\n", ""),
        ):
            with self.assertRaises(ValueError):
                parse_scan(output, error)

    def test_scan_no_serial_or_duplicate_serial_requires_explicit_bus_device(self):
        table = scan(
            [
                (1, 9, "0x0403:0x6010", "FTDI2232", "Digilent", "same", "USB"),
                (1, 10, "0x0403:0x6010", "FTDI2232", "Digilent", "same", "USB"),
            ]
        )
        result = parse_scan(table)
        self.assertEqual([item["id"] for item in result], ["usb:1:9", "usb:1:10"])
        self.assertEqual(result[0]["selector"], ["--busdev-num", "1:9"])
        with self.assertRaises(ApplicationError):
            select_device(result)
        self.assertEqual(select_device(result, "usb:1:10")["address"], 10)
        no_serial = deepcopy(DEVICE)
        no_serial["serial"] = None
        no_serial["id"] = "usb:1:9"
        with self.assertRaises(ApplicationError):
            select_device([no_serial])

    def test_pairing_preserves_explicit_and_remembered_and_rejects_other_board(self):
        other = {**PORT, "id": "other", "serial": "another", "address": 10}
        self.assertEqual(select_uart([PORT, other], DEVICE)["id"], PORT["id"])
        for explicit, remembered in (("other", None), (None, "gone"), (None, "other")):
            with self.assertRaises(ApplicationError) as caught:
                select_uart([PORT, other], DEVICE, explicit, remembered)
            self.assertEqual(caught.exception.code, "PORT_NOT_FOUND")
        self.assertEqual(select_uart([PORT], DEVICE, PORT["id"], "gone")["id"], PORT["id"])

    def test_unknown_association_needs_both_explicit_choices_and_bus_mismatch_wins(self):
        device = {**DEVICE, "serial": None, "id": "usb:1:9"}
        port = {**PORT, "serial": None, "bus": None, "address": None}
        self.assertEqual(association(device, port), "unknown")
        for explicit_device, explicit_port in ((False, None), (True, None), (False, PORT["id"])):
            with self.assertRaises(ApplicationError):
                select_uart([port], device, explicit_port, device_explicit=explicit_device)
        self.assertEqual(
            select_uart([port], device, PORT["id"], device_explicit=True)["id"], PORT["id"]
        )
        self.assertEqual(association(DEVICE, {**PORT, "address": 10}), "different")
        self.assertEqual(association(DEVICE, {**PORT, "serial": DEVICE["serial"] + "B"}), "same")


class PreparationFixture(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.storage = RecordingStorage(self.root)
        self.programmer = ControlledProgrammer(self.root)
        self.ports = [deepcopy(PORT)]
        self.clock = Clock()
        self.port = ScriptedPort(self.clock)

        def opened(name):
            self.port.closed = False
            return self.port

        self.transport = SerialTransport("REFERENCE", opened, self.clock)
        self.app = Application(str(uuid4()))
        await self.app.initialize(
            self.storage,
            ControlledAssembler(),
            serial_transport=self.transport,
            programmer=self.programmer,
            port_enumerator=lambda: deepcopy(self.ports),
        )
        self.owner = self.app.register("gui", str(uuid4()))["work_id"]
        self.other = self.app.register("cli")["work_id"]
        self.board = self.app.board_service

    async def asyncTearDown(self):
        self.programmer.release.set()
        await self.app.shutdown()
        self.temp.cleanup()

    def replies(self, *values):
        self.port.script.extend((b"\x05", [(0, value)] if value else []) for value in values)


class PreparationTests(PreparationFixture):
    async def test_prepare_confirms_programming_before_uart_and_holds_one_owner(self):
        self.replies(b"\x05\x03")
        self.app.loaded_image = {
            "status": "confirmed",
            "program_id": str(uuid4()),
            "source_version": str(uuid4()),
            "byte_count": 8,
        }

        def before():
            self.assertTrue(self.app.board["preparation_required"])
            self.assertEqual(self.app.loaded_image["status"], "unknown")
            self.assertIsNone(self.transport.port)
            self.assertEqual(self.app.board_owner, self.owner)

        self.programmer.before = before
        result = await self.board.prepare(self.owner)
        self.assertEqual(
            result, {"device_id": DEVICE["id"], "port": PORT["id"], "reset_used": False}
        )
        self.assertEqual(self.app.board["connection_status"], "checked")
        self.assertEqual(self.app.preferences["last_serial_port"], PORT["id"])
        self.assertTrue(self.app.works[self.owner]["owns_board"])
        with self.assertRaises(ApplicationError) as caught:
            await self.board.prepare(self.other)
        self.assertEqual(caught.exception.code, "BOARD_CONTROL_CONFLICT")

    async def test_program_failure_is_unconfirmed_and_requires_explicit_preparation(self):
        self.programmer.failure = RuntimeError("programmer exit 1")
        with self.assertRaises(ApplicationError) as caught:
            await self.board.prepare(self.owner)
        self.assertEqual(caught.exception.details["phase"], "programming")
        self.assertEqual(caught.exception.details["programming_status"], "unconfirmed")
        self.assertEqual(caught.exception.details["reset_status"], "not_attempted")
        self.assertTrue(self.app.board["preparation_required"])
        self.assertEqual(self.port.writes, [])
        with self.assertRaises(ApplicationError) as caught:
            await self.board.connect(self.owner)
        self.assertEqual(caught.exception.code, "BOARD_PREPARATION_REQUIRED")

    async def test_missing_bitstream_stops_before_programming_without_invalidating_existing_link(
        self,
    ):
        self.replies(b"\x05\x03")
        await self.board.prepare(self.owner)
        self.programmer.calls.clear()
        self.programmer.invalid = FileNotFoundError("processor.bit absent")
        with self.assertRaises(ApplicationError) as caught:
            await self.board.prepare(self.owner)
        self.assertEqual(caught.exception.details["programming_status"], "not_attempted")
        self.assertEqual(self.app.board["connection_status"], "checked")
        self.assertTrue(all(not isinstance(call, tuple) for call in self.programmer.calls))

    async def test_successful_program_with_failed_uart_keeps_separate_confirmations_and_no_replay(
        self,
    ):
        self.replies(b"", b"")
        self.port.script.append((b"\x04", []))
        with self.assertRaises(ApplicationError) as caught:
            await self.board.prepare(self.owner)
        self.assertEqual(caught.exception.code, "BOARD_PREPARATION_FAILED")
        self.assertEqual(caught.exception.details["phase"], "connection")
        self.assertEqual(caught.exception.details["programming_status"], "confirmed")
        self.assertEqual(caught.exception.details["reset_status"], "unconfirmed")
        self.assertFalse(self.app.board["preparation_required"])
        self.assertTrue(self.app.board["recovery_pending"])
        self.assertEqual(sum(isinstance(call, tuple) for call in self.programmer.calls), 1)
        before = len(self.port.writes)
        with self.assertRaises(ApplicationError):
            await self.board.connect(self.owner)
        self.assertEqual(len(self.port.writes), before, "Reopening must not renew automatic RESET")

    async def test_uart_disappearing_after_programming_never_selects_another(self):
        self.programmer.after = lambda: self.ports.clear()
        with self.assertRaises(ApplicationError) as caught:
            await self.board.prepare(self.owner)
        self.assertEqual(caught.exception.details["programming_status"], "confirmed")
        self.assertEqual(caught.exception.details["phase"], "connection")
        self.assertEqual(caught.exception.details["port"], PORT["id"])
        self.assertEqual(self.port.writes, [])

    async def test_busy_uart_confirms_communication_and_reconnect_does_not_reprogram(self):
        self.replies(b"\x05\x04", b"\x05\x03")
        await self.board.prepare(self.owner)
        await self.board.disconnect(self.owner)
        self.assertEqual(self.app.board["connection_status"], "closed")
        self.assertFalse(self.app.works[self.owner]["owns_board"])
        await self.board.connect(self.owner)
        self.assertEqual(sum(isinstance(call, tuple) for call in self.programmer.calls), 1)

    async def test_programmer_wait_does_not_block_editing_and_competing_actions_are_rejected(self):
        self.replies(b"\x05\x03")
        self.programmer.release.clear()
        task = asyncio.create_task(self.board.prepare(self.owner))
        await self.programmer.entered.wait()
        p = self.app.program_service.create(self.owner)
        version = str(uuid4())
        self.app.program_service.update(self.owner, p["program_id"], version, "editable")
        await self.app.program_service.flush(self.app.program_service.get(p["program_id"]))
        self.assertFalse(task.done())
        for owner, code in (
            (self.owner, "OPERATION_CONFLICT"),
            (self.other, "BOARD_CONTROL_CONFLICT"),
        ):
            with self.assertRaises(ApplicationError) as caught:
                await self.board.prepare(owner)
            self.assertEqual(caught.exception.code, code)
        self.programmer.release.set()
        await task

    async def test_disconnect_during_programming_waits_for_child_and_does_not_open_uart(self):
        self.programmer.release.clear()
        preparing = asyncio.create_task(self.board.prepare(self.owner))
        await self.programmer.entered.wait()
        disconnecting = asyncio.create_task(self.board.disconnect(self.owner))
        await asyncio.sleep(0.01)
        self.assertFalse(disconnecting.done())
        self.programmer.release.set()
        result = await asyncio.gather(preparing, disconnecting, return_exceptions=True)
        self.assertIsInstance(result[0], ApplicationError)
        self.assertEqual(result[0].details["programming_status"], "confirmed")
        self.assertEqual(result[1], {"connection_status": "closed"})
        self.assertEqual(self.port.writes, [])
        self.assertIsNone(self.app.board_owner)

    async def test_preference_write_failure_does_not_undo_confirmed_connection(self):
        self.storage.fail_preferences = True
        self.replies(b"\x05\x03")
        result = await self.board.prepare(self.owner)
        self.assertEqual(result["port"], PORT["id"])
        self.assertEqual(self.app.board["connection_status"], "checked")
        self.assertIsNone(self.app.preferences["last_serial_port"])
        self.assertTrue(
            any(
                item["code"] == "PREFERENCES_WRITE_FAILED"
                for item in self.app.state()["limitations"]
            )
        )

    async def test_finishing_observer_does_not_close_foreign_uart_and_owner_finish_does(self):
        self.replies(b"\x05\x03")
        await self.board.prepare(self.owner)
        await self.app.finish_registered(self.other)
        self.assertFalse(self.port.closed)
        await self.app.finish_registered(self.owner)
        self.assertTrue(self.port.closed)
        self.assertIsNone(self.app.board_owner)


class ProgrammerTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="viewrv programmer ")
        self.root = Path(self.temp.name)
        (self.root / "programmer").mkdir()
        (self.root / "hardware").mkdir()
        self.queue = StorageQueue()
        self.assets = HardwareAssets(self.root, PROFILE)
        self.driver = OpenFPGALoader(self.assets, self.queue, timeout=0.1, grace=0.03)

    async def asyncTearDown(self):
        await self.queue.close()
        self.temp.cleanup()

    def executable(self, body):
        file = self.root / "programmer/openFPGALoader"
        file.write_text(f"#!{sys.executable}\n" + body)
        file.chmod(0o755)
        manifest = {
            "schema_version": 1,
            "version": "1.2.0",
            "platform": "linux",
            "architecture": "x86_64",
            "files": [
                {"path": "openFPGALoader", "sha256": hashlib.sha256(file.read_bytes()).hexdigest()}
            ],
        }
        (self.root / "programmer/manifest.json").write_text(json.dumps(manifest))
        return file

    def bitstream(self):
        file = self.root / "hardware/processor.bit"
        file.write_bytes(b"CONTROLLED TEST ONLY; NOT A HARDWARE BITSTREAM")
        (self.root / "hardware/processor.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "board": "basys3",
                    "processor_profile": PROFILE,
                    "source_revision": "a" * 40,
                    "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
                }
            )
        )
        return file.resolve()

    async def test_real_child_uses_exact_arguments_and_no_shell_or_frozen_library_path(self):
        record = self.root / "arguments.json"
        self.executable(
            "import sys,json,os\nfrom pathlib import Path\nPath("
            + repr(str(record))
            + ").write_text(json.dumps({'args':sys.argv[1:],'libs':os.environ.get('LD_LIBRARY_PATH'),'python':os.environ.get('PYTHONPATH')}))\n"
        )
        path = self.bitstream()
        await self.driver.program(DEVICE, path)
        result = json.loads(record.read_text())
        self.assertEqual(
            result["args"],
            ["--board", "basys3", "--write-sram", "--usb-serial-num", DEVICE["serial"], str(path)],
        )
        self.assertEqual(result["libs"], str(self.root / "programmer/lib"))
        self.assertIsNone(result["python"])
        self.assertEqual(
            child_environment(
                self.root / "programmer/openFPGALoader",
                {
                    "LD_LIBRARY_PATH": "bad",
                    "LD_LIBRARY_PATH_ORIG": "/external",
                    "PYTHONPATH": "bad",
                },
            )["LD_LIBRARY_PATH"],
            str(self.root / "programmer/lib") + ":/external",
        )

    async def test_timeout_terminates_only_owned_child_and_reaps_even_ignored_sigterm(self):
        marker = self.root / "child.pid"
        self.executable(
            "import os,signal,time\nfrom pathlib import Path\nPath("
            + repr(str(marker))
            + ").write_text(str(os.getpid()))\nsignal.signal(signal.SIGTERM,signal.SIG_IGN)\ntime.sleep(20)\n"
        )
        with self.assertRaises(TimeoutError):
            await self.driver.program(DEVICE, self.bitstream())
        pid = int(marker.read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    async def test_scan_errors_are_distinct_from_empty_result(self):
        self.executable("print(" + repr(scan()) + ")\n")
        self.assertEqual(await self.driver.devices(), [])
        self.executable("import sys\nprint('access denied',file=sys.stderr)\nsys.exit(1)\n")
        with self.assertRaises(ApplicationError) as caught:
            await self.driver.devices()
        self.assertEqual(caught.exception.code, "DEVICE_ENUMERATION_FAILED")

    async def test_resources_missing_corrupt_or_wrong_profile_fail_before_child(self):
        with self.assertRaises(FileNotFoundError):
            self.assets.bitstream()
        path = self.bitstream()
        self.assertEqual(self.assets.bitstream(), path)
        path.write_bytes(b"tampered")
        with self.assertRaises(ValueError):
            self.assets.bitstream()
        self.bitstream()
        file = self.root / "hardware/processor.json"
        value = json.loads(file.read_text())
        value["processor_profile"]["memory_profile"] = "ALT_1000"
        file.write_text(json.dumps(value))
        with self.assertRaises(ValueError):
            self.assets.bitstream()
        self.executable("print('valid')\n")
        (self.root / "programmer/openFPGALoader").write_text("changed")
        with self.assertRaises(ValueError):
            self.assets.programmer()

    async def test_scan_output_limit_never_turns_partial_candidates_into_a_unique_choice(self):
        self.executable("print(" + repr(scan()) + ")\nprint('x'*300000)\n")
        with self.assertRaises(ApplicationError) as caught:
            await self.driver.devices()
        self.assertEqual(caught.exception.code, "DEVICE_ENUMERATION_FAILED")

    async def test_cancelled_programming_task_reaps_its_child(self):
        marker = self.root / "cancel.pid"
        self.executable(
            "import os,time\nfrom pathlib import Path\nPath("
            + repr(str(marker))
            + ").write_text(str(os.getpid()))\ntime.sleep(20)\n"
        )
        self.driver.timeout = 5
        task = asyncio.create_task(self.driver.program(DEVICE, self.bitstream()))
        await until(marker.exists)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task
        with self.assertRaises(ProcessLookupError):
            os.kill(int(marker.read_text()), 0)


class BoardApiTests(PreparationFixture):
    async def client(self):
        self.stops = []

        async def stop():
            self.stops.append(True)

        discovery = {
            "base_url": "http://127.0.0.1:41987",
            "instance_id": self.app.instance_id,
            "api_version": 1,
            "access_token": "controlled-token",
        }
        api = create_app(self.app, discovery, PROFILE, stop)
        return httpx.AsyncClient(
            transport=httpx.ASGITransport(app=api),
            base_url=discovery["base_url"],
            headers={"Authorization": "Bearer controlled-token", "X-Viewrv-Work-Id": self.owner},
        )

    async def test_enumeration_contract_and_queries_do_not_create_or_claim_work(self):
        async with await self.client() as client:
            previous = set(self.app.works)
            self.assertEqual(
                (await client.get("/api/v1/board/devices")).json()["result"],
                [{"id": DEVICE["id"], "description": DEVICE["description"]}],
            )
            self.assertEqual(
                (await client.get("/api/v1/board/ports")).json()["result"],
                [{"id": PORT["id"], "description": PORT["description"]}],
            )
            self.assertEqual(set(self.app.works), previous)
            self.assertIsNone(self.app.board_owner)

    async def test_shared_prepare_connect_disconnect_results_and_strict_requests(self):
        self.replies(b"\x05\x03", b"\x05\x04")
        async with await self.client() as client:
            for body in ({"port": False}, {"device_id": ""}, {"extra": 1}):
                self.assertEqual(
                    (await client.post("/api/v1/board/prepare", json=body)).status_code, 400
                )
            self.assertEqual(self.programmer.calls, [])
            result = (await client.post("/api/v1/board/prepare", json={})).json()["result"]
            self.assertEqual(set(result), {"device_id", "port", "reset_used"})
            response = await client.post("/api/v1/board/disconnect", json={})
            self.assertEqual(response.json()["result"], {"connection_status": "closed"})
            self.assertFalse(
                (await client.post("/api/v1/board/connect", json={})).json()["result"]["reset_used"]
            )

    async def test_unregistered_action_is_rejected_before_effects(self):
        async with await self.client() as client:
            client.headers.pop("X-Viewrv-Work-Id")
            response = await client.post("/api/v1/board/prepare", json={})
            self.assertEqual(response.json()["error"]["code"], "WORK_NOT_ACTIVE")
            self.assertEqual(self.programmer.calls, [])

    async def test_disconnected_http_waiter_does_not_abandon_programmer_or_release_lease(self):
        self.replies(b"\x05\x03")
        self.programmer.release.clear()
        async with await self.client() as client:
            task = asyncio.create_task(client.post("/api/v1/board/prepare", json={}))
            await self.programmer.entered.wait()
            task.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await task
            self.assertEqual(self.app.board_owner, self.owner)
            self.assertTrue(self.app.tasks)
            self.programmer.release.set()
            await until(lambda: not self.app.tasks)
            self.assertEqual(self.app.board["connection_status"], "checked")

    async def test_finish_work_waits_for_programming_then_closes_without_following_uart(self):
        self.programmer.release.clear()
        async with await self.client() as client:
            preparing = asyncio.create_task(client.post("/api/v1/board/prepare", json={}))
            await self.programmer.entered.wait()
            finishing = asyncio.create_task(client.post("/api/v1/work/finish", json={}))
            await asyncio.sleep(0.01)
            self.assertFalse(finishing.done())
            self.programmer.release.set()
            response = await finishing
            self.assertTrue(response.json()["result"]["finished"])
            self.assertEqual(
                (await preparing).json()["error"]["details"]["programming_status"], "confirmed"
            )
            self.assertEqual(self.port.writes, [])
            self.assertIn(self.other, self.app.works)

    async def test_failed_enumeration_without_work_closes_unused_core_after_response(self):
        async def fail():
            raise ApplicationError("DEVICE_ENUMERATION_FAILED", "permission denied", 500)

        self.programmer.devices = fail
        self.app.works.clear()
        async with await self.client() as client:
            response = await client.get("/api/v1/board/devices")
            self.assertEqual(response.status_code, 500)
            self.assertIsNone(response.json()["result"])
            self.assertEqual(response.json()["error"]["code"], "DEVICE_ENUMERATION_FAILED")
            self.assertEqual(self.stops, [True])
