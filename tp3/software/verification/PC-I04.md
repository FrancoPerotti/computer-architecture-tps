# Evidencia local de PC-I04: preparación de Basys 3

Fecha: 30 de octubre de 2026. Rama `feature/tp3-14-aplicacion-pc`; base `f0c05f6d938bc9fb44ee3ead31db143d4ca9dda8`. Diseño de #12 incorporado: `d488a82196e897d46905412a77f75512c9d4ac2e`. Cambios locales, sin commit ni publicación.

**Estado: implementación local verificada; PC-I04 no está aceptada ni terminada según el plan.** El usuario autorizó dejar pendientes las comprobaciones físicas y Windows y confirmó que todavía no existe bitstream aprobado. El [plan de implementación](../../docs/implementation_plan.md) exige programación y comunicación reales para dar PC-I04 por terminada. Los ensayos siguientes no sustituyen esa evidencia. PC-I05 depende de PC-I02 y PC-I03 y puede desarrollarse conservando estos pendientes; no se empezó PC-I05 en esta entrega.

## Implementación

| Pieza | Comportamiento |
|-------|----------------|
| `core/preparation.py` | Reserva de placa durante selección, programación y comprobación UART. Valida recursos antes de cerrar el enlace anterior. Cierra UART antes de programar SRAM; invalida la identidad de instrucciones al comenzar el intento. Abre UART únicamente después de programación confirmada. |
| `adapters/programmer.py` | Inventario y hashes del programador, perfil/procedencia/hash de bitstream, argumentos sin shell, entorno de bibliotecas exclusivo del hijo, captura acotada y supervisión con plazo de programación de 120 s; terminación y kill/reap si no termina en los 5 s de gracia. |
| `adapters/usb.py`, `core/board_selection.py` | Metadatos USB/serie privados; respuestas públicas limitadas a id y description. Número de serie único preferido; sin serie inequívoca se exige selección explícita de bus/dispositivo. Asociación por metadatos compartidos; contradicciones rechazadas. Sin asociación demostrable se requieren ambas selecciones explícitas. |
| Aplicación y cierre | Un único trabajo controla la placa. Otro trabajo no puede preparar, conectar ni desconectar. Una reserva temporal no se libera al cancelar el waiter HTTP. Desconectar durante programación espera su finalización y omite UART. El cierre resuelve la conexión propia antes de conservar fuentes y finalizar; cerrar un observador conserva el controlador CLI. |
| HTTP y CLI | `board devices`, `ports`, `prepare`, `connect` y `disconnect` utilizan la misma lógica. Las consultas no registran trabajos. Las acciones crean/reutilizan un trabajo CLI persistente. Códigos de selección conservan candidatos; los errores de preparación conservan fase y confirmaciones separadas de programación y RESET. |
| GUI | Panel Conexión con selección, preparación, conexión, desconexión, propiedad de otro trabajo, confirmaciones por fase y guía offline. La edición/autoguardado siguen funcionando durante programación. La composición visual definitiva continúa en PC-I06/PC-I07. |
| Recursos y construcción | Fuente de openFPGALoader, herramientas y dependencias fijadas; programador Linux construido para la base Ubuntu 24.04. Importador de bitstream externo con SHA-256 registrado, revisión RTL completa y descriptor de perfil. Los ejecutables y recursos se conservan fuera de ASAR. |
| Barrera de distribución | La construcción limpia inventarios anteriores y exige programador/bitstream válidos antes de crear `stage-release.json`. Electron rechaza inventario viejo, plataforma distinta, bitstream ausente o hashes alterados. `--native-only` construye CLI/core para verificación, sin inventario ni paquete. |

Una programación confirmada seguida de UART fallida devuelve `BOARD_PREPARATION_FAILED`, `phase=connection`, `programming_status=confirmed`; conectar después no repite el bitstream. Un fallo del programador conserva `programming_status=unconfirmed`. Un recurso inválido conserva `not_attempted`. La confirmación UART acepta READY/BUSY y no prueba identidad de firmware. El puerto solo se recuerda después de comprobarlo; un fallo de preferencias informa una limitación sin deshacer el enlace confirmado. Reconectar conserva el contexto y el intento de RESET; una instancia nueva exige preparación explícita.

