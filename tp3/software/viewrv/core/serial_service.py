"""One reserved request, one persistent serial thread and loop-owned notifications."""

import asyncio
import queue
import threading
import time
from copy import deepcopy
from uuid import uuid4

from software.viewrv.contracts import ApplicationError


class SerialService:
    def __init__(self, transport, on_notification=lambda notice: None):
        self.transport = transport
        self.on_notification = on_notification
        self.loop = asyncio.get_running_loop()
        self.mailbox = queue.Queue(maxsize=1)
        self.active = None
        self.closing = False
        self.stopped = False
        self.disconnect_task = None
        self.shutdown_result = self.loop.create_future()
        self.shutdown_result.add_done_callback(
            lambda done: None if done.cancelled() else done.exception()
        )
        self.thread = threading.Thread(target=self._worker, name="viewrv-serial", daemon=False)
        self.thread.start()

    @property
    def busy(self):
        return self.active is not None

    def submit(self, operation, parameters=None):
        if self.stopped or self.closing:
            raise ApplicationError("OPERATION_CONFLICT", "El servicio serial está cerrándose.", 409)
        if self.active is not None:
            raise ApplicationError("OPERATION_CONFLICT", "Hay una operación UART pendiente.", 409)
        future = self.loop.create_future()
        # Consume the exception also when a client has stopped waiting.
        future.add_done_callback(lambda done: None if done.cancelled() else done.exception())
        request = {
            "operation_id": str(uuid4()),
            "operation": operation,
            "parameters": deepcopy(parameters or {}),
            "control_signal": threading.Event(),
        }
        self.active = (request, future)
        self.mailbox.put_nowait(request)
        return future

    async def request(self, operation, parameters=None):
        return await asyncio.shield(self.submit(operation, parameters))

    def interrupt(self):
        if self.active:
            self.active[0]["control_signal"].set()

    async def disconnect(self):
        if self.closing or self.stopped:
            raise ApplicationError("OPERATION_CONFLICT", "El enlace está cerrándose.", 409)
        self.closing = True
        self.disconnect_task = self.loop.create_task(self._disconnect())
        self.disconnect_task.add_done_callback(
            lambda done: None if done.cancelled() else done.exception()
        )
        return await asyncio.shield(self.disconnect_task)

    async def _disconnect(self):
        try:
            if self.active:
                future = self.active[1]
                self.interrupt()
                await asyncio.gather(asyncio.shield(future), return_exceptions=True)
            # No normal request can enter between resolving the exchange and CLOSE.
            self.closing = False
            future = self.submit("CLOSE")
            self.closing = True
            return await asyncio.shield(future)
        finally:
            self.closing = False

    def _notify(self, request, kind, data):
        if kind == "completed":
            data = {**data, "result": deepcopy(data["result"])}
        notice = {
            "operation_id": request["operation_id"],
            "kind": kind,
            "data": data,
            "observed_at": time.monotonic(),
        }
        self.loop.call_soon_threadsafe(self._deliver, notice)

    def _worker(self):
        try:
            while True:
                try:
                    request = self.mailbox.get()
                except queue.ShutDown:
                    return
                try:
                    result = self.transport.execute(
                        request["operation"],
                        request["parameters"],
                        request["control_signal"],
                        lambda data: self._notify(request, "progress", data),
                    )
                except ApplicationError as error:
                    self._notify(
                        request, "failed", {"error": error, "transport": self.transport.status()}
                    )
                except Exception as error:
                    self._notify(
                        request,
                        "failed",
                        {
                            "error": ApplicationError("BOARD_RECOVERY_REQUIRED", str(error), 500),
                            "transport": self.transport.status(),
                        },
                    )
                else:
                    self._notify(
                        request,
                        "completed",
                        {"result": result, "transport": self.transport.status()},
                    )
                finally:
                    self.mailbox.task_done()
        finally:
            try:
                self.transport.close()
            except Exception as error:
                self.loop.call_soon_threadsafe(
                    self.shutdown_result.set_exception,
                    ApplicationError("BOARD_DISCONNECTION_FAILED", str(error), 500),
                )
            else:
                self.loop.call_soon_threadsafe(self.shutdown_result.set_result, None)

    def _deliver(self, notice):
        if not self.active or notice["operation_id"] != self.active[0]["operation_id"]:
            return
        future = self.active[1]
        try:
            self.on_notification(notice)
        finally:
            if notice["kind"] != "progress":
                self.active = None
                if not future.done():
                    if notice["kind"] == "failed":
                        future.set_exception(notice["data"]["error"])
                    else:
                        future.set_result(notice["data"]["result"])

    async def shutdown(self):
        if self.stopped:
            return
        if self.disconnect_task is not None:
            await asyncio.gather(asyncio.shield(self.disconnect_task), return_exceptions=True)
        self.closing = True
        if self.active:
            self.interrupt()
            await asyncio.gather(asyncio.shield(self.active[1]), return_exceptions=True)
        self.stopped = True
        self.mailbox.shutdown(immediate=False)
        while self.thread.is_alive():
            await asyncio.sleep(0.05)
        await asyncio.shield(self.shutdown_result)
