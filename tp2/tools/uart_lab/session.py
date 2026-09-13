"""Transacciones del TP2. Una GUI futura puede usar otro protocolo/transporte."""

from __future__ import annotations

import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Callable

from .protocol import TestCase, alu_reference
from .transport import ByteTransport, LinkError


@dataclass(frozen=True)
class Transaction:
    case: TestCase
    received: int
    expected: int
    flags: tuple[int, int, int]  # Z, C, V: modelo esperado, no recibido por UART.
    elapsed_ms: float
    timestamp: str
    source: str

    @property
    def passed(self) -> bool:
        return self.received == self.expected

    def record(self) -> dict:
        result = asdict(self)
        result['passed'] = self.passed
        return result


def execute_tp2(
    transport: ByteTransport, case: TestCase, source: str,
    stage: Callable[[str], None] = lambda _: None,
    sent: Callable[[TestCase], None] = lambda _: None,
) -> Transaction:
    expected, zero, carry, overflow = alu_reference(case.a, case.b, case.opcode & 0x3F)
    stage("Enviando solicitud")
    start = time.perf_counter()
    def on_sent():
        sent(case)
        stage("Esperando respuesta")
    response = transport.exchange(
        bytes((case.a, case.b, case.opcode)), response_size=1,
        sent=on_sent,
    )
    if len(response) != 1:
        raise LinkError("El TP2 requiere exactamente un byte de respuesta.")
    return Transaction(
        case, response[0], expected, (zero, carry, overflow),
        (time.perf_counter() - start) * 1000,
        datetime.now(timezone.utc).isoformat(), source,
    )
