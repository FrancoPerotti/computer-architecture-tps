"""Extract reviewed Spanish content and validate its semantic/graph references.

Run from tp3: python -m software.packaging.prepare_education --extract.
Extraction is explicit and refuses to overwrite edited content. Normal builds
validate the saved resources without depending on the external viewer checkout.
"""

import argparse
import base64
import hashlib
import json
import re
import urllib.parse
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

from software.viewrv.client.resources import load_profile
from software.viewrv.core.protocol import LATCHES

CONTENT = Path(__file__).resolve().parents[1] / "resources/content"
STAGES = ("IF", "ID", "EX", "MEM", "WB")


def observable_fields():
    """Describe only fields transmitted by the protocol, with their exact widths."""
    result = {"if.pc": [{"path": "pc", "bits": 32}]}
    for (key, fields), block in zip(
        LATCHES, ("latch.if_id", "latch.id_ex", "latch.ex_mem", "latch.mem_wb")
    ):
        result[block] = [{"path": f"{key}.{name}", "bits": bits} for name, _, bits in fields]
    result["rf.register_file"] = [{"path": f"registers.{index}", "bits": 32} for index in range(32)]
    result["mem.data_memory"] = [
        {"path": "used_count", "bits": 40},
        {"path": "memory.*.address", "bits": 32},
        {"path": "memory.*.value", "bits": 8},
    ]
    result["session.execution_control"] = [
        {"path": name, "bits": bits}
        for name, bits in [
            ("global_state", 8),
            ("image_valid", 1),
            ("cycle_count", 64),
            ("fault_cause", 3),
            ("fault_pc", 32),
        ]
    ]
    return result


def viewer_data(content=CONTENT):
    """Read the pinned viewer's reviewed data without running its JavaScript."""
    source = content / "viewer/index.html"
    provenance = json.loads((content / "viewer/provenance.json").read_text(encoding="utf-8"))
    expected = next(
        row["sha256"] for row in provenance["files"] if row["path"] == "viewer/index.html"
    )
    if hashlib.sha256(source.read_bytes()).hexdigest() != expected:
        raise ValueError("El HTML aprobado no coincide con su procedencia registrada.")
    match = re.search(
        r'<script id="diagram-data"[^>]*>(.*?)</script>', source.read_text(encoding="utf-8"), re.S
    )
    if match is None:
        raise ValueError("El visor aprobado no contiene su catálogo de recorridos.")
    packed = json.loads(match[1])
    raw = urllib.parse.unquote(
        zlib.decompress(base64.b64decode(packed["compressed"]), -15).decode()
    )
    return json.loads(raw), provenance["source_revision"], expected


