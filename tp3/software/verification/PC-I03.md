# Evidencia de PC-I03: transporte UART y recuperación

Fecha: 30 de octubre de 2026. Rama: `feature/tp3-14-aplicacion-pc`. Base de Git: `f0c05f6`, con los cambios locales de PC-I01, PC-I02 y esta entrega, sin publicar. Diseño de #12 incorporado: `d488a82196e897d46905412a77f75512c9d4ac2e`; se volvió a comprobar la referencia remota durante este trabajo y conserva esa revisión.

El alcance implementado es el adaptador serial, la representación de respuestas completas y su servicio entre hilos, con comprobación controlada de LOAD, RUN, STEP, CHECK_READY y RESET en REFERENCE y ALT_1000. No se utilizó placa real ni se ejecutó Windows. Sus comprobaciones permanecen pendientes, conforme al alcance del goal y a la indicación previa del usuario sobre Windows.

## Entorno, fuentes y artefacto

| Campo | Valor |
|-------|-------|
| Host | Arch Linux x86_64, kernel 7.2.11-arch1-1; sesión X11 para las pruebas gráficas |
| Python / pySerial | CPython 3.14.9 convencional / pySerial 3.5 |
| Node / Electron / React / TypeScript | 24.22.1 / 45.0.0 / 19.3.1 / 6.0.3 |
| FastAPI / Uvicorn / HTTPX / Click | 0.162.0 / 0.54.0 / 0.28.1 / 8.5.0 |
| PyInstaller / electron-builder | 6.22.3 / 26.18.0 |
| Base de construcción Python | Ubuntu 24.04, `ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c` |
| Ubuntu mínimo de ejecución | `ubuntu@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852`, producto de solo lectura y sin red externa |
| Producto Linux | `software/gui/dist/viewrv-gui-0.3.0.tar.gz`, compresión store |
| SHA-256 del tar.gz | d0b57a8561d93c662ca9bf1cf55fc91f64d3180364fce5c4131ae0ca21c28ae9 |
| Extracción comprobada | `software/build/extracted/viewrv-gui-0.3.0`; se conservan por separado las extracciones 0.1.0 y 0.2.0 |
| Protocolo de referencia | `docs/protocol.md`, SHA-256 `b7cb746758d3a4ce209b6ea617d79b52d2d4dc2c29d9e6478fb8d008addad80b` |
| Catálogo de vectores | `docs/verification/cases.json`, SHA-256 `94c2265ad18b2529bcd1594bfa5f9f50ac6de4f66e3be09f76758854e24b11b5` |

Las versiones continúan fijadas en los bloqueos existentes. No se añadió una dependencia. Los fixtures y los emuladores de puerto están exclusivamente en tests y no son modos del producto.

## Implementación verificable

| Pieza | Responsabilidad y evidencia |
|-------|----------------------------|
| `viewrv/core/protocol.py` | Cabecera LOAD de 40 bits, capacidades aprobadas, fórmulas de plazos, cuerpo fijo de 228 bytes, latches y lista de memoria. No ejecuta instrucciones ni accede a dispositivos. |
| `viewrv/adapters/serial.py` | Único propietario del puerto dentro del hilo serial: pySerial 19200/8N1 sin control de flujo, envío/recepción parcial, plazos por fase, control de RUN, conservación de incertidumbre y recuperación. |
| `viewrv/core/serial_service.py` | SerialRequest y SerialNotification mediante diccionarios; buzón `Queue(maxsize=1)`, señal Event nueva por operación y entrega `loop.call_soon_threadsafe`. Conserva reserva hasta procesar el resultado en el hilo de aplicación. |
| Composición del runtime | Construye el adaptador con el perfil ya validado e inicia un único hilo serial con UART cerrado. La lógica de aplicación recibe el puerto inyectado, sin importar pySerial. El cierre espera la terminación del hilo mediante esperas asíncronas. |
| Integración de aplicación | Publica el estado del enlace desde Application thread. El cierre global solicita el control de RUN antes de esperar las tareas que podrían mantenerlo sin límite. HTTP, SSE y conservación siguen disponibles durante la E/S serial. |

