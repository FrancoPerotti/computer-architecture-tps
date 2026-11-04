# viewrv: visor educativo y depuración interactiva PC-I07

Esta entrega integra el visor completo con las capturas de sesión, selección compartida, seguimiento explícito e inspector de datos recibidos. Agrega el catálogo conceptual de 33 instrucciones y 165 etapas, y 59 programas con guías educativas. Conserva los flujos de la IDE, menús, tabs y splits conforme a Penpot. Utiliza las sesiones y la CLI de PC-I05, según [DEC-SYS-008](../docs/decisions/DEC-SYS-008.md) y los [contratos canónicos](../docs/software/viewrv/contratos.md). El core escucha exclusivamente en loopback, conserva una exclusión por usuario y publica un descubrimiento privado después de estar disponible. GUI y CLI validan destino, instancia, API y perfil antes de registrar trabajos. La implementación local se comprueba con el assembler real y adaptadores controlados de hardware. Faltan el bitstream aprobado y la aceptación con Basys 3 y Windows; PC-I04 conserva sus pendientes físicos. Estas pruebas no acreditan una ejecución del procesador real.

La CLI ofrece `program assemble <archivo>`, `board status`, `board devices`, `board ports`, `board prepare [--device ID] [--port PUERTO]`, `board connect [--port PUERTO]`, `board disconnect`, `work status`, `work finish`, ayuda y versión. Las consultas no registran trabajos; ensamblar, preparar o conectar crean o reutilizan el trabajo persistente de CLI. `work finish --discard-unsaved` permite resolver explícitamente un fallo de conservación. Las rutas relativas de la CLI se resuelven desde el directorio de la invocación. PC-I05 completa las 25 operaciones del catálogo: añade program load, run start/stop, debug start/step/continue/pause/restart/stop, debug breakpoint add/remove/list y session list/show/steps/logs. Los [contratos canónicos](../docs/software/viewrv/contratos.md#catálogo-consolidado-de-comandos-y-opciones-de-cli) definen sus argumentos. --output human es predeterminado; --output json se coloca antes del grupo. Los códigos de proceso son 0, 1, 2 y 130; ayuda y versión siempre producen texto local sin iniciar el core.

La GUI utiliza `viewrv://app`, el puente nativo restringido y HTTP/SSE. Ofrece crear y abrir programas, copiar ejemplos, editar con Monaco, dividir vistas sobre un modelo compartido, guardar y recuperar borradores. Cada acción conserva la revisión exacta elegida mientras la edición puede continuar. Los diagnósticos se asocian a esa revisión; una respuesta atrasada no reemplaza el texto actual. El visor existente, las fuentes, el catálogo y los workers se cargan localmente. El panel Conexión permite enumerar destinos, preparar, conectar y desconectar, informa confirmaciones por fase y abre una guía local de permisos.

Los menús Archivo, Editar, Ver y Ayuda reúnen las operaciones del documento y de las vistas. La barra común ofrece Ensamblar, Cargar, Correr y Empezar debug; durante depuración cambia a Avanzar, Continuar/Pausar, Reiniciar y Detener. El menú junto a Correr y **Ctrl/Meta+Shift+Enter** ejecutan «Ensamblar, cargar y correr» con la misma revisión. Una edición anterior a LOAD detiene la secuencia; una edición durante LOAD conserva la imagen confirmada para RUN. El foco en una vista informativa deshabilita las acciones de programa, mientras el control de una depuración sigue ligado a su sesión.

Los resultados muestran registros, memoria, latches y estado global recibidos, con formatos independientes y cambios amarillos. El debugger abre sin ejecutar un ciclo; ofrece breakpoints por línea y registro interetapa, conserva la captura terminal para inspección y marca el último estado conocido si se pierde comunicación. Cerrar su tab solo cierra la vista: se puede reabrir desde Ver. La fuente de la sesión permanece protegida y los demás programas se pueden editar. Una sesión controlada por CLI se observa sin apropiarse de su control. El diagrama de sesión de PC-I07 utiliza esa misma captura, muestra la participación inferida y permite seleccionar módulos, conexiones y apariciones o seguir una aparición explícita sin avanzar la CPU.

## Preparación de Basys 3

El core reserva la placa para un trabajo, valida los recursos y la asociación entre JTAG y UART, cierra el enlace anterior, programa SRAM con openFPGALoader 1.2.0 incluido y solo entonces abre/comprueba UART. No sintetiza RTL ni programa flash. Usa el número de serie USB; sin serie inequívoca exige seleccionar explícitamente el identificador de bus/dispositivo. Una selección explícita o recordada desaparecida produce un error con candidatos y no se sustituye silenciosamente.

Un fallo compuesto distingue `phase`, `programming_status` y `reset_status`. Si la programación se confirmó y UART falló, `board connect` reintenta la comunicación sin volver a programar. READY y BUSY comprueban comunicación, sin identificar firmware. El puerto se recuerda solo después de comprobarlo; un fallo al guardar preferencias no deshace el enlace. Reconectar conserva el límite de RESET del transporte. Una instancia nueva exige preparación explícita.

La programación corre en un proceso hijo supervisado, con argumentos separados, salida limitada y plazo de 120 segundos. El entorno de bibliotecas del hijo se prepara sin modificar el del core. Desconectar o cerrar el trabajo durante programación espera su resolución y omite la apertura posterior de UART. Cerrar una GUI observadora conserva el trabajo y conexión de la CLI que controla la placa.

El usuario confirmó que todavía no hay bitstream aprobado. Su ausencia no impide desarrollar ni probar con adaptadores controlados, pero impide producir la distribución de hardware. El [procedimiento de incorporación](resources/hardware/README.md) exige archivo real, revisión RTL y SHA-256 registrado, y genera el descriptor ligado al perfil de recursos. No se agrega un bitstream de prueba al producto. El programador Linux se construye con `software/packaging/build_programmer_linux.sh`, con fuente y dependencias fijadas en `packaging/programmer-linux.lock.json`.

## Sesiones, ejecución y evidencia

LOAD toma fuente, imagen y mapa de una traducción vigente. ACCEPTED invalida el conocimiento anterior; solo DONE publica `loaded_image.status=loaded`. Un rechazo anterior conserva la imagen previa y una confirmación perdida produce `unknown`. Editar durante una LOAD ya iniciada conserva su versión capturada; RUN valida la referencia contra esa imagen. CLI omite la referencia y el core toma la imagen confirmada; GUI debe indicar programa y revisión.

RUN espera una captura terminal completa o una interrupción confirmada; `--limit` es opcional, positivo y finito. Detener desde otra terminal aplica el control del mismo trabajo. Ctrl+C termina únicamente la espera del cliente con código 130: el core mantiene la operación y no la repite.

Debug abre sin ejecutar un ciclo ni fabricar una captura inicial y protege la versión exacta del programa. STEP publica una captura completa; Continuar repite STEP y evalúa breakpoints antes de solicitar otro. Pausar y detener completan el intercambio pendiente. Una captura FINISHED/FAULT conserva su desenlace y la depuración queda abierta para inspección hasta detenerla. Reiniciar requiere LOAD confirmada, crea otra identidad y reinicia la comparación; un rechazo previo conserva la sesión anterior y una carga incierta la cierra. Los breakpoints se conservan para la misma versión y no se trasladan a otra.

Cada trabajo conserva su último ensayo para consultas. `session show`, `steps` y `logs` admiten `--session`; omitirlo en CLI usa el último ensayo de ese trabajo y nunca adopta uno ajeno por defecto. `steps --after N` lee solamente los pasos conservados con índice mayor que N, sin consumo por observador ni ciclos implícitos. El estado vivo publica el último ensayo por trabajo registrado y su última observación, sin mantener un segundo historial completo de capturas en memoria.

Los registros se guardan progresivamente como `$XDG_STATE_HOME/viewrv/records/<session_id>.jsonl` en Linux, o bajo LocalAppData/viewrv/records en Windows. Cada línea tiene schema_version, session_id, record_type y data; las unidades son start, observation y end. Conservan fuente exacta, perfil, autor, fechas UTC con milisegundos, capturas e integridad. El primer fallo detiene las escrituras de ese registro y se informa, mientras continúan la ejecución y la conservación del código. Un cierre con fallo de registro devuelve warnings sin bloquear la salida. La lectura recupera unidades válidas, mantiene índices originales y no restaura CPU ni debug tras una caída.

La GUI recibe las sesiones por HTTP/SSE y respeta la protección de edición, incluso cuando controla CLI. STEP aporta correspondencias de fuente y diferencias entre capturas de la misma sesión. PC-I07 incorpora interpretación funcional y el endpoint de seguimiento de una aparición, con limitaciones explícitas ante datos no justificables. El [informe de verificación](verification/PC-I07.md) conserva el alcance, las muestras de rendimiento y las incidencias. La aceptación integrada en equipos modestos y con FPGA queda identificada para PC-I08. Estas inferencias no sustituyen los datos recibidos ni pausan Continuar.

## Assembler y conservación

El adaptador llama a `software.assembler.assemble(source_text)` según el contrato aprobado. Se incorporaron el módulo real y su catálogo de pruebas de la rama `feature/tp3-13-assembler`, revisión `4d07433aa38eac65394db3357eda35cceae7d445`, sin modificarlos. PyInstaller incluye explícitamente el módulo en el core nativo. Las pruebas comprueban imagen, mapa PC-línea y diagnósticos reales; los dobles de traducción restantes permiten controlar demoras y fallos. Los adaptadores de hardware controlados son exclusivos de tests. #17 completa la integración con FPGA y el paquete distribuible.

El autoguardado se solicita un segundo después del primer cambio pendiente, sin reiniciar el plazo con cada tecla. El trabajador de almacenamiento conserva primero el código y confirma solo la revisión escrita duraderamente. Guardar explícitamente y cerrar esperan la conservación pendiente. Ante un fallo, la GUI permite reintentar, elegir otro destino o cancelar; salir sin conservar requiere la acción explícita del usuario.

En Linux, la recuperación está en `$XDG_DATA_HOME/viewrv/recovery` (por defecto `~/.local/share/viewrv/recovery`) y las preferencias en `$XDG_CONFIG_HOME/viewrv/preferences.json` (por defecto `~/.config/viewrv/preferences.json`). En Windows se usan los directorios de usuario bajo LocalAppData. Cerrar una pestaña conserva un borrador recuperable; cerrar la aplicación conserva las pestañas abiertas para la reapertura. Descartar un borrador no elimina el archivo Assembly asociado. No se restaura una traducción ni un estado físico de FPGA a partir del texto recuperado.

El banco incluye 59 programas editables: una entrada por cada una de las 33 instrucciones, los dos ejemplos iniciales y 24 casos de control, interacción y borde. Se puede buscar y filtrar por grupo. Sus 409 filas de guía por ciclo se vinculan al texto original y al perfil compatible; la depuración muestra la referencia del contador recibido, separada de la captura. Editar conserva la referencia sin predecir la variante. Los bordes de DMEM usan REFERENCE; ALT_1000 excluye esos dos casos. Las expectativas no acreditan ejecución física. Ver el [banco educativo](resources/content/examples/README.md).

## Transporte UART

`viewrv/adapters/serial.py` ejecuta LOAD, RUN, STEP, CHECK_READY y RESET sobre pySerial a 19200 baud, 8N1 y sin control de flujo. `core/protocol.py` define el layout y los presupuestos de los perfiles REFERENCE (IMEM 1024 / DMEM 2048) y ALT_1000 (1000 / 1000). Los tamaños y cantidades conservan sus cinco bytes; `cycle_count` se representa como cadena decimal de 64 bits y los datos de 32 bits como enteros unsigned.

El transporte valida respuestas completas, padding, indicadores, tamaño de lista y direcciones de memoria; conserva los campos de latches inválidos. Un rechazo explícito, una carga aceptada que falla y un resultado no confirmado conservan clasificaciones distintas. Un FAULT recibido completo es un resultado de CPU. El resultado parcial no reemplaza la última captura completa.

`core/serial_service.py` mantiene el buzón de un elemento, una reserva hasta procesar la notificación final, una señal de control por operación y un único hilo serial durante la vida del core. Las notificaciones vuelven al bucle de aplicación. Cancelar una espera HTTP no cancela el intercambio. LOAD y STEP resuelven su fase antes de desconectar; RUN puede recibir RESET y una respuesta terminal ya iniciada se recibe completa. El cierre global solicita la detención antes de esperar las tareas que podrían mantener un RUN sin límite.

La recuperación conserva fase, perfil, N de LOAD e intento de RESET al cerrar y reabrir el puerto. LOAD cancela TX pendiente, espera W_load(N) y repite ventana/consulta hasta recuperar o solicitar cierre; no reenvía la imagen ni inserta RESET. Los demás fallos exigen W_debug de silencio continuo, consulta desde el primer byte y, si corresponde, un único RESET. Un intento sin confirmar bloquea nuevas operaciones y no se renueva al reconectar. El adaptador admite un reintento explícito separado.

El adaptador y el servicio interno sostienen Preparación y Sesiones; todas las acciones de GUI y CLI comparten el mismo servicio serial. Al iniciar el producto, UART está cerrado y falta contexto de preparación: abrirlo no prueba qué bitstream existe. El hook interno PREPARED solo corresponde a una programación confirmada; las pruebas modelan esa confirmación. El recurso `processor_profile.json` sigue fijando el perfil, sin selección pública ni negociación por UART.

## Entorno de desarrollo

El [mapa de módulos de GUI](gui/README.md) describe la separación del editor, los estilos y las fixtures de pruebas. El [índice de evidencia](verification/README.md) reúne las entregas, las revisiones posteriores y los pendientes de aceptación.

Usar CPython **3.14.9**, Node.js **24.22.1** y las versiones fijadas en los archivos de bloqueo. Los siguientes comandos parten de `tp3`; `python3.14` debe resolver ese CPython:

```sh
python3.14 -m venv software/.venv
software/.venv/bin/python -m pip install --require-hashes -r software/requirements-linux.lock
software/.venv/bin/python -m software.viewrv.cli --help
software/.venv/bin/python -m software.viewrv.cli --output json work status
cd software/gui
npm ci --no-audit --no-fund
node node_modules/electron/install.js
npm run build
```

Desde `software/gui`, `node_modules/.bin/electron .` abre la construcción local bajo el protocolo de producto. La CLI puede invocarse desde cualquier directorio con el paquete instalado en el entorno (`python -m pip install --no-deps -e /ruta/absoluta/tp3/software`) o con `tp3` en `PYTHONPATH`.

`npm run dev` utiliza exactamente `http://127.0.0.1:5173`. Solo un core iniciado explícitamente con ese origen de desarrollo lo admite. Antes de cambiar entre renderer de desarrollo y construcción de producto, cerrar los trabajos de la instancia anterior. No se arranca una segunda instancia competidora para eludir su exclusión.

Para revisar la interfaz dentro de un navegador, ejecutar `npm run preview:browser` desde `software/gui` y abrir `http://127.0.0.1:5174`. El helper sirve el mismo renderer construido y sus recursos locales, con un core real y perfil independiente bajo `software/build/browser-preview-*`; conserva allí los borradores. Permite explorar, crear programas, abrir ejemplos, editar y ensamblar. Los diálogos de archivos, portapapeles sujeto a permisos y controles de ventana conservan las limitaciones del navegador; la comprobación completa de esas funciones corresponde a Electron. Para comparar la composición de escritorio, ampliar el panel del navegador: la ventana nativa tiene un mínimo de 900×600. `VIEWRV_PREVIEW_PORT` permite elegir otro puerto local. Ctrl+C conserva el trabajo y detiene la vista previa. El helper no se incluye en la distribución; el modo normal no utiliza fixtures de hardware.

Para revisar la GUI de depuración sin una placa, ejecutar `npm run preview:debug` desde `software/gui` y abrir `http://127.0.0.1:5175`. Este modo explícito utiliza un perfil separado y capturas UART predefinidas del ejemplo **Sumar dos números**. Abre la depuración en el ciclo 4; permite avanzar, continuar, reiniciar, gestionar breakpoints y abrir el diagrama desde Ver. Tras el ciclo 7 se muestra la finalización; **Reiniciar depuración** vuelve al comienzo. La cabecera identifica siempre **Demo visual · sin FPGA**. No se contacta hardware real ni se ejecutan programas Assembly arbitrarios: para cargar de nuevo debe usarse el ejemplo original de suma. La preparación, la carga y los controles pasan por el core real con adaptadores de prueba. Para trabajar con una placa real debe usarse la aplicación de escritorio. Para dejar la demo disponible al cerrar el terminal o continuar la conversación, usar `npm run preview:debug:background`. El lanzador reutiliza una demo ya activa en ese puerto; guarda su PID y log bajo `software/build/browser-debug-demo-5175.{pid,log}`. El proceso puede detenerse enviando SIGTERM al PID guardado. No instala un servicio ni modifica el inicio de sesión.

## Verificación del tramo

Desde `tp3`, ejecutar los comandos canónicos que corresponden al código implementado:

```sh
software/.venv/bin/python -m unittest discover -s software/tests/viewrv -t . -v
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_core
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_api_cli
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_storage
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_protocol
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_interpretation
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_preparation software.tests.viewrv.test_preparation_process
software/.venv/bin/python -m unittest -v software.tests.test_assembler
cd software/gui
npm test
npm run build
```

Para revisar la GUI completa desde `software/gui`, ejecutar `npm run check`: verifica el formato, compila con TypeScript estricto, ejecuta las pruebas unitarias y después los 24 recorridos funcionales y visuales, secuencialmente. `npm test` ejecuta solo las pruebas unitarias; `npm run test:gui` ejecuta los recorridos sobre la construcción existente. Para repetir uno, por ejemplo, usar `npm run test:gui -- graphical-smoke`. Cada ejecución guarda logs por recorrido y un resumen con resultados y duraciones bajo `software/build/gui-check/`. Playwright y Prettier están fijados en `package-lock.json`; `PLAYWRIGHT_MODULE` queda como reemplazo opcional del Playwright local.

El editor de Assembly formatea automáticamente al terminar una línea con **Enter**, pegar código y guardar (incluido **Guardar como…**). Durante la escritura conserva el código parcial y el formateo de Enter se limita a la línea terminada. También incluye **Editar → Formatear documento** y el atajo **Alt+Shift+F** (también **Ctrl+Shift+I** en Linux). Aplica cuatro espacios de sangría a las instrucciones sin etiqueta, normaliza comas y operandos de memoria y conserva etiquetas, comentarios, saltos de línea y mapa PC–línea. No cambia mayúsculas ni corrige instrucciones inválidas; deja intactas las construcciones no soportadas. Es una edición deshacible, compartida entre splits, que no ensambla ni ejecuta el programa y queda deshabilitada durante la depuración de esa fuente. La conservación automática de borradores no dispara formato con cada pulsación.

`npm run format` aplica el formato del código propio de GUI y `npm run format:check` lo comprueba sin editarlo. No se formatea ni modifica el runtime aprobado de GraphViewer. El workflow `viewrv-gui.yml` aplica la comprobación en Linux con Xvfb a los cambios de software y conserva su evidencia. Los ensayos de paquete nativo, rendimiento, Windows y placa física mantienen sus procedimientos separados; este chequeo no los sustituye.

Las pruebas cubren contratos y concurrencia de programas, fallos de archivos y preferencias, almacenamiento duradero, recuperación tras terminar abruptamente el proceso, CLI y HTTP/SSE. Contribuyen parcialmente a TEST-PC-002, 008, 010, 012, 013, 014, 015, 017, 020 y 026; no acreditan los casos completos ni el catálogo TEST-PC-001 a TEST-PC-030. El módulo `test_protocol` agrega bytes literales del catálogo, ambas capacidades, plazos y fallos con reloj controlado, ciclo de vida entre hilos y pseudo-terminales Linux usando pySerial real. Contribuye parcialmente a TEST-PC-003, 007, 016, 023, 024 y 025. La interpretación educativa, las transiciones, el seguimiento y los recursos de PC-I07 tienen pruebas independientes, sin ejecución de CPU simulada en producción.

La prueba de ventana se ejecuta desde `software/gui` con Playwright como herramienta externa de verificación:

```sh
node tests/smoke.cjs
node tests/programs-smoke.cjs
node tests/conservation-smoke.cjs
node tests/preparation-smoke.cjs
node tests/sessions-smoke.cjs
node tests/ide-smoke.cjs
node tests/drawing-smoke.cjs
node tests/diagram-smoke.cjs
node tests/graphical-smoke.cjs
node tests/follow-loop-smoke.cjs
node tests/examples-smoke.cjs
```

Si Playwright no está en los módulos locales, indicar su ruta mediante `PLAYWRIGHT_MODULE`. Las pruebas requieren una sesión gráfica X11 en Linux y aíslan los directorios XDG. Comprueban el visor, edición real, split, ensamblado controlado mientras se edita, diagnóstico, guardado, preferencias, reapertura con otra instancia del core y fallos de cierre con cancelación, reintento y descarte explícito. `sessions-smoke.cjs` usa el assembler real con JTAG/UART controlados, verifica la protección de la fuente depurada, la edición independiente y el cierre de una GUI observadora mientras CLI continúa. No requieren FPGA.

Los recorridos gráficos se ejecutan secuencialmente. `performance-smoke.cjs` mide entradas y cuadros con GPU habilitada, mantiene todas las muestras y marca intervalos mayores a 25 ms para revisión. La grabación se solicita en una ejecución separada con `VIEWRV_PERF_VIDEO=1`; `VIEWRV_PERF_QUICK=1` limita esa ejecución a notebook 1366×768 al 100 %. No ejecutar otros ensayos mientras se mide. El resultado incluye el entorno, trazas Chromium y, al grabar, cuadros JPEG con timestamps y WebM de duración variable. El [informe PC-I07](verification/PC-I07.md) distingue medición puntual, cadencia, grabación e incidencias; un rAF no acredita por sí solo un cambio de cámara ni ejecución FPGA.

Para repetir la comprobación sobre el paquete extraído, indicar `VIEWRV_PRODUCT` con su ruta absoluta. `node tests/sandbox-smoke.cjs` verifica además el arranque directo del producto con el sandbox nativo, sin el argumento `--no-sandbox` que agrega el lanzador de Electron de Playwright.

La [evidencia de PC-I06](verification/PC-I06.md) registra la IDE y los límites de las comprobaciones locales. La [evidencia de PC-I05](verification/PC-I05.md) registra las sesiones y la CLI. La [evidencia de PC-I04](verification/PC-I04.md) conserva el tramo anterior de preparación y sus pendientes. Las evidencias de [PC-I03](verification/PC-I03.md), [PC-I02](verification/PC-I02.md) y [PC-I01](verification/PC-I01.md) conservan las comprobaciones históricas de sus paquetes.

## Construcción Linux y paquete anterior

Con Docker, el entorno Python anterior y los recursos reales de hardware incorporados, desde `tp3`:

```sh
software/packaging/build_programmer_linux.sh
software/packaging/build_linux.sh
cd software/gui
npm run package:linux -- --config.compression=store
```

La ejecución verificada utilizó CPython 3.14.9 convencional de python-build-standalone, instalado mediante `uv`; el script monta esa instalación de desarrollo en `/opt/python`. No debe usarse para introducir bibliotecas de un CPython construido contra una glibc posterior a la base objetivo.

El script construye ambos conjuntos Python onedir en la base Ubuntu 24.04 fijada del TP3, usando el CPython 3.14.9 convencional indicado. También compila el launcher Linux con el GCC y sysroot fijados del programador. Descarga las herramientas de binutils del snapshot Ubuntu de esa imagen y las extrae dentro de `software/build`; no instala paquetes en el equipo ni cambia el rootfs del contenedor. Los bloqueos de dependencias se verifican mediante hashes.

El código actual es 0.7.0. La construcción de distribución exige programador nativo y bitstream válidos: con el bitstream ausente termina con error y no genera `stage-release.json`. El hook de electron-builder también rechaza inventarios viejos, plataformas distintas y recursos alterados. `build_linux.sh --native-only` construye únicamente CLI/core para pruebas locales, sin inventario ni distribución.

Los paquetes anteriores se conservan: 0.3.0 está en `software/gui/dist/viewrv-gui-0.3.0.tar.gz` y `software/build/extracted/viewrv-gui-0.3.0`; las extracciones 0.1.0 y 0.2.0 siguen separadas. Esos paquetes no contienen PC-I04 a PC-I07. El [informe de entornos y avisos](verification/PC-I08-ENVIRONMENTS-LICENSES-2026-11-04.md) conserva la verificación anterior del lock y del paquete. La [matriz de aceptación original](verification/PC-I08-ACCEPTANCE-2026-11-04.md) identifica los 30 casos, 74 requisitos y 16 grupos de variantes en ese punto. El [suplemento de mantenimiento Linux](verification/PC-I08-LINUX-MAINTENANCE-2026-11-04.md) registra la implementación y comprobación posteriores de instalación, actualización y desinstalación. Siguen pendientes los avisos de distribución y la aceptación física/Windows. No hay una distribución final PC-I08 con hardware. La CLI empaquetada conserva su propio runtime y funciona sin Electron, Python o Node del host.

Para comprobar solo los ejecutables nativos 0.7.0 y su programador en un host sin placa, desde `tp3`, ejecutar `software/.venv/bin/python software/packaging/smoke_preparation_native.py software --sessions`. También comprueba el assembler real incluido y las consultas de registros históricos. El verificador arma una disposición temporal, sin `release.json` ni bitstream, y no la presenta como distribución.

Para verificar el host Electron y ASAR actuales con esos runtimes nativos, después de `npm run build`, desde `software/gui`:

```sh
node ../packaging/build_gui_verification.cjs .. --archive
# Verificar el .sha256 junto al archivo generado y extraerlo completo:
cd /directorio/que/contiene/el/archivo
sha256sum -c native-gui-0.7.0-XXXXXX.tar.gz.sha256
tar -xzf native-gui-0.7.0-XXXXXX.tar.gz
cd viewrv-0.7.0-linux-x64-verification
./viewrv-gui
# CLI independiente:
./viewrv --help
```

El constructor imprime JSON con las rutas de la disposición, el archivo comprimido, la raíz de extracción y su SHA-256. Sin `--archive` conserva el comportamiento anterior e imprime solo la disposición nativa. Cada construcción usa un directorio único `software/build/native-gui-<versión>-*`, marcado `VERIFICATION-ONLY.txt`. Incluye `verification-sha256.json` y `verification-manifest.json`, que identifica el commit, el estado de fuentes, las huellas de locks y todos los archivos con tamaño, modo y SHA-256; el manifiesto no se incluye a sí mismo. El campo `licenses` enumera los avisos encontrados, sin acreditar una auditoría completa de licencias. El archivo comprimido conserva permisos y una raíz estable; no se agregan enlaces simbólicos. Incluye los launchers coordinados, los scripts de mantenimiento y sus inventarios Linux. No contiene bitstream ni `release.json` y no sustituye la construcción de hardware.

Desde `software/gui`, con `VIEWRV_PRODUCT` apuntando a la **raíz extraída**, ejecutar:

```sh
VIEWRV_PRODUCT=/ruta/extraída/viewrv-0.7.0-linux-x64-verification node tests/native-ide-smoke.cjs
VIEWRV_PRODUCT=/ruta/extraída/viewrv-0.7.0-linux-x64-verification node tests/sandbox-smoke.cjs
```

El primer ensayo comprueba el core nativo compartido con CLI, assembler real, edición dividida, guardado y recuperación de cambios sin guardar después de reiniciar GUI/core. Recorre además las 33 instrucciones y 165 etapas del visor con recursos locales, conserva grafo/modelo/geometría y abre el banco de 59 ejemplos y su guía. Tras el arranque configura un proxy externo inaccesible y conserva loopback directo durante el recorrido. No equivale a desconectar la red del host. El segundo ensayo prueba por separado el arranque con el sandbox nativo y un renderer sin Node.

Para ejecutar las 25 operaciones con la CLI nativa contra el core de pruebas y el assembler real, desde `tp3`:

```sh
VIEWRV_TEST_NATIVE_CLI="$PWD/software/build/python/viewrv/viewrv" software/.venv/bin/python -m unittest -v software.tests.viewrv.test_api_cli.SessionCliProcessTests
```

El core de este último ensayo utiliza UART/JTAG controlados desde fuentes de tests. El cliente nativo usa su propio runtime; el ensayo no acredita LOAD/RUN físicos ni el recorrido completo del core nativo con placa.

Para comprobar un producto extraído, desde `tp3`:

```sh
software/.venv/bin/python software/packaging/smoke_package.py /ruta/al/producto/extraído
```

## Instalación por usuario Linux

Desde la raíz del paquete extraído, sin `sudo`:

```sh
./install.sh
~/.local/bin/viewrv --help
~/.local/opt/viewrv/viewrv-gui
```

La instalación usa `~/.local/opt/viewrv`, un acceso CLI en `~/.local/bin/viewrv` y una entrada de escritorio en `${XDG_DATA_HOME:-$HOME/.local/share}/applications/viewrv.desktop`. Informa si falta el directorio de CLI en `PATH`; no edita la configuración de la shell. La GUI, CLI, core y ayudante conservan sus runtimes incluidos. El paquete extraído también puede usarse directamente.

Para actualizar, cerrar la GUI, finalizar explícitamente los trabajos CLI con `viewrv work finish` y ejecutar `install.sh` desde el paquete nuevo. Para reinstalar la misma versión o desinstalar, los scripts siguen disponibles en la instalación:

```sh
~/.local/opt/viewrv/install.sh
~/.local/opt/viewrv/uninstall.sh
```

El mantenimiento conserva un bloqueo exclusivo y comprueba el bloqueo real del core y los ejecutables en uso. Rechaza el producto ocupado y las aperturas durante la sustitución; no termina trabajos. Valida inventarios y archivos propios, prepara una copia y revierte los reemplazos ante errores. Si también falla la reversión, conserva el respaldo y muestra su ruta. Los accesos ajenos o modificados no se sobrescriben. La desinstalación conserva Assembly, borradores, registros, preferencias y archivos ajenos; si existen dentro de la instalación, deja su directorio con un manifiesto de datos retenidos. No cambia permisos USB, controladores ni componentes del sistema.

Los launchers requieren las primitivas Linux disponibles en las bases aprobadas (`flock`, `pidfd` y `renameat2`); una sustitución no soportada se rechaza. Las huellas acreditan consistencia del paquete, no autenticidad del editor ni resistencia a un corte eléctrico.

Para comprobar instalación y CLI/core nativos en un `HOME` temporal, desde `tp3`:

```sh
software/.venv/bin/python software/packaging/smoke_linux_installation.py /ruta/al/paquete/extraído
software/.venv/bin/python -m unittest software.tests.viewrv.test_linux_installation -v
```

El recorrido de la GUI instalada y sandbox se repite en el userland Ubuntu preparado según el [informe de entornos](verification/PC-I08-ENVIRONMENTS-LICENSES-2026-11-04.md):

```sh
software/packaging/check_ubuntu_gui.sh software/build/ubuntu-gui-root /ruta/al/paquete/extraído installation
```

## Windows pendiente

El usuario indicó dejar pendiente la comprobación Windows por no disponer actualmente de equipo o VM. `requirements-windows.lock` y `packaging/build_windows.ps1` preparan la construcción nativa con las mismas versiones; también falta construir el programador Windows con dependencias ajenas al sistema estáticas. No acreditan un NSIS construido ni una ejecución Windows.

Cuando haya entorno, crear `software/.venv` con CPython 3.14.9 y ejecutar el script PowerShell. Verificar también permisos privados, exclusión entre procesos, rutas LocalAppData, CLI independiente, SSE, recursos locales, conservación duradera, recuperación, preferencias y cierre en una cuenta Windows de prueba. Las pruebas de pseudo-terminal y procesos Linux no reemplazan esa comprobación. En Windows también deben validarse pySerial real, fragmentación, plazos, recuperación, cierre durante RUN/LOAD/STEP y pérdida/reenumeración del dispositivo. La Basys 3 real y su bitstream identificado se verifican en la integración física de #17.


Para comprobar programas y guías con el assembler real, desde `tp3`:

```sh
software/.venv/bin/python -m software.packaging.validate_examples
software/.venv/bin/python -m unittest software.tests.viewrv.test_examples
```

`examples-smoke.cjs` recorre el banco y la guía original en Electron, verifica la advertencia de edición y usa una traza UART literal exclusiva de pruebas para seguir siete capturas. No envía ciclos adicionales al abrir una guía ni genera una captura inicial. Las guías y sus huellas se incluyen en la preparación local de recursos y en la validación de una distribución completa.


El dibujo y sus IDs se mantienen desde XML y bindings. `npm run build` valida las referencias, adapta los metadatos del visor y refresca las huellas derivadas del perfil. Las explicaciones generales y contextuales se editan en el recurso español. Ver [mantenimiento de recursos](resources/README.md); estas operaciones conservan el SDK y la interpretación del core.
