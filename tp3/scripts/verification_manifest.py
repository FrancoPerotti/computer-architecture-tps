"""Shared manifest loading and catalogue coherence checks."""

import json
import subprocess
import tempfile
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


def _read_document(path):
    """Lee un documento JSON y conserva su ruta en los diagnósticos."""
    try:
        with path.open(encoding="utf-8") as source:
            return json.load(
                source,
                object_pairs_hook=reject_duplicate_keys,
                parse_constant=reject_constant,
            )
    except (OSError, ValueError) as error:
        raise ValueError(f"cannot read catalogue file {path}: {error}") from error


def _read_catalogue(path):
    """Resuelve archivos de grupos y listas de casos, conservando su orden y fuentes."""
    path = Path(path).resolve()
    directory = path.parent
    sources = {path}

    def reference(entry, owner, stack):
        """Resuelve una referencia local dentro del directorio del catálogo."""
        if set(entry) != {"file"} or not isinstance(entry["file"], str) or not entry["file"]:
            raise ValueError(f"invalid file reference in {owner}: expected only a file path")
        filename = Path(entry["file"])
        target = (owner.parent / filename).resolve()
        if filename.is_absolute() or not target.is_relative_to(directory):
            raise ValueError(f"catalogue reference leaves its directory: {entry['file']}")
        if target.suffix != ".json":
            raise ValueError(f"catalogue reference must name a JSON file: {entry['file']}")
        if target in stack:
            raise ValueError(f"cyclic catalogue reference: {target}")
        sources.add(target)
        return _read_document(target), target, (*stack, target)

    def cases(entries, owner, stack):
        """Expande listas de casos sin interpretar referencias dentro de sus datos."""
        expanded = []
        for entry in entries:
            if isinstance(entry, dict) and "file" in entry:
                document, target, child_stack = reference(entry, owner, stack)
                if not isinstance(document, list):
                    raise ValueError(f"case file must contain an array: {target}")
                expanded.extend(cases(document, target, child_stack))
            else:
                expanded.append(entry)
        return expanded

    def group(entry, owner, stack):
        """Carga un grupo y sus listas externas de casos."""
        if isinstance(entry, dict) and "file" in entry:
            document, target, child_stack = reference(entry, owner, stack)
            if not isinstance(document, dict):
                raise ValueError(f"group file must contain an object: {target}")
            return group(document, target, child_stack)
        if isinstance(entry, dict) and isinstance(entry.get("cases"), list):
            entry["cases"] = cases(entry["cases"], owner, stack)
        return entry

    manifest = _read_document(path)
    if not isinstance(manifest, dict):
        raise ValueError(f"manifest must contain an object: {path}")
    if isinstance(manifest.get("groups"), list):
        manifest["groups"] = [group(entry, path, (path,)) for entry in manifest["groups"]]
    return manifest, sources


def read_manifest(path=MANIFEST):
    """Carga el catálogo completo con biblioteca estándar, sin validar su esquema."""
    return _read_catalogue(path)[0]


def manifest_sources(path=MANIFEST):
    """Enumera el índice y todos los archivos de datos que consume el catálogo."""
    return _read_catalogue(path)[1]


def load_manifest(path=MANIFEST):
    """Resuelve archivos, valida el catálogo completo y comprueba su coherencia."""
    manifest = read_manifest(path)
    with tempfile.TemporaryDirectory(prefix="tp3-manifest-") as temporary:
        resolved = Path(temporary) / "manifest.json"
        schema_path = Path(temporary) / "schema.json"
        schema = _read_document(SCHEMA)
        # La forma resuelta exige grupos/casos completos y conserva errores por campo.
        schema["properties"]["groups"]["items"] = {"$ref": "#/$defs/group"}
        schema["$defs"]["group"]["properties"]["cases"]["items"] = {"$ref": "#/$defs/case"}
        schema_path.write_text(json.dumps(schema), encoding="utf-8")
        resolved.write_text(
            json.dumps(manifest, ensure_ascii=False, allow_nan=False), encoding="utf-8"
        )
        validation = subprocess.run(
            ["check-jsonschema", "--schemafile", str(schema_path), str(resolved)],
            capture_output=True,
            text=True,
            check=False,
        )
    if validation.returncode:
        diagnostic = (validation.stdout + validation.stderr).strip()
        diagnostic = diagnostic.replace(str(resolved), str(Path(path).resolve()))
        diagnostic = diagnostic.replace(str(schema_path), str(SCHEMA))
        raise ValueError(f"manifest validation failed:\n{diagnostic}")
    index_manifest(manifest)
    return manifest
