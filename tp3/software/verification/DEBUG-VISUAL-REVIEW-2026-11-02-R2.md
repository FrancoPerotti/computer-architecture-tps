# Segunda revisión visual de depuración — 2 de noviembre de 2026

| Comentario | Cambio |
| --- | --- |
| 1 · Registros interetapa | Tarjetas permanentes con encabezados, sin plegado ni flechas. También permanecen visibles al consultar el estado final. |
| 2 · Instrucción y ubicación | Primero se muestra el Assembly y después `#n`, con menor énfasis visual. El número conserva su nombre accesible y tooltip de línea. |
| 3 · Estado global | Conserva el desplegable y la apertura inicial; utiliza la nueva flecha minimalista. |
| 4 · Aclaración de fault | Se retiró el párrafo bajo el encabezado global. Se conservan los datos recibidos y la presentación de causas durante fault. |
| 5 · Etiquetas del diagrama | El adaptador de sesión aplica los marcos de selección y participación a formas con contorno. Las etiquetas de texto y las formas originalmente sin borde no reciben marcos nuevos. |
| 6–7 · Selector de breakpoint | Cuatro filas compactas con registro, etapa de entrada y marca de selección. Sin título visible ni botón de cerrar. Cierre al elegir, con Escape, al salir con el foco o al pulsar afuera; navegación con flechas, Inicio y Fin. |
| General · Flechas | Los desplegables nativos de la GUI y los controles de expansión usan chevrons de trazo abierto, con rotación al expandir. El visor interactivo ya utiliza sus iconos Chevron. Se mantienen la semántica nativa y el manejo por teclado. |

## Verificación

- `npm run build`: TypeScript y compilación correctos.
- `npm test`: 33 pruebas aprobadas, incluida la integridad del SDK aprobado y de los recursos generados.
- `tests/debug-review-smoke.cjs`: tarjetas permanentes, instrucción antes del número, retiro del párrafo, plegado global, apariencia de chevrons, cuatro opciones de breakpoint, navegación y cierre, alta/baja real mediante el core, banco inicialmente cerrado y guía/actividad de la revisión anterior.
- `tests/diagram-smoke.cjs`: selección, actividad, seguimiento y retiro de apariciones, formatos independientes y conservación del modelo/geometría. Verifica sobre las etiquetas nativas que no reciban marcos índigo o magenta.
- Navegador integrado a 1528×771: inspección visual de tarjetas, selector y diagrama al 20 %, en el ciclo 4 de la demo. Sin errores de consola observados en la revisión final.
- `git diff --check`: correcto.

Evidencia: `software/build/debug-visual-review-2026-11-02-r2/`. Se utilizan perfiles temporales de Electron/core y la traza UART literal; no es aceptación de hardware ni reconstrucción del paquete de distribución. El visor aprobado, el XML del circuito y el SDK permanecen intactos; se modifica su adaptador local de sesión.
