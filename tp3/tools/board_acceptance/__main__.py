"""Prepara o ejecuta los casos físicos de TEST-PLAT-005."""

import argparse
import hashlib
import json
import math
import platform
import subprocess
import sys
import time
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path

from scripts.verification_manifest import TP3_ROOT

from .plans import GROUP, SMOKE, replay_plans, smoke
from .uart import BAUD, Link, WireError, compare


def write_json(path, value):
    """Publica un JSON completo mediante reemplazo atómico."""
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temp.replace(path)


def digest(path):
    """Calcula SHA-256 sin cargar el archivo entero en memoria."""
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def prepare_case(directory, case_id, plan):
    """Guarda el estímulo, el oráculo y las rutas de evidencia para un ID."""
    directory.mkdir(parents=True)
    images = []
    for index, image in enumerate(plan.images):
        name = f"program-{index + 1}"
        binary = directory / f"{name}.bin"
        binary.write_bytes(image.data)
        if image.source:
            (directory / f"{name}.s").write_text(image.source, encoding="utf-8")
        if image.setup:
            (directory / f"{name}-setup.s").write_text(image.setup, encoding="utf-8")
        images.append(
            {
                "path": binary.name,
                "bytes": len(image.data),
                "sha256": digest(binary),
                "block_pc": image.block_pc,
                "setup_cycles": image.setup_cycles,
            }
        )
    evidence = ["plan.json", "program-*.bin", "uart.jsonl", "result.json"]
    if any(action["op"] == "button" for action in plan.actions):
        evidence.append("button-notes.txt")
    if plan.pending:
        evidence.append("button-trace (RX, TX y reset; formato del instrumento)")
    write_json(
        directory / "plan.json",
        {
            "case": case_id,
            "images": images,
            "actions": plan.actions,
            "pending": plan.pending,
            "evidence": evidence,
        },
    )


def execute(link, plan, run_wait):
    """Ejecuta las acciones de un caso y verifica las respuestas en orden."""
    for index, action in enumerate(plan.actions, 1):
        link.record("action", {"index": index, "op": action["op"]})
        match action:
            case {"op": "command", "request": request, "response": response}:
                link.command(request, response)
                if request == 4:
                    link.require_quiet(0.010)
            case {"op": "load", "image": image}:
                link.load(plan.images[image].data)
            case {"op": "load-header", "size": size, "response": response}:
                link.load_header(size, response)
            case {"op": "incomplete-load", "size": size, "data": data}:
                link.incomplete_load(size, bytes.fromhex(data))
            case {"op": "run-start"}:
                link.command(2, 1)
            case {"op": "step" | "run" as op, "expected": expected}:
                snapshot = link.snapshot(op, expected.get("state"), run_wait)
                link.record("snapshot", snapshot)
                compare(expected, snapshot)
                link.require_quiet(0.010)
            case {"op": "button", "phase": phase}:
                image = plan.images[action["image"]].data if "image" in action else None
                link.button(phase, run_wait, image)
            case _:
                raise ValueError(f"operación desconocida: {action}")


def git(*args):
    """Consulta la revisión del worktree que ejecuta la prueba."""
    return subprocess.check_output(["git", "-C", str(TP3_ROOT), *args], text=True).strip()


def hardware_metadata(args):
    """Vincula el ensayo al build de Vivado y verifica la huella del bitstream."""
    bitstream = args.bitstream.resolve(strict=True)
    info_path = bitstream.parent / "build-info.txt"
    info = info_path.read_text(encoding="utf-8")
    reports = (bitstream.parent / "reports").resolve(strict=True)
    bitstream_hash = digest(bitstream)
    if bitstream.name != "tp3-reference.bit" or not reports.is_dir():
        raise ValueError("se requiere tp3-reference.bit con el directorio reports de la #16")
    lines = info.splitlines()
    for line in ("Profile REFERENCE", "Mode reference", f"Commit {args.rtl_commit}"):
        if line not in lines:
            raise ValueError(f"build-info.txt no confirma {line}")
    hash_lines = info.partition("SHA-256 del bitstream:\n")[2].splitlines()
    if not hash_lines or not hash_lines[0].startswith(f"{bitstream_hash}  "):
        raise ValueError("el SHA-256 del bitstream difiere de build-info.txt")
    report_hashes = {file.name: digest(file) for file in sorted(reports.glob("*.rpt"))}
    if not {"timing-summary.rpt", "setup.rpt", "hold.rpt"} <= report_hashes.keys():
        raise ValueError("faltan los reportes de timing de la #16")
    return {
        "port": args.port,
        "bitstream": str(bitstream),
        "sha256": bitstream_hash,
        "rtl_commit": args.rtl_commit,
        "build_info": info,
        "vivado_reports": str(reports),
        "reports_sha256": report_hashes,
        "operators": args.operators,
        "notes": args.notes,
    }


