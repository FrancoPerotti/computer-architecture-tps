"""Shared preparation/connection HTTP endpoints; no ownership granted by a query."""

from fastapi import BackgroundTasks, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from software.viewrv.contracts import ApplicationError, success


class Empty(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class Connect(Empty):
    port: str | None = Field(default=None, min_length=1)


class Prepare(Connect):
    device_id: str | None = Field(default=None, min_length=1)


def install_board_routes(app, application, admit, finish_query):
    def service():
        if application.board_service is None:
            raise ApplicationError(
                "REQUEST_NOT_SUPPORTED", "La preparación de placa no está disponible.", 503
            )
        return application.board_service

    async def query(method, background):
        admit()
        try:
            envelope, status = success(await method()), 200
        except ApplicationError as error:
            envelope, status = error.envelope(), error.status
        finish_query(background)
        return JSONResponse(envelope, status_code=status, background=background)

    @app.get("/api/v1/board/devices")
    async def devices(background: BackgroundTasks):
        return await query(lambda: service().devices(), background)

    @app.get("/api/v1/board/ports")
    async def ports(background: BackgroundTasks):
        return await query(lambda: service().ports(), background)

    async def action(request, name, operation):
        admit()
        owner = application.require_work(request.headers.get("X-Viewrv-Work-Id"))["work_id"]
        return success(await application.execute(owner, name, lambda: operation(owner)))

    @app.post("/api/v1/board/prepare")
    async def prepare(body: Prepare, request: Request):
        return await action(
            request, "board prepare", lambda owner: service().prepare(owner, **body.model_dump())
        )

    @app.post("/api/v1/board/connect")
    async def connect(body: Connect, request: Request):
        return await action(
            request, "board connect", lambda owner: service().connect(owner, body.port)
        )

    @app.post("/api/v1/board/disconnect")
    async def disconnect(body: Empty, request: Request):
        return await action(request, "board disconnect", lambda owner: service().disconnect(owner))
