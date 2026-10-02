# Arquitectura de Debug

## Para qué existe Debug

Un procesador pipeline no puede entenderse observando solamente el valor final de sus registros.

En un momento cualquiera puede haber varias instrucciones en vuelo. Algunas ya produjeron efectos y otras todavía atraviesan IF, ID, EX o MEM. Alguna también puede haber provocado un redirect, un `halt` o un fault. El Register File muestra una parte de esa historia, pero no permite saber por sí solo qué instrucciones siguen activas dentro del pipeline. Del mismo modo, mirar únicamente los registros interetapa no muestra todos los efectos que ya hicieron commit en registros o memoria.

Debug reúne esos planos para poder responder preguntas como:

- qué sesión se está observando;
- qué ciclo lógico alcanzó la CPU;
- cuál es el frente actual de fetch;
- qué valores contiene el Register File;
- qué instrucciones siguen dentro del pipeline;
- qué datos dejó la ejecución en memoria;
- si la sesión terminó normalmente o por fault;
- y, en caso de fault, qué causa y qué PC lo originaron.

La observación no forma parte de la ejecución del programa. Debug describe un estado que ya existe; no cambia la semántica de las instrucciones ni reemplaza al control de ejecución.

RUN, STEP y LOAD continúan gobernados por [Control de ejecución y sesión](execution_control.md). Este documento se concentra en el estado que puede observarse y en las condiciones que hacen que esa observación sea coherente.

---

# Observar estado arquitectónico y estado del pipeline

La información de Debug proviene de dos niveles diferentes del procesador.

El **estado arquitectónico** contiene los valores que una ejecución secuencial del programa consideraría visibles: Register File, memoria de datos y contexto de terminación.

El **estado microarquitectónico persistente** describe cómo ese programa está distribuido actualmente dentro del pipeline: PC global, registros interetapa, validez y contexto asociado a las instrucciones en vuelo.

Ambos niveles son necesarios para interpretar una ejecución.

Por ejemplo, después de un STEP puede ocurrir simultáneamente que:

- una instrucción haya escrito un registro en WB;
- otra esté realizando un acceso en MEM;
- otra se encuentre en EX;
- y una nueva instrucción haya quedado almacenada en IF/ID.

El valor de un registro no permite deducir por sí solo esas posiciones, y las posiciones del pipeline tampoco reconstruyen automáticamente todos los efectos anteriores.

Por eso Debug combina información arquitectónica y microarquitectónica persistente en una misma observación.

---

# Contexto global de la sesión

Antes de interpretar una instrucción o un registro, el software necesita conocer el contexto general en el que esos valores existen.

## `global_state`

Códigos externos aprobados en un byte, en offset cero del cuerpo del snapshot:

| Código | Estado |
|---|---|
| 0x00 | NO_IMAGE |
| 0x01 | LOADING |
| 0x02 | PREPARING_READY |
| 0x03 | READY |
| 0x04 | RUNNING |
| 0x05 | STEPPING |
| 0x06 | HALT_DRAIN_AUTO |
| 0x07 | HALT_DRAIN_STEP |
| 0x08 | FAULT_DRAIN_AUTO |
| 0x09 | FAULT_DRAIN_STEP |
| 0x0A | FINISHED |
| 0x0B | FAULT |
| 0x0C | PREPARING_RUN |
| 0x0D | PREPARING_STEP |

