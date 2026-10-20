#!/usr/bin/env python3
"""Select, compile and execute manifest cases with Icarus Verilog."""

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

from simulation_runner import SIMULATION_LEVELS, run_selection
from verification_manifest import MANIFEST, TP3_ROOT, case_executions, index_manifest, load_manifest


class UsageError(ValueError):
    """Error de argumentos que la CLI informa con código de uso inválido."""

    pass


class ArgumentParser(argparse.ArgumentParser):
    """Convierte errores de argparse en excepciones para unificar la salida."""

    def error(self, message):
        """Interrumpe el análisis con un error que puede formatearse como texto o JSON."""
        raise UsageError(message)


@dataclass(frozen=True)
class SelectedCase:
    """Identifica un caso y el grupo que aporta su contexto de ejecución."""

    group_id: str
    case_id: str


def select_cases(manifest, selectors=(), select_all=False):
    """Expande grupos y casos, conserva el orden y elimina repeticiones por contexto."""
    groups, cases = index_manifest(manifest)
    if select_all and selectors:
        raise ValueError("--all y --test son mutuamente excluyentes")
    if not select_all and not selectors:
        raise ValueError("indique --test <ID> o --all")
    selection = []
    seen = set()
    for selector in groups if select_all else selectors:
        if selector in groups:
            group = groups[selector]
            ids = [case["id"] for case in group["cases"]]
            entries = [SelectedCase(selector, case_id) for case_id in ids]
        elif selector in cases:
            group, _ = cases[selector]
            entries = [SelectedCase(group["id"], selector)]
        else:
            raise ValueError(f"ID de prueba desconocido: {selector!r}")
        for entry in entries:
            if entry not in seen:
                seen.add(entry)
                selection.append(entry)
    return selection


def partition_selection(manifest, selection, selectors=()):
    """Separa implementadas y pendientes; rechaza casos pendientes pedidos individualmente."""
    _, cases = index_manifest(manifest)
    runnable = []
    pending = []
    for entry in selection:
        if cases[entry.case_id][1]["status"] == "implemented":
            runnable.append(entry)
        elif entry.case_id in selectors:
            raise ValueError(f"el caso {entry.case_id} está pendiente de implementación")
        else:
            pending.append(entry.case_id)
    return runnable, pending


def require_executions(manifest, selection):
    """Exige bancos aplicables, niveles de simulación y fuentes existentes antes de ejecutar."""
    groups = {group["id"]: group for group in manifest["groups"]}
    missing = [
        entry.case_id
        for entry in selection
        if not case_executions(groups[entry.group_id], entry.case_id)
    ]
    if missing:
        visible = ", ".join(missing[:10])
        remaining = len(missing) - 10
        suffix = f" (y {remaining} casos más)" if remaining > 0 else ""
        raise ValueError(f"sin ejecuciones registradas: {visible}{suffix}")
    checked = set()
    for entry in selection:
        group_id = entry.group_id
        for index, execution in case_executions(groups[group_id], entry.case_id):
            if (group_id, index) in checked:
                continue
            checked.add((group_id, index))
            if execution["level"] not in SIMULATION_LEVELS:
                raise ValueError(
                    f"el nivel {execution['level']!r} de {group_id} no corresponde a una simulación Icarus"
                )
            for source in execution["sources"]:
                if not (TP3_ROOT / source).is_file():
                    raise ValueError(f"fuente inexistente en {group_id}: {source}")


def print_selection(manifest, selection, output_format):
    """Muestra los casos seleccionados y sus configuraciones, sin ejecutar pruebas."""
    groups, cases = index_manifest(manifest)
    rows = [
        {
            "group_id": entry.group_id,
            "case_id": entry.case_id,
            "status": cases[entry.case_id][1]["status"],
            "execution_count": len(case_executions(groups[entry.group_id], entry.case_id)),
        }
        for entry in selection
    ]
    if output_format == "json":
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    else:
        for row in rows:
            print(
                f"{row['case_id']} | grupo {row['group_id']} | {row['status']} | ejecuciones: {row['execution_count']}"
            )
        print(f"Selección: {len(rows)} casos con su contexto de verificación. Sin ejecutar.")


