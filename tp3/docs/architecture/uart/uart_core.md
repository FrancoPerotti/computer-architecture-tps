# Integración UART

- **Tipo:** arquitectura.
- **Estado documental:** especificación vigente.

<a id="función-de-uart_core"></a>

## Propósito y alcance

`uart_core` reúne los bloques físicos de recepción y transmisión y presenta sus bytes, solicitudes y estados al control del protocolo dentro de la FPGA. Se conserva el módulo [uart_core del TP2](../../../../tp2/rtl/uart_core.sv) como referencia, conforme al [acuerdo de conexiones](../../decisions/DEC-SYS-007.md#integración-de-uart_core).

El módulo conecta el sincronizador, el generador compartido, el receptor, el transmisor y las dos FIFO. La interpretación de `LOAD`, `RUN`, `STEP`, `RESET` y `CHECK_READY` y la coordinación de sus respuestas corresponden al control del protocolo. `uart_core` recibe y transmite bytes mientras ese control procesa las operaciones o descarta los datos que correspondan a una fase de recuperación o exclusión.

La [agrupación en módulos](../debug/protocol_controller.md#agrupación-en-módulos) utiliza `protocol_controller` para RX y coordinación de operaciones y `response_serializer` para producir TX y seguir su fin físico. Las referencias al control del protocolo en el diagrama representan esa capa completa; no reúnen ambos módulos dentro de `uart_core`.

La frontera hacia el controlador y el serializador y la composición del reporte de errores se definen en las secciones siguientes.

## Organización

### Organización interna

`uart_core` conecta los siguientes módulos:

- `serial_input_sync`, para sincronizar `serial_rx`.
- [baud_tick_gen](uart_baud_tick_gen.md), compartido por RX y TX.
- [uart_rx](uart_rx.md), para recibir y validar cada trama.
- [uart_tx](uart_tx.md), para transmitir cada byte.
- Dos instancias de [fifo](uart_fifo.md), una por sentido.

```mermaid
flowchart LR
    PINRX["serial_rx"] --> SYNC["serial_input_sync"]
    SYNC -->|synchronized_rx| RX["uart_rx"]
    GEN["baud_tick_gen"] -->|sample_tick| RX
    GEN -->|sample_tick| TX["uart_tx"]
    RX -->|received_data y rx_done_tick| RFIFO["FIFO RX"]
    RFIFO -->|r_data y rx_empty| PROTO["Control del protocolo"]
    PROTO -->|rd_uart| RFIFO
    PROTO -->|w_data y wr_uart| TFIFO["FIFO TX"]
    TFIFO -->|tx_full| PROTO
    TFIFO -->|transmit_data| TX
    TFIFO -->|tx_empty| START["TX Start Logic"]
    TX -->|tx_busy| START
    START -->|tx_start| TX
    TX -->|tx_done_tick| TFIFO
    TX -->|serial_tx| PINTX["Pin TX"]
```

`TX Start Logic` es la condición combinacional que solicita el envío cuando existe un byte en TX y el transmisor está libre. Forma parte de `uart_core` y conserva la coordinación del TP2. Los registros y contadores permanecen dentro de los módulos correspondientes.

El diagrama presenta los caminos de datos y solicitudes ya acordados. La exposición de los indicadores RX, del fin físico TX y del error de recepción se describe en la frontera posterior.

## Interfaces y contratos

### Frontera de uart_core

La frontera expone los caminos de bytes RX y TX, el reporte de errores, los indicadores de recepción y el fin físico de cada byte TX. Los nombres internos `rx_done_tick`, `rx_full`, `tx_empty` y `tx_busy` siguen participando en la coordinación de módulos dentro de `uart_core`.

| Dirección | Señal           | Ancho | Origen o destino                                                     |
| --------- | --------------- | ----- | -------------------------------------------------------------------- |
| Entrada   | `clk`           | 1     | Clock funcional común.                                               |
| Entrada   | `reset`         | 1     | Reset funcional común, activo alto.                                  |
| Entrada   | `serial_rx`     | 1     | Pin serie hacia el sincronizador.                                    |
| Salida    | `serial_tx`     | 1     | Salida registrada de `uart_tx` hacia el pin serie.                   |
| Salida    | `r_data`        | 8     | Primer byte de FIFO RX hacia `protocol_controller`.                  |
| Entrada   | `rd_uart`       | 1     | Solicitud de retiro RX desde `protocol_controller`.                  |
| Salida    | `rx_empty`      | 1     | FIFO RX vacía, hacia `protocol_controller`.                          |
| Entrada   | `w_data`        | 8     | Byte de respuesta desde `response_serializer`.                       |
| Entrada   | `wr_uart`       | 1     | Solicitud de escritura TX desde `response_serializer`.               |
| Salida    | `tx_full`       | 1     | FIFO TX llena, hacia `response_serializer`.                          |
| Salida    | `rx_error_tick` | 1     | Evento de error RX hacia `protocol_controller`.                      |
| Salida    | `rx_activity`   | 1     | Actividad desde `uart_rx` hacia `protocol_controller`.               |
| Salida    | `rx_receiving`  | 1     | Trama en curso desde `uart_rx`, incluida en `rx_activity`.           |
| Salida    | `tx_done_tick`  | 1     | Fin físico de cada byte desde `uart_tx` hacia `response_serializer`. |

Los dos indicadores RX y el evento TX se llevan directamente desde sus productores, sin una etapa de registro adicional en `uart_core`. El Controller utiliza `rx_activity` para supervisar el silencio RX; no necesita una conexión separada de `rx_receiving`, que ya participa en ese indicador. Sus condiciones y flancos de consumo mantienen los contratos de [recepción](uart_rx.md#indicadores-para-el-control-del-protocolo) y [transmisión](uart_tx.md#stop-completo-y-evento-de-finalización).

`response_serializer` asocia los eventos de fin TX, en orden, con los bytes de la respuesta que está enviando y comunica su finalización completa a `protocol_controller`. De ese modo se identifica el final del segundo byte de aceptación `LOAD` o `RESET` y el último byte de Debug. La secuencia de producción, seguimiento y exclusión está definida en ambos módulos. El [presupuesto de integración](#presupuesto-de-integración) relaciona sus tiempos con el [protocolo UART](../../protocol.md).

## Comportamiento

### Camino de recepción

`serial_rx` alimenta exclusivamente al sincronizador. Su salida `synchronized_rx` llega a la entrada `rx` del receptor. `uart_rx` entrega `received_data` de ocho bits y activa `rx_done_tick` cuando ha completado y validado el byte.

Las conexiones de la FIFO RX son:

| Puerto de FIFO RX | Conexión                                                        |
|-------------------|-----------------------------------------------------------------|
| `wr`              | `rx_done_tick` desde `uart_rx`.                                 |
| `write_data`      | `received_data` desde `uart_rx.data_out`.                       |
| `rd`              | `rd_uart` desde el control del protocolo.                       |
| `read_data`       | `r_data` hacia el control del protocolo.                        |
| `empty`           | `rx_empty` hacia el control del protocolo.                      |
| `full`            | `rx_full` interno, utilizado para el reporte de desbordamiento. |

El receptor y la FIFO consumen las señales en el flanco que valida el Stop. Si hay espacio, la FIFO guarda el byte y actualiza su ocupación. Después de ese flanco, el control del protocolo puede observar el primer dato válido mediante `r_data` y `rx_empty`.

El control del protocolo toma el byte de `r_data` previo al flanco y activa `rd_uart` cuando corresponde retirarlo. Solo lo considera disponible con `rx_empty` en cero. Durante recuperación o exclusión Debug utiliza el mismo retiro para descartar datos, sin interpretar solicitudes. El [controlador](../debug/protocol_controller.md) retira o descarta mediante `rd_uart` en todas las fases, según su contrato.

El registro de bytes válidos no depende del avance de la CPU ni de la disponibilidad TX. El retiro por el Controller tampoco depende de TX: fuera de reset, `rd_uart = !rx_empty` en todas sus fases. El byte retirado se interpreta, se entrega al Loader o se descarta según la fase y el error RX.

### Actividad y silencio RX

`uart_rx` genera `rx_receiving` mientras su FSM está en `START`, `DATA` o `STOP`. También conserva `rx_previous`, el nivel sincronizado de la línea en el flanco anterior; su comparación con el nivel actual detecta cambios. Fuera de reset, `rx_activity` vale uno si la línea sincronizada cambia de nivel, está baja o `rx_receiving` está activo.

La detección observa cada clock funcional, con independencia de `sample_tick`. Una trama o una línea baja pueden mantener `rx_activity` activo durante varios clocks, aunque no llegue un byte válido. Durante reset, ambos indicadores valen cero. La [generación de indicadores](uart_rx.md#generación-de-los-indicadores) pertenece a `uart_rx`; `uart_core` los expone sin agregar registros.

En `RECOVER_RX`, el Controller reinicia su contador de silencio en cada flanco con `rx_activity` activo. Fuera de reset, `rx_activity = 0` acredita línea alta, sin cambios ni trama en curso. La salida de recuperación exige además el plazo completo, FIFO RX vacía y las condiciones de respuestas y Debug del [Controller](../debug/protocol_controller.md#tiempos-y-prioridades).

### Camino de transmisión

`response_serializer` entrega `w_data` y solicita su incorporación mediante `wr_uart` cuando TX tiene espacio. Si `tx_full` está activo, conserva el byte pendiente hasta poder escribirlo. En paralelo, `protocol_controller` continúa consumiendo RX.

Las conexiones de la FIFO TX son:

| Puerto de FIFO TX | Conexión                                                  |
|-------------------|-----------------------------------------------------------|
| `wr`              | `wr_uart` desde el control del protocolo.                 |
| `write_data`      | `w_data` desde el control del protocolo.                  |
| `rd`              | `tx_done_tick` desde `uart_tx`.                           |
| `read_data`       | `transmit_data` hacia `uart_tx.data_in`.                  |
| `empty`           | `tx_empty` interno, utilizado para solicitar el comienzo. |
| `full`            | `tx_full` hacia el control del protocolo.                 |

Fuera de reset, `tx_start` está activo si `tx_empty` y `tx_busy` valen cero. Durante reset se mantiene en cero. En el flanco de aceptación, `uart_tx` captura `transmit_data` en su registro interno y comienza el Start. La FIFO conserva ese byte como su primer elemento durante toda la transmisión.

Al flanco indicado por `tx_done_tick` termina el Stop completo, la FIFO acepta el retiro del byte transmitido y `uart_tx` vuelve a IDLE. El retiro y la finalización se producen en el mismo flanco. Después de él se presentan el nuevo primer byte y los nuevos flags; si existe otro byte pendiente, se solicita su transmisión para el siguiente flanco.

El serializador puede producir mensajes de cualquier longitud compatible con los formatos del protocolo usando el espacio disponible. La FIFO almacena solo los bytes pendientes inmediatos y el registro del transmisor conserva el byte en curso.

### Reporte de errores

Se conserva el reporte combinado del TP2. `rx_error_tick` se activa en estos casos:

| Condición                             | Significado                                                |
|---------------------------------------|------------------------------------------------------------|
| `frame_error_tick`                    | Error de trama; no se entrega un byte válido.              |
| `rx_done_tick` coincide con `rx_full` | Desbordamiento; el byte válido recibido no pudo guardarse. |

La FIFO utiliza el flag full previo al flanco, incluso si se solicita un retiro en ese mismo flanco, según su contrato.

El evento se consume en el flanco correspondiente, no se repite por el solo hecho de conservar RX llena y permanece en cero durante reset.

El control del protocolo reacciona conforme a la fase y las prioridades ya aprobadas, sin exigir un código externo diferente para trama y desbordamiento. En tamaño y contenido `LOAD`, la FSM aprobada del controlador aplica esta prioridad:

```text
error > byte válido > timeout
```

`RECOVER_RX`, fase del Controller, descarta RX hasta completar el silencio y las demás condiciones de salida exigidas.

## Estado y temporización

### Clock, reset y parámetros compartidos

Todos los módulos reciben el clock funcional común, con objetivo de 50 MHz, y el reset funcional acondicionado, activo alto y consumido al flanco. Se conserva el sincronizador de dos registros del TP2; ambos se inicializan en uno, y solo la segunda etapa alimenta al receptor.

Los parámetros comunes de `uart_core` toman estos valores:

| Parámetro         |      Valor |
|-------------------|-----------:|
| `CLK_FREQ_HZ`     | 50.000.000 |
| `BAUD_RATE`       |     19.200 |
| `OVERSAMPLE`      |         16 |
| `FIFO_ADDR_WIDTH` |          2 |

RX y TX utilizan ocho bits de datos y un Stop con factor de ticks 16. Ambas FIFO utilizan `DATA_WIDTH`=8 y `ADDR_WIDTH`=2.

El generador conecta `s_tick` a la señal interna `sample_tick`, que alimenta ambos bloques. Son nombres de la misma referencia síncrona, con un pulso registrado de un clock cada 163 clocks. Se mantiene la cuenta entre tramas y durante `HOLD` de CPU.

El reset global inicializa los módulos y vacía ambas FIFO. La recuperación de recepción del protocolo conserva TX y consume o descarta RX mediante su interfaz; no aplica ese reset global para realizar el descarte.

## Invariantes y condiciones de borde

Las prioridades de recepción y la combinación de errores están en [Reporte de errores](#reporte-de-errores). Los parámetros y el dominio compartido se conservan en [Clock, reset y parámetros compartidos](#clock-reset-y-parámetros-compartidos).

## Presupuesto de integración

El presupuesto utiliza el dominio común de 50 MHz, UART nominal 19200 8N1, divisor 163, sobremuestreo 16, perfiles compartidos y un host que respeta fases y longitudes. Los cálculos presuponen que la implementación cumple sus contratos y cierra las rutas en 20 ns; no acreditan RTL, timing físico ni comportamiento del driver USB.

### Conexiones y dependencias de control

| Frontera             | Productor → consumidor y comprobación                                                                                                                                                                                                                                                                                                                           |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Clock/reset          | Clock funcional y `reset_sync` común → todos los recursos; tick es enable, no otro clock. Botón/UART/estabilidad se unen antes del acondicionador.                                                                                                                                                                                                              |
| RX físico/FIFO       | `uart_rx` entrega dato y `rx_done_tick` al mismo flanco FIFO; trama inválida no produce byte válido. Error de trama/desbordamiento llega al controlador.                                                                                                                                                                                                        |
| FIFO RX/controlador  | Primer dato combinacional y `rx_empty` → controlador; `rd_uart`=!reset&&!`rx_empty` en todas las fases. Esperar TX nunca inhibe retiro.                                                                                                                                                                                                                         |
| Solicitudes CPU      | `Protocol Controller` → `Global FSM`, por `Execution Control`: `load_request`, `run_request`, `step_request`. Las solicitudes se generan independientemente de `command_accepted`; ambas FSM consumen solicitud y aceptación común en el mismo flanco.                                                                                                          |
| `LOAD`/IMEM          | Controlador entrega byte/posición/último/aborto; Loader guarda tres bytes o escribe palabra con cuarto. `load_ok` certifica la escritura final ante la Global FSM en el flanco de la última entrega válida; el Controller entra en `WAIT_PREP_DONE`.                                                                                                            |
| Tamaño pendiente     | Tamaño validado por el Controller con el quinto byte actual → Loader/registro de tamaño confirmado en el flanco de aceptación; luego se conserva hasta publicación. `load_start` de la FSM inicia Loader e invalida el tamaño anterior; `image_publish` captura el tamaño pendiente al consumir `prepare_done` en PREPARING_READY, sin ciclo CPU.               |
| Preparación          | `prepare_active` de `Global FSM` → `Session Preparation` y controlador; índice limpia metadatos y primer flanco inicializa RF/PC/ciclos/pipeline. `prepare_done` llega a la Global FSM después de las últimas limpiezas, con enables inactivos. El Controller observa `prepare_active` para cerrar LOAD y `cpu_cycle_fire` para STEP; no recibe `prepare_done`. |
| RF/DMEM Debug        | Controlador genera `debug_read_select` común para ambos selectores; serializador da dirección y recibe datos combinacionales del estado retenido. CPU/mantenimiento quedan excluidos durante observación. El flanco observado conserva accesos CPU y la selección Debug cambia después.                                                                         |
| Estado CPU/UART      | `Global FSM` entrega `load_available`, `prepare_active`, `program_finished` y `fault_terminal` al controlador. Su código combinacional `global_state_code[7:0]` llega a `Response Serializer.debug_state_code` para observación.                                                                                                                                |
| Captura de respuesta | Controller presenta campos combinacionales y `response_start`; el serializador libre los captura en sus registros de 17 bits. `run_result_required` conserva la obligación terminal hasta esa captura; el Controller no guarda un descriptor pendiente.                                                                                                         |
| Serializador/TX      | `PREPARE` captura byte y `ENQUEUE` conserva hasta escritura aceptada. Índices avanzan por aceptación, no por intento ni fin físico. FIFO conserva byte en curso hasta `tx_done_tick`.                                                                                                                                                                           |
| Finalización         | Serializador comunica fin en el mismo último Stop; controlador inicia T `LOAD`, libera Debug o registra reset según estado/marcas. Reset UART registrado evita lazo combinacional con ese evento.                                                                                                                                                               |

La dependencia `next_state`→estado registrado rompe el recorrido comandos/ciclo/pipeline siguiente; solo el estado actual realimenta aceptación y autorización. El estado global registrado, los registros propios del serializador y la solicitud registrada de reset rompen las otras dependencias de coordinación. `response_busy` depende del estado del serializador, sin realimentación combinacional desde `response_start`.

### Latencia RX y escritura LOAD

Si un byte válido entra a la FIFO RX en E y esta estaba vacía, el dato y empty cambian después de E. En E+1, `rd_uart` retira ese dato. En `RECEIVE_LOAD_DATA`, el mismo flanco captura el primer/segundo/tercer byte o escribe IMEM con el cuarto. No hay otra etapa de Loader ni espera de TX. La [realización del Loader](../session/loader.md) permite una entrega por clock.

**Latencia desde incorporación FIFO hasta procesamiento:** un clock = 20 ns. Si existe un backlog inicial, se retira un byte por clock hasta vaciar; no se demora por transmisión de una respuesta, `tx_full`, `response_busy`, CPU en `HOLD`, preparación, Debug o recuperación. Fuera de las fases que interpretan datos, ese retiro descarta.

La [FIFO](uart_fifo.md#solicitudes-y-operaciones-aceptadas) usa flags previos al flanco: vacía no acepta lectura simultánea al primer write. Por eso no se promete consumo en E. Con write seguido de retiro E+1 y llegadas separadas por más de un clock, una inducción desde reset vacío da ocupación normal máxima uno; las cuatro entradas aprobadas aportan margen y no se reabren.

Al baud nominal, bytes 8N1 contiguos están separados por 10/19200 s ≈520,833 µs, unos 26.041,67 clocks. Además, la [FSM RX aprobada](uart_rx.md#tabla-de-acciones) proporciona una cota independiente del promedio nominal: tras un evento vuelve a IDLE y una próxima trama válida requiere 8 ticks START + 8×16 DATA + 16 STOP. Con divisor 163, dos eventos válidos están separados por al menos 152×163=24.776 clocks, 495,52 µs. Frente a esa cota conservadora, procesamiento ocupa un clock.

La cota de un clock incluye la escritura IMEM del cuarto byte y `load_ok` de la última palabra. Para el quinto byte de tamaño, en `RECEIVE_LOAD_SIZE` el Controller combina `r_data` con los cuatro bytes registrados, valida los cuarenta bits y, si el tamaño es válido, presenta `load_request` y el tamaño validado antes de E+1. La Global FSM decide combinacionalmente la aceptación de esa solicitud; en E+1, el serializador captura `LOAD/ACCEPTED` o el rechazo correspondiente. Un tamaño inválido produce `INVALID_SIZE` sin presentar `load_request`. No hay un estado intermedio de validación.

La ruta FIFO RX → validación de tamaño → solicitud → aceptación → captura de respuesta debe cumplir el período de 20 ns. La misma exigencia se aplica al camino de opcode y solicitud `RUN`/`STEP`, incluida la autorización `cpu_cycle_fire` cuando STEP ejecuta en el flanco de aceptación. Son condiciones de timing de la implementación. El host espera el último Stop de `LOAD/ACCEPTED` antes de enviar contenido.

### Continuidad RX y conservación TX

`rd_uart` solo depende de reset y `rx_empty`. Por tanto, las once fases del Controller conservan retiro cuando existe dato, independientemente de flags TX. En recuperación/Debug/esperas se descarta; el contador R consulta `rx_activity`, que ya incluye la recepción en curso. No se aplica reset para vaciar RX en recuperación y TX continúa.

En `ENQUEUE`, un byte ya preparado no se recaptura si `tx_full`=1; dato, disponibilidad y cursor retienen. `wr_uart` requiere disponibilidad y espacio. Si TX estaba llena y el último Stop libera lugar, el productor reintenta en el siguiente clock por las reglas previas al flanco; no pierde el byte ni inhibe RX. Incremento/decremento TX simultáneos conservan cuenta. Producción completa junto con un pendiente y último Stop identifica respuesta completa; reset abortado no genera fin normal.

### Servicios y límites del presupuesto

El presupuesto de preparación está en [Session Preparation](../session/session_preparation.md#duración-y-alcance-de-revisión), el plazo final de carga en [Loader](../session/loader.md#presupuesto-de-load) y las cotas de respuesta/lista en [Response Serializer](../debug/response_serializer.md#presupuesto-de-transmisión-y-debug).

Estas cotas son condiciones del diseño. Las pruebas RTL de errores y desbordamiento, reset y retención, commit, plazos medidos y regresión de placa requieren la implementación.

## Referencias y trazabilidad

- [Mapa de autoridad documental](../system_overview.md#autoridad-documental-por-tema): contratos vigentes y origen de las decisiones.
- [Requisitos](../../requirements.md): obligaciones y criterios de aceptación.
- [Decisiones pendientes](../../decisions/pending_decisions.md): decisiones de diseño abiertas y condiciones de cierre.
