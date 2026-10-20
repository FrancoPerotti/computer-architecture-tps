### DEC-SYS-007 — Servicios y parámetros generales de UART

**Estado:** Aprobada.

**Dominio:** UART / Control del protocolo, respuestas y servicios FPGA asociados.

**Contratos:** [Protocolo UART](../protocol.md), [Protocol Controller](../architecture/debug/protocol_controller.md), [Response Serializer](../architecture/debug/response_serializer.md) e [Interfaces](../interfaces.md).

**Contexto:** El enlace PC–FPGA debe recibir programas de forma continua, ejecutar las operaciones admitidas, ordenar sus respuestas y transmitir una observación coherente. El transporte debe seguir funcionando cuando la CPU está detenida y cuando TX espera espacio.

**Decisión:** Utilizar un dominio funcional común, buffers RX/TX independientes y dos módulos de control del transporte: `protocol_controller` interpreta y coordina; `response_serializer` captura y transmite las respuestas. Loader, preparación y Execution Control conservan sus responsabilidades de escritura, inicialización y ejecución. Las siguientes secciones fijan las elecciones y sus fundamentos; los contratos enlazados desarrollan señales, tablas y condiciones por ciclo.

La realización utiliza como referencia los módulos UART y FIFO del [TP2](../../../tp2/rtl/uart_core.sv) y su [reset_sync](../../../tp2/rtl/reset_sync.sv), con el clock funcional y la separación de control y acciones definidos para este sistema.

#### Organización y responsabilidades

| Módulo                | Responsabilidad                                                                                             |
| --------------------- | ----------------------------------------------------------------------------------------------------------- |
| `uart_core`           | Integra sincronizador, generador de ticks, receptor, transmisor y FIFO; transporta bytes y eventos físicos. |
| `protocol_controller` | Consume o descarta RX, conserva tamaño y progreso LOAD, solicita operaciones y selecciona las respuestas.   |
| `response_serializer` | Captura el descriptor de respuesta, recorre la observación y produce TX hasta el último Stop.               |
| `Loader`              | Ensambla palabras y escribe IMEM a partir de las entregas del Controller.                                   |
| `Session Preparation` | Inicializa la sesión y limpia las marcas de DMEM antes de publicación o ejecución.                          |
| `Execution Control`   | Contiene la Global FSM, acepta solicitudes, mantiene la sesión y autoriza ciclos CPU.                       |
| `reset_sync`          | Acondiciona las fuentes de reset para su distribución funcional común.                                      |

La [composición del sistema](../architecture/system_composition.md) conecta estos módulos y distribuye capacidades, clock y reset. RF y DMEM conservan sus recursos y exponen las consultas Debug definidas por sus contratos.

**Justificación:** Separar recepción, servicios y producción de respuestas permite consumir RX mientras TX espera. Cada bloque conserva una responsabilidad verificable; los recursos internos no requieren un módulo HDL independiente por contador o registro.

#### Control y actualización de recursos

Las FSM registran el estado en el flanco positivo de `clk` y calculan combinacionalmente el siguiente estado y las señales de acción. La lógica de cada recurso realiza las capturas, desplazamientos, incrementos y limpiezas habilitados por esas señales.

La selección de condiciones utiliza `casez` y patrones con `?` para entradas irrelevantes; `x` no se utiliza como comodín. Ese comodín no representa un valor desconocido que deba almacenarse. Los controles tienen valores por defecto inactivos y los recursos conservan su valor cuando no reciben una orden. Reset tiene prioridad sobre las acciones normales.

La codificación one-hot mantiene un criterio común entre las FSM y permite identificar directamente cada fase en verificación. Su elección no presupone ventajas de área o frecuencia antes de síntesis.

La separación entre decisión y actualización no introduce por sí sola un ciclo adicional. Una acción combinacional se consume en el mismo flanco que registra el estado siguiente. `cpu_cycle_fire` habilita los recursos CPU; UART, Controller, serializador, Loader y preparación utilizan el clock funcional independientemente de esa habilitación.

**Justificación:** La distinción hace explícito qué lógica decide y qué recurso cambia, sin mezclar el clock físico con las autorizaciones de ejecución ni agregar registros intermedios por la organización del código.

#### Configuración física y ticks

| Parámetro                |                                            Valor |
| ------------------------ | -----------------------------------------------: |
| Clock funcional          |                                    50.000.000 Hz |
| Baud nominal             |                                           19.200 |
| Formato                  | 8N1: un Start, ocho datos, sin paridad y un Stop |
| Sobremuestreo            |                                               16 |
| Divisor de ticks         |                                              163 |
| Profundidad de cada FIFO |                                          4 bytes |

Una única instancia de [baud_tick_gen](../architecture/uart/uart_baud_tick_gen.md) alimenta RX y TX. `s_tick` es un enable síncrono registrado de un clock; no constituye otro dominio de clock. El contador de ocho bits recorre 0 a 162. Al alcanzar 162 vuelve a cero y registra un pulso; los consumidores lo utilizan en el flanco siguiente. Reset limpia cuenta y salida. El generador mantiene su fase entre tramas y durante HOLD CPU.

El divisor es el entero más próximo a `50.000.000 / (19.200 × 16)`. Produce aproximadamente 19.171,78 baud efectivos, con error de −0,147 %. PC y protocolo utilizan 19200 baud nominales y sus márgenes temporales. Una trama nominal de diez bits ocupa aproximadamente 0,520833 ms; 1024 bytes requieren aproximadamente 0,533333 s de contenido, sin respuestas ni preparación.

**Justificación:** La configuración proporciona un ritmo suficiente para el TP y una referencia común para dimensionar recursos y plazos. Compartir ticks mantiene RX y TX en el dominio funcional; el redondeo reduce el error de frecuencia sin generar otro clock.

