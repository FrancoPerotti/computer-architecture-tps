"""Synchronous UART exchanges. Only Serial thread owns this adapter and its port."""

import math
import time

import serial
from serial.tools import list_ports

from software.viewrv.contracts import ApplicationError
from software.viewrv.core.protocol import (
    POLL_SECONDS,
    capacities,
    debug_recovery_milliseconds,
    decode_fixed,
    decode_memory,
    list_milliseconds,
    load_header,
    load_recovery_milliseconds,
    load_seconds,
)


def enumerate_ports():
    try:
        return [
            {"id": item.device, "description": item.description} for item in list_ports.comports()
        ]
    except (OSError, serial.SerialException) as error:
        raise ApplicationError("PORT_ENUMERATION_FAILED", str(error), 500) from error


def select_port(candidates, explicit=None, remembered=None):
    chosen = explicit if explicit is not None else remembered
    if chosen is not None:
        if any(item["id"] == chosen for item in candidates):
            return chosen
        raise ApplicationError(
            "PORT_NOT_FOUND",
            "El puerto indicado no está disponible.",
            404,
            {"candidates": candidates},
        )
    if len(candidates) == 1:
        return candidates[0]["id"]
    raise ApplicationError(
        "PORT_SELECTION_REQUIRED", "Seleccioná un puerto serie.", 409, {"candidates": candidates}
    )


def open_serial(port):
    return serial.Serial(
        port=port,
        baudrate=19200,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=POLL_SECONDS,
        write_timeout=0.2,
        xonxoff=False,
        rtscts=False,
        dsrdtr=False,
    )


class WireFailure(Exception):
    pass


