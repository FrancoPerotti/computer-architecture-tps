"""Resolve installation resources independently of the caller's directory."""

import hashlib
import json
import sys
from pathlib import Path


def resource_root():
    if getattr(sys, "frozen", False):
        executable = Path(sys.executable).resolve()
        if executable.parent.name == "core":
            return executable.parent.parent
        return executable.parent / "resources"
    return Path(__file__).resolve().parents[2] / "resources"


def load_profile(root=None):
    root = root or resource_root()
    value = json.loads((root / "content/processor_profile.json").read_text(encoding="utf-8"))
    if (
        not isinstance(value, dict)
        or type(value.get("schema_version")) is not int
        or value["schema_version"] != 1
        or value.get("profile_id") != "tp3-riscv"
        or type(value.get("revision")) is not int
        or value["revision"] != 1
        or value.get("memory_profile") not in ("REFERENCE", "ALT_1000")
        or not isinstance(value.get("architecture_source"), str)
        or not isinstance(value.get("instruction_ids"), list)
        or not all(isinstance(item, str) for item in value["instruction_ids"])
        or len(value["instruction_ids"]) != 33
        or len(set(value["instruction_ids"])) != 33
    ):
        raise ValueError("Invalid processor profile descriptor")
    for field, file in (
        ("diagram_sha256", "diagram.drawio.xml"),
        ("bindings_sha256", "diagram_bindings.json"),
    ):
        if hashlib.sha256((root / "content" / file).read_bytes()).hexdigest() != value.get(field):
            raise ValueError(f"Resource hash mismatch: {file}")
    profile = {name: value[name] for name in ("profile_id", "revision", "memory_profile")}
    inventory_file = root.parent / "release.json"
    if inventory_file.exists():
        inventory = json.loads(inventory_file.read_text(encoding="utf-8"))
        if (
            not isinstance(inventory, dict)
            or inventory.get("processor_profile") != profile
            or inventory.get("api_version") != 1
        ):
            raise ValueError("Release inventory and processor profile do not match")
    return profile


def load_examples(root=None, profile=None):
    """Load only compatible examples and verify each original source when pinned."""
    root = root or resource_root()
    profile = profile or load_profile(root)
    content = (root / "content").resolve()
    catalog = content / "examples/catalog.json"
    if not catalog.exists():
        return {}
    result = {}
    for entry in json.loads(catalog.read_text(encoding="utf-8")):
        if profile["memory_profile"] not in entry.get("memory_profiles", ["REFERENCE", "ALT_1000"]):
            continue
        path = (content / entry["source_path"]).resolve()
        if not path.is_relative_to(content):
            raise ValueError("Example source is outside the content directory")
        raw = path.read_bytes()
        if entry.get("source_sha256") and hashlib.sha256(raw).hexdigest() != entry["source_sha256"]:
            raise ValueError("Example source and catalog hash do not match")
        result[entry["example_id"]] = {**entry, "source_text": raw.decode("utf-8")}
    return result
