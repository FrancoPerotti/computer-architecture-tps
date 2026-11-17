# Preparación de la release Linux de viewrv

Auditoría del 17 de noviembre de 2026 sobre
`4aaff4009925dd71f4fefae311afd4ee7550335c`, que integra la PR #39.
La rama de trabajo es `feature/viewrv-linux-release`. La versión actual de GUI,
core y CLI es `0.7.0`. El número de la próxima publicación queda por definir.

La entrega prevista conserva el `.tar.gz` para Linux x86-64, el uso desde la
carpeta extraída y la instalación opcional por usuario mediante `install.sh`.
El objetivo es descargar, extraer y abrir la aplicación, con una opción para
agregarla al menú. La base de construcción sigue siendo Ubuntu 24.04.
[Decisión de distribución](integracion_y_distribucion.md#instalación-desinstalación-y-construcción)

| Parte de la entrega | Estado comprobado | Pendiente para construir o publicar |
| --- | --- | --- |
| GUI, ejemplos y circuito | La construcción y las 43 pruebas unitarias pasan en esta base. | Comprobar la GUI dentro del archivo final extraído. |
| CLI y core independientes | Existe la receta PyInstaller con CPython 3.14.9. Los binarios generados faltan en este checkout. | Construirlos con el entorno Ubuntu fijado. |
| Programador de Basys 3 | Existe la receta de openFPGALoader 1.2.0 y sus dependencias fijadas. El ejecutable y su inventario faltan en este checkout. | Construir el programador y verificar su inventario. |
| Bitstream REFERENCE | El archivo de la aceptación publicada coincide con el informe y con la sesión UART. | Incorporarlo mediante el importador existente para generar `processor.bit` y `processor.json`. |
| Licencias | Están presentes y coinciden las huellas de los 375 avisos. De los 11 insumos revisados, 4 corresponden a productos de construcción que faltan localmente. | Construir esos insumos y contrastarlos con el inventario revisado. Recuperar las 21 fuentes de terceros, unos 217,2 MiB. |
| Instalación por usuario | Existen instalación, actualización, accesos de menú y CLI, desinstalación y conservación de datos. Pasan las pruebas de instalación y licencias. | Repetir los recorridos sobre el paquete nativo extraído en perfiles temporales. |
| Construcción Linux | Los scripts usan una imagen Ubuntu fijada por digest. En este entorno el cliente Docker está instalado y el daemon no está accesible. | Ejecutar la receta en un entorno con acceso a Docker. |
| Compatibilidad entre distribuciones | El formato de archivo y la instalación por usuario están definidos. | Medir las dependencias de los binarios finales y probar ese mismo archivo en los sistemas seleccionados. |
| Publicación | Hay una release de evidencia de la aceptación en placa. Los workflows actuales verifican fuentes y pruebas. | Preparar el archivo de producto, su SHA-256, versión, tag, notas y guía de descarga. La automatización de publicación puede incorporarse después. |

El bitstream se recuperó de la release
[`tp3-17-evidencia`](https://github.com/FrancoPerotti/computer-architecture-tps/releases/tag/tp3-17-evidencia).
Se comprobaron el ZIP completo, `vivado/tp3-reference.bit`, el informe de
construcción y los datos de `uart-smoke/session.json`.

| Dato | Valor verificado |
| --- | --- |
| ZIP publicado | `tp3-issue-17-evidencia.zip` |
| SHA-256 del ZIP | `6d93db7fba97153bb52654e8b6399d7948c2281d83acbae0ae1dc5b5a999dc33` |
| Revisión RTL del bitstream | `d2ef373194b396f5a4367af22fe7e243ada5d49e` |
| Perfil | `REFERENCE` |
| Tamaño del bitstream | 2.192.134 bytes |
| SHA-256 del bitstream | `660ae6ed81c864ebc30790af1184fdad2421da535bdc9f26e5f22648520e33af` |

El informe de aceptación ya acredita el recurso de hardware. Los textos que
todavía dicen «Bitstream pendiente» en los README de software y hardware y el
mensaje final del importador requieren actualizarse al incorporarlo.
[Informe de aceptación](../../verification/board_acceptance.md)

El orden propuesto para producir la primera candidata es el siguiente.

1. Definir la versión y preparar un entorno de construcción con Docker y las
   herramientas fijadas. En esta auditoría se usaron Node 24.22.1 y CPython
   3.14.9. El host es Arch Linux x86-64.
2. Incorporar el bitstream verificado con el importador existente. Conservar la
   revisión RTL original y la huella registrada en la aceptación.
3. Construir el programador, preparar el contenido de GUI y construir CLI/core.
   Verificar el inventario de licencias con esos productos. Si un hash cambia,
   revisar el insumo y la composición antes de actualizar su entrada.
4. Recuperar las fuentes de terceros verificadas, ejecutar electron-builder y
   extraer el `.tar.gz` resultante en una ubicación nueva. El inventario de
   recursos debe corresponder al contenido final.
5. Ejecutar la CLI y la GUI empaquetadas, instalar en un perfil temporal,
   comprobar el acceso desde el menú, actualizar y desinstalar conservando
   Assembly, preferencias y registros. Verificar ejemplos y uso sin conexión.
6. Probar el mismo archivo en Ubuntu 24.04 y en el host Arch Linux. Proponer
   Fedora como comprobación adicional para ampliar la cobertura. Registrar
   versión de distribución, arquitectura, dependencias y resultado observado.
7. Ejecutar el recorrido con Basys 3 usando el paquete final. Registrar la
   preparación USB, carga, ejecución y depuración. La aceptación anterior sirve
   como referencia de hardware y protocolo.
8. Preparar una prerelease con el `.tar.gz`, su checksum, las notas y una guía
   breve para descargar, extraer, abrir e instalar. Enumerar los sistemas
   comprobados y las condiciones de acceso USB de cada uno.

La revisión del paquete debe reutilizar `smoke_package.py`,
`smoke_linux_installation.py` y `sandbox-smoke.cjs`. Los ensayos
`native-ide-smoke.cjs`, `licenses-smoke.cjs` y `check_ubuntu_gui.sh` actualmente
exigen la marca `VERIFICATION-ONLY.txt`. Para emplearlos en el producto final
hay que adaptar la selección del paquete conservando sus comprobaciones.

La compatibilidad depende también de las bibliotecas del sistema, glibc,
sandbox, entorno gráfico y primitivas del kernel usadas por los launchers.
Los requisitos mínimos efectivos deben obtenerse de los binarios que se
publiquen y de los ensayos en cada sistema.
[Contrato de construcción](integracion_y_distribucion.md#instalación-desinstalación-y-construcción)

Las comprobaciones ejecutadas durante esta auditoría fueron las siguientes.

| Comprobación | Resultado |
| --- | --- |
| `npm run check`, desde `software/gui` | Formato, tipos y construcción correctos. 43 pruebas aprobadas. |
| `software/.venv/bin/python -m unittest -v software.tests.viewrv.test_linux_installation software.tests.viewrv.test_distribution_licenses`, desde `tp3` | 18 pruebas aprobadas. |
| ZIP y bitstream publicados | Las huellas coinciden con GitHub y con el informe de aceptación. |
| Avisos y entradas de licencias disponibles | Sin cambios de huella. Faltan los productos de construcción y la caché de fuentes indicados en la tabla. |
| `docker version` | El cliente no puede conectar con un daemon en `/var/run/docker.sock`. |

La evidencia local queda bajo `software/build/linux-release-audit/`, excluida
de Git. Incluye el ZIP descargado, el bitstream extraído, `audit.json` con
los recursos comprobados y `installation-and-licenses.log`.