def print_error(message, output_format, listing):
    """Envía el diagnóstico a stderr y conserva una salida JSON válida cuando se solicita."""
    print(f"ERROR: {message}", file=sys.stderr)
    if output_format == "json":
        if listing:
            print("[]")
        else:
            print(
                json.dumps(
                    {
                        "status": "error",
                        "summary": {"total": 0, "passed": 0, "failed": 0, "errors": 0},
                        "results": [],
                        "pending_cases": [],
                    },
                    indent=2,
                )
            )


def print_report(report, output_format):
    """Presenta resultados y contadores en el formato de salida elegido."""
    if output_format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return
    labels = {"passed": "PASS", "failed": "FAIL", "error": "ERROR"}
    for row in report["results"]:
        suffix = f": {row['message']}" if row["message"] else ""
        print(f"{labels[row['status']]} {row['case_id']} [{row['top']}; {row['level']}]{suffix}")
    print(f"Casos pendientes: {len(report['pending_cases'])}")
    summary = report["summary"]
    print(
        f"Total: {summary['total']} | PASS: {summary['passed']} | "
        f"FAIL: {summary['failed']} | ERROR: {summary['errors']}"
    )


def make_parser(format_parser):
    """Construye la CLI con selección explícita y opciones de consulta y formato."""
    parser = ArgumentParser(
        description="Seleccionar y ejecutar simulaciones del manifiesto de TP3.",
        parents=[format_parser],
        allow_abbrev=False,
        epilog=(
            "Ejemplos:\n"
            "  bash scripts/run_tests.sh --test TEST-PIPE-001\n"
            "  bash scripts/run_tests.sh --test TEST-PLAT-001/C003 --test TEST-PIPE-001 --format json\n"
            "  bash scripts/run_tests.sh --all --list --format json"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--test", action="append", metavar="ID", help="grupo o caso; repetible")
    selection.add_argument(
        "--all",
        action="store_true",
        help="ejecutar todos los casos implementados e informar los pendientes",
    )
    selection.add_argument(
        "--validate", action="store_true", help="validar el catálogo y fuentes sin simular"
    )
    parser.add_argument(
        "--list", action="store_true", help="inspeccionar la selección sin ejecutar"
    )
    parser.add_argument(
        "--manifest", type=Path, default=MANIFEST, help="manifiesto a validar y consultar"
    )
    parser.add_argument(
        "--reports-dir", type=Path, help="conservar logs de compilación y simulación"
    )
    return parser


def main(argv=None):
    """Coordina validación, selección y ejecución; devuelve el código de salida correspondiente."""
    argv = list(sys.argv[1:] if argv is None else argv)
    format_parser = ArgumentParser(add_help=False, allow_abbrev=False)
    format_parser.add_argument(
        "--format", choices=("text", "json"), default="text", help="formato de salida"
    )
    output_format = "text"
    listing = "--list" in argv
    try:
        format_args, _ = format_parser.parse_known_args(argv)
        output_format = format_args.format
        args = make_parser(format_parser).parse_args(argv)
        manifest = load_manifest(args.manifest)
        if args.validate:
            if args.list:
                raise UsageError("--validate y --list son mutuamente excluyentes")
            selection = select_cases(manifest, select_all=True)
            runnable, _ = partition_selection(manifest, selection)
            require_executions(manifest, runnable)
            print(json.dumps({"status": "valid"}) if args.format == "json" else "Catálogo válido.")
            return 0
        selection = select_cases(manifest, args.test or (), args.all)
        if args.list:
            print_selection(manifest, selection, args.format)
            return 0
        runnable, pending = partition_selection(manifest, selection, args.test or ())
        if not runnable:
            raise ValueError("la selección no contiene pruebas implementadas")
        require_executions(manifest, runnable)
        report = run_selection(manifest, runnable, args.reports_dir)
        report["pending_cases"] = pending
        print_report(report, args.format)
        return 0 if report["status"] == "passed" else 1
    except UsageError as error:
        print_error(str(error), output_format, listing)
        return 2
    except (OSError, ValueError) as error:
        print_error(str(error), output_format, listing)
        return 1
    except KeyboardInterrupt:
        print_error("ejecución interrumpida", output_format, listing)
        return 130


if __name__ == "__main__":
    sys.exit(main())
