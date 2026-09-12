#!/usr/bin/env python3
"""Cliente autocheckeable para el protocolo binario de la ALU sobre UART."""

from __future__ import annotations

import argparse
import random
import sys
import time
from dataclasses import dataclass
from typing import Iterable

try:
    import serial
except ImportError as exc:
    raise SystemExit(
        "Falta pyserial. Instalar con: python -m pip install -r tools/requirements.txt"
    ) from exc


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


def transact(port: serial.Serial, test: TestCase) -> bool:
    """Ejecuta una transacción y comprueba la respuesta recibida."""

    expected, zero, carry, overflow = alu_reference(test.a, test.b, test.opcode)
    port.write(bytes((test.a, test.b, test.opcode)))
    port.flush()
    response = port.read(1)

    if len(response) != 1:
        print(f"FAIL {test.description}: timeout esperando respuesta", file=sys.stderr)
        return False

    obtained = response[0]
    passed = obtained == expected
    status = "PASS" if passed else "FAIL"
    print(
        f"{status} {test.description}: "
        f"A={test.a:02X} B={test.b:02X} OP={test.opcode:02X} "
        f"RX={obtained:02X} ESP={expected:02X} "
        f"LED(V,C,Z)={overflow},{carry},{zero}"
    )
    return passed


def build_parser() -> argparse.ArgumentParser:
    """Construye el analizador de argumentos de la línea de comandos."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, help="puerto serie, por ejemplo /dev/ttyUSB1")
    parser.add_argument("--baud", type=int, default=19_200)
    parser.add_argument("--timeout", type=float, default=0.25)
    parser.add_argument("--a", type=parse_byte)
    parser.add_argument("--b", type=parse_byte)
    parser.add_argument("--opcode", type=parse_opcode)
    parser.add_argument(
        "--suite",
        choices=("directed", "random", "all"),
        help="ejecuta una bateria autocheckeable",
    )
    parser.add_argument("--random-per-op", type=int, default=100)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=0x1A2B3C4D)
    parser.add_argument(
        "--recovery",
        action="store_true",
        help="envia un byte aislado, espera el timeout interno y verifica resincronizacion",
    )
    return parser


def main() -> int:
    """Ejecuta las pruebas solicitadas y devuelve su estado."""

    parser = build_parser()
    args = parser.parse_args()
    single_values = (args.a, args.b, args.opcode)
    if any(value is not None for value in single_values) and not all(
        value is not None for value in single_values
    ):
        parser.error("--a, --b y --opcode deben indicarse juntos")
    if not args.suite and not args.recovery and not all(
        value is not None for value in single_values
    ):
        parser.error("indicar una operacion, --suite o --recovery")
    if args.random_per_op < 0:
        parser.error("--random-per-op no puede ser negativo")

    cases: list[TestCase] = []
    if all(value is not None for value in single_values):
        cases.append(TestCase(args.a, args.b, args.opcode, "operacion solicitada"))
    if args.suite in ("directed", "all"):
        cases.extend(directed_cases())
    if args.suite in ("random", "all"):
        cases.extend(random_cases(args.random_per_op, args.seed))

    failures = 0
    with serial.Serial(
        port=args.port,
        baudrate=args.baud,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=args.timeout,
        write_timeout=args.timeout,
        xonxoff=False,
        rtscts=False,
        dsrdtr=False,
    ) as port:
        time.sleep(0.05)
        port.reset_input_buffer()
        port.reset_output_buffer()

        if args.recovery:
            port.write(b"\xAA")
            port.flush()
            time.sleep(0.020)
            recovery = TestCase(0x09, 0x02, OPERATIONS["SUB"], "timeout y resincronizacion")
            failures += int(not transact(port, recovery))

        for test in cases:
            failures += int(not transact(port, test))

        if port.in_waiting:
            extra = port.read(port.in_waiting)
            print(f"FAIL: respuestas adicionales inesperadas: {extra.hex()}", file=sys.stderr)
            failures += 1

    total = len(cases) + int(args.recovery)
    if failures:
        print(f"FAIL: {failures} errores en {total} operaciones", file=sys.stderr)
        return 1
    print(f"PASS: {total} operaciones completadas sin errores")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
