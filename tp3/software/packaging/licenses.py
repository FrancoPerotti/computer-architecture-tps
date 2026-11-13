"""Materialize reviewed third-party notices and corresponding sources without network at build time."""

import argparse
import hashlib
import html
import json
import shutil
import tempfile
import urllib.request
from pathlib import Path, PurePosixPath

SOFTWARE = Path(__file__).resolve().parents[1]


def digest(path):
    """Hash a file without loading source archives into memory."""
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def contained(root, name):
    """Reject ambiguous paths and symlinks before accessing reviewed material."""
    path = PurePosixPath(name)
    if (
        not name
        or path.is_absolute()
        or "\\" in name
        or any(part in {"", ".", ".."} for part in name.split("/"))
    ):
        raise ValueError(f"Ruta de licencia inválida: {name}")
    result = root.joinpath(*path.parts)
    current = root
    for part in path.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"Enlace no admitido en material de licencias: {name}")
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Recurso fuera del directorio: {name}")
    return result


def checked(root, item):
    """Return a file only when its reviewed bytes are available."""
    path = contained(root, item["path"])
    if not path.is_file() or digest(path) != item["sha256"]:
        raise ValueError(f"Falta o cambió el material de licencias: {item['path']}")
    return path


def load(software=SOFTWARE):
    """Read the curated lock; this file is reviewed, not inferred from SPDX labels."""
    lock = json.loads((software / "packaging/licenses-linux.lock.json").read_text())
    if lock["schema_version"] != 1 or lock["platform"] != "linux-x86_64":
        raise ValueError("Falta revisar las licencias para la plataforma solicitada.")
    names = [item["path"] for item in lock["sources"]]
    if len(set(names)) != len(names):
        raise ValueError("Fuentes de terceros repetidas en el lock.")
    return lock


def validate(software=SOFTWARE, *, sources=True):
    """Refuse stale dependencies, notices, reviewed resources or missing sources."""
    lock = load(software)
    for item in lock["reviewed_inputs"]:
        checked(software, item)
    for item in lock["notices"]:
        checked(software / "resources/licenses", item)
    if sources:
        for item in lock["sources"]:
            checked(software / "build/license-sources", {**item, "path": item["cache_name"]})
    return lock


def fetch(software=SOFTWARE):
    """Download explicitly requested source files and atomically verify their hashes."""
    lock = validate(software, sources=False)
    cache = software / "build/license-sources"
    cache.mkdir(parents=True, exist_ok=True)
    for item in lock["sources"]:
        path = contained(cache, item["cache_name"])
        if path.is_file() and digest(path) == item["sha256"]:
            continue
        if not item["url"].startswith("https://"):
            raise ValueError("La descarga de fuentes requiere HTTPS.")
        with tempfile.NamedTemporaryFile(dir=cache, delete=False) as stream:
            temporary = Path(stream.name)
            try:
                with urllib.request.urlopen(item["url"], timeout=45) as response:
                    total = 0
                    while data := response.read(1024 * 1024):
                        total += len(data)
                        if total > item["size"]:
                            raise ValueError(f"Tamaño inesperado: {item['cache_name']}")
                        stream.write(data)
                stream.flush()
                if total != item["size"] or digest(temporary) != item["sha256"]:
                    raise ValueError(f"Descarga incompleta o alterada: {item['cache_name']}")
                temporary.replace(path)
            finally:
                temporary.unlink(missing_ok=True)
        print(f"Fuente verificada: {item['cache_name']}")


