"""Actual core with controlled JTAG/UART, exclusively for process and GUI tests."""

import asyncio
import os
import tempfile
from copy import deepcopy
from pathlib import Path

from software.tests.viewrv.preparation_fixture import PORT, ControlledProgrammer
from software.tests.viewrv.serial_fixture import Clock, ScriptedPort
from software.viewrv.adapters.serial import SerialTransport
from software.viewrv.core.__main__ import run


class Programmer(ControlledProgrammer):
    async def program(self, device, bitstream):
        marker = Path(os.environ["VIEWRV_TEST_CONTROL"])
        (marker / "program.entered").touch()
        with (marker / "program.calls").open("a") as stream:
            stream.write("program\n")
        while (marker / "program.wait").exists():
            await asyncio.sleep(0.02)
        if (marker / "program.fail").exists():
            raise RuntimeError("Fallo controlado de programación.")
        await super().program(device, bitstream)


if __name__ == "__main__":
    clock = Clock()
    port = ScriptedPort(clock)
    marker = Path(os.environ["VIEWRV_TEST_CONTROL"])

    def opened(name):
        if (marker / "uart.fail").exists():
            raise OSError("Fallo controlado de apertura UART.")
        port.closed = False
        port.script.extend([(b"\x05", [(0, b"\x05\x03")])] * 40)
        return port

    with tempfile.TemporaryDirectory() as folder:
        raise SystemExit(
            run(
                programmer=Programmer(folder),
                port_enumerator=lambda: [deepcopy(PORT)],
                serial_transport=SerialTransport("REFERENCE", opened, clock),
            )
        )
