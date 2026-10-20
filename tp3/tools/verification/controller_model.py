"""Modelo de flancos de las tablas Controller/Global; servicios UART abstractos."""

from dataclasses import dataclass


PROFILES = {"REFERENCE": (1024, 2048), "ALT_1000": (1000, 1000)}
TIMER_LIMIT = 4_999_999
STATES = (
    "WAIT_COMMAND", "RECEIVE_LOAD_SIZE", "WAIT_LOAD_ACCEPT_SENT",
    "RECEIVE_LOAD_DATA", "WAIT_PREP_DONE", "WAIT_STEP_END",
    "WAIT_RUN_ACCEPT_SENT", "WAIT_RUN_END", "WAIT_RESPONSE_SENT",
    "WAIT_RESET_ACCEPT_SENT", "RECOVER_RX",
)
GLOBAL_STATES = (
    "NO_IMAGE", "LOADING", "PREPARING_READY", "READY", "RUNNING",
    "STEPPING", "HALT_DRAIN_AUTO", "HALT_DRAIN_STEP",
    "FAULT_DRAIN_AUTO", "FAULT_DRAIN_STEP", "FINISHED", "FAULT",
    "PREPARING_RUN", "PREPARING_STEP",
)
LOAD_STATES = {"NO_IMAGE", "READY", "STEPPING", "HALT_DRAIN_STEP",
               "FAULT_DRAIN_STEP", "FINISHED", "FAULT"}
EXEC_STATES = LOAD_STATES - {"NO_IMAGE"}


@dataclass(frozen=True)
class Response:
    opcode: int
    result: int
    debug: bool = False


@dataclass(frozen=True)
class Events:
    rx: int | None = None       # Cabecera FIFO antes del flanco; no modela RX físico.
    error: bool = False
    activity: bool = False
    done: bool = False         # Último Stop de la respuesta actualmente ocupada.
    prepare_done: bool = False
    halt: bool = False         # Confirmaciones CPU y vacío provistos por el estímulo.
    fault: bool = False
    empty: bool = True
    reset: bool = False


