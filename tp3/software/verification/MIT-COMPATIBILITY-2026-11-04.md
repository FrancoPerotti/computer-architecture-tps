# Compatibilidad de MIT para el código propio de viewrv

Estado posterior: se aplicó MIT al código propio con los titulares indicados por el usuario y se implementó el [material de distribución Linux](../packaging/LICENSES.md). El contenido siguiente conserva la revisión preliminar y sus pendientes en aquel momento.

Revisión técnica del 4 de noviembre de 2026. **MIT es una opción viable para el código propio con las condiciones identificadas; la revisión de redistribución del paquete completo sigue abierta.** No se encontró una exigencia incompatible entre los términos revisados. Los componentes todavía pendientes impiden extender esa conclusión a toda la entrega. Este informe no constituye asesoramiento jurídico ni cambia la licencia del proyecto.

El alcance es la aplicación PC y sus recursos distribuidos en Linux. No adjudica titularidad ni licencia el RTL, la documentación, los dibujos o las contribuciones de otras personas. Antes de aplicar MIT deben acordarse titulares y alcance. El propósito educativo no elimina las condiciones de las licencias de terceros.

## Artefacto y método

Se examinó `software/build/native-gui-0.7.0-PvZzgn.tar.gz`, SHA-256 `e626c3507fea772ffb97aa1f525e44ffcd53d6030eccf22446697ecea2b875e0`, con 282 archivos de carga útil y código de aplicación de `2c0ae7110f91ffd73f926a2bac03875e69b56945`. Es el paquete de verificación del [mantenimiento Linux](PC-I08-LINUX-MAINTENANCE-2026-11-04.md), sin bitstream ni aprobación de distribución final. La base del árbol revisado es `ce27fe98f46de1572bec8470c09d88e39d61bf40`.

El [registro estructurado](MIT-COMPATIBILITY-2026-11-04.json) conserva 68 grupos del inventario conservador, las reglas de evaluación, componentes incorporados adicionales y huellas de evidencia. Se contrastaron archivos de licencia locales, cabeceras incorporadas, fuentes upstream fijadas y enlaces ELF. La evaluación manual de términos no se sustituye por un identificador SPDX.

La reconstrucción aislada de la GUI observó módulos de producción y del worker de Monaco: sus **7 archivos de salida coinciden byte por byte con el ASAR probado**. Hay 18 paquetes npm observados, frente a 37 del grafo instalado; fuera de `out/`, el ASAR contiene únicamente `package.json`. No se atribuye automáticamente al producto todo paquete instalado. Esta observación tampoco cubre recursos fuera del ASAR ni garantiza la composición de un paquete futuro de electron-builder.

## Resultado por familia

| Componentes observados | Condición para coexistir con código propio MIT |
|---|---|
| React, Base UI, Floating UI, FlexLayout, Zustand y otras bibliotecas MIT/BSD/ISC | Conservar sus textos y atribuciones. Lucide incluye también avisos MIT de Feather en su licencia completa. |
| Monaco 0.57.0 | Conservar MIT y `ThirdPartyNotices.txt`; revisar por separado código incorporado y fuente de iconos. Se corrigió el recolector para reconocer ese archivo de avisos. |
| DOMPurify incorporado | Su alternativa Apache-2.0 permite esta combinación respetando sus condiciones. La copia en Monaco es 3.4.15; la del visor, 3.4.16. |
| GraphViewer/draw.io 32.0.2 | Mantener Apache-2.0 y atribuciones de sus bibliotecas. La identidad upstream quedó resuelta; faltan completar los textos de distribución incorporados. |
| openFPGALoader 1.2.0 | Su licencia principal es Apache-2.0. Se ejecuta mediante un proceso separado; se conserva su fuente. Incluir también las atribuciones incorporadas, como cxxopts MIT. |
| libusb, libftdi y libudev distribuidas con el programador | Mantener sus licencias LGPL aplicables, fuentes exactas y condiciones de reemplazo/reenlace. El enlace dinámico por sí solo no completa esas obligaciones. |
| libcap y runtimes GCC | Se identificaron la alternativa BSD de libcap y la GCC Runtime Library Exception 3.1. Conservar avisos y trazabilidad del proceso de compilación elegible. |
| certifi 2026.10.23 | Mantener MPL-2.0 y acceso a las fuentes exactas del componente. Los archivos propios separados pueden usar MIT. |
| PyInstaller 6.22.3 | La excepción de su bootloader admite distribuir la aplicación bajo una licencia elegida, respetando las de sus dependencias. |
| Inter e IBM Plex Mono | Conservar OFL-1.1 y copyright de las fuentes. La aplicación puede llevar otra licencia. |
| Fuente codicon de Monaco | El editor declara CC-BY-4.0 para el contenido. Completar atribución y trazabilidad de la revisión exacta del recurso antes de cerrar su distribución. |
| CPython standalone y Electron/Chromium | Las licencias principales PSF y MIT no bastan para evaluar todo su contenido nativo. Sigue pendiente cerrar el inventario y las obligaciones de bibliotecas incorporadas. |

