# TP3 — UART, protocolo y Debug

- **Tipo:** catálogo de verificación.
- **Estado documental:** pruebas diseñadas, sin ejecutar.

## Propósito y alcance

Este documento reúne las pruebas del enlace UART, las FIFO, el protocolo y el serializador de Debug. Distingue la recepción de un byte, su procesamiento, la producción de una respuesta y el fin físico de la transmisión.

Las [convenciones, niveles y límites del plan](verification_plan.md) se aplican a todos los casos. Los contratos enlazados determinan el comportamiento; la [matriz](coverage.md) relaciona las pruebas con los requisitos y el trabajo fuera de alcance.

Los [modelos abstractos ejecutables](../../tools/verification/README.md) comprueban coordinación y recuperación; su ejecución no sustituye las pruebas RTL y de enlace descritas aquí.

## Índice

- [TEST-UART-001 — Tick, sincronización RX y tramas 8N1](#test-uart-001)
- [TEST-UART-002 — FIFO de cuatro bytes y flags preflanco](#test-uart-002)
- [TEST-UART-003 — Comandos binarios, disponibilidad y rechazos](#test-uart-003)
- [TEST-UART-004 — LOAD mínimo, completo y tamaño de 40 bits](#test-uart-004)
- [TEST-UART-005 — Timeout LOAD y prioridad error/byte/vencimiento](#test-uart-005)
- [TEST-UART-006 — Recuperación por silencio y error de opcode](#test-uart-006)
- [TEST-UART-007 — Snapshot fijo, RF y 34 campos de latches](#test-uart-007)
- [TEST-UART-008 — Lista de memoria usada y cantidad inclusiva](#test-uart-008)
- [TEST-UART-009 — TX llena, byte retenido y fin físico](#test-uart-009)
- [TEST-UART-010 — RUN/STEP completos y rechazo sin alterar sesión](#test-uart-010)
- [TEST-UART-011 — Exclusión Debug hasta el último Stop](#test-uart-011)
- [TEST-UART-012 — Orden de respuestas, terminal RUN y RESET](#test-uart-012)
- [TEST-UART-013 — RESET UART después de aceptación y botón](#test-uart-013)
- [TEST-UART-014 — Presupuestos del enlace integrado](#test-uart-014)

<a id="test-uart-001"></a>

## TEST-UART-001 — Tick, sincronización RX y tramas 8N1

- **Nivel:** unidad UART e integración uart_core.
- **Tipo de estímulo:** legal y errores físicos dirigidos.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-001](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-011](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [uart_baud_tick_gen](../architecture/uart/uart_baud_tick_gen.md); [uart_rx](../architecture/uart/uart_rx.md); [uart_tx](../architecture/uart/uart_tx.md); [uart_core](../architecture/uart/uart_core.md).

### Qué comprueba y por qué

Esta prueba comprueba la recepción y transmisión física de bytes 8N1 y la referencia compartida de ticks de sobremuestreo.

Busca detectar el orden de bits invertido, un muestreo que no respete `s_tick`, una trama inválida anunciada como byte válido o un fin de TX anterior al Stop completo.

Las dos fases de inicio comprueban que el generador continúe libre entre tramas. Los errores y resets comprueban que una trama interrumpida no termine como un byte válido.

### Condiciones iniciales

UART comienza después de reset, con clock funcional de 50 MHz, baud nominal de 19200, formato 8N1 y divisor 163.

La entrada RX pasa por el sincronizador de dos etapas. En la prueba física no se inyecta directamente en su segunda etapa. TX dispone del byte antes del flanco que acepta `tx_start`.

El clock y el generador de ticks se mantienen activos durante las observaciones. Cada byte y fase se prepara de manera independiente.

### Variantes cerradas

La prueba tiene 31 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-001/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 24 casos nominales combinan los seis bytes dirigidos con RX o TX y las dos fases de inicio.

Se agrega un recorrido del generador después de reset durante tres períodos. Los tres errores RX comprueban Start falso, Stop bajo y línea baja hasta volver a alto.

Un caso mantiene TX ocupada con el byte `0x55` mientras cambian `data_in` y `tx_start`. Los dos resets restantes interrumpen RX DATA y TX STOP, respectivamente.

### Estímulos concretos

Los bytes dirigidos son `00`, `FF`, `55`, `AA`, `01` y `80`. Cada uno se recibe y transmite con inicio en las fases 0 y 162 del generador: 6×2×2=24 tramas. Se observa además el generador durante tres períodos: primer tick registrado en el flanco 163 y consumido en 164.

Los tres errores RX son Start que vuelve alto antes de su muestra central, Stop bajo y línea sostenida baja que luego vuelve a alto. TX ocupada recibe cambios de data_in y otro tx_start para demostrar que conserva el byte original. Los dos resets interrumpen RX DATA y TX STOP, por separado.

### Procedimiento

1. **Preparar el inicio de trama.** Alinear la solicitud con la fase 0 o 162 del generador y conservar la anchura nominal de cada bit. TX espera sus 16 ticks de Start sin reiniciar `baud_tick_gen`.

2. **Recibir o transmitir el byte.** Observar los bits desde el menos significativo y comparar el dato reconstruido o enviado.

3. **Observar los eventos.** Comprobar un único done y el comportamiento de `busy`, `rx_receiving` y `rx_activity` según el estado.

4. **Aplicar las tramas inválidas.** Exigir que no se incorpore un byte a FIFO. El receptor debe esperar el retorno de la línea a alto en su recuperación.

5. **Aplicar TX ocupada y reset.** Comprobar que TX conserve el byte capturado y que reset aborte la trama sin un done normal, sin exigir conservar datos parciales.

### Resultados y criterio de aprobación

`s_tick` dura un clock y se repite cada 163 clocks; no es un reloj independiente. Después de reset, el primer tick se registra en el flanco 163 y se consume en 164.

RX utiliza dos etapas de sincronización, muestrea Start en el octavo tick y datos y Stop cada 16 ticks. Solo un Stop válido permite un byte recibido, una vez. Start falso o Stop inválido producen error sin byte.

`rx_activity` incluye cambios de línea, línea baja o trama en curso. `rx_receiving` corresponde a START, DATA o STOP; ambos indicadores valen cero durante reset.

TX captura el byte al iniciar, ignora cambios mientras está ocupada y anuncia el fin después del Stop completo. Reset suprime la finalización normal. Las FSM de RX y TX conservan sus codificaciones one-hot de cinco y cuatro estados.

La aprobación exige bytes, eventos e intervalos correctos en ambas fases. Estos casos no establecen una tolerancia a cualquier baud arbitrario.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-002"></a>

## TEST-UART-002 — FIFO de cuatro bytes y flags preflanco

- **Nivel:** unidad FIFO e integración UART.
- **Tipo de estímulo:** legal y overflow artificial.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-001](../requirements.md#7-uart-y-debug-unit), [REQ-UART-010](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-011](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [uart_fifo](../architecture/uart/uart_fifo.md); [uart_core](../architecture/uart/uart_core.md).

### Qué comprueba y por qué

Esta prueba comprueba que FIFO acepte lecturas y escrituras según la ocupación preflanco y conserve el orden de los bytes.

Busca detectar flags calculados con una ocupación futura, la pérdida del primer byte cuando llegan solicitudes simultáneas o un wrap incorrecto de punteros.

La FIFO transporta bytes; no interpreta comandos. El overflow local comprueba el error de recepción sin agregar una causa de fault de CPU.

### Condiciones iniciales

La FIFO tiene cuatro posiciones de ocho bits. La ocupación del caso se alcanza mediante escrituras aceptadas de `0x11`, `0x22`, `0x33` y `0x44`, sin forzar un contador contradictorio.

`read_data` presenta el byte más antiguo en preflanco cuando la FIFO no está vacía. Si `empty=1`, puede contener un residuo y no debe interpretarse como un byte disponible.

El overflow se fuerza localmente con un quinto byte sin retiro. Ese fixture no representa el tráfico normal de un host que cumple el protocolo.

### Variantes cerradas

La prueba tiene 21 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-002/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 16 vectores de solicitudes utilizan las cuatro ocupaciones previstas y las cuatro combinaciones de wr y rd.

Un caso comprueba el wrap mediante una secuencia de 12 bytes. Otro aplica reset con la cola llena y ambas solicitudes activas. Un caso comprueba overflow RX.

Los dos casos de integración restantes coinciden en llegada RX y retiro, con FIFO vacía o llena. Se mantienen las decisiones basadas en los flags preflanco.

### Procedimiento

1. **Preparar la ocupación.** Llenar la FIFO mediante operaciones aceptadas y guardar el primer dato y los flags preflanco.

2. **Aplicar wr y rd.** Dar el flanco y comparar las operaciones aceptadas y la ocupación postflanco con la variante.

3. **Observar los extremos.** Con FIFO vacía, el primer write no permite una lectura simultánea. Con FIFO llena, el retiro no permite aceptar un write en ese mismo flanco; el siguiente puede disponer del espacio.

4. **Seguir la secuencia larga.** Leer los 12 bytes y comprobar que el wrap de punteros conserve su orden.

5. **Aplicar reset y overflow.** Verificar las operaciones suprimidas por reset y el error UART combinado del quinto byte, sin generar una causa de CPU.

### Resultados y criterio de aprobación

Con FIFO vacía y wr y rd simultáneos, solo se acepta la escritura. Con FIFO llena, solo se acepta la lectura. En una ocupación intermedia se aceptan ambas, se conserva la cuenta y se entrega el dato preflanco.

Los bytes deben mantener su orden sin pérdidas ni duplicaciones. Los flags representan la ocupación de cero a cuatro. Una cola vacía puede mostrar residuos sin que sean datos válidos.

Reset pone la cuenta y los punteros en cero y suprime las operaciones del flanco, sin exigir borrar el array. El quinto byte produce overflow sin ampliar la capacidad.

La aprobación exige decisiones preflanco correctas en todas las fronteras y simultaneidades. El overflow es un error UART y no un nuevo fault arquitectónico.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-003"></a>

## TEST-UART-003 — Comandos binarios, disponibilidad y rechazos

- **Nivel:** unidad protocolo con stubCPU; sistema por UART-004/010.
- **Tipo de estímulo:** legal, tráfico fuera de fase y fixtures locales.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-003](../requirements.md#7-uart-y-debug-unit), [REQ-UART-004](../requirements.md#7-uart-y-debug-unit), [REQ-UART-007](../requirements.md#7-uart-y-debug-unit), [REQ-UART-008](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-001](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-003](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-011](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [protocol](../protocol.md); [protocol_controller](../architecture/debug/protocol_controller.md); [execution_control](../architecture/session/execution_control.md).

### Qué comprueba y por qué

Esta prueba comprueba la admisión de bytes según la fase de transporte, las solicitudes directas hacia Execution Control y las respuestas de los comandos admitidos. La elegibilidad interna de la Global FSM se comprueba por separado en TEST-EXEC-001: un byte descartado no llega a esa interfaz.

CHECK_READY consulta `load_available`, independientemente de `image_valid`; no reserva una LOAD posterior. Un byte de tamaño o programa pertenece a LOAD aunque coincida con un opcode.

### Condiciones iniciales

La unidad conecta FIFO RX, Controller, un sustituto de Execution Control y el serializador. El sustituto presenta `command_accepted`, `load_available`, `prepare_active`, `program_finished`, `fault_terminal`, `cpu_cycle_fire` e `image_valid`. `prepare_done` y `load_ok` son eventos internos del procesador y no entradas del Controller.

En `WAIT_COMMAND`, el serializador está libre, no hay preparación activa, resultado RUN pendiente ni observación retenida. READY, STEPPING, drains STEP y terminales conservan imagen válida; NO_IMAGE no. Los terminales de ese fixture ya completaron su intercambio Debug.

RUNNING y los drains AUTO se preparan en `WAIT_RUN_END`, con ACCEPTED completo, `prepare_active=0`, `run_result_required=1` y sin terminal observable. Los drains se sostienen mediante un fixture local; no se afirma que duren una trama real.

`cpu_reply_on_request` determina la aceptación de la única solicitud presentada. El sustituto calcula su respuesta desde la solicitud y la elegibilidad, sin que el Controller espere esa aceptación para generar la solicitud. Desde FINISHED o FAULT, RUN/STEP aceptados bajan los indicadores terminales e inician preparación; el Controller observa `prepare_active` y el primer `cpu_cycle_fire` posterior.

### Variantes cerradas

La prueba comprende 44 casos canónicos, enumerados en el [manifiesto](cases.json):

- C001–C030 combinan CHECK_READY, RUN y STEP con diez contextos CPU. Los 21 casos sin contexto AUTO comienzan en `WAIT_COMMAND`; los nueve AUTO comienzan en `WAIT_RUN_END` y comprueban tráfico fuera de fase sin respuesta.
- C031–C033 entregan `01 04 00 00 00 00` durante AUTO: el primer byte inicia recuperación y el resto se descarta, incluido el `04` que no debe convertirse en RESET.
- C034–C036 entregan los opcodes desconocidos `06`, `00` y `FF` con transporte disponible.
- C037–C044 entregan cuatro valores en tamaño o contenido LOAD; no son solicitudes de comando.

### Procedimiento

1. **Preparar fase y contexto coherentes.** Configurar los recursos anteriores al flanco y el serializador según la fase. No utilizar `WAIT_COMMAND` como fixture de un RUN en curso.

2. **Presentar el byte.** En `WAIT_COMMAND`, RUN/STEP generan su solicitud y consumen `command_accepted` en el mismo flanco. En `RECEIVE_LOAD_SIZE`, solo el quinto byte de un tamaño válido genera `load_request`. Observar los campos combinacionales con `response_start`, sin descriptor pendiente en el Controller.

3. **Comprobar comandos admitidos.** CHECK_READY responde según disponibilidad. RUN/STEP sin imagen presentan su solicitud, reciben rechazo y responden NO_IMAGE. Un STEP aceptado ejecuta en ese flanco o entra en `WAIT_STEP_END`; después produce DONE con Debug exactamente en el flanco de `cpu_cycle_fire`, aunque `prepare_active` todavía sea uno antes del flanco.

4. **Comprobar descarte durante RUN.** En los contextos AUTO, exigir ausencia de `load_request`, `run_request`, `step_request` y respuesta por el byte recibido. Comprobar `RECOVER_RX`, continuidad CPU y conservación de imagen. Los bytes restantes no quedan guardados.

5. **Comprobar datos y eco.** En `RECEIVE_LOAD_SIZE`, capturar en la posición correcta. En `RECEIVE_LOAD_DATA`, entregar y descontar exactamente una vez. Un opcode desconocido en `WAIT_COMMAND` captura su eco y UNKNOWN_COMMAND en el serializador en ese mismo flanco.

### Resultados y criterio de aprobación

| Fase y entrada                            | Resultado esperado                                                                                                   |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `WAIT_COMMAND`, CHECK_READY               | `05 03` cuando `load_available=1`; ninguna reserva. En los contextos legales de esta selección LOAD está disponible. |
| `WAIT_COMMAND`, RUN/STEP sin imagen       | `02 05` / `03 05`, solicitud presentada pero sin ciclo ni Debug.                                                     |
| `WAIT_COMMAND`, RUN/STEP elegibles        | RUN: `02 01` y resultado posterior; STEP: un ciclo y `03 02` con Debug, sin aceptación separada.                     |
| `WAIT_RUN_END`, CHECK_READY/RUN/STEP/LOAD | Sin respuesta ni solicitud de operación; entrada en `RECOVER_RX`; CPU continúa.                                      |
| `WAIT_COMMAND`, opcode desconocido        | Eco seguido de `0C`, respuesta corta y sin cambios de CPU o imagen.                                                  |
| Tamaño o contenido LOAD                   | Byte tratado como dato de su fase, sin interpretar comandos.                                                         |

Las respuestas de rechazo BUSY se seleccionan con imagen válida cuando una solicitud presentada es rechazada; no se espera BUSY como contestación al tráfico descartado durante RUN. Toda captura exige `response_busy=0`, campos correctos y un único productor de `response_start`. Las comprobaciones de prioridad interna permanecen en TEST-EXEC-001.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-004"></a>

## TEST-UART-004 — LOAD mínimo, completo y tamaño de 40 bits

- **Nivel:** sistema con UART físico.
- **Tipo de estímulo:** legal y tamaños rechazados.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-002](../requirements.md#7-uart-y-debug-unit), [REQ-UART-008](../requirements.md#7-uart-y-debug-unit), [REQ-UART-009](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-002](../requirements.md#7-uart-y-debug-unit), [REQ-MEM-003](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-010](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-012](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-015](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-024](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-030](../requirements.md#5-memorias-y-carga-de-programas), [REQ-EXEC-016](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [protocol](../protocol.md); [protocol_controller](../architecture/debug/protocol_controller.md); [loader](../architecture/session/loader.md); [session_preparation](../architecture/session/session_preparation.md).

### Qué comprueba y por qué

Esta prueba comprueba la carga completa de imágenes, la validación de su tamaño y la publicación posterior a la preparación.

Busca detectar un tamaño aceptado solo por sus bits bajos, una última palabra omitida o una confirmación enviada antes de preparar la sesión.

La imagen con palabra ilegal comprueba que LOAD transporta bytes y no decodifica la ISA: una carga binaria correcta puede producir un fault cuando se ejecute.

### Condiciones iniciales

La CPU tiene una imagen A de 16 bytes vigente en READY o STEPPING.

El host conoce el perfil, prepara todo el contenido y escucha TX durante el envío. No espera confirmaciones por cada palabra.

Los programas de tamaño máximo utilizan inmediatos ADDI desde cero hasta 254 o 248, según el perfil. Estos valores caben en los 12 bits de la instrucción.

### Variantes cerradas

La prueba tiene 18 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-004/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los cuatro tamaños válidos combinan los dos perfiles con una imagen de cuatro bytes o de capacidad completa. El host espera ACCEPTED completa antes de enviar el contenido.

Los 12 tamaños inválidos utilizan seis valores por perfil, conservando los 40 bits hasta completar su validación. Los dos casos restantes cargan la palabra ilegal cero, uno por perfil.

La selección no agrega otras combinaciones de instrucciones ni filtros de ISA durante LOAD.

### Procedimiento

1. **Consultar disponibilidad y enviar la cabecera.** Enviar CHECK_READY y después opcode `01` con N sin signo, codificado en cinco bytes little-endian.

2. **Observar el quinto byte y la aceptación.** Antes de ese flanco, comparar el candidato de 40 bits formado por el byte actual y los cuatro registrados. Validar antes de reducir ancho. Si se acepta, `load_request`, `command_accepted`, `remaining_load` y la captura de `01 01` coinciden; tamaño y restantes reciben N. Si se rechaza, esperar `01 06`, sin solicitud ni contenido. Esperar el último Stop de ACCEPTED antes de transmitir programa.

3. **Enviar y reconstruir la imagen.** Transmitir N bytes y comparar las N/4 palabras IMEM. Cada `load_byte_valid` entrega y decrementa una vez; el offset usa N menos restantes preflanco. La última entrega activa `load_last_byte`, escribe la última palabra y certifica `load_ok` en ese mismo flanco, sin una palabra extra.

4. **Observar preparación y respuesta.** Tras la última entrega, exigir `WAIT_PREP_DONE` y `prepare_active=1`. En el flanco P de `PREPARING_READY && prepare_done`, Execution Control publica tamaño y alcanza READY sin ciclo CPU; el Controller todavía ve preparación activa y no captura DONE. En P+1, 20 ns después, captura `01 02` con `prepare_active=0`, RF preparado y DMEM lógicamente en cero. El reset durante preparación se define en TEST-UART-013/C009; debe impedir publicar una imagen parcial.

5. **Ejecutar la imagen ilegal cargada.** Después de DONE completa, comprobar que la ejecución produzca causa 2 en PC cero. Ese resultado pertenece al decoder, no a un rechazo de LOAD.

### Resultados y criterio de aprobación

Una carga aceptada invalida el tamaño anterior y reconstruye las N/4 palabras, sin confirmaciones intermedias ni bloqueo de RX por TX.

`01 02` se captura en el serializador un clock después del commit de preparación a READY, sin un ciclo CPU. La preparación cumple el presupuesto de 1 ms; no se escribe una palabra extra ni se omite la última.

Los tamaños inválidos devuelven `01 06` y conservan la sesión. Los bits altos no pueden truncarse para obtener 4 u otro tamaño admitido.

La palabra ilegal puede cargarse y recibir DONE; al ejecutarla aparece FAULT por instrucción ilegal. La aprobación exige IMEM y estado correctos en cada fase, validación completa de 40 bits y los mismos códigos y layout en ambos perfiles.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-005"></a>

## TEST-UART-005 — Timeout LOAD y prioridad error/byte/vencimiento

- **Nivel:** unidad controlador e integración UART.
- **Tipo de estímulo:** recepción interrumpida y coincidencias locales.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-008](../requirements.md#7-uart-y-debug-unit), [REQ-UART-009](../requirements.md#7-uart-y-debug-unit), [REQ-UART-010](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-011](../requirements.md#7-uart-y-debug-unit), [REQ-MEM-024](../requirements.md#5-memorias-y-carga-de-programas), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [protocol](../protocol.md); [protocol_controller](../architecture/debug/protocol_controller.md).

### Qué comprueba y por qué

Esta prueba comprueba el timeout de inactividad de LOAD y la prioridad entre error UART, byte válido y vencimiento del temporizador.

Busca detectar una cuenta iniciada al encolar ACCEPTED en lugar de esperar su Stop, o un error perdido porque un byte simultáneo completa una fase o habilita una escritura.

Los bytes en la frontera de T comprueban que el timeout no descarte una entrega válida en el mismo flanco.

### Condiciones iniciales

Antes de aceptar LOAD se conserva una imagen de 16 bytes y una cabecera de tamaño parcial. Después de aceptar la LOAD de tamaño 8, el tamaño confirmado es cero y el contenido está parcialmente recibido.

Los cinco bytes de N=8 son `08 00 00 00 00`. Su último byte cero completa un tamaño válido.

T representa 100 ms reales en las mediciones. Solo los casos locales de prioridad precargan el contador para situar las coincidencias en la frontera; no sustituyen una medición física de la recepción.

### Variantes cerradas

La prueba tiene 24 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-005/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los cuatro escenarios incompletos dejan dos bytes de tamaño recibidos o uno, tres o cuatro bytes de contenido.

Los ocho escenarios de frontera repiten esas cuatro situaciones con un byte válido en T-1 o T. El byte no completa la fase y debe reiniciar su supervisión.

Los 12 vectores locales combinan fase de tamaño o contenido, byte final o no final y las tres coincidencias previstas. En contenido, el byte no final ocupa offset 3 y el final offset 7. No se agregan otros cruces.

### Procedimiento

1. **Preparar la recepción parcial.** Comprobar si LOAD ya fue aceptada y guardar la imagen que debe conservar vigencia o permanecer inválida.

2. **Iniciar T en su evento correcto.** Para tamaño, comenzar después del opcode `01`; para contenido, después del Stop final de `01 01`. En el enlace físico, coordinar `rx_done` y su consumo con el flanco observado.

3. **Aplicar la coincidencia.** Observar error, byte válido y timeout en preflanco y comparar la prioridad: error, después byte válido y finalmente timeout.

4. **Observar el resultado.** Un error debe abortar sin escritura coincidente y devolver `01 09`. Si prevalece el byte, debe suprimirse el timeout y reiniciarse o completarse la fase.

5. **Completar la recuperación.** Ante silencio vencido, comprobar `01 07` o `01 08`, la vigencia de imagen correspondiente y la recuperación de RX sin reset de TX.

### Resultados y criterio de aprobación

Un tamaño incompleto devuelve `01 07` y conserva imagen y sesión. Un contenido incompleto devuelve `01 08` y mantiene tamaño confirmado cero.

T comienza después del opcode para tamaño y después del Stop de ACCEPTED para contenido. Cada byte válido reinicia T mientras falten bytes; al completar la fase termina esa supervisión.

Error UART prevalece sobre byte válido, y byte válido prevalece sobre timeout. El error devuelve `01 09`; durante contenido activa `load_abort` e impide entrega, decremento y escritura coincidentes. En tamaño no activa aborto del Loader y conserva la imagen anterior. Un último byte válido en el límite completa la fase: el quinto byte puede aceptar LOAD y el último de contenido escribe IMEM en ese flanco. Cambios de línea, línea baja o una trama sin byte válido no reinician T; los escenarios incompletos comienzan una trama 10.000 clocks antes de T, sin byte completo ni error hasta T. Esa actividad no prolonga el plazo; los bytes posteriores ya pertenecen a recuperación.

No se agrega un timeout total de transferencia ni campos extra a los comandos de un byte. La aprobación exige respuesta, temporizador, imagen y escrituras correctos en cada fase, sin publicar una imagen parcial.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-006"></a>

## TEST-UART-006 — Recuperación por silencio y error de opcode

- **Nivel:** sistema e integración controlador/UART.
- **Tipo de estímulo:** errores físicos e inyección local de overflow.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-010](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-011](../requirements.md#7-uart-y-debug-unit), [REQ-EXEC-015](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [protocol](../protocol.md); [uart_rx](../architecture/uart/uart_rx.md); [protocol_controller](../architecture/debug/protocol_controller.md).

### Qué comprueba y por qué

Esta prueba comprueba silencio continuo de recuperación, actividad RX y continuidad de TX y CPU. También comprueba que recuperar el transporte durante RUN no habilite comandos normales.

Start falso, Stop inválido y overflow llegan como error UART. Las variantes LOAD distinguen un error anterior a la aceptación de otro durante contenido.

### Condiciones iniciales

Los errores de Start y Stop utilizan RX físico. El overflow se provoca localmente con FIFO llena y otra recepción, conservando bytes y ocupación coherentes. Un byte centinela `A5` en uart_core local permite comprobar que no se resetea TX.

La imagen anterior tiene 16 bytes. En tamaño LOAD todavía es válida; en contenido de tamaño 8 ya fue invalidada al aceptar. Durante RUN, ACCEPTED terminó, la preparación está inactiva y el Controller está en `WAIT_RUN_END` con `run_result_required=1`.

R son 5.000.000 clocks, 100 ms a 50 MHz. `rx_activity` incluye transiciones, línea baja y trama en curso; el Controller no recibe `rx_receiving`. Los eventos físicos y los valores observados en su interfaz deben concordar.

### Variantes cerradas

La prueba comprende ocho casos canónicos del [manifiesto](cases.json):

- C001–C003: Start falso, Stop inválido y overflow en `WAIT_COMMAND`/READY. C002 incluye comandos descartados, residuos, actividad cerca del límite, línea baja y trama en curso.
- C005: Stop inválido durante RUN; al recuperar, la CPU sigue ejecutando y se vuelve a `WAIT_RUN_END`.
- C008 y C011: Stop inválido en tamaño y contenido LOAD, respectivamente.
- C013 y C014: terminal FINISHED durante `RECOVER_RX`, con R completo antes o después del último Stop Debug.

El tráfico válido fuera de fase durante RUN y su recuperación sin respuesta se reutilizan de TEST-UART-003, sin duplicar sus IDs.

### Procedimiento

1. **Provocar el error.** Exigir `RECOVER_RX` y reinicio del contador. Un error sin LOAD interpretada no produce respuesta; un error en tamaño/contenido produce `01 09`, con `load_abort` solo durante contenido.

2. **Comprobar actividad en C002.** Consumir y descartar `05`, `04` y residuos. Aplicar cambios, línea baja y trama en curso cerca del límite. Cada `rx_activity` reinicia R, incluso cuando el contador ya estaba saturado; no se guardan comandos ni se aplica reset global.

3. **Completar R.** Exigir silencio continuo, FIFO vacía, serializador libre y Debug liberado. La actividad domina el vencimiento; sin actividad, el contador satura mientras falte otra condición. La actividad sin byte válido no reinicia el timeout LOAD, comprobado en TEST-UART-005.

4. **Cruzar R con Debug.** En C013, R se completa primero y la recuperación permanece hasta el Stop Debug. En C014, una actividad un flanco antes del Stop reinicia R y `RECOVER_RX` continúa después de liberar Debug. El terminal se entrega una vez y no interrumpe la cuenta.

5. **Comprobar el destino.** C005 vuelve a `WAIT_RUN_END`, conserva la obligación RUN y solo admite RESET en su ventana; no se envía una consulta normal. Los otros casos vuelven a `WAIT_COMMAND` después de terminar sus respuestas y pueden recibir un CHECK_READY nuevo. Los comandos descartados no se reproducen.

### Resultados y criterio de aprobación

Los errores de opcode conservan imagen y sesión sin respuesta; durante RUN la CPU continúa. Un error de tamaño devuelve UART_ERROR conservando la imagen anterior; uno de contenido aborta y mantiene el tamaño confirmado en cero.

TX no se resetea. Un terminal RUN durante recuperación conserva el orden respecto de su ACCEPTED, activa retención y se entrega exactamente una vez; `run_result_required` se limpia al capturarlo en el serializador, y `debug_hold` al último Stop.

R completo no basta si quedan bytes, respuesta o Debug. Si RUN sigue activo se recupera su fase de espera, no la admisión general. La aprobación exige destinos correctos, ausencia de comandos diferidos y ambos órdenes entre silencio y fin físico.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-007"></a>

## TEST-UART-007 — Snapshot fijo, RF y 34 campos de latches

- **Nivel:** unidad serializador e integración Debug.
- **Tipo de estímulo:** fixture retenido artificial y snapshot legal STEP.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-DBG-005](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-006](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-007](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-008](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-009](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-013](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-014](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-016](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-017](../requirements.md#7-uart-y-debug-unit), [REQ-UART-005](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [protocol](../protocol.md); [debug_architecture](../architecture/debug/debug_architecture.md); [response_serializer](../architecture/debug/response_serializer.md); [cpu_pipeline](../architecture/cpu/cpu_pipeline.md).

### Qué comprueba y por qué

Esta prueba comprueba que el serializador envíe el layout fijo del snapshot con los campos registrados, sus anchos y su orden de bytes.

Busca detectar offsets incorrectos, padding o little-endian mal aplicados, la omisión de payloads inválidos o la lectura de valores combinacionales futuros.

El fixture local puede combinar campos que una CPU legal no produce juntos. Comprueba el transporte de esos campos y no demuestra alcanzabilidad end-to-end.

### Condiciones iniciales

El banco prepara el contexto y el Register File del caso. El patrón de registros es `xi=0x01010101*i`; los campos de latches tienen los anchos y valores de `latch_fixture` en el [manifiesto](cases.json), con índices 31, 30 y 29 y selectores legales.

La lista de memoria usada está vacía, con K=0. La cabecera es STEP/DONE, `03 02`. Los 34 campos registrados de los cuatro latches se mantienen disponibles para el serializador.

Una entrada de latch válida dentro del contexto artificial FAULT no se interpreta como una ejecución legal. El cambio a STEPPING conserva los bits de causa y PC de fault para comprobar su vigencia, no su borrado físico.

### Variantes cerradas

La prueba tiene 7 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-007/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

El primer caso utiliza el fixture completo. Otros dos modifican los flags de IF/ID para representar un candidato de fetch o un residuo inválido.

Tres casos invalidan ID/EX, EX/MEM o MEM/WB por separado, conservando sus otros campos. El último cambia el contexto de FAULT a STEPPING sin sustituir los bits residuales de metadatos.

En cada caso se modifica solo la diferencia indicada respecto del fixture base. Los bytes esperados están enumerados y no se agregan cruces entre las invalidaciones.

### Procedimiento

1. **Preparar y retener el fixture.** Presentar contexto, Register File y latches y conservarlos durante la producción. TX se ofrece sin backpressure en esta prueba.

2. **Capturar la respuesta.** Comparar los 230 bytes de cabecera y cuerpo con `response_bytes` del [manifiesto](cases.json). Los offsets del protocolo empiezan en el cuerpo, sin contar la cabecera.

3. **Observar los campos inválidos.** Comprobar que los cambios de `valid` no sustituyan los demás datos por cero. El flag de candidato de fetch de IF/ID no debe confundirse con el fault global.

4. **Comprobar la vigencia de metadatos.** En STEPPING, los bytes de causa y PC de fault pueden conservarse, pero no deben interpretarse como metadatos vigentes.

5. **Relacionar el caso local con sistema.** El snapshot legal postflanco de STEP se comprueba en TEST-UART-010, sin atribuir esa alcanzabilidad al fixture de serialización.

### Resultados y criterio de aprobación

El cuerpo debe utilizar los siguientes offsets: estado en 0, validez de imagen en 1, PC en 2, contador en 6, causa en 14 y PC de fault en 15. El Register File comienza en `19+4*i`; los latches comienzan en 147, 158, 188 y 208; `used_count`, en 223.

Los datos multibyte son little-endian y el padding superior es cero. Los cuatro latches contienen 5, 15, 8 y 6 campos y ocupan 76 bytes serializados. No se agregan IDs ni campos combinacionales.

El Register File incluye `x0=0` y `x31`, leyendo el dato base de Debug antes del bypass. El payload inválido se transmite sin reemplazarlo por cero; sus flags determinan la vigencia.

Los metadatos globales solo son vigentes en los estados de fault. El candidato de fetch permanece separado. Con K=0, la respuesta completa tiene 230 bytes.

La aprobación exige coincidencia de todos los campos, flags, padding, residuos y byte final con el fixture independiente.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-008"></a>

## TEST-UART-008 — Lista de memoria usada y cantidad inclusiva

- **Nivel:** unidad serializador e integración CPU/Debug.
- **Tipo de estímulo:** stores legales y fixtures de bitmap.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-DBG-010](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-012](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-013](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-015](../requirements.md#7-uart-y-debug-unit), [REQ-MEM-008](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-029](../requirements.md#5-memorias-y-carga-de-programas), [REQ-UART-005](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [protocol](../protocol.md); [debug_architecture](../architecture/debug/debug_architecture.md); [response_serializer](../architecture/debug/response_serializer.md).

### Qué comprueba y por qué

Esta prueba comprueba que Debug cuente y liste los bytes utilizados del estado lógico de DMEM, una sola vez y en orden creciente.

Busca detectar una cuenta limitada a valores distintos de cero, la duplicación de direcciones sobrescritas o la omisión del último byte cuando la capacidad no es potencia de dos.

La lista representa el estado actual de la sesión. No es un historial de stores ni una copia de todos los bytes físicos.

### Condiciones iniciales

La CPU comienza con una sesión limpia. Los operandos se preparan mediante un fixture de unidad o mediante instrucciones legales cuyos efectos se registran.

Los fixtures del serializador utilizan capacidades 2048 y 1000. Las marcas se definen mediante `bitmap_kind`; cada dato físico de dirección a contiene `a mod 256`.

El Register File, contexto y latches permanecen retenidos con los valores del fixture base de TEST-UART-007. Esa preparación local permite comprobar el listado sin atribuir todos sus valores a una ejecución legal.

### Variantes cerradas

La prueba tiene 10 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-008/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Un caso ejecuta la secuencia de stores, sobrescritura y lectura y luego prepara una sesión nueva.

Los ocho fixtures de capacidad combinan 2048 o 1000 bytes con lista vacía, solo el último byte, primero y último, o todos los bytes utilizados.

El último caso representa la cantidad `2^32` en cinco bytes. Es una comprobación aritmética aislada: no asigna ni recorre una memoria de esa capacidad.

### Procedimiento

1. **Preparar los stores o el bitmap.** Instalar la secuencia o las marcas de la variante, conservando el estado durante el envío.

2. **Contar las marcas.** Recorrer de cero a `C-1`, incluida la última posición. Conservar K y reiniciar solo el cursor para el listado.

3. **Enviar las entradas.** Enumerar cada dirección utilizada una vez, en orden creciente y con su dato actual. Las consultas utilizan la dirección preflanco.

4. **Comparar cantidad y longitud.** Revisar los cinco bytes de cuenta, la longitud `230+5K` y cada entrada. Con K=0 no debe haber entradas ni marcador final.

5. **Comprobar la sesión del programa.** Exigir la lista `(0,34)`, `(1,56)`, `(3,00)`; la lectura de dirección 2 no agrega una entrada. Al preparar la siguiente sesión, la lista debe quedar vacía.

### Resultados y criterio de aprobación

El programa produce K=3 con las entradas `(0,34)`, `(1,56)` y `(3,00)`, únicas y crecientes. El store de cero agrega dirección 3; la sobrescritura no duplica dirección 1; el load no agrega dirección 2.

La lista vacía no tiene entradas. La posición `C-1` debe aparecer cuando su marca esté activa.

Las cantidades 2048, 1000 y `2^32` se codifican como `00 08 00 00 00`, `E8 03 00 00 00` y `00 00 00 00 01`. Las longitudes de los casos son 230, 235, 240, 10470 o 5230 bytes, según K.

Los dos recorridos cuentan y envían el mismo estado retenido, sin historial ni otro bitmap obligatorio. La aprobación exige cantidad, orden, dirección, dato y última entrada correctos, sin wrap del cursor ni búsqueda posterior a la última entrada.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-009"></a>

## TEST-UART-009 — TX llena, byte retenido y fin físico

- **Nivel:** unidad serializador/controlador e integración UART.
- **Tipo de estímulo:** backpressure local dirigido.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-005](../requirements.md#7-uart-y-debug-unit), [REQ-UART-009](../requirements.md#7-uart-y-debug-unit), [REQ-UART-010](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-015](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [response_serializer](../architecture/debug/response_serializer.md); [uart_fifo](../architecture/uart/uart_fifo.md); [uart_core](../architecture/uart/uart_core.md); [protocol_controller](../architecture/debug/protocol_controller.md).

### Qué comprueba y por qué

Esta prueba comprueba que el serializador conserve el byte preparado cuando TX no admite escritura y que una respuesta termine solo después de su último Stop físico.

Busca detectar la pérdida o recaptura del byte pendiente, el avance de un cursor por una escritura rechazada o una finalización anunciada al encolar el último byte.

La atención RX se comprueba en el controlador con TX llena. La retención del serializador y el procesamiento de RX tienen estímulos separados; un caso de integración comprueba su coexistencia durante RECOVER_RX y un Debug terminal de RUN.

### Condiciones iniciales

En unidad de serializador se prepara un byte disponible y un cursor estable. FIXED utiliza el byte `03`; COUNT utiliza `used_count=123` e índice cero; ENTRY utiliza dirección 5, índice 4 y dato `A5`.

La FIFO TX llena contiene cuatro bytes pendientes y `tx_full=1` en preflanco. El byte preparado no debe incorporarse mientras ese flag permanezca activo. Los valores de sus fuentes pueden cambiar durante la espera para comprobar que no se recapturen.

C002 es un fixture artificial del Controller: `RECEIVE_LOAD_SIZE`, índice cero y tamaño parcial cero, con TX forzada llena y ocupada por el banco. Esa combinación no demuestra alcanzabilidad normal, pues la fase mantiene libre el serializador. Aísla la independencia de `rd_uart` respecto de TX. C004 prepara `RECOVER_RX` con el mismo byte `55` y TX ocupada; allí se descarta.

C006 integra el controlador y el serializador durante RECOVER_RX con un Debug terminal RUN/FINISHED ya aceptado por el serializador. La exclusión está activa y ENTRY conserva el byte `A5` en dirección 5 mientras TX está llena. El byte RX `55` debe descartarse sin modificar el estado observado.

### Variantes cerradas

La prueba tiene 9 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-009/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

C001, C003 y C005 comprueban la retención en FIXED, COUNT y ENTRY. C002 comprueba el procesamiento de tamaño en RECEIVE_LOAD_SIZE y C004 el descarte en RECOVER_RX, con TX llena y ocupada en ambos casos.

C006 comprueba la integración de RECOVER_RX con el envío Debug terminal. Ese envío no implica que se reciba una LOAD durante la exclusión.

C007 aplica enqueue y fin físico simultáneos con dos bytes pendientes; la cuenta siguiente sigue siendo dos. C008 y C009 siguen LOAD/ACCEPTED y STEP/DONE con K=0. C008 incluye el cierre de LOAD/DONE en `WAIT_RESPONSE_SENT` sin retención Debug, como segundo intercambio de esa misma carga.

### Procedimiento

1. **Mantener el byte pendiente.** En C001, C003 y C005, mantener TX llena durante tres clocks. Comparar el byte, su disponibilidad y el cursor después de cada flanco. Cambiar la fuente de entrada durante la espera y exigir que el valor preparado se conserve.

2. **Comprobar la liberación de espacio.** Producir el Stop que retira un byte de FIFO. Si full era uno en preflanco, el serializador no puede escribir en ese mismo flanco. Debe aceptar una sola escritura en el clock siguiente, con el byte conservado y el avance de cursor correspondiente.

3. **Observar RX en el controlador.** En C002 y C004, escribir `55` en FIFO RX en E y observar su consumo en E+1. RECEIVE_LOAD_SIZE debe guardar el byte bajo y pasar su índice de cero a uno. RECOVER_RX debe descartarlo sin admitir una orden nueva. TX llena u ocupada no debe retrasar esas acciones.

4. **Comprobar la integración durante recuperación.** En C006, observar simultáneamente el descarte de RX y la retención de ENTRY. Después de liberar espacio, el byte TX debe enviarse una sola vez. CPU y el estado de Debug permanecen retenidos; el tráfico recibido no produce respuesta ni una orden nueva.

5. **Comprobar pendientes y cierre.** En C007, enqueue y `tx_done_tick` simultáneos conservan dos pendientes. En C008, el Stop de ACCEPTED inicia contenido con contador cero; al completar esa carga y preparación, LOAD/DONE cierra `WAIT_RESPONSE_SENT` sin `debug_hold`. En C009, STEP/DONE limpia `debug_hold` en el Stop final. En ambos cierres, `response_busy` era uno antes del flanco y pasa a cero después; no se captura otra respuesta en el mismo flanco del Stop.

### Resultados y criterio de aprobación

El byte preparado, su disponibilidad y el cursor se conservan mientras no haya una escritura aceptada. Liberar espacio no permite utilizar un flag full futuro: la primera escritura ocurre en el flanco siguiente y no pierde ni duplica el byte.

Con TX llena y ocupada, RX se consume en E+1. RECEIVE_LOAD_SIZE guarda `55` como primer byte del tamaño; RECOVER_RX lo descarta sin alterar el tamaño ni admitir una orden nueva. La integración de RECOVER_RX con Debug conserva estas reglas y la exclusión de CPU.

Los incrementos y decrementos simultáneos de pendientes se compensan. `response_done_tick` se produce en WAIT_TX_DONE, con producción completa, un pendiente y `tx_done_tick`; coincide con el último Stop sin un registro extra de evento.

La aprobación exige las tres políticas de retención, las dos acciones RX, la integración durante RECOVER_RX y el fin físico de ambas clases de respuesta. Ninguna liberación de exclusión, inicio de timeout o petición de reset puede adelantarse al Stop que le corresponde.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-010"></a>

## TEST-UART-010 — RUN/STEP completos y rechazo sin alterar sesión

- **Nivel:** sistema.
- **Tipo de estímulo:** legal y solicitudes rechazadas.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-003](../requirements.md#7-uart-y-debug-unit), [REQ-UART-004](../requirements.md#7-uart-y-debug-unit), [REQ-UART-005](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit), [REQ-EXEC-007](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-010](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DBG-001](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-003](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-004](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-013](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-017](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [protocol](../protocol.md); [protocol_controller](../architecture/debug/protocol_controller.md); [execution_control](../architecture/session/execution_control.md).

### Qué comprueba y por qué

Esta prueba comprueba el intercambio completo de RUN y STEP y el snapshot posterior a los efectos de CPU.

Busca detectar una aceptación adicional en STEP, un terminal RUN perdido mientras se transmite ACCEPTED o una captura anterior al último commit.

Los rechazos y el descarte durante exclusión se comprueban mediante los grupos reutilizados; no se agregan otras transacciones propias.

### Condiciones iniciales

La CPU comienza con una sesión limpia y un programa cargado. Los cuatro programas normales preparan `x2=3` mediante ADDI en PC cero antes de ejecutar las instrucciones del escenario.

Esa instrucción cuenta en los ciclos y snapshots. En la secuencia ilegal, el `fault_pc` es 16. El programa de `halt` único no utiliza ese prefijo.

El host espera la respuesta completa antes del siguiente STEP. Los programas de comparación sin UART utilizan el mismo setup para que la observación no cambie los efectos arquitectónicos.

### Variantes cerradas

La prueba tiene 5 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-010/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los cuatro intercambios normales combinan RUN o STEP con terminación FINISHED o FAULT.

En STEP se envía una orden por cada avance, incluidos los ciclos de drain. Esos pasos pertenecen a la misma transacción y no forman otro producto de variantes.

El quinto caso ejecuta un `halt` único mediante RUN. El terminal CPU llega antes del fin físico de ACCEPTED, por lo que deben conservarse ambas respuestas.

También se ejecutan las comprobaciones reutilizadas de [TEST-UART-003](#test-uart-003), [TEST-UART-011](#test-uart-011). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para los casos `C001`, `C002`, correspondientes al escenario FINISHED, se utiliza el siguiente programa:

```asm
addi x2,x0,3
addi x8,x0,11
addi x9,x0,12
sw x2,4(x0)
halt
```

Para los casos `C003`, `C004`, correspondientes al escenario FAULT, se utiliza el siguiente programa:

```asm
addi x2,x0,3
addi x8,x0,11
addi x9,x0,12
sw x2,4(x0)
.word 0x00000000
```

Para el caso `C005`, se utiliza el siguiente programa:

```asm
halt
```

### Procedimiento

1. **Preparar el programa y el host.** Cargar la imagen y comprobar la sesión inicial.

2. **Ejecutar RUN.** Enviar `02`, recibir ACCEPTED completa y esperar el terminal, sin un timeout de duración del programa.

3. **Ejecutar STEP.** Enviar `03`, recibir DONE con Debug y repetir hasta terminal. En C002 y C004, después del último Stop terminal enviar un STEP adicional: debe preparar una sesión nueva con la misma imagen y ejecutar un único primer ciclo. Comparar ese snapshot con el primer STEP desde READY. Esta segunda fase no reanuda el pipeline terminal ni cambia los programas enumerados.

4. **Observar el postflanco.** Comparar RF, DMEM, contexto y latches con los commits del mismo ciclo. En STEP inmediato, captura de `03 02` y `debug_hold_set` coinciden con aceptación y `cpu_cycle_fire`. Tras preparación, `WAIT_STEP_END` produce esas acciones en el primer `cpu_cycle_fire`, aunque `prepare_active` todavía sea uno en preflanco. No debe ejecutar otro ciclo por esperar el serializador. [TEST-EXEC-002/C021](execution.md#test-exec-002) comprueba reset durante esa preparación, incluida la salida del Controller de su espera, sin ciclo ni respuesta STEP.

5. **Comparar cabeceras y estado final.** Todo STEP utiliza `03 02`, incluso con fault o drain. RUN utiliza ACCEPTED y después FINISHED o FAULT. Comparar los efectos con CPU sin UART y el mismo programa.

### Resultados y criterio de aprobación

RUN debe enviar `02 01` antes de `02 0A` o `02 0B` con el snapshot posterior al último commit. La terminación rápida no puede perder la respuesta final.

STEP envía únicamente `03 02` con snapshot, sin aceptación separada, incluso para `halt`, fault y drain. El último paso ya muestra el terminal.

Una orden rechazada con transporte disponible no genera ciclo ni Debug asociado. El tráfico fuera de fase durante RUN se descarta según TEST-UART-003, sin contestar un rechazo ni cancelar su terminal. RF y DMEM coinciden con la ejecución sin observación. Los STEP adicionales de C002/C004 se comparan desde una sesión nueva equivalente.

La aprobación exige cantidad y orden de respuestas correctos, un ciclo por STEP aceptado y datos postflanco coherentes. La cabecera de respuesta y el estado observado se interpretan por separado.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-011"></a>

## TEST-UART-011 — Exclusión Debug hasta el último Stop

- **Nivel:** integración local protocolo/CPU/serializador; reset de sistema.
- **Tipo de estímulo:** fixtures locales con tráfico durante descarte y reset físico.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-DBG-004](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-012](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-013](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-015](../requirements.md#7-uart-y-debug-unit), [REQ-UART-005](../requirements.md#7-uart-y-debug-unit), [REQ-UART-006](../requirements.md#7-uart-y-debug-unit), [REQ-MEM-019](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-028](../requirements.md#5-memorias-y-carga-de-programas).

**Contratos:** [protocol](../protocol.md); [debug_architecture](../architecture/debug/debug_architecture.md); [protocol_controller](../architecture/debug/protocol_controller.md).

### Qué comprueba y por qué

Esta prueba comprueba que el estado observado permanezca retenido desde el ciclo de CPU hasta el último Stop de Debug, incluida la espera previa al envío.

Busca detectar una modificación de registros o marcas durante la observación, la interpretación de un comando recibido bajo exclusión o una orden que quede guardada para ejecutarse después.

Los comandos y las fronteras de exclusión se comprueban con una lista pequeña. Un recorrido con la lista completa comprueba la conservación del estado durante un envío prolongado.

### Condiciones iniciales

Se utiliza REFERENCE y se conserva una copia del estado postflanco de CPU: Register File, PC, latches, contador, contexto y marcas de DMEM.

Los casos ordinarios tienen K=1, con dirección 5 utilizada y dato `A5`. C021 tiene las 2048 marcas activas y dato físico `a mod 256` en cada dirección. Ese caso observa la retención hasta terminar la lista completa.

En el contexto RUN, su propia respuesta ACCEPTED sigue ocupando TX cuando se alcanza el terminal. En STEP, la exclusión comienza después del ciclo observado. Las comprobaciones locales conectan protocolo, CPU y serializador y entregan los bytes mediante FIFO RX; las tramas 8N1 reales se comprueban en TEST-UART-014 y TEST-PLAT-005.

Para la espera previa, los bytes se consumen antes de comenzar la cabecera Debug. Para el cuerpo, se consumen durante la parte fija, lejos del último byte. LOAD utiliza la cabecera `01 04 00 00 00 00`, con un byte por flanco de consumo; los otros comandos utilizan únicamente su opcode.

E identifica el flanco que consume el último Stop de Debug. En los casos de LOAD sobre esa frontera, el opcode se consume en E-5 y los cinco bytes de tamaño en E-4, E-3, E-2, E-1 y E. Cada byte se escribe en FIFO un flanco antes de su consumo. Para un comando de un byte, se escribe en E-1 y se consume en E. Así, todos los bytes del caso llegan mientras la exclusión todavía está activa en preflanco.

### Variantes cerradas

La prueba tiene 31 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-011/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

C001–C030 combinan los dos contextos, tres instantes —espera previa, cuerpo y último Stop— y LOAD, RUN, STEP, RESET o CHECK_READY. Todos utilizan K=1, salvo C021, que envía una LOAD durante el cuerpo del Debug terminal RUN con K=2048.

En C011 y C026, la frontera se refiere al consumo del último byte de tamaño LOAD. El opcode y los otros cuatro bytes se consumen antes de E. En los otros casos de último Stop, el único opcode se consume en E.

C031 aplica el botón durante el cuerpo del snapshot posterior a STEP, con K=1. El envío debe abortarse por reset global y el host debe descartar esa respuesta parcial.

### Procedimiento

1. **Preparar y conservar la observación.** Alcanzar el ciclo STEP o terminal RUN y guardar el estado postflanco. En RUN, comprobar `run_result_required && (program_finished || fault_terminal)` y `debug_read_select` inmediatamente después del flanco terminal, antes de registrar `debug_hold`. Mantener RUN/ACCEPTED ocupando el serializador: la selección común RF/DMEM ya debe estar activa aunque Debug todavía no pueda capturarse.

2. **Entregar los bytes del caso.** Escribirlos en FIFO RX y observar su consumo en los flancos indicados. Para la espera y el cuerpo, exigir exclusión activa durante todo el mensaje. En la frontera E, comprobar su valor preflanco y observar simultáneamente el descarte del último byte RX y el fin físico de Debug.

3. **Comparar el estado retenido.** Durante la espera y el envío, comprobar que Register File, PC, latches, contador, contexto y marcas conserven sus valores. No debe haber ciclos CPU, LOAD, preparación ni respuestas provocadas por los bytes descartados. En C021, mantener estas comprobaciones durante toda la lista de 2048 entradas.

4. **Comprobar la reapertura.** Después de E, entregar un CHECK_READY y un STEP nuevos mediante el transporte disponible. Deben interpretarse conforme al estado observado, sin ejecutar ningún byte descartado. La expectativa de descarte corresponde a bytes consumidos hasta E; los que se entregan después se comprueban como solicitudes nuevas.

5. **Aplicar el botón en C031.** Solicitar reset durante el cuerpo, sin esperar una respuesta UART. Exigir NO_IMAGE y aborto del mensaje. El host conserva su último snapshot completo y descarta el parcial como nueva observación.

### Resultados y criterio de aprobación

La exclusión comienza después del ciclo y sus commits. `debug_read_select = !reset && (debug_hold || (run_result_required && (program_finished || fault_terminal)))` selecciona simultáneamente las fuentes Debug de RF y DMEM, cada una con su dirección propia, durante espera y envío. No habilita escrituras. Reset fuerza esa selección a cero.

Hasta E, UART continúa funcionando y los bytes RX se consumen y descartan sin producir respuestas ni comandos guardados. El estado observado y las marcas de DMEM se conservan, incluida la lista completa de C021.

En E, la exclusión preflanco todavía impide interpretar el byte RX del caso. El Stop final permite liberar la observación después del flanco; una solicitud nueva entregada después se interpreta conforme al estado actual.

RESET UART se descarta durante exclusión. El botón tiene prioridad, aborta la respuesta y deja el parcial sin validez como snapshot nuevo.

La aprobación exige retención de todos los campos, ownership correcto de Register File y DMEM, descarte de cada mensaje y reapertura posterior al Stop. El recorrido completo comprueba duración; las variantes restantes comprueban comandos y fronteras con la misma regla de exclusión.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-012"></a>

## TEST-UART-012 — Orden de respuestas, terminal RUN y RESET

- **Nivel:** integración controlador/serializador y sistema.
- **Tipo de estímulo:** cruces dirigidos.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-003](../requirements.md#7-uart-y-debug-unit), [REQ-UART-008](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-015](../requirements.md#7-uart-y-debug-unit), [REQ-EXEC-007](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [protocol](../protocol.md); [protocol_controller](../architecture/debug/protocol_controller.md); [response_serializer](../architecture/debug/response_serializer.md).

### Qué comprueba y por qué

Esta prueba comprueba el orden ACCEPTED/terminal RUN, la entrega única del resultado durante recuperación y la prioridad temporal entre terminal y RESET. Las decisiones utilizan valores anteriores al flanco.

Busca detectar una captura con el serializador ocupado, la pérdida o duplicación del terminal y un resultado del RUN cancelado por RESET. Durante RUN no se abre recepción de cabeceras LOAD ni de CHECK_READY.

### Condiciones iniciales

El fixture conecta Controller y serializador, con `run_result_required=1`. Los indicadores terminales son excluyentes: FINISHED utiliza `program_finished=1`; FAULT, `fault_terminal=1`. Execution Control mantiene el estado terminal y los datos observados.

E es el flanco del último Stop de RUN/ACCEPTED. `response_busy` vale uno antes de E y cero después; `response_done_tick` se consume en E. Las variantes con evento terminal controlan cuándo su indicador se vuelve observable; no cambian la duración física de un ciclo CPU.

En recuperación, ACCEPTED ya terminó. En RESET reconocido, no hay terminal observable ni preparación activa antes del flanco; en RESET descartado, el indicador terminal ya vale uno antes del flanco.

### Variantes cerradas

Los 14 casos propios del [manifiesto](cases.json) combinan FINISHED o FAULT con estos siete cruces. El programa `halt` único de TEST-UART-010/C005 se reutiliza como recorrido físico rápido, sin contarlo otra vez ni atribuirle un FAULT.

### Qué significa cada cruce

| Cruce                              | Situación antes del flanco                                                                                 | Resultado esperado                                                                                 |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| A — terminal anterior al Stop      | Terminal observable antes de E, con ACCEPTED en curso.                                                     | Retener y conservar obligación; capturar terminal en E+1, después de liberar el serializador.      |
| B — terminal en el flanco del Stop | El último ciclo CPU y el Stop ocurren en E; terminal observable después de E.                              | Pasar por `WAIT_RUN_END`; capturar terminal en E+1 y continuar en `WAIT_RESPONSE_SENT`.            |
| C — terminal posterior al Stop     | CPU continúa después de E; el terminal se observa más tarde en `WAIT_RUN_END`.                             | Capturar resultado con serializador libre y transmitirlo una vez.                                  |
| D — R antes de Debug               | `RECOVER_RX`, terminal pendiente y R cumplido mientras Debug sigue ocupado.                                | Completar Debug antes de volver a `WAIT_COMMAND`; conservar recuperación hasta reunir condiciones. |
| E — Debug antes de R               | `RECOVER_RX`, terminal enviado y silencio todavía incompleto.                                              | Liberar Debug sin omitir la recuperación ni admitir nuevos comandos.                               |
| F — RESET con último ciclo         | `WAIT_RUN_END`, indicadores terminales en cero; RESET se reconoce en el mismo flanco del último ciclo CPU. | Capturar `04 01`, cancelar obligación y aplicar reset después del Stop; no enviar terminal RUN.    |
| G — terminal ya observable         | `WAIT_RUN_END`, terminal indicado y RESET disponible antes del flanco.                                     | Descartar RESET y enviar únicamente el terminal con Debug; no solicitar reset global.              |

C001–C007 corresponden a A–G con FINISHED; C008–C014, a A–G con FAULT. D y E concretan los dos órdenes de recuperación reutilizados por TEST-UART-006.

### Procedimiento

1. **Preparar el cruce coherente.** Obtener las fases desde aceptación, ejecución y recuperación, o inicializar un fixture equivalente y clasificarlo como integración local. No combinar una cabecera LOAD en recepción con un RUN pendiente.

2. **Seguir A, B y C.** Observar `run_result_required`, `debug_hold`, `response_busy`, `response_start` y campos. En E no puede capturarse el terminal mientras `response_busy` siga uno en preflanco. En B, el indicador terminal aparece después de E; la decisión de E no utiliza el estado futuro.

3. **Seguir D y E.** Entregar el resultado en `RECOVER_RX`, sin reiniciar ni detener el contador por la transmisión. Exigir FIFO vacía, silencio, serializador libre y Debug liberado para salir.

4. **Seguir F y G.** En F, limpiar la obligación al reconocer RESET aunque el terminal aparezca después del flanco. En G, prevalece el terminal ya observable: RESET no genera respuesta ni solicitud registrada.

5. **Comparar mensajes completos.** Contar capturas y bytes. FINISHED usa `02 0A` y FAULT `02 0B`, ambos con Debug; cada mensaje termina físicamente antes del siguiente.

### Resultados y criterio de aprobación

ACCEPTED precede al resultado final en A–E y G. La obligación permanece hasta capturar el resultado, se limpia en ese flanco y no vuelve a producir otra captura. `debug_hold` cubre la espera y todo Debug hasta el último Stop.

F produce RESET/ACCEPTED y ningún terminal del RUN cancelado; G produce terminal RUN y ningún RESET/ACCEPTED. Los bytes fuera de fase no crean LOAD ni una respuesta corta concurrente.

La aprobación exige un único productor de `response_start`, capturas solo con serializador libre y cierre de `WAIT_RESPONSE_SENT` con retención liberada únicamente al fin físico. Un cierre de respuesta corta sin `debug_hold` se comprueba en TEST-UART-003 y TEST-UART-009.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-013"></a>

## TEST-UART-013 — RESET UART después de aceptación y botón

- **Nivel:** sistema e integración reset.
- **Tipo de estímulo:** legal y fixtures artificiales de descarte.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-006](../requirements.md#7-uart-y-debug-unit), [REQ-UART-007](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit), [REQ-EXEC-015](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DBG-015](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [protocol](../protocol.md); [reset_integration](../architecture/platform/reset_integration.md); [protocol_controller](../architecture/debug/protocol_controller.md).

### Qué comprueba y por qué

Esta prueba comprueba que RESET UART se aplique después de transmitir físicamente su aceptación y que el botón conserve su prioridad de reset.

Busca detectar un reset que aborte su propia respuesta, una petición UART sin registro o una conexión que reinicie el MMCM por RESET UART.

Los casos de drain se observan localmente mediante el evento reconocido. No se prolongan artificialmente los clocks de CPU para hacerlos durar una trama.

### Condiciones iniciales

El clock está estable, con `locked=1`, y el botón está inactivo. UART se encuentra disponible en una fase permitida.

La CPU continúa según su estado mientras se transmite `04 01`. Si comienza en FAULT, la imagen sigue confirmada hasta que se aplique reset.

E identifica el fin físico del segundo byte, incluido su Stop. La secuencia E+1 a E+4 supone que no permanezca otra fuente de reset activa.

### Variantes cerradas

La prueba tiene 16 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-013/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los seis contextos UART son RUNNING, FAULT y los cuatro drains. RUNNING y drains AUTO utilizan `WAIT_RUN_END`; FAULT y drains STEP, `WAIT_COMMAND` después de terminar su Debug. Los drains breves utilizan un fixture local coherente con esas fases, sin cambiar el clock físico.

C007–C010 aplican el botón durante RUN, LOAD, PREPARING_READY y Debug. La comprobación de reset durante `WAIT_STEP_END`/PREPARING_STEP se define en [TEST-EXEC-002/C021](execution.md#test-exec-002), incluida la cancelación de la espera del Controller sin respuesta STEP.

C011–C016 son fixtures artificiales de un flanco con byte RESET válido. Preparan, respectivamente, `WAIT_RUN_ACCEPT_SENT`, `WAIT_RUN_END` con preparación activa, `WAIT_LOAD_ACCEPT_SENT`, `WAIT_PREP_DONE`, `WAIT_STEP_END` y `WAIT_RESPONSE_SENT` con respuesta corta. Se comprueba retiro y descarte, sin respuesta adicional, petición de reset ni comando guardado. No se afirma que cada ventana dure una trama UART física; los indicadores y recursos preflanco se enumeran en el manifiesto.

El descarte de RESET UART durante Debug o RECOVER se comprueba mediante las reutilizaciones, sin agregar otras fases propias.

También se ejecutan las comprobaciones reutilizadas de [TEST-UART-006](#test-uart-006), [TEST-UART-011](#test-uart-011). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Procedimiento

1. **Reconocer RESET en C001–C006.** Utilizar `WAIT_COMMAND` sin intercambio pendiente o `WAIT_RUN_END` con ACCEPTED completo, preparación inactiva e indicadores terminales en cero. Capturar `04 01` directamente en el serializador y limpiar `run_result_required`, sin reset ni pausa CPU anticipados. En FAULT, el Debug previo ya terminó y el transporte está en `WAIT_COMMAND`; no preparar ese caso con un terminal RUN todavía debido. Las prioridades coincidentes se reutilizan de los cruces F y G de TEST-UART-012.

2. **Seguir el fin físico en C001–C006.** En E, registrar `uart_reset_request=1`. Observar reset en los consumidores en E+1, la liberación en E+2 y E+3 y el primer flanco libre en E+4.

3. **Comparar el estado después de reset UART o botón.** Exigir imagen inválida, PC, Register File y contador en cero y latches inválidos.

4. **Consultar disponibilidad después de reset.** En C001–C010, enviar `05` después de liberar reset y comprobar `05 03`. C011–C016 solo comprueban descarte y no abren una consulta durante el intercambio activo.

5. **Comprobar descarte y botón.** En C011–C016, consumir el byte y conservar fase y obligación, sin `response_start` ni `uart_reset_request`; la CPU solo responde a su autorización propia. En C007–C010 aplicar el botón: un Debug parcial no es una observación nueva. TEST-EXEC-002/C021 comprueba que un STEP todavía en preparación no ejecute su ciclo ni quede pendiente. Las comprobaciones reutilizadas cubren descarte UART durante Debug y recuperación.

### Resultados y criterio de aprobación

La respuesta `04 01` termina antes del reset. La CPU puede ejecutar hasta el flanco E que registra la petición; en E+1 ya consume reset. Reconocer RESET cancela `run_result_required` del RUN anterior. En las fases de aceptación, preparación, Debug y recuperación el byte RESET se descarta; C011–C016 y las variantes reutilizadas comprueban esas ventanas, sin extender el reconocimiento a ellas.

En E+1 los consumidores ven reset. E+2 y E+3 completan su liberación, y E+4 es el primer flanco libre si no hay otra fuente activa.

El sistema queda en NO_IMAGE, con PC, Register File y contador en cero, imagen y latches inválidos y UART y FIFO reiniciadas. CHECK_READY devuelve `05 03`.

El botón puede abortar sin esperar la respuesta ni producir FINISHED. La aprobación exige una petición UART registrada que evite el lazo combinacional y ambas fuentes integradas en el reset común, sin reiniciar el MMCM por UART.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-014"></a>

## TEST-UART-014 — Presupuestos del enlace integrado

- **Nivel:** sistema UART y revisión de cotas.
- **Tipo de estímulo:** legal sin ralentización artificial.
- **Estado:** cotas comprobadas por cálculo; medición RTL pendiente.

**Requisitos:** [REQ-UART-001](../requirements.md#7-uart-y-debug-unit), [REQ-UART-009](../requirements.md#7-uart-y-debug-unit), [REQ-UART-010](../requirements.md#7-uart-y-debug-unit), [REQ-MEM-025](../requirements.md#5-memorias-y-carga-de-programas), [REQ-EXEC-016](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DBG-015](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [uart_core](../architecture/uart/uart_core.md); [loader](../architecture/session/loader.md); [session_preparation](../architecture/session/session_preparation.md); [response_serializer](../architecture/debug/response_serializer.md); [protocol](../protocol.md).

### Qué comprueba y por qué

Esta prueba comprueba los presupuestos del enlace integrado mediante bytes UART reales y sus eventos de inicio y fin.

Busca detectar una recepción detenida por TX, un procesamiento que desborde la FIFO o una respuesta que exceda las cotas del protocolo.

Cada ventana se mide desde su evento definido. No se utiliza una marca genérica del host ni se convierte el tiempo de ejecución de RUN en un timeout de programa.

### Condiciones iniciales

UART utiliza clock de 50 MHz, divisor 163 y FIFO de cuatro posiciones. Se prepara una imagen de tamaño máximo N según el perfil.

N indica los bytes de la imagen. C y Cd representan la capacidad de DMEM en bytes, y K representa la cantidad de direcciones utilizadas que deben incluirse en la lista.

Para Debug se producen K=0, K=1 o K igual a toda la capacidad de DMEM. La lista completa se crea mediante el loop SW indicado: `x3=Cd/4`, que vale 512 o 250; SW ocupa PC 12, BNE ocupa PC 24 con offset `-12` y `halt` ocupa PC 28.

Los stores de cero también activan marcas de memoria utilizada. No se introduce backpressure artificial en esta medición.

### Variantes cerradas

La prueba tiene 10 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-014/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los dos casos de LOAD continuo utilizan una imagen de capacidad IMEM completa, una por perfil. La preparación se mide dentro de esa misma transferencia.

Los dos casos breves envían CHECK_READY, uno por perfil. Los seis casos de Debug combinan K=0, K=1 o K=Cd con ambos perfiles.

La memoria completa se prepara mediante Cd/4 iteraciones de un loop, sin desplegar un programa que exceda IMEM.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para los casos `C003`, `C008`, se utiliza el siguiente programa:

```asm
halt
```

Para los casos `C004`, `C009`, se utiliza el siguiente programa:

```asm
addi x2,x0,0
sb x2,0(x0)
halt
```

Para los casos `C005`, `C010`, se utiliza el siguiente programa:

```asm
addi x1,x0,0
addi x2,x0,0
addi x3,x0,C/4
sw x2,0(x1)
addi x1,x1,4
addi x3,x3,-1
bne x3,x0,-12
halt
```

### Procedimiento

1. **Enviar LOAD continua.** Medir la escritura en FIFO en E y el consumo en E+1 hasta la última palabra. Observar la ocupación máxima y la independencia respecto de TX.

2. **Medir preparación y DONE.** Comprobar Cd+1 clocks de preparación y el Stop final de DONE dentro de `N*10*1000/19200+201` ms desde el inicio del contenido.

3. **Preparar y ejecutar los programas de Debug.** Generar las tres ocupaciones y ejecutar RUN hasta su terminal. Medir la parte fija desde la cabecera completa y la lista desde `used_count` completo, sin limitar la duración previa del programa.

4. **Comparar las cotas.** Contrastar los clocks de cada respuesta y las ventanas de 319 ms para la parte fija y `ceil(5*K*10*1000/19200+200)` ms para la lista.

5. **Observar fin físico y caminos combinacionales.** Todas las mediciones terminan en su Stop. Correlacionar solicitud, aceptación, `cpu_cycle_fire` y captura de respuesta en un mismo flanco, así como el candidato de tamaño del quinto byte. La revisión RTL y el análisis estático deben comprobar ausencia de lazos y cumplimiento del período funcional de 20 ns; los modelos abstractos y las cotas UART no acreditan ese timing.

Las cotas se recalculan con el [comando reproducible](../../tools/verification/README.md), sin ejecutar el DUT. Para los estímulos de recuperación PC se reutiliza `RecoveryChecks`: consulta válida, segundo silencio, fragmentación, bytes pendientes, RESET único y cruces con RUN. Su ejecución con reloj virtual no certifica el enlace ni un cliente implementado.

### Resultados y criterio de aprobación

RX procesa cada byte en un clock. Desde FIFO vacía, la ocupación normal máxima es uno y no hay overflow con el flujo válido. La preparación utiliza C+1 clocks y queda por debajo de 50000.

A 50 MHz, las cotas conservadoras en clocks son:

- Respuesta corta: `2*26083+16`.
- Parte fija con cabecera: `230*26083+C+16`.
- Lista con K mayor que cero: `(5*K+1)*26083+C+16`.
- Respuesta Debug completa: `(230+5*K)*26083+2*C+16`.

`26083` incluye la trama de `160*163` clocks, uno de separación y dos de producción. La cota fija incluye la cabecera conservadoramente; la lista reserva un byte por el comienzo de su ventana. Con K=0 no se transmite lista. Para comparar una respuesta corta con los 200 ms desde la solicitud también se cuenta la recepción y el procesamiento de esa solicitud.

LOAD termina dentro de `N*10*1000/19200+201` ms desde el inicio de contenido. Las respuestas cortas y aceptaciones cumplen 200 ms; la parte fija de Debug cumple 319 ms; la lista cumple `ceil(5*K*10*1000/19200+200)` ms.

RUN no tiene timeout de duración. Las ventanas del host comprueban el fixture del enlace, sin certificar la aplicación final.

La aprobación exige ambos perfiles dentro de todas las cotas, midiendo desde los eventos correctos hasta el Stop físico. Una evidencia abstracta previa no sustituye la medición del RTL.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.
