# PC-I06: flujos completos de la IDE

Estado al 31 de octubre de 2026: implementación 0.6.0 y verificación local del tramo de IDE. La aceptación física, Windows y la distribución integrada conservan sus pendientes; este informe no los acredita.

## Referencia y comentarios del usuario

Se consultó el archivo Penpot `685eebd9-2ce2-80a4-8008-d6f5fdc5ed3d`, «TP3 · GUI del procesador — exploración visual», mediante el plugin conectado por el usuario el 30 de octubre de 2026. Se inspeccionaron las pantallas de bienvenida, resultados y depuración convencional, además de los comentarios de ambas páginas. Los hilos 1–16, publicados por Franco Perotti el 24 de octubre, se repiten en «Vistas y estados» y «Recorrido navegable». No se modificaron los diseños ni se marcaron comentarios como resueltos.

| Hilo | Indicación recogida | Aplicación |
|---|---|---|
| 1 | Mayor contraste para la sección activa | Fondo violeta y borde distinguible en navegación. |
| 2 | Borde de la tarjeta al hacer hover en bienvenida | Borde visible también al recibir foco de teclado. |
| 3, 14 | Aprovechar el espacio a la izquierda de los controles para indicar el estado | Edición, ejecución, depuración u observación de CLI, junto al progreso. |
| 4 | Autocompletado en minúsculas | Se conserva el catálogo local con mnemónicos/registros en minúsculas. |
| 5 | Identificación/tipo del archivo en la franja inferior | Ruta, tipo Assembly, conservación y estado de carga separados del programa en FPGA. |
| 6, 10 | Sombras de notificaciones y ventanas flotantes | Toasts, menús, selector de breakpoint y diálogos con elevación. |
| 7 | Letras rojas sin subrayado en el error de ensamblado | Decoración inline y explicación debajo de la línea; se desactiva el subrayado visual de Monaco. |
| 8, 9 | X de error roja; check/texto de éxito verdes | Avisos distinguidos por icono, texto y color. |
| 11 | Diferencia suave de panel no enfocado, con tono coherente | Fondo frío apenas diferenciado; se conserva legibilidad. |
| 12 | Evitar confusión con los x1/x2/x3 destacados del resultado | Se presenta el banco completo, identificado como registros arquitectónicos, sin un segundo grupo ambiguo de registros. |
| 13 | Mostrar el selector del registro interetapa del breakpoint | Selector real desde el margen o Breakpoints…, con IF/ID, ID/EX, EX/MEM y MEM/WB y su posición en el recorrido. |
| 15 | Mantener el aprovechamiento del espacio del visor | Se conserva el visor local existente; su adaptación educativa sigue en PC-I07. |
| 16 | Ajustes con opciones visualmente consistentes e iconos | Tarjetas de autor, registro, zoom e idioma con iconos locales Lucide. |

## Implementación actual

- Menús Archivo, Editar, Ver y Ayuda mediante Base UI; controles de ventana limitados y validados en el host Electron.
- Completado real de Monaco en minúsculas, búsqueda y textos internos en español. Copiar/cortar/pegar desde el menú utilizan una operación IPC acotada y validada y esperan la API asíncrona de portapapeles de Electron 45. El modelo conserva deshacer/rehacer. Los diálogos modales gestionan foco y Escape mediante Base UI.
- Acciones contextuales comunes fuera de los splits, con motivos de deshabilitación, y franja inferior independiente del foco para conexión/imagen confirmada.
- Flujo de recepción de revisión, ensamblado, LOAD y RUN; la secuencia combinada se detiene al primer fallo. Una edición anterior a LOAD invalida la secuencia; una edición durante LOAD no sustituye la referencia confirmada usada por RUN. Atajo elegido: Ctrl/Meta+Shift+Enter.
- Pestaña de traducción con fuente, PC y palabra de máquina capturados; también accesible desde Ver después de cerrar la notificación.
- Estado convencional con jerarquía de latches, RF y memoria; primera captura ausente explícita, formatos por valor, cambios amarillos, breakpoints coincidentes y avisos persistentes de incertidumbre.
- Tabs y splits izquierda/derecha o arriba/abajo; controles de debug ligados a la sesión, edición protegida de su programa y edición independiente de los demás.
- Reapertura de archivos en la misma instancia sin conservar accidentalmente el bloqueo de cierre. Tras reiniciar, se selecciona el primer programa recuperado si el grupo está vacío, sin cambiar la selección cuando ya hay una vista abierta. El cierre de documentos pasa por su conservación; se deshabilita el cierre directo del grupo que omitiría ese recorrido.
- RUN cambia a Stop/RESET; apertura automática de resultados terminales. La navegación a otra sección conserva la ejecución.
- El diagrama enlazado desde Ver conserva por ahora un acceso explícito al estado convencional: la adaptación gráfica a capturas de sesión pertenece a PC-I07 y no se presenta como ya implementada.

