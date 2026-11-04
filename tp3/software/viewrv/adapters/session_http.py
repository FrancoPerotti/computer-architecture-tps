"""HTTP adapter for shared processor sessions and finite evidence queries."""

from fastapi import BackgroundTasks, Request
from fastapi.responses import JSONResponse

from software.viewrv.adapters.program_http import AssemblySource, Empty
from software.viewrv.contracts import ApplicationError, success


class Trial(Empty):
    record: bool | None = None
    author: str | None = None


class Start(Trial):
    program_id: str | None = None
    source_version: str | None = None


class RunStart(Start):
    limit_seconds: float | None = None


class Breakpoint(Empty):
    line: int | None = None
    pc: int | None = None
    latch: str


class Follow(Empty):
    selection: dict | None = None
    follow: dict | None = None


def provided(body):
    values = body.model_dump(exclude_unset=True)
    if any(value is None for value in values.values()):
        raise ApplicationError(
            "INVALID_ARGUMENT", "Omití los campos opcionales en lugar de enviar null.", 400
        )
    return values


def install_session_routes(app, application, admit, finish_query):
    def service():
        if application.session_service is None:
            raise ApplicationError(
                "REQUEST_NOT_SUPPORTED", "Las sesiones no están disponibles.", 503
            )
        return application.session_service

    def owner(request):
        admit()
        return application.require_work(request.headers.get("X-Viewrv-Work-Id"))["work_id"]

    async def action(request, name, operation):
        work = owner(request)
        return success(await application.execute(work, name, lambda: operation(work)))

    async def query(background, operation):
        admit()
        try:
            value, status = success(await operation()), 200
        except ApplicationError as error:
            value, status = error.envelope(), error.status
        finish_query(background)
        return JSONResponse(value, status_code=status, background=background)

    @app.post("/api/v1/program/load")
    async def load(body: AssemblySource, request: Request):
        values = provided(body)
        if set(values) not in ({"source_path"}, {"program_id", "source_version", "source_text"}):
            raise ApplicationError(
                "INVALID_ARGUMENT", "Proporcioná una sola forma completa de fuente.", 400
            )
        return await action(request, "program load", lambda work: service().load(work, **values))

    @app.post("/api/v1/run/start")
    async def run(body: RunStart, request: Request):
        values = provided(body)
        return await action(request, "run start", lambda work: service().run(work, **values))

    @app.post("/api/v1/run/stop")
    async def run_stop(body: Empty, request: Request):
        return await action(request, "run stop", lambda work: service().run_stop(work))

    @app.post("/api/v1/debug/start")
    async def debug_start(body: Start, request: Request):
        values = provided(body)
        return await action(
            request, "debug start", lambda work: service().debug_start(work, **values)
        )

    @app.post("/api/v1/debug/step")
    async def step(body: Empty, request: Request):
        return await action(request, "debug step", lambda work: service().step(work))

    @app.post("/api/v1/debug/continue")
    async def continuing(body: Empty, request: Request):
        return await action(
            request, "debug continue", lambda work: service().step(work, continuing=True)
        )

    @app.post("/api/v1/debug/pause")
    async def pause(body: Empty, request: Request):
        return await action(request, "debug pause", lambda work: service().debug_control(work))

    @app.post("/api/v1/debug/stop")
    async def stop(body: Empty, request: Request):
        return await action(
            request, "debug stop", lambda work: service().debug_control(work, stop=True)
        )

    @app.post("/api/v1/debug/restart")
    async def restart(body: Trial, request: Request):
        values = provided(body)
        return await action(
            request, "debug restart", lambda work: service().restart(work, **values)
        )

    @app.post("/api/v1/debug/breakpoint/add")
    async def add(body: Breakpoint, request: Request):
        values = provided(body)

        async def operation(work):
            return service().breakpoints(work, "add", **values)

        return await action(request, "debug breakpoint add", operation)

    @app.post("/api/v1/interpretation/follow")
    async def follow(body: Follow, request: Request):
        owner(request)  # Authenticate an existing observer; do not reserve the board.
        return success(service().follow(**provided(body)))

    @app.post("/api/v1/debug/breakpoint/remove")
    async def remove(body: Breakpoint, request: Request):
        values = provided(body)

        async def operation(work):
            return service().breakpoints(work, "remove", **values)

        return await action(request, "debug breakpoint remove", operation)

    @app.get("/api/v1/debug/breakpoint/list")
    async def breakpoints(request: Request):
        return success(service().breakpoints(owner(request)))

    @app.get("/api/v1/session/list")
    async def sessions(background: BackgroundTasks):
        return await query(background, lambda: service().list())

    @app.get("/api/v1/session/show")
    async def show(request: Request, background: BackgroundTasks, session_id: str | None = None):
        return await query(
            background, lambda: service().show(request.headers.get("X-Viewrv-Work-Id"), session_id)
        )

    @app.get("/api/v1/session/steps")
    async def steps(
        request: Request,
        background: BackgroundTasks,
        session_id: str | None = None,
        after: str = "0",
    ):
        async def operation():
            if not after.isascii() or not after.isdecimal():
                raise ApplicationError(
                    "INVALID_ARGUMENT", "after debe ser un entero no negativo.", 400
                )
            return await service().steps(
                request.headers.get("X-Viewrv-Work-Id"), session_id, int(after)
            )

        return await query(background, operation)

    @app.get("/api/v1/session/logs")
    async def logs(request: Request, background: BackgroundTasks, session_id: str | None = None):
        return await query(
            background, lambda: service().logs(request.headers.get("X-Viewrv-Work-Id"), session_id)
        )
