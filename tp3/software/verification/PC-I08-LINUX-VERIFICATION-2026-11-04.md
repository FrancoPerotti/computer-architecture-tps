# PC-I08: paquete Linux de verificación

Estado: comprobación parcial de Linux x86_64. El artefacto reúne la GUI 0.7.0 actual, la CLI, el core y recursos locales. No cierra PC-I08: faltan el bitstream aprobado, la Basys 3, Windows, la matriz completa de aceptación y las evaluaciones en equipos representativos.

## Artefacto e identidad

Rutas relativas a `software/`:

- Archivo: `build/native-gui-0.7.0-o2h6pq.tar.gz` (183.140.837 bytes).
- Huella: `build/native-gui-0.7.0-o2h6pq.tar.gz.sha256`.
- Extracción probada: `build/pc-i08-extracted-mlbukv98/viewrv-0.7.0-linux-x64-verification/`.
- Construcción: `build/pc-i08-linux-package.json`.
- Auditoría de extracción: `build/pc-i08-linux-archive-audit.json`.

SHA-256 del archivo:

```text
fbd93a8c27c7d653be7c59e9f9faa48447c375021477c6f82945a254f6abc870
```

El manifiesto identifica `4aa7f15797c8189ae552eb125df1b81bc97ec43f`, con fuentes limpias al construir. Las correcciones posteriores del ensayo nativo y este informe no alteran el producto del archivo: solo cambian código de verificación y documentación. No se modificó la versión de producto ni el gate de distribución con hardware.

`VERIFICATION-ONLY.txt` identifica el alcance. `verification-manifest.json` registra 272 archivos con ruta, tamaño, permisos y SHA-256, además de huellas de locks y versiones. Excluye su propia entrada; el SHA-256 del comprimido cubre también ese manifiesto. Los 272 registros se contrastaron con la extracción, comprobando ausencia de archivos adicionales salvo el propio manifiesto, enlaces simbólicos y rutas fuera de la raíz. Los 161 recursos de contenido, hardware y programador coinciden byte a byte con las fuentes. Los 14 avisos de licencia encontrados se enumeran en `licenses`; no se acredita aquí una auditoría exhaustiva de licencias.

No contiene `release.json` ni `processor.bit`. No incorpora el adaptador de demo visual ni fixtures de ejecución. El análisis de PyInstaller incluye `software.assembler` en el core y no incluye módulos de `software.tests`, `educational_core` ni `pipeline_vectors` (`build/pc-i08-native-modules-audit.json`).

Los 8 archivos de ASAR coinciden con `gui/out` y `gui/package.json`, sin fuentes ni tests adicionales dentro del archivo de aplicación (`build/pc-i08-gui-asar-audit.json`).

## Construcción y entorno

Node 24.22.1, Electron 45.0.0, Playwright 1.62.1, CPython 3.14.9 convencional y PyInstaller 6.22.3. Se reutilizaron las dependencias instaladas de los locks del proyecto. CLI/core se reconstruyeron con la imagen Ubuntu 24.04 fijada `ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c`, red deshabilitada y rootfs de contenedor de solo lectura. Log: `build/pc-i08-native-build.log`.

Tras `npm run build`, se ejecutó desde `software/gui`:

```sh
node ../packaging/build_gui_verification.cjs .. --archive
```

El tar conserva permisos, ordena entradas y normaliza propietario/fecha; esto no acredita reproducibilidad bit a bit de toda la cadena de herramientas. Los paquetes históricos permanecen intactos. El renderer, Monaco, fuentes, visor, ejemplos y guías se incluyen como recursos locales; no requieren el servidor de desarrollo ni instalaciones de Python/Node en el equipo de uso.

## Comprobaciones

Host gráfico: Arch Linux, kernel `7.2.11-arch1-1`, x86_64, sesión Wayland con Electron en X11. Las pruebas nativas se ejecutan con perfiles y directorios XDG temporales separados del perfil del usuario.

