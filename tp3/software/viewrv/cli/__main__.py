"""Finite commands for people and automation, independent of Electron."""

import json
import math
import sys
from contextlib import contextmanager
from pathlib import Path
from urllib.parse import urlencode

import click

from software.viewrv import __version__
from software.viewrv.client.connection import connect
from software.viewrv.contracts import ApplicationError, is_uuid, success


@click.group()
@click.option(
    "--output",
    type=click.Choice(["human", "json"]),
    default="human",
    help="Formato de resultados y errores.",
)
@click.version_option(__version__, prog_name="viewrv")
def cli(output):
    """Explorar y operar el procesador del TP3 mediante el core local."""


@contextmanager
def cli_connection():
    with connect() as client:
        try:
            status = client.request("GET", "/api/v1/preferences")
            for warning in status["limitations"]:
                click.echo(f"{warning['code']}: {warning['message']}", err=True)
        except ApplicationError as error:
            if error.code != "REQUEST_NOT_SUPPORTED":
                raise
        yield client


@cli.group()
def board():
    """Consultar la placa."""


@board.command("status")
def board_status():
    """Consultar el estado conocido sin operar UART."""
    with cli_connection() as client:
        return client.request("GET", "/api/v1/board/status")


@board.command("devices")
def board_devices():
    """Enumerar los accesos JTAG disponibles sin reservar la placa."""
    with cli_connection() as client:
        return client.request("GET", "/api/v1/board/devices")


@board.command("ports")
def board_ports():
    """Enumerar los puertos UART sin abrirlos."""
    with cli_connection() as client:
        return client.request("GET", "/api/v1/board/ports")


def board_action(name, body):
    with cli_connection() as client:
        owner = client.request("POST", "/api/v1/work/register", {"client_type": "cli"})["work_id"]
        result = client.request("POST", "/api/v1/board/" + name, body, owner, finite=False)
        for warning in client.request("GET", "/api/v1/preferences")["limitations"]:
            click.echo(f"{warning['code']}: {warning['message']}", err=True)
        return result


@board.command("prepare")
@click.option("--device", help="Identificador de board devices.")
@click.option("--port", help="Puerto de board ports.")
def board_prepare(device, port):
    """Programar el bitstream incluido y comprobar UART por fases."""
    return board_action(
        "prepare",
        {
            key: value
            for key, value in {"device_id": device, "port": port}.items()
            if value is not None
        },
    )


@board.command("connect")
@click.option("--port", help="Puerto de board ports.")
def board_connect(port):
    """Comprobar UART sobre una placa previamente preparada."""
    return board_action("connect", {"port": port} if port is not None else {})


@board.command("disconnect")
def board_disconnect():
    """Resolver la actividad propia y cerrar UART, conservando el trabajo CLI."""
    return board_action("disconnect", {})


@cli.group()
def work():
    """Consultar o finalizar el trabajo persistente de CLI."""


@work.command("status")
def work_status():
    """Consultar el trabajo existente sin crear otro."""
    with cli_connection() as client:
        return client.request("GET", "/api/v1/work/cli/status")


@work.command("finish")
@click.option(
    "--discard-unsaved",
    is_flag=True,
    help="Autorizar el descarte de código pendiente si no puede conservarse.",
)
def work_finish(discard_unsaved):
    """Finalizar únicamente el trabajo existente de CLI."""
    with cli_connection() as client:
        status = client.request("GET", "/api/v1/work/cli/status")
        if status["work_id"] is None:
            raise ApplicationError("WORK_NOT_ACTIVE", "No hay un trabajo de CLI activo.")
        return client.request(
            "POST", "/api/v1/work/finish", {"discard_unsaved": discard_unsaved}, status["work_id"]
        )


@cli.group()
def program():
    """Ensamblar un archivo Assembly mediante el core compartido."""


