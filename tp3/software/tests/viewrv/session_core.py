"""Test-only composition: real HTTP/core/UART service, literal controlled replies.

This port does not execute Assembly or model a CPU. It exercises client lifetime,
command framing, concurrency and evidence contracts without physical hardware.
"""

import os
import time
from copy import deepcopy
from pathlib import Path

from software.tests.viewrv.preparation_fixture import PORT, ControlledProgrammer
from software.tests.viewrv.session_cases import wire
from software.viewrv.adapters.assembler import PythonAssembler
from software.viewrv.adapters.serial import SerialTransport
from software.viewrv.core.__main__ import run


class LiteralPort:
    def __init__(self, control):
        self.control = control
        self.rx = bytearray()
        self.timeout = 0.05
        self.write_timeout = 0.2
        self.closed = False
        self.remaining = 0
        self.steps = 0
        self.running = False
        self.load_awaiting = False

    def produce(self):
        if self.load_awaiting and not (self.control / "load.wait").exists():
            self.load_awaiting = False
            self.rx.extend(b"\x01\x02")
        if self.running and not (self.control / "run.wait").exists():
            self.running = False
            self.rx.extend(wire(10, self.steps + 1, run=True))

    @property
    def in_waiting(self):
        self.produce()
        return len(self.rx)

    def write(self, data):
        value = bytes(data)
        with (self.control / "uart.tx").open("a") as stream:
            stream.write(value.hex() + "\n")
        if self.closed:
            raise OSError("Controlled port closed")
        if self.remaining:
            self.remaining -= len(value)
            if self.remaining == 0:
                (self.control / "load.payload").touch()
                if (self.control / "load.wait").exists():
                    self.load_awaiting = True
                else:
                    self.rx.extend(b"\x01\x02")
                self.steps = 0
        elif value == b"\x05":
            self.rx.extend(b"\x05\x03")
        elif len(value) == 6 and value[0] == 1:
            self.remaining = int.from_bytes(value[1:], "little")
            self.rx.extend(b"\x01\x01" if self.remaining else b"\x01\x06")
        elif value == b"\x02":
            self.rx.extend(b"\x02\x01")
            self.running = True
        elif value == b"\x03":
            time.sleep(0.005)
            self.steps += 1
            if not (self.control / "step.drop").exists():
                state = (
                    11
                    if (self.control / "step.fault").exists()
                    else 10
                    if (self.control / "step.terminal").exists()
                    else 5
                )
                self.rx.extend(wire(state, self.steps))
        elif value == b"\x04":
            self.running = False
            if not (self.control / "reset.fail").exists():
                self.rx.extend(b"\x04\x01")
        else:
            raise AssertionError("Unexpected controlled UART write: " + value.hex())
        return len(value)

    def read(self, size):
        end = time.monotonic() + self.timeout
        while not self.rx and time.monotonic() < end:
            self.produce()
            if not self.rx:
                time.sleep(min(0.005, max(0, end - time.monotonic())))
        value = bytes(self.rx[:size])
        del self.rx[:size]
        return value

    def reset_output_buffer(self):
        pass

    def close(self):
        self.closed = True


if __name__ == "__main__":
    control = Path(os.environ["VIEWRV_TEST_CONTROL"])
    raise SystemExit(
        run(
            assembler=PythonAssembler(),
            programmer=ControlledProgrammer(control),
            port_enumerator=lambda: [deepcopy(PORT)],
            serial_transport=SerialTransport("REFERENCE", lambda name: LiteralPort(control)),
        )
    )
