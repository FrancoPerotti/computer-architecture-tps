# PC-I05: operación compartida del procesador y CLI completa

Fecha de ejecución: 2026-10-30. Fuentes locales sobre `f0c05f6d938bc9fb44ee3ead31db143d4ca9dda8`, rama `feature/tp3-14-aplicacion-pc`, versión 0.5.0. Los cambios permanecen sin commit. Este informe complementa las evidencias históricas PC-I01 a PC-I04.

Se implementaron sesiones compartidas, LOAD/RUN, controles de depuración, las 25 operaciones CLI y registros JSONL. Se incorporó el assembler real de #13 y se comprobó su inclusión en el core nativo. La aceptación con FPGA, el paquete completo y Windows siguen pendientes: no hay bitstream aprobado ni Basys 3 disponible, y el usuario indicó diferir Windows. Los ensayos controlados no demuestran ejecución física de instrucciones.

## Implementación y criterios

| Requisito de la entrega | Implementación y evidencia local |
|---|---|
| Carga de una revisión exacta | `core/programs.py` captura fuente, imagen y mapa vigentes; `core/sessions.py` reserva el control antes de IO. LOAD invalida al recibir ACCEPTED y publica la imagen solo con DONE. Rechazo previo conserva el conocimiento anterior; confirmación perdida produce incertidumbre. No ensambla implícitamente ni reenvía cargas. |
| RUN y control exclusivo | Sesión ligada a la imagen confirmada, límite opcional positivo y finito, captura terminal completa o interrupción por RESET confirmado. Rechazo explícito no crea una sesión ficticia. Las acciones concurrentes se rechazan antes de enviar UART; no se encolan ciclos posteriores. |
| STEP, Continuar/Pausar y breakpoints | Debug abre sin ejecutar ni fabricar una captura inicial. Continuar evalúa todos los breakpoints de la captura antes del siguiente STEP; Pausar/Detener esperan el intercambio pendiente. Coincidencias por PC y latch válidos, resolución por línea desde el mapa real. Estados de drenaje no se confunden con FINISHED/FAULT. |
| Reiniciar y cerrar | Restart recarga la imagen congelada y crea otra identidad solo tras DONE. Rechazo conserva la sesión anterior; incertidumbre la cierra. Desconectar/cerrar resuelve LOAD/STEP/RUN antes de UART y conserva código; cancelar una espera HTTP no cancela una acción admitida. Los breakpoints permanecen para la misma versión. |
| Lógica común GUI/CLI | Ambos clientes acceden a `Sessions` mediante HTTP/SSE y el mismo servicio serial. Un observador consulta capturas sin STEP implícito. La fuente depurada permanece protegida y otros programas pueden editarse. Cerrar GUI observadora conserva el trabajo CLI. |
| CLI completa | 6 operaciones board, 2 program, 2 run, 6 debug, 3 breakpoint, 4 session y 2 work. Ayuda/versión locales; formatos human/json, códigos 0/1/2/130 y trabajo CLI persistente. Ctrl+C termina la espera del cliente; el core conserva la operación. |
| Registros y consultas | `core/evidence.py` escribe start/observation/end mediante el trabajador de archivos, priorizando código. `core/records.py` valida y recupera JSONL sin renumerar ni inventar capturas. Primera escritura fallida detiene el registro, comunica su estado y conserva ejecución/código. Sesiones históricas no restauran CPU ni debug. |
| Correspondencia básica de observaciones | `core/observations.py` conserva ubicaciones por latch válido y diferencias respecto de la captura anterior de la misma sesión, incluidos valores unsigned y contador de 64 bits. La primera observación no inventa valores anteriores. La participación educativa por etapas se declara unavailable; su implementación completa corresponde a PC-I07. |
| Construcción del tramo | CLI/core nativos 0.5.0 construidos en la base Ubuntu fijada, con assembler incluido. Los fixtures de hardware permanecen fuera del producto. `--native-only` no genera inventario ni distribución; el paquete completo sigue exigiendo recursos reales de hardware. |

## Assembler real y procedencia

Se incorporaron exactamente `software/assembler.py` y `software/tests/test_assembler.py` desde la rama local `feature/tp3-13-assembler`, revisión `4d07433aa38eac65394db3357eda35cceae7d445`, sin modificar su contenido ni fusionar los otros cambios de esa rama. El contrato público coincide con los documentos del checkout. SHA-256:

| Archivo | SHA-256 |
|---|---|
| `software/assembler.py` | `191ccad3922e1a3e46519b32b51039d51c48ae491c8d0003c4976eff0762d303` |
| `software/tests/test_assembler.py` | `dbd558a07509fdcb91cb4baa9d7f172c8d00f74ec7c9a6a2d4b00d585cdcb017` |

Su catálogo ejecuta 114 pruebas con bytes/mapas esperados independientes. La integración de sesiones verifica además fuente CRLF con etiquetas, bytes literales de ADDI/BNE/HALT, mapa PC-línea y breakpoint por línea. Un diagnóstico real no transmite LOAD ni reemplaza la imagen confirmada anterior. Los procesos CLI y la ventana de sesiones usan ahora este assembler real con hardware controlado. Los dobles restantes de traducción permiten provocar demoras y fallos específicos.

