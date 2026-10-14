# Lenguaje assembler del TP3

- **Tipo:** diseño de software / alcance del lenguaje.
- **Estado documental:** especificación vigente.
- **Fecha:** 2026-10-13.

## Propósito y alcance

Define el lenguaje assembler que la aplicación de PC aceptará para construir programas del TP3. Es el primer entregable del diseño del assembler: fija instrucciones, operandos, literales, etiquetas, comentarios y rechazos, independientemente de la herramienta que realice la traducción.

Las codificaciones y los efectos de las instrucciones proceden de [DEC-SYS-010](../decisions/DEC-SYS-010.md), de los [requisitos ISA](../requirements.md#3-conjunto-de-instrucciones) y de la [whitelist de ID](../architecture/cpu/stage_id.md#codificaciones-legales). `halt` conserva el contrato de [DEC-SYS-001](../decisions/DEC-SYS-001.md). Este documento define la sintaxis aprobada del lenguaje.

Los [acuerdos de DEC-SYS-009](../decisions/DEC-SYS-009.md) seleccionan un assembler propio en Python con su biblioteca estándar, acotado al lenguaje del TP3 y responsable de traducir el código sin comprobar la capacidad de IMEM. Las etapas de traducción están definidas en sus documentos de software y [Empaquetado y resultado](assembler_packing.md) especifica la formación de la imagen y del mapa PC–línea. La aprobación conjunta de DEC-SYS-009 incluye este lenguaje.

[Entradas y salidas del assembler](assembler_interface.md) define la interfaz pública aprobada: texto como única entrada; bytes traducidos y relación PC–línea, o un diagnóstico de traducción, como salida.

## Criterios de alcance

- Un único archivo de código fuente contiene instrucciones de 32 bits y etiquetas.
- Cada instrucción del código fuente produce exactamente una palabra de 32 bits, en el mismo orden. No se insertan instrucciones, relleno, expansiones ni `halt` automáticamente.
- La primera instrucción se ubica en IMEM en la dirección cero. La instrucción de índice `i`, contado desde cero, se ubica en `4 * i`.
- El punto de entrada es siempre cero. Una etiqueta llamada `inicio` o `_start` no cambia ese punto.
- Las direcciones y los desplazamientos se expresan en bytes.
- El usuario inicializa los datos mediante instrucciones: la nueva sesión comienza con DMEM lógicamente en cero. El código fuente no contiene una sección de datos ni una imagen inicial de DMEM.
- Un programa puede omitir `halt`, contener varios `halt` o tener instrucciones después de ellos. La ejecución y la finalización se rigen por los contratos de CPU; no se presupone que todas las instrucciones del código fuente serán ejecutadas.

Estas reglas preservan el prefijo contiguo aprobado para IMEM y permiten conocer las direcciones de las etiquetas sin depender de expansiones de pseudoinstrucciones o de transformaciones de la herramienta elegida.

## Organización del código fuente

El archivo de código fuente es texto UTF-8. Se admiten finales de línea LF y CRLF y una última línea sin salto final. Se admite un BOM UTF-8 únicamente al comienzo del archivo. Los identificadores y tokens de código utilizan caracteres ASCII; los comentarios pueden contener texto Unicode.

Cada línea contiene una de las siguientes formas:

```text
[espacios] [comentario]
[espacios] etiqueta: [comentario]
[espacios] instrucción [comentario]
[espacios] etiqueta: instrucción [comentario]
```

Los corchetes indican partes opcionales y no son caracteres del lenguaje. Se admite como máximo una definición de etiqueta y una instrucción por línea. Se permiten líneas vacías y comentarios entre instrucciones.

Espacios y tabulaciones separan los tokens. Debe existir al menos uno entre el mnemónico y su primer operando. Las comas son obligatorias entre operandos; se permiten espacios y tabulaciones alrededor de comas, paréntesis y del `:` de una definición de etiqueta. Un token, como `x10`, una etiqueta o `-12`, no se divide mediante espacios.

Los mnemónicos, nombres de registros y alias se escriben exactamente en minúsculas. Las etiquetas distinguen mayúsculas de minúsculas. No se admite continuación de línea ni varias instrucciones separadas por `;`.

### Comentarios

`#` inicia un comentario hasta el final de la línea, tanto en una línea completa como después de una etiqueta o instrucción. El comentario no genera bytes ni modifica la dirección de la siguiente instrucción.

```asm
# Inicializa el contador
inicio: addi x1, x0, 5   # x1 = 5
```

`//`, `;` y los comentarios de bloque no son delimitadores admitidos.

## Instrucciones y formas de operandos

Se aceptan exactamente las siguientes **32 instrucciones RV32I más `halt`**, todas con codificación de 32 bits. En la tabla, `op` se sustituye por uno de los mnemónicos de su fila; `rd`, `rs1` y `rs2` representan registros; `imm` y `shamt` representan literales; `destino` representa una etiqueta o un desplazamiento literal.

| Familia                     | Mnemónicos                                                           | Forma admitida         | Ejemplo             |
|-----------------------------|----------------------------------------------------------------------|------------------------|---------------------|
| Registro–registro           | `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and` | `op rd, rs1, rs2`      | `add x3, x1, x2`    |
| Aritmética/lógica inmediata | `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`                       | `op rd, rs1, imm`      | `addi x1, x1, -1`   |
| Shift inmediato             | `slli`, `srli`, `srai`                                               | `op rd, rs1, shamt`    | `srai x3, x2, 31`   |
| Load                        | `lb`, `lh`, `lw`, `lbu`, `lhu`                                       | `op rd, imm(rs1)`      | `lw x3, 0(x2)`      |
| Store                       | `sb`, `sh`, `sw`                                                     | `op rs2, imm(rs1)`     | `sw x3, 4(x2)`      |
| Branch                      | `beq`, `bne`                                                         | `op rs1, rs2, destino` | `bne x1, x0, ciclo` |
| Jump relativo               | `jal`                                                                | `jal rd, destino`      | `jal x1, funcion`   |
| Jump indirecto              | `jalr`                                                               | `jalr rd, imm(rs1)`    | `jalr x0, 0(x1)`    |
| Inmediato superior          | `lui`                                                                | `lui rd, imm`          | `lui x2, 0x12345`   |
| Finalización                | `halt`                                                               | `halt`                 | `halt`              |

Los operandos son obligatorios y se rechazan operandos adicionales. En particular, no se aceptan `jal etiqueta`, `jalr x1` ni `lw x1, (x2)`: deben escribirse `jal x1, etiqueta`, `jalr x0, 0(x1)` y `lw x1, 0(x2)`, según la operación pretendida. La forma alternativa `jalr rd, rs1, imm` queda fuera del lenguaje.

`halt` no lleva operandos y genera exactamente `0x0000000B`. No es un alias de `ecall`, `ebreak` ni de otra instrucción estándar.

## Registros

Se aceptan `x0` a `x31`, sin ceros iniciales adicionales (`x01` se rechaza), y los siguientes alias enteros habituales:

| Registros   | Alias, en el mismo orden |
|-------------|--------------------------|
| `x0`        | `zero`                   |
| `x1`        | `ra`                     |
| `x2`        | `sp`                     |
| `x3`        | `gp`                     |
| `x4`        | `tp`                     |
| `x5`–`x7`   | `t0`–`t2`                |
| `x8`        | `s0`, también `fp`       |
| `x9`        | `s1`                     |
| `x10`–`x17` | `a0`–`a7`                |
| `x18`–`x27` | `s2`–`s11`               |
| `x28`–`x31` | `t3`–`t6`                |

Los alias son nombres alternativos de los mismos índices; no reservan registros ni imponen una convención de llamadas. Usar `sp` no inicializa una pila: al comenzar la sesión ese registro también vale cero. `pc` y los nombres de registros de coma flotante o CSR no son operandos de registro admitidos.

La correspondencia de nombres se apoya en la [convención de registros enteros de RISC-V psABI](https://riscv-non-isa.github.io/riscv-elf-psabi-doc/#_integer_register_convention). Se toma únicamente la nomenclatura; la versión normativa del ISA del TP sigue siendo la aprobada en `DEC-SYS-010`.

## Literales e inmediatos

### Escritura de literales

Los literales representan enteros matemáticos, con signo `+` o `-` opcional y adyacente a sus dígitos o prefijo:

| Base        | Escritura                                                       | Ejemplos                  |
|-------------|-----------------------------------------------------------------|---------------------------|
| Decimal     | Uno o más dígitos `0`–`9`                                       | `12`, `-12`, `+12`, `012` |
| Hexadecimal | Prefijo `0x` o `0X`, seguido de uno o más dígitos hexadecimales | `0x7ff`, `-0x800`, `0XAB` |
| Binaria     | Prefijo `0b` o `0B`, seguido de uno o más dígitos `0` o `1`     | `0b101`, `-0b1`           |

Los ceros iniciales de un literal decimal no seleccionan octal: `012` significa doce. No se admiten octal explícito, separadores de dígitos, constantes de caracteres, valores fraccionarios ni expresiones como `4+8`, `%hi(simbolo)` o `%lo(simbolo)`.

La base no cambia el signo: `0xfff` significa 4095 y no se reinterpreta como -1 para caber en 12 bits. El assembler valida el entero antes de codificarlo y nunca recorta bits para hacer que un valor fuera de rango parezca válido.

### Rangos por operando

| Uso                                                                  | Valores admitidos                      | Significado                                                                                  |
|----------------------------------------------------------------------|----------------------------------------|----------------------------------------------------------------------------------------------|
| Aritmética/lógica inmediata, offset de load/store y offset de `jalr` | -2048 a 2047                           | Inmediato de 12 bits con signo                                                               |
| `slli`, `srli`, `srai`                                               | 0 a 31                                 | Cantidad de desplazamiento de RV32                                                           |
| `lui`                                                                | 0 a 1048575 (`0xfffff`)                | Campo de 20 bits que se coloca en los bits 31:12; los doce bits bajos del resultado son cero |
| `beq`, `bne`                                                         | -4096 a 4094, solo valores pares       | Desplazamiento B relativo al PC de la propia instrucción, en bytes                           |
| `jal`                                                                | -1048576 a 1048574, solo valores pares | Desplazamiento J relativo al PC de la propia instrucción, en bytes                           |

`sltiu` también recibe un inmediato de 12 bits con signo: la comparación sin signo no cambia la extensión del inmediato. Los offsets de `jalr` no se multiplican por dos. En `lui x2, 0x12345`, el valor escrito es `0x12345000`; `lui x2, 0x12345000` se rechaza por exceder el campo de 20 bits.

Los límites B/J comprueban representabilidad en la instrucción. La alineación arquitectónica a cuatro bytes y los faults de ejecución se distinguen en [Validación estática y ejecución](#validación-estática-y-ejecución).

## Etiquetas y destinos

Una etiqueta cumple el patrón ASCII `[A-Za-z_][A-Za-z0-9_]*`. Se define mediante `nombre:` y debe ser única en todo el código fuente. Los mnemónicos admitidos, los nombres `x0`–`x31` y los alias de registro de la tabla anterior están reservados y no se utilizan como etiquetas.

Se admiten referencias hacia adelante y hacia atrás. Una definición en una línea sin instrucción identifica la dirección de la siguiente instrucción; varias líneas con etiquetas diferentes pueden identificar la misma dirección. Una etiqueta al final del código fuente identifica la dirección inmediatamente posterior a la imagen. Esa definición no crea una instrucción ni bytes de relleno.

Las etiquetas solo se admiten como `destino` de `beq`, `bne` y `jal`. No se admiten como operandos de `lui`, `jalr`, loads, stores o aritmética inmediata, ni se admiten etiquetas numéricas locales (`1:`, `1f`, `1b`), nombres con `.` o expresiones con símbolos.

Para una etiqueta usada como destino:

```text
desplazamiento = direccion_de_la_etiqueta - PC_de_la_instruccion
```

La resta se calcula como entero matemático sin wrap-around, y se valida contra el rango B o J correspondiente. Se toma como base el PC de la instrucción que salta, no `PC + 4`.

Para un literal usado como destino, el literal ya es el desplazamiento en bytes. No representa una dirección absoluta, un índice de instrucción ni una cantidad de palabras. Por ejemplo, `jal x0, 8` salta ocho bytes respecto del PC actual, y `jal x0, 0` salta a la propia instrucción. La integración con una herramienta externa deberá preservar expresamente esta interpretación.

```asm
    addi x1, x0, 3       # PC = 0
ciclo:
    addi x1, x1, -1      # PC = 4
    bne x1, x0, ciclo    # PC = 8; desplazamiento = 4 - 8 = -4
    jal x0, fin          # PC = 12; desplazamiento = 20 - 12 = 8
    addi x2, x0, 99      # PC = 16; instrucción omitida por el salto
fin: halt                # PC = 20
```

Este programa contiene seis instrucciones y genera 24 bytes. Las etiquetas y los comentarios no contribuyen al tamaño.

## Funciones fuera del alcance inicial

Se rechazan las siguientes construcciones, aunque la herramienta elegida pudiera aceptarlas:

- Pseudoinstrucciones y formas abreviadas: `li`, `la`, `mv`, `nop`, `j`, `ret`, `call`, `beqz`, `bnez`, entre otras. Se escriben sus instrucciones explícitas admitidas; por ejemplo, `addi x0, x0, 0` en lugar de `nop` y `jalr x0, 0(ra)` en lugar de `ret`.
- Instrucciones fuera de la whitelist, incluidas `auipc`, `blt`, `bge`, `bltu`, `bgeu`, `mul`, instrucciones comprimidas, CSR, `ecall` y `ebreak`.
- Todas las directivas en el código fuente, incluidas `.text`, `.data`, `.word`, `.byte`, `.org`, `.align`, `.globl`, `.equ`, `.insn` y `.option`.
- Macros, archivos incluidos, preprocesador, múltiples archivos con enlace de símbolos externos y selección de secciones o direcciones de origen.
- Emisión directa de palabras o bytes de código máquina desde el código fuente.

## Validación estática y ejecución

El assembler rechaza sintaxis inválida, instrucciones no soportadas, registros inexistentes, operandos faltantes o adicionales, literales inválidos o fuera de rango, desplazamientos B/J impares, símbolos duplicados, símbolos sin definición y construcciones fuera del alcance.

Los errores deben identificar la línea original y el motivo concreto. Si el programa tiene un error, no se entrega una imagen parcial como resultado válido ni se inicia su carga. [Interfaz del assembler](assembler_interface.md#diagnósticos) describe el resultado y la información del diagnóstico; [Estructuras de datos](assembler_data_model.md#resultado-y-diagnóstico) define sus clases y campos aprobados.

El lenguaje no intenta demostrar que el programa finalizará ni que todos sus accesos serán válidos en ejecución. En particular:

- `sw x1, 1(x0)` es ensamblable: el fault de alineación corresponde a la CPU.
- `jal x0, 2` es ensamblable porque el desplazamiento es representable; su destino desalineado a cuatro bytes produce el fault arquitectónico correspondiente.
- `jalr x0, 1(x0)` es ensamblable; la CPU limpia el bit cero del destino según RV32I.
- Un destino de branch/jump alineado pero fuera de la imagen puede ensamblarse. Si el flujo lo alcanza, el fetch aplica el contrato de rango y pertenencia a imagen.
- Una etiqueta al final de la imagen puede referenciarse si el desplazamiento cabe. Saltar allí no agrega un `halt` implícito y puede causar un fault de fetch.
- Escribir `rd=x0` es legal; el registro conserva su semántica arquitectónica de cero.
- La ausencia de `halt` no es un error de traducción.

Esto permite construir los programas de diagnóstico previstos en [ISA](../verification/isa.md), [Memoria](../verification/memory.md) y [Ejecución](../verification/execution.md). Las codificaciones ilegales usadas por testbenches de hardware se preparan como estímulos de prueba; no requieren incorporar una directiva de emisión cruda al lenguaje de usuario.

La imagen cargable conserva las condiciones aprobadas: little-endian, origen cero, no vacía, contigua, tamaño múltiplo de cuatro y dentro de la capacidad de IMEM del perfil seleccionado. El assembler garantiza el orden, la continuidad y cuatro bytes por instrucción como parte de la traducción; no comprueba la capacidad de la placa ni rechaza por sí sola la ausencia de instrucciones. Un archivo vacío o formado solo por comentarios y etiquetas válidas se traduce a cero bytes, que no constituyen una imagen ejecutable. La FPGA comprueba el tamaño no nulo, el múltiplo de cuatro y la capacidad antes de aceptar `LOAD`; la aplicación interpreta su respuesta, conforme al [acuerdo de responsabilidades](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--responsabilidad-de-traducción-y-validación-de-tamaño).

## Ejemplos para revisar el alcance

Son expectativas documentales de este primer entregable. [Pruebas del assembler](assembler_tests.md) reúne el catálogo aprobado de casos y resultados esperados; su implementación y ejecución permanecen pendientes.

| Fuente o situación                                    | Resultado esperado                                                                       |
|-------------------------------------------------------|------------------------------------------------------------------------------------------|
| `addi x1, x0, 5` seguido por `halt`                   | Dos palabras: `0x00500093`, `0x0000000B`; bytes de imagen `93 00 50 00 0B 00 00 00`      |
| `addi t0, zero, -1`                                   | Mismos operandos que `addi x5, x0, -1`                                                   |
| `addi x1, x0, -0x800` / `addi x1, x0, 0x7ff`          | Ambos aceptados: extremos de inmediato I                                                 |
| `addi x1, x0, 2048` / `andi x1, x0, 0xfff`            | Rechazo por inmediato fuera de rango                                                     |
| `sltiu x1, x0, -1`                                    | Aceptado; el inmediato se extiende con signo antes de la comparación sin signo           |
| `slli x1, x2, 31` / `slli x1, x2, 32`                 | El primero se acepta; el segundo se rechaza                                              |
| `lui x1, 0xfffff` / `lui x1, 0x100000`                | El primero se acepta; el segundo se rechaza                                              |
| `beq x1, x2, -4096` / `beq x1, x2, 4094`              | Ambos representables, aunque el segundo puede provocar un fault de alineación si se toma |
| `beq x1, x2, 4096` / `beq x1, x2, 3`                  | Rechazo por rango / desplazamiento impar                                                 |
| `jal x1, -1048576` / `jal x1, 1048574`                | Ambos representables; el límite positivo puede producir un fault de alineación           |
| `jal x1, 1048576` / `jal x1, 1`                       | Rechazo por rango / desplazamiento impar                                                 |
| Referencia a `Fin` con una única definición de `fin:` | Rechazo por símbolo sin definición; distingue mayúsculas                                 |
| Dos definiciones de `ciclo:`                          | Rechazo por símbolo duplicado                                                            |
| `halt x0` / `add x32, x0, x1`                         | Rechazo por operandos / registro inexistente                                             |
| `nop` / `.word 0x0000000B` / `auipc x1, 0`            | Rechazo por construcción fuera del alcance                                               |
| `lw x1, dato(x0)`                                     | Rechazo: el offset requiere un literal, no una etiqueta                                  |
| Fuente solo con `# comentario` y `fin:`               | No produce una imagen cargable                                                           |

## Justificación de las elecciones del lenguaje

Las instrucciones explícitas y una palabra por instrucción mantienen una relación directa entre código fuente, direcciones, palabras cargadas y observación del pipeline. Las etiquetas facilitan escribir saltos sin recalcular manualmente desplazamientos. Los alias de registro aportan nombres habituales mediante una correspondencia fija, sin introducir expansión de código.

Un conjunto reducido de literales, un solo delimitador de comentarios y la ausencia de directivas evitan incorporar un lenguaje de expresiones, un esquema de secciones o una inicialización de DMEM que el TP no necesita. Los errores de rango se informan antes de generar una imagen válida; los faults arquitectónicos se conservan como comportamiento verificable del procesador.

## Estado de diseño

El lenguaje, la interfaz pública y la organización interna están aprobados conjuntamente en [DEC-SYS-009](../decisions/DEC-SYS-009.md), que cierra el diseño completo del assembler. [Pruebas del assembler](assembler_tests.md) documenta las expectativas independientes y el criterio de regresión. La implementación conserva la condición de cierre global D0/M6 del [Plan](../plan.md#condición-común-para-comenzar-implementación).

## Referencias y trazabilidad

- [Consigna, conversión de assembler](../consigna.md#8-conversión-de-assembler-a-lenguaje-máquina): obligación docente.
- [Requisitos ISA](../requirements.md#3-conjunto-de-instrucciones) y [Software de PC](../requirements.md#8-software-de-pc): alcance funcional y aceptación.
- [Whitelist de ID](../architecture/cpu/stage_id.md#codificaciones-legales): instrucciones y patrones fijos admitidos por la CPU.
- [DEC-SYS-010](../decisions/DEC-SYS-010.md): versión normativa del ISA.
- [DEC-SYS-001](../decisions/DEC-SYS-001.md): codificación exacta de `halt`.
- [Arquitectura de memoria](../architecture/memory/memory_architecture.md): imagen, perfiles y estado inicial de DMEM.
- [Faults y terminación](../architecture/session/faults_and_termination.md): validaciones de ejecución.

El [análisis de costo y beneficio](assembler_cost_benefit.md) conserva la comparación entre assembler propio, GNU Binutils y bibliotecas para este alcance. Los [acuerdos de DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueban la estrategia propia, Python, la separación entre traducción y validación de tamaño, las etapas y estructuras de traducción, el catálogo de pruebas y el entorno. [Pruebas del assembler](assembler_tests.md) documenta las expectativas independientes y el criterio de regresión.
