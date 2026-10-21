# TP3 — Pipeline y dependencias

- **Tipo:** catálogo de verificación.
- **Estado documental:** pruebas diseñadas, sin ejecutar.

## Propósito y alcance

Este documento reúne las pruebas del avance del pipeline, las lecturas y escrituras del Register File, el forwarding y las dependencias load-use. Cada grupo explica qué parte del estado se captura, se retiene o se descarta y cómo se comprueban sus efectos.

Los resultados arquitectónicos se comparan con las expectativas escritas para cada variante. Los stalls, el solapamiento y la actualización de latches se comprueban durante los ciclos indicados por las tablas y secuencias de estas pruebas. La comparación incluye tanto los valores finales como las condiciones y los momentos en que se producen sus efectos.

Las [convenciones, niveles y límites del plan](verification_plan.md) se aplican a todos los casos. Los contratos enlazados determinan el comportamiento; la [matriz](coverage.md) relaciona las pruebas con los requisitos y el trabajo fuera de alcance.

## Índice

- [TEST-PIPE-001 — Avance normal, solapamiento y esquema de latches](#test-pipe-001)
- [TEST-PIPE-002 — RF, dos lecturas y bypass WB a ID](#test-pipe-002)
- [TEST-PIPE-003 — Forwarding disponible y prioridad por fuente](#test-pipe-003)
- [TEST-PIPE-004 — Load reciente oculta un productor obsoleto](#test-pipe-004)
- [TEST-PIPE-005 — Load-use en los consumidores efectivos](#test-pipe-005)
- [TEST-PIPE-006 — Ausencia de dependencias falsas](#test-pipe-006)
- [TEST-PIPE-007 — Ocho acciones y actualizaciones preflanco](#test-pipe-007)
- [TEST-PIPE-008 — Wrong-path y fronteras por antigüedad](#test-pipe-008)
- [TEST-PIPE-009 — WB final, commits únicos y HOLD](#test-pipe-009)
- [TEST-PIPE-010 — Fetch candidato, load-use y fronteras anteriores](#test-pipe-010)
- [TEST-PIPE-011 — Registro IF/ID aislado](#test-pipe-011)
- [TEST-PIPE-012 — Registro ID/EX aislado](#test-pipe-012)
- [TEST-PIPE-013 — Registro EX/MEM aislado](#test-pipe-013)
- [TEST-PIPE-014 — Registro MEM/WB aislado](#test-pipe-014)

<a id="test-pipe-001"></a>

## TEST-PIPE-001 — Avance normal, solapamiento y esquema de latches

- **Nivel:** CPU y revisión de estructura.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-001](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-002](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-003](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-004](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-009](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-MEM-001](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-002](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-013](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-020](../requirements.md#5-memorias-y-carga-de-programas), [REQ-HAZ-001](../requirements.md#4-hazards-y-cambios-de-flujo).

**Contratos:** [cpu_pipeline](../architecture/cpu/cpu_pipeline.md); [system_composition](../architecture/system_composition.md).

### Qué comprueba y por qué

Esta prueba comprueba que las cinco etapas de la CPU trabajen en paralelo y que las instrucciones avancen por las cuatro fronteras registradas del pipeline.

Busca detectar una etapa que salte un latch, una captura que utilice datos postflanco en lugar de los datos preflanco o una organización que impida el solapamiento de instrucciones. La revisión de estructura también comprueba los campos y anchos de los cuatro latches.

### Condiciones iniciales

La CPU comienza en READY con una imagen confirmada de 28 bytes. El PC, el Register File y el contador comienzan en cero; los latches no contienen instrucciones válidas.

La imagen tiene seis ADDI independientes en las posiciones 0 a 20 y un `halt` en la posición 24. DMEM no participa y debe conservarse. Los bits residuales de los payloads inválidos no representan instrucciones activas.

### Variantes cerradas

La prueba tiene 1 caso canónico. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-001/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

El único caso ejecuta el programa lineal indicado a continuación. Los cuatro flancos de la tabla son observaciones de esa misma ejecución; no representan otros cuatro casos.

### Datos de referencia

| Ciclo completado | PC global | IF/ID.pc | ID/EX.pc | EX/MEM.pc | MEM/WB.pc |
|-----------------:|----------:|---------:|---------:|----------:|----------:|
|                1 |         4 |        0 | inválido |  inválido |  inválido |
|                2 |         8 |        4 |        0 |  inválido |  inválido |
|                3 |        12 |        8 |        4 |         0 |  inválido |
|                4 |        16 |       12 |        8 |         4 |         0 |

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para el caso `C001`, se utiliza el siguiente programa:

```asm
addi x1,x0,1
addi x2,x0,2
addi x3,x0,3
addi x4,x0,4
addi x5,x0,5
addi x6,x0,6
halt
```

### Procedimiento

1. **Preparar la sesión.** Cargar la imagen y comprobar el estado READY, el PC y la ausencia de trabajo válido en los latches.

2. **Aceptar RUN.** Observar que el flanco de aceptación sea también el primer ciclo efectivo de CPU.

3. **Seguir el llenado del pipeline.** Después de cada uno de los cuatro primeros flancos, esperar la estabilización combinacional y comparar el PC global y los PCs válidos de los latches con la tabla.

4. **Observar el solapamiento.** En el quinto ciclo, comprobar que IF, ID, EX, MEM y WB correspondan simultáneamente a instrucciones distintas. Continuar hasta la terminación y comparar el Register File.

5. **Revisar la estructura.** Contrastar los campos y anchos de cada frontera registrada con el contrato, además de la traza funcional.

### Resultados y criterio de aprobación

Cada instrucción debe avanzar como máximo una etapa por ciclo y cada captura debe utilizar los datos preflanco. El primer writeback ocurre en el quinto flanco.

Al finalizar por `halt`, cada registro `xi`, para `i=1…6`, debe contener el valor `i`. No debe haber efectos en DMEM.

Las cuatro fronteras tienen 5, 15, 8 y 6 campos, con 69, 193, 139 y 103 bits funcionales, respectivamente: 504 bits en total. No se debe agregar un quinto latch ni registrar señales de control derivadas adicionales.

La aprobación requiere una traza completa consistente con el solapamiento de las cinco etapas y una estructura equivalente al contrato, aunque el empaquetado del RTL sea distinto.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-002"></a>

## TEST-PIPE-002 — RF, dos lecturas y bypass WB a ID

- **Nivel:** unidad RF/WB e integración ID.
- **Tipo de estímulo:** legal y entradas locales controladas.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-005](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-008](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-012](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-013](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-016](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-002](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-DBG-005](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [stage_id](../architecture/cpu/stage_id.md); [stage_wb](../architecture/cpu/stage_wb.md).

### Qué comprueba y por qué

Esta prueba comprueba las dos lecturas del Register File, el bypass de WB hacia ID y la lectura de registros utilizada por Debug.

Busca detectar:

- Una dependencia de la semántica física `write-first` del banco.
- Un bypass habilitado por una escritura que no es elegible.
- Una modificación de `x0`.
- La necesidad de un tercer puerto de lectura que no pertenece a la arquitectura.
- Una escritura de WB que prevalezca indebidamente sobre reset o preparación.

### Condiciones iniciales

Cada variante prepara su estado de manera independiente. Para las lecturas ordinarias y de Debug, se reinstala el patrón `xi=0x01010101*i` en el Register File.

Para el bypass, la fuente elegida contiene inicialmente 3 y el valor de WB es 7. Se deshabilita una sola guarda por variante. Cuando se comprueba `rd=0`, tanto la fuente coincidente como el destino se direccionan a `x0` y su valor base es cero.

Las variantes de Debug no deben heredar el banco puesto en cero por una prueba anterior de reset. DMEM e IMEM no participan en estas comprobaciones.

### Variantes cerradas

La prueba tiene 52 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-002/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los casos comprenden:

- Tres pares de lecturas, con índices iguales, distintos o correspondientes a `x0`.
- Quince variantes de bypass: coincidencia en `rs1`, en `rs2` o en ambas, con la situación nominal y las cuatro guardas previstas.
- Dos inicializaciones dominantes, una por reset y otra por `prepare_init`, frente a un WB elegible.
- Las 32 direcciones del Register File leídas por Debug, cada una con el patrón inicial reinstalado.

La variante de `rd=0` comprueba una coincidencia real con `x0`; no se sustituye por un caso donde simplemente no coinciden las direcciones.

### Procedimiento

1. **Preparar las lecturas y WB.** Instalar el patrón o los valores de bypass del caso y presentar las direcciones correspondientes.

2. **Observar en preflanco.** Después de estabilizar la lógica, muestrear las dos lecturas y la selección de bypass. Comparar las fuentes coincidentes y las que deben conservar la lectura base.

3. **Aplicar la escritura.** Dar el flanco habilitado y comprobar el valor postflanco del Register File. Durante HOLD o con una guarda deshabilitada, exigir ausencia de escritura.

4. **Aplicar reset o preparación.** En sus dos variantes, comprobar que `x1…x31` se pongan en cero en paralelo, incluso cuando WB sea elegible en ese flanco.

5. **Observar Debug.** Seleccionar cada uno de los 32 registros mediante la primera lectura y comprobar que la segunda continúe leyendo `x2`. Comparar el dato base del banco, antes del bypass.

### Resultados y criterio de aprobación

Las dos lecturas deben ser combinacionales y simultáneas. El bypass entrega 7 únicamente cuando la fuente coincide con una escritura elegible; en los demás casos se observa el valor actual del Register File. `x0` permanece siempre en cero.

La escritura elegible utiliza el `wb_value` preflanco y ocurre una sola vez. Reset y preparación ponen `x1…x31` en cero e impiden esa escritura coincidente.

Debug debe leer el dato base mediante el puerto existente, sin bypass ni tercer puerto. La aprobación exige que las coincidencias, guardas y 32 direcciones produzcan sus resultados previstos, sin depender de residuos para mantener `x0=0`.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-003"></a>

## TEST-PIPE-003 — Forwarding disponible y prioridad por fuente

- **Nivel:** unidad forwarding/EX y CPU.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-006](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-002](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-003](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-005](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-006](../requirements.md#4-hazards-y-cambios-de-flujo).

**Contratos:** [control_and_hazards](../architecture/cpu/control_and_hazards.md); [stage_ex](../architecture/cpu/stage_ex.md).

### Qué comprueba y por qué

Esta prueba comprueba que el forwarding seleccione el productor más reciente disponible para cada fuente de EX.

Busca detectar una prioridad invertida entre EX/MEM y MEM/WB, la ausencia de una guarda de elegibilidad o una conexión que reenvíe datos a la ALU pero no al store, al branch o a JALR.

Los vectores locales comprueban las decisiones de selección. Los cinco programas comprueban que esas decisiones se apliquen a los caminos reales de operandos de la CPU.

### Condiciones iniciales

En unidad, el valor base del operando es 3, el resultado disponible de EX/MEM es 7 y el valor de MEM/WB es 5. La fuente utilizada tiene índice 1. Los datos y las señales de control corresponden al estado preflanco.

Las fuentes A y B se comprueban por separado; la otra fuente no tiene coincidencia. En las variantes de `rd=0`, la fuente también es cero y su valor base es cero.

Para una fuente no utilizada, el consumidor de A es LUI y el de B es ADDI con un campo aparente `rs2=1`. Para el consumidor inválido, los bits codifican ADD pero `ID/EX.valid=0`. El uso de fuentes se deriva de la instrucción; no se fuerza mediante un puerto `uses_rs` inventado.

Los cinco programas comienzan con una sesión limpia y preparan sus operandos mediante las instrucciones indicadas.

### Variantes cerradas

La prueba tiene 29 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-003/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Se ejecutan ocho selecciones locales: solo coincide EX/MEM, solo coincide MEM/WB, coinciden ambos o no coincide ninguno, para cada fuente A y B.

Los 12 casos de productor no elegible cambian una de tres guardas para cada productor y cada fuente. Se utiliza una configuración que evidencia cada guarda, sin repetirla contra una ausencia de coincidencia.

Los cuatro casos de consumidor no elegible combinan una fuente no utilizada o una entrada inválida con A y B. Los cinco casos restantes son los programas A a E: ALU, fuentes mixtas, store, branch y JALR.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para el caso `C025`, correspondientes al escenario A, se utiliza el siguiente programa:

```asm
addi x1,x0,3
addi x1,x1,4
add x2,x1,x1
halt
```

Para el caso `C026`, correspondientes al escenario B, se utiliza el siguiente programa:

```asm
addi x1,x0,3
addi x2,x0,4
add x3,x1,x2
halt
```

Para el caso `C027`, correspondientes al escenario C, se utiliza el siguiente programa:

```asm
addi x1,x0,4
addi x2,x0,7
sw x2,0(x1)
halt
```

Para el caso `C028`, correspondientes al escenario D, se utiliza el siguiente programa:

```asm
addi x1,x0,7
addi x2,x0,7
beq x1,x2,8
addi x4,x0,99
halt
```

Para el caso `C029`, correspondientes al escenario E, se utiliza el siguiente programa:

```asm
addi x1,x0,12
jalr x5,x1,0
addi x4,x0,99
halt
```

### Procedimiento

1. **Preparar los productores locales.** Instalar los valores 3, 7 y 5 y la coincidencia de la variante.

2. **Observar la selección.** Comparar el selector `00`, `01` o `10` y el dato efectivo de cada fuente. Cuando ambos productores elegibles coinciden, EX/MEM debe prevalecer.

3. **Comprobar las guardas.** Deshabilitar una sola condición del productor. Si EX/MEM deja de ser elegible, comprobar cuándo vuelve a seleccionarse el MEM/WB anterior. Con `x0`, ninguno debe seleccionarse.

4. **Comprobar el consumidor.** En los cuatro casos de fuente no utilizada o entrada inválida, verificar que se seleccione el valor base.

5. **Ejecutar los programas.** Desde una sesión limpia, observar los operandos efectivos y comparar los resultados finales. No deben aparecer stalls por productores cuyos resultados ya están disponibles.

### Resultados y criterio de aprobación

En los cuatro patrones nominales, el dato debe ser 7 cuando solo coincide EX/MEM, 5 cuando solo coincide MEM/WB, 7 cuando coinciden ambos y 3 cuando no coincide ninguno. Las fuentes A y B se resuelven independientemente.

Los programas deben producir:

- A: `x1=7` y `x2=14`.
- B: `x3=7`, usando MEM/WB para `x1` y EX/MEM para `x2`.
- C: la palabra de DMEM en dirección 4 contiene 7, con base y dato obtenidos de productores distintos.
- D: el branch toma el destino 16 y no escribe `x4`.
- E: JALR toma el destino 12, conserva el enlace 8 y deja `x4=0`.

Los programas terminan por `halt`. El forwarding permanece combinacional, sin nuevos registros o campos ni stalls para resultados disponibles. La aprobación requiere que los 29 casos coincidan en selector, dato y efectos de los cinco caminos de operandos.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-004"></a>

## TEST-PIPE-004 — Load reciente oculta un productor obsoleto

- **Nivel:** unidad forwarding e integración hazard.
- **Tipo de estímulo:** artificial local y legal CPU.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-HAZ-002](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-003](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-004](../requirements.md#4-hazards-y-cambios-de-flujo).

**Contratos:** [control_and_hazards](../architecture/cpu/control_and_hazards.md); [architectural_invariants](../architecture/architectural_invariants.md).

### Qué comprueba y por qué

Esta prueba comprueba que un load más reciente impida reenviar una versión obsoleta del mismo registro desde MEM/WB.

Busca detectar que la dirección efectiva del load se utilice como si fuera el dato cargado o que se sustituya ese dato todavía no disponible por el valor antiguo de otro productor.

Los dos casos artificiales comprueban la ecuación local de forwarding. El programa legal comprueba que el stall previo evite que el consumidor llegue a EX en esa combinación.

### Condiciones iniciales

En el fixture artificial, EX/MEM contiene un load hacia `rd=1`, el valor base es 3 y MEM/WB contiene una versión anterior con valor 5. Se fuerza únicamente el bloque local, una vez para cada fuente. Este estado no demuestra alcanzabilidad end-to-end.

En CPU se prepara una sesión limpia con la palabra de DMEM en dirección cero igual a 7. El programa escribe primero la versión 5 de `x1`, la reemplaza mediante el load y luego ejecuta el consumidor.

### Variantes cerradas

La prueba tiene 3 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-004/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los dos vectores locales comprueban las fuentes A y B cuando el productor reciente es un load. El tercer caso ejecuta el programa legal indicado a continuación.

La prueba local y la ejecución legal verifican obligaciones diferentes; la inyección no autoriza agregar un interlock de EX para hacerla ejecutable.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para el caso `C003`, se utiliza el siguiente programa:

```asm
addi x1,x0,5
lw x1,0(x0)
add x2,x1,x1
halt
```

### Procedimiento

1. **Aplicar el fixture artificial.** Presentar el load reciente y el productor antiguo. Observar la selección de ambas fuentes sin interpretar la dirección del load como un resultado arquitectónico disponible.

2. **Preparar y ejecutar el programa legal.** Cargar la palabra 7 en el estado lógico de DMEM y comenzar la sesión.

3. **Observar el ciclo de dependencia.** Cuando el load esté en EX y el consumidor en ID, comprobar que se introduzca exactamente una bubble.

4. **Seguir el dato hasta el consumidor.** Verificar que la combinación artificial no aparezca en la trayectoria legal y que ADD utilice finalmente 7.

5. **Comparar los efectos.** Ejecutar hasta `halt` y comprobar el Register File, sin añadir mecanismos que cambien la arquitectura para admitir el fixture.

### Resultados y criterio de aprobación

En unidad no debe seleccionarse la dirección de EX/MEM como dato ni el valor antiguo 5 de MEM/WB. La coincidencia `exmem_match` bloquea el fallback, aunque el dato del load no esté disponible.

Que permanezca seleccionada la entrada base no significa que se permita ejecutar ese estado artificial en CPU. En la ejecución legal, el stall ocurre antes de que el consumidor llegue a EX y evita esa combinación.

Al terminar el programa, `x1=7` y `x2=14`. La aprobación requiere las dos guardas locales y la prevención mediante el stall legal, sin introducir un nuevo interlock de EX.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-005"></a>

## TEST-PIPE-005 — Load-use en los consumidores efectivos

- **Nivel:** CPU y unidad detector.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-002](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-004](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-005](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-006](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [control_and_hazards](../architecture/cpu/control_and_hazards.md); [stage_id](../architecture/cpu/stage_id.md).

### Qué comprueba y por qué

Esta prueba comprueba que el detector de load-use reconozca todos los consumidores reales del resultado de un load inmediato.

Busca detectar una pausa que contemple solamente la ALU y omita la base o el dato de un store, los operandos de un branch, la base de JALR o la dirección de otro load.

La variante STEP comprueba además que el stall consuma un ciclo efectivo, aunque el PC y parte del pipeline permanezcan retenidos.

### Condiciones iniciales

La imagen comienza con `lw x1,0(x0)` en `PC=0` y el consumidor de la variante en `PC=4`. La palabra de DMEM en dirección cero contiene 8, la de dirección 8 contiene 13 y `x2=3`.

La continuación depende del consumidor:

- Para BEQ, `PC=8` contiene `addi x4,x0,99` y `PC=12` contiene `halt`.
- Para JALR, `PC=8` contiene `halt` y `PC=12` contiene `addi x4,x0,99`.
- En las demás variantes, `halt` ocupa `PC=8`.

Las instrucciones del camino descartado utilizan `x0` como fuente. El estado preparado de `x4` permite observar si una de ellas hace un commit indebido.

### Variantes cerradas

La prueba tiene 9 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-005/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los ocho consumidores en RUN son ADD con dependencia en rs1, rs2 o ambas fuentes; store con dependencia en la base o en el dato; branch; JALR; y load con dependencia en la base. Solo ADD que utiliza `rs1` se repite en STEP.

No se combinan todos los consumidores con todos los modos. Los nueve casos ya incluyen la selección completa de consumidores, fuentes y la repetición temporal indicada.

### Procedimiento

1. **Preparar la imagen y los datos.** Cargar el consumidor y su continuación, junto con los valores del Register File y del estado lógico de DMEM.

2. **Llegar al ciclo de dependencia.** Avanzar hasta que el load esté en EX y el consumidor en ID. Guardar el PC y los cinco campos de IF/ID en preflanco.

3. **Observar el stall en postflanco.** Comprobar la retención completa del PC y de IF/ID, la bubble de ID/EX y el avance del load y del trabajo anterior.

4. **Seguir el forwarding.** En el ciclo posterior a la captura del consumidor, observar que utilice el dato de MEM/WB y comparar su resultado con la variante.

5. **Comprobar STEP.** Después del stall, esperar 50 clocks físicos. El contador debe haber aumentado una sola vez y no debe ejecutarse automáticamente otro ciclo.

### Resultados y criterio de aprobación

Cada dependencia nominal debe introducir exactamente un stall. Se retienen el PC y los cinco campos de IF/ID; `ID/EX.next.valid=0`, el load avanza a EX/MEM y el trabajo anterior continúa hacia MEM/WB.

Después, el consumidor utiliza el dato de MEM/WB. Los ADD producen 11, 11 o 16 según sus fuentes; los stores escriben 3 en dirección 8 u 8 en dirección 4. BEQ toma el destino 12, JALR toma 8 y ninguno modifica `x4`. El LW cuya base proviene del load devuelve 13.

El stall incrementa el contador y consume el único STEP aceptado. No debe existir un ciclo automático adicional ni pérdida o duplicación de instrucciones.

La aprobación exige todas las clases de consumidor y ambas fuentes. En la comprobación de load fallido de TEST-EXEC-004, el consumidor joven no se ejecuta.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-006"></a>

## TEST-PIPE-006 — Ausencia de dependencias falsas

- **Nivel:** unidad detector y CPU.
- **Tipo de estímulo:** legal y flags locales controlados.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-013](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-015](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-003](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-004](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-005](../requirements.md#4-hazards-y-cambios-de-flujo).

**Contratos:** [stage_id](../architecture/cpu/stage_id.md); [control_and_hazards](../architecture/cpu/control_and_hazards.md).

### Qué comprueba y por qué

Esta prueba comprueba que una coincidencia de bits produzca load-use únicamente cuando representa una fuente realmente consumida por una instrucción válida.

Busca detectar pausas o bypass por campos que no son operandos, por flags inválidos o por un load cuyo destino es `x0`. También comprueba que un candidato de fetch no se interprete como una instrucción consumidora.

### Condiciones iniciales

En el detector local se prepara un load válido en ID/EX con `rd=1`. Cada variante modifica una sola condición de la selección indicada y mantiene neutras las demás guardas.

La palabra del consumidor pertenece a la clase de su caso. Para la entrada inválida y el candidato de fetch, sus bits aparentan un ADD con fuentes coincidentes, pero `IF/ID.valid=0`. Solo el candidato tiene `fetch_fault_valid=1`.

El programa legal prepara una palabra 7 en DMEM y ejecuta un load a `x0` seguido de un consumidor de ese registro. El acceso a memoria continúa existiendo, aunque el destino no pueda escribirse.

### Variantes cerradas

La prueba tiene 10 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-006/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Nueve casos locales comprueban las condiciones enumeradas en la subsección siguiente. LUI y JAL utilizan palabras cuyos campos aparentes coinciden con el destino del load, aunque esas instrucciones no consuman las fuentes.

El décimo caso ejecuta el programa legal de load a `x0`. La validación de la dirección de ese acceso se conserva; el hecho de no escribir un registro no elimina sus posibles faults.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para el caso `C010`, se utiliza el siguiente programa:

```asm
lw x0,0(x0)
addi x3,x0,1
halt
```

### Las nueve situaciones locales

Las condiciones conservan los nombres que utiliza el [manifiesto](cases.json):

- **`ADDI-rs2-aparente`.** El campo aparente de rs2 pertenece al inmediato de ADDI y no representa una segunda fuente. Esta condición no debe producir load-use.
- **`LUI-sources-aparentes`.** LUI no consume las fuentes aparentes de sus campos. Esta condición no debe producir load-use.
- **`JAL-sources-aparentes`.** JAL no consume las fuentes aparentes de sus campos. Esta condición no debe producir load-use.
- **`halt`.** halt no consume operandos de registro. Esta condición no debe producir load-use.
- **`illegal`.** Una palabra ilegal no se habilita como consumidor de registro. Esta condición no debe producir load-use.
- **`ifid-invalid`.** Los bits coincidentes pertenecen a una entrada inválida de IF/ID. Esta condición no debe producir load-use.
- **`fetch-candidate`.** La entrada transporta un candidato de fetch y no una instrucción consumidora. Esta condición no debe producir load-use.
- **`load-invalid`.** El productor de ID/EX no es una entrada válida. Esta condición no debe producir load-use.
- **`load-rd0`.** El load tiene destino x0 y no produce una dependencia de dato. Esta condición no debe producir load-use.

El manifiesto concreta instrucción, flags y fuentes de cada situación. El programa adicional de load a x0 comprueba que sigue existiendo el acceso a memoria y que el consumidor de x0 usa cero.

### Procedimiento

1. **Preparar la condición local.** Instalar el load y la palabra del consumidor. Derivar `uses_rs1` y `uses_rs2` mediante la decodificación real, sin forzar usos contradictorios con esa palabra.

2. **Aplicar una sola variación.** Mantener válido el resto del load. En los casos de load inválido o `rd=0`, modificar únicamente la condición indicada.

3. **Observar el detector.** Comparar `load_use_stall` con cero para cada situación y revisar que los campos no utilizados no habiliten bypass.

4. **Ejecutar el programa legal.** Seguir el acceso de `lw x0,0(x0)` y el consumidor posterior, hasta `halt`.

5. **Comparar el resultado y las guardas.** Comprobar `x0=0`, `x3=1` y ausencia de stall por dependencia, sin suprimir la validación propia de memoria.

### Resultados y criterio de aprobación

Todos los casos locales deben producir `load_use_stall=0`. Solo cuentan las fuentes usadas por una instrucción válida; un candidato de fetch no es consumidor.

El programa de CPU conserva `x0=0` y deja `x3=1`, sin stall por dependencia de dato. El load hacia `x0` sigue siendo un acceso de memoria válido sujeto a sus comprobaciones de fault.

La aprobación requiere ausencia de pausas y bypass por campos no utilizados, entradas inválidas o `x0`. Ninguna de esas guardas debe cancelar un fault propio de una operación válida.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-007"></a>

## TEST-PIPE-007 — Ocho acciones y actualizaciones preflanco

- **Nivel:** unidad hazard y registros interetapa.
- **Tipo de estímulo:** entradas locales controladas; drain-load-use artificial.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-009](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-004](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-010](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-EXEC-018](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [control_and_hazards](../architecture/cpu/control_and_hazards.md); [cpu_pipeline](../architecture/cpu/cpu_pipeline.md).

### Qué comprueba y por qué

Esta prueba comprueba que Pipeline Hazard Control seleccione una única acción coherente y que los latches se actualicen con los datos preflanco de esa acción.

Busca detectar dos acciones activas a la vez, una prioridad equivocada entre eventos, un HOLD tratado como avance o una captura que utilice datos recién registrados en el mismo flanco.

Las coincidencias locales comprueban el árbitro. El caso de drain con load-use es artificial: verifica una ecuación de control, pero no demuestra una ejecución alcanzable desde reset.

### Condiciones iniciales

El PC comienza en `0x40` y el destino de redirect es `0x80`. Cada latch tiene un payload distinto del de los demás latches y del de su entrada futura, para distinguir retención de captura.

En cada caso se presentan `cpu_cycle_fire`, `drain_mode` y los candidatos y condiciones mínimos que producen el evento indicado; los restantes valen cero. `drain_mode=0` selecciona el contexto normal y `drain_mode=1` el de drenado. Los payloads y flags de los latches representan el trabajo pendiente.

La dependencia de load-use durante drain se fuerza solamente en el bloque local. Los fixtures no autorizan nuevas señales, estados o trayectorias de CPU.

### Variantes cerradas

La prueba tiene 21 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-007/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los ocho primeros casos comprueban las ocho acciones habilitadas. Otros ocho utilizan los mismos testigos con `cpu_cycle_fire=0` y deben retener el estado.

Un caso prepara FINISHED con el pipeline vacío. Los cuatro casos restantes comprueban pares adyacentes de prioridad entre eventos: fault de EX y halt, halt y redirect, redirect y fault de ID, y fault de ID y load-use.

La prioridad de load-use sobre el avance normal ya se observa en su fila. Normal es la selección por defecto, no un candidato adicional que deba cruzarse con las demás señales.

### Testigos y actualizaciones concretas

El [manifiesto](cases.json) fija los controles de ciclo y drenado, el PC, el destino y los cinco candidatos o condiciones locales de cada caso.

Para comprobar una fila se activa únicamente su candidato y los demás permanecen en cero. `act_normal` utiliza todos en cero. Los drains se presentan con `drain_mode=1` y trabajo pendiente; solo el caso artificial de drain-load-use activa esa dependencia.

En los pares de prioridad se activan los dos candidatos indicados. Son fixtures del bloque de control; no se presentan como instrucciones que puedan llegar juntas en una CPU legal.

| Acción                    | PC      | IF/ID                 | ID/EX       | EX/MEM      | MEM/WB       |
|---------------------------|---------|-----------------------|-------------|-------------|--------------|
| EX fault                  | Retener | Invalidar ambos flags | Bubble      | Invalidar   | Capturar MEM |
| Halt                      | Retener | Invalidar ambos flags | Bubble      | Invalidar   | Capturar MEM |
| Redirect                  | 0x80    | Invalidar ambos flags | Bubble      | Capturar EX | Capturar MEM |
| ID fault                  | Retener | Invalidar ambos flags | Bubble      | Capturar EX | Capturar MEM |
| Load-use                  | Retener | Retener cinco campos  | Bubble      | Capturar EX | Capturar MEM |
| Normal                    | 0x44    | Capturar IF           | Capturar ID | Capturar EX | Capturar MEM |
| Drain-load-use artificial | Retener | Retener cinco campos  | Bubble      | Capturar EX | Capturar MEM |
| Drain-advance             | Retener | Invalidar ambos flags | Capturar ID | Capturar EX | Capturar MEM |

Los payloads que se retienen o capturan se comparan con sus valores preflanco. Invalidar una entrada o insertar una bubble no exige borrar sus otros bits. En los ocho casos sin ciclo, todos los registros y el PC deben conservarse.

### Procedimiento

1. **Preparar el testigo.** Instalar los valores de PC, payloads, `cpu_cycle_fire`, `drain_mode` y candidatos de la variante, conforme a la tabla de acciones.

2. **Observar la acción preflanco.** Con un ciclo habilitado, comprobar que se seleccione exactamente una acción y que corresponda a la prioridad prevista.

3. **Aplicar el flanco.** Comparar el PC, ambos flags de IF/ID y la validez de cada latch con la tabla. Cuando se retenga IF/ID, comparar sus cinco campos.

4. **Comprobar ausencia de avance.** En los ocho casos sin ciclo y en el terminal vacío, verificar que ninguna acción se seleccione y que no haya escritura de CPU.

5. **Aplicar los pares de prioridad.** Activar los dos eventos de cada par y comprobar cuál prevalece, sin convertir el fixture en una promesa de alcanzabilidad legal.

### Resultados y criterio de aprobación

En cada ciclo habilitado debe seleccionarse una sola acción; en los pares debe prevalecer la de mayor prioridad. El avance normal aplica `PC+4`, el redirect aplica `0x80` y las demás acciones retienen el PC.

Load-use conserva los cinco campos de IF/ID. Invalidar IF/ID limpia `valid` y `fetch_fault_valid`; insertar una bubble limpia su validez. No se exige borrar los bits restantes de un payload inválido.

Todas las capturas utilizan productores preflanco. MEM/WB captura MEM en cada acción habilitada. En HOLD y en el terminal vacío no se selecciona ninguna acción ni se produce avance.

La aprobación exige las ocho filas y la ausencia de acción en los casos correspondientes. HOLD no debe convertirse en una novena acción. La fila de drain-load-use demuestra únicamente la lógica artificial indicada.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-008"></a>

## TEST-PIPE-008 — Wrong-path y fronteras por antigüedad

- **Nivel:** CPU e integración hazard.
- **Tipo de estímulo:** legal; combinación EX/ID local indicada.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-HAZ-007](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-008](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-009](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-010](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-EXEC-004](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-013](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-018](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [faults_and_termination](../architecture/session/faults_and_termination.md); [control_and_hazards](../architecture/cpu/control_and_hazards.md).

### Qué comprueba y por qué

Esta prueba comprueba que las instrucciones descartadas no produzcan efectos y que la frontera de terminación se elija según el orden de las instrucciones.

Busca detectar un fault o halt confirmado desde el camino descartado, un store joven que alcance DMEM o la cancelación de un commit anterior por un evento posterior.

Las ejecuciones legales comprueban los efectos del wrong-path. Los cuatro casos locales permiten observar las coincidencias de eventos y los commits anteriores en el mismo flanco.

### Condiciones iniciales

El programa de branch coloca `beq x1,x1,12` en `PC=0`. En `PC=4` hay `halt` o la palabra ilegal cero; en `PC=8`, `sw x2,0(x0)`; y en `PC=12`, `halt`. El banco prepara `x2=2`.

El programa de loop contiene únicamente `jal x0,0`. Las otras dos secuencias terminales colocan `halt` y la palabra ilegal cero en `PC=0` y `PC=4`, en ambos órdenes.

En los casos locales se preparan instrucciones anteriores con un store de valor 3 en MEM y un writeback de valor 11. Estos valores permiten comprobar que la selección de una frontera joven conserve los efectos anteriores.

### Variantes cerradas

La prueba tiene 9 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-008/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los cinco programas son las dos variantes del branch, el loop, la secuencia con `halt` antes de la palabra ilegal y la secuencia con la palabra ilegal antes de `halt`.

Los cuatro pares locales de eventos están enumerados en el [manifiesto](cases.json). En cada uno se observan los dos commits anteriores en el mismo ciclo, sin agregar nuevas combinaciones de causas.

### Procedimiento

1. **Preparar y ejecutar los programas.** Seguir el branch y comprobar que la palabra cero o el `halt` del camino descartado no se confirmen. Observar el loop durante 20 ciclos, sin exigir que termine.

2. **Comparar las dos secuencias terminales.** Verificar cuál instrucción alcanza primero su frontera y comprobar que la posterior no sustituya ese resultado.

3. **Preparar las coincidencias locales.** Guardar el store y el writeback preflanco y activar los eventos de EX e ID del caso.

4. **Observar la selección y los efectos.** Comparar la frontera elegida y los flags postflanco. Las instrucciones jóvenes deben descartarse; el store y el writeback anteriores deben conservar sus commits.

5. **Revisar los metadatos.** Comprobar que correspondan al evento confirmado, sin sustituirlos por un candidato descartado.

### Resultados y criterio de aprobación

Las dos variantes del branch terminan normalmente, sin fault ni store del camino descartado. El loop continúa en RUNNING, sin fault confirmado ni FINISHED.

La secuencia que coloca primero `halt` finaliza normalmente. La que coloca primero la palabra ilegal termina por causa 2 con `fault_pc=0`, sin confirmar el `halt` joven.

En las coincidencias locales prevalece EX sobre el candidato posterior de ID o el stall joven. Cada commit anterior elegible se conserva, incluso en el flanco de confirmación.

La aprobación exige ausencia de efectos de las instrucciones descartadas y conservación de los efectos anteriores. La prioridad debe responder a la antigüedad de instrucciones, no a un orden global entre causas distintas.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-009"></a>

## TEST-PIPE-009 — WB final, commits únicos y HOLD

- **Nivel:** unidad MEM/WB y CPU.
- **Tipo de estímulo:** legal y entradas locales controladas.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-007](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-008](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), [REQ-EXEC-003](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-009](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-HAZ-010](../requirements.md#4-hazards-y-cambios-de-flujo).

**Contratos:** [stage_mem](../architecture/cpu/stage_mem.md); [stage_wb](../architecture/cpu/stage_wb.md); [architectural_invariants](../architecture/architectural_invariants.md).

### Qué comprueba y por qué

Esta prueba comprueba que MEM forme el único valor de writeback y que WB escriba el valor registrado antes del flanco. También verifica que HOLD no repita commits.

Busca detectar una selección duplicada en WB, el uso del dato futuro 99 en lugar del valor actual 7 o la repetición de un store o writeback mientras STEP conserva una etapa ocupada durante varios clocks físicos.

### Condiciones iniciales

En unidad se preparan las dos fuentes de resultado de MEM. MEM/WB contiene el valor actual 7 y la entrada futura permite distinguirlo del valor 99.

En CPU se carga `addi x1,x0,7; sw x1,0(x0)`, seguido de `halt` o de una palabra ilegal. La sesión comienza preparada.

El banco identifica cada instancia dinámica mediante sus eventos de ejecución, sin agregar estado arquitectónico. Esto permite contar commits aunque el PC de una instrucción pueda repetirse en otros programas.

### Variantes cerradas

La prueba tiene 11 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-009/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Dos casos comprueban la selección de resultado en MEM. Otros cinco comprueban WB: la situación nominal y sus cuatro guardas, utilizando siempre el valor actual 7 frente al futuro 99.

Los cuatro programas de CPU combinan terminación por `halt` o por instrucción ilegal con RUN o STEP. En STEP se espera 50 clocks con el store en MEM y otros 50 con WB activo; ambas esperas pertenecen a la misma ejecución.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para los casos `C008`, `C009`, se utiliza el siguiente programa:

```asm
addi x1,x0,7
sw x1,0(x0)
halt
```

Para los casos `C010`, `C011`, se utiliza el siguiente programa:

```asm
addi x1,x0,7
sw x1,0(x0)
illegal
```

### Procedimiento

1. **Preparar las fuentes de MEM y WB.** Presentar sus valores y guardar MEM/WB en preflanco.

2. **Capturar el resultado de MEM.** Comparar el `wb_value` registrado. Al escribir el Register File, exigir el valor de MEM/WB anterior al flanco, no la entrada que acaba de capturarse.

3. **Comprobar las guardas de WB.** Negar una por vez y verificar ausencia de escritura.

4. **Ejecutar los programas.** En STEP, introducir las dos esperas de 50 clocks en HOLD, con el tráfico UART permitido, y luego avanzar hasta el terminal.

5. **Contar los commits.** Comprobar un store y un writeback por instancia dinámica, incluidos los flancos donde se confirme un `halt` o fault joven.

6. **Revisar la selección del RTL.** Confirmar que el valor se seleccione en MEM y que WB no duplique esa decisión.

### Resultados y criterio de aprobación

MEM debe seleccionar `11223344` o `FFFFFF80`, según el caso. WB escribe el valor 7 preflanco y no el valor 99 que llega a la entrada.

En CPU, el estado terminal debe contener `x1=7` y la palabra cero de DMEM igual a 7. Cada store y writeback produce un único commit por instancia.

Durante HOLD se conservan el Register File, DMEM, PC, latches y contador. No se repiten commits. La confirmación de un `halt` o fault joven no veta el store o writeback anterior del mismo flanco.

La aprobación requiere los datos preflanco correctos, todas las guardas y la cuenta de commits, además de la selección única en MEM comprobada en el RTL.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-pipe-010"></a>

## TEST-PIPE-010 — Fetch candidato, load-use y fronteras anteriores

- **Nivel:** CPU e integración CPU/control.
- **Tipo de estímulo:** secuencias de CPU y comandos elegibles, con datos iniciales de fixture explícitos; no se fuerzan candidatos ni latches.
- **Estado:** diseñada, sin ejecutar contra RTL.

**Requisitos:** [REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-004](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-007](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-008](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-009](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-010](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-MEM-016](../requirements.md#5-memorias-y-carga-de-programas), [REQ-EXEC-015](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-018](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [acuerdo 47](../decisions/DEC-ARCH-003.md#acuerdo-47-aprobado--confirmación-de-todo-fetch-fault-en-id-y-revisión-de-aud-001); [stage_if](../architecture/cpu/stage_if.md); [faults_and_termination](../architecture/session/faults_and_termination.md); [execution_control](../architecture/session/execution_control.md).

### Qué comprueba y por qué

Esta prueba recorre la coincidencia de un load-use con un candidato de fetch fuera de imagen, su retención, captura posterior y resolución frente a la instrucción consumidora anterior. Debe detectar tanto confirmaciones prematuras como la pérdida del redirect, fault propio o commit del consumidor.

También comprueba la prioridad del fault del load productor, halt frente al candidato y el abandono de sesión por reset o LOAD aceptado. Las coincidencias se alcanzan ejecutando las instrucciones indicadas, sin inyectar señales de fault. Los casos de STEP incluyen HOLD entre ciclos efectivos.

### Condiciones iniciales

Se utiliza REFERENCE, sesión preparada, PC y contador cero, latches vacíos e imagen confirmada de ocho bytes. No se agrega una continuación ni halt implícito. El fixture CPU instala únicamente `word0` de DMEM y las excepciones RF de la tabla; RF y el resto de DMEM son cero. Con `word0` distinto de cero se instalan sus cuatro marcas de validez, sin contar como store CPU; con `word0=0` se conserva DMEM en cero lógico y sin marcas utilizadas. Se conserva una copia inicial de datos/marcas para detectar cambios. No se presenta este setup como una carga de datos por UART ni como un programa completo de placa.

### Variantes cerradas y programas concretos

La prueba tiene 20 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-PIPE-010/Cnnn`, palabras de instrucción, entradas, acciones, PCs y resultados. No hay producto cartesiano implícito.

Cada fila coloca la primera instrucción en PC=0 y la segunda en PC=4. Las cantidades son decimales; las causas conservan sus códigos arquitectónicos.

| Caso RUN | Caso STEP/HOLD | Programa de ocho bytes      | `word0` / RF adicional | Resultado                                                      |
|----------|----------------|-----------------------------|------------------------|----------------------------------------------------------------|
| C001     | C010           | `lw x1,0(x0); add x2,x1,x1` | 7                      | FAULT, causa 1, PC=8; x1=7, x2=14; 7 ciclos                    |
| C002     | C011           | `lw x1,0(x0); beq x1,x0,-4` | 0                      | Loop a PC=0 sin fault; observar 20 ciclos                      |
| C003     | C012           | `lw x1,0(x0); beq x1,x0,-4` | 7                      | Branch no tomado; FAULT, causa 1, PC=8; 7 ciclos               |
| C004     | C013           | `lw x1,0(x0); jalr x5,x1,0` | 0                      | Loop a PC=0, enlace x5=8, sin fault; observar 20 ciclos        |
| C005     | C014           | `lw x1,0(x0); jalr x5,x1,0` | 2; x5=55               | FAULT, causa 0, PC=4; x5 conserva 55; 5 ciclos                 |
| C006     | C015           | `lw x1,0(x0); sw x1,2(x0)`  | 0                      | FAULT, causa 6, PC=4; sin store ni cambio de marcas; 5 ciclos  |
| C007     | C016           | `lw x1,0(x0); lw x2,2(x1)`  | 0; x2=55               | FAULT, causa 4, PC=4; x2 conserva 55; 5 ciclos                 |
| C008     | —              | `lw x1,2(x0); add x2,x1,x1` | 7; x2=55               | Gana fault del productor: causa 4, PC=0; x1=0, x2=55; 3 ciclos |
| C009     | —              | `lw x1,0(x0); halt`         | 7                      | Halt descarta candidato ID; FINISHED con x1=7; 5 ciclos        |

En C010–C016 se solicita un STEP por ciclo, incluidos stall y drains, y se insertan 50 clocks de HOLD después de los ciclos efectivos 2, 3 y 4 de la primera iteración. En los loops, el límite de 20 ciclos no equivale a FINISHED: al terminar la observación permanecen RUNNING o STEPPING según el modo, y se recuperan por reset externo. C009 no tiene load-use: halt no consume x1; comprueba por separado la frontera anterior exigida por la matriz.

Las cuatro variantes restantes utilizan `lw x1,0(x0); add x2,x1,x1`, `word0=7`, RF cero y avance STEP:

| Caso | Momento postflanco alcanzado                                          | Intervención en el siguiente flanco | Resultado inmediato                                                                   |
|------|-----------------------------------------------------------------------|-------------------------------------|---------------------------------------------------------------------------------------|
| C017 | Ciclo 3: stall realizado; consumidor retenido y candidato solo en IF  | RESET                               | NO_IMAGE, contador/PC/RF cero, latches inválidos                                      |
| C018 | Ciclo 4: candidato registrado en IF/ID; consumidor en EX y load en WB | RESET                               | Mismo reset; no se confirma candidato ni compromete WB                                |
| C019 | Ciclo 3                                                               | LOAD aceptado desde STEPPING        | LOADING, tamaño cero, contador 3; latches retenidos, sin ciclo ni commits             |
| C020 | Ciclo 4                                                               | LOAD aceptado desde STEPPING        | LOADING, tamaño cero, contador 4; candidato registrado retenido, sin ciclo ni commits |

En C019/C020 se completa después una nueva imagen de cuatro bytes que contiene halt y su preparación. La inicialización de preparación limpia PC/RF/latches/contador; completar PREPARING_READY publica la imagen en READY, contador cero y DMEM sin posiciones utilizadas. No se exige borrar el candidato físicamente en el flanco de aceptación de LOAD: queda abandonado con la sesión y se limpia antes de que la nueva imagen pueda ejecutar. Los intercambios usan el contrato existente; no se crea una orden para instalar latches.

En C017–C020, `expected.fault_metadata_valid=false` expresa que el estado global
no valida un fault vigente; no representa un puerto ni un registro adicional.
`fault_confirm` y `fault_capture_fire` deben permanecer en cero. Según el
[contrato de metadatos](../architecture/session/faults_and_termination.md#metadata-persistente-del-fault),
RESET no exige borrar `fault_cause` ni `fault_pc`: C017/C018 no comparan sus
valores inactivos con cero. En C019/C020, `fault_metadata_retained=true` exige
conservar ambos valores preflanco al aceptar LOAD, sin imponer un valor inicial.
La preparación posterior tampoco exige borrarlos ni vuelve vigente un fault.
El código de causa cero identifica un fault de alineación de instrucción;
no significa ausencia de fault.

### Traza de referencia y procedimiento

Los ciclos se numeran desde el primer fetch efectivo, después de preparar la sesión. Las fuentes son preflanco. Para C001–C007 y sus repeticiones STEP, la secuencia inicial es:

| Ciclo efectivo | Situación preflanco                         | Acción y estado postflanco                                                                                                                            |
|----------------|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1              | PC=0, pipeline vacío                        | Normal: IF/ID contiene load PC0; PC=4                                                                                                                 |
| 2              | Load en ID, PC=4                            | Normal: consumidor en IF/ID, load en ID/EX; PC=8                                                                                                      |
| 3              | Load EX, consumidor ID, candidato IF en PC8 | Solo load-use: PC=8 e IF/ID conservan sus cinco campos; bubble ID/EX; load pasa a EX/MEM; no fault ni captura de candidato                            |
| 4              | Bubble EX, load MEM, consumidor ID          | Normal: consumidor pasa a ID/EX; candidato entra en IF/ID con valid=0, flag=1, causa=1, PC=8 e instrucción cero; load pasa a MEM/WB; PC=12            |
| 5              | Consumidor EX, candidato ID, load WB        | WB compromete x1. Redirect descarta candidato; fault EX propio lo desplaza; sin frontera EX, ID confirma fetch y conserva el avance de la EX anterior |

En C001/C003, ciclos 6 y 7 drenan EX/MEM y MEM/WB; ADD compromete x2 solamente en el 7. En C002/C004 se repite el patrón normal/normal/stall/normal/redirect cuatro veces: los redirects ocurren en ciclos 5/10/15/20 y dejan PC=0. El load compromete cuatro veces; JALR compromete tres enlaces antes del límite de observación, en ciclos 7/12/17. Cada instancia compromete una vez.

En C008, el ciclo 3 aplica fault EX del productor, aun con dependencia y candidato IF presentes: no aplica stall, no captura candidato y termina en FAULT sin writes. En C009, el ciclo 3 es normal y registra el candidato junto al halt que pasa a EX; el 4 confirma halt, deja únicamente WB del load y el 5 termina el drain en FINISHED. No confirma el fetch joven.

1. Poblar IMEM con las dos palabras publicadas y preparar el fixture de datos/RF. Guardar la referencia completa de DMEM y marcas.
2. Comparar en cada ciclo efectivo acción única, PC, identidades/flags de los latches, contador, metadatos y commits. Usar las acciones y PCs explícitos del manifiesto; no obtener el resultado esperado de las salidas del DUT.
3. En STEP, fotografiar PC, los cinco campos IF/ID, demás latches, RF, DMEM/marcas, contador y metadatos antes de cada HOLD. Durante sus 50 clocks no cambian y no hay acciones, confirmaciones ni commits. La redetección de IF no cuenta un ciclo.
4. Aplicar las intervenciones C017–C020 en sus estados alcanzados y observar tanto el flanco inmediato como, para LOAD, la preparación posterior. No atribuir a LOAD el borrado que corresponde a preparación.
5. Comparar el terminal o el límite finito del loop y la cantidad de commits por PC/instancia. Las únicas escrituras RF son las publicadas; DMEM y marcas conservan el estado inicial en todos los programas sin intervención.

### Resultados y criterio de aprobación

La confirmación de fetch solo ocurre desde ID y con el PC registrado de su candidato. El stall no captura ni confirma; redirect y halt descartan el candidato; un fault EX anterior conserva su causa/PC y suprime los efectos de su causante. El resultado del load previo se conserva cuando corresponde. HOLD y operaciones globales respetan sus prioridades.

Las comprobaciones reutilizadas de [TEST-PIPE-007](#test-pipe-007) cubren las ocho acciones/$onehot0; las de [TEST-PIPE-008](#test-pipe-008), otras fronteras wrong-path y commits anteriores. Conservan sus IDs y no sustituyen las secuencias conjuntas C001–C020.

Para aprobar se requiere la traza y los resultados de los 20 casos propios y las comprobaciones reutilizadas. El diseño de estas pruebas y sus recálculos documentales no acreditan ejecución contra RTL. Ante una contradicción, el contrato vigente conserva autoridad.

<a id="test-pipe-011"></a>

## TEST-PIPE-011 — Registro IF/ID aislado

- **Nivel:** Unidad.
- **Tipo de estímulo:** vectores de payload y controles locales aplicados a los puertos del registro.
- **Estado:** banco implementado; los resultados se registran por separado.

**Requisitos:** [REQ-CPU-009](../requirements.md#2-procesador-y-pipeline) y
[REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), limitados a IF/ID.

**Contratos:** [registro IF/ID](../architecture/cpu/cpu_pipeline.md#registro-ifid),
[interfaz](../interfaces.md#bloque-1-9) y
[reset funcional síncrono](../architecture/platform/reset_integration.md#efectos-del-reset-sobre-el-sistema).

El banco `if_id_register_tb` instancia únicamente `if_id_register` y el lector de
datos externo. El manifiesto define las secuencias, payloads, repeticiones y
expectativas de los diez casos. Cada paso cambia las entradas en el flanco
descendente, comprueba que el registro todavía conserve el estado anterior y
contrasta `valid_next` antes del flanco ascendente. Después del flanco compara
el estado registrado mediante igualdad estricta para detectar X/Z.

| Caso   | Comprobación                                                     |
| ------ | ---------------------------------------------------------------- |
| C001   | Captura y reemplazo de los cinco campos, incluida entrada vacía. |
| C002   | Captura de candidatos con causas 0 y 1; regreso a instrucción.   |
| C003   | Hold explícito de instrucción durante tres clocks.               |
| C004   | Hold explícito de candidato durante tres clocks.                 |
| C005   | Retención implícita de instrucción sin controles activos.        |
| C006   | Retención implícita de candidato sin controles activos.          |
| C007   | Invalidación de instrucción, repetición y nueva captura.         |
| C008   | Invalidación de candidato, repetición y nueva captura.           |
| C009   | RESET síncrono sobre captura, hold e invalidación.               |
| C010   | Inicialización de sesión sobre captura, hold e invalidación.     |

Las capturas comparan los cinco campos contra los valores esperados del JSON.
La expectativa `retained` compara los 69 bits con su copia preflanco;
`invalidated` compara solo `valid=0` y `fetch_fault_valid=0`, sin imponer valores
a los datos inactivos. Todos los casos comprueban el ancho de 69 bits y el reset
inicial. Las secuencias usan indicadores de instrucción y candidato excluyentes.
Captura, hold e invalidación son controles locales excluyentes; RESET e
inicialización de sesión pueden coincidir con ellos y deben prevalecer.

Este grupo acredita exclusivamente el registro. Los controles se inyectan desde
el banco; no se agrega lógica de IF, arbitraje ni control local al producto.
No acredita el programa, solapamiento ni estructura completa de
`TEST-PIPE-001/C001`, las acciones y prioridades de `TEST-PIPE-007/C001–C021`,
las fronteras de `TEST-PIPE-008/C001–C009`, los commits de
`TEST-PIPE-009/C001–C011` ni las secuencias de CPU/control de
`TEST-PIPE-010/C001–C020`. Sus estados y configuraciones conservan el alcance
previo; siguen pendientes los niveles de integración y CPU correspondientes.
El HOLD sin ciclo y la retención al aceptar LOAD se representan aquí únicamente
por ausencia de controles. Su generación real y la preparación posterior
requieren integración con el control de sesión.

<a id="test-pipe-012"></a>

## TEST-PIPE-012 — Registro ID/EX aislado

- **Nivel:** Unidad.
- **Tipo de estímulo:** vectores de payload y controles locales aplicados a los puertos del registro.
- **Estado:** banco implementado; los resultados se registran por separado.

**Requisitos:** [REQ-CPU-009](../requirements.md#2-procesador-y-pipeline) y
[REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), limitados a ID/EX.

**Contratos:** [registro ID/EX](../architecture/cpu/cpu_pipeline.md#registro-idex),
[interfaz](../interfaces.md#bloque-2-10) y
[reset funcional síncrono](../architecture/platform/reset_integration.md#efectos-del-reset-sobre-el-sistema).

El banco `id_ex_register_tb` instancia únicamente el registro y el lector de datos
externo. Los siete casos conservan estímulos y expectativas en el manifiesto.
Cada paso aplica controles y datos en el flanco descendente, comprueba estabilidad
del estado registrado y contrasta `valid_next` antes del flanco ascendente.
Después del flanco compara el estado con igualdad estricta para detectar X/Z.

| Caso   | Comprobación                                                                     |
| ------ | -------------------------------------------------------------------------------- |
| C001   | Captura preflanco y reemplazo de los quince campos con patrones complementarios. |
| C002   | Captura de entrada inválida con controles residuales y de payload cero.          |
| C003   | Retención de entrada válida durante tres clocks sin acción.                      |
| C004   | Retención de entrada inválida durante tres clocks sin acción.                    |
| C005   | Bubble repetida, retención posterior y nueva captura.                            |
| C006   | RESET síncrono sobre captura, retención y bubble.                                |
| C007   | Inicialización de sesión sobre captura, retención y bubble.                      |

Las capturas comparan los quince campos contra valores del JSON, incluidos ambos
operandos base, el inmediato y los seis controles. Los patrones de C001 alternan
todos los bits del payload salvo `valid`, cuya captura en cero se comprueba en
C002. Son vectores del registro: sus campos se ejercitan independientemente y
no se interpretan como instrucciones decodificadas ejecutables. C002 conserva
controles no nulos bajo `valid=0`, sin convertirlos en trabajo activo.

La expectativa `retained` compara los 193 bits con su copia preflanco;
`invalidated` exige solo `valid=0`, sin imponer valores a los datos y controles
inactivos. Todos los casos comprueban el ancho de 193 bits y el reset inicial.
Captura y bubble son controles locales excluyentes; RESET e inicialización de
sesión pueden coincidir con ellos y deben prevalecer. Sin controles se retiene.

Este grupo acredita exclusivamente el registro, con los datos y controles
inyectados desde el banco. El bypass WB→ID y su selección de operandos siguen
pendientes de integración. El módulo conserva los valores entregados en sus
puertos, sin incorporar Decoder, bypass, arbitraje ni controles de `processor_top`.
`TEST-PIPE-001/C001` conserva su ejecución de esquema de tipos al nivel Unidad;
su programa y estructura completa siguen pendientes. También siguen pendientes
las acciones de `TEST-PIPE-007/C001–C021`, las fronteras de
`TEST-PIPE-008/C001–C009`, los commits de `TEST-PIPE-009/C001–C011` y las
secuencias de CPU/control de `TEST-PIPE-010/C001–C020`. Sus IDs, cantidades,
estados y configuraciones no cambian. La generación real de controles para
HOLD, LOAD, drain y fronteras de instrucciones corresponde a la integración.

<a id="test-pipe-013"></a>

## TEST-PIPE-013 — Registro EX/MEM aislado

- **Nivel:** Unidad.
- **Tipo de estímulo:** vectores de payload y controles locales aplicados a los puertos del registro.
- **Estado:** banco implementado; los resultados se registran por separado.

**Requisitos:** [REQ-CPU-009](../requirements.md#2-procesador-y-pipeline) y
[REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), limitados a EX/MEM.

**Contratos:** [registro EX/MEM](../architecture/cpu/cpu_pipeline.md#registro-exmem),
[interfaz](../interfaces.md#bloque-3-15) y
[reset funcional síncrono](../architecture/platform/reset_integration.md#efectos-del-reset-sobre-el-sistema).

El banco `ex_mem_register_tb` instancia únicamente el registro y el lector de
datos externo. Los siete casos conservan estímulos y expectativas en el
manifiesto. Cada paso aplica controles y datos en el flanco descendente,
comprueba estabilidad del registro y contrasta `valid_next` antes del flanco
ascendente. Después del flanco compara el estado con igualdad estricta para
detectar X/Z.

| Caso   | Comprobación                                                                   |
| ------ | ------------------------------------------------------------------------------ |
| C001   | Captura preflanco de los ocho campos, con resultado y dato de store distintos. |
| C002   | Captura de entrada inválida con controles residuales y de payload cero.        |
| C003   | Retención de entrada válida durante tres clocks sin acción.                    |
| C004   | Retención de entrada inválida durante tres clocks sin acción.                  |
| C005   | Invalidación repetida, retención posterior y nueva captura.                    |
| C006   | RESET síncrono sobre captura, retención e invalidación.                        |
| C007   | Inicialización de sesión sobre captura, retención e invalidación.              |

Las capturas comparan los ocho campos contra el JSON. C001 utiliza patrones
complementarios en los bits del payload salvo `valid`; `ex_result` y
`store_data` tienen valores diferentes para detectar sustituciones entre
resultado/dirección y dato de store. C002 comprueba captura de `valid=0`,
incluidos controles no nulos, y luego reemplazo por payload cero. Son vectores
del registro; sus campos se ejercitan independientemente y no representan
instrucciones ejecutables ni accesos autorizados a memoria.

La expectativa `retained` compara los 139 bits con su copia preflanco;
`invalidated` exige solo `valid=0`, sin fijar valores para datos y controles
inactivos. Todos los casos comprueban el ancho de 139 bits y el reset inicial.
Captura e invalidación son controles locales excluyentes; RESET e inicialización
de sesión pueden coincidir con ellos y deben prevalecer. Sin controles se retiene.

Este grupo acredita exclusivamente el registro. El dato de store y el resultado
EX se inyectan por sus puertos; su selección real mediante forwarding y Result
MUX, la autorización de DMEM y las fronteras de instrucciones siguen pendientes
de integración. `TEST-PIPE-001/C001` conserva su ejecución de esquema de tipos
al nivel Unidad; su programa y estructura completa siguen pendientes. También
siguen pendientes las acciones de `TEST-PIPE-007/C001–C021`, las fronteras de
`TEST-PIPE-008/C001–C009`, los commits de `TEST-PIPE-009/C001–C011` y las
secuencias de CPU/control de `TEST-PIPE-010/C001–C020`. Sus IDs, cantidades,
estados y configuraciones no cambian. No se atribuye al registro aislado la
continuidad de trabajo anterior ante redirect/fault ID ni la generación real
de controles de HOLD, LOAD, halt/fault EX y drain.

<a id="test-pipe-014"></a>

## TEST-PIPE-014 — Registro MEM/WB aislado

- **Nivel:** Unidad.
- **Tipo de estímulo:** vectores de payload y controles locales aplicados a los puertos del registro.
- **Estado:** banco implementado; los resultados se registran por separado.

**Requisitos:** [REQ-CPU-009](../requirements.md#2-procesador-y-pipeline) y
[REQ-CPU-010](../requirements.md#2-procesador-y-pipeline), limitados a MEM/WB.

**Contratos:** [registro MEM/WB](../architecture/cpu/cpu_pipeline.md#registro-memwb),
[interfaz](../interfaces.md#bloque-4-7) y
[reset funcional síncrono](../architecture/platform/reset_integration.md#efectos-del-reset-sobre-el-sistema).

El banco `mem_wb_register_tb` instancia únicamente el registro y el lector de
datos externo. Los seis casos conservan estímulos y expectativas en el
manifiesto. Cada paso aplica controles y datos en el flanco descendente,
comprueba estabilidad del registro y contrasta `valid_next` antes del flanco
ascendente. Después del flanco compara el estado con igualdad estricta para
detectar X/Z.

| Caso   | Comprobación                                                                  |
| ------ | ----------------------------------------------------------------------------- |
| C001   | Captura preflanco y reemplazo de los seis campos, incluido wb_value completo. |
| C002   | Captura de entrada inválida con reg_write residual y de payload cero.         |
| C003   | Retención de entrada válida durante tres clocks sin captura.                  |
| C004   | Retención de entrada inválida durante tres clocks sin captura.                |
| C005   | RESET síncrono sobre captura y retención, seguido de nueva captura.           |
| C006   | Inicialización de sesión sobre captura y retención, seguida de nueva captura. |

Las capturas comparan los seis campos contra el JSON. C001 utiliza patrones
complementarios en los bits del payload salvo `valid`; `wb_value` alterna sus
32 bits y difiere de PC e instrucción. La segunda captura conserva `valid=1`
con `rd=0` y `reg_write=0`: el registro transporta esos campos sin decidir la
autorización del writeback. C002 comprueba captura de `valid=0`, incluido
`reg_write=1` inactivo, y luego reemplazo por payload cero. Son vectores del
registro; no representan instrucciones ejecutables ni commits de RF.

La expectativa `retained` compara los 103 bits con su copia preflanco;
`invalidated` exige solo `valid=0`, sin fijar valores para datos y controles
inactivos. Todos los casos comprueban el ancho de 103 bits y el reset inicial.
RESET e inicialización de sesión prevalecen sobre captura. Sin controles se
retiene; la interfaz no agrega bubble ni invalidación local.

Este grupo acredita exclusivamente el registro. La selección del valor final en
MEM, las guardas de writeback, el consumo de la entrada anterior en un commit
simultáneo y su cuenta por instancia siguen pendientes de integración.
`TEST-PIPE-001/C001` conserva su ejecución de esquema de tipos al nivel Unidad;
su programa y estructura completa siguen pendientes. También siguen pendientes
las acciones de `TEST-PIPE-007/C001–C021`, las fronteras de
`TEST-PIPE-008/C001–C009`, los commits de `TEST-PIPE-009/C001–C011` y las
secuencias de CPU/control de `TEST-PIPE-010/C001–C020`. Sus IDs, cantidades,
estados y configuraciones no cambian. La captura de MEM para las ocho acciones,
incluida una frontera EX joven o el último avance de drain, requiere los
controles locales y la integración correspondientes.
