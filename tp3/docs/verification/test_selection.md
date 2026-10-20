# Ejecución y selección de pruebas

La entrada [scripts/run_tests.sh](../../scripts/run_tests.sh) delega en
[Python](../../scripts/run_tests.py) la validación del manifiesto, la
selección de grupos y casos y la ejecución con Icarus. El
[coordinador de simulaciones](../../scripts/simulation_runner.py) compila
las fuentes, prepara los datos externos y recoge los resultados.
`--list` permite inspeccionar la selección sin ejecutar pruebas.

## Uso

Dentro del contenedor, desde `/workspace/tp3`:

~~~bash
bash scripts/run_tests.sh --help
~~~

Para solicitar la ejecución de un grupo:

~~~bash
bash scripts/run_tests.sh --test TEST-PIPE-001
~~~

Cada grupo seleccionado debe tener sus testbenches registrados en
`executions`. Una lista vacía produce un error, sin informar aprobaciones.

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

`--test` es repetible. `--all` selecciona todos los grupos y es mutuamente
excluyente con `--test`. Cada selección debe contener al menos un caso.

El comando conserva el orden de la primera aparición y elimina las
repeticiones dentro del mismo grupo de ejecución. Las referencias
`reuse_groups` describen relaciones documentales; no agregan pruebas ni
funcionan como dependencias de ejecución.

Los IDs de `replay_cases` se expanden dentro del grupo que solicita la
reejecución. Un caso canónico y su reejecución de placa conservan contextos
distintos; repetir el selector del mismo grupo no duplica sus casos.
Seleccionar directamente un ID de caso utiliza su grupo canónico.

## Salida para personas y agentes

Durante la ejecución, la salida predeterminada informa `PASS`, `FAIL` o
`ERROR` por caso y configuración, con el módulo principal y el nivel de
verificación. Al terminar muestra los contadores. El progreso y los
diagnósticos se escriben por `stderr`.

`--format json` devuelve un único
[documento de resultados](results.schema.json) por `stdout`. Cada fila
corresponde a un caso y una configuración de ejecución. El estado global es
`error` si hay errores, `failed` si hay fallos sin errores y `passed` si
todas las filas están aprobadas. Una ejecución sin resultados no se aprueba.

Con `--list`, la salida muestra cada ID, su grupo de ejecución y la cantidad
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
    "execution_count": 0
  }
]
~~~

`execution_count` cuenta las configuraciones declaradas; no representa
pruebas ejecutadas. La lista de selección es distinta del
[documento de resultados](results.schema.json).

Una selección inválida no produce una lista parcial. Con `--list --format
json`, un error devuelve `[]`, un diagnóstico por `stderr` y un código
distinto de cero. Para `--help` se muestra la ayuda legible.

## Validaciones y códigos de salida

La carga común del manifiesto invoca `check-jsonschema` para comprobar su
estructura. Además, comprueba claves JSON repetidas, IDs únicos, pertenencia
de cada caso a su grupo, coincidencia de `case_count` y existencia de las
referencias a grupos y casos.

Sin `--list`, el comando exige configuraciones de ejecución para todos los
grupos seleccionados y comprueba que sus fuentes existan, relativas a `tp3`.
La ejecución por Icarus admite los niveles `Unidad`, `Integración local`,
`CPU` y `Sistema`. Los niveles `Elaboración/revisión`, `Implementación` y
`Placa` se rechazan: una simulación no acredita esas comprobaciones.

Los errores globales anteriores a las pruebas producen, con `--format
json`, un documento con `status: "error"`, contadores en cero y `results:
[]`. El motivo se escribe por `stderr`. Los contadores en cero indican que
no se ejecutaron pruebas; el estado global y el código de salida indican
el error.

- `0`: todas las pruebas solicitadas aprobadas, o ayuda/listado válidos.
- `1`: al menos una prueba fallida o con error, o un error global.
- `2`: argumentos de CLI inválidos.
- `130`: interrupción de la ejecución.

`--manifest <ruta>` permite consultar otro manifiesto con el mismo esquema.
El manifiesto predeterminado y las fuentes del proyecto se ubican desde el
script; el comando también funciona desde otro directorio de trabajo.

## Compilación y simulación

Cada entrada de `executions` se compila una vez por invocación, con
`iverilog -g2012`, el `top` solicitado y los archivos de `sources` en el
orden declarado. La compilación se realiza desde `tp3`; las rutas de
las fuentes se resuelven respecto de ese directorio.

Para cada caso, Python prepara sus datos desde el manifiesto ya validado y
ejecuta `vvp` con `+CASE=<id>` y `+CASE_DATA=<archivo>`. El
[formato de datos externos](case_data.md) conserva las entradas,
expectativas y el fixture compartido.

El testbench informa una única línea de protocolo por `stdout`:

- `PASS <ID>`, acompañado por código de salida `0`.
- `FAIL <ID> <explicación>`, acompañado por código de salida distinto de cero.

El ID debe coincidir con el solicitado. La ausencia de resultado, los
resultados múltiples, un ID ajeno, un `PASS` con salida distinta de cero o
un `FAIL` con salida cero producen `error`. Las líneas de diagnóstico que
no empiezan con `PASS` o `FAIL` no se interpretan como resultados.

`timeout_seconds` limita el tiempo real de cada simulación; no limita la
compilación. Al vencer, se termina el proceso y sus hijos, y se informa
`error`. Un fallo de compilación se registra como `error` para los casos
afectados. El comando continúa con los demás casos y configuraciones.

Cada invocación usa un directorio temporal propio. La simulación se ejecuta
dentro de un subdirectorio por caso para aislar sus archivos de salida.
Datos, ejecutables, salidas de herramientas y demás archivos de simulación
se eliminan al terminar. Los diagnósticos del compilador, el `stderr` de
la simulación y el `stdout` de los casos fallidos o con errores se envían
por `stderr` del ejecutor.

## Comprobaciones de la herramienta

~~~bash
python3 -m unittest discover -s scripts/tests -v
~~~

Las pruebas comprueban selección mixta, deduplicación, orden, reejecuciones,
errores de coherencia, argumentos inválidos y las salidas de la CLI. Los
smoke tests usan Icarus real para recorrer el flujo completo y provocar
éxito, fallo, timeout, error de compilación y errores de protocolo.

El código de estas comprobaciones y sus fixtures se conserva bajo
`scripts/tests/`. Sus manifiestos y archivos generados se crean en
directorios temporales y se eliminan al terminar. Los casos del smoke test
pertenecen a esos manifiestos temporales y no se registran como pruebas
del hardware en el catálogo del proyecto.
