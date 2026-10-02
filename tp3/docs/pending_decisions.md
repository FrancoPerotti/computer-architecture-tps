# TP3 — Decisiones pendientes

**Contador lógico:** la revisión aprobada de `DEC-SYS-006` (2026-09-26, AUD-005) fija `cycle_count[63:0]` unsigned con incremento módulo `2^64`, sin fault ni flags de overflow. Representación aprobada en ocho bytes little-endian, offset 6 del cuerpo del snapshot; captura mediante lectura directa de estado retenido y exclusión de solicitudes aprobada en D06; realización de bloques pendiente. No se reabre ancho ni semántica.

## 1. Propósito

Este documento contiene únicamente decisiones que el equipo todavía debe resolver. El mapa cronológico indica cuándo debe cerrarse cada una; el detalle posterior las mantiene separadas por dominio.

El protocolo está aprobado en [protocol.md](protocol.md), con [revisión documental](debug_protocol_audit.md). Quedan tres decisiones generales; la realización de bloques debe concretarse antes de implementar.

Cuando una decisión se aprueba:

1. se completan su decisión, justificación y consecuencias;
2. se elimina de este archivo;
3. se incorpora en `decisions.md` con el mismo identificador;
4. se actualiza la columna **Decisión de origen** de cualquier requisito que surja de ella.

## 2. Convenciones

Cada entrada pendiente contiene:

- **Estado:** siempre `Pendiente`.
- **Dominio:** área principal afectada.
- **Debe resolverse antes de:** último momento responsable para cerrarla.
- **Depende de:** decisiones que deben resolverse previamente.
- **Contexto:** problema que debe resolverse.
- **Acuerdos parciales aprobados:** subdecisiones ya cerradas que restringen las opciones restantes sin cerrar todavía el identificador completo, cuando corresponda.
- **Opciones a analizar:** alternativas iniciales o restantes sobre las que todavía no se seleccionó una solución.
- **Requisitos afectados:** trazabilidad hacia `requirements.md`.

---

## 3. Mapa cronológico

| Momento de cierre | Sistema | CPU / Arquitectura | Debug / Protocolo | Software | Clock / Timing |
|---|---|---|---|---|---|
| M1 — Decision Freeze | — | — | — | — | — |
| M2 — Architecture Freeze | — | — | `DEC-SYS-007` | — | — |
| M3 — ISA Freeze | — | — | — | `DEC-SYS-009` | — |
| M4 — Pipeline Freeze | — | — | — | — | — |
| M5 — Hazard Freeze | — | — | — | — | — |
| Antes de diseñar UART / Debug | — | — | — | — | — |
| Antes de implementar software de PC | — | — | — | `DEC-SYS-008` | — |

La primera fila con decisiones pendientes determina el próximo conjunto de trabajo. Dentro de una misma fila deben respetarse las dependencias indicadas en cada entrada.

---

## 4. Sistema y alcance

No quedan decisiones pendientes en este dominio.

## 5. CPU y arquitectura

No quedan decisiones pendientes en este dominio.

---

## 6. Debug y comunicación

### DEC-SYS-007 — Servicios y parámetros generales de UART

**Estado:** Pendiente

**Dominio:** Debug / Comunicación

**Debe resolverse antes de:** M2 — Architecture Freeze

**Depende de:** `DEC-SYS-003`, `DEC-SYS-004` y `DEC-SYS-006`, ya aprobadas, y características de clock/placa disponibles.

**Contexto:** Deben definirse servicios, baud rate, formato físico y supuestos generales de comunicación entre FPGA y PC, incluyendo los servicios necesarios para comenzar y completar una carga con la semántica de fallo cerrado definida, respetar los límites de capacidad del perfil activo y transportar el snapshot aprobado por `DEC-SYS-006`. `DEC-ARCH-004` fija ya el estado de fault observable y sus metadatos mínimos `fault_cause`/`fault_pc`, pero no su representación UART ni un comando adicional de recuperación; esto no presupone consulta arbitraria durante RUN ni reporte obligatorio de capacidades.

