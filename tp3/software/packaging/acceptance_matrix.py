"""Validate curated acceptance evidence against the normative IDs; render its review table."""

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

SOFTWARE = Path(__file__).resolve().parents[1]
RESULTS = {"pass", "partial", "blocked", "fail"}
LABELS = {"pass": "Pase local", "partial": "Parcial", "blocked": "Pendiente", "fail": "Fallo"}


def sha256(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def normative():
    requirements = SOFTWARE.parent / "docs/software/viewrv/requisitos.md"
    verification = SOFTWARE.parent / "docs/software/viewrv/verificacion.md"
    reqs, cases, coverage = {}, {}, {}
    for line in requirements.read_text().splitlines():
        match = re.match(r"\| (SRS-PC-[VEODICRQX]\d\d) \|", line)
        if match:
            reqs[match[1]] = line.split("|")[2].strip()
    for line in verification.read_text().splitlines():
        match = re.match(r'\| <a id="test-pc-\d+"></a> (TEST-PC-\d{3}) /', line)
        if match:
            cases[match[1]] = line.split("|")[2].strip()
        match = re.match(r"\| (SRS-PC-[VEODICRQX]\d\d) \|", line)
        if match:
            coverage[match[1]] = re.findall(r"\[(TEST-PC-\d{3})\]", line)
    if len(reqs) != 74 or len(cases) != 30 or set(coverage) != set(reqs):
        raise ValueError("El catálogo normativo cambió; revisar la matriz antes de aceptarla.")
    variant_section = verification.read_text().split("## Variantes técnicas obligatorias", 1)[1]
    variant_section = variant_section.split("## Vectores concretos de referencia", 1)[0]
    variants = {}
    for line in variant_section.splitlines():
        if line.startswith("| ") and not line.startswith("| Grupo"):
            name = line.split("|")[1].strip()
            if name and not name.startswith("-"):
                variants[name] = line.split("|")[2].strip()
    if len(variants) != 16:
        raise ValueError("Cambió el catálogo de variantes técnicas; revisar la evaluación.")
    return requirements, verification, reqs, cases, coverage, variants


def validate(report, verify_evidence=False):
    requirements, verification, reqs, cases, coverage, variants = normative()
    for file in (requirements, verification):
        relative = str(file.relative_to(SOFTWARE.parent))
        if report["normative_sha256"][relative] != sha256(file):
            raise ValueError(f"Cambió la especificación: {relative}")
    for field, expected in (("cases", cases), ("requirements", reqs), ("variants", variants)):
        rows = report[field]
        if len(rows) != len(expected) or {row["id"] for row in rows} != set(expected):
            raise ValueError(f"IDs ausentes, repetidos o ajenos en {field}")
        for row in rows:
            if row["result"] not in RESULTS:
                raise ValueError(f"Resultado inválido: {row['id']}")
            if not row["evidence"] or not row["note"]:
                raise ValueError(f"Sin evidencia o evaluación: {row['id']}")
            if any(key not in report["evidence"] for key in row["evidence"]):
                raise ValueError(f"Referencia de evidencia inexistente: {row['id']}")
            if any(key not in report["pending"] for key in row["pending"]):
                raise ValueError(f"Pendiente inexistente: {row['id']}")
            if (row["result"] == "pass") != (not row["pending"]):
                raise ValueError(f"Pase con pendientes, o pendiente sin motivo: {row['id']}")
            if field == "requirements" and row["cases"] != coverage[row["id"]]:
                raise ValueError(f"Trazabilidad normativa alterada: {row['id']}")
    if report["acceptance"] != "not_accepted":
        raise ValueError("Esta evaluación parcial no autoriza cerrar PC-I08.")
    for check in report["distribution_checks"]:
        if check["result"] not in RESULTS or not check["note"]:
            raise ValueError("Comprobación de distribución incompleta")
        if any(key not in report["evidence"] for key in check["evidence"]):
            raise ValueError("Comprobación de distribución sin evidencia válida")
    if verify_evidence:
        for key, item in report["evidence"].items():
            file = (SOFTWARE / item["path"]).resolve()
            if not file.is_relative_to(SOFTWARE) or sha256(file) != item["sha256"]:
                raise ValueError(f"Falta evidencia o cambió su huella: {key}")
        archive = (SOFTWARE / report["artifact"]["path"]).resolve()
        if not archive.is_relative_to(SOFTWARE) or sha256(archive) != report["artifact"]["sha256"]:
            raise ValueError("La huella del paquete no corresponde a la evaluación")
    return reqs, cases


def cell(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def render(report, reqs, cases, source_name):
    lines = [
        "# PC-I08: matriz de aceptación integrada",
        "",
        f"Fecha: {report['date']}. Evaluación de software y distribución; **PC-I08 no está aceptada**.",
        "",
        "Esta tabla se genera a partir de [la evaluación curada](" + source_name + "). "
        "Pase local significa que se comprobó el alcance indicado en Linux, con el nivel de "
        "evidencia registrado; no convierte un adaptador controlado en FPGA ni acredita Windows. "
        "Parcial conserva comprobaciones positivas y nombra lo que falta. Pendiente identifica "
        "una condición que aún impide completar el recorrido. Fallo identifica una condición de entrega incumplida.",
        "",
        "La trazabilidad de 30/30 casos y 74/74 requisitos no es un porcentaje de aceptación.",
        "",
        "## Alcance y resultados",
        "",
        report["scope"],
        "",
    ]
    for key, title in (("cases", "Casos"), ("requirements", "Requisitos")):
        counts = Counter(row["result"] for row in report[key])
        lines += [
            f"{title}: {counts['pass']} con pase local, {counts['partial']} parciales, "
            f"{counts['blocked']} pendientes y {counts['fail']} fallos.",
            "",
        ]
    lines += [
        "## Comprobaciones de distribución",
        "",
        "| Comprobación | Resultado | Observación |",
        "|---|---|---|",
    ]
    for check in report["distribution_checks"]:
        lines.append(
            f"| {cell(check['name'])} | {LABELS[check['result']]} | {cell(check['note'])} |"
        )
    lines += ["", "## Pendientes identificados", "", "| ID | Condición pendiente |", "|---|---|"]
    for key, value in report["pending"].items():
        lines.append(f"| {key} | {cell(value)} |")
    lines += [
        "",
        "## Variantes técnicas obligatorias",
        "",
        "| Grupo | Resultado local | Evidencia y alcance |",
        "|---|---|---|",
    ]
    for row in report["variants"]:
        evidence = ", ".join(f"[{key}](#evidencia-{key.lower()})" for key in row["evidence"])
        note = (", ".join(row["pending"]) + ": " if row["pending"] else "") + row["note"]
        lines.append(f"| {cell(row['id'])} | {LABELS[row['result']]} | {evidence}. {cell(note)} |")
    lines += [
        "",
        "## Casos",
        "",
        "| Caso | Resultado local | Evidencia | Pendientes y evaluación |",
        "|---|---|---|---|",
    ]
    for row in report["cases"]:
        identifier = row["id"]
        link = (
            f"[**{identifier}**](../../docs/software/viewrv/verificacion.md#{identifier.lower()})"
        )
        evidence = ", ".join(f"[{key}](#evidencia-{key.lower()})" for key in row["evidence"])
        pending = ", ".join(row["pending"])
        note = (pending + ": " if pending else "") + row["note"]
        lines.append(
            f"| {link} · {cell(cases[identifier])} | {LABELS[row['result']]} | {evidence} | {cell(note)} |"
        )
    lines += [
        "",
        "## Requisitos",
        "",
        "Los resultados se evaluaron por criterio; no se hereda un pase por mencionar un caso de prueba.",
        "",
        "| Requisito | Resultado local | Casos normativos | Pendientes y evaluación |",
        "|---|---|---|---|",
    ]
    for row in report["requirements"]:
        identifier = row["id"]
        note = (", ".join(row["pending"]) + ": " if row["pending"] else "") + row["note"]
        lines.append(
            f"| **{identifier}** | {LABELS[row['result']]} | {', '.join(c.replace('TEST-PC-', '') for c in row['cases'])} | {cell(note)} |"
        )
    lines += ["", "## Evidencia", ""]
    for key, item in report["evidence"].items():
        lines += [
            f"### Evidencia {key}",
            "",
            f"[{cell(item['path'])}](../{item['path']}) · {cell(item['kind'])}.",
            "",
            item["scope"],
            "",
        ]
    lines += [
        "## Repetición y límites",
        "",
        report["reproduction"],
        "",
        "Las huellas de especificaciones, logs y archivo están en el JSON. El verificador comprueba IDs completos, vínculos normativos, referencias y coherencia de estados; `--verify-evidence` comprueba además los bytes. No ejecuta pruebas ni convierte su lectura en un pase.",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--verify-evidence", action="store_true")
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    reqs, cases = validate(report, args.verify_evidence)
    if args.render:
        args.report.with_suffix(".md").write_text(render(report, reqs, cases, args.report.name))
    print(
        json.dumps(
            {
                "cases": len(cases),
                "requirements": len(reqs),
                "variants": len(report["variants"]),
                "acceptance": report["acceptance"],
            }
        )
    )