El hook interno PREPARED corresponde exclusivamente a una programación confirmada del bitstream. En los fixtures se modela esa confirmación; no se programa una placa. El producto inicia con preparación requerida y no abre UART por sí solo. Los comandos públicos de preparación/conexión y las sesiones con identidad de programa se integran en PC-I04/PC-I05. Esta entrega conserva las interfaces públicas anteriores y no expone una opción para omitir la preparación o cambiar el perfil de memoria.

## Comprobaciones ejecutadas

Los comandos Python parten de `tp3`; los comandos npm y de ventana, de `tp3/software/gui`. El [README](../README.md) contiene la preparación del entorno y las rutas. Las pruebas de ventana usan Playwright externo mediante `PLAYWRIGHT_MODULE` y directorios XDG aislados.

| Comprobación | Procedimiento | Resultado |
|--------------|---------------|-----------|
| Transporte e integración | `software/.venv/bin/python -m unittest -v software.tests.viewrv.test_protocol software.tests.viewrv.test_api_cli.SerialApiTests` | 46 pruebas correctas: 44 en test_protocol y dos de integración con aplicación/HTTP |
| Suite completa Python | `software/.venv/bin/python -m unittest discover -s software/tests/viewrv -t . -v` | 112 pruebas correctas; código 0 |
| Cliente TypeScript | `npm test` | 15 pruebas correctas; código 0 |
| Construcción GUI | `npm run build` | Tipos y electron-vite correctos |
| Calidad Python | Ruff 0.17.1, formato y reglas E4/E7/E9/F/I en viewrv, sus pruebas y packaging | Correcto |
| Regresión del editor y conservación | `node tests/programs-smoke.cjs` y `node tests/conservation-smoke.cjs` | Edición, modelo compartido, ensamblado controlado durante edición, guardado, preferencias, reapertura y resolución de fallos de cierre correctos |
| Construcción nativa | `software/packaging/build_linux.sh` | CLI y core onedir construidos en Ubuntu 24.04 |
| Empaquetado | `npm run package:linux -- --config.compression=store` | Producto 0.3.0 construido y extraído |
| Producto nativo, Arch | `software/.venv/bin/python software/packaging/smoke_package.py software/build/extracted/viewrv-gui-0.3.0` | Inventario, ejecutables, un único hilo serial real, programas, conservación y cierre correctos |
| Producto nativo, Ubuntu mínimo | Mismo verificador, contenedor `--network none --read-only --tmpfs /tmp:exec`, producto montado de solo lectura | Correcto; Python externo ejecuta únicamente el verificador, los procesos CLI/core usan su runtime empaquetado |
| GUI empaquetada | `node tests/smoke.cjs` con `VIEWRV_PRODUCT` | Visor local, Monaco, HTTP/SSE, ausencia de solicitudes externas y cierre conservando trabajo CLI correctos |
| Sandbox de GUI | `node tests/sandbox-smoke.cjs` con `VIEWRV_PRODUCT` | Arranque directo con sandbox nativo, renderer sin Node y cierre correctos |
| Diferencias | `git diff --check` | Correcto |

La comprobación del paquete inspecciona `/proc/<pid>/task/*/comm` durante la vida del core y exige un único hilo `viewrv-serial`. No abre un puerto físico. Las transacciones con pySerial real se comprueban separadamente mediante pseudo-terminal Linux en los tests de transporte. No se modificó RTL ni el catálogo de hardware; la regresión de 2016 comprobaciones registrada en PC-I02 es evidencia histórica, no una nueva ejecución de hardware de este tramo.

## Matriz de evidencia del transporte

