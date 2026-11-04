# Ejecución y selección de pruebas

La entrada [scripts/run_tests.sh](../../scripts/run_tests.sh) delega en
[Python](../../scripts/run_tests.py) la validación del manifiesto, la
selección de grupos y casos y la ejecución con Icarus. El
[coordinador de simulaciones](../../scripts/simulation_runner.py) compila
las fuentes, prepara los datos externos y recoge los resultados.
`--list` permite inspeccionar la selección sin ejecutar pruebas.

El manifiesto define las entradas y los valores esperados de los casos de
hardware; los testbenches SystemVerilog realizan sus aserciones. Python
resuelve la configuración y coordina las herramientas mediante reglas
comunes. Agregar casos con los mecanismos admitidos requiere registrar sus
datos y bancos en el manifiesto, sin agregar lógica específica en Python.

## Uso

Dentro del contenedor, desde `/workspace/tp3`:

~~~bash
bash scripts/run_tests.sh --help
~~~

Para solicitar la ejecución de un grupo:

~~~bash
bash scripts/run_tests.sh --test TEST-PLAT-001
~~~

Cada caso del catálogo declara `status`: `implemented` indica que su testbench
está implementado y registrado; `pending`, que todavía no lo está. El estado no
expresa aprobación ni avance de validación física. Un caso implementado debe tener
al menos una ejecución aplicable y sus fuentes disponibles; una inconsistencia
produce error, sin retirarlo silenciosamente de la selección.

Para comprobar la API de perfiles compartidos:

~~~bash
bash scripts/run_tests.sh \
  --test TEST-PLAT-001/C001 \
  --test TEST-PLAT-001/C002 \
  --test TEST-PLAT-001/C014
~~~

