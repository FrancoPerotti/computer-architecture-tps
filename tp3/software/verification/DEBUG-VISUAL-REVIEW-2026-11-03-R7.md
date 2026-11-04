# Selectores de breakpoint e iconos — 3 de noviembre de 2026

Se atienden las cinco observaciones de esta ronda:

- Los círculos vacíos del margen aparecen únicamente al pasar sobre una instrucción sin breakpoint. Los puntos de breakpoints definidos permanecen visibles y no se sustituyen por el indicador de hover.
- Cada instrucción tiene una flecha minimalista que abre el selector de registro interetapa. Es un botón accesible con nombre, tooltip, estado expandido y activación por teclado; desaparece al salir de depuración.
- Se retira «Pausado» de la barra de acciones. Se conservan los estados transitorios, los errores y la indicación de terminación en inspección.
- El visor usa el icono de diagrama `Workflow` de Lucide; el programa cargado se identifica con `FileCheck2`, su tooltip y el nombre de archivo.
- Los botones de barra lateral, encabezado y acciones comparten una sombra suave al pasar el cursor. No se aplica a botones deshabilitados; el foco de teclado permanece independiente y la transición se omite con movimiento reducido.

## Implementación

`BreakpointActions` usa una superposición pública de Monaco y las posiciones visibles del editor, con actualización al desplazar, redimensionar o cambiar configuración/contenido. Limpia la superposición, suscripciones y frame pendiente al desactivarse o desmontarse. No envía comandos de procesador al abrir o cerrar el selector.

El margen interno de Monaco tiene `aria-hidden`; por eso los botones se sitúan sobre él desde la capa pública de superposiciones, sin modificar atributos internos de Monaco. Las decoraciones reservan carriles separados para el punto y la flecha, manteniendo alineados destinos y números de línea.

La documentación del selector se actualiza en `tp3/docs/software/viewrv/gui_y_visor.md`. Los contratos de breakpoint, persistencia y ejecución no cambian.

## Verificación

Las pruebas existentes de IDE comprueban que el círculo vacío no se dibuja en reposo, que aparece al pasar el cursor y que la flecha abre el selector usando Enter. La prueba de visibilidad comprueba también que no quedan flechas tras Detener. La comprobación de presentación del programa cargado usa su nuevo nombre accesible.

Formato, compilación y 38/38 pruebas unitarias correctos. Las 22 comprobaciones de interfaz quedan aprobadas: 21 en la ejecución general y la de hover al repetirla después de adaptar su condición al final de la transición de color, sin espera fija. La prueba anterior esperaba el color final inmediatamente al entrar el cursor. Los registros de ambas ejecuciones conservan esa distinción. `git diff --check` correcto.

El navegador integrado confirma el selector accesible y su cierre con Escape, la ausencia de círculos vacíos al retirar el cursor y una sombra efectiva al pasar por IDE. No se detectan errores de consola.

Evidencia de esta ronda: `software/build/debug-visual-review-2026-11-03-r7/`. La demo de `http://127.0.0.1:5175/` conserva el borrador modificado y los breakpoints existentes; abrir y cerrar el selector durante la revisión del navegador no agrega ni elimina ninguno.

No se valida hardware físico, Windows ni ejecución arbitraria en la demo.
