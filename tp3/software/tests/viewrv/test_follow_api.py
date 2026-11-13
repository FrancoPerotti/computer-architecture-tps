"""PC-I07: observers calculate continuity without mutating the controlled session."""

from copy import deepcopy
from uuid import uuid4

from software.tests.viewrv import pipeline_vectors as v
from software.tests.viewrv import session_api_cases
from software.tests.viewrv.session_cases import SessionFixture


class FollowApiTests(SessionFixture):
    """FollowApiTests."""

    async def client(self):
        """Client."""
        return await session_api_cases.SessionApiTests.client(self)

    async def test_foreign_observer_follows_without_uart_revision_or_sse(self):
        """TEST-PC-018: foreign observer follows without uart revision or sse."""
        opened = await self.debug()
        live = self.sessions.known[opened["session_id"]]
        before = v.put(v.snapshot(1, 4), "if_id", 0, v.ADDI)
        after = v.put(v.put(v.snapshot(2, 8), "if_id", 4, v.HALT), "id_ex", 0, v.ADDI)
        live.last = {"step_index": 1, "snapshot": before}
        observer = self.app.register("gui", str(uuid4()))["work_id"]
        async with await self.client() as client:
            client.headers["X-Viewrv-Work-Id"] = observer
            selection = {"session_id": opened["session_id"], "step_index": 1, "latch": "IF/ID"}
            captured = deepcopy(self.app.state())
            revision, writes = self.app.revision, len(self.port.writes)
            start = await client.post(
                "/api/v1/interpretation/follow", json={"selection": selection}
            )
            self.assertEqual(start.status_code, 200)
            state = start.json()["result"]
            self.assertEqual((state["status"], state["last_latch"]), ("following", "IF/ID"))
            same = await client.post("/api/v1/interpretation/follow", json={"follow": state})
            self.assertEqual(same.json()["result"], state)
            self.assertEqual(self.app.state(), captured)
            self.assertEqual((self.app.revision, len(self.port.writes)), (revision, writes))
            live.previous_observation, live.last = live.last, {"step_index": 2, "snapshot": after}
            advanced = await client.post("/api/v1/interpretation/follow", json={"follow": state})
            self.assertEqual(advanced.json()["result"]["last_latch"], "ID/EX")
            self.assertEqual((self.app.revision, len(self.port.writes)), (revision, writes))
            self.assertEqual(live.last["snapshot"], after)
            self.assertFalse(self.app.works[observer]["owns_board"])

    async def test_shape_context_current_step_and_registered_work_are_required(self):
        """TEST-PC-018: shape context current step and registered work are required."""
        opened = await self.debug()
        live = self.sessions.known[opened["session_id"]]
        before = v.put(v.snapshot(1, 4), "if_id", 0, v.ADDI)
        live.last = {"step_index": 1, "snapshot": before}
        selection = {"session_id": opened["session_id"], "step_index": 1, "latch": "IF/ID"}
        async with await self.client() as client:
            for body in [
                {},
                {"selection": None},
                {"selection": selection, "follow": {}},
                {"selection": {**selection, "step_index": 0}},
                {"selection": {**selection, "latch": []}},
                {"selection": {**selection, "extra": 1}},
            ]:
                with self.subTest(body=body):
                    result = await client.post("/api/v1/interpretation/follow", json=body)
                    self.assertEqual(result.status_code, 400)
                    self.assertEqual(result.json()["error"]["code"], "INVALID_ARGUMENT")
            missing = await client.post(
                "/api/v1/interpretation/follow",
                json={"selection": {**selection, "session_id": str(uuid4())}},
            )
            self.assertEqual(missing.status_code, 404)
            self.assertEqual(missing.json()["error"]["code"], "SESSION_NOT_FOUND")
            live.start["mode"] = "run"
            run = await client.post("/api/v1/interpretation/follow", json={"selection": selection})
            self.assertEqual(run.json()["error"]["code"], "SESSION_MODE_MISMATCH")
            client.headers["X-Viewrv-Work-Id"] = str(uuid4())
            unregistered = await client.post(
                "/api/v1/interpretation/follow", json={"selection": selection}
            )
            self.assertNotEqual(unregistered.status_code, 200)
