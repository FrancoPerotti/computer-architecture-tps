### DEC-ARCH-004 — Instrucciones inválidas y accesos desalineados

**Contrato vigente de consulta:** [faults_and_termination](../architecture/session/faults_and_termination.md), [stage_id](../architecture/cpu/stage_id.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** CPU / Semántica fuera del subconjunto

**Fecha de aprobación:** 2026-09-24

**Contexto:** La consigna no determina el tratamiento de palabras no soportadas, accesos desalineados ni destinos de control inválidos. La organización byte-addressed, los espacios independientes y los faults fuera de rango aprobados en `DEC-ARCH-001` requieren una política precisa, verificable y consistente con la resolución de control en EX, el descarte `wrong-path` y los ciclos efectivos de `DEC-ARCH-002` y `DEC-ARCH-008`.

**Opciones consideradas:**

1. Aceptar implícitamente codificaciones adicionales, o validar estrictamente el subconjunto RV32I y `halt`.
2. Admitir accesos desalineados mediante reconstrucción y múltiples accesos, o exigir alineación natural estricta.
3. Convertir toda detección combinacional en fault o confirmar solo el candidato válido del camino correcto que prevalece por antigüedad.
4. Vaciar todo el pipeline ante fault o drenar únicamente las instrucciones anteriores y descartar la causante y posteriores.
5. Confundir fault con finalización normal o conservar causa y PC observables hasta `FAULT`, con `reset` global como recuperación mínima.

**Revisión por AUD-001:** Las referencias de esta decisión a detección, confirmación y retención de candidatos de fetch se rigen por el acuerdo 47 de `DEC-ARCH-003`: detección solo en IF, confirmación solo en ID y ninguna confirmación durante load-use. No se alteran las restantes políticas.

**Decisión:** Se aprueban conjuntamente las doce subdecisiones siguientes. Las secciones 1 a 11 conservan los contratos previamente acordados y la sección 12 fija la atomicidad universal y el mínimo de verificación para cerrar arquitectónicamente esta decisión.

#### 1. Legalidad de codificaciones de instrucción

La legalidad de una palabra de instrucción de **32 bits** se determinará mediante una **whitelist estricta**: solo es legal si su codificación completa coincide con el patrón RV32I V2.2 de una de las instrucciones explícitamente soportadas o con la palabra custom exacta de `halt`. Una codificación no reconocida o no soportada es un **candidato de fault por instrucción inválida**, no una operación implícita ni una finalización normal.

El conjunto legal consta exactamente de las **32 instrucciones RV32I requeridas** y `halt`:

```text
jal  jalr
beq  bne
lb   lh   lw   lbu  lhu
sb   sh   sw
lui
add  sub  sll  srl  sra  and  or  xor  slt  sltu
addi andi ori  xori slti sltiu slli srli srai
halt
```

Para cada instrucción RV32I soportada, la coincidencia exige **todos** los campos y restricciones de su codificación según RISC-V User-Level ISA V2.2 (`opcode`, `funct3`, `funct7` y demás bits relevantes, cuando correspondan), admitiendo todos los valores de operandos e inmediatos permitidos por ese patrón. La referencia RV32I define la semántica y codificación de este subconjunto; no añade automáticamente otras instrucciones al conjunto implementado. `halt` solo es legal como la **palabra completa `0x0000000B`**, conforme a `DEC-SYS-001`: otra palabra de `custom-0`, aunque comparta el `opcode`, no es `halt` legal.

Son ilegales, entre otras, instrucciones RISC-V estándar no incluidas en el subconjunto, combinaciones no soportadas de campos funcionales o bits fijos, codificaciones reservadas, matches parciales de una instrucción soportada, palabras arbitrarias y `0x00000000`. Esta última **no** se interpreta como `halt`. La presencia de una palabra dentro de IMEM y del prefijo de programa confirmado demuestra que fue cargada y que su fetch puede estar dentro de rango, pero **no** que su codificación sea legal: la legalidad del contenido y el límite de imagen de `DEC-ARCH-001` son condiciones distintas. También se distingue de `valid` en los registros interetapa: detectar una codificación ilegal en trabajo joven descartado como `wrong-path` no confirma por sí solo un fault arquitectónico, conforme a `DEC-ARCH-002`.

Este primer acuerdo fija únicamente la **clasificación de la codificación** y la condición candidata de instrucción inválida.

Los acuerdos posteriores completan este contrato:

- El quinto acuerdo sitúa su detección en ID y el sexto fija las condiciones de confirmación y la prioridad entre instrucciones.
- El séptimo distingue el fetch inválido de la instrucción ilegal, cuya codificación solo se valida tras un fetch válido.
- El octavo fija el drenado de instrucciones anteriores y `FAULT` tras su conclusión.
- El noveno impide que la causante de ID entre válidamente en `ID/EX` y retiene PC mientras drenan las anteriores.

La eventual inspección preventiva de palabras por el loader es opcional. Su alcance, el arbitraje RTL de coincidencias, la representación externa y las vías adicionales de recuperación desde `FAULT` corresponden a decisiones posteriores.

El trigésimo séptimo acuerdo parcial de `DEC-ARCH-003` fija después el decoder combinacional único de ID y su salida `illegal_candidate` sin alterar la whitelist aprobada. `DEC-ARCH-003` ya fija parcialmente transporte/etapas de resolución y el undécimo acuerdo de esta decisión fija causa/PC persistentes y `reset` global como mínimo.

Los acuerdos segundo, tercero y cuarto fijan por separado la alineación de accesos a `Data Memory`, Instruction Fetch y destinos de control; el tratamiento arquitectónico completo queda fijado por las doce subdecisiones, sin alterar la política de carga confirmada o la semántica de `halt` ya aprobadas.

#### 2. Alineación de accesos a Data Memory

**Aclaración aprobada de AUD-004 (2026-09-26):** la dirección efectiva es `(rs1_effective + immediate) mod 2^32`, con inmediato con signo extendido a 32 bits. Su carry no genera por sí solo un fault. Tanto la alineación como la validación de rango parten de ese resultado arquitectónico; solo la suma posterior `{1'b0, effective_address} + N <= DMEM_CAPACITY_BYTES` usa aritmética sin signo ensanchada a 33 bits para proteger todos los bytes, conforme a `DEC-ARCH-001`. Se conserva la prioridad de desalineación sobre access fault de una misma operación.

Todos los accesos CPU a `Data Memory` requerirán **alineación natural estricta** según el ancho solicitado por una instrucción de memoria válida:

| Instrucción       |   Ancho | Condición de alineación de la dirección efectiva                |
|-------------------|--------:|-----------------------------------------------------------------|
| `lb`, `lbu`, `sb` |  1 byte | Cualquier dirección cumple por alineación (`address mod 1 = 0`) |
| `lh`, `lhu`, `sh` | 2 bytes | `address[0] = 0` (`address mod 2 = 0`)                          |
| `lw`, `sw`        | 4 bytes | `address[1:0] = 00` (`address mod 4 = 0`)                       |

Si la dirección efectiva de una instrucción de memoria válida no satisface su condición, se obtiene un **candidato de fault por acceso desalineado**. No se soportarán accesos multibyte desalineados: no se dividirá una operación entre dos palabras, no se combinarán posteriormente datos de dos palabras, no se efectuarán múltiples accesos internos para completarla y no se corregirá ni truncará la dirección para forzar alineación. En particular, un store desalineado **no podrá modificar parcialmente DMEM ni los metadatos de validez por byte**; el cálculo de direcciones candidatas no habilita escrituras. Un load desalineado no obtiene un dato arquitectónico válido mediante el ensamblado de bytes candidatos.

El mapeo de cada byte candidato a `bank_i` y `row_i` aprobado en `DEC-ARCH-006` sigue siendo útil para describir direcciones, incluso si los bytes candidatos cruzan una frontera de word, pero **no vuelve legal** el acceso. Un halfword o word naturalmente alineado cabe en una misma word física de cuatro bytes: un candidato multibyte que cruce esa frontera es desalineado, no una transacción funcional `multi-row`. La legalidad por alineación y la validez por **rango de la región completa** de `DEC-ARCH-001` se evalúan como condiciones independientes; una operación puede ser candidata simultáneamente a ambas causas de fault. El séptimo acuerdo establece cuál causa prevalece cuando ambas coinciden en el mismo acceso.

Este acuerdo decide solo la **legalidad de alineación de accesos a DMEM** y la ausencia de efectos parciales de stores desalineados.

La concreción del contrato sigue esta secuencia:

- El quinto acuerdo fija la detección del candidato en EX
- El sexto las condiciones arquitectónicas de confirmación y prioridad entre instrucciones
- El séptimo prioriza desalineación sobre acceso fuera de rango de una misma operación
- El octavo dispone el drenado de instrucciones anteriores hasta `FAULT`
- El noveno impide que una causante en EX pase válidamente a `EX/MEM` mientras `MEM/WB` y `EX/MEM` previos completan anteriores.

La concreción posterior comprende estos acuerdos y límites:

- El cuadragésimo acuerdo de `DEC-ARCH-003` fija después la detección y confirmación RTL de estos eventos.
- El cuadragésimo segundo acuerdo fija después los enables/flush de PC y registros interetapa para las ocho acciones.
- Las coincidencias están cerradas por los acuerdos 44–47.
- La recuperación UART se rige por [DEC-PROTO-002](DEC-PROTO-002.md) y por el [contrato de RESET](../protocol.md#reset-desde-pc), respetando la invalidez del trabajo `wrong-path` aprobada en `DEC-ARCH-002`.

Los acuerdos tercero y cuarto definen separadamente la alineación de Instruction Fetch y de destinos de control; ninguna de estas reglas sustituye a las demás.

#### 3. Alineación de Instruction Fetch

Todo acceso CPU a `Instruction Memory` para obtener una instrucción de 32 bits deberá cumplir **alineación natural de word**:

```text
PC[1:0] = 2'b00   ⇔   PC mod 4 = 0
```

Un PC múltiplo de cuatro es legal **por alineación**; un PC que no sea múltiplo de cuatro genera un **candidato de fault por `instruction-address-misaligned`**. No se soportará fetch desalineado: no se redondeará ni corregirá automáticamente el PC, no se borrarán sus bits bajos para forzar alineación, no se reconstruirá una instrucción a partir de bytes de dos palabras y no se obtendrá arquitectónicamente una instrucción desde una dirección no múltiplo de cuatro. El índice conceptual `word_index = PC >> 2` de `DEC-ARCH-006` no autoriza a interpretar un PC desalineado como la palabra de un PC menor alineado; un valor combinacional residual de IMEM tampoco convierte ese fetch en instrucción válida.

La condición de alineación es **independiente** de la validez de rango e imagen de `DEC-ARCH-001`, que exige `image_valid` y la pertenencia completa de los cuatro bytes del fetch a IMEM y al prefijo confirmado, con aritmética ensanchada. Un mismo fetch puede ser candidato tanto por desalineación como por estar fuera de capacidad o imagen; el séptimo acuerdo prioriza la causa `instruction-address-misaligned` para ese mismo fetch. La legalidad de codificación de una palabra obtenida por fetch válido según la whitelist del primer acuerdo es otra clasificación distinta. Conforme a `DEC-ARCH-002`, si un fetch candidato del camino joven `wrong-path` es invalidado por un redirect anterior, la detección de desalineación no basta para confirmar un fault arquitectónico.

Se fija solo la **legalidad por alineación del Instruction Fetch**. El cuarto acuerdo define por separado la alineación de los **destinos** generados por `beq`, `bne`, `jal` y `jalr`; el séptimo impide redirigir a un target desalineado, por lo que no existe un fetch arquitectónico posterior desde ese destino.

La concreción del contrato sigue esta secuencia:

- El quinto acuerdo fija la detección del candidato de fetch en IF
- El sexto las condiciones de confirmación y la prioridad entre instrucciones
- El séptimo la prioridad entre desalineación y acceso inválido de un mismo fetch
- El octavo el drenado preciso hasta `FAULT`
- El noveno, revisado por el acuerdo 47 de `DEC-ARCH-003`, descarta el candidato y trabajo joven al confirmarlo en ID, retiene PC y deja avanzar anteriores.

Para esta decisión de alineación, detectar un fetch desalineado no equivale a confirmarlo. El [acuerdo 47 de `DEC-ARCH-003`](DEC-ARCH-003.md#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001) revisa su confirmación en ID; la [coincidencia con load-use](../architecture/session/faults_and_termination.md#coincidencia-con-load-use) detalla la retención previa.

La concreción posterior comprende estos acuerdos y límites:

- El cuadragésimo acuerdo de `DEC-ARCH-003` fija después los candidatos de IF y las condiciones de confirmación.
- El cuadragésimo segundo acuerdo fija después los enables/flush de PC y registros interetapa para las ocho acciones.
- El acuerdo 45 de `DEC-ARCH-003` audita después las coincidencias funcionales.
- La representación externa y otras vías de recuperación permanecen en sus decisiones específicas.
- El undécimo acuerdo fija causa y PC persistentes y `reset` global como mínimo.

#### 4. Alineación de destinos de control

Toda instrucción de control **válida** que efectivamente pretenda modificar el PC deberá producir un destino arquitectónico de 32 bits alineado a cuatro bytes:

```text
target[1:0] = 2'b00   ⇔   target mod 4 = 0
```

Se conservarán las fórmulas de `DEC-ARCH-002` y los caminos de cálculo en EX de `DEC-ARCH-003`: `beq`/`bne` usan `ID/EX.pc + immediate_B`, `jal` usa `ID/EX.pc + immediate_J` y `jalr` usa `(rs1_effective + immediate_I) & 0xFFFFFFFE`. La **comprobación de alineación del destino** depende de que se pretenda utilizarlo:

| Instrucción válida      | Condición para comprobar el target                     | Resultado por alineación                                                                          |
|-------------------------|--------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| `beq`, `bne` no tomados | Ninguna: el target no se utiliza                       | No hay candidato por alineación de ese target, aunque sus bits combinacionales estén desalineados |
| `beq`, `bne` tomados    | Condición del branch verdadera con operandos efectivos | `target[1:0] = 00` es legal por alineación; otro valor genera candidato                           |
| `jal`                   | Siempre, como salto incondicional válido               | `target[1:0] = 00` es legal por alineación; otro valor genera candidato                           |
| `jalr`                  | Siempre, **después** de forzar `jalr_sum[0]` a cero    | `target[1] = 0` es legal por alineación; `target[1] = 1` genera candidato                         |

El destino desalineado de un branch tomado, `jal` o `jalr` válidos genera un **candidato de fault por `instruction-address-misaligned`**. Para `jalr`, `jalr_sum[0] = 1` **no** es por sí solo un error: el bit 0 se borra conforme al ISA y se comprueba el target resultante, sin borrar adicionalmente `target[1]`. Tampoco se redondeará el destino a múltiplo de cuatro, se ejecutará desde una dirección desalineada ni se reconstruirán instrucciones desde dos palabras. Una entrada inválida en EX no puede generar un candidato arquitectónicamente confirmable por sus bits residuales; un branch no tomado no lo produce por un destino que no usa.

Esta regla clasifica la **legalidad del destino de control**; es distinta de la alineación del posterior Instruction Fetch y de la validez por rango e imagen de IMEM.

No añade una condición de alineación a la ecuación combinacional nominal `redirect_valid` de `DEC-ARCH-003`; el séptimo acuerdo impide **aplicar** el redirect a un target desalineado, aunque pueda existir un resultado combinacional.

El sexto acuerdo fija cuándo un candidato **puede confirmarse semánticamente** y qué instrucción prevalece por antigüedad: si el fault se confirma, la instrucción causante no escribe el enlace de `jal`/`jalr` y el noveno impide que avance válidamente a `EX/MEM`, reteniendo PC mientras drenan anteriores.

La concreción posterior y su límite son los siguientes:

- El cuadragésimo acuerdo de `DEC-ARCH-003` fija después `target_misaligned_candidate`, `ex_fault_confirm` y `redirect_apply` en ciclo efectivo.
- El cuadragésimo segundo acuerdo fija después los enables/flush de PC y registros interetapa desde las acciones del cuadragésimo primero.
- El cuadragésimo quinto acuerdo audita después las coincidencias adicionales.
- No se admite fetch arquitectónico desde ese target.

#### 5. Detección de candidatos de fault

Cada condición candidata se detectará en la **primera etapa que disponga de todos los datos necesarios** para evaluarla correctamente:

| Condición candidata                                                          | Etapa de detección |
|------------------------------------------------------------------------------|--------------------|
| Instruction Fetch fuera de capacidad IMEM o del prefijo de imagen confirmada | **IF**             |
| Instruction Fetch desalineado                                                | **IF**             |
| Codificación de instrucción inválida frente a la whitelist completa          | **ID**             |
| Load/store fuera de rango DMEM                                               | **EX**             |
| Load/store desalineado                                                       | **EX**             |
| Destino desalineado de `beq`/`bne` tomados o `jal`/`jalr` válidos            | **EX**             |

IF evaluará sobre el PC tanto la pertenencia de **los cuatro bytes** a IMEM y a la imagen confirmada como `PC[1:0] = 00`. Son condiciones independientes: un fetch puede presentar ambas causas candidatas simultáneamente y el séptimo acuerdo fija cuál prevalece. ID validará la **palabra completa** de `IF/ID` obtenida mediante fetch válido según el subconjunto aprobado y distinguirá el contenido ilegal de un fetch fuera de imagen o de bits residuales de una entrada inválida. Esta asignación de etapas no decide si el loader inspeccionará también la imagen ni asigna aquí etapa alguna al reconocimiento de `halt`.

Para loads y stores válidos, EX calculará primero `effective_address = (rs1_effective + immediate) mod 2^32`, sin fault por el carry de esa suma, y evaluará **sobre ese resultado de 32 bits** la alineación natural. Por separado, comprobará el rango de **toda la región solicitada** mediante `{1'b0, effective_address} + N <= DMEM_CAPACITY_BYTES`, con suma y comparación sin signo de 33 bits; esta segunda suma no admite wrap-around. Ambas condiciones se clasifican separadamente antes de que la operación pueda causar un acceso físico a DMEM; un store inválido no modifica parcialmente bytes ni metadatos y un load inválido no escribe `rd`, conforme a `DEC-ARCH-001` y al segundo acuerdo. La dirección calculada conserva su recorrido nominal como `ex_result` sin que este acuerdo fije campos adicionales de `EX/MEM` ni el mecanismo de inhibición y transporte del candidato.

EX evaluará asimismo la alineación del **destino efectivo** solo después de resolver la condición del branch o calcular el target del salto: un branch no tomado no genera candidato por ese target; `jalr` comprueba el target tras poner su bit 0 en cero, sin borrar el bit 1. La ecuación nominal de `redirect_valid` permanece intacta, pero el séptimo acuerdo impide aplicar un redirect a ese target desalineado; si el fault propio se confirma, la causante carece de efectos arquitectónicos conforme al duodécimo acuerdo. La realización física del control queda para `DEC-ARCH-003`.

La detección produce únicamente un **candidato asociado a un fetch o instrucción concreta**, no un fault arquitectónico confirmado ni un cambio del estado global de ejecución.

Los acuerdos posteriores completan el tratamiento del candidato:

- El sexto acuerdo fija las condiciones arquitectónicas para su confirmación y la prioridad por antigüedad entre instrucciones.
- El séptimo fija la prioridad desalineación sobre acceso inválido para causas concurrentes de un mismo fetch, load o store.
- El octavo define el drenado de instrucciones anteriores tras confirmarse un fault y el ingreso posterior a `FAULT`.
- El noveno fija la retención del PC y las invalidaciones selectivas de `IF/ID`, `ID/EX` y `EX/MEM` según dónde esté la causante, sin interrumpir anteriores.

Cuando un redirect de una instrucción más antigua descarte trabajo joven `wrong-path`, también se descartan sus candidatos de IF o ID, sin efectos arquitectónicos.

Las condiciones combinacionales pueden evaluarse durante `HOLD`, pero no aplican por sí solas transiciones: `RUN` y `STEP` solo las autorizan en ciclos efectivos conforme a `DEC-ARCH-008`.

El [acuerdo 47 de `DEC-ARCH-003`](DEC-ARCH-003.md#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001) mantiene la detección en IF y lleva la confirmación a ID. La [retención durante load-use](../architecture/session/faults_and_termination.md#coincidencia-con-load-use) no captura ni confirma el candidato; tampoco altera las restricciones de `HOLD` anteriores.

La concreción posterior y los límites de alcance son los siguientes:

- El cuadragésimo segundo acuerdo fija después los enables/flush de PC y registros interetapa para las acciones aprobadas.
- El cuadragésimo quinto acuerdo audita después las coincidencias funcionales.
- La representación externa de `fault_cause`/`fault_pc` y otras vías de recuperación siguen en sus decisiones específicas.
- El undécimo acuerdo fija su persistencia y `reset` global como mínimo.

#### 6. Confirmación arquitectónica y prioridad por antigüedad

La **mera detección** en IF, ID o EX no confirma un fault. Un candidato asociado a una operación solo podrá convertirse en fault arquitectónico cuando la operación siga siendo válida, pertenezca al camino correcto, no haya sido invalidada por una instrucción más antigua y no exista un evento arquitectónico de una instrucción anterior que deba prevalecer. El séptimo acuerdo selecciona una causa única cuando la misma operación presenta simultáneamente desalineación y acceso inválido, sin cambiar la prioridad por antigüedad **entre operaciones**. Conceptualmente:

```text
candidato de fault + operación válida + camino correcto
                   + ausencia de evento más antiguo prevaleciente
    → fault arquitectónico confirmado
```

Entre eventos o candidatos de **instrucciones distintas** rige prioridad estricta por **antigüedad de programa**: la instrucción más antigua tiene prioridad arquitectónica. La etapa donde se detectó cada condición no reemplaza el orden del flujo. Si EX alberga un load desalineado, ID una instrucción inválida e IF un fetch fuera de rango, y las tres operaciones son válidas y pertenecen al mismo flujo, tiene prioridad el evento del load en EX por ser el más antiguo. Si una instrucción de control más antigua en EX redirige mientras ID y IF detectan candidatos, las operaciones jóvenes pasan a `wrong-path`: sus candidatos se descartan sin fault arquitectónico ni modificación del estado global. También debe respetarse cualquier otro evento prevaleciente de una instrucción más antigua, sin convertir a un candidato joven en fault por su mera detección.

Una vez **confirmado** un fault, la operación causante y todas las instrucciones más jóvenes carecen de efectos arquitectónicos, conforme a `DEC-ARCH-001`; el octavo acuerdo fija que las **más antiguas** todavía activas completan normalmente y, tras su drenado, se alcanza `FAULT`. El noveno retiene PC, impide admisión y fija las transiciones selectivas por etapa sin vaciar registros interetapa con anteriores. Esta regla no asigna una etapa física única ni señal RTL `fault_confirm`, ni fija el ciclo de confirmación, el transporte de candidatos o la integración física de coincidencias con redirect, stalls y `halt`; el séptimo acuerdo sí prohíbe arquitectónicamente redirigir a un destino desalineado. Tampoco se confundirá la causa prevaleciente **dentro de una misma operación** con la prioridad por antigüedad entre operaciones distintas. Durante `HOLD` no se produce transición arquitectónica por una evaluación combinacional; `RUN` y `STEP` aplican transiciones solo en ciclos efectivos conforme a `DEC-ARCH-008`.

#### 7. Prioridad entre causas concurrentes de una misma operación

Cuando una **misma operación** presente simultáneamente desalineación y violación de rango o acceso inválido, prevalecerá arquitectónicamente **`misalignment > access fault`**. Ambas condiciones se comprueban de forma independiente y pueden detectarse en paralelo en la misma etapa; la prioridad determina una causa única y estable, no el orden temporal ni físico de evaluación:

| Operación               | Condiciones concurrentes                                            | Causa prevaleciente                                                     |
|-------------------------|---------------------------------------------------------------------|-------------------------------------------------------------------------|
| Instruction Fetch en IF | PC desalineado y fetch fuera de IMEM o imagen confirmada            | `instruction-address-misaligned` en lugar de `instruction-access-fault` |
| Load en EX              | Dirección efectiva desalineada para su ancho y acceso fuera de DMEM | `load-address-misaligned` en lugar de `load-access-fault`               |
| Store en EX             | Dirección efectiva desalineada para su ancho y acceso fuera de DMEM | `store-address-misaligned` en lugar de `store-access-fault`             |

Por convención se prioriza primero la legalidad de **forma** del acceso según su alineación natural y luego la pertenencia de la región completa al rango implementado, sin derivar de ello una necesidad física de evaluar secuencialmente ambas condiciones. Si solo se presenta una causa, esta conserva su clasificación. Esta prioridad **entre causas de una operación** no sustituye la prioridad **por antigüedad entre instrucciones distintas** del sexto acuerdo ni confirma por sí sola un fault de trabajo `wrong-path`.

En EX, un branch **tomado**, `jal` o `jalr` válido con destino efectivo desalineado genera un candidato `instruction-address-misaligned` **en la propia instrucción de control** y **no aplica el redirect**: no habrá fetch arquitectónico desde ese target. Un branch no tomado no usa su target. Para `jalr` se comprueba el destino *después* de borrar solo su bit 0.

Si el target está alineado pero fuera de IMEM o de la imagen confirmada, se permite el redirect por alineación; el fetch **posterior** en IF detecta un candidato `instruction-access-fault` asociado a esa operación de fetch distinta, sujeto a validez del camino, prioridad por antigüedad y confirmación.

Esta prohibición de redirigir a un target desalineado no prescribe una nueva ecuación para el `redirect_valid` combinacional nominal de `DEC-ARCH-003`, ni selecciona enable, flush, PC alternativo o comportamiento físico del enlace para la instrucción causante; si un fault se confirma, se mantiene la ausencia de efectos arquitectónicos de esa instrucción.

La taxonomía conceptual de causas es:

```text
instruction-address-misaligned
instruction-access-fault
illegal-instruction
load-address-misaligned
load-access-fault
store-address-misaligned
store-access-fault
```

La legalidad de fetch en IF y la legalidad de codificación en ID son distintas: **solo después de un fetch válido** se valida la palabra de 32 bits como instrucción y puede producirse `illegal-instruction`; los residuos de un fetch inválido no se decodifican arquitectónicamente.

La concreción posterior distingue estos aspectos:

- La codificación binaria común de causas se fija después en el trigésimo quinto acuerdo de `DEC-ARCH-003`.
- El decoder combinacional de ID se fija después en el trigésimo séptimo acuerdo de `DEC-ARCH-003`, mientras el cuadragésimo primer acuerdo de `DEC-ARCH-003` fija después el arbitraje combinacional de acciones.
- El cuadragésimo segundo acuerdo fija después los enables/flush de PC y registros interetapa para esas acciones.
- Sigue pendiente el formato externo de reporte.

La revisión del [acuerdo 47 de `DEC-ARCH-003`](DEC-ARCH-003.md#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001) completa esta distinción entre legalidad de fetch y de instrucción: el candidato de fetch se [confirma en ID](../architecture/session/faults_and_termination.md#confirmación-en-id), sin decodificar arquitectónicamente sus residuos.

#### 8. Respuesta arquitectónica al fault y tratamiento de instrucciones anteriores

Un **fault arquitectónicamente confirmado** establece una frontera **precisa respecto del orden de programa**:

```text
instrucciones anteriores a la causante → continúan y completan normalmente
instrucción causante                → sin efectos arquitectónicos
instrucciones más jóvenes          → sin efectos arquitectónicos
instrucciones nuevas               → dejan de admitirse
```

La CPU drenará **únicamente** las instrucciones más antiguas que la operación causante que aún estén activas en el pipeline. Cuando todas hayan completado y el pipeline carezca de trabajo arquitectónico pendiente, entrará en el estado de error arquitectónico **`FAULT`**, distinto de `FINISHED`, `DONE` o cualquier finalización normal. La frontera resultante tiene todas las instrucciones anteriores completadas y la causante y posteriores sin efectos. Si no quedan instrucciones anteriores activas, no se requiere progreso de trabajo inexistente ni un ciclo artificial de drenado; el ciclo y mecanismo RTL concretos de confirmación/transición se integrarán después. Un **candidato** no confirmado, incluido uno del camino `wrong-path`, no inicia por sí solo este drenado ni detiene la admisión.

Por ejemplo, si MEM contiene `I1` (anterior válida), EX contiene `I2` (fault confirmado), ID contiene `I3` e IF contiene `I4`, `I1` completa sus efectos; `I2`, `I3` e `I4` no producen efectos, y no se admiten instrucciones nuevas mientras se drena `I1`. Otras instrucciones anteriores aún activas también deberán completar normalmente; no se fija una cantidad universal de ciclos.

Esta política complementa `DEC-ARCH-001` y distingue dos desenlaces de drenado:

```text
halt válido        → completan anteriores → pipeline vacío → FINISHED
fault confirmado   → completan anteriores → pipeline vacío → FAULT
```

El drenado requiere **ciclos efectivos** conforme a `DEC-ARCH-008`: bajo ejecución continua progresa con la autorización de `RUN` y, bajo paso a paso, necesita un nuevo `STEP` por ciclo; durante `HOLD` no avanza. El noveno acuerdo fija PC retenido, no admisión, invalidación selectiva de causante/jóvenes y progreso de anteriores hasta que los cuatro registros interetapa sean inválidos, sin exigir una señal o estado RTL `FAULT_DRAIN`, campos de datos limpiados ni ecuaciones de enable. El undécimo acuerdo fija la observabilidad del error, su causa y PC estables durante drenado y `FAULT`, y `reset` global como recuperación mínima. `DEC-ARCH-003` ya fija las etapas de resolución y el transporte mínimo; el acuerdo 45 de `DEC-ARCH-003` audita después las coincidencias funcionales; la representación externa detallada y las vías de recuperación adicionales quedan en sus decisiones respectivas. Un fault no activa `program_finished` ni `DONE`.

#### 9. Acciones del pipeline ante un fault confirmado

Una vez **confirmado arquitectónicamente** un fault, el pipeline separará las instrucciones **anteriores** de la **causante** y las **posteriores**. PC dejará de avanzar y quedará retenido durante todo el drenado; IF no admitirá nuevas instrucciones. Las anteriores todavía válidas continuarán progresando, con los stalls necesarios para sus dependencias, hasta completar sus efectos; la causante no se propagará como instrucción válida y las jóvenes se invalidarán. No se vaciarán indiscriminadamente los cuatro registros interetapa: `MEM/WB` y cualquier otra etapa con trabajo anterior conservan la capacidad de completar cada store o writeback exactamente una vez. Las salidas combinacionales residuales de IF no representan nuevas instrucciones admitidas.

Para una operación causante confirmada, las acciones en el **ciclo efectivo de confirmación** se describen desde el contenido **previo al flanco**.

La fila de fetch siguiente incorpora la revisión del [acuerdo 47 de `DEC-ARCH-003`](DEC-ARCH-003.md#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001): su causante se confirma en ID. La [secuencia previa con load-use](../architecture/session/faults_and_termination.md#coincidencia-con-load-use) conserva al consumidor antes de esa confirmación.

| Causante                                                       | Instrucciones anteriores                                                             | Causante y trabajo más joven                                                                                                                                   | PC / admisión                                  |
|----------------------------------------------------------------|--------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------|
| Fetch detectado en **IF** y confirmado en **ID** desde `IF/ID` | Las entradas previas de `ID/EX`, `EX/MEM` y `MEM/WB` siguen drenando, si son válidas | No se propaga el candidato de `IF/ID` a `ID/EX`: `ID/EX.next.valid=0`; `IF/ID` deja `valid=0` y limpia `fetch_fault_valid`                                     | PC retenido; no se admiten fetches posteriores |
| Instrucción en **`IF/ID` (ID)**                                | `ID/EX`, `EX/MEM` y `MEM/WB` previos continúan drenando                              | La causante no entra válida en `ID/EX` (`ID/EX.next.valid=0`); `IF/ID.next.valid=0`, `IF/ID.next.fetch_fault_valid=0` y el fetch joven de IF se descarta       | PC retenido; no hay admisión nueva             |
| Instrucción en **`ID/EX` (EX)**                                | `EX/MEM` y `MEM/WB` previos continúan drenando                                       | La causante no entra válida en `EX/MEM` (`EX/MEM.next.valid=0`); `ID/EX.next.valid=0`, `IF/ID.next.valid=0`, `IF/ID.next.fetch_fault_valid=0` y se descarta IF | PC retenido; no hay admisión nueva             |

En particular, ante fault confirmado por destino desalineado de `jal` o `jalr` en EX, no se realiza redirect, no se escribe el enlace y la instrucción no avanza **válidamente** a `EX/MEM`. Las entradas inválidas pueden conservar bits residuales sin decodificarse ni producir efectos; `IF/ID.valid=0` con `fetch_fault_valid=1` es únicamente un candidato de fetch, mientras `valid=0` y el flag limpiado no confirma nada por residuos. Una instrucción anterior que ocupaba `EX/MEM` antes del flanco puede avanzar a `MEM/WB` aunque `EX/MEM.next.valid=0` para la causante. No se equiparará una salida combinacional de IF, una instrucción previa en `IF/ID` o una instrucción de `EX/MEM` a la nueva entrada de otro registro interetapa en ese mismo flanco. El décimo acuerdo, revisado por el 47 de `DEC-ARCH-003`, preserva al consumidor durante `load-use` sin confirmar el candidato IF. Este nunca ingresa como instrucción válida: se captura después con `valid=0, fetch_fault_valid=1` y solo puede confirmarse en ID.

Durante el drenado conceptual **`FAULT_DRAIN`**, PC permanece retenido, no se habilitan nuevos fetches ni se admiten instrucciones y solo progresan las anteriores todavía válidas, con los stalls que requieran para conservar sus dependencias. Estas fases semánticas se realizan con `FAULT_DRAIN_AUTO`/`STEP` en la FSM del acuerdo 44; su codificación binaria es libre. El progreso ocurre únicamente en ciclos CPU efectivos: bajo autorización continua de `RUN` se producen los ciclos de drenado y bajo paso a paso se requiere un `STEP` nuevo por ciclo; `HOLD` no actualiza PC, registros interetapa, registros ni memoria. Cuando hayan completado todas las anteriores y **`IF/ID.valid = ID/EX.valid = EX/MEM.valid = MEM/WB.valid = 0`**, el estado arquitectónico pasa a **`FAULT`**, conservando el pipeline vacío. Ni el ciclo de confirmación ni el drenado aplican cambios asíncronos o ciclos arquitectónicos ocultos; `reset` y `LOAD` conservan sus prioridades globales ya aprobadas.

El acuerdo fija solo estas acciones **tras confirmarse** el fault, sin convertir la mera detección de un candidato en drenado o retención del PC. El décimo acuerdo resuelve la interacción semántica con `redirect`, `halt` y `load-use stall`; el undécimo fija causa y PC observables y persistentes, distinción respecto de `FINISHED` y recuperación mínima por `reset` global. La concreción posterior distingue estos aspectos:

- Las etapas y el transporte mínimo de candidatos se fijan en el vigésimo noveno acuerdo de `DEC-ARCH-003`.
- El cuadragésimo acuerdo fija después las ecuaciones RTL de detección/confirmación.
- El cuadragésimo segundo acuerdo fija después enables/flush de PC y registros interetapa para las acciones pactadas.
- El acuerdo 45 de `DEC-ARCH-003` resuelve después las coincidencias funcionales.
- La representación externa y otras vías de recuperación quedan en sus decisiones respectivas.

#### 10. Interacción entre fault, redirect, `halt` y `load-use stall`

No se adopta una prioridad universal `fault > redirect > halt > stall`. Primero se determina qué instrucciones permanecen válidas y en el camino correcto. Entre eventos de **instrucciones distintas** prevalece la instrucción más antigua en orden de programa:

| Frontera más antigua              | Evento en instrucción más joven | Resultado arquitectónico                                                               |
|-----------------------------------|---------------------------------|----------------------------------------------------------------------------------------|
| Redirect aplicable                | Candidato de fault              | El trabajo joven queda `wrong-path` y se descarta; el candidato no se confirma         |
| Fault confirmado                  | Redirect                        | El redirect joven se descarta sin efecto; se drenan anteriores y se llega a `FAULT`    |
| `halt` válido del camino correcto | Candidato de fault              | Se descarta el candidato posterior; drenado normal hasta `FINISHED`                    |
| Fault confirmado                  | `halt`                          | Se descarta el `halt` posterior; se llega a `FAULT`, nunca a `FINISHED` por ese `halt` |

Un candidato de fault de una instrucción **no** confirma nada por su sola detección: debe satisfacer validez, camino correcto y ausencia de una frontera anterior prevaleciente. Si **la misma** instrucción de control, branch tomado, `jal` o `jalr`, tiene destino desalineado, su propio fault suprime sus efectos normales: **no hay redirect**, ni escritura de enlace en `jal`/`jalr`, ni efectos arquitectónicos de la causante. No es una comparación de antigüedad entre dos instrucciones; la señal combinacional nominal de redirect puede existir sin aplicar el destino. Un `halt` válido del camino correcto establece igualmente una frontera: ninguna instrucción posterior confirma un fault o produce efectos. No se asigna aquí etapa física al reconocimiento de `halt`.

Un `load-use stall` no establece una frontera arquitectónica: solo se aplica cuando sigue siendo necesario para **instrucciones anteriores supervivientes**.

Según el [acuerdo 47 de `DEC-ARCH-003`](DEC-ARCH-003.md#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001), un candidato IF no confirma durante el stall. La [secuencia de load-use](../architecture/session/faults_and_termination.md#coincidencia-con-load-use) deja que el consumidor llegue a EX antes de resolver ese candidato en ID.

Cuando el valor esté disponible, el consumidor puede continuar con forwarding y completar una sola vez. Si el load en EX es la causante de fault y su consumidor está en ID, el consumidor se descarta, la causante no pasa válida a `EX/MEM` y no se mantiene el stall por esa dependencia. Tampoco se aplica un stall cuya consumidora es la propia causante o una instrucción posterior a un fault más antiguo.

Conceptualmente se aplica esta secuencia:

1. Se filtran validez, camino correcto y antigüedad.
2. Se suprimen los efectos propios de la causante.
3. Se descarta el trabajo joven tras la frontera de fault, `halt` o redirect.
4. **Solo** se aplican stalls necesarios para anteriores que sobreviven.

Durante el drenado, las anteriores pueden necesitar retención, bubble y forwarding sin habilitar nuevas instrucciones ni perder el fault confirmado.

`RUN` y `STEP` aplican esos pasos solo en ciclos CPU efectivos; `HOLD` no progresa.

La revisión del [acuerdo 47 de `DEC-ARCH-003`](DEC-ARCH-003.md#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001) también rige esta secuencia de filtrado; las [acciones de drenado](../architecture/cpu/control_and_hazards.md#las-ocho-acciones-del-pipeline) conservan sus condiciones de autorización.

El cuadragésimo acuerdo de `DEC-ARCH-003` fija después las condiciones RTL de confirmación/aplicación por antigüedad; el cuadragésimo segundo acuerdo fija después las ecuaciones de enables/flush de PC y registros interetapa para esas acciones; el cuadragésimo cuarto acuerda después la FSM global y el cuadragésimo quinto audita las coincidencias funcionales. El trigésimo sexto había introducido registros terminales, reemplazados expresamente por la FSM del cuadragésimo cuarto.

#### 11. Estado observable, causa y recuperación del fault

Un fault **arquitectónicamente confirmado** será observable como condición de error durante el drenado conceptual **`FAULT_DRAIN`**, cuando haya anteriores activas, y en el estado final **`FAULT`**. Ambos se distinguirán semánticamente de `RUN`/`STEP`, del drenado de un `halt` válido (**`HALT_DRAIN`**) y de **`FINISHED`**. Los nombres designan categorías observables; no obligan a codificar una FSM con esos cinco estados ni a insertar un ciclo de drenado si no queda trabajo anterior. Solo tras completar anteriores y quedar los cuatro registros interetapa inválidos se alcanzará `FAULT`, manteniendo la condición de error y el pipeline vacío. Un fault no activará `program_finished`, `DONE` ni otra indicación reservada para terminación normal por `halt`.

Al **confirmarse** el fault se capturará y mantendrá, como mínimo, información conceptual **`fault_cause`** y **`fault_pc`** asociada a la operación causante:

| Información   | Semántica mínima                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `fault_cause` | Una causa arquitectónica inequívoca entre `instruction-address-misaligned`, `instruction-access-fault`, `illegal-instruction`, `load-address-misaligned`, `load-access-fault`, `store-address-misaligned` y `store-access-fault`. Se respetan la prioridad por antigüedad entre instrucciones y `misalignment > access fault` dentro de un mismo fetch, load o store.                                                                            |
| `fault_pc`    | PC de la instrucción causante ya obtenida, incluido el PC propio transportado hasta `ID/EX` para loads, stores y destinos de control en EX; para fetch detectado en IF y confirmado en ID, dirección del fetch causante preservada en `IF/ID.pc` conforme al acuerdo 47 de `DEC-ARCH-003`. No se sustituye por la dirección efectiva, el target problemático ni automáticamente por el PC global de IF, que puede corresponder a otra operación. |

La captura lógica está vinculada a la **confirmación arquitectónica**, no a la mera detección combinacional del candidato: un candidato `wrong-path`, invalidado o posterior a una frontera anterior no publica causa/PC como fault actual. Una vez confirmados, `fault_cause` y `fault_pc` permanecen **estables durante todo `FAULT_DRAIN` y en `FAULT`**; las instrucciones anteriores que drenan, las posteriores descartadas y nuevos candidatos no los sobrescriben. `HOLD` tampoco los modifica. Los datos forman parte del estado persistente observable de fault para snapshots coherentes cuando Debug pueda capturarlos, sin imponer snapshot arbitrario durante `RUN`, puertos o formato UART ni almacenamiento dentro de los cuatro registros interetapa. El trigésimo quinto acuerdo parcial de `DEC-ARCH-003` fija después `fault_cause[2:0]` y su codificación común con el candidato de `IF/ID`, sin cambiar esta persistencia. No se exige un `fault_address` independiente; otra decisión podrá agregarlo para Debug.

La **recuperación mínima obligatoria desde `FAULT` es el `reset` global** de `DEC-ARCH-008`. Cuando el `reset` funcional tome efecto en el flanco válido, se invalida la condición de fault y dejan de interpretarse `fault_cause` y `fault_pc` como datos de la sesión actual; el PC queda en `0x00000000`, `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB` con `valid=0`, sin sesión ni imagen ejecutable activa (`loaded_image_size_bytes=0`, `image_valid=0`). Reset no produce `FINISHED`/`DONE`; después requiere preparación y commit normales de una nueva sesión antes de `RUN` o `STEP`. No se exige poner a cero los bits físicos de los metadatos invalidados, borrar memorias ni actualizar registros funcionales asíncronamente. El cuadragésimo cuarto acuerdo de `DEC-ARCH-003` aprueba después `RUN`/`STEP` desde `FAULT` para preparar una **sesión nueva y limpia** con la imagen confirmada; no reanuda la sesión fallada ni suprime `reset` global como vía mínima. La representación externa de causa/PC y el comando UART se definen en la [arquitectura de Debug](../architecture/debug/debug_architecture.md) y el [protocolo UART](../protocol.md#reset-desde-pc).

Este acuerdo fija la persistencia observable, información mínima y recuperación por `reset`. El vigésimo noveno acuerdo de `DEC-ARCH-003` fija posteriormente el transporte/etapas mínimas de candidatos sin cambiar esa semántica; el trigésimo quinto fija el ancho y código de causa. El trigésimo sexto acuerdo introdujo `terminal_kind[1:0]` y `drain_auto` registrados, sustituidos **expresamente** por `global_state` en el cuadragésimo cuarto: clase terminal y modalidad de drenado se derivan de los 14 estados. Los acuerdos cuadragésimo primero y segundo fijan el arbitraje y los enables de PC/registros interetapa, y el cuadragésimo tercero el gating de efectos CPU. El cuadragésimo quinto acuerdo audita y resuelve después las coincidencias funcionales; la representación externa del estado global sigue en `DEC-ARCH-009`.

#### 12. Atomicidad y verificación mínima

**Regla general:** Toda operación causante de un **fault arquitectónicamente confirmado** tendrá **cero efectos arquitectónicos propios**. No se aplica esta supresión a las instrucciones anteriores supervivientes: completan exactamente una vez; las posteriores quedan descartadas. Un candidato no confirmado no inicia por sí mismo el drenado ni publica un fault.

| Operación causante                   | Efectos propios prohibidos                                                                                                                                                   |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Load con fault                       | No escribe `rd` ni aporta un valor arquitectónico de la carga                                                                                                                |
| Store con fault                      | No modifica **ningún byte** de DMEM ni sus metadatos de validez; no se habilita **ningún byte para escritura**, aun si algunos bytes candidatos están dentro de la capacidad |
| `jal`/`jalr` con target desalineado  | No aplica redirect ni escribe el enlace                                                                                                                                      |
| Branch tomado con target desalineado | No aplica redirect ni produce otros efectos arquitectónicos de esa instrucción                                                                                               |
| Instrucción inválida                 | No escribe RegFile ni DMEM, no aplica redirect y no inicia `halt`                                                                                                            |

Un store defectuoso es atómico respecto de toda su región: se comprueban alineación y rango de **todos** sus bytes candidatos antes de habilitar DMEM; una región parcialmente dentro de rango no permite una escritura parcial, ni un byte enable parcialmente activo, ni una modificación de metadatos. Se extiende a desalineación y demás faults la prohibición de efectos parciales de `DEC-ARCH-001`. Para loads tampoco se permite writeback de un valor residual; para saltos no se aplica un target desalineado aunque existan resultados combinacionales del datapath.

El drenado usa la disciplina de `DEC-ARCH-008`: en `RUN` las anteriores avanzan automáticamente por ciclos CPU efectivos, respetando stalls necesarios entre supervivientes; en `STEP` cada ciclo de drenado requiere un **`STEP` autorizado nuevo** y puede hacer falta más de uno; en `HOLD` no avanzan instrucciones ni se producen ciclos arquitectónicos ocultos. Si al confirmar no queda trabajo anterior, no se exige un ciclo de drenado vacío antes de `FAULT`.

**Matriz mínima obligatoria de verificación:**

| Área               | Cobertura mínima                                                                                                                                                                                                                                                 |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Legalidad ISA      | Las 32 RV32I soportadas y `halt = 0x0000000B` completos se aceptan; se rechazan no soportadas, reservadas, matches parciales y `0x00000000`                                                                                                                      |
| Alineación DMEM    | Byte en cualquier dirección; halfword y word alineados y desalineados, con la región completa validada                                                                                                                                                           |
| Fetch              | `PC[1:0]=00` es legal por alineación; `01`, `10` y `11` generan candidato de misalignment                                                                                                                                                                        |
| Branches           | Target desalineado solo causa fault propio de branch válido y **tomado**, nunca de branch no tomado                                                                                                                                                              |
| `jal`              | Target desalineado causa fault propio, sin redirect ni link                                                                                                                                                                                                      |
| `jalr`             | Borrar primero solo `target[0]`; comprobar después alineación a cuatro bytes, sin redirect/link si falla                                                                                                                                                         |
| Causas simultáneas | En el mismo fetch, load o store, misalignment y acceso fuera de rango eligen causa de misalignment                                                                                                                                                               |
| `wrong-path`       | Candidato joven invalidado por evento anterior no confirma fault ni reemplaza causa/PC válidos                                                                                                                                                                   |
| Antigüedad         | Entre eventos de instrucciones distintas prevalece la anterior en orden de programa                                                                                                                                                                              |
| Fault preciso      | Todas las anteriores completan; la causante y posteriores carecen de efectos; registros interetapa vacíos antes de `FAULT`                                                                                                                                       |
| Load defectuoso    | `rd` no se escribe por el load causante                                                                                                                                                                                                                          |
| Store defectuoso   | Ningún byte o metadato DMEM cambia ni se habilita un byte de escritura, incluso con acceso parcialmente dentro de rango                                                                                                                                          |
| Control defectuoso | Fault propio de branch tomado o salto no aplica redirect; `jal`/`jalr` tampoco escriben link                                                                                                                                                                     |
| Terminación        | Fault llega a `FAULT`, no `FINISHED`/`DONE`; `RUN`/`STEP` drenan solo en ciclos efectivos, `HOLD` no progresa                                                                                                                                                    |
| Observabilidad     | `fault_cause` y `fault_pc` capturados al confirmar persisten durante `FAULT_DRAIN` y `FAULT`                                                                                                                                                                     |
| Recuperación       | Reset global invalida fault y metadatos, PC vuelve a cero y pipeline/sesión quedan inválidos conforme a `DEC-ARCH-008`; el acuerdo 44 de `DEC-ARCH-003` permite después una nueva sesión limpia por `RUN`/`STEP` desde `FAULT` reutilizando la imagen confirmada |

**Justificación:** La validación estricta, la alineación natural y la confirmación por validez y antigüedad impiden tratar bits residuales, trabajo `wrong-path` o bytes parciales como operaciones arquitectónicas. Una frontera precisa permite completar las anteriores sin comprometer efectos de la causante; causa y PC persistentes distinguen error de terminación normal y permiten diagnosticarlo sin imponer un protocolo concreto.

**Consecuencias:** La política de faults arquitectónicos queda **conceptualmente cerrada**: las doce subdecisiones, la atomicidad universal y la matriz mínima anterior son obligatorias para la implementación y verificación. Un store inválido no habilita escrituras de datos ni metadatos; un fault no produce `FINISHED`. La representación externa y la integración física deberán conservar las prioridades, el estado observable y el drenado establecidos aquí.

El [acuerdo 47 de `DEC-ARCH-003`](DEC-ARCH-003.md#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001) revisa los casos de fetch de esta matriz; su matriz adicional conserva las regresiones de candidato retenido, descarte por EX y confirmación legítima en ID.

El trigésimo quinto acuerdo parcial de `DEC-ARCH-003` fija después el código de tres bits común para `IF/ID.fetch_fault_cause` y `fault_cause` confirmada.

La representación terminal y el control evolucionan de este modo:

- El trigésimo sexto acuerdo parcial de `DEC-ARCH-003` había fijado `terminal_kind[1:0]`, **revisado expresamente** por la FSM de 14 estados del cuadragésimo cuarto para distinguir `NONE`, `HALT`, `FAULT` y modalidad de drenado sin ese registro.
- El cuadragésimo acuerdo fija después las señales candidatas y las ecuaciones RTL de confirmación/aplicación de fault, `halt` y redirect por antigüedad, y el cuadragésimo primero, revisado por el 47, fija la selección combinacional de ocho acciones (seis no terminales y dos de drenado), y el cuadragésimo segundo fija los próximos estados de PC y registros interetapa derivados de ellas.
- El cuadragésimo tercero fija el gating de efectos CPU y el cuadragésimo cuarto las transiciones y autorización del ciclo global.
- El cuadragésimo quinto audita y resuelve las coincidencias funcionales, conservando las fronteras arquitectónicas aquí fijadas.
- El cuadragésimo sexto acuerdo completa la matriz final y cierra `DEC-ARCH-003`, con revisión explícita por el acuerdo 47.

La recuperación por `RUN`/`STEP` desde `FAULT` mediante nueva sesión con imagen confirmada y la elegibilidad de `LOAD` en modos `STEP` se fijan en el cuadragésimo cuarto acuerdo; los campos de fault y pipeline expuestos se definen en [DEC-ARCH-009](DEC-ARCH-009.md), y los formatos UART y las condiciones de admisión y recuperación en el [protocolo](../protocol.md#estado-cpu-y-fase-de-transporte).

Una inspección preventiva opcional de palabras por el loader no cambia la legalidad ni puede sustituir la confirmación durante ejecución. No se incorporan condiciones semánticas pendientes al identificador `DEC-ARCH-004`.

**Requisitos afectados:** `REQ-CPU-011`, `REQ-CPU-015`, `REQ-CPU-017`, `REQ-ISA-001` a `REQ-ISA-034`, especialmente `REQ-ISA-001`, `REQ-ISA-005`, `REQ-ISA-006`, `REQ-ISA-032` a `REQ-ISA-034`, `REQ-ISA-002` a `REQ-ISA-004` y `REQ-ISA-018` a `REQ-ISA-022`, `REQ-MEM-006`, `REQ-MEM-009`, `REQ-MEM-016` a `REQ-MEM-018`, `REQ-MEM-020`, `REQ-MEM-027` a `REQ-MEM-029`, `REQ-EXEC-013` a `REQ-EXEC-015`, `REQ-EXEC-018`, `REQ-HAZ-004`, `REQ-HAZ-010`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`.

**Reemplaza / Reemplazada por:** No aplica.

---
