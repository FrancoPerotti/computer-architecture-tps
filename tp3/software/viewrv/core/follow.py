"""Continuity of one selected occurrence, using only two complete captures."""

from software.viewrv.contracts import ApplicationError
from software.viewrv.core.pipeline import MASK64, transition_actions
from software.viewrv.core.records import LATCH_NAMES, integer, shape

FIELDS = "session_id program_id source_version origin_step_index origin_latch step_index last_latch pc instruction status reason"


def invalid(message):
    """Reject an invalid observer context without any board operation."""
    raise ApplicationError("INVALID_ARGUMENT", message, 400)


def _matches(snapshot, latch, state):
    entry = snapshot[LATCH_NAMES[latch]]
    return entry["valid"] and (entry["pc"], entry["instruction"]) == (
        state["pc"],
        state["instruction"],
    )


def start_follow(session, selection):
    """Select one valid occurrence in the latest complete observation."""
    if (
        not shape(selection, "session_id step_index latch")
        or selection["session_id"] != session.context()["session_id"]
        or not integer(selection["step_index"], 1, high=None)
        or not isinstance(selection["latch"], str)
        or selection["latch"] not in LATCH_NAMES
    ):
        invalid("Seleccioná una captura actual y un registro interetapa válido.")
    current = session.last
    if current is None or selection["step_index"] != current["step_index"]:
        invalid("La selección debe referirse a la última captura completa.")
    entry = current["snapshot"][LATCH_NAMES[selection["latch"]]]
    if not entry["valid"]:
        invalid("El registro interetapa seleccionado no contiene una instrucción válida.")
    return {
        **session.context(),
        "origin_step_index": current["step_index"],
        "origin_latch": selection["latch"],
        "step_index": current["step_index"],
        "last_latch": selection["latch"],
        "pc": entry["pc"],
        "instruction": entry["instruction"],
        "status": "following" if session.debug_open else "finished",
        "reason": None if session.debug_open else "terminal",
    }


def advance_follow(session, state):
    """Advance a selected occurrence by one verifiable boundary transition."""
    if not shape(state, FIELDS) or any(
        state[key] != value for key, value in session.context().items()
    ):
        invalid("El seguimiento no corresponde a la sesión, programa y revisión solicitados.")
    if (
        not integer(state["origin_step_index"], 1, high=None)
        or not integer(state["step_index"], state["origin_step_index"], high=None)
        or not all(
            isinstance(state[key], str) and state[key] in LATCH_NAMES
            for key in ("last_latch", "origin_latch")
        )
        or not integer(state["pc"])
        or not integer(state["instruction"])
    ):
        invalid("El contexto de seguimiento no tiene posiciones e identidad válidas.")
    if (
        not isinstance(state["status"], str)
        or not (state["reason"] is None or isinstance(state["reason"], str))
        or state["status"] not in {"following", "finished", "unavailable"}
        or state["reason"]
        not in {
            "following": {None},
            "finished": {"retired", "discarded", "terminal"},
            "unavailable": {"ambiguous", "gap"},
        }[state["status"]]
    ):
        invalid("El estado de seguimiento no tiene un desenlace válido.")
    if (
        state["origin_step_index"] == state["step_index"]
        and state["origin_latch"] != state["last_latch"]
    ):
        invalid("La posición inicial no puede cambiar sin una nueva captura.")
    current = session.last
    if current is None or state["step_index"] > current["step_index"]:
        invalid("El seguimiento refiere a una captura que no está disponible.")
    if state["status"] != "following":
        return dict(state)  # A completed occurrence is never rebound to a new iteration.
    if state["step_index"] == current["step_index"]:
        if not _matches(current["snapshot"], state["last_latch"], state):
            invalid("La aparición no coincide con la captura a la que refiere.")
        return dict(state)
    result = {**state, "step_index": current["step_index"]}
    previous = session.previous_observation
    if (
        previous is None
        or previous["step_index"] != state["step_index"]
        or current["step_index"] != state["step_index"] + 1
    ):
        return {**result, "status": "unavailable", "reason": "gap"}
    before, after = previous["snapshot"], current["snapshot"]
    if not _matches(before, state["last_latch"], state):
        invalid("La aparición no coincide con la captura anterior verificable.")
    if (int(after["cycle_count"]) - int(before["cycle_count"])) & MASK64 != 1:
        return {**result, "status": "unavailable", "reason": "gap"}
    actions = transition_actions(before, after, session.image["image"])
    outcomes = set()
    for action in actions:
        latch = state["last_latch"]
        if latch == "MEM/WB":
            outcomes.add((latch, "finished", "retired"))
        elif latch == "EX/MEM":
            outcomes.add(("MEM/WB", "following", None))
        elif latch == "ID/EX":
            if action in {"halt", "ex_fault"}:
                outcomes.add((latch, "finished", "retired" if action == "halt" else "discarded"))
            else:
                outcomes.add(("EX/MEM", "following", None))
        elif action in {"load_use", "drain_load_use"}:
            outcomes.add((latch, "following", None))
        elif action in {"normal", "drain_advance"}:
            outcomes.add(("ID/EX", "following", None))
        else:
            outcomes.add((latch, "finished", "discarded"))
    if len(outcomes) != 1:
        return {**result, "status": "unavailable", "reason": "ambiguous"}
    latch, status, reason = outcomes.pop()
    if status == "following" and not _matches(after, latch, state):
        return {**result, "status": "unavailable", "reason": "ambiguous"}
    if status == "following" and (after["global_state"] in {10, 11} or not session.debug_open):
        return {**result, "last_latch": latch, "status": "finished", "reason": "terminal"}
    return {**result, "last_latch": latch, "status": status, "reason": reason}
