"""Per-user Linux maintenance; all mutations run under the product and core locks."""

import os
import shutil
import stat
import tempfile
from pathlib import Path

from .files import (
    MaintenanceError,
    describe,
    digest,
    inventory,
    read_json,
    relative,
    rename,
    sync_directory,
    verify,
    write_json,
)

MANIFEST = "install-manifest.json"
APP_ID = "ar.edu.tp3.viewrv"


def user_paths():
    """Resolve only per-user installation and desktop access destinations."""
    home = Path.home()
    if not home.is_absolute():
        raise MaintenanceError("HOME debe ser una ruta absoluta.")
    data = os.environ.get("XDG_DATA_HOME", "")
    data = Path(data) if data.startswith("/") else home / ".local/share"
    paths = (
        home / ".local/opt/viewrv",
        home / ".local/bin/viewrv",
        data / "applications/viewrv.desktop",
    )
    if any(any(char in str(path) for char in "\n\r\x00") for path in paths):
        raise MaintenanceError("Las rutas de instalación no admiten saltos de línea.")
    if "=" in str(paths[0]):
        raise MaintenanceError("El acceso de escritorio no admite '=' en la ruta del ejecutable.")
    return paths


def _exists(path):
    return path.exists() or path.is_symlink()


def _regular_directory(path):
    if path.is_symlink() or not path.is_dir() or path.stat().st_uid != os.getuid():
        raise MaintenanceError(f"El destino no es un directorio propio: {path}")


def installed(root):
    """Recognize an owned installation and refuse changed product files."""
    if not _exists(root):
        return None
    _regular_directory(root)
    value = read_json(root / MANIFEST)
    if (
        not isinstance(value, dict)
        or value.get("schema_version") != 1
        or value.get("app_id") != APP_ID
        or value.get("root") != str(root)
        or not isinstance(value.get("installed"), bool)
    ):
        raise MaintenanceError("El destino contiene una instalación no reconocida.")
    verify(root, value.get("files"))
    if any(entry["path"] == MANIFEST for entry in value["files"]):
        raise MaintenanceError("El inventario no puede incluirse a sí mismo.")
    if not isinstance(value.get("accesses"), dict):
        raise MaintenanceError("Inventario de accesos inválido.")
    return value


def package_files(source):
    """Validate a complete Linux package and its coordinated native entry points."""
    _regular_directory(source)
    descriptor = read_json(source / "linux-launchers.json")
    if not isinstance(descriptor, dict) or descriptor.get("schema_version") != 1:
        raise MaintenanceError("El paquete no dispone de arranques Linux coordinados.")
    required = {"viewrv", "viewrv-gui", "resources/core/viewrv-core", "viewrv-maintenance"}
    launchers = descriptor.get("launchers", {})
    if not isinstance(launchers, dict) or set(launchers) != required:
        raise MaintenanceError("Las entradas Linux del paquete están incompletas.")
    # Both archive types inventory their complete payload. Hashes provide
    # consistency, not publisher authentication.
    name = (
        "verification-manifest.json"
        if (source / "VERIFICATION-ONLY.txt").exists()
        else "linux-package.json"
    )
    package = read_json(source / name)
    if not isinstance(package, dict) or package.get("schema_version") != 1:
        raise MaintenanceError("Inventario de paquete no reconocido.")
    entries = package.get("files")
    if name == "verification-manifest.json":
        # The portable verifier lists regular files only; reconstruct parents
        # from the actual tree and retain its explicit byte/mode checks.
        if not isinstance(entries, list):
            raise MaintenanceError("Inventario de verificación inválido.")
        listed = {
            str(relative(entry.get("path"))): entry for entry in entries if isinstance(entry, dict)
        }
        actual = inventory(source, excluded=(name, MANIFEST), confined=False)
        if source == user_paths()[0] and installed(source):
            parents = {str(parent) for item in listed for parent in Path(item).parents}
            actual = [
                entry for entry in actual if entry["path"] in listed or entry["path"] in parents
            ]
        files = [entry for entry in actual if entry["kind"] != "directory"]
        if len(listed) != len(entries) or {entry["path"] for entry in files} != set(listed):
            raise MaintenanceError("El paquete contiene archivos no inventariados.")
        for entry in files:
            expected = listed[entry["path"]]
            if entry["kind"] != "file" or any(
                entry[key] != expected.get(key) for key in ("size", "mode", "sha256")
            ):
                raise MaintenanceError(f"Archivo de paquete inconsistente: {entry['path']}")
        entries = actual
    else:
        verify(source, entries)
    entries = [*entries, describe(source / name, name)]
    # Validate fixed paths without trusting arbitrary launcher names from JSON.
    by_path = {entry["path"]: entry for entry in entries}
    for name in required:
        payload = str(Path(name).with_name(f".{Path(name).name}-native"))
        for file in (name, payload):
            item = by_path.get(file, {})
            if item.get("kind") != "file" or not item.get("mode", 0) & 0o111:
                raise MaintenanceError(f"Falta una entrada nativa: {file}")
        expected = launchers[name]
        if expected != {
            "payload": payload,
            "sha256": digest(source / name),
            "payload_sha256": digest(source / payload),
        }:
            raise MaintenanceError(f"Entrada nativa inconsistente: {name}")
    verify(source, entries)
    return entries


