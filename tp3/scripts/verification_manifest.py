"""Shared manifest loading and catalogue coherence checks."""

import json
from pathlib import Path
import subprocess


TP3_ROOT = Path(__file__).resolve().parents[1]
SCHEMA = TP3_ROOT / "docs/verification/cases.schema.json"
MANIFEST = TP3_ROOT / "docs/verification/cases.json"


def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError(f"invalid JSON number: {value}")


def index_manifest(manifest):
    """Index canonical cases and verify relationships not covered by JSON Schema."""
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
    return groups, cases


def load_manifest(path=MANIFEST):
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
