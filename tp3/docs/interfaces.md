# TP3 — Contratos de interfaces

**Estado:** especificación documental de las interfaces internas, contrastada con la arquitectura vigente el 2026-09-30. UART, Loader, mantenimiento y Debug conservan los límites de realización o decisiones abiertas indicados abajo. Esta revisión no acredita implementación RTL, simulación, síntesis ni timing.

Este documento formaliza el mapa de bloques, entradas y salidas anterior. Cada conexión identifica productor, consumidor y ancho cuando está aprobado; cada bloque agrega responsabilidad, comportamiento temporal y criterios para su futura verificación. El [informe de verificación de interfaces](interfaces_audit.md) registra las correcciones y el alcance comprobado.

## 0. Alcance y reglas comunes

### 0.1 Autoridad y lectura

La [consigna](consigna.md) y los [requisitos](requirements.md) fijan las obligaciones. Las [decisiones aprobadas](decisions.md), con sus revisiones explícitas, fijan la arquitectura; los [documentos de arquitectura](../README.md#arquitectura-vigente) la consolidan. Este documento concreta sus interfaces sin aprobar nuevas políticas. Ante una discrepancia se consulta la revisión aprobada aplicable; una conclusión histórica sustituida no es una opción implementable.

En particular, DEC-ARCH-003 acuerdo 47 prevalece: IF detecta, IF/ID transporta y **ID confirma todo fetch fault**; existen **ocho acciones**. El acuerdo 44 fija la FSM de 14 estados y sustituye los registros globales `terminal_kind` y `drain_auto` por predicados del estado actual.

Los bloques son unidades funcionales de conexión. No se exige un archivo o módulo SystemVerilog por cada sumador, mux o bloque de control; la agrupación RTL deberá conservar estos contratos. Los nombres de señales aprobados se preservan. Etiquetas como `Read Address`, `Write Data`, `capture` y `clear de sesión` identifican puertos o acciones locales: no obligan a usar espacios, barras o aliases gráficos como identificadores HDL.

### 0.2 Convenciones, anchos y codificaciones

- **[EXT]**: frontera con comandos, transporte, Debug o plataforma.
- **[CFG]**: configuración de elaboración; no es un bus dinámico.
- **[GLOBAL]**: clock, reset o control de sesión común.
- Una señal escalar de control, validez, selección binaria o evento tiene **1 bit**, salvo ancho explícito.
- Datos, PC, instrucciones, inmediatos, resultados y direcciones arquitectónicas tienen **32 bits**; índices de registros, **5 bits**. Los bits se transportan sin signo; la operación que los interpreta aplica signed/unsigned donde corresponde.
- `alu_op` tiene 6 bits; `result_sel` y selectores de forwarding, 2; `flow_op` y causas de fault, 3; `mem_op`, 4; `cycle_count`, 64 unsigned.
- `global_state` es un tipo simbólico de 14 estados. Su codificación binaria interna y su representación UART no se congelan aquí ni se presupone un bus físico de 4 bits.
- `loaded_image_size_bytes` y el tamaño privado validado del Loader deben representar la capacidad inclusive. Su ancho es `IMAGE_SIZE_WIDTH = max(1, ceil(log2(IMEM_CAPACITY_BYTES + 1)))`.
- `byte_enable` es una **interfaz semántica de selección de bytes**. Su ancho y el empaquetado físico por lanes no están fijados por los acuerdos: DMEM combina el tamaño del store con su dirección. No se presume una máscara física de cuatro bits ya desplazada.
- Las interfaces de stream, escritura de imagen, mantenimiento y snapshot se identifican como **parciales** cuando sus puertos o representación física no están fijados. No se inventan handshakes, grants o anchos de paquetes.
- Un slice `instruction[a:b]` o `ex_result[1:0]` es una conexión combinacional, no un registro adicional.

Las codificaciones de ALU y controles se toman de [Etapa ID](architecture/stage_id.md#codificación-de-los-controles); los selectores de forwarding de [Control y hazards](architecture/control_and_hazards.md#selectores); tamaño de memoria de [MEM Decode](architecture/stage_mem.md#mem-decode); causas de fault de [Faults](architecture/faults_and_termination.md#referencia-de-causas). Un código reservado no se emite para una operación legal; los residuos de una entrada inválida no producen efectos. No se añade una semántica arquitectónica para un estado artificial inválido.

### 0.3 Clock, reset, preparación y enables

Todos los registros funcionales, Loader, preparación, memorias, UART y Debug pertenecen al **mismo dominio funcional**. Los bloques combinacionales no tienen clock, reset ni enable de captura; sus salidas pueden variar durante HOLD sin causar un efecto registrado.

La plataforma REFERENCE es Basys 3: clock primario de 100 MHz y dominio funcional con objetivo de 50 MHz mediante un recurso dedicado. La configuración del generador, pines y XDC corresponden a integración, y el cumplimiento temporal se verificará después de implementación; véase DEC-ARCH-005.

El reset interno es activo en alto. La plataforma normaliza la fuente física y acondiciona un reset distribuido con **aserción asíncrona y liberación sincronizada**. La lógica funcional lo **consume síncronamente** en el flanco ascendente. No se distribuye la fuente externa cruda ni se convierte cada registro del CPU en un consumidor de reset asíncrono. Si existe `locked`, su ausencia solicita reset; su retorno no libera directamente los registros. Véase DEC-ARCH-008 y el acuerdo de estabilidad de DEC-ARCH-005.

Las interfaces secuenciales reciben implícitamente `clk` y, donde el contrato de estado lo exige, `reset`. La tabla siguiente explicita su alcance para evitar que la omisión gráfica se interprete como ausencia de reset:

| Estado / recurso | Efecto de reset funcional | Preparación de sesión | Enable ordinario |
|---|---|---|---|
| PC | `0` | `0` | `pc_write_enable` |
| Register File | `x0`–`x31` en cero lógico | cero lógico completo | `rf_write_fire` |
| IF/ID | `valid=0`, `fetch_fault_valid=0`; demás bits pueden retener residuos | ambos flags en cero | capture / hold / invalidate |
| ID/EX, EX/MEM, MEM/WB | `valid=0`; demás bits pueden retener residuos | `valid=0` | controles locales de actualización |
| Global FSM | `NO_IMAGE` | coordina fase, sin escribir el datapath | transiciones de sesión |
| `loaded_image_size_bytes` | `0` | solo PREPARING_READY publica el tamaño | clear por LOAD aceptado / commit |
| `cycle_count` | `0` | `0` antes del primer ciclo | `cpu_cycle_fire` |
| `fault_cause`, `fault_pc` | condición invalidada por Global FSM; no exige borrar bits | condición anterior deja de ser vigente | solo `fault_capture_fire` |
| IMEM | conserva array; imagen inválida por tamaño cero | no se borra para reutilizar imagen | escritura del Loader autorizado |
| DMEM y metadata | no exige borrar datos ni toda la metadata | establece cero lógico antes de `prepare_done` | store / mantenimiento con ownership |
| Loader / Session Preparation | aborta trabajo privado anterior; condición segura | progreso privado de su operación | actividad habilitada de su fase |
| Debug / transporte | no presentar una transacción o snapshot anterior como estado actual | memoria utilizada comienza vacía | mecanismo concreto pendiente |

Para la orden UART RESET, el [intercambio aprobado](decisions.md#acuerdo-parcial-de-dec-proto-002--intercambio-reset-con-aceptación-antes-del-reset-global) difiere la generación de la solicitud global hasta terminar físicamente `[RESET][ACCEPTED]`, incluido Stop del segundo byte; el botón físico aplica reset directamente. La prioridad siguiente rige cuando el reset funcional está activo. Durante la respuesta Debug no se reconocen solicitudes UART: PC espera completa y FPGA descarta RX; botón físico puede interrumpir. La realización del disparo queda para el diseño de bloques.

La prioridad común es **RESET > LOAD aceptado / preparación efectiva > ciclo CPU > HOLD**. Un LOAD rechazado no suprime un ciclo automático. Una frontera joven de halt/fault/redirect tampoco suprime commits MEM/WB anteriores. RESET impide escrituras CPU, Loader y mantenimiento en su flanco funcional; un LOAD aceptado impide efectos CPU previos e invalida candidatos/estado de la sesión abandonada antes de ejecutarla nuevamente.

`prepare_active` indica una fase, no es un write-enable. `prepare_done=1` certifica que el estado inicial ya está listo **antes del flanco** y que no hay writes de Loader/mantenimiento concurrentes. PREPARING_RUN/STEP puede ejecutar su primer ciclo en ese flanco y dejar `cycle_count=1`; PREPARING_READY publica imagen y queda READY con contador cero, sin ciclo CPU.

### 0.4 Tiempo y validez de las conexiones

Capturas, stores, writebacks y captura de metadata consumen valores **preflanco**; todos sus resultados registrados se observan postflanco. Un dato recién capturado en MEM/WB no se usa como un productor EX de ese mismo flanco.

Las lecturas de IMEM, DMEM y RF son combinacionales. Las escrituras son síncronas y no añaden una etapa, handshake ni stall de memoria. En HOLD (`cpu_cycle_fire=0` y sin acción global superior) PC, latches completos, RF y contador se retienen; no se repiten stores ni writebacks.

Una entrada con `valid=0` no es una instrucción. IF/ID conserva además `fetch_fault_valid` para el candidato separado. Los demás campos pueden retener residuos después de bubble o invalidación; no se exige borrar todos los bits ni registrar una NOP. Tampoco se agregan campos `uses_rsN`, `is_load`, `is_store`, `access_size`, `terminal_kind` o `drain_auto` a los latches.

### 0.5 Configuración y ownership

Las capacidades en bytes satisfacen `4 <= CAPACITY_BYTES <= 2^32` y son múltiplos de cuatro, sin exigir potencias de dos. Las constantes de capacidad deben representar `2^32` sin truncamiento; las comparaciones de extremos utilizan **33 bits unsigned**.

| Perfil | IMEM bytes | DMEM bytes | IMEM words / ancho de índice | DMEM words / ancho de índice | IMAGE_SIZE_WIDTH |
|---|---:|---:|---|---|---:|
| REFERENCE | 1024 | 2048 | 256 / 8 | 512 / 9 | 11 |
| ALT_1000 | 1000 | 1000 | 250 / 8 | 250 / 8 | 10 |

`WORD_COUNT=CAPACITY_BYTES/4`; cada ancho de índice es `max(1, ceil(log2(WORD_COUNT)))`. Configuración, software y loader deben utilizar el mismo perfil autoritativo. Un valor fuera del dominio se rechaza al elaborar; un perfil legal no soportado por un backend se distingue como error de configuración, no fault del programa.

PC, EA y offsets están expresados en bytes; IMEM y DMEM tienen base cero y espacios independientes. EA se forma módulo `2^32`, pero se comprueba **EA+N completo en 33 bits antes de indexar**. Fetch comprueba además imagen confirmada. Desalineación prevalece sobre rango para el mismo acceso. No se hace alias mediante truncamiento.

IMEM CPU/Loader y DMEM CPU/Debug/mantenimiento mantienen ownership exclusivo para operaciones incompatibles. IF y MEM pueden demandar simultáneamente sus memorias independientes. Una consulta directa de Debug requiere CPU quiescente y ownership de DMEM frente a otros accesos incompatibles, incluido mantenimiento; un snapshot aislado puede desacoplar su serialización. Un conflicto interno es una violación de implementación, no una octava causa de fault.

### 0.6 Estado de cierre

Las tablas de las secciones 1–9 concretan conexiones internas y contienen 54 bloques funcionales. La revisión documental comprueba sus fuentes, destinos, anchos y contratos. Las fronteras parciales se enumeran en la sección 15: no se declara cerrado el gate global de interfaces del sistema mientras falten sus puertos/representaciones y las decisiones aplicables. La selección y agrupación de módulos RTL tampoco queda acreditada por este documento.

---

# 1. Etapa IF

<a id="bloque-1-1"></a>

## 1.1 `PC Update Control`

**Tipo:** Combinacional. **Responsabilidad:** Convertir la acción del pipeline en enable y selección de PC.

**Contrato:** `pc_write_enable=act_normal || act_redirect`; `next_pc_sel=act_redirect`. Sin enable se retiene PC.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#pc). **Verificación futura:** Para las ocho acciones y ninguna, comprobar enable/selector y retención.

### Entradas

| Señal | Origen |
|---|---|
| `act_normal` | `Pipeline Hazard Control` |
| `act_redirect` | `Pipeline Hazard Control` |

### Salidas

| Señal | Destino |
|---|---|
| `pc_write_enable` | `PC.write_enable` |
| `next_pc_sel` | `Next PC MUX.sel` |

---

<a id="bloque-1-2"></a>

## 1.2 `Next PC MUX`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar el próximo PC de ejecución.

**Contrato:** Selector 0: PC+4; selector 1: redirect_target. La salida solo se captura con pc_write_enable.

**Fuente:** [contrato arquitectónico](architecture/stage_if.md#next-pc-mux). **Verificación futura:** Comprobar ambos caminos, también con targets distintos del PC global.

### Entradas

| Señal | Origen |
|---|---|
| `pc_plus_4[31:0]` | `PC Adder` |
| `redirect_target[31:0]` | `Target MUX` |
| `next_pc_sel` | `PC Update Control` |

### Salidas

| Señal | Destino |
|---|---|
| `next_pc[31:0]` | `PC` |

---

<a id="bloque-1-3"></a>

## 1.3 `PC`

**Tipo:** Registro funcional. **Responsabilidad:** Conservar la dirección de fetch global.

**Contrato:** Reset o preparación lo dejan en cero; captura next_pc solo con write_enable; en el resto retiene.

**Fuente:** [contrato arquitectónico](architecture/stage_if.md#pc). **Verificación futura:** Prioridad reset/preparación/avance; HOLD y stall; wrap secuencial módulo 2^32.

### Entradas

| Señal | Origen |
|---|---|
| `next_pc[31:0]` | `Next PC MUX` |
| `write_enable` | `PC Update Control.pc_write_enable` |
| inicialización / clear de sesión | `Session Preparation` |
| `reset` | [GLOBAL] reset del sistema |

### Salidas

| Señal | Destino |
|---|---|
| `PC[31:0]` | `PC Adder` |
| `PC[31:0]` | `Instruction Memory.Read Address` |
| `PC[31:0]` | `Fetch Fault Check` |
| `PC[31:0]` | `IF/ID Input Logic` |
| `PC[31:0]` | [EXT] Debug/Snapshot, contenido obligatorio |

---

<a id="bloque-1-4"></a>

## 1.4 `PC Adder`

**Tipo:** Combinacional. **Responsabilidad:** Formar la dirección secuencial siguiente.

**Contrato:** `pc_plus_4=(PC+4) mod 2^32`; no valida el fetch futuro.

**Fuente:** [contrato arquitectónico](architecture/stage_if.md#pc-adder). **Verificación futura:** PC alineado y wrap 0xFFFFFFFC → 0.

### Entradas

| Señal | Origen |
|---|---|
| `PC[31:0]` | `PC` |

### Salidas

| Señal | Destino |
|---|---|
| `pc_plus_4[31:0]` | `Next PC MUX` |

---

<a id="bloque-1-5"></a>

## 1.5 `Instruction Memory`

**Tipo:** Memoria: lectura combinacional / escritura síncrona. **Responsabilidad:** Proveer instrucciones y recibir words completas del Loader.

**Contrato:** Word little-endian de PC validado; write solo del Loader con ownership, word completa, dirección válida y sin reset. No hay salida registrada ni stall de memoria. Interfaz física de carga parcial.

**Fuente:** [contrato arquitectónico](architecture/memory_architecture.md#instruction-memory). **Verificación futura:** Carga word completa, imagen corta, índices de frontera y exclusión CPU/Loader en ambos perfiles.

### Entradas

| Señal | Origen |
|---|---|
| `Read Address[31:0]` | `PC` |
| interfaz de escritura de imagen | `Loader` |
| `IMEM_CAPACITY_BYTES` | [CFG] perfil autoritativo |

### Salidas

| Señal | Destino |
|---|---|
| `instruction[31:0]` | `IF/ID Input Logic` |

> La interfaz concreta de escritura del Loader puede implementarse con dirección/dato/write-enable; los nombres físicos no están fijados por este mapa.

---

<a id="bloque-1-6"></a>

## 1.6 `Fetch Fault Check`

**Tipo:** Combinacional. **Responsabilidad:** Detectar un candidato de fetch inválido.

**Contrato:** Misaligned si PC[1:0]!=0; rango exige imagen válida y PC+4 dentro de capacidad e imagen, sumado en 33 bits. Prioridad misaligned (000) sobre access (001). IF nunca confirma.

**Fuente:** [contrato arquitectónico](architecture/memory_architecture.md#validación-de-fetch). **Verificación futura:** Imagen vacía/corta, límite, desalineación simultánea con rango y ausencia de aliasing.

### Entradas

| Señal | Origen |
|---|---|
| `PC[31:0]` | `PC` |
| `image_valid` | derivado de `loaded_image_size_bytes != 0` |
| `loaded_image_size_bytes` | registro global `loaded_image_size_bytes` |
| `IMEM_CAPACITY_BYTES` | [CFG] configuración de memoria |

### Salidas

| Señal | Destino |
|---|---|
| `if_fetch_fault_candidate` | `IF/ID Input Logic` |
| `if_fetch_fault_cause[2:0]` | `IF/ID Input Logic` |

> **No hay** camino directo `Fetch Fault Check → Pipeline Hazard Control`.

---

<a id="bloque-1-7"></a>

## 1.7 `IF/ID Input Logic`

**Tipo:** Combinacional. **Responsabilidad:** Formar los cinco campos de entrada IF/ID.

**Contrato:** Fetch normal: valid=1, fetch_fault_valid=0, instruction=IMEM, cause=000. Candidato: valid=0, fetch_fault_valid=1, instruction=0 y causa recibida. En ambos pc=PC. Captura solo si act_normal.

**Fuente:** [contrato arquitectónico](architecture/stage_if.md#ifid-input-logic). **Verificación futura:** Flags excluyentes, word cero para candidato y candidato no capturado durante load-use.

### Entradas

| Señal | Origen |
|---|---|
| `PC[31:0]` | `PC` |
| `instruction[31:0]` | `Instruction Memory` |
| `if_fetch_fault_candidate` | `Fetch Fault Check` |
| `if_fetch_fault_cause[2:0]` | `Fetch Fault Check` |

### Salidas

| Señal | Destino |
|---|---|
| `ifid_in_valid` | `IF/ID.valid` |
| `ifid_in_pc[31:0]` | `IF/ID.pc` |
| `ifid_in_instruction[31:0]` | `IF/ID.instruction` |
| `ifid_in_fetch_fault_valid` | `IF/ID.fetch_fault_valid` |
| `ifid_in_fetch_fault_cause[2:0]` | `IF/ID.fetch_fault_cause` |

---

<a id="bloque-1-8"></a>

## 1.8 `IF/ID Update Control`

**Tipo:** Combinacional. **Responsabilidad:** Derivar capture, hold e invalidate de IF/ID.

**Contrato:** Capture con act_normal; hold con act_load_use/act_drain_load_use; invalidate con redirect/halt/fault EX/fault ID/drain_advance. Sin acción se retiene.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#ifid). **Verificación futura:** Acciones exclusivas; invalidación de ambos flags y retención completa en stall/HOLD.

### Entradas

Todas provienen de `Pipeline Hazard Control`.

| Señal | Origen |
|---|---|
| `act_ex_fault` | `Pipeline Hazard Control` |
| `act_halt` | `Pipeline Hazard Control` |
| `act_redirect` | `Pipeline Hazard Control` |
| `act_id_fault` | `Pipeline Hazard Control` |
| `act_load_use` | `Pipeline Hazard Control` |
| `act_normal` | `Pipeline Hazard Control` |
| `act_drain_load_use` | `Pipeline Hazard Control` |
| `act_drain_advance` | `Pipeline Hazard Control` |

### Salidas

| Señal | Destino |
|---|---|
| `capture` | `IF/ID.capture` |
| `hold` | `IF/ID.hold` |
| `invalidate` | `IF/ID.invalidate` |

---

<a id="bloque-1-9"></a>

## 1.9 Registro `IF/ID`

**Tipo:** Registro funcional. **Responsabilidad:** Transportar instrucción o candidato de fetch hacia ID.

**Contrato:** Cinco campos exactos. Capture toma entrada IF; hold conserva los cinco; invalidate/reset/preparación limpian ambos flags. Datos residuales no son instrucciones.

**Fuente:** [contrato arquitectónico](architecture/cpu_pipeline.md#registro-ifid). **Verificación futura:** Campos/anchos, next.valid y observación; nunca valid && fetch_fault_valid en ejecución legal.

### Entradas de datos

| Campo | Origen |
|---|---|
| `valid` | `IF/ID Input Logic.ifid_in_valid` |
| `pc[31:0]` | `IF/ID Input Logic.ifid_in_pc` |
| `instruction[31:0]` | `IF/ID Input Logic.ifid_in_instruction` |
| `fetch_fault_valid` | `IF/ID Input Logic.ifid_in_fetch_fault_valid` |
| `fetch_fault_cause[2:0]` | `IF/ID Input Logic.ifid_in_fetch_fault_cause` |

### Entradas de control

| Señal | Origen |
|---|---|
| `capture` | `IF/ID Update Control` |
| `hold` | `IF/ID Update Control` |
| `invalidate` | `IF/ID Update Control` |
| clear de sesión | `Session Preparation` |
| `reset` | [GLOBAL] reset funcional |

### Salidas

| Campo | Destino |
|---|---|
| `valid` | `ID Fault Check` |
| `valid` | `Load-Use Detector` |
| `valid` | entrada `ID/EX.valid` |
| `valid` | `Pipeline Empty Logic` |
| `pc[31:0]` | `ID Fault Check` |
| `pc[31:0]` | entrada `ID/EX.pc` |
| `instruction[31:0]` | `Decoder` |
| `instruction[31:0]` | `Immediate Generator` |
| `instruction[19:15]` | `Registers.Read Register 1` |
| `instruction[24:20]` | `Registers.Read Register 2` |
| `instruction[19:15]` | `Load-Use Detector` |
| `instruction[24:20]` | `Load-Use Detector` |
| `instruction[19:15]` | `WB Bypass Control` |
| `instruction[24:20]` | `WB Bypass Control` |
| `instruction[31:0]` | entrada `ID/EX.instruction` |
| `instruction[19:15]` | entrada `ID/EX.rs1` |
| `instruction[24:20]` | entrada `ID/EX.rs2` |
| `instruction[11:7]` | entrada `ID/EX.rd` |
| `fetch_fault_valid` | `ID Fault Check` |
| `fetch_fault_cause[2:0]` | `ID Fault Check` |

### Conexiones de próximo estado y observación

| Señal / contenido | Destino |
|---|---|
| `next.valid` (1 bit, combinacional) | `Pipeline Empty Logic.pipeline_empty_next` |
| `valid`, `pc[31:0]`, `instruction[31:0]` actuales | [EXT] Debug/Snapshot, mínimos obligatorios |

`fetch_fault_valid` y `fetch_fault_cause` son funcionales internos y su inclusión en Debug está aprobada por DEC-ARCH-009, distinguiendo candidato de fault confirmado; representación UART aprobada en D03/D05 y DEC-ARCH-009. `next.valid` describe la lógica D que captura el latch, no un quinto registro ni un campo persistente adicional.

---

# 2. Etapa ID

<a id="bloque-2-1"></a>

## 2.1 `Decoder`

**Tipo:** Combinacional. **Responsabilidad:** Reconocer el subconjunto y generar controles para EX.

**Contrato:** Whitelist completa de 32 RV32I más halt exacto 0x0000000B; señales/valores de control según Etapa ID. Ilegal: decode_legal=0, ADD/RS2/ALU/NONE/NONE, reg_write=uses_rs1=uses_rs2=0. No confirma fault.

**Fuente:** [contrato arquitectónico](architecture/stage_id.md#decoder). **Verificación futura:** 33 patrones legales con operandos variables, patrones vecinos ilegales, bits fijos de shifts y defaults neutros.

### Entradas

| Señal | Origen |
|---|---|
| `instruction[31:0]` | `IF/ID` |

### Salidas

| Señal | Destino |
|---|---|
| `decode_legal` | `ID Fault Check` |
| `alu_op[5:0]` | `ID/EX.alu_op` |
| `alu_src` | `ID/EX.alu_src` |
| `result_sel[1:0]` | `ID/EX.result_sel` |
| `flow_op[2:0]` | `ID/EX.flow_op` |
| `mem_op[3:0]` | `ID/EX.mem_op` |
| `reg_write` | `ID/EX.reg_write` |
| `uses_rs1` | `Load-Use Detector` |
| `uses_rs2` | `Load-Use Detector` |

---

<a id="bloque-2-2"></a>

## 2.2 `Registers`

**Tipo:** Estado con dos lecturas combinacionales y una escritura síncrona. **Responsabilidad:** Conservar los 32 registros arquitectónicos.

**Contrato:** Lee x0 siempre como cero; reset/preparación establecen cero lógico; escribe el rd y dato preflanco de MEM/WB solo con rf_write_fire. Bypass explícito externo a las lecturas base.

**Fuente:** [contrato arquitectónico](architecture/stage_wb.md#el-register-file-como-destino-de-wb). **Verificación futura:** x0, escrituras, lectura/escritura simultánea corregida por bypass, HOLD y preparación.

### Entradas

| Señal | Origen |
|---|---|
| `Read Register 1[4:0]` | `IF/ID.instruction[19:15]` |
| `Read Register 2[4:0]` | `IF/ID.instruction[24:20]` |
| `Write Register[4:0]` | `MEM/WB.rd` |
| `Write Data[31:0]` | `MEM/WB.wb_value` |
| `write_enable` | `WB Bypass Control.rf_write_fire` |
| clear / inicialización de sesión | `Session Preparation` |
| `reset` | [GLOBAL] reset funcional |

### Salidas

| Señal | Destino |
|---|---|
| `rf_rs1_value[31:0]` | `RS1 Bypass MUX` |
| `rf_rs2_value[31:0]` | `RS2 Bypass MUX` |
| contenido de RF (32 × 32 bits) | [EXT] Debug/Snapshot, contenido obligatorio |

---

<a id="bloque-2-3"></a>

## 2.3 `Immediate Generator`

**Tipo:** Combinacional. **Responsabilidad:** Reconstruir el inmediato de 32 bits.

**Contrato:** Formatos I/S/B/U/J según Datapath; offsets en bytes, B/J con bit cero incorporado, U con 12 ceros. Shifts consumen después immediate[4:0].

**Fuente:** [contrato arquitectónico](architecture/datapath.md#inmediato). **Verificación futura:** Signos, fronteras y bits fragmentados de cada formato; SRAI sin usar bits fijos como shamt.

### Entradas

| Señal | Origen |
|---|---|
| `instruction[31:0]` | `IF/ID` |

### Salidas

| Señal | Destino |
|---|---|
| `immediate[31:0]` | `ID/EX.immediate` |

---

<a id="bloque-2-4"></a>

## 2.4 `RS1 Bypass MUX`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar el valor base RS1 para ID/EX.

**Contrato:** bypass_rs1=1 selecciona MEM/WB.wb_value; 0 selecciona rf_rs1_value.

**Fuente:** [contrato arquitectónico](architecture/stage_id.md#rs1-bypass-mux). **Verificación futura:** Ambos caminos y fuente x0.

### Entradas

| Señal | Origen |
|---|---|
| `rf_rs1_value[31:0]` | `Registers` |
| `MEM/WB.wb_value[31:0]` | `MEM/WB` |
| `bypass_rs1` | `WB Bypass Control` |

### Salidas

| Señal | Destino |
|---|---|
| `rs1_value[31:0]` | `ID/EX.rs1_value` |

---

<a id="bloque-2-5"></a>

## 2.5 `RS2 Bypass MUX`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar el valor base RS2 para ID/EX.

**Contrato:** bypass_rs2=1 selecciona MEM/WB.wb_value; 0 selecciona rf_rs2_value.

**Fuente:** [contrato arquitectónico](architecture/stage_id.md#rs2-bypass-mux). **Verificación futura:** Ambos caminos y selecciones independientes RS1/RS2.

### Entradas

| Señal | Origen |
|---|---|
| `rf_rs2_value[31:0]` | `Registers` |
| `MEM/WB.wb_value[31:0]` | `MEM/WB` |
| `bypass_rs2` | `WB Bypass Control` |

### Salidas

| Señal | Destino |
|---|---|
| `rs2_value[31:0]` | `ID/EX.rs2_value` |

---

<a id="bloque-2-6"></a>

## 2.6 `WB Bypass Control`

**Tipo:** Combinacional. **Responsabilidad:** Habilitar writeback real y resolver coincidencia WB→ID.

**Contrato:** `rf_write_fire=cpu_cycle_fire && MEM/WB.valid && MEM/WB.reg_write && rd!=0`; cada bypass exige rf_write_fire y coincidencia de su fuente con rd.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#bypass-wb--id). **Verificación futura:** WB válido/inválido, rd=0, fuentes independientes y ninguna escritura o bypass nuevo en HOLD.

### Entradas

| Señal | Origen |
|---|---|
| `cpu_cycle_fire` | `Cycle Authorization` |
| `MEM/WB.valid` | `MEM/WB` |
| `MEM/WB.reg_write` | `MEM/WB` |
| `MEM/WB.rd[4:0]` | `MEM/WB` |
| `IF/ID.instruction[19:15]` | `IF/ID` |
| `IF/ID.instruction[24:20]` | `IF/ID` |

### Salidas

| Señal | Destino |
|---|---|
| `rf_write_fire` | `Registers.write_enable` |
| `bypass_rs1` | `RS1 Bypass MUX.sel` |
| `bypass_rs2` | `RS2 Bypass MUX.sel` |

---

<a id="bloque-2-7"></a>

## 2.7 `ID Fault Check`

**Tipo:** Combinacional. **Responsabilidad:** Unificar candidato ilegal y candidato de fetch registrado.

**Contrato:** `id_fault_candidate=(valid && !decode_legal) || (!valid && fetch_fault_valid)`; ilegal selecciona 010 y fetch copia cause; pc=IF/ID.pc. Metadatos sin candidato no se consumen. Confirmación pertenece al arbitraje.

**Fuente:** [contrato arquitectónico](architecture/faults_and_termination.md#confirmación-en-id). **Verificación futura:** Bubble residual, ilegal, fetch registrado y descarte ante frontera EX más antigua.

### Entradas

| Señal | Origen |
|---|---|
| `IF/ID.valid` | `IF/ID` |
| `IF/ID.pc[31:0]` | `IF/ID` |
| `IF/ID.fetch_fault_valid` | `IF/ID` |
| `IF/ID.fetch_fault_cause[2:0]` | `IF/ID` |
| `decode_legal` | `Decoder` |

### Salidas

| Señal | Destino |
|---|---|
| `id_fault_candidate` | `Pipeline Hazard Control` |
| `id_fault_cause[2:0]` | `Fault Metadata Control` |
| `id_fault_pc[31:0]` | `Fault Metadata Control` |

---

<a id="bloque-2-8"></a>

## 2.8 `Load-Use Detector`

**Tipo:** Combinacional. **Responsabilidad:** Detectar consumidor inmediato de un load.

**Contrato:** Exige IF/ID.valid, ID/EX.valid, is_load(ID/EX.mem_op), rd!=0 y coincidencia de rs1 o rs2 realmente utilizado. Usa usos de Decoder, no bits registrados adicionales.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#detección). **Verificación futura:** ALU, branch, JALR, base/dato de store; falsas dependencias por inmediatos, x0 y entradas inválidas.

### Entradas

| Señal | Origen |
|---|---|
| `IF/ID.valid` | `IF/ID` |
| `rs1[4:0]` | `IF/ID.instruction[19:15]` |
| `rs2[4:0]` | `IF/ID.instruction[24:20]` |
| `uses_rs1` | `Decoder` |
| `uses_rs2` | `Decoder` |
| `ID/EX.valid` | `ID/EX` |
| `ID/EX.rd[4:0]` | `ID/EX` |
| `ID/EX.mem_op[3:0]` | `ID/EX` |

### Salidas

| Señal | Destino |
|---|---|
| `load_use_stall` | `Pipeline Hazard Control` |

---

<a id="bloque-2-9"></a>

## 2.9 `ID/EX Update Control`

**Tipo:** Combinacional. **Responsabilidad:** Derivar captura o bubble de ID/EX.

**Contrato:** Capture con normal/drain_advance; bubble con load-use/redirect/halt/fault EX/fault ID/drain_load_use. Sin acción retiene.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#idex). **Verificación futura:** Las ocho acciones y HOLD, sin borrar obligatoriamente datos de bubble.

### Entradas

Todas provienen de `Pipeline Hazard Control`.

| Señal |
|---|
| `act_ex_fault` |
| `act_halt` |
| `act_redirect` |
| `act_id_fault` |
| `act_load_use` |
| `act_normal` |
| `act_drain_load_use` |
| `act_drain_advance` |

### Salidas

| Señal | Destino |
|---|---|
| `capture` | `ID/EX.capture` |
| `bubble` | `ID/EX.bubble` |

---

<a id="bloque-2-10"></a>

## 2.10 Registro `ID/EX`

**Tipo:** Registro funcional. **Responsabilidad:** Conservar identidad, operandos base, inmediato y seis controles para EX.

**Contrato:** Quince campos exactos; capture toma ID preflanco y valores posbypass; bubble/reset/preparación dejan valid=0. uses_rsN no se registra.

**Fuente:** [contrato arquitectónico](architecture/cpu_pipeline.md#registro-idex). **Verificación futura:** Esquema, propagación de control/identidad, prioridades y next.valid.

### Entradas de datos

| Campo | Origen |
|---|---|
| `valid` | `IF/ID.valid` |
| `pc[31:0]` | `IF/ID.pc` |
| `instruction[31:0]` | `IF/ID.instruction` |
| `rs1[4:0]` | `IF/ID.instruction[19:15]` |
| `rs2[4:0]` | `IF/ID.instruction[24:20]` |
| `rd[4:0]` | `IF/ID.instruction[11:7]` |
| `rs1_value[31:0]` | `RS1 Bypass MUX` |
| `rs2_value[31:0]` | `RS2 Bypass MUX` |
| `immediate[31:0]` | `Immediate Generator` |
| `alu_op[5:0]` | `Decoder` |
| `alu_src` | `Decoder` |
| `result_sel[1:0]` | `Decoder` |
| `flow_op[2:0]` | `Decoder` |
| `mem_op[3:0]` | `Decoder` |
| `reg_write` | `Decoder` |

### Entradas de control

| Señal | Origen |
|---|---|
| `capture` | `ID/EX Update Control` |
| `bubble` | `ID/EX Update Control` |
| clear de sesión | `Session Preparation` |
| `reset` | [GLOBAL] reset funcional |

### Salidas

| Campo | Destino |
|---|---|
| `valid` | `Forwarding Unit` |
| `valid` | `Load-Use Detector` |
| `valid` | `Flow Control` |
| `valid` | `EX Flow Check` |
| `valid` | `EX/MEM.valid` |
| `valid` | `Pipeline Empty Logic` |
| `pc[31:0]` | `Link Adder` |
| `pc[31:0]` | `Target Adder` |
| `pc[31:0]` | `EX/MEM.pc` |
| `pc[31:0]` | `Fault Metadata Control` para fault EX |
| `instruction[31:0]` | `Forwarding Unit` |
| `instruction[31:0]` | `EX/MEM.instruction` |
| `rs1[4:0]` | `Forwarding Unit` |
| `rs2[4:0]` | `Forwarding Unit` |
| `rd[4:0]` | `Load-Use Detector` |
| `rd[4:0]` | `EX/MEM.rd` |
| `rs1_value[31:0]` | `Forward MUX A` |
| `rs2_value[31:0]` | `Forward MUX B` |
| `immediate[31:0]` | `ALUSrc MUX` |
| `immediate[31:0]` | `Result MUX` |
| `immediate[31:0]` | `Target Adder` |
| `immediate[31:0]` | `JALR Adder` |
| `immediate[31:0]` | `EX Flow Check` |
| `alu_op[5:0]` | `ALU` |
| `alu_src` | `ALUSrc MUX.sel` |
| `result_sel[1:0]` | `Result MUX.sel` |
| `flow_op[2:0]` | `Flow Control` |
| `mem_op[3:0]` | `EX Flow Check` |
| `mem_op[3:0]` | `EX/MEM.mem_op` |
| `reg_write` | `EX/MEM.reg_write` |

### Conexiones de próximo estado y observación

| Señal / contenido | Destino |
|---|---|
| `next.valid` (1 bit, combinacional) | `Pipeline Empty Logic.pipeline_empty_next` |
| `valid`, `pc[31:0]`, `instruction[31:0]` actuales | [EXT] Debug/Snapshot, mínimos obligatorios |

Todos los campos funcionales registrados forman parte del snapshot según el acuerdo parcial de DEC-ARCH-009; su representación UART se completa en D05. `next.valid` describe la lógica D que captura el latch, no un campo persistente adicional.

---

# 3. Etapa EX

<a id="bloque-3-1"></a>

## 3.1 `Forwarding Unit`

**Tipo:** Combinacional. **Responsabilidad:** Elegir el productor más reciente para cada fuente EX.

**Contrato:** Usos se derivan de ID/EX.instruction. Match cualificado exige validez, uso real, reg_write y rd!=0. EX/MEM domina; load no reenvía dirección pero bloquea una versión vieja MEM/WB por exmem_match. Selectores 00/01/10; no emite 11.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#forwarding-hacia-ex). **Verificación futura:** Productores dobles, fuentes independientes, x0 y load que oculta una versión vieja; caso imposible de consumidor inmediato separado como artificial.

### Entradas

| Señal | Origen |
|---|---|
| `ID/EX.valid` | `ID/EX` |
| `ID/EX.instruction[31:0]` | `ID/EX` |
| `ID/EX.rs1[4:0]` | `ID/EX` |
| `ID/EX.rs2[4:0]` | `ID/EX` |
| `EX/MEM.valid` | `EX/MEM` |
| `EX/MEM.rd[4:0]` | `EX/MEM` |
| `EX/MEM.reg_write` | `EX/MEM` |
| `EX/MEM.mem_op[3:0]` | `EX/MEM` |
| `MEM/WB.valid` | `MEM/WB` |
| `MEM/WB.rd[4:0]` | `MEM/WB` |
| `MEM/WB.reg_write` | `MEM/WB` |

### Salidas

| Señal | Destino |
|---|---|
| `forward_a_sel[1:0]` | `Forward MUX A.sel` |
| `forward_b_sel[1:0]` | `Forward MUX B.sel` |

---

<a id="bloque-3-2"></a>

## 3.2 `Forward MUX A`

**Tipo:** Combinacional. **Responsabilidad:** Formar RS1 efectivo.

**Contrato:** 00: base ID/EX; 01: EX/MEM.ex_result; 10: MEM/WB.wb_value. Usa exclusivamente forward_a_sel. Resultado alimenta ALU, JALR y validación EX.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#forward-mux-a). **Verificación futura:** Tres fuentes y coherencia de todos los consumidores del operando.

### Entradas

| Señal | Origen |
|---|---|
| base `ID/EX.rs1_value[31:0]` | `ID/EX` |
| `EX/MEM.ex_result[31:0]` | `EX/MEM` |
| `MEM/WB.wb_value[31:0]` | `MEM/WB` |
| `forward_a_sel[1:0]` | `Forwarding Unit` |

### Salidas

| Señal | Destino |
|---|---|
| `rs1_effective[31:0]` | `ALU.A` |
| `rs1_effective[31:0]` | `JALR Adder` |
| `rs1_effective[31:0]` | `EX Flow Check` |

---

<a id="bloque-3-3"></a>

## 3.3 `Forward MUX B`

**Tipo:** Combinacional. **Responsabilidad:** Formar RS2 efectivo y dato de store.

**Contrato:** 00: base ID/EX; 01: EX/MEM.ex_result; 10: MEM/WB.wb_value. Usa exclusivamente forward_b_sel. El dato de store no se sustituye por immediate.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#forward-mux-b). **Verificación futura:** Tres fuentes; forwarding de datos de store independiente de ALUSrc.

### Entradas

| Señal | Origen |
|---|---|
| base `ID/EX.rs2_value[31:0]` | `ID/EX` |
| `EX/MEM.ex_result[31:0]` | `EX/MEM` |
| `MEM/WB.wb_value[31:0]` | `MEM/WB` |
| `forward_b_sel[1:0]` | `Forwarding Unit` |

### Salidas

| Señal | Destino |
|---|---|
| `rs2_effective[31:0]` | `ALUSrc MUX` |
| `rs2_effective[31:0]` | `EX/MEM.store_data` |

---

<a id="bloque-3-4"></a>

## 3.4 `ALUSrc MUX`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar segundo operando de ALU.

**Contrato:** alu_src=0 selecciona rs2_effective; 1 selecciona immediate. No altera store_data.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#alu-source-mux). **Verificación futura:** Operación registro/immediate y store con dirección/dato separados.

### Entradas

| Señal | Origen |
|---|---|
| `rs2_effective[31:0]` | `Forward MUX B` |
| `ID/EX.immediate[31:0]` | `ID/EX` |
| `alu_src` | `ID/EX` |

### Salidas

| Señal | Destino |
|---|---|
| `alu_operand_b[31:0]` | `ALU.B` |

---

<a id="bloque-3-5"></a>

## 3.5 `ALU`

**Tipo:** Combinacional. **Responsabilidad:** Ejecutar aritmética, lógica, shifts y comparaciones RV32.

**Contrato:** Operaciones y códigos según Datapath/Etapa ID; ADD/SUB módulo 2^32; shifts usan B[4:0], SRA signed; SLT signed y SLTU unsigned. En SUB, zero expresa igualdad entre los operandos efectivos para BEQ/BNE.

**Fuente:** [contrato arquitectónico](architecture/datapath.md#alu). **Verificación futura:** Diez operaciones, shamt 0/31, signo y wrap; código NOR previo no emitido por decoder legal.

### Entradas

| Señal | Origen |
|---|---|
| `A[31:0]` | `Forward MUX A.rs1_effective` |
| `B[31:0]` | `ALUSrc MUX.alu_operand_b` |
| `alu_op[5:0]` | `ID/EX` |

### Salidas

| Señal | Destino |
|---|---|
| `alu_result[31:0]` | `Result MUX` |
| `zero` | `Flow Control` |

---

<a id="bloque-3-6"></a>

## 3.6 `Link Adder`

**Tipo:** Combinacional. **Responsabilidad:** Formar enlace de la instrucción EX.

**Contrato:** `link_value=(ID/EX.pc+4) mod 2^32`; nunca usa el PC global.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#link-adder). **Verificación futura:** PC propio distinto del global y wrap.

### Entradas

| Señal | Origen |
|---|---|
| `ID/EX.pc[31:0]` | `ID/EX` |

### Salidas

| Señal | Destino |
|---|---|
| `link_value[31:0] = pc + 4` | `Result MUX` |

---

<a id="bloque-3-7"></a>

## 3.7 `Result MUX`

**Tipo:** Combinacional. **Responsabilidad:** Consolidar el resultado que se registra en EX/MEM.

**Contrato:** result_sel 00: ALU; 01: immediate; 10: link; 11 reservado.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#result-mux). **Verificación futura:** Resultado ALU/EA, LUI y enlace JAL/JALR; no campos alternativos registrados.

### Entradas

| Señal | Origen |
|---|---|
| `alu_result[31:0]` | `ALU` |
| `immediate[31:0]` | `ID/EX` |
| `link_value[31:0]` | `Link Adder` |
| `result_sel[1:0]` | `ID/EX` |

### Salidas

| Señal | Destino |
|---|---|
| `ex_result[31:0]` | `EX/MEM.ex_result` |

---

<a id="bloque-3-8"></a>

## 3.8 `Target Adder`

**Tipo:** Combinacional. **Responsabilidad:** Calcular target de branch/JAL relativo a su PC.

**Contrato:** `pc_relative_target=(ID/EX.pc+immediate) mod 2^32`. Solo se aplica si redirect aprobado.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#target-adder). **Verificación futura:** Offsets positivos/negativos y PC propio.

### Entradas

| Señal | Origen |
|---|---|
| `ID/EX.pc[31:0]` | `ID/EX` |
| `ID/EX.immediate[31:0]` | `ID/EX` |

### Salidas

| Señal | Destino |
|---|---|
| `pc_relative_target[31:0]` | `Target MUX` |

---

<a id="bloque-3-9"></a>

## 3.9 `JALR Adder`

**Tipo:** Combinacional. **Responsabilidad:** Sumar base efectiva e inmediato de JALR.

**Contrato:** `jalr_sum=(rs1_effective+immediate) mod 2^32`; la base incluye forwarding.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#jalr-adder). **Verificación futura:** Base reenviada y wrap; sin limpiar bit 1.

### Entradas

| Señal | Origen |
|---|---|
| `rs1_effective[31:0]` | `Forward MUX A` |
| `ID/EX.immediate[31:0]` | `ID/EX` |

### Salidas

| Señal | Destino |
|---|---|
| `jalr_sum[31:0]` | `Clear bit 0` |

---

<a id="bloque-3-10"></a>

## 3.10 `Clear bit 0`

**Tipo:** Combinacional. **Responsabilidad:** Aplicar la regla de bit cero de JALR.

**Contrato:** `jalr_target=jalr_sum & 0xFFFFFFFE`; solo limpia bit 0, no redondea a múltiplo de cuatro.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#clear-bit-0). **Verificación futura:** Targets con bits bajos 00,01,10,11; bit 1 conserva posible misalignment.

### Entradas

| Señal | Origen |
|---|---|
| `jalr_sum[31:0]` | `JALR Adder` |

### Salidas

| Señal | Destino |
|---|---|
| `jalr_target[31:0]` | `Target MUX` |

---

<a id="bloque-3-11"></a>

## 3.11 `Target MUX`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar target relativo o indirecto.

**Contrato:** target_sel=0: relativo; 1: JALR. Sale simultáneamente a validación EX y Next PC MUX.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#target-mux). **Verificación futura:** Ambas fuentes y mismo target para validar/aplicar.

### Entradas

| Señal | Origen |
|---|---|
| `pc_relative_target[31:0]` | `Target Adder` |
| `jalr_target[31:0]` | `Clear bit 0` |
| `target_sel` | `Flow Control` |

### Salidas

| Señal | Destino |
|---|---|
| `redirect_target[31:0]` | `Next PC MUX` |
| `redirect_target[31:0]` | `EX Flow Check` |

---

<a id="bloque-3-12"></a>

## 3.12 `Flow Control`

**Tipo:** Combinacional. **Responsabilidad:** Clasificar control de flujo, branch tomado y halt candidato.

**Contrato:** target_sel=(flow_op==JALR); redirect_requested=valid && ((BEQ && zero)||(BNE && !zero)||JAL||JALR); ex_halt_candidate=valid && HALT. No confirma ni escribe PC.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#flow-control). **Verificación futura:** BEQ/BNE tomados/no tomados, jumps, halt y entrada inválida.

### Entradas

| Señal | Origen |
|---|---|
| `ID/EX.valid` | `ID/EX` |
| `ID/EX.flow_op[2:0]` | `ID/EX` |
| `ALU.zero` | `ALU` |

### Salidas

| Señal | Destino |
|---|---|
| `target_sel` | `Target MUX.sel` |
| `redirect_requested` | `EX Flow Check` |
| `redirect_requested` | `Pipeline Hazard Control` |
| `ex_halt_candidate` | `Pipeline Hazard Control` |

---

<a id="bloque-3-13"></a>

## 3.13 `EX Flow Check`

**Tipo:** Combinacional. **Responsabilidad:** Validar accesos de datos y targets tomados en EX.

**Contrato:** EA=(rs1_effective+immediate) mod 2^32; N=1/2/4 según mem_op; rango completo EA+N en 33 bits y alineación natural. Candidatos cualificados por valid y clase; misalignment precede acceso. Target solo se valida con redirect_requested; target alineado fuera de imagen corresponde a fetch posterior en IF.

**Fuente:** [contrato arquitectónico](architecture/stage_ex.md#ex-flow-check). **Verificación futura:** Cinco causas posibles EX, región extrema, carry permitido, branch no tomado y JALR tras limpiar bit 0.

### Entradas

| Señal | Origen |
|---|---|
| `ID/EX.valid` | `ID/EX` |
| `ID/EX.mem_op[3:0]` | `ID/EX` |
| `rs1_effective[31:0]` | `Forward MUX A` |
| `ID/EX.immediate[31:0]` | `ID/EX` |
| `redirect_requested` | `Flow Control` |
| `redirect_target[31:0]` | `Target MUX` |
| `DMEM_CAPACITY_BYTES` | [CFG] configuración de memoria |

### Salidas

| Señal | Destino |
|---|---|
| `ex_fault_candidate` | `Pipeline Hazard Control` |
| `ex_fault_cause[2:0]` | `Fault Metadata Control` |

---

<a id="bloque-3-14"></a>

## 3.14 `EX/MEM Update Control`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar captura o invalidación de EX/MEM.

**Contrato:** Capture con normal/load-use/redirect/fault ID/drain_load_use/drain_advance; invalidate con halt/fault EX; sin acción retiene.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#exmem). **Verificación futura:** Enlace continúa tras redirect; instrucción EX anterior continúa ante fault ID.

### Entradas

Todas provienen de `Pipeline Hazard Control`.

| Señal |
|---|
| `act_ex_fault` |
| `act_halt` |
| `act_redirect` |
| `act_id_fault` |
| `act_load_use` |
| `act_normal` |
| `act_drain_load_use` |
| `act_drain_advance` |

### Salidas

| Señal | Destino |
|---|---|
| `capture` | `EX/MEM.capture` |
| `invalidate` | `EX/MEM.invalidate` |

---

<a id="bloque-3-15"></a>

## 3.15 Registro `EX/MEM`

**Tipo:** Registro funcional. **Responsabilidad:** Conservar resultado EX y dato de store separados.

**Contrato:** Ocho campos exactos; capture toma EX preflanco; invalidate/reset/preparación dejan valid=0. No registra immediate, operandos base, alu_result o link separados.

**Fuente:** [contrato arquitectónico](architecture/cpu_pipeline.md#registro-exmem). **Verificación futura:** Esquema, continuidad de anteriores, dato posforwarding y next.valid.

### Entradas de datos

| Campo | Origen |
|---|---|
| `valid` | `ID/EX.valid` |
| `pc[31:0]` | `ID/EX.pc` |
| `instruction[31:0]` | `ID/EX.instruction` |
| `rd[4:0]` | `ID/EX.rd` |
| `reg_write` | `ID/EX.reg_write` |
| `mem_op[3:0]` | `ID/EX.mem_op` |
| `ex_result[31:0]` | `Result MUX` |
| `store_data[31:0]` | `Forward MUX B.rs2_effective` |

### Entradas de control

| Señal | Origen |
|---|---|
| `capture` | `EX/MEM Update Control` |
| `invalidate` | `EX/MEM Update Control` |
| clear de sesión | `Session Preparation` |
| `reset` | [GLOBAL] reset funcional |

### Salidas

| Campo | Destino |
|---|---|
| `valid` | `Forwarding Unit` |
| `valid` | `DMEM Write Control` |
| `valid` | `MEM/WB.valid` |
| `valid` | `Pipeline Empty Logic` |
| `pc[31:0]` | `MEM/WB.pc` |
| `instruction[31:0]` | `MEM/WB.instruction` |
| `rd[4:0]` | `Forwarding Unit` |
| `rd[4:0]` | `MEM/WB.rd` |
| `reg_write` | `Forwarding Unit` |
| `reg_write` | `MEM/WB.reg_write` |
| `mem_op[3:0]` | `Forwarding Unit` |
| `mem_op[3:0]` | `MEM Decode` |
| `mem_op[3:0]` | `DMEM Write Control` |
| `ex_result[31:0]` | `Forward MUX A` |
| `ex_result[31:0]` | `Forward MUX B` |
| `ex_result[31:0]` | `Data Memory.Address` |
| `ex_result[1:0]` | `Load Select/Extend.address_low_bits` |
| `ex_result[31:0]` | `WB Value MUX` |
| `store_data[31:0]` | `Data Memory.Write Data` |

### Conexiones de próximo estado y observación

| Señal / contenido | Destino |
|---|---|
| `next.valid` (1 bit, combinacional) | `Pipeline Empty Logic.pipeline_empty_next` |
| `valid`, `pc[31:0]`, `instruction[31:0]` actuales | [EXT] Debug/Snapshot, mínimos obligatorios |

Todos los campos funcionales registrados forman parte del snapshot según el acuerdo parcial de DEC-ARCH-009; su representación UART se completa en D05. `next.valid` describe la lógica D que captura el latch, no un campo persistente adicional.

---

# 4. Etapa MEM

<a id="bloque-4-1"></a>

## 4.1 `MEM Decode`

**Tipo:** Combinacional. **Responsabilidad:** Derivar clase, tamaño y selección de MEM desde mem_op.

**Contrato:** is_load para LB/LH/LW/LBU/LHU; is_store para SB/SH/SW; size 00/01/10: 1/2/4 bytes; unsigned solo LBU/LHU; wb_value_sel=is_load. is_load puede ser interno.

**Fuente:** [contrato arquitectónico](architecture/stage_mem.md#mem-decode). **Verificación futura:** Nueve códigos definidos, tamaño/signo y ausencia de acceso efectivo por residuos.

### Entradas

| Señal | Origen |
|---|---|
| `EX/MEM.mem_op[3:0]` | `EX/MEM` |

### Salidas externas necesarias

| Señal | Destino |
|---|---|
| `is_store` | `DMEM Write Control` |
| `access_size[1:0]` | `Load Select/Extend` |
| `load_unsigned` | `Load Select/Extend` |
| `wb_value_sel` | `WB Value MUX.sel` |

### Señal derivada interna

| Señal | Uso |
|---|---|
| `is_load` | Se usa internamente para derivar `wb_value_sel`; no necesita ser un puerto externo si ningún otro bloque la consume. |

> `is_load` se mantiene interno cuando solo deriva `wb_value_sel`. Una salida adicional requiere un consumidor explícito; no se agrega aquí un pulso de acceso ni un campo registrado.

---

<a id="bloque-4-2"></a>

## 4.2 `Data Memory`

**Tipo:** Memoria: lectura combinacional / escritura síncrona. **Responsabilidad:** Conservar datos y validez por byte de la sesión.

**Contrato:** Byte no escrito se lee cero lógico. Store actualiza bytes seleccionados y su metadata con el mismo fire; resto retiene. DMEM resuelve dirección + selección semántica de bytes y little-endian. Preparación y lectura Debug respetan ownership; empaquetado físico de lanes parcial.

**Fuente:** [contrato arquitectónico](architecture/memory_architecture.md#data-memory). **Verificación futura:** SB/SH/SW parciales, lectura signed/unsigned, datos y validez atómicos, cero lógico y ambos perfiles.

### Entradas CPU

| Señal | Origen |
|---|---|
| `Address[31:0]` | `EX/MEM.ex_result` |
| `Write Data[31:0]` | `EX/MEM.store_data` |
| `write_enable` | `DMEM Write Control.dmem_store_fire` |
| `byte_enable` | `DMEM Write Control.byte_enable` |
| `DMEM_CAPACITY_BYTES` | [CFG] perfil autoritativo |

### Entradas de mantenimiento

| Señal | Origen |
|---|---|
| clear / preparación de sesión | `Session Preparation` |

### Salidas

| Señal | Destino |
|---|---|
| `mem_read_data[31:0]` | `Load Select/Extend` |
| contenido / metadata observable | [EXT] Debug/Snapshot, si corresponde |

---

<a id="bloque-4-3"></a>

## 4.3 `Load Select/Extend`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar bytes del load y extenderlos a 32 bits.

**Contrato:** Dirección baja, tamaño y lectura definen selección little-endian antes de extensión; BYTE/HALFWORD signed o unsigned; WORD sin extensión. Si DMEM preselecciona bytes, el adaptador conserva la misma semántica; su empaquetado físico no queda congelado.

**Fuente:** [contrato arquitectónico](architecture/stage_mem.md#load-select--extend). **Verificación futura:** LB/LBU en cuatro posiciones, LH/LHU en dos pares alineados, LW; bytes negativos y cero lógico.

### Entradas

| Señal | Origen |
|---|---|
| `mem_read_data[31:0]` | `Data Memory` |
| `address_low_bits[1:0]` | `EX/MEM.ex_result[1:0]` |
| `access_size[1:0]` | `MEM Decode` |
| `load_unsigned` | `MEM Decode` |

### Salidas

| Señal | Destino |
|---|---|
| `load_value[31:0]` | `WB Value MUX` |

---

<a id="bloque-4-4"></a>

## 4.4 `WB Value MUX`

**Tipo:** Combinacional. **Responsabilidad:** Formar el único dato destinado a MEM/WB.

**Contrato:** wb_value_sel=0 toma EX/MEM.ex_result; 1 toma load_value. Un valor combinacional sin validez/reg_write no produce writeback.

**Fuente:** [contrato arquitectónico](architecture/stage_mem.md#wb-value-mux). **Verificación futura:** Load y resultados ALU/LUI/link, captura preflanco.

### Entradas

| Señal | Origen |
|---|---|
| `EX/MEM.ex_result[31:0]` | `EX/MEM` |
| `load_value[31:0]` | `Load Select/Extend` |
| `wb_value_sel` | `MEM Decode` |

### Salidas

| Señal | Destino |
|---|---|
| `wb_value[31:0]` | `MEM/WB.wb_value` |

---

<a id="bloque-4-5"></a>

## 4.5 `DMEM Write Control`

**Tipo:** Combinacional. **Responsabilidad:** Autorizar commit de store y selección semántica de bytes.

**Contrato:** `dmem_store_fire=cpu_cycle_fire && EX/MEM.valid && is_store`; selección por SB/SH/SW, con dirección aplicada en DMEM. Mismo fire para datos y metadata. No incluye veto por fault/halt joven.

**Fuente:** [contrato arquitectónico](architecture/stage_mem.md#dmem-write-control). **Verificación futura:** Store anterior frente a frontera joven, ninguna repetición en HOLD, tamaño y atomicidad.

### Entradas

| Señal | Origen |
|---|---|
| `cpu_cycle_fire` | `Cycle Authorization` |
| `EX/MEM.valid` | `EX/MEM` |
| `is_store` | `MEM Decode` |
| `EX/MEM.mem_op[3:0]` | `EX/MEM` |

### Salidas

| Señal | Destino |
|---|---|
| `dmem_store_fire` / `write_enable` | `Data Memory.write_enable` |
| `byte_enable` | `Data Memory.byte_enable` |

`byte_enable` indica los bytes relativos al acceso que selecciona SB/SH/SW. DMEM aplica `EX/MEM.ex_result` para ubicar esos bytes: por ejemplo, SB en A escribe `store_data[7:0]` en `logical_byte[A]`, incluso si A está en el lane 3. No se fija el ancho/código de una máscara física ni se obliga a mover esta lógica al controlador. La adaptación a lanes debe verificarse con la dirección y el dato; ningún byte no seleccionado cambia.

---

<a id="bloque-4-6"></a>

## 4.6 `MEM/WB Update Control`

**Tipo:** Combinacional. **Responsabilidad:** Habilitar la captura del resultado MEM en MEM/WB.

**Contrato:** capture es OR de las ocho acciones; se captura MEM anterior aun si EX se descarta. Sin acción retiene.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#memwb). **Verificación futura:** Ocho acciones, HOLD y última instrucción de drain.

> El nombre funcional es `MEM/WB Update Control`; no se confunde con el control de EX/MEM.

### Entradas

Todas provienen de `Pipeline Hazard Control`.

| Señal |
|---|
| `act_ex_fault` |
| `act_halt` |
| `act_redirect` |
| `act_id_fault` |
| `act_load_use` |
| `act_normal` |
| `act_drain_load_use` |
| `act_drain_advance` |

### Salidas

| Señal | Destino |
|---|---|
| `capture` | `MEM/WB.capture` |

---

<a id="bloque-4-7"></a>

## 4.7 Registro `MEM/WB`

**Tipo:** Registro funcional. **Responsabilidad:** Conservar identidad y valor final de writeback.

**Contrato:** Seis campos exactos; captura EX/MEM y wb_value preflanco. Reset/preparación invalidan; no lleva mem_op ni resultados alternativos. Writeback simultáneo consume la entrada anterior.

**Fuente:** [contrato arquitectónico](architecture/cpu_pipeline.md#registro-memwb). **Verificación futura:** Esquema, load_value registrado, commit de entrada previa y next.valid.

### Entradas de datos

| Campo | Origen |
|---|---|
| `valid` | `EX/MEM.valid` |
| `pc[31:0]` | `EX/MEM.pc` |
| `instruction[31:0]` | `EX/MEM.instruction` |
| `rd[4:0]` | `EX/MEM.rd` |
| `reg_write` | `EX/MEM.reg_write` |
| `wb_value[31:0]` | `WB Value MUX` |

### Entradas de control

| Señal | Origen |
|---|---|
| `capture` | `MEM/WB Update Control` |
| clear de sesión | `Session Preparation` |
| `reset` | [GLOBAL] reset funcional |

### Salidas

| Campo | Destino |
|---|---|
| `valid` | `Forwarding Unit` |
| `valid` | `WB Bypass Control` |
| `valid` | `Pipeline Empty Logic` |
| `rd[4:0]` | `Forwarding Unit` |
| `rd[4:0]` | `WB Bypass Control` |
| `rd[4:0]` | `Registers.Write Register` |
| `reg_write` | `Forwarding Unit` |
| `reg_write` | `WB Bypass Control` |
| `wb_value[31:0]` | `Forward MUX A` |
| `wb_value[31:0]` | `Forward MUX B` |
| `wb_value[31:0]` | `RS1 Bypass MUX` |
| `wb_value[31:0]` | `RS2 Bypass MUX` |
| `wb_value[31:0]` | `Registers.Write Data` |
| `pc[31:0]` | [EXT] Debug/Snapshot |
| `instruction[31:0]` | [EXT] Debug/Snapshot |

### Conexiones de próximo estado y observación

| Señal / contenido | Destino |
|---|---|
| `next.valid` (1 bit, combinacional) | `Pipeline Empty Logic.pipeline_empty_next` |
| `valid`, `pc[31:0]`, `instruction[31:0]` actuales | [EXT] Debug/Snapshot, mínimos obligatorios |

Todos los campos funcionales registrados forman parte del snapshot según el acuerdo parcial de DEC-ARCH-009; su representación UART se completa en D05. `next.valid` describe la lógica D que captura el latch, no un campo persistente adicional.

---

# 5. Control central del pipeline

<a id="bloque-5-1"></a>

## 5.1 `Pipeline Hazard Control`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar una única acción dentro del ciclo autorizado.

**Contrato:** Sin ciclo no hay acciones. No terminal: fault EX > halt EX > redirect EX > fault ID > load-use > normal. Drain: load_use_stall decide entre las dos ramas. terminal_none/drain_active se derivan del estado actual.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#las-ocho-acciones-del-pipeline). **Verificación futura:** onehot0, prioridad completa, HOLD/terminal vacío; drain_load_use se prueba como estado artificial separado.

### Entradas

| Señal | Origen |
|---|---|
| `cpu_cycle_fire` | `Cycle Authorization` |
| `terminal_none` | `Global Status Decode` |
| `drain_active` | `Global Status Decode` |
| `ex_fault_candidate` | `EX Flow Check` |
| `ex_halt_candidate` | `Flow Control` |
| `redirect_requested` | `Flow Control` |
| `id_fault_candidate` | `ID Fault Check` |
| `load_use_stall` | `Load-Use Detector` |

### Salidas

| Señal | Destinos |
|---|---|
| `act_ex_fault` | `IF/ID Update Control`, `ID/EX Update Control`, `EX/MEM Update Control`, `MEM/WB Update Control`, `Fault Metadata Control` |
| `act_halt` | `IF/ID Update Control`, `ID/EX Update Control`, `EX/MEM Update Control`, `MEM/WB Update Control`, `Global FSM` como `halt_confirm` |
| `act_redirect` | `PC Update Control`, `IF/ID Update Control`, `ID/EX Update Control`, `EX/MEM Update Control`, `MEM/WB Update Control` |
| `act_id_fault` | `IF/ID Update Control`, `ID/EX Update Control`, `EX/MEM Update Control`, `MEM/WB Update Control`, `Fault Metadata Control` |
| `act_load_use` | `IF/ID Update Control`, `ID/EX Update Control`, `EX/MEM Update Control`, `MEM/WB Update Control` |
| `act_normal` | `PC Update Control`, `IF/ID Update Control`, `ID/EX Update Control`, `EX/MEM Update Control`, `MEM/WB Update Control` |
| `act_drain_load_use` | `IF/ID Update Control`, `ID/EX Update Control`, `EX/MEM Update Control`, `MEM/WB Update Control` |
| `act_drain_advance` | `IF/ID Update Control`, `ID/EX Update Control`, `EX/MEM Update Control`, `MEM/WB Update Control` |

> No debe existir `act_if_fault_exception`.

---

# 6. Metadata global de fault

<a id="bloque-6-1"></a>

## 6.1 `Fault Metadata Control`

**Tipo:** Combinacional. **Responsabilidad:** Seleccionar metadata y evento de captura del fault confirmado.

**Contrato:** fault_capture_fire=act_ex_fault || act_id_fault; EX selecciona su causa e ID/EX.pc, ID selecciona su causa e id_fault_pc=IF/ID.pc. No usa PC global ni captura solo por candidato.

**Fuente:** [contrato arquitectónico](architecture/faults_and_termination.md#captura). **Verificación futura:** EX frente a ID, candidato descartado, causas legales y retención en HOLD/drain.

### Entradas

| Señal | Origen |
|---|---|
| `act_ex_fault` | `Pipeline Hazard Control` |
| `act_id_fault` | `Pipeline Hazard Control` |
| `ex_fault_cause[2:0]` | `EX Flow Check` |
| `ID/EX.pc[31:0]` | `ID/EX` |
| `id_fault_cause[2:0]` | `ID Fault Check` |
| `id_fault_pc[31:0]` | `ID Fault Check` |

### Salidas

| Señal | Destino |
|---|---|
| `fault_capture_fire` | registro `fault_cause` |
| `fault_capture_fire` | registro `fault_pc` |
| `fault_capture_fire` | `Global FSM` como `fault_confirm` |
| `fault_cause_in[2:0]` | registro `fault_cause` |
| `fault_pc_in[31:0]` | registro `fault_pc` |

---

<a id="bloque-6-2"></a>

## 6.2 Registro global `fault_cause`

**Tipo:** Registro funcional de metadata. **Responsabilidad:** Conservar la causa del fault confirmado.

**Contrato:** Captura solo con fault_capture_fire y retiene en el resto; reset invalida interpretación por global_state sin exigir borrar bits. Solo siete causas legales, 011 reservado.

**Fuente:** [contrato arquitectónico](architecture/faults_and_termination.md#validez-de-la-metadata). **Verificación futura:** Captura única por sesión terminada en fault y estabilidad; residuos fuera de fault sin significado.

### Entradas

| Señal | Origen |
|---|---|
| `fault_cause_in[2:0]` | `Fault Metadata Control` |
| `capture` | `Fault Metadata Control.fault_capture_fire` |

### Salidas

| Señal | Destino |
|---|---|
| `fault_cause[2:0]` | [EXT] Debug/Status |

---

<a id="bloque-6-3"></a>

## 6.3 Registro global `fault_pc`

**Tipo:** Registro funcional de metadata. **Responsabilidad:** Conservar el PC del causante del fault.

**Contrato:** Captura solo con fault_capture_fire; ID usa IF/ID.pc y EX usa ID/EX.pc. No guarda dirección de datos ni target; retiene hasta otro fault de una sesión nueva.

**Fuente:** [contrato arquitectónico](architecture/faults_and_termination.md#captura). **Verificación futura:** Fetch, ilegal, load/store y target: PC propio correcto y estabilidad durante drain.

### Entradas

| Señal | Origen |
|---|---|
| `fault_pc_in[31:0]` | `Fault Metadata Control` |
| `capture` | `Fault Metadata Control.fault_capture_fire` |

### Salidas

| Señal | Destino |
|---|---|
| `fault_pc[31:0]` | [EXT] Debug/Status |

---

# 7. Vaciado del pipeline y estado terminal

<a id="bloque-7-1"></a>

## 7.1 `Pipeline Empty Logic`

**Tipo:** Combinacional. **Responsabilidad:** Calcular vacío actual y posterior al flanco.

**Contrato:** Cada salida niega el OR de los cuatro valid actuales o next; fetch_fault_valid no participa. next proviene de actualización de latches, no de next_state.

**Fuente:** [contrato arquitectónico](architecture/execution_control.md#pipeline-vacío). **Verificación futura:** Último valid consumido, sin ciclo vacío adicional y ausencia de realimentación combinacional.

Este bloque es lógica combinacional auxiliar; no contiene estado.

### Entradas para `pipeline_empty`

| Señal | Origen |
|---|---|
| `IF/ID.valid` | `IF/ID` |
| `ID/EX.valid` | `ID/EX` |
| `EX/MEM.valid` | `EX/MEM` |
| `MEM/WB.valid` | `MEM/WB` |

### Entradas para `pipeline_empty_next`

| Señal | Origen |
|---|---|
| `IF/ID.next.valid` | lógica de próximo estado de `IF/ID` |
| `ID/EX.next.valid` | lógica de próximo estado de `ID/EX` |
| `EX/MEM.next.valid` | lógica de próximo estado de `EX/MEM` |
| `MEM/WB.next.valid` | lógica de próximo estado de `MEM/WB` |

### Salidas

| Señal | Destino |
|---|---|
| `pipeline_empty` | `Global Status Decode` |
| `pipeline_empty_next` | `Global FSM` |

---

<a id="bloque-7-2"></a>

## 7.2 `Global Status Decode`

**Tipo:** Combinacional. **Responsabilidad:** Derivar fase terminal y necesidad de drain.

**Contrato:** terminal_none niega pertenencia a los cuatro DRAIN, FINISHED o FAULT; drain_active=terminal_active && !pipeline_empty. No agrega registros.

**Fuente:** [contrato arquitectónico](architecture/control_and_hazards.md#estado-terminal-y-drenado). **Verificación futura:** 14 estados y pipeline vacío/no vacío; distinguir drain_mode de drain_active.

> Lógica combinacional auxiliar para no mezclar estos predicados con la FSM registrada.

### Entradas

| Señal | Origen |
|---|---|
| `global_state` | `Global FSM` |
| `pipeline_empty` | `Pipeline Empty Logic` |

### Salidas

| Señal | Destino |
|---|---|
| `terminal_none` | `Pipeline Hazard Control` |
| `drain_active` | `Pipeline Hazard Control` |

---

# 8. Control global de sesión

<a id="bloque-8-1"></a>

## 8.1 `Command Arbiter`

**Tipo:** Combinacional. **Responsabilidad:** Filtrar solicitudes elegibles y resolver coincidencias.

**Contrato:** Prioridad RESET > LOAD > STEP > RUN tras elegibilidad por global_state. LOAD no elegible no cancela RUN automático. Solicitudes aceptadas son eventos de una sola operación, no niveles UART persistentes.

**Fuente:** [contrato arquitectónico](architecture/execution_control.md#aceptación-de-load-run-y-step). **Verificación futura:** 14 estados, ocho combinaciones LOAD/RUN/STEP y reset; aceptación mutuamente excluyente.

### Entradas

| Señal | Origen |
|---|---|
| solicitud `LOAD` | [EXT] interfaz de comandos/UART |
| solicitud `STEP` | [EXT] interfaz de comandos/UART |
| solicitud `RUN` | [EXT] interfaz de comandos/UART |
| `global_state` | `Global FSM` |
| `reset` | [GLOBAL] reset |

> Los nombres físicos de las solicitudes externas pueden definirse posteriormente. Lo importante es su origen y semántica.

### Salidas

| Señal | Destino |
|---|---|
| `load_accept` | `Global FSM` |
| `load_accept` | `Cycle Authorization` |
| `load_accept` | `Loader` / reinicio de nueva carga |
| `load_accept` | registro `loaded_image_size_bytes` para invalidar la imagen previa |
| `step_accept` | `Global FSM` |
| `step_accept` | `Cycle Authorization` |
| `run_accept` | `Global FSM` |
| `run_accept` | `Cycle Authorization` |

---

<a id="bloque-8-2"></a>

## 8.2 `Global FSM`

**Tipo:** Estado registrado y decodificación Moore. **Responsabilidad:** Conservar la fase global de sesión y calcular su próximo estado.

**Contrato:** 14 estados aprobados; reset→NO_IMAGE; LOAD aceptado→LOADING; load_ok→PREPARING_READY; prepare_done publica READY sin ciclo. Ciclos usan confirmación y pipeline_empty_next para terminal/drain según origen. Terminal RUN/STEP prepara sesión nueva. No escribe directamente datapath ni autoriza el ciclo actual con next_state.

**Fuente:** [contrato arquitectónico](architecture/execution_control.md#tabla-de-transiciones). **Verificación futura:** Todas las transiciones, rechazo LOAD continuo, resultado de confirmación, drain STEP→AUTO y sesiones reutilizadas.

FSM Moore de 14 estados.

### Entradas

| Señal | Origen |
|---|---|
| `reset` | [GLOBAL] reset |
| `load_accept` | `Command Arbiter` |
| `step_accept` | `Command Arbiter` |
| `run_accept` | `Command Arbiter` |
| `load_ok` | `Loader` |
| `load_fail` | `Loader` |
| `prepare_done` | `Session Preparation` |
| `halt_confirm` | `Pipeline Hazard Control.act_halt` |
| `fault_confirm` | `Fault Metadata Control.fault_capture_fire` |
| `pipeline_empty_next` | `Pipeline Empty Logic` |
| `cycle_from_continuous` | `Cycle Authorization` |

### Salidas principales

| Señal | Destino |
|---|---|
| `global_state` | `Command Arbiter` |
| `global_state` | `Cycle Authorization` |
| `global_state` | `Global Status Decode` |
| `global_state` | `Session Preparation` para distinguir PREPARING_READY/RUN/STEP |
| `global_state` | [EXT] Debug/Status |
| `loader_active` | `Loader` |
| `prepare_active` | `Session Preparation` |
| `program_finished` | [EXT] Debug/Status |
| `fault_info_valid` | [EXT] Debug/Status |

### Salidas Moore opcionales de estado

Si se dibujan explícitamente:

| Señal | Destino |
|---|---|
| `continuous_mode` | [EXT] Debug/Status, si se expone |
| `step_mode` | [EXT] Debug/Status, si se expone |
| `drain_mode` | [EXT] Debug/Status |
| `halt_drain_active` | [EXT] Debug/Status |
| `fault_drain_active` | [EXT] Debug/Status |
| `fault_active` | [EXT] Debug/Status |
| `fault_terminal` | [EXT] Debug/Status |

> Si ninguna lógica funcional consume estas señales, no hace falta dibujarlas como puertos separados.

---

<a id="bloque-8-3"></a>

## 8.3 `Cycle Authorization`

**Tipo:** Combinacional. **Responsabilidad:** Autorizar exactamente un ciclo de CPU y determinar su origen.

**Contrato:** cpu_cycle_fire=!reset && !load_accept && (automatic_cycle_request || command_cycle_request || prepare_cycle_request); requests y cycle_from_continuous según estado actual. PREPARING_READY nunca ejecuta CPU.

**Fuente:** [contrato arquitectónico](architecture/execution_control.md#autorización-de-un-ciclo-cpu). **Verificación futura:** RUN automático, STEP único, stalls contados, prepare_done RUN/STEP y supresión por reset/LOAD aceptado.

### Entradas

| Señal | Origen |
|---|---|
| `global_state` | `Global FSM` |
| `reset` | [GLOBAL] reset |
| `load_accept` | `Command Arbiter` |
| `run_accept` | `Command Arbiter` |
| `step_accept` | `Command Arbiter` |
| `prepare_done` | `Session Preparation` |

### Salidas

| Señal | Destino |
|---|---|
| `cpu_cycle_fire` | `Pipeline Hazard Control` |
| `cpu_cycle_fire` | `WB Bypass Control` |
| `cpu_cycle_fire` | `DMEM Write Control` |
| `cpu_cycle_fire` | `Cycle Counter` |
| `cycle_from_continuous` | `Global FSM` |

---

# 9. Carga y preparación de sesión

<a id="bloque-9-1"></a>

## 9.1 `Loader`

**Tipo:** Control secuencial privado; interfaz externa parcial. **Responsabilidad:** Recibir/validar una imagen y escribir words completas con ownership.

**Contrato:** LOAD aceptado inicia carga privada, tamaño confirmado sigue cero. Recibe el programa seguido, sin confirmaciones intermedias, y reconstruye words completas little-endian para IMEM; FIFO RX/TX de cuatro bytes y consumo de cada byte antes del siguiente completo aprobados, incluida reconstrucción en un registro fuera de RX y escritura IMEM; falta concretar la realización que cumpla ese presupuesto. load_ok/load_fail excluyentes; load_ok certifica imagen no vacía, contigua desde cero, múltiplo de cuatro y dentro de capacidad. Retiene tamaño validado hasta commit; reset aborta. No confirma imagen por sí solo. El transporte descarta RX durante preparación y confirmación final, y admite la siguiente solicitud al terminar físicamente el segundo byte de DONE, incluido Stop.

**Fuente:** [contrato arquitectónico](architecture/memory_architecture.md#carga-y-publicación-de-una-imagen). **Verificación futura:** Imagen completa, vacía/truncada/discontinua/sobredimensionada, reset durante carga y no publicación prematura.

### Entradas

| Señal | Origen |
|---|---|
| `loader_active` | `Global FSM` |
| inicio/reinicio de carga | `Command Arbiter.load_accept` |
| stream de imagen/programa | [EXT] UART / protocolo / host |
| `IMEM_CAPACITY_BYTES`, `IMAGE_SIZE_WIDTH` | [CFG] perfil autoritativo |
| `reset` | [GLOBAL] reset |

### Salidas

| Señal | Destino |
|---|---|
| interfaz de escritura IMEM | `Instruction Memory` |
| `load_ok` | `Global FSM` |
| `load_fail` | `Global FSM` |
| tamaño validado pendiente de la nueva imagen | `Session Preparation` / commit de `loaded_image_size_bytes` |

> El nombre físico de la señal que transporta el tamaño pendiente es detalle de implementación; conceptualmente el dato pertenece al Loader hasta el commit de la nueva sesión.

---

<a id="bloque-9-2"></a>

## 9.2 `Session Preparation`

**Tipo:** Control secuencial privado; mantenimiento físico parcial. **Responsabilidad:** Establecer el estado inicial coherente de la nueva sesión.

**Contrato:** PC/RF/pipeline/contador iniciales, DMEM cero lógico y conjunto utilizado vacío. prepare_done exige preparación completa preflanco sin writes concurrentes; PREPARING_READY publica tamaño, RUN/STEP reutilizan imagen. Para LOAD en REFERENCE y ALT_1000, presupuesto máximo de 1 ms (50.000 clocks de 50 MHz) desde entrada a PREPARING_READY hasta commit; confirmar apenas termine, sin espera fija. Orden, duración concreta y puertos de mantenimiento pendientes; su diseño deberá cumplir el presupuesto aprobado.

**Fuente:** [contrato arquitectónico](architecture/execution_control.md#preparación-y-prioridad-global) y [presupuesto aprobado](decisions.md#acuerdo-parcial-de-dec-proto-003--presupuesto-máximo-de-preparación-de-sesión). **Verificación futura:** Clear multiciclo, ningún ciclo prematuro, preparación/commit LOAD dentro de 1 ms en los perfiles actuales y primer ciclo con contador 1 en RUN/STEP.

### Entradas

| Señal | Origen |
|---|---|
| `prepare_active` | `Global FSM` |
| `global_state` / modo de preparación | `Global FSM` |
| tamaño validado pendiente | `Loader` |
| `reset` | [GLOBAL] reset |

### Salidas

| Señal / acción | Destino |
|---|---|
| `prepare_done` | `Global FSM` |
| `prepare_done` | `Cycle Authorization` |
| inicializar `PC = 0` | `PC` |
| limpiar Register File | `Registers` |
| invalidar pipeline | `IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB` |
| cero lógico / mantenimiento DMEM | `Data Memory` |
| inicializar conjunto de memoria utilizada de la sesión | [EXT] Debug/Snapshot; mecanismo dependiente de DEC-SYS-005 |
| poner `cycle_count = 0` | `Cycle Counter` |
| commit del tamaño de imagen en PREPARING_READY | registro `loaded_image_size_bytes` |

> Los nombres exactos de los write-enables de preparación no quedaron fijados; el diagrama puede mostrar estas conexiones como una interfaz de mantenimiento/preparación.

---

<a id="bloque-9-3"></a>

## 9.3 Registro global `loaded_image_size_bytes`

**Tipo:** Registro funcional y predicado combinacional. **Responsabilidad:** Conservar la única fuente persistente de imagen confirmada.

**Contrato:** Reset o load_accept lo dejan cero; solo PREPARING_READY && prepare_done escribe tamaño validado; cualquier otro caso retiene, incluida preparación de reutilización. image_valid=(size!=0) no es registro.

**Fuente:** [contrato arquitectónico](architecture/memory_architecture.md#estado-persistente-de-la-imagen). **Verificación futura:** Capacidad inclusive, carga fallida, LOAD rechazado y reutilización sin modificar tamaño.

### Entradas

| Señal | Origen |
|---|---|
| clear a `0` | [GLOBAL] `reset` |
| clear a `0` | `Command Arbiter.load_accept` |
| nuevo tamaño confirmado | `Session Preparation`, usando el tamaño pendiente del `Loader` |
| `IMAGE_SIZE_WIDTH` | [CFG] derivado de IMEM_CAPACITY_BYTES |

### Salidas

| Señal | Destino |
|---|---|
| `loaded_image_size_bytes` | `Fetch Fault Check` |
| `image_valid = (loaded_image_size_bytes != 0)` | `Fetch Fault Check`, [EXT] Debug/Status |
| valor confirmado | [EXT] Debug/Status, si se expone |

> Su ancho es `IMAGE_SIZE_WIDTH` de §0.2 y representa la capacidad inclusive. En REFERENCE son 11 bits; en ALT_1000 son 10. No se confunde con el ancho del índice de words.

---

<a id="bloque-9-4"></a>

## 9.4 `Cycle Counter`

**Tipo:** Registro funcional unsigned de 64 bits. **Responsabilidad:** Contar ciclos efectivos de la sesión módulo 2^64.

**Contrato:** Reset/preparación lo dejan cero; incrementa una vez por cpu_cycle_fire, incluidos stalls y drain. Wrap no genera flags/fault ni cambia estado. Primer ciclo tras preparación consume el cero ya preparado.

**Fuente:** [contrato arquitectónico](architecture/execution_control.md#contador-lógico-de-ciclos). **Verificación futura:** HOLD y actividad UART no cuentan; máximo→0→1 en ciclos normales, stall y drain.

### Entradas

| Señal | Origen |
|---|---|
| `cpu_cycle_fire` | `Cycle Authorization` |
| clear a `0` de nueva sesión | `Session Preparation` |
| `reset` | [GLOBAL] reset |

### Salidas

| Señal | Destino |
|---|---|
| `cycle_count[63:0]` | [EXT] Debug/Status |

> Contador unsigned de 64 bits con wrap modulo `2^64`.

---

# 10. Endpoints externos y parámetros

Estas fuentes/destinos explican las flechas que salen del CPU sin terminar en otro bloque del datapath.

<a id="bloque-10-1"></a>

## 10.1 Fuentes externas

| Fuente | Destino |
|---|---|
| `clk` funcional común, generado por plataforma | todos los bloques secuenciales; objetivo 50 MHz |
| `reset` funcional acondicionado | control/estado global y consumidores de §0.3 |
| comandos LOAD / STEP / RUN | `Command Arbiter` |
| stream de programa | `Loader` |
| `IMEM_CAPACITY_BYTES` | `Instruction Memory`, `Fetch Fault Check`, `Loader` y derivación de IMAGE_SIZE_WIDTH |
| `DMEM_CAPACITY_BYTES` | `Data Memory`, `EX Flow Check` y preparación de metadata |

<a id="bloque-10-2"></a>

## 10.2 Destino externo `Debug/Status`

Debe recibir o reconstruir coherentemente el contenido mínimo aprobado; el formato de serialización está aprobado en protocol.md; los puertos físicos y la secuencia de lectura siguen pendientes:


- `global_state`
- `PC[31:0]`
- `image_valid`
- `program_finished`
- `fault_info_valid`
- `fault_cause[2:0]`
- `fault_pc[31:0]`
- `cycle_count[63:0]`
- `valid`, PC e instrucción de los cuatro latches; campos adicionales según DEC-ARCH-009
- contenido completo del Register File, con índice y valor
- memoria de datos utilizada según DEC-SYS-005; siempre con cero lógico y ownership respetados

Los predicados `program_finished` y `fault_info_valid` pueden reconstruirse de `global_state`; no requieren campos externos redundantes. `fault_cause` y `fault_pc` solo representan un fault vigente en FAULT_DRAIN_AUTO/STEP o FAULT. PC, contador, RF, latches y DMEM utilizados pertenecen a un único instante lógico, aun si la serialización tarda múltiples clocks. Una consulta arbitraria durante RUN no queda aprobada por este contrato.

### 10.3 Composición de Processor Top y frontera del sistema

Processor Top conecta el datapath, latches, controles locales y recursos de memoria descritos en 1–7 con el control de sesión de 8–9. El wrapper de plataforma aporta clock/reset; la capa de protocolo aporta solicitudes válidas y el stream; Debug consume el estado observable. La inclusión física de memorias o controles en un mismo módulo top puede variar sin cambiar la propiedad de cada señal.

| Frontera conceptual | Dirección hacia el sistema integrado | Contrato / estado |
|---|---|---|
| `clk` | entrada | único dominio funcional; generación física en plataforma |
| `reset` | entrada | interno activo alto y acondicionado; consumo funcional síncrono |
| solicitudes LOAD / RUN / STEP | entradas hacia Command Arbiter | eventos sincronizados de operaciones válidas; codificación y framing aprobados en protocol.md; puertos físicos pendientes |
| stream de imagen | entrada hacia Loader | reconstrucción de words completas y recuperación aprobadas; puertos físicos pendientes |
| [CFG] perfil de memoria | configuración | capacidades y anchos comunes a loader, memorias, validadores y software |
| PC, contador, global_state, image_valid | salidas lógicas de observación | estado actual coherente; layout y códigos externos aprobados; puertos de lectura pendientes |
| RF completo y mínimos de los cuatro latches | salidas lógicas de observación | contenido obligatorio; puertos físicos no congelados |
| fault_cause / fault_pc | salidas lógicas de observación | par vigente solo en estados de fault; representación externa aprobada, puertos de lectura pendientes |
| DMEM utilizada | interfaz de observación parcial | criterio y lista binaria aprobados; puertos/recorrido pendientes, cero lógico y ownership obligatorios |

Esta tabla no declara una lista final de puertos HDL del top ni prescribe llevar todos los registros como un bus externo ancho. La elección de agrupación, puertos de lectura Debug, stream y mantenimiento debe registrarse al concretar esos módulos. Una frontera de observación no realimenta controles de ejecución por sí misma.

---

# 11. Integridad de las conexiones

Cada entrada funcional tiene un productor y cada salida enumerada tiene un consumidor, una conexión de observación o una frontera parcial explícita. Una señal derivada usada solo dentro de un bloque puede permanecer interna.

| Conexión sensible | Contrato |
|---|---|
| `id_fault_cause`, `id_fault_pc`, `ex_fault_cause`, `ID/EX.pc` | convergen en Fault Metadata Control; no quedan sin destino |
| `ex_halt_candidate` | Flow Control → Pipeline Hazard Control |
| `forward_a_sel` / `forward_b_sel` | cada selector controla exclusivamente su mux correspondiente |
| `EX/MEM.ex_result[1:0]` | posición de selección de Load Select/Extend |
| `mem_read_data`, dirección y `byte_enable` | selección little-endian consistente; la frontera física de lanes permanece abierta |
| los cuatro `next.valid` | Pipeline Empty Logic → Global FSM; no usan la FSM siguiente |
| RF completo, PC, imagen válida y mínimos de los cuatro latches | Debug/Snapshot; contenido y representación aprobados, puertos físicos pendientes |
| `fault_cause`, `fault_pc`, `cycle_count` | Debug/Status, con validez y sesión coherentes |

Las siguientes conexiones o estados contradicen los acuerdos vigentes y no se implementan:

- confirmación directa Fetch Fault Check → Pipeline Hazard Control;
- una acción `act_if_fault_exception`;
- registros globales `terminal_kind`, `drain_auto` o `fault_valid` paralelos a la FSM;
- un bypass Data Memory → EX;
- una tercera entrada de Next PC MUX para halt/fault;
- una realimentación `next_state` → aceptación, autorización o acciones del mismo ciclo.

# 12. Nombres y equivalencias

| Nombre del mapa formal | Equivalente en arquitectura | Alcance |
|---|---|---|
| `Registers` | Register File / Register Bank | mismo banco de 32 × 32 bits |
| `ALUSrc MUX` | ALU Source MUX | mismo selector RS2/inmediato |
| `Load Select/Extend` | Load Select / Extend | misma selección y extensión de load |
| `capture`, `hold`, `invalidate`, `bubble` | enables locales del latch correspondiente | señales locales; se identifican por bloque, no un enable global único |
| `IF/ID.next.valid` y análogos | `valid_next` | salida de lógica combinacional de actualización |
| `fault_capture_fire` | `fault_confirm = act_ex_fault \|\| act_id_fault` | mismo evento; captura metadata y notifica FSM |
| `halt_confirm` | `act_halt` | mismo evento hacia FSM |
| `loader_active` | estado LOADING | predicado del estado actual |

`MEM/WB Update Control` controla exclusivamente MEM/WB; `EX/MEM Update Control` controla EX/MEM. Hay un solo bloque funcional IF/ID Update Control. No se certifica ni se prescribe una edición de un XML externo no incluido en el repositorio.

# 13. Cadena global de control

La dependencia global debería leerse así:

```text
[EXT] comandos
      │
      ▼
Command Arbiter
      │ load_accept / step_accept / run_accept
      ├──────────────────────────────┐
      ▼                              ▼
 Global FSM                   Cycle Authorization
      │ global_state                 │
      │                              └──► cpu_cycle_fire
      │                                      │
      │                                      ▼
      │                            Pipeline Hazard Control
      │                                      │
      │                                      ▼
      │                           PC / registros de pipeline
      │                                      │
      │                                      ▼
      │                            Pipeline Empty Logic
      │                                      │
      └──────────────────────────────◄──── pipeline_empty_next
```

Y el camino de fault:

```text
ID Fault Check ── id_fault_candidate ──► Pipeline Hazard Control
      │                                      │
      ├─ id_fault_cause ─────┐               ├─ act_id_fault ──┐
      └─ id_fault_pc ────────┤               │                 │
                             ▼               ▼                 │
                       Fault Metadata Control ◄────────────────┘
                             ▲
                             │
EX Flow Check ─ ex_fault_cause
       │
       └─ ex_fault_candidate ──► Pipeline Hazard Control
                                      │
                                      └─ act_ex_fault ─────────► Fault Metadata Control

Fault Metadata Control
      ├──► fault_cause register ──► Debug/Status
      ├──► fault_pc register ─────► Debug/Status
      └──► fault_confirm ─────────► Global FSM
```


# 14. Contratos de integración por ciclo

Esta matriz concreta las salidas de los controles locales para conectarlos sin reinterpretar los nombres. Los términos corresponden a [las ecuaciones aprobadas](architecture/control_and_hazards.md#controles-locales-derivados-de-las-acciones); se comparan en la verificación documental. Capture, invalidate y bubble son mutuamente excluyentes para cada latch; una ausencia de acción significa retención implícita, aunque la salida `hold` de IF/ID sea cero.

| Salida local | Ecuación |
|---|---|
| `pc_write_enable` | `act_normal \|\| act_redirect` |
| `next_pc_sel` | `act_redirect` |
| `ifid_capture_if` (`IF/ID.capture`) | `act_normal` |
| `ifid_hold` (`IF/ID.hold`) | `act_load_use \|\| act_drain_load_use` |
| `ifid_invalidate` (`IF/ID.invalidate`) | `act_redirect \|\| act_halt \|\| act_ex_fault \|\| act_id_fault \|\| act_drain_advance` |
| `idex_capture_id` (`ID/EX.capture`) | `act_normal \|\| act_drain_advance` |
| `idex_bubble` (`ID/EX.bubble`) | `act_load_use \|\| act_redirect \|\| act_halt \|\| act_ex_fault \|\| act_id_fault \|\| act_drain_load_use` |
| `exmem_capture_ex` (`EX/MEM.capture`) | `act_normal \|\| act_load_use \|\| act_redirect \|\| act_id_fault \|\| act_drain_load_use \|\| act_drain_advance` |
| `exmem_invalidate` (`EX/MEM.invalidate`) | `act_halt \|\| act_ex_fault` |
| `memwb_capture_mem` (`MEM/WB.capture`) | `pipeline_action` (OR de las ocho acciones) |

Los aliases entre paréntesis son el mismo cable local; no agregan campos o enables registrados.

| Commit / evento | Predicado / efecto |
|---|---|
| `rf_write_fire` | `cpu_cycle_fire && MEM/WB.valid && MEM/WB.reg_write && MEM/WB.rd!=0`; escribe el rd/dato preflanco |
| `dmem_store_fire` | `cpu_cycle_fire && EX/MEM.valid && is_store(EX/MEM.mem_op)`; aplica dirección/dato preflanco |
| `dmem_metadata_write_fire` | mismo `dmem_store_fire`; modifica validez solo de bytes seleccionados |
| `fault_capture_fire` / `fault_confirm` | `act_ex_fault \|\| act_id_fault`; captura par del causante y notifica FSM |
| `halt_confirm` | `act_halt`; no es FINISHED por sí solo |
| `redirect_apply` | `act_redirect`; actualización de PC y descarte de jóvenes |
| `cycle_counter_increment` | `cpu_cycle_fire`; exactamente una vez por ciclo, también stall/drain |

Los commits CPU están suprimidos por RESET o LOAD aceptado/preparación efectiva a través de la autorización y prioridad común. Un store MEM o writeback WB anterior puede coexistir con fault/halt/redirect joven; no se agrega un veto por el tipo de frontera.

**Secuencia crítica load-use + fetch candidato:** el stall conserva PC y los cinco campos IF/ID; al siguiente avance normal el consumidor pasa a ID/EX y el candidato entra en IF/ID. Durante el ciclo posterior, EX resuelve el consumidor antes de una confirmación ID. Una frontera EX descarta al candidato; sin ella ID confirma con `fault_pc=IF/ID.pc`. La simulación futura debe comprobar esa secuencia bajo RUN, STEP y HOLD; no debe usar el dato recién capturado en MEM/WB antes del flanco que lo produjo.

**Drenado legal:** después de confirmar halt/fault, IF/ID.valid, IF/ID.fetch_fault_valid e ID/EX.valid son cero. Solo quedan anteriores en EX/MEM o MEM/WB; por ello load_use_stall es cero y el drain legal usa act_drain_advance. La rama act_drain_load_use se conserva y se prueba con estado artificial, sin atribuirle alcanzabilidad legal.

**Observación:** el snapshot usa estado actual registrado y DMEM lógica del mismo instante. `next.valid`, candidatos no confirmados y bits residuales no se presentan como instrucciones/fault vigentes. El acuerdo parcial de DEC-ARCH-009 incluye el candidato registrado de IF/ID como tal; su representación UART está aprobada en D03/D05 y DEC-ARCH-009.

# 15. Fronteras parciales y condiciones de salida

Lista final de operaciones aprobada en el [acuerdo de lista final](decisions.md#acuerdo-parcial-de-dec-proto-002--lista-final-y-nombres-de-operaciones): LOAD, RUN, STEP, RESET y CHECK_READY. Los nombres identifican servicios; en UART viaja un código binario de un byte. CHECK_READY reemplaza el nombre descriptivo CONSULTAR_DISPONIBILIDAD sin alterar formatos ni comportamiento. C02 asigna LOAD 0x01, RUN 0x02, STEP 0x03, RESET 0x04 y CHECK_READY 0x05, reutilizados como primer byte de respuesta. Véase el [acuerdo de códigos de solicitud](decisions.md#acuerdo-parcial-de-dec-proto-001--códigos-definitivos-de-solicitud). Resultados aprobados: ACCEPTED 0x01, DONE 0x02, READY 0x03, BUSY 0x04, NO_IMAGE 0x05, INVALID_SIZE 0x06, INCOMPLETE_REQUEST 0x07, INCOMPLETE_DATA 0x08, UART_ERROR 0x09, FINISHED 0x0A, FAULT 0x0B y UNKNOWN_COMMAND 0x0C (extensión C05). Véase el [acuerdo de resultados](decisions.md#acuerdo-parcial-de-dec-proto-001--códigos-comunes-de-resultado). global_state usa códigos 0x00–0x0D según el [acuerdo de códigos de estado](decisions.md#acuerdo-parcial-de-dec-proto-001--códigos-externos-de-global_state). C03/D05 y DEC-ARCH-009 cerrados.

Orden de solicitudes y respuestas aprobado en el [acuerdo de intercambios](decisions.md#acuerdo-parcial-de-dec-proto-001--orden-de-intercambios-y-respuestas): una operación normal por vez, CHECK_READY/RESET durante RUN efectivo, cada respuesta completa antes de otra y exclusión durante Debug. La tabla consolida elegibilidad CPU y fases de transporte; realización de puertos/control privado pendiente.

Errores básicos aprobados en el [acuerdo de errores restantes](decisions.md#acuerdo-parcial-de-dec-proto-001--errores-básicos-fuera-de-load): código desconocido responde `[byte][0x0C]`; error UART al recibir código recupera RX con R = 100 ms sin respuesta ni efecto en CPU/imagen, conservando TX. Solicitudes de un byte completas sin otro timeout de campos. LOAD y exclusión Debug conservan sus reglas.

Plazos PC aprobados en el [acuerdo de plazos restantes](decisions.md#acuerdo-parcial-de-dec-proto-003--plazos-de-reset-step-y-recepción-de-debug): RESET/cabecera STEP 200 ms; tras cabecera, parte fija Debug 228 bytes en 319 ms; después de used_count, lista 5*K bytes en ceil(5*K*10*1000/19200 +200) ms, K=0 termina sin otra espera. RUN mantiene espera de ejecución sin límite. Reacción ante fallo aprobada en C06: W_debug de 6100/3400 ms por perfil, descarte RX/limpieza local y CHECK_READY, sin repetir operaciones; cabecera final RUN 200 ms desde primer byte.

Comandos adicionales y tiempos/recuperación consolidados en [DEC-PROTO-002](decisions.md#dec-proto-002--comandos-adicionales) y [DEC-PROTO-003](decisions.md#dec-proto-003--timeouts-y-recuperación), aprobadas. El formato completo queda consolidado en [DEC-PROTO-001](decisions.md#dec-proto-001--formato-detallado-del-protocolo) y [protocol.md](protocol.md), con [revisión documental](debug_protocol_audit.md). Puertos, contadores, FSM privadas y arbitraje permanecen en DEC-SYS-007/diseño de bloques.

Perfil compartido aprobado en el [acuerdo de perfil compartido](decisions.md#acuerdo-parcial-de-dec-proto-001--perfil-compartido-de-memoria-y-protocolo): REFERENCE por defecto o ALT_1000, misma configuración previa PC/FPGA, capacidades de la tabla común de arquitectura de memoria, códigos/layout únicos. Sin negociación adicional; revisión/consolidación completadas en protocol.md.

## 15.1 Decisiones que siguen abiertas

| Decisión | Interfaz / entregable afectado | Alcance que permanece abierto |
|---|---|---|
| DEC-SYS-007 | solicitudes y UART física | 19200 baud nominales, 8N1 y factor 16 sobre clock funcional común de 50 MHz; generador compartido con divisor 163 y pulso registrado definidos; diseños RX/TX con estados, controles, indicadores y puertos definidos; FIFO RX/TX de cuatro bytes con funcionamiento y puertos definidos; uart_core con conexiones, puertos e indicadores y reporte combinado de errores definidos; servicios LOAD/RUN/STEP/RESET/CHECK_READY y contrato de consumo aprobados; control del protocolo, integración de servicios y demostración de su presupuesto de consumo pendientes |
| DEC-SYS-009 | toolchain / imagen del Loader | assembler y validación de imagen emitida |
| DEC-SYS-008 | aplicación PC | CLI/TUI/GUI y presentación de estado |

DEC-ARCH-009 queda cerrada en [decisions.md](decisions.md#dec-arch-009--campos-de-pipeline-expuestos-por-debug): todos los campos funcionales, anchos, orden por posición, códigos y responsabilidad de interpretación aprobados. global_state de un byte, tabla 0x00–0x0D; puertos y recorrido físicos pendientes del diseño de bloques.

DEC-SYS-005 queda cerrada en [decisions.md](decisions.md#dec-sys-005--criterio-de-memoria-de-datos-utilizada): bytes escritos en la sesión, lista única creciente con cantidad de cinco bytes little-endian, dirección cuatro y valor uno por entrada; cantidad cero sin entradas. Lectura directa del estado retenido aprobada en D06; puertos y secuencia de recorrido/conteo se concretan en diseño de bloques.

La autoridad y dependencias de las tres decisiones abiertas permanecen en [decisiones pendientes](pending_decisions.md). El [envío exclusivo con estado retenido](decisions.md#acuerdo-parcial-de-dec-proto-001--envío-exclusivo-de-debug-con-estado-retenido) selecciona lectura directa del estado posterior al STEP/último ciclo RUN, sin copia completa adicional, CPU sin nuevos ciclos ni LOAD/preparación, RX descartado y liberación tras Stop del último byte. Deben concretarse puertos y secuencia de recorrido/conteo antes de implementar.

## 15.2 Detalles de realización que deben concretarse por módulo

| Detalle | Contrato ya fijado | Lo que aún debe documentarse antes de implementar la conexión |
|---|---|---|
| Escritura Loader→IMEM | word completa, escritura síncrona, dirección validada, ownership y perfil | nombres/anchos físicos de dirección y write-enable y adaptación byte/índice |
| Stream y estado privado Loader | validación de imagen, load_ok/load_fail exclusivos, tamaño retenido hasta commit | recepción, puertos, FSM privada y errores conforme al protocolo aprobado |
| Preparación y mantenimiento | estado inicial listo antes de prepare_done, sin writes concurrentes con primer ciclo | acciones físicas por recurso, secuencia de clear y eventual comunicación de finalización |
| Lanes de DMEM / byte_enable | selección por dirección/tamaño, little-endian y dato/validez atómicos | empaquetado y ancho de máscara, ubicación del desplazamiento/alineación y adaptador de lectura |
| Ownership físico | un agente incompatible autorizado por memoria | muxes o grants elegidos y exclusión de mantenimiento/Debug |
| Observación Debug | lectura directa de estado retenido y envío exclusivo desde instante postciclo hasta último Stop; reset físico puede abortar | puertos de lectura y secuencia de recorrido/conteo/serialización, coordinación con fin físico TX y descarte RX |
| Codificación de global_state | 14 estados/predicados y códigos externos 0x00–0x0D aprobados | enum interno y adaptación a código externo aprobado |
| Plataforma | un dominio, objetivo 50 MHz, reset acondicionado | recurso de clock, pinout, XDC y conexión concreta de locked/reset |
| Agrupación RTL / Processor Top | todas las conexiones y prioridades de este documento | nombres HDL, parámetros compartidos y fronteras elegidas de módulos/estructuras |

Estos detalles no reabren una política ya aprobada. Deben resolverse de forma explícita cuando se implemente el módulo afectado, y no se presentan aquí como contratos físicos cerrados.

## 15.3 Criterio de aceptación documental y verificación posterior

La revisión documental debe demostrar:

- Cobertura de los 54 bloques del mapa original, sin pérdida de entradas/salidas ni campos válidos de pipeline.
- Concordancia con anchos/códigos aprobados y fuentes/destinos de las señales.
- Clock, reset, enables, preparación, HOLD y orden preflanco/postflanco identificados para cada clase de recurso.
- Ocho acciones exclusivas y controles locales equivalentes al acuerdo 47.
- FSM de 14 estados y autorización desde estado actual, sin lazos combinacionales ni estado global redundante.
- Accesos de memoria por bytes, región completa en 33 bits, cero lógico, atomicidad y ownership.
- Contenido y representación de Debug aprobados; frontera clara con realización física pendiente.
- Referencias documentales válidas y evidencia de revisión en [interfaces_audit.md](interfaces_audit.md).

El [gate de fase 11](plan.md#14-fase-11--contratos-de-interfaces) exige que un módulo pueda implementarse sin modificar arbitrariamente otro. Antes de implementar un módulo afectado por una frontera parcial se deben concretar sus puertos y dependencias de §15.1–15.2; el documento no afirma que el gate global del sistema esté satisfecho.

Los criterios de verificación futura de cada bloque son insumos para `verification_plan.md`, testbenches y assertions. Siguen pendientes ejecución RTL, validación de I01–I25 en simulación, inferencia de memorias, cobertura de constraints, timing post-implementation y FPGA. La comparación documental de ecuaciones no sustituye esas pruebas.

## 15.4 Control y acciones en las FSM relacionadas con UART

Las correcciones docentes del TP2 establecen un [criterio de organización](decisions.md#acuerdo-parcial-de-dec-sys-007--correcciones-de-diseño-de-fsm-del-tp2) para los bloques que se adapten al TP3. La FSM conserva un estado registrado y calcula combinacionalmente su siguiente estado y las señales de acción. Las decisiones se expresan mediante casez, con `?` en las condiciones que sean irrelevantes para una elección.

Los contadores y registros que realizan esas acciones se describen como recursos diferenciados del control. Sus interfaces identifican qué señal habilita captura, desplazamiento, incremento, limpieza o carga y en qué flanco se consume. La decisión y la actualización pueden corresponder al mismo flanco, sin introducir una espera adicional por la separación.

En el receptor, la FSM determina cuándo tomar una muestra y emite una orden de captura. El registro de recepción incorpora entonces el bit y conserva los restantes datos. Los contadores actualizan por sus controles correspondientes y aportan las condiciones que necesita la FSM. Los nombres de señales, sus ecuaciones y la agrupación física se concretarán en el diseño del receptor; esta descripción no congela puertos nuevos.

La separación entre control y datos no exige un módulo o archivo por recurso. Sí debe quedar explícita antes de implementar, para que la FSM indique qué acción corresponde y la lógica del recurso determine cómo se actualiza su valor.

## 15.5 Organización del receptor UART en desarrollo

La [organización del receptor](architecture/uart_rx.md) toma los recursos del TP2 y diferencia `RX Control`, `Sample Counter`, `Bit Counter` y `RX Shift Register`, conforme al [acuerdo de organización](decisions.md#acuerdo-parcial-de-dec-sys-007--organización-del-receptor-uart). Identifica controles de limpieza e incremento para los contadores y `data_shift_enable` para la captura del bit; todos se consumen al flanco del clock funcional común. El sincronizador precede al receptor y la FIFO RX recibe sus bytes completos.

Esta descripción concreta la separación funcional requerida en §15.4. El [acuerdo de estados y agrupación](decisions.md#acuerdo-parcial-de-dec-sys-007--estados-y-agrupación-del-receptor-uart) conserva el módulo uart_rx con la FSM, contadores y registro de recepción dentro de él. La [tabla de estados y acciones](architecture/uart_rx.md#estados-y-transiciones) conserva IDLE, START, DATA, STOP y RECOVER, con comprobación de Start a ocho ticks, muestras posteriores separadas por dieciséis ticks y eventos consumidos al flanco, como en el TP2. El [acuerdo de codificación](decisions.md#acuerdo-parcial-de-dec-sys-007--codificación-one-hot-del-receptor-uart) conserva el registro privado state[4:0] one-hot con valores 00001, 00010, 00100, 01000 y 10000 en ese orden y reset a IDLE. DEC-SYS-007 permanece pendiente en los demás bloques e integración UART.

El consumidor de los [indicadores de recepción](architecture/uart_rx.md#indicadores-para-el-control-del-protocolo) es el control del protocolo dentro de la FPGA. Conforme al [acuerdo de indicadores](decisions.md#acuerdo-parcial-de-dec-sys-007--indicadores-de-recepción-uart), uart_rx genera rx_receiving en START/DATA/STOP y rx_activity ante un cambio de la línea sincronizada, nivel bajo o recepción en curso. Ambos tienen ancho de un bit y se presentan combinacionalmente, con cero durante reset. Un registro auxiliar interno de un bit conserva el nivel anterior para detectar cambios, actualizado en cada flanco del clock funcional e inicializado en uno. Los [puertos del receptor](architecture/uart_rx.md#frontera-de-uart_rx) están descritos; ambos indicadores llegan al consumidor mediante la [frontera de uart_core](architecture/uart_core.md#frontera-de-uart_core), sin registro adicional. La organización interna del control del protocolo sigue pendiente. Los indicadores informan del transporte físico y no agregan estados a la FSM global CPU.

## 15.6 Organización del transmisor UART en desarrollo

La [organización del transmisor](architecture/uart_tx.md), aprobada en el [acuerdo correspondiente](decisions.md#acuerdo-parcial-de-dec-sys-007--organización-del-transmisor-uart), conserva uart_tx como módulo. Su FSM, los dos contadores, el registro del byte y el registro del nivel de salida son partes funcionales internas. Los contadores tienen cuatro y tres bits, el registro del byte ocho y el de salida uno, tomando la configuración 8N1 y factor 16 del TP2.


## 15.7 Generador de ticks UART

El [generador de ticks](architecture/uart_baud_tick_gen.md), conforme al [acuerdo del generador](decisions.md#acuerdo-parcial-de-dec-sys-007--generador-de-ticks-uart), conserva baud_tick_gen del TP2 con CLK_FREQ_HZ=50.000.000, BAUD_RATE=19.200 y OVERSAMPLE=16. El divisor redondeado es 163 y el contador tiene ocho bits para recorrer cero a 162. La salida s_tick se registra en uno al volver a cero y se mantiene durante un clock funcional; RX y TX la consumen en el siguiente flanco. Reset inicializa contador y salida en cero. La cuenta permanece activa entre tramas y durante HOLD de CPU.

Los puertos son clk y reset de entrada y s_tick de salida, todos de un bit. La misma salida alimenta a receptor y transmisor como referencia de habilitación, dentro del dominio funcional común. El baud efectivo es aproximadamente 19.171,78, con error de −0,147 % respecto del nominal; el protocolo conserva su configuración y presupuestos aprobados. La conexión compartida está definida en uart_core; el control del protocolo sigue pendiente en DEC-SYS-007.

## 15.8 FIFO UART

El [diseño de las FIFO](architecture/uart_fifo.md), conforme al [acuerdo de funcionamiento](decisions.md#acuerdo-parcial-de-dec-sys-007--funcionamiento-de-las-fifo-uart), conserva el módulo fifo del TP2 con dos instancias independientes de cuatro bytes. Cada instancia mantiene cuatro entradas de ocho bits, dos punteros de dos bits y una ocupación de tres bits. read_data presenta combinacionalmente el byte más antiguo y solo es válido cuando empty está en cero; rd retira ese byte al flanco si hay datos y wr escribe al flanco si hay espacio. Lectura y escritura se aceptan según los flags previos al flanco, y cada operación aceptada actualiza su recurso. Si ambas se aceptan, la ocupación permanece igual. Reset vacía la cola mediante punteros y cuenta en cero.

Los puertos conservados son clk, reset, rd, wr y write_data de entrada, y read_data, empty y full de salida; los datos tienen ocho bits y las demás señales uno. Los productores y consumidores de cada instancia están definidos en la [integración UART](architecture/uart_core.md). La profundidad se conserva como base y margen bajo el contrato de consumo; su justificación no acredita las latencias del controlador todavía pendiente. La [comprobación de suficiencia](architecture/uart_fifo.md#fundamento-de-la-capacidad-y-comprobación-pendiente) exige demostrar consumo RX antes del siguiente byte, incluida escritura IMEM, y continuidad RX durante espera TX, antes de implementar el control del protocolo. DEC-SYS-007 permanece pendiente.

## 15.9 Conexiones internas de uart_core

La [integración UART](architecture/uart_core.md), conforme al [acuerdo de conexiones](decisions.md#acuerdo-parcial-de-dec-sys-007--conexiones-internas-de-uart_core), conserva uart_core del TP2 con el sincronizador, el generador compartido, uart_rx, uart_tx y las dos FIFO. RX escribe received_data con rx_done_tick y recibe el retiro rd_uart desde el control del protocolo. TX escribe w_data con wr_uart desde ese control y retira el primer byte al flanco de tx_done_tick. Fuera de reset, se solicita tx_start cuando TX no está vacía y uart_tx está libre; el transmisor conserva el byte en su registro durante el envío. Todos los módulos utilizan el dominio funcional común y RX continúa físicamente activo con independencia de TX y del avance de CPU.

La [frontera aprobada](architecture/uart_core.md#frontera-de-uart_core) agrega rx_activity, rx_receiving y tx_done_tick a los puertos del TP2. Los tres llegan directamente desde sus productores, sin registro adicional, y conservan sus condiciones y flancos de consumo. El [reporte de errores](architecture/uart_core.md#reporte-de-errores) conserva rx_error_tick como combinación de error de trama y desbordamiento RX, con cero durante reset. El [acuerdo de puertos y errores](decisions.md#acuerdo-parcial-de-dec-sys-007--puertos-y-reporte-de-errores-de-uart_core) aprueba ambos detalles. La realización del control del protocolo, el seguimiento de los bytes de respuesta y la demostración de su presupuesto de consumo siguen pendientes en DEC-SYS-007.

## 15.10 Organización funcional del control del protocolo

La [organización del control del protocolo](architecture/protocol_controller.md), conforme al [acuerdo funcional](decisions.md#acuerdo-parcial-de-dec-sys-007--organización-funcional-del-control-del-protocolo), distingue interpretación y coordinación, registros y contadores y generación de respuestas. El control determina cuándo interpretar o descartar RX y coordina los servicios con los bloques existentes. Los recursos se actualizan mediante las señales de acción de la FSM. La generación de respuestas forma las cabeceras y serializa Debug, respetando TX llena y el fin físico del último byte.

Loader conserva reconstrucción y escritura IMEM; la FSM global CPU conserva ejecución y preparación mantiene sus acciones sobre los recursos de sesión. La coordinación de transporte y respuestas no detiene RX mientras espera TX. La agrupación se concreta en §15.11; los puertos, los recursos concretos, las FSM privadas y la demostración del presupuesto de consumo continúan pendientes en DEC-SYS-007.

## 15.11 Módulos de protocolo y serialización

El [acuerdo de módulos](decisions.md#acuerdo-parcial-de-dec-sys-007--módulos-del-control-del-protocolo-y-respuestas) fija protocol_controller y response_serializer. El [controlador](architecture/protocol_controller.md#agrupación-en-módulos) contiene interpretación y coordinación, su FSM y los registros y contadores correspondientes. El [serializador](architecture/response_serializer.md) contiene generación de cabeceras, recorrido Debug y seguimiento de transmisión, con sus propios controles y recursos.

protocol_controller consume r_data, rx_empty e indicadores RX y genera rd_uart; response_serializer consume tx_full y tx_done_tick y produce w_data y wr_uart. El controlador solicita una respuesta y el serializador comunica su fin físico completo. La [frontera de coordinación](architecture/response_serializer.md#comunicación-con-el-controlador), conforme al [acuerdo de solicitud y finalización](decisions.md#acuerdo-parcial-de-dec-sys-007--solicitud-y-finalización-de-respuestas), fija response_start, response_opcode[7:0], response_result[7:0] y response_with_debug como entradas del serializador y response_busy y response_done_tick como salidas de un bit. La solicitud captura los campos al flanco con el serializador libre y response_busy abarca producción, espera TX y transmisión hasta el Stop final. response_done_tick se consume en ese último flanco y se suprime durante reset. El diseño concreto de los recursos, los puertos hacia los servicios y Debug y la demostración de continuidad RX durante espera TX permanecen abiertos en DEC-SYS-007.

## 15.12 Recursos internos de response_serializer

El [acuerdo de organización interna](decisions.md#acuerdo-parcial-de-dec-sys-007--organización-interna-del-serializador) fija cinco grupos dentro del serializador: FSM de control, descriptor de 17 bits, próximo byte de ocho bits con disponibilidad, recursos de recorrido y seguimiento TX. La [descripción de recursos](architecture/response_serializer.md#organización-interna) conserva la separación entre señales de acción de la FSM y actualizaciones al flanco.

El [seguimiento](architecture/response_serializer.md#seguimiento-de-transmisión) utiliza un contador de tres bits, de cero a cuatro, y un indicador de producción completa. La cuenta incluye bytes encolados hasta su último Stop, incluido el byte en transmisión, y se actualiza con escritura aceptada y tx_done_tick. El indicador se activa al incorporar el último byte a TX. Respuesta en curso, producción completa, un byte pendiente y tx_done_tick identifican el flanco final. El recorrido, sus índices y anchos, los estados y controles de acción y la frontera de observación Debug continúan pendientes; no se presentan esos detalles como implementados o verificados en RTL.
