"""Intercambios UART y decodificación Debug para el ejecutor de aceptación."""

import math
import struct
import time

from .plans import DMEM

BAUD = 19200
BYTE_TIME = 10 / BAUD
HEADER_TIMEOUT = 0.200
FIXED_TIMEOUT = 0.319
FIXED_SIZE = 228
DEBUG_RECOVERY = 6.1  # W_debug para REFERENCE.

# Campos UART, en orden de tp3/docs/protocol.md. Se preserva el payload de
# los latches inválidos porque el protocolo lo transmite igualmente.
LAYOUT = (
    ("ifid", "<BIIBB", "valid pc instruction fetch_fault_valid fetch_fault_cause"),
    (
        "idex",
        "<BIIBBBIIIBBBBBB",
        "valid pc instruction rs1 rs2 rd rs1_value rs2_value immediate alu_op alu_src "
        "result_sel flow_op mem_op reg_write",
    ),
    ("exmem", "<BIIBBBII", "valid pc instruction rd reg_write mem_op ex_result store_data"),
    ("memwb", "<BIIBBI", "valid pc instruction rd reg_write wb_value"),
)
CONTEXT = struct.Struct("<BBIQBI32I")


def load_recovery(size):
    """Calcula W_load con cabecera, T y R en múltiplos de 100 ms."""
    return math.ceil(((size + 6) * BYTE_TIME + 0.200) * 10) / 10


class WireError(RuntimeError):
    """Respuesta ausente, inválida o distinta de la prevista."""


def used_count(fixed):
    """Lee y acota la cantidad de entradas antes de reservar el cuerpo."""
    count = int.from_bytes(fixed[223:228], "little")
    if count > DMEM:
        raise WireError(f"used_count {count} excede DMEM REFERENCE")
    return count


def decode(fixed, entries):
    """Interpreta el cuerpo Debug y comprueba el formato de la captura."""
    if len(fixed) != FIXED_SIZE or len(entries) != 5 * used_count(fixed):
        raise WireError("longitud de Debug inválida")
    state, image_valid, pc, count, cause, fault_pc, *rf = CONTEXT.unpack_from(fixed)
    if state > 13 or image_valid > 1 or cause > 7 or rf[0]:
        raise WireError("contexto Debug inválido")
    snapshot = {
        "state": state,
        "image_valid": image_valid,
        "pc": pc,
        "count": count,
        "fault_cause": cause,
        "fault_pc": fault_pc,
        "rf": rf,
        "valid": [],
        "memory": [],
    }
    offset = CONTEXT.size
    for name, fmt, fields in LAYOUT:
        latch = dict(zip(fields.split(), struct.unpack_from(fmt, fixed, offset), strict=True))
        snapshot[name] = latch
        snapshot["valid"].append(latch["valid"])
        offset += struct.calcsize(fmt)
    for latch in (snapshot[name] for name, _, _ in LAYOUT):
        for field in ("valid", "fetch_fault_valid", "reg_write", "alu_src"):
            if field in latch and latch[field] > 1:
                raise WireError(f"booleano inválido en Debug: {field}")
        for field in ("rs1", "rs2", "rd"):
            if field in latch and latch[field] > 31:
                raise WireError(f"índice RF inválido en Debug: {field}")
        for field, maximum in (
            ("fetch_fault_cause", 7),
            ("result_sel", 2),
            ("flow_op", 5),
            ("mem_op", 8),
        ):
            if field in latch and latch[field] > maximum:
                raise WireError(f"control inválido en Debug: {field}")
        if "alu_op" in latch and latch["alu_op"] > 63:
            raise WireError("padding ALU inválido en Debug")
    previous = -1
    for address, value in struct.iter_unpack("<IB", entries):
        if not previous < address < DMEM:
            raise WireError(f"dirección DMEM fuera de orden o de rango: {address}")
        snapshot["memory"].append([address, value])
        previous = address
    return snapshot