def extract(content=CONTENT):
    """Create separately editable content, preserving the approved original HTML."""
    destination = content / "es/education.json"
    if destination.exists():
        raise ValueError("El contenido español ya existe; no se sobrescribe automáticamente.")
    data, revision, sha = viewer_data(content)
    descriptor = json.loads((content / "diagram_bindings.json").read_text(encoding="utf-8"))
    bindings = descriptor.get("source_blocks", descriptor["blocks"])
    representations = descriptor.get(
        "source_representations", descriptor.get("representations", {})
    )
    semantics = {representations.get(block, [cell])[0]: block for block, cell in bindings.items()}
    pages = {row["id"]: row for row in data["pages"]}
    modules = {
        block: {
            "title": data["blocks"][cell]["name"],
            "description": data["blocks"][cell]["function"],
            "inputs": data["blocks"][cell]["io"]["inputs"],
            "outputs": data["blocks"][cell]["io"]["outputs"],
            "external_signals": data["blocks"][cell]["external"],
            "links": [],
        }
        for block, root in bindings.items()
        for cell in [representations.get(block, [root])[0]]
    }
    modules["session.pipeline_empty"] = {
        "title": "Pipeline vacío",
        "description": "Combina la validez de los cuatro registros interetapa y el candidato de fetch para determinar si queda trabajo pendiente. No representa una quinta etapa ni un registro adicional.",
        "inputs": modules["session.pipeline_empty"]["inputs"],
        "outputs": modules["session.pipeline_empty"]["outputs"],
        "links": modules["session.pipeline_empty"]["links"],
        "external_signals": modules["session.pipeline_empty"]["external_signals"],
    }
    for block, cell in (
        (block, representations.get(block, [root])[0]) for block, root in bindings.items()
    ):
        if cell in data["module_presentation"]:
            modules[block]["presentation"] = data["module_presentation"][cell]

    def module_texts(value):
        """Express native narrative references using stable semantic IDs."""
        return {semantics[cell]: text for cell, text in value.items()}

    def connection_texts(page):
        """Separate editable active-path prose from native chains and masks."""
        return {
            identifier: {"description": row["description"], "paragraphs": row["paragraphs"]}
            for identifier, row in page["connections"].items()
            if row["kind"]
        }

    def inactive_note(page):
        """Keep the shared contextual note without duplicating every inactive edge."""
        notes = {
            tuple(row["paragraphs"][1:])
            for row in page["connections"].values()
            if not row["kind"] and len(row["paragraphs"]) > 1
        }
        if len(notes) > 1:
            raise ValueError("Las notas contextuales requieren una revisión editorial.")
        return list(next(iter(notes), ()))

    instructions = {}
    for identifier, instruction in data["instructions"].items():
        stages = []
        for reference in instruction["stages"]:
            page = pages[reference["id"]]
            stages.append(
                {
                    "stage": STAGES[page["stage"]],
                    "title": page["name"],
                    "description": page["description"],
                    "operation": page["operation"],
                    "paragraphs": page["paragraphs"],
                    "controls": page["controls"],
                    "module_explanations": module_texts(page["module_explanations"]),
                    "connection_explanations": connection_texts(page),
                    "inactive_connection_note": inactive_note(page),
                    "blocks": [
                        block
                        for block, root in bindings.items()
                        if representations.get(block, [root])[0] in page["components"]
                    ],
                }
            )
        instructions[identifier] = {
            **{
                field: instruction[field]
                for field in (
                    "name",
                    "example",
                    "equation",
                    "description",
                    "route_description",
                    "signals",
                )
            },
            "module_explanations": module_texts(instruction["module_explanations"]),
            "stages": stages,
        }
    result = {
        "schema_version": 1,
        "language": "es",
        "provenance": {"viewer_revision": revision, "viewer_sha256": sha},
        "assumptions": pages[data["presentation"]["overview"]["id"]]["paragraphs"],
        "modules": modules,
        "instructions": instructions,
        "stage_presentation": data["presentation"]["stages"],
        "signals": data["signals"],
        "connections": {
            row["id"]: {key: row[key] for key in ("description", "target_function") if key in row}
            for row in data["connections"]
        },
        "overview_connection_explanations": connection_texts(
            pages[data["presentation"]["overview"]["id"]]
        ),
        "overview_inactive_connection_note": inactive_note(
            pages[data["presentation"]["overview"]["id"]]
        ),
    }
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n"
    )


