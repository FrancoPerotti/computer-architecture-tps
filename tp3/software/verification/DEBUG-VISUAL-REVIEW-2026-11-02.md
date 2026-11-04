# Revisión visual de depuración — 2 de noviembre de 2026

Implementación de los cuatro comentarios sobre el estado del procesador en la demo local sin FPGA.

| Comentario | Resultado |
| --- | --- |
| Banco de registros | Cerrado por defecto, también al consultar una captura final o tras perder el core. Si el usuario lo abre, conserva esa apertura al avanzar ciclos. |
| Guía educativa | Título y objetivo destacados; bloques separados para expectativas de diseño y captura recibida; tablas con columnas para registro, PC, aparición o validez según el origen de la información. |
| Actividad inferida | Una sección por etapa, con estado de actividad y lista agrupada de módulos. Conserva la aclaración de que la participación es inferida y no una medición de señales combinacionales. |
| Estado global | Primera sección después del encabezado de ciclo y PC, abierta por defecto. Conserva los campos recibidos, formatos y aclaraciones de vigencia de fault. |

## Verificación

- `npm run build`: TypeScript y compilación correctos.
- `npm test`: 33 pruebas aprobadas.
- `tests/examples-smoke.cjs`: banco de 59 ejemplos, filtros, guía original/editada y separación de expectativas y capturas en los siete ciclos de la referencia de suma.
- `tests/debug-review-smoke.cjs`: orden del estado global, apertura inicial del banco en vistas activa/final/desconectada, conservación de apertura manual, jerarquía de la guía, tablas separadas y cinco secciones de actividad. Comprueba que no exista una captura inicial inventada. La desconexión se provoca únicamente sobre el core temporal de la prueba.
- Navegador integrado a 1528×771: guía y actividad inspeccionadas visualmente en el ciclo 4; banco cerrado; estado global primero; sin errores de consola observados.
- `git diff --check`: correcto.

Capturas en `software/build/debug-review-*.png`, incluidas `debug-review-browser-guide.png` y `debug-review-browser-activity.png`. Las pruebas utilizan Electron/core y la traza UART literal del ejemplo de suma; no constituyen aceptación física de la FPGA ni verificación de un paquete de distribución.

## Disponibilidad de la demo

`npm run preview:debug:background` compila e inicia el servidor local fuera del grupo de procesos del terminal. Reutiliza la demo si ya está activa y registra PID y log en `software/build`. No instala servicios ni configura arranque automático. La demo se identifica como **Demo visual · sin FPGA** y permite revisar controles y capturas predefinidas, sin ejecutar programas arbitrarios. El procedimiento está documentado en `software/README.md`.
