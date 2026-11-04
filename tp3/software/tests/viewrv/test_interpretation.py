"""PC-I05 measured correspondence/differences; educational activity follows in PC-I07."""

import unittest
from copy import deepcopy

from software.tests.viewrv.serial_fixture import literal
from software.viewrv.core.observations import interpret_step
from software.viewrv.core.protocol import decode_fixed, decode_memory


def capture():
    value = literal("TEST-UART-007/C007")
    return decode_memory(decode_fixed(value[2:230], "REFERENCE", "STEP", 2), b"", "REFERENCE")


class ObservationTests(unittest.TestCase):
    def test_first_capture_has_no_fabricated_previous_values(self):
        """TEST-PC-004: first STEP maps valid locations without inventing initial measurements."""
        value = capture()
        for key in ("id_ex", "ex_mem", "mem_wb"):
            value[key]["valid"] = False
        value["if_id"]["pc"] = 0
        result = interpret_step(value, None, 1, {0: 7})
        self.assertEqual(result["instruction_locations"], [{"latch": "IF/ID", "pc": 0, "line": 7}])
        self.assertEqual(
            result["changes"],
            {
                "previous_step_index": None,
                "register_changes": [],
                "memory_changes": [],
                "latch_changes": [],
                "global_changes": [],
            },
        )
        self.assertIn("NO_PREVIOUS_SNAPSHOT", [item["code"] for item in result["limitations"]])

    def test_changes_preserve_previous_values_missing_memory_bytes_and_invalid_latch_data(self):
        """TEST-PC-004: RF, memory and latch changes refer to the same previous complete snapshot."""
        before = capture()
        before["registers"][5] = 10
        before["cycle_count"] = "4"
        before["memory"] = [
            {"address": 0, "value": 52},
            {"address": 1, "value": 86},
            {"address": 3, "value": 0},
        ]
        before["used_count"] = 3
        after = deepcopy(before)
        after["registers"][5] = 15
        after["cycle_count"] = "5"
        after["memory"] = [
            {"address": 0, "value": 52},
            {"address": 1, "value": 87},
            {"address": 2, "value": 0},
            {"address": 3, "value": 0},
        ]
        after["used_count"] = 4
        after["if_id"]["valid"] = False
        original = (deepcopy(before), deepcopy(after))
        result = interpret_step(after, before, 2, {})
        changes = result["changes"]
        self.assertEqual(changes["previous_step_index"], 1)
        self.assertEqual(changes["register_changes"], [{"register": 5, "previous": 10}])
        self.assertEqual(
            changes["memory_changes"],
            [{"address": 1, "previous": 86}, {"address": 2, "previous": None}],
        )
        self.assertEqual(
            changes["latch_changes"], [{"latch": "IF/ID", "field": "valid", "previous": True}]
        )
        self.assertEqual(
            changes["global_changes"],
            [{"field": "cycle_count", "previous": "4"}, {"field": "used_count", "previous": 3}],
        )
        self.assertNotIn("IF/ID", [item["latch"] for item in result["instruction_locations"]])
        self.assertEqual((before, after), original)

    def test_equal_pc_in_distinct_valid_latches_remains_distinct_and_unknown_source_is_explicit(
        self,
    ):
        """TEST-PC-004: equal PCs do not merge latch locations or manufacture an instruction identity."""
        value = capture()
        value["if_id"]["pc"] = value["id_ex"]["pc"] = 0
        result = interpret_step(value, None, 1, {0: 1})
        locations = result["instruction_locations"]
        self.assertEqual(
            [item for item in locations if item["pc"] == 0],
            [{"latch": "IF/ID", "pc": 0, "line": 1}, {"latch": "ID/EX", "pc": 0, "line": 1}],
        )
        self.assertEqual(len(locations), 4)
        self.assertIsNone(locations[-1]["line"])
        self.assertIn(
            "SOURCE_MAPPING_UNAVAILABLE", [item["code"] for item in result["limitations"]]
        )

    def test_counter_wrap_is_preserved_and_unimplemented_educational_activity_is_not_claimed_measured(
        self,
    ):
        """TEST-PC-004: 64-bit wrap remains exact; PC-I07 activity is explicitly unavailable."""
        before = capture()
        after = deepcopy(before)
        before["cycle_count"] = str(2**64 - 1)
        after["cycle_count"] = "0"
        result = interpret_step(after, before, 2, {})
        self.assertEqual(
            result["changes"]["global_changes"],
            [{"field": "cycle_count", "previous": str(2**64 - 1)}],
        )
        self.assertEqual(
            [item["stage"] for item in result["cycle_activity"]], ["IF", "ID", "EX", "MEM", "WB"]
        )
        self.assertTrue(
            all(
                item["status"] == "unavailable" and item["blocks"] == [] and item["pc"] is None
                for item in result["cycle_activity"]
            )
        )
        self.assertIn(
            "ACTIVITY_UNDETERMINED", [item["code"] for item in result["limitations"]]
        )
