# TP3 — UART, protocolo y Debug

- **Tipo:** catálogo de verificación.
- **Estado documental:** pruebas diseñadas, sin ejecutar.

## Propósito y alcance

Este documento reúne las pruebas del enlace UART, las FIFO, el protocolo y el serializador de Debug. Distingue la recepción de un byte, su procesamiento, la producción de una respuesta y el fin físico de la transmisión.

Las [convenciones, niveles y límites del plan](verification_plan.md) se aplican a todos los casos. Los contratos enlazados determinan el comportamiento; la [matriz](coverage.md) relaciona las pruebas con los requisitos y el trabajo fuera de alcance.

## Índice

- [TEST-UART-001 — Tick, sincronización RX y tramas 8N1](#test-uart-001)
- [TEST-UART-002 — FIFO de cuatro bytes y flags preflanco](#test-uart-002)
- [TEST-UART-003 — Comandos binarios, disponibilidad y rechazos](#test-uart-003)
- [TEST-UART-004 — LOAD mínimo, completo y tamaño de40 bits](#test-uart-004)
- [TEST-UART-005 — Timeout LOAD y prioridad error/byte/vencimiento](#test-uart-005)
- [TEST-UART-006 — Recuperación por silencio y error de opcode](#test-uart-006)
- [TEST-UART-007 — Snapshot fijo, RF y34 campos de latches](#test-uart-007)
- [TEST-UART-008 — Lista de memoria usada y cantidad inclusiva](#test-uart-008)
- [TEST-UART-009 — TX llena, byte retenido y fin físico](#test-uart-009)
- [TEST-UART-010 — RUN/STEP completos y rechazo sin alterar sesión](#test-uart-010)
- [TEST-UART-011 — Exclusión Debug hasta el último Stop](#test-uart-011)
- [TEST-UART-012 — Orden de respuestas y terminal RUN durante LOAD](#test-uart-012)
- [TEST-UART-013 — RESET UART después de aceptación y botón](#test-uart-013)
- [TEST-UART-014 — Presupuestos medidos del enlace integrado](#test-uart-014)

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
- **Tipo de estímulo:** legal y solicitudes no elegibles.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-003](../requirements.md#7-uart-y-debug-unit), [REQ-UART-004](../requirements.md#7-uart-y-debug-unit), [REQ-UART-007](../requirements.md#7-uart-y-debug-unit), [REQ-UART-008](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-001](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-003](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-011](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [protocol](../protocol.md); [protocol_controller](../architecture/debug/protocol_controller.md); [execution_control](../architecture/session/execution_control.md).

### Qué comprueba y por qué

Esta prueba comprueba la interpretación de comandos, la disponibilidad de LOAD y los rechazos del protocolo según el estado de CPU.

Busca detectar un byte de programa tratado como comando, una disponibilidad confundida con la validez de imagen o una orden rechazada que produzca un ciclo de ejecución.

CHECK_READY informa disponibilidad actual. No reserva ni garantiza la aceptación de una LOAD posterior.

### Condiciones iniciales

La unidad de protocolo se conecta a FIFO RX, a un sustituto controlado de CPU y a un serializador libre. El banco presenta el código de estado actual de la variante.

READY y los terminales tienen una imagen válida; NO_IMAGE no la tiene. El sustituto mantiene un estado de drain AUTO durante la observación local, sin afirmar que ese estado dure una trama UART en CPU real.

Los intercambios físicos de sistema se comprueban en TEST-UART-004 y TEST-UART-010. En esta unidad se observan la respuesta y las solicitudes de CPU o Loader, sin modificar la imagen por una orden rechazada.

### Variantes cerradas

La prueba tiene 44 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-003/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 30 casos de estado y comando combinan CHECK_READY, RUN y STEP con NO_IMAGE, READY, RUNNING, STEPPING, los cuatro drains, FINISHED y FAULT. Sus códigos son 0 y 3 a 11.

Tres casos reciben una cabecera LOAD completa y válida de tamaño 4 en los tres estados AUTO. Tres casos utilizan los opcodes desconocidos `06`, `00` y `FF`.

Los ocho casos restantes entregan cuatro valores de byte en las fases de tamaño o contenido de LOAD. Esos valores pertenecen a la fase activa y no crean nuevas órdenes.

### Procedimiento

1. **Preparar el estado y el transporte.** Presentar el código CPU actual, la imagen válida o inválida y la fase de protocolo del caso.

2. **Entregar la solicitud.** Aplicar el opcode o la cabecera LOAD completa de tamaño 4. La decisión debe usar el estado actual, no el que resultaría de aceptar la orden.

3. **Comparar la respuesta.** Verificar los dos bytes binarios y las solicitudes dirigidas a CPU o Loader. No interpretar ASCII como una codificación alternativa.

4. **Comprobar los datos de LOAD.** En READ_SIZE y LOAD_DATA, entregar el byte y observar el avance de la fase, sin ejecutar RUN, STEP o RESET por su valor.

5. **Revisar los rechazos.** Comprobar ausencia de ciclo o Debug asociado y conservación de la sesión. Una consulta previa no debe convertirse en una reserva.

### Resultados y criterio de aprobación

CHECK_READY devuelve `05 03` si LOAD está disponible o `05 04` durante AUTO. No conserva una consulta ni una reserva.

Desde NO_IMAGE, RUN y STEP devuelven `02 05` y `03 05`, sin ciclo ni Debug. Las solicitudes incompatibles devuelven `02 04` o `03 04`. Una LOAD incompatible devuelve `01 04` después de recibir la cabecera completa y conserva la ejecución.

Un opcode desconocido devuelve su eco seguido de `0C`, sin modificar CPU ni imagen. Los bytes de LOAD se procesan como tamaño o contenido.

La aprobación exige códigos, longitudes y efectos correctos. Toda respuesta utiliza opcode y resultado binarios, y cada LOAD se valida independientemente de CHECK_READY.

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

2. **Observar rechazo o aceptación.** Si el tamaño se rechaza, esperar `01 06` y no enviar contenido. Si se acepta, esperar los dos bytes `01 01` hasta el último Stop.

3. **Enviar y reconstruir la imagen.** Transmitir los N bytes seguidos y comparar las N/4 palabras de IMEM desde dirección cero, incluida la última.

4. **Observar la preparación.** Comprobar `load_ok` con el último byte y la publicación posterior al consumir `prepare_done`. DONE debe llegar después de READY, con CPU inactiva, Register File preparado y estado lógico de DMEM en cero.

5. **Ejecutar la imagen ilegal cargada.** Después de DONE completa, comprobar que la ejecución produzca causa 2 en PC cero. Ese resultado pertenece al decoder, no a un rechazo de LOAD.

### Resultados y criterio de aprobación

Una carga aceptada invalida el tamaño anterior y reconstruye las N/4 palabras, sin confirmaciones intermedias ni bloqueo de RX por TX.

`01 02` se envía solo después del commit de preparación a READY, sin un ciclo CPU. La preparación cumple el presupuesto de 1 ms; no se escribe una palabra extra ni se omite la última.

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

Error UART prevalece sobre byte válido, y byte válido prevalece sobre timeout. El error devuelve `01 09`, aborta la carga e impide una escritura coincidente del cuarto byte.

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

Esta prueba comprueba que la recuperación de RX requiera silencio continuo y conserve TX y la sesión de CPU según la fase donde ocurre el error.

Busca detectar una reapertura mientras la línea sigue activa, un reset accidental de TX o el abandono de una respuesta terminal pendiente al terminar la recuperación.

Start falso, Stop inválido y overflow deben llegar al controlador como error UART. Sus rutas de entrada se comprueban en READY; las diferencias entre opcode, tamaño y contenido se comprueban con Stop inválido. La secuencia completa de actividad durante RECOVER utiliza un solo recorrido.

### Condiciones iniciales

Los errores de Start y Stop se aplican a RX físico. El overflow se provoca localmente mediante una FIFO RX llena y una recepción adicional; no se fuerza un contador incompatible con sus bytes almacenados.

La imagen anterior tiene 16 bytes y está confirmada antes del error. En tamaño LOAD todavía no se aceptó una imagen nueva. En contenido LOAD ya se aceptó tamaño 8, por lo que el tamaño confirmado es cero.

Para observar la conservación de TX se utiliza el byte centinela `A5` en uart_core local. El caso de opcode en RUNNING mantiene una ejecución continua que permite comprobar que RECOVER no la detenga.

R representa 100 ms de silencio real. En C013 y C014, el fixture de integración entrega una terminación FINISHED de RUN durante RECOVER y sitúa el fin de R antes o después del último Stop de Debug.

### Variantes cerradas

La prueba tiene 8 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-006/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

C001, C002 y C003 comprueban Start falso, Stop inválido y overflow al interpretar un opcode en READY. C002 también ejecuta la secuencia completa de comandos descartados, residuos, actividad próxima a R, línea baja y trama en curso.

C005 aplica Stop inválido al opcode durante RUNNING. C008 lo aplica al tamaño LOAD y C011 al contenido LOAD. Estos tres casos comprueban la respuesta y la conservación o invalidez de la sesión; después verifican la reapertura mediante silencio continuo.

C013 y C014 comprueban los dos órdenes entre recuperación y fin de Debug. Completar R antes del Stop debe conservar la exclusión; completar el Stop antes de R debe conservar RECOVER.

### Procedimiento

1. **Preparar el contexto y provocar el error.** Conservar el estado de CPU y de la imagen. Aplicar el error del caso y comprobar la entrada a RECOVER, la ausencia de respuesta para un opcode no confiable o `01 09` durante LOAD.

2. **Comprobar la actividad de recuperación en C002.** Enviar `05`, `04` y residuos, y verificar que se consuman sin respuesta ni comandos guardados. Producir actividad cerca de R, mantener la línea baja y dejar una trama en curso en los pasos previstos. Cada condición debe impedir la reapertura; después de la última actividad, la cuenta de silencio debe comenzar nuevamente.

3. **Completar el silencio del caso.** En los recorridos de entrada, dejar la línea en reposo y exigir R completo, `rx_receiving=0`, FIFO RX vacía y respuestas terminadas antes de admitir una orden nueva. C002 completa este paso después de su secuencia de actividad; los otros cinco recorridos lo hacen después de resolver el error.

4. **Comprobar los dos órdenes con Debug.** En C013, terminar R mientras Debug continúa y exigir que la admisión permanezca inhibida hasta su Stop final. En C014, presentar actividad RX un flanco antes del Stop de Debug y comprobar que reinicie R; después del Stop, RECOVER debe continuar hasta completar los 100 ms contados desde la última actividad. Mantener RX en reposo entre los dos eventos finales para conservar el orden de cada variante.

5. **Enviar una consulta nueva.** Una vez cumplidas todas las condiciones de salida, enviar CHECK_READY. Debe responder la disponibilidad del contexto sin ejecutar ninguno de los bytes descartados. Comprobar que TX se haya conservado y que RUN no se haya detenido por la recuperación.

### Resultados y criterio de aprobación

Los tres errores deben activar la recuperación. Un error de opcode no produce un eco confiable ni una respuesta; conserva la imagen y, durante RUNNING, permite que CPU continúe.

Un error de tamaño LOAD devuelve `01 09` y conserva la imagen anterior. Un error de contenido devuelve el mismo código, pero mantiene el tamaño confirmado en cero.

En C002, los comandos y residuos se consumen sin producir efectos. La actividad reinicia R y ninguna línea baja, trama en curso o FIFO no vacía permite reabrir la recepción. TX se conserva sin reset global.

Una terminación RUN durante RECOVER se transmite una sola vez, después de cualquier respuesta breve pendiente. El último Stop libera la exclusión Debug, pero la admisión también requiere completar la recuperación.

La aprobación exige las tres rutas de error, los efectos propios de cada contexto, el silencio continuo y ambos órdenes de salida. La secuencia de actividad completa y las mediciones de R deben concordar con esas mismas reglas.

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

La atención RX se comprueba en el controlador con TX llena. La retención del serializador y el procesamiento de RX tienen estímulos separados; un caso de integración comprueba su coexistencia durante RECOVER y un Debug terminal de RUN.

### Condiciones iniciales

En unidad de serializador se prepara un byte disponible y un cursor estable. FIXED utiliza el byte `03`; COUNT utiliza `used_count=123` e índice cero; ENTRY utiliza dirección 5, índice 4 y dato `A5`.

La FIFO TX llena contiene cuatro bytes pendientes y `tx_full=1` en preflanco. El byte preparado no debe incorporarse mientras ese flag permanezca activo. Los valores de sus fuentes pueden cambiar durante la espera para comprobar que no se recapturen.

En unidad de controlador se prepara RX con el byte `55` y TX llena y ocupada. READ_SIZE comienza con índice cero y tamaño parcial cero. RECOVER debe consumir ese mismo byte y descartarlo; estos fixtures no necesitan activar un envío Debug.

C006 integra el controlador y el serializador durante RECOVER con un Debug terminal RUN/FINISHED ya aceptado por el serializador. La exclusión está activa y ENTRY conserva el byte `A5` en dirección 5 mientras TX está llena. El byte RX `55` debe descartarse sin modificar el estado observado.

### Variantes cerradas

La prueba tiene 9 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-009/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

C001, C003 y C005 comprueban la retención en FIXED, COUNT y ENTRY. C002 comprueba el procesamiento de tamaño en READ_SIZE y C004 el descarte en RECOVER, con TX llena y ocupada en ambos casos.

C006 comprueba la integración de RECOVER con el envío Debug terminal. Ese envío no implica que se reciba una LOAD durante la exclusión.

C007 aplica enqueue y fin físico simultáneos con dos bytes pendientes; la cuenta siguiente debe seguir siendo dos. C008 y C009 siguen el fin físico de LOAD/ACCEPTED y STEP/DONE con K=0.

### Procedimiento

1. **Mantener el byte pendiente.** En C001, C003 y C005, mantener TX llena durante tres clocks. Comparar el byte, su disponibilidad y el cursor después de cada flanco. Cambiar la fuente de entrada durante la espera y exigir que el valor preparado se conserve.

2. **Comprobar la liberación de espacio.** Producir el Stop que retira un byte de FIFO. Si full era uno en preflanco, el serializador no puede escribir en ese mismo flanco. Debe aceptar una sola escritura en el clock siguiente, con el byte conservado y el avance de cursor correspondiente.

3. **Observar RX en el controlador.** En C002 y C004, escribir `55` en FIFO RX en E y observar su consumo en E+1. READ_SIZE debe guardar el byte bajo y pasar su índice de cero a uno. RECOVER debe descartarlo sin admitir una orden nueva. TX llena u ocupada no debe retrasar esas acciones.

4. **Comprobar la integración durante recuperación.** En C006, observar simultáneamente el descarte de RX y la retención de ENTRY. Después de liberar espacio, el byte TX debe enviarse una sola vez. CPU y el estado de Debug permanecen retenidos; el tráfico recibido no produce respuesta ni una orden nueva.

5. **Comprobar los pendientes y el último byte.** En C007, aplicar enqueue y `tx_done_tick` juntos y exigir dos pendientes después del flanco. En C008 y C009, seguir la respuesta desde el encolado de su último byte hasta su Stop. La finalización debe ocurrir en ese Stop, nunca antes.

### Resultados y criterio de aprobación

El byte preparado, su disponibilidad y el cursor se conservan mientras no haya una escritura aceptada. Liberar espacio no permite utilizar un flag full futuro: la primera escritura ocurre en el flanco siguiente y no pierde ni duplica el byte.

Con TX llena y ocupada, RX se consume en E+1. READ_SIZE guarda `55` como primer byte del tamaño; RECOVER lo descarta sin alterar el tamaño ni admitir una orden nueva. La integración de RECOVER con Debug conserva estas reglas y la exclusión de CPU.

Los incrementos y decrementos simultáneos de pendientes se compensan. `response_done_tick` se produce en WAIT_TX_DONE, con producción completa, un pendiente y `tx_done_tick`; coincide con el último Stop sin un registro extra de evento.

La aprobación exige las tres políticas de retención, las dos acciones RX, la integración durante RECOVER y el fin físico de ambas clases de respuesta. Ninguna liberación de exclusión, inicio de timeout o petición de reset puede adelantarse al Stop que le corresponde.

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

3. **Ejecutar STEP.** Enviar `03`, recibir DONE con Debug y repetir hasta que el estado sea terminal.

4. **Observar el postflanco.** Comparar Register File, estado lógico de DMEM, contexto y latches registrados del mismo ciclo, incluidos los commits de ese flanco.

5. **Comparar cabeceras y estado final.** Todo STEP utiliza `03 02`, incluso con fault o drain. RUN utiliza ACCEPTED y después FINISHED o FAULT. Comparar los efectos con CPU sin UART y el mismo programa.

### Resultados y criterio de aprobación

RUN debe enviar `02 01` antes de `02 0A` o `02 0B` con el snapshot posterior al último commit. La terminación rápida no puede perder la respuesta final.

STEP envía únicamente `03 02` con snapshot, sin aceptación separada, incluso para `halt`, fault y drain. El último paso ya muestra el terminal.

Una orden rechazada no genera un ciclo o Debug asociado ni cancela el terminal de un RUN previo. El Register File y el estado lógico de DMEM coinciden con la ejecución sin observación.

La aprobación exige cantidad y orden de respuestas correctos, un ciclo por STEP aceptado y datos postflanco coherentes. La cabecera de respuesta y el estado observado se interpretan por separado.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-011"></a>

## TEST-UART-011 — Exclusión Debug hasta el último Stop

- **Nivel:** integración protocolo/CPU y sistema.
- **Tipo de estímulo:** tráfico durante descarte y reset físico.
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

En el contexto RUN, una respuesta breve anterior sigue ocupando TX cuando se alcanza el terminal. En STEP, la exclusión comienza después del ciclo observado. Las comprobaciones locales conectan protocolo, CPU y serializador y entregan los bytes mediante FIFO RX; las tramas 8N1 reales se comprueban en TEST-UART-014 y TEST-PLAT-005.

Para la espera previa, los bytes se consumen antes de comenzar la cabecera Debug. Para el cuerpo, se consumen durante la parte fija, lejos del último byte. LOAD utiliza la cabecera `01 04 00 00 00 00`, con un byte por flanco de consumo; los otros comandos utilizan únicamente su opcode.

E identifica el flanco que consume el último Stop de Debug. En los casos de LOAD sobre esa frontera, el opcode se consume en E-5 y los cinco bytes de tamaño en E-4, E-3, E-2, E-1 y E. Cada byte se escribe en FIFO un flanco antes de su consumo. Para un comando de un byte, se escribe en E-1 y se consume en E. Así, todos los bytes del caso llegan mientras la exclusión todavía está activa en preflanco.

### Variantes cerradas

La prueba tiene 31 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-011/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

C001–C030 combinan los dos contextos, tres instantes —espera previa, cuerpo y último Stop— y LOAD, RUN, STEP, RESET o CHECK_READY. Todos utilizan K=1, salvo C021, que envía una LOAD durante el cuerpo del Debug terminal RUN con K=2048.

En C011 y C026, la frontera se refiere al consumo del último byte de tamaño LOAD. El opcode y los otros cuatro bytes se consumen antes de E. En los otros casos de último Stop, el único opcode se consume en E.

C031 aplica el botón durante el cuerpo del snapshot posterior a STEP, con K=1. El envío debe abortarse por reset global y el host debe descartar esa respuesta parcial.

### Procedimiento

1. **Preparar y conservar la observación.** Alcanzar el ciclo STEP o terminal RUN y guardar el estado postflanco. En RUN, mantener la respuesta breve anterior para comprobar que la exclusión comience aunque Debug todavía no pueda enviarse.

2. **Entregar los bytes del caso.** Escribirlos en FIFO RX y observar su consumo en los flancos indicados. Para la espera y el cuerpo, exigir exclusión activa durante todo el mensaje. En la frontera E, comprobar su valor preflanco y observar simultáneamente el descarte del último byte RX y el fin físico de Debug.

3. **Comparar el estado retenido.** Durante la espera y el envío, comprobar que Register File, PC, latches, contador, contexto y marcas conserven sus valores. No debe haber ciclos CPU, LOAD, preparación ni respuestas provocadas por los bytes descartados. En C021, mantener estas comprobaciones durante toda la lista de 2048 entradas.

4. **Comprobar la reapertura.** Después de E, entregar un CHECK_READY y un STEP nuevos mediante el transporte disponible. Deben interpretarse conforme al estado observado, sin ejecutar ningún byte descartado. La expectativa de descarte corresponde a bytes consumidos hasta E; los que se entregan después se comprueban como solicitudes nuevas.

5. **Aplicar el botón en C031.** Solicitar reset durante el cuerpo, sin esperar una respuesta UART. Exigir NO_IMAGE y aborto del mensaje. El host conserva su último snapshot completo y descarta el parcial como nueva observación.

### Resultados y criterio de aprobación

La exclusión comienza después del ciclo y de sus commits. La selección de lectura Debug representa ese estado postflanco y permanece activa durante la espera y el envío.

Hasta E, UART continúa funcionando y los bytes RX se consumen y descartan sin producir respuestas ni comandos guardados. El estado observado y las marcas de DMEM se conservan, incluida la lista completa de C021.

En E, la exclusión preflanco todavía impide interpretar el byte RX del caso. El Stop final permite liberar la observación después del flanco; una solicitud nueva entregada después se interpreta conforme al estado actual.

RESET UART se descarta durante exclusión. El botón tiene prioridad, aborta la respuesta y deja el parcial sin validez como snapshot nuevo.

La aprobación exige retención de todos los campos, ownership correcto de Register File y DMEM, descarte de cada mensaje y reapertura posterior al Stop. El recorrido completo comprueba duración; las variantes restantes comprueban comandos y fronteras con la misma regla de exclusión.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-012"></a>

## TEST-UART-012 — Orden de respuestas y terminal RUN durante LOAD

- **Nivel:** integración controlador/serializador y sistema.
- **Tipo de estímulo:** cruces dirigidos.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-UART-003](../requirements.md#7-uart-y-debug-unit), [REQ-UART-008](../requirements.md#7-uart-y-debug-unit), [REQ-UART-011](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-015](../requirements.md#7-uart-y-debug-unit), [REQ-EXEC-007](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [protocol](../protocol.md); [protocol_controller](../architecture/debug/protocol_controller.md); [response_serializer](../architecture/debug/response_serializer.md).

### Qué comprueba y por qué

Esta prueba comprueba el orden de las respuestas cuando RUN termina durante otro intercambio del protocolo.

Busca detectar bytes de respuestas intercalados, la pérdida del terminal por una cabecera LOAD incompleta o un Debug enviado para un RUN abandonado por RESET.

La decisión depende de los flags y del estado registrados en preflanco. Los cruces distinguen una respuesta ya determinada de una solicitud todavía sin resolver.

### Condiciones iniciales

El controlador y el serializador se preparan en un fixture de integración con `run_terminal_owed` activo.

En los casos D, el descriptor de rechazo o error breve ya estaba guardado en preflanco. En C y E, la cabecera LOAD todavía no tiene una aceptación ni un rechazo.

En F-reconocido, la exclusión era cero antes del flanco que reconoce RESET y alcanza el terminal. En F-exclusión, ya era uno. Estos valores permiten comprobar la decisión temporal sin cambiar la FSM.

### Variantes cerradas

La prueba tiene 14 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-012/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 14 casos propios combinan FINISHED o FAULT con los siete cruces A, C, D-rechazo, D-error, E, F-reconocido y F-exclusión.

La subsección siguiente define cada situación. B utiliza el `halt` único ya enumerado como TEST-UART-010/C005 y no agrega un caso propio. No se inventa una variante en la que ese `halt` único produzca FAULT.

También se ejecutan las comprobaciones reutilizadas de [TEST-UART-010](#test-uart-010). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Qué significa cada cruce

| Cruce          | Situación que se prepara                                                  | Resultado que distingue la prueba                                                                      |
| -------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| A              | RUN termina mientras se transmite CHECK_READY/BUSY (`05 04`).             | Completar esa respuesta breve y luego enviar el terminal con Debug.                                    |
| B, reutilizado | Halt único termina antes del último Stop de RUN/ACCEPTED.                 | Conservar la obligación terminal hasta completar ACCEPTED; se observa en UART-010/C005.                |
| C              | RUN termina mientras se recibe una cabecera LOAD todavía incompleta.      | Abandonar esa cabecera, descartar su resto y dar prioridad al terminal.                                |
| D-rechazo      | El rechazo LOAD ya estaba determinado antes de que RUN termine.           | Transmitir primero el rechazo ya guardado, luego el terminal.                                          |
| D-error        | El error LOAD ya estaba determinado antes de que RUN termine.             | Transmitir primero el error ya guardado, luego el terminal.                                            |
| E              | El último byte de tamaño LOAD llega en el mismo flanco del terminal.      | El terminal gana sobre la solicitud todavía sin resolver; no aceptar LOAD ni guardar una orden futura. |
| F-reconocido   | RESET se reconoce en IDLE en el mismo flanco en que RUN alcanza terminal. | Guardar `04 01`, cancelar la obligación terminal anterior y aplicar reset después del Stop.            |
| F-exclusión    | RESET llega con exclusión Debug ya activa antes del flanco.               | Descartarlo y completar el terminal debido, sin otra respuesta.                                        |

Cada cruce propio se aplica una vez con FINISHED y otra con FAULT. B tiene una sola ejecución FINISHED reutilizada; no se inventa un halt único que produzca FAULT.

### Procedimiento

1. **Preparar el cruce.** Situar la solicitud y el terminal en el flanco del caso y conservar los descriptores hasta que el serializador los acepte.

2. **Observar A y D.** Exigir que la respuesta breve ya determinada termine antes del terminal.

3. **Observar C y E.** Comprobar que la cabecera LOAD se abandone sin respuesta ni timeout tardío y que sus restos no sincronicen una nueva carga.

4. **Observar F.** Si RESET se reconoce en el flanco coincidente, cancelar la obligación terminal y guardar ACCEPTED. Si la exclusión ya estaba activa, descartar RESET y conservar el terminal debido.

5. **Comparar cada mensaje completo.** Revisar cabecera, cuerpo y fin físico, sin intercalar bytes y cumpliendo una sola vez cada obligación terminal.

### Resultados y criterio de aprobación

A y B completan la respuesta breve antes del terminal con Debug. La obligación terminal se conserva hasta disponer del descriptor, sin sobrescribir una respuesta ocupada.

C y E abandonan la cabecera y descartan su resto, sin aceptación, rechazo ni timeout tardío. La imagen se conserva. D transmite primero el rechazo o error ya determinado y después el terminal.

RESET reconocido en F cancela `run_terminal_owed` y guarda `04 01`, sin crear Debug del RUN abandonado. Si la exclusión ya estaba activa, RESET se descarta y el terminal pendiente se completa.

La aprobación exige una secuencia completa por respuesta, resolución conforme al preflanco y ausencia de una LOAD abandonada encolada para después.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-013"></a>

## TEST-UART-013 — RESET UART después de aceptación y botón

- **Nivel:** sistema e integración reset.
- **Tipo de estímulo:** legal.
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

La prueba tiene 10 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-UART-013/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los seis contextos UART son RUNNING, FAULT y los cuatro drains. Los drains breves utilizan un fixture local con un evento UART reconocido, sin cambiar el clock físico.

Los cuatro casos de botón se aplican durante RUN, LOAD, PREPARING_READY y Debug.

El descarte de RESET UART durante Debug o RECOVER se comprueba mediante las reutilizaciones, sin agregar otras fases propias.

También se ejecutan las comprobaciones reutilizadas de [TEST-UART-006](#test-uart-006), [TEST-UART-011](#test-uart-011). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Procedimiento

1. **Reconocer RESET y preparar ACCEPTED.** Guardar `04 01` sin afirmar reset ni detener CPU únicamente por el reconocimiento.

2. **Seguir el fin físico.** En E, registrar `uart_reset_request=1`. Observar reset en los consumidores en E+1, la liberación en E+2 y E+3 y el primer flanco libre en E+4.

3. **Comparar el estado reiniciado.** Exigir imagen inválida, PC, Register File y contador en cero y latches inválidos.

4. **Consultar disponibilidad nueva.** Enviar `05` después de liberar reset y comprobar `05 03`.

5. **Aplicar el botón.** Solicitarlo directamente en la fase del caso. Un Debug parcial no debe considerarse una observación nueva; las comprobaciones reutilizadas cubren el descarte de UART.

### Resultados y criterio de aprobación

La respuesta `04 01` termina antes del reset. La CPU puede continuar hasta la petición registrada en E; reconocer RESET cancela la obligación terminal del RUN anterior.

En E+1 los consumidores ven reset. E+2 y E+3 completan su liberación, y E+4 es el primer flanco libre si no hay otra fuente activa.

El sistema queda en NO_IMAGE, con PC, Register File y contador en cero, imagen y latches inválidos y UART y FIFO reiniciadas. CHECK_READY devuelve `05 03`.

El botón puede abortar sin esperar la respuesta ni producir FINISHED. La aprobación exige una petición UART registrada que evite el lazo combinacional y ambas fuentes integradas en el reset común, sin reiniciar el MMCM por UART.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-uart-014"></a>

## TEST-UART-014 — Presupuestos medidos del enlace integrado

- **Nivel:** sistema UART y revisión de cotas.
- **Tipo de estímulo:** legal sin ralentización artificial.
- **Estado:** diseñada, sin ejecutar.

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

3. **Preparar y ejecutar los programas de Debug.** Generar las tres ocupaciones y ejecutar RUN hasta su terminal. Las ventanas de Debug comienzan en la cabecera o el snapshot según el protocolo, sin limitar la duración previa del programa.

4. **Comparar las cotas.** Contrastar los clocks de cada respuesta y las ventanas de 319 ms para la parte fija y `ceil(5*K*10*1000/19200+200)` ms para la lista.

5. **Observar el fin físico.** Todas las mediciones terminan en el Stop correspondiente, no en el encolado del byte.

### Resultados y criterio de aprobación

RX procesa cada byte en un clock. Desde FIFO vacía, la ocupación normal máxima es uno y no hay overflow con el flujo válido. La preparación utiliza C+1 clocks y queda por debajo de 50000.

A 50 MHz, las cotas conservadoras en clocks son:

- Respuesta breve: `2*26083+16`.
- Parte fija con cabecera: `230*26083+C+16`.
- Lista con K mayor que cero: `(5*K+1)*26083+C+16`.
- Respuesta Debug completa: `(230+5*K)*26083+2*C+16`.

LOAD termina dentro de `N*10*1000/19200+201` ms desde el inicio de contenido. Las respuestas breves y aceptaciones cumplen 200 ms; la parte fija de Debug cumple 319 ms; la lista cumple `ceil(5*K*10*1000/19200+200)` ms.

RUN no tiene timeout de duración. Las ventanas del host comprueban el fixture del enlace, sin certificar la aplicación final.

La aprobación exige ambos perfiles dentro de todas las cotas, midiendo desde los eventos correctos hasta el Stop físico. Una evidencia abstracta previa no sustituye la medición del RTL.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.
