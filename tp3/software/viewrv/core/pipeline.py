"""Explain observed transitions, never execute a CPU or generate a new snapshot.

Normative sources: stage_id.md (whitelist), control_and_hazards.md (eight
actions), faults_and_termination.md and session_preparation.md. Only instruction
identity, observed controls and recorded state constrain candidate actions. No
ALU, forwarding value, memory result or register write is simulated here.
"""

from dataclasses import dataclass

from software.viewrv.core.records import LATCH_NAMES, warning

STAGES = ("IF", "ID", "EX", "MEM", "WB")
MASK64 = (1 << 64) - 1


@dataclass(frozen=True)
class Instruction:
    """Decoded identity and actual source usage, without computed operand values."""

    mnemonic: str
    family: str
    uses_rs1: bool
    uses_rs2: bool
    rs1: int
    rs2: int
    rd: int


def decode(word):
    """The exact 32 RV32I encodings plus 0x0000000b, not the whole ISA."""
    if type(word) is not int or not 0 <= word < 1 << 32:
        return None
    opcode, f3, f7 = word & 127, (word >> 12) & 7, word >> 25
    mnemonic = family = None
    if word == 11:
        mnemonic, family = "halt", "halt"
    elif opcode == 0x33:
        mnemonic = {
            (0, 0): "add",
            (0, 32): "sub",
            (1, 0): "sll",
            (2, 0): "slt",
            (3, 0): "sltu",
            (4, 0): "xor",
            (5, 0): "srl",
            (5, 32): "sra",
            (6, 0): "or",
            (7, 0): "and",
        }.get((f3, f7))
        family = "r"
    elif opcode == 0x13:
        mnemonic = {0: "addi", 2: "slti", 3: "sltiu", 4: "xori", 6: "ori", 7: "andi"}.get(f3)
        if f3 in {1, 5}:
            mnemonic = {(1, 0): "slli", (5, 0): "srli", (5, 32): "srai"}.get((f3, f7))
        family = "i"
    elif opcode == 3:
        mnemonic, family = {0: "lb", 1: "lh", 2: "lw", 4: "lbu", 5: "lhu"}.get(f3), "load"
    elif opcode == 0x23:
        mnemonic, family = {0: "sb", 1: "sh", 2: "sw"}.get(f3), "store"
    elif opcode == 0x63:
        mnemonic, family = {0: "beq", 1: "bne"}.get(f3), "branch"
    elif opcode == 0x6F:
        mnemonic, family = "jal", "jal"
    elif opcode == 0x67 and f3 == 0:
        mnemonic, family = "jalr", "jalr"
    elif opcode == 0x37:
        mnemonic, family = "lui", "lui"
    if mnemonic is None:
        return None
    return Instruction(
        mnemonic,
        family,
        family in {"r", "i", "load", "store", "branch", "jalr"},
        family in {"r", "store", "branch"},
        (word >> 15) & 31,
        (word >> 20) & 31,
        (word >> 7) & 31,
    )


def image_word(image, pc):
    """Read an aligned word from the confirmed image, or identify a failed fetch."""
    if type(pc) is not int or pc < 0 or pc % 4 or pc + 4 > len(image):
        return None
    return int.from_bytes(bytes(image[pc : pc + 4]), "little")


def controls_match(entry, key):
    """Check recorded functional controls against the normative Decoder table."""
    if not entry["valid"]:
        return True
    instruction = decode(entry["instruction"])
    if instruction is None:
        return key == "if_id"  # Illegal words can only reach the ID fault check.
    name, family = instruction.mnemonic, instruction.family
    writes = family not in {"store", "branch", "halt"}
    if key == "if_id":
        return not entry["fetch_fault_valid"]
    if entry["reg_write"] != writes or writes and entry["rd"] != instruction.rd:
        return False
    if key in {"id_ex", "ex_mem"}:
        memory = {"lb": 1, "lh": 2, "lw": 3, "lbu": 4, "lhu": 5, "sb": 6, "sh": 7, "sw": 8}.get(
            name, 0
        )
        if entry["mem_op"] != memory:
            return False
    if key == "id_ex":
        operation = {
            "add": 32,
            "sub": 34,
            "sll": 0,
            "slt": 42,
            "sltu": 43,
            "xor": 38,
            "srl": 2,
            "sra": 3,
            "or": 37,
            "and": 36,
        }
        alu = (
            operation["sltu" if name == "sltiu" else name.removesuffix("i")]
            if family in {"r", "i"}
            else 34
            if family == "branch"
            else 32
        )
        expected = {
            "alu_op": alu,
            "alu_src": family not in {"r", "branch", "halt"},
            "result_sel": 1 if family == "lui" else 2 if family in {"jal", "jalr"} else 0,
            "flow_op": {"beq": 1, "bne": 2, "jal": 3, "jalr": 4, "halt": 5}.get(name, 0),
        }
        if any(entry[field] != value for field, value in expected.items()):
            return False
        if any(
            getattr(instruction, f"uses_rs{n}")
            and entry[f"rs{n}"] != getattr(instruction, f"rs{n}")
            for n in (1, 2)
        ):
            return False
    return True


