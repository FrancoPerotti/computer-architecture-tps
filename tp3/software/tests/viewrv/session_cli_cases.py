"""All 25 CLI operations, local usage, persistence and interrupted client waits."""

import io
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from software.viewrv.cli.__main__ import main
from software.viewrv.client.connection import CoreClient

TP3 = Path(__file__).resolve().parents[3]
COMMANDS = {
    "board devices",
    "board ports",
    "board prepare",
    "board connect",
    "board disconnect",
    "board status",
    "program assemble",
    "program load",
    "run start",
    "run stop",
    "debug start",
    "debug step",
    "debug continue",
    "debug pause",
    "debug restart",
    "debug stop",
    "debug breakpoint add",
    "debug breakpoint remove",
    "debug breakpoint list",
    "session list",
    "session show",
    "session steps",
    "session logs",
    "work status",
    "work finish",
}


class LocalCliTests(unittest.TestCase):
    def invoke(self, *arguments):
        output, errors = io.StringIO(), io.StringIO()
        with (
            patch(
                "software.viewrv.cli.__main__.connect",
                side_effect=AssertionError("Local CLI command attempted to start core"),
            ),
            redirect_stdout(output),
            redirect_stderr(errors),
        ):
            code = main(list(arguments))
        return code, output.getvalue(), errors.getvalue()

    def test_all_command_help_and_version_are_local_text_even_when_json_is_selected(self):
        """TEST-PC-013 / TEST-PC-015: all command help and version are local text even when json is selected."""
        for output in ("human", "json"):
            for command in sorted(COMMANDS):
                with self.subTest(output=output, command=command):
                    code, text, errors = self.invoke("--output", output, *command.split(), "--help")
                    self.assertEqual(code, 0, errors)
                    self.assertTrue(text.startswith("Usage:"))
            code, text, errors = self.invoke("--output", output, "--version")
            self.assertEqual(code, 0)
            self.assertTrue(text.startswith("viewrv, version"))

    def test_invalid_options_fail_locally_in_json_with_usage_exit_code(self):
        """TEST-PC-013 / TEST-PC-015: invalid options fail locally in json with usage exit code."""
        cases = [("run", "start", "--limit", value) for value in ("0", "-1", "nan", "inf")]
        cases += [
            ("debug", "start", "--record", "--no-record"),
            ("debug", "restart", "--author", "  "),
            ("debug", "breakpoint", "add", "--latch", "IF/ID"),
            ("debug", "breakpoint", "remove", "--line", "1", "--pc", "0", "--latch", "IF/ID"),
            ("debug", "breakpoint", "add", "--pc", "0x100000000", "--latch", "ID/EX"),
            ("debug", "breakpoint", "add", "--pc", "0", "--latch", "EX"),
            ("session", "steps", "--after", "-1"),
            ("session", "steps", "--after", "1.5"),
            ("session", "show", "--session", "invalid"),
        ]
        for arguments in cases:
            with self.subTest(arguments=arguments):
                code, text, errors = self.invoke("--output", "json", *arguments)
                self.assertEqual(code, 2, errors)
                self.assertEqual(json.loads(text)["error"]["code"], "INVALID_ARGUMENT")


