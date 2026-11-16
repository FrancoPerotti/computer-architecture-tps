"""Contrasta los programas físicos con el processor_top RTL por su frontera CPU."""

import argparse
import json
import struct
import sys
from pathlib import Path

from scripts.verification_manifest import TP3_ROOT, index_manifest, read_manifest

from .__main__ import write_json
from .plans import SMOKE, replay_plans, smoke
from .uart import CONTEXT, FIXED_SIZE, LAYOUT, WireError, compare, decode

# El ejecutor se comparte con scripts/run_tests.py, que carga sus módulos como
# scripts de primer nivel.
sys.path.insert(0, str(TP3_ROOT / "scripts"))
from prepare_case import write_data  # noqa: E402
from simulation_runner import compile_execution, run_process, simulation_result  # noqa: E402


def cpu_actions(plan):
    # Deja las solicitudes de tamaño, las esperas y los resets de botón a UART.
    # Conserva las imágenes y los snapshots de cada prefijo ejecutable.
    """Selecciona la parte de cada plan accesible en la frontera CPU."""
    for action in plan.actions:
        op = action["op"]
        if op in ("run-start", "button"):
            return
        if op == "load":
            data = plan.images[action["image"]].data
            words = [int.from_bytes(data[i : i + 4], "little") for i in range(0, len(data), 4)]
            yield {"op": op, "words": words}
        elif op in ("step", "run"):
            yield action
        elif op == "command" and action["request"] == 4:
            yield {"op": "reset"}


def cpu_snapshot(hex_dump):
    # El bench conserva los X del RTL en el log. Solo se sustituyen para
    # decodificar campos sin vigencia arquitectónica en esta observación.
    """Decodifica la captura RTL respetando la vigencia de cada campo."""
    raw = list(hex_dump)
    if int(hex_dump[:2], 16) not in (8, 9, 11):
        raw[28:38] = "0000000000"
    offset = 2 * CONTEXT.size
    for name, fmt, _ in LAYOUT:
        end = offset + 2 * struct.calcsize(fmt)
        if hex_dump[offset : offset + 2] == "00":
            # IF/ID también puede describir un candidato de fault de fetch.
            if name == "ifid" and hex_dump[end - 4 : end - 2] == "01":
                bytes.fromhex(hex_dump[offset + 2 : offset + 10] + hex_dump[end - 2 : end])
            for index in range(offset + 2, end):
                if raw[index] in "xXzZ":
                    raw[index] = "0"
        offset = end
    data = bytes.fromhex("".join(raw))
    return decode(data[:FIXED_SIZE], data[FIXED_SIZE:])


def check(case_id, actions, binary, directory):
    """Corre el banco compartido y compara las capturas con el oráculo."""
    directory.mkdir(parents=True)
    case_data = directory / "case.data"
    write_data(
        case_data,
        {
            "id": case_id,
            "actions": [{k: v for k, v in action.items() if k != "expected"} for action in actions],
        },
    )
    stdout = directory / "simulation.stdout"
    outcome = run_process(
        ["vvp", str(binary), f"+CASE={case_id}", f"+CASE_DATA={case_data}"],
        directory,
        stdout,
        directory / "simulation.stderr",
        timeout=30,
    )
    status, reported, detail = simulation_result(stdout, outcome.returncode)
    if status != "passed" or reported != case_id:
        raise WireError(f"{detail or reported}; ver {stdout}")
    expected = [action["expected"] for action in actions if "expected" in action]
    observed = []
    for line in stdout.read_text().splitlines():
        if line.startswith("DEBUG "):
            observed.append(cpu_snapshot(line.removeprefix("DEBUG ")))
    write_json(directory / "snapshots.json", observed)
    if len(expected) != len(observed):
        raise WireError(f"cantidad de snapshots: {len(observed)}, esperados {len(expected)}")
    for number, (wanted, actual) in enumerate(zip(expected, observed, strict=True), 1):
        compare(wanted, actual, f"captura {number}")
    return len(observed)


def main():
    """Valida las opciones de la CLI y guarda los resultados."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--case", action="append")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True)
    groups, _ = index_manifest(read_manifest())
    execution = next(
        item for item in groups["TEST-ISA-001"]["executions"] if item["top"] == "processor_top_tb"
    )
    sources = [name for name in execution["sources"] if name != "tb/processor_top_tb.sv"]
    binary, error = compile_execution(
        {
            "top": "board_acceptance_cpu_tb",
            "sources": [
                *sources,
                "tb/common/processor_test_harness.sv",
                "tb/board_acceptance_cpu_tb.sv",
            ],
        },
        output / "compile",
        {},
    )
    if error:
        parser.exit(1, f"{error}\n")
    plans = {SMOKE: smoke(), **dict(replay_plans())}
    if args.case and set(args.case) - plans.keys():
        parser.error("ID fuera de TEST-PLAT-005")
    report = {}
    for case_id in dict.fromkeys(args.case or plans):
        plan = plans[case_id]
        actions = list(cpu_actions(plan))
        if not any("expected" in action for action in actions):
            report[case_id] = {"status": "pending", "reason": "intercambio UART o botón"}
            continue
        try:
            count = check(case_id, actions, binary, output / case_id)
        except (WireError, OSError, ValueError) as error:
            report[case_id] = {"status": "failed", "reason": str(error)}
            print(f"{case_id} FAIL {error}", file=sys.stderr)
        else:
            report[case_id] = {"status": "passed", "snapshots": count, "level": "CPU"}
    write_json(output / "status.json", report)
    print(
        json.dumps(
            {
                status: sum(row["status"] == status for row in report.values())
                for status in ("passed", "failed", "pending")
            }
        )
    )
    return any(row["status"] == "failed" for row in report.values())


if __name__ == "__main__":
    raise SystemExit(main())