def same_entry(before, after):
    """Compare valid boundary identities without interpreting invalid residues."""
    return bool(before["valid"]) == bool(after["valid"]) and (
        not before["valid"]
        or (before["pc"], before["instruction"]) == (after["pc"], after["instruction"])
    )


def prepared_context():
    """Return private logical guarantees, never an initial measured snapshot."""
    # Logical guarantees of confirmed LOAD, not a measured/public snapshot.
    return {
        "pc": 0,
        "cycle_count": "0",
        "global_state": 3,
        "image_valid": True,
        **{
            key: {
                "valid": False,
                "pc": 0,
                "instruction": 0,
                **({"fetch_fault_valid": False, "fetch_fault_cause": 0} if key == "if_id" else {}),
            }
            for key in LATCH_NAMES.values()
        },
    }


def load_use(previous):
    """Recognize a load dependency only on a real, nonzero source register."""
    ex, identifier = previous["id_ex"], previous["if_id"]
    if not ex["valid"] or not identifier["valid"]:
        return False
    producer, consumer = decode(ex["instruction"]), decode(identifier["instruction"])
    return bool(
        producer
        and consumer
        and producer.family == "load"
        and producer.rd
        and (
            consumer.uses_rs1
            and consumer.rs1 == producer.rd
            or consumer.uses_rs2
            and consumer.rs2 == producer.rd
        )
    )


def _fault_at(current, pc, causes):
    return (
        current["global_state"] in {9, 11}
        and current["fault_pc"] == pc
        and current["fault_cause"] in causes
    )


def _matches(action, before, after, image):
    """Match boundary identities/flags from the normative action table."""
    if not same_entry(before["ex_mem"], after["mem_wb"]):
        return False
    suppress_ex = action in {"ex_fault", "halt"}
    if (
        suppress_ex
        and after["ex_mem"]["valid"]
        or not suppress_ex
        and not same_entry(before["id_ex"], after["ex_mem"])
    ):
        return False
    if action in {"normal", "drain_advance"}:
        if not same_entry(before["if_id"], after["id_ex"]):
            return False
    elif after["id_ex"]["valid"]:
        return False
    if action in {"load_use", "drain_load_use"}:
        if before["if_id"] != after["if_id"]:
            return False
    elif action == "normal":
        fetch = after["if_id"]
        word = image_word(image, before["pc"])
        if word is None:
            if (
                fetch["valid"]
                or not fetch["fetch_fault_valid"]
                or fetch["pc"] != before["pc"]
                or fetch["fetch_fault_cause"] != (0 if before["pc"] % 4 else 1)
            ):
                return False
        elif (
            not fetch["valid"]
            or fetch["fetch_fault_valid"]
            or (fetch["pc"], fetch["instruction"]) != (before["pc"], word)
        ):
            return False
    elif after["if_id"]["valid"] or after["if_id"]["fetch_fault_valid"]:
        return False
    expected_pc = (before["pc"] + 4) & 0xFFFFFFFF if action == "normal" else before["pc"]
    if action == "redirect":
        if after["pc"] % 4:
            return False
    elif after["pc"] != expected_pc:
        return False
    drain = (
        7
        if action == "halt"
        else 9
        if action in {"ex_fault", "id_fault"}
        else before["global_state"]
        if action.startswith("drain_")
        else None
    )
    pending = (
        any(after[key]["valid"] for key in LATCH_NAMES.values())
        or after["if_id"]["fetch_fault_valid"]
    )
    state = 5 if drain is None else drain if pending else {7: 10, 9: 11}[drain]
    return after["global_state"] == state


