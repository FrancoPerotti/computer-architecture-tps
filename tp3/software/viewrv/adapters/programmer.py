"""Verified local assets and supervised openFPGALoader 1.2.0 subprocesses."""

import asyncio
import hashlib
import json
import os
import platform
import re
import sys
from pathlib import Path

from software.viewrv.contracts import ApplicationError

ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
USB_ID = (0x0403, 0x6010)


def inside(root, name):
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()) or Path(name).is_absolute():
        raise ValueError("El recurso sale de su directorio de instalación.")
    return path


class HardwareAssets:
    def __init__(self, root, profile):
        self.root, self.profile = Path(root), profile

    def programmer(self):
        root = inside(self.root, "programmer")
        value = json.loads(inside(root, "manifest.json").read_text(encoding="utf-8"))
        target = {"Linux": "linux", "Windows": "windows"}.get(platform.system())
        if (
            target is None
            or not isinstance(value, dict)
            or type(value.get("schema_version")) is not int
            or value.get("schema_version") != 1
            or value.get("version") != "1.2.0"
            or value.get("platform") != target
            or value.get("architecture") != "x86_64"
        ):
            raise ValueError("El programador incluido no corresponde a esta plataforma.")
        executable = "openFPGALoader.exe" if target == "windows" else "openFPGALoader"
        if target == "windows" and value.get("non_system_dependencies_static") is not True:
            raise ValueError("El programador Windows no acredita sus dependencias estáticas.")
        files = value.get("files", [])
        if (
            not isinstance(files, list)
            or not files
            or any(
                not isinstance(item, dict)
                or not isinstance(item.get("path"), str)
                or not isinstance(item.get("sha256"), str)
                for item in files
            )
            or executable not in {item["path"] for item in files}
        ):
            raise ValueError("Falta el ejecutable del programador en su inventario.")
        for item in files:
            file = inside(root, item["path"])
            if hashlib.sha256(file.read_bytes()).hexdigest() != item["sha256"]:
                raise ValueError(
                    "No coincide la huella del recurso del programador: " + item["path"]
                )
        path = root / executable
        if os.name != "nt" and not os.access(path, os.X_OK):
            raise PermissionError("El programador incluido no tiene permiso de ejecución.")
        return path.resolve()

    def bitstream(self):
        root = inside(self.root, "hardware")
        value = json.loads(inside(root, "processor.json").read_text(encoding="utf-8"))
        if (
            not isinstance(value, dict)
            or type(value.get("schema_version")) is not int
            or value.get("schema_version") != 1
            or value.get("board") != "basys3"
            or value.get("processor_profile") != self.profile
            or not isinstance(value.get("source_revision"), str)
            or not re.fullmatch(r"[0-9a-f]{40}", value.get("source_revision", ""))
        ):
            raise ValueError("El bitstream no identifica el perfil aprobado de Basys 3.")
        path = inside(root, "processor.bit")
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError("Falta el bitstream del procesador.")
        if hashlib.sha256(path.read_bytes()).hexdigest() != value.get("sha256"):
            raise ValueError("La huella del bitstream no coincide con su descriptor.")
        return path.resolve()


def child_environment(executable, environment=None):
    result = dict(os.environ if environment is None else environment)
    for key in ("PYTHONHOME", "PYTHONPATH", "LD_PRELOAD"):
        result.pop(key, None)
    if os.name != "nt":
        original = result.get("LD_LIBRARY_PATH_ORIG", "")
        frozen = str(getattr(sys, "_MEIPASS", ""))
        paths = [str(executable.parent / "lib")]
        paths += [
            path
            for path in original.split(os.pathsep)
            if path and not (frozen and path.startswith(frozen))
        ]
        result["LD_LIBRARY_PATH"] = os.pathsep.join(paths)
        result.pop("LD_LIBRARY_PATH_ORIG", None)
    return result


