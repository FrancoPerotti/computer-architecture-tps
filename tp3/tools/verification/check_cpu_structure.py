#!/usr/bin/env python3
"""Contrasta el XML elaborado del CPU con inventario, payloads y recursos aprobados.

Es una comprobación estructural; no sustituye simulaciones, revisión de lógica local,
netlist FPGA, timing ni aceptación física.
"""

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from verification_manifest import read_manifest

ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    """Rechaza una discrepancia con el contrato estructural."""
    if not condition:
        raise ValueError(message)


def constant(text):
    """Decodifica una constante hexadecimal emitida por Verilator."""
    match = re.fullmatch(r"\d+'s?h([0-9a-f]+)", text)
    require(match is not None, f"Constante XML no admitida: {text}")
    return int(match[1], 16)


def inspect(xml_path, case_id):
    """Contrasta una elaboración con el inventario y el perfil del caso."""
    root = ET.parse(xml_path).getroot()
    types = {item.get("id"): item for item in root.find(".//typetable")}
    modules = {item.get("name"): item for item in root.findall(".//module")}
    origins = {name: item.get("origName", name) for name, item in modules.items()}
    cells = root.findall(".//cell")
    actual = [origins[cell.get("submodname")] for cell in cells]

    def width(dtype):
        item = types[dtype]
        if item.tag == "structdtype":
            return sum(width(member.get("sub_dtype_id")) for member in item)
        if item.get("sub_dtype_id"):
            return width(item.get("sub_dtype_id"))
        if item.get("left") is not None:
            return abs(int(item.get("left")) - int(item.get("right"))) + 1
        return 1

    def module(origin):
        matches = [item for name, item in modules.items() if origins[name] == origin]
        require(len(matches) == 1, f"Módulo ausente o duplicado: {origin}")
        return matches[0]

    def variable(owner, name):
        matches = [item for item in module(owner).iter("var") if item.get("name") == name]
        require(len(matches) == 1, f"Recurso ausente o duplicado: {owner}.{name}")
        return matches[0]

    def array(owner, name):
        dtype = variable(owner, name).get("dtype_id")
        item = types[dtype]
        require(item.tag == "unpackarraydtype", f"No es array físico: {owner}.{name}")
        bounds = [constant(value.get("name")) for value in item.find("range")]
        return abs(bounds[1] - bounds[0]) + 1, width(item.get("sub_dtype_id"))

    inventory = []
    for line in (ROOT / "docs/architecture/module_inventory.md").read_text().splitlines():
        if not re.match(r"\| \[\d+\.\d+\]", line):
            continue
        columns = [column.strip() for column in line.split("|")]
        block = re.search(r"\[(\d+\.\d+)\]", columns[1])[1]
        file_name = re.search(r"`([^`]+\.sv)`", columns[4])[1]
        owner = re.search(r"`([^`]+)`", columns[5])[1]
        separate = re.search(r"Separado: `([^`]+)`", columns[3])
        inventory.append(
            {
                "id": block,
                "file": file_name,
                "parent": owner,
                "module": separate[1] if separate else Path(file_name).stem,
                "separate": separate is not None,
            }
        )
    require(len(inventory) == 51, "El inventario no contiene los 51 IDs CPU")
    require(len({item["id"] for item in inventory}) == 51, "IDs duplicados")
    separate = {item["module"] for item in inventory if item["separate"]}
    containers = {item["module"] for item in inventory if not item["separate"]}
    require(len(separate) == 23, "Se alteró la agrupación de 23 módulos específicos")
    require(
        set(actual) == separate | containers, "La jerarquía elaborada difiere del inventario CPU"
    )
    require(len(actual) == len(set(actual)), "Se duplicó una instancia funcional CPU")
    cell_parents = {child: parent for parent in root.iter() for child in parent}
    for item in inventory:
        require((ROOT / "rtl" / item["file"]).is_file(), f"Falta {item['file']}")
        if not item["separate"]:
            continue
        cell = next(cell for cell in cells if origins[cell.get("submodname")] == item["module"])
        parent = cell_parents[cell]
        while parent.tag != "cell":
            parent = cell_parents[parent]
        require(
            origins[parent.get("submodname")] == item["parent"],
            f"Padre incorrecto para {item['id']}",
        )

    manifest = read_manifest(ROOT / "docs/verification/cases.json")
    case = next(
        case for group in manifest["groups"] for case in group["cases"] if case["id"] == case_id
    )
    imem, dmem = case["inputs"]["IMEM_C"], case["inputs"]["DMEM_C"]
    for name, expected in [("IMEM_CAPACITY_BYTES", imem), ("DMEM_CAPACITY_BYTES", dmem)]:
        require(
            constant(variable("processor_top", name).find("const").get("name")) == expected,
            f"El XML no corresponde a {case_id}: {name}",
        )
    payloads = {}
    for name, origin in [
        ("ifid", "if_id_register"),
        ("idex", "id_ex_register"),
        ("exmem", "ex_mem_register"),
        ("memwb", "mem_wb_register"),
    ]:
        dtype = types[variable(origin, "data_out").get("dtype_id")]
        expected_fields = manifest["latch_fixture"][name]
        require(
            [item.get("name") for item in dtype] == [field["name"] for field in expected_fields],
            f"Campos incorrectos en {name}",
        )
        for member, field in zip(dtype, expected_fields, strict=True):
            bits = width(member.get("sub_dtype_id"))
            require(bits == field["width"], f"Ancho incorrecto en {name}.{field['name']}")
            debug = variable("processor_top", f"debug_{name}_{field['name']}")
            require(
                debug.get("dir") == "output" and width(debug.get("dtype_id")) == bits,
                f"Puerto Debug incorrecto para {name}.{field['name']}",
            )
        payloads[name] = width(dtype.get("id"))
    require(sum(payloads.values()) == 504, "El pipeline no conserva sus 504 bits")
    require(
        array("register_file", "registers") == (31, 32), "RF escribible debe ser x1..x31 de 32 bits"
    )
    require(
        array("instruction_memory", "words") == (imem // 4, 32), "IMEM no coincide con la capacidad"
    )
    for lane in range(4):
        require(
            array("data_memory", f"data_lane_{lane}") == (dmem // 4, 8), "Lanes DMEM incorrectos"
        )
        require(
            array("data_memory", f"valid_lane_{lane}") == (dmem // 4, 1), "Marcas DMEM incorrectas"
        )
    require(
        width(variable("global_fsm", "global_state").get("dtype_id")) == 14,
        "Global FSM debe conservar sus 14 bits one-hot",
    )
    require(
        not list(module("processor_top").iter("assigndly")),
        "El top agregó estado registrado propio",
    )
    return {
        "case_id": case_id,
        "xml": str(xml_path),
        "status": "passed",
        "inventory": inventory,
        "instances": len(cells),
        "specific_modules": len(separate),
        "local_blocks": 28,
        "payload_widths": payloads,
        "debug_fields": 34,
        "pipeline_bits": 504,
        "register_file": "x1..x31: 31x32; x0 arquitectónico constante, probado por simulación",
        "imem_bytes": imem,
        "dmem_bytes": dmem,
        "limits": "No prueba comportamiento de lógica local, ausencia de lazos o implementación FPGA; ver lint y regresión.",
    }


def main():
    """Publica el resultado estructural o termina con diagnóstico de error."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xml", type=Path, required=True)
    parser.add_argument("--case", default="TEST-PLAT-001/C001")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = inspect(args.xml, args.case)
    except (OSError, ValueError, KeyError, StopIteration, ET.ParseError) as error:
        parser.exit(1, f"ERROR: {error}\n")
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