La tabla identifica estados arquitectónicos en UART, sin imponer codificación interna ni ampliar momentos de observación. Véase el [acuerdo de estados](../decisions.md#acuerdo-parcial-de-dec-proto-001--códigos-externos-de-global_state).

`global_state` identifica la fase actual de la sesión.

Permite distinguir, entre otras situaciones:

- ausencia de imagen;
- carga o preparación;
- sesión lista;
- ejecución continua;
- ejecución por pasos;
- drain por `halt`;
- drain por fault;
- terminación normal;
- terminación excepcional.

El software no necesita inferir esas situaciones mirando indirectamente el PC o los bits `valid` del pipeline.

La codificación binaria interna de `global_state` no forma parte todavía del contrato de transporte. Lo importante en esta capa es su significado arquitectónico.

## `cycle_count`

`cycle_count[63:0]` identifica cuántos ciclos efectivos de la CPU ocurrieron dentro de la sesión actual.

Comienza en cero con la preparación de una nueva sesión e incrementa solamente cuando:

```text
cpu_cycle_fire = 1
```

Esto permite correlacionar una captura de hardware con una simulación, un testbench o un modelo de referencia sin confundir ciclos de la CPU con clocks físicos consumidos por UART, Loader o espera entre STEP.

El contador es modular. Su wrap no invalida una observación ni genera un estado especial.

## Imagen confirmada

La observación también distingue si existe una imagen ejecutable.

Internamente:

```text
image_valid =
    (loaded_image_size_bytes != 0)
```

El tamaño confirmado pertenece al estado del sistema, pero eso no obliga a transmitirlo como un campo externo independiente. Lo que sí forma parte de la interpretación de Debug es poder diferenciar una sesión asociada a una imagen válida de la ausencia de programa ejecutable.

---

# PC global y PCs de las instrucciones

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

El PC global y el PC almacenado en un latch pueden ser diferentes y ambos son informativos.

Después de un redirect, por ejemplo, el PC global puede apuntar al nuevo camino mientras una instrucción anterior todavía permanece en MEM o WB con su propio PC.

Por eso una representación de Debug no trata estos valores como equivalentes.

---

# Register File

Debug dispone del Register File completo:

```text
x0 ... x31
```

Cada registro contiene 32 bits y:

```text
x0 = 0
```

permanece constante.

El Register File refleja las escrituras que ya hicieron commit. No muestra resultados que todavía se encuentran en EX/MEM o MEM/WB y aún no alcanzaron writeback.

Esta diferencia es precisamente una de las razones por las que el Register File se observa junto con el pipeline.

---

# Observar el pipeline

Los cuatro registros interetapa son puntos naturales de observación porque contienen el estado registrado que una instrucción transporta de una etapa a la siguiente:

```text
IF/ID
ID/EX
EX/MEM
MEM/WB
```

Debug observa principalmente estos registros persistentes. No se intenta exponer cada señal combinacional del datapath como una señal de Debug.

## Validez

Cada latch tiene una noción de validez.

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

## PC e instrucción

Como mínimo, la interpretación externa de cada latch conserva:

- `valid`;
- el PC propio de la instrucción;
- `instruction`.

Estos tres campos permiten identificar qué instrucción ocupa una etapa y dónde se encontraba en el programa.

El [acuerdo de exposición completa](../decisions.md#acuerdo-parcial-de-dec-arch-009--exposición-completa-de-campos-registrados-del-pipeline) incluye todos los campos funcionales registrados existentes: IF/ID 5, ID/EX 15, EX/MEM 8 y MEM/WB 6. Sus esquemas y anchos internos se mantienen; anchos externos, orden e identificación por posición están aprobados en D05. Los controles/causas conservan los códigos arquitectónicos. Debug transmite los campos registrados e indicadores sin filtrarlos por valid; interpretarlos corresponde al lector. D03/C03 completos; códigos externos globales 0x00–0x0D aprobados.

Esa decisión no vuelve a diseñar los latches. Los registros interetapa ya están fijados funcionalmente; queda elegir qué parte de ese estado registrado forma parte de su representación de Debug.

## Candidato de fetch fault

IF/ID posee además:

```text
fetch_fault_valid
fetch_fault_cause
```

Un `fetch_fault_valid=1` representa un candidato todavía no confirmado.

No equivale a:

```text
fault_active
```

ni transforma la `instruction` residual del latch en una instrucción ilegal.

El candidato registrado de IF/ID se incluye en el contenido Debug aprobado, con fetch_fault_valid y fetch_fault_cause; su PC/causa identifican un candidato y no un fault global confirmado. Ancho y posición externos están aprobados en D05; interpretación de campos inactivos y códigos aprobados en el protocolo definitivo.

---

# Fault observable

Cuando un fault confirma, el procesador captura:

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

- un candidato de fault todavía no confirmado;
- metadata residual sin validez actual;
- un fault confirmado durante drain;
- un estado terminal `FAULT`.

También distingue `FAULT` de `FINISHED`: ambos tienen el pipeline vacío, pero representan terminaciones diferentes.

---

# Data Memory

El estado observable incluye la parte de DMEM que se considere relevante para Debug.

La semántica de los datos ya está fijada por la arquitectura de memoria: cualquier byte no escrito durante la sesión actual se lee lógicamente como cero, independientemente de residuos físicos.

El [criterio aprobado de memoria utilizada](../decisions.md#acuerdo-parcial-de-dec-sys-005--memoria-utilizada-como-bytes-escritos-en-la-sesión) selecciona los bytes escritos efectivamente por stores del programa en la sesión actual, incluidos ceros. SB, SH y SW incorporan sus 1, 2 y 4 bytes al commit. Leer una posición o inicializarla durante preparación no la incorpora; sobrescribirla actualiza su valor sin duplicar la dirección.

Cada snapshot reporta la lista completa en dirección creciente, con dirección y valor actual de cada byte utilizado, coherentes con el mismo instante del resto del estado. No incluye huecos no escritos entre posiciones utilizadas ni representa un historial o solo los cambios del último ciclo.

El conjunto comienza vacío en cada sesión nueva. La metadata de validez por byte de referencia puede reutilizarse para seleccionarlo; este criterio externo no obliga a otro bitmap ni altera la semántica lógica de DMEM. Cantidad, longitud y lista vacía quedan aprobadas por el [layout](../decisions.md#acuerdo-parcial-de-dec-proto-001--orden-y-delimitación-del-snapshot): cinco bytes little-endian para cantidad y cinco por entrada (dirección cuatro, valor uno), sin entradas si cantidad cero. DEC-SYS-005/D04 quedan cerrados; recorrido, ownership y captura quedan para D06 y el diseño de bloques.

---

# Qué es un snapshot

Un **snapshot** representa el estado del procesador en un único instante lógico.

Esto es más fuerte que transmitir individualmente valores que sean correctos por separado.

Supóngase que un STEP produce un writeback en `x1` y simultáneamente hace avanzar las instrucciones del pipeline. Después del flanco existen:

- un nuevo valor de `x1`;
- nuevos contenidos en IF/ID, ID/EX, EX/MEM y MEM/WB;
- un nuevo `cycle_count`;
- posiblemente un nuevo PC.

Una respuesta que combinara el Register File anterior al STEP con los latches posteriores contendría valores que existieron físicamente, pero **no representaría ningún estado real de la CPU**.

La coherencia exige que todos los campos de un mismo snapshot correspondan al mismo estado lógico.

Esto incluye:

- `cycle_count`;
- PC global;
- `global_state`;
- Register File;
- estado observable de los cuatro latches;
- DMEM reportada;
- metadata de fault cuando sea válida;
- e información asociada a la imagen o sesión necesaria para interpretar la captura.

---

# Por qué la coherencia importa con UART

La CPU y UART operan en escalas temporales muy diferentes.

Capturar el estado puede conceptualmente corresponder a un único instante, mientras que transmitir todos sus campos puede ocupar muchos clocks físicos.

Si el transmisor leyera cada elemento directamente mientras la CPU continúa cambiando, el principio y el final del mensaje podrían pertenecer a ciclos distintos.

Por eso la arquitectura fija el **resultado observable**:

> un snapshot representa un único estado lógico, independientemente del tiempo requerido para serializarlo.

El [acuerdo de envío exclusivo](../decisions.md#acuerdo-parcial-de-dec-proto-001--envío-exclusivo-de-debug-con-estado-retenido) selecciona lectura directa del estado retenido. El instante corresponde al estado posterior al STEP efectivo o al último ciclo RUN que alcanza FINISHED/FAULT. Desde ese instante hasta el Stop físico del último byte, la CPU no ejecuta otro ciclo y no comienza LOAD/preparación; RF, latches, PC, contador, estado, imagen y DMEM permanecen estables. UART y recorrido/lectura Debug continúan funcionando, respetando ownership. No se necesita una copia completa adicional del estado.

La PC espera la respuesta completa antes de enviar otra solicitud. La FPGA consume y descarta RX durante la exclusión, sin respuesta ni comandos encolados; también incluye consultas y RESET UART. Este último se envía después del intercambio. El botón físico conserva reset inmediato y puede abortar el envío; la PC descarta la observación incompleta. La admisión vuelve al terminar físicamente el último byte, incluido Stop. RUN conserva aceptación completa antes de su resultado final con Debug.

D06 queda completo en el nivel de contrato; puertos, recorrido/cantidad de memoria utilizada y control privado de la serialización se concretarán en el diseño de bloques. Los plazos PC están aprobados en [C06](../decisions.md#acuerdo-parcial-de-dec-proto-003--plazos-de-reset-step-y-recepción-de-debug): cabecera STEP 200 ms, parte fija de 228 bytes en 319 ms tras cabecera, lista 5*K bytes con transmisión nominal +200 ms desde used_count, sin espera para K=0. Recuperación aprobada en C06: informar fallo y descartar parcial; fuera de LOAD descartar RX por W_debug 6100/3400 ms, limpiar pendiente local y consultar CHECK_READY, sin repetir STEP/RUN/RESET.

---

# Momentos de observación del protocolo

El [orden de intercambios](../decisions.md#acuerdo-parcial-de-dec-proto-001--orden-de-intercambios-y-respuestas) permite una operación normal por vez, con CHECK_READY/RESET durante RUN. Cada respuesta se transmite completa antes de otra; si RUN termina durante una respuesta breve iniciada, se conserva el estado terminal y se termina esa respuesta antes del resultado RUN/Debug. La exclusión D06 abarca el resultado Debug pendiente y transmitido; RESET UART reconocido durante ejecución abandona el RUN previo.

Las operaciones definitivas son LOAD, RUN, STEP, RESET y CHECK_READY, según el [acuerdo de lista final](../decisions.md#acuerdo-parcial-de-dec-proto-002--lista-final-y-nombres-de-operaciones). CHECK_READY es la consulta de disponibilidad para LOAD; Debug se entrega en STEP y final RUN.

El [acuerdo de servicios de Debug](../decisions.md#acuerdo-parcial-de-dec-proto-002--debug-automático-sin-consultas-adicionales) fija exclusivamente snapshots automáticos posteriores a cada STEP realizado y al final de RUN. No se agrega una consulta explícita de Debug ni capturas durante RUNNING/drains AUTO u otros momentos adicionales. PC puede conservar el snapshot recibido, asociado a su sesión; entre pasos sin otra operación de sesión el estado permanece retenido. Los contratos de reset/preparación descritos aquí siguen definiendo el estado lógico y la coherencia de sesión, sin exigir transmitir snapshots en esas fases.

---

# Snapshot después de STEP

STEP ofrece un punto natural de observación porque el procesador vuelve a una situación de espera después de ejecutar un único ciclo, salvo que ese ciclo cambie la sesión hacia drain o terminal.

La información observada corresponde al estado **posterior** al ciclo autorizado.

El [acuerdo de respuesta STEP con Debug](../decisions.md#acuerdo-parcial-de-dec-proto-001--solicitud-step-y-respuesta-con-debug-de-cada-ciclo) fija la entrega automática de ese estado en la única respuesta `[STEP][DONE][estado de Debug]`, después del ciclo efectivo, sin aceptación previa separada ni consulta adicional. El [acuerdo de halt/fault y drenado STEP](../decisions.md#acuerdo-parcial-de-dec-proto-001--halt-fault-y-drenado-en-respuestas-step) conserva esa misma respuesta: global_state distingue HALT_DRAIN_STEP/FINISHED y FAULT_DRAIN_STEP/FAULT; los de fault incluyen causa y PC vigentes. El paso que vacía el pipeline ya muestra el terminal, sin ciclo ni respuesta adicionales. Layout aprobado y coherencia/envío exclusivo definidos en D06; códigos de global_state aprobados; realización de bloques pendiente.

Esto permite ver simultáneamente:

- los efectos que hicieron commit durante ese ciclo;
- cómo avanzaron las instrucciones;
- el nuevo PC;
- el nuevo `cycle_count`;
- y cualquier cambio de `global_state`.

Un stall `load-use` también consume el STEP, por lo que el snapshot posterior puede mostrar que parte del pipeline avanzó mientras el consumidor permaneció retenido.

Debug no redefine qué significa STEP; solamente expone el estado resultante del ciclo descrito en [Control de ejecución y sesión](execution_control.md).

---

# Snapshot al finalizar RUN

Durante RUN, la CPU puede ejecutar muchos ciclos antes de detenerse.

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

- Register File;
- memoria utilizada;
- PC global;
- `cycle_count`;
- estado terminal;
- y, para `FAULT`, `fault_cause` y `fault_pc`.

El [acuerdo de entrega final de RUN](../decisions.md#acuerdo-parcial-de-dec-proto-001--resultado-automático-de-run-con-estado-de-debug) fija el envío automático de ese snapshot junto con el resultado: `[RUN][FINISHED][estado de Debug]` o `[RUN][FAULT][estado de Debug]`, después de la aceptación completa. Se observa el estado terminal posterior al último commit, sin exigir otra consulta. Layout y longitud quedan aprobados en D05; lectura directa de estado retenido y exclusión de solicitudes en D06. Realización de puertos y secuencia de lectura/serialización pendientes del diseño de bloques.

La existencia de esta obligación no implica que una consulta arbitraria tenga que aceptarse mientras `RUNNING` continúa. El protocolo aprobado en D02 no ofrece capturas durante ejecución continua.

---

# Acceso a DMEM y ownership

Observar DMEM introduce una diferencia respecto de leer registros pequeños.

Leer directamente la DMEM del procesador, en lugar de una copia capturada, requiere respetar las reglas de acceso compartido definidas en [Arquitectura de memoria](memory_architecture.md).

Si Debug accede directamente a DMEM, la CPU no está ejecutando ciclos y ningún otro agente realiza un acceso incompatible a la misma memoria.

Una alternativa basada en una captura aislada puede desacoplar la transmisión posterior del acceso a la memoria real.

En ambos casos el resultado observable conserva:

- los mismos datos lógicos;
- la misma semántica little-endian;
- el cero lógico de bytes no escritos;
- y la exclusión entre agentes incompatibles.

Debug no introduce una nueva latencia arquitectónica en loads ni un stall de memoria dentro de la ejecución normal.

---

# Sesiones, reset y reprogramación

Un snapshot pertenece al contexto de una sesión.

Cuando RESET invalida la sesión, una captura anterior puede conservarse físicamente en algún almacenamiento auxiliar, pero ya no representa el estado actual del procesador.

Después de RESET, el PC, Register File, contador y bits de validez del pipeline representan el estado funcional de reset.

De manera equivalente, una reprogramación y preparación posterior crean un nuevo contexto. Debug no presenta datos de la sesión anterior como si pertenecieran a la nueva.

Esta regla es especialmente importante para DMEM, porque el almacenamiento físico puede conservar residuos aunque la nueva sesión los observe lógicamente como cero.

La coherencia de Debug sigue la semántica de sesión, no la mera permanencia física de los bits.

---

# Información observable fijada

Con las decisiones actuales, la arquitectura fija como contenido observable necesario:

| Información | Interpretación |
|---|---|
| `cycle_count[63:0]` | Ciclo lógico de la sesión. |
| PC global | Frente actual de fetch. |
| Estado global | Fase actual de la sesión y tipo de terminación. |
| Imagen válida | Distinción entre imagen ejecutable y ausencia de programa. |
| `x0...x31` | Register File completo. |
| IF/ID | Todos sus 5 campos funcionales registrados, con semántica de validez; layout externo aprobado en D03/D05. |
| ID/EX | Todos sus 15 campos funcionales registrados, con semántica de validez; layout externo aprobado en D03/D05. |
| EX/MEM | Todos sus 8 campos funcionales registrados, con semántica de validez; layout externo aprobado en D03/D05. |
| MEM/WB | Todos sus 6 campos funcionales registrados, con semántica de validez; layout externo aprobado en D03/D05. |
| DMEM utilizada | Lista ordenada de bytes escritos en la sesión, incluidos ceros; cantidad de cinco bytes little-endian y entradas dirección cuatro bytes/valor uno aprobadas. |
| `fault_cause`, `fault_pc` | Válidos cuando el estado global representa fault confirmado. |

Internamente existen otros campos que pueden contribuir a la implementación o a diagnósticos particulares, pero su existencia no los convierte automáticamente en parte obligatoria del snapshot externo.

---

# Información que no forma parte obligatoria del snapshot

La arquitectura no exige exponer todas las señales combinacionales internas.

Entre los ejemplos que permanecen fuera del contrato obligatorio están:

- selectores internos de multiplexores;
- resultados combinacionales intermedios;
- comparadores temporales;
- señales instantáneas de forwarding;
- señales instantáneas de detección de hazards;
- controles internos que no forman parte del estado registrado.

Tampoco forma parte obligatoria, con las decisiones actuales:

- reportar `IMEM_CAPACITY_BYTES`;
- reportar `DMEM_CAPACITY_BYTES`;
- transmitir un identificador de perfil;
- exponer buffers o contadores privados del Loader;
- exponer progreso interno de Session Preparation.

El software utiliza una configuración externa coherente con el perfil sintetizado mientras no se adopte otra decisión.

---

# Separación entre estado interno y representación externa

El [acuerdo de representación del snapshot](../decisions.md#acuerdo-parcial-de-dec-proto-001--representación-binaria-de-campos-del-snapshot) fija binario y little-endian para todos los campos multibyte: 32 bits en cuatro bytes y contador de 64 en ocho. Cada campo pequeño ocupa un byte propio con bits altos cero; flags 00/01. RF ocupa 128 bytes y los campos de IF/ID, ID/EX, EX/MEM y MEM/WB, 11/30/20/15 bytes. Una entrada de memoria utiliza dirección de cuatro bytes y valor de uno. Estas reglas no alteran el estado interno; orden/layout, cantidad y delimitación se fijan en el acuerdo siguiente. Interpretación de campos inactivos y códigos aprobados en D05/C03.

Que cierta información esté disponible dentro de la CPU no determina automáticamente cómo se representa fuera de ella.

Por ejemplo:

```text
fault_cause = 3'b101
```

tiene una codificación interna ya fijada, pero el protocolo puede elegir posteriormente cómo transportar y presentar esa causa.

Lo mismo ocurre con:

```text
global_state
cycle_count
valid
PC
instruction
```

La arquitectura de Debug fija su significado y coherencia. El protocolo fija después su serialización.

Little-endian arquitectónico y orden UART son decisiones independientes; el acuerdo del protocolo selecciona también little-endian para sus campos multibyte.

### Layout externo aprobado

El [acuerdo de orden y delimitación](../decisions.md#acuerdo-parcial-de-dec-proto-001--orden-y-delimitación-del-snapshot) fija offsets relativos al cuerpo, después de la cabecera común de dos bytes:

| Campo / bloque | Offset | Bytes |
|---|---|---|
| global_state | 0 | 1 |
| image_valid | 1 | 1 |
| PC global | 2 | 4 |
| cycle_count | 6 | 8 |
| fault_cause global | 14 | 1 |
| fault_pc global | 15 | 4 |
| RF x0–x31 | 19 | 128 |
| IF/ID | 147 | 11 |
| ID/EX | 158 | 30 |
| EX/MEM | 188 | 20 |
| MEM/WB | 208 | 15 |
| used_count | 223 | 5 |
| Lista dirección/valor | 228 | 5 * used_count |

RF y latches se identifican por posición, sin bytes de ID. Los campos de cada latch conservan el orden de su esquema en interfaces.md. Causa/PC globales siempre están presentes, y solo se interpretan como fault vigente cuando global_state lo valida.

`used_count` unsigned de cinco bytes little-endian cuenta bytes escritos, de cero hasta la capacidad de DMEM inclusive; soporta 2^32 entradas. Cada entrada contiene dirección de cuatro bytes little-endian y valor de uno, en dirección creciente sin duplicados. Cantidad cero significa cinco bytes cero y ninguna entrada. El cuerpo tiene `228 + 5*used_count` bytes; la respuesta completa, `230 + 5*used_count`. La cantidad determina el final, sin marcador ni longitud adicional. Los controles/causas conservan códigos arquitectónicos; resultados 0x01–0x0B aprobados, incluido DONE 0x02 de STEP y FINISHED 0x0A/FAULT 0x0B de RUN; códigos externos de global_state 0x00–0x0D aprobados en el [acuerdo de estados](../decisions.md#acuerdo-parcial-de-dec-proto-001--códigos-externos-de-global_state). Debug transmite campos registrados e indicadores también con valid=0, sin clasificación de residuos ni sustitución por ceros. El lector interpreta la vigencia de cada campo, incluido el candidato fetch separado y el fault global. Una respuesta incompleta se descarta; la última completa se conserva como observación anterior. Véase el [acuerdo de exposición e interpretación](../decisions.md#acuerdo-parcial-de-dec-proto-001--campos-registrados-e-interpretación-del-snapshot). Plazos aprobados en C06 (parte fija 319 ms y lista por K); reacción/recuperación PC aprobada en C06; coherencia y envío exclusivo aprobados en D06; puertos y recorrido pendientes del diseño de bloques.

---

# Decisiones que todavía permanecen abiertas

La arquitectura de observación está parcialmente cerrada, pero todavía existen decisiones necesarias antes de implementar Debug y comunicación.

| Aspecto | Estado pendiente |
|---|---|
| Puertos de lectura de RF/latches y recorrido de snapshot; representación externa aprobada | Diseño de bloques; DEC-ARCH-009 y C03/D05 cerrados |
| Puertos y recorrido/conteo físico de DMEM utilizada; lectura directa retenida aprobada | Diseño de bloques; DEC-SYS-005 y D06 completos |
| Servicios y parámetros físicos de UART | `DEC-SYS-007` |
| Realización física de serialización; protocolo y perfil compartido aprobados | Diseño de bloques; DEC-PROTO-001 y V03 completos |
| Puertos y FSM privadas de reset/arbitraje; selección y contratos de servicios aprobados | `DEC-SYS-007`, diseño de bloques |
| Realización de contadores, señales UART y control de recuperación; contratos de tiempos aprobados | `DEC-SYS-007`, diseño de bloques |
| Estrategia de assembler | `DEC-SYS-009` |
| Forma de la aplicación de PC | `DEC-SYS-008` |

La coherencia se obtiene mediante lectura directa del estado retenido y exclusión de solicitudes aprobadas en D06. Permanecen abiertos los puertos físicos y la secuencia de recorrido/serialización, incluidos conteo y lectura de bytes DMEM utilizados.

---

# Invariantes de Debug

La observación conserva las siguientes propiedades:

- un snapshot representa un único estado lógico;
- una entrada de pipeline con `valid=0` no aparece como una instrucción activa;
- el PC global se distingue del PC propio de cada instrucción en vuelo;
- `fault_cause` y `fault_pc` se interpretan solamente cuando el estado global valida esa información;
- un candidato de fetch fault no se confunde con un fault confirmado;
- el snapshot posterior a STEP representa el estado posterior al ciclo que consumió la orden;
- la lentitud de UART no mezcla estados de ciclos diferentes;
- el wrap de `cycle_count` no invalida una captura;
- una sesión nueva no expone residuos de la sesión anterior como estado actual;
- DMEM observada conserva el cero lógico y el ownership de memoria;
- Debug no modifica la semántica del pipeline ni introduce nuevos efectos arquitectónicos;
- no se presupone que una captura arbitraria durante `RUNNING` esté habilitada.

Estas propiedades corresponden a `I25` y a las invariantes relacionadas de [Invariantes arquitectónicas](architectural_invariants.md).


## Trazabilidad

- [Visión del sistema](system_overview.md): relación entre FPGA, UART y software de PC.
- [Pipeline CPU](cpu_pipeline.md): estado persistente de los registros interetapa.
- [Control de ejecución y sesión](execution_control.md): RUN, STEP, terminales y `cycle_count`.
- [Faults, redirects y terminación](faults_and_termination.md): `fault_cause`, `fault_pc` y validez del fault.
- [Arquitectura de memoria](memory_architecture.md): DMEM, cero lógico y ownership.
- [Invariantes arquitectónicas](architectural_invariants.md): coherencia de observación y aislamiento.
- [DEC-SYS-005](../decisions.md#dec-sys-005--criterio-de-memoria-de-datos-utilizada): criterio y lista binaria de memoria utilizada aprobados.
- [DEC-ARCH-009](../decisions.md#dec-arch-009--campos-de-pipeline-expuestos-por-debug): selección y representación externas aprobadas.
- [DEC-PROTO-002](../decisions.md#dec-proto-002--comandos-adicionales) y [DEC-PROTO-003](../decisions.md#dec-proto-003--timeouts-y-recuperación): comandos auxiliares y tiempos/recuperación aprobados.
- [Protocolo definitivo](../protocol.md) y [revisión documental](../debug_protocol_audit.md): DEC-PROTO-001 aprobada y consolidada.
- `DEC-SYS-007`, `DEC-SYS-008` y `DEC-SYS-009`: tres decisiones generales todavía abiertas.
