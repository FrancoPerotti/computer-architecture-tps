# PC-I08: avisos, fuentes y licencias del paquete Linux

Fecha: 2026-11-04. **El material de distribución de terceros revisado para este paquete Linux está incorporado y verificado.** Se aplicó MIT al código propio de la aplicación PC, con Franco Perotti y Federico Arnaudo como titulares, según lo indicado por el usuario. El [alcance de MIT](../LICENSING.md) preserva las licencias de terceros y no licencia el hardware ni el resto del repositorio. La revisión es técnica y documental; no constituye una certificación jurídica.

Esta entrega cierra el pendiente de material de avisos Linux de la revisión preliminar. Continúan los pendientes independientes de hardware, Windows y aceptación de PC-I08. El producto sigue marcado como verificación, sin bitstream aprobado ni `release.json`.

## Archivo examinado

```text
software/build/native-gui-0.7.0-Gxfo1R.tar.gz
SHA-256: 222375f160475e9b08193ebdc864a72707e6973c77b13d83668bba3f10d06a48
Fuentes: b66cc4dc251db502b1d7d5cdbf01e838aea4ec05, árbol limpio al construir
```

Se verificaron la huella del archivo, su extracción, 684 archivos de carga útil y el inventario Linux de 934 entradas incluyendo directorios y descriptor. Las licencias ocupan 402 archivos: textos, atribuciones, procedencia, fuentes e índice. Los 416 enlaces del índice resuelven a archivos locales incluidos. Se conservaron 21 archivos fuente externos con 227.765.397 bytes, además de las fuentes pequeñas ya versionadas y del archivo fuente de openFPGALoader que acompaña al programador.

El [registro estructurado](PC-I08-LINUX-LICENSES-2026-11-04.json) conserva artefacto, alcance y hashes de evidencia. El [lock revisado](../packaging/licenses-linux.lock.json) identifica 191 grupos, incluidos inventarios conservadores de dependencias de construcción y otras plataformas. Ese número no representa 191 bibliotecas enlazadas al binario Linux.

## Qué se incorporó

| Ámbito | Material y comprobación |
|---|---|
| Código propio | MIT con ambos titulares, delimitación de alcance y metadatos npm actualizados. La licencia de Electron en la raíz de su runtime se conserva; la propia se incluye en `resources/licenses/MIT.txt`. |
| GUI | Textos y avisos de los 18 paquetes observados en los chunks. El guard reconstruye en un destino aislado y exige equivalencia byte a byte de los 7 archivos del ASAR, incluidos worker y recursos. Rechaza paquetes, imports externos y archivos adicionales no revisados. |
| Monaco e iconos | MIT, `ThirdPartyNotices.txt`, DOMPurify y atribuciones de Lucide/Feather. codicon conserva la licencia publicada por Microsoft, su atribución adicional del icono Git y la identidad del TTF concreto de Monaco 0.57.0 por SHA-256; no se afirma haber reconstruido la fuente. |
| GraphViewer | Apache-2.0, procedencia exacta draw.io 32.0.2 y avisos de spin.js, DOMPurify, regenerator-runtime y pako. Se conservan MIT y Zlib para pako. SDK, XML aprobado y manifiesto de importación no se modificaron. |
| Fuentes tipográficas | Avisos OFL originales de Inter e IBM Plex Mono. |
| Python | Licencia CPython e identificación de sus bibliotecas estáticas mediante el archivo completo oficial de python-build-standalone 20261021. El `libpython` de la instalación coincide exactamente con el archivo oficial stripped de esa release. Se incluyen los 14 textos identificados para sus extensiones incorporadas; readline usa libedit. |
| Paquetes Python | Avisos de los módulos recogidos por PyInstaller, texto completo de pySerial 3.5, excepción de PyInstaller y fuentes exactas de certifi 2026.10.23 con MPL-2.0. Los avisos vendorizados se conservan como tales. |
| Pydantic Core y Rust | SBOM del editor de Pydantic Core 2.50.2, avisos de 101 crates y metadata de Rust del commit identificado dentro del binario. Se agregan los avisos de las 30 entradas de registro del lock de su biblioteca estándar, incluidas las cinco dependencias cuyos caminos aparecen en el binario. Ambos inventarios son conservadores respecto de construcción y otras plataformas. |
| Electron | El ZIP oficial de Electron 45.0.0 fue contrastado con los ejecutables, FFmpeg y los créditos Chromium incluidos. Se conservan la licencia principal y el HTML completo de créditos, que incluye Node.js, SwiftShader, Vulkan y Opus. |
| FFmpeg | Revisión `9db86ce5b5b454dfc96c435f9f0723012980c37f`, fuente exacta, parche de Electron y configuración Linux. El binario declara LGPL 2.1 o posterior; la configuración tiene GPL, nonfree y version3 desactivados. `libffmpeg.so` sigue siendo una biblioteca compartida reemplazable. |
| Programador | Apache-2.0 y fuente de openFPGALoader 1.2.0, atribución MIT de cxxopts, avisos y fuentes con parches Ubuntu de libusb, libftdi, systemd/libudev y libcap. Se conserva la alternativa BSD de libcap. |
| Runtimes GCC | Avisos, excepción de runtime y fuentes exactas de GCC 13 para el programador/launcher y GCC 14 para el `libgcc_s.so.1` recogido por el core. La copia de este último coincide con el paquete Ubuntu `libgcc-s1` 14.2.0-4ubuntu2~24.04.1. |

