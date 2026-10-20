# Datos externos para los testbenches

El [preparador de casos](../../scripts/prepare_case.py) toma las entradas y
expectativas del [manifiesto](cases.json) y genera un archivo que consume el
[lector SystemVerilog](../../tb/common/tp3_case_data.sv). El JSON conserva los
valores de referencia; el archivo generado se reemplaza al preparar el caso.
El testbench contiene la lógica para aplicar las entradas y comprobar el
comportamiento.

## Preparación

Dentro del contenedor, desde `/workspace/tp3`:

~~~bash
python3 scripts/prepare_case.py \
  --case TEST-PLAT-001/C008 \
  --output build/case-data/case.data
~~~

El preparador invoca `check-jsonschema` antes de leer el manifiesto y exige
un ID de caso completo y único. `--manifest` permite indicar otro manifiesto
con el mismo esquema. Un error produce un diagnóstico en la salida de
errores y un código distinto de cero. La preparación fallida conserva el
archivo de salida anterior, si existe.

Los datos preparados incluyen `id`, `inputs`, `expected` y el fixture
compartido `latch_fixture`. La exportación conserva los tipos JSON y el
orden de las listas. Las claves de los objetos se ordenan para producir el
mismo archivo a partir de los mismos datos.

## Lectura en SystemVerilog

El archivo `tb/common/tp3_case_data.sv` se compila junto con el testbench. Este
instancia el lector y llama a `load()` antes de consultar los datos:

~~~systemverilog
tp3_case_data data();
longint signed capacity;
longint signed expected_width;

initial begin
    data.load();
    capacity = data.get_integer("/inputs/C");
    expected_width = data.get_integer("/expected/CAPACITY_INCLUSIVE_WIDTH");
end
~~~

La simulación recibe `+CASE=<id-completo>` y `+CASE_DATA=<archivo-generado>`.
El lector comprueba que el ID del archivo coincida con el solicitado. Una
ruta ausente, un tipo incorrecto o un archivo ilegible o mal formado
terminan la simulación mediante `$fatal(1, ...)`.

Las rutas usan JSON Pointer: `/inputs/items/0` identifica el primer elemento
de una lista. En las claves, `~1` representa `/` y `~0` representa `~`.

Los accesos disponibles son:

- `get_integer(path)`: entero con signo de 64 bits; rechaza desbordamientos.
- `get_boolean(path)`: booleano.
- `get_real(path)`: número real.
- `get_string(path)`: cadena, incluidos espacios, saltos de línea y UTF-8.
- `is_null(path)`: indica si el valor es `null`.
- `get_size(path)`: cantidad de elementos de un objeto o lista.
- `get_type(path)` y `get_text(path)`: tipo y representación textual.

Los enteros se transportan como texto decimal sin truncamiento; los que
exceden el rango del acceso de 64 bits se pueden consultar con `get_text`.
Las cadenas que representan hexadecimal o estados `X`/`Z` conservan su texto;
su interpretación corresponde al testbench. Las cadenas con caracteres NUL,
los sustitutos Unicode aislados y los números no finitos se rechazan.

Este intercambio entrega datos durante la simulación. Los parámetros que
definen anchos o capacidades durante la elaboración se fijan al compilar.
Una expectativa escrita como descripción conserva su texto: la exportación
no la convierte en una expresión ejecutable.

## Representación del archivo generado

La primera línea contiene `TP3_CASE_DATA` y la cantidad de registros. Cada
registro contiene tres tokens separados por espacios: ruta, tipo y valor.
Las rutas y los valores se codifican como bytes UTF-8 en hexadecimal; `-`
representa una cadena vacía. Así, los espacios y saltos de línea de los
datos no alteran la separación de registros.

Los tipos son `object`, `array`, `string`, `integer`, `real`, `boolean` y
`null`. Los objetos y listas contienen su cantidad de elementos; los
booleanos usan `true` o `false`; `null` tiene un valor vacío. Se incluye un
registro para la raíz y para cada nodo del árbol. El lector admite hasta
65536 registros por archivo, configurable mediante `MAX_RECORDS`.

## Comprobación del intercambio

~~~bash
python3 -m unittest discover -s scripts/tests -v
~~~

Estas pruebas utilizan Icarus para comprobar la lectura de valores, los
errores y una comparación cuyo resultado esperado proviene del JSON.
También comprueban la conservación de los datos del catálogo al exportarlos
y reconstruirlos. El fixture de simulación informa `CASE_DATA_OK`: su
resultado verifica el intercambio de datos, sin acreditar el comportamiento
del hardware del catálogo.
