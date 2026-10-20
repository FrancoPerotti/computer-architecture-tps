"""Permanent smoke/regression tests using real Icarus and temporary artefacts."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
from simulation_runner import result_report, run_process
from verification_manifest import MANIFEST


GROUP = "TEST-SMOKE-001"
SOURCES = ["scripts/tests/fixtures/runner_smoke_pkg.sv", "tb/common/case_data.sv",
           "scripts/tests/fixtures/runner_smoke_tb.sv"]


class SimulationRunnerTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix="tp3 runner smoke ")
        self.addCleanup(self.work.cleanup)
        self.directory = Path(self.work.name)
        self.manifest_path = self.directory / "manifest.json"
        self.scratch = self.directory / "scratch"
        self.scratch.mkdir()
        self.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.group = {
            "id": GROUP, "source": "runner smoke fixture", "case_count": 0,
            "reuse_groups": [], "executions": [{
                "sources": SOURCES.copy(), "top": "runner_smoke_tb",
                "level": "Unidad", "timeout_seconds": 1,
            }], "cases": [],
        }
        self.manifest["groups"] = [self.group]

    def add_case(self, mode="sum", expected=5):
        case_id = f"{GROUP}/C{len(self.group['cases']) + 1:03}"
        self.group["cases"].append({
            "id": case_id, "inputs": {"a": 2, "b": 3, "mode": mode},
            "expected": {"result": expected}, "kind": "vector", "origins": ["runner smoke fixture"],
        })
        self.group["case_count"] = len(self.group["cases"])
        return case_id

    def cli(self, *arguments, json_output=True, env_extra=None):
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        environment = {**os.environ, "TMPDIR": str(self.scratch), **(env_extra or {})}
        command = ["bash", str(SCRIPTS / "run_tests.sh"), "--manifest", str(self.manifest_path)]
        command.extend(arguments or ["--all"])
        if json_output:
            command.extend(["--format", "json"])
        result = subprocess.run(command, cwd=self.directory, env=environment,
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(list(self.scratch.iterdir()), [], "runner left temporary artefacts")
        return result

    def validate_report(self, result):
        report = json.loads(result.stdout)
        path = self.directory / "results.json"
        path.write_text(result.stdout, encoding="utf-8")
        validation = subprocess.run(
            ["check-jsonschema", "--schemafile", str(SCRIPTS.parent / "docs/verification/results.schema.json"),
             str(path)], capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(validation.returncode, 0, validation.stdout + validation.stderr)
        summary = report["summary"]
        self.assertEqual(summary["total"], len(report["results"]))
        self.assertEqual(summary["total"], summary["passed"] + summary["failed"] + summary["errors"])
        return report

    def test_smoke_success_compiles_once_and_deduplicates_selection(self):
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
        result = self.cli("--test", GROUP, "--test", first,
                          env_extra={"PATH": f"{wrapper_dir}{os.pathsep}{os.environ['PATH']}"})
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.validate_report(result)
        self.assertEqual(report["summary"], {"total": 2, "passed": 2, "failed": 0, "errors": 0})
        self.assertEqual(report["status"], "passed")
        self.assertTrue(all(row["message"] is None for row in report["results"]))
        calls = [json.loads(line) for line in counter.read_text().splitlines()]
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][-3:], [str(SCRIPTS.parent / path) for path in SOURCES])
        self.assertIn("Simulando", result.stderr)

    def test_json_assertion_failure_is_failed_and_later_case_runs(self):
        self.add_case(expected=6)
        self.add_case(expected=5)
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["status"], "failed")
        self.assertEqual([row["status"] for row in report["results"]], ["failed", "passed"])
        self.assertIn("expected 6, observed 5", report["results"][0]["message"])

    def test_timeout_is_error_and_later_case_runs(self):
        self.add_case(mode="hang")
        self.add_case()
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["status"], "error")
        self.assertEqual([row["status"] for row in report["results"]], ["error", "passed"])
        self.assertIn("timeout_seconds=1", report["results"][0]["message"])

    def test_protocol_errors_are_not_passes_and_do_not_stop_the_selection(self):
        modes = ["silent", "wrong_id", "duplicate", "pass_nonzero", "fail_zero",
                 "contradictory", "stderr_only", "no_reason"]
        for mode in modes:
            self.add_case(mode=mode)
        self.add_case()
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["summary"], {"total": 9, "passed": 1, "failed": 0, "errors": 8})
        self.assertTrue(all(row["status"] == "error" and row["message"] for row in report["results"][:-1]))
        self.assertEqual(report["results"][-1]["status"], "passed")

    def test_compile_error_is_reported_for_each_case_and_next_execution_runs(self):
        self.add_case()
        self.add_case()
        broken = self.directory / "broken.sv"
        broken.write_text("module broken; initial begin THIS IS INVALID VERILOG; end endmodule\n")
        relative = os.path.relpath(broken, SCRIPTS.parent)
        self.group["executions"].insert(0, {
            "sources": [relative], "top": "broken", "level": "Unidad", "timeout_seconds": 1,
        })
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["summary"], {"total": 4, "passed": 2, "failed": 0, "errors": 2})
        self.assertEqual([row["status"] for row in report["results"]], ["error", "passed", "error", "passed"])
        self.assertIn("falló la compilación", report["results"][0]["message"])
        self.assertEqual(result.stderr.count("Compilando TEST-SMOKE-001: broken"), 1)

    def test_compilation_respects_declared_source_order(self):
        self.add_case()
        self.group["executions"][0]["sources"] = list(reversed(SOURCES))
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["results"][0]["status"], "error")
        self.assertIn("falló la compilación", report["results"][0]["message"])

    def test_text_report_contains_real_results_and_same_exit_semantics(self):
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
        self.add_case()
        self.group["executions"][0]["level"] = "Placa"
        result = self.cli()
        self.assertEqual(result.returncode, 1)
        report = self.validate_report(result)
        self.assertEqual(report["results"], [])
        self.assertIn("no corresponde a una simulación Icarus", result.stderr)

    def test_empty_results_cannot_be_reported_as_passed(self):
        with self.assertRaisesRegex(ValueError, "ningún resultado"):
            result_report([])

    def test_timeout_terminates_a_tool_process_group(self):
        marker = self.directory / "child-finished"
        child = f"import time; from pathlib import Path; time.sleep(1); Path({str(marker)!r}).touch()"
        parent = f"import subprocess, sys, time; subprocess.Popen([sys.executable, '-c', {child!r}]); time.sleep(10)"
        outcome = run_process(
            [sys.executable, "-c", parent], self.directory,
            self.directory / "stdout", self.directory / "stderr", timeout=0.2,
        )
        self.assertTrue(outcome.timed_out)
        # A subsequent process waits long enough to detect a surviving child.
        subprocess.run([sys.executable, "-c", "import time; time.sleep(1.1)"], check=True, timeout=3)
        self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
