"""Componentes visuales del laboratorio; sin acceso al puerto serie."""

from __future__ import annotations

from PySide6.QtCore import QEasingCurve, QPropertyAnimation, Qt, Signal
from PySide6.QtGui import QColor, QPainter, QPen
from PySide6.QtWidgets import (
    QFrame, QGraphicsOpacityEffect, QHBoxLayout, QLabel, QLineEdit, QPushButton, QVBoxLayout, QWidget,
)


def label(text: str, name: str = "", wrap: bool = False) -> QLabel:
    widget = QLabel(text)
    widget.setObjectName(name)
    widget.setWordWrap(wrap)
    return widget


def restyle(widget: QWidget):
    widget.style().unpolish(widget)
    widget.style().polish(widget)
    widget.update()


def card(name: str = "Card") -> tuple[QFrame, QVBoxLayout]:
    frame = QFrame()
    frame.setObjectName(name)
    layout = QVBoxLayout(frame)
    layout.setContentsMargins(22, 20, 22, 20)
    layout.setSpacing(14)
    return frame, layout


class LabMark(QWidget):
    def __init__(self):
        super().__init__()
        self.setFixedSize(40, 40)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(QColor("#91e3c8"))
        p.drawRoundedRect(0, 0, 40, 40, 11, 11)
        p.setPen(QPen(QColor("#142a22"), 2))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawRoundedRect(12, 12, 16, 16, 3, 3)
        for n in (16, 24):
            p.drawLine(n, 8, n, 12)
            p.drawLine(n, 28, n, 32)
            p.drawLine(8, n, 12, n)
            p.drawLine(28, n, 32, n)
        p.drawLine(17, 22, 20, 17)
        p.drawLine(20, 17, 23, 22)


class OperandEditor(QFrame):
    changed = Signal()

    def __init__(self, name: str, initial: int):
        super().__init__()
        self.setObjectName("Card")
        self.value = initial
        self.base = 16
        self.valid = True
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 18, 20, 18)
        layout.setSpacing(11)
        layout.addWidget(label(f"OPERANDO {name}", "Eyebrow"))
        self.input = QLineEdit()
        self.input.setObjectName("OperandValue")
        self.input.setAccessibleName(f"Operando {name}")
        self.input.setMaxLength(10)
        layout.addWidget(self.input)
        self.description = label("", "Muted")
        layout.addWidget(self.description)
        bits = QHBoxLayout()
        bits.setSpacing(5)
        self.bits: list[QPushButton] = []
        for bit in range(7, -1, -1):
            column = QVBoxLayout()
            column.setSpacing(5)
            button = QPushButton()
            button.setObjectName("Bit")
            button.setCheckable(True)
            button.setMinimumWidth(24)
            button.setFixedHeight(34)
            button.setAccessibleName(f"Operando {name}, bit {bit}")
            button.setToolTip(f"Bit {bit} · valor {1 << bit}")
            button.clicked.connect(lambda checked=False, b=bit: self.set_value(self.value ^ (1 << b)))
            self.bits.append(button)
            column.addWidget(button)
            bit_label = label(str(bit), "Muted")
            bit_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            column.addWidget(bit_label)
            bits.addLayout(column, 1)
        layout.addLayout(bits)
        self.input.textEdited.connect(self._edited)
        self.set_value(initial)

    def _edited(self, text: str):
        try:
            value = int(text, self.base)
            if not 0 <= value <= 255:
                raise ValueError
            self.value = value
            self.valid = True
        except ValueError:
            self.valid = False
        self.input.setProperty("invalid", not self.valid)
        restyle(self.input)
        self._details()
        self.changed.emit()

    def _details(self):
        if not self.valid:
            self.description.setText("Ingresá un valor de 0 a 255 en el formato elegido.")
            return
        signed = self.value - 256 if self.value & 128 else self.value
        self.description.setText(f"{self.value} sin signo   /   {signed} con signo")
        for i, button in enumerate(self.bits):
            enabled = bool(self.value & (1 << (7 - i)))
            button.setChecked(enabled)
            button.setText("1" if enabled else "0")

    def set_value(self, value: int):
        self.value = value
        self.valid = True
        self.input.setProperty("invalid", False)
        restyle(self.input)
        text = f"{value:02X}" if self.base == 16 else f"{value:08b}" if self.base == 2 else str(value)
        self.input.setText(text)
        self._details()
        self.changed.emit()

    def set_base(self, base: int):
        self.base = base
        self.set_value(self.value)


