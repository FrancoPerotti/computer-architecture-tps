### DEC-PROTO-003 — Timeouts y recuperación

**Estado:** Aprobada.

**Dominio:** Debug / Tiempos FPGA–PC y recuperación del enlace.

**Contrato:** [Protocolo UART](../protocol.md#esperas-y-recuperación-desde-pc) y [Protocol Controller](../architecture/debug/protocol_controller.md).

**Contexto:** Recepciones parciales y fallos del enlace requieren plazos por fase y una recuperación que no confunda bytes residuales con comandos o confirmaciones.

**Decisión:** UART usa 19200 baud nominales, 8N1 y clock funcional de 50 MHz. FPGA supervisa tamaño y contenido LOAD con T = 100 ms (5.000.000 clocks) de inactividad. El tamaño comienza tras el opcode; el contenido después del fin físico de ACCEPTED. La prioridad es error UART, byte válido y vencimiento sin ambos. Actividad de línea sin byte válido no prolonga T.

Una cabecera incompleta conserva imagen y sesión; el fallo de una carga aceptada deja imagen inválida. La recuperación RX descarta bytes y exige R = 100 ms continuos sin actividad, línea alta, ninguna trama en curso y FIFO vacía. También requiere serializador libre y Debug liberado antes de salir. Conserva TX y no aplica reset global. Si RUN sigue activo, CPU y obligación terminal continúan, y al recuperar RX solo se admite RESET; sin resultado RUN pendiente se vuelve al contexto de comandos.

Error UART en contexto de comandos inicia recuperación sin respuesta. Durante RUN efectivo, un byte distinto de RESET o error UART tiene el mismo tratamiento. RESET se descarta durante recuperación.

PC prepara la imagen completa, envía exactamente N bytes seguidos después de ACCEPTED y escucha respuestas mientras transmite. Si LOAD falla, cesa envíos y cancela lo pendiente en lo posible. Espera `W_load(N) = 100 * ceil(((N+6)*10*1000/19200 + 100 + 100)/100)` ms antes de consultar; si falta respuesta repite esa ventana y consulta. El reintento LOAD requiere una acción del usuario y transmite una carga completa.

| Espera PC | Plazo |
|---|---|
| CHECK_READY, aceptación LOAD o RUN | 200 ms desde inicio de solicitud |
| Final LOAD | `N*10*1000/19200 + 201` ms desde inicio del contenido |
| Aceptación RESET | 200 ms desde solicitud |
| Cabecera STEP | 200 ms desde solicitud |
| RUN antes del primer byte terminal | Sin timeout de ejecución |
| Cabecera terminal RUN iniciada | 200 ms desde su primer byte |
| Parte fija Debug, 228 bytes | 319 ms desde cabecera completa |
| Lista Debug, K > 0 | `ceil(5*K*10*1000/19200 + 200)` ms desde used_count completo |
| K = 0 | Respuesta terminada al completar parte fija |

La preparación LOAD tiene un presupuesto máximo de 1 ms incluido commit para REFERENCE y ALT_1000; no es una espera fija. Sus capacidades y presupuestos de transporte son los del [perfil compartido](../protocol.md#perfil-de-memoria).

Fuera de LOAD, PC informa timeout, desconexión o truncamiento, abandona el parcial y conserva el último snapshot completo como observación anterior. No repite automáticamente LOAD, RUN o STEP. Para recuperar comunicación:

1. Lee y descarta RX hasta W_debug(C) de silencio continuo, medido con reloj monótono y reiniciado por cada recepción. Usa capacidad DMEM C: `W_debug(C) = 100*ceil((200+319+ceil(5*C*10*1000/19200+200))/100)` ms; REFERENCE: 6100 ms; ALT_1000: 3400 ms.
2. Envía una única consulta CHECK_READY sin limpiar RX. Exige `05 03` o `05 04` como los primeros bytes recibidos, completos dentro de 200 ms desde el inicio del envío de la consulta. Una consulta válida recupera comunicación sin RESET y conserva los bytes posteriores.
3. Si vence la consulta sin datos, intenta RESET respetando R desde la última transmisión PC; los 200 ms cubren R bajo los tiempos previstos del enlace. Si hubo datos inválidos o respuesta parcial vencida, inicia otro descarte completo por W_debug y después intenta RESET, sin repetir CHECK_READY.
4. Registra el único intento consumido antes de enviar `04` y exige `04 01` como los primeros bytes recibidos, completos dentro de 200 ms desde el inicio del envío de RESET. Con aceptación completa informa el reset y vuelve al flujo normal de sesión reiniciada, sin reanudar la operación abandonada.
5. Sin aceptación válida, con truncamiento o nueva pérdida de enlace, informa fallo y no envía automáticamente otra consulta, RESET u operación. Un nuevo intento requiere acción explícita del usuario. Una desconexión no renueva el presupuesto consumido.

Cada descarte inicia su propio intervalo. Datos pendientes al vencer el silencio se procesan primero y aplazan el envío; no se limpia RX ni se buscan pares válidos dentro de payloads. La fragmentación del driver conserva las fronteras. El enlace de laboratorio entrega bytes en orden dentro de los presupuestos del protocolo.

La consulta de recuperación enviada durante RUN efectivo provoca recuperación RX sin respuesta. El RESET automático puede interrumpir un programa no terminante e invalidar la imagen. Si terminal RUN ya es observable antes de reconocer RESET, el comando puede descartarse y salir Debug; ese intento queda sin confirmar y tampoco se repite. RESET reconocido en el flanco en que CPU termina cancela la obligación RUN. Enviar RESET no demuestra que haya ocurrido.

**Justificación:** Los plazos distinguen transmisión, preparación y ejecución. El silencio drena respuestas y la validación desde el primer byte evita confundir payloads con confirmaciones. Un único RESET permite intentar recuperar una ejecución no terminante sin consultas indefinidas ni reintentos de reset no confirmado.

**Consecuencias:** Se distinguen recuperación LOAD y recuperación fuera de LOAD. La política PC autoriza un solo RESET automático por episodio y exige informar su uso. Las pruebas de cliente, RTL, timing e integración física están pendientes.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-DBG-013`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.
