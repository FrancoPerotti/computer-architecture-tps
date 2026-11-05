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

Las comprobaciones que detecten un defecto deben corregir la especificación y señalar sus efectos sobre los requisitos y los componentes afectados.

<a id="7-software-de-pc"></a>

## 3. Software de PC

<a id="dec-sys-008--formato-de-la-aplicación-de-pc"></a>

El diseño de la aplicación se define en [DEC-SYS-008 — Aplicación de PC](DEC-SYS-008.md), incluida en el [índice de decisiones aprobadas](decisions.md). No hay decisiones de diseño de software de PC abiertas registradas en este documento. La implementación y las comprobaciones de producto conservan sus [criterios de verificación](../software/viewrv/verificacion.md).

<a id="5-cpu-y-arquitectura"></a>

## Referencias y trazabilidad

- [Requisitos](../requirements.md): obligaciones y criterios de aceptación.
- [Decisiones](decisions.md): acuerdos aprobados y sus revisiones.
- [Diseño FPGA consolidado](../architecture/system_overview.md): diseño actual y contratos relacionados.
- [Protocolo](../protocol.md): intercambios y representación externa que debe respetar el software.
- [Plan de verificación](../verification/verification_plan.md): casos, expectativas y criterios de comparación del hardware.
- [Plan](../plan.md): fases, hitos y condiciones globales de avance.
