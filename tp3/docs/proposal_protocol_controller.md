# Protocol Controller — Diseño de la FSM

- **Tipo:** diseño de arquitectura y protocolo.
- **Estado:** diseño definido; implementación y pruebas de integración pendientes.
- **Seguimiento:** [Checklist de documentación](checklist_protocol_controller.md).

## Propósito y alcance

La FSM tiene **11 estados de control**, con salidas Mealy, para coordinar carga, ejecución, avance por pasos, respuestas, Debug, reset y recuperación RX. Los nombres de estados, señales y constantes se expresan en inglés. Las condiciones de las tablas usan pocos alias combinacionales con sus definiciones completas en este documento; mantienen visibles las decisiones de aceptación, selección de comandos y retención Debug.

El criterio de diseño es distinguir las situaciones que requieren un comportamiento presente o futuro diferente. Una acción combinacional no exige automáticamente un estado; compartir una espera tampoco elimina la necesidad de recordar su continuación.

La **Global FSM tiene 14 estados** y decide la elegibilidad de solicitudes, las prioridades y la autorización de ciclos CPU. El Protocol Controller determina la admisión UART y las respuestas conforme al contrato del protocolo.

El [protocolo UART](protocol.md) define los mensajes y las fases de operación. La [especificación del controlador](architecture/debug/protocol_controller.md) fija sus interfaces y decisiones por ciclo; este documento reúne los criterios que justifican ese diseño. La [checklist](checklist_protocol_controller.md) organiza su revisión documental.

## Contrato del protocolo

- La PC mantiene una operación normal en curso por vez y espera su respuesta completa antes de iniciar otra.
- Después de transmitir `RUN/ACCEPTED`, durante RUN efectivo se admite únicamente `RESET`.
- `LOAD`, otro `RUN`, `STEP` y `CHECK_READY` esperan hasta cerrar el intercambio de RUN, incluido Debug.
- La recuperación de PC puede intentar CHECK_READY sin conocer si RUN continúa. Esa consulta conserva el tratamiento fuera de fase si RUN sigue activo; ante su fallo se permite un único intento automático de RESET según el procedimiento siguiente.
- Durante aceptación, preparación y exclusión Debug, RX se consume y descarta sin interpretar nuevos comandos.
- Como tratamiento de tráfico fuera de fase, un byte distinto de `RESET` o un error UART durante RUN efectivo inicia `RECOVER_RX`, sin respuesta. Esto evita interpretar inmediatamente los bytes restantes de una solicitud inválida como comandos.
- Durante recuperación se descartan también `RESET` y las consultas; la CPU y TX pueden continuar según sus contratos.
- Si el terminal ya fue observado, su exclusión tiene prioridad sobre un nuevo RESET UART. Un RESET ya reconocido cancela la obligación terminal, aunque la CPU termine mientras se transmite su aceptación.
- El botón físico conserva su reset directo y puede abortar una transmisión.

### Recuperación de la aplicación PC

Fuera de LOAD, la PC intenta recuperar comunicación con CHECK_READY y, si esa consulta falla, envía una única solicitud automática RESET. Esa recuperación puede cancelar un RUN que seguía ejecutándose y perder la imagen cargada al aplicar el reset global. La PC informa que recurrió a reset y no reanuda automáticamente la operación anterior.

Una consulta durante RUN efectivo provoca `RECOVER_RX` sin respuesta. El único intento RESET permite intentar recuperar una ejecución no terminante; CHECK_READY no constituye una excepción de admisión durante RUN.

