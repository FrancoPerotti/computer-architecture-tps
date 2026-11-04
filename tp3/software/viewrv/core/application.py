"""Single-threaded application state; independent of HTTP and device libraries."""

import asyncio
from copy import deepcopy
from dataclasses import dataclass, field
from uuid import uuid4

from software.viewrv.contracts import ApplicationError


@dataclass(eq=False)
class Subscription:
    work_id: str
    initial: dict
    pending: asyncio.Queue = field(default_factory=lambda: asyncio.Queue(maxsize=32))
    closed: bool = False

    def close(self):
        self.closed = True
        while not self.pending.empty():
            self.pending.get_nowait()
        self.pending.put_nowait(None)


class Application:
    def __init__(self, instance_id):
        self.instance_id = instance_id
        self.revision = 0
        self.shutting_down = False
        self.works = {}
        self.registrations = {}
        self.subscriptions = set()
        self.program_service = None
        self.serial_service = None
        self.board_service = None
        self.session_service = None
        self.board_owner = None
        self.board_operation = None
        self.loaded_image = {
            "status": "unknown",
            "program_id": None,
            "source_version": None,
            "byte_count": None,
        }
        self.tasks = {}
        self.finishing_works = set()
        self.board = {
            "connection_status": "closed",
            "port": None,
            "controller": None,
            "preparation_required": True,
            "recovery_pending": False,
        }
        self.preferences = {
            "schema_version": 1,
            "default_author": None,
            "record_by_default": True,
            "last_serial_port": None,
            "ui_zoom": 1.0,
            "language": "es",
        }

    def state(self):
        return deepcopy(
            {
                "board": self.board,
                "works": list(self.works.values()),
                "programs": [p.view() for p in self.program_service.programs.values()]
                if self.program_service
                else [],
                "assemblies": list(self.program_service.assemblies.values())
                if self.program_service
                else [],
                "sessions": self.session_service.live() if self.session_service else [],
                "loaded_image": self.loaded_image,
                "preferences": self.preferences,
                "limitations": self.program_service.warnings() if self.program_service else [],
            }
        )

    def message(self, kind, data):
        return {
            "instance_id": self.instance_id,
            "state_revision": self.revision,
            "type": kind,
            "data": deepcopy(data),
        }

    def publish(self, blocks):
        self.revision += 1
        message = self.message("update", blocks)
        for subscription in tuple(self.subscriptions):
            try:
                subscription.pending.put_nowait(deepcopy(message))
            except asyncio.QueueFull:
                self.unsubscribe(subscription)

    def register(self, client_type, registration_id=None):
        if self.shutting_down:
            raise ApplicationError("CORE_SHUTTING_DOWN", "El core está cerrándose.", 503)
        if client_type == "cli":
            for work in self.works.values():
                if work["client_type"] == "cli":
                    return {"work_id": work["work_id"]}
        elif registration_id in self.registrations:
            return {"work_id": self.registrations[registration_id]}
        work_id = str(uuid4())
        self.works[work_id] = {
            "work_id": work_id,
            "client_type": client_type,
            "pending_commands": [],
            "owns_board": False,
            "session_id": None,
            "debug_open": False,
        }
        if client_type == "gui":
            self.registrations[registration_id] = work_id
        self.publish({"works": list(self.works.values())})
        return {"work_id": work_id}

    def cli_status(self):
        for work in self.works.values():
            if work["client_type"] == "cli":
                return {key: deepcopy(value) for key, value in work.items() if key != "client_type"}
        return {
            "work_id": None,
            "pending_commands": [],
            "owns_board": False,
            "session_id": None,
            "debug_open": False,
        }

    def require_work(self, work_id):
        if work_id not in self.works:
            raise ApplicationError("WORK_NOT_ACTIVE", "El trabajo solicitado no está activo.", 409)
        return self.works[work_id]

    def check_board_admission(self, work_id, *, control=False):
        work = self.require_work(work_id)
        if self.board_owner not in (None, work_id):
            raise ApplicationError(
                "BOARD_CONTROL_CONFLICT", "La placa está controlada por otro trabajo.", 409
            )
        if self.board_operation and (not control or self.board_operation[2] == "board disconnect"):
            raise ApplicationError(
                "OPERATION_CONFLICT", "Hay una operación de placa pendiente.", 409
            )
        if not control and (work["debug_open"] or self.serial_service and self.serial_service.busy):
            raise ApplicationError(
                "OPERATION_CONFLICT", "La sesión actual conserva el uso de la placa.", 409
            )
        return work

    def reserve_board(self, work_id, name, *, control=False):
        work = self.check_board_admission(work_id, control=control)
        token = str(uuid4())
        self.board_owner = work_id
        self.board_operation = (token, work_id, name)
        work["owns_board"] = True
        self.board["controller"] = work["client_type"]
        self.publish({"board": self.board, "works": list(self.works.values())})
        return token

    def end_board_operation(self, token):
        if self.board_operation and self.board_operation[0] == token:
            self.board_operation = None

    def release_board(self, work_id):
        if self.board_owner == work_id and self.board_operation is None:
            self.board_owner = None
            if work_id in self.works:
                self.works[work_id]["owns_board"] = False
            self.board["controller"] = None
            self.publish({"board": self.board, "works": list(self.works.values())})

    def invalidate_image(self, status="unknown"):
        self.loaded_image = {
            "status": status,
            "program_id": None,
            "source_version": None,
            "byte_count": None,
        }
        if self.session_service:
            self.session_service.image = None
            self.session_service.position = None
        self.publish({"loaded_image": self.loaded_image})

    def finish(self, work_id, discard_unsaved=False):
        self.require_work(work_id)
        if self.board_owner == work_id:
            raise ApplicationError(
                "OPERATION_CONFLICT", "Resolvé la conexión antes de finalizar el trabajo.", 409
            )
        del self.works[work_id]
        self.registrations = {
            key: value for key, value in self.registrations.items() if value != work_id
        }
        for subscription in tuple(self.subscriptions):
            if subscription.work_id == work_id:
                self.unsubscribe(subscription)
        blocks = {"works": list(self.works.values())}
        if self.session_service:
            blocks["sessions"] = self.session_service.live()
        self.publish(blocks)
        if not self.works:
            self.shutting_down = True
        return {"work_id": work_id, "finished": True, "discarded_sources": [], "warnings": []}

    def subscribe(self, work_id):
        work = self.require_work(work_id)
        if work["client_type"] != "gui":
            raise ApplicationError("INVALID_ARGUMENT", "SSE requiere un trabajo de GUI.")
        # No await between copying the state and registering: one application-loop action.
        subscription = Subscription(work_id, self.message("state", self.state()))
        self.subscriptions.add(subscription)
        return subscription

    def unsubscribe(self, subscription):
        self.subscriptions.discard(subscription)
        subscription.close()

    async def initialize(
        self,
        storage,
        assembler,
        examples=None,
        resource_root=None,
        *,
        serial_transport=None,
        programmer=None,
        programmer_factory=None,
        port_enumerator=None,
        processor_profile=None,
    ):
        from software.viewrv.core.programs import Programs
        from software.viewrv.core.serial_service import SerialService

        self.program_service = Programs(self, storage, assembler, examples, resource_root)
        await self.program_service.initialize()
        if programmer_factory is not None and programmer is None:
            programmer = programmer_factory(self.program_service.queue)
        if serial_transport is not None:
            self.serial_service = SerialService(serial_transport, self._serial_notification)
            if programmer is not None:
                from software.viewrv.core.preparation import Preparation

                self.board_service = Preparation(self, programmer, port_enumerator)
        from software.viewrv.core.sessions import Sessions

        self.session_service = Sessions(
            self,
            processor_profile
            or {
                "profile_id": "tp3-riscv",
                "revision": 1,
                "memory_profile": getattr(serial_transport, "profile", "REFERENCE"),
            },
        )

    def _serial_notification(self, notice):
        if notice["kind"] == "progress":
            if self.session_service:
                self.session_service.serial_progress(notice["data"])
            if notice["data"].get("phase") == "load_accepted":
                self.invalidate_image("none")
            if notice["data"].get("phase") == "checking":
                self.board["connection_status"] = "checking"
                self.publish({"board": self.board})
        else:
            self.board.update(notice["data"]["transport"])
            result = notice["data"].get("result", {})
            if result.get("reset_status") == "confirmed":
                self.invalidate_image("none")
            if (
                isinstance(result.get("snapshot"), dict)
                and result["snapshot"]["image_valid"] is False
            ):
                self.invalidate_image("none")
            self.publish({"board": self.board})

    async def execute(self, work_id, command, operation):
        work = self.require_work(work_id)
        if work_id in self.finishing_works:
            raise ApplicationError(
                "OPERATION_CONFLICT", "El trabajo está resolviendo su cierre.", 409
            )
        if command == "work finish":
            self.finishing_works.add(work_id)
        work["pending_commands"].append(command)
        self.publish({"works": list(self.works.values())})

        async def run():
            try:
                return await operation()
            finally:
                current = self.works.get(work_id)
                if current and command in current["pending_commands"]:
                    current["pending_commands"].remove(command)
                    self.publish({"works": list(self.works.values())})
                if command == "work finish":
                    self.finishing_works.discard(work_id)
                self.tasks.pop(asyncio.current_task(), None)

        task = asyncio.create_task(run())
        self.tasks[task] = work_id
        # Keep ownership and consume failures even if the HTTP waiter disappears.
        task.add_done_callback(lambda done: None if done.cancelled() else done.exception())
        return await asyncio.shield(task)

    async def finish_registered(self, work_id, discard_unsaved=False):
        if self.board_service:
            await self.board_service.finish_owned(work_id)
        pending = [
            task
            for task, owner in self.tasks.items()
            if owner == work_id and task != asyncio.current_task()
        ]
        if pending:
            await asyncio.gather(
                *(asyncio.shield(task) for task in pending), return_exceptions=True
            )
        discarded = (
            await self.program_service.finish_work(work_id, discard_unsaved)
            if self.program_service
            else []
        )
        result = self.finish(work_id, discard_unsaved)
        result["discarded_sources"] = discarded
        if self.session_service:
            result["warnings"] = [
                {"code": item["code"], "message": f"{session.session_id}: {item['message']}"}
                for session in self.session_service.known.values()
                if session.owner == work_id
                for item in session.writer.limitations
            ]
        return result

    async def shutdown(self):
        if self.session_service:
            self.session_service.closing = True
        if self.serial_service:
            # A RUN owned by a pending application task has no implicit limit.
            # Request its protocol-defined stop before waiting for that task.
            self.serial_service.interrupt()
        if self.tasks:
            await asyncio.gather(
                *(asyncio.shield(task) for task in tuple(self.tasks)), return_exceptions=True
            )
        if self.session_service:
            for session in tuple(self.session_service.known.values()):
                if session.debug_open:
                    await self.session_service._close_debug(session)
            await self.session_service.shutdown()
        if self.program_service:
            await self.program_service.shutdown()
        if self.serial_service:
            await self.serial_service.shutdown()
