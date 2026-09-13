from __future__ import annotations

import json
import os
import time
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from support import VirtualFPGA
from PySide6.QtCore import Qt
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication
from uart_lab.theme import STYLE
from uart_lab.window import LabWindow


def wait_until(predicate, timeout=4):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        QApplication.processEvents()
        if predicate():
            return
        QTest.qWait(10)
    raise AssertionError("La interfaz no llegó al estado esperado")


class GuiIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])
        cls.app.setStyle("Fusion")
        cls.app.setStyleSheet(STYLE)

    def setUp(self):
        self.window = LabWindow(demo=True)
        self.window.show()
        wait_until(lambda: self.window.connected)

    def tearDown(self):
        self.window.close()
        wait_until(lambda: not self.window.thread.isRunning())
        QApplication.processEvents()

    def test_bits_formats_and_invalid_input(self):
        w = self.window
        QTest.mouseClick(w.a.bits[0], Qt.MouseButton.LeftButton)
        self.assertEqual(w.a.value, 0xFF)
        w.format.setCurrentIndex(w.format.findData(2))
        self.assertEqual(w.a.input.text(), "11111111")
        w.format.setCurrentIndex(w.format.findData(10))
        self.assertEqual(w.a.input.text(), "255")
        w.a.input.selectAll()
        QTest.keyClicks(w.a.input, "256")
        self.assertFalse(w.a.valid)
        self.assertFalse(w.send.isEnabled())
        w.a.input.selectAll()
        QTest.keyClicks(w.a.input, "127")
        self.assertTrue(w.send.isEnabled())

    def test_manual_operation_and_export_provenance(self):
        w = self.window
        QTest.mouseClick(w.send, Qt.MouseButton.LeftButton)
        wait_until(lambda: not w.busy and len(w.records) == 1)
        self.assertEqual(w.result.hex.text(), "80")
        self.assertEqual(w.result.binary.text(), "1000 0000")
        self.assertEqual(w.result.source.text(), "SIMULACIÓN")
        saved = json.loads(json.dumps(w.session_document()))
        self.assertEqual(saved["transactions"][0]["source"], "simulacion_local")
        self.assertEqual(saved["transactions"][0]["flags"], [0, 0, 1])
        self.assertIn("no_recibido", saved["flags_origin"])
        self.assertIn("modelo", w.notice.text())

    def test_save_session_writes_actual_json_file(self):
        w = self.window
        w.send_operation()
        wait_until(lambda: not w.busy and len(w.records) == 1)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "session.json"
            with patch("uart_lab.window.QFileDialog.getSaveFileName", return_value=(str(path), "")):
                w.save_session()
            saved = json.loads(path.read_text())
        self.assertEqual(saved["transactions"][0]["received"], 0x80)
        self.assertEqual(saved["transactions"][0]["source"], "simulacion_local")
        self.assertTrue(any(event["kind"] == "TX" for event in saved["events"]))

    def test_directed_suite_and_replay_invalid_opcode(self):
        w = self.window
        w.pages.setCurrentIndex(1)
        QTest.mouseClick(w.run_tests, Qt.MouseButton.LeftButton)
        wait_until(lambda: not w.busy and w.job_done == 13)
        self.assertEqual(w.table.rowCount(), 13)
        self.assertEqual(w.job_passed, 13)
        w.table.selectRow(12)
        self.assertIn("TX 12 34 3F", w.case_detail.text())
        QTest.mouseClick(w.replay, Qt.MouseButton.LeftButton)
        self.assertEqual(w.pages.currentIndex(), 0)
        self.assertEqual(w.operation.currentText(), "INVÁLIDO (3F)")

    def test_random_suite_can_be_canceled_without_freezing(self):
        w = self.window
        w.suite.setCurrentIndex(w.suite.findData("random"))
        w.pages.setCurrentIndex(1)
        QTest.mouseClick(w.run_tests, Qt.MouseButton.LeftButton)
        wait_until(lambda: w.job_done >= 2)
        QTest.mouseClick(w.stop, Qt.MouseButton.LeftButton)
        wait_until(lambda: not w.busy)
        self.assertLess(w.job_done, 800)
        self.assertIn("Detenida", w.test_status.text())
        self.assertTrue(w.connected)
        self.assertTrue(w.run_tests.isEnabled())

    def test_invalid_seed_does_not_start_job(self):
        w = self.window
        w.suite.setCurrentIndex(w.suite.findData("random"))
        w.seed.setText("hola")
        w.start_suite()
        self.assertFalse(w.busy)
        self.assertIn("semilla", w.test_notice.text())

    def test_connection_error_is_visible(self):
        w = self.window
        w.toggle_connection()
        wait_until(lambda: not w.connected and not w.connecting)
        w.port.addItem("Inexistente", "/definitely/not/a/serial/port")
        w.port.setCurrentIndex(w.port.count() - 1)
        w.toggle_connection()
        wait_until(lambda: not w.connecting)
        self.assertFalse(w.connected)
        self.assertIn("No se pudo abrir", w.notice.text())
        self.assertFalse(w.send.isEnabled())

    @unittest.skipUnless(hasattr(os, "openpty"), "Requiere pseudo-terminal POSIX")
    def test_gui_real_serial_and_timeout_disconnect(self):
        board = VirtualFPGA(lambda _: b"")
        self.addCleanup(board.close)
        w = self.window
        w.toggle_connection()
        wait_until(lambda: not w.connected and not w.connecting)
        w.port.addItem("FPGA virtual", board.name)
        w.port.setCurrentIndex(w.port.count() - 1)
        w.toggle_connection()
        wait_until(lambda: w.connected)
        w.send_operation()
        wait_until(lambda: not w.busy and not w.connected)
        self.assertEqual(board.requests, [b"\x7f\x01\x20"])
        self.assertTrue(any(e['kind'] == 'TX' and '7F 01 20' in e['message'] for e in w.events))
        self.assertIn("No llegó", w.notice.text())
        self.assertFalse(w.send.isEnabled())

    @unittest.skipUnless(hasattr(os, "openpty"), "Requiere pseudo-terminal POSIX")
    def test_real_serial_success_and_suite_stops_on_mismatch(self):
        board = VirtualFPGA()
        self.addCleanup(board.close)
        w = self.window
        w.toggle_connection()
        wait_until(lambda: not w.connected and not w.connecting)
        w.port.addItem("FPGA virtual", board.name)
        w.port.setCurrentIndex(w.port.count() - 1)
        w.toggle_connection()
        wait_until(lambda: w.connected)
        w.send_operation()
        wait_until(lambda: not w.busy and len(w.records) == 1)
        self.assertEqual(w.result.source.text(), "UART / FPGA")
        self.assertEqual(w.records[0]["source"], board.name)
        self.assertEqual(w.records[0]["received"], 0x80)
        board.respond = lambda _: b"\x81"
        w.start_suite()
        wait_until(lambda: not w.busy and w.job_done == 1)
        self.assertEqual(w.job_failed, 1)
        self.assertEqual(w.table.rowCount(), 1)
        self.assertIn("difiere", w.test_notice.text())
        self.assertEqual(len(board.requests), 2)

    def test_close_during_suite_stops_worker(self):
        w = self.window
        w.suite.setCurrentIndex(w.suite.findData("random"))
        w.start_suite()
        wait_until(lambda: w.job_done >= 1)
        w.close()
        wait_until(lambda: not w.thread.isRunning())
        self.assertFalse(w.isVisible())


if __name__ == "__main__":
    unittest.main()
