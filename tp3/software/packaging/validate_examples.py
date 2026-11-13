"""Validate static educational programs and guides with the public assembler.

This checks source/guide identity and structural consistency. Expected values
are authored design vectors, not results calculated here or FPGA evidence.
"""

import hashlib
import json
import re
from pathlib import Path

from software.assembler import assemble
from software.viewrv.core.protocol import PROFILES

CONTENT = Path(__file__).resolve().parents[1] / "resources/content"
LATCHES = ("IF/ID", "ID/EX", "EX/MEM", "MEM/WB")
REQUIRED_SCENARIOS = {
    "beq-not-taken",
    "bne-not-taken",
    "parallel-five",
    "forward-ex-mem",
    "forward-mem-wb",
    "forward-two-sources",
    "forward-youngest",
    "load-use",
    "wb-id-bypass",
    "x0-write",
    "x0-load-use",
    "halt-drain",
    "loop-counter",
    "loop-self",
    "negative-compare",
    "negative-shifts",
    "load-misaligned",
    "store-misaligned",
    "x0-load-misaligned",
    "load-out-of-range",
    "store-out-of-range",
    "jump-misaligned",
    "jump-out-of-image",
    "fetch-past-image",
}


def validate(content=CONTENT):
    """Reject incomplete banks, stale guides and inconsistent occurrence positions."""
    profile = json.loads((content / "processor_profile.json").read_text(encoding="utf-8"))
    catalog = json.loads((content / "examples/catalog.json").read_text(encoding="utf-8"))
    instructions = {name.lower() for name in profile["instruction_ids"]}
    seen, focuses, total_cycles = set(), set(), 0
    for entry in catalog:
        identifier = entry.get("example_id", "")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", identifier) or identifier in seen:
            raise ValueError("Identificador de ejemplo inválido o repetido.")
        seen.add(identifier)
        if (
            entry.get("source_path") != f"examples/{identifier}.s"
            or entry.get("guide_path") != f"examples/guides/{identifier}.json"
        ):
            raise ValueError(f"{identifier}: rutas de recursos inválidas.")
        source = (content / entry["source_path"]).read_bytes()
        digest = hashlib.sha256(source).hexdigest()
        if digest != entry.get("source_sha256"):
            raise ValueError(f"{identifier}: huella de fuente desactualizada.")
        result = assemble(source.decode("utf-8"))
        if result.error:
            raise ValueError(f"{identifier}: {result.error}")
        pcs = set(result.pc_to_line)
        profiles = entry.get("memory_profiles", [])
        if (
            not profiles
            or not set(profiles) <= set(PROFILES)
            or any(len(result.image) > PROFILES[name][0] for name in profiles)
        ):
            raise ValueError(f"{identifier}: imagen o perfil de memoria inválido.")
        if (
            not set(entry.get("related_instruction_ids", [])) <= instructions
            or not entry.get("expected_observations")
            or not entry.get("title")
            or not entry.get("objective")
        ):
            raise ValueError(f"{identifier}: metadatos educativos incompletos.")
        focus = entry.get("focus_instruction_id")
        if focus:
            mnemonics = {
                source.decode().splitlines()[line - 1].strip().split()[0].lower()
                for line in result.pc_to_line.values()
            }
            if focus not in instructions or focus not in mnemonics or focus in focuses:
                raise ValueError(f"{identifier}: instrucción individual ausente o repetida.")
            focuses.add(focus)
        state = entry["expected_state"]
        if any(
            not register.isdecimal()
            or not 0 <= int(register) < 32
            or type(value) is not int
            or not 0 <= value <= 0xFFFFFFFF
            or register == "0"
            and value != 0
            for register, value in state.get("registers", {}).items()
        ):
            raise ValueError(f"{identifier}: registro esperado inválido.")
        for address, value in state.get("memory", {}).items():
            if (
                not address.isdecimal()
                or any(not 0 <= int(address) < PROFILES[name][1] for name in profiles)
                or type(value) is not int
                or not 0 <= value < 256
            ):
                raise ValueError(f"{identifier}: byte esperado inválido.")
        if "used_count" in state and state["used_count"] != len(state.get("memory", {})):
            raise ValueError(f"{identifier}: marcas de memoria inconsistentes.")
        guide = json.loads((content / entry["guide_path"]).read_text(encoding="utf-8"))
        if (
            guide.get("schema_version") != 1
            or guide.get("example_id") != identifier
            or guide.get("source_sha256") != digest
            or guide.get("memory_profiles") != profiles
            or not guide.get("assumptions")
        ):
            raise ValueError(f"{identifier}: guía no corresponde al original.")
        cycles = guide.get("cycles", [])
        if not cycles or [row.get("cycle") for row in cycles] != list(range(1, len(cycles) + 1)):
            raise ValueError(f"{identifier}: secuencia de ciclos inválida.")
        identities = {}
        previous = {}
        for row in cycles:
            slots, current = set(), {}
            if not row.get("explanation"):
                raise ValueError(f"{identifier}: ciclo sin explicación.")
            for position in row["positions"]:
                latch, pc, occurrence = position["latch"], position["pc"], position["occurrence"]
                if (
                    latch not in LATCHES
                    or latch in slots
                    or pc not in pcs
                    or occurrence in current
                    or identities.get(occurrence, pc) != pc
                ):
                    raise ValueError(f"{identifier}: posición o aparición inválida.")
                if occurrence not in identities and latch != "IF/ID":
                    raise ValueError(f"{identifier}: aparición sin búsqueda inicial.")
                if occurrence in identities and occurrence not in previous:
                    raise ValueError(f"{identifier}: aparición terminada reutilizada.")
                slots.add(latch)
                identities[occurrence] = pc
                current[occurrence] = LATCHES.index(latch)
                if occurrence in previous and current[occurrence] not in (
                    previous[occurrence],
                    previous[occurrence] + 1,
                ):
                    raise ValueError(f"{identifier}: avance de aparición inválido.")
            previous = current
        terminal = guide.get("terminal")
        if bool(guide.get("prefix_only")) != (terminal is None):
            raise ValueError(f"{identifier}: prefijo y terminación contradictorios.")
        if terminal and (
            terminal.get("cycle") != len(cycles)
            or terminal.get("execution_status") not in ("finished", "fault")
            or cycles[-1]["positions"]
        ):
            raise ValueError(f"{identifier}: terminal sin pipeline vacío.")
        if (
            terminal
            and terminal["execution_status"] == "fault"
            and (
                terminal.get("fault_cause") not in (0, 1, 2, 4, 5, 6, 7)
                or type(terminal.get("fault_pc")) is not int
            )
        ):
            raise ValueError(f"{identifier}: metadata de fault inválida.")
        total_cycles += len(cycles)
    if focuses != instructions or not REQUIRED_SCENARIOS <= seen:
        raise ValueError("El banco no cubre las 33 instrucciones y las interacciones requeridas.")
    return {"programs": len(catalog), "instructions": len(focuses), "guide_cycles": total_cycles}


if __name__ == "__main__":
    print(json.dumps(validate()))
