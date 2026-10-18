# TP3 — Plataforma y comprobaciones de entrega

- **Tipo:** catálogo de verificación.
- **Estado documental:** pruebas diseñadas, sin ejecutar.

## Propósito y alcance

Este documento reúne las comprobaciones de configuración, clock, reset, composición del RTL, timing y aceptación en Basys3. También define cómo comprobar que la documentación corresponda a la versión entregada.

Las [convenciones, niveles y límites del plan](verification_plan.md) se aplican a todos los casos. Los contratos enlazados determinan el comportamiento; la [matriz](coverage.md) relaciona las pruebas con los requisitos y el trabajo fuera de alcance.

## Índice

- [TEST-PLAT-001 — Perfiles, capacidades y anchos derivados](#test-plat-001)
- [TEST-PLAT-002 — Clocking Wizard, locked y reset sincronizado](#test-plat-002)
- [TEST-PLAT-003 — Composición RTL y dependencias combinacionales](#test-plat-003)
- [TEST-PLAT-004 — Constraints, recursos y timing post-implementation](#test-plat-004)
- [TEST-PLAT-005 — Aceptación Basys3 con un bitstream](#test-plat-005)
- [TEST-PLAT-006 — Documentación y correspondencia con la entrega](#test-plat-006)

<a id="test-plat-001"></a>

## TEST-PLAT-001 — Perfiles, capacidades y anchos derivados

- **Nivel:** elaboración y revisión de configuración.
- **Tipo de estímulo:** parámetros válidos/ilegales.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-MEM-010](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-011](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-012](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-014](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-021](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-022](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-026](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-030](../requirements.md#5-memorias-y-carga-de-programas).

**Contratos:** [common_configuration](../architecture/common_configuration.md); [memory_architecture](../architecture/memory/memory_architecture.md); [system_composition](../architecture/system_composition.md).

### Qué comprueba y por qué

Esta prueba comprueba los perfiles de memoria, la validación de capacidades y los anchos derivados de la configuración.

Busca detectar un índice de cero bits para un único elemento, un overflow al calcular C+1 o un alias con una capacidad que no sea potencia de dos.

También distingue una capacidad ilegal de una capacidad legal que el target declarado no soporta. Esa distinción debe producir un diagnóstico de configuración, no un fault de CPU.

### Condiciones iniciales

La validación se realiza antes de elaborar memorias o IP. La capacidad C utiliza una representación sin signo de 64 bits y los extremos utilizan 33 bits; `2^32` no se calcula con un entero de 32 bits.

Se utilizan los nombres y valores aprobados de REFERENCE y ALT_1000. Las capacidades locales se suministran a los bloques genéricos y no crean otros perfiles de placa.

La prueba especifica las comprobaciones y los diagnósticos necesarios; no depende de una forma concreta de invocar los comandos de build.

### Variantes cerradas

La prueba tiene 15 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PLAT-001/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 15 casos comprenden:

- La elaboración de REFERENCE y ALT_1000 con sus capacidades exactas.
- La elaboración mínima con C=4 para ambas memorias.
- Las funciones de ancho aplicadas a las cinco capacidades de la tabla, incluida `2^32` sin elaborar arrays.
- Los cinco valores ilegales: 0, 2, 1023, 2050 y `2^32+4`.
- Un perfil desconocido.
- Una capacidad `2^32` matemáticamente legal pero no soportada como array físico en Basys3.

Las comprobaciones aritméticas no exigen implementar físicamente todos esos tamaños.

### Datos de referencia

|    C | BYTE_ADDRESS_WIDTH | WORD/ROW_INDEX_WIDTH | CAPACITY_INCLUSIVE_WIDTH |
|-----:|-------------------:|---------------------:|-------------------------:|
|    4 |                  2 |                    1 |                        3 |
| 1000 |                 10 |                    8 |                       10 |
| 1024 |                 10 |                    8 |                       11 |
| 2048 |                 11 |                    9 |                       12 |
| 2^32 |                 32 |                   30 |                       33 |

### Procedimiento

1. **Preparar la configuración.** Seleccionar el perfil o la capacidad de la variante antes de elaborar recursos.

2. **Elaborar los perfiles soportados.** Comparar la propagación de capacidades desde el wrapper a los tops y sus hijos, sin modificar la lógica.

3. **Evaluar los anchos.** Aplicar las funciones a las cinco capacidades y comparar con la tabla. C=4 no puede producir un índice de palabra de cero bits.

4. **Aplicar las configuraciones rechazadas.** Exigir el diagnóstico antes de reservar recursos. El perfil desconocido y la capacidad física no soportada deben distinguirse de una capacidad ilegal.

5. **Revisar la autoridad de valores.** Seguir cada ancho y límite hasta la capacidad seleccionada. El caso máximo se limita a funciones, sin asignar arrays gigantes.

### Resultados y criterio de aprobación

Los anchos deben coincidir con la tabla, sin valores cero, overflow de C+1 ni constantes independientes de la capacidad.

El perfil se selecciona una vez en el wrapper y los hijos reciben parámetros explícitos. CONFIG_INVALID_CAPACITY identifica la ilegalidad y CONFIG_UNSUPPORTED identifica falta de soporte.

Ambos perfiles conservan el layout UART fijo y derivan sus propios límites. Las herramientas deben declarar el mismo perfil que utiliza la configuración.

La aprobación exige trazabilidad de cada límite y ancho hasta la fuente autoritativa, sin asumir potencias de dos ni exigir síntesis física de ALT_1000.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-plat-002"></a>

## TEST-PLAT-002 — Clocking Wizard, locked y reset sincronizado

- **Nivel:** integración wrapper y revisión.
- **Tipo de estímulo:** eventos de plataforma controlados.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-TIM-001](../requirements.md#9-clock-fpga-y-timing), [REQ-TIM-008](../requirements.md#9-clock-fpga-y-timing), [REQ-EXEC-011](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-015](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-UART-006](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [platform_reference](../architecture/platform/platform_reference.md); [reset_integration](../architecture/platform/reset_integration.md).

### Qué comprueba y por qué

Esta prueba comprueba el clock funcional común y la integración de las fuentes de reset con el acondicionador de dos etapas.

Busca detectar una liberación asíncrona distribuida a los recursos, un reset combinado conectado al MMCM que impida recuperar el clock o un reset UART que interrumpa su propia aceptación.

Los pares de fuentes se aplican localmente al combinador. No representan una CPU operativa con una petición UART sostenida durante reset.

### Condiciones iniciales

Clocking Wizard utiliza MMCM y BUFG para obtener 50 MHz desde 100 MHz y expone `locked`. Las fuentes de reset se presentan con sus polaridades normalizadas.

En el combinador local se mantiene un clock funcional controlado y se aplican cambios entre flancos. En plataforma, el botón se mantiene al menos 1 µs. Mientras `!locked` está activo, el reset funcional permanece activo.

Las observaciones distinguen la aserción del acondicionador de la acción síncrona de sus consumidores.

### Variantes cerradas

La prueba tiene 10 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PLAT-002/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los cuatro eventos básicos son arranque, liberación del botón, pérdida y retorno de locked y reset UART.

Los seis casos restantes combinan pares ordenados de fuentes distintas en el combinador y reset_sync. Comprueban qué ocurre al liberar una fuente mientras otra sigue activa.

La secuencia física de aceptación y reset UART se comprueba mediante TEST-UART-013, sin duplicar sus casos.

También se ejecutan las comprobaciones reutilizadas de [TEST-UART-013](uart_debug.md#test-uart-013). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Procedimiento

1. **Aplicar el evento de plataforma.** Observar la aserción del acondicionador antes del próximo flanco y la acción de los consumidores en su flanco funcional.

2. **Liberar las fuentes.** Contar las dos etapas de sincronización y comprobar que una fuente todavía activa impida salir de reset.

3. **Comparar los pares locales.** Limitar esas observaciones al combinador y reset_sync, sin atribuir una ejecución de CPU al fixture.

4. **Revisar MMCM y clocks.** Solo el botón debe resetear el MMCM; `!locked` y la petición UART no se conectan a ese reset. STEP y tick son habilitaciones, no clocks.

5. **Comprobar el intercambio UART reutilizado.** Seguir el Stop de aceptación y la petición registrada según TEST-UART-013.

### Resultados y criterio de aprobación

El sistema tiene un único dominio funcional de 50 MHz. Tick y STEP no crean relojes adicionales.

Reset_sync afirma asíncronamente su salida y la libera mediante dos etapas; los recursos funcionales consumen ese reset de forma síncrona. No hay operación antes de locked y de la liberación completa, y una fuente activa impide liberar.

Solo el botón resetea MMCM. UART no reinicia el generador y `!locked` no crea un lazo que lo mantenga en reset. Se conserva ASYNC_REG en los sincronizadores.

El rebote del botón puede repetir reset; no se exige un filtro que no pertenece al diseño. La aprobación requiere las trazas y la revisión del IP para demostrar ausencia de arranque prematuro, gating y lazo de reset.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-plat-003"></a>

## TEST-PLAT-003 — Composición RTL y dependencias combinacionales

- **Nivel:** revisión RTL, elaboración y análisis estático.
- **Tipo de estímulo:** estructura sin estímulo arquitectónico.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-001](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-002](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-005](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-006](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-007](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-008](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-009](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-012](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-015](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-003](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-MEM-011](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-019](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-026](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-027](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-028](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-029](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-030](../requirements.md#5-memorias-y-carga-de-programas), [REQ-TIM-001](../requirements.md#9-clock-fpga-y-timing), [REQ-EXEC-018](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [module_inventory](../architecture/module_inventory.md); [system_composition](../architecture/system_composition.md); [interfaces](../interfaces.md); [architectural_invariants](../architecture/architectural_invariants.md); [global_state_encoding](../architecture/session/global_state_encoding.md).

### Qué comprueba y por qué

Esta prueba comprueba que la estructura del RTL y la netlist conserven los bloques, interfaces y recursos definidos por los contratos.

Busca detectar una agrupación que oculte una obligación, registros derivados añadidos al pipeline o un lazo combinacional en la autoridad de estado y ejecución.

La revisión estructural complementa las simulaciones: un resultado funcional aislado no demuestra por sí solo la organización completa.

### Condiciones iniciales

Se utiliza RTL y netlist de una revisión identificada, junto con el inventario y las interfaces vigentes.

El alcance incluye el paquete compartido, IP, reset, controladores y serializador. Los bloques locales pueden compartir un archivo; no se exige un archivo separado por cada función.

La revisión no supone un código numérico de encoder para estados internos ilegales que el contrato no haya definido.

### Variantes cerradas

La prueba tiene 1 caso canónico. El [manifiesto](cases.json) enumera los IDs `TEST-PLAT-003/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

El único caso revisa los 51 bloques y los servicios adicionales del build.

Cada puerto, ancho o dependencia es un ítem de esa misma comprobación estructural. No se convierte en un nuevo vector funcional por bloque.

### Procedimiento

1. **Localizar cada bloque.** Identificar su archivo u objeto y comparar dirección, ancho, naturaleza y productor o consumidor con las interfaces. Comprobar `global_fsm.sv` dentro de `execution_control.sv` y las seis funciones locales del contenedor.

2. **Comprobar los recursos.** Revisar los cuatro latches y sus 504 bits funcionales, el Register File de 32 por 32 bits, las memorias inferidas y el estado one-hot de 14 bits.

3. **Seguir las dependencias.** Recorrer estado actual y solicitudes, aceptación y autorización de ciclo, acción, latches `next`, `pipeline_empty_next` y `next_state`. Este último solo retorna mediante el registro de estado. Comprobar que las solicitudes UART se generen independientemente de `command_accepted`, que el código de estado llegue a `Response Serializer` y que `Protocol Controller` reciba los indicadores de control aprobados. La FSM actualiza su registro en cada flanco funcional, también cuando `cpu_cycle_fire=0`.

4. **Buscar estado duplicado.** Revisar `image_valid`, contador de instrucciones, `drain_auto`, `terminal_kind`, `uses_rs*`, estado UART global adicional o una copia completa de Debug.

5. **Comprobar valores definidos y assertions.** Exigir defaults definidos sin X como comodines ni nuevos faults. Las assertions detectan invariantes y ownership, sin efectos arquitectónicos.

### Resultados y criterio de aprobación

Contratos y jerarquía deben coincidir aunque varias funciones compartan archivo. No deben existir los registros derivados duplicados indicados.

El Register File de referencia utiliza flip-flops con inicialización paralela. Las memorias son inferidas y conservan lectura combinacional. No se permiten latches accidentales ni lazos combinacionales.

Las representaciones internas inválidas tienen valores definidos y no producen una causa de fault nueva. No se prescribe un byte de encoder que el contrato no especifica.

La aprobación exige identificar cada bloque y comprobar sus puertos y anchos, además de verificar que los caminos de autoridad y señales de control sean acíclicos. Contar módulos no basta.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-plat-004"></a>

## TEST-PLAT-004 — Constraints, recursos y timing post-implementation

- **Nivel:** Vivado síntesis/implementación.
- **Tipo de estímulo:** REFERENCE físico.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-TIM-002](../requirements.md#9-clock-fpga-y-timing), [REQ-TIM-003](../requirements.md#9-clock-fpga-y-timing), [REQ-TIM-004](../requirements.md#9-clock-fpga-y-timing), [REQ-TIM-005](../requirements.md#9-clock-fpga-y-timing), [REQ-TIM-006](../requirements.md#9-clock-fpga-y-timing), [REQ-TIM-008](../requirements.md#9-clock-fpga-y-timing), [REQ-MEM-010](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-025](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-026](../requirements.md#5-memorias-y-carga-de-programas).

**Contratos:** [platform_reference](../architecture/platform/platform_reference.md); [memory_architecture](../architecture/memory/memory_architecture.md).

### Qué comprueba y por qué

Esta prueba comprueba que la implementación física de REFERENCE cumpla timing a 50 MHz y conserve la semántica de los recursos.

Busca detectar un timing aparentemente correcto por caminos sin restringir, una lectura de memoria que cambie de latencia o una excepción XDC demasiado amplia.

La frecuencia máxima razonable se justifica con los reportes post-route, considerando setup, hold e interfaces.

### Condiciones iniciales

Se utiliza REFERENCE sobre la Basys3, con RTL, IP y XDC del mismo commit.

Los pines son W5, U18, B18 y A18, con LVCMOS33. Clocking Wizard convierte 100 MHz a 50 MHz; ambos clocks se consideran relacionados.

Las restricciones aprobadas se conservan en los caminos de UART, sincronización, CPU, memorias y reset funcional.

### Variantes cerradas

La prueba tiene 1 caso canónico. El [manifiesto](cases.json) enumera los IDs `TEST-PLAT-004/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

El único caso comprende una síntesis e implementación a 50 MHz con los reportes de clocks, CDC, DRC, recursos, setup, hold y camino crítico.

Una frecuencia mayor que 50 MHz es opcional. La prueba no prescribe un barrido indefinido de frecuencias.

### Procedimiento

1. **Preparar el build de referencia.** Utilizar los archivos de la misma revisión y los constraints aprobados.

2. **Sintetizar e implementar a 50 MHz.** Examinar `report_clocks`, `report_cdc`, `report_drc`, `report_utilization`, `timing_summary` y los caminos de setup y hold.

3. **Comprobar las restricciones.** Revisar RX desde pin hasta primer registro con 20 ns, TX desde registro a pin con 20 ns, reset_sync de dos etapas y el timing normal de CPU, memorias y reset funcional.

4. **Comparar los resultados.** Exigir WNS y WHS no negativos y TNS y THS iguales a cero. Identificar camino crítico, extremos, skew y demora.

5. **Justificar recursos y frecuencia.** No ocultar errores con false_path o multicycle ni declarar asíncronos los clocks de 100 y 50 MHz. Un fallback de memoria solo se acepta si conserva los contratos y pasa la misma regresión funcional.

### Resultados y criterio de aprobación

La implementación debe cumplir `WNS≥0`, `WHS≥0`, `TNS=0` y `THS=0` a 50 MHz, con los caminos relevantes restringidos.

Ninguna excepción puede ocultar CPU, memorias o reset distribuido. Los clocks no se declaran asíncronos entre sí y baud o STEP no crean otros clocks.

Los recursos inferidos deben caber y conservar la lectura combinacional. El camino crítico debe identificar extremos, demora, clock y skew, sin extrapolar una frecuencia considerando solo setup.

La aprobación exige reportes post-route completos, cobertura de constraints y ausencia de errores DRC o CDC relevantes sin justificar. Toda excepción debe identificar su endpoint y su motivo; una cifra WNS favorable no basta.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-plat-005"></a>

## TEST-PLAT-005 — Aceptación Basys3 con un bitstream

- **Nivel:** placa y emisor/lector UART de pruebas.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-TIM-007](../requirements.md#9-clock-fpga-y-timing), [REQ-MEM-004](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-007](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-010](../requirements.md#5-memorias-y-carga-de-programas), [REQ-UART-001](../requirements.md#7-uart-y-debug-unit), [REQ-UART-002](../requirements.md#7-uart-y-debug-unit), [REQ-UART-003](../requirements.md#7-uart-y-debug-unit), [REQ-UART-004](../requirements.md#7-uart-y-debug-unit), [REQ-UART-005](../requirements.md#7-uart-y-debug-unit), [REQ-UART-006](../requirements.md#7-uart-y-debug-unit), [REQ-UART-007](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-004](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-005](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-010](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-013](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [platform_reference](../architecture/platform/platform_reference.md); [protocol](../protocol.md); [execution_control](../architecture/session/execution_control.md).

### Qué comprueba y por qué

Esta prueba comprueba en Basys3 los casos legales seleccionados y el enlace UART con un único bitstream.

Busca detectar diferencias entre simulación y placa, incluyendo configuración serial, pines, timing y reemplazo de imágenes sin reprogramación del dispositivo.

La ejecución física utiliza casos ya enumerados. Repetirlos en placa aporta una observación distinta, pero no crea otros casos lógicos.

### Condiciones iniciales

Se utiliza la conexión J4 de Basys3 y un bitstream REFERENCE con timing aprobado. El host se configura a 19200 baud y 8N1.

Se cargan las imágenes y los operandos de los casos seleccionados. Los valores del Register File y del estado lógico de DMEM se preparan mediante LUI, ADDI y stores legales.

En placa no se utilizan escrituras invisibles de un fixture. Las instrucciones de setup forman parte de la ejecución y sus efectos deben incluirse en la comparación.

### Variantes cerradas

La prueba tiene **0 casos base adicionales**. Conserva los IDs de los casos que se vuelven a ejecutar; no crea IDs propios de variante.

Este grupo no agrega casos base propios. Las 151 reejecuciones físicas están enumeradas en la subsección siguiente y en `replay_cases` del [manifiesto](cases.json).

La selección utiliza únicamente REFERENCE. No se trasladan a placa los casos artificiales, los comprobadores aritméticos de capacidad máxima o los fixtures unitarios del encoder como si fueran programas legales.

Se conservan los IDs originales y la selección cerrada; no se agrega un producto de variantes de placa.

También se ejecutan las comprobaciones reutilizadas de [TEST-ISA-001](isa.md#test-isa-001), [TEST-ISA-002](isa.md#test-isa-002), [TEST-ISA-003](isa.md#test-isa-003), [TEST-ISA-005](isa.md#test-isa-005), [TEST-ISA-006](isa.md#test-isa-006), [TEST-ISA-007](isa.md#test-isa-007), [TEST-ISA-008](isa.md#test-isa-008), [TEST-PIPE-003](pipeline.md#test-pipe-003), [TEST-PIPE-005](pipeline.md#test-pipe-005), [TEST-EXEC-004](execution.md#test-exec-004), [TEST-EXEC-008](execution.md#test-exec-008), [TEST-MEM-008](memory.md#test-mem-008), [TEST-UART-004](uart_debug.md#test-uart-004), [TEST-UART-008](uart_debug.md#test-uart-008), [TEST-UART-013](uart_debug.md#test-uart-013). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Casos que se vuelven a ejecutar en placa

Estas 151 reejecuciones forman una selección cerrada y están también en `replay_cases` del [manifiesto](cases.json). En UART-008 se crean las marcas mediante stores reales; en UART-013 los cuatro drains se verifican localmente y no se trasladan a esta selección física.

- En [TEST-ISA-001](isa.md#test-isa-001) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C006`, `C007`, `C008`,
  `C009`, `C010`, `C011`, `C012`, `C013`, `C014`, `C015`, `C016`,
  `C017`, `C018`, `C019`, `C020`.

- En [TEST-ISA-002](isa.md#test-isa-002) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C006`, `C007`, `C008`,
  `C009`, `C010`, `C011`, `C012`, `C013`, `C014`, `C015`, `C016`,
  `C017`, `C018`, `C019`, `C020`, `C021`, `C022`, `C023`, `C024`,
  `C025`, `C026`, `C027`, `C028`, `C029`, `C030`, `C031`, `C032`,
  `C033`, `C034`, `C035`, `C036`, `C037`.

- En [TEST-ISA-003](isa.md#test-isa-003) se vuelven a ejecutar los casos `C021`, `C022`, `C023`, `C024`.

- En [TEST-ISA-005](isa.md#test-isa-005) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`.

- En [TEST-ISA-006](isa.md#test-isa-006) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C006`, `C007`, `C008`.

- En [TEST-ISA-007](isa.md#test-isa-007) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C006`, `C007`, `C008`,
  `C009`, `C010`, `C011`, `C012`, `C013`, `C014`, `C015`, `C016`,
  `C017`, `C018`, `C019`, `C020`, `C021`, `C022`.

- En [TEST-ISA-008](isa.md#test-isa-008) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C006`.

- En [TEST-PIPE-003](pipeline.md#test-pipe-003) se vuelven a ejecutar los casos `C025`, `C026`, `C027`, `C028`, `C029`.

- En [TEST-PIPE-005](pipeline.md#test-pipe-005) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C006`, `C007`, `C008`,
  `C009`.

- En [TEST-EXEC-004](execution.md#test-exec-004) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C007`, `C008`.

- En [TEST-EXEC-008](execution.md#test-exec-008) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`.

- En [TEST-MEM-008](memory.md#test-mem-008) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C006`.

- En [TEST-UART-004](uart_debug.md#test-uart-004) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C004`, `C005`, `C006`, `C007`, `C008`,
  `C009`.

- En [TEST-UART-008](uart_debug.md#test-uart-008) se vuelven a ejecutar los casos `C001`, `C002`, `C003`, `C005`.

- En [TEST-UART-013](uart_debug.md#test-uart-013) se vuelven a ejecutar los casos `C001`, `C002`, `C007`, `C008`, `C009`, `C010`.

### Procedimiento

1. **Configurar una sola vez.** Ejecutar los casos ISA seleccionados, con LUI únicamente para TEST-ISA-003. En pipeline, ejecutar los cinco programas de TEST-PIPE-003 y los consumidores de TEST-PIPE-005. En faults, utilizar los casos REFERENCE enumerados y excluir los PCs inyectados.

2. **Reemplazar la imagen.** Cargar A y luego B sin cambiar el bitstream. Comprobar también la recuperación del loop mediante reset y capturar Register File, latches, memoria utilizada y contador por UART.

3. **Comprobar las cargas y listas.** En TEST-UART-004 utilizar REFERENCE. En TEST-UART-008 preparar mediante stores reales la lista vacía, el último byte y la lista completa, sin forzar el bitmap ni asignar capacidad `2^32`.

4. **Preparar los datos del listado.** Para la lista completa con dato `a mod 256`, utilizar el loop SB del contador de dirección. Para el último byte, cargar `C-1` y escribir su byte bajo. Comparar el contexto real de esa ejecución, sin trasladar el fixture artificial de TEST-UART-007.

5. **Comparar con el setup incluido.** Identificar el PC inicial del bloque, las relocaciones de JALR o branches, PC de fault, enlace, contador y stores de preparación. Ajustar la expectativa a esas instrucciones reales y conservar sus ciclos en el resultado.

### Resultados y criterio de aprobación

Los valores dirigidos y faults deben coincidir con el catálogo. El enlace UART real conserva los 32 registros, los latches, la memoria utilizada y el contador observados.

El reemplazo de imagen no requiere un bitstream nuevo ni puede depender de residuos de una sesión anterior. RUN y STEP deben ser compatibles, las observaciones coherentes y la recuperación por reset disponible.

No se exige implementación física de ALT_1000 ni la GUI final para comprobar la FPGA. La aceptación de la aplicación pertenece a la verificación de software.

La aprobación exige los binarios, prefijos de setup, bitstream y build, perfil, capturas UART y resultados de las variantes seleccionadas. La simulación no sustituye la evidencia de placa.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-plat-006"></a>

## TEST-PLAT-006 — Documentación y correspondencia con la entrega

- **Nivel:** revisión documental.
- **Tipo de estímulo:** fuentes vigentes y versión implementada futura.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-DOC-001](../requirements.md#10-documentación-y-trazabilidad), [REQ-DOC-002](../requirements.md#10-documentación-y-trazabilidad), [REQ-DOC-003](../requirements.md#10-documentación-y-trazabilidad), [REQ-DOC-004](../requirements.md#10-documentación-y-trazabilidad), [REQ-DOC-005](../requirements.md#10-documentación-y-trazabilidad), [REQ-DOC-006](../requirements.md#10-documentación-y-trazabilidad), [REQ-DOC-007](../requirements.md#10-documentación-y-trazabilidad), [REQ-DOC-008](../requirements.md#10-documentación-y-trazabilidad), [REQ-DOC-009](../requirements.md#10-documentación-y-trazabilidad).

**Contratos:** [requirements](../requirements.md); [decisions](../decisions/decisions.md); [system_overview](../architecture/system_overview.md); [control_and_hazards](../architecture/cpu/control_and_hazards.md); [execution_control](../architecture/session/execution_control.md); [memory_architecture](../architecture/memory/memory_architecture.md); [protocol](../protocol.md).

### Qué comprueba y por qué

Esta prueba comprueba que la documentación describa el circuito entregado y permita relacionar sus requisitos con el comportamiento verificado.

Busca detectar diagramas o contratos de otra versión, obligaciones sin una fuente vigente o una propuesta presentada como si fuera un resultado ejecutado.

Es una comprobación documental de la entrega; no ejecuta instrucciones de CPU.

### Condiciones iniciales

Documentos, programas, resultados y netlist corresponden al mismo commit.

Se identifican las decisiones relacionadas con el apartado 29 de la consigna. Las fuentes históricas enlazadas que estén ausentes no se consideran disponibles ni se restauran por inferencia.

La revisión distingue una prueba diseñada, una comprobación abstracta y un resultado real de simulación o placa.

### Variantes cerradas

La prueba tiene 1 caso canónico. El [manifiesto](cases.json) enumera los IDs `TEST-PLAT-006/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

El único caso revisa las nueve obligaciones documentales.

Definir la prueba no satisface por sí mismo los requisitos que dependen de implementación o software. Los nueve ítems pertenecen a la misma revisión, sin agregar casos propios.

### Procedimiento

1. **Revisar cada requisito documental.** Para REQ-DOC-001 a REQ-DOC-009, localizar la fuente vigente y su justificación, incluyendo reprogramación, `halt`, ausencia de `halt`, memoria utilizada, protocolo, perfiles y hazards.

2. **Comparar las representaciones.** Contrastar interfaces y diagramas con RTL, bitstream y resultados de la versión entregada.

3. **Identificar las fuentes ausentes.** Mantener explícitos los enlaces históricos que no puedan comprobarse, sin reconstruir archivos eliminados por inferencia.

4. **Comparar el alcance de la evidencia.** Distinguir aprobación de diseño, resultados abstractos y simulaciones o pruebas de placa realmente ejecutadas.

5. **Comprobar la correspondencia final.** REQ-DOC-009 no puede aprobarse antes de que exista la implementación que debe describir.

### Resultados y criterio de aprobación

Cada obligación documental debe tener una fuente vigente y trazabilidad al comportamiento verificado.

Las decisiones abiertas conservan su situación; redactar las pruebas no las aprueba. La propuesta, la evidencia histórica y los resultados ejecutados se distinguen, y la documentación final refleja la versión entregada.

Los enlaces ausentes permanecen identificados hasta resolver su situación. La aprobación requiere comprobar cada requisito con su fuente y evidencia real.

REQ-DOC-009 depende de la implementación existente. Diseñar ahora su comprobación no acredita esa correspondencia.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.
