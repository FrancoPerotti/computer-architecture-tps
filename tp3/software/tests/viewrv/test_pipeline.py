"""PC-I07: independent literal action vectors and observable occurrence continuity."""

import unittest
from copy import deepcopy
from types import SimpleNamespace
from uuid import uuid4

from software.assembler import assemble
from software.tests.viewrv import pipeline_vectors as v
from software.viewrv.contracts import ApplicationError
from software.viewrv.core.follow import advance_follow, start_follow
from software.viewrv.core.observations import interpret_step
from software.viewrv.core.pipeline import decode, transition_actions
from software.viewrv.core.records import interpretation


class PipelineTests(unittest.TestCase):
    """PipelineTests."""

    def explain(self, code, before, after):
        """Explain."""
        original = deepcopy((before, after))
        result = interpret_step(after, before, 3, {0: 1, 4: 2, 8: 3}, code, prepared=True)
        self.assertEqual((before, after), original)
        self.assertTrue(interpretation(result))
        return {row["stage"]: row for row in result["cycle_activity"]}, result

    def test_decode_all_33_encodings_against_public_real_assembler(self):
        """TEST-PC-018: decode all 33 encodings against public real assembler."""
        operations = {
            **{name: "x3,x1,x2" for name in "add sub sll slt sltu xor srl sra or and".split()},
            **{name: "x3,x1,2" for name in "addi slti sltiu xori ori andi slli srli srai".split()},
            **{name: "x3,0(x1)" for name in "lb lh lw lbu lhu sb sh sw jalr".split()},
            "beq": "x1,x2,0",
            "bne": "x1,x2,0",
            "jal": "x3,0",
            "lui": "x3,0x12345",
            "halt": "",
        }
        self.assertEqual(len(operations), 33)
        for name, operands in operations.items():
            with self.subTest(instruction=name):
                compiled = assemble(f"{name} {operands}\n")
                self.assertIsNone(compiled.error)
                self.assertEqual(
                    decode(int.from_bytes(bytes(compiled.image[:4]), "little")).mnemonic, name
                )
        for illegal in [0, 0xFFFFFFFF, 0x02000033, 0x00002063, 0x00001067, 0x0000100B, 0x02001013]:
            self.assertIsNone(decode(illegal), hex(illegal))

    def test_first_step_uses_load_guarantees_without_previous_measurement(self):
        """TEST-PC-018: first step uses load guarantees without previous measurement."""
        after = v.put(v.snapshot(1, 4), "if_id", 0, v.ADDI)
        result = interpret_step(after, None, 1, {0: 1}, v.image(v.ADDI, v.HALT), prepared=True)
        activity = result["cycle_activity"]
        self.assertEqual((activity[0]["stage"], activity[0]["pc"]), ("IF", 0))
        self.assertEqual([item["status"] for item in activity[1:]], ["empty"] * 4)
        self.assertIsNone(result["changes"]["previous_step_index"])
        self.assertEqual(result["changes"]["latch_changes"], [])
        self.assertEqual([item["code"] for item in result["limitations"]], ["NO_PREVIOUS_SNAPSHOT"])
        unknown = interpret_step(after, None, 1, {0: 1}, v.image(v.ADDI, v.HALT))
        self.assertTrue(all(item["status"] == "unavailable" for item in unknown["cycle_activity"]))

    def test_activity_describes_old_stage_and_locations_describe_new_latch(self):
        """TEST-PC-018: activity describes old stage and locations describe new latch."""
        code, before, after = v.normal()
        self.assertEqual(transition_actions(before, after, code), ["normal"])
        activity, result = self.explain(code, before, after)
        self.assertEqual(activity["EX"]["pc"], 0)
        self.assertEqual(after["id_ex"]["pc"], 4)
        self.assertIn("ex.alu", activity["EX"]["blocks"])
        self.assertEqual(result["instruction_locations"][1], {"latch": "ID/EX", "pc": 4, "line": 2})

    def test_load_use_retains_consumer_and_advances_load_without_id_capture(self):
        """TEST-PC-018: load use retains consumer and advances load without id capture."""
        code, before, after = v.stall()
        self.assertEqual(transition_actions(before, after, code), ["load_use"])
        activity, _ = self.explain(code, before, after)
        self.assertIn("id.load_use_detector", activity["ID"]["blocks"])
        self.assertNotIn("rf.register_file", activity["ID"]["blocks"])
        self.assertIn("ex.alu", activity["EX"]["blocks"])

    def test_jal_does_not_claim_alu_and_redirect_discards_younger_entries(self):
        """TEST-PC-018: jal does not claim alu and redirect discards younger entries."""
        code, before, after = v.redirect()
        self.assertEqual(transition_actions(before, after, code), ["redirect"])
        activity, _ = self.explain(code, before, after)
        self.assertIn("ex.link_adder", activity["EX"]["blocks"])
        self.assertNotIn("ex.alu", activity["EX"]["blocks"])
        self.assertNotIn("rf.register_file", activity["ID"]["blocks"])

    def test_lui_uses_result_mux_without_alu_function(self):
        """TEST-PC-018: lui uses result mux without alu function."""
        code = v.image(v.LUI, v.OTHER, v.HALT)
        before = v.put(v.put(v.snapshot(2, 8), "if_id", 4, v.OTHER), "id_ex", 0, v.LUI)
        after = v.put(
            v.put(v.put(v.snapshot(3, 12), "if_id", 8, v.HALT), "id_ex", 4, v.OTHER),
            "ex_mem",
            0,
            v.LUI,
        )
        activity, _ = self.explain(code, before, after)
        self.assertIn("ex.result_mux", activity["EX"]["blocks"])
        self.assertNotIn("ex.alu", activity["EX"]["blocks"])

    def test_halt_drain_preserves_older_wb_even_without_value_change(self):
        """TEST-PC-018: halt drain preserves older wb even without value change."""
        code, before, after = v.halt_drain()
        self.assertEqual(transition_actions(before, after, code), ["halt"])
        activity, _ = self.explain(code, before, after)
        self.assertNotIn("ex.alu", activity["EX"]["blocks"])
        terminal = v.snapshot(5, 12, 10)
        activity, result = self.explain(code, after, terminal)
        self.assertEqual(transition_actions(after, terminal, code), ["drain_advance"])
        self.assertIn("rf.register_file", activity["WB"]["blocks"])
        self.assertEqual(result["changes"]["register_changes"], [])

    def test_id_fault_keeps_older_ex_and_fault_drain_has_no_new_fetch(self):
        """TEST-PC-018: id fault keeps older ex and fault drain has no new fetch."""
        code, before, after = v.id_fault()
        self.assertEqual(transition_actions(before, after, code), ["id_fault"])
        activity, _ = self.explain(code, before, after)
        self.assertIn("ex.alu", activity["EX"]["blocks"])
        self.assertNotIn("if.instruction_memory", activity["IF"]["blocks"])
        next_value = v.put(v.snapshot(4, 8, 9, fault_pc=4, fault_cause=2), "mem_wb", 0, v.ADDI)
        self.assertEqual(transition_actions(after, next_value, code), ["drain_advance"])

    def test_ex_load_fault_does_not_reach_memory(self):
        """TEST-PC-018: ex load fault does not reach memory."""
        code, before, after = v.load_fault()
        self.assertEqual(transition_actions(before, after, code), ["ex_fault"])
        activity, _ = self.explain(code, before, after)
        self.assertIn("ex.fault_check", activity["EX"]["blocks"])
        self.assertEqual(activity["MEM"]["status"], "empty")

    def test_inconsistent_controls_and_gap_preserve_snapshot_and_limit_inference(self):
        """TEST-PC-018: inconsistent controls and gap preserve snapshot and limit inference."""
        code, before, after = v.normal()
        after["ex_mem"]["reg_write"] = False
        activity, result = self.explain(code, before, after)
        self.assertTrue(all(item["status"] == "unavailable" for item in activity.values()))
        self.assertIn("TRANSITION_INCONSISTENT", [item["code"] for item in result["limitations"]])
        after["cycle_count"] = "4"
        activity, result = self.explain(code, before, after)
        self.assertIsNone(result["changes"]["previous_step_index"])
        self.assertIn("NONCONSECUTIVE_SNAPSHOT", [item["code"] for item in result["limitations"]])

    def test_counter_wrap_is_one_cycle_and_does_not_make_a_gap(self):
        """TEST-PC-018: counter wrap is one cycle and does not make a gap."""
        code, before, after = v.normal()
        before["cycle_count"], after["cycle_count"] = str(2**64 - 1), "0"
        _, result = self.explain(code, before, after)
        self.assertFalse(result["limitations"])

    def test_fetch_fault_remains_independent_of_valid_instruction_flag(self):
        """TEST-PC-004: a failed fetch reaches ID as a candidate, not an instruction."""
        code = v.image(v.ADDI)
        before = v.put(v.snapshot(1, 4), "if_id", 0, v.ADDI)
        fetched = v.put(v.snapshot(2, 8), "id_ex", 0, v.ADDI)
        fetched["if_id"].update(pc=4, fetch_fault_valid=True, fetch_fault_cause=1)
        self.assertEqual(transition_actions(before, fetched, code), ["normal"])
        fault = v.put(v.snapshot(3, 8, 9, fault_pc=4, fault_cause=1), "ex_mem", 0, v.ADDI)
        self.assertEqual(transition_actions(fetched, fault, code), ["id_fault"])
        activity, result = self.explain(code, fetched, fault)
        self.assertIn("id.fault_check", activity["ID"]["blocks"])
        self.assertFalse(any(row["latch"] == "IF/ID" for row in result["instruction_locations"]))

    def test_profile_or_preparation_contradiction_limits_activity_without_changing_bits(self):
        """TEST-PC-004: disagreement with context preserves the received measurement."""
        after = v.put(v.snapshot(1, 4), "if_id", 0, v.ADDI)
        code = v.image(v.ADDI, v.HALT)
        result = interpret_step(
            after,
            None,
            1,
            {0: 1},
            code,
            prepared=True,
            profile={"profile_id": "other", "revision": 1, "memory_profile": "REFERENCE"},
        )
        self.assertIn("PROFILE_MISMATCH", [row["code"] for row in result["limitations"]])
        after["registers"][7] = 99
        original = deepcopy(after)
        result = interpret_step(after, None, 1, {0: 1}, code, prepared=True)
        self.assertIn("TRANSITION_INCONSISTENT", [row["code"] for row in result["limitations"]])
        self.assertEqual(after, original)

    def test_unused_immediate_bits_do_not_create_a_false_load_use_dependency(self):
        """TEST-PC-004: only actual instruction sources participate in hazards."""
        consumer = 0x00100113  # addi x2,x0,1: bits 24:20 match x1 but are not rs2.
        code = v.image(v.LOAD, consumer, v.HALT)
        before = v.put(v.put(v.snapshot(2, 8), "if_id", 4, consumer), "id_ex", 0, v.LOAD)
        after = v.put(
            v.put(v.put(v.snapshot(3, 12), "if_id", 8, v.HALT), "id_ex", 4, v.OTHER),
            "ex_mem",
            0,
            v.LOAD,
        )
        after["id_ex"].update(instruction=consumer, immediate=1, rs2=1)
        self.assertEqual(transition_actions(before, after, code), ["normal"])

    def test_load_to_x0_can_reach_wb_without_a_register_write(self):
        """TEST-PC-004: a valid WB slot does not imply an architectural RF write."""
        load_zero = 0x00002003
        before = v.put(v.snapshot(4, 12, 7), "mem_wb", 0, v.LOAD)
        before["mem_wb"].update(instruction=load_zero, rd=0)
        after = v.snapshot(5, 12, 10)
        activity, _ = self.explain(v.image(load_zero, v.HALT), before, after)
        self.assertEqual(activity["WB"]["status"], "interpreted")
        self.assertNotIn("rf.register_file", activity["WB"]["blocks"])

    def test_wb_to_id_bypass_is_distinct_from_changes_and_ex_forwarding(self):
        """TEST-PC-004: both real ID sources can use the same effective WB commit."""
        code = v.image(v.ADDI, v.OTHER, v.OTHER, v.ADD, v.HALT)
        before = v.put(
            v.put(
                v.put(v.put(v.snapshot(4, 16), "if_id", 12, v.ADD), "id_ex", 8, v.OTHER),
                "ex_mem",
                4,
                v.OTHER,
            ),
            "mem_wb",
            0,
            v.ADDI,
        )
        before["mem_wb"]["wb_value"] = 5
        before["ex_mem"]["ex_result"] = 2
        after = v.put(
            v.put(
                v.put(v.put(v.snapshot(5, 20), "if_id", 16, v.HALT), "id_ex", 12, v.ADD),
                "ex_mem",
                8,
                v.OTHER,
            ),
            "mem_wb",
            4,
            v.OTHER,
        )
        after["registers"][1] = 5
        after["id_ex"].update(rs1_value=5, rs2_value=5)
        after["ex_mem"]["ex_result"] = after["mem_wb"]["wb_value"] = 2
        activity, result = self.explain(code, before, after)
        self.assertTrue(
            {"id.rs1_bypass_mux", "id.rs2_bypass_mux", "id.wb_bypass_control"}
            <= set(activity["ID"]["blocks"])
        )
        self.assertEqual(result["changes"]["register_changes"], [{"register": 1, "previous": 0}])
        self.assertIn("ex.forward_mux_a", activity["EX"]["blocks"])
        self.assertNotIn("ex.forward_mux_b", activity["EX"]["blocks"])