Estos resultados se apoyan en las condiciones de [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0), la combinación de archivos bajo [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/FAQ/), el enlace bajo [LGPL-2.1](https://opensource.org/license/lgpl-2-1), la [excepción GCC](https://gcc.gnu.org/onlinedocs/libstdc++/manual/license.html), la [excepción de PyInstaller](https://pyinstaller.org/en/stable/license.html), las reglas de [OFL](https://openfontlicense.org/ofl-faq/) y la atribución de [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/). Cada componente conserva sus propios términos.

## Hallazgos que resuelven dudas del inventario anterior

**Visor aprobado.** El SDK local de 4.360.002 bytes tiene SHA-256 `32c73b8e42e784d0ace7d59754cbea6c2a78a0f506d390e2a3870546b9242f7c` y blob Git `bcc038e8fc4b101d64724c3be1b3b33bdb2954a4`. Coincide íntegramente con `src/main/webapp/js/viewer-static.min.js` del commit draw.io `2201e54124bfbbf09d8addec60e6f8d73eed6f92`, etiqueta `v32.0.2`, cuya [licencia fijada es Apache-2.0](https://github.com/jgraph/drawio/blob/2201e54124bfbbf09d8addec60e6f8d73eed6f92/LICENSE). Se conservó intacto el SDK y el manifiesto de importación original. Este informe complementa la incertidumbre histórica de ese manifiesto.

Las cabeceras del visor identifican DOMPurify, regenerator-runtime MIT, pako 2.2.0 **MIT AND Zlib** y spin.js 2.0.0. Se confirmó MIT para spin.js en su [fuente fijada](https://github.com/fgnass/spin.js/blob/0271cbb28ac9a4be3910df937a586380ec25235e/spin.js). La versión de regenerator-runtime no figura en su cabecera. Este listado de cabeceras no constituye un inventario exhaustivo del SDK minificado.

**Programador.** La [licencia fijada de openFPGALoader](https://github.com/trabucayre/openFPGALoader/blob/befbab4f646207dbaf1daf8b144dd980ad283dd5/LICENSE) confirma Apache-2.0. Su clase propia `FTDIpp` usa la biblioteca C libftdi; no debe confundirse con el wrapper C++ GPL de esa biblioteca. Las bibliotecas compartidas observadas son libusb `2:1.0.27-1`, libftdi `1.5-6build5`, libudev `255.4-1ubuntu8.18` y libcap `1:2.66-5ubuntu2.4`.

Se probó el camino de reemplazo en una copia temporal: una biblioteca con hash diferente se rechaza; después de actualizar su entrada en el manifiesto local sin firma, el programador ejecuta `--version` correctamente. El cambio consistió en añadir bytes finales, preservando código y ABI. Esto verifica el control de integridad y la carga, **no acredita una biblioteca reconstruida ni el cumplimiento completo de LGPL**. Deben documentarse fuentes, reconstrucción y actualización del manifiesto sin retirar la validación de integridad.

**Python y recursos incorporados.** Se recuperó el [texto BSD de pySerial 3.5](https://github.com/pyserial/pyserial/blob/v3.5/LICENSE.txt), ausente de la instalación local. Se preservaron en evidencia las fuentes exactas de certifi y MPL. El aviso LGPL de autocommand aparece en la recolección conservadora de setuptools, pero su código no figura en el análisis de PyInstaller; sí se identificaron ocho grupos de código vendorizado con términos permisivos o alternativas permisivas. Estas copias de evidencia todavía no forman parte del paquete distribuido.

**Límites de los runtimes.** El `libpython` empaquetado coincide por SHA-256 con el standalone utilizado para construir. Sus módulos incorporados incluyen bibliotecas nativas, por ejemplo OpenSSL 3.5.9 y SQLite 3.53.1. La licencia principal de [CPython](https://docs.python.org/3.14/license.html) reconoce componentes con términos propios; el [standalone](https://docs.astral.sh/python-build-standalone/) requiere revisar también sus dependencias estáticas. El backend de readline observado es editline. En Electron, el HTML de créditos Chromium incluye FFmpeg con texto LGPL y referencias opcionales a GPL: ese texto no demuestra una compilación con opciones GPL habilitadas. Falta asociarlo a fuentes y opciones del binario exacto.

**Dependencias npm no observadas.** No se localizó un LICENSE completo de media-query-parser 2.0.2 en su commit npm `ef6703c3e8cea7520bed17b923306885a57a984a`, aunque sus metadatos declaran MIT. Su código no contribuye directamente a los chunks verificados. No se usa una licencia de la rama actual para atribuírsela retroactivamente a esa versión; debe revisarse de nuevo si otro empaquetado incluye sus archivos.

## Trabajo concreto antes de cerrar la distribución

1. Incorporar al paquete un inventario y los textos completos de terceros, accesibles sin red, incluidos los avisos suplementarios de Monaco, iconos y visor.
2. Completar fuentes exactas y procedimiento de reconstrucción/reemplazo de los componentes MPL/LGPL, con los parches de la distribución Ubuntu y los textos completos referidos por sus avisos.
3. Cerrar procedencia, versiones, avisos y obligaciones de los runtimes CPython/Electron/Chromium/FFmpeg y la revisión exacta de codicon.
4. Acordar autoría y alcance de MIT para el código propio. Repetir el análisis de composición sobre el artefacto final y posteriormente sobre Windows.

La [aceptación R2](PC-I08-ACCEPTANCE-2026-11-04-R2.md) mantiene abierto el caso de avisos. Identificar licencias compatibles no equivale a haber incluido ya sus textos, fuentes y procedimientos en el producto. No se modificó la aplicación para esta revisión.

## Evidencia y repetición

La evidencia local está bajo `software/build/evidence/license-compatibility-2026-11-04/`, ignorada por Git. El JSON versionado conserva sus huellas; el repositorio conserva este informe y los auditores, pero no pretende contener toda esa evidencia local. Los archivos centrales son `gui-modules-reviewed/modules.json`, `viewer-provenance.json`, `elf-linkage.json`, `lgpl-replacement-check.json`, `python-native-runtime.json`, `python-vendored.json` y `audit-with-vendor-notices/audit.json`.

Desde `tp3`, con las dependencias fijadas y los análisis de PyInstaller de la construcción examinada disponibles:

```sh
software/.venv/bin/python software/packaging/audit_licenses.py \
  /ruta/absoluta/al/producto /ruta/absoluta/a/evidencia/avisos
software/build/toolchain/node_modules/node/bin/node \
  software/packaging/audit_gui_modules.cjs \
  /ruta/absoluta/a/evidencia/gui-nueva /ruta/absoluta/al/producto
software/.venv/bin/python -m unittest software.tests.viewrv.test_acceptance_audit -v
```

El auditor de módulos exige un destino nuevo fuera de la GUI y del producto; falla si la reconstrucción difiere. La pertenencia de módulos es conservadora, no una prueba automática de interpretación jurídica. La comprobación upstream, ELF y de términos es adicional al inventario automático.

Pasaron las dos pruebas del recolector, las comprobaciones de destino protegido y la comparación de los siete archivos de GUI. No se repitió toda la suite funcional porque el cambio ejecutable se limita a herramientas de auditoría y reconocimiento de avisos.
