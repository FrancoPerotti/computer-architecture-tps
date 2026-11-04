"""Importar una copia trazable del visor aprobado, sin modificar su repositorio."""

import argparse
import base64
import hashlib
import json
import re
import shutil
import subprocess
import sys
import urllib.parse
import zlib
from pathlib import Path

SOFTWARE = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    sys.path.insert(0, str(SOFTWARE.parent))
    from software.packaging.prepare_education import observable_fields

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument(
        "--output", type=Path, help="Directorio de contenido para una importación aislada."
    )
    args = parser.parse_args()
    source = args.source.resolve()
    content = args.output.resolve() if args.output else SOFTWARE / "resources/content"
    viewer = content / "viewer"
    viewer.mkdir(parents=True, exist_ok=True)
    copies = {
        "riscv-pipeline-viewer.html": viewer / "index.html",
        "diagramas/TP3_PIPELINE_COMPLETO.drawio.xml": viewer / "source-diagram.drawio.xml",
        "vendor/viewer-static.min.js": viewer / "viewer-static.min.js",
        "vendor/manifest.json": viewer / "runtime-manifest.json",
    }
    for name in (
        "inter-400.ttf",
        "inter-500.ttf",
        "inter-600.ttf",
        "ibm-plex-mono-400.ttf",
        "ibm-plex-mono-500.ttf",
        "ibm-plex-mono-600.ttf",
        "inter-OFL.txt",
        "ibm-plex-mono-OFL.txt",
    ):
        copies[f"assets/{name}"] = content / "fonts" / name
    runtime_hash = digest(source / "vendor/viewer-static.min.js")
    if runtime_hash != "32c73b8e42e784d0ace7d59754cbea6c2a78a0f506d390e2a3870546b9242f7c":
        raise ValueError("El runtime no coincide con el diseño aprobado")
    for relative, target in copies.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / relative, target)
    revision = subprocess.check_output(
        ["git", "-C", str(source), "rev-parse", "HEAD"], text=True
    ).strip()
    provenance = {
        "source_revision": revision,
        "files": [
            {"source": name, "path": str(target.relative_to(content)), "sha256": digest(target)}
            for name, target in copies.items()
        ],
    }
    packed = json.loads(
        re.search(
            r'<script id="diagram-data"[^>]*>(.*?)</script>',
            (viewer / "index.html").read_text(encoding="utf-8"),
            re.S,
        )[1]
    )

    def unpack(value):
        return urllib.parse.unquote(zlib.decompress(base64.b64decode(value), -15).decode())

    payload = json.loads(unpack(packed["compressed"]))
    (content / "diagram.drawio.xml").write_text(
        unpack(payload["xml"]), encoding="utf-8", newline="\n"
    )
    provenance["derived"] = [
        {
            "source": "viewer/index.html#diagram-data.xml",
            "path": "diagram.drawio.xml",
            "sha256": digest(content / "diagram.drawio.xml"),
        }
    ]
    (viewer / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    specification = (SOFTWARE.parent / "docs/software/viewrv/gui_y_visor.md").read_text()
    bindings = dict(
        re.findall(
            r"^\| ([a-z]+\.[a-z0-9_]+) \| [^|]+ \| ([\w-]+)(?: \(interno\))? \|$",
            specification,
            re.M,
        )
    )
    (content / "diagram_bindings.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "blocks": bindings,
                "source_blocks": bindings,
                "source_representations": {"session.pipeline_empty": ["tp3-exec-empty"]},
                "cell_ids": {},
                "representations": {"session.pipeline_empty": ["tp3-exec-empty"]},
            },
            indent=2,
        )
        + "\n"
    )
    profile = {
        "schema_version": 1,
        "profile_id": "tp3-riscv",
        "revision": 1,
        "memory_profile": "REFERENCE",
        "architecture_source": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=SOFTWARE, text=True
        ).strip(),
        "diagram_sha256": digest(content / "diagram.drawio.xml"),
        "bindings_sha256": digest(content / "diagram_bindings.json"),
        "instruction_ids": sorted(
            path.stem.upper() for path in (source / "contenido/instrucciones").glob("*.json")
        ),
        "observable_fields": observable_fields(),
    }
    (content / "processor_profile.json").write_text(json.dumps(profile, indent=2) + "\n")
    print(f"Visor {revision[:7]} importado; runtime {runtime_hash}; {len(bindings)} bloques.")


if __name__ == "__main__":
    main()
