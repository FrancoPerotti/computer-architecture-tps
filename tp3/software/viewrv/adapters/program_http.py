"""Editor and preference HTTP contracts for the shared program service."""

from fastapi import Request
from pydantic import BaseModel, ConfigDict

from software.viewrv.contracts import ApplicationError, success


class Empty(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class ProgramIdentity(Empty):
    program_id: str


class Capture(ProgramIdentity):
    source_version: str
    source_text: str


class Save(Capture):
    source_path: str | None = None


class SourcePath(Empty):
    source_path: str


class Example(Empty):
    example_id: str


class AssemblySource(Empty):
    source_path: str | None = None
    program_id: str | None = None
    source_version: str | None = None
    source_text: str | None = None


def install_program_routes(app, application, admit):
    def service():
        if application.program_service is None:
            raise ApplicationError(
                "REQUEST_NOT_SUPPORTED", "El servicio de programas no está disponible.", 503
            )
        return application.program_service

    def work(request, gui=False):
        admit()
        context = application.require_work(request.headers.get("X-Viewrv-Work-Id"))
        if gui and context["client_type"] != "gui":
            raise ApplicationError(
                "INVALID_ARGUMENT", "Esta operación del editor requiere un trabajo de GUI."
            )
        return context["work_id"]

    async def execute(request, name, operation, gui=True):
        work_id = work(request, gui)

        async def run():
            result = operation(work_id)
            if hasattr(result, "__await__"):
                result = await result
            return result

        return success(await application.execute(work_id, name, run))

    @app.get("/api/v1/program/list")
    async def list_programs(request: Request):
        return await execute(request, "program list", lambda owner: service().list(owner))

    @app.post("/api/v1/program/create")
    async def create_program(body: Empty, request: Request):
        return await execute(request, "program create", lambda owner: service().create(owner))

    @app.post("/api/v1/program/open")
    async def open_program(body: SourcePath, request: Request):
        return await execute(
            request, "program open", lambda owner: service().open(owner, body.source_path)
        )

    @app.post("/api/v1/program/open-example")
    async def open_example(body: Example, request: Request):
        return await execute(
            request,
            "program open-example",
            lambda owner: service().open_example(owner, body.example_id),
        )

    @app.post("/api/v1/program/update")
    async def update_program(body: Capture, request: Request):
        return await execute(
            request, "program update", lambda owner: service().update(owner, **body.model_dump())
        )

    @app.post("/api/v1/program/save")
    async def save_program(body: Save, request: Request):
        return await execute(
            request, "program save", lambda owner: service().save(owner, **body.model_dump())
        )

    @app.post("/api/v1/program/close")
    async def close_program(body: Capture, request: Request):
        return await execute(
            request, "program close", lambda owner: service().close(owner, **body.model_dump())
        )

    @app.post("/api/v1/program/recover")
    async def recover_program(body: ProgramIdentity, request: Request):
        return await execute(
            request, "program recover", lambda owner: service().recover(owner, body.program_id)
        )

    @app.post("/api/v1/program/discard")
    async def discard_program(body: ProgramIdentity, request: Request):
        return await execute(
            request, "program discard", lambda owner: service().discard(owner, body.program_id)
        )

    @app.post("/api/v1/program/assemble")
    async def assemble_program(body: AssemblySource, request: Request):
        fields = body.model_fields_set
        if fields not in ({"source_path"}, {"program_id", "source_version", "source_text"}) or any(
            value is None for value in body.model_dump(exclude_unset=True).values()
        ):
            raise ApplicationError(
                "INVALID_ARGUMENT", "Proporcioná un archivo o una captura completa del editor."
            )
        return await execute(
            request,
            "program assemble",
            lambda owner: service().assemble(owner, **body.model_dump()),
            gui=False,
        )

    @app.get("/api/v1/preferences")
    async def preferences():
        admit()
        return success(
            service().preferences_status()
            if application.program_service
            else {"preferences": application.preferences.copy(), "limitations": []}
        )

    @app.post("/api/v1/preferences/update")
    async def update_preferences(body: dict, request: Request):
        return await execute(
            request,
            "preferences update",
            lambda owner: service().preferences_update(owner, body),
            gui=False,
        )
