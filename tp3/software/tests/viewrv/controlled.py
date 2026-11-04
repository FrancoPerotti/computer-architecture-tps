"""Controlled assembler results for application verification, never shipped as assembler."""

import threading
from dataclasses import dataclass


@dataclass
class Diagnostic:
    line: int
    message: str


@dataclass
class Result:
    image: bytes | None
    pc_to_line: dict
    error: Diagnostic | None = None


class ControlledAssembler:
    def __init__(self):
        self.started = threading.Event()
        self.release = threading.Event()
        self.release.set()
        self.inputs = []

    def assemble(self, text):
        self.inputs.append(text)
        self.started.set()
        if not self.release.wait(15):
            raise TimeoutError("Controlled assembler gate was not released")
        if text == "invalid\n":
            return Result(
                None, {}, Diagnostic(1, "Instrucción inválida en el resultado controlado.")
            )
        if text == "internal\n":
            raise RuntimeError("Controlled internal failure")
        if not text.strip():
            return Result(b"", {})
        # A known ADDI/HALT fixture; this double does not translate arbitrary text.
        return Result(bytes.fromhex("930050000b000000"), {0: 1, 4: 2})
