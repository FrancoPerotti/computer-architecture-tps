"""Catálogo de pruebas del assembler (TEST-ASM-001 a TEST-ASM-008).

Verifica la operación pública ``assemble`` contra las expectativas
independientes de ``tp3/docs/software/assembler_tests.md``. Los bytes y mapas
esperados son constantes del catálogo; no se calculan con las tablas ni con el
encoder del producto.
"""

import unittest

from software.assembler import AssemblyDiagnostic, assemble


def _attach(test_class, case_id, test_method):
    name = "test_" + case_id.replace("-", "_").replace("/", "_")
    setattr(test_class, name, test_method)


def _success_case(source, image_hex, pc_to_line):
    def test(self):
        self.assert_success(source, image_hex, pc_to_line)

    return test


def _rejection_case(source, line, fragments):
    def test(self):
        self.assert_rejected(source, line, fragments)

    return test


class _CatalogCase(unittest.TestCase):
    def assert_success(self, source, image_hex, pc_to_line):
        self.assert_success_result(assemble(source), image_hex, pc_to_line)

    def assert_success_result(self, result, image_hex, pc_to_line):
        self.assertIsNone(result.error, msg=result.error)
        self.assertEqual(result.pc_to_line, pc_to_line)
        self.assertIsInstance(result.image, bytes)
        self.assertEqual(result.image, bytes.fromhex(image_hex))

    def assert_rejected(self, source, line, fragments):
        result = assemble(source)
        self.assertIsNone(result.image)
        self.assertEqual(result.pc_to_line, {})
        self.assertIsInstance(result.error, AssemblyDiagnostic)
        self.assertEqual(result.error.line, line)
        message = result.error.message.lower()
        for fragment in fragments:
            self.assertIn(fragment.lower(), message)


_TEST_ASM_001 = [
    ("TEST-ASM-001/C001", "add x3, x1, x2", "B3 81 20 00"),
    ("TEST-ASM-001/C002", "sub x3, x1, x2", "B3 81 20 40"),
    ("TEST-ASM-001/C003", "sll x3, x1, x2", "B3 91 20 00"),
    ("TEST-ASM-001/C004", "slt x3, x1, x2", "B3 A1 20 00"),
    ("TEST-ASM-001/C005", "sltu x3, x1, x2", "B3 B1 20 00"),
    ("TEST-ASM-001/C006", "xor x3, x1, x2", "B3 C1 20 00"),
    ("TEST-ASM-001/C007", "srl x3, x1, x2", "B3 D1 20 00"),
    ("TEST-ASM-001/C008", "sra x3, x1, x2", "B3 D1 20 40"),
    ("TEST-ASM-001/C009", "or x3, x1, x2", "B3 E1 20 00"),
    ("TEST-ASM-001/C010", "and x3, x1, x2", "B3 F1 20 00"),
    ("TEST-ASM-001/C011", "addi x3, x1, -1", "93 81 F0 FF"),
    ("TEST-ASM-001/C012", "slti x3, x1, -1", "93 A1 F0 FF"),
    ("TEST-ASM-001/C013", "sltiu x3, x1, -1", "93 B1 F0 FF"),
    ("TEST-ASM-001/C014", "xori x3, x1, -1", "93 C1 F0 FF"),
    ("TEST-ASM-001/C015", "ori x3, x1, -1", "93 E1 F0 FF"),
    ("TEST-ASM-001/C016", "andi x3, x1, -1", "93 F1 F0 FF"),
    ("TEST-ASM-001/C017", "slli x3, x2, 31", "93 11 F1 01"),
    ("TEST-ASM-001/C018", "srli x3, x2, 31", "93 51 F1 01"),
    ("TEST-ASM-001/C019", "srai x3, x2, 31", "93 51 F1 41"),
    ("TEST-ASM-001/C020", "lb x3, -4(x2)", "83 01 C1 FF"),
    ("TEST-ASM-001/C021", "lh x3, -4(x2)", "83 11 C1 FF"),
    ("TEST-ASM-001/C022", "lw x3, -4(x2)", "83 21 C1 FF"),
    ("TEST-ASM-001/C023", "lbu x3, -4(x2)", "83 41 C1 FF"),
    ("TEST-ASM-001/C024", "lhu x3, -4(x2)", "83 51 C1 FF"),
    ("TEST-ASM-001/C025", "sb x5, -4(x2)", "23 0E 51 FE"),
    ("TEST-ASM-001/C026", "sh x5, -4(x2)", "23 1E 51 FE"),
    ("TEST-ASM-001/C027", "sw x5, -4(x2)", "23 2E 51 FE"),
    ("TEST-ASM-001/C028", "beq x1, x2, 8", "63 84 20 00"),
    ("TEST-ASM-001/C029", "bne x1, x0, -4", "E3 9E 00 FE"),
    ("TEST-ASM-001/C030", "jal x1, 8", "EF 00 80 00"),
    ("TEST-ASM-001/C031", "jalr x0, 1(x1)", "67 80 10 00"),
    ("TEST-ASM-001/C032", "lui x2, 0x12345", "37 51 34 12"),
    ("TEST-ASM-001/C033", "halt", "0B 00 00 00"),
]

