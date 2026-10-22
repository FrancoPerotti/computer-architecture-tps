"""Exercise JSON-to-SystemVerilog transport with the actual simulator."""

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# Permite importar las herramientas al descubrir pruebas desde otro directorio.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_case

# Ruta de las herramientas que se prueban, independiente del directorio de ejecución.
SCRIPTS = Path(__file__).resolve().parents[1]

# Raíz del proyecto e identificador del caso sintético de transporte de datos.
ROOT = SCRIPTS.parent
CASE_ID = "TEST-DATA-001/C001"


def decode_data(content):
    """Reconstruye JSON desde los registros para contrastar la exportación de forma independiente."""
    lines = content.splitlines()
    header, count = lines[0].split()
    assert header == "TP3_CASE_DATA" and int(count) == len(lines) - 1
    entries = {}
    children = {}
    for line in lines[1:]:
        path, kind, text = line.split()
        path = "" if path == "-" else bytes.fromhex(path).decode("utf-8")
        text = "" if text == "-" else bytes.fromhex(text).decode("utf-8")
        assert path not in entries
        entries[path] = kind, text
        if path:
            parent, token = path.rsplit("/", 1)
            children.setdefault(parent, []).append(token)

    def node(path):
        """Reconstruye el valor de una ruta y sus descendientes según los tipos registrados."""
        kind, text = entries[path]
        if kind == "object":
            tokens = children.get(path, [])
            assert len(tokens) == int(text)
            return {
                token.replace("~1", "/").replace("~0", "~"): node(f"{path}/{token}")
                for token in tokens
            }
        if kind == "array":
            return [node(f"{path}/{index}") for index in range(int(text))]
        if kind == "string":
            return text
        if kind == "null":
            assert text == ""
            return None
        return json.loads(text)

    return node("")


