"""Validation and recovery of independent JSONL evidence; never resumes a CPU."""

import json
import re
from datetime import datetime

from software.viewrv.contracts import ApplicationError, is_uuid
from software.viewrv.core.protocol import BOOLEAN_FIELDS, LATCHES, capacities

LATCH_NAMES = {"IF/ID": "if_id", "ID/EX": "id_ex", "EX/MEM": "ex_mem", "MEM/WB": "mem_wb"}
STAGES = {"IF", "ID", "EX", "MEM", "WB"}
STATUSES = {"finished", "fault", "interrupted", "unknown"}


def shape(value, fields):
    return isinstance(value, dict) and set(value) == set(fields.split())


def integer(value, low=0, high=2**32 - 1):
    return type(value) is int and low <= value and (high is None or value <= high)


def timestamp(value):
    if not isinstance(value, str) or not re.fullmatch(
        r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z", value
    ):
        return False
    try:
        datetime.fromisoformat(value)
        return True
    except ValueError:
        return False


def notices(value):
    return isinstance(value, list) and all(
        shape(item, "code section message") and all(isinstance(part, str) for part in item.values())
        for item in value
    )


def profile(value):
    return (
        shape(value, "profile_id revision memory_profile")
        and value["profile_id"] == "tp3-riscv"
        and type(value["revision"]) is int
        and value["revision"] == 1
        and value["memory_profile"] in {"REFERENCE", "ALT_1000"}
    )


def snapshot(value, memory_profile):
    if not shape(
        value,
        "global_state image_valid pc cycle_count fault_cause fault_pc registers if_id id_ex ex_mem mem_wb used_count memory",
    ):
        return False
    if (
        not integer(value["global_state"])
        or value["global_state"] not in {5, 7, 9, 10, 11}
        or type(value["image_valid"]) is not bool
        or not integer(value["pc"])
        or not integer(value["fault_cause"], high=7)
        or not integer(value["fault_pc"])
        or not isinstance(value["cycle_count"], str)
        or not re.fullmatch(r"0|[1-9][0-9]{0,19}", value["cycle_count"])
        or int(value["cycle_count"]) >= 2**64
        or not isinstance(value["registers"], list)
        or len(value["registers"]) != 32
        or not all(integer(item) for item in value["registers"])
    ):
        return False
    for name, fields in LATCHES:
        if not isinstance(value[name], dict) or set(value[name]) != {key for key, _, _ in fields}:
            return False
        for key, _, bits in fields:
            item = value[name][key]
            if (
                type(item) is not bool
                if key in BOOLEAN_FIELDS
                else not integer(item, high=(1 << bits) - 1)
            ):
                return False
    memory = value["memory"]
    if (
        not integer(value["used_count"], high=capacities(memory_profile)[1])
        or not isinstance(memory, list)
        or len(memory) != value["used_count"]
    ):
        return False
    previous = -1
    for item in memory:
        if (
            not shape(item, "address value")
            or not integer(item["address"], previous + 1, capacities(memory_profile)[1] - 1)
            or not integer(item["value"], high=255)
        ):
            return False
        previous = item["address"]
    return True


def breakpoint(value):
    return (
        shape(value, "pc line latch")
        and integer(value["pc"])
        and integer(value["line"], 1)
        and isinstance(value["latch"], str)
        and value["latch"] in LATCH_NAMES
    )


