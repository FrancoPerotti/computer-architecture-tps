# TP3 — Índice general de documentación

- **Tipo:** índice de documentación.
- **Estado documental:** documentación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Lectura inicial](#lectura-inicial)
- [Documentos de consulta](#documentos-de-consulta)
- [Recorridos por tarea](#recorridos-por-tarea)
- [Estado y planificación del proyecto](#estado-y-planificación-del-proyecto)
- [Decisiones y antecedentes](#decisiones-y-antecedentes)

## Propósito y alcance

Organiza el acceso a la documentación del TP3 y orienta la lectura según la consulta o el trabajo que se necesita realizar. Cada documento conserva su propósito y su autoridad; el [mapa de autoridad documental por tema](architecture/system_overview.md#autoridad-documental-por-tema) identifica los contratos vigentes y sus fuentes de aprobación.

## Lectura inicial

Para conocer el alcance del trabajo y entender el sistema, se recomienda la siguiente secuencia:

1. [Consigna](consigna.md): objetivo docente, funciones obligatorias y condiciones de entrega.
2. [Requisitos](requirements.md): obligaciones identificadas, origen y criterios de aceptación.
3. [Diseño FPGA consolidado](architecture/system_overview.md): funcionamiento general, subsistemas y fuentes de detalle del diseño actual.

Después de esa lectura, los documentos de consulta permiten profundizar en un tema y los recorridos por tarea relacionan las fuentes necesarias para trabajar sobre él.

## Documentos de consulta

| Consulta | Documento | Propósito |
|---|---|---|
| Alcance docente | [Consigna](consigna.md) | Define el trabajo práctico y sus obligaciones originales. |
| Obligaciones y aceptación | [Requisitos](requirements.md) | Relaciona cada requisito con su fuente, aceptación y decisión de origen. |
| Arquitectura del sistema | [Diseño FPGA consolidado](architecture/system_overview.md) | Presenta el funcionamiento e identifica los contratos especializados de etapas, control, memoria, sesión, UART, Debug y plataforma. |
| Bloques y agrupación RTL | [Inventario de módulos](architecture/module_inventory.md) | Relaciona los bloques funcionales con módulos, archivos y ubicación en la jerarquía. |
| Integración del sistema | [Composición del sistema](architecture/system_composition.md) | Define la topología, los puertos de los tops y los aliases de integración. |
| Conexiones entre bloques | [Interfaces](interfaces.md) | Fija entradas, salidas, anchos, productores, consumidores y temporización. |
| Comunicación PC–FPGA | [Protocolo UART](protocol.md) | Define mensajes, bytes, códigos, secuencias, plazos y recuperación. |
| Propiedades compartidas | [Invariantes arquitectónicas](architecture/architectural_invariants.md) | Reúne las propiedades que deben conservarse entre los contratos del sistema. |
| Diseño de las pruebas | [Plan de verificación de hardware](verification/verification_plan.md) | Define convenciones, niveles, evidencia requerida y reglas de comparación; enlaza los catálogos por área. |
| Trazabilidad de la verificación | [Matriz de cobertura](verification/coverage.md) | Relaciona requisitos, bloques e invariantes con sus contratos y comprobaciones. |
| Variantes de prueba | [Manifiesto de casos](verification/cases.json) | Enumera las variantes de la batería definida; los catálogos desarrollan sus estímulos y expectativas. |

La selección del contrato técnico correspondiente se realiza mediante el [mapa de autoridad por tema](architecture/system_overview.md#autoridad-documental-por-tema). Los documentos de arquitectura desarrollan el comportamiento interno, Interfaces fija las conexiones y Protocolo define la representación y los intercambios externos.

## Recorridos por tarea

### Implementación de un módulo

Consulte el [Inventario](architecture/module_inventory.md) para ubicar el bloque y su agrupación. Lea su contrato especializado en el [mapa de autoridad](architecture/system_overview.md#autoridad-documental-por-tema), sus conexiones en [Interfaces](interfaces.md) y su integración en [Composición](architecture/system_composition.md). La [matriz de cobertura](verification/coverage.md) permite localizar las pruebas correspondientes y las [invariantes](architecture/architectural_invariants.md) fijan las propiedades compartidas que debe conservar.

Las [decisiones pendientes](decisions/pending_decisions.md) identifican las elecciones de diseño todavía abiertas. El [plan de desarrollo](plan.md) establece las condiciones de cierre previas a la implementación.

### Consulta del protocolo

Comience por [Protocolo UART](protocol.md) para conocer solicitudes, respuestas, representación de los datos y recuperación. Consulte [Control de ejecución y sesión](architecture/session/execution_control.md) para la semántica de ejecución, [Arquitectura de Debug](architecture/debug/debug_architecture.md) para el significado y la coherencia de la observación, y [Serializador de respuestas](architecture/debug/response_serializer.md) para la producción de bytes. [UART y Debug](verification/uart_debug.md) reúne las pruebas de esa interacción.

### Verificación de un requisito

Localice el identificador en [Requisitos](requirements.md) y consulte su contrato vigente. Busque el mismo identificador en la [matriz de cobertura](verification/coverage.md) para llegar a la especificación de prueba del catálogo correspondiente. El [plan de verificación](verification/verification_plan.md) fija las convenciones y los criterios comunes de comparación; el [manifiesto](verification/cases.json) enumera las variantes que deben ejecutarse.

## Estado y planificación del proyecto

| Documento | Propósito |
|---|---|
| [Decisiones pendientes](decisions/pending_decisions.md) | Registra las decisiones de diseño todavía abiertas, sus dependencias y condiciones de cierre. |
| [Plan de desarrollo](plan.md) | Organiza fases, actividades, entregables, hitos y condiciones de salida. |

El plan establece las condiciones para pasar del diseño a la implementación. Las especificaciones de prueba describen comprobaciones previstas; sus resultados se acreditan mediante la ejecución y la evidencia requerida por el plan de verificación.

## Decisiones y antecedentes

[Decisiones aprobadas](decisions/decisions.md) conserva las elecciones de diseño, sus justificaciones, consecuencias y revisiones, incluidas las decisiones reemplazadas que se mantienen por trazabilidad. Se consulta para conocer el origen de un contrato o la evolución de una aprobación. El diseño actual se consulta en los contratos vigentes identificados por el [mapa de autoridad documental](architecture/system_overview.md#autoridad-documental-por-tema).