_TEST_ASM_002 = [
    (
        "TEST-ASM-002/C001",
        "# Contador\n\ninicio:\n"
        "addi x1, x0, 3\n"
        "ciclo: addi x1, x1, -1\n"
        "bne x1, x0, ciclo\n"
        "jal x0, fin\n"
        "addi x2, x0, 99\n"
        "fin: halt",
        "93 00 30 00 93 80 F0 FF E3 9E 00 FE "
        "6F 00 80 00 13 01 30 06 0B 00 00 00",
        {0: 4, 4: 5, 8: 6, 12: 7, 16: 8, 20: 9},
    ),
    (
        "TEST-ASM-002/C002",
        "Inicio:\nentrada:\naddi x2, x0, 1\njal x0, Inicio\nhalt",
        "13 01 10 00 6F F0 DF FF 0B 00 00 00",
        {0: 3, 4: 4, 8: 5},
    ),
    (
        "TEST-ASM-002/C003",
        "jal x0, fin\nhalt\naddi x2, x0, 1\nfin:",
        "6F 00 C0 00 0B 00 00 00 13 01 10 00",
        {0: 1, 4: 2, 8: 3},
    ),
    (
        "TEST-ASM-002/C004",
        "addi x1, x0, 0\njal x0, 8\nhalt",
        "93 00 00 00 6F 00 80 00 0B 00 00 00",
        {0: 1, 4: 2, 8: 3},
    ),
]

_TEST_ASM_003_TEXT = (
    "# Inicialización\n"
    "\n"
    "inicio : addi x1 , x0 , 5 # acción: , ( )\n"
    "\tsw x1 , 4 ( x0 )\n"
    "\thalt"
)

_TEST_ASM_003 = [
    (
        "TEST-ASM-003/C001",
        _TEST_ASM_003_TEXT,
        "93 00 50 00 23 22 10 00 0B 00 00 00",
        {0: 3, 4: 4, 8: 5},
    ),
    (
        "TEST-ASM-003/C002",
        "\ufeff" + _TEST_ASM_003_TEXT.replace("\n", "\r\n"),
        "93 00 50 00 23 22 10 00 0B 00 00 00",
        {0: 3, 4: 4, 8: 5},
    ),
    (
        "TEST-ASM-003/C003",
        "addi x1, x0, 012\n"
        "addi x1, x0, +12\n"
        "addi x1, x0, 0Xc\n"
        "addi x1, x0, +0B1100\n"
        "addi x1, x0, -0x1\n"
        "addi x1, x0, -0b1",
        "93 00 C0 00 93 00 C0 00 93 00 C0 00 "
        "93 00 C0 00 93 00 F0 FF 93 00 F0 FF",
        {0: 1, 4: 2, 8: 3, 12: 4, 16: 5, 20: 6},
    ),
    (
        "TEST-ASM-003/C004",
        "add t0, ra, sp\n"
        "add gp, tp, t6\n"
        "add s0, s11, a0\n"
        "add fp, a7, zero\n"
        "add x31, x30, x29",
        "B3 82 20 00 B3 01 F2 01 33 84 AD 00 "
        "33 84 08 00 B3 0F DF 01",
        {0: 1, 4: 2, 8: 3, 12: 4, 16: 5},
    ),
]

_TEST_ASM_004_VALID = [
    ("TEST-ASM-004/C001", "addi x1, x0, -2048", "93 00 00 80"),
    ("TEST-ASM-004/C002", "addi x1, x0, 2047", "93 00 F0 7F"),
    ("TEST-ASM-004/C003", "sw x5, -2048(x2)", "23 20 51 80"),
    ("TEST-ASM-004/C004", "sw x5, 2047(x2)", "A3 2F 51 7E"),
    ("TEST-ASM-004/C005", "slli x1, x2, 0", "93 10 01 00"),
    ("TEST-ASM-004/C006", "lui x1, 0", "B7 00 00 00"),
    ("TEST-ASM-004/C007", "lui x1, 0xfffff", "B7 F0 FF FF"),
    ("TEST-ASM-004/C008", "beq x1, x2, -4096", "63 80 20 80"),
    ("TEST-ASM-004/C009", "beq x1, x2, 4094", "E3 8F 20 7E"),
    ("TEST-ASM-004/C010", "jal x1, -1048576", "EF 00 00 80"),
    ("TEST-ASM-004/C011", "jal x1, 1048574", "EF F0 FF 7F"),
]

