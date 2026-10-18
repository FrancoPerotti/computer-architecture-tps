### DEC-SYS-007 — Servicios y parámetros generales de UART

**Contrato vigente de consulta:** [uart_core](../architecture/uart/uart_core.md), [uart_rx](../architecture/uart/uart_rx.md), [uart_tx](../architecture/uart/uart_tx.md), [uart_fifo](../architecture/uart/uart_fifo.md), [uart_baud_tick_gen](../architecture/uart/uart_baud_tick_gen.md), [protocol_controller](../architecture/debug/protocol_controller.md), [response_serializer](../architecture/debug/response_serializer.md), [loader](../architecture/session/loader.md), [session_preparation](../architecture/session/session_preparation.md), [reset_integration](../architecture/platform/reset_integration.md), [global_state_encoding](../architecture/session/global_state_encoding.md), [execution_control](../architecture/session/execution_control.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada.

**Dominio:** Sistema / UART, Debug y servicios FPGA asociados.

**Fecha de aprobación:** Acuerdos parciales entre 2026-10-01 y 2026-10-05; consolidación documental el 2026-10-05 después de comprobar conexiones y presupuesto.

**Contexto:** La integración reúne enlace PC/FPGA, buffers, `LOAD` continuo, respuestas ordenadas y Debug coherente. Los límites de acuerdos parciales previos describen su fecha de aprobación, anterior al cierre conjunto.

**Opciones consideradas:**

- Mantener configuración y módulos TP2 adaptados a clock funcional.
- Variantes de buffers/coordinación.
- Copia Debug frente a lectura retenida.
- Recursos duplicados frente a derivación del estado/progreso existentes.

Las selecciones se documentan en los acuerdos parciales anteriores.

**Decisión:** Los bloques se concretan con los siguientes contratos. La [revisión de interfaz con Execution Control](#revisión-de-dec-sys-007--interfaz-del-protocolo-con-execution-control) actualiza la aceptación y los indicadores que utiliza el controlador.

| Bloque o frontera           | Contrato aprobado                                                                                                                                                 |
|-----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| UART                        | Opera nominalmente a 19200 8N1, con sobremuestreo 16 y dominio común 50 MHz, divisor 163 y tick registrado                                                        |
| RX/TX y FIFO                | RX/TX utilizan sus FSM y recursos aprobados; las FIFO independientes contienen cuatro bytes y `uart_core` produce eventos de recepción/error/actividad/fin físico |
| `protocol_controller`       | Usa FSM one-hot de dieciséis estados y un descriptor pendiente                                                                                                    |
| Control CPU / protocolo     | Solicitudes directas, aceptación común e indicadores de disponibilidad, preparación y terminación                                                                 |
| `response_serializer`       | Usa diez estados one-hot, generación progresiva y finalización en el último Stop                                                                                  |
| Respuestas y terminal `RUN` | Se coordinan por estado y marcas existentes, sin registro de clases                                                                                               |
| Debug                       | Lee estado retenido con exclusión desde el instante observado hasta fin físico; comparte RF/DMEM según sus selectores                                             |
| Loader                      | Reutiliza posición/tamaño, conserva tres bytes y escribe palabra con cuarto, incluyendo `load_ok` final                                                           |
| Preparación                 | Inicializa RF/PC/ciclos/pipeline y limpia metadatos DMEM por índice, con `prepare_done` sin mantenimiento concurrente                                             |
| RF                          | Se realiza con flip-flops e inicialización simultánea                                                                                                             |
| Reset                       | Combina fuentes antes de `reset_sync` TP2 de dos etapas                                                                                                           |
| FSM CPU                     | Utiliza catorce bits one-hot y código UART combinacional hacia `Response Serializer`                                                                              |

Formatos, comandos, prioridades y recuperación conservan `protocol.md` y los acuerdos vigentes.

**Justificación:** Reutiliza módulos TP2 y recursos existentes, separa control de actualización, conserva flujo RX durante espera TX y evita copias/registro de clases. Las [comprobaciones de diseño](../architecture/uart/uart_core.md#presupuesto-de-integración) completan las condiciones pendientes antes de implementación: un clock de procesamiento RX/`LOAD` (20 ns) frente a al menos 24.776 clocks entre eventos válidos; preparación de 40,98/20,02 µs; cotas de respuestas/Debug dentro de plazos PC para ambos perfiles.

**Consecuencias:** Se cierra esta decisión de diseño, no la verificación RTL ni el gate D0/M6. Deben implementarse y probarse los contratos, cerrar timing de 50 MHz, restricciones y validación en placa. Assembler/aplicación PC y detalles restantes de plataforma/tops/lanes siguen su ruta de diseño global. No se autoriza programar por este cierre aislado.

**Requisitos afectados:** `REQ-UART-001` a `REQ-UART-011`, `REQ-EXEC-016`, `REQ-EXEC-017`, `REQ-DBG-013` a `REQ-DBG-016`, `REQ-DOC-006`; referencias de origen existentes conservan DEC-SYS-007.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de DEC-SYS-007 y traslada la decisión desde `pending_decisions.md`. No sustituye decisiones CPU/ISA ni protocolo aprobado.

### Acuerdo parcial de DEC-SYS-007 — Configuración física UART de referencia

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-007` permanece pendiente en sus aspectos restantes.

**Dominio:** Sistema / UART y temporización del protocolo.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La configuración física UART reutiliza el TP2 y se adapta al clock funcional TP3; estos parámetros permiten dimensionar recursos y tiempos de `LOAD`.

**Decisión:** La UART del TP3 utilizará baud rate nominal de **19200 baud**, formato **8N1** (ocho bits de datos, sin paridad, un bit de Stop) y sobremuestreo **16**. Se utilizará el clock funcional común con objetivo de **50 MHz**, conforme a `DEC-ARCH-005`, adaptando la generación de ticks a esa frecuencia. Los ticks serán enables síncronos y no un dominio de clock adicional.

El formato mantiene un bit de Start y un bit de Stop por cada byte, además de los ocho bits de datos. A la velocidad nominal, la duración de una trama de byte es `10 / 19200` segundos, aproximadamente **0,520833 ms**; transmitir 1024 bytes sin pausas requiere aproximadamente **0,533333 s** de contenido, sin incluir respuestas ni preparación.

**Justificación:** Reutilizar la configuración conocida del TP2 proporciona un ritmo suficiente para el uso previsto del TP y una referencia concreta para los contratos temporales de recepción y transmisión.

**Consecuencias y alcance pendiente:** Se resuelve U01 de la checklist. Quedan pendientes buffers, contrato de consumo y señales de fin/actividad en U02, transporte de PC en U03, correcciones de diseño de bloques UART mencionadas por el usuario y selección concreta de los tiempos. Las duraciones calculadas son nominales; al concretar el generador se tendrá en cuenta el redondeo del divisor. No se afirma que exista ya una implementación TP3 ni medición de hardware.

**Requisitos afectados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-009`, `REQ-UART-010`, `REQ-TIM-002`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve baud rate, formato físico, sobremuestreo y frecuencia de referencia para UART pendientes en `DEC-SYS-007`, conservando el dominio común aprobado y sin cerrar el conjunto de servicios o la integración UART.

### Acuerdo parcial de DEC-SYS-007 — Buffers y contrato de consumo UART

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-007` permanece pendiente en sus aspectos restantes.

**Dominio:** Sistema / UART, Loader y transmisión de respuestas.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La reutilización de las FIFO TP2 requiere un contrato de consumo suficiente para `LOAD` continuo y los eventos UART necesarios para coordinar el protocolo.

**Decisión:** Se adoptan las siguientes reglas:

1. **Buffers independientes:** FIFO RX de cuatro bytes y FIFO TX de cuatro bytes, como en la configuración de referencia del TP2.
2. **Consumo RX:** Durante recepción normal de `LOAD`, cada byte se retirará y procesará antes de que llegue completo el siguiente. El consumo se realizará con el clock funcional común, sin depender de esperar un tick de baud ni de ciclos efectivos de CPU. En recepción continua nominal hay aproximadamente 0,520833 ms, unos 26042 clocks funcionales de 50 MHz, entre bytes completos consecutivos.
3. **Reconstrucción de instrucciones:** Se acumularán los cuatro bytes de la instrucción en un registro fuera de la FIFO RX, se escribirá la palabra completa en IMEM con el ownership aprobado y se continuará con la siguiente. El presupuesto del punto anterior incluye esa escritura. No se acumula el programa entero en la FIFO.
4. **TX llena:** La capa de transmisión conservará el byte pendiente y esperará espacio antes de introducirlo en TX, sin perderlo ni bloquear el consumo o descarte de RX. Las vías RX/TX seguirán siendo independientes y la limpieza de recepción conservará TX para informar el fallo.
5. **Eventos observables:** UART informará el fin físico de cada byte transmitido, incluido Stop. La capa de respuestas identificará el segundo byte de aceptación de `LOAD` y activará la espera aprobada en L15. También se dispondrá de información de actividad RX y recepción en curso para cumplir el criterio de silencio de recuperación.

**Justificación:** Con el consumo de cada byte antes del siguiente, cuatro lugares de RX son suficientes para el flujo normal de `LOAD`. El registro de reconstrucción separa la instrucción en formación del almacenamiento temporal de bytes. Esperar espacio TX sin bloquear RX conserva el progreso de recepción y recuperación.

**Consecuencias y alcance pendiente:** Se resuelve U02 de la checklist como contrato de diseño, sin acreditar todavía su realización. Al diseñar las máquinas de estado se comprobará que cumplen el presupuesto, incluida escritura IMEM y espera TX. Quedan pendientes las correcciones de bloques del TP2 que mencionó el usuario, la realización del generador y la lista exacta de puertos/señales de actividad, recepción en curso y fin físico de TX. El `uart_core` del TP2 ya tiene fin de byte TX interno, pero no expone todavía todos estos eventos. Las respuestas y snapshots se transmitirán usando el espacio disponible; el tamaño de TX no exige almacenar el mensaje completo en esa FIFO.

**Requisitos afectados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-002`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve las profundidades de FIFO, el contrato de consumo y los eventos necesarios para el protocolo pendientes en `DEC-SYS-007`, conservando los acuerdos de carga seguida y recuperación sin cerrar la realización de UART.

### Acuerdo parcial de DEC-SYS-007 — Correcciones de diseño de FSM del TP2

**Estado del acuerdo:** Criterios registrados a partir de las correcciones docentes del TP2. DEC-SYS-007 continúa pendiente en el diseño de bloques.

**Dominio:** UART / Organización del control y de las acciones sobre datos.

**Fecha de registro:** 2026-10-01.

**Contexto:** Las correcciones docentes del TP2 requieren decisiones FSM mediante casez y patrones con condiciones irrelevantes, separadas de la lógica que captura, desplaza o actualiza datos.

**Contraste con el TP2 disponible:** `uart_rx` y `uart_tx` ya registran estado, contadores y datos en el flanco de `clk`. Su lógica combinacional utiliza case para el estado e if/else para condiciones; en ese mismo bloque calcula tanto `next_state` como los siguientes valores de contadores y datos. La corrección consiste en reorganizar esa descripción, sin afirmar que el estado actual se actualizaba combinacionalmente.

**Criterios de diseño:**

1. La lógica combinacional de transición y generación de controles se expresa mediante casez, haciendo explícitas las condiciones de cada decisión. En los patrones, los bits irrelevantes se representan mediante `?`; no mediante `x`. El comodín indica que esa condición no participa en la elección, no que un registro deba almacenar un valor desconocido. La [documentación de Verilator](https://verilator.org/guide/latest/warnings.html#casewithx) distingue ese uso.
2. La FSM calcula el siguiente estado y emite controles de acción. La actualización del registro de datos, los contadores y demás recursos corresponde a lógica diferenciada que consume esos controles. Para el receptor, la FSM ordena capturar un bit cuando corresponde muestrearlo; el registro de recepción realiza la captura en el flanco autorizado. Estar en `DATA` no basta para capturar en todos los clocks.
3. El estado actual permanece registrado en el flanco de `clk`; calcular `next_state` combinacionalmente sigue siendo correcto. La separación entre decisión y acción no exige un ciclo adicional: un control combinacional puede ser consumido por el registro en el flanco correspondiente.
4. La separación es funcional y debe verse en el diseño y en su futura realización. No exige por sí sola un archivo o módulo HDL independiente para cada FSM, contador o registro. Puertos, controles concretos, agrupación y codificación interna se definirán al diseñar los bloques.

**Consecuencias y alcance pendiente:** Se conocen las correcciones docentes que estaban pendientes de consultar al usuario. Falta aplicarlas al diseño del receptor, transmisor y lógica privada relacionada con UART, especificando estado, condiciones, controles y recursos receptores de cada acción. No cambia el protocolo, la FSM global CPU ni los contratos de clock/`reset`. Se trabaja únicamente en documentación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la información pendiente sobre las correcciones del TP2; no aprueba todavía los puertos o FSM concretos del TP3.

### Acuerdo parcial de DEC-SYS-007 — Organización del receptor UART

**Estado del acuerdo:** Organización aprobada como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Receptor.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La organización del receptor TP2 debe explicitar recursos y señales mediante las que la FSM ordena acciones, conforme a las correcciones docentes.

**Decisión:** El receptor diferencia cuatro partes funcionales: RX Control, Sample Counter, Bit Counter y RX Shift Register. RX Control conserva el estado registrado y calcula las transiciones y los controles de acción. Los contadores actualizan sus valores mediante órdenes de limpieza e incremento; el registro de desplazamiento incorpora la muestra recibida cuando el control habilita la captura, identificada como `data_shift_enable`.

Los controles se consumen en el flanco del clock funcional común, sin un ciclo adicional por la separación. La entrada serie sincronizada alimenta al control y al registro de recepción; los contadores aportan las condiciones de avance. El byte completo se entrega a la FIFO RX mediante el evento de recepción válida. La separación funcional no obliga a crear un módulo HDL por recurso.

**Justificación:** Los recursos existentes en el TP2 cubren la recepción 8N1 y permiten aplicar la corrección docente haciendo visible qué bloque decide una acción y qué recurso la realiza.

**Consecuencias y alcance pendiente:** La organización se desarrolla en [Receptor UART](../architecture/uart/uart_rx.md). La propuesta de estados y acciones se revisa en el paso siguiente y no queda aprobada por este acuerdo. Permanecen pendientes la codificación interna, los indicadores de actividad RX y recepción en curso y la integración del subsistema UART. El trabajo continúa únicamente en diseño.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aplica al receptor el criterio de separación entre control y acciones del acuerdo anterior; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Estados y agrupación del receptor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Receptor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El receptor reutiliza la división TP2: cinco estados, contadores y registro de recepción internos. La adaptación aplica casez y señales de acción sin cambiar la recepción.

**Decisión:** Se conserva `uart_rx` como módulo receptor. RX Control, Sample Counter, Bit Counter y RX Shift Register son partes funcionales internas, con lógica diferenciada de control y actualización; los contadores y el registro de recepción no se convierten en módulos nuevos. Se mantiene la división en módulos del TP2 como referencia para el subsistema UART, con las adaptaciones necesarias al clock y a los contratos del TP3.

La FSM conserva `IDLE`, `START`, `DATA`, `STOP` y `RECOVER`.

| Estado RX | Función                                                                        |
|-----------|--------------------------------------------------------------------------------|
| `IDLE`    | Espera un posible comienzo de trama                                            |
| `START`   | Comprueba el nivel bajo después de ocho ticks de sobremuestreo                 |
| `DATA`    | Ordena las ocho capturas separadas por dieciséis ticks                         |
| `STOP`    | Comprueba el nivel alto dieciséis ticks después de D7 y anuncia el byte válido |
| `RECOVER` | Espera el retorno de la línea a alto después de un error                       |

Se conserva el reporte de Start falso o Stop inválido y la entrega del byte solo con Stop válido.

Las transiciones y eventos mantienen el comportamiento del TP2, expresado mediante controles explícitos sobre los recursos. Las capturas, los incrementos, las limpiezas y el cambio de estado pueden ocurrir en el mismo flanco. La [tabla de estados y acciones](../architecture/uart/uart_rx.md#estados-y-transiciones) documenta las condiciones correspondientes. La recuperación de trama en `RECOVER` no reemplaza la recuperación por silencio de 100 ms del protocolo.

**Justificación:** Los estados existentes cubren las fases de la trama 8N1 y el retorno al reposo tras un error. Las correcciones docentes requieren reorganizar el control y las acciones, sin introducir nuevas fases de recepción ni módulos para cada recurso.

**Consecuencias y alcance pendiente:** Quedan conservados los estados y el comportamiento de recepción de referencia. Permanecen pendientes la codificación interna, los indicadores de actividad RX y recepción en curso y el diseño de los demás bloques e integración UART. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa los estados y la agrupación pendientes del acuerdo de organización del receptor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Indicadores de recepción UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Observación de recepción y recuperación del protocolo.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** `protocol_controller` consume `rx_receiving` y `rx_activity` para interpretar servicios y recuperar por silencio. Su responsabilidad difiere de la recepción de operandos del controlador TP2.

**Decisión:** `uart_rx` genera dos indicadores de un bit. Fuera de `reset`, `rx_receiving` vale uno si el estado actual es `START`, `DATA` o `STOP`. `rx_activity` vale uno si la línea sincronizada cambia de nivel, permanece baja o `rx_receiving` está activo. No depende de que la trama produzca un byte válido; una línea baja en `RECOVER` también mantiene actividad.

La generación es combinacional, sin una etapa adicional en las salidas. Para detectar cambios se conserva un registro auxiliar de un bit con el nivel sincronizado anterior, actualizado en cada flanco del clock funcional e inicializado en uno. Durante `reset` ambos indicadores externos valen cero. La lógica auxiliar permanece dentro del receptor y no agrega estados ni módulos HDL independientes.

La integración UART expone los indicadores al control del protocolo. Durante recuperación, ese control reinicia la cuenta de silencio en cada flanco con `rx_activity` activo y permite avanzar cuando cesa. Al cumplir los 100 ms comprueba ausencia de actividad, línea en reposo, ningún byte en curso y FIFO RX vacía antes de admitir solicitudes. La actividad prevalece si coincide con el final de la cuenta. Se mantiene el contrato de [descarte y silencio](../protocol.md#descarte-y-silencio).

**Justificación:** Observar solo bytes válidos no permite detectar una trama parcial, un error o una línea baja sostenida. Las condiciones aprobadas permiten al consumidor distinguir silencio efectivo de recepción activa manteniendo los estados existentes del TP2.

**Consecuencias y alcance pendiente:** Los indicadores y los [puertos del receptor](../architecture/uart/uart_rx.md#frontera-de-uart_rx) quedan documentados. Faltan la codificación interna de estados, el recorrido de las señales en la integración UART y la organización interna del control del protocolo, además del diseño de los demás bloques UART. El trabajo continúa únicamente en diseño.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa los indicadores pendientes de los acuerdos del receptor; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Codificación one-hot del receptor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Codificación privada del receptor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** Los cinco estados del receptor requieren una representación privada; se conserva la codificación one-hot del TP2.

**Decisión:** El registro de estado del receptor tiene cinco bits. Los valores legales son `IDLE`=00001, `START`=00010, `DATA`=00100, `STOP`=01000 y `RECOVER`=10000. El `reset` lleva a `IDLE`. El siguiente estado se calcula combinacionalmente y se registra al flanco ascendente del clock funcional, conforme a los controles y transiciones ya documentados.

La codificación pertenece a la FSM privada de `uart_rx`. Se mantienen el comportamiento de recepción, las señales de acción y los indicadores aprobados. La representación externa de `global_state` y los mensajes del protocolo conservan sus contratos.

**Justificación:** Mantener la codificación del TP2 permite reconocer directamente cada fase de recepción en simulación y reutilizar la referencia de diseño al aplicar las correcciones docentes.

**Consecuencias y alcance pendiente:** La [tabla de codificación](../architecture/uart/uart_rx.md#codificación-del-estado) completa este detalle del receptor. El trabajo continúa con el transmisor, el generador de ticks, las FIFO y la integración UART, además del control del protocolo. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la codificación interna pendiente de los acuerdos del receptor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Organización del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Transmisor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** `uart_tx` reutiliza FSM, dos contadores, registro de byte y registro de salida del TP2, con separación entre control y acciones.

**Decisión:** El transmisor diferencia TX Control, Sample Counter, Bit Counter, TX Shift Register y TX Output Register como partes funcionales internas de `uart_tx`. La FSM calcula el siguiente estado y emite controles; la lógica de cada contador y registro realiza las actualizaciones al flanco del clock funcional común.

Se conservan el contador de duración de cuatro bits, el contador de datos de tres, el registro del byte de ocho y el registro de salida de un bit para la configuración 8N1 con factor 16. El registro del byte permite capturar el dato a transmitir; el registro de salida conserva el nivel de TX entre actualizaciones. La preparación del valor de salida pertenece al camino de datos, bajo selección de la FSM. La separación no exige módulos nuevos ni un ciclo adicional entre orden y acción.

**Justificación:** Los recursos del TP2 cubren la transmisión de un byte y permiten aplicar las correcciones docentes haciendo explícitas las órdenes sobre los registros y contadores. La salida registrada conserva la organización existente del nivel serie.

**Consecuencias y alcance pendiente:** La [arquitectura del transmisor](../architecture/uart/uart_tx.md) documenta la organización y propone controles para su desarrollo. Permanecen pendientes estados, transiciones, codificación, selector, puertos y temporización de eventos, además del diseño de los demás bloques e integración UART. El fin físico de Stop debe respetar el protocolo aprobado. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aplica al transmisor el criterio de separación entre control y acciones y complementa el diseño del receptor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Estados del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Transmisión de trama y finalización física.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** `IDLE`, `START`, `DATA` y `STOP` conservan el recorrido TP2. `tx_done_tick` comunica fin físico después del Stop completo; las órdenes FSM actualizan los recursos.

**Decisión:** `IDLE` conserva la línea alta y acepta el byte cuando `tx_start` está activo. En el flanco de aceptación se carga el registro del byte, se inicializan los contadores, se registra cero en TX y se pasa a `START`. `START` cuenta dieciséis ticks y luego presenta D0. `DATA` conserva cada bit durante dieciséis intervalos de tick y realiza siete transiciones de D0 a D7, ordenando el desplazamiento, el incremento de índice y la escritura del bit siguiente en el mismo flanco. Al terminar D7 se registra uno en TX y se pasa a `STOP`.

`STOP` conserva el nivel alto durante dieciséis intervalos completos de tick. `tx_done_tick` es un evento combinacional consumido una vez en el flanco que termina ese intervalo y devuelve la FSM a `IDLE`. `tx_busy` informa `START`, `DATA` y `STOP`. El `reset` lleva a `IDLE`, inicializa recursos y salida alta y suprime los indicadores de envío. La [descripción y tabla de acciones](../architecture/uart/uart_tx.md#estados-y-transiciones) documentan las condiciones y el uso de los datos previos al flanco, conservando el comportamiento del TP2.

El evento de finalización corresponde al fin físico del byte, incluido todo el Stop, según el [protocolo](../protocol.md). La integración debe llevarlo al control del protocolo para coordinar los hitos que requieren una respuesta ya transmitida. Encolar el byte o comenzar su Stop no equivale a esa finalización.

**Justificación:** Los cuatro estados del TP2 cubren el envío 8N1. La separación entre control y acciones mantiene las fases existentes y hace explícita la relación entre actualizaciones del registro del byte, del pin y de los contadores. Completar Stop respeta los presupuestos y exclusiones aprobados del protocolo.

**Consecuencias y alcance pendiente:** Se concretan estados, transiciones, controles y temporización de eventos. Permanecen pendientes la codificación privada, la codificación del selector y los puertos e integración, además del diseño de los demás bloques UART. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa los estados y acciones pendientes del acuerdo de organización del transmisor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Codificación one-hot del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Codificación privada del transmisor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** Los cuatro estados del transmisor conservan codificación one-hot privada, coherente con sus transiciones y fin físico.

**Decisión:** El registro de estado del transmisor tiene cuatro bits. Los valores legales son `IDLE`=0001, `START`=0010, `DATA`=0100 y `STOP`=1000. El `reset` lleva a `IDLE`. El siguiente estado se calcula combinacionalmente y se registra al flanco ascendente del clock funcional, conforme a los controles y transiciones ya documentados.

La codificación pertenece a la FSM privada de `uart_tx`. Se conservan el comportamiento de transmisión y los eventos aprobados; la representación externa de `global_state` y los mensajes del protocolo mantienen sus contratos.

**Justificación:** Mantener la codificación del TP2 permite reconocer directamente cada fase de transmisión en simulación y reutilizar la referencia existente al aplicar las correcciones docentes.

**Consecuencias y alcance pendiente:** La [tabla de codificación](../architecture/uart/uart_tx.md#codificación-del-estado) completa este detalle del transmisor. Permanecen pendientes la codificación del selector de salida, la frontera de puertos y la integración, además de los demás bloques UART y del control del protocolo. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la codificación privada pendiente del acuerdo de estados del transmisor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Selector de salida del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Selección del dato de salida.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** La FSM TX necesita seleccionar mediante dos bits el valor del registro de salida y habilitar por separado su captura.

**Decisión:** `tx_output_select[1:0]` utiliza HIGH=00, LOW=01, `CURRENT_BIT`=10 y `NEXT_BIT`=11.

| Selección TX  | Valor preparado                                                                                |
|---------------|------------------------------------------------------------------------------------------------|
| HIGH          | Uno para reposo y Stop                                                                         |
| LOW           | Cero para Start                                                                                |
| `CURRENT_BIT` | `data_reg[0]` para comenzar D0                                                                 |
| `NEXT_BIT`    | `data_reg[1]` previo al flanco para comenzar D1 a D7 mientras se desplaza el registro del byte |

El selector controla la lógica combinacional de entrada del registro de salida. `tx_write_enable` autoriza la captura al flanco del clock funcional. Sin ese enable, el registro conserva su nivel. Ambos controles permanecen dentro de `uart_tx`; la FSM indica qué valor corresponde y la lógica del recurso realiza la selección y la actualización.

**Justificación:** Las cuatro alternativas cubren los niveles de Start, Stop y reposo y el recorrido de los bits de datos del TP2. Distinguir selección y captura hace explícita la separación entre control y acciones y conserva el uso de los datos previos al flanco.

**Consecuencias y alcance pendiente:** La [tabla de selección](../architecture/uart/uart_tx.md#selección-del-nivel-de-salida) completa la codificación de este control. La frontera de puertos se presenta para aprobación y su conexión se completará en la integración UART, junto con los demás bloques pendientes. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa el selector pendiente del diseño del transmisor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Puertos del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Frontera del módulo transmisor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** La frontera `uart_tx` conserva los puertos TP2 y debe concordar con FSM, acciones y selector de salida.

**Decisión:** `uart_tx` recibe `clk`, `reset`, `tx_start` y `s_tick` de un bit, y `data_in` de ocho bits. Produce tx, `tx_busy` y `tx_done_tick` de un bit. `clk` y `reset` pertenecen al dominio funcional común; `s_tick` es el pulso de sobremuestreo compartido. La integración UART aporta la solicitud de envío y el byte de la FIFO TX y consume la ocupación y la finalización física. tx alimenta la línea `serial_tx` mediante la integración.

El byte se captura al flanco que acepta `tx_start` estando en `IDLE`. La integración presenta `data_in` estable para ese flanco. La transmisión posterior utiliza el registro interno del byte; los controles de captura, desplazamiento, contadores y selección de salida permanecen dentro del módulo. `tx_done_tick` se consume al flanco final del Stop completo, según el acuerdo de estados.

**Justificación:** La interfaz existente del TP2 cubre la entrega de un byte, la solicitud de inicio, la salida serie y los avisos de ocupación y finalización. La separación interna entre control y acciones se realiza conservando esa frontera.

**Consecuencias y alcance pendiente:** La [frontera de puertos](../architecture/uart/uart_tx.md#frontera-de-uart_tx) completa este detalle del transmisor. El siguiente bloque a diseñar es el generador de ticks compartido. La coordinación de las FIFO, la exposición de los eventos al control del protocolo y el diseño de ese control siguen pendientes. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la frontera de puertos pendiente del diseño del transmisor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Generador de ticks UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Referencia temporal compartida.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El generador TP2 se adapta a 50 MHz: pulso de un clock cada 163 clocks y contador de ocho bits de cero a 162.

**Decisión:** Se conserva `baud_tick_gen` con el cálculo de divisor entero redondeado al valor más cercano. Para `CLK_FREQ_HZ`=50.000.000, `BAUD_RATE`=19.200 y OVERSAMPLE=16, la frecuencia nominal de ticks es 307.200 Hz, el divisor ideal es 162,760416… y el entero seleccionado es 163. La cuenta y la salida registrada mantienen el comportamiento del TP2: el contador vuelve a cero al llegar a 162 y `s_tick` vale uno durante un clock; los demás flancos incrementan la cuenta y registran cero en `s_tick`.

Una única instancia alimenta a RX y TX. Ambos consumen el pulso en el flanco siguiente a su generación, dentro del mismo dominio funcional, y usan `clk` para registrar sus recursos. El generador permanece activo entre tramas y durante `HOLD` de CPU. El `reset` funcional pone contador y salida en cero; se conservan los puertos `clk`, `reset` y `s_tick`, todos de un bit.

El baud efectivo es aproximadamente 19.171,78, con error relativo de −0,147 % respecto del nominal. El protocolo, la configuración de PC y sus presupuestos conservan 19200 baud nominales y los márgenes ya aprobados.

**Justificación:** El redondeo existente del TP2 produce el divisor entero más próximo a la frecuencia objetivo y permite reutilizar el generador con la frecuencia funcional aprobada para el TP3. Compartir la referencia conserva la organización UART existente.

**Consecuencias y alcance pendiente:** La [arquitectura del generador](../architecture/uart/uart_baud_tick_gen.md) concreta la cuenta, el pulso, su consumo y la frontera del bloque. El diseño continúa con las FIFO y la integración UART y del control del protocolo. La plataforma física y la validación del enlace en simulación y FPGA siguen pendientes. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la realización del generador pendiente de la configuración física UART; no cierra DEC-SYS-007 ni cambia el baud nominal del protocolo.

### Acuerdo parcial de DEC-SYS-007 — Funcionamiento de las FIFO UART

**Estado del acuerdo:** Aprobado como base de diseño. Suficiencia condicionada al contrato de consumo; DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Almacenamiento temporal de bytes.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** Las FIFO TP2 aportan cuatro entradas por sentido. Su reutilización con margen se distingue de la comprobación posterior de latencias del controlador TP3.

**Decisión:** Se conserva el módulo `fifo` con dos instancias independientes, RX y TX, cada una de cuatro entradas de ocho bits. Cada instancia mantiene punteros de lectura y escritura de dos bits y ocupación de tres bits. `wr` escribe al flanco si existe espacio; `read_data` presenta el byte más antiguo, válido con `empty` en cero, y `rd` lo retira al flanco si hay datos. `empty` y `full` derivan de la ocupación. Se conservan las reglas de aceptación del TP2 usando flags previos al flanco; cuando ambas operaciones se aceptan, ambas ocurren y la ocupación permanece igual.

El `reset` pone ambos punteros y la ocupación en cero y suprime operaciones de ese flanco. Se conservan los puertos `clk`, `reset`, `rd`, `wr`, `write_data`, `read_data`, `empty` y `full`, con ancho de datos de ocho bits y un bit en las demás señales. Los productores y consumidores de RX y TX se concretarán en la integración UART.

La profundidad de cuatro bytes se mantiene como capacidad de referencia y margen, bajo el contrato ya aprobado de retirar y procesar cada byte de `LOAD` antes del siguiente, incluida la escritura IMEM. TX se produce progresivamente; esperar espacio conserva el byte pendiente y permite continuar con RX. Antes de implementar el control del protocolo se demostrará documentalmente la latencia máxima de consumo y la continuidad de recepción o descarte durante espera TX; después se verificarán en simulación.

**Justificación:** A 19200 baud nominales y 8N1 existe aproximadamente un intervalo de 0,520833 ms, unos 26.042 clocks de 50 MHz, entre bytes completos. Cumplir el contrato evita acumulación sostenida de RX, mientras un registro externo reúne los bytes de cada instrucción. TX no exige almacenar la respuesta completa. Cuatro no se presenta como un mínimo derivado de latencias todavía desconocidas.

**Consecuencias y alcance pendiente:** La [arquitectura de las FIFO](../architecture/uart/uart_fifo.md) concreta recursos, operaciones, flags, `reset` y puertos. La [comprobación de suficiencia](../architecture/uart/uart_fifo.md#fundamento-de-la-capacidad-y-comprobación-pendiente) queda como condición pendiente antes de implementar el controlador. El siguiente paso es la conexión de RX y TX en la integración UART. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el funcionamiento de las FIFO del acuerdo de buffers y explicita la demostración pendiente del contrato de consumo; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Conexiones internas de uart_core

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Integración de caminos de bytes.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** `uart_core` conecta recepción válida a FIFO RX, consumo desde el controlador y producción de respuestas hacia FIFO TX. TX comienza con datos y transmisor libre; el retiro ocurre al completar Stop.

**Decisión:** `uart_core` conserva la integración de `serial_input_sync`, `baud_tick_gen`, `uart_rx`, `uart_tx` y dos instancias `fifo`. El sincronizador alimenta la entrada RX y un único generador aporta el tick compartido. Los parámetros comunes se adaptan al dominio funcional de 50 MHz y a la configuración UART y profundidades aprobadas.

En RX, `rx_done_tick` solicita la escritura de `received_data` en la FIFO; el control del protocolo observa `r_data` y `rx_empty` y genera `rd_uart` para consumir o descartar. En TX, el control entrega `w_data` y `wr_uart` con espacio disponible, conservando el byte pendiente cuando `tx_full` está activo. El primer byte de FIFO alimenta `uart_tx.data_in`; fuera de `reset`, `tx_start` se activa cuando `tx_empty` y `tx_busy` valen cero. Durante `reset` se suprime el comienzo.

El byte TX permanece en la FIFO durante su transmisión. `tx_done_tick` solicita su retiro en el mismo flanco que completa Stop y devuelve el transmisor a `IDLE`. Después del flanco se presenta el nuevo primer byte y, si existe, se solicita el siguiente envío. La [arquitectura de integración](../architecture/uart/uart_core.md) documenta las conexiones y sus relaciones temporales.

La interpretación de comandos, el descarte por fase y la coordinación de respuestas corresponden al control del protocolo. Los caminos físicos RX y TX continúan independientes y no dependen de la autorización de ciclos CPU.

**Justificación:** La conexión del TP2 conserva el orden de los bytes y relaciona el retiro TX con la finalización física requerida por el protocolo. Separar las solicitudes de los dos caminos permite que el futuro controlador conserve la continuidad RX durante espera TX.

**Consecuencias y alcance pendiente:** Las conexiones de datos y solicitudes quedan definidas. La frontera ampliada con indicadores RX y fin TX y el reporte de error combinado permanecen como propuesta pendiente de aprobación. La FSM del control del protocolo, el seguimiento de respuestas y la demostración del presupuesto de consumo continúan pendientes. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la conexión de los bloques UART del TP2 con los recursos y contratos definidos para TP3; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Puertos y reporte de errores de uart_core

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Frontera con el control del protocolo.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** La frontera UART conserva puertos TP2 y expone actividad RX, recepción en curso y fin físico TX, con un reporte combinado de trama inválida/desbordamiento RX.

**Decisión:** `uart_core` conserva las entradas `clk`, `reset`, `serial_rx`, `rd_uart`, `w_data` y `wr_uart` y las salidas `serial_tx`, `r_data`, `rx_empty`, `tx_full` y `rx_error_tick`. Agrega las salidas `rx_activity`, `rx_receiving` y `tx_done_tick`. `w_data` y `r_data` tienen ocho bits; las demás señales tienen uno. La frontera consta de seis entradas y ocho salidas.

Los dos indicadores RX y el evento de fin TX llegan directamente desde `uart_rx` y `uart_tx` al control del protocolo, sin registro adicional en `uart_core`. Conservan sus condiciones y flancos de consumo. El evento TX permite identificar el final físico de las respuestas siguiendo sus bytes en orden; la realización de ese seguimiento permanece pendiente.

`rx_error_tick` se activa ante `frame_error_tick` o ante `rx_done_tick` con `rx_full` previo al flanco. Se consume en el flanco correspondiente y vale cero durante `reset`. El reporte no distingue externamente entre error de trama y desbordamiento ni se repite por mantener RX llena. `rx_full`, `rx_done_tick`, `tx_empty` y `tx_busy` permanecen internos a `uart_core`.

**Justificación:** Los puertos del TP2 permiten intercambiar bytes y conocer la disponibilidad de las FIFO. Las tres salidas adicionales aportan la información ya requerida para recuperación por silencio, recepción en curso y finalización física de aceptación y Debug. El reporte combinado cubre las causas UART que el protocolo trata mediante la política de recuperación aprobada.

**Consecuencias y alcance pendiente:** La [frontera](../architecture/uart/uart_core.md#frontera-de-uart_core) y el [reporte de errores](../architecture/uart/uart_core.md#reporte-de-errores) quedan definidos, junto con las conexiones internas aprobadas previamente. Continúan pendientes la organización y FSM privadas del control del protocolo, sus puertos hacia los servicios, la serialización y seguimiento de respuestas y la demostración de latencia y continuidad RX durante espera TX. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Resuelve la propuesta de frontera ampliada y reporte combinado del acuerdo de conexiones internas de `uart_core`; no cierra DEC-SYS-007 ni modifica los formatos del protocolo.

### Acuerdo parcial de DEC-SYS-007 — Organización funcional del control del protocolo

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Interpretación de operaciones y coordinación de respuestas.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El control de protocolo distingue interpretación/coordinación, recursos y generación de respuestas antes de concretar agrupación, puertos y estados.

**Decisión:** El control interpreta las solicitudes y determina cuándo consumir o descartar RX, coordinando `LOAD`, `RUN`, `STEP`, `RESET` y `CHECK_READY` con los bloques correspondientes. Los registros y contadores conservan código, tamaño, progreso y tiempos de espera, y se actualizan mediante las señales de acción emitidas por la FSM. La generación de respuestas forma cabeceras y serializa Debug, conserva el byte pendiente durante TX llena y sigue la finalización física de las respuestas.

El Loader conserva la reconstrucción de palabras y la escritura IMEM. La FSM global CPU conserva el control de ejecución. La fase del transporte, los recursos privados del protocolo y la generación de respuestas permanecen activos en el dominio funcional común durante `HOLD` de CPU. La espera por TX no bloquea el consumo o descarte RX que corresponda a la fase.

Esta separación es funcional. No fija un módulo por responsabilidad, un módulo por registro, nombres de puertos ni una única FSM para todos los servicios.

**Justificación:** Distinguir interpretación, recursos y respuestas aplica la separación entre control y acciones indicada por el profesor y permite concretar el protocolo sin mezclar las responsabilidades del transporte, Loader y ejecución CPU.

**Consecuencias y alcance pendiente:** La [organización funcional](../architecture/debug/protocol_controller.md) registra las responsabilidades y su relación con los bloques existentes. Quedan pendientes la agrupación en módulos, las fronteras y recursos concretos, las FSM privadas, la coordinación de respuestas y `reset` y la demostración de las latencias de consumo. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-001`, `REQ-DBG-002`, `REQ-DBG-003`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la separación funcional del control pendiente después de definir `uart_core`; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Módulos del control del protocolo y respuestas

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Agrupación del control y serialización.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** `protocol_controller` y `response_serializer` separan coordinación de comandos y producción de respuestas, cada uno con controles y recursos internos.

**Decisión:** `protocol_controller` interpreta solicitudes, consume o descarta RX y coordina las operaciones con Loader y control de ejecución. Contiene su FSM, registros y contadores. `response_serializer` forma las cabeceras, recorre la información Debug y entrega los bytes a TX. Contiene los controles, registros y contadores necesarios para recorrer el mensaje y seguir su transmisión física.

El controlador indica qué respuesta enviar y el serializador comunica cuándo termina físicamente el último byte, incluido Stop. Durante espera por espacio TX, `protocol_controller` conserva el consumo o descarte RX de la fase. Los recursos se actualizan mediante señales de acción de sus controles respectivos; no se exige un módulo adicional por registro o contador.

El consumo RX y los indicadores de recepción corresponden al controlador. La producción TX, `tx_full` y `tx_done_tick` corresponden al serializador. Loader conserva la reconstrucción de instrucciones y escritura IMEM, y la FSM global CPU conserva ejecución. La ocupación TX no equivale por sí misma a `HOLD` de CPU.

**Justificación:** La agrupación permite atender RX mientras se produce una respuesta y concentra el recorrido y envío de Debug en un módulo específico. Mantiene la separación docente entre control y acciones sin mezclar el transporte con las responsabilidades de carga y ejecución.

**Consecuencias y alcance pendiente:** La [agrupación](../architecture/debug/protocol_controller.md#agrupación-en-módulos) y la [responsabilidad del serializador](../architecture/debug/response_serializer.md) quedan aprobadas. La comunicación de solicitud y finalización se presenta como propuesta pendiente; las demás fronteras, FSM privadas, recursos, coordinación de pendientes y demostración del presupuesto de consumo continúan abiertos. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-001`, `REQ-DBG-002`, `REQ-DBG-003`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la agrupación pendiente del acuerdo de organización funcional del control del protocolo; no cierra DEC-SYS-007 ni modifica los formatos del protocolo.

### Acuerdo parcial de DEC-SYS-007 — Solicitud y finalización de respuestas

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Comunicación entre controlador y serializador.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El serializador debe capturar código, resultado y selección Debug de una respuesta completa, e informar ocupación y fin físico al controlador.

**Decisión:** `protocol_controller` presenta `response_opcode[7:0]`, `response_result[7:0]` y `response_with_debug` y activa `response_start` durante un clock cuando `response_serializer` está libre. Fuera de `reset`, la solicitud se acepta al flanco con `response_busy` en cero. Los tres campos están estables para ese flanco y se capturan en registros internos del serializador; sus cambios posteriores en el controlador no alteran la respuesta en curso.

`response_with_debug` selecciona el cuerpo después de los dos bytes de cabecera para `STEP` realizado y `RUN` terminal. Las demás respuestas se limitan a la cabecera, incluidos rechazos y `RUN` / `ACCEPTED`. Las señales son internas y no agregan campos al enlace UART.

`response_busy` permanece activo desde la aceptación hasta el fin físico del último byte, incluidas producción, espera por espacio TX y salida de los bytes encolados. `response_done_tick` comunica una única finalización durante un clock y se consume en el flanco que completa el último Stop, con la misma referencia temporal de `tx_done_tick`. Después del flanco el serializador queda libre para una solicitud posterior. Durante `reset` se suprimen aceptación y finalización y se desactiva ocupación; un envío abortado por `reset` no se informa como terminado normalmente.

El serializador atiende una respuesta por vez. Los pendientes y el orden entre respuestas corresponden al controlador; no se agrega una cola de respuestas al serializador. El consumo o descarte RX continúa durante espera TX.

**Justificación:** Capturar la descripción evita depender de cambios posteriores en el controlador. Distinguir respuesta en curso y fin físico permite iniciar el timeout `LOAD`, aplicar `RESET` o liberar la exclusión Debug en el hito ya aprobado, sin confundir escritura en FIFO con transmisión completa.

**Consecuencias y alcance pendiente:** La [frontera y secuencia](../architecture/debug/response_serializer.md#comunicación-con-el-controlador) quedan aprobadas. Permanecen pendientes los recursos y controles internos, la identificación del último byte físicamente transmitido, la frontera y recorrido Debug, la coordinación de pendientes y `reset` y la demostración del presupuesto de consumo. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Resuelve la propuesta de comunicación pendiente del acuerdo de módulos del control del protocolo y respuestas; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Organización interna del serializador

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Recursos de producción y seguimiento de respuestas.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** `response_serializer` necesita cinco grupos: FSM, descriptor, próximo byte, recorrido y seguimiento de transmisión. Las actualizaciones de recursos permanecen separadas del control.

**Decisión:** `response_serializer` contiene FSM de control, registro de descripción de 17 bits, registro del próximo byte de ocho bits con indicador de disponibilidad, recursos de recorrido y seguimiento de transmisión. El descriptor conserva código, resultado y selección de Debug. Los recursos de recorrido identifican sección, campo y byte; sus índices y anchos se definirán al concretar la secuencia.

El seguimiento contiene un contador de tres bits que recorre cero a cuatro bytes TX pendientes y un indicador de producción completa de un bit. La cuenta incluye el byte en transmisión, que permanece en la FIFO hasta terminar Stop, y excluye el próximo byte todavía no encolado. Aumenta con escritura TX aceptada y disminuye con fin físico; eventos simultáneos conservan la cuenta. Se inicia en cero con `reset` o nueva respuesta. La cota proviene de la FIFO TX de cuatro entradas, del único productor y de comenzar cada respuesta después del fin físico de la anterior.

La producción queda completa cuando el último byte se incorpora a TX. La condición de fin físico utiliza respuesta en curso, producción completa, un byte pendiente y `tx_done_tick` previo al flanco. El contador vacío mientras aún se producen bytes no finaliza la respuesta. La FSM emite las señales de acción y cada recurso realiza sus actualizaciones al flanco funcional.

**Justificación:** La organización permite producir el mensaje progresivamente y conservar el byte durante espera TX. Separar posición, producción completa y bytes pendientes evita confundir el último byte generado con su salida física y fundamenta el ancho del contador en la conexión de la FIFO aprobada.

**Consecuencias y alcance pendiente:** La [organización interna](../architecture/debug/response_serializer.md#organización-interna) y el [seguimiento](../architecture/debug/response_serializer.md#seguimiento-de-transmisión) concretan estos grupos. Siguen pendientes el recorrido, sus recursos e índices, los controles y estados de FSM, la frontera de lectura Debug y la coordinación del controlador. La demostración del presupuesto de consumo continúa pendiente. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-009`, `REQ-UART-011`, `REQ-DBG-005` a `REQ-DBG-010`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la organización interna del serializador pendiente después de definir la solicitud y finalización de respuestas; no cierra DEC-SYS-007 ni modifica los formatos del protocolo.

### Acuerdo parcial de DEC-SYS-007 — Dos recorridos de DMEM para Debug

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Recorrido y serialización de memoria utilizada.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** `used_count` precede a las entradas DMEM. Se requiere un recorrido de conteo y otro de producción, con estado observado retenido durante toda la respuesta.

**Decisión:** Para una respuesta con Debug, `response_serializer` recorre primero todas las direcciones de byte de DMEM y calcula `used_count` según los metadatos de bytes escritos por stores comprometidos en la sesión. Cuenta también valores cero y cada dirección aparece una sola vez. Después produce cabecera, contexto, RF, registros interetapa y `used_count` en el orden aprobado por el protocolo. Finalmente vuelve a recorrer DMEM desde cero, en orden creciente, y produce dirección de cuatro bytes little-endian y valor actual de un byte por cada posición utilizada.

La cantidad se transmite en cinco bytes little-endian. Si vale cero, se omiten la lista y el segundo recorrido. Una respuesta sin Debug produce solo su cabecera y no recorre DMEM. La exclusión ya aprobada mantiene estables datos y metadatos desde el instante observado hasta el Stop del último byte; UART y el consumo o descarte RX siguen activos.

**Justificación:** El primer recorrido obtiene la cantidad antes de que deba enviarse y el segundo permite producir una lista ordenada directamente desde el estado retenido, sin almacenar una copia completa. La estabilidad entre recorridos garantiza que la cantidad y las entradas representan la misma observación.

**Consecuencias y alcance pendiente:** La [secuencia del serializador](../architecture/debug/response_serializer.md#recorrido-de-dmem-y-orden-de-producción) queda definida. Permanecen pendientes los índices y anchos, los puertos de consulta de metadatos y datos, el recorrido de las demás secciones, los controles y estados de FSM y la comprobación de sus latencias. El trabajo continúa únicamente en documentación; no se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Resuelve la secuencia de conteo y envío de DMEM pendiente después de la organización interna del serializador; no cierra DEC-SYS-007 ni modifica el layout del protocolo.

### Acuerdo parcial de DEC-SYS-007 — Registros de dirección y cantidad del recorrido DMEM

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Recursos internos del recorrido de memoria utilizada.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** La dirección examinada y la cantidad de posiciones utilizadas representan magnitudes distintas y requieren recursos separados. Sus anchos se concretan en el acuerdo siguiente.

**Decisión:** `response_serializer` contiene un registro de dirección de DMEM reutilizado para ambos recorridos y un contador `used_count` separado. El registro de dirección comienza en cero para el primer recorrido y vuelve a cero antes del segundo. El contador comienza en cero, aumenta por cada byte utilizado según metadatos durante el primer recorrido y conserva la cantidad obtenida durante la producción de la cantidad y de la lista.

Ambos recursos pertenecen al grupo interno de recorrido y se actualizan mediante acciones de la FSM, conforme al criterio de diseño aprobado. Su separación permite mantener el total calculado mientras la dirección avanza nuevamente para producir las entradas.

**Justificación:** Los recorridos son sucesivos y pueden reutilizar una misma posición. La cantidad debe conservarse independientemente de esa posición para enviarla antes de la lista y mantener el resultado del conteo.

**Consecuencias y alcance pendiente:** La [descripción de recursos](../architecture/debug/response_serializer.md#recursos-de-dirección-y-cantidad) concreta sus funciones. Los anchos de ambos recursos, los índices de byte y de las demás secciones, los controles y estados de FSM y los puertos de lectura permanecen pendientes. La aprobación no incluye la propuesta anterior de anchos en bits. El trabajo continúa únicamente en documentación.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta dos recursos del recorrido DMEM aprobado; no cierra DEC-SYS-007 ni modifica la representación UART.

### Acuerdo parcial de DEC-SYS-007 — Anchos de dirección y cantidad del recorrido DMEM

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Dimensionamiento de recursos de memoria utilizada.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** La última dirección y el máximo total utilizado tienen rangos diferentes; ambos recursos se dimensionan según la capacidad configurada.

**Decisión:** En `REFERENCE`, con DMEM de 2048 bytes, el registro de dirección tiene 11 bits para representar 0 a 2047 y el contador `used_count` tiene 12 bits para representar 0 a 2048 inclusive. Para capacidad C en bytes, los anchos se derivan como max(1, ceil(log2(C))) y max(1, ceil(log2(C + 1))), respectivamente, dentro del dominio de parametrización de memoria aprobado.

Por aplicación de esa regla, `ALT_1000` utiliza diez bits para ambos recursos: dirección 0 a 999 y cantidad 0 a 1000. La representación UART conserva dirección de cuatro bytes y cantidad de cinco bytes little-endian; los bits superiores sin correspondencia en el recurso interno se completan con ceros.

**Justificación:** El contador necesita representar C cuando todas las posiciones están utilizadas. La dirección solo necesita llegar a C − 1; con capacidad potencia de dos, el contador requiere un bit más. Derivar anchos por capacidad conserva la parametrización sin exigir potencias de dos.

**Consecuencias y alcance pendiente:** Los [anchos del serializador](../architecture/debug/response_serializer.md#anchos-de-dirección-y-cantidad) quedan fijados. Siguen pendientes los índices de byte, el recorrido de las demás secciones, los controles y estados de FSM y los puertos de lectura Debug. Esta revisión documental no acredita implementación RTL, síntesis ni timing.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-UART-005`, `REQ-MEM-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa los anchos pendientes del acuerdo de registros de dirección y cantidad; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Índice de byte compartido para cantidad y entradas DMEM

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Posición dentro de campos de memoria utilizada.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** Cantidad utilizada y entradas DMEM ocupan cinco bytes. Un índice compartido recorre ambos formatos; cada entrada contiene cuatro bytes de dirección y uno de valor.

**Decisión:** `response_serializer` contiene un índice de byte de tres bits que recorre posiciones cero a cuatro y se reutiliza para producir `used_count` y cada entrada DMEM. Comienza en cero para la cantidad y vuelve a cero al comenzar cada entrada. Durante `used_count` selecciona sus cinco bytes little-endian, con extensión superior en cero desde el contador interno. Durante una entrada, posiciones cero a tres seleccionan los cuatro bytes little-endian de dirección y posición cuatro selecciona el valor actual del byte de memoria.

La fase de producción distingue cantidad de entrada. El índice pertenece al grupo de recorrido y conserva una posición distinta de la dirección de DMEM: identifica qué byte del campo o entrada se produce.

**Justificación:** Ambos elementos tienen cinco bytes y se producen sucesivamente, de modo que pueden compartir un mismo recurso. Tres bits permiten representar cero a cuatro; dos bits no representan la quinta posición.

**Consecuencias y alcance pendiente:** La [selección por índice](../architecture/debug/response_serializer.md#índice-de-byte-de-cantidad-y-entradas-dmem) queda definida. Siguen pendientes el momento de avance durante producción y espera TX, los controles, estados de FSM, nombres HDL, índices de las demás secciones y puertos de lectura. El acuerdo no acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el índice de byte de cantidad y entradas DMEM; no cierra DEC-SYS-007 ni modifica el layout UART.

### Acuerdo parcial de DEC-SYS-007 — Avance del recorrido DMEM por escritura TX aceptada

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Avance del recorrido y espera por espacio TX.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** El índice avanza solo al incorporar el byte a FIFO TX. Durante espera conserva posición y dato, y la dirección se mantiene hasta completar los cinco bytes de la entrada.

**Decisión:** El índice de byte de `used_count` y de las entradas avanza por escritura TX aceptada, con `wr_uart` activo y `tx_full` en cero previos al flanco. Mientras un byte preparado no sea aceptado, se conservan byte, disponibilidad e índice; en una entrada, también su dirección de DMEM. Preparar o capturar el byte no adelanta el índice.

Las posiciones cero a tres avanzan al siguiente índice tras su aceptación. Aceptar la posición cuatro de `used_count` completa la cantidad; aceptar la posición cuatro de una entrada completa su encolado y habilita avanzar a la siguiente dirección si el recorrido continúa. Cada nueva entrada comienza con índice cero. Las posiciones no utilizadas se saltan durante búsqueda sin producir bytes TX. `used_count` conserva el total obtenido en el primer recorrido.

UART transmite en paralelo y la finalización física sigue perteneciendo al seguimiento TX aprobado, hasta Stop del último byte. Durante espera TX el controlador mantiene la atención o descarte RX según la fase.

**Justificación:** El avance por aceptación preserva orden y evita omitir o duplicar bytes bajo FIFO llena. Conservar la dirección hasta encolar el valor mantiene juntos los cinco bytes de una entrada.

**Consecuencias y alcance pendiente:** La [política de avance](../architecture/debug/response_serializer.md#avance-durante-producción-y-espera-tx) queda definida. Siguen pendientes el cierre del recorrido y reconocimiento del último byte, los controles concretos, los estados de FSM, el recorrido de las demás secciones y los puertos de lectura. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el avance pendiente del índice compartido y la dirección de entradas DMEM; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Contador de entradas DMEM encoladas y cierre de lista

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Progreso acumulado de la lista y reconocimiento de su último byte.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** El progreso de lista cuenta entradas completas acumuladas; el contador TX cuenta bytes pendientes hasta su Stop. Son recursos con funciones y condiciones de actualización distintas.

**Decisión:** `response_serializer` agrega un contador de entradas completas encoladas dentro del grupo de recorrido. Comienza en cero al iniciar la lista y aumenta al aceptar en FIFO TX el valor de una entrada, posición cuatro del índice de byte. Los cuatro bytes de dirección y los bytes de las demás secciones no lo incrementan; ni espera TX ni `tx_done_tick` lo disminuyen. `used_count` conserva el total esperado.

La aceptación que lleva la cuenta a `used_count` incorpora el último byte de la lista y activa producción completa en ese mismo flanco. El reconocimiento usa la cuenta previa al flanco y el incremento que se aceptará, sin retrasarse a un flanco posterior. Termina el segundo recorrido y no requiere consultar direcciones posteriores. Para `used_count` cero, lista y segundo recorrido se omiten y producción completa se activa al incorporar el quinto byte de la cantidad.

La finalización física conserva el seguimiento aprobado hasta el último Stop; el contador de entradas tiene rango acumulativo de cero a `used_count` inclusive y el contador TX conserva rango cero a cuatro bytes pendientes.

**Justificación:** Conservar total esperado y progreso acumulado permite reconocer exactamente el último valor encolado, sin modificar `used_count` ni confundir entradas completas con bytes pendientes físicos.

**Consecuencias y alcance pendiente:** El [contador y cierre de lista](../architecture/debug/response_serializer.md#entradas-completas-encoladas-y-último-byte-de-la-lista) quedan definidos. Permanecen pendientes el ancho del nuevo contador, el cierre del primer recorrido, los controles y estados de FSM, nombres HDL, las demás secciones y puertos Debug. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el reconocimiento del último byte pendiente tras aprobar el avance TX; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Ancho del contador de entradas DMEM encoladas

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Dimensionamiento del progreso acumulado de la lista.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** El contador de entradas y `used_count` deben representar el mismo máximo de posiciones DMEM; comparten el ancho derivado de capacidad.

**Decisión:** El contador de entradas completas encoladas tiene max(1, ceil(log2(C + 1))) bits para capacidad C en bytes de DMEM, igual que `used_count`. `REFERENCE` utiliza 12 bits para representar cero a 2048 inclusive; `ALT_1000` utiliza diez bits para representar cero a 1000 inclusive.

Total esperado y progreso permanecen en recursos separados y conservan sus funciones aprobadas. El dimensionamiento se deriva de la capacidad configurada, sin exigir potencia de dos ni agregar un campo UART.

**Justificación:** Cuando todas las posiciones están utilizadas, el total esperado y la cuenta final de entradas encoladas alcanzan C. Ambos requieren el mismo rango y ancho.

**Consecuencias y alcance pendiente:** El [contador de entradas del serializador](../architecture/debug/response_serializer.md#entradas-completas-encoladas-y-último-byte-de-la-lista) queda dimensionado. Permanecen pendientes el cierre del primer recorrido, los controles y estados de FSM, los nombres HDL, las demás secciones y los puertos de lectura. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-UART-005`, `REQ-MEM-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa el ancho pendiente del contador de entradas encoladas; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Cierre del primer recorrido DMEM

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Conteo completo de memoria utilizada por direcciones.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** El primer recorrido debe consultar e incluir la última posición válida antes de terminar, para no omitir su marca de utilizado.

**Decisión:** El primer recorrido comienza en dirección cero y procesa cada posición de byte una vez, en orden creciente. Al procesar una posición se incrementa `used_count` si sus metadatos indican utilización. Se avanza de dirección mientras sea menor que C − 1 y se termina después de procesar C − 1, sin incrementar la dirección final, para capacidad C de DMEM.

La comparación con C − 1 es explícita y no depende del desbordamiento del registro de dirección. `REFERENCE` cierra después de la dirección 2047 y `ALT_1000` después de la 999. El incremento que corresponda a esa última posición participa del total final: cierre e incremento pueden consumirse en el mismo flanco y la parte fija posterior utiliza la cuenta registrada después de incluirla.

**Justificación:** Procesar la última posición antes de terminar evita omitir un byte utilizado. Comparar contra la capacidad menos uno conserva la parametrización no potencia de dos y mantiene la dirección dentro de su rango representable.

**Consecuencias y alcance pendiente:** El [cierre del primer recorrido](../architecture/debug/response_serializer.md#cierre-del-primer-recorrido) queda definido. Permanecen pendientes la frontera de lectura de metadatos y datos, los controles concretos y estados de FSM, el recorrido de las demás secciones y la comprobación de latencias. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-UART-005`, `REQ-MEM-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el cierre del primer recorrido pendiente después del conteo y cierre de lista; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Señales de consulta Debug de DMEM

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Frontera de dirección, valor y metadatos de memoria utilizada.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** El conteo utiliza la marca; la lista utiliza dato solo de posiciones escritas. El valor de una posición no escrita se ignora; el momento de lectura se concreta posteriormente.

**Decisión:** `response_serializer` presenta `debug_dmem_addr` a DMEM, con ancho derivado de la capacidad igual al registro de dirección de recorrido: max(1, ceil(log2(C))) bits, 11 en `REFERENCE` y diez en `ALT_1000`. DMEM devuelve `debug_dmem_data` de ocho bits y `debug_dmem_used` de uno, correspondientes al mismo byte seleccionado.

`debug_dmem_used` proviene de los metadatos de escritura de la sesión y vale uno también para un cero escrito. El conteo consume solo ese indicador. Durante listado, cero omite la posición e ignora el dato; uno permite producir dirección y valor, utilizando el dato para el quinto byte de la entrada.

Las señales conservan lectura directa de estado retenido, cero lógico de DMEM y ownership exclusivo frente a CPU y mantenimiento. La conexión no agrega una copia completa ni unos metadatos de utilización independientes.

**Justificación:** Separar dirección seleccionada, marca de utilización y valor permite contar correctamente y producir únicamente las posiciones utilizadas, sin deducir utilización de que el valor sea distinto de cero.

**Consecuencias y alcance pendiente:** Las [señales del serializador](../architecture/debug/response_serializer.md#señales-de-consulta-de-dmem) y los [puertos de DMEM](../interfaces.md#42-data-memory) quedan definidos. Permanecen pendientes la realización temporal de esta consulta, sus controles de consumo, la selección física de ownership, los estados de FSM y la lectura de RF, contexto y registros interetapa. La propuesta temporal de lectura combinacional no se registra como aprobada en este acuerdo. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la frontera de consulta DMEM pendiente después de definir sus recorridos; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Lectura Debug de DMEM entre flancos

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Contrato temporal de consulta de DMEM.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** La lectura combinacional utiliza la dirección registrada entre flancos: seleccionar 9 en A, consumir su marca en B y seleccionar 10 para el siguiente intervalo.

**Decisión:** `debug_dmem_data` y `debug_dmem_used` se presentan combinacionalmente desde la dirección seleccionada y el estado retenido de DMEM. El registro de dirección permanece estable entre flancos. La consulta se consume al flanco siguiente utilizando los valores de la dirección previa al flanco; cambiar ese registro en el mismo flanco hace que las salidas reflejen después la nueva dirección, cuya información se consume posteriormente.

Durante el primer recorrido, tras inicializar la dirección en cero y activar conteo, se procesa una posición por ciclo funcional: contar si la marca vale uno y avanzar, o cerrar después de procesar C − 1. En el segundo se aplica la misma lectura, omitiendo posiciones no utilizadas y conservando la dirección de cada entrada utilizada durante sus cinco bytes y espera TX. El valor se toma al preparar el quinto byte de la entrada.

La lectura no incorpora un registro de respuesta de DMEM ni handshake adicional. El registro del próximo byte del serializador conserva captura y espera TX. Los recursos siguen actualizándose al flanco funcional común conforme a las acciones de la FSM.

**Justificación:** La lectura combinacional aprovecha el intervalo de clock para presentar los metadatos y el dato de una dirección registrada y permite contar una posición por ciclo sin confundir la dirección previa con la seleccionada después del flanco.

**Consecuencias y alcance pendiente:** La [lectura entre flancos](../architecture/debug/response_serializer.md#lectura-de-dmem-entre-flancos) fija el contrato temporal. Permanecen pendientes los enables concretos, estados de FSM, selección física de ownership y lectura de las demás secciones. El cumplimiento del clock objetivo debe verificarse con implementación y timing; el acuerdo no acredita validación RTL ni física.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la realización temporal pendiente del acuerdo de señales de consulta Debug de DMEM; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Selector de dirección de lectura CPU/Debug de DMEM

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Memoria / Selección física de dirección de lectura para Debug.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** CPU y Debug comparten dirección de lectura DMEM mediante un mux controlado por `protocol_controller`. Preparación mantiene su camino de mantenimiento.

**Decisión:** DMEM contiene un multiplexor combinacional de dirección de lectura controlado por `dmem_debug_select` de un bit desde `protocol_controller`. Cero selecciona Address[31:0] CPU desde `EX/MEM.ex_result`; uno selecciona `debug_dmem_addr` del serializador, extendida con ceros a 32 bits. La dirección resultante es combinacional, sin un registro nuevo.

`dmem_debug_select` permanece activo desde el estado posterior al ciclo observado hasta el Stop del último byte, incluyendo espera por una respuesta anterior; durante `reset` vale cero. El ciclo que produce la observación conserva el acceso CPU antes de activar la selección Debug. El serializador consume datos y metadatos como consulta válida solo con Debug seleccionado.

La ventana exclusiva conserva CPU retenida y ausencia de preparación que modifique el estado. El multiplexor selecciona lectura y no autoriza escrituras: stores CPU y mantenimiento conservan sus acciones y prioridades. Preparación utiliza su camino propio, con realización física pendiente, y el serializador no consume consultas Debug durante preparación efectiva.

**Justificación:** Seleccionar una dirección de lectura permite compartir el acceso entre dos agentes excluyentes y evita que una dirección residual CPU determine la posición observada durante Debug. Mantener el selector durante toda la exclusión respeta la coherencia desde el instante observado, aun antes de que pueda empezar la respuesta.

**Consecuencias y alcance pendiente:** El [selector DMEM](../architecture/memory/memory_architecture.md#selector-de-dirección-de-lectura-cpudebug), los [puertos](../interfaces.md#42-data-memory) y la responsabilidad de [protocol_controller](../architecture/debug/protocol_controller.md#agrupación-en-módulos) quedan definidos. Permanecen pendientes la generación concreta en la FSM, adaptación de lanes/datos, mantenimiento físico, demás fronteras y recorrido de cabecera, contexto, RF y registros interetapa. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-010`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-MEM-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el selector de lectura CPU/Debug pendiente después de la lectura entre flancos; no cierra DEC-SYS-007 ni define todo el mantenimiento de DMEM.

### Acuerdo parcial de DEC-SYS-007 — Índice de recorrido de cabecera, contexto, RF y latches

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Posición del byte previo a la cantidad de memoria utilizada.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** Los 225 bytes de cabecera, contexto, RF y registros interetapa previos a `used_count` se recorren con un único índice; las respuestas breves solo utilizan dos posiciones.

**Decisión:** `response_serializer` contiene `fixed_byte_index` de ocho bits, con posiciones cero a 224, dentro del grupo de recorrido. Comienza en cero para cada respuesta y avanza por escritura TX aceptada. Durante espera se conservan byte preparado e índice; preparar el byte no adelanta la posición.

La distribución es: código en cero, resultado en uno, contexto en dos a 20, RF en 21 a 148, `IF/ID` en 149 a 159, `ID/EX` en 160 a 189, `EX/MEM` en 190 a 209 y `MEM/WB` en 210 a 224. Se conserva el orden y layout del protocolo.

Una respuesta sin Debug termina de producirse al aceptar posición uno y espera su fin físico. Una respuesta con Debug realiza primero el conteo DMEM y luego recorre las 225 posiciones; aceptar posición 224 completa este tramo y pasa a `used_count` con el índice compartido de tres bits en cero. La última posición de este índice se retiene al cerrar y durante las fases posteriores, sin incrementar fuera del rango.

**Justificación:** Un índice de ocho bits representa todas las posiciones y permite identificar sección y byte a partir del layout, compartiendo también el recurso con las cabeceras breves. Avanzar por aceptación conserva el mensaje bajo espera TX.

**Consecuencias y alcance pendiente:** El [recorrido anterior a used_count](../architecture/debug/response_serializer.md#recorrido-de-cabecera-contexto-rf-y-latches) queda definido. Permanecen pendientes la lectura RF y demás fronteras de observación, la selección concreta de los bytes, los controles y estados de FSM y la comprobación de latencias. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el índice de cabecera, contexto, RF y registros interetapa pendiente después del recorrido DMEM; no cierra DEC-SYS-007 ni modifica el layout UART.

### Acuerdo parcial de DEC-SYS-007 — Mux CPU/Debug de la primera lectura RF

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Lectura del banco de registros bajo exclusión CPU.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** La primera lectura RF se comparte mediante selección de índices de cinco bits. La salida conserva los 32 bits del registro elegido; no se agrega tercer puerto.

**Decisión:** Registers contiene un mux combinacional de primera dirección de lectura, con entradas Read Register 1 CPU y `debug_rf_addr[4:0]` desde `response_serializer`. `rf_debug_select` de un bit desde `protocol_controller` selecciona CPU con cero y Debug con uno. La segunda lectura mantiene su conexión CPU y el banco conserva dos puertos de lectura combinacionales.

El valor base de la primera lectura se conecta también como `debug_rf_data[31:0]` hacia el serializador, antes del bypass CPU; esa salida no agrega una tercera lectura. La regla de x0 depende de la dirección interna seleccionada. El serializador consume el dato únicamente con Debug seleccionado y durante su sección RF y produce los cuatro bytes little-endian ya aprobados.

`rf_debug_select` sigue la ventana exclusiva de observación, desde el estado posterior al ciclo CPU hasta el último Stop, incluida espera por una respuesta anterior; durante `reset` vale cero. CPU permanece retenida y no escribe RF ni se prepara una sesión durante la observación. El ciclo que produce el estado observado conserva su acceso CPU antes de activar Debug.

**Justificación:** La exclusión permite compartir una lectura existente. Seleccionar el número de registro antes de leer conserva la semántica del banco y entrega su valor arquitectónico sin copiar RF ni reutilizar datos de bypass CPU.

**Consecuencias y alcance pendiente:** La [lectura RF del serializador](../architecture/debug/response_serializer.md#lectura-rf-compartida-con-debug), los [puertos Registers](../interfaces.md#22-registers) y la relación con ID quedan definidas. Permanecen pendientes la derivación del registro y byte desde `fixed_byte_index`, la generación concreta del selector, los controles de captura, estados de FSM y observación de contexto y registros interetapa. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-005`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la lectura RF pendiente tras el índice de cabecera, contexto, RF y registros interetapa; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Derivación de registro y byte RF desde el índice de recorrido

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Selección de registro y byte dentro del bloque RF.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** `fixed_byte_index` permite derivar registro y byte RF: x0 comienza en 21, cada registro ocupa cuatro posiciones y x1 comienza en 25.

**Decisión:** Durante producción RF, con `fixed_byte_index` entre 21 y 148 inclusive, se resta 21 para obtener una posición relativa de cero a 127. La división entera por cuatro produce `debug_rf_addr` de cinco bits, de cero a 31; su resto produce `rf_byte_select` de dos bits, de cero a tres. Se trata de derivaciones combinacionales, sin agregar contadores de registro ni byte RF.

Equivalentemente, los bits [6:2] de la posición relativa de siete bits seleccionan el registro y [1:0] seleccionan el byte. `rf_byte_select` elige `debug_rf_data[7:0]`, [15:8], [23:16] o [31:24] en ese orden little-endian. El próximo byte captura el dato bajo el control de la FSM; el índice solo avanza por escritura TX aceptada y conserva ambas selecciones durante espera.

La derivación se utiliza en la sección RF. Fuera de ella no se consume el retorno RF y las selecciones se presentan en cero como valores neutros. El cambio de índice al flanco modifica las selecciones para el intervalo posterior, conforme a la lectura de valores preflanco aprobada.

**Justificación:** La posición del byte en el layout ya identifica el grupo de cuatro y la posición interna del grupo. Aprovechar ese índice mantiene coherentes el registro y su byte y evita estados de posición RF independientes.

**Consecuencias y alcance pendiente:** La [derivación RF](../architecture/debug/response_serializer.md#derivación-de-registro-y-byte-rf) queda definida. Permanecen pendientes las conexiones de observación de contexto y registros interetapa, los controles concretos de captura/consumo, la generación de selectores y estados de FSM. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-005`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la selección de registro y byte pendiente del mux de primera lectura RF; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Entradas de observación del contexto

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Conexiones del contexto hacia `response_serializer`.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** El contexto tiene seis conexiones y ocupa 19 bytes, posiciones dos a 20 del recorrido que incluye cabecera.

**Decisión:** `response_serializer` recibe `debug_state_code` de ocho bits, `debug_image_valid` de uno, `debug_pc` de 32, `debug_cycle_count` de 64, `debug_fault_cause` de tres y `debug_fault_pc` de 32. Sus fuentes son, respectivamente, el código UART derivado del estado actual de la FSM global, el predicado `loaded_image_size_bytes` != 0, el registro PC global, `Cycle Counter` y los dos registros globales de fault.

Los valores se observan directamente bajo la exclusión Debug aprobada, sin copiar el contexto completo. Se consumen al producir contexto de una respuesta con Debug. Se conservan el orden, padding de campos pequeños y little-endian del protocolo: estado, `image_valid`, PC, contador, causa y PC de fault. Los registros de fault se presentan con sus bits actuales y su vigencia se interpreta según el estado global.

La entrada de estado contiene el código externo aprobado y no presupone una codificación interna de la FSM. La ubicación y realización de su adaptación combinacional permanecen pendientes al concretar ese bloque. `image_valid` no agrega almacenamiento.

**Justificación:** Los valores ya pertenecen a recursos existentes y permanecen coherentes durante la exclusión. Seis conexiones permiten acceder a ellos para formar el contexto aprobado sin introducir otro almacenamiento del snapshot.

**Consecuencias y alcance pendiente:** Las [entradas de contexto](../architecture/debug/response_serializer.md#entradas-de-observación-del-contexto) y su contrato quedan definidos. Permanecen pendientes la selección concreta de sus bytes, los controles de captura, la adaptación física del código de estado, las conexiones de registros interetapa y los controles y estados de FSM. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta las conexiones de contexto pendientes después de la derivación RF; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Selección de bytes del contexto desde el índice de recorrido

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Selección de campo y byte del contexto.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** `fixed_byte_index` selecciona campo y byte del contexto. Los valores multibyte conservan little-endian; PC=0x12345678 se transmite como 78, 56, 34 y 12.

**Decisión:** La selección es combinacional y utiliza el índice de recorrido existente, sin agregar un contador de contexto ni un índice de byte registrado.

| Posición       | Selección                                      |
|----------------|------------------------------------------------|
| Dos            | `debug_state_code`                             |
| Tres           | `debug_image_valid` con siete ceros superiores |
| Cuatro a siete | Los cuatro bytes de `debug_pc`                 |
| Ocho a 15      | Los ocho bytes de `debug_cycle_count`          |
| 16             | `debug_fault_cause` con cinco ceros superiores |
| 17 a 20        | Los cuatro bytes de `debug_fault_pc`           |

En campos de varios bytes, la posición menos el inicio del campo produce j y se seleccionan los bits [8*j + 7 : 8*j], conservando little-endian. La selección se consume al producir contexto con Debug. La FSM controla la captura del próximo byte con valores preflanco; capturarlo no adelanta el índice. El índice solo avanza por escritura TX aceptada y durante espera se conserva el byte preparado.

Aceptar posición 20 pasa a posición 21, inicio de RF, sin finalizar la producción de la respuesta.

**Justificación:** La posición del recorrido identifica tanto el campo como su byte. Reutilizarla conserva el layout aprobado y permite producir el contexto desde las seis entradas existentes.

**Consecuencias y alcance pendiente:** La [selección de bytes del contexto](../architecture/debug/response_serializer.md#selección-de-bytes-del-contexto) queda definida. Permanecen pendientes los controles de captura y consumo, la adaptación física del código de estado, las conexiones y selección de bytes de registros interetapa y los estados de FSM. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la selección de bytes pendiente después de las entradas de contexto; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Entradas de observación de IF/ID

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Conexiones del registro `IF/ID` hacia `response_serializer`.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** Los cinco campos actuales `IF/ID` alimentan su sección del snapshot UART bajo exclusión CPU, sin otra copia registrada.

**Decisión:** `response_serializer` recibe `debug_ifid_valid` de un bit, `debug_ifid_pc` de 32, `debug_ifid_instruction` de 32, `debug_ifid_fetch_fault_valid` de uno y `debug_ifid_fetch_fault_cause` de tres, desde las salidas actuales de los campos homónimos de `IF/ID`. Se conectan los 69 bits funcionales existentes, sin otra copia del registro interetapa ni lectura de sus entradas de captura o `next.valid`.

Los valores permanecen retenidos durante la ventana exclusiva Debug y se consumen al producir `IF/ID` en posiciones 149 a 159 del recorrido. Se conservan los 11 bytes, orden y padding del protocolo. Los bits registrados se transmiten también cuando los flags están inactivos y su interpretación utiliza `valid` y `fetch_fault_valid`; el candidato de fetch se distingue del fault global confirmado.

**Justificación:** La exclusión permite observar directamente el registro interetapa que conserva el estado del pipeline. Conectar sus campos completos mantiene la coherencia con el contexto y RF ya definidos y permite formar la representación UART aprobada.

**Consecuencias y alcance pendiente:** Las [entradas IF/ID](../architecture/debug/response_serializer.md#entradas-de-observación-de-ifid), las salidas de [IF](../architecture/cpu/stage_if.md#registro-ifid) y el mapa de [interfaces](../interfaces.md#19-registro-ifid) quedan concretados. Permanecen pendientes la selección de los bytes de `IF/ID`, los controles de captura y consumo, las conexiones de los demás registros interetapa y los estados de FSM. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la frontera de `IF/ID` pendiente después de la selección de contexto; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Observación y selección de bytes de los cuatro latches

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Debug / Fronteras y selección de bytes de `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** Los cuatro registros interetapa deben aplicar el mismo criterio de conexión directa y selección de bytes. Este acuerdo agrupa los tres esquemas restantes y el selector de los cuatro.

**Decisión:** `response_serializer` recibe directamente todos los campos funcionales registrados actuales de los cuatro registros interetapa mediante entradas `debug_<latch>_<campo>`, con prefijos ifid, idex, exmem y memwb.

| Registro interetapa | Campos conservados | Bits |
|---------------------|-------------------:|-----:|
| `IF/ID`             |              Cinco |   69 |
| `ID/EX`             |                 15 |  193 |
| `EX/MEM`            |               Ocho |  139 |
| `MEM/WB`            |               Seis |  103 |

Los nombres, anchos y posiciones completos quedan fijados en las [tablas del serializador](../architecture/debug/response_serializer.md#observación-y-selección-de-bytes-de-los-cuatro-latches). No se agregan copias del pipeline ni contadores por registro interetapa.

`fixed_byte_index` selecciona combinacionalmente el campo y su byte en los rangos 149 a 159, 160 a 189, 190 a 209 y 210 a 224, respectivamente. Los campos pequeños ocupan un byte con ceros superiores. Los campos de 32 bits recorren cuatro bytes little-endian: para inicio s, j = `fixed_byte_index` − s selecciona [8*j + 7 : 8*j]. Se conservan códigos y orden del protocolo.

Se consumen las entradas durante la sección correspondiente de una respuesta con Debug, bajo la exclusión ya aprobada. Se observa el valor registrado actual, también con flags inactivos, sin sustituirlo por sus entradas de captura, `next.valid` o resultados combinacionales posteriores. `valid` habilita interpretar la instrucción y `fetch_fault_valid` habilita por separado el candidato `IF/ID`.

La FSM captura el byte seleccionado usando los valores preflanco. La captura no adelanta el índice, que avanza por escritura TX aceptada y se conserva junto con el byte preparado durante espera. Aceptar 159, 189 y 209 pasa al registro interetapa siguiente. Aceptar 224 retiene el índice y pasa a `used_count` con su índice compartido en cero. Ninguna de esas transiciones completa la producción de la respuesta.

**Justificación:** Todos los registros interetapa permanecen retenidos durante Debug y su layout está aprobado. Una regla común permite concretar las conexiones y producción de sus 76 bytes sin repetir decisiones equivalentes ni introducir recursos de recorrido independientes.

**Consecuencias y alcance pendiente:** Quedan definidas las fronteras de observación y selección de bytes de los cuatro registros interetapa. Permanecen pendientes los controles de captura y consumo, estados de FSM, adaptación física del código de estado y coordinación concreta en `protocol_controller`. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-DBG-013`, `REQ-DBG-015`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la selección pendiente de `IF/ID` y las conexiones y selección de `ID/EX`, `EX/MEM` y `MEM/WB`; conserva el acuerdo previo de entradas `IF/ID`. No cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Preparación y encolado comunes de cada byte

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Serializador / Control común del recurso de próximo byte y escritura FIFO TX.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** Todos los bytes utilizan preparación y encolado diferenciados, con el mismo registro próximo byte y avance por aceptación TX.

**Decisión:** La preparación captura el byte seleccionado para la posición actual y activa su disponibilidad, sin escribir TX ni adelantar el recorrido. En un paso posterior, el encolado presenta el byte registrado y solicita `wr_uart` con disponibilidad activa y `tx_full` en cero, fuera de `reset`. La aceptación utiliza las señales previas al flanco y consume la disponibilidad, aplicando el avance o cierre correspondiente.

Si TX está llena, el paso de encolado conserva byte, disponibilidad y posición; no recaptura ni prepara el byte siguiente. Se puede preparar aun con TX llena. Preparación y aceptación se realizan en flancos distintos. Al consumir el byte se prepara el siguiente cuando corresponde o se pasa a la consulta/recorrido o espera final que corresponda.

Reset y una nueva respuesta dejan la disponibilidad inactiva. El conteo previo DMEM y el salto de posiciones no utilizadas no producen bytes. `tx_done_tick` continúa actualizando pendientes durante preparación y espera. Las condiciones aprobadas de producción completa y último Stop permanecen vigentes; el controlador conserva su atención RX.

**Justificación:** El registro mantiene estable el byte seleccionado mientras espera espacio. Separar su captura y escritura da un mecanismo común para todos los campos y vincula el progreso a la aceptación efectiva de la FIFO.

**Consecuencias y alcance pendiente:** El [mecanismo común](../architecture/debug/response_serializer.md#preparación-y-encolado-comunes-de-cada-byte) queda definido. Permanecen pendientes la distribución entre estados privados, codificación y tabla completa de señales de acción de la FSM, la adaptación física del código de estado y la coordinación concreta del controlador. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el mecanismo de captura y entrega del próximo byte pendiente después del acuerdo conjunto de registros interetapa. No cierra DEC-SYS-007 ni define todavía toda la FSM.

### Acuerdo parcial de DEC-SYS-007 — Diez estados de la FSM del serializador

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Serializador / Estados privados y acciones de transición.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** El serializador requiere diez estados privados que distingan conteo, preparación, encolado y espera de fin físico, con función, condición de avance y destino explícitos.

**Decisión:** La FSM de `response_serializer` utiliza `IDLE`, `COUNT_DMEM`, `PREPARE_FIXED`, `ENQUEUE_FIXED`, `PREPARE_COUNT`, `ENQUEUE_COUNT`, `SCAN_DMEM`, `PREPARE_ENTRY`, `ENQUEUE_ENTRY` y `WAIT_TX_DONE`. Sus funciones, condiciones y acciones de transición quedan definidas en la [tabla de FSM](../architecture/debug/response_serializer.md#estados-de-la-fsm-del-serializador).

Una solicitud con Debug inicia conteo DMEM; sin Debug inicia parte fija. Los tres pares PREPARE/ENQUEUE identifican la clase de byte mediante el estado y conservan captura separada de escritura. `COUNT_DMEM` procesa también la última dirección. `SCAN_DMEM` omite posiciones no utilizadas y retiene la dirección durante los cinco bytes de cada entrada.

La aceptación del resultado sin Debug, del quinto byte de cantidad cero o del valor de la última entrada marca producción completa y lleva a `WAIT_TX_DONE`. Otros cierres pasan al siguiente tramo. El fin físico usa un pendiente, producción completa y `tx_done_tick`, genera `response_done_tick` en ese mismo flanco y vuelve a `IDLE`. No se agrega un estado `DONE` ni un registro de pulso que desplace ese hito.

`response_busy` permanece activo fuera de `IDLE`. El seguimiento TX atiende `tx_done_tick` durante producción y esperas. Reset tiene prioridad, aborta hacia `IDLE` y suprime escritura y finalización normal. La exclusión Debug y atención RX permanecen a cargo del controlador.

**Justificación:** Cada estado conserva la operación en curso y cada par selecciona una clase de byte y su política de avance. La secuencia expresa los recorridos y cierres aprobados usando los recursos existentes y manteniendo el fin físico separado del cierre de producción.

**Consecuencias y alcance pendiente:** Quedan definidos los diez estados, sus transiciones y acciones sobre los recursos. Permanecen pendientes su codificación, los nombres y generación de señales de acción, la adaptación física del código de estado global y la coordinación concreta del controlador. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la organización privada pendiente después de los pasos comunes de preparación y encolado. No cierra DEC-SYS-007 ni aprueba todavía la codificación de estados.

### Acuerdo parcial de DEC-SYS-007 — Codificación one-hot de la FSM del serializador

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Serializador / Registro privado de estado.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** Los diez estados del serializador adoptan un bit por estado, siguiendo el criterio de las FSM RX y TX.

**Decisión:** El estado de `response_serializer` utiliza un registro one-hot de diez bits. En el orden aprobado, `IDLE` activa el bit cero, `COUNT_DMEM` el uno, `PREPARE_FIXED` el dos, `ENQUEUE_FIXED` el tres, `PREPARE_COUNT` el cuatro, `ENQUEUE_COUNT` el cinco, `SCAN_DMEM` el seis, `PREPARE_ENTRY` el siete, `ENQUEUE_ENTRY` el ocho y `WAIT_TX_DONE` el nueve.

Reset establece `IDLE`, 0000000001. Las transiciones cargan el código del estado siguiente y mantienen un único bit activo en operación legal. Las decisiones conservan casez y comodines `?`, estado registrado y recursos separados actualizados por señales de acción. Esta codificación es interna al serializador y no modifica `debug_state_code` ni los códigos UART de la FSM global CPU.

**Justificación:** Se mantiene el criterio ya adoptado para las FSM UART. Un bit por estado identifica directamente cada una de las diez operaciones definidas, sin cambiar su secuencia ni agregar un registro de fase.

**Consecuencias y alcance pendiente:** La [codificación de los diez estados](../architecture/debug/response_serializer.md#codificación-one-hot-de-los-estados) queda definida. Permanecen pendientes los nombres y tabla de generación de señales de acción, adaptación física del código UART de estado global y coordinación concreta del controlador. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la codificación pendiente después del acuerdo de diez estados. No cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Señales de acción de la FSM del serializador

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Serializador / Órdenes sobre recursos y generación por estado.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** La tabla FSM debe seguir casez, condiciones irrelevantes y separación entre decisión combinacional y actualización registrada de recursos.

**Decisión:** Se aprueban `response_init`, `byte_load`, `byte_consume`, `fixed_index_inc`, `shared_index_clear`, `shared_index_inc`, `dmem_addr_inc`, `used_count_inc`, `list_init`, `entry_count_inc`, `production_complete_set`, `tx_pending_inc` y `tx_pending_dec`, con sus condiciones y generación por estado en la [tabla de señales](../architecture/debug/response_serializer.md#señales-de-acción-de-la-fsm).

Son órdenes combinacionales de un bit que habilitan actualizaciones de los recursos existentes al flanco. `response_init` captura el descriptor e inicializa recursos; `list_init` reinicia los tres recursos de la lista conservando `used_count`. `byte_load` captura y activa disponibilidad, `byte_consume` la desactiva por escritura aceptada. Índices, dirección, total utilizado y entradas completas se actualizan conforme a sus condiciones aprobadas. Los dos controles de pendientes físicos pueden coincidir y se compensan; producción completa se activa en los tres cierres aprobados.

Se aprueban las condiciones de `wr_uart` y selección `w_data`, ocupación y finalización física de la tabla. Reset suprime órdenes, escritura y finalización y tiene prioridad en los recursos. Inicializaciones preceden a actualizaciones del mismo recurso, con condiciones que evitan coincidencias incompatibles; sin orden, se retiene el valor.

La FSM calcula estado siguiente y emite controles con casez y `?`. El cálculo y registro de incrementos o capturas pertenece a la lógica diferenciada del recurso. Estado actual registrado y separación funcional dentro del módulo, sin exigir otro ciclo ni un módulo por recurso. Preparar y encolar en flancos distintos conserva la decisión específica del próximo byte.

**Justificación:** La tabla concreta las transiciones aprobadas mediante habilitaciones explícitas y mantiene el criterio docente de separación entre control y acciones. Los recursos conservan valores durante espera y avanzan por aceptación efectiva.

**Consecuencias y alcance pendiente:** Quedan aprobados nombres y generación funcional de las señales de acción del serializador. Permanecen pendientes la adaptación física del código de estado global, recursos y coordinación concreta de `protocol_controller`, demás fronteras del sistema y demostración de latencia RX/`LOAD`. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba la propuesta de señales preparada para revisión después de la codificación one-hot. No cierra DEC-SYS-007 ni autoriza comenzar RTL.

### Acuerdo parcial de DEC-SYS-007 — Registro de respuesta pendiente en el controlador

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Control del protocolo / Descripción de respuesta pendiente de entrega.

**Fecha de aprobación:** 2026-10-03.

**Contexto:** `RUN` puede terminar mientras una respuesta breve se transmite. `protocol_controller` necesita conservar un descriptor pendiente sin sobrescribir la respuesta activa.

**Decisión:** `protocol_controller` conserva `pending_response_opcode` de ocho bits, `pending_response_result` de ocho y `pending_response_with_debug` de uno, formando un descriptor de 17 bits, más `pending_response_valid` de uno. Al guardar la descripción se activa disponibilidad y los campos se mantienen hasta entregarlos al serializador libre.

Cuando atiende este pendiente, el controlador presenta los campos con `response_start` y `response_busy` en cero, fuera de `reset`. En el flanco de aceptación el serializador captura su descriptor y el controlador desactiva `pending_response_valid`. El espacio se libera por entrega, sin esperar el fin físico de la nueva respuesta. Durante espera no se sobrescribe la descripción pendiente. Reset deja disponibilidad inactiva y suprime solicitudes.

Los valores del cuerpo Debug continúan retenidos en los recursos CPU. La exclusión comienza en el instante observado y cubre espera y transmisión hasta el último Stop. Se conservan el orden de respuestas y `ACCEPTED` antes del terminal de `RUN`.

**Justificación:** El espacio recuerda qué respuesta debe solicitarse mientras el serializador atiende otra. Su descriptor es independiente del ya capturado por el serializador y permite conservar una descripción pendiente durante la transmisión previa.

**Consecuencias y alcance pendiente:** El [registro pendiente y entrega](../architecture/debug/protocol_controller.md#registro-de-respuesta-pendiente) queda definido. Permanecen pendientes uso de un camino común para todas las respuestas, prioridades de eventos, órdenes de carga/consumo, restantes recursos y FSM del controlador, demás fronteras y presupuesto de consumo RX/`LOAD`. No se acredita implementación ni verificación RTL.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el recurso de respuesta pendiente del controlador después del diseño de señales del serializador. No cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Recorrido común y conservación del terminal de RUN

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Controlador / Coordinación de respuestas.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** Debe comprobarse que un descriptor pendiente y la obligación terminal `RUN` bastan para preservar respuestas bajo las prioridades del protocolo.

**Decisión:** Todas las respuestas pasan por el descriptor pendiente aprobado, incluso con el serializador libre. Captura y entrega ocupan flancos sucesivos; un descriptor ocupado no se sobrescribe ni se reemplaza en el flanco de entrega. El serializador conserva independientemente la respuesta aceptada.

El controlador recuerda que un `RUN` aceptado debe producir su terminal. Si la CPU termina cuando el espacio está ocupado, conserva esa obligación y el estado terminal, entrega primero el descriptor previo y forma después `RUN` terminal. `ACCEPTED` conserva precedencia; cada `RUN` produce un único terminal. La exclusión Debug abarca desde el instante observado hasta el último Stop, incluida esa espera.

**Justificación:** Una respuesta breve puede ocupar el espacio en el flanco del último ciclo de `RUN`. Conservar la obligación y el estado terminal permite resolverlo sin un segundo descriptor completo.

**Consecuencias y alcance pendiente:** Queda aprobado el [recorrido común](../architecture/debug/protocol_controller.md#un-espacio-y-recorrido-común). Se revisan conjuntamente representación de la obligación, restantes recursos, prioridades, FSM y puertos. Se conservan transporte y `reset` aprobados; no se acredita RTL ni se cierra DEC-SYS-007.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa el uso del descriptor pendiente aprobado el 2026-10-03.

### Acuerdo parcial de DEC-SYS-007 — Estados y recursos del recorrido LOAD

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / Recorrido `LOAD` dentro de su FSM.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** `LOAD` comparte una única FSM `protocol_controller` con los demás comandos. La FSM privada del serializador conserva su organización one-hot independiente.

**Decisión:** Se aprueban `IDLE` compartido y `READ_SIZE`, `CHECK_SIZE`, `WAIT_LOAD_ACCEPT`, `LOAD_DATA`, `WAIT_LOAD_RESULT`, `WAIT_LOAD_PREP` y `WAIT_LOAD_DONE`, con funciones y avance definidos en el [recorrido LOAD aprobado](../architecture/debug/protocol_controller.md#recorrido-load-aprobado).

`LOAD` sigue esta secuencia:

1. Recibe el tamaño, valida y consulta disponibilidad, solicita `ACCEPTED` y espera su envío físico.
2. Entrega el contenido al Loader.
3. Espera confirmación de escritura y preparación inicial.
4. Solicita `DONE` y vuelve a `IDLE` después de su envío físico. Un rechazo solicita el resultado previsto por el protocolo. `LOAD` no inicia ejecución: la CPU queda preparada para `RUN` o `STEP`.

Se aprueban registro del tamaño original, índice para sus cinco bytes, contador de bytes faltantes y contador de tiempo para detectar recepción interrumpida. Los faltantes se inicializan con el tamaño y disminuyen por byte entregado al Loader, conservando el tamaño original. FSM y recursos mantienen la separación de decisiones y actualizaciones previamente acordada.

**Justificación:** Los estados identifican qué está haciendo el controlador y qué confirmación espera para continuar. Los recursos conservan tamaño, posición, progreso y plazo. Loader conserva ensamblado y escritura; serializador conserva envío.

**Consecuencias y alcance pendiente:** Aprobación parcial del recorrido `LOAD`, sin aprobar por extensión los otros comandos ni la propuesta completa de dieciséis estados. No se aprueban todavía anchos/codificación nuevos, puertos, controles concretos, recuperación y nuevas prioridades entre comandos, incluida cabecera `LOAD` interrumpida por terminal `RUN`. La coincidencia de última entrega y confirmación Loader se concreta en integración. Se continúa con `RUN`, manteniendo explicaciones breves y decisiones agrupadas por recorrido. No se acredita RTL ni se cierra DEC-SYS-007.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba la parte funcional de `LOAD` dentro de la propuesta conjunta del controlador. No modifica el protocolo vigente.

### Acuerdo parcial de DEC-SYS-007 — Estados y marcas del recorrido RUN

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / Recorrido `RUN` dentro de su FSM.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** `RUN` requiere condiciones y destinos de cada estado dentro de la FSM común, incluida conservación del terminal mientras se completa `ACCEPTED`.

**Decisión:** Se aprueban funciones y transiciones de `EXEC_RUN`, `WAIT_RUN_ACCEPT` y uso compartido de `IDLE` y `WAIT_DEBUG`, según el [recorrido RUN aprobado](../architecture/debug/protocol_controller.md#recorrido-run-aprobado). Aceptar `RUN` solicita `ACCEPTED`; rechazar solicita respuesta breve y utiliza `WAIT_BRIEF`. Al terminar físicamente `ACCEPTED` se pasa a `IDLE` si la ejecución continúa o a `WAIT_DEBUG` si ya terminó. Desde `IDLE`, terminal `RUN` debido lleva a `WAIT_DEBUG`; otros comandos permitidos siguen su recorrido. El fin físico de resultado terminal y Debug vuelve a `IDLE`. Sin condición de avance se conserva estado.

Se aprueban las marcas funcionales «`RUN` debe una respuesta final» y «estado retenido para Debug», representadas en el diseño por `run_terminal_owed` y `debug_hold`. La primera se conserva desde aceptación hasta guardar la respuesta terminal; la segunda hasta el último Stop de Debug. Esperar `ACCEPTED` no pausa ejecución CPU. Si `RUN` termina antes, se recuerda el terminal y se retiene el estado; `ACCEPTED` se completa primero.

**Justificación:** Se distingue la fase UART del progreso CPU, manteniendo una aceptación completa y una única respuesta terminal con observación coherente. Las dos marcas conservan obligación y retención aunque sus tiempos de consumo difieran.

**Consecuencias y alcance pendiente:** Aprobación funcional parcial de `LOAD` y `RUN`. Quedan pendientes `STEP` y otros comandos, coordinación común, cancelación por `RESET`, prioridad durante cabecera `LOAD` no aceptada, codificación/anchos nuevos, puertos y controles. El uso de `WAIT_BRIEF` para rechazo no cierra todas sus prioridades. No se acredita RTL ni se cierra DEC-SYS-007. Sigue `STEP`, presentando función, condición de avance y destino de cada estado.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba la parte funcional `RUN` dentro de la propuesta conjunta; conserva el protocolo vigente.

### Acuerdo parcial de DEC-SYS-007 — Estados y retención del recorrido STEP

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / Recorrido `STEP` dentro de su FSM.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** `STEP` requiere avance inmediato o preparación previa, condiciones de transición y reutilización de la retención Debug.

**Decisión:** Se aprueban `EXEC_STEP`, `WAIT_STEP_PREP` y uso compartido de `WAIT_DEBUG`, con entrada desde `IDLE`, según el [recorrido STEP aprobado](../architecture/debug/protocol_controller.md#recorrido-step-aprobado). Aceptación con ciclo realizado lleva a `WAIT_DEBUG`; aceptación que requiere nueva sesión lleva a `WAIT_STEP_PREP`; rechazo utiliza `WAIT_BRIEF`. Preparación terminada y único ciclo realizado llevan de `WAIT_STEP_PREP` a `WAIT_DEBUG`. El fin físico de `DONE` con todo Debug vuelve a `IDLE`.

La preparación previa aplica desde una sesión terminada normalmente o por fault. `STEP` realiza exactamente un ciclo CPU y observa su estado posterior. Se reutiliza `debug_hold`: se activa al realizar ese ciclo y se limpia después del último Stop de `DONE` con Debug. La FSM global conserva preparación/ejecución y el serializador conserva transmisión.

**Justificación:** Se distingue el `STEP` inmediato del que necesita preparar una nueva sesión, manteniendo un único ciclo observado y una retención compartida con `RUN` durante espera y envío Debug.

**Consecuencias y alcance pendiente:** Aprobación funcional de `LOAD`, `RUN` y `STEP`. Siguen `RESET`, `CHECK_READY`, recuperación, coordinación común y detalles de anchos/codificación, puertos y señales. El uso de `WAIT_BRIEF` no cierra todas sus prioridades. No se acredita RTL ni se cierra DEC-SYS-007. Sigue `RESET` con explicaciones breves y tabla de función/condición/destino.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba la parte funcional `STEP` y retención compartida de la propuesta conjunta; conserva el protocolo vigente.

### Acuerdo parcial de DEC-SYS-007 — Recorrido RESET y cancelación del terminal RUN

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / `RESET` UART dentro de su FSM.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** `RESET` UART debe coordinar aceptación física, solicitud global y cancelación de la obligación terminal `RUN`, con condiciones y destinos explícitos.

**Decisión:** Desde `IDLE`, reconocer `RESET` solicita `ACCEPTED` y lleva a `WAIT_RESET_ACCEPT`. Este espera el envío físico completo; el último Stop activa la solicitud de `reset` global. El `reset` devuelve el controlador a `IDLE` y la CPU a `NO_IMAGE`. Se aprueba la marca funcional «solicitar `reset`», activada únicamente después de transmitir `ACCEPTED` completo, según el [recorrido RESET aprobado](../architecture/debug/protocol_controller.md#recorrido-reset-aprobado).

Al reconocer `RESET` se cancela la obligación de enviar el terminal de un `RUN` pendiente. La CPU puede continuar mientras se transmite `ACCEPTED`; no se pausa anticipadamente y el `reset` efectivo ocurre después. Esto conserva el abandono del `RUN` anterior y la secuencia externa del protocolo.

**Justificación:** Completar la aceptación antes de `reset` impide que el propio `reset` interrumpa su confirmación. Cancelar la obligación terminal coordina el abandono de `RUN` con el `reset` solicitado.

**Consecuencias y alcance pendiente:** Están aprobadas las partes funcionales `LOAD`, `RUN`, `STEP` y `RESET`. Siguen `CHECK_READY`, recuperación, otras prioridades comunes y detalles físicos. La representación registrada de la solicitud y su conexión al `reset` global permanecen propuestas para integración/señales. Se conservan descarte de `RESET` UART durante Debug/recuperación y `reset` físico directo ya aprobados. No se acredita RTL ni se cierra DEC-SYS-007.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba la parte funcional `RESET` y concreta la cancelación terminal de `RUN`; conserva el protocolo vigente.

### Acuerdo parcial de DEC-SYS-007 — Recorrido CHECK_READY con estados compartidos

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / `CHECK_READY` dentro de su FSM.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** `CHECK_READY` utiliza estados compartidos y descriptor pendiente, con condiciones y destinos de avance sin nuevos recursos específicos.

**Decisión:** Desde `IDLE`, recibir `CHECK_READY` solicita `READY` o `BUSY` según disponibilidad actual para `LOAD` y lleva a `WAIT_BRIEF`. Este espera el último Stop de la respuesta breve y vuelve a `IDLE`; si `RUN` terminó mientras esperaba, pasa a `WAIT_DEBUG` para atender su terminal, después de completar la respuesta breve. Funciones y avance en el [recorrido CHECK_READY aprobado](../architecture/debug/protocol_controller.md#recorrido-check_ready-aprobado).

Se reutiliza el espacio pendiente y no se agrega un recurso específico del comando. `CHECK_READY` no modifica ni pausa CPU; `READY` indica disponibilidad para `LOAD`, independientemente de imagen cargada. Se conservan ausencia de reserva y validación independiente de cada `LOAD`.

**Justificación:** La consulta utiliza recepción y espera de respuestas breves existentes, manteniendo orden entre consulta y terminal `RUN` y ejecución CPU independiente de TX.

**Consecuencias y alcance pendiente:** Quedan aprobados los recorridos funcionales de `LOAD`, `RUN`, `STEP`, `RESET` y `CHECK_READY`. Siguen recuperación, coordinación común y prioridades restantes, anchos/codificación, controles, puertos e integración. El descarte durante Debug/recuperación conserva el protocolo vigente. No se acredita RTL ni se cierra DEC-SYS-007. Sigue `RECOVER` con entrada, permanencia y salida explicadas.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba `CHECK_READY` y uso compartido de `WAIT_BRIEF`; conserva el protocolo vigente.

### Acuerdo parcial de DEC-SYS-007 — Estado RECOVER y contador de tiempo compartido

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / Recuperación RX.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** `RECOVER` requiere entrada, permanencia y salida explícitas y reutiliza el temporizador `LOAD`. R=100 ms ya estaba fijado y no se redefine.

**Decisión:** Error UART al interpretar comando o recibir `LOAD`, o vencimiento T durante recepción `LOAD`, abandona recepción y lleva a `RECOVER`; `LOAD` solicita el error previsto. `RECOVER` descarta RX y toda actividad reinicia el contador de silencio. Se vuelve a `IDLE` después de R continuo, con RX vacía, sin byte en recepción y respuestas pendientes completas, incluido Debug si correspondía. Funciones y avance en la [recuperación aprobada](../architecture/debug/protocol_controller.md#recuperación-rx-aprobada).

Se reutiliza el contador de tiempo de `LOAD` porque las fases temporizadas son excluyentes. TX continúa y `RUN` puede continuar; no se guardan comandos recibidos durante descarte ni se aplica `reset` global para recuperar. Se mantienen resultados y efectos de errores `LOAD` y ausencia de respuesta para `opcode` corrupto ya fijados por protocolo.

**Justificación:** Descartar y exigir una frontera de silencio permite reconocer nuevos comandos sin confundir restos del mensaje interrumpido. Reutilizar el temporizador conserva un único recurso para fases excluyentes.

**Consecuencias y alcance pendiente:** Se completan funcionalmente recorridos de los cinco comandos y recuperación. Siguen coordinación común de respuestas, prioridades restantes, anchos/codificación, puertos, señales e integración. La clase de respuesta activa no queda aprobada por extensión. No se acredita RTL ni se cierra DEC-SYS-007.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba `RECOVER` y temporizador compartido de la propuesta conjunta; conserva el protocolo vigente.

### Acuerdo parcial de DEC-SYS-007 — Finalización derivada del estado y marcas existentes

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / Coordinación de finalización de respuestas.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** Las clases de respuesta deben distinguirse desde estado y recursos existentes, incluido Debug durante `RECOVER`, para evitar almacenamiento redundante.

**Decisión:** Se deriva la acción de finalización desde el estado controlador y marcas ya aprobadas, según la [coordinación aprobada](../architecture/debug/protocol_controller.md#coordinación-derivada-del-estado-y-marcas-existentes).

| Estado de espera               | Acción al finalizar                  |
|--------------------------------|--------------------------------------|
| `WAIT_LOAD_ACCEPT`             | Inicia recepción                     |
| `WAIT_LOAD_DONE`               | Vuelve a `IDLE`                      |
| `WAIT_RESET_ACCEPT`            | Solicita `reset`                     |
| `WAIT_RUN_ACCEPT`/`WAIT_BRIEF` | Vuelven a `IDLE` o atienden terminal |
| `WAIT_DEBUG`                   | Libera retención y vuelve a `IDLE`   |

`RECOVER` limpia retención si terminó Debug y conserva recuperación hasta sus condiciones de salida.

La condición combinacional `debug_done` utiliza `response_done_tick`, `debug_hold` activa, `run_terminal_owed` inactiva y `pending_response_valid` inactiva, con valores previos al flanco. No agrega registro, estado ni puerto. Se descartan `active_response_kind`/`active_kind_load` y la posterior propuesta de salida `response_debug_active` del serializador.

**Justificación:** El estado identifica las finalizaciones ordinarias. En `RECOVER`, mientras una respuesta breve previa termina, la obligación `RUN` sigue activa o el descriptor Debug permanece pendiente; eso impide confundir su fin con Debug. Durante envío Debug, obligación consumida, pendiente libre y retención activa permiten reconocerlo. El acuerdo depende de entrega exclusiva, no sobrescritura y descarte durante Debug ya aprobados.

**Comprobación:** Modelo abstracto de coordinación con 34 estados alcanzables y 117 transiciones, incluidos terminales coincidentes, `STEP`, respuestas breves, errores, recuperación y `reset`. Se verificó la invariante bajo los contratos del modelo; no acredita RTL ni temporización UART.

**Consecuencias y alcance pendiente:** Se completa funcionalmente la finalización sin duplicar clase de respuesta. Quedan prioridades restantes, anchos/codificación, puertos, señales, integración y presupuesto RX/`LOAD`. DEC-SYS-007 continúa abierto; no se autoriza implementación.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Sustituye ambas propuestas no aprobadas de registro de clases y salida Debug activa por derivación desde recursos existentes.

### Acuerdo parcial de DEC-SYS-007 — Prioridad del terminal RUN sobre cabecera LOAD sin resolver

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Controlador / Prioridad entre terminal `RUN` y recepción de cabecera `LOAD`.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** Un terminal `RUN` puede coincidir con una cabecera `LOAD` todavía sin resolver. Debe establecerse prioridad conservando la respuesta breve ya formada.

**Decisión:** Si `RUN` termina mientras se recibe o valida la cabecera `LOAD` sin resolver, se prioriza su terminal: retener estado CPU, enviar resultado terminal con Debug, abandonar cabecera y descartar bytes restantes. `LOAD` no se guarda para después ni modifica imagen; tampoco produce respuesta o `INCOMPLETE_REQUEST` posterior. Al terminar Debug se vuelve a admitir transporte según fase.

Una respuesta breve ya preparada para `LOAD` se conserva y completa primero, conforme al orden aprobado; la prioridad interrumpe cabecera aún sin resolver, no cancela respuestas ya determinadas. Regla en el [protocolo](../protocol.md#terminal-run-durante-cabecera-load) y en el [controlador](../architecture/debug/protocol_controller.md#terminal-run-y-exclusión-debug).

**Justificación:** Concreta el cruce entre recepción completa de cabecera y descarte/exclusión desde el instante observado, sin permitir que una solicitud no aceptada retrase o modifique esa observación.

**Consecuencias y alcance pendiente:** Se actualiza protocolo y coordinación, sin estado ni recurso nuevo. Siguen anchos/codificación, puertos, controles, integración y presupuesto RX/`LOAD`. No se acredita RTL ni se cierra DEC-SYS-007.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba la precisión propuesta de terminal `RUN` durante cabecera `LOAD` y matiza la regla general de recibir seis bytes antes de rechazo mientras no haya exclusión terminal.

### Acuerdo parcial de DEC-SYS-007 — Codificación y anchos del controlador

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / Representación de estados y recursos existentes.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** Los recorridos aprobados requieren codificación one-hot y anchos derivados de formatos/rangos, sin añadir recursos funcionales.

**Decisión:** FSM `protocol_state` one-hot de dieciséis bits, con `IDLE` en bit cero y demás estados en el orden de la tabla aprobada. Reset deja solo `IDLE` activo. Se mantienen estado registrado y decisiones/acciones combinacionales casez y `?`.

`load_size_received` utiliza cuarenta bits por cinco bytes UART; `size_byte_index`, tres para cero a cuatro; `load_bytes_remaining`, `IMAGE_SIZE_WIDTH` = max(1, ceil(log2(C + 1))) para cero a capacidad IMEM inclusive, once bits `REFERENCE` y diez `ALT_1000`. `inactivity_count` utiliza veintitrés bits para los 5.000.000 clocks de T/R, con cuenta/saturación/reinicios según fase. `run_terminal_owed`, `debug_hold` y `uart_reset_request` utilizan un bit cada uno. Descriptor pendiente conserva dieciocho bits previamente aprobados. Tabla y explicación en [codificación y dimensionamiento](../architecture/debug/protocol_controller.md#codificación-y-dimensionamiento-aprobados).

**Justificación:** One-hot mantiene el criterio UART/serializador. Anchos de datos y contadores representan los formatos y rangos aprobados; tamaño completo se valida antes de reducir ancho. No se incorpora registro de clases, puerto Debug activo ni otro estado.

**Comprobación:** Dieciséis estados distintos, índices consecutivos y `IDLE` en cero; anchos mínimos de índice, faltantes y temporizador; suma de recursos listados de 114 bits `REFERENCE` y 113 `ALT_1000`. Comprobación aritmética/documental, sin síntesis ni RTL.

**Consecuencias y alcance pendiente:** Estados, recursos, representación, coordinación derivada y prioridad terminal están aprobados. Se concretan señales/puertos y después integración de servicios y presupuesto RX/`LOAD`. DEC-SYS-007 continúa abierto y no se autoriza implementación.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la representación pendiente de los recursos y dieciséis estados del controlador.

### Acuerdo parcial de DEC-SYS-007 — Señales y conexiones del controlador

> **Interfaces revisadas por la [conexión con Execution Control](#revisión-de-dec-sys-007--interfaz-del-protocolo-con-execution-control) (2026-10-16).** Se concretan solicitudes directas, aceptación común e indicadores de sesión sobre los recorridos de transporte aprobados.

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `protocol_controller` / Fronteras y acciones sobre recursos existentes.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** La integración del controlador necesita datos, controles, productores, consumidores y momento de uso explícitos para UART, CPU y servicios.

**Decisión:** Aprobar las [señales y conexiones funcionales](../architecture/debug/protocol_controller.md#señales-y-conexiones-aprobadas) y su [tabla de puertos](../architecture/debug/protocol_controller.md#puertos-del-controlador-aprobados), con estas relaciones:

- Consumo RX independiente de espera TX.
- Entrega válida/última/aborto hacia Loader con confirmación de escritura final.
- Solicitudes y aceptación `LOAD`/`RUN`/`STEP`.
- Observación de ciclo `STEP` y fin de preparación.
- Descriptor al serializador libre y ocupación/finalización física.
- Misma exclusión para selección RF/DMEM. UART `RESET` registra `uart_reset_request` al último Stop de `ACCEPTED` y aplica `reset` global en el siguiente flanco funcional. Órdenes internas habilitan actualizaciones de los recursos existentes según estado, con lógica de recurso diferenciada.

**Justificación:** Concreta los recorridos y recursos aprobados. La frontera registrada de `reset` evita la realimentación combinacional desde finalización TX hacia su propio `reset`; no pausa anticipadamente la CPU ni agrega recursos a los ya dimensionados.

**Consecuencias y alcance pendiente:** Se completan conexiones funcionales del controlador. Falta concretar servicios Loader/preparación/`reset`/adaptación global/memoria y demostrar consumo RX/`LOAD`. No se acredita RTL ni se autoriza implementación. La capacidad de aceptar cada byte del Loader sigue siendo obligación de diseño, no comprobación ya realizada.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aprueba el bloque agrupado de señales/conexiones y la secuencia registrada de `reset` UART. Las extensiones propuestas posteriormente requieren revisión independiente.

### Acuerdo parcial de DEC-SYS-007 — Realización del Loader

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Loader / Reconstrucción de instrucciones e integración IMEM.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** Loader debe reconstruir cada palabra guardando tres bytes y escribir con el cuarto, reutilizando tamaño y progreso del controlador.

**Decisión:** Adoptar el [diseño del Loader](../architecture/session/loader.md). `byte_offset` se deriva combinacionalmente del tamaño original menos faltantes antes de cada entrega. El controlador agrega `load_byte_offset` hacia Loader, con `BYTE_ADDRESS_WIDTH`; Loader deriva `lane` y `word_index`. Reutiliza tamaño original retenido hasta commit, sin registro duplicado. `partial_word` de 24 bits conserva los tres primeros bytes y el cuarto byte actual completa la palabra little-endian para escritura síncrona en ese mismo flanco. El último cuarto byte produce `load_ok` junto con su escritura; controlador avanza directamente a `WAIT_LOAD_PREP` y FSM global a `PREPARING_READY`. Loader usa ownership `LOADING` sin FSM ni contadores privados adicionales. Aborto/`reset` suprimen escritura; no hay publicación prematura de imagen.

**Justificación:** El progreso y tamaño ya existen en el controlador. La palabra completa puede formarse antes del flanco con el byte actual; no necesita guardar un cuarto byte ni agregar fase de escritura. El estado global identifica la fase de carga.

**Comprobación:** Modelo abstracto de todos los 506 tamaños legales de `REFERENCE`/`ALT_1000`; 257.084 entregas y 64.271 palabras, con posición, índices, little-endian, sustitución de residuos y última entrega correctos. No acredita RTL, síntesis, timing ni el presupuesto conjunto UART/preparación.

**Consecuencias y alcance pendiente:** Se concreta Loader y su extensión de conexión. Siguen preparación, mantenimiento, `reset`/adaptador global y comprobación de presupuesto RX/`LOAD`. No se autoriza implementación ni se cierra DEC-SYS-007.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la frontera Loader/IMEM y agrega expresamente la conexión de posición al controlador; conserva `LOAD` y publicación tras preparación.

### Acuerdo parcial de DEC-SYS-007 — Preparación de sesión y mantenimiento

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** `Session Preparation` / RF y metadatos DMEM.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** La preparación debe aprovechar inicialización simultánea RF con flip-flops y limpiar marcas DMEM secuencialmente. Esta realización sustituye el recorrido RF por su puerto de escritura y permite 40,98 µs en `REFERENCE`.

**Decisión:** Adoptar la [preparación de sesión](../architecture/session/session_preparation.md). Primer flanco inicializa PC/`cycle_count`, invalida pipeline/`fetch_fault_valid` y pone RF completo en cero mediante inicialización local. RF x1–x31 se realiza con flip-flops y x0 como constante cero; no se agrega selección de escritura de mantenimiento. Un índice `prepare_index` recorre todas las marcas DMEM, limpiando una por clock. El bitmap `valid` por byte se comparte con memoria utilizada para Debug, sin borrar datos ni duplicar metadatos. El índice representa capacidad inclusive: doce bits `REFERENCE` y diez `ALT_1000`; dirección de limpieza once/diez. `prepare_done` se deriva al alcanzar capacidad después de la última limpieza; ese flanco no realiza mantenimiento. `PREPARING_READY` publica imagen sin ciclo; `PREPARING_RUN`/`STEP` autorizan el primer ciclo con estado ya limpio. No se agrega FSM ni registro de modo/finalización.

**Justificación:** Reutiliza el requisito de inicialización RF simultánea, elimina dirección/dato de escritura RF para limpieza y conserva flexibilidad del bitmap DMEM sin clear global de una RAM. Cumple el presupuesto de hasta 1 ms sin espera fija posterior.

**Comprobación:** Modelo abstracto de la variante vigente para DMEM de 4, 28, 32, 36, 1000 y 2048 bytes: RF inicializada una vez, cada marca limpiada una vez, anchos y fin sin mantenimiento concurrente. `REFERENCE` necesita 2049 clocks / 40,98 µs a 50 MHz; `ALT_1000`, 1001 / 20,02 µs. No acredita RTL, área ni timing físico.

**Consecuencias y alcance pendiente:** Se concretan preparación y mantenimiento RF/DMEM. Siguen acondicionamiento de `reset`, representación física del estado global, revisión final de conexiones y comprobación conjunta RX/`LOAD`. No se autoriza implementación ni se cierra DEC-SYS-007.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Sustituye la propuesta no aprobada de recorrer RF por el puerto WB; conserva los estados PREPARING y contratos de sesión existentes.

### Acuerdo parcial de DEC-SYS-007 — Acondicionamiento del reset global

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** Integración / Fuentes y distribución del `reset` funcional.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** Botón y solicitud UART deben utilizar el acondicionador `reset_sync` TP2 común, conservando sus condiciones de aserción y liberación.

**Decisión:** Adoptar la [integración del reset global](../architecture/platform/reset_integration.md). Botón normalizado, `uart_reset_request` registrado y falta de estabilidad de clock (!`locked` si existe) se combinan antes del único `reset_sync` del TP2. Se conservan dos etapas, aserción asíncrona y liberación sincronizada; todos los consumidores funcionales reciben su salida y consumen `reset` al flanco. `RESET` UART registra petición al completar el último Stop de `ACCEPTED` y aplica `reset` en el siguiente flanco funcional; limpia petición mediante ese `reset`. Liberación ocurre después de retirar todas las fuentes y atravesar las dos etapas. Preparación local conserva su señal y no reinicia UART ni FSM global.

**Justificación:** Reutiliza el circuito TP2 y el registro de solicitud existente. Conserva prioridad de botón, regla de aceptación completa y acondicionamiento común, sin agregar `reset` por módulo ni lazo combinacional de finalización.

**Comprobación:** Lectura de `reset_sync.sv` y modelo abstracto del registro UART/dos etapas: petición en E, `reset` funcional E+1/E+2/E+3 y primer flanco libre E+4 sin otras fuentes. Mantenimiento por fuente física y liberación sincronizada comprobados en el modelo; no simulación RTL TP3 ni timing/metastabilidad medidos.

**Consecuencias y alcance pendiente:** Se concreta acondicionamiento común. Siguen representación física global/Debug, revisión final de conexiones y comprobación RX/`LOAD`. No se autoriza implementación ni se cierra DEC-SYS-007.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta integración de fuentes sobre contratos de `reset` existentes; conserva semántica funcional y estados CPU/protocolo.

### Acuerdo parcial de DEC-SYS-007 — Representación física del estado global

> **Distribución revisada por la [conexión con Execution Control](#revisión-de-dec-sys-007--interfaz-del-protocolo-con-execution-control) (2026-10-16).** El código de ocho bits llega al serializador; el controlador utiliza los indicadores de sesión. Se conservan la representación one-hot y los códigos externos.

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente hasta revisión de conexiones y presupuesto.

**Dominio:** `Global FSM` / Estado registrado y observación controlador/Debug.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** El estado CPU requiere almacenamiento one-hot y conversión combinacional al código UART aprobado, sin duplicar estado.

**Decisión:** Adoptar la [representación física global](../architecture/session/global_state_encoding.md): `global_state` de catorce bits one-hot, bits cero a trece en el orden de códigos UART; `reset` activa solo `NO_IMAGE` en bit cero. La lógica Moore global genera `global_state_code` de ocho bits combinacionalmente. Controlador y serializador consumen la misma conexión, este último como `debug_state_code`; no se duplica estado ni se registra el código. `loader_active`, `prepare_active`, `program_finished` y `fault_info_valid` se derivan del estado actual. Se conservan transiciones, autorizaciones y exclusión Debug postciclo.

**Justificación:** Mantiene el criterio one-hot aprobado en las otras FSM y conecta el estado registrado con la representación externa existente, sin una etapa adicional de captura. No declara un óptimo de área/frecuencia frente a codificación binaria sin síntesis.

**Comprobación:** Catorce bits consecutivos/unívocos, `reset` `NO_IMAGE`, códigos `protocol.md` y cuatro predicados comprobados para todos los estados legales; no RTL/síntesis/timing.

**Consecuencias y alcance pendiente:** Se concreta adaptación global. Siguen revisión de conexiones y presupuesto RX/`LOAD` antes de cerrar DEC-SYS-007. No se autoriza implementación.

**Requisitos relacionados:** `REQ-UART-005`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta representación física previamente pendiente; conserva FSM y códigos externos acordados.

### Revisión de DEC-SYS-007 — Interfaz del protocolo con Execution Control

**Estado:** Aprobada.

**Fecha:** 2026-10-16.

**Contexto:** El [acuerdo 48 de DEC-ARCH-003](DEC-ARCH-003.md#acuerdo-48-aprobado--integración-del-control-global-de-ejecución) integra la selección de comandos y la autorización en `Global FSM`. Se revisan las conexiones del controlador con CPU y servicios, y la distribución del código de estado.

**Decisión:** `Protocol Controller` conserva la fase del intercambio UART y solicita operaciones a `Execution Control`. Las conexiones se concretan en [Protocol Controller](../architecture/debug/protocol_controller.md#puertos-del-controlador-aprobados), [Composición](../architecture/system_composition.md#processor_top-comandos-carga-y-consultas) e [Interfaces](../interfaces.md#bloque-8-1):

| Conexión                                      | Señales                                            | Uso                                                                                         |
|-----------------------------------------------|----------------------------------------------------|---------------------------------------------------------------------------------------------|
| `Protocol Controller` → `Execution Control`   | `load_request`, `run_request`, `step_request`      | Solicitudes en `CHECK_SIZE`, `EXEC_RUN` y `EXEC_STEP`, respectivamente.                     |
| `Execution Control` → `Protocol Controller`   | `command_accepted`                                 | Aceptación de la solicitud presentada.                                                      |
| `Execution Control` → `Protocol Controller`   | `load_available`                                   | Responder `CHECK_READY` con `READY` si vale uno o `BUSY` si vale cero.                      |
| `Execution Control` → `Protocol Controller`   | `prepare_active`                                   | Admitir comandos con preparación inactiva, sujeto a disponibilidad local de transporte.     |
| `Execution Control` → `Protocol Controller`   | `program_finished`, `fault_terminal`               | Detectar y clasificar el terminal de un `RUN` debido, con pipeline vacío.                   |
| `Execution Control` → `Protocol Controller`   | `cpu_cycle_fire`                                   | Identificar el ciclo efectivo de `STEP`.                                                    |
| `Execution Control` → `Protocol Controller`   | `image_valid`                                      | Clasificar el rechazo de `RUN`/`STEP` como `NO_IMAGE` o `BUSY`.                             |
| `Session Preparation` → `Protocol Controller` | `prepare_done`                                     | Completar la espera de preparación de `LOAD`; con `cpu_cycle_fire`, completar la de `STEP`. |
| `Execution Control` → `Response Serializer`   | `global_state_code[7:0]` → `debug_state_code[7:0]` | Producir el byte de estado del contexto Debug.                                              |

Las solicitudes y los indicadores de control son de un bit. El controlador presenta una sola solicitud por ciclo, generada según su fase y las condiciones de transporte, independientemente de la aceptación. Ambas FSM consumen solicitud y `command_accepted` en el mismo flanco. Con solicitud activa, cero indica rechazo; sin solicitud, cero no constituye un evento.

**Consumo de la aceptación común:**

| Fase UART    | Condición                                             | Acción                                                  |
|--------------|-------------------------------------------------------|---------------------------------------------------------|
| `CHECK_SIZE` | `load_request && command_accepted`                    | Capturar faltantes y guardar `LOAD`/`ACCEPTED`.         |
| `EXEC_RUN`   | `run_request && command_accepted`                     | Activar `run_terminal_owed` y guardar `RUN`/`ACCEPTED`. |
| `EXEC_STEP`  | `step_request && command_accepted && cpu_cycle_fire`  | Activar retención y guardar `STEP`/`DONE` con Debug.    |
| `EXEC_STEP`  | `step_request && command_accepted && !cpu_cycle_fire` | Pasar a `WAIT_STEP_PREP`.                               |

`load_request` se presenta después de validar los cuarenta bits de tamaño. Ante rechazo de `RUN`/`STEP`, `image_valid=0` selecciona `NO_IMAGE` e `image_valid=1` selecciona `BUSY`. `load_available` expresa disponibilidad de sesión para `LOAD`; la consulta conserva las condiciones locales de admisión y la validación posterior de la carga.

**Terminal y observación:** `terminal_due = run_terminal_owed && (program_finished || fault_terminal)`. `program_finished` selecciona el resultado `FINISHED` y `fault_terminal` selecciona `FAULT`. Se conserva `debug_exclusive = !reset && (debug_hold || terminal_due)` para la exclusión y los selectores RF/DMEM. La exclusión comienza al observar el estado posterior al ciclo terminal, incluida la espera por una respuesta previa, y termina con el último Stop de Debug.

**Servicios de sesión:** `Global FSM` emite `load_start` hacia Loader y el registro de tamaño confirmado en el flanco de aceptación. `prepare_active` activa el mismo trabajo de `Session Preparation` en los tres estados `PREPARING_*`. Al recibir `prepare_done`, la FSM publica mediante `image_publish` desde `PREPARING_READY` o autoriza el primer ciclo desde `PREPARING_RUN`/`PREPARING_STEP`.

**Contratos conservados:** Se mantienen los dieciséis estados del controlador, los diez del serializador y sus recursos, códigos, mensajes, tiempos y prioridades. `WAIT_LOAD_ACCEPT` y `WAIT_RUN_ACCEPT` esperan el fin físico de `ACCEPTED`. El descriptor pendiente, la obligación terminal, la retención Debug, el consumo RX durante espera TX, la recuperación y el intercambio de reset conservan sus funciones.

**Comprobación:** Correspondencia documental de señales, productores, consumidores, condiciones de aceptación y predicados de terminación con las especificaciones consolidadas.

**Reemplaza / Reemplazada por:** Actualiza la aceptación de comandos, los controles de carga/preparación y la distribución funcional del estado de los acuerdos anteriores. Conserva los contratos de transporte, serialización y protocolo externo.
