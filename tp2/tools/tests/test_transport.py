from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

from support import VirtualFPGA
from uart_lab.protocol import OPERATIONS, TestCase as Case, directed_cases
from uart_lab.session import execute_tp2
from uart_lab.transport import LinkError, SerialTransport


@unittest.skipUnless(hasattr(os, "openpty"), "Requiere pseudo-terminal POSIX")
class SerialIntegrationTests(unittest.TestCase):
    def open_board(self, respond=None):
        board = VirtualFPGA(respond)
        self.addCleanup(board.close)
        link = SerialTransport.connect(board.name)
        self.addCleanup(link.close)
        return board, link

    def test_wire_packet_stages_and_expected_flags(self):
        board, link = self.open_board()
        stages = []
        result = execute_tp2(link, Case(0x7F, 1, OPERATIONS["ADD"], "overflow"), board.name, stages.append)
        self.assertEqual(board.requests, [b"\x7f\x01\x20"])
        self.assertEqual(result.received, 0x80)
        self.assertTrue(result.passed)
        self.assertEqual(result.flags, (0, 0, 1))
        self.assertEqual(stages, ["Enviando solicitud", "Esperando respuesta"])
        self.assertEqual(result.record()["source"], board.name)

    def test_timeout_is_reported(self):
        _, link = self.open_board(lambda _: b"")
        with self.assertRaisesRegex(LinkError, "No llegó"):
            link.exchange(b"\x05\x03\x20")

    def test_extra_response_is_rejected(self):
        _, link = self.open_board(lambda _: b"\x08\x99")
        with self.assertRaisesRegex(LinkError, "adicionales"):
            link.exchange(b"\x05\x03\x20")

    def test_transport_supports_future_multibyte_responses(self):
        _, link = self.open_board(lambda _: b"\x01\x02\x03\x04")
        self.assertEqual(link.exchange(b"\x10\x20\x30", response_size=4), b"\x01\x02\x03\x04")

    def test_cli_directed_suite_keeps_working_over_serial(self):
        board = VirtualFPGA()
        self.addCleanup(board.close)
        script = Path(__file__).resolve().parents[1] / "uart_alu_client.py"
        result = subprocess.run(
            [sys.executable, str(script), "--port", board.name, "--suite", "directed"],
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: 13 operaciones", result.stdout)
        self.assertEqual(board.requests, [bytes((c.a, c.b, c.opcode)) for c in directed_cases()])


if __name__ == "__main__":
    unittest.main()
