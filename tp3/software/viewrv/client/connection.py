"""Private discovery and finite HTTP requests; never imports core composition."""

import json
import subprocess
import sys
import time
from pathlib import Path

import httpx

from software.viewrv.client.platform import runtime_directory
from software.viewrv.client.resources import load_profile
from software.viewrv.contracts import (
    API_VERSION,
    ApplicationError,
    validate_discovery,
    validate_envelope,
)

_candidates = []


class CoreClient:
    def __init__(self, discovery):
        self.discovery = validate_discovery(discovery)
        self.http = httpx.Client(
            base_url=discovery["base_url"],
            headers={"Authorization": f"Bearer {discovery['access_token']}"},
            trust_env=False,
            follow_redirects=False,
            timeout=httpx.Timeout(15, connect=3),
        )

    def close(self):
        self.http.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    def request(self, method, route, body=None, work_id=None, *, finite=True):
        headers = {"X-Viewrv-Work-Id": work_id} if work_id else {}
        try:
            response = self.http.request(
                method,
                route,
                json=body,
                headers=headers,
                timeout=httpx.Timeout(15 if finite else None, connect=3),
            )
            if 300 <= response.status_code < 400:
                raise ValueError("Redirect rejected")
            envelope = validate_envelope(response.json())
            if response.is_error:
                if envelope["error"] is None:
                    raise ValueError("Error status without error")
                error = envelope["error"]
                raise ApplicationError(
                    error["code"], error["message"], response.status_code, error.get("details")
                )
            if not response.is_success or envelope["error"] is not None:
                raise ValueError("Inconsistent response")
            return envelope["result"]
        except (httpx.HTTPError, ValueError) as error:
            raise ApplicationError(
                "REQUEST_RESULT_UNCONFIRMED",
                "No se obtuvo una respuesta completa válida; la solicitud no se repite.",
            ) from error

    def validate(self, profile):
        info = self.request("GET", "/api/v1/core/info")
        if not isinstance(info, dict):
            raise ApplicationError(
                "REQUEST_RESULT_UNCONFIRMED", "La identidad recibida no tiene el formato esperado."
            )
        if info.get("instance_id") != self.discovery["instance_id"]:
            raise ApplicationError(
                "CORE_IDENTITY_MISMATCH", "La identidad del core no coincide con el descubrimiento."
            )
        if (
            type(info.get("api_version")) is not int
            or info.get("api_version") != API_VERSION
            or info.get("processor_profile") != profile
        ):
            raise ApplicationError(
                "CORE_INCOMPATIBLE", "El contrato o el perfil del core es incompatible."
            )


def start_candidate(dev_origin=None):
    if getattr(sys, "frozen", False):
        root = Path(sys.executable).resolve().parent
        command = [
            str(
                root
                / "resources"
                / "core"
                / ("viewrv-core.exe" if sys.platform == "win32" else "viewrv-core")
            )
        ]
        cwd = root
    else:
        command = [sys.executable, "-m", "software.viewrv.core"]
        cwd = Path(__file__).resolve().parents[3]
    if dev_origin:
        command += ["--dev-origin", dev_origin]
    options = {
        "stdin": subprocess.DEVNULL,
        "stdout": subprocess.DEVNULL,
        "stderr": subprocess.DEVNULL,
        "close_fds": True,
        "cwd": cwd,
    }
    if sys.platform == "win32":
        options["creationflags"] = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        options["start_new_session"] = True
    _candidates[:] = [process for process in _candidates if process.poll() is None]
    candidate = subprocess.Popen(command, **options)
    _candidates.append(candidate)
    return candidate


def connect(*, startup_timeout=15, dev_origin=None):
    path = runtime_directory() / "core.json"
    try:
        profile = load_profile()
    except (OSError, ValueError, TypeError) as error:
        raise ApplicationError(
            "CORE_START_FAILED",
            "Los recursos locales de viewrv están ausentes o son incompatibles.",
        ) from error
    deadline = time.monotonic() + startup_timeout
    candidate = None
    last_error = None
    saw_discovery = False
    while time.monotonic() < deadline:
        try:
            discovery = validate_discovery(json.loads(path.read_text(encoding="utf-8")))
            saw_discovery = True
            client = CoreClient(discovery)
            try:
                client.validate(profile)
                return client
            except Exception:
                client.close()
                raise
        except FileNotFoundError:
            # A normal shutdown withdrew a previously observed discovery. A candidate
            # that already lost that owner's lock cannot take over retroactively.
            if saw_discovery and candidate is not None and candidate.poll() == 0:
                candidate = None
                saw_discovery = False
        except (OSError, ValueError):
            last_error = ApplicationError(
                "CORE_DISCOVERY_FAILED", "No se pudo leer el descubrimiento privado del core."
            )
        except ApplicationError as error:
            if error.code in {
                "CORE_INCOMPATIBLE",
                "CORE_IDENTITY_MISMATCH",
                "AUTHENTICATION_FAILED",
                "CORE_DISCOVERY_FAILED",
            }:
                raise
            last_error = error
        if candidate is None:
            try:
                candidate = start_candidate(dev_origin)
            except OSError as error:
                raise ApplicationError(
                    "CORE_START_FAILED", "No se pudo iniciar el proceso del core."
                ) from error
        if candidate.poll() not in (None, 0):
            raise ApplicationError(
                "CORE_START_FAILED", "El core terminó sin publicar una instancia disponible."
            )
        time.sleep(0.05)
    code = (
        "CORE_DISCOVERY_FAILED"
        if last_error and last_error.code == "CORE_DISCOVERY_FAILED"
        else "CORE_UNAVAILABLE"
    )
    raise ApplicationError(
        code, "No se obtuvo una instancia accesible dentro del plazo de arranque."
    )
