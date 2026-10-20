"""Compile and execute Icarus simulations using isolated temporary files."""

from dataclasses import dataclass
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile

from prepare_case import case_payload, write_data
from verification_manifest import TP3_ROOT, index_manifest


SIMULATION_LEVELS = frozenset({"Unidad", "Integración local", "CPU", "Sistema"})


@dataclass(frozen=True)
class ProcessOutcome:
    returncode: int
    timed_out: bool = False


def stop_process(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    return process.wait()


def run_process(command, directory, stdout_path, stderr_path, timeout=None):
    """A timeout or interruption also terminates children of the tool."""
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        process = subprocess.Popen(
            command, cwd=directory, stdin=subprocess.DEVNULL,
            stdout=stdout, stderr=stderr, start_new_session=True,
        )
        try:
            return ProcessOutcome(process.wait(timeout=timeout))
        except subprocess.TimeoutExpired:
            return ProcessOutcome(stop_process(process), timed_out=True)
        except BaseException:
            if process.poll() is None:
                stop_process(process)
            raise


def diagnostics(path, label):
    if path.exists() and path.stat().st_size:
        print(f"--- {label} ---", file=sys.stderr)
        with path.open(encoding="utf-8", errors="replace") as source:
            shutil.copyfileobj(source, sys.stderr)
        print(file=sys.stderr)


def simulation_result(stdout_path, returncode):
    """Accept exactly one protocol line, including the requested ID later."""
    markers = []
    with stdout_path.open(encoding="utf-8", errors="replace") as source:
        for line in source:
            words = line.strip().split(None, 2)
            if words and words[0] in {"PASS", "FAIL"}:
                markers.append(words)
                if len(markers) > 1:
                    return "error", None, "la simulación informó más de un resultado"
    if not markers:
        return "error", None, f"la simulación terminó sin resultado explícito (código {returncode})"
    marker = markers[0]
    if len(marker) < 2:
        return "error", None, "resultado sin ID de caso"
    status, case_id = marker[:2]
    if returncode < 0:
        return "error", case_id, f"la simulación terminó por señal {-returncode}"
    if status == "PASS":
        if len(marker) != 2:
            return "error", case_id, "formato inválido: se esperaba PASS <ID>"
        if returncode != 0:
            return "error", case_id, f"PASS acompañado por código de salida {returncode}"
        return "passed", case_id, None
    if len(marker) != 3 or not marker[2].strip():
        return "error", case_id, "FAIL requiere una explicación"
    if returncode == 0:
        return "error", case_id, "FAIL acompañado por código de salida 0"
    return "failed", case_id, marker[2]


def compile_execution(execution, directory):
    directory.mkdir()
    binary = directory / "simulation.vvp"
    stdout = directory / "compile.stdout"
    stderr = directory / "compile.stderr"
    command = ["iverilog", "-g2012", "-s", execution["top"], "-o", str(binary)]
    command.extend(str((TP3_ROOT / source).resolve()) for source in execution["sources"])
    try:
        outcome = run_process(command, TP3_ROOT, stdout, stderr)
    except OSError as error:
        return None, f"no se pudo iniciar la compilación: {error}"
    diagnostics(stdout, f"compilación {execution['top']}: stdout")
    diagnostics(stderr, f"compilación {execution['top']}: stderr")
    if outcome.returncode != 0:
        return None, f"falló la compilación de {execution['top']} (código {outcome.returncode})"
    if not binary.is_file():
        return None, f"la compilación de {execution['top']} no generó la simulación"
    return binary, None


def run_case(manifest, case, execution, binary, directory):
    directory.mkdir()
    stdout = directory / "simulation.stdout"
    stderr = directory / "simulation.stderr"
    data_file = directory / "case.data"
    case_id = case["id"]
    try:
        write_data(data_file, case_payload(manifest, case))
        outcome = run_process(
            ["vvp", str(binary), f"+CASE={case_id}", f"+CASE_DATA={data_file}"],
            directory, stdout, stderr, timeout=execution["timeout_seconds"],
        )
    except (OSError, ValueError) as error:
        return "error", f"no se pudo preparar o iniciar el caso: {error}"
    if outcome.timed_out:
        status, message = "error", f"se excedió timeout_seconds={execution['timeout_seconds']}"
    else:
        status, reported_id, message = simulation_result(stdout, outcome.returncode)
        if reported_id is not None and reported_id != case_id:
            status, message = "error", f"el resultado corresponde a {reported_id}, se solicitó {case_id}"
    diagnostics(stderr, f"simulación {case_id}: stderr")
    if status != "passed":
        diagnostics(stdout, f"simulación {case_id}: stdout")
    return status, message


def result_report(results):
    if not results:
        raise ValueError("no se produjo ningún resultado de prueba")
    summary = {
        "total": len(results),
        "passed": sum(row["status"] == "passed" for row in results),
        "failed": sum(row["status"] == "failed" for row in results),
        "errors": sum(row["status"] == "error" for row in results),
    }
    status = "error" if summary["errors"] else "failed" if summary["failed"] else "passed"
    return {"status": status, "summary": summary, "results": results}


def run_selection(manifest, selection):
    for tool in ("iverilog", "vvp"):
        if shutil.which(tool) is None:
            raise ValueError(f"no se encontró {tool}; utilice el entorno de desarrollo compartido")
    groups, cases = index_manifest(manifest)
    results = []
    compiled = {}
    with tempfile.TemporaryDirectory(prefix="tp3-tests-") as temporary:
        root = Path(temporary)
        for entry in selection:
            for execution_index, execution in enumerate(groups[entry.group_id]["executions"]):
                key = (entry.group_id, execution_index)
                if key not in compiled:
                    print(f"Compilando {entry.group_id}: {execution['top']} ({execution['level']})", file=sys.stderr)
                    compiled[key] = compile_execution(execution, root / f"build-{len(compiled)}")
                binary, compile_error = compiled[key]
                if compile_error:
                    status, message = "error", compile_error
                else:
                    print(f"Simulando {entry.case_id}: {execution['top']} ({execution['level']})", file=sys.stderr)
                    _, case = cases[entry.case_id]
                    status, message = run_case(
                        manifest, case, execution, binary, root / f"case-{len(results)}",
                    )
                results.append({
                    "case_id": entry.case_id, "top": execution["top"],
                    "level": execution["level"], "status": status, "message": message,
                })
    return result_report(results)
