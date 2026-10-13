### DEC-SYS-010 — Versión del ISA

**Contrato vigente de consulta:** [stage_id](../architecture/cpu/stage_id.md), [datapath](../architecture/cpu/datapath.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Sistema / ISA

**Fecha de aprobación:** 2026-09-19

**Contexto:** La consigna define el subconjunto de instrucciones RISC-V requerido, pero no identifica una versión concreta del estándar para determinar sus codificaciones y su semántica exacta.

**Opciones consideradas:**

1. Utilizar una referencia RISC-V sin fijar versión.
2. Adoptar automáticamente la revisión más reciente disponible.
3. Adoptar RISC-V User-Level ISA V2.2, que es la versión declarada como base por la documentación indicada para el trabajo.

**Decisión:** El proyecto utiliza el subconjunto requerido de **RV32I según RISC-V User-Level ISA V2.2**.

**Justificación:** Fijar una versión evita que CPU, assembler y tests interpreten de forma diferente las codificaciones o la semántica de una instrucción. La documentación proporcionada declara que está basada en User-Level ISA V2.2.

**Referencia:** <https://msyksphinz-self.github.io/riscv-isadoc/>

**Consecuencias:**

- el procesador debe utilizar codificaciones y efectos arquitectónicos compatibles con esa versión;
- el assembler debe generar esas mismas codificaciones;
- los resultados esperados de los tests deben aplicar esa misma semántica;
- cualquier cambio de versión requiere revisar y reemplazar explícitamente esta decisión.

**Requisitos afectados:** `REQ-CPU-001`, `REQ-CPU-013` a `REQ-CPU-015`, `REQ-ISA-001` a `REQ-ISA-033`, `REQ-MEM-006`, `REQ-HAZ-009`, `REQ-SW-003`.

**Reemplaza / Reemplazada por:** No aplica.

---
