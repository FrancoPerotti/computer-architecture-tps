### DEC-PROTO-001 — Formato detallado del protocolo

**Estado:** Aprobada.

**Dominio:** Debug / Protocolo.

**Contrato:** [Protocolo UART](../protocol.md). El contenido e interpretación de las observaciones se definen en [Arquitectura de Debug](../architecture/debug/debug_architecture.md); su transmisión, en [Response Serializer](../architecture/debug/response_serializer.md).

**Contexto:** PC y FPGA requieren una representación única para carga, ejecución, pasos, disponibilidad, reset y Debug, con fronteras de mensaje y fases de admisión explícitas.

**Decisión:** Las operaciones son LOAD (`0x01`), RUN (`0x02`), STEP (`0x03`), RESET (`0x04`) y CHECK_READY (`0x05`). Toda respuesta comienza con el código de operación y un resultado de un byte. Los campos multibyte son little-endian y los tamaños y cantidades ocupan cinco bytes unsigned. La [tabla de resultados](../protocol.md#cabecera-común-de-respuesta) define doce códigos `0x01`–`0x0C`.

LOAD declara N bytes de imagen no vacía, contigua desde cero, múltiplo de cuatro y dentro de IMEM. La PC consulta disponibilidad y envía el contenido solo después de LOAD/ACCEPTED completo. FPGA valida cada LOAD independientemente de la consulta. La aceptación invalida la imagen cargada; preparación completa y commit publican la nueva imagen y permiten LOAD/DONE. Una cabecera rechazada o incompleta conserva la imagen; una carga aceptada que falla queda sin imagen ejecutable.

RUN devuelve ACCEPTED y luego FINISHED o FAULT con Debug. STEP elegible ejecuta exactamente un ciclo y devuelve DONE con Debug, sin aceptación separada. El ciclo observado incluye stall, drain y commits según la autoridad de ejecución. RUN y STEP desde terminal preparan una sesión sobre la imagen cargada antes de ejecutar.

La PC mantiene una operación normal por vez y espera la respuesta completa. El intercambio RUN permanece abierto hasta completar terminal y Debug, salvo RESET reconocido. Durante RUN efectivo se admite únicamente RESET después de ACCEPTED y sin preparación activa. Otro byte o error UART inicia recuperación RX sin respuesta; CPU y obligación terminal continúan. Durante aceptaciones, preparación, respuestas y exclusión Debug se descarta RX adicional.

RUN que termina antes de completar ACCEPTED retiene su observación y transmite primero la aceptación completa. RESET reconocido cancela la obligación terminal; un terminal ya observable tiene prioridad sobre un nuevo RESET UART. No se intercalan respuestas ni se guardan comandos para otra fase.

Debug utiliza lectura directa de estado retenido desde el instante observado hasta el último Stop. Su cuerpo contiene 19 bytes de contexto, 128 de RF, 76 de registros interetapa y cinco de cantidad, más cinco bytes por posición utilizada de DMEM: cuerpo `228 + 5*K`, respuesta `230 + 5*K`. Se transmiten los campos registrados incluso con `valid=0`; el lector interpreta su vigencia. La lista DMEM contiene direcciones únicas crecientes y valores actuales de bytes escritos por stores comprometidos de la sesión.

PC y FPGA seleccionan previamente el mismo perfil: REFERENCE por defecto o ALT_1000. Los códigos y layout son comunes; capacidades y ventanas dependen del perfil. No hay negociación de perfil, checksum, CRC, marcador final ni consulta adicional de Debug.

**Justificación:** La longitud por operación delimita los mensajes. Las fases de aceptación, transferencia, preparación y observación impiden ejecutar una imagen parcial o modificar el estado mientras se transmite Debug. Una operación normal por vez permite coordinar las respuestas con las continuaciones de cada fase.

**Consecuencias:** La aplicación PC debe respetar [admisión y orden de intercambios](../protocol.md#orden-de-los-intercambios), [ventanas de RESET](../protocol.md#aplicar-reset-global) y [recuperación](../protocol.md#esperas-y-recuperación-desde-pc). La Global FSM tiene 14 estados y mantiene su autoridad sobre elegibilidad y ciclos CPU. La implementación y las pruebas de integración están pendientes.

**Requisitos afectados:** `REQ-MEM-003`, `REQ-MEM-008`, `REQ-MEM-010` a `REQ-MEM-012`, `REQ-MEM-015` a `REQ-MEM-019`, `REQ-MEM-021` a `REQ-MEM-024`, `REQ-MEM-027`, `REQ-MEM-029`, `REQ-MEM-030`, `REQ-EXEC-016` a `REQ-EXEC-018`, `REQ-UART-002` a `REQ-UART-011`, `REQ-DBG-001` a `REQ-DBG-017`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.
