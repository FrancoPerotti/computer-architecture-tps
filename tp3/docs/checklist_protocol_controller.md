# Checklist — Documentación de Protocol Controller y protocolo

- **Tipo:** checklist de documentación y verificación.
- **Estado:** revisión documental completada; contratos, referencias, diagramas y casos alineados con el diseño vigente. Implementación y pruebas RTL pendientes.
- **Base:** Controller de 11 estados, salidas Mealy separadas en control y datos, alias explícitos y admisión exclusiva de RESET durante RUN efectivo.
- **Diseño:** [Protocol Controller](architecture/debug/protocol_controller.md).

Los documentos deben describir únicamente el diseño vigente: comportamiento, interfaces, condiciones, responsabilidades y justificaciones aplicables. El historial pertenece a Git. No se incluyen acuerdos descartados, comparaciones entre versiones, nombres obsoletos ni evidencia de diseños que no corresponden a las tablas vigentes.

Cada regla se desarrolla en la sección que le corresponde. Las secciones de comandos describen sus solicitudes, respuestas y efectos; el orden de operaciones y la recuperación se explican en sus apartados. El protocolo utiliza términos del intercambio PC–FPGA; los estados y controles internos se detallan en arquitectura.

Las marcas distinguen contratos documentados de tareas pendientes. Los [modelos abstractos](../tools/verification/README.md) permiten repetir las comprobaciones del Controller y de recuperación PC; no acreditan implementación ni pruebas RTL.

## 1. Contrato de operación

