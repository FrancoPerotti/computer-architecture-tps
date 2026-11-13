"""Verify native CLI/core/programmer without claiming a hardware distribution."""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.request import ProxyHandler, Request, build_opener
from uuid import uuid4


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("software", type=Path, help="Directorio con build/python y resources.")
    parser.add_argument(
        "--sessions",
        action="store_true",
        help="Comprobar además CLI/core nativos con un registro histórico controlado de PC-I05.",
    )
    args = parser.parse_args()
    software = args.software.resolve()
    with tempfile.TemporaryDirectory(prefix="viewrv native preparation ") as folder:
        root = Path(folder)
        product = root / "native verification only"
        shutil.copytree(software / "build/python/viewrv", product)
        shutil.copytree(software / "build/python/viewrv-core", product / "resources/core")
        for directory in ("content", "programmer", "hardware"):
            shutil.copytree(software / "resources" / directory, product / "resources" / directory)
        assert not (product / "release.json").exists()
        assert not (product / "resources/hardware/processor.bit").exists(), (
            "Este ensayo documenta el recurso pendiente."
        )
        environment = {
            **os.environ,
            "XDG_RUNTIME_DIR": str(root),
            "XDG_STATE_HOME": str(root / "state"),
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_DATA_HOME": str(root / "data"),
        }
        for name in ("PYTHONPATH", "PYTHONHOME", "LD_LIBRARY_PATH", "LD_PRELOAD"):
            environment.pop(name, None)
        historical = None
        if args.sessions:
            # External verification data only; no assembler, programmer or
            # firmware fixture is added to the production resource tree.
            sys.path.insert(0, str(software.parent))
            from software.tests.viewrv.record_cases import end, lines, observation, start, unit

            historical = str(uuid4())
            captured = observation(state=11)
            captured["snapshot"]["registers"][31] = 2**32 - 1
            captured["snapshot"]["cycle_count"] = str(2**64 - 1)
            directory = root / "state/viewrv/records"
            directory.mkdir(parents=True, mode=0o700)
            (directory / (historical + ".jsonl")).write_bytes(
                lines(
                    unit(historical, "start", start()),
                    unit(historical, "observation", captured),
                    unit(historical, "end", end(1, "fault")),
                )
            )
            version = subprocess.check_output(
                [str(product / "viewrv"), "--version"], cwd=root, env=environment, text=True
            )
            from software.viewrv import __version__

            assert version.strip() == f"viewrv, version {__version__}"
        programmer = subprocess.run(
            [str(product / "resources/programmer/openFPGALoader"), "--version"],
            env=environment,
            capture_output=True,
            text=True,
            check=True,
        )
        assert programmer.stdout.strip() == "openFPGALoader v1.2.0"
        core = subprocess.Popen(
            [str(product / "resources/core/viewrv-core")],
            cwd=root,
            env=environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
        try:
            discovery_file = root / "viewrv/core.json"
            deadline = time.monotonic() + 15
            while not discovery_file.exists() and time.monotonic() < deadline:
                assert core.poll() is None, core.stderr.read().decode()
                time.sleep(0.02)
            discovery = json.loads(discovery_file.read_text())
            opener = build_opener(ProxyHandler({}))

            def action(route, body, work=None):
                headers = {
                    "Authorization": "Bearer " + discovery["access_token"],
                    "Content-Type": "application/json",
                }
                if work:
                    headers["X-Viewrv-Work-Id"] = work
                request = Request(
                    discovery["base_url"] + "/api/v1/" + route, json.dumps(body).encode(), headers
                )
                with opener.open(request, timeout=15) as response:
                    value = json.load(response)
                assert value["error"] is None, value
                return value["result"]

            def cli(*arguments, code=0):
                result = subprocess.run(
                    [str(product / "viewrv"), "--output", "json", *arguments],
                    cwd=root,
                    env=environment,
                    capture_output=True,
                    text=True,
                    timeout=25,
                )
                assert result.returncode == code, (result.stdout, result.stderr)
                return json.loads(result.stdout)

            observer = action(
                "work/register", {"client_type": "gui", "registration_id": str(uuid4())}
            )["work_id"]
            assert cli("board", "devices")["result"] == [], (
                "El ensayo requiere un host sin Basys 3 accesible."
            )
            assert isinstance(cli("board", "ports")["result"], list)
            assert cli("work", "status")["result"]["work_id"] is None
            if historical:
                listed = cli("session", "list")["result"]
                assert [item["session_id"] for item in listed["sessions"]] == [historical]
                shown = cli("session", "show", "--session", historical)["result"]
                assert shown["execution_status"] == "fault" and not shown["debug_open"]
                assert shown["evidence"]["record_status"] == "complete"
                assert shown["last_observation"]["snapshot"]["registers"][31] == 2**32 - 1
                assert shown["last_observation"]["snapshot"]["cycle_count"] == str(2**64 - 1)
                assert len(cli("session", "steps", "--session", historical)["result"]["steps"]) == 1
                assert (
                    cli("session", "steps", "--session", historical, "--after", "1")["result"][
                        "steps"
                    ]
                    == []
                )
                assert (
                    cli("session", "logs", "--session", historical)["result"]["source_text"]
                    == "# ñ\naddi x1,x0,5\nhalt\n"
                )
                assert cli("work", "status")["result"]["work_id"] is None
                source = root / "native assembler boundary.s"
                source.write_text("addi x1,x0,5\nhalt\n")
                assembled = cli("program", "assemble", str(source))["result"]
                assert assembled["image"] == list(bytes.fromhex("930050000b000000"))
                assert assembled["pc_to_line"] == [{"pc": 0, "line": 1}, {"pc": 4, "line": 2}]
                source.write_text("unknown x1,x0,5\n")
                rejected = cli("program", "assemble", str(source), code=1)["error"]
                assert rejected["code"] == "ASSEMBLY_SOURCE_ERROR"
                assert rejected["details"]["line"] == 1
            assert cli("board", "status")["result"]["preparation_required"] is True
            assert cli("board", "connect", code=1)["error"]["code"] == "BOARD_PREPARATION_REQUIRED"
            cli("work", "finish")
            action("work/finish", {}, observer)
            assert core.wait(timeout=10) == 0
            assert not discovery_file.exists()
        finally:
            if core.poll() is None:
                core.terminate()
                core.wait(timeout=10)
            core.stderr.close()
    print(
        "PC-I04 nativo: CLI/core independientes, programador 1.2.0 y dependencias locales, enumeración sin placa, preparación requerida y cierre correctos. Ensamblaje temporal sin release.json ni bitstream: no es un paquete distribuible."
    )
    if args.sessions:
        print(
            "PC-I05 nativo: consultas de evidencia histórica, 32/64 bits, ninguna sesión física restaurada, imagen/mapa y diagnóstico del assembler real correctos. El registro de prueba pertenece al directorio temporal del usuario, no al producto."
        )


if __name__ == "__main__":
    main()
