"""Proyecta los casos canónicos sobre operaciones observables desde la Basys 3."""

from dataclasses import dataclass, field

from scripts.verification_manifest import index_manifest, read_manifest
from software.assembler import assemble

IMEM = 1024
DMEM = 2048
GROUP = "TEST-PLAT-005"
SMOKE = "smoke"


@dataclass
class Image:
    """Imagen IMEM con el origen y el costo del setup cuando corresponden."""

    data: bytes
    source: str | None = None
    setup: str | None = None
    block_pc: int = 0
    setup_cycles: int = 0


@dataclass
class Plan:
    """Imágenes y operaciones observables de una reejecución."""

    images: list[Image] = field(default_factory=list)
    actions: list[dict] = field(default_factory=list)
    pending: str | None = None

    def command(self, opcode, result):
        """Agrega una solicitud con respuesta corta esperada."""
        self.actions.append({"op": "command", "request": opcode, "response": result})

    def load(self, image):
        """Valida y registra una imagen para la secuencia normal de LOAD."""
        if not 0 < len(image.data) <= IMEM or len(image.data) % 4:
            raise ValueError("imagen física fuera de REFERENCE")
        index = len(self.images)
        self.images.append(image)
        self.actions.append({"op": "load", "image": index})

    def snapshot(self, op, expected):
        """Agrega una observación con sus campos esperados."""
        self.actions.append({"op": op, "expected": expected})

    def no_image(self):
        """Comprueba disponibilidad y rechazo de ejecución sin imagen."""
        self.command(0x05, 0x03)
        self.command(0x03, 0x05)
        self.command(0x02, 0x05)


def translate(source):
    """Invoca el assembler del TP3 y conserva su diagnóstico en caso de error."""
    result = assemble(source)
    if result.error is not None or result.image is None:
        raise ValueError(f"setup inválido: {result.error}")
    return result.image


def program(*lines):
    """Construye una imagen y conserva su fuente Assembly."""
    source = "\n".join(lines) + "\n"
    return Image(translate(source), source=source)


def machine_words(words):
    """Empaqueta las palabras dirigidas del catálogo en orden UART."""
    return b"".join(word.to_bytes(4, "little") for word in words)


def set_register(register, value):
    """Representa un patrón de 32 bits mediante LUI y ADDI legales."""
    signed = (value + 2**31) % 2**32 - 2**31
    if -2048 <= signed < 2048:
        return [f"addi x{register},x0,{signed}"]
    low = (value + 2048) % 4096 - 2048
    high = ((value - low) >> 12) & 0xFFFFF
    lines = [f"lui x{register},0x{high:x}"]
    if low:
        lines.append(f"addi x{register},x{register},{low}")
    return lines


def setup_instructions(rf, memory):
    """Proyecta los operandos y marcas de DMEM sobre un prefijo legal."""
    remaining = dict(memory)
    lines = []
    for address in sorted(memory):
        if address not in remaining:
            continue
        if address % 4 == 0 and all(address + i in remaining for i in range(4)):
            value = int.from_bytes(bytes(remaining.pop(address + i) for i in range(4)), "little")
            store = "sw"
        else:
            value = remaining.pop(address)
            store = "sb"
        lines.extend(set_register(31, value))
        lines.append(f"{store} x31,{address}(x0)")
    # El temporal forma parte del setup y vuelve a su valor inicial antes del bloque.
    if memory or rf[31]:
        lines.extend(set_register(31, rf[31]))
    for register, value in enumerate(rf[1:31], 1):
        if value:
            lines.extend(set_register(register, value))
    if lines:
        # La redirección vacía IF/ID e ID/EX antes de buscar la primera palabra
        # canónica. El JAL a x0 sale antes del EX de esa primera instrucción.
        lines.append("jal x0,4")
    return lines


def terminal(state, pc, count, rf, memory, cause=None, fault_pc=None):
    """Describe el contexto, RF y DMEM esperados al vaciarse el pipeline."""
    observation = {
        "state": state,
        "image_valid": 1,
        "pc": pc,
        "count": count,
        "rf": rf,
        "valid": [0, 0, 0, 0],
        "memory": sorted([address, value] for address, value in memory.items()),
    }
    if state == 11:
        observation.update(fault_cause=cause, fault_pc=fault_pc)
    return observation


