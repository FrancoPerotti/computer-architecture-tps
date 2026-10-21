# Entorno de compilación y simulación de TP3

- **Tipo:** instrucciones de desarrollo.
- **Alcance:** imagen compartida de herramientas de la issue #3.
- **Plataforma:** `linux/amd64` (x86-64).

## Contenido del entorno

El entorno usa Ubuntu 24.04 para `linux/amd64`. Los desarrolladores y CI
compilan, simulan y comprueban las fuentes con las mismas herramientas:

| Herramienta          | Versión             | Responsabilidad                            |
| -------------------- | ------------------- | ------------------------------------------ |
| Icarus Verilog / VVP | 13.0                | Compilación y simulación SystemVerilog     |
| check-jsonschema     | 0.38.2              | Esquemas JSON y estructura del catálogo    |
| GNU Make             | 4.3                 | Interfaz común de comprobaciones           |
| Verible              | v0.0-4296-g0f262651 | Lint y formato SystemVerilog               |
| Verilator            | 5.020               | Análisis técnico del RTL con `--lint-only` |
| Ruff                 | 0.17.1              | Lint, docstrings y formato Python          |
| ShellCheck           | 0.9.0               | Análisis de scripts Bash                   |
| shfmt                | 3.8.0               | Formato Bash                               |

Python 3.12, Bash y utilidades GNU completan el entorno.
El [Dockerfile](../docker/Dockerfile) tiene cuatro etapas sobre la misma base:

| Etapa       | Contenido                                                  | Uso                                                      |
| ----------- | ---------------------------------------------------------- | -------------------------------------------------------- |
| `build`     | Compiladores y dependencias de construcción                | Construir Icarus desde su fuente fijada                  |
| `validator` | Python, Pip y Venv                                         | Preparar check-jsonschema y sus dependencias verificadas |
| `quality`   | Archivos oficiales de Verible y Ruff                       | Verificar hashes y preparar ejecutables/licencias        |
| `runtime`   | Herramientas de desarrollo y sus dependencias de ejecución | Ejecutar los comandos de Make                            |

La etapa `runtime` conserva los auxiliares `ivl`/`ivlpp`, targets y módulos
de Icarus. Incluye su licencia y el archivo exacto de fuentes distribuido con
la imagen, bajo `/opt/iverilog/share/`. Los compiladores C/C++ y las dependencias
de construcción de Icarus quedan en `build`; Make también está disponible en `runtime`. Los ejecutables y módulos se instalan sin
símbolos de depuración para reducir el tamaño.

La etapa `validator` instala `check-jsonschema` en `/opt/check-jsonschema`,
un entorno virtual que se copia a `runtime`. Pip se utiliza durante su
preparación; el entorno virtual distribuido se crea sin Pip.

Los ejecutables de Verible y Ruff se instalan en `/opt/quality/bin` y sus
licencias en `/opt/quality/share/licenses`. Se copian únicamente las herramientas
de lint y formato de Verible. Verilator se instala sin las recomendaciones
opcionales de APT; `make lint` no compila modelos C++.

## Entradas fijadas

| Entrada                                                                            | Referencia                                                                 |
| ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Ubuntu 24.04, manifiesto `amd64`                                                   | `sha256:a2d43bffc46670d7108bb3c0468c67c5557c4c92e83e1e34cbff1322ad1b94dc`  |
| Ubuntu `noble`, `noble-updates`, `noble-security`, componentes `main` y `universe` | Snapshot `20261018T000000Z`                                                |
| Icarus 13.0, tag de origen `v13_0`                                                 | Commit `dfeee909ed9f20b4870dd93423156c0170c0e1ff`                          |
| Archivo de fuentes de ese commit                                                   | SHA-256 `c3a18398dd25073845550af2f35926193f4d3aa7cd7080122bdc501f59717c00` |
| Certificados iniciales: paquete Ubuntu `ca-certificates_20240203_all.deb`          | SHA-256 `641de77d8f142cfd62a1a6f964ba67b20754d3337c480efb529d086075a06c9a` |
| check-jsonschema 0.38.2 y sus dependencias Python                                  | [Versiones y hashes fijados](../docker/check-jsonschema.requirements.txt)  |