## Entorno y artefactos

| Campo | Valor |
|---|---|
| Host | Arch Linux x86_64, kernel `7.2.11-arch1-1`, Intel Core Ultra 9 185H, RAM 30 GiB |
| Python / pySerial | 3.14.9 / 3.5 |
| Node / Electron / TypeScript | 24.22.1 / 45.0.0 / 6.0.3 |
| GUI observada | Ventana Electron X11, viewport 1440×1000, zoom predeterminado; prueba funcional, sin aceptación visual completa de PC-I06 |
| Base de construcción | `ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c` |
| Ejecución Ubuntu mínima | `ubuntu@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852`, red deshabilitada, rootfs y producto de solo lectura, `/tmp` ejecutable temporal |
| CLI nativa SHA-256 | `10c16b7d260730b119fa289ddbe86937a6c35e1cfb2d186fb6bb90861761dcd3` |
| Core nativo SHA-256 | `1d39a8f981b26225bda22d2e8bf322f7160e71ef6d428e95513b094ddf5740aa` |
| Programador | openFPGALoader 1.2.0 real, fuente/dependencias y huellas registradas en [PC-I04](PC-I04.md) |
| Hardware | Sin placa accesible; sin bitstream TP3 aprobado. No se programó FPGA ni se midió una ejecución física. |

Los procesos de prueba aíslan runtime, estado, configuración y datos mediante directorios XDG temporales. Las respuestas UART controladas utilizan bytes literales del catálogo TEST-UART-007 y modificaciones explícitas de campos; no constituyen una traza legal de CPU ni implementan un simulador del procesador.

## Reproducción y resultados

| Comprobación ejecutada | Resultado |
|---|---|
| Suite Python completa, incluido assembler | 321 pruebas correctas en 71,727 s: 207 viewrv y 114 assembler. |
| Catálogo independiente del assembler | 114 pruebas correctas; copia exacta de la revisión indicada. |
| CLI nativa en Arch | 3 pruebas de procesos correctas en 36,441 s: las 25 operaciones en ambos formatos, Ctrl+C y recuperación tras caída real del core. |
| CLI nativa en Ubuntu mínimo sin red | Las mismas 3 pruebas correctas en 36,625 s sobre el mismo ejecutable. |
| Core nativo en Arch y Ubuntu mínimo | Inicio/cierre, preparación requerida, programador real, evidencia histórica y traducción/diagnóstico reales correctos en ambos entornos. |
| Construcción nativa | CLI/core 0.5.0 correctos; `Analysis-00.toc` incluye `software.assembler` y no contiene `software.tests`. Sin inventario de distribución. |
| Tests GUI y construcción | 16 tests Node correctos; TypeScript y electron-vite correctos. |
| Ventana real PC-I05 | Recorrido completo del verificador correcto, sin errores de renderer. Capturas de fuente protegida y edición independiente inspeccionadas. |
| Calidad de fuentes | Ruff 0.17.1: formato y reglas E4/E7/E9/F/I correctos; `git diff --check` correcto. |

Comandos desde `tp3`, salvo npm y ventana desde `software/gui`. Los comandos canónicos `test_core`, `test_api_cli`, `test_storage` y `test_interpretation` incluyen los casos nuevos mediante helpers sin prefijo test; no se descubren dos veces. Las descripciones visibles identifican TEST-PC.

```sh
software/.venv/bin/python -m unittest discover -s software/tests -t . -v
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_core
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_api_cli
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_storage
software/.venv/bin/python -m unittest -v software.tests.viewrv.test_interpretation
software/packaging/build_linux.sh --native-only
software/.venv/bin/python software/packaging/smoke_preparation_native.py software --sessions
VIEWRV_TEST_NATIVE_CLI="$PWD/software/build/python/viewrv/viewrv" software/.venv/bin/python -m unittest -v software.tests.viewrv.test_api_cli.SessionCliProcessTests
```

El verificador nativo comprueba CLI/core reales y programador sin dependencias Python/Node del host en esos procesos. Siembra un registro histórico exclusivamente en el estado temporal del usuario: verifica consultas, integridad, FAULT, uint32/uint64, ninguna sesión física restaurada, assembler real incluido y diagnóstico por línea. No agrega un bitstream, assembler simulado ni programador de prueba a los recursos de producción.

El ensayo de las 25 operaciones usa la CLI nativa contra el core de pruebas ejecutado desde fuentes, con assembler real y UART/JTAG controlados. Es una comprobación de cliente y contratos; no acredita el recorrido completo del core nativo LOAD/RUN sobre FPGA. El entorno del cliente elimina PYTHONPATH/PYTHONHOME/LD_LIBRARY_PATH/LD_PRELOAD. Ambos ensayos se repiten sobre los mismos ejecutables en Arch y Ubuntu mínimo.

