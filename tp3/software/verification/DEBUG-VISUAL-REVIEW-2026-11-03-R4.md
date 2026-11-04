# Visibilidad de breakpoints al salir de depuración — 3 de noviembre de 2026

Se había definido conservar los breakpoints de la misma versión, sin una regla explícita para su visibilidad en Edición. El editor seguía dibujando las decoraciones de una sesión con `debug_open=false`.

Al detener la depuración ahora se retiran puntos, nombres de destinos, posiciones disponibles y etiquetas de etapa del editor. El margen recupera su ancho normal. Las definiciones se conservan en el core; una nueva depuración de la misma versión las vuelve a mostrar. La selección del inspector de una sesión cerrada tampoco desplaza el editor. Pausar y alcanzar un estado terminal mantienen el debugger abierto y sus marcas visibles hasta Detener.

La regla queda documentada en `tp3/docs/software/viewrv/gui_y_visor.md`, en «Detener la depuración y volver a editar».

Verificación:

- `npm run build`: TypeScript y compilación correctos.
- `tests/breakpoint-visibility-smoke.cjs`: punto y destino visibles durante debug; Stop limpia las decoraciones y restaura el margen; LOAD/debug de la misma versión y Reiniciar conservan el punto sin emitir STEP; editar tras Stop mantiene limpio el margen. Electron y core aislados, una captura UART literal.
- Navegador integrado: modo Edición actualizado, sin puntos ni destinos de breakpoint en el código original. Se conserva la otra pestaña modificada del usuario.
- `git diff --check`: correcto.

Evidencia local: `software/build/breakpoint-visibility-2026-11-03/`. No cambia la persistencia de breakpoints, el protocolo ni el control de ejecución.