@program.command("assemble")
@click.argument("file", type=click.Path(path_type=Path))
def program_assemble(file):
    """Ensamblar el texto del archivo sin cargar ni ejecutar en FPGA."""
    source_path = str(file.expanduser().resolve())
    with cli_connection() as client:
        owner = client.request("POST", "/api/v1/work/register", {"client_type": "cli"})["work_id"]
        return client.request(
            "POST", "/api/v1/program/assemble", {"source_path": source_path}, owner, finite=False
        )


def processor_action(route, body=None):
    with cli_connection() as client:
        owner = client.request("POST", "/api/v1/work/register", {"client_type": "cli"})["work_id"]
        result = client.request("POST", "/api/v1/" + route, body or {}, owner, finite=False)
        if isinstance(result, dict) and result.get("session_id"):
            details = client.request(
                "GET",
                "/api/v1/session/show?" + urlencode({"session_id": result["session_id"]}),
                work_id=owner,
            )
            for item in details["evidence"]["limitations"]:
                click.echo(f"{item['code']}: {item['message']}", err=True)
        return result


@program.command("load")
@click.argument("file", type=click.Path(path_type=Path))
def program_load(file):
    """Cargar la traducción vigente del archivo, sin ensamblar ni ejecutar."""
    return processor_action("program/load", {"source_path": str(file.expanduser().resolve())})


def finite_positive(ctx, param, value):
    if value is not None and (not math.isfinite(value) or value <= 0):
        raise click.BadParameter("debe ser positivo y finito", ctx, param)
    return value


def trial_options(function):
    function = click.option("--author", help="Autor no vacío del ensayo.")(function)
    function = click.option(
        "--no-record", is_flag=True, help="Desactivar registro para este ensayo."
    )(function)
    return click.option("--record", is_flag=True, help="Activar registro para este ensayo.")(
        function
    )


def trial_body(record, no_record, author):
    if record and no_record:
        raise click.UsageError("--record y --no-record son mutuamente excluyentes.")
    if author is not None and not author.strip():
        raise click.UsageError("--author necesita texto no vacío.")
    return {
        **({"record": record} if record or no_record else {}),
        **({"author": author} if author is not None else {}),
    }


@cli.group("run")
def run_group():
    """Ejecutar normalmente o detener el RUN propio."""


@run_group.command("start")
@click.option(
    "--limit", type=float, callback=finite_positive, help="Límite opcional de RUN en segundos."
)
@trial_options
def run_start(limit, record, no_record, author):
    """Ejecutar la imagen confirmada y esperar su desenlace."""
    return processor_action(
        "run/start",
        {
            **trial_body(record, no_record, author),
            **({"limit_seconds": limit} if limit is not None else {}),
        },
    )


@run_group.command("stop")
def run_stop():
    """Solicitar RESET del RUN propio, conservando un terminal ya iniciado."""
    return processor_action("run/stop")


@cli.group()
def debug():
    """Depurar la imagen confirmada mediante ciclos STEP."""


@debug.command("start")
@trial_options
def debug_start(record, no_record, author):
    """Abrir debug sin ejecutar todavía un ciclo."""
    return processor_action("debug/start", trial_body(record, no_record, author))


@debug.command("restart")
@trial_options
def debug_restart(record, no_record, author):
    """Recargar la misma revisión y abrir una sesión nueva."""
    return processor_action("debug/restart", trial_body(record, no_record, author))


@debug.command("step")
def debug_step():
    """Ejecutar exactamente un ciclo, sin encolar avances."""
    return processor_action("debug/step")


@debug.command("continue")
def debug_continue():
    """Avanzar con STEP hasta breakpoint, pausa, terminal o fallo."""
    return processor_action("debug/continue")


@debug.command("pause")
def debug_pause():
    """Completar el STEP pendiente e impedir el siguiente."""
    return processor_action("debug/pause")


@debug.command("stop")
def debug_stop():
    """Cerrar debug propio conservando el desenlace conocido."""
    return processor_action("debug/stop")