def session(code, before, after=None):
    """Session."""
    context = {key: str(uuid4()) for key in ("session_id", "program_id", "source_version")}
    return SimpleNamespace(
        context=lambda: context,
        image={"image": code},
        debug_open=True,
        previous_observation={"step_index": 1, "snapshot": before} if after else None,
        last={"step_index": 2 if after else 1, "snapshot": after or before},
    )


class FollowTests(unittest.TestCase):
    """FollowTests."""

    def follow_pair(self, vector, latch):
        """Follow pair."""
        code, before, after = vector
        value = session(code, before)
        state = start_follow(
            value, {"session_id": value.context()["session_id"], "step_index": 1, "latch": latch}
        )
        self.assertEqual(advance_follow(value, state), state)
        value.previous_observation, value.last = value.last, {"step_index": 2, "snapshot": after}
        return value, state, advance_follow(value, state)

    def test_stall_retains_same_occurrence_then_it_moves_one_latch(self):
        """TEST-PC-018: stall retains same occurrence then it moves one latch."""
        value, state, held = self.follow_pair(v.stall(), "IF/ID")
        self.assertEqual((held["last_latch"], held["status"]), ("IF/ID", "following"))
        value.previous_observation = value.last
        next_value = v.put(
            v.put(v.put(v.snapshot(4, 12), "if_id", 8, v.HALT), "id_ex", 4, v.ADD),
            "mem_wb",
            0,
            v.LOAD,
        )
        value.last = {"step_index": 3, "snapshot": next_value}
        moved = advance_follow(value, held)
        self.assertEqual(
            (moved["last_latch"], moved["origin_latch"], moved["origin_step_index"]),
            ("ID/EX", "IF/ID", 1),
        )
        self.assertEqual(state["step_index"], 1)

    def test_redirect_discards_selected_younger_instruction_without_rebinding(self):
        """TEST-PC-018: redirect discards selected younger instruction without rebinding."""
        value, _, result = self.follow_pair(v.redirect(), "IF/ID")
        self.assertEqual(
            (result["status"], result["reason"], result["last_latch"]),
            ("finished", "discarded", "IF/ID"),
        )
        self.assertEqual(advance_follow(value, result), result)

    def test_wb_retires_even_when_same_pc_is_in_younger_iteration(self):
        """TEST-PC-018: wb retires even when same pc is in younger iteration."""
        code = v.image(v.BRANCH, v.ADDI)
        before = v.put(v.put(v.snapshot(4, 4), "if_id", 0, v.BRANCH), "mem_wb", 0, v.BRANCH)
        after = v.put(v.put(v.snapshot(5, 8), "if_id", 4, v.ADDI), "id_ex", 0, v.BRANCH)
        _, _, result = self.follow_pair((code, before, after), "MEM/WB")
        self.assertEqual(
            (result["status"], result["reason"], result["last_latch"]),
            ("finished", "retired", "MEM/WB"),
        )

    def test_retirement_precedes_terminal_reason(self):
        """TEST-PC-018: retirement precedes terminal reason."""
        code, _, before = v.halt_drain()
        after = v.snapshot(5, 12, 10)
        value, _, result = self.follow_pair((code, before, after), "MEM/WB")
        self.assertEqual(result["reason"], "retired")
        self.assertEqual(result["status"], "finished")
        self.assertEqual(value.last["snapshot"], after)

    def test_gap_and_inconsistency_never_adopt_matching_pc_elsewhere(self):
        """TEST-PC-018: gap and inconsistency never adopt matching pc elsewhere."""
        value, state, _ = self.follow_pair(v.normal(), "ID/EX")
        value.last["step_index"] = 3
        self.assertEqual(advance_follow(value, state)["reason"], "gap")
        value.last["step_index"] = 2
        value.last["snapshot"]["ex_mem"]["reg_write"] = False
        self.assertEqual(advance_follow(value, state)["reason"], "ambiguous")

    def test_follow_accepts_64_bit_wrap_without_skipping_a_latch(self):
        """TEST-PC-018: counter wrap preserves an otherwise justified occurrence."""
        code, before, after = v.normal()
        before["cycle_count"], after["cycle_count"] = str(2**64 - 1), "0"
        _, _, result = self.follow_pair((code, before, after), "ID/EX")
        self.assertEqual((result["status"], result["last_latch"]), ("following", "EX/MEM"))

    def test_logical_close_keeps_last_justified_location_and_never_resumes(self):
        """TEST-PC-018: ending debug retains the last proven occurrence position."""
        value, state, _ = self.follow_pair(v.normal(), "ID/EX")
        value.debug_open = False
        stopped = advance_follow(value, state)
        self.assertEqual(
            (stopped["status"], stopped["reason"], stopped["last_latch"]),
            ("finished", "terminal", "EX/MEM"),
        )
        self.assertEqual(advance_follow(value, stopped), stopped)
        selected = start_follow(
            value, {"session_id": value.context()["session_id"], "step_index": 2, "latch": "EX/MEM"}
        )
        self.assertEqual((selected["status"], selected["reason"]), ("finished", "terminal"))

    def test_invalid_selection_stale_source_and_unverifiable_prior_position_rejected(self):
        """TEST-PC-018: invalid selection stale source and unverifiable prior position rejected."""
        code, before, _ = v.normal()
        value = session(code, before)
        for latch, step in [("MEM/WB", 1), ("IF/ID", 0), ([], 1)]:
            with self.assertRaises(ApplicationError):
                start_follow(
                    value,
                    {
                        "session_id": value.context()["session_id"],
                        "step_index": step,
                        "latch": latch,
                    },
                )
        state = start_follow(
            value, {"session_id": value.context()["session_id"], "step_index": 1, "latch": "IF/ID"}
        )
        for field, replacement in [
            ("source_version", str(uuid4())),
            ("pc", 99),
            ("status", []),
            ("last_latch", []),
            ("reason", "retired"),
        ]:
            with self.subTest(field=field), self.assertRaises(ApplicationError):
                advance_follow(value, {**state, field: replacement})
