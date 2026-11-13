"""Selection preserves explicit destinations and rejects contradictory USB identity."""

from software.viewrv.contracts import ApplicationError


def public_candidates(values):
    return [{"id": item["id"], "description": item.get("description")} for item in values]


def selection_error(code, message, candidates):
    return ApplicationError(
        code,
        message,
        409 if code.endswith("REQUIRED") else 404,
        {"candidates": public_candidates(candidates)},
    )


def select_device(devices, explicit=None):
    if explicit is not None:
        device = next((item for item in devices if item["id"] == explicit), None)
        if device is None:
            raise selection_error(
                "DEVICE_NOT_FOUND", "El programador elegido no está disponible.", devices
            )
        return device
    if len(devices) == 1 and devices[0].get("serial") and devices[0]["id"].startswith("serial:"):
        return devices[0]
    raise selection_error(
        "DEVICE_SELECTION_REQUIRED", "Seleccioná el acceso JTAG de la Basys 3.", devices
    )


def association(device, port):
    for key in ("vid", "pid"):
        if device.get(key) is not None and port.get(key) is not None and device[key] != port[key]:
            return "different"
    bus_known = all(
        device.get(key) is not None and port.get(key) is not None for key in ("bus", "address")
    )
    if bus_known and any(device[key] != port[key] for key in ("bus", "address")):
        return "different"
    serial, uart = device.get("serial"), port.get("serial")
    if serial and uart:
        # The FTDI VCP driver can append interface B to its parent iSerial.
        if uart not in (serial, serial + "B"):
            return "different"
        return "same"
    return "same" if bus_known else "unknown"


def select_uart(ports, device, explicit=None, remembered=None, *, device_explicit=False):
    compatible = [item for item in ports if association(device, item) != "different"]
    chosen = explicit if explicit is not None else remembered
    if chosen is not None:
        port = next((item for item in compatible if item["id"] == chosen), None)
        if port is None:
            raise selection_error(
                "PORT_NOT_FOUND",
                "El puerto elegido o recordado no está disponible para esta placa.",
                compatible,
            )
        if association(device, port) == "unknown" and not (
            explicit is not None and device_explicit
        ):
            raise selection_error(
                "PORT_SELECTION_REQUIRED",
                "Seleccioná explícitamente JTAG y UART para confirmar su asociación.",
                compatible,
            )
        return port
    matching = [item for item in compatible if association(device, item) == "same"]
    if len(matching) == 1:
        return matching[0]
    raise selection_error(
        "PORT_SELECTION_REQUIRED",
        "No hay un puerto UART inequívoco para la placa seleccionada.",
        compatible,
    )
