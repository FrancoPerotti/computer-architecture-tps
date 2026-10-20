"""Permanent smoke/regression tests using real Icarus and temporary artefacts."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# Permite importar las herramientas al descubrir pruebas desde otro directorio.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from simulation_runner import result_report, run_process
from verification_manifest import MANIFEST

# Ruta de las herramientas que se prueban, independiente del directorio de ejecución.
SCRIPTS = Path(__file__).resolve().parents[1]

# Grupo y fuentes sintéticos para comprobar el ejecutor con Icarus real.
GROUP = "TEST-SMOKE-001"
SOURCES = [
    "scripts/tests/fixtures/runner_smoke_pkg.sv",
    "tb/common/tp3_case_data.sv",
    "scripts/tests/fixtures/runner_smoke_tb.sv",
]


class SimulationRunnerTests(unittest.TestCase):
    """Comprueba compilación, ejecución y resultados con bancos sintéticos y artefactos temporales."""

    def setUp(self):
        """Prepara un grupo de smoke tests y un espacio temporal independiente para cada prueba."""
        self.work = tempfile.TemporaryDirectory(prefix="tp3 runner smoke ")
        self.addCleanup(self.work.cleanup)
        self.directory = Path(self.work.name)
        self.manifest_path = self.directory / "manifest.json"
        self.scratch = self.directory / "scratch"
        self.scratch.mkdir()
        self.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.group = {
            "id": GROUP,
            "source": "runner smoke fixture",
            "case_count": 0,
            "reuse_groups": [],
            "executions": [
                {
                    "sources": SOURCES.copy(),
                    "top": "runner_smoke_tb",
                    "level": "Unidad",
                    "timeout_seconds": 1,
                }
            ],
            "cases": [],
        }
        self.manifest["groups"] = [self.group]

    def add_case(self, mode="sum", expected=5):
        """Agrega un caso sintético con el modo y la expectativa solicitados y devuelve su ID."""
        case_id = f"{GROUP}/C{len(self.group['cases']) + 1:03}"
        self.group["cases"].append(
            {
                "id": case_id,
                "status": "implemented",
                "inputs": {"a": 2, "b": 3, "mode": mode},
                "expected": {"result": expected},
                "kind": "vector",
                "origins": ["runner smoke fixture"],
            }
        )
        self.group["case_count"] = len(self.group["cases"])
        return case_id

    def cli(self, *arguments, json_output=True, env_extra=None):
        """Ejecuta la selección temporal y exige que el ejecutor limpie sus artefactos."""
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        environment = {**os.environ, "TMPDIR": str(self.scratch), **(env_extra or {})}
        command = ["bash", str(SCRIPTS / "run_tests.sh"), "--manifest", str(self.manifest_path)]
        command.extend(arguments or ["--all"])
        if json_output:
            command.extend(["--format", "json"])
        result = subprocess.run(
            command, cwd=self.directory, env=environment, capture_output=True, text=True, timeout=20
        )
        self.assertEqual(list(self.scratch.iterdir()), [], "runner left temporary artefacts")
        return result

    def validate_report(self, result):
        """Valida el esquema del informe y la coherencia entre filas, contadores y estado global."""
        report = json.loads(result.stdout)
        path = self.directory / "results.json"
        path.write_text(result.stdout, encoding="utf-8")
        validation = subprocess.run(
            [
                "check-jsonschema",
                "--schemafile",
                str(SCRIPTS.parent / "docs/verification/results.schema.json"),
                str(path),
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(validation.returncode, 0, validation.stdout + validation.stderr)
        summary = report["summary"]
        self.assertEqual(summary["total"], len(report["results"]))
        self.assertEqual(
            summary["total"], summary["passed"] + summary["failed"] + summary["errors"]
        )
        return report

    def test_smoke_success_compiles_once_and_deduplicates_selection(self):
        """Comprueba una compilación por banco y evita repetir un caso seleccionado varias veces."""
        first = self.add_case()
        self.add_case()
        counter = self.directory / "compiler_calls.jsonl"
        wrapper_dir = self.directory / "tools"
        wrapper_dir.mkdir()
        compiler = shutil.which("iverilog")
        wrapper = wrapper_dir / "iverilog"
        wrapper.write_text(
            "#!/usr/bin/env python3\nimport json, os, sys\n"
            f"with open({str(counter)!r}, 'a') as out: out.write(json.dumps(sys.argv[1:]) + '\\n')\n"
            f"os.execv({compiler!r}, [{compiler!r}, *sys.argv[1:]])\n"
        )
        wrapper.chmod(0o755)
        result = self.cli(
            "--test",
            GROUP,
            "--test",
            first,
            env_extra={"PATH": f"{wrapper_dir}{os.pathsep}{os.environ['PATH']}"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.validate_report(result)
        self.assertEqual(report["summary"], {"total": 2, "passed": 2, "failed": 0, "errors": 0})
        self.assertEqual(report["status"], "passed")
        self.assertTrue(all(row["message"] is None for row in report["results"]))
        calls = [json.loads(line) for line in counter.read_text().splitlines()]
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][-3:], [str(SCRIPTS.parent / path) for path in SOURCES])
        self.assertIn("Simulando", result.stderr)

    def test_pending_cases_do_not_become_results_and_logs_can_be_preserved(self):
        """Comprueba estados mixtos, selección explícita y persistencia de diagnósticos."""
        implemented = self.add_case()
        pending = self.add_case()
        self.group["cases"][-1]["status"] = "pending"
        self.group["cases"][-1]["inputs"].pop("a")
        self.group["cases"][0]["expected"]["result"] = 7
        self.group["executions"][0]["parameters"] = {"OFFSET": {"input": "a"}}
        logs = self.directory / "reports"
        result = self.cli("--all", "--reports-dir", str(logs))
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.validate_report(result)
        self.assertEqual(report["pending_cases"], [pending])
        self.assertEqual([row["case_id"] for row in report["results"]], [implemented])
        self.assertEqual(report["summary"]["total"], 1)
        self.assertTrue(list(logs.rglob("compile.stderr")))
        self.assertTrue(list(logs.rglob("simulation.stdout")))
        result = self.cli("--test", pending)
        self.assertEqual(result.returncode, 1)
        self.assertIn("pendiente", result.stderr)

    def test_json_assertion_failure_is_failed_and_later_case_runs(self):
        """Exige que una aserción fallida se informe y no impida ejecutar casos posteriores."""
        self.add_case(expected=6)
        self.add_case(expected=5)
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["status"], "failed")
        self.assertEqual([row["status"] for row in report["results"]], ["failed", "passed"])
        self.assertIn("expected 6, observed 5", report["results"][0]["message"])

    def test_parameters_and_case_filters_keep_configurations_separate(self):
        """Comprueba que cada caso reciba únicamente sus bancos y parámetros aplicables."""
        first = self.add_case(expected=6)
        second = self.add_case(expected=5)
        execution = self.group["executions"][0]
        execution["case_ids"] = [first]
        execution["parameters"] = {"OFFSET": "1"}
        self.group["executions"].append(
            {
                "sources": SOURCES.copy(),
                "top": "runner_smoke_tb",
                "level": "Unidad",
                "timeout_seconds": 1,
                "case_ids": [second],
            }
        )
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.validate_report(result)
        self.assertEqual(report["summary"]["passed"], 2)
        self.assertEqual(len(report["results"]), 2)
        # Un banco inválido ajeno al caso no debe impedir su ejecución.
        execution["sources"] = ["missing.sv"]
        result = self.cli("--test", second)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_expected_rejection_requires_exact_marker_diagnostic_and_exit_code(self):
        """Aprueba rechazos solo cuando coinciden marcador, ID, diagnóstico y código de salida."""
        modes = [
            "reject",
            "reject_zero",
            "reject_duplicate",
            "reject_wrong_id",
            "fatal_only",
            "sum",
        ]
        for mode in modes:
            self.add_case(mode=mode)
            self.group["cases"][-1]["expected"]["diagnostic"] = "SMOKE_REJECTION"
        self.group["executions"][0]["expected_rejection"] = {
            "exit_code": 1,
            "diagnostic_key": "diagnostic",
        }
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(
            [row["status"] for row in report["results"]],
            ["passed", "error", "error", "error", "error", "failed"],
        )
        self.group["cases"][0]["expected"]["diagnostic"] = "OTHER_DIAGNOSTIC"
        result = self.cli("--test", self.group["cases"][0]["id"])
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.validate_report(result)["results"][0]["status"], "failed")
        self.group["cases"][0]["expected"]["diagnostic"] = "SMOKE_REJECTION"
        self.group["executions"][0]["expected_rejection"]["exit_code"] = 2
        result = self.cli("--test", self.group["cases"][0]["id"])
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.validate_report(result)["results"][0]["status"], "error")

    def test_input_parameters_compile_once_per_distinct_configuration(self):
        """Exige reutilizar el ejecutable para parámetros iguales y recompilar valores diferentes."""
        for value in (2, 2, 3):
            self.add_case(expected=2 * value + 3)
            self.group["cases"][-1]["inputs"]["a"] = value
        self.group["executions"][0]["parameters"] = {"OFFSET": {"input": "a"}}
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.validate_report(result)["summary"]["passed"], 3)
        self.assertEqual(result.stderr.count(f"Compilando {GROUP}: runner_smoke_tb"), 2)

    def test_parameter_bindings_require_existing_integer_inputs(self):
        """Rechaza referencias ausentes o no enteras antes de iniciar la compilación."""
        self.add_case()
        execution = self.group["executions"][0]
        execution["parameters"] = {"OFFSET": {"input": "missing"}}
        for value in [None, True, 1.5, "2"]:
            with self.subTest(value=value):
                self.group["cases"][0]["inputs"]["a"] = value
                execution["parameters"]["OFFSET"]["input"] = "a"
                result = self.cli()
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.validate_report(result)["results"], [])
                self.assertIn("requires integer input", result.stderr)
                self.assertNotIn("Compilando", result.stderr)
        execution["parameters"]["OFFSET"]["input"] = "missing"
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        self.assertIn("requires integer input", result.stderr)

    def test_unregistered_rejection_and_missing_expectation_are_not_passes(self):
        """Impide aprobar rechazos sin declaración o sin diagnóstico esperado válido."""
        self.add_case(mode="reject")
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.validate_report(result)["results"][0]["status"], "error")
        self.group["executions"][0]["expected_rejection"] = {
            "exit_code": 1,
            "diagnostic_key": "diagnostic",
        }
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.validate_report(result)["results"], [])
        self.assertIn("expected rejection diagnostic", result.stderr)

    def test_timeout_is_error_and_later_case_runs(self):
        """Exige un error por tiempo agotado y la continuación de los casos restantes."""
        self.add_case(mode="hang")
        self.add_case()
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["status"], "error")
        self.assertEqual([row["status"] for row in report["results"]], ["error", "passed"])
        self.assertIn("timeout_seconds=1", report["results"][0]["message"])

    def test_protocol_errors_are_not_passes_and_do_not_stop_the_selection(self):
        """Rechaza marcadores inconsistentes y permite continuar las demás simulaciones."""
        modes = [
            "silent",
            "wrong_id",
            "duplicate",
            "pass_nonzero",
            "fail_zero",
            "contradictory",
            "stderr_only",
            "no_reason",
        ]
        for mode in modes:
            self.add_case(mode=mode)
        self.add_case()
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["summary"], {"total": 9, "passed": 1, "failed": 0, "errors": 8})
        self.assertTrue(
            all(row["status"] == "error" and row["message"] for row in report["results"][:-1])
        )
        self.assertEqual(report["results"][-1]["status"], "passed")

    def test_compile_error_is_reported_for_each_case_and_next_execution_runs(self):
        """Asocia errores de compilación a los casos afectados y continúa con otros bancos."""
        self.add_case()
        self.add_case()
        broken = self.directory / "broken.sv"
        broken.write_text("module broken; initial begin THIS IS INVALID VERILOG; end endmodule\n")
        relative = os.path.relpath(broken, SCRIPTS.parent)
        self.group["executions"].insert(
            0,
            {
                "sources": [relative],
                "top": "broken",
                "level": "Unidad",
                "timeout_seconds": 1,
            },
        )
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["summary"], {"total": 4, "passed": 2, "failed": 0, "errors": 2})
        self.assertEqual(
            [row["status"] for row in report["results"]], ["error", "passed", "error", "passed"]
        )
        self.assertIn("falló la compilación", report["results"][0]["message"])
        self.assertEqual(result.stderr.count("Compilando TEST-SMOKE-001: broken"), 1)

    def test_compilation_respects_declared_source_order(self):
        """Verifica que los paquetes se compilen antes de sus consumidores según el manifiesto."""
        self.add_case()
        self.group["executions"][0]["sources"] = list(reversed(SOURCES))
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["results"][0]["status"], "error")
        self.assertIn("falló la compilación", report["results"][0]["message"])

    def test_text_report_contains_real_results_and_same_exit_semantics(self):
        """Contrasta el informe legible y su código de salida con los resultados reales."""
        case_id = self.add_case()
        result = self.cli(json_output=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"PASS {case_id} [runner_smoke_tb; Unidad]", result.stdout)
        self.assertIn("Total: 1 | PASS: 1 | FAIL: 0 | ERROR: 0", result.stdout)
        self.group["cases"][0]["expected"]["result"] = 6
        result = self.cli(json_output=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn(f"FAIL {case_id}", result.stdout)

    def test_simulation_does_not_accredit_a_board_level(self):
        """Rechaza niveles de verificación física antes de ejecutar una simulación."""
        self.add_case()
        self.group["executions"][0]["level"] = "Placa"
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["results"], [])
        self.assertIn("no corresponde a una simulación Icarus", result.stderr)

    def test_empty_results_cannot_be_reported_as_passed(self):
        """Impide generar una aprobación para una corrida sin resultados."""
        with self.assertRaisesRegex(ValueError, "ningún resultado"):
            result_report([])

    def test_timeout_terminates_a_tool_process_group(self):
        """Comprueba que el límite de tiempo termine también los procesos hijos de la herramienta."""
        marker = self.directory / "child-finished"
        child = (
            f"import time; from pathlib import Path; time.sleep(1); Path({str(marker)!r}).touch()"
        )
        parent = f"import subprocess, sys, time; subprocess.Popen([sys.executable, '-c', {child!r}]); time.sleep(10)"
        outcome = run_process(
            [sys.executable, "-c", parent],
            self.directory,
            self.directory / "stdout",
            self.directory / "stderr",
            timeout=0.2,
        )
        self.assertTrue(outcome.timed_out)
        # La espera posterior permite detectar si el proceso hijo sobrevivió al timeout.
        subprocess.run(
            [sys.executable, "-c", "import time; time.sleep(1.1)"], check=True, timeout=3
        )
        self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
