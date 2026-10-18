# Interpretación de operandos y resolución de destinos

- **Tipo:** diseño de software.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Interfaces y contratos](#interfaces-y-contratos)
- [Instrucciones interpretadas](#instrucciones-interpretadas)
- [Registros](#registros)
- [Literales e inmediatos](#literales-e-inmediatos)
- [Operandos de memoria y JALR](#operandos-de-memoria-y-jalr)
- [Resolución de destinos](#resolución-de-destinos)
- [Comprobaciones y diagnósticos](#comprobaciones-y-diagnósticos)
- [Ejemplo de interpretación](#ejemplo-de-interpretación)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

La interpretación convierte los operandos reconocidos como texto en los valores que necesita la codificación. Identifica registros, obtiene valores enteros de los literales, separa base y offset de los accesos indirectos y resuelve los destinos de branches y `jal` mediante la tabla de etiquetas.

La entrada procede de [Direcciones y tabla de etiquetas](assembler_addresses.md). El [lenguaje assembler](assembler_language.md) fija los nombres, formas, bases numéricas y rangos admitidos. Esta etapa comprueba esas condiciones y conserva el PC y la línea original de cada instrucción. La formación de las palabras de 32 bits y su empaquetado en bytes pertenecen a la etapa posterior.

## Interfaces y contratos

| Dirección        | Dato                        | Representación conceptual                                   | Productor                   | Consumidor                      | Función                                                        |
|------------------|-----------------------------|-------------------------------------------------------------|-----------------------------|---------------------------------|----------------------------------------------------------------|
| Entrada          | Instrucciones con dirección | Secuencia con `line`, `pc`, `mnemonic` y operandos de texto | Asignación de direcciones   | Interpretación                  | Instrucciones que deben convertirse a valores de codificación. |
| Entrada          | Tabla de etiquetas          | Nombre → dirección y línea de definición                    | Asignación de direcciones   | Resolución de destinos          | Definiciones completas del programa.                           |
| Salida correcta  | Instrucciones interpretadas | Secuencia con índices de registro e inmediatos numéricos    | Interpretación y resolución | Codificación                    | Valores comprobados para cada instrucción.                     |
| Salida con error | Diagnóstico                 | Línea y motivo                                              | Interpretación y resolución | Operación pública de ensamblado | Informar un operando inválido o una referencia sin definición. |

La operación recorre las instrucciones en su orden original y conserva ese orden en la salida. Cada instrucción reconocida produce un registro interpretado. Si encuentra un error, entrega un diagnóstico y descarta la secuencia parcial; la aplicación recibe `image=None` y `pc_to_line={}`, según la [interfaz pública](assembler_interface.md#resultado-de-la-traducción).

La interpretación y la resolución describen responsabilidades del mismo recorrido sobre instrucciones y tabla completa. No requieren una estructura de expresiones ni la incorporación de herramientas externas.

## Instrucciones interpretadas

Cada registro de salida conserva los siguientes campos conceptuales:

| Campo      | Representación              | Función                                                                    |
|------------|-----------------------------|----------------------------------------------------------------------------|
| `line`     | Entero positivo             | Línea original de la instrucción.                                          |
| `pc`       | Entero no negativo          | Dirección en bytes ya asignada.                                            |
| `mnemonic` | Texto                       | Instrucción admitida que determina la codificación.                        |
| `rd`       | Índice de 0 a 31 o ausencia | Registro destino, cuando la instrucción lo utiliza.                        |
| `rs1`      | Índice de 0 a 31 o ausencia | Primer registro fuente o base de acceso indirecto.                         |
| `rs2`      | Índice de 0 a 31 o ausencia | Segundo registro fuente o dato de un store.                                |
| `imm`      | Entero o ausencia           | Inmediato, offset, cantidad de desplazamiento o desplazamiento de control. |

Los campos de operandos presentes dependen de la instrucción:

| Familia                     | Campos presentes          | Interpretación de `imm`                                    |
|-----------------------------|---------------------------|------------------------------------------------------------|
| Registro–registro           | `rd`, `rs1`, `rs2`        | Ausente.                                                   |
| Aritmética/lógica inmediata | `rd`, `rs1`, `imm`        | Inmediato de 12 bits con signo.                            |
| Shift inmediato             | `rd`, `rs1`, `imm`        | Cantidad de desplazamiento de 0 a 31.                      |
| Load                        | `rd`, `rs1`, `imm`        | Offset de 12 bits con signo.                               |
| Store                       | `rs1`, `rs2`, `imm`       | Offset de 12 bits con signo.                               |
| `beq`, `bne`                | `rs1`, `rs2`, `imm`       | Desplazamiento relativo al PC de la instrucción, en bytes. |
| `jal`                       | `rd`, `imm`               | Desplazamiento relativo al PC de la instrucción, en bytes. |
| `jalr`                      | `rd`, `rs1`, `imm`        | Offset de 12 bits con signo, sin escalado.                 |
| `lui`                       | `rd`, `imm`               | Campo de 20 bits sin desplazar.                            |
| `halt`                      | Ningún campo de operandos | Ausente.                                                   |

La ausencia de un campo se distingue de un valor cero. `rd=0` identifica `x0` y es un operando válido; un store carece de `rd`. Del mismo modo, `imm=0` es un inmediato presente y no una ausencia de inmediato.

Los valores siguen siendo enteros matemáticos. Los negativos se conservan con su signo; su representación en bits se forma al codificar, después de comprobar el rango. La salida no necesita otra copia de los operandos de texto. [Estructuras de datos](assembler_data_model.md#instrucciones-interpretadas) define su representación Python aprobada mediante `InterpretedInstruction`.

## Registros

Un operando de registro se interpreta según los nombres exactos de [Registros](assembler_language.md#registros). `x0` a `x31` producen sus índices correspondientes y los alias producen el índice del mismo registro arquitectónico.

| Texto            | Índice |
|------------------|-------:|
| `x0`, `zero`     |      0 |
| `x1`, `ra`       |      1 |
| `x2`, `sp`       |      2 |
| `x5`, `t0`       |      5 |
| `x8`, `s0`, `fp` |      8 |
| `x10`, `a0`      |     10 |
| `x31`, `t6`      |     31 |

Se comprueban el nombre completo y su escritura en minúsculas. `x32`, `x01`, `X1`, `pc` y nombres de registros no admitidos producen un diagnóstico. Un entero como `5` no reemplaza al nombre `x5` en una posición de registro.

La conversión de alias solo cambia la representación del operando. No reserva registros, inicializa una pila ni impone una convención de llamadas. Escribir `x0` como destino sigue siendo legal; su comportamiento pertenece a la CPU.

## Literales e inmediatos

### Conversión numérica

La conversión utiliza el signo y la base explícita admitidos por [Literales e inmediatos](assembler_language.md#literales-e-inmediatos). Comprueba el token completo antes de obtener su valor:

- Decimal: uno o más dígitos ASCII de `0` a `9`.
- Hexadecimal: `0x` o `0X` y uno o más dígitos hexadecimales.
- Binaria: `0b` o `0B` y uno o más dígitos `0` o `1`.

Cada forma admite un único signo `+` o `-` opcional al comienzo, adyacente al resto del literal. Un prefijo sin dígitos, dígitos incompatibles con la base o texto adicional producen un diagnóstico. Las expresiones, constantes de caracteres y separadores de dígitos quedan fuera del lenguaje.

Los ceros iniciales no seleccionan octal. `012` produce el entero 12 y `-0x800` produce -2048. `0xfff` produce 4095; no se reinterpreta como -1 para caber en un campo con signo. La conversión no recorta bits ni aplica módulo para corregir un valor fuera de rango.

### Validación por instrucción

| Uso                                                 | Condición sobre el valor de `imm`     |
|-----------------------------------------------------|---------------------------------------|
| Aritmética/lógica inmediata, loads, stores y `jalr` | -2048 a 2047.                         |
| `slli`, `srli`, `srai`                              | 0 a 31.                               |
| `lui`                                               | 0 a 1048575, equivalente a `0xfffff`. |
| `beq`, `bne`                                        | -4096 a 4094 y valor par.             |
| `jal`                                               | -1048576 a 1048574 y valor par.       |

El nombre de la instrucción determina el rango; la base elegida para escribir el literal no lo modifica. `sltiu` conserva el inmediato de 12 bits con signo aunque su comparación sea sin signo.

Para `lui x2, 0x12345`, la salida conserva `imm=0x12345`. La codificación colocará ese campo en los bits 31:12; el resultado arquitectónico será `0x12345000`. No se toma `0x12345000` como un literal válido para el campo de 20 bits.

Los shifts conservan la cantidad de desplazamiento en `imm`. Sus bits fijos de codificación se determinarán en la tabla del encoder, sin modificar ese valor.

## Operandos de memoria y JALR

La lectura entrega el segundo operando normalizado a `offset(base)`. La interpretación convierte el offset a un entero admitido de 12 bits con signo y la base a un índice de registro.

| Instrucción      | Conversión                                |
|------------------|-------------------------------------------|
| `lw x3, -4(sp)`  | `rd=3`, `rs1=2`, `imm=-4`; `rs2` ausente. |
| `sw t0, 4(x0)`   | `rs2=5`, `rs1=0`, `imm=4`; `rd` ausente.  |
| `jalr x0, 1(ra)` | `rd=0`, `rs1=1`, `imm=1`; `rs2` ausente.  |

El primer operando de un store representa el registro que aporta el dato y se conserva como `rs2`. La base del segundo operando se conserva como `rs1`.

El offset requiere un literal; `dato(x0)` se rechaza aunque exista una etiqueta llamada `dato`. Las etiquetas se admiten únicamente como destinos de `beq`, `bne` y `jal`.

La interpretación no calcula direcciones efectivas a partir del contenido de los registros, no comprueba límites de DMEM ni redondea offsets. En `jalr`, tampoco limpia el bit cero del inmediato: la CPU aplica esa regla sobre el destino calculado durante la ejecución.

## Resolución de destinos

### Destino expresado como etiqueta

El destino de `beq`, `bne` o `jal` puede ser el nombre de una etiqueta admitida. Se busca su definición por el nombre exacto en la tabla completa. Si no existe, se informa el error en la línea de la instrucción que la utiliza.

La dirección encontrada se convierte a desplazamiento mediante:

```text
imm = direccion_de_la_etiqueta - pc_de_la_instruccion
```

La resta se calcula sin truncamiento ni wrap-around y el resultado se comprueba contra el rango B o J y la condición de paridad. La base es el PC de la instrucción que salta, no `PC + 4`. Las referencias adelantadas y hacia atrás utilizan la misma regla.

### Destino expresado como literal

Un literal de destino ya representa el desplazamiento en bytes. Se convierte a entero y se comprueba con el mismo rango y paridad que un destino resuelto desde una etiqueta. No se le resta nuevamente el PC ni se lo multiplica por cuatro.

Por ejemplo, para `jal x0, 8` ubicada en PC 12, la salida conserva `imm=8`; el destino de ejecución corresponde a PC 20. Para `jal x0, 0`, la salida conserva `imm=0` y el salto apunta a la propia instrucción.

### Representabilidad y faults de ejecución

Un desplazamiento impar se rechaza porque no puede representarse en B/J. Un desplazamiento par que no sea múltiplo de cuatro, como 2, es representable y puede ensamblarse; la CPU comprueba la alineación del destino cuando corresponde.

Tampoco se comprueba que el destino esté dentro de la imagen. Una etiqueta al final o un literal que lleve fuera del programa puede producir una instrucción codificable y un fault posterior de fetch. La distinción se conserva conforme a [Validación estática y ejecución](assembler_language.md#validación-estática-y-ejecución).

## Comprobaciones y diagnósticos

El diagnóstico conserva la línea original de la instrucción y describe el operando causante y el motivo. Las siguientes situaciones producen un error:

| Situación                                                   | Motivo                                            |
|-------------------------------------------------------------|---------------------------------------------------|
| Registro fuera de `x0`–`x31` o alias desconocido            | El operando no identifica un registro admitido.   |
| Literal incompleto o con dígitos inválidos                  | El token no representa un entero del lenguaje.    |
| Inmediato fuera del rango de su instrucción                 | El valor no cabe en el campo correspondiente.     |
| Desplazamiento B/J impar                                    | Su bit menos significativo no puede codificarse.  |
| Etiqueta sin definición                                     | No existe una dirección para resolver el destino. |
| Símbolo o expresión en una posición que requiere un literal | La forma de operando queda fuera del lenguaje.    |

La etapa no continúa sobre una instrucción inválida para fabricar una palabra aproximada. La secuencia vacía produce una salida vacía sin diagnóstico. Si hay un error, no se presenta ninguna parte de la traducción como resultado válido.

Esta etapa utiliza la tabla de etiquetas sin modificar las definiciones. Las duplicaciones ya se comprueban al construirla. El contrato no incorpora diagnósticos de capacidad ni intenta predecir la terminación del programa.

## Ejemplo de interpretación

Con las direcciones y etiquetas del [ejemplo de asignación](assembler_addresses.md#ejemplo-de-asignación), las seis instrucciones producen:

| `line` | `pc` | `mnemonic` | `rd`    | `rs1`   | `rs2`   | `imm`   |
|-------:|-----:|------------|---------|---------|---------|---------|
|      4 |    0 | `addi`     | 1       | 0       | Ausente | 3       |
|      5 |    4 | `addi`     | 1       | 1       | Ausente | -1      |
|      6 |    8 | `bne`      | Ausente | 1       | 0       | -4      |
|      7 |   12 | `jal`      | 0       | Ausente | Ausente | 8       |
|      8 |   16 | `addi`     | 2       | 0       | Ausente | 99      |
|      9 |   20 | `halt`     | Ausente | Ausente | Ausente | Ausente |

`ciclo` se define en dirección 4; la instrucción `bne` ubicada en PC 8 recibe `imm=4-8=-4`. `fin` se define en dirección 20; `jal` en PC 12 recibe `imm=20-12=8`.

Los operandos quedan preparados para la codificación, pero la tabla todavía no contiene palabras de código máquina. Los campos ausentes no se confunden con los índices cero presentes en `addi`, `bne` y `jal`.

## Estado de diseño

La interpretación de operandos y resolución de destinos están aprobadas en el [acuerdo de DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--interpretación-de-operandos-y-resolución-de-destinos). [Codificación de instrucciones](assembler_encoding.md) define la tabla y fórmulas aprobadas que utilizan estos valores. Las [estructuras Python](assembler_data_model.md) también están aprobadas. El cierre conjunto de [DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueba también el lenguaje, la interfaz pública y la organización interna. El [catálogo de pruebas](assembler_tests.md) está aprobado documentalmente; su implementación y ejecución permanecen pendientes. El [entorno e importación](assembler_environment.md) está aprobado.

Los ejemplos describen expectativas documentales. La implementación y ejecución de pruebas permanecen posteriores al cierre global del [Plan](../plan.md#condición-común-para-comenzar-implementación). El cierre de `DEC-SYS-009` se consulta en [DEC-SYS-009](../decisions/DEC-SYS-009.md).

## Referencias y trazabilidad

- [Lenguaje assembler](assembler_language.md): registros, literales, rangos y formas de destino.
- [Lectura del código fuente](assembler_source_reader.md): reconocimiento y normalización de operandos de texto.
- [Direcciones y tabla de etiquetas](assembler_addresses.md): PCs y definiciones utilizadas en la resolución.
- [Interfaz del assembler](assembler_interface.md): condiciones de éxito, error y conservación de líneas.
- [Codificación de instrucciones](assembler_encoding.md): formación de las palabras de 32 bits a partir de estos operandos.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): estrategia y acuerdos del assembler.
- [DEC-SYS-010](../decisions/DEC-SYS-010.md): versión normativa del ISA.
- [Etapa ID](../architecture/cpu/stage_id.md#codificaciones-legales): instrucciones y patrones admitidos por la CPU.
- [Decisiones pendientes](../decisions/pending_decisions.md): diseño restante y cierre.
- [Plan](../plan.md): fases y condiciones previas a implementación.
