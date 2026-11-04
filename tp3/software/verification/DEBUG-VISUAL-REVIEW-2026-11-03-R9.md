# Formato y padding del selector — 3 de noviembre de 2026

El selector de registro usa una cuadrícula estable: columna de check de 16 px, nombre monoespaciado en una etiqueta de 66 px y descripción. Todas las filas tienen 40 px de altura y padding de 8 px verticales y 10 px horizontales; el contenedor tiene 6 px. La columna del check se reserva también sin selección para evitar desplazamientos al marcar opciones. El estado seleccionado usa un acento suave y el foco de teclado conserva una indicación independiente.

Se separa este estilo del selector de apariciones, manteniendo el anclaje y los controles existentes. No se agregaron ni quitaron breakpoints del usuario durante la revisión.

Verificación: compilación/TypeScript correctos, 2/2 comprobaciones de GUI (`ide-smoke` y `debug-review-smoke`) y `git diff --check` correctos. En el navegador se compararon una línea sin selección y otra con dos registros seleccionados: altura 40 px, padding `8px 10px` y desplazamiento del nombre 36 px en todas las filas. Sin errores de consola.

Evidencia: `software/build/debug-visual-review-2026-11-03-r9/`, con capturas de ambos estados, registros y hashes. La demo queda abierta en el selector sin selección.
