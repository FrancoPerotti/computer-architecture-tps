"""Session HTTP/SSE contracts and core-owned operation lifetime."""

import asyncio
import threading
from uuid import uuid4

import httpx

from software.tests.viewrv.session_cases import SessionFixture
from software.tests.viewrv.test_storage import until
from software.viewrv.adapters.http import create_app


class SessionApiTests(SessionFixture):
    async def test_http_statuses_distinguish_invalid_location_missing_definition_conflict_and_cpu_fault(
        self,
    ):
        """TEST-PC-015: http statuses distinguish invalid location missing definition conflict and cpu fault."""
        await self.debug()
        async with await self.client() as client:
            for route, body, status, code in (
                (
                    "debug/breakpoint/add",
                    {"pc": 2, "latch": "IF/ID"},
                    422,
                    "INVALID_BREAKPOINT_LOCATION",
                ),
                (
                    "debug/breakpoint/remove",
                    {"pc": 0, "latch": "IF/ID"},
                    404,
                    "BREAKPOINT_NOT_FOUND",
                ),
                (
                    "debug/breakpoint/add",
                    {"pc": 0, "line": 1, "latch": "IF/ID"},
                    400,
                    "INVALID_ARGUMENT",
                ),
            ):
                response = await client.post("/api/v1/" + route, json=body)
                self.assertEqual(response.status_code, status, response.text)
                self.assertEqual(response.json()["error"]["code"], code)
            added = await client.post(
                "/api/v1/debug/breakpoint/add", json={"pc": 0, "latch": "IF/ID"}
            )
            self.assertEqual(added.status_code, 200)
            duplicate = await client.post(
                "/api/v1/debug/breakpoint/add", json={"pc": 0, "latch": "IF/ID"}
            )
            self.assertEqual(duplicate.status_code, 409)
            unknown = await client.get("/api/v1/session/show?session_id=" + str(uuid4()))
            self.assertEqual(unknown.status_code, 404)
            self.step_reply(state=11)
            terminal = await client.post("/api/v1/debug/step", json={})
            self.assertEqual(terminal.status_code, 200)
            self.assertIsNone(terminal.json()["error"])
            self.assertEqual(terminal.json()["result"]["snapshot"]["global_state"], 11)

    async def test_disconnect_while_reading_source_does_not_start_a_later_uart_load(self):
        """TEST-PC-024: disconnect while reading source does not start a later uart load."""
        path = self.root / "delayed source.s"
        await self.programs.save(self.owner, **self.capture, source_path=str(path))
        original = self.storage.read_source
        entered = threading.Event()
        self.release.clear()

        def read(path):
            entered.set()
            if not self.release.wait(5):
                raise TimeoutError("Controlled source read gate")
            return original(path)

        self.storage.read_source = read
        before = len(self.port.writes)
        async with await self.client() as client:
            loading = asyncio.create_task(
                client.post("/api/v1/program/load", json={"source_path": str(path)})
            )
            await until(entered.is_set)
            disconnecting = asyncio.create_task(client.post("/api/v1/board/disconnect", json={}))
            await asyncio.sleep(0.01)
            self.assertFalse(disconnecting.done())
            self.release.set()
            loaded, closed = await asyncio.gather(loading, disconnecting)
            self.assertEqual(loaded.json()["error"]["code"], "OPERATION_CONFLICT")
            self.assertEqual(closed.json()["result"], {"connection_status": "closed"})
        self.assertEqual(len(self.port.writes), before)

    async def test_run_and_debug_during_pending_load_are_conflicts_not_queued_starts(self):
        """TEST-PC-005 / TEST-PC-017: run and debug during pending load are conflicts not queued starts."""
        self.load_reply()
        entered = self.gate_reads()
        async with await self.client() as client:
            pending = asyncio.create_task(client.post("/api/v1/program/load", json=self.capture))
            await until(entered.is_set)
            references = {key: self.capture[key] for key in ("program_id", "source_version")}
            before = len(self.port.writes)
            for route in ("run/start", "debug/start"):
                response = await client.post("/api/v1/" + route, json=references)
                self.assertEqual(response.json()["error"]["code"], "OPERATION_CONFLICT")
            self.assertEqual(len(self.port.writes), before)
            self.assertIsNone(self.app.works[self.owner]["session_id"])
            self.release.set()
            loaded = await pending
            self.assertIsNone(loaded.json()["error"])
            self.assertFalse(any(data in (b"\x02", b"\x03") for _, data in self.port.writes))

    async def test_breakpoint_added_before_pending_capture_evaluation_applies_to_that_capture(self):
        """TEST-PC-005: breakpoint added before pending capture evaluation applies to that capture."""
        opened = await self.debug()
        self.step_reply()
        entered = self.gate_reads()
        async with await self.client() as client:
            pending = asyncio.create_task(client.post("/api/v1/debug/step", json={}))
            await until(entered.is_set)
            added = await client.post(
                "/api/v1/debug/breakpoint/add", json={"pc": 0, "latch": "IF/ID"}
            )
            self.assertIsNone(added.json()["error"])
            self.release.set()
            result = (await pending).json()["result"]
            self.assertEqual(result["breakpoint_hits"], [{"pc": 0, "line": 1, "latch": "IF/ID"}])
            self.assertEqual(result["session_id"], opened["session_id"])

    async def test_failed_code_conservation_keeps_work_but_does_not_reopen_debug_or_uart(self):
        """TEST-PC-026: failed code conservation keeps work but does not reopen debug or uart."""
        opened = await self.debug()
        self.storage.fail_recovery = True
        async with await self.client() as client:
            response = await client.post("/api/v1/work/finish", json={})
            self.assertEqual(response.json()["error"]["code"], "CODE_SAVE_FAILED")
            self.assertIn(self.owner, self.app.works)
            self.assertFalse(self.app.works[self.owner]["debug_open"])
            self.assertEqual(self.app.board["connection_status"], "closed")
            self.assertEqual(
                (await self.sessions.show(session_id=opened["session_id"]))["execution_status"],
                "interrupted",
            )
            before = len(self.port.writes)
            self.storage.fail_recovery = False
            retried = await client.post("/api/v1/work/finish", json={})
            self.assertTrue(retried.json()["result"]["finished"])
            self.assertEqual(len(self.port.writes), before)

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
        api = create_app(self.app, discovery, self.sessions.profile, stop)
        return httpx.AsyncClient(
            transport=httpx.ASGITransport(app=api),
            base_url=discovery["base_url"],
            headers={"Authorization": "Bearer controlled-token", "X-Viewrv-Work-Id": self.owner},
        )

    async def test_shared_load_debug_step_and_query_response_shapes(self):
        """TEST-PC-003 / TEST-PC-030: shared load debug step and query response shapes."""
        async with await self.client() as client:
            self.load_reply()
            loaded = (await client.post("/api/v1/program/load", json=self.capture)).json()
            self.assertIsNone(loaded["error"])
            self.assertEqual(set(loaded["result"]), {"program_id", "source_version", "byte_count"})
            refs = {key: self.capture[key] for key in ("program_id", "source_version")}
            opened = (await client.post("/api/v1/debug/start", json=refs)).json()["result"]
            self.assertIsNone(opened["snapshot"])
            self.step_reply()
            step = (await client.post("/api/v1/debug/step", json={})).json()["result"]
            self.assertEqual(
                set(step),
                {
                    "session_id",
                    "program_id",
                    "source_version",
                    "step_index",
                    "snapshot",
                    "breakpoint_hits",
                    "interpretation",
                },
            )
            await self.sessions.known[opened["session_id"]].writer.finish()
            before = len(self.port.writes)
            path = "/api/v1/session/steps?session_id=" + opened["session_id"]
            first = (await client.get(path)).json()["result"]
            second = (await client.get(path)).json()["result"]
            self.assertEqual(first, second)
            self.assertEqual([value["step_index"] for value in first["steps"]], [1])
            self.assertEqual((await client.get(path + "&after=1")).json()["result"]["steps"], [])
            self.assertEqual(len(self.port.writes), before)

    async def test_gui_missing_partial_or_stale_reference_is_rejected_before_uart(self):
        """TEST-PC-017: gui missing partial or stale reference is rejected before uart."""
        await self.load()
        before = len(self.port.writes)
        async with await self.client() as client:
            for body, code in (
                ({}, "INVALID_ARGUMENT"),
                ({"program_id": self.capture["program_id"]}, "INVALID_ARGUMENT"),
                (
                    {"program_id": self.capture["program_id"], "source_version": str(uuid4())},
                    "SOURCE_VERSION_MISMATCH",
                ),
                ({"program_id": str(uuid4()), "source_version": str(uuid4())}, "PROGRAM_NOT_FOUND"),
            ):
                response = await client.post("/api/v1/run/start", json=body)
                self.assertEqual(response.json()["error"]["code"], code, response.text)
            self.assertEqual(len(self.port.writes), before)

    async def test_strict_bodies_options_and_incremental_arguments_do_not_operate_uart(self):
        """TEST-PC-015: strict bodies options and incremental arguments do not operate uart."""
        before = len(self.port.writes)
        async with await self.client() as client:
            for route, body in (
                ("run/start", {"limit_seconds": True}),
                ("run/start", {"limit_seconds": -1}),
                ("debug/start", {"record": 1}),
                ("debug/step", {"extra": True}),
                ("program/load", {"source_path": "file", "program_id": str(uuid4())}),
            ):
                response = await client.post("/api/v1/" + route, json=body)
                self.assertEqual(response.status_code, 400, response.text)
            for after in ("-1", "1.2", "bad"):
                response = await client.get("/api/v1/session/steps?after=" + after)
                self.assertEqual(response.json()["error"]["code"], "INVALID_ARGUMENT")
            self.assertEqual(
                (await client.post("/api/v1/debug/start", json={"record": None})).json()["error"][
                    "code"
                ],
                "INVALID_ARGUMENT",
            )
        self.assertEqual(len(self.port.writes), before)

    async def test_cancelled_http_waiter_leaves_step_owned_by_core_until_result_processed(self):
        """TEST-PC-029 / TEST-PC-030: cancelled http waiter leaves step owned by core until result processed."""
        opened = await self.debug()
        self.step_reply()
        entered = self.gate_reads()
        async with await self.client() as client:
            waiter = asyncio.create_task(client.post("/api/v1/debug/step", json={}))
            await until(entered.is_set)
            waiter.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await waiter
            self.assertIsNotNone(self.app.board_operation)
            response = await client.post("/api/v1/debug/step", json={})
            self.assertEqual(response.json()["error"]["code"], "OPERATION_CONFLICT")
            self.release.set()
            await until(lambda: not self.app.tasks)
            show = (
                await client.get("/api/v1/session/show?session_id=" + opened["session_id"])
            ).json()["result"]
            self.assertEqual(show["last_observation"]["step_index"], 1)
            self.assertEqual(sum(data == b"\x03" for _, data in self.port.writes), 1)

    async def test_finishing_owner_during_run_resolves_reset_then_closes_uart_and_keeps_observer(
        self,
    ):
        """TEST-PC-023 / TEST-PC-026: finishing owner during run resolves reset then closes uart and keeps observer."""
        await self.load()
        self.port.script.extend([(b"\x02", [(0, b"\x02\x01")]), (b"\x04", [(0, b"\x04\x01")])])
        async with await self.client() as client:
            running = asyncio.create_task(
                client.post(
                    "/api/v1/run/start",
                    json={key: self.capture[key] for key in ("program_id", "source_version")},
                )
            )
            await until(lambda: any(data == b"\x02" for _, data in self.port.writes))
            finished = await client.post("/api/v1/work/finish", json={})
            result = (await running).json()["result"]
            self.assertEqual(result["interruption"], {"reason": "user_request"})
            self.assertTrue(finished.json()["result"]["finished"])
            self.assertTrue(self.port.closed)
            self.assertNotIn(self.owner, self.app.works)
            self.assertIn(self.other, self.app.works)
            self.assertFalse(self.stops)

    async def test_foreign_mutations_are_rejected_while_readonly_observation_is_allowed(self):
        """TEST-PC-029 / TEST-PC-030: foreign mutations are rejected while readonly observation is allowed."""
        opened = await self.debug()
        async with await self.client() as client:
            foreign = {"X-Viewrv-Work-Id": self.other}
            for route, body in (
                ("debug/step", {}),
                ("debug/breakpoint/add", {"pc": 0, "latch": "IF/ID"}),
                ("board/disconnect", {}),
            ):
                response = await client.post("/api/v1/" + route, json=body, headers=foreign)
                self.assertEqual(response.json()["error"]["code"], "BOARD_CONTROL_CONFLICT")
            show = await client.get(
                "/api/v1/session/show?session_id=" + opened["session_id"], headers=foreign
            )
            self.assertEqual(show.json()["result"]["source_text"], self.capture["source_text"])
            default = await client.get("/api/v1/session/show", headers=foreign)
            self.assertEqual(default.json()["error"]["code"], "SESSION_SELECTION_REQUIRED")

    async def test_sse_contains_only_latest_session_per_work_and_last_complete_observation(self):
        """TEST-PC-029 / TEST-PC-030: sse contains only latest session per work and last complete observation."""
        opened = await self.debug()
        subscription = self.app.subscribe(self.owner)
        initial = subscription.initial["data"]
        self.assertEqual(
            [value["session_id"] for value in initial["sessions"]], [opened["session_id"]]
        )
        self.step_reply()
        await self.sessions.step(self.owner)
        self.load_reply()
        new = await self.sessions.restart(self.owner)
        state = self.app.state()
        self.assertEqual([value["session_id"] for value in state["sessions"]], [new["session_id"]])
        self.assertIsNone(state["sessions"][0]["last_observation"])
        self.assertEqual(len(self.sessions.known), 2)
        self.app.unsubscribe(subscription)

    async def test_finishing_work_removes_its_session_from_observers_live_block(self):
        """TEST-PC-029 / TEST-PC-030: finishing work removes its session from observers live block."""
        opened = await self.debug()
        observer = self.app.register("gui", str(uuid4()))["work_id"]
        subscription = self.app.subscribe(observer)
        self.assertEqual(
            subscription.initial["data"]["sessions"][0]["session_id"], opened["session_id"]
        )
        async with await self.client() as client:
            response = await client.post("/api/v1/work/finish", json={})
            self.assertIsNone(response.json()["error"])
        messages = []
        while not subscription.pending.empty():
            messages.append(subscription.pending.get_nowait())
        updates = [
            message["data"]["sessions"] for message in messages if "sessions" in message["data"]
        ]
        self.assertEqual(updates[-1], [])
        self.app.unsubscribe(subscription)

    async def test_record_failure_is_reported_as_close_warning_without_blocking_conserved_code(
        self,
    ):
        """TEST-PC-021 / TEST-PC-026: record failure is reported as close warning without blocking conserved code."""

        def failed(unit):
            raise PermissionError("Controlled record unavailable")

        self.storage.append_record = failed
        opened = await self.debug()
        await self.sessions.known[opened["session_id"]].writer.finish()
        async with await self.client() as client:
            response = await client.post("/api/v1/work/finish", json={})
        self.assertIsNone(response.json()["error"])
        result = response.json()["result"]
        self.assertTrue(result["finished"])
        self.assertEqual(result["warnings"][0]["code"], "RECORD_WRITE_FAILED")
        self.assertNotIn(self.owner, self.app.works)
