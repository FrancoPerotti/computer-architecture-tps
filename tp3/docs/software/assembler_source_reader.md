# Lectura del código fuente assembler

- **Tipo:** diseño de software.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Interfaces y contratos](#interfaces-y-contratos)
- [Representación de las líneas](#representación-de-las-líneas)
- [Comportamiento de la lectura](#comportamiento-de-la-lectura)
- [Comprobaciones y diagnósticos](#comprobaciones-y-diagnósticos)
- [Ejemplo de lectura](#ejemplo-de-lectura)
- [Condiciones de borde](#condiciones-de-borde)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

La lectura reconoce la organización del código fuente y conserva la información necesaria para traducir sus instrucciones. Separa comentarios, identifica definiciones de etiquetas y reconoce mnemónicos y operandos, manteniendo el número original de cada línea.

Este documento especifica la primera etapa interna del assembler. El [lenguaje assembler](assembler_language.md) fija las construcciones admitidas y la [interfaz pública](assembler_interface.md) define el resultado que recibe la aplicación. La lectura entrega una representación intermedia del texto; la asignación de direcciones, resolución de símbolos, interpretación de operandos y codificación pertenecen a las etapas posteriores.

## Interfaces y contratos

| Dirección        | Dato               | Representación conceptual       | Productor                          | Consumidor                      | Función                                             |
|------------------|--------------------|---------------------------------|------------------------------------|---------------------------------|-----------------------------------------------------|
| Entrada          | Código fuente      | Texto completo, `source_text`   | Aplicación, a través del assembler | Lectura                         | Programa escrito en el lenguaje del TP3.            |
| Salida correcta  | Líneas reconocidas | Secuencia ordenada de registros | Lectura                            | Asignación de direcciones       | Etiquetas, instrucciones y su ubicación original.   |
| Salida con error | Diagnóstico        | Línea y motivo                  | Lectura                            | Operación pública de ensamblado | Informar una construcción que no puede reconocerse. |

Una lectura correcta entrega todos los registros reconocidos en el orden del programa. Una lectura con error entrega un único diagnóstico y descarta su resultado parcial. La operación pública conserva las condiciones de error de `AssemblyResult`: `image=None`, `pc_to_line={}` y un diagnóstico.

La salida correcta de esta etapa acredita la forma del texto reconocido. Todavía no acredita que todos los operandos sean válidos ni que todas las referencias tengan una definición.

## Representación de las líneas

Cada registro conserva los siguientes campos:

| Campo      | Representación conceptual | Función                                             |
|------------|---------------------------|-----------------------------------------------------|
| `line`     | Entero positivo           | Número de línea original, contado desde uno.        |
| `label`    | Texto o ausencia          | Nombre de la etiqueta definida en esa línea.        |
| `mnemonic` | Texto o ausencia          | Mnemónico de la instrucción, escrito en minúsculas. |
| `operands` | Secuencia de textos       | Operandos en el orden de la forma admitida.         |

Los nombres describen el contrato de datos. [Estructuras de datos](assembler_data_model.md#líneas-reconocidas) define su representación aprobada como `SourceRecord` en Python. Se conserva una representación simple, sin árbol de expresiones ni copias de comentarios.

| Contenido de la línea       | Registro entregado                                       |
|-----------------------------|----------------------------------------------------------|
| Vacía o solo comentario     | Ninguno.                                                 |
| Solo definición de etiqueta | `line` y `label`; `mnemonic` ausente y `operands` vacío. |
| Solo instrucción            | `line`, `mnemonic` y `operands`; `label` ausente.        |
| Etiqueta e instrucción      | Los cuatro campos.                                       |

Una línea vacía o de comentario no agrega un registro, pero participa en la numeración original. Una definición de etiqueta se conserva aunque no tenga una instrucción en la misma línea. Las etapas posteriores necesitan esa definición para asignarle la dirección de la siguiente instrucción o del final del programa.

Los operandos permanecen como texto. Los registros no se convierten a índices, los literales no se convierten a enteros y las referencias a etiquetas no se sustituyen por desplazamientos durante la lectura.

## Comportamiento de la lectura

### Líneas y comentarios

La lectura respeta LF y CRLF, una última línea sin salto final y el BOM UTF-8 inicial admitido por el lenguaje. El BOM inicial no forma parte de un token. La aplicación realiza la lectura y decodificación UTF-8 del archivo; esta etapa recibe el texto ya obtenido.

Cada línea conserva su número original antes de separar el comentario. El primer `#` inicia el comentario hasta el final de esa línea. Su contenido se descarta, incluidas comas, paréntesis o dos puntos que aparezcan dentro de él. El código restante se analiza después de retirar los espacios y tabulaciones de sus extremos.

El reconocimiento de comentarios utiliza únicamente `#`. Las otras construcciones se interpretan según las reglas del lenguaje, sin admitir `//`, `;` o comentarios de bloque como delimitadores adicionales.

### Definiciones de etiquetas

Una definición se reconoce al comienzo del código de la línea, mediante un identificador seguido de `:`. Se permiten espacios y tabulaciones alrededor de ese separador, conservando el nombre de la etiqueta y su uso de mayúsculas y minúsculas.

El identificador debe cumplir `[A-Za-z_][A-Za-z0-9_]*` y respetar los nombres reservados de [Etiquetas y destinos](assembler_language.md#etiquetas-y-destinos). Se admite como máximo una definición por línea.

Si existe código después de `:`, debe corresponder a una instrucción. La lectura conserva las definiciones sin asignar direcciones ni comprobar todavía si otra línea define el mismo nombre. La detección de símbolos duplicados pertenece a la construcción de la tabla de etiquetas.

### Mnemónicos y operandos

El mnemónico debe pertenecer a las 32 instrucciones RV32I o a `halt` del [lenguaje](assembler_language.md#instrucciones-y-formas-de-operandos). La coincidencia utiliza su escritura exacta en minúsculas. Las pseudoinstrucciones y directivas se rechazan conforme al alcance establecido.

La forma de la instrucción determina la cantidad y la organización de sus operandos:

| Forma                                                      | Organización reconocida                                                      |
|------------------------------------------------------------|------------------------------------------------------------------------------|
| Registro–registro, aritmética inmediata, shifts y branches | Tres operandos separados por comas.                                          |
| Loads, stores y `jalr`                                     | Dos operandos separados por una coma; el segundo tiene forma `offset(base)`. |
| `jal` y `lui`                                              | Dos operandos separados por una coma.                                        |
| `halt`                                                     | Ningún operando.                                                             |

Existe al menos un espacio o tabulación entre el mnemónico y su primer operando. Las comas son obligatorias y todos los operandos requeridos deben estar presentes. Un token no puede dividirse mediante espacios: `x1` y `-1` son tokens completos; `x 1` y `- 1` no lo son.

Los espacios y tabulaciones externos a los operandos se retiran. En un operando de memoria se reconocen por separado el token de offset, los paréntesis y el token de base; los espacios permitidos alrededor de esos delimitadores se normalizan a la forma `offset(base)`. Por ejemplo, `4 ( x2 )` se conserva como `4(x2)`. El operando ocupa una sola posición en `operands`.

La lectura exige offset y base explícitos y un único par de paréntesis completo. No admite operandos vacíos, paréntesis anidados ni texto adicional después del cierre. La interpretación posterior comprueba que el offset sea un literal admitido y que la base sea un registro válido.

## Comprobaciones y diagnósticos

La lectura comprueba la organización sintáctica de cada línea. Las comprobaciones de significado se realizan después, sobre los datos reconocidos:

| Comprobación                                                                           | Etapa responsable                                     |
|----------------------------------------------------------------------------------------|-------------------------------------------------------|
| Separación de comentarios y reconocimiento de una etiqueta por línea                   | Lectura.                                              |
| Sintaxis de definición de etiqueta y nombres reservados                                | Lectura.                                              |
| Mnemónico admitido, cantidad de operandos, comas y forma de memoria                    | Lectura.                                              |
| Índices de registro y correspondencia de alias                                         | Interpretación de operandos.                          |
| Base de un literal, valor entero, rango del inmediato y paridad del desplazamiento B/J | Interpretación de operandos y resolución de destinos. |
| Definiciones duplicadas y dirección de cada etiqueta                                   | Construcción de la tabla de etiquetas.                |
| Referencias sin definición y desplazamiento relativo al PC                             | Resolución de destinos.                               |
| Palabra de instrucción y bytes little-endian                                           | Codificación y empaquetado.                           |

Por ejemplo, `addi x1, x0, 2048` puede reconocerse en esta etapa, pero se rechaza después porque el inmediato no cabe. `bne x1, x0, fin` también puede reconocerse antes de conocer la definición de `fin`. El éxito de lectura no reemplaza esas comprobaciones.

La lectura recorre las líneas en orden y termina al detectar una línea cuya forma es inválida. El diagnóstico conserva `line` y explica el motivo conforme a la [interfaz pública](assembler_interface.md#diagnósticos). Este orden local no fija una prioridad global entre errores de lectura y errores de las etapas posteriores.

| Código de una línea | Resultado de lectura                                                               |
|---------------------|------------------------------------------------------------------------------------|
| `addi x1 x0 1`      | Error: faltan los separadores de operandos.                                        |
| `halt x1`           | Error: `halt` no admite operandos.                                                 |
| `uno: dos: halt`    | Error: contiene una segunda definición de etiqueta.                                |
| `addi x 1, x0, 1`   | Error: un token de operando está dividido.                                         |
| `lw x1, (x0)`       | Error: falta el offset explícito.                                                  |
| `jalr x0, x1, 0`    | Error: no corresponde a la forma de operandos admitida.                            |
| `nop`               | Error: mnemónico fuera del lenguaje.                                               |
| `add x32, x0, x1`   | Forma reconocida; el registro inexistente se rechaza al interpretar los operandos. |

Los mensajes identifican problemas de traducción. Esta etapa no consulta IMEM ni comprueba la ejecución de accesos o saltos.

## Ejemplo de lectura

Para el siguiente código fuente:

```asm
# Contador

inicio:
    addi x1, x0, 3       # Inicialización
ciclo: addi x1, x1, -1
    bne x1, x0, ciclo
    sw x1, 4 ( x0 )
    halt
```

La salida contiene los siguientes registros, en orden:

| `line` | `label`  | `mnemonic` | `operands`           |
|-------:|----------|------------|----------------------|
|      3 | `inicio` | Ausente    | Vacío.               |
|      4 | Ausente  | `addi`     | `x1`, `x0`, `3`.     |
|      5 | `ciclo`  | `addi`     | `x1`, `x1`, `-1`.    |
|      6 | Ausente  | `bne`      | `x1`, `x0`, `ciclo`. |
|      7 | Ausente  | `sw`       | `x1`, `4(x0)`.       |
|      8 | Ausente  | `halt`     | Vacío.               |

Las líneas 1 y 2 no producen registros. La definición de `inicio` se conserva en su propia línea, mientras que `ciclo` comparte registro con su instrucción. El comentario de la línea 4 se descarta y el operando de memoria de la línea 7 se normaliza sin cambiar sus tokens.

## Condiciones de borde

- Un texto vacío o compuesto solo por comentarios produce una secuencia vacía de registros.
- Un texto que contiene solo etiquetas válidas conserva sus definiciones, aunque no contenga instrucciones.
- Una etiqueta al final del programa se conserva para que la etapa siguiente le asigne la dirección posterior a la última instrucción.
- Las referencias a etiquetas posteriores se conservan como texto; la lectura no exige que su definición haya aparecido antes.
- Una línea con `halt` se reconoce como instrucción y no termina la lectura del archivo. Las instrucciones posteriores continúan perteneciendo al código fuente.
- Los cambios de espacios y comentarios admitidos por el lenguaje conservan los mismos tokens; las líneas originales siguen determinando la relación con el código fuente.

Estas condiciones permiten la traducción vacía y los programas con varias rutas de control definidos en los contratos del assembler. La etapa de lectura no agrega instrucciones ni bytes.

## Estado de diseño

El contrato de lectura y su representación intermedia están aprobados en el [acuerdo de lectura de DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--lectura-del-código-fuente). Los contratos de direcciones, interpretación, codificación, empaquetado y [estructuras Python](assembler_data_model.md) también están aprobados. El cierre conjunto de [DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueba también el lenguaje, la interfaz pública y la organización interna. El [catálogo de pruebas](assembler_tests.md) está aprobado documentalmente; su implementación y ejecución permanecen pendientes. El [entorno e importación](assembler_environment.md) está aprobado.

Las tablas y ejemplos describen resultados esperados del diseño. No constituyen un parser implementado ni pruebas ejecutadas. El cierre de `DEC-SYS-009` se consulta en [DEC-SYS-009](../decisions/DEC-SYS-009.md), y las condiciones de implementación en el [Plan](../plan.md#condición-común-para-comenzar-implementación).

## Referencias y trazabilidad

- [Lenguaje assembler](assembler_language.md): organización del texto, comentarios, instrucciones, operandos y etiquetas.
- [Interfaz del assembler](assembler_interface.md): entrada pública, resultados y diagnósticos.
- [Direcciones y tabla de etiquetas](assembler_addresses.md): ubicación de instrucciones y registro de definiciones.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): estrategia propia, Python y responsabilidad de traducción.
- [Requisitos de software de PC](../requirements.md#8-software-de-pc): traducción de programas y presentación de información.
- [Decisiones pendientes](../decisions/pending_decisions.md): diseño restante y cierre de la decisión.
- [Plan](../plan.md): fases, hitos y condiciones previas a implementación.