def run_cases(args, plans, status):
    """Corre los casos seleccionados sobre un solo puerto físico."""
    import serial

    runnable = {
        case_id: plan
        for case_id, plan in plans.items()
        if not plan.pending and (args.manual or not any(a["op"] == "button" for a in plan.actions))
    }
    if not runnable:
        print("Los casos seleccionados requieren el recorrido manual o instrumentación.")
        return 0

    with serial.Serial(
        port=args.port,
        baudrate=BAUD,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=0.01,
        write_timeout=2,
        xonxoff=False,
        rtscts=False,
        dsrdtr=False,
        exclusive=True,
    ) as port:
        for index, (case_id, plan) in enumerate(runnable.items()):
            directory = args.output / case_id
            with (directory / "uart.jsonl").open("x", encoding="utf-8", buffering=1) as log:
                start = time.monotonic()

                def record(event, data):
                    log.write(
                        json.dumps(
                            {"elapsed_s": time.monotonic() - start, "event": event, "data": data}
                        )
                        + "\n"
                    )

                link = Link(port, record)
                try:
                    # Cada caso comienza en NO_IMAGE. La preparación de un
                    # caso A→B conserva el enlace y reemplaza A solo con LOAD.
                    if index == 0:
                        link.synchronize_open()
                    else:
                        link.require_quiet(0.020)
                    link.command(4, 1)
                    link.require_quiet(0.010)
                    execute(link, plan, args.run_wait)
                except (WireError, OSError, KeyboardInterrupt, EOFError) as error:
                    result = {"status": "failed", "reason": str(error) or type(error).__name__}
                else:
                    result = {"status": "passed", "level": "placa", "transport": "UART"}
            status[case_id]["board"] = result["status"]
            write_json(directory / "result.json", result)
            write_json(args.output / "status.json", status)
            print(f"{case_id} {result['status']}", flush=True)
            if result["status"] != "passed":
                print(result["reason"], file=sys.stderr)
                return 1
    return 0


def simulate(directory, plan, status):
    """Ejecuta el recorrido inicial con respuestas y reloj controlados."""
    from .fixture import smoke_port

    directory = directory / SMOKE
    port = smoke_port()
    with (directory / "uart.jsonl").open("x", encoding="utf-8", buffering=1) as log:

        def record(event, data):
            log.write(json.dumps({"elapsed_s": port.time, "event": event, "data": data}) + "\n")

        link = Link(port, record, now=port.monotonic, pause=port.sleep)
        try:
            execute(link, plan, 3)
            port.complete()
        except (WireError, AssertionError) as error:
            result = {"status": "failed", "reason": str(error)}
        else:
            result = {"status": "passed", "level": "host", "transport": "simulado"}
    status[SMOKE]["simulated_transport"] = result["status"]
    write_json(directory / "result.json", result)
    write_json(directory.parent / "status.json", status)
    print(f"{SMOKE} {result['status']} (transporte simulado)", flush=True)
    return result["status"] != "passed"


def main(argv=None):
    """Valida las opciones de la CLI y guarda los resultados."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--case", action="append", help="ID exacto o smoke. Sin filtro prepara 151 IDs."
    )
    parser.add_argument("--output", type=Path, required=True, help="Directorio nuevo de evidencia")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--port", help="Puerto físico. Omitir para preparar sin conectar.")
    mode.add_argument(
        "--simulate", action="store_true", help="Ejecuta smoke con un transcript fijo"
    )
    parser.add_argument(
        "--bitstream", type=Path, help="Bitstream REFERENCE de la #16 ya programado"
    )
    parser.add_argument("--rtl-commit", help="Commit completo del build RTL")
    parser.add_argument("--operators", nargs=2, metavar=("OPERADOR", "COMPARADOR"))
    parser.add_argument("--notes", help="Identificación de la placa, sesión y turnos")
    parser.add_argument(
        "--manual", action="store_true", help="Habilita los casos de botón interactivos"
    )
    parser.add_argument(
        "--run-wait",
        type=float,
        default=3,
        help="Cota externa del ensayo hasta la cabecera terminal (segundos)",
    )
    args = parser.parse_args(argv)
    if not math.isfinite(args.run_wait) or args.run_wait <= 0:
        parser.error("--run-wait debe ser positivo y finito")
    if args.port and not (args.bitstream and args.rtl_commit and args.operators and args.notes):
        parser.error("--port requiere --bitstream, --rtl-commit, --operators y --notes")
    if args.port and (
        len(args.rtl_commit) != 40 or any(c not in "0123456789abcdef" for c in args.rtl_commit)
    ):
        parser.error("--rtl-commit requiere el SHA Git completo")
    if args.simulate and args.case and args.case != [SMOKE]:
        parser.error("--simulate ejecuta únicamente smoke")
    if args.simulate:
        args.case = [SMOKE]
    try:
        plans = dict(replay_plans())
        if args.case:
            plans[SMOKE] = smoke()
            unknown = set(args.case) - plans.keys()
            if unknown:
                raise ValueError(f"IDs fuera de {GROUP}: {sorted(unknown)}")
            plans = {case_id: plans[case_id] for case_id in dict.fromkeys(args.case)}
        hardware = hardware_metadata(args) if args.port else None
        session = {
            "catalogue": GROUP,
            "created_utc": datetime.now(UTC).isoformat(),
            "profile": "REFERENCE",
            "argv": list(sys.argv[1:] if argv is None else argv),
            "uart": {"baud": BAUD, "format": "8N1"},
            "software_commit": git("rev-parse", "HEAD"),
            "software_changes": git(
                "status", "--short", "--untracked-files=all", "--", str(TP3_ROOT)
            ),
            "python": platform.python_version(),
            "mode": "simulado" if args.simulate else "placa" if args.port else "preparación",
            "hardware": hardware,
        }
        if args.port:
            import serial

            session["pyserial"] = serial.VERSION
        args.output.mkdir(parents=True)
        write_json(args.output / "session.json", session)
        status = {}
        for case_id, plan in plans.items():
            prepare_case(args.output / case_id, case_id, plan)
            status[case_id] = {
                "preparation": "pending" if plan.pending else "prepared",
                "board": "pending",
                "reason": plan.pending,
            }
        write_json(args.output / "status.json", status)
        print(dict(Counter(case["preparation"] for case in status.values())), flush=True)
        if args.port:
            return run_cases(args, plans, status)
        if args.simulate:
            return simulate(args.output, plans[SMOKE], status)
    except (OSError, ValueError, ImportError, subprocess.CalledProcessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
