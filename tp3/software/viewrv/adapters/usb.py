"""UART enumeration metadata; does not open or alter a serial port."""

from pathlib import Path

from serial.tools import list_ports

from software.viewrv.contracts import ApplicationError


def enumerate_serial_ports():
    try:
        result = []
        for port in list_ports.comports():
            value = {
                "id": port.device,
                "description": port.description,
                "vid": port.vid,
                "pid": port.pid,
                "serial": port.serial_number,
                "bus": None,
                "address": None,
            }
            path = (Path("/sys/class/tty") / Path(port.device).name / "device").resolve()
            for parent in (path, *path.parents):
                try:
                    if (parent / "busnum").is_file() and (parent / "devnum").is_file():
                        value["bus"] = int((parent / "busnum").read_text().strip())
                        value["address"] = int((parent / "devnum").read_text().strip())
                        break
                except (OSError, ValueError):
                    break  # Missing association metadata requires explicit selection.
            result.append(value)
        return result
    except OSError as error:
        raise ApplicationError("PORT_ENUMERATION_FAILED", str(error), 500) from error