- [x] Definir recuperación PC fuera de LOAD: CHECK_READY y, si falla, un único RESET automático según el [procedimiento](protocol.md#perder-una-respuesta-o-conexión).
- [x] Especificar que ese RESET puede cancelar RUN e invalidar la imagen; exigir aceptación completa, sin reintento automático fallido ni repetición automática de LOAD, RUN o STEP.
- [x] Definir las ventanas de RESET y su prioridad respecto del terminal RUN, incluida la coincidencia con el último ciclo CPU.
- [x] Definir que un byte distinto de RESET o un error UART durante RUN efectivo inicia RECOVER_RX sin respuesta.
- [x] Definir códigos, formatos de mensajes, contenido Debug y condiciones de admisión de la aplicación PC.

## 2. Protocolo externo

Documento: [protocol.md](protocol.md).

- [x] Especificar CHECK_READY en contexto de comandos y su tratamiento sin respuesta durante RUN; distinguir consulta normal de intento de recuperación con fase desconocida.
- [x] Definir cuándo PC puede iniciar LOAD, RUN y STEP y qué intercambio completo espera.
- [x] Distinguir admisión UART de rechazo por elegibilidad interna; definir tráfico fuera de fase sin respuesta durante RUN.
- [x] Publicar la matriz de estado CPU y fase de transporte.
- [x] Mostrar secuencias y diagramas de RUN con resultado terminal o RESET reconocido.
- [x] Definir recuperación desde el primer byte indebido durante RUN, sin interpretar cabeceras ni bytes residuales como comandos.
- [x] Explicar terminal RUN temprano: observación retenida y ACCEPTED completo antes del resultado con Debug.
- [x] Definir salida de recuperación RX con silencio, FIFO vacía, serializador libre y Debug liberado; volver a esperar RUN si sigue activo.
- [x] Definir consulta única, descarte adicional si hubo datos y RESET confirmado; detener la recuperación automática si no se confirma.
- [x] Especificar W_load(N), W_debug(C), plazos de 200 ms y R = 100 ms, con recuperación LOAD y reintento manual propios.

## 3. FSM de Protocol Controller

Documento: [protocol_controller.md](architecture/debug/protocol_controller.md).

- [x] Publicar los 11 estados con significado, entradas relevantes y continuación.
- [x] Publicar entradas con origen y significado y salidas con destino y significado; indicar anchos y separar puertos de conexiones internas a registros.
- [x] Usar nombres en inglés coherentes en recorridos, ecuaciones, tablas y casos.
- [x] Explicar la respuesta combinacional de solicitudes desde WAIT_COMMAND y validación del quinto byte desde RECEIVE_LOAD_SIZE.
- [x] Definir WAIT_RESPONSE_SENT para respuestas cortas o con Debug, con limpieza determinada por debug_hold.
- [x] Distinguir WAIT_RUN_ACCEPT_SENT y WAIT_RUN_END por sus continuaciones y admisión de RESET.
- [x] Definir los alias rx_byte_valid, run_ended, last_size_byte, load_size_valid y timer_limit_reached, y load_size_candidate unsigned de 40 bits. Usar response_busy directamente para disponibilidad del serializador.
- [x] Separar Mealy Control Outputs y Mealy Data Outputs en tablas principal y de acciones comunes. Enumerar solo controles que valen uno; los omitidos valen cero salvo acciones comunes.
- [x] Definir entrega directa con response_start, response_with_debug, response_opcode y response_result, y captura interna de 17 bits en el serializador.
- [x] Justificar disponibilidad del serializador en cada fase productora de respuesta y conservación del terminal RUN mientras sale ACCEPTED.
- [x] Definir prioridad absoluta de reset, inhibición de acciones normales y prioridad error UART > byte válido > timeout.
- [x] Publicar acciones comunes de consumo RX, retención terminal, entrega de respuesta y selección Debug.
- [x] Usar load_byte_valid para entrega y decremento de load_bytes_remaining, incluida la última entrega.
- [x] Definir debug_read_select y su distribución a RF y DMEM, con activación inmediata por terminal RUN e inhibición durante reset.
- [x] Definir limpieza de debug_hold en WAIT_RESPONSE_SENT y RECOVER_RX únicamente al fin físico de Debug.
- [x] Definir run_result_required y sus controles run_result_required_set/clear: limpiar al capturar el terminal en el serializador o reconocer RESET.
- [x] Asignar load_size_received, size_byte_index y load_bytes_remaining al Controller; asignar ensamblado de palabras y escrituras IMEM al Loader.
- [x] Generar solicitudes independientemente de command_accepted y consumir aceptación combinacional en el mismo flanco.
- [x] Usar el quinto byte actual para validar tamaño, presentar load_size_bytes y cargar faltantes.
- [x] Cerrar WAIT_PREP_DONE con !prepare_active y WAIT_STEP_END con cpu_cycle_fire. Explicar entrada con preparación LOAD activa y captura de LOAD/DONE un clock después de publicar la imagen.
- [x] Definir valores por defecto, retención, prioridades y ejemplos de eventos coincidentes.
- [x] Definir codificación one-hot de 11 bits, orden y estado de reset.
- [x] Documentar recursos registrados de 91/90 bits para REFERENCE/ALT_1000.
- [x] Identificar evidencia correspondiente a las tablas vigentes y sus límites; distinguir modelo abstracto de implementación.
- [x] Distinguir salidas Mealy y uart_reset_request registrada; publicar la tabla Moore sin salidas exclusivas de la fase.

## 4. Interfaces y módulos relacionados

- [x] En [interfaces.md](interfaces.md), especificar solicitudes, captura de tamaño y entrega directa al serializador en las secciones del Controller. Contrastar las conexiones de RF (§2.2), DMEM (§4.2), Loader (§9.1 y §15.18) y preparación (§9.2).
- [x] En [system_composition.md](architecture/system_composition.md), definir solicitud y aceptación combinacionales, prepare_active y cpu_cycle_fire hacia Controller, prepare_done y load_ok hacia Global, y debug_read_select hacia RF/DMEM.
- [x] En [loader.md](architecture/session/loader.md), definir tamaño completo en la aceptación y última escritura/load_ok en el flanco de la última entrega válida.
- [x] En [debug_architecture.md](architecture/debug/debug_architecture.md), definir admisión durante RUN, orden ACCEPTED/terminal, retención y selección común RF/DMEM.
- [x] En [response_serializer.md](architecture/debug/response_serializer.md), definir captura directa con response_start y serializador libre; conservar sus registros propios, fin físico y direcciones independientes RF/DMEM.
- [x] En [interfaces.md](interfaces.md), conectar debug_read_select a los selectores de lectura CPU/Debug de RF y DMEM.
- [x] En [memory_architecture.md](architecture/memory/memory_architecture.md), conectar debug_read_select al selector CPU/Debug de DMEM. Los puertos locales pueden tener nombres propios si la conexión es inequívoca.
- [x] En [reset_integration.md](architecture/platform/reset_integration.md), definir secuencia de reconocimiento, aceptación completa, solicitud registrada y reset distribuido.
- [x] En [uart_core.md](architecture/uart/uart_core.md), definir presupuesto del quinto byte y generación de rx_activity, que incluye trama en curso, línea baja y cambios de nivel.
- [x] En [uart_fifo.md](architecture/uart/uart_fifo.md), definir consumo RX independiente de TX y sus conexiones al Controller.
- [x] En [system_overview.md](architecture/system_overview.md), describir el Controller de 11 estados y el contrato de admisión UART.
- [x] Contrastar [inventario](architecture/module_inventory.md), [invariantes](architecture/architectural_invariants.md), [Execution Control](architecture/session/execution_control.md) y [Session Preparation](architecture/session/session_preparation.md) con las responsabilidades de cada módulo.
- [x] Dejar estos documentos con sus contratos y justificaciones vigentes, sin registros de evolución del diseño.

## 5. Requisitos y decisiones

- [x] Definir criterios de REQ-UART-003/004/006/007/008/010/011, REQ-DBG-011 y REQ-SW-010/011 en [requirements.md](requirements.md).
- [x] Cumplir las obligaciones de la [consigna](consigna.md) y mantener su trazabilidad a requisitos.
- [x] Definir formato, admisión, RESET y recuperación en [DEC-PROTO-001](decisions/DEC-PROTO-001.md), [DEC-PROTO-002](decisions/DEC-PROTO-002.md) y [DEC-PROTO-003](decisions/DEC-PROTO-003.md).
- [x] Describir estados, Mealy, recursos, señales y coordinación vigentes en [DEC-SYS-007](decisions/DEC-SYS-007.md), sin acuerdos parciales ni comparaciones de versiones.
- [x] Publicar decisiones de protocolo con justificación y enlaces a contratos vigentes en el [índice](decisions/decisions.md).
- [x] Contrastar las referencias de decisiones arquitectónicas con admisión UART y elegibilidad Global.
- [x] En [pending_decisions.md](decisions/pending_decisions.md), distinguir la política de recuperación definida de la selección pendiente de CLI/TUI/GUI para DEC-SYS-008.

## 6. Verificación

En [uart_debug.md](verification/uart_debug.md), las marcas registran casos y expectativas documentados; su ejecución RTL, timing y placa continúa pendiente:

- [x] TEST-UART-003: definir matriz de comandos admitidos y tráfico fuera de fase; observar solicitudes directas desde WAIT_COMMAND y RECEIVE_LOAD_SIZE.
- [x] TEST-UART-004/005: cubrir tamaño completo del quinto byte, límites, prioridad error/byte/timeout y última escritura simultánea a la entrega.
- [x] Comprobar entrada a WAIT_PREP_DONE con preparación activa y LOAD/DONE un clock después de publicación. Comprobar respuesta y retención STEP en el flanco de cpu_cycle_fire, aunque prepare_active todavía valga uno. Incluir reset.
- [x] TEST-UART-006: cubrir recuperación por tráfico durante RUN y retorno a WAIT_RUN_END. Comprobar que rx_activity impide cerrar silencio con trama, cambios o línea baja, sin prolongar timeout LOAD por actividad sin byte válido.
- [x] TEST-UART-009/010: cubrir fin físico, terminal temprano, preparación y recorridos completos.
- [x] TEST-UART-011: comprobar exclusión y selección RF/DMEM hasta el último Stop.
- [x] Comprobar una entrega/decremento por load_byte_valid; response_start con serializador libre, campos válidos y un único productor, incluido opcode desconocido.
- [x] Cubrir RUN terminado antes, en el mismo flanco y después del último Stop de ACCEPTED; sin duplicación ni pérdida de resultado, con obligación hasta captura. Incluir recuperación RX y RESET coincidente o posterior al terminal.
- [x] Contrastar las dependencias combinacionales de solicitud, aceptación, autoridad de ciclo y respuesta con las ecuaciones y tablas vigentes, sin lazos ni uso del estado futuro para autorizar el mismo ciclo. Incluir Loader, preparación, selección Debug y petición registrada de reset.
- [x] Guardar modelos, estímulos, configuración y comandos reproducibles para las 11 fases y recuperación PC. Cubrir cierres de WAIT_RESPONSE_SENT con/sin Debug y liberación solo al fin físico. Véase [ejecución y límites](../tools/verification/README.md).
- [x] TEST-UART-012: cubrir orden ACCEPTED/terminal, tráfico indebido durante RUN y prioridades de RESET conforme al contrato.
- [x] TEST-UART-013: cubrir ventanas RESET, coincidencia con último ciclo, terminal ya observable y botón físico.
- [x] TEST-UART-014: contrastar las cotas calculadas con los plazos de ambos perfiles, documentar las fronteras de medición y reutilizar los estímulos abstractos de recuperación PC. La revisión de dependencias figura arriba; las mediciones RTL y del cliente implementado siguen pendientes.

Además:

- [x] En [execution.md](verification/execution.md), definir TEST-EXEC-008 para RUN no terminante y recuperación por RESET, sin consultas normales durante ejecución.
- [x] En [cases.json](verification/cases.json), contrastar entradas, expectativas, tipos de estímulo, referencias y conteos con el diseño vigente; distinguir tráfico inválido de fixtures artificiales.
- [x] Definir la trazabilidad de cada caso mediante su grupo, fuente y familia hacia los contratos y requisitos de la especificación. Verificar IDs, reutilizaciones y enlaces con `CatalogChecks`, sin atribuir a una variante toda la cobertura del grupo.
- [x] Completar [coverage.md](verification/coverage.md) y [verification_plan.md](verification/verification_plan.md) para las reglas e invariantes del sistema, distinguiendo modelos y cotas de la ejecución pendiente en RTL, cliente y placa.
- [x] Distinguir evidencia abstracta de resultados RTL, síntesis y placa, con configuración y límites explícitos en el plan y junto a los modelos reproducibles.

## 7. Diagramas e índices

- [x] Publicar [fsm_protocol_controller.drawio.xml](diagrams/generated/fsm_protocol_controller.drawio.xml) como vista resumida de los 11 estados y sus recorridos, con SVG incrustado en el [documento del controlador](architecture/debug/protocol_controller.md#diagrama-de-estados) y PNG de preview. Las condiciones exactas, prioridades y salidas permanecen en sus tablas.
- [x] Generar SVG y PNG del XML revisado del Protocol Controller y registrar su fuente, hash y enlaces en el manifiesto.
- [x] Contrastar el [documento de diseño](proposal_protocol_controller.md) con las tablas, recuperación PC y evidencia aplicables, sin comparativas de versiones.
- [x] Verificar índices, referencias y anclas hacia conceptos vigentes; enlazar el controlador, su diagrama, los criterios de diseño y los modelos reproducibles desde el índice general.

## 8. Consistencia final

- [x] Comprobar que documentos y diagramas describan únicamente el estado actual, sin acuerdos descartados, nombres obsoletos, relatos de cambios o evidencia de otro diseño.
- [x] Comprobar que ninguna secuencia prometa CHECK_READY/BUSY durante RUN; distinguir consulta de recuperación y descarte si RUN continúa.
- [x] Contrastar protocolo, requisitos, aplicación, tablas y casos sobre tráfico fuera de fase y recuperación.
- [x] Verificar nombres en inglés y definiciones completas de alias, prioridades y uso del quinto byte actual.
- [x] Confirmar los 14 estados Global, prioridades, elegibilidad y autoridad de ciclos CPU.
- [x] Verificar formatos, contenido Debug, ciclo único STEP y secuencia física RESET.
- [x] Usar «respuesta corta» y distinguir solicitud, captura en serializador y fin físico. Los estados *_SENT esperan esta última frontera.
- [x] Completar el cierre cuando enlaces, conteos, diagramas y expectativas correspondan al mismo diseño.