def active_executables(roots):
    """Inspect current kernel executables; neither discovery JSON nor PID files count."""
    ancestors = set()
    pid = os.getpid()
    while pid > 1 and pid not in ancestors:
        ancestors.add(pid)
        try:
            pid = int(Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    roots = [root.resolve() for root in roots]
    for proc in Path("/proc").iterdir():
        if not proc.name.isdecimal():
            continue
        try:
            executable = Path(os.readlink(proc / "exe").removesuffix(" (deleted)"))
        except FileNotFoundError:
            continue
        except PermissionError:
            # Linux can hide exe for unrelated privileged helpers even when
            # their real uid matches ours (systemd --user, gpg-agent). Public
            # product starts are independently covered by the kernel lease.
            # An unreadable candidate belonging to this product still refuses
            # maintenance; its argv is only a conservative refusal, never proof
            # of an absent process and never a target for a signal.
            try:
                command = (proc / "cmdline").read_bytes().split(b"\0", 1)[0]
                candidate = Path(os.fsdecode(command))
                name = (proc / "comm").read_text().strip()
            except FileNotFoundError:
                continue
            except PermissionError:
                if proc.stat().st_uid == os.getuid():
                    raise MaintenanceError("No se pudo comprobar un proceso del usuario.") from None
                continue
            if any(candidate.is_relative_to(root) for root in roots) or name.startswith(
                ("viewrv", ".viewrv")
            ):
                raise MaintenanceError(
                    "No se pudo comprobar un componente de viewrv en uso."
                ) from None
            continue
        if not any(executable.is_relative_to(root) for root in roots):
            continue
        if int(proc.name) in ancestors and executable.name in {
            "viewrv-maintenance",
            ".viewrv-maintenance-native",
        }:
            continue
        raise MaintenanceError(
            f"Hay un componente en uso: {executable.name}. Cerralo antes del mantenimiento."
        )


def _access(path):
    if not _exists(path):
        return None
    if path.is_symlink():
        return {"kind": "link", "target": os.readlink(path)}
    info = path.lstat()
    if stat.S_ISREG(info.st_mode) and info.st_nlink == 1:
        return {"kind": "file", "sha256": digest(path), "mode": stat.S_IMODE(info.st_mode)}
    raise MaintenanceError(f"El acceso no es un archivo propio: {path}")


def _desktop(root):
    # Exec is not a shell command; freedesktop escaping is intentionally separate.
    executable = str(root / "viewrv-gui").replace("%", "%%")
    for char in ("\\", '"', "`", "$"):
        executable = executable.replace(char, "\\" + char)
    # Desktop string decoding precedes Exec argument decoding, so double the
    # quoting backslashes once more (freedesktop Desktop Entry specification).
    executable = executable.replace("\\", "\\\\").replace("\t", "\\t")
    icon = str(root / "resources/icons/viewrv.svg").replace("\\", "\\\\").replace("\t", "\\t")
    return (
        "[Desktop Entry]\nType=Application\nName=viewrv\n"
        # GIO checks the executable before expanding %% in its path. env makes
        # the product path an argument, expanded once, without using a shell.
        f'Exec=/usr/bin/env -- "{executable}"\nIcon={icon}\nTerminal=false\nCategories=Education;\n'
    )


def _copy_entries(source, target, entries):
    entries = sorted(entries, key=lambda entry: (entry["path"].count("/"), entry["path"]))
    for entry in entries:
        source_path, target_path = source / entry["path"], target / entry["path"]
        kind = entry["kind"]
        if kind == "directory":
            target_path.mkdir(exist_ok=True)
        elif kind == "link":
            target_path.symlink_to(entry["target"])
        else:
            shutil.copy2(source_path, target_path, follow_symlinks=False)
    # Only after copying descendants, restore possibly read-only directory modes.
    for entry in reversed(entries):
        if entry["kind"] == "directory":
            (target / entry["path"]).chmod(entry["mode"])


def maintain(operation, source=None):
    """Caller holds the exclusive launch lease and the existing core InstanceGuard."""
    root, cli, desktop = user_paths()
    previous = installed(root)
    if operation == "uninstall" and previous is None:
        return "No hay una instalación por usuario para retirar."
    source = source.resolve() if source else None
    roots = [root, *([source] if source else [])]
    active_executables(roots)
    entries = package_files(source) if operation == "install" else []
    accesses = (cli, desktop)
    expected_accesses = previous.get("accesses", {}) if previous else {}
    if set(expected_accesses) not in (set(), {str(path) for path in accesses}):
        raise MaintenanceError("El inventario de accesos no corresponde a este usuario.")
    snapshots = {str(path): _access(path) for path in accesses}
    for path in accesses:
        if snapshots[str(path)] != expected_accesses.get(str(path)):
            raise MaintenanceError(f"El acceso es ajeno o fue modificado: {path}")
    owned = {entry["path"] for entry in previous["files"]} if previous else set()
    old_tree = inventory(root, (MANIFEST,), confined=False) if previous else []
    unknown = [entry for entry in old_tree if entry["path"] not in owned]
    incoming = {entry["path"]: entry for entry in entries}
    for entry in unknown:
        if entry["path"] in incoming and not (
            entry["kind"] == incoming[entry["path"]]["kind"] == "directory"
        ):
            raise MaintenanceError(
                f"Un archivo del usuario ocupa un destino del paquete: {entry['path']}"
            )
        for parent in Path(entry["path"]).parents:
            if str(parent) in incoming and incoming[str(parent)]["kind"] != "directory":
                raise MaintenanceError("El paquete ocupa un directorio con datos del usuario.")
    root.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".viewrv-stage-", dir=root.parent))
    swaps = []
    root_committed = False
    access_stages = []
    cleanup_ok = True
    try:
        if source:
            _copy_entries(source, stage, entries)
        verify(stage, entries)
        # Include owned parent directories only as containers for unknown data;
        # they are not owned by the next uninstall unless present in the package.
        for entry in unknown:
            (stage / entry["path"]).parent.mkdir(parents=True, exist_ok=True)
        _copy_entries(root, stage, [entry for entry in unknown if entry["path"] not in incoming])
        verify(stage, entries)
        for entry in unknown:
            if (
                entry["path"] not in incoming
                and describe(stage / entry["path"], entry["path"], confined=False) != entry
            ):
                raise MaintenanceError("Un archivo del usuario cambió durante la copia.")
        next_accesses = {}
        for path in accesses:
            path.parent.mkdir(parents=True, exist_ok=True)
            fd, name = tempfile.mkstemp(prefix=".viewrv-access-", dir=path.parent)
            os.close(fd)
            temp = Path(name)
            access_stages.append(temp)
            if operation == "install":
                if path == cli:
                    temp.unlink()
                    temp.symlink_to(root / "viewrv")
                else:
                    temp.write_text(_desktop(root), encoding="utf-8")
                    temp.chmod(0o644)
                next_accesses[str(path)] = _access(temp)
        write_json(
            stage / MANIFEST,
            {
                "schema_version": 1,
                "app_id": APP_ID,
                "root": str(root),
                "installed": operation == "install",
                "files": entries,
                "accesses": next_accesses,
            },
        )
        sync_directory(stage)
        if source:
            verify(source, entries)
        if previous:
            if (
                installed(root) != previous
                or inventory(root, (MANIFEST,), confined=False) != old_tree
            ):
                raise MaintenanceError("La instalación cambió durante la preparación.")
        active_executables(roots)
        for path in accesses:
            if _access(path) != snapshots[str(path)]:
                raise MaintenanceError("Un acceso cambió durante la preparación.")
        rename(stage, root, exchange=previous is not None)
        root_committed = True
        if previous and (
            read_json(stage / MANIFEST) != previous
            or inventory(stage, (MANIFEST,), confined=False) != old_tree
        ):
            raise MaintenanceError("La instalación cambió durante la sustitución.")
        for path, temp in zip(accesses, access_stages, strict=True):
            exists = snapshots[str(path)] is not None
            if operation == "install":
                rename(temp, path, exchange=exists)
                swaps.append((path, temp, exists))
                if exists and _access(temp) != snapshots[str(path)]:
                    raise MaintenanceError("Un acceso cambió durante la sustitución.")
            elif exists:
                temp.unlink()
                rename(path, temp)
                swaps.append((path, temp, True))
                if _access(temp) != snapshots[str(path)]:
                    raise MaintenanceError("Un acceso cambió durante la retirada.")
            sync_directory(path.parent)
        sync_directory(root.parent)
    except BaseException:
        # Preserve backups if rollback itself fails; never erase the only copy.
        try:
            for path, temp, existed in reversed(swaps):
                if operation == "install" and existed:
                    rename(temp, path, exchange=True)
                elif operation == "install":
                    rename(path, temp)
                else:
                    rename(temp, path)
            if root_committed:
                if previous:
                    rename(stage, root, exchange=True)
                else:
                    rename(root, stage)
        except OSError as rollback_error:
            cleanup_ok = False
            raise MaintenanceError(
                f"No se pudo restaurar completamente; conservá el respaldo {stage}"
            ) from rollback_error
        raise
    finally:
        if cleanup_ok:
            if stage.exists():
                shutil.rmtree(stage)
            for temp in access_stages:
                temp.unlink(missing_ok=True)
    if operation == "uninstall" and list(root.iterdir()) == [root / MANIFEST]:
        (root / MANIFEST).unlink()
        root.rmdir()
    warning = ""
    if operation == "install" and str(cli.parent) not in os.environ.get("PATH", "").split(
        os.pathsep
    ):
        warning = f"\n{cli.parent} no está en PATH; usá su ruta completa o agregalo en una terminal nueva. No se modificó tu shell."
    return (
        f"viewrv instalado en {root}."
        if operation == "install"
        else "viewrv desinstalado; los archivos y datos del usuario se conservan."
    ) + warning
