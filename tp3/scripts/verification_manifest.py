"""Shared manifest loading and catalogue coherence checks."""

import json
import subprocess
from pathlib import Path

# Rutas compartidas resueltas desde el módulo para admitir cualquier directorio de trabajo.
TP3_ROOT = Path(__file__).resolve().parents[1]
SCHEMA = TP3_ROOT / "docs/verification/cases.schema.json"
MANIFEST = TP3_ROOT / "docs/verification/cases.json"


def reject_duplicate_keys(pairs):
    """Reconstruye un objeto JSON y rechaza claves repetidas antes de perder sus valores."""
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def reject_constant(value):
    """Rechaza las constantes JSON que representan NaN o infinito."""
    raise ValueError(f"invalid JSON number: {value}")


def case_executions(group, case_id):
    """Devuelve los bancos aplicables con sus índices y orden originales."""
    return [
        (index, execution)
        for index, execution in enumerate(group["executions"])
        if "case_ids" not in execution or case_id in execution["case_ids"]
    ]


def rejection_diagnostic(execution, case):
    """Valida el diagnóstico esperado o devuelve None si no hay rechazo declarado."""
    rejection = execution.get("expected_rejection")
    if rejection is None:
        return None
    diagnostic = case["expected"].get(rejection["diagnostic_key"])
    if (
        not isinstance(diagnostic, str)
        or not diagnostic.strip()
        or "\n" in diagnostic
        or "\r" in diagnostic
    ):
        raise ValueError(
            f"expected rejection diagnostic must be a nonempty single line in {case['id']}"
        )
    return diagnostic


def execution_parameters(execution, case):
    """Resuelve parámetros desde literales o entradas enteras antes de la elaboración."""
    parameters = {}
    for name, binding in execution.get("parameters", {}).items():
        if isinstance(binding, str):
            parameters[name] = binding
            continue
        value = case["inputs"].get(binding["input"])
        if type(value) is not int:
            raise ValueError(
                f"parameter {name} requires integer input {binding['input']!r} in {case['id']}"
            )
        width = max(64, abs(value).bit_length())
        sign = "-" if value < 0 else ""
        parameters[name] = f"{sign}{width}'d{abs(value)}"
    return parameters


def index_manifest(manifest):
    """Indexa grupos y casos y exige coherencia de IDs, recuentos, referencias y parámetros."""
    groups = {}
    cases = {}
    for group in manifest["groups"]:
        group_id = group["id"]
        if group_id in groups:
            raise ValueError(f"duplicate group ID: {group_id}")
        groups[group_id] = group
        if group["case_count"] != len(group["cases"]):
            raise ValueError(f"case_count does not match cases in {group_id}")
        for case in group["cases"]:
            case_id = case["id"]
            if case_id in cases:
                raise ValueError(f"duplicate case ID: {case_id}")
            if case_id.partition("/")[0] != group_id:
                raise ValueError(f"case {case_id!r} does not belong to group {group_id!r}")
            cases[case_id] = (group, case)
    for group in groups.values():
        for reference in group["reuse_groups"]:
            if reference not in groups:
                raise ValueError(f"unknown reuse group {reference!r} in {group['id']}")
        for reference in group.get("replay_cases", []):
            if reference not in cases:
                raise ValueError(f"unknown replay case {reference!r} in {group['id']}")
        available = {case["id"] for case in group["cases"]} | set(group.get("replay_cases", []))
        for execution in group["executions"]:
            selected = set(execution.get("case_ids", available))
            if not selected <= available:
                raise ValueError(
                    f"execution references cases outside {group['id']}: {sorted(selected - available)}"
                )
            for case_id in selected:
                if cases[case_id][1]["status"] == "pending":
                    continue
                rejection_diagnostic(execution, cases[case_id][1])
                execution_parameters(execution, cases[case_id][1])
    return groups, cases


def load_manifest(path=MANIFEST):
    """Valida el esquema, carga JSON sin claves repetidas y comprueba su coherencia."""
    path = Path(path).resolve()
    validation = subprocess.run(
        ["check-jsonschema", "--schemafile", str(SCHEMA), str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if validation.returncode:
        diagnostic = (validation.stdout + validation.stderr).strip()
        raise ValueError(f"manifest validation failed:\n{diagnostic}")
    with path.open(encoding="utf-8") as source:
        manifest = json.load(
            source,
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=reject_constant,
        )
    index_manifest(manifest)
    return manifest
