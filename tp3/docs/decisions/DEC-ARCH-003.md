### DEC-ARCH-003 — Política de hazards

**Contrato vigente de consulta:** [control_and_hazards](../architecture/cpu/control_and_hazards.md), [cpu_pipeline](../architecture/cpu/cpu_pipeline.md), [stage_id](../architecture/cpu/stage_id.md), [execution_control](../architecture/session/execution_control.md), [faults_and_termination](../architecture/session/faults_and_termination.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** CPU / Hazards

**Fecha de aprobación:** 2026-09-25

**Contexto:** Los acuerdos aprobados fijan los siguientes aspectos:

- El forwarding general hacia EX desde `EX/MEM` y `MEM/WB`, con prioridad del productor más reciente y exclusión de valores todavía no disponibles.
- El stall nominal de un ciclo y su condición conceptual exacta para una dependencia `load-use` inmediata, con PC e `IF/ID` retenidos e `ID/EX` convertido en bubble.
- La clasificación semántica de fuentes `rs1`/`rs2` por instrucción.
- La distinción entre etapa de consumo y resolución en EX del dato de stores, que se transporta por `EX/MEM` para su uso en MEM.
- La matriz de clases y valores reenviables por etapa, incluido el enlace de `jal`/`jalr` desde `EX/MEM`, y la selección en MEM del único valor arquitectónico que `MEM/WB` transporta hacia WB y forwarding y el cálculo físico en EX del enlace de `jal`/`jalr` desde `ID/EX.pc`, seleccionado por el `Result MUX` y el `WB Value MUX` para esos saltos.
- La selección física del único `ex_result` mediante un `Result MUX` de tres entradas (`alu_result`, `immediate`, `link_value`) según la clase de instrucción.
- La generación física del destino en EX mediante `Target Adder`, `JALR Adder` y `Target MUX`, la comparación de branches por resta y `ALU.zero`, y el envío conceptual de `redirect_valid` al `Pipeline Hazard Control` y de `redirect_target` al `Next-PC MUX`.
- La prioridad local de un redirect válido sobre stalls causados exclusivamente por trabajo joven `wrong-path` que se descartará.
- Las transiciones nominales de PC e `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB` ante avance normal, `load-use stall` y redirect, con retención por ausencia de captura e invalidación mediante `valid=0`.
- El mux de próximo PC entre `pc_plus_4` y `redirect_target`, la habilitación de escritura del PC, la captura, retención e invalidación física de `IF/ID` y la captura e invalidación de `ID/EX` y el avance físico de `EX/MEM` y `MEM/WB` y su coordinación nominal mediante `Pipeline Hazard Control` para esos casos.
- La selección exacta e independiente de cada fuente según el productor más reciente, sin sustituirlo por un valor anterior si todavía no está disponible.

La integración y las coincidencias se rigen por los acuerdos 40–47, con prevalencia del acuerdo 47 para la confirmación de fetch y sus acciones. La concreción posterior sigue esta secuencia:

1. El cuadragésimo cuarto acuerdo fija la generación global de `cpu_cycle_fire` y la temporización de inicio/drenado mediante una FSM de 14 estados.
2. El cuadragésimo quinto audita y resuelve las coincidencias globales e integración funcional.
3. El acuerdo 47 revisa la matriz final del acuerdo 46; el protocolo externo conserva su decisión propia.

`next_pc_sel`, `pc_write_enable`, la captura/invalidez de los cuatro registros interetapa y el transporte del enlace para las acciones aprobadas ya tienen ecuaciones de etapa.

La política deberá integrar stalls, flushes y candidatos de fault para que únicamente una operación activa del flujo válido pueda producir error arquitectónico, sin reemplazar la política detallada de faults de `DEC-ARCH-004`. También deberá preservar el progreso concurrente de IF y MEM sin introducir stalls por la lectura de memorias, cuya interfaz combinacional fue acordada en `DEC-ARCH-006`, ni crear un hazard estructural por tratar IMEM y DMEM como un único recurso.

El vigésimo octavo acuerdo fija detección candidata de `halt` en ID y confirmación en EX para trabajo válido del camino correcto: al confirmar se retiene PC, se consume `halt` sin propagarlo válido a `EX/MEM`, se descarta el trabajo joven y las anteriores drenan hasta `FINISHED` solo en ciclos efectivos.

La identificación y concreción posterior de `halt` siguen esta evolución:

- La identificación semántica de `halt` en EX se fija posteriormente como `flow_op=HALT` en el trigésimo tercer acuerdo.
- Su código funcional `flow_op=3'b101` queda fijado en el trigésimo cuarto acuerdo.
- El cuadragésimo acuerdo fija después `ex_halt_candidate`/`halt_confirm` y su precedencia con fault propio y redirect, sin cerrar por sí solo la integración global de enables/flush.
- Los acuerdos cuadragésimo segundo y cuadragésimo tercero fijan después la actualización de registros interetapa y el gating de efectos CPU.

La revisión del [acuerdo 47 de `DEC-ARCH-003`](#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001) sitúa toda confirmación de fetch en ID. La [secuencia con load-use](../architecture/session/faults_and_termination.md#coincidencia-con-load-use) conserva al consumidor durante la retención y permite resolver su EX antes del candidato joven.

El estado de causa/PC confirmado permanece global y fuera del pipeline.

El trigésimo segundo acuerdo fija las ecuaciones funcionales del detector `load-use` y de la `Forwarding Unit`; el trigésimo tercero define seis categorías semánticas del control de `ID/EX` y su reducción hacia `EX/MEM` y `MEM/WB`, sin obligar a un bus `control` único. El trigésimo cuarto acuerdo fija nombres, anchos y códigos de los controles y selectores principales; el trigésimo quinto fija el código de tres bits común a la causa candidata de `IF/ID` y a la causa global confirmada.

El trigésimo sexto fija `terminal_kind[1:0]` y `drain_auto`, con fases de drenado y finalización derivadas de las cuatro validez.

El cuadragésimo quinto acuerdo resuelve después las coincidencias funcionales restantes; la matriz del cuadragésimo sexto queda revisada por el acuerdo 47, y la representación externa Debug/UART corresponde a sus decisiones separadas.

Las transiciones de registros interetapa descritas previamente en `DEC-ARCH-003` son **nominales** para avance, `load-use stall` y redirect sin coincidencia de fault confirmado; el trigésimo acuerdo fija cómo se subordinan al arbitraje por antigüedad cuando sí hay fronteras concurrentes y el trigésimo primero añade la tabla de transiciones resultante. El noveno acuerdo de `DEC-ARCH-004` fija por separado que, tras la confirmación de un fault, PC se retiene, las entradas de la causante y jóvenes no se admiten o se invalidan según `IF/ID`/EX y las anteriores progresan hasta `FAULT`, incluso con stall necesario entre ellas. El décimo acuerdo resuelve la interacción semántica con redirect, `halt` y `load-use` sin cerrar ecuaciones RTL.

**Opciones consideradas:** Mantener solo las reglas nominales de hazards sin integrar coincidencias, o cerrar explícitamente la selección por antigüedad, los controles del pipeline, la autorización global y su composición completa. Implementar un stall estructural compartiendo IF/MEM o respetar sus memorias independientes. Exigir un único bus `ID/EX.control` o preservar categorías funcionales con empaquetado RTL equivalente.

**Decisión:** Se aprueba la política de hazards integrada y verificada documentalmente en los 47 acuerdos siguientes, incluida la auditoría de coincidencias del acuerdo 45, la matriz del 46 y su revisión explícita por el acuerdo 47. La última revisión expresa prevalece sobre representaciones históricas anteriores.

**Justificación:** La matriz final cubre forwarding, stalls, fronteras, acciones, actualización de registros interetapa, gating y FSM sin coincidencias funcionales restantes; separa el contrato arquitectónico de la representación externa Debug/UART y de la elección física de implementación.

**Consecuencias:** La implementación RTL deberá respetar las ocho acciones excluyentes, el control de ciclo y la conservación de efectos de instrucciones anteriores; su verificación posterior usará los invariantes de la matriz final. El empaquetado de `ID/EX.control` no condiciona el cierre; Debug/UART mantiene decisiones independientes en `DEC-ARCH-009` y protocolo.

**Dependencias resueltas:** `DEC-ARCH-001`, `DEC-ARCH-002`, `DEC-ARCH-004` y `DEC-ARCH-007`. M5 — Hazard Freeze.

Los acuerdos 1–46 se conservan en orden cronológico: las referencias a aspectos «pendientes» describen el estado **al aprobar cada acuerdo parcial**, no el estado vigente de este ADR. La revisión del acuerdo 44 prevalece sobre los registros terminales propuestos en acuerdos anteriores, y el acuerdo 47 revisa la matriz del acuerdo 46 y fija la política vigente de confirmación de fetch en ID.

#### Acuerdo parcial aprobado — forwarding general hacia EX

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-22

Para cada operando fuente `rs1` o `rs2` que deba consumirse o quedar resuelto al atravesar EX, el valor efectivo provendrá conceptualmente del valor leído y conservado en `ID/EX`, del resultado disponible de `EX/MEM` o del valor de `MEM/WB` destinado a Write Back. Si dos productores válidos y disponibles escriben el mismo registro fuente, se preferirá **`EX/MEM` > `MEM/WB` > `ID/EX`**: `EX/MEM` contiene la versión más reciente. La selección se hará independientemente para cada operando usado. Así, en `add x5, x1, x2; addi x5, x5, 1; sub x6, x5, x3`, `sub` consumirá el resultado de `addi` y no el de `add`.

El forwarding desde una etapa posterior exige que su instrucción sea válida, escriba arquitectónicamente un registro, tenga `rd != x0`, coincida con el registro fuente realmente usado y ofrezca ya el dato correcto. Una coincidencia de números de registro no basta: una instrucción invalidada o que no escribe `rd` no es productora; `x0` permanecerá en cero. Si el productor más reciente coincidente todavía no tiene el valor disponible, el consumidor deberá esperar antes que usar el valor obsoleto de `ID/EX` o de un productor anterior en `MEM/WB`.

En particular, el dato de un `load` que esté en `EX/MEM` **no está disponible para forwarding normal hacia EX en ese mismo ciclo**. La arquitectura inicial no incorporará un bypass combinacional directo `DMEM → EX`; un consumidor `load-use` inmediato esperará hasta que el dato esté disponible, aunque la interfaz de DMEM tenga lectura combinacional según `DEC-ARCH-006`. Las dependencias ALU→ALU consecutivas con resultados disponibles podrán resolverse normalmente sin stall. Los operandos de branches y `jalr` que se consumen en EX se benefician del mismo criterio general de valores efectivos, preservando `DEC-ARCH-002`.

Este primer acuerdo fija las fuentes, prioridad, elegibilidad y disponibilidad semánticas, sin imponer por sí mismo señales, muxes ni ecuaciones RTL.

Los acuerdos siguientes fijan estos contratos:

- El stall `load-use` nominal y su detección conceptual exacta.
- La clasificación de fuentes y la resolución en EX del dato de stores.
- La matriz de valores reenviables desde `EX/MEM` y `MEM/WB` y el punto de selección del valor arquitectónico para WB en MEM.
- Los campos físicos de los cuatro registros interetapa `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`.
- La prioridad local de redirect sobre un stall causado solo por trabajo joven descartado y las transiciones nominales de validez de los registros interetapa.
- La selección precisa de cada fuente por versión más reciente y los dos muxes combinacionales de forwarding hacia EX.
- El detector combinacional de `load-use` en ID y la `Forwarding Unit`.
- El mecanismo general de retención/invalidez, el mux de próximo PC con habilitación de escritura y la actualización física de `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`.
- El `Pipeline Hazard Control` combinacional para los casos nominales.
- El cálculo en EX y transporte por `ex_result`/`wb_value` del enlace de `jal`/`jalr`.
- El `Result MUX` de tres entradas con selección semántica de resultado ALU, inmediato `LUI` o enlace.
- La generación física del redirect en EX con `Target MUX` y `ALU.zero` para branches.

El trigésimo acuerdo fija posteriormente el orden semántico por antigüedad EX→ID→IF excepcional y el stall entre supervivientes; la realización RTL restante, el control de selección y las interacciones físicas no cubiertas con branches, `jalr` y faults permanecen abiertos en `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — resolución del hazard `load-use`

**Fecha:** 2026-09-22

Una dependencia `load-use` inmediata se resolverá con un **stall nominal de un ciclo**. Se detectará cuando una instrucción `load` válida esté en `ID/EX`, su destino sea `rd != x0` y una instrucción válida en `IF/ID` necesite efectivamente ese registro como fuente. La coincidencia de bits de un campo que la instrucción joven no utiliza no generará este stall; tampoco lo generará un `load` cuyo destino sea `x0`.

En la transición de stall, **PC e `IF/ID` se retendrán e `ID/EX` recibirá una bubble (`valid=0`)**, mientras que el `load` avanzará hacia MEM y las instrucciones más antiguas podrán seguir avanzando. El séptimo acuerdo explicita el avance de `EX/MEM` y `MEM/WB` en este caso. `IF/ID` conservará al consumidor que estaba en ID; la instrucción siguiente que estaba en IF no ingresará a `IF/ID` durante esa transición. El consumidor no se perderá ni se admitirá dos veces. La bubble separará al consumidor del `load` sin congelar globalmente el pipeline.

Tras esa espera nominal, el `load` podrá avanzar hasta `MEM/WB` y el consumidor pasar a EX con el dato correcto suministrado por el forwarding aprobado desde `MEM/WB`. No se agrega un bypass directo `DMEM → EX` ni se toma un valor anterior cuando el dato cargado aún no está disponible. En ausencia de otras causas de espera, esta dependencia agrega una sola bubble/ciclo de stall; la coordinación con otras condiciones concurrentes permanece diferida.

El stall ocurre dentro de un **ciclo lógico efectivo del CPU**, no en `HOLD`: el `load` y las instrucciones anteriores pueden progresar y ese ciclo cuenta una vez conforme a `DEC-ARCH-008`. En `RUN`, el siguiente ciclo habilitado permite continuar; en `STEP`, el stall consume una orden aceptada y los ciclos siguientes siguen requiriendo sus propias órdenes `STEP`. El noveno acuerdo fija la condición conceptual exacta y el decimosexto fija el bloque combinacional de detección en ID, sin imponer señales de enable ni ecuaciones RTL definitivas; el sexto acuerdo fija únicamente la prioridad de redirect frente a stalls originados exclusivamente por trabajo joven descartado, sin resolver las demás coincidencias con flush u otros eventos.

Los acuerdos siguientes clasifican las fuentes `rs1`/`rs2` usadas por cada instrucción, distinguen la etapa de consumo del dato de stores de su resolución al atravesar EX y fijan la prioridad local de redirect sobre stalls del camino descartado. Las demás prioridades stall/redirect/flush, las señales y las ecuaciones concretas de la unidad de hazards corresponden a acuerdos posteriores de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — clasificación semántica de operandos fuente (3A)

**Fecha:** 2026-09-22

La lógica de hazards y forwarding determinará a partir de la instrucción decodificada si esta utiliza `rs1`, `rs2`, ambos o ninguno. Solo una instrucción válida y un operando semánticamente utilizado podrán establecer una dependencia con un productor pendiente; los bits que ocupan posiciones de `rs1` o `rs2` en otra codificación no se interpretarán automáticamente como fuentes.

| Instrucción / clase | Usa `rs1` | Usa `rs2` |
|---|:---:|:---:|
| `add`, `sub`, `sll`, `srl`, `sra`, `and`, `or`, `xor`, `slt`, `sltu` | Sí | Sí |
| `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu` | Sí | No |
| `slli`, `srli`, `srai` | Sí | No |
| `lb`, `lh`, `lw`, `lbu`, `lhu` | Sí | No |
| `sb`, `sh`, `sw` | Sí | Sí |
| `beq`, `bne` | Sí | Sí |
| `jalr` | Sí | No |
| `jal` | No | No |
| `lui` | No | No |
| `halt` | No | No |

Para cada fuente, la dependencia conceptual requiere que la instrucción **use realmente ese operando** y que su índice coincida con el destino de un productor elegible, conforme al primer acuerdo. `uses_rs1` y `uses_rs2` son aquí descripciones conceptuales de las fuentes; el trigésimo séptimo acuerdo fija después sus nombres como salidas combinacionales del decoder, sin registrarlas. Esto impide hazards o forwarding espurios por bits de inmediatos u otros campos: `jal`, `lui` y `halt` no leen registros fuente, y las instrucciones I y los shifts inmediatos no leen `rs2`.

Los stores usan `rs1` como base para calcular la dirección y `rs2` como dato a almacenar; este acuerdo clasifica ambas fuentes. El acuerdo 3B fija sus etapas de consumo y la resolución del dato de store al atravesar EX. Si un `load` inmediato válido produce el `rs2` de un store válido, se conserva el stall nominal del acuerdo anterior: la clasificación 3A no modifica esa espera ya aprobada.

Esta clasificación fija solo la existencia semántica de fuentes; 3B establece cuándo deben resolverse y consumirse. Otras prioridades de hazards y las ecuaciones RTL definitivas se resolverán en acuerdos posteriores de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — etapa de consumo de operandos y tratamiento de stores (3B)

**Fecha:** 2026-09-22

La etapa donde un operando se **consume funcionalmente** se distinguirá de aquella en que su valor efectivo debe quedar **resuelto para atravesar el pipeline**. Para la arquitectura inicial se aprueba la siguiente clasificación, en continuidad con las fuentes semánticas de 3A:

| Instrucción / clase | Operando | Consumo funcional |
|---|---|---|
| R-type | `rs1` | EX |
| R-type | `rs2` | EX |
| I-type aritmética y shifts | `rs1` | EX |
| Loads | `rs1` | EX |
| Stores | `rs1` | EX |
| Stores | `rs2` | MEM |
| `beq`, `bne` | `rs1` | EX |
| `beq`, `bne` | `rs2` | EX |
| `jalr` | `rs1` | EX |
| `jal`, `lui`, `halt` | — | No leen registros fuente |

En `sb`, `sh` y `sw`, `rs1` es la base empleada en EX para calcular la dirección efectiva. `rs2` aporta el dato consumido funcionalmente al escribir DMEM en MEM. Aunque se utilice en MEM, el valor efectivo correcto de `rs2` deberá quedar resuelto cuando el store atraviese EX mediante el esquema general de forwarding, preservarse en el campo `store_data[31:0]` de `EX/MEM` fijado por el duodécimo acuerdo y llegar a MEM para la escritura.

Tanto `load → store-address` (`rs1`) como `load → store-data` (`rs2`) inmediatos utilizarán el mecanismo `load-use` aprobado: en el caso nominal se inserta un stall de un ciclo, y después el store puede recibir el resultado del load por forwarding desde `MEM/WB` hacia EX. La base se consume en EX; el dato correcto se transporta hasta su consumo en MEM. No se incorporará en la arquitectura inicial un bypass especial hacia store-data en MEM, por ejemplo desde `MEM/WB`, para evitar el stall del dato de store.

Esta política reutiliza el forwarding hacia EX y evita un camino especial en MEM, aceptando el stall nominal para `load → store-data`. El duodécimo acuerdo fija los campos físicos de `EX/MEM`. Permanecen diferidos la codificación de controles, las demás señales RTL, las prioridades no cubiertas por el acuerdo local posterior entre redirect y stall del camino descartado, las coincidencias ciclo a ciclo entre hazards y las ecuaciones finales de forwarding y detección. No se reabre la semántica de consumo y transporte aprobada aquí.

#### Acuerdo parcial aprobado — matriz de valores reenviables

**Fecha:** 2026-09-22

Una etapa posterior solo podrá reenviar el valor de una instrucción válida que escriba arquitectónicamente un registro `rd != x0`, si dicho valor ya es el resultado correcto que recibirá Write Back y coincide con una fuente realmente usada. La coincidencia de índices por sí sola no alcanza; el productor más reciente prevalece conforme al primer acuerdo.

| Productor | Forwarding desde `EX/MEM` | Valor reenviado |
|---|:---:|---|
| R-type | Sí | Resultado de ejecución |
| I-type aritmética / shifts | Sí | Resultado de ejecución |
| `lui` | Sí | Valor arquitectónico producido por `lui` |
| `jal` | Sí | `instruction_PC + 4` |
| `jalr` | Sí | `instruction_PC + 4` |
| Loads | No | El dato cargado aún no está disponible |
| Stores | No | No escriben `rd` |
| `beq`, `bne` | No | No escriben `rd` |
| `halt` | No | No escribe `rd` |

Para `jal` y `jalr`, el enlace debe poder obtenerse correctamente como fuente de forwarding desde `EX/MEM` cuando `rd != x0`, además de preservarse para escritura en WB conforme a `DEC-ARCH-002`. El duodécimo acuerdo fija `ex_result[31:0]` como campo que lo conserva en `EX/MEM`; el vigésimo quinto fija su cálculo en EX desde `ID/EX.pc` y su selección por el `Result MUX`. Un load en `EX/MEM` solo dispone de la dirección efectiva en ese campo, no del dato arquitectónico a escribir en `rd`, y no podrá reenviarlo desde allí hacia EX.

| Productor | Forwarding desde `MEM/WB` |
|---|:---:|
| R-type | Sí |
| I-type aritmética / shifts | Sí |
| `lui` | Sí |
| Loads | Sí |
| `jal` | Sí |
| `jalr` | Sí |
| Stores | No |
| `beq`, `bne` | No |
| `halt` | No |

El valor reenviado desde `MEM/WB` será **el mismo `wb_value` arquitectónico seleccionado para Write Back en MEM antes de capturar `MEM/WB`**, según los acuerdos posteriores, provenga originalmente de ALU, DMEM, `instruction_PC + 4` o `lui`. No se requiere reconstruir su origen en la lógica de forwarding; también aquí se exigirán instrucción válida, escritura de registro y `rd != x0`.

Se conserva la prioridad **`EX/MEM` disponible > `MEM/WB` > `ID/EX`** entre productores elegibles. El último acuerdo precisa que primero se identifica la versión más reciente: si un load más reciente en `EX/MEM` coincide con la fuente pero todavía no tiene disponible su resultado, el consumidor esperará conforme al acuerdo de `load-use` en lugar de usar un valor anterior de `MEM/WB` o `ID/EX`. Instrucciones inválidas, stores, branches, `halt`, escrituras a `x0` o resultados todavía no disponibles no son fuentes de forwarding.

Este acuerdo fija clases y valores arquitectónicos reenviables. Los acuerdos undécimo y duodécimo fijan los campos físicos de `MEM/WB` y `EX/MEM`, el decimoquinto fija los dos muxes de forwarding hacia EX y el decimoséptimo fija la unidad combinacional que selecciona sus entradas, sin determinar entonces nombres RTL ni codificación de selectores (fijados después en el trigésimo cuarto acuerdo) ni ecuaciones RTL finales. El sexto acuerdo fija una prioridad local entre redirect y stall del camino descartado; el trigésimo acuerdo fija después el orden semántico entre fronteras de fault, `halt`, redirect y stall entre supervivientes; la integración RTL de coincidencias y hazards de distintas clases continúa abierta en `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — prioridad entre redirección y stall del camino descartado

**Fecha:** 2026-09-22

Dentro de un **ciclo lógico efectivo**, una redirección válida de una instrucción de control más antigua en EX tendrá prioridad sobre un stall causado **exclusivamente por trabajo más joven `wrong-path` que dicha redirección invalidará**. En esa resolución, IF/PC aplicará el destino de `beq`/`bne` tomado o `jal`/`jalr` válido, y todo trabajo joven del camino incorrecto quedará inválido conforme a `DEC-ARCH-002`. La petición de stall de ese trabajo no impedirá actualizar el PC, no conservará instrucciones destinadas al descarte ni las convertirá en trabajo retenido para ciclos posteriores. El PC de destino y la invalidación serán coherentes entre sí; el acuerdo siguiente especifica `IF/ID` e `ID/EX` inválidos durante el redirect, sin exigir un mecanismo RTL particular ni una cantidad fija de instrucciones válidas descartadas.

Esta regla local opera bajo la jerarquía global de `DEC-ARCH-008`: `reset` global, `LOAD` aceptado/preparación de sesión, ciclo efectivo del CPU y `HOLD`, en ese orden. Un `STEP` aceptado habilita exactamente un ciclo que podrá resolver redirect y descarte; el `STEP` se consume allí, sin exigir otro para aplicar la redirección ya resuelta. En `RUN` rige el mismo resultado durante el ciclo habilitado; durante `HOLD` no se actualiza el PC ni se invalida trabajo por una evaluación combinacional.

Un `beq`/`bne` no tomado no produce redirect ni flush: cualquier stall válido conserva su tratamiento normal. El `load-use` clásico ubica un load en `ID/EX` y un consumidor en `IF/ID`; la misma entrada de EX no puede ser simultáneamente ese load y la instrucción de control que redirige. Por ello, su colisión directa no es el caso nominal; la prioridad rige para cualquier stall atribuible únicamente a instrucciones jóvenes que se descartan.

No se establece una prioridad universal de redirect sobre otros eventos: `DEC-ARCH-004` ya prohíbe aplicar redirect a un destino desalineado y fija la prioridad por antigüedad entre instrucciones y por desalineación frente a acceso inválido de la misma operación. La integración RTL con faults de instrucciones más antiguas o de la propia instrucción de control e instrucciones inválidas continúa pendiente de `DEC-ARCH-003`, con la prioridad semántica y atomicidad fijadas en `DEC-ARCH-004`. Los stalls originados en causas que no sean exclusivamente el trabajo joven descartado y otras coincidencias de control permanecen para acuerdos posteriores de `DEC-ARCH-003`; el decimoctavo acuerdo fija el mecanismo físico general de retención e invalidación, sin cerrar las señales ni ecuaciones RTL de flush.

#### Acuerdo parcial aprobado — semántica de `stall`, `bubble` y `flush` sobre el pipeline

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-22

En los casos nominales sin fault confirmado ni coincidencias adicionales aún diferidas, las transiciones conceptuales durante un ciclo lógico efectivo serán:

| Situación | PC | `IF/ID` | `ID/EX` | `EX/MEM` | `MEM/WB` |
|---|---|---|---|---|---|
| Avance normal | Avanza al próximo PC secuencial | Captura IF | Captura ID | Captura EX | Captura MEM |
| `load-use stall` | Retiene | Retiene al consumidor | Bubble (`valid=0`) | Avanza con el load | Avanza con la instrucción anterior |
| Redirect válido en EX | Adopta `target` | Flush (`valid=0`) | Flush (`valid=0`) | Avanza con la instrucción de control válida | Avanza con la instrucción anterior |

El avance normal preserva la validez de las entradas capturadas: no convierte automáticamente una entrada inválida en instrucción activa. El `load-use stall` mantiene al consumidor en `IF/ID` y retiene el PC, mientras el load pasa de EX hacia MEM y las instrucciones más antiguas avanzan; la bubble en `ID/EX` separa productor y consumidor sin congelar todo el pipeline. La instrucción siguiente en IF no desplaza al consumidor durante esa transición.

Ante un redirect válido de `beq`/`bne` tomado o `jal`/`jalr` en EX, IF/PC adopta el destino, `IF/ID` e `ID/EX` quedan inválidos y `EX/MEM` recibe la instrucción de control válida, que podrá continuar hasta WB para escribir el enlace cuando corresponda. `MEM/WB` continúa el avance de instrucciones más antiguas. **Se invalidan los dos registros interetapa jóvenes, sin presuponer que ambos contenían instrucciones válidas**; los campos residuales no representan operaciones activas. Un branch no tomado no redirige ni causa flush: conserva el flujo secuencial y se aplican los stalls independientes que correspondan.

En el flanco efectivo que aplica el redirect, el PC registrado toma el target y la lectura combinacional de IMEM podrá presentar la instrucción de ese nuevo PC después del flanco, conforme a `DEC-ARCH-006`. Esa instrucción **no se captura como válida en `IF/ID` en el mismo flanco**: `IF/ID` e `ID/EX` permanecen inválidos durante esa transición, y el fetch del target podrá incorporarse en el siguiente ciclo efectivo habilitado.

Bubble y flush distinguen espera de descarte, pero ambas producen arquitectónicamente `valid=0` en la entrada afectada. No será obligatorio escribir una NOP física, borrar los demás bits del registro interetapa ni registrar una causa de invalidez diferenciada. Mientras `valid=0`, ninguna lógica funcional interpretará esos bits como instrucción activa: no podrá escribir registros o DMEM, redirigir PC, reconocer arquitectónicamente `halt` ni originar otro efecto de una instrucción válida. La **única excepción de representación** es `IF/ID.valid=0` con `fetch_fault_valid=1`: identifica un candidato de fetch aún no confirmado, no una instrucción ni una causa de bubble/flush; ante descarte de trabajo joven el flag se invalida conforme al vigésimo noveno acuerdo.

Stall, bubble y flush son resultados **dentro de ciclos efectivos**, no `HOLD`, conforme a `DEC-ARCH-008`. El contador lógico cuenta ese ciclo una vez y un `STEP` aceptado queda consumido aunque PC o algún registro interetapa se retenga o invalide.

La concreción posterior de retención y avance sigue esta secuencia:

- El decimoctavo acuerdo fija retención por ausencia de captura e invalidación mediante `valid=0`.
- El decimonoveno fija el mux de próximo PC y la habilitación de escritura del PC.
- El vigésimo concreta la habilitación de escritura e invalidación de `IF/ID`.
- El vigésimo primero concreta la captura e invalidación de `ID/EX`.
- El vigésimo segundo concreta el avance de `EX/MEM` y el vigésimo tercero el de `MEM/WB` sin retenciones ni invalidaciones específicas.
- El vigésimo cuarto fija el bloque combinacional que coordina estos casos nominales.

La tabla describe solo casos nominales; las coincidencias con faults se rigen semánticamente por los acuerdos décimo y duodécimo de `DEC-ARCH-004`. La integración RTL, los stalls de otras causas y las ecuaciones de selección y enables siguen abiertos; los nombres/códigos funcionales principales se fijan en el trigésimo cuarto acuerdo. Se conserva la prioridad local del acuerdo anterior.

#### Acuerdo parcial aprobado — selección exacta de fuentes de forwarding

**Fecha:** 2026-09-23

Para cada fuente `rs1` y `rs2` que la instrucción válida utilice y deba consumir o resolver al atravesar EX, la elección del valor efectivo será **independiente** y respetará la versión más reciente de ese registro en el orden del programa. Primero se identificará al productor pendiente más reciente que escriba arquitectónicamente `rd != x0` y cuyo `rd` coincida con el índice de esa fuente; la disponibilidad de su valor determinará si ya puede reenviarse. Las coincidencias de campos de operandos que la instrucción no usa no serán dependencias.

Si `EX/MEM` contiene ese productor válido y su valor arquitectónico correcto ya está disponible según la matriz del cuarto acuerdo, se seleccionará `EX/MEM`. Si `EX/MEM` **no es productor de ese registro**, y `MEM/WB` contiene un productor válido coincidente con escritura arquitectónica a `rd != x0`, se seleccionará desde `MEM/WB` **el mismo dato seleccionado para Write Back**. Solo cuando no exista un productor pendiente aplicable en `EX/MEM` ni `MEM/WB` se utilizará el valor original de la fuente transportado por `ID/EX`. Estos son criterios conceptuales, no nombres de señales o selectores RTL.

Si `EX/MEM` sí contiene al productor coincidente más reciente pero su resultado aún no está disponible, **no se elegirá `MEM/WB` ni `ID/EX` como sustitutos con una versión anterior**: el consumidor no ejecutará con ese valor y habrá sido retenido por el mecanismo de hazards correspondiente. Un load en `EX/MEM` es el caso característico; el `load-use stall` ya aprobado lo separa del consumidor y, tras la espera, el dato cargado se reenvía desde `MEM/WB`. Esta precisión no crea otro tipo de stall ni modifica su duración nominal.

Ambas fuentes se evalúan por separado: `sub x6, x5, x5` puede recibir el mismo valor de `EX/MEM` por `rs1` y `rs2`, mientras otra instrucción puede obtener una fuente de `EX/MEM` y la otra de `MEM/WB` o del valor original de `ID/EX`. `beq`, `bne` y `jalr` usarán estos operandos efectivos para su resolución en EX conforme a `DEC-ARCH-002`. En stores, `rs1` para la dirección y `rs2` para el dato se resolverán mediante esta misma selección en EX; el dato correcto viajará por `EX/MEM` hasta su consumo en MEM, sin bypass adicional hacia MEM.

La prioridad **`EX/MEM` > `MEM/WB` > `ID/EX`** significa identificar primero al productor más reciente y usar su valor solo cuando esté disponible; en caso contrario, esperar, nunca elegir el primer dato disponible de un productor anterior. El decimoséptimo acuerdo fija una unidad combinacional para controlar los muxes conforme a esta política; sus ecuaciones RTL y la integración física de forwarding, stall, redirect, flush y faults permanecen para acuerdos posteriores de `DEC-ARCH-003`; el trigésimo cuarto fija los códigos de selectores. Se preservan `DEC-ARCH-004` y la lectura combinacional, la escritura síncrona y la política de coincidencias WB→ID ya aprobadas en `DEC-ARCH-007`.

#### Acuerdo parcial aprobado — condición exacta de detección del hazard `load-use`

**Fecha:** 2026-09-23

La detección de `load-use` exigirá una dependencia verdadera e inmediata entre un load válido en `ID/EX` y la instrucción válida inmediatamente más joven en `IF/ID`. La condición conceptual será:

```text
load_use_stall =
    ID/EX.valid
    AND ID/EX.is_load
    AND ID/EX.rd != x0
    AND IF/ID.valid
    AND (
          (IF/ID.uses_rs1 AND IF/ID.rs1 == ID/EX.rd)
          OR
          (IF/ID.uses_rs2 AND IF/ID.rs2 == ID/EX.rd)
        )
```

En esta condición se expresan conceptos funcionales: el trigésimo séptimo acuerdo fija después los nombres combinacionales `uses_rs1` y `uses_rs2` en ID, sin agregarlos a `IF/ID`; los nombres RTL definitivos de las demás señales no se imponen aquí. En la ecuación, `IF/ID.rs1`, `IF/ID.rs2` y `IF/ID.uses_rs1`/`uses_rs2` designan índices y propiedades **derivados combinacionalmente de `IF/ID.instruction` en ID**, no campos físicos registrados en `IF/ID`; el decimocuarto acuerdo fija su contenido. Los indicadores de uso se derivarán de la instrucción decodificada según 3A: solo una fuente realmente leída podrá establecer una dependencia. Un productor o consumidor inválido, una instrucción productora distinta de load, `rd = x0` o una coincidencia accidental de bits en un campo no utilizado no generarán este stall.

Los stores utilizan tanto `rs1` (dirección) como `rs2` (dato), por lo que `load → store-address` y `load → store-data` inmediatos satisfacen esta misma condición; ambos valores deben estar resueltos cuando el store atraviese EX según 3B. `beq`, `bne` y `jalr` también se retendrán cuando su fuente efectiva dependa de ese load, para decidir el flujo en EX con el dato correcto. No se requieren detectores especiales para esas clases.

Si `load_use_stall` es verdadero y se autoriza un ciclo efectivo, se aplicará el stall nominal ya aprobado: PC e `IF/ID` se retienen, `ID/EX` recibe una bubble (`valid=0`) y `EX/MEM` y `MEM/WB` avanzan, permitiendo que el load llegue a MEM. Después, el consumidor podrá continuar y obtener el resultado del load desde `MEM/WB` por forwarding; no se agrega un bypass combinacional `DMEM → EX`. Un stall cuenta como un ciclo lógico incluso en `STEP` y no convierte esa transición en `HOLD`.

La ecuación no incluye un término redirect: la misma entrada `ID/EX` no puede contener simultáneamente un load y una instrucción de control que redirige en EX. Se preserva la prioridad local aprobada para otros stalls causados solo por trabajo joven `wrong-path`, sin fijar aquí la integración RTL de otras causas, faults o instrucciones inválidas; el décimo acuerdo de `DEC-ARCH-004` conserva el stall solo si ambas instrucciones sobreviven a la frontera. El decimosexto acuerdo fija su detector combinacional, sin imponer señales de control RTL finales ni un mecanismo nuevo de stall.

#### Acuerdo parcial aprobado — selección del valor arquitectónico de Write Back en MEM

**Fecha:** 2026-09-23

Durante MEM, **antes de capturar `MEM/WB`**, se seleccionará un único valor arquitectónico de 32 bits destinado a Write Back. Para un load válido que escriba arquitectónicamente `rd`, será el dato leído de DMEM tras la selección y ensamblado little-endian de los bytes y la extensión signed/unsigned correspondiente. Para una instrucción válida R-type, I-type aritmética/shifts, `lui`, `jal` o `jalr` que escriba `rd`, será el resultado arquitectónico producido en EX y transportado mediante `EX/MEM`, incluido `instruction_PC + 4` para el enlace. Conceptualmente:

```text
load válido que escribe rd                  -> wb_value = load_value
R-type, I-type, lui, jal o jalr que escribe rd -> wb_value = EX/MEM.ex_result
```

`load_value` describe el origen conceptual del dato cargado, sin fijar una señal intermedia. Los acuerdos siguientes fijan `wb_value` como campo físico de `MEM/WB` y `ex_result` como campo físico de `EX/MEM`. El vigésimo quinto acuerdo sitúa en EX el `Link Adder` del enlace de `jal`/`jalr` y su selección por el `Result MUX`, sin alterar su disponibilidad para forwarding desde `EX/MEM`. `MEM/WB` conservará **un único dato ya seleccionado** para la escritura en WB y para el forwarding posterior, que reutilizará exactamente ese mismo dato sin volver a reconstruir si provino de ALU, DMEM, `LUI` o `instruction_PC + 4`.

Para stores, branches, `halt`, entradas inválidas o cualquier instrucción que no escriba arquitectónicamente un registro, el contenido del valor seleccionado será irrelevante: validez y habilitación de escritura impedirán que esos bits provoquen escritura en el banco o forwarding. Un load con condición candidata de fault no podrá comprometer un resultado por la mera presencia de bits de dato; la confirmación y prioridad de errores de operaciones del flujo válido siguen correspondiendo a `DEC-ARCH-004`.

La lectura combinacional de DMEM acordada en `DEC-ARCH-006` permite resolver el dato cargado en MEM antes de capturar `MEM/WB`, pero **no añade un bypass combinacional `DMEM → EX`**. El load solo será fuente normal de forwarding hacia EX después de capturarse su valor en `MEM/WB`; el `load-use stall` nominal y el bloqueo de versiones anteriores permanecen vigentes.

Este acuerdo fija el punto de convergencia y el único dato arquitectónico hacia WB; el acuerdo siguiente fija los campos físicos de `MEM/WB`. No se impone el nombre o codificación del selector, las demás señales definitivas de control, las ecuaciones RTL ni la integración RTL de faults y otros eventos.

#### Acuerdo parcial aprobado — contenido físico de `MEM/WB`

**Fecha:** 2026-09-23

`MEM/WB` conservará únicamente los siguientes campos físicos funcionales, suficientes para Write Back, forwarding y la observabilidad mínima del pipeline:

```text
MEM/WB
├── valid
├── pc[31:0]
├── instruction[31:0]
├── rd[4:0]
├── reg_write
└── wb_value[31:0]
```

`valid` identifica una instrucción arquitectónicamente activa; con `valid=0`, los demás bits pueden ser residuales pero no habilitan escritura ni forwarding. `pc[31:0]` y `instruction[31:0]` conservan respectivamente el PC asociado y la palabra completa de la instrucción para la trazabilidad y observabilidad requeridas por Debug, conforme a `DEC-SYS-006`. La representación externa exacta del snapshot permanece para `DEC-ARCH-009`.

`rd[4:0]` identifica el destino arquitectónico para WB y las comparaciones de forwarding. `reg_write` indica si la instrucción escribe arquitectónicamente dicho registro; la escritura efectiva exige `valid`, `reg_write` y `rd != x0`, además de un ciclo habilitado conforme a `DEC-ARCH-008`. El forwarding desde `MEM/WB` exige igualmente esos tres términos y coincidencia con una fuente semánticamente usada, preservando la selección del productor más reciente.

`wb_value[31:0]` contiene el único dato arquitectónico seleccionado en MEM antes de capturar `MEM/WB`: el valor de load leído, ensamblado little-endian y extendido, o el `ex_result[31:0]` transportado por `EX/MEM` para R-type, I-type aritmética/shifts, `lui`, `jal` y `jalr` (incluido el enlace `instruction_PC + 4`). WB y el forwarding desde `MEM/WB` usan directamente este mismo campo, sin reconstruir su origen. El duodécimo acuerdo fija `ex_result` como campo físico de `EX/MEM`. Un load no reenvía desde `EX/MEM` ni por bypass combinacional `DMEM → EX`: su dato solo está disponible para forwarding normal tras la captura en `MEM/WB`.

`MEM/WB` no transportará por separado `ex_result`, `load_value`, `store_data`, `immediate`, `rs1`, `rs2`, `rs1_value`, `rs2_value` ni `mem_op`: ya se consumieron o convergieron en `wb_value`. Para stores, branches, `halt`, entradas inválidas u otras instrucciones sin escritura de registro, los bits de `wb_value` carecen de efecto arquitectónico. Un candidato de fault tampoco se convierte en escritura válida por presentar datos residuales; su confirmación y ausencia de efectos están fijadas en `DEC-ARCH-004`; solo resta la integración RTL en `DEC-ARCH-003`. Agregar otros campos físicos a `MEM/WB` requerirá una revisión explícita de este acuerdo, incluso si la definición de Debug de `DEC-ARCH-009` identificase otra necesidad de observabilidad.

Se fijan los campos físicos funcionales de `MEM/WB`; el vigésimo tercer acuerdo concreta su captura nominal y la propagación de invalidez desde `EX/MEM`, sin flush específico por `load-use` o redirect. El trigésimo cuarto acuerdo fija `reg_write` como señal de un bit (0/1); los acuerdos cuadragésimo primero y segundo fijan después la selección de acciones y las ecuaciones de actualización de `MEM/WB`, sin cambiar este contenido físico; quedan abiertas otras coincidencias no cubiertas. El acuerdo siguiente fija los campos de `EX/MEM`; la política de los demás registros interetapa y las prioridades de eventos todavía abiertas permanecen en `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — contenido físico de `EX/MEM`

**Fecha:** 2026-09-23

`EX/MEM` conservará únicamente los siguientes campos físicos funcionales, necesarios para completar las operaciones de memoria en MEM, permitir forwarding y preservar la observabilidad mínima del pipeline:

```text
EX/MEM
├── valid
├── pc[31:0]
├── instruction[31:0]
├── rd[4:0]
├── reg_write
├── mem_op
├── ex_result[31:0]
└── store_data[31:0]
```

`valid` identifica una instrucción arquitectónicamente activa. Una entrada inválida no podrá escribir DMEM ni posteriormente el banco de registros, reenviar un valor ni producir otro efecto funcional aunque sus demás bits sean residuales. `pc[31:0]` e `instruction[31:0]` conservan el PC asociado y la palabra completa de la instrucción para su trazabilidad y observabilidad conforme a `DEC-SYS-006`. La representación externa del snapshot se decidirá en `DEC-ARCH-009`.

`rd[4:0]` identifica el destino de instrucciones escritoras para las comparaciones de forwarding y su transporte hacia `MEM/WB` cuando corresponda. `reg_write` indica la intención arquitectónica de escribir `rd`; la codificación y las ecuaciones concretas de control siguen diferidas. El forwarding desde `EX/MEM` requiere un productor válido con escritura, `rd != x0`, coincidencia con una fuente semánticamente usada y disponibilidad del valor arquitectónico correcto. Un load en `EX/MEM` puede tener `reg_write`, pero su `ex_result` es la dirección efectiva, **no** el dato a escribir en `rd`, por lo que no reenvía desde esa etapa ni habilita un bypass `DMEM → EX`.

`mem_op` transporta a MEM la información necesaria para distinguir load de store, ancho de acceso y, para cargas, extensión con signo o con cero. El trigésimo cuarto acuerdo fija después `mem_op[3:0]` y su codificación para `NONE`, cinco loads y tres stores. Para loads y stores, `ex_result[31:0]` contiene la dirección efectiva que MEM usará para acceder a DMEM. Para R-type, I-type aritmética/shifts, `lui`, `jal` y `jalr`, contiene el valor arquitectónico producido en EX, reenviable cuando se cumplen las condiciones anteriores y transportado a MEM para la selección de `wb_value` antes de `MEM/WB`. En `jal` y `jalr` es el enlace `instruction_PC + 4`, calculado en EX desde `ID/EX.pc` conforme al vigésimo quinto acuerdo, sin adelantar la escritura del banco a EX. El vigésimo sexto acuerdo concreta la selección de estos valores y direcciones mediante el `Result MUX`.

`store_data[31:0]` conserva el valor efectivo de `rs2` resuelto mediante forwarding al atravesar EX; `sb`, `sh` y `sw` lo consumen en MEM para escribir DMEM. La dirección proviene de `ex_result`, mientras `mem_op` define el acceso. También para `load → store-data` inmediato se conserva el stall nominal y el forwarding posterior `MEM/WB`→EX: no se agrega bypass especial hacia MEM. Una entrada inválida con `mem_op` y `store_data` residuales no podrá habilitar una escritura a DMEM; las condiciones candidatas de fault no se confirman por sí solas, conforme a `DEC-ARCH-004` ya aprobada.

No se transportarán por separado en `EX/MEM` `rs1`, `rs2`, `rs1_value`, `rs2_value`, `immediate`, `link_value` ni `alu_result`: los valores necesarios ya se consumieron en EX o quedaron consolidados en `ex_result` o `store_data`. Agregar otros campos físicos requerirá revisión explícita de este acuerdo, incluso si `DEC-ARCH-009` identificase otra necesidad de observabilidad.

Este acuerdo fija los campos físicos funcionales de `EX/MEM`; el vigésimo segundo acuerdo fija su captura nominal sin retención por `load-use` ni invalidación por redirect. Siguen abiertos la codificación de `mem_op`, los enables y prioridades fuera de esos casos nominales, el control concreto de escritura de memoria, la integración con faults y las demás señales y ecuaciones RTL. El acuerdo siguiente fija los campos de `ID/EX`, sin cerrar la composición interna de su control.

#### Acuerdo parcial aprobado — contenido físico de `ID/EX`

**Fecha:** 2026-09-23

`ID/EX` conservará los siguientes **diez elementos funcionales enumerados**, necesarios para ejecutar en EX, resolver las fuentes por forwarding, transportar el destino y preservar la observabilidad mínima del pipeline. El elemento `control` es un placeholder de información semántica y no exige un único campo RTL físico, conforme a la revisión explícita del trigésimo tercer acuerdo:

```text
ID/EX
├── valid
├── pc[31:0]
├── instruction[31:0]
├── rs1[4:0]
├── rs2[4:0]
├── rd[4:0]
├── rs1_value[31:0]
├── rs2_value[31:0]
├── immediate[31:0]
└── control
```

`valid` identifica una instrucción arquitectónicamente activa. Una entrada con `valid=0` no podrá originar efectos funcionales, hazards o forwarding como instrucción válida, aunque los demás campos conserven bits residuales. La bubble del stall `load-use` y el flush de una redirección invalidan `ID/EX` con `valid=0`, sin obligar a limpiar otros bits ni codificar causas distintas. `pc[31:0]` conserva el PC **de esta instrucción** para calcular destinos relativos al PC o el enlace `instruction_PC + 4` cuando corresponda; `instruction[31:0]` conserva la palabra completa para trazabilidad y observabilidad según `DEC-SYS-006`. La representación externa exacta seguirá en `DEC-ARCH-009`.

`rs1[4:0]` y `rs2[4:0]` guardan los índices extraídos en ID para comparar, **independientemente por cada fuente realmente usada**, con `rd` de productores pendientes en `EX/MEM` y `MEM/WB`. Su presencia física no convierte un campo no utilizado en fuente semántica: rige la clasificación 3A y no se activan hazards ni forwarding por coincidencias accidentales.

`rs1_value[31:0]` y `rs2_value[31:0]` contienen los valores base capturados en ID tras el bypass interno WB→ID cuando corresponda; cada uno es la base en EX solo cuando no hay productor pendiente aplicable para esa fuente. Se mantiene la selección por versión más reciente **`EX/MEM` disponible > `MEM/WB` > `ID/EX`**: si un productor más reciente coincide pero su valor todavía no está disponible, no se utiliza el valor original ni otro anterior.

La lectura combinacional, la escritura síncrona, el bypass interno explícito WB→ID y su frontera funcional con forwarding externo ya están fijados en `DEC-ARCH-007`: un valor base posbypass cede ante el productor pendiente más reciente en EX, sin alterar la selección aprobada. La elección del recurso físico queda para implementación, bajo el contrato aprobado de `DEC-ARCH-007` y las prioridades globales ya fijadas.

`rd[4:0]` conserva el destino arquitectónico y avanzará a las etapas siguientes cuando corresponda. `immediate[31:0]` contiene el inmediato generado y extendido en ID para las instrucciones que lo usan en EX. `control` designa colectivamente la información requerida en EX y, cuando corresponda, en etapas posteriores: el trigésimo tercer acuerdo fija sus categorías `alu_op`, `alu_src`, `result_sel`, `flow_op`, `mem_op` y `reg_write`, sin obligar a agruparlas en un campo físico único. El trigésimo cuarto acuerdo fija luego sus nombres, anchos y códigos funcionales principales; las ecuaciones RTL del control path y el empaquetado opcional permanecen abiertos.

Los índices y valores de fuente permiten aplicar la misma política a ALU, stores, branches y `jalr`: ambos operandos de store se resuelven al atravesar EX aunque su dato se consuma en MEM, y una dependencia `load-use` inmediata conserva el stall nominal sin bypass `DMEM → EX`. El contenido físico de `ID/EX` no introduce nuevas prioridades entre stall, redirect, flush o faults. Cualquier campo físico adicional requerirá revisión explícita de este acuerdo, también si `DEC-ARCH-009` identificase otra necesidad de observabilidad.

Este acuerdo enumera diez elementos funcionales de `ID/EX`, incluido el placeholder `control` cuya composición semántica revisa el trigésimo tercero; el vigésimo primer acuerdo concreta su captura nominal y la invalidación física de `valid` para bubble y flush. Siguen abiertos nombres, representación/codificación y ecuaciones RTL de control y la integración física de la política de faults aprobada en `DEC-ARCH-004`. El acuerdo siguiente fija los campos físicos de `IF/ID`.

#### Acuerdo parcial aprobado — contenido físico de `IF/ID`

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-23

La aprobación original de este decimocuarto acuerdo fijó los **tres campos de instrucción** de `IF/ID`. El vigésimo noveno acuerdo lo **revisa explícitamente** para añadir dos campos de candidato de fetch; el contenido físico vigente es:

```text
IF/ID
├── valid
├── pc[31:0]
├── instruction[31:0]
├── fetch_fault_valid
└── fetch_fault_cause[2:0]
```

`valid` indica si la entrada representa una instrucción arquitectónicamente activa. Con `valid=0`, la lógica de decodificación, hazards y control no podrá tratarla como instrucción válida ni permitir efectos de esa instrucción aunque los bits de `instruction` sean residuales; **`fetch_fault_valid=1` identifica por separado un candidato de fetch**, aún no confirmado. `pc[31:0]` conserva el PC propio de la instrucción obtenida o del fetch candidato, no el PC global de IF; acompaña a una instrucción válida cuando avance a `ID/EX` para cálculos relativos al PC y enlace `instruction_PC + 4` en EX. `instruction[31:0]` conserva la palabra completa de una instrucción válida para decode y trazabilidad conforme a `DEC-SYS-006`; no tiene significado arquitectónico en una entrada de fetch fault.

En ID, a partir de `instruction[31:0]` se extraerán combinacionalmente `rs1`, `rs2` y `rd`, se generará el inmediato correspondiente y se derivará la clasificación semántica de fuentes de 3A. No se registrarán por separado en `IF/ID` `rs1`, `rs2`, `rd`, `uses_rs1` ni `uses_rs2`: los términos `IF/ID.rs1`/`rs2` y `IF/ID.uses_rs1`/`uses_rs2` de la condición de `load-use` son notación conceptual para los valores derivados, no campos adicionales. Solo las fuentes realmente usadas y una entrada válida podrán establecer una dependencia; la coincidencia de bits de un campo no utilizado no provocará stall.

En un ciclo efectivo de `load-use stall`, `IF/ID` retiene **sus cinco campos sin cambios** para conservar al consumidor, mientras PC se retiene e `ID/EX` recibe una bubble. Si IF detecta entonces un fetch fault válido, se aplica la excepción de confirmación en IF del vigésimo noveno acuerdo sin capturar su candidato en `IF/ID`. Ante redirect válido en EX, `IF/ID` queda con `valid=0` **y `fetch_fault_valid=0`** para descartar tanto trabajo joven como candidato de fetch `wrong-path`; `pc` e `instruction` no necesitan borrarse y el fetch del target no se captura como válido en el mismo flanco. Una entrada inválida sin flag de fault no decodifica trabajo ni confirma error por residuos. `DEC-ARCH-004` fija validez, antigüedad y prioridad de causas; un target desalineado no aplica el redirect nominal aquí descrito.

Los **cinco campos** son el contenido físico funcional revisado de `IF/ID`; cualquier otro campo requeriría una nueva revisión explícita, también si `DEC-ARCH-009` determinase que necesita más estado registrado para Debug. El decimoctavo acuerdo fija el mecanismo general de retención e invalidación y el vigésimo precisa la actualización física nominal de `IF/ID`; el vigésimo noveno añade el transporte de candidato sin alterar `valid`. El cuadragésimo segundo acuerdo fija después las ecuaciones de captura/retención/invalidez de `IF/ID` para las nueve acciones; el cuadragésimo cuarto acuerdo fija después la FSM/control global de ciclos; otras coincidencias siguen pendientes de `DEC-ARCH-003`. El acuerdo siguiente fija los muxes de forwarding hacia EX.

#### Acuerdo parcial aprobado — realización física del forwarding hacia EX

**Fecha:** 2026-09-23

El camino de forwarding hacia EX empleará **dos multiplexores combinacionales independientes de tres entradas y 32 bits**, uno para cada fuente semánticamente utilizada. Su estructura física de datos será:

```text
Forward MUX A
├── ID/EX.rs1_value[31:0]
├── EX/MEM.ex_result[31:0]
└── MEM/WB.wb_value[31:0]
        ↓
rs1_effective[31:0]
```

```text
Forward MUX B
├── ID/EX.rs2_value[31:0]
├── EX/MEM.ex_result[31:0]
└── MEM/WB.wb_value[31:0]
        ↓
rs2_effective[31:0]
```

Cada mux se seleccionará independientemente: las dos fuentes pueden tomar datos de etapas distintas, ambas de una misma etapa o una del valor original. La identificación del productor pendiente **más reciente** de cada registro usado precede a la selección del dato. Se conserva la prioridad conceptual **`EX/MEM` disponible > `MEM/WB` > `ID/EX`**:

| Condición | Selección |
|---|---|
| En `EX/MEM` hay un productor válido que escribe `rd != x0`, coincide con la fuente y ya tiene disponible el valor arquitectónico correcto | `EX/MEM.ex_result` |
| `EX/MEM` no produce esa fuente y `MEM/WB` contiene un productor válido coincidente y escritor | Se permite `MEM/WB.wb_value` |
| No hay productor pendiente aplicable | Valor original de `ID/EX` |

Una instrucción inválida, una fuente no utilizada, un productor sin escritura o una escritura a `x0` no habilitan forwarding por mera coincidencia de campos.

Desde `EX/MEM` pueden reenviarse resultados disponibles de R-type, I-type aritmética/shifts, `lui` y enlaces `instruction_PC + 4` de `jal`/`jalr`. Para un load en `EX/MEM`, `ex_result` contiene la **dirección efectiva**, no el dato cargado. Si ese load es el productor coincidente más reciente, el consumidor esperará según la política de hazards aprobada: ni un `MEM/WB` anterior ni el valor original obsoleto de `ID/EX` se elegirán como operandos válidos; el decimoséptimo acuerdo distingue esta regla del valor combinacional residual que pueda presentar físicamente un mux durante la espera. Tras la captura del dato en `MEM/WB` podrá elegirse `wb_value`, el mismo valor arquitectónico utilizado para Write Back sin reconstruir su origen (ALU, DMEM, enlace o `lui`). No se incorpora bypass combinacional `DMEM → EX` ni se modifica el stall `load-use` nominal.

Los valores efectivos de ambos muxes se utilizarán en EX según la clase de instrucción: operaciones ALU, operandos de `beq`/`bne` y `jalr`, base y dato de stores resuelto al atravesar EX. La topología de los dos muxes no fijó las señales selectoras ni su ancho o codificación, determinados después para `forward_a_sel[1:0]`/`forward_b_sel[1:0]` en el trigésimo cuarto acuerdo; las ecuaciones RTL de la unidad se fijan después en el trigésimo noveno acuerdo; permanecen abiertos otros caminos de datos y la integración RTL frente a redirect, flush o faults. Las notaciones `rs1_effective` y `rs2_effective` describen las salidas de los muxes; sus selectores son `forward_a_sel[1:0]` y `forward_b_sel[1:0]` conforme a los acuerdos posteriores. El acuerdo siguiente fija el bloque combinacional que detecta `load-use` en ID y el decimoséptimo la unidad que controla los dos muxes.

#### Acuerdo parcial aprobado — realización física del detector de hazard `load-use`

**Fecha:** 2026-09-23

Un **bloque combinacional ubicado lógicamente en ID** observará al productor inmediatamente anterior en `ID/EX` y al consumidor en `IF/ID`. Sus entradas conceptuales serán:

```text
Desde ID/EX
├── valid
├── rd[4:0]
└── información que permita determinar is_load

Desde IF/ID / decodificación en ID
├── valid
├── rs1[4:0]
├── rs2[4:0]
├── uses_rs1
└── uses_rs2
```

El resultado conceptual `load_use_stall` se determinará **exactamente** por la condición ya aprobada:

```text
load_use_stall =
    ID/EX.valid
    AND ID/EX.is_load
    AND ID/EX.rd != x0
    AND IF/ID.valid
    AND (
          (IF/ID.uses_rs1 AND IF/ID.rs1 == ID/EX.rd)
          OR
          (IF/ID.uses_rs2 AND IF/ID.rs2 == ID/EX.rd)
        )
```

El bloque podrá usar comparaciones de igualdad entre cada índice fuente y `ID/EX.rd`, junto con lógica combinacional para validez, clase load, `rd != x0` y uso real de las fuentes. Su clase `is_load` se obtiene de información ya disponible en `ID/EX` sin fijar un subcampo, ancho o codificación de `ID/EX.control`. Los índices `rs1`/`rs2` y `uses_rs1`/`uses_rs2` del consumidor se derivan combinacionalmente de `IF/ID.instruction` en ID: el trigésimo séptimo acuerdo fija después las salidas combinacionales del decoder, sin añadir campos físicos a `IF/ID`. Coincidencias accidentales en fuentes no usadas, `rd=x0`, un productor no load o entradas inválidas no activarán el resultado. El detector puede representarse como un único bloque **`Load-Use Hazard Detector`**, sin exponer compuertas individuales en el diagrama arquitectónico.

La salida es un resultado combinacional: puede evaluarse durante `HOLD`, pero **solo un ciclo lógico efectivo** podrá aplicar sus efectos. Para un `load_use_stall` verdadero en el caso nominal, PC e `IF/ID` se retienen, `ID/EX` recibe bubble (`valid=0`) y `EX/MEM` y `MEM/WB` avanzan; el load llega a MEM y el consumidor continuará luego con forwarding desde `MEM/WB`. Esta condición incluye dependencias reales sobre base o dato de stores, operandos de `beq`/`bne` y fuente de `jalr`, sin añadir detectores específicos ni cambiar el stall nominal de un ciclo.

La ecuación no incorpora redirect: en la misma entrada `ID/EX` no pueden estar a la vez el load que activa esta detección y la instrucción de control que redirige en EX. Se conserva la prioridad local aprobada para stalls debidos exclusivamente al trabajo joven `wrong-path`; el décimo acuerdo de `DEC-ARCH-004` aplica el stall de `load-use` solo si productor y consumidor sobreviven como anteriores a un fault, descartando dependencias cuyo consumidor sea causante o joven.

La realización temporal/física de la confirmación de faults y las demás coincidencias continúan pendientes, sin cambiar el detector combinacional nominal: su resultado solo se **aplica** cuando el hazard sigue siendo necesario.

Este acuerdo fija el bloque combinacional, sus entradas y la condición que evalúa; el vigésimo cuarto acuerdo incorpora su resultado conceptual al `Pipeline Hazard Control` nominal, sin fijar nombres RTL definitivos de señales hacia enables/retención/flush ni su integración con otros eventos. El acuerdo siguiente fija la unidad combinacional de selección de forwarding, separada de este detector.

#### Acuerdo parcial aprobado — realización física de la `Forwarding Unit`

**Fecha:** 2026-09-23

Una **`Forwarding Unit` combinacional** controlará de forma independiente los dos multiplexores 3:1 de 32 bits aprobados para los operandos efectivos de EX. Observará conceptualmente:

```text
Desde ID/EX
├── rs1[4:0]
├── rs2[4:0]
├── uses_rs1
└── uses_rs2

Desde EX/MEM
├── valid
├── rd[4:0]
├── reg_write
└── información que permita determinar disponibilidad del resultado

Desde MEM/WB
├── valid
├── rd[4:0]
└── reg_write
```

Sus dos salidas conceptuales, `forward_a_sel` y `forward_b_sel`, seleccionarán independientemente para cada fuente realmente usada el dato original `ID/EX.rs1_value` o `ID/EX.rs2_value`, `EX/MEM.ex_result` o `MEM/WB.wb_value` a través del mux correspondiente. `uses_rs1` y `uses_rs2` son propiedades derivables de la instrucción/control ya disponible en `ID/EX`, **no campos físicos adicionales**; la disponibilidad del resultado en `EX/MEM` también se determina con información ya conservada allí, sin fijar su codificación ni añadir un campo al registro interetapa. Una entrada consumidora de `ID/EX` con `valid=0` no podrá usar arquitectónicamente selecciones combinacionales residuales, sin imponer aquí un puerto físico adicional de la unidad.

Para cada fuente, la unidad identificará primero al **productor pendiente más reciente** que escriba arquitectónicamente `rd != x0` y coincida con su índice. Si `EX/MEM` contiene ese productor válido y su resultado arquitectónico correcto ya está disponible, seleccionará `EX/MEM.ex_result`. Si `EX/MEM` no produce ese registro y `MEM/WB` contiene un productor válido coincidente con `reg_write` y `rd != x0`, seleccionará `MEM/WB.wb_value`. Si no existe productor pendiente aplicable, conservará el valor original de `ID/EX`. Ni un productor inválido o sin escritura ni una coincidencia en una fuente semánticamente no usada habilitarán forwarding. La selección de `rs1` y `rs2` será independiente y podrá escoger etapas distintas o la misma etapa según corresponda.

Si `EX/MEM` contiene el productor coincidente más reciente pero su dato todavía no está disponible, **no se utilizará `MEM/WB` ni `ID/EX` como sustituto obsoleto**. El consumidor deberá haber sido retenido por el mecanismo de hazards correspondiente; el valor combinacional que pueda presentar físicamente un mux durante esa espera no se consumirá como operando válido y no requiere una cuarta entrada o codificación de selección. Un load en `EX/MEM` tiene en `ex_result` solo la dirección efectiva y es el caso característico. El dato cargado podrá llegar por `MEM/WB.wb_value` tras la captura en `MEM/WB`, sin bypass `DMEM → EX` ni un nuevo tipo de stall.

Este acuerdo fija la unidad funcional combinacional, su información de entrada y la política para controlar ambos muxes, preservando la matriz de resultados reenviables y el valor de WB ya seleccionado en MEM.

El trigésimo segundo acuerdo fija posteriormente las ecuaciones booleanas funcionales de coincidencia y selección por fuente; no modifica esta política ni agrega campos. `forward_a_sel[1:0]` y `forward_b_sel[1:0]` reciben nombres, anchos y códigos funcionales definitivos en el trigésimo cuarto acuerdo; el trigésimo noveno acuerdo fija después las ecuaciones RTL de coincidencia, selectores y muxes combinacionales, sin cerrar la integración global con detector `load-use`, enables, invalidaciones, redirect y faults.

La lectura combinacional, la escritura síncrona, el bypass interno explícito que garantiza el valor nuevo en WB→ID y su frontera funcional con forwarding externo y `load-use` están fijados en `DEC-ARCH-007`. Su séptimo acuerdo fija la integración temporal con avance, `HOLD`, `reset` y sesión conforme a `DEC-ARCH-008`, mientras el octavo acuerdo impide que la tecnología física del banco altere ese contrato. Su realización RTL se concretará en implementación.

La confirmación arquitectónica de faults está fijada en `DEC-ARCH-004` y su implementación RTL se integra en `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — realización física de retención, bubble e invalidación

**Fecha:** 2026-09-23

Para los casos nominales de `load-use stall` y redirect se distinguirán dos mecanismos físicos generales: **retención**, que impide capturar valores nuevos y conserva íntegro el contenido registrado, e **invalidación**, que captura una entrada inválida o fuerza `valid=0` en el registro interetapa afectado. PC e `IF/ID` tendrán mecanismos conceptuales de habilitación de escritura que permitan retenerlos inhibiendo su actualización en un ciclo efectivo; este acuerdo no fija nombres ni ecuaciones RTL de esos enables.

Ante un `load-use stall` nominal durante un ciclo lógico efectivo:

```text
PC      → retiene su valor
IF/ID   → retiene sus cinco campos sin cambios (tras la revisión del acuerdo 29)
ID/EX   → recibe bubble mediante valid=0
EX/MEM  → avanza con el load productor
MEM/WB  → avanza con la instrucción anterior
```

Así el consumidor permanece íntegro en `IF/ID` y el load previamente ubicado en `ID/EX` avanza, sin congelar `EX/MEM` o `MEM/WB` ni capturar en `IF/ID` la instrucción siguiente. La bubble se materializa invalidando la **nueva entrada de `ID/EX`** (`valid=0`), no reteniendo el load en ese registro interetapa. No se exige escribir una NOP física ni borrar los otros campos: los residuos de una entrada inválida no habilitan ejecución, escrituras, redirect, `halt` o faults arquitectónicos.

Ante un redirect válido resuelto en EX durante un ciclo lógico efectivo:

```text
PC      → captura redirect_target
IF/ID   → queda inválido con valid=0
ID/EX   → queda inválido con valid=0
EX/MEM  → avanza con la instrucción de control válida
MEM/WB  → avanza con la instrucción anterior
```

El flush de `IF/ID` e `ID/EX` descarta trabajo más joven `wrong-path` sin necesitar limpiar PC, instrucción u otros bits residuales de esos registros interetapa; en `IF/ID` **también se limpia `fetch_fault_valid`** cuando ese candidato pertenece al camino descartado, aunque `valid` ya sea cero. No se captura como válida la instrucción del target en `IF/ID` en el mismo flanco del redirect. Una solicitud de retención causada **exclusivamente** por ese trabajo joven no impediría capturar el target ni conservaría como válido lo descartado, conforme a la prioridad local ya aprobada. Esto no declara una prioridad universal entre redirect y otras causas.

En síntesis, **retener significa no capturar una entrada nueva**; bubble o flush significan producir `valid=0` en la entrada afectada. Son resultados de un ciclo efectivo, no de la evaluación combinacional durante `HOLD`; un `STEP` autorizado se consume y el contador lógico avanza una vez conforme a `DEC-ARCH-008`. Se fija el mecanismo físico general de estos dos casos nominales, sin elegir nombres RTL, ecuaciones de enable/flush, ecuaciones RTL de integración con faults de `DEC-ARCH-004`, otros stalls o eventos concurrentes ni la realización restante del control path.

#### Acuerdo parcial aprobado — realización física del control de actualización del PC

**Fecha:** 2026-09-23

El control nominal de actualización del registro PC utilizará un **`Next-PC MUX`** con dos entradas conceptuales, `pc_plus_4` y `redirect_target`, seguido de un registro PC con habilitación de escritura:

```text
pc_plus_4 --------\
                   > Next-PC MUX ---> PC
redirect_target --/

PC
└── write_enable
```

`pc_plus_4` representa el próximo PC secuencial calculado desde el **PC global actual**; no es el enlace `instruction_PC + 4` de una instrucción en EX. El mux selecciona el valor de flujo secuencial o el destino de una redirección válida resuelta en EX. PC solo captura la salida seleccionada cuando se habilita su escritura durante un ciclo lógico efectivo. En los casos nominales ya aprobados:

| Situación | `Next-PC MUX` | Escritura de PC | Resultado |
|---|---|---|---|
| Avance normal | Selecciona `pc_plus_4` | Habilitada | PC captura el valor secuencial |
| `load-use stall` | Irrelevante | Deshabilitada | PC conserva íntegramente su valor |
| Redirect válido en EX | Selecciona `redirect_target` | Habilitada | PC captura el destino |

Durante el stall nominal, el valor en la entrada del registro PC no importa mientras se inhiba su escritura; `IF/ID` conserva sus cinco campos conforme a la revisión del acuerdo vigésimo noveno e `ID/EX` recibe una bubble, mientras los registros interetapa más antiguos avanzan. Durante el redirect, la carga del destino se coordina con `IF/ID.valid=0`, `IF/ID.fetch_fault_valid=0` e `ID/EX.valid=0`, sin capturar el fetch del target como válido en `IF/ID` en ese mismo flanco. Un stall provocado **exclusivamente** por trabajo joven `wrong-path` que se invalidará no inhibirá la carga de `redirect_target`, conforme a la prioridad local ya aprobada. Un branch no tomado sigue el flujo secuencial salvo que se aplique un stall independiente válido; una entrada inválida en EX no puede solicitar redirect por sus bits residuales.

La habilitación local de escritura opera bajo la autorización global de `DEC-ARCH-008`: durante `HOLD` no se captura ningún próximo PC aunque el mux presente un valor; un `STEP` aceptado aplica a lo sumo una actualización en su único ciclo efectivo. Reset y `LOAD` conservan su prioridad global sin imponer entradas adicionales al mux nominal. Se fija la **estructura física general** de selección y escritura del PC, sin fijar nombres RTL definitivos, codificación del selector, ecuaciones de habilitación o selección, realización del sumador secuencial ni ecuaciones RTL de integración con faults de `DEC-ARCH-004`, otros stalls o eventos concurrentes.

#### Acuerdo parcial aprobado — realización física de la actualización de `IF/ID`

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-23

El registro `IF/ID` dispondrá conceptualmente de **habilitación de escritura** para capturar o retener su contenido, y de un mecanismo de invalidación capaz de producir `valid_next=0`:

```text
IF/ID
├── write_enable
└── mecanismo para producir valid_next = 0
```

Durante un ciclo lógico efectivo de avance normal, `IF/ID` tiene la escritura habilitada y captura conjuntamente desde IF sus **cinco campos** tras la revisión explícita del vigésimo noveno acuerdo: `valid`, `pc[31:0]`, `instruction[31:0]`, `fetch_fault_valid` y `fetch_fault_cause`. La validez de instrucción capturada no se deduce de un candidato de fetch: fetch normal captura `valid=1, fetch_fault_valid=0`; fetch candidato captura `valid=0, fetch_fault_valid=1` con PC y causa asociados. Durante un `load-use stall` nominal se deshabilita la escritura: `IF/ID` **retiene íntegramente** sus cinco campos, preservando al consumidor en ID mientras el load anteriormente situado en `ID/EX` avanza; `ID/EX` recibe una bubble según el acuerdo de transiciones. La excepción aprobada para un fetch fault de IF que coincide con ese stall confirma directamente en IF sin escribir su candidato sobre el consumidor.

Ante un redirect válido resuelto en EX durante un ciclo efectivo, `IF/ID` produce `valid_next=0` **y `fetch_fault_valid_next=0`** y descarta su entrada joven, incluso si ya era un candidato con `valid=0`. `pc`, `instruction` y `fetch_fault_cause` pueden conservar bits residuales: no se exige limpiar esos campos ni escribir una NOP física; sin `valid` ni flag de candidato no se permiten efectos ni confirmación de fault del trabajo descartado. La instrucción del target no se captura como válida en `IF/ID` en el mismo flanco. Si una solicitud de retención coincide con ese redirect y **proviene exclusivamente de trabajo joven `wrong-path`** que se invalidará, prevalece el descarte: no se retiene trabajo incorrecto. Esta prioridad local no determina el tratamiento de otras causas de retención.

La aplicación de captura, retención o invalidación requiere un ciclo efectivo autorizado por `DEC-ARCH-008`: la evaluación combinacional durante `HOLD` no modifica `IF/ID` y un `STEP` aceptado aplica una sola transición. Queda fijada la estructura física general de actualización de `IF/ID` para los casos nominales; `write_enable`, `valid_next` y `fetch_fault_valid_next` son nombres conceptuales, sin fijar nombres RTL definitivos, codificación de señales, ecuaciones de control ni ecuaciones RTL de integración con faults de `DEC-ARCH-004` u otros eventos concurrentes. La ampliación a cinco campos está documentada **explícitamente** en el vigésimo noveno acuerdo; fuera de ella no se agregan campos registrados.

#### Acuerdo parcial aprobado — realización física de la actualización de `ID/EX`

**Fecha:** 2026-09-23

En avance normal durante un ciclo lógico efectivo, `ID/EX` captura desde ID los **diez elementos funcionales enumerados**, asociados a la misma entrada: `valid`, `pc[31:0]`, `instruction[31:0]`, `rs1[4:0]`, `rs2[4:0]`, `rd[4:0]`, `rs1_value[31:0]`, `rs2_value[31:0]`, `immediate[31:0]` y el conjunto semántico `control`, sin exigir un único bus RTL para este último conforme al trigésimo tercer acuerdo. Capturar una entrada inválida no la convierte en una instrucción activa.

Ante un `load-use stall` nominal, la **nueva entrada** de `ID/EX` tendrá `valid_next=0`: se inserta una bubble por espera, no se retiene en `ID/EX` el load que lo ocupaba. Ese load avanza simultáneamente hacia `EX/MEM`, mientras el consumidor permanece íntegro en `IF/ID` y las instrucciones anteriores continúan avanzando. Ante un redirect válido resuelto en EX, también se produce `ID/EX.valid_next=0`, esta vez como flush que descarta la entrada joven `wrong-path`; la instrucción de control más antigua continúa válida hacia `EX/MEM`. En el caso nominal de `load-use` la entrada en EX es un load, por lo que no coincide en ese mismo `ID/EX` con la instrucción de control que redirige. Para una petición de retención causada exclusivamente por trabajo joven descartado sigue rigiendo la prioridad local de redirect previamente aprobada, sin extenderla a otros eventos.

```text
load-use stall → bubble por espera  ─┐
                                     ├→ ID/EX.valid_next = 0
redirect       → flush por descarte ─┘
```

No se necesita escribir una NOP física ni borrar `pc`, `instruction`, índices de registros, `rd`, valores de operandos, inmediato o `control`: sus bits residuales con `valid=0` no producen efectos funcionales, hazards o forwarding como instrucción válida. Bubble y flush tienen causas distintas y el mismo efecto físico nominal sobre `valid` de la nueva entrada; no se agrega un campo de causa. La captura e invalidación solo se aplican en ciclos efectivos `RUN`/`STEP` conforme a `DEC-ARCH-008`; una evaluación combinacional durante `HOLD` no cambia `ID/EX`. Un `STEP` aceptado consume exactamente el ciclo efectivo en que se aplica la transición. Este acuerdo no fija nombres RTL definitivos, codificación, ecuaciones de invalidación ni ecuaciones RTL de integración con faults de `DEC-ARCH-004` u otros eventos concurrentes, y no agrega campos ni codifica `ID/EX.control`.

#### Acuerdo parcial aprobado — realización física de la actualización de `EX/MEM`

**Fecha:** 2026-09-24

En cada ciclo lógico efectivo habilitado de los casos nominales de avance normal, `load-use stall` y redirect válido en EX, `EX/MEM` **captura la salida de la instrucción que ocupaba `ID/EX` al comenzar la transición**, junto con los resultados correspondientes de EX. El nuevo `ID/EX.valid_next=0` producido por bubble o flush en ese mismo ciclo no sustituye el `ID/EX.valid` anterior que alimenta la captura en `EX/MEM`. No se retiene ni invalida `EX/MEM` por ninguno de esos dos eventos nominales.

```text
EX/MEM.next.valid        = ID/EX.valid
EX/MEM.next.pc           = ID/EX.pc
EX/MEM.next.instruction  = ID/EX.instruction
EX/MEM.next.rd           = ID/EX.rd
EX/MEM.next.reg_write    = control correspondiente a la instrucción en EX
EX/MEM.next.mem_op       = control correspondiente a la instrucción en EX
EX/MEM.next.ex_result    = ex_result producido en EX
EX/MEM.next.store_data   = rs2_effective resuelto en EX
```

Estas expresiones son conceptuales: `reg_write` y `mem_op` provienen del control correspondiente sin fijar su codificación, y el valor de `store_data` solo tiene uso funcional para un store válido. `ex_result` representa la dirección efectiva para loads/stores o el resultado arquitectónico ya aprobado de ALU/`LUI`/enlace para las otras clases; **un load en `EX/MEM` transporta dirección, no dato cargado para forwarding hacia EX**. Si `ID/EX` estaba inválido, `EX/MEM` captura `valid=0`; los demás campos pueden contener residuos sin efectos funcionales.

Ante un `load-use stall` nominal, `EX/MEM` captura **el load válido que estaba en `ID/EX`** y permite que avance hacia MEM y luego `MEM/WB`, mientras `IF/ID` retiene al consumidor e `ID/EX` recibe una bubble. El dato del load se podrá reenviar posteriormente desde `MEM/WB`, no desde `EX/MEM`. Ante un redirect válido resuelto en EX, `EX/MEM` captura **la instrucción de control válida que estaba en `ID/EX`**, mientras PC adopta `redirect_target` e `IF/ID` e `ID/EX` quedan inválidos para descartar el trabajo más joven `wrong-path`. La instrucción de control no forma parte de ese descarte y continúa hacia etapas posteriores, incluido WB para un enlace de `jal`/`jalr` cuando corresponda. En avance normal, `EX/MEM` captura igualmente la entrada y el resultado de EX sin volver válida una entrada previamente inválida; `MEM/WB` continúa avanzando conforme a la tabla nominal.

Durante `HOLD` ninguna evaluación combinacional produce una captura en `EX/MEM`, conforme a `DEC-ARCH-008`; en `RUN` o en el único ciclo efectivo de un `STEP` aceptado se aplica la transición nominal. Reset y `LOAD` conservan la prioridad global ya aprobada. Este acuerdo fija solo el avance físico nominal de `EX/MEM`, sin definir enables o ecuaciones RTL. El noveno acuerdo de `DEC-ARCH-004` exige `EX/MEM.next.valid=0` cuando la causante confirmada ocupa EX, preservando el avance de la entrada anterior de `EX/MEM` hacia `MEM/WB`; la integración RTL con eventos concurrentes sigue abierta en `DEC-ARCH-003`, sin reabrir la prioridad arquitectónica aprobada.

#### Acuerdo parcial aprobado — realización física de la actualización de `MEM/WB`

**Fecha:** 2026-09-24

En cada ciclo lógico efectivo habilitado de avance normal, `load-use stall` o redirect válido en EX **en los casos nominales**, `MEM/WB` captura la salida de MEM correspondiente a la entrada **previa** de `EX/MEM`. Este último puede estar capturando simultáneamente otra instrucción desde EX sin cambiar cuál se transfiere a `MEM/WB`. El dato `wb_value` será el único valor arquitectónico ya seleccionado en MEM **antes de la captura**, conforme al acuerdo décimo, no un dato reconstruido desde la nueva entrada de `EX/MEM`:

```text
MEM/WB.next.valid        = EX/MEM.valid
MEM/WB.next.pc           = EX/MEM.pc
MEM/WB.next.instruction  = EX/MEM.instruction
MEM/WB.next.rd           = EX/MEM.rd
MEM/WB.next.reg_write    = EX/MEM.reg_write
MEM/WB.next.wb_value     = wb_value seleccionado en MEM
```

Para un load válido que escribe `rd`, el `wb_value` capturado es el dato leído, ensamblado little-endian y extendido en MEM. Para las demás instrucciones válidas escritoras pertinentes es el resultado arquitectónico conservado en `EX/MEM.ex_result`, incluido el enlace de `jal`/`jalr`. WB y el forwarding desde `MEM/WB` usan ese mismo campo; no existe bypass combinacional `DMEM → EX`. Para stores, branches, `halt` e instrucciones que no escriben `rd`, el contenido residual de `wb_value` no habilita escritura ni forwarding.

Ante un `load-use stall` nominal, `MEM/WB` recibe la instrucción más antigua que **ya ocupaba `EX/MEM`**, mientras el load previo de `ID/EX` pasa a `EX/MEM`, `ID/EX` recibe una bubble e `IF/ID` conserva al consumidor. Ante un redirect válido resuelto en EX, `MEM/WB` recibe igualmente la instrucción que **ya ocupaba `EX/MEM`**, más antigua que la de control que redirige; esta última entra en `EX/MEM` mientras `IF/ID` e `ID/EX` invalidan el trabajo joven `wrong-path` y PC captura el target. La redirección no descarta el trabajo anterior ni exige un flush o retención específica de `MEM/WB`. En avance normal, `MEM/WB` también captura la entrada correspondiente de MEM.

Si `EX/MEM.valid=0` antes del flanco, entonces `MEM/WB.next.valid=0`: se **propaga** una entrada inválida o bubble existente, sin que eso constituya un flush particular de `MEM/WB`. Sus otros campos pueden conservar bits residuales, sin escritura arquitectónica o forwarding. Este comportamiento de avance solo se aplica en un ciclo CPU efectivo de `RUN` o `STEP`; durante `HOLD` `MEM/WB` permanece estable aunque cambien señales combinacionales, conforme a `DEC-ARCH-008`. Reset y `LOAD` conservan su prioridad global. No se fijan nombres, enables o ecuaciones RTL definitivas, ni la integración RTL con faults u otros eventos concurrentes, que debe preservar `DEC-ARCH-004`.

#### Acuerdo parcial aprobado — realización física del control nominal de hazards del pipeline

**Fecha:** 2026-09-24

Una lógica **combinacional** central, denominada conceptualmente `Pipeline Hazard Control`, coordinará en los casos nominales la retención, invalidación y selección de próximo PC ya aprobadas por separado. Recibirá como mínimo conceptual `load_use_stall`, producido por el detector en ID, y `redirect_valid`, decidido por una instrucción de control válida en EX. Determinará las acciones correspondientes sobre PC y su `Next-PC MUX`, `IF/ID` e `ID/EX`; `EX/MEM` y `MEM/WB` continúan avanzando conforme a los acuerdos de cada registro interetapa. El detector de `load-use` y la `Forwarding Unit` conservan sus funciones independientes: esta lógica no redefine la condición de detección ni las selecciones de operandos reenviados.

Para un **ciclo lógico efectivo** en los casos nominales cubiertos:

| Selección de control | PC y `Next-PC MUX` | `IF/ID` | `ID/EX` | `EX/MEM` | `MEM/WB` |
|---|---|---|---|---|---|
| `redirect_valid` | Habilitar PC y capturar `redirect_target` | Invalidar, `valid_next=0` | Invalidar, `valid_next=0` | Capturar la instrucción de control válida de EX | Capturar la entrada previa de `EX/MEM` |
| Sin redirect, `load_use_stall` aplicable | Inhibir escritura de PC; entrada del mux irrelevante | Retener íntegramente `valid`, `pc` e `instruction` | Bubble, `valid_next=0` | Capturar el load previo de `ID/EX` | Capturar la entrada previa de `EX/MEM` |
| Sin redirect ni stall aplicable | Habilitar PC y seleccionar `pc_plus_4` | Capturar IF | Capturar ID | Capturar EX | Capturar MEM |

La validez de cada entrada capturada en avance normal proviene de su etapa anterior: una entrada inválida no se reactiva por avanzar. En el redirect, `EX/MEM` y `MEM/WB` no se invalidan específicamente y el fetch del target no entra válido en `IF/ID` en el mismo flanco; en el stall nominal, PC e `IF/ID` se retienen mientras las instrucciones anteriores progresan. La bubble por espera y el flush por descarte comparten `valid_next=0` en `ID/EX` sin requerir una NOP física o limpieza de otros campos.

Para este **dominio nominal**, la selección conceptual es `redirect válido > load-use stall aplicable > avance normal`. Si un redirect de una instrucción más antigua coincide con una petición de retención debida **exclusivamente a trabajo joven `wrong-path` que se descarta**, esa petición no bloquea el target ni conserva válidas las entradas invalidadas, conforme a la prioridad local ya aprobada.

El `load-use` clásico requiere un load en `ID/EX`, mientras un redirect válido exige allí una instrucción de control, por lo que **no existe su colisión directa** en la misma entrada.

Esta jerarquía nominal no desplaza la prioridad arquitectónica por antigüedad de `DEC-ARCH-004` ni el stall necesario entre instrucciones anteriores a un fault en IF; los demás stalls e integración RTL con eventos concurrentes quedan abiertos.

Un target desalineado de la propia instrucción de control no aplica redirect. Un branch no tomado no activa redirect ni flush y conserva el tratamiento de un stall independiente válido.

La lógica puede evaluar combinacionalmente sus entradas durante `HOLD`, pero no actualiza PC ni registros interetapa ni incrementa el contador hasta que `DEC-ARCH-008` autorice un ciclo CPU: `RUN` aplica la transición en sus ciclos efectivos y un `STEP` aceptado autoriza exactamente una. Reset y `LOAD` aceptado conservan la prioridad global. Se fija la existencia y función del bloque nominal, sin imponer puertos físicos adicionales ni ecuaciones finales de enables/invalidaciones/selección; el trigésimo cuarto acuerdo fija los nombres y códigos de `next_pc_sel` y `pc_write_enable`. Permanece abierta la integración completa con faults de `DEC-ARCH-004` y demás prioridades de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — realización física del valor de enlace de `jal` y `jalr`

**Fecha:** 2026-09-24

Para una instrucción válida `jal` o `jalr` en EX, el valor de enlace de 32 bits se calculará **en EX** mediante un `Link Adder` conceptual que suma cuatro a `ID/EX.pc[31:0]`, el PC propio de la instrucción. No se utilizará el PC global de IF ni el `pc_plus_4` del `Next-PC MUX`, que pueden corresponder a otra instrucción:

```text
ID/EX.pc[31:0]
        ↓
   Link Adder (+4)
        ↓
link_value[31:0]
        ↓
   Result MUX
        ↓
ex_result[31:0]
        ↓
     EX/MEM
```

El `Result MUX` selecciona para `jal`/`jalr` el resultado combinacional `link_value = ID/EX.pc + 4`, por lo que `ex_result = link_value` antes de que `EX/MEM` lo capture junto con la validez, la identidad y el destino de esa misma instrucción. `link_value` no es un campo físico adicional de `ID/EX`, `EX/MEM` ni `MEM/WB`. El redirect válido invalida las **nuevas** entradas jóvenes de `IF/ID` e `ID/EX`, pero no la captura de la instrucción de control válida en `EX/MEM`. Desde `EX/MEM.ex_result` el enlace está disponible para forwarding cuando el productor es válido, escribe `rd != x0` y coincide con una fuente realmente usada; una escritura a `x0` no cancela la redirección, aunque impide forwarding y escritura de registro.

En MEM, el `WB Value MUX` seleccionará `EX/MEM.ex_result` para estas instrucciones no load, conforme al punto de selección arquitectónico ya aprobado:

```text
EX/MEM.ex_result
        ↓
   WB Value MUX
        ↓
wb_value[31:0]
        ↓
     MEM/WB
        ↓
        WB
```

`MEM/WB` captura **ese mismo valor único** antes de suministrarlo a WB y al forwarding posterior, sin volver a calcular el enlace ni transportar un `link_value` registrado separado. La suma ocurre en EX y el enlace puede reenviarse desde `EX/MEM`, pero la **escritura arquitectónica del banco ocurre únicamente en WB** durante un ciclo efectivo válido conforme a `DEC-ARCH-002` y `DEC-ARCH-008`. Durante `HOLD` ninguna evaluación combinacional del sumador o de los muxes produce una captura o escritura. El tratamiento de faults y de instrucciones que dejen de ser válidas sigue sujeto a `DEC-ARCH-004`.

Este acuerdo fija la etapa del cálculo y el camino físico general del enlace; el vigésimo sexto acuerdo fija los otros orígenes y la selección semántica del `Result MUX`. El nombre, ancho y codificación funcional de su selector `result_sel[1:0]` se fijan después en el trigésimo cuarto acuerdo; las ecuaciones finales del control path y la integración RTL con faults y eventos concurrentes continúan abiertos.

#### Acuerdo parcial aprobado — realización física de la selección de `ex_result`

**Fecha:** 2026-09-24

EX producirá un único `ex_result[31:0]` mediante un `Result MUX` **combinacional** con tres entradas de datos de 32 bits:

```text
alu_result[31:0] ─────┐
immediate[31:0] ──────┼──► Result MUX ──► ex_result[31:0]
link_value[31:0] ─────┘
```

| Instrucción válida en EX | Entrada seleccionada | Significado de `ex_result` |
|---|---|---|
| R-type; I-type aritmética / shifts | `alu_result` | Resultado arquitectónico de la operación |
| Loads; stores | `alu_result` | Dirección efectiva calculada en EX |
| `lui` | `immediate` | Valor inmediato ya generado en su representación arquitectónica |
| `jal`; `jalr` | `link_value` | `instruction_PC + 4`, calculado en EX desde `ID/EX.pc` conforme al acuerdo anterior |

`EX/MEM.ex_result` captura el único valor seleccionado para la instrucción que ocupaba `ID/EX` antes del flanco de un ciclo efectivo. Para R-type, I-type aritmética/shifts, `lui` y `jal`/`jalr` válidos que escriben `rd != x0`, este campo contiene el resultado arquitectónico disponible para forwarding desde `EX/MEM`, sujeto a coincidencia con una fuente realmente usada y a la política del productor más reciente. Para un load, contiene **su dirección efectiva, no el dato cargado**: aunque escriba `rd`, no es fuente de forwarding desde `EX/MEM`; el dato arquitectónico estará disponible desde `MEM/WB.wb_value` tras su captura. Para un store, la dirección se utiliza en MEM pero no es un valor de registro reenviable. No se agrega bypass `DMEM → EX`.

Para `beq`, `bne`, `halt` y cualquier instrucción sin escritura arquitectónica de `rd`, los bits de `ex_result` carecen de efecto para WB y forwarding. También una entrada inválida, `reg_write=0` o `rd=x0` carecen de elegibilidad de escritura y reenvío, aunque el mux presente un valor combinacional residual. La selección de EX no altera los efectos de control de un salto válido ni el uso de la dirección de un store válido. Los campos `alu_result`, `immediate` y `link_value` no se registran por separado en `EX/MEM`: el inmediato procede de `ID/EX` y el enlace del `Link Adder` aprobado; en MEM el `WB Value MUX` sigue seleccionando `EX/MEM.ex_result` para escritores no load y el dato cargado para loads, con escritura arquitectónica únicamente en WB. Durante `HOLD` el mux puede evaluarse, pero no captura registros interetapa ni produce escrituras; `RUN` y `STEP` solo aplican transiciones en ciclos efectivos conforme a `DEC-ARCH-008`.

Se fijan la existencia del `Result MUX`, sus tres entradas de datos y la semántica de `ex_result` por clase, **sin fijar entonces nombre RTL, ancho ni codificación de la señal selectora** (fijados después como `result_sel[1:0]` en el trigésimo cuarto acuerdo). Tampoco se fijan ecuaciones concretas del control de `ID/EX` ni la integración RTL frente a faults y otros eventos pendiente de `DEC-ARCH-003`, sujeta a `DEC-ARCH-004` aprobada.

#### Acuerdo parcial aprobado — realización física de la generación de redirect en EX

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

EX generará combinacionalmente dos resultados conceptuales: `redirect_valid`, que indica que la instrucción de control **válida** en `ID/EX` requiere modificar el flujo secuencial, y `redirect_target[31:0]`, que contiene el destino arquitectónico correspondiente. El destino se obtiene por dos caminos de 32 bits:

```text
ID/EX.pc[31:0]                 rs1_effective[31:0]
       ↓                                ↓
Target Adder (+ immediate)     JALR Adder (+ immediate)
       ↓                                ↓
pc_relative_target[31:0]         jalr_sum[31:0]
                                        ↓
                                forzar bit 0 a cero
                                        ↓
                                jalr_target[31:0]

pc_relative_target ──┐
                     ├──► Target MUX ──► redirect_target[31:0]
jalr_target ─────────┘
```

Para `beq`, `bne` y `jal`, el `Target MUX` selecciona `pc_relative_target = ID/EX.pc + immediate`, con el inmediato B o J correspondiente a la instrucción; no usa el PC global de IF. Para `jalr` selecciona `jalr_target = (rs1_effective + immediate) & 0xFFFFFFFE`, con el inmediato I y el operando efectivo más reciente, que puede provenir de forwarding. El `Target MUX` forma el destino **dentro de EX**; el `Next-PC MUX` ya aprobado selecciona posteriormente entre ese destino y `pc_plus_4` desde el PC global para la entrada del registro PC. El `Link Adder` de `jal`/`jalr` calcula por separado el enlace `ID/EX.pc + 4` para `ex_result`: enlace, destino relativo y PC secuencial no son intercambiables.

Para branches, la ALU de EX realizará la resta de 32 bits `rs1_effective - rs2_effective` y su indicador de cero expresará `equal = ALU.zero`. La resta compara los **operandos efectivos** seleccionados tras forwarding: `beq` toma la rama cuando `ALU.zero = 1` y `bne` cuando `ALU.zero = 0`, sin depender de la interpretación signed/unsigned. La condición de redirección es conceptualmente:

```text
redirect_valid = ID/EX.valid AND (
    (beq AND equal) OR (bne AND !equal) OR jal OR jalr
)
```

`beq`, `bne`, `jal` y `jalr` denotan aquí la clase de instrucción reconocida en EX, **sin fijar subcampos, señales RTL ni codificación** de `ID/EX.control`. `jal` y `jalr` redirigen siempre que su instrucción sea válida; una entrada inválida no puede hacerlo por sus bits residuales. Un `beq` o `bne` no tomado no activa `redirect_valid` ni invalida el camino secuencial por esa causa, aunque los sumadores y muxes puedan presentar resultados combinacionales.

`redirect_valid` llega conceptualmente al `Pipeline Hazard Control`, y `redirect_target` a la entrada de target del `Next-PC MUX`.

En los casos nominales ya aprobados, un redirect válido aplicado en **un ciclo CPU efectivo** carga PC con el target e invalida las nuevas entradas jóvenes de `IF/ID` e `ID/EX`, mientras la instrucción de control en EX avanza a `EX/MEM` y las anteriores progresan.

Durante `HOLD`, ambos resultados pueden evaluarse pero no actualizan PC ni registros interetapa; `RUN` y un `STEP` aceptado aplican transiciones únicamente en los ciclos autorizados por `DEC-ARCH-008`.

`DEC-ARCH-004` prohíbe aplicar redirect a target desalineado y, si se confirma su fault en EX, retiene PC e invalida la nueva entrada de `EX/MEM` sin detener las anteriores.

La selección nominal y la prioridad local frente a trabajo joven `wrong-path` se subordinan a la antigüedad: redirect o `halt` anterior descarta un candidato joven, fault anterior descarta redirect o `halt` joven y un fault propio suprime los efectos de la instrucción; el `load-use` se aplica solo entre supervivientes.

El vigésimo octavo acuerdo concreta además que un `halt` joven descartado por ese redirect en EX nunca se confirma: la mera detección en ID no inicia drenado ni retiene PC. La integración RTL con otros eventos queda abierta.

La resta con `ALU.zero` fija ahora una **elección física** para la comparación de branches, compatible con la semántica de igualdad de `DEC-ARCH-002`, que no imponía su realización. Se fijan los caminos de cálculo del destino y la generación conceptual del redirect en EX.

El trigésimo tercer acuerdo fija después su representación **semántica** como `flow_op=BEQ/BNE/JAL/JALR`. El trigésimo cuarto acuerdo fija el código de `flow_op` y de `target_sel`.

Permanecen abiertos el empaquetado RTL y las ecuaciones de los selectores, las ecuaciones RTL finales y las coincidencias no cubiertas.

#### Acuerdo parcial aprobado — reconocimiento de `halt` y comienzo del drenado

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

La instrucción custom `halt` se detectará **inicialmente en ID** por comparación de la palabra completa en `IF/ID`, y solo como **candidata**:

```text
halt_candidate = IF/ID.valid && decode_legal
                 && (IF/ID.instruction == 32'h0000000B)
```

El trigésimo séptimo acuerdo explicita `decode_legal` en esta ecuación: como la palabra exacta de `halt` es legal, conserva la misma detección funcional. Esta detección no inicia el drenado, no retiene PC ni cambia por sí misma el estado global. Un redirect de una instrucción anterior en EX descarta el `halt` joven de ID: no se confirma, no se detiene la admisión desde el destino y no se llega a `FINISHED` por ese candidato. Los bits residuales de `IF/ID` inválido tampoco generan un candidato efectivo.

El `halt` se **confirma arquitectónicamente en EX** únicamente si alcanzó `ID/EX` como instrucción válida y continúa perteneciendo al flujo correcto en un **ciclo CPU efectivo autorizado**. Conceptualmente, `halt_confirmed = ID/EX.valid && ID/EX representa exactamente halt && instrucción aún arquitectónicamente válida`. Se define la condición semántica, no un nombre de señal obligatorio: el trigésimo tercer acuerdo lo representa semánticamente mediante `flow_op=HALT`, el trigésimo cuarto acuerdo fija luego `flow_op[2:0]` y `HALT=101`, mientras su integración RTL sigue pendiente. Durante `HOLD` puede evaluarse lógica combinacional sin confirmar el evento ni modificar el estado.

Al confirmar `halt` se fija una **frontera en orden de programa**: las instrucciones anteriores pueden completar sus efectos; el propio `halt` se consume como evento de control **sin ingresar válido a `EX/MEM`**, y las posteriores se descartan sin escribir registros o DMEM, redirigir, confirmar fault ni producir otros efectos funcionales. Para el estado previo al flanco `MEM/WB:I1, EX/MEM:I2, ID/EX:halt, IF/ID:I4, IF:I5`, en ese ciclo efectivo `I1` puede comprometer WB, `I2` puede avanzar a `MEM/WB` y se fijan `EX/MEM.next.valid=0`, `ID/EX.next.valid=0` e `IF/ID.next.valid=0` para la causante y el trabajo joven. No se vacían indiscriminadamente los registros interetapa que contienen anteriores; sus efectos siguen exactamente una vez durante el drenado.

El **PC conserva bit a bit su valor registrado actual** desde la confirmación y durante el drenado, aunque corresponda a una posición secuencial más joven presentada en IF; no se recarga el PC de `halt`, no se impone `PC+4` ni un destino especial. IF deja de admitir instrucciones nuevas. Este comportamiento requiere retención de PC, **sin añadir una entrada exclusiva para `halt` al `Next-PC MUX`** aprobado.

La condición funcional **`HALT_DRAIN`** no obliga a una FSM o codificación RTL particular. Durante ella, `IF/ID` e `ID/EX` carecen de trabajo joven válido; `EX/MEM` y `MEM/WB` solo pueden contener anteriores supervivientes. El drenado progresa exclusivamente en ciclos CPU efectivos: bajo `RUN` continúa automáticamente, bajo paso a paso requiere **un `STEP` nuevo por ciclo**, y durante `HOLD` no progresa ni repite stores o writebacks. Reset y `LOAD` conservan las prioridades globales de `DEC-ARCH-008`.

La finalización normal **`FINISHED`** requiere `halt` previamente confirmado y los cuatro registros interetapa lógicamente vacíos: `IF/ID.valid = ID/EX.valid = EX/MEM.valid = MEM/WB.valid = 0`. La candidatura en ID y la confirmación en EX no son por sí mismas `FINISHED`; si no quedan anteriores, no se exige un ciclo artificial de drenado. `FINISHED` continúa separado de `FAULT` conforme a `DEC-ARCH-004` y `DEC-SYS-001`. La integración unificada de eventos concurrentes sigue la antigüedad ya aprobada: un fault anterior descarta un `halt` joven, y un `halt` válido anterior descarta candidatos de fault posteriores.

Este acuerdo fija la **etapa candidata ID, la confirmación EX y la frontera microarquitectónica de `halt`**. El trigésimo cuarto acuerdo fija luego `flow_op[2:0]=101` para `HALT` y el trigésimo sexto `terminal_kind[1:0]`/`drain_auto` para la frontera confirmada y su drenado. Siguen pendientes la integración RTL, las ecuaciones de arbitraje físico, enables e invalidaciones, y la codificación del control global de ejecución; no se fija una señal `halt_confirmed` ni una FSM obligatoria.

#### Acuerdo parcial aprobado — representación y transporte físico de candidatos de fault

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

Se conservan **solo los cuatro registros interetapa** `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`. Los candidatos de Instruction Fetch se detectan en IF, las instrucciones ilegales en ID y los accesos load/store o targets desalineados en EX conforme a `DEC-ARCH-004`. La única ampliación registrada de pipeline se hace en **`IF/ID`**, revisando explícitamente su decimocuarto acuerdo de tres campos a cinco:

```text
IF/ID
├── valid
├── pc[31:0]
├── instruction[31:0]
├── fetch_fault_valid
└── fetch_fault_cause[2:0]
```

`valid` conserva su significado: identifica una **instrucción obtenida y arquitectónicamente activa**, no un candidato de fault. En un fetch normal se capturan `valid=1`, `pc=PC del fetch`, la palabra obtenida y `fetch_fault_valid=0`. En un fetch con causa candidata seleccionada por la prioridad ya aprobada se capturan **`valid=0`, `pc=PC causante`, `fetch_fault_valid=1` y `fetch_fault_cause=causa detectada`**; los bits de `instruction` carecen de significado arquitectónico. Una entrada `valid=0, fetch_fault_valid=0` es inactiva y no puede confirmar fault por residuos. El trigésimo quinto acuerdo fija después el ancho/codificación de `fetch_fault_cause[2:0]`; no se agrega campo de PC distinto de `IF/ID.pc`.

En la **ruta normal**, el candidato de IF capturado en `IF/ID` se resuelve conceptualmente en **ID** durante un ciclo efectivo: si un redirect, fault o `halt` más antiguo ha invalidado el fetch, el flag se descarta sin confirmar; si `fetch_fault_valid=1` y el fetch sigue en el camino correcto, se confirma el fault según la antigüedad de `DEC-ARCH-004`. No se transporta la candidatura a `ID/EX` ni se interpreta `instruction` como instrucción ilegal; `fault_pc=IF/ID.pc` y `fault_cause` procede del candidato seleccionado. Un flush o invalidación de trabajo joven **debe poner también `fetch_fault_valid=0`**, aun si `IF/ID.valid` ya era cero; durante `HOLD` se retienen los cinco campos y no se confirma nada por una evaluación combinacional. Reset y preparación de nueva sesión invalidan las candidaturas previas conforme a `DEC-ARCH-008`.

**Excepción aprobada para `load-use` entre anteriores supervivientes:** si IF detecta un fetch fault mientras `ID/EX` contiene el load anterior e `IF/ID` debe **retener válida** a su consumidora anterior, no se sobrescribe el registro interetapa con el candidato. Si ese fetch permanece en el camino correcto y no existe una frontera anterior prevaleciente, el fault se **confirma directamente en IF** en ese ciclo CPU efectivo, conforme al décimo acuerdo de `DEC-ARCH-004`: `IF/ID` conserva íntegramente a la consumidora, `ID/EX` recibe bubble, el load y las demás anteriores avanzan, PC se retiene y no se admite el fetch causante. `fault_pc` se toma del **PC del fetch en IF**, y `fault_cause` de la causa detectada allí; el candidato no se captura en `IF/ID` ni se requiere un registro adicional. Esta excepción no convierte toda detección IF en confirmación inmediata; un fetch `wrong-path` descartado nunca confirma error.

La instrucción ilegal solo puede detectarse sobre una **entrada normal `IF/ID.valid=1`** por decodificación de la palabra completa en ID. Si prevalece una instrucción anterior se descarta; si se confirma, **no entra válida a `ID/EX`**, y `fault_pc=IF/ID.pc`, sin campo de candidato adicional. Los faults de load, store o target se detectan y resuelven directamente en EX; si se confirman, la causante **no entra válida a `EX/MEM`**, y `fault_pc=ID/EX.pc`. No se añaden campos de fault a `ID/EX`, `EX/MEM` ni `MEM/WB`. Se conserva la prioridad `misalignment > access fault` dentro de un mismo acceso y la prioridad por **antigüedad** entre instrucciones, sin confundir una coincidencia física con confirmación arquitectónica.

En **cualquiera de las rutas de confirmación**, se capturan `fault_cause` y `fault_pc` como **estado global persistente fuera de los cuatro registros interetapa**, y la condición de fault se activa; causa y PC permanecen estables durante `FAULT_DRAIN` y `FAULT` conforme a `DEC-ARCH-004`. Ningún candidato descartado, incluido el de `IF/ID` con `valid=0`, modifica ese estado. La ruta excepcional de IF utiliza el PC de IF y la ruta normal transportada el PC de `IF/ID`; para ilegal en ID se usa `IF/ID.pc` y para EX se usa `ID/EX.pc`, nunca la dirección de datos ni el target problemático.

Este acuerdo fija la **representación mínima y transporte de candidatos de fault**, con una revisión explícita de los acuerdos decimocuarto y vigésimo relativos a `IF/ID`. El trigésimo acuerdo fija después el orden semántico de resolución EX→ID→IF excepcional y los stalls de supervivientes; el trigésimo quinto fija la codificación común de causa de tres bits. El cuadragésimo primer acuerdo fija después el arbitraje combinacional de las fronteras cubiertas; las coincidencias no cubiertas, las ecuaciones finales de enable/flush y la representación externa Debug siguen pendientes, sin cambiar el contrato arquitectónico de `DEC-ARCH-004`.

#### Acuerdo parcial aprobado — prioridad unificada de eventos dentro de un ciclo efectivo

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

El arbitraje conjunto de fault, `halt`, redirect y stall se regirá por **antigüedad de programa**, no por una prioridad universal de tipos como `fault > halt > redirect > stall`. Entre eventos de **instrucciones distintas**, prevalece la más antigua que siga válida y en el camino correcto: en este pipeline in-order, **EX > ID > IF**. Dentro de **una misma instrucción**, un fault propio confirmado suprime sus efectos normales, incluido redirect y enlace de un `jal`/`jalr` con target desalineado. Solo después de determinar la frontera y las instrucciones supervivientes se aplican los stalls necesarios entre estas últimas, conforme a `DEC-ARCH-004`.

En cada ciclo CPU efectivo autorizado, el orden conceptual para **trabajo todavía no cubierto por una frontera activa** es:

```text
1. EX: si la instrucción válida confirma fault propio, frontera FAULT
       (no redirect ni enlace; causante no entra válida a EX/MEM).
       En otro caso, si confirma halt, frontera HALT
       (halt se consume en EX; no entra válido a EX/MEM).
       En otro caso, si produce redirect aplicable, frontera REDIRECT
       (PC toma redirect_target; trabajo secuencial joven se descarta).

2. Solo si EX no establece frontera, ID: confirmar illegal-instruction
   sobre IF/ID.valid=1, o fetch_fault_valid=1 sobre IF/ID.valid=0,
   siempre que el candidato siga en el camino correcto. Si confirma,
   frontera FAULT; la causante no avanza como instrucción válida.

3. Solo si EX e ID no establecen frontera, IF: conservar la excepción
   aprobada de fetch fault cuando un load-use entre anteriores obliga
   a retener al consumidor válido en IF/ID. Si el fetch es elegible,
   confirmar FAULT en IF sin capturar al candidato sobre el consumidor.
   En los demás casos IF solo detecta y, si corresponde, transporta
   al candidato hacia IF/ID para resolverlo en ID.

4. Una vez fijada la frontera y descartado el trabajo más joven,
   aplicar únicamente el load-use stall que aún necesiten
   productor y consumidor anteriores supervivientes; si no hay
   frontera ni stall aplicable, efectuar el avance nominal.
```

En EX, el fault propio precede al efecto normal **de esa misma instrucción**: `jal`/`jalr` con destino desalineado no redirige ni escribe enlace; el propio fault tampoco avanza válido a `EX/MEM`. Un `halt` EX confirmado sin fault propio se consume allí, descarta ID/IF jóvenes y deja drenar a sus anteriores hasta `FINISHED`. Un redirect EX aplicable, en cambio, **sí deja avanzar válida a la instrucción de control a `EX/MEM`** y descarta ID/IF secuenciales `wrong-path` y sus candidatos de fault, aunque `IF/ID.valid=0` y `fetch_fault_valid=1`. Solo sin frontera EX puede confirmarse un fault de ID: una instrucción ilegal válida o el candidato de fetch conservado en `IF/ID`; sus anteriores en `ID/EX`, `EX/MEM` y `MEM/WB` continúan y el fetch joven de IF se descarta. Por ejemplo, con I1 en `MEM/WB`, I2 en `EX/MEM`, I3 en `ID/EX`, I4 causante en `IF/ID` e I5 en IF, I1–I3 sobreviven y **I4 e I5 no producen efectos**.

La **excepción de IF** se evalúa **después de descartar fronteras EX e ID y antes de aplicar el stall**: se comprueba conceptualmente que un load y su consumidora anteriores aún precisan `load-use`, mientras IF presenta un fetch fault elegible. Se confirma en IF sin sobrescribir `IF/ID`, se retiene allí al consumidor con sus cinco campos, `ID/EX` recibe bubble y el load avanza; `fault_pc` proviene del PC de IF. Un redirect o fault EX anterior, o un fault ID anterior, descarta en cambio el candidato IF.

La ruta **ordinaria** continúa transportando el fetch candidato por `IF/ID` para resolverlo en ID, sin confirmación inmediata general en IF.

Si una frontera descarta la consumidora, su dependencia ya no justifica el stall; si load y consumidora sobreviven a la frontera, su stall se conserva.

Sin frontera, se aplica el `load-use` nominal o el avance normal; un redirect EX prevalece localmente sobre un stall atribuible solo a trabajo joven descartado, conforme al acuerdo ya aprobado.

Una frontera de fault o `halt` **previamente confirmada** impide la admisión de trabajo nuevo y la confirmación de eventos de trabajo joven descartado; las instrucciones anteriores supervivientes continúan drenando con los hazards que precisen. No se introducen ciclos arquitectónicos ocultos ni una jerarquía fija por tipo de evento: `reset` y `LOAD` aceptado/preparación dominan los ciclos CPU, `RUN`/`STEP` autorizan las transiciones y `HOLD` no confirma nuevos eventos aunque la lógica combinacional se evalúe, conforme a `DEC-ARCH-008`. El nombre de la condición de drenado no impone una FSM RTL.

Este trigésimo acuerdo fija la **prioridad semántica unificada** sin modificar los cuatro registros interetapa ni los mecanismos nominales de bubble, flush, forwarding y retención. Los códigos funcionales del control de `ID/EX` se fijan en el trigésimo cuarto acuerdo. El trigésimo sexto acuerdo introdujo la clase terminal y el modo de drenado, sustituidos después por la FSM del cuadragésimo cuarto acuerdo. El cuadragésimo primer acuerdo fija después las ecuaciones RTL de arbitraje combinacional y el cuadragésimo segundo los enables/valores `next` de PC y registros interetapa; siguen abiertas las coincidencias no cubiertas, preservando `DEC-ARCH-004` y los acuerdos vigésimo octavo y vigésimo noveno de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — control completo del PC y los cuatro registros de pipeline

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

Se fijan las **transiciones semánticas en cada ciclo CPU efectivo** de PC, `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB` para las fronteras y hazards aprobados. Cada captura y efecto arquitectónico se decide con las entradas **previas al flanco**; «capturar EX» alimenta la entrada nueva de `EX/MEM` desde `ID/EX` previo, y «capturar MEM» alimenta `MEM/WB` desde `EX/MEM` previo. La invalidación de una entrada nueva nunca borra retrospectivamente una instrucción anterior que ya ocupaba otra etapa. El trigésimo acuerdo selecciona la frontera por antigüedad EX→ID→IF excepcional antes de aplicar un stall necesario entre supervivientes; esta tabla materializa las acciones resultantes, sin prioridad universal por tipo de evento.

| Acción seleccionada | PC | `IF/ID.next` | `ID/EX.next` | `EX/MEM.next` | `MEM/WB.next` |
|---|---|---|---|---|---|
| Avance normal | Capturar `PC + 4` | Capturar IF | Capturar ID | Capturar EX | Capturar MEM |
| `load-use` entre supervivientes | Retener | Retener íntegramente al consumidor | Inválido / bubble | Capturar load anterior de EX | Capturar MEM |
| Redirect válido en EX | Capturar `redirect_target` | Inválido | Inválido | Capturar instrucción de control válida de EX | Capturar MEM |
| `halt` confirmado en EX | Retener | Inválido | Inválido | Inválido | Capturar MEM |
| Fault propio confirmado en EX | Retener | Inválido | Inválido | Inválido | Capturar MEM |
| Fault confirmado en ID | Retener | Inválido | Inválido | Capturar instrucción anterior de EX | Capturar MEM |
| **Fault excepcional confirmado en IF** con `load-use` entre anteriores | Retener | **Retener los cinco campos del consumidor válido** | Inválido / bubble | Capturar load anterior de EX | Capturar MEM |
| Drenado activo de `halt` o fault | Retener | Retener al anterior si hay stall; invalidar al dejarlo avanzar o si ya no lo contiene | Capturar anterior de ID si puede avanzar; bubble/inválido si hay stall o no existe | Capturar anterior de EX, o inválido si no existe | Capturar MEM |

En avance normal, «capturar IF» incluye un fetch válido (`valid=1, fetch_fault_valid=0`) o, si IF detectó un candidato de fault **no confirmado**, su captura en `IF/ID` con `valid=0, fetch_fault_valid=1`, PC y causa del fetch para resolverlo posteriormente en ID. Un candidato no confirmado **no** selecciona una fila de fault. El `load-use` nominal retiene PC e `IF/ID` y crea solo la bubble de `ID/EX`: el load y las anteriores siguen avanzando. Un redirect EX válido invalida trabajo secuencial joven pero **preserva** la instrucción de control en `EX/MEM`; por el contrario, el propio `halt` o fault de EX **no** entra válido a `EX/MEM`. Si se confirma fault en ID, su causante no entra válida a `ID/EX`, pero la instrucción anterior en EX sí entra a `EX/MEM`.

En la **excepción de IF**, el fetch causante de fault no ingresa al pipeline; `fault_pc` procede del PC del fetch en IF. El consumidor en `IF/ID` es **anterior** a esa frontera y debe permanecer con sus cinco campos durante el ciclo de confirmación, mientras `ID/EX` recibe bubble y el load de EX avanza a `EX/MEM`.

En los ciclos efectivos siguientes de `FAULT_DRAIN`, sin nuevos fetches admitidos, el consumidor todavía válido en `IF/ID` puede avanzar a `ID/EX`, luego `EX/MEM` y `MEM/WB`, con forwarding y stalls necesarios entre anteriores; `IF/ID` se invalida **al dejarlo avanzar**, no antes. El PC permanece retenido durante este progreso.

La fila de drenado no es un flush incondicional de todas las etapas: si todavía hay trabajo anterior válido en `IF/ID` o `ID/EX`, se lo conserva o transfiere según corresponda; si no lo hay, se inyectan entradas inválidas.

En `HALT_DRAIN` iniciado por `halt` EX, y en faults EX o ID una vez aplicada su fila de confirmación, ya no quedan anteriores en `IF/ID`; para esos casos la fila de drenado se simplifica al desplazamiento de anteriores en las etapas restantes y la inyección de invalidez.

**Invalidar `IF/ID`** por descarte o por agotamiento de trabajo superviviente significa como mínimo `IF/ID.next.valid=0` **y** `IF/ID.next.fetch_fault_valid=0`: incluso un candidato joven con `valid=0` debe quedar desactivado. `pc`, `instruction` y `fetch_fault_cause` pueden conservar bits residuales sin efecto. La retención del consumidor superviviente en la excepción IF **no** es una invalidación. Los demás registros interetapa nuevos inválidos pueden asimismo conservar sus bits residuales, sin reconocer efectos de entradas inválidas.

Al confirmarse `halt` o fault, un writeback de la entrada **previa** de `MEM/WB` y un store anterior desde la entrada **previa** de `EX/MEM` pueden completarse normalmente, una sola vez, si cumplen validez y ciclo efectivo; `MEM/WB.next` sigue capturando MEM previa. Se descarta la causante cuando corresponde y el trabajo posterior, nunca las anteriores. El drenado progresa en `RUN` o mediante un `STEP` nuevo por ciclo, y llega a `FINISHED` o `FAULT` cuando completaron las anteriores y **los cuatro `valid` quedaron en cero**, sin exigir un ciclo de drenado vacío adicional. Si ya estaban vacíos tras la confirmación, se alcanza directamente el estado final correspondiente. Durante `HOLD` los cinco registros, incluidos PC, retienen sus valores y no se confirma ningún evento por clocks físicos; `reset` global y `LOAD` aceptado/preparación conservan su precedencia sobre ciclos CPU conforme a `DEC-ARCH-008`.

Este trigésimo primer acuerdo consolida las transiciones nominales y las fronteras precisas de `DEC-ARCH-004`, incluida su excepción de IF, sin añadir registros interetapa, señales, codificaciones de estados, enables ni ecuaciones RTL obligatorias. La codificación `flow_op[2:0]=101` se fija en el trigésimo cuarto acuerdo; la implementación física opcional del conjunto de control continúa pendiente y el cuadragésimo primer acuerdo de `DEC-ARCH-003` fija después el arbitraje combinacional de acciones y el cuadragésimo segundo fija los enables/invalidaciones y capturas de PC y registros interetapa para ellas.

#### Acuerdo parcial aprobado — ecuaciones funcionales definitivas de hazards de datos

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

Se fijan las ecuaciones conceptuales del **`Load-Use Hazard Detector`** y de la **`Forwarding Unit`** existentes. La primera detecta una dependencia cuyo dato todavía no está disponible; la segunda elige por fuente la versión pendiente más reciente ya disponible. La ecuación del detector es:

```text
load_use_stall =
    ID/EX.valid
    && ID/EX.is_load
    && (ID/EX.rd != x0)
    && IF/ID.valid
    && (
         (IF/ID.uses_rs1 && (IF/ID.rs1 == ID/EX.rd))
         ||
         (IF/ID.uses_rs2 && (IF/ID.rs2 == ID/EX.rd))
       )
```

`IF/ID.rs1`, `IF/ID.rs2` y los indicadores de uso se **derivan combinacionalmente** de `IF/ID.instruction` según la clasificación 3A: no se registran campos nuevos. `ID/EX.is_load` es información derivable del control ya transportado por la instrucción en `ID/EX`; su codificación se fija después como `mem_op[3:0]` en el trigésimo cuarto acuerdo, sin subcampo `is_load` adicional. La igualdad sobre una fuente no usada, `rd=x0` o cualquier entrada inválida no habilita el stall. La detección combinacional no congela por sí sola el pipeline: tras seleccionar la frontera por antigüedad EX→ID→IF excepcional, el stall se **aplica** únicamente si load y consumidora sobreviven, conforme a los acuerdos trigésimo y trigésimo primero.

Para cada fuente **independiente** `rsN`, `N ∈ {1,2}`, se fijan las coincidencias de productor:

```text
exmem_match_rsN =
    ID/EX.valid && ID/EX.uses_rsN
    && EX/MEM.valid && EX/MEM.reg_write
    && (EX/MEM.rd != x0)
    && (EX/MEM.rd == ID/EX.rsN)

memwb_match_rsN =
    ID/EX.valid && ID/EX.uses_rsN
    && MEM/WB.valid && MEM/WB.reg_write
    && (MEM/WB.rd != x0)
    && (MEM/WB.rd == ID/EX.rsN)
```

`ID/EX.uses_rs1` y `ID/EX.uses_rs2` se derivan de la instrucción/control ya registrados en `ID/EX`, **sin agregar campos físicos**. La coincidencia de `EX/MEM` significa que se halló un productor más reciente de esa fuente que cualquier productor coincidente de `MEM/WB`, pero no implica disponibilidad del dato. `exmem_result_available` denota que `EX/MEM.ex_result` ya contiene el valor arquitectónico que se escribiría en `rd`: ocurre para resultados R-type, I-type aritmética/shifts, `lui` y enlace de `jal`/`jalr`. En un load, `EX/MEM.ex_result` contiene **la dirección efectiva**, nunca el valor cargado; un load coincidente no tiene resultado reenviable desde `EX/MEM`. La disponibilidad se deriva del control existente en `EX/MEM`, sin campo `result_available` adicional; el trigésimo octavo acuerdo fija después `exmem_result_available = !is_load(EX/MEM.mem_op)`. `MEM/WB` entrega siempre su único `wb_value` arquitectónico ya seleccionado en MEM, incluido el de loads, sin reconstruir el origen.

Las habilitaciones de forwarding son, por cada fuente:

```text
forward_exmem_rsN = exmem_match_rsN && exmem_result_available
forward_memwb_rsN = !exmem_match_rsN && memwb_match_rsN
```

La negación de la segunda expresión se aplica a **`exmem_match_rsN`**, no a `forward_exmem_rsN`. Por ello, si `EX/MEM` es el productor coincidente más reciente pero todavía no dispone del dato, `MEM/WB` no puede sustituirlo por la versión anterior. Cada `Forward MUX` de tres entradas realiza conceptualmente, por separado para `rs1` y `rs2`:

```text
si forward_exmem_rsN:  rsN_effective ← EX/MEM.ex_result
si no, si forward_memwb_rsN:
                        rsN_effective ← MEM/WB.wb_value
si no:                  rsN_effective ← ID/EX.rsN_value
```

La última rama representa el **valor base utilizable solo cuando no existe un productor coincidente más reciente pendiente**. Si `exmem_match_rsN=1` y `exmem_result_available=0`, ambas habilitaciones de forwarding son cero y el mux físico podría mostrar la rama base; **ese valor combinacional es irrelevante y no podrá ser consumido por una instrucción válida en EX**. El detector `load-use` habrá retenido previamente a la consumidora de la dependencia inmediata hasta disponer del dato; el control de supervivencia conserva los stalls necesarios durante el drenado. No se selecciona la dirección efectiva del load, `MEM/WB` obsoleto ni el valor base obsoleto como operando arquitectónico. No se agrega cuarta entrada de mux, bypass `DMEM → EX` ni nuevo tipo de forwarding o stall.

El bypass interno **WB→ID** de `DEC-ARCH-007` actúa antes: `Register File → bypass WB→ID → rs1_value/rs2_value → ID/EX.rsN_value → Forward MUX → rsN_effective`. La `Forwarding Unit` no necesita conocer de dónde provenía el valor base posbypass; un productor pendiente más reciente en `EX/MEM` o `MEM/WB` prevalece por versión cuando su dato esté disponible. Productores inválidos, sin escritura o con `rd=x0`, y consumidor inválido o fuente no usada no generan forwarding funcional. Las salidas combinacionales pueden evaluarse en `HOLD`, pero no originan por sí mismas avance ni efectos arquitectónicos.

Este trigésimo segundo acuerdo cierra **las ecuaciones funcionales del detector y de la `Forwarding Unit`** sin cambiar los cuatro registros interetapa ni agregar bloques. El trigésimo cuarto acuerdo fija después los nombres, anchos y códigos funcionales de las categorías de control y selectores principales; el trigésimo octavo fija `is_load` y la disponibilidad de `EX/MEM`. Permanecen pendientes las ecuaciones RTL de enables, flush y arbitraje concurrente no cubierto.

#### Acuerdo parcial aprobado — composición semántica del control transportado por el pipeline

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

Se revisa explícitamente el significado del elemento **`ID/EX.control`** del decimotercer acuerdo: es un **placeholder para la información de control asociada a la instrucción**, no la obligación de registrar un único número, vector o bus empaquetado. La implementación puede representarla mediante señales separadas, una estructura, un bundle o una forma equivalente que conserve las siguientes **seis categorías semánticas generadas en ID** para la instrucción decodificada:

| Categoría conceptual | Significado y alternativas semánticas |
|---|---|
| `alu_op` | Operación de ALU: `ADD`, `SUB`, `SLL`, `SRL`, `SRA`, `AND`, `OR`, `XOR`, `SLT`, `SLTU`. Loads/stores emplean `ADD` para dirección efectiva; `beq`/`bne` emplean `SUB` y leen `ALU.zero` para igualdad. |
| `alu_src` | Segundo operando de ALU: `rs2_effective` o `immediate`. Selecciona registro o inmediato para operaciones ALU y cálculo de dirección cuando corresponda. |
| `result_sel` | Valor de `EX/MEM.ex_result` a través del **`Result MUX` 3:1** aprobado: `ALU` → `alu_result`, `IMMEDIATE` → `immediate`, `LINK` → `link_value`. Loads/stores llevan la dirección ALU; `lui`, el inmediato; `jal`/`jalr`, `ID/EX.pc + 4`. |
| `flow_op` | Clase de flujo: `NONE`, `BEQ`, `BNE`, `JAL`, `JALR`, `HALT`. |
| `mem_op` | Acceso: `NONE`, `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW`. Distingue load/store, ancho y extensión con/sin signo del load; permite derivar `is_load` sin otro campo. |
| `reg_write` | Intención de escribir `rd`: verdadera para R-type, I-type aritmética/shifts, loads, `lui`, `jal` y `jalr`; falsa para stores, `beq`/`bne` y `halt`. Una intención no permite escribir si `valid=0`, hay fault propio o no se autoriza un ciclo efectivo. |

Los comportamientos de `flow_op` son:

| Operación | Condición o función |
|---|---|
| `BEQ` | Redirige si `ALU.zero=1` |
| `BNE` | Redirige si `ALU.zero=0` |
| `JAL` y `JALR` | Redirigen incondicionalmente con los destinos físicos ya aprobados |
| `HALT` | Permite identificar en EX al `halt` válido que allí se confirma |

En EX, `flow_op=BEQ/BNE` utiliza la resta de `rs1_effective` y `rs2_effective` y `ALU.zero`, mientras `flow_op=JAL` utiliza el destino relativo a **`ID/EX.pc`** y `flow_op=JALR` el destino `(rs1_effective + immediate) & 0xFFFFFFFE` formado por los sumadores y el `Target MUX` ya aprobados. `flow_op=HALT` conserva la distinción entre candidato en ID y **confirmación de la instrucción válida en EX** durante un ciclo efectivo del camino correcto; no implica confirmación anticipada ni señal física `is_halt` separada. Un fault de destino de la propia instrucción de control suprime sus efectos normales conforme a `DEC-ARCH-004` y al trigésimo acuerdo.

La información se **reduce progresivamente** según la etapa consumidora:

```text
ID genera → ID/EX conserva información semántica de:
    alu_op, alu_src, result_sel, flow_op, mem_op, reg_write

EX consume:
    alu_op, alu_src, result_sel, flow_op

EX/MEM conserva entre sus campos de control:
    mem_op, reg_write

MEM consume:
    mem_op

MEM/WB conserva entre sus campos de control:
    reg_write

WB consume:
    reg_write
```

Esto preserva los campos ya aprobados **`EX/MEM.mem_op`**, **`EX/MEM.reg_write`** y **`MEM/WB.reg_write`**, así como los resultados y datos registrados de cada etapa; no extiende hacia `EX/MEM` señales de ALU, selección de resultado ni clase de flujo que ya fueron consumidas en EX. `mem_op` permite derivar el tipo de acceso, la disponibilidad del resultado de `EX/MEM` y la selección del valor arquitectónico hacia `MEM/WB` conforme a las políticas anteriores. `uses_rs1`/`uses_rs2` se derivan de la instrucción/control disponible según 3A y el acuerdo trigésimo segundo. Tampoco se exigen campos físicos independientes `is_load`, `mem_to_reg`, `is_halt` ni `target_sel`: pueden derivarse de `instruction`, `flow_op`, `mem_op` y de los demás controles existentes. No se altera el número de registros interetapa, el contenido de `IF/ID` ni la distinción bypass WB→ID / forwarding en EX.

La **validez** determina si una entrada contiene una instrucción activa: con `ID/EX.valid=0`, las categorías de control residuales no producen efectos arquitectónicos de ALU, redirect, `halt`, accesos a memoria, writeback, hazard ni fault por bits residuales; la lógica combinacional puede evaluarse sin comprometer resultados. Bubble y flush no obligan a codificar todos los controles como NOP; las etapas posteriores también requieren su propia validez y las condiciones normales para producir efectos. Reset, `LOAD`, `RUN`/`STEP` y `HOLD` mantienen su jerarquía global de `DEC-ARCH-008`.

Este trigésimo tercer acuerdo fija **qué información semántica** se genera, consume y transporta, sin imponer entonces nombres RTL definitivos, anchos ni códigos binarios, que el trigésimo cuarto acuerdo fija después para las señales principales. El empaquetado opcional de `ID/EX.control` permanece abierto en `DEC-ARCH-003`; los acuerdos cuadragésimo primero y segundo fijan después el arbitraje y los enables/capturas de PC y registros interetapa para sus nueve acciones.

#### Acuerdo parcial aprobado — nombres, anchos y codificación de controles y selectores

**Fecha:** 2026-09-25

Se fijan los **nombres, anchos y códigos funcionales** de los controles principales de `DEC-ARCH-003`, concretando el trigésimo tercer acuerdo sin obligar a materializar un único bus `ID/EX.control`. Las seis categorías generadas en ID acompañan a la instrucción hasta su etapa consumidora; podrán implementarse como señales separadas o estructura equivalente. Los códigos `RESERVED` no serán emitidos por el decoder para instrucciones válidas del subconjunto; los bits residuales de una entrada inválida carecen de efectos arquitectónicos, sin requerir NOP física.

**Operaciones de ALU.** La interfaz existente utiliza `opcode` de **6 bits**: `alu_op[5:0]`; en el CPU se aplicará a datos de **32 bits**. Se conservan los códigos existentes de `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SRL` y `SRA`, y se incorporan los faltantes `SLL`, `SLT` y SLTU:

| `alu_op[5:0]` | Operación | `alu_op[5:0]` | Operación |
|---|---|---|---|
| `000000` | `SLL` | `100000` | `ADD` |
| `000010` | `SRL` | `100010` | `SUB` |
| `000011` | `SRA` | `100100` | `AND` |
| `101010` | `SLT` | `100101` | `OR` |
| `101011` | SLTU | `100110` | `XOR` |

La ALU de TP1/TP2 ya implementa los códigos conservados y `100111` para NOR, pero **todavía no implementa `SLL`, `SLT` ni SLTU**. NOR puede seguir existiendo internamente; el decoder del CPU no generará `100111` para ninguna instrucción válida del subconjunto. El presente acuerdo fija el contrato del CPU, no afirma que la ALU extendida ya esté implementada.

| Señal de control desde ID a `ID/EX` | Ancho | Codificación funcional |
|---|---|---|
| `alu_src` | 1 bit | `0` = RS2 (`rs2_effective`); `1` = IMMEDIATE (`immediate`) |
| `result_sel[1:0]` | 2 bits | `00` = ALU (`alu_result`); `01` = IMMEDIATE (`immediate`); `10` = LINK (`link_value`); `11` = `RESERVED` |
| `flow_op[2:0]` | 3 bits | `000` = `NONE`; `001` = `BEQ`; `010` = `BNE`; `011` = `JAL`; `100` = `JALR`; `101` = `HALT`; `110`/`111` = `RESERVED` |
| `mem_op[3:0]` | 4 bits | `0000` = `NONE`; `0001` = `LB`; `0010` = `LH`; `0011` = `LW`; `0100` = `LBU`; `0101` = `LHU`; `0110` = `SB`; `0111` = `SH`; `1000` = `SW`; `1001`–`1111` = `RESERVED` |
| `reg_write` | 1 bit | `0` = NO WRITE; `1` = WRITE, siempre subordinado a validez, ciclo efectivo y ausencia de fault propio |

`flow_op` permite derivar localmente `is_beq`, `is_bne`, `is_jal`, `is_jalr` e `is_halt`; `mem_op` permite derivar `is_load`, `is_store`, `access_size` y `load_unsigned`. Se conserva la **misma codificación `mem_op[3:0]`** desde `ID/EX` a `EX/MEM.mem_op` para MEM, y `reg_write` continúa desde `ID/EX` por `EX/MEM.reg_write` y `MEM/WB.reg_write` hasta WB. EX consume `alu_op`, `alu_src`, `result_sel` y `flow_op`; solo `mem_op` y `reg_write` siguen como controles a `EX/MEM`, y solo `reg_write` a `MEM/WB`. El trigésimo octavo acuerdo fija después las ecuaciones de derivación de `is_load`, `is_store`, `mem_access`, `access_size`, `load_unsigned` y los predicados de flujo, sin registrarlos como campos físicos adicionales.

Los **selectores locales** quedan fijados así, sin transportarlos a través de todos los registros interetapa:

| Señal local | Ancho | Codificación funcional / derivación |
|---|---|---|
| `forward_a_sel[1:0]`, `forward_b_sel[1:0]` | 2 bits cada una | `00` = `ID_EX` (`ID/EX.rsN_value`); `01` = `EX_MEM` (`EX/MEM.ex_result`); `10` = `MEM_WB` (`MEM/WB.wb_value`); `11` = `RESERVED`. Se deciden por fuente independientemente. |
| `target_sel` | 1 bit | `0` = `PC_RELATIVE`; `1` = `JALR`; derivable en EX como `flow_op == JALR`, sin campo transportado desde ID. |
| `wb_value_sel` | 1 bit | `0` = `EX_RESULT`; `1` = `LOAD_VALUE`; derivable en MEM como `is_load(EX/MEM.mem_op)`, sin campo transportado. |
| `next_pc_sel` | 1 bit | `0` = `PC_PLUS_4`; `1` = `REDIRECT_TARGET`. Selecciona solo las dos entradas ya aprobadas del `Next-PC MUX`. |
| `pc_write_enable` | 1 bit | `0` = retener PC; `1` = capturar la salida del `Next-PC MUX`. |

Las ecuaciones de forwarding del trigésimo segundo acuerdo siguen gobernando la elegibilidad de las entradas: con `EX/MEM` coincidente pero load aún no disponible, cualquier código o salida combinacional residual del mux **no se consume** como operando válido, aun si físicamente se observa `00`. `target_sel=0` o `wb_value_sel=0` en operaciones que no consumen esos caminos tampoco crea efectos sin validez. Las categorías `RESERVED` pertenecen a estos selectores de tres entradas y a los controles enumerados; no se impone codificación NOP específica al invalidar un registro interetapa.

Durante un **ciclo CPU efectivo**, las acciones nominales sobre PC usan:

```text
avance normal:              pc_write_enable=1, next_pc_sel=0 (PC_PLUS_4)
redirect EX aplicable:      pc_write_enable=1, next_pc_sel=1 (REDIRECT_TARGET)
load-use / halt / fault / drenado:
                            pc_write_enable=0, next_pc_sel=irrelevante
```

La retención no añade una tercera entrada al `Next-PC MUX`; ante `HOLD` no se aplica ninguna actualización aunque cambien sus señales combinacionales. `RESET` y `LOAD` aceptado/preparación mantienen la precedencia global de `DEC-ARCH-008`. El arbitraje por antigüedad y la invalidez de trabajo joven siguen rigiendo **antes de aplicar** los selectores, conforme a los acuerdos trigésimo y trigésimo primero.

Este trigésimo cuarto acuerdo cierra los **nombres, anchos y códigos funcionales principales** de control y selección sin introducir campos de pipeline ni exigir un vector `control` único. El trigésimo quinto acuerdo fija posteriormente las causas de fault de tres bits. Permanecen pendientes la integración RTL, ecuaciones de enables/invalidaciones/arbitraje no cubierto, el empaquetado opcional y otras codificaciones, como la del estado global.

#### Acuerdo parcial aprobado — codificación de causas de fault

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se fija una codificación **común de tres bits** para el candidato de fetch registrado en `IF/ID.fetch_fault_cause[2:0]` y para la causa de fault confirmado `fault_cause[2:0]`, mantenida como **estado global fuera de los cuatro registros interetapa**. Los siete códigos de causa corresponden exactamente a las categorías de `DEC-ARCH-004`:

| Código | Causa arquitectónica | Detección posible |
|---|---|---|
| `000` | `INSTRUCTION_ADDRESS_MISALIGNED` (`instruction-address-misaligned`) | Fetch IF o target de control en EX |
| `001` | `INSTRUCTION_ACCESS_FAULT` (`instruction-access-fault`) | Fetch IF |
| `010` | `ILLEGAL_INSTRUCTION` (`illegal-instruction`) | Decode ID sobre instrucción obtenida válida |
| `011` | **`RESERVED`** | Ninguna causa válida |
| `100` | `LOAD_ADDRESS_MISALIGNED` (`load-address-misaligned`) | Load EX |
| `101` | `LOAD_ACCESS_FAULT` (`load-access-fault`) | Load EX |
| `110` | `STORE_ADDRESS_MISALIGNED` (`store-address-misaligned`) | Store EX |
| `111` | `STORE_ACCESS_FAULT` (`store-access-fault`) | Store EX |

**No existe un código `NONE`.** Ausencia de candidato de fetch se expresa mediante `IF/ID.fetch_fault_valid=0`; ausencia de fault global confirmado mediante el estado/flag global correspondiente. Cuando ese indicador está inactivo, los bits de causa pueden ser residuales sin significado arquitectónico, incluso si físicamente coinciden con un código de causa o con `011`. Para un **candidato válido** generado en IF, `fetch_fault_cause` solo puede tomar `000` o `001`; IF nunca genera `010`–`111` como candidato válido. El ancho común permite que la ruta ordinaria IF→`IF/ID`→ID transfiera directamente `IF/ID.fetch_fault_cause[2:0]` a `fault_cause[2:0]` **solo al confirmar** y sin traducción. En la excepción de `load-use` entre anteriores, IF confirma directamente el fetch elegible y registra su código `000` o `001` sin sobrescribir `IF/ID` ni exigir otro registro interetapa.

En ID la instrucción ilegal válida confirma `010`; en EX un target desalineado de branch tomado, `jal` o `jalr` confirma `000`, la **misma causa arquitectónica** que un fetch desalineado aunque se detecte en etapa distinta. Para loads y stores EX se elige respectivamente entre `100`/`101` o `110`/`111`; si una misma operación presenta desalineación y acceso inválido, se selecciona su código **misaligned**, conforme a `misalignment > access fault`. Entre instrucciones distintas continúa prevaleciendo la más antigua válida del camino correcto. La causa identifica el **tipo de fault**, no la etapa física donde se detectó.

`fault_cause[2:0]` se captura únicamente junto a la **confirmación arquitectónica** y permanece estable, con `fault_pc`, durante `FAULT_DRAIN` y `FAULT`. Un candidato detectado pero descartado (`wrong-path`, inválido o posterior a frontera anterior) no altera esos metadatos. Reset global y `LOAD` aceptado mantienen la invalidación semántica de candidatos y de la condición de fault conforme a `DEC-ARCH-008`, sin requerir borrar bits residuales. Este trigésimo quinto acuerdo **revisa explícitamente solo el ancho antes abierto** del campo de candidato del acuerdo vigésimo noveno: `IF/ID` continúa con cinco campos; los otros tres registros interetapa no ganan campos de fault. `fault_pc`, prioridades, etapas de detección y rutas de transporte/confirmación conservan sus acuerdos anteriores. El trigésimo sexto acuerdo fija después `terminal_kind[1:0]` como indicador global de fault confirmado y la derivación de `fault_drain`/`fault`; la representación externa de Debug/UART sigue pendiente.

#### Acuerdo parcial aprobado — representación del estado global de terminación y drenado

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

**Revisión expresa por el cuadragésimo cuarto acuerdo:** las fórmulas registradas `terminal_kind` y `drain_auto` de este acuerdo quedan sustituidas por los estados de `global_state` y predicados combinacionales derivados. Esta sección documenta el contrato semántico anterior; ya no exige esos dos flip-flops, ni que `HALT_DRAIN`/`FAULT_DRAIN` sean condiciones únicamente combinacionales. Permanecen la exclusión `HALT`/`FAULT`, la terminación en el flanco que vacía el último registro interetapa y la distinción de drenado continuo o por `STEP`.

La frontera terminal confirmada se representa mediante **estado global registrado fuera de los cuatro registros interetapa**, sin almacenar `HALT_DRAIN`, `FINISHED`, `FAULT_DRAIN` y `FAULT` como cuatro estados independientes:

| `terminal_kind[1:0]` | Significado |
|---|---|
| `00` | `NONE`: aún no hay frontera terminal arquitectónicamente confirmada |
| `01` | `HALT`: se confirmó un `halt` válido |
| `10` | `FAULT`: se confirmó un fault arquitectónico |
| `11` | `RESERVED`: no se genera por confirmaciones válidas |

La clase registrada es única: no pueden estar confirmados simultáneamente `halt` y fault. La selección de la frontera sigue sometida a **validez, camino correcto y antigüedad EX→ID→IF excepcional** y al tratamiento de fault propio y de stalls entre anteriores supervivientes ya aprobados; la codificación no reabre su arbitraje semántico. Durante un ciclo CPU efectivo, `halt` válido confirmado en EX establece `terminal_kind.next=HALT`; un fault confirmado en EX, ID o excepcionalmente IF establece `terminal_kind.next=FAULT` **junto con** la captura de `fault_cause[2:0]` y `fault_pc`. Un candidato de `halt` en ID, un candidato de fault no confirmado o trabajo joven descartado no altera la clase terminal ni esos metadatos.

La ocupación actual del pipeline se calcula combinacionalmente a partir de las cuatro validez de instrucción:

```text
pipeline_empty =
    !IF/ID.valid
    && !ID/EX.valid
    && !EX/MEM.valid
    && !MEM/WB.valid

halt_drain  = (terminal_kind == HALT)  && !pipeline_empty
finished    = (terminal_kind == HALT)  &&  pipeline_empty

fault_drain = (terminal_kind == FAULT) && !pipeline_empty
fault       = (terminal_kind == FAULT) &&  pipeline_empty
```

`fetch_fault_valid` **no** integra `pipeline_empty`: después de confirmar una frontera terminal no se admiten instrucciones jóvenes ni se conservan candidatos posteriores, y solo se drenan instrucciones anteriores válidas. En el fault IF excepcional durante `load-use`, el consumidor anterior permanece válido en `IF/ID`, por lo que `fault_drain` continúa activo mientras ese consumidor avance y complete. Si ninguna anterior sobrevive, la condición final `finished` o `fault` surge **tras el propio flanco de confirmación**, sin ciclo artificial de drenado. Si sí hay anteriores, pasa de `halt_drain`/`fault_drain` a la condición final al vaciarse el último registro interetapa en un ciclo efectivo, sin estado registrado intermedio ni ciclo extra. `HOLD` no altera la ocupación registrada y no adelanta esa transición.

Se registra además un único bit global **`drain_auto`** que recuerda cómo se autorizó el ciclo **confirmante**:

| Valor | Modalidad y autorización posterior |
|---|---|
| `0` | Modo paso a paso: cada ciclo posterior de drenado requiere un **`STEP` nuevo aceptado** |
| `1` | Autorización continua: se podrán solicitar automáticamente ciclos posteriores de drenado |

En la confirmación `drain_auto.next=1` si el ciclo fue autorizado bajo ejecución continua, o `drain_auto.next=0` si fue autorizado por `STEP` aceptado.

Mientras `terminal_kind != NONE && !pipeline_empty` existe drenado pendiente; `drain_auto` **no es por sí solo** un pulso de avance ni habilita writebacks/stores. Todo avance requiere ciclo CPU efectivo autorizado, incluso si entre las supervivientes hacen falta stalls o forwarding; `HOLD` no produce ciclo ni repite efectos.

Una vez derivados `finished` o `fault`, no queda trabajo que drenar ni se solicitan ciclos normales por esa condición.

Esta representación no sustituye el control global de `RESET`, `LOAD`, `RUN`, `STEP` y `HOLD`, cuya prioridad sigue siendo **`reset` global > `LOAD` aceptado/preparación > ciclo efectivo > `HOLD`**, conforme a `DEC-ARCH-008`.

Reset global y preparación coherente de nueva sesión establecen `terminal_kind=NONE` y `drain_auto=0`; el mero intento de `LOAD` rechazado durante `RUN` o drenado automático no cambia estos registros. Con `terminal_kind=NONE`, los bits residuales de `fault_cause` y `fault_pc` no representan un fault confirmado y no necesitan limpiarse físicamente. En `terminal_kind=FAULT`, ambos metadatos permanecen estables durante `fault_drain` y `fault`; tampoco se reemplazan por candidatos posteriores. El trigésimo sexto acuerdo fija la **representación terminal y la modalidad de drenado**, sin añadir campos a `IF/ID`, `ID/EX`, `EX/MEM` o `MEM/WB`, imponer códigos de estados del control global, formato Debug/UART ni ecuaciones RTL de arbitraje no cubiertas.

> **Aclaración de adaptación RV32 (AUD-011, 2026-09-26):** conservar los opcodes de la ALU de TP1/TP2 no exige conservar su cantidad de desplazamiento genérica. `SLL`/`SRL`/`SRA` consumen solo los cinco bits bajos del operando de cantidad seleccionado (`shamt = operand_b[4:0]`), por registro o inmediato. `SRA` interpreta con signo el dato; los bits fijos de SRAI no forman parte de `shamt`. La adaptación puede estar dentro de la ALU o en su frontera, sin cambiar opcodes ni modificar los TPs anteriores.

#### Acuerdo parcial aprobado — ecuaciones RTL del decoder de ID

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

ID utilizará un **decoder combinacional único** que valide la palabra completa de `IF/ID.instruction[31:0]` contra la whitelist estricta de **32 instrucciones RV32I y `halt = 32'h0000000B`** de `DEC-ARCH-004` y genere los controles semánticos para `ID/EX`. Se observan `opcode = instruction[6:0]`, `funct3 = instruction[14:12]` y `funct7 = instruction[31:25]`; para shifts inmediatos, los siete bits superiores se comprueban como campo fijo. Todos los índices de registros, inmediatos y `shamt` de cinco bits permitidos por RV32I conservan su libertad: validar la palabra completa significa comprobar **los bits fijos aplicables**, no exigir valores concretos para operandos o inmediatos variables. No se incorporan campos nuevos a `IF/ID`.

```text
illegal_candidate = IF/ID.valid && !decode_legal
halt_candidate = IF/ID.valid && decode_legal
                 && (IF/ID.instruction == 32'h0000000B)
```

`decode_legal` clasifica combinacionalmente la codificación, sin confirmar por sí solo un fault. Con `IF/ID.valid=0, IF/ID.fetch_fault_valid=1` hay un **candidato de fetch**, no una instrucción ilegal; los bits de `instruction` son residuales. Solo una instrucción válida del camino correcto puede producir `illegal_candidate`; su confirmación en ID sigue sujeta a la frontera más antigua EX→ID→IF excepcional. Una palabra exacta de `halt` válida en ID genera únicamente `halt_candidate`; su confirmación sigue ocurriendo en EX.

**R-type (`opcode=0110011`).** Se admiten únicamente estos diez pares exactos:

| Instrucción | `funct7` | `funct3` | `alu_op[5:0]` |
|---|---|---|---|
| `add` | `0000000` | `000` | `100000` (`ADD`) |
| `sub` | `0100000` | `000` | `100010` (`SUB`) |
| `sll` | `0000000` | `001` | `000000` (`SLL`) |
| `slt` | `0000000` | `010` | `101010` (`SLT`) |
| `sltu` | `0000000` | `011` | `101011` (SLTU) |
| `xor` | `0000000` | `100` | `100110` (`XOR`) |
| `srl` | `0000000` | `101` | `000010` (`SRL`) |
| `sra` | `0100000` | `101` | `000011` (`SRA`) |
| `or` | `0000000` | `110` | `100101` (`OR`) |
| `and` | `0000000` | `111` | `100100` (`AND`) |

En los diez casos: `alu_src=0`, `result_sel=00`, `flow_op=000`, `mem_op=0000`, `reg_write=1`, `uses_rs1=1`, `uses_rs2=1`. Todo otro par `funct7/funct3` para este `opcode` es ilegal, incluso si comparte parcialmente un código de ALU.

**I-type aritméticas y shifts inmediatos (`opcode=0010011`).** Para `addi` (`funct3=000`), `slti` (`010`), `sltiu` (`011`), `xori` (`100`), `ori` (`110`) y `andi` (`111`), `alu_op` es respectivamente `ADD` (`100000`), `SLT` (`101010`), SLTU (`101011`), `XOR` (`100110`), `OR` (`100101`) y `AND` (`100100`). Sus doce bits de inmediato siguen siendo variables. Las otras tres codificaciones legales bajo este `opcode` exigen **además** los bits fijos `instruction[31:25]`:

| Instrucción | `funct3` | `instruction[31:25]` | `alu_op[5:0]` |
|---|---|---|---|
| `slli` | `001` | `0000000` | `000000` (`SLL`) |
| `srli` | `101` | `0000000` | `000010` (`SRL`) |
| `srai` | `101` | `0100000` | `000011` (`SRA`) |

En las nueve I aritméticas/shifts: `alu_src=1`, `result_sel=00`, `flow_op=000`, `mem_op=0000`, `reg_write=1`, `uses_rs1=1`, `uses_rs2=0`. Un shift inmediato con `instruction[31:25]` distinto del patrón correspondiente es ilegal; sus bits `instruction[24:20]` son el `shamt` legal de cinco bits, no otro `rs2` consumido.

**Memoria.** Todos los loads (`opcode=0000011`) usan `ADD` (`alu_op=100000`), `alu_src=1`, `result_sel=00`, `flow_op=000`, `reg_write=1`, `uses_rs1=1`, `uses_rs2=0`. Los stores (`opcode=0100011`) usan `ADD`, `alu_src=1`, `result_sel=00`, `flow_op=000`, `reg_write=0`, `uses_rs1=1`, `uses_rs2=1`:

| Clase | `funct3` | Instrucción | `mem_op[3:0]` |
|---|---|---|---|
| Load | `000` | `lb` | `0001` |
| Load | `001` | `lh` | `0010` |
| Load | `010` | `lw` | `0011` |
| Load | `100` | `lbu` | `0100` |
| Load | `101` | `lhu` | `0101` |
| Store | `000` | `sb` | `0110` |
| Store | `001` | `sh` | `0111` |
| Store | `010` | `sw` | `1000` |

Los `funct3` restantes de esos opcodes son ilegales. El dato de store de `rs2` continúa resolviéndose mediante forwarding en EX y transportándose en `EX/MEM.store_data` hasta MEM, aunque la ALU use el inmediato como segundo operando para la dirección.

**Branches (`opcode=1100011`).** Solo `funct3=000` (`beq`, `flow_op=001`) y `funct3=001` (`bne`, `flow_op=010`) son legales. En ambos: `alu_op=SUB` (`100010`), `alu_src=0`, `result_sel=00`, `mem_op=0000`, `reg_write=0`, `uses_rs1=1`, `uses_rs2=1`. EX compara mediante la resta y `ALU.zero` ya aprobadas. Los demás `funct3` son ilegales.

**Saltos, `lui` y `halt`.** Los controles restantes son:

| Instrucción | Patrón legal | `alu_op` | `alu_src` | `result_sel` | `flow_op` | `mem_op` | `reg_write` | `uses_rs1` / `uses_rs2` |
|---|---|---|---|---|---|---|---|---|
| `jal` | `opcode=1101111` | `ADD` | `1` | `10` (LINK) | `011` (`JAL`) | `0000` | `1` | `0` / `0` |
| `jalr` | `opcode=1100111`, `funct3=000` | `ADD` | `1` | `10` (LINK) | `100` (`JALR`) | `0000` | `1` | `1` / `0` |
| `lui` | `opcode=0110111` | `ADD` | `1` | `01` (IMMEDIATE) | `000` (`NONE`) | `0000` | `1` | `0` / `0` |
| `halt` | word completa `32'h0000000B` | `ADD` | `0` | `00` (ALU) | `101` (`HALT`) | `0000` | `0` | `0` / `0` |

Para `jal`, `lui` y `halt`, `alu_op=ADD` (`100000`) y `alu_src` tienen valores **deterministas sin consumo funcional** de la ALU. `jalr` sigue calculando el target `(rs1_effective + immediate) & 32'hFFFFFFFE` con el camino dedicado aprobado, no con un cambio del decoder. Cualquier `funct3` distinto de `000` bajo `1100111` es ilegal; cualquier otra palabra `custom-0` que no sea la **palabra completa** de `halt` también es ilegal.

**Defaults al inicio de la lógica combinacional**, aplicables a toda codificación no reconocida:

```text
decode_legal = 0
alu_op       = 6'b100000  // ADD
alu_src      = 0           // RS2
result_sel   = 2'b00       // ALU
flow_op      = 3'b000      // NONE
mem_op       = 4'b0000     // NONE
reg_write    = 0
uses_rs1     = 0
uses_rs2     = 0
```

El decoder comprueba conceptualmente primero la palabra exacta de `halt` y después `opcode` y subcampos funcionales cuando corresponda; podrá implementarse con una única lógica combinacional equivalente. Una instrucción ilegal mantiene los defaults funcionalmente neutros, pero **su confirmación en ID impide que ingrese válida a `ID/EX`**; sus bits residuales no se convierten en operaciones activas. `decode_legal` no convierte en válida una entrada `IF/ID.valid=0` ni genera efectos arquitectónicos por sí solo. `uses_rs1` y `uses_rs2` quedan fijados como **salidas combinacionales derivadas**, no campos registrados de `IF/ID` o `ID/EX`; para forwarding en EX su información podrá volver a derivarse de la instrucción/control ya registrado. No se obliga a empaquetar las seis categorías de control en un bus único.

Este trigésimo séptimo acuerdo fija el decoder de ID y sus ecuaciones funcionales sin cambiar la whitelist, la generación del inmediato, el arbitraje por antigüedad EX→ID→IF excepcional, los enables, la política de faults confirmados ni el control global de ciclos. Solo una coincidencia completa con la whitelist produce `decode_legal=1` y controles aptos para **ingreso válido** a `ID/EX` cuando las fronteras más antiguas lo permitan.

#### Acuerdo parcial aprobado — ecuaciones de controles derivados locales

**Fecha:** 2026-09-25

Los controles transportados mantienen los nombres y códigos del trigésimo cuarto acuerdo; las siguientes señales son **lógica combinacional local**, no campos nuevos de `ID/EX`, `EX/MEM` o `MEM/WB`. Se conserva `mem_op[3:0]` en `ID/EX` y `EX/MEM`: `0000` `NONE`; `0001` `LB`; `0010` `LH`; `0011` `LW`; `0100` `LBU`; `0101` `LHU`; `0110` `SB`; `0111` `SH`; `1000` `SW`; `1001`–`1111` `RESERVED`.

```text
is_load(mem_op) =
       (mem_op == 4'b0001)  // LB
    || (mem_op == 4'b0010)  // LH
    || (mem_op == 4'b0011)  // LW
    || (mem_op == 4'b0100)  // LBU
    || (mem_op == 4'b0101)  // LHU

is_store(mem_op) =
       (mem_op == 4'b0110)  // SB
    || (mem_op == 4'b0111)  // SH
    || (mem_op == 4'b1000)  // SW

mem_access = is_load || is_store
```

Estas funciones se aplican **localmente al `mem_op` de la etapa correspondiente**: en `ID/EX` sirven, entre otras cosas, para detectar `load-use`; en `EX/MEM` determinan disponibilidad de forwarding y acceso/selección de valor en MEM. No se arrastra un bit `is_load`, `is_store` o `mem_access` por los registros interetapa. Solo una instrucción válida y elegible podrá ocasionar acceso a memoria o efectos arquitectónicos: la decodificación combinacional de residuos no habilita operaciones por sí sola.

| `access_size[1:0]` | Significado | `mem_op` que lo seleccionan |
|---|---|---|
| `00` | BYTE | `LB`, `LBU`, `SB` |
| `01` | HALFWORD | `LH`, `LHU`, `SH` |
| `10` | WORD | `LW`, `SW` |
| `11` | `RESERVED` | Ninguna operación válida |

Con `mem_access=0`, `access_size` **carece de significado funcional**; no se impone valor para `NONE`, códigos reservados ni entradas inválidas. La extensión de loads se selecciona localmente por:

```text
load_unsigned = (mem_op == 4'b0100) || (mem_op == 4'b0101)
```

Así, `LB`/`LH`/`LW` tienen `load_unsigned=0` y `LBU`/`LHU` `load_unsigned=1`. Para stores, `NONE` y códigos reservados, el valor no se consume y es funcionalmente irrelevante. Se conservan el ancho del acceso, el chequeo de rango/alineación en EX y la extensión en MEM ya aprobados.

La disponibilidad del **resultado arquitectónico** de un productor en `EX/MEM` se obtiene sin bit registrado adicional:

```text
exmem_result_available = !is_load(EX/MEM.mem_op)

forward_exmem_rsN = exmem_match_rsN && exmem_result_available
forward_memwb_rsN = !exmem_match_rsN && memwb_match_rsN
```

`exmem_match_rsN` ya exige consumidor válido y fuente utilizada, productor `EX/MEM` válido, `reg_write=1`, `rd != x0` y coincidencia de índice; no se repiten esas condiciones en `exmem_result_available`. Para una instrucción escritora válida no load, `EX/MEM.ex_result` contiene el resultado reenviable (ALU, `lui` o enlace); para un load, solo la **dirección efectiva**, no el dato. Si ese load es el productor coincidente más reciente, `forward_exmem_rsN=0` y `forward_memwb_rsN=0`, aunque `MEM/WB` tenga una versión anterior; tampoco se consume el valor base obsoleto de `ID/EX` que pueda aparecer como salida residual del mux. Los stalls y el avance de anteriores supervivientes siguen las reglas ya aprobadas. Para una entrada `EX/MEM` inválida o con control residual, `!is_load` puede evaluarse a uno sin crear forwarding: `exmem_match_rsN=0`. No se define un uso arquitectónico de códigos `mem_op` reservados como si fueran instrucciones válidas.

Las clases de flujo se derivan exclusivamente de `ID/EX.flow_op[2:0]`:

```text
is_beq  = (ID/EX.flow_op == 3'b001)
is_bne  = (ID/EX.flow_op == 3'b010)
is_jal  = (ID/EX.flow_op == 3'b011)
is_jalr = (ID/EX.flow_op == 3'b100)
is_halt = (ID/EX.flow_op == 3'b101)

target_sel = is_jalr
// equivalentemente: target_sel = (ID/EX.flow_op == 3'b100)

wb_value_sel = is_load(EX/MEM.mem_op)
```

`target_sel=0` selecciona `PC_RELATIVE` para `BEQ`/`BNE`/`JAL`; `target_sel=1` selecciona `JALR_TARGET` para `JALR`. Con `NONE` o `HALT`, `target_sel` puede valer combinacionalmente cero, pero el camino de target carece de efecto arquitectónico; una entrada inválida tampoco aplica redirect por sus bits residuales. `wb_value_sel=1` elige `LOAD_VALUE` para `LB`/`LH`/`LW`/`LBU`/`LHU` y `0` elige `EX_RESULT` para los demás códigos; si la entrada no escribe registro o es inválida, esa selección no compromete writeback. Los predicados de flujo no se registran como campos físicos independientes y no sustituyen la validez ni la prioridad por antigüedad.

`result_sel[1:0]` **ya viaja explícitamente a EX**: no necesita derivación adicional. El `Result MUX` forma `ex_result = alu_result` con `00`, `ex_result = immediate` con `01` o `ex_result = link_value` con `10`; `11` permanece reservado y nunca es emitido para una instrucción válida. `target_sel`, `wb_value_sel`, tamaño/unsigned y las clasificaciones de flujo/memoria son locales y no amplían el contenido registrado de ningún registro interetapa.

Este trigésimo octavo acuerdo cierra estas **ecuaciones de derivación combinacional**, incluida `exmem_result_available`, sin modificar la ecuación de forwarding por fuente del trigésimo segundo acuerdo; los acuerdos cuadragésimo primero y segundo fijan después el arbitraje y la actualización de PC/registros interetapa, mientras la autorización global de ciclos permanece pendiente. Una señal combinacional aislada no produce efectos sin instrucción válida, camino elegible y ciclo efectivo.

#### Acuerdo parcial aprobado — realización RTL del Load-Use Hazard Detector y la Forwarding Unit

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se fija la realización RTL **combinacional** de los dos bloques de hazards de datos ya aprobados. No cambian la política funcional del trigésimo segundo acuerdo, los cuatro registros interetapa, los dos `Forward MUX` 3:1 ni el bypass WB→ID separado. El **`Load-Use Hazard Detector`** utiliza los índices de `IF/ID` obtenidos de la instrucción y las salidas combinacionales de uso del decoder de ID del trigésimo séptimo acuerdo:

```text
ifid_rs1 = IF/ID.instruction[19:15]
ifid_rs2 = IF/ID.instruction[24:20]
ifid_uses_rs1, ifid_uses_rs2 = uso semántico decodificado en ID

idex_is_load = is_load(ID/EX.mem_op)

load_use_stall =
    ID/EX.valid
    && idex_is_load
    && (ID/EX.rd != 5'd0)
    && IF/ID.valid
    && (
         (ifid_uses_rs1 && (ifid_rs1 == ID/EX.rd))
         ||
         (ifid_uses_rs2 && (ifid_rs2 == ID/EX.rd))
       )
```

`IF/ID.fetch_fault_valid` no habilita consumidor: un candidato de fetch tiene `IF/ID.valid=0`, aunque los índices de la palabra residual coincidan. La salida `load_use_stall` **solo detecta** la dependencia; no escribe PC, retiene `IF/ID` ni inserta por sí misma la bubble. El `Pipeline Hazard Control` determinará si aplica el stall después de seleccionar fronteras EX→ID→IF excepcional y de descartar trabajo joven, únicamente cuando load y consumidor continúen siendo anteriores supervivientes. `HOLD` permite evaluar la ecuación sin autorizar una transición secuencial.

La **`Forwarding Unit`** vuelve a derivar `idex_uses_rs1` e `idex_uses_rs2` combinacionalmente de `ID/EX.instruction` ya registrada, con la clasificación semántica de fuentes aprobada; no registra estos bits ni agrega otro campo a `ID/EX`. Para cada fuente se implementan literalmente las coincidencias:

```text
exmem_match_rs1 =
    ID/EX.valid && idex_uses_rs1
    && EX/MEM.valid && EX/MEM.reg_write
    && (EX/MEM.rd != 5'd0)
    && (EX/MEM.rd == ID/EX.rs1)

memwb_match_rs1 =
    ID/EX.valid && idex_uses_rs1
    && MEM/WB.valid && MEM/WB.reg_write
    && (MEM/WB.rd != 5'd0)
    && (MEM/WB.rd == ID/EX.rs1)

exmem_match_rs2 =
    ID/EX.valid && idex_uses_rs2
    && EX/MEM.valid && EX/MEM.reg_write
    && (EX/MEM.rd != 5'd0)
    && (EX/MEM.rd == ID/EX.rs2)

memwb_match_rs2 =
    ID/EX.valid && idex_uses_rs2
    && MEM/WB.valid && MEM/WB.reg_write
    && (MEM/WB.rd != 5'd0)
    && (MEM/WB.rd == ID/EX.rs2)
```

Con la disponibilidad local fijada en el trigésimo octavo acuerdo, las habilitaciones y la prioridad de los **dos selectores independientes** quedan:

```text
exmem_result_available = !is_load(EX/MEM.mem_op)

forward_exmem_rs1 = exmem_match_rs1 && exmem_result_available
forward_memwb_rs1 = !exmem_match_rs1 && memwb_match_rs1

forward_a_sel = forward_exmem_rs1 ? 2'b01 :
                forward_memwb_rs1 ? 2'b10 :
                                      2'b00

forward_exmem_rs2 = exmem_match_rs2 && exmem_result_available
forward_memwb_rs2 = !exmem_match_rs2 && memwb_match_rs2

forward_b_sel = forward_exmem_rs2 ? 2'b01 :
                forward_memwb_rs2 ? 2'b10 :
                                      2'b00
```

Para ambos muxes de 32 bits, `00` elige `ID/EX.rsN_value`, `01` elige `EX/MEM.ex_result` y `10` elige `MEM/WB.wb_value`; `11` permanece reservado y no se genera en una selección válida. La negación de prioridad se aplica a **`exmem_match_rsN`**, no a `forward_exmem_rsN`: un `EX/MEM` coincidente siempre oculta un productor `MEM/WB` anterior para esa fuente, aun cuando `exmem_result_available=0` por tratarse de un load.

Si `exmem_match_rsN=1` y `exmem_result_available=0`, ambas habilitaciones son cero y el selector respectivo toma **físicamente `2'b00`**. La entrada base que muestre el mux es un dato residual **no consumible** en esa situación; ni la dirección efectiva de `EX/MEM`, ni el `wb_value` anterior de `MEM/WB` ni el valor base obsoleto pueden actuar como operando arquitectónico. La consumidora inmediata habrá esperado conforme a `load-use`, y los stalls que necesiten anteriores supervivientes se preservan durante el drenado. No se añade una cuarta entrada, bypass `DMEM → EX` ni un tipo nuevo de hazard. Productores inválidos, sin `reg_write` o con `rd=x0`, consumidores inválidos y fuentes no usadas no generan coincidencia funcional; `exmem_result_available` aislado no la sustituye. Ambos bloques pueden evaluarse durante `HOLD` sin originar por sí mismos ciclos, commits ni cambios de los registros interetapa.

Este trigésimo noveno acuerdo **cierra las ecuaciones RTL de detección y selección de los dos bloques combinacionales**. El cuadragésimo acuerdo fija después candidatos y confirmaciones/aplicación de fault, redirect y `halt`; el cuadragésimo primero fija la selección combinacional de acciones del `Pipeline Hazard Control`. El cuadragésimo segundo fija después los enables, bubble/flush y capturas de PC/registros interetapa para esas acciones; permanecen abiertas las coincidencias globales no cubiertas, siempre bajo la prioridad por antigüedad ya fijada. No se introduce estado ni control registrado adicional.

#### Acuerdo parcial aprobado — detección y confirmación RTL de eventos arquitectónicos

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

**Revisión de representación por el acuerdo 44:** `terminal_none` se deriva ahora de `global_state`; `terminal_kind.next` en las descripciones históricas designa la transición de la FSM a la clase `FAULT`/`HALT` y no un registro separado. Las confirmaciones, la selección de `fault_cause_in`/`fault_pc_in` y su instante de captura permanecen literalmente vigentes.

Se fijan las **señales combinacionales de detección** y las **condiciones de confirmación o aplicación** de faults, `halt` y redirects. `cpu_cycle_fire` designa conceptualmente un ciclo CPU efectivo autorizado por el control global, no un nuevo estado ni una ecuación para generar esa autorización; `terminal_none = (terminal_kind == NONE)` indica ausencia de frontera terminal previamente confirmada. Reset y `LOAD` aceptado/preparación preceden al ciclo efectivo conforme a `DEC-ARCH-008`. Durante `HOLD` puede evaluarse la lógica combinacional, pero no se confirma ni aplica ningún evento. Se conserva el arbitraje por antigüedad **EX→ID→IF excepcional**.

En IF se verifican los cuatro bytes del fetch con **aritmética ensanchada** frente a la capacidad de IMEM y al prefijo de imagen confirmado; la alineación se comprueba independientemente:

```text
if_fetch_range_valid =
    image_valid
    && ({1'b0, PC} + 33'd4 <= IMEM_CAPACITY_BYTES)
    && ({1'b0, PC} + 33'd4 <= loaded_image_size_bytes)

if_fetch_misaligned = (PC[1:0] != 2'b00)
if_fetch_access_fault = !if_fetch_range_valid
if_fetch_fault_candidate = if_fetch_misaligned || if_fetch_access_fault

if_fetch_fault_cause =
    if_fetch_misaligned    ? 3'b000 :  // INSTRUCTION_ADDRESS_MISALIGNED
    if_fetch_access_fault ? 3'b001 :  // INSTRUCTION_ACCESS_FAULT
                            irrelevante si no hay candidato
```

Ante ambas causas de un **mismo fetch**, desalineación prevalece sobre acceso inválido; la detección ordinaria en IF no confirma fault. En ID la palabra obtenida de un fetch válido se clasifica con el decoder único aprobado; un candidato de fetch registrado no es una instrucción ilegal:

```text
illegal_candidate = IF/ID.valid && !decode_legal
id_fetch_fault_candidate = !IF/ID.valid && IF/ID.fetch_fault_valid
id_fault_candidate = illegal_candidate || id_fetch_fault_candidate

if (illegal_candidate):
    id_fault_cause = 3'b010  // ILLEGAL_INSTRUCTION
    id_fault_pc    = IF/ID.pc
else if (id_fetch_fault_candidate):
    id_fault_cause = IF/ID.fetch_fault_cause
    id_fault_pc    = IF/ID.pc
```

Las dos rutas ID son mutuamente excluyentes por la representación de `IF/ID`. Fuera de `id_fault_candidate`, las salidas de causa/PC combinacionales no habilitan captura global.

> **Aclaración por AUD-004 (2026-09-26):** en las ecuaciones históricas siguientes, `effective_address` es el resultado módulo `2^32` de base más inmediato; su carry no es un fault. La protección contra overflow/wrap-around se refiere a la suma ensanchada del extremo de la región y a su indexación, conforme a la aclaración de `DEC-ARCH-001` y `DEC-ARCH-004`.

EX calcula la dirección efectiva de cada load/store **con `rs1_effective` reenviado cuando corresponda**. `access_size` es la derivación local ya fijada de `ID/EX.mem_op`; su número de bytes solicitado y el rango completo se expresan así, sin truncamiento, wrap-around ni validación parcial:

```text
effective_address = rs1_effective + ID/EX.immediate

access_size == BYTE     → mem_nbytes = 1
access_size == HALFWORD → mem_nbytes = 2
access_size == WORD     → mem_nbytes = 4

dmem_range_valid =
    ({1'b0, effective_address} + mem_nbytes) <= DMEM_CAPACITY_BYTES

mem_misaligned =
    (access_size == HALFWORD && effective_address[0])
    || (access_size == WORD && |effective_address[1:0])

load_misaligned_candidate =
    ID/EX.valid && is_load(ID/EX.mem_op) && mem_misaligned
load_access_candidate =
    ID/EX.valid && is_load(ID/EX.mem_op) && !dmem_range_valid
store_misaligned_candidate =
    ID/EX.valid && is_store(ID/EX.mem_op) && mem_misaligned
store_access_candidate =
    ID/EX.valid && is_store(ID/EX.mem_op) && !dmem_range_valid
```

Los accesos BYTE nunca fallan por alineación natural. Los valores de tamaño reservados o residuales en una entrada inválida no producen un acceso arquitectónico; un candidato confirmado inhibe **todos** los efectos propios de la operación, incluso las escrituras parciales de un store. Para branch y jump en EX se conservan las clases de `flow_op` y los destinos ya fijados:

```text
branch_taken = (is_beq && ALU.zero) || (is_bne && !ALU.zero)

redirect_requested =
    ID/EX.valid && (branch_taken || is_jal || is_jalr)

BEQ / BNE / JAL → redirect_target = pc_relative_target
JALR            → redirect_target = jalr_target

target_misaligned_candidate =
    redirect_requested && (redirect_target[1:0] != 2'b00)
```

El branch no tomado no solicita redirect ni verifica como fault un target que no utiliza; `jalr_target` borra **solo** el bit 0 de `jalr_sum` antes de esa comprobación. Un target alineado fuera de IMEM o imagen puede redirigirse; el fetch posterior detectará por separado el candidato de acceso inválido.

`redirect_requested` concreta la **solicitud combinacional nominal** antes descrita como `redirect_valid`; no constituye una segunda clase de redirect ni equivale a `redirect_apply`. La solicitud puede coexistir con fault propio por target desalineado, pero solo la condición de aplicación efectúa el cambio de PC.

Las cinco candidaturas de fault propio de EX y su causa se seleccionan únicamente para la instrucción válida de esa etapa. Dentro de un mismo load/store se prioriza **desalineación sobre acceso inválido**:

```text
ex_fault_candidate =
    target_misaligned_candidate
    || load_misaligned_candidate || load_access_candidate
    || store_misaligned_candidate || store_access_candidate

if (target_misaligned_candidate):
    ex_fault_cause = 3'b000  // INSTRUCTION_ADDRESS_MISALIGNED
else if (load_misaligned_candidate):
    ex_fault_cause = 3'b100  // LOAD_ADDRESS_MISALIGNED
else if (load_access_candidate):
    ex_fault_cause = 3'b101  // LOAD_ACCESS_FAULT
else if (store_misaligned_candidate):
    ex_fault_cause = 3'b110  // STORE_ADDRESS_MISALIGNED
else if (store_access_candidate):
    ex_fault_cause = 3'b111  // STORE_ACCESS_FAULT

ex_halt_candidate = ID/EX.valid && (ID/EX.flow_op == HALT)
ex_halt_event = !ex_fault_candidate && ex_halt_candidate
ex_redirect_event =
    !ex_fault_candidate && !ex_halt_candidate && redirect_requested
ex_frontier = ex_fault_candidate || ex_halt_event || ex_redirect_event
```

EX no vuelve a comparar la palabra `32'h0000000B`: el decoder validó `halt` en ID y transportó `flow_op=HALT` con la instrucción válida. El orden interno EX representa **fault propio → `halt` → redirect**. Así, un jump con target desalineado puede presentar `redirect_requested=1`, pero su fault propio impide aplicar el redirect y, para `jal`/`jalr`, escribir enlace. Para instrucciones válidas del decoder, las categorías de memoria, salto y `halt` son excluyentes; la prioridad de causas no convierte códigos reservados en instrucciones válidas.

La confirmación/aplicación de cada frontera requiere un ciclo CPU efectivo y ninguna frontera terminal anterior:

```text
ex_fault_confirm =
    cpu_cycle_fire && terminal_none && ex_fault_candidate

halt_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_fault_candidate && ex_halt_candidate

redirect_apply =
    cpu_cycle_fire && terminal_none
    && !ex_fault_candidate && !ex_halt_candidate
    && redirect_requested

id_fault_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_frontier && id_fault_candidate

if_fault_exception_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_frontier && !id_fault_candidate
    && load_use_stall && if_fetch_fault_candidate

fault_confirm =
    ex_fault_confirm || id_fault_confirm || if_fault_exception_confirm
```

Ante `ex_fault_confirm`, se registra `terminal_kind.next=FAULT`, `fault_pc=ID/EX.pc` y la causa EX, y **la causante no entra válida a `EX/MEM`**. Ante `halt_confirm`, se registra `terminal_kind.next=HALT` y el propio `halt` tampoco entra válido a `EX/MEM`. Ante `redirect_apply`, PC captura `redirect_target`, la instrucción de control **sí** puede avanzar válida a `EX/MEM` y el trabajo joven secuencial se descarta. Si ID confirma una ilegal o un candidato de fetch transportado, registra `terminal_kind.next=FAULT`, causa/PC de `IF/ID` y no ingresa válida la causante a `ID/EX`; cualquier candidato joven en IF se descarta.

La excepción IF requiere el `load-use` ya detectado **entre load y consumidor anteriores supervivientes** y ausencia de frontera EX/ID; registra `terminal_kind.next=FAULT`, causa candidata de IF y `fault_pc=PC` del fetch actual. Conserva íntegros los cinco campos del consumidor anterior en `IF/ID`, inserta bubble en `ID/EX`, deja avanzar el load y no captura al fetch causante. Sin la excepción, la ruta ordinaria de un candidato de IF **no confirma inmediatamente**: si el avance normal lo permite, `IF/ID` captura `valid=0`, `fetch_fault_valid=1`, `fetch_fault_cause=if_fetch_fault_cause` y `pc=PC` para resolverlo posteriormente en ID.

Los metadatos globales se eligen estructuralmente por la ruta confirmada y **solo** se capturan si `fault_confirm=1`:

```text
if (ex_fault_confirm):
    fault_cause_in = ex_fault_cause
    fault_pc_in    = ID/EX.pc
else if (id_fault_confirm):
    fault_cause_in = id_fault_cause
    fault_pc_in    = IF/ID.pc
else if (if_fault_exception_confirm):
    fault_cause_in = if_fetch_fault_cause
    fault_pc_in    = PC

if (fault_confirm):
    fault_cause ← fault_cause_in
    fault_pc    ← fault_pc_in
    terminal_kind.next ← FAULT
```

Las rutas confirmadas se excluyen por la estructura EX→ID→IF excepcional. `fault_cause`/`fault_pc` permanecen estables durante `FAULT_DRAIN` y `FAULT`, incluso mientras avanzan instrucciones anteriores; no se reescriben por candidatos jóvenes ni por salidas combinacionales durante `HOLD`. Estas ecuaciones **cierran detección y confirmación/aplicación de eventos arquitectónicos** preservando los cuatro registros interetapa, la tabla preflanco del trigésimo primer acuerdo, los códigos de causa del trigésimo quinto, `terminal_kind` del trigésimo sexto y el detector del trigésimo noveno. El cuadragésimo primer acuerdo fija después la selección combinacional del `Pipeline Hazard Control`, incluida la aplicación del stall. Siguen pendientes la generación RTL de `cpu_cycle_fire`, el control global de ciclo y las coincidencias aún no cubiertas. El cuadragésimo segundo acuerdo fija después los enables/flush y próximos estados de PC y registros interetapa para las nueve acciones, pues estas señales de confirmación por sí solas no constituían todas sus ecuaciones secuenciales.

#### Acuerdo parcial aprobado — arbitraje RTL unificado del Pipeline Hazard Control

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

**Revisión de representación por el acuerdo 44:** `terminal_none`, `terminal_active` y `drain_active` son predicados combinacionales derivados de `global_state` y los cuatro `valid`; las ecuaciones siguientes mantienen su significado sin exigir `terminal_kind` ni `drain_auto` registrados. Los nueve `act_*` y su cobertura/exclusión no cambian.

Se fija un único **`Pipeline Hazard Control` combinacional** que selecciona una sola acción microarquitectónica aplicable por ciclo CPU efectivo. Recibe conceptualmente `cpu_cycle_fire`, `terminal_kind[1:0]`, `pipeline_empty`, `ex_fault_candidate`, `ex_halt_candidate`, `redirect_requested`, `id_fault_candidate`, `if_fetch_fault_candidate` y `load_use_stall`, ya definidos en los acuerdos anteriores. No es una FSM, no registra estado ni añade campos a los cuatro registros interetapa. `drain_auto` **no participa** en el arbitraje: solo interviene en el control global que autoriza un futuro `cpu_cycle_fire`. Una vez autorizado ese ciclo, el bloque escoge su transición interna según la antigüedad de las instrucciones supervivientes.

```text
terminal_none   = (terminal_kind == NONE)
terminal_active = (terminal_kind != NONE)
drain_active    = terminal_active && !pipeline_empty
```

Si `terminal_active && pipeline_empty`, ya se alcanzó `FINISHED` o `FAULT` y no queda trabajo de pipeline. En un ciclo de trabajo aún sin frontera terminal, las confirmaciones y la aplicación de redirect conservan literalmente las compuertas aprobadas en el cuadragésimo acuerdo:

```text
ex_fault_confirm =
    cpu_cycle_fire && terminal_none && ex_fault_candidate

halt_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_fault_candidate && ex_halt_candidate

redirect_apply =
    cpu_cycle_fire && terminal_none
    && !ex_fault_candidate && !ex_halt_candidate
    && redirect_requested

ex_frontier_selected =
    ex_fault_confirm || halt_confirm || redirect_apply

id_fault_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_frontier_selected && id_fault_candidate

if_fault_exception_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_frontier_selected && !id_fault_candidate
    && load_use_stall && if_fetch_fault_candidate
```

El orden interno **fault EX → `halt` EX → redirect EX** suprime los efectos normales de una instrucción con fault propio antes de considerar sus otros eventos. Entre **instrucciones distintas** sigue venciendo la más antigua EX→ID→IF excepcional: un redirect EX descarta una ilegal joven en ID y un candidato de IF; sin frontera EX, el fault ID prevalece sobre IF. `ex_frontier` del cuadragésimo acuerdo era la disyunción combinacional *sin* habilitación de ciclo; `ex_frontier_selected` es su versión confirmada/aplicada: cuando `cpu_cycle_fire && terminal_none`, ambas condiciones tienen el mismo valor y `!ex_frontier_selected` equivale a `!ex_frontier` en las confirmaciones ID/IF. Fuera de un ciclo autorizado ninguna de ellas habilita captura; las nuevas ecuaciones conservan sin contradicción las condiciones de confirmación ya aprobadas.

El detector `load_use_stall` no retiene directamente al consumidor. Solo se aplica en ausencia de fronteras prevalecientes, una vez descartado el trabajo más joven:

```text
load_use_apply =
    cpu_cycle_fire && terminal_none
    && !ex_frontier_selected && !id_fault_confirm
    && !if_fault_exception_confirm && load_use_stall

normal_advance =
    cpu_cycle_fire && terminal_none
    && !ex_frontier_selected && !id_fault_confirm
    && !if_fault_exception_confirm && !load_use_apply
```

Un candidato de fetch **ordinario** en IF no constituye por sí mismo frontera confirmada: si no hay excepción de confirmación en IF ni otra frontera o stall aplicable, `normal_advance=1` y el candidato se captura en `IF/ID` (`valid=0, fetch_fault_valid=1`) para resolverlo después en ID. En cambio, en la excepción IF se confirma el fault de fetch sin sobrescribir al consumidor anterior retenido en `IF/ID`; el load avanza según la transición preflanco ya aprobada. Ante fault propio del load EX, el consumidor joven se descarta y no se aplica el stall por esa dependencia.

Con `terminal_kind!=NONE` no se confirman nuevos faults, `halt` ni redirects del trabajo descartado. El drenado de las instrucciones **anteriores supervivientes** usa el mismo detector y puede incluir stall; no significa flush global:

```text
drain_cycle = cpu_cycle_fire && drain_active

drain_load_use = drain_cycle && load_use_stall
drain_advance  = drain_cycle && !load_use_stall
```

Se exponen conceptualmente **nueve acciones combinacionales**, sin registro de estado ni codificación de FSM adicional:

```text
act_ex_fault           = ex_fault_confirm
act_halt               = halt_confirm
act_redirect           = redirect_apply
act_id_fault           = id_fault_confirm
act_if_fault_exception = if_fault_exception_confirm
act_load_use           = load_use_apply
act_normal             = normal_advance
act_drain_load_use     = drain_load_use
act_drain_advance      = drain_advance
```

El bloque verifica la exclusión y cobertura del ciclo procesable:

```text
$onehot0({
    act_ex_fault,
    act_halt,
    act_redirect,
    act_id_fault,
    act_if_fault_exception,
    act_load_use,
    act_normal,
    act_drain_load_use,
    act_drain_advance
})

cpu_cycle_fire && (terminal_none || drain_active)
→ exactamente una acción seleccionada

!cpu_cycle_fire
→ ninguna acción produce transición secuencial

terminal_active && pipeline_empty
→ ninguna acción de pipeline

terminal_active
→ !ex_fault_confirm && !halt_confirm && !redirect_apply
  && !id_fault_confirm && !if_fault_exception_confirm
```

En un ciclo efectivo con `terminal_none`, exactamente una de las **siete** primeras acciones se selecciona; en un ciclo efectivo con `drain_active`, exactamente una de las **dos** acciones de drenado se selecciona. Si no hay autorización de ciclo, no se confirma ningún evento ni progresa el pipeline. Las acciones del bloque son la realización RTL del arbitraje semántico ya aprobado, **no** una prioridad universal nueva por tipo de evento. El trigésimo primer acuerdo mantiene las acciones preflanco de PC, `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB` como contrato; el cuadragésimo segundo acuerdo deriva después de estas acciones los enables, invalidaciones y valores `next` RTL exactos para ese contrato. El cuadragésimo cuarto acuerdo fija después la generación de `cpu_cycle_fire` y los 14 estados del control global; las coincidencias no cubiertas continúan pendientes; el bloque no introduce un bypass, stall, registro interetapa ni registro nuevo.

#### Acuerdo parcial aprobado — ecuaciones exactas de actualización de PC y registros de pipeline

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se fijan las ecuaciones RTL de próximo estado para PC y los cuatro registros interetapa a partir de las nueve acciones **mutuamente excluyentes** del cuadragésimo primer acuerdo. Toda captura lee entradas **previas al flanco**, preservando la tabla semántica del trigésimo primer acuerdo. Las acciones constituyen la única fuente de actualización **normal del pipeline**; `reset` global y `LOAD` aceptado/preparación conservan su mayor prioridad conforme a `DEC-ARCH-008`. Se define:

```text
pipeline_action =
    act_ex_fault || act_halt || act_redirect
    || act_id_fault || act_if_fault_exception
    || act_load_use || act_normal
    || act_drain_load_use || act_drain_advance
```

Con `pipeline_action=0` y sin `reset`/`LOAD`/preparación, PC, `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB` **retienen íntegramente su contenido**: un clock físico de `HOLD` no desplaza instrucciones ni inserta bubbles. También ocurre si ya se llegó a `FINISHED` o `FAULT` con el pipeline vacío. El control del PC queda:

```text
pc_write_enable = act_normal || act_redirect
next_pc_sel     = act_redirect

act_normal   → PC.next = PC + 4              // next_pc_sel=0: PC_PLUS_4
act_redirect → PC.next = redirect_target    // next_pc_sel=1: REDIRECT_TARGET
resto        → PC.next = PC                  // pc_write_enable=0
```

`next_pc_sel` puede valer físicamente cero durante retención sin obligar a capturar el camino secuencial; el PC no recibe una tercera entrada de mux. `IF/ID` distingue **captura de IF**, **retención** e **invalidación**:

```text
ifid_capture_if = act_normal

ifid_hold =
    act_load_use || act_if_fault_exception || act_drain_load_use

ifid_invalidate =
    act_redirect || act_halt || act_ex_fault
    || act_id_fault || act_drain_advance
```

Cuando `ifid_capture_if=1` y **no** hay candidato de fault en IF, se captura una instrucción normal; si hay candidato ordinario, se transporta sin hacerla válida:

```text
if (act_normal && !if_fetch_fault_candidate):
    IF/ID.next.valid             = 1
    IF/ID.next.pc                = PC
    IF/ID.next.instruction       = if_instruction
    IF/ID.next.fetch_fault_valid = 0
    IF/ID.next.fetch_fault_cause = 3'b000

if (act_normal && if_fetch_fault_candidate):
    IF/ID.next.valid             = 0
    IF/ID.next.pc                = PC
    IF/ID.next.instruction       = 32'b0
    IF/ID.next.fetch_fault_valid = 1
    IF/ID.next.fetch_fault_cause = if_fetch_fault_cause
```

El código `3'b000` cuando `fetch_fault_valid=0` es **determinista pero no indica un fault**; tampoco los ceros de la palabra candidata representan una instrucción válida. Con `ifid_hold=1` se conservan bit a bit los **cinco** campos (`valid`, `pc`, `instruction`, `fetch_fault_valid`, `fetch_fault_cause`), ya sea por `load-use` nominal, confirmación IF excepcional o `load-use` durante drenado. Con `ifid_invalidate=1` se exige `IF/ID.next.valid=0` **y** `IF/ID.next.fetch_fault_valid=0`; `pc`, `instruction` y `fetch_fault_cause` pueden conservar bits residuales o escribirse determinísticamente como `32'b0`, `32'b0` y `3'b000` respectivamente. Ninguna de estas alternativas admite candidatos o instrucciones por residuos.

`ID/EX` recibe una instrucción desde ID únicamente en avance normal o en avance de drenado; en los demás ciclos procesables recibe una **bubble**:

```text
idex_capture_id = act_normal || act_drain_advance

idex_bubble =
    act_load_use || act_redirect || act_halt || act_ex_fault
    || act_id_fault || act_if_fault_exception || act_drain_load_use

if (idex_capture_id):
    ID/EX.next.valid       = IF/ID.valid
    ID/EX.next.pc          = IF/ID.pc
    ID/EX.next.instruction = IF/ID.instruction

    ID/EX.next.rs1         = IF/ID.instruction[19:15]
    ID/EX.next.rs2         = IF/ID.instruction[24:20]
    ID/EX.next.rd          = IF/ID.instruction[11:7]

    ID/EX.next.rs1_value   = id_rs1_value_after_wb_bypass
    ID/EX.next.rs2_value   = id_rs2_value_after_wb_bypass
    ID/EX.next.immediate   = immediate

    ID/EX.next.alu_op      = decoded_alu_op
    ID/EX.next.alu_src     = decoded_alu_src
    ID/EX.next.result_sel  = decoded_result_sel
    ID/EX.next.flow_op     = decoded_flow_op
    ID/EX.next.mem_op      = decoded_mem_op
    ID/EX.next.reg_write   = decoded_reg_write

if (idex_bubble):
    ID/EX.next.valid       = 0
```

Los valores base son los posteriores al bypass **WB→ID** ya aprobado, no los datos crudos del almacenamiento; los demás campos de una bubble pueden quedar residuales sin NOP física. En `act_normal`, un candidato `IF/ID` con `valid=0` solo puede propagar invalidez si aún no fue confirmado ni descartado; en `act_drain_advance`, cualquier `IF/ID` válida es una instrucción **anterior superviviente**. En ese mismo flanco `IF/ID.next` queda inválido y `ID/EX.next` recibe el `IF/ID` **previo**, sin duplicarlo ni admitir un fetch nuevo. En `act_drain_load_use`, en cambio, `IF/ID` conserva íntegro al consumidor e `ID/EX` recibe bubble.

`EX/MEM` captura EX en todas las acciones salvo el fault propio EX y `halt` confirmado, que consumen a la causante sin ingresarla válida a MEM:

```text
exmem_capture_ex =
    act_normal || act_load_use || act_redirect
    || act_id_fault || act_if_fault_exception
    || act_drain_load_use || act_drain_advance

exmem_invalidate = act_halt || act_ex_fault

if (exmem_capture_ex):
    EX/MEM.next.valid       = ID/EX.valid
    EX/MEM.next.pc          = ID/EX.pc
    EX/MEM.next.instruction = ID/EX.instruction
    EX/MEM.next.rd          = ID/EX.rd
    EX/MEM.next.reg_write   = ID/EX.reg_write
    EX/MEM.next.mem_op      = ID/EX.mem_op
    EX/MEM.next.ex_result   = ex_result
    EX/MEM.next.store_data  = rs2_effective

if (exmem_invalidate):
    EX/MEM.next.valid       = 0

result_sel == ALU       → ex_result = alu_result
result_sel == IMMEDIATE → ex_result = ID/EX.immediate
result_sel == LINK      → ex_result = link_value
```

Durante `act_redirect` **continúa válida** hacia `EX/MEM` la instrucción de control de EX; ante `act_id_fault` continúa la instrucción EX anterior a la causante ID; ante `act_if_fault_exception` el load anterior de `ID/EX` entra en `EX/MEM`. Las entradas nuevas invalidadas no reactivan un store, enlace o writeback por datos residuales. `MEM/WB` avanza desde la **entrada previa de `EX/MEM`** en cualquiera de las nueve acciones:

```text
memwb_capture_mem = pipeline_action

if (memwb_capture_mem):
    MEM/WB.next.valid       = EX/MEM.valid
    MEM/WB.next.pc          = EX/MEM.pc
    MEM/WB.next.instruction = EX/MEM.instruction
    MEM/WB.next.rd          = EX/MEM.rd
    MEM/WB.next.reg_write   = EX/MEM.reg_write
    MEM/WB.next.wb_value    = wb_value

wb_value = is_load(EX/MEM.mem_op) ? load_value : EX/MEM.ex_result
```

Una frontera confirmada en EX, ID o IF no invalida retrospectivamente el store anterior que ya estaba en `EX/MEM` ni el writeback anterior en `MEM/WB`; ambos conservan su elegibilidad por validez y ciclo efectivo. El `wb_value` recién capturado en `MEM/WB` no se utiliza como si hubiera estado allí antes del flanco.

| Acción | PC | `IF/ID` | `ID/EX` | `EX/MEM` | `MEM/WB` |
|---|---|---|---|---|---|
| `act_normal` | `PC + 4` | Capture IF | Capture ID | Capture EX | Capture MEM |
| `act_load_use` | `HOLD` | `HOLD` | Bubble | Capture EX | Capture MEM |
| `act_redirect` | `redirect_target` | Invalidate | Bubble | Capture EX | Capture MEM |
| `act_halt` | `HOLD` | Invalidate | Bubble | Invalidate | Capture MEM |
| `act_ex_fault` | `HOLD` | Invalidate | Bubble | Invalidate | Capture MEM |
| `act_id_fault` | `HOLD` | Invalidate | Bubble | Capture EX | Capture MEM |
| `act_if_fault_exception` | `HOLD` | `HOLD` | Bubble | Capture EX | Capture MEM |
| `act_drain_load_use` | `HOLD` | `HOLD` | Bubble | Capture EX | Capture MEM |
| `act_drain_advance` | `HOLD` | Invalidate | Capture ID | Capture EX | Capture MEM |

Esta tabla es la realización RTL exacta de la tabla semántica del trigésimo primer acuerdo. Ante `act_drain_advance` **no se admite IF nuevo**: la superviviente de `IF/ID` pasa a `ID/EX` mientras `IF/ID` invalida tanto `valid` como `fetch_fault_valid`; ante `act_drain_load_use`, el load de EX avanza, el consumidor anterior permanece en `IF/ID` y posteriormente puede pasar a `ID/EX` sin pérdida.

`pipeline_action=0` conserva los cinco registros completos en `HOLD`, espera entre `STEP` o estado terminal vacío, mientras `reset`/`LOAD` tienen precedencia.

Los controles de captura/invalidez son combinacionales y se derivan de las acciones, sin crear registros o campos nuevos.

Este cuadragésimo segundo acuerdo **cierra las ecuaciones de actualización del PC y los cuatro registros interetapa para las acciones pactadas**; el cuadragésimo cuarto acuerdo fija después la generación de `cpu_cycle_fire` y el control global de sesión; el cuadragésimo tercero fija antes el gating de efectos de memoria/RegFile sujetos a validez.

La integración con coincidencias no cubiertas y la representación externa Debug siguen sus decisiones correspondientes.

#### Acuerdo parcial aprobado — gating definitivo de efectos arquitectónicos

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

**Revisión de representación por el acuerdo 44:** las ecuaciones de escritura de `terminal_kind` y `drain_auto` más abajo quedan sustituidas por transiciones de `global_state`. `terminal_write_enable`/`drain_auto_write_enable` dejan de ser enables de registros; solo `fault_confirm`/`halt_confirm` determinan la transición y `fault_capture_fire` sigue habilitando el par de metadatos. `cycle_from_continuous` pasa a ser la indicación combinacional de origen que selecciona el estado de drenado AUTO/`STEP`; el resto del gating de efectos CPU sigue vigente.

Se fijan las condiciones RTL de habilitación de los efectos arquitectónicos y globales originados por CPU. Cada efecto normal requiere un **ciclo CPU efectivo**, la **validez de su entrada de pipeline** y el **control local** que le corresponde. Todas las escrituras de etapa utilizan los campos **previos al flanco**. Una frontera confirmada en una instrucción más joven no cancela los efectos válidos de instrucciones anteriores; la causante y el trabajo descartado no alcanzan válidamente la etapa donde podrían comprometerlos.

La escritura del `Register File` y la elegibilidad del bypass interno WB→ID comparten la misma condición aprobada en `DEC-ARCH-007`:

```text
rf_write_fire =
    cpu_cycle_fire
    && MEM/WB.valid
    && MEM/WB.reg_write
    && (MEM/WB.rd != 5'd0)

if (rf_write_fire):
    RF[MEM/WB.rd] ← MEM/WB.wb_value

wb_write_enable = rf_write_fire
bypass_rs1 = rf_write_fire && (MEM/WB.rd == id_rs1)
bypass_rs2 = rf_write_fire && (MEM/WB.rd == id_rs2)
```

Cada puerto selecciona independientemente `MEM/WB.wb_value` cuando su bypass vale uno o su lectura ordinaria en caso contrario. Las coincidencias de bits durante `HOLD`, hacia `x0`, desde entradas inválidas o sin `reg_write` no anuncian writeback ni bypass. Un fault, `halt` o redirect detectado en etapas **más jóvenes** no inhibe a la instrucción anterior válida que ya se encontraba en WB.

El store CPU se compromete desde `EX/MEM` únicamente con validez, ciclo y tipo de operación:

```text
dmem_store_fire =
    cpu_cycle_fire
    && EX/MEM.valid
    && is_store(EX/MEM.mem_op)

if (dmem_store_fire):
    address = EX/MEM.ex_result
    data    = EX/MEM.store_data
    byte_enable = lanes seleccionados por EX/MEM.mem_op (SB, SH o SW)

dmem_metadata_write_fire = dmem_store_fire
```

El store modifica **atómicamente** el dato y los metadatos de cada byte seleccionado, conservando ambos para los bytes no seleccionados. En la implementación de referencia se actualizan juntos `data[byte]` y `valid[byte]`; un perfil físico equivalente conserva la misma semántica. No se vuelven a efectuar en MEM las comprobaciones arquitectónicas de alineación y rango realizadas en EX. Un store causante de fault propio nunca entra válido a `EX/MEM`, por lo que no activa ningún byte de DMEM ni sus metadatos. Un store anterior ya presente en MEM puede comprometerse en el mismo ciclo en que una instrucción más joven confirma fault o `halt`.

Si una implementación requiere habilitación **física** de lectura de DMEM, puede definir:

```text
dmem_load_access =
    cpu_cycle_fire
    && EX/MEM.valid
    && is_load(EX/MEM.mem_op)
```

La lectura combinacional puede existir sin commit arquitectónico; el load produce efecto arquitectónico después, si su resultado alcanza válido `MEM/WB` y se cumple `rf_write_fire`. Ninguna lectura de datos residuales escribe por sí sola el banco.

Solo la aplicación confirmada puede producir un redirect arquitectónico; se conservan exactamente las dos entradas del `Next-PC MUX` y el enable aprobados en el cuadragésimo segundo acuerdo:

```text
redirect_commit = redirect_apply
pc_write_enable = act_normal || act_redirect
next_pc_sel     = act_redirect
```

Un `redirect_target` puramente combinacional no altera el PC. `jal` y `jalr` válidos transportan `ex_result=link_value` y `reg_write=1` por `EX/MEM` y `MEM/WB` y escriben el enlace **solo** mediante `rf_write_fire`, sin enable arquitectónico adicional. Si su propia instrucción confirma fault en EX, no entra válida a `EX/MEM` y no puede aplicar redirect ni escribir enlace más adelante.

La captura persistente de un fault y la confirmación de `halt` se gobiernan exclusivamente por las confirmaciones ya arbitradas, equivalentes a sus acciones:

```text
fault_capture_fire = fault_confirm
                   = act_ex_fault || act_id_fault || act_if_fault_exception

halt_commit = halt_confirm = act_halt

if (fault_capture_fire):
    fault_cause.next = fault_cause_in
    fault_pc.next    = fault_pc_in
else:
    fault_cause.next = fault_cause
    fault_pc.next    = fault_pc
```

Los candidatos descartados, `wrong-path`, entradas inválidas y evaluaciones durante `HOLD` no modifican el par global de causa/PC; la candidatura de `halt` en ID tampoco confirma el estado terminal. Se consolida:

```text
terminal_write_enable = fault_confirm || halt_confirm

if (fault_confirm):
    terminal_kind.next = FAULT
else if (halt_confirm):
    terminal_kind.next = HALT
else:
    terminal_kind.next = terminal_kind

drain_auto_write_enable = terminal_write_enable

if (terminal_write_enable):
    drain_auto.next = cycle_from_continuous
else:
    drain_auto.next = drain_auto
```

`fault_confirm` y `halt_confirm` son mutuamente excluyentes. El control global proporciona `cycle_from_continuous=1` si **el ciclo confirmante** fue autorizado en contexto continuo, o `0` si provino de `STEP` aceptado; el bit capturado permanece estable durante el drenado y **no** genera por sí solo un futuro ciclo. Esta procedencia no impone codificación ni FSM para el control global.

El contador lógico usa una habilitación distinta de los commits de instrucciones:

```text
cycle_counter_increment = cpu_cycle_fire
```

Incrementa **exactamente una vez por ciclo CPU efectivo**, incluidos avance normal, stall `load-use`, redirect, confirmación de fault/`halt` y drenado; no incrementa durante `HOLD`. No se lo habilita por un dato combinacional ni por una acción local que retenga PC. El cuadragésimo cuarto acuerdo fija después la generación global de `cpu_cycle_fire` e impide autorizar ciclos adicionales una vez vacío un pipeline terminal, sin agregar un ciclo final vacío.

En síntesis: WB requiere `MEM/WB.valid` y `reg_write` para escribir; MEM requiere `EX/MEM.valid` e `is_store` para almacenar; los eventos EX requieren `ID/EX.valid` en sus candidatos, y ID interpreta una instrucción únicamente con `IF/ID.valid` o un candidato de fetch transportado mediante `IF/ID.fetch_fault_valid`. En todos los casos, la confirmación/commit exige el **ciclo efectivo** y los controles locales ya fijados. Bits residuales de etapas inválidas no crean efectos.

Estas son ecuaciones de **efectos normales del CPU**, subordinadas a la prioridad global de `DEC-ARCH-008`:

```text
RESET > LOAD aceptado / preparación > ciclo CPU efectivo > HOLD
```

Si `reset` o `LOAD`/preparación dominan el flanco, no se comprometen writeback, store, metadatos, captura de fault, confirmación de `halt` ni incremento del contador de la ejecución CPU previa, aunque las candidaturas combinacionales existan. Reset y `LOAD` conservan sus propios efectos de inicialización y ownership independientes. Este cuadragésimo tercer acuerdo cierra el **gating de efectos CPU** sin decidir la generación global de `cpu_cycle_fire`, las coincidencias adicionales no cubiertas o la representación Debug/UART.

#### Acuerdo parcial aprobado — FSM global de ejecución y autorización de ciclos

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se fija una **FSM Moore explícita de 14 estados** para el ciclo de vida global de la sesión. La FSM registra únicamente `global_state`, calcula `next_state` desde eventos aceptados y emite modos derivados del estado actual; **no** escribe PC, RF, IMEM, DMEM, pipeline o contador ni genera directamente `cpu_cycle_fire`. El `Command Arbiter` acepta comandos bajo `RESET` > `LOAD` > `STEP` > `RUN`; `Cycle Authorization`, Loader, `Session Preparation` y el datapath efectúan las acciones. Esta subdecisión **revisa explícitamente la representación física** de los acuerdos 36 y 40–43: `terminal_kind[1:0]` y `drain_auto` dejan de ser registros globales, así como sus ecuaciones de escritura del acuerdo 43. Permanecen las fronteras semánticas, las confirmaciones, las nueve acciones, el gating de RF/DMEM/metadatos/fault y la regla `cycle_counter_increment=cpu_cycle_fire`. Las ecuaciones anteriores que leen `terminal_kind`/`drain_auto` se reinterpretan mediante predicados **combinacionales** del estado, nunca como una segunda fuente registrada de verdad.

| Estado | Semántica |
|---|---|
| `NO_IMAGE` | No existe imagen ejecutable. |
| `LOADING` | Recepción y validación de nueva imagen. |
| `PREPARING_READY` | Preparación de nueva imagen para quedar detenida; todavía no hay commit de sesión. |
| `PREPARING_RUN` | Preparación de una sesión nueva con imagen ya confirmada, solicitada por `RUN` terminal. |
| `PREPARING_STEP` | Preparación de una sesión nueva con imagen ya confirmada, conservando **un `STEP` aceptado pendiente**. |
| `READY` | Imagen y sesión inicial confirmadas, ejecución aún no iniciada. |
| `RUNNING` | Ejecución continua normal. |
| `STEPPING` | Ejecución paso a paso entre autorizaciones. |
| `HALT_DRAIN_AUTO` / `HALT_DRAIN_STEP` | Drenado de anteriores tras `halt` confirmado, automático o por `STEP`. |
| `FAULT_DRAIN_AUTO` / `FAULT_DRAIN_STEP` | Drenado de anteriores tras fault confirmado, automático o por `STEP`. |
| `FINISHED` | Terminación normal con pipeline vacío. |
| `FAULT` | Terminación excepcional con pipeline vacío. |

La FSM recibe conceptualmente estas entradas:

| Productor | Entradas |
|---|---|
| Arbitraje de comandos | `reset`, `load_accept`, `run_accept`, `step_accept` |
| Loader | `load_ok`, `load_fail` |
| `Session Preparation` | `prepare_done` |
| Pipeline | `halt_confirm`, `fault_confirm` |
| `valid_next` combinacionales de los cuatro registros interetapa | `pipeline_empty_next` |

`load_ok` y `load_fail` se excluyen. `RESET` domina desde **cualquier** estado y lleva a `NO_IMAGE`; un `LOAD` aceptado domina cualquier ciclo CPU en estados que lo admiten. `LOAD` es elegible desde `NO_IMAGE`, `READY`, `STEPPING`, ambos drenados `STEP`, `FINISHED` y `FAULT`; **no** se acepta durante `RUNNING` o drenado automático. `LOAD` aceptado desde paso a paso/drenado interrumpe la sesión previa bajo la prioridad de `DEC-ARCH-008` sin comprometer efectos CPU de ese flanco. Solicitudes rechazadas no cambian estado ni suprimen el ciclo continuo.

Se precisan las fases de preparación sin cambiar la prioridad global. `prepare_done=1` significa **antes del flanco** que todos los valores de estado inicial (PC, RF, cero lógico de DMEM, pipeline y contador) ya quedaron coherentemente preparados en flancos anteriores, y que **no hay escrituras de Loader ni mantenimiento en ese flanco**.

Aunque `prepare_active` refleje el estado Moore previo al flanco, `PREPARING_RUN/STEP && prepare_done` es un flanco de **ciclo CPU**, no de acciones efectivas de preparación: el primer ciclo usa ese estado inicial preflanco, consume el `RUN` o `STEP` pendiente y deja `cycle_count=1`. Con `prepare_done=0` no hay ciclo. `PREPARING_READY && prepare_done` hace el commit completo de sesión e imagen **sin** ciclo CPU y llega a `READY`.

En particular, `load_ok` solo indica imagen recibida/validada y su tamaño queda privado del Loader; no publica aún `loaded_image_size_bytes`. El único write no nulo de ese tamaño sucede en el commit de `PREPARING_READY`, una vez preparada íntegramente la sesión. `PREPARING_RUN/STEP` reutilizan la imagen confirmada y no escriben su tamaño.

Así se conserva `RESET` > `LOAD` aceptado/preparación **efectiva** > ciclo CPU > `HOLD`, y una imagen parcial nunca es ejecutable.

Las transiciones (además de `reset` universal y `LOAD` aceptado desde los estados elegibles) quedan:

| Estado previo | Condición preflanco / evento | Estado siguiente |
|---|---|---|
| `NO_IMAGE` | `load_accept` | `LOADING` |
| `NO_IMAGE` | sin aceptación | `NO_IMAGE` |
| `LOADING` | `load_ok` | `PREPARING_READY` |
| `LOADING` | `load_fail` | `NO_IMAGE` |
| `LOADING` | en curso | `LOADING` |
| `PREPARING_READY` | `prepare_done` | `READY` (commit completo, sin CPU) |
| `PREPARING_READY` | en curso | `PREPARING_READY` |
| `READY` | `load_accept` | `LOADING` |
| `READY` | `step_accept` / `run_accept` | Resultado de **un** ciclo `STEP` / continuo en ese flanco |
| `READY` | sin aceptación | `READY` |
| `STEPPING` | `load_accept` | `LOADING` |
| `STEPPING` | `step_accept` / `run_accept` | Resultado de **un** ciclo `STEP` / continuo en ese flanco |
| `STEPPING` | sin aceptación | `STEPPING` |
| `RUNNING` | ciclo continuo | Resultado de **un** ciclo continuo en ese flanco |
| `HALT_DRAIN_AUTO` / `FAULT_DRAIN_AUTO` | ciclo automático | Drenado del mismo tipo o su estado final |
| `HALT_DRAIN_STEP` / `FAULT_DRAIN_STEP` | `load_accept` | `LOADING` |
| `HALT_DRAIN_STEP` / `FAULT_DRAIN_STEP` | `step_accept` / `run_accept` | Drenado `STEP` / AUTO del mismo tipo o su estado final |
| `HALT_DRAIN_STEP` / `FAULT_DRAIN_STEP` | sin aceptación | Retener estado |
| `FINISHED` / `FAULT` | `load_accept` | `LOADING` |
| `FINISHED` / `FAULT` | `step_accept` / `run_accept` | `PREPARING_STEP` / `PREPARING_RUN` |
| `FINISHED` / `FAULT` | sin aceptación | Retener estado |
| `PREPARING_RUN` / `PREPARING_STEP` | `prepare_done` | Resultado de **un** ciclo continuo / `STEP` en ese flanco |
| `PREPARING_RUN` / `PREPARING_STEP` | en curso | Retener estado |

Para cualquier fila «resultado de un ciclo», se aplica este orden:

1. `fault_confirm`: `FAULT` si `pipeline_empty_next`; si no, `FAULT_DRAIN_AUTO/STEP`.
2. `halt_confirm`: `FINISHED` si `pipeline_empty_next`; si no, `HALT_DRAIN_AUTO/STEP`.
3. Sin frontera terminal: `RUNNING` o `STEPPING` según el **origen del ciclo**.

Para ciclos de drenado ya terminales no se confirma otra frontera: `pipeline_empty_next` elige `FINISHED`/`FAULT` o conserva el drenado de su clase y origen; `RUN` aceptado durante drenado `STEP` lo convierte en AUTO si no se vacía.

`pipeline_empty_next` se obtiene del próximo estado de registros interetapa del acuerdo 42, sin evaluar salidas de la FSM siguiente ni crear un lazo; por ello `FINISHED`/`FAULT` surge en **el mismo flanco** que vacía el último `valid`, sin ciclo de drenado vacío.

`RUN`/`STEP` en `FINISHED`/`FAULT` inician una sesión **nueva y limpia** con la imagen confirmada, nunca reanudan el PC/pipeline terminal anterior; desde `FAULT` constituyen una vía de recuperación adicional expresamente aprobada, sin eliminar `reset` global como vía mínima obligatoria.

Las salidas Moore, exclusivamente función de `global_state` actual, son:

```text
loader_active     = state == LOADING
prepare_active    = state in {PREPARING_READY, PREPARING_RUN, PREPARING_STEP}
continuous_mode   = state in {RUNNING, HALT_DRAIN_AUTO, FAULT_DRAIN_AUTO}
step_mode         = state in {STEPPING, HALT_DRAIN_STEP, FAULT_DRAIN_STEP}
drain_mode        = state in {HALT_DRAIN_AUTO, HALT_DRAIN_STEP,
                              FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP}
halt_drain_active = state in {HALT_DRAIN_AUTO, HALT_DRAIN_STEP}
fault_drain_active= state in {FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP}
program_finished = state == FINISHED
fault_active     = fault_drain_active || (state == FAULT)
fault_terminal   = state == FAULT
fault_info_valid = fault_active
```

`prepare_active` anuncia modo, **no** es por sí misma un write-enable ni anula un ciclo válido con `prepare_done=1`. `drain_mode` se distingue de `drain_active` del Hazard Control; sobre estados alcanzables, ambos indican uno de los cuatro estados de drenado **con pipeline aún no vacío**. Los predicados equivalentes a la interfaz de los acuerdos 40–41 son:

```text
terminal_active = state in {HALT_DRAIN_AUTO, HALT_DRAIN_STEP,
                            FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP,
                            FINISHED, FAULT}
terminal_none   = !terminal_active
drain_active    = terminal_active && !pipeline_empty
```

En los cuatro estados DRAIN alcanzables `pipeline_empty=0`; en `FINISHED`/`FAULT` vale uno. El antiguo `terminal_kind` puede leerse **solo como alias combinacional** `NONE` en estados no terminales, `HALT` en `HALT_DRAIN_`*/`FINISHED` y `FAULT` en `FAULT_DRAIN_`*/`FAULT`, pero no existe su flip-flop ni un enable de escritura. Análogamente el origen automático es una propiedad de los estados `*_AUTO`, no un `drain_auto` registrado: sus viejas ecuaciones `drain_auto_write_enable=terminal_write_enable` y `drain_auto.next=cycle_from_continuous` quedan **sustituidas**, no se implementan junto a la FSM. `terminal_write_enable=fault_confirm||halt_confirm` queda, a lo sumo, como alias de evento combinacional sin registro de destino. `fault_capture_fire=fault_confirm` sí continúa capturando causa/PC globales preflanco.

`Cycle Authorization` separado genera:

```text
automatic_cycle_request = state in {RUNNING, HALT_DRAIN_AUTO, FAULT_DRAIN_AUTO}
command_cycle_request   = (state in {READY, STEPPING, HALT_DRAIN_STEP,
                                     FAULT_DRAIN_STEP}) && (run_accept || step_accept)
prepare_cycle_request   = (state in {PREPARING_RUN, PREPARING_STEP}) && prepare_done
cycle_request           = automatic_cycle_request || command_cycle_request
                          || prepare_cycle_request
cpu_cycle_fire          = !reset && !load_accept && cycle_request
```

Solo estados que pueden ejecutar una sesión **confirmada** solicitan ciclo; `PREPARING_RUN/STEP` reutilizan imagen válida y el contrato reforzado de `prepare_done` garantiza que su primer flanco es ejecutable y sin writes de preparación. Ni un stall, bubble, redirect o flush internos cancelan `cpu_cycle_fire`. `NO_IMAGE`, `LOADING`, `PREPARING_READY`, `FINISHED` y `FAULT` no solicitan ciclos por sí solos. El arbiter solo puede aceptar comandos legales según el estado y excluye `STEP`/`RUN` concurrentes por prioridad; un `LOAD` rechazado no inhibe `RUN`. El origen del ciclo es combinacional y solo tiene significado cuando `cpu_cycle_fire=1`:

```text
continuous_cycle = automatic_cycle_request
    || ((state in {READY, STEPPING, HALT_DRAIN_STEP, FAULT_DRAIN_STEP})
        && run_accept)
    || ((state == PREPARING_RUN) && prepare_done)
cycle_from_continuous = cpu_cycle_fire && continuous_cycle
```

Los demás ciclos autorizados proceden de `STEP` aceptado o de `PREPARING_STEP && prepare_done`. El origen continuo/`STEP` determina la modalidad de drenado tras confirmar frontera, sin agregar otro estado persistente.

```text
pipeline_empty =
    !IF/ID.valid && !ID/EX.valid && !EX/MEM.valid && !MEM/WB.valid
pipeline_empty_next =
    !IF/ID.next.valid && !ID/EX.next.valid
    && !EX/MEM.next.valid && !MEM/WB.next.valid

image_valid = (loaded_image_size_bytes != 0)
cycle_counter_increment = cpu_cycle_fire
```

`fetch_fault_valid` no participa en el vaciado. `loaded_image_size_bytes` es la fuente persistente única de imagen confirmada: `reset` y `LOAD` aceptado lo ponen en cero; una carga fallida lo deja allí; solo el commit de `PREPARING_READY` lo establece al tamaño validado, y en cualquier otro caso se retiene. `fault_cause[2:0]` y `fault_pc[31:0]` siguen siendo registros independientes capturados solo con `fault_confirm`; `fault_info_valid` se deriva de los estados fault, sin registro extra y sin interpretación de bits residuales fuera de ellos. `cycle_count` queda en cero **antes** del flanco de `prepare_done` de una nueva sesión y se incrementa a uno si ese flanco emite el primer ciclo CPU. **Revisado por AUD-005:** `cycle_count[63:0]` es unsigned e incrementa módulo `2^64` por `cpu_cycle_fire`, sin fault, cambio de `global_state`, detención ni flag adicional; el formato UART permanece pendiente conforme a la revisión de `DEC-SYS-006` del 2026-09-26.

El Loader y `Session Preparation` mantienen progreso privado (índices, palabras parciales, contadores y flags) y notifican `load_ok/load_fail` o `prepare_done`, sin agregar subestados de recepción o clear a la FSM global. Estado global persistente: `global_state`, `fault_cause`, `fault_pc`, `loaded_image_size_bytes` y `cycle_count`, más estado privado de esos módulos; `run_active`, `drain_auto`, `terminal_kind`, `image_valid`, `fault_valid`, `finished`, `fault` y modos de drenado **no** son registros globales independientes. El cuadragésimo quinto acuerdo audita después las coincidencias restantes: en ese momento `DEC-ARCH-003` aún esperaba su matriz final de verificación/cierre; el formato externo Debug/UART continúa en sus decisiones respectivas.

#### Acuerdo parcial aprobado — auditoría de coincidencias e integración global

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se auditan las **coincidencias funcionales globales e interacciones entre hazards** que permanecían abiertas tras los acuerdos 40–44. La composición de `RESET`/`LOAD`/preparación, FSM de 14 estados, `Cycle Authorization`, fronteras por antigüedad, nueve acciones mutuamente excluyentes, actualización de PC/registros interetapa y gating de efectos determina unívocamente estos casos. La auditoría **no añade** una prioridad general, estado, acción, selector, stall, bypass o campo de pipeline, ni altera las ecuaciones aprobadas.

| Coincidencia | Política ya fijada que la resuelve |
|---|---|
| `RESET`, `LOAD` aceptado, preparación efectiva y ciclo CPU | `RESET` domina todo; `LOAD` aceptado y escrituras efectivas de preparación dominan efectos CPU. Un `LOAD` **rechazado** no interrumpe el ciclo continuo. Entre comandos aceptables rige `RESET` > `LOAD` > `STEP` > `RUN`. |
| Loader y nueva imagen | `load_ok` valida pero no publica imagen. `PREPARING_READY && prepare_done` publica sesión e imagen coherentes **sin** ciclo CPU; fallo deja tamaño confirmado cero. |
| Reutilización de imagen y primer ciclo | `RUN`/`STEP` desde `FINISHED` o `FAULT` inician **nueva** sesión por `PREPARING_RUN`/`STEP`. Si `prepare_done=1`, estado inicial completo antes del flanco y sin escrituras de mantenimiento concurrentes, ese flanco autoriza el primer ciclo y consume el `RUN`/`STEP` pendiente. |
| Ejecución paso a paso y `LOAD` | `LOAD` aceptado en `STEPPING` o drenado `STEP` domina el flanco, inhibe CPU y abandona la sesión previa. `LOAD` rechazado en `RUNNING` o drenado AUTO no inhibe ciclos. |
| Cambio de drenado `STEP`→AUTO | `RUN` aceptado durante drenado `STEP` autoriza el ciclo actual y conserva modalidad AUTO si quedan anteriores; `STEP` aceptado produce solo un ciclo, incluso con stall. |
| Confirmación terminal y vaciado | `halt_confirm`/`fault_confirm` y `pipeline_empty_next` eligen directamente `FINISHED`/`FAULT` cuando el último `valid_next` baja a cero, sin ciclo vacío adicional; con anteriores eligen DRAIN AUTO/`STEP` según `cycle_from_continuous`. |
| Fronteras EX, ID e IF excepcional | Dentro de la instrucción EX, fault propio precede a `halt` y redirect; entre instrucciones distintas prevalece la más antigua EX→ID→IF excepcional. Redirect/`halt` EX descartan candidatos jóvenes; fault ID permite avanzar la EX anterior. |
| `load-use` y frontera | La frontera anterior prevalece sobre stalls solo de trabajo joven descartado; el stall necesario entre anteriores supervivientes se preserva. Fault IF excepcional con `load-use` retiene íntegro al consumidor `IF/ID`, inserta bubble y deja avanzar el load anterior sin capturar el fetch causante. |
| Drenado terminal | No se confirman fronteras nuevas ni se admiten fetches; se selecciona `act_drain_load_use` o `act_drain_advance` para anteriores supervivientes, cada una solo en ciclo CPU efectivo. |
| Efectos `MEM/WB` y cómputo de ciclos | Store MEM y writeback WB anteriores pueden comprometerse en el mismo flanco que confirma una frontera joven; `RESET`, `LOAD` aceptado o preparación efectiva los suprimen. `cycle_count` incrementa exactamente una vez por `cpu_cycle_fire`, incluidos stalls, redirects, confirmaciones y drenado. |
| IF y MEM simultáneos | IMEM y DMEM son recursos lógicos independientes; fetch y load/store del mismo ciclo no originan un stall estructural artificial. |

Para cada ciclo **procesable** sin frontera terminal previa, el `Pipeline Hazard Control` selecciona exactamente **una** de las siete acciones `act_ex_fault`, `act_halt`, `act_redirect`, `act_id_fault`, `act_if_fault_exception`, `act_load_use` o `act_normal`. En drenado activo selecciona exactamente una de `act_drain_load_use` o `act_drain_advance`. En todo momento vale `$onehot0` de las nueve; con `cpu_cycle_fire=0` no se aplica ninguna. El acuerdo 42 sigue siendo la **única realización normal** de próximo estado de PC y cuatro registros interetapa para esas acciones, siempre desde las entradas previas al flanco. Una frontera confirmada en EX/ID/IF no invalida retrospectivamente una instrucción anterior ya en MEM o WB.

La integración del control global conserva una dependencia combinacional **acíclica**:

```text
global_state actual + comandos aceptados
    → Cycle Authorization → cpu_cycle_fire
    → confirmaciones + única acción de Pipeline Hazard Control
    → PC/latches.next (desde entradas preflanco)
    → pipeline_empty_next (desde los cuatro valid_next)
    → FSM.next_state
```

`FSM.next_state` no realimenta `cpu_cycle_fire` ni las acciones **del mismo ciclo**. `prepare_done` garantiza antes del flanco que la preparación efectiva terminó si autoriza el primer ciclo de `PREPARING_RUN`/`STEP`; `PREPARING_READY` no solicita ciclo. Los estados DRAIN alcanzables contienen trabajo anterior; el paso a `FINISHED`/`FAULT` ocurre en el flanco que vacía su último `valid`, sin ciclo final artificial.

El detector `load-use` y la `Forwarding Unit` mantienen sus ecuaciones. Cada fuente usada selecciona al productor más reciente con dato disponible; un load coincidente y más reciente en `EX/MEM` sin dato disponible **bloquea** el fallback hacia `MEM/WB` anterior o hacia la base `ID/EX` y espera el avance autorizado. `forward_a_sel`, `forward_b_sel`, `result_sel`, `target_sel` y `wb_value_sel` son selectores locales combinacionales: salidas residuales en `HOLD`, etapas inválidas o trabajo descartado no autorizan captura/commit arquitectónico. Cada efecto CPU sigue necesitando `cpu_cycle_fire`, validez de su etapa y control específico; las reglas particulares de confirmación y prioridades del propio evento siguen vigentes.

El placeholder semántico `ID/EX.control` **no requiere una subdecisión adicional de empaquetado**: las seis categorías `alu_op`, `alu_src`, `result_sel`, `flow_op`, `mem_op` y `reg_write` ya tienen semántica, codificación y transporte por etapas aprobados. Materializarlas como señales separadas, estructura o bundle equivalente es detalle de implementación RTL, sin alterar campos físicos ni efectos. La representación **externa** Debug/UART de estados, controles y registros interetapa permanece en `DEC-ARCH-009` y decisiones de protocolo, fuera del cierre de esta política de hazards.

La auditoría no identifica coincidencias funcionales sin política definida. **Quedan resueltas las coincidencias globales y la integración funcional antes declaradas abiertas en `DEC-ARCH-003`.** En esta etapa aún quedaba la matriz final de verificación y acto de cierre del cuadragésimo sexto acuerdo; no se infiere de esta auditoría que ya exista RTL verificado.

#### Acuerdo parcial aprobado — matriz final de verificación y cierre de la política de hazards

**Fecha:** 2026-09-25

**Revisión de vigencia:** matriz revisada por el acuerdo 47 el 2026-09-26; las filas e invariantes siguientes expresan el contrato vigente. La versión original se conserva debajo como historia.

La matriz consolida los acuerdos 1–45 y la revisión explícita del acuerdo 47. **No introduce comportamiento nuevo**: cada fila es un contrato arquitectónico ya fijado y un criterio para verificar después su implementación RTL.

| Área de `DEC-ARCH-003` | Cierre y criterio de verificación |
|---|---|
| Forwarding `EX/MEM` y `MEM/WB` → EX; prioridad, disponibilidad y fuentes usadas | Acuerdos 1–3, 9–10, 32 y 38–39: comprobar `rs1`/`rs2` independientemente, productor reciente disponible, `rd!=x0`, fuentes efectivamente usadas y bloqueo de un `MEM/WB` obsoleto ante load reciente coincidente sin dato. |
| `load-use` y stall entre supervivientes | Acuerdos 2, 4, 18–21, 29–32 y 41–42, revisados por el 47: retener PC/`IF/ID`, insertar bubble `ID/EX`, dejar progresar anteriores y aplicar stall solo si productor y consumidor sobreviven a la frontera. |
| Stores, WB→ID y forwarding posterior | Acuerdos 5, 7, 9–10, 23, 25, 32, 39 y 43, con `DEC-ARCH-007`: comprobar dirección en EX, `store_data` transportado por `EX/MEM`, bypass de WB solo para escritura elegible y prioridad posterior del productor más reciente en EX. |
| Cuatro registros interetapa, controles, `Result MUX`, `Target MUX` y `WB Value MUX` | Acuerdos 7, 11–14, 19–25, 29, 33–34, 37–38 y 42: campos/controles necesarios llegan a la etapa consumidora; `valid=0` deja inertes los residuos. Se comprueban selectores, enlace y selección de datos sin imponer empaquetado físico único de `ID/EX.control`. |
| Branches, `jal` y `jalr`; redirect | Acuerdos 6–8, 16–17, 22–27, 30–31 y 40–42: resolución en EX, target y enlace correctos, fault propio antes de redirect y descarte del camino joven al aplicar una redirección válida. |
| `halt`, detección de fetch IF y faults confirmados `ID/EX` y metadatos | Acuerdos 28–31, 35–36 y 40–44, revisados por el 47: confirmar solo candidatos elegibles del camino correcto, descartar causante de fault y jóvenes, retener PC y conservar `fault_cause`/`fault_pc` mientras drenan anteriores; `halt` no llega válido a `EX/MEM`. |
| Antigüedad, ocho acciones, enables e invalidaciones | Acuerdos 30–31 y 40–45, revisados por el 47: frontera EX → ID; IF solo detecta y transporta candidatos conforme al acuerdo 47; `act_ex_fault`, `act_halt`, `act_redirect`, `act_id_fault`, `act_load_use`, `act_normal`, `act_drain_load_use` y `act_drain_advance` excluyentes, aplicadas a PC y registros interetapa con valores preflanco y sin ciclo adicional de `HOLD`. |
| Fetch candidato durante load-use | Acuerdo 47: solo `act_load_use`, sin confirmación ni captura del candidato; PC retenido permite redetectarlo, capturarlo después y resolverlo en ID. Probar consumidor branch/jalr y load/store con fault propio antes del fetch joven. |
| Gating RF/DMEM/fault/contador; `cpu_cycle_fire` | Acuerdos 36, 40 y 42–45, revisados por el 47: ningún efecto CPU sin ciclo, validez y control local; el writeback/store anterior a frontera joven completa una sola vez; el contador incrementa también en stall, redirect, frontera y drenado. |
| FSM de 14 estados, autorización y comandos | Acuerdos 36 y 40–45, con revisión expresa del 44: `global_state` es la fuente registrada de fases terminales AUTO/`STEP`; `RESET` > `LOAD` aceptado > preparación efectiva > ciclo CPU > `HOLD`, `STEP` > `RUN` entre comandos aceptados, solicitud de `LOAD` rechazada sin inhibir `RUN`. `PREPARING_READY && prepare_done` solo confirma imagen/sesión; `PREPARING_RUN/STEP && prepare_done` ejecuta primer ciclo solo con preparación preflanco completa. |
| Drenado y terminación | Acuerdos 28–31 y 36, 40–45: anteriores progresan en AUTO o por un `STEP` aceptado por ciclo; `pipeline_empty_next=1` con confirmación/vaciado final lleva a `FINISHED` o `FAULT` en ese flanco sin ciclo vacío. |
| Coincidencias globales e integración | Acuerdo 45: auditar `RESET`/`LOAD`/preparación, comandos concurrentes, fronteras/`load-use`, forwarding/selectores durante `HOLD` y drenado, commits anteriores y fetch IF + acceso MEM simultáneos sobre IMEM/DMEM independientes, sin hazard estructural artificial. |

Los invariantes conjuntos de aceptación son:

```text
cpu_cycle_fire=0                        → sin avance ni efecto CPU de la sesión
cpu_cycle_fire=1 && terminal_none      → exactamente una de seis acciones no terminales
cpu_cycle_fire=1 && drain_active       → exactamente una de dos acciones de drenado
en todo momento                        → $onehot0 de las ocho acciones
frontera con pipeline_empty_next=1     → FINISHED si halt; FAULT si fault
```

Una instrucción válida completa normalmente, causa una frontera (sin efectos propios prohibidos) o es más joven y queda descartada; las anteriores supervivientes conservan efectos elegibles incluso en el flanco de confirmación y durante drenado. `Command Arbiter` selecciona el comando aceptado, `Cycle Authorization` deriva `cpu_cycle_fire`, `Pipeline Hazard Control` escoge una acción y las ecuaciones de PC/registros interetapa/datapath efectúan la transición y los commits. La FSM decide sus estados y transiciones a partir de `pipeline_empty_next`, pero no ejecuta directamente acciones del datapath ni realimenta `next_state` hacia la autorización del mismo flanco. `terminal_none` y `drain_active` son predicados derivados del estado actual conforme al acuerdo 44, no registros terminales paralelos.

**Cierre:** no resta política de forwarding, hazard, prioridad, stall, flush, autorización o próximo estado del pipeline por decidir dentro de `DEC-ARCH-003`. El empaquetado de `ID/EX.control` es detalle de implementación RTL; la construcción y verificación física del CPU quedan por realizar y esta matriz no afirma que ya hayan pasado pruebas de hardware. La representación externa del estado y pipeline por Debug/UART permanece en `DEC-ARCH-009` y las decisiones de protocolo. Se **aprueba `DEC-ARCH-003`** con 47 acuerdos; el cierre original de 46 acuerdos queda revisado por el 47, preservando la revisión de representación del acuerdo 44.

<details>
<summary>Historia: versión original del acuerdo 46, sustituida en estos puntos por el acuerdo 47</summary>

**Fecha:** 2026-09-25

La matriz consolida los acuerdos 1–45 y la auditoría de coincidencias del acuerdo 45. **No introduce comportamiento nuevo**: cada fila es un contrato arquitectónico ya fijado y un criterio para verificar después su implementación RTL.

| Área de `DEC-ARCH-003` | Cierre y criterio de verificación |
|---|---|
| Forwarding `EX/MEM` y `MEM/WB` → EX; prioridad, disponibilidad y fuentes usadas | Acuerdos 1–3, 9–10, 32 y 38–39: comprobar `rs1`/`rs2` independientemente, productor reciente disponible, `rd!=x0`, fuentes efectivamente usadas y bloqueo de un `MEM/WB` obsoleto ante load reciente coincidente sin dato. |
| `load-use` y stall entre supervivientes | Acuerdos 2, 4, 18–21, 29–32 y 41–42: retener PC/`IF/ID`, insertar bubble `ID/EX`, dejar progresar anteriores y aplicar stall solo si productor y consumidor sobreviven a la frontera. |
| Stores, WB→ID y forwarding posterior | Acuerdos 5, 7, 9–10, 23, 25, 32, 39 y 43, con `DEC-ARCH-007`: comprobar dirección en EX, `store_data` transportado por `EX/MEM`, bypass de WB solo para escritura elegible y prioridad posterior del productor más reciente en EX. |
| Cuatro registros interetapa, controles, `Result MUX`, `Target MUX` y `WB Value MUX` | Acuerdos 7, 11–14, 19–25, 29, 33–34, 37–38 y 42: campos/controles necesarios llegan a la etapa consumidora; `valid=0` deja inertes los residuos. Se comprueban selectores, enlace y selección de datos sin imponer empaquetado físico único de `ID/EX.control`. |
| Branches, `jal` y `jalr`; redirect | Acuerdos 6–8, 16–17, 22–27, 30–31 y 40–42: resolución en EX, target y enlace correctos, fault propio antes de redirect y descarte del camino joven al aplicar una redirección válida. |
| `halt`, faults `IF/ID`/EX y metadatos | Acuerdos 28–31, 35–36 y 40–44: confirmar solo candidatos elegibles del camino correcto, descartar causante de fault y jóvenes, retener PC y conservar `fault_cause`/`fault_pc` mientras drenan anteriores; `halt` no llega válido a `EX/MEM`. |
| Antigüedad, nueve acciones, enables e invalidaciones | Acuerdos 30–31 y 40–45: frontera EX → ID → IF excepcional; `act_ex_fault`, `act_halt`, `act_redirect`, `act_id_fault`, `act_if_fault_exception`, `act_load_use`, `act_normal`, `act_drain_load_use` y `act_drain_advance` excluyentes, aplicadas a PC y registros interetapa con valores preflanco y sin ciclo adicional de `HOLD`. |
| Gating RF/DMEM/fault/contador; `cpu_cycle_fire` | Acuerdos 36, 40 y 42–45: ningún efecto CPU sin ciclo, validez y control local; el writeback/store anterior a frontera joven completa una sola vez; el contador incrementa también en stall, redirect, frontera y drenado. |
| FSM de 14 estados, autorización y comandos | Acuerdos 36 y 40–45, con revisión expresa del 44: `global_state` es la fuente registrada de fases terminales AUTO/`STEP`; `RESET` > `LOAD` aceptado > preparación efectiva > ciclo CPU > `HOLD`, `STEP` > `RUN` entre comandos aceptados, solicitud de `LOAD` rechazada sin inhibir `RUN`. `PREPARING_READY && prepare_done` solo confirma imagen/sesión; `PREPARING_RUN/STEP && prepare_done` ejecuta primer ciclo solo con preparación preflanco completa. |
| Drenado y terminación | Acuerdos 28–31 y 36, 40–45: anteriores progresan en AUTO o por un `STEP` aceptado por ciclo; `pipeline_empty_next=1` con confirmación/vaciado final lleva a `FINISHED` o `FAULT` en ese flanco sin ciclo vacío. |
| Coincidencias globales e integración | Acuerdo 45: auditar `RESET`/`LOAD`/preparación, comandos concurrentes, fronteras/`load-use`, forwarding/selectores durante `HOLD` y drenado, commits anteriores y fetch IF + acceso MEM simultáneos sobre IMEM/DMEM independientes, sin hazard estructural artificial. |

Los invariantes conjuntos de aceptación son:

```text
cpu_cycle_fire=0                        → sin avance ni efecto CPU de la sesión
cpu_cycle_fire=1 && terminal_none      → exactamente una de siete acciones no terminales
cpu_cycle_fire=1 && drain_active       → exactamente una de dos acciones de drenado
en todo momento                        → $onehot0 de las nueve acciones
frontera con pipeline_empty_next=1     → FINISHED si halt; FAULT si fault
```

Una instrucción válida completa normalmente, causa una frontera (sin efectos propios prohibidos) o es más joven y queda descartada; las anteriores supervivientes conservan efectos elegibles incluso en el flanco de confirmación y durante drenado. `Command Arbiter` selecciona el comando aceptado, `Cycle Authorization` deriva `cpu_cycle_fire`, `Pipeline Hazard Control` escoge una acción y las ecuaciones de PC/registros interetapa/datapath efectúan la transición y los commits. La FSM decide sus estados y transiciones a partir de `pipeline_empty_next`, pero no ejecuta directamente acciones del datapath ni realimenta `next_state` hacia la autorización del mismo flanco. `terminal_none` y `drain_active` son predicados derivados del estado actual conforme al acuerdo 44, no registros terminales paralelos.

**Cierre:** no resta política de forwarding, hazard, prioridad, stall, flush, autorización o próximo estado del pipeline por decidir dentro de `DEC-ARCH-003`. El empaquetado de `ID/EX.control` es detalle de implementación RTL; la construcción y verificación física del CPU quedan por realizar y esta matriz no afirma que ya hayan pasado pruebas de hardware. La representación externa del estado y pipeline por Debug/UART permanece en `DEC-ARCH-009` y las decisiones de protocolo. Se **aprueba `DEC-ARCH-003`** con 46 acuerdos, conservando las revisiones históricas expresas del acuerdo 44.

</details>

#### Acuerdo 47 aprobado — confirmación de todo fetch fault en ID y revisión de AUD-001

**Fecha:** 2026-09-26

**Estado:** Aprobado por revisión explícita de DEC-ARCH-003.

**Motivo y alcance de la revisión:** AUD-001 demostró que confirmar un fetch más joven mientras su consumidor anterior permanece en ID puede impedir el redirect o el fault propio posterior de esa instrucción. Se sustituye esa política: **IF solo detecta candidatos; todo fetch fault se confirma arquitectónicamente en ID**, después de transportarse por `IF/ID`. Quedan revisados los acuerdos anteriores en sus referencias a esa confirmación anticipada, al número de acciones, a las ecuaciones dependientes y a los casos de verificación. La matriz del acuerdo 46 se actualiza conforme a este acuerdo. El texto anterior se conserva como historia expresamente revisada, no como una alternativa implementable.

**Política obligatoria:**

- Se elimina la antigua ruta de confirmación desde IF. No existe señal de confirmación ni acción de fault de esa etapa.
- Si coinciden `load_use_stall` e `if_fetch_fault_candidate`, **sin frontera anterior EX/ID prevaleciente**, se ejecuta solamente `act_load_use`: PC e `IF/ID` retienen íntegros sus valores, `ID/EX` recibe bubble y `EX/MEM` y `MEM/WB` capturan sus entradas anteriores. No se captura el candidato, no se publican causa/PC globales ni se inicia drenado por él.
- Mientras se retiene PC, el candidato se vuelve a detectar combinacionalmente en la misma dirección, sin registro adicional. En el siguiente avance normal se captura por la ruta **IF→`IF/ID`→ID**, con `valid=0`, `fetch_fault_valid=1`, `pc=PC` y la causa seleccionada. Si antes prevalece un redirect, fault o halt anterior, se descarta el candidato; no se exige capturar trabajo wrong-path.
- Cuando el candidato llega a ID, la instrucción consumidora anterior ya puede resolver su control o su fault en EX. La frontera EX prevalece y descarta el candidato joven; solo sin ella ID puede confirmar el fetch fault. `fault_pc` procede siempre de **`IF/ID.pc`** para fetch o ilegal ID; para faults propios EX procede de **`ID/EX.pc`**. Nunca se captura el PC global de IF como fuente directa de una confirmación de fetch.
- El Hazard Control tiene **ocho acciones: seis no terminales y dos de drenado**. No se agregan registros, campos de pipeline, selectores ni estados/FSM. Los cinco campos de `IF/ID`, las demás etapas, la FSM global de 14 estados, sus comandos, la autorización de ciclos, forwarding, códigos de causa, memorias y políticas externas conservan sus contratos.

**Confirmaciones y arbitraje vigentes.** Se mantienen los candidatos de los acuerdos 37–40, la selección de causa dentro de una operación y `ex_frontier`:

```text
ex_frontier = ex_fault_candidate || ex_halt_event || ex_redirect_event

ex_fault_confirm = cpu_cycle_fire && terminal_none && ex_fault_candidate
halt_confirm = cpu_cycle_fire && terminal_none
               && !ex_fault_candidate && ex_halt_candidate
redirect_apply = cpu_cycle_fire && terminal_none
                 && !ex_fault_candidate && !ex_halt_candidate
                 && redirect_requested
ex_frontier_selected = ex_fault_confirm || halt_confirm || redirect_apply

id_fault_candidate = (IF/ID.valid && !decode_legal)
                     || (!IF/ID.valid && IF/ID.fetch_fault_valid)
id_fault_confirm = cpu_cycle_fire && terminal_none
                   && !ex_frontier_selected && id_fault_candidate
fault_confirm = ex_fault_confirm || id_fault_confirm

load_use_apply = cpu_cycle_fire && terminal_none
                 && !ex_frontier_selected && !id_fault_confirm
                 && load_use_stall
normal_advance = cpu_cycle_fire && terminal_none
                 && !ex_frontier_selected && !id_fault_confirm
                 && !load_use_apply

drain_cycle = cpu_cycle_fire && drain_active
drain_load_use = drain_cycle && load_use_stall
drain_advance = drain_cycle && !load_use_stall

act_ex_fault       = ex_fault_confirm
act_halt           = halt_confirm
act_redirect       = redirect_apply
act_id_fault       = id_fault_confirm
act_load_use       = load_use_apply
act_normal         = normal_advance
act_drain_load_use = drain_load_use
act_drain_advance  = drain_advance

pipeline_action = act_ex_fault || act_halt || act_redirect
                  || act_id_fault || act_load_use || act_normal
                  || act_drain_load_use || act_drain_advance

$onehot0({act_ex_fault, act_halt, act_redirect, act_id_fault,
          act_load_use, act_normal, act_drain_load_use, act_drain_advance})
```

Durante `cpu_cycle_fire && terminal_none`, `ex_frontier_selected` equivale al `ex_frontier` combinacional; por tanto ID conserva la prioridad EX→ID. **IF no constituye una tercera frontera confirmante.** El candidato de IF no aparece en las ecuaciones de selección de acciones: solo decide qué se captura cuando hay `act_normal`. No se transforma un fault joven en una frontera por la existencia de un stall.

**Próximo estado vigente de PC y registros interetapa.** Todas las fuentes son preflanco; `reset`, `LOAD` aceptado y preparación efectiva conservan su prioridad. Estas ecuaciones sustituyen las correspondientes del acuerdo 42:

```text
pc_write_enable = act_normal || act_redirect
next_pc_sel = act_redirect
act_normal   → PC.next = PC + 4
act_redirect → PC.next = redirect_target
resto        → PC.next = PC

ifid_capture_if = act_normal
ifid_hold = act_load_use || act_drain_load_use
ifid_invalidate = act_redirect || act_halt || act_ex_fault
                  || act_id_fault || act_drain_advance

idex_capture_id = act_normal || act_drain_advance
idex_bubble = act_load_use || act_redirect || act_halt
              || act_ex_fault || act_id_fault || act_drain_load_use

exmem_capture_ex = act_normal || act_load_use || act_redirect
                   || act_id_fault || act_drain_load_use || act_drain_advance
exmem_invalidate = act_halt || act_ex_fault
memwb_capture_mem = pipeline_action
```

| Acción vigente | PC | `IF/ID.next` | `ID/EX.next` | `EX/MEM.next` | `MEM/WB.next` |
|---|---|---|---|---|---|
| `act_normal` | PC+4 | Capturar IF: instrucción o candidato | Capturar ID | Capturar EX | Capturar MEM |
| `act_load_use` | Retener | Retener los cinco campos | Bubble | Capturar EX | Capturar MEM |
| `act_redirect` | Target | Invalidar ambos flags | Bubble | Capturar EX válida | Capturar MEM |
| `act_halt` | Retener | Invalidar ambos flags | Bubble | Invalidar | Capturar MEM |
| `act_ex_fault` | Retener | Invalidar ambos flags | Bubble | Invalidar | Capturar MEM |
| `act_id_fault` | Retener | Invalidar ambos flags | Bubble | Capturar EX anterior | Capturar MEM |
| `act_drain_load_use` | Retener | Retener los cinco campos | Bubble | Capturar EX | Capturar MEM |
| `act_drain_advance` | Retener | Invalidar ambos flags | Capturar ID | Capturar EX | Capturar MEM |

Con `act_normal`, `IF/ID` captura `valid=1, fetch_fault_valid=0, instruction=if_instruction` si el fetch es válido, o `valid=0, fetch_fault_valid=1, instruction=32'b0` si hay candidato; siempre captura `pc=PC`. La causa es `if_fetch_fault_cause` para candidato y `3'b000` determinista sin significado de fault cuando el flag es cero. Retener conserva **los cinco campos**; invalidar limpia `valid` y `fetch_fault_valid`, permitiendo residuos de PC/instrucción/causa. Con `pipeline_action=0` y sin acción global superior, PC y los cuatro registros interetapa completos se retienen.

La captura `ID/EX` conserva el contrato del acuerdo 42: validez, PC, instrucción, índices, inmediato, valores posbypass WB→ID y las seis categorías de control desde ID preflanco. Bubble solo exige `valid_next=0`. `EX/MEM` toma validez/identidad/control de `ID/EX` previo, `ex_result` seleccionado entre ALU/inmediato/link y `store_data=rs2_effective`; invalidación exige `valid_next=0`. `MEM/WB` toma `EX/MEM` previo y `wb_value=is_load(EX/MEM.mem_op)?load_value:EX/MEM.ex_result`. Una entrada nueva invalidada no cancela efectos de la antigua MEM o WB.

Las dos acciones de drenado permanecen por contrato, sin simplificar ni añadir una FSM. Bajo la nueva política, las confirmaciones EX/ID invalidan `IF/ID`; ya no se inicia drenado con un consumidor válido retenido allí por un fetch más joven. Esto no autoriza cambiar las ecuaciones de drenado ni sus condiciones de autorización.

**Captura global y efectos.** Se revisa la ecuación del acuerdo 43:

```text
fault_capture_fire = fault_confirm = act_ex_fault || act_id_fault

if (ex_fault_confirm):
    fault_cause_in = ex_fault_cause
    fault_pc_in = ID/EX.pc
else if (id_fault_confirm):
    fault_cause_in = id_fault_cause
    fault_pc_in = IF/ID.pc

if (fault_capture_fire):
    fault_cause.next = fault_cause_in
    fault_pc.next = fault_pc_in
else:
    fault_cause.next = fault_cause
    fault_pc.next = fault_pc
```

Para fetch confirmado en ID, `id_fault_cause` copia `IF/ID.fetch_fault_cause` sin traducción; ilegal ID selecciona `010`. Las siete causas y su prioridad dentro de una operación se conservan. `rf_write_fire`, `dmem_store_fire`, `dmem_metadata_write_fire`, `redirect_commit`, `halt_commit` y `cycle_counter_increment=cpu_cycle_fire` no cambian. La FSM del acuerdo 44 consume las confirmaciones y `pipeline_empty_next` existentes: solo EX o ID pueden originar `FAULT`/DRAIN, y el vaciado sigue sin ciclo extra. `HOLD` no captura ni confirma candidatos.

**Matriz adicional obligatoria que revisa el acuerdo 46:**

| Caso | Evidencia exigida |
|---|---|
| Load-use con candidato IF y sin frontera EX/ID | Únicamente `act_load_use`; PC/`IF/ID` estables, bubble `ID/EX`, progreso `EX/MEM`/WB; `fault_confirm`=0 y metadatos estables |
| Stall terminado, candidato todavía en el mismo PC | `act_normal` captura candidato en `IF/ID` mientras el consumidor anterior pasa a EX; aún no hay fault por ese candidato |
| Consumidor branch tomado o jalr válido | En EX aplica redirect y descarta el candidato joven de `IF/ID`, incluido su flag, sin `FAULT` por él |
| Consumidor branch no tomado o ALU ordinaria | Sin frontera EX, candidato en ID confirma con causa registrada y `fault_pc`=`IF/ID.pc`; la EX anterior progresa |
| Consumidor load/store con fault propio, o jalr con target desalineado | `ex_fault_confirm` prevalece sobre candidato de fetch ID; la causante no entra válida a `EX/MEM` y sus efectos quedan inhibidos |
| Load productor con fault en EX | `act_ex_fault` descarta consumidor y candidato joven; no aplicar el stall de la dependencia descartada |
| Candidato frente a halt EX anterior | `act_halt` descarta candidato y termina por `FINISHED` tras drenado, no `FAULT` |
| `RUN`, `STEP` y `HOLD` intercalados | Un ciclo por `STEP`, incluido el stall; `HOLD` preserva cinco campos/PC/metadatos; redetección combinacional no confirma ni cuenta ciclos |
| Reset o `LOAD` aceptado frente a candidato retenido/registrado | La prioridad global invalida el candidato y suprime efectos de la sesión previa |
| Cobertura de acciones | Exactamente una de seis acciones no terminales o una de dos de drenado por ciclo procesable; $onehot0 de ocho siempre; cero acciones en `HOLD` o terminal vacío |

Contraejemplos de AUD-001 convertidos en regresión: con imagen de 8 bytes y DMEM inicial cero, `lw x1,0(x0); beq x1,x0,-4` debe repetir el loop sin confirmar el fetch especulativo en PC=8. Con `lw x1,0(x0); sw x1,2(x0)`, debe confirmarse el store desalineado con `fault_cause=110`, `fault_pc=4`, sin writes de datos ni metadatos; el fetch PC=8 queda descartado. Repetir cambiando consumidor por un load inválido, jalr alineado/desalineado, branch no tomado y ALU dependiente para contrastar descarte y confirmación ID legítima.

**Cierre de la revisión:** DEC-ARCH-003 permanece Aprobada, ahora con **47 acuerdos**. Este acuerdo resuelve documentalmente AUD-001 y prevalece sobre todas las referencias históricas incompatibles, incluida la matriz 46. La implementación y la verificación RTL siguen futuras; no se cambian otras políticas arquitectónicas ni se declaran resueltos los demás hallazgos de la auditoría.

**Requisitos afectados:** `REQ-DOC-008`, `REQ-CPU-004` a `REQ-CPU-011`, `REQ-CPU-015`, `REQ-CPU-017`, `REQ-MEM-005`, `REQ-MEM-006`, `REQ-MEM-016`, `REQ-MEM-017`, `REQ-MEM-020`, `REQ-MEM-025`, `REQ-MEM-030`, `REQ-EXEC-001` a `REQ-EXEC-005`, `REQ-EXEC-009`, `REQ-EXEC-013`, `REQ-EXEC-015` a `REQ-EXEC-018`, `REQ-HAZ-001` a `REQ-HAZ-010`, especialmente `REQ-HAZ-002` a `REQ-HAZ-006`, `REQ-HAZ-007` a `REQ-HAZ-009`, `REQ-DBG-006` a `REQ-DBG-009`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-016` y `REQ-DBG-017`; los metadatos CPU afectan también `REQ-MEM-029`.

**Reemplaza / Reemplazada por:** No aplica; las revisiones entre acuerdos se conservan dentro de este ADR.

---
