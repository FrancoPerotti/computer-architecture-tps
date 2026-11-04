# Quinta revisión visual de depuración — 3 de noviembre de 2026

| Comentario | Resultado |
| --- | --- |
| 1 · Franja del editor | Se retira la fila permanente de solo lectura, apariciones y breakpoints. La protección del editor y el candado de la barra de estado se conservan. F9 abre los breakpoints y Ctrl+Alt+F9 las apariciones de la línea del cursor; ambas acciones también están en el menú contextual. Los problemas reales de sincronización mantienen su aviso y reintento. |
| 2 · Seguir desde el código | Cada línea con una aparición recibida ofrece un botón de recorrido junto a su etiqueta de etapa. Activa el seguimiento y abre el diagrama. Elegir otra instrucción reemplaza el seguimiento anterior. El botón activo permite detenerlo. Cuando la línea tiene varias apariciones simultáneas, se elige explícitamente el registro interetapa. Se conserva el botón del inspector. Los controles no aparecen antes de la primera captura ni después de perder la conexión. |
| 3 · Selector de componente | Sin etiqueta exterior; «Componente» aparece como opción inicial deshabilitada, hasta seleccionar un componente. El nombre accesible del selector se conserva. |
| 4 · Conexión | Encabezado fijo y contenido desplazable; alineación común, 24 px entre secciones y 16 px dentro de grupos, campos con columna común, acciones agrupadas y una acción primaria. |
| 5 · Ejemplos | Encabezado fijo alineado con búsqueda, cantidad y lista; 24 px entre secciones, 12 px entre cantidad y lista, entradas con 16 px de relleno y 8 px de separación. Se mantiene la apertura directa con un clic. |

## Criterio de diseño

Se aplican los criterios de proximidad, jerarquía y escala coherente de [Carbon: Spacing](https://www.carbondesignsystem.com/building-blocks/foundations/spacing/overview), junto con la separación entre encabezado, contenido y acciones de [Carbon: Modal guidelines](https://www.carbondesignsystem.com/building-blocks/core/components/modal/guidelines). Es una adaptación a los componentes y la identidad de viewrv, sin incorporar la biblioteca Carbon ni afirmar conformidad completa con ella.

## Verificación

- `npm run build`: TypeScript y compilación correctos.
- `npm test`: 33 pruebas aprobadas.
- `tests/source-follow-smoke.cjs`: sin franja permanente ni seguimiento antes de la captura; botón nativo accesible por teclado, separado de la etiqueta de etapa; reemplazo y detención de una única aparición sin STEP adicional; accesos por teclado de apariciones y breakpoints; panel angosto de 900×639; retirada de controles al desconectar; placeholder y alineación de los diálogos.
- `tests/follow-loop-smoke.cjs`: dos apariciones del mismo PC elegidas desde el código, retiro sin reasignación automática ni movimiento de cámara, selección explícita de otra aparición. Seis capturas UART literales, sin STEP adicional.
- Navegador integrado a 1528×771: se conserva la pestaña modificada del usuario y se usa otra copia intacta para la demo. Seguimiento desde la línea 2, reemplazo por la línea 3 y avance hasta ID/EX en ciclo 3. Inspección visual de los diálogos de conexión y ejemplos. Sin errores de consola observados.
- `git diff --check`: correcto.

Evidencia local: `software/build/debug-visual-review-2026-11-03-r3/`. Las pruebas usan Electron/core aislados y capturas predefinidas; no constituyen aceptación de hardware ni reconstrucción del paquete distribuible. El seguimiento conserva la identidad de una aparición y los controles de ejecución existentes.
