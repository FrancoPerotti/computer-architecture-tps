# TP3 — Memorias y accesos

- **Tipo:** catálogo de verificación.
- **Estado documental:** catálogo diseñado; ejecución parcial local de Loader y sesión.

## Propósito y alcance

Este documento reúne las pruebas de IMEM, DMEM y Loader. Incluye el direccionamiento, los límites de cada acceso, el orden little-endian, las marcas de validez y el reemplazo de imágenes. Las observaciones distinguen los datos físicos del estado lógico de DMEM.

Las [convenciones, niveles y límites del plan](verification_plan.md) se aplican a todos los casos. Los contratos enlazados determinan el comportamiento; la [matriz](coverage.md) relaciona las pruebas con los requisitos y el trabajo fuera de alcance.

## Índice

- [TEST-MEM-001 — Stores por lane y actualización atómica](#test-mem-001)
- [TEST-MEM-002 — Loads, signo y mezcla de bytes lógicos](#test-mem-002)
- [TEST-MEM-003 — Región completa, alineación y aritmética ensanchada](#test-mem-003)
- [TEST-MEM-004 — Fetch, little-endian y tamaño confirmado](#test-mem-004)
- [TEST-MEM-005 — Temporización de memoria e independencia IF/MEM](#test-mem-005)
- [TEST-MEM-006 — Ownership y colisiones internas](#test-mem-006)
- [TEST-MEM-007 — Loader por cuarto byte y aborto](#test-mem-007)
- [TEST-MEM-008 — Publicación de imagen y reemplazo más corto](#test-mem-008)

<a id="test-mem-001"></a>

## TEST-MEM-001 — Stores por lane y actualización atómica

- **Nivel:** unidad DMEM e integración MEM.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-MEM-005](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-006](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-013](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-023](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-027](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-029](../requirements.md#5-memorias-y-carga-de-programas), [REQ-ISA-002](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-003](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-004](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-007](../requirements.md#2-procesador-y-pipeline).

**Contratos:** [dmem_access](../architecture/memory/dmem_access.md); [stage_mem](../architecture/cpu/stage_mem.md).

### Qué comprueba y por qué

Esta prueba comprueba que un store escriba los bytes seleccionados y active sus marcas de validez en el mismo flanco.

Busca detectar una máscara o un lane equivocado, la modificación de bytes vecinos o una marca actualizada sin el dato correspondiente. Los dos bitmaps iniciales permiten comprobar que los lanes no seleccionados conserven tanto una marca cero como una marca uno.

El store de cero comprueba que un byte escrito siga siendo utilizado aunque su valor sea cero.

### Condiciones iniciales

La fila física de DMEM comienza con los bytes `[A1, B2, C3, D4]`. El dato del store es `0x12345678`, excepto en la variante que escribe cero mediante SB.

El banco prepara un ciclo autorizado y una entrada válida de EX/MEM con el `mem_op` de la variante. Las instrucciones jóvenes no intervienen en este acceso. El bitmap inicial es `0000` o `1111`, según el caso.

Las tres variantes de guardas utilizan únicamente SW en dirección cero y bitmap `1111`. Los bytes y las marcas de los lanes ajenos al store deben conservarse.

### Variantes cerradas

La prueba tiene 18 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-MEM-001/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Las siete filas de store de la tabla se comprueban con los dos bitmaps iniciales, lo que produce 14 casos.

Un caso adicional aplica SB con dato cero en dirección 2 y marcas `0000`. Los tres restantes deshabilitan una guarda por vez en SW de dirección cero. Como la habilitación es común al acceso, esas guardas no se cruzan nuevamente con cada lane.

### Datos de referencia

| Operación / EA | Máscara | Bytes físicos esperados en dirección 0,1,2,3 |
|----------------|---------|----------------------------------------------|
| SB / 0         | 0001    | 78 B2 C3 D4                                  |
| SB / 1         | 0010    | A1 78 C3 D4                                  |
| SB / 2         | 0100    | A1 B2 78 D4                                  |
| SB / 3         | 1000    | A1 B2 C3 78                                  |
| SH / 0         | 0011    | 78 56 C3 D4                                  |
| SH / 2         | 1100    | A1 B2 78 56                                  |
| SW / 0         | 1111    | 78 56 34 12                                  |

### Procedimiento

1. **Preparar datos y marcas.** Instalar la fila física, el bitmap y la entrada de EX/MEM. Guardar una copia de todos los lanes.

2. **Observar el preflanco.** Comprobar que presentar el acceso no cambie combinacionalmente ningún dato ni ninguna marca.

3. **Aplicar el flanco del store.** Comparar cada lane con la máscara de la tabla. Los seleccionados deben recibir el dato y la marca; los demás deben conservar ambos valores.

4. **Leer el estado lógico de DMEM.** Después del flanco, comprobar que una marca cero produzca cero lógico incluso cuando exista un residuo físico.

5. **Comprobar las guardas.** En cada store inhibido, verificar que no cambie ningún dato ni ninguna marca.

### Resultados y criterio de aprobación

Antes del flanco, todos los datos y marcas deben conservarse. En el flanco válido solo cambian los lanes de la máscara, y sus marcas pasan a uno junto con los datos.

Cuando el bitmap inicial es `0000`, los lanes no escritos siguen presentando cero en el estado lógico de DMEM. Un store de cero activa su marca igualmente.

Las variantes inhibidas no deben producir escrituras parciales, read-modify-write ni cambios de validez. La aprobación exige coincidencia de datos físicos, estado lógico de DMEM y marcas antes y después de cada acceso, con una única transacción por store.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-mem-002"></a>

## TEST-MEM-002 — Loads, signo y mezcla de bytes lógicos

- **Nivel:** unidad DMEM/load_select_extend e integración MEM.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-MEM-005](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-006](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-008](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-017](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-023](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-027](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-029](../requirements.md#5-memorias-y-carga-de-programas), [REQ-ISA-018](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-019](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-020](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-021](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-022](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-007](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-008](../requirements.md#2-procesador-y-pipeline).

**Contratos:** [dmem_access](../architecture/memory/dmem_access.md); [stage_mem](../architecture/cpu/stage_mem.md).

### Qué comprueba y por qué

Esta prueba comprueba que los loads seleccionen los bytes correctos y apliquen la extensión de signo o de cero después de formar el dato.

Busca detectar un orden little-endian invertido, la extensión del signo de un byte incorrecto o la utilización de residuos físicos cuyos bytes no tienen validez.

Los casos con marcas inactivas comprueban el estado lógico de DMEM. La lectura no debe convertir una dirección en memoria utilizada.

### Condiciones iniciales

El banco instala los bytes físicos y el bitmap especificados para cada variante. La tabla nominal utiliza la fila `[80, FF, 00, 80]` con las marcas activas.

Las variantes de sustitución por cero utilizan los bitmaps indicados. Los dos casos de signo positivo preparan los halfwords `0x007F` y `0x7FFF`.

No hay un store ni una preparación simultánea. Todos estos accesos están naturalmente alineados; la clasificación de faults se comprueba en TEST-MEM-003.

### Variantes cerradas

La prueba tiene 25 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-MEM-002/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 13 accesos nominales son los pares de instrucción y dirección de la tabla.

Otros diez casos combinan los dos bitmaps previstos con cinco lecturas: LW, LH y LHU en direcciones 0 y 2. Los dos casos restantes comprueban LH con los halfwords positivos y bitmap `1111`.

### Datos de referencia

| Operación |      EA | Resultado                             |
|-----------|--------:|---------------------------------------|
| LB        | 0,1,2,3 | FFFFFF80, FFFFFFFF,00000000, FFFFFF80 |
| LBU       | 0,1,2,3 | 00000080,000000FF,00000000,00000080   |
| LH        |     0,2 | FFFFFF80, FFFF8000                    |
| LHU       |     0,2 | 0000FF80,00008000                     |
| LW        |       0 | 8000FF80                              |

### Procedimiento

1. **Preparar la fila y sus marcas.** Guardar los datos y el bitmap que deberán permanecer sin cambios.

2. **Aplicar la lectura.** Presentar la dirección efectiva y el tamaño. Esperar la estabilización combinacional, sin aplicar un flanco adicional de memoria.

3. **Comparar el dato.** Comprobar la sustitución por cero de los bytes inválidos, el ensamblado little-endian y la extensión de la operación.

4. **Observar la integración MEM.** Capturar `load_value` en MEM/WB en el flanco correspondiente, sin introducir otra latencia de memoria.

5. **Revisar el estado conservado.** Volver a leer datos y marcas para comprobar que el load no haya modificado DMEM ni su bitmap.

### Resultados y criterio de aprobación

Los accesos nominales deben producir los valores de la tabla. Con bitmap `0101`, el estado lógico de DMEM presenta `[80, 00, 00, 00]`: LW, LH de dirección cero y LHU de dirección cero producen `00000080`; LH y LHU de dirección 2 producen cero.

Con bitmap `0000`, todas las lecturas devuelven cero pese a los residuos físicos. Los casos positivos de LH producen `0000007F` y `00007FFF`.

La sustitución por cero debe ocurrir antes del ensamblado y de la extensión. Ningún load agrega marcas ni escribe DMEM.

La aprobación requiere todos los lanes, tamaños y extensiones previstos, una salida combinacional sin flanco extra y la captura correcta del resultado en MEM/WB, conservando los metadatos de memoria.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-mem-003"></a>

## TEST-MEM-003 — Región completa, alineación y aritmética ensanchada

- **Nivel:** unidad fetch/ex_flow_check y CPU.
- **Tipo de estímulo:** legal salvo entradas locales de PC.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-MEM-013](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-014](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-015](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-016](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-017](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-018](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-021](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-027](../requirements.md#5-memorias-y-carga-de-programas), [REQ-EXEC-018](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [memory_architecture](../architecture/memory/memory_architecture.md); [faults_and_termination](../architecture/session/faults_and_termination.md); [dmem_access](../architecture/memory/dmem_access.md).

### Qué comprueba y por qué

Esta prueba comprueba que un acceso a DMEM valide toda su región y su alineación antes de reducir la dirección a fila y lane.

Busca detectar un alias por truncamiento, una comprobación limitada al primer byte o un desborde en el cálculo del extremo del acceso.

Los casos de formación modular distinguen la suma de dirección de 32 bits del extremo calculado en 33 bits. Los casos máximos comprueban esa aritmética sin exigir una memoria física de `2^32` bytes.

### Condiciones iniciales

En CPU, la instrucción causante ocupa `PC=0`. El banco prepara valores centinela en el Register File y DMEM, y deja los destinos de load con el valor `0x55`, para detectar efectos indebidos.

En unidad se aplican la capacidad `C`, la dirección efectiva, el tamaño y la operación de cada caso. Para el acceso `EA=C=2048`, se utiliza un registro base igual a C e inmediato cero; 2048 no se codifica en un inmediato de 12 bits.

En las expresiones de región, N es el tamaño del acceso en bytes: uno para byte, dos para halfword y cuatro para word.

Los casos de capacidad `2^32` se limitan a funciones o comprobadores aritméticos. No requieren elaborar arrays gigantes ni demuestran un acceso físico de esa capacidad.

### Variantes cerradas

La prueba tiene 78 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-MEM-003/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 64 casos de límites combinan dos capacidades y load o store con cuatro direcciones de byte, seis de halfword y seis de word.

Los ocho casos de formación modular combinan las dos capacidades, load o store y dos pares de base e inmediato. Se aplican solamente a word; no se agrega un cruce con otros tamaños.

Los seis casos máximos aplican load y store a las tres regiones indicadas con `C=2^32`, mediante comprobaciones aritméticas aisladas.

### Procedimiento

1. **Preparar los operandos y los valores centinela.** Conservar especialmente las posiciones de dirección cero, que permiten detectar un alias.

2. **Formar la dirección efectiva.** Sumar base e inmediato módulo `2^32`. Calcular después el extremo de la región mediante una suma sin signo de 33 bits.

3. **Clasificar el acceso.** Comprobar alineación y rango antes de reducir la dirección a fila o lane. Si ambas condiciones fallan, seleccionar la causa prevista de desalineación.

4. **Observar CPU.** Para las causas 4 a 7, comprobar `fault_pc=0`, la ausencia de writeback del load o la ausencia completa del store, incluidos sus datos y marcas.

5. **Comprobar los accesos válidos y los casos máximos.** Un acceso válido debe abarcar toda su región. En los casos de `2^32`, comparar únicamente la aritmética y la causa, sin asignar esa memoria física.

### Resultados y criterio de aprobación

Las direcciones cero y `C-N` son válidas cuando abarcan N bytes alineados. La dirección C queda fuera de rango. La desalineación produce causa 4 en load o 6 en store, incluso si también falla el rango; un acceso alineado fuera de rango produce causa 5 o 7.

Una dirección efectiva modular igual a cero es válida aunque la suma de base e inmediato haya tenido carry. Ese carry no debe convertirse en un fault.

Con `C=2^32`, la región `FFFFFFFC+4` es válida y `FFFFFFFF+1` es válida para byte. La región `FFFFFFFF+4` falla rango y alineación, con prioridad de desalineación.

Un store inválido no modifica ningún dato o marca, ni siquiera la parte de la región que cabe en DMEM. Un load inválido conserva su destino. La aprobación requiere clasificación correcta por caso, causa y PC correctos en CPU y valores centinela intactos, sin alias por truncamiento.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-mem-004"></a>

## TEST-MEM-004 — Fetch, little-endian y tamaño confirmado

- **Nivel:** unidad IMEM/IF y CPU.
- **Tipo de estímulo:** legal y PCs locales artificiales.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-004](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-017](../requirements.md#2-procesador-y-pipeline), [REQ-MEM-001](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-002](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-009](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-013](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-016](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-018](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-023](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-024](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-030](../requirements.md#5-memorias-y-carga-de-programas).

**Contratos:** [stage_if](../architecture/cpu/stage_if.md); [memory_architecture](../architecture/memory/memory_architecture.md).

### Qué comprueba y por qué

Esta prueba comprueba que IF acepte únicamente búsquedas alineadas que pertenezcan a la imagen confirmada y a la capacidad de IMEM.

Busca detectar palabras residuales aceptadas fuera de imagen, un PC desalineado redondeado por `PC>>2` o un candidato de fetch clasificado como instrucción ilegal.

La ejecución de CPU también comprueba la reconstrucción little-endian de una palabra cargada por Loader.

### Condiciones iniciales

IMEM contiene `0x00A585B3` en dirección cero y `halt` en dirección 4. El sufijo físico contiene palabras de `halt` residuales que no deben confundirse con instrucciones de la imagen.

El tamaño `loaded_image_size_bytes` se prepara según la variante; `image_valid` se deriva de ese tamaño. Para la imagen completa se utiliza tamaño C y un `halt` en la última palabra.

Los PCs desalineados se inyectan solamente en IF local. En CPU, el Register File comienza con `x10=3` y `x11=4`; la palabra cargada corresponde a `add x11,x11,x10`.

### Variantes cerradas

La prueba tiene 23 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-MEM-004/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 22 casos locales aplican once combinaciones concretas de PC y tamaño por capacidad. Incluyen los límites de imagen y memoria, la desalineación y la ausencia de imagen.

El caso restante ejecuta ADD y `halt` en CPU. Sus bytes `B3 85 A5 00` deben reconstruir la palabra `0x00A585B3`.

### Procedimiento

1. **Preparar IMEM.** Escribir los bytes little-endian mediante Loader y conservar el sufijo físico residual.

2. **Aplicar PC y tamaño.** Presentar cada combinación local y observar la palabra, su validez y el candidato de fetch antes de reducir el índice.

3. **Comparar los flags y el PC.** En un fetch inválido, exigir `valid=0`, `fetch_fault_valid=1` y el PC original sin truncamiento. Distinguir esa entrada de una instrucción ilegal.

4. **Ejecutar CPU.** Con `x10=3` y `x11=4`, ejecutar las dos palabras de la imagen y comparar `x11=7`.

5. **Revisar la finalización.** Comprobar que el `halt` real termine la ejecución antes de utilizar el sufijo residual.

### Resultados y criterio de aprobación

Con la imagen corta, el fetch de PC cero devuelve `00A585B3` y el de PC 4 devuelve `halt`. PC 8 y el sufijo fuera de imagen producen un candidato de causa 1; no representan un `halt` implícito.

La dirección `C-4` es válida únicamente cuando pertenece a una imagen completa. C queda fuera de capacidad. Los PCs 1, 2, 3 y `C+1` producen causa 0 antes de considerar el rango. Sin imagen no hay instrucción válida.

IF/ID distingue una instrucción con `valid=1` y `fetch_fault_valid=0` de un candidato con los flags inversos. La palabra residual no se clasifica como instrucción ilegal.

La aprobación exige datos, flags y PCs correctos, además de la ejecución de ADD y `halt` sin utilizar el sufijo. Ningún PC inválido puede legalizarse por truncar `PC>>2`.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-mem-005"></a>

## TEST-MEM-005 — Temporización de memoria e independencia IF/MEM

- **Nivel:** unidad memorias y CPU.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-CPU-003](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-004](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-007](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-001](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-MEM-014](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-019](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-020](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-025](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-027](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-028](../requirements.md#5-memorias-y-carga-de-programas).

**Contratos:** [memory_architecture](../architecture/memory/memory_architecture.md); [stage_mem](../architecture/cpu/stage_mem.md).

### Qué comprueba y por qué

Esta prueba comprueba la lectura combinacional y la escritura síncrona de memoria, junto con la independencia de IMEM y DMEM.

Busca detectar una lectura que requiera un clock extra, un recurso compartido que impida IF y MEM simultáneos o un stall estructural no previsto.

El programa contiene una dependencia LW→SW que sí requiere stall. La traza debe distinguir esa pausa de una supuesta latencia adicional de memoria.

### Condiciones iniciales

En unidad se preparan dos direcciones con los valores `0x12345678` y `0x89ABCDEF`. El clock permanece activo, pero las observaciones de lectura se realizan entre flancos.

En CPU se prepara la palabra cero de DMEM con `0x12345678` y se carga el programa indicado. IMEM y DMEM conservan espacios de dirección independientes.

### Variantes cerradas

La prueba tiene 3 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-MEM-005/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los dos casos locales comprueban un cambio de dirección de lectura entre flancos y una escritura seguida de lectura.

El tercer caso ejecuta el programa de CPU. Permite observar accesos simultáneos de IF y MEM y la única dependencia inicial LW→SW.

### Programas concretos

Las instrucciones ocupan palabras sucesivas desde PC=0, salvo el mapa explícito de la variante. `word0` en el [manifiesto](cases.json) significa la palabra ilegal `0x00000000`; aquí se escribe `.word 0x00000000`. Las inicializaciones del fixture se indican por separado.

Para el caso `C003`, se utiliza el siguiente programa:

```asm
lw x1,0(x0)
sw x1,4(x0)
lb x2,0(x0)
lbu x3,1(x0)
halt
```

### Procedimiento

1. **Preparar y cambiar la dirección de lectura.** Comparar la salida después de estabilizarla, antes del siguiente flanco. Ninguna habilitación de CPU debe crear otro clock de memoria.

2. **Aplicar una escritura.** Observar que el dato se conserve antes del flanco habilitado y cambie después de él.

3. **Ejecutar el programa de CPU.** Identificar los ciclos en los que IF busca una instrucción mientras MEM lee o escribe DMEM.

4. **Comparar las transacciones y los resultados.** Exigir que ambos accesos se mantengan sin alias y que el único stall provenga de LW→SW.

5. **Revisar los latches.** Comprobar que IF/ID y MEM/WB capturen en sus ciclos correspondientes, sin una latencia adicional de memoria.

### Resultados y criterio de aprobación

Las lecturas deben ser combinacionales y las escrituras deben ocurrir al flanco. IMEM de dirección cero y DMEM de dirección cero pertenecen a espacios distintos.

El programa termina por `halt` con `x1=12345678`, la palabra de DMEM en dirección 4 igual a `12345678`, `x2=78` y `x3=56`. Su único stall es el de la dependencia LW→SW.

Un acceso de varios lanes constituye una sola transacción. La aprobación exige una traza con IF y MEM concurrentes, sin pérdidas ni stall estructural. La realización de síntesis y timing se comprueba además en TEST-PLAT-004.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-mem-006"></a>

## TEST-MEM-006 — Ownership y colisiones internas

- **Nivel:** integración memorias/sistema y revisión.
- **Tipo de estímulo:** legal y colisión artificial.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-MEM-019](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-020](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-025](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-028](../requirements.md#5-memorias-y-carga-de-programas), [REQ-DBG-015](../requirements.md#7-uart-y-debug-unit), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [memory_architecture](../architecture/memory/memory_architecture.md); [dmem_access](../architecture/memory/dmem_access.md); [execution_control](../architecture/session/execution_control.md).

### Qué comprueba y por qué

Esta prueba comprueba que cada memoria tenga como máximo un agente autorizado en cada fase del sistema.

Busca detectar un acceso simultáneo incompatible al mismo recurso. La independencia de IMEM y DMEM permite IF y MEM simultáneos, pero no autoriza fetch y Loader en IMEM ni CPU y Debug en DMEM.

Los conflictos artificiales comprueban las prioridades o las assertions previstas. No definen un comportamiento arquitectónico para una sesión inválida.

### Condiciones iniciales

Las fases legales se alcanzan mediante reset, carga, preparación y comandos normales. Para Debug se observa el estado posterior a STEP con la CPU retenida.

Las inyecciones se aplican únicamente a solicitudes y guardas de interfaces locales. Permiten comprobar un conflicto del bloque, pero no demuestran alcanzabilidad end-to-end ni una ejecución válida de CPU.

### Variantes cerradas

La prueba tiene 10 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-MEM-006/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Se comprueban seis fases: RUNNING, LOADING, PREPARING_READY, un ciclo STEP efectivo en STEPPING, Debug exclusivo posterior a STEP y espera sin agente activo. PREPARING_READY representa el mantenimiento de la sesión.

Los cuatro casos artificiales comprueban clear y store coincidentes, reset frente a ambos, solicitudes incompatibles en IMEM y solicitudes incompatibles de CPU y Debug en DMEM. No se cruzan estos conflictos con los 14 estados.

Los dos conflictos entre agentes se utilizan para comprobar la assertion. No se inventa un agente ganador donde el contrato no lo define.

### Procedimiento

1. **Alcanzar las fases legales.** Registrar qué agentes y operaciones están autorizados en cada memoria. En espera no debe haber acceso CPU; durante RUN se permiten IF y MEM simultáneos porque usan memorias distintas.

2. **Aplicar clear y store localmente.** Comprobar que clear prevalezca y cambie solamente la marca direccionada, sin escribir el dato del store.

3. **Aplicar reset al conflicto.** Exigir que se supriman ambas actualizaciones.

4. **Forzar los conflictos entre agentes.** Observar que la assertion detecte las solicitudes incompatibles de IMEM o DMEM. No interpretar el resultado como una operación válida de CPU.

5. **Comparar el estado conservado.** Revisar que los accesos excluidos no hayan modificado datos o marcas ni generado un nuevo fault arquitectónico.

### Resultados y criterio de aprobación

En las fases legales hay como máximo un agente autorizado por memoria. IF y MEM pueden coexistir; LOAD excluye fetch y Debug excluye CPU y preparación, sin requerir un puerto adicional.

En el conflicto artificial de clear y store, clear prevalece y el store no escribe datos ni marcas. Reset suprime ambas operaciones.

Las assertions deben detectar el ownership inválido sin producir una nueva causa arquitectónica. No se fija un ganador funcional entre CPU y Debug que no esté definido por el contrato.

La aprobación exige la exclusión legal y la detección de los conflictos previstos. Esa detección no certifica que los estados artificiales sean alcanzables en funcionamiento normal.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-mem-007"></a>

## TEST-MEM-007 — Loader por cuarto byte y aborto

- **Nivel:** unidad Loader e integración IMEM.
- **Tipo de estímulo:** legal y guardas locales.
- **Estado:** unidad y conexión con Execution Control ejecutadas con un fixture IMEM; integración con IMEM de producción y sistema pendiente.

**Requisitos:** [REQ-MEM-001](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-003](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-023](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-024](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-030](../requirements.md#5-memorias-y-carga-de-programas), [REQ-UART-002](../requirements.md#7-uart-y-debug-unit), [REQ-DBG-002](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [loader](../architecture/session/loader.md); [uart_core](../architecture/uart/uart_core.md).

### Qué comprueba y por qué

Esta prueba comprueba que Loader forme cada palabra con cuatro bytes y la escriba una sola vez en IMEM al recibir el cuarto.

Busca detectar una escritura prematura, el uso de un cuarto byte anterior, la pérdida de bytes parciales durante una pausa o la omisión o duplicación de la última palabra.

Las variantes de aborto y reset comprueban que sus prioridades impidan una escritura coincidente.

### Condiciones iniciales

El banco inicia Loader mediante `load_start`, con tamaño 8 y ocho bytes pendientes, y presenta `loader_active=1` durante la carga. El offset se obtiene de `size-remaining` en preflanco.

El registro `partial_word` contiene el residuo `0x00DEADBE` e IMEM tiene valores centinela. Así se puede observar si una carga mezcla bytes anteriores.

Para los casos de última palabra se utiliza `load_size=C` y se presentan los últimos cuatro bytes, con faltantes de 4 a 1. Después de un aborto, un nuevo `load_start` inicia la carga en offset cero; el host no reasigna direcciones.

El caso de Loader inactivo es una inyección local de byte válido. No representa una entrega normal autorizada de UART.

### Variantes cerradas

La prueba tiene 9 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-MEM-007/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

La selección comprende:

- Una carga de ocho bytes con un ciclo sin byte válido antes del cuarto.
- Tres abortos después de recibir uno, dos o tres bytes parciales; cada secuencia continúa con una nueva imagen de `halt`.
- Un aborto coincidente con el cuarto byte.
- Un reset coincidente con el último byte, en offset 7.
- Dos comprobaciones de última palabra, una para REFERENCE y otra para ALT_1000.
- Una guarda local con Loader inactivo.

Los bytes y los pasos de cada transferencia pertenecen al mismo caso; no agregan casos individuales.

### Procedimiento

1. **Preparar la carga y entregar los bytes.** Presentar cada byte con `load_byte_valid`. Observar las capturas parciales en los lanes 0, 1 y 2.

2. **Observar el cuarto byte.** Comprobar que el lane 3 forme la palabra con el byte actual y `partial_word`, sin esperar otro flanco para incorporarlo.

3. **Comparar las escrituras.** En la carga de ocho bytes, exigir escrituras solamente en offsets 3 y 7. En la última escritura, observar `load_ok` en el mismo flanco.

4. **Aplicar aborto o reset.** Comprobar que impidan la escritura coincidente y `load_ok`. En la carga posterior, observar que los tres bytes parciales nuevos reemplacen los residuos antes del cuarto.

5. **Comprobar Loader inactivo.** Con `loader_active=0`, presentar el estímulo local y exigir ausencia de escritura.

### Resultados y criterio de aprobación

El offset deriva de tamaño menos faltantes en preflanco; el lane es `offset%4` y la fila es `offset>>2`.

Los tres primeros bytes actualizan solamente `partial_word`. El cuarto escribe `00A585B3` en ese mismo flanco. El cuarto byte final escribe `halt` y produce `load_ok`, pero el tamaño confirmado permanece en cero hasta la preparación.

Aborto y reset impiden la escritura y `load_ok` coincidentes. `load_fail` se produce solamente para un aborto de carga activa sin reset. Una carga nueva no debe mezclar bytes anteriores, y no debe existir una escritura en offset N cuando el byte no es válido.

La aprobación exige una escritura por palabra, datos e índices correctos y respeto de las prioridades, sin publicación prematura de la imagen.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-mem-008"></a>

## TEST-MEM-008 — Publicación de imagen y reemplazo más corto

- **Nivel:** CPU/sistema.
- **Tipo de estímulo:** legal.
- **Estado:** C001–C006 con integración local disponible y C007 revisado documentalmente; CPU y sistema pendientes.

**Requisitos:** [REQ-CPU-016](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-018](../requirements.md#2-procesador-y-pipeline), [REQ-MEM-004](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-007](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-008](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-009](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-012](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-015](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-024](../requirements.md#5-memorias-y-carga-de-programas), [REQ-MEM-030](../requirements.md#5-memorias-y-carga-de-programas), [REQ-EXEC-016](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-EXEC-017](../requirements.md#6-finalización-y-modos-de-ejecución), [REQ-DBG-012](../requirements.md#7-uart-y-debug-unit).

**Contratos:** [memory_architecture](../architecture/memory/memory_architecture.md); [session_preparation](../architecture/session/session_preparation.md); [protocol](../protocol.md).

### Qué comprueba y por qué

Esta prueba comprueba el reemplazo de una imagen y la preparación de una nueva sesión antes de publicarla como ejecutable.

Busca detectar una publicación prematura, la restauración de la imagen anterior después de una carga fallida o la exposición de residuos de la sesión A durante la ejecución de B.

Los rechazos distinguen una solicitud que no se acepta de una carga aceptada que después falla: solo la primera conserva la imagen y la sesión anteriores.

### Condiciones iniciales

El sistema utiliza REFERENCE. La imagen A tiene 16 bytes y, al ejecutarse, deja `x1=7`, `x2=9` y la palabra cero de DMEM igual a 7 antes de terminar.

La imagen B tiene cuatro bytes y contiene únicamente `halt`. Se carga sobre la misma configuración FPGA, sin reprogramarla.

READY se observa mediante el estado interno. Debug se consulta después de STEP o del terminal RUN; no se agrega un comando READ_STATE inexistente.

### Variantes cerradas

La prueba tiene 7 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-MEM-008/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los dos reemplazos cortos ejecutan A, cargan B y luego utilizan RUN o STEP.

Tres casos rechazan los tamaños 0, 1028 y 6 en REFERENCE, con la imagen de 16 bytes todavía válida. Otro acepta tamaño 8, recibe tres bytes y alcanza timeout; después de la recuperación se carga una imagen válida de cuatro bytes.

El último caso revisa el formato: LOAD no contiene entrypoint ni direcciones por byte. No se inventa un paquete inválido para representar un origen o huecos que ese formato no puede expresar.

### Procedimiento

1. **Ejecutar A y guardar su estado.** Conservar la imagen confirmada, el tamaño y los valores que permiten detectar residuos.

2. **Aceptar la nueva LOAD.** Presentar la solicitud y comprobar `command_accepted=load_start=1`. En ese flanco, el tamaño confirmado pasa a cero y `cpu_cycle_fire=0`. `load_ok` todavía no debe publicar N.

3. **Observar PREPARING_READY.** Al consumir `prepare_done`, comprobar `image_publish=1`, la publicación de N y READY con `cpu_cycle_fire=0`. El Register File, PC, latches, contador y estado lógico de DMEM deben estar preparados antes de ejecutar B.

4. **Ejecutar B.** Enviar RUN o STEP después de completar físicamente DONE y comprobar que B no utilice palabras residuales de A.

5. **Comprobar rechazo y aborto.** Un rechazo conserva la sesión; un aborto conserva la invalidez. Durante el contenido de LOAD, los bytes que coincidan con RUN o STEP son datos, no comandos. Comprobar NO_IMAGE únicamente después de recuperar el transporte.

### Resultados y criterio de aprobación

Una LOAD aceptada pone el tamaño confirmado en cero inmediatamente. Una LOAD rechazada conserva A. `load_ok` no publica la imagen; `prepare_done` en PREPARING_READY publica N y alcanza READY sin ejecutar CPU.

La preparación restablece el Register File, PC, contador, pipeline y estado lógico de DMEM, con `used_count=0`. La carga abortada no restaura A ni permite RUN o STEP.

B debe ejecutarse independientemente de los datos y del sufijo físico de A. El tamaño confirmado es el único estado global persistente de la imagen, con `image_valid=(tamaño!=0)`; no se agrega un bitmap de IMEM ni un contador de instrucciones.

La aprobación exige distinguir rechazo, aborto y publicación, y conservar las condiciones esperadas en cada fase.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

## Evidencia local de Loader — tercer bloque de #8

`rtl/loader.sv` implementa el ensamblado little-endian y la frontera de escritura
de Interfaces §9.1. El único registro propio es `partial_word[23:0]`; no incorpora
FSM, contador de progreso ni copia registrada del tamaño. `load_start` conserva
su puerto contractual, pero no necesita borrar el parcial: las primeras tres
entregas reemplazan sus segmentos antes de escribir.

El cuarto byte se combina directamente con el parcial y habilita la escritura en
ese mismo flanco. Reset y aborto impiden capturas y escrituras; reset también
suprime `load_fail`. `pending_image_size_bytes` es el alias combinacional del tamaño
validado y `load_ok` coincide con la última escritura, sin publicar aún la imagen.
Los anchos derivan de `IMEM_CAPACITY_BYTES` mediante `system_pkg`.

`tb/loader_tb.sv` ejecuta los nueve IDs originales de `TEST-MEM-007` en dos modos:
unidad, con controles modelados, e integración local con `execution_control` y su
FSM reales. Un fixture síncrono observa dos ubicaciones de IMEM y conserva sus
centinelas y escrituras durante reset. No es el módulo de memoria de producción
ni reserva un array proporcional a la capacidad configurada.

Todos los estímulos y expectativas adicionales están en `cases.json`, mediante
`loader_fixture`, `loader_steps` y `expected.loader_steps`. Los valores comunes se
declaran una sola vez. El banco calcula el offset como tamaño menos faltantes en
ancho de tamaño, antes de reducirlo al ancho de dirección; modela así la conexión
del Controller sin agregar progreso privado al Loader. Comprueba los buses antes
del flanco, que los recursos no cambien anticipadamente y las capturas/escrituras
después. El lector y ejecutor compartidos permanecen sin cambios, al igual que los
IDs, entradas, expectativas y ejecuciones anteriores.

| IDs | Comprobación disponible | Alcance pendiente |
|---|---|---|
| `TEST-MEM-007/C001` | Dos palabras, bytes consecutivos, pausa con dato residual inválido, escrituras solo en offsets 3/7 y éxito con la última escritura. | Transporte UART e IMEM de producción. |
| `TEST-MEM-007/C002–C004` | Aborto después de uno, dos o tres bytes, ninguna escritura parcial y nueva carga de halt que reemplaza residuos. | Detección del error/timeout y recuperación del Controller. |
| `TEST-MEM-007/C005–C006` | Aborto frente al cuarto byte; reset frente al último byte y aborto coincidente. No hay escritura ni éxito; reset suprime también el resultado de aborto. | Integración de reset y efectos globales del sistema completo. |
| `TEST-MEM-007/C007–C008` | Última palabra en filas 255/249 de REFERENCE/ALT_1000. | El prefijo de la imagen no se transfiere en este fixture de frontera. |
| `TEST-MEM-007/C009` | Byte válido artificial con Loader inactivo: ninguna escritura ni éxito. | No representa una entrega normal de UART. |
| `TEST-PLAT-001/C004–C008` | Última palabra e índices para 4, 1000, 1024, 2048 y `2^32` bytes; alias y publicación del tamaño inclusive. | Sin arrays gigantes, lectura IF ni realización física. |

En integración local, la última escritura y `load_ok` llevan a
`PREPARING_READY` con tamaño confirmado cero. La preparación permanece modelada;
solo al presentar `prepare_done` se publica el tamaño y se alcanza `READY`, sin
ciclo CPU. Los abortos llevan a `NO_IMAGE`; una nueva carga válida vuelve a
preparar y publicar su propio tamaño. Estas comprobaciones no acreditan la
ejecución de instrucciones ni la inicialización real de PC, RF, pipeline o DMEM.

Son **23 ejecuciones adicionales**: nueve de unidad, nueve con Execution Control
y cinco de límites. El catálogo conserva 1363 casos canónicos; 218 tienen alguna
ejecución disponible y 1145 continúan pendientes. `TEST-MEM-008` conserva sus
obligaciones de CPU/sistema y permanece pendiente.

### Reproducción y evidencia

Con la imagen exacta de `docker/image.ref`, `make check` incluye Loader. Verilator
comprueba `execution_control` y `loader` como raíces separadas; la FSM se analiza
dentro del primero, sin desactivar advertencias de múltiples tops.

La regresión completa aprobó formato, lint, catálogo, **40 pruebas de
infraestructura y 408 ejecuciones RTL**, sin fallos ni errores: las 385 anteriores
y las 23 agregadas para Loader. También aprobaron los cinco rechazos
suplementarios de capacidades inválidas.

Desde `/workspace/tp3`, la selección local puede ejecutarse con:

```bash
bash scripts/run_tests.sh --test TEST-MEM-007 --test TEST-PLAT-001 \
  --format json --reports-dir build/reports/loader/selected
```

`build/reports/loader/` conserva diagnósticos, comandos y hashes de las fuentes
comprobadas en `context.json`. Una verificación suplementaria usa las cinco
capacidades inválidas de `TEST-PLAT-001/C009–C013`: exige rechazo con
`CONFIG_INVALID_CAPACITY` y ausencia de elaboración del buffer parcial. No agrega
casos canónicos ni reemplaza la ejecución funcional del catálogo.

La preparación real y la conexión de los tres módulos en el banco local se
documentan en [la evidencia de Session Preparation](execution.md#evidencia-local-de-session-preparation--cuarto-bloque-de-8).
Continúan pendientes la conexión en `processor_top`, la verificación con
IMEM/CPU/UART reales, síntesis, timing y placa. Este bloque no cierra #8.

## Evidencia local del reemplazo de imagen

`tb/session_lifecycle_tb.sv` agrega seis ejecuciones de `TEST-MEM-008` con los
cuatro módulos de sesión reales. La conexión, los modelos y la reproducción se
describen en [la evidencia del ciclo de vida](execution.md#evidencia-local-del-ciclo-de-vida-de-sesión).

| IDs | Comprobación local | Alcance pendiente |
|---|---|---|
| `TEST-MEM-008/C001–C002` | Reemplazo de 16 por cuatro bytes: invalidez al aceptar LOAD, preparación completa y publicación en READY con PC/RF/marcas modelados limpios; autorización RUN/STEP posterior. Conserva el sufijo físico de IMEM. | Ejecución legal de A/B y exclusión del sufijo por IF con el nuevo tamaño confirmado. |
| `TEST-MEM-008/C003–C005` | Con el rechazo modelado mediante ausencia de `load_request`, conserva fase, imagen, contador, PC/RF/marcas e IMEM. | Validación Controller de los tamaños N40=0,1028,6 y respuesta de rechazo. |
| `TEST-MEM-008/C006` | LOAD aceptado invalida la imagen anterior; tres bytes y aborto dejan NO_IMAGE, RUN/STEP se ignoran y una recarga de cuatro bytes llega a READY. | Detección de timeout, recuperación y respuestas de transporte. |

El fixture instala residuos observables de A (`x1=7`, `x2=9`, palabra DMEM cero=7)
después de un terminal controlado. Esa instalación es artificial y no sustituye
la ejecución de A. La preparación limpia marcas y conserva el dato físico; la
recarga de B conserva las tres palabras de IMEM posteriores al prefijo de cuatro
bytes. El banco comprueba el tamaño publicado, sin ejecutar fetch de producción.
Loader recibe tamaños ya validados; no se le agrega la política de rechazo del
Controller. El aborto también se suministra desde el banco, sin medir un timeout.

Para `TEST-MEM-008/C007` se revisaron [Protocol: imagen y tamaño](../protocol.md#imagen-y-tamaño),
[Loader: posición de bytes](../architecture/session/loader.md#identificación-de-la-posición-de-cada-byte)
y [su interfaz](../interfaces.md#bloque-8-1). El formato secuencial no representa
origen configurable ni huecos; no se agregaron campos wire. No hay un paquete
inválido representativo que simular. El caso permanece `pending` en el runner,
porque este acredita simulaciones, y su revisión queda registrada aquí.
