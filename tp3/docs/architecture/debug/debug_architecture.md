# Arquitectura de Debug

- **Tipo:** arquitectura.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Observar estado arquitectónico y estado del pipeline](#observar-estado-arquitectónico-y-estado-del-pipeline)
- [Contexto global de la sesión](#contexto-global-de-la-sesión)
- [PC global y PCs de las instrucciones](#pc-global-y-pcs-de-las-instrucciones)
- [Register File](#register-file)
- [Observar el pipeline](#observar-el-pipeline)
- [Fault observable](#fault-observable)
- [Data Memory](#data-memory)
- [Qué es un snapshot](#qué-es-un-snapshot)
- [Por qué la coherencia importa con UART](#por-qué-la-coherencia-importa-con-uart)
- [Momentos de observación del protocolo](#momentos-de-observación-del-protocolo)
- [Snapshot después de STEP](#snapshot-después-de-step)
- [Snapshot al finalizar RUN](#snapshot-al-finalizar-run)
- [Acceso a DMEM y ownership](#acceso-a-dmem-y-ownership)
- [Sesiones, reset y reprogramación](#sesiones-reset-y-reprogramación)
- [Información observable fijada](#información-observable-fijada)
- [Información que no forma parte obligatoria del snapshot](#información-que-no-forma-parte-obligatoria-del-snapshot)
- [Separación entre estado interno y representación externa](#separación-entre-estado-interno-y-representación-externa)
- [Invariantes y condiciones de borde](#invariantes-y-condiciones-de-borde)
- [Verificación y evidencia](#verificación-y-evidencia)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

<a id="para-qué-existe-debug"></a>

## Propósito y alcance

Este documento define qué estado del procesador puede observarse mediante Debug y cómo combinar la información arquitectónica con el estado persistente del pipeline. El objetivo es que una observación permita reconstruir el contexto de una ejecución sin confundir los efectos que ya hicieron commit con las instrucciones que todavía están en vuelo.

El alcance comprende:

- La identificación de la sesión observada y del ciclo lógico alcanzado por la CPU.
- El frente actual de fetch y el PC asociado a cada instrucción que permanece en el pipeline.
- Los valores del banco de registros y los datos observables de la memoria.
- El contenido y la validez de los registros interetapa, para saber qué instrucciones siguen activas en IF, ID, EX o MEM.
- El estado de terminación de la sesión: ejecución normal o fault.
- La causa y el PC de la operación que originó un fault, cuando existe uno confirmado.
- Las condiciones temporales que permiten formar un snapshot coherente a través de UART y Debug.

Un pipeline puede contener varias instrucciones al mismo tiempo. Algunas ya produjeron efectos en el banco de registros o en memoria, mientras otras todavía avanzan por IF, ID, EX o MEM. Además, una de ellas puede haber solicitado un redirect, un `halt` o un fault. Observar únicamente el banco de registros no permite saber qué instrucciones siguen activas; observar solo los registros interetapa tampoco muestra todos los efectos que ya se hicieron visibles arquitectónicamente.

Por eso Debug reúne ambos niveles de información: el estado arquitectónico que una ejecución secuencial consideraría visible y el estado microarquitectónico persistente que describe la distribución actual del trabajo dentro del pipeline.

La observación es de solo lectura y no forma parte de la ejecución del programa. Debug describe un estado que ya existe: no cambia la semántica de las instrucciones ni reemplaza al control de ejecución. `RUN`, `STEP` y `LOAD` continúan gobernados por [Control de ejecución y sesión](../session/execution_control.md). Este documento se concentra en qué puede observarse y en las condiciones necesarias para que esa observación sea coherente.

---

## Observar estado arquitectónico y estado del pipeline

La información de Debug proviene de dos niveles diferentes del procesador.

El **estado arquitectónico** contiene los valores que una ejecución secuencial del programa consideraría visibles: banco de registros, memoria de datos y contexto de terminación.

El **estado microarquitectónico persistente** describe cómo ese programa está distribuido actualmente dentro del pipeline: PC global, registros interetapa, validez y contexto asociado a las instrucciones en vuelo.

Ambos niveles son necesarios para interpretar una ejecución.

Por ejemplo, después de un `STEP` puede ocurrir simultáneamente que:

- Una instrucción haya escrito un registro en WB.
- Otra esté realizando un acceso en MEM.
- Otra se encuentre en EX.
- Y una nueva instrucción haya quedado almacenada en `IF/ID`.

El valor de un registro no permite deducir por sí solo esas posiciones, y las posiciones del pipeline tampoco reconstruyen automáticamente todos los efectos anteriores.

Por eso Debug combina información arquitectónica y microarquitectónica persistente en una misma observación.

---

## Contexto global de la sesión

Antes de interpretar una instrucción o un registro, el software necesita conocer el contexto general en el que esos valores existen.

### `global_state`

La [codificación externa de `global_state`](../../protocol.md#global_state) identifica los estados de sesión en UART mediante un byte en offset cero del cuerpo del snapshot. Ese transporte no impone codificación interna ni amplía los momentos de observación. El [acuerdo de estados](../../decisions/DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--códigos-externos-de-global_state) conserva su aprobación; aquí se interpreta la fase observada.

`global_state` identifica la fase actual de la sesión.

Permite distinguir, entre otras situaciones:

- Ausencia de imagen (`NO_IMAGE`);
- Carga o preparación (`LOADING`, `PREPARING_READY`, `PREPARING_RUN`, `PREPARING_STEP`);
- Sesión lista (`READY`);
- Ejecución continua (`RUNNING`);
- Ejecución por pasos (`STEPPING`);
- Drain por `halt` (`HALT_DRAIN_AUTO`, `HALT_DRAIN_STEP`);
- Drain por fault (`FAULT_DRAIN_AUTO`, `FAULT_DRAIN_STEP`);
- Terminación normal (`FINISHED`);
- Terminación excepcional (`FAULT`).

El software no necesita inferir esas situaciones mirando indirectamente el PC o los bits `valid` del pipeline.

La codificación interna está definida en [global_state_encoding](../session/global_state_encoding.md); el transporte usa la conversión externa definida en [Protocolo](../../protocol.md#global_state). En esta capa se define su significado arquitectónico.

### `cycle_count`

`cycle_count[63:0]` identifica cuántos ciclos efectivos de la CPU ocurrieron dentro de la sesión actual.

Comienza en cero con la preparación de una nueva sesión e incrementa solamente cuando:

```text
cpu_cycle_fire = 1
```

Esto permite correlacionar una captura de hardware con una simulación, un testbench y las secuencias esperadas de las pruebas sin confundir ciclos de la CPU con clocks físicos consumidos por UART, `Loader` o espera entre `STEP`.

El contador es modular. Su wrap no invalida una observación ni genera un estado especial.

### Imagen confirmada

La observación también distingue si existe una imagen ejecutable.

Internamente:

```text
image_valid =
    (loaded_image_size_bytes != 0)
```

El tamaño confirmado pertenece al estado del sistema, pero eso no obliga a transmitirlo como un campo externo independiente. Lo que sí forma parte de la interpretación de Debug es poder diferenciar una sesión asociada a una imagen válida de la ausencia de programa ejecutable.

---

## PC global y PCs de las instrucciones

El pipeline contiene varios PCs con significados distintos.

El **PC global** representa el frente actual de búsqueda de IF. Indica desde qué dirección intenta continuar el fetch.

Los registros interetapa, en cambio, transportan el PC propio de cada instrucción.

Esto permite seguir una instrucción concreta mientras avanza:

```text
IF/ID.pc
    ↓
ID/EX.pc
    ↓
EX/MEM.pc
    ↓
MEM/WB.pc
```

El PC global y el PC almacenado en un registro interetapa pueden ser diferentes y ambos son informativos.

Después de un redirect, por ejemplo, el PC global puede apuntar al nuevo camino mientras una instrucción anterior todavía permanece en MEM o WB con su propio PC.

Por eso una representación de Debug no trata estos valores como equivalentes.

---

## Register File

Debug dispone del banco de registros completo:

```text
x0 ... x31
```

Cada registro contiene 32 bits y:

```text
x0 = 0
```

permanece constante.

El banco de registros refleja las escrituras que ya hicieron commit. No muestra resultados que todavía se encuentran en `EX/MEM` o `MEM/WB` y aún no alcanzaron writeback.

Esta diferencia es precisamente una de las razones por las que el banco de registros se observa junto con el pipeline.

---

## Observar el pipeline

Los cuatro registros interetapa son puntos naturales de observación porque contienen el estado registrado que una instrucción transporta de una etapa a la siguiente:

```text
IF/ID
ID/EX
EX/MEM
MEM/WB
```

Debug observa principalmente estos registros persistentes. No se intenta exponer cada señal combinacional del datapath como una señal de Debug.

### Validez

Cada registro interetapa tiene una noción de validez.

`valid=1` indica que la entrada representa una instrucción activa.

`valid=0` indica que sus demás bits no describen trabajo ejecutable, aunque físicamente puedan conservar valores residuales.

Por eso una entrada como:

```text
valid       = 0
pc          = valor residual
instruction = valor residual
```

no se presenta como una instrucción real.

Debug tampoco necesita distinguir obligatoriamente por qué una entrada quedó inválida. Bubble, flush, drain y otras causas pueden producir el mismo resultado observable:

```text
valid = 0
```

La arquitectura exige distinguir actividad de inactividad, no almacenar una causa adicional de invalidez.

### PC e instrucción

Como mínimo, la interpretación externa de cada registro interetapa conserva:

- `valid`;
- el PC propio de la instrucción;
- `instruction`.

Estos tres campos permiten identificar qué instrucción ocupa una etapa y dónde se encontraba en el programa.

El [acuerdo de exposición completa](../../decisions/DEC-ARCH-009.md#acuerdo-parcial-de-dec-arch-009--exposición-completa-de-campos-registrados-del-pipeline) incluye todos los campos funcionales registrados existentes:

| Registro | Cantidad de campos |
|---|---:|
| `IF/ID` | 5 |
| `ID/EX` | 15 |
| `EX/MEM` | 8 |
| `MEM/WB` | 6 |

Debug transmite los campos registrados e indicadores sin filtrarlos por valid. Interpretarlos corresponde al lector. 

### Candidato de fetch fault

`IF/ID` posee además:

```text
fetch_fault_valid
fetch_fault_cause
```

Un `fetch_fault_valid=1` representa un candidato todavía no confirmado.

No equivale a:

```text
fault_active
```

ni transforma la `instruction` residual del registro interetapa en una instrucción ilegal.

El candidato registrado de `IF/ID` se incluye en el contenido Debug aprobado, con `fetch_fault_valid` y `fetch_fault_cause`; su PC/causa identifican un candidato y no un fault global confirmado. Ancho y posición externos están aprobados en D05; interpretación de campos inactivos y códigos aprobados en el protocolo definitivo.

---

## Fault observable

Cuando se confirma un fault, el procesador captura:

```text
fault_cause[2:0]
fault_pc[31:0]
```

Esos registros pueden conservar bits físicos fuera de una sesión fallada. La validez de su interpretación no proviene de que sus bits sean cero o no cero, sino del estado global.

La información representa un fault vigente durante:

```text
FAULT_DRAIN_AUTO
FAULT_DRAIN_STEP
FAULT
```

Esto puede expresarse mediante:

```text
fault_info_valid
```

derivado de `global_state`.

Por lo tanto, Debug distingue entre:

- Un candidato de fault todavía no confirmado.
- Metadatos residuales sin validez actual.
- Un fault confirmado durante drain.
- Un estado terminal `FAULT`.

También distingue `FAULT` de `FINISHED`: ambos tienen el pipeline vacío, pero representan terminaciones diferentes.

---

## Data Memory

El estado observable incluye la parte de DMEM que se considere relevante para Debug.

La semántica de los datos ya está fijada por la arquitectura de memoria: cualquier byte no escrito durante la sesión actual se lee lógicamente como cero, independientemente de residuos físicos.

El [criterio aprobado de memoria utilizada](../../decisions/DEC-SYS-005.md#acuerdo-parcial-de-dec-sys-005--memoria-utilizada-como-bytes-escritos-en-la-sesión) selecciona los bytes escritos efectivamente por stores del programa en la sesión actual, incluidos ceros. `SB`, `SH` y `SW` incorporan sus 1, 2 y 4 bytes al commit. Leer una posición o inicializarla durante preparación no la incorpora; sobrescribirla actualiza su valor sin duplicar la dirección.

Cada snapshot reporta la lista completa en dirección creciente, con dirección y valor actual de cada byte utilizado, coherentes con el mismo instante del resto del estado. No incluye huecos no escritos entre posiciones utilizadas ni representa un historial o solo los cambios del último ciclo.

El conjunto comienza vacío en cada sesión nueva. Los metadatos de validez por byte de referencia pueden reutilizarse para seleccionarlo. Este criterio externo no obliga a otro bitmap ni altera la semántica lógica de DMEM.

El [layout](../../decisions/DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--orden-y-delimitación-del-snapshot) aprueba la cantidad, la longitud y la lista vacía: cinco bytes little-endian para cantidad y cinco por entrada (dirección cuatro, valor uno), sin entradas si cantidad cero. DEC-SYS-005/D04 quedan cerrados; la lectura directa retenida y la exclusión están aprobadas en D06.

El [serializador](response_serializer.md#recorrido-de-dmem-y-orden-de-producción) tiene aprobados dos recorridos:

1. Contar por metadatos antes de producir la parte fija.
2. Recorrer nuevamente para producir la lista creciente. Cantidad cero omite este segundo recorrido.

Puertos, índices, anchos y controles están concretados en [response_serializer](response_serializer.md) y [protocol_controller](protocol_controller.md), con integración de memoria en [dmem_access](../memory/dmem_access.md).

---

## Qué es un snapshot

Un **snapshot** representa el estado del procesador en un único instante lógico.

Esto es más fuerte que transmitir individualmente valores que sean correctos por separado.

Supóngase que un `STEP` produce un writeback en `x1` y simultáneamente hace avanzar las instrucciones del pipeline. Después del flanco existen:

- Un nuevo valor de `x1`.
- Nuevos contenidos en `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`.
- Un nuevo `cycle_count`.
- Posiblemente un nuevo PC.

Una respuesta que combinara el banco de registros anterior al `STEP` con los registros interetapa posteriores contendría valores que existieron físicamente, pero **no representaría ningún estado real de la CPU**.

La coherencia exige que todos los campos de un mismo snapshot correspondan al mismo estado lógico.

Esto incluye:

- `cycle_count`.
- PC global.
- `global_state`.
- Banco de registros.
- Estado observable de los cuatro registros interetapa.
- DMEM reportada.
- Metadatos de fault cuando sean válidos.
- Información asociada a la imagen o sesión necesaria para interpretar la captura.

---

## Por qué la coherencia importa con UART

La CPU y UART operan en escalas temporales muy diferentes.

Capturar el estado puede conceptualmente corresponder a un único instante, mientras que transmitir todos sus campos puede ocupar muchos clocks físicos.

Si el transmisor leyera cada elemento directamente mientras la CPU continúa cambiando, el principio y el final del mensaje podrían pertenecer a ciclos distintos.

Por eso la arquitectura fija el **resultado observable**:

> un snapshot representa un único estado lógico, independientemente del tiempo requerido para serializarlo.

El [acuerdo de envío exclusivo](../../decisions/DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--envío-exclusivo-de-debug-con-estado-retenido) selecciona lectura directa del estado retenido. El instante corresponde al estado posterior al `STEP` efectivo o al último ciclo `RUN` que alcanza `FINISHED`/`FAULT`.

Desde ese instante hasta el Stop físico del último byte, la CPU no ejecuta otro ciclo y no comienza `LOAD`/preparación. RF, registros interetapa, PC, contador, estado, imagen y DMEM permanecen estables.

UART y recorrido/lectura Debug continúan funcionando, respetando ownership. No se necesita una copia completa adicional del estado.

Durante ese intercambio se aplican estas reglas:

| Caso | Comportamiento |
|---|---|
| Nueva solicitud desde la PC | La PC espera la respuesta completa antes de enviarla. |
| RX recibido durante la exclusión | La FPGA lo consume y descarta, sin respuesta ni comandos encolados. |
| Consultas y `RESET` UART | También quedan incluidos en el descarte. `RESET` UART se envía después del intercambio. |
| Botón físico | Conserva reset inmediato y puede abortar el envío. La PC descarta la observación incompleta. |
| Fin de la exclusión | La admisión vuelve al terminar físicamente el último byte, incluido Stop. |
| Orden de `RUN` | La aceptación completa precede a su resultado final con Debug. |

D06 queda completo en el nivel de contrato; la [secuencia de dos recorridos de DMEM](response_serializer.md#recorrido-de-dmem-y-orden-de-producción) está aprobada. Puertos, recursos de conteo/posición, índices, anchos y control privado están concretados en [response_serializer](response_serializer.md) y [protocol_controller](protocol_controller.md), con [comprobación UART](../uart/uart_core.md#presupuesto-de-integración).

[C06](../../decisions/DEC-PROTO-003.md#acuerdo-parcial-de-dec-proto-003--plazos-de-reset-step-y-recepción-de-debug) aprueba los siguientes plazos PC:

| Tramo | Plazo |
|---|---|
| Cabecera `STEP` | 200 ms |
| Parte fija de 228 bytes | 319 ms tras cabecera |
| Lista de 5*K bytes | Transmisión nominal +200 ms desde `used_count`; sin espera para K=0 |

La recuperación aprobada en C06 informa fallo y descarta el parcial. Fuera de `LOAD`, lee y descarta RX hasta completar `W_debug` de 6100/3400 ms de silencio continuo: cada recepción reinicia la cuenta. Después consulta `CHECK_READY` sin limpiar RX y valida únicamente los primeros dos bytes (`05 03` o `05 04`) dentro de 200 ms. Si empieza un terminal RUN u otra secuencia, vuelve al descarte; no busca esos pares dentro del payload. Conserva los bytes posteriores a una consulta válida y no repite `STEP`/`RUN`/`RESET`. El [contrato de recuperación PC](../../protocol.md#perder-una-respuesta-o-conexión) concreta buffers, vencimientos y supuestos del transporte.

---

## Momentos de observación del protocolo

El [orden de intercambios](../../decisions/DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--orden-de-intercambios-y-respuestas) permite una operación normal por vez, con `CHECK_READY`/`RESET` durante `RUN`. Cada respuesta se transmite completa antes de otra; si `RUN` termina durante una respuesta breve iniciada, se conserva el estado terminal y se termina esa respuesta antes del resultado `RUN`/Debug. La exclusión D06 abarca el resultado Debug pendiente y transmitido; `RESET` UART reconocido durante ejecución abandona el `RUN` previo.

Las operaciones definitivas son `LOAD`, `RUN`, `STEP`, `RESET` y `CHECK_READY`, según el [acuerdo de lista final](../../decisions/DEC-PROTO-002.md#acuerdo-parcial-de-dec-proto-002--lista-final-y-nombres-de-operaciones). `CHECK_READY` es la consulta de disponibilidad para `LOAD`; Debug se entrega en `STEP` y final `RUN`.

El [acuerdo de servicios de Debug](../../decisions/DEC-PROTO-002.md#acuerdo-parcial-de-dec-proto-002--debug-automático-sin-consultas-adicionales) fija exclusivamente snapshots automáticos posteriores a cada `STEP` realizado y al final de `RUN`. No se agrega una consulta explícita de Debug ni capturas durante `RUNNING`/drains `AUTO` u otros momentos adicionales. PC puede conservar el snapshot recibido, asociado a su sesión; entre pasos sin otra operación de sesión el estado permanece retenido. Los contratos de reset/preparación descritos aquí siguen definiendo el estado lógico y la coherencia de sesión, sin exigir transmitir snapshots en esas fases.

---

## Snapshot después de STEP

`STEP` ofrece un punto natural de observación porque el procesador vuelve a una situación de espera después de ejecutar un único ciclo, salvo que ese ciclo cambie la sesión hacia drain o terminal.

La información observada corresponde al estado **posterior** al ciclo autorizado.

El [acuerdo de respuesta STEP con Debug](../../decisions/DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--solicitud-step-y-respuesta-con-debug-de-cada-ciclo) fija la entrega automática de ese estado en la única respuesta `[STEP][DONE][estado de Debug]`. La entrega ocurre después del ciclo efectivo, sin aceptación previa separada ni consulta adicional.

El [acuerdo de halt/fault y drenado STEP](../../decisions/DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--halt-fault-y-drenado-en-respuestas-step) conserva esa misma respuesta. `global_state` distingue `HALT_DRAIN_STEP`/`FINISHED` y `FAULT_DRAIN_STEP`/`FAULT`; los de fault incluyen causa y PC vigentes. El paso que vacía el pipeline ya muestra el terminal, sin ciclo ni respuesta adicionales.

El layout está aprobado, la coherencia y el envío exclusivo están definidos en D06, y los códigos de `global_state` están aprobados. La realización documental de bloques está concretada en [Serializador](response_serializer.md) y [Controlador](protocol_controller.md), con implementación RTL pendiente.

Esto permite ver simultáneamente:

- Los efectos que hicieron commit durante ese ciclo.
- Cómo avanzaron las instrucciones.
- El nuevo PC.
- El nuevo `cycle_count`.
- Y cualquier cambio de `global_state`.

Un stall `load-use` también consume el `STEP`, por lo que el snapshot posterior puede mostrar que parte del pipeline avanzó mientras el consumidor permaneció retenido.

Debug no redefine qué significa `STEP`; solamente expone el estado resultante del ciclo descrito en [Control de ejecución y sesión](../session/execution_control.md).

---

## Snapshot al finalizar RUN

Durante `RUN`, la CPU puede ejecutar muchos ciclos antes de detenerse.

La arquitectura requiere disponer del estado de Debug correspondiente al final de la ejecución continua.

Ese final puede ser:

```text
FINISHED
```

o:

```text
FAULT
```

después del drain necesario.

En ese momento el pipeline está vacío, pero siguen siendo relevantes:

- Banco de registros.
- Memoria utilizada.
- PC global.
- `cycle_count`.
- Estado terminal.
- Y, para `FAULT`, `fault_cause` y `fault_pc`.

El [acuerdo de entrega final de RUN](../../decisions/DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--resultado-automático-de-run-con-estado-de-debug) fija el envío automático de ese snapshot junto con el resultado: `[RUN][FINISHED][estado de Debug]` o `[RUN][FAULT][estado de Debug]`, después de la aceptación completa. Se observa el estado terminal posterior al último commit, sin exigir otra consulta. Layout y longitud quedan aprobados en D05; lectura directa de estado retenido y exclusión de solicitudes en D06. Puertos y secuencia de lectura/serialización concretados en [response_serializer](response_serializer.md), con [comprobación UART](../uart/uart_core.md#presupuesto-de-integración).

La existencia de esta obligación no implica que una consulta arbitraria tenga que aceptarse mientras `RUNNING` continúa. El protocolo aprobado en D02 no ofrece capturas durante ejecución continua.

---

## Acceso a DMEM y ownership

Observar DMEM introduce una diferencia respecto de leer registros pequeños.

Leer directamente la DMEM del procesador, en lugar de una copia capturada, requiere respetar las reglas de acceso compartido definidas en [Arquitectura de memoria](../memory/memory_architecture.md).

Si Debug accede directamente a DMEM, la CPU no está ejecutando ciclos y ningún otro agente realiza un acceso incompatible a la misma memoria.

La [consulta del serializador](response_serializer.md#señales-de-consulta-de-dmem) tiene tres señales aprobadas: dirección de byte hacia DMEM, valor de ocho bits de retorno y marca de utilizado de un bit de retorno. El conteo utiliza únicamente la marca. El listado toma el dato cuando esa marca vale uno y omite las posiciones restantes.

La [lectura entre flancos](response_serializer.md#lectura-de-dmem-entre-flancos) está aprobada: las salidas son combinacionales desde la dirección registrada y la posición previa se consume al flanco siguiente.

El [selector CPU/Debug](../memory/memory_architecture.md#selector-de-dirección-de-lectura-cpudebug) está aprobado. `dmem_debug_select`, desde `protocol_controller`, selecciona la dirección del serializador durante la ventana exclusiva. Controles y selectores están definidos en [protocol_controller](protocol_controller.md), y mantenimiento en [session_preparation](../session/session_preparation.md). El cableado del backend DMEM/top está definido en la [composición aprobada](../system_composition.md).

En ambos casos el resultado observable conserva:

- Los mismos datos lógicos.
- La misma semántica little-endian.
- El cero lógico de bytes no escritos.
- Y la exclusión entre agentes incompatibles.

Debug no introduce una nueva latencia arquitectónica en loads ni un stall de memoria dentro de la ejecución normal.

---

## Sesiones, reset y reprogramación

Un snapshot pertenece al contexto de una sesión.

Cuando `RESET` invalida la sesión, una captura anterior puede conservarse físicamente en algún almacenamiento auxiliar, pero ya no representa el estado actual del procesador.

Después de `RESET`, el PC, banco de registros, contador y bits de validez del pipeline representan el estado funcional de reset.

De manera equivalente, una reprogramación y preparación posterior crean un nuevo contexto. Debug no presenta datos de la sesión anterior como si pertenecieran a la nueva.

Esta regla es especialmente importante para DMEM, porque el almacenamiento físico puede conservar residuos aunque la nueva sesión los observe lógicamente como cero.

La coherencia de Debug sigue la semántica de sesión, no la mera permanencia física de los bits.

---

## Información observable fijada

Con las decisiones actuales, la arquitectura fija como contenido observable necesario:

| Información | Interpretación |
|---|---|
| `cycle_count[63:0]` | Ciclo lógico de la sesión. |
| PC global | Frente actual de fetch. |
| Estado global | Fase actual de la sesión y tipo de terminación. |
| Imagen válida | Distinción entre imagen ejecutable y ausencia de programa. |
| `x0...x31` | Banco de registros completo. |
| `IF/ID` | Todos sus 5 campos funcionales registrados, con semántica de validez; layout externo aprobado en D03/D05. |
| `ID/EX` | Todos sus 15 campos funcionales registrados, con semántica de validez; layout externo aprobado en D03/D05. |
| `EX/MEM` | Todos sus 8 campos funcionales registrados, con semántica de validez; layout externo aprobado en D03/D05. |
| `MEM/WB` | Todos sus 6 campos funcionales registrados, con semántica de validez; layout externo aprobado en D03/D05. |
| DMEM utilizada | Lista ordenada de bytes escritos en la sesión, incluidos ceros; cantidad de cinco bytes little-endian y entradas dirección cuatro bytes/valor uno aprobadas. |
| `fault_cause`, `fault_pc` | Válidos cuando el estado global representa fault confirmado. |

Internamente existen otros campos que pueden contribuir a la implementación o a diagnósticos particulares, pero su existencia no los convierte automáticamente en parte obligatoria del snapshot externo.

---

## Información que no forma parte obligatoria del snapshot

La arquitectura no exige exponer todas las señales combinacionales internas.

Entre los ejemplos que permanecen fuera del contrato obligatorio están:

- Selectores internos de multiplexores.
- Resultados combinacionales intermedios.
- Comparadores temporales.
- Señales instantáneas de forwarding.
- Señales instantáneas de detección de hazards.
- Controles internos que no forman parte del estado registrado.

Tampoco forma parte obligatoria, con las decisiones actuales:

- Reportar `IMEM_CAPACITY_BYTES`.
- Reportar `DMEM_CAPACITY_BYTES`.
- Transmitir un identificador de perfil.
- Exponer buffers o contadores privados del `Loader`.
- Exponer progreso interno de `Session Preparation`.

El software utiliza una configuración externa coherente con el perfil sintetizado mientras no se adopte otra decisión.

---

## Separación entre estado interno y representación externa

La representación binaria y el orden de bytes se consultan en [Campos binarios](../../protocol.md#campos-binarios-y-orden-de-bytes), [Latches](../../protocol.md#latches) y [Memoria utilizada](../../protocol.md#memoria-utilizada). Su aprobación se conserva en DEC-PROTO-001.

Que cierta información esté disponible dentro de la CPU no determina automáticamente cómo se representa fuera de ella.

Por ejemplo:

```text
fault_cause = 3'b101
```

tiene una codificación interna ya fijada, y su transporte/presentación vigente está fijado en [Causa y PC de fault](../../protocol.md#causa-y-pc-de-fault).

Lo mismo ocurre con:

```text
global_state
cycle_count
valid
PC
instruction
```

La arquitectura de Debug fija su significado y coherencia. El protocolo fija su representación externa vigente.

Little-endian arquitectónico y orden UART son decisiones independientes; el acuerdo del protocolo selecciona también little-endian para sus campos multibyte.

### Layout externo aprobado

Para ubicar los campos observados, usar la [distribución general del snapshot](../../protocol.md#distribución-general), fuente canónica de offsets y longitudes. Los offsets son relativos al cuerpo, después de la cabecera común de dos bytes; no se confunden con las posiciones de recorrido del serializador. La aprobación y el orden se conservan en el [acuerdo de delimitación de DEC-PROTO-001](../../decisions/DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--orden-y-delimitación-del-snapshot).

RF y registros interetapa se identifican por posición, sin bytes de ID. Los campos de cada registro interetapa conservan el orden de su esquema en `interfaces.md`. Causa/PC globales siempre están presentes, y solo se interpretan como fault vigente cuando `global_state` lo valida.

La interpretación de cantidad/entradas y el final del cuerpo se consultan en [Memoria utilizada](../../protocol.md#memoria-utilizada) y [Final y longitud](../../protocol.md#final-y-longitud); códigos en [cabecera](../../protocol.md#cabecera-común-de-respuesta) y [global_state](../../protocol.md#global_state); exposición de residuos y descarte de respuestas incompletas en [Interpretación](../../protocol.md#interpretación). Los plazos y la recuperación pertenecen al protocolo. El significado de campos activos/inactivos y la coherencia del estado retenido se desarrollan arriba; la lectura, el encolado y la finalización física están en [response_serializer](response_serializer.md).

---

<a id="invariantes-de-debug"></a>

## Invariantes y condiciones de borde

La observación conserva las siguientes propiedades:

- Un snapshot representa un único estado lógico.
- Una entrada de pipeline con `valid=0` no aparece como una instrucción activa.
- El PC global se distingue del PC propio de cada instrucción en vuelo.
- `fault_cause` y `fault_pc` se interpretan solamente cuando el estado global valida esa información.
- Un candidato de fetch fault no se confunde con un fault confirmado.
- El snapshot posterior a `STEP` representa el estado posterior al ciclo que consumió la orden.
- La lentitud de UART no mezcla estados de ciclos diferentes.
- El wrap de `cycle_count` no invalida una captura.
- Una sesión nueva no expone residuos de la sesión anterior como estado actual.
- DMEM observada conserva el cero lógico y el ownership de memoria.
- Debug no modifica la semántica del pipeline ni introduce nuevos efectos arquitectónicos.
- No se presupone que una captura arbitraria durante `RUNNING` esté habilitada.

Estas propiedades corresponden a `I25` y a las invariantes relacionadas de [Invariantes arquitectónicas](../architectural_invariants.md).

## Verificación y evidencia

### Estado de cierre y trabajo restante

Observación, representación externa, recursos/conexiones y control de serialización están aprobados y contrastados en el [cierre UART](../uart/uart_core.md#presupuesto-de-integración). DEC-SYS-007 está consolidada; no se reabre para implementar o probar estos acuerdos.

El diseño FPGA, incluidos los lanes/metadatos de DMEM, la plataforma, la composición, el plan de verificación y su correspondencia integral, está cerrado documentalmente en FPGA-01–09. Selectores CPU/Debug, preparación de metadatos y codificador global tienen contratos concretos; la implementación debe respetarlos. No se ha implementado ni verificado RTL.

El diseño del assembler está aprobado en [DEC-SYS-009](../../decisions/DEC-SYS-009.md); la aplicación PC conserva su decisión pendiente DEC-SYS-008. Estos diseños no afectan el significado de los snapshots ni los comandos ya aprobados.

---

<a id="trazabilidad"></a>

## Referencias y trazabilidad

- [Visión del sistema](../system_overview.md): relación entre FPGA, UART y software de PC.
- [Pipeline CPU](../cpu/cpu_pipeline.md): estado persistente de los registros interetapa.
- [Control de ejecución y sesión](../session/execution_control.md): `RUN`, `STEP`, terminales y `cycle_count`.
- [Faults, redirects y terminación](../session/faults_and_termination.md): `fault_cause`, `fault_pc` y validez del fault.
- [Arquitectura de memoria](../memory/memory_architecture.md): DMEM, cero lógico y ownership.
- [Invariantes arquitectónicas](../architectural_invariants.md): coherencia de observación y aislamiento.
- [DEC-SYS-005](../../decisions/DEC-SYS-005.md#dec-sys-005--criterio-de-memoria-de-datos-utilizada): criterio y lista binaria de memoria utilizada aprobados.
- [DEC-ARCH-009](../../decisions/DEC-ARCH-009.md#dec-arch-009--campos-de-pipeline-expuestos-por-debug): selección y representación externas aprobadas.
- [DEC-PROTO-002](../../decisions/DEC-PROTO-002.md#dec-proto-002--comandos-adicionales) y [DEC-PROTO-003](../../decisions/DEC-PROTO-003.md#dec-proto-003--timeouts-y-recuperación): comandos auxiliares y tiempos/recuperación aprobados.
- [Protocolo definitivo](../../protocol.md) y [DEC-PROTO-001](../../decisions/DEC-PROTO-001.md#dec-proto-001--formato-detallado-del-protocolo): decisión aprobada y consolidada.
- [DEC-SYS-007](../../decisions/DEC-SYS-007.md#dec-sys-007--servicios-y-parámetros-generales-de-uart): servicios UART aprobados.
- [DEC-SYS-009](../../decisions/DEC-SYS-009.md): diseño del assembler aprobado.
- [DEC-SYS-008](../../decisions/pending_decisions.md#7-software-de-pc): aplicación PC pendiente.
