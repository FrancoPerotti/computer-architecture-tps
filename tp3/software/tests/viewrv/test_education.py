"""PC-I07: complete reviewed catalog and graph references, independently of a GUI."""

import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from software.packaging.prepare_education import CONTENT, extract, validate, viewer_data


class EducationTests(unittest.TestCase):
    """Check content completeness and reject silent loss of graph associations."""

    def test_saved_content_covers_the_reviewed_33_instructions_and_165_stages(self):
        """TEST-PC-019: preserve reviewed prose and identify every semantic block."""
        self.assertEqual(validate(), {"instructions": 33, "stages": 165, "blocks": 44})
        source, _, _ = viewer_data()
        # Verify the initial extraction, rather than locking future editorial
        # corrections in the saved Spanish resource to the legacy HTML's prose.
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            (temporary / "viewer").mkdir()
            for file in ["viewer/index.html", "viewer/provenance.json", "diagram_bindings.json"]:
                shutil.copy2(CONTENT / file, temporary / file)
            extract(temporary)
            saved = json.loads((temporary / "es/education.json").read_text(encoding="utf-8"))
        pages = {page["id"]: page for page in source["pages"]}
        for name, instruction in saved["instructions"].items():
            self.assertEqual(
                instruction["description"], source["instructions"][name]["description"]
            )
            for entry, original in zip(
                instruction["stages"], source["instructions"][name]["stages"]
            ):
                self.assertEqual(entry["paragraphs"], pages[original["id"]]["paragraphs"])
        self.assertTrue(saved["assumptions"])

    def test_missing_stage_instruction_or_graph_root_blocks_acceptance(self):
        """TEST-PC-019: edited resources cannot silently drop required content."""
        with tempfile.TemporaryDirectory() as directory:
            content = Path(directory) / "content"
            (content / "es").mkdir(parents=True)
            files = [
                "processor_profile.json",
                "diagram.drawio.xml",
                "diagram_bindings.json",
                "es/education.json",
            ]
            for file in files:
                shutil.copy2(CONTENT / file, content / file)
            original = json.loads((content / "es/education.json").read_text(encoding="utf-8"))
            for change, message in [
                ("stage", "cinco etapas"),
                ("instruction", "33 instrucciones"),
                ("reference", "referencia"),
                ("contextual", "contextual"),
            ]:
                with self.subTest(change=change):
                    value = json.loads(json.dumps(original))
                    if change == "stage":
                        value["instructions"]["addi"]["stages"].pop()
                    elif change == "instruction":
                        del value["instructions"]["addi"]
                    elif change == "contextual":
                        value["instructions"]["addi"]["module_explanations"]["missing.block"] = (
                            "Texto"
                        )
                    else:
                        value["instructions"]["addi"]["stages"][0]["blocks"].append(
                            "nonexistent.block"
                        )
                    (content / "es/education.json").write_text(json.dumps(value))
                    with self.assertRaisesRegex(ValueError, message):
                        validate(content)
            (content / "es/education.json").write_text(json.dumps(original))
            bindings = json.loads((content / "diagram_bindings.json").read_text(encoding="utf-8"))
            bindings["blocks"]["id.rs1_bypass_mux"] = "missing-graph-root"
            (content / "diagram_bindings.json").write_text(json.dumps(bindings))
            profile = json.loads((content / "processor_profile.json").read_text(encoding="utf-8"))
            profile["bindings_sha256"] = hashlib.sha256(
                (content / "diagram_bindings.json").read_bytes()
            ).hexdigest()
            (content / "processor_profile.json").write_text(json.dumps(profile))
            with self.assertRaisesRegex(ValueError, "44 bloques"):
                validate(content)

    def test_extraction_cannot_overwrite_saved_editorial_changes(self):
        """A build validates saved content; extracting again requires an explicit review."""
        before = (CONTENT / "es/education.json").read_bytes()
        with self.assertRaisesRegex(ValueError, "no se sobrescribe"):
            extract()
        self.assertEqual((CONTENT / "es/education.json").read_bytes(), before)

    def test_nonexistent_alternative_representation_is_rejected(self):
        """The internal pipeline-empty cell must exist, independently of its owner."""
        with tempfile.TemporaryDirectory() as directory:
            content = Path(directory) / "content"
            shutil.copytree(
                CONTENT, content, ignore=shutil.ignore_patterns("*.html", "fonts", "*.min.js")
            )
            descriptor = json.loads((content / "diagram_bindings.json").read_text())
            descriptor["representations"]["session.pipeline_empty"] = ["missing-internal-cell"]
            (content / "diagram_bindings.json").write_text(json.dumps(descriptor))
            profile = json.loads((content / "processor_profile.json").read_text())
            profile["bindings_sha256"] = hashlib.sha256(
                (content / "diagram_bindings.json").read_bytes()
            ).hexdigest()
            (content / "processor_profile.json").write_text(json.dumps(profile))
            with self.assertRaisesRegex(ValueError, "representación alternativa"):
                validate(content)

    def test_extraction_uses_source_bindings_after_current_layout_ids_change(self):
        """Language extraction retains semantic references independently of layout IDs."""
        with tempfile.TemporaryDirectory() as directory:
            content = Path(directory)
            (content / "viewer").mkdir()
            for name in ["viewer/index.html", "viewer/provenance.json", "diagram_bindings.json"]:
                shutil.copy2(CONTENT / name, content / name)
            descriptor = json.loads((content / "diagram_bindings.json").read_text(encoding="utf-8"))
            descriptor["blocks"]["latch.if_id"] = "renamed-current-latch"
            (content / "diagram_bindings.json").write_text(json.dumps(descriptor), encoding="utf-8")
            extract(content)
            education = json.loads((content / "es/education.json").read_text(encoding="utf-8"))
            self.assertEqual(len(education["modules"]), 44)
            self.assertTrue(education["modules"]["latch.if_id"]["description"])
            source, _, _ = viewer_data(content)
            pages = {page["id"]: page for page in source["pages"]}
            for identifier, instruction in education["instructions"].items():
                for stage, reference in zip(
                    instruction["stages"], source["instructions"][identifier]["stages"]
                ):
                    self.assertEqual(
                        "session.pipeline_empty" in stage["blocks"],
                        "tp3-exec-empty" in pages[reference["id"]]["components"],
                    )
