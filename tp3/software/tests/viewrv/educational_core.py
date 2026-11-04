"""Literal UART traces, exclusive to PC-I07 window verification.

This port checks one fixed image and returns hand-authored boundary vectors. It
does not interpret Assembly, calculate CPU results or ship inside the product.
"""

import os
from copy import deepcopy
from pathlib import Path

from software.tests.viewrv import pipeline_vectors as v
from software.tests.viewrv.preparation_fixture import PORT, ControlledProgrammer
from software.tests.viewrv.session_core import LiteralPort
from software.viewrv.adapters.assembler import PythonAssembler
from software.viewrv.adapters.serial import SerialTransport
from software.viewrv.core.__main__ import run
from software.viewrv.core.protocol import LATCHES

SOURCE = "addi x1,x0,5\naddi x2,x0,2\nadd x2,x1,x1\nhalt\n"
IMAGE = bytes(v.image(v.ADDI, v.OTHER, v.ADD, v.HALT))


def captures():
    """Seven explicit post-edge states including forwarding, HALT and drain."""
    one = v.put(v.snapshot(1, 4), "if_id", 0, v.ADDI)
    two = v.put(v.put(v.snapshot(2, 8), "if_id", 4, v.OTHER), "id_ex", 0, v.ADDI)
    three = v.put(
        v.put(v.put(v.snapshot(3, 12), "if_id", 8, v.ADD), "id_ex", 4, v.OTHER), "ex_mem", 0, v.ADDI
    )
    three["ex_mem"]["ex_result"] = 5
    four = v.put(
        v.put(
            v.put(v.put(v.snapshot(4, 16), "if_id", 12, v.HALT), "id_ex", 8, v.ADD),
            "ex_mem",
            4,
            v.OTHER,
        ),
        "mem_wb",
        0,
        v.ADDI,
    )
    four["ex_mem"]["ex_result"], four["mem_wb"]["wb_value"] = 2, 5
    five = v.put(
        v.put(v.put(v.snapshot(5, 20), "id_ex", 12, v.HALT), "ex_mem", 8, v.ADD),
        "mem_wb",
        4,
        v.OTHER,
    )
    five["if_id"].update(pc=16, fetch_fault_valid=True, fetch_fault_cause=1)
    five["ex_mem"]["ex_result"], five["mem_wb"]["wb_value"] = 10, 2
    five["registers"][1] = 5
    six = v.put(v.snapshot(6, 20, 7), "mem_wb", 8, v.ADD)
    six["mem_wb"]["wb_value"] = 10
    six["registers"][1:3] = [5, 2]
    seven = v.snapshot(7, 20, 10)
    seven["registers"][1:3] = [5, 10]
    return [one, two, three, four, five, six, seven]


def packet(snapshot):
    """Serialize a supplied fixture snapshot; no interpretation or CPU advance."""
    result = bytearray(b"\x03\x02")
    fields = [
        ("global_state", 1),
        ("image_valid", 1),
        ("pc", 4),
        ("cycle_count", 8),
        ("fault_cause", 1),
        ("fault_pc", 4),
    ]
    for field, size in fields:
        result.extend(int(snapshot[field]).to_bytes(size, "little"))
    for value in snapshot["registers"]:
        result.extend(value.to_bytes(4, "little"))
    for key, fields in LATCHES:
        for field, size, _ in fields:
            result.extend(int(snapshot[key][field]).to_bytes(size, "little"))
    result.extend(snapshot["used_count"].to_bytes(5, "little"))
    for item in snapshot["memory"]:
        result.extend(item["address"].to_bytes(4, "little"))
        result.append(item["value"])
    return bytes(result)


def addition_captures():
    """Literal boundaries for the original addition example: 8 + 2 into x3."""
    first, second, third, fourth, fifth, sixth, seventh = captures()
    # This named fixture substitutes explicitly authored words and values. It
    # does not read source, evaluate operands or calculate CPU results.
    for snapshot in (first, second, third, fourth, fifth, sixth, seventh):
        for key, _fields in LATCHES:
            entry = snapshot[key]
            if entry["valid"] and entry["pc"] == 0:
                entry["instruction"] = 0x00800093
                if key == "id_ex":
                    entry["immediate"] = 8
                if key == "ex_mem":
                    entry["ex_result"] = 8
                if key == "mem_wb":
                    entry["wb_value"] = 8
            if entry["valid"] and entry["pc"] == 8:
                entry["instruction"] = 0x002081B3
                if key != "if_id":
                    entry["rd"] = 3
                if key == "id_ex":
                    entry["rs2"] = 2
    fifth["registers"][1] = 8
    sixth["registers"][1] = 8
    seventh["registers"][1:4] = [8, 2, 10]
    return [first, second, third, fourth, fifth, sixth, seventh]