_TEST_ASM_004_INVALID = [
    ("TEST-ASM-004/C012", "addi x1, x0, -2049", 1, ("-2049",)),
    ("TEST-ASM-004/C013", "addi x1, x0, 2048", 1, ("2048",)),
    ("TEST-ASM-004/C014", "sw x5, -2049(x2)", 1, ("-2049",)),
    ("TEST-ASM-004/C015", "sw x5, 2048(x2)", 1, ("2048",)),
    ("TEST-ASM-004/C016", "slli x1, x2, -1", 1, ("-1",)),
    ("TEST-ASM-004/C017", "slli x1, x2, 32", 1, ("32",)),
    ("TEST-ASM-004/C018", "lui x1, -1", 1, ("-1",)),
    ("TEST-ASM-004/C019", "lui x1, 0x100000", 1, ("1048576",)),
    ("TEST-ASM-004/C020", "beq x1, x2, -4098", 1, ("-4098",)),
    ("TEST-ASM-004/C021", "beq x1, x2, 4096", 1, ("4096",)),
    ("TEST-ASM-004/C022", "beq x1, x2, 3", 1, ("3", "par")),
    ("TEST-ASM-004/C023", "jal x1, -1048578", 1, ("-1048578",)),
    ("TEST-ASM-004/C024", "jal x1, 1048576", 1, ("1048576",)),
    ("TEST-ASM-004/C025", "jal x1, 1", 1, ("par",)),
    ("TEST-ASM-004/C026", "lw x1, 2048(x2)", 1, ("2048",)),
    ("TEST-ASM-004/C027", "jalr x0, -2049(x1)", 1, ("-2049",)),
    ("TEST-ASM-004/C028", "andi x1, x0, 0xfff", 1, ("4095",)),
]

_TEST_ASM_005 = [
    ("TEST-ASM-005/C001", "add x1 x2 x3", 1, ("comas",)),
    ("TEST-ASM-005/C002", "add x1, x2", 1, ("faltan operandos",)),
    ("TEST-ASM-005/C003", "halt x1", 1, ("halt",)),
    ("TEST-ASM-005/C004", "lw x1, (x2)", 1, ("offset",)),
    ("TEST-ASM-005/C005", "jalr x1, x2, 0", 1, ("forma de operandos",)),
    ("TEST-ASM-005/C006", "nop", 1, ("nop",)),
    ("TEST-ASM-005/C007", "mul x1, x2, x3", 1, ("mul",)),
    ("TEST-ASM-005/C008", ".word 0", 1, ("directiva",)),
    ("TEST-ASM-005/C009", "add x32, x1, x2", 1, ("x32",)),
    ("TEST-ASM-005/C010", "add x01, x1, x2", 1, ("x01",)),
    ("TEST-ASM-005/C011", "addi x1, x0, 0xGG", 1, ("0xGG",)),
    ("TEST-ASM-005/C012", "addi x1, x0, 4+8", 1, ("4+8",)),
    ("TEST-ASM-005/C013", "jal x0, Fin\nfin: halt", 1, ("Fin",)),
    ("TEST-ASM-005/C014", "fin: halt\nfin: halt", 2, ("fin", "línea 1")),
    ("TEST-ASM-005/C015", "x1: halt", 1, ("reservado",)),
    ("TEST-ASM-005/C016", "fin: halt\naddi x1, x0, fin", 2, ("fin",)),
    ("TEST-ASM-005/C017", "ADD x1, x2, x3", 1, ("minúsculas",)),
    ("TEST-ASM-005/C018", "add X1, x2, x3", 1, ("minúsculas",)),
    ("TEST-ASM-005/C019", "uno: dos: halt", 1, ("segunda",)),
    ("TEST-ASM-005/C020", "addi x1, x0, - 1", 1, ("espacios",)),
    ("TEST-ASM-005/C021", "1fin: halt", 1, ("identificador",)),
]

_TEST_ASM_006 = [
    ("TEST-ASM-006/C001", "", "", {}),
    ("TEST-ASM-006/C002", "# Sin instrucciones\ninicio:", "", {}),
    ("TEST-ASM-006/C003", "sw x1, 1(x0)", "A3 20 10 00", {0: 1}),
    ("TEST-ASM-006/C004", "jal x0, 2", "6F 00 20 00", {0: 1}),
    ("TEST-ASM-006/C005", "lw x1, -4(x0)", "83 20 C0 FF", {0: 1}),
    ("TEST-ASM-006/C006", "jalr x0, 1(x0)", "67 00 10 00", {0: 1}),
]

