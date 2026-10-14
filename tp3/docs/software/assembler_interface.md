# Interfaz del assembler

- **Tipo:** contrato de interfaces.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Interfaces y contratos](#interfaces-y-contratos)
- [Resultado de la traducción](#resultado-de-la-traducción)
- [Diagnósticos](#diagnósticos)
- [Ejemplos de entrada y salida](#ejemplos-de-entrada-y-salida)
- [Responsabilidades de las capas](#responsabilidades-de-las-capas)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

El assembler traduce un programa del lenguaje del TP3 a una secuencia de bytes de instrucciones. Recibe el código fuente como texto y devuelve la traducción completa y la relación entre direcciones y líneas, o un diagnóstico cuando el programa no puede traducirse.

Este documento define la entrada, los campos del resultado, las condiciones de éxito y error y la distribución de responsabilidades con la aplicación y el protocolo. El [lenguaje assembler](assembler_language.md) fija las instrucciones, operandos y construcciones admitidas. [DEC-SYS-009](../decisions/DEC-SYS-009.md) conserva la aprobación del assembler propio en Python y de su responsabilidad de traducción independiente de la capacidad de IMEM.

## Interfaces y contratos

### Operación de ensamblado

La interfaz pública es:

```python
assemble(source_text: str) -> AssemblyResult
```

| Dirección | Nombre        | Tipo de Python   | Productor  | Consumidor | Función                                                 |
|-----------|---------------|------------------|------------|------------|---------------------------------------------------------|
| Entrada   | `source_text` | `str`            | Aplicación | Assembler  | Texto completo del programa.                            |
| Salida    | Resultado     | `AssemblyResult` | Assembler  | Aplicación | Traducción completa y relación PC–línea, o diagnóstico. |

La aplicación obtiene `source_text` desde un editor o mediante la lectura de un archivo UTF-8. La lectura, el nombre del archivo y los errores de acceso o decodificación pertenecen a esa capa. Las mismas entradas y salidas se utilizan desde una CLI, TUI o GUI.

La numeración de líneas comienza en uno y corresponde al texto recibido. Las líneas vacías, los comentarios y las definiciones de etiquetas conservan su posición en esa numeración.

## Resultado de la traducción

`AssemblyResult` representa uno de dos resultados: traducción exitosa o error. Los campos y sus condiciones de entrega están aprobados en [Empaquetado y resultado](assembler_packing.md):

| Campo        | Tipo de Python       | Traducción exitosa                                 | Error de traducción |
|--------------|----------------------|----------------------------------------------------|---------------------|
| `image`      | `bytes` o `None`     | Bytes de la traducción completa.                   | `None`.             |
| `pc_to_line` | `dict[int, int]`     | Dirección de cada instrucción y su línea original. | Diccionario vacío.  |
| `error`      | Diagnóstico o `None` | `None`.                                            | Un diagnóstico.     |

Con `error=None`, `image` contiene todos los bytes traducidos. Con un diagnóstico, `image=None` y `pc_to_line={}`; cualquier traducción parcial se descarta. La aplicación utiliza únicamente resultados completos para solicitar una carga.

El éxito de traducción acredita que el código puede representarse mediante las instrucciones admitidas. La aceptación de su tamaño, la finalización de la carga y el resultado de la ejecución pertenecen a operaciones posteriores.

### Imagen de instrucciones

`image` contiene los bytes de las instrucciones en orden, desde la dirección cero. Cada instrucción aporta cuatro bytes little-endian; el resultado es contiguo y su tamaño es múltiplo de cuatro por construcción.

El contenido corresponde únicamente a las instrucciones traducidas. La cabecera UART y el campo de tamaño se forman en la capa de protocolo según [LOAD](../protocol.md#cargar-una-imagen). La relación PC–línea se conserva en la aplicación y no se incorpora al contenido transmitido. El assembler tampoco genera una imagen inicial de DMEM.

El tamaño y la cantidad de instrucciones se derivan de los bytes:

```text
tamaño en bytes = len(image)
cantidad de instrucciones = len(image) / 4
```

El resultado conserva una única representación de la traducción. Estos valores no requieren campos independientes ni una segunda copia como lista de palabras.

La cantidad de instrucciones no se limita según IMEM. Un programa puede traducirse correctamente y recibir `INVALID_SIZE` al solicitar su carga.

### Relación entre PC y línea

`pc_to_line` contiene una entrada por instrucción emitida. Las claves son las direcciones `0`, `4`, `8`, etc., hasta la última instrucción de la imagen. Cada valor identifica la línea original donde aparece esa instrucción.

Una definición de etiqueta en una línea separada no agrega una entrada. Si una etiqueta y una instrucción comparten línea, la dirección de la instrucción se relaciona con esa misma línea.

La aplicación utiliza `fault_pc` recibido por Debug para localizar la instrucción causante. La relación se conserva asociada al programa efectivamente cargado en la sesión. Cuando el fault corresponde a un fetch fuera de la imagen, la dirección carece de entrada: la aplicación informa esa dirección sin atribuirle una línea del programa.

La conservación de estos datos durante la sesión y su presentación pertenecen al diseño de la aplicación. El significado de `fault_pc` se consulta en [Faults y terminación](../architecture/session/faults_and_termination.md).

### Traducción vacía

Un texto vacío o compuesto únicamente por comentarios y etiquetas válidas produce:

```text
image      = b""
pc_to_line = {}
error      = None
```

No existen instrucciones que traducir ni se agrega `halt` automáticamente. Los cero bytes resultantes no constituyen una imagen ejecutable. Si se solicita su carga, la FPGA responde `INVALID_SIZE`; ese rechazo corresponde al tamaño de `LOAD`, no a la codificación del programa.

## Diagnósticos

Un error de traducción se describe mediante los siguientes campos:

| Campo     | Tipo de Python | Función                                      |
|-----------|----------------|----------------------------------------------|
| `line`    | `int`          | Línea original del error, contada desde uno. |
| `message` | `str`          | Explicación del motivo.                      |

Se devuelve un diagnóstico por llamada y se descarta cualquier resultado parcial. La corrección del programa da lugar a una nueva operación de ensamblado. [Organización y operación](assembler_organization.md#orden-de-detección-de-errores) define completar las etapas en orden y detener el recorrido ante el primer rechazo detectado. Ese diagnóstico puede corresponder a una línea posterior a otro error que todavía no se comprobó; no se exige continuar el análisis sobre líneas inválidas.

Los diagnósticos corresponden a los rechazos del [lenguaje](assembler_language.md#validación-estática-y-ejecución): sintaxis, instrucciones y construcciones no soportadas, operandos, registros, literales, rangos de inmediatos y etiquetas. Los límites de inmediatos forman parte de la codificación y se comprueban independientemente de IMEM. Los errores de capacidad y el resultado de una carga pertenecen al protocolo y a la aplicación.

El assembler entrega el diagnóstico como datos. La interfaz de usuario decide cómo presentar `line` y `message`. Por ejemplo:

```text
Línea 1: el inmediato 2048 está fuera del rango permitido [-2048, 2047].
```

El ejemplo ilustra la información requerida, sin fijar un formato de impresión. El manejo de defectos internos del software pertenece a la implementación y a la aplicación; esos defectos no se clasifican como errores del código assembler.

## Ejemplos de entrada y salida

### Traducción exitosa

Para el siguiente código fuente:

```asm
# Inicializa un registro y finaliza
inicio:
    addi x1, x0, 5
    halt
```

El resultado es:

```text
image      = bytes 93 00 50 00 0B 00 00 00
pc_to_line = {0: 3, 4: 4}
error      = None
```

La traducción ocupa ocho bytes. La etiqueta `inicio` se define en la línea 2; la instrucción de dirección cero aparece en la línea 3.

### Error de traducción

Para el siguiente código fuente:

```asm
addi x1, x0, 2048
halt
```

El resultado es:

```text
image         = None
pc_to_line    = {}
error.line    = 1
error.message = "El inmediato 2048 está fuera del rango permitido [-2048, 2047]."
```

El inmediato de la primera instrucción no cabe en el campo de 12 bits con signo. La instrucción `halt` de la línea siguiente no permite completar la traducción del programa.

### Fault durante la ejecución

La instrucción `sw x1, 1(x0)` es traducible porque sus operandos y su inmediato admiten codificación. El acceso desalineado se detecta durante la ejecución y se reporta por Debug. Esta separación se rige por [Validación estática y ejecución](assembler_language.md#validación-estática-y-ejecución).

## Responsabilidades de las capas

| Componente                       | Responsabilidad                                                                                             |
|----------------------------------|-------------------------------------------------------------------------------------------------------------|
| Aplicación / interfaz de usuario | Obtener el texto, seleccionar el perfil común, invocar el assembler y presentar el resultado o diagnóstico. |
| Assembler                        | Validar el lenguaje, traducir las instrucciones a bytes y relacionar PCs con líneas.                        |
| Protocolo / transporte           | Construir y enviar `LOAD`, gestionar sus respuestas y los errores de comunicación.                          |
| Aplicación / Debug               | Interpretar los snapshots y relacionar sus PCs con el programa cargado.                                     |
| FPGA / controlador de protocolo  | Validar el tamaño contra IMEM antes de aceptar `LOAD` y responder `INVALID_SIZE` si no es admisible.        |

La operación de ensamblado termina al devolver su resultado. La carga y los comandos `RUN` y `STEP` se realizan mediante los intercambios definidos por el protocolo.

## Estado de diseño

La estrategia propia, Python con biblioteca estándar y la separación entre traducción y validación de tamaño están aprobadas en [DEC-SYS-009](../decisions/DEC-SYS-009.md). El empaquetado, la relación PC–línea y las condiciones de entrega de los campos del resultado están aprobados en su [acuerdo de empaquetado](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--empaquetado-y-resultado). Las clases y atributos del resultado y diagnóstico están aprobados en el [acuerdo de estructuras de datos](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--estructuras-de-datos). La firma y las reglas de diagnósticos, incluido el diagnóstico único por llamada, están aprobadas en el cierre conjunto de DEC-SYS-009.

[Estructuras de datos](assembler_data_model.md) define las clases y atributos aprobados de los registros internos, `AssemblyResult` y `AssemblyDiagnostic`.

[Organización y operación](assembler_organization.md) define el módulo, las funciones y la captura específica de errores de código fuente en `assemble`, con un diagnóstico por llamada.

[Pruebas del assembler](assembler_tests.md) define la comprobación aprobada de bytes, mapas, entrada vacía y diagnósticos desde la operación pública. Su implementación y ejecución permanecen pendientes.

[Entorno e importación](assembler_environment.md) define Python 3.11 como mínimo y el acceso público aprobado mediante `software.assembler`.

La [lectura del código fuente](assembler_source_reader.md) desarrolla la primera etapa interna aprobada: reconocimiento de líneas y datos entregados para su traducción. [Direcciones y tabla de etiquetas](assembler_addresses.md) desarrolla el contrato aprobado de ubicación de instrucciones y definiciones. [Interpretación de operandos](assembler_operands.md) define la conversión aprobada de esos datos a los valores que necesita la codificación. [Codificación de instrucciones](assembler_encoding.md) define la tabla y fórmulas aprobadas para formar las palabras. [Empaquetado y resultado](assembler_packing.md) define la formación aprobada de bytes y relación PC–línea. La organización interna y el contrato público completo están aprobados en [DEC-SYS-009](../decisions/DEC-SYS-009.md); las condiciones de D0/M6 se consultan en el [Plan](../plan.md#28-hitos-formales-del-proyecto). El [catálogo de pruebas](assembler_tests.md) está aprobado documentalmente; su implementación y ejecución permanecen pendientes.

## Referencias y trazabilidad

- [Requisitos de software de PC](../requirements.md#8-software-de-pc): selección del programa, traducción, carga y presentación de información al usuario.
- [Lenguaje assembler](assembler_language.md): instrucciones, sintaxis y rechazos de traducción.
- [Lectura del código fuente](assembler_source_reader.md): reconocimiento de líneas y representación intermedia.
- [Direcciones y tabla de etiquetas](assembler_addresses.md): asignación de PCs y definiciones de símbolos.
- [Interpretación de operandos](assembler_operands.md): valores numéricos para la codificación y resolución de destinos.
- [Codificación de instrucciones](assembler_encoding.md): tabla de campos fijos y fórmulas de formación de palabras.
- [Empaquetado y resultado](assembler_packing.md): bytes little-endian y relación PC–línea de la traducción completa.
- [Estructuras de datos](assembler_data_model.md): clases y tipos de campo aprobados para Python.
- [Organización y operación](assembler_organization.md): coordinación aprobada de etapas y entrega del diagnóstico.
- [Pruebas del assembler](assembler_tests.md): casos y expectativas independientes para el resultado público.
- [Entorno e importación](assembler_environment.md): versión mínima y acceso al módulo aprobados.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): estrategia propia, lenguaje de implementación y distribución de responsabilidades.
- [Protocolo UART](../protocol.md): validación de tamaño, intercambio `LOAD`, respuestas y representación de Debug.
- [Faults y terminación](../architecture/session/faults_and_termination.md): causas de error durante ejecución y significado de `fault_pc`.
- [Arquitectura de Debug](../architecture/debug/debug_architecture.md): contenido y coherencia de los snapshots.
- [Decisiones pendientes](../decisions/pending_decisions.md): diseño restante y condiciones de cierre.
- [Plan](../plan.md): fases e hitos de desarrollo y verificación.