def parse_scan(stdout, stderr=""):
    text = ANSI.sub("", stdout)
    diagnostics = ANSI.sub("", stderr).strip()
    if diagnostics and diagnostics != "No USB devices found":
        raise ValueError("No se pudo completar la enumeración USB: " + diagnostics)
    columns = ("Bus", "device", "vid:pid", "probe_type", "manufacturer", "serial", "product")
    lines = text.splitlines()
    header = next((line for line in lines if tuple(line.split()) == columns), None)
    if header is None:
        raise ValueError(
            "La salida scan-usb no contiene la tabla esperada de openFPGALoader 1.2.0."
        )
    starts = [header.index(name) for name in columns] + [None]
    devices = []
    for line in lines[lines.index(header) + 1 :]:
        if not line.strip():
            continue
        values = [line[starts[i] : starts[i + 1]].strip() for i in range(7)]
        try:
            bus, address = int(values[0]), int(values[1])
            # v1.2.0 formats uint8_t via signed char on some platforms.
            bus = bus + 256 if -128 <= bus < 0 else bus
            address = address + 256 if -128 <= address < 0 else address
            if not 1 <= bus <= 255 or not 1 <= address <= 255:
                raise ValueError("Invalid bus address")
            vid, pid = (int(part, 16) for part in values[2].split(":"))
        except (ValueError, IndexError) as error:
            raise ValueError("Fila USB inválida; no se elige otro dispositivo.") from error
        if (vid, pid) != USB_ID or values[3].lower() != "ftdi2232":
            continue
        serial_number = values[5] if values[5].lower() not in {"none", "-", ""} else None
        devices.append(
            {
                "bus": bus,
                "address": address,
                "vid": vid,
                "pid": pid,
                "serial": serial_number,
                "description": " ".join((values[4], values[6])).strip() or None,
            }
        )
    for device in devices:
        serial_number = device["serial"]
        unique = serial_number and sum(item["serial"] == serial_number for item in devices) == 1
        device["id"] = (
            "serial:" + serial_number if unique else f"usb:{device['bus']}:{device['address']}"
        )
        device["selector"] = (
            ["--usb-serial-num", serial_number]
            if unique
            else ["--busdev-num", f"{device['bus']}:{device['address']}"]
        )
    if len({device["id"] for device in devices}) != len(devices):
        raise ValueError("La enumeración repite un destino USB.")
    return devices


class OpenFPGALoader:
    def __init__(self, assets, queue, *, timeout=120, grace=5):
        self.assets, self.queue, self.timeout, self.grace = assets, queue, timeout, grace

    async def _asset(self, method):
        return await self.queue.submit(lambda: (method, ()))

    async def _run(self, arguments, timeout):
        executable = await self._asset(self.assets.programmer)
        process = await asyncio.create_subprocess_exec(
            str(executable),
            *arguments,
            cwd=executable.parent,
            env=child_environment(executable),
            stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        async def drain(stream):
            output = bytearray()
            truncated = False
            while chunk := await stream.read(8192):
                if len(output) + len(chunk) > 262144:
                    truncated = True
                if len(output) < 262144:
                    output.extend(chunk[: 262144 - len(output)])
            return output.decode("utf-8", errors="replace"), truncated

        output = asyncio.create_task(drain(process.stdout))
        errors = asyncio.create_task(drain(process.stderr))

        async def reap():
            if process.returncode is None:
                try:
                    process.terminate()
                except ProcessLookupError:
                    pass
                try:
                    await asyncio.wait_for(process.wait(), self.grace)
                except TimeoutError:
                    try:
                        process.kill()
                    except ProcessLookupError:
                        pass
                    await process.wait()

        try:
            await asyncio.wait_for(process.wait(), timeout)
        except (TimeoutError, asyncio.CancelledError):
            await reap()
            await asyncio.gather(output, errors)
            raise
        stdout, stderr = await asyncio.gather(output, errors)
        return process.returncode, stdout[0], stderr[0], stdout[1] or stderr[1]

    async def devices(self):
        try:
            code, stdout, stderr, truncated = await self._run(["--scan-usb"], 15)
            if truncated:
                raise ValueError(
                    "La enumeración USB excedió el límite de salida; no se elige un resultado parcial."
                )
            if code != 0:
                raise ValueError(
                    stderr.strip() or stdout.strip() or f"scan-usb terminó con código {code}"
                )
            return parse_scan(stdout, stderr)
        except (OSError, ValueError, KeyError, TimeoutError) as error:
            raise ApplicationError("DEVICE_ENUMERATION_FAILED", str(error), 500) from error

    async def validate(self):
        await self._asset(self.assets.programmer)
        return await self._asset(self.assets.bitstream)

    async def program(self, device, bitstream):
        if await self._asset(self.assets.bitstream) != bitstream:
            raise ValueError("Cambió el recurso de bitstream antes de programar.")
        code, stdout, stderr, truncated = await self._run(
            ["--board", "basys3", "--write-sram", *device["selector"], str(bitstream)], self.timeout
        )
        if code != 0:
            raise RuntimeError(
                stderr.strip() or stdout.strip() or f"El programador terminó con código {code}."
            )
