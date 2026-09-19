"""Estilo compartido por las vistas del laboratorio."""

from pathlib import Path

STYLE = """
* { font-family: 'Inter', 'Noto Sans', sans-serif; font-size: 13px; color: #dce5eb; }
QMainWindow, QWidget#Root { background: #101418; }
QDialog { background: #191f25; }
QWidget { background: transparent; }
QFrame#Sidebar { background: #141a1f; border-right: 1px solid #273039; }
QFrame#ConnectionBar { background: #141a1f; border-bottom: 1px solid #273039; }
QFrame#Card { background: #191f25; border: 1px solid #303a43; border-radius: 14px; }
QFrame#ResultCard { background: #172725; border: 1px solid #365b53; border-radius: 14px; }
QLabel { border: none; }
QLabel#Muted { color: #a0adb8; }
QLabel#Eyebrow { color: #a6b4bf; font-size: 11px; font-weight: 600; }
QLabel#Title { font-size: 29px; font-weight: 600; color: #f0f5f7; }
QLabel#CardTitle { font-size: 17px; font-weight: 600; }
QLabel#Brand { font-size: 21px; font-weight: 700; letter-spacing: 1px; }
QLabel#HexResult { font-family: 'JetBrains Mono', 'DejaVu Sans Mono', monospace;
 font-size: 78px; font-weight: 600; color: #8ce6c9; }
QLabel#ResultBinary { font-family: 'JetBrains Mono', 'DejaVu Sans Mono', monospace;
 font-size: 23px; color: #c0e9dc; }
QLabel#Number { font-size: 29px; font-weight: 600; }
QLabel#Success { color: #8ce6c9; }
QLabel#Error { color: #ffaaa4; }
QLabel#Notice { background: #302922; border: 1px solid #685442; border-radius: 8px;
 padding: 11px 14px; color: #f0cfa9; }
QLabel#Badge { background: #24332e; border: 1px solid #3b5a4b;
 border-radius: 6px; padding: 5px 9px; color: #ade7cf; font-size: 11px; }
QLabel#Flag { background: #23332e; border: 1px solid #416054; border-radius: 7px;
 padding: 7px 9px; color: #a9bdb5; font-family: 'DejaVu Sans Mono'; }
QLabel#Flag[active=true] { color: #9eefce; border-color: #699c85; }
QPushButton, QToolButton { background: #252e36; border: 1px solid #3b4854;
 border-radius: 7px; padding: 9px 14px; font-weight: 500; }
QPushButton:hover, QToolButton:hover { background: #303d47; border-color: #637783; }
QPushButton:pressed, QToolButton:pressed { background: #172027; }
QPushButton:focus, QToolButton:focus { border: 1px solid #a2e9d3; }
QPushButton:disabled, QToolButton:disabled { color: #6c7984; background: #1e262d; border-color: #2e3942; }
QPushButton#Primary { background: #91e3c8; color: #10231c; border: 1px solid #91e3c8; font-weight: 600; }
QPushButton#Primary:hover { background: #b1f0dc; border-color: #b1f0dc; }
QPushButton#Primary:disabled { background: #293d35; color: #748e83; border-color: #385247; }
QPushButton#Nav { text-align: left; background: transparent; color: #a6b3bd;
 border: 1px solid transparent; padding: 12px 15px; }
QPushButton#Nav:checked { background: #22352f; color: #a4efd4; border-color: #365347; }
QPushButton#Nav:hover { background: #243039; }
QPushButton#Bit { padding: 6px 0; background: #11191f; color: #8c9da8;
 font-family: 'DejaVu Sans Mono'; font-size: 18px; border-color: #3a4751; }
QPushButton#Bit:checked { background: #284c3e; color: #a7f4d7; border-color: #548d73; }
QLineEdit, QComboBox, QSpinBox { background: #10181e; border: 1px solid #40505e;
 border-radius: 7px; padding: 9px 11px; selection-background-color: #355e50; }
QLineEdit:focus, QComboBox:focus, QSpinBox:focus { border-color: #91e3c8; }
QLineEdit[invalid=true] { border-color: #ef8f88; }
QLineEdit:disabled, QComboBox:disabled, QSpinBox:disabled { color: #71808a; border-color: #2e3942; }
QLineEdit#OperandValue { font-family: 'JetBrains Mono', 'DejaVu Sans Mono', monospace;
 font-size: 38px; font-weight: 500; padding: 7px 11px; }
QComboBox { padding-right: 25px; }
QComboBox::drop-down { width: 22px; border: none; }
QComboBox QAbstractItemView { background: #1e2932; color: #e4ecef;
 selection-background-color: #34564b; border: 1px solid #4b5d6a; padding: 4px; }
QProgressBar { background: #10181e; border: none; border-radius: 4px; height: 8px; }
QProgressBar::chunk { background: #91e3c8; border-radius: 4px; }
QTableWidget { background: #151c22; border: 1px solid #303d47;
 border-radius: 9px; gridline-color: #26323b; selection-background-color: #2c483e; }
QTableWidget::item { padding: 7px; border-bottom: 1px solid #27333c; }
QTableWidget::item:selected { background: #2c483e; color: #effaf5; }
QHeaderView::section { background: #1d2831; color: #aebfc9; border: none;
 border-bottom: 1px solid #3b4a56; padding: 11px 8px; font-weight: 600; }
QPlainTextEdit { background: #10181e; border: 1px solid #303d47; border-radius: 8px;
 padding: 8px; font-family: 'JetBrains Mono', 'DejaVu Sans Mono', monospace;
 font-size: 12px; color: #b7c8d3; selection-background-color: #34564b; }
QScrollArea { border: none; background: transparent; }
QScrollBar:vertical { background: transparent; width: 8px; margin: 0; }
QScrollBar::handle:vertical { background: #445563; border-radius: 4px; min-height: 30px; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical { background: transparent; }
QToolTip { background: #26333e; color: #f0f5f7; border: 1px solid #647d8d; padding: 5px; }
"""

_icons = (Path(__file__).parent / "assets").as_posix()
STYLE += f"""
QComboBox::down-arrow {{ image: url('{_icons}/chevron-down.svg'); width: 12px; height: 12px; }}
QSpinBox::up-button {{ width: 20px; border: none; subcontrol-origin: border; subcontrol-position: top right; }}
QSpinBox::down-button {{ width: 20px; border: none; subcontrol-origin: border; subcontrol-position: bottom right; }}
QSpinBox::up-arrow {{ image: url('{_icons}/chevron-up.svg'); width: 10px; height: 10px; }}
QSpinBox::down-arrow {{ image: url('{_icons}/chevron-down.svg'); width: 10px; height: 10px; }}
"""