**Acuerdo parcial aprobado — 2026-10-01:** UART nominal de 19200 baud, 8N1 y sobremuestreo 16, usando el clock funcional común con objetivo de 50 MHz y ticks síncronos adaptados a esa frecuencia. Se conserva la configuración física de referencia del TP2; buffers y correcciones de bloques no quedan aprobados automáticamente. Véase el [acuerdo de configuración UART](decisions.md#acuerdo-parcial-de-dec-sys-007--configuración-física-uart-de-referencia).

**Segundo acuerdo parcial aprobado — 2026-10-01:** FIFO RX y TX independientes de cuatro bytes; consumir/procesar cada byte de LOAD antes de que llegue completo el siguiente, incluyendo reconstrucción en un registro y escritura de cada word IMEM. Ante TX llena se conserva el byte pendiente sin bloquear RX. Se requiere fin físico de cada byte TX, actividad RX y recepción en curso; el protocolo identifica el segundo byte de aceptación para iniciar el timeout. Véase el [acuerdo de buffers y consumo UART](decisions.md#acuerdo-parcial-de-dec-sys-007--buffers-y-contrato-de-consumo-uart).

**Lista de servicios aprobada — 2026-10-01:** LOAD, RUN, STEP, RESET y CHECK_READY; consulta de disponibilidad renombrada CHECK_READY sin cambio de semántica. C01 completo. Véase el [acuerdo de lista final](decisions.md#acuerdo-parcial-de-dec-proto-002--lista-final-y-nombres-de-operaciones).

**Correcciones docentes del TP2 registradas — 2026-10-01:** transición y controles mediante casez con `?` para condiciones irrelevantes; separación entre FSM de control y recursos que actualizan datos/contadores mediante señales de acción. El estado actual se registra al flanco y next_state se calcula combinacionalmente. Véase el [criterio de diseño de FSM](decisions.md#acuerdo-parcial-de-dec-sys-007--correcciones-de-diseño-de-fsm-del-tp2).

**Organización del receptor aprobada — 2026-10-01:** separación entre control, contador de sobremuestreo, contador de bits y registro de desplazamiento, con controles de acción consumidos al flanco. Véase el [acuerdo de organización](decisions.md#acuerdo-parcial-de-dec-sys-007--organización-del-receptor-uart).

**Estados y agrupación del receptor aprobados — 2026-10-02:** se conserva la división en módulos del TP2, con contadores y registro de recepción dentro de uart_rx, y los estados IDLE, START, DATA, STOP y RECOVER con su comportamiento de recepción. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--estados-y-agrupación-del-receptor-uart) y la [tabla de acciones](architecture/uart_rx.md#estados-y-transiciones).

**Indicadores de recepción aprobados — 2026-10-02:** rx_receiving indica START/DATA/STOP; rx_activity indica cambio de nivel sincronizado, nivel bajo o recepción en curso. El [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--indicadores-de-recepción-uart) y la [descripción del receptor](architecture/uart_rx.md#indicadores-para-el-control-del-protocolo) identifican generación, productor, consumidor y puertos del receptor. El control del protocolo dentro de la FPGA los consume para realizar la recuperación por silencio. El recorrido físico a través de la integración UART y la organización interna del control del protocolo permanecen pendientes.

**Codificación del receptor aprobada — 2026-10-02:** registro de estado one-hot de cinco bits, con IDLE=00001, START=00010, DATA=00100, STOP=01000 y RECOVER=10000; reset a IDLE. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--codificación-one-hot-del-receptor-uart) y la [tabla de codificación](architecture/uart_rx.md#codificación-del-estado). El trabajo continúa con el transmisor y los demás bloques e integración UART.

**Organización del transmisor aprobada — 2026-10-02:** se conserva uart_tx como módulo con su FSM, dos contadores, registro del byte y registro del nivel de salida, separando control y actualizaciones. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--organización-del-transmisor-uart) y la [descripción del transmisor](architecture/uart_tx.md).

**Estados del transmisor aprobados — 2026-10-02:** IDLE, START, DATA y STOP con el comportamiento de envío del TP2 y tx_done_tick al completar todo el Stop. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--estados-del-transmisor-uart) y la [tabla de acciones](architecture/uart_tx.md#tabla-de-acciones). La integración de los eventos permanece pendiente.

**Codificación del transmisor aprobada — 2026-10-02:** registro de estado one-hot de cuatro bits, con IDLE=0001, START=0010, DATA=0100 y STOP=1000; reset a IDLE. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--codificación-one-hot-del-transmisor-uart) y la [tabla de codificación](architecture/uart_tx.md#codificación-del-estado).

**Selector del transmisor aprobado — 2026-10-02:** tx_output_select de dos bits con HIGH=00, LOW=01, CURRENT_BIT=10 y NEXT_BIT=11; tx_write_enable autoriza la captura del valor seleccionado. Ambos controles son internos. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--selector-de-salida-del-transmisor-uart) y la [selección de salida](architecture/uart_tx.md#selección-del-nivel-de-salida). La coordinación y exposición de eventos se completarán en la integración UART.

**Puertos del transmisor aprobados — 2026-10-02:** entradas clk, reset, tx_start y s_tick de un bit y data_in de ocho bits; salidas tx, tx_busy y tx_done_tick de un bit. El byte se captura al aceptar tx_start en IDLE; los controles de acción permanecen internos. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--puertos-del-transmisor-uart) y la [frontera de puertos](architecture/uart_tx.md#frontera-de-uart_tx). La integración permanece pendiente.

**Generador de ticks aprobado — 2026-10-02:** se conserva baud_tick_gen del TP2 con divisor entero redondeado a 163 para clock funcional de 50 MHz, nominal 19200 baud y factor 16. Un contador de ocho bits recorre cero a 162 y produce s_tick registrado de un clock, compartido por RX y TX. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--generador-de-ticks-uart) y la [descripción del generador](architecture/uart_baud_tick_gen.md). El trabajo continúa con las FIFO y la integración.

**Funcionamiento de las FIFO aprobado — 2026-10-02:** dos instancias del módulo fifo del TP2, independientes y de cuatro bytes, con escritura y retiro síncronos, primer dato combinacional, flags empty/full y reset a vacío. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--funcionamiento-de-las-fifo-uart) y la [descripción](architecture/uart_fifo.md). Los cuatro lugares se mantienen como base y margen bajo el contrato de consumo; antes de implementar el control del protocolo falta demostrar sus latencias y la continuidad RX durante espera TX. La integración permanece pendiente.

**Conexiones internas de uart_core aprobadas — 2026-10-02:** RX escribe cada byte válido en su FIFO y el control del protocolo lo retira para procesar o descartar; el control escribe los bytes de respuesta en TX y el transmisor retira el byte al terminar el Stop completo. El envío comienza cuando existe un byte pendiente y el transmisor está libre. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--conexiones-internas-de-uart_core) y la [integración](architecture/uart_core.md).

**Puertos y reporte de errores de uart_core aprobados — 2026-10-02:** se conservan los once puertos del TP2 y se agregan rx_activity, rx_receiving y tx_done_tick, sin registro adicional en la integración. rx_error_tick conserva la combinación de error de trama y desbordamiento RX y se suprime durante reset. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--puertos-y-reporte-de-errores-de-uart_core), la [frontera](architecture/uart_core.md#frontera-de-uart_core) y el [reporte](architecture/uart_core.md#reporte-de-errores). El control del protocolo y la demostración de su presupuesto de consumo permanecen pendientes.

**Organización funcional del control del protocolo aprobada — 2026-10-02:** se distinguen interpretación y coordinación, registros y contadores actualizados mediante señales de acción, y generación de respuestas con serialización Debug y seguimiento del fin físico. Loader conserva reconstrucción y escritura IMEM y la FSM global CPU conserva la ejecución. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--organización-funcional-del-control-del-protocolo) y la [organización](architecture/protocol_controller.md). La separación no fija todavía módulos, puertos o estados.

**Módulos del control y respuestas aprobados — 2026-10-02:** protocol_controller contiene interpretación, coordinación y atención RX; response_serializer contiene generación de cabeceras, recorrido Debug y seguimiento de transmisión TX. Cada módulo conserva sus controles, registros y contadores. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--módulos-del-control-del-protocolo-y-respuestas) y la [agrupación](architecture/protocol_controller.md#agrupación-en-módulos).

**Solicitud y finalización de respuestas aprobadas — 2026-10-02:** response_start solicita una respuesta con el serializador libre y captura response_opcode, response_result y response_with_debug al flanco. response_busy permanece activo hasta el fin físico del último byte y response_done_tick comunica esa finalización en el flanco del último Stop. No se agrega una cola de respuestas al serializador. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--solicitud-y-finalización-de-respuestas) y la [frontera](architecture/response_serializer.md#comunicación-con-el-controlador). Los recursos y el mecanismo de seguimiento siguen pendientes.

**Organización interna del serializador aprobada — 2026-10-02:** cinco grupos: FSM, descriptor de 17 bits, próximo byte de ocho bits con disponibilidad, recursos de recorrido y seguimiento TX. El contador de pendientes tiene tres bits y recorre cero a cuatro, incluido el byte en transmisión; el indicador de producción completa distingue el último byte encolado de su fin físico. Véanse el [acuerdo](decisions.md#acuerdo-parcial-de-dec-sys-007--organización-interna-del-serializador), la [organización](architecture/response_serializer.md#organización-interna) y el [seguimiento](architecture/response_serializer.md#seguimiento-de-transmisión). Los índices del recorrido, los controles y los estados siguen pendientes.

**Opciones restantes a analizar:** recorrido de response_serializer, índices y anchos de posición, controles de acción y estados de su FSM; demás puertos, recursos, FSM privadas y coordinación con Loader, control de ejecución, preparación, reset y observación Debug; realización de las acciones de seguimiento del fin físico y demostración del presupuesto de consumo aprobado. Receptor, transmisor, generador, FIFO y uart_core tienen definidos sus diseños de referencia, conexiones y puertos para el clock funcional común. La solicitud y finalización entre controlador y serializador están fijadas. Debe demostrarse la latencia de consumo del controlador y su continuidad RX durante espera TX antes de implementar ese control. Baud rate, formato físico, sobremuestreo, profundidades de FIFO y contrato de consumo ya están fijados; los formatos binarios están aprobados en [DEC-PROTO-001](decisions.md#dec-proto-001--formato-detallado-del-protocolo) y [protocol.md](protocol.md).

**Requisitos afectados:** `REQ-UART-001` a `REQ-UART-011`, `REQ-EXEC-016`, `REQ-EXEC-017`, `REQ-DBG-013` a `REQ-DBG-016`, `REQ-DOC-006`.

---

## 7. Software de PC

### DEC-SYS-009 — Estrategia del assembler

**Estado:** Pendiente

**Dominio:** Software / Assembler

**Debe resolverse antes de:** M3 — ISA Freeze y antes de implementar el assembler.

**Depende de:** `DEC-SYS-001`, `DEC-SYS-004`, `DEC-SYS-010` y `DEC-ARCH-001`, ya aprobadas.

**Contexto:** Debe decidirse si se implementará un assembler propio o se integrará una herramienta existente de manera controlada, y en qué componente del toolchain se verificará que la imagen generada es una secuencia little-endian no vacía, contigua, sin huecos, con origen cero, tamaño múltiplo de cuatro y dentro de la capacidad soportada del perfil seleccionado. Esta responsabilidad no se asigna necesariamente de forma exclusiva al assembler y no deberá hardcodear los valores del perfil de referencia.

La estrategia deberá aceptar `halt` sin operandos y emitir exactamente `0x0000000B`, conforme a `DEC-SYS-001` y `REQ-SW-012`; integrar una herramienta RV32I conserva esa obligación custom.

**Opciones a analizar:** assembler propio para el subconjunto; herramienta externa; biblioteca existente con validación del subconjunto.

**Requisitos afectados:** `REQ-MEM-010` a `REQ-MEM-012`, `REQ-MEM-015`, `REQ-MEM-021` a `REQ-MEM-024`, `REQ-SW-002` a `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-012`.

---

### DEC-SYS-008 — Formato de la aplicación de PC

**Estado:** Pendiente

**Dominio:** Software / Interfaz

**Debe resolverse antes de:** Implementar la interfaz de usuario.

**Depende de:** `DEC-SYS-006`, ya aprobada, y flujos de operación definidos por Debug y el protocolo.

**Contexto:** Debe seleccionarse una CLI, TUI, GUI o combinación para operar el sistema y presentar el snapshot aprobado sin acoplar la interfaz a señales combinacionales internas. La aplicación deberá mostrar un fault de memoria como ejecución anormal y no como finalización normal.

**Opciones a analizar:** CLI inicial; TUI; GUI; capas reutilizables con más de una interfaz.

**Requisitos afectados:** `REQ-SW-001`, `REQ-SW-005` a `REQ-SW-010`, `REQ-DBG-013` a `REQ-DBG-017`, `REQ-EXEC-018`.