class SerialTransport:
    def __init__(self, profile, factory=open_serial, clock=time.monotonic):
        capacities(profile)
        self.profile, self.factory, self.clock = profile, factory, clock
        self.port = None
        self.port_name = None
        self.buffer = bytearray()
        self.context = None
        self.preparation_required = True
        self.checked = False
        self.last_snapshot = None
        self.phase = "closed"
        self.last_tx = float("-inf")
        self.progress = lambda data: None
        self.control = None
        self.operation = None
        self._query_received = False
        self.reset_status = "not_attempted"
        self.header_completed_at = None

    def status(self):
        return {
            "connection_status": "closed"
            if self.port is None
            else "checked"
            if self.checked
            else "unreliable",
            "port": self.port_name if self.port is not None else None,
            "preparation_required": self.preparation_required,
            "recovery_pending": self.context is not None,
        }

    def prepared(self):
        # Called by composition only after a confirmed bitstream programming.
        # Opening UART, CHECK_READY and a new process never imply this fact.
        if self.port is not None:
            raise ApplicationError(
                "OPERATION_CONFLICT", "Cerrá UART antes de programar la placa.", 409
            )
        self.context = None
        self.preparation_required = False
        self.checked = False
        self.buffer.clear()
        return {"prepared": True}

    def close(self):
        try:
            if self.port is not None:
                self.port.close()
        except (OSError, serial.SerialException):
            self.checked = False
            raise
        else:
            self.port = None
            self.checked = False
            self.buffer.clear()
            # Recovery phase, LOAD size and reset attempt survive port closure.

    def _take(self, size, deadline):
        if self.buffer:
            result = bytes(self.buffer[:size])
            del self.buffer[:size]
            return result
        remaining = deadline - self.clock() if deadline is not None else POLL_SECONDS
        if remaining <= 0:
            return b""
        self.port.timeout = min(POLL_SECONDS, remaining)
        result = self.port.read(size)
        if len(result) > size:
            self.buffer.extend(result[size:])
        return result[:size]

    def _read(self, size, deadline):
        data = bytearray()
        while len(data) < size:
            if self.clock() >= deadline:
                raise WireFailure("Venció el plazo de recepción de " + self.phase)
            part = self._take(size - len(data), deadline)
            if part and self.phase == "check_ready":
                self._query_received = True
            if self.clock() > deadline:
                raise WireFailure("La respuesta llegó fuera del plazo de " + self.phase)
            data.extend(part)
        return bytes(data)

    def _available(self):
        if self.buffer:
            return True
        return self.port.in_waiting > 0

    def _write(self, data, deadline, listen=False):
        offset = 0
        while offset < len(data):
            remaining = deadline - self.clock()
            if remaining <= 0:
                raise WireFailure("Venció el plazo de envío de " + self.phase)
            self.port.write_timeout = remaining
            chunk = data[offset : offset + 64] if listen else data[offset:]
            count = self.port.write(chunk)
            self.last_tx = self.clock()
            if not isinstance(count, int) or not 0 < count <= len(chunk):
                raise WireFailure("El puerto no confirmó progreso de escritura")
            offset += count
            if self.clock() > deadline:
                raise WireFailure("La escritura excedió el plazo de " + self.phase)
            if listen and self.port.in_waiting:
                self.port.timeout = 0
                self.buffer.extend(self.port.read(self.port.in_waiting))
                # An abort can arrive while output is still being queued.
                if len(self.buffer) >= 2:
                    if self.buffer[0] != 1 or self.buffer[1] not in (2, 8, 9):
                        raise WireFailure("Respuesta fuera de fase durante LOAD")
                    if self.buffer[1] in (8, 9):
                        reply = bytes(self.buffer[:2])
                        del self.buffer[:2]
                        raise ApplicationError(
                            "LOAD_FAILED",
                            "La FPGA abortó LOAD.",
                            500,
                            {"response": list(reply), "image_status": "invalid"},
                        )
                    if offset != len(data):
                        raise WireFailure("DONE recibido antes de enviar la imagen completa")

    def _header(self, opcode, deadline, allowed):
        first = self._read(1, deadline)[0]
        if first != opcode:
            raise WireFailure("La respuesta no comienza con el opcode esperado")
        result = self._read(1, deadline)[0]
        self.header_completed_at = self.clock()
        if result not in allowed:
            raise WireFailure("Resultado UART inválido para la fase")
        return result

    def _check(self):
        self.phase = "check_ready"
        self._query_received = False
        deadline = self.clock() + 0.2
        self._write(b"\x05", deadline)
        result = self._header(5, deadline, {3, 4})
        self.checked = True
        return result == 3

    def _debug(self, operation, result):
        self.phase = "debug_fixed"
        fixed = self._read(228, self.header_completed_at + 0.319)
        fixed_completed_at = self.clock()
        snapshot = decode_fixed(fixed, self.profile, operation, result)
        self.phase = "debug_memory"
        count = snapshot["used_count"]
        memory = (
            self._read(5 * count, fixed_completed_at + list_milliseconds(count) / 1000)
            if count
            else b""
        )
        snapshot = decode_memory(snapshot, memory, self.profile)
        self.last_snapshot = snapshot
        return snapshot

    def _load(self, parameters):
        image = parameters["image"]
        if not isinstance(image, bytes):
            raise ApplicationError("INVALID_ARGUMENT", "La imagen debe ser bytes inmutables.", 400)
        header = load_header(len(image))
        if not self._check():
            raise ApplicationError("BOARD_NOT_READY", "CHECK_READY informó BUSY.", 409)
        self.phase = "load_header"
        deadline = self.clock() + 0.2
        self._write(header, deadline)
        result = self._header(1, deadline, {1, 4, 6, 7, 9})
        if result != 1:
            if result in (7, 9):
                self._pending("LOAD", len(image))
            raise ApplicationError(
                "LOAD_REJECTED",
                "La FPGA rechazó LOAD antes de aceptarla.",
                422 if result == 6 else 409,
                {"response": [1, result], "image_status": "preserved"},
            )
        self.progress({"phase": "load_accepted", "image_status": "invalid"})
        self.phase = "load_content"
        deadline = self.clock() + load_seconds(len(image))
        self._write(image, deadline, listen=True)
        self.phase = "load_done"
        result = self._header(1, deadline, {2, 8, 9})
        if result != 2:
            self._pending("LOAD", len(image))
            raise ApplicationError(
                "LOAD_FAILED",
                "La FPGA abortó LOAD después de aceptarla.",
                500,
                {"response": [1, result], "image_status": "invalid"},
            )
        return {"byte_count": len(image), "image_status": "confirmed"}

    def _terminal(self, first_at):
        self.phase = "run_terminal_header"
        self.progress({"phase": "run_terminal_started"})
        result = self._read(1, first_at + 0.2)[0]
        self.header_completed_at = self.clock()
        if result not in {10, 11}:
            raise WireFailure("Cabecera terminal de RUN inválida")
        return {"snapshot": self._debug("RUN", result), "interruption": None}

    def _reset_run(self, reason):
        self.phase = "run_reset"
        deadline = self.clock() + 0.2
        self.reset_status = "unconfirmed"
        self._write(b"\x04", deadline)
        first = self._read(1, deadline)[0]
        if first == 2:
            return {**self._terminal(self.clock()), "reset_status": "unconfirmed"}
        if first != 4 or self._read(1, deadline) != b"\x01":
            raise WireFailure("RESET sin aceptación válida")
        self.reset_status = "confirmed"
        return {"snapshot": None, "interruption": {"reason": reason}, "reset_status": "confirmed"}

    def _run(self, parameters, control):
        limit = parameters.get("max_seconds")
        if limit is not None and (
            type(limit) not in (int, float) or not math.isfinite(limit) or limit <= 0
        ):
            raise ApplicationError(
                "INVALID_ARGUMENT", "El límite RUN debe ser positivo y finito.", 400
            )
        self.phase = "run_acceptance"
        deadline = self.clock() + 0.2
        self._write(b"\x02", deadline)
        result = self._header(2, deadline, {1, 4, 5})
        if result != 1:
            raise ApplicationError(
                "RUN_REJECTED", "La FPGA rechazó RUN.", 409, {"response": [2, result]}
            )
        accepted_at = self.header_completed_at
        self.progress({"phase": "run_accepted"})
        end = None if limit is None else accepted_at + limit
        self.phase = "run_execution"
        while True:
            # A terminal already available wins over a simultaneous stop request.
            if self._available():
                first = self._take(1, end)
            elif control.is_set() or (end is not None and self.clock() >= end):
                return self._reset_run("user_request" if control.is_set() else "time_limit")
            else:
                first = self._take(1, end)
            if first:
                if first != b"\x02":
                    raise WireFailure("Primer byte terminal de RUN inválido")
                return self._terminal(self.clock())

    def _step(self):
        self.phase = "step_header"
        deadline = self.clock() + 0.2
        self._write(b"\x03", deadline)
        result = self._header(3, deadline, {2, 4, 5})
        if result != 2:
            raise ApplicationError(
                "STEP_REJECTED", "La FPGA rechazó STEP.", 409, {"response": [3, result]}
            )
        return {"snapshot": self._debug("STEP", result)}

    def _pending(self, operation, byte_count=None, reset_used=False):
        if self.context is None:
            self.context = {
                "operation": operation,
                "phase": self.phase,
                "byte_count": byte_count,
                "reset_used": reset_used,
                "reset_status": self.reset_status,
            }
        self.checked = False
        if operation == "LOAD" and self.port is not None:
            # Never discard input. Cancel only output that has not left the host.
            # Synchronous write already returned. cancel_write() here can cancel
            # the *next* write on POSIX; reset_output_buffer cancels queued TX.
            for method in ("reset_output_buffer",):
                try:
                    getattr(self.port, method)()
                except (AttributeError, OSError, serial.SerialException):
                    pass

    def _discard(self, seconds, continuous):
        self.phase = "recovery_silence"
        end = self.clock() + seconds
        while True:
            if self.operation in {"RECOVER", "OPEN"} and self.control.is_set():
                raise WireFailure("Se solicitó cerrar el enlace durante la recuperación")
            # Check queued input even at the boundary; never flush RX on exit.
            if self._available():
                self.port.timeout = 0
                self.buffer.clear()
                self.port.read(max(1, self.port.in_waiting))
                if continuous:
                    end = self.clock() + seconds
                continue
            if self.clock() >= end:
                return
            data = self._take(4096, end)
            if data and continuous:
                end = self.clock() + seconds

    def recover(self, retry_reset=False):
        if self.context is None:
            return {"ready": self._check(), "reset_status": "not_attempted"}
        context = self.context
        if context["reset_used"] and not retry_reset:
            raise ApplicationError(
                "BOARD_RECOVERY_REQUIRED",
                "El RESET automático ya fue utilizado; se requiere una acción explícita.",
                409,
                {"phase": context["phase"], "reset_status": context["reset_status"]},
            )
        if retry_reset:
            context["reset_used"] = False
        is_load = context["operation"] == "LOAD"
        silence = (
            load_recovery_milliseconds(context["byte_count"])
            if is_load
            else debug_recovery_milliseconds(self.profile)
        ) / 1000
        while True:
            self._discard(silence, continuous=not is_load)
            try:
                ready = self._check()
            except (WireFailure, ValueError):
                if is_load:
                    # Repeat the window/query, never the image or a RESET.
                    continue
                break
            else:
                self.context = None
                self.checked = True
                return {"ready": ready, "reset_status": "not_attempted"}
        try:
            # Any data, even a wrong first byte, requires a second full silence.
            if self._query_received or self._available():
                self._discard(silence, continuous=True)
            if self.clock() < self.last_tx + 0.101:
                self._discard(self.last_tx + 0.101 - self.clock(), continuous=False)
            context["reset_used"] = True  # Before write, including write failure.
            context["reset_status"] = "unconfirmed"
            self.reset_status = "unconfirmed"
            self.phase = "recovery_reset"
            deadline = self.clock() + 0.2
            self._write(b"\x04", deadline)
            self._header(4, deadline, {1})
            self.reset_status = "confirmed"
            self.context = None
            self.checked = True
            return {"ready": None, "reset_status": "confirmed"}
        except (WireFailure, OSError, ValueError):
            self.checked = False
            raise

    def execute(self, operation, parameters, control, progress=lambda data: None):
        self.progress = progress
        self.control, self.operation = control, operation
        self.reset_status = "not_attempted"
        try:
            if operation == "UNPREPARED":
                if self.port is not None:
                    raise ApplicationError(
                        "OPERATION_CONFLICT", "UART debe estar cerrado antes de programar.", 409
                    )
                self.preparation_required = True
                self.checked = False
                return {"prepared": False}
            if operation == "PREPARED":
                return self.prepared()
            if operation == "PORTS":
                return {"ports": enumerate_ports()}
            if operation == "CLOSE":
                self.close()
                return {"connection_status": "closed"}
            if operation == "OPEN":
                if self.preparation_required:
                    raise ApplicationError(
                        "BOARD_PREPARATION_REQUIRED",
                        "Se requiere programación explícita del bitstream.",
                        409,
                    )
                chosen = parameters["port"]
                if self.port is not None:
                    raise ApplicationError("OPERATION_CONFLICT", "UART ya está abierto.", 409)
                self.phase = "open"
                self.progress({"phase": "checking"})
                self.port_name = chosen
                self.port = self.factory(chosen)
                return {"port": chosen, **self.recover()}
            if self.port is None:
                raise ApplicationError("BOARD_NOT_CONNECTED", "UART está cerrado.", 409)
            if operation == "RECOVER":
                self.progress({"phase": "checking"})
                return self.recover(parameters.get("retry_reset", False))
            if self.context is not None:
                raise ApplicationError(
                    "BOARD_RECOVERY_REQUIRED", "Hay una recuperación pendiente.", 409
                )
            if self.preparation_required:
                raise ApplicationError(
                    "BOARD_PREPARATION_REQUIRED", "Se requiere preparar la placa.", 409
                )
            if operation == "CHECK_READY":
                return {"ready": self._check()}
            if operation == "LOAD":
                return self._load(parameters)
            if operation == "RUN":
                return self._run(parameters, control)
            if operation == "STEP":
                return self._step()
            if operation == "RESET":
                self.phase = "reset"
                deadline = self.clock() + 0.2
                self.reset_status = "unconfirmed"
                self._write(b"\x04", deadline)
                self._header(4, deadline, {1})
                self.reset_status = "confirmed"
                self.checked = True
                return {"reset_status": "confirmed", "ready": self._check()}
            raise ApplicationError("INVALID_ARGUMENT", "Operación serial desconocida.", 400)
        except ApplicationError as error:
            if error.code == "LOAD_FAILED":
                self._pending("LOAD", len(parameters["image"]))
            raise
        except (WireFailure, OSError, ValueError) as error:
            interrupted = operation
            if operation == "LOAD" and not self.phase.startswith("load_"):
                interrupted = "CHECK_READY"
            self._pending(
                interrupted, len(parameters.get("image", b"")), self.reset_status != "not_attempted"
            )
            codes = {
                "LOAD": "LOAD_RESULT_UNCONFIRMED",
                "RUN": "RUN_RESULT_UNCONFIRMED",
                "STEP": "STEP_RESULT_UNCONFIRMED",
                "RESET": "RESET_UNCONFIRMED",
                "OPEN": "BOARD_CONNECTION_FAILED",
                "CLOSE": "BOARD_DISCONNECTION_FAILED",
            }
            code = codes.get(operation, "BOARD_RECOVERY_REQUIRED")
            if operation == "RESET" and self.reset_status == "confirmed":
                code = "BOARD_CONNECTION_FAILED"
            raise ApplicationError(
                code,
                str(error),
                500,
                {
                    "phase": self.phase,
                    "port": self.port_name,
                    "image_status": "unknown",
                    "reset_status": self.reset_status
                    if self.reset_status != "not_attempted"
                    else "unconfirmed"
                    if self.context["reset_used"]
                    else "not_attempted",
                },
            ) from error
