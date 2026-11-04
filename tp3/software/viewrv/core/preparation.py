"""Board preparation coordinates leases, programming, UART and confirmed preferences."""

import asyncio

from software.viewrv.contracts import ApplicationError
from software.viewrv.core.board_selection import public_candidates, select_device, select_uart


class Preparation:
    def __init__(self, application, programmer, port_enumerator):
        self.app, self.programmer, self.port_enumerator = application, programmer, port_enumerator
        self.active = None
        self.phase = None
        self.close_requested = False
        self.device = None
        self.explicit_pair = False

    async def devices(self):
        return public_candidates(await self.programmer.devices())

    async def ports(self):
        return public_candidates(await self._ports())

    async def _ports(self):
        if self.port_enumerator is None:
            raise ApplicationError(
                "PORT_ENUMERATION_FAILED", "No está disponible la enumeración UART.", 500
            )
        return await self.app.program_service.queue.submit(lambda: (self.port_enumerator, ()))

    def _begin(self, owner, name):
        token = self.app.reserve_board(owner, name)
        self.active = asyncio.current_task()
        self.phase = "selection"
        self.close_requested = False
        return token

    def _end(self, token, owner):
        self.app.end_board_operation(token)
        self.active = None
        self.phase = None
        if self.app.board["port"] is None:
            self.app.release_board(owner)

    async def _remember(self, owner, port):
        programs = self.app.program_service
        while programs.preferences_busy:
            await asyncio.sleep(0.01)
        try:
            await programs.preferences_update(owner, {"last_serial_port": port})
        except ApplicationError as error:
            programs.limitations.append(
                {
                    "code": error.code,
                    "section": "preferences",
                    "message": "La conexión se comprobó, pero no se pudo recordar el puerto: "
                    + error.message,
                }
            )
            programs.notify("limitations")

    async def _connect(self, owner, port):
        serial = self.app.serial_service
        if self.close_requested:
            raise ApplicationError(
                "BOARD_CONNECTION_FAILED",
                "Se solicitó desconectar antes de comprobar UART.",
                409,
                {"port": port["id"], "reset_status": "not_attempted"},
            )
        self.phase = "connection"
        if self.app.board["port"] and self.app.board["port"] != port["id"]:
            await serial.disconnect()
            self.app.invalidate_image()
        operation = (
            "RECOVER"
            if self.app.board["recovery_pending"] and self.app.board["port"]
            else "CHECK_READY"
            if self.app.board["port"]
            else "OPEN"
        )
        try:
            try:
                result = await serial.request(
                    operation, {"port": port["id"]} if operation == "OPEN" else {}
                )
            except ApplicationError as error:
                if (
                    operation == "RECOVER"
                    or self.close_requested
                    or not self.app.board["port"]
                    or not self.app.board["recovery_pending"]
                    or (error.details or {}).get("reset_status") != "not_attempted"
                ):
                    raise
                result = await serial.request("RECOVER")
            if self.close_requested:
                raise ApplicationError(
                    "BOARD_CONNECTION_FAILED",
                    "Se solicitó desconectar durante la comprobación.",
                    409,
                    {
                        "port": port["id"],
                        "reset_status": result.get("reset_status", "not_attempted"),
                    },
                )
        except ApplicationError as error:
            raise ApplicationError(
                "BOARD_CONNECTION_FAILED",
                error.message,
                error.status,
                {
                    "port": port["id"],
                    "reset_status": (error.details or {}).get("reset_status", "not_attempted"),
                },
            ) from error
        await self._remember(owner, port["id"])
        return {"port": port["id"], "reset_used": result.get("reset_status") == "confirmed"}

    async def prepare(self, owner, device_id=None, port=None):
        token = self._begin(owner, "board prepare")
        device = selected = None
        programming_status = "not_attempted"
        phase = "programming"
        try:
            device = select_device(await self.programmer.devices(), device_id)
            selected = select_uart(
                await self._ports(),
                device,
                port,
                self.app.preferences["last_serial_port"],
                device_explicit=device_id is not None,
            )
            try:
                bitstream = await self.programmer.validate()
                if self.close_requested:
                    raise RuntimeError("Se solicitó desconectar antes de programar.")
                self.phase = "programming"
                if self.app.board["port"] is not None:
                    await self.app.serial_service.disconnect()
                    self.app.invalidate_image()
                await self.app.serial_service.request("UNPREPARED")
                self.app.invalidate_image()
                programming_status = "unconfirmed"
                await self.programmer.program(device, bitstream)
                programming_status = "confirmed"
                self.device = device
                self.explicit_pair = device_id is not None and port is not None
                await self.app.serial_service.request("PREPARED")
                phase = "connection"
                # Keep the exact chosen port after USB reenumeration; never take a substitute.
                selected = select_uart(
                    await self._ports(), device, selected["id"], device_explicit=self.explicit_pair
                )
                result = await self._connect(owner, selected)
                return {"device_id": device["id"], **result}
            except (ApplicationError, OSError, ValueError, RuntimeError, TimeoutError) as error:
                raise ApplicationError(
                    "BOARD_PREPARATION_FAILED",
                    str(error),
                    500,
                    {
                        "phase": phase,
                        "device_id": device["id"],
                        "port": selected["id"],
                        "programming_status": programming_status,
                        "reset_status": (getattr(error, "details", None) or {}).get(
                            "reset_status", "not_attempted"
                        ),
                    },
                ) from error
        finally:
            self._end(token, owner)

    async def connect(self, owner, port=None):
        self.app.check_board_admission(owner)
        if self.app.board["preparation_required"] or self.device is None:
            raise ApplicationError(
                "BOARD_PREPARATION_REQUIRED",
                "Primero prepará la placa con el bitstream del procesador.",
                409,
            )
        token = self._begin(owner, "board connect")
        try:
            selected = select_uart(
                await self._ports(),
                self.device,
                port,
                self.app.preferences["last_serial_port"],
                device_explicit=self.explicit_pair and port is not None,
            )
            return await self._connect(owner, selected)
        finally:
            self._end(token, owner)

    async def disconnect(self, owner):
        self.app.require_work(owner)
        if self.app.board_owner is None:
            raise ApplicationError(
                "BOARD_NOT_CONNECTED", "No hay una conexión propia que cerrar.", 409
            )
        token = self.app.reserve_board(owner, "board disconnect", control=True)
        if self.app.session_service:
            await self.app.session_service.before_disconnect(owner)
        previous = self.active
        if previous and previous is not asyncio.current_task():
            self.close_requested = True
            if self.phase == "connection":
                self.app.serial_service.interrupt()
            await asyncio.gather(asyncio.shield(previous), return_exceptions=True)
        self.active = asyncio.current_task()
        self.phase = "disconnect"
        try:
            result = await self.app.serial_service.disconnect()
            self.app.invalidate_image()
            self.app.end_board_operation(token)
            self.app.release_board(owner)
            return result
        finally:
            self._end(token, owner)

    async def finish_owned(self, owner):
        if self.app.board_owner == owner:
            await self.disconnect(owner)

    async def recover_for_session(self, owner):
        if self.app.board_owner != owner:
            raise ApplicationError(
                "BOARD_CONTROL_CONFLICT", "La recuperación pertenece a otro trabajo.", 409
            )
        return await self.app.serial_service.request("RECOVER")
