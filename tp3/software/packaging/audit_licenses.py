"""Inventory local third-party notices without approving redistribution or changing a product."""

import argparse
import ast
import hashlib
import importlib.metadata as metadata
import json
import re
import sys
from pathlib import Path

NOTICE = re.compile(r"^(licen[cs]es?|copying|copyright|notice|ofl)([._-].*|$)", re.I)
THIRD_PARTY_NOTICE = re.compile(
    r"^third[._ -]?party[._ -]?(notices?|licen[cs]es?)([._ -].*|$)", re.I
)
SOFTWARE = Path(__file__).resolve().parents[1]


def digest(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def notice_files(root):
    return sorted(p for p in root.rglob("*") if p.is_file() and is_notice(p))


def is_notice(file):
    return (
        bool(NOTICE.match(file.name))
        or (
            bool(THIRD_PARTY_NOTICE.match(file.name))
            and file.suffix.lower() in ("", ".txt", ".md", ".html", ".rst")
        )
        or "-ofl." in file.name.lower()
        or (
            "licenses" in file.parts and file.suffix.lower() in ("", ".txt", ".md", ".rst", ".html")
        )
    )


def analysis_sources():
    sources = set()

    def walk(value):
        if not isinstance(value, (tuple, list)):
            return
        if len(value) == 3 and all(isinstance(item, str) for item in value):
            if "/site-packages/" in value[1]:
                sources.add(value[1].split("/site-packages/", 1)[1])
        for item in value:
            walk(item)

    files = sorted((SOFTWARE / "build/pyinstaller").glob("*/*/Analysis-00.toc"))
    if len(files) != 2:
        raise ValueError("Se requieren los análisis de CLI y core de la construcción auditada.")
    for file in files:
        walk(ast.literal_eval(file.read_text()))
    return files, sources


def audit(product, output):
    output.mkdir(parents=True, exist_ok=True)
    product_manifest = json.loads((product / "verification-manifest.json").read_text())
    python_version = (SOFTWARE / ".python-version").read_text().strip()
    if python_version != ".".join(map(str, sys.version_info[:3])):
        raise ValueError("La auditoría requiere el intérprete fijado para la construcción.")
    python_directory = f"python{sys.version_info.major}.{sys.version_info.minor}"
    packaged = {}
    for file in notice_files(product):
        packaged.setdefault(digest(file), []).append(file.relative_to(product).as_posix())
    components = []

    def component(ecosystem, name, version, license_id, notices, scope):
        identity = re.sub(r"[^a-zA-Z0-9_.-]", "_", f"{ecosystem}-{name}-{version}")
        records = []
        for index, source in enumerate(sorted(set(notices))):
            sha = digest(source)
            destination = output / "notices" / identity / f"{index:02d}-{source.name}"
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(source.read_bytes())
            records.append(
                {
                    "source": str(source),
                    "sha256": sha,
                    "collected": destination.relative_to(output).as_posix(),
                    "packaged_as": packaged.get(sha, []),
                }
            )
        status = (
            "notice_not_available_locally"
            if not records
            else "notices_included"
            if all(record["packaged_as"] for record in records)
            else "notices_not_matched_as_files"
        )
        components.append(
            {
                "ecosystem": ecosystem,
                "name": name,
                "version": version,
                "declared_license": license_id,
                "scope": scope,
                "notice_status": status,
                "notices": records,
            }
        )

    lock_path = SOFTWARE / "gui/package-lock.json"
    lock = json.loads(lock_path.read_text())
    for relative, entry in sorted(lock["packages"].items()):
        if not relative or entry.get("dev"):
            continue
        directory = SOFTWARE / "gui" / relative
        manifest_path = directory / "package.json"
        if not manifest_path.is_file() and entry.get("optional"):
            continue
        manifest = json.loads(manifest_path.read_text())
        if manifest["version"] != entry["version"]:
            raise ValueError(f"La versión instalada no coincide con el lock: {relative}")
        # The installed production graph is a conservative scope, not a Vite
        # attribution proving that every module survives tree shaking.
        own_notices = [
            p
            for p in notice_files(directory)
            if "node_modules" not in p.relative_to(directory).parts
        ]
        component(
            "npm",
            manifest["name"],
            manifest["version"],
            manifest.get("license"),
            own_notices,
            "installed-production-graph",
        )

    analyses, sources = analysis_sources()
    site = SOFTWARE / f"build/ubuntu-venv/lib/{python_directory}/site-packages"
    if not site.is_dir():
        raise ValueError("Falta el entorno de metadatos de la construcción Ubuntu.")
    for distribution in sorted(metadata.distributions(path=[str(site)]), key=lambda d: d.name):
        files = distribution.files or []
        if not sources.intersection(str(file) for file in files):
            continue
        notices = [
            Path(distribution.locate_file(file))
            for file in files
            if is_notice(Path(str(file))) and Path(distribution.locate_file(file)).is_file()
        ]
        component(
            "python",
            distribution.name,
            distribution.version,
            distribution.metadata.get("License-Expression") or distribution.metadata.get("License"),
            notices,
            "collected-by-pyinstaller-analysis",
        )
    python_license = Path(sys.base_prefix) / f"lib/{python_directory}/LICENSE.txt"
    component(
        "runtime",
        "CPython",
        python_version,
        "PSF-2.0 and historical notices",
        [python_license],
        "bundled-libpython; static-dependency-attribution-still-required",
    )
    component(
        "runtime",
        "Electron",
        product_manifest["electron_version"],
        "MIT and bundled Chromium notices",
        [product / "LICENSE", product / "LICENSES.chromium.html"],
        "native-gui-runtime",
    )
    for name in ("inter", "ibm-plex-mono"):
        component(
            "content",
            name,
            "pinned-assets",
            "OFL-1.1",
            [SOFTWARE / f"resources/content/fonts/{name}-OFL.txt"],
            "local-fonts",
        )
    programmer = json.loads((SOFTWARE / "resources/programmer/manifest.json").read_text())
    programmer_versions = {p["package"]: p["version"] for p in programmer["dependencies"]}
    programmer_versions["openFPGALoader"] = programmer["version"]
    for notice in notice_files(SOFTWARE / "resources/programmer/licenses"):
        component(
            "programmer",
            notice.stem,
            programmer_versions.get(notice.stem, "see-original-runtime-notice"),
            "see-original-notice",
            [notice],
            "native-programmer-and-collected-libraries",
        )

    viewer_manifest = SOFTWARE / "resources/content/viewer/runtime-manifest.json"
    viewer = json.loads(viewer_manifest.read_text())
    unresolved = [
        {
            "component": "viewer-static.min.js",
            "sha256": viewer["sha256"],
            "reason": "Upstream commit/version is unknown. The runtime declares Apache-2.0 and embeds additional third-party license headers; complete attribution is unresolved.",
        },
        {
            "component": "CPython standalone and native extensions",
            "reason": "Collecting the CPython/package licenses does not identify every statically linked native dependency or satisfy source-availability obligations automatically.",
        },
        {
            "component": "GUI bundle",
            "reason": "The production npm graph is conservative. Bundle attribution, required notices and any source obligations require review before final distribution.",
        },
    ]
    lock_matches_product = digest(lock_path) == product_manifest["locks"]["gui/package-lock.json"]
    if not lock_matches_product:
        unresolved.append(
            {
                "component": "package-lock.json",
                "reason": "Current lock metadata differs from the tested archive manifest. Preserve the archive identity and rebuild its manifest before claiming a new distribution.",
            }
        )
    counts = {
        status: sum(c["notice_status"] == status for c in components)
        for status in (
            "notices_included",
            "notices_not_matched_as_files",
            "notice_not_available_locally",
        )
    }
    report = {
        "schema_version": 1,
        "kind": "technical-notice-audit",
        "method": "Exact SHA-256 matches of standalone notice files. Does not prove absence from concatenated HTML, ASAR or compiled bundles, and does not approve redistribution.",
        "redistribution_approved": False,
        "product": str(product),
        "product_manifest_sha256": digest(product / "verification-manifest.json"),
        "lock_matches_product_manifest": lock_matches_product,
        "inputs": {str(file): digest(file) for file in [lock_path, viewer_manifest, *analyses]},
        "components": components,
        "summary": counts,
        "unresolved": unresolved,
    }
    (output / "audit.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("product", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = audit(args.product.resolve(), args.output.resolve())
    print(
        json.dumps(
            {
                "components": len(report["components"]),
                **report["summary"],
                "unresolved": len(report["unresolved"]),
                "redistribution_approved": False,
            }
        )
    )
