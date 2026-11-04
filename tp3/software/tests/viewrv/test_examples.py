"""Static educational bank: normative results, assembly and authored cycle guides."""

import json
import shutil
import tempfile
import unittest
from pathlib import Path

from software.assembler import assemble
from software.packaging.validate_examples import CONTENT, validate
from software.tests.viewrv.educational_core import (
    addition_captures,
    loop_captures,
    memory_captures,
    packet,
)
from software.viewrv.client.resources import load_examples
from software.viewrv.core.observations import interpret_step
from software.viewrv.core.pipeline import decode
from software.viewrv.core.protocol import PROFILES, decode_fixed, decode_memory


class ExampleBankTests(unittest.TestCase):
    """Verify authored design vectors without simulating a CPU or asserting hardware acceptance."""

    @classmethod
    def setUpClass(cls):
        """Read the content under review once."""
        cls.catalog = json.loads((CONTENT / "examples/catalog.json").read_text(encoding="utf-8"))
        cls.entries = {entry["example_id"]: entry for entry in cls.catalog}

    def guide(self, identifier):
        """Read one authored guide."""
        return json.loads(
            (CONTENT / self.entries[identifier]["guide_path"]).read_text(encoding="utf-8")
        )

    def test_complete_bank_assembles_with_real_public_assembler(self):
        """Each of the 33 instruction programs and every required interaction is executable."""
        self.assertEqual(validate(), {"programs": 59, "instructions": 33, "guide_cycles": 409})
        for entry in self.catalog:
            with self.subTest(example=entry["example_id"]):
                source = (CONTENT / entry["source_path"]).read_text(encoding="utf-8")
                compiled = assemble(source)
                self.assertIsNone(compiled.error)
                decoded = [
                    decode(int.from_bytes(compiled.image[pc : pc + 4], "little"))
                    for pc in compiled.pc_to_line
                ]
                self.assertTrue(all(decoded))
                focus = entry["focus_instruction_id"]
                if focus:
                    self.assertIn(focus, [instruction.mnemonic for instruction in decoded])
                # Expectations name only fields of the real received state.
                self.assertLessEqual(
                    set(entry["expected_state"]), {"registers", "memory", "used_count"}
                )

    def test_individual_results_match_normative_instruction_vectors(self):
        """Literal oracle from gui_y_visor.md; no execution-derived expected values."""
        r = {
            "add": 10,
            "sub": 6,
            "sll": 32,
            "slt": 0,
            "sltu": 0,
            "xor": 10,
            "srl": 2,
            "sra": 2,
            "or": 10,
            "and": 0,
        }
        i = {
            "addi": 10,
            "slti": 0,
            "sltiu": 0,
            "xori": 10,
            "ori": 10,
            "andi": 0,
            "slli": 32,
            "srli": 2,
            "srai": 2,
        }
        loads = {"lb": 0xFFFFFFFF, "lbu": 0xFF, "lh": 0xFFFF80FF, "lhu": 0x80FF, "lw": 0x80FF}
        for name, expected in {**r, **i, **loads, "lui": 0x12345000}.items():
            with self.subTest(instruction=name):
                entry = self.entries["instruction-" + name]
                self.assertEqual(entry["expected_state"]["registers"]["3"], expected)
                source = (CONTENT / entry["source_path"]).read_text(encoding="utf-8")
                if name in r:
                    self.assertIn("    addi x1, x0, 8\n    addi x2, x0, 2\n", source)
                    self.assertIn(f"    {name} x3, x1, x2\n", source)
                elif name in i:
                    self.assertIn(f"    addi x1, x0, 8\n    {name} x3, x1, 2\n", source)
                elif name in loads:
                    self.assertIn("    lui x1, 0x8\n    addi x1, x1, 255\n    sw x1, 0(x0)\n", source)
                    self.assertEqual(
                        entry["expected_state"]["memory"], {"0": 255, "1": 128, "2": 0, "3": 0}
                    )
        for name, values in [("sb", [120]), ("sh", [120, 86]), ("sw", [120, 86, 52, 18])]:
            self.assertEqual(
                self.entries["instruction-" + name]["expected_state"]["memory"],
                {str(index): value for index, value in enumerate(values)},
            )
        for name, link in [("jal", 4), ("jalr", 8)]:
            self.assertEqual(
                self.entries["instruction-" + name]["expected_state"]["registers"]["3"], link
            )
            self.assertEqual(
                self.entries["instruction-" + name]["expected_state"]["registers"]["4"], 0
            )

    def test_branch_stall_bypass_and_loop_occurrences_have_explicit_frontiers(self):
        """The clock-by-clock guide is not inferred merely from sequential PCs."""
        stall = self.guide("load-use")["cycles"]
        self.assertEqual(
            next(row for row in stall[3]["positions"] if row["latch"] == "IF/ID"),
            next(row for row in stall[4]["positions"] if row["latch"] == "IF/ID"),
        )
        self.assertFalse(any(row["latch"] == "ID/EX" for row in stall[4]["positions"]))
        self.assertEqual(
            next(row for row in stall[5]["positions"] if row["latch"] == "ID/EX")["pc"], 12
        )
        self.assertEqual(stall[-1]["cycle"], 9)
        taken = self.guide("instruction-beq")["cycles"]
        self.assertFalse(any(row["latch"] in ("IF/ID", "ID/EX") for row in taken[4]["positions"]))
        self.assertEqual(
            next(row for row in taken[5]["positions"] if row["latch"] == "IF/ID")["pc"], 16
        )
        bypass = self.guide("wb-id-bypass")["cycles"][4]
        self.assertEqual(
            next(row for row in bypass["positions"] if row["latch"] == "ID/EX")["pc"], 12
        )
        self.assertIn("WB", bypass["explanation"])
        loop = self.guide("loop-self")
        self.assertTrue(loop["prefix_only"])
        self.assertIsNone(loop["terminal"])
        parallel = loop["cycles"][3]["positions"]
        self.assertEqual({row["pc"] for row in parallel}, {0})
        self.assertEqual(len({row["occurrence"] for row in parallel}), 2)

    def test_fault_vectors_use_actual_profile_limits_and_preserve_older_effects(self):
        """Addresses and causes follow profile and faults_and_termination.md."""
        for identifier, cause, pc in [
            ("load-misaligned", 4, 0),
            ("store-misaligned", 6, 4),
            ("x0-load-misaligned", 4, 0),
            ("load-out-of-range", 5, 8),
            ("store-out-of-range", 7, 8),
            ("jump-misaligned", 0, 4),
            ("jump-out-of-image", 1, 16),
            ("fetch-past-image", 1, 4),
        ]:
            with self.subTest(example=identifier):
                terminal = self.guide(identifier)["terminal"]
                self.assertEqual(
                    (terminal["execution_status"], terminal["fault_cause"], terminal["fault_pc"]),
                    ("fault", cause, pc),
                )
                self.assertEqual(self.entries[identifier]["expected_state"]["used_count"], 0)
                if identifier not in ("jump-out-of-image", "fetch-past-image"):
                    before = self.guide(identifier)["cycles"][pc // 4 + 1]["positions"]
                    self.assertLessEqual({"IF/ID", "ID/EX"}, set(row["latch"] for row in before))
        for name in ["load-out-of-range", "store-out-of-range"]:
            entry = self.entries[name]
            self.assertEqual(entry["memory_profiles"], ["REFERENCE"])
            self.assertEqual(entry["expected_state"]["registers"]["1"], PROFILES["REFERENCE"][1])
        self.assertEqual(self.entries["jump-out-of-image"]["expected_state"]["registers"]["3"], 4)
        self.assertEqual(self.entries["fetch-past-image"]["expected_state"]["registers"]["3"], 7)

    def test_stale_source_and_guide_reference_are_rejected(self):
        """Resource edits must preserve guide/source identity and named instruction coverage."""
        with tempfile.TemporaryDirectory() as directory:
            content = Path(directory)
            shutil.copytree(CONTENT / "examples", content / "examples")
            shutil.copy2(CONTENT / "processor_profile.json", content / "processor_profile.json")
            path = content / "examples/instruction-add.s"
            original = path.read_text(encoding="utf-8")
            path.write_text(original + "# edit\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "huella de fuente"):
                validate(content)
            path.write_text(original, encoding="utf-8")
            path = content / "examples/guides/loop-self.json"
            guide = json.loads(path.read_text(encoding="utf-8"))
            guide["cycles"][3]["positions"][1]["occurrence"] = guide["cycles"][3]["positions"][0][
                "occurrence"
            ]
            path.write_text(json.dumps(guide), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "aparición inválida"):
                validate(content)

    def test_profile_filters_reference_boundaries_and_checks_source_hash(self):
        """Core offers only programs whose expected memory bounds fit its actual profile."""
        reference = load_examples(CONTENT.parent, {"memory_profile": "REFERENCE"})
        alternate = load_examples(CONTENT.parent, {"memory_profile": "ALT_1000"})
        self.assertEqual(len(reference), 59)
        self.assertEqual(len(alternate), 57)
        self.assertEqual(
            set(reference) - set(alternate), {"load-out-of-range", "store-out-of-range"}
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(CONTENT / "examples", root / "content/examples")
            path = root / "content/examples/addition.s"
            path.write_text(path.read_text(encoding="utf-8") + "# stale\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "catalog hash"):
                load_examples(root, {"memory_profile": "REFERENCE"})

    def test_addition_guide_and_literal_uart_fixture_are_consistent(self):
        """Check fixture consistency; authored UART values do not prove a hardware execution."""
        trace = addition_captures()
        keys = {"IF/ID": "if_id", "ID/EX": "id_ex", "EX/MEM": "ex_mem", "MEM/WB": "mem_wb"}
        source = (CONTENT / self.entries["addition"]["source_path"]).read_text(encoding="utf-8")
        image = assemble(source).image
        for row, snapshot in zip(self.guide("addition")["cycles"], trace):
            self.assertEqual(
                {(entry["latch"], entry["pc"]) for entry in row["positions"]},
                {
                    (name, snapshot[key]["pc"])
                    for name, key in keys.items()
                    if snapshot[key]["valid"]
                },
            )
            for key in keys.values():
                if snapshot[key]["valid"]:
                    pc = snapshot[key]["pc"]
                    self.assertEqual(
                        snapshot[key]["instruction"], int.from_bytes(image[pc : pc + 4], "little")
                    )
            self.assertEqual(len(packet(snapshot)), 230)
        self.assertEqual(trace[-1]["registers"][1:4], [8, 2, 10])

    def test_memory_window_fixture_preserves_sparse_zero_bytes_and_invalid_residues(self):
        """Check the UART window fixture against assembly, wire sizes and sparse semantics."""
        source = "sw x0,0(x0)\nsb x0,7(x0)\nlw x1,0(x0)\nhalt\n"
        image = assemble(source).image
        trace = memory_captures()
        previous = None
        for index, snapshot in enumerate(trace, 1):
            raw = packet(snapshot)
            self.assertEqual(len(raw), 230 + 5 * snapshot["used_count"])
            decoded = decode_memory(
                decode_fixed(raw[2:230], "REFERENCE", "STEP", 2), raw[230:], "REFERENCE"
            )
            self.assertEqual(decoded, snapshot)
            for key in ("if_id", "id_ex", "ex_mem", "mem_wb"):
                if snapshot[key]["valid"]:
                    pc = snapshot[key]["pc"]
                    self.assertEqual(
                        snapshot[key]["instruction"], int.from_bytes(image[pc : pc + 4], "little")
                    )
            result = interpret_step(
                snapshot, previous, index, {0: 1, 4: 2, 8: 3, 12: 4}, image, prepared=True
            )
            self.assertNotIn(
                "TRANSITION_INCONSISTENT", [item["code"] for item in result["limitations"]]
            )
            if index == 5:
                self.assertEqual(
                    result["changes"]["memory_changes"], [{"address": 7, "previous": None}]
                )
            previous = snapshot
        self.assertEqual(trace[3]["ex_mem"]["ex_result"], 7)
        self.assertEqual(trace[4]["mem_wb"]["wb_value"], 7)
        self.assertEqual([item["address"] for item in trace[-1]["memory"]], [0, 1, 2, 3, 7])
        self.assertFalse(trace[-1]["mem_wb"]["valid"])
        self.assertEqual(trace[-1]["mem_wb"]["instruction"], 0x00002083)
        self.assertTrue(trace[-1]["mem_wb"]["reg_write"])

    def test_self_loop_window_trace_matches_the_independent_guide_prefix(self):
        """Two simultaneous PC-zero locations belong to different authored occurrences."""
        image = assemble((CONTENT / "examples/loop-self.s").read_text(encoding="utf-8")).image
        trace = loop_captures()
        names = {"IF/ID": "if_id", "ID/EX": "id_ex", "EX/MEM": "ex_mem", "MEM/WB": "mem_wb"}
        previous = None
        for index, (snapshot, row) in enumerate(zip(trace, self.guide("loop-self")["cycles"]), 1):
            self.assertEqual(
                {
                    (name, snapshot[key]["pc"])
                    for name, key in names.items()
                    if snapshot[key]["valid"]
                },
                {(position["latch"], position["pc"]) for position in row["positions"]},
            )
            raw = packet(snapshot)
            self.assertEqual(
                decode_memory(
                    decode_fixed(raw[2:230], "REFERENCE", "STEP", 2), raw[230:], "REFERENCE"
                ),
                snapshot,
            )
            result = interpret_step(snapshot, previous, index, {0: 2}, image, prepared=True)
            self.assertNotIn(
                "TRANSITION_INCONSISTENT", [item["code"] for item in result["limitations"]]
            )
            previous = snapshot
        self.assertTrue(trace[3]["if_id"]["valid"] and trace[3]["mem_wb"]["valid"])
        self.assertFalse(trace[4]["mem_wb"]["valid"])
        self.assertTrue(trace[4]["id_ex"]["valid"])
