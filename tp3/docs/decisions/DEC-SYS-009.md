### DEC-SYS-009 — Estrategia del assembler

**Estado:** Aprobada.

**Dominio:** Software / Assembler.

**Fecha de aprobación completa:** 2026-10-14.

**Contexto:** Los acuerdos parciales concretan la estrategia, las etapas de traducción, las estructuras de datos, las pruebas y el entorno. La aprobación conjunta del lenguaje, la interfaz pública y la organización interna completa el diseño del assembler.

**Opciones consideradas:** Assembler propio acotado, GNU Binutils y bibliotecas existentes, según [Costo y beneficio](../software/assembler_cost_benefit.md). El criterio de selección es cumplir el lenguaje del TP3 con el menor esfuerzo total esperado de desarrollo, verificación e integración.

**Decisión:** Se aprueba el diseño completo de un assembler propio en Python con biblioteca estándar, conforme a los siguientes contratos:

| Aspecto           | Contrato aprobado                                                                                                                                                                                                                                                                      |
|-------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Lenguaje          | [Lenguaje assembler](../software/assembler_language.md): 32 instrucciones RV32I más `halt`, sintaxis explícita, registros y alias, literales, etiquetas y rechazos.                                                                                                                    |
| Interfaz pública  | [Interfaz del assembler](../software/assembler_interface.md): `assemble(source_text: str) -> AssemblyResult`, con bytes y mapa PC–línea completos o un único diagnóstico.                                                                                                              |
| Etapas            | [Lectura](../software/assembler_source_reader.md), [direcciones](../software/assembler_addresses.md), [operandos](../software/assembler_operands.md), [codificación](../software/assembler_encoding.md) y [empaquetado](../software/assembler_packing.md), ejecutadas en ese orden.    |
| Datos             | [Estructuras de datos](../software/assembler_data_model.md): siete dataclasses, registros nuevos entre etapas y datos independientes por llamada.                                                                                                                                      |
| Organización      | [Organización y operación](../software/assembler_organization.md): un módulo, cinco funciones de etapa y `_AssemblyError` capturada por `assemble`; las excepciones inesperadas se propagan. El diagnóstico corresponde al primer rechazo detectado en el orden de etapas y registros. |
| Responsabilidades | El assembler traduce sin recibir perfil ni capacidad de IMEM. La FPGA valida el tamaño antes de aceptar `LOAD`; la aplicación gestiona archivos, transporte y presentación.                                                                                                            |
| Verificación      | [Pruebas del assembler](../software/assembler_tests.md): 101 variantes dirigidas en ocho grupos, con expectativas independientes y alcance proporcional al TP.                                                                                                                         |
| Entorno           | [Entorno e importación](../software/assembler_environment.md): CPython 3.11 como mínimo, importación desde `software.assembler` y catálogo con `unittest`.                                                                                                                             |

**Justificación:** El lenguaje pequeño y fijo permite resolver etiquetas mediante direcciones contiguas y reutilizar seis formatos de codificación. Las etapas y representaciones simples acotan el desarrollo y su comprensión. La elección conserva su fundamento cualitativo; no acredita una medición comparativa del costo real.

