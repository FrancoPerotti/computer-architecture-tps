"""Transcript UART explícito para probar el host sin hardware."""

import struct


class ScriptedPort:
    """Comprueba cada escritura y entrega las respuestas en fragmentos cortos."""

    def __init__(self, exchanges):
        """Inicializa los intercambios esperados y el reloj virtual."""
        self.exchanges = list(exchanges)
        self.pending = b""
        self.time = 0.0

    def monotonic(self):
        """Lee el reloj virtual."""
        return self.time

    def sleep(self, delay):
        """Adelanta el reloj virtual."""
        self.time += delay

    def write(self, data):
        """Exige la siguiente solicitud y pone su respuesta a disposición."""
        if self.pending or not self.exchanges:
            raise AssertionError(f"TX inesperado: {data.hex(' ')}")
        request, self.pending = self.exchanges.pop(0)
        if data != request:
            raise AssertionError(f"TX esperado {request.hex(' ')}, llegó {data.hex(' ')}")
        return len(data)

    def read(self, size):
        """Entrega como máximo un fragmento de la respuesta."""
        self.time += 0.001 if self.pending else 0.010
        count = min(size, 17)
        result, self.pending = self.pending[:count], self.pending[count:]
        return result

    def complete(self):
        """Comprueba que se consumió todo el transcript."""
        if self.exchanges or self.pending:
            raise AssertionError("quedan intercambios en el transcript")


def frame(*, op, result, state, pc, count, fault=(0, 0), rf=(), ifid_word=None, memory=()):
    # Fixture independiente del layout de struct usado para decodificar.
    """Construye un cuerpo de prueba con offsets y valores dirigidos."""
    body = bytearray(228)
    struct.pack_into("<BBIQBI", body, 0, state, 1, pc, count, *fault)
    for register, value in rf:
        struct.pack_into("<I", body, 19 + 4 * register, value)
    if ifid_word is not None:
        body[147] = 1
        struct.pack_into("<I", body, 152, ifid_word)
    body[223:228] = len(memory).to_bytes(5, "little")
    return (
        bytes((op, result))
        + bytes(body)
        + b"".join(struct.pack("<IB", address, value) for address, value in memory)
    )


def smoke_port():
    """Devuelve el transcript literal del recorrido inicial."""
    halt = frame(op=2, result=10, state=10, pc=8, count=3)
    step = frame(op=3, result=2, state=5, pc=4, count=1, ifid_word=0x00700093)
    result = frame(
        op=2,
        result=10,
        state=10,
        pc=20,
        count=7,
        rf=((1, 7), (2, 9)),
        memory=((0, 7), (1, 0), (2, 0), (3, 0)),
    )
    fault = frame(op=2, result=11, state=11, pc=8, count=5, fault=(1, 4), rf=((1, 1),))
    exchanges = [
        ("04", "04 01"),
        ("05", "05 03"),
        ("03", "03 05"),
        ("02", "02 05"),
        ("05", "05 03"),
        ("01 10 00 00 00 00", "01 01"),
        ("93 00 70 00 23 20 10 00 13 01 90 00 0b 00 00 00", "01 02"),
        ("03", step),
        ("02", b"\x02\x01" + result),
        ("05", "05 03"),
        ("01 04 00 00 00 00", "01 01"),
        ("0b 00 00 00", "01 02"),
        ("02", b"\x02\x01" + halt),
        ("05", "05 03"),
        ("01 04 00 00 00 00", "01 01"),
        ("93 00 10 00", "01 02"),
        ("02", b"\x02\x01" + fault),
        ("04", "04 01"),
        ("05", "05 03"),
        ("03", "03 05"),
        ("02", "02 05"),
    ]
    return ScriptedPort(
        (bytes.fromhex(tx), bytes.fromhex(rx) if isinstance(rx, str) else rx)
        for tx, rx in exchanges
    )