@debug.group("breakpoint")
def breakpoint_group():
    """Administrar breakpoints de la revisión depurada, sin avanzar ciclos."""


def pc_value(ctx, param, value):
    if value is None:
        return value
    try:
        address = int(value, 16 if value.lower().startswith("0x") else 10)
        if not 0 <= address < 2**32:
            raise ValueError()
        return address
    except ValueError as error:
        raise click.BadParameter(
            "se requiere una dirección unsigned de 32 bits decimal o hexadecimal 0x", ctx, param
        ) from error


def breakpoint_options(function):
    function = click.option(
        "--latch", required=True, type=click.Choice(["IF/ID", "ID/EX", "EX/MEM", "MEM/WB"])
    )(function)
    function = click.option("--pc", callback=pc_value)(function)
    return click.option("--line", type=click.IntRange(min=1))(function)


def breakpoint_action(action, line, pc, latch):
    if (line is None) == (pc is None):
        raise click.UsageError("Proporcioná exactamente una de --line o --pc.")
    return processor_action(
        "debug/breakpoint/" + action,
        {"latch": latch, **({"line": line} if line is not None else {"pc": pc})},
    )


@breakpoint_group.command("add")
@breakpoint_options
def breakpoint_add(line, pc, latch):
    """Agregar un breakpoint válido de instrucción y registro interetapa."""
    return breakpoint_action("add", line, pc, latch)


@breakpoint_group.command("remove")
@breakpoint_options
def breakpoint_remove(line, pc, latch):
    """Eliminar ese breakpoint sin conservar una definición desactivada."""
    return breakpoint_action("remove", line, pc, latch)


@breakpoint_group.command("list")
def breakpoint_list():
    """Consultar los breakpoints propios sin crear un trabajo."""
    with cli_connection() as client:
        owner = client.request("GET", "/api/v1/work/cli/status")["work_id"]
        if owner is None:
            raise ApplicationError("DEBUG_NOT_ACTIVE", "No hay una depuración CLI abierta.", 409)
        return client.request("GET", "/api/v1/debug/breakpoint/list", work_id=owner)


@cli.group()
def session():
    """Consultar sesiones y evidencia conservada, sin operar la FPGA."""


def session_value(ctx, param, value):
    if value is not None and not is_uuid(value):
        raise click.BadParameter("se requiere un UUID válido de sesión", ctx, param)
    return value


def session_option(function):
    return click.option(
        "--session",
        "identity",
        callback=session_value,
        help="Sesión explícita; omitir usa la última del trabajo CLI actual.",
    )(function)


def session_query(name, identity=None, after=None):
    with cli_connection() as client:
        owner = (
            client.request("GET", "/api/v1/work/cli/status")["work_id"]
            if identity is None and name != "list"
            else None
        )
        if identity is None and name != "list" and owner is None:
            raise ApplicationError(
                "SESSION_SELECTION_REQUIRED",
                "Indicá --session; no hay un ensayo predeterminado del trabajo CLI actual.",
                409,
            )
        arguments = {
            **({"session_id": identity} if identity is not None else {}),
            **({"after": after} if after is not None else {}),
        }
        route = "/api/v1/session/" + name + ("?" + urlencode(arguments) if arguments else "")
        return client.request("GET", route, work_id=owner)


@session.command("list")
def session_list():
    """Enumerar sesiones conocidas y recuperables de registros."""
    return session_query("list")


@session.command("show")
@session_option
def session_show(identity):
    """Consultar fuente, estado y última captura completa disponible."""
    return session_query("show", identity)


@session.command("steps")
@session_option
@click.option(
    "--after",
    type=click.IntRange(min=0),
    default=0,
    help="Devolver índices estrictamente posteriores.",
)
def session_steps(identity, after):
    """Leer pasos conservados sin consumirlos ni enviar STEP."""
    return session_query("steps", identity, after)


