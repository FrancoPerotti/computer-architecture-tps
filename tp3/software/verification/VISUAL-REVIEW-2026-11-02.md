# Revisión visual — 2 de noviembre de 2026

Implementación de los 27 comentarios del navegador sobre la vista previa de viewrv. Trabajo posterior a PC-I07; versión de desarrollo 0.7.0. La evidencia archivada de PC-I07 conserva su alcance original. Esta revisión verifica el renderer actual desde el código fuente y no certifica un nuevo paquete de distribución.

## Correspondencia con los comentarios

| Comentario | Cambio aplicado |
| --- | --- |
| 1 | Firma `view│rv` a la izquierda, en IBM Plex Mono local con separador índigo, siguiendo el manual de marca. |
| 2 | Eliminado el título duplicado del centro de la barra superior. |
| 3 | Eliminada la línea superior de la barra de estado. |
| 4 | El visor interactivo utiliza toda su superficie; Conexión ya no ocupa un panel lateral. |
| 5 | Los diálogos recortan el contenido dentro del borde redondeado. El desplazamiento ocurre dentro de ellos; scrollbar fina, pista transparente y extremo redondeado. |
| 6 | Un clic en un ejemplo lo abre inmediatamente. Eliminados los radios y el paso adicional de Abrir. Se bloquean clics duplicados mientras se abre; un fallo conserva el diálogo y muestra el error. |
| 7 | Búsqueda con lupa y placeholder «Buscar ejemplo», conservando su nombre accesible. |
| 8 | Selector sin título encima; «Grupo» representa todos los grupos. |
| 9 | Durante una depuración propia, las líneas de instrucciones muestran un círculo tenue en el margen, con indicación al pasar el cursor y tooltip para agregar un breakpoint. |
| 10 | La línea bajo el cursor tiene un fondo sutil, independiente de la posición del cursor de edición y de los colores de ejecución. |
| 11 | Eliminado el estado de recuperación/guardado repetido encima del editor. Se conserva el estado en la barra inferior. |
| 12 | «Acerca del ejemplo» es un icono de información con tooltip y nombre accesible. |
| 13 | La referencia del ejemplo se abre en un panel lateral acoplable. Aparece a la derecha del editor, o a su izquierda si este ya está en el extremo derecho. Conserva las advertencias al modificar el original y la distinción entre lo esperado y lo recibido. |
| 14 | Play y flecha forman un control unido, con extensión estrecha para el desplegable. |
| 15 | Tooltips breves: Ensamblar, Cargar, Correr y Depurar. Cargar sigue nombrando la operación de transferir Assembly a la FPGA. Los motivos de deshabilitación se conservan como descripción accesible. |
| 16 | El checkbox de registrar ensayos queda a la derecha de su descripción, en la misma fila. La interpretación corresponde al control señalado en la captura. |
| 17 | Selector de escala a la derecha, en la misma fila. |
| 18 | Selector de idioma a la derecha, en la misma fila. |
| 19 | Ajustes tiene altura y desplazamiento delimitados; el texto de persistencia termina dentro del contenido y no invade el pie. |
| 20 | Las pestañas de ejemplos conservan su título real. Un punto indica diferencias respecto del original; desaparece al restaurarlo. Los archivos guardados comparan su revisión con la guardada. |
| 21 | Margen exterior a la derecha y debajo de los paneles, compartido por visor e IDE. FlexLayout reparte el espacio interior disponible. |
| 22 | Conexión es un diálogo flotante accesible desde Conectar… o Ver. Cerrar el diálogo conserva selección y progreso, incluso durante la preparación de la placa. |
| 23 | Al cerrar la última pestaña de un grupo se elimina el grupo vacío y el restante se expande. El cierre individual de documentos mantiene su conservación; también se puede crear un programa tras cerrar todas las pestañas. |
| 24 | Catálogo con tarjetas, tipografía y colores del programa, buscador y filtros por familia. Sigue usando las 33 instrucciones reales. |
| 25 | La documentación del autocompletado se expande automáticamente y acompaña la selección por teclado. Los widgets se dibujan fuera del recorte de los paneles, dentro de un contenedor que conserva los estilos de Monaco. Se comprobó LUI completo también en una ventana estrecha. |
| 26 | Un clic en el margen fuera de la depuración propia no abre ningún selector ni aviso. |
| 27 | Eliminada la pestaña exterior «Visor interactivo»; la superficie queda dedicada al visor. |

Referencia de marca: [manual v0.9, página 4](../../docs/software/viewrv/recursos/viewrv_manual_identidad_visual_v0.9.pdf). Firma implementada con tipografía y CSS, sin introducir una imagen de baja resolución.

## Verificación realizada

- `npm run build`: comprobación TypeScript y compilación correctas.
- `npm test`: 33 pruebas aprobadas, ninguna fallida.
- `tests/visual-feedback-smoke.cjs`: revisión del renderer real a 1301×639 y de la documentación LUI a 615×639; firma, márgenes, visor sin pestañas, diálogo flotante, apertura directa, títulos y modificación/restauración, referencia lateral, eliminación de grupos vacíos, creación tras cerrar todas las pestañas, margen inactivo, hover, documentación de autocompletado, catálogo y geometría de Ajustes/pie. Sin errores del renderer.
- `tests/preparation-smoke.cjs`: selección JTAG/UART, preparación mientras se edita con el diálogo cerrado, reapertura con resultado conservado, reconexión sin reprogramar, guía local y propiedad de otro trabajo.
- `tests/ide-smoke.cjs`: ensamblado, carga, depuración sin STEP implícito, pasos y breakpoint seleccionado desde el círculo del margen, formatos independientes, división, edición paralela, reinicio, RUN/RESET y cierre.
- `tests/programs-smoke.cjs`: autoguardado, modelo compartido, archivos, diagnóstico controlado, apertura directa de ejemplos, preferencias, cierre y recuperación en una nueva instancia del core.
- `tests/conservation-smoke.cjs`: fallos de conservación mantienen la ventana y el código; cancelar/reintentar/descartar explícitamente; archivo desaparecido guardado en otro destino.
- `tests/examples-smoke.cjs`: 59 ejemplos, 33 instrucciones individuales, filtros, referencia lateral, modificación/restauración y siete ciclos recibidos del caso literal de suma.
- `tests/diagram-smoke.cjs`: GraphViewer completo, correlación, seguimiento y reapertura, geometría/modelo conservados y sin recursos externos.
- Navegador integrado: vista previa actualizada en `http://127.0.0.1:5174/`, firma, conexión flotante, ajustes y catálogo inspeccionados. Sin errores de consola en la revisión final. Se conservó el mismo perfil y sus borradores.

Las pruebas de hardware anteriores utilizan fixtures explícitos, en perfiles temporales aislados. No equivalen a aceptación en una Basys 3 física. Continúan pendientes el bitstream aprobado y la comprobación Windows ya diferida por el usuario.

## Evidencia local

Capturas actuales en `software/build/visual-review-*.png`: visor, ejemplos, referencia lateral, autocompletado, autocompletado estrecho, catálogo, ajustes y navegador integrado. Resultados y hashes en `software/build/visual-review-2026-11-02/`. Son evidencia de desarrollo local, separada del archivo de PC-I07.
