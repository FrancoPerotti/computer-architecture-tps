"""Controlled programmer and USB metadata, exclusive to verification."""

import asyncio
from copy import deepcopy
from pathlib import Path

DEVICE = {
    "id": "serial:210183TEST",
    "serial": "210183TEST",
    "bus": 1,
    "address": 9,
    "vid": 0x0403,
    "pid": 0x6010,
    "description": "Digilent Basys 3 controlled",
    "selector": ["--usb-serial-num", "210183TEST"],
}
PORT = {
    "id": "controlled-uart",
    "description": "Basys 3 UART controlled",
    "vid": 0x0403,
    "pid": 0x6010,
    "serial": "210183TEST",
    "bus": 1,
    "address": 9,
}


class ControlledProgrammer:
    def __init__(self, root):
        self.root = Path(root)
        self.candidates = [deepcopy(DEVICE)]
        self.release = asyncio.Event()
        self.release.set()
        self.entered = asyncio.Event()
        self.failure = None
        self.invalid = None
        self.calls = []
        self.before = None
        self.after = None

    async def devices(self):
        self.calls.append("devices")
        return deepcopy(self.candidates)

    async def validate(self):
        self.calls.append("validate")
        if self.invalid:
            raise self.invalid
        return self.root / "controlled-test-only.bit"

    async def program(self, device, bitstream):
        self.calls.append(("program", deepcopy(device), bitstream))
        if self.before:
            self.before()
        self.entered.set()
        await self.release.wait()
        if self.failure:
            raise self.failure
        if self.after:
            self.after()