@session.command("logs")
@session_option
def session_logs(identity):
    """Consultar registro, contexto e integridad sin crear una copia."""
    return session_query("logs", identity)


def human_result(result):
    labels = {
        "work_id": "Trabajo",
        "pending_commands": "Órdenes pendientes",
        "owns_board": "Controla la placa",
        "session_id": "Ensayo",
        "debug_open": "Depuración abierta",
        "connection_status": "Conexión",
        "port": "Puerto",
        "controller": "Controlador",
        "preparation_required": "Requiere preparación",
        "recovery_pending": "Recuperación pendiente",
        "finished": "Trabajo finalizado",
        "discarded_sources": "Fuentes descartadas",
        "warnings": "Avisos",
        "program_id": "Programa",
        "source_version": "Revisión",
        "source_text": "Código ejecutado",
        "snapshot": "Captura recibida",
        "step_index": "Paso",
        "breakpoint_hits": "Breakpoints coincidentes",
        "breakpoints": "Breakpoints",
        "stop_reasons": "Motivos de detención",
        "execution_status": "Estado del ensayo",
        "record_status": "Estado del registro",
        "sessions": "Ensayos",
        "steps": "Pasos conservados",
        "observations": "Observaciones conservadas",
        "limitations": "Limitaciones",
        "outcome": "Desenlace",
        "evidence": "Evidencia",
        "device_id": "Programador JTAG",
        "reset_used": "Se aplicó RESET",
    }
    if isinstance(result, list):
        if not result:
            click.echo("No hay candidatos disponibles.")
        for candidate in result:
            click.echo(f"{candidate['id']}: {candidate['description'] or 'Sin descripción'}")
        return
    if "image" in result and "pc_to_line" in result:
        click.echo(f"Programa: {result['program_id']}")
        click.echo(f"Revisión: {result['source_version']}")
        click.echo("Imagen: " + (" ".join(f"{byte:02x}" for byte in result["image"]) or "(vacía)"))
        for entry in result["pc_to_line"]:
            click.echo(f"PC {entry['pc']}: línea {entry['line']}")
        return
    for key, value in result.items():
        if (
            isinstance(value, dict)
            or isinstance(value, list)
            and value
            and isinstance(value[0], dict)
        ):
            click.echo(f"{labels.get(key, key)}:")
            click.echo(json.dumps(value, ensure_ascii=False, indent=2))
            continue
        if value is None:
            value = "ninguno"
        elif type(value) is bool:
            value = "sí" if value else "no"
        elif isinstance(value, list):
            value = ", ".join(map(str, value)) or "ninguno"
        click.echo(f"{labels.get(key, key)}: {value}")


def main(args=None):
    args = list(sys.argv[1:] if args is None else args)
    output = "human"
    if args[:1] == ["--output"] and len(args) > 1:
        output = args[1]
    elif args and args[0].startswith("--output="):
        output = args[0].partition("=")[2]
    try:
        result = cli.main(args=args, prog_name="viewrv", standalone_mode=False)
        if isinstance(result, (dict, list)):
            if output == "json":
                click.echo(json.dumps(success(result), ensure_ascii=False))
            else:
                human_result(result)
        return 0
    except (click.Abort, KeyboardInterrupt):
        error = ApplicationError(
            "CLIENT_WAIT_INTERRUPTED",
            "Se interrumpió la espera; la operación del core no se cancela.",
        )
        code = 130
    except click.ClickException as exception:
        error = ApplicationError("INVALID_ARGUMENT", exception.format_message())
        code = 2
    except ApplicationError as exception:
        error, code = exception, 1
    except (OSError, ValueError):
        error = ApplicationError(
            "CORE_DISCOVERY_FAILED", "No se pudo obtener la configuración local del core."
        )
        code = 1
    if output == "json":
        click.echo(json.dumps(error.envelope(), ensure_ascii=False))
    else:
        click.echo(f"{error.code}: {error.message}", err=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