def compare(expected, observed, path="Debug"):
    """Compara campos esperados e informa la primera diferencia con su ruta."""
    if isinstance(expected, dict):
        for key, value in expected.items():
            compare(value, observed[key], f"{path}.{key}")
    elif observed != expected:
        if (
            isinstance(expected, list)
            and isinstance(observed, list)
            and len(expected) == len(observed)
        ):
            for index, value in enumerate(expected):
                compare(value, observed[index], f"{path}[{index}]")
        raise WireError(f"{path}: esperado {str(expected)[:140]}, recibido {str(observed)[:140]}")


class Link:
    """Enlace síncrono con reloj y transporte sustituibles para pruebas."""

    def __init__(self, port, record, *, now=time.monotonic, pause=time.sleep):
        """Recibe un puerto abierto, un registro de eventos y un reloj."""
        self.port = port
        self.record = record
        self.now = now
        self.pause = pause

    def read_some(self, size):
        """Lee y registra un fragmento recibido del puerto."""
        chunk = self.port.read(size)
        if chunk:
            self.record("rx", chunk.hex(" "))
        return chunk

    def read(self, size, deadline):
        """Reúne una cantidad exacta de bytes con un plazo absoluto."""
        data = bytearray()
        while len(data) < size:
            if self.now() >= deadline:
                raise WireError(f"timeout RX: {len(data)}/{size} bytes")
            data.extend(self.read_some(size - len(data)))
        if self.now() > deadline:
            raise WireError(f"plazo RX excedido al completar {size} bytes")
        return bytes(data)

    def send(self, data):
        """Encola una solicitud completa y devuelve su instante de inicio."""
        start = self.now()
        self.record("tx", data.hex(" "))
        written = self.port.write(data)
        if written != len(data):
            raise WireError(f"escritura parcial TX: {written}/{len(data)} bytes")
        return start

    def expect(self, request, result, deadline):
        """Comprueba una respuesta corta y deja pasar el último Stop."""
        expected = bytes((request, result))
        reply = self.read(2, deadline)
        if reply != expected:
            raise WireError(f"se esperaba {expected.hex(' ')}, llegó {reply.hex(' ')}")
        self.pause(BYTE_TIME)

    def command(self, request, result):
        """Intercambia una solicitud de un byte."""
        start = self.send(bytes((request,)))
        self.expect(request, result, start + HEADER_TIMEOUT)

    def load_header(self, size, result):
        """Envía el tamaño completo en cinco bytes y exige el resultado indicado."""
        start = self.send(b"\x01" + size.to_bytes(5, "little"))
        self.expect(1, result, start + HEADER_TIMEOUT)

    def load(self, image):
        """Consulta disponibilidad y ejecuta las dos fases de una carga."""
        self.command(5, 3)
        self.load_header(len(image), 1)
        start = self.send(image)
        self.expect(1, 2, start + len(image) * BYTE_TIME + 0.201)

    def incomplete_load(self, size, partial):
        """Provoca timeout de contenido y espera el silencio de recuperación."""
        self.load_header(size, 1)
        start = self.send(partial)
        self.expect(1, 8, start + len(partial) * BYTE_TIME + HEADER_TIMEOUT)
        self.require_quiet(load_recovery(size))

    def require_quiet(self, duration):
        """Comprueba que no aparezca tráfico en la ventana indicada."""
        deadline = self.now() + duration
        while self.now() < deadline:
            unexpected = self.read_some(256)
            if unexpected:
                raise WireError(f"tráfico inesperado: {unexpected.hex(' ')}")

    def synchronize_open(self):
        """Descarta RX previo al primer comando y exige el silencio de recuperación."""
        started = self.now()
        quiet_until = started + 0.020
        limit = started + 3 * DEBUG_RECOVERY
        while self.now() < quiet_until:
            if self.read_some(256):
                quiet_until = self.now() + DEBUG_RECOVERY
                if quiet_until > limit:
                    raise WireError("el puerto no quedó en reposo después de abrirlo")

    def snapshot_start(self, op, state, run_wait):
        """Abre STEP o RUN y reúne la parte fija del snapshot."""
        if op == "step":
            start = self.send(b"\x03")
            self.expect(3, 2, start + HEADER_TIMEOUT)
        else:
            self.command(2, 1)
            self.run_header(11 if state == 11 else 10, run_wait)
        return self.read(FIXED_SIZE, self.now() + FIXED_TIMEOUT)

    def run_header(self, result, run_wait):
        # El contrato no limita el RUN. Este plazo externo solo acota el ensayo.
        """Recibe la cabecera terminal dentro de los plazos del ensayo."""
        first = self.read(1, self.now() + run_wait)
        tail = self.read(1, self.now() + HEADER_TIMEOUT)
        if first + tail != bytes((2, result)):
            raise WireError(f"resultado RUN inesperado: {(first + tail).hex(' ')}")

    def snapshot(self, op, state, run_wait):
        """Completa el cuerpo Debug y devuelve la observación decodificada."""
        fixed = self.snapshot_start(op, state, run_wait)
        size = 5 * used_count(fixed)
        timeout = math.ceil(1000 * size * BYTE_TIME + 200) / 1000
        entries = self.read(size, self.now() + timeout)
        self.pause(BYTE_TIME)
        return decode(fixed, entries)

    def button(self, phase, run_wait, image=None):
        """Guía al operador para abortar el intercambio con BTNC."""
        if phase == "RUN":
            input("Pulsá y soltá BTNC con el loop en RUN. Después presioná Enter. ")
            self.require_quiet(DEBUG_RECOVERY)
        elif phase == "LOAD":
            input("Prepará BTNC. Presioná Enter para iniciar la transferencia. ")
            self.command(5, 3)
            self.load_header(len(image), 1)
            # Quedan cuatro bytes pendientes: la carga no puede pasar a preparación.
            print("Pulsá BTNC AHORA y mantenelo presionado hasta el aviso de soltar.", flush=True)
            partial = image[:-4]
            # Da tiempo al operador sin alcanzar el timeout de inactividad de 100 ms.
            for offset in range(0, len(partial), 32):
                start = self.send(partial[offset : offset + 32])
                self.pause(max(0, start + 0.070 - self.now()))
            self.port.flush()
            input("Soltá BTNC y presioná Enter después de confirmar el pulso durante LOAD. ")
            self.require_quiet(load_recovery(len(image)))
        elif phase == "DEBUG":
            self.run_header(10, run_wait)
            fixed = self.read(FIXED_SIZE, self.now() + FIXED_TIMEOUT)
            size = 5 * used_count(fixed)
            if size != 5 * DMEM:
                raise WireError("el RUN no produjo el listado completo para interrumpir")
            self.record("button-window", {"phase": phase, "tail_bytes": size})
            input("Pulsá y soltá BTNC ahora, mientras llega Debug. Después presioná Enter. ")
            data = bytearray()
            deadline = self.now() + size * BYTE_TIME + HEADER_TIMEOUT
            while self.now() < deadline and len(data) < size:
                chunk = self.read_some(min(256, size - len(data)))
                if not chunk:
                    # En USB puede haber una pausa entre paquetes. Exigir un
                    # silencio sostenido, además de un cuerpo realmente truncado.
                    quiet = self.now() + 0.110
                    while self.now() < quiet and not chunk:
                        chunk = self.read_some(min(256, size - len(data)))
                    if not chunk:
                        break
                data.extend(chunk)
            if len(data) == size:
                raise WireError(
                    f"no se observó un listado parcialmente recibido: {len(data)}/{size}"
                )
            self.record("truncated-debug", {"expected": size, "received": len(data)})
            self.require_quiet(DEBUG_RECOVERY)
        else:
            raise WireError(f"falta instrumentar el botón en {phase}")
        self.record("button-confirmed-by-operator", phase)
