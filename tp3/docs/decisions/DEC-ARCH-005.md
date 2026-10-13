### DEC-ARCH-005 — Frecuencia objetivo y distribución de clock

**Contrato vigente de consulta:** [platform_reference](../architecture/platform/platform_reference.md), [reset_integration](../architecture/platform/reset_integration.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Clock / Timing

**Fecha de aprobación:** 2026-09-22

**Depende de:** `DEC-SYS-004`, `DEC-ARCH-006` y `DEC-ARCH-008`, ya aprobadas, clock de la placa, recursos disponibles y restricciones iniciales.

**Alcance aprobado:** La estrategia arquitectónica comprende un único dominio funcional, su generación desde el clock físico, la relación semántica entre estabilidad y `reset`, y el **objetivo de referencia de 50 MHz (20 ns)** para `REFERENCE=1024/2048` sobre Basys 3. Esta aprobación cierra la elección arquitectónica para M2 — Architecture Freeze; no afirma que la implementación ya haya alcanzado 50 MHz.

**Verificación posterior:** Timing closure determinará mediante reportes post-implementation WNS, TNS, WHS, THS, camino crítico, cobertura de constraints y frecuencia efectivamente alcanzada. Es la verificación del objetivo aprobado, no una precondición para aprobar este ADR. Si falla timing a 50 MHz, se revisará el diseño y se corregirán los caminos críticos; funcionar por debajo del mínimo docente de 50 MHz no cumple el TP. Superar ese mínimo es opcional. La selección/configuración concreta del recurso de clock, pin, XDC y conexión RTL con `locked` corresponden a integración y no bloquean Architecture Freeze.

**Contexto:** Los acuerdos siguientes fijan un único dominio de clock funcional con enables síncronos, el objetivo de referencia de 50 MHz para `REFERENCE` en Basys 3 a partir de su oscilador físico de 100 MHz, el criterio de verificación temporal y la relación semántica entre estabilidad del generador y `reset` global.

El perfil `REFERENCE` deberá verificar timing a la frecuencia aprobada; `ALT_1000` no adquiere por esta decisión obligación de síntesis o implementación.

El análisis considerará la demanda simultánea máxima de un fetch y un acceso de datos y cubrirá los caminos combinacionales de validación, IMEM, organización por lanes DMEM, filtro de validez, ensamblado y extensión acordados en `DEC-ARCH-006`.

Una salida registrada no podrá introducirse para cerrar timing sin revisar esa decisión. Los reportes deberán identificar el recurso efectivamente inferido y justificar si resulta necesario evaluar XPM o primitivas.

Si un backend comparte recursos físicos, deberá preservar concurrencia, ausencia de aliasing y lectura sin stalls.

Las referencias de los acuerdos originales a aspectos todavía pendientes o a una parte restante de esta decisión describen tareas de integración y verificación posteriores, no elecciones arquitectónicas abiertas para su aprobación.

#### Acuerdo parcial aprobado — dominio de clock funcional

**Fecha:** 2026-09-22

La implementación inicial utilizará un único dominio de clock funcional principal para todo el estado secuencial de:

- CPU y pipeline;
- control global y loader;
- escrituras y metadatos de las memorias lógicas;
- Debug;
- UART.

Las lecturas combinacionales de IMEM y DMEM no constituirán dominios adicionales. Sus puntos de captura, escrituras y estructuras secuenciales asociadas pertenecerán al clock funcional principal.

##### Control de avance

`RUN`, `STEP`, `HOLD`, `LOAD` y mantenimiento no detendrán, gatearán, dividirán ni generarán clocks funcionales. Mientras el generador proporcione flancos válidos, el clock principal continuará activo y el avance se controlará mediante enables, selección de próximo estado y eventos síncronos conforme a `DEC-ARCH-008`.

Un `STEP` autorizará exactamente un ciclo lógico del CPU; no producirá un pulso de clock nuevo. Los conceptos de enable y evento no impondrán nombres RTL concretos.

##### Clock de placa y adaptación

La frontera conceptual será:

```text
clock físico de placa
        -> adaptación según plataforma
        -> único clock funcional principal
        -> todo el estado secuencial del sistema
```

Según la plataforma y frecuencia seleccionadas, la adaptación podrá consistir en conexión directa o en un recurso de generación de clock compatible con la plataforma y frecuencia seleccionadas. En la plataforma Basys 3 de referencia se requerirá adaptar 100 MHz a 50 MHz mediante un recurso dedicado; su selección, configuración exacta y conexión física con `reset` se concretarán en integración conforme al acuerdo de estabilidad siguiente.

El clock físico de entrada de un eventual generador no constituirá por sí mismo un segundo dominio funcional del RTL de usuario.

##### UART

UART no utilizará un dominio de clock funcional independiente. Los ritmos de transmisión, recepción u oversampling se derivarán del clock principal mediante contadores, acumuladores, clock-enables o ticks síncronos equivalentes:

```text
clock funcional
        -> contador o acumulador
        -> baud_tick síncrono
        -> enable de UART
```

Un concepto como `baud_tick` será un evento de enable y no un clock distribuido. No se utilizará como `posedge` o `negedge` para crear otro dominio. Baud rate, oversampling y generación concreta permanecerán para `DEC-SYS-007` y la parte restante de `DEC-ARCH-005`.

##### Revisión futura

No se introducirán clocks funcionales adicionales en la implementación inicial. Si una necesidad física futura justificara otro dominio interno, deberá revisarse esta decisión y documentarse explícitamente la frontera CDC, sincronización o handshake, constraints, coherencia de Debug y memorias, impacto sobre `reset` y verificación.

#### Acuerdo parcial aprobado — plataforma y frecuencia funcional de referencia

**Fecha:** 2026-09-22

La plataforma FPGA de referencia será **Digilent Basys 3**, con **AMD/Xilinx Artix-7 XC7A35T-1CPG236C**. Su oscilador físico de **100 MHz** será la fuente primaria del clock de la implementación `REFERENCE=1024/2048` definida en `DEC-ARCH-006`.

El único dominio funcional tendrá como **frecuencia objetivo inicial** `fclk = 50 MHz`, equivalente a `Tclk = 20 ns`:

```text
oscilador Basys 3: 100 MHz
        -> recurso dedicado de generación y distribución de clock
        -> dominio funcional: objetivo 50 MHz (20 ns)
        -> CPU, pipeline, control, loader, memorias, Debug y UART
```

##### Generación y estabilidad

La conversión 100 → 50 MHz empleará un recurso de clock soportado por la FPGA, como Clock Wizard, MMCM o equivalente soportado, y la salida utilizará distribución dedicada. No se distribuirá como clock funcional un divisor hecho con lógica ordinaria, por ejemplo un flip-flop divisor. No se fija el recurso, configuración, instancia ni pin concretos.

Si el generador seleccionado proporciona una indicación de estabilidad como `locked`, se aplicará la relación semántica con `reset` global definida más abajo. La conexión concreta, los tiempos y la realización física quedarán para integración sin alterar la aserción asíncrona, desaserción sincronizada y consumo funcional síncrono de `DEC-ARCH-008`.

##### Objetivo temporal y revisión

El objetivo de 50 MHz no equivale a timing ya aprobado. Para la Basys 3 se restringirán correctamente el clock primario de 100 MHz / 10 ns y el funcional generado de 50 MHz / 20 ns, considerando los constraints que aporte el recurso elegido y evitando dejar rutas relevantes sin analizar. `REFERENCE` se sintetizará e implementará; tras place-and-route se documentarán camino crítico, WNS, TNS, WHS, THS, skew, cobertura de constraints y cumplimiento del período objetivo conforme al criterio siguiente.

Si no se cumple el objetivo, primero se analizarán los caminos críticos y sus causas, se corregirá el diseño cuando corresponda y se repetirán las verificaciones. No se declarará cumplimiento operando por debajo de 50 MHz. Cualquier revisión técnica debe preservar el mínimo docente; una frecuencia superior es mejora opcional y requiere validación propia. El contrato de lectura combinacional y concurrencia IF/MEM de `DEC-ARCH-006` permanecerá vigente; una lectura registrada o stall de memoria no será un atajo implícito de timing.

Los 50 MHz constituyen el objetivo de referencia hasta contar con evidencia post-implementación. `ALT_1000=1000/1000` continúa limitado a elaboración, simulación y smoke tests, sin obligación física nueva.

#### Acuerdo parcial aprobado — criterio de cumplimiento temporal

**Fecha:** 2026-09-22

La implementación `REFERENCE=1024/2048` sobre Basys 3 solo se considerará temporalmente válida a 50 MHz (`Tclk = 20 ns`) si el análisis de Vivado **post-implementation**, después de síntesis y place-and-route, demuestra para **todos los caminos relevantes restringidos** ausencia de violaciones de setup y hold:

```text
Setup: WNS >= 0 ns; TNS = 0 ns
Hold:  WHS >= 0 ns; THS = 0 ns
```

El criterio no se limita al subtotal del clock funcional: incluye los caminos relevantes asociados al clock primario de 100 MHz, al funcional generado de 50 MHz y a las interfaces que requieran constraints. Antes de interpretar los slacks se verificará que los clocks relevantes estén definidos, que los caminos síncronos pertinentes estén analizados y que no existan caminos o interfaces críticos relevantes sin restricciones temporales adecuadas. Toda excepción temporal deberá estar justificada, documentada y verificada; no podrá ocultar violaciones mediante excepciones genéricas.

No se exige margen positivo adicional: un slack nulo cumple el umbral y un margen positivo pequeño podrá señalarse sin considerarlo incumplimiento. La síntesis exitosa o la ausencia de errores generales no sustituyen un Timing Summary completo y favorable. Si hay violaciones de setup o hold, o cobertura relevante incompleta, se identificarán los caminos y sus causas, se corregirá el diseño cuando corresponda y se repetirá la verificación. Cualquier revisión de la frecuencia requerirá justificación y actualización documental explícitas, respetando el mínimo docente de 50 MHz y `DEC-ARCH-006`.

Este acuerdo define el **criterio**, no acredita todavía su cumplimiento: faltan los constraints concretos y los reportes post-implementation de la implementación de referencia.

#### Acuerdo parcial aprobado — estabilidad del generador y reset funcional

**Fecha:** 2026-09-22

Si el recurso de generación de clock proporciona una indicación de estabilidad como `locked`, su ausencia será una causa de solicitud de `reset` global, además de la solicitud externa. Conceptualmente:

```text
solicitud de reset = solicitud externa de reset OR generador sin estabilidad
```

La expresión y los nombres son ilustrativos, sin imponer señales, una FSM ni estructura RTL concreta. Cualquiera de las dos causas podrá asertar asíncronamente el `reset` distribuido de `DEC-ARCH-008`. La liberación solo podrá comenzar cuando la solicitud externa esté inactiva **y** el generador indique estabilidad. `locked = 1` retira una causa de `reset`, pero no libera directamente CPU, pipeline o control: la desaserción del `reset` distribuido permanece sincronizada con el clock funcional.

Durante arranque, mientras no haya estabilidad, el `reset` permanecerá asertado. Si se pierde `locked` durante `RUN`, `STEP`, `LOAD`, `HOLD` o drenado, se solicitará nuevamente `reset` global con su prioridad y semántica ya aprobadas. El `reset` distribuido podrá asertarse sin flancos, incluso si el clock funcional se detiene; **los efectos en registros funcionales ocurrirán solo en el primer flanco válido en que observen ese `reset`**, antes de permitir operación funcional normal. No se prometen cambios inmediatos en PC, pipeline, control o tamaño de imagen en ausencia de flancos válidos.

Al tomar efecto el `reset` funcional, se abortarán ejecución y cargas en curso, se invalidará la sesión (`loaded_image_size_bytes = 0`, `image_valid = 0` por derivación) y el sistema quedará detenido. Esta recuperación no será `FINISHED` ni `DONE`; después de recuperar estabilidad y liberar el `reset` correctamente podrá solicitarse una nueva `LOAD`, no reanudarse la sesión anterior. Los efectos ya comprometidos antes de que el `reset` funcional tome efecto conservarán el tratamiento de `DEC-ARCH-008`.

La selección/configuración del recurso, la conexión y secuencia RTL concretas, el pin, la duración mínima y los constraints seguirán correspondiendo a integración. Esta relación semántica no acredita todavía la estabilidad física ni el cierre temporal.

##### Aspectos todavía pendientes

Continúan abiertos dentro de `DEC-ARCH-005` o integración:

- frecuencia final sustentada por timing post-implementación;
- recurso y configuración concretos de generación;
- conexión física y secuencia RTL concretas de la indicación de estabilidad y `reset`;
- pin y constraints concretos de placa y clocks;
- evidencia de síntesis, implementación y cumplimiento post-implementation del criterio de setup, hold y cobertura de constraints.

**Opciones a analizar:**

- Recurso dedicado para generar 50 MHz desde 100 MHz en Basys 3.
- Configuración y constraints de integración.
- Corrección del diseño si falla timing a 50 MHz.
- Evaluar frecuencias superiores solo como mejora opcional.

**Requisitos afectados:** `REQ-MEM-008`, `REQ-MEM-010`, `REQ-MEM-016` a `REQ-MEM-030`, `REQ-EXEC-011`, `REQ-UART-001` a `REQ-UART-005`, `REQ-TIM-001` a `REQ-TIM-007`, `REQ-DOC-009`.

**Reemplaza / Reemplazada por:** No aplica.

---

### Aclaración de DEC-ARCH-005 — Clocking Wizard requerido por el docente

**Estado:** Requisito comunicado por el usuario e incorporado al diseño.

**Fecha:** 2026-10-05.

**Fuente y alcance:** Indicación docente reportada durante el diseño: utilizar Clocking Wizard de Vivado para generar el reloj. Es un requisito adicional registrado; no se atribuye una cita textual al profesor ni se presenta como contenido de `consigna.md`.

**Concreción:** Clocking Wizard deja de ser una alternativa de herramienta pendiente de elección. Se incorpora REQ-TIM-008; se conservan entrada de 100 MHz y dominio funcional de 50 MHz ya aprobados. La selección de MMCM y demás parámetros de la [propuesta de plataforma](../architecture/platform/platform_reference.md#propuesta-de-generador-de-clock) siguen siendo concreciones técnicas pendientes, no obligaciones adicionales atribuidas al profesor.

**Consecuencias:** No pedir otra aprobación para utilizar Clocking Wizard. Continúan FPGA-04, configuración/conexiones de clock y `reset`, pines y restricciones; no se autoriza implementación ni se afirma cumplimiento temporal.

### Aclaración de DEC-ARCH-005 — Frecuencia mínima exigida de 50 MHz

**Estado:** Requisito docente comunicado por el usuario e incorporado al diseño.

**Fecha:** 2026-10-05.

**Fuente:** Indicación docente reportada durante el diseño: funcionamiento mínimo a 50 MHz; frecuencias superiores son opcionales. Las experiencias previas reportadas a 100 MHz no constituyen un límite físico demostrado ni un criterio de aceptación.

**Concreción:** REQ-TIM-006 exige frecuencia funcional >=50 MHz con timing válido. Se conserva 50 MHz como frecuencia de la implementación de referencia y de la propuesta Clocking Wizard 100→50 MHz. No se abre una búsqueda de 100 MHz. Si falla timing a 50 MHz, debe corregirse el diseño; bajar de ese mínimo no cumple el requisito, aunque se documente una revisión. Se corrigen las formulaciones anteriores que admitían revisar la frecuencia sin fijar este piso.

**Alcance:** Elegir 50 MHz o generar ese reloj no demuestra todavía funcionamiento a esa frecuencia. Se mantienen reportes post-implementation, cobertura de constraints, setup/hold y validación funcional en placa. Configuración concreta de plataforma y conexiones siguen su ruta; sin implementar todavía.

### Acuerdo de concreción de DEC-ARCH-005 — Configuración del generador de clock

**Estado:** Aprobada.

**Fecha:** 2026-10-05.

**Contexto:** Clocking Wizard debe concretar sus opciones para transformar 100 MHz de placa en el dominio requerido de 50 MHz.

**Decisión:** Entrada single-ended de 100 MHz de Basys 3; MMCM mediante Clocking Wizard, salida única de 50 MHz, fase cero y duty cycle 50 %, buffer global BUFG, feedback automático y `locked` habilitado. Sin reconfiguración/fase dinámica ni spread spectrum. Puerto `reset` del generador activo alto; su fuente se propone a continuación con la conexión de `reset` de plataforma. Divisores internos legales calculados por el Wizard al generar el IP.

**Alcance:** Un único dominio funcional para CPU, memorias, control, Loader/preparación, Debug y UART. Relación `locked`/`reset` y mínimo docente conservados. No prueba timing ni genera IP/RTL. FPGA-04 permanece abierto para conexión de `reset`, pines y restricciones. [Plataforma](../architecture/platform/platform_reference.md#generador-del-clock).

### Acuerdo de concreción de DEC-ARCH-005 — Conexión del reset de plataforma

**Estado:** Aprobada.

**Fecha:** 2026-10-05.

**Contexto:** El `reset` de plataforma combina botón, petición UART y !`locked`, con liberación sincronizada. !`locked` no debe realimentar el `reset` del generador.

**Decisión:** Reset activo alto del Clocking Wizard conectado al botón físico normalizado. La solicitud del único `reset_sync` es botón `OR` `uart_reset_request` `OR` !`locked`; el acondicionador y todos los consumidores funcionales usan el reloj de 50 MHz. El botón reinicia generador y sistema; `RESET` UART conserva el generador en marcha y reinicia el sistema después del último Stop de `ACCEPTED`. !`locked` mantiene `reset` funcional, sin resetear al propio MMCM. Dos etapas y secuencia UART aprobadas se conservan, sin otra FSM/supervisor.

**Alcance:** Fuentes y conexión de `reset` concretadas. [Plataforma](../architecture/platform/platform_reference.md#conexión-de-reset-aprobada). Pinout, polaridades y duración mínima concreta, constraints y revisión local de plataforma siguen a continuación. Sin RTL/timing/placa verificados.

### Acuerdo de concreción de DEC-ARCH-005 — Pines y restricciones de Basys 3

**Estado:** Aprobada.

**Fecha:** 2026-10-05.

**Contexto:** La plataforma necesita pines y restricciones para PC→micro-USB J4→puente USB-UART→FPGA, botón central y clock generado.

**Decisión:** Frontera de placa con cuatro puertos de un bit: reloj W5, botón central U18 activo alto, RX FPGA B18 y TX FPGA A18, LVCMOS33. Comunicación por puente USB-UART incorporado, sin adaptador externo. Clocking Wizard y `reset_sync` se integran en wrapper; sincronizador RX permanece en `uart_core`. Se adoptan las restricciones previstas de [plataforma](../architecture/platform/platform_reference.md#pines-y-restricciones-aprobados): clocks primario/generado 10/20 ns relacionados, presupuestos `datapath_only` de 20 ns para rutas UART de pin/registro, `ASYNC_REG` y timing normal entre etapas/consumidores, excepciones de `reset` limitadas a entradas asíncronas del acondicionador/MMCM. Sin excepciones globales de datos/`reset` funcional. Pulsación física válida con margen de 1 µs, sin otro contador/filtro.

**Comprobación y alcance:** Pines, polaridades y puente contrastados con fuentes oficiales; mínimos físicos de pulso consultados en DS181 (tablas 26/37). Revisión local de productores/consumidores y constraints completada. FPGA-04 cerrado en diseño documental, sin generar IP/RTL/XDC ni comprobar timing/placa. Configuración/tops/representación y plan de verificación siguen abiertos.