## Entorno y procedencia

| Campo | Valor |
|-------|-------|
| Host | Arch Linux x86_64; ventana Electron bajo X11 |
| Python / pySerial | 3.14.9 / 3.5 |
| Node / Electron / TypeScript | 24.22.1 / 45.0.0 / 6.0.3 |
| FastAPI / Uvicorn / HTTPX / Click | 0.162.0 / 0.54.0 / 0.28.1 / 8.5.0 |
| Fuente de openFPGALoader | 1.2.0, revisión `befbab4f646207dbaf1daf8b144dd980ad283dd5` |
| Archivo fuente | `https://codeload.github.com/trabucayre/openFPGALoader/tar.gz/refs/tags/v1.2.0` |
| SHA-256 fuente | `f75e9896bd8c6310f98ecd629ed260ecaa83329c31e0f8f831b07531aa64d30a` |
| SHA-256 ejecutable construido | `06b50ecf5661d960bd61ec69abc1e0a79660b2e997f812fff2312a9df62f4a34` |
| Base de construcción | `ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c` |
| Snapshot de herramientas | Ubuntu `20261018T000000Z`, 76 paquetes/versiones/archivos/SHA-256 en `packaging/programmer-linux.lock.json` |
| Base mínima de ejecución | `ubuntu@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852` |
| Versión del código actual | 0.4.0; no hay distribución de hardware 0.4.0 |

La receta extrae los paquetes de herramientas dentro de `software/build/programmer` y reconstruye la fuente desde el archivo verificado. No instala paquetes ni modifica el rootfs de Docker o del host. Activa FTDI, Xilinx y escaneo USB; enlaza estáticamente los runtimes C++/GCC. Incluye las bibliotecas dinámicas libusb, libftdi, libudev y libcap requeridas, sus avisos, licencia del programador, aviso GCC, fuente y bloqueo de construcción. `resources/programmer/manifest.json` registra hashes, versiones y flags. La validación Windows exige un manifiesto nativo y declaración de dependencias ajenas al sistema estáticas; aún falta construir y comprobar ese binario.

