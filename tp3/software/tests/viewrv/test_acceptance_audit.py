"""Packaging audit checks; these are not physical acceptance of the product."""

import tempfile
import unittest
from pathlib import Path

from software.packaging.audit_licenses import is_notice, notice_files


class NoticeInventoryTests(unittest.TestCase):
    def test_existing_native_font_and_programmer_notice_layouts_are_recognized(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected = [
                "LICENSE",
                "LICENSES.chromium.html",
                "fonts/inter-OFL.txt",
                "fonts/ibm-plex-mono-OFL.txt",
                "programmer/licenses/gcc-runtime.txt",
                "click.dist-info/licenses/LICENSE.txt",
                "COPYING",
                "NOTICE.md",
            ]
            for name in expected + ["packaging/licenses/_spdx.py", "code.js", "README.md"]:
                file = root / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text(name)
            self.assertEqual({str(p.relative_to(root)) for p in notice_files(root)}, set(expected))

    def test_module_named_licenses_is_not_a_license_notice(self):
        self.assertFalse(is_notice(Path("packaging/licenses/__init__.py")))
        self.assertFalse(is_notice(Path("packaging/licenses/_spdx.py")))
        self.assertTrue(is_notice(Path("package.dist-info/licenses/LICENSE.BSD")))
