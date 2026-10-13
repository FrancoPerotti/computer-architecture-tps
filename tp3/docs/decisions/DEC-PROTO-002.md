### DEC-PROTO-002 — Comandos adicionales

**Contrato vigente de consulta:** [protocol](../protocol.md), [execution_control](../architecture/session/execution_control.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Debug / Servicios de control y observación

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se completa la selección y secuencia de servicios auxiliares de `LOAD`/`RUN`/`STEP`, incluidos `reset` global desde PC, disponibilidad y obtención de Debug.

**Opciones consideradas:**

- Reset solo físico o también UART.
- Disponibilidad espontánea o consultada.
- Debug explícito adicional o automático.
- Servicios de pausa/aborto/reintento/capacidades.

Se seleccionan `reset` UART más botón, consulta `CHECK_READY` y Debug automático, sin otros comandos.

**Decisión:** La lista final consta de `LOAD` 0x01, `RUN` 0x02, `STEP` 0x03, `RESET` 0x04 y `CHECK_READY` 0x05. `RESET` solicita el mismo `reset` global del botón: responde `04 01` (`ACCEPTED`) y genera `reset` al terminar físicamente el segundo byte incluido Stop. El botón lo solicita directamente y puede abortar una transmisión; no genera aceptación UART ni mensaje espontáneo de arranque.

`CHECK_READY` se solicita con `05` y responde `05 03` (`READY`) o `05 04` (`BUSY`). Expresa disponibilidad para `LOAD`, sin reserva ni garantía de imagen válida. PC consulta antes de `LOAD`; FPGA valida `LOAD` por condiciones actuales sin exigir recordar consulta previa. Después de `reset` o recuperación se reutiliza el mismo servicio.

Debug se envía automáticamente con cada `STEP` realizado y final `RUN`; no existe una solicitud adicional de snapshot ni captura durante ejecución continua. Una operación normal por vez, con `CHECK_READY`/`RESET` durante `RUN` efectivo; `RESET` reconocido abandona `RUN` previo. Cada respuesta se completa físicamente antes de otra. Durante contenido/tamaño `LOAD`, recuperación y envío exclusivo Debug se mantienen las reglas específicas; `RESET` UART se envía después de Debug y botón físico puede interrumpirlo. La PC retoma la comunicación tras un fallo con los plazos y ventana del [acuerdo de recuperación](DEC-PROTO-003.md#acuerdo-parcial-de-dec-proto-003--recuperación-de-pc-y-cabecera-final-de-run).

**Justificación:** Los servicios cubren carga, ejecución, observación, disponibilidad y recuperación de una sesión sin comandos redundantes. La aceptación antes del `reset` evita truncarla y el envío exclusivo conserva Debug coherente.

**Consecuencias:** Selección, formatos, códigos, exclusión y reacción ante fallos cerrados; puertos y FSM privadas se concretan en DEC-SYS-007/diseño de bloques. Perfil compartido y revisión/consolidación del protocolo permanecen en C07/V01–V03/DEC-PROTO-001. Esta aprobación no cierra todo D0 ni acredita implementación.

**Requisitos afectados:** `REQ-EXEC-012`, `REQ-EXEC-015`, `REQ-EXEC-018`, `REQ-MEM-019`, `REQ-MEM-028`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de `reset`, consulta, servicios Debug, lista final, códigos, intercambios y recuperación PC.

---

### Acuerdo parcial de DEC-PROTO-002 — Reset global desde PC y botón físico

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-002` permanece pendiente en sus aspectos restantes.

**Dominio:** Sistema / Debug / Protocolo de control.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** El sistema requiere `reset` global desde la aplicación PC y desde el botón de la placa. Esta capacidad es independiente de la recuperación de una carga incompleta.

**Opciones consideradas:** utilizar únicamente el `reset` físico; ofrecer además una solicitud de `reset` global mediante UART desde la PC.

**Decisión:** El protocolo ofrecerá una operación de `reset` global solicitada desde la PC mediante UART. El botón físico de la placa seguirá siendo otra fuente de solicitud del mismo `reset` global. Ambas vías producirán los efectos lógicos y la prioridad ya aprobados en `DEC-ARCH-008`, sin cambiar la semántica de `reset` ni la preparación posterior de sesión.

La operación UART, una vez recibida y reconocida válidamente, solicitará `reset` global también durante ejecución continua, sin esperar `halt`. El sistema quedará seguro, detenido y sin imagen ejecutable válida; una nueva ejecución requerirá una carga válida posterior. El `reset` del sistema no implica volver a sintetizar ni reconfigurar el bitstream de la FPGA.

**Justificación:** El control desde PC permite solicitar `reset` sin intervención sobre el botón, mientras la vía física mantiene disponible la recuperación externa cuando el enlace no está operativo.

**Consecuencias y alcance pendiente:** Se agrega `reset` global al conjunto de servicios UART. Quedan abiertos su codificación, respuestas, confirmación de disponibilidad posterior, tratamiento de bytes pendientes y reconocimiento durante carga o recuperación del transporte. Un byte de contenido de `LOAD` no podrá confundirse con este comando. La generación, duración y distribución concreta de la solicitud UART y del botón se definirán en integración, respetando el dominio común y el acondicionamiento aprobado. No se selecciona GUI, un comando UART de `reset` de recepción, un reintento automático ni el `reset` global como recuperación obligatoria de `LOAD` fallido.

**Requisitos afectados:** `REQ-UART-006`, `REQ-EXEC-015`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-012`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la exposición UART de `reset` global prevista como pendiente en `DEC-ARCH-008` y `DEC-PROTO-002`; conserva el `reset` físico y no cierra `DEC-PROTO-002`.

### Acuerdo parcial de DEC-PROTO-002 — Consulta de disponibilidad iniciada por PC

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-002` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de control y disponibilidad.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La PC puede conectarse cuando la FPGA ya está encendida; un aviso único durante el arranque no garantiza su recepción. Se requiere una consulta iniciada por PC.

**Opciones consideradas:** depender de un aviso espontáneo de la FPGA; consultar desde la PC y obtener una respuesta de disponibilidad.

**Decisión:** El protocolo ofrecerá una consulta de disponibilidad iniciada por la PC. Cuando el receptor pueda interpretar válidamente la consulta, la FPGA responderá si está disponible para recibir una solicitud `LOAD`, conforme al significado aprobado en `DEC-PROTO-001`. La consulta será informativa y repetible; no iniciará `LOAD`, no reseteará el sistema ni modificará la imagen o el estado arquitectónico de la CPU.

La PC podrá obtener así la disponibilidad al conectar, después de un `reset` y antes de reintentar una carga fallida, sin depender de haber escuchado una emisión durante el arranque. Se mantienen las respuestas ya aprobadas de aceptación, éxito y fallo de `LOAD`. La consulta no sustituye la solicitud con tamaño ni su aceptación.

**Justificación:** El intercambio iniciado por la PC permite obtener la información cuando la aplicación está escuchando y reutiliza la misma operación en conexión inicial, `reset` y recuperación.

**Consecuencias y alcance pendiente:** Quedan abiertos la codificación, respuestas, timeout de consulta, repetición ante falta de respuesta y tratamiento durante `LOAD` o resincronización. Un byte del programa no podrá interpretarse como consulta. El acuerdo siguiente fija la secuencia que debe seguir la PC y mantiene la validación de cada `LOAD` por la FPGA sin exigir memoria de una consulta anterior.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-002`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el mecanismo de obtención de disponibilidad por consulta de PC, sin cerrar `DEC-PROTO-002` ni las reglas restantes de secuencia.

### Acuerdo parcial de DEC-PROTO-002 — Intercambio RESET con aceptación antes del reset global

**Estado del acuerdo:** Aprobado como base de diseño. Se completa Z02; `DEC-PROTO-002` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Reset desde PC, confirmación y retorno al enlace.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El `reset` global reinicia UART y buffers. `ACCEPTED` debe transmitirse completo antes del `reset`; la consulta de disponibilidad permite retomar después el protocolo.

**Decisión:** `RESET` se solicita con exactamente un byte `[RESET]`, sin parámetros. Cuando se interpreta como comando válido, la FPGA responde exactamente dos bytes `[RESET][ACEPTADA]`, sin datos adicionales. Los valores numéricos permanecen pendientes en C02/C03.

La secuencia es:

1. PC envía `RESET`.
2. FPGA transmite la aceptación completa.
3. Al finalizar físicamente el segundo byte, incluido su Stop, genera la solicitud de `reset` global; encolar los bytes o retirarlos de FIFO no acredita ese final.
4. El `reset` aplica los mismos efectos arquitectónicos que el botón físico: sistema detenido en `NO_IMAGE`, sin imagen válida ni sesión anterior activa, con estado inicial de CPU y UART reiniciada según sus contratos.
5. PC abandona la espera del resultado de la ejecución anterior y consulta disponibilidad. Solo al recibir DISPONIBLE continúa con una nueva `LOAD` y su secuencia normal.

ACEPTADA confirma que se tomó la orden y precede a la aplicación efectiva del `reset`. La consulta posterior confirma que el receptor está disponible para `LOAD`; no agrega un mensaje espontáneo de arranque ni una segunda confirmación `RESET`. La ausencia de imagen tras este intercambio se deriva de los efectos del `reset`, no de un significado nuevo para DISPONIBLE.

Se distingue el reconocimiento de la orden UART de la generación de la solicitud global de `reset`: esta última se difiere hasta el final físico de la aceptación. Una vez generada, se conserva el acondicionamiento temporal y la prioridad global aprobados. No se agrega una pausa anticipada de la CPU ni un estado global nuevo para esperar la UART; la realización de este orden corresponde al diseño de protocolo/plataforma.

El botón físico aplica el `reset` directamente, sin esperar transmisión ni enviar una aceptación UART. Al retomar la comunicación después de un `reset` físico, PC abandona el intercambio anterior y vuelve a consultar disponibilidad. Este contrato no exige una notificación espontánea ni fija un mecanismo de detección automática del botón desde PC.

Se conservan las exclusiones de comandos durante contenido `LOAD`, preparación/confirmación de carga y recuperación por silencio. Reset y solicitudes mientras un snapshot está transmitiéndose se completarán en D06, junto con el arbitraje y las reglas de serialización; este acuerdo no presupone intercalar la aceptación de `reset` dentro de otro mensaje.

**Justificación:** Terminar la respuesta antes de reiniciar UART evita perder la aceptación o truncar su trama. La consulta posterior utiliza el mismo mecanismo de disponibilidad ya acordado para primera carga y recuperación, manteniendo un intercambio sencillo para el TP.

**Consecuencias y alcance pendiente:** Se completa Z02 y se continúa con D02. Formato, orden de confirmación/`reset`, abandono del intercambio previo y retorno a consulta quedan definidos. Siguen pendientes los tiempos y fallas de PC en C06, códigos numéricos, realización de generación/`reset` y fin físico TX, y la interacción durante snapshot en D06/C04. El efecto del `reset` y los estados de la FSM global permanecen sin cambios. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-006`, `REQ-UART-007`, `REQ-EXEC-015`, `REQ-DBG-001`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa el intercambio pendiente del `reset` global desde PC y su diferencia temporal con el botón, conservando los efectos arquitectónicos, el servicio de disponibilidad y las exclusiones `LOAD`/recuperación.

### Acuerdo parcial de DEC-PROTO-002 — Debug automático sin consultas adicionales

**Estado del acuerdo:** Aprobado como base de diseño. Se completa D02; `DEC-PROTO-002` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Servicios de observación y momentos de captura.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** `RUN` entrega Debug al terminar y `STEP` después de cada ciclo. PC conserva el snapshot recibido; entre pasos sin operaciones de sesión el estado permanece retenido y no requiere otra solicitud de retransmisión.

**Decisión:** El protocolo del TP obtiene Debug exclusivamente en los intercambios automáticos aprobados:

- Después de cada `STEP` realizado, en `[STEP][COMPLETADO][estado de Debug]`, incluidos confirmación de halt/fault y ciclos de drenado.
- Al finalizar `RUN`, después del drenado necesario, en `[RUN][FINALIZADA][estado de Debug]` o `[RUN][FAULT][estado de Debug]`.

No se agrega `READ_STATE` ni otra solicitud explícita de snapshot. No se ofrecen capturas mientras `RUNNING` o un drain AUTO continúan ejecutándose, ni capturas adicionales en `READY`, `NO_IMAGE`, carga, preparación o `reset`. Los estados del snapshot `STEP` son los posteriores a su ciclo efectivo; los de `RUN` son `FINISHED`/`FAULT` según R02. Se conserva la observación de fault pendiente/terminal en los pasos ya definidos.

La PC puede guardar y volver a mostrar el snapshot recibido. Mientras la sesión espera entre pasos, sin un avance ni una nueva operación de sesión, permanecen retenidos PC, RF, pipeline, DMEM y contador; UART/Debug pueden transmitir sin modificar ese estado arquitectónico. No se exige mantener un historial ni se selecciona aquí una implementación del software.

`CONSULTAR_DISPONIBILIDAD` conserva su función de informar elegibilidad de `LOAD`, sin contenido Debug ni captura de snapshot. Un `reset` o una nueva carga cambian el contexto; un snapshot conservado pertenece a su sesión original y no se interpreta como estado actual de otra sesión.

**Justificación:** Los snapshots automáticos satisfacen los recorridos requeridos por la consigna. Repetir el estado retenido entre pasos no aporta una observación nueva, y conservar la respuesta en PC permite reutilizarla sin otro intercambio UART.

**Consecuencias y alcance pendiente:** Se completa D02 y se continúa con D03. La lista final de comandos no incluirá una consulta Debug adicional. Siguen pendientes campos externos de registros interetapa, criterio de memoria utilizada, layout/longitud y realización de captura/envío en D03–D06, códigos/reglas comunes y demás decisiones de D0. Pausa/aborto u otros servicios no se agregan por este acuerdo. No se inicia implementación.

**Requisitos afectados:** `REQ-EXEC-007`, `REQ-EXEC-010`, `REQ-UART-005`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la necesidad de consultas adicionales y los momentos de captura pendientes en D02, conservando el contenido y la coherencia mínimos aprobados.

### Acuerdo parcial de DEC-PROTO-002 — Lista final y nombres de operaciones

**Estado del acuerdo:** Aprobado como base de diseño. C01 completo; asignación individual de códigos pendiente en C02.

**Dominio:** Debug / Servicios y nombres definitivos del protocolo.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se consolidan las cinco operaciones `LOAD`, `RUN`, `STEP`, `RESET` y `CHECK_READY`. Los nombres definitivos son en inglés; `CHECK_READY` sustituye la etiqueta provisional `CONSULTAR_DISPONIBILIDAD`.

**Decisión:** La lista final de solicitudes consta de cinco operaciones:

| Nombre definitivo | Servicio | Campos de solicitud ya aprobados |
|---|---|---|
| `LOAD` | Cargar el programa y preparar una sesión | Código de un byte y tamaño unsigned de cinco bytes little-endian; contenido de N bytes después de aceptación |
| `RUN` | Ejecución continua y resultado final con Debug | Código de un byte, sin parámetros |
| `STEP` | Un ciclo efectivo y respuesta con Debug | Código de un byte, sin parámetros |
| `RESET` | Reset global solicitado por PC, con aceptación antes de aplicarlo | Código de un byte, sin parámetros |
| `CHECK_READY` | Consultar disponibilidad para recibir `LOAD` | Código de un byte, sin parámetros |

`CHECK_READY` es la misma consulta informativa aprobada: devuelve `[CHECK_READY][DISPONIBLE / NO_DISPONIBLE]`, dos bytes, sin datos ni reserva de una carga. La PC consulta antes de `LOAD`; la FPGA valida `LOAD` por sus condiciones actuales y no exige recordar una consulta previa. Disponible no implica imagen ejecutable válida. Se conservan elegibilidad, tiempos, exclusión y descarte durante recuperación/envío Debug previamente aprobados.

Los nombres son etiquetas de diseño compartidas por PC y FPGA. En el enlace se transmiten códigos binarios de un byte, nunca las cadenas ASCII de los nombres. La numeración sigue siendo consecutiva desde 0x01; no se asigna un número concreto por operación en este acuerdo.

Debug se entrega automáticamente en las respuestas de `STEP` y final `RUN`. Reintentar consiste en otra `LOAD` completa solicitada por el usuario. La lista no incorpora solicitudes adicionales de snapshot, reintento, pausa/aborto ni negociación/reporte de capacidades.

**Justificación:** La lista consolida los servicios ya aprobados y permite asignar códigos sobre un conjunto definitivo. `CHECK_READY` conserva el significado específico de disponibilidad para `LOAD` y mantiene los nombres del protocolo en inglés.

**Consecuencias y alcance pendiente:** Se cierra C01 y la selección de servicios de DEC-SYS-007/DEC-PROTO-002. Estos identificadores siguen abiertos por realización de bloques y códigos/integración respectivamente.

| Acuerdo | Alcance previsto |
|---|---|
| C02 | Asignará códigos |
| C03 | Definirá resultados/estados |
| C04 | Reunirá elegibilidad y reglas de intercambios |
| C05/C06 | Definirán errores y plazos |
| C07 | Definirá el perfil compartido |

No se modifica la semántica de las operaciones ni se inicia implementación.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida las operaciones aprobadas y sustituye `CONSULTAR_DISPONIBILIDAD` como nombre provisional por `CHECK_READY`; conserva los formatos y comportamientos definidos en acuerdos anteriores.
