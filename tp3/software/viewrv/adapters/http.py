"""HTTP/SSE adapter, including the packaged application's admission rules."""

import hmac
from typing import Literal

from fastapi import BackgroundTasks, Depends, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.sse import EventSourceResponse
from pydantic import BaseModel, ConfigDict, model_validator
from starlette.exceptions import HTTPException

from software.viewrv import __version__
from software.viewrv.contracts import API_VERSION, GUI_ORIGIN, ApplicationError, is_uuid, success


class RegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    client_type: Literal["gui", "cli"]
    registration_id: str | None = None

    @model_validator(mode="after")
    def valid_registration(self):
        if self.client_type == "gui" and not is_uuid(self.registration_id):
            raise ValueError("GUI requires a UUID registration_id")
        if self.client_type == "cli" and self.registration_id is not None:
            raise ValueError("CLI omits registration_id")
        return self


class FinishRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    discard_unsaved: bool = False


class Admission:
    def __init__(self, app, host, token, dev_origin=None):
        self.app, self.host, self.token = app, host, token
        self.origins = {GUI_ORIGIN}
        if dev_origin:
            self.origins.add(dev_origin)

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        headers = dict(scope["headers"])
        origin = headers.get(b"origin", b"").decode("latin1")
        allowed_origin = origin in self.origins

        async def cors_send(message):
            if message["type"] == "http.response.start" and allowed_origin:
                message["headers"] = list(message["headers"]) + [
                    (b"access-control-allow-origin", origin.encode()),
                    (b"vary", b"Origin"),
                ]
            await send(message)

        async def reject(code, message, status, extra=None):
            response = JSONResponse(
                ApplicationError(code, message).envelope(), status_code=status, headers=extra
            )
            await response(scope, receive, cors_send)

        if headers.get(b"host", b"").decode("latin1") != self.host or (
            origin and not allowed_origin
        ):
            return await reject("INVALID_REQUEST", "El destino o el origen no está admitido.", 400)
        if scope["method"] == "OPTIONS":
            requested = {
                name.strip().lower()
                for name in headers.get(b"access-control-request-headers", b"")
                .decode("latin1")
                .split(",")
                if name.strip()
            }
            if (
                not allowed_origin
                or headers.get(b"access-control-request-method") not in (b"GET", b"POST")
                or not requested <= {"authorization", "content-type", "x-viewrv-work-id"}
            ):
                return await reject(
                    "INVALID_REQUEST", "La comprobación previa CORS no está admitida.", 400
                )
            response = JSONResponse(
                None,
                headers={
                    "Access-Control-Allow-Methods": "GET, POST",
                    "Access-Control-Allow-Headers": "Authorization, Content-Type, X-Viewrv-Work-Id",
                },
            )
            return await response(scope, receive, cors_send)
        authorization = headers.get(b"authorization", b"")
        if not hmac.compare_digest(authorization, f"Bearer {self.token}".encode()):
            return await reject(
                "AUTHENTICATION_FAILED",
                "Falta una credencial válida para esta instancia.",
                401,
                {"WWW-Authenticate": "Bearer"},
            )
        if (
            scope["method"] == "POST"
            and headers.get(b"content-type", b"").split(b";")[0].strip().lower()
            != b"application/json"
        ):
            return await reject("REQUEST_NOT_SUPPORTED", "Se requiere contenido JSON.", 415)
        await self.app(scope, receive, cors_send)


def create_app(application, discovery, profile, request_shutdown, lifespan=None, dev_origin=None):
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None, lifespan=lifespan)
    app.add_middleware(
        Admission,
        host=discovery["base_url"].removeprefix("http://"),
        token=discovery["access_token"],
        dev_origin=dev_origin,
    )

    @app.exception_handler(ApplicationError)
    async def application_error(request, error):
        headers = {"WWW-Authenticate": "Bearer"} if error.status == 401 else None
        return JSONResponse(error.envelope(), status_code=error.status, headers=headers)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request, error):
        return JSONResponse(
            ApplicationError(
                "INVALID_REQUEST", "La solicitud no tiene la estructura esperada."
            ).envelope(),
            status_code=400,
        )

    @app.exception_handler(HTTPException)
    async def http_error(request, error):
        return JSONResponse(
            ApplicationError(
                "REQUEST_NOT_SUPPORTED", "La ruta o el método no está admitido."
            ).envelope(),
            status_code=error.status_code,
            headers=error.headers,
        )

    @app.exception_handler(Exception)
    async def internal_error(request, error):
        headers = {}
        origin = request.headers.get("Origin")
        if origin in {GUI_ORIGIN, dev_origin} and origin:
            headers = {"Access-Control-Allow-Origin": origin, "Vary": "Origin"}
        return JSONResponse(
            ApplicationError("INTERNAL_ERROR", "No se pudo completar la solicitud.").envelope(),
            status_code=500,
            headers=headers,
        )

    def admit():
        if application.shutting_down:
            raise ApplicationError("CORE_SHUTTING_DOWN", "El core está cerrándose.", 503)

    @app.get("/api/v1/core/info")
    async def info():
        admit()
        return success(
            {
                "instance_id": application.instance_id,
                "api_version": API_VERSION,
                "core_version": __version__,
                "processor_profile": profile,
            }
        )

    def finish_query_if_unused(background):
        if not application.works:
            application.shutting_down = True
            background.add_task(request_shutdown)

    @app.get("/api/v1/board/status")
    async def board_status(background: BackgroundTasks):
        admit()
        result = success(application.board.copy())
        finish_query_if_unused(background)
        return result

    @app.get("/api/v1/work/cli/status")
    async def work_status(background: BackgroundTasks):
        admit()
        result = success(application.cli_status())
        finish_query_if_unused(background)
        return result

    @app.post("/api/v1/work/register")
    async def register(body: RegisterRequest):
        admit()
        return success(application.register(body.client_type, body.registration_id))

    @app.post("/api/v1/work/finish")
    async def finish(body: FinishRequest, request: Request, background: BackgroundTasks):
        admit()
        work_id = request.headers.get("X-Viewrv-Work-Id")
        result = await application.execute(
            work_id,
            "work finish",
            lambda: application.finish_registered(work_id, body.discard_unsaved),
        )
        if application.shutting_down:
            background.add_task(request_shutdown)
        return success(result)

    async def subscription_for(request: Request):
        admit()
        subscription = application.subscribe(request.headers.get("X-Viewrv-Work-Id"))
        try:
            yield subscription
        finally:
            application.unsubscribe(subscription)

    @app.get("/api/v1/events", response_class=EventSourceResponse)
    async def events(subscription=Depends(subscription_for)):
        yield subscription.initial
        while not subscription.closed:
            message = await subscription.pending.get()
            if message is None:
                break
            yield message

    from software.viewrv.adapters.board_http import install_board_routes
    from software.viewrv.adapters.program_http import install_program_routes
    from software.viewrv.adapters.session_http import install_session_routes

    install_program_routes(app, application, admit)
    install_board_routes(app, application, admit, finish_query_if_unused)
    install_session_routes(app, application, admit, finish_query_if_unused)
    return app
