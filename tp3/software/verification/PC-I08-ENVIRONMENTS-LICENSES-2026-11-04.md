# PC-I08: entornos, avisos y comprobaciones adicionales

Fecha: 2026-11-04. Este informe amplía la [verificación del primer archivo Linux](PC-I08-LINUX-VERIFICATION-2026-11-04.md) y respalda la [matriz de aceptación](PC-I08-ACCEPTANCE-2026-11-04.md). PC-I08 conserva pendientes de distribución, hardware y aceptación humana.

## Resultados comprobados

| Ámbito | Resultado | Evidencia bajo `software/build/evidence/pc-i08-acceptance-2026-11-04/` |
|---|---|---|
| Regresión viewrv | 250 pruebas pasadas, antes de añadir los ensayos de auditoría/SSE | `python.log` |
| Assembler | 114 pruebas pasadas | `assembler.log` |
| Node | 42 pruebas pasadas tras corregir el lock | `node.log` |
| Inventario de avisos | 2 regresiones pasadas | `audit-tests.log` |
| CLI nativa | 3 ensayos pasados; incluyen 25 operaciones humanas/JSON, Ctrl+C y recuperación de un registro tras caída | `native-cli.log` |
| GUI nativa Ubuntu | Recorrido completo pasado: 33 instrucciones/165 etapas, banco de 59 ejemplos y guía, assembler real, split, guardado/autoguardado y recuperación tras reiniciar GUI/core | `ubuntu-native-ide.log` |
| Sandbox nativo Ubuntu | Arranque directo pasado, renderer sin Node y cierre correcto | `ubuntu-sandbox.log` |
| Backpressure SSE | 1 ensayo pasado del endpoint HTTP/ASGI real, bloqueando `send` hasta saturar solo ese canal | `sse-backpressure.log` |
| Ciclo SSE en GUI | Nuevo recorrido pasado: comentario real, inactividad, reconexión y cierre durante reintento | `stream-lifecycle.log` |

Se conserva la evidencia previa de 23 recorridos de GUI en `software/build/gui-check/2026-11-04T02-38-10-481Z/summary.json`; no se volvió a contar como una corrida actual. El nuevo recorrido `stream-lifecycle-smoke` se incorpora al runner: las ejecuciones completas futuras abarcan 24 recorridos. Las pruebas nuevas no introducen adaptadores ni herramientas de verificación en la aplicación distribuida.

## Ubuntu y aislamiento

Se probó el mismo archivo `native-gui-0.7.0-o2h6pq.tar.gz`, SHA-256 `fbd93a8c27c7d653be7c59e9f9faa48447c375021477c6f82945a254f6abc870`, sin modificar sus ejecutables ni recursos. La raíz de Ubuntu procede de la imagen fijada del TP3:

```text
ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c
```

Ubuntu informa 24.04.5 LTS, con glibc y bibliotecas gráficas propias del snapshot firmado `20261018T000000Z`. `ubuntu-packages.tsv` identifica todas las versiones. `dpkg --configure -a` terminó correctamente y `dpkg --audit` no dejó paquetes pendientes.

La ejecución usa Bubblewrap con namespaces privados de usuario, procesos, red e IPC, raíz Ubuntu de solo lectura, `/tmp` privado y Xvfb 1366×768×24. El producto se monta de solo lectura. La red externa está deshabilitada desde antes de arrancar; loopback permite GUI/CLI/core. Los directorios XDG de los ensayos son temporales. El ejecutable y las dependencias de Playwright/Node pertenecen al verificador externo; la aplicación usa sus runtimes empaquetados. La prueba separada de sandbox no agrega `--no-sandbox`.

El host tiene Intel Core Ultra 9 185H y 22 CPUs lógicas; `environment.json` registra kernel, RAM, almacenamiento y display. Sigue siendo el kernel de Arch, no una VM ni un equipo arrancado con Ubuntu. Xvfb no acredita GPU/compositor, controladores USB, permisos físicos ni rendimiento de 60 FPS. Este equipo tampoco se presenta como equipo estudiantil modesto.

Se inspeccionaron las capturas `software/build/pc-i08-ubuntu-native-conceptual.png` y `software/build/pc-i08-ubuntu-native-recovered.png`. No se observó un cambio de composición que requiriera alterar la GUI.

### Repetir en un equipo con espacio para Docker

Desde `tp3/software`, la imagen de prueba instala bibliotecas únicamente dentro de su contenedor y conserva las firmas de Ubuntu:

```sh
docker build -f packaging/Dockerfile.gui-verification -t viewrv-gui-check:ubuntu-24.04 packaging
mkdir -p build/ubuntu-gui-repeat
ubuntu_test_container=$(docker create viewrv-gui-check:ubuntu-24.04 /bin/true)
docker export "$ubuntu_test_container" | tar --no-same-owner -xf - -C build/ubuntu-gui-repeat
docker rm "$ubuntu_test_container"
packaging/check_ubuntu_gui.sh build/ubuntu-gui-repeat /ruta/absoluta/al/producto ide
packaging/check_ubuntu_gui.sh build/ubuntu-gui-repeat /ruta/absoluta/al/producto sandbox
```

El helper requiere Bubblewrap y el Node fijado bajo `software/build/toolchain/node_modules/node/bin/node`. Cada recorrido usa su Xvfb privado. No instala bibliotecas en el host ni modifica sus borradores.

En esta ejecución el disco raíz usado por Docker estaba lleno. El primer intento de instalar bibliotecas falló durante APT y no se tomó como evidencia. Se exportó la imagen base al disco del proyecto; APT verificó allí el snapshot firmado dentro de un namespace y descargó las bibliotecas. La configuración que requiere otros UID/GID se completó mediante un `chroot` de contenedor sobre esa raíz generada, sin red ni escritura en la raíz del host. Los logs `ubuntu-image-build.log`, `ubuntu-rootfs-prepare.log` y `ubuntu-rootfs-configure.log` conservan los intentos y el resultado final; no se deshabilitó la validación de firmas para obtener el pase.

