"""Executable contract for the local instruction reference used by the IDE."""

import json
import unittest
from pathlib import Path

from software.assembler import _INSTRUCTIONS, assemble

CONTENT = Path(__file__).resolve().parents[2] / "resources/content"


class InstructionHelpTests(unittest.TestCase):
    def setUp(self):
        self.rows = json.loads((CONTENT / "instructions.json").read_text(encoding="utf-8"))

    def test_reference_covers_the_actual_assembler_without_extra_instructions(self):
        names = [row["mnemonic"] for row in self.rows]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(set(names), set(_INSTRUCTIONS))

    def test_parameters_follow_the_assembler_operand_roles(self):
        displayed = {"imm12": "imm", "mem": "offset(rs1)", "dest": "destino"}
        for row in self.rows:
            with self.subTest(instruction=row["mnemonic"]):
                roles = _INSTRUCTIONS[row["mnemonic"]][4]
                self.assertEqual(
                    [p["name"] for p in row["operands"]],
                    [displayed.get(role, role) for role in roles],
                )
                self.assertTrue(row["syntax"].startswith(row["mnemonic"]))
                self.assertTrue(all(p["description"] for p in row["operands"]))
                self.assertTrue(row["description"])

    def test_every_displayed_example_really_assembles(self):
        for row in self.rows:
            with self.subTest(instruction=row["mnemonic"]):
                self.assertEqual(row["example"].split()[0], row["mnemonic"])
                result = assemble(row["example"] + "\nhalt\n")
                self.assertIsNone(result.error)
                self.assertEqual(len(result.image), 8)
                self.assertEqual(result.pc_to_line, {0: 1, 4: 2})
