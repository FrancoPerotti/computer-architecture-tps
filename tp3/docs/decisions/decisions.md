# TP3 — Decisiones aprobadas

- **Tipo:** registro de decisiones.
- **Estado documental:** decisiones vigentes.

Este índice reúne las decisiones del diseño vigente. Sus contratos se consultan en [Diseño FPGA consolidado](../architecture/system_overview.md).

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [2. Convenciones](#2-convenciones)
- [3. Sistema y alcance](#3-sistema-y-alcance)
- [4. CPU y arquitectura](#4-cpu-y-arquitectura)
- [4. Clock y timing](#4-clock-y-timing)
- [5. Debug y protocolo](#5-debug-y-protocolo)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

<a id="1-propósito"></a>

## Propósito y alcance

Este documento reúne las decisiones aprobadas que definen el sistema y enlaza sus contratos y justificaciones.

Las decisiones todavía no resueltas se registran en `pending_decisions.md`. Cuando una decisión pendiente se aprueba, conserva su identificador y se traslada a este documento.

El [mapa de autoridad por tema](../architecture/system_overview.md#autoridad-documental-por-tema) identifica la especificación y las decisiones de cada tema.

## 2. Convenciones

Cada decisión aprobada contiene:

- **Estado:** `Aprobada`.
- **Dominio:** área principal afectada.
- **Contexto:** problema que resuelve el diseño.
- **Decisión:** comportamiento y condiciones del sistema.
- **Justificación:** razones de la selección.
- **Consecuencias:** restricciones y efectos sobre los demás componentes.
- **Requisitos afectados:** trazabilidad hacia `requirements.md`.

---

## 3. Sistema y alcance

### DEC-SYS-001 — Representación y semántica de STOP/HALT

**Estado:** Aprobada

[DEC-SYS-001](DEC-SYS-001.md)

---

### DEC-SYS-002 — Comportamiento ante ausencia de STOP/HALT

**Estado:** Aprobada

[DEC-SYS-002](DEC-SYS-002.md)

---

### DEC-SYS-003 — Política general de reprogramación

**Estado:** Aprobada

[DEC-SYS-003](DEC-SYS-003.md)

---

### DEC-SYS-004 — Capacidades iniciales de memoria

**Estado:** Aprobada

[DEC-SYS-004](DEC-SYS-004.md)

---

### DEC-SYS-005 — Criterio de memoria de datos utilizada

**Estado:** Aprobada

[DEC-SYS-005](DEC-SYS-005.md)

---

### DEC-SYS-006 — Información observable mediante Debug

**Estado:** Aprobada

[DEC-SYS-006](DEC-SYS-006.md)

---

### DEC-SYS-009 — Estrategia del assembler

**Estado:** Aprobada.

[DEC-SYS-009](DEC-SYS-009.md)

---

### DEC-SYS-010 — Versión del ISA

**Estado:** Aprobada

[DEC-SYS-010](DEC-SYS-010.md)

---

## 4. CPU y arquitectura

### DEC-ARCH-001 — Organización y comportamiento de las memorias

**Estado:** Aprobada

[DEC-ARCH-001](DEC-ARCH-001.md)

---

### DEC-ARCH-002 — Etapa de resolución de branches y jumps

**Estado:** Aprobada

[DEC-ARCH-002](DEC-ARCH-002.md)

---

### DEC-ARCH-003 — Política de hazards

**Estado:** Aprobada

[DEC-ARCH-003](DEC-ARCH-003.md)

---

### DEC-ARCH-004 — Instrucciones inválidas y accesos desalineados

**Estado:** Aprobada

[DEC-ARCH-004](DEC-ARCH-004.md)

---

### DEC-ARCH-006 — Implementación física de las memorias

**Estado:** Aprobada

[DEC-ARCH-006](DEC-ARCH-006.md)

---

### DEC-ARCH-007 — Temporización del banco de registros

**Estado:** Aprobada

[DEC-ARCH-007](DEC-ARCH-007.md)

---

### DEC-ARCH-008 — Reset y enables

**Estado:** Aprobada

[DEC-ARCH-008](DEC-ARCH-008.md)

---

### DEC-ARCH-009 — Campos de pipeline expuestos por debug

**Estado:** Aprobada

[DEC-ARCH-009](DEC-ARCH-009.md)

---

## 4. Clock y timing

### DEC-ARCH-005 — Frecuencia objetivo y distribución de clock

**Estado:** Aprobada

[DEC-ARCH-005](DEC-ARCH-005.md)

---

## 5. Debug y protocolo

### DEC-PROTO-001 — Formato detallado del protocolo

**Estado:** Aprobada.

[DEC-PROTO-001](DEC-PROTO-001.md)

---

### DEC-PROTO-002 — Comandos adicionales

**Estado:** Aprobada

[DEC-PROTO-002](DEC-PROTO-002.md)

---

### DEC-PROTO-003 — Timeouts y recuperación

**Estado:** Aprobada

[DEC-PROTO-003](DEC-PROTO-003.md)

---

### DEC-SYS-007 — Servicios y parámetros generales de UART

**Estado:** Aprobada.

[DEC-SYS-007](DEC-SYS-007.md)

---

## Referencias y trazabilidad

- [Requisitos](../requirements.md): obligaciones afectadas por cada acuerdo.
- [Decisiones pendientes](pending_decisions.md): decisiones de diseño abiertas y condiciones de cierre.
- [Mapa de autoridad documental](../architecture/system_overview.md#autoridad-documental-por-tema): contrato vigente de consulta para cada tema.