## Revisión de avisos de terceros

`packaging/audit_licenses.py` examina el grafo npm de producción instalado y los módulos recogidos por los análisis de PyInstaller, más los runtimes, fuentes y programador. Recopila los archivos de avisos disponibles en un directorio de evidencia y los compara por SHA-256 con archivos independientes del producto. No modifica el producto.

Resultado sobre el paquete actualizado, en `licenses-current/audit.json`:

- 68 entradas conservadoras, incluidas dependencias que el tree shaking podría no conservar.
- 12 entradas con sus archivos de aviso coincidentes dentro del producto.
- 54 entradas cuyos avisos locales no coinciden como archivos independientes del producto.
- 2 entradas sin un archivo completo de aviso localizado por el recolector: pySerial 3.5 y media-query-parser 2.0.2. Tienen identificadores/cabeceras de licencia; eso no reemplaza el texto completo del editor correspondiente.

Este método no busca texto equivalente dentro de HTML concatenado, ASAR o bundles y **no demuestra que falten 54 licencias**. El inventario y la revisión de atribución necesarios para cerrar la distribución siguen incompletos. La carpeta `licenses/` de entrega y su inventario completo, definidos en integración, todavía no están preparados. Los avisos recolectados se conservan fuera del producto para esa revisión.

Se mantienen tres ámbitos abiertos: identificar los componentes realmente incluidos en el bundle; resolver la procedencia y avisos del `viewer-static.min.js` aprobado, cuyo commit upstream no se conoce; y revisar la atribución de dependencias nativas enlazadas estáticamente y las condiciones de sus fuentes. El auditor no aprueba la redistribución ni deduce esas condiciones a partir de un identificador SPDX.

Repetición desde `tp3`:

```sh
software/.venv/bin/python software/packaging/audit_licenses.py \
  /ruta/absoluta/al/producto \
  software/build/evidence/otra-auditoria/avisos
```

El primer inventario del archivo anterior queda separado en `licenses/audit.json`. La auditoría del archivo actual confirma que su lock coincide con el del árbol de fuentes.

## Corrección de metadatos y archivo actualizado

El lock declaraba `@base-ui/utils` 0.6.0 aunque la dependencia solicitada, la URL resuelta y el paquete instalado eran 0.5.0. Se verificó el SHA-512 del tarball de caché y se leyó su `package.json` antes de corregir la versión. `npm-lock-mismatch.json` registra la comprobación; la caché de metadatos incoherente se preservó como `npm-hidden-lock-before.json`. Después, `npm ls --omit=dev --all --json` terminó con código 0. No se reemplazó código de dependencias para realizar esta corrección.

Se construyó un nuevo archivo marcado de verificación:

```text
software/build/native-gui-0.7.0-SemoSr.tar.gz
SHA-256: 5f73454268f241d6bb8c7981bc549e400026a9127670f96c897c99c1ee98e305
```

Su extracción es `software/build/pc-i08-current-extracted-6mf4ag9i/viewrv-0.7.0-linux-x64-verification/`. `package-current-audit.json` comprueba SHA-256, modos y rutas de la extracción y la igualdad de sus 272 archivos de carga útil con el producto efectivamente probado en Arch/Ubuntu. Solo cambia `verification-manifest.json`, con el commit `0a3378d` y el hash del lock corregido; no se alteran ASAR, ejecutables ni recursos. Esta equivalencia permite conservar las pruebas de ejecución sin presentar una repetición que no se hizo. El archivo anterior permanece intacto. Continúa sin `release.json` ni bitstream.

## Variantes SSE y corrección del fixture CLI

La nueva prueba de backpressure bloquea la función `send` del endpoint ASGI real mientras el otro observador consume actualizaciones. Tras superar los 32 pendientes se cierra solo el canal saturado, siguen registrados los clientes y la resuscripción recibe un estado completo. No se confunde esta prueba con congelar el pintado de Electron.

El recorrido GUI observa bytes SSE reales sin cambiarlos. El servidor conserva su reloj real y emite comentarios cada 15 segundos; el reloj del renderer se controla y pausa para comprobar el umbral de 45 segundos sin esperar ese tiempo real ni inventar una captura. El comentario evita una desconexión, la inactividad provoca reconexión con estado completo e identidades estables, y cerrar durante el siguiente reintento finaliza solo GUI. Se verifican las solicitudes mutadoras y la ausencia de UART/RESET. El primer intento dejó el reloj del renderer corriendo durante la espera del comentario; se corrigió la temporización del verificador y se conservaron sus logs. No se cambió el watchdog de la aplicación.

La fixture de CLI nativa asumía una carpeta onedir de CLI sin recursos y fallaba al recibir el producto integrado, que ya contiene `resources/content`. Ahora copia únicamente el ejecutable, su `_internal_cli` y el contenido correspondiente. El fallo previo queda en `native-cli-fixture-layout-failure.log`; los tres ensayos posteriores pasaron sobre el cliente nativo. El core de esos ensayos sigue siendo un adaptador de pruebas, no una FPGA.

## Trabajo pendiente de distribución

Faltan instalar/desinstalar por usuario en Linux, exclusión durante mantenimiento y lanzamiento concurrente, avisos/inventario completos, Windows y los ensayos físicos/humanos identificados en la matriz. Son pendientes diferenciados: los de mantenimiento y avisos requieren trabajo de software antes de aceptar una distribución final; conseguir la placa no los resuelve por sí solo.