class CaseDataTests(unittest.TestCase):
    """Comprueba el transporte de datos y sus errores con el simulador real."""

    @classmethod
    def setUpClass(cls):
        """Compila una vez el banco del lector y prepara el directorio temporal de la clase."""
        cls.work = tempfile.TemporaryDirectory(prefix="tp3-case-data-tests-")
        cls.directory = Path(cls.work.name)
        cls.binary = cls.directory / "case_data.vvp"
        compilation = subprocess.run(
            [
                "iverilog",
                "-g2012",
                "-s",
                "case_data_tb",
                "-o",
                str(cls.binary),
                str(ROOT / "tb/common/tp3_case_data.sv"),
                str(SCRIPTS / "tests/fixtures/case_data_tb.sv"),
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if compilation.returncode:
            raise AssertionError(compilation.stdout + compilation.stderr)
        cls.manifest = json.loads(prepare_case.MANIFEST.read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls):
        """Elimina el ejecutable y los datos temporales al terminar la clase."""
        cls.work.cleanup()

    def setUp(self):
        """Prepara un caso sintético independiente con los tipos y límites que debe transportar el lector."""
        self.output = self.directory / "case.data"
        self.output.unlink(missing_ok=True)
        self.fixture = copy.deepcopy(self.manifest)
        self.fixture["groups"] = [
            {
                "id": "TEST-DATA-001",
                "source": "transport fixture",
                "case_count": 1,
                "reuse_groups": [],
                "executions": [],
                "cases": [
                    {
                        "id": CASE_ID,
                        "status": "pending",
                        "kind": "vector",
                        "origins": ["transport fixture"],
                        "inputs": {
                            "a": 2,
                            "b": 3,
                            "minimum": -(2**63),
                            "maximum": 2**63 - 1,
                            "overflow": 2**63,
                            "enabled": True,
                            "disabled": False,
                            "label": 'Español\ncon espacios\ty comillas "',
                            "empty": "",
                            "a/b": {"~key": "00xZ"},
                            "items": [-7, [], {}],
                        },
                        "expected": {"result": 5, "nothing": None, "ratio": 1.25},
                    }
                ],
            }
        ]
        self.fixture_path = self.directory / "manifest.json"

    def prepare(self, case_id=CASE_ID):
        """Escribe el manifiesto temporal y solicita la exportación de un caso por la CLI."""
        self.fixture_path.write_text(json.dumps(self.fixture), encoding="utf-8")
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "prepare_case.py"),
                "--manifest",
                str(self.fixture_path),
                "--case",
                case_id,
                "--output",
                str(self.output),
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )

    def simulate(self, case_id=CASE_ID, probe="normal", include_data=True):
        """Ejecuta el lector con el caso y la variante de comprobación solicitados."""
        command = ["vvp", str(self.binary), f"+CASE={case_id}", f"+PROBE={probe}"]
        if include_data:
            command.append(f"+CASE_DATA={self.output}")
        return subprocess.run(command, capture_output=True, text=True, timeout=10)

    def test_external_data_and_assertions(self):
        """Comprueba que cambiar la expectativa del JSON cambie el resultado de la aserción HDL."""
        preparation = self.prepare()
        self.assertEqual(preparation.returncode, 0, preparation.stderr)
        result = self.simulate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"CASE_DATA_OK {CASE_ID}", result.stdout)

        # Cambiar solo la expectativa del JSON debe modificar el resultado de la simulación.
        self.fixture["groups"][0]["cases"][0]["expected"]["result"] = 6
        preparation = self.prepare()
        self.assertEqual(preparation.returncode, 0, preparation.stderr)
        result = self.simulate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("result does not match JSON expectation", result.stdout)

    def test_all_canonical_cases_round_trip(self):
        """Exige que cada caso del catálogo conserve íntegros sus datos al exportarse y reconstruirse."""
        for group in self.manifest["groups"]:
            for case in group["cases"]:
                with self.subTest(case=case["id"]):
                    data = {
                        "id": case["id"],
                        "inputs": case["inputs"],
                        "expected": case["expected"],
                        "latch_fixture": self.manifest["latch_fixture"],
                    }
                    restored = decode_data(prepare_case.serialize(data))
                    self.assertEqual(
                        json.dumps(restored, sort_keys=True), json.dumps(data, sort_keys=True)
                    )

    def test_missing_wrong_type_and_out_of_range_values_fail(self):
        """Exige fallos explícitos para rutas ausentes, tipos incompatibles y enteros fuera de rango."""
        preparation = self.prepare()
        self.assertEqual(preparation.returncode, 0, preparation.stderr)
        for probe, diagnostic in [
            ("missing", "missing path"),
            ("wrong_type", "expected integer"),
            ("overflow", "exceeds signed 64-bit range"),
        ]:
            with self.subTest(probe=probe):
                result = self.simulate(probe=probe)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stdout)

    def test_missing_file_argument_and_mismatched_case_fail(self):
        """Rechaza argumentos ausentes, archivos inexistentes e IDs que no corresponden a los datos."""
        preparation = self.prepare()
        self.assertEqual(preparation.returncode, 0, preparation.stderr)
        result = self.simulate(include_data=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing +CASE_DATA", result.stdout)
        result = subprocess.run(
            ["vvp", str(self.binary), f"+CASE_DATA={self.output}"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing +CASE=", result.stdout)
        result = self.simulate(case_id="TEST-DATA-001/C002")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match case", result.stdout)
        self.output.unlink()
        result = self.simulate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot open", result.stdout)

    def test_corrupt_files_fail(self):
        """Comprueba que archivos truncados o corruptos no se acepten como lecturas correctas."""
        preparation = self.prepare()
        self.assertEqual(preparation.returncode, 0, preparation.stderr)
        valid = self.output.read_text()
        lines = valid.splitlines(keepends=True)
        invalid_hex = lines.copy()
        invalid_hex[1] = "z1 object 34\n"
        nul_value = lines.copy()
        nul_value[1] = "- object 00\n"
        duplicate = lines.copy()
        duplicate[-1] = duplicate[1]
        unknown_type = valid.replace(" object ", " unknown ", 1)
        for label, content in [
            ("truncated", "".join(lines[:-1])),
            ("trailing", valid + "unexpected\n"),
            ("hex", "".join(invalid_hex)),
            ("nul", "".join(nul_value)),
            ("duplicate", "".join(duplicate)),
            ("type", unknown_type),
            ("count", "TP3_CASE_DATA 65537\n"),
        ]:
            with self.subTest(corruption=label):
                self.output.write_text(content)
                result = self.simulate()
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn(f"CASE_DATA_OK {CASE_ID}", result.stdout)

    def test_invalid_manifest_and_unknown_case_preserve_output(self):
        """Exige que una preparación fallida conserve el archivo de salida anterior."""
        self.output.write_text("previous output")
        self.fixture["groups"][0]["case_count"] = "invalid"
        preparation = self.prepare()
        self.assertNotEqual(preparation.returncode, 0)
        self.assertIn("manifest validation failed", preparation.stderr)
        self.assertEqual(self.output.read_text(), "previous output")
        self.fixture["groups"][0]["case_count"] = 1
        preparation = self.prepare("TEST-DATA-001/C999")
        self.assertNotEqual(preparation.returncode, 0)
        self.assertIn("found 0", preparation.stderr)
        self.assertEqual(self.output.read_text(), "previous output")

    def test_unsupported_text_and_numbers_are_not_silently_changed(self):
        """Rechaza texto no representable y números no finitos sin sustituirlos silenciosamente."""
        for value in ["contains\0NUL", "\ud800", float("nan"), float("inf")]:
            with self.subTest(value=repr(value)):
                with self.assertRaises(ValueError):
                    prepare_case.serialize({"value": value})


if __name__ == "__main__":
    unittest.main()
