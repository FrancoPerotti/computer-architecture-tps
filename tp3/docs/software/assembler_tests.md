# Pruebas del assembler

- **Tipo:** catálogo de verificación de software.
- **Estado documental:** catálogo aprobado; pruebas diseñadas, sin implementar ni ejecutar.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Expectativas independientes](#expectativas-independientes)
- [Convenciones de comparación](#convenciones-de-comparación)
- [TEST-ASM-001 — Codificaciones del subconjunto](#test-asm-001)
- [TEST-ASM-002 — Etiquetas, direcciones y mapa](#test-asm-002)
- [TEST-ASM-003 — Escritura admitida](#test-asm-003)
- [TEST-ASM-004 — Límites de inmediatos](#test-asm-004)
- [TEST-ASM-005 — Errores habituales del lenguaje](#test-asm-005)
- [TEST-ASM-006 — Traducción y ejecución](#test-asm-006)
- [TEST-ASM-007 — Diagnósticos y descarte de parciales](#test-asm-007)
- [TEST-ASM-008 — Independencia entre llamadas](#test-asm-008)
- [Cobertura y condición de aprobación](#cobertura-y-condición-de-aprobación)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

El catálogo verifica la traducción mediante la operación pública `assemble`: código fuente de entrada, bytes de salida, mapa PC–línea y diagnósticos. Cada caso detecta un incumplimiento concreto del lenguaje o de la interfaz.

La selección comprende 101 variantes en ocho grupos:

| Grupo          | Variantes | Motivo                                                                                                  |
|----------------|----------:|---------------------------------------------------------------------------------------------------------|
| `TEST-ASM-001` |        33 | Una codificación por cada instrucción soportada, incluido `halt`.                                       |
| `TEST-ASM-002` |         4 | Destinos adelantados y anteriores, etiquetas aisladas, final de imagen y PC–línea.                      |
| `TEST-ASM-003` |         4 | Espacios, comentarios, finales de línea, bases numéricas y alias habituales.                            |
| `TEST-ASM-004` |        28 | Once extremos válidos y diecisiete rechazos de rango o paridad.                                         |
| `TEST-ASM-005` |        21 | Errores de escritura y construcciones fuera del lenguaje.                                               |
| `TEST-ASM-006` |         7 | Entrada vacía, operandos ensamblables que requieren comprobación en CPU y capacidad ajena al assembler. |
| `TEST-ASM-007` |         3 | Línea del diagnóstico, descarte de parciales y orden de detección.                                      |
| `TEST-ASM-008` |         1 | Colecciones y símbolos independientes entre llamadas.                                                   |

Los IDs completos tienen la forma `TEST-ASM-NNN/Cnnn`. Las tablas y programas de este documento enumeran la selección completa de software. La cantidad no representa combinaciones de todos los registros, inmediatos, alias y formatos.

Las pruebas observan el resultado público, por lo que una reorganización de funciones puede conservarlas. No se agregan pruebas de constructores de dataclasses, llamadas a funciones privadas, mocks del encoder, fuzzing, rendimiento, agotamiento de recursos ni entradas de Python ajenas al contrato `str`. La ejecución del programa, UART y la aceptación FPGA pertenecen a sus catálogos.

## Expectativas independientes

Las palabras y bytes esperados son constantes de las tablas, obtenidas de los campos de RV32I y del contrato exacto de `halt`. Las direcciones y mapas se fijan contando las instrucciones y las líneas de los programas del catálogo.

La regresión no utiliza tablas, validadores, encoder ni empaquetador del assembler para construir sus expectativas. Tampoco utiliza el decoder de la CPU para decidir qué palabra aceptar. Comprobar únicamente que una salida se pueda decodificar o que dos entradas produzcan la misma salida no sustituye la comparación con los valores fijos.

Los campos RV32I se contrastan con las [definiciones oficiales RV-I](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i) y los [shifts RV32-I](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv32_i), conservando User-Level ISA V2.2 según [DEC-SYS-010](../decisions/DEC-SYS-010.md). `halt` se contrasta directamente con [DEC-SYS-001](../decisions/DEC-SYS-001.md).

**Revisión documental de constantes — 2026-10-14:** las palabras y bytes RV32I utilizados se contrastaron con el assembler integrado de Clang 23.1.1 disponible en el entorno, usando `--target=riscv32-unknown-elf -march=rv32i -mabi=ilp32`, con instrucciones comprimidas y relajación deshabilitadas. Se extrajeron los bytes de `.text` sin relocaciones pendientes. Para etiquetas y formas propias de los literales se utilizaron instrucciones equivalentes con los operandos resueltos conforme al catálogo. Esta comprobación revisa los datos esperados; no ejecuta pruebas del assembler del proyecto ni agrega Clang como dependencia de su regresión.

## Convenciones de comparación

Cada variante parte de una llamada con el texto indicado. Los programas comienzan en PC cero; las líneas se cuentan desde uno. Salvo indicación contraria, el texto usa LF. En las tablas compactas de errores, `\n` representa un salto de línea real del texto recibido.

Las columnas `word` utilizan hexadecimal con prefijo; los grupos de dos dígitos representan bytes hexadecimales en orden de imagen. El programa contiene esos valores binarios, no los caracteres del volcado.

**Éxito:** comparar `image` byte por byte con la secuencia fija, `pc_to_line` con el mapa indicado y `error` con `None`. Una longitud correcta, por sí sola, no acredita la codificación. Las variantes de una sola instrucción esperan exactamente cuatro bytes y `{0: 1}`; no se agrega `halt`.

**Rechazo:** exigir `image=None`, `pc_to_line={}`, un único `AssemblyDiagnostic`, la línea indicada y un mensaje que identifique el token o valor problemático y el motivo de su tabla. La redacción literal del mensaje permanece libre. La comparación automática del estado y línea se acompaña de la revisión de pertinencia del mensaje; un mensaje meramente no vacío no acredita esa parte del contrato.

Una prueba puede compartir el código que invoca `assemble` y compara resultados. Los bytes y mapas esperados se conservan como datos independientes; ese código compartido no calcula codificaciones a partir de las tablas de producción.

<a id="test-asm-001"></a>

## TEST-ASM-001 — Codificaciones del subconjunto

**Motivo:** detectar un opcode, selector, registro, inmediato o byte ubicado incorrectamente. Los registros distintos evitan ocultar intercambios de campos. Los inmediatos negativos ejercitan los bits altos y los shifts distinguen `srai` de `srli`.

Cada fila es una llamada independiente con una instrucción en la línea 1. El resultado esperado incluye `pc_to_line={0: 1}` y `error=None`.

| Variante | Código fuente      | `word`       | `image`       |
|----------|--------------------|--------------|---------------|
| C001     | `add x3, x1, x2`   | `0x002081b3` | `B3 81 20 00` |
| C002     | `sub x3, x1, x2`   | `0x402081b3` | `B3 81 20 40` |
| C003     | `sll x3, x1, x2`   | `0x002091b3` | `B3 91 20 00` |
| C004     | `slt x3, x1, x2`   | `0x0020a1b3` | `B3 A1 20 00` |
| C005     | `sltu x3, x1, x2`  | `0x0020b1b3` | `B3 B1 20 00` |
| C006     | `xor x3, x1, x2`   | `0x0020c1b3` | `B3 C1 20 00` |
| C007     | `srl x3, x1, x2`   | `0x0020d1b3` | `B3 D1 20 00` |
| C008     | `sra x3, x1, x2`   | `0x4020d1b3` | `B3 D1 20 40` |
| C009     | `or x3, x1, x2`    | `0x0020e1b3` | `B3 E1 20 00` |
| C010     | `and x3, x1, x2`   | `0x0020f1b3` | `B3 F1 20 00` |
| C011     | `addi x3, x1, -1`  | `0xfff08193` | `93 81 F0 FF` |
| C012     | `slti x3, x1, -1`  | `0xfff0a193` | `93 A1 F0 FF` |
| C013     | `sltiu x3, x1, -1` | `0xfff0b193` | `93 B1 F0 FF` |
| C014     | `xori x3, x1, -1`  | `0xfff0c193` | `93 C1 F0 FF` |
| C015     | `ori x3, x1, -1`   | `0xfff0e193` | `93 E1 F0 FF` |
| C016     | `andi x3, x1, -1`  | `0xfff0f193` | `93 F1 F0 FF` |
| C017     | `slli x3, x2, 31`  | `0x01f11193` | `93 11 F1 01` |
| C018     | `srli x3, x2, 31`  | `0x01f15193` | `93 51 F1 01` |
| C019     | `srai x3, x2, 31`  | `0x41f15193` | `93 51 F1 41` |
| C020     | `lb x3, -4(x2)`    | `0xffc10183` | `83 01 C1 FF` |
| C021     | `lh x3, -4(x2)`    | `0xffc11183` | `83 11 C1 FF` |
| C022     | `lw x3, -4(x2)`    | `0xffc12183` | `83 21 C1 FF` |
| C023     | `lbu x3, -4(x2)`   | `0xffc14183` | `83 41 C1 FF` |
| C024     | `lhu x3, -4(x2)`   | `0xffc15183` | `83 51 C1 FF` |
| C025     | `sb x5, -4(x2)`    | `0xfe510e23` | `23 0E 51 FE` |
| C026     | `sh x5, -4(x2)`    | `0xfe511e23` | `23 1E 51 FE` |
| C027     | `sw x5, -4(x2)`    | `0xfe512e23` | `23 2E 51 FE` |
| C028     | `beq x1, x2, 8`    | `0x00208463` | `63 84 20 00` |
| C029     | `bne x1, x0, -4`   | `0xfe009ee3` | `E3 9E 00 FE` |
| C030     | `jal x1, 8`        | `0x008000ef` | `EF 00 80 00` |
| C031     | `jalr x0, 1(x1)`   | `0x00108067` | `67 80 10 00` |
| C032     | `lui x2, 0x12345`  | `0x12345137` | `37 51 34 12` |
| C033     | `halt`             | `0x0000000b` | `0B 00 00 00` |

<a id="test-asm-002"></a>

## TEST-ASM-002 — Etiquetas, direcciones y mapa

**Motivo:** detectar etiquetas asociadas a otra instrucción, desplazamientos calculados desde PC+4, confusión entre bytes y palabras, y líneas de Debug desplazadas por comentarios o etiquetas.

### C001 — Referencias adelantadas y hacia atrás

```asm
# Contador

inicio:
addi x1, x0, 3
ciclo: addi x1, x1, -1
bne x1, x0, ciclo
jal x0, fin
addi x2, x0, 99
fin: halt
```

`ciclo` está en dirección 4 y `fin` en 20. Los desplazamientos son -4 desde PC 8 y 8 desde PC 12. La salida exacta es:

```text
image      = 93 00 30 00 93 80 F0 FF E3 9E 00 FE 6F 00 80 00 13 01 30 06 0B 00 00 00
pc_to_line = {0: 4, 4: 5, 8: 6, 12: 7, 16: 8, 20: 9}
error      = None
```

### C002 — Dos etiquetas en la misma dirección

```asm
Inicio:
entrada:
addi x2, x0, 1
jal x0, Inicio
halt
```

Ambas etiquetas tienen dirección cero; la definición y referencia a `Inicio` también comprueban un identificador con mayúscula. La salida es:

```text
image      = 13 01 10 00 6F F0 DF FF 0B 00 00 00
pc_to_line = {0: 3, 4: 4, 8: 5}
error      = None
```

### C003 — Etiqueta al final e instrucción después de halt

```asm
jal x0, fin
halt
addi x2, x0, 1
fin:
```

`fin` tiene dirección 12. La instrucción posterior a `halt` se conserva y la etiqueta no agrega bytes ni una entrada en PC 12:

```text
image      = 6F 00 C0 00 0B 00 00 00 13 01 10 00
pc_to_line = {0: 1, 4: 2, 8: 3}
error      = None
```

### C004 — Destino literal desde un PC distinto de cero

```asm
addi x1, x0, 0
jal x0, 8
halt
```

El literal 8 ya es un desplazamiento. La palabra de `jal` es `0x0080006f` aunque su PC sea 4:

```text
image      = 93 00 00 00 6F 00 80 00 0B 00 00 00
pc_to_line = {0: 1, 4: 2, 8: 3}
error      = None
```

<a id="test-asm-003"></a>

## TEST-ASM-003 — Escritura admitida

**Motivo:** comprobar formas habituales de escritura sin multiplicar combinaciones de espacios, registros y bases.

### C001 y C002 — Espacios, comentarios y finales de línea

C001 utiliza el texto siguiente con LF, una tabulación antes de `sw` y de `halt` y sin salto final:

```asm
# Inicialización

inicio : addi x1 , x0 , 5 # acción: , ( )
	sw x1 , 4 ( x0 )
	halt
```

Las tabulaciones son caracteres reales del texto recibido. C002 utiliza ese mismo texto precedido por U+FEFF y con todos sus saltos LF reemplazados por CRLF. Los espacios alrededor de los paréntesis del store conservan su offset y base. Ambas variantes esperan los mismos valores fijos:

```text
image      = 93 00 50 00 23 22 10 00 0B 00 00 00
pc_to_line = {0: 3, 4: 4, 8: 5}
error      = None
```

### C003 — Bases, signos y decimal con cero inicial

```asm
addi x1, x0, 012
addi x1, x0, +12
addi x1, x0, 0Xc
addi x1, x0, +0B1100
addi x1, x0, -0x1
addi x1, x0, -0b1
```

Las primeras cuatro instrucciones representan doce, incluidas `012` y las bases explícitas; las últimas dos representan -1:

```text
image      = 93 00 C0 00 93 00 C0 00 93 00 C0 00 93 00 C0 00 93 00 F0 FF 93 00 F0 FF
pc_to_line = {0: 1, 4: 2, 8: 3, 12: 4, 16: 5, 20: 6}
error      = None
```

### C004 — Alias y registros altos

```asm
add t0, ra, sp
add gp, tp, t6
add s0, s11, a0
add fp, a7, zero
add x31, x30, x29
```

La selección comprende nombres de las familias de alias y los extremos de registros. `s0` y `fp` corresponden ambos a x8. Se comparan las constantes, no solamente el resultado de traducir otra escritura equivalente:

```text
image      = B3 82 20 00 B3 01 F2 01 33 84 AD 00 33 84 08 00 B3 0F DF 01
pc_to_line = {0: 1, 4: 2, 8: 3, 12: 4, 16: 5}
error      = None
```

<a id="test-asm-004"></a>

## TEST-ASM-004 — Límites de inmediatos

**Motivo:** detectar errores de límite, truncamiento de valores inválidos, tratamiento unsigned de I y distribución de los extremos B/J. Los shifts con cantidad 31 ya están cubiertos por `TEST-ASM-001/C017–C019`.

Cada fila es una instrucción en la línea 1. Las variantes válidas esperan `{0: 1}` y `error=None`:

| Variante | Código fuente válido | `word`       | `image`       |
|----------|----------------------|--------------|---------------|
| C001     | `addi x1, x0, -2048` | `0x80000093` | `93 00 00 80` |
| C002     | `addi x1, x0, 2047`  | `0x7ff00093` | `93 00 F0 7F` |
| C003     | `sw x5, -2048(x2)`   | `0x80512023` | `23 20 51 80` |
| C004     | `sw x5, 2047(x2)`    | `0x7e512fa3` | `A3 2F 51 7E` |
| C005     | `slli x1, x2, 0`     | `0x00011093` | `93 10 01 00` |
| C006     | `lui x1, 0`          | `0x000000b7` | `B7 00 00 00` |
| C007     | `lui x1, 0xfffff`    | `0xfffff0b7` | `B7 F0 FF FF` |
| C008     | `beq x1, x2, -4096`  | `0x80208063` | `63 80 20 80` |
| C009     | `beq x1, x2, 4094`   | `0x7e208fe3` | `E3 8F 20 7E` |
| C010     | `jal x1, -1048576`   | `0x800000ef` | `EF 00 00 80` |
| C011     | `jal x1, 1048574`    | `0x7ffff0ef` | `EF F0 FF 7F` |

Las variantes siguientes esperan el resultado común de rechazo con `error.line=1`:

| Variante | Código fuente inválido | Motivo del diagnóstico                                          |
|----------|------------------------|-----------------------------------------------------------------|
| C012     | `addi x1, x0, -2049`   | Inmediato por debajo de -2048.                                  |
| C013     | `addi x1, x0, 2048`    | Inmediato por encima de 2047.                                   |
| C014     | `sw x5, -2049(x2)`     | Offset por debajo de -2048.                                     |
| C015     | `sw x5, 2048(x2)`      | Offset por encima de 2047.                                      |
| C016     | `slli x1, x2, -1`      | Cantidad de shift negativa.                                     |
| C017     | `slli x1, x2, 32`      | Cantidad de shift por encima de 31.                             |
| C018     | `lui x1, -1`           | Campo U negativo.                                               |
| C019     | `lui x1, 0x100000`     | Campo U por encima de `0xfffff`.                                |
| C020     | `beq x1, x2, -4098`    | Desplazamiento B por debajo de -4096.                           |
| C021     | `beq x1, x2, 4096`     | Desplazamiento B por encima de 4094.                            |
| C022     | `beq x1, x2, 3`        | Desplazamiento B impar.                                         |
| C023     | `jal x1, -1048578`     | Desplazamiento J por debajo de -1048576.                        |
| C024     | `jal x1, 1048576`      | Desplazamiento J por encima de 1048574.                         |
| C025     | `jal x1, 1`            | Desplazamiento J impar.                                         |
| C026     | `lw x1, 2048(x2)`      | Offset de load por encima de 2047.                              |
| C027     | `jalr x0, -2049(x1)`   | Offset de `jalr` por debajo de -2048.                           |
| C028     | `andi x1, x0, 0xfff`   | El literal es +4095 y no cabe en I; no se reinterpreta como -1. |

<a id="test-asm-005"></a>

## TEST-ASM-005 — Errores habituales del lenguaje

**Motivo:** rechazar equivocaciones de escritura y construcciones de otros assemblers con una línea y un motivo útiles. Cada variante utiliza solamente el problema indicado, para evitar depender de prioridades entre errores de la misma instrucción.

Cada fila espera `image=None`, `pc_to_line={}` y un diagnóstico pertinente:

| Variante | Texto de entrada              | Línea | Motivo del diagnóstico                                                       |
|----------|-------------------------------|------:|------------------------------------------------------------------------------|
| C001     | `add x1 x2 x3`                |     1 | Faltan comas entre operandos.                                                |
| C002     | `add x1, x2`                  |     1 | Falta un operando.                                                           |
| C003     | `halt x1`                     |     1 | `halt` no admite operandos.                                                  |
| C004     | `lw x1, (x2)`                 |     1 | Falta el offset explícito.                                                   |
| C005     | `jalr x1, x2, 0`              |     1 | Forma de operandos no admitida.                                              |
| C006     | `nop`                         |     1 | Pseudoinstrucción fuera del lenguaje.                                        |
| C007     | `mul x1, x2, x3`              |     1 | Instrucción fuera del subconjunto.                                           |
| C008     | `.word 0`                     |     1 | Directiva no admitida.                                                       |
| C009     | `add x32, x1, x2`             |     1 | Registro inexistente.                                                        |
| C010     | `add x01, x1, x2`             |     1 | Nombre de registro con cero inicial adicional.                               |
| C011     | `addi x1, x0, 0xGG`           |     1 | Literal hexadecimal inválido.                                                |
| C012     | `addi x1, x0, 4+8`            |     1 | Expresión no admitida como literal.                                          |
| C013     | `jal x0, Fin\nfin: halt`      |     1 | `Fin` no está definida; `fin` no satisface esa referencia.                   |
| C014     | `fin: halt\nfin: halt`        |     2 | Definición duplicada de `fin`; identificar la primera definición en línea 1. |
| C015     | `x1: halt`                    |     1 | Nombre reservado de registro usado como etiqueta.                            |
| C016     | `fin: halt\naddi x1, x0, fin` |     2 | El operando `fin` no es un inmediato literal admitido de `addi`.             |
| C017     | `ADD x1, x2, x3`              |     1 | Mnemónico que no respeta la escritura admitida.                              |
| C018     | `add X1, x2, x3`              |     1 | Nombre de registro que no respeta la escritura admitida.                     |
| C019     | `uno: dos: halt`              |     1 | Segunda definición de etiqueta en la misma línea.                            |
| C020     | `addi x1, x0, - 1`            |     1 | Token del inmediato dividido.                                                |
| C021     | `1fin: halt`                  |     1 | Identificador de etiqueta inválido.                                          |

<a id="test-asm-006"></a>

## TEST-ASM-006 — Traducción y ejecución

**Motivo:** conservar la responsabilidad acotada del assembler. La representabilidad de una instrucción, la validez de una carga y la ejecución son contratos diferentes.

| Variante | Entrada                        | `image` esperada | `pc_to_line` |
|----------|--------------------------------|------------------|--------------|
| C001     | Texto vacío `""`.              | `b""`            | `{}`         |
| C002     | `# Sin instrucciones\ninicio:` | `b""`            | `{}`         |
| C003     | `sw x1, 1(x0)`                 | `A3 20 10 00`    | `{0: 1}`     |
| C004     | `jal x0, 2`                    | `6F 00 20 00`    | `{0: 1}`     |
| C005     | `lw x1, -4(x0)`                | `83 20 C0 FF`    | `{0: 1}`     |
| C006     | `jalr x0, 1(x0)`               | `67 00 10 00`    | `{0: 1}`     |

Todas esas variantes esperan `error=None`. No se agrega terminación ni se rechaza la entrada vacía. El store desalineado, el destino de `jal` y el acceso de load se comprueban al ejecutar; `jalr` conserva su offset impar para la regla arquitectónica de limpieza del bit cero. Estas pruebas no requieren ejecutar el programa ni observar un snapshot.

### C007 — Programa que supera IMEM de referencia por una instrucción

El texto contiene 256 líneas `addi x1, x1, 1` seguidas de una línea `halt`, sin comentarios ni etiquetas. Es un único caso de 257 instrucciones y 1028 bytes.

La expectativa independiente es:

```text
image      = grupo 93 80 10 00 repetido 256 veces, seguido por 0B 00 00 00
pc_to_line = {4*i: i+1 para i de 0 a 256 inclusive}
error      = None
```

La última entrada es `{1024: 257}`. El assembler acepta la traducción porque no compara capacidad de IMEM. No se realiza `LOAD` en esta prueba; la comprobación FPGA de tamaño conserva su catálogo de protocolo. La repetición fija los datos de entrada y esperados, sin requerir imágenes grandes ni otros perfiles.

<a id="test-asm-007"></a>

## TEST-ASM-007 — Diagnósticos y descarte de parciales

**Motivo:** comprobar la ubicación del error y la entrega exclusiva de resultados completos. Las dos últimas variantes contrastan el orden de etapas de [Organización y operación](assembler_organization.md#orden-de-detección-de-errores).

### C001 — Error después de una instrucción válida y líneas vacías

```asm
# Inicialización
addi x1, x0, 5

addi x2, x0, 2048
halt
```

Se espera `image=None`, `pc_to_line={}` y un diagnóstico de línea 4 por inmediato fuera de rango. La instrucción válida anterior no se entrega como imagen parcial.

### C002 — Rechazo de lectura antes de comprobar el rango

```asm
addi x1, x0, 2048
nop
```

Se espera `image=None`, `pc_to_line={}` y un diagnóstico de línea 2 por mnemónico fuera del lenguaje. No se informa primero el rango de la línea 1 porque la lectura completa precede a la interpretación.

### C003 — El rango se comprueba después de una lectura correcta

```asm
addi x1, x0, 2048
halt
```

Se espera `image=None`, `pc_to_line={}` y un diagnóstico de línea 1 por inmediato fuera de rango. En los tres casos, el motivo debe corresponder al problema indicado y se entrega un solo diagnóstico.

<a id="test-asm-008"></a>

## TEST-ASM-008 — Independencia entre llamadas

**Motivo:** detectar símbolos retenidos de otro programa o resultados modificados por una llamada posterior. C001 es una secuencia de tres llamadas sobre el mismo módulo:

| Llamada | Texto                          | Resultado esperado                                                                 |
|---------|--------------------------------|------------------------------------------------------------------------------------|
| A       | `inicio: halt`                 | `image=0B 00 00 00`, `pc_to_line={0: 1}`, `error=None`.                            |
| B       | `jal x0, inicio`               | `image=None`, `pc_to_line={}`, diagnóstico de línea 1 por `inicio` sin definición. |
| C       | `inicio: addi x1, x0, 5\nhalt` | `image=93 00 50 00 0B 00 00 00`, `pc_to_line={0: 1, 4: 2}`, `error=None`.          |

Después de B y C, el resultado A debe conservar exactamente sus bytes y mapa originales. La definición de A no resuelve B y no causa una definición duplicada en C. Las expectativas de cada llamada se comparan con las constantes de esta tabla.

## Cobertura y condición de aprobación

| Obligación                                                     | Casos                                                                                       |
|----------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| Traducción del subconjunto, `REQ-SW-003`                       | `TEST-ASM-001` a `TEST-ASM-008`.                                                            |
| Codificación RV32I, alcance assembler de `REQ-ISA-033`         | `TEST-ASM-001`, extremos válidos de `TEST-ASM-004` y constantes de los programas restantes. |
| Palabra exacta y ausencia de operandos de `halt`, `REQ-SW-012` | `TEST-ASM-001/C033`, `TEST-ASM-005/C003` y programas completos.                             |
| Etiquetas, literales, registros y rechazos del lenguaje        | `TEST-ASM-002` a `TEST-ASM-005`.                                                            |
| Resultado vacío, mapa, diagnósticos y llamadas independientes  | `TEST-ASM-002`, `TEST-ASM-006` a `TEST-ASM-008`.                                            |

La cobertura de selección de archivos, carga, transporte y presentación de Debug permanece en el diseño de la aplicación. El catálogo no acredita esos requisitos mediante una traducción correcta.

Una variante se aprueba cuando coinciden todos los campos públicos esperados. La regresión se considera satisfactoria cuando pasan sus 101 variantes y la revisión de pertinencia de los diagnósticos. La evidencia registra el ID, texto, resultado esperado, resultado observado y revisión del código.

## Estado de diseño

La selección y sus expectativas están aprobadas en el [acuerdo de DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--catálogo-de-pruebas). Aplica los criterios del usuario: resultados independientes, alcance proporcional al TP y entradas dirigidas del lenguaje. El cierre conjunto de [DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueba el lenguaje, la interfaz pública y la organización completos. Los casos de orden de errores comprueban el contrato aprobado de organización.

Este documento enumera los casos de software y sus expectativas. El [manifiesto de hardware](../verification/cases.json) conserva su selección independiente. La implementación y ejecución de estas pruebas permanecen posteriores al cierre global del [Plan](../plan.md#condición-común-para-comenzar-implementación); no se crean aquí tests ni el módulo assembler.

[Entorno e importación](assembler_environment.md#ejecución-de-las-pruebas) define la ejecución aprobada de este catálogo con `unittest` y fija su ubicación y comando futuros.

## Referencias y trazabilidad

- [Lenguaje assembler](assembler_language.md): formas, literales, registros, etiquetas y rechazos.
- [Interfaz del assembler](assembler_interface.md): entrada y resultados públicos.
- [Organización y operación](assembler_organization.md): orden de detección y aislamiento entre llamadas.
- [Codificación de instrucciones](assembler_encoding.md): formatos y relación con el ISA aprobado.
- [Empaquetado y resultado](assembler_packing.md): bytes little-endian y relación PC–línea.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): acuerdos y cierre restante.
- [Requisitos de software](../requirements.md#8-software-de-pc) e [ISA](../requirements.md#3-conjunto-de-instrucciones): obligaciones cubiertas.
- [Matriz de cobertura](../verification/coverage.md#sw): trazabilidad del catálogo de software.
- [Plan de verificación de hardware](../verification/verification_plan.md): expectativas independientes y separación de niveles.
- [Entorno e importación](assembler_environment.md): intérprete y ejecución del catálogo aprobados.
- [Plan](../plan.md): condición de inicio de implementación y pruebas.
