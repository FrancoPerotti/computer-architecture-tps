"""Program identities, source revisions and conservation on the application loop."""

import asyncio
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from dataclasses import dataclass, field
from pathlib import Path
from uuid import uuid4

from software.viewrv.contracts import ApplicationError, is_uuid
from software.viewrv.core.preferences import validate_preferences
from software.viewrv.core.storage import StorageQueue


def invalid(message):
    return ApplicationError("INVALID_ARGUMENT", message, 400)


@dataclass
class Program:
    program_id: str
    source_version: str
    source_text: str
    source_path: str | None = None
    example_id: str | None = None
    is_open: bool = True
    edit_protected: bool = False
    saved_version: str | None = None
    recovery_version: str | None = None
    versions: dict = field(default_factory=dict)
    owners: set = field(default_factory=set)
    revision_owner: str | None = None
    recovery_stamp: tuple | None = None
    auto: object = None
    wake: object = None
    operations: dict = field(default_factory=dict)
    closing: bool = False

    def __post_init__(self):
        self.versions[self.source_version] = self.source_text

    def view(self):
        return {
            name: deepcopy(getattr(self, name))
            for name in (
                "program_id",
                "source_version",
                "source_text",
                "source_path",
                "example_id",
                "is_open",
                "edit_protected",
                "saved_version",
                "recovery_version",
            )
        }

    def snapshot(self, is_open=None):
        return {
            "schema_version": 1,
            "program_id": self.program_id,
            "source_version": self.source_version,
            "text": self.source_text,
            "source_path": self.source_path,
            "example_id": self.example_id,
            "is_open": self.is_open if is_open is None else is_open,
        }

    def stamp(self, snapshot=None):
        value = snapshot or self.snapshot()
        return (
            value["source_version"],
            value["source_path"],
            value["is_open"],
            value["example_id"],
        )


