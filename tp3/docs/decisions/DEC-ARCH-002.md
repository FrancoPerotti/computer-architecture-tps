### DEC-ARCH-002 — Etapa de resolución de branches y jumps

**Contrato vigente de consulta:** [stage_ex](../architecture/cpu/stage_ex.md), [datapath](../architecture/cpu/datapath.md), [control_and_hazards](../architecture/cpu/control_and_hazards.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** CPU / Pipeline

**Fecha de aprobación:** 2026-09-22

**Contexto:** El pipeline debe resolver `beq`, `bne`, `jal` y `jalr` con destinos byte-addressed conforme a `DEC-ARCH-001`, conservar el estado correcto ante cambios de flujo y evitar efectos de instrucciones del camino incorrecto. La decisión se cierra con los siete acuerdos siguientes; su realización física y las prioridades concretas corresponden a decisiones posteriores.

**Decisión:** Se aprueban conjuntamente los siete acuerdos de resolución, destinos, redirección, descarte, enlace, eventos `wrong-path` y fetch secuencial que se detallan a continuación.

#### Acuerdo aprobado — etapa arquitectónica de resolución

**Fecha:** 2026-09-22

`beq`, `bne`, `jal` y `jalr` se resolverán en **EX — Execute**. Una instrucción de control solo podrá producir una decisión válida de cambio de flujo al alcanzar EX como instrucción válida. EX es el punto arquitectónico de resolución, sin exigir un mecanismo RTL particular ni excluir cálculos parciales previos.

Esta elección permite utilizar el esquema general de operandos y dependencias de ejecución sin exigir resolución temprana especializada en ID. Al conocerse la redirección en EX, pueden existir instrucciones más jóvenes ya admitidas; el acuerdo de descarte fija su semántica sin imponer cantidad de invalidaciones ni ciclos de penalidad.

Este primer acuerdo fija la etapa; los acuerdos siguientes establecen condiciones, destinos, enlace, actualización del PC e invalidación. Las prioridades entre redirect, stall y flush y las señales RTL concretas corresponden a `DEC-ARCH-003`.

#### Acuerdo aprobado — condición y cálculo del destino en EX

**Fecha:** 2026-09-22

Para una instrucción de control válida, EX determinará la condición efectiva y calculará el destino arquitectónico sobre operandos y direcciones de 32 bits conforme a RV32I:

```text
beq:  taken = (rs1_effective == rs2_effective)
      target = instruction_PC + immediate_B

bne:  taken = (rs1_effective != rs2_effective)
      target = instruction_PC + immediate_B

jal:  salto incondicional
      target = instruction_PC + immediate_J

jalr: salto incondicional
      target = (rs1_effective + immediate_I) & 0xFFFFFFFE
```

Los inmediatos B, J e I se interpretarán según su codificación RV32I. La comparación de branches abarcará los 32 bits completos y no dependerá de una interpretación signed/unsigned. `rs1_effective` y `rs2_effective` representarán los valores arquitectónicos más recientes para la instrucción: `DEC-ARCH-003` definirá el forwarding y/o stall que impida decisiones con operandos obsoletos, sin fijar aquí su matriz o implementación.

Para `beq`, `bne` y `jal`, `instruction_PC` será el PC asociado a la propia instrucción y preservado hasta EX, no el PC global que esté usando IF para otra instrucción. Para `jalr`, el bit 0 de la suma de 32 bits se forzará a cero. Las expresiones `taken` y `target` describen resultados conceptuales, no nombres de señales RTL obligatorias. Podrán utilizarse comparador, ALU, sumadores dedicados o recursos compartidos si preservan esta semántica y cumplen timing.

El acuerdo del enlace fija el valor y la etapa de escritura sin imponer su cálculo físico. La legalidad de destinos desalineados o inválidos y sus faults corresponde a `DEC-ARCH-004`; este acuerdo fija el valor arquitectónico del destino.

#### Acuerdo aprobado — política de redirección del PC

**Fecha:** 2026-09-22

EX determinará conceptualmente si una instrucción de control válida requiere redirigir el flujo y el destino correspondiente. La lógica asociada a IF/PC aplicará esa decisión al seleccionar el próximo PC efectivo; EX no será propietario directo del registro PC. `redirect_valid` y `redirect_target` son nombres explicativos, no señales RTL obligatorias:

```text
beq:  redirigir si rs1_effective == rs2_effective
bne:  redirigir si rs1_effective != rs2_effective
jal:  redirigir si la instrucción en EX es válida
jalr: redirigir si la instrucción en EX es válida

si se aplica una redirección: próximo PC = destino calculado en EX
si no hay redirección:     continuar con el flujo secuencial
```

Un branch no tomado no redirigirá ni invalidará instrucciones válidas del camino secuencial por su sola presencia. Una entrada inválida en EX tampoco podrá modificar el PC, aunque sus bits residuales codifiquen una instrucción de control. Los destinos mantienen las fórmulas del acuerdo anterior.

La redirección solo podrá actualizar estado secuencial como parte de un ciclo lógico efectivo del CPU conforme a `DEC-ARCH-008`. Durante `HOLD`, una evaluación combinacional de EX no cambiará el PC; un `STEP` aceptado autorizará exactamente un ciclo lógico y, cuando corresponda, una sola actualización del PC, sin repetir la redirección en flancos posteriores sin nuevo avance; en `RUN` se aplicará cuando corresponda en ciclos habilitados. La selección conceptual de próximo PC no obliga a que PC cambie en todo ciclo efectivo: un stall puede retenerlo según los enables locales que defina `DEC-ARCH-003`.

El acuerdo siguiente fija el descarte de instrucciones jóvenes; los registros afectados, la prioridad entre redirect, stall, flush y otros eventos y la realización RTL del selector y de los enables locales corresponden a `DEC-ARCH-003`. La política de redirección no determina la relación exacta de una redirección coincidente con un stall ni sustituye la política de faults de `DEC-ARCH-004`.

#### Acuerdo aprobado — descarte de instrucciones jóvenes ante redirección

**Fecha:** 2026-09-22

Cuando una instrucción de control válida en EX produzca una redirección (`beq` o `bne` tomado, `jal` o `jalr`), **toda instrucción más joven admitida por el camino secuencial incorrecto quedará arquitectónicamente inválida**. La instrucción de control conservará su validez; las instrucciones válidas más antiguas no se descartarán por esa redirección y podrán completar sus efectos normales conforme a sus propias condiciones. No se tratará la redirección como un `reset` ni como un vaciado global del pipeline. IF e ID son ubicaciones ilustrativas de trabajo joven, no una selección obligatoria de registros interetapa o una cantidad fija de instrucciones descartadas.

Una instrucción invalidada carecerá de efectos funcionales aunque queden bits residuales en un registro: no podrá escribir registros o DMEM, redirigir el PC, iniciar la finalización mediante `halt`, producir un fault arquitectónico ni causar otros cambios arquitectónicos. Un `halt` joven descartado no iniciará drenado según `DEC-SYS-001`; un candidato de fault del camino descartado no se convertirá en fault arquitectónico según `DEC-ARCH-001`. Los efectos de instrucciones más antiguas conservarán sus propias reglas, sin decidir aquí la prioridad frente a un fault anterior u otras causas concurrentes.

Cuando `beq` o `bne` no se tome, el camino secuencial seguirá siendo válido y ninguna instrucción de ese camino se invalidará solo por la presencia del branch. Esta regla fija únicamente la semántica del descarte; las señales, bits físicos que se limpien, registros interetapa afectados, temporización ciclo a ciclo y prioridad entre redirect, stall, bubble y flush corresponden a `DEC-ARCH-003`.

#### Acuerdo aprobado — valor de enlace de `jal` y `jalr`

**Fecha:** 2026-09-22

Las instrucciones válidas `jal` y `jalr` producirán como valor arquitectónico de enlace de 32 bits:

```text
link_value = instruction_PC + 4
```

`instruction_PC` será el PC asociado a la propia instrucción y conservado a lo largo del pipeline; no se utilizará el PC global de IF, que puede corresponder a otra instrucción. Por ejemplo, si `instruction_PC = 0x00000020`, el valor de enlace será `0x00000024` aunque IF presente otro PC.

El valor de enlace, o información equivalente que permita reconstruirlo exactamente, deberá preservarse hasta WB a través del recorrido de pipeline (incluidos `EX/MEM` y `MEM/WB`). La escritura arquitectónica de `rd` tendrá lugar en **WB**, cualificada por validez y avance conforme a `DEC-ARCH-008`, sin escritura anticipada del banco en EX. Si `rd = x0`, el salto y su redirección seguirán siendo válidos pero `x0` conservará su valor cero.

No se fija dónde se realiza físicamente la suma, si se transporta el PC o el resultado, si se comparte un sumador, ni los campos o nombres RTL concretos. La elección deberá preservar el valor correcto en WB sin alterar la política posterior de forwarding, stalls y prioridades de `DEC-ARCH-003`.

#### Acuerdo aprobado — efectos de eventos detectados en instrucciones `wrong-path`

**Fecha:** 2026-09-22

Un evento asociado a una instrucción solo podrá modificar el estado arquitectónico o global de ejecución si la instrucción sigue siendo válida y pertenece al camino correcto. La detección interna de una condición podrá producir un **candidato** sin confirmarlo arquitectónicamente: si una instrucción de control más antigua invalida la operación, se descartarán la instrucción y sus eventos asociados. No se exige que las condiciones se detecten anticipadamente ni se fija dónde se confirman.

En particular, un `halt` más joven que quede `wrong-path` no detendrá la admisión del camino correcto, no iniciará drenado y no activará `FINISHED` ni otra finalización normal, conforme a `DEC-SYS-001` y `REQ-EXEC-013`. Un fetch o acceso de memoria con condición candidata a fault que luego pertenezca al camino descartado no generará un fault arquitectónico ni alterará el estado global de ejecución, conforme a `DEC-ARCH-001` y `REQ-EXEC-018`.

La misma regla se aplica a cualquier instrucción invalidada: no escribirá registros ni DMEM, no redirigirá el PC y no producirá efectos arquitectónicos o cambios globales originados por esa instrucción. Esto precisa la distinción entre **condición candidata** y **evento arquitectónico confirmado** del acuerdo de descarte anterior; la mera presencia de bits residuales o una detección temprana no constituyen un commit.

Las etapas, confirmaciones, prioridad por antigüedad y transporte están fijados por `DEC-ARCH-004` y `DEC-ARCH-003`, acuerdos 40–47. Este acuerdo no modifica los efectos de una operación válida del camino correcto ni la prioridad global de `reset` establecida en `DEC-ARCH-008`.

#### Acuerdo aprobado — penalización de control y ausencia de predicción

**Fecha:** 2026-09-22

La arquitectura inicial utilizará **fetch secuencial por defecto** sin predictor de branches ni punto alternativo de resolución temprana. Mientras una instrucción de control avanza hacia EX, IF seguirá provisionalmente `PC + 4` cuando el ciclo efectivo y sus enables locales permitan avanzar. Este flujo provisional no obliga a modificar PC durante `HOLD` o un stall: la prioridad y los enables concretos siguen sujetos a `DEC-ARCH-003` y `DEC-ARCH-008`.

Si un `beq`/`bne` tomado o un `jal`/`jalr` válido determina una redirección en EX, la lógica IF/PC seleccionará el destino según los acuerdos anteriores y **todo trabajo más joven del camino secuencial incorrecto deberá quedar inválido**. Se acepta el costo del trabajo provisional iniciado antes de conocer la redirección, sin que una instrucción descartada pueda producir efectos arquitectónicos o eventos globales. Un branch no tomado conservará el camino secuencial, sin penalización de invalidación por la mera presencia del branch; otros stalls independientes podrán ocurrir.

La arquitectura inicial excluye:

- predictor dinámico;
- predicción estática adicional;
- BTB;
- tablas de historial;
- delay slots;
- resolución anticipada en ID;
- tratamiento temprano especial de `jal`/`jalr`.

Todas las instrucciones de control requeridas conservarán EX como único punto arquitectónico de resolución.

El trabajo joven realmente presente dependerá de la ocupación, stalls, bubbles y demás condiciones: no se fija una penalización constante de ciclos ni una cantidad universal de entradas descartadas. Una cifra nominal, por ejemplo «dos ciclos», solo describirá un caso concreto, nunca el contrato arquitectónico.

Introducir después predicción, BTB o resolución temprana requerirá revisar explícitamente `DEC-ARCH-002` y la verificación del flujo, sus invalidaciones y hazards. Los acuerdos 41–42 de `DEC-ARCH-003` fijan después las acciones y flushes, y el 45 audita las coincidencias funcionales; la implementación física se sujeta a esos contratos.

#### Aclaración aprobada — fetch secuencial provisional y ausencia de predictor

**Fecha:** 2026-09-23

El avance provisional de IF por `PC + 4` mientras `beq` o `bne` llega a EX es **observablemente equivalente** a una política estática `not taken`:

| Resultado del branch | Comportamiento |
|---|---|
| No se toma | El camino secuencial conserva su validez |
| Se toma | Se redirige el PC y se descarta el trabajo joven `wrong-path` |

Esta equivalencia de comportamiento **no constituye un predictor estático `always not taken` implementado explícitamente**. No habrá estructura de predicción ni decisión de predicción asociada al branch: `PC + 4` es simplemente el fetch por defecto mientras no se haya resuelto una redirección válida y el avance esté habilitado.

La arquitectura inicial se describe como **fetch secuencial por defecto + resolución de branches en EX + invalidación del trabajo `wrong-path` ante redirect**. Esta aclaración pertenece a `DEC-ARCH-002` y no modifica sus siete acuerdos, la ausencia inicial de predictor dinámico, predicción estática adicional, BTB, historial, delay slots o resolución anticipada en ID, ni los ciclos efectivos y stalls ya establecidos. Incorporar cualquiera de esos mecanismos exigiría revisar explícitamente `DEC-ARCH-002`.

**Justificación:** La resolución uniforme en EX y el fetch secuencial por defecto evitan predicción y resolución anticipada especializada; la invalidación del camino incorrecto preserva la semántica de ejecución aunque se acepte una penalización variable de control.

**Consecuencias:** IF/PC aplicará las redirecciones válidas de EX en ciclos efectivos, el trabajo joven `wrong-path` no tendrá efectos arquitectónicos y `jal`/`jalr` escribirán el enlace en WB. No se exige una penalización constante ni una realización RTL particular.

**Aspectos diferidos:** Los detalles siguientes no bloquean el cierre de `DEC-ARCH-002` ni son pendientes internos de esta decisión:

`DEC-ARCH-003` resolverá estos aspectos:

- El forwarding concreto.
- Los stalls y bubbles.
- Las señales y la realización física de flush/invalidation.
- Los registros interetapa, enables y prioridades entre redirect, stall, flush y otros eventos.
- La temporización concreta del pipeline.
- La realización física del cálculo y transporte del enlace, preservando su valor y escritura en WB ya aprobados.

`DEC-ARCH-004` ya resolvió la política arquitectónica de faults, instrucciones inválidas, legalidad de destinos y accesos desalineados y confirmación de errores, preservando el descarte de candidatos `wrong-path` aquí aprobado. La coordinación con stalls e invalidaciones físicas corresponde a `DEC-ARCH-003`.

**Requisitos afectados:** `REQ-DOC-008`, `REQ-CPU-008` a `REQ-CPU-011`, `REQ-CPU-013`, `REQ-CPU-017`, `REQ-ISA-001`, `REQ-ISA-005`, `REQ-ISA-006`, `REQ-ISA-032`, `REQ-MEM-016`, `REQ-EXEC-013`, `REQ-EXEC-018`, `REQ-HAZ-006` a `REQ-HAZ-010`.

**Reemplaza / Reemplazada por:** No aplica.

---
