# Inventario completo de bloques y agrupación FPGA

- **Tipo:** arquitectura.
- **Estado documental:** especificación vigente.

## Propósito y alcance

Relaciona los 51 bloques funcionales con sus módulos, archivos y ubicación en la jerarquía FPGA. La agrupación conserva los contratos de interfaces y distingue bloques separados de lógica local.

## Criterio y comparación de alternativas

Interfaces define 51 bloques CPU en las secciones 1–9. El inventario mantiene la trazabilidad de cada bloque independientemente del número de archivos. La elección de módulos se fundamenta en responsabilidad, contrato y valor de verificación; la tabla siguiente compara las alternativas.

| Organización | Ventajas | Costes / riesgos | Juicio para este proyecto |
|---|---|---|---|
| Todo el procesador en un módulo | Pocas conexiones entre módulos y recorrido local directo | Archivo extenso, responsabilidades mezcladas y comprobación aislada más difícil | Demasiado concentrado para el diseño/documentación del TP |
| Cada uno de los 51 bloques en su propio módulo | Correspondencia directa con el dibujo e identificación individual | Muchos puertos/instancias, navegación y mantenimiento para funciones muy pequeñas | Excesivamente fragmentado como regla universal para este CPU |
| Etapas + submódulos seleccionados | Recorrido por pipeline claro y aislamiento de unidades con reglas propias | Requiere justificar y documentar cada agrupación; una etapa puede crecer si se concentra demasiado | **Recomendación:** elegir por responsabilidad, contrato y valor de verificación, manteniendo los 51 bloques trazados |

Se recomienda un módulo independiente cuando reúne una responsabilidad coherente, reglas/casos propios o una frontera registrada o puertos relevantes. La reutilización ayuda, pero no es requisito: un detector usado una sola vez puede justificar su módulo. No se usa un umbral de líneas de código como criterio único.

La organización distingue dos familias:

- **Lógica próxima a sus consumidores:** muxes sencillos, sumadores, máscaras triviales y predicados pequeños.
- **Módulos separados explícitamente:** memoria, `decoder`, ALU, hazards, detección/validación, controles sustanciales y registros interetapa.

Para `Load-Use Detector` se recomienda `load_use_detector.sv`: su ecuación incluye validez, fuentes realmente usadas, `x0` y tipo del productor; esas reglas permiten comprobación individual significativa. Para `Clear bit 0` se recomienda una expresión local en `ex_stage.sv`: encapsular una transformación de un bit no añade una responsabilidad que justifique otra interfaz. En WB, `wb_stage` realiza íntegramente `WB Bypass Control`, evitando una segunda capa que solo lo envuelva.

### Fuentes y alcance del juicio

