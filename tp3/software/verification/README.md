# Evidencia de viewrv

Los informes registran lo comprobado en su fecha y con sus versiones. Sus recuentos históricos no se deben interpretar como la cantidad actual de pruebas ni como aceptación de una plataforma posterior.

## Estado de entregas

| Entrega | Evidencia | Situación |
|---|---|---|
| PC-I01 | [Base de producto](PC-I01.md) | Arranque, recursos y paquete inicial. |
| PC-I02 | [Programas y conservación](PC-I02.md) | Edición, archivos y recuperación. |
| PC-I03 | [Transporte](PC-I03.md) | Intercambios UART y recuperación con pruebas controladas. |
| PC-I04 | [Preparación de placa](PC-I04.md) | Implementación local; bitstream aprobado y comprobación física pendientes. |
| PC-I05 | [Sesiones y CLI](PC-I05.md) | Operaciones y coordinación del core y sus clientes. |
| PC-I06 | [IDE](PC-I06.md) | Flujo de edición y depuración convencional. |
| PC-I07 | [Visor y contenido educativo](PC-I07.md) | Implementación local y verificación del tramo. |
| PC-I08 | [Plan de implementación](../../docs/implementation_plan.md#entregas-de-viewrv) | Distribución y aceptación integrada pendientes. |

## Mantenimiento y revisiones posteriores

- [Estabilización del software](SOFTWARE-STABILIZATION-2026-11-03.md): módulos, recursos, formato, Monaco y automatización de pruebas.
- [Última revisión de notificaciones y estados vacíos](DEBUG-VISUAL-REVIEW-2026-11-03-R11.md).
- [Formato del banco de 59 ejemplos](EXAMPLES-FORMAT-2026-11-03.md): equivalencia de bytes y mapas PC–línea, comentarios y guías.
- [Organización previa a PC-I08](SOFTWARE-ORGANIZATION-2026-11-03.md): separación del editor y los estilos, ciclo de vida compartido de pruebas y estado de Git.

Los informes `VISUAL-REVIEW-*` y `DEBUG-VISUAL-REVIEW-*` anteriores conservan las decisiones y evidencias de cada ronda; no se sobrescriben al realizar otra revisión.

## Pendientes de aceptación

Faltan el bitstream aprobado, la programación/comunicación con Basys 3 real, las verificaciones de Windows solicitadas como pendientes y la aceptación integrada de PC-I08. Los paquetes anteriores y los montajes de verificación tienen el alcance indicado en su informe; no constituyen una distribución final actualizada.

La comprobación actual de la GUI se ejecuta con `npm run check` desde `software/gui`. El [mapa de módulos y pruebas](../gui/README.md) describe su organización. El catálogo completo de requisitos y escenarios permanece en la [especificación de verificación](../../docs/software/viewrv/verificacion.md).