#### Recepción y actividad RX

`uart_rx` contiene RX Control, Sample Counter de cuatro bits, Bit Counter de tres bits y RX Shift Register de ocho bits. La FSM utiliza cinco bits one-hot, en el orden `IDLE`, `START`, `DATA`, `STOP`, `RECOVER`, con `IDLE` en el bit cero y como estado de reset.

`START` verifica el nivel bajo después de ocho ticks. `DATA` ordena ocho capturas separadas por dieciséis ticks. `STOP` verifica el nivel alto dieciséis ticks después de D7 y produce `rx_done_tick` solo para una trama válida. Un Start falso o Stop inválido produce error; `RECOVER` espera el retorno de la línea a alto. Esta recuperación de trama es distinta del silencio de recuperación del protocolo.

La entrada serie atraviesa el sincronizador de dos registros antes de llegar al control y al registro de recepción. La captura de bits solo ocurre con `data_shift_enable`; permanecer en `DATA` no habilita una captura por clock.

El receptor genera los siguientes indicadores combinacionales de un bit:

| Indicador      | Condición fuera de reset                                           |
| -------------- | ------------------------------------------------------------------ |
| `rx_receiving` | FSM en `START`, `DATA` o `STOP`.                                   |
| `rx_activity`  | Cambio del nivel sincronizado, línea baja o `rx_receiving` activo. |

Un registro auxiliar `rx_previous`, inicializado en uno y actualizado cada clock funcional, permite detectar cambios sin depender de `s_tick`. Durante reset ambos indicadores valen cero. Una trama o una línea baja pueden mantener actividad durante varios clocks, incluso sin producir un byte válido.

`uart_core` expone ambos indicadores; el Controller consume `rx_activity`, que ya incluye la trama en curso. No necesita una entrada separada de `rx_receiving`.

