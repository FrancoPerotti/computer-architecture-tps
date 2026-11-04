"""Verificar el producto extraído, con CLI y core nativos independientes del host."""

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.request import ProxyHandler, Request, build_opener
from uuid import uuid4


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("product", type=Path)
    args = parser.parse_args()
    product = args.product.resolve()
    if os.name == "nt":
        raise SystemExit("Pendiente: ejecutar en una cuenta Windows de prueba aislada.")
    executable = product / "viewrv"
    manifest = json.loads((product / "release.json").read_text())
    for resource in manifest["resources"]:
        path = (product / resource["path"]).resolve()
        if not path.is_relative_to(product):
            raise AssertionError("El inventario sale de la raíz del producto")
        assert hashlib.sha256(path.read_bytes()).hexdigest() == resource["sha256"], path
    with tempfile.TemporaryDirectory(prefix="viewrv-package-") as folder:
        runtime = Path(folder)
        environment = {
            **os.environ,
            "XDG_RUNTIME_DIR": folder,
            "XDG_STATE_HOME": str(runtime / "state"),
            "XDG_DATA_HOME": str(runtime / "data"),
            "XDG_CONFIG_HOME": str(runtime / "config"),
            "HTTP_PROXY": "http://127.0.0.1:1",
            "ALL_PROXY": "http://127.0.0.1:1",
        }

        def cli(*args, expected=0):
            result = subprocess.run(
                [str(executable), *args],
                cwd=folder,
                env=environment,
                capture_output=True,
                text=True,
                timeout=20,
            )
            assert result.returncode == expected, (result.stdout, result.stderr)
            return result.stdout

        assert manifest["app_version"] in cli("--version")
        assert not (runtime / "viewrv/core.json").exists()
        status = json.loads(cli("--output", "json", "work", "status"))["result"]
        assert status["work_id"] is None
        discovery_file = runtime / "viewrv/core.json"
        deadline = time.monotonic() + 5
        while discovery_file.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        assert not discovery_file.exists(), "La consulta inicial dejó el core abierto sin uso"
        # Wait for the previous owner to release its stable lock after removing discovery.
        import fcntl

        with (runtime / "state/viewrv/core.lock").open("rb") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            fcntl.flock(lock, fcntl.LOCK_UN)
        core = subprocess.Popen(
            [str(product / "resources/core/viewrv-core")],
            env=environment,
            cwd=folder,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            deadline = time.monotonic() + 15
            while not discovery_file.exists() and time.monotonic() < deadline:
                assert core.poll() is None, "El core empaquetado terminó durante el arranque"
                time.sleep(0.05)
            discovery = json.loads(discovery_file.read_text())
            thread_names = [
                entry.read_text().strip() for entry in Path(f"/proc/{core.pid}/task").glob("*/comm")
            ]
            assert thread_names.count("viewrv-serial") == 1, thread_names
        except BaseException:
            core.terminate()
            core.wait(timeout=5)
            raise
        opener = build_opener(ProxyHandler({}))

        def action(route, body, work_id=None):
            headers = {
                "Authorization": f"Bearer {discovery['access_token']}",
                "Content-Type": "application/json",
            }
            if work_id:
                headers["X-Viewrv-Work-Id"] = work_id
            request = Request(
                discovery["base_url"] + "/api/v1/" + route, json.dumps(body).encode(), headers
            )
            with opener.open(request, timeout=15) as response:
                envelope = json.load(response)
            assert envelope["error"] is None, envelope
            return envelope["result"]

        cli_id = gui_id = None
        try:
            cli_id = action("work/register", {"client_type": "cli"})["work_id"]
            gui_id = action(
                "work/register", {"client_type": "gui", "registration_id": str(uuid4())}
            )["work_id"]
            program = action("program/create", {}, gui_id)
            capture = {
                "program_id": program["program_id"],
                "source_version": str(uuid4()),
                "source_text": "addi x1,x0,5\nhalt\n",
            }
            action("program/update", capture, gui_id)
            source = runtime / "saved program.s"
            saved = action("program/save", {**capture, "source_path": str(source)}, gui_id)
            assert saved["saved_version"] == saved["recovery_version"] == capture["source_version"]
            assert source.read_text() == capture["source_text"]
            snapshot = json.loads(
                (runtime / "data/viewrv/recovery" / f"{program['program_id']}.json").read_text()
            )
            assert snapshot["text"] == capture["source_text"] and snapshot["is_open"]
            action("preferences/update", {"default_author": "PC-I02", "ui_zoom": 1.25}, gui_id)
            # This partial product deliberately has no real assembler yet (#13/#17).
            failure = json.loads(
                cli("--output", "json", "program", "assemble", str(source), expected=1)
            )
            assert failure["result"] is None
            assert failure["error"]["code"] == "ASSEMBLY_INTERNAL_ERROR", failure
            assert failure["error"]["details"]["source_version"] == capture["source_version"]
            closed = action("program/close", capture, gui_id)
            assert not closed["is_open"]
            reopened = action("program/recover", {"program_id": program["program_id"]}, gui_id)
            assert reopened["is_open"] and reopened["source_text"] == capture["source_text"]
            assert (
                json.loads(cli("--output", "json", "work", "status"))["result"]["work_id"] == cli_id
            )
            action("work/finish", {}, gui_id)
            gui_id = None
            assert (
                json.loads(cli("--output", "json", "work", "status"))["result"]["work_id"] == cli_id
            )
            assert json.loads(cli("--output", "json", "work", "finish"))["result"]["finished"]
            cli_id = None
            deadline = time.monotonic() + 5
            while discovery_file.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            assert not discovery_file.exists(), "El core no retiró el descubrimiento al cerrar"
            assert (runtime / "state/viewrv/core.lock").exists(), (
                "Se eliminó el archivo de exclusión"
            )
            assert core.wait(timeout=5) == 0
        finally:
            for work_id in (gui_id, cli_id):
                if work_id:
                    action("work/finish", {}, work_id)
            if core.poll() is None:
                core.terminate()
                core.wait(timeout=5)
    print(
        "PC-I03 paquete: inventario, CLI/core nativos, único hilo serial, programas, conservación, assembler ausente explícito, continuidad y cierre correctos."
    )


if __name__ == "__main__":
    main()
