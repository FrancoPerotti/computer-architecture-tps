# Fuentes y reemplazo de bibliotecas

viewrv usa bibliotecas de terceros que conservan sus licencias. En particular, utiliza código de FFmpeg bajo LGPL 2.1 o posterior. Sus fuentes y las de las bibliotecas LGPL del programador acompañan a los binarios en este mismo paquete, sin depender de una descarga posterior. Los textos completos están enlazados desde `index.html`.

## Bibliotecas del programador

En `sources/ubuntu` se incluyen fuentes originales, descriptores `.dsc` y parches de las revisiones Ubuntu distribuidas de libusb, libftdi, systemd/libudev y libcap. Se incluye también GCC 13, utilizado para el enlace del programador y el launcher, y GCC 14, correspondiente al `libgcc_s.so.1` que acompaña al core. La procedencia y SHA-256 de cada archivo están en `manifest.json`. Los avisos de GCC y su excepción de runtime se conservan por separado; la excepción permite distribuir los módulos independientes bajo sus propios términos.

En un entorno de desarrollo Ubuntu 24.04 con las herramientas y dependencias de construcción instaladas, reconstruir cada paquete mediante su descriptor:

```sh
mkdir fuentes-y-compilacion
cd fuentes-y-compilacion
dpkg-source -x /ruta/al/paquete/resources/licenses/sources/ubuntu/libusb-1.0/libusb-1.0_1.0.27-1.dsc
cd libusb-1.0-1.0.27
dpkg-buildpackage -b -us -uc
```

`dpkg-source` aplica los parches incluidos. El archivo `debian/control` de cada fuente declara las dependencias de construcción; no se requiere acceso de administrador para compilar una vez que estén instaladas. Para reproducir el programador propio, consultar `../programmer/sources/build-lock.json`, el archivo fuente de openFPGALoader y sus flags en `../programmer/manifest.json`. El proyecto conserva los scripts de construcción bajo `tp3/software/packaging`.

Las bibliotecas reemplazables están en `../programmer/lib/`: `libusb-1.0.so.0`, `libftdi1.so.2`, `libudev.so.1` y `libcap.so.2`. Se cargan dinámicamente usando ese directorio. El reemplazo debe conservar ABI y SONAME. Podés estudiar, modificar y reconstruir los componentes conforme a sus licencias, y depurar cambios en las bibliotecas; no se agrega una prohibición de ingeniería inversa para ese fin.

Trabajá con una copia portátil y cerrá sus procesos antes de reemplazar archivos. Después de copiar tu biblioteca, actualizar su entrada SHA-256 en `../programmer/manifest.json` permite que el control de integridad acepte esa versión. El manifiesto es local y no requiere firma ni una clave del desarrollador. Por ejemplo, desde la raíz de tu copia portátil y con Python de desarrollo:

```sh
python3 - <<'PY'
import hashlib, json
from pathlib import Path
root = Path('resources/programmer')
path = root / 'manifest.json'
value = json.loads(path.read_text())
for entry in value['files']:
    if entry['path'].startswith('lib/'):
        with (root / entry['path']).open('rb') as stream:
            entry['sha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
path.write_text(json.dumps(value, indent=2) + '\n')
PY
```

La aplicación sigue verificando el manifiesto. El inventario original del paquete deja de describir tu copia modificada; no debe presentarse como la distribución verificada. Para instalar o actualizar una versión modificada, reconstruir también los inventarios Linux con las herramientas del proyecto y conservar los avisos/fuentes de tus cambios. El mantenimiento rechaza sobrescribir una instalación que tenga modificaciones no inventariadas. Esto protege los archivos del usuario y no impide ejecutar la copia portátil modificada.

## FFmpeg de Electron

El runtime es Electron 45.0.0, commit `54f961b44b83e4ece81065ab60a182fd0c38c01e`, basado en Chromium `156.0.8078.48`. FFmpeg procede de `9db86ce5b5b454dfc96c435f9f0723012980c37f`. `sources/ffmpeg` incluye el archivo fuente y `link_with_loader_path.patch` de Electron. Este parche cambia el enlace en macOS y no cambia el código de la biblioteca Linux. `provenance/ffmpeg-config.h` conserva la configuración generada: GPL, nonfree y version3 desactivados. El binario declara LGPL 2.1 o posterior mediante `avcodec_license`.

La biblioteca `libffmpeg.so`, en la raíz del producto, se enlaza dinámicamente. Para reconstruirla con la misma integración, usar el checkout fijado de Electron, sincronizar sus DEPS, aplicar sus parches y construir el target `ffmpeg` con las opciones oficiales de `build/args/release.gn`: `is_component_build=false`, `is_component_ffmpeg=true`, `ffmpeg_branding="Chrome"` y `proprietary_codecs=true`. El archivo fuente incluido contiene `BUILD.gn`, los scripts `chromium/scripts/build_ffmpeg.py` y los archivos de configuración que controlan esa compilación. Las herramientas de Chromium y sus dependencias de desarrollo se preparan siguiendo la documentación de construcción incluida en el repositorio Electron de esa revisión.

Podés reemplazar `libffmpeg.so` por una compilación modificada compatible con los símbolos/ABI esperados. Conservá su nombre y respetá las condiciones de licencia de las opciones elegidas. viewrv no añade una firma del desarrollador para cargar esa biblioteca. La función de mantenimiento exige inventarios actualizados si querés instalar una distribución modificada.

## certifi y otros componentes

`sources/certifi-2026.10.23` conserva las fuentes exactas de certifi, incluido el almacén de certificados, su aviso y MPL-2.0. Esos archivos mantienen MPL cuando se redistribuyen o modifican. Para incorporar cambios al core, reconstruir los onedir con `packaging/build_linux.sh --native-only` y las dependencias fijadas, utilizando tu versión modificada del componente. Los archivos originales se pueden consultar directamente sin herramientas de extracción de PyInstaller.

Los componentes permisivos, las fuentes OFL y los iconos conservan sus avisos en el índice. Los recursos recibidos de terceros no se relicencian bajo MIT. Si publicás una descarga de este paquete, entregá juntos binarios, avisos y fuentes; no elimines los archivos de fuentes ni los sustituyas únicamente por un enlace futuro.
