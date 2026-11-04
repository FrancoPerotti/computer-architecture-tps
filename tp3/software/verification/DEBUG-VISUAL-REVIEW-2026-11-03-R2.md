# Cuarta revisión visual de depuración — 3 de noviembre de 2026

| Comentario | Resultado |
| --- | --- |
| 1 · Margen de breakpoint | El ancho se calcula midiendo el texto del destino con su tipografía real y reservando 8 px antes de los dígitos, sujeto al redondeo de Monaco. La comprobación geométrica dio 14,6 px con un destino y 8,6 px con varios. No se truncan destinos ni se superponen al número. |
| 2 · Seguimiento deshabilitado | El tooltip explica la condición concreta: falta de captura, componente que no es un registro interetapa, registro vacío, sesión inactiva o desconectada. Para seguir: recibir una captura, seleccionar IF/ID, ID/EX, EX/MEM o MEM/WB válido y pulsar el icono de recorrido. Después se avanza con los controles habituales. |
| 3 · Pestaña | Sólo nombre del archivo y marca de modificación. Se retiran los sufijos FPGA y otra revisión; el estado de carga sigue en la barra inferior. |
| 4 · Catálogo | Escala de espaciado coherente, alineación de los bloques de lectura, agrupación de búsqueda/filtros, ancho de contenido limitado a 960 px y jerarquía de encabezados. Los parámetros usan una columna fija de nombres y una columna flexible de descripción. Parámetros y ejemplo se apilan en paneles estrechos; las dos columnas aparecen cuando el contenedor supera 760 px. Se conservan búsqueda, filtros y los 33 contenidos. |
| 5 · Archivo modificado | Nombre y punto en ámbar oscuro (`#a15c00`). El punto conserva una señal adicional al color. Al guardar, se restaura el estilo normal. |
| 6 · Inspector compacto | Centrar, seguir y dejar de seguir se presentan como iconos con nombres accesibles y tooltips. El estado fijo, en seguimiento o finalizado también usa icono y tooltip. El botón deshabilitado ofrece su explicación en el botón y en un contenedor enfocable. |

## Criterio de diseño

Se consultó [Carbon Design System: Spacing](https://www.carbondesignsystem.com/building-blocks/foundations/spacing/overview). Se aplicaron sus criterios de escala consistente, proximidad para elementos relacionados y separación para la jerarquía: 8/12 px dentro de grupos, 16 px entre entradas y 24 px entre secciones, con alineaciones comunes. Esta es una adaptación al estilo existente de viewrv; no incorpora otra biblioteca visual.

## Verificación

- `npm run build`: TypeScript y compilación correctos.
- `npm test`: 33 pruebas aprobadas.
- `tests/debug-spacing-smoke.cjs`: margen medido con uno y varios destinos, pestaña sin sufijo, color del archivo modificado y restauración al guardar, iconos y motivos de deshabilitación, seguimiento real IF/ID → ID/EX → EX/MEM → MEM/WB sin STEP extra, catálogo con encabezados semánticos y alineación común, disposición de una y dos columnas, búsqueda y filtro de memoria.
- `tests/follow-loop-smoke.cjs`: dos apariciones simultáneas del mismo PC, seguimiento de una aparición concreta, retiro sin reasignación ni movimiento de cámara y selección explícita de otra aparición. Seis capturas literales, sin STEP extra.
- Navegador integrado a 1528×771: pestaña modificada del usuario conservada, otra copia intacta para la demo, margen compacto, catálogo e iconos inspeccionados. Seguimiento activo de la primera instrucción en EX/MEM, ciclo 3. Sin errores de consola observados.
- `git diff --check`: correcto.

Evidencia local: `software/build/debug-visual-review-2026-11-03-r2/`. Perfiles aislados de Electron/core y capturas UART predefinidas para las pruebas; no implica validación de hardware ni reconstrucción del paquete distribuible. El control de ejecución y la lógica que distingue apariciones conservan sus contratos.
