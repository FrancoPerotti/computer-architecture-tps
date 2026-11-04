# Documentación de viewrv

- **Tipo:** índice de documentación.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Documentos](#documentos)
- [Autoridad de las definiciones](#autoridad-de-las-definiciones)
- [Condiciones de realización](#condiciones-de-realización)

## Propósito y alcance

La documentación describe viewrv, la aplicación local para aprender, operar y depurar el procesador RISC-V del TP3. La GUI y la CLI comparten un core local. Cada tema tiene una fuente de definición y los otros documentos la referencian.

## Documentos

| Tema | Documento | Contenido |
|------|-----------|-----------|
| Producto | [Requisitos](requisitos.md) | Alcance, usuarios, 74 requisitos y 30 escenarios de aceptación. |
| Estructura | [Arquitectura](arquitectura.md) | Procesos, responsabilidades, componentes, trabajadores y coordinación. |
| Operación | [Contratos y funcionamiento](contratos.md) | Programas, sesiones, CLI, HTTP, JSON, SSE, errores y registros. |
| Presentación | [GUI y visor](gui_y_visor.md) | Interacciones, composición, contenido y correspondencia con el pipeline. |
| Realización | [Integración y distribución](integracion_y_distribucion.md) | Dependencias, recursos, UART, bitstream, archivos e instalación. |
| Comprobación | [Verificación](verificacion.md) | Casos, expectativas, cobertura, entornos y aceptación. |

## Autoridad de las definiciones

[DEC-SYS-008](../../decisions/DEC-SYS-008.md) consolida la solución de la aplicación, su justificación y sus fronteras. Los requisitos definen el producto. Arquitectura describe su estructura y contratos define el comportamiento compartido. GUI y visor define la presentación sin reemplazar la autoridad del core. Integración reúne los detalles de plataforma y entrega; verificación relaciona requisitos y expectativas.

Los contratos de [UART](../../protocol.md), [CPU y Debug](../../architecture/system_overview.md), [memoria](../../architecture/memory/memory_architecture.md) y [assembler](../assembler_interface.md) conservan sus propias definiciones. El diseño del assembler se consulta en [DEC-SYS-009](../../decisions/DEC-SYS-009.md) y sus documentos; no se duplica dentro de viewrv.

## Condiciones de realización

La implementación se organiza mediante las [entregas de viewrv](../../implementation_plan.md#entregas-de-viewrv), con actividades en paralelo según sus dependencias. Los planes orientan el desarrollo y los hitos conjuntos conservan su condición de revisión del sistema completo. La definición documental no acredita software construido ni pruebas ejecutadas. La evidencia de plataforma, acceso a la placa, rendimiento y conservación se obtiene mediante los casos de verificación.
