"""UTF-8 user files and durable per-user recovery, executed only by Storage worker."""

import json
import os
import stat
import tempfile
from pathlib import Path
from uuid import uuid4

from software.viewrv.client.platform import (
    config_directory,
    data_directory,
    private_directory,
    state_directory,
)
from software.viewrv.contracts import ApplicationError, is_uuid
from software.viewrv.core.preferences import DEFAULT_PREFERENCES, validate_preferences

RECOVERY_FIELDS = {
    "schema_version",
    "program_id",
    "source_version",
    "text",
    "source_path",
    "is_open",
    "example_id",
}


def validate_snapshot(value, name=None):
    return (
        isinstance(value, dict)
        and set(value) == RECOVERY_FIELDS
        and type(value["schema_version"]) is int
        and value["schema_version"] == 1
        and is_uuid(value["program_id"])
        and (name is None or name == value["program_id"])
        and is_uuid(value["source_version"])
        and isinstance(value["text"], str)
        and type(value["is_open"]) is bool
        and (
            value["source_path"] is None
            or isinstance(value["source_path"], str)
            and Path(value["source_path"]).is_absolute()
        )
        and (value["example_id"] is None or isinstance(value["example_id"], str))
    )


def sync_directory(path):
    if os.name != "nt":
        fd = os.open(path, os.O_DIRECTORY | os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)


def publish_file(temp, path):
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes

        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.MoveFileExW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD]
        if not kernel.MoveFileExW(str(temp), str(path), 0x1 | 0x8):
            raise ctypes.WinError(ctypes.get_last_error())
    else:
        os.replace(temp, path)
        sync_directory(path.parent)


def durable_write(path, text):
    fd, temporary = tempfile.mkstemp(prefix=".viewrv-", suffix=".tmp", dir=path.parent)
    temp = Path(temporary)
    try:
        with os.fdopen(fd, "wb") as stream:
            if path.exists():
                os.chmod(temp, stat.S_IMODE(path.stat().st_mode))
            stream.write(text.encode("utf-8") if isinstance(text, str) else text)
            stream.flush()
            os.fsync(stream.fileno())
        publish_file(temp, path)
    finally:
        temp.unlink(missing_ok=True)


