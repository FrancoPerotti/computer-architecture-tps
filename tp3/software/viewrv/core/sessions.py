"""Shared LOAD, RUN, debug and evidence; all logical state belongs to this loop."""

import asyncio
import math
from copy import deepcopy
from dataclasses import dataclass, field
from datetime import datetime, timezone
from uuid import uuid4

from software.viewrv.contracts import ApplicationError, is_uuid
from software.viewrv.core.evidence import RecordWriter
from software.viewrv.core.follow import advance_follow, start_follow
from software.viewrv.core.observations import interpret_step
from software.viewrv.core.records import LATCH_NAMES, warning


def now():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def fail(code, message, status=409, details=None):
    return ApplicationError(code, message, status, details)


@dataclass
class Session:
    session_id: str
    owner: str
    start: dict
    image: dict
    writer: object
    execution_status: str = "ongoing"
    debug_open: bool = False
    last: dict | None = None
    outcome: dict | None = None
    breakpoints: list = field(default_factory=list)
    count: int = 0
    previous_observation: dict | None = None

    def context(self):
        return {
            "session_id": self.session_id,
            "program_id": self.start["program_id"],
            "source_version": self.start["source_version"],
        }


class Sessions:
    def __init__(self, app, profile):
        self.app, self.profile = app, profile
        self.programs = app.program_service
        self.storage, self.queue = self.programs.storage, self.programs.queue
        self.known = {}
        self.definitions = {}
        self.image = None
        self.position = None
        self.active = None
        self.operation = None
        self.control_active = False
        self.pause_requested = False
        self.stop_requested = False
        self.closing = False
        self.reset_unconfirmed = False
        self.pending_run = None

    def serial_progress(self, notice):
        if notice.get("phase") == "run_accepted" and self.pending_run is not None:
            self._run_session(self.pending_run)

    def _run_session(self, pending):
        if pending["session"] is None:
            pending["session"] = self._new(
                pending["owner"],
                "run",
                pending["image"],
                pending["record"],
                pending["author"],
                started_at=pending["started_at"],
                resolved=True,
            )
        return pending["session"]

    def notify(self):
        self.app.publish({"sessions": self.live(), "works": list(self.app.works.values())})

    def live(self):
        return [
            self.view(self.known[work["session_id"]])
            for work in self.app.works.values()
            if work["session_id"] in self.known
        ]

    def view(self, session):
        writer = session.writer
        return {
            **session.context(),
            "mode": session.start["mode"],
            "started_at": session.start["started_at"],
            "execution_status": session.execution_status,
            "debug_open": session.debug_open,
            "source_text": session.start["source_text"],
            "last_observation": deepcopy(session.last),
            "outcome": deepcopy(session.outcome),
            "breakpoints": deepcopy(session.breakpoints),
            "evidence": {
                "record_status": writer.status,
                "observation_status": "available" if session.last else "none_received",
                "limitations": deepcopy(writer.limitations),
            },
        }

    def _options(self, record, author):
        if (
            record is not None
            and type(record) is not bool
            or author is not None
            and (not isinstance(author, str) or not author.strip())
        ):
            raise fail("INVALID_ARGUMENT", "Registro y autor no tienen valores admitidos.", 400)
        return (
            self.app.preferences["record_by_default"] if record is None else record,
            self.app.preferences["default_author"] if author is None else author,
        )

    def _foreign(self, owner):
        work = self.app.require_work(owner)
        if self.app.board_owner not in (None, owner):
            raise fail("BOARD_CONTROL_CONFLICT", "La placa pertenece a otro trabajo.")
        return work

    def _connected(self):
        board = self.app.board
        if board["port"] is None:
            raise fail("BOARD_NOT_CONNECTED", "Conectá UART antes de operar el procesador.")
        if board["preparation_required"]:
            raise fail("BOARD_PREPARATION_REQUIRED", "Prepará la placa antes de operar.")
        if board["recovery_pending"]:
            raise fail("BOARD_RECOVERY_REQUIRED", "Hay una recuperación pendiente.")

    def _no_conflict(self, work, debug=False):
        if (
            self.active
            or self.control_active
            or self.app.board_operation
            or (self.app.serial_service and self.app.serial_service.busy)
            or (work["debug_open"] and not debug)
        ):
            raise fail(
                "OPERATION_CONFLICT", "Hay una operación o depuración incompatible pendiente."
            )

    def _begin(self, owner, name, debug=False):
        work = self._foreign(owner)
        self._no_conflict(work, debug)
        self._connected()
        token = self.app.reserve_board(owner, name, control=debug)
        self.active, self.operation = asyncio.current_task(), name
        self.closing = False
        return token

    def _end(self, token):
        self.app.end_board_operation(token)
        self.active = self.operation = None

    def _debug(self, owner):
        work = self._foreign(owner)
        session = self.known.get(work["session_id"])
        if session is None or not session.debug_open:
            raise fail("DEBUG_NOT_ACTIVE", "No hay una depuración propia abierta.")
        return session

    def _loaded(self, owner, program_id, source_version):
        work = self._foreign(owner)
        if (
            (program_id is None) != (source_version is None)
            or program_id is not None
            and (not is_uuid(program_id) or not is_uuid(source_version))
        ):
            raise fail(
                "INVALID_ARGUMENT", "Proporcioná programa y revisión juntos, con UUID válidos.", 400
            )
        if work["client_type"] == "gui" and program_id is None:
            raise fail(
                "INVALID_ARGUMENT", "La GUI debe identificar el programa y revisión elegidos.", 400
            )
        if program_id is not None:
            self.programs.get(program_id)
        self._no_conflict(work)
        if self.image is None or self.app.loaded_image["status"] != "loaded":
            raise fail(
                "IMAGE_NOT_LOADED", "Se necesita una imagen con LOAD confirmada y fuente vinculada."
            )
        image = self.image
        if program_id is not None and (program_id, source_version) != (
            image["program_id"],
            image["source_version"],
        ):
            raise fail(
                "SOURCE_VERSION_MISMATCH", "La imagen confirmada no corresponde a esa revisión."
            )
        return deepcopy(image)

    def _new(
        self, owner, mode, image, record, author, breakpoints=None, started_at=None, resolved=False
    ):
        enabled, author = (record, author) if resolved else self._options(record, author)
        identity = str(uuid4())
        opening = {
            "mode": mode,
            "program_id": image["program_id"],
            "source_version": image["source_version"],
            "source_text": image["source_text"],
            "started_at": started_at or now(),
            "author": author,
            "processor_profile": deepcopy(self.profile),
        }
        writer = RecordWriter(identity, self.queue, self.storage, enabled, self.notify)
        if breakpoints is None:
            breakpoints = (
                self.definitions.get((image["program_id"], image["source_version"]), [])
                if mode == "debug"
                else []
            )
        session = Session(
            identity,
            owner,
            opening,
            deepcopy(image),
            writer,
            debug_open=mode == "debug",
            breakpoints=deepcopy(list(breakpoints)),
        )
        self.known[identity] = session
        work = self.app.require_work(owner)
        work["session_id"], work["debug_open"] = identity, session.debug_open
        writer.append("start", opening)
        self.notify()
        return session

    async def _finish(self, session, status, reason=None, error=None):
        if session.execution_status != "ongoing":
            return
        session.execution_status = status
        session.outcome = {
            "ended_at": now(),
            "interruption_reason": reason,
            "failure": None if error is None else {"code": error.code, "message": error.message},
        }
        session.writer.append(
            "end",
            {
                "execution_status": status,
                "outcome": session.outcome,
                "observation_count": session.count,
                "limitations": deepcopy(session.writer.limitations),
            },
        )
        self.notify()
        await session.writer.finish()

    async def _recover(self, owner):
        if self.app.board["recovery_pending"] and not self.closing and self.app.board_service:
            try:
                await self.app.board_service.recover_for_session(owner)
            except ApplicationError:
                pass  # Original operation remains unconfirmed; never replay it.

    async def _transfer(self, owner, image):
        context = {key: image[key] for key in ("program_id", "source_version")}
        context["byte_count"] = len(image["image"])
        try:
            await self.app.serial_service.request("LOAD", {"image": bytes(image["image"])})
        except ApplicationError as error:
            if error.code == "LOAD_FAILED":
                self.app.invalidate_image("none")
            elif error.code == "LOAD_RESULT_UNCONFIRMED":
                self.app.invalidate_image()
            await self._recover(owner)
            if error.code in {"LOAD_REJECTED", "LOAD_FAILED", "LOAD_RESULT_UNCONFIRMED"}:
                raise fail(error.code, error.message, error.status, context) from error
            raise
        self.image, self.position = deepcopy(image), "fresh"
        self.app.loaded_image = {"status": "loaded", **context}
        self.app.publish({"loaded_image": self.app.loaded_image})
        return context

    async def load(self, owner, **source):
        token = self._begin(owner, "program load")
        try:
            image = await self.programs.load_capture(owner, **source)
            p = self.programs.get(image["program_id"])
            if "load" in p.operations:
                raise fail("OPERATION_CONFLICT", "Ya hay una carga para ese programa.")
            p.operations["load"] = asyncio.current_task()
            try:
                if self.closing:
                    raise fail(
                        "OPERATION_CONFLICT",
                        "Se solicitó desconectar antes de comenzar el intercambio LOAD.",
                    )
                return await self._transfer(owner, image)
            finally:
                p.operations.pop("load", None)
        finally:
            self._end(token)

    async def run(
        self,
        owner,
        program_id=None,
        source_version=None,
        limit_seconds=None,
        record=None,
        author=None,
    ):
        self._options(record, author)
        if limit_seconds is not None and (
            type(limit_seconds) not in (int, float)
            or not math.isfinite(limit_seconds)
            or limit_seconds <= 0
        ):
            raise fail("INVALID_ARGUMENT", "El límite debe ser positivo y finito.", 400)
        if self._foreign(owner)["debug_open"]:
            raise fail("OPERATION_CONFLICT", "RUN no se admite durante una depuración abierta.")
        image = self._loaded(owner, program_id, source_version)
        if self.position == "abandoned":
            raise fail(
                "IMAGE_NOT_LOADED",
                "El estado abandonado necesita una nueva LOAD antes de ejecutar desde el inicio.",
            )
        token = self._begin(owner, "run start")
        enabled, author = self._options(record, author)
        pending = {
            "owner": owner,
            "image": image,
            "record": enabled,
            "author": author,
            "session": None,
            "started_at": now(),
        }
        self.pending_run = pending
        self.reset_unconfirmed = False
        try:
            try:
                result = await self.app.serial_service.request(
                    "RUN", {"max_seconds": limit_seconds}
                )
            except ApplicationError as error:
                if error.code == "RUN_REJECTED":
                    raise fail(
                        error.code,
                        error.message,
                        error.status,
                        {key: image[key] for key in ("program_id", "source_version")},
                    ) from error
                session = self._run_session(pending)
                self.reset_unconfirmed = (error.details or {}).get("reset_status") == "unconfirmed"
                if error.code != "RUN_REJECTED":
                    self.app.invalidate_image()
                await self._finish(session, "interrupted", "communication_failure", error)
                await self._recover(owner)
                context = (
                    session.context()
                    if error.code == "RUN_RESULT_UNCONFIRMED"
                    else {key: image[key] for key in ("program_id", "source_version")}
                )
                raise fail(error.code, error.message, error.status, context) from error
            session = self._run_session(pending)
            capture = result["snapshot"]
            if capture is not None:
                session.last = {"snapshot": deepcopy(capture)}
                session.count += 1
                session.writer.append("observation", session.last)
                self.position = "terminal"
                await self._finish(session, {10: "finished", 11: "fault"}[capture["global_state"]])
            else:
                self.app.invalidate_image("none")
                await self._finish(session, "interrupted", result["interruption"]["reason"])
            self.notify()
            return {
                **session.context(),
                "snapshot": deepcopy(capture),
                "interruption": result["interruption"],
            }
        finally:
            self.pending_run = None
            self._end(token)

    async def run_stop(self, owner):
        self._foreign(owner)
        execution = self.pending_run
        session = execution["session"] if execution else None
        if (
            not execution
            or execution["owner"] != owner
            or self.operation != "run start"
            or session
            and session.execution_status != "ongoing"
        ):
            raise fail("RUN_NOT_ACTIVE", "No hay un RUN propio pendiente.")
        if self.control_active:
            raise fail("OPERATION_CONFLICT", "Ya se está resolviendo un control.")
        self.control_active = True
        pending = self.active
        self.app.serial_service.interrupt()
        try:
            try:
                return await asyncio.shield(pending)
            except ApplicationError as error:
                if self.reset_unconfirmed:
                    session = execution["session"]
                    raise fail(
                        "RESET_UNCONFIRMED", "No pudo confirmarse RESET.", 500, session.context()
                    ) from error
                raise
        finally:
            self.control_active = False

    async def debug_start(
        self, owner, program_id=None, source_version=None, record=None, author=None
    ):
        self._options(record, author)
        image = self._loaded(owner, program_id, source_version)
        p = self.programs.get(image["program_id"])
        token = self._begin(owner, "debug start")
        p.edit_protected = True
        try:
            if p.source_version != image["source_version"]:
                raise fail(
                    "SOURCE_VERSION_MISMATCH",
                    "La revisión actual no coincide con la que se protegería.",
                )
            if self.position != "fresh":
                raise fail(
                    "IMAGE_NOT_LOADED", "Debug requiere una LOAD nueva sin ciclos ejecutados."
                )
            session = self._new(owner, "debug", image, record, author)
            self.programs.notify("programs")
            return {
                **session.context(),
                "breakpoints": deepcopy(session.breakpoints),
                "snapshot": None,
            }
        except Exception:
            p.edit_protected = False
            self.programs.notify("programs")
            raise
        finally:
            self._end(token)

    def _control_result(self, session, extra=()):
        reasons = list(extra)
        if session.last and session.last["snapshot"]["global_state"] in {10, 11}:
            reasons.append("terminal")
        if self.pause_requested:
            reasons.append("pause_requested")
        if session.last and session.last["breakpoint_hits"]:
            reasons.append("breakpoint")
        if not session.debug_open:
            reasons.append("session_closed")
        return {
            **session.context(),
            "stop_reasons": list(dict.fromkeys(reasons)),
            "last_step": deepcopy(session.last),
        }

    async def _step(self, session):
        try:
            result = await self.app.serial_service.request("STEP")
        except ApplicationError as error:
            if error.code == "STEP_REJECTED":
                raise fail(error.code, error.message, error.status, session.context()) from error
            self.position = "abandoned"
            self.app.invalidate_image()
            await self._finish(session, "interrupted", "communication_failure", error)
            self._unprotect(session)
            await self._recover(session.owner)
            raise fail(error.code, error.message, error.status, session.context()) from error
        capture = result["snapshot"]
        old = session.last["snapshot"] if session.last else None
        session.count += 1
        mapping = {entry["pc"]: entry["line"] for entry in session.image["pc_to_line"]}
        # Atomic evaluation on Application thread; edits admitted afterwards
        # affect the next capture and never reevaluate this one.
        hits = [
            deepcopy(bp)
            for bp in session.breakpoints
            if capture[LATCH_NAMES[bp["latch"]]]["valid"]
            and capture[LATCH_NAMES[bp["latch"]]]["pc"] == bp["pc"]
        ]
        session.previous_observation = session.last
        session.last = {
            "step_index": session.count,
            "snapshot": deepcopy(capture),
            "breakpoint_hits": hits,
            "interpretation": interpret_step(
                capture,
                old,
                session.count,
                mapping,
                session.image["image"],
                prepared=True,
                profile=self.profile,
            ),
        }
        session.writer.append("observation", session.last)
        self.position = "terminal" if capture["global_state"] in {10, 11} else "abandoned"
        if capture["global_state"] in {10, 11}:
            await self._finish(session, {10: "finished", 11: "fault"}[capture["global_state"]])
        self.notify()
        return {**session.context(), **deepcopy(session.last)}

    async def step(self, owner, continuing=False):
        session = self._debug(owner)
        if session.execution_status != "ongoing":
            raise fail(
                "OPERATION_CONFLICT",
                "La depuración ya tiene un desenlace; podés inspeccionarla, reiniciarla o detenerla.",
            )
        token = self._begin(owner, "debug continue" if continuing else "debug step", debug=True)
        self.pause_requested = self.stop_requested = False
        try:
            while True:
                result = await self._step(session)
                if not continuing:
                    return result
                if (
                    self.pause_requested
                    or self.stop_requested
                    or self.closing
                    or session.last["breakpoint_hits"]
                    or session.execution_status != "ongoing"
                ):
                    return self._control_result(
                        session, ("session_closed",) if self.stop_requested or self.closing else ()
                    )
                await asyncio.sleep(0)
        finally:
            self._end(token)

    def _unprotect(self, session):
        session.debug_open = False
        work = self.app.works.get(session.owner)
        if work and work["session_id"] == session.session_id:
            work["debug_open"] = False
        p = self.programs.programs.get(session.start["program_id"])
        if p:
            p.edit_protected = False
        self.programs.notify("programs")
        self.notify()

    async def _close_debug(self, session):
        if session.execution_status == "ongoing":
            await self._finish(session, "interrupted", "user_request")
        self._unprotect(session)

    async def debug_control(self, owner, stop=False):
        session = self._debug(owner)
        if (
            self.control_active
            or self.active
            and self.operation not in {"debug step", "debug continue"}
        ):
            raise fail("OPERATION_CONFLICT", "Hay otro control o recarga pendiente.")
        self.control_active = True
        self.stop_requested = stop
        self.pause_requested = not stop
        pending = self.active
        try:
            if pending:
                await asyncio.shield(pending)
            if stop:
                await self._close_debug(session)
            return self._control_result(
                session, ("session_closed",) if stop else ("pause_requested",)
            )
        finally:
            self.control_active = False

    async def restart(self, owner, record=None, author=None):
        old = self._debug(owner)
        self._options(record, author)
        token = self._begin(owner, "debug restart", debug=True)
        try:
            try:
                await self._transfer(owner, old.image)
            except ApplicationError as error:
                if error.code not in {"LOAD_REJECTED", "BOARD_NOT_READY"}:
                    await self._finish(old, "interrupted", "communication_failure", error)
                    self._unprotect(old)
                raise
            await self._finish(old, "interrupted", "user_request")
            if self.closing:
                self._unprotect(old)
                raise fail("OPERATION_CONFLICT", "Se solicitó desconectar durante la recarga.")
            session = self._new(owner, "debug", old.image, record, author, old.breakpoints)
            old.debug_open = False
            self.notify()
            return {
                **session.context(),
                "breakpoints": deepcopy(session.breakpoints),
                "snapshot": None,
            }
        finally:
            self._end(token)

    def breakpoints(self, owner, action="list", line=None, pc=None, latch=None):
        session = self._debug(owner)
        if action != "list":
            if (
                (line is None) == (pc is None)
                or latch not in LATCH_NAMES
                or line is not None
                and (type(line) is not int or line < 1)
                or pc is not None
                and (type(pc) is not int or not 0 <= pc < 2**32)
            ):
                raise fail(
                    "INVALID_ARGUMENT", "Elegí exactamente línea o PC y un latch válido.", 400
                )
            mapping = session.image["pc_to_line"]
            entry = (
                next(
                    (entry for entry in mapping if entry["line"] == line if line is not None), None
                )
                if line is not None
                else next((entry for entry in mapping if entry["pc"] == pc), None)
            )
            if entry is None:
                raise fail(
                    "INVALID_BREAKPOINT_LOCATION",
                    "La ubicación no corresponde a una instrucción de esa revisión.",
                    422,
                )
            bp = {**entry, "latch": latch}
            if action == "add":
                if bp in session.breakpoints:
                    raise fail("BREAKPOINT_ALREADY_EXISTS", "Ese breakpoint ya está definido.")
                session.breakpoints.append(bp)
            elif action == "remove":
                if bp not in session.breakpoints:
                    raise fail("BREAKPOINT_NOT_FOUND", "Ese breakpoint no está definido.", 404)
                session.breakpoints.remove(bp)
            else:
                raise fail("INVALID_ARGUMENT", "Acción de breakpoint desconocida.", 400)
            self.definitions[(session.start["program_id"], session.start["source_version"])] = (
                deepcopy(session.breakpoints)
            )
            self.notify()
        return {**session.context(), "breakpoints": deepcopy(session.breakpoints)}

    async def before_disconnect(self, owner):
        self._foreign(owner)
        self.closing = self.stop_requested = True
        if self.active and self.active is not asyncio.current_task():
            self.app.serial_service.interrupt()
            await asyncio.gather(asyncio.shield(self.active), return_exceptions=True)
        work = self.app.works.get(owner)
        session = self.known.get(work["session_id"]) if work else None
        if session and session.debug_open:
            await self._close_debug(session)

    async def shutdown(self):
        await asyncio.gather(*(session.writer.finish() for session in self.known.values()))

    def follow(self, *, selection=None, follow=None):
        """Calculate observer continuity without reserving or mutating the session."""
        if (selection is None) == (follow is None):
            raise fail("INVALID_ARGUMENT", "Proporcioná exactamente selection o follow.", 400)
        value = selection if selection is not None else follow
        if not isinstance(value, dict) or not is_uuid(value.get("session_id")):
            raise fail("INVALID_ARGUMENT", "Indicá una sesión mediante UUID.", 400)
        session = self.known.get(value["session_id"])
        if session is None:
            raise fail("SESSION_NOT_FOUND", "La sesión viva solicitada no está disponible.", 404)
        if session.start["mode"] != "debug":
            raise fail("SESSION_MODE_MISMATCH", "El seguimiento requiere una sesión debug.")
        return (
            start_follow(session, selection)
            if selection is not None
            else advance_follow(session, follow)
        )

    def _selection(self, owner, session_id):
        if session_id is not None:
            if not is_uuid(session_id):
                raise fail("INVALID_ARGUMENT", "La sesión debe identificarse mediante UUID.", 400)
            return session_id
        work = self.app.works.get(owner)
        if work is None or work["client_type"] != "cli" or work["session_id"] is None:
            raise fail(
                "SESSION_SELECTION_REQUIRED",
                "Indicá una sesión; el trabajo CLI actual no inició ensayos.",
            )
        return work["session_id"]

    def _historical_view(self, record):
        opening = record["start"]
        last = record["observations"][-1] if record["observations"] else None
        closing = record["end"]
        result = {
            "session_id": record["session_id"],
            "mode": opening["mode"],
            "program_id": opening["program_id"],
            "source_version": opening["source_version"],
            "started_at": opening["started_at"],
            "execution_status": record["execution_status"],
            "debug_open": False,
            "source_text": opening["source_text"],
            "last_observation": last,
            "outcome": closing["outcome"]
            if closing
            else {"ended_at": None, "interruption_reason": None, "failure": None}
            if record["execution_status"] in {"finished", "fault"}
            else None,
            "breakpoints": None,
            "evidence": {
                "record_status": record["record_status"],
                "observation_status": "available"
                if last
                else "none_received"
                if closing and closing["observation_count"] == 0
                else "unavailable",
                "limitations": deepcopy(record["limitations"]),
            },
        }
        return result

    async def _query(self, owner, session_id, *, history=False):
        identity = self._selection(owner, session_id)
        session = self.known.get(identity)
        record = None
        if session and session.writer.status == "disabled":
            view = self.view(session)
        else:
            try:
                record = await self.queue.submit(
                    lambda: (self.storage.read_record, (identity, not history)),
                    keys=(f"record:{identity}",),
                )
            except ApplicationError as error:
                if session is None:
                    raise
                view = self.view(session)
                view["evidence"]["limitations"].append(
                    warning("EVIDENCE_UNAVAILABLE", "record", error.message)
                )
                if view["evidence"]["record_status"] not in {"writing", "failed"}:
                    view["evidence"]["record_status"] = "unavailable"
            else:
                view = self.view(session) if session else self._historical_view(record)
                evidence = view["evidence"]
                if session and session.writer.status == "writing":
                    evidence["record_status"] = "writing"
                    evidence["limitations"].extend(
                        item for item in record["limitations"] if item["section"] != "outcome"
                    )
                else:
                    evidence["record_status"] = (
                        "failed"
                        if session and session.writer.status == "failed"
                        else record["record_status"]
                    )
                    evidence["limitations"].extend(record["limitations"] if session else [])
        return session, record, deepcopy(view)

    async def list(self):
        records, limitations = await self.queue.submit(lambda: (self.storage.list_records, ()))
        views = {record["session_id"]: self._historical_view(record) for record in records}
        views.update({identity: self.view(session) for identity, session in self.known.items()})
        fields = (
            "session_id",
            "mode",
            "program_id",
            "source_version",
            "started_at",
            "execution_status",
            "debug_open",
        )
        return {
            "sessions": [
                {key: view[key] for key in fields}
                for view in sorted(
                    views.values(), key=lambda item: (item["started_at"], item["session_id"])
                )
            ],
            "limitations": limitations,
        }

    async def show(self, owner=None, session_id=None):
        return (await self._query(owner, session_id))[2]

    async def steps(self, owner=None, session_id=None, after=0):
        if type(after) is not int or after < 0:
            raise fail("INVALID_ARGUMENT", "El índice after debe ser un entero no negativo.", 400)
        session, record, view = await self._query(owner, session_id, history=True)
        if view["mode"] != "debug":
            raise fail("SESSION_MODE_MISMATCH", "Los pasos se consultan en una sesión debug.")
        limitations = view["evidence"]["limitations"]
        if record is None:
            limitations.append(
                warning(
                    "EVIDENCE_UNAVAILABLE",
                    "steps",
                    "No hay capturas conservadas disponibles; no se ejecutaron pasos adicionales.",
                )
            )
        fields = ("session_id", "program_id", "source_version", "execution_status", "debug_open")
        return {
            **{key: view[key] for key in fields},
            "steps": [value for value in record["observations"] if value["step_index"] > after]
            if record
            else [],
            "record_status": view["evidence"]["record_status"],
            "limitations": limitations,
        }

    async def logs(self, owner=None, session_id=None):
        session, record, view = await self._query(owner, session_id, history=True)
        opening = record["start"] if record else session.start
        historical = self._historical_view(record) if record else None
        fields = (
            "session_id",
            "mode",
            "program_id",
            "source_version",
            "started_at",
            "source_text",
            "execution_status",
        )
        limitations = view["evidence"]["limitations"]
        if record is None:
            limitations.append(
                warning(
                    "EVIDENCE_UNAVAILABLE",
                    "observations",
                    "El registro no está disponible; la última captura en memoria no se presenta como historial conservado.",
                )
            )
        return {
            **{key: view[key] for key in fields},
            "author": opening["author"],
            "observations": record["observations"] if record else [],
            "outcome": historical["outcome"] if historical else None,
            "record_status": view["evidence"]["record_status"],
            "limitations": limitations,
        }
