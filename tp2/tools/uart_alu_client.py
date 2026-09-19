#!/usr/bin/env python3
"""Cliente autocheckeable para el protocolo binario de la ALU sobre UART."""

from __future__ import annotations

import argparse
import sys
import time

try:
    import serial
except ImportError as exc:
    raise SystemExit(
        "Falta pyserial. Instalar con: python -m pip install -r tools/requirements.txt"
    ) from exc


from uart_lab.protocol import (
    OPERATIONS, TestCase, alu_reference, directed_cases,
    parse_byte, parse_opcode, random_cases,
)
from uart_lab.transport import SerialTransport, LinkError


def transact(port: serial.Serial, test: TestCase) -> bool:
    """Ejecuta una transacción y comprueba la respuesta recibida."""

    expected, zero, carry, overflow = alu_reference(test.a, test.b, test.opcode)
    try:
        response = SerialTransport(port).exchange(bytes((test.a, test.b, test.opcode)))
    except LinkError as exc:
        print(f"FAIL {test.description}: {exc}", file=sys.stderr)
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