Estas ejecuciones comprueban la API al nivel `Unidad`, con el
[alcance descrito en configuración común](../architecture/common_configuration.md#comprobación-rtl-del-paquete).

Para comprobar el árbitro combinacional:

~~~bash
bash scripts/run_tests.sh --test TEST-PIPE-007
~~~

El grupo ejecuta el árbitro al nivel `Unidad` y su composición con los cuatro
registros al nivel `Integración local`. La [especificación](pipeline.md#test-pipe-007)
delimita el PC de fixture y las comprobaciones pendientes en processor_top/CPU.
Los grupos TEST-PIPE-001, 008 y 009 agregan las proyecciones locales que figuran
en la [tabla de acreditación](pipeline.md#acreditacion-local-7).

Para listar un grupo completo:

~~~bash
bash scripts/run_tests.sh --test TEST-PIPE-001 --list
~~~

Para combinar grupos y casos individuales:

~~~bash
bash scripts/run_tests.sh \
  --test TEST-PLAT-001/C003 \
  --test TEST-PIPE-001 \
  --test TEST-MEM-001 \
  --list
~~~

`--test` es repetible y es mutuamente excluyente con `--all`. `--all` ejecuta
todos los casos implementados e informa los pendientes. Seleccionar un grupo
aplica el mismo criterio. Pedir individualmente un caso pendiente es un error.
Una selección de ejecución sin casos implementados también produce error;
`--list` permite consultar pendientes y selecciones vacías sin simular.

El comando conserva el orden de la primera aparición y elimina las
repeticiones dentro del mismo grupo de ejecución. Las referencias
`reuse_groups` describen relaciones documentales; no agregan pruebas ni
funcionan como dependencias de ejecución.

`replay_cases` conserva referencias de aceptación física en placa. Estas
referencias no se expanden como simulaciones adicionales. Seleccionar directamente
un ID de caso utiliza su grupo canónico.

## Salida para personas y agentes

Durante la ejecución, la salida predeterminada informa `PASS`, `FAIL` o
`ERROR` por caso y configuración, con el módulo principal y el nivel de
verificación. Al terminar muestra los contadores de ejecuciones y, por separado, la cantidad de casos pendientes. El progreso y los
diagnósticos se escriben por `stderr`.

`--format json` devuelve un único
[documento de resultados](results.schema.json) por `stdout`. Cada fila
corresponde a un caso y una configuración de ejecución. El estado global es
`error` si hay errores, `failed` si hay fallos sin errores y `passed` si
todas las filas están aprobadas. `pending_cases` contiene los IDs pendientes de
la selección; no genera filas de resultado ni incrementa los contadores de
`summary`. Una ejecución sin resultados no se aprueba.

Con `--list`, la salida muestra cada ID, su grupo, su `status` y la cantidad
de configuraciones registradas, seguida por la cantidad de casos
seleccionados. Indica expresamente que no se ejecutaron.

Para obtener una selección estructurada:

~~~bash
bash scripts/run_tests.sh \
  --test TEST-PLAT-001/C003 \
  --list --format json
~~~

La salida estándar contiene un único array JSON:

~~~json
[
  {
    "group_id": "TEST-PLAT-001",
    "case_id": "TEST-PLAT-001/C003",
    "status": "implemented",
    "execution_count": 1
  }
]
~~~

`execution_count` cuenta las configuraciones aplicables al caso; no representa
pruebas ejecutadas. La lista de selección es distinta del
[documento de resultados](results.schema.json).

Una selección inválida no produce una lista parcial. Con `--list --format
json`, un error devuelve `[]`, un diagnóstico por `stderr` y un código
distinto de cero. Para `--help` se muestra la ayuda legible.

## Comandos comunes y reportes

La interfaz común local y de CI es `make check`, desde `tp3` dentro del contenedor.
También se pueden ejecutar los bloques por separado:

~~~bash
make validate
make test-infra
make test-rtl
make test-rtl TESTS="TEST-PLAT-001/C003 TEST-PIPE-001"
~~~

`make validate` comprueba los dos metaschemas, el catálogo y la coherencia de IDs,
estados, parámetros y fuentes de todos los casos implementados. No compila ni
simula. Su equivalente de CLI es `python3 scripts/run_tests.py --validate` para
catálogo y coherencia, más la comprobación de metaschemas con `check-jsonschema`.

`make test-infra` guarda `build/reports/infrastructure.log`. `make test-rtl`
guarda `results.json`, `simulation.log` y los diagnósticos por compilación/caso
en `build/reports/simulation/`. Esos archivos son generados y no se versionan.

## Validaciones y códigos de salida

La carga común del manifiesto invoca `check-jsonschema` para comprobar su
estructura. Además, comprueba claves JSON repetidas, IDs únicos, pertenencia
de cada caso a su grupo, coincidencia de `case_count` y existencia de las
referencias a grupos y casos.

Al ejecutar, el comando exige configuraciones de ejecución para todos los
casos implementados seleccionados y comprueba que las fuentes aplicables existan, relativas a `tp3`.
La ejecución por Icarus admite los niveles `Unidad`, `Integración local`,
`CPU` y `Sistema`. Los niveles `Elaboración/revisión`, `Implementación` y
`Placa` se rechazan: una simulación no acredita esas comprobaciones.

Los errores globales anteriores a las pruebas producen, con `--format
json`, un documento con `status: "error"`, contadores en cero y `results:
[]`, además de `pending_cases: []`. El motivo se escribe por `stderr`. Los contadores en cero indican que
no se ejecutaron pruebas; el estado global y el código de salida indican
el error.

- `0`: todas las pruebas solicitadas aprobadas, o ayuda/listado/validación válidos.
- `1`: al menos una prueba fallida o con error, o un error global.
- `2`: argumentos de CLI inválidos.
- `130`: interrupción de la ejecución.

`--manifest <ruta>` permite consultar otro manifiesto con el mismo esquema.
El manifiesto predeterminado y las fuentes del proyecto se ubican desde el
script; el comando también funciona desde otro directorio de trabajo.

## Compilación y simulación

Cada configuración de parámetros de una entrada de `executions` se compila
una vez por invocación, con
`iverilog -g2012`, el `top` solicitado y los archivos de `sources` en el
orden declarado. La compilación se realiza desde `tp3`; las rutas de
las fuentes se resuelven respecto de ese directorio.

`case_ids` limita una ejecución a los casos indicados del grupo. Si se omite,
se aplica a todos sus casos implementados. Los casos sin ejecución
aplicable se detectan antes de compilar.

`parameters` permite fijar parámetros de elaboración. Un valor puede ser
un literal entero de SystemVerilog, un identificador (incluidas constantes
de paquete como `system_pkg::ALT_1000`) o una referencia a una entrada
entera del caso:

~~~json
{
  "parameters": {
    "CHECK_CAPACITY": "1",
    "CAPACITY_BYTES": {"input": "C"}
  }
}
~~~

`{"input": "C"}` toma `inputs.C` antes de compilar y lo convierte en un
literal de al menos 64 bits, ampliado si el entero lo requiere. Una clave
ausente o un valor que no sea entero produce un error de validación.
Así, el valor que determina la elaboración y el que recibe el banco
proceden de la misma entrada.

El ejecutor genera una instancia temporal del `top` con esas conexiones.
Cada entrada conserva sus compilaciones por parámetros resueltos: casos
con los mismos valores reutilizan el ejecutable y valores diferentes se
compilan por separado.

Para cada caso, Python prepara sus datos desde el manifiesto ya validado y
ejecuta `vvp` con `+CASE=<id>` y `+CASE_DATA=<archivo>`. El
[formato de datos externos](case_data.md) conserva las entradas,
expectativas y el fixture compartido.

El testbench informa una única línea de protocolo por `stdout`:

- `PASS <ID>`, acompañado por código de salida `0`.
- `FAIL <ID> <explicación>`, acompañado por código de salida distinto de cero.
- `REJECT <ID> <diagnóstico>`, solo para ejecuciones con `expected_rejection`.

Para un rechazo esperado, `expected_rejection.exit_code` indica el código
positivo exigido y `diagnostic_key` identifica la clave de `expected`
que contiene el diagnóstico. El rechazo se aprueba solo si coinciden los
tres datos: ID, diagnóstico y código de salida. Un `PASS` con código cero
cuando se esperaba rechazo es un fallo. Un diagnóstico diferente es un
fallo; un código inesperado o un rechazo sin expectativa registrada es un
error. Un error de compilación, un timeout o un `$fatal` sin resultado
explícito nunca acreditan un rechazo esperado.

El ID debe coincidir con el solicitado. La ausencia de resultado, los
resultados múltiples, un ID ajeno, un `PASS` con salida distinta de cero o
un `FAIL` con salida cero producen `error`. Las líneas de diagnóstico que
no empiezan con `PASS`, `FAIL` o `REJECT` no se interpretan como resultados.

`timeout_seconds` limita el tiempo real de cada simulación; no limita la
compilación. Al vencer, se termina el proceso y sus hijos, y se informa
`error`. Un fallo de compilación se registra como `error` para los casos
afectados. El comando continúa con los demás casos y configuraciones.

Cada invocación usa un directorio temporal propio. La simulación se ejecuta
dentro de un subdirectorio por caso para aislar sus archivos de salida.
Datos, ejecutables y archivos intermedios se eliminan al terminar. Con
`--reports-dir <ruta>` se conservan copias de stdout/stderr de compilación y
simulación, incluso al interrumpirse una ejecución. Los diagnósticos del compilador, el `stderr` de
la simulación y el `stdout` de los casos fallidos o con errores se envían
por `stderr` del ejecutor.

## Comprobaciones de la herramienta

~~~bash
python3 -m unittest discover -s scripts/tests -v
~~~

Las pruebas comprueban selección mixta, estados de implementación, deduplicación, orden, referencias físicas,
errores de coherencia, argumentos inválidos y las salidas de la CLI. Los
smoke tests usan Icarus real para recorrer el flujo completo y provocar
éxito, fallo, timeout, error de compilación y errores de protocolo.

El código de estas comprobaciones y sus fixtures se conserva bajo
`scripts/tests/`. Sus manifiestos y archivos generados se crean en
directorios temporales y se eliminan al terminar. Los casos del smoke test
pertenecen a esos manifiestos temporales y no se registran como pruebas
del hardware en el catálogo del proyecto.
