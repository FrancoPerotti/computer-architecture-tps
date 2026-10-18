### DEC-PROTO-001 — Formato detallado del protocolo

**Contrato vigente de consulta:** [protocol](../protocol.md), [debug_architecture](../architecture/debug/debug_architecture.md), [response_serializer](../architecture/debug/response_serializer.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada.

**Dominio:** Debug / Protocolo.

**Fecha de aprobación:** 2026-10-01; consolidación de los acuerdos previos y revisión V01/V02/V03.

**Contexto:** El sistema requiere un contrato único para carga, ejecución, pasos, `reset`, disponibilidad y Debug automático. El diseño conjunto PC/FPGA precede a la implementación y mantiene un alcance proporcional al trabajo práctico.

**Opciones consideradas:**

- Delimitación por tamaño o marcador.
- Respuestas de aceptación/finalización diferenciadas.
- Checksum/CRC.
- Consultas Debug adicionales.
- Copia de snapshot o lectura directa retenida.
- Negociación de capacidades o perfil compartido previo.

Los acuerdos parciales seleccionan tamaño explícito, cabecera común, Debug automático y perfil común, sin checksum ni negociación adicional.

**Decisión:** El contrato definitivo es [protocol.md](../protocol.md). `LOAD`=0x01, `RUN`=0x02, `STEP`=0x03, `RESET`=0x04 y `CHECK_READY`=0x05 ocupan un byte. Toda respuesta empieza con eco de código y resultado de un byte, seguido del contenido correspondiente; tabla de doce resultados 0x01–0x0C y estados externos 0x00–0x0D.

`LOAD` declara N unsigned de cinco bytes little-endian, valida imagen no vacía/base cero/contigua/múltiplo de cuatro/dentro de IMEM y espera aceptación antes del contenido seguido. La aceptación invalida la imagen previa; solo preparación completa y commit publican imagen válida y `DONE`. Rechazos previos conservan imagen; fallo de carga aceptada no hace rollback. PC consulta disponibilidad antes de cada carga y FPGA valida independientemente, sin reserva por consulta.

`RUN` tiene aceptación y resultado terminal automático `FINISHED`/`FAULT` con Debug después de drain; `STEP` realizado tiene única respuesta `DONE` con snapshot posterior a un ciclo efectivo, incluidos stall/drain. `RESET` global se genera después del último Stop de su aceptación; botón físico es otra fuente directa. Solo durante ejecución `RUN` se permiten consultas y `RESET` antes de su resultado terminal, con respuestas completas y sin intercalar bytes.

Snapshot binario little-endian, estado retenido leído directamente y exclusión desde instante postciclo hasta último Stop; RX se consume/descarta durante exclusión. Se transmiten campos registrados sin filtrarlos por `valid`, interpretados por el lector. Contexto 19 bytes, RF 128, cuatro registros interetapa 76, cantidad unsigned de cinco bytes y lista de direcciones únicas crecientes/valores actuales escritos por stores comprometidos en la sesión. Cuerpo 228+5*K y respuesta 230+5*K; no marcador final ni consulta Debug extra.

Perfil `REFERENCE` por defecto o `ALT_1000`, seleccionado previamente e igual en PC/FPGA conforme a [memoria](../architecture/memory/memory_architecture.md#perfiles-definidos). Códigos/layout comunes; límites y tiempos por capacidad. Tiempos/recuperación según DEC-PROTO-003; servicios adicionales según DEC-PROTO-002. No se agrega configuración de PC ni negociación UART.

**Justificación:** Formatos por operación y cantidad delimitan mensajes sin ambigüedad para el cliente propio. Separar aceptación, commit y observación evita ejecutar una imagen parcial o mezclar estados mientras UART transmite. Conserva comprobaciones y recuperación básicas con alcance de laboratorio.

**Consecuencias:** V01/V02 verifican recorridos, códigos, campos, offsets, ejemplos y cálculos; V03 consolida documentos y retira la checklist de 52 tareas al archivo histórico retirado (`archive/protocolo_checklist_temporal_2026-10-01.md`); V03 acredita el cierre y remite al contrato [protocol.md](../protocol.md). DEC-PROTO-001 queda cerrada. Puertos físicos, generador UART, correcciones FSM TP2, arbitraje/serialización, ownership y preparación por recurso permanecen en DEC-SYS-007/diseño de bloques; aplicación y assembler en DEC-SYS-008/009. D0 del sistema completo sigue abierto. Esta revisión documental no acredita implementación ni mediciones.

**Requisitos afectados:** `REQ-MEM-003`, `REQ-MEM-008`, `REQ-MEM-010` a `REQ-MEM-012`, `REQ-MEM-015` a `REQ-MEM-019`, `REQ-MEM-021` a `REQ-MEM-024`, `REQ-MEM-027`, `REQ-MEM-029`, `REQ-MEM-030`, `REQ-EXEC-016` a `REQ-EXEC-018`, `REQ-UART-002` a `REQ-UART-011`, `REQ-DBG-001` a `REQ-DBG-017`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de formato, `LOAD`, `RUN`, `STEP`, respuestas, snapshot, códigos, intercambios, errores y perfil. Sus textos fechados se mantienen como historial; referencias a pendientes en esos acuerdos describen el momento de aprobación.

---

### Acuerdo parcial de DEC-PROTO-001 — Tamaño declarado al iniciar LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La FPGA necesita conocer la cantidad de bytes de programa esperada para delimitar una carga. La PC dispone de la imagen ensamblada y puede conocer su tamaño antes de transmitirla.

**Opciones consideradas:** declarar la longitud antes del contenido; delimitar el contenido mediante una marca de finalización.

**Decisión:** Cada solicitud de inicio de `LOAD` declarará el tamaño total de la imagen en **bytes**, antes de transferir las instrucciones. Para una carga aceptada, el receptor llevará el progreso privado y reconocerá la recepción completa al alcanzar exactamente el tamaño declarado.

El tamaño anunciado deberá ser mayor que cero, múltiplo de cuatro y no mayor que la capacidad configurada de IMEM, conforme a las restricciones de imagen ya aprobadas. Por ejemplo, ocho instrucciones de 32 bits corresponden a 32 bytes.

La recepción completa no constituye por sí sola el commit de la imagen ni una confirmación de carga exitosa. Se mantienen la validación y preparación completa de sesión exigidas por `DEC-SYS-003`, `DEC-ARCH-003` y `DEC-ARCH-006`; una carga aceptada incompleta o fallida permanece sin imagen ejecutable válida.

**Justificación:** La longitud explícita permite conocer el límite del contenido desde el inicio, comprobar su tamaño y transportar cualquier valor de instrucción sin reservar una marca dentro de la imagen.

**Consecuencias y alcance pendiente:** Se selecciona únicamente el tamaño declarado como delimitación del contenido de `LOAD`. Los acuerdos siguientes fijan la aceptación previa al envío y la confirmación final de carga exitosa. Permanecen abiertos la codificación y el ancho del campo externo de longitud, el framing, el orden de bytes, la codificación de respuestas, el control del envío posterior a la aceptación, la integridad, los datos excedentes y los timeouts o mecanismos de recuperación. Este acuerdo no prescribe paquetes para otras operaciones ni nuevas señales o estados RTL. La longitud no sustituye una comprobación de integridad.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-012`, `REQ-MEM-024`, `REQ-MEM-030`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** No aplica; acuerdo parcial que restringe las opciones restantes de `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Aceptación previa al envío del programa

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** El inicio de una carga puede rechazarse por tamaño inválido o por falta de elegibilidad del sistema. La PC necesita conocer el resultado de la solicitud antes de transmitir las instrucciones.

**Opciones consideradas:** enviar el programa inmediatamente después de la solicitud; esperar una aceptación explícita de la FPGA.

**Decisión:** La PC enviará primero la solicitud de inicio de `LOAD` con el tamaño declarado y esperará una respuesta explícita de aceptación de la FPGA antes de enviar el contenido del programa. La FPGA aceptará solo si el tamaño satisface las restricciones de imagen y `LOAD` es elegible según el estado global aprobado. Ante una solicitud rechazada, responderá con un rechazo y la PC no enviará el programa.

La aceptación comunicada corresponde al inicio efectivo de `LOAD`, con la invalidación de la imagen anterior ya exigida por la arquitectura. Una solicitud rechazada conserva la imagen vigente y no cancela un ciclo de ejecución continua. La respuesta de aceptación inicial no significa que el programa haya sido recibido, validado ni confirmado como ejecutable.

**Justificación:** La aceptación previa permite resolver una solicitud incompatible antes de transferir las instrucciones y establece cuándo puede comenzar el envío del contenido.

**Consecuencias y alcance pendiente:** Se fija el intercambio solicitud → aceptación o rechazo → contenido solo tras aceptación. El acuerdo siguiente fija la confirmación final de carga exitosa. Permanecen abiertos los códigos y campos de respuesta, el framing, el tratamiento de contenido enviado sin aceptación, el control del ritmo de transferencia, la integridad y la recuperación ante pérdida de la respuesta. No se define un ACK por byte o bloque ni un nuevo estado global. Los timeouts y reintentos corresponden a `DEC-PROTO-003`.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-012`, `REQ-MEM-019`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** No aplica; complementa el acuerdo de tamaño declarado sin cerrar `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Confirmación final de carga exitosa

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La PC necesita distinguir la aceptación inicial de `LOAD` de la disponibilidad efectiva del nuevo programa para ejecutar.

**Opciones consideradas:** inferir el éxito al terminar el envío; recibir una confirmación explícita de la FPGA después de completar la carga y preparar la sesión.

**Decisión:** La FPGA enviará una respuesta final de carga completada correctamente después de recibir la cantidad declarada de bytes, superar la validación de carga y completar la preparación y el commit de la nueva sesión. Esta respuesta significará que la imagen está confirmada y el sistema está listo para ejecutar; no iniciará automáticamente `RUN` ni `STEP`.

La respuesta será distinguible de la aceptación inicial. Solo podrá emitirse después del commit aprobado `PREPARING_READY && prepare_done`, que publica el tamaño confirmado y lleva el sistema a `READY`. Recibir el último byte o activar `load_ok` no basta para emitirla. Una carga fallida no emitirá confirmación de éxito y conservará el comportamiento de fallo cerrado ya aprobado.

**Justificación:** Una confirmación final explícita permite saber que el programa está disponible para ejecutar y que terminó la preparación de sesión, además de la recepción del contenido.

**Consecuencias y alcance pendiente:** El flujo exitoso será solicitud con tamaño → aceptación → contenido → validación y preparación → confirmación final. Permanecen abiertos los códigos y campos de respuesta, la integridad, las respuestas de fallo y los mecanismos ante pérdida de la confirmación. La pérdida de la respuesta no implica rollback de una sesión ya comprometida ni permite inferir que la carga falló; timeouts y recuperación corresponden a `DEC-PROTO-003`. Este acuerdo no agrega estados globales ni fija la FSM privada del transporte.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-008`, `REQ-MEM-024`, `REQ-MEM-030`, `REQ-EXEC-017`, `REQ-DBG-012`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** No aplica; complementa los acuerdos de tamaño declarado y aceptación previa sin cerrar `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — LOAD sin checksum ni CRC

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La consigna no exige checksum ni CRC para cargar programas. El equipo no observó alteraciones del contenido recibido por la UART del TP2 ni recibió correcciones por ausencia de estas comprobaciones. Para el alcance del laboratorio se prioriza un protocolo de carga sencillo.

**Opciones consideradas:** incorporar una comprobación de integridad del programa mediante checksum o CRC; cargarlo sin esa comprobación adicional.

**Decisión:** `LOAD` no incorporará checksum ni CRC del contenido del programa. El diseño asumirá que los bytes recibidos sin errores informados por la UART corresponden a los enviados. Esto es un supuesto del enlace para el trabajo práctico, no una garantía de detección de cualquier alteración.

Se mantienen las comprobaciones de tamaño, elegibilidad, recepción completa y preparación de sesión, junto con el tratamiento de los errores que informe UART y de las transferencias incompletas. La política concreta de fallo, los timeouts y la recuperación continúan pendientes. Una alteración que conserve la longitud y no produzca un error UART puede pasar inadvertida; la confirmación final de `LOAD` acredita el cumplimiento de las comprobaciones acordadas, sin certificar igualdad del contenido mediante checksum o CRC.

**Justificación:** El beneficio de la comprobación adicional no justifica su complejidad en el contexto y alcance acordados. La ausencia de checksum o CRC no elimina la necesidad de controlar las condiciones de carga ya aprobadas.

**Consecuencias y alcance pendiente:** No se agregarán campos de checksum o CRC del programa, cálculo ni comparación de estos valores en PC o FPGA para `LOAD`. Esta elección resuelve la comprobación de integridad del contenido de `LOAD` mencionada como pendiente en los acuerdos anteriores. No define por sí sola la protección de otras operaciones ni el framing; permanecen abiertos el orden de bytes, las codificaciones de mensajes, el ritmo de transferencia y el tratamiento de errores de transporte. No se modifica el contenido ni la validez de las instrucciones del ISA.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el punto de integridad del contenido de `LOAD` de los acuerdos parciales anteriores, sin cerrar `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Instrucciones de LOAD en little-endian

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** Cada instrucción tiene 32 bits y UART transporta bytes. El emisor y el Loader necesitan un orden inequívoco para reconstruir la palabra, respetando el orden consecutivo de instrucciones de la imagen.

**Opciones consideradas:** transmitir los bytes de cada instrucción desde el menos significativo al más significativo (little-endian); transmitirlos en el orden inverso (big-endian).

**Decisión:** Las instrucciones de `LOAD` se transmitirán en little-endian: para una palabra `W[31:0]`, se enviarán en orden `W[7:0]`, `W[15:8]`, `W[23:16]` y `W[31:24]`. Las instrucciones se enviarán en orden de dirección creciente, comenzando por la correspondiente a la dirección cero. Por ejemplo, `0x00A585B3` se transmitirá como los cuatro bytes `B3 85 A5 00`.

El Loader reconstruirá una palabra completa de 32 bits antes de habilitar su escritura síncrona en IMEM. Para los bytes recibidos consecutivamente `b0`, `b1`, `b2`, `b3`, la palabra será `{b3, b2, b1, b0}`. No se escribirá una instrucción incompleta ni se modificará la codificación de la instrucción.

**Justificación:** El transporte coincide con el little-endian arquitectónico ya aprobado para memoria y mantiene una correspondencia directa entre bytes de la imagen y direcciones crecientes.

**Consecuencias y alcance pendiente:** Se fija únicamente el orden de los bytes del contenido de instrucciones de `LOAD`. No se extiende esta elección al campo de longitud, a direcciones externas, a respuestas ni a snapshots; su codificación y orden de bytes permanecen pendientes. Tampoco se cambia el orden de bits dentro de cada byte de la UART ni se fija el framing del protocolo.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-023`, `REQ-MEM-024`, `REQ-MEM-027`, `REQ-SW-004`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el orden de bytes de las instrucciones de `LOAD` mencionado como pendiente en los acuerdos anteriores, sin cerrar `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Respuesta de fallo por recepción incompleta

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** El timeout de recepción de `LOAD` ya está aprobado. La PC necesita conocer que la FPGA declaró fallida la carga y distinguirlo de una aceptación inicial o una carga exitosa.

**Opciones consideradas:** detectar el fallo únicamente por ausencia de confirmación final; emitir una respuesta explícita de fallo desde la FPGA.

**Decisión:** Cuando venza el timeout de recepción de contenido de una carga aceptada, la FPGA enviará una respuesta que identifique el fallo de `LOAD` por recepción incompleta. El significado lógico será «carga fallida: recepción incompleta», sin fijar una representación textual o binaria ni un código concreto.

El programa permanecerá inválido y no se emitirá la confirmación final de éxito. La respuesta de fallo será distinguible de la aceptación inicial y de la confirmación de carga completada. No será un fault arquitectónico de una instrucción ni una finalización de ejecución por `halt`.

**Justificación:** Una respuesta explícita comunica el resultado de la carga a la PC sin depender exclusivamente de que esta agote su propia espera.

**Consecuencias y alcance pendiente:** Quedan abiertos el framing, los códigos y campos, el envío ante TX ocupado, la pérdida de la respuesta, las respuestas a otros errores y la recuperación/resincronización. Informar el fallo no implica que el enlace ya pueda aceptar un comando nuevo ni garantiza que la PC haya recibido la respuesta. Estos aspectos se completarán en `DEC-PROTO-001` y `DEC-PROTO-003`.

**Requisitos afectados:** `REQ-UART-002`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia y significado de la respuesta de fallo por timeout de contenido de `LOAD`, sin cerrar `DEC-PROTO-001` ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Disponibilidad común para iniciar LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y disponibilidad.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La consulta de disponibilidad debe cubrir la primera carga, la recuperación de una transferencia fallida y la operación posterior al `reset`.

**Opciones consideradas:** indicar disponibilidad únicamente después de una carga fallida; utilizar una indicación común de disponibilidad para iniciar `LOAD`.

**Decisión:** El protocolo proporcionará a la PC una indicación con el significado «disponible para recibir una solicitud `LOAD`». La misma indicación se utilizará antes de la primera carga, cuando el sistema esté operativo tras arranque o `reset` global, y al completar la recuperación/resincronización de una carga fallida. Solo podrá indicar disponibilidad cuando el transporte permita interpretar una nueva solicitud y el estado global sea elegible para `LOAD`.

Esta indicación no significa que exista un programa válido ni que la CPU esté lista para ejecutarlo. Tampoco equivale a aceptar una carga concreta: después de obtener disponibilidad, la PC enviará la solicitud con tamaño y esperará su aceptación, que verificará tamaño y elegibilidad actual. No se introduce un nuevo estado global ni se identifica este aviso con el estado interno `READY` de una imagen confirmada.

**Justificación:** Una indicación común hace consistente el inicio de la primera carga y de un reintento, y permite observar que terminó la recuperación del receptor.

**Consecuencias y alcance pendiente:** El acuerdo siguiente de `DEC-PROTO-002` fija una consulta iniciada por la PC para obtener la disponibilidad. Quedan pendientes códigos, campos, framing, momentos permitidos, esperas y recuperación ante falta de respuesta. La indicación posterior a una carga fallida requerirá que la resincronización realmente haya terminado. La regla sobre consulta previa a `LOAD` se fija en el acuerdo de secuencia posterior.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-002`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia y significado común del aviso de disponibilidad para `LOAD`, sin cerrar su transporte ni `DEC-PROTO-001` o `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Secuencia de PC y validación independiente de LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y contrato de PC.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La secuencia del cliente debe distinguirse de las condiciones de aceptación de `LOAD` en FPGA: una consulta previa no constituye una autorización almacenada.

**Opciones consideradas:** exigir una consulta previa y recordarla en la FPGA para habilitar `LOAD`; establecer la secuencia de PC y validar `LOAD` por sus propias condiciones actuales.

**Decisión:** Antes de cada intento de carga, incluido un reintento, la PC consultará disponibilidad y esperará una respuesta disponible. Luego solicitará `LOAD` con el tamaño en bytes y esperará su aceptación antes de enviar instrucciones. Tras transferir el contenido esperará la confirmación final o el fallo de la operación según las reglas aprobadas. Una respuesta ocupada o la ausencia de respuesta a la consulta no habilitará el envío del programa por el flujo de PC.

La FPGA validará cada solicitud `LOAD` según su formato válido, tamaño, elegibilidad actual del estado global y disponibilidad efectiva del receptor. La ausencia de una consulta previa no será por sí misma causa de rechazo de una `LOAD` que satisfaga sus condiciones. Una consulta anterior no reservará el receptor ni hará aceptable una solicitud incompatible; la aceptación de `LOAD` seguirá siendo la autorización concreta para transferir el contenido.

**Justificación:** El cliente sigue un flujo explícito y la FPGA comprueba las condiciones de la operación en el momento correspondiente. La consulta informativa no exige introducir un registro de consulta anterior, su caducidad ni nuevas condiciones de elegibilidad arquitectónica.

**Consecuencias y alcance pendiente:** No se agregará una condición de habilitación de `LOAD` basada en haber consultado previamente. Quedan pendientes la codificación, framing, esperas, respuesta a ocupado, pérdida de respuestas y resincronización. Se deberán verificar ambas reglas: el flujo de PC consulta y espera aceptación; la FPGA acepta o rechaza `LOAD` por sus condiciones actuales incluso cuando se omite la consulta o cuando existe una consulta anterior.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-007`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve las reglas de consulta previa y aceptación de `LOAD` pendientes en los acuerdos anteriores, sin cerrar el protocolo completo.

### Acuerdo parcial de DEC-PROTO-001 — Código de operación y tamaño de LOAD de cinco bytes

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Formato de solicitudes UART.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** El receptor necesita identificar la operación y la longitud de sus campos. El código determina el formato; `LOAD` contiene cinco bytes de tamaño.

**Opciones consideradas:** solicitudes con formato conocido según el código; delimitar cada solicitud con una marca de finalización adicional. Para `LOAD` se selecciona un campo fijo capaz de representar la capacidad arquitectónica inclusive.

**Decisión:** En recepción alineada, cada solicitud comenzará con un código de operación de **un byte**. El código determinará los campos siguientes y su formato. Los valores de los códigos y los campos de las otras operaciones permanecen pendientes.

La solicitud `LOAD` tendrá exactamente **seis bytes de datos UART**: un byte de código `LOAD` seguido de cinco bytes que representan el tamaño total del programa en bytes como entero sin signo, en little-endian. Si esos cinco bytes son `b0` a `b4`, el tamaño será `b0 + (b1 << 8) + (b2 << 16) + (b3 << 24) + (b4 << 32)`, interpretado sin truncamiento en 40 bits. Por ejemplo, 32 bytes se anunciarán como `[código LOAD] 20 00 00 00 00`; el tamaño arquitectónico máximo de `2^32` bytes como `[código LOAD] 00 00 00 00 01`.

El receptor esperará los cinco bytes de tamaño antes de validar la solicitud. El tamaño recibido deberá ser mayor que cero, múltiplo de cuatro y no mayor que la capacidad activa de IMEM. Se validará el valor completo antes de reducirlo al ancho interno del perfil; valores altos no podrán truncarse y convertirse en tamaños aparentemente válidos. Los 40 bits del campo externo no amplían el límite arquitectónico de `2^32` bytes.

Una solicitud incompleta o rechazada no producirá el inicio de `LOAD` ni invalidará por sí sola la imagen vigente. Una solicitud completa aceptada aplicará la invalidación ya aprobada y enviará aceptación. Las instrucciones se transferirán posteriormente, después de que la PC reciba esa aceptación; no forman parte de los seis bytes de la solicitud.

**Justificación:** Un formato conocido por código permite determinar cuándo termina una solicitud correctamente alineada. Cinco bytes de tamaño cubren el límite arquitectónico inclusive y mantienen un formato fijo independiente del perfil sintetizado.

**Consecuencias y alcance pendiente:** Los bits físicos de Start/Stop de UART no se cuentan entre estos seis bytes ni en el tamaño del programa. El acuerdo posterior de `DEC-PROTO-003` fija timeout para la recepción incompleta de los cinco bytes de tamaño. Quedan abiertos los valores de códigos, campos de otras operaciones y respuestas, tratamiento de códigos desconocidos, duración y respuesta de ese timeout, datos excedentes y recuperación de alineación. Este formato no resuelve por sí solo la resincronización tras un error y no modifica los parámetros físicos UART del TP2 o TP3.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-MEM-012`, `REQ-MEM-024`, `REQ-MEM-030`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el formato de solicitudes y el ancho y orden de bytes del tamaño de `LOAD` pendientes en los acuerdos anteriores, sin cerrar el protocolo completo.

### Acuerdo parcial de DEC-PROTO-001 — Respuesta de solicitud LOAD incompleta

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Respuestas a solicitudes UART.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se aprobó descartar por timeout una solicitud `LOAD` cuyo campo de tamaño no se completó, conservando la imagen vigente. La PC debe distinguir ese rechazo del fallo de una transferencia de instrucciones que ya fue aceptada.

**Opciones consideradas:** inferir el rechazo por falta de aceptación; emitir una respuesta explícita de solicitud incompleta.

**Decisión:** Si vence el timeout de recepción de los cinco bytes de tamaño después del código `LOAD`, la FPGA enviará una respuesta con el significado «solicitud `LOAD` incompleta». Será identificable como error de recepción de la solicitud, antes de la aceptación de carga, y distinguible de «carga fallida: recepción incompleta», que corresponde al contenido de una `LOAD` ya aceptada.

La solicitud se descartará sin aceptar `LOAD`, sin escribir instrucciones ni invalidar la imagen vigente. Se mantendrán los efectos aprobados del timeout de solicitud incompleta; esta respuesta no constituye un fault arquitectónico, un `reset`, una aceptación ni una confirmación de carga exitosa.

**Justificación:** Una respuesta explícita permite que la PC conozca el resultado de la solicitud y en qué fase ocurrió el error, con la semántica correspondiente de conservación de imagen.

**Consecuencias y alcance pendiente:** Se fija el significado de la respuesta, no un texto literal enviado por UART ni sus códigos, campos o longitud. Quedan abiertos el framing, la entrega ante TX ocupado, pérdida de la respuesta, tratamiento de bytes tardíos y recuperación de alineación. Informar el rechazo no indica por sí solo que el receptor ya esté preparado para recibir otro comando.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-MEM-024`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia y significado de la respuesta al timeout de solicitud `LOAD` incompleta, sin cerrar su codificación, entrega o recuperación ni `DEC-PROTO-001` o `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Transferencia seguida del programa

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Transferencia del contenido de `LOAD`.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La transferencia de programa debe precisar si utiliza envío continuo o bloques con confirmaciones intermedias. Se selecciona envío continuo para simplificar el protocolo.

**Opciones consideradas:** transferencia seguida del contenido; bloques o instrucciones con confirmaciones intermedias.

**Decisión:** Después de recibir la aceptación de `LOAD`, la PC enviará el contenido completo anunciado como una única transferencia lógica de bytes en orden de dirección creciente y con cada instrucción en little-endian. No esperará confirmaciones por byte, instrucción o bloque. En el flujo exitoso, al terminar el envío esperará la confirmación final de carga tras validación, preparación y commit ya aprobados.

La FPGA recibirá el stream, reconstruirá cada palabra completa de cuatro bytes y podrá escribirla en IMEM durante la recepción, con el ownership aprobado. No se requiere acumular el programa completo en un buffer intermedio antes de escribir IMEM. La cantidad de bytes del contenido sigue siendo exactamente la anunciada; el contenido no se interpretará como códigos de operación.

Transferir seguido no exige que todos los bytes lleguen sin ningún intervalo ni realizar una única llamada al sistema desde la PC. Los buffers o fragmentaciones internas de PC y del adaptador no introducen bloques de protocolo ni confirmaciones intermedias. Las pausas permitidas y la duración del timeout común permanecen pendientes.

Se mantienen las respuestas de error, timeout, fallo cerrado y recuperación acordadas. Si la carga falla durante el envío, la PC deberá detener el intento anterior y coordinar su recuperación; el envío seguido no obliga a completar un intento que ya fue declarado fallido ni permite mezclar comandos nuevos con su contenido pendiente.

**Justificación:** El tamaño declarado delimita la transferencia y la aceptación autoriza el envío completo. Evitar confirmaciones intermedias simplifica el control de transmisión, recepción y progreso de la carga.

**Consecuencias y alcance pendiente:** El diseño de UART, FIFO y Loader deberá sostener el ritmo de bytes de la configuración elegida, con un presupuesto de latencia de consumo y buffers que evite desbordamiento durante una carga correcta. No se aprueba una profundidad de FIFO ni se acredita todavía ese presupuesto. Quedan pendientes baud/formato físico, pausas permitidas del emisor, dimensionado y manejo de buffers, errores de recepción y resincronización. El valor numérico del timeout se justificará después de cerrar esos contratos.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-009`, `REQ-MEM-024`, `REQ-MEM-027`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el modo de transferencia del programa y descarta confirmaciones intermedias de contenido, sin cerrar su temporización, buffers o recuperación ni `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Errores básicos de LOAD y alcance del trabajo práctico

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` y `DEC-PROTO-003` permanecen pendientes en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y alcance de diseño.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El contrato necesita políticas explícitas para tamaño inválido, error UART y bytes adicionales. PC y FPGA se diseñan conjuntamente, con un cliente que respeta el protocolo y alcance de laboratorio.

**Opciones consideradas:** comprobaciones y recuperación básicas bajo el contrato del cliente propio; ampliar el protocolo para cubrir emisores independientes y violaciones arbitrarias de ese contrato.

**Decisión:** Se adoptan las siguientes políticas:

1. **Tamaño inválido:** Recibidos los cinco bytes de tamaño, se rechaza `LOAD` si el valor es cero, no es múltiplo de cuatro o supera IMEM. La respuesta identifica «tamaño inválido» y se conserva la imagen anterior. Una solicitud completa y alineada rechazada por ese motivo no requiere recuperación por silencio; la PC no envía contenido.
2. **Error UART durante recepción de `LOAD`:** Se abandona inmediatamente la recepción y se aplica la recuperación por descarte y silencio ya aprobada. Si `LOAD` todavía no fue aceptada, se conserva la imagen anterior; si fue aceptada, queda inválida. La respuesta identifica «error de recepción UART» sin exigir distinguir error de trama y desbordamiento de RX.
3. **Bytes posteriores al contenido:** Solo se escriben los bytes anunciados. Desde la recepción del último byte hasta terminar la preparación y el envío de la confirmación final, se descartan los bytes adicionales sin interpretarlos como comandos ni modificar el programa. Si el contenido esperado se recibió correctamente y se completa la preparación, se mantiene el éxito de `LOAD`. Después de la confirmación se retorna a la interpretación normal de solicitudes.

El contrato de uso presupone que la PC envía exactamente el tamaño anunciado, espera aceptación antes del contenido y espera el resultado final antes de otra operación. No se agregan mecanismos ni nuevos pendientes para detectar sobrantes arbitrariamente tardíos o para protegerse de un cliente que incumple deliberadamente esa secuencia. Se conservan los timeouts y la recuperación básica acordados.

**Justificación:** Las comprobaciones cubren errores básicos de solicitud y recepción sin ampliar el diseño más allá del enlace de laboratorio y del cliente propio del TP.

**Consecuencias y alcance pendiente:** Quedan resueltas estas políticas y la extensión de la recuperación a errores UART durante la recepción de `LOAD`. Permanecen pendientes la codificación de respuestas, su integración temporal, los parámetros UART y los tiempos ya diferidos. El alcance no exige distinguir todas las causas físicas de recepción ni demostrar robustez ante emisores arbitrarios. No se agregan campos, comandos o estados globales por esos escenarios.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve tamaño inválido, errores UART durante `LOAD` y descarte posterior al contenido. Delimita la robustez requerida al contexto del TP sin cerrar el protocolo completo.

### Acuerdo parcial de DEC-PROTO-001 — Numeración consecutiva de códigos de operación

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Codificación de solicitudes.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El formato utiliza un byte de código por solicitud. Debe establecerse una regla de numeración antes de asignar los códigos concretos al conjunto definitivo de comandos.

**Decisión:** Cada código de operación ocupará un byte binario. Los códigos se asignarán consecutivamente desde `0x01`: `0x01`, `0x02`, `0x03`, etc. La correspondencia entre esos valores y las operaciones se definirá cuando se cierre el conjunto de comandos.

La tabla propuesta de `LOAD`, `RUN`, `STEP`, `READ_STATE`, `RESET` y `QUERY_READY` no constituye una asignación aprobada. Se mantienen los servicios y comportamientos previamente acordados, sin fijar aquí nombres finales, operaciones adicionales ni sus valores individuales. Esta regla corresponde a solicitudes de PC hacia FPGA; no define los códigos de respuesta.

**Justificación:** Permite fijar una convención sencilla sin anticipar una tabla para operaciones cuyo diseño aún está abierto.

**Consecuencias y alcance pendiente:** Quedan pendientes la lista final de comandos, su orden en la tabla, la asignación individual y la codificación de respuestas. El ancho de un byte confirma el acuerdo anterior; no cambia el formato de seis bytes de la solicitud `LOAD`.

**Requisitos afectados:** `REQ-UART-008`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Fija la regla general de numeración sin cerrar la tabla ni `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Cabecera común de respuestas y resultados de LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Formato de respuestas.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Las respuestas necesitan identificar la solicitud y su resultado. Se define una cabecera común y su aplicación a `LOAD`, dejando la numeración de resultados para un acuerdo posterior.

**Decisión:** Toda respuesta correspondiente a una solicitud tendrá la forma `[código de operación: 1 byte][resultado: 1 byte][datos, si corresponden]`. El primer byte repetirá el código de la solicitud; el segundo identificará el resultado y formará parte del contenido de respuesta. Los datos adicionales y su delimitación dependerán de la operación y del resultado, y se definirán al especificar esa respuesta.

Las respuestas de `LOAD` no llevarán datos adicionales: tendrán exactamente dos bytes y finalizarán al recibir el segundo. Se aprueban los siguientes resultados simbólicos, con los efectos ya acordados:

| Resultado              | Significado                                                                                                        |
|------------------------|--------------------------------------------------------------------------------------------------------------------|
| `ACEPTADA`             | `LOAD` fue aceptada; la PC puede comenzar a enviar el programa.                                                    |
| `COMPLETADA`           | Se recibió y validó el programa y se completó preparación y commit de sesión; el sistema está listo para ejecutar. |
| `TAMAÑO_INVALIDO`      | Solicitud rechazada por tamaño cero, no múltiplo de cuatro o superior a IMEM.                                      |
| `NO_DISPONIBLE`        | El estado actual no permite aceptar `LOAD`.                                                                        |
| `SOLICITUD_INCOMPLETA` | Venció la espera de los bytes del tamaño, antes de aceptar `LOAD`.                                                 |
| `CONTENIDO_INCOMPLETO` | Venció la espera del programa después de aceptar `LOAD`.                                                           |
| `ERROR_UART`           | Se abandonó la recepción por un error informado por UART.                                                          |

En un flujo exitoso, la FPGA responde `[LOAD][ACEPTADA]` a la solicitud y, después de recibir el contenido y completar la preparación, responde `[LOAD][COMPLETADA]`. Los nombres son símbolos de documentación, no cadenas de texto enviadas por UART. Ambos campos serán bytes binarios.

**Justificación:** La cabecera identifica la operación y el resultado con un formato breve. `LOAD` utiliza respuestas de longitud fija; la misma cabecera permite incorporar posteriormente los datos requeridos por otras operaciones.

**Consecuencias y alcance pendiente:** Se resuelven P01 y L13 de la checklist: cabecera común, campos, longitudes y resultados de `LOAD`. Los códigos de operación y los valores de resultado siguen pendientes en C02/C03. El formato y la longitud de los datos de Debug siguen pendientes en D05; no se asume que toda respuesta del sistema tenga dos bytes. No se cambia la política de errores, recuperación, conservación de imagen ni el instante de confirmación final.

**Requisitos afectados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-005`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la estructura de respuestas y los formatos básicos de `LOAD` pendientes en los acuerdos anteriores, sin cerrar su codificación numérica ni el protocolo completo.

### Acuerdo parcial de DEC-PROTO-001 — Formato de consulta de disponibilidad

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` y `DEC-PROTO-002` permanecen pendientes en sus aspectos restantes.

**Dominio:** Debug / Consulta de disponibilidad para `LOAD`.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La consulta iniciada por PC necesita un formato mínimo compatible con la cabecera común de respuestas y el significado de disponibilidad ya definido.

**Decisión:** La solicitud de disponibilidad no tendrá parámetros: ocupará exactamente un byte, el código de esa operación. El nombre simbólico `CONSULTAR_DISPONIBILIDAD` se usa para documentar el intercambio, sin fijar todavía su código numérico.

Cuando el receptor pueda interpretar la consulta, responderá exactamente dos bytes: `[CONSULTAR_DISPONIBILIDAD][resultado]`. No habrá datos adicionales; el segundo byte completará la respuesta.

| Resultado simbólico | Significado                                                                                |
|---------------------|--------------------------------------------------------------------------------------------|
| `DISPONIBLE`        | El receptor puede atender una nueva solicitud y el estado global es elegible para `LOAD`.  |
| `NO_DISPONIBLE`     | En ese momento el sistema no puede aceptar `LOAD`, por ejemplo durante ejecución continua. |

La consulta no modificará la imagen ni la ejecución. Una respuesta disponible no reservará el sistema ni aceptará anticipadamente una carga: la FPGA volverá a comprobar las condiciones al recibir `LOAD`. Se mantienen el significado común antes de primera carga, tras `reset` y después de recuperación, y la ausencia de relación entre disponibilidad e imagen ejecutable válida.

Durante recuperación se descartarán los bytes de consulta sin respuesta, conforme a la política aprobada. Durante el contenido de `LOAD` los bytes serán datos del programa y no comandos; durante preparación y envío de confirmación se mantiene el descarte aprobado. La PC seguirá respetando las esperas acordadas antes de consultar.

**Justificación:** Un byte de solicitud y dos de respuesta proporcionan la información necesaria para iniciar el flujo de carga sin agregar parámetros ni datos de estado generales.

**Consecuencias y alcance pendiente:** Se resuelve L14 de la checklist. Quedan pendientes los valores numéricos en C02/C03, el timeout de consulta y las ventanas de recuperación/repetición ya diferidas. No se agrega reserva, reporte de capacidades ni snapshot a la consulta.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-011`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve los campos y longitudes de solicitud y respuesta de disponibilidad pendientes en los acuerdos anteriores, sin cerrar códigos, tiempos ni los identificadores generales del protocolo.

### Acuerdo parcial de DEC-PROTO-001 — Secuencia completa y cierre del intercambio LOAD

**Estado del acuerdo:** Aprobado como base de diseño. Se completa L19; `DEC-PROTO-001` permanece pendiente para las demás operaciones, códigos y reglas comunes.

**Dominio:** Debug / Intercambio completo de carga.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El intercambio `LOAD` debe reunir formatos, tiempos, efectos y errores básicos, incluida la frontera que permite iniciar la siguiente solicitud.

**Decisión:** La PC prepara los N bytes del programa antes de solicitar `LOAD`. El intercambio exitoso sigue esta secuencia; los nombres de códigos/resultados son simbólicos hasta C02/C03:

| Paso | Mensaje o acción                                           | Tiempo y efecto                                                                                                                                                                                       |
|------|------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1    | PC → FPGA: `[CONSULTAR_DISPONIBILIDAD]`                    | Solicitud de un byte; PC espera hasta 200 ms.                                                                                                                                                         |
| 2    | FPGA → PC: `[CONSULTAR_DISPONIBILIDAD][DISPONIBLE]`        | Dos bytes; informa elegibilidad actual sin reservar la carga ni modificar CPU/imagen.                                                                                                                 |
| 3    | PC → FPGA: `[LOAD][N: cinco bytes unsigned little-endian]` | Seis bytes; FPGA recibe el tamaño con T = 100 ms de inactividad desde el código y valida tamaño completo y elegibilidad. PC espera hasta 200 ms por la respuesta inicial.                             |
| 4    | FPGA → PC: `[LOAD][ACEPTADA]`                              | Dos bytes; al aceptar invalida la imagen anterior. El T de contenido empieza al finalizar físicamente el segundo byte, incluido Stop.                                                                 |
| 5    | PC → FPGA: N bytes de contenido                            | Envío seguido, instrucciones little-endian y direcciones crecientes, sin confirmaciones intermedias. T se reinicia por cada byte correcto mientras falten bytes.                                      |
| 6    | FPGA: preparación y commit                                 | Recepción completa lleva a `PREPARING_READY`; preparación y commit en `READY` dentro del presupuesto de 1 ms para `REFERENCE`/`ALT_1000`. Se confirma la imagen y la sesión inicial sin ejecutar CPU. |
| 7    | FPGA → PC: `[LOAD][COMPLETADA]`                            | Dos bytes; PC espera hasta `1000 * N * 10 / 19200 + 201` ms desde el inicio del contenido en los perfiles actuales.                                                                                   |

La PC espera los dos bytes completos de COMPLETADA antes de enviar la siguiente operación. La FPGA mantiene el descarte de RX durante preparación y envío de esa confirmación; termina el intercambio de `LOAD` y vuelve a interpretar solicitudes cuando finaliza físicamente su segundo byte, incluido Stop. El commit en `READY` puede preceder al fin de transmisión: `READY` por sí solo no abre el receptor a una solicitud nueva durante la confirmación. Un intercambio exitoso no agrega una espera de silencio R.

Para N = 32, la solicitud de carga es `[LOAD][20 00 00 00 00]`, seguida de 32 bytes solo después de ACEPTADA; la espera final es aproximadamente 217,667 ms. Para N = 1024, el tamaño es `00 04 00 00 00` y la espera final aproximadamente 734,333 ms.

#### Errores básicos del recorrido LOAD

| Caso                                            | Respuesta de FPGA                           | Imagen / sesión                                                             | Continuación                                                                              |
|-------------------------------------------------|---------------------------------------------|-----------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Consulta interpretada en estado no elegible     | `[CONSULTAR_DISPONIBILIDAD][NO_DISPONIBLE]` | Conservadas.                                                                | PC no solicita `LOAD` mientras no obtenga DISPONIBLE.                                     |
| Solicitud completa con tamaño inválido          | `[LOAD][TAMAÑO_INVALIDO]`                   | Conservadas; no se acepta `LOAD`.                                           | PC no envía contenido; no requiere recuperación por silencio.                             |
| Solicitud `LOAD` completa en estado no elegible | `[LOAD][NO_DISPONIBLE]`                     | Conservadas; la ejecución activa continúa.                                  | PC no envía contenido; el rechazo completo no requiere recuperación por silencio.         |
| Tamaño incompleto al vencer T                   | `[LOAD][SOLICITUD_INCOMPLETA]`              | Conservadas; `LOAD` no fue aceptada.                                        | Descarte y recuperación por silencio.                                                     |
| Contenido incompleto al vencer T                | `[LOAD][CONTENIDO_INCOMPLETO]`              | Sin imagen válida después de la aceptación.                                 | Descarte y recuperación por silencio.                                                     |
| Error UART al recibir tamaño o contenido        | `[LOAD][ERROR_UART]`                        | Conservadas antes de aceptar; sin imagen válida después.                    | Abandonar recepción y recuperar por silencio; error tiene prioridad sobre byte y timeout. |
| Vence la espera de PC o se pierde una respuesta | No se presupone una respuesta recibida.     | No inferir rollback: perder COMPLETADA no revierte una imagen comprometida. | PC detiene/cancela el intento y aplica la espera de recuperación antes de consultar.      |

En recuperación, la FPGA descarta RX sin borrar TX, incluidas consultas/`reset` UART, hasta R = 100 ms de silencio continuo, línea en reposo, ningún byte en curso y RX vacía. PC detiene/cancela ante fallo o vencimiento, espera `W_ms = 100 * ceil(((N + 6) * 1000 * 10 / 19200 + 100 + 100) / 100)` y consulta disponibilidad; si no obtiene respuesta, espera W nuevamente antes de repetir la consulta. El usuario solicita una nueva `LOAD` completa si desea reintentar. Para N = 1024, W = 800 ms. Se conserva el alcance del cliente propio y transporte de laboratorio.

**Consecuencias y alcance pendiente:** P01, L13–L19 y U01–U03 quedan completos, permitiendo continuar con R01. La asignación numérica de códigos/resultados permanece deliberadamente diferida. Se documentó el comportamiento; siguen pendientes la realización del receptor/UART/preparación, las demás operaciones y la revisión final del protocolo antes de D0.

**Requisitos afectados:** `REQ-UART-007` a `REQ-UART-011`, `REQ-EXEC-017`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos previos de `LOAD` y precisa el final físico de su intercambio antes de la siguiente solicitud, sin cambiar la política de imagen, los tiempos ni el reintento manual.

### Acuerdo parcial de DEC-PROTO-001 — Solicitud y aceptación de RUN

**Estado del acuerdo:** Aprobado como base de diseño. Se completa R01; `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Inicio o continuación de ejecución continua.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** `LOAD` deja una imagen confirmada y una sesión lista, sin ejecución automática. `RUN` necesita definir su solicitud y el significado de `ACCEPTED`.

**Decisión:** Una solicitud `RUN` ocupa exactamente un byte `[RUN]`, sin parámetros. Cuando el receptor interpreta esa solicitud como comando, su respuesta inicial ocupa exactamente dos bytes:

| Condición                           | Respuesta inicial      | Efecto                                                                            |
|-------------------------------------|------------------------|-----------------------------------------------------------------------------------|
| Imagen válida y estado elegible     | `[RUN][ACEPTADA]`      | Toma la orden y realiza la ejecución continua correspondiente al contexto actual. |
| Sin imagen válida                   | `[RUN][SIN_IMAGEN]`    | Rechazo; no inicia una ejecución.                                                 |
| Imagen válida y estado incompatible | `[RUN][NO_DISPONIBLE]` | Rechazo; conserva la sesión y no altera la ejecución vigente.                     |

Los nombres son simbólicos: la asignación numérica de códigos y resultados permanece pendiente en C02/C03. Se mantienen las reglas del receptor durante contenido, preparación/confirmación `LOAD` y recuperación: esos bytes no se interpretan como solicitudes `RUN`.

Los estados arquitectónicamente elegibles son `READY`, `STEPPING`, `HALT_DRAIN_STEP`, `FAULT_DRAIN_STEP`, `FINISHED` y `FAULT`, con imagen válida:

- Desde `READY` comienza la sesión preparada; el flanco de aceptación ya ejecuta su primer ciclo efectivo.
- Desde `STEPPING` continúa la sesión existente desde el punto alcanzado por los `STEP`, sin volver a inicializarla.
- Desde un drain `STEP` autoriza el ciclo actual de drenado y completa automáticamente el trabajo anterior que todavía quede, conforme a la arquitectura; no admite nuevas instrucciones.
- Desde `FINISHED` o `FAULT` inicia `PREPARING_RUN` con la misma imagen. Tras la preparación efectiva, ejecuta el primer ciclo y continúa automáticamente en una sesión nueva con estado inicial.

ACEPTADA certifica que la orden fue tomada y se realizará su ejecución continua, incluida la preparación previa cuando corresponda. No certifica que la preparación ya terminó, que el estado actual sea `RUNNING` ni que el programa haya finalizado. La aceptación no modifica la autorización de ciclos existente ni introduce una espera de transmisión UART antes de avanzar la CPU.

**Justificación:** Una orden sin parámetros alcanza para iniciar o continuar el programa confirmado. Separar aceptación, ausencia de imagen y estado incompatible permite a PC entender la respuesta inicial sin confundirla con el resultado arquitectónico de la ejecución.

**Consecuencias y alcance pendiente:** Se completa R01 y se continúa con R02. Quedan pendientes la notificación de terminación normal/fault y su contenido Debug, la comunicación durante ejecución, los plazos de PC y los valores numéricos. No se agrega una duración máxima de programa ni una captura durante `RUN`.

**Requisitos afectados:** `REQ-UART-003`, `REQ-EXEC-006`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-003`, `REQ-SW-005`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa el formato y la respuesta inicial de `RUN` pendientes en el protocolo, conservando la elegibilidad y el control de ejecución aprobados.

### Acuerdo parcial de DEC-PROTO-001 — Resultado automático de RUN con estado de Debug

**Estado del acuerdo:** Aprobado como base de diseño. Se completa R02; `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Terminación de ejecución continua y observación final.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** `RUN` ejecuta continuamente y puede necesitar drenado después de confirmar halt o fault. La consigna requiere enviar automáticamente el resultado y Debug al terminar.

**Decisión:** Un `RUN` aceptado que alcanza su estado terminal genera una respuesta final automática, sin exigir una consulta posterior de PC:

| Terminación           | Condición arquitectónica                                     | Respuesta final                      |
|-----------------------|--------------------------------------------------------------|--------------------------------------|
| Normal por halt       | `FINISHED`, con pipeline vacío después del drenado necesario | `[RUN][FINALIZADA][estado de Debug]` |
| Excepcional por fault | `FAULT`, con pipeline vacío después del drenado necesario    | `[RUN][FAULT][estado de Debug]`      |

La cabecera mantiene el código de la solicitud `RUN` y un byte de resultado. Los nombres FINALIZADA y `FAULT` son simbólicos hasta C03; la representación binaria del estado de Debug, su longitud y delimitación se completarán en D05. La respuesta final no se reduce a dos bytes: incluye el snapshot acordado.

El snapshot corresponde a un único instante lógico posterior al drenado y al último commit de las instrucciones anteriores. Incluye RF, los cuatro registros interetapa, DMEM utilizada, PC global, contador de ciclos, estado terminal y demás información mínima aprobada; en `FAULT` incluye causa y PC de la instrucción causante. Mantiene la coherencia durante toda la serialización, conforme al contrato de Debug. No se anuncia FINALIZADA o `FAULT` por la mera confirmación inicial de halt/fault mientras quedan instrucciones anteriores.

El intercambio normal observado por PC es solicitud `RUN` → respuesta inicial ACEPTADA completa → respuesta final con Debug. Si el programa termina antes de transmitirse toda la aceptación, se conserva ese orden y se envía primero la aceptación; las respuestas no intercalan sus bytes. La realización de retención y serialización queda pendiente del diseño de bloques y D06.

Un `RUN` rechazado solo produce su respuesta inicial de rechazo. Un programa que continúa ejecutándose sin alcanzar un terminal no genera una respuesta final por el simple transcurso del tiempo. La interrupción por `reset` conserva sus efectos arquitectónicos y su intercambio se resolverá en Z02; no se presenta como finalización normal del programa.

**Justificación:** La entrega automática satisface la observación final requerida y permite a PC recibir aceptación, resultado y estado sin consultar periódicamente la terminación. Esperar el drenado asegura que el resultado incluye todos los efectos arquitectónicos anteriores.

**Consecuencias y alcance pendiente:** Se completa R02 y se continúa con R03. Se resuelve para `RUN` la entrega automática que figuraba abierta en D02; permanecen abiertas la observación de `STEP` y las consultas adicionales. Quedan pendientes códigos numéricos, campos/layout/longitud del snapshot, realización de captura/envío, solicitudes admitidas durante ejecución/envío, interacción con `reset` y plazos de PC. No se inicia implementación.

**Requisitos afectados:** `REQ-EXEC-005`, `REQ-EXEC-007`, `REQ-EXEC-018`, `REQ-UART-003`, `REQ-UART-005`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-005`, `REQ-SW-009`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa la notificación final de `RUN` y su entrega de Debug pendientes en los acuerdos anteriores, sin fijar todavía el layout ni cambiar halt, fault o drenado.

### Acuerdo parcial de DEC-PROTO-001 — Comunicación y espera de PC durante RUN

**Estado del acuerdo:** Aprobado como base de diseño. Se completa R03; `DEC-PROTO-001` y `DEC-PROTO-003` permanecen pendientes en sus aspectos restantes.

**Dominio:** Debug / Solicitudes durante ejecución continua y temporización de PC.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** `RUN` puede durar un tiempo indeterminado después de `ACCEPTED`. Deben distinguirse el plazo de aceptación, la duración del programa y las solicitudes admitidas durante ejecución y drenado automático.

**Decisión:** Mientras el sistema se encuentre en `RUNNING`, `HALT_DRAIN_AUTO` o `FAULT_DRAIN_AUTO` y el receptor interprete solicitudes, se aplica esta tabla:

| Solicitud                  | Resultado                                                                     | Efecto                                                                              |
|----------------------------|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| `RESET`                    | Aceptar el `reset` global ya acordado; formato/confirmación pendientes en Z02 | Abandonar la ejecución y aplicar sus efectos arquitectónicos.                       |
| `CONSULTAR_DISPONIBILIDAD` | `[CONSULTAR_DISPONIBILIDAD][NO_DISPONIBLE]`                                   | Informar que `LOAD` no es elegible, sin modificar ejecución ni imagen.              |
| `LOAD`                     | `[LOAD][NO_DISPONIBLE]` después de recibir su solicitud completa              | No aceptar la carga ni recibir contenido de programa; conservar ejecución e imagen. |
| `RUN`                      | `[RUN][NO_DISPONIBLE]`                                                        | No iniciar otra ejecución; conservar la actual.                                     |
| `STEP`                     | `[STEP][NO_DISPONIBLE]`                                                       | No insertar un paso ni alterar el avance continuo actual.                           |

Una solicitud `LOAD` conserva su formato de seis bytes y las reglas de solicitud incompleta/error UART ya aprobadas. La tabla no cambia el tratamiento de contenido `LOAD` o recuperación, donde los bytes no se interpretan como comandos, ni prescribe los campos futuros de `STEP`/`RESET`. Las solicitudes incompatibles no suprimen ciclos automáticos de CPU.

La PC dispone de **200 ms para recibir la respuesta inicial completa de `RUN`**, con origen al enviar la solicitud, usando el mismo margen de comunicación de las respuestas cortas. Esa respuesta puede ser ACEPTADA, `SIN_IMAGEN` o `NO_DISPONIBLE`, según R01.

Después de recibir ACEPTADA, la PC espera el resultado final con Debug **sin un timeout de duración del programa**. Si el programa continúa sin alcanzar halt/fault terminal, la ausencia de resultado final no se interpreta por el paso del tiempo como error de recepción ni como finalización. El usuario puede solicitar `RESET` para abandonar una ejecución que no termina; no se ordena `reset` automáticamente por su duración.

**Justificación:** Se mantienen disponibles el mecanismo mínimo de recuperación y la consulta informativa, mientras se rechazan órdenes incompatibles sin detener la CPU. Una respuesta inicial corta admite un plazo de comunicación; la duración de un programa depende de su ejecución y puede ser ilimitada.

**Consecuencias y alcance pendiente:** Se completa R03 y se continúa con S01. `RUN` queda definido en R01–R03 al nivel de intercambio acordado. Siguen pendientes los valores numéricos, el layout de Debug, la realización de bloques y las reglas mientras se serializa el snapshot en D06, además de orden/arbitraje de respuestas y `reset` en C04/Z02. El vencimiento de la espera inicial o las fallas de enlace se completarán en C06, sin asumir que perder una aceptación pruebe que `RUN` no se ejecutó. Esta decisión fija la espera inicial y la ausencia de límite de programa también para `DEC-PROTO-003`.

**Requisitos afectados:** `REQ-UART-003`, `REQ-UART-006`, `REQ-UART-007`, `REQ-EXEC-006`, `REQ-EXEC-012`, `REQ-EXEC-015`, `REQ-DBG-001`, `REQ-SW-005`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa la comunicación durante `RUN` y su plazo de respuesta inicial pendientes en los acuerdos de `RUN`, sin cerrar la transmisión de Debug ni el intercambio de `reset`.

### Acuerdo parcial de DEC-PROTO-001 — Solicitud STEP y respuesta con Debug de cada ciclo

**Estado del acuerdo:** Aprobado como base de diseño. Se completan S01 y S02; `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Avance de un ciclo y observación posterior.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Cada `STEP` debe reunir solicitud, resultado del único ciclo y Debug en el mismo intercambio, sin diferir la observación a otra operación.

**Decisión:** `STEP` se solicita con exactamente un byte `[STEP]`, sin parámetros. Para un paso realizado, la FPGA responde una única vez, después de su ciclo efectivo:

```text
PC → FPGA: [STEP]
FPGA → PC: [STEP][COMPLETADO][estado de Debug]
```

No se envía una aceptación previa separada. La FPGA realiza un único ciclo, captura el estado posterior y transmite su snapshot junto con el resultado. COMPLETADO confirma que ocurrió el ciclo solicitado; no afirma que terminó el programa ni que se completó una instrucción. Los casos de halt/fault, drenado pendiente y terminal se completarán en S03.

La cabecera tiene código `STEP` y resultado de un byte cada uno. COMPLETADO es un nombre simbólico hasta C03. El estado de Debug contiene RF, PC global, contador de ciclos, estado global e imagen válida, los cuatro registros interetapa, DMEM utilizada y los metadatos de fault cuando sean vigentes, conforme al contenido mínimo aprobado. Todos sus campos corresponden al mismo instante posterior al ciclo, incluidos sus commits, avance o stall y cambios de estado. Layout, orden de campos/bytes, longitud y delimitación siguen pendientes en D05; realización de captura y serialización en D06.

Si no hay imagen válida, se rechaza con `[STEP][SIN_IMAGEN]`; con imagen válida en estado incompatible, se rechaza con `[STEP][NO_DISPONIBLE]`. Son respuestas de dos bytes sin snapshot, sin realizar el ciclo. Se mantienen las reglas del receptor que impiden interpretar bytes de contenido `LOAD` o recuperación como comandos.

La elegibilidad arquitectónica se conserva: `READY`, `STEPPING`, `HALT_DRAIN_STEP`, `FAULT_DRAIN_STEP`, `FINISHED` y `FAULT` con imagen válida. Desde terminales se prepara una sesión nueva con la misma imagen y luego se ejecuta el único ciclo solicitado; se responde con su estado posterior, no con el estado de preparación. Desde `READY`/`STEPPING` el ciclo se realiza al aceptar la orden; durante drain `STEP` avanza un solo ciclo de trabajo anterior. Un stall consume el paso y no autoriza un ciclo adicional.

La PC obtiene el paso y su Debug en una misma respuesta, sin una consulta adicional. La CPU vuelve al contexto de espera correspondiente; UART y Debug conservan su actividad funcional para transmitir el snapshot sin contar ciclos de CPU por esa transmisión.

**Justificación:** La observación automática de cada paso satisface la consigna y muestra exactamente el efecto del ciclo pedido. Una respuesta posterior al avance reúne resultado y observación sin un intercambio de aceptación adicional.

**Consecuencias y alcance pendiente:** Se completan S01/S02 y se continúa con S03. `RUN` y `STEP` tienen entrega automática de Debug aprobada; D02 conserva únicamente las consultas y momentos adicionales de captura por decidir. Siguen pendientes los resultados de pasos que confirman halt/fault, layout/longitud del snapshot, puertos/secuencia de realización, solicitudes durante envío y plazos/fallas de comunicación en C06. No se programa implementación.

**Requisitos afectados:** `REQ-UART-004`, `REQ-UART-005`, `REQ-EXEC-009`, `REQ-EXEC-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-006`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa solicitud y respuesta `STEP` con su Debug automático, conservando el único ciclo por paso y dejando explícitamente S03 y el layout pendientes.

### Acuerdo parcial de DEC-PROTO-001 — Halt, fault y drenado en respuestas STEP

**Estado del acuerdo:** Aprobado como base de diseño. Se completa S03; `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Resultado arquitectónico de cada paso y drenado.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** `STEP` puede confirmar halt o fault con instrucciones anteriores pendientes. El estado global de Debug debe distinguir drenado y terminal sin cambiar el formato de respuesta.

**Decisión:** Todo `STEP` realizado, incluidos los ciclos que confirman halt/fault o completan drenado, conserva la única respuesta:

```text
[STEP][COMPLETADO][estado de Debug]
```

COMPLETADO acredita que ocurrió el ciclo solicitado. La situación de la ejecución se interpreta a partir del `global_state` del snapshot posterior al ciclo:

| Estado observado   | Significado                                                              |
|--------------------|--------------------------------------------------------------------------|
| `STEPPING`         | La sesión espera el siguiente comando, sin frontera terminal confirmada. |
| `HALT_DRAIN_STEP`  | Halt confirmado; quedan instrucciones anteriores por completar.          |
| `FINISHED`         | Terminación normal con pipeline vacío.                                   |
| `FAULT_DRAIN_STEP` | Fault confirmado; quedan instrucciones anteriores por completar.         |
| `FAULT`            | Terminación por fault con pipeline vacío.                                |

`FAULT_DRAIN_STEP` y `FAULT` incluyen causa y PC de la instrucción causante como metadatos vigentes. La representación externa de estados y metadatos sigue pendiente en D05/C03, sin agregar otro resultado `STEP` para distinguir estas situaciones.

Durante drenado `STEP`, cada nuevo `STEP` realiza un único ciclo del trabajo anterior y devuelve su Debug posterior. Al completar la última instrucción anterior, ese mismo snapshot ya muestra `FINISHED` o `FAULT`; no se solicita un ciclo vacío adicional ni se genera una segunda respuesta terminal. Se mantienen `HOLD` entre pasos y el conteo de ciclos efectivos.

Un `RUN` aceptado durante drain `STEP` ejecuta el ciclo actual de drenado. Desde `HALT_DRAIN_STEP` consume el único WB pendiente y alcanza `FINISHED` en ese mismo ciclo. Desde `FAULT_DRAIN_STEP` alcanza `FAULT` si el pipeline queda vacío; solo si queda trabajo después del ciclo pasa a `FAULT_DRAIN_AUTO` y continúa drenando automáticamente.

Desde `FINISHED`/`FAULT`, un `STEP` posterior sigue iniciando una sesión nueva sobre la imagen confirmada, conforme a S01 y la arquitectura; no se reanuda la sesión terminal. Los rechazos conservan `SIN_IMAGEN`/`NO_DISPONIBLE` y no se presentan como ciclos realizados.

**Justificación:** Separar el resultado del comando (ciclo realizado) del estado de ejecución en Debug permite conservar un único formato `STEP` sin ocultar halt, fault ni trabajo pendiente. La observación refleja los efectos anteriores que efectivamente se comprometieron en ese ciclo.

**Consecuencias y alcance pendiente:** Se completa S03 y se continúa con Z02. S01–S03 quedan definidos al nivel de intercambio acordado. Siguen pendientes códigos numéricos, layout/longitud del snapshot, realización de captura/envío, solicitudes durante transmisión y esperas/fallas de PC. No se modifica la FSM global ni se inicia implementación.

**Requisitos afectados:** `REQ-EXEC-005`, `REQ-EXEC-009`, `REQ-EXEC-010`, `REQ-EXEC-018`, `REQ-UART-004`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-006`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa halt/fault y drenado de `STEP` pendientes en el acuerdo de `STEP` con Debug, conservando COMPLETADO y la semántica de un ciclo por paso.

### Acuerdo parcial de DEC-PROTO-001 — Representación binaria de campos del snapshot

**Estado del acuerdo:** Aprobado como base de diseño. Se completa P02; D05 y `DEC-PROTO-001` siguen pendientes del layout y delimitación restantes.

**Dominio:** Debug / Anchos externos, orden de bytes y representación escalar.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El contenido de registros interetapa y memoria utilizada ya está definido; se requieren reglas comunes de representación en bytes antes de fijar orden y cantidad de entradas.

**Decisión:** El snapshot se transmite como datos binarios. Cada campo comienza en un byte propio; no se empaquetan campos pequeños distintos dentro del mismo byte:

- Campos de 32 bits, incluidos RF, PC, instrucciones, operandos, direcciones y resultados: cuatro bytes.
- Contador de ciclos de 64 bits: ocho bytes.
- Campos de ocho bits, incluidos valores de bytes DMEM: un byte.
- Flags y campos de menos de ocho bits, incluidos índices, controles y causas: un byte cada uno, con bits altos sobrantes en cero. Flags booleanos: 00 o 01.
- Todos los campos multibyte del protocolo usan little-endian, manteniendo también el tamaño y las instrucciones `LOAD` ya aprobados.

Los datos arquitectónicos conservan su patrón de bits, incluidos los valores de 32 bits interpretables con signo por una instrucción; no se convierten a texto ni se alteran por el padding de campos pequeños. El padding externo no agrega ni modifica bits registrados en los registros interetapa. Las codificaciones semánticas de resultados y estados pendientes no quedan asignadas por escoger un byte para transportarlas.

Ejemplo: 0x12345678 se transmite como `78 56 34 12`; un índice de registro 5, como `05`; un flag verdadero, como `01`. La causa interna de tres bits ocupa un byte con sus bits altos en cero; su interpretación sigue el campo y la validez correspondientes.

Las longitudes resultantes para el contenido ya aprobado de los registros interetapa son:

| Latch    | Longitud externa de sus campos |
|----------|--------------------------------|
| `IF/ID`  | 11 bytes                       |
| `ID/EX`  | 30 bytes                       |
| `EX/MEM` | 20 bytes                       |
| `MEM/WB` | 15 bytes                       |

Los cuatro registros interetapa ocupan 76 bytes; RF completo ocupa 128 bytes. Estas longitudes no fijan todavía el orden de bloques/campos, identificadores adicionales, presencia de metadatos inactivos ni longitud total del snapshot. Cada entrada lógica de memoria utilizada tendrá dirección de cuatro bytes y valor de uno; cantidad de entradas, posición de esa cantidad y representación de lista vacía se completarán en D05.

**Justificación:** Anchos naturales, little-endian y un byte propio para cada campo pequeño permiten formar e interpretar los campos sin cruzarlos entre límites de bytes. Se conserva el orden multibyte utilizado por `LOAD` y memoria.

**Consecuencias y alcance pendiente:** Se completa P02. D03 ya dispone de campos y anchos externos; D04 de dirección/valor por byte, pero ambos continúan abiertos hasta su representación completa en D05. Se sigue con orden de bloques, identificación de RF/registros interetapa, cantidad/longitud de memoria, metadatos según validez, codificación de estados/resultados y delimitación del snapshot. La captura/envío se concreta en D06. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-005`, `REQ-DBG-005`, `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-016`, `REQ-DBG-017`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve endianness y representación escalar externos pendientes en P02 y parcialmente en D03–D05, sin cambiar campos internos ni asignar códigos numéricos pendientes.

### Acuerdo parcial de DEC-PROTO-001 — Orden y delimitación del snapshot

**Estado del acuerdo:** Aprobado como base de diseño. Completa el layout por posición y la lista binaria de D04; D03/D05 conservan pendientes de interpretación y códigos. Captura y envío se definirán en D06.

**Dominio:** Debug / Orden de campos y longitud del mensaje.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El layout debe ordenar contexto, RF, registros interetapa y memoria utilizada, con cantidad explícita de entradas y sin identificadores adicionales por registro o registro interetapa.

**Decisión:** Después de la cabecera común `[código de solicitud: 1][resultado: 1]`, el cuerpo del snapshot tiene este orden fijo. Los offsets siguientes comienzan en cero en el cuerpo, excluyendo los dos bytes de cabecera:

| Bloque / campo             | Offset en el cuerpo | Longitud en bytes |
|----------------------------|---------------------|-------------------|
| `global_state`             | 0                   | 1                 |
| `image_valid`              | 1                   | 1                 |
| PC global                  | 2                   | 4                 |
| `cycle_count`              | 6                   | 8                 |
| `fault_cause` global       | 14                  | 1                 |
| `fault_pc` global          | 15                  | 4                 |
| RF: x0, x1, …, x31         | 19                  | 128               |
| `IF/ID`                    | 147                 | 11                |
| `ID/EX`                    | 158                 | 30                |
| `EX/MEM`                   | 188                 | 20                |
| `MEM/WB`                   | 208                 | 15                |
| `used_count`               | 223                 | 5                 |
| Lista de memoria utilizada | 228                 | `5 * used_count`  |

RF identifica cada registro por posición: `x_i` comienza en `19 + 4*i`. Los registros interetapa se identifican por bloque y sus campos siguen exactamente el orden del esquema aprobado en `interfaces.md` y el acuerdo de exposición completa: `IF/ID` 5 campos, `ID/EX` 15, `EX/MEM` 8 y `MEM/WB` 6. No se agregan bytes de identificación ni campos nuevos. Cada campo conserva el ancho externo y little-endian del acuerdo de representación escalar.

`fault_cause` y `fault_pc` globales siempre ocupan sus posiciones. Solo se interpretan como fault vigente en `FAULT_DRAIN_AUTO`, `FAULT_DRAIN_STEP` o `FAULT`. Su presencia no agrega un flag de fault ni exige borrar bits físicos cuando el estado no los valida.

`used_count` es unsigned de 40 bits, cinco bytes little-endian, y cuenta entradas de bytes escritos; no es la última dirección ni la longitud de un rango. Su dominio es de cero hasta la capacidad de DMEM, inclusive. Permite representar hasta 2^32 entradas: `00 00 00 00 01`. Cada entrada ocupa `[dirección de byte: 4 bytes little-endian][valor actual: 1 byte]`; todas las direcciones son únicas, pertenecen a DMEM y aparecen en orden creciente, conforme al criterio de DEC-SYS-005. Para `used_count=0`, los cinco bytes son cero y no sigue ninguna entrada.

La longitud del cuerpo es `228 + 5*used_count` bytes; la respuesta completa, incluida su cabecera, ocupa `230 + 5*used_count`. La PC recibe la parte fija, lee la cantidad y recibe exactamente las entradas indicadas; al terminar la última entrada termina el mensaje. No hay marcador final, longitud adicional, checksum ni padding entre bloques. Sin memoria escrita la respuesta completa ocupa 230 bytes; con dos entradas, 240 bytes. Con los 2048 bytes de DMEM del perfil `REFERENCE` escritos, ocupa 10470 bytes.

**Justificación:** El layout fijo identifica contexto, registros y registros interetapa por posición. La cantidad explicita tanto la lista vacía como el final de una lista de longitud variable, preservando todo el rango de capacidades admitido.

**Consecuencias y alcance pendiente:** Se completa D04 y se cierra DEC-SYS-005 como criterio y representación externa de memoria utilizada. D03/D05 mantienen pendientes de codificación semántica, interpretación de campos inactivos y tratamiento de snapshot truncado; los códigos numéricos globales y de resultados se asignarán en C03. D06 concretará captura, coherencia durante envío y solicitudes concurrentes. No se inicia implementación.

**Requisitos afectados:** `REQ-DBG-005`, `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-016`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-SW-009`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa orden, identificación por posición, cantidad y delimitación pendientes del acuerdo de representación binaria, sin cambiar los esquemas funcionales ni asignar códigos pendientes.

### Acuerdo parcial de DEC-PROTO-001 — Campos registrados e interpretación del snapshot

**Estado del acuerdo:** Aprobado como base de diseño. Completa códigos de control, exposición de campos inactivos y tratamiento de snapshot incompleto. D03 completo; asignación de códigos globales/resultados en C03, captura/envío en D06 y plazos/fallas restantes en C06.

**Dominio:** Debug / Representación externa y responsabilidad del lector.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Debug reutiliza códigos arquitectónicos y descarta observaciones incompletas. La interpretación de campos residuales depende de los indicadores `valid` del receptor.

**Decisión:** Los controles y causas transmiten sus códigos funcionales ya definidos en la arquitectura, sin otra tabla de traducción: el campo ocupa un byte, conservando sus bits significativos y completando los superiores con cero. Esto incluye `alu_op`, `alu_src`, `result_sel`, `flow_op`, `mem_op`, `reg_write` y las causas de fetch/fault. Los códigos externos de `global_state` y resultados todavía se asignarán en C03; no se impone una codificación física a la FSM global por este acuerdo.

Debug expone todos los campos registrados aprobados, incluidos `valid` y `fetch_fault_valid`, en el formato fijo acordado. Para registros interetapa inválidos conserva los datos registrados; no filtra campos, no sustituye sus valores por cero y no agrega una clasificación de residuos. El padding externo de campos pequeños continúa aplicándose y no borra sus bits significativos.

La responsabilidad de interpretar los valores corresponde al lector o consumidor de Debug. `valid` indica una instrucción activa; cuando vale cero, los restantes datos no representan por sí solos una instrucción activa. En `IF/ID`, `fetch_fault_valid` indica separadamente un candidato y habilita interpretar el PC/causa correspondientes, sin presentarlo como fault global confirmado. El lector interpreta causa/PC globales como fault vigente solamente cuando `global_state` valida esa condición. Los indicadores existentes aportan el contexto; el emisor no decide cómo se muestra ni si se ocultan valores en la PC.

Una respuesta de Debug se admite como nueva observación solamente cuando se recibió completa según el layout y `used_count`. Ante respuesta incompleta, el consumidor descarta esa observación parcial y conserva la última completa, identificada con su ciclo y sesión anteriores; no la presenta como un estado nuevo. El plazo para declarar recepción incompleta y la recuperación del enlace se definirán en C06. No se agrega un checksum ni reenvío automático.

**Justificación:** Reutilizar códigos y exponer estado registrado conserva una representación directa y fija. Los indicadores permiten al lector distinguir datos activos, candidatos y valores sin vigencia. Exigir recepción completa evita combinar partes de estados diferentes o actualizar la observación con información parcial.

**Consecuencias y alcance pendiente:** D03 queda completo: contenido, anchos, orden, identificación por posición, códigos de campos y responsabilidad de interpretación. DEC-ARCH-009 conserva pendiente la asignación externa de `global_state` en C03. D05 conserva esa dependencia de códigos, que se retoma en C03; se avanza a D06 para captura y envío coherente. No se selecciona aquí una implementación de captura, una presentación de PC ni los plazos restantes.

**Requisitos afectados:** `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa las reglas pendientes del acuerdo de orden y delimitación; explicita responsabilidad del lector y preserva los esquemas funcionales y códigos arquitectónicos.

### Acuerdo parcial de DEC-PROTO-001 — Envío exclusivo de Debug con estado retenido

**Estado del acuerdo:** Aprobado como base de diseño. D06 completo en el nivel de contrato del protocolo; puertos, secuencia de recorrido y FSM privada quedan para el diseño de bloques. Códigos globales/resultados pendientes en C03 y plazos/fallas en C06.

**Dominio:** Debug / Coherencia, exclusión de solicitudes y `reset` durante envío.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La respuesta Debug requiere estado detenido, espera completa desde PC y descarte RX durante el envío. Debe distinguirse `RESET` UART del botón físico.

**Decisión:** El instante observado es el estado posterior al flanco del único ciclo efectivo de `STEP` o al último ciclo efectivo de `RUN` que alcanza `FINISHED`/`FAULT` después del drenado. Incluye los commits de RF/DMEM y todos los valores registrados posteriores a ese flanco. Desde ese estado hasta terminar físicamente la respuesta, el transporte no admite nuevas solicitudes que puedan cambiar la sesión; la exclusión incluye espera previa a transmitir y toda la cabecera común y el cuerpo. `RUN` conserva el orden aprobado: primero aceptación completa, luego respuesta final con Debug, aunque alcance el terminal antes de finalizar la aceptación.

La CPU permanece sin nuevos ciclos efectivos; no comienza `LOAD` ni preparación de otra sesión. PC, RF, registros interetapa, contador, estado, imagen y DMEM de la sesión permanecen estables. UART, lectura Debug, recorrido de metadatos y serialización siguen funcionando con el clock funcional común. Se selecciona lectura directa del estado retenido, respetando los puertos de lectura y ownership; no se necesita una copia completa adicional ni shadow de RF, registros interetapa y DMEM para garantizar coherencia. El registro de bytes, índices o cantidad necesario para recorrer/serializar se concretará en el diseño de bloques.

La PC espera la respuesta completa antes de enviar cualquier otra solicitud, incluida consulta de disponibilidad o `RESET`. Durante la exclusión, la FPGA consume y descarta los bytes RX sin interpretarlos como comandos, responderlos ni conservarlos para ejecutarlos después. No se encola una respuesta `NO_DISPONIBLE` entre bytes Debug. Un `RESET` enviado prematuramente por UART también se descarta; la PC debe enviarlo después del intercambio completo, y entonces rige su aceptación previa al `reset` global ya aprobada.

La admisión de solicitudes vuelve a habilitarse al finalizar físicamente el último byte de la respuesta Debug, incluido su bit de Stop; encolarlo en FIFO TX no basta. No se agrega un intervalo de silencio al envío correcto. El contrato supone una PC cooperativa y no incorpora mecanismos para emisores que continúen enviando solicitudes después de violar esa secuencia.

El botón físico conserva el `reset` global directo e inmediato conforme al acondicionamiento aprobado; puede interrumpir la transmisión. Se abandona el envío previo y no se continúa con datos de la nueva sesión dentro de esa respuesta. La PC descarta el snapshot incompleto y conserva la última observación completa como anterior. Al retomar el enlace, sigue el flujo ya aprobado de abandonar el intercambio previo y consultar disponibilidad; los plazos y la recuperación del enlace quedan para C06. No hay aceptación UART ni aviso espontáneo por el botón.

**Justificación:** Los momentos automáticos de Debug ya dejan la CPU detenida. Excluir operaciones de sesión permite leer directamente un estado estable durante una transferencia lenta y delimitar una sola respuesta. Consumir RX evita acumular solicitudes accidentales en FIFO; distinguir `reset` UART y físico conserva la prioridad y respuesta de cada mecanismo.

**Consecuencias y alcance pendiente:** Se cierra D06 como contrato de coherencia y transporte, sin agregar estados a la FSM global de 14 estados. La exclusión y el fin físico se coordinan en la capa de protocolo, antes de entregar comandos aceptados a la CPU. La realización de señales, puertos de lectura, cantidad/recorrido de bytes usados, control privado de Debug y distribución de recursos se completará antes de implementar. C01/C02/C03 concretan lista y códigos; C04 reúne elegibilidad e intercambios; C05/C06 completan errores y plazos. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-EXEC-012`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-016`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Selecciona estado retenido y lectura directa para los momentos automáticos aprobados; completa captura/envío y `reset` durante snapshot pendientes de acuerdos anteriores. Conserva las reglas de `RESET` reconocido fuera del envío, `reset` físico, sesión y prioridad funcional.

### Acuerdo parcial de DEC-PROTO-001 — Códigos definitivos de solicitud

**Estado del acuerdo:** Aprobado como base de diseño. C02 completo; códigos de resultado y `global_state` pendientes en C03.

**Dominio:** Debug / Códigos binarios de operación.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La lista definitiva de cinco operaciones requiere códigos consecutivos desde 0x01 y una cabecera común de respuesta.

**Decisión:** Cada solicitud comienza con un byte binario de operación:

| Operación     | Código hexadecimal |
|---------------|--------------------|
| `LOAD`        | 0x01               |
| `RUN`         | 0x02               |
| `STEP`        | 0x03               |
| `RESET`       | 0x04               |
| `CHECK_READY` | 0x05               |

La respuesta comienza con ese mismo código y después un byte de resultado, seguido por los datos definidos para la operación. Esto rige tanto aceptación/final de `LOAD` y `RUN` como respuesta `STEP`, `RESET` y `CHECK_READY`. Los códigos no expresan prioridad y sus valores no se reutilizan automáticamente para codificar resultados.

Ejemplos de solicitudes completas: `RUN` `02`, `STEP` `03`, `RESET` `04`, `CHECK_READY` `05`. Una solicitud `LOAD` de 32 bytes es `01 20 00 00 00 00`; después de aceptación se envían exactamente sus 32 bytes de programa. En una respuesta `LOAD` los dos bytes son `[01][resultado]`; `STEP` realizado usa `[03][resultado][snapshot]`. Los símbolos de resultado conservan sus significados aprobados, pero su byte numérico se asignará en C03. Los formatos simbólicos existentes se interpretan mediante esta tabla; no representan cadenas ASCII.

**Justificación:** La tabla implementa la regla de un byte y numeración consecutiva aprobada, identifica inequívocamente las cinco solicitudes y permite completar la representación binaria de los ejemplos sin cambiar sus formatos.

**Consecuencias y alcance pendiente:** Se cierra C02. C03 asignará resultados y códigos externos de `global_state`, retomando la dependencia de D05/DEC-ARCH-009; C04/C05/C06/C07 completarán reglas comunes, errores, plazos y perfil. Se conservan todas las políticas de aceptación, `reset`, exclusión, recuperación y sesión aprobadas. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa la asignación individual diferida por el acuerdo de códigos de un byte y la lista final de operaciones, sin asignar resultados ni estados.

### Acuerdo parcial de DEC-PROTO-001 — Códigos comunes de resultado

**Estado del acuerdo:** Aprobado como base de diseño. Tabla del segundo byte de respuesta aprobada; C03 permanece abierto únicamente por códigos externos de `global_state`. Errores restantes se concretarán en C05.

**Dominio:** Debug / Resultados binarios de solicitudes.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Los once resultados necesitan nombres y códigos comunes. El código de operación identifica la solicitud; el siguiente expresa aceptación, disponibilidad, éxito o fallo.

**Decisión:** El segundo byte de respuesta utiliza estos códigos:

| Código | Nombre definitivo    | Significado aprobado                                    |
|--------|----------------------|---------------------------------------------------------|
| 0x01   | `ACCEPTED`           | `LOAD`, `RUN` o `RESET` aceptado                        |
| 0x02   | `DONE`               | `LOAD` completado o ciclo `STEP` realizado              |
| 0x03   | `READY`              | Disponible para recibir `LOAD`, respuesta `CHECK_READY` |
| 0x04   | `BUSY`               | No disponible para la operación                         |
| 0x05   | `NO_IMAGE`           | No hay imagen válida para ejecutar                      |
| 0x06   | `INVALID_SIZE`       | Tamaño de `LOAD` inválido                               |
| 0x07   | `INCOMPLETE_REQUEST` | Solicitud `LOAD` recibida incompleta                    |
| 0x08   | `INCOMPLETE_DATA`    | Contenido del programa `LOAD` recibido incompleto       |
| 0x09   | `UART_ERROR`         | Error UART durante recepción de `LOAD`                  |
| 0x0A   | `FINISHED`           | `RUN` terminó normalmente por halt                      |
| 0x0B   | `FAULT`              | `RUN` terminó por fault de CPU                          |

La cabecera continúa siendo `[código de operación][resultado]`. La presencia y longitud de datos dependen de la operación y resultado ya aprobados. `DONE` de `LOAD` termina tras dos bytes; `DONE` de `STEP` agrega Debug. Un `STEP` efectivamente realizado conserva `DONE` incluso si confirma halt/fault o avanza drenado: `global_state` y causa/PC del snapshot describen su estado arquitectónico. Solo `RUN` usa `FINISHED`/`FAULT` como resultado terminal automático. `FAULT` es una terminación de CPU, distinta de `UART_ERROR` del transporte.

Correspondencia con las etiquetas descriptivas anteriores:

| Etiqueta anterior       | Etiqueta aprobada    |
|-------------------------|----------------------|
| ACEPTADA                | `ACCEPTED`           |
| COMPLETADA y COMPLETADO | `DONE`               |
| DISPONIBLE              | `READY`              |
| `NO_DISPONIBLE`         | `BUSY`               |
| `SIN_IMAGEN`            | `NO_IMAGE`           |
| `TAMAÑO_INVALIDO`       | `INVALID_SIZE`       |
| `SOLICITUD_INCOMPLETA`  | `INCOMPLETE_REQUEST` |
| `CONTENIDO_INCOMPLETO`  | `INCOMPLETE_DATA`    |
| `ERROR_UART`            | `UART_ERROR`         |
| FINALIZADA              | `FINISHED`           |

`FAULT` conserva nombre y significado. Los acuerdos históricos con esas etiquetas se interpretan mediante esta tabla.

Ejemplos de respuestas completas sin snapshot:

| Caso                        | Bytes   |
|-----------------------------|---------|
| `CHECK_READY` disponible    | `05 03` |
| `CHECK_READY` no disponible | `05 04` |
| Aceptación `LOAD`           | `01 01` |
| Carga completada            | `01 02` |
| Tamaño inválido             | `01 06` |
| Aceptación `RUN`            | `02 01` |
| `RUN` sin imagen            | `02 05` |
| `STEP` sin imagen           | `03 05` |
| Aceptación `RESET`          | `04 01` |

Respuestas con snapshot: `STEP` realizado `[03][02][snapshot]`, `RUN` normal `[02][0A][snapshot]` y `RUN` con fault `[02][0B][snapshot]`. Sus longitudes completas continúan siendo `230 + 5*used_count` bytes, incluidos los dos de cabecera.

No se asigna prioridad por el número de resultado ni se modifica la aceptación de solicitudes. `READY`/`BUSY` de `CHECK_READY` siguen expresando disponibilidad para `LOAD`, sin reserva ni garantía de imagen válida. Los códigos de estado del snapshot pertenecen a otro campo y se definirán a continuación.

**Justificación:** Una tabla compartida evita códigos redundantes para resultados equivalentes; el primer byte diferencia `LOAD` y `STEP`. Nombres en inglés mantienen consistencia con las operaciones y la separación de fallo de CPU/transporte permite interpretar cada respuesta sin un campo de motivo adicional.

**Consecuencias y alcance pendiente:** Resultados 0x01–0x0B quedan aprobados; se actualizan etiquetas en contratos actuales, conservando el historial. C03/D05 y DEC-ARCH-009 quedan pendientes solamente de códigos externos de `global_state`. C05 definirá errores fuera de `LOAD` y código desconocido, extendiendo el conjunto únicamente si se acuerda una respuesta adicional. C04/C06/C07 completan intercambios, esperas y perfil compartido. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-013`, `REQ-DBG-017`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Asigna códigos y nombres definitivos a los resultados aprobados, unifica las etiquetas de éxito `LOAD`/`STEP` en `DONE` y conserva sus formatos, efectos y reglas temporales.

### Acuerdo parcial de DEC-PROTO-001 — Códigos externos de global_state

**Estado del acuerdo:** Aprobado como base de diseño. Completa C03/D05 y la representación externa de DEC-ARCH-009.

**Dominio:** Debug / Estado global transmitido en el snapshot.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Los catorce estados de la FSM global requieren códigos externos de un byte para UART, independientes de su representación interna.

**Decisión:** `global_state` ocupa el primer byte del cuerpo del snapshot, offset cero después de los dos bytes de cabecera, con esta tabla:

| Código | Estado             |
|--------|--------------------|
| 0x00   | `NO_IMAGE`         |
| 0x01   | `LOADING`          |
| 0x02   | `PREPARING_READY`  |
| 0x03   | `READY`            |
| 0x04   | `RUNNING`          |
| 0x05   | `STEPPING`         |
| 0x06   | `HALT_DRAIN_AUTO`  |
| 0x07   | `HALT_DRAIN_STEP`  |
| 0x08   | `FAULT_DRAIN_AUTO` |
| 0x09   | `FAULT_DRAIN_STEP` |
| 0x0A   | `FINISHED`         |
| 0x0B   | `FAULT`            |
| 0x0C   | `PREPARING_RUN`    |
| 0x0D   | `PREPARING_STEP`   |

Son códigos de transporte; no imponen una codificación física a la FSM ni agregan estados o registros funcionales. Solicitudes, resultados y `global_state` ocupan campos diferentes. El lector usa la posición de cada byte para aplicar su tabla correspondiente, aunque sus valores numéricos coincidan.

Ejemplo: `STEP` que deja `STEPPING` comienza `03 02 05`: operación `STEP`, resultado `DONE` y `global_state` `STEPPING`. Si ese `STEP` alcanza `FINISHED`, comienza `03 02 0A`; si alcanza `FAULT`, `03 02 0B`. El resultado del `STEP` realizado sigue `DONE`, y el estado/causa/PC del snapshot indican terminación o fault. `RUN` terminado normalmente comienza `02 0A 0A`; `RUN` con fault, `02 0B 0B`. El resto del snapshot sigue su layout aprobado.

La tabla cubre todos los estados arquitectónicos, sin ampliar los momentos de transmisión: únicamente snapshots automáticos tras `STEP` y final `RUN`. Estados de carga/preparación y `RUN`/drain AUTO no adquieren un servicio adicional de captura por disponer de código. Causa/PC globales conservan su vigencia en `FAULT_DRAIN_AUTO`, `FAULT_DRAIN_STEP` y `FAULT`; el candidato `IF/ID` sigue separado.

**Justificación:** Códigos externos consecutivos y completos permiten interpretar inequívocamente la FSM y conservar el layout de un byte. El orden de la tabla sigue la lista arquitectónica existente.

**Consecuencias y alcance pendiente:** Se cierran C03 y D05; DEC-ARCH-009 queda aprobada al completar selección y representación externa de registros interetapa/contexto. Captura coherente y envío exclusivo siguen el contrato de D06. C04/C05/C06/C07 y la revisión/consolidación del protocolo permanecen pendientes, junto con puertos y realización de bloques. No se inicia implementación.

**Requisitos afectados:** `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa la dependencia de códigos externos de estado diferida a C03, conservando campos, longitudes, momentos de observación y semántica arquitectónica.

### Acuerdo parcial de DEC-PROTO-001 — Orden de intercambios y respuestas

**Estado del acuerdo:** Aprobado como base de diseño. C04 completo; errores básicos restantes, plazos y perfil en C05/C06/C07.

**Dominio:** Debug / Secuencia PC–FPGA y elegibilidad de solicitudes.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El protocolo admite una operación normal por vez, `CHECK_READY`/`RESET` durante `RUN`, respuestas completas sin intercalado y exclusión de solicitudes durante Debug.

**Decisión:** La PC mantiene una operación normal en curso por vez. `LOAD` continúa siendo un único intercambio a través de aceptación, envío de contenido y confirmación/fallo; `STEP` termina al recibir su única respuesta completa con Debug; `RESET` exige aceptación y el flujo posterior de consulta de disponibilidad ya aprobado. `CHECK_READY` termina con su respuesta completa de dos bytes. La PC no adelanta otra solicitud durante estos intercambios.

`RUN` es la excepción: después de `ACCEPTED` puede continuar ejecutando mientras su resultado final queda pendiente. Durante `RUNNING` y drains AUTO, PC puede solicitar `CHECK_READY` o `RESET` y espera la respuesta de esa solicitud antes de enviar otra. Se mantienen los rechazos `BUSY` de `LOAD`/`RUN`/`STEP` durante ejecución, sin cancelar ciclos CPU. Un `RESET` válidamente reconocido abandona el intercambio previo de `RUN`; PC deja de esperar su resultado y sigue el intercambio `RESET`/consulta. La CPU no se pausa anticipadamente por reconocer `RESET`: el `reset` global se solicita al terminar físicamente su aceptación conforme al contrato existente.

Cada respuesta se transmite completa antes de comenzar otra, incluido el Stop del último byte; no se intercalan cabeceras ni datos. `RUN` mantiene aceptación completa antes de resultado terminal. Si el resultado automático de `RUN` queda pendiente mientras se transmite una respuesta breve ya iniciada, esa respuesta se completa y luego se envía el resultado terminal con su Debug coherente. Se retiene el estado terminal durante la espera según D06. La realización física del arbitraje y los registros privados de respuesta se concretarán en diseño de bloques; no se agrega una cola de comandos al contrato.

La tabla siguiente consolida reglas aprobadas. Las fases del transporte prevalecen sobre la elegibilidad arquitectónica; `READY` en el estado CPU no habilita recepción de comandos mientras todavía se transmite una confirmación o Debug.

| Situación / fase                                                                | `LOAD`                                                | `RUN` / `STEP`                                         | `CHECK_READY`                            | `RESET` UART                                         |
|---------------------------------------------------------------------------------|-------------------------------------------------------|--------------------------------------------------------|------------------------------------------|------------------------------------------------------|
| Transporte disponible, `NO_IMAGE`                                               | Validar tamaño y aceptar si es correcto               | `NO_IMAGE`, dos bytes y sin Debug                      | `READY`, sin imagen válida implícita     | `ACCEPTED`; `reset` global después del último Stop   |
| Transporte disponible, `READY`/`STEPPING`/drains `STEP`/`FINISHED`/`FAULT`      | Validar tamaño y aceptar si es correcto               | Aceptar con la semántica arquitectónica ya definida    | `READY`, sin reserva de carga            | `ACCEPTED`; `reset` global después del último Stop   |
| `RUNNING` o drains AUTO, fuera de respuestas/Debug                              | `BUSY` tras recibir cabecera completa; no cancela CPU | `BUSY`, sin alterar CPU                                | `BUSY`, respuesta de dos bytes           | `ACCEPTED` y abandono del intercambio `RUN` anterior |
| Recepción de tamaño `LOAD`                                                      | Los cinco bytes son tamaño de la solicitud en curso   | No se interpretan comandos dentro del tamaño           | No se interpreta como comando            | No se interpreta como comando                        |
| Recepción de contenido `LOAD` aceptado                                          | Los siguientes N bytes son programa                   | No se interpretan comandos dentro del programa         | No se interpreta como comando            | No se interpreta como comando                        |
| Preparación `LOAD` y envío de su confirmación final                             | PC espera `DONE`; RX adicional se descarta            | RX adicional se descarta                               | RX adicional se descarta                 | RX adicional se descarta                             |
| Preparación `RUN`/`STEP` y respuesta inicial `RUN` o respuesta `STEP` pendiente | PC espera el intercambio correspondiente              | Sin segunda operación de PC ni preparación superpuesta | PC espera antes de otra solicitud normal | PC espera; conserva `reset` físico directo           |
| Transmisión de una respuesta breve                                              | PC espera completa                                    | PC espera completa; no se intercalan respuestas        | PC espera completa                       | PC espera completa                                   |
| Respuesta automática Debug pendiente o en transmisión                           | RX consumido/descartado, sin respuesta                | RX consumido/descartado, sin respuesta                 | RX consumido/descartado, sin respuesta   | RX consumido/descartado; PC lo envía después         |
| Recuperación RX por silencio                                                    | RX consumido/descartado                               | RX consumido/descartado                                | RX consumido/descartado, sin respuesta   | RX consumido/descartado, sin respuesta               |

La preparación `RUN`/`STEP` mantiene las políticas de sesión existentes. La tabla no define manejo de clientes que violen la secuencia durante respuestas breves o preparaciones ni agrega timeouts de ejecución. Las excepciones `RUN` se aplican durante ejecución efectiva, fuera de exclusión Debug. El botón físico conserva el `reset` directo en todas las fases y puede abortar una transmisión; la PC descarta cualquier respuesta Debug incompleta y abandona el intercambio previo al retomar el enlace.

**Justificación:** Una secuencia cooperativa y un único mensaje TX por vez permiten identificar respuestas por sus cabeceras y longitudes. `RUN` necesita una excepción para poder resetear un programa que no termina; Debug exige exclusión para conservar el estado observado. Reunir reglas de transporte y estado evita confundir disponibilidad arquitectónica con admisión mientras existe una respuesta en curso.

**Consecuencias y alcance pendiente:** C04 completo, sin nuevos comandos, prioridades globales ni estados CPU. Errores de código desconocido/UART fuera de `LOAD` quedan en C05; esperas y recuperación desde PC en C06; perfil compartido en C07. Puertos y FSM privadas de protocolo/UART/Loader/Debug permanecen en diseño de bloques. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-011`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida elegibilidad y exclusión de los acuerdos existentes; fija una operación normal por vez, excepción de `RUN` y serialización completa de respuestas.

### Acuerdo parcial de DEC-PROTO-001 — Errores básicos fuera de LOAD

**Estado del acuerdo:** Aprobado como base de diseño. C05 completo; esperas y recuperación desde PC en C06.

**Dominio:** Debug / Código desconocido y error UART al recibir una operación.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Un código desconocido no debe ejecutar operaciones. Se requiere respuesta de rechazo y recuperación ante error UART del código; `LOAD` mantiene su tratamiento y las demás solicitudes ocupan un byte.

**Decisión:** Cuando el receptor está interpretando códigos de operación y recibe correctamente un byte distinto de `LOAD`/`RUN`/`STEP`/`RESET`/`CHECK_READY`, envía `[byte recibido][UNKNOWN_COMMAND]`, exactamente dos bytes. `UNKNOWN_COMMAND` se agrega a la tabla común con código 0x0C, siguiente resultado libre. Ejemplo: código desconocido 0x06 responde `06 0C`. No se ejecuta una operación ni se altera imagen/sesión; si `RUN` ya ejecuta, continúa. La PC identifica este resultado como error de la solicitud y no como nuevo comando.

Ante error UART al recibir un código de operación fuera de `LOAD`, se descarta esa recepción y el RX pendiente, y se aplica la misma recuperación de R = 100 ms de silencio continuo: reinicio por actividad RX, final con línea en reposo, ningún byte en curso y FIFO RX vacía. Durante recuperación se consume/descarta RX sin interpretar comandos. No se emite una respuesta para esa recepción, porque no hay un código válido y confiable para identificarla. No se resetea la CPU, no se invalida la imagen ni se modifica la sesión como efecto del error; una ejecución `RUN` continúa y las respuestas TX existentes se conservan. Si coinciden error y byte recibido, ese byte no se interpreta como una solicitud válida.

`LOAD` conserva sus controles de solicitud/tamaño/contenido y `UART_ERROR` 0x09 con los efectos según aceptación ya definidos. `RUN`, `STEP`, `RESET` y `CHECK_READY` ocupan un byte sin parámetros: al recibirlo correctamente la solicitud está completa, por lo que no se agrega timeout para campos inexistentes. Una trama UART fallada corresponde al error físico, no a una solicitud parcialmente decodificada.

La respuesta `UNKNOWN_COMMAND` solo corresponde a un byte recibido válidamente en contexto de comandos. Durante tamaño/contenido `LOAD` los bytes son campos/datos, y durante recuperación, preparación/confirmación `LOAD` o envío exclusivo Debug rige el descarte ya aprobado; no se convierte un byte de esas fases en comando desconocido. Un error RX durante la exclusión Debug no modifica el estado observado ni intercala una respuesta en TX.

**Justificación:** Eco del byte desconocido y un resultado definido mantienen la cabecera común. Ante trama no confiable, descartar y esperar silencio evita atribuir una operación incorrecta o fabricar una respuesta. Los formatos de un byte hacen innecesario un timeout adicional de campos y conservan el alcance de una PC cooperativa de laboratorio.

**Consecuencias y alcance pendiente:** C05 completo; tabla de resultados extendida a 0x01–0x0C, conservando códigos anteriores. R se reutiliza fuera de `LOAD` solo en recepción de código con error UART; las políticas `LOAD` y Debug permanecen intactas. C06 fija plazos de recepción/reacción de PC, C07 perfil compartido y V01/V02/V03 revisión/consolidación. Puertos y FSM privadas quedan para diseño de bloques. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-001`, `REQ-UART-008`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-011`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa tratamiento de código desconocido/UART fuera de `LOAD` y extiende el enum de resultados con `UNKNOWN_COMMAND`, sin nuevos comandos ni cambios arquitectónicos.

### Acuerdo parcial de DEC-PROTO-001 — Perfil compartido de memoria y protocolo

**Estado del acuerdo:** Aprobado como base de diseño. C07 completo; revisión y consolidación pendientes en V01/V02/V03.

**Dominio:** Debug / Configuración común PC–FPGA.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Ambos extremos deben seleccionar el mismo perfil antes del enlace, con una tabla común de capacidades y códigos/layout estables, sin negociación UART adicional.

**Decisión:** Los perfiles comunes son `REFERENCE` por defecto (IMEM 1024 bytes, DMEM 2048 bytes) y `ALT_1000` (IMEM 1000 bytes, DMEM 1000 bytes). La fuente de capacidades es la [tabla de perfiles de la arquitectura de memoria](../architecture/memory/memory_architecture.md#perfiles-definidos), ya aprobada. El perfil se selecciona antes de usar el sistema y debe ser el mismo en la configuración de elaboración/síntesis FPGA y en la configuración PC del protocolo. Esta decisión no prescribe interfaz gráfica, CLI ni formato de archivo de configuración.

PC toma de esa tabla sus límites de `LOAD`, rango/cantidad de DMEM y cálculo de esperas dependientes de capacidad. FPGA usa las mismas capacidades para memorias y validadores. Los códigos de solicitud, resultado, `global_state`, anchos escalares, orden y longitud fija de Debug son únicos y no cambian entre perfiles; la cantidad variable de memoria depende de las escrituras de la sesión. Las ventanas de recuperación y límites de imagen se calculan con los parámetros del perfil.

`REFERENCE` es el perfil físico obligatorio; `ALT_1000` conserva el alcance de elaboración/simulación para verificar que no se asuman potencias de dos. No se exige desplegar `ALT_1000` en placa ni se agrega una consulta/negociación de capacidades, identificación de perfil en cada paquete o versión de protocolo. Ambos extremos cumplen la configuración acordada de antemano para el TP.

**Justificación:** Los perfiles existentes proporcionan capacidades compartidas y evitan constantes contradictorias en PC y FPGA. Layout/códigos únicos mantienen el intercambio y la interpretación iguales, con variación solo en los límites y tiempos que dependen de tamaño/capacidad.

**Consecuencias y alcance pendiente:** C07 completo. V01 revisará recorridos; V02 tablas, longitudes, códigos y tiempos; V03 consolidará `protocol.md` y cerrará DEC-PROTO-001 cuando no queden diferencias. Puertos/FSM privadas en DEC-SYS-007 y decisiones de aplicación/assembler en DEC-SYS-008/009 siguen pendientes. No se inicia implementación.

**Requisitos afectados:** `REQ-MEM-010`, `REQ-UART-002`, `REQ-UART-008`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-SW-004`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa configuración compartida de C07, conservando capacidades, alcance de perfiles y todas las decisiones de mensajes/recuperación.
