# Organización y operación del assembler

- **Tipo:** diseño de software.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Organización del módulo](#organización-del-módulo)
- [Interfaces de las funciones](#interfaces-de-las-funciones)
- [Recorrido de assemble](#recorrido-de-assemble)
- [Propagación de diagnósticos](#propagación-de-diagnósticos)
- [Orden de detección de errores](#orden-de-detección-de-errores)
- [Datos y llamadas independientes](#datos-y-llamadas-independientes)
- [Ejemplos de operación](#ejemplos-de-operación)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

La operación pública `assemble(source_text: str) -> AssemblyResult` coordina las etapas aprobadas de traducción. Recibe el texto, ejecuta sus transformaciones y entrega los bytes y el mapa completos, o un diagnóstico del código fuente.

Este documento define la ubicación del módulo, las funciones internas y el mecanismo de propagación de errores. Utiliza las clases aprobadas en [Estructuras de datos](assembler_data_model.md) y conserva las condiciones de [Interfaz del assembler](assembler_interface.md) y [Empaquetado y resultado](assembler_packing.md).

## Organización del módulo

El assembler se organiza inicialmente en un único archivo, `software/assembler.py`, dentro del directorio de software del proyecto. El alcance acotado permite mantener juntas las clases, tablas y funciones de traducción, con una función por etapa y nombres que identifican sus responsabilidades.

La aplicación utiliza tres elementos públicos del módulo:

| Elemento             | Función                                                 |
|----------------------|---------------------------------------------------------|
| `assemble`           | Ejecutar una traducción completa.                       |
| `AssemblyResult`     | Consultar la imagen, el mapa y el eventual diagnóstico. |
| `AssemblyDiagnostic` | Consultar la línea y el motivo de un error.             |

Las otras cinco clases aprobadas representan datos internos. Las funciones internas y la excepción de propagación utilizan nombres comenzados por `_`. La aplicación invoca la operación completa y recibe su resultado público.

El módulo reúne:

- las siete dataclasses aprobadas;
- las tablas de instrucciones, campos de codificación y alias de registros;
- la excepción interna `_AssemblyError`;
- `assemble` y las funciones de las cinco etapas;
- los auxiliares de reconocimiento y conversión que necesitan esas etapas.

Las tablas contienen los datos del [lenguaje](assembler_language.md) y de [codificación](assembler_encoding.md). La tabla de instrucciones proporciona los mnemónicos admitidos al reconocimiento y los campos fijos al encoder. Los alias utilizan una tabla común de nombre a índice. Estas tablas se consultan durante el ensamblado y no se modifican por programa.

La organización de la aplicación y el transporte conservan su diseño independiente. [Entorno e importación](assembler_environment.md) define la versión mínima de Python, los marcadores de paquete y la importación `software.assembler` aprobados. El archivo indicado es una ubicación prevista; su creación corresponde a la implementación posterior.

## Interfaces de las funciones

Las firmas y resultados correctos son:

| Función                                     | Entrada                                                   | Salida correcta                                               | Error de código fuente                                        |
|---------------------------------------------|-----------------------------------------------------------|---------------------------------------------------------------|---------------------------------------------------------------|
| `assemble(source_text)`                     | `str`                                                     | `AssemblyResult`                                              | Se devuelve dentro de `AssemblyResult.error`.                 |
| `_read_source(source_text)`                 | `str`                                                     | `list[SourceRecord]`                                          | Propaga `_AssemblyError` con línea y motivo.                  |
| `_assign_addresses(records)`                | `list[SourceRecord]`                                      | `tuple[list[LocatedInstruction], dict[str, LabelDefinition]]` | Propaga `_AssemblyError` ante definición duplicada.           |
| `_interpret_operands(instructions, labels)` | `list[LocatedInstruction]` y `dict[str, LabelDefinition]` | `list[InterpretedInstruction]`                                | Propaga `_AssemblyError` ante un operando o destino inválido. |
| `_encode_instructions(instructions)`        | `list[InterpretedInstruction]`                            | `list[EncodedInstruction]`                                    | Los errores del código fuente ya fueron comprobados.          |
| `_pack_result(instructions)`                | `list[EncodedInstruction]`                                | `AssemblyResult` con `error=None`                             | La entrada válida permite formar el resultado completo.       |

La salida de direcciones es una tupla de dos elementos: primero la lista de instrucciones y después el diccionario de etiquetas. La tupla agrupa las dos colecciones aprobadas y no agrega una clase de datos.

Las funciones utilizan las entradas que necesitan para cumplir su etapa. La interpretación recibe la tabla completa, lo que admite referencias adelantadas. La codificación y el empaquetado utilizan los registros de la etapa anterior y no consultan nuevamente el código fuente ni las etiquetas.

## Recorrido de assemble

Cada llamada ejecuta esta secuencia:

1. `_read_source` reconoce todas las líneas del texto y entrega sus registros.
2. `_assign_addresses` ubica las instrucciones y construye la tabla completa de etiquetas.
3. `_interpret_operands` convierte registros y literales, resuelve destinos y comprueba sus rangos.
4. `_encode_instructions` forma una palabra de 32 bits por instrucción.
5. `_pack_result` forma los bytes little-endian, el mapa PC–línea y el resultado exitoso.
6. `assemble` devuelve ese resultado a la aplicación.

Una etapa comienza cuando la anterior terminó correctamente. Las listas conservan el orden del programa y cada etapa construye sus nuevos registros, conforme al modelo aprobado.

La lista vacía atraviesa codificación y empaquetado normalmente. Un texto que solo define etiquetas conserva su tabla durante la asignación, pero produce cero instrucciones y el resultado exitoso vacío. Las definiciones duplicadas siguen siendo errores aunque no haya instrucciones.

## Propagación de diagnósticos

`_AssemblyError` es una excepción interna específica, derivada de `Exception`. Conserva un atributo `diagnostic` de tipo `AssemblyDiagnostic`, con la línea original y el motivo del rechazo.

Cuando una función reconoce un error del lenguaje, crea ese diagnóstico y lanza `_AssemblyError`. La propagación abandona la etapa y las llamadas auxiliares involucradas. `assemble` captura esa excepción y devuelve:

```text
image      = None
pc_to_line = {}
error      = diagnostic
```

El mecanismo permite que las funciones entreguen directamente su salida correcta y que un error interrumpa el recorrido hasta el coordinador. La aplicación recibe el diagnóstico como datos dentro de `AssemblyResult`, conforme a su contrato público.

La captura se limita a `_AssemblyError`. Un defecto interno, una entrada de tipo distinto del contrato o un fallo de recursos conserva su excepción y no se presenta como un error del código assembler. Por ejemplo, los auxiliares convierten un literal mal escrito en un diagnóstico cuando corresponde al lenguaje; una excepción inesperada de programación no se transforma mediante una captura general.

Al detectar un error se entrega un solo diagnóstico y se descartan los datos parciales. Las etapas restantes no se ejecutan. El resultado de un error no contiene bytes ni entradas de mapa de las instrucciones que hayan podido procesarse antes.

## Orden de detección de errores

El orden sigue las etapas completas: lectura, direcciones e interpretación. Dentro de cada una, los registros se recorren en orden del código fuente y se informa el primer rechazo detectado por esa etapa. No se exige analizar el programa restante para reunir otros errores.

Un error de lectura puede aparecer en una línea posterior a un error de rango o de símbolo todavía no comprobado. La operación informa el error encontrado por el recorrido, no necesariamente el de menor número de línea entre todos los problemas del programa.

Para una misma instrucción con varios operandos inválidos, basta con identificar uno de esos rechazos con su línea y motivo. No se fija una prioridad adicional entre comprobaciones de la misma instrucción ni un texto literal obligatorio para cada mensaje.

## Datos y llamadas independientes

Cada llamada construye sus registros, tabla de etiquetas, imagen y mapa. Las tablas compartidas contienen únicamente definiciones del lenguaje y codificación; no conservan datos de programas ensamblados anteriormente.

El resultado exitoso se publica al finalizar el empaquetado. Los registros intermedios permanecen internos y la aplicación recibe únicamente la representación pública. Un error abandona los datos de esa llamada sin modificar un resultado entregado anteriormente.

La operación trabaja con texto y datos en memoria. La lectura de archivos, la carga UART, las respuestas FPGA y la conservación del mapa asociado al programa cargado pertenecen a sus capas, según [Interfaz del assembler](assembler_interface.md#responsabilidades-de-las-capas).

## Ejemplos de operación

### Traducción completa

Para el código fuente:

```asm
inicio: addi x1, x0, 5
halt
```

| Etapa          | Resultado relevante                                                 |
|----------------|---------------------------------------------------------------------|
| Lectura        | Dos registros; `inicio` se define en la línea 1.                    |
| Direcciones    | Instrucciones en PCs 0 y 4; `inicio` tiene dirección 0.             |
| Interpretación | `addi` tiene `rd=1`, `rs1=0` e `imm=5`; `halt` carece de operandos. |
| Codificación   | Palabras `0x00500093` y `0x0000000b`.                               |
| Empaquetado    | Ocho bytes y dos entradas PC–línea.                                 |

El resultado público es:

```text
image      = bytes 93 00 50 00 0B 00 00 00
pc_to_line = {0: 1, 4: 2}
error      = None
```

### Errores en etapas diferentes

Para el código fuente:

```asm
addi x1, x0, 2048
nop
```

La primera línea tiene una forma reconocible; su inmediato se comprueba al interpretar. La segunda utiliza un mnemónico fuera del lenguaje, por lo que la lectura propaga un diagnóstico de línea 2 y `assemble` devuelve el resultado de error. Las etapas de direcciones e interpretación no se ejecutan.

Si se reemplaza `nop` por `halt`, la lectura y la asignación terminan correctamente. La interpretación detecta el inmediato fuera de rango de la línea 1 y propaga su diagnóstico. La codificación y el empaquetado no se ejecutan.

Ambos rechazos producen `image=None`, `pc_to_line={}` y un único diagnóstico con la línea y el motivo correspondiente.

## Estado de diseño

El módulo, sus funciones, la coordinación de etapas y el mecanismo de propagación están aprobados junto con el lenguaje y la interfaz pública en el cierre completo de [DEC-SYS-009](../decisions/DEC-SYS-009.md). Las clases, transformaciones y condiciones de entrega conservan sus acuerdos aprobados.

[Pruebas del assembler](assembler_tests.md) define el catálogo aprobado de entradas y expectativas independientes, incluidas las variantes de orden de detección y llamadas sucesivas. Su implementación y ejecución permanecen pendientes.

[Entorno e importación](assembler_environment.md) define el contrato aprobado de intérprete, paquetes y ejecución del catálogo.

Las firmas y secuencias describen contratos de diseño. La implementación y ejecución de pruebas permanecen posteriores al cierre global del [Plan](../plan.md#condición-común-para-comenzar-implementación). El cierre completo de `DEC-SYS-009` se consulta en [DEC-SYS-009](../decisions/DEC-SYS-009.md).

## Referencias y trazabilidad

- [Interfaz del assembler](assembler_interface.md): entrada, resultado, diagnósticos y responsabilidades públicas.
- [Estructuras de datos](assembler_data_model.md): clases y tipos aprobados entre etapas.
- [Lectura del código fuente](assembler_source_reader.md): comprobaciones sintácticas y orden local de detección.
- [Direcciones y tabla de etiquetas](assembler_addresses.md): salida conjunta y diagnóstico de definición duplicada.
- [Interpretación de operandos](assembler_operands.md): comprobaciones de registros, literales, rangos y destinos.
- [Codificación de instrucciones](assembler_encoding.md): palabras completas a partir de operandos comprobados.
- [Empaquetado y resultado](assembler_packing.md): imagen, mapa y condiciones de entrega completa.
- [Lenguaje assembler](assembler_language.md): formas admitidas y rechazos de traducción.
- [Pruebas del assembler](assembler_tests.md): selección aprobada y expectativas de la operación pública.
- [Entorno e importación](assembler_environment.md): versión mínima, ruta pública y ejecución de pruebas aprobadas.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): estrategia y acuerdos parciales.
- [Plan](../plan.md): condiciones previas a la implementación.
