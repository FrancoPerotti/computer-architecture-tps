#!/usr/bin/env python3
"""UART Lab: interfaz gráfica del TP2. Usar --demo para explorarla sin placa."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--demo", action="store_true", help="conecta al modelo local, sin hardware")
    args = parser.parse_args()
    try:
        from PySide6.QtWidgets import QApplication
        from PySide6.QtGui import QIcon
        from uart_lab.theme import STYLE
        from uart_lab.window import LabWindow
    except ImportError as exc:
        print("Faltan dependencias. Instalá: python -m pip install -r tp2/tools/requirements-gui.txt", file=sys.stderr)
        print(str(exc), file=sys.stderr)
        return 1
    app = QApplication(sys.argv[:1])
    app.setApplicationName("UART Lab")
    app.setOrganizationName("Arquitectura de Computadoras · UNC")
    app.setStyle("Fusion")
    app.setStyleSheet(STYLE)
    app.setWindowIcon(QIcon(str(Path(__file__).parent / "uart_lab/assets/lab.svg")))
    window = LabWindow(demo=args.demo)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
