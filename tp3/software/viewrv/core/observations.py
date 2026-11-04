"""Source correspondence and measured changes, separate from educational activity."""

from software.viewrv.core.pipeline import MASK64, cycle_activity
from software.viewrv.core.records import LATCH_NAMES, warning


def interpret_step(snapshot, previous, index, mapping, image=None, *, prepared=False, profile=None):
    """Keep measured correspondence/changes separate from justified cycle activity."""
    locations = [
        {"latch": label, "pc": snapshot[key]["pc"], "line": mapping.get(snapshot[key]["pc"])}
        for label, key in LATCH_NAMES.items()
        if snapshot[key]["valid"]
    ]
    changes = {
        "previous_step_index": index - 1 if previous is not None else None,
        "register_changes": [],
        "memory_changes": [],
        "latch_changes": [],
        "global_changes": [],
    }
    limitations = []
    if previous is None:
        limitations.append(
            warning(
                "NO_PREVIOUS_SNAPSHOT",
                "changes",
                "No hay una captura anterior para comparar valores.",
            )
        )
    elif (int(snapshot["cycle_count"]) - int(previous["cycle_count"])) & MASK64 != 1:
        limitations.append(
            warning(
                "NONCONSECUTIVE_SNAPSHOT",
                "changes",
                "No hay dos ciclos consecutivos para comparar valores.",
            )
        )
        changes["previous_step_index"] = None
    else:
        changes["register_changes"] = [
            {"register": register, "previous": value}
            for register, value in enumerate(previous["registers"])
            if value != snapshot["registers"][register]
        ]
        old_memory = {item["address"]: item["value"] for item in previous["memory"]}
        changes["memory_changes"] = [
            {"address": item["address"], "previous": old_memory.get(item["address"])}
            for item in snapshot["memory"]
            if item["address"] not in old_memory or old_memory[item["address"]] != item["value"]
        ]
        changes["latch_changes"] = [
            {"latch": label, "field": field, "previous": value}
            for label, key in LATCH_NAMES.items()
            for field, value in previous[key].items()
            if value != snapshot[key][field]
        ]
        changes["global_changes"] = [
            {"field": field, "previous": value}
            for field, value in previous.items()
            if type(value) in (int, str, bool) and value != snapshot[field]
        ]
    activity, activity_limits = cycle_activity(
        snapshot, previous, index, image, prepared=prepared, profile=profile
    )
    limitations.extend(activity_limits)
    if any(item["line"] is None for item in locations):
        limitations.append(
            warning(
                "SOURCE_MAPPING_UNAVAILABLE",
                "instruction_locations",
                "Hay PCs válidos fuera del mapa de la versión ejecutada.",
            )
        )
    return {
        "instruction_locations": locations,
        "changes": changes,
        "cycle_activity": activity,
        "limitations": limitations,
    }
