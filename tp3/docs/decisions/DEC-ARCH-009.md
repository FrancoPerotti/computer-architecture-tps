### DEC-ARCH-009 — Campos de pipeline expuestos por debug

**Contrato vigente de consulta:** [debug_architecture](../architecture/debug/debug_architecture.md), [cpu_pipeline](../architecture/cpu/cpu_pipeline.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** CPU / Debug / Representación externa

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La consigna requiere observar los registros interetapa. Se completa la selección de campos funcionales, su identificación externa y la interpretación de validez/candidatos junto al contexto global de ejecución.

**Opciones consideradas:** Exponer el mínimo `valid`/PC/instrucción o todos los campos funcionales registrados; identificar bloques por posición fija o agregar IDs; conservar estado registrado o filtrar campos por validez. Se seleccionan exposición completa, posiciones fijas y responsabilidad de interpretación del lector.

**Decisión:** Se transmiten los 34 campos funcionales de los cuatro registros interetapa, en el orden de su esquema en `interfaces.md`: `IF/ID` 5 campos/69 bits internos, `ID/EX` 15/193, `EX/MEM` 8/139 y `MEM/WB` 6/103. Sus longitudes externas son 11/30/20/15 bytes; los bloques se identifican por posición fija, sin IDs adicionales. Campos de 32 bits: cuatro bytes little-endian; campos pequeños: un byte propio con padding alto cero. Controles/causas conservan los códigos arquitectónicos ya definidos.

Debug expone los datos registrados y sus indicadores también con `valid`=0, sin sustituirlos por cero ni clasificarlos como residuos. Su vigencia se interpreta por el lector: `valid` indica instrucción activa; `fetch_fault_valid` de `IF/ID` identifica el candidato registrado y permite interpretar su PC/causa, sin convertirlo en fault global confirmado. No se exponen nuevos diagnósticos combinacionales ni se agregan campos internos.

Fuera de los registros interetapa, `global_state` ocupa un byte en offset cero del cuerpo y usa códigos 0x00–0x0D para los 14 estados según el [acuerdo de códigos externos](DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--códigos-externos-de-global_state). `fault_cause` y `fault_pc` globales están siempre presentes y se interpretan como fault vigente únicamente en los estados de fault aprobados. No hay registros `terminal_kind`, `drain_auto` ni `fault_valid` adicionales.

Los acuerdos de [contenido completo](#acuerdo-parcial-de-dec-arch-009--exposición-completa-de-campos-registrados-del-pipeline), [anchos externos](DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--representación-binaria-de-campos-del-snapshot), [orden/layout](DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--orden-y-delimitación-del-snapshot) y [responsabilidad del lector](DEC-PROTO-001.md#acuerdo-parcial-de-dec-proto-001--campos-registrados-e-interpretación-del-snapshot) completan el contrato. No se impone una codificación física a la FSM global.

**Justificación:** Exponer el estado funcional completo y registrado facilita seguir las instrucciones, operandos, resultados y controles; formato fijo y códigos existentes permiten interpretarlo sin agregar estado diagnóstico. Los indicadores separan trabajo activo, candidato y fault confirmado.

**Consecuencias:** Se cierran D03/D05 y DEC-ARCH-009. D06 define lectura directa del estado retenido y envío exclusivo tras `STEP`/final `RUN`; puertos y recorrido se concretan en diseño de bloques. El resto de reglas comunes, errores, esperas y perfil permanece en decisiones de protocolo. Esta aprobación no acredita implementación ni cierra todo D0.

**Requisitos afectados:** `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de selección y representación externa, sin modificar los esquemas funcionales ni decisiones de hazards/sesión.

---

### Acuerdo parcial de DEC-ARCH-009 — Exposición completa de campos registrados del pipeline

**Estado del acuerdo:** Aprobado como base de diseño. Se selecciona el contenido de D03; `DEC-ARCH-009` y D03 siguen pendientes de la representación binaria externa que se completará con D05.

**Dominio:** Debug / Campos de `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Debug debe transportar los campos registrados definidos en `interfaces.md` para interpretar datos y controles del pipeline. El orden y empaquetado se concretan en el layout del snapshot.

**Decisión:** Cada snapshot de Debug incluye los campos funcionales completos de los cuatro registros interetapa, con la semántica y anchos internos existentes:

| Latch    | Campos expuestos                                                                                                                                                                                                              | Cantidad y ancho interno total |
|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------|
| `IF/ID`  | `valid`, `pc[31:0]`, `instruction[31:0]`, `fetch_fault_valid`, `fetch_fault_cause[2:0]`                                                                                                                                       | 5 campos, 69 bits              |
| `ID/EX`  | `valid`, `pc[31:0]`, `instruction[31:0]`, `rs1[4:0]`, `rs2[4:0]`, `rd[4:0]`, `rs1_value[31:0]`, `rs2_value[31:0]`, `immediate[31:0]`, `alu_op[5:0]`, `alu_src`, `result_sel[1:0]`, `flow_op[2:0]`, `mem_op[3:0]`, `reg_write` | 15 campos, 193 bits            |
| `EX/MEM` | `valid`, `pc[31:0]`, `instruction[31:0]`, `rd[4:0]`, `reg_write`, `mem_op[3:0]`, `ex_result[31:0]`, `store_data[31:0]`                                                                                                        | 8 campos, 139 bits             |
| `MEM/WB` | `valid`, `pc[31:0]`, `instruction[31:0]`, `rd[4:0]`, `reg_write`, `wb_value[31:0]`                                                                                                                                            | 6 campos, 103 bits             |

Los 34 campos corresponden a 504 bits de estado interno. Este total no fija longitud UART, padding, orden ni packing externo. No se modifican los registros interetapa ni se agregan registros de diagnóstico, causas de invalidez o señales combinacionales al snapshot.

`valid` conserva la interpretación de instrucción activa. Con `valid`=0, los datos residuales no se presentan como una instrucción activa. `IF/ID` puede transportar el candidato separado `fetch_fault_valid=1`: su PC y causa describen un candidato de fetch, no un fault global confirmado. La condición de fault vigente sigue representada por `global_state` y `fault_cause`/`fault_pc` globales, según los acuerdos existentes.

Los controles de `ID/EX` se exponen por sus seis campos definidos; no se inventa un bus adicional llamado control. `EX/MEM` expone el resultado seleccionado y el dato de store registrados; no se agregan resultados alternativos ni operandos efectivos combinacionales. `MEM/WB` expone el valor de writeback registrado.

**Justificación:** Observar el contenido completo ya existente permite seguir tanto identidad de instrucciones como operandos, resultados y controles por etapa. Reutilizar los esquemas definidos evita crear otro subconjunto de campos registrado o diagnósticos adicionales.

**Consecuencias y alcance pendiente:** Queda aprobado qué campos de los registros interetapa viajan en Debug. Se continúa con D04 para memoria utilizada, y se vuelve a la representación externa de D03 en D05: orden/ancho UART, padding, codificación de controles, validez e identificación de registros interetapa. D03 y `DEC-ARCH-009` no se marcan completos hasta resolver esa representación. La serialización/captura se realiza luego en D06; no se inicia implementación.

**Requisitos afectados:** `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-014`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Selecciona exposición completa y resuelve la inclusión del candidato registrado de `IF/ID`, conservando la representación externa pendiente y los esquemas internos aprobados.
