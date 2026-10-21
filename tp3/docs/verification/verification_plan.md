# TP3 — Plan de verificación de hardware

- **Tipo:** plan de verificación.
- **Estado documental:** plan vigente; ejecución RTL pendiente.
- **Fecha:** 2026-10-20.

## Propósito y alcance

Este documento define cómo se verificará el hardware cuando se implemente: qué debe comprobarse, qué estímulos se utilizarán y qué resultado se considerará correcto.

El plan se construye a partir de cuatro fuentes de autoridad:

- Los [requisitos](../requirements.md) del TP3.
- Los [contratos vigentes](../architecture/system_overview.md#autoridad-documental-por-tema) de la arquitectura.
- Las [interfaces](../interfaces.md) aprobadas.
- Las [invariantes I01–I25](../architecture/architectural_invariants.md).

El alcance comprende la selección finita de casos, la definición de sus estímulos y expectativas, los niveles de verificación y la evidencia que deberá registrarse al implementar. Los contratos conservan la autoridad: si una prueba contradice un contrato vigente, primero debe revisarse la prueba; el diseño no se modifica implícitamente para hacerla coincidir.

Los documentos que componen el plan cumplen funciones diferentes:

- [Cobertura](coverage.md): los 167 requisitos —146 de hardware, nueve documentales y doce de software—, con sus contratos y comprobaciones asociadas. Incluye cobertura de bloques e invariantes.
- [ISA](isa.md): operaciones, inmediatos, codificaciones y flujo arquitectónico.
- [Pipeline](pipeline.md): solapamiento, latches, RF/WB, forwarding, `load-use` y descarte.
- [Memoria](memory.md): IMEM, lanes de DMEM, cero lógico, rango, alineación y ownership.
- [Ejecución](execution.md): sesión, preparación, arbitraje, `RUN`/`STEP`/`HOLD`, `halt`, faults y contador.
- [UART y Debug](uart_debug.md): UART físico, FIFO, mensajes, carga, recuperación, snapshot y fin físico de TX.
- [Plataforma](platform.md): configuración, reset integrado, estructura RTL, timing, placa y revisión documental.

## Selección finita de casos

Este plan no intenta probar todas las combinaciones posibles de entradas, registros, direcciones y estados. Define una selección finita de casos, y cada caso se incluye por un motivo concreto:

- Cubre una obligación de los requisitos o de un contrato.
- Representa una clase de entrada cuyo comportamiento es diferente.
- Verifica una frontera explícita, como un límite de rango, alineación o capacidad.
- Comprueba una interacción crítica entre contratos.

Cada sección identifica el motivo de sus casos mediante los requisitos y las fuentes correspondientes. Las tablas y listas delimitan las variantes que deben ejecutarse; no representan un producto cartesiano de todas las combinaciones.

Un mismo vector puede compartirse entre una prueba unitaria y una prueba de integración cuando ambas comprueban la misma semántica. La integración agrega casos propios cuando es necesario observar temporización, ownership o efectos que una prueba unitaria aislada no puede demostrar. Cambiar únicamente el registro o la dirección dentro de una misma clase no justifica, por sí solo, un caso nuevo.

El [manifiesto](cases.json) enumera 1380 variantes canónicas en 58 grupos. Las 151 reejecuciones de placa utilizan IDs de esa selección y se enumeran por separado.

Las [reglas del protocolo y su coordinación](coverage.md#reglas-del-protocolo-y-coordinación) relacionan admisión, carga, respuestas, Debug y reset con esos casos. La política de recuperación PC complementa la verificación de hardware; su modelo no acredita una aplicación implementada.

### Registro de ejecución en el manifiesto

El manifiesto `tp3-verification-cases` reúne la descripción de los casos y la configuración de sus ejecuciones en el mismo archivo. Cada grupo conserva sus IDs, fuentes documentales, entradas, expectativas y relaciones de reutilización, y contiene una lista `executions`.

Cada entrada de `executions` describe un testbench mediante sus fuentes en orden de compilación (`sources`), relativas a `tp3`, su módulo principal (`top`), el nivel de verificación que acredita (`level`) y el límite de tiempo por caso (`timeout_seconds`). Un grupo puede contener varias entradas para comprobar sus casos con distintos testbenches o en distintos niveles. Los IDs y las expectativas permanecen definidos en `cases` y `replay_cases`.

Las propiedades opcionales `case_ids` y `parameters` restringen los casos aplicables y fijan los parámetros de elaboración del banco. Un parámetro puede tomar una entrada entera mediante `{"input": "C"}`, que referencia `inputs.C` del caso antes de compilar. Sin `case_ids`, la ejecución se aplica a todos los casos del grupo, incluidas sus reejecuciones. `expected_rejection` declara un rechazo controlado mediante su código de salida positivo y la clave del diagnóstico dentro de `expected`; el diagnóstico conserva su autoridad en el caso. La carga común verifica la pertenencia de los casos y la existencia y los tipos de las entradas referenciadas. El [ejecutor común](test_selection.md#compilación-y-simulación) aplica estas configuraciones y valida los resultados.

`timeout_seconds` es un entero positivo que expresa el tiempo real máximo de cada simulación, en segundos. El límite corresponde a cada caso individual; no incluye la compilación ni representa tiempo simulado del circuito.

La lista `executions` vacía indica que el grupo no tiene una ejecución registrada. Una entrada solo referencia fuentes y testbenches existentes. La presencia de un caso en el catálogo o de una configuración de ejecución no representa un resultado aprobado.

Los resultados de las corridas se conservan como evidencia separada del manifiesto. Registrar una ejecución o sus resultados no cambia las entradas, expectativas ni cantidades de casos aprobadas.

El [intercambio de datos con los testbenches](case_data.md) describe la preparación de archivos desde el manifiesto y su lectura en SystemVerilog. Las entradas y los valores esperados se conservan en el JSON; los testbenches implementan la aplicación de estímulos y las comprobaciones.

La [guía de ejecución y selección de pruebas](test_selection.md) describe la CLI para consultar grupos y casos, eliminar repeticiones, validar las referencias del manifiesto y ejecutar los testbenches registrados con Icarus.

### Estructura del manifiesto

El [JSON Schema del manifiesto](cases.schema.json) define sus campos obligatorios, tipos, formatos de ID y configuraciones de ejecución. El campo `$schema` de `cases.json` lo vincula con ese archivo; `schema` conserva el identificador del manifiesto.

La raíz, los grupos, los casos, los fixtures y las configuraciones de ejecución rechazan campos desconocidos. Cada ejecución requiere `sources`, `top`, `level` y `timeout_seconds`: las fuentes son rutas relativas a `tp3`, el módulo principal usa un identificador simple de SystemVerilog, el nivel corresponde a uno de los nombres de la tabla de niveles de este plan y el límite de tiempo es un entero mayor o igual a uno. Las listas `executions` vacías son válidas.

Los objetos `inputs` y `expected` conservan los campos específicos de cada caso. El esquema comprueba que sean objetos con contenido; sus valores y significado se contrastan con el catálogo y los contratos. Los estímulos ilegales intencionales forman parte de los casos y no se rechazan por representar una entrada inválida para el hardware.

El esquema valida la estructura. La coincidencia entre `case_count` y la cantidad de casos, la unicidad por ID, la pertenencia de cada caso a su grupo, las referencias entre grupos/casos y la existencia de las fuentes son comprobaciones de coherencia adicionales a JSON Schema.

La validación del esquema se ejecuta con `check-jsonschema`, incluido en la imagen compartida. La [guía del entorno](../development_environment.md#validación-del-manifiesto) contiene los comandos de validación del manifiesto y del propio esquema.

### Formato estructurado de resultados

El [JSON Schema de resultados](results.schema.json) define un documento con el estado global (`status`), los contadores (`summary`) y los resultados individuales (`results`). Cada resultado identifica el caso (`case_id`), el testbench (`top`) y el nivel de verificación (`level`), e incluye su estado (`status`) y un diagnóstico (`message`). Los contadores corresponden a ejecuciones individuales: un mismo caso puede tener resultados de distintos testbenches o niveles.

`passed` indica que se comprobó el comportamiento esperado; `failed`, que el testbench detectó una diferencia; `error`, que la prueba no pudo completarse o interpretarse, por ejemplo por un error de compilación, un límite de tiempo excedido o la ausencia de resultado explícito. Los resultados `failed` y `error` requieren un diagnóstico no vacío. Un resultado aprobado admite `message: null`.

La representación JSON consiste en un único documento en la salida estándar; el progreso y los diagnósticos externos al documento corresponden a la salida de errores. La representación legible conserva los mismos resultados y códigos de salida.

El esquema comprueba la estructura y reutiliza las definiciones de ID, módulo y nivel del manifiesto. La coincidencia de los contadores con los resultados y del estado global con sus estados individuales son comprobaciones de coherencia adicionales a JSON Schema.

## Convenciones comunes

### Identificación de especificaciones y variantes

Cada `TEST-<área>-NNN` identifica una especificación de prueba. Cuando esa especificación tiene variantes enumeradas, cada una se identifica como `TEST-<área>-NNN/Cnnn` y se ejecuta y registra por separado. El sufijo identifica la variante; la cantidad del grupo se obtiene de su enumeración en el manifiesto.

«Aprobar» una especificación exige aprobar todas sus variantes; una ejecución representativa no alcanza. Los pasos y las observaciones que pertenecen a una variante no crean casos adicionales. Para ampliar una familia de casos hay que revisar el catálogo y el manifiesto.

En el manifiesto, cada variante se vincula mediante `group.source` con su especificación; `origins` identifica la tabla o familia que la define. Los encabezados **Requisitos** y **Contratos** de esa especificación completan la trazabilidad. Los requisitos corresponden al conjunto de variantes: una variante aislada no acredita todos los requisitos del grupo. Las reejecuciones de placa conservan el ID y la expectativa del caso original.

`kind` identifica la forma del estímulo, por ejemplo vector, programa o fixture. Su legalidad y alcance se precisan en **Tipo de estímulo** y en las condiciones de la variante. Un opcode inválido o tráfico fuera de fase puede recibirse por UART real; un fixture local que fuerza estado o entrega bytes por clock no demuestra alcanzabilidad mediante tramas 8N1.

### Estado inicial común

Salvo indicación contraria, todas las variantes utilizan el perfil `REFERENCE`, con IMEM de 1024 bytes y DMEM de 2048 bytes. También comienzan con:

- Una imagen confirmada desde cero.
- Una sesión ya preparada.
- `PC`, RF y contador en cero.
- Los latches sin trabajo.
- DMEM en cero lógico.

Cada variante parte de ese estado. Si necesita inicializaciones adicionales, la propia prueba debe indicarlas. Cuando se prueba la CPU sin UART, el banco de pruebas debe alcanzar el mismo estado mediante reset, carga y preparación, o mediante un fixture controlado equivalente. Ese fixture no puede interpretarse como un comando externo nuevo del sistema.

Los bancos presentan las entradas del bloque probado y observan sus salidas. En `Global FSM`, presentan las solicitudes y condiciones de sus productores, y observan aceptación, inicio de carga, autorización de ciclo y publicación. En unidad de hazards presentan `cpu_cycle_fire` y `drain_mode`; en unidad de protocolo, el sustituto de CPU produce los indicadores de control y la aceptación común. Los nombres de estado que identifican un fixture se distinguen de los puertos conectados al DUT. Las salidas combinacionales se comparan antes del flanco y los registros después de su captura.

### Instrucciones y assembler de estímulo

Los números de instrucción siempre representan valores de 32 bits. La instrucción `halt` debe utilizar exactamente la codificación `0x0000000B`.

El assembler utilizado en los ejemplos es únicamente una notación para expresar los estímulos. Antes de poblar IMEM, cada codificación debe validarse contra la whitelist de instrucciones de ID; la prueba no debe depender del futuro assembler.

No se deben usar pseudoinstrucciones para inferir la cantidad de ciclos. Si una secuencia necesita un `nop`, este significa exactamente:

```text
addi x0,x0,0
```

### Convenciones de representación

Las tablas de datos, palabras, bytes UART y máscaras utilizan hexadecimal o binario sin prefijo, según lo indique su columna. Por ejemplo:

- `12345678` representa `0x12345678`.
- Los bytes `34 12` representan el halfword `0x1234`.

Las direcciones pequeñas, capacidades, ciclos, índices y los inmediatos con signo se expresan en decimal. Los extremos `FFFFFFFF` y `FFFFFFFC` se expresan en hexadecimal.

Los nombres abreviados `PC4`, `word4` y `LH2` describen la posición o dirección indicada; no representan otro registro ni otra instrucción.

### Temporización y significado de las observaciones

Para describir correctamente cada ciclo se distinguen dos momentos:

| Momento        | Qué representa                                                                                     |
|----------------|----------------------------------------------------------------------------------------------------|
| **Preflanco**  | Valores que existían antes del flanco y que generan los datos y las señales de control a capturar. |
| **Postflanco** | Valores registrados después del flanco, cuando los registros del pipeline ya fueron actualizados.  |

Una prueba compara las habilitaciones combinacionales en preflanco y los valores registrados después del flanco correspondiente, esperando a que se estabilice la lógica combinacional. De ese modo, distingue los valores que quedaron registrados de las señales que todavía se están calculando para el ciclo siguiente.

La detección de una condición tampoco equivale automáticamente a su confirmación. Un candidato de fault todavía debe pasar por la prioridad y el arbitraje del pipeline antes de producir una terminación.

Por último, el PC global de fetch identifica la dirección que IF está buscando y puede avanzar especulativamente o cambiar por un redirect. Se compara con la secuencia temporal prevista por la prueba. Los PCs de las instrucciones que siguen en el pipeline y `fault_pc` tienen sus propias expectativas, según la posición y el evento que representan.

### Pruebas legales y artificiales

Una prueba **legal** llega a su condición mediante las operaciones normales del sistema: reset, carga, preparación y ejecución.

Una prueba **artificial** fuerza entradas o estado de un bloque para verificar una ecuación o una frontera que sería imposible o impracticable alcanzar durante una sesión normal. Su cobertura sirve para comprobar ese bloque, pero no demuestra alcanzabilidad end-to-end ni autoriza cambios en la FSM.

El plan identifica expresamente los casos artificiales o de frontera relacionados con:

- El drain asociado a `load-use`.
- La exclusión de un load reciente.
- PCs desalineados inyectados.
- El wrap del contador.
- Las colisiones de mantenimiento.
- Las ventanas del Controller y las entregas RX por clock, sin exigir que una trama 8N1 quepa en esa ventana.

## Cómo leer las pruebas

Cada grupo de pruebas debe poder leerse de principio a fin sin completar información implícita. Por eso especifica:

- El error o incumplimiento que intenta detectar.
- El estado inicial necesario.
- La selección cerrada de variantes que deben ejecutarse.
- Los pasos y estímulos de cada variante.
- El criterio que determina si la variante se aprueba.

Los programas y las tablas que aparecen en cada grupo son datos dirigidos para esas comprobaciones; no son una descripción general de todas las ejecuciones posibles. El manifiesto permite localizar una variante concreta y conocer sus datos exactos, sin depender de expresiones ambiguas como «repetir con las guardas».

Para leer las pruebas, se utilizan estos términos:

- **Fixture:** estado inicial controlado que prepara el banco de pruebas. En una prueba de CPU puede cargar los operandos necesarios; en una prueba sobre la placa, esos operandos deben cargarse mediante instrucciones legales y sus efectos deben contabilizarse.
- **DUT:** hardware que se está verificando. Sus salidas se comparan con expectativas calculadas de forma independiente, no con una copia de sus propios resultados.
- **Guarda:** condición que debe cumplirse para que ocurra un efecto. Por ejemplo, `valid=1` permite tratar una entrada como una instrucción activa, `reg_write=1` permite una escritura en RF y `rd≠0` impide escribir en `x0`. Para saber cuál condición produjo un resultado, se comparan variantes iguales salvo por una sola guarda; así, cualquier diferencia observada puede atribuirse a esa condición y no a otro cambio.
- **Commit:** escritura arquitectónica efectiva en RF o DMEM. Una instrucción descartada no debe producir un commit; una instrucción anterior que sigue siendo elegible debe conservarlo.
- **Drain:** ciclos utilizados para completar el trabajo anterior a `halt` o fault. En modalidad `STEP`, cada ciclo de drain requiere su propia orden.

## Niveles de verificación y evidencia requerida

Los niveles indican hasta dónde llega cada comprobación: comienzan en un bloque aislado, avanzan hacia la CPU y el sistema completo, y terminan en la implementación y la placa. Cada nivel tiene una observación propia y una evidencia que deberá registrarse cuando el hardware se implemente.

| Nivel                | Alcance de la observación                                | Evidencia requerida al implementar                                                                                                 |
|----------------------|----------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Modelo abstracto     | Contratos de control, recuperación PC y cotas calculadas. | Fuentes, comando, perfiles, estímulos, expectativas y eventos de interfaz inyectados.                                               |
| Unidad               | Un bloque o una lógica local aislada.                    | Entradas, salidas y efectos registrados por variante.                                                                              |
| Integración local    | Una etapa o una combinación de bloques.                  | Datos y señales de control en las fronteras, incluidos preflanco y postflanco.                                                     |
| CPU                  | `processor_top`, sin el enlace físico.                   | Commits, RF/DMEM, PC y latches, acciones, faults y ciclos efectivos.                                                               |
| Sistema              | UART, protocolo, CPU y serializador conectados.          | Bytes 8N1 reales y estado interno correlacionado. Inyectar bytes de FIFO sirve para pruebas locales, pero no reemplaza este nivel. |
| Cliente PC           | Aplicación y transporte, incluidos buffers y deadlines.   | Recuperación con lecturas fragmentadas, datos pendientes, desconexiones y respuestas perdidas o inválidas; registro de operaciones enviadas. |
| Elaboración/revisión | Tipos, parámetros, interfaces y dependencias del diseño. | Log de build o checklist con los archivos, objetos y versión examinada.                                                            |
| Implementación       | Vivado y netlist del perfil `REFERENCE`.                 | Recursos, clocks, constraints, DRC/CDC y timing post-route.                                                                        |
| Placa                | Basys 3 funcionando con un bitstream.                    | Capturas UART, programa/binario, perfil, bitstream y resultados de aceptación.                                                     |

Al implementar, cada registro de evidencia debe incluir:

- El ID y la variante de la prueba.
- El nivel de evidencia y el nombre del estímulo cuando se trate de un modelo fuera del catálogo RTL.
- La revisión del código utilizado.
- El comando y la versión de las herramientas utilizadas.
- El perfil de memoria.
- El estímulo aplicado.
- El resultado esperado.
- El resultado observado.
- El estado final de la prueba.

Un timeout del banco de pruebas representa un fallo o una limitación de la prueba. Nunca puede interpretarse como `FINISHED` del procesador.

No se exige implementar físicamente `ALT_1000` ni utilizar arrays gigantes para verificar la aritmética de `2^32`.

### Evidencia disponible y pendiente

Los [modelos ejecutables](../../tools/verification/README.md) comprueban recorridos de las 11 fases del Controller y las 14 Global, recuperación PC fuera de LOAD, integridad del catálogo y presupuestos de ambos perfiles. Se suministran eventos de CPU, fin de preparación y último Stop; el reloj PC es virtual. No se ejecutan instrucciones ni se produce el cuerpo Debug. El comando y los límites se documentan junto a las fuentes.

La ejecución de los casos contra RTL, las tramas 8N1, el análisis de lazos y timing de la implementación, la placa y el cliente real siguen pendientes. El cliente debe comprobar también la recuperación propia de LOAD. Ningún resultado abstracto aprueba por sí solo un requisito completo ni una variante del catálogo RTL.

## Resultados esperados y criterios de comparación

### Cómo se definen los resultados esperados

Cada variante tiene un resultado esperado definido a partir de sus entradas, su estado inicial y los contratos vigentes. Ese resultado se escribe en las tablas, las secuencias y los criterios del catálogo, y el [manifiesto](cases.json) identifica la expectativa correspondiente. El banco de pruebas aplica el estímulo y compara lo observado con esa expectativa.

Los resultados se calculan y revisan independientemente del RTL. Copiar la salida del DUT o utilizar su decoder para decidir qué resultado aceptar produciría una comparación del hardware consigo mismo. Las codificaciones, operaciones y efectos esperados se obtienen de los contratos de la ISA, memoria y control.

Cuando un caso reutiliza una tabla o una comprobación de otra prueba, esa referencia forma parte de su expectativa. Debe identificar los datos y las condiciones aplicables a la variante. Para los casos parametrizados, como un loop que escribe toda DMEM, la expectativa puede expresarse mediante una regla explícita sobre la capacidad del perfil. La regla determina los valores y la secuencia esperados a partir de las entradas del caso, sin utilizar resultados observados del DUT.

### Qué resultados se comparan

Para las pruebas de CPU, la expectativa comprende el programa, el estado inicial y los datos de la variante. El banco compara:

- El contenido final del `Register File`.
- El estado lógico de DMEM, es decir, los valores que deberían observarse teniendo en cuenta las marcas de validez.
- La cantidad y el orden de los stores comprometidos, junto con su dirección, tamaño y bytes escritos.
- La causa del fault y el PC que lo originó, cuando el programa produce un fault.

Las inicializaciones y las instrucciones de setup forman parte del caso. Sus efectos se incluyen en el estado esperado, junto con los resultados de las instrucciones que comprueba la variante. Los registros que ninguna instrucción de la secuencia escribe deben conservar su valor inicial; los bytes que no reciben un store conservan su valor lógico. En una sesión limpia, esos bytes se observan como cero. Un store de cero también marca sus bytes como utilizados, por lo que comparar solo el contenido de DMEM no alcanza para comprobar esa condición.

Una instrucción descartada o causante de un fault no debe producir escrituras. Los efectos anteriores que siguen siendo elegibles deben conservarse. Las expectativas de los casos de fault incluyen tanto causa y PC como los valores y las marcas que deben permanecer intactos.

### Cuándo se comparan los resultados

En una prueba combinacional, se aplican las entradas y se comparan las salidas cuando la lógica se estabiliza. En una prueba con registros, las entradas y las condiciones preflanco determinan qué debe capturarse; la comparación del estado registrado se realiza postflanco, según las convenciones de este plan.

En los programas que terminan, RF, DMEM y los metadatos se comparan al alcanzar `FINISHED` o `FAULT`, después de completar el trabajo anterior pendiente. La comparación se realiza antes de un reset o una nueva preparación que modifique ese estado. Las escrituras se observan durante toda la ejecución, incluido el drenado, para detectar efectos faltantes, repetidos o descartados que hayan llegado a comprometerse.

En `STEP`, cada observación intermedia se compara después del ciclo efectivo correspondiente. Los programas no terminantes se comprueban durante la ventana definida por su prueba y luego se recuperan mediante el mecanismo indicado. El fin de esa ventana o un timeout del banco no se interpreta como una terminación del procesador.

### Observaciones temporales

Los valores finales no bastan para comprobar el funcionamiento interno del pipeline. Las tablas y secuencias por ciclo de cada prueba determinan las expectativas para:

- Los stalls.
- Los latches.
- `cycle_count`.
- La FSM global.
- El comportamiento de `STEP`.
- El momento o la forma de una observación por Debug.

Esas observaciones se comparan en el momento definido por la prueba, con sus condiciones de avance, stall, HOLD o drenado. El PC global representa el frente de búsqueda y se comprueba mediante su secuencia temporal; `fault_pc` identifica la instrucción o el fetch causante y se compara con el valor fijado para la variante.

### Comparación de commits

La interfaz concreta del scoreboard pertenece al banco de pruebas. No agrega puertos ni estado arquitectónico al procesador.

Para verificar stores y otros commits, el banco debe identificar cada ejecución concreta de una instrucción. Una misma instrucción puede ejecutarse varias veces dentro de un loop, por lo que su PC puede repetirse. El PC repetido no alcanza para distinguir esas ejecuciones.

Por eso el banco utiliza etiquetas internas para numerar o identificar las instancias dinámicas. Esas etiquetas solo existen en la verificación; no forman parte del diseño de la CPU.

Para cada instancia, la expectativa determina si debe existir una escritura y qué dato debe producir. La comparación debe comprobar:

1. que cada escritura prevista ocurra una sola vez y con su destino y dato correctos;
2. que los stores ocurran en la cantidad y el orden esperados;
3. que una instrucción descartada, por ejemplo después de un redirect, `halt` o fault, no produzca ningún efecto arquitectónico.

Comparar únicamente el estado final no permite detectar un store repetido que escriba el mismo valor ni una escritura indebida cuyo dato sea sobrescrito después. La observación de commits comprueba esos efectos durante la ejecución, mientras que las expectativas temporales comprueban las condiciones bajo las que deben ocurrir.

## Organización de la verificación

La verificación se divide en niveles porque cada nivel permite observar propiedades diferentes. Las pruebas de unidad comprueban bloques aislados; las de integración local comprueban etapas o combinaciones de bloques; las de CPU comprueban `processor_top` sin el enlace físico; y las de sistema comprueban la interacción entre UART, protocolo, CPU y serializador.

Las comprobaciones sobre la placa requieren además una implementación sintetizada, timing cerrado y un bitstream. Por eso no sustituyen a las pruebas de unidad, integración, CPU o sistema: agregan evidencia sobre el comportamiento físico de la implementación elegida.

Los testbenches se organizarán por nivel y por los IDs de este catálogo, con una estructura equivalente a:

- `tb/unit` para pruebas de unidad.
- `tb/integration` para integración local.
- `tb/cpu` para `processor_top` sin enlace físico.
- `tb/system` para la integración completa con UART, protocolo y serializador.

Los modelos abstractos tienen el comando reproducible indicado arriba. Los testbenches RTL, sus interfaces y comandos de regresión se concretarán al implementar, conservando los vectores y expectativas del catálogo. La programación de la verificación y del hardware se realiza después del cierre global establecido en el [plan](../plan.md#16-fase-13--implementación-rtl-incremental).

## Condición de entrega y cierre

El plan define las comprobaciones de cada requisito en alcance y las condiciones iniciales, estímulos, expectativas, niveles y criterios de aprobación de sus pruebas. La matriz cubre los 51 bloques y las 25 invariantes, ambos perfiles y las interacciones críticas. Los IDs y las referencias relacionan cada variante con su especificación y sus contratos.

El cierre documental de FPGA-07 y FPGA-08 comprende el diseño de las pruebas y las reglas de comparación. Su correspondencia con el diseño FPGA forma parte del cierre de FPGA-09. La ejecución exitosa de las pruebas y la habilitación de la implementación son resultados independientes del cierre de estos documentos.

## Pendientes y límites

- **LIM-01:** los contratos exigen valores definidos ante estados internos ilegales, pero no fijan un byte numérico del encoder para zero-hot/multi-hot. La revisión solo exige ausencia de `X`, control seguro y ausencia de un nuevo fault; no se inventa un código UART. Ese valor deberá documentarse al concretar el RTL. Las ejecuciones legales sí tienen los 14 códigos fijados.
- **LIM-02:** algunas fuentes actuales contienen referencias a documentos ausentes en el worktree. Este entregable utiliza los requisitos y contratos presentes; esas referencias no se consideran evidencia disponible.
- **LIM-03:** las interfaces exactas del banco de pruebas, las consultas jerárquicas XDC y los comandos de regresión se concretarán cuando existan RTL y netlist. Aquí se fijan observaciones y criterios, sin afirmar que esas herramientas ya estén disponibles.

## Referencias y trazabilidad

- [Decisiones pendientes](../decisions/pending_decisions.md): decisiones de diseño abiertas y condiciones de cierre.
- [Plan, fase 12](../plan.md#15-fase-12--plan-de-verificación): origen del entregable.
- [Invariantes](../architecture/architectural_invariants.md): propiedades de interacción.
- [Inventario](../architecture/module_inventory.md): bloques y módulos cubiertos.
