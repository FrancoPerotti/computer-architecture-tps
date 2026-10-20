# Entorno de compilación y simulación de TP3

- **Tipo:** instrucciones de desarrollo.
- **Alcance:** imagen compartida de herramientas de la issue #3.
- **Plataforma:** `linux/amd64` (x86-64).

## Contenido del entorno

El entorno usa Ubuntu 24.04, Icarus Verilog 13.0 (`iverilog` y `vvp`)
y `check-jsonschema` 0.38.2, con Python, Bash y utilidades GNU. Los
desarrolladores usan la misma imagen para compilar, ejecutar simulaciones
y validar la estructura del manifiesto de pruebas.

El [Dockerfile](../docker/Dockerfile) tiene tres etapas sobre la misma base:

| Etapa       | Contenido                                                                                          | Uso                                                                     |
| ----------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `build`     | C/C++, Make, Autoconf, Bison, Flex, Gperf y cabeceras Readline/zlib/bzip2                          | Construir Icarus desde su fuente fijada                                 |
| `validator` | Python, Pip y Venv                                                                                 | Preparar check-jsonschema y sus dependencias verificadas                |
| `runtime`   | Icarus, check-jsonschema, Python, bibliotecas de ejecución, Bash, Coreutils, Findutils, Grep y Sed | Compilar RTL/testbenches, ejecutar simulaciones y validar el manifiesto |

La etapa `runtime` conserva los auxiliares `ivl`/`ivlpp`, targets y módulos
de Icarus. Incluye su licencia y el archivo exacto de fuentes distribuido con
la imagen, bajo `/opt/iverilog/share/`. Los compiladores C/C++ y las herramientas
de construcción quedan en `build`. Los ejecutables y módulos se instalan sin
símbolos de depuración para reducir el tamaño.

La etapa `validator` instala `check-jsonschema` en `/opt/check-jsonschema`,
un entorno virtual que se copia a `runtime`. Pip se utiliza durante su
preparación; el entorno virtual distribuido se crea sin Pip.

## Entradas fijadas

| Entrada                                                                            | Referencia                                                                 |
| ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Ubuntu 24.04, manifiesto `amd64`                                                   | `sha256:a2d43bffc46670d7108bb3c0468c67c5557c4c92e83e1e34cbff1322ad1b94dc`  |
| Ubuntu `noble`, `noble-updates`, `noble-security`, componentes `main` y `universe` | Snapshot `20261018T000000Z`                                                |
| Icarus 13.0, tag de origen `v13_0`                                                 | Commit `dfeee909ed9f20b4870dd93423156c0170c0e1ff`                          |
| Archivo de fuentes de ese commit                                                   | SHA-256 `c3a18398dd25073845550af2f35926193f4d3aa7cd7080122bdc501f59717c00` |
| Certificados iniciales: paquete Ubuntu `ca-certificates_20240203_all.deb`          | SHA-256 `641de77d8f142cfd62a1a6f964ba67b20754d3337c480efb529d086075a06c9a` |
| check-jsonschema 0.38.2 y sus dependencias Python                                  | [Versiones y hashes fijados](../docker/check-jsonschema.requirements.txt)  |

El digest fija el contenido de la base. El
[archivo APT](../docker/ubuntu.sources) fija el conjunto disponible de paquetes
y dependencias, incluidas las transitivas. Se conserva la verificación de
firmas de Ubuntu; se permite consultar metadatos históricos vencidos del
snapshot. Las fuentes de Icarus se descargan por commit y su checksum se
comprueba antes de compilarlas.

Los paquetes de `check-jsonschema` se descargan de PyPI como wheels para
Python 3.12 en `linux/amd64`. El archivo de dependencias fija todas sus
versiones y hashes SHA-256, incluidas las dependencias transitivas. Pip
verifica los hashes y utiliza únicamente paquetes binarios precompilados.
Python y las herramientas de preparación provienen del mismo snapshot APT.

La base mínima carece de certificados CA. Docker descarga por HTTPS el
paquete de certificados iniciales; después de verificarlo, se extrae su
contenido para que APT pueda acceder al snapshot por HTTPS. La primera etapa
instala el paquete normal de certificados desde el mismo snapshot y pasa
su bundle a las otras etapas.

Las versiones instaladas se guardan en:

- `/opt/iverilog/share/tp3-dev/build-packages.txt`.
- `/usr/local/share/tp3-dev/runtime-packages.txt`.
- `/opt/check-jsonschema/share/requirements.txt`.

La receta fija las entradas del entorno. Los metadatos generados durante
la construcción pueden hacer que dos imágenes resultantes difieran byte
a byte.

## Construcción local

Se necesita Docker con su servicio activo y un constructor compatible con
Dockerfiles de varias etapas. La construcción requiere acceso a Docker Hub,
GitHub, PyPI y al snapshot de Ubuntu.

Desde `tp3`:

~~~bash
docker build --platform linux/amd64 --tag tp3-dev:local docker
~~~

Icarus se construye con dos trabajos paralelos. Un cambio en RTL o testbenches
no cambia el contexto `docker/` ni obliga a reconstruir el simulador.
Docker puede conservar las capas de construcción en caché; ese espacio es
independiente del tamaño de la imagen final.

Para consultar herramientas y tamaño:

~~~bash
docker run --rm --network none tp3-dev:local iverilog -V
docker run --rm --network none tp3-dev:local vvp -V
docker run --rm --network none tp3-dev:local check-jsonschema --version
docker image inspect tp3-dev:local --format '{{.Id}} {{.Size}}'
~~~

## Uso con los archivos del proyecto

La imagen contiene herramientas. El RTL y los testbenches se toman del
repositorio montado desde el host.

Desde la raíz del repositorio, en una terminal Bash:

~~~bash
docker run --rm -it --network none \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$PWD,dst=/workspace" \
  tp3-dev:local
~~~

La terminal se abre en `/workspace/tp3`. Las salidas que se generen dentro
del directorio montado permanecen en el host, con el UID/GID del usuario.
El contenedor termina al salir de la terminal.

## Validación del manifiesto

Dentro del contenedor, desde `/workspace/tp3`:

~~~bash
check-jsonschema \
  --schemafile docs/verification/cases.schema.json \
  docs/verification/cases.json
~~~

La herramienta comprueba la sintaxis JSON y su estructura contra el esquema
local. Un archivo inválido produce un diagnóstico y un código de salida
distinto de cero. La validación utiliza archivos locales y funciona sin red.

Para comprobar que el propio esquema esté bien formado:

~~~bash
check-jsonschema --check-metaschema docs/verification/cases.schema.json
~~~

La [guía de ejecución y selección de pruebas](verification/test_selection.md)
describe el uso de `scripts/run_tests.sh` para ejecutar los casos registrados
o inspeccionar la selección con `--list`, con salida legible o JSON.

## Fuentes

- [Construcción de Icarus 13.0](https://github.com/steveicarus/iverilog/blob/v13_0/README.md).
- [Ubuntu Snapshot Service](https://ubuntu.com/server/docs/how-to/software/snapshot-service/).
- [Construcciones de varias etapas](https://docs.docker.com/build/building/multi-stage/).
- [Uso de check-jsonschema](https://check-jsonschema.readthedocs.io/en/latest/usage.html).