**Consecuencias:** Los documentos de lenguaje, interfaz y organización pasan a especificaciones vigentes y `DEC-SYS-009` se retira del registro de pendientes. El assembler puede traducir programas que produzcan faults de ejecución, así como entradas vacías o imágenes mayores que IMEM: la traducción, la aceptación de carga y la ejecución conservan responsabilidades distintas. La implementación y las pruebas ejecutadas permanecen posteriores al cierre global D0/M6 del [Plan](../plan.md#condición-común-para-comenzar-implementación). La aplicación de PC conserva su decisión independiente `DEC-SYS-008`.

**Requisitos afectados:** `REQ-MEM-010` a `REQ-MEM-012`, `REQ-MEM-015`, `REQ-MEM-021` a `REQ-MEM-024`, `REQ-SW-002` a `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-012` y el alcance de codificación de `REQ-ISA-033`.

**Reemplaza / Reemplazada por:** Completa los acuerdos parciales siguientes, sin cambiar sus contratos aprobados. Sus menciones a aspectos pendientes describen el alcance existente en la fecha de cada aprobación, anterior al cierre conjunto.

### Acuerdo parcial de DEC-SYS-009 — Elección de assembler propio

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-13.

**Contexto:** El [lenguaje propuesto](../software/assembler_language.md) comprende 32 instrucciones RV32I más `halt`, palabras de tamaño fijo, etiquetas y literales simples, sin pseudoinstrucciones, expresiones, macros ni secciones. El criterio principal indicado por el usuario es obtener una implementación correcta con el menor esfuerzo total, incluida su verificación e integración.

**Opciones consideradas:** Assembler propio acotado, integración de GNU Binutils y biblioteca existente. El [análisis de costo y beneficio](../software/assembler_cost_benefit.md) describe los trabajos compartidos, las adaptaciones y los riesgos de cada alternativa.

**Decisión:** El TP3 utilizará un **assembler propio, acotado al lenguaje del proyecto**, para traducir los programas de usuario. La implementación de la traducción no se delegará a GNU ni a una biblioteca de assembler existente.

**Justificación:** El usuario acepta esta alternativa considerando el alcance reducido y el costo esperado de integrar y adaptar una herramienta más general frente a implementar el lenguaje acotado. Las instrucciones comparten seis formatos reutilizables y el tamaño fijo permite una resolución simple de etiquetas. Se trata de una elección de ingeniería apoyada en el alcance y la comparación documental, no de una demostración experimental de menor costo: no se midieron horas ni se desarrollaron prototipos comparativos.

**Consecuencias:**

- La lectura y validación del código fuente, resolución de etiquetas y codificación se diseñarán como responsabilidades del software propio.
- Las instrucciones no soportadas se rechazan antes de la carga; los faults arquitectónicos de programas ensamblables continúan siendo observables mediante Debug.
- El assembler debe aceptar `halt` sin operandos y emitir exactamente `0x0000000B`, según `DEC-SYS-001`.
- La codificación se comprobará mediante expectativas independientes del encoder y de la CPU. GNU como referencia de verificación sigue siendo una propuesta; este acuerdo no selecciona herramientas de prueba ni obliga a instalar GNU para operar la aplicación.
- Al aprobar este acuerdo, quedaban pendientes el lenguaje de implementación, interfaces y organización interna, empaquetado, asignación de la validación de imagen según el perfil, diagnósticos y relación PC–línea, y el catálogo completo de pruebas de software. El acuerdo siguiente resuelve el lenguaje de implementación.
- Este acuerdo aprueba la estrategia propia; no aprueba por sí solo cada elección de sintaxis, no cierra `DEC-SYS-009` completa ni D0/M6 y no acredita una implementación funcionando.

**Requisitos afectados:** `REQ-SW-002` a `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-012`. Las obligaciones de memoria/perfil relacionadas conservan sus decisiones aprobadas; su asignación a las capas de software forma parte del cierre restante.

**Reemplaza / Reemplazada por:** Resuelve la elección entre las alternativas de `DEC-SYS-009`. El cierre conjunto registrado al comienzo de este documento completa el alcance restante.

### Acuerdo parcial de DEC-SYS-009 — Lenguaje de implementación

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** Elegida la estrategia de assembler propio, se necesita un lenguaje que permita desarrollar, comprender y verificar el código con poco esfuerzo. No existen requisitos de velocidad de ensamblado que justifiquen priorizar rendimiento sobre simplicidad.

**Decisión:** El assembler propio se implementará en **Python, utilizando su biblioteca estándar**, sin incorporar una biblioteca externa de assembler o parsing.

**Justificación:** Python permite trabajar directamente con texto, tablas de instrucciones y registros, diccionarios de etiquetas, enteros, operaciones de bits y bytes. El usuario aprueba la elección por el menor esfuerzo esperado de comprensión y desarrollo y por la ausencia de exigencias de velocidad de ensamblado.

**Consecuencias y alcance pendiente:** Las entradas y salidas, estructuras de datos, organización interna, codificación, empaquetado y diagnósticos se especificarán para Python; el acuerdo siguiente concreta la separación de validación de tamaño en FPGA. Las pruebas deberán comprobar las codificaciones y rangos de forma independiente. El entorno y la versión soportada se concretarán en el diseño de software. Este acuerdo no selecciona CLI, TUI o GUI, ni dependencias de transporte serie, ni herramientas externas de verificación; tampoco cierra D0/M6 o el diseño completo del assembler.

**Requisitos afectados:** `REQ-SW-002` a `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-012`.

### Acuerdo parcial de DEC-SYS-009 — Responsabilidad de traducción y validación de tamaño

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en su diseño detallado y cierre.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** La propuesta inicial de interfaz recibía texto y capacidad de IMEM para validar la imagen antes de cargarla. El usuario establece que el assembler debe encargarse de traducir y que la validación de capacidad corresponde a la FPGA. El contrato aprobado de `LOAD` ya valida el tamaño completo antes de aceptar y antes de recibir las instrucciones.

**Decisión:** El assembler recibe únicamente el texto del programa y traduce las instrucciones del lenguaje soportado a bytes little-endian, conservando su relación PC–línea. Comprueba lo necesario para una traducción correcta: sintaxis, instrucciones, operandos, registros, etiquetas y rangos de codificación. No recibe capacidad ni perfil de memoria y no decide si los bytes producidos caben en IMEM.

La FPGA conserva la validación de tamaño no nulo, múltiplo de cuatro y no mayor que su capacidad, según [Protocolo](../protocol.md#imagen-y-tamaño). La aplicación interpreta `INVALID_SIZE` y presenta el rechazo. No se exige duplicar la comparación de capacidad en otra capa de PC. Una traducción vacía puede producir cero bytes; su eventual carga se rechaza como tamaño inválido, no como error del lenguaje.

**Justificación:** Mantiene una responsabilidad acotada para el assembler y elimina una entrada dependiente de hardware. La aceptación previa de `LOAD` ya impide enviar instrucciones si su tamaño no es admisible: la PC envía la cabecera y espera aceptación. El éxito de traducción se distingue del éxito de carga y ejecución.

**Consecuencias:** Se revisa [Entradas y salidas](../software/assembler_interface.md) a `assemble(source_text: str)`. La aplicación sigue usando el perfil común para las restantes obligaciones de protocolo y Debug. Los resultados y diagnósticos de traducción permanecen independientes de la placa. La asignación general de validación de imagen al toolchain de PC queda reemplazada por esta separación explícita; el detalle interno de traducción y el catálogo de pruebas siguen pendientes. El resto de las elecciones de interfaz sigue en revisión.

**Requisitos afectados:** `REQ-SW-002` a `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-012`, `REQ-MEM-012`, `REQ-MEM-015`, `REQ-MEM-024`. Se conservan las condiciones y comprobaciones FPGA de estos requisitos.

**Reemplaza / Reemplazada por:** Reemplaza la propuesta de pasar capacidad de IMEM al assembler y el pendiente de asignar una comprobación de capacidad adicional al software de PC. No reemplaza `DEC-PROTO-001` ni los contratos de memoria/carga aprobados.

### Acuerdo parcial de DEC-SYS-009 — Lectura del código fuente

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** La primera etapa interna debe reconocer el código fuente y conservar su ubicación original para las etapas de traducción. El usuario revisa [Lectura del código fuente](../software/assembler_source_reader.md) y acepta su contrato.

**Decisión:** Se aprueba la lectura documentada: separación de comentarios, reconocimiento de una etiqueta e instrucción por línea cuando corresponda, comprobación de mnemónicos y formas de operandos, y conservación de los campos conceptuales `line`, `label`, `mnemonic` y `operands`. Las líneas vacías y de comentarios no agregan registros; sus posiciones se conservan en la numeración. Las etiquetas solas y las definiciones al final del programa se mantienen para asignarles una dirección posteriormente.

Los operandos se conservan como texto y los espacios admitidos en operandos de memoria se normalizan. La lectura informa un diagnóstico ante una forma inválida y descarta el resultado parcial. La interpretación de registros y literales, la detección de símbolos duplicados, la resolución de referencias y la codificación corresponden a etapas posteriores.

**Justificación:** Una representación simple conserva el orden del programa y las líneas necesarias para los diagnósticos y Debug. Separar reconocimiento e interpretación permite registrar referencias adelantadas sin asignar todavía direcciones ni valores.

**Consecuencias y alcance pendiente:** El contrato de lectura pasa a especificación vigente. La estructura Python concreta, asignación de direcciones y tabla de etiquetas, interpretación de operandos, resolución de destinos, codificación, empaquetado y catálogo de pruebas siguen pendientes. Este acuerdo no acredita un parser implementado ni cierra `DEC-SYS-009` o D0/M6.

**Requisitos afectados:** `REQ-SW-002`, `REQ-SW-003`, `REQ-SW-012`.

### Acuerdo parcial de DEC-SYS-009 — Direcciones y tabla de etiquetas

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** Los registros reconocidos por la lectura deben asociarse con direcciones para resolver etiquetas y conservar la relación con el código fuente. El usuario revisa y acepta las reglas de [Direcciones y tabla de etiquetas](../software/assembler_addresses.md).

**Decisión:** Se aprueba la asignación desde cero, con cuatro bytes por instrucción. Cada etiqueta se registra con la dirección vigente antes de ubicar la instrucción de su línea. Una etiqueta aislada identifica la siguiente instrucción o la dirección posterior al programa. Las etiquetas no ocupan bytes y distintos nombres pueden compartir dirección. Repetir un nombre exacto produce un diagnóstico en la segunda definición; los nombres distinguen mayúsculas y minúsculas.

La salida conserva instrucciones con `line`, `pc`, `mnemonic` y `operands`, y una tabla consultable por nombre con dirección y línea de definición. Las instrucciones se ubican por orden del código fuente, incluidas las posteriores a `halt`. Las referencias permanecen como texto para su resolución posterior. Esta etapa no comprueba capacidad de IMEM ni genera palabras de instrucción.

**Justificación:** El tamaño fijo permite determinar todas las direcciones antes de codificar. Conservar la tabla completa admite referencias adelantadas y permite informar definiciones duplicadas con su ubicación original. Los PCs y líneas de las instrucciones proporcionan la relación necesaria para Debug.

**Consecuencias y alcance pendiente:** El contrato pasa a especificación vigente. Permanecen pendientes las estructuras Python concretas, interpretación de operandos, resolución de destinos, codificación, empaquetado y catálogo de pruebas. Este acuerdo no acredita una implementación ni cierra `DEC-SYS-009` o D0/M6.

**Requisitos afectados:** `REQ-SW-003`, `REQ-SW-010`.

### Acuerdo parcial de DEC-SYS-009 — Interpretación de operandos y resolución de destinos

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** Las instrucciones con dirección y operandos de texto deben convertirse a valores comprobados antes de formar las palabras de código máquina. El usuario aprueba [Interpretación de operandos y resolución de destinos](../software/assembler_operands.md).

**Decisión:** Se aprueba la conversión de nombres y alias de registro a índices de 0 a 31, la conversión de literales admitidos a enteros matemáticos, la separación de base y offset de memoria y `jalr`, y la resolución de etiquetas a desplazamientos relativos al PC de la propia instrucción. Un destino literal ya representa ese desplazamiento en bytes y no se transforma como dirección absoluta.

Cada valor se comprueba contra el rango de su instrucción, incluida la paridad de los desplazamientos B/J. La base numérica no modifica el signo ni permite recortar un valor fuera de rango. Las etiquetas deben estar definidas y respetar su posición de operando admitida. La salida conserva `line`, `pc`, `mnemonic`, `rd`, `rs1`, `rs2` e `imm`, distinguiendo campos ausentes de índices o inmediatos cero.

**Justificación:** Entregar operandos interpretados y comprobados permite que la codificación se concentre en la distribución de campos. La línea original identifica los errores y las direcciones ya asignadas resuelven referencias adelantadas y hacia atrás con una única regla.

**Consecuencias y alcance pendiente:** El contrato pasa a especificación vigente. Los negativos se conservan como enteros con signo hasta la codificación; los inmediatos U y de shift conservan su valor de campo. La etapa no comprueba capacidad de memoria ni sustituye los faults de ejecución de la CPU. Permanecen pendientes las representaciones Python concretas, tabla y fórmulas de codificación, empaquetado y catálogo de pruebas. Este acuerdo no acredita una implementación ni cierra `DEC-SYS-009` o D0/M6.

**Requisitos afectados:** `REQ-SW-003`, `REQ-SW-010`, `REQ-SW-012`, `REQ-ISA-033`.

### Acuerdo parcial de DEC-SYS-009 — Codificación de instrucciones

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** Los operandos interpretados deben convertirse en palabras compatibles con la whitelist de ID y la reconstrucción de inmediatos de la CPU. El usuario revisa [Codificación de instrucciones](../software/assembler_encoding.md), consulta su resumen y acepta continuar con el empaquetado.

**Decisión:** Se aprueban la tabla de campos fijos de las 32 instrucciones RV32I y `halt`, la distribución de bits en los formatos R, I, S, B, U y J y las fórmulas de composición. Los inmediatos con signo se representan en complemento a dos con el ancho correspondiente; U conserva su campo de 20 bits y los shifts conservan su cantidad de cinco bits junto al selector fijo. Los desplazamientos B/J se distribuyen como valores en bytes ya resueltos, sin volver a calcular etiquetas.

Cada instrucción produce una palabra entera de 32 bits no negativa y conserva `line` y `pc`. `halt` produce exactamente `0x0000000b`. La entrada vacía produce una secuencia vacía; no se agrega relleno ni una terminación implícita.

**Justificación:** Los seis formatos permiten compartir las fórmulas de distribución de campos. La tabla acota las operaciones al subconjunto aprobado y mantiene la compatibilidad con el decoder y el Immediate Generator. La validación previa de operandos permite formar palabras sin recortar valores inválidos.

**Consecuencias y alcance pendiente:** El contrato pasa a especificación vigente. La codificación no analiza faults de ejecución ni capacidad de IMEM. Permanecen pendientes las representaciones Python concretas, el empaquetado, la revisión del contrato público completo y el catálogo de pruebas de software. Las comprobaciones documentales de tablas y ejemplos no acreditan una implementación ni cierran `DEC-SYS-009` o D0/M6.

**Requisitos afectados:** `REQ-SW-003`, `REQ-SW-012`, `REQ-ISA-033`.

### Acuerdo parcial de DEC-SYS-009 — Empaquetado y resultado

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** Las palabras codificadas deben convertirse en los bytes del programa y conservar su relación con el código fuente para Debug. El usuario revisa la explicación de [Empaquetado y resultado](../software/assembler_packing.md) y aprueba el contrato.

**Decisión:** Cada palabra de 32 bits produce cuatro bytes little-endian, comenzando por los bits 7:0 y terminando por 31:24. Los grupos se concatenan en orden del programa para formar `image`. Los mismos registros codificados producen una entrada `pc_to_line[pc]=line` por instrucción, sin entradas adicionales para etiquetas ni para los otros bytes de cada palabra.

La traducción completa entrega `image` como `bytes`, el mapa de líneas y `error=None`. La entrada sin instrucciones entrega `b""`, `{}` y `None`. Ante un error de traducción de una etapa anterior, se entrega `image=None`, mapa vacío y el diagnóstico; no se publica una traducción parcial.

**Justificación:** La distribución coincide con la reconstrucción del Loader y el protocolo aprobado. Formar bytes y mapa desde los mismos registros conserva la correspondencia entre el programa traducido y sus líneas originales.

**Consecuencias y alcance pendiente:** El contrato pasa a especificación vigente. Se conservan todas las instrucciones, incluidas las posteriores a `halt`, sin agregar relleno ni terminación automática. La cabecera y transferencia de `LOAD` pertenecen al protocolo; el mapa queda en la aplicación y la capacidad de IMEM se valida en FPGA. Permanecen pendientes las representaciones Python concretas, la revisión del contrato público completo y el catálogo de pruebas de software. Este acuerdo no acredita una implementación ni cierra `DEC-SYS-009` o D0/M6.

**Requisitos afectados:** `REQ-SW-003`, `REQ-SW-010`, `REQ-SW-012`.

### Acuerdo parcial de DEC-SYS-009 — Estructuras de datos

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** Los contratos de las etapas requieren representaciones Python concretas para conservar texto, direcciones, operandos, palabras y resultados. El usuario revisa [Estructuras de datos](../software/assembler_data_model.md), confirma el uso de registros nuevos entre etapas y acepta la propuesta.

**Decisión:** Se aprueban siete clases `dataclass` con sus campos y tipos documentados: `SourceRecord`, `LocatedInstruction`, `LabelDefinition`, `InterpretedInstruction`, `EncodedInstruction`, `AssemblyDiagnostic` y `AssemblyResult`. Las secuencias utilizan listas; las etiquetas, un diccionario por nombre; la relación PC–línea, un diccionario por dirección. Los campos ausentes utilizan `None`, distinguiéndose de los índices e inmediatos cero.

Cada etapa crea registros con la forma de su salida y conserva los datos necesarios para la siguiente. Los campos se proporcionan explícitamente y cada llamada utiliza sus propias colecciones. Las clases agrupan datos; las comprobaciones de sintaxis, presencia de campos y rangos corresponden a las etapas.

**Justificación:** Los campos con nombre permiten consultar los datos de cada etapa de forma clara. Las dataclasses de la biblioteca estándar reducen el trabajo de definir registros y mantienen una representación específica para cada contrato aprobado.

**Consecuencias y alcance pendiente:** El modelo pasa a especificación vigente. Se concretan las clases del resultado y diagnóstico, conservando las condiciones de traducción completa y vacía aprobadas. Permanecen pendientes la organización de funciones y archivos, la propagación interna de diagnósticos, el cierre de la interfaz pública, el entorno y versión soportada y el catálogo de pruebas de software. Este acuerdo no acredita una implementación ni cierra `DEC-SYS-009` o D0/M6.

**Requisitos afectados:** `REQ-SW-003`, `REQ-SW-010`, `REQ-SW-012`.

### Acuerdo parcial de DEC-SYS-009 — Catálogo de pruebas

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente en sus aspectos restantes.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** El usuario solicita diseñar pruebas sin comparaciones tautológicas, proporcionales al TP y con entradas dirigidas habituales. Revisa el resumen de [Pruebas del assembler](../software/assembler_tests.md) y acepta el catálogo.

**Decisión:** Se aprueba la selección finita de 101 variantes en ocho grupos, con sus entradas, bytes y mapas esperados, líneas y motivos de diagnóstico y condiciones de aprobación. Comprende una codificación por instrucción, etiquetas, escritura admitida, extremos de inmediatos, errores del lenguaje, separación de traducción y ejecución, descarte de parciales e independencia entre llamadas.

La verificación utiliza la operación pública `assemble` y expectativas independientes. Las tablas y funciones del assembler y el decoder de la CPU no calculan los valores que la prueba debe aceptar. Las constantes RV32I fueron contrastadas documentalmente con LLVM; su uso durante esa revisión no incorpora una herramienta externa como dependencia de la regresión. `halt` conserva su expectativa exacta de `DEC-SYS-001`.

**Justificación:** La selección comprueba operaciones, fronteras e interacciones del lenguaje con datos finitos. Los casos pueden compartir el mecanismo de invocación y comparación, conservando sus expectativas como datos. No se exige explorar combinaciones exhaustivas ni provocar fallos internos artificiales.

**Consecuencias y alcance pendiente:** El catálogo pasa a diseño aprobado. Su implementación y ejecución permanecen pendientes. Los casos de orden de detección conservan su relación con la propuesta de organización y no cierran por sí solos su contrato completo. Permanecen pendientes la revisión y aprobación de organización, lenguaje e interfaz pública como conjunto y el entorno y versión soportada. Este acuerdo no cierra `DEC-SYS-009` o D0/M6 ni acredita una regresión ejecutada.

**Requisitos afectados:** `REQ-SW-003`, `REQ-SW-012` y el alcance assembler de `REQ-ISA-033`.

### Acuerdo parcial de DEC-SYS-009 — Entorno e importación

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-009` permanece pendiente de revisión y cierre conjunto.

**Fecha de aprobación:** 2026-10-14.

**Contexto:** La implementación y las pruebas requieren un intérprete mínimo y una ruta de importación concretos. El usuario acepta [Entorno e importación](../software/assembler_environment.md) y solicita explicar el criterio de elección.

**Decisión:** Se aprueba CPython 3.11 como mínimo, utilizando sintaxis y APIs disponibles en esa versión. La traducción y su regresión usan la biblioteca estándar, con `unittest` para el catálogo aprobado. La aplicación y las pruebas importan los elementos públicos desde `software.assembler`, con base de ejecución en `tp3` y marcadores vacíos `__init__.py` para los paquetes `software` y `software.tests`.

El código de traducción permanece en `software/assembler.py` y las pruebas se ubican en `software/tests/test_assembler.py`. El comando de catálogo es `python3 -m unittest -v software.tests.test_assembler`. La compatibilidad mínima se comprueba al implementar, ejecutando el catálogo en 3.11 y en la versión de desarrollo cuando sea distinta.

**Justificación:** Python 3.11 cubre los recursos del diseño y es la versión más antigua todavía mantenida según la referencia oficial consultada al aprobar. La biblioteca estándar y `unittest` evitan dependencias adicionales para esta capa. La importación convencional desde el checkout conserva una organización simple y no requiere distribuir o instalar un paquete. El entorno local, Python 3.14.8, cumple el mínimo.

**Consecuencias y alcance pendiente:** El entorno pasa a especificación vigente. La preparación del entorno y la creación de los archivos pertenecen a la implementación. Las dependencias de transporte y el formato de aplicación conservan su decisión independiente. Permanece pendiente la revisión y aprobación conjunta de lenguaje, interfaz pública y organización para cerrar `DEC-SYS-009`; el acuerdo no cierra D0/M6 ni acredita importaciones o pruebas del assembler ejecutadas.

**Requisitos afectados:** `REQ-SW-003` y `REQ-SW-012`.