Los fixtures UART/JTAG son exclusivos de tests. Se conserva el assembler real de #13. No se modificó el core de sesiones ni se simuló un procesador en producción.

En la revisión del 30 de octubre el usuario señaló las esquinas aún cuadradas y las manchas blancas exteriores. Se corrigieron las variables de tema correspondientes a FlexLayout 0.11.1, los radios de las tabs (8 px superiores), los grupos (12 px), el recorte del contenido y el fondo de sus contenedores. La captura `gui-pc-i06-corners.png` muestra las esquinas contra el fondo real, sin relleno blanco exterior; también se inspeccionaron las capturas completas.

## Verificación local

Entorno gráfico: Arch Linux x86_64, kernel 7.2.11-arch1-1, sesión X11; CPython 3.14.9, Node 24.22.1, Electron 45.0.0, Monaco 0.57.0 y FlexLayout 0.11.1, con dependencias fijadas. Se ejecutó la GUI real mediante Playwright externo, con los cuatro directorios XDG aislados. Las pruebas de ventanas se ejecutaron secuencialmente. Se inspeccionaron las capturas, incluidas las esquinas y la variante al 125%.

| Comprobación | Resultado y alcance |
|---|---|
| Regresión Python completa | 321 pruebas: 207 de viewrv y 114 del assembler real; 56,732 s, OK. |
| Pruebas Node | 20, OK: contratos, sincronización del texto, recepción previa a acciones, referencias inmutables del flujo combinado, formatos 32/64 bits y rechazo de inventarios inválidos. |
| TypeScript y electron-vite | Construcción de producción 0.6.0 correcta; workers, fuentes de interfaz y codicons incluidos localmente. |
| `programs-smoke.cjs` | Completado visible, modelo compartido, revisión atrasada, guardar, cerrar/reabrir en el mismo core y en uno nuevo; menú de selección/copia/corte/pegado, búsqueda, deshacer/rehacer; diagnóstico rojo efectivo sin subrayado, ejemplos y preferencias. |
| `ide-smoke.cjs` | Ensamblado real, tabla fuente/PC/palabra, foco, LOAD exacto, debug sin STEP inicial, un ciclo por acción, selector y coincidencia de breakpoint, formatos independientes, splits, edición de otro programa, reinicio sin STEP, RUN/RESET y resultados automáticos. También atajo combinado y edición durante LOAD, pérdida de STEP sin repetición, recarga explícita, continuidad fuera de IDE, FAULT inspeccionable y cierre/reapertura de vista sin ciclos. |
| `conservation-smoke.cjs` | Fallo de escritura mantiene ventana; cancelar conserva edición, reintentar conserva texto, descarte explícito y guardado en otro destino. El trabajo CLI permanece abierto. |
| `preparation-smoke.cjs` | Selección de dispositivo/puerto, edición durante espera, fases, reconexión sin reprogramar, guía local modal y propiedad ajena de CLI. |
| `sessions-smoke.cjs` | CLI controla, GUI observa la misma captura y fuente por HTTP/SSE; protección del programa, edición independiente y cierre del observador mientras continúa CLI. |
| `smoke.cjs` | Arranque, descubrimiento, SSE, visor local, navegación, Monaco y cierre. |
| CLI nativa, Arch y Ubuntu 24.04 | Las tres pruebas de procesos con las 25 operaciones, salida humana/JSON, Ctrl+C y recuperación de registros pasaron en ambos sistemas, contra el core de tests y assembler real. Ubuntu se ejecutó sin red y con raíz de contenedor de solo lectura. |
| Core nativo, Arch y Ubuntu 24.04 | Programador 1.2.0 y dependencias incluidas, enumeración sin placa, preparación requerida, assembler real, consultas históricas de 32/64 bits y cierre. No restaura una sesión física desde un registro. |
| GUI ASAR con runtimes nativos | `native-ide-smoke.cjs`: host empaquetado 0.6.0 inicia su core nativo; CLI nativa comparte la instancia, ensambla realmente, la GUI abre traducción, divide/edita/guarda y cierra sin finalizar el trabajo CLI. El atajo deshabilitado sin placa no envía ensamblado ni LOAD. |
| Sandbox nativo | `sandbox-smoke.cjs`: arranque directo sin `--no-sandbox`, renderer sin Node y cierre normal de GUI/core. |

Los fixtures UART/JTAG de las pruebas de ventana son respuestas controladas, exclusivas de tests; no constituyen una simulación del procesador incorporada al producto. Aunque la fuente se ensambla realmente, los registros que aparecen en esas capturas no acreditan su ejecución física. Los verificadores adaptados mantienen las aserciones de conservación y propiedad; esperan la creación efectiva del documento antes de escribir y usan el nombre accesible del título en los nuevos diálogos.

