"""Exercise frozen install/update/self-uninstall with a disposable HOME, without FPGA."""

import argparse
import fcntl
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


def main():
    """Verify the actual offline package while preserving the operator's profile."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("product", type=Path)
    parser.add_argument(
        "--gui",
        action="store_true",
        help="Ejecutar además GUI/CLI nativas en Xvfb desde la instalación.",
    )
    args = parser.parse_args()
    if args.gui and not Path("/usr/bin/xvfb-run").is_file():
        raise SystemExit("La prueba --gui requiere Xvfb; usá check_ubuntu_gui.sh con installation.")
    source = args.product.resolve()
    with tempfile.TemporaryDirectory(prefix='viewrv install $literal % " ') as directory:
        home = Path(directory)
        environment = {
            **os.environ,
            "HOME": str(home),
            "XDG_STATE_HOME": str(home / "state"),
            "XDG_DATA_HOME": str(home / "data"),
            "XDG_CONFIG_HOME": str(home / "config"),
            "XDG_RUNTIME_DIR": str(home),
            "PATH": "/usr/bin:/bin",
        }
        for name in (
            "PYTHONPATH",
            "PYTHONHOME",
            "LD_LIBRARY_PATH",
            "LD_PRELOAD",
            "VIEWRV_MAINTENANCE_FD",
        ):
            environment.pop(name, None)
        root = home / ".local/opt/viewrv"
        cli = home / ".local/bin/viewrv"
        discovery = home / "viewrv/core.json"

        def run(*arguments, expected=0):
            result = subprocess.run(
                [str(arg) for arg in arguments],
                cwd=home,
                env=environment,
                text=True,
                capture_output=True,
                timeout=90,
            )
            assert result.returncode == expected, (result.returncode, result.stdout, result.stderr)
            return result

        def quiet():
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                with (home / "state/viewrv/maintenance.lock").open("r+") as stream:
                    try:
                        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    except BlockingIOError:
                        time.sleep(0.05)
                    else:
                        return
            raise AssertionError("Los componentes no liberaron la exclusión de mantenimiento")

        installed = False
        try:
            download = home / "original download"
            shutil.copytree(source, download, symlinks=True)
            result = run(download / "install.sh")
            installed = True
            assert "no está en PATH" in result.stdout
            assert cli.is_symlink()
            assert (home / "data/applications/viewrv.desktop").is_file()
            assert "0.7.0" in run(cli, "--version").stdout
            assert not discovery.exists(), "--version no debe arrancar el core"
            shutil.rmtree(download)
            with (home / "state/viewrv/maintenance.lock").open("r+") as lease:
                fcntl.flock(lease, fcntl.LOCK_EX)
                for entry in ("viewrv", "viewrv-gui", "resources/core/viewrv-core"):
                    arguments = [root / entry]
                    if entry == "viewrv":
                        arguments += ["--output", "json", "work", "status"]
                    blocked = run(*arguments, expected=1)
                    if entry == "viewrv":
                        assert (
                            json.loads(blocked.stdout)["error"]["details"]["reason"]
                            == "PRODUCT_MAINTENANCE"
                        )
                    else:
                        assert "mantenimiento" in blocked.stderr
            if args.gui:
                software = Path(__file__).resolve().parents[1]
                gui_environment = {
                    **environment,
                    "VIEWRV_PRODUCT": str(root),
                    "VIEWRV_EVIDENCE_PREFIX": "linux-installed",
                    "VIEWRV_TEST_MAINTENANCE": "1",
                }
                for scenario in ("native-ide-smoke.cjs", "sandbox-smoke.cjs"):
                    subprocess.run(
                        [
                            "/usr/bin/xvfb-run",
                            "-a",
                            "-s",
                            "-screen 0 1366x768x24",
                            str(software / "build/toolchain/node_modules/node/bin/node"),
                            str(software / "gui/tests" / scenario),
                        ],
                        cwd=software / "gui",
                        env=gui_environment,
                        check=True,
                        # The full catalog visits 165 real graph stages. This bounds the
                        # functional verifier; UI response is measured separately.
                        timeout=600 if scenario == "native-ide-smoke.cjs" else 90,
                    )
            source_file = home / "user code.s"
            source_file.write_text("addi x1, x0, 8\nhalt\n")
            output = json.loads(
                run(cli, "--output", "json", "program", "assemble", source_file).stdout
            )
            assert output["error"] is None
            assert discovery.exists(), "El trabajo CLI debe conservar el core nativo"
            before = (root / "install-manifest.json").read_bytes()
            rejected = run(source / "install.sh", expected=1)
            assert "finalizá" in rejected.stderr
            run(root / "uninstall.sh", expected=1)
            assert (root / "install-manifest.json").read_bytes() == before
            run(cli, "--output", "json", "work", "finish")
            quiet()
            assert not discovery.exists()
            # Data both outside and inside the installation must survive. The
            # next install uses its own installed scripts, not the download.
            nested = root / "resources/user notes"
            nested.mkdir()
            (nested / "own.s").write_text("halt\n")
            saved = []
            for area in ("state/viewrv/records", "state/viewrv/recovery", "config/viewrv"):
                path = home / area / "keep.txt"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("keep")
                saved.append(path)
            run(root / "install.sh")
            assert (nested / "own.s").read_text() == "halt\n"
            assert "0.7.0" in run(cli, "--version").stdout
            run(root / "uninstall.sh")
            installed = False
            assert not cli.exists()
            assert not (home / "data/applications/viewrv.desktop").exists()
            assert not (root / "viewrv").exists()
            assert (nested / "own.s").read_text() == "halt\n"
            assert source_file.read_text() == "addi x1, x0, 8\nhalt\n"
            assert all(path.read_text() == "keep" for path in saved)
            # Also remove an installation with no retained data from its own
            # frozen runtime. No system Python or Node is on the product path.
            (nested / "own.s").unlink()
            nested.rmdir()
            (root / "resources").rmdir()
            run(source / "install.sh")
            installed = True
            run(root / "uninstall.sh")
            installed = False
            assert not root.exists()
            print(
                "Native Linux maintenance: per-user install, CLI/native core, occupied update/uninstall refusal, installed-script update, frozen self-uninstall, data preservation and clean uninstall passed. No FPGA or system profile changes."
            )
        finally:
            if installed and cli.exists():
                status = json.loads(run(cli, "--output", "json", "work", "status").stdout)
                if status["result"]["work_id"] is not None:
                    run(cli, "--output", "json", "work", "finish")
                quiet()
                run(root / "uninstall.sh")


if __name__ == "__main__":
    main()