class FileStorage:
    def __init__(self, data_root=None, config_root=None, state_root=None):
        self.recovery = (data_root or data_directory()) / "recovery"
        self.preferences = (config_root or config_directory()) / "preferences.json"
        self.records = (
            state_root
            or (data_root.parent / "state" if data_root is not None else state_directory())
        ) / "records"

    def append_record(self, unit):
        from software.viewrv.core.records import shape

        if (
            not shape(unit, "schema_version session_id record_type data")
            or not is_uuid(unit["session_id"])
            or unit["record_type"] not in {"start", "observation", "end"}
        ):
            raise ValueError("Invalid record unit")
        private_directory(self.records)
        path = self.records / f"{unit['session_id']}.jsonl"
        flags = os.O_WRONLY | (
            os.O_CREAT | os.O_EXCL if unit["record_type"] == "start" else os.O_APPEND
        )
        with os.fdopen(os.open(path, flags, 0o600), "wb") as stream:
            stream.write(
                (json.dumps(unit, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")
            )
            stream.flush()
            os.fsync(stream.fileno())
        if unit["record_type"] == "start":
            sync_directory(self.records)
        return str(path)

    def read_record(self, session_id, summary=False):
        from software.viewrv.core.records import parse_record

        if not is_uuid(session_id):
            raise ValueError("Invalid record identity")
        path = self.records / f"{session_id}.jsonl"
        try:
            with path.open("rb") as stream:
                return parse_record(stream, session_id, path, retain_observations=not summary)
        except FileNotFoundError as error:
            raise ApplicationError(
                "SESSION_NOT_FOUND", "No hay un registro para esa sesión.", 404
            ) from error
        except OSError as error:
            raise ApplicationError(
                "RECORD_READ_FAILED", str(error), 500, {"session_id": session_id, "path": str(path)}
            ) from error

    def list_records(self):
        from software.viewrv.core.records import warning

        try:
            paths = sorted(path for path in self.records.iterdir() if path.suffix == ".jsonl")
        except FileNotFoundError:
            return [], []
        except OSError as error:
            return [], [warning("RECORD_READ_FAILED", "sessions", str(error))]
        records, limitations = [], []
        for path in paths:
            try:
                if not is_uuid(path.stem):
                    raise ApplicationError("RECORD_INVALID", "Nombre de registro inválido.")
                records.append(self.read_record(path.stem, summary=True))
            except ApplicationError as error:
                limitations.append(warning(error.code, "sessions", f"{path}: {error.message}"))
        return records, limitations

    def read_source(self, path):
        target = Path(path).resolve()
        try:
            text = target.read_bytes().decode("utf-8")
            return str(target), text
        except FileNotFoundError as error:
            raise ApplicationError(
                "SOURCE_NOT_FOUND", "El archivo fuente no existe.", 404, {"path": str(target)}
            ) from error
        except UnicodeError as error:
            raise ApplicationError(
                "SOURCE_ENCODING_INVALID",
                "El archivo no contiene texto UTF-8 válido.",
                500,
                {"path": str(target)},
            ) from error
        except OSError as error:
            raise ApplicationError(
                "SOURCE_READ_FAILED", str(error), 500, {"path": str(target)}
            ) from error

    def write_source(self, path, text, allow_create=False):
        target = Path(path).resolve()
        if not allow_create and not target.is_file():
            raise FileNotFoundError(f"El archivo asociado no existe: {target}")
        durable_write(target, text)
        return str(target)

    def read_recoveries(self):
        snapshots, limitations = [], []
        try:
            paths = sorted(path for path in self.recovery.iterdir() if path.suffix == ".json")
        except FileNotFoundError:
            return snapshots, limitations
        except OSError as error:
            return [], [
                {"code": "RECOVERY_READ_FAILED", "section": "programs", "message": str(error)}
            ]
        for path in paths:
            try:
                value = json.loads(path.read_text(encoding="utf-8"))
                if not validate_snapshot(value, path.stem):
                    raise ValueError("Copia de recuperación inválida")
                snapshots.append(value)
            except (ValueError, UnicodeError) as error:
                limitations.append(
                    {
                        "code": "RECOVERY_INVALID",
                        "section": "programs",
                        "message": f"{path}: {error}",
                    }
                )
            except OSError as error:
                limitations.append(
                    {
                        "code": "RECOVERY_READ_FAILED",
                        "section": "programs",
                        "message": f"{path}: {error}",
                    }
                )
        return snapshots, limitations

    def write_recovery(self, snapshot):
        if not validate_snapshot(snapshot):
            raise ValueError("Invalid recovery snapshot")
        private_directory(self.recovery)
        path = self.recovery / f"{snapshot['program_id']}.json"
        durable_write(path, json.dumps(snapshot, ensure_ascii=False) + "\n")
        return str(path)

    def delete_recovery(self, program_id):
        if not is_uuid(program_id):
            raise ValueError("Invalid program identity")
        path = self.recovery / f"{program_id}.json"
        path.unlink(missing_ok=True)
        if path.parent.exists():
            sync_directory(path.parent)
        return str(path)

    def read_preferences(self):
        try:
            value = json.loads(self.preferences.read_text(encoding="utf-8"))
            if not validate_preferences(value):
                raise ValueError("Formato, versión o valor de preferencias no admitido")
            return value, []
        except FileNotFoundError:
            return DEFAULT_PREFERENCES.copy(), []
        except (ValueError, UnicodeError):
            code = "PREFERENCES_INVALID"
        except OSError:
            code = "PREFERENCES_READ_FAILED"
        return DEFAULT_PREFERENCES.copy(), [
            {
                "code": code,
                "section": "preferences",
                "message": f"No se pudieron leer las preferencias de {self.preferences}.",
            }
        ]

    def write_preferences(self, value):
        if not validate_preferences(value):
            raise ValueError("Invalid preferences")
        private_directory(self.preferences.parent)
        if self.preferences.exists():
            try:
                old = self.preferences.read_bytes()
                if not validate_preferences(json.loads(old.decode("utf-8"))):
                    raise ValueError("Invalid original")
            except (ValueError, UnicodeError):
                backup = self.preferences.with_name(f"preferences.invalid-{uuid4()}.json")
                durable_write(backup, old)
        durable_write(self.preferences, json.dumps(value, ensure_ascii=False) + "\n")
        return str(self.preferences)
