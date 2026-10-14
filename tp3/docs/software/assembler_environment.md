# Entorno e importación del assembler

- **Tipo:** diseño de software.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Intérprete y versión mínima](#intérprete-y-versión-mínima)
- [Dependencias](#dependencias)
- [Ubicación e importación](#ubicación-e-importación)
- [Ejecución de las pruebas](#ejecución-de-las-pruebas)
- [Comprobaciones de compatibilidad](#comprobaciones-de-compatibilidad)
- [Estado de diseño](#estado-de-diseño)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

## Propósito y alcance

El assembler utiliza Python y su biblioteca estándar, conforme al [acuerdo de implementación](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--lenguaje-de-implementación). Este documento define el intérprete mínimo, la ruta de importación y el mecanismo de ejecución del catálogo aprobado.

El contrato concreta el uso del módulo previsto por [Organización y operación](assembler_organization.md). La selección de interfaz de usuario y las dependencias de transporte conservan su decisión independiente en [DEC-SYS-008](../decisions/pending_decisions.md#dec-sys-008--formato-de-la-aplicación-de-pc).

## Intérprete y versión mínima

| Aspecto                  | Contrato                                                                            |
|--------------------------|-------------------------------------------------------------------------------------|
| Intérprete de referencia | CPython.                                                                            |
| Versión mínima           | Python 3.11.                                                                        |
| Versiones posteriores    | Versiones estables de Python 3.x compatibles con las APIs utilizadas.               |
| Versión de parche        | No se fija una versión de parche particular; se registra la utilizada al verificar. |

La implementación utiliza sintaxis y APIs disponibles en Python 3.11, incluidos dataclasses, tipos como `list[str]` y la representación de ausencia mediante `int | None`. La elección permite conservar las estructuras aprobadas con una base mantenida y sin requerir funciones recientes del intérprete.

**Referencia de mantenimiento — 2026-10-14:** Python 3.11 es la versión más antigua todavía mantenida en la [lista oficial de versiones](https://devguide.python.org/versions/), con fin de soporte previsto para octubre de 2027. Esta fecha fundamenta la elección inicial; no sustituye la comprobación del catálogo sobre la versión utilizada.

El entorno consultado dispone de CPython 3.14.8 mediante `python3`. Cumple el mínimo aprobado. Este dato acredita la disponibilidad del intérprete, no una implementación del assembler ni una regresión ejecutada.

## Dependencias

| Uso                     | Recursos                                            |
|-------------------------|-----------------------------------------------------|
| Traducción              | Biblioteca estándar de Python y tipos incorporados. |
| Registros de datos      | `dataclasses`.                                      |
| Reconocimiento de texto | Operaciones de `str` y `re` cuando corresponde.     |
| Regresión del catálogo  | `unittest`, incluido en la biblioteca estándar.     |

El assembler y sus pruebas no requieren instalar paquetes mediante `pip`. Un entorno virtual puede utilizarse para organizar el desarrollo de la aplicación, pero no es requisito de esta capa. Las dependencias de otras capas se fijan al diseñarlas.

Los resultados esperados de [Pruebas del assembler](assembler_tests.md) permanecen como datos fijos. Clang se utilizó para revisar constantes; no se invoca para traducir programas del usuario ni para calcular expectativas durante la regresión.

## Ubicación e importación

La disposición prevista es:

```text
tp3/
└── software/
    ├── __init__.py
    ├── assembler.py
    └── tests/
        ├── __init__.py
        └── test_assembler.py
```

`software/assembler.py` contiene las clases, tablas y funciones del assembler. Los archivos `__init__.py` son marcadores vacíos que identifican `software` y `software.tests` como paquetes regulares de Python. El código de pruebas pertenece a `software/tests/test_assembler.py`.

La aplicación y las pruebas utilizan el nombre completo del módulo:

```python
from software.assembler import assemble, AssemblyResult, AssemblyDiagnostic
```

La base de ejecución es el directorio `tp3`, que contiene `software`. Al invocar Python desde allí mediante `-m` o en una sesión interactiva, ese directorio forma parte de su búsqueda normal de módulos. El TP utiliza esa disposición directamente desde el checkout; no exige instalar el assembler como un paquete distribuible ni agregar modificaciones de `sys.path` dentro del módulo.

Importar el módulo define las clases, tablas y funciones. El ensamblado comienza cuando la aplicación llama a `assemble`. La importación no carga un archivo de programa ni inicia comunicación con la FPGA.

## Ejecución de las pruebas

El catálogo se implementa mediante `unittest`, conservando sus ocho grupos y 101 variantes. Las tablas de variantes pueden compartir el mecanismo de invocación y comparación previsto por el catálogo; la elección del ejecutor no modifica sus expectativas.

El comando previsto, ejecutado desde `tp3`, es:

```sh
python3 -m unittest -v software.tests.test_assembler
```

El nombre `python3` identifica el intérprete compatible seleccionado en ese entorno. Las pruebas importan `software.assembler` por la misma ruta que la aplicación. Los módulos de traducción y prueba permanecen separados.

El comando verifica la traducción con texto y datos en memoria; no requiere placa, conexión serie ni herramientas RISC-V. La revisión de pertinencia de los mensajes de error conserva el criterio del catálogo.

## Comprobaciones de compatibilidad

Al implementar se ejecuta el catálogo completo en Python 3.11 y en la versión utilizada para desarrollar, si es distinta. Se registran la versión del intérprete, revisión del código y resultados conforme a la evidencia del catálogo. La compatibilidad declarada con el mínimo se acredita mediante esa ejecución, no solamente porque el código sea aceptado por un intérprete posterior.

Los módulos estándar previstos están disponibles en el entorno local. La sintaxis del ejemplo de importación también se comprobó con la gramática de Python 3.11. El módulo y las pruebas todavía no existen, por lo que no se acredita su importación ni su funcionamiento.

## Estado de diseño

Python 3.11 como mínimo, la importación `software.assembler`, los marcadores de paquete y la ejecución del catálogo con `unittest` están aprobados en el [acuerdo de DEC-SYS-009](../decisions/DEC-SYS-009.md#acuerdo-parcial-de-dec-sys-009--entorno-e-importación). El cierre conjunto de [DEC-SYS-009](../decisions/DEC-SYS-009.md) aprueba el lenguaje, la interfaz pública y la organización completos.

La disposición y el comando describen el entorno de la implementación futura. Los archivos de código, marcadores de paquete y pruebas se crean después del cierre global del [Plan](../plan.md#condición-común-para-comenzar-implementación). La aprobación acredita el diseño del entorno; su preparación y la ejecución de la regresión permanecen posteriores.

## Referencias y trazabilidad

- [Organización y operación](assembler_organization.md): módulo y elementos públicos previstos.
- [Estructuras de datos](assembler_data_model.md): clases y tipos aprobados.
- [Interfaz del assembler](assembler_interface.md): llamada pública y resultado.
- [Pruebas del assembler](assembler_tests.md): catálogo y expectativas independientes.
- [Estado de versiones de Python](https://devguide.python.org/versions/): mantenimiento de la base aprobada.
- [Paquetes regulares](https://docs.python.org/3.11/reference/import.html#regular-packages) y [búsqueda de módulos](https://docs.python.org/3.11/library/sys_path_init.html): marcadores y ruta de importación.
- [unittest](https://docs.python.org/3.11/library/unittest.html#command-line-interface): ejecución de las pruebas desde un módulo.
- [DEC-SYS-009](../decisions/DEC-SYS-009.md): lenguaje elegido y acuerdos de diseño.
- [Plan](../plan.md): condición de inicio de implementación y pruebas.