| Obligación | Entrada y comprobación autoritativa |
|------------|-----------------------------------|
| Cinco operaciones en ambos perfiles | Secuencia real de pySerial sobre PTY: OPEN/CHECK_READY, nueva consulta previa a LOAD, cabecera de seis bytes, imagen de ocho bytes tras ACCEPTED, DONE, STEP, RUN terminal, RESET y consulta posterior. También se comprueban rechazo y fallo. |
| LOAD y lectura durante emisión | Imagen literal `93 00 50 00 0B 00 00 00`; escrituras parciales de un byte, separación de aceptación y contenido, rechazo anterior sin payload, abortos posteriores con imagen inválida, pérdida de ACCEPTED/DONE con resultado no confirmado. Un aborto durante una imagen de 256 bytes detiene los 192 bytes todavía pendientes. |
| Cinco bytes sin truncamiento | Cabecera literal de N=2^32: `01 00 00 00 00 01`, rechazada sin reservar 4 GiB; límites de 40 bits y used_count=2^32 rechazado antes de leer/asignar una lista imposible. La capacidad de LOAD continúa siendo validada por FPGA. |
| Captura completa y exacta | TEST-UART-007/C001…C007 del catálogo, sin encoder de producción como oráculo. PC=0x12345678, cycle_count="72623859790382856", RF con patrón literal, fault y todos los latches. Invalidar un latch conserva sus datos y la validez independiente de fetch. |
| Representación JSON | Contador máximo unsigned 64 como cadena "18446744073709551615"; 0xFFFFFFFF se conserva como 4294967295. Los cuatro indicadores definidos son booleanos y los controles mantienen sus códigos. |
| Memoria y validación | Cero escrito conservado, dirección ausente no inventada, conteos K=0 y máximos 1000/2048, orden/duplicados y padding rechazados. Una validación fallida no genera snapshot ni se convierte en fault de CPU. |
| Fragmentación y truncamientos | Cada una de las 229 fronteras del vector de 230 bytes, y entrega byte a byte, en ambos perfiles. Prefijos incompletos en cabecera, contexto, RF, latches y cantidad conservan la captura completa anterior. |
| Plazos por fase | Cabeceras 200 ms; fijo 319 ms; listas 206/2805/5534 ms para K=2/1000/2048; aceptación y contenido LOAD separados. Fragmentos no reinician plazos y el costo del decoder no extiende el presupuesto de la lista. Escritura y DONE comparten el plazo de contenido. |
| RUN sin límite implícito | Terminal controlado a los 100 segundos de reloj virtual sin RESET; sondeo acotado a 50 ms. Límite explícito desde ACCEPTED completo, desactivado al primer byte terminal; cabecera iniciada y cuerpo conservan sus propios plazos. |
| Detención de RUN | RESET confirmado produce interrupción sin snapshot inventado. Un terminal que ya inició gana y se recibe completo. Timeout de ACK conserva resultado no confirmado; no se afirma detención ni se repite RESET. |
| Desconexión solicitada | Antes/después de aceptación LOAD, cabecera/cuerpo STEP, RUN ejecutando y terminal ya iniciado, ambos perfiles. LOAD/STEP completan la fase; RUN ejecutando usa RESET; el terminal completo se conserva y el puerto se cierra después. El hilo sigue disponible. |
| Pérdida de enlace | Errores de E/S antes/durante LOAD y aceptación/ejecución/cuerpo RUN; pérdida durante STEP y cierre del extremo PTY real. No se publica el parcial ni se reenvía la operación; fase y N se conservan al cerrar/reabrir. |
| Recuperación LOAD | W_load(32)=300 ms y W_load(1024)=800 ms. Una consulta perdida repite solamente ventana y CHECK_READY, sin RESET ni reenvío de imagen. Se cancela TX pendiente mediante reset_output_buffer; no se deja un cancel_write que afecte a la consulta siguiente. El recorrido también pasa con pySerial real. |
| Recuperación restante | W_debug=6100/3400 ms según perfil, reiniciado por cada byte, incluido uno pendiente justo en el límite. Consulta válida fragmentada desde el primer byte; datos posteriores conservados. No se busca READY dentro de un cuerpo o prefijo inválido. |
| Único RESET automático | Consulta sin bytes pasa a RESET tras 200 ms; consulta con datos inválidos/incompletos exige otro silencio completo. Se marca el intento antes de escribir RESET. Fallo de escritura, truncamiento o pérdida de ACK consume el intento; cerrar/reabrir no lo renueva. Se verifica un reintento explícito separado. |
| Selección de puerto | Prioridad explícito → recordado → único candidato; ausencia/ambigüedad y puerto recordado desaparecido no se sustituyen silenciosamente. Enumeración y selección quedan disponibles para la integración de Preparación. |
| Servicio entre hilos | Una reserva aun con buzón vacío, copia de parámetros, control nuevo por solicitud, notificaciones procesadas en Application thread y un único Serial thread incluso al cerrar/abrir UART. Cancelar el waiter no libera la reserva ni abandona el cierre. |
| Integración y cierre | Con STEP pendiente siguen respondiendo HTTP, edición, SSE y escritura durable; un segundo STEP se rechaza. El cierre global de una tarea RUN sin límite solicita RESET antes de esperarla y termina el hilo. El producto empaquetado conserva trabajos CLI al cerrar GUI. |

