"""PC-I01: contratos HTTP/CLI y procesos; contribuciones parciales al catálogo."""

import asyncio
import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

import httpx
from fastapi.testclient import TestClient

from software.tests.viewrv.session_api_cases import SessionApiTests as SessionApiTests
from software.tests.viewrv.session_cli_cases import LocalCliTests as LocalCliTests
from software.tests.viewrv.session_cli_cases import SessionCliProcessTests as SessionCliProcessTests
from software.viewrv.adapters.http import create_app
from software.viewrv.client.connection import CoreClient, connect
from software.viewrv.client.platform import InstanceGuard, publish_discovery, runtime_directory
from software.viewrv.client.resources import load_profile
from software.viewrv.contracts import STATE_BLOCKS, ApplicationError, validate_discovery
from software.viewrv.core.application import Application

TP3 = Path(__file__).resolve().parents[3]
PROFILE = {"profile_id": "tp3-riscv", "revision": 1, "memory_profile": "REFERENCE"}


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.discovery = {
            "base_url": "http://127.0.0.1:41987",
            "instance_id": str(uuid4()),
            "api_version": 1,
            "access_token": secrets.token_urlsafe(32),
        }
        self.application = Application(self.discovery["instance_id"])
        self.stopped = False

        async def shutdown():
            self.stopped = True

        self.client = TestClient(
            create_app(self.application, self.discovery, PROFILE, shutdown),
            base_url=self.discovery["base_url"],
            raise_server_exceptions=False,
        )
        self.client.headers.update({"Authorization": f"Bearer {self.discovery['access_token']}"})
        self.addCleanup(self.client.close)

    def assert_error(self, response, status, code):
        self.assertEqual(response.status_code, status, response.text)
        self.assertIsNone(response.json()["result"])
        self.assertEqual(response.json()["error"]["code"], code)

    def test_pc_015_authentication_and_exact_host_origin(self):
        self.assert_error(
            self.client.get("/api/v1/core/info", headers={"Authorization": ""}),
            401,
            "AUTHENTICATION_FAILED",
        )
        response = self.client.get(
            "/api/v1/core/info",
            headers={"Authorization": "Bearer invalid", "Origin": "viewrv://app"},
        )
        self.assert_error(response, 401, "AUTHENTICATION_FAILED")
        self.assertEqual(response.headers["www-authenticate"], "Bearer")
        self.assertEqual(response.headers["access-control-allow-origin"], "viewrv://app")
        for headers in (
            {"Host": "localhost:41987"},
            {"Host": "127.0.0.1:80"},
            {"Origin": "https://example.com"},
            {"Origin": "null"},
        ):
            self.assert_error(
                self.client.get("/api/v1/core/info", headers=headers), 400, "INVALID_REQUEST"
            )
        response = self.client.get("/api/v1/core/info", headers={"Origin": "viewrv://app"})
        self.assertEqual(response.json()["result"]["processor_profile"], PROFILE)
        self.assertFalse(self.application.works)

    def test_pc_017_query_without_registered_work_closes_after_response(self):
        response = self.client.get("/api/v1/work/cli/status")
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.json()["result"]["work_id"])
        self.assertFalse(self.application.works)
        self.assertTrue(self.stopped)

    def test_pc_015_preflight_is_finite_and_has_no_work_effect(self):
        headers = {
            "Authorization": "",
            "Origin": "viewrv://app",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization, content-type, x-viewrv-work-id",
        }
        self.assertEqual(
            self.client.options("/api/v1/work/register", headers=headers).status_code, 200
        )
        for key, value in (
            ("Origin", "https://example.com"),
            ("Access-Control-Request-Method", "DELETE"),
            ("Access-Control-Request-Headers", "cookie"),
        ):
            self.assert_error(
                self.client.options("/api/v1/work/register", headers={**headers, key: value}),
                400,
                "INVALID_REQUEST",
            )
        self.assertFalse(self.application.works)

    def test_pc_015_validation_and_transport_errors_use_envelope(self):
        for body in (
            {},
            {"client_type": "gui"},
            {"client_type": "gui", "registration_id": "bad"},
            {"client_type": "cli", "registration_id": str(uuid4())},
            {"client_type": "cli", "extra": True},
        ):
            self.assert_error(
                self.client.post("/api/v1/work/register", json=body), 400, "INVALID_REQUEST"
            )
        self.assert_error(
            self.client.post(
                "/api/v1/work/register",
                content="{bad",
                headers={"Content-Type": "application/json"},
            ),
            400,
            "INVALID_REQUEST",
        )
        self.assert_error(
            self.client.post("/api/v1/work/register", content="text"), 415, "REQUEST_NOT_SUPPORTED"
        )
        self.assert_error(self.client.get("/not-a-route"), 404, "REQUEST_NOT_SUPPORTED")
        response = self.client.get("/api/v1/work/register")
        self.assert_error(response, 405, "REQUEST_NOT_SUPPORTED")
        self.assertIn("POST", response.headers["allow"])

    def test_pc_017_finish_does_not_register_and_shutdown_follows_response(self):
        self.assert_error(self.client.post("/api/v1/work/finish", json={}), 409, "WORK_NOT_ACTIVE")
        gui = self.client.post(
            "/api/v1/work/register", json={"client_type": "gui", "registration_id": str(uuid4())}
        ).json()["result"]["work_id"]
        cli = self.client.post("/api/v1/work/register", json={"client_type": "cli"}).json()[
            "result"
        ]["work_id"]
        self.assert_error(
            self.client.post(
                "/api/v1/work/finish",
                json={"discard_unsaved": "yes"},
                headers={"X-Viewrv-Work-Id": gui},
            ),
            400,
            "INVALID_REQUEST",
        )
        self.assertEqual(
            self.client.post(
                "/api/v1/work/finish", json={}, headers={"X-Viewrv-Work-Id": gui}
            ).status_code,
            200,
        )
        self.assertFalse(self.stopped)
        response = self.client.post(
            "/api/v1/work/finish", json={}, headers={"X-Viewrv-Work-Id": cli}
        )
        self.assertTrue(response.json()["result"]["finished"])
        self.assertTrue(self.stopped)
        self.assert_error(
            self.client.post("/api/v1/work/register", json={"client_type": "cli"}),
            503,
            "CORE_SHUTTING_DOWN",
        )

    def test_pc_008_sse_requires_existing_gui_work(self):
        self.assert_error(self.client.get("/api/v1/events"), 409, "WORK_NOT_ACTIVE")
        cli = self.client.post("/api/v1/work/register", json={"client_type": "cli"}).json()[
            "result"
        ]["work_id"]
        self.assert_error(
            self.client.get("/api/v1/events", headers={"X-Viewrv-Work-Id": cli}),
            400,
            "INVALID_ARGUMENT",
        )


