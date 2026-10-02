# Trabajo Práctico N.º 3 — Procesador RISC-V Pipeline

Implementación en FPGA de un procesador RISC-V de 32 bits con pipeline de cinco etapas, carga y reprogramación de programas, control de ejecución y depuración mediante UART, junto con el software de PC necesario para operarlo.

## Arquitectura vigente

Los documentos de arquitectura describen conjuntamente el núcleo CPU y los contratos internos ya aprobados. El [protocolo UART/Debug](docs/protocol.md) y la representación externa están aprobados. La realización de bloques UART/Debug y el software de PC conservan los pendientes de [decisiones abiertas](docs/pending_decisions.md); los documentos no acreditan implementación.

El recorrido de lectura comienza por la visión del sistema y el pipeline, continúa con el datapath y las etapas, y luego reúne control, faults, memoria y sesión. Debug utiliza esos contratos para definir el significado y la coherencia de la observación; las invariantes cierran la lectura con propiedades verificables de integración.

| Orden | Documento | Responsabilidad |
|---|---|---|
| 1 | [Visión general del sistema](docs/architecture/system_overview.md) | CPU, carga, comunicación y software de PC; límites entre subsistemas. |
| 2 | [Pipeline CPU](docs/architecture/cpu_pipeline.md) | Cinco etapas, validez, identidad y contrato completo de los cuatro registros interetapa. |
| 3 | [Datapath](docs/architecture/datapath.md) | PC, memorias, RF, inmediatos, muxes, operandos efectivos, ALU, targets, enlace y recorridos hasta writeback. Las señales de selección son entradas del plano de datos. |
| 4 | [Etapa IF](docs/architecture/stage_if.md) | Fetch, formación de instrucción o candidato y conexiones de PC e IF/ID. |
| 5 | [Etapa ID](docs/architecture/stage_id.md) | Decoder, whitelist y controles aprobados, lectura del RF, inmediato e interfaz de bypass/detector load-use. |
| 6 | [Etapa EX](docs/architecture/stage_ex.md) | Consumo de operandos efectivos, ALU, direcciones, targets, link, resultado y conexiones de validación. |
| 7 | [Etapa MEM](docs/architecture/stage_mem.md) | Selección/ensamblado/extensión de loads, commit de stores y formación de `wb_value`. |
| 8 | [Etapa WB](docs/architecture/stage_wb.md) | Commit del resultado registrado al RF, usando estado preflanco y preservando `x0`. |
| 9 | [Control del pipeline y hazards](docs/architecture/control_and_hazards.md) | Selección de forwarding y bypass, load-use, stalls, bubbles, flushes, prioridades, ocho acciones y actualización de PC/latches. |
| 10 | [Faults, redirects y terminación](docs/architecture/faults_and_termination.md) | Candidatos y confirmaciones, siete causas, prioridad por edad, fetch IF→ID, redirects, halt, precisión, metadata, frontera y drain. |
| 11 | [Arquitectura de memoria](docs/architecture/memory_architecture.md) | Harvard, bytes/little-endian, imagen confirmada, capacidad/rango/alineación, cero lógico, atomicidad y ownership. |
| 12 | [Control de ejecución y sesión](docs/architecture/execution_control.md) | Ciclo de vida de sesión, RUN/STEP, autorización de ciclos, preparación, drain, terminales, reutilización de imagen y contador lógico. |
| 13 | [Arquitectura de Debug](docs/architecture/debug_architecture.md) | Estado arquitectónico y persistente, snapshot de un único instante lógico, contenido observable y representación externa aprobada; realización física pendiente. |
| 14 | [Invariantes arquitectónicas](docs/architecture/architectural_invariants.md) | Propiedades I01–I25 de seguridad, coherencia, precisión y alcanzabilidad, y cobertura legal/artificial. |

Las etapas describen la realización local y enlazan los contratos transversales. El esquema completo de cada latch está en Pipeline CPU; las políticas de selección y actualización están en Control del pipeline; las confirmaciones y causas están en Faults. Memoria fija los valores y accesos válidos, mientras Control de ejecución autoriza cuándo existe un ciclo CPU.

Los [contratos de interfaces](docs/interfaces.md) formalizan el mapa de bloques, entradas y salidas: reúnen 54 bloques funcionales, conexiones, anchos, comportamiento temporal y criterios de verificación por bloque. Deben consultarse junto con la arquitectura antes de implementar. Las interfaces físicas de Loader, mantenimiento, Debug, protocolo y plataforma conservan los límites indicados en ese documento; su existencia no acredita el cierre global del gate de interfaces ni implementación RTL.

## Autoridad y trazabilidad

| Documento | Función |
|---|---|
| [Consigna](docs/consigna.md) | Enunciado del trabajo práctico. |
| [Requisitos](docs/requirements.md) | Obligaciones identificadas y criterios de aceptación. |
| [Decisiones aprobadas](docs/decisions.md) | Respaldo de la consolidación; conserva acuerdos históricos con sus revisiones explícitas. |
| [Decisiones pendientes](docs/pending_decisions.md) | Los tres asuntos abiertos de realización UART y software. |
| [Protocolo UART/Debug](docs/protocol.md) | Formatos, códigos, secuencias, Debug, tiempos y recuperación aprobados. |
| [Contratos de interfaces](docs/interfaces.md) | Conexiones y contratos por bloque derivados de la arquitectura, con fronteras parciales explícitas. |
| [Plan de desarrollo](docs/plan.md) | Fases, entregables y gates de implementación/verificación; una actividad planificada no acredita su realización. |

Ante una contradicción, se contrasta la consolidación con la revisión aprobada aplicable. Un acuerdo sustituido o una traza histórica no constituye una arquitectura alternativa vigente.

## Auditorías

La [revisión del protocolo](docs/debug_protocol_audit.md) registra los recorridos y cálculos del contrato consolidado. La [auditoría de interfaces](docs/interfaces_audit.md) registra la formalización del mapa y su contraste con la arquitectura. La [auditoría final de integración](docs_integration_audit.md) registra los hallazgos iniciales, el plan, los cambios aplicados y su verificación documental. La [auditoría integral anterior](docs_audit.md) y la [segunda auditoría adversarial](docs_audit_v2.md) conservan evidencia fechada; sus avisos de vigencia distinguen ese estado histórico del actual.

El diagrama externo en draw.io mencionado en las auditorías anteriores no está incluido en este árbol. Los diagramas disponibles para esta revisión son los Mermaid de los documentos de arquitectura.
