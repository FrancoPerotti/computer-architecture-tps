"""Add coordinated Linux entry points and offline per-user maintenance to a package."""

import argparse
import json
import shutil
import sys
from pathlib import Path

SOFTWARE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOFTWARE.parent))

from software.viewrv.installation.files import digest, inventory, write_json  # noqa: E402


def stage(root, launcher=None):
    """Wrap native payloads and inventory the resulting offline Linux product."""
    launcher = launcher or SOFTWARE / "build/linux-launcher/viewrv-launcher"
    if (root / "linux-launchers.json").exists():
        raise ValueError("El paquete ya contiene entradas Linux coordinadas.")
    if not launcher.is_file():
        raise ValueError("Falta construir el launcher Linux en la base Ubuntu aprobada.")
    launchers = {}
    for name in ("viewrv", "viewrv-gui", "resources/core/viewrv-core", "viewrv-maintenance"):
        path = root / name
        payload = path.with_name(f".{path.name}-native")
        if name == "viewrv-maintenance":
            shutil.copy2(root / ".viewrv-native", payload)
        else:
            path.rename(payload)
        shutil.copy2(launcher, path)
        path.chmod(0o755)
        launchers[name] = {
            "payload": str(payload.relative_to(root)),
            "sha256": digest(path),
            "payload_sha256": digest(payload),
        }
    for name in ("install.sh", "uninstall.sh"):
        shutil.copy2(SOFTWARE / "packaging/linux" / name, root / name)
        (root / name).chmod(0o755)
    icon = root / "resources/icons/viewrv.svg"
    icon.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOFTWARE / "packaging/linux/viewrv.svg", icon)
    write_json(root / "linux-launchers.json", {"schema_version": 1, "launchers": launchers})
    release_path = root / "release.json"
    if release_path.exists():
        release = json.loads(release_path.read_text())
        by_name = {entry["path"]: entry for entry in release["resources"]}
        for name in (
            *launchers,
            *(entry["payload"] for entry in launchers.values()),
            "install.sh",
            "uninstall.sh",
            "resources/icons/viewrv.svg",
            "linux-launchers.json",
        ):
            by_name[name] = {
                "role": "core"
                if "/core/" in name
                else "cli"
                if name
                in {"viewrv", ".viewrv-native", "viewrv-maintenance", ".viewrv-maintenance-native"}
                else "content",
                "path": name,
                "sha256": digest(root / name),
            }
        release["resources"] = list(by_name.values())
        release_path.write_text(json.dumps(release, indent=2) + "\n")
    write_json(root / "linux-package.json", {"schema_version": 1, "files": inventory(root)})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    stage(args.root.resolve())