Referencias primarias contrastadas: [fuente oficial del tag](https://github.com/trabucayre/openFPGALoader/tree/v1.2.0), [guía oficial de instalación](https://trabucayre.github.io/openFPGALoader/guide/install.html). Se revisaron el formato de `--scan-usb`, selección USB, placa `basys3`, `--write-sram` y opciones de construcción en la fuente del archivo fijado.

## Comprobaciones ejecutadas

Comandos Python desde `tp3`; comandos npm/ventana desde `software/gui`. Los directorios XDG de cada prueba están aislados. Los fixtures de JTAG/UART están exclusivamente en `software/tests/viewrv`; no existe un modo simulado en producción.

| Comprobación | Procedimiento | Resultado |
|--------------|---------------|-----------|
| Suite Python | `software/.venv/bin/python -m unittest discover -s software/tests/viewrv -t . -v` | 140 pruebas correctas; 112 anteriores y 28 nuevas. |
| Selección, fases y API | `test_preparation` | 27 pruebas: asociación, destinos desaparecidos, errores previos sin efectos, separación de fases, READY/BUSY, propiedad, edición durante espera, preferencias fallidas, cierre durante programación y cancelación del waiter HTTP. |
| CLI y core como procesos | `test_preparation_process` | Un recorrido de enumeración sin crear trabajo, preparación, exclusión, desconexión/reconexión sin programación, UART fallida después de programación confirmada, fallo de programación sin reenvío y cierre completo. |
| Proceso del programador | Casos de `test_preparation.ProgrammerTests` | Argumentos exactos incluso con espacios, entorno propio, hashes/perfil alterados, falta de recursos, fallo de enumeración frente a lista vacía, rechazo de salida excesiva, timeout, kill y reap, cancelación sin hijo abandonado. |
| Cliente y barrera de paquete | `npm test` | 16 pruebas correctas, incluida barrera de recursos/plataforma/inventario/hashes con fixtures temporales externos al producto. |
| GUI | `npm run build` | TypeScript y electron-vite correctos. |
| Ventana real | `node tests/preparation-smoke.cjs` | Selección JTAG/UART, edición y autoguardado mientras programa, reconexión sin repetir programación, fallo UART con programación confirmada, guía local, controlador CLI observado y cierre de GUI sin quitarle la conexión. |
| Programador Linux | `software/packaging/build_programmer_linux.sh` | Fuente/dependencias verificadas; construcción correcta; `openFPGALoader v1.2.0`; escaneo sin Basys 3 accesible devuelve tabla vacía válida. |
| Construcción nativa | `software/packaging/build_linux.sh --native-only` | CLI/core onedir 0.4.0 construidos en Ubuntu 24.04, sin inventario de distribución. |
| Barrera real por bitstream faltante | `software/packaging/build_linux.sh` | Resultado esperado: CLI/core se construyen, luego falla al faltar `resources/hardware/processor.json`/`processor.bit`; no se genera `stage-release.json` ni se empaqueta una distribución parcial. |
| Ejecutables nativos en Arch | `software/.venv/bin/python software/packaging/smoke_preparation_native.py software` | CLI/core nativos independientes, programador/bibliotecas incluidos, enumeración sin placa, arranque con preparación requerida, error al conectar sin preparar y cierre correctos. |
| Ejecutables nativos en Ubuntu mínimo | Mismo verificador con `--network none --read-only --tmpfs /tmp:exec`, fuente/ejecutables montados de solo lectura y Python externo solo para el verificador. | Correcto. El verificador arma una disposición temporal sin `release.json` ni bitstream; es evidencia de ejecutables y dependencias, no de paquete ni FPGA. |
| Calidad | Ruff 0.17.1, formato y reglas E4/E7/E9/F/I | Correcto en aplicación, tests y packaging. |
| Diferencias | `git diff --check` | Correcto. |

Capturas inspeccionadas: `software/build/gui-pc-i04-phases.png` y `gui-pc-i04-owner.png`. Registros: `software/build/evidence/pc-i04/`, excluidos de Git. El ensayo de ventana usa Playwright externo mediante `PLAYWRIGHT_MODULE`. No se abrió ni programó una Basys 3 real.

## Pendientes para cerrar la entrega

1. Incorporar el bitstream real de TP3 con su revisión RTL, perfil REFERENCE y hash registrado mediante el [procedimiento de recursos](../resources/hardware/README.md). El descriptor acredita la procedencia declarada; no demuestra por sí mismo la correspondencia física del circuito.
2. Construir el paquete Linux completo y repetir el recorrido desde ese paquete con Basys 3: permisos, selección de la misma placa en JTAG/UART, programación SRAM, CHECK_READY, casos de error y reenumeración. Registrar dispositivo, bitstream, perfil y versiones. Contribuye a TEST-PC-014 y TEST-PC-025, sin declararlos completos por estos ensayos locales.
3. Construir programador, runtimes Python y NSIS nativos Windows. Verificar dependencias estáticas ajenas al sistema, interfaces/controladores preservando VCP, COM, permisos privados, selección/reenumeración, biblioteca del hijo y todos los recorridos físicos y de cierre. La aceptación Windows permanece pendiente por indicación del usuario.
4. Integrar en #17 el assembler real de #13 y la FPGA, y completar la aceptación de distribución PC-I08. LOAD/RUN/debug/sesiones y la CLI completa pertenecen a PC-I05; esta entrega no genera una sesión de CPU a partir de CHECK_READY.

Los paquetes históricos no se modificaron: 0.1.0 SHA-256 `ae8c50ccc5d6d596177ccafdad546b0abfce9526e032bb75cd7ba417e2135430`, 0.2.0 `e931932e16c3eeee77fbef9f274b2b58ff12bc127a5d6879f18e816bebab04c2`, 0.3.0 `d0b57a8561d93c662ca9bf1cf55fc91f64d3180364fce5c4131ae0ca21c28ae9`. Sus extracciones siguen separadas; el paquete 0.3.0 no incluye estos cambios.

Huella SHA-256 del diff binario local contra la base, excluyendo este informe: `b2268a32ff5d11dcef070c96c651a313c5b430a0b7ab4e3f5230040f2136add2`. Comando desde la raíz: `git diff --binary -- . ':(exclude)tp3/software/verification/PC-I04.md' | sha256sum`. Los informes anteriores conservan sus huellas históricas.
