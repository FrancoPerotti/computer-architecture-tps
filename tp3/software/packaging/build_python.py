"""Construir los dos conjuntos onedir nativos y su inventario."""

import argparse
import hashlib
import json
import platform
import subprocess
import sys
from importlib.util import find_spec
from pathlib import Path

SOFTWARE = Path(__file__).resolve().parents[1]
TP3 = SOFTWARE.parent
sys.path.insert(0, str(TP3))


def main():
    from software.viewrv import __version__
    from software.viewrv.adapters.programmer import HardwareAssets
    from software.viewrv.client.resources import load_profile

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--native-only",
        action="store_true",
        help="Construir CLI/core para verificación local, sin inventario de distribución.",
    )
    args = parser.parse_args()
    (SOFTWARE / "build/stage-release.json").unlink(missing_ok=True)

    if sys.version_info[:3] != (3, 14, 9):
        raise SystemExit("La construcción aprobada requiere CPython 3.14.9.")
    target = {"Linux": "linux", "Windows": "windows"}.get(platform.system())
    if target is None or platform.machine().lower() not in {"amd64", "x86_64"}:
        raise SystemExit("Se requiere Linux o Windows x86_64 nativo.")
    if not args.native_only:
        from software.packaging.validate_examples import validate

        validate(SOFTWARE / "resources/content")
    has_assembler = find_spec("software.assembler") is not None
    for name, entry, contents in (
        ("viewrv", "cli_entry.py", "_internal_cli"),
        ("viewrv-core", "core_entry.py", "_internal"),
    ):
        subprocess.run(
            [
                sys.executable,
                "-m",
                "PyInstaller",
                "--noconfirm",
                "--clean",
                "--onedir",
                "--name",
                name,
                "--contents-directory",
                contents,
                "--paths",
                str(TP3),
                "--distpath",
                str(SOFTWARE / "build/python"),
                "--workpath",
                str(SOFTWARE / "build/pyinstaller" / name),
                "--specpath",
                str(SOFTWARE / "build/spec"),
                *(
                    ["--hidden-import", "software.assembler"]
                    if name == "viewrv-core" and has_assembler
                    else []
                ),
                str(SOFTWARE / "packaging" / entry),
            ],
            cwd=TP3,
            check=True,
        )
    if args.native_only:
        print(
            "CLI y core nativos construidos; no se generó un paquete ni inventario de distribución."
        )
        return
    assets = HardwareAssets(SOFTWARE / "resources", load_profile(SOFTWARE / "resources"))
    assets.programmer()
    assets.bitstream()
    resources = []
    extension = ".exe" if target == "windows" else ""
    inputs = [
        ("cli", SOFTWARE / f"build/python/viewrv/viewrv{extension}", f"viewrv{extension}"),
        (
            "core",
            SOFTWARE / f"build/python/viewrv-core/viewrv-core{extension}",
            f"resources/core/viewrv-core{extension}",
        ),
    ]
    for file in sorted((SOFTWARE / "resources/content").rglob("*")):
        if file.is_file():
            inputs.append(
                (
                    "content",
                    file,
                    f"resources/content/{file.relative_to(SOFTWARE / 'resources/content').as_posix()}",
                )
            )
    for directory, role in (("programmer", "programmer"), ("hardware", "bitstream")):
        for file in sorted((SOFTWARE / "resources" / directory).rglob("*")):
            if file.is_file():
                inputs.append(
                    (
                        role,
                        file,
                        f"resources/{directory}/{file.relative_to(SOFTWARE / 'resources' / directory).as_posix()}",
                    )
                )
    for role, file, path in inputs:
        resources.append(
            {"role": role, "path": path, "sha256": hashlib.sha256(file.read_bytes()).hexdigest()}
        )
    profile = json.loads((SOFTWARE / "resources/content/processor_profile.json").read_text())
    inventory = {
        "schema_version": 1,
        "app_version": __version__,
        "api_version": 1,
        "platform": target,
        "architecture": "x86_64",
        "processor_profile": {
            key: profile[key] for key in ("profile_id", "revision", "memory_profile")
        },
        "resources": resources,
    }
    (SOFTWARE / "build/stage-release.json").write_text(json.dumps(inventory, indent=2) + "\n")
    print(
        f"Conjuntos onedir de CLI/core e inventario {target} preparados; no es la distribución final."
    )


if __name__ == "__main__":
    main()
