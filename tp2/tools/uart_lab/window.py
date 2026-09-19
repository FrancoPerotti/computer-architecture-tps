"""Aplicación de escritorio del TP2. Las vistas consumen transacciones, no UART."""

from __future__ import annotations

import json
from datetime import datetime

from PySide6.QtCore import QThread, QTimer, Qt, Signal
from PySide6.QtGui import QColor, QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QAbstractItemView, QBoxLayout, QButtonGroup, QComboBox, QFileDialog,
    QFrame, QHBoxLayout, QHeaderView, QLineEdit, QMainWindow, QPlainTextEdit,
    QProgressBar, QPushButton, QScrollArea, QSizePolicy, QSpinBox,
    QStackedWidget, QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget,
)
from serial.tools import list_ports

from .protocol import OPERATIONS, TestCase, directed_cases, random_cases
from .session import Transaction
from .widgets import LabMark, OperandEditor, ResultCard, card, label, restyle
from .worker import LabWorker


OP_DESCRIPTIONS = {
    "ADD": ("A + B", "Suma de 8 bits; el resultado conserva los ocho bits inferiores."),
    "SUB": ("A − B", "Resta de 8 bits con representación en complemento a dos."),
    "AND": ("A ∧ B", "Activa solamente los bits que están activos en ambos operandos."),
    "OR": ("A ∨ B", "Activa los bits presentes en cualquiera de los dos operandos."),
    "XOR": ("A ⊕ B", "Activa los bits que difieren entre los operandos."),
    "NOR": ("¬(A ∨ B)", "Invierte el resultado de OR, dentro de los ocho bits."),
    "SRA": ("A >>> B", "Desplaza A a la derecha B posiciones, conservando el signo."),
    "SRL": ("A >> B", "Desplaza A a la derecha B posiciones y completa con ceros."),
    "INVÁLIDO (3F)": ("OP 3F", "Caso de control: un opcode inválido debe devolver cero."),
}
MANUAL_OPERATIONS = {**OPERATIONS, "INVÁLIDO (3F)": 0x3F}


def button(text: str, primary: bool = False) -> QPushButton:
    widget = QPushButton(text)
    if primary:
        widget.setObjectName("Primary")
    widget.setCursor(Qt.CursorShape.PointingHandCursor)
    return widget


def scroll_page() -> tuple[QScrollArea, QVBoxLayout]:
    scroll = QScrollArea()
    scroll.setWidgetResizable(True)
    content = QWidget()
    layout = QVBoxLayout(content)
    layout.setContentsMargins(28, 25, 28, 25)
    layout.setSpacing(19)
    scroll.setWidget(content)
    return scroll, layout


