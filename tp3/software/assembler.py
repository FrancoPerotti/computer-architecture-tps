"""Assembler del subconjunto RV32I del TP3.

Traduce el lenguaje de ``tp3/docs/software/assembler_language.md`` a la imagen
little-endian y al mapa PC-línea aprobados en ``DEC-SYS-009``.

La operación pública es ``assemble``. Las etapas internas siguen el orden
lectura, direcciones, operandos, codificación y empaquetado; un error del
código fuente se propaga con ``_AssemblyError`` y se devuelve como diagnóstico
dentro de ``AssemblyResult``.
"""

import re
from dataclasses import dataclass

__all__ = ["assemble", "AssemblyResult", "AssemblyDiagnostic"]


@dataclass
class SourceRecord:
    """Línea reconocida por la lectura."""

    line: int
    label: str | None
    mnemonic: str | None
    operands: list[str]


@dataclass
class LocatedInstruction:
    """Instrucción con su dirección asignada."""

    line: int
    pc: int
    mnemonic: str
    operands: list[str]


@dataclass
class LabelDefinition:
    """Definición de etiqueta con dirección y línea."""

    address: int
    line: int


@dataclass
class InterpretedInstruction:
    """Instrucción con registros e inmediatos ya comprobados."""

    line: int
    pc: int
    mnemonic: str
    rd: int | None
    rs1: int | None
    rs2: int | None
    imm: int | None


@dataclass
class EncodedInstruction:
    """Instrucción codificada como palabra de 32 bits."""

    line: int
    pc: int
    word: int


@dataclass
class AssemblyDiagnostic:
    """Error del código fuente con su línea y motivo."""

    line: int
    message: str


@dataclass
class AssemblyResult:
    """Resultado público de una traducción."""

    image: bytes | None
    pc_to_line: dict[int, int]
    error: AssemblyDiagnostic | None


class _AssemblyError(Exception):
    """Error interno que transporta un diagnóstico del código fuente."""

    def __init__(self, line: int, message: str):
        """Conserva la línea y el motivo del error como diagnóstico."""
        super().__init__(message)
        self.diagnostic = AssemblyDiagnostic(line, message)


_REGISTERS: dict[str, int] = {f"x{index}": index for index in range(32)}
_REGISTERS.update(
    {
        "zero": 0,
        "ra": 1,
        "sp": 2,
        "gp": 3,
        "tp": 4,
        "t0": 5,
        "t1": 6,
        "t2": 7,
        "s0": 8,
        "fp": 8,
        "s1": 9,
        "a0": 10,
        "a1": 11,
        "a2": 12,
        "a3": 13,
        "a4": 14,
        "a5": 15,
        "a6": 16,
        "a7": 17,
        "s2": 18,
        "s3": 19,
        "s4": 20,
        "s5": 21,
        "s6": 22,
        "s7": 23,
        "s8": 24,
        "s9": 25,
        "s10": 26,
        "s11": 27,
        "t3": 28,
        "t4": 29,
        "t5": 30,
        "t6": 31,
    }
)