class ResultCard(QFrame):
    def __init__(self):
        super().__init__()
        self.setObjectName("ResultCard")
        layout = QVBoxLayout(self)
        layout.setContentsMargins(26, 23, 26, 23)
        layout.setSpacing(10)
        heading = QHBoxLayout()
        heading.addWidget(label("ÚLTIMA RESPUESTA", "Eyebrow"))
        heading.addStretch()
        self.source = label("SIN DATOS", "Badge")
        heading.addWidget(self.source)
        layout.addLayout(heading)
        number = QHBoxLayout()
        self.hex = label("—", "HexResult")
        effect = QGraphicsOpacityEffect(self.hex)
        self.hex.setGraphicsEffect(effect)
        self.animation = QPropertyAnimation(effect, b"opacity", self)
        self.animation.setDuration(160)
        self.animation.setStartValue(0.55)
        self.animation.setEndValue(1.0)
        self.animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        number.addWidget(self.hex)
        number.addWidget(label("HEX", "Muted"), alignment=Qt.AlignmentFlag.AlignBottom)
        number.addStretch()
        layout.addLayout(number)
        self.binary = label("···· ····", "ResultBinary")
        layout.addWidget(self.binary)
        self.decimal = label("Enviá una operación para ver el resultado.", "Muted", True)
        layout.addWidget(self.decimal)
        self.request = label("", "Muted")
        layout.addWidget(self.request)
        layout.addStretch()
        self.verdict = label("Esperando la primera operación", "Muted", True)
        layout.addWidget(self.verdict)
        self.flags_caption = label("BANDERAS ESPERADAS · MODELO LOCAL", "Eyebrow")
        layout.addWidget(self.flags_caption)
        flags = QHBoxLayout()
        self.flag_labels = []
        for text in ("Z", "C", "V"):
            widget = label(f"{text}  —", "Flag")
            widget.setToolTip("Valor esperado por el modelo. UART no transmite banderas; verificarlas en los LED.")
            flags.addWidget(widget)
            self.flag_labels.append(widget)
        layout.addLayout(flags)
        layout.addWidget(label("Z, C y V se verifican físicamente en los LED.", "Muted", True))

    def show_transaction(self, transaction):
        value = transaction.received
        self.hex.setText(f"{value:02X}")
        self.animation.stop()
        self.animation.start()
        bits = f"{value:08b}"
        self.binary.setText(f"{bits[:4]} {bits[4:]}")
        self.decimal.setText(f"{value} sin signo   /   {value - 256 if value & 128 else value} con signo")
        self.source.setText("SIMULACIÓN" if transaction.source == "simulacion_local" else "UART / FPGA")
        self.request.setText(f"Solicitud · {transaction.case.a:02X} {transaction.case.b:02X} {transaction.case.opcode:02X}")
        self.verdict.setObjectName("Success" if transaction.passed else "Error")
        self.verdict.setText(
            f"{'Coincide con el modelo' if transaction.passed else f'Esperado: {transaction.expected:02X} · resultado diferente'}"
            f"   ·   {transaction.elapsed_ms:.1f} ms"
        )
        restyle(self.verdict)
        for name, widget, active in zip(("Z", "C", "V"), self.flag_labels, transaction.flags):
            widget.setText(f"{name}  {active}")
            widget.setProperty("active", bool(active))
            restyle(widget)

    def clear(self):
        self.hex.setText("—")
        self.binary.setText("···· ····")
        self.decimal.setText("Enviá una operación para ver el resultado.")
        self.source.setText("SIN DATOS")
        self.request.setText("")
        self.verdict.setText("Esperando la primera operación")
        self.verdict.setObjectName("Muted")
        restyle(self.verdict)
        for name, widget in zip(("Z", "C", "V"), self.flag_labels):
            widget.setText(f"{name}  —")
            widget.setProperty("active", False)
            restyle(widget)