def memory_captures():
    """Seven literal zero-store/load boundaries with sparse bytes and invalid residues."""

    def store(snapshot, key, pc=0, byte=False):
        """Supply SW x0,0(x0) or SB x0,7(x0) controls without evaluating instructions."""
        v.put(snapshot, key, pc, v.LOAD)
        entry = snapshot[key]
        entry["instruction"] = 0x000003A3 if byte else 0x00002023
        fields = [
            ("rd", 7 if byte else 0),
            ("reg_write", False),
            ("mem_op", 6 if byte else 8),
            ("immediate", 7 if byte else 0),
            ("ex_result", 7 if byte else 0),
            ("wb_value", 7 if byte else 0),
        ]
        for field, value in fields:
            if field in entry:
                entry[field] = value
        return snapshot

    first = store(v.snapshot(1, 4), "if_id")
    second = store(store(v.snapshot(2, 8), "if_id", 4, True), "id_ex")
    third = store(store(v.put(v.snapshot(3, 12), "if_id", 8, v.LOAD), "id_ex", 4, True), "ex_mem")
    fourth = store(
        store(
            v.put(v.put(v.snapshot(4, 16), "if_id", 12, v.HALT), "id_ex", 8, v.LOAD),
            "ex_mem",
            4,
            True,
        ),
        "mem_wb",
    )
    fifth = store(
        v.put(v.put(v.snapshot(5, 20), "id_ex", 12, v.HALT), "ex_mem", 8, v.LOAD), "mem_wb", 4, True
    )
    fifth["if_id"].update(pc=16, fetch_fault_valid=True, fetch_fault_cause=1)
    sixth = v.put(v.snapshot(6, 20, 7), "mem_wb", 8, v.LOAD)
    sixth["if_id"] = {**fifth["if_id"], "fetch_fault_valid": False}
    sixth["id_ex"] = {**fifth["id_ex"], "valid": False}
    sixth["ex_mem"] = {**fifth["ex_mem"], "valid": False}
    seventh = deepcopy(sixth)
    seventh.update(cycle_count="7", global_state=10)
    seventh["mem_wb"]["valid"] = False
    fourth["used_count"] = 4
    fourth["memory"] = [{"address": address, "value": 0} for address in (0, 1, 2, 3)]
    for snapshot in (fifth, sixth, seventh):
        snapshot["used_count"] = 5
        snapshot["memory"] = [{"address": address, "value": 0} for address in (0, 1, 2, 3, 7)]
    return [first, second, third, fourth, fifth, sixth, seventh]


def loop_captures():
    """Six literal self-branch boundaries; distinct occurrences share PC zero."""
    first = v.put(v.snapshot(1, 4), "if_id", 0, v.BRANCH)
    second = v.put(v.snapshot(2, 8), "id_ex", 0, v.BRANCH)
    second["if_id"].update(pc=4, fetch_fault_valid=True, fetch_fault_cause=1)
    third = v.put(v.snapshot(3, 0), "ex_mem", 0, v.BRANCH)
    fourth = v.put(v.put(v.snapshot(4, 4), "if_id", 0, v.BRANCH), "mem_wb", 0, v.BRANCH)
    fifth = deepcopy(second)
    fifth["cycle_count"] = "5"
    fifth["mem_wb"] = {**fourth["mem_wb"], "valid": False}
    sixth = deepcopy(third)
    sixth["cycle_count"] = "6"
    sixth["mem_wb"] = {**fourth["mem_wb"], "valid": False}
    return [first, second, third, fourth, fifth, sixth]


class EducationalPort(LiteralPort):
    """Return only the fixed trace, and reject a different image or extra STEP."""

    def __init__(self, control):
        """Prepare the literal byte packets and image-checking state."""
        super().__init__(control)
        self.payload = bytearray()
        selected = os.environ.get("VIEWRV_EDUCATIONAL_TRACE", "default")
        cases = {
            "default": (IMAGE, captures),
            "addition": (bytes.fromhex("9300800013012000b38120000b000000"), addition_captures),
            "memory": (bytes.fromhex("23200000a3030000832000000b000000"), memory_captures),
            "loop": (bytes.fromhex("63000000"), loop_captures),
        }
        if selected not in cases:
            raise ValueError("Unknown literal educational trace")
        self.expected_image, supplied = cases[selected]
        self.trace = [packet(value) for value in supplied()]

    def write(self, data):
        """Handle only the controlled image and the literal trace's permitted cycle requests."""
        if self.closed:
            raise OSError("Port closed")
        value = bytes(data)
        if not self.remaining and value == b"\x03":
            with (self.control / "uart.tx").open("a") as output:
                output.write("03\n")
            if self.steps >= len(self.trace):
                raise AssertionError("Extra STEP after the fixed terminal capture")
            self.rx.extend(self.trace[self.steps])
            self.steps += 1
            return len(value)
        if self.remaining:
            self.payload.extend(value)
            result = super().write(value)
            if not self.remaining and bytes(self.payload) != self.expected_image:
                raise AssertionError("The educational fixture received a different image")
            return result
        if len(value) == 6 and value[0] == 1:
            self.payload.clear()
        return super().write(value)


if __name__ == "__main__":
    control = Path(os.environ["VIEWRV_TEST_CONTROL"])
    raise SystemExit(
        run(
            assembler=PythonAssembler(),
            programmer=ControlledProgrammer(control),
            port_enumerator=lambda: [deepcopy(PORT)],
            serial_transport=SerialTransport("REFERENCE", lambda _: EducationalPort(control)),
        )
    )