# mnemónico -> (formato, opcode, funct3, funct7, roles de operando)
# Los roles son la fuente única para la aridad, la interpretación y la
# codificación: rd, rs1, rs2, imm12, shamt, imm20, mem y dest.
_INSTRUCTIONS: dict[str, tuple[str, int, int | None, int | None, tuple[str, ...]]] = {
    "add": ("R", 0x33, 0x0, 0x00, ("rd", "rs1", "rs2")),
    "sub": ("R", 0x33, 0x0, 0x20, ("rd", "rs1", "rs2")),
    "sll": ("R", 0x33, 0x1, 0x00, ("rd", "rs1", "rs2")),
    "slt": ("R", 0x33, 0x2, 0x00, ("rd", "rs1", "rs2")),
    "sltu": ("R", 0x33, 0x3, 0x00, ("rd", "rs1", "rs2")),
    "xor": ("R", 0x33, 0x4, 0x00, ("rd", "rs1", "rs2")),
    "srl": ("R", 0x33, 0x5, 0x00, ("rd", "rs1", "rs2")),
    "sra": ("R", 0x33, 0x5, 0x20, ("rd", "rs1", "rs2")),
    "or": ("R", 0x33, 0x6, 0x00, ("rd", "rs1", "rs2")),
    "and": ("R", 0x33, 0x7, 0x00, ("rd", "rs1", "rs2")),
    "addi": ("I", 0x13, 0x0, None, ("rd", "rs1", "imm12")),
    "slti": ("I", 0x13, 0x2, None, ("rd", "rs1", "imm12")),
    "sltiu": ("I", 0x13, 0x3, None, ("rd", "rs1", "imm12")),
    "xori": ("I", 0x13, 0x4, None, ("rd", "rs1", "imm12")),
    "ori": ("I", 0x13, 0x6, None, ("rd", "rs1", "imm12")),
    "andi": ("I", 0x13, 0x7, None, ("rd", "rs1", "imm12")),
    "slli": ("SHIFT", 0x13, 0x1, 0x00, ("rd", "rs1", "shamt")),
    "srli": ("SHIFT", 0x13, 0x5, 0x00, ("rd", "rs1", "shamt")),
    "srai": ("SHIFT", 0x13, 0x5, 0x20, ("rd", "rs1", "shamt")),
    "lb": ("I", 0x03, 0x0, None, ("rd", "mem")),
    "lh": ("I", 0x03, 0x1, None, ("rd", "mem")),
    "lw": ("I", 0x03, 0x2, None, ("rd", "mem")),
    "lbu": ("I", 0x03, 0x4, None, ("rd", "mem")),
    "lhu": ("I", 0x03, 0x5, None, ("rd", "mem")),
    "sb": ("S", 0x23, 0x0, None, ("rs2", "mem")),
    "sh": ("S", 0x23, 0x1, None, ("rs2", "mem")),
    "sw": ("S", 0x23, 0x2, None, ("rs2", "mem")),
    "beq": ("B", 0x63, 0x0, None, ("rs1", "rs2", "dest")),
    "bne": ("B", 0x63, 0x1, None, ("rs1", "rs2", "dest")),
    "jal": ("J", 0x6F, None, None, ("rd", "dest")),
    "jalr": ("I", 0x67, 0x0, None, ("rd", "mem")),
    "lui": ("U", 0x37, None, None, ("rd", "imm20")),
    "halt": ("HALT", 0x0B, None, None, ()),
}

_RESERVED_NAMES = set(_INSTRUCTIONS) | set(_REGISTERS)

_LABEL_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_REGISTER_PATTERN = re.compile(r"[xX][0-9]+")
_LITERAL_PATTERN = re.compile(r"[+-]?(?:0[xX][0-9a-fA-F]+|0[bB][01]+|[0-9]+)")
_MEMORY_PATTERN = re.compile(r"([^\s()]+)[ \t]*\([ \t]*([^\s()]+)[ \t]*\)")
_INSTRUCTION_PATTERN = re.compile(r"(\S+)(?:[ \t]+(.*))?")

# El lenguaje solo admite espacios y tabulaciones como separadores.
_SEPARATORS = " \t"

# Con más dígitos significativos que estos, el literal supera cualquier rango
# admitido. El límite evita convertir cadenas enormes y sus diagnósticos.
_MAX_LITERAL_DIGITS = {10: 7, 16: 7, 2: 21}


def _abbreviate(token: str, limit: int = 40) -> str:
    """Acorta un token para que un diagnóstico no crezca sin límite."""
    return token if len(token) <= limit else token[:limit] + "…"


def _read_source(source_text: str) -> list[SourceRecord]:
    """Reconoce las líneas del programa y conserva su numeración original."""
    text = source_text
    if text.startswith("\ufeff"):
        text = text[1:]
    records: list[SourceRecord] = []
    for number, raw_line in enumerate(text.replace("\r\n", "\n").split("\n"), start=1):
        code = raw_line.split("#", 1)[0].strip(_SEPARATORS)
        if not code:
            continue
        if any(character.isspace() and character not in _SEPARATORS for character in code):
            raise _AssemblyError(
                number,
                "La línea contiene un separador no admitido; solo se permiten "
                "espacios y tabulaciones.",
            )
        label, rest = _split_label(code, number)
        if not rest:
            records.append(SourceRecord(number, label, None, []))
            continue
        mnemonic, operand_text = _split_instruction(rest, number)
        operands = _split_operands(mnemonic, operand_text, number)
        records.append(SourceRecord(number, label, mnemonic, operands))
    return records


