"""Hand-authored boundary vectors from the normative action table, not a CPU model."""

from copy import deepcopy

from software.tests.viewrv.test_interpretation import capture

ADDI = 0x00500093  # addi x1,x0,5
OTHER = 0x00200113  # addi x2,x0,2
ADD = 0x00108133  # add x2,x1,x1
LOAD = 0x00002083  # lw x1,0(x0)
MISALIGNED_LOAD = 0x00202083  # lw x1,2(x0)
LUI = 0x123451B7  # lui x3,0x12345
JAL = 0x0080006F  # jal x0,8
BRANCH = 0x00000063  # beq x0,x0,0
HALT = 0x0000000B


def image(*words):
    """Image."""
    return list(b"".join(word.to_bytes(4, "little") for word in words))


def snapshot(cycle, pc, state=5, *, fault_pc=0, fault_cause=0):
    """Snapshot."""
    result = capture()
    for key in ("if_id", "id_ex", "ex_mem", "mem_wb"):
        result[key] = {
            field: False if type(value) is bool else 0 for field, value in result[key].items()
        }
    result.update(
        cycle_count=str(cycle),
        pc=pc,
        global_state=state,
        image_valid=True,
        fault_pc=fault_pc,
        fault_cause=fault_cause,
        registers=[0] * 32,
        used_count=0,
        memory=[],
    )
    return result


def put(value, latch, pc, word):
    """Put."""
    entry = value[latch]
    entry.update(valid=True, pc=pc, instruction=word)
    if latch == "if_id":
        return value
    # Literal Decoder controls, independent of the interpreter under test.
    controls = {
        ADDI: dict(
            rd=1,
            rs1=0,
            rs2=5,
            immediate=5,
            alu_op=32,
            alu_src=1,
            result_sel=0,
            flow_op=0,
            mem_op=0,
            reg_write=True,
        ),
        OTHER: dict(
            rd=2,
            rs1=0,
            rs2=2,
            immediate=2,
            alu_op=32,
            alu_src=1,
            result_sel=0,
            flow_op=0,
            mem_op=0,
            reg_write=True,
        ),
        ADD: dict(
            rd=2,
            rs1=1,
            rs2=1,
            immediate=0,
            alu_op=32,
            alu_src=0,
            result_sel=0,
            flow_op=0,
            mem_op=0,
            reg_write=True,
        ),
        LOAD: dict(
            rd=1,
            rs1=0,
            rs2=0,
            immediate=0,
            alu_op=32,
            alu_src=1,
            result_sel=0,
            flow_op=0,
            mem_op=3,
            reg_write=True,
        ),
        MISALIGNED_LOAD: dict(
            rd=1,
            rs1=0,
            rs2=2,
            immediate=2,
            alu_op=32,
            alu_src=1,
            result_sel=0,
            flow_op=0,
            mem_op=3,
            reg_write=True,
        ),
        LUI: dict(
            rd=3,
            rs1=0,
            rs2=0,
            immediate=0x12345000,
            alu_op=32,
            alu_src=1,
            result_sel=1,
            flow_op=0,
            mem_op=0,
            reg_write=True,
        ),
        JAL: dict(
            rd=0,
            rs1=0,
            rs2=0,
            immediate=8,
            alu_op=32,
            alu_src=1,
            result_sel=2,
            flow_op=3,
            mem_op=0,
            reg_write=True,
        ),
        BRANCH: dict(
            rd=0,
            rs1=0,
            rs2=0,
            immediate=0,
            alu_op=34,
            alu_src=0,
            result_sel=0,
            flow_op=1,
            mem_op=0,
            reg_write=False,
        ),
        HALT: dict(
            rd=0,
            rs1=0,
            rs2=0,
            immediate=0,
            alu_op=32,
            alu_src=0,
            result_sel=0,
            flow_op=5,
            mem_op=0,
            reg_write=False,
        ),
    }[word]
    entry.update({key: val for key, val in controls.items() if key in entry})
    return value


def normal():
    """Normal."""
    code = image(ADDI, OTHER, ADD, HALT)
    before = put(put(snapshot(2, 8), "if_id", 4, OTHER), "id_ex", 0, ADDI)
    after = put(put(put(snapshot(3, 12), "if_id", 8, ADD), "id_ex", 4, OTHER), "ex_mem", 0, ADDI)
    return code, before, after


def stall():
    """Stall."""
    code = image(LOAD, ADD, HALT)
    before = put(put(snapshot(2, 8), "if_id", 4, ADD), "id_ex", 0, LOAD)
    after = put(snapshot(3, 8), "ex_mem", 0, LOAD)
    after["if_id"] = deepcopy(before["if_id"])
    return code, before, after


def redirect():
    """Redirect."""
    code = image(JAL, ADDI, HALT)
    before = put(put(snapshot(2, 8), "if_id", 4, ADDI), "id_ex", 0, JAL)
    return code, before, put(snapshot(3, 8), "ex_mem", 0, JAL)


def halt_drain():
    """Halt drain."""
    code = image(ADDI, HALT, OTHER)
    before = put(put(put(snapshot(3, 12), "if_id", 8, OTHER), "id_ex", 4, HALT), "ex_mem", 0, ADDI)
    return code, before, put(snapshot(4, 12, 7), "mem_wb", 0, ADDI)


def id_fault():
    """Id fault."""
    code = image(ADDI, 0, HALT)
    before = put(put(snapshot(2, 8), "if_id", 4, 0), "id_ex", 0, ADDI)
    after = put(snapshot(3, 8, 9, fault_pc=4, fault_cause=2), "ex_mem", 0, ADDI)
    return code, before, after


def load_fault():
    """An EX alignment fault outranks the younger load-use dependency."""
    code = image(MISALIGNED_LOAD, ADD, HALT)
    before = put(put(snapshot(2, 8), "if_id", 4, ADD), "id_ex", 0, MISALIGNED_LOAD)
    return code, before, snapshot(3, 8, 11, fault_pc=0, fault_cause=4)
