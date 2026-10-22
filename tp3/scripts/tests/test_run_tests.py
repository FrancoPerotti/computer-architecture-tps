"""Validate selection semantics and the public shell/Python CLI."""

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# Permite importar las herramientas al descubrir pruebas desde otro directorio.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_tests
from verification_manifest import MANIFEST, index_manifest

# Ruta de las herramientas que se prueban, independiente del directorio de ejecución.
SCRIPTS = Path(__file__).resolve().parents[1]

# Grupos sintéticos para distinguir selección canónica, reutilización y reejecución.
FIRST = "TEST-UNIT-001"
SECOND = "TEST-UNIT-002"
BOARD = "TEST-BOARD-001"


def group_fixture(group_id, count, **extra):
    """Construye un grupo sintético con casos mínimos y permite añadir relaciones de selección."""
    return {
        "id": group_id,
        "source": "selection fixture",
        "case_count": count,
        "reuse_groups": [],
        "executions": [],
        "cases": [
            {
                "id": f"{group_id}/C{index:03}",
                "status": "pending",
                "inputs": {"a": index},
                "expected": {"result": index},
                "kind": "vector",
                "origins": ["selection fixture"],
            }
            for index in range(1, count + 1)
        ],
        **extra,
    }


class SelectionTests(unittest.TestCase):
    """Comprueba la selección y los errores públicos de la CLI sin atribuir resultados al hardware."""

    def setUp(self):
        """Prepara grupos temporales independientes con reutilización documental y reejecuciones."""
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
        """Escribe el manifiesto temporal y ejecuta la CLI desde otro directorio."""
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        return subprocess.run(
            [
                "bash",
                str(SCRIPTS / "run_tests.sh"),
                "--manifest",
                str(self.manifest_path),
                *arguments,
            ],
            cwd=self.directory,
            capture_output=True,
            text=True,
            timeout=15,
        )

    def pairs(self, selection):
        """Reduce la selección a pares de grupo y caso para comparar orden y contexto."""
        return [(entry.group_id, entry.case_id) for entry in selection]

    def test_mixed_selection_deduplicates_and_preserves_first_occurrence(self):
        """Exige una sola aparición por contexto y respeta el orden del primer selector."""
        selection = run_tests.select_cases(
            self.manifest, [f"{FIRST}/C003", FIRST, FIRST, f"{FIRST}/C003", SECOND]
        )
        self.assertEqual(
            self.pairs(selection),
            [
                (FIRST, f"{FIRST}/C003"),
                (FIRST, f"{FIRST}/C001"),
                (FIRST, f"{FIRST}/C002"),
                (SECOND, f"{SECOND}/C001"),
            ],
        )

    def test_reuse_is_not_an_execution_dependency(self):
        """Comprueba que las relaciones documentales no agreguen ejecuciones implícitas."""
        selection = run_tests.select_cases(self.manifest, [SECOND])
        self.assertEqual(self.pairs(selection), [(SECOND, f"{SECOND}/C001")])

    def test_all_does_not_expand_physical_references(self):
        """Conserva referencias físicas documentales sin generar simulaciones adicionales."""
        selection = run_tests.select_cases(self.manifest, select_all=True)
        self.assertEqual(len(selection), 4)
        self.assertNotIn(BOARD, [entry.group_id for entry in selection])
        self.assertEqual(run_tests.select_cases(self.manifest, [BOARD]), [])

    def test_unknown_empty_and_conflicting_selections_fail(self):
        """Rechaza selecciones vacías, desconocidas o incompatibles."""
        for selectors, select_all in [
            ([], False),
            ([""], False),
            (["TEST-UNKNOWN-001"], False),
            ([f"{FIRST}/C999"], False),
            ([FIRST], True),
        ]:
            with self.subTest(selectors=selectors, select_all=select_all):
                with self.assertRaises(ValueError):
                    run_tests.select_cases(self.manifest, selectors, select_all)
        self.manifest["groups"].append(group_fixture("TEST-EMPTY-001", 0))
        self.assertEqual(run_tests.select_cases(self.manifest, ["TEST-EMPTY-001"]), [])

    def test_catalogue_relationship_errors_are_rejected(self):
        """Detecta duplicados, recuentos incorrectos y referencias ajenas o inexistentes."""
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
        """Verifica el listado JSON y la resolución de rutas desde fuera del proyecto."""
        result = self.cli(
            "--test",
            FIRST,
            "--test",
            f"{FIRST}/C001",
            "--test",
            SECOND,
            "--list",
            "--format",
            "json",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual(len(rows), 4)
        self.assertEqual(
            rows[0],
            {
                "group_id": FIRST,
                "case_id": f"{FIRST}/C001",
                "execution_count": 0,
                "status": "pending",
            },
        )
        self.assertEqual(result.stderr, "")

    def test_cli_text_and_help_do_not_claim_execution(self):
        """Exige que el listado y la ayuda no presenten consultas como pruebas ejecutadas."""
        result = self.cli("--test", FIRST, "--list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Sin ejecutar", result.stdout)
        self.assertNotIn("PASS ", result.stdout)
        self.assertNotIn("FAIL ", result.stdout)
        self.manifest_path.unlink()
        help_result = subprocess.run(
            [
                "bash",
                str(SCRIPTS / "run_tests.sh"),
                "--manifest",
                str(self.manifest_path),
                "--help",
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        self.assertEqual(help_result.returncode, 0)
        for flag in ["--test", "--all", "--list", "--format", "--manifest"]:
            self.assertIn(flag, help_result.stdout)

    def test_cli_argument_errors_produce_nonzero_and_json(self):
        """Comprueba el código de uso inválido y la estructura de error para argumentos incorrectos."""
        for arguments in [
            [],
            ["--all", "--test", FIRST],
            ["--test"],
            ["--issue", "3"],
            ["--al"],
            ["--test", FIRST, "--unknown"],
        ]:
            with self.subTest(arguments=arguments):
                result = self.cli(*arguments, "--format", "json")
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(json.loads(result.stdout)["status"], "error")
                self.assertIn("ERROR:", result.stderr)

    def test_cli_unknown_id_has_no_partial_selection(self):
        """Exige que un selector desconocido invalide el listado completo."""
        result = self.cli(
            "--test", FIRST, "--test", "TEST-UNKNOWN-001", "--list", "--format", "json"
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout), [])
        self.assertIn("desconocido", result.stderr)

    def test_cli_missing_executions_is_a_global_error_not_a_pass(self):
        """Exige un error global sin aprobaciones cuando los casos no tienen bancos registrados."""
        self.manifest["groups"][0]["cases"][0]["status"] = "implemented"
        result = self.cli("--test", FIRST, "--format", "json")
        self.assertEqual(result.returncode, 1)
        report = json.loads(result.stdout)
        self.assertEqual(
            report,
            {
                "status": "error",
                "summary": {"total": 0, "passed": 0, "failed": 0, "errors": 0},
                "results": [],
                "pending_cases": [],
            },
        )
        self.assertIn("sin ejecuciones registradas", result.stderr)
        output = self.directory / "results.json"
        output.write_text(result.stdout)
        validation = subprocess.run(
            [
                "check-jsonschema",
                "--schemafile",
                str(SCRIPTS.parent / "docs/verification/results.schema.json"),
                str(output),
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(validation.returncode, 0, validation.stdout + validation.stderr)

    def test_source_checks_and_registered_selection_requires_explicit_results(self):
        """Comprueba fuentes existentes y exige un marcador de resultado explícito de la simulación."""
        execution = {
            "sources": ["tb/common/tp3_case_data.sv"],
            "top": "tp3_case_data",
            "level": "Unidad",
            "timeout_seconds": 1,
        }
        self.manifest["groups"][0]["executions"] = [execution]
        for case in self.manifest["groups"][0]["cases"]:
            case["status"] = "implemented"
        result = self.cli("--test", FIRST, "--format", "json")
        self.assertEqual(result.returncode, 1)
        report = json.loads(result.stdout)
        self.assertEqual(report["summary"], {"total": 3, "passed": 0, "failed": 0, "errors": 3})
        self.assertTrue(
            all("sin resultado explícito" in row["message"] for row in report["results"])
        )
        execution["sources"] = ["tb/does-not-exist.sv"]
        result = self.cli("--test", FIRST)
        self.assertEqual(result.returncode, 1)
        self.assertIn("fuente inexistente", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_invalid_schema_and_duplicate_json_keys_have_clear_errors(self):
        """Exige diagnósticos claros para manifiestos inválidos y claves JSON repetidas."""
        self.manifest["groups"][0]["case_count"] = "invalid"
        result = self.cli("--all", "--list", "--format", "json")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout), [])
        self.assertIn("manifest validation failed", result.stderr)
        self.manifest["groups"][0]["case_count"] = 3
        text = json.dumps(self.manifest).replace('"scope":', '"scope": "duplicate", "scope":', 1)
        self.manifest_path.write_text(text)
        result = subprocess.run(
            [
                "bash",
                str(SCRIPTS / "run_tests.sh"),
                "--manifest",
                str(self.manifest_path),
                "--all",
                "--list",
                "--format",
                "json",
            ],
            capture_output=True,
            text=True,
            timeout=15,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("duplicate JSON key", result.stderr)
        self.assertEqual(json.loads(result.stdout), [])

    def test_real_catalogue_selection_preserves_canonical_counts(self):
        """Contrasta el listado completo con los casos y contextos declarados en el catálogo."""
        result = self.cli("--manifest", str(MANIFEST), "--all", "--list", "--format", "json")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        catalogue = json.loads(MANIFEST.read_text(encoding="utf-8"))
        canonical_ids = {case["id"] for group in catalogue["groups"] for case in group["cases"]}
        self.assertEqual(len(rows), len(canonical_ids))
        self.assertEqual({row["case_id"] for row in rows}, canonical_ids)
        self.assertEqual(len({(row["group_id"], row["case_id"]) for row in rows}), len(rows))

    def test_execution_case_references_and_parameter_structure_are_validated(self):
        """Rechaza bancos asociados a casos ajenos y parámetros con estructura o sintaxis inválida."""
        execution = {
            "sources": ["tb/common/tp3_case_data.sv"],
            "top": "tp3_case_data",
            "level": "Unidad",
            "timeout_seconds": 1,
            "case_ids": [f"{SECOND}/C001"],
        }
        self.manifest["groups"][0]["executions"] = [execution]
        result = self.cli("--test", FIRST, "--list")
        self.assertEqual(result.returncode, 1)
        self.assertIn("outside", result.stderr)
        execution["case_ids"] = [f"{FIRST}/C001"]
        for parameters in [{"BAD)": "1"}, {"GOOD": "1); $finish;"}]:
            with self.subTest(parameters=parameters):
                execution["parameters"] = parameters
                result = self.cli("--test", FIRST, "--list")
                self.assertEqual(result.returncode, 1)
                self.assertIn("manifest validation failed", result.stderr)

    def test_pending_case_and_empty_execution_are_errors_but_listing_is_valid(self):
        """Distingue consulta, selección sin implementadas y pedido explícito pendiente."""
        for arguments, diagnostic in [
            (["--all"], "no contiene pruebas implementadas"),
            (["--test", f"{FIRST}/C001"], "pendiente"),
            (["--test", BOARD], "no contiene pruebas implementadas"),
        ]:
            with self.subTest(arguments=arguments):
                result = self.cli(*arguments, "--format", "json")
                self.assertEqual(result.returncode, 1)
                self.assertIn(diagnostic, result.stderr)
                self.assertEqual(json.loads(result.stdout)["results"], [])
        self.assertEqual(self.cli("--all", "--list").returncode, 0)

    def test_validate_accepts_pending_and_checks_every_implemented_source(self):
        """Valida sin simular; una implementación registrada incompleta siempre es un error."""
        self.assertEqual(self.cli("--validate").returncode, 0)
        case = self.manifest["groups"][0]["cases"][0]
        case["status"] = "implemented"
        result = self.cli("--validate")
        self.assertEqual(result.returncode, 1)
        self.assertIn("sin ejecuciones registradas", result.stderr)
        self.manifest["groups"][0]["executions"] = [
            {
                "sources": ["missing.sv"],
                "top": "missing",
                "level": "Unidad",
                "timeout_seconds": 1,
                "case_ids": [case["id"]],
            }
        ]
        result = self.cli("--validate")
        self.assertEqual(result.returncode, 1)
        self.assertIn("fuente inexistente", result.stderr)
        self.assertNotIn("Compilando", result.stderr)

    def test_status_is_required_and_restricted(self):
        """El esquema rechaza omisiones y estados ajenos al contrato de implementación."""
        case = self.manifest["groups"][0]["cases"][0]
        for status in (None, "passed", "disabled"):
            with self.subTest(status=status):
                case.pop("status", None)
                if status is not None:
                    case["status"] = status
                result = self.cli("--validate")
                self.assertEqual(result.returncode, 1)
                self.assertIn("manifest validation failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
