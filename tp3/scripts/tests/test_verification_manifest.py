"""Check catalogue file resolution, validation and source-file protection."""

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verification_manifest import load_manifest, manifest_sources, read_manifest

SCRIPTS = Path(__file__).resolve().parents[1]


class ManifestFilesTests(unittest.TestCase):
    """Comprueba referencias de archivos con catálogos pequeños y expectativas independientes."""

    def setUp(self):
        """Prepara un catálogo sintético con metadatos comunes y dos casos distintos."""
        self.work = tempfile.TemporaryDirectory(prefix="tp3 catalogue files ")
        self.addCleanup(self.work.cleanup)
        self.directory = Path(self.work.name)
        self.path = self.directory / "index.json"
        self.manifest = {key: value for key, value in read_manifest().items() if key != "groups"}
        self.group = {
            "id": "TEST-FILES-001",
            "source": "file resolution fixture",
            "case_count": 2,
            "reuse_groups": [],
            "executions": [],
            "cases": [
                {
                    "id": f"TEST-FILES-001/C{index:03}",
                    "status": "pending",
                    "kind": "vector",
                    "origins": ["file resolution fixture"],
                    "inputs": {"value": index, "file": "ordinary input data.json"},
                    "expected": {"value": index + 5},
                }
                for index in [1, 2]
            ],
        }
        self.manifest["groups"] = [copy.deepcopy(self.group)]

    def write(self, relative, value):
        """Escribe JSON en un archivo temporal y devuelve su ruta."""
        path = self.directory / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def split(self):
        """Distribuye el fixture entre índice, grupo y dos listas de casos."""
        group = copy.deepcopy(self.group)
        group["cases"] = [
            {"file": "vectors/first.json"},
            {"file": "vectors/second.json"},
        ]
        self.write("groups/vectors/first.json", [self.group["cases"][0]])
        self.write("groups/vectors/second.json", [self.group["cases"][1]])
        self.write("groups/group.json", group)
        index = {**self.manifest, "groups": [{"file": "groups/group.json"}]}
        self.write("index.json", index)

    def test_split_and_inline_catalogues_are_identical(self):
        """Conserva todos los valores y el orden, y no interpreta file dentro de inputs."""
        self.split()
        self.assertEqual(read_manifest(self.path), self.manifest)
        self.assertEqual(load_manifest(self.path), self.manifest)
        inline = self.write("inline.json", self.manifest)
        self.assertEqual(load_manifest(inline), self.manifest)

    def test_mixed_inline_cases_and_nested_case_files_keep_order(self):
        """Permite listas parciales con referencias anidadas y casos inline."""
        self.split()
        self.write("groups/vectors/first.json", [{"file": "nested.json"}])
        self.write("groups/vectors/nested.json", [self.group["cases"][0]])
        group = {**self.group, "cases": [{"file": "vectors/first.json"}, self.group["cases"][1]]}
        self.write("groups/group.json", group)
        self.assertEqual(read_manifest(self.path), self.manifest)

    def test_all_source_files_are_reported_from_another_directory(self):
        """Resuelve cada referencia desde su archivo, independientemente del cwd."""
        self.split()
        self.assertEqual(
            manifest_sources(self.path),
            {
                self.path,
                self.directory / "groups/group.json",
                self.directory / "groups/vectors/first.json",
                self.directory / "groups/vectors/second.json",
            },
        )
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "run_tests.py"),
                "--manifest",
                str(self.path),
                "--all",
                "--list",
                "--format",
                "json",
            ],
            cwd=self.directory / "groups",
            capture_output=True,
            text=True,
            timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [row["case_id"] for row in json.loads(result.stdout)],
            [case["id"] for case in self.group["cases"]],
        )

    def test_missing_and_wrong_document_types_are_rejected(self):
        """Rechaza archivos ausentes y distingue grupos de listas de casos."""
        self.split()
        for value, diagnostic in [(None, "cannot read catalogue file"), ([], "group file")]:
            path = self.directory / "groups/group.json"
            if value is None:
                path.unlink()
            else:
                self.write("groups/group.json", value)
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, diagnostic):
                load_manifest(self.path)
        self.split()
        self.write("groups/vectors/first.json", self.group["cases"][0])
        with self.assertRaisesRegex(ValueError, "case file must contain an array"):
            load_manifest(self.path)

    def test_duplicate_keys_and_nonfinite_numbers_in_fragments_are_rejected(self):
        """Aplica el lector JSON estricto también a los archivos de casos."""
        self.split()
        path = self.directory / "groups/vectors/first.json"
        for text, diagnostic in [
            ('[{"id":"first","id":"second"}]', "duplicate JSON key"),
            ('[{"value":NaN}]', "invalid JSON number"),
            ('[{"value":Infinity}]', "invalid JSON number"),
        ]:
            path.write_text(text, encoding="utf-8")
            with self.subTest(text=text), self.assertRaisesRegex(ValueError, diagnostic):
                read_manifest(self.path)

    def test_cycles_and_references_with_extra_fields_are_rejected(self):
        """Detecta ciclos de grupos y casos y evita descartar propiedades de una referencia."""
        self.split()
        self.write("groups/group.json", {"file": "group.json"})
        with self.assertRaisesRegex(ValueError, "cyclic catalogue reference"):
            read_manifest(self.path)
        self.split()
        self.write("groups/vectors/first.json", [{"file": "../vectors/first.json"}])
        with self.assertRaisesRegex(ValueError, "cyclic catalogue reference"):
            read_manifest(self.path)
        self.split()
        index = {**self.manifest, "groups": [{"file": "groups/group.json", "id": "lost"}]}
        self.write("index.json", index)
        with self.assertRaisesRegex(ValueError, "invalid file reference"):
            read_manifest(self.path)

    def test_references_cannot_leave_the_catalogue_directory(self):
        """Rechaza rutas absolutas, escapes relativos y symlinks hacia archivos externos."""
        with tempfile.TemporaryDirectory(prefix="tp3 outside catalogue ") as outside:
            target = Path(outside) / "group.json"
            target.write_text(json.dumps(self.group), encoding="utf-8")
            link = self.directory / "external.json"
            link.symlink_to(target)
            for reference in [str(target), f"../{Path(outside).name}/group.json", "external.json"]:
                index = {**self.manifest, "groups": [{"file": reference}]}
                self.write("index.json", index)
                with (
                    self.subTest(reference=reference),
                    self.assertRaisesRegex(ValueError, "leaves its directory"),
                ):
                    read_manifest(self.path)

    def test_resolved_schema_and_cross_file_ids_are_validated(self):
        """Valida el contenido resuelto y rechaza IDs repetidos entre archivos."""
        self.split()
        invalid = copy.deepcopy(self.group["cases"][0])
        invalid["unexpected"] = True
        self.write("groups/vectors/first.json", [invalid])
        with self.assertRaisesRegex(ValueError, "manifest validation failed") as caught:
            load_manifest(self.path)
        self.assertIn(str(self.path), str(caught.exception))
        self.assertIn("$.groups[0].cases[0]", str(caught.exception))
        self.assertNotIn("tp3-manifest-", str(caught.exception))
        self.write("groups/vectors/first.json", [self.group["cases"][0]])
        self.write("groups/vectors/second.json", [self.group["cases"][0]])
        with self.assertRaisesRegex(ValueError, "duplicate case ID"):
            load_manifest(self.path)

    def test_prepare_case_cannot_overwrite_any_catalogue_source(self):
        """Protege tanto el índice como cada grupo y lista de casos frente a --output."""
        self.split()
        originals = {path: path.read_bytes() for path in manifest_sources(self.path)}
        for path in originals:
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS / "prepare_case.py"),
                    "--manifest",
                    str(self.path),
                    "--case",
                    self.group["cases"][0]["id"],
                    "--output",
                    str(path),
                ],
                capture_output=True,
                text=True,
                timeout=15,
            )
            with self.subTest(path=path):
                self.assertEqual(result.returncode, 1)
                self.assertIn("output must not replace", result.stderr)
                self.assertEqual(path.read_bytes(), originals[path])