Las comprobaciones contribuyen parcialmente a TEST-PC-003, TEST-PC-007, TEST-PC-016, TEST-PC-023, TEST-PC-024 y TEST-PC-025. No dan por completos los casos que incluyen FPGA, sesiones públicas o aceptación en varios sistemas.

El reloj virtual permite contrastar límites, fragmentación y silencios sin introducir esperas de varios segundos en cada variante. Los pseudo-terminales utilizan las llamadas reales de pySerial y del sistema operativo; no reproducen los tiempos físicos de 8N1 ni los errores eléctricos de una UART. Los bytes del catálogo son fixtures de serialización, no prueba de una ejecución legal del CPU.

## Pendientes de placa real y Windows

- PC-I04 debe integrar programador/bitstream, enumeración y selección de la misma Basys 3 y fases públicas de preparación y conexión. PC-I05 debe conectar sesiones, control exclusivo, metadatos de programa/revisión y las operaciones CLI/GUI al servicio. El adaptador no fabrica esas identidades ni una sesión física a partir de CHECK_READY.
- #17 debe comprobar la Basys 3 real con bitstream, perfil y hash identificados: LOAD de la imagen de referencia, terminal x1=5, STEP y drain, límites de RUN y coincidencia con RESET, fragmentación/pérdida real del enlace, reconexión sin renovar intentos, permisos y selección del dispositivo. Debe conservar trazas y resultados físicos; un PTY no acredita FPGA.
- Windows queda pendiente por indicación del usuario. Requiere construcción nativa/NSIS y comprobación de pySerial sobre COM, sus timeouts y escrituras parciales, pérdida y reenumeración USB, cierre durante las fases, recuperación y ciclo de vida del hilo, además de los recorridos de base y conservación ya pendientes. No se ejecutó un NSIS ni se sustituyó esa evidencia por Linux.
- La aplicación inicia sin contexto físico suficiente y exige preparación explícita mediante bitstream. No persiste ni reconstruye una sesión de CPU tras la caída del core. El contexto de recuperación se conserva mientras vive ese core, aunque cierre UART.
- El assembler real sigue en #13 y su integración real en #17; el paquete conserva el error explícito de módulo ausente. No se utiliza un assembler simulado de producción para comprobar UART.

Registros completos: `software/build/evidence/pc-i03/`, excluidos de Git. Capturas de regresión: `software/build/gui-pc-i03.png` y `software/build/gui-pc-i03-base.png`. No se publicaron cambios ni se creó una PR.

Huella SHA-256 del diff binario local contra la base, excluyendo este informe: `50ba02309ffcdc94c4de4d20b1cc4f655f2cb697581d0fefc3cbd415fadd5440`. Comando desde la raíz: `git diff --binary -- . ':(exclude)tp3/software/verification/PC-I03.md' | sha256sum`. Los informes PC-I01 y PC-I02 conservan sus huellas históricas.
