# Margen del editor, pestañas y controles compactos — 3 de noviembre de 2026

Se atienden las siete observaciones visuales de esta ronda.

| Observación | Cambio |
|---|---|
| Resaltado del pipeline incompleto | Las decoraciones de Monaco cubren también todo el margen: números, puntos y destinos de breakpoint. La selección de una aparición recibe el mismo tratamiento. |
| Aviso de breakpoint | Indicador compacto con icono de pausa circular, nombre, número de línea monoespaciado y flecha hacia el registro interetapa. Conserva todos los hits recibidos y sus etiquetas accesibles. |
| Maximizar grupo | Icono `Scan` de Lucide con curvas en las cuatro esquinas, 15 px y trazo de 1,6 px. Restaurar usa el icono de dos cuadrados redondeados de la misma familia. |
| Pestañas integradas con el panel | Las seleccionadas de todos los grupos comparten el fondo del panel y tienen curvas de 8 px en la base. No se dibuja una línea entre barra y contenido. Los adornos no capturan eventos. |
| Ciclo observado | Reloj junto al número; tooltip «Ciclo de reloj observado» y nombre accesible con el valor. |
| Pausado repetido | Se retira la etiqueta de estado del encabezado del resultado; la barra de acciones conserva el estado de ejecución. Los avisos de comunicación, fallos y resultados terminales permanecen. |
| Modo seleccionado | Se conserva el fondo morado y el icono acentuado, sin el contorno oscuro fino. El foco de teclado conserva su indicación. |

Las decoraciones usan la API pública `marginClassName` de Monaco. Los iconos usan la extensión pública `icons` de FlexLayout. No se cambian métodos internos de las bibliotecas, comandos del procesador ni condiciones de breakpoint.

La primera ejecución de pruebas detectó que el apilado de una pestaña seleccionada podía interceptar el menú Editar. Se corrigió conteniendo las capas en el contexto del layout (`isolation: isolate`); no se elevaron arbitrariamente los menús. La corrección permite mantener las curvas encima de las pestañas vecinas y los menús por encima del área de trabajo.

## Verificación

La comprobación final y sus registros se conservan en `software/build/debug-visual-review-2026-11-03-r6/`.

- `npm run check`: correcto en una ejecución completa, con formato, compilación, 38/38 pruebas unitarias y 22/22 comprobaciones de GUI. `git diff --check`: correcto.
- Se amplían las pruebas existentes de IDE y seguimiento: el número de ciclo sigue siendo accesible, el encabezado no repite «Pausado», el resaltado tiene el ancho total del margen y también cubre el margen de la aparición seguida.
- Revisión del navegador integrado a 1405×699: captura literal del ciclo 3 con breakpoint en `EX/MEM`, margen completo, curvas, reloj y ausencia del borde del modo. Maximizar/restaurar funcionan y el menú Editar recibe eventos por encima de las pestañas. Se conserva el borrador modificado del usuario.
- Documentación actualizada en `tp3/docs/software/viewrv/gui_y_visor.md`.

La demo continúa en `http://127.0.0.1:5175/` con capturas predefinidas. No se amplía su capacidad de ejecutar programas arbitrarios ni se valida hardware físico o Windows en esta ronda.