def interpretation(value):
    if not shape(value, "instruction_locations changes cycle_activity limitations") or not notices(
        value["limitations"]
    ):
        return False
    locations, changes, activity = (
        value["instruction_locations"],
        value["changes"],
        value["cycle_activity"],
    )
    if not isinstance(locations, list) or any(
        not shape(item, "latch pc line")
        or item["latch"] not in LATCH_NAMES
        or not integer(item["pc"])
        or (item["line"] is not None and not integer(item["line"], 1))
        for item in locations
    ):
        return False
    if not shape(
        changes, "previous_step_index register_changes memory_changes latch_changes global_changes"
    ) or (
        changes["previous_step_index"] is not None
        and not integer(changes["previous_step_index"], 1, high=None)
    ):
        return False
    for group, fields in (
        ("register_changes", "register previous"),
        ("memory_changes", "address previous"),
        ("latch_changes", "latch field previous"),
        ("global_changes", "field previous"),
    ):
        if not isinstance(changes[group], list) or any(
            not shape(item, fields) for item in changes[group]
        ):
            return False
        for item in changes[group]:
            if "register" in item and not integer(item["register"], high=31):
                return False
            if "address" in item and not integer(item["address"]):
                return False
            if "latch" in item and item["latch"] not in LATCH_NAMES:
                return False
            if "field" in item and not isinstance(item["field"], str):
                return False
            if item["previous"] is not None and type(item["previous"]) not in (int, bool, str):
                return False
            previous = item["previous"]
            if group == "register_changes" and not integer(previous):
                return False
            if (
                group == "memory_changes"
                and previous is not None
                and not integer(previous, high=255)
            ):
                return False
            if group == "latch_changes":
                fields = {name: bits for name, _, bits in dict(LATCHES)[LATCH_NAMES[item["latch"]]]}
                if item["field"] not in fields:
                    return False
                if (
                    type(previous) is not bool
                    if item["field"] in BOOLEAN_FIELDS
                    else not integer(previous, high=2 ** fields[item["field"]] - 1)
                ):
                    return False
            if group == "global_changes":
                bits = {
                    "global_state": 8,
                    "image_valid": 1,
                    "pc": 32,
                    "fault_cause": 3,
                    "fault_pc": 32,
                    "used_count": 40,
                }
                if item["field"] == "cycle_count":
                    if (
                        not isinstance(previous, str)
                        or not re.fullmatch(r"0|[1-9][0-9]{0,19}", previous)
                        or int(previous) >= 2**64
                    ):
                        return False
                elif item["field"] not in bits or (
                    type(previous) is not bool
                    if item["field"] == "image_valid"
                    else not integer(previous, high=2 ** bits[item["field"]] - 1)
                ):
                    return False
    return (
        isinstance(activity, list)
        and len(activity) == 5
        and all(
            shape(item, "stage status pc blocks")
            and isinstance(item["stage"], str)
            and item["stage"] in STAGES
            and item["status"] in {"interpreted", "empty", "unavailable"}
            and (item["pc"] is None or integer(item["pc"]))
            and isinstance(item["blocks"], list)
            and all(isinstance(block, str) for block in item["blocks"])
            for item in activity
        )
        and {item["stage"] for item in activity} == STAGES
    )


def outcome(value):
    return (
        shape(value, "ended_at interruption_reason failure")
        and (value["ended_at"] is None or timestamp(value["ended_at"]))
        and value["interruption_reason"]
        in {None, "user_request", "time_limit", "communication_failure", "internal_error"}
        and (
            value["failure"] is None
            or shape(value["failure"], "code message")
            and all(isinstance(part, str) for part in value["failure"].values())
        )
    )


def valid_start(value):
    return (
        shape(
            value, "mode program_id source_version source_text started_at author processor_profile"
        )
        and value["mode"] in {"run", "debug"}
        and is_uuid(value["program_id"])
        and is_uuid(value["source_version"])
        and isinstance(value["source_text"], str)
        and timestamp(value["started_at"])
        and (
            value["author"] is None
            or isinstance(value["author"], str)
            and bool(value["author"].strip())
        )
        and profile(value["processor_profile"])
    )


def valid_observation(value, start):
    if not isinstance(value, dict) or not snapshot(
        value.get("snapshot"), start["processor_profile"]["memory_profile"]
    ):
        return False
    if start["mode"] == "run":
        return shape(value, "snapshot") and value["snapshot"]["global_state"] in {10, 11}
    valid = (
        shape(value, "step_index snapshot breakpoint_hits interpretation")
        and integer(value["step_index"], 1, high=None)
        and isinstance(value["breakpoint_hits"], list)
        and all(breakpoint(item) for item in value["breakpoint_hits"])
        and interpretation(value["interpretation"])
    )
    if not valid:
        return False
    capture, inferred = value["snapshot"], value["interpretation"]
    for hit in value["breakpoint_hits"]:
        latch = capture[LATCH_NAMES[hit["latch"]]]
        if not latch["valid"] or latch["pc"] != hit["pc"]:
            return False
    locations = inferred["instruction_locations"]
    expected = {
        label: capture[key]["pc"] for label, key in LATCH_NAMES.items() if capture[key]["valid"]
    }
    if (
        len(locations) != len(expected)
        or {item["latch"]: item["pc"] for item in locations} != expected
    ):
        return False
    previous = inferred["changes"]["previous_step_index"]
    if (value["step_index"] == 1 and previous is not None) or (
        value["step_index"] > 1 and (previous is None or previous >= value["step_index"])
    ):
        return False
    if previous is None and any(
        inferred["changes"][name]
        for name in ("register_changes", "memory_changes", "latch_changes", "global_changes")
    ):
        return False
    if any(item["status"] == "unavailable" for item in inferred["cycle_activity"]) and not any(
        item["section"] == "cycle_activity" for item in inferred["limitations"]
    ):
        return False
    return True


