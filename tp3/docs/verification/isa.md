# TP3 — ISA y codificación

- **Tipo:** catálogo de verificación.
- **Estado documental:** pruebas diseñadas, sin ejecutar.

## Propósito y alcance

Este documento define las pruebas de verificación de la ISA y de la codificación de instrucciones. Cada prueba comprueba una familia concreta de operaciones, formatos, señales de control o casos de borde, mediante un conjunto finito de variantes.

El alcance comprende:

- La aplicación de las convenciones, niveles y límites definidos en el [plan de verificación](verification_plan.md).
- La comprobación de las operaciones, inmediatos, codificaciones, señales de control del decoder y destinos de control incluidos en esta sección.
- La definición de las variantes que pertenecen a cada prueba y de sus expectativas.
- La relación entre cada prueba y los contratos arquitectónicos que determinan su comportamiento.

Los contratos enlazados son la fuente autoritativa del comportamiento; este documento no redefine la ISA ni inventa reglas alternativas. La [matriz de cobertura](coverage.md) registra qué requisitos quedan cubiertos y qué trabajo permanece fuera del alcance.

## Índice

- [TEST-ISA-001 — Suma, resta y operaciones lógicas](#test-isa-001)
- [TEST-ISA-002 — Shifts y comparaciones signed/unsigned](#test-isa-002)
- [TEST-ISA-003 — Inmediatos I/S/B/U/J y LUI](#test-isa-003)
- [TEST-ISA-004 — Whitelist y señales de control del decoder](#test-isa-004)
- [TEST-ISA-005 — BEQ/BNE tomado y no tomado](#test-isa-005)
- [TEST-ISA-006 — JAL/JALR y valor de enlace](#test-isa-006)
- [TEST-ISA-007 — Loads y stores de la ISA](#test-isa-007)
- [TEST-ISA-008 — Targets desalineados y fuera de imagen](#test-isa-008)

<a id="test-isa-001"></a>

## TEST-ISA-001 — Suma, resta y operaciones lógicas

- **Nivel:** unidad ALU y CPU.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-ISA-008](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-009](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-013](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-014](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-015](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-023](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-024](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-025](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-026](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-033](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-001](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-006](../requirements.md#2-procesador-y-pipeline).

**Contratos:** [stage_ex](../architecture/cpu/stage_ex.md); [datapath](../architecture/cpu/datapath.md); [stage_id](../architecture/cpu/stage_id.md).

### Qué comprueba y por qué

Esta prueba comprueba que la ALU y el camino de los inmediatos produzcan los resultados definidos para operaciones de 32 bits.

Busca detectar:

- Una operación de la ALU implementada de forma incorrecta.
- La pérdida del `carry` modular al conservar el resultado en 32 bits.
- Un inmediato lógico tratado como `unsigned` antes de realizar su extensión.

Los casos normales comprueban el funcionamiento habitual de cada operación. Los casos extremos comprueban que el resultado conserve exactamente 32 bits, incluidos el desborde modular y los valores con el bit de signo activo.

### Condiciones iniciales

La prueba se ejecuta en dos niveles, con las siguientes condiciones:

- **CPU:** la CPU comienza preparada. `x1` y `x2` contienen los operandos indicados en la fila correspondiente y `rd=x3` comienza en cero.
- **Variante inmediata:** se utiliza `x1` junto con el inmediato firmado de la instrucción. `x2` no se lee.
- **Unidad ALU:** se aplican directamente a la ALU los mismos operandos y señales de control que se utilizarían en la prueba de CPU.

Ninguna variante accede a DMEM.

### Variantes cerradas

La prueba tiene 20 casos canónicos. Cada fila de la tabla de operandos corresponde a una variante y conserva los valores hexadecimales en 32 bits.

El [manifiesto](cases.json) enumera los IDs `TEST-ISA-001/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones fuera de esas 20 variantes.

### Datos de referencia

| Operación | rs1      | rs2 / inmediato | Resultado x3 |
|-----------|----------|-----------------|--------------|
| ADD       | 00000005 | 00000007        | 0000000C     |
| ADD       | FFFFFFFF | 00000001        | 00000000     |
| ADD       | 7FFFFFFF | 00000001        | 80000000     |
| SUB       | 00000009 | 00000004        | 00000005     |
| SUB       | 00000000 | 00000001        | FFFFFFFF     |
| SUB       | 80000000 | 00000001        | 7FFFFFFF     |
| AND       | A5A5A5A5 | 0F0F0F0F        | 05050505     |
| OR        | A5A5A5A5 | 0F0F0F0F        | AFAFAFAF     |
| XOR       | A5A5A5A5 | 0F0F0F0F        | AAAAAAAA     |
| XOR       | FFFFFFFF | FFFFFFFF        | 00000000     |
| ADDI      | 0000000A | 7               | 00000011     |
| ADDI      | 00000000 | -2048           | FFFFF800     |
| ADDI      | FFFFFFFF | 1               | 00000000     |
| ADDI      | 00000000 | 2047            | 000007FF     |
| ANDI      | 12345678 | -1              | 12345678     |
| ANDI      | 12345678 | 15              | 00000008     |
| ORI       | 12345678 | -2048           | FFFFFE78     |
| ORI       | 12345678 | 15              | 1234567F     |
| XORI      | 12345678 | -1              | EDCBA987     |
| XORI      | 12345678 | 0               | 12345678     |

### Procedimiento

1. **Preparar el estado inicial.** Inicializar únicamente los operandos indicados en la variante. Antes de ejecutar, conservar una copia del resto del `Register File` y de DMEM para comprobar que no se modifiquen sin motivo.

2. **Ejecutar la variante según el nivel de prueba.**
   - En la prueba de unidad, aplicar a la ALU los operandos y las señales de control correspondientes y esperar a que se estabilice la lógica combinacional.
   - En la prueba de CPU, colocar la instrucción en la imagen, comenzar desde `PC=0` y ejecutar esa instrucción seguida de `halt`.

3. **Comparar el resultado y los efectos.** Comparar el resultado de la unidad o el valor escrito en `x3` con el valor esperado de la fila. La instrucción debe producir un único writeback elegible. El overflow o `carry` aritmético debe resolverse de forma modular y no debe iniciar un fault.

### Resultados y criterio de aprobación

Para cada fila se espera lo siguiente:

- El resultado coincide exactamente con el valor indicado.
- La operación se calcula módulo `2^32`.
- El inmediato de tipo I se extiende con signo antes de participar en la operación.
- Un overflow o `carry` de la operación no genera un fault.

En la prueba de CPU, la ejecución termina con `halt`. DMEM y los registros que no forman parte del setup ni corresponden a `rd` deben conservar sus valores originales.

La variante es correcta cuando se cumplen simultáneamente estas condiciones:

- El resultado coincide tanto en la prueba de unidad como en la prueba de CPU.
- Existe una única escritura elegible en `rd` por instancia de la instrucción.
- No se produce ninguna escritura de memoria.
- Se aprobaron todos los casos propios y todas las comprobaciones reutilizadas.

La expectativa específica de cada caso está en el [manifiesto](cases.json) y debe ser consistente con el contrato arquitectónico. Si hubiera una contradicción, se corrige la especificación antes de ejecutar la prueba. El valor esperado se calcula independientemente y nunca se obtiene copiando la salida del DUT.

<a id="test-isa-002"></a>

## TEST-ISA-002 — Shifts y comparaciones signed/unsigned

- **Nivel:** unidad ALU y CPU.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-ISA-010](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-011](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-012](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-016](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-017](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-027](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-028](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-029](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-030](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-031](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-033](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-006](../requirements.md#2-procesador-y-pipeline).

**Contratos:** [datapath](../architecture/cpu/datapath.md); [stage_ex](../architecture/cpu/stage_ex.md).

### Qué comprueba y por qué

Esta prueba comprueba que los desplazamientos y las comparaciones interpreten correctamente los operandos de 32 bits.

Busca detectar:

- La confusión entre un desplazamiento lógico y uno aritmético.
- El uso de bits de `rs2` que no pertenecen a la cantidad efectiva de desplazamiento.
- Una comparación con signo realizada como si fuera sin signo, o viceversa.
- Un resultado distinto de cero cuando los dos operandos de una comparación son iguales.

Las cantidades 0, 1 y 31 comprueban los extremos y un desplazamiento habitual. Los operandos con el bit 31 activo permiten distinguir la interpretación `signed` de la interpretación `unsigned`.

### Condiciones iniciales

La CPU comienza con una sesión preparada. El banco de pruebas carga los operandos de cada fila en el Register File y deja `x3`, el registro de destino, en cero. En la prueba de unidad se aplican esos mismos operandos y las señales de control correspondientes directamente a la ALU.

Para los desplazamientos, el primer operando es `0x80000001`. En las comparaciones se utilizan los pares de la tabla. Cuando el segundo operando proviene de un inmediato de tipo I, primero se extiende con signo y después se interpreta según la operación de comparación.

Estas variantes no acceden a DMEM. Los registros que no participan como operandos o destino deben conservar sus valores.

### Variantes cerradas

La prueba tiene 37 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-ISA-002/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los casos se distribuyen de la siguiente manera:

- Los 18 desplazamientos combinan las cantidades 0, 1 y 31 con SLL, SRL, SRA, SLLI, SRLI y SRAI.
- Otros tres casos utilizan SLL, SRL y SRA con `rs2=33`. Sus cinco bits bajos representan la cantidad 1; los bits altos no deben cambiarla.
- Las 16 comparaciones aplican las versiones con signo y sin signo a los cuatro pares de registros y a los cuatro pares con inmediato de la tabla.

Los datos y resultados concretos se presentan a continuación.

### Datos de referencia

| shamt | SLL / SLLI | SRL / SRLI | SRA / SRAI |
|------:|------------|------------|------------|
|     0 | 80000001   | 80000001   | 80000001   |
|     1 | 00000002   | 40000000   | C0000000   |
|    31 | 80000000   | 00000001   | FFFFFFFF   |

| A        | B / inmediato     | SLT / SLTI | SLTU / SLTIU |
|----------|-------------------|-----------:|-------------:|
| FFFFFFFF | registro 00000001 |          1 |            0 |
| 80000000 | registro 7FFFFFFF |          1 |            0 |
| 00000007 | registro 00000007 |          0 |            0 |
| 00000001 | registro 00000002 |          1 |            1 |
| 00000000 | inmediato -1      |          0 |            1 |
| FFFFFFFF | inmediato -1      |          0 |            0 |
| FFFFF800 | inmediato -2048   |          0 |            0 |
| 000007FE | inmediato 2047    |          1 |            1 |

### Procedimiento

1. **Preparar los operandos.** Cargar los valores de la variante y guardar el estado de DMEM y de los registros ajenos al resultado. El valor `rs2=33` se utiliza solamente en los tres desplazamientos de formato R.

2. **Aplicar la operación.** En unidad, presentar los operandos y las señales de control a la ALU y esperar su estabilización. En CPU, ejecutar la instrucción correspondiente seguida de `halt`.

3. **Observar la cantidad y la interpretación de los datos.** En los desplazamientos inmediatos, comprobar los bits fijos de la instrucción y utilizar únicamente `shamt[4:0]`; los bits que distinguen SRAI no forman parte de la cantidad. En las comparaciones inmediatas, observar la extensión de signo antes de la comparación.

4. **Comparar el resultado.** Verificar el resultado de la ALU o el valor de `x3` contra la tabla. Comprobar también que DMEM y los registros ajenos al destino conserven su estado.

### Resultados y criterio de aprobación

Los desplazamientos deben producir exactamente los valores de la tabla. Las versiones R e I correspondientes deben coincidir cuando utilizan la misma cantidad efectiva.

Las comparaciones deben producir únicamente 0 o 1. En particular, SLTIU extiende primero el inmediato con signo y después realiza la comparación sin signo.

La instrucción puede escribir su resultado en el registro de destino; no debe escribir memoria ni generar un fault por la interpretación del signo. En CPU, la secuencia finaliza por `halt`.

La aprobación exige que todas las variantes coincidan con la tabla y utilicen las señales de control de la operación legal correspondiente.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-isa-003"></a>

## TEST-ISA-003 — Inmediatos I/S/B/U/J y LUI

- **Nivel:** unidad immediate_generator y CPU.
- **Tipo de estímulo:** legal.
- **Estado:** unidad implementada; comprobación CPU pendiente.

**Requisitos:** [REQ-ISA-007](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-033](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-014](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-005](../requirements.md#2-procesador-y-pipeline).

**Contratos:** [stage_id](../architecture/cpu/stage_id.md); [datapath](../architecture/cpu/datapath.md).

### Ejecución disponible

El banco `immediate_generator_tb` ejecuta las 24 variantes en nivel `Unidad`. Compara el inmediato con `expected.immediate` del manifiesto. La escritura de LUI, la conservación del resto del estado y la terminación se comprobarán en CPU; esta ejecución unitaria no las acredita.

### Qué comprueba y por qué

Esta prueba comprueba que el generador de inmediatos reconstruya correctamente los formatos I, S, B, U y J. También verifica que LUI transporte el inmediato de tipo U hasta writeback mediante el selector IMMEDIATE.

Busca detectar:

- Bits ubicados en una posición incorrecta al reconstruir el inmediato.
- Una extensión de signo incorrecta.
- La aplicación duplicada del desplazamiento implícito de los formatos B y J.
- Una dependencia de LUI respecto de un campo que solo aparenta ser `rs1`.

### Condiciones iniciales

En la prueba de unidad se presenta una palabra de instrucción codificada con el formato y el valor de la variante. El generador de inmediatos recibe esa palabra sin depender de los valores del Register File.

En CPU se prepara una imagen con `lui x3,campo_U` seguida de `halt`. El Register File comienza preparado y `x3` es el destino del resultado. Los registros ajenos a ese destino y DMEM deben conservarse.

Los destinos grandes o desalineados de los formatos B y J se reconstruyen únicamente en la prueba de unidad. Su presencia en los datos del generador no implica que se ejecute un salto a esos destinos en una sesión legal.

### Variantes cerradas

La prueba tiene 24 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-ISA-003/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los formatos I, S, B y J tienen cinco enteros dirigidos cada uno. El formato U tiene cuatro campos dirigidos.

Los cuatro casos de formato U también se utilizan para ejecutar LUI en CPU. Esa comprobación utiliza los mismos datos y no agrega otros casos canónicos.

### Procedimiento

1. **Preparar la palabra codificada.** Distribuir los bits de cada valor según su formato. Para los cuatro casos U, construir una instrucción LUI válida.

2. **Observar el inmediato reconstruido.** Aplicar la palabra al generador y esperar la estabilización combinacional, sin exigir un nuevo flanco. Comparar sus 32 bits con el inmediato esperado de la variante.

3. **Comprobar LUI en CPU.** Ejecutar la imagen preparada para cada campo U y observar el valor escrito en `x3`. Verificar que los bits bajos sean cero y que el resultado no dependa del campo aparente de `rs1`.

4. **Revisar los efectos.** Comprobar que LUI escriba únicamente su destino, que DMEM no cambie y que la ejecución termine por `halt`.

### Resultados y criterio de aprobación

Los formatos I, S, B y J deben producir el entero indicado con su extensión de signo a 32 bits. Los bits repartidos entre distintas posiciones de S, B y J se reconstruyen según las expresiones del contrato.

Los formatos B y J deben incorporar el bit cero implícito una sola vez. En los desplazamientos de tipo I, `shamt[4:0]` permanece separado de los bits fijos de la operación.

Los cuatro campos U deben producir `00000000`, `12345000`, `80000000` y `FFFFF000`. Esos mismos valores deben aparecer en `x3` al ejecutar LUI, sin modificar otros registros ni DMEM.

La aprobación requiere coincidencia bit a bit en el generador y en los cuatro resultados de LUI.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-isa-004"></a>

## TEST-ISA-004 — Whitelist y señales de control del decoder

- **Nivel:** unidad decoder e integración ID.
- **Tipo de estímulo:** legal y mutación de palabra.
- **Estado:** unidad implementada; integración ID pendiente.

**Requisitos:** [REQ-CPU-005](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-015](../requirements.md#2-procesador-y-pipeline), [REQ-ISA-033](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-034](../requirements.md#3-conjunto-de-instrucciones).

**Contratos:** [stage_id](../architecture/cpu/stage_id.md).

### Ejecución disponible

El banco `decoder_tb` ejecuta las 409 variantes en nivel `Unidad` y compara las nueve salidas del decoder con las expectativas del manifiesto. Los 437 pares de mutación conservan sus IDs y orígenes. La formación de candidatos y el tratamiento de `IF/ID.valid` se comprobarán en integración ID; el banco unitario solo consume la palabra de instrucción y no acredita esa integración.

### Qué comprueba y por qué

Esta prueba comprueba que el decoder acepte exactamente las codificaciones de la whitelist y produzca las señales de control previstas para cada instrucción.

Busca detectar:

- La aceptación de una palabra por su opcode sin comprobar otros campos fijos, como `funct7`.
- Señales de control que permitan efectos arquitectónicos en una palabra ilegal.
- La interpretación de una palabra residual de un latch inválido como si fuera una instrucción activa.
- La pérdida de cobertura al eliminar palabras repetidas entre las mutaciones.

Una mutación no se considera ilegal automáticamente. Si al invertir un bit se obtiene otra instrucción de la whitelist, se comprueba como esa instrucción legal.

### Condiciones iniciales

En unidad se aplica al decoder cada palabra de 32 bits indicada en el caso.

En integración ID, esa misma palabra se coloca en `IF/ID.instruction`, con `PC=0`, el valor de `IF/ID.valid` de la variante y `fetch_fault_valid=0`. Los demás latches permanecen inválidos. No existe una frontera de EX que descarte el candidato de ID.

Este fixture permite observar la decodificación y la formación del candidato. Todavía no representa una confirmación de fault ni de `halt`.

### Variantes cerradas

La prueba tiene 409 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-ISA-004/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

La enumeración comprende palabras legales, mutaciones de campos fijos, la palabra exacta de `halt`, mutaciones de esa palabra, codificaciones adicionales y una entrada inválida de IF/ID:

- Hay 64 registros asociados con las dos configuraciones de campos variables de las instrucciones RV32I.
- Los registros asociados con mutaciones de bits fijos son 336. Cada uno conserva los pares de instrucción de origen y bit invertido que representa.
- La palabra personalizada exacta de `halt` tiene un caso; sus inversiones individuales de bits están asociadas con 32 registros.
- Las cuatro palabras adicionales son cero, MUL, ECALL y BLT.
- El caso residual utiliza la palabra cero con `IF/ID.valid=0`.

Estas categorías pueden compartir un registro cuando generan la misma palabra y el mismo valor de validez. Por eso sus cantidades no se suman para obtener el total. La enumeración deduplicada conserva los 409 casos y los 437 pares de origen y bit mutado.

### Procedimiento

1. **Preparar la variante.** Leer la palabra y su validez en el [manifiesto](cases.json). Aplicar una sola vez cada par distinto de palabra y validez.

2. **Observar el decoder.** Comparar `decode_legal`, `alu_op`, los selectores, `flow_op`, `mem_op`, `reg_write` y el uso de ambas fuentes con la expectativa. El decoder RTL no debe utilizarse como única referencia para calcularla.

3. **Observar los candidatos en ID.** Comprobar que una palabra ilegal válida produzca el candidato correspondiente. La palabra de `halt` debe reconocerse como HALT, sin adelantar su confirmación en EX.

4. **Comprobar la cobertura de mutaciones.** Revisar cada par conservado en `mutations`. Una palabra que representa varios orígenes debe cubrirlos todos; deduplicarla no elimina esas comprobaciones.

5. **Revisar las señales de control neutras.** En las palabras ilegales y en la entrada residual inválida, comprobar que no se habiliten efectos por interpretar datos inactivos.

### Resultados y criterio de aprobación

Cada palabra debe coincidir con la legalidad y con todas las señales de control especificadas para su caso.

Una palabra ilegal debe seleccionar ADD, un operando de registro y el resultado ALU, con `flow_op=NONE`, `mem_op=NONE` y `reg_write=uses_rs1=uses_rs2=0`. Esos valores mantienen definida la lógica combinacional; no convierten la palabra en una instrucción ejecutable.

Solo `0x0000000B` debe reconocerse como `halt`. Una palabra ilegal con `IF/ID.valid=0` no debe generar un candidato por instrucción activa.

La aprobación requiere que los 437 pares de mutación sigan representados y que cada par de palabra y validez coincida con su expectativa. Ningún origen o bit puede desaparecer por la deduplicación.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-isa-005"></a>

## TEST-ISA-005 — BEQ/BNE tomado y no tomado

- **Nivel:** CPU e integración EX.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-ISA-005](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-006](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-033](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-017](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-007](../requirements.md#4-hazards-y-cambios-de-flujo), [REQ-HAZ-008](../requirements.md#4-hazards-y-cambios-de-flujo).

**Contratos:** [stage_ex](../architecture/cpu/stage_ex.md); [control_and_hazards](../architecture/cpu/control_and_hazards.md).

### Qué comprueba y por qué

Esta prueba comprueba la decisión de BEQ y BNE y el cálculo del destino de un branch. También verifica que el descarte de instrucciones jóvenes ocurra solamente cuando el branch se toma.

Busca detectar una condición de comparación invertida, un destino calculado incorrectamente o un flush aplicado al camino secuencial de un branch no tomado.

Los casos locales comprueban los destinos hacia atrás y un destino desalineado que no se utiliza. Este último no debe generar un fault cuando la comparación indica que el branch no se toma.

### Condiciones iniciales

En CPU se prepara una imagen de 20 bytes. El branch ocupa `PC=0`; las instrucciones siguientes escriben `x3` en `PC=4` y `x4` en `PC=8`. La imagen contiene `halt` en `PC=12` y una instrucción que escribiría `x5` en `PC=16`.

El Register File comienza con los valores de `x1` y `x2` indicados en la variante. Los registros de resultado comienzan preparados. DMEM no participa en estas operaciones y debe conservarse.

En integración EX se prepara un ID/EX válido, sin productores pendientes, con el PC, el offset y los operandos de cada caso local. Ese fixture comprueba el cálculo y la decisión de EX sin ejecutar un programa fuera de la imagen.

### Variantes cerradas

La prueba tiene 8 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-ISA-005/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los cuatro programas hacia adelante combinan BEQ y BNE con operandos iguales o distintos.

Los otros cuatro casos se realizan en EX local: dos toman un branch desde `PC=8` con offset `-8`, y dos dejan sin tomar un branch cuyo offset es `+2`. En estos últimos se utiliza BEQ con operandos distintos y BNE con operandos iguales.

### Datos de referencia

```asm
# PC 0
beq x1,x2,8
addi x3,x0,1
addi x4,x0,2
halt
addi x5,x0,3
```

### Procedimiento

1. **Preparar el programa y los operandos.** Cargar la imagen y los valores de `x1` y `x2`. Utilizar BEQ o BNE según la variante.

2. **Ejecutar y observar la decisión.** Desde `PC=0`, seguir la comparación, la solicitud de redirect y los flags de las instrucciones jóvenes. Si se toma el branch, comprobar el descarte de las instrucciones de ID e IF; si no se toma, comprobar que la instrucción de `PC=4` continúe.

3. **Comparar el estado final.** Ejecutar hasta `halt` y revisar `x3`, `x4` y `x5`, junto con la ausencia de escrituras de memoria.

4. **Aplicar los casos locales.** Presentar en EX el PC, el offset y los operandos de cada variante. Comparar el destino y el candidato de fault sin interpretar ese fixture como una ejecución completa de CPU.

### Resultados y criterio de aprobación

BEQ debe tomarse solamente cuando los operandos son iguales; BNE, solamente cuando son distintos.

En los programas hacia adelante, el branch tomado utiliza el destino 8 y deja `x3=0`. Si no se toma, la instrucción de `PC=4` se ejecuta y deja `x3=1`. En ambos casos, `x4=2`, `x5=0` y la ejecución termina por `halt`.

El destino local hacia atrás debe ser cero. El destino desalineado que no se utiliza no debe producir redirect ni fault. Tampoco debe invalidarse trabajo secuencial cuando el branch no se toma.

La aprobación requiere que las cuatro ejecuciones y los cuatro casos locales coincidan en la decisión, el PC y los commits permitidos.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-isa-006"></a>

## TEST-ISA-006 — JAL/JALR y valor de enlace

- **Nivel:** CPU e integración EX.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-ISA-001](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-032](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-033](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-017](../requirements.md#2-procesador-y-pipeline), [REQ-HAZ-009](../requirements.md#4-hazards-y-cambios-de-flujo).

**Contratos:** [stage_ex](../architecture/cpu/stage_ex.md); [faults_and_termination](../architecture/session/faults_and_termination.md).

### Qué comprueba y por qué

Esta prueba comprueba el destino de JAL y JALR y el valor de enlace que llega a writeback.

Busca detectar:

- La confusión entre el destino del salto y la dirección de retorno `PC+4`.
- La omisión de la limpieza del bit 0 en JALR.
- El uso de la base ya modificada por writeback cuando `rd=rs1`.
- La cancelación del redirect por utilizar `x0` como destino del enlace.

### Condiciones iniciales

La imagen de CPU coloca el salto en `PC=0`, `addi x3,x0,99` en `PC=4`, `addi x4,x0,7` en `PC=8` y `halt` en `PC=12`.

El banco prepara `x1` y el destino `rd` según la variante, sin dependencias previas. Los resultados preparados y DMEM permiten detectar efectos de la instrucción que debe descartarse.

Los dos casos hacia atrás se aplican en EX local con los operandos y el PC indicados. Comprueban el cálculo del destino y del enlace, sin requerir una ejecución repetida de un programa.

### Variantes cerradas

La prueba tiene 10 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-ISA-006/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los dos casos de JAL utilizan la misma imagen y eligen `rd=x5` o `rd=x0`.

Los seis casos de JALR combinan dos pares de base e inmediato —9 con 0, y 12 con -4— con `rd=x5`, `rd=x0` o `rd=x1`. La última elección exige conservar la base anterior al writeback del enlace.

Los dos casos locales hacia atrás utilizan JAL desde `PC=8` con offset `-8`, y JALR desde ese PC con base 1 e inmediato `-1`.

### Procedimiento

1. **Preparar la variante.** Cargar la imagen y los valores iniciales del Register File. Guardar la base que debe utilizar JALR antes de que pueda escribirse el enlace.

2. **Ejecutar el salto.** Comenzar desde `PC=0` y observar el destino calculado en EX en preflanco.

3. **Seguir el redirect y el enlace.** Comprobar que se descarte la instrucción de `PC=4` y que el enlace de JAL o JALR continúe hasta WB. Cuando `rd=x1`, comparar el destino con la base inicial 9 o 12 antes de que se escriba el valor 4.

4. **Comparar los efectos.** Ejecutar hasta `halt` y comprobar `x3=0`, `x4=7` y el destino del enlace. Revisar que `rd=x0` no impida el redirect.

5. **Aplicar los dos casos locales.** Comparar el destino cero y el enlace 12 con los cálculos independientes de cada variante.

### Resultados y criterio de aprobación

En CPU, el destino debe ser 8. La instrucción descartada no escribe `x3`, mientras que la instrucción del destino deja `x4=7`.

Si `rd=x5`, recibe el enlace 4. Si `rd=x0`, permanece en cero y el salto se aplica igualmente. Si `rd=rs1=x1`, recibe 4 después de que el destino haya utilizado la base inicial.

JALR debe limpiar solamente el bit 0: la suma 9 produce el destino alineado 8. Los casos locales hacia atrás deben producir destino cero y enlace 12.

La secuencia termina por `halt`. La aprobación exige un redirect correcto y un único commit del enlace elegible, sin escrituras a `x0`, DMEM o registros del camino descartado.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-isa-007"></a>

## TEST-ISA-007 — Loads y stores de la ISA

- **Nivel:** CPU.
- **Tipo de estímulo:** legal.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-ISA-002](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-003](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-004](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-018](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-019](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-020](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-021](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-022](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-033](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-007](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-008](../requirements.md#2-procesador-y-pipeline).

**Contratos:** [stage_mem](../architecture/cpu/stage_mem.md); [dmem_access](../architecture/memory/dmem_access.md).

### Qué comprueba y por qué

Esta prueba comprueba que las instrucciones de load y store recorran correctamente el decoder, EX/MEM y el camino de memoria de la CPU.

Busca detectar una selección incorrecta del tamaño, de los lanes o de la extensión de signo. En particular, comprueba que LH y LHU reciban las señales de control que distinguen sus resultados.

Las pruebas unitarias de memoria verifican el comportamiento del bloque aislado. Estos casos comprueban que las ocho instrucciones de acceso lo utilicen correctamente desde una CPU completa.

### Condiciones iniciales

Cada variante ejecuta una instrucción de acceso seguida de `halt`. Los loads utilizan `rd=x3`; los stores obtienen su dato de `rs2=x2`.

Para los stores, la fila física comienza con los bytes `[A1, B2, C3, D4]`, las cuatro marcas de validez están activas y `x2=0x12345678`. Los lanes no seleccionados sirven para detectar modificaciones ajenas al acceso.

Para los loads, la fila contiene `[80, FF, 00, 80]` y sus cuatro marcas están activas. Así, el estado lógico de DMEM coincide con los bytes físicos preparados.

Los dos accesos con offset negativo utilizan la palabra `0x12345678` y forman la dirección con base 4 e inmediato `-4`.

### Variantes cerradas

La prueba tiene 22 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-ISA-007/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los 20 accesos nominales utilizan las siete variantes de store y las trece variantes de load de las tablas de memoria, con las cuatro marcas activas.

Otros dos casos ejecutan LW y SW con base 4 e inmediato `-4`. Las variantes de bitmaps y guardas permanecen en las pruebas de memoria; no se agregan aquí nuevos cruces con esos valores.

### Procedimiento

1. **Preparar la fila y los operandos.** Cargar el dato físico, sus marcas y los registros de la variante. Guardar los bytes de los lanes ajenos al acceso y los registros que no deben escribirse.

2. **Ejecutar la instrucción.** Seguir `mem_op` desde el decoder hasta MEM y observar la dirección y el tamaño del acceso.

3. **Observar la selección para writeback.** Antes de capturar MEM/WB, comprobar si MEM utiliza `load_value` o `ex_result`, según la instrucción.

4. **Comparar el resultado.** Contrastar el dato, la máscara y la extensión con la tabla de memoria correspondiente. En los offsets negativos, comprobar que la dirección efectiva sea cero.

5. **Revisar los efectos y la finalización.** Comprobar que los loads no cambien datos ni marcas de DMEM, que los stores no escriban el Register File y que cada secuencia termine por `halt`.

### Resultados y criterio de aprobación

Los bytes seleccionados y la extensión de cada load deben coincidir con las tablas de memoria. Los stores deben modificar solamente los lanes de su máscara.

La dirección efectiva de base 4 más inmediato `-4` debe ser cero. Los loads pueden producir el writeback de su destino; los stores pueden producir su commit en DMEM. No se permiten los efectos de la otra clase de instrucción.

MEM debe seleccionar `load_value` o `ex_result` antes de registrar MEM/WB. No debe agregarse una selección adicional en WB ni un stall propio de la memoria.

La aprobación requiere que las ocho instrucciones cubiertas produzcan sus efectos correctos en CPU completa, con todas las variantes nominales y de offset negativo.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.

<a id="test-isa-008"></a>

## TEST-ISA-008 — Targets desalineados y fuera de imagen

- **Nivel:** CPU e integración EX.
- **Tipo de estímulo:** legal, con condición local indicada.
- **Estado:** diseñada, sin ejecutar.

**Requisitos:** [REQ-ISA-001](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-005](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-006](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-032](../requirements.md#3-conjunto-de-instrucciones), [REQ-ISA-033](../requirements.md#3-conjunto-de-instrucciones), [REQ-CPU-011](../requirements.md#2-procesador-y-pipeline), [REQ-CPU-017](../requirements.md#2-procesador-y-pipeline), [REQ-EXEC-018](../requirements.md#6-finalización-y-modos-de-ejecución).

**Contratos:** [faults_and_termination](../architecture/session/faults_and_termination.md); [stage_ex](../architecture/cpu/stage_ex.md).

### Qué comprueba y por qué

Esta prueba comprueba la diferencia entre un fault de la propia instrucción de salto y un fault del fetch realizado después de un redirect válido.

Busca detectar la cancelación incorrecta de un enlace ya legítimo, la aplicación de un redirect por una instrucción desalineada o la atribución del fault al PC equivocado.

Los destinos desalineados comprueban la validación de EX. Los destinos alineados fuera de la imagen comprueban la detección posterior de IF y su confirmación en ID. El caso local con dos condiciones inválidas verifica la prioridad definida por el contrato.

### Condiciones iniciales

La imagen contiene 16 bytes: el salto o branch ocupa `PC=0`, `addi x3,x0,99` ocupa `PC=4`, `sw x2,0(x0)` ocupa `PC=8` y `halt` ocupa `PC=12`.

El Register File comienza con `x2=7` y `x5=55`. Para el BEQ tomado se prepara `x1=7`; para el BNE tomado, `x1=6`. JALR utiliza base 3 para obtener el destino 2, o base 16 para saltar fuera de la imagen.

DMEM y los registros preparados permiten observar si una instrucción joven descartada produce un efecto. El caso con destino `FFFFFFFE` se aplica localmente para comprobar la selección de causa; no demuestra una trayectoria completa de CPU.

### Variantes cerradas

La prueba tiene 7 casos canónicos. El [manifiesto](cases.json) enumera los IDs `TEST-ISA-008/Cnnn`, sus entradas, el tipo de estímulo y la expectativa. La selección es cerrada: no se agregan combinaciones implícitas.

Los cuatro casos de destino propio desalineado utilizan BEQ, BNE, JAL y JALR tomados, con destino 2.

Los dos casos alineados fuera de imagen utilizan JAL y JALR con destino 16, justo después de la imagen de 16 bytes. El caso local restante aplica JAL hacia `FFFFFFFE`, donde coinciden la desalineación y el acceso inválido.

Los branches no tomados se comprueban mediante la reutilización indicada, sin agregar otros casos propios.

También se ejecutan las comprobaciones reutilizadas de [TEST-ISA-005](#test-isa-005). Se conservan sus IDs originales y no se suman otra vez como casos propios.

### Procedimiento

1. **Preparar la imagen y los operandos.** Mantener los valores que permiten distinguir el enlace del salto y los efectos de las instrucciones jóvenes.

2. **Aplicar el salto y observar EX.** Comparar el candidato de fault y la solicitud de redirect antes del flanco. En las comprobaciones reutilizadas de destino no utilizado, preparar una comparación que deje el branch sin tomar.

3. **Seguir la terminación por fault propio.** Si EX confirma la desalineación, observar el descarte hasta FAULT. Comprobar `x5=55`, `x3=0` y la ausencia del store joven.

4. **Seguir el fetch posterior a un salto válido.** Para el destino alineado 16, comprobar primero el redirect y el enlace 4. Después observar el fault de fetch con `fault_pc=16`, sin atribuirlo al PC del salto.

5. **Comparar la causa local y los efectos.** En el destino `FFFFFFFE`, exigir la prioridad de desalineación. Revisar también que los commits anteriores permitidos se conserven y que los jóvenes no ocurran.

### Resultados y criterio de aprobación

Los cuatro destinos desalineados deben confirmar causa 0 en EX con `fault_pc=0`. No se aplica redirect ni se escribe enlace; `x5` conserva 55 y las instrucciones jóvenes no producen commits.

El destino alineado 16 debe permitir el redirect y conservar el enlace 4. El fetch posterior confirma causa 1 en ID con `fault_pc=16`.

Los branches no tomados no deben fallar por un destino que no utilizan. En el caso local hacia `FFFFFFFE`, la causa 0 prevalece sobre la condición de acceso inválido.

La aprobación exige que causa, PC causante, redirect, enlace y efectos anteriores o jóvenes coincidan con la variante. La detección de un candidato y su confirmación deben observarse como momentos distintos.

Para aprobar la prueba deben cumplirse los resultados y las condiciones de aprobación de todos los casos propios y de todas las comprobaciones reutilizadas. La expectativa de cada variante se consulta en el [manifiesto](cases.json) y se calcula independientemente del DUT. Si aparece una contradicción con un contrato vigente, debe señalarse y resolverse antes de ejecutar; el contrato conserva la autoridad.
