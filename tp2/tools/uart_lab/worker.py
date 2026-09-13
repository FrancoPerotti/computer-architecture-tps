"""El hilo de trabajo es el único dueño del puerto serie."""

from __future__ import annotations

import threading

from PySide6.QtCore import QObject, Signal, Slot

from .session import execute_tp2
from .transport import DemoTransport, LinkError, SerialTransport


class LabWorker(QObject):
    connection = Signal(bool, str)
    stage = Signal(str)
    transaction = Signal(object)
    sent = Signal(object)
    error = Signal(str)
    completed = Signal(bool)  # Cancelado.
    stopped = Signal()

    def __init__(self):
        super().__init__()
        self.transport = None
        self.source = ""
        self.cancel = threading.Event()

    @Slot(str, int)
    def connect_link(self, port: str, baud: int):
        try:
            self._close()
            self.transport = DemoTransport() if port == "demo" else SerialTransport.connect(port, baud)
            self.source = "simulacion_local" if port == "demo" else port
            self.connection.emit(True, self.source)
        except LinkError as exc:
            self.error.emit(str(exc))
            self.connection.emit(False, "")

    def _close(self):
        if self.transport:
            try:
                self.transport.close()
            except Exception as exc:
                raise LinkError(f"Error al cerrar el puerto: {exc}") from exc
            finally:
                self.transport = None

    @Slot()
    def disconnect_link(self):
        try:
            self._close()
        except LinkError as exc:
            self.error.emit(str(exc))
        self.connection.emit(False, "")

    @Slot(object)
    def run_cases(self, cases):
        try:
            if self.transport is None:
                raise LinkError("Conectá la placa o activá la simulación local.")
            for case in cases:
                if self.cancel.is_set():
                    break
                result = execute_tp2(self.transport, case, self.source, self.stage.emit, self.sent.emit)
                self.transaction.emit(result)
                if not result.passed:
                    # No continuamos una suite cuyo enlace podría estar desalineado.
                    break
        except LinkError as exc:
            self.error.emit(str(exc))
            self.disconnect_link()
        finally:
            self.completed.emit(self.cancel.is_set())

    @Slot()
    def shutdown(self):
        self.disconnect_link()
        self.stopped.emit()