class LabWindow(QMainWindow):
    open_requested = Signal(str, int)
    disconnect_requested = Signal()
    run_requested = Signal(object)
    shutdown_requested = Signal()

    def __init__(self, demo: bool = False):
        super().__init__()
        self.setWindowTitle("UART Lab · Arquitectura de Computadoras")
        self.resize(1360, 940)
        self.setMinimumSize(1060, 760)
        self.connected = False
        self.connecting = False
        self.busy = False
        self.closing = False
        self.can_close = False
        self.source = ""
        self.job = ""
        self.job_total = 0
        self.job_done = 0
        self.job_passed = 0
        self.job_failed = 0
        self.records: list[dict] = []
        self.events: list[dict] = []
        self.suite_results: list[Transaction] = []
        self._build()
        self.thread = QThread(self)
        self.worker = LabWorker()
        self.worker.moveToThread(self.thread)
        self.open_requested.connect(self.worker.connect_link)
        self.disconnect_requested.connect(self.worker.disconnect_link)
        self.run_requested.connect(self.worker.run_cases)
        self.shutdown_requested.connect(self.worker.shutdown)
        self.worker.connection.connect(self._connection)
        self.worker.stage.connect(self._stage)
        self.worker.transaction.connect(self._transaction)
        self.worker.sent.connect(self._sent)
        self.worker.error.connect(self._error)
        self.worker.completed.connect(self._completed)
        self.worker.stopped.connect(self.thread.quit)
        self.thread.finished.connect(self.worker.deleteLater)
        self.thread.finished.connect(self._thread_finished)
        self.thread.start()
        self.refresh_ports()
        self._update_controls()
        self.send_shortcut = QShortcut(QKeySequence("Ctrl+Return"), self)
        self.send_shortcut.activated.connect(self.send_operation)
        if demo:
            self.port.setCurrentIndex(self.port.findData("demo"))
            QTimer.singleShot(0, self.toggle_connection)

    def _build(self):
        root = QWidget()
        root.setObjectName("Root")
        layout = QHBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(self._sidebar())
        body = QVBoxLayout()
        body.setSpacing(0)
        body.addWidget(self._connection_bar())
        self.pages = QStackedWidget()
        self.pages.addWidget(self._alu_page())
        self.pages.addWidget(self._tests_page())
        body.addWidget(self.pages, 1)
        layout.addLayout(body, 1)
        self.setCentralWidget(root)

    def _sidebar(self):
        sidebar = QFrame()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(184)
        layout = QVBoxLayout(sidebar)
        layout.setContentsMargins(18, 25, 18, 25)
        layout.setSpacing(15)
        brand = QHBoxLayout()
        brand.addWidget(LabMark())
        brand.addWidget(label("UART\nLAB", "Brand"))
        layout.addLayout(brand)
        layout.addSpacing(24)
        layout.addWidget(label("ESPACIO DE TRABAJO", "Eyebrow"))
        group = QButtonGroup(self)
        self.nav = []
        for index, text in enumerate(("ALU", "Pruebas")):
            nav = button(text)
            nav.setObjectName("Nav")
            nav.setCheckable(True)
            group.addButton(nav)
            nav.clicked.connect(lambda checked=False, i=index: self.pages.setCurrentIndex(i))
            layout.addWidget(nav)
            self.nav.append(nav)
        self.nav[0].setChecked(True)
        layout.addStretch()
        layout.addWidget(label("TP 02", "Badge"), alignment=Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(label("ALU + UART\nBasys 3 · 8 bits", "Muted"))
        layout.addSpacing(12)
        layout.addWidget(label("Arquitectura de\nComputadoras · UNC", "Muted"))
        return sidebar

    def _connection_bar(self):
        frame = QFrame()
        frame.setObjectName("ConnectionBar")
        layout = QHBoxLayout(frame)
        layout.setContentsMargins(28, 16, 28, 16)
        layout.setSpacing(10)
        layout.addWidget(label("ENLACE", "Eyebrow"))
        self.port = QComboBox()
        self.port.setAccessibleName("Puerto serie")
        self.port.setMinimumWidth(205)
        self.port.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        layout.addWidget(self.port, 1)
        self.refresh = button("↻")
        self.refresh.setAccessibleName("Actualizar puertos")
        self.refresh.setToolTip("Buscar puertos serie disponibles")
        self.refresh.clicked.connect(self.refresh_ports)
        layout.addWidget(self.refresh)
        self.baud = QComboBox()
        self.baud.setAccessibleName("Velocidad UART")
        self.baud.addItems(["19200", "9600", "38400", "57600", "115200"])
        self.baud.setToolTip("Debe coincidir con el bitstream. Cambiar este valor no reconfigura la FPGA.")
        self.baud.setFixedWidth(105)
        layout.addWidget(self.baud)
        layout.addWidget(label("baud", "Muted"))
        self.connect_button = button("Conectar", True)
        self.connect_button.clicked.connect(self.toggle_connection)
        layout.addWidget(self.connect_button)
        self.connection_status = label("●  Sin conexión", "Muted")
        layout.addWidget(self.connection_status)
        return frame

    def _header(self, layout, title: str, subtitle: str):
        layout.addWidget(label("ARQUITECTURA DE COMPUTADORAS / TP 02", "Eyebrow"))
        layout.addWidget(label(title, "Title"))
        layout.addWidget(label(subtitle, "Muted", True))

    def _alu_page(self):
        page, layout = scroll_page()
        self._header(layout, "Explorá cada bit.", "Operá la ALU, inspeccioná la respuesta y contrastala con el modelo.")
        self.notice = label("", "Notice", True)
        self.notice.hide()
        layout.addWidget(self.notice)
        workspace = QBoxLayout(QBoxLayout.Direction.LeftToRight)
        workspace.setSpacing(18)
        self.workspace = workspace
        left = QVBoxLayout()
        left.setSpacing(14)
        format_row = QHBoxLayout()
        format_row.addWidget(label("ENTRADA · 8 BITS", "Eyebrow"))
        format_row.addStretch()
        self.format = QComboBox()
        self.format.setAccessibleName("Formato de operandos")
        for text, base in (("Hexadecimal", 16), ("Decimal", 10), ("Binario", 2)):
            self.format.addItem(text, base)
        format_row.addWidget(self.format)
        left.addLayout(format_row)
        operands = QBoxLayout(QBoxLayout.Direction.LeftToRight)
        operands.setSpacing(14)
        self.operands_layout = operands
        self.a = OperandEditor("A", 0x7F)
        self.b = OperandEditor("B", 1)
        operands.addWidget(self.a, 1)
        operands.addWidget(self.b, 1)
        left.addLayout(operands)
        self.format.currentIndexChanged.connect(self._format_changed)
        self.a.changed.connect(self._update_controls)
        self.b.changed.connect(self._update_controls)
        op_card, op_layout = card()
        op_row = QHBoxLayout()
        op_row.addWidget(label("Operación", "CardTitle"))
        op_row.addStretch()
        self.operation = QComboBox()
        self.operation.setAccessibleName("Operación ALU")
        self.operation.addItems(list(MANUAL_OPERATIONS))
        self.operation.setMinimumWidth(110)
        op_row.addWidget(self.operation)
        op_layout.addLayout(op_row)
        self.op_description = label("", "Muted", True)
        op_layout.addWidget(self.op_description)
        send_row = QHBoxLayout()
        self.formula = label("", "ResultBinary")
        send_row.addWidget(self.formula)
        send_row.addStretch()
        self.send = button("Enviar operación  →", True)
        self.send.setToolTip("Enviar una solicitud · Ctrl+Enter")
        self.send.clicked.connect(self.send_operation)
        send_row.addWidget(self.send)
        op_layout.addLayout(send_row)
        left.addWidget(op_card)
        left.addStretch()
        self.operation.currentTextChanged.connect(self._operation_changed)
        self._operation_changed()
        workspace.addLayout(left, 3)
        self.result = ResultCard()
        self.result.setMinimumWidth(320)
        workspace.addWidget(self.result, 2)
        layout.addLayout(workspace)
        flow_card, flow = card()
        flow_row = QHBoxLayout()
        self.flow_status = label("Listo para conectar", "CardTitle")
        self.flow_packet = label("PC → A · B · OP     /     FPGA → resultado", "Muted")
        flow_row.addWidget(self.flow_status)
        flow_row.addStretch()
        flow_row.addWidget(self.flow_packet)
        flow.addLayout(flow_row)
        self.flow_steps = []
        rail = QHBoxLayout()
        for step in ("01  Solicitud", "02  Respuesta", "03  Verificación"):
            widget = label(step, "Muted")
            rail.addWidget(widget, 1)
            self.flow_steps.append(widget)
        flow.addLayout(rail)
        layout.addWidget(flow_card)
        log_card, log_layout = card()
        log_header = QHBoxLayout()
        self.log_toggle = button("▸  Registro de comunicación")
        self.log_toggle.setCheckable(True)
        self.log_toggle.clicked.connect(self._toggle_log)
        log_header.addWidget(self.log_toggle)
        log_header.addStretch()
        self.export = button("Guardar sesión")
        self.export.clicked.connect(self.save_session)
        log_header.addWidget(self.export)
        log_layout.addLayout(log_header)
        self.log = QPlainTextEdit()
        self.log.setAccessibleName("Registro de comunicación")
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(2000)
        self.log.setFixedHeight(160)
        self.log.hide()
        log_layout.addWidget(self.log)
        layout.addWidget(log_card)
        layout.addStretch()
        return page

    def _tests_page(self):
        page, layout = scroll_page()
        self._header(layout, "De la intuición a la evidencia.", "Casos reproducibles, resultados comparados y un registro que podés guardar.")
        self.test_notice = label("", "Notice", True)
        self.test_notice.hide()
        layout.addWidget(self.test_notice)
        controls, options = card()
        row = QHBoxLayout()
        self.suite = QComboBox()
        self.suite.setAccessibleName("Suite de pruebas")
        self.suite.addItem("Casos dirigidos · 13 operaciones", "directed")
        self.suite.addItem("Casos aleatorios", "random")
        self.suite.addItem("Dirigidos + aleatorios", "all")
        row.addWidget(self.suite, 1)
        self.run_tests = button("Ejecutar pruebas  →", True)
        self.run_tests.clicked.connect(self.start_suite)
        row.addWidget(self.run_tests)
        self.stop = button("Detener")
        self.stop.clicked.connect(self.cancel_suite)
        row.addWidget(self.stop)
        options.addLayout(row)
        config = QHBoxLayout()
        config.addWidget(label("Casos por operación", "Muted"))
        self.samples = QSpinBox()
        self.samples.setRange(1, 1000)
        self.samples.setValue(100)
        self.samples.setAccessibleName("Casos aleatorios por operación")
        config.addWidget(self.samples)
        config.addSpacing(18)
        config.addWidget(label("Semilla", "Muted"))
        self.seed = QLineEdit("0x1a2b3c4d")
        self.seed.setAccessibleName("Semilla de pruebas aleatorias")
        self.seed.setMaximumWidth(150)
        config.addWidget(self.seed)
        config.addStretch()
        self.save_tests = button("Guardar sesión")
        self.save_tests.clicked.connect(self.save_session)
        config.addWidget(self.save_tests)
        options.addLayout(config)
        self.suite.currentIndexChanged.connect(self._update_controls)
        layout.addWidget(controls)
        stats = QHBoxLayout()
        self.stats = []
        for caption in ("COMPLETADAS", "CORRECTAS", "DIFERENTES"):
            frame, column = card()
            column.addWidget(label(caption, "Eyebrow"))
            number = label("0", "Number")
            column.addWidget(number)
            self.stats.append(number)
            stats.addWidget(frame, 1)
        layout.addLayout(stats)
        progress_row = QHBoxLayout()
        self.test_status = label("Preparado para ejecutar", "Muted")
        self.progress_count = label("0 / 0", "Muted")
        progress_row.addWidget(self.test_status)
        progress_row.addStretch()
        progress_row.addWidget(self.progress_count)
        layout.addLayout(progress_row)
        self.progress = QProgressBar()
        self.progress.setRange(0, 1)
        self.progress.setValue(0)
        self.progress.setTextVisible(False)
        layout.addWidget(self.progress)
        self.table = QTableWidget(0, 7)
        self.table.setHorizontalHeaderLabels(["Caso", "A / B", "OP", "Esperado", "Recibido", "Tiempo", "Estado"])
        self.table.verticalHeader().hide()
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.table.setShowGrid(False)
        self.table.setMinimumHeight(270)
        self.table.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.itemSelectionChanged.connect(self.inspect_case)
        layout.addWidget(self.table, 1)
        self.case_detail = label("Seleccioná un caso para inspeccionar los bytes y su resultado.", "Muted", True)
        layout.addWidget(self.case_detail)
        self.replay = button("Cargar caso en la ALU")
        self.replay.clicked.connect(self.load_selected_case)
        self.replay.setEnabled(False)
        layout.addWidget(self.replay, alignment=Qt.AlignmentFlag.AlignLeft)
        return page

    def refresh_ports(self):
        selected = self.port.currentData()
        self.port.clear()
        try:
            ports = sorted(list_ports.comports(), key=lambda p: p.device)
            for port in ports:
                self.port.addItem(f"{port.device} · {port.description}", port.device)
        except OSError as exc:
            self._error(f"No se pudieron enumerar los puertos: {exc}")
        self.port.addItem("Simulación local · sin FPGA", "demo")
        previous = self.port.findData(selected)
        if previous >= 0:
            self.port.setCurrentIndex(previous)
        self.port.setToolTip("Elegí explícitamente el puerto del puente USB–UART o la simulación local.")

    def toggle_connection(self):
        if self.busy or self.connecting or self.closing:
            return
        self.connecting = True
        self._update_controls()
        if self.connected:
            self.disconnect_requested.emit()
        else:
            self.connection_status.setText("●  Conectando…")
            self.open_requested.emit(self.port.currentData(), int(self.baud.currentText()))

    def _connection(self, connected: bool, source: str):
        self.connecting = False
        self.connected = connected
        self.source = source
        self.connect_button.setText("Desconectar" if connected else "Conectar")
        self.connection_status.setObjectName("Success" if connected else "Muted")
        self.connection_status.setText("●  Simulación" if source == "simulacion_local" else "●  Conectado" if connected else "●  Sin conexión")
        restyle(self.connection_status)
        if connected:
            self.result.clear()
            demo = source == "simulacion_local"
            self._notice("Simulación local activa. Los resultados provienen del modelo; no hay una FPGA conectada." if demo else "")
            self._log("ENLACE", f"{'Simulación local' if demo else source + ' · ' + self.baud.currentText() + ' baud · 8N1'} conectado")
            self.flow_status.setText("Listo para enviar")
        else:
            if self.notice.text().startswith("Simulación local activa"):
                self._notice("")
            self.flow_status.setText("Enlace desconectado")
            self._log("ENLACE", "Desconectado")
        self._update_controls()

    def _notice(self, text: str):
        for widget in (self.notice, self.test_notice):
            widget.setText(text)
            widget.setVisible(bool(text))

    def _format_changed(self):
        for editor in (self.a, self.b):
            editor.set_base(self.format.currentData())

    def _operation_changed(self):
        name = self.operation.currentText()
        formula, description = OP_DESCRIPTIONS[name]
        self.formula.setText(formula)
        self.op_description.setText(f"{description}\nOpcode: {MANUAL_OPERATIONS[name]:02X}")

    def _update_controls(self):
        # Called by input widgets during construction, before the rest exists.
        if not hasattr(self, "run_tests"):
            return
        idle = not self.busy and not self.connecting and not self.closing
        self.connect_button.setEnabled(idle)
        for widget in (self.port, self.baud, self.refresh):
            widget.setEnabled(idle and not self.connected)
        self.send.setEnabled(idle and self.connected and self.a.valid and self.b.valid)
        self.run_tests.setEnabled(idle and self.connected)
        canceling = hasattr(self, "worker") and self.worker.cancel.is_set()
        self.stop.setEnabled(self.busy and self.job == "suite" and not canceling)
        for widget in (self.a, self.b, self.operation, self.format, self.suite):
            widget.setEnabled(idle)
        random_enabled = idle and self.suite.currentData() != "directed"
        self.samples.setEnabled(random_enabled)
        self.seed.setEnabled(random_enabled)
        self.replay.setEnabled(idle and bool(self.table.selectedItems()))
        self.export.setEnabled(bool(self.events))
        self.save_tests.setEnabled(bool(self.events))

    def _start(self, cases: list[TestCase], job: str):
        if self.busy or self.connecting or not self.connected or self.closing:
            return
        self.worker.cancel.clear()
        self.busy = True
        self.job = job
        self.job_total = len(cases)
        self.job_done = self.job_passed = self.job_failed = 0
        if job == "suite":
            self.table.setRowCount(0)
            self.suite_results.clear()
            self.case_detail.setText("Seleccioná un caso para inspeccionar los bytes y su resultado.")
            self.progress.setRange(0, len(cases))
            self.progress.setValue(0)
            self.progress_count.setText(f"0 / {len(cases)}")
            for stat in self.stats:
                stat.setText("0")
            self.test_status.setText("Ejecutando pruebas…")
        if self.source != "simulacion_local":
            self._notice("")
        self._update_controls()
        self.run_requested.emit(cases)

    def send_operation(self):
        if self.a.valid and self.b.valid:
            name = self.operation.currentText()
            self._start([TestCase(self.a.value, self.b.value, MANUAL_OPERATIONS[name], name)], "manual")

    def start_suite(self):
        kind = self.suite.currentData()
        cases = directed_cases() if kind in ("directed", "all") else []
        if kind in ("random", "all"):
            try:
                seed = int(self.seed.text(), 0)
                if not 0 <= seed <= 0xFFFFFFFF:
                    raise ValueError
            except ValueError:
                self._error("Ingresá una semilla entre 0 y 0xFFFFFFFF, por ejemplo 0x1a2b3c4d.")
                self.seed.setFocus()
                return
            cases.extend(random_cases(self.samples.value(), seed))
        self._log("PRUEBAS", f"{kind} · {len(cases)} casos · semilla {self.seed.text()}")
        self._start(cases, "suite")

    def cancel_suite(self):
        self.worker.cancel.set()
        self.test_status.setText("Deteniendo al terminar la transacción actual…")
        self._update_controls()

    def _stage(self, text: str):
        self.flow_status.setText(text)
        index = 0 if text == "Enviando solicitud" else 1
        for i, widget in enumerate(self.flow_steps):
            widget.setObjectName("Success" if i <= index else "Muted")
            restyle(widget)

    def _transaction(self, result: Transaction):
        self.records.append(result.record())
        self.job_done += 1
        self.job_passed += int(result.passed)
        self.job_failed += int(not result.passed)
        self.result.show_transaction(result)
        self.flow_packet.setText(f"TX  {result.case.a:02X} {result.case.b:02X} {result.case.opcode:02X}    →    RX  {result.received:02X}")
        for widget in self.flow_steps:
            widget.setObjectName("Success" if result.passed else "Error")
            restyle(widget)
        self._log("RX", f"{result.received:02X} · esperado {result.expected:02X} · {result.elapsed_ms:.1f} ms · {'OK' if result.passed else 'DIFERENTE'}")
        if self.job == "suite":
            self.suite_results.append(result)
            row = self.table.rowCount()
            self.table.insertRow(row)
            names = {v: k for k, v in OPERATIONS.items()}
            values = [result.case.description, f"{result.case.a:02X} / {result.case.b:02X}",
                      names.get(result.case.opcode, f"{result.case.opcode:02X}"), f"{result.expected:02X}",
                      f"{result.received:02X}", f"{result.elapsed_ms:.1f} ms", "OK" if result.passed else "DIFERENTE"]
            for column, value in enumerate(values):
                item = QTableWidgetItem(value)
                if column == 6:
                    item.setForeground(QColor("#91e3c8" if result.passed else "#ffaaa4"))
                self.table.setItem(row, column, item)
            self.progress.setValue(self.job_done)
            self.progress_count.setText(f"{self.job_done} / {self.job_total}")
            for stat, value in zip(self.stats, (self.job_done, self.job_passed, self.job_failed)):
                stat.setText(str(value))
        if not result.passed:
            self._notice("La respuesta difiere del modelo. La suite se detuvo; revisá el caso y reconectá si hubo errores de enlace.")
        self._update_controls()

    def _sent(self, case: TestCase):
        packet = f"{case.a:02X} {case.b:02X} {case.opcode:02X}"
        self.flow_packet.setText(f"TX  {packet}    →    esperando RX")
        self._log("TX", f"{packet} · {case.description}")

    def _error(self, text: str):
        self._notice(text)
        self.flow_status.setText("Revisá el enlace")
        self.flow_steps[1].setObjectName("Error")
        restyle(self.flow_steps[1])
        self._log("ERROR", text)

    def _completed(self, canceled: bool):
        self.busy = False
        state = "Detenida" if canceled else "Finalizada" if self.job_done == self.job_total else "Interrumpida"
        if self.job == "suite":
            self.test_status.setText(f"{state} · {self.job_passed} correctas · {self.job_failed} diferentes")
            self._log("PRUEBAS", f"{state}: {self.job_done}/{self.job_total} casos")
        self.flow_status.setText("Resultado verificado" if self.job_done and not self.job_failed else "Revisá el resultado" if self.job_failed else "Sin respuesta")
        self._update_controls()

    def _log(self, kind: str, message: str):
        timestamp = datetime.now().astimezone().isoformat(timespec="milliseconds")
        self.events.append({"timestamp": timestamp, "kind": kind, "message": message, "source": self.source})
        self.log.appendPlainText(f"{timestamp[11:23]}  {kind:<7}  {message}")
        self.export.setEnabled(True)
        self.save_tests.setEnabled(True)

    def _toggle_log(self, checked: bool):
        self.log.setVisible(checked)
        self.log_toggle.setText(f"{'▾' if checked else '▸'}  Registro de comunicación")

    def session_document(self) -> dict:
        return {"schema_version": 1, "application": "UART Lab", "protocol": "tp2-alu-3bytes",
                "exported_at": datetime.now().astimezone().isoformat(),
                "flags_origin": "modelo_esperado_no_recibido_por_uart",
                "transactions": self.records, "events": self.events}

    def save_session(self):
        path, _ = QFileDialog.getSaveFileName(self, "Guardar sesión", "uart-lab-session.json", "Sesión JSON (*.json)")
        if not path:
            return
        try:
            with open(path, "w", encoding="utf-8") as stream:
                json.dump(self.session_document(), stream, indent=2, ensure_ascii=False)
                stream.write("\n")
            self._log("ARCHIVO", f"Sesión guardada en {path}")
        except OSError as exc:
            self._error(f"No se pudo guardar la sesión: {exc}")

    def inspect_case(self):
        row = self.table.currentRow()
        if row < 0 or row >= len(self.suite_results):
            return
        result = self.suite_results[row]
        self.case_detail.setText(
            f"{result.case.description} · TX {result.case.a:02X} {result.case.b:02X} {result.case.opcode:02X}"
            f" → RX {result.received:02X} · esperado {result.expected:02X}"
            f" · {'simulación local' if result.source == 'simulacion_local' else result.source}"
        )
        self._update_controls()

    def load_selected_case(self):
        row = self.table.currentRow()
        if not 0 <= row < len(self.suite_results) or self.busy:
            return
        case = self.suite_results[row].case
        self.a.set_value(case.a)
        self.b.set_value(case.b)
        name = next((name for name, code in MANUAL_OPERATIONS.items() if code == case.opcode), None)
        if name:
            self.operation.setCurrentText(name)
        else:
            self._notice("Este opcode no está disponible en el selector manual.")
            return
        self.nav[0].setChecked(True)
        self.pages.setCurrentIndex(0)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if hasattr(self, "operands_layout"):
            self.operands_layout.setDirection(QBoxLayout.Direction.TopToBottom if self.width() < 1250 else QBoxLayout.Direction.LeftToRight)

    def closeEvent(self, event):
        if self.can_close:
            event.accept()
            return
        event.ignore()
        if not self.closing:
            self.closing = True
            self.worker.cancel.set()
            self._update_controls()
            # Se encola tras la transacción actual. El puerto se cierra en su hilo.
            self.shutdown_requested.emit()

    def _thread_finished(self):
        self.can_close = True
        self.close()
