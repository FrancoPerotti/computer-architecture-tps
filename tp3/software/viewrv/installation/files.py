"""Validated inventories and reversible, same-filesystem replacements."""

import ctypes
import hashlib
import json
import os
import stat
from pathlib import PurePosixPath


class MaintenanceError(Exception):
    """A maintenance refusal that leaves existing user resources untouched."""


def digest(path):
    """Hash a regular payload without loading the entire file into memory."""
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def relative(value):
    """Reject absolute, normalized-away and escaping inventory paths."""
    if not isinstance(value, str):
        raise MaintenanceError("Ruta de inventario inválida.")
    path = PurePosixPath(value)
    if (
        not value
        or value == "."
        or path.is_absolute()
        or path.as_posix() != value
        or ".." in path.parts
    ):
        raise MaintenanceError("Ruta de inventario fuera del producto.")
    return path


def describe(path, name, *, confined=True):
    """Describe one inode without following a symlink."""
    info = path.lstat()
    entry = {"path": name, "mode": stat.S_IMODE(info.st_mode)}
    if stat.S_ISLNK(info.st_mode):
        target = os.readlink(path)
        # Internal links may go up a directory, but must remain inside the product.
        parts = list(PurePosixPath(name).parent.parts)
        if confined and os.path.isabs(target):
            raise MaintenanceError(f"Enlace absoluto no admitido: {name}")
        for part in PurePosixPath(target).parts:
            if part == "..":
                if confined and not parts:
                    raise MaintenanceError(f"Enlace fuera del producto: {name}")
                if parts:
                    parts.pop()
            elif part != ".":
                parts.append(part)
        entry.update(kind="link", target=target)
    elif stat.S_ISDIR(info.st_mode):
        entry["kind"] = "directory"
    elif stat.S_ISREG(info.st_mode) and info.st_nlink == 1:
        entry.update(kind="file", size=info.st_size, sha256=digest(path))
    else:
        raise MaintenanceError(f"Tipo de archivo no admitido: {name}")
    return entry


def inventory(root, excluded=(), *, confined=True):
    """Visit directories in a stable order, never traversing symlinks."""
    entries = []

    def visit(directory):
        for path in sorted(directory.iterdir()):
            name = path.relative_to(root).as_posix()
            if name in excluded:
                continue
            entry = describe(path, name, confined=confined)
            entries.append(entry)
            if entry["kind"] == "directory":
                visit(path)

    visit(root)
    return entries


def validate_entries(entries):
    """Check inventory shape and parent types before accessing any child."""
    if not isinstance(entries, list):
        raise MaintenanceError("Inventario de archivos inválido.")
    by_path = {}
    for entry in entries:
        if not isinstance(entry, dict):
            raise MaintenanceError("Entrada de inventario inválida.")
        path = relative(entry.get("path"))
        if str(path) in by_path or entry.get("kind") not in {"file", "directory", "link"}:
            raise MaintenanceError("Entrada repetida o tipo inválido en el inventario.")
        if not isinstance(entry.get("mode"), int) or entry["mode"] & ~0o777:
            raise MaintenanceError("Permisos no admitidos en el inventario.")
        by_path[str(path)] = entry
    for name in by_path:
        for parent in PurePosixPath(name).parents:
            if str(parent) != "." and by_path.get(str(parent), {}).get("kind") != "directory":
                raise MaintenanceError("Un ancestro del archivo no es un directorio inventariado.")
    return by_path


def verify(root, entries):
    """Compare current types, modes, link targets and file bytes to an inventory."""
    by_path = validate_entries(entries)
    # Check parents before children; never follow a substituted directory symlink.
    for name in sorted(by_path, key=lambda value: (value.count("/"), value)):
        try:
            actual = describe(root / name, name)
        except OSError as error:
            raise MaintenanceError(f"No se puede comprobar el archivo: {name}") from error
        if actual != by_path[name]:
            raise MaintenanceError(f"Archivo modificado o inconsistente: {name}")


def write_json(path, value):
    """Create and flush a new manifest without overwriting an existing file."""
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def read_json(path):
    """Read a regular manifest and report invalid JSON as a maintenance refusal."""
    try:
        if not path.is_file() or path.is_symlink():
            raise MaintenanceError(f"Falta un inventario regular: {path.name}")
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise MaintenanceError(f"No se pudo leer el inventario: {path.name}") from error


def rename(source, destination, *, exchange=False):
    """No silent overwrite: exchange existing entries, or require an absent target."""
    libc = ctypes.CDLL(None, use_errno=True)
    function = libc.renameat2
    function.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    function.restype = ctypes.c_int
    if function(-100, os.fsencode(source), -100, os.fsencode(destination), 2 if exchange else 1):
        code = ctypes.get_errno()
        raise OSError(code, os.strerror(code), str(destination))


def sync_directory(path):
    """Flush directory entry changes before discarding transaction backups."""
    fd = os.open(path, os.O_DIRECTORY | os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