class DiscoveryTests(unittest.TestCase):
    def test_pc_015_reject_destinations_before_sending_credentials(self):
        good = {
            "base_url": "http://127.0.0.1:41234",
            "instance_id": str(uuid4()),
            "api_version": 1,
            "access_token": secrets.token_urlsafe(32),
        }
        for url in (
            "https://127.0.0.1:41234",
            "http://localhost:41234",
            "http://127.0.0.1:41234/",
            "http://127.0.0.1:41234?x=1",
            "http://user@127.0.0.1:41234",
            "http://127.0.0.1:65536",
            "http://example.com:80",
            "http://127.0.0.1:0",
        ):
            with self.subTest(url=url), self.assertRaises(ApplicationError):
                validate_discovery({**good, "base_url": url})
        with self.assertRaises(ApplicationError) as caught:
            validate_discovery({**good, "api_version": 2})
        self.assertEqual(caught.exception.code, "CORE_INCOMPATIBLE")

    def test_pc_014_profile_must_exist_and_be_known(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with self.assertRaises(FileNotFoundError):
                load_profile(root)
            (root / "content").mkdir()
            (root / "content/processor_profile.json").write_text(
                json.dumps({"schema_version": 1, **PROFILE, "memory_profile": "UNKNOWN"})
            )
            with self.assertRaises(ValueError):
                load_profile(root)

    def test_pc_014_resource_hashes_and_inventory_must_match(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "resources"
            shutil.copytree(TP3 / "software/resources/content", root / "content")
            self.assertEqual(load_profile(root), PROFILE)
            inventory = root.parent / "release.json"
            inventory.write_text(
                json.dumps(
                    {
                        "api_version": 1,
                        "processor_profile": {**PROFILE, "memory_profile": "ALT_1000"},
                    }
                )
            )
            with self.assertRaises(ValueError):
                load_profile(root)
            inventory.unlink()
            (root / "content/diagram_bindings.json").write_text("{}")
            with self.assertRaises(ValueError):
                load_profile(root)

    def test_pc_015_identity_profile_redirect_and_uncertain_result(self):
        discovery = {
            "base_url": "http://127.0.0.1:41234",
            "instance_id": str(uuid4()),
            "api_version": 1,
            "access_token": secrets.token_urlsafe(32),
        }
        with CoreClient(discovery) as client:
            client.http.close()
            for info, expected in (
                (
                    {"instance_id": str(uuid4()), "api_version": 1, "processor_profile": PROFILE},
                    "CORE_IDENTITY_MISMATCH",
                ),
                (
                    {
                        "instance_id": discovery["instance_id"],
                        "api_version": 1,
                        "processor_profile": {**PROFILE, "memory_profile": "ALT_1000"},
                    },
                    "CORE_INCOMPATIBLE",
                ),
            ):
                client.http = httpx.Client(
                    transport=httpx.MockTransport(
                        lambda request: httpx.Response(200, json={"result": info, "error": None})
                    ),
                    base_url=discovery["base_url"],
                )
                with self.assertRaises(ApplicationError) as caught:
                    client.validate(PROFILE)
                self.assertEqual(caught.exception.code, expected)
                client.http.close()
            requests = []

            def handler(request):
                requests.append(request)
                return httpx.Response(307, headers={"Location": "http://example.com"})

            client.http = httpx.Client(
                transport=httpx.MockTransport(handler), base_url=discovery["base_url"]
            )
            with self.assertRaises(ApplicationError) as caught:
                client.request("POST", "/api/v1/work/finish", {})
            self.assertEqual(caught.exception.code, "REQUEST_RESULT_UNCONFIRMED")
            self.assertEqual(len(requests), 1)


class ProcessTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        root = Path(self.folder.name)
        self.environment = {
            **os.environ,
            "XDG_RUNTIME_DIR": str(root),
            "XDG_STATE_HOME": str(root / "state"),
            "XDG_DATA_HOME": str(root / "data"),
            "XDG_CONFIG_HOME": str(root / "config"),
            "PYTHONPATH": str(TP3),
            "HTTP_PROXY": "http://127.0.0.1:1",
            "HTTPS_PROXY": "http://127.0.0.1:1",
            "ALL_PROXY": "http://127.0.0.1:1",
        }
        if os.name == "nt":
            self.skipTest("El aislamiento de LocalAppData requiere la cuenta de prueba Windows.")
        self.env_patch = patch.dict(os.environ, self.environment)
        self.env_patch.start()
        self.addCleanup(self.env_patch.stop)
        self.children = []
        self.addCleanup(self.cleanup_children)

    def cleanup_children(self):
        for child in self.children:
            if child.poll() is None:
                child.terminate()
            child.wait(timeout=10)

    def start(self, *args):
        child = subprocess.Popen(
            [sys.executable, "-m", "software.viewrv.core", *args],
            cwd=TP3,
            env=self.environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.children.append(child)
        return child

    def cli(self, *args):
        return subprocess.run(
            [sys.executable, "-m", "software.viewrv.cli", *args],
            cwd=self.folder.name,
            env=self.environment,
            capture_output=True,
            text=True,
            timeout=20,
        )

    def test_pc_013_help_version_and_usage_never_start_core(self):
        for args in (
            ("--help",),
            ("--output", "json", "--version"),
            ("--output", "json", "work", "finish", "--help"),
        ):
            result = self.cli(*args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(result.stdout.startswith("{"))
        result = self.cli("--output", "json", "work", "finish", "--invalid")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout)["error"]["code"], "INVALID_ARGUMENT")
        self.assertFalse((runtime_directory() / "core.json").exists())

    def test_pc_015_concurrent_start_and_cli_continuity_without_electron(self):
        children = [self.start() for _ in range(5)]
        with connect() as client:
            with ThreadPoolExecutor(max_workers=8) as pool:
                ids = list(
                    pool.map(
                        lambda _: client.request(
                            "POST", "/api/v1/work/register", {"client_type": "cli"}
                        )["work_id"],
                        range(16),
                    )
                )
            self.assertEqual(len(set(ids)), 1)
            discovery = runtime_directory() / "core.json"
            self.assertEqual(discovery.stat().st_mode & 0o777, 0o600)
            self.assertEqual(discovery.parent.stat().st_mode & 0o777, 0o700)
            guard = InstanceGuard()
            self.assertFalse(guard.acquire())
            result = self.cli("--output", "json", "work", "status")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(json.loads(result.stdout)["result"]["work_id"], ids[0])
            result = self.cli("board", "status")
            self.assertEqual(result.returncode, 0)
            self.assertIn("Conexión: closed", result.stdout)
            result = self.cli("--output", "json", "work", "finish")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertTrue(json.loads(result.stdout)["result"]["finished"])
        deadline = time.monotonic() + 5
        while discovery.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertFalse(discovery.exists())
        for child in children:
            self.assertEqual(child.wait(timeout=5), 0)
        guard = InstanceGuard()
        self.assertTrue(guard.acquire())
        guard.release()
        self.assertTrue(guard.path.exists())

    def test_pc_008_real_sse_initial_update_keepalive_and_gui_close(self):
        server = self.start()
        with connect() as client:
            gui = client.request(
                "POST",
                "/api/v1/work/register",
                {"client_type": "gui", "registration_id": str(uuid4())},
            )["work_id"]
            with client.http.stream(
                "GET", "/api/v1/events", headers={"X-Viewrv-Work-Id": gui}, timeout=20
            ) as response:
                self.assertEqual(response.status_code, 200)
                lines = response.iter_lines()

                def next_data():
                    for line in lines:
                        if line.startswith("data: "):
                            return json.loads(line[6:])
                    self.fail("SSE closed before data")

                state = next_data()
                self.assertEqual(state["type"], "state")
                self.assertEqual(set(state["data"]), STATE_BLOCKS)
                cli = client.request("POST", "/api/v1/work/register", {"client_type": "cli"})[
                    "work_id"
                ]
                update = next_data()
                self.assertEqual(update["state_revision"], state["state_revision"] + 1)
                self.assertEqual(len(update["data"]["works"]), 2)
                keepalive = next(line for line in lines if line.startswith(":"))
                self.assertTrue(keepalive.startswith(":"))
                self.assertEqual(client.request("GET", "/api/v1/work/cli/status")["work_id"], cli)
                client.request("POST", "/api/v1/work/finish", {}, gui)
                list(lines)
            self.assertEqual(
                client.request("GET", "/api/v1/core/info")["instance_id"],
                client.discovery["instance_id"],
            )
            client.request("POST", "/api/v1/work/finish", {}, cli)
        self.assertEqual(server.wait(timeout=5), 0)

    def test_pc_017_initial_cli_query_leaves_no_unused_core(self):
        from software.viewrv.client.connection import start_candidate

        def candidate(*args):
            child = start_candidate(*args)
            self.children.append(child)
            return child

        with patch("software.viewrv.client.connection.start_candidate", candidate):
            with connect() as client:
                self.assertIsNone(client.request("GET", "/api/v1/work/cli/status")["work_id"])
        path = runtime_directory() / "core.json"
        deadline = time.monotonic() + 5
        while path.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertFalse(path.exists())

    def test_pc_015_client_can_start_after_last_query_closes_core(self):
        from software.viewrv.client.connection import start_candidate

        def candidate(*args):
            child = start_candidate(*args)
            self.children.append(child)
            return child

        with patch("software.viewrv.client.connection.start_candidate", candidate):
            for _ in range(3):
                with connect(startup_timeout=4) as client:
                    result = client.request("GET", "/api/v1/work/cli/status")
                    self.assertIsNone(result["work_id"])

    def test_pc_014_invalid_profile_never_publishes(self):
        root = Path(self.folder.name) / "missing-resources"
        child = self.start("--resources", str(root))
        self.assertEqual(child.wait(timeout=5), 1)
        self.assertFalse((runtime_directory() / "core.json").exists())

    def test_pc_015_stale_discovery_recovers_only_through_new_lock_owner(self):
        discovery = {
            "base_url": "http://127.0.0.1:1",
            "instance_id": str(uuid4()),
            "api_version": 1,
            "access_token": secrets.token_urlsafe(32),
        }
        publish_discovery(runtime_directory() / "core.json", discovery)
        # Keep a handle to the candidate, so cleanup cannot leak a test process.
        from software.viewrv.client.connection import start_candidate

        def candidate(*args):
            child = start_candidate(*args)
            self.children.append(child)
            return child

        with (
            patch("software.viewrv.client.connection.start_candidate", candidate),
            connect() as client,
        ):
            self.assertNotEqual(client.discovery["instance_id"], discovery["instance_id"])
            work = client.request("POST", "/api/v1/work/register", {"client_type": "cli"})[
                "work_id"
            ]
            client.request("POST", "/api/v1/work/finish", {}, work)

    def test_pc_015_busy_lock_without_publication_is_not_replaced(self):
        discovery = {
            "base_url": "http://127.0.0.1:1",
            "instance_id": str(uuid4()),
            "api_version": 1,
            "access_token": secrets.token_urlsafe(32),
        }
        path = runtime_directory() / "core.json"
        publish_discovery(path, discovery)
        with InstanceGuard():
            with self.assertRaises(ApplicationError) as caught:
                connect(startup_timeout=0.3)
            self.assertEqual(caught.exception.code, "CORE_UNAVAILABLE")
            self.assertEqual(json.loads(path.read_text()), discovery)


class ProgramApiTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        from software.tests.viewrv.controlled import ControlledAssembler
        from software.tests.viewrv.test_storage import RecordingStorage

        self.temp = tempfile.TemporaryDirectory()
        self.storage = RecordingStorage(Path(self.temp.name))
        self.assembler = ControlledAssembler()
        self.application = Application(str(uuid4()))
        await self.application.initialize(
            self.storage, self.assembler, {"fixture": {"source_text": "addi x1,x0,5\nhalt\n"}}
        )
        discovery = {
            "base_url": "http://127.0.0.1:41987",
            "instance_id": self.application.instance_id,
            "api_version": 1,
            "access_token": secrets.token_urlsafe(32),
        }

        async def stop():
            pass

        api = create_app(self.application, discovery, PROFILE, stop)
        self.client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=api),
            base_url=discovery["base_url"],
            headers={"Authorization": f"Bearer {discovery['access_token']}"},
        )
        self.owner = (
            await self.client.post(
                "/api/v1/work/register",
                json={"client_type": "gui", "registration_id": str(uuid4())},
            )
        ).json()["result"]["work_id"]
        self.client.headers["X-Viewrv-Work-Id"] = self.owner

    async def asyncTearDown(self):
        self.assembler.release.set()
        self.storage.source_release.set()
        await self.client.aclose()
        await self.application.shutdown()
        self.temp.cleanup()

    async def test_pc_002_editor_endpoints_and_canonical_program_shape(self):
        result = (await self.client.post("/api/v1/program/create", json={})).json()["result"]
        self.assertEqual(
            set(result),
            {
                "program_id",
                "source_version",
                "source_text",
                "source_path",
                "example_id",
                "is_open",
                "edit_protected",
                "saved_version",
                "recovery_version",
            },
        )
        capture = {
            "program_id": result["program_id"],
            "source_version": str(uuid4()),
            "source_text": "addi x1,x0,5\nhalt\n",
        }
        updated = (await self.client.post("/api/v1/program/update", json=capture)).json()["result"]
        self.assertEqual(updated["source_text"], capture["source_text"])
        assembled = (await self.client.post("/api/v1/program/assemble", json=capture)).json()[
            "result"
        ]
        self.assertEqual(assembled["source_version"], capture["source_version"])
        self.assertEqual(assembled["image"], [147, 0, 80, 0, 11, 0, 0, 0])
        destination = Path(self.temp.name) / "name with spaces.s"
        saved = await self.client.post(
            "/api/v1/program/save", json={**capture, "source_path": str(destination)}
        )
        self.assertEqual(saved.status_code, 200, saved.text)
        self.assertEqual(destination.read_text(), capture["source_text"])
        closed = await self.client.post("/api/v1/program/close", json=capture)
        self.assertFalse(closed.json()["result"]["is_open"])
        recovered = await self.client.post(
            "/api/v1/program/recover", json={"program_id": capture["program_id"]}
        )
        self.assertTrue(recovered.json()["result"]["is_open"])
        discarded = await self.client.post(
            "/api/v1/program/discard", json={"program_id": capture["program_id"]}
        )
        self.assertTrue(discarded.json()["result"]["discarded"])
        self.assertTrue(destination.exists())
        self.assertEqual(
            (await self.client.get("/api/v1/program/list")).json()["result"]["programs"], []
        )

    async def test_pc_002_assembly_error_envelope_preserves_revision_and_line(self):
        program = (await self.client.post("/api/v1/program/create", json={})).json()["result"]
        capture = {
            "program_id": program["program_id"],
            "source_version": str(uuid4()),
            "source_text": "invalid\n",
        }
        await self.client.post("/api/v1/program/update", json=capture)
        response = await self.client.post("/api/v1/program/assemble", json=capture)
        self.assertEqual(response.status_code, 422)
        self.assertEqual(
            response.json()["error"]["details"],
            {
                "program_id": program["program_id"],
                "source_version": capture["source_version"],
                "line": 1,
            },
        )
        self.assertIsNone(response.json()["result"])
        for body in (
            {},
            {"source_path": "/tmp/test.s", "program_id": program["program_id"]},
            {"program_id": program["program_id"]},
        ):
            response = await self.client.post("/api/v1/program/assemble", json=body)
            self.assertEqual(response.status_code, 400)
            self.assertEqual(response.json()["error"]["code"], "INVALID_ARGUMENT")

    async def test_pc_012_preference_contract_and_failure_details(self):
        initial = (await self.client.get("/api/v1/preferences")).json()["result"]
        self.assertEqual(initial["preferences"]["language"], "es")
        self.storage.fail_preferences = True
        response = await self.client.post("/api/v1/preferences/update", json={"ui_zoom": 1.25})
        self.assertEqual(response.status_code, 500)
        self.assertEqual(response.json()["error"]["code"], "PREFERENCES_WRITE_FAILED")
        self.assertEqual(response.json()["error"]["details"]["path"], str(self.storage.preferences))
        current = (await self.client.get("/api/v1/preferences")).json()["result"]
        self.assertEqual(initial, current)
        self.storage.fail_preferences = False
        response = await self.client.post(
            "/api/v1/preferences/update",
            json={"default_author": "Franco", "record_by_default": False},
        )
        self.assertEqual(response.json()["result"]["preferences"]["default_author"], "Franco")
        self.assertFalse(response.json()["result"]["preferences"]["record_by_default"])
        for invalid in (
            {"schema_version": 1},
            {"language": "en"},
            {"ui_zoom": 3},
            {"unknown": True},
        ):
            self.assertEqual(
                (await self.client.post("/api/v1/preferences/update", json=invalid)).status_code,
                400,
            )

    async def test_pc_026_failed_close_preserves_work_and_emits_structured_failures(self):
        program = (await self.client.post("/api/v1/program/create", json={})).json()["result"]
        self.storage.fail_recovery = True
        response = await self.client.post("/api/v1/work/finish", json={})
        self.assertEqual(response.status_code, 500)
        self.assertEqual(response.json()["error"]["code"], "CODE_SAVE_FAILED")
        self.assertEqual(
            response.json()["error"]["details"]["failures"][0]["program_id"], program["program_id"]
        )
        self.assertIn(self.owner, self.application.works)
        response = await self.client.post("/api/v1/work/finish", json={"discard_unsaved": True})
        self.assertTrue(response.json()["result"]["finished"])
        self.assertEqual(len(response.json()["result"]["discarded_sources"]), 1)

    async def test_pc_002_editor_routes_require_gui_and_examples_stay_independent(self):
        first = (
            await self.client.post("/api/v1/program/open-example", json={"example_id": "fixture"})
        ).json()["result"]
        second = (
            await self.client.post("/api/v1/program/open-example", json={"example_id": "fixture"})
        ).json()["result"]
        self.assertNotEqual(first["program_id"], second["program_id"])
        cli = (await self.client.post("/api/v1/work/register", json={"client_type": "cli"})).json()[
            "result"
        ]["work_id"]
        response = await self.client.post(
            "/api/v1/program/create", json={}, headers={"X-Viewrv-Work-Id": cli}
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()["error"]["code"], "INVALID_ARGUMENT")