def first_step(image):
    """Describe la primera captura luego de preparar una imagen."""
    return {
        "state": 5,
        "image_valid": 1,
        "pc": 4,
        "count": 1,
        "rf": [0] * 32,
        "valid": [1, 0, 0, 0],
        "memory": [],
        "ifid": {
            "pc": 0,
            "instruction": int.from_bytes(image.data[:4], "little"),
            "fetch_fault_valid": 0,
        },
    }


def registers(**values):
    """Construye la expectativa de 32 registros desde sus valores no nulos."""
    rf = [0] * 32
    for name, value in values.items():
        rf[int(name[1:])] = value
    return rf


def cpu_projection(case_id, inputs, expected):
    """Traslada el programa y el oráculo canónicos al setup físico."""
    words = inputs["words"]
    start_rf = list(inputs.get("initial_rf", [0] * 32))
    start_mem = {entry["address"]: entry["value"] for entry in inputs.get("initial_memory", [])}
    memory = dict(zip(expected["used_addresses"], expected["used_values"], strict=True))
    final_rf = list(expected["rf"])
    lines = setup_instructions(start_rf, start_mem)
    shift = 4 * len(lines)
    if shift and case_id.startswith(("TEST-ISA-006/", "TEST-ISA-008/")) and words[0] & 0x7F == 0x67:
        # Los otros saltos usan desplazamientos relativos. JALR necesita una base
        # absoluta trasladada, incluido el bit bajo de los casos de enmascaramiento.
        old_base = start_rf[1]
        start_rf[1] += shift
        if final_rf[1] == old_base:
            final_rf[1] += shift
    if case_id == "TEST-PIPE-005/C008":
        start_mem[0] += shift
        memory[0] += shift
        final_rf[1] += shift
    if case_id.startswith("TEST-ISA-006/") or case_id in (
        "TEST-ISA-008/C005",
        "TEST-ISA-008/C006",
        "TEST-PIPE-005/C008",
    ):
        jal = words[1] if case_id == "TEST-PIPE-005/C008" else words[0]
        destination = (jal >> 7) & 31
        if destination:
            final_rf[destination] += shift
    relocated = setup_instructions(start_rf, start_mem)
    if len(relocated) != len(lines):
        raise ValueError(f"{case_id}: la relocación cambió el tamaño del setup")
    setup = "\n".join(relocated) + "\n" if relocated else None
    prefix = translate(setup) if setup else b""
    if len(prefix) != shift:
        raise ValueError(f"{case_id}: expansión inesperada del setup")
    cycles_before_block = len(lines) + 2 if lines else 0
    image = Image(
        machine_words(words) if not prefix else prefix + machine_words(words),
        setup=setup,
        block_pc=shift,
        setup_cycles=cycles_before_block,
    )
    last = expected["trace"][-1] if "trace" in expected else expected
    count = (last["count"] if "count" in last else last["cycles"]) + cycles_before_block
    observation = terminal(
        expected["terminal"],
        last["pc"] + shift,
        count,
        final_rf,
        memory,
        expected["fault_cause"],
        expected["fault_pc"] + shift,
    )
    return image, observation


def cpu_plan(plan, case):
    """Construye el recorrido STEP o RUN de la variante del CPU."""
    case_id = case["id"]
    for inputs, expected in zip(
        case["inputs"]["processor"], case["expected"]["processor"], strict=True
    ):
        image, final = cpu_projection(case_id, inputs, expected)
        plan.load(image)
        if inputs["mode"] == "STEP":
            for count in range(1, final["count"]):
                observed = {"count": count, "image_valid": 1}
                if count == 1:
                    observed.update(first_step(image))
                if case_id == "TEST-PIPE-005/C002" and count == image.setup_cycles + 3:
                    observed.update(
                        pc=image.block_pc + 8,
                        valid=[1, 0, 1, 0],
                        ifid={"pc": image.block_pc + 4},
                        exmem={"pc": image.block_pc},
                    )
                plan.snapshot("step", observed)
            plan.snapshot("step", final)
        else:
            if case_id.startswith("TEST-ISA-003/"):
                plan.snapshot("step", first_step(image))
                plan.snapshot(
                    "step",
                    {
                        "count": 2,
                        "state": 5,
                        "pc": 8,
                        "valid": [1, 1, 0, 0],
                        "idex": {"pc": 0, "immediate": int(case["expected"]["immediate"], 16)},
                    },
                )
            plan.snapshot("run", final)


