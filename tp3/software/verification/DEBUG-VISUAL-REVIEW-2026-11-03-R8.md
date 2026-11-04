# Anclaje del selector de breakpoint — 3 de noviembre de 2026

El selector usaba una posición fija del panel. Ahora se alinea con la flecha de la instrucción y se abre 4 px debajo. El nuevo hook `useBreakpointPosition` comparte las coordenadas públicas de Monaco con la superposición de flechas, evitando un desfase por el orden de actualización de React durante el desplazamiento.

Actualiza la posición al desplazar, redimensionar o cambiar la configuración del editor. Contempla la escala visual, limita ancho/altura al panel y se acomoda arriba si no hay espacio suficiente debajo. Si la instrucción deja de estar visible, cierra el selector. Limpia listeners, observador y frame pendiente al cerrar o desmontar. No cambia la selección de registros ni envía comandos de procesador.

Verificación:

- Compilación y TypeScript correctos; formato comprobado y `git diff --check` correcto.
- 4/4 comprobaciones de GUI aprobadas: `ide-smoke`, `debug-review-smoke`, `breakpoint-visibility-smoke` y `source-follow-smoke`.
- La prueba de IDE verifica alineación horizontal y separación de 4 px tras abrir por teclado y redimensionar el viewport. La de revisión comprueba que el menú sigue a la flecha al hacer scroll. Las demás cubren la limpieza al detener y el acceso con F9/seguimiento.
- Navegador integrado: líneas distintas, scroll con el ancla visible, cierre al salir del viewport y apertura debajo de la flecha de la línea 3. Diferencia horizontal 0 px; separación vertical aproximada 4 px. Sin errores de consola. Se conservan el borrador y los breakpoints del usuario.

Evidencia: `software/build/debug-visual-review-2026-11-03-r8/`. La documentación del selector se actualiza en `tp3/docs/software/viewrv/gui_y_visor.md`. No se repite la validación general de la ronda R7 para este ajuste de posición.
