#!/usr/bin/env python3
"""Prepare external SystemVerilog data from one manifest case."""

import argparse
import json
import math
import os
from pathlib import Path
import sys
import tempfile


from verification_manifest import MANIFEST, SCHEMA, load_manifest


def load_case(manifest_path, case_id):
    """Delegate schema validation, then resolve exactly one canonical case."""
    manifest = load_manifest(manifest_path)
    matches = [
        (group, case)
        for group in manifest["groups"]
        for case in group["cases"]
        if case["id"] == case_id
    ]
    if len(matches) != 1:
        raise ValueError(f"expected one case for {case_id!r}; found {len(matches)}")
    group, case = matches[0]
    if case_id.partition("/")[0] != group["id"]:
        raise ValueError(f"case {case_id!r} does not belong to group {group['id']!r}")
    return case_payload(manifest, case)


def case_payload(manifest, case):
    """Use the same payload for the standalone preparer and the runner."""
    return {
        "id": case["id"],
        "inputs": case["inputs"],
        "expected": case["expected"],
        "latch_fixture": manifest["latch_fixture"],
    }


def pointer_token(key):
    return key.replace("~", "~0").replace("/", "~1")


def records(value, path=""):
    """Yield typed JSON Pointer records without interpreting case semantics."""
    if isinstance(value, dict):
        yield path, "object", str(len(value))
        for key in sorted(value):
            yield from records(value[key], f"{path}/{pointer_token(key)}")
    elif isinstance(value, list):
        yield path, "array", str(len(value))
        for index, item in enumerate(value):
            yield from records(item, f"{path}/{index}")
    elif value is None:
        yield path, "null", ""
    elif isinstance(value, bool):
        yield path, "boolean", "true" if value else "false"
    elif isinstance(value, int):
        yield path, "integer", str(value)
    elif isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError(f"non-finite real at {path}")
        yield path, "real", json.dumps(value, allow_nan=False)
    elif isinstance(value, str):
        yield path, "string", value
    else:
        raise ValueError(f"unsupported value at {path}: {type(value).__name__}")


def encode_token(value):
    if "\0" in value:
        raise ValueError("NUL characters cannot be represented in SystemVerilog strings")
    return value.encode("utf-8").hex() or "-"


def serialize(data):
    entries = list(records(data))
    lines = [f"TP3_CASE_DATA {len(entries)}\n"]
    lines.extend(
        f"{encode_token(path)} {kind} {encode_token(value)}\n"
        for path, kind, value in entries
    )
    return "".join(lines)


def write_data(output, data):
    """Replace the output only after every value has been serialized."""
    content = serialize(data)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="ascii", dir=output.parent, delete=False
        ) as temporary:
            temporary_path = Path(temporary.name)
            temporary.write(content)
        os.replace(temporary_path, output)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--case", required=True, help="Full canonical case ID")
    parser.add_argument("--output", type=Path, required=True, help="Generated data file")
    args = parser.parse_args(argv)
    try:
        if args.output.resolve() in {args.manifest.resolve(), SCHEMA.resolve()}:
            raise ValueError("output must not replace the manifest or its schema")
        write_data(args.output, load_case(args.manifest, args.case))
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
