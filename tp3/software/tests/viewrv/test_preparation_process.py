"""Public CLI process contract against the actual injected core."""

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from software.viewrv.client.connection import CoreClient

TP3 = Path(__file__).resolve().parents[3]


class PreparationProcessTests(unittest.TestCase):
    @unittest.skipIf(os.name == "nt", "Requiere cuenta Windows de prueba aislada.")
    def test_cli_owns_one_connection_and_failures_do_not_replay_effects(self):
        with tempfile.TemporaryDirectory(prefix="viewrv pc04 ") as folder:
            root = Path(folder)
            environment = {
                **os.environ,
                "PYTHONPATH": str(TP3),
                "XDG_RUNTIME_DIR": folder,
                "XDG_STATE_HOME": str(root / "state"),
                "XDG_CONFIG_HOME": str(root / "config"),
                "XDG_DATA_HOME": str(root / "data"),
                "VIEWRV_TEST_CONTROL": folder,
            }
            core = subprocess.Popen(
                [sys.executable, "-m", "software.tests.viewrv.preparation_core"],
                cwd=TP3,
                env=environment,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            try:
                discovery_file = root / "viewrv/core.json"
                deadline = time.monotonic() + 10
                while not discovery_file.exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue(discovery_file.exists())
                with CoreClient(json.loads(discovery_file.read_text())) as client:
                    observer = client.request(
                        "POST",
                        "/api/v1/work/register",
                        {
                            "client_type": "gui",
                            "registration_id": "11111111-2222-4333-8444-555555555555",
                        },
                    )["work_id"]

                    def cli(*arguments, code=0):
                        process = subprocess.run(
                            [
                                sys.executable,
                                "-m",
                                "software.viewrv.cli",
                                "--output",
                                "json",
                                *arguments,
                            ],
                            cwd=folder,
                            env=environment,
                            capture_output=True,
                            text=True,
                            timeout=15,
                        )
                        self.assertEqual(process.returncode, code, process.stderr + process.stdout)
                        return json.loads(process.stdout)

                    self.assertEqual(
                        cli("board", "devices")["result"][0]["id"], "serial:210183TEST"
                    )
                    self.assertEqual(cli("board", "ports")["result"][0]["id"], "controlled-uart")
                    self.assertIsNone(cli("work", "status")["result"]["work_id"])
                    self.assertFalse(cli("board", "prepare")["result"]["reset_used"])
                    owner = cli("work", "status")["result"]["work_id"]
                    self.assertTrue(cli("work", "status")["result"]["owns_board"])
                    blocked = client.http.post(
                        "/api/v1/board/disconnect", json={}, headers={"X-Viewrv-Work-Id": observer}
                    )
                    self.assertEqual(blocked.json()["error"]["code"], "BOARD_CONTROL_CONFLICT")
                    cli("board", "disconnect")
                    cli("board", "connect")
                    self.assertEqual((root / "program.calls").read_text(), "program\n")
                    self.assertEqual(cli("work", "status")["result"]["work_id"], owner)
                    (root / "uart.fail").touch()
                    failed = cli("board", "prepare", code=1)["error"]
                    self.assertEqual(failed["details"]["phase"], "connection")
                    self.assertEqual(failed["details"]["programming_status"], "confirmed")
                    (root / "uart.fail").unlink()
                    cli("board", "connect")
                    (root / "program.fail").touch()
                    failed = cli("board", "prepare", code=1)["error"]
                    self.assertEqual(failed["details"]["programming_status"], "unconfirmed")
                    self.assertEqual(
                        cli("board", "connect", code=1)["error"]["code"],
                        "BOARD_PREPARATION_REQUIRED",
                    )
                    self.assertEqual((root / "program.calls").read_text().count("program"), 3)
                    cli("work", "finish")
                    client.request("POST", "/api/v1/work/finish", {}, observer)
                self.assertEqual(core.wait(timeout=10), 0)
                self.assertFalse(discovery_file.exists())
            finally:
                if core.poll() is None:
                    core.terminate()
                    core.wait(timeout=10)