def _split_label(code: str, line: int) -> tuple[str | None, str]:
    """Separa una definición de etiqueta inicial del resto de la línea."""
    if ":" not in code:
        return None, code
    head, tail = code.split(":", 1)
    name = head.strip(_SEPARATORS)
    if any(character.isspace() for character in name):
        # Los dos puntos pertenecen al texto de una instrucción, no a una etiqueta.
        return None, code
    if not name:
        raise _AssemblyError(line, "Falta el identificador de la etiqueta antes de ':'.")
    if not _LABEL_PATTERN.fullmatch(name):
        raise _AssemblyError(line, f"El identificador de etiqueta '{name}' no es válido.")
    if name in _RESERVED_NAMES:
        raise _AssemblyError(
            line,
            f"El nombre '{name}' está reservado y no puede usarse como etiqueta.",
        )
    rest = tail.strip(_SEPARATORS)
    if ":" in rest:
        second = rest.split(":", 1)[0].strip(_SEPARATORS)
        if second and not any(character.isspace() for character in second):
            raise _AssemblyError(line, "La línea contiene una segunda definición de etiqueta.")
    return name, rest


def _split_instruction(text: str, line: int) -> tuple[str, str]:
    """Separa el mnemónico de su texto de operandos."""
    match = _INSTRUCTION_PATTERN.fullmatch(text)
    if match is None:
        raise _AssemblyError(line, f"No se pudo reconocer la instrucción '{text}'.")
    mnemonic = match.group(1)
    operand_text = match.group(2) or ""
    if mnemonic not in _INSTRUCTIONS:
        if mnemonic.startswith("."):
            raise _AssemblyError(line, f"La directiva '{mnemonic}' no pertenece al lenguaje.")
        if mnemonic.lower() in _INSTRUCTIONS:
            raise _AssemblyError(line, f"El mnemónico '{mnemonic}' debe escribirse en minúsculas.")
        raise _AssemblyError(
            line, f"La instrucción '{mnemonic}' no pertenece al subconjunto admitido."
        )
    return mnemonic, operand_text


def _split_operands(mnemonic: str, operand_text: str, line: int) -> list[str]:
    """Comprueba aridad, comas y forma de los operandos de una instrucción."""
    roles = _INSTRUCTIONS[mnemonic][4]
    if not roles:
        if operand_text:
            raise _AssemblyError(line, "La instrucción 'halt' no admite operandos.")
        return []
    chunks = [chunk.strip(_SEPARATORS) for chunk in operand_text.split(",")]
    if len(chunks) < len(roles):
        if "," not in operand_text and len(operand_text.split()) > 1:
            raise _AssemblyError(
                line,
                f"Faltan las comas entre los operandos de '{mnemonic}'.",
            )
        raise _AssemblyError(
            line,
            f"Faltan operandos para '{mnemonic}': se esperaban {len(roles)}.",
        )
    if len(chunks) > len(roles):
        raise _AssemblyError(
            line,
            f"La forma de operandos de '{mnemonic}' no es válida; "
            f"se esperaban {len(roles)} operandos.",
        )
    operands: list[str] = []
    for position, (role, chunk) in enumerate(zip(roles, chunks), start=1):
        if not chunk:
            raise _AssemblyError(line, f"El operando {position} de '{mnemonic}' está vacío.")
        if role == "mem":
            operands.append(_normalize_memory(chunk, line))
        elif any(character.isspace() for character in chunk):
            raise _AssemblyError(
                line,
                f"El operando '{chunk}' no es un token válido: no se admiten espacios internos.",
            )
        else:
            operands.append(chunk)
    return operands


def _normalize_memory(token: str, line: int) -> str:
    """Normaliza un operando de memoria a la forma ``offset(base)``."""
    match = _MEMORY_PATTERN.fullmatch(token)
    if match is not None:
        return f"{match.group(1)}({match.group(2)})"
    if token.startswith("("):
        raise _AssemblyError(
            line,
            "Falta el offset explícito en el operando de memoria; "
            "se requiere la forma offset(base).",
        )
    raise _AssemblyError(
        line,
        f"El operando de memoria '{token}' no tiene la forma offset(base).",
    )


def _assign_addresses(
    records: list[SourceRecord],
) -> tuple[list[LocatedInstruction], dict[str, LabelDefinition]]:
    """Asigna direcciones contiguas y construye la tabla de etiquetas."""
    instructions: list[LocatedInstruction] = []
    labels: dict[str, LabelDefinition] = {}
    pc = 0
    for record in records:
        if record.label is not None:
            previous = labels.get(record.label)
            if previous is not None:
                raise _AssemblyError(
                    record.line,
                    f"La etiqueta '{record.label}' ya fue definida en la línea {previous.line}.",
                )
            labels[record.label] = LabelDefinition(pc, record.line)
        if record.mnemonic is not None:
            instructions.append(
                LocatedInstruction(record.line, pc, record.mnemonic, list(record.operands))
            )
            pc += 4
    return instructions, labels


