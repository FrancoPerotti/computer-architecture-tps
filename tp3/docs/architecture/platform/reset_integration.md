# Integración del reset global

- **Tipo:** arquitectura. 
- **Estado documental:** especificación vigente.

<a id="estado-y-contrato-existente"></a>

## Propósito y alcance

Este documento define la integración del reset común de la FPGA: sus fuentes, el acondicionamiento mediante el único `reset_sync` y la distribución hacia los consumidores funcionales. Los registros funcionales consumen el reset de forma síncrona; solo `reset_sync` utiliza aserción asíncrona.

El alcance comprende:

- las solicitudes provenientes del botón de placa, la pérdida de estabilidad del clock y el comando `RESET` por UART;
- la combinación de esas solicitudes antes de `reset_sync`;
- la aserción asíncrona y la liberación sincronizada;
- la secuencia temporal del reset solicitado por UART;
- los efectos del reset sobre la CPU, el pipeline, las memorias, el Loader, la UART, las FIFO y el estado de la sesión;
- la separación entre el reset común y la preparación local de RF, PC, pipeline y ciclos, que conserva su propio mecanismo de inicialización.

La generación del clock y la configuración del MMCM pertenecen a [Plataforma FPGA de referencia](platform_reference.md). El comportamiento interno de cada módulo y la definición completa del protocolo UART pertenecen a sus documentos específicos. Este documento solo define cómo esos elementos interactúan con el reset común.

## Fuentes y acondicionamiento compartido

El sistema reutiliza el módulo [reset_sync del TP2](../../../../tp2/rtl/reset_sync.sv) que cuenta con dos flip-flops.

```text
async_reset_request = physical_reset_request
                      OR clock_reset_request
                      OR uart_reset_request

reset = salida de reset_sync(clk, async_reset_request)
```

Las fuentes tienen estas condiciones de activación:

| Fuente                   | Significado y conexión                                                                                                                                                                                                                                                                                               |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `physical_reset_request` | Solicitud activa en alto generada por el botón central BTNC/U18 de la Basys 3: vale `1` al pulsarlo y `0` al soltarlo, sin inversión. La plataforma también la conecta al reset del MMCM; aquí se describe su entrada al reset funcional, según [plataforma](platform_reference.md#pines-y-restricciones-aprobados). |
| `clock_reset_request`    | Solicitud activa cuando el clock no es estable: `!locked`. En la plataforma aprobada, `locked` es la salida habilitada del Clocking Wizard; si una variante no expone esa señal, esta fuente se fija en `0`.                                                                                                         |
| `uart_reset_request`     | Solicitud registrada de un bit desde `protocol_controller`, después del último Stop de `RESET/ACCEPTED`. El reset distribuido la limpia; su secuencia se define a continuación.                                                                                                                                      |

No se genera ni se supone un `locked` adicional.

Las fuentes se combinan antes del acondicionador. Solo la salida de `reset_sync` se distribuye a la CPU, la FSM global, el controlador, el Loader, la preparación, las memorias según su contrato, las FIFO, RX/TX y el generador de ticks. Ninguna fuente de reset se conecta directamente a los registros funcionales.

`reset_sync` utiliza dos flip-flops, representados por `reset_pipe[1:0]`, para mantener el reset activo durante el arranque y liberarlo de forma sincronizada:

| Condición                                                 | `reset_pipe` | Reset funcional |
|-----------------------------------------------------------|-------------:|-----------------|
| Hay una solicitud de reset activa                         |      `2'b11` | Activo          |
| Desaparecen todas las solicitudes; primer flanco de clock |      `2'b10` | Activo          |
| Segundo flanco de clock sin nuevas solicitudes            |      `2'b00` | Inactivo        |

Mientras `physical_reset_request`, `clock_reset_request` o `uart_reset_request` permanezcan activos, `reset_pipe` vuelve o permanece en `2'b11`. Cuando todas las solicitudes desaparecen, la liberación avanza con el clock desde `2'b11` hasta `2'b10` y luego hasta `2'b00`.

El reset funcional se obtiene únicamente de `reset_pipe[1]`. Por eso permanece activo durante la solicitud y también durante el primer ciclo posterior a su desaparición; solo se libera después de completar las dos etapas de sincronización. El resultado es una aserción inmediata y una liberación sincronizada.

Los dos flip-flops se marcan con `ASYNC_REG` para indicar que forman una cadena de sincronización. La inicialización en `2'b11` se conserva para que el sistema permanezca en reset durante el arranque y durante la recuperación del clock. Mientras `clock_reset_request = !locked` esté activo, la secuencia no puede avanzar hacia `2'b00`.

## Secuencia temporal de `RESET` por UART

### Reconocimiento y aceptación

El Controller reconoce el opcode `RESET` en `WAIT_COMMAND`. Durante un `RUN` lo reconoce en `WAIT_RUN_END` únicamente cuando la preparación está inactiva y todavía no se indicó un terminal. La aceptación `RUN/ACCEPTED` ya terminó físicamente antes de entrar en esa fase. Durante las aceptaciones, la preparación, Debug o recuperación RX, el byte se descarta.

Al reconocer `RESET`, el Controller presenta `RESET/ACCEPTED` al serializador libre mediante `response_start` y entra en `WAIT_RESET_ACCEPT_SENT`. También limpia `run_result_required`, la marca de resultado final `RUN` pendiente. La CPU continúa según su estado mientras se transmite la aceptación; reconocer el comando todavía no activa el reset global.

En `WAIT_RUN_END`, un terminal `RUN` ya indicado por `program_finished` o `fault_terminal` tiene prioridad sobre un nuevo `RESET`. Si esas entradas todavía están en cero y se reconoce `RESET` en el mismo flanco en que la CPU termina, se cancela el resultado final `RUN` y continúa la aceptación de `RESET`.

### Solicitud registrada y liberación

Se llama **E** al flanco en el que el Controller consume `response_done_tick`, el fin físico de la respuesta `RESET/ACCEPTED`, mientras se encuentra en `WAIT_RESET_ACCEPT_SENT`. Los tiempos `E+1`, `E+2`, etc. son los flancos siguientes del clock funcional de 50 MHz.

La tabla muestra el comportamiento con una única condición: no aparecen nuevas solicitudes de reset del botón ni del clock. Si alguna de esas fuentes permanece activa, el reset continúa afirmado y la liberación se detiene.

| Momento    | Evento o acción                                                                                                 | Estado del reset y efecto                                                                                                                                  |
| ---------- | --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Antes de E | La respuesta `ACCEPTED` todavía no terminó. `uart_reset_request = 0`.                                           | La CPU continúa según su estado actual.                                                                                                                    |
| E          | `response_done_tick` indica que se transmitió el último Stop. El controlador registra `uart_reset_request = 1`. | El acondicionador afirma el reset; la respuesta ya terminó y no se interrumpe.                                                                             |
| E+1        | El controlador consume el reset y limpia `uart_reset_request`.                                                  | Los consumidores funcionales muestrean reset activo: la CPU queda en `NO_IMAGE`, las escrituras se suprimen y los recursos se reinician según su contrato. |
| E+2        | No quedan solicitudes activas. Comienza la liberación sincronizada.                                             | `reset_pipe` avanza hacia `2'b10`, pero los consumidores todavía observan reset activo.                                                                    |
| E+3        | Continúa la liberación de la segunda etapa.                                                                     | `reset_pipe` alcanza `2'b00` después del flanco; los registros funcionales todavía consumen el valor anterior durante este flanco.                         |
| E+4        | Primer flanco posterior a la liberación completa.                                                               | Primer flanco funcional libre de reset. La CPU queda en `NO_IMAGE`, el controlador en `WAIT_COMMAND` y UART/FIFO disponibles según sus estados iniciales.  |

Los momentos E a E+4 describen los flancos del circuito; el acondicionamiento no requiere estados adicionales en la FSM del Controller. `uart_reset_request` se registra para evitar un lazo combinacional entre `response_done_tick`, el reset y la supresión del evento que termina la respuesta. El reset físico puede imponerse en cualquier momento y tiene prioridad; en ese caso, la secuencia UART no continúa hasta que desaparezca esa solicitud y pueda comenzar una nueva liberación de dos etapas.

## Efectos del reset sobre el sistema

Los registros funcionales continúan utilizando el clock normal y consumen el reset en el flanco correspondiente. No tienen sensibilidad asíncrona al reset. La aserción asíncrona está limitada al acondicionador `reset_sync`.

Cuando el reset funcional está activo:

| Componente                  | Efecto                                                                                       |
|-----------------------------|----------------------------------------------------------------------------------------------|
| CPU, Loader y mantenimiento | Suprimen las escrituras y no producen efectos comprometidos.                                 |
| Registro de archivos        | Se inicializa en cero.                                                                       |
| PC y contador de ciclos     | Se inicializan según el estado de reset aprobado.                                            |
| Pipeline                    | Se invalida.                                                                                 |
| `loaded_image_size_bytes`   | Se pone en cero; no queda una imagen publicada.                                              |
| UART, RX/TX y FIFO          | Se reinician según sus contratos.                                                            |
| IMEM y DMEM                 | Conservan físicamente sus arrays; sus metadatos se limpian durante la preparación siguiente. |

El reset físico tiene prioridad en cualquier fase, incluida Debug, y puede abortar una transmisión sin generar una respuesta normal. El comando `RESET` por UART sigue la secuencia de reconocimiento, aceptación completa y solicitud registrada definida arriba.

## Referencias y trazabilidad

- [Protocol Controller](../debug/protocol_controller.md#reset-uart): reconocimiento, prioridad del terminal y solicitud registrada.
- [Response Serializer](../debug/response_serializer.md#comunicación-con-el-controlador): captura de la aceptación y fin físico de la respuesta.
- [Protocolo UART](../../protocol.md#aplicar-reset-global): intercambio de `RESET` y comportamiento desde PC.
- [Mapa de autoridad documental](../system_overview.md#autoridad-documental-por-tema): contratos vigentes y origen de las decisiones.
- [Requisitos](../../requirements.md): obligaciones y criterios de aceptación.
- [Decisiones pendientes](../../decisions/pending_decisions.md): decisiones de diseño abiertas y condiciones de cierre.