Make `4.3-4.1build2`, Verilator `5.020-1`, ShellCheck `0.9.0-1` y shfmt
`3.8.0-1` provienen del mismo snapshot firmado. Verible y Ruff provienen de sus
releases oficiales, con versión y SHA-256 de archivos y licencias fijados en el
Dockerfile. Las configuraciones de lint y formato se toman del repositorio montado.

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

## Imagen compartida

La candidata `v0.1.0-rc.1` está disponible en el paquete público
[tp3-dev de GitHub Container Registry](https://github.com/FrancoPerotti/computer-architecture-tps/pkgs/container/tp3-dev).
Los desarrolladores pueden descargarla sin autenticarse ni construir las herramientas.

La referencia exacta se conserva únicamente en
[`docker/image.ref`](../docker/image.ref). Ese archivo fija el digest del
contenido publicado; los comandos lo leen para utilizar la misma imagen aunque
una etiqueta del registro cambie.

Desde la raíz del repositorio, en una terminal Bash:

~~~bash
TP3_IMAGE="$(cat tp3/docker/image.ref)"
docker pull "$TP3_IMAGE"
docker run --rm --network none \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$PWD,dst=/workspace" \
  "$TP3_IMAGE" make check
~~~

La descarga requiere acceso al registro; las comprobaciones se ejecutan sin red.
La imagen compartida contiene las herramientas y utiliza las reglas, fuentes y
pruebas del repositorio montado. La referencia no reemplaza la receta de
construcción ni acredita la validación de otros bloques del proyecto.

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
repositorio montado desde el host. Después de descargar la imagen compartida,
se puede abrir una terminal interactiva con la misma referencia fijada.

Desde la raíz del repositorio, en una terminal Bash:

~~~bash
TP3_IMAGE="$(cat tp3/docker/image.ref)"
docker run --rm -it --network none \
  --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$PWD,dst=/workspace" \
  "$TP3_IMAGE"
~~~

La terminal se abre en `/workspace/tp3`. Las salidas que se generen dentro
del directorio montado permanecen en el host, con el UID/GID del usuario.
El contenedor termina al salir de la terminal.

Para utilizar una construcción propia, se sustituye la referencia por
`tp3-dev:local`. La distribución compartida conserva el digest de `image.ref`.

## Comprobaciones locales

Dentro del contenedor, desde `/workspace/tp3`:

~~~bash
make help
make check
~~~

`make check` comprueba formato, lint, esquemas y catálogo, infraestructura y todos
los casos de simulación implementados. No modifica fuentes. Para aplicar el formato
explícitamente se usa `make format`. También están disponibles `format-check`,
`lint`, `validate`, `test-infra`, `test-rtl` y `test`.

El formato y lint abarcan fuentes propias bajo `rtl/`, `tb/` y `scripts/`, incluidos
fixtures. Verilator analiza exclusivamente el RTL y sus dependencias ordenadas en
Make, actualmente `rtl/system_pkg.sv` y `rtl/if_id_register.sv`. El catálogo de pruebas conserva sus bancos
y fuentes de simulación; no define el alcance de lint RTL.

Ruff comprueba errores básicos, imports y presencia/formato básico de docstrings.
La exigencia de documentar también funciones privadas y anidadas se revisa donde
Ruff no la cubre. Bash utiliza ShellCheck y shfmt; sus comentarios se revisan sin
un validador de documentación adicional. Las reglas están en `ruff.toml`,
`.rules.verible_lint` y `.verible-format-flags`. Las excepciones son locales y
justificadas junto a la construcción correspondiente.

La [guía de pruebas](verification/test_selection.md) describe selección, estados,
CLI JSON y reportes en `build/reports/`. Las convenciones de escritura de RTL se
encuentran en la [guía de estilo del repositorio](../../docs/code-style.md#alcance-de-tp3).

## GitHub Actions

El [workflow de TP3](../../.github/workflows/tp3.yml) se activa para PR dirigidos a
`feature/tp3-riscv-pipeline`, pushes a `feature/tp3-*` excepto esa rama destino y
ejecuciones manuales. Las ejecuciones manuales siempre realizan el control completo.
GitHub [exige que el workflow esté en la rama predeterminada](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
para habilitar `workflow_dispatch`; declararlo en una rama de trabajo por sí solo
no habilita el botón de ejecución manual.

Un análisis ligero omite la construcción y pruebas ante cambios exclusivamente
narrativos o de TP1/TP2 sin dependencias directas de TP3. Catálogo, esquemas, fuentes,
configuraciones, contexto Docker y workflow son entradas ejecutables. Las rutas desconocidas
ejecutan el control completo. Los renombres consideran las rutas vieja y nueva.
Si no puede determinarse el rango de cambios, se comprueba todo por precaución.

Cuando existe un PR abierto hacia la rama destino para el mismo commit de un push,
el push informa que delegó la comprobación al PR. Una consulta de metadatos fallida
conserva la comprobación del push. Los eventos PR y push tienen grupos de cancelación
y nombres de resultado separados; un push no sustituye el resultado `TP3 PR`.

Cuando aplica, CI selecciona cómo obtener las herramientas antes de ejecutar
`make check` sin red:

- Si cambian RTL, testbenches, catálogo, scripts, reglas o workflow, y la definición
  de herramientas permanece igual a la publicada, descarga la referencia exacta
  de `docker/image.ref`. No prepara Buildx ni reconstruye la imagen.
- Si cambia el contexto `tp3/docker/`, salvo `image.ref`, construye y verifica el
  Dockerfile del checkout con caché de BuildKit. Los archivos nuevos, eliminados
  o renombrados del contexto también cuentan como cambios de herramientas.
- Si solo cambia `image.ref`, descarga y verifica la nueva referencia. El archivo
  debe ser regular y contener una única referencia al paquete acordado fijada por
  digest; las etiquetas, referencias inválidas y archivos ausentes producen error.
- Las ejecuciones manuales reconstruyen y verifican las herramientas. Si no se
  puede determinar con seguridad la procedencia o el rango, se reconstruye por
  precaución y se deja el motivo visible.

La clasificación de una PR considera el diff completo desde el ancestro común,
no solo su último commit. La selección de herramientas también compara la receta
con el commit que registró la referencia publicada: un push de RTL posterior a
un cambio de herramientas todavía no publicado conserva la reconstrucción.
Actualizar `image.ref` después de modificar herramientas dentro de la misma PR
no elimina la obligación de verificar esa receta.

Cuando la rama destino todavía no contiene `image.ref`, se utiliza su primera
incorporación en el historial como frontera de herramientas ya publicadas. La
comparación sigue incluyendo todos los cambios posteriores de la PR; una historia
ambigua fuerza la reconstrucción. Esto permite reutilizar una entrega publicada
que todavía espera integración en la rama destino.

La referencia publicada no sustituye el análisis del checkout ni genera un PASS
por sí sola. Un fallo de descarga o construcción detiene los controles, sin
cambiar de imagen como alternativa. El reporte `image-source.json` registra el
modo, la referencia y el motivo de selección; se conservan también los logs de
la descarga cuando corresponda. El job tiene un límite de duración y la fase de
comprobaciones un límite adicional que también contiene una compilación detenida.

Los informes y logs se conservan como artifacts incluso al fallar. El resultado
final distingue controles satisfactorios, cambio no aplicable y errores; un fallo
de clasificación o del entorno no se presenta como aprobación. Las acciones se
fijan por commit y el workflow utiliza permisos de lectura, sin publicar imágenes.

## Fuentes

- [Construcción de Icarus 13.0](https://github.com/steveicarus/iverilog/blob/v13_0/README.md).
- [Ubuntu Snapshot Service](https://ubuntu.com/server/docs/how-to/software/snapshot-service/).
- [Construcciones de varias etapas](https://docs.docker.com/build/building/multi-stage/).
- [Uso de check-jsonschema](https://check-jsonschema.readthedocs.io/en/latest/usage.html).
- [Verible](https://chipsalliance.github.io/verible/).
- [Verilator](https://verilator.org/guide/latest/).
- [Ruff](https://docs.astral.sh/ruff/).