### Auditoría del alcance PC-I06

| Regla de GUI y contratos | Evidencia |
|---|---|
| Foco, revisión y recepción antes de acciones | `document-sync`, `ide-workflow`, programas e IDE; el resultado anterior no sustituye el texto nuevo, y una vista informativa no elige programa implícitamente. |
| Imagen confirmada y secuencia combinada | Pruebas puras rechazan edición previa a LOAD y fallos intermedios; IDE ejecuta Ctrl+Shift+Enter y contrasta las referencias exactas de LOAD/RUN durante edición posterior. La prueba nativa comprueba el atajo bloqueado sin FPGA. |
| Debug, terminal y protección | IDE/sesiones y regresión core: apertura y reinicio sin ciclo implícito, terminal inspeccionable, no editar fuente protegida ni controlar una sesión ajena; otros documentos siguen editables. |
| Resultados convencionales | RF completo, DMEM sparse, cuatro latches con validez y bits residuales, fetch fault separado, campos globales recibidos y contadores sin truncamiento; formatos por valor y cambios amarillos. La información educativa inferida continúa fuera de este tramo. |
| Esperas, navegación y recuperación | Preparación/IDE/sesiones: navegación y edición durante operaciones, continuidad al ocultar IDE, última captura completa visible, advertencia persistente, recuperación sin repetir STEP y nueva LOAD explícita. |
| Tabs, splits, cierre y reapertura | Programas/IDE/conservación: un modelo por programa, ambas direcciones de split, cerrar una vista de debug conserva la sesión; cerrar la última vista de fuente conserva antes de disponer su modelo; reapertura con edición habilitada. |

Se usaron viewports 1366×768, 1440×1000, 1600×1100 y 1920×1080 a escala 100%, además de 1366×768 al 125%. El cambio de zoom y la navegación no generaron STEP. La medición de escritura conserva las 33 muestras entre keydown y el segundo `requestAnimationFrame`: máximo **31,4 ms** en este host. Es un límite observado de respuesta visible bajo el fixture disponible; no reemplaza TEST-PC-027 en equipos representativos ni mide el rendimiento del diagrama de PC-I07. El registro completo está en `gui-pc-i06-latency.json`.

## Runtimes y trazabilidad

La disposición nativa comprobada es `software/build/native-gui-pc06-F79oUE`. La genera `packaging/build_gui_verification.cjs` con el Electron fijado, el ASAR de la construcción actual, CLI/core 0.6.0 y recursos locales. Se identifica mediante `VERIFICATION-ONLY.txt`, sin `release.json` ni bitstream. El procedimiento está en [README](../README.md). El gate de distribución continúa exigiendo recursos reales; no se añadió un sustituto de hardware al producto.

| Archivo | SHA-256 |
|---|---|
| `viewrv-gui` | `b36c3ce9b423098a7854f4912f730b0654b41ae183818f887b8f1cd0a90725eb` |
| `viewrv` | `29906cd0d495e0755365a344252e7fef47288729a52336be6c4ec39630a44df3` |
| `resources/core/viewrv-core` | `003ecddf3968402b8be13b64d1cddfea9c7ea48525a2010095e52d36831ed788` |
| `resources/app.asar` | `5c603e4ee2b34dbf2a1987d1ef4cb97b28d62db5c01f2233c885e0747ba20408` |

Los logs, capturas, versiones, estado de fuentes y hashes se conservan en el directorio ignorado `software/build/evidence/pc-i06`. Su manifiesto relaciona los archivos de evidencia con la revisión base y el diff local; no se atribuyen los cambios sin commit a HEAD. Se preservan separados los paquetes y extracciones históricos 0.1.0, 0.2.0 y 0.3.0.

## Pendientes de aceptación integrada

La Basys 3 y el bitstream aprobado siguen ausentes. Windows permanece diferido por indicación del usuario. No se produjo un tar.gz 0.6.0 ni un NSIS, ni se declara aprobada la ejecución FPGA, la equivalencia física GUI/CLI o el catálogo completo de 30 casos y 74 requisitos. La GUI nativa se comprobó en Arch; las comprobaciones Ubuntu de este informe corresponden a CLI/core, no a una ventana de Electron.

PC-I07 conserva el circuito adaptado a sesiones, las explicaciones, el banco educativo completo, participación funcional y seguimiento. PC-I08 conserva distribución, instalación y aceptación integrada en los sistemas objetivo. Estos pendientes no se ocultan mediante datos iniciales ni resultados educativos fabricados en la IDE.