@unittest.skipIf(
    os.name == "nt", "Windows acceptance remains pending; isolate LocalAppData separately."
)
class ProgramProcessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="viewrv-pc02-")
        self.root = Path(self.temp.name)
        self.environment = {
            **os.environ,
            "XDG_RUNTIME_DIR": str(self.root),
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_DATA_HOME": str(self.root / "data"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "PYTHONPATH": str(TP3),
        }
        self.env = patch.dict(os.environ, self.environment)
        self.env.start()
        self.children = []
        self.addCleanup(self.cleanup)

    def cleanup(self):
        for child in self.children:
            if child.poll() is None:
                child.terminate()
            child.wait(timeout=10)
        self.env.stop()
        self.temp.cleanup()

    def start(self):
        child = subprocess.Popen(
            [sys.executable, "-m", "software.tests.viewrv.controlled_core"],
            cwd=TP3,
            env=self.environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.children.append(child)
        discovery = self.root / "viewrv/core.json"
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if discovery.exists():
                try:
                    value = json.loads(discovery.read_text())
                    from software.viewrv.client.connection import CoreClient

                    with CoreClient(value) as client:
                        client.request("GET", "/api/v1/core/info")
                    return child
                except Exception:
                    pass
            self.assertIsNone(child.poll(), "Controlled core ended during startup")
            time.sleep(0.05)
        self.fail("Core did not publish readiness")

    def cli(self, *args):
        return subprocess.run(
            [sys.executable, "-m", "software.viewrv.cli", *args],
            cwd=self.root,
            env=self.environment,
            capture_output=True,
            text=True,
            timeout=20,
        )

    def test_pc_010_abrupt_core_loss_restores_confirmed_text_revision_and_open_state(self):
        child = self.start()
        with connect() as client:
            owner = client.request(
                "POST",
                "/api/v1/work/register",
                {"client_type": "gui", "registration_id": str(uuid4())},
            )["work_id"]
            p = client.request("POST", "/api/v1/program/create", {}, owner)
            version = str(uuid4())
            started = time.monotonic()
            client.request(
                "POST",
                "/api/v1/program/update",
                {
                    "program_id": p["program_id"],
                    "source_version": version,
                    "source_text": "# texto confirmado\n",
                },
                owner,
            )
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                programs = client.request("GET", "/api/v1/program/list", work_id=owner)["programs"]
                if programs[0]["recovery_version"] == version:
                    break
                time.sleep(0.03)
            else:
                self.fail("Autosave was not confirmed")
            self.assertLess(time.monotonic() - started, 2)
            identity = client.discovery["instance_id"]
        child.kill()
        child.wait(timeout=5)
        restarted = self.start()
        with connect() as client:
            self.assertNotEqual(client.discovery["instance_id"], identity)
            owner = client.request(
                "POST",
                "/api/v1/work/register",
                {"client_type": "gui", "registration_id": str(uuid4())},
            )["work_id"]
            recovered = client.request("GET", "/api/v1/program/list", work_id=owner)["programs"][0]
            self.assertEqual(recovered["program_id"], p["program_id"])
            self.assertEqual(recovered["source_version"], version)
            self.assertEqual(recovered["source_text"], "# texto confirmado\n")
            self.assertTrue(recovered["is_open"])
            self.assertEqual(
                client.request("GET", "/api/v1/board/status")["connection_status"], "closed"
            )
            client.request("POST", "/api/v1/work/finish", {}, owner)
        self.assertEqual(restarted.wait(timeout=5), 0)

    def test_pc_013_cli_relative_file_json_diagnostic_and_persistent_context(self):
        self.start()
        source = self.root / "source with spaces.s"
        source.write_text("addi x1,x0,5\nhalt\n")
        result = self.cli("--output", "json", "program", "assemble", source.name)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        translated = json.loads(result.stdout)["result"]
        self.assertEqual(translated["image"], [147, 0, 80, 0, 11, 0, 0, 0])
        context = json.loads(self.cli("--output", "json", "work", "status").stdout)["result"]
        self.assertIsNotNone(context["work_id"])
        source.write_text("invalid\n")
        result = self.cli("--output", "json", "program", "assemble", source.name)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["error"]["details"]["line"], 1)
        self.assertEqual(
            json.loads(self.cli("--output", "json", "work", "status").stdout)["result"]["work_id"],
            context["work_id"],
        )
        missing = self.cli("--output", "json", "program", "assemble", "missing.s")
        self.assertEqual(json.loads(missing.stdout)["error"]["code"], "SOURCE_NOT_FOUND")
        self.assertEqual(self.cli("--output", "json", "work", "finish").returncode, 0)


