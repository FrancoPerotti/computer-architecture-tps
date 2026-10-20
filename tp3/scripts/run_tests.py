#!/usr/bin/env python3
"""Select, compile and execute manifest cases with Icarus Verilog."""

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import sys

from verification_manifest import MANIFEST, TP3_ROOT, index_manifest, load_manifest
from simulation_runner import SIMULATION_LEVELS, run_selection


class UsageError(ValueError):
    pass


class ArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(message)


@dataclass(frozen=True)
class SelectedCase:
    group_id: str
    case_id: str


def select_cases(manifest, selectors=(), select_all=False):
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
            ids.extend(group.get("replay_cases", []))
            if not ids:
                raise ValueError(f"el grupo {selector} no contiene casos")
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
    if not selection:
        raise ValueError("la selección no contiene casos")
    return selection


def require_executions(manifest, selection):
    groups = {group["id"]: group for group in manifest["groups"]}
    selected_groups = dict.fromkeys(entry.group_id for entry in selection)
    missing = [group_id for group_id in selected_groups if not groups[group_id]["executions"]]
    if missing:
        visible = ", ".join(missing[:10])
        remaining = len(missing) - 10
        suffix = f" (y {remaining} grupos más)" if remaining > 0 else ""
        raise ValueError(f"sin ejecuciones registradas: {visible}{suffix}")
    for group_id in selected_groups:
        for execution in groups[group_id]["executions"]:
            if execution["level"] not in SIMULATION_LEVELS:
                raise ValueError(f"el nivel {execution['level']!r} de {group_id} no corresponde a una simulación Icarus")
            for source in execution["sources"]:
                if not (TP3_ROOT / source).is_file():
                    raise ValueError(f"fuente inexistente en {group_id}: {source}")


def print_selection(manifest, selection, output_format):
    groups = {group["id"]: group for group in manifest["groups"]}
    rows = [
        {"group_id": entry.group_id, "case_id": entry.case_id,
         "execution_count": len(groups[entry.group_id]["executions"])}
        for entry in selection
    ]
    if output_format == "json":
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    else:
        for row in rows:
            print(f"{row['case_id']} | grupo {row['group_id']} | ejecuciones: {row['execution_count']}")
        print(f"Selección: {len(rows)} casos con su contexto de verificación. Sin ejecutar.")


def print_error(message, output_format, listing):
    print(f"ERROR: {message}", file=sys.stderr)
    if output_format == "json":
        if listing:
            print("[]")
        else:
            print(json.dumps({
                "status": "error",
                "summary": {"total": 0, "passed": 0, "failed": 0, "errors": 0},
                "results": [],
            }, indent=2))


def print_report(report, output_format):
    if output_format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return
    labels = {"passed": "PASS", "failed": "FAIL", "error": "ERROR"}
    for row in report["results"]:
        suffix = f": {row['message']}" if row["message"] else ""
        print(f"{labels[row['status']]} {row['case_id']} [{row['top']}; {row['level']}]{suffix}")
    summary = report["summary"]
    print(f"Total: {summary['total']} | PASS: {summary['passed']} | "
          f"FAIL: {summary['failed']} | ERROR: {summary['errors']}")


def make_parser(format_parser):
    parser = ArgumentParser(
        description="Seleccionar y ejecutar simulaciones del manifiesto de TP3.",
        parents=[format_parser],
        allow_abbrev=False,
        epilog=("Ejemplos:\n"
                "  bash scripts/run_tests.sh --test TEST-PIPE-001\n"
                "  bash scripts/run_tests.sh --test TEST-PLAT-001/C003 --test TEST-PIPE-001 --format json\n"
                "  bash scripts/run_tests.sh --all --list --format json"),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--test", action="append", metavar="ID", help="grupo o caso; repetible")
    selection.add_argument("--all", action="store_true", help="seleccionar todos los grupos")
    parser.add_argument("--list", action="store_true", help="inspeccionar la selección sin ejecutar")
    parser.add_argument("--manifest", type=Path, default=MANIFEST, help="manifiesto a validar y consultar")
    return parser


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    format_parser = ArgumentParser(add_help=False, allow_abbrev=False)
    format_parser.add_argument("--format", choices=("text", "json"), default="text", help="formato de salida")
    output_format = "text"
    listing = "--list" in argv
    try:
        format_args, _ = format_parser.parse_known_args(argv)
        output_format = format_args.format
        args = make_parser(format_parser).parse_args(argv)
        manifest = load_manifest(args.manifest)
        selection = select_cases(manifest, args.test or (), args.all)
        if args.list:
            print_selection(manifest, selection, args.format)
            return 0
        require_executions(manifest, selection)
        report = run_selection(manifest, selection)
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
