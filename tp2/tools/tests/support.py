"""FPGA virtual sobre un pseudo-terminal real para verificar la capa serie."""

from __future__ import annotations

import os
import select
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from uart_lab.protocol import alu_reference


class VirtualFPGA:
    def __init__(self, respond=None):
        self.master, self.slave = os.openpty()
        self.name = os.ttyname(self.slave)
        self.requests = []
        self.respond = respond or (lambda p: bytes((alu_reference(p[0], p[1], p[2] & 63)[0],)))
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def _run(self):
        pending = bytearray()
        last_byte = time.monotonic()
        while not self.stop.is_set():
            ready, _, _ = select.select([self.master], [], [], 0.005)
            if not ready:
                if time.monotonic() - last_byte > 0.010:
                    pending.clear()
                continue
            try:
                data = os.read(self.master, 4096)
                pending.extend(data)
                last_byte = time.monotonic()
                while len(pending) >= 3:
                    packet = bytes(pending[:3])
                    del pending[:3]
                    self.requests.append(packet)
                    reply = self.respond(packet)
                    if reply:
                        os.write(self.master, reply)
            except OSError:
                break

    def close(self):
        self.stop.set()
        self.thread.join(timeout=1)
        os.close(self.master)
        os.close(self.slave)
