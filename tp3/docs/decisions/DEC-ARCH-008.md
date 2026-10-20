### DEC-ARCH-008 — Reset y enables

**Contrato vigente de consulta:** [execution_control](../architecture/session/execution_control.md), [reset_integration](../architecture/platform/reset_integration.md), [session_preparation](../architecture/session/session_preparation.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** CPU / Control global

**Fecha de aprobación:** 2026-09-22

**Contexto:** Debían fijarse los siguientes aspectos, sin convertir nombres explicativos en una FSM o interfaz RTL obligatoria:

- La semántica global de `reset`, `LOAD`, `RUN`, `STEP` y `HOLD`.
- Sus prioridades.
- Las condiciones conceptuales de avance y commit.
- El ownership exclusivo de memorias.
- Una vía mínima de recuperación para `RUN`.

Los acuerdos consolidados separan `reset` global de inicialización de sesión, adoptan aserción asíncrona y desaserción sincronizada para el `reset` distribuido, fijan su polaridad y alcance, descartan un debouncer obligatorio inicial, seleccionan `reset` como recuperación mínima, rechazan `LOAD` durante ejecución continua y definen ciclos efectivos, `HOLD`, preparación y commit de sesión. Conforme a `DEC-ARCH-006`, el contrato garantiza un único agente por memoria, evita stores o escrituras duplicadas y bloquea `LOAD`, `RUN` y `STEP` hasta cumplir sus precondiciones, dejando la realización concreta para implementación.

**Opciones consideradas:**

1. Sincronizar aserción y desaserción, o asertar asíncronamente y liberar de forma sincronizada.
2. Unificar `reset` global e inicialización de sesión, o mantenerlos conceptualmente separados.
3. Aceptar `LOAD` durante `RUN` como aborto implícito, o rechazarlo y disponer de recuperación explícita.
4. Exigir una FSM, grants y enables concretos, o fijar únicamente el contrato observable.
5. Incorporar un debouncer obligatorio, o dejarlo como acondicionamiento opcional basado en evidencia física.

**Decisión:** Se aprueba el siguiente contrato consolidado. La [revisión de control integrado y habilitaciones](#revisión-de-dec-arch-008--control-integrado-y-habilitaciones) actualiza las remisiones de realización y conserva las prioridades y condiciones de ciclo efectivo.

#### 1. Separación entre reset global e inicialización de sesión

El `reset` global y la inicialización de una nueva sesión serán mecanismos conceptualmente distintos.

##### Reset global

El `reset` global llevará al sistema a un estado seguro sin programa ejecutable confirmado ni sesión activa. Su alcance funcional concreto queda establecido por la sección 3.

El sistema deberá quedar en una condición que permita aceptar posteriormente una operación de carga. Reset global e inicialización de sesión continuarán siendo eventos distintos aunque compartan mecanismos internos.

##### Inicialización y commit de una nueva sesión

Una nueva sesión podrá prepararse sin aplicar el `reset` global completo. Recibir y validar la imagen completa no constituirá por sí solo una carga exitosa. Antes del commit deberán estar preparados coherentemente:

```text
imagen completa recibida y validada
PC = 0x00000000
x0 ... x31 = 0
pipeline sin instrucciones válidas
DMEM lógicamente en cero
conjunto lógico de memoria utilizada vacío
contador lógico de ciclo = 0
estado de ejecución preparado pero detenido
```

Desde la aceptación de `LOAD` y durante toda la recepción, validación y preparación se mantendrá:

```text
loaded_image_size_bytes = 0
image_valid = 0
```

El único write no nulo de `loaded_image_size_bytes` constituirá el commit completo de sesión y ocurrirá solo cuando la imagen y todo el estado inicial requerido estén preparados. `image_valid` pasará entonces a uno por derivación combinacional. Esta frontera deberá exponer un estado coherente, pero no fija el orden interno ni obliga a que toda la preparación ocurra en un único ciclo.

Una carga vacía, truncada, inválida, sobredimensionada, interrumpida o fallida después de su aceptación no producirá el commit. Una solicitud rechazada antes de ser aceptada conservará la imagen vigente. `RUN` y `STEP` no harán avanzar la CPU antes del commit, y completarlo no iniciará automáticamente ninguno de esos modos.

La inicialización de sesión podrá reutilizar mecanismos internos empleados también por `reset` sin ser conceptualmente equivalente a aplicar el `reset` global. No se exige borrar físicamente las memorias ni reiniciar recursos ajenos al estado lógico requerido. IMEM podrá conservar residuos fuera de la imagen confirmada y DMEM podrá conservar datos anteriores siempre que no sean lógicamente válidos para la nueva sesión.

##### Aspectos diferidos sin bloquear la decisión

Esta decisión no fija:

- pin o fuente física definitiva de `reset`;
- nombres de puertos, codificación binaria de estados y FSM privadas; la FSM global se rige por el acuerdo 44;
- duración u orden temporal interno de la preparación;
- mecanismo, paralelismo o señales de invalidación DMEM;
- secuencias RTL concretas de ownership, grants o enables;
- tratamiento temporal de colisiones internas;
- secuencia temporal precisa de fault, que corresponde a las decisiones de pipeline, hazards, control y protocolo.

Estos puntos son detalles de implementación, integración o decisiones dependientes y no impiden cerrar `DEC-ARCH-008`.

#### 2. Estrategia temporal del reset global

La fuente física de `reset` podrá cambiar de estado sin relación temporal con el clock principal. Cualquiera sea su polaridad eléctrica, el wrapper la normalizará a una solicitud conceptual activa en alto antes del sincronizador, denominada aquí `reset_request_async` solo con fines descriptivos.

La señal externa sin acondicionar no se distribuirá directamente a CPU, pipeline, control, enables ni otros registros funcionales. La cadena de `reset` se asertará asíncronamente y su liberación se sincronizará respecto del dominio funcional principal.

##### Sincronizador de referencia

La implementación de referencia utilizará una cadena de dos etapas o un mecanismo funcionalmente equivalente:

```systemverilog
(* ASYNC_REG = "TRUE" *) logic [1:0] reset_sync;

always_ff @(posedge clk or posedge reset_request_async) begin
    if (reset_request_async)
        reset_sync <= 2'b11;
    else
        reset_sync <= {reset_sync[0], 1'b0};
end

assign reset = reset_sync[1];
```

El código es ilustrativo. La sintaxis, el nombre de las señales y el atributo específico de herramienta serán detalles de implementación. El atributo no sustituirá la revisión de CDC ni las restricciones temporales correspondientes.

Partiendo de un estado desasertado conocido, una solicitud externa válida producirá conceptualmente:

```text
aserción:     00 -> 11, sin esperar un flanco
desaserción:  11 -> 10 -> 00
```

La aserción utilizará el recurso asíncrono de ambas etapas para llevar inmediatamente la cadena y el `reset` distribuido al estado activo. Al retirar la solicitud, el cero atravesará las dos etapas; así la desaserción solo ocurrirá como resultado de flancos activos y no expondrá directamente la liberación asíncrona a la lógica funcional.

Dos etapas constituirán la implementación de referencia mínima. Podrá utilizarse un mecanismo equivalente con latencia distinta si documenta y verifica aserción asíncrona y liberación sincronizada.

##### Consumo por la lógica funcional

CPU, pipeline y control consumirán el `reset` interno de forma síncrona:

```systemverilog
always_ff @(posedge clk) begin
    if (reset)
        state <= RESET_VALUE;
    else
        state <= next_state;
end
```

Los efectos funcionales ocurrirán en el flanco en que cada registro observe activo el `reset` interno. No se adoptará como política general un `reset` asíncrono en los registros funcionales del procesador.

El `reset` distribuido podrá asertarse entre flancos, pero sus efectos sobre CPU, pipeline y control ocurrirán en el primer `posedge clk` en el que cada registro funcional lo observe activo. La desaserción sincronizada evita liberar esos consumidores directamente desde una transición externa asíncrona.

##### Límites y aspectos diferidos a integración

El acondicionador no garantiza pulsos externos que incumplan el ancho mínimo del recurso asíncrono ni constituye por sí mismo un debouncer. La fuente externa deberá cumplir los requisitos eléctricos y temporales del dispositivo; el valor concreto dependerá del clock, dispositivo y placa y se documentará en integración. La inicialización física de los registros al configurar la FPGA no se utilizará como sustituto de un evento de `reset` válido.

La relación semántica entre estabilidad indicada por `locked` y solicitud/liberación de `reset` se fija en el acuerdo parcial de `DEC-ARCH-005`; su conexión y temporización concretas corresponden a integración física. Su acuerdo parcial de dominio funcional establece un único clock para la implementación inicial; introducir otro dominio interno exigiría revisar esa decisión y documentar su CDC.

Esta subdecisión define la estrategia temporal del `reset`. Los acuerdos siguientes fijan alcance, prioridad y recuperación; su realización RTL concreta permanece libre mientras preserve el contrato.

#### 3. Alcance funcional del reset global

Este acuerdo reemplaza únicamente el alcance mínimo del `reset` global que figuraba en la primera subdecisión. No modifica la separación entre `reset` e inicialización de sesión, el commit atómico de `LOAD` ni la estrategia de sincronización aprobada.

Los efectos siguientes se aplicarán en el flanco activo en el que la lógica funcional observe activo el `reset` distribuido; no se producirán directamente por una transición de la entrada física asíncrona.

##### Estado funcional obligatorio

Como mínimo, el `reset` global establecerá:

```text
PC                         = 0x00000000
x0 ... x31                 = 0
contador lógico de ciclo   = 0
IF/ID.valid                = 0
ID/EX.valid                = 0
EX/MEM.valid               = 0
MEM/WB.valid               = 0
estado de ejecución        = sin ejecución activa y sin imagen válida
loaded_image_size_bytes    = 0
image_valid                = 0, por derivación
control interno            = condición segura sin operaciones pendientes
```

No existirá una sesión activa después del `reset`. `RUN` y `STEP` no producirán ejecución válida hasta que un `LOAD` posterior complete la preparación y el commit de una nueva sesión.

##### Instruction Memory

El `reset` global no borrará obligatoriamente `Instruction Memory`. Las instrucciones físicas residuales no serán ejecutables porque `loaded_image_size_bytes = 0` y, por derivación, `image_valid = 0`. Un `LOAD` posterior escribirá la nueva imagen y solo su commit completo publicará nuevamente un tamaño no nulo.

##### Data Memory y metadata

El `reset` global no borrará obligatoriamente el array físico de datos de DMEM ni deberá preparar inmediatamente su cero lógico para una nueva sesión. Los datos y los metadatos podrán conservar residuos físicos, que no pertenecerán a una sesión ejecutable.

La inicialización de sesión deberá establecer antes de su commit la semántica según la cual todo byte todavía no escrito en esa sesión se lee como cero. La preparación podrá utilizar invalidación paralela, secuencial, una FSM de mantenimiento, tags de generación u otra técnica equivalente permitida por `DEC-ARCH-006`; este acuerdo no selecciona una.

El `reset` global no estará obligado a invalidar todos los metadatos DMEM en un único ciclo ni a utilizar esos metadatos como criterio de memoria utilizada por Debug.

##### Banco de registros y pipeline

Los registros arquitectónicos `x0` a `x31` quedarán lógicamente en cero. `x0` continuará siendo permanentemente cero independientemente del `reset`.

Los cuatro registros interetapa del pipeline quedarán lógicamente vacíos mediante sus bits de validez en cero. Los restantes campos podrán conservar bits físicos residuales y no se interpretarán como instrucciones activas mientras `valid = 0`.

##### Ejecución, control y Debug

El `reset` eliminará cualquier condición activa perteneciente a una ejecución anterior: `RUN`, `STEP` pendiente, drenado por `halt`, finalización normal, fault no persistente y `LOAD` parcial. Las FSMs y registros de control quedarán en estados seguros desde los cuales puedan aceptar las operaciones posteriores permitidas. Ninguna transacción anterior podrá producir efectos arquitectónicos después de que el `reset` funcional haya tomado efecto.

El acuerdo siguiente fija qué acción prevalece cuando `reset` coincide con otro enable. La estructura RTL concreta que implemente esa prioridad será un detalle de implementación, pero el estado observable posterior deberá satisfacer este contrato.

Debug deberá representar coherentemente el PC, banco de registros, contador, validez del pipeline, estado de ejecución y ausencia de imagen después del `reset`. Una operación o snapshot anterior no podrá presentarse sin distinción como estado actual. El valor, disponibilidad o interpretación del campo de memoria utilizada cuando no existe una sesión activa permanecerá pendiente para `DEC-SYS-005` y las decisiones de protocolo.

##### Diferencia respecto de la inicialización de sesión

El `reset` deja al sistema seguro, detenido y sin imagen ejecutable. La inicialización de sesión deberá además recibir y validar una imagen, preparar el cero lógico de DMEM y el criterio de memoria utilizada, y efectuar el commit que habilita posteriormente `RUN` o `STEP`. Podrá reutilizar parte de la lógica de `reset` sin ser equivalente a aplicarlo.

#### 4. Prioridad entre reset, LOAD y avance normal

Se adopta la siguiente prioridad conceptual global:

```text
1. RESET GLOBAL
2. LOAD ACEPTADO / PREPARACIÓN DE SESIÓN
3. CICLO EFECTIVO DE CPU
4. HOLD
```

Los nombres `session_init` y `cpu_enable` podrán utilizarse para explicar esta jerarquía, pero no serán señales RTL, puertos ni árboles físicos de enable obligatorios. Una FSM, enables distribuidos u otra realización equivalente será válida si preserva la misma semántica.

Este acuerdo global no imponía una estructura; el cuadragésimo cuarto acuerdo de `DEC-ARCH-003` selecciona posteriormente una FSM Moore de 14 estados y `Cycle Authorization` separado, sin alterar la jerarquía. En el flanco `PREPARING_RUN/STEP && prepare_done`, la preparación **ya concluyó antes del flanco** y no realiza escrituras concurrentes, por lo que corresponde a la clase ciclo CPU efectivo.

##### Prioridad de reset global

Reset dominará cualquier `LOAD`, mantenimiento, ciclo de CPU o `HOLD` coincidente. En el flanco dominado por `reset`:

- el estado alcanzará los valores definidos por el acuerdo de alcance funcional;
- no se aceptará ni confirmará un `LOAD`;
- un `LOAD` previamente aceptado quedará abandonado;
- no se escribirá un tamaño de imagen no nulo;
- ninguna instrucción, escritura del loader ni operación de mantenimiento producirá un nuevo efecto.

Reset es además la vía mínima obligatoria de recuperación invocable durante `RUN` definida en el acuerdo consolidado posterior.

##### LOAD aceptado y preparación de sesión

La segunda clase comenzará únicamente cuando una solicitud `LOAD` haya sido aceptada y abarcará:

```text
recepción de la imagen
reconstrucción y escrituras de IMEM
validación de la imagen
preparación lógica de DMEM
preparación del restante estado inicial
commit completo o fallo
```

Una solicitud `LOAD` no será aceptada mientras ya exista contexto de ejecución continua, incluido su drenado automático. Una solicitud rechazada no entra en esta clase, no invalida por sí sola la imagen vigente y no suprime el avance normal de `RUN`.

Una vez aceptado `LOAD`, ninguna solicitud `RUN` o `STEP` producirá un ciclo efectivo de CPU. No ocurrirán writebacks, stores ni incrementos del contador pertenecientes a la ejecución anterior. Loader y mantenimiento podrán progresar mediante sus propios enables y ownership, independientes de la autorización de avance del CPU.

Solo el commit completo terminará exitosamente esta clase y publicará un valor no nulo de `loaded_image_size_bytes`. Un fallo la terminará sin sesión válida y sin habilitar avance de CPU.

##### Ciclo efectivo de CPU

Un ciclo efectivo solo podrá autorizarse cuando exista una sesión confirmada y el control se encuentre en `RUN`, ante un `STEP` aceptado o en drenado habilitado conforme al modo de ejecución vigente.

En `RUN` podrán autorizarse ciclos sucesivos. Cada `STEP` aceptado autorizará exactamente un ciclo, incluso durante drenado. En drenado continuo los ciclos progresarán automáticamente; en drenado paso a paso continuará requiriéndose un `STEP` por ciclo, conforme a `DEC-SYS-001`.

La autorización global de un ciclo no obliga a actualizar todos los elementos del pipeline. Un stall seguirá siendo un ciclo efectivo y contará una vez aunque la lógica local retenga PC o registros interetapa, inserte una bubble o permita avanzar solo un subconjunto. La política concreta de enables locales, forwarding, stalls, bubbles y flushes corresponde a `DEC-ARCH-003`.

Los writebacks, stores y actualizaciones de metadatos originados por CPU deberán quedar cualificados por el ciclo efectivo y por la validez local correspondiente. Ninguno podrá repetirse por cada flanco físico durante una espera ni comprometerse más de una vez por el mismo avance lógico.

El cuadragésimo tercer acuerdo de `DEC-ARCH-003` fija después `rf_write_fire`, `dmem_store_fire`, `dmem_metadata_write_fire`, `fault_capture_fire` y `cycle_counter_increment=cpu_cycle_fire`. El cuadragésimo cuarto **revisa** sus escrituras registradas de `terminal_kind`/`drain_auto`, reemplazándolas por transiciones de FSM, y fija en un bloque separado la autorización de `cpu_cycle_fire`. Conserva commits anteriores válidos ante fronteras jóvenes y enables propios de loader/mantenimiento.

El contador lógico incrementará exactamente una vez por cada ciclo efectivo, incluidos stalls habilitados y drenado, y no por actividad exclusiva de UART, loader o mantenimiento.

##### HOLD

Cuando no exista `reset`, `LOAD` aceptado ni ciclo efectivo, el plano de ejecución CPU se encontrará en `HOLD`. PC, registros interetapa, estado asociado al avance y contador conservarán su valor, sin writebacks, stores ni otros commits originados por CPU.

La sección siguiente precisa qué estado queda congelado, qué actividad externa puede continuar y desde qué situaciones resulta legal autorizar posteriormente otro ciclo.

##### Clock principal

La jerarquía se implementará mediante selección de próximo estado y enables síncronos. No se detendrá, gateará arbitrariamente ni generará manualmente el clock principal para implementar `RUN`, `STEP`, `LOAD` o `HOLD`. Ninguna de estas condiciones detendrá el clock cuando el generador proporcione flancos válidos; la pérdida de estabilidad se trata por `reset` global según `DEC-ARCH-005`.

#### 5. Semántica de HOLD y actividad permitida

Dentro de la clase de menor prioridad, `HOLD` será la condición en la que no ocurre un ciclo efectivo del CPU. Reset y `LOAD` aceptado tampoco producen ciclos CPU, pero conservan sus semánticas propias y no se reclasifican como `HOLD`. No será obligatorio representar `HOLD` mediante un modo RTL específico ni mediante una señal global denominada `cpu_enable = 0`.

##### Plano de ejecución congelado

Mientras no exista una acción de mayor prioridad ni un ciclo efectivo autorizado, conservarán su valor:

```text
PC
banco de registros arquitectónicos
IF/ID
ID/EX
EX/MEM
MEM/WB
contador lógico de ciclo
estado microarquitectónico cuyo progreso pertenece al CPU
progreso de drenado
estado de fault o finalización ya alcanzado
```

Durante `HOLD` no se capturará una instrucción nueva, no avanzará el pipeline y no se reconocerá ni progresará un nuevo evento de `halt`, fault o drenado. Tampoco se producirán writebacks, stores, actualizaciones de metadatos originadas por CPU ni incrementos del contador.

Una instrucción podrá permanecer retenida en una etapa con un efecto pendiente, pero no lo repetirá durante los clocks físicos de espera. Cuando posteriormente se autorice un ciclo legal, el efecto podrá comprometerse una sola vez conforme a su validez y enable local.

##### Plano de control activo

El congelamiento anterior no se aplicará indiscriminadamente al plano de control externo. Mientras el CPU permanece sin avance podrán continuar:

- acondicionamiento del `reset`;
- UART RX y UART TX;
- recepción y decodificación de comandos;
- control necesario para aceptar un `RUN` o `STEP` legal o para evaluar una solicitud `LOAD`;
- captura, almacenamiento auxiliar y serialización de Debug;
- respuestas y demás lógica externa al avance del pipeline.

Estos cambios no constituirán ciclos efectivos ni incrementarán el contador. Si se acepta una acción de mayor prioridad o se autoriza un ciclo legal, el sistema abandonará `HOLD` y aplicará la clase correspondiente de la jerarquía global.

El acceso Debug continuará sujeto a coherencia y ownership. Su actividad deberá preservar el estado funcional observado conforme a esos contratos.

##### Memorias y lógica combinacional

No se exigirá que las señales combinacionales permanezcan físicamente constantes. IMEM, DMEM, ALU, comparadores, muxes, forwarding y detección de hazards podrán continuar evaluándose.

Las lecturas combinacionales de memoria podrán permanecer activas, pero ninguna evaluación producirá nuevo estado secuencial ni efectos arquitectónicos sin ciclo efectivo y validez local. En particular, un store retenido no volverá a escribir DMEM en cada flanco físico.

##### STEP, contador y Debug

Desde un estado legalmente reanudable, cada `STEP` aceptado autorizará exactamente un ciclo efectivo. Después de ese ciclo no se autorizará otro sin un nuevo `STEP`, salvo una transición válida a `RUN` u otra condición ya aprobada.

Durante drenado paso a paso seguirá siendo necesario un `STEP` por ciclo. La captura y transmisión posterior del snapshot no generarán avances adicionales. El contador permanecerá estable durante `HOLD` e incrementará una vez por cada ciclo efectivo autorizado, incluidos stalls y drenado.

##### Reanudación y estados no reanudables

Un sistema preparado para ejecutar o una espera de `STEP` podrá continuar desde el mismo estado CPU cuando el control autorice legalmente el siguiente ciclo. El tiempo físico transcurrido en `HOLD` no alterará la semántica del programa.

El acuerdo 44 de `DEC-ARCH-003` fija `RESET` > `LOAD` > `STEP` > `RUN` entre comandos elegibles. `LOAD` se admite desde `NO_IMAGE`, `READY`, `STEPPING`, `HALT_DRAIN_STEP`, `FAULT_DRAIN_STEP`, `FINISHED` y `FAULT`; se rechaza en `RUNNING` y drenado AUTO sin inhibir el ciclo vigente. `RUN`/`STEP` aceptados en `FINISHED`/`FAULT` preparan una sesión nueva y limpia con la imagen confirmada mediante `PREPARING_RUN`/`STEP`; no reanudan la sesión terminal. Sin imagen no se autoriza ejecución. Las respuestas y el formato UART se definen en el [protocolo](../protocol.md); la elegibilidad interna no implica admisión UART durante el intercambio en curso.

Esta semántica no introduce comandos PAUSE o RESUME. El [protocolo UART](../protocol.md#estado-cpu-y-fase-de-transporte) admite durante `RUN` efectivo únicamente `RESET`, tras completar `ACCEPTED` y la preparación. Un byte `LOAD`, `RUN`, `STEP`, `CHECK_READY` o desconocido en esa fase inicia recuperación RX sin respuesta ni solicitud a la Global FSM; la ejecución y la imagen vigente se conservan. La reprogramación requiere recuperar primero el transporte y completar el intercambio en curso o aplicar reset.

#### 6. Semántica de ciclo lógico

`cpu_enable` será un nombre conceptual para el evento final que autoriza exactamente un ciclo lógico del procesador. Podrá denominarse descriptivamente `cpu_cycle_fire`, pero ninguno de ambos nombres constituirá una señal RTL o un puerto obligatorio.

Conceptualmente, el evento final solo podrá existir después de resolver la prioridad global:

```text
sin reset activo
AND sin LOAD aceptado en progreso
AND sesión confirmada
AND modo de ejecución autoriza un ciclo
-> exactamente un ciclo lógico de CPU
```

Una solicitud preliminar de `RUN` o `STEP` no será por sí sola un ciclo. Si coincide con `reset`, `LOAD` aceptado o una condición no ejecutable, no existirá evento final, no avanzará el CPU y no incrementará el contador. Las respuestas a solicitudes UART admitidas y el descarte de tráfico fuera de fase se definen en el [protocolo](../protocol.md#estado-cpu-y-fase-de-transporte).

La ausencia del evento final tampoco implicará siempre `HOLD`: `reset`, `LOAD` aceptado y preparación efectiva aplican sus clases superiores. Las escrituras efectivas de preparación inhiben ciclos CPU. `prepare_active` identifica el modo; en `PREPARING_RUN`/`STEP` con `prepare_done`, la preparación ya terminó antes del flanco y no hay writes de mantenimiento/Loader concurrentes: ese flanco ejecuta el primer ciclo CPU y deja `cycle_count=1`. `PREPARING_READY` con `prepare_done` publica la sesión y queda `READY` sin ciclo CPU. Solo cuando no exista una acción superior se aplicará la semántica de `HOLD` acordada.

##### Stalls, bubbles y flushes

Un stall interno ocurrido dentro de un ciclo autorizado no cancelará ese ciclo:

```text
stall dentro de ciclo efectivo != HOLD
```

El ciclo contará aunque PC o algunos registros interetapa queden retenidos o se inserten bubbles/flushes. Los patrones vigentes son los aprobados en `DEC-ARCH-003`, acuerdo 47.

La autorización global definirá que existe una transición lógica; los enables locales decidirán qué elementos cambian durante ella. El control está fijado en `DEC-ARCH-003`, acuerdos 40–47: eventos, ocho acciones, próximo estado, efectos, autorización e integración; la matriz 46 está revisada por el 47. Resta implementar y verificar RTL conforme a ese contrato.

##### RUN, STEP y drenado

`RUN` autorizará eventos finales sucesivos mientras la ejecución deba continuar. Un `STEP` válido y aceptado autorizará exactamente uno. `STEP` significará un ciclo del procesador, no la finalización de una instrucción completa.

Si el ciclo autorizado contiene un stall, el `STEP` se considerará consumido y el contador incrementará una vez. Para otro ciclo será necesario un nuevo `STEP`, salvo una transición válida a `RUN`.

Después de reconocer un `halt` válido, el drenado requerirá ciclos efectivos. En `RUN` progresará automáticamente ciclo a ciclo; en `STEP` requerirá una nueva orden por ciclo. El pipeline no drenará durante `HOLD`.

##### Contador lógico

En operación normal se cumplirá:

```text
evento final de ciclo = 1 -> contador incrementa exactamente uno
evento final de ciclo = 0 -> contador conserva su valor
```

Reset e inicialización de sesión serán acciones de mayor prioridad que establecen el contador en cero sin constituir ciclos CPU.

Los ciclos efectivos con stalls, bubbles, flushes, invalidaciones o drenado contarán. Los ciclos del clock funcional con actividad exclusiva de UART, Debug, loader o mantenimiento no contarán. `cycle_count[63:0]` es unsigned e incrementa módulo `2^64` por `cpu_cycle_fire`, sin fault, cambio de `global_state`, detención ni flag adicional; el formato UART permanece pendiente conforme a la revisión de `DEC-SYS-006` del 2026-09-26.

#### 7. Generación desde RUN, STEP y drenado

La solicitud conceptual de un ciclo se obtendrá a partir de una autorización continua o de un `STEP` válido y aceptado:

```text
solicitud de ciclo = autorización continua OR STEP aceptado

evento final de ciclo =
    solicitud de ciclo
    AND sin prioridad de reset o LOAD aceptado/preparación
    AND sesión confirmada
    AND estado ejecutable
```

Las expresiones anteriores son semánticas. `run_active`, `step_pulse`, autorización continua, `cpu_enable` y `cpu_cycle_fire` no serán nombres obligatorios de estados, señales ni puertos RTL.

El cuadragésimo cuarto acuerdo de `DEC-ARCH-003` adopta después `cpu_cycle_fire` como señal combinacional de `Cycle Authorization` y sustituye el registro histórico `drain_auto` por estados globales AUTO/`STEP`, sin convertir esta expresión conceptual en un permiso para comprometer efectos CPU durante preparación efectiva.

##### Autorización continua

Un `RUN` válido desde una sesión preparada establecerá un contexto de avance continuo. Mientras la ejecución normal deba continuar, ese contexto solicitará ciclos sucesivos sin nuevos comandos.

Cuando se reconozca un `halt` válido, dejarán de admitirse instrucciones nuevas y el estado observable podrá pasar a DRAINING. Si el `halt` fue reconocido bajo contexto continuo, se conservará autorización automática para los ciclos de drenado sin exigir que el estado siga denominándose `RUN` ni que exista un flag `run_active` concreto.

El **avance normal** cesará al confirmar una frontera terminal de `halt` o fault, o ante una acción superior o intervención válida. Si el fault se confirma en un ciclo bajo contexto continuo, las anteriores aún válidas conservarán autorización de drenado automático hasta `FAULT` conforme a `DEC-ARCH-004`; el trigésimo sexto acuerdo de `DEC-ARCH-003` había fijado `drain_auto` para recordar ese origen; el cuadragésimo cuarto **sustituye** ese registro por estados `FAULT_DRAIN_AUTO/STEP`. Si se confirmó por `STEP`, cada ciclo posterior requiere otro `STEP` aceptado, salvo conversión por `RUN` aceptado. Ninguna de estas condiciones autoriza un ciclo durante `HOLD`, `reset` o `LOAD` aceptado. El cuadragésimo cuarto acuerdo precisa que `PREPARING_RUN/STEP && prepare_done` sí autoriza el primer ciclo en ese mismo flanco **solo** si la preparación ya terminó previamente y no hay escrituras de mantenimiento/Loader concurrentes.

##### STEP aceptado

Un `STEP` solo solicitará un ciclo si es válido, fue aceptado y el sistema se encuentra en un estado legalmente reanudable. Cada aceptación producirá exactamente una solicitud y no permanecerá activa durante clocks posteriores.

Si el ciclo contiene stall, bubble, flush o invalidación, el `STEP` igualmente quedará consumido. En drenado bajo control paso a paso no existirá autorización automática: cada ciclo requerirá un nuevo `STEP`.

Una solicitud `STEP` suprimida, rechazada o coincidente con `reset` o `LOAD` aceptado/preparación efectiva con writes no generará un evento CPU ni quedará diferida implícitamente para ejecutarse al retirar la prioridad. La respuesta externa, cuando el transporte admite el comando, se define en el [protocolo](../protocol.md#estado-cpu-y-fase-de-transporte).

##### HOLD y condición del pipeline

Sin autorización continua ni `STEP` aceptado, y sin acción superior, el plano CPU permanecerá en `HOLD`. La existencia de instrucciones válidas en el pipeline no autorizará por sí sola un ciclo.

DRAINING describirá una condición del pipeline, no una fuente autónoma de avance. El contexto continuo o un `STEP` aceptado determinarán si progresa. Del mismo modo, stall, bubble, flush e invalidación describirán qué sucede dentro de un ciclo ya autorizado y no generarán autorización global.

##### FINISHED y fault

`FINISHED` se alcanzará únicamente después de reconocer un `halt` válido y vaciar completamente el pipeline. Eliminará la autorización de la sesión terminada; `RUN`/`STEP` elegibles preparan una sesión nueva mediante `PREPARING_RUN`/`STEP` conforme al acuerdo 44.

Un fault confirmado impedirá ciclos normales posteriores y permanecerá distinguible de `FINISHED`. `DEC-ARCH-004` fija después que las anteriores supervivientes completen durante el drenado, con ciclos efectivos automáticos si la confirmación ocurrió bajo contexto continuo o con un `STEP` nuevo por ciclo si ocurrió en paso a paso; `DEC-ARCH-003` precisa las transiciones de registros interetapa y la representación terminal sin modificar la prioridad global aquí aprobada.

Reset y `LOAD` aceptado dominarán cualquier autorización continua o `STEP`. Una solicitud coincidente no contará, no incrementará el contador y no se convertirá en un ciclo latente.

#### 8. Secuencia conceptual de inicialización de sesión

La secuencia siguiente describe la sesión iniciada por `LOAD`. `RUN`/`STEP` desde `FINISHED`/`FAULT` también preparan una sesión nueva, reutilizando la imagen confirmada, conforme al acuerdo 44. La preparación por `LOAD` es potencialmente multiciclo entre aceptación y commit o fallo:

```text
LOAD aceptado
      -> invalidar imagen confirmada
      -> impedir ciclos CPU
      -> recibir, validar y escribir la nueva imagen
         junto con la preparación del estado de sesión
      -> commit completo o fallo
```

Esta secuencia es conceptual y no obliga a utilizar una FSM, estado o señal RTL denominada `session_init`.

##### Aceptación de LOAD

En el flanco en que `LOAD` sea aceptado se escribirá:

```text
loaded_image_size_bytes = 0
```

`image_valid` pasará a cero exclusivamente por derivación combinacional. La imagen anterior dejará de ser ejecutable y no habrá eventos finales de ciclo CPU hasta terminar el procedimiento. Una solicitud `LOAD` rechazada conservará por sí sola la sesión e imagen vigentes.

`LOAD` no podrá aceptarse mientras ya exista contexto de ejecución continua, incluido el drenado automático iniciado por `RUN`. Una vez aceptado desde una condición permitida, se aplicará la prioridad ya acordada sobre cualquier solicitud de avance.

##### Preparación multiciclo

Durante la fase podrán realizarse, en paralelo o secuencialmente:

- recepción, reconstrucción, validación y escrituras de la nueva imagen en IMEM;
- preparación del cero lógico de DMEM;
- puesta a cero del banco de registros;
- invalidación del pipeline;
- preparación de `PC = 0x00000000`;
- puesta a cero del contador lógico;
- eliminación de estados de ejecución no persistentes;
- preparación del conjunto lógico de memoria utilizada y demás metadatos de sesión.

No se fija el orden físico interno, paralelismo, FSM privadas ni cantidad de ciclos; la FSM global y su autorización siguen el acuerdo 44. El contenido parcial ya escrito en IMEM y cualquier estado parcialmente preparado carecerán de semántica de sesión ejecutable mientras el tamaño confirmado permanezca en cero.

UART, loader y mantenimiento podrán progresar con sus propios enables. El pipeline no avanzará como ejecución, no se incorporarán instrucciones y no se comprometerán efectos de la sesión anterior.

##### Commit completo

Antes del commit deberán estar preparados coherentemente:

```text
imagen completa recibida, validada y escrita
PC = 0x00000000
x0 ... x31 = 0
pipeline sin instrucciones válidas
DMEM lógicamente en cero
conjunto lógico de memoria utilizada vacío
contador lógico de ciclo = 0
estado de ejecución inicial y detenido
```

Solo entonces el único write no nulo de `loaded_image_size_bytes` publicará el tamaño de la nueva imagen. `image_valid` pasará a uno por derivación; no se publicará ni almacenará como un estado persistente independiente.

El commit expondrá una frontera coherente de sesión, pero no exige que todas las tareas de preparación ocurran en ese mismo ciclo. El cuadragésimo cuarto acuerdo de `DEC-ARCH-003` lo ubica en `PREPARING_READY && prepare_done`: termina la carga sin ciclo CPU; después el sistema queda preparado y sin eventos CPU hasta recibir posteriormente un `RUN` o `STEP` válido. `READY` es un estado de la FSM global del acuerdo 44; `HOLD` describe ausencia de ciclo efectivo y no añade un estado.

##### Fallo, nueva tentativa y reset

Una carga vacía, incompleta, inválida, sobredimensionada, interrumpida o fallida no producirá commit. `loaded_image_size_bytes` permanecerá en cero y no existirá sesión ejecutable.

No se restaurará la imagen anterior ni se hará rollback del estado parcialmente preparado. Sus residuos físicos carecerán de validez de sesión. Una nueva solicitud válida podrá reiniciar el procedimiento completo.

Si `reset` ocurre durante cualquier fase, dominará la operación, impedirá nuevos writes de loader o mantenimiento en el flanco correspondiente y dejará el sistema en el estado global sin imagen definido anteriormente.

Los punteros, contadores y flags de progreso interno no constituirán evidencia de sesión confirmada. La única publicación persistente de una imagen ejecutable será el write no nulo del tamaño al commit completo.

#### 9. Convención de polaridad del reset

Toda solicitud y señal conceptual de `reset` utilizada dentro del diseño será activa en alto:

```text
reset = 1 -> reset solicitado o activo
reset = 0 -> funcionamiento normal
```

La polaridad eléctrica del pin o fuente física no formará parte del contrato interno. Una fuente activa en bajo se invertirá una única vez en el wrapper o top-level; una fuente activa en alto no requerirá inversión. Los módulos funcionales no dependerán de esa elección de placa.

La cadena conceptual será:

```text
pin o fuente física
        -> normalización única de polaridad en wrapper
        -> solicitud asíncrona normalizada activa en alto
        -> acondicionador con aserción asíncrona y desaserción sincronizada
        -> reset distribuido activo en alto
           (aserción asíncrona / desaserción sincronizada)
        -> consumo síncrono por CPU, pipeline y control
```

La normalización de polaridad no modificará la estrategia temporal aprobada: la solicitud válida asertará inmediatamente la cadena y el `reset` distribuido, mientras que su desaserción atravesará las dos etapas. Los registros funcionales seguirán aplicando los efectos de `reset` únicamente en `posedge clk`.

##### Nomenclatura

No se exigirá que todos los puertos o señales se denominen literalmente `reset`. Podrán utilizarse nombres inequívocos como `reset`, `rst`, `reset_request_async` u otros equivalentes si su semántica está documentada y permanece activa en alto.

El sufijo `_n` se reservará para señales activas en bajo, normalmente limitadas a la frontera física. No se permitirá que una misma señal interna sea interpretada con polaridades distintas por módulos diferentes.

Nombres como `reset_button_n` serán válidos para puertos físicos activos en bajo, pero deberán normalizarse antes de alcanzar el sincronizador y nunca se propagarán como convención funcional del CPU.

##### Aspectos de integración todavía abiertos

La convención interna queda cerrada. Permanecen para integración la selección del pin o fuente física, duración mínima y realización concreta de la relación con una eventual señal `locked` de generación de clock, definida semánticamente en `DEC-ARCH-005`.

#### 10. Rebotes y requisitos de la entrada física de reset

La implementación inicial no incorporará obligatoriamente un eliminador de rebotes digital dedicado para `reset`. Después de normalizar una única vez su polaridad, la entrada física alimentará el acondicionador ya aprobado:

```text
entrada física
        -> normalización única de polaridad
        -> solicitud asíncrona normalizada activa en alto
        -> aserción asíncrona / desaserción sincronizada en dos etapas
        -> reset distribuido activo en alto
           (aserción asíncrona / desaserción sincronizada)
        -> consumo funcional síncrono
```

El sincronizador resuelve el cruce de dominio de la solicitud asíncrona, pero no será presentado ni verificado como debouncer. Reset será una condición de nivel y no un evento que deba contabilizar exactamente una transición por pulsación.

##### Comportamiento permitido ante rebotes

Sin un filtro dedicado, una aserción física válida podrá activar la cadena sin esperar a ser muestreada por un flanco. Un pulso que no satisfaga el ancho mínimo del recurso asíncrono quedará fuera del contrato. Los rebotes podrán prolongar el `reset` interno, impedir temporalmente su liberación o producir una liberación sincronizada seguida de una nueva aserción asíncrona.

No se garantizará que todos los rebotes se reduzcan a un único intervalo continuo de `reset`. Toda nueva aserción que alcance el `reset` distribuido volverá a aplicar íntegramente el contrato de `reset` global y no constituirá una operación arquitectónica distinta.

##### Requisito de integración

La fuente externa deberá cumplir los requisitos eléctricos y temporales del dispositivo, incluido el ancho mínimo aplicable al recurso de aserción asíncrona. Pulsos arbitrariamente cortos quedarán fuera del contrato.

La duración concreta se expresará en tiempo o ciclos al definir clock, dispositivo, placa y constraints. El procedimiento de arranque y uso deberá esperar a que el `reset` se haya estabilizado antes de enviar comandos funcionales. La confiabilidad del mecanismo físico se validará repetidamente sobre la FPGA real.

##### Revisión futura basada en evidencia

Si la validación física demuestra un comportamiento inaceptable, podrá añadirse un filtro o debouncer en el wrapper de integración. No se fija ahora su realización ni su ubicación exacta respecto del sincronizador; dependerán del mecanismo seleccionado y requerirán el análisis CDC correspondiente.

Esa incorporación no modificará la polaridad conceptual activa en alto, la aserción asíncrona y desaserción sincronizada del `reset` distribuido, el consumo funcional síncrono, el alcance y prioridad del `reset` ni la ausencia de ciclos CPU durante su aplicación. Por ello será un detalle de integración y no una obligación arquitectónica inicial.

#### 11. Aceptación de LOAD durante ejecución continua

Una solicitud `LOAD` no será aceptada mientras ya exista un contexto de ejecución continua:

```text
contexto continuo activo
        + solicitud LOAD
        -> LOAD rechazado
        -> ejecución vigente continúa
```

La condición es semántica y no exige un estado o señal RTL denominado `RUN` o `run_active`. Incluye la ejecución normal y el drenado automático iniciado por `RUN` después de reconocer un `halt`, aunque el estado observable se denomine DRAINING. El rechazo se mantendrá mientras subsista esa autorización continua, hasta `FINISHED`, fault o una intervención externa válida según las prioridades fijadas en el acuerdo 44.

##### Efectos del rechazo

Una solicitud rechazada durante contexto continuo no deberá:

- modificar `loaded_image_size_bytes` ni su derivación `image_valid`;
- escribir IMEM ni transferir su ownership al loader;
- iniciar recepción, preparación lógica de DMEM o cualquier otra inicialización de sesión;
- modificar por sí misma PC, registros, pipeline, contador o estado de ejecución;
- introducir stall, bubble, flush, pausa, fault o finalización;
- cancelar la autorización continua ni su drenado.

La invalidación inmediata de la imagen anterior y la prioridad sobre el avance CPU se aplicarán únicamente a partir de una aceptación efectiva. Una mera solicitud rechazada no tendrá prioridad sobre el ciclo CPU que corresponda y no quedará latente para aceptarse automáticamente al terminar `RUN`; será necesaria una nueva solicitud válida.

##### Ownership y ausencia de aborto implícito

Durante el contexto continuo, la CPU conservará el flujo funcional de IMEM. El loader no obtendrá grant ni write enable y no podrá comenzar una nueva imagen. `LOAD` no constituirá un mecanismo implícito para pausar, abortar o recuperar `RUN`.

La recuperación mínima durante `RUN` será el `reset` global definido por el acuerdo consolidado siguiente. El [protocolo UART](../protocol.md#reset-desde-pc) concreta su invocación desde PC; `LOAD` no asume implícitamente esa función.

##### Fronteras delegadas a protocolo y control

El [control global](../architecture/session/execution_control.md#tabla-de-transiciones) fija `RESET` > `LOAD` > `STEP` > `RUN` entre comandos elegibles. Una solicitud interna `LOAD` es elegible desde `NO_IMAGE`, `READY`, `STEPPING`, `HALT_DRAIN_STEP`, `FAULT_DRAIN_STEP`, `FINISHED` y `FAULT`; se rechaza en `RUNNING` y drenado AUTO sin inhibir el ciclo vigente. `RUN`/`STEP` aceptados en `FINISHED`/`FAULT` preparan una sesión nueva y limpia con la imagen confirmada mediante `PREPARING_RUN`/`STEP`; no reanudan la sesión terminal. Sin imagen no se autoriza ejecución. Esta elegibilidad interna no obliga al Controller a interpretar esos comandos UART: el [protocolo](../protocol.md#tráfico-fuera-de-fase-durante-run) define el descarte y la recuperación sin respuesta durante `RUN`.

La elegibilidad interna y la admisión UART son contratos distintos: la Global FSM decide sobre las solicitudes que recibe; el Controller decide qué bytes interpreta y cuándo presenta una solicitud.

#### 12. Reset global como recuperación mínima durante RUN

El `reset` global será la vía mínima obligatoria de recuperación externa para abandonar una ejecución `RUN` activa o no terminante. Podrá invocarse durante ejecución normal o drenado continuo y, por su máxima prioridad, no esperará `halt` ni el vaciado del pipeline.

Cuando la lógica funcional observe activo el `reset` distribuido:

- se abortarán `RUN`, `STEP` pendiente y drenado;
- el pipeline quedará inválido y no se admitirán efectos arquitectónicos posteriores de la ejecución abandonada;
- se cancelarán `LOAD` parcial, fault no persistente, finalización y operaciones pendientes conforme al alcance global ya aprobado;
- `loaded_image_size_bytes` quedará en cero e `image_valid` en cero por derivación;
- PC, banco de registros, contador y control alcanzarán los valores de `reset` definidos;
- el sistema quedará detenido, sin sesión ejecutable y capaz de aceptar posteriormente un nuevo `LOAD`.

La recuperación por `reset` constituirá un aborto externo, no `FINISHED` ni finalización normal. No activará `program_finished`, `DONE` ni ningún indicador reservado para un `halt` válido seguido de drenado completo. Los efectos ya comprometidos antes de que el `reset` funcional tome efecto pertenecen a la ejecución anterior; ningún efecto pendiente se comprometerá después.

`LOAD` continuará rechazándose mientras exista contexto continuo y no será una vía implícita de aborto. Después del `reset` será necesaria una nueva solicitud `LOAD` válida; una solicitud rechazada durante `RUN` no quedará latente.

Esta garantía satisface la recuperación mínima exigida por `REQ-EXEC-015`. [DEC-PROTO-002](DEC-PROTO-002.md) expone `RESET` por UART. Su reconocimiento depende de la fase de transporte: si el terminal `RUN` ya es observable, prevalece y se descarta ese byte; si se reconoce `RESET` antes, se cancela la respuesta terminal pendiente, se transmite `RESET/ACCEPTED` y después de su último Stop se solicita el reset global. La CPU puede seguir ejecutando hasta que se aplique el reset. El botón físico conserva su acción directa mediante el [acondicionamiento de reset](../architecture/platform/reset_integration.md).

##### Realización RTL no prescrita

> **Realización revisada por el [control integrado](#revisión-de-dec-arch-008--control-integrado-y-habilitaciones) (2026-10-16).** La organización de la FSM y sus puertos se concreta mediante el acuerdo 48 de `DEC-ARCH-003` y las especificaciones consolidadas.

La decisión fija semántica, prioridades, ownership y condiciones de enable. La FSM global de 14 estados, aceptación de comandos y autorización separada están fijadas por el acuerdo 44 de `DEC-ARCH-003`. Quedan libres la codificación binaria, nombres de puertos, FSM privadas, owners/grants, paralelismo físico de preparación e invalidación DMEM, respetando los enables y transiciones aprobados.

La implementación materializará la FSM global aprobada y sus enables; la organización de submódulos es libre dentro del contrato. Deberá preservar el contrato observable, exclusión de ownership, atomicidad del commit y ausencia de escrituras duplicadas. Los contratos se distribuyen entre estos ámbitos:

| Ámbito                       | Responsabilidad                                                                |
|------------------------------|--------------------------------------------------------------------------------|
| `DEC-ARCH-003`               | Patrones locales de hazards                                                    |
| Acuerdos 40–47 ya aprobados  | Secuencia CPU de faults                                                        |
| Protocolo                    | Reporte externo de faults                                                      |
| Integración y `DEC-ARCH-005` | Pin, duración mínima concreta y realización física de la relación con `locked` |

**Aspectos diferidos:**

- Pin o fuente física y duración mínima concreta de `reset`.
- Realización física de la relación con `locked` fijada semánticamente en `DEC-ARCH-005`.
- Realización RTL de estados, señales, grants y enables.
- Mecanismo físico de invalidación DMEM.
- Respuesta y framing de comandos. El arbitraje y la secuencia CPU de faults están cerrados por `DEC-ARCH-003`, acuerdos 40–47.

**Justificación:** La separación entre `reset` global e inicialización de sesión evita convertir toda reprogramación en un `reset` físico y permite preparar coherentemente una sesión multiciclo antes de publicarla. La jerarquía conceptual y el evento final de ciclo impiden avances o compromisos duplicados durante `HOLD`, `STEP`, stalls y carga.

La aserción asíncrona permite reaccionar aun cuando todavía no haya un flanco disponible, mientras la desaserción sincronizada evita liberar el dominio funcional directamente desde una transición externa. La polaridad única y el acondicionamiento localizado desacoplan el CPU de la placa.

Rechazar `LOAD` durante contexto continuo preserva ownership y evita un aborto implícito. Seleccionar `reset` global como recuperación mínima satisface la ejecución no terminante sin confundir intervención externa con finalización normal. Mantener libres la codificación de FSM, nombres de puertos y organización física permite realizar el contrato aprobado.

**Consecuencias:**

- `reset` global e inicialización de sesión son mecanismos distintos;
- el `reset` distribuido usa aserción asíncrona y desaserción sincronizada, con consumo funcional síncrono;
- `reset` es activo en alto dentro del diseño y su polaridad física se normaliza en el wrapper;
- no se exige debouncer inicial, pero puede añadirse en integración si la evidencia lo requiere;
- `reset` domina `LOAD`, avance CPU y `HOLD`;
- `reset` global es la recuperación mínima obligatoria durante `RUN` y no produce `FINISHED` ni `DONE`;
- `LOAD` se rechaza durante contexto continuo, incluido su drenado automático, y no queda latente;
- una `LOAD` aceptada invalida inmediatamente la imagen y solo el commit completo publica una nueva sesión;
- `HOLD` congela el plano CPU sin detener el clock ni impedir actividad externa permitida;
- `RUN`, `STEP` y drenado generan ciclos efectivos conforme al contrato y el contador cambia una vez por ciclo;
- ownership de memorias es exclusivo y los efectos requieren enable conceptual y validez local;
- se conserva la FSM global del acuerdo 44; codificación binaria, FSM privadas y distribución física de enables siguen libres;
- pin, duración mínima y realización física de la relación con `locked` quedan para integración y `DEC-ARCH-005`;
- hazards locales y temporización precisa de faults permanecen en sus decisiones correspondientes.

**Requisitos afectados:** `REQ-CPU-009` a `REQ-CPU-013`, `REQ-CPU-016`, `REQ-CPU-018`, `REQ-HAZ-004`, `REQ-HAZ-010`, `REQ-EXEC-001` a `REQ-EXEC-018`, `REQ-MEM-007`, `REQ-MEM-008`, `REQ-MEM-019`, `REQ-MEM-024`, `REQ-MEM-025`, `REQ-MEM-028` a `REQ-MEM-030`, `REQ-UART-002` a `REQ-UART-005`, `REQ-DBG-001` a `REQ-DBG-004`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015` a `REQ-DBG-017`, `REQ-TIM-001`, `REQ-TIM-002`, `REQ-TIM-007`, `REQ-DOC-004`, `REQ-DOC-009`.

**Reemplaza / Reemplazada por:** No aplica.

---

### Revisión de DEC-ARCH-008 — Control integrado y habilitaciones

**Estado:** Aprobada.

**Fecha:** 2026-10-16.

**Alcance:** Las remisiones de este ADR al acuerdo 44 de `DEC-ARCH-003`, a la autorización separada y a la libertad inicial de realización se actualizan con el [acuerdo 48](DEC-ARCH-003.md#acuerdo-48-aprobado--integración-del-control-global-de-ejecución). [Execution Control](../architecture/session/execution_control.md), [Preparación de sesión](../architecture/session/session_preparation.md) e [Interfaces](../interfaces.md#bloque-8-1) concretan los controles vigentes. El [acondicionamiento de reset](../architecture/platform/reset_integration.md) conserva su contrato.

**Decisión:** `Global FSM`, en `global_fsm.sv` dentro de `execution_control.sv`, selecciona las solicitudes directas `load_request`, `run_request` y `step_request`, comunica aceptación mediante `command_accepted` y genera los controles de los recursos. El estado interno es one-hot de catorce bits y captura `next_state` en cada flanco positivo de `clk`; `cpu_cycle_fire` autoriza un ciclo efectivo de la CPU.

La prioridad funcional sigue siendo `RESET` > `LOAD` aceptado / preparación efectiva > ciclo CPU > `HOLD`. Su aplicación en la organización integrada es:

| Situación                                             | Control y efecto                                                                                                                                                                        |
|-------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Reset funcional activo                                | Suprime los controles Mealy y las escrituras CPU, Loader y mantenimiento; lleva la FSM a `NO_IMAGE`.                                                                                    |
| `LOAD` seleccionado                                   | `load_start` inicia Loader e invalida el tamaño confirmado en el flanco de aceptación; `cpu_cycle_fire=0`.                                                                              |
| Preparación efectiva                                  | `prepare_active` activa `Session Preparation`; sus controles realizan inicialización y limpieza. Mientras el estado inicial se prepara, `cpu_cycle_fire=0`.                             |
| `PREPARING_READY` con `prepare_done=1`                | `image_publish` habilita la captura del tamaño pendiente y la FSM entra en `READY`, con contador cero y sin ciclo CPU.                                                                  |
| `PREPARING_RUN`/`PREPARING_STEP` con `prepare_done=1` | El estado inicial ya está completo antes del flanco y los controles de inicialización/limpieza están inactivos. La FSM emite `cpu_cycle_fire=1` y el primer ciclo deja `cycle_count=1`. |
| Ciclo efectivo de CPU                                 | Los recursos consumen `cpu_cycle_fire` y sus habilitaciones locales; el contador incrementa una vez, incluidos stalls y drenado.                                                        |
| `HOLD`                                                | PC, RF, registros interetapa y contador retienen sus valores; UART y control de transporte continúan funcionando.                                                                       |

`prepare_active` refleja la fase registrada y puede seguir activo en el flanco de `prepare_done`. La finalización certifica que las escrituras de preparación ya terminaron; la FSM decide publicar la imagen o autorizar el primer ciclo según el estado actual.

`Global FSM` determina la autorización antes de consultar las confirmaciones y `pipeline_empty_next`. Se conservan la selección de acciones y sus prioridades, los efectos elegibles de instrucciones anteriores y la retención entre ciclos. Un `LOAD` rechazado durante ejecución continua conserva la autorización vigente.

**Comprobación:** Se contrastan estas habilitaciones con las interfaces y las reglas de preparación, prioridad y ciclo efectivo de las especificaciones consolidadas. La comprobación es documental.

**Reemplaza / Reemplazada por:** Actualiza las referencias de realización del control global. Los contratos de reset, ownership, commit de imagen, ciclo lógico y recuperación de este ADR conservan su alcance.