class ControllerModel:
    def __init__(self, profile="REFERENCE"):
        self.profile = profile
        self.capacity, self.dmem_capacity = PROFILES[profile]
        self.edge = self.cpu_fires = 0
        self.captures, self.completions = [], []
        self.visited, self.global_visited = set(), set()
        self.imem = {}         # Palabras físicas: reset y aborto no las borran.
        self._reset()

    def _reset(self):
        self.state, self.global_state = "WAIT_COMMAND", "NO_IMAGE"
        self.size = self.index = self.remaining = self.timer = self.image_size = 0
        self.owed = self.hold = self.reset_request = False
        self.response = None
        self.partial = []

    @property
    def busy(self):
        return self.response is not None

    @property
    def prepare_active(self):
        return self.global_state.startswith("PREPARING_")

    @property
    def run_ended(self):
        return self.global_state in {"FINISHED", "FAULT"}

    @property
    def debug_select(self):
        return self.hold or (self.owed and self.run_ended)

    def _global(self, request, e, load_ok, load_fail):
        g = self.global_state
        accepted = (request == 1 and g in LOAD_STATES) or (
            request in (2, 3) and g in EXEC_STATES)
        selected = request if accepted else None
        fire = g in {"RUNNING", "HALT_DRAIN_AUTO", "FAULT_DRAIN_AUTO"}
        fire |= g in {"READY", "STEPPING", "HALT_DRAIN_STEP", "FAULT_DRAIN_STEP"} and selected in (2, 3)
        fire |= g in {"PREPARING_RUN", "PREPARING_STEP"} and e.prepare_done
        fire = bool(fire and selected != 1)
        next_g, publish = g, False
        if selected == 1:
            next_g = "LOADING"
        elif g == "LOADING":
            next_g = "NO_IMAGE" if load_fail else "PREPARING_READY" if load_ok else g
        elif self.prepare_active and e.prepare_done:
            next_g = {"PREPARING_READY": "READY", "PREPARING_RUN": "RUNNING",
                      "PREPARING_STEP": "STEPPING"}[g]
            publish = g == "PREPARING_READY"
        elif g in {"FINISHED", "FAULT"} and selected in (2, 3):
            next_g = "PREPARING_RUN" if selected == 2 else "PREPARING_STEP"
        elif g == "READY" and fire:
            next_g = "RUNNING" if selected == 2 else "STEPPING"
        elif g in {"RUNNING", "STEPPING"} and fire:
            auto = g == "RUNNING" or selected == 2
            if e.fault or e.halt:
                kind = "FAULT" if e.fault else "HALT"
                next_g = ("FAULT" if e.fault else "FINISHED") if e.empty else (
                    f"{kind}_DRAIN_{'AUTO' if auto else 'STEP'}")
            else:
                next_g = "RUNNING" if auto else "STEPPING"
        elif g.startswith("HALT_DRAIN_") and fire:
            next_g = "FINISHED"
        elif g.startswith("FAULT_DRAIN_") and fire:
            next_g = "FAULT" if e.empty else (
                "FAULT_DRAIN_AUTO" if g.endswith("AUTO") or selected == 2 else g)
        return accepted, fire, next_g, publish

    def tick(self, e=Events()):
        self.edge += 1
        self.visited.add(self.state)
        self.global_visited.add(self.global_state)
        if e.reset or self.reset_request:
            self._reset()     # Se abstrae la duración del acondicionador de reset.
            return {"reset": True, "response": None, "fire": False}
        if e.done and not self.busy:
            raise ValueError("Stop de respuesta sin serializador ocupado")
        if e.halt and e.fault:
            raise ValueError("Confirmaciones CPU no excluyentes")
        if e.prepare_done and not self.prepare_active:
            raise ValueError("prepare_done fuera de preparación")
        if e.rx is not None and not 0 <= e.rx <= 255:
            raise ValueError("Byte fuera de rango")

        state, valid = self.state, e.rx is not None and not e.error
        candidate = ((e.rx or 0) << 32) | (self.size & 0xFFFFFFFF)
        size_valid = 0 < candidate <= self.capacity and candidate % 4 == 0
        request = None
        if state == "WAIT_COMMAND" and valid and e.rx in (2, 3):
            request = e.rx
        elif state == "RECEIVE_LOAD_SIZE" and valid and self.index == 4 and size_valid:
            request = 1
        timeout = e.rx is None and not e.error and self.timer == TIMER_LIMIT
        delivery = state == "RECEIVE_LOAD_DATA" and valid
        abort = state == "RECEIVE_LOAD_DATA" and (e.error or timeout)
        last = delivery and self.remaining == 1
        load_ok = delivery and not abort and last and (self.size - self.remaining) % 4 == 3
        accepted, fire, next_g, publish = self._global(request, e, load_ok, abort)
        next_state, timer = state, self.timer
        owed, hold, reset_request = self.owed, self.hold, False
        responses = []
        debug_before = self.debug_select

        def respond(opcode, result, debug=False):
            responses.append(Response(opcode, result, debug))

        if state == "WAIT_COMMAND":
            if e.error:
                next_state, timer = "RECOVER_RX", 0
            elif valid:
                if e.rx == 1:
                    self.size = self.index = 0
                    next_state, timer = "RECEIVE_LOAD_SIZE", 0
                elif e.rx == 2:
                    respond(2, 1 if accepted else 4 if self.image_size else 5)
                    owed = bool(accepted)
                    next_state = "WAIT_RUN_ACCEPT_SENT" if accepted else "WAIT_RESPONSE_SENT"
                elif e.rx == 3:
                    if accepted and not fire:
                        next_state = "WAIT_STEP_END"
                    else:
                        respond(3, 2 if accepted else 4 if self.image_size else 5, bool(accepted))
                        hold = bool(accepted)
                        next_state = "WAIT_RESPONSE_SENT"
                elif e.rx == 4:
                    respond(4, 1)
                    owed, next_state = False, "WAIT_RESET_ACCEPT_SENT"
                else:
                    respond(e.rx, (3 if self.global_state in LOAD_STATES else 4) if e.rx == 5 else 12)
                    next_state = "WAIT_RESPONSE_SENT"
        elif state == "RECEIVE_LOAD_SIZE":
            if e.error or timeout:
                respond(1, 9 if e.error else 7)
                next_state, timer = "RECOVER_RX", 0
            elif valid:
                self.size |= e.rx << (8 * self.index)
                if self.index == 4:
                    respond(1, 6 if not size_valid else 1 if accepted else 4)
                    next_state = "WAIT_LOAD_ACCEPT_SENT" if accepted else "WAIT_RESPONSE_SENT"
                    if accepted:
                        self.remaining = candidate
                        self.partial = []
                else:
                    self.index += 1
                    timer = 0
            else:
                timer += 1
        elif state == "WAIT_LOAD_ACCEPT_SENT" and e.done:
            next_state, timer = "RECEIVE_LOAD_DATA", 0
        elif state == "RECEIVE_LOAD_DATA":
            if abort:
                respond(1, 9 if e.error else 8)
                self.partial = []
                next_state, timer = "RECOVER_RX", 0
            elif delivery:
                offset = self.size - self.remaining
                self.partial.append(e.rx)
                if offset % 4 == 3:
                    self.imem[offset // 4] = int.from_bytes(bytes(self.partial), "little")
                    self.partial = []
                self.remaining -= 1
                if last:
                    next_state = "WAIT_PREP_DONE"
                else:
                    timer = 0
            else:
                timer += 1
        elif state == "WAIT_PREP_DONE" and not self.prepare_active:
            respond(1, 2)
            next_state = "WAIT_RESPONSE_SENT"
        elif state == "WAIT_STEP_END" and fire:
            respond(3, 2, True)
            hold, next_state = True, "WAIT_RESPONSE_SENT"
        elif state == "WAIT_RUN_ACCEPT_SENT" and e.done:
            next_state = "WAIT_RESPONSE_SENT" if self.run_ended else "WAIT_RUN_END"
        elif state == "WAIT_RUN_END":
            if self.run_ended:
                next_state = "WAIT_RESPONSE_SENT"
            elif not self.prepare_active:
                if valid and e.rx == 4:
                    respond(4, 1)
                    owed, next_state = False, "WAIT_RESET_ACCEPT_SENT"
                elif e.error or valid:
                    next_state, timer = "RECOVER_RX", 0
        elif state == "WAIT_RESPONSE_SENT" and e.done:
            hold, next_state = False, "WAIT_COMMAND"
        elif state == "WAIT_RESET_ACCEPT_SENT" and e.done:
            reset_request = True
        elif state == "RECOVER_RX":
            if e.activity:
                timer = 0
            elif timer < TIMER_LIMIT:
                timer += 1
            elif e.rx is None and not self.busy and not self.hold:
                if not self.owed:
                    next_state = "WAIT_COMMAND"
                elif not self.run_ended:
                    next_state = "WAIT_RUN_END"

        if self.owed and self.run_ended:
            hold = True
            if not self.busy:
                respond(2, 10 if self.global_state == "FINISHED" else 11, True)
                owed = False
        if state == "RECOVER_RX" and e.done and self.hold:
            hold = False
        assert len(responses) <= 1, "Productores de respuesta simultáneos"
        assert not responses or not self.busy, "Captura con serializador ocupado"
        if e.done:
            self.completions.append((self.edge, self.response))
            self.response = None
        if responses:
            self.response = responses[0]
            self.captures.append((self.edge, self.response))
        if accepted and request == 1:
            self.image_size = 0
        if publish:
            self.image_size = self.size
        self.state, self.global_state, self.timer = next_state, next_g, timer
        self.owed, self.hold, self.reset_request = owed, hold, reset_request
        self.cpu_fires += fire
        self.visited.add(self.state)
        self.global_visited.add(self.global_state)
        self._invariants()
        return dict(request=request, accepted=accepted, fire=fire, delivery=delivery,
                    load_ok=load_ok, abort=abort, publish=publish,
                    debug_before=debug_before, response=responses[0] if responses else None)

    def _invariants(self):
        assert 0 <= self.timer <= TIMER_LIMIT
        assert 0 <= self.remaining <= self.capacity
        if self.state == "WAIT_COMMAND":
            assert not (self.busy or self.prepare_active or self.owed or self.hold)
        if self.state in {"RECEIVE_LOAD_SIZE", "RECEIVE_LOAD_DATA", "WAIT_PREP_DONE", "WAIT_STEP_END"}:
            assert not (self.busy or self.owed)
        if self.state == "WAIT_RUN_END":
            assert not self.busy
        assert not (self.hold and self.prepare_active)
