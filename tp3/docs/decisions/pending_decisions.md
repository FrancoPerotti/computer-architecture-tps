# TP3 — Decisiones pendientes

- **Tipo:** registro de decisiones pendientes.
- **Estado documental:** documentación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [2. Convenciones](#2-convenciones)
- [3. Software de PC](#3-software-de-pc)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

<a id="1-propósito"></a>

## Propósito y alcance

Registrar las decisiones de diseño todavía no resueltas, sus dependencias y condiciones de cierre. Las decisiones aprobadas se consultan en [Decisiones](decisions.md); las fases, hitos y condiciones globales de avance se consultan en el [Plan](../plan.md).

## 2. Convenciones

Cada decisión pendiente conserva su identificador, contexto, opciones a analizar, dependencias, requisitos afectados y condición de cierre.

Cuando una decisión se aprueba, conserva su identificador y se traslada al registro de [Decisiones](decisions.md). Registre decisión, justificación y consecuencias, actualice su vínculo en requisitos y retire la entrada de este documento.

Una comprobación futura que descubra un defecto debe incorporarse con fuente y efecto; no reabrir acuerdos por textos históricos.

<a id="7-software-de-pc"></a>

## 3. Software de PC

### DEC-SYS-008 — Formato de la aplicación de PC

**Estado:** Pendiente

**Dominio:** Software / Interfaz

**Debe resolverse antes de:** Implementar la interfaz de usuario.

**Depende de:** `DEC-SYS-006`, ya aprobada, y flujos de operación definidos por Debug y el protocolo.

**Contexto:** Debe seleccionarse una CLI, TUI, GUI o combinación para operar el sistema y presentar el snapshot aprobado sin acoplar la interfaz a señales combinacionales internas. La aplicación deberá mostrar un fault de memoria como ejecución anormal y no como finalización normal.

**Opciones a analizar:** CLI inicial; TUI; GUI; capas reutilizables con más de una interfaz.

**Requisitos afectados:** `REQ-SW-001`, `REQ-SW-005` a `REQ-SW-010`, `REQ-DBG-013` a `REQ-DBG-017`, `REQ-EXEC-018`.

<a id="5-cpu-y-arquitectura"></a>

## Referencias y trazabilidad

- [Requisitos](../requirements.md): obligaciones y criterios de aceptación.
- [Decisiones](decisions.md): acuerdos aprobados y sus revisiones.
- [Diseño FPGA consolidado](../architecture/system_overview.md): diseño actual y contratos relacionados.
- [Protocolo](../protocol.md): intercambios y representación externa que debe respetar el software.
- [Plan de verificación](../verification/verification_plan.md): casos, expectativas y criterios de comparación del hardware.
- [Plan](../plan.md): fases, hitos y condiciones globales de avance.