Para Ubuntu mínimo, desde la raíz del repositorio:

```sh
docker run --rm --network none --read-only --tmpfs /tmp:exec \
  --user "$(id -u):$(id -g)" -e PYTHONDONTWRITEBYTECODE=1 \
  -e PYTHONPATH=/work/tp3:/work/tp3/software/build/ubuntu-venv/lib/python3.14/site-packages \
  -e VIEWRV_TEST_NATIVE_CLI=/work/tp3/software/build/python/viewrv/viewrv \
  -v "$PWD:/work:ro" \
  -v /home/franco/.local/share/uv/python/cpython-3.14.9-linux-x86_64-gnu:/opt/python:ro \
  -w /work/tp3 \
  ubuntu@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852 \
  /opt/python/bin/python3.14 -m unittest -v software.tests.viewrv.test_api_cli.SessionCliProcessTests
```

Cambiar únicamente los argumentos posteriores a `python3.14` por `software/packaging/smoke_preparation_native.py software --sessions` reproduce la comprobación del core nativo. Python externo pertenece al verificador o al core controlado; no se utiliza dentro de los ejecutables nativos.

Desde `software/gui`:

```sh
npm test
npm run build
node tests/sessions-smoke.cjs
```

Se utilizó Playwright externo mediante `PLAYWRIGHT_MODULE`; las capturas y logs están bajo `software/build/evidence/pc-i05`, excluido de Git. La ventana real comprueba HTTP/SSE con la misma fuente/captura, ausencia de tráfico UART al observar, protección del programa depurado, edición/autoguardado de otro programa y cierre de GUI sin detener Continuar de CLI. No acredita los controles completos de ejecución ni los paneles de PC-I06.

## Contribución al catálogo

| IDs | Evidencia local aportada |
|---|---|
| TEST-PC-003, 005, 006, 007 | LOAD exacta, RUN/STEP, estados de drenaje, breakpoints simultáneos, pausa, restart, exclusión, rechazo e incertidumbre. |
| TEST-PC-004 | Ubicaciones por latch y diferencias entre capturas; participación funcional y seguimiento completos pendientes de PC-I07. |
| TEST-PC-008, 009 | Consultas sin ciclos implícitos, contexto/fuente/perfil congelados, opciones de registro/autor y conservación progresiva. |
| TEST-PC-013, 015, 016, 017 | 25 operaciones, human/json, ayuda local, códigos, validación/referencias, límites, Ctrl+C y HTTP cancelado sin repetición. |
| TEST-PC-021, 022 | Escritura fallida sin bloquear CPU/código; caída real del proceso y recuperación con línea intermedia inválida y final truncado, manteniendo índices. |
| TEST-PC-023, 024 | RESET confirmado frente a incertidumbre; cierre durante RUN/STEP/LOAD, incluido desconectar durante lectura de fuente antes de transmitir. |
| TEST-PC-029, 030 | CLI controla/GUI observa en ventana real; HTTP/SSE conservan capturas, no ejecutan STEP al consultar y cerrar observador no termina el controlador. |

Las filas indican contribución; no declaran completos casos que requieren otros niveles, plataformas o la FPGA real.

## Pendientes de aceptación

1. Incorporar el bitstream aprobado mediante el procedimiento de recursos de PC-I04 y disponer de Basys 3 para verificar LOAD/RUN/STEP, breakpoints, terminales y recuperación del procesador real, con assembler/imagen/mapa registrados.
2. Construir la distribución Linux completa y comprobar su flujo integral desde el paquete. Los ejecutables `--native-only` y un registro histórico no prueban este recorrido. No hay paquete 0.5.0 ni aceptación final PC-I08.
3. Construir/verificar programador, CLI/core y NSIS en Windows y repetir las variantes aplicables. La comprobación Windows permanece diferida por indicación del usuario.
4. Completar controles/presentación de la IDE en PC-I06, interpretación educativa en PC-I07 y aceptación conjunta en #17/PC-I08; no se trasladan esos alcances a las pruebas locales de PC-I05.

Los tres paquetes históricos permanecen intactos: 0.1.0 SHA-256 `ae8c50ccc5d6d596177ccafdad546b0abfce9526e032bb75cd7ba417e2135430`, 0.2.0 `e931932e16c3eeee77fbef9f274b2b58ff12bc127a5d6879f18e816bebab04c2`, 0.3.0 `d0b57a8561d93c662ca9bf1cf55fc91f64d3180364fce5c4131ae0ca21c28ae9`. Sus extracciones siguen separadas y no contienen PC-I05.

Huella SHA-256 del diff binario local contra la base, excluyendo este informe: `e28e7e79e280b19ec1760e5d78bd28390122216d58a4817f3b84e8c0dd34347e`. Desde la raíz: `git diff --binary -- . ':(exclude)tp3/software/verification/PC-I05.md' | sha256sum`. Incluye los tramos locales anteriores; sus informes conservan huellas históricas. El directorio de evidencia incluye `sha256.json` con las huellas de logs y capturas.
