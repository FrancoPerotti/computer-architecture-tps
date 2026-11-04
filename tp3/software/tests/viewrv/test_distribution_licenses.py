"""Verify complete offline license staging and refusal of stale or altered inputs."""

import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from software.packaging.licenses import fetch, stage, validate, verify


class DistributionLicensesTests(unittest.TestCase):
    """Exercise package boundaries with independent source and notice fixtures."""

    def setUp(self):
        """Create a small reviewed dependency and corresponding-source inventory."""
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.software = self.root / "software"
        self.product = self.root / "product"
        self.product.mkdir()

        def file(root, name, data):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            return {"path": name, "sha256": hashlib.sha256(data).hexdigest()}

        self.source = file(self.software / "build/license-sources", "component.tar.gz", b"source")
        self.lock = {
            "schema_version": 1,
            "platform": "linux-x86_64",
            "reviewed_inputs": [
                file(self.software, "LICENSE", b"own license"),
                file(self.software, "LICENSING.md", b"own scope"),
                file(self.software, "dependencies.lock", b"component 1"),
            ],
            "notices": [file(self.software / "resources/licenses", "NOTICE.txt", b"attribution")],
            "sources": [
                {
                    **self.source,
                    "path": "sources/component.tar.gz",
                    "cache_name": "component.tar.gz",
                    "url": "https://example.invalid/component.tar.gz",
                    "size": 6,
                }
            ],
            "runtime_files": [file(self.product, "library.so", b"reviewed binary")],
            "runtime_notices": [
                {**file(self.product, "LICENSE", b"runtime license"), "destination": "Runtime.txt"}
            ],
            "components": [
                {
                    "name": "component",
                    "version": "1",
                    "license": "MIT",
                    "notice_paths": ["NOTICE.txt", "Runtime.txt"],
                }
            ],
        }
        self.save_lock()

    def save_lock(self):
        """Persist the reviewed fixture independently of the implementation's output."""
        path = self.software / "packaging/licenses-linux.lock.json"
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(self.lock))

    def test_materialized_sources_and_notices_verify_without_checkout_or_cache(self):
        """A product carries real sources, not merely a working-copy reference."""
        destination = stage(self.product, self.software)
        self.assertEqual((destination / "sources/component.tar.gz").read_bytes(), b"source")
        (self.software / "build/license-sources/component.tar.gz").unlink()
        (self.software / "resources/licenses/NOTICE.txt").unlink()
        self.assertEqual(verify(destination), {"components": 1, "files": 7, "sources": 1})
        (destination / "sources/component.tar.gz").write_bytes(b"changed source")
        with self.assertRaisesRegex(ValueError, "material de licencias"):
            verify(destination)

    def test_missing_source_stale_dependency_and_changed_runtime_refuse_staging(self):
        """Each boundary fails before creating the destination directory."""
        for relative in (
            "build/license-sources/component.tar.gz",
            "dependencies.lock",
        ):
            with self.subTest(relative=relative):
                path = self.software / relative
                original = path.read_bytes()
                path.write_bytes(b"changed")
                with self.assertRaises(ValueError):
                    stage(self.product, self.software)
                self.assertFalse((self.product / "resources/licenses").exists())
                path.write_bytes(original)
        (self.product / "library.so").write_bytes(b"different version")
        with self.assertRaises(ValueError):
            stage(self.product, self.software)
        self.assertFalse((self.product / "resources/licenses").exists())

    def test_unlisted_notices_and_missing_component_attribution_are_rejected(self):
        """A manifest cannot certify an incomplete index or extra material."""
        self.lock["components"][0]["notice_paths"] = ["missing.txt"]
        self.save_lock()
        destination = stage(self.product, self.software)
        with self.assertRaisesRegex(ValueError, "sin avisos"):
            verify(destination)
        self.lock["components"][0]["notice_paths"] = ["NOTICE.txt"]
        (destination / "manifest.json").write_text(json.dumps(self.lock))
        (destination / "extra.txt").write_text("unlisted")
        with self.assertRaisesRegex(ValueError, "inconsistentes"):
            verify(destination)

    def test_paths_and_symlinks_cannot_escape_the_reviewed_material(self):
        """A curated-data mistake cannot read arbitrary files during staging."""
        for name in ("../LICENSE", "/etc/passwd", "a/../LICENSE", "a\\LICENSE"):
            with self.subTest(name=name):
                self.lock["notices"][0]["path"] = name
                self.save_lock()
                with self.assertRaisesRegex(ValueError, "Ruta de licencia"):
                    validate(self.software)
        self.lock["notices"][0]["path"] = "NOTICE.txt"
        self.save_lock()
        path = self.software / "resources/licenses/NOTICE.txt"
        path.unlink()
        path.symlink_to(self.software / "LICENSE")
        with self.assertRaisesRegex(ValueError, "Enlace no admitido"):
            validate(self.software)

    def test_failed_download_does_not_replace_cached_source(self):
        """A truncated or altered response never becomes a valid source cache entry."""
        path = self.software / "build/license-sources/component.tar.gz"
        path.write_bytes(b"old cache requiring refresh")
        with patch("urllib.request.urlopen", return_value=io.BytesIO(b"bad")):
            with self.assertRaisesRegex(ValueError, "incompleta o alterada"):
                fetch(self.software)
        self.assertEqual(path.read_bytes(), b"old cache requiring refresh")
        self.assertEqual([p.name for p in path.parent.iterdir()], [path.name])