def _parse_register(token: str, line: int) -> int:
    """Convierte un nombre o alias de registro en su índice."""
    index = _REGISTERS.get(token)
    if index is not None:
        return index
    match = _REGISTER_PATTERN.fullmatch(token)
    if match is not None:
        digits = token[1:]
        if digits.startswith("0") and digits != "0":
            raise _AssemblyError(
                line,
                f"El nombre de registro '{_abbreviate(token)}' no es válido: "
                "no se admiten ceros iniciales.",
            )
        if len(digits) > 2 or int(digits) > 31:
            raise _AssemblyError(
                line,
                f"El registro '{_abbreviate(token)}' no existe; se admiten x0 a x31 y sus alias.",
            )
        raise _AssemblyError(
            line,
            f"El registro '{_abbreviate(token)}' debe escribirse en minúsculas.",
        )
    raise _AssemblyError(
        line,
        f"El operando '{_abbreviate(token)}' no identifica un registro admitido.",
    )


def _parse_literal(token: str, line: int) -> int:
    """Convierte un literal decimal, hexadecimal o binario en un entero."""
    match = _LITERAL_PATTERN.fullmatch(token)
    if match is None:
        raise _AssemblyError(
            line,
            f"El operando '{_abbreviate(token)}' no es un literal admitido.",
        )
    body = token.lstrip("+-")
    prefix = body[:2].lower()
    if prefix == "0x":
        digits = body[2:].lstrip("0")
        base = 16
    elif prefix == "0b":
        digits = body[2:].lstrip("0")
        base = 2
    else:
        digits = body.lstrip("0")
        base = 10
    if not digits:
        return 0
    if len(digits) > _MAX_LITERAL_DIGITS[base]:
        raise _AssemblyError(
            line,
            f"El operando '{_abbreviate(token)}' excede el rango de los valores admitidos.",
        )
    value = int(digits, base)
    return -value if token.startswith("-") else value


def _split_memory(token: str) -> tuple[str, str]:
    """Separa el offset y la base de un operando ya normalizado."""
    offset, _, base = token.partition("(")
    return offset, base[:-1]


def _check_immediate(instruction: LocatedInstruction, value: int, subject: str) -> None:
    """Comprueba rango y paridad del inmediato según la instrucción."""
    if instruction.mnemonic in ("beq", "bne"):
        low, high = -4096, 4094
    elif instruction.mnemonic == "jal":
        low, high = -1048576, 1048574
    else:
        low, high = -2048, 2047
    if not low <= value <= high:
        raise _AssemblyError(
            instruction.line,
            f"{subject} {value} de '{instruction.mnemonic}' está fuera "
            f"del rango permitido [{low}, {high}].",
        )
    if instruction.mnemonic in ("beq", "bne", "jal") and value % 2 != 0:
        raise _AssemblyError(
            instruction.line,
            f"{subject} {value} de '{instruction.mnemonic}' debe ser par para codificarse.",
        )


def _parse_destination(
    token: str, instruction: LocatedInstruction, labels: dict[str, LabelDefinition]
) -> int:
    """Resuelve un destino literal o una etiqueta a un desplazamiento."""
    if _LITERAL_PATTERN.fullmatch(token):
        return _parse_literal(token, instruction.line)
    if _LABEL_PATTERN.fullmatch(token):
        definition = labels.get(token)
        if definition is None:
            raise _AssemblyError(instruction.line, f"La etiqueta '{token}' no está definida.")
        return definition.address - instruction.pc
    raise _AssemblyError(
        instruction.line,
        f"El destino '{token}' no es una etiqueta ni un desplazamiento literal.",
    )