@unittest.skipIf(os.name == "nt", "Aislamiento de cuenta Windows pendiente.")
class SessionCliProcessTests(unittest.TestCase):
    def test_core_crash_recovers_partial_record_without_source_file_or_restored_physical_session(
        self,
    ):
        """TEST-PC-022 / TEST-PC-030: core crash recovers partial record without source file or restored physical session."""
        self.cli("board", "prepare")
        self.cli("program", "assemble", str(self.source))
        self.cli("program", "load", str(self.source))
        self.cli("debug", "start")
        self.cli("debug", "step")
        self.cli("debug", "step")
        identity = self.current()["session_id"]
        self.wait(lambda: len(self.cli("session", "steps")["result"]["steps"]) == 2)
        path = self.root / "state/viewrv/records" / (identity + ".jsonl")
        old_instance = self.client.discovery["instance_id"]
        self.core.kill()
        self.core.wait(timeout=10)
        self.client.close()
        saved = path.read_bytes().splitlines(keepends=True)
        self.assertEqual(len(saved), 3)
        with path.open("wb") as stream:
            stream.write(
                saved[0] + saved[1] + b"broken middle unit\n" + saved[2] + b'{"schema_version":'
            )
            stream.flush()
            os.fsync(stream.fileno())
        self.source.unlink()
        before = (self.root / "uart.tx").read_bytes()
        self.core = subprocess.Popen(
            [sys.executable, "-m", "software.tests.viewrv.session_core"],
            cwd=TP3,
            env=self.environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.children.append(self.core)
        self.wait(
            lambda: (
                json.loads((self.root / "viewrv/core.json").read_text())["instance_id"]
                != old_instance
            )
        )
        self.client = CoreClient(json.loads((self.root / "viewrv/core.json").read_text()))
        self.observer = self.client.request(
            "POST", "/api/v1/work/register", {"client_type": "gui", "registration_id": str(uuid4())}
        )["work_id"]
        self.assertIsNone(self.current()["work_id"])
        shown = self.cli("session", "show", "--session", identity)["result"]
        self.assertEqual(shown["source_text"], "addi x1,x0,5\nhalt\n")
        self.assertEqual(shown["execution_status"], "unknown")
        self.assertFalse(shown["debug_open"])
        self.assertEqual(shown["evidence"]["record_status"], "incomplete")
        steps = self.cli("session", "steps", "--session", identity)["result"]
        self.assertEqual([item["step_index"] for item in steps["steps"]], [1, 2])
        self.assertEqual((self.root / "uart.tx").read_bytes(), before)
        board = self.cli("board", "status")["result"]
        self.assertTrue(board["preparation_required"])
        self.assertEqual(board["connection_status"], "closed")
        self.assertEqual(self.cli("debug", "step", code=1)["error"]["code"], "DEBUG_NOT_ACTIVE")
        self.assertEqual(
            self.cli("session", "show", code=1)["error"]["code"], "SESSION_SELECTION_REQUIRED"
        )
        self.assertEqual((self.root / "uart.tx").read_bytes(), before)
        self.cli("work", "finish")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="viewrv pc05 cli ")
        self.root = Path(self.temp.name)
        native = os.environ.get("VIEWRV_TEST_NATIVE_CLI")
        if native:
            product = self.root / "native CLI verification only"
            shutil.copytree(Path(native).resolve().parent, product)
            shutil.copytree(TP3 / "software/resources/content", product / "resources/content")
            self.cli_command = [str(product / "viewrv")]
        else:
            self.cli_command = [sys.executable, "-m", "software.viewrv.cli"]
        self.environment = {
            **os.environ,
            "PYTHONPATH": os.pathsep.join(
                filter(None, (str(TP3), os.environ.get("PYTHONPATH", "")))
            ),
            "XDG_RUNTIME_DIR": str(self.root),
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_DATA_HOME": str(self.root / "data"),
            "VIEWRV_TEST_CONTROL": str(self.root),
        }
        self.children = []
        self.cli_environment = dict(self.environment)
        if native:
            for key in ("PYTHONPATH", "PYTHONHOME", "LD_LIBRARY_PATH", "LD_PRELOAD"):
                self.cli_environment.pop(key, None)
        self.core = subprocess.Popen(
            [sys.executable, "-m", "software.tests.viewrv.session_core"],
            cwd=TP3,
            env=self.environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.children.append(self.core)
        self.wait(lambda: (self.root / "viewrv/core.json").exists())
        self.client = CoreClient(json.loads((self.root / "viewrv/core.json").read_text()))
        self.observer = self.client.request(
            "POST", "/api/v1/work/register", {"client_type": "gui", "registration_id": str(uuid4())}
        )["work_id"]
        self.source = self.root / "exact source.s"
        self.source.write_text("addi x1,x0,5\nhalt\n")

    def tearDown(self):
        self.client.close()
        for process in reversed(self.children):
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        self.temp.cleanup()

    def wait(self, predicate, timeout=12):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if predicate():
                return
            time.sleep(0.01)
        self.fail("Condition did not become true")

    def cli(self, *arguments, output="json", code=0):
        process = subprocess.run(
            [*self.cli_command, "--output", output, *arguments],
            cwd=self.root,
            env=self.cli_environment,
            capture_output=True,
            text=True,
            timeout=20,
        )
        self.assertEqual(process.returncode, code, process.stdout + process.stderr)
        if output == "json":
            return json.loads(process.stdout)
        self.assertTrue(process.stdout)
        self.assertFalse(process.stdout.startswith("{"))
        return process.stdout

    def start_cli(self, *arguments, output="json"):
        process = subprocess.Popen(
            [*self.cli_command, "--output", output, *arguments],
            cwd=self.root,
            env=self.cli_environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.children.append(process)
        return process

    def current(self):
        return self.client.request("GET", "/api/v1/work/cli/status")

    def test_all_25_operations_in_human_and_json_use_one_persistent_work(self):
        """TEST-PC-013 / TEST-PC-015: all 25 operations in human and json use one persistent work."""
        for output in ("human", "json"):
            visited = set()

            def command(*arguments):
                visited.add(
                    " ".join(
                        arguments[:3] if arguments[:2] == ("debug", "breakpoint") else arguments[:2]
                    )
                )
                return self.cli(*arguments, output=output)

            command("board", "devices")
            command("board", "ports")
            command("board", "status")
            self.assertIsNone(self.current()["work_id"])
            command("board", "prepare")
            owner = self.current()["work_id"]
            command("board", "disconnect")
            command("board", "connect")
            command("program", "assemble", str(self.source))
            command("program", "load", str(self.source))
            command("run", "start", "--author", "Franco")
            command("program", "load", str(self.source))
            command("debug", "start")
            identity = self.current()["session_id"]
            command("debug", "breakpoint", "add", "--line", "1", "--latch", "IF/ID")
            command("debug", "breakpoint", "list")
            command("debug", "step")
            command("debug", "continue")
            command("debug", "pause")
            command("debug", "breakpoint", "remove", "--pc", "0x0", "--latch", "IF/ID")
            command("debug", "restart", "--no-record")
            command("debug", "stop")
            command("session", "list")
            command("session", "show")
            command("session", "steps", "--session", identity, "--after", "0")
            command("session", "logs", "--session", identity)
            command("program", "load", str(self.source))
            (self.root / "run.wait").touch()
            running = self.start_cli("run", "start", output=output)
            self.wait(lambda: "run start" in self.current()["pending_commands"])
            command("run", "stop")
            stdout, stderr = running.communicate(timeout=10)
            self.assertEqual(running.returncode, 0, stdout + stderr)
            (self.root / "run.wait").unlink()
            command("work", "status")
            self.assertEqual(self.current()["work_id"], owner)
            command("work", "finish")
            self.assertIsNone(self.current()["work_id"])
            self.assertEqual(visited, COMMANDS)
            self.assertEqual(
                self.cli("session", "show", code=1)["error"]["code"], "SESSION_SELECTION_REQUIRED"
            )

    def test_ctrl_c_only_interrupts_client_wait_and_stop_from_another_invocation_resolves_run(self):
        """TEST-PC-013 / TEST-PC-023: ctrl c only interrupts client wait and stop from another invocation resolves run."""
        self.cli("board", "prepare")
        self.cli("program", "assemble", str(self.source))
        self.cli("program", "load", str(self.source))
        (self.root / "run.wait").touch()
        running = self.start_cli("run", "start")
        self.wait(
            lambda: (
                "run start" in self.current()["pending_commands"]
                and self.current()["session_id"] is not None
            )
        )
        running.send_signal(signal.SIGINT)
        stdout, stderr = running.communicate(timeout=10)
        self.assertEqual(running.returncode, 130, stdout + stderr)
        self.assertEqual(json.loads(stdout)["error"]["code"], "CLIENT_WAIT_INTERRUPTED")
        self.assertIn("run start", self.current()["pending_commands"])
        stopped = self.cli("run", "stop")["result"]
        self.assertEqual(stopped["interruption"], {"reason": "user_request"})
        self.assertEqual(self.core.poll(), None)
        logs = self.cli("session", "logs")["result"]
        self.assertEqual(logs["execution_status"], "interrupted")
        self.assertEqual(logs["record_status"], "complete")
        self.assertEqual(logs["observations"], [])
        self.cli("work", "finish")
