# Segunda revisión visual — 2 de noviembre de 2026

Cambios sobre los ocho comentarios de la segunda ronda del navegador. Renderer de desarrollo 0.7.0; misma vista previa y mismo perfil de programas.

| Comentario | Resultado |
| --- | --- |
| 1 · Play y desplegable | Grupo más estrecho, fondo transparente y sin recuadro exterior. Una línea vertical corta separa ambos iconos. Conserva el tamaño y el comportamiento de los demás controles. |
| 2 · Hover del editor | El fondo continúa por el margen y el número de línea, que además cambia de color y peso. Se limpia al salir o desplazar el editor. |
| 3 · Conexión | Diálogo con cabecera Basys 3, indicador de estado, resumen en tarjeta, selección JTAG/UART alineada, acción principal índigo, botones secundarios, mensajes de resultado diferenciados y enlace de ayuda. Conserva selección, fases, restricciones de propiedad y preparación en segundo plano. |
| 4 · Descripción del autocompletado | Sin botón de cierre independiente. La descripción permanece expandida al usar Ctrl+Espacio; desaparece junto con las sugerencias. Se corrige el cálculo de tamaño del contenedor con borde que producía un desplazamiento de pocos píxeles. Se conserva scroll cuando realmente sea necesario; las descripciones comprobadas caben completas sin barras. |
| 5 · Lupa | Posición vertical explícita al 50 % del campo, con compensación de media altura. El icono queda centrado incluso dentro del diálogo, cuyo estilo de label antes anulaba el centrado flex. |
| 6 · Borradores | Antes se mostraban todos los programas cerrados. Ahora se excluyen ejemplos cuyo texto coincide con el original, archivos ya guardados y programas nuevos vacíos. Las variantes modificadas conservan su recuperación. La lista se consulta desde **Ver → Borradores recuperables…**, en un diálogo, sin consumir la altura del IDE. También se comprueban los originales de ejemplos cerrados al volver a cargar la interfaz. No se eliminan las copias de conservación para ocultar la lista. |
| 7 · Espacio encima del editor | El icono de información se ubica en la esquina inferior derecha de cada editor. La advertencia de ensamblado anterior es un indicador compacto abajo a la izquierda con el detalle en su tooltip. Los avisos de fallo/protección y los controles de depuración conservan su función. |
| 8 · Vista ensamblada | Columna **Línea** independiente entre PC e Instrucción fuente. El texto de la instrucción ya no concatena el número de línea. |

## Verificación

- Compilación y TypeScript correctos con `npm run build`.
- `npm test`: 33 pruebas aprobadas.
- `tests/visual-round2-smoke.cjs`: renderer Electron y core reales con perfil temporal. Comprueba los ocho cambios: estilo de Run, alineación del hover, aspecto de la conexión, centrado de búsqueda, tres aperturas/cierres de ejemplos intactos sin entradas de recuperación, variante modificada conservada y recuperada después de recargar la interfaz, ubicación de información, geometría estable ante una revisión de ensamblado anterior y cuatro columnas de traducción con los valores reales del ejemplo de suma.
- Documentación LUI comprobada a 1528×771, 1301×639 y 615×639: texto íntegro, sin cierre independiente y sin scroll vertical u horizontal innecesario; Ctrl+Espacio conserva la descripción abierta.
- `tests/preparation-smoke.cjs`: preparación con el diálogo cerrado mientras se edita, selección y resultados conservados, reconexión, fases de fallo, guía local y propiedad de otro trabajo.
- `tests/ide-smoke.cjs`: ensamblado, carga, depuración, breakpoint desde el margen, pasos, ejecución, edición paralela, divisiones y cierre.
- `tests/conservation-smoke.cjs`: cancelación y reintento ante fallos de conservación, descarte explícito y guardado en otra ruta de un archivo desaparecido.
- Inspección del navegador integrado: ejemplos intactos del perfil existente excluidos de la lista; editor sin sección inferior de borradores; nuevo diálogo de conexión visible. Sin errores de consola en la inspección final.
- `git diff --check` correcto.

Pruebas de conexión con fixtures explícitos; sin nueva aceptación física de FPGA ni reconstrucción del paquete de distribución. No se modificó el core de Python.

Capturas locales: `software/build/visual-round2-*.png`. Logs y hashes: `software/build/visual-review-2026-11-02-r2/`. La evidencia de la primera revisión y de PC-I07 mantiene su alcance original.
