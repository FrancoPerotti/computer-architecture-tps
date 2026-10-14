# Empaquetado y resultado del assembler

- **Tipo:** diseño de software.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Interfaces y contratos](#interfaces-y-contratos)
- [Orden de bytes](#orden-de-bytes)
- [Formación de la imagen](#formación-de-la-imagen)
- [Relación entre PC y línea](#relación-entre-pc-y-línea)
- [Entrega del resultado](#entrega-del-resultado)
- [Ejemplos de empaquetado](#ejemplos-de-empaquetado)
- [Condiciones de la salida](#condiciones-de-la-salida)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

El empaquetado convierte las palabras de 32 bits producidas por la [codificación](assembler_encoding.md) en la secuencia de bytes `image`. Conserva sus direcciones y líneas originales en `pc_to_line` y forma el resultado completo de la traducción.

El orden little-endian está establecido por el [acuerdo de responsabilidades](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--responsabilidad-de-traducción-y-validación-de-tamaño), el [protocolo de carga](../protocol.md#imagen-y-tamaño) y la [reconstrucción del Loader](../architecture/session/loader.md#reconstrucción-de-palabras-little-endian). Este documento concreta su aplicación en el assembler y la formación de los campos descritos en [Interfaz del assembler](assembler_interface.md).

## Interfaces y contratos

| Dirección | Dato                      | Representación conceptual           | Productor    | Consumidor  | Función                                           |
|-----------|---------------------------|-------------------------------------|--------------|-------------|---------------------------------------------------|
| Entrada   | Instrucciones codificadas | Secuencia con `line`, `pc` y `word` | Codificación | Empaquetado | Palabras completas en orden del programa.         |
| Salida    | Resultado de traducción   | `image`, `pc_to_line` y `error`     | Assembler    | Aplicación  | Bytes completos y ubicación de sus instrucciones. |

La entrada contiene una palabra por instrucción. `word` está entre cero y `0xffffffff`, `line` conserva la línea original y los PCs son `0`, `4`, `8`, etc. El empaquetado utiliza esas direcciones; no vuelve a asignarlas ni consulta etiquetas.

Una entrada interna que contradiga este contrato representa un defecto del software. El empaquetado no recorta palabras ni rellena huecos para convertirla en una imagen válida.

## Orden de bytes

Cada palabra aporta exactamente cuatro bytes, comenzando por sus ocho bits menos significativos:

| Posición dentro de la instrucción | Bits de `word` | Dirección en `image` |
|----------------------------------:|----------------|----------------------|
| 0                                 | 7:0            | `pc`.                |
| 1                                 | 15:8           | `pc + 1`.            |
| 2                                 | 23:16          | `pc + 2`.            |
| 3                                 | 31:24          | `pc + 3`.            |

Para cada posición `j`, desde cero hasta tres:

```text
image[pc + j] = (word >> (8 * j)) & 0xff
```

La fórmula expresa la distribución de bytes, no una función implementada ni una asignación sobre el tipo inmutable `bytes` de Python. La salida pública es una secuencia `bytes` con ese contenido.

Por ejemplo, la palabra `0x00500093` produce `93 00 50 00`. La palabra `0xfff08093`, que codifica un inmediato negativo, produce `93 80 F0 FF`. El signo ya está representado en los bits de la palabra; no se aplica nuevamente al empaquetarla.

Los pares de dígitos de los ejemplos representan bytes en hexadecimal. `image` contiene sus valores binarios, no los caracteres de esa representación textual. Los bytes cero se conservan en todas sus posiciones.

## Formación de la imagen

Las palabras se recorren en el orden de entrada y sus grupos de cuatro bytes se concatenan en ese mismo orden. La primera palabra comienza en dirección cero y cada palabra siguiente ocupa las cuatro posiciones posteriores.

Para `N` instrucciones:

```text
len(image) = 4 * N
```

La imagen contiene todas las instrucciones traducidas, incluidas las posteriores a `halt`. No se agrega una terminación implícita ni relleno hasta completar IMEM. Las etiquetas y comentarios no agregan bytes.

El resultado público conserva `image` como única representación del código máquina. La secuencia de palabras pertenece al recorrido interno y no se incorpora como otro campo de salida. La cantidad de instrucciones y el tamaño se derivan de `len(image)`.

## Relación entre PC y línea

Cada instrucción codificada agrega una entrada:

```text
pc_to_line[pc] = line
```

Los bytes y el mapa se forman a partir de los mismos registros. Para `N` instrucciones existen `N` entradas, con claves `0`, `4`, ..., `4 * (N - 1)` cuando `N` es positivo. Las direcciones de los otros tres bytes de una instrucción no agregan entradas.

El mapa apunta a la línea que contiene la instrucción. Una etiqueta aislada no agrega una entrada; una etiqueta en la misma línea conserva la línea de esa instrucción. Una etiqueta al final del programa puede tener una dirección asignada sin que exista una instrucción ni una entrada para ella.

La aplicación conserva este mapa para relacionar un PC de Debug con el código fuente. El mapa no se transmite a IMEM. El uso de `fault_pc` y la presentación de direcciones sin línea asociada se describen en [Interfaz del assembler](assembler_interface.md#relación-entre-pc-y-línea).

## Entrega del resultado

La traducción completa produce los siguientes campos:

| Campo        | Valor al completar la traducción                           |
|--------------|------------------------------------------------------------|
| `image`      | Secuencia `bytes` de todas las instrucciones.              |
| `pc_to_line` | Diccionario de direcciones y líneas de esas instrucciones. |
| `error`      | `None`.                                                    |

Una secuencia sin instrucciones produce `image=b""`, `pc_to_line={}` y `error=None`. No se transforma en un error de lenguaje ni se agrega `halt` para obtener una carga admisible.

Si una etapa anterior informa un error de código fuente, el assembler entrega `image=None`, `pc_to_line={}` y el diagnóstico correspondiente. No publica bytes ni entradas de mapa parciales. Con una entrada que cumple el contrato, el empaquetado no introduce otra clase de rechazo del código fuente.

El éxito de traducción no acredita aceptación de carga. La capa de protocolo obtiene el tamaño con `len(image)`, forma la cabecera de `LOAD`, espera `ACCEPTED` antes de transmitir la imagen y procesa la confirmación final. El assembler entrega solamente los bytes de instrucciones y su mapa; no agrega esa cabecera, no realiza transporte UART ni compara el tamaño con IMEM.

## Ejemplos de empaquetado

### Dos instrucciones

Para el código fuente:

```asm
# Inicializa un registro y finaliza
inicio:
    addi x1, x0, 5
    halt
```

Los registros codificados y sus bytes son:

| `line` | `pc` | `word`       | Bytes en orden de imagen |
|-------:|-----:|--------------|--------------------------|
| 3      | 0    | `0x00500093` | `93 00 50 00`.           |
| 4      | 4    | `0x0000000b` | `0B 00 00 00`.           |

El resultado contiene:

```text
image      = bytes 93 00 50 00 0B 00 00 00
pc_to_line = {0: 3, 4: 4}
error      = None
```

La imagen ocupa ocho bytes. `inicio`, definida en la línea 2, no agrega bytes ni una entrada de mapa.

### Programa con desplazamientos negativos

Las palabras del [programa con etiquetas resueltas](assembler_encoding.md#programa-con-etiquetas-resueltas) producen:

| `line` | `pc` | `word`       | Bytes en orden de imagen |
|-------:|-----:|--------------|--------------------------|
| 4      | 0    | `0x00300093` | `93 00 30 00`.           |
| 5      | 4    | `0xfff08093` | `93 80 F0 FF`.           |
| 6      | 8    | `0xfe009ee3` | `E3 9E 00 FE`.           |
| 7      | 12   | `0x0080006f` | `6F 00 80 00`.           |
| 8      | 16   | `0x06300113` | `13 01 30 06`.           |
| 9      | 20   | `0x0000000b` | `0B 00 00 00`.           |

La imagen ocupa 24 bytes y el mapa es:

```text
pc_to_line = {0: 4, 4: 5, 8: 6, 12: 7, 16: 8, 20: 9}
```

El Loader que reciba cada grupo en ese orden reconstruye la palabra indicada en su fila.

## Condiciones de la salida

- Cada palabra aporta cuatro bytes little-endian en orden creciente de dirección.
- Reconstruir esos cuatro bytes según el Loader recupera la palabra original.
- La longitud de `image` es cuatro veces la cantidad de instrucciones y no depende del contenido de sus palabras.
- `pc_to_line` tiene una entrada por instrucción y corresponde a los mismos registros que producen `image`.
- Las instrucciones posteriores a `halt` se conservan; las etiquetas, comentarios y líneas vacías no ocupan bytes.
- El resultado vacío y los errores de traducción conservan las condiciones de entrega completa definidas en este contrato.

## Estado de diseño

La formación de bytes y del mapa está aprobada en el [acuerdo de DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--empaquetado-y-resultado). Las [estructuras Python](assembler_data_model.md) también están aprobadas. El cierre conjunto de [DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueba también el lenguaje, la interfaz pública y la organización interna. El [catálogo de pruebas](assembler_tests.md) está aprobado documentalmente; su implementación y ejecución permanecen pendientes. El [entorno e importación](assembler_environment.md) está aprobado.

Las fórmulas y ejemplos describen expectativas documentales. La implementación y ejecución de pruebas permanecen posteriores al cierre global del [Plan](../plan.md#condición-común-para-comenzar-implementación). El cierre completo de `DEC-SYS-009` se consulta en [DEC-SYS-009](../decisions/DEC-SYS-009.md).

## Referencias y trazabilidad

- [Codificación de instrucciones](assembler_encoding.md): palabras de 32 bits, PCs y líneas recibidos.
- [Direcciones y tabla de etiquetas](assembler_addresses.md): ubicación contigua desde cero.
- [Interfaz del assembler](assembler_interface.md): campos públicos, resultado vacío y errores.
- [Protocolo](../protocol.md#cargar-una-imagen): cabecera, contenido y aceptación de carga.
- [Loader](../architecture/session/loader.md#reconstrucción-de-palabras-little-endian): reconstrucción de palabras desde bytes recibidos.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): estrategia y acuerdos del assembler.
- [Plan](../plan.md): fases y condiciones previas a la implementación.
