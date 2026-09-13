"""Transporte de bytes sin dependencias de Qt ni del protocolo de aplicación."""

from __future__ import annotations

import time
from typing import Callable, Protocol

import serial

from .protocol import alu_reference


class LinkError(Exception):
    """La comunicación no produjo una respuesta inequívoca."""


class ByteTransport(Protocol):
    def exchange(self, payload: bytes, response_size: int = 1, sent: Callable[[], None] | None = None) -> bytes: ...
    def close(self) -> None: ...


class SerialTransport:
    """UART 8N1; una solicitud en vuelo y reposo entre transacciones.

    El reposo y el control de bytes adicionales ayudan a evitar respuestas
    viejas. No sustituyen delimitación/CRC en el protocolo del FPGA.
    """

    QUIET_SECONDS = 0.025  # Superior al timeout entre bytes de 10 ms del TP2.

    def __init__(self, port: serial.Serial):
        self.port = port

    @classmethod
    def connect(cls, name: str, baud: int = 19200) -> SerialTransport:
        try:
            port = serial.Serial(
                name, baudrate=baud, bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE,
                timeout=0.25, write_timeout=0.25,
                xonxoff=False, rtscts=False, dsrdtr=False,
            )
            link = cls(port)
            try:
                time.sleep(0.05)
                port.reset_input_buffer()
                port.reset_output_buffer()
            except Exception:
                port.close()
                raise
            return link
        except (serial.SerialException, OSError, ValueError) as exc:
            raise LinkError(f"No se pudo abrir {name}: {exc}") from exc

    def exchange(self, payload: bytes, response_size: int = 1, sent: Callable[[], None] | None = None) -> bytes:
        if response_size < 1:
            raise ValueError("La respuesta debe tener al menos un byte.")
        try:
            if self.port.in_waiting:
                raise LinkError("Hay bytes pendientes. Reconectá antes de continuar.")
            written = self.port.write(payload)
            if written != len(payload):
                raise LinkError("La solicitud no se envió completa. Reconectá el enlace.")
            # write() entrega el paquete al sistema; read() espera la respuesta.
            # Evitamos flush(), cuya espera del driver no tiene timeout portable.
            if sent:
                sent()
            response = self.port.read(response_size)
            if len(response) != response_size:
                raise LinkError("No llegó una respuesta. Revisá baud, placa y conexión.")
            time.sleep(self.QUIET_SECONDS)
            if self.port.in_waiting:
                raise LinkError("Llegaron respuestas adicionales. Reconectá el enlace.")
            return response
        except (serial.SerialException, OSError) as exc:
            raise LinkError(f"Se perdió la conexión serie: {exc}") from exc

    def close(self) -> None:
        self.port.close()


class DemoTransport:
    """Modelo local del TP2. No representa una FPGA ni valida el enlace físico."""

    def exchange(self, payload: bytes, response_size: int = 1, sent: Callable[[], None] | None = None) -> bytes:
        if len(payload) != 3 or response_size != 1:
            raise LinkError("El modelo del TP2 requiere tres bytes de entrada y uno de respuesta.")
        if sent:
            sent()
        time.sleep(0.008)
        return bytes((alu_reference(payload[0], payload[1], payload[2] & 0x3F)[0],))

    def close(self) -> None:
        pass