_TEST_ASM_007 = [
    (
        "TEST-ASM-007/C001",
        "# Inicialización\naddi x1, x0, 5\n\naddi x2, x0, 2048\nhalt",
        4,
        ("2048",),
    ),
    ("TEST-ASM-007/C002", "addi x1, x0, 2048\nnop", 2, ("nop",)),
    ("TEST-ASM-007/C003", "addi x1, x0, 2048\nhalt", 1, ("2048",)),
]


class TestAsm001(_CatalogCase):
    """TEST-ASM-001 — codificaciones del subconjunto."""


class TestAsm002(_CatalogCase):
    """TEST-ASM-002 — etiquetas, direcciones y mapa."""


class TestAsm003(_CatalogCase):
    """TEST-ASM-003 — escritura admitida."""


class TestAsm004(_CatalogCase):
    """TEST-ASM-004 — límites de inmediatos."""


class TestAsm005(_CatalogCase):
    """TEST-ASM-005 — errores habituales del lenguaje."""


class TestAsm006(_CatalogCase):
    """TEST-ASM-006 — traducción y ejecución."""

    def test_TEST_ASM_006_C007(self):
        source = "\n".join(["addi x1, x1, 1"] * 256 + ["halt"])
        self.assert_success(
            source,
            "93 80 10 00 " * 256 + "0B 00 00 00",
            {4 * index: index + 1 for index in range(257)},
        )


class TestAsm007(_CatalogCase):
    """TEST-ASM-007 — diagnósticos y descarte de parciales."""


class TestAsm008(_CatalogCase):
    """TEST-ASM-008 — independencia entre llamadas."""

    def test_TEST_ASM_008_C001(self):
        first = assemble("inicio: halt")
        self.assert_success_result(first, "0B 00 00 00", {0: 1})

        second = assemble("jal x0, inicio")
        self.assertIsNone(second.image)
        self.assertEqual(second.pc_to_line, {})
        self.assertIsInstance(second.error, AssemblyDiagnostic)
        self.assertEqual(second.error.line, 1)
        self.assertIn("inicio", second.error.message.lower())

        third = assemble("inicio: addi x1, x0, 5\nhalt")
        self.assert_success_result(
            third, "93 00 50 00 0B 00 00 00", {0: 1, 4: 2}
        )

        self.assert_success_result(first, "0B 00 00 00", {0: 1})


class TestCatalogCoverage(unittest.TestCase):
    """Comprueba la cantidad de variantes aprobada por grupo."""

    def test_catalog_counts(self):
        counts = {
            "TEST-ASM-001": len(_TEST_ASM_001),
            "TEST-ASM-002": len(_TEST_ASM_002),
            "TEST-ASM-003": len(_TEST_ASM_003),
            "TEST-ASM-004": len(_TEST_ASM_004_VALID) + len(_TEST_ASM_004_INVALID),
            "TEST-ASM-005": len(_TEST_ASM_005),
            "TEST-ASM-006": len(_TEST_ASM_006) + 1,
            "TEST-ASM-007": len(_TEST_ASM_007),
            "TEST-ASM-008": 1,
        }
        self.assertEqual(
            counts,
            {
                "TEST-ASM-001": 33,
                "TEST-ASM-002": 4,
                "TEST-ASM-003": 4,
                "TEST-ASM-004": 28,
                "TEST-ASM-005": 21,
                "TEST-ASM-006": 7,
                "TEST-ASM-007": 3,
                "TEST-ASM-008": 1,
            },
        )
        self.assertEqual(sum(counts.values()), 101)


for _case_id, _source, _image in _TEST_ASM_001:
    _attach(TestAsm001, _case_id, _success_case(_source, _image, {0: 1}))

for _case_id, _source, _image, _map in _TEST_ASM_002:
    _attach(TestAsm002, _case_id, _success_case(_source, _image, _map))

for _case_id, _source, _image, _map in _TEST_ASM_003:
    _attach(TestAsm003, _case_id, _success_case(_source, _image, _map))

for _case_id, _source, _image in _TEST_ASM_004_VALID:
    _attach(TestAsm004, _case_id, _success_case(_source, _image, {0: 1}))

for _case_id, _source, _line, _fragments in _TEST_ASM_004_INVALID:
    _attach(TestAsm004, _case_id, _rejection_case(_source, _line, _fragments))

for _case_id, _source, _line, _fragments in _TEST_ASM_005:
    _attach(TestAsm005, _case_id, _rejection_case(_source, _line, _fragments))

for _case_id, _source, _image, _map in _TEST_ASM_006:
    _attach(TestAsm006, _case_id, _success_case(_source, _image, _map))

for _case_id, _source, _line, _fragments in _TEST_ASM_007:
    _attach(TestAsm007, _case_id, _rejection_case(_source, _line, _fragments))

if __name__ == "__main__":
    unittest.main()
