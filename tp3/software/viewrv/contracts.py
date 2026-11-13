"""Transport values shared by clients and adapters; importing has no effects."""

import re
from uuid import UUID

API_VERSION = 1
GUI_ORIGIN = "viewrv://app"
STATE_BLOCKS = frozenset(
    (
        "board",
        "works",
        "programs",
        "assemblies",
        "loaded_image",
        "sessions",
        "preferences",
        "limitations",
    )
)


class ApplicationError(Exception):
    def __init__(self, code, message, status=400, details=None):
        super().__init__(message)
        self.code, self.message, self.status = code, message, status
        self.details = details

    def envelope(self):
        error = {"code": self.code, "message": self.message}
        if self.details is not None:
            error["details"] = self.details
        return {"result": None, "error": error}


def success(result):
    return {"result": result, "error": None}


def is_uuid(value):
    try:
        return isinstance(value, str) and str(UUID(value)) == value
    except ValueError:
        return False


def validate_discovery(value):
    if not isinstance(value, dict) or set(value) != {
        "base_url",
        "instance_id",
        "api_version",
        "access_token",
    }:
        raise ApplicationError(
            "CORE_DISCOVERY_FAILED", "El descubrimiento del core no tiene el formato esperado."
        )
    url = value["base_url"]
    if not isinstance(url, str) or not re.fullmatch(r"http://127\.0\.0\.1:[0-9]{1,5}", url):
        raise ApplicationError(
            "CORE_DISCOVERY_FAILED", "El destino del core no es una dirección local admitida."
        )
    if not 1 <= int(url.rsplit(":", 1)[1]) <= 65535 or not is_uuid(value["instance_id"]):
        raise ApplicationError(
            "CORE_DISCOVERY_FAILED", "El puerto o la identidad del core es inválido."
        )
    if type(value["api_version"]) is not int or value["api_version"] != API_VERSION:
        raise ApplicationError("CORE_INCOMPATIBLE", "La versión de API del core no es compatible.")
    if not isinstance(value["access_token"], str) or not re.fullmatch(
        r"[A-Za-z0-9_-]{32,}", value["access_token"]
    ):
        raise ApplicationError(
            "CORE_DISCOVERY_FAILED", "La credencial del descubrimiento es inválida."
        )
    return value


def validate_envelope(value):
    if not isinstance(value, dict) or set(value) != {"result", "error"}:
        raise ValueError("Invalid response envelope")
    if value["error"] is not None:
        error = value["error"]
        if (
            value["result"] is not None
            or not isinstance(error, dict)
            or not isinstance(error.get("code"), str)
            or not isinstance(error.get("message"), str)
        ):
            raise ValueError("Invalid error envelope")
    elif value["result"] is None:
        raise ValueError("Missing result")
    return value
