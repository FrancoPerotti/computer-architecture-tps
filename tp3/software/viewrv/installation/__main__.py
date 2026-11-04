"""Frozen Linux maintenance helper. It never requires a system Python runtime."""

import argparse
import fcntl
import os
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

from ..client.platform import InstanceGuard, state_directory
from .files import MaintenanceError
from .service import maintain


def inherited_lease():
    """Require the stable exclusive kernel lock passed by the native launcher."""
    try:
        fd = int(os.environ.pop("VIEWRV_MAINTENANCE_FD", "-1"))
        if fd < 3:
            raise ValueError
        own = os.fstat(fd)
        path = state_directory() / "maintenance.lock"
        info = path.lstat()
        if (
            (own.st_dev, own.st_ino) != (info.st_dev, info.st_ino)
            or not stat.S_ISREG(info.st_mode)
            or info.st_uid != os.getuid()
            or info.st_nlink != 1
        ):
            raise ValueError
        # This fd must already own an exclusive lease. A separate shared open
        # must be rejected; then reassert exclusivity on the inherited description.
        probe = os.open(path, os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            try:
                fcntl.flock(probe, fcntl.LOCK_SH | fcntl.LOCK_NB)
            except BlockingIOError:
                pass
            else:
                raise ValueError
        finally:
            os.close(probe)
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        os.set_inheritable(fd, False)
        return fd
    except (OSError, ValueError) as error:
        raise MaintenanceError(
            "Ejecutá install.sh o uninstall.sh para mantener el producto con exclusión."
        ) from error


def _bootstrap(fd, arguments):
    executable = Path(sys.executable)
    # The worker uses its private runtime, so it can exchange or remove the
    # installed tree without lazily importing modules from that tree afterward.
    interrupted = []

    def defer(number, _frame):
        interrupted.append(number)

    signals = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT)
    handlers = {number: signal.signal(number, defer) for number in signals}
    try:
        with tempfile.TemporaryDirectory(prefix="viewrv-maintenance-") as directory:
            root = Path(directory)
            shutil.copy2(executable, root / executable.name)
            shutil.copytree(
                executable.parent / "_internal_cli", root / "_internal_cli", symlinks=True
            )
            environment = {**os.environ, "VIEWRV_MAINTENANCE_FD": str(fd)}
            with subprocess.Popen(
                [str(root / executable.name), "--worker", *arguments],
                env=environment,
                pass_fds=(fd,),
            ) as child:
                code = child.wait()
        return code if code else 128 + interrupted[0] if interrupted else 0
    finally:
        for number, handler in handlers.items():
            signal.signal(number, handler)


def main(argv=None):
    """Run the private maintenance worker or bootstrap its disposable runtime."""
    arguments = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(description="Instalación por usuario de viewrv para Linux.")
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("operation", choices=("install", "uninstall"))
    parser.add_argument("--source", type=Path)
    args = parser.parse_args(arguments)
    try:
        if sys.platform != "linux" or os.getuid() == 0:
            raise MaintenanceError("El mantenimiento se ejecuta como usuario normal en Linux.")
        if (args.operation == "install") != (args.source is not None):
            raise MaintenanceError("Instalar requiere --source; desinstalar no recibe una fuente.")
        fd = inherited_lease()
        if not args.worker:
            if not getattr(sys, "frozen", False):
                raise MaintenanceError("Usá el ayudante nativo incluido en el paquete Linux.")
            return _bootstrap(fd, arguments)
        # Finish or roll back the short filesystem transaction before handling
        # cancellation. The supervising helper records terminal cancellation.
        previous_mask = signal.pthread_sigmask(
            signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT}
        )
        try:
            guard = InstanceGuard()
            if not guard.acquire():
                raise MaintenanceError(
                    "El core está en uso. Cerrá la GUI y finalizá explícitamente los trabajos CLI."
                )
            try:
                print(maintain(args.operation, args.source))
            finally:
                guard.release()
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        return 0
    except (MaintenanceError, OSError) as error:
        print(f"viewrv: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
