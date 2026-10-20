"""Validate selection semantics and the public shell/Python CLI."""

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import run_tests
from verification_manifest import MANIFEST, index_manifest


FIRST = "TEST-UNIT-001"
SECOND = "TEST-UNIT-002"
BOARD = "TEST-BOARD-001"


def group_fixture(group_id, count, **extra):
    return {
        "id": group_id, "source": "selection fixture", "case_count": count,
        "reuse_groups": [], "executions": [],
        "cases": [
            {"id": f"{group_id}/C{index:03}", "inputs": {"a": index},
             "expected": {"result": index}, "kind": "vector", "origins": ["selection fixture"]}
            for index in range(1, count + 1)
        ],
        **extra,
    }


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix="tp3 selection tests ")
        self.addCleanup(self.work.cleanup)
        self.directory = Path(self.work.name)
        self.manifest_path = self.directory / "manifest.json"
        self.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.manifest["groups"] = [
            group_fixture(FIRST, 3),
            group_fixture(SECOND, 1, reuse_groups=[FIRST]),
            group_fixture(BOARD, 0, reuse_groups=[FIRST], replay_cases=[f"{FIRST}/C002"]),
        ]

    def cli(self, *arguments):
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        return subprocess.run(
            ["bash", str(SCRIPTS / "run_tests.sh"), "--manifest", str(self.manifest_path), *arguments],
            cwd=self.directory, capture_output=True, text=True, timeout=15,
        )

    def pairs(self, selection):
        return [(entry.group_id, entry.case_id) for entry in selection]

    def test_mixed_selection_deduplicates_and_preserves_first_occurrence(self):
        selection = run_tests.select_cases(
            self.manifest, [f"{FIRST}/C003", FIRST, FIRST, f"{FIRST}/C003", SECOND]
        )
        self.assertEqual(self.pairs(selection), [
            (FIRST, f"{FIRST}/C003"), (FIRST, f"{FIRST}/C001"),
            (FIRST, f"{FIRST}/C002"), (SECOND, f"{SECOND}/C001"),
        ])

    def test_reuse_is_not_an_execution_dependency(self):
        selection = run_tests.select_cases(self.manifest, [SECOND])
        self.assertEqual(self.pairs(selection), [(SECOND, f"{SECOND}/C001")])

    def test_all_keeps_explicit_replays_in_their_context(self):
        selection = run_tests.select_cases(self.manifest, select_all=True)
        self.assertEqual(len(selection), 5)
        self.assertIn((FIRST, f"{FIRST}/C002"), self.pairs(selection))
        self.assertIn((BOARD, f"{FIRST}/C002"), self.pairs(selection))
        self.assertEqual(self.pairs(run_tests.select_cases(self.manifest, [BOARD, BOARD])),
                         [(BOARD, f"{FIRST}/C002")])

    def test_unknown_empty_and_conflicting_selections_fail(self):
        for selectors, select_all in [([], False), ([""], False), (["TEST-UNKNOWN-001"], False),
                                      ([f"{FIRST}/C999"], False), ([FIRST], True)]:
            with self.subTest(selectors=selectors, select_all=select_all):
                with self.assertRaises(ValueError):
                    run_tests.select_cases(self.manifest, selectors, select_all)
        self.manifest["groups"].append(group_fixture("TEST-EMPTY-001", 0))
        with self.assertRaisesRegex(ValueError, "no contiene casos"):
            run_tests.select_cases(self.manifest, ["TEST-EMPTY-001"])

    def test_catalogue_relationship_errors_are_rejected(self):
        for problem in ["group-id", "case-id", "count", "owner", "reuse", "replay"]:
            manifest = copy.deepcopy(self.manifest)
            group = manifest["groups"][0]
            if problem == "group-id":
                manifest["groups"].append(copy.deepcopy(group))
            elif problem == "case-id":
                group["cases"][1]["id"] = group["cases"][0]["id"]
            elif problem == "count":
                group["case_count"] = 9
            elif problem == "owner":
                group["cases"][0]["id"] = "TEST-OTHER-001/C001"
            elif problem == "reuse":
                group["reuse_groups"] = ["TEST-UNKNOWN-001"]
            else:
                group["replay_cases"] = [f"{FIRST}/C999"]
            with self.subTest(problem=problem):
                with self.assertRaises(ValueError):
                    index_manifest(manifest)

    def test_cli_lists_selection_as_json_from_another_directory(self):
        result = self.cli("--test", FIRST, "--test", f"{FIRST}/C001", "--test", SECOND,
                          "--list", "--format", "json")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual(len(rows), 4)
        self.assertEqual(rows[0], {"group_id": FIRST, "case_id": f"{FIRST}/C001", "execution_count": 0})
        self.assertEqual(result.stderr, "")

    def test_cli_text_and_help_do_not_claim_execution(self):
        result = self.cli("--test", FIRST, "--list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Sin ejecutar", result.stdout)
        self.assertNotIn("PASS ", result.stdout)
        self.assertNotIn("FAIL ", result.stdout)
        self.manifest_path.unlink()
        help_result = subprocess.run(
            ["bash", str(SCRIPTS / "run_tests.sh"), "--manifest", str(self.manifest_path), "--help"],
            capture_output=True, text=True, timeout=5,
        )
        self.assertEqual(help_result.returncode, 0)
        for flag in ["--test", "--all", "--list", "--format", "--manifest"]:
            self.assertIn(flag, help_result.stdout)

    def test_cli_argument_errors_produce_nonzero_and_json(self):
        for arguments in [[], ["--all", "--test", FIRST], ["--test"], ["--issue", "3"],
                          ["--al"], ["--test", FIRST, "--unknown"]]:
            with self.subTest(arguments=arguments):
                result = self.cli(*arguments, "--format", "json")
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(json.loads(result.stdout)["status"], "error")
                self.assertIn("ERROR:", result.stderr)

    def test_cli_unknown_id_has_no_partial_selection(self):
        result = self.cli("--test", FIRST, "--test", "TEST-UNKNOWN-001", "--list", "--format", "json")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout), [])
        self.assertIn("desconocido", result.stderr)

    def test_cli_missing_executions_is_a_global_error_not_a_pass(self):
        result = self.cli("--test", FIRST, "--format", "json")
        self.assertEqual(result.returncode, 1)
        report = json.loads(result.stdout)
        self.assertEqual(report, {
            "status": "error", "summary": {"total": 0, "passed": 0, "failed": 0, "errors": 0},
            "results": [],
        })
        self.assertIn("sin ejecuciones registradas", result.stderr)
        output = self.directory / "results.json"
        output.write_text(result.stdout)
        validation = subprocess.run(
            ["check-jsonschema", "--schemafile", str(SCRIPTS.parent / "docs/verification/results.schema.json"),
             str(output)], capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(validation.returncode, 0, validation.stdout + validation.stderr)

    def test_source_checks_and_registered_selection_requires_explicit_results(self):
        execution = {"sources": ["tb/common/case_data.sv"], "top": "tp3_case_data",
                     "level": "Unidad", "timeout_seconds": 1}
        self.manifest["groups"][0]["executions"] = [execution]
        result = self.cli("--test", FIRST, "--format", "json")
        self.assertEqual(result.returncode, 1)
        report = json.loads(result.stdout)
        self.assertEqual(report["summary"], {"total": 3, "passed": 0, "failed": 0, "errors": 3})
        self.assertTrue(all("sin resultado explícito" in row["message"] for row in report["results"]))
        execution["sources"] = ["tb/does-not-exist.sv"]
        result = self.cli("--test", FIRST)
        self.assertEqual(result.returncode, 1)
        self.assertIn("fuente inexistente", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_invalid_schema_and_duplicate_json_keys_have_clear_errors(self):
        self.manifest["groups"][0]["case_count"] = "invalid"
        result = self.cli("--all", "--list", "--format", "json")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout), [])
        self.assertIn("manifest validation failed", result.stderr)
        self.manifest["groups"][0]["case_count"] = 3
        text = json.dumps(self.manifest).replace('"scope":', '"scope": "duplicate", "scope":', 1)
        self.manifest_path.write_text(text)
        result = subprocess.run(
            ["bash", str(SCRIPTS / "run_tests.sh"), "--manifest", str(self.manifest_path),
             "--all", "--list", "--format", "json"], capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("duplicate JSON key", result.stderr)
        self.assertEqual(json.loads(result.stdout), [])

    def test_real_catalogue_selection_preserves_canonical_and_replay_counts(self):
        result = self.cli("--manifest", str(MANIFEST), "--all", "--list", "--format", "json")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual(len(rows), 1357 + 151)
        self.assertEqual(len({row["case_id"] for row in rows}), 1357)
        self.assertEqual(len({(row["group_id"], row["case_id"]) for row in rows}), 1508)
        self.assertTrue(all(row["execution_count"] == 0 for row in rows))


if __name__ == "__main__":
    unittest.main()