Las ventanas y los supuestos de transporte se definen en [la recuperación PC](protocol.md#esperas-y-recuperación-desde-pc): `W_debug(C)` de silencio continuo de RX en PC, 6100 ms en `REFERENCE` y 3400 ms en `ALT_1000`, y 200 ms desde el inicio del envío de la consulta o RESET hasta recibir su respuesta completa. El silencio se mide desde la última recepción o desde el comienzo de cada descarte; cada byte recibido reinicia la cuenta. Tras una desconexión, la cuenta comienza al retomar el enlace. La recuperación de LOAD utiliza `W_load(N)` y su procedimiento específico.

| Fase de la aplicación PC | Comportamiento |
|---|---|
| Descarte inicial | Abandonar el parcial y leer y descartar hasta completar `W_debug(C)` sin recibir bytes. Procesar primero cualquier dato pendiente en el lector; no vaciar buffers ni reiniciar el flujo al salir del descarte. |
| Consulta | Enviar un único CHECK_READY. Aceptar `05 03` o `05 04` como prefijo del flujo recibido, completos dentro de 200 ms desde el inicio del envío de la consulta. Si la respuesta es válida, dar por recuperada la comunicación sin solicitar RESET. |
| Consulta fallida sin datos recibidos | Al vencer los 200 ms, pasar al único intento de RESET. Respetar el silencio RX de la FPGA `R = 100 ms` desde la última transmisión de PC; el timeout de consulta lo cubre con los tiempos previstos del enlace. |
| Consulta fallida con datos recibidos | Ante otro opcode, resultado inválido o consulta incompleta al vencer el plazo, abandonar el parcial y volver al descarte por `W_debug(C)`. Cada recepción reinicia la cuenta. Después enviar RESET, sin volver a consultar CHECK_READY. Este camino cubre RUN que empieza a transmitir Debug mientras se esperaba la consulta. |
| Confirmación de RESET | Registrar que se consumió el único intento antes de enviarlo y aceptar `04 01` como prefijo del flujo recibido, completo dentro de 200 ms desde el inicio del envío de RESET. El mensaje completo confirma la aceptación; la FPGA aplica el reset después de su último Stop. La PC vuelve al flujo normal de una sesión reiniciada, sin repetir LOAD, RUN o STEP. |
| RESET sin aceptación válida | Si hay timeout, respuesta inválida, truncamiento o pérdida de enlace, informar que no se pudo confirmar la recuperación. No iniciar otra operación ni enviar automáticamente otra consulta o RESET dentro de ese episodio. Un nuevo intento requiere una acción explícita del usuario. |

En consulta y confirmación, las entregas fragmentadas del driver conservan su orden y fronteras. No se busca `05 03`, `05 04` ni `04 01` dentro de un cuerpo Debug o de bytes ya descartados. Los bytes pendientes al vencer un silencio se procesan antes de decidir el siguiente envío; los posteriores a una consulta válida se conservan para el lector normal. Una respuesta válida recupera comunicación, pero no reconstruye el estado de sesión perdido; un snapshot anterior sigue identificado como observación anterior.

Si RUN alcanza terminal después de enviar el RESET de recuperación y el terminal ya fue observado antes de reconocer ese comando, la prioridad terminal permite que RESET sea descartado y se transmita Debug. Ese intento no se repite automáticamente: sin RESET/ACCEPTED válido se informa fallo de recuperación. Por lo tanto, el procedimiento no interpreta el envío de RESET como confirmación de haber reiniciado.

Estas fases pertenecen a la aplicación PC. El Controller tiene 11 estados y la Global 14. La [checklist](checklist_protocol_controller.md#1-contrato-de-operación) identifica las tareas de documentación y pruebas pendientes.

## Estados de control

| State | Qué representa y por qué se distingue |
|---|---|
| `WAIT_COMMAND` | No hay operación ni respuesta en curso. RX se interpreta como opcode y el serializador está libre. |
| `RECEIVE_LOAD_SIZE` | Hay una cabecera LOAD incompleta. RX contiene bytes del tamaño; la imagen anterior todavía se conserva. |
| `WAIT_LOAD_ACCEPT_SENT` | LOAD fue aceptado, pero su aceptación todavía debe terminar físicamente antes de recibir contenido. |
| `RECEIVE_LOAD_DATA` | Hay una carga aceptada con bytes de programa pendientes. RX alimenta al Loader y se supervisa inactividad. |
| `WAIT_PREP_DONE` | IMEM ya fue escrita. Espera que la preparación de LOAD deje de estar activa, con la imagen ya publicada, antes de responder DONE. |
| `WAIT_STEP_END` | STEP fue aceptado, pero su ciclo todavía no ocurrió porque requiere preparación previa. |
| `WAIT_RUN_ACCEPT_SENT` | RUN fue aceptado. La CPU puede avanzar o terminar, pero ACCEPTED debe completarse antes del resultado. |
| `WAIT_RUN_END` | ACCEPTED ya fue transmitido y falta el terminal de RUN. RESET se admite cuando la preparación está inactiva. |
| `WAIT_RESPONSE_SENT` | Hay una respuesta corta o con Debug en transmisión, o falta entregar el terminal RUN después de completar ACCEPTED. El cierre de la respuesta final devuelve al contexto de comandos y libera la observación si `debug_hold` está activo. |
| `WAIT_RESET_ACCEPT_SENT` | RESET fue reconocido; solo después de terminar su aceptación se solicita reset global. |
| `RECOVER_RX` | Se perdió la alineación RX. Se descarta recepción hasta recuperar silencio y terminar respuestas y Debug pendientes. |

`WAIT_PREP_DONE` corresponde a LOAD. La preparación previa de STEP queda dentro de `WAIT_STEP_END`; la de RUN puede continuar después de su aceptación, dentro de `WAIT_RUN_END`, donde `prepare_active` impide admitir RESET hasta que termine.

### Memoria auxiliar

Los 11 nombres describen las fases del registro `protocol_state`, no la totalidad del estado almacenado del sistema.

| Register | Qué conserva |
|---|---|
| `run_result_required` | La obligación de entregar el resultado de un RUN aceptado. Se consume cuando el serializador captura FINISHED o FAULT con Debug, o se cancela al reconocer RESET. |
| `debug_hold` | La retención de la observación hasta completar físicamente Debug. |
| `load_size_received`, `size_byte_index`, `load_bytes_remaining` | Datos y progreso de recepción de LOAD. |
| `inactivity_count` | Inactividad durante recepción o silencio de recuperación. |
| `uart_reset_request` | Solicitud registrada de reset posterior al último Stop de su aceptación. |

`run_result_required` y `debug_hold` también son memoria de control, aunque estén fuera de `protocol_state`. Los contadores y el tamaño pertenecen al Protocol Controller; el Loader conserva el ensamblado parcial de palabras y realiza las escrituras de IMEM.

El Controller presenta opcode, resultado e indicador Debug directamente al serializador, que los captura en sus propios registros con `response_start`. El total de recursos registrados del Controller es 91 bits en `REFERENCE` y 90 en `ALT_1000`, con codificación one-hot de 11 bits.

### Invariantes de las fases

- En `WAIT_COMMAND`, el serializador está libre, no hay obligación RUN ni retención Debug y no hay preparación activa. Esto forma parte del significado del estado; los alias no sustituyen ni alteran esas invariantes.
- En `RECEIVE_LOAD_SIZE`, `RECEIVE_LOAD_DATA`, `WAIT_PREP_DONE` y `WAIT_STEP_END`, el serializador está libre. No existe un RUN pendiente ni otra respuesta que compita por su captura.
- Al entrar en `WAIT_PREP_DONE`, la Global entra simultáneamente en `PREPARING_READY` por la última escritura del Loader, por lo que `prepare_active` ya está activo después de ese flanco. Dentro de esta espera, su desactivación indica preparación terminada e imagen publicada; no se confunde con una preparación todavía no iniciada. Reset reinicia ambas FSM.
- En `WAIT_STEP_END`, la Global está en `PREPARING_STEP` hasta autorizar el ciclo solicitado. En este contexto `cpu_cycle_fire` implica preparación completada; el Controller no necesita comprobar `prepare_done` por separado.
- En `WAIT_RUN_END`, RUN/ACCEPTED ya terminó y el serializador está libre. La preparación RUN puede seguir activa y determina cuándo se admite RESET.
- En `WAIT_RESPONSE_SENT`, una respuesta normal ya fue capturada por el serializador. La excepción es el terminal RUN observado antes de completar ACCEPTED: después de ese último Stop, puede quedar un ciclo con el serializador libre y `run_result_required` activo hasta entregar el terminal en el flanco siguiente.
- En `WAIT_RESPONSE_SENT`, `debug_hold` distingue la observación retenida para Debug de la respuesta corta. La retención abarca también la espera previa a entregar el terminal RUN y se conserva hasta el último Stop de Debug.
- En `RECOVER_RX`, una retención Debug activa corresponde a la respuesta Debug. La aceptación RUN ya terminó antes de admitir el tráfico que originó esa recuperación; LOAD tampoco se superpone con RUN. Por eso `response_done_tick && debug_hold` puede limpiar la retención en esta fase.
- Toda activación de `response_start` ocurre con `response_busy == 0` antes del flanco. Las fases garantizan esa disponibilidad para respuestas normales; la entrega del terminal RUN la comprueba explícitamente.

## Entradas y salidas

Se distinguen los puertos del Protocol Controller de las conexiones internas entre su lógica de control y sus registros. El Controller utiliza `rx_activity` para recuperación RX, `prepare_active` para reconocer el fin de preparación LOAD y `cpu_cycle_fire` para el ciclo STEP. Session Preparation entrega `prepare_done` a la Global; el Loader entrega `load_ok` a la Global para iniciar preparación después de la última escritura.

Todas las señales sin ancho indicado son de un bit, salvo `protocol_state` y `next_state`, que representan una de las 11 fases. Los anchos parametrizados son `IMAGE_SIZE_WIDTH = max(1, ceil(log2(IMEM_CAPACITY_BYTES + 1)))` y `BYTE_ADDRESS_WIDTH = max(1, ceil(log2(IMEM_CAPACITY_BYTES)))`. `IMEM_CAPACITY_BYTES` es un parámetro de configuración, usado para validar el tamaño, no un evento de entrada.

### Entradas desde otros módulos

| Entrada | Origen | Significado |
|---|---|---|
| `clk` | Distribución del clock funcional | Flanco positivo común que actualiza la FSM y sus recursos. |
| `reset` | Integración y acondicionamiento del reset global | Reinicia la fase y los recursos; tiene prioridad sobre las acciones normales. |
| `r_data[7:0]` | UART, salida de la FIFO RX | Byte disponible en la cabecera de la FIFO. Se interpreta como comando, tamaño o contenido según la fase, o se descarta. Solo es válido si `rx_empty == 0`. |
| `rx_empty` | UART, FIFO RX | Indica que no hay un byte disponible para retirar. |
| `rx_error_tick` | UART, receptor RX | Evento de error de recepción. Prevalece sobre la interpretación o entrega de un byte del mismo ciclo. |
| `rx_activity` | UART, detección de actividad RX | Indica cambio de nivel, línea baja o trama en curso. Reinicia el contador de silencio en recuperación. No reinicia el timeout de LOAD. |
| `response_busy` | Response Serializer | Indica que el serializador está ocupado y no puede aceptar otro descriptor. |
| `response_done_tick` | Response Serializer | Evento de fin físico de la respuesta completa, incluido el último Stop y Debug si corresponde. La fase permite identificar qué respuesta terminó. |
| `load_available` | Execution Control, Global FSM | Indica disponibilidad de la sesión para aceptar LOAD. Determina READY o BUSY al responder CHECK_READY. |
| `prepare_active` | Execution Control, Global FSM | Indica preparación de sesión activa. Su desactivación en `WAIT_PREP_DONE` permite generar LOAD/DONE con la imagen ya publicada. También impide admitir RESET en `WAIT_RUN_END` hasta que termine la preparación. |
| `program_finished` | Execution Control, Global FSM | Indica terminal normal de ejecución, con el pipeline vacío. Conserva el resultado RUN/FINISHED hasta que pueda entregarse al serializador. |
| `fault_terminal` | Execution Control, Global FSM | Indica terminal por fault, con el pipeline vacío. Conserva el resultado RUN/FAULT hasta que pueda entregarse al serializador. |
| `image_valid` | Execution Control, tamaño confirmado de imagen | Indica que existe una imagen válida; se deriva de `loaded_image_size_bytes != 0`. Distingue NO_IMAGE de BUSY ante rechazo de RUN o STEP. |
| `command_accepted` | Execution Control, Global FSM | Aceptación combinacional de la solicitud presentada. Se consume en el mismo flanco; sin solicitud activa, su valor no constituye un evento. |
| `cpu_cycle_fire` | Execution Control, Global FSM | Habilita un ciclo CPU efectivo. En el contexto STEP identifica el flanco de su único ciclo y la retención de la observación para Debug. |

`rx_activity` incluye internamente `rx_receiving`: si RX está recibiendo una trama, hay actividad. Por eso `!rx_activity` ya garantiza línea alta, sin cambios detectados y sin trama en curso. `rx_receiving` conserva su función dentro de UART, pero el Controller no necesita recibirla por separado.

`prepare_done` conserva su conexión desde Session Preparation hacia la Global FSM. La Global publica la imagen y sale de `PREPARING_READY` al consumir ese evento; después del flanco baja `prepare_active`. El Controller observa esa desactivación y entrega LOAD/DONE al serializador en el flanco siguiente. Para STEP, la Global genera `cpu_cycle_fire` en el propio flanco que completa la preparación y ejecuta el ciclo pendiente.

`load_ok` conecta el Loader con la Global FSM, que la consume para iniciar `PREPARING_READY`. El Controller identifica la última entrega mediante `load_bytes_remaining` y pasa directamente a `WAIT_PREP_DONE`. El contrato del Loader establece que entregar el último byte válido completa la última palabra y produce `load_ok` en ese mismo flanco.

### Entradas desde recursos internos

Estas conexiones permiten a la lógica combinacional decidir el próximo estado y sus acciones; no agregan puertos al módulo.

| Entrada | Origen | Significado |
|---|---|---|
| `protocol_state` | Registro de fase | Fase actual del protocolo; determina cómo interpretar los eventos y bytes recibidos. |
| `load_size_received[39:0]` | Registro de tamaño recibido | Conserva los cinco bytes del tamaño. Antes de capturar el quinto, se combina con `r_data` para validar y presentar el tamaño completo. |
| `size_byte_index[2:0]` | Registro de índice de tamaño | Selecciona el byte de tamaño que se recibe, de cero a cuatro. |
| `load_bytes_remaining[IMAGE_SIZE_WIDTH-1:0]` | Contador de bytes pendientes | Cantidad de bytes de programa aún no entregados al Loader. Identifica la última entrega y permite calcular su desplazamiento. |
| `inactivity_count[22:0]` | Contador de inactividad/silencio | Cuenta hasta `4999999`, con saturación. Detecta timeout de LOAD o silencio suficiente para recuperar RX. |
| `run_result_required` | Registro de obligación RUN | Indica que un RUN aceptado todavía debe producir su respuesta terminal. Se conserva durante recuperación. |
| `debug_hold` | Registro de retención Debug | Indica que la observación debe permanecer retenida hasta el fin físico de Debug. |

### Salidas hacia otros módulos

| Salida | Destino | Significado |
|---|---|---|
| `rd_uart` | UART, FIFO RX | Retira el byte disponible. Se activa con `!reset && !rx_empty`; la fase decide si se procesa o se descarta. |
| `response_start` | Response Serializer | Solicita la captura de los campos de respuesta presentados directamente por el Controller. Se activa con el serializador libre y sus campos estables antes del flanco. |
| `response_opcode[7:0]` | Response Serializer | Opcode seleccionado combinacionalmente para la respuesta. Se captura con `response_start`. |
| `response_result[7:0]` | Response Serializer | Resultado seleccionado combinacionalmente para la respuesta. Se captura con `response_start`. |
| `response_with_debug` | Response Serializer | Control de formato decidido por el Controller: uno incluye Debug y cero selecciona una respuesta corta. Se captura con `response_start`. |
| `load_request` | Execution Control, Global FSM | Solicita LOAD al recibir el quinto byte de un tamaño válido. No depende de `command_accepted`; ambas FSM consumen solicitud y aceptación en el mismo flanco. |
| `run_request` | Execution Control, Global FSM | Solicita RUN al reconocer su opcode en `WAIT_COMMAND`, incluso si luego se rechaza por estado de sesión o falta de imagen. |
| `step_request` | Execution Control, Global FSM | Solicita STEP al reconocer su opcode en `WAIT_COMMAND`, incluso si luego se rechaza por estado de sesión o falta de imagen. |
| `load_size_bytes[IMAGE_SIZE_WIDTH-1:0]` | Loader; mediante su alias, Execution Control | Tamaño validado de la imagen. En el flanco de aceptación incluye el quinto byte actual; después se mantiene hasta la publicación de la imagen. |
| `load_byte_valid` | Loader | Habilita la entrega de un byte de programa en `RECEIVE_LOAD_DATA` y, en ese mismo flanco, decrementa `load_bytes_remaining` dentro del Controller. No se activa ante reset o error UART. |
| `load_byte_data[7:0]` | Loader | Byte de programa a entregar; presenta `r_data` y se consume con `load_byte_valid`. |
| `load_byte_offset[BYTE_ADDRESS_WIDTH-1:0]` | Loader | Desplazamiento del byte dentro de la imagen, calculado como tamaño menos bytes pendientes antes del flanco de entrega. |
| `load_last_byte` | Loader | Identifica la última entrega válida, con `load_bytes_remaining == 1` antes del flanco. |
| `load_abort` | Loader | Aborta una recepción de contenido por error UART o timeout. El Loader prioriza el aborto sobre la escritura y genera `load_fail` hacia la Global FSM. |
| `uart_reset_request` | Integración y acondicionamiento del reset global | Solicitud registrada después de completar físicamente RESET/ACCEPTED. El reset distribuido posterior reinicia el sistema y limpia la solicitud. |
| `debug_read_select` | Mux de dirección del primer puerto de lectura de RF y selector de dirección de lectura CPU/Debug de DMEM | Selecciona las direcciones de Debug en ambos módulos durante la retención o al observar un terminal RUN pendiente. No habilita escrituras. |

La integración distribuye `debug_read_select` a ambos selectores de lectura. RF y DMEM permanecen seleccionados para Debug durante la misma ventana, aunque el serializador recorra sus datos en etapas diferentes. Cada selector conserva sus propias direcciones CPU y Debug; la señal común solo elige cuál utilizar.

`load_start` y `loader_active` pertenecen a la conexión Global FSM → Loader. El Controller tampoco recibe `load_fail`, `global_state_code` ni los eventos TX por byte: coordina las respuestas mediante `response_busy` y `response_done_tick`.

### Salidas de control hacia recursos internos

Son órdenes combinacionales de la FSM. Cada recurso realiza su actualización en el flanco habilitado; sin una orden aplicable conserva su valor.

| Salida | Destino | Significado |
|---|---|---|
| `next_state` | Registro `protocol_state` | Fase que se registrará en el próximo flanco; por defecto conserva la actual. |
| `size_init` | Registros `load_size_received` y `size_byte_index` | Inicializa tamaño e índice al reconocer LOAD. |
| `size_byte_capture` | Registro `load_size_received` | Captura `r_data` en la posición seleccionada por `size_byte_index`. |
| `size_index_inc` | Registro `size_byte_index` | Avanza al siguiente byte del tamaño cuando el índice actual es menor que cuatro. |
| `remaining_load` | Contador `load_bytes_remaining` | Carga el tamaño completo validado al aceptar LOAD, incluido el quinto byte recibido en ese flanco. |
| `timer_clear` | Contador `inactivity_count` | Reinicia la cuenta. Tiene prioridad sobre `timer_inc`. |
| `timer_inc` | Contador `inactivity_count` | Incrementa la cuenta sin superar `4999999`. |
| `run_result_required_set` | Registro `run_result_required` | Registra que un RUN aceptado debe responder su terminal. |
| `run_result_required_clear` | Registro `run_result_required` | Consume la obligación cuando el serializador captura el terminal RUN o la cancela al reconocer RESET. Detectar el terminal por sí solo no limpia la marca. |
| `debug_hold_set` | Registro `debug_hold` | Activa retención al realizar STEP o al observar el terminal de un RUN pendiente. |
| `debug_hold_clear` | Registro `debug_hold` | Libera la retención después del fin físico de la respuesta Debug. |
| `reset_request_set` | Registro `uart_reset_request` | Registra la solicitud de reset después del último Stop de RESET/ACCEPTED. |

Además, `load_byte_valid` decrementa `load_bytes_remaining`, incluida la última entrega que lo lleva a cero. El Loader acepta cada entrega sin backpressure, por lo que ese evento representa también el avance de recepción.

Las órdenes de acción y los campos `response_*` seleccionados son combinacionales. El serializador registra el descriptor al aceptar `response_start`. `uart_reset_request` sigue siendo una salida registrada del Controller. Los campos de datos se muestran en una columna separada de las habilitaciones y controles de formato.

## Convenciones de las tablas

| Constant | Value |
|---|---|
| `OP_LOAD` | `0x01` |
| `OP_RUN` | `0x02` |
| `OP_STEP` | `0x03` |
| `OP_RESET` | `0x04` |
| `OP_CHECK_READY` | `0x05` |

- `Mealy Control Outputs` enumera únicamente las habilitaciones, selecciones y controles de formato que valen uno en esa condición. Se escribe solo su nombre; los controles omitidos valen cero, salvo los activados por una acción común aplicable.
- `Mealy Data Outputs` indica los valores presentados en buses de opcode, resultado, tamaño, byte o posición cuando la fila habilita su uso. `=` representa un valor combinacional presentado, no una escritura directa en un registro.
- Al entregar una respuesta, `response_start` aparece como orden de control, `response_with_debug` como control de formato y `response_opcode` y `response_result` como datos. El serializador captura los tres campos en el mismo flanco con `response_busy == 0`; la transmisión física continúa después.
- Las demás órdenes de control valen cero, salvo las acciones comunes que correspondan. Los datos solo se consumen con su habilitación; fuera de ella no ordenan actualizaciones.
- `—` significa que la fila no agrega salidas particulares de esa clase. Las conexiones de datos permanentes y las acciones comunes siguen vigentes.
- `ANY` representa cualquier estado; `NEXT_STATE` es el destino ya determinado por la tabla principal. Son metanotación, no estados adicionales.
- `reset` tiene prioridad absoluta: lleva a `WAIT_COMMAND`, reinicia los recursos y suprime todas las acciones normales, incluidas las comunes. Las demás filas se evalúan únicamente con `reset == 0`; se omite `!reset` de esas condiciones para evitar repetir esta regla. Las ecuaciones de salidas conservan la inhibición explícita durante reset.
- Por defecto, `next_state = protocol_state`; sin una condición aplicable se conserva el estado y, sin orden de actualización, cada recurso conserva sus datos.
- La FSM captura el próximo estado en cada flanco positivo del clock funcional. `cpu_cycle_fire` habilita recursos CPU, no el clock del controlador UART.
- `response_done_tick` corresponde al fin físico de la respuesta, incluido el último Stop.
- `inactivity_count` cuenta de cero a `4999999` y satura. Se mantiene el plazo de 5.000.000 clocks y la prioridad error UART > byte válido > timeout.

### Entrega directa y disponibilidad del serializador

El Controller decide opcode, resultado e inclusión de Debug. Cuando activa `response_start`, el serializador captura esos campos en sus propios registros y pasa a estar ocupado después del flanco. La entrega no equivale a completar la transmisión: los estados de espera siguen usando `response_done_tick`.

Las respuestas normales encuentran al serializador libre por las siguientes invariantes de fase:

| Fase que genera la respuesta | Por qué está libre |
|---|---|
| `WAIT_COMMAND` | Solo se llega después de terminar el intercambio anterior o de completar recuperación sin respuestas activas. |
| `RECEIVE_LOAD_SIZE` | Recibir el opcode LOAD inicia la cabecera sin producir una respuesta previa. No hay otro RUN ni comando concurrente. |
| `RECEIVE_LOAD_DATA` | LOAD/ACCEPTED terminó físicamente antes de habilitar la recepción del programa. |
| `WAIT_PREP_DONE` | Después de LOAD/ACCEPTED no se produjo otra respuesta; se completan contenido y preparación antes de emitir DONE. |
| `WAIT_STEP_END` | STEP aceptado con preparación no produce una aceptación separada; su única respuesta espera el ciclo CPU. |
| `WAIT_RUN_END`, para RESET | RUN/ACCEPTED ya terminó y todavía no se inició el resultado terminal. Un terminal ya observado tiene prioridad sobre RESET. |

El único resultado que puede aparecer con el serializador ocupado es FINISHED o FAULT de un RUN cuyo ACCEPTED todavía se transmite. En ese caso:

1. La Global conserva su estado terminal y el Controller mantiene `run_result_required` activo.
2. La observación se retiene desde la detección del terminal, sin esperar a que termine ACCEPTED.
3. Al terminar ACCEPTED, se espera hasta que `response_busy == 0` antes del flanco de entrega. No se acepta otra solicitud en el propio flanco del último Stop, porque el serializador todavía está ocupado antes de ese flanco.
4. Se presentan `OP_RUN`, `FINISHED` o `FAULT` y `response_with_debug = 1`, junto con `response_start` y `run_result_required_clear`.
5. El serializador conserva esos campos durante el envío; `debug_hold` se libera al completar físicamente Debug.

Un RESET reconocido previamente cancela la obligación RUN. El reset físico puede abortar cualquier fase y reinicia también al serializador. Fuera de reset, ningún productor de respuesta normal compite con el terminal RUN, por las fases y reglas de admisión del protocolo. Por eso el Controller puede consumir incluso un opcode desconocido y entregarlo al serializador en ese mismo flanco sin almacenarlo antes.

### Alias de las condiciones

Estos nombres representan lógica combinacional derivada de señales y registros existentes. No agregan registros, puertos ni ciclos. La tabla de transiciones indica el estado de origen y conserva explícitos los comandos, la aceptación y las condiciones de retención.

El alias de datos `load_size_candidate` tiene 40 bits unsigned e incluye el byte actual antes de su captura:

```systemverilog
load_size_candidate = {r_data, load_size_received[31:0]};
```

| Alias booleano | Definición completa | Significado |
|---|---|---|
| `rx_byte_valid` | `!rx_empty && !rx_error_tick` | Hay un byte disponible que puede interpretarse o entregarse según la fase. |
| `run_ended` | `program_finished \|\| fault_terminal` | La CPU alcanzó un terminal normal o por fault. Por sí solo no indica que se deba una respuesta RUN. |
| `last_size_byte` | `size_byte_index == 4` | El byte actual ocupa la quinta y última posición del campo tamaño, cuando hay un byte válido en `RECEIVE_LOAD_SIZE`. |
| `load_size_valid` | `load_size_candidate > 0 && load_size_candidate <= IMEM_CAPACITY_BYTES && load_size_candidate[1:0] == 0` | El tamaño completo es no nulo, cabe en IMEM y es múltiplo de cuatro. Se utiliza al recibir el quinto byte válido. |
| `timer_limit_reached` | `inactivity_count == 4999999` | El contador alcanzó su límite. |

`!response_busy` indica directamente que el serializador está libre. La obligación de entregar un terminal RUN se comprueba por separado con `run_result_required`. Dentro del rango saturado `0..4999999`, `!timer_limit_reached` equivale a `inactivity_count < 4999999`. El índice de tamaño y los cuarenta bits del tamaño candidato se evalúan antes del flanco; el alias no introduce una etapa de validación posterior.

Los errores UART se comprueban por separado: `!rx_byte_valid` también puede significar error, por lo que no sustituye a `rx_empty && !rx_error_tick` en las ramas de timeout. El consumo o descarte común de RX sigue dependiendo de `!rx_empty`, incluso cuando el byte no puede interpretarse.

### Timeout de LOAD y silencio de recuperación

El contador se reutiliza en fases diferentes; cada fase mide una condición distinta.

| Uso | Fases | Qué reinicia la cuenta | Qué permite avanzar la cuenta |
|---|---|---|---|
| Timeout entre bytes de LOAD | `RECEIVE_LOAD_SIZE`, `RECEIVE_LOAD_DATA` | Cada byte válido mientras falten bytes; el último cierra la fase. Un error UART inicia recuperación. | Ausencia de byte disponible y de error UART. La actividad de línea o una trama en curso no extienden este plazo. |
| Silencio de recuperación | `RECOVER_RX` | `rx_activity`: cambio de nivel, línea baja o trama en curso. | `!rx_activity`. Para salir se exige además el plazo completo, FIFO RX vacía y las condiciones de respuestas y Debug de la tabla principal. |

### Generación de solicitudes

Las solicitudes se calculan antes de consultar `command_accepted`; su generación no depende de la aceptación. En la tabla figuran tanto en la rama aceptada como en la rechazada.

```systemverilog
run_request =
    !reset
    && protocol_state == WAIT_COMMAND
    && rx_byte_valid
    && r_data == OP_RUN;

step_request =
    !reset
    && protocol_state == WAIT_COMMAND
    && rx_byte_valid
    && r_data == OP_STEP;

load_request =
    !reset
    && protocol_state == RECEIVE_LOAD_SIZE
    && rx_byte_valid
    && last_size_byte
    && load_size_valid;
```

### Datos y órdenes sobre recursos

- `size_init` pone en cero el tamaño recibido y su índice. `size_byte_capture` captura `r_data` en el byte seleccionado; `size_index_inc` incrementa el índice.
- `size_byte_capture` utiliza directamente la entrada `r_data`; captura, incremento, decremento y limpieza son órdenes a recursos cuya lógica realiza esas operaciones. No requieren representar sus resultados aritméticos como nuevos buses de la FSM.
- El quinto byte se concatena con los cuatro bytes ya registrados para formar el tamaño completo unsigned de 40 bits. Las comparaciones se realizan antes de reducir su ancho.
- Al aceptar LOAD en ese mismo flanco, `remaining_load` y `load_size_bytes` usan ese tamaño completo, incluido el quinto byte actual, mediante el camino combinacional correspondiente. Después se mantiene el tamaño capturado hasta la publicación de la imagen.
- `load_byte_valid` habilita la entrega al Loader y el decremento de `load_bytes_remaining`. `load_byte_data` presenta `r_data`; `load_byte_offset` se deriva del tamaño menos los faltantes previos al flanco.
- `response_start` habilita la captura de `response_opcode`, `response_result` y `response_with_debug` en el serializador. Para el terminal RUN, esa aceptación también activa `run_result_required_clear`; para las demás respuestas, la marca RUN sigue su regla propia.
- `timer_clear` pone en cero el temporizador; `timer_inc` incrementa dentro de su rango. La limpieza tiene prioridad sobre el incremento.
- `run_result_required_set` y `run_result_required_clear` actualizan `run_result_required`; `debug_hold_set` y `debug_hold_clear` actualizan `debug_hold`.
- `reset_request_set` registra `uart_reset_request`; el reset distribuido posterior reinicia el sistema.
- `response_opcode`, `response_result` y `response_with_debug` son valores combinacionales seleccionados en la misma condición que `response_start`. Una vez capturados por el serializador, el Controller puede cambiar esos buses sin alterar el mensaje en curso.
- Las tablas muestran `load_size_bytes` en las filas que presentan LOAD, `load_byte_data` y `load_byte_offset` en las entregas válidas, y los campos `response_*` al entregar una respuesta. Los datos solo son significativos cuando se habilita su consumo; no agregan una captura intermedia en el Controller.
- El tamaño validado se reduce a `IMAGE_SIZE_WIDTH` después de comprobar los cuarenta bits. La resta para `load_byte_offset` se realiza con `IMAGE_SIZE_WIDTH` y su resultado válido se presenta con `BYTE_ADDRESS_WIDTH`, usando el número de bytes restantes anterior al flanco.

## Tabla principal de transiciones y salidas Mealy

| Source state | Destination state | Boolean condition | Mealy Control Outputs | Mealy Data Outputs |
|---|---|---|---|---|
| `ANY` | `WAIT_COMMAND` | `reset` | — | — |
| `WAIT_COMMAND` | `RECOVER_RX` | `rx_error_tick` | `timer_clear` | — |
| `WAIT_COMMAND` | `RECEIVE_LOAD_SIZE` | `rx_byte_valid && r_data == OP_LOAD` | `size_init; timer_clear` | — |
| `WAIT_COMMAND` | `WAIT_RUN_ACCEPT_SENT` | `rx_byte_valid && r_data == OP_RUN && command_accepted` | `run_request; run_result_required_set; response_start` | `response_opcode = OP_RUN; response_result = ACCEPTED` |
| `WAIT_COMMAND` | `WAIT_RESPONSE_SENT` | `rx_byte_valid && r_data == OP_RUN && !command_accepted` | `run_request; response_start` | `response_opcode = OP_RUN; response_result = image_valid ? BUSY : NO_IMAGE` |
| `WAIT_COMMAND` | `WAIT_RESPONSE_SENT` | `rx_byte_valid && r_data == OP_STEP && command_accepted && cpu_cycle_fire` | `step_request; debug_hold_set; response_start; response_with_debug` | `response_opcode = OP_STEP; response_result = DONE` |
| `WAIT_COMMAND` | `WAIT_STEP_END` | `rx_byte_valid && r_data == OP_STEP && command_accepted && !cpu_cycle_fire` | `step_request` | — |
| `WAIT_COMMAND` | `WAIT_RESPONSE_SENT` | `rx_byte_valid && r_data == OP_STEP && !command_accepted` | `step_request; response_start` | `response_opcode = OP_STEP; response_result = image_valid ? BUSY : NO_IMAGE` |
| `WAIT_COMMAND` | `WAIT_RESET_ACCEPT_SENT` | `rx_byte_valid && r_data == OP_RESET` | `run_result_required_clear; response_start` | `response_opcode = OP_RESET; response_result = ACCEPTED` |
| `WAIT_COMMAND` | `WAIT_RESPONSE_SENT` | `rx_byte_valid && r_data == OP_CHECK_READY` | `response_start` | `response_opcode = OP_CHECK_READY; response_result = load_available ? READY : BUSY` |
| `WAIT_COMMAND` | `WAIT_RESPONSE_SENT` | `rx_byte_valid && !(r_data >= OP_LOAD && r_data <= OP_CHECK_READY)` | `response_start` | `response_opcode = r_data; response_result = UNKNOWN_COMMAND` |
| `RECEIVE_LOAD_SIZE` | `RECOVER_RX` | `rx_error_tick` | `timer_clear; response_start` | `response_opcode = OP_LOAD; response_result = UART_ERROR` |
| `RECEIVE_LOAD_SIZE` | `RECEIVE_LOAD_SIZE` | `rx_byte_valid && size_byte_index < 4` | `size_byte_capture; size_index_inc; timer_clear` | — |
| `RECEIVE_LOAD_SIZE` | `WAIT_RESPONSE_SENT` | `rx_byte_valid && last_size_byte && !load_size_valid` | `size_byte_capture; response_start` | `response_opcode = OP_LOAD; response_result = INVALID_SIZE` |
| `RECEIVE_LOAD_SIZE` | `WAIT_LOAD_ACCEPT_SENT` | `rx_byte_valid && last_size_byte && load_size_valid && command_accepted` | `size_byte_capture; load_request; remaining_load; response_start` | `response_opcode = OP_LOAD; response_result = ACCEPTED; load_size_bytes = load_size_candidate[IMAGE_SIZE_WIDTH-1:0]` |
| `RECEIVE_LOAD_SIZE` | `WAIT_RESPONSE_SENT` | `rx_byte_valid && last_size_byte && load_size_valid && !command_accepted` | `size_byte_capture; load_request; response_start` | `response_opcode = OP_LOAD; response_result = BUSY; load_size_bytes = load_size_candidate[IMAGE_SIZE_WIDTH-1:0]` |
| `RECEIVE_LOAD_SIZE` | `RECOVER_RX` | `rx_empty && !rx_error_tick && timer_limit_reached` | `timer_clear; response_start` | `response_opcode = OP_LOAD; response_result = INCOMPLETE_REQUEST` |
| `RECEIVE_LOAD_SIZE` | `RECEIVE_LOAD_SIZE` | `rx_empty && !rx_error_tick && !timer_limit_reached` | `timer_inc` | — |
| `WAIT_LOAD_ACCEPT_SENT` | `RECEIVE_LOAD_DATA` | `response_done_tick` | `timer_clear` | — |
| `RECEIVE_LOAD_DATA` | `RECOVER_RX` | `rx_error_tick` | `load_abort; timer_clear; response_start` | `response_opcode = OP_LOAD; response_result = UART_ERROR` |
| `RECEIVE_LOAD_DATA` | `RECEIVE_LOAD_DATA` | `rx_byte_valid && load_bytes_remaining > 1` | `load_byte_valid; timer_clear` | `load_byte_data = r_data; load_byte_offset = load_size_bytes - load_bytes_remaining` |
| `RECEIVE_LOAD_DATA` | `WAIT_PREP_DONE` | `rx_byte_valid && load_bytes_remaining == 1` | `load_byte_valid; load_last_byte` | `load_byte_data = r_data; load_byte_offset = load_size_bytes - load_bytes_remaining` |
| `RECEIVE_LOAD_DATA` | `RECOVER_RX` | `rx_empty && !rx_error_tick && timer_limit_reached` | `load_abort; timer_clear; response_start` | `response_opcode = OP_LOAD; response_result = INCOMPLETE_DATA` |
| `RECEIVE_LOAD_DATA` | `RECEIVE_LOAD_DATA` | `rx_empty && !rx_error_tick && !timer_limit_reached` | `timer_inc` | — |
| `WAIT_PREP_DONE` | `WAIT_RESPONSE_SENT` | `!prepare_active` | `response_start` | `response_opcode = OP_LOAD; response_result = DONE` |
| `WAIT_STEP_END` | `WAIT_RESPONSE_SENT` | `cpu_cycle_fire` | `debug_hold_set; response_start; response_with_debug` | `response_opcode = OP_STEP; response_result = DONE` |
| `WAIT_RUN_ACCEPT_SENT` | `WAIT_RUN_END` | `response_done_tick && !run_ended` | — | — |
| `WAIT_RUN_ACCEPT_SENT` | `WAIT_RESPONSE_SENT` | `response_done_tick && run_ended` | — | — |
| `WAIT_RUN_END` | `WAIT_RESPONSE_SENT` | `run_ended` | — | — |
| `WAIT_RUN_END` | `WAIT_RESET_ACCEPT_SENT` | `!run_ended && !prepare_active && rx_byte_valid && r_data == OP_RESET` | `run_result_required_clear; response_start` | `response_opcode = OP_RESET; response_result = ACCEPTED` |
| `WAIT_RUN_END` | `RECOVER_RX` | `!run_ended && !prepare_active && (rx_error_tick \|\| (rx_byte_valid && r_data != OP_RESET))` | `timer_clear` | — |
| `WAIT_RESPONSE_SENT` | `WAIT_COMMAND` | `response_done_tick && debug_hold` | `debug_hold_clear` | — |
| `WAIT_RESPONSE_SENT` | `WAIT_COMMAND` | `response_done_tick && !debug_hold` | — | — |
| `WAIT_RESET_ACCEPT_SENT` | `WAIT_RESET_ACCEPT_SENT` | `response_done_tick` | `reset_request_set` | — |
| `RECOVER_RX` | `RECOVER_RX` | `rx_activity` | `timer_clear` | — |
| `RECOVER_RX` | `RECOVER_RX` | `!rx_activity && !timer_limit_reached` | `timer_inc` | — |
| `RECOVER_RX` | `WAIT_RUN_END` | `!rx_activity && timer_limit_reached && rx_empty && !response_busy && !debug_hold && run_result_required && !run_ended` | — | — |
| `RECOVER_RX` | `WAIT_COMMAND` | `!rx_activity && timer_limit_reached && rx_empty && !response_busy && !debug_hold && !run_result_required` | — | — |

## Acciones comunes

Estas acciones se acumulan con las de la tabla principal y no reemplazan su destino. Permiten consumir RX mientras TX espera, retener la observación terminal mientras sale `RUN/ACCEPTED`, entregar el resultado cuando el serializador esté libre y completar Debug durante recuperación sin omitir el silencio requerido.

| Source state | Destination state | Boolean condition | Mealy Control Outputs | Mealy Data Outputs |
|---|---|---|---|---|
| `ANY` | `NEXT_STATE` | `!rx_empty` | `rd_uart` | — |
| `ANY` | `NEXT_STATE` | `run_result_required && run_ended` | `debug_hold_set` | — |
| `ANY` | `NEXT_STATE` | `run_result_required && run_ended && !response_busy` | `response_start; response_with_debug; run_result_required_clear` | `response_opcode = OP_RUN; response_result = program_finished ? FINISHED : FAULT` |
| `RECOVER_RX` | `NEXT_STATE` | `response_done_tick && debug_hold` | `debug_hold_clear` | — |
| `ANY` | `NEXT_STATE` | `(debug_hold \|\| (run_result_required && run_ended))` | `debug_read_select` | — |

El productor terminal no compite con una nueva respuesta normal: con un terminal RUN pendiente ya no se admiten nuevos comandos ni cabeceras LOAD, y un RESET reconocido previamente cancela la obligación. Si el serializador todavía transmite ACCEPTED, se conserva la obligación y la Global mantiene el resultado hasta su entrega directa. `run_result_required_clear` se activa únicamente al entregar ese terminal con el serializador libre, o al reconocer RESET.

## Salidas Moore y salidas registradas

No hay salidas Moore de control que dependan exclusivamente de las once fases de `protocol_state`.

| State | Moore outputs |
|---|---|
| All states | — |

El controlador de fases es Mealy: selecciona combinacionalmente los campos de respuesta y su habilitación de captura. El descriptor queda registrado dentro del serializador; `uart_reset_request` sigue siendo una salida registrada del Controller y no se deduce exclusivamente del nombre de una de estas once fases.

## Criterios de organización y temporización

Cada estado distingue una situación de control por sus entradas relevantes, acciones o continuación. El número de estados del registro principal no incluye los registros auxiliares que recuerdan datos, progreso u obligaciones.

| Situación de control | Responsabilidad |
|---|---|
| `WAIT_COMMAND` | Interpretar un opcode y presentar RUN o STEP antes de consultar su aceptación combinacional. |
| `RECEIVE_LOAD_SIZE` | Recibir cinco bytes y utilizar el quinto byte actual para validar el tamaño completo y presentar LOAD en el mismo flanco. |
| `RECEIVE_LOAD_DATA` | Entregar cada byte al Loader y actualizar los faltantes; la última entrega completa IMEM e inicia preparación en la Global. |
| `WAIT_PREP_DONE` | Observar preparación activa al entrar; tras publicarse la imagen, `!prepare_active` permite entregar LOAD/DONE en el flanco siguiente. |
| `WAIT_STEP_END` | Esperar la preparación necesaria y reconocer el único ciclo STEP mediante `cpu_cycle_fire`. |
| `WAIT_LOAD_ACCEPT_SENT`, `WAIT_RUN_ACCEPT_SENT`, `WAIT_RESET_ACCEPT_SENT` | Esperar el fin físico de una aceptación con continuaciones diferentes: recibir programa, esperar RUN o solicitar reset. |
| `WAIT_RUN_END` | Esperar el terminal RUN y admitir RESET sin preparación activa ni terminal observable. |
| `WAIT_RESPONSE_SENT` | Esperar el fin físico de la respuesta final y liberar la observación si `debug_hold` está activo. |
| `RECOVER_RX` | Recuperar silencio y alineación RX mientras CPU y TX pueden continuar. |

### Temporización de interfaces

Las solicitudes, los campos de respuesta y sus controles se calculan antes del flanco, siguiendo las [dependencias combinacionales del controlador](architecture/debug/protocol_controller.md#temporización-de-interfaces). El cumplimiento del período funcional de 20 ns se comprobará al implementar RTL.

LOAD presenta el tamaño completo unsigned de 40 bits, incluido el byte actual, antes de validar y reducir su ancho. El [Loader](architecture/session/loader.md#finalización-y-publicación-de-la-imagen) completa la última escritura y produce `load_ok` en el flanco de la última entrega. Después de publicar la imagen, el Controller captura LOAD/DONE en el flanco siguiente, a 20 ns con clock de 50 MHz.

STEP captura su respuesta y retiene la observación en el flanco de `cpu_cycle_fire`. El serializador captura las respuestas normales en el mismo flanco que `response_start`, con `response_busy == 0`. Este último depende del estado del serializador y no de la solicitud de captura.

Para RUN terminado antes del último Stop de ACCEPTED se retiene la observación y se mantiene `run_result_required` hasta la captura terminal. Completar una solicitud interna de respuesta no equivale a terminar su transmisión UART: los estados de espera consumen `response_done_tick`.

## Comprobación del diseño y límites

Los [modelos abstractos reproducibles](../tools/verification/README.md) comprueban la coordinación del Controller, Global, Loader y serializador y la recuperación PC fuera de LOAD en ambos perfiles. También se comprueban las referencias del catálogo y las cotas calculadas del enlace. Sus estímulos cubren fases, prioridades, fronteras de respuesta y recuperación; las fuentes, configuración, comando y límites se describen junto a los modelos.

Se inyectan los eventos de interfaz y se utiliza tiempo virtual. Esta comprobación no enumera todo el sistema ni acredita RTL, contenido del datapath, tramas UART, timing, placa o una implementación del cliente PC.

## Referencias y seguimiento

- [Checklist de documentación](checklist_protocol_controller.md).
- [Protocolo UART](protocol.md).
- [Protocol Controller](architecture/debug/protocol_controller.md).
- [Diagrama de estados](architecture/debug/protocol_controller.md#diagrama-de-estados): vista resumida con etiquetas breves; las condiciones exactas, prioridades y salidas permanecen en las tablas.
- [Response Serializer](architecture/debug/response_serializer.md).
- [Global FSM y control de ejecución](architecture/session/execution_control.md).
- [Loader](architecture/session/loader.md).
- [Preparación de sesión](architecture/session/session_preparation.md).