[Ibex documenta](https://ibex-core.readthedocs.io/en/latest/03_reference/instruction_decode_execute.html) archivos separados para `decoder`/ALU/control/RF, mientras mantiene muxes dentro de la etapa ID. Es un ejemplo real de organización selectiva, no prueba de que una partición concreta sea óptima para nuestro pipeline de cinco etapas. La recomendación anterior es juicio de ingeniería aplicado a nuestros contratos y al objetivo educativo.

[AMD UG901](https://docs.amd.com/r/en-US/ug901-vivado-synthesis/KEEP_HIERARCHY) explica que la jerarquía y las optimizaciones entre módulos dependen de `flatten_hierarchy`/`KEEP_HIERARCHY`. La cantidad de archivos no implica por sí sola más ciclos, más área o menor frecuencia. Conservar forzosamente todas las fronteras puede limitar optimizaciones; no se añade una restricción de jerarquía para justificar el catálogo. El timing a 50 MHz se verificará durante implementación, sin inferirlo del número de módulos.

<a id="los-54-bloques-uno-por-uno"></a>

## Bloques CPU, uno por uno

«Separado» identifica un módulo específico para el bloque. «Local» identifica lógica/estado dentro del módulo indicado, con sus acciones/actualizaciones diferenciadas según los acuerdos. Cada fila utiliza el ID/nombre vigente en Interfaces y señala exactamente el archivo donde se realizará. La ubicación está aprobada junto con la agrupación selectiva; la naturaleza del bloque ya estaba aprobada.

| ID / contrato | Bloque definido | Realización recomendada | Archivo futuro | Ubicación directa | Motivo | Naturaleza aprobada |
|---|---|---|---|---|---|---|
| [1.1](../interfaces.md#bloque-1-1) | `PC Update Control` | Local en `if_stage` | `if_stage.sv` | `if_stage` | Enable/selección del PC ligados al estado y acciones de IF | Combinacional |
| [1.2](../interfaces.md#bloque-1-2) | `Next PC MUX` | Local en `if_stage` | `if_stage.sv` | `if_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [1.3](../interfaces.md#bloque-1-3) | `PC` | Local en `if_stage` | `if_stage.sv` | `if_stage` | Estado PC ligado a su selección/enable local de IF | Registro funcional |
| [1.4](../interfaces.md#bloque-1-4) | `PC Adder` | Local en `if_stage` | `if_stage.sv` | `if_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [1.5](../interfaces.md#bloque-1-5) | `Instruction Memory` | Separado: `instruction_memory` | `instruction_memory.sv` | `if_stage` | Memoria con lectura/carga y ownership propios | Memoria: lectura combinacional / escritura síncrona |
| [1.6](../interfaces.md#bloque-1-6) | `Fetch Fault Check` | Separado: `fetch_fault_check` | `fetch_fault_check.sv` | `if_stage` | Prioridad y límites de fetch; casos de prueba propios | Combinacional |
| [1.7](../interfaces.md#bloque-1-7) | `IF/ID Input Logic` | Local en `if_stage` | `if_stage.sv` | `if_stage` | Formación local del payload de IF/ID | Combinacional |
| [1.8](../interfaces.md#bloque-1-8) | `IF/ID Update Control` | Local en `processor_top` | `processor_top.sv` | `processor_top` | Controles pequeños ligados al registro interetapa; lógica local del top | Combinacional |
| [1.9](../interfaces.md#bloque-1-9) | Registro `IF/ID` | Separado: `if_id_register` | `if_id_register.sv` | `processor_top` | Frontera registrada del pipeline con payload y actualización propios | Registro funcional |
| [2.1](../interfaces.md#bloque-2-1) | `Decoder` | Separado: `decoder` | `decoder.sv` | `id_stage` | Whitelist y tabla de controles de la ISA | Combinacional |
| [2.2](../interfaces.md#bloque-2-2) | `Registers` | Separado: `register_file` | `register_file.sv` | `id_stage` | Estado RF, `x0`, puertos y prioridades propias | Estado con dos lecturas combinacionales y una escritura síncrona |
| [2.3](../interfaces.md#bloque-2-3) | `Immediate Generator` | Separado: `immediate_generator` | `immediate_generator.sv` | `id_stage` | Transformación de los formatos de inmediato | Combinacional |
| [2.4](../interfaces.md#bloque-2-4) | `RS1 Bypass MUX` | Local en `id_stage` | `id_stage.sv` | `id_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [2.5](../interfaces.md#bloque-2-5) | `RS2 Bypass MUX` | Local en `id_stage` | `id_stage.sv` | `id_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [2.6](../interfaces.md#bloque-2-6) | `WB Bypass Control` | Local en `wb_stage` | `wb_stage.sv` | `wb_stage` | `wb_stage` ya representa esta responsabilidad; otro hijo duplicaría la capa de organización | Combinacional |
| [2.7](../interfaces.md#bloque-2-7) | `ID Fault Check` | Separado: `id_fault_check` | `id_fault_check.sv` | `id_stage` | Convergencia de ilegal/fetch candidato y metadatos | Combinacional |
| [2.8](../interfaces.md#bloque-2-8) | `Load-Use Detector` | Separado: `load_use_detector` | `load_use_detector.sv` | `id_stage` | Dependencias, fuentes usadas, validez y `x0` | Combinacional |
| [2.9](../interfaces.md#bloque-2-9) | `ID/EX Update Control` | Local en `processor_top` | `processor_top.sv` | `processor_top` | Controles pequeños ligados al registro interetapa; lógica local del top | Combinacional |
| [2.10](../interfaces.md#bloque-2-10) | Registro `ID/EX` | Separado: `id_ex_register` | `id_ex_register.sv` | `processor_top` | Frontera registrada del pipeline con payload y actualización propios | Registro funcional |
| [3.1](../interfaces.md#bloque-3-1) | `Forwarding Unit` | Separado: `forwarding_unit` | `forwarding_unit.sv` | `ex_stage` | Prioridad de productores y disponibilidad del dato | Combinacional |
| [3.2](../interfaces.md#bloque-3-2) | `Forward MUX A` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.3](../interfaces.md#bloque-3-3) | `Forward MUX B` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.4](../interfaces.md#bloque-3-4) | `ALUSrc MUX` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.5](../interfaces.md#bloque-3-5) | `ALU` | Separado: `alu` | `alu.sv` | `ex_stage` | Operaciones aritméticas/lógicas con contrato propio | Combinacional |
| [3.6](../interfaces.md#bloque-3-6) | `Link Adder` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.7](../interfaces.md#bloque-3-7) | `Result MUX` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.8](../interfaces.md#bloque-3-8) | `Target Adder` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.9](../interfaces.md#bloque-3-9) | `JALR Adder` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.10](../interfaces.md#bloque-3-10) | `Clear bit 0` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.11](../interfaces.md#bloque-3-11) | `Target MUX` | Local en `ex_stage` | `ex_stage.sv` | `ex_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [3.12](../interfaces.md#bloque-3-12) | `Flow Control` | Separado: `flow_control` | `flow_control.sv` | `ex_stage` | Semántica de branches/jumps y target seleccionado | Combinacional |
| [3.13](../interfaces.md#bloque-3-13) | `EX Fault Check` | Separado: `ex_flow_check` | `ex_flow_check.sv` | `ex_stage` | Alineación/rango y prioridad de faults EX | Combinacional |
| [3.14](../interfaces.md#bloque-3-14) | `EX/MEM Update Control` | Local en `processor_top` | `processor_top.sv` | `processor_top` | Controles pequeños ligados al registro interetapa; lógica local del top | Combinacional |
| [3.15](../interfaces.md#bloque-3-15) | Registro `EX/MEM` | Separado: `ex_mem_register` | `ex_mem_register.sv` | `processor_top` | Frontera registrada del pipeline con payload y actualización propios | Registro funcional |
| [4.1](../interfaces.md#bloque-4-1) | `MEM Decode` | Separado: `mem_decode` | `mem_decode.sv` | `mem_stage` | Interpretación de controles de acceso de memoria | Combinacional |
| [4.2](../interfaces.md#bloque-4-2) | `Data Memory` | Separado: `data_memory` | `data_memory.sv` | `mem_stage` | Memoria, marcas, puertos y mantenimiento propios | Memoria: lectura combinacional / escritura síncrona |
| [4.3](../interfaces.md#bloque-4-3) | `Load Select/Extend` | Separado: `load_select_extend` | `load_select_extend.sv` | `mem_stage` | Selección de lanes y extensión signed/unsigned | Combinacional |
| [4.4](../interfaces.md#bloque-4-4) | `WB Value MUX` | Local en `mem_stage` | `mem_stage.sv` | `mem_stage` | Selección/suma local del datapath; separarla añade conexiones sin aislar reglas sustanciales | Combinacional |
| [4.5](../interfaces.md#bloque-4-5) | `DMEM Write Control` | Separado: `dmem_write_control` | `dmem_write_control.sv` | `mem_stage` | Store efectivo y máscara conforme a validez/ciclo/reset | Combinacional |
| [4.6](../interfaces.md#bloque-4-6) | `MEM/WB Update Control` | Local en `processor_top` | `processor_top.sv` | `processor_top` | Controles pequeños ligados al registro interetapa; lógica local del top | Combinacional |
| [4.7](../interfaces.md#bloque-4-7) | Registro `MEM/WB` | Separado: `mem_wb_register` | `mem_wb_register.sv` | `processor_top` | Frontera registrada del pipeline con payload y actualización propios | Registro funcional |
| [5.1](../interfaces.md#bloque-5-1) | `Pipeline Hazard Control` | Separado: `pipeline_hazard_control` | `pipeline_hazard_control.sv` | `processor_top` | Arbitraje por edad y ocho acciones de pipeline | Combinacional |
| [6.1](../interfaces.md#bloque-6-1) | `Fault Metadata Control` | Local en `execution_control` | `execution_control.sv` | `execution_control` | Selección de causa/PC y evento de captura junto a sus registros de sesión | Combinacional |
| [6.2](../interfaces.md#bloque-6-2) | Registro global `fault_cause` | Local en `execution_control` | `execution_control.sv` | `execution_control` | Recurso registrado de sesión; actualización local diferenciada en `execution_control` | Registro funcional de metadatos |
| [6.3](../interfaces.md#bloque-6-3) | Registro global `fault_pc` | Local en `execution_control` | `execution_control.sv` | `execution_control` | Recurso registrado de sesión; actualización local diferenciada en `execution_control` | Registro funcional de metadatos |
| [7.1](../interfaces.md#bloque-7-1) | `Pipeline Empty Logic` | Local en `execution_control` | `execution_control.sv` | `execution_control` | Reducción combinacional de los cuatro próximos `valid` | Combinacional |
| [8.1](../interfaces.md#bloque-8-1) | `Global FSM` | Separado: `global_fsm` | `global_fsm.sv` | `execution_control` | FSM de 14 estados, selección de comandos, autorización de ciclos y decodificación de salidas | Estado registrado y lógica combinacional Moore/Mealy |
| [9.1](../interfaces.md#bloque-9-1) | `Loader` | Separado: `loader` | `loader.sv` | `processor_top` | Reconstrucción de palabras y recursos de carga | Reconstrucción secuencial de bytes y control combinacional, sin FSM privada adicional |
| [9.2](../interfaces.md#bloque-9-2) | `Session Preparation` | Separado: `session_preparation` | `session_preparation.sv` | `processor_top` | Progreso y acciones de preparación | Progreso registrado de mantenimiento y control combinacional, sin FSM privada adicional |
| [9.3](../interfaces.md#bloque-9-3) | Registro global `loaded_image_size_bytes` | Local en `execution_control` | `execution_control.sv` | `execution_control` | Recurso registrado de sesión; actualización local diferenciada en `execution_control` | Registro funcional y predicado combinacional |
| [9.4](../interfaces.md#bloque-9-4) | `Cycle Counter` | Local en `execution_control` | `execution_control.sv` | `execution_control` | Recurso registrado de sesión; actualización local diferenciada en `execution_control` | Registro funcional unsigned de 64 bits |

## Cobertura por ubicación

| Ubicación de los bloques | Total | Módulos específicos | Bloques como lógica/estado local |
|---|---:|---:|---:|
| `if_stage` | 7 | 2 | 5 |
| `id_stage` | 7 | 5 | 2 |
| `ex_stage` | 13 | 4 | 9 |
| `mem_stage` | 5 | 4 | 1 |
| `wb_stage` | 1 | 0 | 1 |
| `processor_top`: registros interetapa, sus controles, hazards, Loader y preparación | 11 | 7 | 4 |
| `execution_control` | 7 | 1 | 6 |
| **Total** | **51** | **23** | **28** |

Los cuatro registros interetapa son `if_id_register`, `id_ex_register`, `ex_mem_register` y `mem_wb_register`, instanciados en `processor_top`. Sus controles de actualización son lógica local diferenciada del top; producen `next.valid` sin otro registro.

WB recibe `MEM/WB` actual y genera una sola `rf_write_fire`/bypass. `WB Value MUX` sigue en MEM.

El PC queda como registro local de `if_stage`. `fault_cause`/`fault_pc`, tamaño confirmado y contador de ciclos quedan como recursos locales de `execution_control`, con las prioridades/acciones ya acordadas. No se fusionan sus estados ni se agregan flags.

## Módulos adicionales de integración, transporte y placa

Los siguientes 19 tipos se suman a los 23 módulos específicos recomendados. Los nombres/agrupaciones de UART/controlador/serializador/reset conservan sus acuerdos; tops/etapas/`execution_control` quedaron aprobados con la agrupación selectiva. `clock_generator` es IP y `fifo` tiene dos instancias.

| Módulo | Contenedor | Archivo futuro / realización |
|---|---|---|
| `basys3_top` | raíz | `basys3_top.sv` |
| `clock_generator` | `basys3_top` | IP Clocking Wizard; MMCM/BUFG internos del IP |
| `reset_sync` | `basys3_top` | `reset_sync.sv`; referencia TP2 aprobada |
| `system_top` | `basys3_top` | `system_top.sv` |
| `uart_core` | `system_top` | `uart_core.sv` |
| `protocol_controller` | `system_top` | `protocol_controller.sv` |
| `response_serializer` | `system_top` | `response_serializer.sv` |
| `processor_top` | `system_top` | `processor_top.sv` |
| `serial_input_sync` | `uart_core` | `serial_input_sync.sv` |
| `baud_tick_gen` | `uart_core` | `baud_tick_gen.sv` |
| `uart_rx` | `uart_core` | `uart_rx.sv` |
| `uart_tx` | `uart_core` | `uart_tx.sv` |
| `fifo` | `uart_core` | `fifo.sv`; instancias RX y TX |
| `if_stage` | `processor_top` | `if_stage.sv` |
| `id_stage` | `processor_top` | `id_stage.sv` |
| `ex_stage` | `processor_top` | `ex_stage.sv` |
| `mem_stage` | `processor_top` | `mem_stage.sv` |
| `wb_stage` | `processor_top` | `wb_stage.sv` |
| `execution_control` | `processor_top` | `execution_control.sv` |

La agrupación tiene 42 tipos de módulo, incluido el IP; 41 archivos .sv de módulos propios y `system_pkg.sv` como paquete compartido aprobado. La cantidad es consecuencia de las agrupaciones justificadas, no un objetivo. No se incluyen archivos internos del IP o futuros testbenches.

## Recursos auxiliares y límites del inventario

| Grupo o lógica auxiliar | Propietario | Realización conservada |
|---|---|---|
| TX Start Logic y combinación de errores/actividad RX | `uart_core` | Coordinación local aprobada |
| Divisor/tick, FSM RX/TX, punteros y flags FIFO | `baud_tick_gen`, `uart_rx`, `uart_tx`, `fifo` | Recursos internos aprobados |
| FSM, tamaño/progreso LOAD, timeout, descriptor y marcas/reset | `protocol_controller` | Recursos internos y acciones aprobados |
| FSM, descriptor, byte pendiente, índices/conteo y seguimiento TX | `response_serializer` | Cinco grupos internos aprobados |
| Registro de 24 bits y formación/escritura de palabras | `loader` | Recursos internos del bloque 9.1 |
| Índice de limpieza y acciones de inicialización | `session_preparation` | Recursos internos del bloque 9.2 |
| Bancos/bitmap y selección CPU/Debug | `data_memory` | Una memoria y metadatos compartidos |
| Salidas Moore/Mealy y código externo de ocho bits | `global_fsm` | Lógica combinacional del bloque 8.1; controles de los recursos y código de observación para `Response Serializer` |

<a id="comprobación-y-pendientes"></a>

## Verificación y evidencia

Se contrastaron los 51 IDs/nombres/naturalezas con interfaces, cada bloque con su módulo/archivo y cada módulo específico con su padre. Se comprobaron nombres únicos, jerarquía sin ciclos y correspondencia con `system_composition`. La distribución comprende 23 bloques con módulo específico y 28 como lógica/estado local. Es revisión documental, no simulación RTL ni evidencia de timing.

La organización selectiva fue aprobada el 2026-10-06, con cobertura explícita de los bloques CPU, incluido `WB Bypass Control`. La [revisión local de composición](system_composition.md#revisión-local-y-cierre-de-composición) completó conexiones/anchos/propiedad: FPGA-05/06 cerrados en diseño documental. La correspondencia uno a uno queda como alternativa evaluada, sin aprobar ni implementar. El plan de verificación, sus criterios de comparación y la correspondencia integral del diseño están cerrados documentalmente en FPGA-07/08/09.

## Referencias y trazabilidad

- [Mapa de autoridad documental](system_overview.md#autoridad-documental-por-tema): contratos vigentes y origen de las decisiones.
- [Requisitos](../requirements.md): obligaciones y criterios de aceptación.
- [Decisiones pendientes](../decisions/pending_decisions.md): decisiones de diseño abiertas y condiciones de cierre.
