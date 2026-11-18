# Candidata Linux de viewrv

El 17 de noviembre de 2026 se construyó la candidata local `0.7.0` desde
`788390f3b6ef4ad1bc120aa5ef187385a7e9a9e3`, en la rama
`feature/viewrv-linux-release`. La base incorpora las mejoras de la PR #39.

El archivo es `viewrv-0.7.0-linux-x64.tar.gz`, de 409.228.225 bytes
(390,3 MiB). Su SHA-256 es
`527b2c8d68af0667afd7a224fb8aefba80dbbcef7da8562ce72d2875839ad24d`.
El paquete, su archivo `.sha256`, `LEEME.md`, `verification.json` y la carpeta
extraída están en `tp3/software/build/linux-release-candidate/`.

El producto incluye Electron, CLI y core nativos, ensamblador, openFPGALoader,
bitstream REFERENCE, ejemplos, circuito y material de licencias con fuentes.
`README.txt` explica cómo abrirlo desde la carpeta extraída, instalarlo en el
menú y actualizarlo o desinstalarlo conservando los datos.

| Comprobación | Resultado |
| --- | --- |
| GUI, tipos y construcción | 43 pruebas aprobadas con `npm run check`. |
| Instalación y material de licencias | 20 pruebas Python aprobadas. |
| CLI y core del paquete en Arch Linux | Inventario íntegro, ensamblado real, un hilo serial, conservación de programas y cierre correctos. |
| Instalación en Arch Linux | Instalación, actualización, rechazo de mantenimiento con procesos activos y desinstalación con conservación de datos aprobados. |
| IDE nativo en Arch Linux | 33 instrucciones, 165 etapas, 59 ejemplos, edición en splits, ensamblado, guardado y recuperación tras reiniciar GUI/core aprobados. |
| Sandbox e índice de licencias en Arch Linux | Arranque con sandbox y renderer sin Node. Índice y avisos disponibles sin conexión. |
| CLI y core en Ubuntu 24.04.5 | Mismo recorrido nativo aprobado. |
| Aplicación instalada en Ubuntu 24.04.5 | IDE completo, sandbox, mantenimiento mientras la GUI está abierta, actualización, desinstalación y conservación de datos aprobados. |
| Licencias en Ubuntu 24.04.5 | Acción de Ayuda, índice local y avisos adicionales de Monaco aprobados. |
| Python y scripts de empaquetado | Ruff, Prettier y comprobación sintáctica de los scripts shell aprobados. |

La prueba Ubuntu utiliza un userland aislado mediante Bubblewrap y Xvfb, con
red y perfil de usuario aislados, sobre el kernel del host Arch Linux. El
archivo comprimido se comparó con el TAR extraído para las pruebas mediante
SHA-256 del contenido descomprimido. Los ensayos usan los runtimes y el
ensamblador incluidos en el producto.

Los 22 archivos ELF del paquete requieren símbolos de glibc hasta `2.38`.
El máximo aparece en openFPGALoader y sus bibliotecas libcap, libudev y libusb.
También se necesitan las bibliotecas de escritorio de Electron y las
primitivas Linux indicadas en el
[contrato de distribución](integracion_y_distribucion.md#instalación-desinstalación-y-construcción).

El bitstream procede de
[`tp3-17-evidencia`](https://github.com/FrancoPerotti/computer-architecture-tps/releases/tag/tp3-17-evidencia).
Se verificaron el ZIP, `vivado/tp3-reference.bit`, el informe de Vivado y la
procedencia de la sesión UART. El descriptor importado conserva estos datos.

| Dato | Valor |
| --- | --- |
| SHA-256 de `tp3-issue-17-evidencia.zip` | `6d93db7fba97153bb52654e8b6399d7948c2281d83acbae0ae1dc5b5a999dc33` |
| Revisión RTL | `d2ef373194b396f5a4367af22fe7e243ada5d49e` |
| Perfil | `REFERENCE` |
| SHA-256 del bitstream | `660ae6ed81c864ebc30790af1184fdad2421da535bdc9f26e5f22648520e33af` |

La construcción usa Node 24.22.1, CPython 3.14.9, Electron 45.0.0 y
openFPGALoader 1.2.0. El programador, las bibliotecas nativas y CLI/core se
construyeron en la imagen fijada
`ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c`.
El procedimiento general está en el
[README de software](../../../software/README.md#construcción-linux).

La preparación corrigió los puntos encontrados al construir el producto.

- Los scripts de Docker usan el almacén de certificados de Ubuntu para las
  descargas HTTPS realizadas por CPython.
- Las fuentes de terceros se pueden recuperar antes de compilar los runtimes.
  El empaquetado valida los insumos de construcción, avisos y fuentes.
- Las huellas del análisis PyInstaller ordenan los inventarios de módulos,
  datos y biblioteca base. Se contrastaron con la construcción Ubuntu revisada
  y se conservaron sus entradas, opciones, rutas y tipos.
- Los hooks de electron-builder se exportan desde el workspace de GUI y
  reutilizan los controles de hardware, licencias y mantenimiento existentes.
- El ASAR contiene el bundle de GUI y sus metadatos. Las dependencias ya
  integradas por Vite se excluyen de la copia adicional de `node_modules`.
- La incorporación de licencias acepta el nombre `LICENSE.electron.txt` que
  utiliza electron-builder y verifica la misma huella del texto revisado.
- Los ensayos nativos aceptan el paquete de distribución, comprueban el
  ensamblador incluido y consideran el proceso supervisor del core. El
  verificador Ubuntu admite `VIEWRV_TEST_NODE` para indicar el Node fijado.

La descarga actual de Gitiles para `ffmpeg-9db86ce5.tar.gz` devolvió bytes
distintos de los registrados. Se recuperó el archivo revisado de la caché de
aceptación y se comprobó su tamaño de 18.926.460 bytes y su SHA-256
`e83420be15aedc0479ad8265767eb3d18c65236e59be7227c88507998e8ce028`.
Ese archivo está incluido en `resources/licenses/sources/` del paquete y
permite volver a preparar la caché de una reconstrucción.

Quedan pendientes la prueba en Fedora, el recorrido físico con Basys 3 de
este paquete y la publicación en GitHub Releases. Durante esta preparación
no había dispositivos UART en `/dev/serial/by-id`. El
[informe de la #17](../../verification/board_acceptance.md) conserva la
aceptación anterior del bitstream y el protocolo.

La evidencia local queda en `tp3/software/build/linux-release-audit/`, excluida
de Git. Incluye los logs de construcción y pruebas, la comparación de los
inventarios PyInstaller y `elf-compatibility.json`. Las capturas del IDE nativo
usan los prefijos `linux-candidate-arch` y `linux-installed` bajo
`tp3/software/build/`.