def _interpret_operands(
    instructions: list[LocatedInstruction], labels: dict[str, LabelDefinition]
) -> list[InterpretedInstruction]:
    """Convierte registros, literales y destinos a valores comprobados."""
    interpreted: list[InterpretedInstruction] = []
    for instruction in instructions:
        roles = _INSTRUCTIONS[instruction.mnemonic][4]
        rd: int | None = None
        rs1: int | None = None
        rs2: int | None = None
        imm: int | None = None
        for role, token in zip(roles, instruction.operands):
            if role == "rd":
                rd = _parse_register(token, instruction.line)
            elif role == "rs1":
                rs1 = _parse_register(token, instruction.line)
            elif role == "rs2":
                rs2 = _parse_register(token, instruction.line)
            elif role == "imm12":
                imm = _parse_literal(token, instruction.line)
                _check_immediate(instruction, imm, "El inmediato")
            elif role == "shamt":
                imm = _parse_literal(token, instruction.line)
                if not 0 <= imm <= 31:
                    raise _AssemblyError(
                        instruction.line,
                        f"La cantidad de desplazamiento {imm} de "
                        f"'{instruction.mnemonic}' está fuera del rango "
                        "permitido [0, 31].",
                    )
            elif role == "imm20":
                imm = _parse_literal(token, instruction.line)
                if not 0 <= imm <= 0xFFFFF:
                    raise _AssemblyError(
                        instruction.line,
                        f"El campo U {imm} de '{instruction.mnemonic}' está "
                        "fuera del rango permitido [0, 1048575].",
                    )
            elif role == "mem":
                offset_token, base_token = _split_memory(token)
                imm = _parse_literal(offset_token, instruction.line)
                _check_immediate(instruction, imm, "El inmediato")
                rs1 = _parse_register(base_token, instruction.line)
            elif role == "dest":
                imm = _parse_destination(token, instruction, labels)
                _check_immediate(instruction, imm, "El desplazamiento")
        interpreted.append(
            InterpretedInstruction(
                instruction.line,
                instruction.pc,
                instruction.mnemonic,
                rd,
                rs1,
                rs2,
                imm,
            )
        )
    return interpreted


def _encode_instructions(
    instructions: list[InterpretedInstruction],
) -> list[EncodedInstruction]:
    """Forma la palabra de 32 bits de cada instrucción interpretada."""
    encoded: list[EncodedInstruction] = []
    for instruction in instructions:
        format_name, opcode, funct3, funct7, _ = _INSTRUCTIONS[instruction.mnemonic]
        if format_name == "HALT":
            word = 0x0000000B
        elif format_name == "R":
            word = (
                (funct7 << 25)
                | (instruction.rs2 << 20)
                | (instruction.rs1 << 15)
                | (funct3 << 12)
                | (instruction.rd << 7)
                | opcode
            )
        elif format_name == "I":
            immediate = instruction.imm & 0xFFF
            word = (
                (immediate << 20)
                | (instruction.rs1 << 15)
                | (funct3 << 12)
                | (instruction.rd << 7)
                | opcode
            )
        elif format_name == "SHIFT":
            immediate = (funct7 << 5) | instruction.imm
            word = (
                (immediate << 20)
                | (instruction.rs1 << 15)
                | (funct3 << 12)
                | (instruction.rd << 7)
                | opcode
            )
        elif format_name == "S":
            immediate = instruction.imm & 0xFFF
            word = (
                (((immediate >> 5) & 0x7F) << 25)
                | (instruction.rs2 << 20)
                | (instruction.rs1 << 15)
                | (funct3 << 12)
                | ((immediate & 0x1F) << 7)
                | opcode
            )
        elif format_name == "B":
            immediate = instruction.imm & 0x1FFF
            word = (
                (((immediate >> 12) & 0x1) << 31)
                | (((immediate >> 5) & 0x3F) << 25)
                | (instruction.rs2 << 20)
                | (instruction.rs1 << 15)
                | (funct3 << 12)
                | (((immediate >> 1) & 0xF) << 8)
                | (((immediate >> 11) & 0x1) << 7)
                | opcode
            )
        elif format_name == "U":
            word = (instruction.imm << 12) | (instruction.rd << 7) | opcode
        elif format_name == "J":
            immediate = instruction.imm & 0x1FFFFF
            word = (
                (((immediate >> 20) & 0x1) << 31)
                | (((immediate >> 1) & 0x3FF) << 21)
                | (((immediate >> 11) & 0x1) << 20)
                | (((immediate >> 12) & 0xFF) << 12)
                | (instruction.rd << 7)
                | opcode
            )
        else:
            raise ValueError(f"Formato desconocido: {format_name}")
        encoded.append(EncodedInstruction(instruction.line, instruction.pc, word))
    return encoded


def _pack_result(instructions: list[EncodedInstruction]) -> AssemblyResult:
    """Forma la imagen little-endian y la relación PC-línea."""
    image = b"".join(instruction.word.to_bytes(4, "little") for instruction in instructions)
    pc_to_line = {instruction.pc: instruction.line for instruction in instructions}
    return AssemblyResult(image, pc_to_line, None)


def assemble(source_text: str) -> AssemblyResult:
    """Traduce un programa del lenguaje del TP3 a bytes little-endian."""
    try:
        records = _read_source(source_text)
        instructions, labels = _assign_addresses(records)
        interpreted = _interpret_operands(instructions, labels)
        encoded = _encode_instructions(interpreted)
        return _pack_result(encoded)
    except _AssemblyError as error:
        return AssemblyResult(None, {}, error.diagnostic)
