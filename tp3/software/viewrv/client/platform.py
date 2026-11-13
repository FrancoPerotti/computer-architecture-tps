"""Per-user coordination paths, private files and OS-owned instance lock."""

import errno
import json
import os
import tempfile
from pathlib import Path


def _xdg(name, fallback):
    value = os.environ.get(name, "")
    return Path(value) if value and Path(value).is_absolute() else Path.home() / fallback


def state_directory():
    if os.name == "nt":
        import ctypes
        import uuid
        from ctypes import wintypes

        shell = ctypes.WinDLL("shell32", use_last_error=True)
        ole = ctypes.WinDLL("ole32", use_last_error=True)
        shell.SHGetKnownFolderPath.argtypes = [
            ctypes.c_void_p,
            wintypes.DWORD,
            wintypes.HANDLE,
            ctypes.POINTER(wintypes.LPWSTR),
        ]
        shell.SHGetKnownFolderPath.restype = ctypes.c_long
        ole.CoTaskMemFree.argtypes = [ctypes.c_void_p]
        guid = (ctypes.c_ubyte * 16).from_buffer_copy(
            uuid.UUID("f1b32785-6fba-4fcf-9d55-7b8e7f157091").bytes_le
        )
        value = wintypes.LPWSTR()
        result = shell.SHGetKnownFolderPath(ctypes.byref(guid), 0, None, ctypes.byref(value))
        if result != 0:
            raise OSError("No se pudo resolver LocalAppData")
        try:
            return Path(value.value) / "viewrv"
        finally:
            ole.CoTaskMemFree(ctypes.cast(value, ctypes.c_void_p))
    return _xdg("XDG_STATE_HOME", ".local/state") / "viewrv"


def runtime_directory():
    if os.name != "nt":
        raw = os.environ.get("XDG_RUNTIME_DIR", "")
        if raw and Path(raw).is_absolute() and Path(raw).is_dir() and os.access(raw, os.W_OK):
            return Path(raw) / "viewrv"
    return state_directory() / "runtime"


def make_private(path, directory=False):
    """Restrict access to this account before publishing any credential."""
    if os.name != "nt":
        path.chmod(0o700 if directory else 0o600)
        return
    import ctypes
    from ctypes import wintypes

    # Protected DACL for the current account; never inherit broad parent access.
    advapi = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetCurrentProcess.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    kernel.LocalFree.restype = ctypes.c_void_p
    advapi.OpenProcessToken.argtypes = [
        wintypes.HANDLE,
        wintypes.DWORD,
        ctypes.POINTER(wintypes.HANDLE),
    ]
    advapi.GetTokenInformation.argtypes = [
        wintypes.HANDLE,
        ctypes.c_int,
        ctypes.c_void_p,
        wintypes.DWORD,
        ctypes.POINTER(wintypes.DWORD),
    ]
    advapi.ConvertStringSecurityDescriptorToSecurityDescriptorW.argtypes = [
        wintypes.LPCWSTR,
        wintypes.DWORD,
        ctypes.POINTER(ctypes.c_void_p),
        ctypes.c_void_p,
    ]
    advapi.SetFileSecurityW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, ctypes.c_void_p]
    token = wintypes.HANDLE()
    descriptor = ctypes.c_void_p()
    sid_text = wintypes.LPWSTR()
    try:
        if not advapi.OpenProcessToken(kernel.GetCurrentProcess(), 8, ctypes.byref(token)):
            raise ctypes.WinError(ctypes.get_last_error())
        size = wintypes.DWORD()
        advapi.GetTokenInformation(token, 1, None, 0, ctypes.byref(size))
        info = ctypes.create_string_buffer(size.value)
        if not advapi.GetTokenInformation(token, 1, info, size, ctypes.byref(size)):
            raise ctypes.WinError(ctypes.get_last_error())
        sid = ctypes.cast(info, ctypes.POINTER(ctypes.c_void_p))[0]
        advapi.ConvertSidToStringSidW.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.LPWSTR)]
        if not advapi.ConvertSidToStringSidW(sid, ctypes.byref(sid_text)):
            raise ctypes.WinError(ctypes.get_last_error())
        sddl = f"D:P(A;{'OICI' if directory else ''};FA;;;{sid_text.value})"
        if not advapi.ConvertStringSecurityDescriptorToSecurityDescriptorW(
            sddl, 1, ctypes.byref(descriptor), None
        ):
            raise ctypes.WinError(ctypes.get_last_error())
        if not advapi.SetFileSecurityW(str(path), 0x80000004, descriptor):
            raise ctypes.WinError(ctypes.get_last_error())
    finally:
        kernel.LocalFree(descriptor)
        kernel.LocalFree(ctypes.cast(sid_text, ctypes.c_void_p))
        if token:
            kernel.CloseHandle(token)


def private_directory(path):
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    make_private(path, directory=True)
    return path


def publish_discovery(path, discovery):
    private_directory(path.parent)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=".core-", suffix=".json")
    temp = Path(name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            make_private(temp)
            json.dump(discovery, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


class InstanceGuard:
    """The stable file is never removed, including after an unexpected exit."""

    def __init__(self, path=None):
        self.path = path or state_directory() / "core.lock"
        self.stream = None

    def acquire(self):
        private_directory(self.path.parent)
        fd = os.open(self.path, os.O_CREAT | os.O_RDWR, 0o600)
        self.stream = os.fdopen(fd, "r+b", buffering=0)
        os.set_inheritable(fd, False)
        try:
            make_private(self.path)
        except BaseException:
            self.release()
            raise
        try:
            if os.name == "nt":
                import msvcrt

                if self.path.stat().st_size == 0:
                    self.stream.write(b"\0")
                self.stream.seek(0)
                msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
            else:
                import fcntl

                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            self.release()
            if error.errno in {errno.EACCES, errno.EAGAIN, errno.EDEADLK, errno.EBUSY}:
                return False
            raise
        return True

    def release(self):
        if self.stream is not None:
            self.stream.close()
            self.stream = None

    def __enter__(self):
        if not self.acquire():
            raise BlockingIOError("El core ya conserva la exclusión")
        return self

    def __exit__(self, *_):
        self.release()


def data_directory():
    if os.name == "nt":
        return state_directory()
    return _xdg("XDG_DATA_HOME", ".local/share") / "viewrv"


def config_directory():
    if os.name == "nt":
        return state_directory()
    return _xdg("XDG_CONFIG_HOME", ".config") / "viewrv"