def reject_size(plan, size):
    """Prueba el tamaño sin transmitir contenido después del rechazo."""
    plan.command(0x05, 0x03)
    plan.actions.append({"op": "load-header", "size": size, "response": 0x06})


def load_cases(plan, case):
    """Prepara pruebas de tamaños y preservación o invalidez de imagen."""
    inputs = case["inputs"]
    group, _, variant = case["id"].partition("/")
    if group == "TEST-MEM-008":
        old = inputs["cpu_old_image"]
        plan.load(Image(machine_words(old)))
        final_a = terminal(10, 20, 7, registers(x1=7, x2=9), dict(enumerate([7, 0, 0, 0])))
        plan.snapshot("run", final_a)
        if "requested_N" in inputs:
            reject_size(plan, inputs["requested_N"])
            # STEP reinicia la sesión terminal con la imagen A todavía cargada.
            plan.snapshot("step", first_step(plan.images[-1]))
            plan.snapshot("run", final_a)
        else:
            plan.command(0x05, 0x03)
            plan.actions.append(
                {
                    "op": "incomplete-load",
                    "size": inputs["new_N"],
                    "data": machine_words([11])[: inputs["received_bytes"]].hex(),
                }
            )
            plan.no_image()
            plan.load(program("halt"))
            plan.snapshot("run", terminal(10, 8, 3, registers(), {}))
    elif "N40" in inputs:
        plan.load(program("addi x1,x0,7", "sw x1,0(x0)", "addi x2,x0,9", "halt"))
        plan.snapshot("step", first_step(plan.images[-1]))
        reject_size(plan, inputs["N40"])
        plan.snapshot(
            "run", terminal(10, 20, 7, registers(x1=7, x2=9), dict(enumerate([7, 0, 0, 0])))
        )
    elif variant == "C009":
        plan.load(Image(machine_words([inputs["content_word"]])))
        plan.snapshot("run", terminal(11, 4, 2, registers(), {}, 2, 0))
    else:
        size = inputs["N"]
        writes = size // 4 - 1
        image = program(*(f"addi x1,x0,{i}" for i in range(writes)), "halt")
        plan.load(image)
        plan.snapshot("step", first_step(image))
        plan.snapshot(
            "run",
            terminal(
                10, size + 4, writes + (4 if writes else 3), registers(x1=max(0, writes - 1)), {}
            ),
        )


def memory_lists(plan, variant):
    """Prepara las marcas DMEM y su estado esperado mediante stores."""
    if variant == "C001":
        image = program(
            "sb x0,3(x0)",
            "lui x1,1",
            "addi x1,x1,0x234",
            "sh x1,0(x0)",
            "addi x2,x0,0x56",
            "sb x2,1(x0)",
            "lb x3,2(x0)",
            "halt",
        )
        plan.load(image)
        plan.snapshot(
            "run", terminal(10, 36, 11, registers(x1=0x1234, x2=0x56), {0: 0x34, 1: 0x56, 3: 0})
        )
        plan.snapshot("step", first_step(image))
    elif variant == "C002":
        plan.load(program("halt"))
        plan.snapshot("run", terminal(10, 8, 3, registers(), {}))
    elif variant == "C003":
        plan.load(program("addi x1,x0,2047", "sb x1,0(x1)", "halt"))
        plan.snapshot("run", terminal(10, 16, 6, registers(x1=2047), {2047: 255}))
    else:
        plan.load(full_memory())
        plan.snapshot(
            "run",
            terminal(
                10,
                28,
                2 + 3 * DMEM + 2 * (DMEM - 1) + 4,
                registers(x1=DMEM, x2=DMEM),
                {address: address % 256 for address in range(DMEM)},
            ),
        )


