### DEC-SYS-001 — Representación y semántica de STOP/HALT

**Contrato vigente de consulta:** [faults_and_termination](../architecture/session/faults_and_termination.md), [execution_control](../architecture/session/execution_control.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Sistema / Ejecución

**Fecha de aprobación:** 2026-09-20

**Contexto:** El sistema necesita un mecanismo explícito que permita a un programa indicar su finalización. Debido a que el procesador utiliza un pipeline, detectar el final del programa no implica que la ejecución pueda detenerse inmediatamente: pueden existir instrucciones válidas anteriores todavía pendientes de completar. También es necesario distinguir una finalización intencional de situaciones como la ejecución accidental de memoria vacía o una instrucción inválida.

**Opciones consideradas:**

1. Incorporar una instrucción custom `halt` utilizando uno de los espacios designados por RISC-V para extensiones no estándar.
2. Utilizar la instrucción estándar `EBREAK` como indicador de fin de programa.
3. Interpretar la palabra `0x00000000` como fin de programa.
4. Utilizar una convención software basada en una instrucción que produzca un loop infinito, por ejemplo `jal x0, 0`.

**Decisión:** La arquitectura incorpora una instrucción custom sin operandos denominada **`halt`**, codificada como `0x0000000B`. Su patrón completo tiene `bits[31:7] = 0` y el major `opcode` `custom-0`, `bits[6:0] = 0001011`.

`halt` no producirá efectos arquitectónicos sobre el banco de registros ni sobre la memoria de datos.

Solo el reconocimiento de un `halt` válido y perteneciente al flujo correcto podrá iniciar la finalización. Un `halt` que deba descartarse por un branch, jump u otra instrucción anterior no modificará el estado de ejecución ni iniciará el drenado.

Cuando `halt` sea reconocido, el procesador dejará de admitir nuevas instrucciones válidas y comenzará el drenado del pipeline. Las instrucciones válidas anteriores a `halt` podrán completar normalmente sus efectos arquitectónicos, mientras que ninguna instrucción posterior a `halt` podrá modificar el estado arquitectónico.

La ejecución se considerará finalizada únicamente cuando, después de haberse reconocido `halt`, el pipeline haya quedado completamente vacío.

En ejecución continua, el drenado continuará automáticamente hasta alcanzar dicho estado. En ejecución paso a paso, el procesador continuará requiriendo un comando `STEP` por cada ciclo, incluso durante el drenado, preservando la relación de un `STEP` por ciclo.

Este acuerdo de sistema no selecciona una etapa ni señales RTL para `halt`. Su concreción posterior en `DEC-ARCH-003` sigue esta secuencia:

1. El acuerdo parcial aprobado el 2026-09-24 fija la detección candidata en ID, la confirmación arquitectónica en EX, la retención del PC registrado y el descarte de trabajo joven.
2. Los acuerdos trigésimo tercero y trigésimo cuarto fijan la codificación funcional de `ID/EX.control`.
3. El cuadragésimo primero de `DEC-ARCH-003` fija el arbitraje combinacional de ocho acciones.
4. El cuadragésimo segundo fija enables/valores `next`.
5. El cuadragésimo quinto audita y resuelve las coincidencias funcionales.

**Justificación:** Una instrucción custom permite representar de forma inequívoca la intención de finalizar el programa sin reutilizar una instrucción estándar con otra semántica ni confundir la terminación normal con una instrucción inválida o memoria sin programar. El espacio `custom-0` está destinado por RISC-V a extensiones no estándar y permite introducir este mecanismo sin colisionar con las instrucciones RV32I requeridas. La separación entre detección de `halt` y finalización efectiva permite preservar los efectos de las instrucciones anteriores que todavía se encuentren dentro del pipeline.

**Referencias:**

- *The RISC-V Instruction Set Manual, Volume I: User-Level ISA, Version 2.2*, mapa de major opcodes: <https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf>.
- RISC-V International, mapa oficial vigente de opcodes RV32/64G: <https://docs.riscv.org/reference/isa/v20260120/unpriv/rv-32-64g.html#rv32-64g>.

**Consecuencias:**

- el assembler debe reconocer el mnemónico `halt` sin operandos y generar la palabra `0x0000000B`;
- el procesador debe reconocer únicamente dicha palabra completa como el marcador de finalización del programa;
- `halt` no debe escribir registros ni memoria;
- un `halt` invalidado por una instrucción anterior no debe afectar el control de ejecución;
- detectar `halt` y finalizar el programa son eventos distintos;
- después de detectar `halt` no deben admitirse nuevas instrucciones válidas;
- las instrucciones válidas anteriores a `halt` deben poder completar su ejecución;
- las instrucciones posteriores a `halt` no deben producir efectos arquitectónicos;
- debe existir una forma de determinar cuándo el pipeline ha quedado vacío;
- en modo continuo, el drenado ocurre automáticamente;
- en modo paso a paso, el drenado respeta la regla de un ciclo por cada `STEP`;
- `0x00000000` no se utilizará como representación de `halt`;
- la etapa de detección y la implementación concreta del drenado permanecen como decisiones de microarquitectura.

**Requisitos afectados:** `REQ-CPU-011`, `REQ-CPU-015`, `REQ-ISA-034`, `REQ-HAZ-010`, `REQ-EXEC-001` a `REQ-EXEC-010`, `REQ-EXEC-013`, `REQ-SW-003`, `REQ-SW-012`, `REQ-DOC-003`.

**Reemplaza / Reemplazada por:** No aplica.
