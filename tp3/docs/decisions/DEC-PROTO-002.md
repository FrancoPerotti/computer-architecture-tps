### DEC-PROTO-002 — Comandos adicionales

**Estado:** Aprobada.

**Dominio:** Debug / Servicios de control y observación.

**Contrato:** [Protocolo UART](../protocol.md) y [Control de ejecución](../architecture/session/execution_control.md).

**Contexto:** La aplicación PC necesita consultar disponibilidad, solicitar reset global y recibir Debug en los puntos de observación del procesador.

**Decisión:** Los servicios son LOAD, RUN, STEP, RESET y CHECK_READY, con los [códigos y formatos del protocolo](../protocol.md#solicitudes-y-respuestas).

CHECK_READY informa si puede comenzar LOAD mediante `05 03` (READY) o `05 04` (BUSY). No reserva la carga, no confirma una imagen válida y no modifica la CPU. La PC consulta antes de LOAD; FPGA evalúa la carga por sus condiciones actuales.

RESET se solicita con `04`. Cuando se reconoce, FPGA transmite `04 01` completo, incluido el último Stop, antes de pedir reset global. La CPU puede continuar mientras sale la aceptación. El reset deja NO_IMAGE e imagen inválida; no exige borrar físicamente todos los arrays ni reconfigurar el bitstream.

RESET UART se reconoce en contexto de comandos o durante RUN efectivo después de ACCEPTED, sin preparación activa ni terminal ya observable. En tamaño y contenido LOAD los bytes pertenecen a la carga. Durante aceptaciones, preparación, respuestas, recuperación y exclusión Debug se descarta RX adicional.

Reconocer RESET cancela la obligación terminal de RUN. Si CPU termina en ese mismo flanco se completa RESET/ACCEPTED y no se produce el resultado del RUN abandonado. Si el terminal ya era observable antes de reconocer el comando, su exclusión domina y RESET se descarta. El botón físico pide el mismo reset directamente y puede abortar una transmisión, sin aceptación UART ni mensaje de arranque.

Debug se entrega automáticamente después de cada STEP realizado y al terminal de RUN. No existe una solicitud adicional de snapshot ni observación durante ejecución continua. PC espera el intercambio completo; durante RUN efectivo solo admite RESET. CHECK_READY enviado durante RUN provoca recuperación RX sin respuesta, incluso si PC lo envía para recuperar comunicación sin conocer la fase.

Fuera de LOAD, la [recuperación PC](../protocol.md#perder-una-respuesta-o-conexión) intenta CHECK_READY y, si falla, un único RESET automático. Ese intento puede cancelar RUN e invalidar la imagen. Debe confirmarse mediante `04 01` desde el primer byte; si falla no se reintenta ni se inicia otra operación automáticamente. RESET confirmado devuelve al flujo normal de sesión reiniciada, sin repetición automática de LOAD, RUN o STEP.

**Justificación:** Consulta, reset y Debug automático cubren disponibilidad, control y observación. Completar la aceptación antes del reset permite confirmar el comando; retener la observación hasta el fin físico mantiene coherente Debug.

**Consecuencias:** La PC distingue RESET enviado de RESET reconocido y debe informar si la recuperación utilizó reset. Los controles UART no agregan estados a la Global FSM. La selección de interfaz PC y la implementación y verificación de integración están pendientes.

**Requisitos afectados:** `REQ-EXEC-012`, `REQ-EXEC-015`, `REQ-EXEC-018`, `REQ-MEM-019`, `REQ-MEM-028`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.