Las obligaciones y alternativas se revisaron usando los textos incluidos y las referencias primarias de [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0), [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/), [LGPL-2.1](https://opensource.org/license/lgpl-2-1), la [excepción GCC](https://gcc.gnu.org/onlinedocs/libstdc++/manual/license.html), la [excepción de PyInstaller](https://pyinstaller.org/en/stable/license.html), [OFL](https://openfontlicense.org/ofl-faq/) y las condiciones de [FFmpeg](https://ffmpeg.org/legal.html). Los componentes conservan sus propios términos.

Las fuentes Ubuntu proceden del snapshot fijado `20261018T000000Z`: se verificaron las firmas InRelease y los SHA-256 de los índices Sources y archivos referidos. Se incluyen originales, `.dsc`, parches Debian/Ubuntu y firmas de originales cuando el índice las publica. El lock fija URLs, tamaños y huellas; no resuelve versiones flotantes durante la construcción.

La falta de LICENSE local de media-query-parser 2.0.2 permanece como observación del grafo npm instalado. Su código no contribuye a los chunks observados y sus archivos no están en el ASAR. El guard impide trasladar esa conclusión a un paquete que agregue dependencias sueltas sin revisar. Tampoco se infiere que los avisos LGPL de autocommand en setuptools o MPL de SGX en el lock Rust acrediten código de esos componentes en el binario Linux.

## Construcción y acceso

`packaging/licenses.py --fetch` prepara explícitamente la caché, verificando tamaño y SHA-256 antes de reemplazar un archivo. Los builds no descargan fuentes: validan el inventario, los archivos revisados y los nativos antes de copiar textos y fuentes al producto. Un cambio de dependencia o recurso revisado exige actualizar su revisión; regenerar hashes por sí solo no interpreta una licencia.

El constructor de verificación y el hook Linux de electron-builder incorporan el material antes de inventariar el paquete. Windows se rechaza hasta disponer de su revisión. Los controles existentes de bitstream, perfil y plataforma se mantienen. El [procedimiento reproducible](../packaging/LICENSES.md) documenta la preparación y el índice de desarrollo.

Ayuda → Avisos y licencias solicita abrir únicamente el índice local fijo mediante IPC validado. La prueba interceptó la solicitud para no abrir el navegador personal y comprobó la ruta exacta; luego abrió el HTML real en una ventana Electron con sandbox, sin Node. Se comprobaron títulos, titulares, cantidad de entradas y apertura de los avisos suplementarios de Monaco sin solicitudes externas. Se inspeccionó la captura del índice y se ajustó la tabla para mostrar las cuatro columnas sin recorte a 1100 píxeles.

## Fuentes y reemplazo comprobados

`resources/licenses/REBUILDING.md` describe fuentes, reconstrucción, licencias y reemplazo de bibliotecas. Se mantiene la validación de integridad del programador. El manifiesto local no requiere una firma del desarrollador: el usuario puede actualizar la huella para su versión modificada y reconstruir los inventarios si quiere instalarla. El mantenimiento sigue protegiendo las instalaciones modificadas contra sobrescrituras no inventariadas.

Se compiló realmente libusb 1.0.27 desde el original incluido usando el GCC/sysroot fijado en un namespace Ubuntu sin red y con raíz/proyecto de solo lectura, salvo el directorio temporal de compilación. La variante utiliza `--disable-udev`, `--enable-shared` y runtimes GCC estáticos. Su hash difiere de la biblioteca distribuida. Al reemplazarla en una copia portátil, el hash original fue rechazado; al actualizar su entrada en el manifiesto, openFPGALoader ejecutó `--version` con código 0. Esto demuestra compilación y carga dinámica de una biblioteca reconstruida; no prueba operaciones USB ni reproducción idéntica del binario Ubuntu original.

Los primeros intentos detectaron ausencia de libgcc compartida y del preprocesador C++ en el sysroot de ensayo. Se corrigió el entorno con enlace estático de runtimes y el C++ fijado; se conservan los logs fallidos y el comando exitoso. No se instalaron herramientas en el host ni se modificaron las bibliotecas de la aplicación.

## Validación

| Comprobación | Resultado |
|---|---|
| Suite Python viewrv | 271 pruebas pasadas; incluye 5 nuevas de staging, fuentes faltantes/alteradas, índices, rutas, symlinks y descarga fallida. |
| Suite Node | 43 pruebas pasadas; guard de composición y controles de hardware/distribución. |
| Construcción GUI | TypeScript y build pasados. Rebuild de atribución con 7/7 archivos idénticos y 18 paquetes observados. |
| Calidad | Ruff 0.17.1, formato Python, Prettier, sintaxis de shell y comprobación de whitespace propios pasados; los avisos originales conservan sus bytes mediante `.gitattributes`. |
| Archivo final | SHA-256, extracción, inventario completo, 402 archivos de licencias/fuentes y 416 enlaces locales verificados sin depender de la caché del checkout. |
| Instalación real | Instalación por usuario del archivo final, verificación de fuentes/avisos instalados y desinstalación propia pasadas con HOME/XDG temporales. |
| Ayuda e índice final | Prueba nativa Ubuntu/Xvfb pasada sobre el archivo final; índice y avisos Monaco sin red. |
| Regresión nativa de GUI | Recorrido Ubuntu de 33 instrucciones/165 etapas, 59 ejemplos, assembler, split, guardado/autoguardado, recuperación y cierre pasado sobre el archivo previo de esta misma implementación. |
| Sandbox | Prueba nativa Ubuntu pasada sobre ese archivo previo. |

Los **281 archivos ajenos a licencias y al inventario Linux** del archivo final coinciden exactamente con el archivo `aef185437764568885c05ff99378b8fb340da9128ff7903ae1bdb0f0c2560ef4` utilizado para esos recorridos nativos. Esto incluye ASAR, ejecutables, runtimes, programador y contenido. La equivalencia se verificó por rutas, tamaños, modos y SHA-256; permite conservar esas pruebas sin afirmar una repetición que no se realizó. El índice final y la instalación sí se volvieron a probar directamente.

Un primer ensayo usó una ventana oculta y agotó el timeout de captura; se corrigió el verificador para mostrarla dentro de Xvfb. Otro intento de instalar mientras la GUI del mismo producto estaba abierta fue rechazado por la exclusión existente; la instalación se repitió después del cierre. La prueba Node inicial expuso que el nuevo guard de licencias ocultaba los errores de hardware en la fixture; se separó la comprobación de hardware reutilizable, manteniendo ambos controles en el hook de distribución, y la suite completa posterior pasó.

La evidencia local se conserva bajo `software/build/evidence/distribution-licenses-2026-11-04/`, ignorada por Git, con sus hashes en el registro estructurado. La [matriz R3](PC-I08-ACCEPTANCE-2026-11-04-R3.md) actualiza el pendiente de avisos Linux y conserva identificadas las pruebas históricas. No se acredita Windows, USB físico, bitstream, escritorio Ubuntu real, equipo modesto, corte eléctrico ni aceptación humana.
