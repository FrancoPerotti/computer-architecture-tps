# TP3 — Verificación documental de interfaces

**Fecha:** 2026-09-30. **Artefacto:** [interfaces.md](interfaces.md), formalizado a partir de `mapa_bloques_entradas_salidas_tp3.md`. El archivo anterior se renombró; las secciones 1–9 conservan los 54 bloques y sus conexiones, con las correcciones registradas aquí.

**Resultado:** contratos internos formalizados y contrastados con la arquitectura aprobada. Las fronteras parciales de Loader, mantenimiento, Debug, protocolo y plataforma están identificadas; no se aprueban políticas nuevas ni se declara satisfecho el gate global del sistema. Las comprobaciones documentales no equivalen a pruebas RTL.

## Hallazgos y correcciones

| ID | Situación del mapa original | Corrección en interfaces.md | Fuente |
|---|---|---|---|
| IFC-001 | Load Select/Extend no enumeraba la posición del byte; EX/MEM tampoco enumeraba esa conexión. | Se agregó `address_low_bits[1:0]` desde `EX/MEM.ex_result[1:0]` en ambos extremos. Se distingue selección conceptual de empaquetado físico. | [Load Select / Extend](architecture/stage_mem.md#load-select--extend) |
| IFC-002 | PC y RF figuraban como observación opcional; IF/ID, ID/EX y EX/MEM no enumeraban sus mínimos obligatorios hacia Debug. | PC, RF completo e imagen válida tienen destino explícito; los cuatro latches enumeran `valid`, PC e instrucción como contenido obligatorio. Campos adicionales y representación siguen pendientes. | [Información observable](architecture/debug_architecture.md#información-observable-fijada), DEC-SYS-006 |
| IFC-003 | Pipeline Empty Logic nombraba las fuentes `next.valid`, pero los latches no enumeraban esas salidas combinacionales. | Se agregó la conexión de próximo estado en cada latch y se aclaró que no es un campo ni un registro adicional. | [Pipeline vacío](architecture/execution_control.md#pipeline-vacío), DEC-ARCH-003 acuerdos 44/47 |
| IFC-004 | Clock/reset estaban omitidos por convención y no había una matriz temporal completa de los recursos. | Se explicitaron dominio, consumo síncrono, acondicionamiento, estado de reset, preparación, enables y prioridad global. Los latches y RF enumeran reset funcional. | DEC-ARCH-005/008; [Reset](architecture/execution_control.md#reset) |
| IFC-005 | El ancho del tamaño confirmado quedaba descrito sin su fórmula aprobada; no todos los consumidores de configuración aparecían en las tablas. | Se incorporó IMAGE_SIZE_WIDTH, índices y perfiles; se enumeró configuración de Loader, IMEM, DMEM y registro de tamaño. | [Capacidades](architecture/memory_architecture.md#capacidades-y-parametrización), DEC-ARCH-006 |
| IFC-006 | Entradas/salidas carecían de un contrato temporal y un criterio de verificación por bloque. | Cada uno de los 54 bloques tiene tipo, responsabilidad, contrato, fuente y criterio de verificación futura. Se agregó la matriz de enables y commits. | Etapas IF/ID/EX/MEM/WB; DEC-ARCH-003 acuerdos 34–47 aplicables |
| IFC-007 | `byte_enable` podía confundirse con una máscara física por lanes, aunque el mapa no fijaba ese contrato. | Se explicitó que selecciona bytes relativos al store y DMEM combina tamaño/dirección. Su ancho y ubicación física de adaptación siguen abiertos. No se agregó una entrada de dirección al controlador como decisión nueva. | [DMEM Write Control](architecture/stage_mem.md#dmem-write-control), DEC-ARCH-006 |
| IFC-008 | El documento incluía instrucciones sobre nombres y flechas de un XML externo no disponible. | Se sustituyeron por reglas de integridad y equivalencias de nombres autocontenidas; no se certifica un diagrama externo. | Arquitectura consolidada y árbol disponible |
| IFC-009 | Preparación no enumeraba el inicio vacío del conjunto de memoria utilizada y no distinguía todas las fronteras físicas abiertas. | Se agregó la obligación semántica y se listaron pendientes y detalles de realización por interfaz, sin escoger el criterio o mecanismo de captura. | DEC-SYS-003/005/006; [Preparación](architecture/execution_control.md#preparación-y-prioridad-global) |

## Cobertura por familia

| Bloques | Cantidad | Contratos contrastados |
|---|---:|---|
| IF (1.1–1.9) | 9 | PC+4, fetch, imagen, candidato, entrada/actualización IF/ID y reset |
| ID (2.1–2.10) | 10 | whitelist, controles, RF, inmediato, bypass, candidato ID, load-use y latch |
| EX (3.1–3.15) | 15 | forwarding, operandos, ALU, enlace, targets, flujo, validación y EX/MEM |
| MEM y frontera WB (4.1–4.7) | 7 | tamaños, loads, stores, cero lógico, valor WB y MEM/WB |
| Pipeline Hazard Control (5.1) | 1 | ocho acciones, antigüedad, onehot0 y terminales |
| Metadata (6.1–6.3) | 3 | captura de causa/PC, validez global y retención |
| Vacío y fase terminal (7.1–7.2) | 2 | cuatro valid actuales/next y predicados combinacionales |
| Control global (8.1–8.3) | 3 | comandos, 14 estados, autorización y origen del ciclo |
| Carga/preparación/estado (9.1–9.4) | 4 | carga privada, commit de imagen, preparación y contador |
| **Total** | **54** | Cada bloque tiene productor/consumidor, contrato temporal y criterio futuro. |

La frontera de Processor Top, los endpoints de Debug y las reglas de plataforma se describen en las secciones 0 y 10; son composición e interfaces parciales, no bloques nuevos añadidos al pipeline.

## Comprobaciones ejecutadas

La revisión combina contraste semántico de las tablas y contratos con extracción y comparación mediante Python estándar. Las enumeraciones booleanas comprueban especificaciones documentadas, no un procesador implementado.

<!-- BEGIN VERIFICATION RESULTS -->
| Comprobación | Resultado |
|---|---|
| Cobertura y contratos | 54/54 bloques conservados, con los mismos nombres e identificadores; ninguno perdió una señal tabulada del mapa original. |
| Campos de pipeline | Coincidencia exacta con Pipeline CPU: IF/ID 5 campos / 69 bits; ID/EX 15 / 193; EX/MEM 8 / 139; MEM/WB 6 / 103. |
| Conexiones por bloque | 506 filas de conexión extraídas; 142 relaciones internas, enumeradas en ambos extremos. Ninguna fuente/destino sin bloque o frontera identificable. |
| Señales y anchos | 226 entradas de señales internas cotejadas con una salida del productor; 217 comparaciones de ancho numérico, incluidos slices. Sin señal sin salida fuente ni discrepancia de ancho. Los tipos simbólicos y fronteras físicas parciales se revisaron separadamente. |
| Acciones/enables | Diez ecuaciones locales de actualización coinciden con Control y hazards vigente. |
| Arbitraje de pipeline | 192 combinaciones de ciclo, fase y candidatos: acuerdo 47 y consolidación coinciden con la prioridad definida y onehot0; HOLD y terminal vacío no seleccionan acción. |
| Comandos | 224 combinaciones de 14 estados, reset y solicitudes LOAD/STEP/RUN: prioridad y elegibilidad mutuamente excluyentes. |
| Autorización/origen | 448 combinaciones, agregando prepare_done: ecuaciones del acuerdo 44 y ejecución consolidada coinciden; reset/LOAD aceptado suprimen, LOAD rechazado no cancela automático y PREPARING_READY no ejecuta CPU. |
| Grafo combinacional | 39 bloques puramente combinacionales y 46 aristas entre ellos, sin ciclos. La frontera Q/D de latches/FSM y la relación valid_next → pipeline_empty_next → next_state se contrastaron además con I20; no es un análisis de netlist RTL. |
| Parametrización | REFERENCE y ALT_1000 coinciden con los anchos derivados; capacidad mínima de 4 bytes no produce índice de ancho cero y capacidad de 2^32 requiere tamaño de imagen de 33 bits. |
| Autoridad | SHA-256 sin cambios de los 14 documentos de arquitectura y de decisions, requirements, pending_decisions y consigna: 18 fuentes. El plan solo incorpora el estado del entregable. |
| Pendientes | Los ocho identificadores originales coinciden exactamente con la tabla de fronteras abiertas de interfaces.md. |
| Navegación | 105 referencias de interfaces/auditoría/README/plan y 366 en la documentación actual del TP3 más README raíz, sin archivos o anclas faltantes. |
| Markdown | Anclas explícitas únicas, fences cerrados y columnas consistentes; operadores OR escapados en tablas. |

Las 11 filas de acción/interfaz conceptual sin nombre físico de puerto (clear, escritura Loader, tamaño privado y commit) se revisaron semánticamente y se mantienen vinculadas a las fronteras parciales de la sección 15. No se asignaron anchos ficticios a byte_enable o global_state. Las referencias históricas de auditorías anteriores siguen siendo evidencia histórica y no se usan como contratos actuales.
<!-- END VERIFICATION RESULTS -->

## Contrastes semánticos adicionales

- **Decoder y datos:** legalidad estricta de 32 RV32I más halt exacto, controles/códigos aprobados, inmediatos por formato, shifts de cinco bits y comparación signed/unsigned. La ALU heredada no se presenta como extendida e implementada.
- **Forwarding/bypass/load-use:** prioridades por fuente y antigüedad, x0, fuentes realmente usadas, load que bloquea versión vieja MEM/WB y dato de store separado. Bypass WB→ID depende del writeback efectivo; no se añade un interlock EX.
- **Faults/redirect/halt:** IF detecta y transporta; ID confirma. EX prevalece sobre ID, misalignment sobre rango del mismo acceso. Fault propio y halt no ingresan válidos a EX/MEM; redirect conserva enlace. Metadata usa PC del causante, no EA, target ni PC global.
- **Tiempo y commits:** datos preflanco, prioridad de reset/LOAD/preparación, retención completa en HOLD y commits MEM/WB anteriores preservados ante frontera joven. `prepare_active` no es un write-enable; `prepare_done` requiere preparación terminada antes del primer ciclo.
- **Memorias:** lectura combinacional/escritura síncrona, direccionamiento por bytes, little-endian, región completa en 33 bits y sin aliasing por truncamiento, validez por byte, atomicidad y propiedad exclusiva de cada recurso. No se presupone una máscara física ni una tecnología de RAM inferida.
- **Sesión y observación:** commit solo en PREPARING_READY, reutilización de imagen desde terminal, contador módulo 2^64, snapshot de un instante y reset sin sesión válida. `global_state` es la única fase registrada; fault_info_valid e image_valid son derivados.
- **Alcanzabilidad:** el drain legal solo contiene anteriores en EX/MEM y MEM/WB. La rama act_drain_load_use permanece contractual y se verifica artificialmente; no se exige alcanzarla desde una sesión legal.

Estos contrastes remiten a [I01–I25](architecture/architectural_invariants.md), las etapas y los contratos transversales. El plan de verificación RTL deberá desarrollar los criterios de cada bloque y comprobar las propiedades en una realización concreta.

## Estado que permanece abierto

De las ocho decisiones originales, DEC-SYS-005 quedó aprobada el 2026-10-01 al cerrar criterio y representación de DMEM utilizada. DEC-ARCH-009 también quedó aprobada el 2026-10-01 al completar representación externa y códigos de estado. DEC-PROTO-002/003 quedaron aprobadas el 2026-10-01 al cerrar comandos auxiliares, tiempos y recuperación. DEC-PROTO-001 quedó aprobada el 2026-10-01 tras la [revisión y consolidación](debug_protocol_audit.md). Continúan pendientes tres: DEC-SYS-007, DEC-SYS-009 y DEC-SYS-008; los puertos y FSM privadas se concretan en diseño de bloques. Los mínimos observables, el ancho del contador y las políticas de CPU ya aprobadas no se reabren.

Antes de implementar conexiones físicas parciales se deben concretar los detalles enumerados en [interfaces.md, sección 15](interfaces.md#15-fronteras-parciales-y-condiciones-de-salida): escritura Loader/IMEM, stream, mantenimiento/preparación, adaptación de lanes, ownership, captura Debug, agrupación RTL y plataforma. No se introduce una selección silenciosa de esas realizaciones.

No se ejecutaron simulaciones RTL ni síntesis. Tampoco se verificaron inferencia de RAM, timing, constraints, FPGA o un XML draw.io externo. El siguiente entregable de verificación sigue siendo `verification_plan.md`; los criterios del documento son su insumo, no evidencia de pruebas futuras superadas.