def full_memory():
    """Genera una marca por dirección con un loop SB."""
    return program(
        "lui x2,1",
        "addi x2,x2,-2048",
        "loop: sb x1,0(x1)",
        "addi x1,x1,1",
        "bne x1,x2,loop",
        "halt",
    )


def reset_cases(plan, group, variant):
    """Prepara el estímulo y la recuperación posterior para cada fuente de reset."""
    if group == "TEST-EXEC-008" or variant in ("C001", "C007"):
        plan.load(program("loop: jal x0,loop"))
        plan.actions.append({"op": "run-start"})
        if variant == "C002" or variant == "C007":
            plan.actions.append({"op": "button", "phase": "RUN"})
        else:
            plan.command(0x04, 0x01)
    elif variant == "C002":
        plan.load(program("addi x1,x0,1"))
        plan.snapshot("run", terminal(11, 8, 5, registers(x1=1), {}, 1, 4))
        plan.command(0x04, 0x01)
    elif variant == "C008":
        plan.load(program("halt"))
        plan.images.append(program(*(["addi x0,x0,0"] * 255), "halt"))
        plan.actions.append(
            {
                "op": "button",
                "phase": "LOAD",
                "image": len(plan.images) - 1,
                "payload_bytes": IMEM - 4,
            }
        )
    elif variant == "C009":
        plan.images.append(program("halt"))
        plan.pending = (
            "Disparar el reset físico dentro de PREPARING_READY con el final del "
            "payload como referencia y una captura temporal calibrada con la #15."
        )
        plan.command(0x05, 0x03)
        plan.actions.append({"op": "load-header", "size": 4, "response": 0x01})
        plan.actions.append(
            {
                "op": "button",
                "phase": "PREPARING_READY",
                "image": 0,
                "payload_bytes": 4,
                "expect_silence": True,
            }
        )
    else:
        plan.load(full_memory())
        plan.actions.append({"op": "run-start"})
        plan.actions.append({"op": "button", "phase": "DEBUG"})
    plan.no_image()
    plan.load(program("halt"))
    plan.snapshot("run", terminal(10, 8, 3, registers(), {}))


def smoke():
    """Construye un recorrido corto desde fuente hasta ejecución y reset."""
    plan = Plan()
    plan.command(0x04, 0x01)
    plan.no_image()
    image = program("addi x1,x0,7", "sw x1,0(x0)", "addi x2,x0,9", "halt")
    plan.load(image)
    plan.snapshot("step", first_step(image))
    plan.snapshot("run", terminal(10, 20, 7, registers(x1=7, x2=9), dict(enumerate([7, 0, 0, 0]))))
    plan.load(program("halt"))
    plan.snapshot("run", terminal(10, 8, 3, registers(), {}))
    plan.load(program("addi x1,x0,1"))
    plan.snapshot("run", terminal(11, 8, 5, registers(x1=1), {}, 1, 4))
    plan.command(0x04, 0x01)
    plan.no_image()
    return plan


def replay_plans():
    """Emite un plan por cada ID original de la selección canónica."""
    groups, cases = index_manifest(read_manifest())
    ids = groups[GROUP]["replay_cases"]
    if len(ids) != 151 or len(set(ids)) != len(ids):
        raise ValueError(f"{GROUP}: se esperaban 151 IDs de reejecución distintos")
    for case_id in ids:
        group, _, variant = case_id.partition("/")
        case = cases[case_id][1]
        plan = Plan()
        if group == "TEST-UART-013" or case_id in ("TEST-EXEC-008/C001", "TEST-EXEC-008/C002"):
            reset_cases(plan, group, variant)
        elif case["inputs"].get("processor"):
            cpu_plan(plan, case)
        elif group == "TEST-UART-008":
            memory_lists(plan, variant)
        elif group in ("TEST-UART-004", "TEST-MEM-008"):
            load_cases(plan, case)
        else:
            raise ValueError(f"falta preparar {case_id}")
        yield case_id, plan
