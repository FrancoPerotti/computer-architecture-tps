# Tercera revisión visual de depuración — 3 de noviembre de 2026

| Comentario | Resultado |
| --- | --- |
| 1 · Leyenda de cambios | Se retiró «Δ Cambios en amarillo» de la cabecera del diagrama. Se mantiene el resaltado de los datos modificados. |
| 2–3 · Tamaño de celdas globales | Todas las filas del bloque global tienen la misma altura. Los valores siguen completos, incluso cuando requieren ajuste de línea. |
| 4–5 · Acceso al diagrama | Se retiró «Abrir diagrama» del estado del procesador. El botón de depuración incorpora una extensión con chevron y la opción «Depurar con diagrama interactivo». La acción principal abre la vista convencional; el dropdown abre el diagrama junto al editor. El reinicio conserva la vista elegida. También permanece el acceso desde Ver. |
| 6–7 · Validez | Check verde circular para una instrucción válida; círculo con guion para un registro vacío; X roja circular para el indicador recibido de fallo de fetch. No se presenta una burbuja normal del pipeline como un error. Los iconos tienen nombres accesibles y títulos. |
| 8 · Evidencia | Se retiró la sección técnica de la vista del procesador. La conservación de ensayos sigue respetando la configuración existente. |
| 9 · Destinos de breakpoints | Los registros elegidos aparecen en magenta junto al punto del margen y antes del número de línea. Admite varios destinos, reserva espacio y oculta la repetición en continuaciones visuales de líneas ajustadas. Las posiciones actuales de instrucciones permanecen al lado del Assembly. |
| 10 · Selección y seguimiento | Se retiraron los dos botones de las tarjetas convencionales. La selección de componentes y el seguimiento de apariciones permanecen en el inspector del diagrama. |
| 11–12 · Controles de ventana y navegación | Los tres controles de ventana forman un grupo sin separación entre botones. Los iconos de navegación se centran con grid y padding cero. |
| 13 · Estado del archivo | Iconos con tooltip para Assembly, recuperación confirmada, guardado, autoguardado pendiente, lectura y modificación desde la carga. La barra puede mostrar el documento asociado a la sesión cuando el foco está en su resultado, sin cambiar el foco usado para ejecutar acciones. |
| 14–16 · Nombres | El banco conserva el título educativo y agrega el archivo en tipografía monoespaciada. Las pestañas y la barra inferior muestran el nombre con extensión (`addition.s`), conservando la marca de cambios y las indicaciones de carga. Guardar como propone una sola extensión. Los archivos externos conservan su nombre real. |
| 17 · Conexión | Botones de conectar y desconectar con iconos, nombres accesibles y tooltips breves. |
| 18 · Ajuste de línea | Activado por defecto en Monaco; se adapta al tamaño del panel sin modificar las líneas lógicas ni el código. |

## Verificación

- `npm run build`: TypeScript y compilación correctos.
- `npm test`: 33 pruebas aprobadas.
- `tests/debug-polish-smoke.cjs`: nombres en catálogo, pestañas y barra; nombre sugerido al guardar; iconos y centros geométricos; conexión flotante; inicio y reinicio con diagrama sin STEP implícito; inicio convencional; ajuste en 1000×771; igualdad de altura de las siete celdas; iconos de validez y vacío; ausencia de botones y evidencia retirados; etiquetas persistentes para uno y varios destinos de breakpoint.
- `tests/debug-review-smoke.cjs`: regresión de tarjetas permanentes, banco inicialmente cerrado, estado global, selector de breakpoint, guía educativa y actividad por etapa.
- `tests/examples-smoke.cjs`: 59 ejemplos, 33 instrucciones, filtros, apertura, guía original/editada y siete ciclos recibidos de la referencia literal de suma.
- Expectativas de nombres de archivo e iconos actualizadas en los smoke tests afectados por la nueva presentación. No se declara una nueva ejecución de todos esos procedimientos históricos.
- Navegador integrado a 1528×771: dropdown, nombres en ejemplos, estado global, iconos, etiquetas de breakpoint y barra inferior inspeccionados. Demo pausada en ciclo 4, sin errores de consola observados.
- `git diff --check`: correcto.

Evidencia local: `software/build/debug-visual-review-2026-11-03/`. Las pruebas usan perfiles aislados del core y Electron con capturas UART predefinidas; no validan hardware físico ni un paquete de distribución. No se modifican el ensamblador, el protocolo ni las capturas de referencia.