def valid_end(value):
    return (
        shape(value, "execution_status outcome observation_count limitations")
        and value["execution_status"] in STATUSES
        and outcome(value["outcome"])
        and integer(value["observation_count"], high=None)
        and notices(value["limitations"])
    )


def warning(code, section, message):
    return {"code": code, "section": section, "message": message}


def parse_record(content, session_id, path="", *, retain_observations=True):
    """Recover complete valid units, keeping original step indices and partial warnings."""
    start = end = None
    observations, limitations = [], []
    previous_index = 0
    observation_count = 0

    def duplicate_safe(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Campo JSON repetido")
            result[key] = value
        return result

    lines = content.splitlines() if isinstance(content, (str, bytes)) else content
    for number, line in enumerate(lines, 1):
        try:
            unit = json.loads(
                line.decode("utf-8") if isinstance(line, bytes) else line,
                object_pairs_hook=duplicate_safe,
                parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)),
            )
            if (
                not shape(unit, "schema_version session_id record_type data")
                or type(unit["schema_version"]) is not int
                or unit["schema_version"] != 1
                or unit["session_id"] != session_id
                or not is_uuid(session_id)
            ):
                raise ValueError("Envoltura o identidad inválida")
            kind, data = unit["record_type"], unit["data"]
            if kind == "start" and start is None and valid_start(data):
                start = data
            elif (
                kind == "observation"
                and start is not None
                and end is None
                and valid_observation(data, start)
            ):
                if observations and observations[-1]["snapshot"]["global_state"] in {10, 11}:
                    raise ValueError("Observación posterior a un terminal")
                if start["mode"] == "debug":
                    index = data["step_index"]
                    if index <= previous_index:
                        raise ValueError("Índice de paso repetido o fuera de orden")
                    if index != previous_index + 1:
                        limitations.append(
                            warning(
                                "EVIDENCE_INCOMPLETE",
                                "observations",
                                f"Faltan pasos entre {previous_index} y {index}.",
                            )
                        )
                    previous_index = index
                observations.append(data)
                observation_count += 1
                if not retain_observations:
                    observations[:] = [data]
            elif kind == "end" and start is not None and end is None and valid_end(data):
                if (
                    data["outcome"]["ended_at"] is not None
                    and data["outcome"]["ended_at"] < start["started_at"]
                ):
                    raise ValueError("El cierre es anterior a la apertura")
                terminal = observations[-1]["snapshot"]["global_state"] if observations else None
                if (
                    terminal in {10, 11}
                    and data["execution_status"] != {10: "finished", 11: "fault"}[terminal]
                ):
                    raise ValueError("El cierre contradice la captura terminal")
                if data["execution_status"] in {"finished", "fault"} and terminal not in {10, 11}:
                    limitations.append(
                        warning(
                            "EVIDENCE_INCOMPLETE",
                            "observations",
                            "Falta la captura terminal del desenlace conservado.",
                        )
                    )
                end = data
            else:
                raise ValueError("Unidad inválida o fuera de orden")
        except (ValueError, TypeError, KeyError, UnicodeError) as error:
            limitations.append(warning("RECORD_INVALID", "record", f"Línea {number}: {error}"))
    if start is None:
        raise ApplicationError(
            "RECORD_INVALID",
            "El registro no tiene una apertura válida.",
            500,
            {"session_id": session_id, "path": str(path)},
        )
    if end is None:
        limitations.append(
            warning(
                "EVIDENCE_INCOMPLETE",
                "outcome",
                "No hay cierre conservado; no se deduce actividad física.",
            )
        )
    elif end["observation_count"] != observation_count:
        limitations.append(
            warning(
                "EVIDENCE_INCOMPLETE",
                "observations",
                "La cantidad conservada no coincide con la recibida.",
            )
        )
    failed = end is not None and any(
        item["code"] == "RECORD_WRITE_FAILED" for item in end["limitations"]
    )
    if end is not None:
        limitations.extend(end["limitations"])
    status = "failed" if failed else "incomplete" if limitations else "complete"
    terminal = observations[-1]["snapshot"]["global_state"] if observations else None
    execution = (
        end["execution_status"] if end else {10: "finished", 11: "fault"}.get(terminal, "unknown")
    )
    return {
        "session_id": session_id,
        "start": start,
        "observations": observations,
        "end": end,
        "record_status": status,
        "execution_status": execution,
        "limitations": limitations,
    }