**Justificación:** Las cinco fases cubren recepción 8N1 y retorno al reposo tras error. Detectar actividad por nivel y cambios impide declarar silencio con una trama incompleta o una línea sostenida en bajo. Las [condiciones y acciones RX](../architecture/uart/uart_rx.md#estados-y-transiciones) desarrollan esos eventos sin añadir fases al protocolo.

#### Transmisión y fin físico

`uart_tx` conserva TX Control, Sample Counter de cuatro bits, Bit Counter de tres bits, registro de desplazamiento de ocho bits y registro de salida serie de un bit. Su FSM utiliza cuatro bits one-hot, en el orden `IDLE`, `START`, `DATA`, `STOP`, con `IDLE` en el bit cero y como estado de reset.

El transmisor acepta `tx_start` en `IDLE`, con `data_in` estable antes del flanco. En ese flanco captura el byte, inicializa los contadores, registra el nivel bajo y entra en `START`. Start cuenta dieciséis ticks antes de D0; cada bit de datos se conserva durante dieciséis intervalos de tick. Las siete transiciones de D0 a D7 desplazan el byte, incrementan el índice y registran el bit siguiente en el mismo flanco. Al terminar D7 se registra alto y comienza `STOP`, que dura dieciséis intervalos completos. El registro serie conserva el nivel entre actualizaciones y se inicializa en alto. `tx_busy` vale uno en `START`, `DATA` y `STOP`; reset lleva a `IDLE` y suprime los indicadores de envío.

El selector interno `tx_output_select[1:0]` utiliza estas alternativas:

| Código | Selección     | Valor preparado                                                                      |
| ------ | ------------- | ------------------------------------------------------------------------------------ |
| `00`   | `HIGH`        | Uno para reposo y Stop.                                                              |
| `01`   | `LOW`         | Cero para Start.                                                                     |
| `10`   | `CURRENT_BIT` | `data_reg[0]` para comenzar D0.                                                      |
| `11`   | `NEXT_BIT`    | `data_reg[1]` anterior al flanco para comenzar D1 a D7 mientras se desplaza el byte. |

`tx_write_enable` habilita su captura; sin esa orden el registro conserva el nivel, aunque el selector tome HIGH por defecto. Ambos controles permanecen internos.

`tx_done_tick` es el evento del flanco que completa el Stop entero. En ese mismo flanco el transmisor vuelve a `IDLE` y la FIFO retira el byte. El dato permanece en la FIFO durante la transmisión. Si quedan bytes, el siguiente puede iniciarse desde el flanco posterior.

La [frontera del transmisor](../architecture/uart/uart_tx.md#frontera-de-uart_tx) utiliza `clk`, `reset`, `s_tick`, `tx_start`, `data_in[7:0]`, `tx`, `tx_busy` y `tx_done_tick`, sin registros adicionales para desplazar los eventos de interfaz.

**Justificación:** Registrar la salida mantiene estable cada nivel entre flancos. Vincular el retiro FIFO y el evento de finalización al Stop completo permite coordinar LOAD, Debug y RESET con la salida física, en lugar de confundirla con el encolado.

#### FIFO y consumo de bytes

Se utilizan dos instancias de [fifo](../architecture/uart/uart_fifo.md), RX y TX, de cuatro entradas de ocho bits. Cada una tiene punteros de dos bits y cuenta de ocupación de tres bits. La salida de lectura es combinacional y solo es válida con `empty=0`.

Las operaciones se aceptan según los flags anteriores al flanco: lectura con `rd && !empty`, escritura con `wr && !full`. Si ambas se solicitan en lleno, solo se acepta lectura; en vacío, solo escritura. Con ambas aceptadas avanzan ambos punteros y se conserva la ocupación. Reset vacía la cola mediante punteros y cuenta, sin borrar sus bytes físicos.

El Controller genera `rd_uart = !reset && !rx_empty` en todas sus fases. La fase y el error RX determinan el uso o descarte del byte; esperar TX no inhibe su retiro. El serializador conserva el byte preparado y la posición hasta una escritura TX aceptada. Si una FIFO llena libera espacio al terminar Stop, el productor puede encolar desde el flanco siguiente.

**Justificación:** Procesar cada byte antes del siguiente evita acumulación sostenida en RX. Cuatro entradas proporcionan margen de desacople; Loader reúne los bytes de cada palabra y TX produce el mensaje progresivamente, sin exigir que las FIFO almacenen el programa o la respuesta completos.

#### Integración de uart_core

`uart_core` contiene `serial_input_sync`, un generador de ticks, `uart_rx`, `uart_tx` y las dos FIFO. Sus seis entradas son `clk`, `reset`, `serial_rx`, `rd_uart`, `w_data` y `wr_uart`; sus ocho salidas son `serial_tx`, `r_data`, `rx_empty`, `tx_full`, `rx_error_tick`, `rx_activity`, `rx_receiving` y `tx_done_tick`. Los buses `r_data` y `w_data` tienen ocho bits; las demás señales tienen uno.

En RX, `rx_done_tick` escribe `received_data` en la FIFO. El Controller observa `r_data` y `rx_empty` y produce `rd_uart`. En TX, el serializador produce `w_data` y `wr_uart` y recibe `tx_full` y `tx_done_tick`. Fuera de reset, `tx_start = !tx_empty && !tx_busy`; reset suprime el comienzo.

`rx_error_tick` combina error de trama y desbordamiento: `frame_error_tick` o `rx_done_tick` con `rx_full` previo al flanco. No se repite por mantener RX llena y vale cero durante reset. `rx_full`, `rx_done_tick`, `tx_empty` y `tx_busy` son conexiones internas. Los indicadores RX y el evento TX atraviesan la integración sin otra etapa de registro.

**Justificación:** La [integración UART](../architecture/uart/uart_core.md) conserva el orden de bytes y proporciona a cada consumidor los eventos que necesita. El reporte combinado permite aplicar la recuperación de protocolo sin introducir códigos externos distintos para trama y desbordamiento.

#### FSM de Protocol Controller

`protocol_controller` utiliza una FSM Mealy one-hot de once bits. El siguiente orden fija el bit activo de cada estado; reset selecciona únicamente el bit cero.

| Bit | Estado                   | Función                                                                                 |
| --- | ------------------------ | --------------------------------------------------------------------------------------- |
| 0   | `WAIT_COMMAND`           | Interpretar un opcode con el transporte disponible.                                     |
| 1   | `RECEIVE_LOAD_SIZE`      | Recibir el tamaño y resolver LOAD con su quinto byte.                                   |
| 2   | `WAIT_LOAD_ACCEPT_SENT`  | Esperar el último Stop de LOAD/ACCEPTED.                                                |
| 3   | `RECEIVE_LOAD_DATA`      | Entregar contenido al Loader.                                                           |
| 4   | `WAIT_PREP_DONE`         | Esperar preparación y publicación de la imagen.                                         |
| 5   | `WAIT_STEP_END`          | Esperar el ciclo STEP que requiere preparación previa.                                  |
| 6   | `WAIT_RUN_ACCEPT_SENT`   | Esperar RUN/ACCEPTED mientras la CPU puede avanzar.                                     |
| 7   | `WAIT_RUN_END`           | Esperar terminal RUN y admitir RESET en su ventana.                                     |
| 8   | `WAIT_RESPONSE_SENT`     | Esperar una respuesta corta o con Debug; incluye la entrega del terminal tras ACCEPTED. |
| 9   | `WAIT_RESET_ACCEPT_SENT` | Esperar RESET/ACCEPTED para solicitar reset global.                                     |
| 10  | `RECOVER_RX`             | Descartar RX hasta cumplir silencio y completar respuestas y Debug.                     |

Las salidas combinacionales dependen del estado, las entradas y los recursos registrados. Las tablas distinguen controles activos y datos consumidos con su habilitación. No hay salidas Moore de control exclusivas de la fase; `uart_reset_request` es una salida registrada.

**Justificación:** Cada fase distingue una recepción, espera o continuación necesaria del intercambio. La [tabla del Controller](../architecture/debug/protocol_controller.md#tabla-principal-de-transiciones-y-salidas-mealy) fija sus condiciones y las [acciones comunes](../architecture/debug/protocol_controller.md#acciones-comunes) conservan consumo RX y atención del terminal durante las esperas. La FSM global CPU conserva su propio control de ejecución.

#### Recursos del Controller

| Recurso registrado     | Ancho              | Función                                                |
| ---------------------- | ------------------ | ------------------------------------------------------ |
| `protocol_state`       | 11                 | Fase one-hot del transporte.                           |
| `load_size_received`   | 40                 | Los cinco bytes del tamaño original.                   |
| `size_byte_index`      | 3                  | Posición del byte de tamaño, entre cero y cuatro.      |
| `load_bytes_remaining` | `IMAGE_SIZE_WIDTH` | Cantidad aún no entregada al Loader.                   |
| `inactivity_count`     | 23                 | Cuenta compartida de timeout y silencio.               |
| `run_result_required`  | 1                  | RUN aceptado todavía debe entregar su resultado final. |
| `debug_hold`           | 1                  | Retención de la observación hasta el fin físico Debug. |
| `uart_reset_request`   | 1                  | Solicitud de reset registrada después de ACCEPTED.     |

`IMAGE_SIZE_WIDTH = max(1, ceil(log2(IMEM_CAPACITY_BYTES + 1)))`. El total es 91 bits en REFERENCE y 90 en ALT_1000. Reset limpia los recursos y deja `WAIT_COMMAND` activo. `timer_clear` tiene prioridad sobre `timer_inc`; sin acción el recurso conserva su valor.

El tamaño se captura por byte y el índice avanza hasta el quinto. La aceptación carga los faltantes y cada `load_byte_valid` los decrementa en el mismo flanco de entrega, incluida la última entrega hasta cero. La cuenta de tiempo satura en 4.999.999 y se comparte entre fases excluyentes.

**Justificación:** Los datos recibidos y las marcas representan las condiciones que sobreviven entre fases. El tamaño debe validarse en cuarenta bits; los faltantes necesitan representar la capacidad inclusive. La [codificación y dimensionamiento](../architecture/debug/protocol_controller.md#codificación-y-dimensionamiento) deriva los anchos de esos rangos.

#### Solicitudes y servicios de sesión

El Controller presenta una sola solicitud por ciclo entre `load_request`, `run_request` y `step_request`, independientemente de `command_accepted`. Execution Control decide combinacionalmente la aceptación; ambas FSM consumen solicitud y aceptación en el mismo flanco. Sin solicitud, `command_accepted=0` no constituye un evento.

RUN y STEP presentan su solicitud también con imagen inválida. Ante rechazo, `image_valid=0` selecciona NO_IMAGE y `image_valid=1` selecciona BUSY. LOAD solo presenta solicitud si el tamaño completo es válido: no nulo, múltiplo de cuatro y dentro de IMEM. El quinto byte actual se combina con los cuatro registrados antes de reducir el ancho o aceptar la carga.

El Controller recibe `load_available`, `prepare_active`, `program_finished`, `fault_terminal`, `image_valid`, `command_accepted` y `cpu_cycle_fire`. `load_ok`, `load_fail` y `prepare_done` llegan a la Global FSM dentro de `processor_top`, mediante Execution Control. La [frontera del Controller](../interfaces.md#104-protocol-controller) comprende 15 entradas y 16 salidas externas; las conexiones internas a sus recursos se especifican por separado.

**Justificación:** Separar solicitud de aceptación evita un lazo combinacional y deja a la Global FSM la elegibilidad arquitectónica. El Controller conserva la admisión del transporte y reconoce el ciclo STEP por su habilitación efectiva, incluida la finalización de una preparación previa.

#### Captura y finalización de respuestas

El Controller presenta `response_opcode[7:0]`, `response_result[7:0]` y `response_with_debug` combinacionalmente y activa `response_start`. Con `response_busy=0` antes del flanco, el serializador captura esos 17 bits en su descriptor y lo conserva durante el envío. Los campos del Controller pueden cambiar después de la captura sin alterar la respuesta en curso. `response_start` habilita una única captura por respuesta; el serializador atiende una respuesta por vez. `response_with_debug` selecciona cuerpo para STEP realizado y RUN terminal; las demás respuestas tienen solo la cabecera de dos bytes, incluidas aceptaciones y rechazos. Esa señal de formato no agrega un campo al enlace UART.

Las fases que producen una respuesta normal garantizan serializador libre y un único productor. El serializador mantiene `response_busy` durante el mensaje completo y produce `response_done_tick` en el flanco del último Stop, incluido Debug. Antes de ese flanco todavía está ocupado; la siguiente captura puede ocurrir desde el flanco posterior. Reset suprime captura y finalización, deja ocupación inactiva y aborta el envío sin informar un fin normal.

Al aceptar RUN se activa `run_result_required`. Si la CPU alcanza FINISHED o FAULT durante ACCEPTED, se retiene el estado y se completa primero la aceptación. El terminal se entrega al serializador cuando queda libre; `program_finished` selecciona FINISHED y `fault_terminal` selecciona FAULT. Esa captura limpia la obligación y ocurre una sola vez. `debug_hold` permanece activo hasta el último Stop Debug. STEP activa la retención y captura DONE con Debug en el flanco de su único ciclo.

**Justificación:** El descriptor propio del serializador desacopla el envío de los campos combinacionales. La exclusión entre fases y la obligación terminal conservada por el Controller permiten ordenar ACCEPTED y terminal sin duplicar el descriptor registrado. La [comunicación entre ambos módulos](../architecture/debug/response_serializer.md#comunicación-con-el-controlador) distingue captura, encolado y finalización física.

#### Admisión, prioridades y recuperación RX

La PC mantiene una operación normal en curso por vez. CHECK_READY responde READY o BUSY según `load_available`, sin reservar LOAD ni alterar CPU; READY expresa disponibilidad para cargar, independientemente de que exista imagen válida. Durante RUN efectivo o su drain automático, solo se admite RESET después del último Stop de ACCEPTED y con preparación inactiva. Otro byte o un error UART inicia `RECOVER_RX` sin respuesta; la CPU puede continuar y la imagen se conserva.

Durante aceptaciones, preparación, respuestas Debug y recuperación, los bytes adicionales se descartan. Un terminal RUN ya observable domina un nuevo RESET. Si RESET se reconoce antes de observar ese terminal, cancela `run_result_required`, incluso si la CPU termina en el mismo flanco. Se completa RESET/ACCEPTED antes de pedir reset global.

Los timeouts de tamaño y contenido LOAD y el silencio de recuperación son 5.000.000 clocks: 100 ms a 50 MHz. En LOAD, error UART tiene prioridad sobre byte válido y este sobre timeout; un byte válido en el límite completa o reinicia la fase. El timeout depende de bytes válidos, no de actividad sin byte. El plazo de tamaño comienza al reconocer LOAD; el de contenido comienza en el último Stop de LOAD/ACCEPTED, antes de admitir los bytes del programa. Un error UART al recibir un opcode inicia recuperación sin respuesta; en tamaño o contenido LOAD produce UART_ERROR. Los timeouts producen INCOMPLETE_REQUEST o INCOMPLETE_DATA, respectivamente. Solo el fallo durante contenido aborta la carga ya aceptada; antes de aceptarla se conserva la imagen anterior.

En recuperación, `rx_activity` reinicia la cuenta, incluida una actividad coincidente con su vencimiento. Con silencio completo, la salida exige RX vacía, serializador libre y Debug liberado. Si RUN continúa pendiente se vuelve a `WAIT_RUN_END`; si ya se atendieron las respuestas, se vuelve a `WAIT_COMMAND`. Un terminal durante recuperación conserva su resultado y Debug sin cancelar la supervisión del silencio. No se guardan comandos para después ni se reinicia UART para descartar RX.

**Justificación:** La fase de transporte determina qué puede interpretarse sin confundir contenido o bytes residuales con nuevos comandos. El contador compartido cubre fases excluyentes; la actividad física impide una recuperación falsa. El [protocolo](../protocol.md#orden-de-los-intercambios) fija la admisión externa y la [recuperación desde PC](../protocol.md#perder-una-respuesta-o-conexión), incluido el único RESET automático si falla la consulta.

#### Observación Debug y selección RF/DMEM

Debug lee directamente el estado retenido posterior al ciclo STEP o al último ciclo RUN. La exclusión comienza en ese instante y termina con el último Stop, salvo reset global. Incluye la espera por ACCEPTED y bloquea ciclos CPU y preparación concurrentes.

El Controller genera `debug_read_select = !reset && (debug_hold || (run_result_required && run_ended))`, con `run_ended = program_finished || fault_terminal`. La detección terminal cubre el intervalo anterior al registro de `debug_hold`; en STEP la marca se registra en el propio flanco observado.

La señal común selecciona el primer puerto de lectura RF y el camino de lectura CPU/Debug de DMEM. Con cero, la selección utiliza Read Register 1 CPU para RF y `EX/MEM.ex_result` para DMEM; con uno utiliza las direcciones independientes del serializador: `debug_rf_addr[4:0]` y `debug_dmem_addr`, extendida con ceros a 32 bits para DMEM. RF devuelve `debug_rf_data[31:0]` antes del bypass CPU; la segunda lectura conserva su conexión CPU. La regla de x0 se aplica a la dirección interna seleccionada. El serializador consume los retornos como consultas Debug solo durante la selección y la sección correspondientes. La selección no habilita escrituras y vale cero durante reset.

Los seis campos de contexto llegan por `debug_state_code[7:0]`, `debug_image_valid`, `debug_pc[31:0]`, `debug_cycle_count[63:0]`, `debug_fault_cause[2:0]` y `debug_fault_pc[31:0]`. Proceden del código global combinacional, el predicado de tamaño confirmado no nulo, PC, contador y los registros de fault; `image_valid` no agrega almacenamiento.

Se observan RF y los 34 campos registrados actuales de los cuatro registros interetapa: IF/ID, cinco campos y 69 bits; ID/EX, quince y 193; EX/MEM, ocho y 139; MEM/WB, seis y 103. Las entradas del serializador utilizan `debug_<latch>_<campo>`, con prefijos `ifid`, `idex`, `exmem` y `memwb`. Sus 504 bits funcionales no incluyen padding interno. Se transmiten los bits registrados también con flags inactivos, sin sustituirlos por entradas de captura o `next.valid`. `valid` determina la vigencia de la instrucción; `IF/ID.fetch_fault_valid` permite interpretar por separado el candidato de fetch. Los ceros de relleno se forman al serializar.

**Justificación:** Retener la situación observada permite recorrer campos y memoria sin copiar el snapshot completo. Compartir las lecturas reutiliza recursos mientras CPU está detenida; la selección combinacional preserva el acceso CPU del flanco que produjo la observación. El [significado de Debug](../architecture/debug/debug_architecture.md) y las [consultas de memoria](../architecture/memory/memory_architecture.md#selector-de-dirección-de-lectura-cpudebug) fijan esa exclusión.

#### Recorrido y recursos del serializador

El serializador utiliza diez estados one-hot en este orden: `IDLE`, `COUNT_DMEM`, `PREPARE_FIXED`, `ENQUEUE_FIXED`, `PREPARE_COUNT`, `ENQUEUE_COUNT`, `SCAN_DMEM`, `PREPARE_ENTRY`, `ENQUEUE_ENTRY`, `WAIT_TX_DONE`. `IDLE` ocupa el bit cero y es el estado de reset. `response_busy` se deriva del estado fuera de `IDLE` y vale cero durante reset, sin dependencia combinacional de `response_start`.

Además del descriptor, conserva un próximo byte de ocho bits con disponibilidad, `fixed_byte_index` de ocho bits, un índice compartido de tres bits, dirección DMEM, `used_count`, contador de entradas encoladas, `tx_pending` de tres bits y marca de producción completa. `tx_pending` cuenta de cero a cuatro los bytes encolados aún no terminados, incluido el byte en transmisión y excluido el próximo byte aún sin encolar. Comienza en cero con reset o nueva respuesta; escritura aceptada lo incrementa, fin físico lo decrementa y ambos eventos simultáneos conservan la cuenta.

Cada byte se prepara y se encola en flancos separados. Preparar puede ocurrir con TX llena: captura el dato y activa disponibilidad sin avanzar ni escribir TX. Encolar exige disponibilidad y `tx_full=0`, consume el byte y avanza el recorrido por aceptación efectiva. Si TX está llena, byte, disponibilidad y posición permanecen estables; no se recaptura ni se prepara el byte siguiente. Reset o nueva respuesta dejan disponibilidad y producción completa inactivas. El seguimiento de pendientes atiende `tx_done_tick` únicamente con respuesta ocupada, incluidas preparación y espera.

El fin físico exige respuesta ocupada, producción completa, un único pendiente TX y `tx_done_tick` anteriores al flanco. Ese flanco produce `response_done_tick`, consume el último pendiente y vuelve a `IDLE`. Una cuenta vacía mientras todavía se producen bytes no termina el mensaje. La producción completa se marca al aceptar el último byte, sin esperar su Stop, y lleva a `WAIT_TX_DONE`. Durante esa espera no se producen ni encolan más bytes; índices y dirección conservan sus posiciones finales.

La observación de una DMEM de capacidad C bytes utiliza dos recorridos sucesivos. El primero cuenta las marcas de bytes escritos por stores comprometidos de la sesión, incluidos valores cero. La dirección y `used_count` comienzan en cero. Se examina una posición por clock y se incrementa la cuenta si está utilizada. La comparación explícita con C − 1 cierra el recorrido después de procesar la última posición, sin incrementar la dirección final ni depender de desbordamiento. El eventual incremento de esa última marca participa del total en ese mismo flanco. Después se transmiten cabecera, contexto, RF, registros interetapa y la cantidad unsigned de cinco bytes. El segundo produce entradas crecientes de dirección de cuatro bytes y valor de uno; cantidad cero omite ese recorrido. Una respuesta sin Debug transmite solo su cabecera y no recorre DMEM. Los retornos son combinacionales y se consumen con la dirección anterior al flanco. El conteo usa solo `debug_dmem_used`, de un bit; el listado consume `debug_dmem_data`, de ocho bits, para posiciones utilizadas. En una entrada, la dirección permanece estable durante sus cinco bytes y esperas TX; el dato se toma al preparar el quinto byte. Las consultas no incorporan un registro de respuesta de DMEM ni handshake adicional.

La dirección DMEM se reutiliza en ambos recorridos y vuelve a cero antes del listado; `used_count` conserva el resultado separado de la dirección. La dirección utiliza `max(1, ceil(log2(C)))` y los contadores de cantidad y entradas `max(1, ceil(log2(C + 1)))`. Con 2048 bytes en REFERENCE son 11 y 12 bits; con 1000 bytes en ALT_1000, diez y diez. La cantidad y cada entrada comparten el índice 0 a 4: para la entrada, cero a tres seleccionan los bytes de dirección y cuatro el dato. El índice comienza en cero y se reinicia al comenzar cada entrada; la cantidad se extiende con ceros hasta sus cinco bytes UART.

El contador de entradas comienza en cero al iniciar la lista y solo aumenta al aceptar el quinto byte de cada entrada. Los bytes de dirección y `tx_done_tick` no lo modifican; `used_count` conserva el total. Si la cuenta previa más uno alcanza `used_count`, esa aceptación marca producción completa y retiene la dirección, sin consultar posiciones posteriores. La dirección avanza únicamente si quedan entradas por encolar. Con cantidad cero, producción completa se activa al aceptar el quinto byte de la cantidad.

El recorrido fijo comienza en cero para cada respuesta y utiliza posiciones 0 a 224. El índice identifica sección, campo y byte sin contadores adicionales por sección:

| Posición  | Campo                                            |
| --------- | ------------------------------------------------ |
| 0         | Opcode de respuesta.                             |
| 1         | Resultado.                                       |
| 2         | `debug_state_code`.                              |
| 3         | `debug_image_valid`, con siete ceros superiores. |
| 4 a 7     | Cuatro bytes de `debug_pc`.                      |
| 8 a 15    | Ocho bytes de `debug_cycle_count`.               |
| 16        | `debug_fault_cause`, con cinco ceros superiores. |
| 17 a 20   | Cuatro bytes de `debug_fault_pc`.                |
| 21 a 148  | RF, cuatro bytes por registro.                   |
| 149 a 159 | IF/ID, once bytes.                               |
| 160 a 189 | ID/EX, treinta bytes.                            |
| 190 a 209 | EX/MEM, veinte bytes.                            |
| 210 a 224 | MEM/WB, quince bytes.                            |

En RF, restar 21 produce una posición relativa de siete bits; [6:2] selecciona el registro y [1:0] el byte. `rf_byte_select` elige [7:0], [15:8], [23:16] y [31:24] de `debug_rf_data`. Fuera del tramo RF las selecciones son cero y no se consume ese retorno.

Para un campo multibyte que comienza en s, j = `fixed_byte_index` − s selecciona [8*j + 7 : 8*j]. Los campos pequeños completan sus bits altos con cero. Capturar el byte usa valores anteriores al flanco y no avanza el índice; solo la escritura TX aceptada lo hace. Aceptar 20, 159, 189 o 209 pasa al tramo siguiente sin terminar la producción. Aceptar 224 retiene el índice y pasa a la cantidad, con el índice compartido en cero. Sin Debug, aceptar posición uno retiene el índice, marca producción completa y espera el fin físico.

Los [nombres y posiciones del serializador](../architecture/debug/response_serializer.md#observación-y-selección-de-bytes-de-los-cuatro-latches) conservan el layout. La respuesta Debug completa ocupa `230 + 5*K` bytes para K posiciones DMEM utilizadas.

Las acciones `response_init`, `byte_load`, `byte_consume`, `fixed_index_inc`, `shared_index_clear`, `shared_index_inc`, `dmem_addr_inc`, `used_count_inc`, `list_init`, `entry_count_inc`, `production_complete_set`, `tx_pending_inc` y `tx_pending_dec` habilitan los recursos según la [tabla de acciones](../architecture/debug/response_serializer.md#señales-de-acción-de-la-fsm).

`response_init` captura el descriptor e inicializa el recorrido y seguimiento. `list_init` pone dirección, índice compartido y contador de entradas en cero conservando `used_count`; `byte_load` activa disponibilidad y `byte_consume` la limpia. Las órdenes son combinacionales de un bit; inicializar tiene prioridad sobre actualizar el mismo recurso y reset sobre todas las órdenes.

**Justificación:** Dos recorridos proporcionan la cantidad antes del listado sin un buffer de memoria completo. Reutilizar dirección e índice reduce almacenamiento; separar producción de pendientes físicos mantiene el orden y permite conservar cada byte durante espera TX.

#### Loader y publicación de imagen

El Controller presenta `load_size_bytes` con el quinto byte actual en el flanco de aceptación; después lo obtiene del tamaño registrado y lo mantiene hasta `image_publish`. Execution Control genera `load_start` en la aceptación e invalida el tamaño confirmado. Loader presenta el mismo tamaño mediante el alias combinacional `pending_image_size_bytes`.

La posición de cada entrega es `load_size_bytes - load_bytes_remaining`, calculada con los valores anteriores al flanco. El lane proviene de sus dos bits bajos y el índice de palabra de desplazar dos posiciones. `load_last_byte` exige entrega válida y un faltante previo igual a uno. El ancho de dirección de byte es `max(1, ceil(log2(IMEM_CAPACITY_BYTES)))`.

[Loader](../architecture/session/loader.md) conserva los tres primeros bytes en `partial_word[23:0]` y los combina con el cuarto actual para escribir una palabra de 32 bits. Acepta una entrega por clock; `loader_active` de la Global FSM autoriza la escritura solo en `LOADING`, con entrega válida y lane tres. No necesita FSM, contador de posición ni copia privada de tamaño. Reset, inicio y aborto limpian su recepción parcial; el aborto tiene prioridad sobre entrega y suprime escritura. `load_fail` certifica el aborto solicitado por el Controller.

La última entrega válida escribe la última palabra y activa `load_ok` hacia la Global FSM en ese mismo flanco. Comienza `PREPARING_READY` y el Controller entra en `WAIT_PREP_DONE`, con `prepare_active` activo después del flanco. Solo `image_publish`, al completar la preparación, confirma el tamaño y vuelve ejecutable la imagen. El Controller entrega LOAD/DONE al serializador en el flanco siguiente a la publicación, 20 ns después.

LOAD termina en READY sin iniciar ejecución; esta requiere RUN o STEP. Un rechazo anterior a la aceptación conserva imagen y sesión. Un aborto posterior deja imagen inválida; no restaura la anterior. LOAD no valida la legalidad ISA de las instrucciones.

**Justificación:** El progreso del Controller ya determina posición y fin de carga. Un registro de 24 bits basta para ensamblar palabras con el cuarto byte actual. Separar recepción, última escritura y publicación impide ejecutar una imagen parcial o una sesión todavía sin preparar.

#### Preparación de sesión

[Session Preparation](../architecture/session/session_preparation.md) recibe `prepare_active` y utiliza el mismo mecanismo para `PREPARING_READY`, `PREPARING_RUN` y `PREPARING_STEP`. El primer flanco inicializa PC y ciclos, invalida pipeline y candidatos de fetch y pone RF en cero, a la vez que limpia la primera marca DMEM. RF x1–x31 se realiza con flip-flops e inicialización simultánea; x0 es constante cero. La preparación utiliza la inicialización local RF, sin dirección ni escritura de mantenimiento por su puerto normal.

`prepare_index` recorre una marca DMEM por clock. Dato físico y bitmap no se duplican: las mismas marcas determinan cero lógico y memoria utilizada en Debug. El índice representa C inclusive; sus anchos son doce bits en REFERENCE y diez en ALT_1000. La dirección de mantenimiento utiliza once y diez bits, respectivamente.

Al alcanzar C después de la última limpieza, `prepare_done` aparece combinacionalmente con inicialización y limpieza inactivas. El flanco que consume esa condición es distinto del último flanco de mantenimiento. En `PREPARING_READY` publica imagen y entra en READY sin ciclo CPU; en `PREPARING_RUN` o `PREPARING_STEP` conserva imagen y autoriza el primer ciclo con `cpu_cycle_fire`. STEP se observa después de ese ciclo, aunque `prepare_active` todavía valga uno antes del flanco.

En ambos perfiles, la preparación cumple el presupuesto máximo de 1 ms sin agregar una espera fija después del último clear.

El servicio conserva un índice de preparación, sin FSM privada ni registro de modo o finalización. Reset es prioritario. La preparación local no reinicia UART ni la Global FSM.

**Justificación:** La inicialización RF simultánea permite limpiar todas las marcas DMEM sin barrer RF por su puerto de escritura. Separar el flanco final evita mantenimiento concurrente con publicación o primer ciclo CPU. El bitmap compartido conserva cero lógico y listado Debug sin un clear masivo de los arrays.

#### Reset global

La petición física del botón, `uart_reset_request` registrado y la falta de estabilidad del clock se combinan antes del único `reset_sync`. La fuente de estabilidad es `!locked` cuando la plataforma lo expone; una variante sin esa señal fija esa fuente en cero, sin inventar otro indicador.

El acondicionador tiene dos etapas, aserción asíncrona y liberación sincronizada. Solo su salida llega a los consumidores funcionales, que muestrean reset al flanco. Las etapas se inicializan en uno y utilizan `ASYNC_REG`; la liberación requiere que desaparezcan todas las solicitudes y transcurran las dos etapas de sincronización.

En `WAIT_RESET_ACCEPT_SENT`, el último Stop de RESET/ACCEPTED habilita el registro de `uart_reset_request`. El reset se afirma después de esa respuesta y los consumidores lo muestrean en el siguiente flanco funcional, que también limpia la solicitud. La CPU puede avanzar hasta el reset efectivo. El botón físico puede solicitar reset en cualquier fase y abortar una transmisión sin finalización normal.

**Justificación:** Registrar la solicitud evita el lazo combinacional entre fin de respuesta, reset y supresión de ese mismo evento. El [acondicionamiento común](../architecture/platform/reset_integration.md) conserva prioridad del botón y consumo funcional síncrono sin crear un reset independiente por módulo.

#### Representación del estado global

Global FSM pertenece a Execution Control y conserva catorce estados: `NO_IMAGE`, `LOADING`, `PREPARING_READY`, `READY`, `RUNNING`, `STEPPING`, `HALT_DRAIN_AUTO`, `HALT_DRAIN_STEP`, `FAULT_DRAIN_AUTO`, `FAULT_DRAIN_STEP`, `FINISHED`, `FAULT`, `PREPARING_RUN`, `PREPARING_STEP`.

`global_state` utiliza catorce bits one-hot, en ese orden, con NO_IMAGE en el bit cero y como reset. El código externo de ocho bits es combinacional: 0x00 a 0x0D en el mismo orden. Llega desde `Execution Control.global_state_code` a `Response Serializer.debug_state_code`; el registro one-hot no se exporta para que otro bloque lo decodifique. `program_finished`, `fault_terminal` y demás controles proceden de la Global FSM. La vigencia de los metadatos de fault se interpreta a partir del código externo. Una representación interna inválida utiliza valores por defecto definidos; no crea un estado CPU ni un fault arquitectónico.

**Justificación:** El estado global conserva fase de sesión, ejecución y modalidad de drain. La [codificación de estado](../architecture/session/global_state_encoding.md) permite que la representación UART permanezca fija mientras la codificación interna utiliza un bit por estado, sin registros de observación duplicados. La elegibilidad y las transiciones pertenecen a [Execution Control](../architecture/session/execution_control.md).

#### Presupuestos de integración

| Recorrido             | Condición o cota de diseño                                                                                       |
| --------------------- | ---------------------------------------------------------------------------------------------------------------- |
| RX y LOAD             | Un clock desde incorporación en FIFO vacía hasta retiro y procesamiento, incluida cuarta entrega/escritura IMEM. |
| Quinto byte de tamaño | Validación completa, solicitud, aceptación y captura de respuesta en el flanco de retiro, sin fase intermedia.   |
| Separación RX         | Al menos 152 × 163 = 24.776 clocks entre eventos válidos de la FSM RX.                                           |
| Preparación           | C + 1 clocks: 2049 en REFERENCE y 1001 en ALT_1000, equivalentes a 40,98 y 20,02 µs.                             |
| Debug                 | `230 + 5*K` bytes y recorridos DMEM dentro de `W_debug`: 6100 ms para REFERENCE y 3400 ms para ALT_1000.         |

El período funcional es 20 ns. Las rutas de validación de tamaño, solicitud, aceptación y captura de respuesta deben cerrarlo; también el camino RUN/STEP que incluye autorización del ciclo cuando corresponde. El presupuesto RX usa flags previos al flanco y presupone retiro continuo, de modo que desde reset vacío la ocupación RX normal máxima es uno.

Las cotas y sus condiciones se desarrollan en [UART](../architecture/uart/uart_core.md#presupuesto-de-integración), [Loader](../architecture/session/loader.md#presupuesto-de-load), [preparación](../architecture/session/session_preparation.md#duración-y-alcance-de-revisión) y [serializador](../architecture/debug/response_serializer.md#presupuesto-de-transmisión-y-debug). Los plazos y la recuperación desde PC pertenecen al protocolo; estas cotas no son mediciones de timing ni resultados de placa.

**Justificación:** Comparar el procesamiento por clock con el ritmo UART fundamenta el consumo continuo con cuatro entradas. La preparación y serialización progresivas permiten comprobar sus plazos sin reservar buffers para el programa o el snapshot completos.

#### Consecuencias y verificación

La implementación debe conservar un productor y consumidor definidos para cada conexión, la independencia RX/TX, la captura con serializador libre, el orden físico de respuestas, el ciclo único STEP y la exclusión de observación. La [composición](../architecture/system_composition.md) y las [interfaces](../interfaces.md) fijan esos recorridos.

Las pruebas deben cubrir solicitudes y aceptación en el mismo flanco, quinto byte de tamaño, última escritura LOAD, publicación y respuesta posterior, STEP con preparación, terminal RUN antes/en/después del último Stop de ACCEPTED, recuperación RX con terminal pendiente, prioridades RESET y reset físico en cualquier fase. También deben comprobar errores, desbordamiento, flags previos al flanco, byte estable ante TX llena y fin físico del último byte.

La elaboración RTL, síntesis, cierre de timing de 50 MHz y validación del enlace y de la placa corresponden a la implementación y al [plan de verificación](../verification/verification_plan.md). Esta decisión fija diseño y condiciones de realización; no acredita esos resultados ni sustituye el cierre conjunto del sistema.

#### Requisitos relacionados

La decisión se vincula con los siguientes [requisitos del sistema](../requirements.md):

- UART: `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`.
- Debug: `REQ-DBG-001`, `REQ-DBG-002`, `REQ-DBG-003`, `REQ-DBG-005`, `REQ-DBG-010`, `REQ-DBG-011`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-016`.
- Sesión, memoria y timing: `REQ-EXEC-016`, `REQ-EXEC-017`, `REQ-MEM-010`, `REQ-TIM-002`.
- Documentación: `REQ-DOC-001`, `REQ-DOC-006`.