def transition_actions(before, after, image):
    """Possible actions; an empty set means inconsistent observed evolution."""
    if (
        not before["image_valid"]
        or not after["image_valid"]
        or before["global_state"] not in {3, 5, 7, 9}
    ):
        return []
    # A valid captured word must belong to this image. Invalid payload is ignored.
    for snapshot in (before, after):
        if any(
            snapshot[key]["valid"]
            and image_word(image, snapshot[key]["pc"]) != snapshot[key]["instruction"]
            for key in LATCH_NAMES.values()
        ):
            return []
        if any(not controls_match(snapshot[key], key) for key in LATCH_NAMES.values()):
            return []
    ex, identifier = before["id_ex"], before["if_id"]
    instruction = decode(ex["instruction"]) if ex["valid"] else None
    stall = load_use(before)
    if before["global_state"] in {7, 9}:
        options = ["drain_load_use" if stall else "drain_advance"]
    elif instruction and instruction.family == "halt":
        options = ["halt"]
    else:
        options = []
        if instruction:
            causes = {"load": {4, 5}, "store": {6, 7}, "branch": {0}, "jal": {0}, "jalr": {0}}.get(
                instruction.family, set()
            )
            if _fault_at(after, ex["pc"], causes):
                options.append("ex_fault")
            if instruction.family in {"branch", "jal", "jalr"}:
                options.append("redirect")
        id_fault = (
            identifier["fetch_fault_valid"]
            or identifier["valid"]
            and decode(identifier["instruction"]) is None
        )
        if id_fault and _fault_at(
            after, identifier["pc"], {0, 1} if identifier["fetch_fault_valid"] else {2}
        ):
            options.append("id_fault")
        elif not id_fault and (not instruction or instruction.family not in {"jal", "jalr"}):
            options.append("load_use" if stall else "normal")
    return [action for action in options if _matches(action, before, after, image)]


def _ex_blocks(instruction):
    family = instruction.family
    blocks = {"ex.ex_mem_update", "ex.fault_check"}
    if instruction.uses_rs1:
        blocks.update(("ex.forwarding_unit", "ex.forward_mux_a"))
    if instruction.uses_rs2:
        blocks.update(("ex.forwarding_unit", "ex.forward_mux_b"))
    if family in {"r", "i", "load", "store", "branch"}:
        blocks.update(("ex.alu", "ex.alu_source_mux"))
    if family not in {"halt", "branch", "store"}:
        blocks.add("ex.result_mux")
    if family in {"branch", "jal", "jalr", "halt"}:
        blocks.add("ex.flow_control")
    if family in {"branch", "jal"}:
        blocks.update(("ex.target_adder", "ex.target_mux"))
    if family in {"jal", "jalr"}:
        blocks.add("ex.link_adder")
    if family == "jalr":
        blocks.update(("ex.jalr_adder", "ex.clear_bit_zero", "ex.target_mux"))
    return blocks


def action_activity(action, before):
    """Functional blocks, distinct from measured values and post-edge locations."""
    result = []
    for stage, key in zip(STAGES, (None, "if_id", "id_ex", "ex_mem", "mem_wb")):
        entry = before[key] if key else None
        blocks, pc, status = set(), None, "empty"
        if stage == "IF":
            blocks = {"if.pc_update", "if.if_id_update", "control.pipeline_hazard"}
            if action == "normal":
                pc, status = before["pc"], "interpreted"
                blocks.update(
                    (
                        "if.pc",
                        "if.pc_adder",
                        "if.next_pc_mux",
                        "if.instruction_memory",
                        "if.fault_check",
                        "if.input_logic",
                    )
                )
            elif action == "redirect":
                status = "interpreted"
                blocks.add("if.next_pc_mux")
            else:
                status = "interpreted"
        elif entry["valid"] or stage == "ID" and entry["fetch_fault_valid"]:
            pc, status = entry["pc"], "interpreted"
            instruction = decode(entry["instruction"]) if entry["valid"] else None
            if stage == "ID":
                blocks.update(("id.fault_check", "id.id_ex_update", "control.pipeline_hazard"))
                if action in {"load_use", "drain_load_use"}:
                    blocks.add("id.load_use_detector")
                elif action in {"normal", "drain_advance"} and instruction:
                    blocks.add("id.decoder")
                    if instruction.uses_rs1 or instruction.uses_rs2:
                        blocks.add("rf.register_file")
                    if instruction.family not in {"r", "halt"}:
                        blocks.add("id.immediate_generator")
                    wb = before["mem_wb"]
                    if wb["valid"] and wb["reg_write"] and wb["rd"]:
                        for n in (1, 2):
                            if (
                                getattr(instruction, f"uses_rs{n}")
                                and getattr(instruction, f"rs{n}") == wb["rd"]
                            ):
                                blocks.update((f"id.rs{n}_bypass_mux", "id.wb_bypass_control"))
                elif action == "id_fault":
                    blocks.add("id.decoder")
            elif stage == "EX":
                if instruction:
                    blocks = _ex_blocks(instruction)
                    if action in {"halt", "ex_fault"}:
                        blocks.update(("session.execution_control", "control.pipeline_hazard"))
                else:
                    status = "unavailable"
            elif stage == "MEM":
                blocks.update(("mem.decode", "mem.mem_wb_update"))
                if entry["mem_op"] in {1, 2, 3, 4, 5}:
                    blocks.update(("mem.data_memory", "mem.load_select_extend", "mem.wb_value_mux"))
                elif entry["mem_op"] in {6, 7, 8}:
                    blocks.update(("mem.data_memory", "mem.write_control"))
                elif entry["reg_write"]:
                    blocks.add("mem.wb_value_mux")
            elif stage == "WB" and entry["reg_write"] and entry["rd"]:
                blocks.add("rf.register_file")
        result.append({"stage": stage, "status": status, "pc": pc, "blocks": sorted(blocks)})
    return result


