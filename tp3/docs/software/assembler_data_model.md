# Estructuras de datos del assembler

- **Tipo:** diseño de software.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Representación común](#representación-común)
- [Datos entre etapas](#datos-entre-etapas)
- [Líneas reconocidas](#líneas-reconocidas)
- [Direcciones y definiciones](#direcciones-y-definiciones)
- [Instrucciones interpretadas](#instrucciones-interpretadas)
- [Instrucciones codificadas](#instrucciones-codificadas)
- [Resultado y diagnóstico](#resultado-y-diagnóstico)
- [Ejemplo de transformación](#ejemplo-de-transformación)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

Las etapas aprobadas del assembler especifican qué datos reciben y producen. Este documento define sus nombres de clase, tipos de campo y contenedores en Python, conforme a la elección de biblioteca estándar de [DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--lenguaje-de-implementación).

El modelo conserva la separación entre texto reconocido, instrucciones con dirección, operandos interpretados y palabras codificadas. La aplicación recibe el resultado público completo; los datos de las etapas pertenecen al recorrido interno del assembler.

## Representación común

Los registros se representan mediante clases `dataclass` de la biblioteca estándar. Sus campos se consultan por nombre, como `instruction.pc` o `diagnostic.line`. Se utilizan dataclasses simples, con sus opciones por defecto y los campos indicados en las tablas.

Los tipos básicos son `str` para nombres y operandos textuales, `int` para líneas, direcciones, registros y valores numéricos, y `bytes` para la imagen final. `None` representa un campo ausente. Las secuencias de registros y de operandos utilizan `list`; las consultas por nombre o PC utilizan `dict`.

Las anotaciones describen los tipos esperados. La comprobación de sintaxis, rangos y campos presentes corresponde a las etapas aprobadas; la creación de un registro no reemplaza esas comprobaciones.

Cada etapa construye los registros de su salida. Un registro de texto no se convierte en uno interpretado mediante cambios sobre sus campos. Las líneas y PCs se conservan al construir los registros posteriores.

Todos los campos se proporcionan explícitamente al crear un registro, incluidos los ausentes con `None`. Cada llamada de ensamblado utiliza sus propias listas y diccionarios; las etiquetas y los resultados de un programa no se comparten con llamadas posteriores.

## Datos entre etapas

| Productor | Datos de salida correcta | Consumidor |
|---|---|---|
| Lectura | `list[SourceRecord]` | Asignación de direcciones. |
| Asignación de direcciones | `list[LocatedInstruction]` y `dict[str, LabelDefinition]` | Interpretación y resolución. |
| Interpretación y resolución | `list[InterpretedInstruction]` | Codificación. |
| Codificación | `list[EncodedInstruction]` | Empaquetado. |
| Empaquetado | `AssemblyResult` completo | Aplicación. |

La salida de direcciones comprende la lista y la tabla de etiquetas, conforme a [Direcciones y tabla de etiquetas](assembler_addresses.md). Las dos colecciones forman la salida conjunta de esa etapa.

Las etapas que detectan errores de código fuente producen la información de `AssemblyDiagnostic`. [Organización y operación](assembler_organization.md#propagación-de-diagnósticos) define su propagación hasta la operación pública mediante una excepción interna específica; el diagnóstico público conserva su representación como datos.

## Líneas reconocidas

`SourceRecord` representa una línea reconocida por la [lectura](assembler_source_reader.md):

| Campo | Tipo | Contenido |
|---|---|---|
| `line` | `int` | Número de línea original, desde uno. |
| `label` | `str` o `None` | Nombre de la etiqueta definida, cuando existe. |
| `mnemonic` | `str` o `None` | Mnemónico de la instrucción, cuando existe. |
| `operands` | `list[str]` | Operandos reconocidos en su orden. |

Una etiqueta aislada tiene `label` presente, `mnemonic=None` y `operands=[]`. Una instrucción sin etiqueta tiene `label=None`. `halt` tiene `mnemonic="halt"` y `operands=[]`; su lista vacía no representa ausencia de instrucción.

Las líneas vacías o de comentarios no producen registros. Los operandos todavía son texto, incluidos registros, literales y referencias a etiquetas.

## Direcciones y definiciones

`LocatedInstruction` representa una instrucción después de asignar su dirección:

| Campo | Tipo | Contenido |
|---|---|---|
| `line` | `int` | Línea original. |
| `pc` | `int` | Dirección en bytes desde cero. |
| `mnemonic` | `str` | Mnemónico reconocido. |
| `operands` | `list[str]` | Operandos textuales en su orden. |

La lista contiene únicamente instrucciones; `mnemonic` siempre está presente. Las etiquetas se conservan en una tabla de tipo `dict[str, LabelDefinition]`. Cada nombre exacto es una clave y su valor contiene:

| Campo de `LabelDefinition` | Tipo | Contenido |
|---|---|---|
| `address` | `int` | Dirección en bytes asociada a la definición. |
| `line` | `int` | Línea de definición, para los diagnósticos. |

El nombre se conserva en la clave del diccionario. La dirección y la línea permanecen juntas en `LabelDefinition`, conforme al contrato aprobado. La definición duplicada se detecta antes de incorporar otra entrada con el mismo nombre.

## Instrucciones interpretadas

`InterpretedInstruction` representa los valores comprobados por la [interpretación de operandos](assembler_operands.md):

| Campo | Tipo | Contenido |
|---|---|---|
| `line` | `int` | Línea original. |
| `pc` | `int` | Dirección asignada. |
| `mnemonic` | `str` | Operación que determina los campos presentes. |
| `rd` | `int` o `None` | Registro destino, cuando se utiliza. |
| `rs1` | `int` o `None` | Primer registro fuente o base, cuando se utiliza. |
| `rs2` | `int` o `None` | Segundo registro fuente o dato del store, cuando se utiliza. |
| `imm` | `int` o `None` | Inmediato o desplazamiento comprobado, cuando se utiliza. |

Los campos presentes son los definidos para cada familia en el contrato de operandos. Los campos restantes reciben `None`. `rd=0`, `rs1=0`, `rs2=0` e `imm=0` son valores presentes; su ausencia se comprueba mediante `is None`.

Los negativos permanecen como enteros con signo. Las etiquetas ya están resueltas a desplazamientos. Este registro conserva los valores necesarios para codificar y no incorpora una copia de los operandos textuales.

## Instrucciones codificadas

`EncodedInstruction` representa la salida de [codificación](assembler_encoding.md):

| Campo | Tipo | Contenido |
|---|---|---|
| `line` | `int` | Línea original. |
| `pc` | `int` | Dirección asignada. |
| `word` | `int` | Patrón de 32 bits como entero de cero a `0xffffffff`. |

El empaquetado utiliza `word` para formar los cuatro bytes y `line` con `pc` para el mapa. El resultado público contiene los bytes completos y el mapa; la lista codificada pertenece a los datos internos.

## Resultado y diagnóstico

`AssemblyDiagnostic` reúne la información de un error del código fuente:

| Campo | Tipo | Contenido |
|---|---|---|
| `line` | `int` | Línea original del error, desde uno. |
| `message` | `str` | Motivo del rechazo. |

El diagnóstico se consulta mediante atributos, como `result.error.line`, cuando `error` está presente. La aplicación agrega el nombre del archivo y decide su presentación. Los defectos internos del software y los errores de carga o comunicación conservan las responsabilidades de [Interfaz del assembler](assembler_interface.md#diagnósticos).

`AssemblyResult` conserva los campos y condiciones de entrega aprobados en [Empaquetado y resultado](assembler_packing.md):

| Campo | Tipo | Contenido |
|---|---|---|
| `image` | `bytes` o `None` | Traducción completa, o ausencia ante error. |
| `pc_to_line` | `dict[int, int]` | PC de cada instrucción y su línea original. |
| `error` | `AssemblyDiagnostic` o `None` | Diagnóstico, o ausencia ante éxito. |

Una traducción exitosa tiene `error=None` e `image` de tipo `bytes`, incluido `b""` cuando no hay instrucciones. Un error tiene `image=None`, `pc_to_line={}` y un diagnóstico. La aplicación distingue estos casos consultando `error`; una imagen vacía sigue siendo un resultado exitoso de traducción.

El modelo define las clases y los atributos. [Organización y operación](assembler_organization.md#organización-del-módulo) define su ubicación en un módulo junto con la operación `assemble`. [Entorno e importación](assembler_environment.md#ubicación-e-importación) define el acceso aprobado mediante `software.assembler`.

## Ejemplo de transformación

Para una instrucción ubicada en la línea 3:

```asm
inicio: addi x1, x0, -1
```

Los valores de cada representación son:

| Representación | Campos |
|---|---|
| `SourceRecord` | `line=3`, `label="inicio"`, `mnemonic="addi"`, `operands=["x1", "x0", "-1"]`. |
| `LocatedInstruction` | `line=3`, `pc=0`, `mnemonic="addi"`, `operands=["x1", "x0", "-1"]`. |
| `LabelDefinition`, bajo la clave `"inicio"` | `address=0`, `line=3`. |
| `InterpretedInstruction` | `line=3`, `pc=0`, `mnemonic="addi"`, `rd=1`, `rs1=0`, `rs2=None`, `imm=-1`. |
| `EncodedInstruction` | `line=3`, `pc=0`, `word=0xfff00093`. |
| `AssemblyResult` | `image=bytes 93 00 F0 FF`, `pc_to_line={0: 3}`, `error=None`. |

La tabla supone que es la primera instrucción del programa. El registro fuente conserva la definición; la tabla de etiquetas conserva su dirección y línea; los registros posteriores mantienen la ubicación de la instrucción hasta producir sus bytes y mapa.

## Estado de diseño

Las siete clases de datos y sus contenedores están aprobados en el [acuerdo de DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--estructuras-de-datos). Cada etapa construye un registro nuevo con la forma de su salida, conservando los datos necesarios para la siguiente. El cierre conjunto de [DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueba también el lenguaje, la interfaz pública y la organización interna. El [catálogo de pruebas](assembler_tests.md) está aprobado documentalmente; su implementación y ejecución permanecen pendientes. El [entorno e importación](assembler_environment.md) está aprobado.

[Organización y operación](assembler_organization.md) define las funciones, el módulo y la coordinación aprobados, incluida la propagación interna de diagnósticos.

Las tablas describen el diseño de las representaciones. La implementación y ejecución de pruebas permanecen posteriores al cierre global del [Plan](../plan.md#condición-común-para-comenzar-implementación). El estado completo de `DEC-SYS-009` se consulta en [DEC-SYS-009](../decisions/DEC-SYS-009.md).

## Referencias y trazabilidad

- [Lectura del código fuente](assembler_source_reader.md): registros con etiqueta, mnemónico y operandos textuales.
- [Direcciones y tabla de etiquetas](assembler_addresses.md): PCs y definiciones con dirección y línea.
- [Interpretación de operandos](assembler_operands.md): campos presentes, índices e inmediatos comprobados.
- [Codificación de instrucciones](assembler_encoding.md): palabras de 32 bits y ubicación original.
- [Empaquetado y resultado](assembler_packing.md): imagen y mapa completos.
- [Interfaz del assembler](assembler_interface.md): operación pública y diagnósticos aprobados.
- [Organización y operación](assembler_organization.md): módulo, funciones y propagación interna de errores.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): elección de Python y acuerdos de diseño.
- [Plan](../plan.md): condiciones previas a la implementación.
