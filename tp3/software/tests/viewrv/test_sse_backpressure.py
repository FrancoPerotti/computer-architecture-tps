"""TEST-PC-029: stop the ASGI sender, not Electron's painting, to saturate one stream."""

import asyncio
import json
import unittest
from uuid import uuid4

from software.viewrv.adapters.http import create_app
from software.viewrv.core.application import Application


class SseBackpressureTests(unittest.IsolatedAsyncioTestCase):
    async def test_blocked_http_sender_closes_only_its_channel_and_resubscription_is_complete(self):
        """TEST-PC-029: backpressure blocks ASGI send and preserves other clients."""
        application = Application(str(uuid4()))
        gui = application.register("gui", str(uuid4()))["work_id"]
        cli = application.register("cli")["work_id"]
        discovery = {"base_url": "http://127.0.0.1:41987", "access_token": "test-token"}
        profile = {"profile_id": "tp3-riscv", "revision": 1, "memory_profile": "REFERENCE"}

        async def shutdown():
            self.fail("Saturating an observer shut down the application")

        app = create_app(application, discovery, profile, shutdown)
        scope = {
            "type": "http",
            "asgi": {"version": "3.0", "spec_version": "2.4"},
            "http_version": "1.1",
            "method": "GET",
            "scheme": "http",
            "path": "/api/v1/events",
            "raw_path": b"/api/v1/events",
            "query_string": b"",
            "root_path": "",
            "server": ("127.0.0.1", 41987),
            "client": ("127.0.0.1", 12345),
            "headers": [
                (b"host", b"127.0.0.1:41987"),
                (b"authorization", b"Bearer test-token"),
                (b"x-viewrv-work-id", gui.encode()),
            ],
        }
        blocked, release = asyncio.Event(), asyncio.Event()
        incoming = asyncio.Queue()
        incoming.put_nowait({"type": "http.request", "body": b"", "more_body": False})
        sent = []

        async def send(message):
            if message["type"] == "http.response.body" and message.get("body"):
                blocked.set()
                await release.wait()
            sent.append(message)

        task = asyncio.create_task(app(scope, incoming.get, send))
        fast = None
        try:
            await asyncio.wait_for(blocked.wait(), 3)
            self.assertEqual(len(application.subscriptions), 1)
            slow = next(iter(application.subscriptions))
            fast = application.subscribe(gui)
            # The actual HTTP response is held inside send(); the application
            # and another observer continue publishing and draining updates.
            for index in range(33):
                application.publish({"limitations": [{"code": f"TEST_{index}"}]})
                message = fast.pending.get_nowait()
                self.assertEqual(message["state_revision"], application.revision)
            self.assertTrue(slow.closed)
            self.assertFalse(fast.closed)
            self.assertIn(cli, application.works)
            self.assertIn(gui, application.works)
            self.assertFalse(application.shutting_down)
            release.set()
            await asyncio.wait_for(task, 3)
            self.assertEqual(sent[0]["status"], 200)
            body = b"".join(m.get("body", b"") for m in sent if m["type"] == "http.response.body")
            data = next(line[6:] for line in body.splitlines() if line.startswith(b"data: "))
            self.assertEqual(json.loads(data)["type"], "state")
            self.assertNotIn(slow, application.subscriptions)
            reopened = application.subscribe(gui)
            try:
                self.assertEqual(reopened.initial["type"], "state")
                self.assertEqual(reopened.initial["state_revision"], application.revision)
                self.assertEqual(reopened.initial["data"], application.state())
            finally:
                application.unsubscribe(reopened)
        finally:
            release.set()
            if not task.done():
                task.cancel()
            await asyncio.gather(task, return_exceptions=True)
            if fast:
                application.unsubscribe(fast)