class SerialApiTests(unittest.IsolatedAsyncioTestCase):
    async def test_pc007_http_edit_and_storage_remain_available_during_pending_step(self):
        from software.tests.viewrv.controlled import ControlledAssembler
        from software.tests.viewrv.serial_fixture import Clock, ScriptedPort, literal
        from software.tests.viewrv.test_protocol import until
        from software.viewrv.adapters.files import FileStorage
        from software.viewrv.adapters.serial import SerialTransport

        clock = Clock()
        port = ScriptedPort(clock, [(b"\x05", [(0, b"\x05\x03")]), (b"\x03", [(0, literal())])])
        engine = SerialTransport("ALT_1000", lambda name: port, clock)
        entered, release = threading.Event(), threading.Event()
        original = port.read

        def gated(size):
            if engine.phase == "debug_fixed" and not release.is_set():
                entered.set()
                if not release.wait(0.05):
                    clock.advance(clock() + 0.05)
                    return b""
            return original(size)

        port.read = gated
        application = Application(str(uuid4()))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            await application.initialize(
                FileStorage(root / "data", root / "config"),
                ControlledAssembler(),
                serial_transport=engine,
            )
            discovery = {
                "base_url": "http://127.0.0.1:41987",
                "instance_id": application.instance_id,
                "api_version": 1,
                "access_token": secrets.token_urlsafe(32),
            }

            async def stop():
                pass

            api = create_app(
                application, discovery, {**PROFILE, "memory_profile": "ALT_1000"}, stop
            )
            try:
                async with httpx.AsyncClient(
                    transport=httpx.ASGITransport(app=api),
                    base_url=discovery["base_url"],
                    headers={"Authorization": "Bearer " + discovery["access_token"]},
                ) as client:
                    work = application.register("gui", str(uuid4()))["work_id"]
                    client.headers["X-Viewrv-Work-Id"] = work
                    await application.serial_service.request("PREPARED")
                    await application.serial_service.request("OPEN", {"port": "controlled"})
                    self.assertEqual(application.board["connection_status"], "checked")
                    subscription = application.subscribe(work)
                    step = application.serial_service.submit("STEP")
                    await until(entered.is_set)
                    self.assertFalse(step.done())
                    status = (await client.get("/api/v1/board/status")).json()["result"]
                    self.assertEqual(status["connection_status"], "checked")
                    program = (await client.post("/api/v1/program/create", json={})).json()[
                        "result"
                    ]
                    capture = {
                        "program_id": program["program_id"],
                        "source_version": str(uuid4()),
                        "source_text": "# editable while serial waits\n",
                    }
                    updated = (await client.post("/api/v1/program/update", json=capture)).json()[
                        "result"
                    ]
                    await application.program_service.flush(
                        application.program_service.get(program["program_id"])
                    )
                    self.assertEqual(updated["source_text"], capture["source_text"])
                    self.assertTrue(
                        (root / "data/recovery" / f"{program['program_id']}.json").exists()
                    )
                    self.assertFalse(subscription.pending.empty())
                    self.assertFalse(
                        step.done(), "HTTP or storage must not wait for the serial exchange"
                    )
                    with self.assertRaises(ApplicationError):
                        application.serial_service.submit("STEP")
                    release.set()
                    self.assertIsNotNone((await step)["snapshot"])
                    await application.serial_service.disconnect()
                    self.assertEqual(application.board["connection_status"], "closed")
                    self.assertTrue(application.serial_service.thread.is_alive())
            finally:
                release.set()
                await application.shutdown()
            self.assertFalse(application.serial_service.thread.is_alive())

    async def test_global_shutdown_signals_run_before_waiting_for_application_tasks(self):
        from software.tests.viewrv.controlled import ControlledAssembler
        from software.tests.viewrv.serial_fixture import Clock, ScriptedPort
        from software.viewrv.adapters.files import FileStorage
        from software.viewrv.adapters.serial import SerialTransport

        clock = Clock()
        port = ScriptedPort(
            clock,
            [
                (b"\x05", [(0, b"\x05\x03")]),
                (b"\x02", [(0, b"\x02\x01")]),
                (b"\x04", [(0, b"\x04\x01")]),
            ],
        )
        engine = SerialTransport("REFERENCE", lambda name: port, clock)
        application = Application(str(uuid4()))
        accepted = asyncio.Event()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            await application.initialize(
                FileStorage(root / "data", root / "config"),
                ControlledAssembler(),
                serial_transport=engine,
            )

            def notice(value):
                application._serial_notification(value)
                if value["kind"] == "progress" and value["data"].get("phase") == "run_accepted":
                    accepted.set()

            application.serial_service.on_notification = notice
            try:
                await application.serial_service.request("PREPARED")
                await application.serial_service.request("OPEN", {"port": "controlled"})
                owner = application.register("cli")["work_id"]
                result = asyncio.create_task(
                    application.execute(
                        owner, "run start", lambda: application.serial_service.request("RUN")
                    )
                )
                await asyncio.wait_for(accepted.wait(), 2)
                self.assertEqual(application.cli_status()["pending_commands"], ["run start"])
                await asyncio.wait_for(application.shutdown(), 2)
                self.assertEqual((await result)["reset_status"], "confirmed")
                self.assertEqual(application.cli_status()["pending_commands"], [])
                self.assertFalse(application.serial_service.thread.is_alive())
            finally:
                await application.shutdown()