def render_index(lock):
    """Create an offline HTML index; every field is escaped and links stay relative."""
    escape = html.escape
    rows = []
    for item in lock["components"]:
        links = " · ".join(
            f'<a href="{escape(path, quote=True)}">{escape(PurePosixPath(path).name)}</a>'
            for path in item["notice_paths"]
        )
        rows.append(
            f'<tr><th scope="row">{escape(item["name"])}</th>'
            f"<td>{escape(item['version'])}</td><td>{escape(item['license'])}</td><td>{links}</td></tr>"
        )
    sources = "".join(
        f'<li><a href="{escape(item["path"], quote=True)}">{escape(item["cache_name"])}</a>'
        f" <code>SHA-256 {item['sha256']}</code></li>"
        for item in lock["sources"]
    )
    return (
        '<!doctype html><html lang="es"><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'\">"
        "<title>viewrv · Avisos y licencias</title><style>"
        "body{font:16px/1.5 system-ui,sans-serif;color:#243147;background:#f0f2f5;margin:0;padding:32px}"
        "main{max-width:1200px;margin:auto;background:white;border-radius:16px;padding:32px}"
        "h1{margin:0 0 8px}h2{margin-top:32px}a{color:#4936c9}"
        "table{border-collapse:collapse;width:100%;table-layout:fixed;font-size:14px}"
        "th,td{text-align:left;vertical-align:top;padding:12px;border-bottom:1px solid #e3e7ee;overflow-wrap:anywhere}"
        "thead th:nth-child(1){width:25%}thead th:nth-child(2){width:15%}"
        "thead th:nth-child(3){width:25%}thead th:nth-child(4){width:35%}"
        "thead{background:#f5f4fb}code{font-size:12px;overflow-wrap:anywhere}li{margin:12px 0}"
        ".table{overflow:auto}p{max-width:85ch}@media(max-width:650px){body,main{padding:16px}}"
        "</style><main><h1>Avisos y licencias</h1>"
        '<p>viewrv · Código propio: <a href="MIT.txt">MIT</a>. '
        "Copyright © 2026 Franco Perotti y Federico Arnaudo.</p>"
        "<p>Los componentes de terceros conservan sus licencias y atribuciones. "
        "Este índice y los textos enlazados están disponibles sin conexión.</p>"
        "<p>Se conservan también avisos de construcción y de otras plataformas presentes en los "
        "inventarios del editor de Pydantic Core y de Rust. Su presencia no demuestra que ese "
        "componente se enlace en el binario Linux; el manifiesto identifica ese alcance.</p>"
        '<p><a href="REBUILDING.md">Fuentes, reconstrucción y reemplazo de bibliotecas</a> · '
        '<a href="manifest.json">Inventario con huellas y procedencia</a> · '
        '<a href="LICENSING.md">Alcance de MIT</a></p>'
        '<div class="table"><table><thead><tr><th>Componente</th><th>Versión</th>'
        "<th>Licencia</th><th>Textos y atribuciones</th></tr></thead><tbody>"
        + "".join(rows)
        + "</tbody></table></div><h2>Fuentes correspondientes incluidas</h2><p>"
        "Los paquetes Ubuntu conservan sus fuentes originales, archivos .dsc y parches Debian/Ubuntu. "
        'Las fuentes de certifi se incluyen en <a href="sources/certifi-2026.10.23/LICENSE">'
        "sources/certifi-2026.10.23</a>. La fuente de openFPGALoader acompaña al programador "
        "en ../programmer/sources.</p><ul>" + sources + "</ul></main></html>\n"
    )


def stage(root, software=SOFTWARE, *, preview=False):
    """Include reviewed notices and exact source archives in an unpacked Linux product."""
    lock = validate(software)
    destination = software / "build/licenses" if preview else root / "resources/licenses"
    if destination.exists():
        raise ValueError("El producto ya contiene material de licencias; usá un destino nuevo.")
    runtime = lock["runtime_files"]
    for item in runtime:
        actual = item
        if item.get("alternative") and (root / item["alternative"]).is_file():
            actual = {**item, "path": item["alternative"]}
        checked(root, actual)
    destination.mkdir(parents=True)
    for item in lock["notices"]:
        file = checked(software / "resources/licenses", item)
        target = contained(destination, item["path"])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target)
    for item in lock["sources"]:
        target = contained(destination, item["path"])
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(software / "build/license-sources" / item["cache_name"], target)
    for item in lock["runtime_notices"]:
        shutil.copyfile(checked(root, item), destination / item["destination"])
    for source, name in (("LICENSE", "MIT.txt"), ("LICENSING.md", "LICENSING.md")):
        shutil.copyfile(software / source, destination / name)
    (destination / "manifest.json").write_text(
        json.dumps(lock, ensure_ascii=False, indent=2) + "\n"
    )
    (destination / "index.html").write_text(render_index(lock))
    return destination


def verify(destination):
    """Verify materialized licenses using only the product's own inventory."""
    lock = json.loads((destination / "manifest.json").read_text())
    expected = {"manifest.json", "index.html", "MIT.txt", "LICENSING.md"}
    for item in lock["notices"] + lock["sources"]:
        checked(destination, item)
        expected.add(item["path"])
    for item in lock["runtime_notices"]:
        checked(destination, {**item, "path": item["destination"]})
        expected.add(item["destination"])
    for source, name in (("LICENSE", "MIT.txt"), ("LICENSING.md", "LICENSING.md")):
        entry = next(item for item in lock["reviewed_inputs"] if item["path"] == source)
        checked(destination, {**entry, "path": name})
    for component in lock["components"]:
        if not component["notice_paths"] or any(
            name not in expected for name in component["notice_paths"]
        ):
            raise ValueError(f"Componente sin avisos incluidos: {component['name']}")
    actual = set()
    for path in destination.rglob("*"):
        if path.is_symlink():
            raise ValueError("Enlace no admitido en licencias empaquetadas.")
        if path.is_file():
            actual.add(path.relative_to(destination).as_posix())
    if actual != expected or (destination / "index.html").read_text() != render_index(lock):
        raise ValueError("El índice o los archivos de licencias empaquetados son inconsistentes.")
    return {
        "components": len(lock["components"]),
        "files": len(actual),
        "sources": len(lock["sources"]),
    }


def main():
    """Fetch explicitly, validate offline, or stage into a new package directory."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--stage", type=Path)
    parser.add_argument(
        "--preview",
        type=Path,
        help="Preparar el índice de desarrollo desde un producto verificado.",
    )
    parser.add_argument(
        "--verify", type=Path, help="Verificar material de un paquete sin depender de la caché."
    )
    args = parser.parse_args()
    if args.verify:
        print(json.dumps(verify(args.verify.resolve())))
        return
    if args.fetch:
        fetch()
    validate()
    if args.stage:
        print(verify(stage(args.stage.resolve())))
    if args.preview:
        print(stage(args.preview.resolve(), preview=True))


if __name__ == "__main__":
    main()
