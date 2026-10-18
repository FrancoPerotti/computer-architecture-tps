# Codificación de instrucciones del assembler

- **Tipo:** diseño de software.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Interfaces y contratos](#interfaces-y-contratos)
- [Campos fijos por instrucción](#campos-fijos-por-instrucción)
- [Representación de inmediatos](#representación-de-inmediatos)
- [Distribución de campos](#distribución-de-campos)
- [Construcción de la palabra](#construcción-de-la-palabra)
- [Codificación de halt](#codificación-de-halt)
- [Ejemplos de codificación](#ejemplos-de-codificación)
- [Condiciones de la salida](#condiciones-de-la-salida)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

La codificación forma una palabra de 32 bits para cada instrucción interpretada. Combina los campos fijos que identifican la operación con los índices de registros y los inmediatos comprobados por la [interpretación de operandos](assembler_operands.md).

El proyecto utiliza RV32I según User-Level ISA V2.2, conforme a [DEC-SYS-010](../decisions/DEC-SYS-010.md). La [whitelist de ID](../architecture/cpu/stage_id.md#codificaciones-legales) fija las 32 instrucciones soportadas y sus patrones legales. La instrucción custom `halt` conserva la palabra exacta aprobada en [DEC-SYS-001](../decisions/DEC-SYS-001.md).

Este documento define la tabla de campos y su distribución en los formatos R, I, S, B, U y J. La salida contiene palabras como enteros, con sus PCs y líneas originales. El empaquetado en bytes y la formación de `AssemblyResult` pertenecen al diseño posterior.

## Interfaces y contratos

| Dirección | Dato                        | Representación conceptual                                           | Productor                   | Consumidor   | Función                                                 |
|-----------|-----------------------------|---------------------------------------------------------------------|-----------------------------|--------------|---------------------------------------------------------|
| Entrada   | Instrucciones interpretadas | Secuencia con `line`, `pc`, `mnemonic`, índices de registro e `imm` | Interpretación de operandos | Codificación | Valores admitidos para cada instrucción.                |
| Salida    | Instrucciones codificadas   | Secuencia con `line`, `pc` y `word`                                 | Codificación                | Empaquetado  | Palabras de 32 bits y su relación con el código fuente. |

Cada registro de salida contiene:

| Campo  | Representación             | Función                                  |
|--------|----------------------------|------------------------------------------|
| `line` | Entero positivo            | Línea original de la instrucción.        |
| `pc`   | Entero no negativo         | Dirección asignada, en bytes.            |
| `word` | Entero de 0 a `0xffffffff` | Patrón de los 32 bits de la instrucción. |

La entrada cumple las formas y los rangos de la etapa anterior. Los errores de código fuente se informan allí; una entrada interna que contradiga ese contrato representa un defecto del software. La codificación no sustituye operandos ausentes por cero ni recorta un valor inválido para obtener una palabra aparentemente válida.

La notación hexadecimal utilizada en tablas y ejemplos expresa valores enteros, no texto que se transmita por UART. La numeración de bits pertenece a la palabra; el orden de sus bytes se define al empaquetarla.

## Campos fijos por instrucción

`opcode` identifica la clase de instrucción. `funct3` y `funct7`, cuando corresponden, distinguen operaciones dentro de esa clase. La siguiente tabla materializa los patrones de la whitelist de ID para el assembler. Los valores se expresan en hexadecimal; `opcode` ocupa siete bits, `funct3` tres y `funct7` siete.

| Instrucción | Formato        | `opcode` | `funct3` | `funct7` |
|-------------|----------------|----------|----------|----------|
| `add`       | R              | `0x33`   | `0x0`    | `0x00`   |
| `sub`       | R              | `0x33`   | `0x0`    | `0x20`   |
| `sll`       | R              | `0x33`   | `0x1`    | `0x00`   |
| `slt`       | R              | `0x33`   | `0x2`    | `0x00`   |
| `sltu`      | R              | `0x33`   | `0x3`    | `0x00`   |
| `xor`       | R              | `0x33`   | `0x4`    | `0x00`   |
| `srl`       | R              | `0x33`   | `0x5`    | `0x00`   |
| `sra`       | R              | `0x33`   | `0x5`    | `0x20`   |
| `or`        | R              | `0x33`   | `0x6`    | `0x00`   |
| `and`       | R              | `0x33`   | `0x7`    | `0x00`   |
| `addi`      | I              | `0x13`   | `0x0`    | —        |
| `slti`      | I              | `0x13`   | `0x2`    | —        |
| `sltiu`     | I              | `0x13`   | `0x3`    | —        |
| `xori`      | I              | `0x13`   | `0x4`    | —        |
| `ori`       | I              | `0x13`   | `0x6`    | —        |
| `andi`      | I              | `0x13`   | `0x7`    | —        |
| `slli`      | I, shift       | `0x13`   | `0x1`    | `0x00`   |
| `srli`      | I, shift       | `0x13`   | `0x5`    | `0x00`   |
| `srai`      | I, shift       | `0x13`   | `0x5`    | `0x20`   |
| `lb`        | I              | `0x03`   | `0x0`    | —        |
| `lh`        | I              | `0x03`   | `0x1`    | —        |
| `lw`        | I              | `0x03`   | `0x2`    | —        |
| `lbu`       | I              | `0x03`   | `0x4`    | —        |
| `lhu`       | I              | `0x03`   | `0x5`    | —        |
| `sb`        | S              | `0x23`   | `0x0`    | —        |
| `sh`        | S              | `0x23`   | `0x1`    | —        |
| `sw`        | S              | `0x23`   | `0x2`    | —        |
| `beq`       | B              | `0x63`   | `0x0`    | —        |
| `bne`       | B              | `0x63`   | `0x1`    | —        |
| `jal`       | J              | `0x6f`   | —        | —        |
| `jalr`      | I              | `0x67`   | `0x0`    | —        |
| `lui`       | U              | `0x37`   | —        | —        |
| `halt`      | Palabra exacta | `0x0b`   | —        | —        |

Una celda vacía indicada por `—` representa un campo que no se utiliza como selector fijo en ese formato; no agrega un campo cero a la entrada. En I ordinario, los bits 31:25 pertenecen al inmediato. En los shifts inmediatos, esos siete bits sí son fijos y los bits 24:20 contienen la cantidad de desplazamiento.

La tabla cubre únicamente el subconjunto del TP3. Compartir un opcode con otras instrucciones RV32I no amplía el lenguaje admitido. Para `halt`, el opcode por sí solo no basta: todos los bits superiores deben ser cero.

## Representación de inmediatos

### Inmediatos con signo

La interpretación entrega el entero con su signo y ya comprobado contra el rango correspondiente. La codificación obtiene su representación en complemento a dos de ancho `n`:

```text
u = imm mod 2^n
```

| Formato         | Ancho `n` | Rango previamente comprobado   |
|-----------------|----------:|--------------------------------|
| I ordinario y S |        12 | -2048 a 2047.                  |
| B               |        13 | -4096 a 4094, valor par.       |
| J               |        21 | -1048576 a 1048574, valor par. |

Para un valor válido, obtener los `n` bits bajos mediante una máscara equivale a esa representación. Esta operación se realiza después de validar, no como una forma de aceptar valores fuera de rango.

Por ejemplo, `imm=-1` en I produce `u=0xfff`. Un literal fuente `0xfff`, en cambio, representa el entero positivo 4095 y ya debe haberse rechazado en una posición I de 12 bits con signo.

### Inmediato U y shifts

En U, `imm` es el campo de 20 bits no negativo de la instrucción. Se coloca en los bits 31:12 de la palabra, mediante un desplazamiento de doce posiciones. No se vuelve a interpretar como una dirección ni se desplaza antes de esta etapa.

En un shift inmediato, `imm` conserva la cantidad de 0 a 31. El campo de doce bits utilizado por la fórmula I se forma así:

```text
u = (funct7 << 5) | imm
```

En `srai` el valor fijo `funct7=0x20` produce los bits superiores `0100000`. La cantidad se mantiene en los cinco bits inferiores; no recibe extensión de signo.

## Distribución de campos

`word[a:b]` representa los bits inclusivos desde `a` hasta `b`, con `a` como el más significativo. `u[a:b]` utiliza la misma convención. Estas expresiones describen posiciones de bits, no slices de Python.

| Formato | Bits 31:25         | Bits 24:20        | Bits 19:15 | Bits 14:12 | Bits 11:7         | Bits 6:0 |
|---------|--------------------|-------------------|------------|------------|-------------------|----------|
| R       | `funct7`           | `rs2`             | `rs1`      | `funct3`   | `rd`              | `opcode` |
| I       | `u[11:5]`          | `u[4:0]`          | `rs1`      | `funct3`   | `rd`              | `opcode` |
| S       | `u[11:5]`          | `rs2`             | `rs1`      | `funct3`   | `u[4:0]`          | `opcode` |
| B       | `{u[12], u[10:5]}` | `rs2`             | `rs1`      | `funct3`   | `{u[4:1], u[11]}` | `opcode` |
| U       | `imm[19:13]`       | `imm[12:8]`       | `imm[7:3]` | `imm[2:0]` | `rd`              | `opcode` |
| J       | `{u[20], u[10:5]}` | `{u[4:1], u[11]}` | `u[19:15]` | `u[14:12]` | `rd`              | `opcode` |

Las llaves indican concatenación, con el primer fragmento ubicado en las posiciones más significativas. Los formatos B y J reparten el inmediato en posiciones diferentes a las de I y S. Su bit cero está implícito y no ocupa una posición en la palabra.

Las posiciones de B y J se detallan por fragmento:

| Formato | Fragmento  | Posición en `word` |
|---------|------------|--------------------|
| B       | `u[12]`    | 31.                |
| B       | `u[10:5]`  | 30:25.             |
| B       | `u[4:1]`   | 11:8.              |
| B       | `u[11]`    | 7.                 |
| J       | `u[20]`    | 31.                |
| J       | `u[10:1]`  | 30:21.             |
| J       | `u[11]`    | 20.                |
| J       | `u[19:12]` | 19:12.             |

El encoder utiliza el desplazamiento en bytes resuelto por la etapa anterior. No vuelve a restar el PC ni divide el desplazamiento completo antes de distribuir sus fragmentos.

## Construcción de la palabra

Los operadores `<<` y `>>` indican desplazamiento de bits; `&` aplica una máscara y `|` combina campos mediante OR. Las siguientes expresiones son fórmulas del diseño, no funciones implementadas.

### Formato R

```text
word = (funct7 << 25) | (rs2 << 20) | (rs1 << 15)
     | (funct3 << 12) | (rd << 7) | opcode
```

### Formato I

Se utiliza `u` de doce bits, obtenido del inmediato con signo o del campo especial de shift:

```text
word = (u << 20) | (rs1 << 15) | (funct3 << 12)
     | (rd << 7) | opcode
```

La fórmula se aplica a aritmética/lógica inmediata, shifts, loads y `jalr`, usando los campos fijos de su fila.

### Formato S

```text
word = (((u >> 5) & 0x7f) << 25) | (rs2 << 20)
     | (rs1 << 15) | (funct3 << 12)
     | ((u & 0x1f) << 7) | opcode
```

El dato del store se identifica mediante `rs2`. Los bits 11:7 contienen el fragmento bajo del inmediato y no un registro destino.

### Formato B

```text
word = (((u >> 12) & 0x1) << 31)
     | (((u >> 5) & 0x3f) << 25)
     | (rs2 << 20) | (rs1 << 15) | (funct3 << 12)
     | (((u >> 1) & 0xf) << 8)
     | (((u >> 11) & 0x1) << 7) | opcode
```

### Formato U

```text
word = (imm << 12) | (rd << 7) | opcode
```

### Formato J

```text
word = (((u >> 20) & 0x1) << 31)
     | (((u >> 1) & 0x3ff) << 21)
     | (((u >> 11) & 0x1) << 20)
     | (((u >> 12) & 0xff) << 12)
     | (rd << 7) | opcode
```

Cada expresión utiliza campos presentes y comprobados en su formato. Los campos ocupan posiciones disjuntas y el resultado queda entre cero y `0xffffffff` por construcción. No se necesita una máscara final para ocultar errores de rango.

## Codificación de halt

`halt` produce directamente:

```text
word = 0x0000000b
```

Los bits 31:7 son cero y el opcode es `0001011`, correspondiente a `custom-0`. Se utiliza la palabra completa de `DEC-SYS-001`; no se codifica como `ecall`, `ebreak` ni como una familia de instrucciones custom parametrizable.

## Ejemplos de codificación

### ADDI con inmediato positivo

Para `addi x1, x0, 5`, los valores son `rd=1`, `rs1=0`, `imm=5`, `funct3=0` y `opcode=0x13`:

```text
u              = 0x005
u << 20        = 0x00500000
rs1 << 15      = 0x00000000
funct3 << 12   = 0x00000000
rd << 7        = 0x00000080
opcode         = 0x00000013
word           = 0x00500093
```

### Formatos y valores con signo

Los destinos literales de la tabla se expresan como desplazamientos en bytes:

| Instrucción       | Formato        | `word`       |
|-------------------|----------------|--------------|
| `add x3, x1, x2`  | R              | `0x002081b3` |
| `sub x3, x1, x2`  | R              | `0x402081b3` |
| `addi x1, x1, -1` | I              | `0xfff08093` |
| `lw x3, -4(x2)`   | I              | `0xffc12183` |
| `srai x3, x2, 31` | I, shift       | `0x41f15193` |
| `sw x5, 4(x0)`    | S              | `0x00502223` |
| `bne x1, x0, -4`  | B              | `0xfe009ee3` |
| `beq x1, x2, 2`   | B              | `0x00208163` |
| `lui x2, 0x12345` | U              | `0x12345137` |
| `jal x0, 8`       | J              | `0x0080006f` |
| `jal x1, -4`      | J              | `0xffdff0ef` |
| `jalr x0, 1(x1)`  | I              | `0x00108067` |
| `halt`            | Palabra exacta | `0x0000000b` |

`beq x1, x2, 2` es representable; el eventual fault de alineación de su destino se comprueba al ejecutar el branch tomado. La codificación no transforma el desplazamiento 2 en cero o cuatro.

### Programa con etiquetas resueltas

Las instrucciones del [ejemplo de interpretación](assembler_operands.md#ejemplo-de-interpretación) producen:

| `line` | `pc` | Instrucción interpretada | `word`       |
|-------:|-----:|--------------------------|--------------|
|      4 |    0 | `addi x1, x0, 3`         | `0x00300093` |
|      5 |    4 | `addi x1, x1, -1`        | `0xfff08093` |
|      6 |    8 | `bne x1, x0, -4`         | `0xfe009ee3` |
|      7 |   12 | `jal x0, 8`              | `0x0080006f` |
|      8 |   16 | `addi x2, x0, 99`        | `0x06300113` |
|      9 |   20 | `halt`                   | `0x0000000b` |

Cada registro conserva el PC y la línea de entrada. Las etiquetas ya están representadas por los desplazamientos; no se consultan nuevamente al formar estas palabras.

## Condiciones de la salida

- Cada instrucción de entrada produce exactamente una palabra, en el mismo orden.
- Todos los valores `word` representan patrones de 32 bits como enteros no negativos.
- La entrada vacía produce una secuencia vacía; no se agrega `halt` ni relleno.
- `line` y `pc` se conservan para formar posteriormente `pc_to_line`.
- Los campos fijos de cada palabra coinciden con la whitelist de ID y los fragmentos del inmediato permiten la reconstrucción definida en [Datapath](../architecture/cpu/datapath.md#inmediato).
- Los inmediatos B/J conservan su valor en bytes, incluido el bit cero implícito.
- La palabra de `halt` coincide exactamente con `0x0000000b`.

El encoder no analiza el flujo de ejecución ni la capacidad de IMEM. Las palabras producidas todavía deben empaquetarse para formar `image`; la aceptación de carga pertenece a la FPGA y al protocolo.

## Estado de diseño

La tabla y las fórmulas de codificación están aprobadas en el [acuerdo de DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--codificación-de-instrucciones). [Empaquetado y resultado](assembler_packing.md) define la formación aprobada de bytes y relación PC–línea. Las [estructuras Python](assembler_data_model.md) también están aprobadas. El cierre conjunto de [DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueba también el lenguaje, la interfaz pública y la organización interna. El [catálogo de pruebas](assembler_tests.md) está aprobado documentalmente; su implementación y ejecución permanecen pendientes. El [entorno e importación](assembler_environment.md) está aprobado.

Las tablas y expresiones describen el contrato de diseño y sus expectativas. La implementación y ejecución de pruebas permanecen posteriores al cierre global del [Plan](../plan.md#condición-común-para-comenzar-implementación). El cierre completo de `DEC-SYS-009` se consulta en [DEC-SYS-009](../decisions/DEC-SYS-009.md).

## Referencias y trazabilidad

- [Interpretación de operandos](assembler_operands.md): índices, inmediatos y desplazamientos comprobados.
- [Empaquetado y resultado](assembler_packing.md): conversión de palabras a bytes y formación de la relación PC–línea.
- [Lenguaje assembler](assembler_language.md): instrucciones y sintaxis admitidas.
- [Etapa ID](../architecture/cpu/stage_id.md#codificaciones-legales): whitelist y campos fijos del decoder.
- [Datapath](../architecture/cpu/datapath.md#inmediato): posiciones de registros y reconstrucción de inmediatos.
- [DEC-SYS-010](../decisions/DEC-SYS-010.md): versión normativa del ISA.
- [DEC-SYS-001](../decisions/DEC-SYS-001.md): palabra custom de `halt`.
- [Definiciones oficiales RV-I](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv_i) y [shifts RV32-I](https://github.com/riscv/riscv-opcodes/blob/master/extensions/rv32_i): referencias complementarias de campos fijos, contrastadas con el subconjunto aprobado; no reemplazan la versión normativa del proyecto.
- [Formatos de instrucciones de GNU as](https://sourceware.org/binutils/docs/as/RISC_002dV_002dFormats.html): referencia complementaria de distribución de campos R, I, S, B, U y J.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): acuerdos y alcance restante del assembler.
- [Plan](../plan.md): fases y condiciones previas a implementación.
