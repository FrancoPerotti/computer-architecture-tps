"""Contrato del TP2 y modelo de referencia, independientes de la interfaz."""

from __future__ import annotations

import argparse
import random
from dataclasses import dataclass
from typing import Iterable

OPERATIONS = {
    "ADD": 0b100000,
    "SUB": 0b100010,
    "AND": 0b100100,
    "OR": 0b100101,
    "XOR": 0b100110,
    "SRA": 0b000011,
    "SRL": 0b000010,
    "NOR": 0b100111,
}


@dataclass(frozen=True)
class TestCase:
    """Representa una operación utilizada para validar la ALU."""

    a: int
    b: int
    opcode: int
    description: str


def parse_byte(value: str) -> int:
    """Convierte un argumento numérico en un byte."""

    parsed = int(value, 0)
    if not 0 <= parsed <= 0xFF:
        raise argparse.ArgumentTypeError("el valor debe estar entre 0 y 255")
    return parsed


def parse_opcode(value: str) -> int:
    """Convierte un nombre o valor numérico en un opcode de seis bits."""

    upper = value.upper()
    if upper in OPERATIONS:
        return OPERATIONS[upper]
    parsed = parse_byte(value)
    if parsed > 0x3F:
        raise argparse.ArgumentTypeError("el opcode utiliza solamente seis bits")
    return parsed


def alu_reference(a: int, b: int, opcode: int) -> tuple[int, int, int, int]:
    """Calcula el resultado y las banderas esperados para una operación."""

    carry = 0
    overflow = 0

    if opcode == OPERATIONS["ADD"]:
        extended = a + b
        result = extended & 0xFF
        carry = int(extended > 0xFF)
        overflow = int(((a ^ result) & (b ^ result) & 0x80) != 0)
    elif opcode == OPERATIONS["SUB"]:
        result = (a - b) & 0xFF
        overflow = int(((a ^ b) & (a ^ result) & 0x80) != 0)
    elif opcode == OPERATIONS["AND"]:
        result = a & b
    elif opcode == OPERATIONS["OR"]:
        result = a | b
    elif opcode == OPERATIONS["XOR"]:
        result = a ^ b
    elif opcode == OPERATIONS["SRA"]:
        signed_a = a - 0x100 if a & 0x80 else a
        result = (signed_a >> b) & 0xFF
    elif opcode == OPERATIONS["SRL"]:
        result = (a >> b) & 0xFF
    elif opcode == OPERATIONS["NOR"]:
        result = (~(a | b)) & 0xFF
    else:
        result = 0

    zero = int(result == 0)
    return result, zero, carry, overflow


def directed_cases() -> list[TestCase]:
    """Construye los casos dirigidos de la validación."""

    return [
        TestCase(0x05, 0x03, OPERATIONS["ADD"], "suma normal"),
        TestCase(0xFF, 0x01, OPERATIONS["ADD"], "carry y cero"),
        TestCase(0x7F, 0x01, OPERATIONS["ADD"], "overflow positivo"),
        TestCase(0x80, 0x80, OPERATIONS["ADD"], "overflow negativo y carry"),
        TestCase(0x05, 0x05, OPERATIONS["SUB"], "resta cero"),
        TestCase(0x80, 0x01, OPERATIONS["SUB"], "overflow de resta"),
        TestCase(0x0C, 0x0A, OPERATIONS["AND"], "AND"),
        TestCase(0xA0, 0x0F, OPERATIONS["OR"], "OR"),
        TestCase(0xAA, 0xFF, OPERATIONS["XOR"], "XOR"),
        TestCase(0xF0, 0x0F, OPERATIONS["NOR"], "NOR"),
        TestCase(0x80, 0x01, OPERATIONS["SRL"], "shift logico"),
        TestCase(0x80, 0x01, OPERATIONS["SRA"], "shift aritmetico"),
        TestCase(0x12, 0x34, 0x3F, "opcode invalido"),
    ]


def random_cases(samples_per_operation: int, seed: int) -> Iterable[TestCase]:
    """Genera casos pseudoaleatorios reproducibles para cada operación."""

    generator = random.Random(seed)
    for name, opcode in OPERATIONS.items():
        for sample in range(samples_per_operation):
            yield TestCase(
                generator.randrange(256),
                generator.randrange(256),
                opcode,
                f"{name} aleatorio {sample + 1}",
            )


