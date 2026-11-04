"""Wire layout and exact budgets from docs/protocol.md; no I/O or CPU simulation."""

from math import ceil

PROFILES = {"REFERENCE": (1024, 2048), "ALT_1000": (1000, 1000)}
OPCODES = {"LOAD": 1, "RUN": 2, "STEP": 3, "RESET": 4, "CHECK_READY": 5}
FIXED_BYTES = 228
POLL_SECONDS = 0.05


def capacities(profile):
    if profile not in PROFILES:
        raise ValueError("Unknown memory profile")
    return PROFILES[profile]


def load_header(byte_count):
    # Capacity is authoritative in FPGA; keep all 40 bits, including 2**32.
    if type(byte_count) is not int or not 0 <= byte_count < 2**40:
        raise ValueError("LOAD length must fit an unsigned 40-bit field")
    return b"\x01" + byte_count.to_bytes(5, "little")


def load_seconds(byte_count):
    return byte_count * 10 / 19200 + 0.201


def list_milliseconds(count):
    return (count * 50000 + 19199) // 19200 + 200


def load_recovery_milliseconds(byte_count):
    return 100 * (((byte_count + 6) * 10000 + 200 * 19200 + 1920000 - 1) // 1920000)


def debug_recovery_milliseconds(profile):
    return 100 * ceil((200 + 319 + list_milliseconds(capacities(profile)[1])) / 100)


COMMON = (("valid", 1, 1), ("pc", 4, 32), ("instruction", 4, 32))
LATCHES = (
    ("if_id", COMMON + (("fetch_fault_valid", 1, 1), ("fetch_fault_cause", 1, 3))),
    (
        "id_ex",
        COMMON
        + (
            ("rs1", 1, 5),
            ("rs2", 1, 5),
            ("rd", 1, 5),
            ("rs1_value", 4, 32),
            ("rs2_value", 4, 32),
            ("immediate", 4, 32),
            ("alu_op", 1, 6),
            ("alu_src", 1, 1),
            ("result_sel", 1, 2),
            ("flow_op", 1, 3),
            ("mem_op", 1, 4),
            ("reg_write", 1, 1),
        ),
    ),
    (
        "ex_mem",
        COMMON
        + (
            ("rd", 1, 5),
            ("reg_write", 1, 1),
            ("mem_op", 1, 4),
            ("ex_result", 4, 32),
            ("store_data", 4, 32),
        ),
    ),
    ("mem_wb", COMMON + (("rd", 1, 5), ("reg_write", 1, 1), ("wb_value", 4, 32))),
)
BOOLEAN_FIELDS = {"valid", "image_valid", "fetch_fault_valid", "reg_write"}


def decode_fixed(data, profile, operation, result):
    if len(data) != FIXED_BYTES:
        raise ValueError("Incomplete fixed Debug body")
    if (operation == "STEP" and result != 2) or (operation == "RUN" and result not in {10, 11}):
        raise ValueError("Invalid Debug response header")
    offset = 0

    def field(name, size, bits):
        nonlocal offset
        value = int.from_bytes(data[offset : offset + size], "little")
        offset += size
        if value >= 1 << bits:
            raise ValueError(f"Nonzero padding in {name}")
        return bool(value) if name in BOOLEAN_FIELDS else value

    state = field("global_state", 1, 8)
    allowed = {5, 7, 9, 10, 11} if operation == "STEP" else {result}
    if operation not in {"STEP", "RUN"} or state not in allowed:
        raise ValueError("Debug state does not match its response header")
    snapshot = {
        "global_state": state,
        "image_valid": field("image_valid", 1, 1),
        "pc": field("pc", 4, 32),
        "cycle_count": str(field("cycle_count", 8, 64)),
        "fault_cause": field("fault_cause", 1, 3),
        "fault_pc": field("fault_pc", 4, 32),
        "registers": [field("register", 4, 32) for _ in range(32)],
    }
    for name, fields in LATCHES:
        snapshot[name] = {key: field(key, size, bits) for key, size, bits in fields}
    snapshot["used_count"] = field("used_count", 5, 40)
    if snapshot["used_count"] > capacities(profile)[1]:
        raise ValueError("used_count exceeds the configured DMEM capacity")
    return snapshot


def decode_memory(snapshot, data, profile):
    count = snapshot["used_count"]
    if len(data) != 5 * count:
        raise ValueError("Incomplete Debug memory list")
    memory, previous = [], -1
    for offset in range(0, len(data), 5):
        address = int.from_bytes(data[offset : offset + 4], "little")
        if not previous < address < capacities(profile)[1]:
            raise ValueError("Memory addresses must be unique, ordered and inside DMEM")
        previous = address
        memory.append({"address": address, "value": data[offset + 4]})
    return {**snapshot, "memory": memory}