| Comprobación | Resultado y evidencia |
|---|---|
| Construcción GUI | `npm run build` completado con typecheck y compilación de renderer/main/preload. |
| Inventario y gate | 2 pruebas de paquete: inventario binario, permisos y rechazo de enlaces; distribución rechaza hardware ausente, inventarios obsoletos, plataforma distinta y recursos alterados. |
| Regresión Node | 42/42 pruebas pasadas (`build/pc-i08-node-tests.log`); formato comprobado. La verificación completa previa de GUI, 23/23 casos, permanece en el [informe de organización](SOFTWARE-ORGANIZATION-2026-11-03.md). No se atribuye esa corrida anterior a este paquete. |
| Archivo extraído | SHA-256 del comprimido y sus 272 archivos verificados; 161 recursos idénticos. |
| GUI/CLI/core del archivo extraído | Recorrido completo pasado: 33 instrucciones/165 etapas, banco de 59 ejemplos y guía original, assembler real e imagen esperada, división del editor, guardado manual y automático, recuperación de borrador sin destino tras reiniciar GUI/core y guardado posterior con ruta elegida. Cerrar GUI conserva el trabajo CLI; finalizar el último trabajo permite terminar el core. Sin errores de renderer ni solicitudes externas inesperadas. Log `build/pc-i08-linux-native-ide.log`. |
| Sandbox del archivo extraído | Arranque directo pasado sin `--no-sandbox`, renderer sin Node y cierre correcto. Log `build/pc-i08-linux-sandbox.log`. |
| CLI/core/programador sin placa | `smoke_preparation_native.py software --sessions` pasó en Arch y en la base Ubuntu fijada, esta última con `--network none`. Assembler real, programador 1.2.0 y dependencias locales, enumeración sin placa, preparación requerida, consultas históricas de 32/64 bits y cierre. Logs `build/pc-i08-native-preparation.log` y `build/pc-i08-ubuntu-native-preparation.log`. |

Los registros históricos del último ensayo se crean fuera del producto mediante fuentes de tests y no restauran sesiones físicas. La comprobación Ubuntu de CLI/core no acredita el escritorio Ubuntu.

Las capturas `build/pc-i08-linux-native-conceptual.png`, `build/pc-i08-linux-native.png` y `build/pc-i08-linux-native-recovered.png` registran el visor, el borrador antes del cierre y su guardado tras recuperar. Se inspeccionaron visualmente las capturas del visor y del documento recuperado.

El primer intento de ampliar el ensayo gráfico asumía que un archivo asociado quedaría sin guardar al cerrar. Se corrigió esa expectativa para respetar el contrato de autoguardado; el log se conserva en `build/pc-i08-linux-native-ide-harness-mismatch.log`. Se ajustaron además el foco por panel al crear documentos, la lectura del texto visual de Monaco y la restricción de red del ensayo: el host establece conexión directa al arrancar y después se configura el proxy inaccesible antes de recorrer las funcionalidades. El diagnóstico parcial de IDE se conserva en `build/pc-i08-linux-native-ide-diagnostic.log`; no acredita el recorrido conceptual omitido allí. Estas correcciones pertenecen al verificador; no se cambió la aplicación para obtener el resultado.

## Uso y repetición

Desde el directorio que contiene el comprimido:

```sh
sha256sum -c native-gui-0.7.0-o2h6pq.tar.gz.sha256
tar -xzf native-gui-0.7.0-o2h6pq.tar.gz
cd viewrv-0.7.0-linux-x64-verification
./viewrv-gui
./viewrv --help
```

Desde `software/gui`, indicar la raíz extraída con `VIEWRV_PRODUCT` y ejecutar secuencialmente `node tests/native-ide-smoke.cjs` y `node tests/sandbox-smoke.cjs`. `VIEWRV_EVIDENCE_PREFIX=pc-i08-linux` conserva capturas con ese prefijo en `software/build/`.

La restricción de red de la prueba gráfica bloquea HTTP(S) externo después del arranque mediante un proxy inaccesible, conserva loopback directo y registra solicitudes inesperadas. No equivale a desconectar toda la red del host. No se ejecutó LOAD/RUN/STEP físico ni se acepta una simulación como evidencia de FPGA.

## Pendientes

Se mantienen el bitstream aprobado, programación y comunicación real con Basys 3, Windows/NSIS e instalación/desinstalación, ejecución gráfica en Ubuntu, revisión completa de licencias, los 30 casos y 74 requisitos, rendimiento en equipos modestos identificados y aceptación humana. Este artefacto permite probar la aplicación nativa actual y avanzar esa verificación sin cerrar esos pendientes.