def cycle_activity(snapshot, previous, index, image, *, prepared=False, profile=None):
    """Explain only the common activity of transitions compatible with observations."""
    unavailable = [
        {"stage": stage, "status": "unavailable", "pc": None, "blocks": []} for stage in STAGES
    ]
    if profile is not None and (
        profile.get("profile_id") != "tp3-riscv"
        or profile.get("revision") != 1
        or profile.get("memory_profile") not in {"REFERENCE", "ALT_1000"}
    ):
        return unavailable, [
            warning(
                "PROFILE_MISMATCH",
                "cycle_activity",
                "El perfil observado no corresponde a las reglas educativas locales.",
            )
        ]
    if image is None or previous is None and not (prepared and index == 1):
        return unavailable, [
            warning(
                "ACTIVITY_UNDETERMINED",
                "cycle_activity",
                "Falta imagen o contexto anterior verificable para interpretar el ciclo.",
            )
        ]
    before = previous if previous is not None else prepared_context()
    if (int(snapshot["cycle_count"]) - int(before["cycle_count"])) & MASK64 != 1:
        return unavailable, [
            warning(
                "NONCONSECUTIVE_SNAPSHOT",
                "cycle_activity",
                "El contador no corresponde al ciclo siguiente; no se reconstruye actividad a través del salto.",
            )
        ]
    preparation_contradicted = previous is None and (
        any(snapshot["registers"]) or snapshot["used_count"] != 0 or snapshot["memory"]
    )
    actions = [] if preparation_contradicted else transition_actions(before, snapshot, image)
    if not actions:
        return unavailable, [
            warning(
                "TRANSITION_INCONSISTENT",
                "cycle_activity",
                "La captura no coincide con una transición justificable del perfil; se conservan sus bits recibidos.",
            )
        ]
    alternatives = [action_activity(action, before) for action in actions]
    result = []
    for position, stage in enumerate(STAGES):
        entries = [value[position] for value in alternatives]
        equal = len({(item["status"], item["pc"]) for item in entries}) == 1
        blocks = set.intersection(*(set(item["blocks"]) for item in entries)) if equal else set()
        result.append(
            {
                "stage": stage,
                "status": entries[0]["status"] if equal else "unavailable",
                "pc": entries[0]["pc"] if equal else None,
                "blocks": sorted(blocks),
            }
        )
    limitations = []
    if len(actions) > 1:
        limitations.append(
            warning(
                "ACTIVITY_UNDETERMINED",
                "cycle_activity",
                "Varias acciones son compatibles; se muestra solo la participación común justificable: "
                + ", ".join(actions)
                + ".",
            )
        )
    if any(item["status"] == "unavailable" for item in result):
        limitations.append(
            warning(
                "UNSUPPORTED_INSTRUCTION",
                "cycle_activity",
                "Una instrucción de la captura no pertenece a la whitelist del perfil.",
            )
        )
    return result, limitations