def validate(content=CONTENT):
    """Reject missing instructions, stages, bindings and nonexistent graph roots."""
    load_profile(content.parent)
    profile = json.loads((content / "processor_profile.json").read_text(encoding="utf-8"))
    if profile.get("observable_fields") != observable_fields():
        raise ValueError("El perfil de campos observables no coincide con el protocolo.")
    descriptor = json.loads((content / "diagram_bindings.json").read_text(encoding="utf-8"))
    bindings = descriptor["blocks"]
    education = json.loads((content / "es/education.json").read_text(encoding="utf-8"))
    xml = ET.fromstring((content / "diagram.drawio.xml").read_text(encoding="utf-8"))
    for diagram in xml.findall("diagram"):
        if diagram.find("mxGraphModel") is None and diagram.text:
            diagram.append(
                ET.fromstring(
                    urllib.parse.unquote(
                        zlib.decompress(base64.b64decode(diagram.text), -15).decode()
                    )
                )
            )
    identifiers = {element.get("id") for element in xml.iter() if element.get("id")}
    if len(bindings) != 44 or not set(bindings.values()) <= identifiers:
        raise ValueError("Las correspondencias no cubren los 44 bloques funcionales del diagrama.")
    for block, cells in descriptor.get("representations", {}).items():
        if (
            block not in bindings
            or not isinstance(cells, list)
            or not cells
            or not all(isinstance(cell, str) and cell in identifiers for cell in cells)
        ):
            raise ValueError("La representación alternativa no existe en el diagrama.")
    if (
        education.get("schema_version") != 1
        or education.get("language") != "es"
        or set(education.get("modules", {})) != set(bindings)
    ):
        raise ValueError("El contenido no identifica el mismo catálogo de módulos.")
    for identifier, module in education["modules"].items():
        if any(
            not isinstance(module.get(field), str) or not module[field].strip()
            for field in ("title", "description")
        ):
            raise ValueError(f"{identifier}: falta el nombre o la explicación del módulo.")
        if not all(
            isinstance(module.get(field), list)
            for field in ("inputs", "outputs", "external_signals", "links")
        ):
            raise ValueError(f"{identifier}: faltan las referencias del módulo.")
        for link in module["links"]:
            if (
                not isinstance(link, dict)
                or not isinstance(link.get("title"), str)
                or not link["title"].strip()
                or urllib.parse.urlparse(link.get("url", "")).scheme != "https"
            ):
                raise ValueError(f"{identifier}: enlace educativo inválido.")
    if set(education.get("instructions", {})) != {
        name.lower() for name in profile["instruction_ids"]
    }:
        raise ValueError(
            "El catálogo educativo no cubre exactamente las 33 instrucciones del perfil."
        )
    connections = education.get("connections", {})
    if (
        not connections
        or not education.get("signals")
        or len(education.get("stage_presentation", [])) != 5
    ):
        raise ValueError("Faltan explicaciones generales de conexiones, señales o etapas.")
    if any(not isinstance(value.get("description"), str) for value in connections.values()):
        raise ValueError("Falta la explicación de una conexión.")

    def validate_context(value):
        """Reject narrative references to unknown semantic blocks and connections."""
        if not set(value.get("module_explanations", {})) <= set(bindings) or not set(
            value.get("connection_explanations", {})
        ) <= set(connections):
            raise ValueError("Referencia contextual educativa inexistente.")

    count = 0
    for identifier, instruction in education["instructions"].items():
        validate_context(instruction)
        if any(
            not isinstance(instruction.get(field), str) or not instruction[field].strip()
            for field in ("name", "example", "description", "route_description")
        ):
            raise ValueError(
                f"{identifier}: falta el nombre, ejemplo o explicación de la instrucción."
            )
        stages = instruction.get("stages", [])
        if [row.get("stage") for row in stages] != list(STAGES):
            raise ValueError(f"{identifier}: faltan las cinco etapas ordenadas del recorrido.")
        for row in stages:
            validate_context(row)
            if (
                not set(row["blocks"]) <= set(bindings)
                or not row["description"]
                or not row["paragraphs"]
            ):
                raise ValueError(
                    f"{identifier}/{row['stage']}: referencia o explicación incompleta."
                )
        count += len(stages)
    return {
        "instructions": len(education["instructions"]),
        "stages": count,
        "blocks": len(bindings),
    }


def main():
    """Extract once on request, then validate the complete saved resource set."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extract", action="store_true")
    args = parser.parse_args()
    if args.extract:
        extract()
    print(json.dumps(validate()))


if __name__ == "__main__":
    main()
