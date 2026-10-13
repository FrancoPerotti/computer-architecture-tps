### DEC-ARCH-007 — Temporización del banco de registros

**Contrato vigente de consulta:** [stage_id](../architecture/cpu/stage_id.md), [stage_wb](../architecture/cpu/stage_wb.md), [control_and_hazards](../architecture/cpu/control_and_hazards.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** CPU / Banco de registros

**Fecha de aprobación:** 2026-09-24

**Contexto:** Debía fijarse la interfaz y temporización del banco arquitectónico de 32 registros de 32 bits para un pipeline de cinco etapas, la semántica de lectura y escritura coincidentes, su interacción con forwarding y hazards, el control temporal en `RUN`/`STEP`/`HOLD`/`reset`/`LOAD` y las restricciones de implementación FPGA. Los ocho primeros acuerdos cerraron esos contratos funcionales y el noveno fija la verificación mínima y el cierre conceptual.

**Opciones consideradas:**

- Lecturas combinacionales o síncronas con ciclo adicional.
- Coincidencia WB→ID resuelta por bypass explícito o por el modo interno del almacenamiento.
- Escritura solo desde WB o anticipada.
- Primitiva FPGA obligatoria o neutralidad sujeta al contrato.
- Cierre con o sin matriz verificable.

**Decisión:** Se aprueba el `Register File` 32 × 32 con interfaz funcional 2R1W, dos lecturas combinacionales independientes en ID, escritura síncrona válida exclusivamente desde WB en ciclos CPU efectivos y bypass explícito independiente hacia cada lectura coincidente. `x0` siempre se lee como cero y no se escribe ni recibe bypass. El dato posbypass se captura como valor base en `ID/EX`; la `Forwarding Unit` sigue prefiriendo el productor más reciente disponible en `EX/MEM` o `MEM/WB`, y el hazard `load-use` conserva su stall nominal. Reset, `LOAD`, `RUN`, `STEP`, `HOLD` y ambos drenados obedecen las prioridades globales aprobadas en `DEC-ARCH-008`; cualquier recurso FPGA debe preservar esta interfaz y temporización. La matriz del noveno acuerdo es criterio mínimo obligatorio de aceptación, no evidencia de una implementación ya verificada.

Los nueve acuerdos de este identificador forman el contrato aprobado:

#### Acuerdo parcial aprobado — interfaz lógica del Register File

**Fecha:** 2026-09-24

El banco arquitectónico contiene **32 registros de 32 bits**, `x0` a `x31`, con una interfaz funcional de **dos puertos de lectura y uno de escritura (2R1W)**. ID dispone de ambas lecturas independientes para obtener simultáneamente los dos operandos fuente cuando la instrucción los usa:

| Puerto funcional | Dirección | Dato |
|---|---|---|
| Lectura 1 | `rs1[4:0]` | `rs1_value[31:0]` |
| Lectura 2 | `rs2[4:0]` | `rs2_value[31:0]` |
| Escritura | `rd[4:0]` | `wb_value[31:0]`, con condición de escritura válida |

Los valores leídos en ID se transportan a `ID/EX` junto con sus índices conforme a los campos aprobados en `DEC-ARCH-003`. El **único puerto funcional de escritura** recibe su dato, destino y condición de escritura válida desde **WB**, sin escritura arquitectónica anticipada desde EX o MEM, de acuerdo con `DEC-ARCH-002` y los campos de `MEM/WB` fijados en `DEC-ARCH-003`. Este acuerdo no altera la elegibilidad ya aprobada de escritura válida ni del forwarding externo.

`x0` deberá conservar permanentemente su valor cero conforme a `REQ-CPU-013`; el quinto acuerdo fija lectura cero, ausencia de modificación por intentos de escritura y exclusión del bypass, sin imponer una representación física concreta. Debug no exige aquí un puerto funcional adicional: la observación de los 32 registros podrá definirse mediante snapshot, multiplexado u otro mecanismo compatible con sus decisiones pendientes.

La concreción del contrato sigue esta secuencia:

- Este primer acuerdo fija solo **interfaz lógica y rutas funcionales**
- El segundo fija la lectura combinacional
- El tercero la escritura síncrona
- El cuarto el valor nuevo observable ante coincidencia WB→ID
- El quinto selecciona el bypass interno explícito
- El sexto fija su frontera funcional con el forwarding externo y los hazards
- El séptimo su integración temporal con los modos globales
- El octavo exige que cualquier recurso físico preserve ese contrato. La realización RTL deberá conservar las prioridades de `DEC-ARCH-008`.

#### Acuerdo parcial aprobado — temporización de lectura del Register File

**Fecha:** 2026-09-24

Los dos puertos funcionales de lectura del `Register File` tendrán **salidas combinacionales en ID**. Los índices obtenidos de `IF/ID.instruction` determinarán directamente `rs1_value[31:0] = RF[rs1]` y `rs2_value[31:0] = RF[rs2]` **cuando no exista una escritura WB efectiva coincidente**; el cuarto acuerdo selecciona en ese caso el nuevo `wb_value` para cada puerto coincidente. La lectura no requiere flanco de clock ni ciclo adicional. La ruta conceptual es `IF/ID.instruction → rs1/rs2 → Register File → rs1_value/rs2_value → ID/EX`.

`ID/EX.rs1_value` y `ID/EX.rs2_value` conservarán funcionalmente los valores originales leídos en ID **solo cuando haya un ciclo CPU efectivo autorizado y corresponda capturar una nueva entrada válida en `ID/EX`**, de acuerdo con `DEC-ARCH-003` y `DEC-ARCH-008`. Esos valores sirven de respaldo para la selección posterior mediante forwarding; la lectura combinacional no introduce otra etapa ni cambia el contenido físico aprobado de `ID/EX`. En ciclos que introduzcan una bubble o invaliden la entrada, los bits residuales podrán capturarse o conservarse físicamente, pero no representan operandos de una instrucción válida.

Durante `HOLD` pueden variar las salidas combinacionales por cambios de sus entradas, pero `ID/EX` no captura, el pipeline no avanza y el banco no recibe writebacks originados por CPU. La evaluación combinacional por sí sola no produce una transición arquitectónica.

Este segundo acuerdo **solo fija la temporización de lectura**; el tercero fija la escritura síncrona en un ciclo CPU efectivo, el cuarto establece que la lectura ID coincidente observa el nuevo valor de WB y el quinto garantiza esa selección mediante bypass interno explícito. No se depende del modo read-first/write-first/no-change del almacenamiento ni se incorpora una fase física adicional de clock.

#### Acuerdo parcial aprobado — temporización de escritura del Register File

**Fecha:** 2026-09-24

El puerto funcional de escritura utilizará **escritura síncrona**. La escritura arquitectónica normal del CPU se efectuará solo en el flanco activo correspondiente a un **ciclo CPU efectivo autorizado**, con la instrucción y los campos de `MEM/WB` **previos al flanco**:

```text
if (cpu_effective_cycle && MEM/WB.valid && MEM/WB.reg_write && MEM/WB.rd != x0)
    RF[MEM/WB.rd] ← MEM/WB.wb_value
```

El destino es `MEM/WB.rd[4:0]` y el dato es `MEM/WB.wb_value[31:0]`, exclusivamente desde WB: no se escribe anticipadamente desde EX ni MEM. La instrucción presente en WB puede producir **como máximo una escritura arquitectónica en cada ciclo efectivo válido**. La captura simultánea de una entrada nueva en `MEM/WB` no sustituye los campos previos usados para el writeback de ese ciclo, de acuerdo con el avance aprobado en `DEC-ARCH-003`; su cuadragésimo tercer acuerdo expresa esta habilitación como `rf_write_fire` y la comparte con la elegibilidad del bypass WB→ID.

Durante **`HOLD`** no hay ciclo CPU efectivo ni writeback; el banco conserva su estado frente a la ejecución CPU aunque `MEM/WB` retenga una instrucción válida durante varios clocks físicos. Esa retención no repite la escritura en cada clock, conforme a `DEC-ARCH-008`. Las acciones prioritarias de `reset` global y preparación de `LOAD` conservan sus reglas propias: no se confunden con una escritura arquitectónica ordinaria desde WB.

Una entrada sin permiso de escritura arquitectónica no modifica el banco aunque `rd` o `wb_value` conserven bits residuales: stores, branches, `halt`, entradas inválidas o descartadas e instrucciones causantes de fault no producen writeback propio. Las instrucciones anteriores supervivientes a un fault conservan sus escrituras válidas conforme a `DEC-ARCH-004`. Una escritura destinada a `x0` tampoco modifica su valor arquitectónico; el mecanismo físico concreto de protección permanece abierto.

Este tercer acuerdo fija **solo la temporización síncrona y habilitación de la escritura normal del CPU**. El cuarto fija como resultado arquitectónico de una lectura ID coincidente el nuevo dato de WB y el quinto exige un bypass interno explícito para obtenerlo, independiente del modo del almacenamiento físico.

#### Acuerdo parcial aprobado — lectura y escritura simultáneas sobre el mismo registro

**Fecha:** 2026-09-24

Cuando en un **mismo ciclo CPU efectivo** WB tenga una escritura arquitectónica válida a un registro distinto de `x0` y una instrucción en ID lea ese registro, la lectura de ID observará el **nuevo `MEM/WB.wb_value`**, no el valor anterior almacenado. Para cada puerto se aplica independientemente la siguiente selección conceptual, con los campos de `MEM/WB` anteriores al flanco:

```text
write_enable_efectivo = cpu_effective_cycle && MEM/WB.valid && MEM/WB.reg_write && MEM/WB.rd != x0
rs1_value = (write_enable_efectivo && MEM/WB.rd == rs1) ? MEM/WB.wb_value : RF[rs1]
rs2_value = (write_enable_efectivo && MEM/WB.rd == rs2) ? MEM/WB.wb_value : RF[rs2]
```

Si WB escribe `x5 ← 100` e ID decodifica `add x7, x5, x5`, ambos puertos entregarán `100`. También se seleccionará `wb_value` cuando coincida **solo uno** de los índices; el otro puerto conservará su lectura arquitectónica ordinaria. Cuando corresponda capturar una nueva entrada válida en `ID/EX` en ese ciclo efectivo, `ID/EX.rs1_value` y `ID/EX.rs2_value` conservarán esos valores base correctos, sobre los que EX aplicará después el forwarding de productores más recientes conforme a `DEC-ARCH-003`.

No existe escritura arquitectónica ni selección de `wb_value` por mera coincidencia de bits si falta el ciclo efectivo, `MEM/WB.valid` o `MEM/WB.reg_write`, o si `MEM/WB.rd = x0`. Toda lectura de `rs1=x0` o `rs2=x0` entrega **cero**, incluso si WB presenta datos residuales para `x0`; `x0` queda excluido de la coincidencia WB→ID. `HOLD` no produce writeback ni captura `ID/EX` aunque puedan evaluarse señales combinacionales, conforme a `DEC-ARCH-008`. Instrucciones invalidadas o causantes de fault no aportan escrituras propias, preservando `DEC-ARCH-004`.

Este cuarto acuerdo fija **solo la semántica observable**: WB escribe `R` e ID lee `R` en el mismo ciclo efectivo → ID observa el nuevo valor. El quinto fija un bypass interno explícito `WB → Read Ports` independiente de la semántica del almacenamiento; el sexto fija su frontera funcional con forwarding externo y hazards y el octavo obliga a respetarla con cualquier primitiva física.

#### Acuerdo parcial aprobado — bypass interno explícito `WB → ID`

**Fecha:** 2026-09-24

La selección del valor nuevo de WB se implementará mediante un **bypass combinacional explícito hacia cada puerto de lectura** del `Register File`. Se usan los campos estables de `MEM/WB` previos al flanco y la condición efectiva de escritura arquitectónica del CPU ya aprobada, no una propiedad `write-first`, `read-first`, `no-change` u otra del recurso físico:

```text
wb_write_enable = cpu_effective_cycle && MEM/WB.valid && MEM/WB.reg_write && MEM/WB.rd != x0
bypass_rs1 = wb_write_enable && MEM/WB.rd == rs1
bypass_rs2 = wb_write_enable && MEM/WB.rd == rs2

rs1_value = bypass_rs1 ? MEM/WB.wb_value : RF[rs1]
rs2_value = bypass_rs2 ? MEM/WB.wb_value : RF[rs2]
```

Ambas selecciones son **independientes**: solo una puede coincidir, ambas pueden recibir `wb_value` si `rs1 = rs2 = MEM/WB.rd`, o ninguna puede coincidir. `ID/EX.rs1_value` e `ID/EX.rs2_value` conservarán funcionalmente los valores **posteriores a la selección** cuando se capture una nueva entrada válida en un ciclo efectivo, aunque difieran de las salidas crudas del almacenamiento físico. En ese mismo ciclo, el writeback normal modifica síncronamente el registro destino en el flanco usando los campos previos de `MEM/WB`; no requiere una etapa adicional ni captura de la nueva entrada de `MEM/WB` como fuente anticipada.

**Protección funcional de `x0`:** leer `rs1=x0` o `rs2=x0` siempre devuelve cero; un intento de escribir `rd=x0` **no modifica el banco ni activa ningún bypass**, aun si `wb_value` conserva bits residuales. `wb_write_enable` falso por `HOLD`, invalidez o ausencia de permiso de escritura tampoco activa el bypass por coincidencia de índices; durante `HOLD` no se capturan valores en `ID/EX` ni se realiza writeback. Se conserva la prioridad de `reset`/`LOAD` sobre ciclos CPU de `DEC-ARCH-008` y la ausencia de efectos propios de instrucciones causantes de fault de `DEC-ARCH-004`.

El bypass interno `WB → ID` selecciona los **valores base** leídos en ID, no reemplaza los muxes de forwarding externo `ID/EX`, `EX/MEM` y `MEM/WB` hacia EX aprobados en `DEC-ARCH-003`. El sexto acuerdo fija que la selección final en EX sigue prefiriendo al productor pendiente más reciente y que el bypass no evita ni crea stalls. Este quinto acuerdo fija el mecanismo interno y la protección funcional de `x0`, sin imponer nombres de señales RTL definitivas ni representación física del almacenamiento de `x0`.

#### Acuerdo parcial aprobado — interacción entre bypass interno y forwarding externo

**Fecha:** 2026-09-24

El bypass interno **`WB → ID`** resuelve exclusivamente coincidencias de escritura arquitectónica en WB y lectura del mismo registro en ID durante el mismo ciclo efectivo. Su resultado **posbypass** queda como valor base en `ID/EX.rs1_value` o `ID/EX.rs2_value` cuando corresponda capturar una nueva entrada válida. No reemplaza la `Forwarding Unit` ni sus muxes externos hacia EX aprobados en `DEC-ARCH-003`.

Al llegar la consumidora a EX, cada fuente usada continúa eligiendo la versión más reciente según **`EX/MEM` disponible > `MEM/WB` disponible > valor base de `ID/EX`**. Si un productor coincidente en `EX/MEM` es más reciente pero su dato aún no está disponible, la consumidora debe esperar: el valor base ya corregido por WB→ID **no** autoriza usar una versión anterior. Por ejemplo, con `I1` escribiendo `x5 = 10` en WB e `I2` más reciente produciendo `x5 = 20`, una `I4` que lea `x5` en ID puede capturar `ID/EX.rs1_value = 10` mediante bypass interno; cuando alcance EX, usará **20** si `I2` es el productor pendiente más reciente y su resultado está disponible para forwarding. La selección también se aplica independientemente a `rs2` cuando la instrucción la use.

El bypass interno **no elimina el stall `load-use`**: en `lw x5, ...; add x6, x5, x7`, el load en `EX/MEM` aún no puede entregar el dato cargado a EX; se mantiene la bubble y retención nominal de un ciclo y luego se reenvía desde `MEM/WB` conforme a `DEC-ARCH-003`. Tampoco sustituye la `Forwarding Unit` ni introduce un stall adicional. Si WB es el único productor relevante para una lectura coincidente en ID, el bypass ya entrega el dato correcto y **no se exige un stall adicional por esa coincidencia**.

Este sexto acuerdo fija la **frontera funcional**: WB→ID suministra el valor base; forwarding hacia EX decide el operando efectivo final por productor más reciente y disponibilidad. El séptimo aplica a esos caminos las condiciones temporales de `RUN`, `STEP`, `HOLD`, `reset` y nueva sesión, subordinadas a las reglas globales **ya aprobadas** en `DEC-ARCH-008`. No se modifican los stalls, prioridades, muxes ni campos de registros interetapa de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — comportamiento bajo RUN, STEP, HOLD, reset y nueva sesión

**Fecha:** 2026-09-24

El `Register File` aplicará la jerarquía conceptual **`reset` global > `LOAD` aceptado/preparación de sesión > ciclo CPU efectivo > `HOLD`**, ya aprobada en `DEC-ARCH-008`. La inicialización de sesión y el `reset` no se confunden con una escritura arquitectónica ordinaria de WB. `x0` conserva permanentemente cero bajo todos estos modos.

| Contexto | Comportamiento del `Register File` |
|---|---|
| **`RUN`** | En cada ciclo CPU efectivo, la instrucción **previa al flanco** en `MEM/WB` puede comprometer como máximo una escritura si `valid`, `reg_write` y `rd != x0`; un clock físico sin ciclo efectivo no repite la escritura. |
| **`STEP`** | Cada `STEP` aceptado autoriza exactamente **un** ciclo efectivo y cero o una escritura elegible de `MEM/WB`; otro writeback requiere un ciclo efectivo posterior autorizado por otro `STEP`. |
| **`HOLD`** | No hay writeback CPU; el banco conserva íntegramente su estado aunque `MEM/WB` retenga `valid`, `reg_write`, `rd` y `wb_value` durante múltiples clocks físicos. El write-enable efectivo es cero. |
| **Reset global** | Cuando el `reset` funcional toma efecto conforme a `DEC-ARCH-008`, `x0…x31` quedan **lógicamente en cero**. Reset prevalece sobre cualquier writeback CPU coincidente: ese writeback no se compromete. |
| **`LOAD` aceptado / preparación de sesión** | No se producen writebacks normales del pipeline CPU. Antes del commit de la nueva sesión, `x0…x31` quedan **lógicamente en cero**; una carga confirmada deja el CPU preparado sin iniciar `RUN` ni `STEP`. |
| **`HALT_DRAIN` / `FAULT_DRAIN`** | Las instrucciones anteriores válidas que sobreviven a la frontera pueden escribir al llegar a WB **solo en ciclos efectivos**; bajo contexto `RUN` el drenado progresa automáticamente y bajo paso a paso cada ciclo requiere un `STEP` nuevo. |

En un ciclo efectivo, el writeback elegible usa los campos **anteriores al flanco** de `MEM/WB` y no se duplica por retenerlos en `HOLD`; el bypass interno WB→ID solo se habilita para una escritura CPU realmente elegible. Reset o `LOAD`/preparación inhiben ese commit aunque `MEM/WB` conserve datos anteriores. Las instrucciones causantes de fault y las posteriores descartadas no escriben, mientras las anteriores supervivientes conservan su writeback una vez cuando corresponda, según `DEC-ARCH-004`. La finalización normal por `halt` tampoco detiene prematuramente las escrituras anteriores de su drenado. La validez del pipeline y los modos no habilitan por sí mismos escrituras fuera de ciclos efectivos.

El `reset` global deja al banco **lógicamente** en cero cuando toma efecto funcional; la preparación de `LOAD` garantizará ese mismo valor antes de publicar el commit de la nueva imagen. No se fija un clear paralelo, el borrado inmediato de todos los bits físicos ni otra técnica particular: cualquier realización debe preservar los valores observables y la prioridad aprobada. Los posibles ciclos de mantenimiento de `LOAD` no constituyen ciclos efectivos ni writebacks del pipeline CPU.

Este séptimo acuerdo fija la **integración temporal** del `Register File` con los modos globales. El octavo fija que cualquier tecnología física y sus detalles RTL deben preservarla, sin reabrir la semántica de `DEC-ARCH-008` ni el bypass y forwarding ya acordados.

#### Acuerdo parcial aprobado — contrato de implementación física en FPGA

**Fecha:** 2026-09-24

`DEC-ARCH-007` **no impone una primitiva física específica** para el `Register File`: registros, distributed RAM, LUT RAM, BRAM u otro recurso equivalente son admisibles únicamente si su realización conserva el contrato observable de los acuerdos anteriores. La elección concreta podrá realizarse después según utilización de FPGA, frecuencia alcanzable y resultados de síntesis, sin cambiar la arquitectura.

En cualquier realización deben mantenerse:

- **32 registros de 32 bits**.
- Dos lecturas simultáneas **combinacionales en ID**.
- Un puerto de escritura **síncrona desde WB**.
- Bypass combinacional explícito **WB→ID** por puerto.
- `x0` siempre igual a cero.
- Ausencia de writeback en `HOLD`.
- Ciclos CPU efectivos para `RUN`, `STEP` y drenados.
- Cero lógico del banco tras el `reset` funcional y antes del commit de una nueva sesión.

El recurso elegido no puede cambiar silenciosamente la temporización, la interfaz 2R1W ni la prioridad global aprobada en `DEC-ARCH-008`.

Una primitiva que requiera **presentar la dirección, esperar un flanco y después obtener el dato** no puede sustituir directamente la lectura combinacional de ID si añade un ciclo o altera el pipeline. Se utilizará otra realización o lógica adicional que conserve exactamente los valores y tiempos aprobados, sin introducir otra etapa o un ciclo CPU oculto. La escritura normal sigue tomando los campos previos al flanco de `MEM/WB` en un ciclo efectivo, sin duplicarse por retención en `HOLD`.

La corrección de la lectura y escritura simultáneas del mismo registro **no dependerá** de si la memoria física es `write-first`, `read-first`, `no-change` u otra: el bypass explícito WB→ID seleccionará el nuevo `wb_value` para cada puerto coincidente cuando haya escritura efectiva, conforme al quinto acuerdo. El recurso físico es una elección de implementación; la interfaz y temporización observables son obligatorias.

Este octavo acuerdo fija la **neutralidad de primitiva y las restricciones de toda implementación FPGA**. El noveno acuerdo cierra los **casos límite, la matriz mínima de verificación y la decisión arquitectónica**; la selección concreta del recurso y las ecuaciones RTL finales quedarán para la implementación, sin reabrir estos acuerdos.

#### Acuerdo aprobado — verificación mínima y cierre

**Fecha:** 2026-09-24

La implementación de `DEC-ARCH-007` deberá superar como mínimo la siguiente matriz. Son **criterios de aceptación**, no resultados de pruebas ya ejecutadas:

| Área | Caso mínimo | Resultado esperado |
|---|---|---|
| Estructura | Acceso a `x0...x31` | Existen 32 registros arquitectónicos de 32 bits. |
| Lecturas simultáneas | `rs1 != rs2` | Ambos valores están disponibles simultáneamente en ID. |
| Misma fuente | `rs1 = rs2` | Ambos puertos entregan el mismo valor correcto. |
| Lectura combinacional | Cambio de `rs1`/`rs2` en ID | Las salidas reflejan el registro seleccionado dentro del mismo ciclo, sin flanco adicional. |
| Escritura síncrona | WB válido escribe `rd` | El estado almacenado cambia únicamente en el flanco de un ciclo CPU efectivo. |
| Entrada inválida | `MEM/WB.valid = 0` | No se modifica ningún registro. |
| Sin escritura arquitectónica | `reg_write = 0` | No se modifica ningún registro. |
| Protección de `x0` | Intento de escribir `x0` | `x0` permanece en cero. |
| Lectura de `x0` | `rs1=0` o `rs2=0` | Se obtiene `0x00000000`. |
| Bypass WB→ID en `rs1` | WB escribe el registro leído como `rs1` | ID recibe `wb_value` en ese puerto. |
| Bypass WB→ID en `rs2` | WB escribe el registro leído como `rs2` | ID recibe `wb_value` en ese puerto. |
| Bypass en ambos puertos | `rs1 = rs2 = wb_rd` | Ambos puertos reciben `wb_value`. |
| WB dirigido a `x0` | `wb_rd = 0` | No se activa bypass; las lecturas de `x0` permanecen en cero. |
| Productor más reciente | Coincidencia con WB y productor posterior en `EX/MEM` | EX utiliza el productor pendiente más reciente mediante forwarding cuando su dato esté disponible. |
| `load-use` | Load seguido inmediatamente por consumidor | Se conserva el stall nominal ya aprobado y después se utiliza el dato cargado. |
| Coincidencia solo con WB | Productor relevante únicamente en WB | El bypass interno evita un stall adicional. |
| `HOLD` | Escritor válido permanece físicamente en WB durante varios clocks sin ciclo efectivo | El `Register File` conserva su estado; no se produce ni se repite writeback. |
| `STEP` | Un `STEP` aceptado con escritor válido en WB | Se compromete exactamente el writeback elegible de ese ciclo efectivo, sin otro hasta un nuevo `STEP`. |
| `RUN` | Ciclos efectivos sucesivos | Cada escritor válido compromete como máximo una vez por ciclo efectivo. |
| Reset | Reset funcional coincide con WB válido | Reset prevalece y `x0...x31` quedan lógicamente en cero; no hay writeback coincidente. |
| Nueva sesión | Finaliza correctamente la preparación de `LOAD` | El banco queda lógicamente en cero antes del commit y de ejecutar la nueva imagen. |
| Drenado | Instrucción anterior válida alcanza WB en `HALT_DRAIN` o `FAULT_DRAIN` | Puede escribir exactamente una vez durante un ciclo efectivo autorizado por `RUN` o un `STEP` nuevo. |
| Implementación física | Cambio de primitiva manteniendo el contrato | No cambia la semántica ni aparece latencia adicional de lectura. |

En `HOLD` se verificará expresamente la conservación del estado del banco y la ausencia de **writebacks repetidos** durante clocks físicos sin ciclo efectivo, aunque `MEM/WB` retenga una instrucción escritora, conforme a `DEC-ARCH-008`. Las pruebas de productor más reciente y `load-use` comprueban la frontera de este banco con `DEC-ARCH-003`; no cierran su implementación RTL restante.

##### Contrato consolidado de `DEC-ARCH-007`

```text
Register File: 32 registros × 32 bits; interfaz funcional 2R1W.
Lectura: dos puertos combinacionales simultáneos en ID.
Escritura: síncrona desde WB, solo en un ciclo CPU efectivo
           con MEM/WB.valid, MEM/WB.reg_write y rd != x0;
           datos y controles previos al flanco.
Coincidencia WB → ID: cada puerto coincidente observa wb_value
                     mediante bypass combinacional explícito.
x0: lectura siempre cero, escrituras ignoradas, bypass inhibido.
ID/EX: conserva el valor base posbypass cuando captura entrada válida.
Forwarding EX: EX/MEM disponible > MEM/WB disponible > base de ID/EX;
               si el productor más reciente aún no tiene dato, esperar.
load-use: conserva el stall nominal y el forwarding posterior.
HOLD: sin writeback; banco inalterado aun con WB retenida.
RUN, STEP y drenados: writeback solo en ciclos CPU efectivos autorizados.
Reset funcional / nueva sesión: x0...x31 lógicamente en cero;
                                 LOAD preparado antes del commit.
FPGA: primitiva libre, sujeta a conservar toda la semántica y temporización.
```

Quedan **resueltas las ocho subdecisiones**: interfaz lógica, lectura, escritura, lectura/escritura simultáneas, bypass explícito WB→ID, interacción con forwarding y hazards, modos/`reset`/nueva sesión, neutralidad de implementación física y verificación mínima. `DEC-ARCH-007` queda **conceptualmente cerrada y aprobada**. La implementación RTL posterior de la política de hazards y control aprobada en `DEC-ARCH-003` deberá preservar este contrato.

**Justificación:** La lectura combinacional y el bypass explícito evitan depender de una primitiva FPGA o de su modo de colisión; escribir desde WB solo en ciclos efectivos mantiene resultados precisos y evita commits duplicados en `HOLD`. La matriz mínima permite comprobar los casos límite de interfaz, prioridad de productores y modos antes de aceptar una implementación.

**Consecuencias:** El banco y la integración con el pipeline deben superar los 23 casos mínimos sin introducir latencia extra ni alterar los stalls o el control global aprobados. La elección concreta de almacenamiento, protección física de `x0`, detalles RTL y observabilidad Debug siguen siendo detalles de implementación o de sus decisiones correspondientes; no se requiere una primitiva FPGA ni un puerto funcional extra. `DEC-ARCH-003` se aprobó después y conserva su dependencia de esta decisión.

**Requisitos afectados:** `REQ-CPU-005`, `REQ-CPU-008`, `REQ-CPU-012`, `REQ-CPU-013`, `REQ-CPU-016`, `REQ-HAZ-002` a `REQ-HAZ-006`.

**Reemplaza / Reemplazada por:** No aplica.

---
