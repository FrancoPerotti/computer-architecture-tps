"""Política de recuperación fuera de LOAD, con reloj monótono virtual en ms."""

from controller_model import PROFILES


def silence_ms(profile):
    capacity = PROFILES[profile][1]
    list_ms = (5 * capacity * 10 * 1000 + 19199) // 19200 + 200
    return ((200 + 319 + list_ms + 99) // 100) * 100


class RecoveryModel:
    def __init__(self, profile="REFERENCE", interrupted=2, snapshot=None):
        if interrupted == 1:
            raise ValueError("LOAD tiene su propia recuperación")
        self.quiet_ms = silence_ms(profile)
        self.state = "SILENCE_QUERY"
        self.now = self.since = 0
        self.deadline = None
        self.connected = True
        self.query_sent = self.reset_used = False
        self.sent = []
        self.prefix = bytearray()
        self.trailing = bytearray()
        self.snapshot = snapshot  # Observación anterior, no reconstrucción de sesión.

    def _send(self, opcode):
        if opcode == 4:
            assert not self.reset_used
            self.reset_used = True  # Se consume el intento antes de enviarlo.
        else:
            assert opcode == 5 and not self.query_sent
            self.query_sent = True
        self.sent.append((self.now, opcode))
        self.state = "RESET" if opcode == 4 else "QUERY"
        self.prefix.clear()
        self.deadline = self.now + 200
        return opcode

    def _query_failed(self, data_seen):
        if data_seen:
            self.state, self.since = "SILENCE_RESET", self.now
            self.prefix.clear()
            return None
        assert self.now - self.sent[-1][0] >= 100
        return self._send(4)

    def advance(self, now, data=b"", connected=True):
        if now < self.now:
            raise ValueError("El reloj debe ser monótono")
        self.now = now
        if self.state in {"FAILED", "RESET_CONFIRMED", "QUERY_OK"}:
            return None
        if not connected:
            self.connected = False
            if self.reset_used:
                self.state = "FAILED"
            else:
                self.state = "SILENCE_RESET" if self.query_sent else "SILENCE_QUERY"
                self.prefix.clear()
            return None
        if not self.connected:
            self.connected, self.since = True, now
        if self.state.startswith("SILENCE_"):
            # Procesar el lector antes de decidir si venció el silencio.
            if data:
                self.since = now
                return None
            if now - self.since >= self.quiet_ms:
                return self._send(5 if self.state == "SILENCE_QUERY" else 4)
            return None

        if now > self.deadline:
            if self.state == "QUERY":
                return self._query_failed(bool(self.prefix or data))
            self.state = "FAILED"
            return None
        self.prefix.extend(data)
        opcode = 5 if self.state == "QUERY" else 4
        results = {3, 4} if opcode == 5 else {1}
        invalid = bool(self.prefix) and self.prefix[0] != opcode
        invalid |= len(self.prefix) >= 2 and self.prefix[1] not in results
        if invalid:
            if self.state == "QUERY":
                return self._query_failed(True)
            self.state = "FAILED"
        elif len(self.prefix) >= 2:
            self.trailing.extend(self.prefix[2:])
            self.state = "QUERY_OK" if opcode == 5 else "RESET_CONFIRMED"
        elif now >= self.deadline:
            if self.state == "QUERY":
                return self._query_failed(bool(self.prefix))
            self.state = "FAILED"
        return None
