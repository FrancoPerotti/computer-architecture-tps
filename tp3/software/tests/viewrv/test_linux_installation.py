"""Real filesystem/process/lock checks in a temporary per-user profile."""

import fcntl
import json
import os
import shutil
import signal
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from software.packaging.stage_linux import stage
from software.viewrv.client.platform import InstanceGuard
from software.viewrv.installation.__main__ import inherited_lease, main
from software.viewrv.installation.files import MaintenanceError, inventory, read_json
from software.viewrv.installation.service import MANIFEST, active_executables, maintain, user_paths

SOFTWARE = Path(__file__).resolve().parents[2]


@unittest.skipUnless(os.sys.platform == "linux", "Mantenimiento Linux")
class LinuxInstallationTests(unittest.TestCase):
    """Exercise reversible maintenance with real files, locks and Linux processes."""

    @classmethod
    def setUpClass(cls):
        """Compile the small launcher for process and lease integration checks."""
        cls.build = tempfile.TemporaryDirectory(prefix="viewrv-launcher-tests-")
        cls.launcher = Path(cls.build.name) / "launcher"
        subprocess.run(
            [
                "cc",
                "-O2",
                "-Wall",
                "-Wextra",
                "-Werror",
                str(SOFTWARE / "packaging/linux/launcher.c"),
                "-o",
                str(cls.launcher),
            ],
            check=True,
        )

    @classmethod
    def tearDownClass(cls):
        """Remove only this test class's disposable launcher."""
        cls.build.cleanup()

    def setUp(self):
        """Create a package and an isolated account with literal shell metacharacters."""
        self.temp = tempfile.TemporaryDirectory(prefix='viewrv user $literal `name` % " ')
        self.home = Path(self.temp.name)
        self.environment = patch.dict(
            os.environ,
            {
                "HOME": str(self.home),
                "XDG_STATE_HOME": str(self.home / "state"),
                "XDG_DATA_HOME": str(self.home / "data"),
                "XDG_CONFIG_HOME": str(self.home / "config"),
                "PATH": "/usr/bin:/bin",
            },
        )
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.addCleanup(self.temp.cleanup)
        self.source = self.home / "download"
        self.source.mkdir()
        (self.source / "resources/core").mkdir(parents=True)
        for name in ("viewrv", "viewrv-gui", "resources/core/viewrv-core"):
            shutil.copy2("/bin/true", self.source / name)
        stage(self.source, self.launcher)
        self.root, self.cli, self.desktop = user_paths()

    def tree(self):
        """Capture all installed bytes, modes and symlink targets."""
        return inventory(self.root, confined=False)

    def test_install_update_uninstall_preserve_unknown_assembly_and_external_data(self):
        """Preserve unknown Assembly, links, preferences and shell configuration."""
        shell = self.home / ".zshrc"
        shell.write_text("original\n")
        self.assertIn("no está en PATH", maintain("install", self.source))
        self.assertEqual(self.cli.resolve(), self.root / "viewrv")
        self.assertEqual(subprocess.run([str(self.cli)]).returncode, 0)
        text = self.desktop.read_text()
        self.assertIn('Exec=/usr/bin/env -- "', text)
        self.assertIn("\\$literal", text)
        self.assertIn("\\\\`name\\\\`", text)
        self.assertIn("%%", text)
        self.assertIn('\\"', text)
        self.assertNotIn("%F", text)
        retained = self.root / "user program.s"
        retained.write_text("halt\n")
        nested = self.root / "resources/user notes"
        nested.mkdir()
        (nested / "notes.s").write_text("add x1,x2,x3\n")
        outside = self.home / "data/viewrv/recovery/draft.json"
        outside.parent.mkdir(parents=True)
        outside.write_text("draft")
        link = self.root / "external source"
        link.symlink_to(outside)
        maintain("install", self.source)
        self.assertEqual(retained.read_text(), "halt\n")
        self.assertEqual(os.readlink(link), str(outside))
        maintain("uninstall")
        self.assertFalse(self.cli.exists())
        self.assertFalse(self.desktop.exists())
        self.assertFalse((self.root / "viewrv").exists())
        self.assertEqual(retained.read_text(), "halt\n")
        self.assertEqual((nested / "notes.s").read_text(), "add x1,x2,x3\n")
        self.assertEqual(outside.read_text(), "draft")
        self.assertEqual(shell.read_text(), "original\n")
        self.assertFalse(read_json(self.root / MANIFEST)["installed"])
        maintain("install", self.source)
        maintain("uninstall")
        self.assertTrue(retained.exists())

    @unittest.skipUnless(shutil.which("gio"), "GIO desktop launcher unavailable")
    def test_desktop_access_is_accepted_by_gio_with_literal_shell_metacharacters(self):
        """Use the desktop parser to resolve the quoted public launcher path."""
        maintain("install", self.source)
        result = subprocess.run(
            ["gio", "launch", str(self.desktop)], capture_output=True, text=True, timeout=5
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_uninstall_without_user_files_removes_install_directory_and_is_repeatable(self):
        """Remove an empty product directory and allow an already absent product."""
        maintain("install", self.source)
        maintain("uninstall")
        self.assertFalse(self.root.exists())
        self.assertIn("No hay", maintain("uninstall"))

    def test_unmanaged_destination_and_foreign_shortcuts_are_never_overwritten(self):
        """Reject foreign destinations before staging any replacement."""
        self.root.mkdir(parents=True)
        (self.root / "foreign").write_text("keep")
        with self.assertRaises(MaintenanceError):
            maintain("install", self.source)
        self.assertEqual((self.root / "foreign").read_text(), "keep")
        shutil.rmtree(self.root)
        self.cli.parent.mkdir(parents=True)
        self.cli.write_text("another app")
        with self.assertRaises(MaintenanceError):
            maintain("install", self.source)
        self.assertEqual(self.cli.read_text(), "another app")
        self.assertFalse(self.root.exists())

    def test_tampered_source_or_installed_owned_file_aborts_with_old_product_intact(self):
        """Refuse altered owned files without deleting user modifications."""
        maintain("install", self.source)
        before = self.tree()
        (self.source / "resources/icons/viewrv.svg").write_text("broken")
        with self.assertRaises(MaintenanceError):
            maintain("install", self.source)
        self.assertEqual(self.tree(), before)
        (self.root / "viewrv").write_bytes(b"changed by user")
        before = self.tree()
        with self.assertRaises(MaintenanceError):
            maintain("uninstall")
        self.assertEqual(self.tree(), before)
        self.assertTrue(self.cli.is_symlink())

    def test_unsafe_manifest_and_substituted_directory_symlink_are_rejected(self):
        """Reject traversal and directory substitutions before following child paths."""
        maintain("install", self.source)
        path = self.root / MANIFEST
        original = path.read_bytes()
        value = json.loads(original)
        value["files"][0]["path"] = "../outside"
        path.write_text(json.dumps(value))
        with self.assertRaises(MaintenanceError):
            maintain("uninstall")
        path.write_bytes(original)
        shutil.rmtree(self.root / "resources/icons")
        (self.root / "resources/icons").symlink_to(self.source / "resources/icons")
        with self.assertRaises(MaintenanceError):
            maintain("uninstall")
        self.assertTrue((self.source / "resources/icons/viewrv.svg").is_file())

    def test_access_commit_failure_rolls_back_product_and_both_accesses(self):
        """Restore the previous product and CLI link if desktop replacement fails."""
        from software.viewrv.installation import service

        maintain("install", self.source)
        (self.root / "mine.s").write_text("keep")
        before, desktop = self.tree(), self.desktop.read_bytes()
        original = service.rename

        def fail_desktop(source, destination, **kwargs):
            if destination == self.desktop:
                raise PermissionError("injected occupied destination")
            return original(source, destination, **kwargs)

        with patch.object(service, "rename", side_effect=fail_desktop):
            with self.assertRaises(PermissionError):
                maintain("install", self.source)
        self.assertEqual(self.tree(), before)
        self.assertEqual(self.desktop.read_bytes(), desktop)
        self.assertEqual(self.cli.resolve(), self.root / "viewrv")
        self.assertFalse(list(self.root.parent.glob(".viewrv-stage-*")))
        self.assertFalse(list(self.cli.parent.glob(".viewrv-access-*")))

    def test_kernel_executable_check_rejects_raw_process_without_pid_or_core_lock(self):
        """Detect an actual raw executable while ignoring stale discovery metadata."""
        maintain("install", self.source)
        raw = self.root / "raw-sleep"
        shutil.copy2("/bin/sleep", raw)
        process = subprocess.Popen([str(raw), "30"])
        try:
            with self.assertRaisesRegex(MaintenanceError, "en uso"):
                maintain("uninstall")
            self.assertIsNone(process.poll())
        finally:
            process.terminate()
            process.wait(timeout=5)
        # A stale discovery file has no authority over kernel process/lock state.
        state = self.home / "state/viewrv"
        state.mkdir(parents=True, exist_ok=True)
        (state / "core.json").write_text('{"pid":123}')
        active_executables([self.root])
        maintain("uninstall")
        self.assertTrue(raw.exists())

    def test_initial_replacement_failure_leaves_no_product_or_shortcuts(self):
        """Abort the first rename without publishing partial product accesses."""
        with patch(
            "software.viewrv.installation.service.rename", side_effect=PermissionError("occupied")
        ):
            with self.assertRaises(PermissionError):
                maintain("install", self.source)
        self.assertFalse(self.root.exists())
        self.assertFalse(self.cli.exists())
        self.assertFalse(self.desktop.exists())
        self.assertFalse(list(self.root.parent.glob(".viewrv-stage-*")))

    def test_failed_rollback_preserves_the_previous_tree_as_a_named_backup(self):
        """Never clean the sole old copy when an operating-system rollback fails."""
        from software.viewrv.installation import service

        maintain("install", self.source)
        (self.root / "retained.s").write_text("halt\n")
        before = self.tree()
        original = service.rename
        root_replacements = []

        def fail_commit_and_rollback(source, destination, **kwargs):
            if destination == self.root:
                root_replacements.append(1)
                if len(root_replacements) == 2:
                    raise PermissionError("rollback blocked")
            if destination == self.desktop:
                raise PermissionError("desktop blocked")
            return original(source, destination, **kwargs)

        with patch.object(service, "rename", side_effect=fail_commit_and_rollback):
            with self.assertRaisesRegex(MaintenanceError, "respaldo"):
                maintain("install", self.source)
        backups = list(self.root.parent.glob(".viewrv-stage-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(inventory(backups[0], confined=False), before)
        self.assertEqual((self.root / "retained.s").read_text(), "halt\n")

    def test_all_public_starts_reject_exclusive_maintenance_and_cli_json_is_one_envelope(self):
        """Reject every public entry while maintenance owns the exclusive lease."""
        lock = self.home / "state/viewrv/maintenance.lock"
        lock.parent.mkdir(parents=True)
        with lock.open("w+") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            for name in ("viewrv", "viewrv-gui", "resources/core/viewrv-core"):
                args = [str(self.source / name)]
                if name == "viewrv":
                    args += ["--output", "json", "board", "status"]
                result = subprocess.run(args, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 1)
                if name == "viewrv":
                    self.assertEqual(
                        json.loads(result.stdout)["error"]["details"]["reason"],
                        "PRODUCT_MAINTENANCE",
                    )
                    self.assertEqual(len(result.stdout.splitlines()), 1)
        self.assertEqual(subprocess.run([str(self.source / "viewrv")]).returncode, 0)

    def test_running_launcher_holds_shared_lease_and_relays_sigint_without_killing_other_jobs(self):
        """Keep the launch lease and forward SIGINT to the supervised child only."""
        payload = self.source / ".viewrv-native"
        shutil.copy2("/bin/sleep", payload)
        process = subprocess.Popen([str(self.source / "viewrv"), "30"])
        try:
            # Reading child state is a readiness barrier, not a PID-based lock.
            import time

            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                lock = self.home / "state/viewrv/maintenance.lock"
                if lock.exists():
                    with lock.open("r+") as stream:
                        try:
                            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                        except BlockingIOError:
                            break
                time.sleep(0.01)
            else:
                self.fail("Launcher did not acquire its lease")
            result = subprocess.run(
                [str(self.source / "viewrv-maintenance"), "uninstall"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("Cerrá la GUI", result.stderr)
            process.send_signal(signal.SIGINT)
            self.assertEqual(process.wait(timeout=5), 130)
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)

    def test_inherited_exclusive_lease_is_required_and_core_guard_blocks_worker(self):
        """Require both the inherited maintenance lease and existing core exclusion."""
        with self.assertRaises(MaintenanceError):
            inherited_lease()
        lock = self.home / "state/viewrv/maintenance.lock"
        lock.parent.mkdir(parents=True)
        with lock.open("w+") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            with patch.dict(os.environ, {"VIEWRV_MAINTENANCE_FD": str(stream.fileno())}):
                self.assertEqual(inherited_lease(), stream.fileno())
            with InstanceGuard():
                with patch.dict(os.environ, {"VIEWRV_MAINTENANCE_FD": str(stream.fileno())}):
                    self.assertEqual(main(["--worker", "install", "--source", str(self.source)]), 1)
        self.assertFalse(self.root.exists())
