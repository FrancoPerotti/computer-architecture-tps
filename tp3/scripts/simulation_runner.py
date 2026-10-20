"""Compile and execute Icarus simulations using isolated temporary files."""

import os
import shutil
import signal
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

from prepare_case import case_payload, write_data
from verification_manifest import (
    TP3_ROOT,
    case_executions,
    execution_parameters,
    index_manifest,
    rejection_diagnostic,
)

# Niveles de verificación que puede acreditar una ejecución del simulador.
SIMULATION_LEVELS = frozenset({"Unidad", "Integración local", "CPU", "Sistema"})


@dataclass(frozen=True)
class ProcessOutcome:
    """Conserva el código de salida del proceso y si se agotó su tiempo de ejecución."""

    returncode: int
    timed_out: bool = False


def stop_process(process):
    """Termina el grupo de procesos y espera su cierre para recoger el código de salida."""
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    return process.wait()


def run_process(command, directory, stdout_path, stderr_path, timeout=None):
    """Ejecuta una herramienta con logs separados y limpia sus procesos al vencer o interrumpirse."""
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        process = subprocess.Popen(
            command,
            cwd=directory,
            stdin=subprocess.DEVNULL,
            stdout=stdout,
            stderr=stderr,
            start_new_session=True,
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
    """Copia un archivo de diagnóstico no vacío a stderr con su identificación."""
    if path.exists() and path.stat().st_size:
        print(f"--- {label} ---", file=sys.stderr)
        with path.open(encoding="utf-8", errors="replace") as source:
            shutil.copyfileobj(source, sys.stderr)
        print(file=sys.stderr)


def simulation_result(stdout_path, returncode, rejection=None, expected_diagnostic=None):
    """Devuelve estado, ID y diagnóstico tras validar un único marcador y su código de salida."""
    markers = []
    with stdout_path.open(encoding="utf-8", errors="replace") as source:
        for line in source:
            words = line.strip().split(None, 2)
            if words and words[0] in {"PASS", "FAIL", "REJECT"}:
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
    if status == "REJECT":
        if rejection is None:
            return "error", case_id, "rechazo sin expectativa registrada"
        if len(marker) != 3 or marker[2] != expected_diagnostic:
            return "failed", case_id, "el diagnóstico de rechazo difiere del esperado"
        if returncode != rejection["exit_code"]:
            return (
                "error",
                case_id,
                f"rechazo con código {returncode}; se esperaba {rejection['exit_code']}",
            )
        return "passed", case_id, None
    if status == "PASS":
        if len(marker) != 2:
            return "error", case_id, "formato inválido: se esperaba PASS <ID>"
        if returncode != 0:
            return "error", case_id, f"PASS acompañado por código de salida {returncode}"
        if rejection is not None:
            return "failed", case_id, "se esperaba un rechazo y la configuración fue aceptada"
        return "passed", case_id, None
    if len(marker) != 3 or not marker[2].strip():
        return "error", case_id, "FAIL requiere una explicación"
    if returncode == 0:
        return "error", case_id, "FAIL acompañado por código de salida 0"
    return "failed", case_id, marker[2]


def compile_execution(execution, directory, parameters):
    """Compila el top y sus parámetros en orden; devuelve el ejecutable o el error de compilación."""
    directory.mkdir()
    binary = directory / "simulation.vvp"
    stdout = directory / "compile.stdout"
    stderr = directory / "compile.stderr"
    top = execution["top"]
    wrapper = None
    if parameters:
        # El esquema limita las expresiones a identificadores y literales enteros.
        # Una instancia conserva las referencias a constantes de paquete.
        wrapper = directory / "selected_top.sv"
        bindings = ", ".join(f".{name}({value})" for name, value in parameters.items())
        wrapper.write_text(
            f"module __tp3_runner_top; {top} #({bindings}) dut(); endmodule\n",
            encoding="utf-8",
        )
        top = "__tp3_runner_top"
    command = ["iverilog", "-g2012", "-s", top, "-o", str(binary)]
    command.extend(str((TP3_ROOT / source).resolve()) for source in execution["sources"])
    if wrapper is not None:
        command.append(str(wrapper))
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
    """Prepara los datos, simula un caso y comprueba el ID, el resultado y el límite de tiempo."""
    directory.mkdir()
    stdout = directory / "simulation.stdout"
    stderr = directory / "simulation.stderr"
    data_file = directory / "case.data"
    case_id = case["id"]
    try:
        write_data(data_file, case_payload(manifest, case))
        outcome = run_process(
            ["vvp", str(binary), f"+CASE={case_id}", f"+CASE_DATA={data_file}"],
            directory,
            stdout,
            stderr,
            timeout=execution["timeout_seconds"],
        )
    except (OSError, ValueError) as error:
        return "error", f"no se pudo preparar o iniciar el caso: {error}"
    if outcome.timed_out:
        status, message = "error", f"se excedió timeout_seconds={execution['timeout_seconds']}"
    else:
        status, reported_id, message = simulation_result(
            stdout,
            outcome.returncode,
            execution.get("expected_rejection"),
            rejection_diagnostic(execution, case),
        )
        if reported_id is not None and reported_id != case_id:
            status, message = (
                "error",
                f"el resultado corresponde a {reported_id}, se solicitó {case_id}",
            )
    diagnostics(stderr, f"simulación {case_id}: stderr")
    if status != "passed":
        diagnostics(stdout, f"simulación {case_id}: stdout")
    return status, message


def result_report(results):
    """Resume los resultados y determina el estado global; rechaza corridas vacías."""
    if not results:
        raise ValueError("no se produjo ningún resultado de prueba")
    summary = {
        "total": len(results),
        "passed": sum(row["status"] == "passed" for row in results),
        "failed": sum(row["status"] == "failed" for row in results),
        "errors": sum(row["status"] == "error" for row in results),
    }
    status = "error" if summary["errors"] else "failed" if summary["failed"] else "passed"
    return {"status": status, "summary": summary, "results": results, "pending_cases": []}


def run_selection(manifest, selection, reports_dir=None):
    """Ejecuta la selección reutilizando compilaciones por configuración y aislando sus archivos."""
    for tool in ("iverilog", "vvp"):
        if shutil.which(tool) is None:
            raise ValueError(f"no se encontró {tool}; utilice el entorno de desarrollo compartido")
    groups, cases = index_manifest(manifest)
    results = []
    compiled = {}
    with tempfile.TemporaryDirectory(prefix="tp3-tests-") as temporary:
        root = Path(temporary)
        if reports_dir is not None:
            reports_dir = Path(reports_dir).resolve()
            reports_dir.mkdir(parents=True, exist_ok=True)
        try:
            for entry in selection:
                for execution_index, execution in case_executions(
                    groups[entry.group_id], entry.case_id
                ):
                    _, case = cases[entry.case_id]
                    parameters = execution_parameters(execution, case)
                    key = (entry.group_id, execution_index, tuple(parameters.items()))
                    if key not in compiled:
                        print(
                            f"Compilando {entry.group_id}: {execution['top']} ({execution['level']})",
                            file=sys.stderr,
                        )
                        compiled[key] = compile_execution(
                            execution, root / f"build-{len(compiled)}", parameters
                        )
                    binary, compile_error = compiled[key]
                    if compile_error:
                        status, message = "error", compile_error
                    else:
                        print(
                            f"Simulando {entry.case_id}: {execution['top']} ({execution['level']})",
                            file=sys.stderr,
                        )
                        status, message = run_case(
                            manifest,
                            case,
                            execution,
                            binary,
                            root / f"case-{len(results)}",
                        )
                    results.append(
                        {
                            "case_id": entry.case_id,
                            "top": execution["top"],
                            "level": execution["level"],
                            "status": status,
                            "message": message,
                        }
                    )
        finally:
            if reports_dir is not None:
                # Conserva solo diagnósticos; binarios y datos intermedios siguen siendo temporales.
                for log in root.rglob("*"):
                    if log.is_file() and log.suffix in {".stdout", ".stderr"}:
                        destination = reports_dir / log.relative_to(root)
                        destination.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(log, destination)
    return result_report(results)
