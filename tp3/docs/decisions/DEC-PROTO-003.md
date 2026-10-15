### DEC-PROTO-003 — Timeouts y recuperación

**Contrato vigente de consulta:** [protocol](../protocol.md), [protocol_controller](../architecture/debug/protocol_controller.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Debug / Tiempos FPGA–PC y recuperación del enlace

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se completan los tiempos de recepción `LOAD`, recuperación RX, espera de respuestas PC y reacción ante comunicación incompleta, usando UART 19200 baud, 8N1 y clock funcional de 50 MHz.

**Opciones consideradas:** Timeout total de programa o inactividad por byte; recuperación por `reset` global o descarte/silencio; reenvío automático o reintento manual. Se seleccionan inactividad `LOAD`, recuperación RX por silencio y reintento manual; tiempos PC se calculan por mensaje/fase.

**Decisión:** FPGA usa T=100 ms (5.000.000 clocks) de inactividad para tamaño/contenido `LOAD`. El tamaño comienza tras `opcode`; el contenido después del fin físico de aceptación. Prioridad error UART, byte válido y vencimiento sin ambos. Recepción incompleta antes de aceptar conserva imagen; fallo posterior la deja inválida. RX se recupera por descarte y R=100 ms de silencio continuo, reiniciado por actividad, con línea en reposo, sin byte en curso y FIFO vacía. TX se conserva. Error UART en código fuera de `LOAD` usa ese R sin respuesta ni efecto CPU/imagen.

PC prepara el programa completo, envía exacto/seguido después de aceptación, escucha respuestas y detiene/cancela al fallar. Ventana `LOAD` W: tiempo nominal de N+6 bytes más T+R, redondeado arriba a múltiplos de 100 ms; W=800 ms para N=1024. Consulta tras W y repite W si falta respuesta; reintento manual con una nueva `LOAD` completa.

| Espera PC | Plazo aprobado |
|---|---|
| `CHECK_READY`, aceptación `LOAD` o `RUN` | 200 ms desde inicio de solicitud |
| Final `LOAD` | N*10*1000/19200 +201 ms desde inicio del contenido, `REFERENCE`/`ALT_1000` |
| Aceptación `RESET` | 200 ms desde solicitud |
| Cabecera `STEP` completa | 200 ms desde solicitud |
| Terminación `RUN` antes de primer byte terminal | Sin timeout de duración |
| Completar cabecera final `RUN` ya comenzada | 200 ms desde su primer byte |
| Parte fija Debug de 228 bytes | 319 ms desde cabecera completa |
| Lista Debug, K>0 | ceil(5*K*10*1000/19200 +200) ms desde `used_count` |
| K=0 | Respuesta completa al terminar parte fija; sin otra espera |

`LOAD` dispone de presupuesto de preparación máximo 1 ms, incluido commit en `READY`, para `REFERENCE`/`ALT_1000`; no es una espera fija y futuros perfiles revisan esa cota. Los demás plazos se explican en el [acuerdo de recepción Debug](#acuerdo-parcial-de-dec-proto-003--plazos-de-reset-step-y-recepción-de-debug).

Ante timeout/desconexión/truncamiento PC informa fallo, descarta parcial, conserva observación anterior y detiene la secuencia sin repetir automáticamente `STEP`/`RUN`/`RESET` ni inferir rollback. Fuera del flujo `LOAD`, `W_debug`(C)=100*ceil((200+319+ceil(5*C*10*1000/19200+200))/100) ms; vale 6100 para `REFERENCE` y 3400 para `ALT_1000`. PC lee y descarta RX hasta completar ese intervalo de silencio continuo, reiniciado con cada recepción. Envía `CHECK_READY` sin limpiar RX y valida únicamente sus dos bytes iniciales `05 03`/`05 04` dentro de 200 ms; otro comienzo, resultado inválido o timeout vuelve al descarte sin buscar pares dentro del payload. Los bytes posteriores a una consulta válida se conservan. La consulta recupera comunicación; para sesión conocida, el usuario puede `RESET` y `LOAD`. Véase el [acuerdo de recuperación](#acuerdo-parcial-de-dec-proto-003--recuperación-de-pc-y-cabecera-final-de-run).

**Justificación:** Inactividad permite distintos tamaños sin castigar programas largos. Los presupuestos por fase distinguen transmisión y ejecución; el silencio continuo por perfil permite drenar una respuesta iniciada incluso si K se perdió. La lectura sin limpieza al consultar conserva el comienzo de un terminal RUN tardío y evita validar pares de su cuerpo como disponibilidad. Repetir solo consultas y reintentar operaciones manualmente evita duplicar avances o resets.

**Consecuencias:** C06 y las elecciones de tiempos/recuperación quedan cerrados. Puertos UART, contadores, reconocimiento de actividad/en curso/fin físico y FSM privadas se concretan en DEC-SYS-007/diseño de bloques. C07/V01–V03 completan perfil y documento definitivo bajo DEC-PROTO-001. Los valores son contratos de diseño para la implementación futura, sin pruebas RTL ni mediciones de hardware en esta etapa.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-DBG-013`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de T/R, ventanas y envío `LOAD`, plazos PC, preparación `LOAD`, errores RX y recuperación de PC, conservando sus contextos y efectos.

---

### Acuerdo parcial de DEC-PROTO-003 — Timeout de recepción para LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y recuperación.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** Una carga aceptada puede dejar de recibir datos antes de alcanzar el tamaño declarado. La FPGA debe detectar esa interrupción. Como antecedente, el controlador de ALU del TP2 aplica `TRANSACTION_TIMEOUT_MS`, con valor predeterminado de 10 ms, mientras espera B o el `opcode` después de recibir parte de la transacción; recibir el siguiente byte reinicia la espera. Véase [alu_uart_controller.sv](../../../tp2/rtl/alu_uart_controller.sv).

**Opciones consideradas:** permanecer esperando indefinidamente el contenido faltante; detectar la inactividad mediante un timeout de recepción en la FPGA.

**Decisión:** `LOAD` tendrá un timeout de recepción en la FPGA mientras esté pendiente contenido del programa. Si se supera el intervalo permitido sin recibir un nuevo byte del contenido de la carga, se declarará fallida la carga. Cada nuevo byte aceptado como contenido reiniciará el intervalo de inactividad mientras falten bytes. El timeout medirá inactividad de recepción, no la duración total de transferencia de una imagen.

Una carga fallida por timeout no publicará una imagen ejecutable ni emitirá la confirmación final de éxito. Se conserva la invalidación que ocurre al aceptar `LOAD`; no se restaura el programa anterior. Este timeout es un error de comunicación de `LOAD` y no un fault arquitectónico de una instrucción.

**Justificación:** La detección de una transferencia interrumpida evita que una carga incompleta permanezca esperando indefinidamente. Reutiliza el criterio de inactividad del TP2 sin depender del tamaño total del programa.

**Consecuencias y alcance pendiente:** El acuerdo siguiente de `DEC-PROTO-001` fija la existencia de una respuesta de fallo por recepción incompleta. Quedan pendientes el valor temporal, el instante inicial de activación alrededor de la aceptación y la espera del primer byte, la prioridad de coincidencias, la codificación de esa respuesta y la recuperación/resincronización, incluidos bytes tardíos y pendientes en FIFO. Los 10 ms del TP2 constituyen un antecedente, no un valor aprobado para TP3. No se adopta automáticamente el retorno a esperar una nueva transacción del controlador TP2; el transporte debe resolver la realineación antes de interpretar bytes residuales como comandos nuevos. Los timeouts de la PC, comandos incompletos y otras operaciones continúan pendientes. No se introduce un nuevo estado global ni se fija el contador o la FSM privada.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia de timeout de recepción para `LOAD` de los acuerdos anteriores, sin cerrar `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Recuperación automática y reintento solicitado por el usuario

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y recuperación.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** Se deben separar la recuperación de la recepción después de una carga fallida y la decisión de reenviar el programa. El `reset` global solicitado por UART o botón constituye una operación independiente ya aprobada.

**Opciones consideradas:** requerir una intervención del usuario para recuperar la recepción; recuperar automáticamente la recepción y dejar el reenvío a elección del usuario; recuperar y reenviar automáticamente.

**Decisión:** Después de declarar fallida una carga, se recuperará automáticamente el estado de recepción y se resincronizará el enlace hasta dejarlo preparado para otra solicitud. Esta recuperación específica de `LOAD` no requerirá que el usuario solicite `reset` global ni presione el botón físico. Se descartará la recepción parcial y se resolverán los bytes pendientes del intento anterior antes de interpretar comandos nuevos.

El reenvío del programa será solicitado por el usuario desde la PC. La acción de reintentar se traducirá en una nueva operación `LOAD` completa: solicitud con tamaño, espera de aceptación, transferencia de todas las instrucciones desde el comienzo y confirmación final tras validación y preparación. No se reanudará desde el byte donde se interrumpió la carga ni se reenviará automáticamente. No se incorpora un comando adicional RETRY ni se selecciona el formato de interfaz de PC.

Durante la recuperación la imagen seguirá inválida y no se habilitarán `RUN` ni `STEP`. La PC y la FPGA deberán coordinar el cese del envío anterior y la eliminación o delimitación de sus datos pendientes antes de iniciar la nueva `LOAD`. La respuesta de fallo ya aprobada no acredita por sí sola que esa recuperación haya terminado.

**Justificación:** La recuperación automática evita exigir una intervención para liberar la recepción, mientras el reintento solicitado por el usuario mantiene explícita la decisión de repetir la carga y permite inspeccionar un fallo antes de reenviar.

**Consecuencias y alcance pendiente:** Se fija la política de recuperación y reintento. El acuerdo siguiente de `DEC-PROTO-001` fija una indicación común de disponibilidad para `LOAD`. Quedan abiertos el mecanismo de resincronización, la codificación y obtención de esa indicación por la PC, el tratamiento de bytes tardíos, vaciado de buffers y delimitación, los tiempos, la pérdida de respuestas y el papel de un posible comando de resincronización. No basta con vaciar una FIFO una sola vez y aceptar inmediatamente nuevos comandos si aún pueden llegar datos del intento anterior. El `reset` global conserva su función independiente y sus vías UART y física.

**Requisitos afectados:** `REQ-UART-002`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la política de recuperación y reintento de `LOAD`, sin cerrar el mecanismo concreto ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Timeout de solicitud LOAD incompleta

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Recepción de solicitudes y recuperación.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Una solicitud `LOAD` comprende el código de operación y cinco bytes de tamaño. El envío puede interrumpirse después del código y antes de completar el tamaño, cuando la carga todavía no fue aceptada.

**Opciones consideradas:** esperar indefinidamente los bytes faltantes de tamaño; aplicar timeout a la solicitud parcial y descartarla.

**Decisión:** Después de reconocer el código `LOAD`, el receptor aplicará timeout de inactividad mientras falte alguno de los cinco bytes de tamaño. Cada byte aceptado como parte del tamaño reiniciará la espera mientras queden bytes pendientes. Si vence el timeout antes de completar el campo, se descartará la solicitud incompleta y su progreso privado.

Una solicitud descartada por este timeout no iniciará `LOAD`, no escribirá instrucciones ni invalidará la imagen vigente. Tampoco modificará por sí sola el estado de ejecución o el estado arquitectónico de la CPU; una ejecución ya activa podrá continuar según sus reglas ordinarias. Si no había imagen válida, el descarte no creará una. No se emitirá aceptación ni confirmación de carga exitosa para esa solicitud incompleta.

Este caso se distingue del timeout del contenido de una carga ya aceptada: solo la aceptación efectiva de `LOAD` invalida la imagen anterior, y una falla posterior deja al sistema sin imagen ejecutable. El timeout del tamaño no fuerza ese efecto ni exige `reset` global.

**Justificación:** El receptor puede abandonar una solicitud interrumpida sin quedar esperando indefinidamente ni producir efectos de una operación que todavía no fue aceptada.

**Consecuencias y alcance pendiente:** El acuerdo siguiente de `DEC-PROTO-001` fija una respuesta específica de solicitud `LOAD` incompleta y el acuerdo posterior de `DEC-PROTO-003` fija un valor temporal común con la recepción del contenido. Quedan pendientes la duración concreta, prioridad de coincidencias, codificación y entrega de la respuesta, bytes tardíos y mecanismo de resincronización. Descartar el tamaño parcial no basta para interpretar inmediatamente cualquier byte posterior como un comando nuevo. La respuesta de fallo de una carga aceptada conserva su significado separado. No se agrega un estado global ni se fija la FSM privada del receptor.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia y efecto del timeout de solicitud `LOAD` incompleta, sin cerrar su duración, respuesta o recuperación ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Tiempo de inactividad común para tamaño y contenido

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Temporización de recepción de `LOAD`.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se aprobaron timeouts de inactividad tanto para completar el tamaño de la solicitud como para recibir el contenido de una carga aceptada. Ambas esperas detectan ausencia del próximo byte.

**Opciones consideradas:** duraciones independientes según la fase; utilizar una duración común para ambas esperas.

**Decisión:** Se utilizará un único valor temporal de timeout de inactividad para la recepción de los cinco bytes del tamaño y para la recepción del contenido de `LOAD`. El símbolo `T` identifica ese valor común sin fijar nombre de parámetro RTL, unidades de codificación ni duración numérica. Cada byte aceptado de la fase correspondiente reiniciará la espera mientras falten bytes.

El valor común no modifica las consecuencias específicas de cada fase: si vence mientras se recibe el tamaño, se descarta la solicitud, se informa solicitud `LOAD` incompleta y se conserva la imagen vigente; si vence durante el contenido de una `LOAD` ya aceptada, se informa carga fallida y se mantiene la imagen inválida. No se aplica un límite `T` a la duración total de transferencia del programa.

**Justificación:** Se detecta la misma condición de inactividad mediante un criterio temporal único, manteniendo separados los efectos de la solicitud parcial y de la carga aceptada.

**Consecuencias y alcance pendiente:** Quedan pendientes el valor numérico, conversión al clock funcional, activación inicial de la espera del contenido alrededor de la aceptación y el primer byte, prioridad de coincidencias, respuestas y recuperación. Compartir duración no exige un contador físico único ni una FSM específica. No se extiende automáticamente el mismo valor a timeouts de PC, consulta, transmisión o resincronización. Los 10 ms del TP2 siguen siendo un antecedente, sin aprobarse como duración de TP3.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el uso de un valor temporal común para las dos fases de recepción de `LOAD`, sin cerrar su duración ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Recuperación por descarte y silencio del enlace

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Recuperación de recepción y coordinación con PC.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Después de abandonar una recepción incompleta pueden llegar bytes del intento anterior. Interpretarlos como comandos nuevos perdería la alineación; se requiere una recuperación coordinada de FPGA y PC.

**Opciones consideradas:** volver inmediatamente a interpretar comandos después de limpiar la recepción parcial; descartar los datos pendientes y esperar silencio del enlace, coordinado con el cese del envío desde PC.

**Decisión:** Para recuperar los timeouts de tamaño y contenido de `LOAD` se aplicará el siguiente contrato:

1. **Limpieza inicial:** Se descartarán la solicitud o instrucción parcial y los bytes pendientes en la FIFO RX. Se conservará la vía TX para enviar la respuesta de error correspondiente. La limpieza de recepción no producirá `reset` global: antes de aceptar `LOAD` se conserva la imagen vigente y la ejecución puede continuar; después de aceptar `LOAD` la imagen permanece inválida.
2. **Descarte durante recuperación:** Se consumirán y descartarán todos los bytes que lleguen, incluidos aquellos cuyo valor coincida con una consulta, `LOAD` o `reset` UART. No se interpretarán comandos ni se anunciará disponibilidad durante esta fase. No se fija un estado adicional de la FSM global ni la implementación de la FSM privada de recepción.
3. **Cese del intento desde PC:** Al recibir el error, la PC dejará de transmitir el intento anterior y cancelará el envío pendiente en lo que permita el transporte. Aplicará también este procedimiento si vence su propia espera de respuesta. Los bytes ya en tránsito o que no puedan cancelarse quedarán cubiertos por el contrato temporal de recuperación.
4. **Silencio efectivo:** La espera de recuperación comenzará al entrar en esa fase y se reiniciará ante cualquier actividad de recepción. Solo finalizará después de un intervalo completo de silencio, con la línea en reposo, ningún byte en curso y la FIFO RX vacía. Vaciar la FIFO una sola vez no basta.
5. **Intervalo independiente:** El símbolo `R` identifica la duración de silencio, todavía sin valor numérico. Es independiente del timeout de recepción `T`. Su elección se justificará con la reacción y cancelación desde PC y el tiempo máximo de llegada de los bytes pendientes, incluidos los buffers del transporte.
6. **Retorno al flujo de PC:** Después de detener/cancelar el intento, la PC esperará una ventana acordada antes de consultar disponibilidad. Esa ventana deberá cubrir los datos pendientes, el timeout de recepción que aún pudiera estar activo si se perdió una respuesta y la recuperación por silencio. Si la consulta no recibe respuesta, la PC esperará nuevamente antes de repetirla; no enviará consultas continuamente que impidan completar el silencio. Una respuesta disponible habilita el flujo ya aprobado de nueva `LOAD` completa, solicitada por el usuario.

La recuperación depende de que la PC abandone el envío anterior y de un límite explícito para la llegada de sus bytes pendientes. El silencio por sí solo no garantiza alineación frente a datos arbitrariamente tardíos. Esos límites, `R` y las ventanas de PC deberán quedar justificados y cerrados antes del gate D0; no se aprueba una duración por defecto.

**Justificación:** El descarte elimina los restos de la operación abandonada y el silencio permite retornar a un límite entre solicitudes bajo el contrato temporal acordado, sin exigir `reset` global ni agregar un comando RETRY.

**Consecuencias y alcance pendiente:** Queda fijado el mecanismo de recuperación para los timeouts de `LOAD` y el tratamiento de consultas y `reset` UART durante esa recuperación. Quedan pendientes los valores y conversiones temporales, los límites del transporte, el dimensionado de buffers, las señales que permitan observar actividad y recepción en curso, las prioridades en coincidencias y la codificación/entrega de respuestas ante TX ocupado o pérdida. La política para otros errores UART, códigos desconocidos y datos excedentes se definirá aparte; no se extiende automáticamente este mecanismo a todos ellos. No se congela una lista nueva de puertos ni se acredita aún la viabilidad temporal.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el mecanismo pendiente de recuperación de los timeouts de `LOAD` y sus seis reglas de coordinación, conservando las políticas previas de imagen, respuestas y reintento. No cierra su temporización ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Inicio del timeout de contenido tras transmitir aceptación

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Transición entre aceptación de `LOAD` y recepción del programa.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La PC debe recibir `ACCEPTED` antes de enviar contenido. El timeout de contenido comienza al terminar físicamente esa respuesta para no consumir tiempo de recepción durante su envío.

**Decisión:** Una vez recibida y validada la solicitud, la FPGA acepta `LOAD`, inicia la carga con sus efectos ya aprobados y transmite `[LOAD][ACEPTADA]`. El timeout de inactividad del contenido comenzará al terminar físicamente la transmisión del segundo byte de esa respuesta, incluido su bit de Stop.

Introducir la respuesta en la FIFO TX no constituye fin de transmisión ni inicia todavía esa espera. La aceptación efectiva de `LOAD` y la invalidación de la imagen anterior siguen ocurriendo al aceptar la solicitud, sin diferirse hasta el fin de TX.

La PC esperará la respuesta completa antes de enviar el programa. Se utilizará el mismo tiempo `T` para esperar el primer byte y los siguientes; cada byte de contenido recibido correctamente reiniciará la espera mientras falten bytes. No se incorpora un timeout separado para el primer byte ni un límite a la duración total de la transferencia.

El valor de `T` deberá cubrir la reacción normal de PC después de recibir la aceptación y el tiempo de recepción del primer byte. Su duración numérica sigue pendiente junto con los parámetros UART y del transporte.

**Justificación:** La autorización debe salir por el enlace antes de contar el tiempo disponible para que la PC reaccione y comience a transmitir. Se conserva un criterio común de inactividad para la recepción.

**Consecuencias y alcance pendiente:** Se resuelve L15 de la checklist. Quedan pendientes el valor y conversión de `T`, las prioridades si coinciden byte/error/vencimiento y el contrato concreto que permita identificar el fin físico de la respuesta desde la capa UART. No se fijan puertos ni contadores nuevos. El envío ante TX lleno se completará en U02 y la espera de aceptación en PC en L18.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-009`, `REQ-UART-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la activación inicial del timeout de contenido pendiente en los acuerdos previos de recepción de `LOAD` y tiempo común, sin cerrar su duración ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Envío preparado y supervisado desde PC

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Contrato del transporte de PC para `LOAD`.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El envío desde PC debe preparar el programa antes de cargar y permitir detener el intento ante fallo. No se seleccionan interfaz gráfica, lenguaje ni biblioteca de transporte.

**Decisión:** Se utilizará el siguiente contrato:

1. **Preparación previa:** La PC tendrá el programa completo preparado como bytes y conocerá su tamaño antes de solicitar `LOAD`. No ensamblará ni leerá archivos durante la transferencia.
2. **Inicio y continuidad:** Después de recibir la aceptación completa, comenzará automáticamente a enviar exactamente el contenido anunciado, seguido y sin pausas intencionales. Las fragmentaciones internas del sistema operativo o adaptador no constituyen bloques nuevos del protocolo ni requieren confirmaciones.
3. **Supervisión durante envío:** La PC escuchará respuestas mientras transmite. Si recibe un error o vence su espera, detendrá nuevos envíos y cancelará lo pendiente en lo que permita el transporte.
4. **Recuperación coordinada:** Los bytes ya en tránsito podrán terminar de llegar mientras la FPGA los descarta. La PC respetará la ventana acordada antes de consultar disponibilidad y mantendrá el reintento completo a elección del usuario.

Las pausas normales del sistema operativo y del adaptador quedarán cubiertas por el margen de `T`. La espera del primer byte contemplará la reacción del transporte y su recepción UART, sin incluir preparación del programa ni interacción adicional del usuario.

**Justificación:** Tener el contenido preparado permite iniciar el envío al recibir la autorización y sostenerlo. Supervisar simultáneamente las respuestas permite reaccionar al fallo sin esperar a completar deliberadamente un intento abandonado.

**Consecuencias y alcance pendiente:** Se resuelve U03 de la checklist como contrato de uso del cliente propio del TP. Quedan pendientes los tiempos `T`, `R`, ventanas y esperas de PC en L16–L18, con margen para el transporte de laboratorio. No se garantiza cancelación instantánea de bytes ya en tránsito ni se exige robustez frente a latencias arbitrarias. No se fija una única llamada al sistema, un mecanismo de concurrencia ni una implementación de la aplicación.

**Requisitos afectados:** `REQ-UART-009`, `REQ-UART-010`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la preparación, continuidad, supervisión y cese del envío desde PC pendientes en los acuerdos de carga seguida y recuperación, sin cerrar su temporización ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Duración y prioridades del timeout de LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Temporización de recepción de `LOAD`.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Con la configuración UART y los contratos de consumo/envío definidos, corresponde concretar el timeout T y la prioridad entre error, byte válido y vencimiento.

**Decisión:** El timeout común de inactividad de tamaño y contenido de `LOAD` será **T = 100 ms**. Con el clock funcional de 50 MHz corresponde a **5.000.000 de ciclos físicos de clock**, independientes de `cpu_cycle_fire` y del contador lógico de la sesión. Un contador que represente ese intervalo requiere al menos 23 bits; esta derivación no fija la FSM ni obliga a compartir un contador físico entre fases.

Se mantienen los puntos de activación aprobados: espera del tamaño después de reconocer el código `LOAD` y espera del contenido después de terminar físicamente el segundo byte de aceptación, incluido Stop. Cada byte válido aceptado reinicia la espera mientras falten bytes; recibir el último completa su fase. T no limita la duración total de la transferencia.

Si coinciden eventos en un mismo flanco funcional, se aplicará esta prioridad:

1. **Error UART:** abandonar la recepción y aplicar la recuperación acordada, sin aceptar un byte coincidente como válido para continuar la operación.
2. **Byte válido recibido:** consumirlo y reiniciar T si faltan bytes, o completar la fase si es el último. Un byte válido en el límite evita el timeout.
3. **Vencimiento sin error ni byte válido:** declarar solicitud o contenido incompleto según la fase, con los efectos de imagen y respuestas ya aprobados.

**Justificación:** La trama nominal tarda aproximadamente 0,520833 ms, y el programa está preparado antes de `LOAD`, con inicio automático y envío sin pausas intencionales. Los 100 ms son un margen de diseño para la reacción de PC y las pausas normales del transporte, manteniendo una detección de interrupción rápida para el uso del TP. No constituyen una medición de latencia de PC ni un valor determinado únicamente por baud rate.

**Consecuencias y alcance pendiente:** Se resuelve L16. La propuesta inicial de 100 ms había quedado diferida; este acuerdo la selecciona después de concretar U01–U03 y L15. Quedan pendientes R, las ventanas de recuperación/consulta y las esperas de PC en L17/L18. La realización de UART/protocolo deberá cumplir la cuenta y prioridades, sin introducir un nuevo dominio de clock.

**Requisitos afectados:** `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el valor numérico, conversión de referencia y coincidencias pendientes en los acuerdos de timeout y tiempo común. Sustituye la postergación de T, sin fijar R ni cerrar `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Silencio de recuperación y ventana de consulta desde PC

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Temporización de recuperación de `LOAD`.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La recuperación requiere silencio continuo en FPGA y una ventana de espera PC después de detener o cancelar una transferencia fallida, bajo los supuestos del transporte de laboratorio.

**Decisión:** El intervalo de recuperación será **R = 100 ms de silencio continuo**, equivalente a 5.000.000 de clocks funcionales de 50 MHz. R y T representan intervalos independientes aunque tengan el mismo valor. Toda actividad de recepción reiniciará R; al finalizar deberán estar la línea en reposo, RX vacía y ningún byte en curso, conforme al criterio aprobado.

Después de detener/cancelar el intento, la PC esperará una ventana W antes de consultar disponibilidad. Se dimensionará mediante la estimación conservadora del tiempo de transmitir la solicitud `LOAD` y el programa completos, más T y R, redondeada hacia arriba a múltiplos de 100 ms:

```text
trama_nominal_ms = 1000 * 10 / 19200
W_ms = 100 * ceil(((N + 6) * trama_nominal_ms + T_ms + R_ms) / 100)
```

N es el tamaño en bytes del programa del intento; los seis bytes corresponden a la solicitud `LOAD`. Se usa el programa completo para evitar depender de conocer cuántos bytes quedaron pendientes tras cancelar. Para N = 1024, la estimación antes de redondear es aproximadamente 736,458 ms y W = 800 ms; para N = 32, W = 300 ms.

Al terminar W, la PC consultará disponibilidad. Si no recibe respuesta, esperará de nuevo la misma ventana W antes de repetir la consulta. Solo una respuesta disponible permite continuar el flujo de una nueva `LOAD`, cuyo reenvío sigue a elección del usuario.

**Justificación:** R conserva un margen de silencio simple para el TP. La ventana W contempla bytes pendientes, el posible timeout de recepción todavía activo si se perdió una respuesta y la recuperación posterior, sin exigir medir la ocupación exacta del transporte desde PC.

**Consecuencias y alcance pendiente:** Se resuelve L17. La ventana es una estimación de diseño para el envío preparado y seguido del transporte de laboratorio, no una garantía ante pausas arbitrarias del emisor. Se mantienen la cancelación en lo que permita el transporte y el descarte RX. Quedan pendientes las esperas de respuesta en L18 y la realización de los contratos UART, sin introducir un comando de recuperación adicional ni un estado global nuevo.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-010`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve R y las ventanas de consulta de recuperación pendientes en los acuerdos anteriores, conservando T, recuperación automática y reintento manual, sin cerrar todas las esperas de PC ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Esperas de respuesta de PC para LOAD

**Estado del acuerdo:** Aprobado como base de diseño. L18 y `DEC-PROTO-003` permanecen pendientes de completar el presupuesto máximo de preparación de sesión.

**Dominio:** Debug / Esperas del cliente durante carga.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Las esperas de disponibilidad y aceptación son breves; el plazo final depende del tamaño del programa. El presupuesto de preparación se mantiene como dependencia de este acuerdo.

**Decisión:** La PC utilizará un plazo de **200 ms** para obtener respuesta a la consulta de disponibilidad y a la solicitud inicial `LOAD`. Esas respuestas son cortas y el plazo proporciona margen al transporte de laboratorio.

La espera de confirmación final se contará desde que la PC comienza a enviar el contenido. Se calculará para cada intento según N, el tamaño de programa en bytes:

```text
envio_nominal_ms = 1000 * N * 10 / 19200
plazo_final_ms = envio_nominal_ms + preparacion_max_ms + 200
```

El tiempo de envío corresponde al programa, después de la aceptación; los seis bytes de solicitud pertenecen al intercambio previo. La espera no será un valor fijo independiente de N. A baud nominal, 32 bytes requieren aproximadamente 16,667 ms, 256 bytes 133,333 ms y 1024 bytes 533,333 ms de contenido.

Si vence una espera o se recibe fallo, la PC aplicará el cese/cancelación y recuperación aprobados, con reintento solo solicitado por el usuario. La ausencia de confirmación final no certifica que la imagen haya quedado inválida: una imagen ya comprometida no se revierte por perder su respuesta.

**Justificación:** Los intercambios cortos necesitan un margen para comunicación; una carga completa necesita además el tiempo proporcional al tamaño enviado y la preparación previa al commit. Separar esos términos evita un timeout prematuro en programas mayores.

**Consecuencias y alcance pendiente:** Se aprueban los 200 ms de respuestas cortas y de margen final, el cálculo proporcional a N y el punto inicial de la espera final. Queda por fijar `preparacion_max_ms` mediante una cota o presupuesto de `Session Preparation` y el perfil compartido. L18 no se marca completo hasta resolver ese dato; L19 tampoco se adelanta. No se modifica el instante de éxito de `LOAD` ni se introduce un límite de ejecución de `RUN`.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-009`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve parcialmente las esperas de PC pendientes en los acuerdos anteriores, sin inventar la cota de preparación ni cerrar L18 o `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Presupuesto máximo de preparación de sesión

**Estado del acuerdo:** Aprobado como base de diseño. Se completa L18; `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Preparación posterior a `LOAD` y espera final de PC.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La FPGA prepara la sesión después de recibir el programa y antes de confirmar éxito. Los perfiles actuales requieren un presupuesto máximo de preparación de 1 ms.

**Decisión:** Para los perfiles `REFERENCE` y `ALT_1000`, la preparación posterior a `LOAD` tendrá un **presupuesto máximo de 1 ms**, equivalente a **50.000 clocks funcionales de 50 MHz**. Se cuenta desde la entrada a `PREPARING_READY` hasta el flanco de commit que, con `prepare_done`, publica el tamaño y establece `READY`. El envío de la respuesta final se cubre con el margen de comunicación ya acordado.

La preparación debe dejar PC, RF, pipeline y contador en sus valores iniciales, DMEM en cero lógico y el conjunto utilizado vacío. Se confirma apenas termina efectivamente; no se espera deliberadamente 1 ms ni se sustituye `prepare_done` por un temporizador. Este presupuesto es un requisito de diseño, no una duración medida ni una nueva causa de fault o timeout en la FPGA.

La espera final de PC, desde el inicio del envío del contenido, queda para estos perfiles:

```text
preparacion_max_ms = 1
plazo_final_ms = 1000 * N * 10 / 19200 + 1 + 200
```

Para N = 32, 256 y 1024 bytes resulta aproximadamente 217,667 ms, 334,333 ms y 734,333 ms, respectivamente. Los plazos de disponibilidad y aceptación siguen siendo 200 ms. Se conservan recuperación y reintento manual ante vencimiento, sin inferir rollback por ausencia de respuesta final.

**Justificación:** A 50 MHz, recorrer las 2048 posiciones de DMEM de referencia a una posición por clock requiere 40,96 µs. Los 50.000 clocks proporcionan margen para el resto de la preparación. Este cálculo sustenta el presupuesto sin fijar todavía el orden de operaciones ni los puertos de mantenimiento.

**Consecuencias y alcance pendiente:** Se resuelve L18. Al diseñar `Session Preparation` se deberá verificar que la secuencia completa cumple el presupuesto, incluido el commit. Las capacidades arquitectónicamente admitidas no quedan restringidas por esta cota: un perfil futuro deberá revisar explícitamente su presupuesto y la configuración compartida con PC antes de utilizarse. Siguen pendientes L19, la realización de los bloques, las demás operaciones y sus esperas. No se inicia implementación.

**Requisitos afectados:** `REQ-EXEC-017`, `REQ-UART-009`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa `preparacion_max_ms` y el cierre de L18 pendientes en el acuerdo de esperas de PC, sin cambiar el instante de éxito de `LOAD` ni cerrar `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Plazos de RESET, STEP y recepción de Debug

**Estado del acuerdo:** Aprobado como base de diseño. Plazos restantes registrados; C06 conserva pendiente reacción de PC ante timeout, desconexión o respuesta truncada, incluida cabecera final `RUN` incompleta.

**Dominio:** Debug / Esperas de recepción de PC.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** `RESET` y `STEP` requieren un plazo de cabecera de 200 ms. Debug separa parte fija y lista; sus límites utilizan tamaños aprobados, 19200 baud, tramas de diez bits y margen de 200 ms.

**Decisión:** Los plazos son máximos de espera, no demoras obligatorias. Se avanza al recibir los bytes completos:

| Espera de PC | Inicio del plazo | Plazo máximo |
|---|---|---|
| Aceptación `RESET` completa, dos bytes | Inicio del envío de su byte de solicitud | 200 ms |
| Cabecera `STEP` completa, operación y resultado | Inicio del envío de su byte de solicitud | 200 ms |
| Parte fija del cuerpo Debug, 228 bytes | Recepción completa de la cabecera que anuncia Debug | 319 ms |
| Lista de memoria, 5*K bytes, con K > 0 | Recepción completa de `used_count`, al final de la parte fija | ceil(5*K*10*1000/19200 + 200) ms |

La cabecera `STEP` rechazada con `NO_IMAGE`/`BUSY` completa su respuesta en dos bytes; `DONE` anuncia el cuerpo Debug. Los 228 bytes fijos excluyen la cabecera común e incluyen contexto, RF, registros interetapa y `used_count` de cinco bytes, conforme a D05. K es `used_count`, cantidad de bytes DMEM utilizados; cada entrada ocupa cinco bytes. Con K=0, la respuesta termina al completar la parte fija, sin esperar una lista inexistente.

La parte fija ocupa nominalmente 228*10*1000/19200 = 118,75 ms. Al sumar 200 ms y redondear arriba a milisegundos enteros, su plazo es 319 ms. Ejemplos de lista variable: K=2, diez bytes y plazo 206 ms; K=1000, 5000 bytes y plazo 2805 ms; K=2048, 10240 bytes y plazo 5534 ms. El plazo de la lista depende de K, no de la última dirección ni de la capacidad entera cuando la lista es menor.

`RUN` conserva 200 ms para su respuesta inicial completa y, después de `ACCEPTED`, espera de terminación sin límite de duración de ejecución. Una vez recibida la cabecera final `FINISHED`/`FAULT`, la parte fija y lista Debug usan los mismos plazos que `STEP`. `RESET` conserva aceptación antes del `reset` físico y consulta `CHECK_READY` posterior con su plazo de 200 ms ya aprobado; la aceptación no acredita final de `reset` ni existencia de imagen válida.

La representación y el recorrido del snapshot deben respetar estos presupuestos de recepción. Se mantienen baud nominal y margen de diseño del TP; los puertos, lectura/cantidad de DMEM utilizada, preparación necesaria y serialización se concretarán antes de implementar. No se agrega timeout de duración de `RUN` ni de recepción de campos a solicitudes de un byte.

**Justificación:** Los plazos breves mantienen el margen de reacción existente. El tamaño fijo tiene tiempo calculable; K permite calcular el plazo de la lista variable sin penalizar siempre una memoria poco usada ni truncar una lista grande. Cada fase tiene inicio identificable en el formato ya aprobado.

**Consecuencias y alcance pendiente:** Se registra la parte de plazos de C06 sin cerrarlo completo. Pendientes reacción ante timeout/desconexión, abandono de observación parcial y recuperación de PC antes de otra solicitud, y cabecera final `RUN` que empieza pero queda incompleta. La ausencia de confirmación no demuestra que una operación no ocurrió, y no se reenvía automáticamente una operación potencialmente ejecutada. C07 y revisión/consolidación siguen pendientes. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa esperas de `RESET`/`STEP` y recepción del snapshot diferidas a C06; conserva disponibilidad/`LOAD`, espera inicial `RUN`, recuperación FPGA y ausencia de timeout de ejecución.

### Acuerdo parcial de DEC-PROTO-003 — Recuperación de PC y cabecera final de RUN

**Estado del acuerdo:** Aprobado como base de diseño. C06 completo; perfil compartido y revisión/consolidación pendientes en C07/V01–V03.

**Dominio:** Debug / Reacción ante fallo de enlace y reanudación conocida.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Una observación incompleta requiere informar fallo, descartar el parcial y recuperar con silencio continuo de RX y `CHECK_READY`. RUN puede terminar en cualquier momento: la duración máxima de su Debug no acota el inicio del terminal. La consulta debe conservar la frontera de la respuesta y no aceptar pares de bytes de un payload. No deben repetirse automáticamente operaciones potencialmente ejecutadas; la cabecera terminal `RUN` también tiene límite una vez iniciada.

**Decisión:** Ante timeout, desconexión o respuesta truncada, PC informa el fallo, abandona la respuesta parcial y conserva la última observación completa como anterior, sin presentarla como estado nuevo. Detiene la secuencia normal de ejecución y no repite automáticamente `STEP`, `RUN` ni `RESET`: una confirmación perdida no demuestra que la operación no se ejecutó. La imagen y sesión FPGA no hacen rollback por una espera vencida en PC.

Para recuperar nuevas fallas fuera del flujo `LOAD` ya definido, PC lee y descarta RX hasta observar un intervalo continuo sin bytes. Con capacidad DMEM del perfil C, su duración en milisegundos es:

```text
B_lista(C) = ceil(5*C*10*1000/19200 + 200)
B_intercambio(C) = 200 + 319 + B_lista(C)
W_debug(C) = 100 * ceil(B_intercambio(C) / 100)
```

La cuenta usa un reloj monótono y empieza después de abandonar el intercambio fallido; tras desconexión se aplica al retomar el enlace. Cada recepción, incluidos bytes pendientes en buffers locales, vuelve a iniciar el intervalo. Usa capacidad del perfil, pues la cantidad del snapshot puede no haberse recibido. `REFERENCE`: C=2048, lista máxima 5534 ms, intercambio 6053 ms e intervalo 6100 ms. `ALT_1000`: C=1000, lista máxima 2805 ms, intercambio 3324 ms e intervalo 3400 ms. La cota cubre una respuesta ya iniciada y los márgenes aprobados; no limita la duración ni el comienzo del terminal de `RUN`. Los bytes de un terminal que empieza durante el descarte prolongan la espera. El transporte de laboratorio retomado debe entregar en orden y cumplir esos presupuestos; no se garantiza alineación con demoras arbitrarias de bytes. Una nueva pérdida, desconexión o error reinicia la recuperación.

Después del silencio continuo, PC envía una sola consulta `CHECK_READY` conservando el flujo de lectura y su buffer, sin limpiar RX. Si al vencer el intervalo hay bytes recibidos pendientes, se procesan primero y reinician la cuenta en lugar de consultar. Para restablecer comunicación, el primer byte recibido desde el envío debe ser `05` y el siguiente `03` o `04`, ambos dentro de 200 ms desde el inicio del envío. Fragmentar o agrupar bytes en el driver no cambia esa regla. `READY` permite solicitar `LOAD`, `BUSY` indica que todavía no es elegible; ninguna respuesta prueba imagen válida ni reconstruye los ciclos ejecutados.

Ante un primer byte distinto de `05`, incluido `02` de un terminal RUN, un resultado distinto de `03`/`04`, timeout o fallo de enlace, PC abandona la consulta y vuelve al descarte. La cuenta empieza al abandonar la consulta y se reinicia con cada recepción posterior. No vuelve a buscar `05 03` ni `05 04` dentro de los bytes recibidos. Si un terminal impide la consulta por exclusión Debug, su cuerpo se descarta hasta volver a completar el silencio. Solo se repite la consulta informativa, no la operación original.

Si llega una respuesta `CHECK_READY` válida seguida de un terminal RUN, la respuesta breve conserva su frontera porque FPGA la completa antes de enviar el terminal. PC conserva todos los bytes posteriores para el lector normal, incluso si el driver entrega ambos mensajes juntos. Comunicación restablecida no significa que RUN haya terminado ni impide que su terminal empiece inmediatamente después.

Para volver a una sesión conocida, el usuario puede solicitar `RESET` y una nueva `LOAD`, con las secuencias de aceptación/consulta ya aprobadas. No se reanuda automáticamente una ejecución de estado incierto ni se agrega `READ_STATE`, reenvío automático, historial obligatorio o `reset` global automático ante una falla del transporte. `LOAD` conserva su cese/cancelación, ventana W según N, consulta y reintento manual ya definidos; `W_debug` no reemplaza esas reglas.

`RUN` conserva espera de ejecución sin límite mientras su respuesta terminal no haya comenzado. Desde el primer byte de la cabecera final `RUN`, PC espera como máximo 200 ms para completar sus dos bytes. Si comienza pero no termina, se declara fallo y se aplica la recuperación anterior. Cabecera terminal completa `FINISHED`/`FAULT` da inicio a los plazos de parte fija y lista Debug de C06; no se reinicia este plazo de cabecera por bytes parciales.

**Justificación:** Evitar repetir operaciones preserva la incertidumbre real de una confirmación perdida. El intervalo sin bytes cubre el resto de una respuesta ya iniciada bajo las cotas del enlace. Si RUN comienza más tarde, la consulta observa su primer byte porque no limpia RX ni busca coincidencias dentro de un cuerpo. Se vuelve al descarte en lugar de aceptar un par ambiguo. `CHECK_READY` es informativa y permite recuperar comunicación sin ejecutar CPU; `RESET`/`LOAD` voluntarios establecen una sesión nueva conocida. Limitar una cabecera comenzada detecta truncamiento sin limitar la ejecución `RUN`.

**Consecuencias y alcance pendiente:** Se cierra C06 y se consolidan DEC-PROTO-002/003. C07 fijará cómo se selecciona/comparten perfiles; V01/V02/V03 completarán recorridos, revisión de tablas y documento definitivo. El diseño de bloques bajo DEC-SYS-007 concretará puertos, FSM privadas, contadores y arbitraje para cumplir los contratos. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa reacción de PC y cabecera final `RUN` pendientes del acuerdo de plazos, preservando recuperación `LOAD` y los contratos de CPU/Debug.
