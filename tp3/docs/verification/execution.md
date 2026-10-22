# TP3 — Sesión y ejecución

- **Tipo:** catálogo de verificación.
- **Estado documental:** catálogo diseñado; ejecución parcial en unidad e integración local de sesión.

## Propósito y alcance

Este documento reúne las pruebas del control global de ejecución y preparación de sesiones. Comprueba la aceptación de comandos, RUN, STEP y HOLD, la confirmación de halt o fault, los drains y el contador de ciclos efectivos.

Las [convenciones, niveles y límites del plan](verification_plan.md) se aplican a todos los casos. Los contratos enlazados determinan el comportamiento; la [matriz](coverage.md) relaciona las pruebas con los requisitos y el trabajo fuera de alcance.

En unidad de `Global FSM`, el banco presenta `reset`, `load_request`, `run_request`, `step_request` y las condiciones de sus productores. Observa `command_accepted`, `load_start`, `cpu_cycle_fire`, `image_publish`, las salidas Moore y el código de estado. En integración, `Execution Control` recibe las acciones de fault y los cuatro próximos `valid` desde sus productores y forma localmente `fault_confirm` y `pipeline_empty_next`.

## Índice

- [TEST-EXEC-001 — Elegibilidad, arbitraje y autorización global](#test-exec-001)
- [TEST-EXEC-002 — Preparación y último clear separado del primer ciclo](#test-exec-002)
- [TEST-EXEC-003 — RUN, STEP y espera entre comandos](#test-exec-003)
- [TEST-EXEC-004 — Siete causas de fault y precisión de efectos](#test-exec-004)
- [TEST-EXEC-005 — Halt exacto, consumo EX y drenado legal](#test-exec-005)
- [TEST-EXEC-006 — Fault drain, cambio STEP a AUTO y metadata retenida](#test-exec-006)
- [TEST-EXEC-007 — Reutilizar imagen desde FINISHED o FAULT](#test-exec-007)
- [TEST-EXEC-008 — Sin halt y recuperación por reset](#test-exec-008)
- [TEST-EXEC-009 — Contador efectivo y wrap de64 bits](#test-exec-009)
- [TEST-EXEC-010 — Reset y LOAD dominan efectos de la sesión anterior](#test-exec-010)

<a id="test-exec-001"></a>

## TEST-EXEC-001 — Elegibilidad, arbitraje y autorización global

- **Nivel:** unidad global_fsm e integración execution_control.
- **Tipo de estímulo:** fixtures de estado y solicitudes locales; cruces simultáneos artificiales.
- **Estado:** ejecución disponible en unidad Global FSM; integración pendiente.

**Requisitos:** [REQ-EXEC-006](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-008](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-016](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-CPU-018](../requirements.md#2-procesador-y-pipeline).

**Contratos:** [execution_control](../architecture/session/execution_control.md); [global_state_encoding](../architecture/session/global_state_encoding.md).

### Qué comprueba y por qué

Esta prueba comprueba la elegibilidad de los comandos, su arbitraje y la autorización de ciclos en cada estado global.

Busca detectar un comando que gane prioridad sin ser elegible, una LOAD rechazada que detenga un ciclo automático o una autorización calculada a partir de `next_state` en lugar del estado actual.

Los cruces de solicitudes comprueban que la misma orden pueda tener efectos distintos según exista una imagen, una sesión preparada, un drain o una preparación en curso.

### Condiciones iniciales

El banco prepara el registro interno one-hot del caso en `Global FSM` y presenta `load_ok=load_fail=halt_confirm=fault_confirm=0`. En unidad, `pipeline_empty_next` procede del fixture; en integración se obtiene de los próximos `valid` de los registros interetapa.

En integración con `Execution Control`, READY y las sesiones con imagen publicada tienen tamaño confirmado 16. LOADING, NO_IMAGE y PREPARING_READY tienen tamaño cero.

Para un drain se coloca una instrucción anterior en MEM/WB. Un drain vacío no se utiliza como si fuera una sesión alcanzable. Cuando `prepare_done=1`, el fixture representa un mantenimiento ya terminado, sin inicialización ni clear activos.

### Variantes cerradas

La prueba tiene 153 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-001/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

La selección aplica las nueve solicitudes enumeradas a los 14 estados con `prepare_done=0`. Los tres estados de preparación repiten esas nueve solicitudes con `prepare_done=1`.

Esto produce `14×9+3×9=153` casos. Los rechazos de LOAD durante ejecución automática ya están incluidos; no se agrega otro producto de solicitudes posibles.

### Estados y solicitudes enumerados

Los 14 estados son NO_IMAGE, LOADING, PREPARING_READY, READY, RUNNING, STEPPING, HALT_DRAIN_AUTO, HALT_DRAIN_STEP, FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP, FINISHED, FAULT, PREPARING_RUN y PREPARING_STEP. El código observado corresponde al estado actual.

Las nueve solicitudes son: `ninguna`, `LOAD`, `RUN`, `STEP`, `LOAD+STEP`, `LOAD+RUN`, `STEP+RUN`, `LOAD+STEP+RUN`, `RESET+LOAD+STEP+RUN`. Se aplican en cada estado con prepare_done=0. Solo los tres PREPARING repiten esas nueve solicitudes con prepare_done=1. De ahí salen 14×9+3×9=153 casos; no se ensayan todos los subconjuntos posibles de comandos.

`LOAD`, `RUN` y `STEP` activan sus entradas `load_request`, `run_request` y `step_request`; `RESET` activa `reset`. Los cruces simultáneos comprueban prioridad en la unidad; UART presenta una sola solicitud por ciclo.

### Procedimiento

1. **Preparar el estado y las solicitudes.** Instalar el fixture y los comandos de la variante.

2. **Observar la elegibilidad y el arbitraje.** Evaluar primero qué comandos pueden aceptarse y después la prioridad RESET, LOAD, STEP y RUN. Comparar `command_accepted` con la selección de LOAD/RUN/STEP. Reset debe llevar a NO_IMAGE con las cuatro salidas Mealy en cero.

3. **Comparar los controles preflanco.** Comprobar `command_accepted`, `load_start`, `cpu_cycle_fire` e `image_publish`. LOAD seleccionada activa aceptación e inicio y excluye un ciclo coincidente; LOAD rechazada conserva el ciclo automático. La publicación corresponde a PREPARING_READY con `prepare_done=1` y sin reset.

4. **Observar las salidas Moore.** Comparar las seis salidas de control y `global_state_code[7:0]` con el estado actual, según la [tabla de decodificación](../architecture/session/execution_control.md#señales-derivadas-de-global_state). El código llega a `Response Serializer.debug_state_code`.

5. **Aplicar el flanco y comparar la transición.** Revisar la FSM según el caso, incluidas las transiciones de carga o preparación con `cpu_cycle_fire=0`. La terminación y el inicio de preparación también se comprueban en TEST-EXEC-005, TEST-EXEC-006 y TEST-EXEC-007.

### Resultados y criterio de aprobación

LOAD es elegible en NO_IMAGE, READY, STEPPING, los drains STEP y los terminales. RUN y STEP son elegibles en ese mismo conjunto, excepto NO_IMAGE.

Hay ciclos automáticos en RUNNING y los drains AUTO. READY, STEPPING y los drains STEP ejecutan por una orden aceptada. PREPARING_RUN y PREPARING_STEP ejecutan al consumir `prepare_done`; PREPARING_READY nunca ejecuta CPU.

La autorización debe depender del estado actual. El encoder entrega los códigos 0 a 13 correspondientes sin demora ni un estado UART adicional.

La aprobación exige aceptación, inicio de carga, autorización, publicación y decodificación correctos en todas las filas, conservación de un estado one-hot legal y ausencia de una cola adicional que recuerde la orden durante preparación. El comando seleccionado y el destino de la FSM identifican el origen del ciclo.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-002"></a>

## TEST-EXEC-002 — Preparación y último clear separado del primer ciclo

- **Nivel:** unidad session_preparation e integración CPU.
- **Tipo de estímulo:** legal con estado previo del fixture.
- **Estado:** unidad e integración local ejecutadas con recursos modelados; CPU y Controller de producción pendientes.

**Requisitos:** [REQ-CPU-005](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-008](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-016](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-018](../requirements.md#2-procesador-y-pipeline), [REQ-MEM-007](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-008](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-029](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-030](../requirements.md#5-memorias-y-carga-de-programas), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-016](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DBG-012](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [session_preparation](../architecture/session/session_preparation.md); [execution_control](../architecture/session/execution_control.md).

### Qué comprueba y por qué

Esta prueba comprueba que la preparación inicialice la CPU y limpie todas las marcas de DMEM antes de autorizar la ejecución o publicar la imagen.

Busca detectar una inicialización del Register File ligada al recorrido de DMEM, la omisión de la última marca o un primer ciclo de CPU que coincida con una escritura de mantenimiento.

La preparación utiliza el mismo mecanismo para READY, RUN y STEP. Las capacidades se comprueban en ese mecanismo local; la integración con la FSM comprueba por separado qué debe ocurrir al terminar cada destino.

### Condiciones iniciales

El fixture prepara `x1…x31=0xA5A5A5A5`, `PC=64` y contador 99. Los latches tienen entradas válidas, todas las marcas de DMEM están activas y el dato físico de dirección a contiene `a mod 256`.

En unidad se inicia `Session Preparation` con índice cero y `prepare_active=1`, y se conectan los recursos que reciben sus acciones de inicialización y limpieza. El destino READY/RUN/STEP pertenece al fixture de integración con la FSM. Los registros `x1…x31` deben inicializarse simultáneamente incluso cuando C sea 4 o 28, mientras `x0` permanece en cero.

En integración se utiliza REFERENCE, con DMEM de 2048 bytes. PREPARING_READY tiene una imagen pendiente de 16 bytes; PREPARING_RUN y PREPARING_STEP conservan una imagen confirmada de ese tamaño. La primera palabra contiene `halt`, de modo que el primer fetch desde cero puede observarse sin depender de operandos anteriores.

Las capacidades genéricas pertenecen al fixture de los bloques. Los datos físicos de DMEM y el contenido de IMEM deben conservarse durante la preparación.

### Variantes cerradas

La prueba tiene 11 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-002/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los seis recorridos locales utilizan las capacidades 4, 28, 32, 36, 1000 y 2048. Corresponden a C001, C004, C007, C010, C013 y C016 y comprueban inicialización, direcciones de limpieza y duración del mantenimiento.

C016 también se ejecuta en integración para observar la publicación en READY. C017 y C018 comprueban, respectivamente, el primer ciclo de RUN y STEP con esa misma capacidad. Las dos observaciones de C016 utilizan sus mismos datos y no crean otra variante.

Los tres casos de reset, C019, C020 y C021, utilizan capacidad 4 y los destinos READY, RUN y STEP. El reset ocurre después de limpiar las direcciones 0 y 1. Para iniciar otra preparación, el fixture presenta la imagen pendiente o confirmada que requiere el destino, conservando el índice que dejó reset; el recorrido debe comenzar nuevamente desde cero.

### Procedimiento

1. **Preparar el estado residual.** Instalar los valores del fixture y conservar una copia de los datos físicos de DMEM y de IMEM. En integración, preparar además el tamaño pendiente o confirmado de la imagen.

2. **Seguir el recorrido local.** En el primer flanco, comprobar simultáneamente `prepare_init` y la limpieza de la marca cero. Observar que PC, contador y Register File se inicialicen en ese flanco y que los latches queden inválidos. En los C-1 flancos siguientes, comparar las direcciones hasta C-1, sin omisiones ni repeticiones.

3. **Observar el final del mantenimiento.** Después de la última limpieza, exigir índice C y `prepare_done` activo, con inicialización y limpieza inactivas. El flanco que consume done debe estar separado del último clear.

4. **Comprobar los tres destinos en integración.** En C016, consumir `prepare_done` debe activar `image_publish=1`, publicar el tamaño 16 y alcanzar READY con `cpu_cycle_fire=0`. En C017 y C018, exigir `image_publish=0` y `cpu_cycle_fire=1`: se ejecuta el primer fetch desde PC cero y el contador pasa de cero a uno. RUN continúa automáticamente; STEP conserva ese estado hasta una orden nueva.

5. **Aplicar reset durante el recorrido.** En C019–C021, comprobar que reset impida una limpieza coincidente; en integración, la FSM alcanza NO_IMAGE. Preparar después el estado y la imagen del destino y volver a activar el servicio, sin modificar el índice reiniciado. Verificar que la preparación nueva recorra desde dirección cero, sin reanudar el índice anterior. En C021, conectar también el Controller en `WAIT_STEP_END`, con serializador libre y sin resultado RUN pendiente. El reset distribuido debe llevarlo a `WAIT_COMMAND`, suprimir `response_start`, `uart_reset_request` y `debug_read_select`, y cancelar STEP sin dejar una operación diferida. Estas observaciones amplían la integración del mismo caso; conservan sus estímulos y expectativas de CPU y preparación.

### Resultados y criterio de aprobación

El primer flanco deja el Register File completo en cero, inicializa PC y contador, invalida el pipeline y limpia la primera marca. Los siguientes flancos limpian una sola marca por vez, sin escribir los datos físicos de DMEM ni IMEM.

Cada capacidad requiere C limpiezas y un flanco posterior para consumir done. REFERENCE utiliza 2049 clocks, equivalentes a 40,98 µs; ALT_1000 utiliza 1001 clocks, equivalentes a 20,02 µs. Ambos cumplen el presupuesto de 1 ms.

READY publica la imagen sin ejecutar CPU. RUN y STEP ejecutan su primer ciclo al consumir done, cuando ya no hay mantenimiento activo. El contador pasa de cero a uno y el primer fetch utiliza PC cero; la diferencia posterior es la continuidad automática de RUN frente a la retención de STEP.

Reset domina la limpieza y obliga a comenzar nuevamente desde cero. La aprobación exige inicialización completa aun con C menor que 32, recorrido íntegro, separación entre mantenimiento y ejecución y conservación de los datos físicos.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-003"></a>

## TEST-EXEC-003 — RUN, STEP y espera entre comandos

- **Nivel:** CPU/sistema.
- **Tipo de estímulo:** legal.
- **Estado:** integración local disponible; CPU y sistema pendientes.

**Requisitos:** [REQ-EXEC-006](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-008](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-010](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-011](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-DBG-016](../requirements.md#7-uart-y-debug-unit), [REQ-TIM-001](../requirements.md#9-clock-fpga-y-timing).

**Contratos:** [execution_control](../architecture/session/execution_control.md); [protocol](../protocol.md).

### Qué comprueba y por qué

Esta prueba comprueba que RUN autorice ejecución continua y que cada STEP aceptado autorice exactamente un ciclo de CPU.

Busca detectar un STEP que ejecute una instrucción completa, un stall que cause un ciclo adicional oculto o un clock físico detenido junto con la CPU.

La comparación entre modos comprueba la autorización temporal aunque ambos programas alcancen el mismo resultado arquitectónico.

### Condiciones iniciales

El sistema utiliza UART y comienza con el Register File en cero y el estado lógico de DMEM en cero.

Se cargan los dos programas indicados: el lineal de TEST-PIPE-001 y el programa completo de load-use. Este último prepara sus operandos mediante las tres primeras instrucciones antes del load y su consumidor.

Las instrucciones de preparación forman parte de la ejecución, del contador y de los snapshots. No se sustituyen por escrituras invisibles del Register File en una prueba legal de sistema.

### Variantes cerradas

La prueba tiene 4 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-003/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Se ejecutan los programas lineal y de load-use en RUN y STEP, para un total de cuatro casos.

Los datos de las pruebas de pipeline se utilizan aquí para observar autorización y mensajes del sistema. No se amplía la selección a otros consumidores.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para los casos `C001`, `C002`, se utiliza el siguiente programa:

```asm
addi x1,x0,1
addi x2,x0,2
addi x3,x0,3
addi x4,x0,4
addi x5,x0,5
addi x6,x0,6
halt
```

Para los casos `C003`, `C004`, se utiliza el siguiente programa:

```asm
addi x1,x0,8
sw x1,0(x0)
addi x2,x0,3
lw x1,0(x0)
add x3,x1,x2
halt
```

### Procedimiento

1. **Cargar la imagen y preparar el enlace.** Comprobar la sesión inicial y los dos programas.

2. **Ejecutar mediante RUN.** Enviar una solicitud válida y seguir `cpu_cycle_fire` hasta el terminal.

3. **Ejecutar mediante STEP.** Esperar cada respuesta completa, intercalar 50 clocks físicos y enviar la orden siguiente.

4. **Correlacionar las observaciones.** Comparar cada snapshot postflanco con el ciclo efectivo y el contador, especialmente durante el stall. Durante HOLD, UART debe continuar sin autorizar otro ciclo.

5. **Comparar ambos modos.** Contrastar el Register File, el estado lógico de DMEM y las trazas por ciclo efectivo. El contador no se compara con la cantidad de instrucciones retiradas.

### Resultados y criterio de aprobación

RUN desde READY ejecuta en el flanco de aceptación y continúa en modo automático. STEP desde READY o STEPPING ejecuta un ciclo y después retiene la CPU.

Un stall consume STEP e incrementa el contador aunque el PC no avance. Los clocks de espera y UART no agregan ciclos ni repiten commits.

El Register File y el estado lógico de DMEM deben coincidir al terminal de ambos modos. Cada snapshot posterior a STEP representa el mismo ciclo efectivo de la traza RUN.

La aprobación exige un `cpu_cycle_fire` por STEP aceptado y ninguno por una orden rechazada o por la espera. El clock físico debe continuar sin gating y `next_state` no debe autorizar ciclos.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-004"></a>

## TEST-EXEC-004 — Siete causas de fault y precisión de efectos

- **Nivel:** CPU e integración ID/EX.
- **Tipo de estímulo:** legal salvo fetch desalineado artificial.
- **Estado:** integración local disponible; CPU y sistema pendientes.

**Requisitos:** [REQ-EXEC-018](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-015](../requirements.md#2-procesador-y-pipeline), [REQ-MEM-016](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-017](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-018](../requirements.md#5-memorias-y-carga-de-programas), [REQ-DBG-017](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [faults_and_termination](../architecture/session/faults_and_termination.md); [stage_if](../architecture/cpu/stage_if.md); [stage_id](../architecture/cpu/stage_id.md); [stage_ex](../architecture/cpu/stage_ex.md).

### Qué comprueba y por qué

Esta prueba comprueba las siete causas de fault implementadas, el PC causante y la conservación de los efectos anteriores a la instrucción que falla.

Busca detectar metadatos de un candidato que no se confirmó, un efecto normal del load o store causante o la pérdida de un commit anterior.

La desalineación de un destino y la de un fetch comparten causa, pero identifican PCs causantes distintos. Los casos locales de fetch permiten observar esa diferencia sin atribuirles una trayectoria legal de CPU.

### Condiciones iniciales

El programa prepara el siguiente prefijo: `addi x8,x0,11` en PC 0, `addi x9,x0,12` en PC 4 y `sw x2,4(x0)` en PC 8. El banco instala `x2=3`, `x3=55` y `x4=0`.

La instrucción de PC 12 es la causante de la tabla. Para desalineación de datos se utiliza dirección efectiva 1; para acceso fuera de rango se utiliza base C e inmediato cero, tanto en load como en store.

El caso de fetch fuera de imagen coloca `addi x10,x0,13` en PC 12 y confirma una imagen de 16 bytes. En las otras secuencias, PC 16 contiene `add x4,x3,x3` y PC 20 contiene `sw x2,8(x0)`, seguidos de `halt`; esas instrucciones son jóvenes respecto de la causante.

Los dos PCs desalineados se inyectan en IF local y se transportan como candidatos hasta ID.

### Variantes cerradas

La prueba tiene 11 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-004/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los nueve programas comprueban las siete causas, con una repetición en ALT_1000 de load-access y otra de store-access.

Los dos casos artificiales de fetch utilizan PC 1 y PC 1025. Su candidato se transporta a ID; la palabra residual no se considera una instrucción ejecutable.

### Datos de referencia

| Causante / estímulo                                    | Causa | fault_pc |
|--------------------------------------------------------|------:|---------:|
| JAL x5,+2 en PC12                                      |     0 |       12 |
| Imagen termina tras ADDI en PC12, sin halt; fetch PC16 |     1 |       16 |
| Palabra 00000000 en PC12                               |     2 |       12 |
| LW x3,1(x0)                                            |     4 |       12 |
| LW x3, 0(x1)                                           |     5 |       12 |
| SW x2,1(x0)                                            |     6 |       12 |
| SW x2, 0(x1)                                           |     7 |       12 |

### Procedimiento

1. **Preparar el prefijo y la causante.** Guardar los valores que deben conservarse y cargar la variante de fault.

2. **Ejecutar hasta la confirmación.** Observar por separado el candidato de IF, ID o EX y `fault_capture_fire`.

3. **Comparar causa y PC.** Utilizar la tabla de referencia. En un load fallido, EX debe prevalecer sobre el load-use del consumidor que lee `x3`.

4. **Completar el drain anterior.** Comparar `x8`, `x9` y la palabra de DMEM en dirección 4. La causante y las instrucciones jóvenes de PC 16 y PC 20 no deben escribir el Register File ni DMEM.

5. **Observar la retención.** Conservar causa y PC durante drain y HOLD, sin una segunda confirmación. El mensaje terminal UART se comprueba en TEST-UART-010.

### Resultados y criterio de aprobación

IF detecta el fault de fetch e ID lo confirma. Una instrucción ilegal confirma en ID; los faults de destino y datos confirman en EX. La causa y el PC se capturan una sola vez; el código `011` permanece reservado.

La causante no debe escribir un resultado, enlace, dato o marca ni aplicar redirect. Las instrucciones jóvenes se descartan. Los efectos anteriores dejan `x8=11`, `x9=12` y la palabra de dirección 4 igual a 3.

Un load fallido conserva `x3=55` y `x4=0`. Un store fallido no modifica datos ni marcas. Los metadatos permanecen hasta FAULT y el candidato de fetch no se convierte en instrucción ilegal.

La aprobación exige causa, PC, etapa de confirmación y commits correctos en cada caso, incluidos los anteriores elegibles en el propio flanco de confirmación.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-005"></a>

## TEST-EXEC-005 — Halt exacto, consumo EX y drenado legal

- **Nivel:** CPU.
- **Tipo de estímulo:** legal.
- **Estado:** ejecución disponible en unidad Global FSM; integración pendiente.

**Requisitos:** [REQ-ISA-034](../requirements.md#3-conjunto-de-instrucciones), [REQ-EXEC-001](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-002](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-003](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-004](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-005](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-013](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DBG-017](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [faults_and_termination](../architecture/session/faults_and_termination.md); [execution_control](../architecture/session/execution_control.md); [architectural_invariants](../architecture/architectural_invariants.md).

### Qué comprueba y por qué

Esta prueba comprueba que `halt` se confirme en EX, descarte las instrucciones jóvenes y termine después de completar el trabajo anterior.

Busca detectar una detención prematura al ver `halt` en ID, la ejecución de instrucciones posteriores o un ciclo vacío añadido al final.

El programa de `halt` único comprueba la terminación directa cuando no queda trabajo anterior.

### Condiciones iniciales

La CPU comienza en READY con una sesión limpia y una imagen confirmada.

El programa A contiene solamente `halt` y ocupa cuatro bytes. El programa B ocupa 16 bytes: ejecuta ADDI y SW antes de `halt`, y coloca después una instrucción que intentaría escribir `x2=99`.

El Register File y el estado lógico de DMEM preparados permiten comprobar el store anterior y la ausencia del writeback joven.

### Variantes cerradas

La prueba tiene 4 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-005/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Se ejecutan los programas A y B en RUN y STEP. La espera en HOLD se introduce únicamente en B por STEP y pertenece a ese mismo caso.

Las comprobaciones reutilizadas conservan la palabra exacta de `halt` y los efectos del camino descartado.

También se ejecutan las comprobaciones reutilizadas de [TEST-ISA-004](isa.md#test-isa-004), [TEST-PIPE-008](pipeline.md#test-pipe-008). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para los casos `C001`, `C002`, se utiliza el siguiente programa:

```asm
halt
```

Para los casos `C003`, `C004`, se utiliza el siguiente programa:

```asm
addi x1,x0,7
sw x1,0(x0)
halt
addi x2,x0,99
```

### Procedimiento

1. **Preparar y ejecutar el programa.** Seguir `halt` desde ID. Su reconocimiento como candidato no debe frenar por sí solo la admisión.

2. **Observar la confirmación en EX.** Registrar el PC y los flags `next`. En A, comprobar FINISHED en ese mismo flanco, porque no quedan entradas válidas.

3. **Seguir el trabajo anterior de B.** Comprobar que el store y writeback anteriores continúen y que se descarte la instrucción que escribiría `x2`.

4. **Comprobar HOLD en STEP.** Esperar 50 clocks durante drain; sin ciclo efectivo no debe haber avance ni repetición de commits.

5. **Observar el último ciclo con trabajo.** Exigir FINISHED cuando el pipeline quede vacío, sin solicitar un paso adicional para terminar.

### Resultados y criterio de aprobación

La confirmación de EX consume `halt`, invalida ambos flags de IF/ID y las entradas nuevas de ID/EX y EX/MEM, y retiene el PC. `halt` no escribe ni entra válidamente en EX/MEM.

A alcanza FINISHED directamente durante su ciclo EX. B conserva `x1=7`, la palabra cero de DMEM igual a 7 y `x2=0`. Si queda trabajo anterior, utiliza HALT_DRAIN_AUTO o HALT_DRAIN_STEP.

En un drain legal, `IF/ID.valid=fetch_fault_valid=ID/EX.valid=0` y `load_use_stall=0`; solo se utiliza `act_drain_advance`. STEP requiere una orden por avance y HOLD no repite commits.

La aprobación exige que el último ciclo con trabajo ya muestre FINISHED y que no se añada un ciclo vacío.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-006"></a>

## TEST-EXEC-006 — Fault drain, cambio STEP a AUTO y metadata retenida

- **Nivel:** CPU y unidad global_fsm.
- **Tipo de estímulo:** recorridos legales y fixtures locales artificiales.
- **Estado:** ejecución disponible en unidad Global FSM; integración pendiente.

**Requisitos:** [REQ-EXEC-003](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-015](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-018](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DBG-016](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-017](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [execution_control](../architecture/session/execution_control.md); [faults_and_termination](../architecture/session/faults_and_termination.md).

### Qué comprueba y por qué

Esta prueba comprueba el avance de los drains, su retención entre órdenes STEP y el cambio a ejecución automática al aceptar RUN.

Busca detectar un drain STEP que avance solo, un RUN que reinicie la sesión en lugar de completar el trabajo pendiente o un terminal que requiera un ciclo adicional.

Un fault confirmado en ID puede dejar dos etapas finales pendientes. La confirmación de `halt` en EX solo deja trabajo en MEM/WB. Los casos locales de FSM comprueban sus filas sin atribuir otro estado alcanzable al programa de `halt`.

### Condiciones iniciales

Para fault se utiliza el prefijo que escribe 11 en `x8`, 12 en `x9` y 3 en la palabra de dirección 4, seguido de la palabra ilegal cero en PC 12. La ejecución se realiza mediante STEP.

Para `halt` se ejecutan tres ADDI independientes seguidos de `halt`. La confirmación deja únicamente el writeback anterior pendiente.

En unidad se instala HALT_DRAIN_STEP en el registro interno de `Global FSM` y se presenta `run_request=1`, con `reset=load_request=step_request=0`. El fixture controla `pipeline_empty_next` y observa la aceptación, la autorización y el estado siguiente.

### Variantes cerradas

La prueba tiene 7 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-006/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los tres recorridos de fault completan dos ciclos mediante STEP, aceptan RUN con dos etapas finales pendientes o aceptan RUN cuando solo queda MEM/WB.

Los dos recorridos legales de `halt` completan el único WB remanente mediante STEP o RUN.

Los dos casos locales restantes conservan estas expectativas:

| Caso | Entrada local                            | Estado siguiente esperado |
|------|------------------------------------------|---------------------------|
| C006 | `run_request=1`, `pipeline_empty_next=0` | `HALT_DRAIN_AUTO`         |
| C007 | `run_request=1`, `pipeline_empty_next=1` | `FINISHED`                |

C006 comprueba el contrato combinacional artificial de la FSM. En el drain legal de `halt`, el único WB pendiente se consume en un ciclo efectivo y deja `pipeline_empty_next=1`; la transición artificial de C006 queda fuera del grafo de sesiones alcanzables.

### Procedimiento

1. **Llegar al drain STEP.** En C001–C005, ejecutar la secuencia correspondiente hasta HALT_DRAIN_STEP o FAULT_DRAIN_STEP.

2. **Observar la espera.** Pausar 50 clocks y comprobar la retención del PC, latches, contador y metadatos.

3. **Aplicar las órdenes del recorrido.** Cada STEP autoriza un ciclo. RUN ejecuta el ciclo actual y pasa a AUTO si queda trabajo, o directamente al terminal si el pipeline queda vacío.

4. **Comparar los mensajes de STEP.** En los recorridos de CPU, registrar DONE en cada paso, incluso al alcanzar FAULT. El estado del snapshot distingue el fault; no se reemplaza la cabecera DONE.

5. **Observar el ciclo final.** Comprobar metadatos estables, ausencia de confirmaciones nuevas y selección del terminal mediante la validez `next` del último ciclo.

6. **Comprobar C006 y C007 en unidad.** Aplicar cada fixture con `run_request=1`. Antes del flanco, exigir `command_accepted=1`, `cpu_cycle_fire=1`, `drain_mode=1` y `load_start=image_publish=0`. Después del flanco, comparar el estado con la tabla de los dos casos locales.

### Resultados y criterio de aprobación

La espera conserva el estado y cada STEP ejecuta exactamente un ciclo de drain. RUN completa el ciclo actual y continúa automáticamente solo si queda trabajo.

Durante drain y HOLD no cambian los metadatos ni se confirma otra frontera. Las cuatro clases de drain conservan su política. El último ciclo entra en FAULT o FINISHED sin un ciclo vacío adicional.

RUN devuelve el resultado terminal automático. STEP conserva DONE y utiliza el estado observado para distinguir la situación.

La aprobación exige las cuatro clases de drain y ambos resultados del cambio a RUN: trabajo restante o pipeline vacío. C006 conserva su destino artificial HALT_DRAIN_AUTO y C007 alcanza FINISHED; los recorridos legales de halt terminan en el único ciclo de drenado.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-007"></a>

## TEST-EXEC-007 — Reutilizar imagen desde FINISHED o FAULT

- **Nivel:** CPU/sistema.
- **Tipo de estímulo:** legal.
- **Estado:** ejecución disponible en unidad Global FSM; integración pendiente.

**Requisitos:** [REQ-CPU-016](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-018](../requirements.md#2-procesador-y-pipeline), [REQ-MEM-007](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-008](../requirements.md#5-memorias-y-carga-de-programas), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-015](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DBG-012](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-016](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [execution_control](../architecture/session/execution_control.md); [session_preparation](../architecture/session/session_preparation.md).

### Qué comprueba y por qué

Esta prueba comprueba que RUN o STEP desde FINISHED o FAULT inicien una nueva sesión sobre la imagen retenida.

Busca detectar la reanudación de datos y trabajo de la sesión terminada, o la interpretación de una causa de fault anterior como si perteneciera a la nueva ejecución.

La imagen sigue vigente, pero el Register File y el estado lógico de DMEM deben prepararse nuevamente antes del primer ciclo.

### Condiciones iniciales

La imagen confirmada tiene 16 bytes. Ejecuta `addi x1,x0,7; sw x1,0(x0); addi x2,x0,9` y termina con `halt` o con la palabra ilegal cero, según el caso.

Se llega al terminal después de que el transporte haya quedado libre. El banco conserva la imagen y su tamaño, junto con los valores residuales del Register File y DMEM, para observar su preparación.

### Variantes cerradas

La prueba tiene 4 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-007/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Se combinan los terminales FINISHED y FAULT con una nueva orden RUN o STEP.

Son cuatro trayectorias sobre la misma imagen retenida. LOAD y reset se comprueban aparte; no se agregan cruces con otros comandos.

### Procedimiento

1. **Ejecutar la primera sesión.** Llegar al terminal y guardar el contenido de IMEM y el tamaño confirmado.

2. **Aceptar RUN o STEP.** Enviar la orden sin una LOAD intermedia y seguir la entrada a preparación. Observar `command_accepted=1` con `load_start=image_publish=cpu_cycle_fire=0` en el flanco de aceptación.

3. **Observar la preparación.** Exigir ausencia de CPU y de snapshot mientras se inicializan el Register File, los latches y el contador y se limpian las marcas de DMEM. IMEM debe conservarse.

4. **Observar el consumo de done.** En ese flanco, exigir `cpu_cycle_fire=1` e `image_publish=0`, y comprobar el primer fetch desde PC cero y el contador de cero a uno.

5. **Comparar la nueva sesión.** RUN continúa; STEP retiene después de ese primer ciclo. Los metadatos anteriores no deben interpretarse como un fault vigente de la sesión nueva.

### Resultados y criterio de aprobación

La imagen y el tamaño se conservan, pero la sesión terminada no se reanuda. Durante la preparación no hay ejecución de CPU ni snapshot.

El primer ciclo ocurre con PC cero, Register File preparado, estado lógico de DMEM en cero y pipeline vacío. El contador pasa de cero a uno al consumir done.

La causa de fault anterior pierde vigencia sin exigir que sus bits físicos se borren. Solo un fault confirmado en la nueva sesión puede volver a dar vigencia a sus propios metadatos.

La aprobación exige que las cuatro combinaciones de terminal y orden inicien correctamente una sesión nueva sobre la imagen retenida.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-008"></a>

## TEST-EXEC-008 — Sin halt y recuperación por reset

- **Nivel:** CPU/sistema.
- **Tipo de estímulo:** legal.
- **Estado:** integración local disponible; CPU y sistema pendientes.

**Requisitos:** [REQ-EXEC-012](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-014](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-015](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DOC-004](../requirements.md#10-documentación-y-trazabilidad), [REQ-DBG-017](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [execution_control](../architecture/session/execution_control.md); [faults_and_termination](../architecture/session/faults_and_termination.md); [protocol](../protocol.md).

### Qué comprueba y por qué

Esta prueba comprueba que la ausencia de `halt` no se confunda con terminación normal y que un programa continuo pueda abandonarse mediante reset.

Busca detectar un timeout interpretado como FINISHED, un `halt` implícito fuera de imagen o una UART que deje de atender mientras la CPU ejecuta un loop.

La observación del loop utiliza una ventana de 20 ciclos efectivos del banco de pruebas y no agrega un detector de terminación al procesador. No fija el ciclo exacto del reset UART: la CPU continúa mientras se completa la aceptación de RUN y el intercambio RESET.

### Condiciones iniciales

Cada imagen tiene cuatro bytes y la sesión comienza limpia.

La imagen de loop contiene `jal x0,0`, que redirige a su propio PC. La imagen de ADDI contiene una única instrucción y obliga al fetch posterior de PC 4. La imagen restante contiene la palabra ilegal cero en PC 0.

UART permanece activa durante RUN. No se envía CHECK_READY durante su ejecución; el único comando admitido es RESET, después del último Stop de RUN/ACCEPTED y con la preparación inactiva. El botón conserva su acción directa.

### Variantes cerradas

La prueba tiene 4 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-008/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Dos casos ejecutan el mismo loop y lo abandonan mediante reset UART o botón.

Los otros dos ejecutan la imagen de ADDI sin `halt` y la imagen ilegal. Ambas terminan por fault, pero con causas y PCs distintos.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para los casos `C001`, `C002`, se utiliza el siguiente programa:

```asm
jal x0,0
```

Para el caso `C003`, se utiliza el siguiente programa:

```asm
addi x1,x0,1
```

Para el caso `C004`, se utiliza el siguiente programa:

```asm
.word 0x00000000
```

### Procedimiento

1. **Cargar y ejecutar el loop.** Completar LOAD, enviar RUN y observar una ventana de 20 ciclos efectivos, sin esperar una terminación del programa.

2. **Respetar la fase de transporte.** En C001, esperar el último Stop de RUN/ACCEPTED y comprobar `prepare_active=0` antes de enviar RESET. La CPU puede seguir ejecutando más allá de la ventana observada. No intercalar CHECK_READY ni otros comandos; su descarte y recuperación se comprueban en TEST-UART-003.

3. **Solicitar el reset.** En C001, enviar `04`, recibir `04 01` completa y exigir reset global después de su último Stop, sin pausar anticipadamente la CPU. En C002, aplicar el botón sin esperar aceptación UART; puede abortar una respuesta en curso. No exigir FINISHED ni snapshot terminal del RUN abandonado.

4. **Ejecutar las otras dos imágenes.** Comparar FAULT con causa 1 y PC 4 después de ADDI, y causa 2 con PC cero para la palabra ilegal.

5. **Revisar los efectos.** La ADDI anterior debe conservar su commit antes del fault de fetch. Después de reset deben observarse la invalidez de imagen y el estado reinicializado.

### Resultados y criterio de aprobación

El loop permanece en RUNNING, sin terminal ni timeout de duración. No se consulta disponibilidad durante RUN ni se espera BUSY. UART admite RESET en su ventana y el botón permite abandonar la ejecución directamente.

La ADDI sin `halt` produce un access fault de fetch; la palabra cero produce un fault por instrucción ilegal. Un timeout del banco de pruebas no equivale a FINISHED.

Reset abandona el loop y deja NO_IMAGE, PC, Register File y contador en cero, con flags inválidos. No se requiere una finalización normal ni un snapshot del RUN cancelado.

RESET UART se reconoce después de completar RUN/ACCEPTED y la preparación; el reset global espera además el último Stop de RESET/ACCEPTED. El botón puede solicitar reset inmediatamente. La aprobación exige recuperación y distinción entre terminación, fault y abandono dentro de la observación acotada.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-009"></a>

## TEST-EXEC-009 — Contador efectivo y wrap de 64 bits

- **Nivel:** unidad contador y CPU.
- **Tipo de estímulo:** legal; fixture próximo al wrap artificial.
- **Estado:** integración local disponible; CPU y sistema pendientes.

**Requisitos:** [REQ-DBG-016](../requirements.md#7-uart-y-debug-unit), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-CPU-001](../requirements.md#2-procesador-y-pipeline).

**Contratos:** [execution_control](../architecture/session/execution_control.md); [protocol](../protocol.md).

### Qué comprueba y por qué

Esta prueba comprueba que el contador de 64 bits aumente una vez por ciclo efectivo, se conserve durante HOLD y haga wrap módulo `2^64`.

Busca detectar la cuenta de clocks físicos en lugar de ciclos CPU, un ancho de 32 bits, saturación o un fault causado por alcanzar el máximo.

La aritmética se comprueba con valores próximos al máximo. Las trazas de pipeline comprueban por separado que stalls y drains autoricen incrementos, aunque no retiren una instrucción nueva.

### Condiciones iniciales

En unidad se prepara el valor previo indicado y se aplica la habilitación del caso. Inicialización y reset se presentan directamente a los recursos del contador para comprobar su prioridad frente al incremento.

C008 utiliza un fixture de integración con execution_control y la lógica de hazards en RUNNING. El PC es `0x40`, hay trabajo pendiente y no existen candidatos de fault, halt, redirect ni load-use. El contador comienza en `FFFFFFFFFFFFFFFF`.

Ese caso se compara también con el mismo fixture y contador 41. Las expectativas independientes son avance normal, ausencia de confirmaciones y PC siguiente `0x44`; la comparación entre ambos valores del contador complementa esas expectativas.

La inyección del máximo permite comprobar el wrap sin simular `2^64` ciclos. No representa una sesión que haya ejecutado físicamente esa cantidad de ciclos.

### Variantes cerradas

La prueba tiene 5 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-009/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

C001 incrementa `FFFFFFFFFFFFFFFE` hasta `FFFFFFFFFFFFFFFF`. C002 conserva el máximo con el ciclo deshabilitado. C008 comprueba el wrap durante un avance normal de integración.

C011 y C012 aplican reset y `prepare_init`, respectivamente, frente a un incremento solicitado. Ambos deben dejar el contador en cero. La prioridad global sobre los commits de CPU se comprueba en [TEST-EXEC-010](#test-exec-010).

Las comprobaciones reutilizadas observan la cuenta durante avance, stall y drain y la representación del contador en Debug.

También se ejecutan las comprobaciones reutilizadas de [TEST-PIPE-001](pipeline.md#test-pipe-001), [TEST-PIPE-005](pipeline.md#test-pipe-005), [TEST-EXEC-005](#test-exec-005), [TEST-EXEC-006](#test-exec-006), [TEST-UART-007](uart_debug.md#test-uart-007). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Procedimiento

1. **Comprobar el incremento previo al máximo.** Preparar `FFFFFFFFFFFFFFFE`, habilitar un ciclo y exigir `FFFFFFFFFFFFFFFF` después del flanco.

2. **Comprobar HOLD.** Mantener el máximo con el ciclo deshabilitado. Los clocks físicos deben conservar el contador y no producir un incremento.

3. **Observar el wrap en integración.** Aplicar el flanco del fixture C008 y exigir contador cero, `act_normal` y PC `0x44`, sin fault, halt, redirect ni reset. Repetir el mismo estímulo con contador 41: debe producir contador 42 y las mismas señales de control esperadas.

4. **Aplicar reset y preparación.** Con el máximo y un incremento solicitado, exigir contador cero después del flanco. La inicialización debe prevalecer sobre la suma, tanto para reset como para `prepare_init`.

5. **Relacionar las trazas y el snapshot.** En las pruebas reutilizadas, comprobar un incremento por ciclo efectivo, incluidos stall y drain, y ninguno durante HOLD. Comparar los ocho bytes little-endian del contador con el fixture de Debug.

### Resultados y criterio de aprobación

El contador aumenta exactamente una vez por `cpu_cycle_fire`. UART y mantenimiento no lo incrementan por sí mismos; los stalls y drains sí cuentan cuando ejecutan un ciclo de CPU.

El máximo vuelve a cero sin saturación ni nuevos faults o flags. En C008 se conserva el avance normal: el PC pasa de `0x40` a `0x44` y el estado continúa en RUNNING. HOLD conserva el máximo; reset y preparación dejan cero.

El contador `0102030405060708` se serializa como `08 07 06 05 04 03 02 01`.

La aprobación requiere los valores exactos de las cinco variantes, la independencia del control respecto del wrap y la cuenta correcta en las trazas reutilizadas.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-exec-010"></a>

## TEST-EXEC-010 — Reset y LOAD dominan efectos de la sesión anterior

- **Nivel:** integración CPU/control.
- **Tipo de estímulo:** legal y coincidencias locales.
- **Estado:** integración local disponible; CPU y sistema pendientes.

**Requisitos:** [REQ-CPU-008](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-016](../requirements.md#2-procesador-y-pipeline), [REQ-EXEC-015](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-MEM-007](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-019](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-028](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-030](../requirements.md#5-memorias-y-carga-de-programas).

**Contratos:** [execution_control](../architecture/session/execution_control.md); [reset_integration](../architecture/platform/reset_integration.md); [session_preparation](../architecture/session/session_preparation.md).

### Qué comprueba y por qué

Esta prueba comprueba la prioridad de una LOAD aceptada, reset y preparación sobre los efectos de una sesión anterior.

Busca detectar un store o writeback viejo en el flanco de aceptación de LOAD, o la cancelación de un commit anterior por una LOAD que fue rechazada.

Los contextos de carga y mantenimiento comprueban que la autoridad de reset abarque esos recursos además de la ejecución.

### Condiciones iniciales

En espera STEP se prepara trabajo anterior válido en MEM y WB. En los drains alcanzables se conserva la disposición real del trabajo: `halt` confirmado en EX deja solo MEM/WB, mientras que un fault de ID puede dejar EX/MEM y MEM/WB.

Los contextos de Loader y preparación se fuerzan localmente con la última habilitación de escritura prevista. Estos fixtures permiten comprobar prioridades y no constituyen por sí solos trayectorias end-to-end.

### Variantes cerradas

La prueba tiene 9 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-EXEC-010/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Tres casos aceptan LOAD desde estados de espera de órdenes con sesión válida: STEPPING y los dos drains STEP.

Otros tres aplican reset frente a efectos distintos: store o writeback de CPU, última palabra de Loader y clear de preparación.

Los tres casos de LOAD rechazada utilizan RUNNING y los dos drains AUTO. La inicialización frente a WB y el clear frente a store se comprueban mediante las reutilizaciones indicadas, sin duplicar esos casos.

También se ejecutan las comprobaciones reutilizadas de [TEST-PIPE-002](pipeline.md#test-pipe-002), [TEST-MEM-006](memory.md#test-mem-006). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Procedimiento

1. **Preparar el trabajo anterior.** Instalar los latches y el contexto de escritura que correspondan al estado.

2. **Solicitar LOAD en los tres estados de espera.** Presentar `load_request=1` y observar `command_accepted=load_start=1`, con `cpu_cycle_fire=0`. Comprobar la invalidez de imagen y la ausencia de store o writeback de la sesión abandonada.

3. **Solicitar LOAD durante AUTO.** Presentar `load_request=1` y observar `command_accepted=load_start=0`, con `cpu_cycle_fire=1`. Verificar que el ciclo efectivo y los commits anteriores continúen en los tres estados previstos.

4. **Aplicar reset antes del flanco.** En cada contexto, exigir las cuatro salidas Mealy de la FSM y todas las habilitaciones de escritura inactivas.

5. **Comprobar las prioridades reutilizadas.** Revisar init frente a WB en TEST-PIPE-002 y clear frente a store en TEST-MEM-006.

### Resultados y criterio de aprobación

Una LOAD aceptada pone el tamaño en cero, suprime el ciclo y los commits viejos y abandona el drain anterior. Una LOAD rechazada conserva la imagen y la ejecución y permite el commit elegible anterior.

Reset domina las escrituras, pone en cero el Register File, PC y contador e invalida la imagen y los latches. No exige borrar los arrays físicos.

La preparación prevalece sobre WB y el clear prevalece sobre store, según los casos reutilizados.

La aprobación exige la prioridad global correcta sobre estado y commits. Una solicitud rechazada no debe interpretarse como abandono de la sesión.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

## Evidencia local de Global FSM — primer bloque de #8

`rtl/global_fsm.sv` implementa la fase de sesión, selección de comandos y autorización
sin puertos de prueba. `tb/global_fsm_tb.sv` comprueba los controles antes del flanco,
la captura del destino, el estado one-hot y su código externo después del flanco.
La implementación utiliza dos bloques: un único `always_comb` fija valores por
defecto y calcula salidas Moore, autorización y estado siguiente; un `always_ff`
actualiza únicamente `global_state` en el flanco. La autorización y las transiciones
se describen en tablas planas `casez` sobre concatenaciones del estado actual y
sus entradas relevantes. Los patrones `?` ignoran columnas sin efecto y el orden
de filas hace explícita la prioridad. Las combinaciones de órdenes usan constantes
`CTRL_*` con nombre; las máscaras separan sus bits con `_` y tienen encabezados
junto a cada tabla. Las transiciones se agrupan por estado de origen después de
las reglas globales de RESET y LOAD, conservando el orden relativo de sus filas.
Las columnas de ambas tablas se alinean manualmente; directivas locales de
Verible preservan esa presentación al ejecutar el formatter.
La autorización usa estado, solicitudes y preparación; las confirmaciones y
`pipeline_empty_next` solo intervienen en la tabla de destino. La decodificación
Moore depende únicamente del estado registrado. El único registro de la FSM es
`global_state`; las acciones sobre los recursos se realizan en sus consumidores.

| IDs | Nivel registrado | Comprobación disponible | Pendiente |
|---|---|---|---|
| `TEST-EXEC-001/C001–C153` | Unidad | Las 153 filas originales de elegibilidad, prioridad, autorización, publicación, Moore/Mealy y transición. | Integración de `execution_control`, tamaño confirmado y productores reales. |
| `TEST-EXEC-005/C001–C004` | Unidad | Proyección de confirmación halt, terminal directo, drain AUTO/STEP y HOLD de 50 clocks en C004. | Programa real, reconocimiento/consumo EX, PC, descarte y commits anteriores/jóvenes en CPU. |
| `TEST-EXEC-006/C001–C005` | Unidad | Proyección de los drains con resultados de pipeline modelados, HOLD de 50 clocks y cambio STEP a RUN con trabajo restante o último WB. | Recorrido de CPU, precisión de efectos, captura/retención de metadata y respuestas UART. |
| `TEST-EXEC-006/C006–C007` | Unidad | Los dos vectores artificiales originales; C006 conserva `HALT_DRAIN_AUTO` con `pipeline_empty_next=0`. | No representan recorridos alcanzables de halt; no acreditan integración CPU. |
| `TEST-EXEC-007/C001–C004` | Unidad | Desde FINISHED/FAULT, aceptación sin ciclo, espera en PREPARING_RUN/STEP, primer ciclo con done y continuidad RUN/retención STEP. | Imagen real retenida, PC/RF/DMEM/pipeline preparados y contador de cero a uno. |

Son **168 IDs con ejecución unitaria**, conservando todos los IDs, entradas y
expectativas anteriores. `implemented` indica disponibilidad de una ejecución;
no significa que estén aprobados todos los niveles del caso.

Los vectores de TEST-EXEC-001 y C006–C007 instalan el estado mediante una escritura
jerárquica exclusiva del banco. Las trece proyecciones restantes conducen una
secuencia desde reset y suministran resultados modelados de carga, preparación,
confirmación y vacío. Su setup incluye carga abortada, carga completa, espera y
publicación. Los nuevos `inputs.fsm_steps` y `expected.fsm_steps` mantienen cada
estímulo y expectativa en JSON; `clocks` fija los flancos con ese estímulo. Durante
HOLD no hay ciclos CPU; en RUNNING cada flanco repetido sí autoriza un ciclo.
El banco interpreta esos datos y realiza las aserciones SystemVerilog; el ejecutor
Python permanece genérico y sin cambios.

Estas secuencias acreditan la frontera de la FSM. No ejecutan las instrucciones
que figuran en los casos originales, no producen commits ni modelan como CPU real
la ubicación o edad de cada instrucción. Loader, preparación y `execution_control`
se incorporan en los siguientes bloques de #8; la integración con CPU corresponde
a #9 y UART/sistema a sus entregas posteriores. Los demás IDs y niveles conservan
su obligación y su estado pendiente; esta unidad no cierra #8.

### Reproducción

Desde la raíz del repositorio, con la imagen exacta de `tp3/docker/image.ref`:

```bash
TP3_IMAGE="$(cat tp3/docker/image.ref)"
docker run --rm --network none \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$PWD,dst=/workspace" \
  "$TP3_IMAGE" make check
```

Dentro del contenedor, desde `/workspace/tp3`, la selección de esta unidad es:

```bash
bash scripts/run_tests.sh \
  --test TEST-EXEC-001 \
  --test TEST-EXEC-005 \
  --test TEST-EXEC-006 \
  --test TEST-EXEC-007 \
  --format json --reports-dir build/reports/global-fsm
```

La regresión de `make check` conserva resultados y comandos de compilación/simulación
en `build/reports/results.json`, `build/reports/simulation/` e
`infrastructure.log`. La evidencia de esta implementación corresponde al árbol
local sobre `c8ddc08`, con cambios sin commit. `build/reports/global-fsm-context.json`
registra la referencia Git, la imagen y los hashes de sus fuentes y catálogo.
Síntesis, timing y placa siguen pendientes.

La comprobación local con la imagen fijada aprobó formato, lint, catálogo,
**40 pruebas de infraestructura y 187 ejecuciones RTL**: 168 de esta unidad y
19 de la base compartida de #3, con cero fallos y errores. El catálogo conserva
1363 casos canónicos: 184 tienen una ejecución disponible y 1179 están pendientes.


### Comprobación de la refactorización a tablas casez

La misma imagen fijada ejecutó además una comparación suplementaria de la versión
previa y la refactorizada: los 14 estados legales y tres representaciones internas
inválidas (cero, dos bits activos y todos los bits activos), con las 1024
combinaciones binarias de las diez entradas de control para cada estado. Las
**17.408 comparaciones** verifican salidas Moore/Mealy, código externo, próximo
estado y captura registrada. Incluyen combinaciones artificiales; no constituyen
17.408 casos nuevos del catálogo ni sesiones legales de CPU.

El snapshot previo, el banco de comparación, los comandos y logs quedan en
`build/reports/global-fsm-casez/`. Esta comparación acredita equivalencia frente
al snapshot; las expectativas independientes continúan en `cases.json` y se
comprueban mediante la regresión habitual. La documentación de diseño, los IDs y
sus expectativas no se modificaron durante esta refactorización.


La reorganización posterior en un bloque combinacional y uno secuencial repitió
las 17.408 comparaciones frente al snapshot de tres bloques combinacionales, con
las mismas columnas y alcance binario. `build/reports/global-fsm-two-block/`
conserva ambos modelos, banco, comandos y resultados. También se elaboró con
Verilator un fixture que produce confirmaciones y vacío a partir de
`cpu_cycle_fire` y `drain_mode`, para comprobar las dependencias combinacionales;
no se detectaron lazos y no se agregó ningún puerto al producto.


La mejora de legibilidad posterior repitió las mismas 17.408 comparaciones frente
al snapshot previo, manteniendo los dos bloques y todas las expectativas del
catálogo. La evidencia más reciente, incluidos comandos, referencia, banco y
fixture de dependencias, queda en `build/reports/global-fsm-readability/`.

## Evidencia local de Execution Control — segundo bloque de #8

El primer bloque, Global FSM y sus pruebas, quedó consolidado en `82fe145`.
`rtl/execution_control.sv` instancia esa FSM sin modificarla y agrega los recursos
locales previstos en Interfaces §6.1–6.3, §7.1 y §9.3–9.4:

- Selección de causa/PC de EX o ID y captura con las acciones de fault confirmadas.
  Reset inhibe la captura, sin exigir borrar físicamente la metadata; su vigencia
  continúa determinada por la fase global.
- Tamaño confirmado con prioridad `reset > load_start > image_publish > retener`.
  `image_valid` es combinacional; `load_ok` no publica la imagen.
- Contador de 64 bits con prioridad `reset > prepare_init > cpu_cycle_fire > retener`,
  wrap módulo `2^64` y sin borrado por la sola aceptación de LOAD.
- Reducción combinacional de los cuatro próximos `valid`, independiente de
  `next_state`, para decidir terminal o drain sin un ciclo vacío adicional.

El parámetro `IMEM_CAPACITY_BYTES` determina `IMAGE_SIZE_WIDTH` mediante el paquete
compartido. Las capacidades inválidas se rechazan antes de elaborar la FSM y los
recursos registrados; no se agregan memorias ni registros de validez redundantes.
Loader, preparación, hazards y los registros del pipeline siguen fuera del módulo.

`tb/execution_control_tb.sv` comprueba las salidas antes del flanco y los recursos
registrados después. Las inyecciones y valores comunes se declaran en
`inputs.control_fixture`; `resource_defaults` evita duplicar esos datos en cada
flanco. Los vectores y secuencias de la FSM se leen de sus campos originales;
`inputs.control_steps` y `expected.control_steps` agregan los recursos del contenedor
y las secuencias propias. El banco puede repetir una
expectativa estable durante varios clocks de HOLD; los ciclos que incrementan
usan una expectativa por flanco. El ejecutor Python y el banco anterior de la FSM
permanecen sin cambios. No se reemplazan IDs, entradas, expectativas ni ejecuciones
anteriores del catálogo.

| IDs reutilizados | Comprobación nueva | Límite de la evidencia |
|---|---|---|
| `TEST-EXEC-001/C001–C153` | FSM dentro del contenedor, imagen, contador, metadata y reducción desde los cuatro próximos `valid`. | Vectores locales con estado y recursos instalados; no son recorridos de CPU. |
| `TEST-EXEC-004/C001–C011` | Causa/PC de ID o EX, retención durante 50 clocks de HOLD, drain, terminal y reset. C001 incluye una coincidencia EX/ID forzada para comprobar el multiplexor. | Las causas y acciones llegan modeladas: no se detectan faults ni se ejecutan los programas originales. |
| `TEST-EXEC-005/C001–C004`, `TEST-EXEC-006/C001–C007` | Secuencias anteriores con imagen y contador reales del contenedor; captura y retención de metadata de fault. | Confirmaciones y próximos `valid` modelados. C006–C007 siguen siendo vectores artificiales de halt. |
| `TEST-EXEC-007/C001–C004` | Reutilización sin cambiar el tamaño, inicialización del contador y primer ciclo con cuenta uno; metadata residual conservada. | El productor de preparación está modelado; PC/RF/DMEM no participan. |
| `TEST-EXEC-009/C001–C002`, `C008`, `C011–C012` | Cuenta, HOLD, wrap, ciclo posterior e inicialización. | C011–C012 fuerzan la orden de ciclo para enfrentar reset/preparación al incremento del recurso. C008 acredita el contador y la fase; hazards, PC y comparación integrada con contador 41 siguen pendientes. |
| `TEST-EXEC-010/C001–C009` | LOAD aceptado/rechazado, reset y preparación frente a los recursos locales. | No acredita supresión o autorización de commits de CPU, última escritura IMEM ni limpieza real de DMEM. |
| `TEST-PLAT-001/C004–C008` | Publicación de la capacidad inclusive, retención y reset para 4, 1000, 1024, 2048 y `2^32` bytes. | Solo registros de tamaño de hasta 33 bits; no reserva arrays ni acredita realización física. |

Son **198 ejecuciones locales adicionales** sobre los mismos IDs. El catálogo
conserva 1363 casos canónicos; 209 tienen alguna ejecución disponible y 1154 siguen
pendientes. La disponibilidad de una proyección local no completa los niveles de
CPU o sistema exigidos por el caso original.

### Reproducción y alcance

`make check`, con la imagen exacta de `docker/image.ref`, incluye ambos bancos y
las nuevas ejecuciones. La regresión completa aprobó formato, lint, catálogo,
**40 pruebas de infraestructura y 385 ejecuciones RTL**, sin fallos ni errores:
187 ejecuciones anteriores y las 198 del contenedor. Desde `/workspace/tp3`
también puede seleccionarse:

```bash
bash scripts/run_tests.sh \
  --test TEST-EXEC-001 --test TEST-EXEC-004 \
  --test TEST-EXEC-005 --test TEST-EXEC-006 --test TEST-EXEC-007 \
  --test TEST-EXEC-009 --test TEST-EXEC-010 --test TEST-PLAT-001 \
  --format json --reports-dir build/reports/execution-control/selected
```

`build/reports/execution-control/` conserva el log de regresión, la comprobación de
preservación del catálogo y verificaciones suplementarias: rechazo de las cinco
capacidades inválidas de `TEST-PLAT-001/C009–C013` sin elaborar la FSM, y lint de un
fixture con confirmaciones/próximos `valid` derivados de `cpu_cycle_fire` y
`drain_mode`. Estas verificaciones no agregan casos canónicos ni sustituyen hazards
o CPU reales. Los resultados y hashes del árbol comprobado se registran en
`build/reports/execution-control/context.json`.

Este bloque no cierra #8. Continúan pendientes Loader, Session Preparation y su
integración; CPU, UART, síntesis, timing y placa conservan sus comprobaciones propias.

## Evidencia local de Session Preparation — cuarto bloque de #8

`rtl/session_preparation.sv` implementa el recorrido de Interfaces §9.2. Su único
registro es `prepare_index`, cuyo ancho representa también `DMEM_CAPACITY_BYTES`
como centinela final. No agrega FSM, modo de sesión, copia de bitmap ni registro
de done. Reset y la salida de preparación rearman el índice en cero.

El primer flanco combina `prepare_init` y la limpieza de la marca cero. Cada
flanco posterior limpia una dirección distinta; al llegar a C se desactiva el
mantenimiento y se presenta `prepare_done`. El consumo de done ocupa un flanco
separado: C limpiezas más uno de finalización, sin espera adicional.

`tb/session_preparation_tb.sv` conecta el módulo con `execution_control` y Loader
reales. Modela los consumidores de inicialización —PC, RF, flags del pipeline y
marcas de DMEM— y una IMEM de cuatro palabras con escritura síncrona. Los datos
físicos de DMEM siguen el patrón `a mod 256` y deben conservarse, al igual que IMEM.
El contador observado es el recurso real de Execution Control. La captura de
fetch es un modelo local: no implementa IF, hazards ni ejecución de instrucciones.

Los estímulos y expectativas adicionales están en `inputs.prep_fixture` y
`expected.preparation`, conservando todos los datos y registros de ejecución
anteriores del catálogo. Las capacidades, conteos, palabras, residuos y destinos
proceden de esos campos. El recorrido se comprueba como un rango ordenado, sin
expandir miles de filas JSON por clock. El lector y ejecutor compartidos permanecen
sin cambios y se conservan los límites de cinco segundos por ejecución.

| IDs | Ejecución disponible | Alcance pendiente |
|---|---|---|
| `TEST-EXEC-002/C001`, `C004`, `C007`, `C010`, `C013`, `C016` | Unidad: 4, 28, 32, 36, 1000 y 2048 marcas, RF completo inicializado en el primer flanco aun con C menor que 32, índice/done y conservación de memorias físicas. | Consumidores de producción y coherencia CPU/Debug. |
| `TEST-EXEC-002/C016` | Integración local: LOAD de 16 bytes por Loader, última escritura, preparación real y publicación en READY con contador cero. | Controller, UART e IMEM de producción. |
| `TEST-EXEC-002/C017–C018` | Integración local: primera carga/preparación, terminal FINISHED/FAULT modelado y nueva preparación RUN/STEP conservando imagen; primer fetch modelado desde PC cero, contador uno y continuidad/retención posterior. | Confirmaciones de hazards, fetch y ejecución de CPU reales. No se ejecuta el halt de la imagen. |
| `TEST-EXEC-002/C019–C021` | Unidad e integración local: reset tras dos clears, supresión de mantenimiento y reinicio desde cero para READY/RUN/STEP. El fixture restaura fase e imagen tras reset sin escribir el índice del servicio. | En C021, las observaciones de Controller `WAIT_STEP_END`, respuesta, Debug y cancelación UART permanecen pendientes. |
| `TEST-PLAT-001/C004–C008` | Índice inclusivo en capacidades 4, 1000, 1024, 2048 y `2^32`; primer clear, inyección cerca del límite, último clear, done sin escritura y conservación del centinela. | No recorre `2^32` bytes ni reserva una memoria de ese tamaño. |

La inicialización y todos los clears excluyen `cpu_cycle_fire` y las escrituras de
Loader. En el flanco final, READY publica con contador cero; RUN y STEP permiten
su primer ciclo con contador uno y sin mantenimiento concurrente. El banco también
comprueba que done se conserve mientras el servicio siga activo y que la salida
de preparación rearme el índice para una sesión posterior.

Son **20 ejecuciones adicionales**: nueve de unidad del servicio, seis de
integración local y cinco de límites. El catálogo conserva 1363 casos canónicos;
229 tienen alguna ejecución disponible y 1134 permanecen pendientes. Una ejecución
local disponible no aprueba los niveles CPU/sistema del caso original.

### Reproducción y evidencia

Con la imagen exacta de `docker/image.ref`, `make check` incluye el nuevo módulo y
sus bancos. Verilator analiza Session Preparation como otra raíz RTL. Desde
`/workspace/tp3`, la selección local es:

```bash
bash scripts/run_tests.sh --test TEST-EXEC-002 --test TEST-PLAT-001 \
  --format json --reports-dir build/reports/session-preparation/selected
```

La regresión completa aprobó formato, lint, catálogo, **40 pruebas de
infraestructura y 428 ejecuciones RTL**, sin fallos ni errores: las 408 anteriores
y las 20 agregadas. REFERENCE y ALT_1000 requieren respectivamente 2049 y 1001
flancos hasta consumir done; son 40,98 µs y 20,02 µs en la simulación a 50 MHz,
sin constituir una verificación física de timing.

`build/reports/session-preparation/` conserva logs, comandos, comprobación de
preservación del catálogo y hashes de las fuentes en `context.json`. La prueba
suplementaria de las cinco capacidades inválidas de `TEST-PLAT-001/C009–C013`
exige `CONFIG_INVALID_CAPACITY` sin elaborar el índice de progreso; no agrega IDs.

Los tres módulos de sesión están implementados y conectados en el banco local.
La conexión en `processor_top`, memorias y CPU reales, transporte, síntesis, timing
y placa conservan sus obligaciones; esta evidencia no cierra por sí sola #8.

## Evidencia local del ciclo de vida de sesión

`tb/session_lifecycle_tb.sv` conecta Loader, Session Preparation y Execution
Control con su Global FSM real, sin inyectar estado en esos módulos. El banco
modela tamaño/progreso del Controller, escrituras síncronas IMEM, marcas/datos
DMEM, PC y RF. Lee las operaciones de `inputs.session_steps` y las expectativas
de `expected.session_steps`, conservando los campos originales del catálogo.

| IDs | Comprobación local | Alcance pendiente |
|---|---|---|
| `TEST-EXEC-003/C001–C004` | RUN continuo y un ciclo por STEP; contador retenido durante 50 clocks físicos entre pasos. Un stall del PC modelado consume igualmente una cuenta. | Ejecución de los programas lineal/load-use, RF terminal, hazards, snapshots y continuidad UART. |
| `TEST-EXEC-008/C001–C002` | Veinte ciclos sin confirmación terminal, continuidad de RUN hasta recibir reset y retorno a NO_IMAGE; RUN/STEP posteriores no autorizan ciclos. | Loop ejecutado por CPU, sincronización del botón, bytes y temporización de respuesta UART. |
| `TEST-EXEC-008/C003–C004` | Acciones de fault confirmadas desde el banco, causa/PC 1/4 y 2/0, transición a FAULT y retención terminal. | Detección de fetch fuera de imagen/instrucción ilegal y efectos precisos sobre RF. |

Las palabras de los programas se entregan por Loader, pero el banco no interpreta
instrucciones. En EXEC-003 suministra diez autorizaciones y después confirma halt;
esa traza no predice la latencia de la CPU. `terminal_cycle` entrega directamente
halt o una acción de fault ID y próximos valid vacíos; este banco no comprueba un
drain con instrucciones pendientes. Las modalidades de drain conservan sus bancos
de FSM/Execution Control y sus obligaciones de integración CPU.

En EXEC-008/C001 se modelan tres clocks adicionales antes de entregar el reset
funcional: RUN debe continuar durante ellos. No representan la duración UART ni
acreditan la coordinación con el último Stop de `RESET_ACCEPTED`. C002 entrega
directamente el reset funcional. Los resultados de RF originales, la detección
de faults y las respuestas de transporte permanecen pendientes en sus niveles.

Son ocho ejecuciones de control de sesión; el mismo banco agrega seis de
[reemplazo de imagen](memory.md#evidencia-local-del-reemplazo-de-imagen). Para
reproducir las 14 desde `tp3`, con la imagen de `docker/image.ref`:

```bash
bash scripts/run_tests.sh --test TEST-EXEC-003 --test TEST-EXEC-008 \
  --test TEST-MEM-008 --format json --reports-dir build/reports/session-audit/selected
```

El caso MEM-008/C007 de esa selección es una revisión documental fuera del runner.
Los resultados por ID/nivel, comandos y hashes están en
`build/reports/session-audit/`; el resumen de entrega se conserva en el PR.
