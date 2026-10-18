# Direcciones y tabla de etiquetas del assembler

- **Tipo:** diseño de software.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Interfaces y contratos](#interfaces-y-contratos)
- [Asignación de direcciones](#asignación-de-direcciones)
- [Tabla de etiquetas](#tabla-de-etiquetas)
- [Instrucciones con dirección](#instrucciones-con-dirección)
- [Diagnósticos](#diagnósticos)
- [Ejemplo de asignación](#ejemplo-de-asignación)
- [Condiciones de borde](#condiciones-de-borde)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

La asignación de direcciones establece la posición de cada instrucción en la traducción y construye la tabla de etiquetas definidas por el programa. Utiliza los registros producidos por la [lectura del código fuente](assembler_source_reader.md), conservando el orden del programa y los números de línea originales.

El [lenguaje assembler](assembler_language.md) fija instrucciones de cuatro bytes, origen cero y etiquetas que no ocupan espacio. Esta etapa materializa esas reglas en datos para la interpretación y resolución posteriores. Las referencias a etiquetas y los operandos numéricos permanecen como texto; sus valores y rangos se comprueban después.

## Interfaces y contratos

| Dirección        | Dato                        | Representación conceptual                                           | Productor                 | Consumidor                      | Función                                              |
|------------------|-----------------------------|---------------------------------------------------------------------|---------------------------|---------------------------------|------------------------------------------------------|
| Entrada          | Líneas reconocidas          | Secuencia de registros con `line`, `label`, `mnemonic` y `operands` | Lectura                   | Asignación de direcciones       | Definiciones e instrucciones del programa, en orden. |
| Salida correcta  | Instrucciones con dirección | Secuencia de registros                                              | Asignación de direcciones | Interpretación de operandos     | Instrucciones con su PC y línea original.            |
| Salida correcta  | Tabla de etiquetas          | Nombre → definición                                                 | Asignación de direcciones | Resolución de destinos          | Dirección y línea de definición de cada etiqueta.    |
| Salida con error | Diagnóstico                 | Línea y motivo                                                      | Asignación de direcciones | Operación pública de ensamblado | Informar una definición duplicada.                   |

Una operación correcta entrega la secuencia completa de instrucciones y la tabla completa de etiquetas. Si encuentra una definición duplicada, entrega un diagnóstico y descarta ambos resultados parciales. La operación pública conserva las condiciones de error de [AssemblyResult](assembler_interface.md#resultado-de-la-traducción).

Las representaciones de esta etapa son datos internos del assembler. La aplicación recibe únicamente el resultado público de una traducción completa.

## Asignación de direcciones

La dirección de la siguiente instrucción comienza en cero. Los registros de lectura se recorren en orden:

1. Si el registro define una etiqueta, se comprueba que su nombre no esté registrado y se asocia con la dirección actual.
2. Si contiene una instrucción, se entrega su registro con esa dirección como `pc`.
3. Después de una instrucción, la dirección avanza cuatro bytes. Una definición sin instrucción conserva la dirección actual.

La etiqueta de una línea que también contiene una instrucción se registra antes de avanzar la dirección. Por lo tanto, identifica la propia instrucción de esa línea.

Para la instrucción de índice `i`, contado desde cero:

```text
pc = 4 * i
```

Para un programa con `N` instrucciones, la dirección posterior a la última es `4 * N`. Los cálculos utilizan enteros en bytes, sin truncamiento ni wrap-around.

Estas direcciones describen la ubicación del código, no el orden dinámico de ejecución. Los branches y jumps no modifican la asignación. Todas las instrucciones presentes se ubican en orden, incluidas las que siguen a un `halt` o pertenecen a una ruta que el programa puede omitir.

La etapa no recibe capacidad de IMEM ni limita la cantidad de instrucciones según el perfil. La FPGA conserva la comprobación de tamaño al aceptar `LOAD`, conforme al [acuerdo de responsabilidades](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--responsabilidad-de-traducción-y-validación-de-tamaño).

## Tabla de etiquetas

La tabla se consulta por el nombre exacto de la etiqueta. Cada definición conserva:

| Campo     | Representación conceptual | Función                                         |
|-----------|---------------------------|-------------------------------------------------|
| Nombre    | Texto                     | Identificador que actúa como clave de la tabla. |
| `address` | Entero no negativo        | Dirección en bytes asociada a la etiqueta.      |
| `line`    | Entero positivo           | Línea donde se define, para los diagnósticos.   |

La dirección y la línea forman parte de una misma definición; no se requiere una tabla paralela de posiciones del código fuente. [Estructuras de datos](assembler_data_model.md#direcciones-y-definiciones) define su representación Python aprobada mediante `LabelDefinition` y una tabla por nombre.

Los nombres distinguen mayúsculas y minúsculas. `fin` y `Fin` son claves diferentes. Dos definiciones del mismo nombre son un error aunque correspondan a la misma dirección; una definición posterior no sobrescribe la primera.

Etiquetas diferentes pueden compartir dirección. Esto ocurre, por ejemplo, cuando se escriben definiciones consecutivas sin instrucciones entre ellas. Una definición al final del programa toma la dirección posterior a la última instrucción, sin producir relleno ni agregar un `halt`.

La tabla incluye todas las definiciones antes de resolver las referencias de las instrucciones. De ese modo, una referencia puede utilizar una etiqueta situada antes o después de ella. Comprobar que cada referencia exista y calcular su desplazamiento pertenece a la resolución de destinos.

## Instrucciones con dirección

La secuencia de salida contiene únicamente registros que representan instrucciones:

| Campo      | Representación conceptual | Función                                         |
|------------|---------------------------|-------------------------------------------------|
| `line`     | Entero positivo           | Línea original de la instrucción.               |
| `pc`       | Entero no negativo        | Dirección en bytes asignada a la instrucción.   |
| `mnemonic` | Texto                     | Mnemónico reconocido por la lectura.            |
| `operands` | Secuencia de textos       | Operandos reconocidos, conservados en su orden. |

Las definiciones de etiquetas quedan en la tabla y no agregan instrucciones a esta secuencia. El mnemónico y los operandos se conservan; asignar un PC no convierte los registros a índices ni los inmediatos o destinos a valores numéricos.

La relación pública `pc_to_line` se obtiene de los campos `pc` y `line` cuando la traducción completa tiene éxito. Una definición de etiqueta no agrega una entrada propia a esa relación. Si una etapa posterior falla, la aplicación recibe el diagnóstico y `pc_to_line={}`, según la interfaz pública.

La cantidad de instrucciones y la dirección posterior a la última se derivan de la secuencia. No se requieren copias independientes de estos valores en el resultado interno.

## Diagnósticos

Una definición duplicada se informa en la línea de la segunda aparición. El mensaje identifica el nombre y la línea de su primera definición. Por ejemplo:

```asm
ciclo:
ciclo: halt
```

El diagnóstico corresponde a la línea 2 y explica que `ciclo` ya fue definida en la línea 1. El mensaje se entrega como datos y su presentación pertenece a la aplicación.

La comprobación utiliza las definiciones, no las referencias. Una instrucción que menciona `fin` no constituye una definición de ese nombre. Las referencias sin definición se comprueban después de construir la tabla completa.

## Ejemplo de asignación

Para el siguiente código fuente:

```asm
# Contador

inicio:
    addi x1, x0, 3
ciclo: addi x1, x1, -1
    bne x1, x0, ciclo
    jal x0, fin
    addi x2, x0, 99
fin: halt
salida:
```

La secuencia de instrucciones es:

| `line` | `pc` | `mnemonic` | `operands`           |
|-------:|-----:|------------|----------------------|
|      4 |    0 | `addi`     | `x1`, `x0`, `3`.     |
|      5 |    4 | `addi`     | `x1`, `x1`, `-1`.    |
|      6 |    8 | `bne`      | `x1`, `x0`, `ciclo`. |
|      7 |   12 | `jal`      | `x0`, `fin`.         |
|      8 |   16 | `addi`     | `x2`, `x0`, `99`.    |
|      9 |   20 | `halt`     | Vacío.               |

La tabla de etiquetas contiene:

| Nombre   | `address` | `line` |
|----------|----------:|-------:|
| `inicio` |         0 |      3 |
| `ciclo`  |         4 |      5 |
| `fin`    |        20 |      9 |
| `salida` |        24 |     10 |

Las seis instrucciones ocupan posiciones consecutivas de cuatro bytes. La definición `inicio` identifica la instrucción de la línea siguiente. `ciclo` y `fin` identifican las instrucciones de sus propias líneas. `salida` identifica el límite posterior al programa y no agrega una instrucción de dirección 24.

Las referencias a `ciclo` y `fin` permanecen como texto en los operandos. La tabla ya permite resolverlas en la etapa siguiente, independientemente de su posición en el archivo.

## Condiciones de borde

- Una entrada sin registros entrega una secuencia de instrucciones y una tabla de etiquetas vacías.
- Si solo existen etiquetas diferentes, todas se asocian con cero y la secuencia de instrucciones queda vacía. Una repetición del mismo nombre sigue siendo un error.
- Las etiquetas consecutivas comparten la dirección de la siguiente instrucción o del final del programa.
- Una etiqueta al final puede usarse posteriormente como destino si su desplazamiento es representable. Eso no crea una instrucción en esa dirección; el eventual fetch fuera de imagen se rige por el contrato de CPU.
- Las instrucciones posteriores a `halt` conservan sus direcciones. La terminación en ejecución no modifica la distribución del código fuente.
- Un PC sin instrucción, como la dirección posterior al programa, no recibe una entrada en `pc_to_line`. La aplicación no atribuye una línea de instrucción a una definición de etiqueta aislada.

## Estado de diseño

La asignación de direcciones y la tabla de etiquetas están aprobadas en el [acuerdo de DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--direcciones-y-tabla-de-etiquetas). [Interpretación de operandos](assembler_operands.md) desarrolla el contrato aprobado de conversión y resolución que utiliza estas salidas. La codificación, el empaquetado y las [estructuras Python](assembler_data_model.md) también están aprobados. El cierre conjunto de [DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueba también el lenguaje, la interfaz pública y la organización interna. El [catálogo de pruebas](assembler_tests.md) está aprobado documentalmente; su implementación y ejecución permanecen pendientes. El [entorno e importación](assembler_environment.md) está aprobado.

Las tablas describen expectativas documentales. La implementación y la ejecución de pruebas permanecen posteriores al cierre global del [Plan](../plan.md#condición-común-para-comenzar-implementación). El estado de `DEC-SYS-009` se consulta en [DEC-SYS-009](../decisions/DEC-SYS-009.md).

## Referencias y trazabilidad

- [Lectura del código fuente](assembler_source_reader.md): registros de entrada y numeración original de líneas.
- [Lenguaje assembler](assembler_language.md#etiquetas-y-destinos): definiciones, direcciones y destinos admitidos.
- [Interfaz del assembler](assembler_interface.md): resultados, diagnósticos y relación PC–línea.
- [Interpretación de operandos](assembler_operands.md): conversión de registros y literales y resolución de destinos.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): acuerdos de diseño y distribución de responsabilidades.
- [Requisitos de software de PC](../requirements.md#8-software-de-pc): traducción de instrucciones y resolución de símbolos.
- [Decisiones pendientes](../decisions/pending_decisions.md): diseño restante y condiciones de cierre.
- [Plan](../plan.md): fases e hitos de diseño e implementación.