class Programs:
    def __init__(self, application, storage, assembler, examples=None, resource_root=None):
        self.application = application
        self.storage = storage
        self.assembler = assembler
        self.queue = StorageQueue()
        self.programs = {}
        self.assemblies = {}
        self.limitations = []
        self.failures = {}
        self.examples = examples or {}
        self.resource_root = resource_root
        self.assembly_worker = None
        self.preferences_busy = False
        self.stopping = False

    def notify(self, *blocks):
        state = self.application.state()
        self.application.publish({name: state[name] for name in blocks})

    def warnings(self):
        return self.limitations + [
            {
                "code": "CODE_SAVE_FAILED",
                "section": "programs",
                "message": f"{failure['program_id']}: {failure['message']}",
            }
            for failure in self.failures.values()
        ]

    async def initialize(self):
        preferences, pref_warnings = await self.queue.submit(
            lambda: (self.storage.read_preferences, ())
        )
        self.application.preferences = preferences
        snapshots, warnings = await self.queue.submit(lambda: (self.storage.read_recoveries, ()))
        self.limitations = pref_warnings + warnings
        for snapshot in snapshots:
            p = Program(
                snapshot["program_id"],
                snapshot["source_version"],
                snapshot["text"],
                snapshot["source_path"],
                snapshot["example_id"],
                snapshot["is_open"],
            )
            p.recovery_version = p.source_version
            p.recovery_stamp = p.stamp()
            if p.source_path:
                try:
                    _, text = await self.queue.submit(
                        lambda p=p: (self.storage.read_source, (p.source_path,)),
                        keys=(p.source_path,),
                    )
                    if text == p.source_text:
                        p.saved_version = p.source_version
                except ApplicationError as error:
                    self.limitations.append(
                        {
                            "code": error.code,
                            "section": "programs",
                            "message": f"{p.source_path}: {error.message}",
                        }
                    )
            self.programs[p.program_id] = p

    def get(self, program_id):
        if not is_uuid(program_id):
            raise invalid("La identidad del programa debe ser un UUID válido.")
        if program_id not in self.programs:
            raise ApplicationError("PROGRAM_NOT_FOUND", "No se encuentra el programa.", 404)
        return self.programs[program_id]

    def use(self, p, work_id):
        p.owners.add(work_id)

    def capture(self, p, version, text):
        if not is_uuid(version) or not isinstance(text, str):
            raise invalid("La captura debe identificar revisión y texto completos.")
        if p.versions.get(version) != text:
            raise ApplicationError(
                "SOURCE_VERSION_MISMATCH",
                "El core no recibió esa revisión exacta del programa.",
                409,
            )
        return {"program_id": p.program_id, "source_version": version, "source_text": text}

    def _edit(self, p, version, text, work_id):
        if p.closing:
            raise ApplicationError(
                "OPERATION_CONFLICT", "El programa está resolviendo su cierre o descarte.", 409
            )
        if not is_uuid(version) or not isinstance(text, str):
            raise invalid("La captura debe identificar revisión y texto completos.")
        if version == p.source_version:
            if text != p.source_text:
                raise invalid("Una revisión no puede identificar dos textos distintos.")
            return
        if p.edit_protected:
            raise ApplicationError(
                "PROGRAM_PROTECTED", "El programa está protegido durante la depuración.", 409
            )
        if version in p.versions or text == p.source_text:
            raise ApplicationError(
                "SOURCE_VERSION_MISMATCH",
                "La actualización reutiliza una revisión anterior o no cambia el texto.",
                409,
            )
        p.source_version, p.source_text = version, text
        p.versions[version] = text
        p.revision_owner = work_id
        self.use(p, work_id)
        self.schedule(p)
        self.notify("programs", "assemblies")

    def schedule(self, p):
        if self.stopping or p.closing:
            return
        if p.auto is None or p.auto.done():
            p.wake = asyncio.Event()
            p.auto = asyncio.create_task(self._autosave(p))

    async def _autosave(self, p):
        try:
            await asyncio.wait_for(p.wake.wait(), timeout=1.0)
        except TimeoutError:
            pass
        while not self.stopping:
            before = p.source_version
            failures = await self._save_current(p)
            if before == p.source_version and (failures or not self._dirty(p)):
                return

    def _dirty(self, p):
        return p.recovery_stamp != p.stamp() or bool(
            p.source_path and p.saved_version != p.source_version
        )

    def _failure(self, p, version, target, path, error):
        failure = {
            "program_id": p.program_id,
            "source_version": version,
            "target": target,
            "path": str(path),
            "message": str(error),
        }
        self.failures[(p.program_id, target)] = failure
        return failure

    def _confirm(self, p, version, target, snapshot=None):
        if (
            target == "source_file"
            and snapshot is not None
            and snapshot["source_path"] != p.source_path
        ):
            return
        old = p.recovery_version if target == "recovery" else p.saved_version
        order = list(p.versions)
        if target == "source_file":
            # An explicit captured save may finish after a later autosave. The
            # acknowledgement must describe the bytes actually written, so the
            # current revision remains dirty until its own next write completes.
            p.saved_version = version
        elif old is None or order.index(version) >= order.index(old):
            p.recovery_version = version
            p.recovery_stamp = p.stamp(snapshot)
        failure = self.failures.get((p.program_id, target))
        if failure and order.index(version) >= order.index(failure["source_version"]):
            self.failures.pop((p.program_id, target), None)

    async def _save_current(self, p):
        jobs = []
        if p.recovery_stamp != p.stamp():
            captured = {}

            def prepare_recovery(captured=captured):
                captured.update(p.snapshot())
                return self.storage.write_recovery, (deepcopy(captured),)

            jobs.append(
                (
                    "recovery",
                    captured,
                    self.queue.submit(
                        prepare_recovery, priority=0, keys=(f"recovery:{p.program_id}",)
                    ),
                )
            )
        if p.source_path and p.saved_version != p.source_version:
            captured = {}

            def prepare_source(captured=captured):
                captured.update(p.snapshot())
                return self.storage.write_source, (captured["source_path"], captured["text"], False)

            jobs.append(
                (
                    "source_file",
                    captured,
                    self.queue.submit(
                        prepare_source,
                        priority=0,
                        keys=(f"source:{p.program_id}", p.source_path),
                    ),
                )
            )
        failures = []
        for target, captured, future in jobs:
            try:
                await asyncio.shield(future)
                self._confirm(p, captured["source_version"], target, captured)
            except Exception as error:
                path = (
                    self.storage.recovery / f"{p.program_id}.json"
                    if target == "recovery"
                    else captured.get("source_path", p.source_path)
                )
                failures.append(
                    self._failure(
                        p, captured.get("source_version", p.source_version), target, path, error
                    )
                )
            self.notify("programs", "limitations")
        return failures

    async def flush(self, p):
        if p.auto and not p.auto.done():
            p.wake.set()
            await asyncio.shield(p.auto)
        return await self._save_current(p)

    def list(self, work_id):
        for p in self.programs.values():
            if p.is_open:
                self.use(p, work_id)
        return {
            "programs": [p.view() for p in self.programs.values()],
            "limitations": self.warnings(),
        }

    def create(self, work_id, text="", example_id=None):
        p = Program(str(uuid4()), str(uuid4()), text, example_id=example_id)
        p.revision_owner = work_id
        self.use(p, work_id)
        self.programs[p.program_id] = p
        self.schedule(p)
        self.notify("programs")
        return p.view()

    def open_example(self, work_id, example_id):
        if example_id not in self.examples:
            raise invalid("No se encuentra el ejemplo seleccionado.")
        return self.create(work_id, self.examples[example_id]["source_text"], example_id)

    async def _normalize(self, path):
        if not isinstance(path, str) or not Path(path).is_absolute():
            raise invalid("La ruta del archivo debe ser absoluta.")
        try:
            return await self.queue.submit(
                lambda: (lambda value: str(Path(value).resolve()), (path,))
            )
        except (OSError, ValueError) as error:
            raise invalid("La ruta del archivo no es válida.") from error

    async def open(self, work_id, path):
        path = await self._normalize(path)
        existing = next((p for p in self.programs.values() if p.source_path == path), None)
        if existing and existing.is_open:
            self.use(existing, work_id)
            return existing.view()
        path, text = await self.queue.submit(
            lambda: (self.storage.read_source, (path,)), keys=(path,)
        )
        existing = next((p for p in self.programs.values() if p.source_path == path), None)
        if existing and existing.is_open:
            self.use(existing, work_id)
            return existing.view()
        if existing:
            p = existing
            if p.source_text != text:
                self._edit(p, str(uuid4()), text, work_id)
            p.is_open = True
        else:
            p = Program(str(uuid4()), str(uuid4()), text, path)
            self.programs[p.program_id] = p
        p.saved_version = p.source_version
        p.revision_owner = work_id
        self.use(p, work_id)
        self.schedule(p)
        self.notify("programs")
        return p.view()

    def update(self, work_id, program_id, source_version, source_text):
        p = self.get(program_id)
        self._edit(p, source_version, source_text, work_id)
        self.use(p, work_id)
        return p.view()

    async def save(self, work_id, program_id, source_version, source_text, source_path=None):
        p = self.get(program_id)
        self.capture(p, source_version, source_text)
        self.use(p, work_id)
        if p.closing or "save" in p.operations:
            raise ApplicationError(
                "OPERATION_CONFLICT", "Ya hay un guardado o cierre en curso.", 409
            )
        p.operations["save"] = asyncio.current_task()
        try:
            path = await self._normalize(source_path) if source_path is not None else p.source_path
            if path is None:
                raise invalid("El borrador necesita un destino para Guardar como.")
            if self.resource_root and Path(path).is_relative_to(self.resource_root):
                raise invalid("Los recursos originales de la aplicación no se sobrescriben.")
            if any(
                other.program_id != program_id and other.source_path == path
                for other in self.programs.values()
            ):
                raise ApplicationError(
                    "OPERATION_CONFLICT", "El destino está asociado a otro programa.", 409
                )
            # An explicit save keeps its captured source; later edits remain independent.
            try:
                await asyncio.shield(
                    self.queue.submit(
                        lambda: (
                            self.storage.write_source,
                            (path, source_text, source_path is not None),
                        ),
                        priority=0,
                        keys=(f"source:{p.program_id}", path),
                    )
                )
            except Exception as error:
                failure = self._failure(p, source_version, "source_file", path, error)
                self.notify("limitations")
                raise ApplicationError(
                    "CODE_SAVE_FAILED",
                    "No se pudo guardar el archivo Assembly.",
                    500,
                    {"failures": [failure]},
                ) from error
            if p.source_path != path:
                p.saved_version = None
            p.source_path = path
            self._confirm(p, source_version, "source_file")
            self.notify("programs", "limitations")
            # The recovery copy always keeps current text and current association.
            failures = await self.flush(p)
            if failures:
                raise ApplicationError(
                    "CODE_SAVE_FAILED",
                    "No se pudo completar la conservación del código.",
                    500,
                    {"failures": failures},
                )
            return p.view()
        finally:
            p.operations.pop("save", None)

    async def close(self, work_id, program_id, source_version, source_text):
        p = self.get(program_id)
        self.capture(p, source_version, source_text)
        if p.source_version != source_version:
            raise ApplicationError(
                "SOURCE_VERSION_MISMATCH", "El cierre requiere la última revisión recibida.", 409
            )
        if p.closing:
            raise ApplicationError("OPERATION_CONFLICT", "El programa ya está cerrándose.", 409)
        p.closing = True
        try:
            if p.operations:
                await asyncio.gather(
                    *(asyncio.shield(task) for task in tuple(p.operations.values())),
                    return_exceptions=True,
                )
            failures = await self.flush(p)
            if failures:
                raise ApplicationError(
                    "CODE_SAVE_FAILED",
                    "El programa permanece abierto porque no pudo conservarse.",
                    500,
                    {"failures": failures},
                )
            snapshot = p.snapshot(is_open=False)
            try:
                await asyncio.shield(
                    self.queue.submit(
                        lambda: (self.storage.write_recovery, (snapshot,)),
                        priority=0,
                        keys=(f"recovery:{p.program_id}",),
                    )
                )
            except Exception as error:
                failure = self._failure(
                    p,
                    p.source_version,
                    "recovery",
                    self.storage.recovery / f"{p.program_id}.json",
                    error,
                )
                self.notify("limitations")
                raise ApplicationError(
                    "CODE_SAVE_FAILED",
                    "El programa permanece abierto porque no pudo conservarse.",
                    500,
                    {"failures": [failure]},
                ) from error
            p.is_open = False
            self._confirm(p, p.source_version, "recovery", snapshot)
            self.notify("programs", "limitations")
            return p.view()
        finally:
            p.closing = False

    async def recover(self, work_id, program_id):
        p = self.get(program_id)
        if p.closing:
            raise ApplicationError(
                "OPERATION_CONFLICT", "El programa está resolviendo su cierre.", 409
            )
        p.is_open = True
        self.use(p, work_id)
        self.schedule(p)
        self.notify("programs")
        return p.view()

    async def discard(self, work_id, program_id):
        p = self.get(program_id)
        if p.edit_protected:
            raise ApplicationError(
                "PROGRAM_PROTECTED", "Terminá la depuración antes de descartar su programa.", 409
            )
        if p.closing:
            raise ApplicationError("OPERATION_CONFLICT", "El programa ya está cerrándose.", 409)
        p.closing = True
        try:
            if p.operations:
                await asyncio.gather(
                    *(asyncio.shield(task) for task in tuple(p.operations.values())),
                    return_exceptions=True,
                )
            if p.auto and not p.auto.done():
                p.wake.set()
                await asyncio.shield(p.auto)
            try:
                await asyncio.shield(
                    self.queue.submit(
                        lambda: (self.storage.delete_recovery, (program_id,)),
                        priority=0,
                        keys=(f"recovery:{p.program_id}",),
                    )
                )
            except Exception as error:
                p.recovery_version = None
                p.recovery_stamp = None
                raise ApplicationError(
                    "RECOVERY_DELETE_FAILED",
                    str(error),
                    500,
                    {
                        "program_id": program_id,
                        "path": str(self.storage.recovery / f"{program_id}.json"),
                    },
                ) from error
            del self.programs[program_id]
            self.assemblies = {
                key: value for key, value in self.assemblies.items() if key[0] != program_id
            }
            self.failures = {
                key: value for key, value in self.failures.items() if key[0] != program_id
            }
            self.notify("programs", "assemblies", "limitations")
            return {"program_id": program_id, "discarded": True}
        finally:
            p.closing = False

    async def preferences_update(self, work_id, updates):
        if self.preferences_busy:
            raise ApplicationError(
                "OPERATION_CONFLICT", "Ya hay una actualización de preferencias en curso.", 409
            )
        if (
            not isinstance(updates, dict)
            or "schema_version" in updates
            or not set(updates) <= set(self.application.preferences)
        ):
            raise invalid("La actualización de preferencias tiene campos no admitidos.")
        value = {**self.application.preferences, **updates}
        if not validate_preferences(value):
            raise invalid("Las preferencias tienen valores no admitidos.")
        self.preferences_busy = True
        try:
            try:
                await asyncio.shield(
                    self.queue.submit(
                        lambda: (self.storage.write_preferences, (value,)), keys=("preferences",)
                    )
                )
            except Exception as error:
                raise ApplicationError(
                    "PREFERENCES_WRITE_FAILED",
                    str(error),
                    500,
                    {"path": str(self.storage.preferences)},
                ) from error
            self.application.preferences = value
            self.limitations = [
                warning for warning in self.limitations if warning["section"] != "preferences"
            ]
            self.notify("preferences", "limitations")
            return self.preferences_status()
        finally:
            self.preferences_busy = False

    def preferences_status(self):
        return {
            "preferences": deepcopy(self.application.preferences),
            "limitations": [
                warning for warning in self.limitations if warning["section"] == "preferences"
            ],
        }

    async def source_capture(
        self, work_id, source_path=None, program_id=None, source_version=None, source_text=None
    ):
        if (
            source_path is not None
            and any(value is not None for value in (program_id, source_version, source_text))
            or source_path is None
            and any(value is None for value in (program_id, source_version, source_text))
        ):
            raise invalid("Proporcioná una sola forma completa de fuente.")
        if source_path is not None:
            path = await self._normalize(source_path)
            path, text = await self.queue.submit(
                lambda: (self.storage.read_source, (path,)), keys=(path,)
            )
            p = next((p for p in self.programs.values() if p.source_path == path), None)
            if p is None:
                p = Program(str(uuid4()), str(uuid4()), text, path, is_open=False)
                p.saved_version = p.source_version
                self.programs[p.program_id] = p
                self.schedule(p)
            if not p.is_open and text != p.source_text:
                self._edit(p, str(uuid4()), text, work_id)
                p.saved_version = p.source_version
            version = (
                p.source_version
                if text == p.source_text
                else next((key for key, value in p.versions.items() if value == text), None)
            )
            if version is None:
                version = str(uuid4())
                p.versions[version] = text
            p.saved_version = version
            source_version, source_text = version, text
        else:
            p = self.get(program_id)
            self.capture(p, source_version, source_text)
        return p, source_version, source_text

    async def load_capture(self, work_id, **source):
        p, version, text = await self.source_capture(work_id, **source)
        self.use(p, work_id)
        if p.closing:
            raise ApplicationError(
                "OPERATION_CONFLICT", "El programa está resolviendo su cierre.", 409
            )
        if version != p.source_version:
            raise ApplicationError(
                "SOURCE_VERSION_MISMATCH", "El texto actual cambió antes de comenzar LOAD.", 409
            )
        assembly = self.assemblies.get((p.program_id, version))
        if assembly is None or assembly["status"] != "ready":
            code = (
                "SOURCE_VERSION_MISMATCH"
                if any(key[0] == p.program_id and key[1] != version for key in self.assemblies)
                else "ASSEMBLY_REQUIRED"
            )
            raise ApplicationError(code, "Ensamblá la revisión exacta antes de cargar.", 409)
        return {
            "program_id": p.program_id,
            "source_version": version,
            "source_text": text,
            "image": deepcopy(assembly["image"]),
            "pc_to_line": deepcopy(assembly["pc_to_line"]),
        }

    async def assemble(
        self, work_id, source_path=None, program_id=None, source_version=None, source_text=None
    ):
        p, source_version, source_text = await self.source_capture(
            work_id, source_path, program_id, source_version, source_text
        )
        self.use(p, work_id)
        if p.closing or "assemble" in p.operations:
            raise ApplicationError(
                "OPERATION_CONFLICT", "Ya hay un ensamblado o cierre para ese programa.", 409
            )
        p.operations["assemble"] = asyncio.current_task()
        key = (p.program_id, source_version)
        context = {"program_id": p.program_id, "source_version": source_version}
        self.assemblies = {
            old: value for old, value in self.assemblies.items() if old[0] != p.program_id
        }
        entry = {
            **context,
            "status": "assembling",
            "image": None,
            "pc_to_line": None,
            "error": None,
        }
        self.assemblies[key] = entry
        self.notify("programs", "assemblies")
        if self.assembly_worker is None:
            self.assembly_worker = ThreadPoolExecutor(
                max_workers=1, thread_name_prefix="viewrv-assembly"
            )
        try:
            try:
                result = await asyncio.get_running_loop().run_in_executor(
                    self.assembly_worker, self.assembler.assemble, source_text
                )
                image, mapping, diagnostic = result.image, result.pc_to_line, result.error
                if diagnostic is not None:
                    if (
                        image is not None
                        or mapping != {}
                        or type(diagnostic.line) is not int
                        or diagnostic.line < 1
                        or not isinstance(diagnostic.message, str)
                    ):
                        raise ValueError("Invalid assembly diagnostic")
                    raise ApplicationError(
                        "ASSEMBLY_SOURCE_ERROR",
                        diagnostic.message,
                        422,
                        {**context, "line": diagnostic.line},
                    )
                if (
                    not isinstance(image, bytes)
                    or len(image) % 4
                    or not isinstance(mapping, dict)
                    or set(mapping) != set(range(0, len(image), 4))
                    or any(
                        type(pc) is not int or type(line) is not int or line < 1
                        for pc, line in mapping.items()
                    )
                ):
                    raise ValueError("Invalid complete assembly result")
                output = {
                    **context,
                    "image": list(image),
                    "pc_to_line": [
                        {"pc": pc, "line": line} for pc, line in sorted(mapping.items())
                    ],
                }
            except ApplicationError:
                raise
            except Exception as error:
                message = (
                    "El módulo assembler todavía no está disponible."
                    if isinstance(error, ModuleNotFoundError)
                    else "El assembler no devolvió un resultado válido."
                )
                raise ApplicationError("ASSEMBLY_INTERNAL_ERROR", message, 500, context) from error
            entry.update(status="ready", image=output["image"], pc_to_line=output["pc_to_line"])
            return output
        except ApplicationError as error:
            entry.update(status="failed", error=error.envelope()["error"])
            raise
        finally:
            p.operations.pop("assemble", None)
            self.notify("assemblies")

    async def finish_work(self, work_id, discard_unsaved=False):
        failures = []
        for p in tuple(self.programs.values()):
            if work_id not in p.owners or p.revision_owner not in (None, work_id):
                continue
            failures.extend(await self.flush(p))
        if failures and not discard_unsaved:
            raise ApplicationError(
                "CODE_SAVE_FAILED",
                "Queda código sin conservar; el trabajo permanece abierto.",
                500,
                {"failures": failures},
            )
        # A finished interface no longer owns the in-memory revision. A later
        # interface recovering the same program must resolve its own pending
        # conservation, even when it has not changed the source text yet.
        for p in self.programs.values():
            p.owners.discard(work_id)
            if p.revision_owner == work_id:
                p.revision_owner = None
        return (
            [
                {"program_id": program_id, "source_version": version}
                for program_id, version in dict.fromkeys(
                    (failure["program_id"], failure["source_version"]) for failure in failures
                )
            ]
            if discard_unsaved
            else []
        )

    async def shutdown(self):
        for p in tuple(self.programs.values()):
            if p.auto and not p.auto.done():
                p.wake.set()
                await asyncio.shield(p.auto)
        self.stopping = True
        await self.queue.close()
        if self.assembly_worker:
            self.assembly_worker.shutdown(wait=True)
