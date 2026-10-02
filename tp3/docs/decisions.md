# TP3 — Decisiones aprobadas

## 1. Propósito

Este documento conserva únicamente las decisiones aprobadas por el equipo y las decisiones reemplazadas que deben mantenerse por trazabilidad.

Las decisiones todavía no resueltas se registran en `pending_decisions.md`. Cuando una decisión pendiente se aprueba, conserva su identificador y se traslada a este documento.

## 2. Convenciones

Cada decisión aprobada contiene:

- **Estado:** `Aprobada` o `Reemplazada`.
- **Dominio:** área principal afectada.
- **Fecha de aprobación:** fecha en que el equipo aceptó la decisión.
- **Contexto:** problema que originó la decisión.
- **Opciones consideradas:** alternativas evaluadas.
- **Decisión:** alternativa seleccionada.
- **Justificación:** razones de la selección.
- **Consecuencias:** restricciones y efectos introducidos.
- **Requisitos afectados:** trazabilidad hacia `requirements.md`.
- **Reemplaza / Reemplazada por:** relación histórica, cuando corresponda.

---

## 3. Sistema y alcance

### DEC-SYS-001 — Representación y semántica de STOP/HALT

**Estado:** Aprobada

**Dominio:** Sistema / Ejecución

**Fecha de aprobación:** 2026-09-20

**Contexto:** El sistema necesita un mecanismo explícito que permita a un programa indicar su finalización. Debido a que el procesador utiliza un pipeline, detectar el final del programa no implica que la ejecución pueda detenerse inmediatamente: pueden existir instrucciones válidas anteriores todavía pendientes de completar. También es necesario distinguir una finalización intencional de situaciones como la ejecución accidental de memoria vacía o una instrucción inválida.

**Opciones consideradas:**

1. Incorporar una instrucción custom `halt` utilizando uno de los espacios designados por RISC-V para extensiones no estándar.
2. Utilizar la instrucción estándar `EBREAK` como indicador de fin de programa.
3. Interpretar la palabra `0x00000000` como fin de programa.
4. Utilizar una convención software basada en una instrucción que produzca un loop infinito, por ejemplo `jal x0, 0`.

**Decisión:** Incorporar una instrucción custom sin operandos denominada **`halt`**, codificada como `0x0000000B`. Su patrón completo tiene `bits[31:7] = 0` y el major opcode `custom-0`, `bits[6:0] = 0001011`.

`halt` no producirá efectos arquitectónicos sobre el banco de registros ni sobre la memoria de datos.

Solo el reconocimiento de un `halt` válido y perteneciente al flujo correcto podrá iniciar la finalización. Un `halt` que deba descartarse por un branch, jump u otra instrucción anterior no modificará el estado de ejecución ni iniciará el drenado.

Cuando `halt` sea reconocido, el procesador dejará de admitir nuevas instrucciones válidas y comenzará el drenado del pipeline. Las instrucciones válidas anteriores a `halt` podrán completar normalmente sus efectos arquitectónicos, mientras que ninguna instrucción posterior a `halt` podrá modificar el estado arquitectónico.

La ejecución se considerará finalizada únicamente cuando, después de haberse reconocido `halt`, el pipeline haya quedado completamente vacío.

En ejecución continua, el drenado continuará automáticamente hasta alcanzar dicho estado. En ejecución paso a paso, el procesador continuará requiriendo un comando `STEP` por cada ciclo, incluso durante el drenado, preservando la relación de un `STEP` por ciclo.

Este acuerdo de sistema no selecciona una etapa ni señales RTL para `halt`. El acuerdo parcial de `DEC-ARCH-003` aprobado el 2026-09-24 fija posteriormente su detección candidata en ID, confirmación arquitectónica en EX, retención del PC registrado y descarte de trabajo joven; la codificación funcional de `ID/EX.control` se fija después en los acuerdos trigésimo tercero y trigésimo cuarto, y el cuadragésimo primero de `DEC-ARCH-003` fija el arbitraje combinacional de ocho acciones; el cuadragésimo segundo acuerdo fija después enables/valores `next`, y el cuadragésimo quinto audita y resuelve las coincidencias funcionales.

**Justificación:** Una instrucción custom permite representar de forma inequívoca la intención de finalizar el programa sin reutilizar una instrucción estándar con otra semántica ni confundir la terminación normal con una instrucción inválida o memoria sin programar. El espacio `custom-0` está destinado por RISC-V a extensiones no estándar y permite introducir este mecanismo sin colisionar con las instrucciones RV32I requeridas. La separación entre detección de `halt` y finalización efectiva permite preservar los efectos de las instrucciones anteriores que todavía se encuentren dentro del pipeline.

**Referencias:**

- *The RISC-V Instruction Set Manual, Volume I: User-Level ISA, Version 2.2*, mapa de major opcodes: <https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf>.
- RISC-V International, mapa oficial vigente de opcodes RV32/64G: <https://docs.riscv.org/reference/isa/v20260120/unpriv/rv-32-64g.html#rv32-64g>.

**Consecuencias:**

- el assembler debe reconocer el mnemónico `halt` sin operandos y generar la palabra `0x0000000B`;
- el procesador debe reconocer únicamente dicha palabra completa como el marcador de finalización del programa;
- `halt` no debe escribir registros ni memoria;
- un `halt` invalidado por una instrucción anterior no debe afectar el control de ejecución;
- detectar `halt` y finalizar el programa son eventos distintos;
- después de detectar `halt` no deben admitirse nuevas instrucciones válidas;
- las instrucciones válidas anteriores a `halt` deben poder completar su ejecución;
- las instrucciones posteriores a `halt` no deben producir efectos arquitectónicos;
- debe existir una forma de determinar cuándo el pipeline ha quedado vacío;
- en modo continuo, el drenado ocurre automáticamente;
- en modo paso a paso, el drenado respeta la regla de un ciclo por cada `STEP`;
- `0x00000000` no se utilizará como representación de `halt`;
- la etapa de detección y la implementación concreta del drenado permanecen como decisiones de microarquitectura.

**Requisitos afectados:** `REQ-CPU-011`, `REQ-CPU-015`, `REQ-ISA-034`, `REQ-HAZ-010`, `REQ-EXEC-001` a `REQ-EXEC-010`, `REQ-EXEC-013`, `REQ-SW-003`, `REQ-SW-012`, `REQ-DOC-003`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-SYS-002 — Comportamiento ante ausencia de STOP/HALT

**Estado:** Aprobada

**Dominio:** Sistema / Ejecución

**Fecha de aprobación:** 2026-09-20

**Contexto:** Un programa puede no contener un `halt` válido o puede ejecutar indefinidamente sin alcanzarlo. El sistema debe definir qué ocurre en ese caso sin introducir mecanismos implícitos de finalización que puedan confundirse con una terminación normal del programa.

La política debe ser coherente con `DEC-SYS-001`, según la cual la finalización normal requiere el reconocimiento de un `halt` válido perteneciente al flujo correcto y el posterior vaciado completo del pipeline.

También debe preservarse la distinción entre finalización normal, intervención externa y condiciones de error que puedan definirse posteriormente.

**Opciones consideradas:**

1. Considerar terminado el programa al alcanzar la última dirección cargada en la memoria de instrucciones.
2. Considerar terminado el programa al acceder a memoria vacía o ejecutar una palabra `0x00000000`.
3. Finalizar automáticamente después de superar una cantidad máxima predeterminada de ciclos.
4. No producir finalización normal mientras no se ejecute un `halt` válido y disponer de una intervención externa para recuperar el control de una ejecución no terminante.

**Decisión:** La única finalización normal del programa será la definida por `DEC-SYS-001`: reconocimiento de un `halt` válido perteneciente al flujo correcto seguido por el vaciado completo del pipeline.

La ausencia de `halt` no producirá autónomamente una finalización normal.

No se utilizarán como sustitutos implícitos de `halt`:

- alcanzar la última dirección cargada;
- acceder a memoria vacía;
- ejecutar `0x00000000`;
- superar una cantidad arbitraria de ciclos.

Un timeout utilizado por un testbench, una herramienta de simulación u otro entorno de prueba podrá interrumpir una prueba, pero no representará una finalización del DUT ni deberá producir la indicación normal de programa finalizado.

En modo **RUN**, el procesador continuará ejecutando mientras no ocurra alguna de las siguientes condiciones:

- reconocimiento de un `halt` válido;
- intervención externa;
- una condición de error definida explícitamente por una decisión posterior.

En modo **STEP**, cada comando continuará representando exactamente un ciclo de avance. En ausencia de nuevos comandos `STEP`, el estado de ejecución del procesador no avanzará, sin que ello implique detener o manipular el clock principal, y el programa no se considerará finalizado.

El sistema deberá disponer de al menos un mecanismo externo capaz de recuperar el control de una ejecución no terminante. El mecanismo seleccionado deberá poder invocarse mientras RUN esté activo y llevar el sistema a un estado controlado desde el cual pueda iniciarse el procedimiento documentado para una nueva ejecución. Podrá basarse en reset, reprogramación, una operación de control explícita u otro mecanismo equivalente; su forma concreta y sus efectos se definirán en decisiones posteriores.

Una intervención externa o una condición de error no equivaldrán a una finalización normal mediante `halt` y no deberán producir `program_finished` ni ningún indicador de protocolo que posteriormente se reserve para representar la finalización normal.

Los términos conceptuales `RUNNING`, `DRAINING`, `FINISHED` y, cuando resulte útil, `ABORTED` describen estados semánticos del sistema y no imponen una cantidad, codificación o estructura determinada de estados RTL.

**Justificación:** Mantener a `halt` como única causa de finalización normal proporciona una semántica inequívoca y evita que condiciones accidentales del sistema se interpreten como terminaciones válidas del programa.

Utilizar la longitud cargada, memoria vacía o una cantidad máxima de ciclos como criterio automático de finalización introduciría comportamientos que podrían ocultar errores de software o confundir programas legítimamente no terminantes con programas finalizados.

Al mismo tiempo, una ejecución continua sin `halt` no debe dejar al sistema sin posibilidad de recuperación. Por ello se exige una capacidad externa de recuperación, pero se difiere su mecanismo concreto hasta disponer de las decisiones de reprogramación, reset y protocolo necesarias.

La separación entre finalización normal, recuperación externa y error permitirá verificar cada situación independientemente y evitará que una condición excepcional sea reportada como si el programa hubiera ejecutado correctamente su `halt`.

**Consecuencias:**

- un programa que no alcance un `halt` válido no producirá finalización normal por sí mismo;
- alcanzar la última dirección cargada no finalizará el programa;
- acceder a memoria vacía no finalizará el programa;
- `0x00000000` no finalizará el programa;
- no existirá un límite arbitrario de ciclos como parte de la semántica normal del procesador;
- los timeouts utilizados por herramientas o testbenches serán externos al comportamiento funcional del DUT;
- en RUN, una ejecución no terminante continuará mientras no exista `halt`, intervención externa o una condición de error definida;
- en STEP, la ausencia de nuevos comandos impedirá el avance del estado de ejecución sin producir finalización normal y sin manipular el clock principal;
- el sistema deberá disponer de al menos un mecanismo externo de recuperación invocable durante RUN;
- `DEC-ARCH-008` selecciona posteriormente reset global como mecanismo mínimo y define sus efectos sobre PC, pipeline, registros, imagen y control;
- una recuperación externa no deberá emitir `program_finished` ni ningún indicador de protocolo que posteriormente se reserve para representar la finalización normal;
- una condición de error futura deberá distinguirse de la finalización normal;
- no se impone un estado RTL denominado `ABORTED`; la FSM global es la del acuerdo 44 de `DEC-ARCH-003`;
- `DEC-SYS-003` define la semántica de reprogramación sin establecer que pueda iniciarse directamente durante RUN ni adoptarla por sí sola como mecanismo de recuperación;
- `DEC-ARCH-008` selecciona el reset global como vía mínima concreta de recuperación invocable durante RUN;
- `DEC-PROTO-002` deberá decidir si la recuperación se expondrá como una operación UART;
- `DEC-ARCH-001` define el tratamiento de accesos fuera de rango y `DEC-ARCH-004` deberá definir por separado el de instrucciones inválidas y desalineación.

**Requisitos afectados:** `REQ-EXEC-005`, `REQ-EXEC-006`, `REQ-EXEC-008`, `REQ-EXEC-009`, `REQ-EXEC-012`, `REQ-EXEC-014`, `REQ-EXEC-015`, `REQ-DOC-004`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-SYS-003 — Política general de reprogramación

**Estado:** Aprobada

**Dominio:** Sistema / Reprogramación

**Fecha de aprobación:** 2026-09-20

**Contexto:** El sistema debe permitir cargar y ejecutar distintos programas sin volver a sintetizar la FPGA. Al comenzar una nueva programación puede existir estado residual de una ejecución anterior en el PC, banco de registros, memoria de datos, memoria de instrucciones, registros intermedios del pipeline, estado de ejecución y estructuras auxiliares de debug.

Como el trabajo práctico no requiere comunicación ni persistencia de estado entre programas distintos, conservar ese estado introduciría dependencias entre ejecuciones y dificultaría la reproducibilidad, la verificación y la depuración.

Esta decisión define el estado lógico que debe presentar el sistema cuando una reprogramación se completa correctamente. `DEC-ARCH-008` selecciona por separado el reset global como recuperación mínima de una ejecución no terminante y rechaza el inicio directo de LOAD mientras RUN permanece activo.

**Opciones consideradas:**

1. Conservar el estado arquitectónico y de memoria de la ejecución anterior, reemplazando únicamente la memoria de instrucciones.
2. Conservar selectivamente registros o memoria de datos para permitir persistencia entre programas.
3. Reinicializar el estado asociado a la ejecución anterior y tratar cada programa cargado como una nueva sesión independiente.
4. Dejar la política de reinicialización a criterio de cada módulo sin establecer una semántica global.

**Decisión:** Cada reprogramación completada correctamente establecerá una **nueva sesión de ejecución independiente** de cualquier programa ejecutado previamente.

El nuevo programa deberá comenzar desde un estado inicial conocido y reproducible. Para ello:

- el pipeline asociado a la ejecución anterior deberá quedar lógicamente vacío o inválido;
- el PC deberá quedar preparado en el punto de entrada definido para una nueva ejecución;
- los registros `x0` a `x31` deberán presentar el valor lógico inicial cero;
- toda ubicación de memoria de datos que todavía no haya sido escrita durante la nueva sesión deberá devolver el valor lógico cero;
- la memoria de instrucciones deberá considerar válidas únicamente las palabras incluidas en la nueva imagen cargada;
- cualquier dirección de instrucciones no incluida en la nueva imagen deberá quedar lógicamente no cargada y no podrá exponer como válida una instrucción residual del programa anterior;
- una dirección de instrucciones no cargada no se interpretará como `halt`; `DEC-ARCH-001` define el intento de fetch fuera de imagen y `DEC-ARCH-004` deberá definir por separado las codificaciones inválidas;
- cualquier estado utilizado para identificar memoria de datos utilizada deberá reinicializarse de modo que el conjunto lógico de posiciones utilizadas comience vacío;
- los indicadores y estados transitorios asociados a la ejecución anterior, incluyendo finalización, drenado y errores que no deban persistir, deberán dejar de aplicarse;
- la Debug Unit no deberá presentar información residual de la ejecución anterior como si perteneciera al nuevo programa.

Estas garantías son lógicas y observables. No obligan a borrar físicamente cada celda de memoria o registro: podrán implementarse mediante borrado, marcas de validez, identificadores de generación u otro mecanismo equivalente.

La finalización correcta de la carga dejará al sistema en un estado preparado para comenzar una nueva ejecución, pero **no iniciará automáticamente RUN ni STEP**.

Desde que el sistema acepta el inicio de una nueva carga, la imagen ejecutable dejará de considerarse válida. Hasta que la carga finalice correctamente, RUN y STEP deberán rechazarse o permanecer sin efecto según el protocolo que se defina. Una carga incompleta, inválida o fallida no volverá ejecutable la imagen parcial nueva ni una mezcla de esta con instrucciones de la imagen anterior. El sistema permanecerá sin una imagen ejecutable válida hasta que una carga posterior se complete correctamente.

Esta política de fallo cerrado no exige conservar o restaurar atómicamente el programa anterior, implementar rollback ni disponer de doble almacenamiento para la memoria de instrucciones.

`DEC-ARCH-001` fija el punto de entrada en `0x00000000`. La lógica de reinicialización deberá garantizar que el PC quede preparado en ese punto.

Los mecanismos concretos utilizados para reinicializar memorias, registros, pipeline, PC y demás estructuras se definirán durante el diseño de arquitectura y microarquitectura.

Esta decisión no establece que la reprogramación sea el mecanismo obligatorio de recuperación de una ejecución no terminante. `DEC-ARCH-008` determina que LOAD se rechaza durante contexto continuo y que reset global lleva previamente al sistema a un estado controlado desde el cual puede solicitarse una nueva carga.

**Justificación:** Tratar cada programa como una nueva sesión independiente evita dependencias accidentales con ejecuciones anteriores y permite que un mismo programa, ejecutado bajo las mismas condiciones de entrada, comience desde el mismo estado observable.

Definir registros y memoria de datos con valor lógico inicial cero hace verificable la reproducibilidad sin imponer una estrategia física de limpieza. Del mismo modo, invalidar toda dirección que no pertenezca a la nueva imagen evita que un programa más corto ejecute accidentalmente instrucciones residuales de una imagen anterior.

La política de fallo cerrado impide ejecutar imágenes parciales o mezcladas sin exigir mecanismos costosos de rollback o doble buffer.

Esta política simplifica la comparación entre simulación, modelo de referencia y FPGA real, reduce la cantidad de estados históricos que deben considerarse durante la depuración y evita que valores residuales en registros, memoria o pipeline oculten errores o alteren resultados.

Conservar estado entre programas no aporta una capacidad requerida por el trabajo práctico y aumentaría innecesariamente la complejidad del sistema.

La separación entre reprogramación y recuperación externa mantiene además desacopladas dos responsabilidades diferentes: esta decisión especifica cómo debe quedar el sistema cuando una nueva programación se completa correctamente, mientras que `DEC-SYS-002` únicamente exige que exista alguna vía para recuperar el control de una ejecución no terminante.

**Consecuencias:**

- cada programa cargado correctamente se considera una nueva sesión de ejecución;
- los registros `x0` a `x31` comienzan lógicamente en cero;
- la memoria de datos comienza lógicamente en cero y sin posiciones consideradas utilizadas;
- el pipeline comienza sin instrucciones válidas pertenecientes al programa anterior;
- el PC comienza desde el punto de entrada definido para el nuevo programa;
- solo las instrucciones incluidas en la nueva imagen se consideran cargadas y válidas;
- el nuevo programa no puede ejecutar como válida una instrucción residual de una imagen anterior;
- una posición de instrucciones no cargada no equivale a `halt`;
- los estados de finalización, drenado y error anteriores no se confunden con el estado de la nueva ejecución;
- la información de debug correspondiente a la ejecución anterior no se presenta como estado actual del nuevo programa;
- cargar correctamente un programa deja al sistema preparado pero detenido;
- RUN y STEP continúan siendo operaciones separadas de la carga;
- desde que el sistema acepta el comienzo de LOAD y hasta su finalización exitosa no existe una imagen ejecutable válida;
- una carga parcial, inválida o fallida mantiene RUN y STEP rechazados o sin efecto hasta una carga válida posterior;
- no se exige rollback, conservación atómica de la imagen anterior ni doble buffer;
- no se prescribe si la limpieza se realizará mediante borrado físico, marcas de validez, generaciones u otro mecanismo equivalente;
- `DEC-ARCH-001` define el punto de entrada exacto y la semántica de posiciones de instrucciones no cargadas;
- `DEC-ARCH-008` define las condiciones de commit que exigen PC, pipeline y control en el estado inicial establecido, sin imponer una secuencia RTL concreta;
- reprogramar no es una vía implícita de aborto o recuperación durante RUN;
- `DEC-ARCH-008` rechaza LOAD mientras existe contexto continuo y selecciona reset global como recuperación mínima previa.

**Requisitos afectados:** `REQ-CPU-009` a `REQ-CPU-013`, `REQ-CPU-016`, `REQ-MEM-003` a `REQ-MEM-005`, `REQ-MEM-007` a `REQ-MEM-009`, `REQ-EXEC-016`, `REQ-EXEC-017`, `REQ-UART-002`, `REQ-DBG-002` a `REQ-DBG-012`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-002`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-SYS-004 — Capacidades iniciales de memoria

**Estado:** Aprobada

**Dominio:** Sistema / Memorias

**Fecha de aprobación:** 2026-09-20

**Contexto:** El sistema requiere una memoria de instrucciones para almacenar los programas cargados y una memoria de datos para soportar las operaciones de acceso a memoria del procesador.

La consigna exige documentar sus capacidades, pero no establece valores concretos. El proyecto necesita, por lo tanto, definir una configuración de referencia reproducible para desarrollo, simulación, síntesis, validación y ejecución sobre FPGA, sin convertir dichos valores en constantes rígidas distribuidas por toda la implementación.

Al mismo tiempo, debe preservarse la posibilidad de sintetizar configuraciones con capacidades diferentes sin modificar la lógica funcional del procesador.

Por `DEC-SYS-003`, la capacidad máxima disponible en Instruction Memory es independiente de la cantidad de instrucciones pertenecientes a la imagen actualmente cargada. Una posición físicamente disponible no se considera válida por el solo hecho de encontrarse dentro de la capacidad implementada.

**Opciones consideradas:**

1. Fijar capacidades constantes y hardcodeadas independientemente en cada módulo.
2. Permitir capacidades parametrizables sin establecer una configuración común de referencia.
3. Definir capacidades parametrizables en tiempo de elaboración o síntesis junto con un perfil de referencia aprobado para el TP.
4. Permitir modificar dinámicamente las capacidades de las memorias durante la ejecución.

**Decisión:** Las capacidades de Instruction Memory y Data Memory deberán ser **configurables en tiempo de elaboración o síntesis**, mediante parámetros o una configuración autoritativa equivalente.

Se establece como **perfil de referencia del TP**:

- **Instruction Memory:** `1024 bytes` de capacidad lógica;
- **Data Memory:** `2048 bytes` de capacidad lógica.

Dado que el conjunto de instrucciones soportado actualmente utiliza instrucciones de 32 bits y no incorpora instrucciones comprimidas, los `1024 bytes` de Instruction Memory permiten almacenar como máximo **256 instrucciones** en el perfil de referencia.

Esta equivalencia expresa únicamente capacidad y no impone que la memoria de instrucciones deba organizarse físicamente como un array de palabras de 32 bits.

Las capacidades configuradas permanecerán constantes durante toda la ejecución del bitstream. Modificar dichas capacidades podrá requerir una nueva síntesis e implementación de la FPGA.

Las dimensiones, límites, contadores, comparaciones y demás elementos que dependan de estas capacidades deberán derivarse de una configuración autoritativa y no de constantes numéricas independientes repetidas en distintos componentes.

CPU, memorias, lógica de carga, Debug, protocolo, verificación y software de PC deberán operar con límites coherentes con el perfil sintetizado. El mecanismo concreto mediante el cual dichos componentes compartirán o conocerán esa configuración se definirá posteriormente.

Una imagen de programa que exceda la capacidad configurada de Instruction Memory no podrá considerarse cargada exitosamente.

Para el perfil de referencia:

- una imagen de hasta `256` instrucciones puede caber en Instruction Memory;
- una imagen de más de `256` instrucciones no puede finalizar con una carga exitosa.

Esta regla define únicamente la condición de capacidad. El mecanismo de detección, la respuesta del protocolo y el código de error correspondiente se definirán posteriormente.

Una imagen más corta que la capacidad máxima solo hará válidas las palabras que efectivamente formen parte de la nueva imagen cargada, conforme a `DEC-SYS-003`. La capacidad no determina por sí sola la validez de las posiciones restantes.

`DEC-ARCH-001` define la granularidad, los anchos derivados y los límites legales de configuraciones alternativas. La política de alineación de cada acceso permanece separada en `DEC-ARCH-004`.

Esta decisión no determina:

- organización interna en bytes o palabras;
- ancho concreto de los buses de dirección;
- direcciones base ni mapa de memoria;
- punto de entrada numérico;
- comportamiento ante accesos fuera de rango;
- cantidad, tipo o arbitraje de puertos;
- lectura síncrona o combinacional;
- utilización de BRAM, RAM distribuida, registros o IP;
- mecanismo físico de inicialización o limpieza;
- representación concreta de validez de instrucciones o datos;
- formato del protocolo de carga o de sus errores.

**Justificación:** Una configuración de referencia concreta permite que simulación, testbenches, síntesis, FPGA y software trabajen sobre límites conocidos y reproducibles.

El perfil de `1024 bytes` de Instruction Memory proporciona espacio para hasta `256` instrucciones del ISA actualmente soportado, cantidad suficiente como configuración inicial para programas de prueba, diagnóstico y demostración del trabajo práctico.

Los `2048 bytes` de Data Memory proporcionan un espacio de datos razonable para cargas, almacenamientos, arreglos y programas de prueba sin sobredimensionar prematuramente los recursos de FPGA.

Estas capacidades no implican que Debug deba transmitir la memoria completa. La definición de qué posiciones de memoria de datos se consideran utilizadas permanece separada y se resolverá posteriormente.

Parametrizar las capacidades evita que una elección realizada durante esta etapa se convierta innecesariamente en una restricción estructural permanente. Una configuración distinta puede obtenerse mediante elaboración o resíntesis sin exigir cambios en la lógica funcional, siempre que respete las restricciones arquitectónicas que se definan posteriormente.

Derivar límites y dimensiones de una configuración autoritativa reduce además el riesgo de inconsistencias entre RTL, loader, Debug, tests y software.

Finalmente, separar capacidad lógica de organización física evita comprometer anticipadamente una tecnología concreta de memoria antes de analizar recursos, temporización e inferencia sobre FPGA.

**Consecuencias:**

- el perfil oficial de referencia del TP utiliza `1024 bytes` de Instruction Memory y `2048 bytes` de Data Memory;
- en dicho perfil, Instruction Memory tiene capacidad máxima equivalente a `256` instrucciones de 32 bits;
- las capacidades son parámetros de elaboración o síntesis y no variables modificables durante ejecución;
- cambiar las capacidades puede requerir generar un nuevo bitstream;
- reprogramar el contenido dentro de la capacidad ya sintetizada no requiere modificar dicha capacidad;
- los límites dependientes de memoria deben derivarse de una configuración autoritativa;
- no deben mantenerse números mágicos independientes para representar las mismas capacidades en distintos componentes;
- el loader del perfil de referencia no puede confirmar exitosamente una imagen que exceda `1024 bytes` de instrucciones;
- una imagen con menos de `256` instrucciones no convierte automáticamente las posiciones restantes en instrucciones válidas;
- capacidad máxima e imagen válida actual son conceptos diferentes;
- la capacidad total de Data Memory es independiente del subconjunto de posiciones que posteriormente se considere utilizado;
- Debug, protocolo, tests y software deberán permanecer coherentes con el perfil sintetizado;
- una configuración alternativa deberá poder obtenerse sin modificar la lógica funcional dependiente únicamente de capacidad;
- la síntesis del perfil de referencia deberá utilizarse posteriormente para evaluar utilización de recursos y timing;
- no se fija todavía organización, direccionamiento, tecnología, puertos, temporización ni representación física de las memorias;
- `DEC-ARCH-001` transforma estas capacidades en una organización y esquema de direccionamiento concretos;
- `DEC-ARCH-006` selecciona el contrato físico inicial, el perfil físico obligatorio y el perfil alternativo de validación;
- las decisiones posteriores de Debug, UART, protocolo y software deberán respetar la capacidad configurada sin asumir que los valores del perfil de referencia son universales.

**Requisitos afectados:** `REQ-MEM-001`, `REQ-MEM-002`, `REQ-MEM-003`, `REQ-MEM-004`, `REQ-MEM-005`, `REQ-MEM-009`, `REQ-MEM-010`, `REQ-MEM-011`, `REQ-MEM-012`, `REQ-EXEC-017`, `REQ-UART-002`, `REQ-DBG-002`, `REQ-SW-004`, `REQ-SW-010`, `REQ-DOC-007`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-SYS-005 — Criterio de memoria de datos utilizada

**Estado:** Aprobada

**Dominio:** Sistema / Debug / Memoria

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La consigna pide mostrar la memoria de datos utilizada. Es necesario fijar qué posiciones pertenecen a ese conjunto, cómo se representan stores parciales y ceros escritos, y cómo delimitar una lista vacía o de longitud variable.

**Opciones consideradas:** Selección por bytes escritos frente a words/rangos o valores distintos de cero; lista de dirección/valor actual frente a volcado completo o historial de cambios. Se seleccionaron bytes escritos y lista completa del estado actual durante la discusión de D04/D05.

**Decisión:** Son utilizados los bytes escritos por stores CPU comprometidos en la sesión actual, incluidos valores cero. SB/SH/SW incorporan 1/2/4 bytes al commit; lecturas y preparación no incorporan entradas. Sobrescribir actualiza el valor sin duplicar una dirección. Cada sesión nueva comienza vacía, incluido reiniciar la misma imagen desde FINISHED/FAULT.

Cada snapshot contiene la lista completa de direcciones utilizadas, únicas y crecientes, y sus valores actuales en el mismo instante coherente. No incluye huecos no escritos, historial ni deltas. La lista se coloca al final del cuerpo, precedida por `used_count`: unsigned de cinco bytes little-endian, entre cero y la capacidad de DMEM inclusive. Cada entrada contiene dirección de cuatro bytes little-endian y valor de un byte. Cantidad cero se representa con cinco bytes cero y ninguna entrada; la cantidad determina exactamente la longitud y el final.

El [acuerdo de criterio](#acuerdo-parcial-de-dec-sys-005--memoria-utilizada-como-bytes-escritos-en-la-sesión) y el [acuerdo de layout](#acuerdo-parcial-de-dec-proto-001--orden-y-delimitación-del-snapshot) detallan selección, ejemplos, offsets y longitudes.

**Justificación:** La unidad byte representa stores parciales y conserva escrituras de cero. Dirección/valor actual evita confundir el contenido observable con historial; la cantidad de cinco bytes cubre capacidades hasta 2^32 sin un caso especial para la lista vacía.

**Consecuencias:** Puede reutilizarse la metadata de validez por byte de referencia; no se exige un segundo bitmap ni un contador persistente adicional. La captura, recorrido, ownership y serialización física se completan en D06 y diseño de bloques, respetando coherencia y semántica lógica de DMEM. Quedan fuera de este identificador los códigos y las reglas comunes todavía pendientes del protocolo. Esta aprobación cierra el diseño de criterio y representación; no acredita implementación.

**Requisitos afectados:** `REQ-MEM-008`, `REQ-MEM-019`, `REQ-MEM-028`, `REQ-MEM-029`, `REQ-DBG-010`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-009`, `REQ-DOC-005`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de criterio y layout; conserva los contratos de memoria y coherencia aprobados.

---

### DEC-SYS-006 — Información observable mediante Debug

**Estado:** Aprobada

**Dominio:** Sistema / Debug

**Fecha de aprobación:** 2026-09-20

**Contexto:** La consigna requiere una unidad de Debug capaz de permitir la observación del estado del procesador desde el software de PC, incluyendo como mínimo el banco de registros, los registros intermedios del pipeline y la memoria de datos utilizada.

Para que esta observabilidad sea útil tanto durante el desarrollo como durante la ejecución paso a paso, es necesario definir qué información constituye el estado observable del sistema antes de establecer el formato concreto del protocolo UART o la representación exacta de los registros intermedios.

La Debug Unit debe proporcionar suficiente información para reconstruir e interpretar el estado del pipeline en un ciclo determinado, sin convertirse en una exposición indiscriminada de todas las señales combinacionales internas del procesador.

La decisión debe mantener una separación clara entre:

- el **estado que conceptualmente debe ser observable**;
- la **representación física de dicho estado dentro del procesador**;
- el **formato utilizado para transportarlo por UART**;
- la **forma en que el software de PC lo presenta al usuario**.

**Opciones consideradas:**

1. Exponer únicamente la información mínima explícitamente exigida por la consigna: banco de registros, memoria de datos utilizada y una identificación básica de las instrucciones presentes en el pipeline.
2. Exponer para cada etapa únicamente `instruction`, `PC` y una indicación de validez.
3. Exponer de manera indiscriminada el contenido completo de todos los registros intermedios y numerosas señales internas del datapath y control.
4. Exponer el estado arquitectónico completo y una representación semánticamente suficiente del estado registrado del pipeline, incluyendo información adicional de contexto, pero excluyendo por defecto las señales puramente combinacionales internas.

**Decisión:** Se adopta la opción 4.

La Debug Unit deberá permitir obtener una representación coherente del estado observable del sistema, denominada conceptualmente **snapshot de Debug**.

Cada snapshot deberá contener, como mínimo:

- un identificador del **ciclo de ejecución** al que corresponde;
- el **PC actual** del procesador;
- el **estado global de ejecución**;
- una indicación de si existe una **imagen de programa válida y ejecutable**;
- el contenido de los **32 registros arquitectónicos** `x0` a `x31`;
- el estado observable de los cuatro registros intermedios del pipeline:
  - `IF/ID`;
  - `ID/EX`;
  - `EX/MEM`;
  - `MEM/WB`;
- el subconjunto de **Data Memory considerado utilizado**, conforme al criterio que establezca `DEC-SYS-005`.

Para cada registro intermedio del pipeline deberá ser observable, como mínimo:

- una indicación explícita de **validez**;
- el **PC asociado a la instrucción** almacenada en dicho registro;
- la **instrucción de 32 bits** asociada;
- los demás datos y señales de control **registrados** que sean necesarios para interpretar correctamente el estado y la evolución de esa instrucción dentro del pipeline.

La lista exacta de campos adicionales de cada registro intermedio no se fija en esta decisión. Será definida por `DEC-ARCH-009` una vez establecida la estructura concreta de los latches del pipeline.

La indicación de validez deberá distinguir entre una instrucción activa y una entrada inactiva. Con `valid = 0`, los demás bits del registro intermedio no representarán una instrucción activa, aunque conserven contenido residual.

No será obligatorio que Debug distinga la causa por la que una entrada se encuentra inactiva. Una burbuja, una entrada invalidada por un flush, una posición vacía durante el llenado o drenado y otras causas podrán compartir la misma representación inactiva.

El **PC global** y el **PC asociado a cada latch** son conceptos diferentes y ambos deberán poder representarse:

- el PC global describe el estado actual del frente de búsqueda de instrucciones;
- el PC almacenado junto a una instrucción permite identificar la dirección de origen de dicha instrucción mientras avanza por el pipeline.

El **estado global de ejecución** deberá proporcionar información suficiente para que el software distinga las situaciones semánticamente relevantes establecidas por las decisiones del sistema, incluyendo al menos los casos equivalentes a:

- sistema preparado pero sin ejecución activa;
- ejecución continua;
- ejecución paso a paso;
- drenado posterior a un `halt`;
- ejecución finalizada normalmente;
- ausencia de una imagen válida;
- carga o reprogramación en progreso, cuando corresponda;
- estados de error o interrupción externa que se definan posteriormente.

Estas categorías observables se realizan con la FSM de 14 estados del acuerdo 44 de `DEC-ARCH-003`; su codificación binaria y representación UART siguen abiertas.

La indicación de **imagen válida** deberá permitir diferenciar un sistema preparado para ejecutar un programa correctamente cargado de un sistema que no posee una imagen ejecutable, por ejemplo después de una reprogramación incompleta o fallida conforme a `DEC-SYS-003`.

El identificador de ciclo será un contador lógico de avances efectivos del procesador dentro de la sesión actual. Comenzará en cero al preparar cada nueva sesión (por LOAD o por RUN/STEP desde FINISHED/FAULT) e incrementará exactamente una vez por cada ciclo habilitado de ejecución, tanto en RUN como en STEP. También contará ciclos habilitados en los que exista un stall y ciclos de drenado.

El contador no avanzará mientras el procesador espere un nuevo STEP, durante una carga o reprogramación ni por ciclos del clock funcional con actividad exclusiva de UART o control externo. Su ancho y overflow quedan fijados por la revisión aprobada siguiente.

#### Revisión aprobada de DEC-SYS-006 — contador lógico de 64 bits (AUD-005)

**Fecha:** 2026-09-26. **Estado:** Aprobada como revisión de esta decisión, sin nuevo identificador.

Se cierra el pendiente original de ancho y overflow: `cycle_count[63:0]` será **unsigned de 64 bits**. La referencia original que difería estos aspectos queda sustituida por esta revisión.

```text
reset o inicialización efectiva de una nueva sesión → cycle_count = 0
cpu_cycle_fire = 1 → cycle_count.next = (cycle_count + 1) mod 2^64
sin acción superior y cpu_cycle_fire = 0 → cycle_count.next = cycle_count
0xFFFFFFFFFFFFFFFF + 1 → 0x0000000000000000
```

Cuenta exactamente una vez por ciclo CPU efectivo, incluidos stalls, bubbles, redirects, confirmaciones y drenado. HOLD y la actividad exclusiva de Loader, UART, Debug o mantenimiento no incrementan el contador. Reset e inicialización conservan su prioridad; antes del primer ciclo de toda sesión el valor es cero y después es uno. En `PREPARING_RUN/STEP && prepare_done`, la preparación ya terminó antes del flanco y ese flanco ejecuta el primer ciclo; `PREPARING_READY && prepare_done` queda en READY con cero, conforme al acuerdo 44 de `DEC-ARCH-003`.

El wrap-around **no constituye un fault**, no detiene ni altera la ejecución, no modifica `global_state`, no genera flags y no requiere estado persistente adicional. Se eligen 64 bits para que el wrap sea irrelevante en ejecuciones prácticas, sin lógica especial de saturación u overflow. El contador continúa siendo un identificador lógico observable por Debug; no es un identificador ilimitado o globalmente único entre sesiones.

El orden de bytes, framing y demás representación UART de los 64 bits permanecen pendientes en las decisiones de protocolo. Esta revisión no los fija.

#### Coherencia y representación del snapshot

Todo snapshot deberá ser **internamente coherente**: los registros, PC, latches, estado de ejecución, memoria utilizada y demás información dinámica que lo integran deberán representar un mismo estado lógico del procesador.

No deberá producirse un snapshot que combine, por ejemplo, registros correspondientes a un ciclo con latches correspondientes a otro ciclo como consecuencia del tiempo requerido para transmitir la información por UART.

El mecanismo concreto para garantizar esta coherencia —captura temporal, congelamiento, shadow registers, lectura mientras el procesador está detenido u otra estrategia equivalente— se definirá posteriormente.

Esta decisión no obliga a que los snapshots puedan solicitarse arbitrariamente mientras el procesador ejecuta en modo continuo. Los momentos en los que Debug puede capturar o transmitir información y su interacción con RUN y STEP se definirán junto con las interfaces y el protocolo.

Las capacidades configuradas de Instruction Memory y Data Memory no forman parte de la información obligatoria de Debug ni necesitan incluirse en el snapshot. Para esta decisión es suficiente que el software utilice una configuración externa coherente con el perfil sintetizado conforme a `DEC-SYS-004`. Una decisión posterior podrá permitir reportar opcionalmente capacidades o un identificador de perfil.

No forma parte del estado obligatorio de Debug la exposición de todas las señales internas puramente combinacionales, tales como:

- selecciones internas de multiplexores;
- resultados intermedios no registrados;
- comparadores temporales;
- señales combinacionales de forwarding;
- señales combinacionales de detección de hazards;
- codificaciones internas de control que no formen parte del estado registrado.

La implementación podrá exponer información adicional con fines de diagnóstico siempre que ello no convierta dichos detalles en parte necesaria del contrato funcional del sistema.

El criterio general será:

> El Debug deberá describir el estado arquitectónico del procesador y el estado microarquitectónico persistente necesario para comprender la evolución de las instrucciones por el pipeline, sin exigir la exposición de cada señal interna transitoria.

Esta decisión define **qué información debe ser observable** y, mediante la revisión de AUD-005, el ancho y comportamiento del contador lógico.

No determina:

- la codificación concreta del estado global de ejecución;
- el formato binario de un snapshot;
- el orden de transmisión de sus campos;
- comandos UART;
- framing, longitudes, endianness o checksum;
- códigos de respuesta o error;
- mecanismo de captura o congelamiento del snapshot;
- formato interno exacto de cada latch;
- representación física de `valid`;
- representación visual en el software de PC;
- criterio exacto de Data Memory utilizada;
- frecuencia o momento en que se permite solicitar información durante una ejecución continua;
- mecanismo concreto por el que el software conoce el perfil de memoria sintetizado.

**Justificación:** Exponer únicamente la instrucción presente en cada etapa permite una visualización simple del pipeline, pero resulta insuficiente para diagnosticar errores en operandos, resultados de ALU, accesos a memoria, writeback o propagación de señales de control.

En el extremo opuesto, exponer indiscriminadamente todas las señales internas acoplaría excesivamente Debug a la implementación concreta del datapath y aumentaría innecesariamente el volumen de información, la complejidad del protocolo y la dependencia del software respecto del RTL.

La solución adoptada utiliza como frontera principal el **estado registrado** entre etapas. Los registros intermedios representan puntos naturales de observación porque contienen el estado persistente que una instrucción transporta de una etapa a la siguiente.

Incluir explícitamente `valid`, PC e instrucción facilita la interpretación humana del pipeline y permite distinguir correctamente instrucciones activas de entradas inactivas sin imponer metadata adicional sobre la causa de cada invalidación.

La observación de los demás campos registrados relevantes permite además diagnosticar errores internos sin necesidad de exponer todas las señales combinacionales del procesador.

El PC global proporciona contexto sobre el frente de búsqueda, mientras que los PCs asociados a las instrucciones permiten seguir una instrucción concreta a medida que avanza por el pipeline.

Un identificador lógico de ciclo facilita la correlación entre hardware, simulación, testbench, software de PC y modelo de referencia sin confundir el avance del procesador con la actividad del clock físico durante pausas, carga o comunicación.

Finalmente, exigir coherencia interna del snapshot evita que la lentitud relativa de UART produzca una representación que nunca haya existido realmente en el procesador.

**Consecuencias:**

- Debug deberá disponer de acceso al banco completo de registros;
- deberá disponer del PC global;
- deberá poder observar los cuatro registros intermedios del pipeline;
- cada latch deberá disponer de una noción observable de validez binaria;
- las instrucciones deberán poder asociarse con su PC mientras atraviesan el pipeline;
- los latches deberán exponer suficiente estado registrado para interpretar el procesamiento de cada instrucción;
- `DEC-ARCH-009` deberá definir exactamente qué campos forman parte de cada latch y cuáles de ellos constituyen su representación de Debug;
- la arquitectura deberá permitir construir snapshots coherentes aunque la transmisión UART sea mucho más lenta que el procesador;
- Debug deberá permitir distinguir una imagen válida de la ausencia de programa ejecutable;
- el software podrá identificar el estado global de ejecución sin inferirlo indirectamente a partir de otros datos;
- el contador lógico de ciclo comenzará en cero con cada nueva sesión y contará únicamente ciclos habilitados de ejecución;
- la memoria reportada por Debug no queda definida simplemente como toda la capacidad de Data Memory; dependerá de `DEC-SYS-005`;
- no se obliga a exponer todas las señales combinacionales internas;
- no se obliga a reportar capacidades de memoria ni un identificador de perfil mediante Debug;
- el protocolo posterior deberá poder representar todo el contenido aprobado por esta decisión;
- el software de PC deberá ser capaz de interpretar y presentar esta información;
- la implementación concreta del snapshot no queda fijada en esta decisión;
- la existencia del snapshot no obliga a permitir consultas arbitrarias durante RUN.

**Requisitos afectados:** `REQ-CPU-009` a `REQ-CPU-012`, `REQ-CPU-016`, `REQ-EXEC-007`, `REQ-EXEC-010`, `REQ-UART-005`, `REQ-DBG-004` a `REQ-DBG-010`, `REQ-DBG-012` a `REQ-DBG-016`, `REQ-SW-006` a `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-SYS-010 — Versión del ISA

**Estado:** Aprobada

**Dominio:** Sistema / ISA

**Fecha de aprobación:** 2026-09-19

**Contexto:** La consigna define el subconjunto de instrucciones RISC-V requerido, pero no identifica una versión concreta del estándar para determinar sus codificaciones y su semántica exacta.

**Opciones consideradas:**

1. Utilizar una referencia RISC-V sin fijar versión.
2. Adoptar automáticamente la revisión más reciente disponible.
3. Adoptar RISC-V User-Level ISA V2.2, que es la versión declarada como base por la documentación indicada para el trabajo.

**Decisión:** Utilizar el subconjunto requerido de **RV32I según RISC-V User-Level ISA V2.2**.

**Justificación:** Fijar una versión evita que CPU, assembler, modelo de referencia y tests interpreten de forma diferente las codificaciones o la semántica de una instrucción. La documentación proporcionada declara que está basada en User-Level ISA V2.2.

**Referencia:** <https://msyksphinz-self.github.io/riscv-isadoc/>

**Consecuencias:**

- el procesador debe utilizar codificaciones y efectos arquitectónicos compatibles con esa versión;
- el assembler debe generar esas mismas codificaciones;
- el modelo de referencia y los tests deben aplicar la misma semántica;
- cualquier cambio de versión requiere revisar y reemplazar explícitamente esta decisión.

**Requisitos afectados:** `REQ-CPU-001`, `REQ-CPU-013` a `REQ-CPU-015`, `REQ-ISA-001` a `REQ-ISA-033`, `REQ-MEM-006`, `REQ-HAZ-009`, `REQ-SW-003`.

**Reemplaza / Reemplazada por:** No aplica.

---

## 4. CPU y arquitectura

### DEC-ARCH-001 — Organización y comportamiento de las memorias

**Estado:** Aprobada

**Dominio:** CPU / Memorias

**Fecha de aprobación:** 2026-09-21

**Contexto:** Las capacidades de Instruction Memory y Data Memory aprobadas en `DEC-SYS-004` deben transformarse en un contrato arquitectónico inequívoco. Es necesario definir la unidad de direccionamiento, el mapa lógico, el punto de entrada, la relación entre capacidad e imagen cargada, los límites de acceso, la concurrencia mínima, las restricciones de parametrización, el orden de bytes y la representación de validez de una imagen.

La organización debe preservar la reinicialización lógica y el fallo cerrado establecidos por `DEC-SYS-003`, distinguir faults de la finalización normal de `DEC-SYS-001` y `DEC-SYS-002`, y evitar que decisiones de conveniencia física se conviertan en restricciones arquitectónicas innecesarias.

**Opciones consideradas:**

1. Direccionamiento por palabras o direccionamiento por bytes.
2. Un único espacio de memoria o espacios Harvard lógicamente independientes.
3. Truncar direcciones fuera de rango, permitir wrap-around o validar explícitamente la región completa de cada acceso.
4. Exigir memorias multiport o definir solamente ownership y demanda lógica mínima.
5. Admitir cualquier capacidad positiva, exigir potencias de dos, exigir múltiplos de cuatro o fijar únicamente el perfil de referencia.
6. Utilizar little-endian, big-endian u órdenes diferentes entre Instruction Memory y Data Memory.
7. Representar la imagen cargada mediante borrado físico, un bitmap por instrucción o un prefijo contiguo descrito por tamaño y validez global.

**Decisión:** Se adopta el siguiente contrato integral.

#### Unidad direccionable, mapa y punto de entrada

Instruction Memory y Data Memory serán arquitectónicamente **byte-addressed**. El PC, los destinos de control y las direcciones efectivas de loads y stores representarán posiciones medidas en bytes.

El ISA soportado contiene únicamente instrucciones de 32 bits y no incluye instrucciones comprimidas. Por ello, el flujo secuencial avanzará mediante `PC + 4` y cada fetch obtendrá una instrucción completa de 32 bits.

Los accesos de Data Memory tendrán las siguientes granularidades:

- `lb`, `lbu` y `sb`: 1 byte;
- `lh`, `lhu` y `sh`: 2 bytes;
- `lw` y `sw`: 4 bytes.

El sistema utilizará una arquitectura **Harvard lógica**, con espacios independientes para Instruction Memory y Data Memory:

```text
IMEM_BASE   = 0x00000000
DMEM_BASE   = 0x00000000
ENTRY_POINT = 0x00000000
```

El mismo valor numérico de dirección podrá identificar simultáneamente posiciones distintas de IMEM y DMEM sin aliasing entre ambos espacios.

Los rangos lógicos se derivarán de las capacidades configuradas:

```text
0 <= imem_address < IMEM_CAPACITY_BYTES
0 <= dmem_address < DMEM_CAPACITY_BYTES
```

En el perfil de referencia, IMEM ocupa `0x00000000` a `0x000003FF`, sus comienzos alineados de instrucción llegan hasta `0x000003FC`, y DMEM ocupa `0x00000000` a `0x000007FF`. Estos valores no serán constantes universales.

Después de una carga exitosa, el PC quedará preparado en `0x00000000` sin iniciar automáticamente RUN ni STEP. No se requiere un punto de entrada configurable.

#### Validación de rango y faults de memoria

**Aclaración aprobada de AUD-004 (2026-09-26):** la generación de la dirección efectiva y la validación de su región son dos sumas distintas. Para loads/stores, con el inmediato con signo extendido a 32 bits y el operando tras forwarding:

```text
effective_address = (rs1_effective + immediate) mod 2^32
```

La primera suma sigue la aritmética arquitectónica de 32 bits. **El carry de `rs1 + immediate` no constituye por sí mismo un fault**; el resultado modular es la dirección arquitectónica que se comprueba. La prohibición de wrap-around/aliasing al acceder a memoria se aplica a la región y a la indexación física, no a esta generación de dirección.

La validez de rango se comprobará después sobre todos los bytes del acceso, antes de transformar la dirección arquitectónica en un índice interno. Para DMEM, con `N=1/2/4` bytes, se exige:

```text
{1'b0, effective_address} + N <= DMEM_CAPACITY_BYTES
```

Esta segunda suma y la comparación son sin signo y ensanchadas a **33 bits**, con `N` y la capacidad representados sin truncamiento; pueden representar el límite exclusivo `2^32` y detectar un extremo que lo exceda. No se reduce `effective_address + N` módulo `2^32`. En forma general, para IMEM o DMEM se verifica con esa aritmética ensanchada una condición equivalente a:

```text
address + N <= CAPACITY_BYTES
```

o `address <= CAPACITY_BYTES - N` bajo las precondiciones correspondientes.

Un fetch candidato será válido por rango únicamente si sus cuatro bytes se encuentran dentro de IMEM y pertenecen a la imagen confirmada. La alineación se verificará separadamente conforme a `DEC-ARCH-004`.

Una posición dentro de capacidad pero fuera de la imagen no expondrá una instrucción residual, no se interpretará como `halt` ni entregará una instrucción ejecutable. Un fetch fuera de imagen o capacidad generará un candidato de fault.

Cada byte de DMEM dentro de capacidad que no haya sido escrito durante la sesión devolverá cero lógico conforme a `DEC-SYS-003`. Loads y stores validarán todos los bytes antes de acceder:

- un store inválido no modificará ningún byte;
- un load inválido no escribirá `rd`;
- no habrá efectos parciales, wrap-around de la región ni aliasing por truncamiento al formar índices físicos; se conserva el wrap arquitectónico normal al generar la dirección efectiva.

Un candidato de fault solo se convertirá en fault arquitectónico si la operación pertenece al flujo válido. Si una instrucción anterior descarta la operación por branch, jump, `halt` u otra causa, el candidato también se descartará.

Un fault aceptado será distinto de FINISHED. La operación causante y todas las instrucciones posteriores carecerán de efectos arquitectónicos. El tratamiento de anteriores, detección, prioridad y detención está fijado por `DEC-ARCH-004` y los acuerdos 40–47 de `DEC-ARCH-003`; el reporte externo corresponde a protocolo.

#### Ownership, puertos y concurrencia

Instruction Memory tendrá como agentes conceptuales a la CPU, que realiza fetch, y al loader, que escribe durante carga. No se requerirá acceso simultáneo de ambos sobre la IMEM viva: durante ejecución el loader no escribirá, y durante una carga aceptada no habrá fetch válido ni avance de CPU.

Data Memory tendrá como agentes conceptuales a la CPU y a Debug. No se requerirá acceso directo simultáneo sobre la DMEM viva. Debug podrá utilizar exclusión temporal, captura, mirror, shadow storage, un puerto adicional coherente u otro mecanismo equivalente.

La CPU demandará como máximo una solicitud por memoria y ciclo. IMEM y DMEM serán recursos lógicos independientes y deberán poder sostener en el mismo ciclo una solicitud de fetch y una solicitud de load o store, sin introducir un hazard estructural obligatorio por tratarlas como un único recurso no concurrente.

Puertos adicionales, mirrors y shadow storage estarán permitidos, pero no serán requisitos arquitectónicos. Una colisión de ownership prohibida será una violación de invariante interno, no un fault de programa obligatorio.

#### Restricciones y derivaciones de parametrización

La capacidad en bytes será la única entrada autoritativa para cada memoria. Ambas capacidades deberán cumplir independientemente:

```text
4 <= CAPACITY_BYTES <= 2^32
CAPACITY_BYTES % 4 == 0
```

No será necesario que sean potencias de dos. El límite superior ocupa hasta el último offset `0xFFFFFFFF`; el dominio de configuración y cálculo deberá poder representar matemáticamente `2^32`, aunque ese valor no sea una dirección de 32 bits.

Para Instruction Memory se derivará:

```text
IMEM_INSTRUCTION_COUNT = IMEM_CAPACITY_BYTES / 4
```

Para Data Memory, `DMEM_CAPACITY_BYTES / 4` podrá utilizarse como cantidad lógica de words sin imponer una organización física por palabras.

También se derivarán desde la capacidad los límites, anchos de índices, comparadores, contadores, tamaños de metadata y límites utilizados por loader, Debug, software y testbenches. No existirán parámetros configurables redundantes para propiedades derivables.

Las derivaciones deberán admitir una única word sin crear vectores de ancho cero, capacidades no potencia de dos y el límite `2^32`. Cuando una representación exija ancho positivo se utilizará una regla equivalente a `max(1, ceil(log2(element_count)))`.

Se distinguirá una configuración **arquitectónicamente válida** de una configuración **soportada por la implementación**. `DEC-ARCH-006` define `REFERENCE=1024/2048` como perfil físico obligatorio y `ALT_1000=1000/1000` para validar parametrización no potencia de dos mediante elaboración, simulación y smoke tests. Una configuración inválida deberá rechazarse antes de ejecución y una configuración válida pero no soportada deberá producir un error claro de build.

#### Endianness y selección de bytes

Instruction Memory y Data Memory utilizarán semántica arquitectónica **little-endian**. En todo valor multibyte, la dirección menor contendrá los bits menos significativos.

Una word `0x12345678` almacenada desde `A` se representará conceptualmente como:

```text
A + 0 -> 0x78  bits  7:0
A + 1 -> 0x56  bits 15:8
A + 2 -> 0x34  bits 23:16
A + 3 -> 0x12  bits 31:24
```

Por tanto, `lw A` reconstruirá `0x12345678`. `sb` escribirá los ocho bits menos significativos; `sh` y `sw` distribuirán sus bytes desde LSB a MSB en direcciones crecientes. Los loads realizarán la reconstrucción inversa y aplicarán después sign extension para `lb` y `lh`, zero extension para `lbu` y `lhu`, o conservarán los 32 bits para `lw`.

Instruction Memory aplicará la misma regla. La instrucción `0x00A585B3` ubicada en `PC = 0x00000000` corresponderá a:

```text
IMEM[0] = 0xB3
IMEM[1] = 0x85
IMEM[2] = 0xA5
IMEM[3] = 0x00
```

y el fetch reconstruirá `0x00A585B3`.

Esta semántica no impone bancos, byte enables ni una organización física específica. Tampoco decide el orden de bytes del protocolo UART: `DEC-PROTO-001` podrá elegir cualquier orden inequívoco, pero loader y software deberán transformarlo para preservar la representación arquitectónica little-endian.

#### Validez y commit de la imagen ejecutable

Toda imagen confirmada será un prefijo contiguo, no vacío y sin huecos de Instruction Memory, comenzando en `0x00000000`. Su pertenencia se representará conceptualmente mediante:

```text
image_valid
loaded_image_size_bytes
```

Con una imagen válida se cumplirán:

```text
image_valid = 1
4 <= loaded_image_size_bytes <= IMEM_CAPACITY_BYTES
loaded_image_size_bytes % 4 == 0
loaded_instruction_count = loaded_image_size_bytes / 4
```

Los bytes pertenecientes a la imagen serán:

```text
[0, loaded_image_size_bytes)
```

Como el límite es exclusivo, `loaded_image_size_bytes` deberá poder representar `2^32`. La validez completa de un fetch requerirá una condición equivalente a:

```text
image_valid
AND PC + 4 <= IMEM_CAPACITY_BYTES
AND PC + 4 <= loaded_image_size_bytes
```

con aritmética ensanchada, además de la política de alineación que defina `DEC-ARCH-004`.

No se admitirán imágenes sparse ni múltiples secciones de código discontinuas. No se utilizará ni requerirá un bitmap de validez por instrucción. Que una palabra pertenezca a la imagen no determina si su codificación es legal para el ISA; ese tratamiento corresponde a `DEC-ARCH-004`.

Al aceptar una nueva carga se establecerá conceptualmente:

```text
image_valid = 0
loaded_image_size_bytes = 0
```

El loader escribirá instrucciones secuencialmente desde cero. El progreso de recepción o escritura será estado separado del tamaño confirmado y ninguna escritura parcial habilitará ejecución.

Recibir y validar la imagen completa no bastará para publicarla. Solo después de preparar también DMEM y el restante estado inicial de la nueva sesión se escribirá atómicamente el tamaño recibido; en el cuadragésimo cuarto acuerdo de `DEC-ARCH-003`, `load_ok` deja el tamaño privado del Loader y `PREPARING_READY && prepare_done` realiza ese único commit, sin ejecutar CPU; ese único write no nulo constituirá el commit completo y hará que `image_valid = 1` por derivación. Una carga vacía, truncada, inválida, sobredimensionada o fallida conservará el tamaño en cero y mantendrá RUN y STEP inhabilitados hasta una carga válida posterior.

No se exige rollback, restaurar la imagen anterior, borrar físicamente IMEM ni utilizar doble buffer. Si un programa nuevo es más corto, el contenido residual posterior al límite confirmado será irrelevante y no ejecutable.

`loaded_image_size_bytes` es estado conceptual necesario para determinar pertenencia, pero no será un campo obligatorio del snapshot mínimo de Debug.

La organización física, inferencia, latencia, ownership, metadata y perfiles se definen en `DEC-ARCH-006`. La polaridad, estrategia temporal, semántica y prioridades de reset y enables se definen en `DEC-ARCH-008`, sin imponer señales o secuencias RTL concretas. La alineación, codificaciones inválidas y prioridad entre errores están aprobadas en `DEC-ARCH-004`.

**Justificación:** El direccionamiento por byte y little-endian mantienen coherencia con RV32I y permiten una única semántica para instrucciones y datos. Los espacios Harvard independientes permiten atender las demandas lógicas simultáneas de IF y MEM sin exigir una tecnología física concreta.

La validación ensanchada de la región completa evita aliasing, wrap-around de sus bytes y efectos parciales, sin prohibir la generación modular de la dirección efectiva. Admitir capacidades múltiplos de cuatro no potencia de dos evita convertir una simplificación de indexación en una restricción arquitectónica y obliga a preservar comparaciones de rango correctas.

Una imagen como prefijo contiguo satisface los programas requeridos por el TP y permite invalidar limpiamente residuos de imágenes anteriores con dos valores escalares, sin borrar toda IMEM ni mantener metadata por instrucción. Separar el progreso del tamaño confirmado y publicar la imagen solo al éxito garantiza que una carga parcial nunca se vuelva ejecutable.

**Consecuencias:**

- PC, destinos de control y direcciones de datos se expresan en bytes;
- el flujo secuencial utiliza `PC + 4`;
- IMEM y DMEM son espacios lógicos independientes con base cero;
- el entry point es fijo en `0x00000000`;
- todo acceso valida su región completa antes de indexar memoria;
- un fetch fuera de imagen o capacidad y un acceso DMEM fuera de rango producen candidatos de fault;
- los candidatos del camino incorrecto se descartan;
- la operación causante de un fault y las posteriores no producen efectos arquitectónicos;
- IMEM y DMEM deben sostener simultáneamente las demandas lógicas de IF y MEM;
- no se exigen accesos concurrentes CPU/loader ni CPU/Debug sobre una misma memoria viva;
- las capacidades son múltiplos de cuatro entre 4 y `2^32` bytes y pueden no ser potencias de dos;
- toda propiedad derivable procede de la capacidad autoritativa en bytes;
- IMEM y DMEM son little-endian;
- el endianness UART continúa separado;
- una imagen ejecutable es un prefijo contiguo no vacío desde cero;
- `image_valid` y `loaded_image_size_bytes` determinan la pertenencia a la imagen;
- una carga aceptada invalida inmediatamente la imagen y pone el tamaño confirmado en cero;
- tamaño y validez se publican atómicamente solo al completar exitosamente la carga;
- no se soportan imágenes sparse ni se requiere bitmap de validez por instrucción;
- no es necesario borrar físicamente el sufijo residual de IMEM;
- pertenencia a la imagen y legalidad de la codificación ISA son conceptos distintos;
- alineación y clock están aprobados en `DEC-ARCH-004` y `DEC-ARCH-005`; el protocolo detallado permanece pendiente; reset y enables se fijan semánticamente en `DEC-ARCH-008` y la implementación física de memorias en `DEC-ARCH-006`.

**Requisitos afectados:** `REQ-CPU-003`, `REQ-CPU-004`, `REQ-CPU-006`, `REQ-CPU-007`, `REQ-CPU-011`, `REQ-CPU-014`, `REQ-CPU-016` a `REQ-CPU-018`, `REQ-ISA-001` a `REQ-ISA-006`, `REQ-ISA-018` a `REQ-ISA-022`, `REQ-ISA-032`, `REQ-ISA-033`, `REQ-HAZ-001`, `REQ-MEM-001` a `REQ-MEM-024`, `REQ-EXEC-014`, `REQ-EXEC-017`, `REQ-EXEC-018`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`, `REQ-DOC-007`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-ARCH-002 — Etapa de resolución de branches y jumps

**Estado:** Aprobada

**Dominio:** CPU / Pipeline

**Fecha de aprobación:** 2026-09-22

**Contexto:** El pipeline debe resolver `beq`, `bne`, `jal` y `jalr` con destinos byte-addressed conforme a `DEC-ARCH-001`, conservar el estado correcto ante cambios de flujo y evitar efectos de instrucciones del camino incorrecto. La decisión se cierra con los siete acuerdos siguientes; su realización física y las prioridades concretas corresponden a decisiones posteriores.

**Decisión:** Se aprueban conjuntamente los siete acuerdos de resolución, destinos, redirección, descarte, enlace, eventos `wrong-path` y fetch secuencial que se detallan a continuación.

#### Acuerdo aprobado — etapa arquitectónica de resolución

**Fecha:** 2026-09-22

`beq`, `bne`, `jal` y `jalr` se resolverán en **EX — Execute**. Una instrucción de control solo podrá producir una decisión válida de cambio de flujo al alcanzar EX como instrucción válida. EX es el punto arquitectónico de resolución, sin exigir un mecanismo RTL particular ni excluir cálculos parciales previos.

Esta elección permite utilizar el esquema general de operandos y dependencias de ejecución sin exigir resolución temprana especializada en ID. Al conocerse la redirección en EX, pueden existir instrucciones más jóvenes ya admitidas; el acuerdo de descarte fija su semántica sin imponer cantidad de invalidaciones ni ciclos de penalidad.

Este primer acuerdo fija la etapa; los acuerdos siguientes establecen condiciones, destinos, enlace, actualización del PC e invalidación. Las prioridades entre redirect, stall y flush y las señales RTL concretas corresponden a `DEC-ARCH-003`.

#### Acuerdo aprobado — condición y cálculo del destino en EX

**Fecha:** 2026-09-22

Para una instrucción de control válida, EX determinará la condición efectiva y calculará el destino arquitectónico sobre operandos y direcciones de 32 bits conforme a RV32I:

```text
beq:  taken = (rs1_effective == rs2_effective)
      target = instruction_PC + immediate_B

bne:  taken = (rs1_effective != rs2_effective)
      target = instruction_PC + immediate_B

jal:  salto incondicional
      target = instruction_PC + immediate_J

jalr: salto incondicional
      target = (rs1_effective + immediate_I) & 0xFFFFFFFE
```

Los inmediatos B, J e I se interpretarán según su codificación RV32I. La comparación de branches abarcará los 32 bits completos y no dependerá de una interpretación signed/unsigned. `rs1_effective` y `rs2_effective` representarán los valores arquitectónicos más recientes para la instrucción: `DEC-ARCH-003` definirá el forwarding y/o stall que impida decisiones con operandos obsoletos, sin fijar aquí su matriz o implementación.

Para `beq`, `bne` y `jal`, `instruction_PC` será el PC asociado a la propia instrucción y preservado hasta EX, no el PC global que esté usando IF para otra instrucción. Para `jalr`, el bit 0 de la suma de 32 bits se forzará a cero. Las expresiones `taken` y `target` describen resultados conceptuales, no nombres de señales RTL obligatorias. Podrán utilizarse comparador, ALU, sumadores dedicados o recursos compartidos si preservan esta semántica y cumplen timing.

El acuerdo del enlace fija el valor y la etapa de escritura sin imponer su cálculo físico. La legalidad de destinos desalineados o inválidos y sus faults corresponde a `DEC-ARCH-004`; este acuerdo fija el valor arquitectónico del destino.

#### Acuerdo aprobado — política de redirección del PC

**Fecha:** 2026-09-22

EX determinará conceptualmente si una instrucción de control válida requiere redirigir el flujo y el destino correspondiente. La lógica asociada a IF/PC aplicará esa decisión al seleccionar el próximo PC efectivo; EX no será propietario directo del registro PC. `redirect_valid` y `redirect_target` son nombres explicativos, no señales RTL obligatorias:

```text
beq:  redirigir si rs1_effective == rs2_effective
bne:  redirigir si rs1_effective != rs2_effective
jal:  redirigir si la instrucción en EX es válida
jalr: redirigir si la instrucción en EX es válida

si se aplica una redirección: próximo PC = destino calculado en EX
si no hay redirección:     continuar con el flujo secuencial
```

Un branch no tomado no redirigirá ni invalidará instrucciones válidas del camino secuencial por su sola presencia. Una entrada inválida en EX tampoco podrá modificar el PC, aunque sus bits residuales codifiquen una instrucción de control. Los destinos mantienen las fórmulas del acuerdo anterior.

La redirección solo podrá actualizar estado secuencial como parte de un ciclo lógico efectivo del CPU conforme a `DEC-ARCH-008`. Durante HOLD, una evaluación combinacional de EX no cambiará el PC; un STEP aceptado autorizará exactamente un ciclo lógico y, cuando corresponda, una sola actualización del PC, sin repetir la redirección en flancos posteriores sin nuevo avance; en RUN se aplicará cuando corresponda en ciclos habilitados. La selección conceptual de próximo PC no obliga a que PC cambie en todo ciclo efectivo: un stall puede retenerlo según los enables locales que defina `DEC-ARCH-003`.

El acuerdo siguiente fija el descarte de instrucciones jóvenes; los registros afectados, la prioridad entre redirect, stall, flush y otros eventos y la realización RTL del selector y de los enables locales corresponden a `DEC-ARCH-003`. La política de redirección no determina la relación exacta de una redirección coincidente con un stall ni sustituye la política de faults de `DEC-ARCH-004`.

#### Acuerdo aprobado — descarte de instrucciones jóvenes ante redirección

**Fecha:** 2026-09-22

Cuando una instrucción de control válida en EX produzca una redirección (`beq` o `bne` tomado, `jal` o `jalr`), **toda instrucción más joven admitida por el camino secuencial incorrecto quedará arquitectónicamente inválida**. La instrucción de control conservará su validez; las instrucciones válidas más antiguas no se descartarán por esa redirección y podrán completar sus efectos normales conforme a sus propias condiciones. No se tratará la redirección como un reset ni como un vaciado global del pipeline. IF e ID son ubicaciones ilustrativas de trabajo joven, no una selección obligatoria de latches o una cantidad fija de instrucciones descartadas.

Una instrucción invalidada carecerá de efectos funcionales aunque queden bits residuales en un registro: no podrá escribir registros o DMEM, redirigir el PC, iniciar la finalización mediante `halt`, producir un fault arquitectónico ni causar otros cambios arquitectónicos. Un `halt` joven descartado no iniciará drenado según `DEC-SYS-001`; un candidato de fault del camino descartado no se convertirá en fault arquitectónico según `DEC-ARCH-001`. Los efectos de instrucciones más antiguas conservarán sus propias reglas, sin decidir aquí la prioridad frente a un fault anterior u otras causas concurrentes.

Cuando `beq` o `bne` no se tome, el camino secuencial seguirá siendo válido y ninguna instrucción de ese camino se invalidará solo por la presencia del branch. Esta regla fija únicamente la semántica del descarte; las señales, bits físicos que se limpien, latches afectados, temporización ciclo a ciclo y prioridad entre redirect, stall, bubble y flush corresponden a `DEC-ARCH-003`.

#### Acuerdo aprobado — valor de enlace de `jal` y `jalr`

**Fecha:** 2026-09-22

Las instrucciones válidas `jal` y `jalr` producirán como valor arquitectónico de enlace de 32 bits:

```text
link_value = instruction_PC + 4
```

`instruction_PC` será el PC asociado a la propia instrucción y conservado a lo largo del pipeline; no se utilizará el PC global de IF, que puede corresponder a otra instrucción. Por ejemplo, si `instruction_PC = 0x00000020`, el valor de enlace será `0x00000024` aunque IF presente otro PC.

El valor de enlace, o información equivalente que permita reconstruirlo exactamente, deberá preservarse hasta WB a través del recorrido de pipeline (incluidos EX/MEM y MEM/WB). La escritura arquitectónica de `rd` tendrá lugar en **WB**, cualificada por validez y avance conforme a `DEC-ARCH-008`, sin escritura anticipada del banco en EX. Si `rd = x0`, el salto y su redirección seguirán siendo válidos pero `x0` conservará su valor cero.

No se fija dónde se realiza físicamente la suma, si se transporta el PC o el resultado, si se comparte un sumador, ni los campos o nombres RTL concretos. La elección deberá preservar el valor correcto en WB sin alterar la política posterior de forwarding, stalls y prioridades de `DEC-ARCH-003`.

#### Acuerdo aprobado — efectos de eventos detectados en instrucciones `wrong-path`

**Fecha:** 2026-09-22

Un evento asociado a una instrucción solo podrá modificar el estado arquitectónico o global de ejecución si la instrucción sigue siendo válida y pertenece al camino correcto. La detección interna de una condición podrá producir un **candidato** sin confirmarlo arquitectónicamente: si una instrucción de control más antigua invalida la operación, se descartarán la instrucción y sus eventos asociados. No se exige que las condiciones se detecten anticipadamente ni se fija dónde se confirman.

En particular, un `halt` más joven que quede `wrong-path` no detendrá la admisión del camino correcto, no iniciará drenado y no activará FINISHED ni otra finalización normal, conforme a `DEC-SYS-001` y `REQ-EXEC-013`. Un fetch o acceso de memoria con condición candidata a fault que luego pertenezca al camino descartado no generará un fault arquitectónico ni alterará el estado global de ejecución, conforme a `DEC-ARCH-001` y `REQ-EXEC-018`.

La misma regla se aplica a cualquier instrucción invalidada: no escribirá registros ni DMEM, no redirigirá el PC y no producirá efectos arquitectónicos o cambios globales originados por esa instrucción. Esto precisa la distinción entre **condición candidata** y **evento arquitectónico confirmado** del acuerdo de descarte anterior; la mera presencia de bits residuales o una detección temprana no constituyen un commit.

Las etapas, confirmaciones, prioridad por antigüedad y transporte están fijados por `DEC-ARCH-004` y `DEC-ARCH-003`, acuerdos 40–47. Este acuerdo no modifica los efectos de una operación válida del camino correcto ni la prioridad global de reset establecida en `DEC-ARCH-008`.

#### Acuerdo aprobado — penalización de control y ausencia de predicción

**Fecha:** 2026-09-22

La arquitectura inicial utilizará **fetch secuencial por defecto** sin predictor de branches ni punto alternativo de resolución temprana. Mientras una instrucción de control avanza hacia EX, IF seguirá provisionalmente `PC + 4` cuando el ciclo efectivo y sus enables locales permitan avanzar. Este flujo provisional no obliga a modificar PC durante HOLD o un stall: la prioridad y los enables concretos siguen sujetos a `DEC-ARCH-003` y `DEC-ARCH-008`.

Si un `beq`/`bne` tomado o un `jal`/`jalr` válido determina una redirección en EX, la lógica IF/PC seleccionará el destino según los acuerdos anteriores y **todo trabajo más joven del camino secuencial incorrecto deberá quedar inválido**. Se acepta el costo del trabajo provisional iniciado antes de conocer la redirección, sin que una instrucción descartada pueda producir efectos arquitectónicos o eventos globales. Un branch no tomado conservará el camino secuencial, sin penalización de invalidación por la mera presencia del branch; otros stalls independientes podrán ocurrir.

No se incluirán inicialmente predictor dinámico, predicción estática adicional, BTB, tablas de historial, delay slots, resolución anticipada en ID ni un tratamiento temprano especial de `jal`/`jalr`. Todas las instrucciones de control requeridas conservarán EX como único punto arquitectónico de resolución. El trabajo joven realmente presente dependerá de la ocupación, stalls, bubbles y demás condiciones: no se fija una penalización constante de ciclos ni una cantidad universal de entradas descartadas. Una cifra nominal, por ejemplo «dos ciclos», solo describirá un caso concreto, nunca el contrato arquitectónico.

Introducir después predicción, BTB o resolución temprana requerirá revisar explícitamente `DEC-ARCH-002` y la verificación del flujo, sus invalidaciones y hazards. Los acuerdos 41–42 de `DEC-ARCH-003` fijan después las acciones y flushes, y el 45 audita las coincidencias funcionales; la implementación física se sujeta a esos contratos.

#### Aclaración aprobada — fetch secuencial provisional y ausencia de predictor

**Fecha:** 2026-09-23

El avance provisional de IF por `PC + 4` mientras `beq` o `bne` llega a EX es **observablemente equivalente** a una política estática `not taken`: si el branch no se toma, el camino secuencial conserva su validez; si se toma, se redirige el PC y se descarta el trabajo joven `wrong-path`. Esta equivalencia de comportamiento **no constituye un predictor estático `always not taken` implementado explícitamente**. No habrá estructura de predicción ni decisión de predicción asociada al branch: `PC + 4` es simplemente el fetch por defecto mientras no se haya resuelto una redirección válida y el avance esté habilitado.

La arquitectura inicial se describe como **fetch secuencial por defecto + resolución de branches en EX + invalidación del trabajo `wrong-path` ante redirect**. Esta aclaración pertenece a `DEC-ARCH-002` y no modifica sus siete acuerdos, la ausencia inicial de predictor dinámico, predicción estática adicional, BTB, historial, delay slots o resolución anticipada en ID, ni los ciclos efectivos y stalls ya establecidos. Incorporar cualquiera de esos mecanismos exigiría revisar explícitamente `DEC-ARCH-002`.

**Justificación:** La resolución uniforme en EX y el fetch secuencial por defecto evitan predicción y resolución anticipada especializada; la invalidación del camino incorrecto preserva la semántica de ejecución aunque se acepte una penalización variable de control.

**Consecuencias:** IF/PC aplicará las redirecciones válidas de EX en ciclos efectivos, el trabajo joven `wrong-path` no tendrá efectos arquitectónicos y `jal`/`jalr` escribirán el enlace en WB. No se exige una penalización constante ni una realización RTL particular.

**Aspectos diferidos:** Los detalles siguientes no bloquean el cierre de `DEC-ARCH-002` ni son pendientes internos de esta decisión:

- `DEC-ARCH-003` resolverá el forwarding concreto; stalls y bubbles; señales y realización física de flush/invalidation; latches, enables y prioridades entre redirect, stall, flush y otros eventos; la temporización concreta del pipeline; y la realización física del cálculo y transporte del enlace, preservando su valor y escritura en WB ya aprobados.
- `DEC-ARCH-004` ya resolvió la política arquitectónica de faults, instrucciones inválidas, legalidad de destinos y accesos desalineados y confirmación de errores, preservando el descarte de candidatos `wrong-path` aquí aprobado. La coordinación con stalls e invalidaciones físicas corresponde a `DEC-ARCH-003`.

**Requisitos afectados:** `REQ-DOC-008`, `REQ-CPU-008` a `REQ-CPU-011`, `REQ-CPU-013`, `REQ-CPU-017`, `REQ-ISA-001`, `REQ-ISA-005`, `REQ-ISA-006`, `REQ-ISA-032`, `REQ-MEM-016`, `REQ-EXEC-013`, `REQ-EXEC-018`, `REQ-HAZ-006` a `REQ-HAZ-010`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-ARCH-003 — Política de hazards

**Estado:** Aprobada

**Dominio:** CPU / Hazards

**Fecha de aprobación:** 2026-09-25

**Contexto:** Los acuerdos aprobados fijan el forwarding general hacia EX desde EX/MEM y MEM/WB, con prioridad del productor más reciente y exclusión de valores todavía no disponibles; el stall nominal de un ciclo y su condición conceptual exacta para una dependencia `load-use` inmediata, con PC e IF/ID retenidos e ID/EX convertido en bubble; la clasificación semántica de fuentes `rs1`/`rs2` por instrucción; la distinción entre etapa de consumo y resolución en EX del dato de stores, que se transporta por EX/MEM para su uso en MEM; la matriz de clases y valores reenviables por etapa, incluido el enlace de `jal`/`jalr` desde EX/MEM, y la selección en MEM del único valor arquitectónico que MEM/WB transporta hacia WB y forwarding y el cálculo físico en EX del enlace de `jal`/`jalr` desde `ID/EX.pc`, seleccionado por el `Result MUX` y el `WB Value MUX` para esos saltos; la selección física del único `ex_result` mediante un `Result MUX` de tres entradas (`alu_result`, `immediate`, `link_value`) según la clase de instrucción; la generación física del destino en EX mediante `Target Adder`, `JALR Adder` y `Target MUX`, la comparación de branches por resta y `ALU.zero`, y el envío conceptual de `redirect_valid` al `Pipeline Hazard Control` y de `redirect_target` al Next-PC MUX; la prioridad local de un redirect válido sobre stalls causados exclusivamente por trabajo joven `wrong-path` que se descartará; las transiciones nominales de PC e IF/ID, ID/EX, EX/MEM y MEM/WB ante avance normal, `load-use stall` y redirect, con retención por ausencia de captura e invalidación mediante `valid=0`; el mux de próximo PC entre `pc_plus_4` y `redirect_target`, la habilitación de escritura del PC, la captura, retención e invalidación física de IF/ID y la captura e invalidación de ID/EX y el avance físico de EX/MEM y MEM/WB y su coordinación nominal mediante `Pipeline Hazard Control` para esos casos; y la selección exacta e independiente de cada fuente según el productor más reciente, sin sustituirlo por un valor anterior si todavía no está disponible. La integración y las coincidencias se rigen por los acuerdos 40–47, con prevalencia del acuerdo 47 para la confirmación de fetch y sus acciones. El cuadragésimo cuarto acuerdo fija después la generación global de `cpu_cycle_fire` y la temporización de inicio/drenado mediante una FSM de 14 estados; el cuadragésimo quinto acuerdo audita y resuelve después las coincidencias globales e integración funcional; la matriz final del acuerdo 46 queda revisada por el acuerdo 47, mientras el protocolo externo conserva su decisión propia; `next_pc_sel`, `pc_write_enable`, la captura/invalidez de los cuatro latches y el transporte del enlace para las acciones aprobadas ya tienen ecuaciones de etapa. La política deberá integrar stalls, flushes y candidatos de fault para que únicamente una operación activa del flujo válido pueda producir error arquitectónico, sin reemplazar la política detallada de faults de `DEC-ARCH-004`. También deberá preservar el progreso concurrente de IF y MEM sin introducir stalls por la lectura de memorias, cuya interfaz combinacional fue acordada en `DEC-ARCH-006`, ni crear un hazard estructural por tratar IMEM y DMEM como un único recurso.

El vigésimo octavo acuerdo fija detección candidata de `halt` en ID y confirmación en EX para trabajo válido del camino correcto: al confirmar se retiene PC, se consume `halt` sin propagarlo válido a EX/MEM, se descarta el trabajo joven y las anteriores drenan hasta `FINISHED` solo en ciclos efectivos. La identificación semántica de `halt` en EX se fija posteriormente como `flow_op=HALT` en el trigésimo tercer acuerdo; su código funcional `flow_op=3'b101` queda fijado en el trigésimo cuarto acuerdo; el cuadragésimo acuerdo fija después `ex_halt_candidate`/`halt_confirm` y su precedencia con fault propio y redirect, sin cerrar por sí solo la integración global de enables/flush; los acuerdos cuadragésimo segundo y cuadragésimo tercero fijan después la actualización de latches y el gating de efectos CPU. Conforme al acuerdo 47 de `DEC-ARCH-003`, IF solo detecta candidatos: durante `load-use`, sin frontera EX/ID prevaleciente, solo se aplica `act_load_use`, se retienen PC y los cinco campos de IF/ID y no se confirma ni captura el candidato; al avanzar se redetecta en ese PC y se transporta por IF→IF/ID→ID, donde puede confirmarse con `fault_pc=IF/ID.pc` si no lo descarta una frontera EX anterior. El estado de causa/PC confirmado permanece global y fuera del pipeline. El trigésimo segundo acuerdo fija las ecuaciones funcionales del detector `load-use` y de la Forwarding Unit; el trigésimo tercero define seis categorías semánticas del control de ID/EX y su reducción hacia EX/MEM y MEM/WB, sin obligar a un bus `control` único. El trigésimo cuarto acuerdo fija nombres, anchos y códigos de los controles y selectores principales; el trigésimo quinto fija el código de tres bits común a la causa candidata de IF/ID y a la causa global confirmada. El trigésimo sexto fija `terminal_kind[1:0]` y `drain_auto`, con fases de drenado y finalización derivadas de las cuatro validez. El cuadragésimo quinto acuerdo resuelve después las coincidencias funcionales restantes; la matriz del cuadragésimo sexto queda revisada por el acuerdo 47, y la representación externa Debug/UART corresponde a sus decisiones separadas.

Las transiciones de latches descritas previamente en `DEC-ARCH-003` son **nominales** para avance, `load-use stall` y redirect sin coincidencia de fault confirmado; el trigésimo acuerdo fija cómo se subordinan al arbitraje por antigüedad cuando sí hay fronteras concurrentes y el trigésimo primero añade la tabla de transiciones resultante. El noveno acuerdo de `DEC-ARCH-004` fija por separado que, tras la confirmación de un fault, PC se retiene, las entradas de la causante y jóvenes no se admiten o se invalidan según IF/ID/EX y las anteriores progresan hasta `FAULT`, incluso con stall necesario entre ellas; el décimo acuerdo resuelve la interacción semántica con redirect, `halt` y `load-use` sin cerrar ecuaciones RTL.

**Opciones consideradas:** Mantener solo las reglas nominales de hazards sin integrar coincidencias, o cerrar explícitamente la selección por antigüedad, los controles del pipeline, la autorización global y su composición completa. Implementar un stall estructural compartiendo IF/MEM o respetar sus memorias independientes. Exigir un único bus `ID/EX.control` o preservar categorías funcionales con empaquetado RTL equivalente.

**Decisión:** Se aprueba la política de hazards integrada y verificada documentalmente en los 47 acuerdos siguientes, incluida la auditoría de coincidencias del acuerdo 45, la matriz del 46 y su revisión explícita por el acuerdo 47. La última revisión expresa prevalece sobre representaciones históricas anteriores.

**Justificación:** La matriz final cubre forwarding, stalls, fronteras, acciones, actualización de latches, gating y FSM sin coincidencias funcionales restantes; separa el contrato arquitectónico de la representación externa Debug/UART y de la elección física de implementación.

**Consecuencias:** La implementación RTL deberá respetar las ocho acciones excluyentes, el control de ciclo y la conservación de efectos de instrucciones anteriores; su verificación posterior usará los invariantes de la matriz final. El empaquetado de `ID/EX.control` no condiciona el cierre; Debug/UART mantiene decisiones independientes en `DEC-ARCH-009` y protocolo.

**Dependencias resueltas:** `DEC-ARCH-001`, `DEC-ARCH-002`, `DEC-ARCH-004` y `DEC-ARCH-007`. M5 — Hazard Freeze.

Los acuerdos 1–46 se conservan en orden cronológico: las referencias a aspectos «pendientes» describen el estado **al aprobar cada acuerdo parcial**, no el estado vigente de este ADR. La revisión del acuerdo 44 prevalece sobre los registros terminales propuestos en acuerdos anteriores, y el acuerdo 47 revisa la matriz del acuerdo 46 y fija la política vigente de confirmación de fetch en ID.

#### Acuerdo parcial aprobado — forwarding general hacia EX

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-22

Para cada operando fuente `rs1` o `rs2` que deba consumirse o quedar resuelto al atravesar EX, el valor efectivo provendrá conceptualmente del valor leído y conservado en ID/EX, del resultado disponible de EX/MEM o del valor de MEM/WB destinado a Write Back. Si dos productores válidos y disponibles escriben el mismo registro fuente, se preferirá **EX/MEM > MEM/WB > ID/EX**: EX/MEM contiene la versión más reciente. La selección se hará independientemente para cada operando usado. Así, en `add x5, x1, x2; addi x5, x5, 1; sub x6, x5, x3`, `sub` consumirá el resultado de `addi` y no el de `add`.

El forwarding desde una etapa posterior exige que su instrucción sea válida, escriba arquitectónicamente un registro, tenga `rd != x0`, coincida con el registro fuente realmente usado y ofrezca ya el dato correcto. Una coincidencia de números de registro no basta: una instrucción invalidada o que no escribe `rd` no es productora; `x0` permanecerá en cero. Si el productor más reciente coincidente todavía no tiene el valor disponible, el consumidor deberá esperar antes que usar el valor obsoleto de ID/EX o de un productor anterior en MEM/WB.

En particular, el dato de un `load` que esté en EX/MEM **no está disponible para forwarding normal hacia EX en ese mismo ciclo**. La arquitectura inicial no incorporará un bypass combinacional directo `DMEM → EX`; un consumidor `load-use` inmediato esperará hasta que el dato esté disponible, aunque la interfaz de DMEM tenga lectura combinacional según `DEC-ARCH-006`. Las dependencias ALU→ALU consecutivas con resultados disponibles podrán resolverse normalmente sin stall. Los operandos de branches y `jalr` que se consumen en EX se benefician del mismo criterio general de valores efectivos, preservando `DEC-ARCH-002`.

Este primer acuerdo fija las fuentes, prioridad, elegibilidad y disponibilidad semánticas, sin imponer por sí mismo señales, muxes ni ecuaciones RTL. Los acuerdos siguientes fijan el stall `load-use` nominal y su detección conceptual exacta, la clasificación de fuentes, la resolución en EX del dato de stores, la matriz de valores reenviables desde EX/MEM y MEM/WB, el punto de selección del valor arquitectónico para WB en MEM y los campos físicos de los cuatro latches IF/ID, ID/EX, EX/MEM y MEM/WB, la prioridad local de redirect sobre un stall causado solo por trabajo joven descartado, las transiciones nominales de validez de los latches, la selección precisa de cada fuente por versión más reciente y los dos muxes combinacionales de forwarding hacia EX, el detector combinacional de `load-use` en ID, la Forwarding Unit, el mecanismo general de retención/invalidez, el mux de próximo PC con habilitación de escritura y la actualización física de IF/ID, ID/EX, EX/MEM y MEM/WB y el `Pipeline Hazard Control` combinacional para los casos nominales y el cálculo en EX y transporte por `ex_result`/`wb_value` del enlace de `jal`/`jalr` y el `Result MUX` de tres entradas con selección semántica de resultado ALU, inmediato LUI o enlace, y la generación física del redirect en EX con `Target MUX` y `ALU.zero` para branches. El trigésimo acuerdo fija posteriormente el orden semántico por antigüedad EX→ID→IF excepcional y el stall entre supervivientes; la realización RTL restante, el control de selección y las interacciones físicas no cubiertas con branches, `jalr` y faults permanecen abiertos en `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — resolución del hazard `load-use`

**Fecha:** 2026-09-22

Una dependencia `load-use` inmediata se resolverá con un **stall nominal de un ciclo**. Se detectará cuando una instrucción `load` válida esté en ID/EX, su destino sea `rd != x0` y una instrucción válida en IF/ID necesite efectivamente ese registro como fuente. La coincidencia de bits de un campo que la instrucción joven no utiliza no generará este stall; tampoco lo generará un `load` cuyo destino sea `x0`.

En la transición de stall, **PC e IF/ID se retendrán e ID/EX recibirá una bubble (`valid=0`)**, mientras que el `load` avanzará hacia MEM y las instrucciones más antiguas podrán seguir avanzando. El séptimo acuerdo explicita el avance de EX/MEM y MEM/WB en este caso. IF/ID conservará al consumidor que estaba en ID; la instrucción siguiente que estaba en IF no ingresará a IF/ID durante esa transición. El consumidor no se perderá ni se admitirá dos veces. La bubble separará al consumidor del `load` sin congelar globalmente el pipeline.

Tras esa espera nominal, el `load` podrá avanzar hasta MEM/WB y el consumidor pasar a EX con el dato correcto suministrado por el forwarding aprobado desde MEM/WB. No se agrega un bypass directo `DMEM → EX` ni se toma un valor anterior cuando el dato cargado aún no está disponible. En ausencia de otras causas de espera, esta dependencia agrega una sola bubble/ciclo de stall; la coordinación con otras condiciones concurrentes permanece diferida.

El stall ocurre dentro de un **ciclo lógico efectivo del CPU**, no en HOLD: el `load` y las instrucciones anteriores pueden progresar y ese ciclo cuenta una vez conforme a `DEC-ARCH-008`. En RUN, el siguiente ciclo habilitado permite continuar; en STEP, el stall consume una orden aceptada y los ciclos siguientes siguen requiriendo sus propias órdenes STEP. El noveno acuerdo fija la condición conceptual exacta y el decimosexto fija el bloque combinacional de detección en ID, sin imponer señales de enable ni ecuaciones RTL definitivas; el sexto acuerdo fija únicamente la prioridad de redirect frente a stalls originados exclusivamente por trabajo joven descartado, sin resolver las demás coincidencias con flush u otros eventos.

Los acuerdos siguientes clasifican las fuentes `rs1`/`rs2` usadas por cada instrucción, distinguen la etapa de consumo del dato de stores de su resolución al atravesar EX y fijan la prioridad local de redirect sobre stalls del camino descartado. Las demás prioridades stall/redirect/flush, las señales y las ecuaciones concretas de la unidad de hazards corresponden a acuerdos posteriores de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — clasificación semántica de operandos fuente (3A)

**Fecha:** 2026-09-22

La lógica de hazards y forwarding determinará a partir de la instrucción decodificada si esta utiliza `rs1`, `rs2`, ambos o ninguno. Solo una instrucción válida y un operando semánticamente utilizado podrán establecer una dependencia con un productor pendiente; los bits que ocupan posiciones de `rs1` o `rs2` en otra codificación no se interpretarán automáticamente como fuentes.

| Instrucción / clase | Usa `rs1` | Usa `rs2` |
|---|:---:|:---:|
| `add`, `sub`, `sll`, `srl`, `sra`, `and`, `or`, `xor`, `slt`, `sltu` | Sí | Sí |
| `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu` | Sí | No |
| `slli`, `srli`, `srai` | Sí | No |
| `lb`, `lh`, `lw`, `lbu`, `lhu` | Sí | No |
| `sb`, `sh`, `sw` | Sí | Sí |
| `beq`, `bne` | Sí | Sí |
| `jalr` | Sí | No |
| `jal` | No | No |
| `lui` | No | No |
| `halt` | No | No |

Para cada fuente, la dependencia conceptual requiere que la instrucción **use realmente ese operando** y que su índice coincida con el destino de un productor elegible, conforme al primer acuerdo. `uses_rs1` y `uses_rs2` son aquí descripciones conceptuales de las fuentes; el trigésimo séptimo acuerdo fija después sus nombres como salidas combinacionales del decoder, sin registrarlas. Esto impide hazards o forwarding espurios por bits de inmediatos u otros campos: `jal`, `lui` y `halt` no leen registros fuente, y las instrucciones I y los shifts inmediatos no leen `rs2`.

Los stores usan `rs1` como base para calcular la dirección y `rs2` como dato a almacenar; este acuerdo clasifica ambas fuentes. El acuerdo 3B fija sus etapas de consumo y la resolución del dato de store al atravesar EX. Si un `load` inmediato válido produce el `rs2` de un store válido, se conserva el stall nominal del acuerdo anterior: la clasificación 3A no modifica esa espera ya aprobada.

Esta clasificación fija solo la existencia semántica de fuentes; 3B establece cuándo deben resolverse y consumirse. Otras prioridades de hazards y las ecuaciones RTL definitivas se resolverán en acuerdos posteriores de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — etapa de consumo de operandos y tratamiento de stores (3B)

**Fecha:** 2026-09-22

La etapa donde un operando se **consume funcionalmente** se distinguirá de aquella en que su valor efectivo debe quedar **resuelto para atravesar el pipeline**. Para la arquitectura inicial se aprueba la siguiente clasificación, en continuidad con las fuentes semánticas de 3A:

| Instrucción / clase | Operando | Consumo funcional |
|---|---|---|
| R-type | `rs1` | EX |
| R-type | `rs2` | EX |
| I-type aritmética y shifts | `rs1` | EX |
| Loads | `rs1` | EX |
| Stores | `rs1` | EX |
| Stores | `rs2` | MEM |
| `beq`, `bne` | `rs1` | EX |
| `beq`, `bne` | `rs2` | EX |
| `jalr` | `rs1` | EX |
| `jal`, `lui`, `halt` | — | No leen registros fuente |

En `sb`, `sh` y `sw`, `rs1` es la base empleada en EX para calcular la dirección efectiva. `rs2` aporta el dato consumido funcionalmente al escribir DMEM en MEM. Aunque se utilice en MEM, el valor efectivo correcto de `rs2` deberá quedar resuelto cuando el store atraviese EX mediante el esquema general de forwarding, preservarse en el campo `store_data[31:0]` de EX/MEM fijado por el duodécimo acuerdo y llegar a MEM para la escritura.

Tanto `load → store-address` (`rs1`) como `load → store-data` (`rs2`) inmediatos utilizarán el mecanismo `load-use` aprobado: en el caso nominal se inserta un stall de un ciclo, y después el store puede recibir el resultado del load por forwarding desde MEM/WB hacia EX. La base se consume en EX; el dato correcto se transporta hasta su consumo en MEM. No se incorporará en la arquitectura inicial un bypass especial hacia store-data en MEM, por ejemplo desde MEM/WB, para evitar el stall del dato de store.

Esta política reutiliza el forwarding hacia EX y evita un camino especial en MEM, aceptando el stall nominal para `load → store-data`. El duodécimo acuerdo fija los campos físicos de EX/MEM; permanecen diferidos la codificación de controles, las demás señales RTL, las prioridades no cubiertas por el acuerdo local posterior entre redirect y stall del camino descartado, las coincidencias ciclo a ciclo entre hazards y las ecuaciones finales de forwarding y detección; no se reabre la semántica de consumo y transporte aprobada aquí.

#### Acuerdo parcial aprobado — matriz de valores reenviables

**Fecha:** 2026-09-22

Una etapa posterior solo podrá reenviar el valor de una instrucción válida que escriba arquitectónicamente un registro `rd != x0`, si dicho valor ya es el resultado correcto que recibirá Write Back y coincide con una fuente realmente usada. La coincidencia de índices por sí sola no alcanza; el productor más reciente prevalece conforme al primer acuerdo.

| Productor | Forwarding desde EX/MEM | Valor reenviado |
|---|:---:|---|
| R-type | Sí | Resultado de ejecución |
| I-type aritmética / shifts | Sí | Resultado de ejecución |
| `lui` | Sí | Valor arquitectónico producido por `lui` |
| `jal` | Sí | `instruction_PC + 4` |
| `jalr` | Sí | `instruction_PC + 4` |
| Loads | No | El dato cargado aún no está disponible |
| Stores | No | No escriben `rd` |
| `beq`, `bne` | No | No escriben `rd` |
| `halt` | No | No escribe `rd` |

Para `jal` y `jalr`, el enlace debe poder obtenerse correctamente como fuente de forwarding desde EX/MEM cuando `rd != x0`, además de preservarse para escritura en WB conforme a `DEC-ARCH-002`. El duodécimo acuerdo fija `ex_result[31:0]` como campo que lo conserva en EX/MEM; el vigésimo quinto fija su cálculo en EX desde `ID/EX.pc` y su selección por el `Result MUX`. Un load en EX/MEM solo dispone de la dirección efectiva en ese campo, no del dato arquitectónico a escribir en `rd`, y no podrá reenviarlo desde allí hacia EX.

| Productor | Forwarding desde MEM/WB |
|---|:---:|
| R-type | Sí |
| I-type aritmética / shifts | Sí |
| `lui` | Sí |
| Loads | Sí |
| `jal` | Sí |
| `jalr` | Sí |
| Stores | No |
| `beq`, `bne` | No |
| `halt` | No |

El valor reenviado desde MEM/WB será **el mismo `wb_value` arquitectónico seleccionado para Write Back en MEM antes de capturar MEM/WB**, según los acuerdos posteriores, provenga originalmente de ALU, DMEM, `instruction_PC + 4` o `lui`. No se requiere reconstruir su origen en la lógica de forwarding; también aquí se exigirán instrucción válida, escritura de registro y `rd != x0`.

Se conserva la prioridad **EX/MEM disponible > MEM/WB > ID/EX** entre productores elegibles. El último acuerdo precisa que primero se identifica la versión más reciente: si un load más reciente en EX/MEM coincide con la fuente pero todavía no tiene disponible su resultado, el consumidor esperará conforme al acuerdo de `load-use` en lugar de usar un valor anterior de MEM/WB o ID/EX. Instrucciones inválidas, stores, branches, `halt`, escrituras a `x0` o resultados todavía no disponibles no son fuentes de forwarding.

Este acuerdo fija clases y valores arquitectónicos reenviables; los acuerdos undécimo y duodécimo fijan los campos físicos de MEM/WB y EX/MEM, el decimoquinto fija los dos muxes de forwarding hacia EX y el decimoséptimo fija la unidad combinacional que selecciona sus entradas, sin determinar entonces nombres RTL ni codificación de selectores (fijados después en el trigésimo cuarto acuerdo) ni ecuaciones RTL finales. El sexto acuerdo fija una prioridad local entre redirect y stall del camino descartado; el trigésimo acuerdo fija después el orden semántico entre fronteras de fault, `halt`, redirect y stall entre supervivientes; la integración RTL de coincidencias y hazards de distintas clases continúa abierta en `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — prioridad entre redirección y stall del camino descartado

**Fecha:** 2026-09-22

Dentro de un **ciclo lógico efectivo**, una redirección válida de una instrucción de control más antigua en EX tendrá prioridad sobre un stall causado **exclusivamente por trabajo más joven `wrong-path` que dicha redirección invalidará**. En esa resolución, IF/PC aplicará el destino de `beq`/`bne` tomado o `jal`/`jalr` válido, y todo trabajo joven del camino incorrecto quedará inválido conforme a `DEC-ARCH-002`. La petición de stall de ese trabajo no impedirá actualizar el PC, no conservará instrucciones destinadas al descarte ni las convertirá en trabajo retenido para ciclos posteriores. El PC de destino y la invalidación serán coherentes entre sí; el acuerdo siguiente especifica IF/ID e ID/EX inválidos durante el redirect, sin exigir un mecanismo RTL particular ni una cantidad fija de instrucciones válidas descartadas.

Esta regla local opera bajo la jerarquía global de `DEC-ARCH-008`: reset global, LOAD aceptado/preparación de sesión, ciclo efectivo del CPU y HOLD, en ese orden. Un STEP aceptado habilita exactamente un ciclo que podrá resolver redirect y descarte; el STEP se consume allí, sin exigir otro para aplicar la redirección ya resuelta. En RUN rige el mismo resultado durante el ciclo habilitado; durante HOLD no se actualiza el PC ni se invalida trabajo por una evaluación combinacional.

Un `beq`/`bne` no tomado no produce redirect ni flush: cualquier stall válido conserva su tratamiento normal. El `load-use` clásico ubica un load en ID/EX y un consumidor en IF/ID; la misma entrada de EX no puede ser simultáneamente ese load y la instrucción de control que redirige. Por ello, su colisión directa no es el caso nominal; la prioridad rige para cualquier stall atribuible únicamente a instrucciones jóvenes que se descartan.

No se establece una prioridad universal de redirect sobre otros eventos: `DEC-ARCH-004` ya prohíbe aplicar redirect a un destino desalineado y fija la prioridad por antigüedad entre instrucciones y por desalineación frente a acceso inválido de la misma operación. La integración RTL con faults de instrucciones más antiguas o de la propia instrucción de control e instrucciones inválidas continúa pendiente de `DEC-ARCH-003`, con la prioridad semántica y atomicidad fijadas en `DEC-ARCH-004`. Los stalls originados en causas que no sean exclusivamente el trabajo joven descartado y otras coincidencias de control permanecen para acuerdos posteriores de `DEC-ARCH-003`; el decimoctavo acuerdo fija el mecanismo físico general de retención e invalidación, sin cerrar las señales ni ecuaciones RTL de flush.

#### Acuerdo parcial aprobado — semántica de `stall`, `bubble` y `flush` sobre el pipeline

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-22

En los casos nominales sin fault confirmado ni coincidencias adicionales aún diferidas, las transiciones conceptuales durante un ciclo lógico efectivo serán:

| Situación | PC | IF/ID | ID/EX | EX/MEM | MEM/WB |
|---|---|---|---|---|---|
| Avance normal | Avanza al próximo PC secuencial | Captura IF | Captura ID | Captura EX | Captura MEM |
| `load-use stall` | Retiene | Retiene al consumidor | Bubble (`valid=0`) | Avanza con el load | Avanza con la instrucción anterior |
| Redirect válido en EX | Adopta `target` | Flush (`valid=0`) | Flush (`valid=0`) | Avanza con la instrucción de control válida | Avanza con la instrucción anterior |

El avance normal preserva la validez de las entradas capturadas: no convierte automáticamente una entrada inválida en instrucción activa. El `load-use stall` mantiene al consumidor en IF/ID y retiene el PC, mientras el load pasa de EX hacia MEM y las instrucciones más antiguas avanzan; la bubble en ID/EX separa productor y consumidor sin congelar todo el pipeline. La instrucción siguiente en IF no desplaza al consumidor durante esa transición.

Ante un redirect válido de `beq`/`bne` tomado o `jal`/`jalr` en EX, IF/PC adopta el destino, IF/ID e ID/EX quedan inválidos y EX/MEM recibe la instrucción de control válida, que podrá continuar hasta WB para escribir el enlace cuando corresponda. MEM/WB continúa el avance de instrucciones más antiguas. **Se invalidan los dos latches jóvenes, sin presuponer que ambos contenían instrucciones válidas**; los campos residuales no representan operaciones activas. Un branch no tomado no redirige ni causa flush: conserva el flujo secuencial y se aplican los stalls independientes que correspondan.

En el flanco efectivo que aplica el redirect, el PC registrado toma el target y la lectura combinacional de IMEM podrá presentar la instrucción de ese nuevo PC después del flanco, conforme a `DEC-ARCH-006`. Esa instrucción **no se captura como válida en IF/ID en el mismo flanco**: IF/ID e ID/EX permanecen inválidos durante esa transición, y el fetch del target podrá incorporarse en el siguiente ciclo efectivo habilitado.

Bubble y flush distinguen espera de descarte, pero ambas producen arquitectónicamente `valid=0` en la entrada afectada. No será obligatorio escribir una NOP física, borrar los demás bits del latch ni registrar una causa de invalidez diferenciada. Mientras `valid=0`, ninguna lógica funcional interpretará esos bits como instrucción activa: no podrá escribir registros o DMEM, redirigir PC, reconocer arquitectónicamente `halt` ni originar otro efecto de una instrucción válida. La **única excepción de representación** es `IF/ID.valid=0` con `fetch_fault_valid=1`: identifica un candidato de fetch aún no confirmado, no una instrucción ni una causa de bubble/flush; ante descarte de trabajo joven el flag se invalida conforme al vigésimo noveno acuerdo.

Stall, bubble y flush son resultados **dentro de ciclos efectivos**, no HOLD, conforme a `DEC-ARCH-008`. El contador lógico cuenta ese ciclo una vez y un STEP aceptado queda consumido aunque PC o algún latch se retenga o invalide. El decimoctavo acuerdo fija retención por ausencia de captura e invalidación mediante `valid=0`; el decimonoveno fija el mux de próximo PC y la habilitación de escritura del PC; el vigésimo concreta la habilitación de escritura e invalidación de IF/ID; el vigésimo primero concreta la captura e invalidación de ID/EX; el vigésimo segundo concreta el avance de EX/MEM y el vigésimo tercero el de MEM/WB sin retenciones ni invalidaciones específicas; el vigésimo cuarto fija el bloque combinacional que coordina estos casos nominales. La tabla describe solo casos nominales; las coincidencias con faults se rigen semánticamente por los acuerdos décimo y duodécimo de `DEC-ARCH-004`. La integración RTL, los stalls de otras causas y las ecuaciones de selección y enables siguen abiertos; los nombres/códigos funcionales principales se fijan en el trigésimo cuarto acuerdo. Se conserva la prioridad local del acuerdo anterior.

#### Acuerdo parcial aprobado — selección exacta de fuentes de forwarding

**Fecha:** 2026-09-23

Para cada fuente `rs1` y `rs2` que la instrucción válida utilice y deba consumir o resolver al atravesar EX, la elección del valor efectivo será **independiente** y respetará la versión más reciente de ese registro en el orden del programa. Primero se identificará al productor pendiente más reciente que escriba arquitectónicamente `rd != x0` y cuyo `rd` coincida con el índice de esa fuente; la disponibilidad de su valor determinará si ya puede reenviarse. Las coincidencias de campos de operandos que la instrucción no usa no serán dependencias.

Si EX/MEM contiene ese productor válido y su valor arquitectónico correcto ya está disponible según la matriz del cuarto acuerdo, se seleccionará EX/MEM. Si EX/MEM **no es productor de ese registro**, y MEM/WB contiene un productor válido coincidente con escritura arquitectónica a `rd != x0`, se seleccionará desde MEM/WB **el mismo dato seleccionado para Write Back**. Solo cuando no exista un productor pendiente aplicable en EX/MEM ni MEM/WB se utilizará el valor original de la fuente transportado por ID/EX. Estos son criterios conceptuales, no nombres de señales o selectores RTL.

Si EX/MEM sí contiene al productor coincidente más reciente pero su resultado aún no está disponible, **no se elegirá MEM/WB ni ID/EX como sustitutos con una versión anterior**: el consumidor no ejecutará con ese valor y habrá sido retenido por el mecanismo de hazards correspondiente. Un load en EX/MEM es el caso característico; el `load-use stall` ya aprobado lo separa del consumidor y, tras la espera, el dato cargado se reenvía desde MEM/WB. Esta precisión no crea otro tipo de stall ni modifica su duración nominal.

Ambas fuentes se evalúan por separado: `sub x6, x5, x5` puede recibir el mismo valor de EX/MEM por `rs1` y `rs2`, mientras otra instrucción puede obtener una fuente de EX/MEM y la otra de MEM/WB o del valor original de ID/EX. `beq`, `bne` y `jalr` usarán estos operandos efectivos para su resolución en EX conforme a `DEC-ARCH-002`. En stores, `rs1` para la dirección y `rs2` para el dato se resolverán mediante esta misma selección en EX; el dato correcto viajará por EX/MEM hasta su consumo en MEM, sin bypass adicional hacia MEM.

La prioridad **EX/MEM > MEM/WB > ID/EX** significa identificar primero al productor más reciente y usar su valor solo cuando esté disponible; en caso contrario, esperar, nunca elegir el primer dato disponible de un productor anterior. El decimoséptimo acuerdo fija una unidad combinacional para controlar los muxes conforme a esta política; sus ecuaciones RTL y la integración física de forwarding, stall, redirect, flush y faults permanecen para acuerdos posteriores de `DEC-ARCH-003`; el trigésimo cuarto fija los códigos de selectores. Se preservan `DEC-ARCH-004` y la lectura combinacional, la escritura síncrona y la política de coincidencias WB→ID ya aprobadas en `DEC-ARCH-007`.

#### Acuerdo parcial aprobado — condición exacta de detección del hazard `load-use`

**Fecha:** 2026-09-23

La detección de `load-use` exigirá una dependencia verdadera e inmediata entre un load válido en ID/EX y la instrucción válida inmediatamente más joven en IF/ID. La condición conceptual será:

```text
load_use_stall =
    ID/EX.valid
    AND ID/EX.is_load
    AND ID/EX.rd != x0
    AND IF/ID.valid
    AND (
          (IF/ID.uses_rs1 AND IF/ID.rs1 == ID/EX.rd)
          OR
          (IF/ID.uses_rs2 AND IF/ID.rs2 == ID/EX.rd)
        )
```

En esta condición se expresan conceptos funcionales: el trigésimo séptimo acuerdo fija después los nombres combinacionales `uses_rs1` y `uses_rs2` en ID, sin agregarlos a IF/ID; los nombres RTL definitivos de las demás señales no se imponen aquí. En la ecuación, `IF/ID.rs1`, `IF/ID.rs2` y `IF/ID.uses_rs1`/`uses_rs2` designan índices y propiedades **derivados combinacionalmente de `IF/ID.instruction` en ID**, no campos físicos registrados en IF/ID; el decimocuarto acuerdo fija su contenido. Los indicadores de uso se derivarán de la instrucción decodificada según 3A: solo una fuente realmente leída podrá establecer una dependencia. Un productor o consumidor inválido, una instrucción productora distinta de load, `rd = x0` o una coincidencia accidental de bits en un campo no utilizado no generarán este stall.

Los stores utilizan tanto `rs1` (dirección) como `rs2` (dato), por lo que `load → store-address` y `load → store-data` inmediatos satisfacen esta misma condición; ambos valores deben estar resueltos cuando el store atraviese EX según 3B. `beq`, `bne` y `jalr` también se retendrán cuando su fuente efectiva dependa de ese load, para decidir el flujo en EX con el dato correcto. No se requieren detectores especiales para esas clases.

Si `load_use_stall` es verdadero y se autoriza un ciclo efectivo, se aplicará el stall nominal ya aprobado: PC e IF/ID se retienen, ID/EX recibe una bubble (`valid=0`) y EX/MEM y MEM/WB avanzan, permitiendo que el load llegue a MEM. Después, el consumidor podrá continuar y obtener el resultado del load desde MEM/WB por forwarding; no se agrega un bypass combinacional `DMEM → EX`. Un stall cuenta como un ciclo lógico incluso en STEP y no convierte esa transición en HOLD.

La ecuación no incluye un término redirect: la misma entrada ID/EX no puede contener simultáneamente un load y una instrucción de control que redirige en EX. Se preserva la prioridad local aprobada para otros stalls causados solo por trabajo joven `wrong-path`, sin fijar aquí la integración RTL de otras causas, faults o instrucciones inválidas; el décimo acuerdo de `DEC-ARCH-004` conserva el stall solo si ambas instrucciones sobreviven a la frontera. El decimosexto acuerdo fija su detector combinacional, sin imponer señales de control RTL finales ni un mecanismo nuevo de stall.

#### Acuerdo parcial aprobado — selección del valor arquitectónico de Write Back en MEM

**Fecha:** 2026-09-23

Durante MEM, **antes de capturar MEM/WB**, se seleccionará un único valor arquitectónico de 32 bits destinado a Write Back. Para un load válido que escriba arquitectónicamente `rd`, será el dato leído de DMEM tras la selección y ensamblado little-endian de los bytes y la extensión signed/unsigned correspondiente. Para una instrucción válida R-type, I-type aritmética/shifts, `lui`, `jal` o `jalr` que escriba `rd`, será el resultado arquitectónico producido en EX y transportado mediante EX/MEM, incluido `instruction_PC + 4` para el enlace. Conceptualmente:

```text
load válido que escribe rd                  -> wb_value = load_value
R-type, I-type, lui, jal o jalr que escribe rd -> wb_value = EX/MEM.ex_result
```

`load_value` describe el origen conceptual del dato cargado, sin fijar una señal intermedia. Los acuerdos siguientes fijan `wb_value` como campo físico de MEM/WB y `ex_result` como campo físico de EX/MEM. El vigésimo quinto acuerdo sitúa en EX el `Link Adder` del enlace de `jal`/`jalr` y su selección por el `Result MUX`, sin alterar su disponibilidad para forwarding desde EX/MEM. MEM/WB conservará **un único dato ya seleccionado** para la escritura en WB y para el forwarding posterior, que reutilizará exactamente ese mismo dato sin volver a reconstruir si provino de ALU, DMEM, LUI o `instruction_PC + 4`.

Para stores, branches, `halt`, entradas inválidas o cualquier instrucción que no escriba arquitectónicamente un registro, el contenido del valor seleccionado será irrelevante: validez y habilitación de escritura impedirán que esos bits provoquen escritura en el banco o forwarding. Un load con condición candidata de fault no podrá comprometer un resultado por la mera presencia de bits de dato; la confirmación y prioridad de errores de operaciones del flujo válido siguen correspondiendo a `DEC-ARCH-004`.

La lectura combinacional de DMEM acordada en `DEC-ARCH-006` permite resolver el dato cargado en MEM antes de capturar MEM/WB, pero **no añade un bypass combinacional `DMEM → EX`**. El load solo será fuente normal de forwarding hacia EX después de capturarse su valor en MEM/WB; el `load-use stall` nominal y el bloqueo de versiones anteriores permanecen vigentes.

Este acuerdo fija el punto de convergencia y el único dato arquitectónico hacia WB; el acuerdo siguiente fija los campos físicos de MEM/WB. No se impone el nombre o codificación del selector, las demás señales definitivas de control, las ecuaciones RTL ni la integración RTL de faults y otros eventos.

#### Acuerdo parcial aprobado — contenido físico de `MEM/WB`

**Fecha:** 2026-09-23

MEM/WB conservará únicamente los siguientes campos físicos funcionales, suficientes para Write Back, forwarding y la observabilidad mínima del pipeline:

```text
MEM/WB
├── valid
├── pc[31:0]
├── instruction[31:0]
├── rd[4:0]
├── reg_write
└── wb_value[31:0]
```

`valid` identifica una instrucción arquitectónicamente activa; con `valid=0`, los demás bits pueden ser residuales pero no habilitan escritura ni forwarding. `pc[31:0]` y `instruction[31:0]` conservan respectivamente el PC asociado y la palabra completa de la instrucción para la trazabilidad y observabilidad requeridas por Debug, conforme a `DEC-SYS-006`. La representación externa exacta del snapshot permanece para `DEC-ARCH-009`.

`rd[4:0]` identifica el destino arquitectónico para WB y las comparaciones de forwarding. `reg_write` indica si la instrucción escribe arquitectónicamente dicho registro; la escritura efectiva exige `valid`, `reg_write` y `rd != x0`, además de un ciclo habilitado conforme a `DEC-ARCH-008`. El forwarding desde MEM/WB exige igualmente esos tres términos y coincidencia con una fuente semánticamente usada, preservando la selección del productor más reciente.

`wb_value[31:0]` contiene el único dato arquitectónico seleccionado en MEM antes de capturar MEM/WB: el valor de load leído, ensamblado little-endian y extendido, o el `ex_result[31:0]` transportado por EX/MEM para R-type, I-type aritmética/shifts, `lui`, `jal` y `jalr` (incluido el enlace `instruction_PC + 4`). WB y el forwarding desde MEM/WB usan directamente este mismo campo, sin reconstruir su origen. El duodécimo acuerdo fija `ex_result` como campo físico de EX/MEM. Un load no reenvía desde EX/MEM ni por bypass combinacional `DMEM → EX`: su dato solo está disponible para forwarding normal tras la captura en MEM/WB.

MEM/WB no transportará por separado `ex_result`, `load_value`, `store_data`, `immediate`, `rs1`, `rs2`, `rs1_value`, `rs2_value` ni `mem_op`: ya se consumieron o convergieron en `wb_value`. Para stores, branches, `halt`, entradas inválidas u otras instrucciones sin escritura de registro, los bits de `wb_value` carecen de efecto arquitectónico. Un candidato de fault tampoco se convierte en escritura válida por presentar datos residuales; su confirmación y ausencia de efectos están fijadas en `DEC-ARCH-004`; solo resta la integración RTL en `DEC-ARCH-003`. Agregar otros campos físicos a MEM/WB requerirá una revisión explícita de este acuerdo, incluso si la definición de Debug de `DEC-ARCH-009` identificase otra necesidad de observabilidad.

Se fijan los campos físicos funcionales de MEM/WB; el vigésimo tercer acuerdo concreta su captura nominal y la propagación de invalidez desde EX/MEM, sin flush específico por `load-use` o redirect. El trigésimo cuarto acuerdo fija `reg_write` como señal de un bit (0/1); los acuerdos cuadragésimo primero y segundo fijan después la selección de acciones y las ecuaciones de actualización de MEM/WB, sin cambiar este contenido físico; quedan abiertas otras coincidencias no cubiertas. El acuerdo siguiente fija los campos de EX/MEM; la política de los demás latches y las prioridades de eventos todavía abiertas permanecen en `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — contenido físico de `EX/MEM`

**Fecha:** 2026-09-23

EX/MEM conservará únicamente los siguientes campos físicos funcionales, necesarios para completar las operaciones de memoria en MEM, permitir forwarding y preservar la observabilidad mínima del pipeline:

```text
EX/MEM
├── valid
├── pc[31:0]
├── instruction[31:0]
├── rd[4:0]
├── reg_write
├── mem_op
├── ex_result[31:0]
└── store_data[31:0]
```

`valid` identifica una instrucción arquitectónicamente activa. Una entrada inválida no podrá escribir DMEM ni posteriormente el banco de registros, reenviar un valor ni producir otro efecto funcional aunque sus demás bits sean residuales. `pc[31:0]` e `instruction[31:0]` conservan el PC asociado y la palabra completa de la instrucción para su trazabilidad y observabilidad conforme a `DEC-SYS-006`. La representación externa del snapshot se decidirá en `DEC-ARCH-009`.

`rd[4:0]` identifica el destino de instrucciones escritoras para las comparaciones de forwarding y su transporte hacia MEM/WB cuando corresponda. `reg_write` indica la intención arquitectónica de escribir `rd`; la codificación y las ecuaciones concretas de control siguen diferidas. El forwarding desde EX/MEM requiere un productor válido con escritura, `rd != x0`, coincidencia con una fuente semánticamente usada y disponibilidad del valor arquitectónico correcto. Un load en EX/MEM puede tener `reg_write`, pero su `ex_result` es la dirección efectiva, **no** el dato a escribir en `rd`, por lo que no reenvía desde esa etapa ni habilita un bypass `DMEM → EX`.

`mem_op` transporta a MEM la información necesaria para distinguir load de store, ancho de acceso y, para cargas, extensión con signo o con cero. El trigésimo cuarto acuerdo fija después `mem_op[3:0]` y su codificación para NONE, cinco loads y tres stores. Para loads y stores, `ex_result[31:0]` contiene la dirección efectiva que MEM usará para acceder a DMEM. Para R-type, I-type aritmética/shifts, `lui`, `jal` y `jalr`, contiene el valor arquitectónico producido en EX, reenviable cuando se cumplen las condiciones anteriores y transportado a MEM para la selección de `wb_value` antes de MEM/WB; en `jal` y `jalr` es el enlace `instruction_PC + 4`, calculado en EX desde `ID/EX.pc` conforme al vigésimo quinto acuerdo, sin adelantar la escritura del banco a EX. El vigésimo sexto acuerdo concreta la selección de estos valores y direcciones mediante el `Result MUX`.

`store_data[31:0]` conserva el valor efectivo de `rs2` resuelto mediante forwarding al atravesar EX; `sb`, `sh` y `sw` lo consumen en MEM para escribir DMEM. La dirección proviene de `ex_result`, mientras `mem_op` define el acceso. También para `load → store-data` inmediato se conserva el stall nominal y el forwarding posterior MEM/WB→EX: no se agrega bypass especial hacia MEM. Una entrada inválida con `mem_op` y `store_data` residuales no podrá habilitar una escritura a DMEM; las condiciones candidatas de fault no se confirman por sí solas, conforme a `DEC-ARCH-004` ya aprobada.

No se transportarán por separado en EX/MEM `rs1`, `rs2`, `rs1_value`, `rs2_value`, `immediate`, `link_value` ni `alu_result`: los valores necesarios ya se consumieron en EX o quedaron consolidados en `ex_result` o `store_data`. Agregar otros campos físicos requerirá revisión explícita de este acuerdo, incluso si `DEC-ARCH-009` identificase otra necesidad de observabilidad.

Este acuerdo fija los campos físicos funcionales de EX/MEM; el vigésimo segundo acuerdo fija su captura nominal sin retención por `load-use` ni invalidación por redirect. Siguen abiertos la codificación de `mem_op`, los enables y prioridades fuera de esos casos nominales, el control concreto de escritura de memoria, la integración con faults y las demás señales y ecuaciones RTL. El acuerdo siguiente fija los campos de ID/EX, sin cerrar la composición interna de su control.

#### Acuerdo parcial aprobado — contenido físico de `ID/EX`

**Fecha:** 2026-09-23

ID/EX conservará los siguientes **diez elementos funcionales enumerados**, necesarios para ejecutar en EX, resolver las fuentes por forwarding, transportar el destino y preservar la observabilidad mínima del pipeline. El elemento `control` es un placeholder de información semántica y no exige un único campo RTL físico, conforme a la revisión explícita del trigésimo tercer acuerdo:

```text
ID/EX
├── valid
├── pc[31:0]
├── instruction[31:0]
├── rs1[4:0]
├── rs2[4:0]
├── rd[4:0]
├── rs1_value[31:0]
├── rs2_value[31:0]
├── immediate[31:0]
└── control
```

`valid` identifica una instrucción arquitectónicamente activa. Una entrada con `valid=0` no podrá originar efectos funcionales, hazards o forwarding como instrucción válida, aunque los demás campos conserven bits residuales. La bubble del stall `load-use` y el flush de una redirección invalidan ID/EX con `valid=0`, sin obligar a limpiar otros bits ni codificar causas distintas. `pc[31:0]` conserva el PC **de esta instrucción** para calcular destinos relativos al PC o el enlace `instruction_PC + 4` cuando corresponda; `instruction[31:0]` conserva la palabra completa para trazabilidad y observabilidad según `DEC-SYS-006`. La representación externa exacta seguirá en `DEC-ARCH-009`.

`rs1[4:0]` y `rs2[4:0]` guardan los índices extraídos en ID para comparar, **independientemente por cada fuente realmente usada**, con `rd` de productores pendientes en EX/MEM y MEM/WB. Su presencia física no convierte un campo no utilizado en fuente semántica: rige la clasificación 3A y no se activan hazards ni forwarding por coincidencias accidentales. `rs1_value[31:0]` y `rs2_value[31:0]` contienen los valores base capturados en ID tras el bypass interno WB→ID cuando corresponda; cada uno es la base en EX solo cuando no hay productor pendiente aplicable para esa fuente. Se mantiene la selección por versión más reciente **EX/MEM disponible > MEM/WB > ID/EX**: si un productor más reciente coincide pero su valor todavía no está disponible, no se utiliza el valor original ni otro anterior. La lectura combinacional, la escritura síncrona, el bypass interno explícito WB→ID y su frontera funcional con forwarding externo ya están fijados en `DEC-ARCH-007`: un valor base posbypass cede ante el productor pendiente más reciente en EX, sin alterar la selección aprobada. La elección del recurso físico queda para implementación, bajo el contrato aprobado de `DEC-ARCH-007` y las prioridades globales ya fijadas.

`rd[4:0]` conserva el destino arquitectónico y avanzará a las etapas siguientes cuando corresponda. `immediate[31:0]` contiene el inmediato generado y extendido en ID para las instrucciones que lo usan en EX. `control` designa colectivamente la información requerida en EX y, cuando corresponda, en etapas posteriores: el trigésimo tercer acuerdo fija sus categorías `alu_op`, `alu_src`, `result_sel`, `flow_op`, `mem_op` y `reg_write`, sin obligar a agruparlas en un campo físico único. El trigésimo cuarto acuerdo fija luego sus nombres, anchos y códigos funcionales principales; las ecuaciones RTL del control path y el empaquetado opcional permanecen abiertos.

Los índices y valores de fuente permiten aplicar la misma política a ALU, stores, branches y `jalr`: ambos operandos de store se resuelven al atravesar EX aunque su dato se consuma en MEM, y una dependencia `load-use` inmediata conserva el stall nominal sin bypass `DMEM → EX`. El contenido físico de ID/EX no introduce nuevas prioridades entre stall, redirect, flush o faults. Cualquier campo físico adicional requerirá revisión explícita de este acuerdo, también si `DEC-ARCH-009` identificase otra necesidad de observabilidad.

Este acuerdo enumera diez elementos funcionales de ID/EX, incluido el placeholder `control` cuya composición semántica revisa el trigésimo tercero; el vigésimo primer acuerdo concreta su captura nominal y la invalidación física de `valid` para bubble y flush. Siguen abiertos nombres, representación/codificación y ecuaciones RTL de control y la integración física de la política de faults aprobada en `DEC-ARCH-004`. El acuerdo siguiente fija los campos físicos de IF/ID.

#### Acuerdo parcial aprobado — contenido físico de `IF/ID`

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-23

La aprobación original de este decimocuarto acuerdo fijó los **tres campos de instrucción** de IF/ID. El vigésimo noveno acuerdo lo **revisa explícitamente** para añadir dos campos de candidato de fetch; el contenido físico vigente es:

```text
IF/ID
├── valid
├── pc[31:0]
├── instruction[31:0]
├── fetch_fault_valid
└── fetch_fault_cause[2:0]
```

`valid` indica si la entrada representa una instrucción arquitectónicamente activa. Con `valid=0`, la lógica de decodificación, hazards y control no podrá tratarla como instrucción válida ni permitir efectos de esa instrucción aunque los bits de `instruction` sean residuales; **`fetch_fault_valid=1` identifica por separado un candidato de fetch**, aún no confirmado. `pc[31:0]` conserva el PC propio de la instrucción obtenida o del fetch candidato, no el PC global de IF; acompaña a una instrucción válida cuando avance a ID/EX para cálculos relativos al PC y enlace `instruction_PC + 4` en EX. `instruction[31:0]` conserva la palabra completa de una instrucción válida para decode y trazabilidad conforme a `DEC-SYS-006`; no tiene significado arquitectónico en una entrada de fetch fault.

En ID, a partir de `instruction[31:0]` se extraerán combinacionalmente `rs1`, `rs2` y `rd`, se generará el inmediato correspondiente y se derivará la clasificación semántica de fuentes de 3A. No se registrarán por separado en IF/ID `rs1`, `rs2`, `rd`, `uses_rs1` ni `uses_rs2`: los términos `IF/ID.rs1`/`rs2` y `IF/ID.uses_rs1`/`uses_rs2` de la condición de `load-use` son notación conceptual para los valores derivados, no campos adicionales. Solo las fuentes realmente usadas y una entrada válida podrán establecer una dependencia; la coincidencia de bits de un campo no utilizado no provocará stall.

En un ciclo efectivo de `load-use stall`, IF/ID retiene **sus cinco campos sin cambios** para conservar al consumidor, mientras PC se retiene e ID/EX recibe una bubble. Si IF detecta entonces un fetch fault válido, se aplica la excepción de confirmación en IF del vigésimo noveno acuerdo sin capturar su candidato en IF/ID. Ante redirect válido en EX, IF/ID queda con `valid=0` **y `fetch_fault_valid=0`** para descartar tanto trabajo joven como candidato de fetch `wrong-path`; `pc` e `instruction` no necesitan borrarse y el fetch del target no se captura como válido en el mismo flanco. Una entrada inválida sin flag de fault no decodifica trabajo ni confirma error por residuos. `DEC-ARCH-004` fija validez, antigüedad y prioridad de causas; un target desalineado no aplica el redirect nominal aquí descrito.

Los **cinco campos** son el contenido físico funcional revisado de IF/ID; cualquier otro campo requeriría una nueva revisión explícita, también si `DEC-ARCH-009` determinase que necesita más estado registrado para Debug. El decimoctavo acuerdo fija el mecanismo general de retención e invalidación y el vigésimo precisa la actualización física nominal de IF/ID; el vigésimo noveno añade el transporte de candidato sin alterar `valid`. El cuadragésimo segundo acuerdo fija después las ecuaciones de captura/retención/invalidez de IF/ID para las nueve acciones; el cuadragésimo cuarto acuerdo fija después la FSM/control global de ciclos; otras coincidencias siguen pendientes de `DEC-ARCH-003`. El acuerdo siguiente fija los muxes de forwarding hacia EX.

#### Acuerdo parcial aprobado — realización física del forwarding hacia EX

**Fecha:** 2026-09-23

El camino de forwarding hacia EX empleará **dos multiplexores combinacionales independientes de tres entradas y 32 bits**, uno para cada fuente semánticamente utilizada. Su estructura física de datos será:

```text
Forward MUX A
├── ID/EX.rs1_value[31:0]
├── EX/MEM.ex_result[31:0]
└── MEM/WB.wb_value[31:0]
        ↓
rs1_effective[31:0]
```

```text
Forward MUX B
├── ID/EX.rs2_value[31:0]
├── EX/MEM.ex_result[31:0]
└── MEM/WB.wb_value[31:0]
        ↓
rs2_effective[31:0]
```

Cada mux se seleccionará independientemente: las dos fuentes pueden tomar datos de etapas distintas, ambas de una misma etapa o una del valor original. La identificación del productor pendiente **más reciente** de cada registro usado precede a la selección del dato. Se conserva la prioridad conceptual **EX/MEM disponible > MEM/WB > ID/EX**: se usa `EX/MEM.ex_result` si allí hay un productor válido que escribe `rd != x0`, coincide con la fuente y ya tiene disponible el valor arquitectónico correcto; si EX/MEM no produce esa fuente, se permite `MEM/WB.wb_value` de un productor válido coincidente y escritor; si no hay productor pendiente aplicable, se elige el valor original de ID/EX. Una instrucción inválida, una fuente no utilizada, un productor sin escritura o una escritura a `x0` no habilitan forwarding por mera coincidencia de campos.

Desde EX/MEM pueden reenviarse resultados disponibles de R-type, I-type aritmética/shifts, `lui` y enlaces `instruction_PC + 4` de `jal`/`jalr`. Para un load en EX/MEM, `ex_result` contiene la **dirección efectiva**, no el dato cargado. Si ese load es el productor coincidente más reciente, el consumidor esperará según la política de hazards aprobada: ni un MEM/WB anterior ni el valor original obsoleto de ID/EX se elegirán como operandos válidos; el decimoséptimo acuerdo distingue esta regla del valor combinacional residual que pueda presentar físicamente un mux durante la espera. Tras la captura del dato en MEM/WB podrá elegirse `wb_value`, el mismo valor arquitectónico utilizado para Write Back sin reconstruir su origen (ALU, DMEM, enlace o `lui`). No se incorpora bypass combinacional `DMEM → EX` ni se modifica el stall `load-use` nominal.

Los valores efectivos de ambos muxes se utilizarán en EX según la clase de instrucción: operaciones ALU, operandos de `beq`/`bne` y `jalr`, base y dato de stores resuelto al atravesar EX. La topología de los dos muxes no fijó las señales selectoras ni su ancho o codificación, determinados después para `forward_a_sel[1:0]`/`forward_b_sel[1:0]` en el trigésimo cuarto acuerdo; las ecuaciones RTL de la unidad se fijan después en el trigésimo noveno acuerdo; permanecen abiertos otros caminos de datos y la integración RTL frente a redirect, flush o faults. Las notaciones `rs1_effective` y `rs2_effective` describen las salidas de los muxes; sus selectores son `forward_a_sel[1:0]` y `forward_b_sel[1:0]` conforme a los acuerdos posteriores. El acuerdo siguiente fija el bloque combinacional que detecta `load-use` en ID y el decimoséptimo la unidad que controla los dos muxes.

#### Acuerdo parcial aprobado — realización física del detector de hazard `load-use`

**Fecha:** 2026-09-23

Un **bloque combinacional ubicado lógicamente en ID** observará al productor inmediatamente anterior en ID/EX y al consumidor en IF/ID. Sus entradas conceptuales serán:

```text
Desde ID/EX
├── valid
├── rd[4:0]
└── información que permita determinar is_load

Desde IF/ID / decodificación en ID
├── valid
├── rs1[4:0]
├── rs2[4:0]
├── uses_rs1
└── uses_rs2
```

El resultado conceptual `load_use_stall` se determinará **exactamente** por la condición ya aprobada:

```text
load_use_stall =
    ID/EX.valid
    AND ID/EX.is_load
    AND ID/EX.rd != x0
    AND IF/ID.valid
    AND (
          (IF/ID.uses_rs1 AND IF/ID.rs1 == ID/EX.rd)
          OR
          (IF/ID.uses_rs2 AND IF/ID.rs2 == ID/EX.rd)
        )
```

El bloque podrá usar comparaciones de igualdad entre cada índice fuente y `ID/EX.rd`, junto con lógica combinacional para validez, clase load, `rd != x0` y uso real de las fuentes. Su clase `is_load` se obtiene de información ya disponible en ID/EX sin fijar un subcampo, ancho o codificación de `ID/EX.control`. Los índices `rs1`/`rs2` y `uses_rs1`/`uses_rs2` del consumidor se derivan combinacionalmente de `IF/ID.instruction` en ID: el trigésimo séptimo acuerdo fija después las salidas combinacionales del decoder, sin añadir campos físicos a IF/ID. Coincidencias accidentales en fuentes no usadas, `rd=x0`, un productor no load o entradas inválidas no activarán el resultado. El detector puede representarse como un único bloque **Load-Use Hazard Detector**, sin exponer compuertas individuales en el diagrama arquitectónico.

La salida es un resultado combinacional: puede evaluarse durante HOLD, pero **solo un ciclo lógico efectivo** podrá aplicar sus efectos. Para un `load_use_stall` verdadero en el caso nominal, PC e IF/ID se retienen, ID/EX recibe bubble (`valid=0`) y EX/MEM y MEM/WB avanzan; el load llega a MEM y el consumidor continuará luego con forwarding desde MEM/WB. Esta condición incluye dependencias reales sobre base o dato de stores, operandos de `beq`/`bne` y fuente de `jalr`, sin añadir detectores específicos ni cambiar el stall nominal de un ciclo.

La ecuación no incorpora redirect: en la misma entrada ID/EX no pueden estar a la vez el load que activa esta detección y la instrucción de control que redirige en EX. Se conserva la prioridad local aprobada para stalls debidos exclusivamente al trabajo joven `wrong-path`; el décimo acuerdo de `DEC-ARCH-004` aplica el stall de `load-use` solo si productor y consumidor sobreviven como anteriores a un fault, descartando dependencias cuyo consumidor sea causante o joven. La realización temporal/física de la confirmación de faults y las demás coincidencias continúan pendientes, sin cambiar el detector combinacional nominal: su resultado solo se **aplica** cuando el hazard sigue siendo necesario. Este acuerdo fija el bloque combinacional, sus entradas y la condición que evalúa; el vigésimo cuarto acuerdo incorpora su resultado conceptual al `Pipeline Hazard Control` nominal, sin fijar nombres RTL definitivos de señales hacia enables/retención/flush ni su integración con otros eventos. El acuerdo siguiente fija la unidad combinacional de selección de forwarding, separada de este detector.

#### Acuerdo parcial aprobado — realización física de la `Forwarding Unit`

**Fecha:** 2026-09-23

Una **Forwarding Unit combinacional** controlará de forma independiente los dos multiplexores 3:1 de 32 bits aprobados para los operandos efectivos de EX. Observará conceptualmente:

```text
Desde ID/EX
├── rs1[4:0]
├── rs2[4:0]
├── uses_rs1
└── uses_rs2

Desde EX/MEM
├── valid
├── rd[4:0]
├── reg_write
└── información que permita determinar disponibilidad del resultado

Desde MEM/WB
├── valid
├── rd[4:0]
└── reg_write
```

Sus dos salidas conceptuales, `forward_a_sel` y `forward_b_sel`, seleccionarán independientemente para cada fuente realmente usada el dato original `ID/EX.rs1_value` o `ID/EX.rs2_value`, `EX/MEM.ex_result` o `MEM/WB.wb_value` a través del mux correspondiente. `uses_rs1` y `uses_rs2` son propiedades derivables de la instrucción/control ya disponible en ID/EX, **no campos físicos adicionales**; la disponibilidad del resultado en EX/MEM también se determina con información ya conservada allí, sin fijar su codificación ni añadir un campo al latch. Una entrada consumidora de ID/EX con `valid=0` no podrá usar arquitectónicamente selecciones combinacionales residuales, sin imponer aquí un puerto físico adicional de la unidad.

Para cada fuente, la unidad identificará primero al **productor pendiente más reciente** que escriba arquitectónicamente `rd != x0` y coincida con su índice. Si EX/MEM contiene ese productor válido y su resultado arquitectónico correcto ya está disponible, seleccionará `EX/MEM.ex_result`. Si EX/MEM no produce ese registro y MEM/WB contiene un productor válido coincidente con `reg_write` y `rd != x0`, seleccionará `MEM/WB.wb_value`. Si no existe productor pendiente aplicable, conservará el valor original de ID/EX. Ni un productor inválido o sin escritura ni una coincidencia en una fuente semánticamente no usada habilitarán forwarding. La selección de `rs1` y `rs2` será independiente y podrá escoger etapas distintas o la misma etapa según corresponda.

Si EX/MEM contiene el productor coincidente más reciente pero su dato todavía no está disponible, **no se utilizará MEM/WB ni ID/EX como sustituto obsoleto**. El consumidor deberá haber sido retenido por el mecanismo de hazards correspondiente; el valor combinacional que pueda presentar físicamente un mux durante esa espera no se consumirá como operando válido y no requiere una cuarta entrada o codificación de selección. Un load en EX/MEM tiene en `ex_result` solo la dirección efectiva y es el caso característico. El dato cargado podrá llegar por `MEM/WB.wb_value` tras la captura en MEM/WB, sin bypass `DMEM → EX` ni un nuevo tipo de stall.

Este acuerdo fija la unidad funcional combinacional, su información de entrada y la política para controlar ambos muxes, preservando la matriz de resultados reenviables y el valor de WB ya seleccionado en MEM. El trigésimo segundo acuerdo fija posteriormente las ecuaciones booleanas funcionales de coincidencia y selección por fuente; no modifica esta política ni agrega campos. `forward_a_sel[1:0]` y `forward_b_sel[1:0]` reciben nombres, anchos y códigos funcionales definitivos en el trigésimo cuarto acuerdo; el trigésimo noveno acuerdo fija después las ecuaciones RTL de coincidencia, selectores y muxes combinacionales, sin cerrar la integración global con detector `load-use`, enables, invalidaciones, redirect y faults. La lectura combinacional, la escritura síncrona, el bypass interno explícito que garantiza el valor nuevo en WB→ID y su frontera funcional con forwarding externo y `load-use` están fijados en `DEC-ARCH-007`; su séptimo acuerdo fija la integración temporal con avance, HOLD, reset y sesión conforme a `DEC-ARCH-008`, mientras el octavo acuerdo impide que la tecnología física del banco altere ese contrato; su realización RTL se concretará en implementación. La confirmación arquitectónica de faults está fijada en `DEC-ARCH-004` y su implementación RTL se integra en `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — realización física de retención, bubble e invalidación

**Fecha:** 2026-09-23

Para los casos nominales de `load-use stall` y redirect se distinguirán dos mecanismos físicos generales: **retención**, que impide capturar valores nuevos y conserva íntegro el contenido registrado, e **invalidación**, que captura una entrada inválida o fuerza `valid=0` en el latch afectado. PC e IF/ID tendrán mecanismos conceptuales de habilitación de escritura que permitan retenerlos inhibiendo su actualización en un ciclo efectivo; este acuerdo no fija nombres ni ecuaciones RTL de esos enables.

Ante un `load-use stall` nominal durante un ciclo lógico efectivo:

```text
PC      → retiene su valor
IF/ID   → retiene sus cinco campos sin cambios (tras la revisión del acuerdo 29)
ID/EX   → recibe bubble mediante valid=0
EX/MEM  → avanza con el load productor
MEM/WB  → avanza con la instrucción anterior
```

Así el consumidor permanece íntegro en IF/ID y el load previamente ubicado en ID/EX avanza, sin congelar EX/MEM o MEM/WB ni capturar en IF/ID la instrucción siguiente. La bubble se materializa invalidando la **nueva entrada de ID/EX** (`valid=0`), no reteniendo el load en ese latch. No se exige escribir una NOP física ni borrar los otros campos: los residuos de una entrada inválida no habilitan ejecución, escrituras, redirect, `halt` o faults arquitectónicos.

Ante un redirect válido resuelto en EX durante un ciclo lógico efectivo:

```text
PC      → captura redirect_target
IF/ID   → queda inválido con valid=0
ID/EX   → queda inválido con valid=0
EX/MEM  → avanza con la instrucción de control válida
MEM/WB  → avanza con la instrucción anterior
```

El flush de IF/ID e ID/EX descarta trabajo más joven `wrong-path` sin necesitar limpiar PC, instrucción u otros bits residuales de esos latches; en IF/ID **también se limpia `fetch_fault_valid`** cuando ese candidato pertenece al camino descartado, aunque `valid` ya sea cero. No se captura como válida la instrucción del target en IF/ID en el mismo flanco del redirect. Una solicitud de retención causada **exclusivamente** por ese trabajo joven no impediría capturar el target ni conservaría como válido lo descartado, conforme a la prioridad local ya aprobada. Esto no declara una prioridad universal entre redirect y otras causas.

En síntesis, **retener significa no capturar una entrada nueva**; bubble o flush significan producir `valid=0` en la entrada afectada. Son resultados de un ciclo efectivo, no de la evaluación combinacional durante HOLD; un STEP autorizado se consume y el contador lógico avanza una vez conforme a `DEC-ARCH-008`. Se fija el mecanismo físico general de estos dos casos nominales, sin elegir nombres RTL, ecuaciones de enable/flush, ecuaciones RTL de integración con faults de `DEC-ARCH-004`, otros stalls o eventos concurrentes ni la realización restante del control path.

#### Acuerdo parcial aprobado — realización física del control de actualización del PC

**Fecha:** 2026-09-23

El control nominal de actualización del registro PC utilizará un **Next-PC MUX** con dos entradas conceptuales, `pc_plus_4` y `redirect_target`, seguido de un registro PC con habilitación de escritura:

```text
pc_plus_4 --------\
                   > Next-PC MUX ---> PC
redirect_target --/

PC
└── write_enable
```

`pc_plus_4` representa el próximo PC secuencial calculado desde el **PC global actual**; no es el enlace `instruction_PC + 4` de una instrucción en EX. El mux selecciona el valor de flujo secuencial o el destino de una redirección válida resuelta en EX. PC solo captura la salida seleccionada cuando se habilita su escritura durante un ciclo lógico efectivo. En los casos nominales ya aprobados:

| Situación | Next-PC MUX | Escritura de PC | Resultado |
|---|---|---|---|
| Avance normal | Selecciona `pc_plus_4` | Habilitada | PC captura el valor secuencial |
| `load-use stall` | Irrelevante | Deshabilitada | PC conserva íntegramente su valor |
| Redirect válido en EX | Selecciona `redirect_target` | Habilitada | PC captura el destino |

Durante el stall nominal, el valor en la entrada del registro PC no importa mientras se inhiba su escritura; IF/ID conserva sus cinco campos conforme a la revisión del acuerdo vigésimo noveno e ID/EX recibe una bubble, mientras los latches más antiguos avanzan. Durante el redirect, la carga del destino se coordina con `IF/ID.valid=0`, `IF/ID.fetch_fault_valid=0` e `ID/EX.valid=0`, sin capturar el fetch del target como válido en IF/ID en ese mismo flanco. Un stall provocado **exclusivamente** por trabajo joven `wrong-path` que se invalidará no inhibirá la carga de `redirect_target`, conforme a la prioridad local ya aprobada. Un branch no tomado sigue el flujo secuencial salvo que se aplique un stall independiente válido; una entrada inválida en EX no puede solicitar redirect por sus bits residuales.

La habilitación local de escritura opera bajo la autorización global de `DEC-ARCH-008`: durante HOLD no se captura ningún próximo PC aunque el mux presente un valor; un STEP aceptado aplica a lo sumo una actualización en su único ciclo efectivo. Reset y LOAD conservan su prioridad global sin imponer entradas adicionales al mux nominal. Se fija la **estructura física general** de selección y escritura del PC, sin fijar nombres RTL definitivos, codificación del selector, ecuaciones de habilitación o selección, realización del sumador secuencial ni ecuaciones RTL de integración con faults de `DEC-ARCH-004`, otros stalls o eventos concurrentes.

#### Acuerdo parcial aprobado — realización física de la actualización de `IF/ID`

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-23

El registro IF/ID dispondrá conceptualmente de **habilitación de escritura** para capturar o retener su contenido, y de un mecanismo de invalidación capaz de producir `valid_next=0`:

```text
IF/ID
├── write_enable
└── mecanismo para producir valid_next = 0
```

Durante un ciclo lógico efectivo de avance normal, IF/ID tiene la escritura habilitada y captura conjuntamente desde IF sus **cinco campos** tras la revisión explícita del vigésimo noveno acuerdo: `valid`, `pc[31:0]`, `instruction[31:0]`, `fetch_fault_valid` y `fetch_fault_cause`. La validez de instrucción capturada no se deduce de un candidato de fetch: fetch normal captura `valid=1, fetch_fault_valid=0`; fetch candidato captura `valid=0, fetch_fault_valid=1` con PC y causa asociados. Durante un `load-use stall` nominal se deshabilita la escritura: IF/ID **retiene íntegramente** sus cinco campos, preservando al consumidor en ID mientras el load anteriormente situado en ID/EX avanza; ID/EX recibe una bubble según el acuerdo de transiciones. La excepción aprobada para un fetch fault de IF que coincide con ese stall confirma directamente en IF sin escribir su candidato sobre el consumidor.

Ante un redirect válido resuelto en EX durante un ciclo efectivo, IF/ID produce `valid_next=0` **y `fetch_fault_valid_next=0`** y descarta su entrada joven, incluso si ya era un candidato con `valid=0`. `pc`, `instruction` y `fetch_fault_cause` pueden conservar bits residuales: no se exige limpiar esos campos ni escribir una NOP física; sin `valid` ni flag de candidato no se permiten efectos ni confirmación de fault del trabajo descartado. La instrucción del target no se captura como válida en IF/ID en el mismo flanco. Si una solicitud de retención coincide con ese redirect y **proviene exclusivamente de trabajo joven `wrong-path`** que se invalidará, prevalece el descarte: no se retiene trabajo incorrecto. Esta prioridad local no determina el tratamiento de otras causas de retención.

La aplicación de captura, retención o invalidación requiere un ciclo efectivo autorizado por `DEC-ARCH-008`: la evaluación combinacional durante HOLD no modifica IF/ID y un STEP aceptado aplica una sola transición. Queda fijada la estructura física general de actualización de IF/ID para los casos nominales; `write_enable`, `valid_next` y `fetch_fault_valid_next` son nombres conceptuales, sin fijar nombres RTL definitivos, codificación de señales, ecuaciones de control ni ecuaciones RTL de integración con faults de `DEC-ARCH-004` u otros eventos concurrentes. La ampliación a cinco campos está documentada **explícitamente** en el vigésimo noveno acuerdo; fuera de ella no se agregan campos registrados.

#### Acuerdo parcial aprobado — realización física de la actualización de `ID/EX`

**Fecha:** 2026-09-23

En avance normal durante un ciclo lógico efectivo, ID/EX captura desde ID los **diez elementos funcionales enumerados**, asociados a la misma entrada: `valid`, `pc[31:0]`, `instruction[31:0]`, `rs1[4:0]`, `rs2[4:0]`, `rd[4:0]`, `rs1_value[31:0]`, `rs2_value[31:0]`, `immediate[31:0]` y el conjunto semántico `control`, sin exigir un único bus RTL para este último conforme al trigésimo tercer acuerdo. Capturar una entrada inválida no la convierte en una instrucción activa.

Ante un `load-use stall` nominal, la **nueva entrada** de ID/EX tendrá `valid_next=0`: se inserta una bubble por espera, no se retiene en ID/EX el load que lo ocupaba. Ese load avanza simultáneamente hacia EX/MEM, mientras el consumidor permanece íntegro en IF/ID y las instrucciones anteriores continúan avanzando. Ante un redirect válido resuelto en EX, también se produce `ID/EX.valid_next=0`, esta vez como flush que descarta la entrada joven `wrong-path`; la instrucción de control más antigua continúa válida hacia EX/MEM. En el caso nominal de `load-use` la entrada en EX es un load, por lo que no coincide en ese mismo ID/EX con la instrucción de control que redirige. Para una petición de retención causada exclusivamente por trabajo joven descartado sigue rigiendo la prioridad local de redirect previamente aprobada, sin extenderla a otros eventos.

```text
load-use stall → bubble por espera  ─┐
                                     ├→ ID/EX.valid_next = 0
redirect       → flush por descarte ─┘
```

No se necesita escribir una NOP física ni borrar `pc`, `instruction`, índices de registros, `rd`, valores de operandos, inmediato o `control`: sus bits residuales con `valid=0` no producen efectos funcionales, hazards o forwarding como instrucción válida. Bubble y flush tienen causas distintas y el mismo efecto físico nominal sobre `valid` de la nueva entrada; no se agrega un campo de causa. La captura e invalidación solo se aplican en ciclos efectivos RUN/STEP conforme a `DEC-ARCH-008`; una evaluación combinacional durante HOLD no cambia ID/EX. Un STEP aceptado consume exactamente el ciclo efectivo en que se aplica la transición. Este acuerdo no fija nombres RTL definitivos, codificación, ecuaciones de invalidación ni ecuaciones RTL de integración con faults de `DEC-ARCH-004` u otros eventos concurrentes, y no agrega campos ni codifica `ID/EX.control`.

#### Acuerdo parcial aprobado — realización física de la actualización de `EX/MEM`

**Fecha:** 2026-09-24

En cada ciclo lógico efectivo habilitado de los casos nominales de avance normal, `load-use stall` y redirect válido en EX, EX/MEM **captura la salida de la instrucción que ocupaba ID/EX al comenzar la transición**, junto con los resultados correspondientes de EX. El nuevo `ID/EX.valid_next=0` producido por bubble o flush en ese mismo ciclo no sustituye el `ID/EX.valid` anterior que alimenta la captura en EX/MEM. No se retiene ni invalida EX/MEM por ninguno de esos dos eventos nominales.

```text
EX/MEM.next.valid        = ID/EX.valid
EX/MEM.next.pc           = ID/EX.pc
EX/MEM.next.instruction  = ID/EX.instruction
EX/MEM.next.rd           = ID/EX.rd
EX/MEM.next.reg_write    = control correspondiente a la instrucción en EX
EX/MEM.next.mem_op       = control correspondiente a la instrucción en EX
EX/MEM.next.ex_result    = ex_result producido en EX
EX/MEM.next.store_data   = rs2_effective resuelto en EX
```

Estas expresiones son conceptuales: `reg_write` y `mem_op` provienen del control correspondiente sin fijar su codificación, y el valor de `store_data` solo tiene uso funcional para un store válido. `ex_result` representa la dirección efectiva para loads/stores o el resultado arquitectónico ya aprobado de ALU/LUI/enlace para las otras clases; **un load en EX/MEM transporta dirección, no dato cargado para forwarding hacia EX**. Si ID/EX estaba inválido, EX/MEM captura `valid=0`; los demás campos pueden contener residuos sin efectos funcionales.

Ante un `load-use stall` nominal, EX/MEM captura **el load válido que estaba en ID/EX** y permite que avance hacia MEM y luego MEM/WB, mientras IF/ID retiene al consumidor e ID/EX recibe una bubble. El dato del load se podrá reenviar posteriormente desde MEM/WB, no desde EX/MEM. Ante un redirect válido resuelto en EX, EX/MEM captura **la instrucción de control válida que estaba en ID/EX**, mientras PC adopta `redirect_target` e IF/ID e ID/EX quedan inválidos para descartar el trabajo más joven `wrong-path`. La instrucción de control no forma parte de ese descarte y continúa hacia etapas posteriores, incluido WB para un enlace de `jal`/`jalr` cuando corresponda. En avance normal, EX/MEM captura igualmente la entrada y el resultado de EX sin volver válida una entrada previamente inválida; MEM/WB continúa avanzando conforme a la tabla nominal.

Durante HOLD ninguna evaluación combinacional produce una captura en EX/MEM, conforme a `DEC-ARCH-008`; en RUN o en el único ciclo efectivo de un STEP aceptado se aplica la transición nominal. Reset y LOAD conservan la prioridad global ya aprobada. Este acuerdo fija solo el avance físico nominal de EX/MEM, sin definir enables o ecuaciones RTL. El noveno acuerdo de `DEC-ARCH-004` exige `EX/MEM.next.valid=0` cuando la causante confirmada ocupa EX, preservando el avance de la entrada anterior de EX/MEM hacia MEM/WB; la integración RTL con eventos concurrentes sigue abierta en `DEC-ARCH-003`, sin reabrir la prioridad arquitectónica aprobada.

#### Acuerdo parcial aprobado — realización física de la actualización de `MEM/WB`

**Fecha:** 2026-09-24

En cada ciclo lógico efectivo habilitado de avance normal, `load-use stall` o redirect válido en EX **en los casos nominales**, MEM/WB captura la salida de MEM correspondiente a la entrada **previa** de EX/MEM. Este último puede estar capturando simultáneamente otra instrucción desde EX sin cambiar cuál se transfiere a MEM/WB. El dato `wb_value` será el único valor arquitectónico ya seleccionado en MEM **antes de la captura**, conforme al acuerdo décimo, no un dato reconstruido desde la nueva entrada de EX/MEM:

```text
MEM/WB.next.valid        = EX/MEM.valid
MEM/WB.next.pc           = EX/MEM.pc
MEM/WB.next.instruction  = EX/MEM.instruction
MEM/WB.next.rd           = EX/MEM.rd
MEM/WB.next.reg_write    = EX/MEM.reg_write
MEM/WB.next.wb_value     = wb_value seleccionado en MEM
```

Para un load válido que escribe `rd`, el `wb_value` capturado es el dato leído, ensamblado little-endian y extendido en MEM. Para las demás instrucciones válidas escritoras pertinentes es el resultado arquitectónico conservado en `EX/MEM.ex_result`, incluido el enlace de `jal`/`jalr`. WB y el forwarding desde MEM/WB usan ese mismo campo; no existe bypass combinacional `DMEM → EX`. Para stores, branches, `halt` e instrucciones que no escriben `rd`, el contenido residual de `wb_value` no habilita escritura ni forwarding.

Ante un `load-use stall` nominal, MEM/WB recibe la instrucción más antigua que **ya ocupaba EX/MEM**, mientras el load previo de ID/EX pasa a EX/MEM, ID/EX recibe una bubble e IF/ID conserva al consumidor. Ante un redirect válido resuelto en EX, MEM/WB recibe igualmente la instrucción que **ya ocupaba EX/MEM**, más antigua que la de control que redirige; esta última entra en EX/MEM mientras IF/ID e ID/EX invalidan el trabajo joven `wrong-path` y PC captura el target. La redirección no descarta el trabajo anterior ni exige un flush o retención específica de MEM/WB. En avance normal, MEM/WB también captura la entrada correspondiente de MEM.

Si `EX/MEM.valid=0` antes del flanco, entonces `MEM/WB.next.valid=0`: se **propaga** una entrada inválida o bubble existente, sin que eso constituya un flush particular de MEM/WB. Sus otros campos pueden conservar bits residuales, sin escritura arquitectónica o forwarding. Este comportamiento de avance solo se aplica en un ciclo CPU efectivo de RUN o STEP; durante HOLD MEM/WB permanece estable aunque cambien señales combinacionales, conforme a `DEC-ARCH-008`. Reset y LOAD conservan su prioridad global. No se fijan nombres, enables o ecuaciones RTL definitivas, ni la integración RTL con faults u otros eventos concurrentes, que debe preservar `DEC-ARCH-004`.

#### Acuerdo parcial aprobado — realización física del control nominal de hazards del pipeline

**Fecha:** 2026-09-24

Una lógica **combinacional** central, denominada conceptualmente `Pipeline Hazard Control`, coordinará en los casos nominales la retención, invalidación y selección de próximo PC ya aprobadas por separado. Recibirá como mínimo conceptual `load_use_stall`, producido por el detector en ID, y `redirect_valid`, decidido por una instrucción de control válida en EX. Determinará las acciones correspondientes sobre PC y su Next-PC MUX, IF/ID e ID/EX; EX/MEM y MEM/WB continúan avanzando conforme a los acuerdos de cada latch. El detector de `load-use` y la Forwarding Unit conservan sus funciones independientes: esta lógica no redefine la condición de detección ni las selecciones de operandos reenviados.

Para un **ciclo lógico efectivo** en los casos nominales cubiertos:

| Selección de control | PC y Next-PC MUX | IF/ID | ID/EX | EX/MEM | MEM/WB |
|---|---|---|---|---|---|
| `redirect_valid` | Habilitar PC y capturar `redirect_target` | Invalidar, `valid_next=0` | Invalidar, `valid_next=0` | Capturar la instrucción de control válida de EX | Capturar la entrada previa de EX/MEM |
| Sin redirect, `load_use_stall` aplicable | Inhibir escritura de PC; entrada del mux irrelevante | Retener íntegramente `valid`, `pc` e `instruction` | Bubble, `valid_next=0` | Capturar el load previo de ID/EX | Capturar la entrada previa de EX/MEM |
| Sin redirect ni stall aplicable | Habilitar PC y seleccionar `pc_plus_4` | Capturar IF | Capturar ID | Capturar EX | Capturar MEM |

La validez de cada entrada capturada en avance normal proviene de su etapa anterior: una entrada inválida no se reactiva por avanzar. En el redirect, EX/MEM y MEM/WB no se invalidan específicamente y el fetch del target no entra válido en IF/ID en el mismo flanco; en el stall nominal, PC e IF/ID se retienen mientras las instrucciones anteriores progresan. La bubble por espera y el flush por descarte comparten `valid_next=0` en ID/EX sin requerir una NOP física o limpieza de otros campos.

Para este **dominio nominal**, la selección conceptual es `redirect válido > load-use stall aplicable > avance normal`. Si un redirect de una instrucción más antigua coincide con una petición de retención debida **exclusivamente a trabajo joven `wrong-path` que se descarta**, esa petición no bloquea el target ni conserva válidas las entradas invalidadas, conforme a la prioridad local ya aprobada. El `load-use` clásico requiere un load en ID/EX, mientras un redirect válido exige allí una instrucción de control, por lo que **no existe su colisión directa** en la misma entrada. Esta jerarquía nominal no desplaza la prioridad arquitectónica por antigüedad de `DEC-ARCH-004` ni el stall necesario entre instrucciones anteriores a un fault en IF; los demás stalls e integración RTL con eventos concurrentes quedan abiertos. Un target desalineado de la propia instrucción de control no aplica redirect. Un branch no tomado no activa redirect ni flush y conserva el tratamiento de un stall independiente válido.

La lógica puede evaluar combinacionalmente sus entradas durante HOLD, pero no actualiza PC ni latches ni incrementa el contador hasta que `DEC-ARCH-008` autorice un ciclo CPU: RUN aplica la transición en sus ciclos efectivos y un STEP aceptado autoriza exactamente una. Reset y LOAD aceptado conservan la prioridad global. Se fija la existencia y función del bloque nominal, sin imponer puertos físicos adicionales ni ecuaciones finales de enables/invalidaciones/selección; el trigésimo cuarto acuerdo fija los nombres y códigos de `next_pc_sel` y `pc_write_enable`. Permanece abierta la integración completa con faults de `DEC-ARCH-004` y demás prioridades de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — realización física del valor de enlace de `jal` y `jalr`

**Fecha:** 2026-09-24

Para una instrucción válida `jal` o `jalr` en EX, el valor de enlace de 32 bits se calculará **en EX** mediante un `Link Adder` conceptual que suma cuatro a `ID/EX.pc[31:0]`, el PC propio de la instrucción. No se utilizará el PC global de IF ni el `pc_plus_4` del Next-PC MUX, que pueden corresponder a otra instrucción:

```text
ID/EX.pc[31:0]
        ↓
   Link Adder (+4)
        ↓
link_value[31:0]
        ↓
   Result MUX
        ↓
ex_result[31:0]
        ↓
     EX/MEM
```

El `Result MUX` selecciona para `jal`/`jalr` el resultado combinacional `link_value = ID/EX.pc + 4`, por lo que `ex_result = link_value` antes de que EX/MEM lo capture junto con la validez, la identidad y el destino de esa misma instrucción. `link_value` no es un campo físico adicional de ID/EX, EX/MEM ni MEM/WB. El redirect válido invalida las **nuevas** entradas jóvenes de IF/ID e ID/EX, pero no la captura de la instrucción de control válida en EX/MEM. Desde `EX/MEM.ex_result` el enlace está disponible para forwarding cuando el productor es válido, escribe `rd != x0` y coincide con una fuente realmente usada; una escritura a `x0` no cancela la redirección, aunque impide forwarding y escritura de registro.

En MEM, el `WB Value MUX` seleccionará `EX/MEM.ex_result` para estas instrucciones no load, conforme al punto de selección arquitectónico ya aprobado:

```text
EX/MEM.ex_result
        ↓
   WB Value MUX
        ↓
wb_value[31:0]
        ↓
     MEM/WB
        ↓
        WB
```

MEM/WB captura **ese mismo valor único** antes de suministrarlo a WB y al forwarding posterior, sin volver a calcular el enlace ni transportar un `link_value` registrado separado. La suma ocurre en EX y el enlace puede reenviarse desde EX/MEM, pero la **escritura arquitectónica del banco ocurre únicamente en WB** durante un ciclo efectivo válido conforme a `DEC-ARCH-002` y `DEC-ARCH-008`. Durante HOLD ninguna evaluación combinacional del sumador o de los muxes produce una captura o escritura. El tratamiento de faults y de instrucciones que dejen de ser válidas sigue sujeto a `DEC-ARCH-004`.

Este acuerdo fija la etapa del cálculo y el camino físico general del enlace; el vigésimo sexto acuerdo fija los otros orígenes y la selección semántica del `Result MUX`. El nombre, ancho y codificación funcional de su selector `result_sel[1:0]` se fijan después en el trigésimo cuarto acuerdo; las ecuaciones finales del control path y la integración RTL con faults y eventos concurrentes continúan abiertos.

#### Acuerdo parcial aprobado — realización física de la selección de `ex_result`

**Fecha:** 2026-09-24

EX producirá un único `ex_result[31:0]` mediante un `Result MUX` **combinacional** con tres entradas de datos de 32 bits:

```text
alu_result[31:0] ─────┐
immediate[31:0] ──────┼──► Result MUX ──► ex_result[31:0]
link_value[31:0] ─────┘
```

| Instrucción válida en EX | Entrada seleccionada | Significado de `ex_result` |
|---|---|---|
| R-type; I-type aritmética / shifts | `alu_result` | Resultado arquitectónico de la operación |
| Loads; stores | `alu_result` | Dirección efectiva calculada en EX |
| `lui` | `immediate` | Valor inmediato ya generado en su representación arquitectónica |
| `jal`; `jalr` | `link_value` | `instruction_PC + 4`, calculado en EX desde `ID/EX.pc` conforme al acuerdo anterior |

`EX/MEM.ex_result` captura el único valor seleccionado para la instrucción que ocupaba ID/EX antes del flanco de un ciclo efectivo. Para R-type, I-type aritmética/shifts, `lui` y `jal`/`jalr` válidos que escriben `rd != x0`, este campo contiene el resultado arquitectónico disponible para forwarding desde EX/MEM, sujeto a coincidencia con una fuente realmente usada y a la política del productor más reciente. Para un load, contiene **su dirección efectiva, no el dato cargado**: aunque escriba `rd`, no es fuente de forwarding desde EX/MEM; el dato arquitectónico estará disponible desde `MEM/WB.wb_value` tras su captura. Para un store, la dirección se utiliza en MEM pero no es un valor de registro reenviable. No se agrega bypass `DMEM → EX`.

Para `beq`, `bne`, `halt` y cualquier instrucción sin escritura arquitectónica de `rd`, los bits de `ex_result` carecen de efecto para WB y forwarding. También una entrada inválida, `reg_write=0` o `rd=x0` carecen de elegibilidad de escritura y reenvío, aunque el mux presente un valor combinacional residual. La selección de EX no altera los efectos de control de un salto válido ni el uso de la dirección de un store válido. Los campos `alu_result`, `immediate` y `link_value` no se registran por separado en EX/MEM: el inmediato procede de ID/EX y el enlace del `Link Adder` aprobado; en MEM el `WB Value MUX` sigue seleccionando `EX/MEM.ex_result` para escritores no load y el dato cargado para loads, con escritura arquitectónica únicamente en WB. Durante HOLD el mux puede evaluarse, pero no captura latches ni produce escrituras; RUN y STEP solo aplican transiciones en ciclos efectivos conforme a `DEC-ARCH-008`.

Se fijan la existencia del `Result MUX`, sus tres entradas de datos y la semántica de `ex_result` por clase, **sin fijar entonces nombre RTL, ancho ni codificación de la señal selectora** (fijados después como `result_sel[1:0]` en el trigésimo cuarto acuerdo), ni ecuaciones concretas del control de ID/EX ni la integración RTL frente a faults y otros eventos pendiente de `DEC-ARCH-003`, sujeta a `DEC-ARCH-004` aprobada.

#### Acuerdo parcial aprobado — realización física de la generación de redirect en EX

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

EX generará combinacionalmente dos resultados conceptuales: `redirect_valid`, que indica que la instrucción de control **válida** en ID/EX requiere modificar el flujo secuencial, y `redirect_target[31:0]`, que contiene el destino arquitectónico correspondiente. El destino se obtiene por dos caminos de 32 bits:

```text
ID/EX.pc[31:0]                 rs1_effective[31:0]
       ↓                                ↓
Target Adder (+ immediate)     JALR Adder (+ immediate)
       ↓                                ↓
pc_relative_target[31:0]         jalr_sum[31:0]
                                        ↓
                                forzar bit 0 a cero
                                        ↓
                                jalr_target[31:0]

pc_relative_target ──┐
                     ├──► Target MUX ──► redirect_target[31:0]
jalr_target ─────────┘
```

Para `beq`, `bne` y `jal`, el `Target MUX` selecciona `pc_relative_target = ID/EX.pc + immediate`, con el inmediato B o J correspondiente a la instrucción; no usa el PC global de IF. Para `jalr` selecciona `jalr_target = (rs1_effective + immediate) & 0xFFFFFFFE`, con el inmediato I y el operando efectivo más reciente, que puede provenir de forwarding. El `Target MUX` forma el destino **dentro de EX**; el `Next-PC MUX` ya aprobado selecciona posteriormente entre ese destino y `pc_plus_4` desde el PC global para la entrada del registro PC. El `Link Adder` de `jal`/`jalr` calcula por separado el enlace `ID/EX.pc + 4` para `ex_result`: enlace, destino relativo y PC secuencial no son intercambiables.

Para branches, la ALU de EX realizará la resta de 32 bits `rs1_effective - rs2_effective` y su indicador de cero expresará `equal = ALU.zero`. La resta compara los **operandos efectivos** seleccionados tras forwarding: `beq` toma la rama cuando `ALU.zero = 1` y `bne` cuando `ALU.zero = 0`, sin depender de la interpretación signed/unsigned. La condición de redirección es conceptualmente:

```text
redirect_valid = ID/EX.valid AND (
    (beq AND equal) OR (bne AND !equal) OR jal OR jalr
)
```

`beq`, `bne`, `jal` y `jalr` denotan aquí la clase de instrucción reconocida en EX, **sin fijar subcampos, señales RTL ni codificación** de `ID/EX.control`. `jal` y `jalr` redirigen siempre que su instrucción sea válida; una entrada inválida no puede hacerlo por sus bits residuales. Un `beq` o `bne` no tomado no activa `redirect_valid` ni invalida el camino secuencial por esa causa, aunque los sumadores y muxes puedan presentar resultados combinacionales.

`redirect_valid` llega conceptualmente al `Pipeline Hazard Control`, y `redirect_target` a la entrada de target del `Next-PC MUX`. En los casos nominales ya aprobados, un redirect válido aplicado en **un ciclo CPU efectivo** carga PC con el target e invalida las nuevas entradas jóvenes de IF/ID e ID/EX, mientras la instrucción de control en EX avanza a EX/MEM y las anteriores progresan. Durante HOLD, ambos resultados pueden evaluarse pero no actualizan PC ni latches; RUN y un STEP aceptado aplican transiciones únicamente en los ciclos autorizados por `DEC-ARCH-008`. `DEC-ARCH-004` prohíbe aplicar redirect a target desalineado y, si se confirma su fault en EX, retiene PC e invalida la nueva entrada de EX/MEM sin detener las anteriores. La selección nominal y la prioridad local frente a trabajo joven `wrong-path` se subordinan a la antigüedad: redirect o `halt` anterior descarta un candidato joven, fault anterior descarta redirect o `halt` joven y un fault propio suprime los efectos de la instrucción; el `load-use` se aplica solo entre supervivientes. El vigésimo octavo acuerdo concreta además que un `halt` joven descartado por ese redirect en EX nunca se confirma: la mera detección en ID no inicia drenado ni retiene PC. La integración RTL con otros eventos queda abierta.

La resta con `ALU.zero` fija ahora una **elección física** para la comparación de branches, compatible con la semántica de igualdad de `DEC-ARCH-002`, que no imponía su realización. Se fijan los caminos de cálculo del destino y la generación conceptual del redirect en EX; el trigésimo tercer acuerdo fija después su representación **semántica** como `flow_op=BEQ/BNE/JAL/JALR`; el trigésimo cuarto acuerdo fija el código de `flow_op` y de `target_sel`; permanecen abiertos el empaquetado RTL y las ecuaciones de los selectores, las ecuaciones RTL finales y las coincidencias no cubiertas.

#### Acuerdo parcial aprobado — reconocimiento de `halt` y comienzo del drenado

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

La instrucción custom `halt` se detectará **inicialmente en ID** por comparación de la word completa en IF/ID, y solo como **candidata**:

```text
halt_candidate = IF/ID.valid && decode_legal
                 && (IF/ID.instruction == 32'h0000000B)
```

El trigésimo séptimo acuerdo explicita `decode_legal` en esta ecuación: como la word exacta de `halt` es legal, conserva la misma detección funcional. Esta detección no inicia el drenado, no retiene PC ni cambia por sí misma el estado global. Un redirect de una instrucción anterior en EX descarta el `halt` joven de ID: no se confirma, no se detiene la admisión desde el destino y no se llega a `FINISHED` por ese candidato. Los bits residuales de IF/ID inválido tampoco generan un candidato efectivo.

El `halt` se **confirma arquitectónicamente en EX** únicamente si alcanzó `ID/EX` como instrucción válida y continúa perteneciendo al flujo correcto en un **ciclo CPU efectivo autorizado**. Conceptualmente, `halt_confirmed = ID/EX.valid && ID/EX representa exactamente halt && instrucción aún arquitectónicamente válida`. Se define la condición semántica, no un nombre de señal obligatorio: el trigésimo tercer acuerdo lo representa semánticamente mediante `flow_op=HALT`, el trigésimo cuarto acuerdo fija luego `flow_op[2:0]` y `HALT=101`, mientras su integración RTL sigue pendiente. Durante HOLD puede evaluarse lógica combinacional sin confirmar el evento ni modificar el estado.

Al confirmar `halt` se fija una **frontera en orden de programa**: las instrucciones anteriores pueden completar sus efectos; el propio `halt` se consume como evento de control **sin ingresar válido a EX/MEM**, y las posteriores se descartan sin escribir registros o DMEM, redirigir, confirmar fault ni producir otros efectos funcionales. Para el estado previo al flanco `MEM/WB:I1, EX/MEM:I2, ID/EX:halt, IF/ID:I4, IF:I5`, en ese ciclo efectivo `I1` puede comprometer WB, `I2` puede avanzar a MEM/WB y se fijan `EX/MEM.next.valid=0`, `ID/EX.next.valid=0` e `IF/ID.next.valid=0` para la causante y el trabajo joven. No se vacían indiscriminadamente los latches que contienen anteriores; sus efectos siguen exactamente una vez durante el drenado.

El **PC conserva bit a bit su valor registrado actual** desde la confirmación y durante el drenado, aunque corresponda a una posición secuencial más joven presentada en IF; no se recarga el PC de `halt`, no se impone `PC+4` ni un destino especial. IF deja de admitir instrucciones nuevas. Este comportamiento requiere retención de PC, **sin añadir una entrada exclusiva para `halt` al Next-PC MUX** aprobado.

La condición funcional **`HALT_DRAIN`** no obliga a una FSM o codificación RTL particular. Durante ella, IF/ID e ID/EX carecen de trabajo joven válido; EX/MEM y MEM/WB solo pueden contener anteriores supervivientes. El drenado progresa exclusivamente en ciclos CPU efectivos: bajo RUN continúa automáticamente, bajo paso a paso requiere **un STEP nuevo por ciclo**, y durante HOLD no progresa ni repite stores o writebacks. Reset y LOAD conservan las prioridades globales de `DEC-ARCH-008`.

La finalización normal **`FINISHED`** requiere `halt` previamente confirmado y los cuatro latches lógicamente vacíos: `IF/ID.valid = ID/EX.valid = EX/MEM.valid = MEM/WB.valid = 0`. La candidatura en ID y la confirmación en EX no son por sí mismas FINISHED; si no quedan anteriores, no se exige un ciclo artificial de drenado. `FINISHED` continúa separado de `FAULT` conforme a `DEC-ARCH-004` y `DEC-SYS-001`. La integración unificada de eventos concurrentes sigue la antigüedad ya aprobada: un fault anterior descarta un `halt` joven, y un `halt` válido anterior descarta candidatos de fault posteriores.

Este acuerdo fija la **etapa candidata ID, la confirmación EX y la frontera microarquitectónica de `halt`**. El trigésimo cuarto acuerdo fija luego `flow_op[2:0]=101` para HALT y el trigésimo sexto `terminal_kind[1:0]`/`drain_auto` para la frontera confirmada y su drenado. Siguen pendientes la integración RTL, las ecuaciones de arbitraje físico, enables e invalidaciones, y la codificación del control global de ejecución; no se fija una señal `halt_confirmed` ni una FSM obligatoria.

#### Acuerdo parcial aprobado — representación y transporte físico de candidatos de fault

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

Se conservan **solo los cuatro registros de pipeline** IF/ID, ID/EX, EX/MEM y MEM/WB. Los candidatos de Instruction Fetch se detectan en IF, las instrucciones ilegales en ID y los accesos load/store o targets desalineados en EX conforme a `DEC-ARCH-004`. La única ampliación registrada de pipeline se hace en **IF/ID**, revisando explícitamente su decimocuarto acuerdo de tres campos a cinco:

```text
IF/ID
├── valid
├── pc[31:0]
├── instruction[31:0]
├── fetch_fault_valid
└── fetch_fault_cause[2:0]
```

`valid` conserva su significado: identifica una **instrucción obtenida y arquitectónicamente activa**, no un candidato de fault. En un fetch normal se capturan `valid=1`, `pc=PC del fetch`, la word obtenida y `fetch_fault_valid=0`. En un fetch con causa candidata seleccionada por la prioridad ya aprobada se capturan **`valid=0`, `pc=PC causante`, `fetch_fault_valid=1` y `fetch_fault_cause=causa detectada`**; los bits de `instruction` carecen de significado arquitectónico. Una entrada `valid=0, fetch_fault_valid=0` es inactiva y no puede confirmar fault por residuos. El trigésimo quinto acuerdo fija después el ancho/codificación de `fetch_fault_cause[2:0]`; no se agrega campo de PC distinto de `IF/ID.pc`.

En la **ruta normal**, el candidato de IF capturado en IF/ID se resuelve conceptualmente en **ID** durante un ciclo efectivo: si un redirect, fault o `halt` más antiguo ha invalidado el fetch, el flag se descarta sin confirmar; si `fetch_fault_valid=1` y el fetch sigue en el camino correcto, se confirma el fault según la antigüedad de `DEC-ARCH-004`. No se transporta la candidatura a ID/EX ni se interpreta `instruction` como instrucción ilegal; `fault_pc=IF/ID.pc` y `fault_cause` procede del candidato seleccionado. Un flush o invalidación de trabajo joven **debe poner también `fetch_fault_valid=0`**, aun si `IF/ID.valid` ya era cero; durante HOLD se retienen los cinco campos y no se confirma nada por una evaluación combinacional. Reset y preparación de nueva sesión invalidan las candidaturas previas conforme a `DEC-ARCH-008`.

**Excepción aprobada para `load-use` entre anteriores supervivientes:** si IF detecta un fetch fault mientras ID/EX contiene el load anterior e IF/ID debe **retener válida** a su consumidora anterior, no se sobrescribe el latch con el candidato. Si ese fetch permanece en el camino correcto y no existe una frontera anterior prevaleciente, el fault se **confirma directamente en IF** en ese ciclo CPU efectivo, conforme al décimo acuerdo de `DEC-ARCH-004`: IF/ID conserva íntegramente a la consumidora, ID/EX recibe bubble, el load y las demás anteriores avanzan, PC se retiene y no se admite el fetch causante. `fault_pc` se toma del **PC del fetch en IF**, y `fault_cause` de la causa detectada allí; el candidato no se captura en IF/ID ni se requiere un registro adicional. Esta excepción no convierte toda detección IF en confirmación inmediata; un fetch `wrong-path` descartado nunca confirma error.

La instrucción ilegal solo puede detectarse sobre una **entrada normal `IF/ID.valid=1`** por decodificación de la word completa en ID. Si prevalece una instrucción anterior se descarta; si se confirma, **no entra válida a ID/EX**, y `fault_pc=IF/ID.pc`, sin campo de candidato adicional. Los faults de load, store o target se detectan y resuelven directamente en EX; si se confirman, la causante **no entra válida a EX/MEM**, y `fault_pc=ID/EX.pc`. No se añaden campos de fault a ID/EX, EX/MEM ni MEM/WB. Se conserva la prioridad `misalignment > access fault` dentro de un mismo acceso y la prioridad por **antigüedad** entre instrucciones, sin confundir una coincidencia física con confirmación arquitectónica.

En **cualquiera de las rutas de confirmación**, se capturan `fault_cause` y `fault_pc` como **estado global persistente fuera de los cuatro latches**, y la condición de fault se activa; causa y PC permanecen estables durante `FAULT_DRAIN` y `FAULT` conforme a `DEC-ARCH-004`. Ningún candidato descartado, incluido el de IF/ID con `valid=0`, modifica ese estado. La ruta excepcional de IF utiliza el PC de IF y la ruta normal transportada el PC de IF/ID; para ilegal en ID se usa IF/ID.pc y para EX se usa ID/EX.pc, nunca la dirección de datos ni el target problemático.

Este acuerdo fija la **representación mínima y transporte de candidatos de fault**, con una revisión explícita de los acuerdos decimocuarto y vigésimo relativos a IF/ID. El trigésimo acuerdo fija después el orden semántico de resolución EX→ID→IF excepcional y los stalls de supervivientes; el trigésimo quinto fija la codificación común de causa de tres bits. El cuadragésimo primer acuerdo fija después el arbitraje combinacional de las fronteras cubiertas; las coincidencias no cubiertas, las ecuaciones finales de enable/flush y la representación externa Debug siguen pendientes, sin cambiar el contrato arquitectónico de `DEC-ARCH-004`.

#### Acuerdo parcial aprobado — prioridad unificada de eventos dentro de un ciclo efectivo

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

El arbitraje conjunto de fault, `halt`, redirect y stall se regirá por **antigüedad de programa**, no por una prioridad universal de tipos como `fault > halt > redirect > stall`. Entre eventos de **instrucciones distintas**, prevalece la más antigua que siga válida y en el camino correcto: en este pipeline in-order, **EX > ID > IF**. Dentro de **una misma instrucción**, un fault propio confirmado suprime sus efectos normales, incluido redirect y enlace de un `jal`/`jalr` con target desalineado. Solo después de determinar la frontera y las instrucciones supervivientes se aplican los stalls necesarios entre estas últimas, conforme a `DEC-ARCH-004`.

En cada ciclo CPU efectivo autorizado, el orden conceptual para **trabajo todavía no cubierto por una frontera activa** es:

```text
1. EX: si la instrucción válida confirma fault propio, frontera FAULT
       (no redirect ni enlace; causante no entra válida a EX/MEM).
       En otro caso, si confirma halt, frontera HALT
       (halt se consume en EX; no entra válido a EX/MEM).
       En otro caso, si produce redirect aplicable, frontera REDIRECT
       (PC toma redirect_target; trabajo secuencial joven se descarta).

2. Solo si EX no establece frontera, ID: confirmar illegal-instruction
   sobre IF/ID.valid=1, o fetch_fault_valid=1 sobre IF/ID.valid=0,
   siempre que el candidato siga en el camino correcto. Si confirma,
   frontera FAULT; la causante no avanza como instrucción válida.

3. Solo si EX e ID no establecen frontera, IF: conservar la excepción
   aprobada de fetch fault cuando un load-use entre anteriores obliga
   a retener al consumidor válido en IF/ID. Si el fetch es elegible,
   confirmar FAULT en IF sin capturar al candidato sobre el consumidor.
   En los demás casos IF solo detecta y, si corresponde, transporta
   al candidato hacia IF/ID para resolverlo en ID.

4. Una vez fijada la frontera y descartado el trabajo más joven,
   aplicar únicamente el load-use stall que aún necesiten
   productor y consumidor anteriores supervivientes; si no hay
   frontera ni stall aplicable, efectuar el avance nominal.
```

En EX, el fault propio precede al efecto normal **de esa misma instrucción**: `jal`/`jalr` con destino desalineado no redirige ni escribe enlace; el propio fault tampoco avanza válido a EX/MEM. Un `halt` EX confirmado sin fault propio se consume allí, descarta ID/IF jóvenes y deja drenar a sus anteriores hasta `FINISHED`. Un redirect EX aplicable, en cambio, **sí deja avanzar válida a la instrucción de control a EX/MEM** y descarta ID/IF secuenciales `wrong-path` y sus candidatos de fault, aunque `IF/ID.valid=0` y `fetch_fault_valid=1`. Solo sin frontera EX puede confirmarse un fault de ID: una instrucción ilegal válida o el candidato de fetch conservado en IF/ID; sus anteriores en ID/EX, EX/MEM y MEM/WB continúan y el fetch joven de IF se descarta. Por ejemplo, con I1 en MEM/WB, I2 en EX/MEM, I3 en ID/EX, I4 causante en IF/ID e I5 en IF, I1–I3 sobreviven y **I4 e I5 no producen efectos**.

La **excepción de IF** se evalúa **después de descartar fronteras EX e ID y antes de aplicar el stall**: se comprueba conceptualmente que un load y su consumidora anteriores aún precisan `load-use`, mientras IF presenta un fetch fault elegible. Se confirma en IF sin sobrescribir IF/ID, se retiene allí al consumidor con sus cinco campos, ID/EX recibe bubble y el load avanza; `fault_pc` proviene del PC de IF. Un redirect o fault EX anterior, o un fault ID anterior, descarta en cambio el candidato IF. La ruta **ordinaria** continúa transportando el fetch candidato por IF/ID para resolverlo en ID, sin confirmación inmediata general en IF. Si una frontera descarta la consumidora, su dependencia ya no justifica el stall; si load y consumidora sobreviven a la frontera, su stall se conserva. Sin frontera, se aplica el `load-use` nominal o el avance normal; un redirect EX prevalece localmente sobre un stall atribuible solo a trabajo joven descartado, conforme al acuerdo ya aprobado.

Una frontera de fault o `halt` **previamente confirmada** impide la admisión de trabajo nuevo y la confirmación de eventos de trabajo joven descartado; las instrucciones anteriores supervivientes continúan drenando con los hazards que precisen. No se introducen ciclos arquitectónicos ocultos ni una jerarquía fija por tipo de evento: reset y LOAD aceptado/preparación dominan los ciclos CPU, RUN/STEP autorizan las transiciones y HOLD no confirma nuevos eventos aunque la lógica combinacional se evalúe, conforme a `DEC-ARCH-008`. El nombre de la condición de drenado no impone una FSM RTL.

Este trigésimo acuerdo fija la **prioridad semántica unificada** sin modificar los cuatro latches ni los mecanismos nominales de bubble, flush, forwarding y retención. Los códigos funcionales del control de ID/EX se fijan en el trigésimo cuarto acuerdo. El trigésimo sexto acuerdo introdujo la clase terminal y el modo de drenado, sustituidos después por la FSM del cuadragésimo cuarto acuerdo. El cuadragésimo primer acuerdo fija después las ecuaciones RTL de arbitraje combinacional y el cuadragésimo segundo los enables/valores `next` de PC y latches; siguen abiertas las coincidencias no cubiertas, preservando `DEC-ARCH-004` y los acuerdos vigésimo octavo y vigésimo noveno de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — control completo del PC y los cuatro registros de pipeline

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

Se fijan las **transiciones semánticas en cada ciclo CPU efectivo** de PC, IF/ID, ID/EX, EX/MEM y MEM/WB para las fronteras y hazards aprobados. Cada captura y efecto arquitectónico se decide con las entradas **previas al flanco**; «capturar EX» alimenta la entrada nueva de EX/MEM desde ID/EX previo, y «capturar MEM» alimenta MEM/WB desde EX/MEM previo. La invalidación de una entrada nueva nunca borra retrospectivamente una instrucción anterior que ya ocupaba otra etapa. El trigésimo acuerdo selecciona la frontera por antigüedad EX→ID→IF excepcional antes de aplicar un stall necesario entre supervivientes; esta tabla materializa las acciones resultantes, sin prioridad universal por tipo de evento.

| Acción seleccionada | PC | IF/ID.next | ID/EX.next | EX/MEM.next | MEM/WB.next |
|---|---|---|---|---|---|
| Avance normal | Capturar `PC + 4` | Capturar IF | Capturar ID | Capturar EX | Capturar MEM |
| `load-use` entre supervivientes | Retener | Retener íntegramente al consumidor | Inválido / bubble | Capturar load anterior de EX | Capturar MEM |
| Redirect válido en EX | Capturar `redirect_target` | Inválido | Inválido | Capturar instrucción de control válida de EX | Capturar MEM |
| `halt` confirmado en EX | Retener | Inválido | Inválido | Inválido | Capturar MEM |
| Fault propio confirmado en EX | Retener | Inválido | Inválido | Inválido | Capturar MEM |
| Fault confirmado en ID | Retener | Inválido | Inválido | Capturar instrucción anterior de EX | Capturar MEM |
| **Fault excepcional confirmado en IF** con `load-use` entre anteriores | Retener | **Retener los cinco campos del consumidor válido** | Inválido / bubble | Capturar load anterior de EX | Capturar MEM |
| Drenado activo de `halt` o fault | Retener | Retener al anterior si hay stall; invalidar al dejarlo avanzar o si ya no lo contiene | Capturar anterior de ID si puede avanzar; bubble/inválido si hay stall o no existe | Capturar anterior de EX, o inválido si no existe | Capturar MEM |

En avance normal, «capturar IF» incluye un fetch válido (`valid=1, fetch_fault_valid=0`) o, si IF detectó un candidato de fault **no confirmado**, su captura en IF/ID con `valid=0, fetch_fault_valid=1`, PC y causa del fetch para resolverlo posteriormente en ID. Un candidato no confirmado **no** selecciona una fila de fault. El `load-use` nominal retiene PC e IF/ID y crea solo la bubble de ID/EX: el load y las anteriores siguen avanzando. Un redirect EX válido invalida trabajo secuencial joven pero **preserva** la instrucción de control en EX/MEM; por el contrario, el propio `halt` o fault de EX **no** entra válido a EX/MEM. Si se confirma fault en ID, su causante no entra válida a ID/EX, pero la instrucción anterior en EX sí entra a EX/MEM.

En la **excepción de IF**, el fetch causante de fault no ingresa al pipeline; `fault_pc` procede del PC del fetch en IF. El consumidor en IF/ID es **anterior** a esa frontera y debe permanecer con sus cinco campos durante el ciclo de confirmación, mientras ID/EX recibe bubble y el load de EX avanza a EX/MEM. En los ciclos efectivos siguientes de `FAULT_DRAIN`, sin nuevos fetches admitidos, el consumidor todavía válido en IF/ID puede avanzar a ID/EX, luego EX/MEM y MEM/WB, con forwarding y stalls necesarios entre anteriores; IF/ID se invalida **al dejarlo avanzar**, no antes. El PC permanece retenido durante este progreso. La fila de drenado no es un flush incondicional de todas las etapas: si todavía hay trabajo anterior válido en IF/ID o ID/EX, se lo conserva o transfiere según corresponda; si no lo hay, se inyectan entradas inválidas. En `HALT_DRAIN` iniciado por `halt` EX, y en faults EX o ID una vez aplicada su fila de confirmación, ya no quedan anteriores en IF/ID; para esos casos la fila de drenado se simplifica al desplazamiento de anteriores en las etapas restantes y la inyección de invalidez.

**Invalidar IF/ID** por descarte o por agotamiento de trabajo superviviente significa como mínimo `IF/ID.next.valid=0` **y** `IF/ID.next.fetch_fault_valid=0`: incluso un candidato joven con `valid=0` debe quedar desactivado. `pc`, `instruction` y `fetch_fault_cause` pueden conservar bits residuales sin efecto. La retención del consumidor superviviente en la excepción IF **no** es una invalidación. Los demás latches nuevos inválidos pueden asimismo conservar sus bits residuales, sin reconocer efectos de entradas inválidas.

Al confirmarse `halt` o fault, un writeback de la entrada **previa** de MEM/WB y un store anterior desde la entrada **previa** de EX/MEM pueden completarse normalmente, una sola vez, si cumplen validez y ciclo efectivo; `MEM/WB.next` sigue capturando MEM previa. Se descarta la causante cuando corresponde y el trabajo posterior, nunca las anteriores. El drenado progresa en RUN o mediante un STEP nuevo por ciclo, y llega a `FINISHED` o `FAULT` cuando completaron las anteriores y **los cuatro `valid` quedaron en cero**, sin exigir un ciclo de drenado vacío adicional. Si ya estaban vacíos tras la confirmación, se alcanza directamente el estado final correspondiente. Durante HOLD los cinco registros, incluidos PC, retienen sus valores y no se confirma ningún evento por clocks físicos; reset global y LOAD aceptado/preparación conservan su precedencia sobre ciclos CPU conforme a `DEC-ARCH-008`.

Este trigésimo primer acuerdo consolida las transiciones nominales y las fronteras precisas de `DEC-ARCH-004`, incluida su excepción de IF, sin añadir latches, señales, codificaciones de estados, enables ni ecuaciones RTL obligatorias. La codificación `flow_op[2:0]=101` se fija en el trigésimo cuarto acuerdo; la implementación física opcional del conjunto de control continúa pendiente y el cuadragésimo primer acuerdo de `DEC-ARCH-003` fija después el arbitraje combinacional de acciones y el cuadragésimo segundo fija los enables/invalidaciones y capturas de PC y latches para ellas.

#### Acuerdo parcial aprobado — ecuaciones funcionales definitivas de hazards de datos

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

Se fijan las ecuaciones conceptuales del **Load-Use Hazard Detector** y de la **Forwarding Unit** existentes. La primera detecta una dependencia cuyo dato todavía no está disponible; la segunda elige por fuente la versión pendiente más reciente ya disponible. La ecuación del detector es:

```text
load_use_stall =
    ID/EX.valid
    && ID/EX.is_load
    && (ID/EX.rd != x0)
    && IF/ID.valid
    && (
         (IF/ID.uses_rs1 && (IF/ID.rs1 == ID/EX.rd))
         ||
         (IF/ID.uses_rs2 && (IF/ID.rs2 == ID/EX.rd))
       )
```

`IF/ID.rs1`, `IF/ID.rs2` y los indicadores de uso se **derivan combinacionalmente** de `IF/ID.instruction` según la clasificación 3A: no se registran campos nuevos. `ID/EX.is_load` es información derivable del control ya transportado por la instrucción en ID/EX; su codificación se fija después como `mem_op[3:0]` en el trigésimo cuarto acuerdo, sin subcampo `is_load` adicional. La igualdad sobre una fuente no usada, `rd=x0` o cualquier entrada inválida no habilita el stall. La detección combinacional no congela por sí sola el pipeline: tras seleccionar la frontera por antigüedad EX→ID→IF excepcional, el stall se **aplica** únicamente si load y consumidora sobreviven, conforme a los acuerdos trigésimo y trigésimo primero.

Para cada fuente **independiente** `rsN`, `N ∈ {1,2}`, se fijan las coincidencias de productor:

```text
exmem_match_rsN =
    ID/EX.valid && ID/EX.uses_rsN
    && EX/MEM.valid && EX/MEM.reg_write
    && (EX/MEM.rd != x0)
    && (EX/MEM.rd == ID/EX.rsN)

memwb_match_rsN =
    ID/EX.valid && ID/EX.uses_rsN
    && MEM/WB.valid && MEM/WB.reg_write
    && (MEM/WB.rd != x0)
    && (MEM/WB.rd == ID/EX.rsN)
```

`ID/EX.uses_rs1` y `ID/EX.uses_rs2` se derivan de la instrucción/control ya registrados en ID/EX, **sin agregar campos físicos**. La coincidencia de EX/MEM significa que se halló un productor más reciente de esa fuente que cualquier productor coincidente de MEM/WB, pero no implica disponibilidad del dato. `exmem_result_available` denota que `EX/MEM.ex_result` ya contiene el valor arquitectónico que se escribiría en `rd`: ocurre para resultados R-type, I-type aritmética/shifts, `lui` y enlace de `jal`/`jalr`. En un load, `EX/MEM.ex_result` contiene **la dirección efectiva**, nunca el valor cargado; un load coincidente no tiene resultado reenviable desde EX/MEM. La disponibilidad se deriva del control existente en EX/MEM, sin campo `result_available` adicional; el trigésimo octavo acuerdo fija después `exmem_result_available = !is_load(EX/MEM.mem_op)`. MEM/WB entrega siempre su único `wb_value` arquitectónico ya seleccionado en MEM, incluido el de loads, sin reconstruir el origen.

Las habilitaciones de forwarding son, por cada fuente:

```text
forward_exmem_rsN = exmem_match_rsN && exmem_result_available
forward_memwb_rsN = !exmem_match_rsN && memwb_match_rsN
```

La negación de la segunda expresión se aplica a **`exmem_match_rsN`**, no a `forward_exmem_rsN`. Por ello, si EX/MEM es el productor coincidente más reciente pero todavía no dispone del dato, MEM/WB no puede sustituirlo por la versión anterior. Cada Forward MUX de tres entradas realiza conceptualmente, por separado para `rs1` y `rs2`:

```text
si forward_exmem_rsN:  rsN_effective ← EX/MEM.ex_result
si no, si forward_memwb_rsN:
                        rsN_effective ← MEM/WB.wb_value
si no:                  rsN_effective ← ID/EX.rsN_value
```

La última rama representa el **valor base utilizable solo cuando no existe un productor coincidente más reciente pendiente**. Si `exmem_match_rsN=1` y `exmem_result_available=0`, ambas habilitaciones de forwarding son cero y el mux físico podría mostrar la rama base; **ese valor combinacional es irrelevante y no podrá ser consumido por una instrucción válida en EX**. El detector `load-use` habrá retenido previamente a la consumidora de la dependencia inmediata hasta disponer del dato; el control de supervivencia conserva los stalls necesarios durante el drenado. No se selecciona la dirección efectiva del load, MEM/WB obsoleto ni el valor base obsoleto como operando arquitectónico. No se agrega cuarta entrada de mux, bypass `DMEM → EX` ni nuevo tipo de forwarding o stall.

El bypass interno **WB→ID** de `DEC-ARCH-007` actúa antes: `Register File → bypass WB→ID → rs1_value/rs2_value → ID/EX.rsN_value → Forward MUX → rsN_effective`. La Forwarding Unit no necesita conocer de dónde provenía el valor base posbypass; un productor pendiente más reciente en EX/MEM o MEM/WB prevalece por versión cuando su dato esté disponible. Productores inválidos, sin escritura o con `rd=x0`, y consumidor inválido o fuente no usada no generan forwarding funcional. Las salidas combinacionales pueden evaluarse en HOLD, pero no originan por sí mismas avance ni efectos arquitectónicos.

Este trigésimo segundo acuerdo cierra **las ecuaciones funcionales del detector y de la Forwarding Unit** sin cambiar los cuatro latches ni agregar bloques. El trigésimo cuarto acuerdo fija después los nombres, anchos y códigos funcionales de las categorías de control y selectores principales; el trigésimo octavo fija `is_load` y la disponibilidad de EX/MEM. Permanecen pendientes las ecuaciones RTL de enables, flush y arbitraje concurrente no cubierto.

#### Acuerdo parcial aprobado — composición semántica del control transportado por el pipeline

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-24

Se revisa explícitamente el significado del elemento **`ID/EX.control`** del decimotercer acuerdo: es un **placeholder para la información de control asociada a la instrucción**, no la obligación de registrar un único número, vector o bus empaquetado. La implementación puede representarla mediante señales separadas, una estructura, un bundle o una forma equivalente que conserve las siguientes **seis categorías semánticas generadas en ID** para la instrucción decodificada:

| Categoría conceptual | Significado y alternativas semánticas |
|---|---|
| `alu_op` | Operación de ALU: `ADD`, `SUB`, `SLL`, `SRL`, `SRA`, `AND`, `OR`, `XOR`, `SLT`, `SLTU`. Loads/stores emplean ADD para dirección efectiva; `beq`/`bne` emplean SUB y leen `ALU.zero` para igualdad. |
| `alu_src` | Segundo operando de ALU: `rs2_effective` o `immediate`. Selecciona registro o inmediato para operaciones ALU y cálculo de dirección cuando corresponda. |
| `result_sel` | Valor de `EX/MEM.ex_result` a través del **Result MUX 3:1** aprobado: `ALU` → `alu_result`, `IMMEDIATE` → `immediate`, `LINK` → `link_value`. Loads/stores llevan la dirección ALU; `lui`, el inmediato; `jal`/`jalr`, `ID/EX.pc + 4`. |
| `flow_op` | Clase de flujo: `NONE`, `BEQ`, `BNE`, `JAL`, `JALR`, `HALT`. `BEQ` redirige si `ALU.zero=1`; `BNE`, si `ALU.zero=0`; `JAL` y `JALR` redirigen incondicionalmente con los destinos físicos ya aprobados; `HALT` permite identificar en EX al `halt` válido que allí se confirma. |
| `mem_op` | Acceso: `NONE`, `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW`. Distingue load/store, ancho y extensión con/sin signo del load; permite derivar `is_load` sin otro campo. |
| `reg_write` | Intención de escribir `rd`: verdadera para R-type, I-type aritmética/shifts, loads, `lui`, `jal` y `jalr`; falsa para stores, `beq`/`bne` y `halt`. Una intención no permite escribir si `valid=0`, hay fault propio o no se autoriza un ciclo efectivo. |

En EX, `flow_op=BEQ/BNE` utiliza la resta de `rs1_effective` y `rs2_effective` y `ALU.zero`, mientras `flow_op=JAL` utiliza el destino relativo a **`ID/EX.pc`** y `flow_op=JALR` el destino `(rs1_effective + immediate) & 0xFFFFFFFE` formado por los sumadores y el `Target MUX` ya aprobados. `flow_op=HALT` conserva la distinción entre candidato en ID y **confirmación de la instrucción válida en EX** durante un ciclo efectivo del camino correcto; no implica confirmación anticipada ni señal física `is_halt` separada. Un fault de destino de la propia instrucción de control suprime sus efectos normales conforme a `DEC-ARCH-004` y al trigésimo acuerdo.

La información se **reduce progresivamente** según la etapa consumidora:

```text
ID genera → ID/EX conserva información semántica de:
    alu_op, alu_src, result_sel, flow_op, mem_op, reg_write

EX consume:
    alu_op, alu_src, result_sel, flow_op

EX/MEM conserva entre sus campos de control:
    mem_op, reg_write

MEM consume:
    mem_op

MEM/WB conserva entre sus campos de control:
    reg_write

WB consume:
    reg_write
```

Esto preserva los campos ya aprobados **`EX/MEM.mem_op`**, **`EX/MEM.reg_write`** y **`MEM/WB.reg_write`**, así como los resultados y datos registrados de cada etapa; no extiende hacia EX/MEM señales de ALU, selección de resultado ni clase de flujo que ya fueron consumidas en EX. `mem_op` permite derivar el tipo de acceso, la disponibilidad del resultado de EX/MEM y la selección del valor arquitectónico hacia MEM/WB conforme a las políticas anteriores. `uses_rs1`/`uses_rs2` se derivan de la instrucción/control disponible según 3A y el acuerdo trigésimo segundo. Tampoco se exigen campos físicos independientes `is_load`, `mem_to_reg`, `is_halt` ni `target_sel`: pueden derivarse de `instruction`, `flow_op`, `mem_op` y de los demás controles existentes. No se altera el número de latches, el contenido de IF/ID ni la distinción bypass WB→ID / forwarding en EX.

La **validez** determina si una entrada contiene una instrucción activa: con `ID/EX.valid=0`, las categorías de control residuales no producen efectos arquitectónicos de ALU, redirect, `halt`, accesos a memoria, writeback, hazard ni fault por bits residuales; la lógica combinacional puede evaluarse sin comprometer resultados. Bubble y flush no obligan a codificar todos los controles como NOP; las etapas posteriores también requieren su propia validez y las condiciones normales para producir efectos. Reset, LOAD, RUN/STEP y HOLD mantienen su jerarquía global de `DEC-ARCH-008`.

Este trigésimo tercer acuerdo fija **qué información semántica** se genera, consume y transporta, sin imponer entonces nombres RTL definitivos, anchos ni códigos binarios, que el trigésimo cuarto acuerdo fija después para las señales principales. El empaquetado opcional de `ID/EX.control` permanece abierto en `DEC-ARCH-003`; los acuerdos cuadragésimo primero y segundo fijan después el arbitraje y los enables/capturas de PC y latches para sus nueve acciones.

#### Acuerdo parcial aprobado — nombres, anchos y codificación de controles y selectores

**Fecha:** 2026-09-25

Se fijan los **nombres, anchos y códigos funcionales** de los controles principales de `DEC-ARCH-003`, concretando el trigésimo tercer acuerdo sin obligar a materializar un único bus `ID/EX.control`. Las seis categorías generadas en ID acompañan a la instrucción hasta su etapa consumidora; podrán implementarse como señales separadas o estructura equivalente. Los códigos `RESERVED` no serán emitidos por el decoder para instrucciones válidas del subconjunto; los bits residuales de una entrada inválida carecen de efectos arquitectónicos, sin requerir NOP física.

**Operaciones de ALU.** La interfaz existente utiliza opcode de **6 bits**: `alu_op[5:0]`; en el CPU se aplicará a datos de **32 bits**. Se conservan los códigos existentes de ADD, SUB, AND, OR, XOR, SRL y SRA, y se incorporan los faltantes SLL, SLT y SLTU:

| `alu_op[5:0]` | Operación | `alu_op[5:0]` | Operación |
|---|---|---|---|
| `000000` | SLL | `100000` | ADD |
| `000010` | SRL | `100010` | SUB |
| `000011` | SRA | `100100` | AND |
| `101010` | SLT | `100101` | OR |
| `101011` | SLTU | `100110` | XOR |

La ALU de TP1/TP2 ya implementa los códigos conservados y `100111` para NOR, pero **todavía no implementa SLL, SLT ni SLTU**. NOR puede seguir existiendo internamente; el decoder del CPU no generará `100111` para ninguna instrucción válida del subconjunto. El presente acuerdo fija el contrato del CPU, no afirma que la ALU extendida ya esté implementada.

| Señal de control desde ID a ID/EX | Ancho | Codificación funcional |
|---|---|---|
| `alu_src` | 1 bit | `0` = RS2 (`rs2_effective`); `1` = IMMEDIATE (`immediate`) |
| `result_sel[1:0]` | 2 bits | `00` = ALU (`alu_result`); `01` = IMMEDIATE (`immediate`); `10` = LINK (`link_value`); `11` = RESERVED |
| `flow_op[2:0]` | 3 bits | `000` = NONE; `001` = BEQ; `010` = BNE; `011` = JAL; `100` = JALR; `101` = HALT; `110`/`111` = RESERVED |
| `mem_op[3:0]` | 4 bits | `0000` = NONE; `0001` = LB; `0010` = LH; `0011` = LW; `0100` = LBU; `0101` = LHU; `0110` = SB; `0111` = SH; `1000` = SW; `1001`–`1111` = RESERVED |
| `reg_write` | 1 bit | `0` = NO WRITE; `1` = WRITE, siempre subordinado a validez, ciclo efectivo y ausencia de fault propio |

`flow_op` permite derivar localmente `is_beq`, `is_bne`, `is_jal`, `is_jalr` e `is_halt`; `mem_op` permite derivar `is_load`, `is_store`, `access_size` y `load_unsigned`. Se conserva la **misma codificación `mem_op[3:0]`** desde ID/EX a `EX/MEM.mem_op` para MEM, y `reg_write` continúa desde ID/EX por `EX/MEM.reg_write` y `MEM/WB.reg_write` hasta WB. EX consume `alu_op`, `alu_src`, `result_sel` y `flow_op`; solo `mem_op` y `reg_write` siguen como controles a EX/MEM, y solo `reg_write` a MEM/WB. El trigésimo octavo acuerdo fija después las ecuaciones de derivación de `is_load`, `is_store`, `mem_access`, `access_size`, `load_unsigned` y los predicados de flujo, sin registrarlos como campos físicos adicionales.

Los **selectores locales** quedan fijados así, sin transportarlos a través de todos los latches:

| Señal local | Ancho | Codificación funcional / derivación |
|---|---|---|
| `forward_a_sel[1:0]`, `forward_b_sel[1:0]` | 2 bits cada una | `00` = ID_EX (`ID/EX.rsN_value`); `01` = EX_MEM (`EX/MEM.ex_result`); `10` = MEM_WB (`MEM/WB.wb_value`); `11` = RESERVED. Se deciden por fuente independientemente. |
| `target_sel` | 1 bit | `0` = PC_RELATIVE; `1` = JALR; derivable en EX como `flow_op == JALR`, sin campo transportado desde ID. |
| `wb_value_sel` | 1 bit | `0` = EX_RESULT; `1` = LOAD_VALUE; derivable en MEM como `is_load(EX/MEM.mem_op)`, sin campo transportado. |
| `next_pc_sel` | 1 bit | `0` = PC_PLUS_4; `1` = REDIRECT_TARGET. Selecciona solo las dos entradas ya aprobadas del Next-PC MUX. |
| `pc_write_enable` | 1 bit | `0` = retener PC; `1` = capturar la salida del Next-PC MUX. |

Las ecuaciones de forwarding del trigésimo segundo acuerdo siguen gobernando la elegibilidad de las entradas: con EX/MEM coincidente pero load aún no disponible, cualquier código o salida combinacional residual del mux **no se consume** como operando válido, aun si físicamente se observa `00`. `target_sel=0` o `wb_value_sel=0` en operaciones que no consumen esos caminos tampoco crea efectos sin validez. Las categorías `RESERVED` pertenecen a estos selectores de tres entradas y a los controles enumerados; no se impone codificación NOP específica al invalidar un latch.

Durante un **ciclo CPU efectivo**, las acciones nominales sobre PC usan:

```text
avance normal:              pc_write_enable=1, next_pc_sel=0 (PC_PLUS_4)
redirect EX aplicable:      pc_write_enable=1, next_pc_sel=1 (REDIRECT_TARGET)
load-use / halt / fault / drenado:
                            pc_write_enable=0, next_pc_sel=irrelevante
```

La retención no añade una tercera entrada al Next-PC MUX; ante HOLD no se aplica ninguna actualización aunque cambien sus señales combinacionales. RESET y LOAD aceptado/preparación mantienen la precedencia global de `DEC-ARCH-008`. El arbitraje por antigüedad y la invalidez de trabajo joven siguen rigiendo **antes de aplicar** los selectores, conforme a los acuerdos trigésimo y trigésimo primero.

Este trigésimo cuarto acuerdo cierra los **nombres, anchos y códigos funcionales principales** de control y selección sin introducir campos de pipeline ni exigir un vector `control` único. El trigésimo quinto acuerdo fija posteriormente las causas de fault de tres bits. Permanecen pendientes la integración RTL, ecuaciones de enables/invalidaciones/arbitraje no cubierto, el empaquetado opcional y otras codificaciones, como la del estado global.

#### Acuerdo parcial aprobado — codificación de causas de fault

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se fija una codificación **común de tres bits** para el candidato de fetch registrado en `IF/ID.fetch_fault_cause[2:0]` y para la causa de fault confirmado `fault_cause[2:0]`, mantenida como **estado global fuera de los cuatro latches**. Los siete códigos de causa corresponden exactamente a las categorías de `DEC-ARCH-004`:

| Código | Causa arquitectónica | Detección posible |
|---|---|---|
| `000` | INSTRUCTION_ADDRESS_MISALIGNED (`instruction-address-misaligned`) | Fetch IF o target de control en EX |
| `001` | INSTRUCTION_ACCESS_FAULT (`instruction-access-fault`) | Fetch IF |
| `010` | ILLEGAL_INSTRUCTION (`illegal-instruction`) | Decode ID sobre instrucción obtenida válida |
| `011` | **RESERVED** | Ninguna causa válida |
| `100` | LOAD_ADDRESS_MISALIGNED (`load-address-misaligned`) | Load EX |
| `101` | LOAD_ACCESS_FAULT (`load-access-fault`) | Load EX |
| `110` | STORE_ADDRESS_MISALIGNED (`store-address-misaligned`) | Store EX |
| `111` | STORE_ACCESS_FAULT (`store-access-fault`) | Store EX |

**No existe un código `NONE`.** Ausencia de candidato de fetch se expresa mediante `IF/ID.fetch_fault_valid=0`; ausencia de fault global confirmado mediante el estado/flag global correspondiente. Cuando ese indicador está inactivo, los bits de causa pueden ser residuales sin significado arquitectónico, incluso si físicamente coinciden con un código de causa o con `011`. Para un **candidato válido** generado en IF, `fetch_fault_cause` solo puede tomar `000` o `001`; IF nunca genera `010`–`111` como candidato válido. El ancho común permite que la ruta ordinaria IF→IF/ID→ID transfiera directamente `IF/ID.fetch_fault_cause[2:0]` a `fault_cause[2:0]` **solo al confirmar** y sin traducción. En la excepción de `load-use` entre anteriores, IF confirma directamente el fetch elegible y registra su código `000` o `001` sin sobrescribir IF/ID ni exigir otro latch.

En ID la instrucción ilegal válida confirma `010`; en EX un target desalineado de branch tomado, `jal` o `jalr` confirma `000`, la **misma causa arquitectónica** que un fetch desalineado aunque se detecte en etapa distinta. Para loads y stores EX se elige respectivamente entre `100`/`101` o `110`/`111`; si una misma operación presenta desalineación y acceso inválido, se selecciona su código **misaligned**, conforme a `misalignment > access fault`. Entre instrucciones distintas continúa prevaleciendo la más antigua válida del camino correcto. La causa identifica el **tipo de fault**, no la etapa física donde se detectó.

`fault_cause[2:0]` se captura únicamente junto a la **confirmación arquitectónica** y permanece estable, con `fault_pc`, durante `FAULT_DRAIN` y `FAULT`. Un candidato detectado pero descartado (`wrong-path`, inválido o posterior a frontera anterior) no altera esos metadatos. Reset global y LOAD aceptado mantienen la invalidación semántica de candidatos y de la condición de fault conforme a `DEC-ARCH-008`, sin requerir borrar bits residuales. Este trigésimo quinto acuerdo **revisa explícitamente solo el ancho antes abierto** del campo de candidato del acuerdo vigésimo noveno: IF/ID continúa con cinco campos; los otros tres latches no ganan campos de fault. `fault_pc`, prioridades, etapas de detección y rutas de transporte/confirmación conservan sus acuerdos anteriores. El trigésimo sexto acuerdo fija después `terminal_kind[1:0]` como indicador global de fault confirmado y la derivación de `fault_drain`/`fault`; la representación externa de Debug/UART sigue pendiente.

#### Acuerdo parcial aprobado — representación del estado global de terminación y drenado

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

**Revisión expresa por el cuadragésimo cuarto acuerdo:** las fórmulas registradas `terminal_kind` y `drain_auto` de este acuerdo quedan sustituidas por los estados de `global_state` y predicados combinacionales derivados. Esta sección documenta el contrato semántico anterior; ya no exige esos dos flip-flops, ni que `HALT_DRAIN`/`FAULT_DRAIN` sean condiciones únicamente combinacionales. Permanecen la exclusión HALT/FAULT, la terminación en el flanco que vacía el último latch y la distinción de drenado continuo o por STEP.

La frontera terminal confirmada se representa mediante **estado global registrado fuera de los cuatro latches**, sin almacenar `HALT_DRAIN`, `FINISHED`, `FAULT_DRAIN` y `FAULT` como cuatro estados independientes:

| `terminal_kind[1:0]` | Significado |
|---|---|
| `00` | NONE: aún no hay frontera terminal arquitectónicamente confirmada |
| `01` | HALT: se confirmó un `halt` válido |
| `10` | FAULT: se confirmó un fault arquitectónico |
| `11` | RESERVED: no se genera por confirmaciones válidas |

La clase registrada es única: no pueden estar confirmados simultáneamente `halt` y fault. La selección de la frontera sigue sometida a **validez, camino correcto y antigüedad EX→ID→IF excepcional** y al tratamiento de fault propio y de stalls entre anteriores supervivientes ya aprobados; la codificación no reabre su arbitraje semántico. Durante un ciclo CPU efectivo, `halt` válido confirmado en EX establece `terminal_kind.next=HALT`; un fault confirmado en EX, ID o excepcionalmente IF establece `terminal_kind.next=FAULT` **junto con** la captura de `fault_cause[2:0]` y `fault_pc`. Un candidato de `halt` en ID, un candidato de fault no confirmado o trabajo joven descartado no altera la clase terminal ni esos metadatos.

La ocupación actual del pipeline se calcula combinacionalmente a partir de las cuatro validez de instrucción:

```text
pipeline_empty =
    !IF/ID.valid
    && !ID/EX.valid
    && !EX/MEM.valid
    && !MEM/WB.valid

halt_drain  = (terminal_kind == HALT)  && !pipeline_empty
finished    = (terminal_kind == HALT)  &&  pipeline_empty

fault_drain = (terminal_kind == FAULT) && !pipeline_empty
fault       = (terminal_kind == FAULT) &&  pipeline_empty
```

`fetch_fault_valid` **no** integra `pipeline_empty`: después de confirmar una frontera terminal no se admiten instrucciones jóvenes ni se conservan candidatos posteriores, y solo se drenan instrucciones anteriores válidas. En el fault IF excepcional durante `load-use`, el consumidor anterior permanece válido en IF/ID, por lo que `fault_drain` continúa activo mientras ese consumidor avance y complete. Si ninguna anterior sobrevive, la condición final `finished` o `fault` surge **tras el propio flanco de confirmación**, sin ciclo artificial de drenado. Si sí hay anteriores, pasa de `halt_drain`/`fault_drain` a la condición final al vaciarse el último latch en un ciclo efectivo, sin estado registrado intermedio ni ciclo extra. HOLD no altera la ocupación registrada y no adelanta esa transición.

Se registra además un único bit global **`drain_auto`** que recuerda cómo se autorizó el ciclo **confirmante**: `0` = modo paso a paso, cada ciclo posterior de drenado requiere un **STEP nuevo aceptado**; `1` = autorización continua, se podrán solicitar automáticamente ciclos posteriores de drenado. En la confirmación `drain_auto.next=1` si el ciclo fue autorizado bajo ejecución continua, o `drain_auto.next=0` si fue autorizado por STEP aceptado. Mientras `terminal_kind != NONE && !pipeline_empty` existe drenado pendiente; `drain_auto` **no es por sí solo** un pulso de avance ni habilita writebacks/stores. Todo avance requiere ciclo CPU efectivo autorizado, incluso si entre las supervivientes hacen falta stalls o forwarding; HOLD no produce ciclo ni repite efectos. Una vez derivados `finished` o `fault`, no queda trabajo que drenar ni se solicitan ciclos normales por esa condición. Esta representación no sustituye el control global de RESET, LOAD, RUN, STEP y HOLD, cuya prioridad sigue siendo **reset global > LOAD aceptado/preparación > ciclo efectivo > HOLD**, conforme a `DEC-ARCH-008`.

Reset global y preparación coherente de nueva sesión establecen `terminal_kind=NONE` y `drain_auto=0`; el mero intento de LOAD rechazado durante RUN o drenado automático no cambia estos registros. Con `terminal_kind=NONE`, los bits residuales de `fault_cause` y `fault_pc` no representan un fault confirmado y no necesitan limpiarse físicamente. En `terminal_kind=FAULT`, ambos metadatos permanecen estables durante `fault_drain` y `fault`; tampoco se reemplazan por candidatos posteriores. El trigésimo sexto acuerdo fija la **representación terminal y la modalidad de drenado**, sin añadir campos a IF/ID, ID/EX, EX/MEM o MEM/WB, imponer códigos de estados del control global, formato Debug/UART ni ecuaciones RTL de arbitraje no cubiertas.

> **Aclaración de adaptación RV32 (AUD-011, 2026-09-26):** conservar los opcodes de la ALU de TP1/TP2 no exige conservar su cantidad de desplazamiento genérica. SLL/SRL/SRA consumen solo los cinco bits bajos del operando de cantidad seleccionado (`shamt = operand_b[4:0]`), por registro o inmediato. SRA interpreta con signo el dato; los bits fijos de SRAI no forman parte de shamt. La adaptación puede estar dentro de la ALU o en su frontera, sin cambiar opcodes ni modificar los TPs anteriores.

#### Acuerdo parcial aprobado — ecuaciones RTL del decoder de ID

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

ID utilizará un **decoder combinacional único** que valide la word completa de `IF/ID.instruction[31:0]` contra la whitelist estricta de **32 instrucciones RV32I y `halt = 32'h0000000B`** de `DEC-ARCH-004` y genere los controles semánticos para ID/EX. Se observan `opcode = instruction[6:0]`, `funct3 = instruction[14:12]` y `funct7 = instruction[31:25]`; para shifts inmediatos, los siete bits superiores se comprueban como campo fijo. Todos los índices de registros, inmediatos y `shamt` de cinco bits permitidos por RV32I conservan su libertad: validar la word completa significa comprobar **los bits fijos aplicables**, no exigir valores concretos para operandos o inmediatos variables. No se incorporan campos nuevos a IF/ID.

```text
illegal_candidate = IF/ID.valid && !decode_legal
halt_candidate = IF/ID.valid && decode_legal
                 && (IF/ID.instruction == 32'h0000000B)
```

`decode_legal` clasifica combinacionalmente la codificación, sin confirmar por sí solo un fault. Con `IF/ID.valid=0, IF/ID.fetch_fault_valid=1` hay un **candidato de fetch**, no una instrucción ilegal; los bits de `instruction` son residuales. Solo una instrucción válida del camino correcto puede producir `illegal_candidate`; su confirmación en ID sigue sujeta a la frontera más antigua EX→ID→IF excepcional. Una word exacta de `halt` válida en ID genera únicamente `halt_candidate`; su confirmación sigue ocurriendo en EX.

**R-type (`opcode=0110011`).** Se admiten únicamente estos diez pares exactos:

| Instrucción | `funct7` | `funct3` | `alu_op[5:0]` |
|---|---|---|---|
| `add` | `0000000` | `000` | `100000` (ADD) |
| `sub` | `0100000` | `000` | `100010` (SUB) |
| `sll` | `0000000` | `001` | `000000` (SLL) |
| `slt` | `0000000` | `010` | `101010` (SLT) |
| `sltu` | `0000000` | `011` | `101011` (SLTU) |
| `xor` | `0000000` | `100` | `100110` (XOR) |
| `srl` | `0000000` | `101` | `000010` (SRL) |
| `sra` | `0100000` | `101` | `000011` (SRA) |
| `or` | `0000000` | `110` | `100101` (OR) |
| `and` | `0000000` | `111` | `100100` (AND) |

En los diez casos: `alu_src=0`, `result_sel=00`, `flow_op=000`, `mem_op=0000`, `reg_write=1`, `uses_rs1=1`, `uses_rs2=1`. Todo otro par `funct7/funct3` para este opcode es ilegal, incluso si comparte parcialmente un código de ALU.

**I-type aritméticas y shifts inmediatos (`opcode=0010011`).** Para `addi` (`funct3=000`), `slti` (`010`), `sltiu` (`011`), `xori` (`100`), `ori` (`110`) y `andi` (`111`), `alu_op` es respectivamente ADD (`100000`), SLT (`101010`), SLTU (`101011`), XOR (`100110`), OR (`100101`) y AND (`100100`). Sus doce bits de inmediato siguen siendo variables. Las otras tres codificaciones legales bajo este opcode exigen **además** los bits fijos `instruction[31:25]`:

| Instrucción | `funct3` | `instruction[31:25]` | `alu_op[5:0]` |
|---|---|---|---|
| `slli` | `001` | `0000000` | `000000` (SLL) |
| `srli` | `101` | `0000000` | `000010` (SRL) |
| `srai` | `101` | `0100000` | `000011` (SRA) |

En las nueve I aritméticas/shifts: `alu_src=1`, `result_sel=00`, `flow_op=000`, `mem_op=0000`, `reg_write=1`, `uses_rs1=1`, `uses_rs2=0`. Un shift inmediato con `instruction[31:25]` distinto del patrón correspondiente es ilegal; sus bits `instruction[24:20]` son el `shamt` legal de cinco bits, no otro `rs2` consumido.

**Memoria.** Todos los loads (`opcode=0000011`) usan ADD (`alu_op=100000`), `alu_src=1`, `result_sel=00`, `flow_op=000`, `reg_write=1`, `uses_rs1=1`, `uses_rs2=0`. Los stores (`opcode=0100011`) usan ADD, `alu_src=1`, `result_sel=00`, `flow_op=000`, `reg_write=0`, `uses_rs1=1`, `uses_rs2=1`:

| Clase | `funct3` | Instrucción | `mem_op[3:0]` |
|---|---|---|---|
| Load | `000` | `lb` | `0001` |
| Load | `001` | `lh` | `0010` |
| Load | `010` | `lw` | `0011` |
| Load | `100` | `lbu` | `0100` |
| Load | `101` | `lhu` | `0101` |
| Store | `000` | `sb` | `0110` |
| Store | `001` | `sh` | `0111` |
| Store | `010` | `sw` | `1000` |

Los `funct3` restantes de esos opcodes son ilegales. El dato de store de `rs2` continúa resolviéndose mediante forwarding en EX y transportándose en `EX/MEM.store_data` hasta MEM, aunque la ALU use el inmediato como segundo operando para la dirección.

**Branches (`opcode=1100011`).** Solo `funct3=000` (`beq`, `flow_op=001`) y `funct3=001` (`bne`, `flow_op=010`) son legales. En ambos: `alu_op=SUB` (`100010`), `alu_src=0`, `result_sel=00`, `mem_op=0000`, `reg_write=0`, `uses_rs1=1`, `uses_rs2=1`. EX compara mediante la resta y `ALU.zero` ya aprobadas. Los demás `funct3` son ilegales.

**Saltos, `lui` y `halt`.** Los controles restantes son:

| Instrucción | Patrón legal | `alu_op` | `alu_src` | `result_sel` | `flow_op` | `mem_op` | `reg_write` | `uses_rs1` / `uses_rs2` |
|---|---|---|---|---|---|---|---|---|
| `jal` | `opcode=1101111` | ADD | `1` | `10` (LINK) | `011` (JAL) | `0000` | `1` | `0` / `0` |
| `jalr` | `opcode=1100111`, `funct3=000` | ADD | `1` | `10` (LINK) | `100` (JALR) | `0000` | `1` | `1` / `0` |
| `lui` | `opcode=0110111` | ADD | `1` | `01` (IMMEDIATE) | `000` (NONE) | `0000` | `1` | `0` / `0` |
| `halt` | word completa `32'h0000000B` | ADD | `0` | `00` (ALU) | `101` (HALT) | `0000` | `0` | `0` / `0` |

Para `jal`, `lui` y `halt`, `alu_op=ADD` (`100000`) y `alu_src` tienen valores **deterministas sin consumo funcional** de la ALU. `jalr` sigue calculando el target `(rs1_effective + immediate) & 32'hFFFFFFFE` con el camino dedicado aprobado, no con un cambio del decoder. Cualquier `funct3` distinto de `000` bajo `1100111` es ilegal; cualquier otra word `custom-0` que no sea la **word completa** de `halt` también es ilegal.

**Defaults al inicio de la lógica combinacional**, aplicables a toda codificación no reconocida:

```text
decode_legal = 0
alu_op       = 6'b100000  // ADD
alu_src      = 0           // RS2
result_sel   = 2'b00       // ALU
flow_op      = 3'b000      // NONE
mem_op       = 4'b0000     // NONE
reg_write    = 0
uses_rs1     = 0
uses_rs2     = 0
```

El decoder comprueba conceptualmente primero la word exacta de `halt` y después opcode y subcampos funcionales cuando corresponda; podrá implementarse con una única lógica combinacional equivalente. Una instrucción ilegal mantiene los defaults funcionalmente neutros, pero **su confirmación en ID impide que ingrese válida a ID/EX**; sus bits residuales no se convierten en operaciones activas. `decode_legal` no convierte en válida una entrada `IF/ID.valid=0` ni genera efectos arquitectónicos por sí solo. `uses_rs1` y `uses_rs2` quedan fijados como **salidas combinacionales derivadas**, no campos registrados de IF/ID o ID/EX; para forwarding en EX su información podrá volver a derivarse de la instrucción/control ya registrado. No se obliga a empaquetar las seis categorías de control en un bus único.

Este trigésimo séptimo acuerdo fija el decoder de ID y sus ecuaciones funcionales sin cambiar la whitelist, la generación del inmediato, el arbitraje por antigüedad EX→ID→IF excepcional, los enables, la política de faults confirmados ni el control global de ciclos. Solo una coincidencia completa con la whitelist produce `decode_legal=1` y controles aptos para **ingreso válido** a ID/EX cuando las fronteras más antiguas lo permitan.

#### Acuerdo parcial aprobado — ecuaciones de controles derivados locales

**Fecha:** 2026-09-25

Los controles transportados mantienen los nombres y códigos del trigésimo cuarto acuerdo; las siguientes señales son **lógica combinacional local**, no campos nuevos de ID/EX, EX/MEM o MEM/WB. Se conserva `mem_op[3:0]` en ID/EX y EX/MEM: `0000` NONE; `0001` LB; `0010` LH; `0011` LW; `0100` LBU; `0101` LHU; `0110` SB; `0111` SH; `1000` SW; `1001`–`1111` RESERVED.

```text
is_load(mem_op) =
       (mem_op == 4'b0001)  // LB
    || (mem_op == 4'b0010)  // LH
    || (mem_op == 4'b0011)  // LW
    || (mem_op == 4'b0100)  // LBU
    || (mem_op == 4'b0101)  // LHU

is_store(mem_op) =
       (mem_op == 4'b0110)  // SB
    || (mem_op == 4'b0111)  // SH
    || (mem_op == 4'b1000)  // SW

mem_access = is_load || is_store
```

Estas funciones se aplican **localmente al `mem_op` de la etapa correspondiente**: en ID/EX sirven, entre otras cosas, para detectar `load-use`; en EX/MEM determinan disponibilidad de forwarding y acceso/selección de valor en MEM. No se arrastra un bit `is_load`, `is_store` o `mem_access` por los latches. Solo una instrucción válida y elegible podrá ocasionar acceso a memoria o efectos arquitectónicos: la decodificación combinacional de residuos no habilita operaciones por sí sola.

| `access_size[1:0]` | Significado | `mem_op` que lo seleccionan |
|---|---|---|
| `00` | BYTE | LB, LBU, SB |
| `01` | HALFWORD | LH, LHU, SH |
| `10` | WORD | LW, SW |
| `11` | RESERVED | Ninguna operación válida |

Con `mem_access=0`, `access_size` **carece de significado funcional**; no se impone valor para NONE, códigos reservados ni entradas inválidas. La extensión de loads se selecciona localmente por:

```text
load_unsigned = (mem_op == 4'b0100) || (mem_op == 4'b0101)
```

Así, LB/LH/LW tienen `load_unsigned=0` y LBU/LHU `load_unsigned=1`. Para stores, NONE y códigos reservados, el valor no se consume y es funcionalmente irrelevante. Se conservan el ancho del acceso, el chequeo de rango/alineación en EX y la extensión en MEM ya aprobados.

La disponibilidad del **resultado arquitectónico** de un productor en EX/MEM se obtiene sin bit registrado adicional:

```text
exmem_result_available = !is_load(EX/MEM.mem_op)

forward_exmem_rsN = exmem_match_rsN && exmem_result_available
forward_memwb_rsN = !exmem_match_rsN && memwb_match_rsN
```

`exmem_match_rsN` ya exige consumidor válido y fuente utilizada, productor EX/MEM válido, `reg_write=1`, `rd != x0` y coincidencia de índice; no se repiten esas condiciones en `exmem_result_available`. Para una instrucción escritora válida no load, `EX/MEM.ex_result` contiene el resultado reenviable (ALU, `lui` o enlace); para un load, solo la **dirección efectiva**, no el dato. Si ese load es el productor coincidente más reciente, `forward_exmem_rsN=0` y `forward_memwb_rsN=0`, aunque MEM/WB tenga una versión anterior; tampoco se consume el valor base obsoleto de ID/EX que pueda aparecer como salida residual del mux. Los stalls y el avance de anteriores supervivientes siguen las reglas ya aprobadas. Para una entrada EX/MEM inválida o con control residual, `!is_load` puede evaluarse a uno sin crear forwarding: `exmem_match_rsN=0`. No se define un uso arquitectónico de códigos `mem_op` reservados como si fueran instrucciones válidas.

Las clases de flujo se derivan exclusivamente de `ID/EX.flow_op[2:0]`:

```text
is_beq  = (ID/EX.flow_op == 3'b001)
is_bne  = (ID/EX.flow_op == 3'b010)
is_jal  = (ID/EX.flow_op == 3'b011)
is_jalr = (ID/EX.flow_op == 3'b100)
is_halt = (ID/EX.flow_op == 3'b101)

target_sel = is_jalr
// equivalentemente: target_sel = (ID/EX.flow_op == 3'b100)

wb_value_sel = is_load(EX/MEM.mem_op)
```

`target_sel=0` selecciona PC_RELATIVE para BEQ/BNE/JAL; `target_sel=1` selecciona JALR_TARGET para JALR. Con NONE o HALT, `target_sel` puede valer combinacionalmente cero, pero el camino de target carece de efecto arquitectónico; una entrada inválida tampoco aplica redirect por sus bits residuales. `wb_value_sel=1` elige LOAD_VALUE para LB/LH/LW/LBU/LHU y `0` elige EX_RESULT para los demás códigos; si la entrada no escribe registro o es inválida, esa selección no compromete writeback. Los predicados de flujo no se registran como campos físicos independientes y no sustituyen la validez ni la prioridad por antigüedad.

`result_sel[1:0]` **ya viaja explícitamente a EX**: no necesita derivación adicional. El Result MUX forma `ex_result = alu_result` con `00`, `ex_result = immediate` con `01` o `ex_result = link_value` con `10`; `11` permanece reservado y nunca es emitido para una instrucción válida. `target_sel`, `wb_value_sel`, tamaño/unsigned y las clasificaciones de flujo/memoria son locales y no amplían el contenido registrado de ningún latch.

Este trigésimo octavo acuerdo cierra estas **ecuaciones de derivación combinacional**, incluida `exmem_result_available`, sin modificar la ecuación de forwarding por fuente del trigésimo segundo acuerdo; los acuerdos cuadragésimo primero y segundo fijan después el arbitraje y la actualización de PC/latches, mientras la autorización global de ciclos permanece pendiente. Una señal combinacional aislada no produce efectos sin instrucción válida, camino elegible y ciclo efectivo.

#### Acuerdo parcial aprobado — realización RTL del Load-Use Hazard Detector y la Forwarding Unit

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se fija la realización RTL **combinacional** de los dos bloques de hazards de datos ya aprobados. No cambian la política funcional del trigésimo segundo acuerdo, los cuatro latches, los dos Forward MUX 3:1 ni el bypass WB→ID separado. El **Load-Use Hazard Detector** utiliza los índices de IF/ID obtenidos de la instrucción y las salidas combinacionales de uso del decoder de ID del trigésimo séptimo acuerdo:

```text
ifid_rs1 = IF/ID.instruction[19:15]
ifid_rs2 = IF/ID.instruction[24:20]
ifid_uses_rs1, ifid_uses_rs2 = uso semántico decodificado en ID

idex_is_load = is_load(ID/EX.mem_op)

load_use_stall =
    ID/EX.valid
    && idex_is_load
    && (ID/EX.rd != 5'd0)
    && IF/ID.valid
    && (
         (ifid_uses_rs1 && (ifid_rs1 == ID/EX.rd))
         ||
         (ifid_uses_rs2 && (ifid_rs2 == ID/EX.rd))
       )
```

`IF/ID.fetch_fault_valid` no habilita consumidor: un candidato de fetch tiene `IF/ID.valid=0`, aunque los índices de la word residual coincidan. La salida `load_use_stall` **solo detecta** la dependencia; no escribe PC, retiene IF/ID ni inserta por sí misma la bubble. El `Pipeline Hazard Control` determinará si aplica el stall después de seleccionar fronteras EX→ID→IF excepcional y de descartar trabajo joven, únicamente cuando load y consumidor continúen siendo anteriores supervivientes. HOLD permite evaluar la ecuación sin autorizar una transición secuencial.

La **Forwarding Unit** vuelve a derivar `idex_uses_rs1` e `idex_uses_rs2` combinacionalmente de `ID/EX.instruction` ya registrada, con la clasificación semántica de fuentes aprobada; no registra estos bits ni agrega otro campo a ID/EX. Para cada fuente se implementan literalmente las coincidencias:

```text
exmem_match_rs1 =
    ID/EX.valid && idex_uses_rs1
    && EX/MEM.valid && EX/MEM.reg_write
    && (EX/MEM.rd != 5'd0)
    && (EX/MEM.rd == ID/EX.rs1)

memwb_match_rs1 =
    ID/EX.valid && idex_uses_rs1
    && MEM/WB.valid && MEM/WB.reg_write
    && (MEM/WB.rd != 5'd0)
    && (MEM/WB.rd == ID/EX.rs1)

exmem_match_rs2 =
    ID/EX.valid && idex_uses_rs2
    && EX/MEM.valid && EX/MEM.reg_write
    && (EX/MEM.rd != 5'd0)
    && (EX/MEM.rd == ID/EX.rs2)

memwb_match_rs2 =
    ID/EX.valid && idex_uses_rs2
    && MEM/WB.valid && MEM/WB.reg_write
    && (MEM/WB.rd != 5'd0)
    && (MEM/WB.rd == ID/EX.rs2)
```

Con la disponibilidad local fijada en el trigésimo octavo acuerdo, las habilitaciones y la prioridad de los **dos selectores independientes** quedan:

```text
exmem_result_available = !is_load(EX/MEM.mem_op)

forward_exmem_rs1 = exmem_match_rs1 && exmem_result_available
forward_memwb_rs1 = !exmem_match_rs1 && memwb_match_rs1

forward_a_sel = forward_exmem_rs1 ? 2'b01 :
                forward_memwb_rs1 ? 2'b10 :
                                      2'b00

forward_exmem_rs2 = exmem_match_rs2 && exmem_result_available
forward_memwb_rs2 = !exmem_match_rs2 && memwb_match_rs2

forward_b_sel = forward_exmem_rs2 ? 2'b01 :
                forward_memwb_rs2 ? 2'b10 :
                                      2'b00
```

Para ambos muxes de 32 bits, `00` elige `ID/EX.rsN_value`, `01` elige `EX/MEM.ex_result` y `10` elige `MEM/WB.wb_value`; `11` permanece reservado y no se genera en una selección válida. La negación de prioridad se aplica a **`exmem_match_rsN`**, no a `forward_exmem_rsN`: un EX/MEM coincidente siempre oculta un productor MEM/WB anterior para esa fuente, aun cuando `exmem_result_available=0` por tratarse de un load.

Si `exmem_match_rsN=1` y `exmem_result_available=0`, ambas habilitaciones son cero y el selector respectivo toma **físicamente `2'b00`**. La entrada base que muestre el mux es un dato residual **no consumible** en esa situación; ni la dirección efectiva de EX/MEM, ni el `wb_value` anterior de MEM/WB ni el valor base obsoleto pueden actuar como operando arquitectónico. La consumidora inmediata habrá esperado conforme a `load-use`, y los stalls que necesiten anteriores supervivientes se preservan durante el drenado. No se añade una cuarta entrada, bypass `DMEM → EX` ni un tipo nuevo de hazard. Productores inválidos, sin `reg_write` o con `rd=x0`, consumidores inválidos y fuentes no usadas no generan coincidencia funcional; `exmem_result_available` aislado no la sustituye. Ambos bloques pueden evaluarse durante HOLD sin originar por sí mismos ciclos, commits ni cambios de los latches.

Este trigésimo noveno acuerdo **cierra las ecuaciones RTL de detección y selección de los dos bloques combinacionales**. El cuadragésimo acuerdo fija después candidatos y confirmaciones/aplicación de fault, redirect y `halt`; el cuadragésimo primero fija la selección combinacional de acciones del `Pipeline Hazard Control`. El cuadragésimo segundo fija después los enables, bubble/flush y capturas de PC/latches para esas acciones; permanecen abiertas las coincidencias globales no cubiertas, siempre bajo la prioridad por antigüedad ya fijada. No se introduce estado ni control registrado adicional.

#### Acuerdo parcial aprobado — detección y confirmación RTL de eventos arquitectónicos

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

**Revisión de representación por el acuerdo 44:** `terminal_none` se deriva ahora de `global_state`; `terminal_kind.next` en las descripciones históricas designa la transición de la FSM a la clase FAULT/HALT y no un registro separado. Las confirmaciones, la selección de `fault_cause_in`/`fault_pc_in` y su instante de captura permanecen literalmente vigentes.

Se fijan las **señales combinacionales de detección** y las **condiciones de confirmación o aplicación** de faults, `halt` y redirects. `cpu_cycle_fire` designa conceptualmente un ciclo CPU efectivo autorizado por el control global, no un nuevo estado ni una ecuación para generar esa autorización; `terminal_none = (terminal_kind == NONE)` indica ausencia de frontera terminal previamente confirmada. Reset y LOAD aceptado/preparación preceden al ciclo efectivo conforme a `DEC-ARCH-008`. Durante HOLD puede evaluarse la lógica combinacional, pero no se confirma ni aplica ningún evento. Se conserva el arbitraje por antigüedad **EX→ID→IF excepcional**.

En IF se verifican los cuatro bytes del fetch con **aritmética ensanchada** frente a la capacidad de IMEM y al prefijo de imagen confirmado; la alineación se comprueba independientemente:

```text
if_fetch_range_valid =
    image_valid
    && ({1'b0, PC} + 33'd4 <= IMEM_CAPACITY_BYTES)
    && ({1'b0, PC} + 33'd4 <= loaded_image_size_bytes)

if_fetch_misaligned = (PC[1:0] != 2'b00)
if_fetch_access_fault = !if_fetch_range_valid
if_fetch_fault_candidate = if_fetch_misaligned || if_fetch_access_fault

if_fetch_fault_cause =
    if_fetch_misaligned    ? 3'b000 :  // INSTRUCTION_ADDRESS_MISALIGNED
    if_fetch_access_fault ? 3'b001 :  // INSTRUCTION_ACCESS_FAULT
                            irrelevante si no hay candidato
```

Ante ambas causas de un **mismo fetch**, desalineación prevalece sobre acceso inválido; la detección ordinaria en IF no confirma fault. En ID la word obtenida de un fetch válido se clasifica con el decoder único aprobado; un candidato de fetch registrado no es una instrucción ilegal:

```text
illegal_candidate = IF/ID.valid && !decode_legal
id_fetch_fault_candidate = !IF/ID.valid && IF/ID.fetch_fault_valid
id_fault_candidate = illegal_candidate || id_fetch_fault_candidate

if (illegal_candidate):
    id_fault_cause = 3'b010  // ILLEGAL_INSTRUCTION
    id_fault_pc    = IF/ID.pc
else if (id_fetch_fault_candidate):
    id_fault_cause = IF/ID.fetch_fault_cause
    id_fault_pc    = IF/ID.pc
```

Las dos rutas ID son mutuamente excluyentes por la representación de IF/ID. Fuera de `id_fault_candidate`, las salidas de causa/PC combinacionales no habilitan captura global.

> **Aclaración por AUD-004 (2026-09-26):** en las ecuaciones históricas siguientes, `effective_address` es el resultado módulo `2^32` de base más inmediato; su carry no es un fault. La protección contra overflow/wrap-around se refiere a la suma ensanchada del extremo de la región y a su indexación, conforme a la aclaración de `DEC-ARCH-001` y `DEC-ARCH-004`.

EX calcula la dirección efectiva de cada load/store **con `rs1_effective` reenviado cuando corresponda**. `access_size` es la derivación local ya fijada de `ID/EX.mem_op`; su número de bytes solicitado y el rango completo se expresan así, sin truncamiento, wrap-around ni validación parcial:

```text
effective_address = rs1_effective + ID/EX.immediate

access_size == BYTE     → mem_nbytes = 1
access_size == HALFWORD → mem_nbytes = 2
access_size == WORD     → mem_nbytes = 4

dmem_range_valid =
    ({1'b0, effective_address} + mem_nbytes) <= DMEM_CAPACITY_BYTES

mem_misaligned =
    (access_size == HALFWORD && effective_address[0])
    || (access_size == WORD && |effective_address[1:0])

load_misaligned_candidate =
    ID/EX.valid && is_load(ID/EX.mem_op) && mem_misaligned
load_access_candidate =
    ID/EX.valid && is_load(ID/EX.mem_op) && !dmem_range_valid
store_misaligned_candidate =
    ID/EX.valid && is_store(ID/EX.mem_op) && mem_misaligned
store_access_candidate =
    ID/EX.valid && is_store(ID/EX.mem_op) && !dmem_range_valid
```

Los accesos BYTE nunca fallan por alineación natural. Los valores de tamaño reservados o residuales en una entrada inválida no producen un acceso arquitectónico; un candidato confirmado inhibe **todos** los efectos propios de la operación, incluso las escrituras parciales de un store. Para branch y jump en EX se conservan las clases de `flow_op` y los destinos ya fijados:

```text
branch_taken = (is_beq && ALU.zero) || (is_bne && !ALU.zero)

redirect_requested =
    ID/EX.valid && (branch_taken || is_jal || is_jalr)

BEQ / BNE / JAL → redirect_target = pc_relative_target
JALR            → redirect_target = jalr_target

target_misaligned_candidate =
    redirect_requested && (redirect_target[1:0] != 2'b00)
```

El branch no tomado no solicita redirect ni verifica como fault un target que no utiliza; `jalr_target` borra **solo** el bit 0 de `jalr_sum` antes de esa comprobación. Un target alineado fuera de IMEM o imagen puede redirigirse; el fetch posterior detectará por separado el candidato de acceso inválido.

`redirect_requested` concreta la **solicitud combinacional nominal** antes descrita como `redirect_valid`; no constituye una segunda clase de redirect ni equivale a `redirect_apply`. La solicitud puede coexistir con fault propio por target desalineado, pero solo la condición de aplicación efectúa el cambio de PC.

Las cinco candidaturas de fault propio de EX y su causa se seleccionan únicamente para la instrucción válida de esa etapa. Dentro de un mismo load/store se prioriza **desalineación sobre acceso inválido**:

```text
ex_fault_candidate =
    target_misaligned_candidate
    || load_misaligned_candidate || load_access_candidate
    || store_misaligned_candidate || store_access_candidate

if (target_misaligned_candidate):
    ex_fault_cause = 3'b000  // INSTRUCTION_ADDRESS_MISALIGNED
else if (load_misaligned_candidate):
    ex_fault_cause = 3'b100  // LOAD_ADDRESS_MISALIGNED
else if (load_access_candidate):
    ex_fault_cause = 3'b101  // LOAD_ACCESS_FAULT
else if (store_misaligned_candidate):
    ex_fault_cause = 3'b110  // STORE_ADDRESS_MISALIGNED
else if (store_access_candidate):
    ex_fault_cause = 3'b111  // STORE_ACCESS_FAULT

ex_halt_candidate = ID/EX.valid && (ID/EX.flow_op == HALT)
ex_halt_event = !ex_fault_candidate && ex_halt_candidate
ex_redirect_event =
    !ex_fault_candidate && !ex_halt_candidate && redirect_requested
ex_frontier = ex_fault_candidate || ex_halt_event || ex_redirect_event
```

EX no vuelve a comparar la word `32'h0000000B`: el decoder validó `halt` en ID y transportó `flow_op=HALT` con la instrucción válida. El orden interno EX representa **fault propio → `halt` → redirect**. Así, un jump con target desalineado puede presentar `redirect_requested=1`, pero su fault propio impide aplicar el redirect y, para `jal`/`jalr`, escribir enlace. Para instrucciones válidas del decoder, las categorías de memoria, salto y `halt` son excluyentes; la prioridad de causas no convierte códigos reservados en instrucciones válidas.

La confirmación/aplicación de cada frontera requiere un ciclo CPU efectivo y ninguna frontera terminal anterior:

```text
ex_fault_confirm =
    cpu_cycle_fire && terminal_none && ex_fault_candidate

halt_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_fault_candidate && ex_halt_candidate

redirect_apply =
    cpu_cycle_fire && terminal_none
    && !ex_fault_candidate && !ex_halt_candidate
    && redirect_requested

id_fault_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_frontier && id_fault_candidate

if_fault_exception_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_frontier && !id_fault_candidate
    && load_use_stall && if_fetch_fault_candidate

fault_confirm =
    ex_fault_confirm || id_fault_confirm || if_fault_exception_confirm
```

Ante `ex_fault_confirm`, se registra `terminal_kind.next=FAULT`, `fault_pc=ID/EX.pc` y la causa EX, y **la causante no entra válida a EX/MEM**. Ante `halt_confirm`, se registra `terminal_kind.next=HALT` y el propio `halt` tampoco entra válido a EX/MEM. Ante `redirect_apply`, PC captura `redirect_target`, la instrucción de control **sí** puede avanzar válida a EX/MEM y el trabajo joven secuencial se descarta. Si ID confirma una ilegal o un candidato de fetch transportado, registra `terminal_kind.next=FAULT`, causa/PC de IF/ID y no ingresa válida la causante a ID/EX; cualquier candidato joven en IF se descarta.

La excepción IF requiere el `load-use` ya detectado **entre load y consumidor anteriores supervivientes** y ausencia de frontera EX/ID; registra `terminal_kind.next=FAULT`, causa candidata de IF y `fault_pc=PC` del fetch actual. Conserva íntegros los cinco campos del consumidor anterior en IF/ID, inserta bubble en ID/EX, deja avanzar el load y no captura al fetch causante. Sin la excepción, la ruta ordinaria de un candidato de IF **no confirma inmediatamente**: si el avance normal lo permite, IF/ID captura `valid=0`, `fetch_fault_valid=1`, `fetch_fault_cause=if_fetch_fault_cause` y `pc=PC` para resolverlo posteriormente en ID.

Los metadatos globales se eligen estructuralmente por la ruta confirmada y **solo** se capturan si `fault_confirm=1`:

```text
if (ex_fault_confirm):
    fault_cause_in = ex_fault_cause
    fault_pc_in    = ID/EX.pc
else if (id_fault_confirm):
    fault_cause_in = id_fault_cause
    fault_pc_in    = IF/ID.pc
else if (if_fault_exception_confirm):
    fault_cause_in = if_fetch_fault_cause
    fault_pc_in    = PC

if (fault_confirm):
    fault_cause ← fault_cause_in
    fault_pc    ← fault_pc_in
    terminal_kind.next ← FAULT
```

Las rutas confirmadas se excluyen por la estructura EX→ID→IF excepcional. `fault_cause`/`fault_pc` permanecen estables durante `FAULT_DRAIN` y `FAULT`, incluso mientras avanzan instrucciones anteriores; no se reescriben por candidatos jóvenes ni por salidas combinacionales durante HOLD. Estas ecuaciones **cierran detección y confirmación/aplicación de eventos arquitectónicos** preservando los cuatro latches, la tabla preflanco del trigésimo primer acuerdo, los códigos de causa del trigésimo quinto, `terminal_kind` del trigésimo sexto y el detector del trigésimo noveno. El cuadragésimo primer acuerdo fija después la selección combinacional del `Pipeline Hazard Control`, incluida la aplicación del stall; siguen pendientes la generación RTL de `cpu_cycle_fire`, el control global de ciclo y las coincidencias aún no cubiertas; el cuadragésimo segundo acuerdo fija después los enables/flush y próximos estados de PC y latches para las nueve acciones, pues estas señales de confirmación por sí solas no constituían todas sus ecuaciones secuenciales.

#### Acuerdo parcial aprobado — arbitraje RTL unificado del Pipeline Hazard Control

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

**Revisión de representación por el acuerdo 44:** `terminal_none`, `terminal_active` y `drain_active` son predicados combinacionales derivados de `global_state` y los cuatro `valid`; las ecuaciones siguientes mantienen su significado sin exigir `terminal_kind` ni `drain_auto` registrados. Los nueve `act_*` y su cobertura/exclusión no cambian.

Se fija un único **`Pipeline Hazard Control` combinacional** que selecciona una sola acción microarquitectónica aplicable por ciclo CPU efectivo. Recibe conceptualmente `cpu_cycle_fire`, `terminal_kind[1:0]`, `pipeline_empty`, `ex_fault_candidate`, `ex_halt_candidate`, `redirect_requested`, `id_fault_candidate`, `if_fetch_fault_candidate` y `load_use_stall`, ya definidos en los acuerdos anteriores. No es una FSM, no registra estado ni añade campos a los cuatro latches. `drain_auto` **no participa** en el arbitraje: solo interviene en el control global que autoriza un futuro `cpu_cycle_fire`. Una vez autorizado ese ciclo, el bloque escoge su transición interna según la antigüedad de las instrucciones supervivientes.

```text
terminal_none   = (terminal_kind == NONE)
terminal_active = (terminal_kind != NONE)
drain_active    = terminal_active && !pipeline_empty
```

Si `terminal_active && pipeline_empty`, ya se alcanzó `FINISHED` o `FAULT` y no queda trabajo de pipeline. En un ciclo de trabajo aún sin frontera terminal, las confirmaciones y la aplicación de redirect conservan literalmente las compuertas aprobadas en el cuadragésimo acuerdo:

```text
ex_fault_confirm =
    cpu_cycle_fire && terminal_none && ex_fault_candidate

halt_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_fault_candidate && ex_halt_candidate

redirect_apply =
    cpu_cycle_fire && terminal_none
    && !ex_fault_candidate && !ex_halt_candidate
    && redirect_requested

ex_frontier_selected =
    ex_fault_confirm || halt_confirm || redirect_apply

id_fault_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_frontier_selected && id_fault_candidate

if_fault_exception_confirm =
    cpu_cycle_fire && terminal_none
    && !ex_frontier_selected && !id_fault_candidate
    && load_use_stall && if_fetch_fault_candidate
```

El orden interno **fault EX → `halt` EX → redirect EX** suprime los efectos normales de una instrucción con fault propio antes de considerar sus otros eventos. Entre **instrucciones distintas** sigue venciendo la más antigua EX→ID→IF excepcional: un redirect EX descarta una ilegal joven en ID y un candidato de IF; sin frontera EX, el fault ID prevalece sobre IF. `ex_frontier` del cuadragésimo acuerdo era la disyunción combinacional *sin* habilitación de ciclo; `ex_frontier_selected` es su versión confirmada/aplicada: cuando `cpu_cycle_fire && terminal_none`, ambas condiciones tienen el mismo valor y `!ex_frontier_selected` equivale a `!ex_frontier` en las confirmaciones ID/IF. Fuera de un ciclo autorizado ninguna de ellas habilita captura; las nuevas ecuaciones conservan sin contradicción las condiciones de confirmación ya aprobadas.

El detector `load_use_stall` no retiene directamente al consumidor. Solo se aplica en ausencia de fronteras prevalecientes, una vez descartado el trabajo más joven:

```text
load_use_apply =
    cpu_cycle_fire && terminal_none
    && !ex_frontier_selected && !id_fault_confirm
    && !if_fault_exception_confirm && load_use_stall

normal_advance =
    cpu_cycle_fire && terminal_none
    && !ex_frontier_selected && !id_fault_confirm
    && !if_fault_exception_confirm && !load_use_apply
```

Un candidato de fetch **ordinario** en IF no constituye por sí mismo frontera confirmada: si no hay excepción de confirmación en IF ni otra frontera o stall aplicable, `normal_advance=1` y el candidato se captura en IF/ID (`valid=0, fetch_fault_valid=1`) para resolverlo después en ID. En cambio, en la excepción IF se confirma el fault de fetch sin sobrescribir al consumidor anterior retenido en IF/ID; el load avanza según la transición preflanco ya aprobada. Ante fault propio del load EX, el consumidor joven se descarta y no se aplica el stall por esa dependencia.

Con `terminal_kind!=NONE` no se confirman nuevos faults, `halt` ni redirects del trabajo descartado. El drenado de las instrucciones **anteriores supervivientes** usa el mismo detector y puede incluir stall; no significa flush global:

```text
drain_cycle = cpu_cycle_fire && drain_active

drain_load_use = drain_cycle && load_use_stall
drain_advance  = drain_cycle && !load_use_stall
```

Se exponen conceptualmente **nueve acciones combinacionales**, sin registro de estado ni codificación de FSM adicional:

```text
act_ex_fault           = ex_fault_confirm
act_halt               = halt_confirm
act_redirect           = redirect_apply
act_id_fault           = id_fault_confirm
act_if_fault_exception = if_fault_exception_confirm
act_load_use           = load_use_apply
act_normal             = normal_advance
act_drain_load_use     = drain_load_use
act_drain_advance      = drain_advance
```

El bloque verifica la exclusión y cobertura del ciclo procesable:

```text
$onehot0({
    act_ex_fault,
    act_halt,
    act_redirect,
    act_id_fault,
    act_if_fault_exception,
    act_load_use,
    act_normal,
    act_drain_load_use,
    act_drain_advance
})

cpu_cycle_fire && (terminal_none || drain_active)
→ exactamente una acción seleccionada

!cpu_cycle_fire
→ ninguna acción produce transición secuencial

terminal_active && pipeline_empty
→ ninguna acción de pipeline

terminal_active
→ !ex_fault_confirm && !halt_confirm && !redirect_apply
  && !id_fault_confirm && !if_fault_exception_confirm
```

En un ciclo efectivo con `terminal_none`, exactamente una de las **siete** primeras acciones se selecciona; en un ciclo efectivo con `drain_active`, exactamente una de las **dos** acciones de drenado se selecciona. Si no hay autorización de ciclo, no se confirma ningún evento ni progresa el pipeline. Las acciones del bloque son la realización RTL del arbitraje semántico ya aprobado, **no** una prioridad universal nueva por tipo de evento. El trigésimo primer acuerdo mantiene las acciones preflanco de PC, IF/ID, ID/EX, EX/MEM y MEM/WB como contrato; el cuadragésimo segundo acuerdo deriva después de estas acciones los enables, invalidaciones y valores `next` RTL exactos para ese contrato. El cuadragésimo cuarto acuerdo fija después la generación de `cpu_cycle_fire` y los 14 estados del control global; las coincidencias no cubiertas continúan pendientes; el bloque no introduce un bypass, stall, latch ni registro nuevo.

#### Acuerdo parcial aprobado — ecuaciones exactas de actualización de PC y registros de pipeline

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se fijan las ecuaciones RTL de próximo estado para PC y los cuatro latches a partir de las nueve acciones **mutuamente excluyentes** del cuadragésimo primer acuerdo. Toda captura lee entradas **previas al flanco**, preservando la tabla semántica del trigésimo primer acuerdo. Las acciones constituyen la única fuente de actualización **normal del pipeline**; reset global y LOAD aceptado/preparación conservan su mayor prioridad conforme a `DEC-ARCH-008`. Se define:

```text
pipeline_action =
    act_ex_fault || act_halt || act_redirect
    || act_id_fault || act_if_fault_exception
    || act_load_use || act_normal
    || act_drain_load_use || act_drain_advance
```

Con `pipeline_action=0` y sin reset/LOAD/preparación, PC, IF/ID, ID/EX, EX/MEM y MEM/WB **retienen íntegramente su contenido**: un clock físico de HOLD no desplaza instrucciones ni inserta bubbles. También ocurre si ya se llegó a `FINISHED` o `FAULT` con el pipeline vacío. El control del PC queda:

```text
pc_write_enable = act_normal || act_redirect
next_pc_sel     = act_redirect

act_normal   → PC.next = PC + 4              // next_pc_sel=0: PC_PLUS_4
act_redirect → PC.next = redirect_target    // next_pc_sel=1: REDIRECT_TARGET
resto        → PC.next = PC                  // pc_write_enable=0
```

`next_pc_sel` puede valer físicamente cero durante retención sin obligar a capturar el camino secuencial; el PC no recibe una tercera entrada de mux. IF/ID distingue **captura de IF**, **retención** e **invalidación**:

```text
ifid_capture_if = act_normal

ifid_hold =
    act_load_use || act_if_fault_exception || act_drain_load_use

ifid_invalidate =
    act_redirect || act_halt || act_ex_fault
    || act_id_fault || act_drain_advance
```

Cuando `ifid_capture_if=1` y **no** hay candidato de fault en IF, se captura una instrucción normal; si hay candidato ordinario, se transporta sin hacerla válida:

```text
if (act_normal && !if_fetch_fault_candidate):
    IF/ID.next.valid             = 1
    IF/ID.next.pc                = PC
    IF/ID.next.instruction       = if_instruction
    IF/ID.next.fetch_fault_valid = 0
    IF/ID.next.fetch_fault_cause = 3'b000

if (act_normal && if_fetch_fault_candidate):
    IF/ID.next.valid             = 0
    IF/ID.next.pc                = PC
    IF/ID.next.instruction       = 32'b0
    IF/ID.next.fetch_fault_valid = 1
    IF/ID.next.fetch_fault_cause = if_fetch_fault_cause
```

El código `3'b000` cuando `fetch_fault_valid=0` es **determinista pero no indica un fault**; tampoco los ceros de la word candidata representan una instrucción válida. Con `ifid_hold=1` se conservan bit a bit los **cinco** campos (`valid`, `pc`, `instruction`, `fetch_fault_valid`, `fetch_fault_cause`), ya sea por `load-use` nominal, confirmación IF excepcional o `load-use` durante drenado. Con `ifid_invalidate=1` se exige `IF/ID.next.valid=0` **y** `IF/ID.next.fetch_fault_valid=0`; `pc`, `instruction` y `fetch_fault_cause` pueden conservar bits residuales o escribirse determinísticamente como `32'b0`, `32'b0` y `3'b000` respectivamente. Ninguna de estas alternativas admite candidatos o instrucciones por residuos.

ID/EX recibe una instrucción desde ID únicamente en avance normal o en avance de drenado; en los demás ciclos procesables recibe una **bubble**:

```text
idex_capture_id = act_normal || act_drain_advance

idex_bubble =
    act_load_use || act_redirect || act_halt || act_ex_fault
    || act_id_fault || act_if_fault_exception || act_drain_load_use

if (idex_capture_id):
    ID/EX.next.valid       = IF/ID.valid
    ID/EX.next.pc          = IF/ID.pc
    ID/EX.next.instruction = IF/ID.instruction

    ID/EX.next.rs1         = IF/ID.instruction[19:15]
    ID/EX.next.rs2         = IF/ID.instruction[24:20]
    ID/EX.next.rd          = IF/ID.instruction[11:7]

    ID/EX.next.rs1_value   = id_rs1_value_after_wb_bypass
    ID/EX.next.rs2_value   = id_rs2_value_after_wb_bypass
    ID/EX.next.immediate   = immediate

    ID/EX.next.alu_op      = decoded_alu_op
    ID/EX.next.alu_src     = decoded_alu_src
    ID/EX.next.result_sel  = decoded_result_sel
    ID/EX.next.flow_op     = decoded_flow_op
    ID/EX.next.mem_op      = decoded_mem_op
    ID/EX.next.reg_write   = decoded_reg_write

if (idex_bubble):
    ID/EX.next.valid       = 0
```

Los valores base son los posteriores al bypass **WB→ID** ya aprobado, no los datos crudos del almacenamiento; los demás campos de una bubble pueden quedar residuales sin NOP física. En `act_normal`, un candidato IF/ID con `valid=0` solo puede propagar invalidez si aún no fue confirmado ni descartado; en `act_drain_advance`, cualquier IF/ID válida es una instrucción **anterior superviviente**. En ese mismo flanco `IF/ID.next` queda inválido y `ID/EX.next` recibe el IF/ID **previo**, sin duplicarlo ni admitir un fetch nuevo. En `act_drain_load_use`, en cambio, IF/ID conserva íntegro al consumidor e ID/EX recibe bubble.

EX/MEM captura EX en todas las acciones salvo el fault propio EX y `halt` confirmado, que consumen a la causante sin ingresarla válida a MEM:

```text
exmem_capture_ex =
    act_normal || act_load_use || act_redirect
    || act_id_fault || act_if_fault_exception
    || act_drain_load_use || act_drain_advance

exmem_invalidate = act_halt || act_ex_fault

if (exmem_capture_ex):
    EX/MEM.next.valid       = ID/EX.valid
    EX/MEM.next.pc          = ID/EX.pc
    EX/MEM.next.instruction = ID/EX.instruction
    EX/MEM.next.rd          = ID/EX.rd
    EX/MEM.next.reg_write   = ID/EX.reg_write
    EX/MEM.next.mem_op      = ID/EX.mem_op
    EX/MEM.next.ex_result   = ex_result
    EX/MEM.next.store_data  = rs2_effective

if (exmem_invalidate):
    EX/MEM.next.valid       = 0

result_sel == ALU       → ex_result = alu_result
result_sel == IMMEDIATE → ex_result = ID/EX.immediate
result_sel == LINK      → ex_result = link_value
```

Durante `act_redirect` **continúa válida** hacia EX/MEM la instrucción de control de EX; ante `act_id_fault` continúa la instrucción EX anterior a la causante ID; ante `act_if_fault_exception` el load anterior de ID/EX entra en EX/MEM. Las entradas nuevas invalidadas no reactivan un store, enlace o writeback por datos residuales. MEM/WB avanza desde la **entrada previa de EX/MEM** en cualquiera de las nueve acciones:

```text
memwb_capture_mem = pipeline_action

if (memwb_capture_mem):
    MEM/WB.next.valid       = EX/MEM.valid
    MEM/WB.next.pc          = EX/MEM.pc
    MEM/WB.next.instruction = EX/MEM.instruction
    MEM/WB.next.rd          = EX/MEM.rd
    MEM/WB.next.reg_write   = EX/MEM.reg_write
    MEM/WB.next.wb_value    = wb_value

wb_value = is_load(EX/MEM.mem_op) ? load_value : EX/MEM.ex_result
```

Una frontera confirmada en EX, ID o IF no invalida retrospectivamente el store anterior que ya estaba en EX/MEM ni el writeback anterior en MEM/WB; ambos conservan su elegibilidad por validez y ciclo efectivo. El `wb_value` recién capturado en MEM/WB no se utiliza como si hubiera estado allí antes del flanco.

| Acción | PC | IF/ID | ID/EX | EX/MEM | MEM/WB |
|---|---|---|---|---|---|
| `act_normal` | `PC + 4` | Capture IF | Capture ID | Capture EX | Capture MEM |
| `act_load_use` | HOLD | HOLD | Bubble | Capture EX | Capture MEM |
| `act_redirect` | `redirect_target` | Invalidate | Bubble | Capture EX | Capture MEM |
| `act_halt` | HOLD | Invalidate | Bubble | Invalidate | Capture MEM |
| `act_ex_fault` | HOLD | Invalidate | Bubble | Invalidate | Capture MEM |
| `act_id_fault` | HOLD | Invalidate | Bubble | Capture EX | Capture MEM |
| `act_if_fault_exception` | HOLD | HOLD | Bubble | Capture EX | Capture MEM |
| `act_drain_load_use` | HOLD | HOLD | Bubble | Capture EX | Capture MEM |
| `act_drain_advance` | HOLD | Invalidate | Capture ID | Capture EX | Capture MEM |

Esta tabla es la realización RTL exacta de la tabla semántica del trigésimo primer acuerdo. Ante `act_drain_advance` **no se admite IF nuevo**: la superviviente de IF/ID pasa a ID/EX mientras IF/ID invalida tanto `valid` como `fetch_fault_valid`; ante `act_drain_load_use`, el load de EX avanza, el consumidor anterior permanece en IF/ID y posteriormente puede pasar a ID/EX sin pérdida. `pipeline_action=0` conserva los cinco registros completos en HOLD, espera entre STEP o estado terminal vacío, mientras reset/LOAD tienen precedencia. Los controles de captura/invalidez son combinacionales y se derivan de las acciones, sin crear registros o campos nuevos. Este cuadragésimo segundo acuerdo **cierra las ecuaciones de actualización del PC y los cuatro latches para las acciones pactadas**; el cuadragésimo cuarto acuerdo fija después la generación de `cpu_cycle_fire` y el control global de sesión; el cuadragésimo tercero fija antes el gating de efectos de memoria/RegFile sujetos a validez. La integración con coincidencias no cubiertas y la representación externa Debug siguen sus decisiones correspondientes.

#### Acuerdo parcial aprobado — gating definitivo de efectos arquitectónicos

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

**Revisión de representación por el acuerdo 44:** las ecuaciones de escritura de `terminal_kind` y `drain_auto` más abajo quedan sustituidas por transiciones de `global_state`. `terminal_write_enable`/`drain_auto_write_enable` dejan de ser enables de registros; solo `fault_confirm`/`halt_confirm` determinan la transición y `fault_capture_fire` sigue habilitando el par de metadatos. `cycle_from_continuous` pasa a ser la indicación combinacional de origen que selecciona el estado de drenado AUTO/STEP; el resto del gating de efectos CPU sigue vigente.

Se fijan las condiciones RTL de habilitación de los efectos arquitectónicos y globales originados por CPU. Cada efecto normal requiere un **ciclo CPU efectivo**, la **validez de su entrada de pipeline** y el **control local** que le corresponde. Todas las escrituras de etapa utilizan los campos **previos al flanco**. Una frontera confirmada en una instrucción más joven no cancela los efectos válidos de instrucciones anteriores; la causante y el trabajo descartado no alcanzan válidamente la etapa donde podrían comprometerlos.

La escritura del Register File y la elegibilidad del bypass interno WB→ID comparten la misma condición aprobada en `DEC-ARCH-007`:

```text
rf_write_fire =
    cpu_cycle_fire
    && MEM/WB.valid
    && MEM/WB.reg_write
    && (MEM/WB.rd != 5'd0)

if (rf_write_fire):
    RF[MEM/WB.rd] ← MEM/WB.wb_value

wb_write_enable = rf_write_fire
bypass_rs1 = rf_write_fire && (MEM/WB.rd == id_rs1)
bypass_rs2 = rf_write_fire && (MEM/WB.rd == id_rs2)
```

Cada puerto selecciona independientemente `MEM/WB.wb_value` cuando su bypass vale uno o su lectura ordinaria en caso contrario. Las coincidencias de bits durante HOLD, hacia `x0`, desde entradas inválidas o sin `reg_write` no anuncian writeback ni bypass. Un fault, `halt` o redirect detectado en etapas **más jóvenes** no inhibe a la instrucción anterior válida que ya se encontraba en WB.

El store CPU se compromete desde EX/MEM únicamente con validez, ciclo y tipo de operación:

```text
dmem_store_fire =
    cpu_cycle_fire
    && EX/MEM.valid
    && is_store(EX/MEM.mem_op)

if (dmem_store_fire):
    address = EX/MEM.ex_result
    data    = EX/MEM.store_data
    byte_enable = lanes seleccionados por EX/MEM.mem_op (SB, SH o SW)

dmem_metadata_write_fire = dmem_store_fire
```

El store modifica **atómicamente** el dato y la metadata de cada byte seleccionado, conservando ambos para los bytes no seleccionados. En la implementación de referencia se actualizan juntos `data[byte]` y `valid[byte]`; un perfil físico equivalente conserva la misma semántica. No se vuelven a efectuar en MEM las comprobaciones arquitectónicas de alineación y rango realizadas en EX. Un store causante de fault propio nunca entra válido a EX/MEM, por lo que no activa ningún byte de DMEM ni su metadata. Un store anterior ya presente en MEM puede comprometerse en el mismo ciclo en que una instrucción más joven confirma fault o `halt`.

Si una implementación requiere habilitación **física** de lectura de DMEM, puede definir:

```text
dmem_load_access =
    cpu_cycle_fire
    && EX/MEM.valid
    && is_load(EX/MEM.mem_op)
```

La lectura combinacional puede existir sin commit arquitectónico; el load produce efecto arquitectónico después, si su resultado alcanza válido MEM/WB y se cumple `rf_write_fire`. Ninguna lectura de datos residuales escribe por sí sola el banco.

Solo la aplicación confirmada puede producir un redirect arquitectónico; se conservan exactamente las dos entradas del Next-PC MUX y el enable aprobados en el cuadragésimo segundo acuerdo:

```text
redirect_commit = redirect_apply
pc_write_enable = act_normal || act_redirect
next_pc_sel     = act_redirect
```

Un `redirect_target` puramente combinacional no altera el PC. `jal` y `jalr` válidos transportan `ex_result=link_value` y `reg_write=1` por EX/MEM y MEM/WB y escriben el enlace **solo** mediante `rf_write_fire`, sin enable arquitectónico adicional. Si su propia instrucción confirma fault en EX, no entra válida a EX/MEM y no puede aplicar redirect ni escribir enlace más adelante.

La captura persistente de un fault y la confirmación de `halt` se gobiernan exclusivamente por las confirmaciones ya arbitradas, equivalentes a sus acciones:

```text
fault_capture_fire = fault_confirm
                   = act_ex_fault || act_id_fault || act_if_fault_exception

halt_commit = halt_confirm = act_halt

if (fault_capture_fire):
    fault_cause.next = fault_cause_in
    fault_pc.next    = fault_pc_in
else:
    fault_cause.next = fault_cause
    fault_pc.next    = fault_pc
```

Los candidatos descartados, `wrong-path`, entradas inválidas y evaluaciones durante HOLD no modifican el par global de causa/PC; la candidatura de `halt` en ID tampoco confirma el estado terminal. Se consolida:

```text
terminal_write_enable = fault_confirm || halt_confirm

if (fault_confirm):
    terminal_kind.next = FAULT
else if (halt_confirm):
    terminal_kind.next = HALT
else:
    terminal_kind.next = terminal_kind

drain_auto_write_enable = terminal_write_enable

if (terminal_write_enable):
    drain_auto.next = cycle_from_continuous
else:
    drain_auto.next = drain_auto
```

`fault_confirm` y `halt_confirm` son mutuamente excluyentes. El control global proporciona `cycle_from_continuous=1` si **el ciclo confirmante** fue autorizado en contexto continuo, o `0` si provino de STEP aceptado; el bit capturado permanece estable durante el drenado y **no** genera por sí solo un futuro ciclo. Esta procedencia no impone codificación ni FSM para el control global.

El contador lógico usa una habilitación distinta de los commits de instrucciones:

```text
cycle_counter_increment = cpu_cycle_fire
```

Incrementa **exactamente una vez por ciclo CPU efectivo**, incluidos avance normal, stall `load-use`, redirect, confirmación de fault/`halt` y drenado; no incrementa durante HOLD. No se lo habilita por un dato combinacional ni por una acción local que retenga PC. El cuadragésimo cuarto acuerdo fija después la generación global de `cpu_cycle_fire` e impide autorizar ciclos adicionales una vez vacío un pipeline terminal, sin agregar un ciclo final vacío.

En síntesis: WB requiere `MEM/WB.valid` y `reg_write` para escribir; MEM requiere `EX/MEM.valid` e `is_store` para almacenar; los eventos EX requieren `ID/EX.valid` en sus candidatos, y ID interpreta una instrucción únicamente con `IF/ID.valid` o un candidato de fetch transportado mediante `IF/ID.fetch_fault_valid`. En todos los casos, la confirmación/commit exige el **ciclo efectivo** y los controles locales ya fijados. Bits residuales de etapas inválidas no crean efectos.

Estas son ecuaciones de **efectos normales del CPU**, subordinadas a la prioridad global de `DEC-ARCH-008`:

```text
RESET > LOAD aceptado / preparación > ciclo CPU efectivo > HOLD
```

Si reset o LOAD/preparación dominan el flanco, no se comprometen writeback, store, metadata, captura de fault, confirmación de `halt` ni incremento del contador de la ejecución CPU previa, aunque las candidaturas combinacionales existan. Reset y LOAD conservan sus propios efectos de inicialización y ownership independientes. Este cuadragésimo tercer acuerdo cierra el **gating de efectos CPU** sin decidir la generación global de `cpu_cycle_fire`, las coincidencias adicionales no cubiertas o la representación Debug/UART.

#### Acuerdo parcial aprobado — FSM global de ejecución y autorización de ciclos

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se fija una **FSM Moore explícita de 14 estados** para el ciclo de vida global de la sesión. La FSM registra únicamente `global_state`, calcula `next_state` desde eventos aceptados y emite modos derivados del estado actual; **no** escribe PC, RF, IMEM, DMEM, pipeline o contador ni genera directamente `cpu_cycle_fire`. El `Command Arbiter` acepta comandos bajo RESET > LOAD > STEP > RUN; `Cycle Authorization`, Loader, Session Preparation y el datapath efectúan las acciones. Esta subdecisión **revisa explícitamente la representación física** de los acuerdos 36 y 40–43: `terminal_kind[1:0]` y `drain_auto` dejan de ser registros globales, así como sus ecuaciones de escritura del acuerdo 43. Permanecen las fronteras semánticas, las confirmaciones, las nueve acciones, el gating de RF/DMEM/metadata/fault y la regla `cycle_counter_increment=cpu_cycle_fire`. Las ecuaciones anteriores que leen `terminal_kind`/`drain_auto` se reinterpretan mediante predicados **combinacionales** del estado, nunca como una segunda fuente registrada de verdad.

| Estado | Semántica |
|---|---|
| `NO_IMAGE` | No existe imagen ejecutable. |
| `LOADING` | Recepción y validación de nueva imagen. |
| `PREPARING_READY` | Preparación de nueva imagen para quedar detenida; todavía no hay commit de sesión. |
| `PREPARING_RUN` | Preparación de una sesión nueva con imagen ya confirmada, solicitada por RUN terminal. |
| `PREPARING_STEP` | Preparación de una sesión nueva con imagen ya confirmada, conservando **un STEP aceptado pendiente**. |
| `READY` | Imagen y sesión inicial confirmadas, ejecución aún no iniciada. |
| `RUNNING` | Ejecución continua normal. |
| `STEPPING` | Ejecución paso a paso entre autorizaciones. |
| `HALT_DRAIN_AUTO` / `HALT_DRAIN_STEP` | Drenado de anteriores tras `halt` confirmado, automático o por STEP. |
| `FAULT_DRAIN_AUTO` / `FAULT_DRAIN_STEP` | Drenado de anteriores tras fault confirmado, automático o por STEP. |
| `FINISHED` | Terminación normal con pipeline vacío. |
| `FAULT` | Terminación excepcional con pipeline vacío. |

La FSM recibe conceptualmente `reset`, `load_accept`, `run_accept`, `step_accept` del arbitraje de comandos; `load_ok`, `load_fail` del Loader; `prepare_done` de Session Preparation; `halt_confirm`, `fault_confirm` del pipeline; y `pipeline_empty_next` de los `valid_next` combinacionales de los cuatro latches. `load_ok` y `load_fail` se excluyen. RESET domina desde **cualquier** estado y lleva a `NO_IMAGE`; un LOAD aceptado domina cualquier ciclo CPU en estados que lo admiten. LOAD es elegible desde `NO_IMAGE`, `READY`, `STEPPING`, ambos drenados STEP, `FINISHED` y `FAULT`; **no** se acepta durante RUNNING o drenado automático. LOAD aceptado desde paso a paso/drenado interrumpe la sesión previa bajo la prioridad de `DEC-ARCH-008` sin comprometer efectos CPU de ese flanco. Solicitudes rechazadas no cambian estado ni suprimen el ciclo continuo.

Se precisan las fases de preparación sin cambiar la prioridad global. `prepare_done=1` significa **antes del flanco** que todos los valores de estado inicial (PC, RF, cero lógico de DMEM, pipeline y contador) ya quedaron coherentemente preparados en flancos anteriores, y que **no hay escrituras de Loader ni mantenimiento en ese flanco**. Aunque `prepare_active` refleje el estado Moore previo al flanco, `PREPARING_RUN/STEP && prepare_done` es un flanco de **ciclo CPU**, no de acciones efectivas de preparación: el primer ciclo usa ese estado inicial preflanco, consume el RUN o STEP pendiente y deja `cycle_count=1`. Con `prepare_done=0` no hay ciclo. `PREPARING_READY && prepare_done` hace el commit completo de sesión e imagen **sin** ciclo CPU y llega a `READY`. En particular, `load_ok` solo indica imagen recibida/validada y su tamaño queda privado del Loader; no publica aún `loaded_image_size_bytes`. El único write no nulo de ese tamaño sucede en el commit de `PREPARING_READY`, una vez preparada íntegramente la sesión. `PREPARING_RUN/STEP` reutilizan la imagen confirmada y no escriben su tamaño. Así se conserva RESET > LOAD aceptado/preparación **efectiva** > ciclo CPU > HOLD, y una imagen parcial nunca es ejecutable.

Las transiciones (además de reset universal y LOAD aceptado desde los estados elegibles) quedan:

| Estado previo | Condición preflanco / evento | Estado siguiente |
|---|---|---|
| `NO_IMAGE` | `load_accept` | `LOADING` |
| `NO_IMAGE` | sin aceptación | `NO_IMAGE` |
| `LOADING` | `load_ok` | `PREPARING_READY` |
| `LOADING` | `load_fail` | `NO_IMAGE` |
| `LOADING` | en curso | `LOADING` |
| `PREPARING_READY` | `prepare_done` | `READY` (commit completo, sin CPU) |
| `PREPARING_READY` | en curso | `PREPARING_READY` |
| `READY` | `load_accept` | `LOADING` |
| `READY` | `step_accept` / `run_accept` | Resultado de **un** ciclo STEP / continuo en ese flanco |
| `READY` | sin aceptación | `READY` |
| `STEPPING` | `load_accept` | `LOADING` |
| `STEPPING` | `step_accept` / `run_accept` | Resultado de **un** ciclo STEP / continuo en ese flanco |
| `STEPPING` | sin aceptación | `STEPPING` |
| `RUNNING` | ciclo continuo | Resultado de **un** ciclo continuo en ese flanco |
| `HALT_DRAIN_AUTO` / `FAULT_DRAIN_AUTO` | ciclo automático | Drenado del mismo tipo o su estado final |
| `HALT_DRAIN_STEP` / `FAULT_DRAIN_STEP` | `load_accept` | `LOADING` |
| `HALT_DRAIN_STEP` / `FAULT_DRAIN_STEP` | `step_accept` / `run_accept` | Drenado STEP / AUTO del mismo tipo o su estado final |
| `HALT_DRAIN_STEP` / `FAULT_DRAIN_STEP` | sin aceptación | Retener estado |
| `FINISHED` / `FAULT` | `load_accept` | `LOADING` |
| `FINISHED` / `FAULT` | `step_accept` / `run_accept` | `PREPARING_STEP` / `PREPARING_RUN` |
| `FINISHED` / `FAULT` | sin aceptación | Retener estado |
| `PREPARING_RUN` / `PREPARING_STEP` | `prepare_done` | Resultado de **un** ciclo continuo / STEP en ese flanco |
| `PREPARING_RUN` / `PREPARING_STEP` | en curso | Retener estado |

Para cualquier fila «resultado de un ciclo», se aplica `fault_confirm` primero (FAULT si `pipeline_empty_next`, si no `FAULT_DRAIN_AUTO/STEP`), luego `halt_confirm` (FINISHED si `pipeline_empty_next`, si no `HALT_DRAIN_AUTO/STEP`), y sin frontera terminal RUNNING o STEPPING según el **origen del ciclo**. Para ciclos de drenado ya terminales no se confirma otra frontera: `pipeline_empty_next` elige FINISHED/FAULT o conserva el drenado de su clase y origen; RUN aceptado durante drenado STEP lo convierte en AUTO si no se vacía. `pipeline_empty_next` se obtiene del próximo estado de latches del acuerdo 42, sin evaluar salidas de la FSM siguiente ni crear un lazo; por ello FINISHED/FAULT surge en **el mismo flanco** que vacía el último `valid`, sin ciclo de drenado vacío. RUN/STEP en FINISHED/FAULT inician una sesión **nueva y limpia** con la imagen confirmada, nunca reanudan el PC/pipeline terminal anterior; desde FAULT constituyen una vía de recuperación adicional expresamente aprobada, sin eliminar reset global como vía mínima obligatoria.

Las salidas Moore, exclusivamente función de `global_state` actual, son:

```text
loader_active     = state == LOADING
prepare_active    = state in {PREPARING_READY, PREPARING_RUN, PREPARING_STEP}
continuous_mode   = state in {RUNNING, HALT_DRAIN_AUTO, FAULT_DRAIN_AUTO}
step_mode         = state in {STEPPING, HALT_DRAIN_STEP, FAULT_DRAIN_STEP}
drain_mode        = state in {HALT_DRAIN_AUTO, HALT_DRAIN_STEP,
                              FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP}
halt_drain_active = state in {HALT_DRAIN_AUTO, HALT_DRAIN_STEP}
fault_drain_active= state in {FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP}
program_finished = state == FINISHED
fault_active     = fault_drain_active || (state == FAULT)
fault_terminal   = state == FAULT
fault_info_valid = fault_active
```

`prepare_active` anuncia modo, **no** es por sí misma un write-enable ni anula un ciclo válido con `prepare_done=1`. `drain_mode` se distingue de `drain_active` del Hazard Control; sobre estados alcanzables, ambos indican uno de los cuatro estados de drenado **con pipeline aún no vacío**. Los predicados equivalentes a la interfaz de los acuerdos 40–41 son:

```text
terminal_active = state in {HALT_DRAIN_AUTO, HALT_DRAIN_STEP,
                            FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP,
                            FINISHED, FAULT}
terminal_none   = !terminal_active
drain_active    = terminal_active && !pipeline_empty
```

En los cuatro estados DRAIN alcanzables `pipeline_empty=0`; en FINISHED/FAULT vale uno. El antiguo `terminal_kind` puede leerse **solo como alias combinacional** NONE en estados no terminales, HALT en HALT_DRAIN_*/FINISHED y FAULT en FAULT_DRAIN_*/FAULT, pero no existe su flip-flop ni un enable de escritura. Análogamente el origen automático es una propiedad de los estados `*_AUTO`, no un `drain_auto` registrado: sus viejas ecuaciones `drain_auto_write_enable=terminal_write_enable` y `drain_auto.next=cycle_from_continuous` quedan **sustituidas**, no se implementan junto a la FSM. `terminal_write_enable=fault_confirm||halt_confirm` queda, a lo sumo, como alias de evento combinacional sin registro de destino. `fault_capture_fire=fault_confirm` sí continúa capturando causa/PC globales preflanco.

`Cycle Authorization` separado genera:

```text
automatic_cycle_request = state in {RUNNING, HALT_DRAIN_AUTO, FAULT_DRAIN_AUTO}
command_cycle_request   = (state in {READY, STEPPING, HALT_DRAIN_STEP,
                                     FAULT_DRAIN_STEP}) && (run_accept || step_accept)
prepare_cycle_request   = (state in {PREPARING_RUN, PREPARING_STEP}) && prepare_done
cycle_request           = automatic_cycle_request || command_cycle_request
                          || prepare_cycle_request
cpu_cycle_fire          = !reset && !load_accept && cycle_request
```

Solo estados que pueden ejecutar una sesión **confirmada** solicitan ciclo; `PREPARING_RUN/STEP` reutilizan imagen válida y el contrato reforzado de `prepare_done` garantiza que su primer flanco es ejecutable y sin writes de preparación. Ni un stall, bubble, redirect o flush internos cancelan `cpu_cycle_fire`. `NO_IMAGE`, `LOADING`, `PREPARING_READY`, `FINISHED` y `FAULT` no solicitan ciclos por sí solos. El arbiter solo puede aceptar comandos legales según el estado y excluye STEP/RUN concurrentes por prioridad; un LOAD rechazado no inhibe RUN. El origen del ciclo es combinacional y solo tiene significado cuando `cpu_cycle_fire=1`:

```text
continuous_cycle = automatic_cycle_request
    || ((state in {READY, STEPPING, HALT_DRAIN_STEP, FAULT_DRAIN_STEP})
        && run_accept)
    || ((state == PREPARING_RUN) && prepare_done)
cycle_from_continuous = cpu_cycle_fire && continuous_cycle
```

Los demás ciclos autorizados proceden de STEP aceptado o de `PREPARING_STEP && prepare_done`. El origen continuo/STEP determina la modalidad de drenado tras confirmar frontera, sin agregar otro estado persistente.

```text
pipeline_empty =
    !IF/ID.valid && !ID/EX.valid && !EX/MEM.valid && !MEM/WB.valid
pipeline_empty_next =
    !IF/ID.next.valid && !ID/EX.next.valid
    && !EX/MEM.next.valid && !MEM/WB.next.valid

image_valid = (loaded_image_size_bytes != 0)
cycle_counter_increment = cpu_cycle_fire
```

`fetch_fault_valid` no participa en el vaciado. `loaded_image_size_bytes` es la fuente persistente única de imagen confirmada: reset y LOAD aceptado lo ponen en cero; una carga fallida lo deja allí; solo el commit de `PREPARING_READY` lo establece al tamaño validado, y en cualquier otro caso se retiene. `fault_cause[2:0]` y `fault_pc[31:0]` siguen siendo registros independientes capturados solo con `fault_confirm`; `fault_info_valid` se deriva de los estados fault, sin registro extra y sin interpretación de bits residuales fuera de ellos. `cycle_count` queda en cero **antes** del flanco de `prepare_done` de una nueva sesión y se incrementa a uno si ese flanco emite el primer ciclo CPU. **Revisado por AUD-005:** `cycle_count[63:0]` es unsigned e incrementa módulo `2^64` por `cpu_cycle_fire`, sin fault, cambio de `global_state`, detención ni flag adicional; el formato UART permanece pendiente conforme a la revisión de `DEC-SYS-006` del 2026-09-26.

El Loader y Session Preparation mantienen progreso privado (índices, words parciales, contadores y flags) y notifican `load_ok/load_fail` o `prepare_done`, sin agregar subestados de recepción o clear a la FSM global. Estado global persistente: `global_state`, `fault_cause`, `fault_pc`, `loaded_image_size_bytes` y `cycle_count`, más estado privado de esos módulos; `run_active`, `drain_auto`, `terminal_kind`, `image_valid`, `fault_valid`, `finished`, `fault` y modos de drenado **no** son registros globales independientes. El cuadragésimo quinto acuerdo audita después las coincidencias restantes: en ese momento `DEC-ARCH-003` aún esperaba su matriz final de verificación/cierre; el formato externo Debug/UART continúa en sus decisiones respectivas.

#### Acuerdo parcial aprobado — auditoría de coincidencias e integración global

> **Revisado por el acuerdo 47 (2026-09-26).** Este cuerpo conserva la redacción histórica. Sus referencias a confirmación de fetch en IF, a una acción adicional por load-use y a los conteos/ecuaciones derivados quedan sustituidas por el acuerdo 47. IF solo detecta y todo fetch fault se confirma en ID; los demás contratos de este acuerdo se conservan.

**Fecha:** 2026-09-25

Se auditan las **coincidencias funcionales globales e interacciones entre hazards** que permanecían abiertas tras los acuerdos 40–44. La composición de RESET/LOAD/preparación, FSM de 14 estados, `Cycle Authorization`, fronteras por antigüedad, nueve acciones mutuamente excluyentes, actualización de PC/latches y gating de efectos determina unívocamente estos casos. La auditoría **no añade** una prioridad general, estado, acción, selector, stall, bypass o campo de pipeline, ni altera las ecuaciones aprobadas.

| Coincidencia | Política ya fijada que la resuelve |
|---|---|
| RESET, LOAD aceptado, preparación efectiva y ciclo CPU | RESET domina todo; LOAD aceptado y escrituras efectivas de preparación dominan efectos CPU. Un LOAD **rechazado** no interrumpe el ciclo continuo. Entre comandos aceptables rige RESET > LOAD > STEP > RUN. |
| Loader y nueva imagen | `load_ok` valida pero no publica imagen. `PREPARING_READY && prepare_done` publica sesión e imagen coherentes **sin** ciclo CPU; fallo deja tamaño confirmado cero. |
| Reutilización de imagen y primer ciclo | RUN/STEP desde FINISHED o FAULT inician **nueva** sesión por PREPARING_RUN/STEP. Si `prepare_done=1`, estado inicial completo antes del flanco y sin escrituras de mantenimiento concurrentes, ese flanco autoriza el primer ciclo y consume el RUN/STEP pendiente. |
| Ejecución paso a paso y LOAD | LOAD aceptado en STEPPING o drenado STEP domina el flanco, inhibe CPU y abandona la sesión previa. LOAD rechazado en RUNNING o drenado AUTO no inhibe ciclos. |
| Cambio de drenado STEP→AUTO | RUN aceptado durante drenado STEP autoriza el ciclo actual y conserva modalidad AUTO si quedan anteriores; STEP aceptado produce solo un ciclo, incluso con stall. |
| Confirmación terminal y vaciado | `halt_confirm`/`fault_confirm` y `pipeline_empty_next` eligen directamente FINISHED/FAULT cuando el último `valid_next` baja a cero, sin ciclo vacío adicional; con anteriores eligen DRAIN AUTO/STEP según `cycle_from_continuous`. |
| Fronteras EX, ID e IF excepcional | Dentro de la instrucción EX, fault propio precede a `halt` y redirect; entre instrucciones distintas prevalece la más antigua EX→ID→IF excepcional. Redirect/`halt` EX descartan candidatos jóvenes; fault ID permite avanzar la EX anterior. |
| `load-use` y frontera | La frontera anterior prevalece sobre stalls solo de trabajo joven descartado; el stall necesario entre anteriores supervivientes se preserva. Fault IF excepcional con `load-use` retiene íntegro al consumidor IF/ID, inserta bubble y deja avanzar el load anterior sin capturar el fetch causante. |
| Drenado terminal | No se confirman fronteras nuevas ni se admiten fetches; se selecciona `act_drain_load_use` o `act_drain_advance` para anteriores supervivientes, cada una solo en ciclo CPU efectivo. |
| Efectos MEM/WB y cómputo de ciclos | Store MEM y writeback WB anteriores pueden comprometerse en el mismo flanco que confirma una frontera joven; RESET, LOAD aceptado o preparación efectiva los suprimen. `cycle_count` incrementa exactamente una vez por `cpu_cycle_fire`, incluidos stalls, redirects, confirmaciones y drenado. |
| IF y MEM simultáneos | IMEM y DMEM son recursos lógicos independientes; fetch y load/store del mismo ciclo no originan un stall estructural artificial. |

Para cada ciclo **procesable** sin frontera terminal previa, el `Pipeline Hazard Control` selecciona exactamente **una** de las siete acciones `act_ex_fault`, `act_halt`, `act_redirect`, `act_id_fault`, `act_if_fault_exception`, `act_load_use` o `act_normal`. En drenado activo selecciona exactamente una de `act_drain_load_use` o `act_drain_advance`. En todo momento vale `$onehot0` de las nueve; con `cpu_cycle_fire=0` no se aplica ninguna. El acuerdo 42 sigue siendo la **única realización normal** de próximo estado de PC y cuatro latches para esas acciones, siempre desde las entradas previas al flanco. Una frontera confirmada en EX/ID/IF no invalida retrospectivamente una instrucción anterior ya en MEM o WB.

La integración del control global conserva una dependencia combinacional **acíclica**:

```text
global_state actual + comandos aceptados
    → Cycle Authorization → cpu_cycle_fire
    → confirmaciones + única acción de Pipeline Hazard Control
    → PC/latches.next (desde entradas preflanco)
    → pipeline_empty_next (desde los cuatro valid_next)
    → FSM.next_state
```

`FSM.next_state` no realimenta `cpu_cycle_fire` ni las acciones **del mismo ciclo**. `prepare_done` garantiza antes del flanco que la preparación efectiva terminó si autoriza el primer ciclo de PREPARING_RUN/STEP; PREPARING_READY no solicita ciclo. Los estados DRAIN alcanzables contienen trabajo anterior; el paso a FINISHED/FAULT ocurre en el flanco que vacía su último `valid`, sin ciclo final artificial.

El detector `load-use` y la Forwarding Unit mantienen sus ecuaciones. Cada fuente usada selecciona al productor más reciente con dato disponible; un load coincidente y más reciente en EX/MEM sin dato disponible **bloquea** el fallback hacia MEM/WB anterior o hacia la base ID/EX y espera el avance autorizado. `forward_a_sel`, `forward_b_sel`, `result_sel`, `target_sel` y `wb_value_sel` son selectores locales combinacionales: salidas residuales en HOLD, etapas inválidas o trabajo descartado no autorizan captura/commit arquitectónico. Cada efecto CPU sigue necesitando `cpu_cycle_fire`, validez de su etapa y control específico; las reglas particulares de confirmación y prioridades del propio evento siguen vigentes.

El placeholder semántico `ID/EX.control` **no requiere una subdecisión adicional de empaquetado**: las seis categorías `alu_op`, `alu_src`, `result_sel`, `flow_op`, `mem_op` y `reg_write` ya tienen semántica, codificación y transporte por etapas aprobados. Materializarlas como señales separadas, estructura o bundle equivalente es detalle de implementación RTL, sin alterar campos físicos ni efectos. La representación **externa** Debug/UART de estados, controles y latches permanece en `DEC-ARCH-009` y decisiones de protocolo, fuera del cierre de esta política de hazards.

La auditoría no identifica coincidencias funcionales sin política definida. **Quedan resueltas las coincidencias globales y la integración funcional antes declaradas abiertas en `DEC-ARCH-003`.** En esta etapa aún quedaba la matriz final de verificación y acto de cierre del cuadragésimo sexto acuerdo; no se infiere de esta auditoría que ya exista RTL verificado.

#### Acuerdo parcial aprobado — matriz final de verificación y cierre de la política de hazards

**Fecha:** 2026-09-25

**Revisión de vigencia:** matriz revisada por el acuerdo 47 el 2026-09-26; las filas e invariantes siguientes expresan el contrato vigente. La versión original se conserva debajo como historia.

La matriz consolida los acuerdos 1–45 y la revisión explícita del acuerdo 47. **No introduce comportamiento nuevo**: cada fila es un contrato arquitectónico ya fijado y un criterio para verificar después su implementación RTL.

| Área de `DEC-ARCH-003` | Cierre y criterio de verificación |
|---|---|
| Forwarding EX/MEM y MEM/WB → EX; prioridad, disponibilidad y fuentes usadas | Acuerdos 1–3, 9–10, 32 y 38–39: comprobar `rs1`/`rs2` independientemente, productor reciente disponible, `rd!=x0`, fuentes efectivamente usadas y bloqueo de un MEM/WB obsoleto ante load reciente coincidente sin dato. |
| `load-use` y stall entre supervivientes | Acuerdos 2, 4, 18–21, 29–32 y 41–42, revisados por el 47: retener PC/IF/ID, insertar bubble ID/EX, dejar progresar anteriores y aplicar stall solo si productor y consumidor sobreviven a la frontera. |
| Stores, WB→ID y forwarding posterior | Acuerdos 5, 7, 9–10, 23, 25, 32, 39 y 43, con `DEC-ARCH-007`: comprobar dirección en EX, `store_data` transportado por EX/MEM, bypass de WB solo para escritura elegible y prioridad posterior del productor más reciente en EX. |
| Cuatro latches, controles, `Result MUX`, `Target MUX` y `WB Value MUX` | Acuerdos 7, 11–14, 19–25, 29, 33–34, 37–38 y 42: campos/controles necesarios llegan a la etapa consumidora; `valid=0` deja inertes los residuos. Se comprueban selectores, enlace y selección de datos sin imponer empaquetado físico único de `ID/EX.control`. |
| Branches, `jal` y `jalr`; redirect | Acuerdos 6–8, 16–17, 22–27, 30–31 y 40–42: resolución en EX, target y enlace correctos, fault propio antes de redirect y descarte del camino joven al aplicar una redirección válida. |
| `halt`, detección de fetch IF y faults confirmados ID/EX y metadatos | Acuerdos 28–31, 35–36 y 40–44, revisados por el 47: confirmar solo candidatos elegibles del camino correcto, descartar causante de fault y jóvenes, retener PC y conservar `fault_cause`/`fault_pc` mientras drenan anteriores; `halt` no llega válido a EX/MEM. |
| Antigüedad, ocho acciones, enables e invalidaciones | Acuerdos 30–31 y 40–45, revisados por el 47: frontera EX → ID; IF solo detecta y transporta candidatos conforme al acuerdo 47; `act_ex_fault`, `act_halt`, `act_redirect`, `act_id_fault`, `act_load_use`, `act_normal`, `act_drain_load_use` y `act_drain_advance` excluyentes, aplicadas a PC y latches con valores preflanco y sin ciclo adicional de HOLD. |
| Fetch candidato durante load-use | Acuerdo 47: solo act_load_use, sin confirmación ni captura del candidato; PC retenido permite redetectarlo, capturarlo después y resolverlo en ID. Probar consumidor branch/jalr y load/store con fault propio antes del fetch joven. |
| Gating RF/DMEM/fault/contador; `cpu_cycle_fire` | Acuerdos 36, 40 y 42–45, revisados por el 47: ningún efecto CPU sin ciclo, validez y control local; el writeback/store anterior a frontera joven completa una sola vez; el contador incrementa también en stall, redirect, frontera y drenado. |
| FSM de 14 estados, autorización y comandos | Acuerdos 36 y 40–45, con revisión expresa del 44: `global_state` es la fuente registrada de fases terminales AUTO/STEP; RESET > LOAD aceptado > preparación efectiva > ciclo CPU > HOLD, STEP > RUN entre comandos aceptados, solicitud de LOAD rechazada sin inhibir RUN. `PREPARING_READY && prepare_done` solo confirma imagen/sesión; `PREPARING_RUN/STEP && prepare_done` ejecuta primer ciclo solo con preparación preflanco completa. |
| Drenado y terminación | Acuerdos 28–31 y 36, 40–45: anteriores progresan en AUTO o por un STEP aceptado por ciclo; `pipeline_empty_next=1` con confirmación/vaciado final lleva a FINISHED o FAULT en ese flanco sin ciclo vacío. |
| Coincidencias globales e integración | Acuerdo 45: auditar RESET/LOAD/preparación, comandos concurrentes, fronteras/`load-use`, forwarding/selectores durante HOLD y drenado, commits anteriores y fetch IF + acceso MEM simultáneos sobre IMEM/DMEM independientes, sin hazard estructural artificial. |

Los invariantes conjuntos de aceptación son:

```text
cpu_cycle_fire=0                        → sin avance ni efecto CPU de la sesión
cpu_cycle_fire=1 && terminal_none      → exactamente una de seis acciones no terminales
cpu_cycle_fire=1 && drain_active       → exactamente una de dos acciones de drenado
en todo momento                        → $onehot0 de las ocho acciones
frontera con pipeline_empty_next=1     → FINISHED si halt; FAULT si fault
```

Una instrucción válida completa normalmente, causa una frontera (sin efectos propios prohibidos) o es más joven y queda descartada; las anteriores supervivientes conservan efectos elegibles incluso en el flanco de confirmación y durante drenado. `Command Arbiter` selecciona el comando aceptado, `Cycle Authorization` deriva `cpu_cycle_fire`, `Pipeline Hazard Control` escoge una acción y las ecuaciones de PC/latches/datapath efectúan la transición y los commits. La FSM decide sus estados y transiciones a partir de `pipeline_empty_next`, pero no ejecuta directamente acciones del datapath ni realimenta `next_state` hacia la autorización del mismo flanco. `terminal_none` y `drain_active` son predicados derivados del estado actual conforme al acuerdo 44, no registros terminales paralelos.

**Cierre:** no resta política de forwarding, hazard, prioridad, stall, flush, autorización o próximo estado del pipeline por decidir dentro de `DEC-ARCH-003`. El empaquetado de `ID/EX.control` es detalle de implementación RTL; la construcción y verificación física del CPU quedan por realizar y esta matriz no afirma que ya hayan pasado pruebas de hardware. La representación externa del estado y pipeline por Debug/UART permanece en `DEC-ARCH-009` y las decisiones de protocolo. Se **aprueba `DEC-ARCH-003`** con 47 acuerdos; el cierre original de 46 acuerdos queda revisado por el 47, preservando la revisión de representación del acuerdo 44.


<details>
<summary>Historia: versión original del acuerdo 46, sustituida en estos puntos por el acuerdo 47</summary>


**Fecha:** 2026-09-25

La matriz consolida los acuerdos 1–45 y la auditoría de coincidencias del acuerdo 45. **No introduce comportamiento nuevo**: cada fila es un contrato arquitectónico ya fijado y un criterio para verificar después su implementación RTL.

| Área de `DEC-ARCH-003` | Cierre y criterio de verificación |
|---|---|
| Forwarding EX/MEM y MEM/WB → EX; prioridad, disponibilidad y fuentes usadas | Acuerdos 1–3, 9–10, 32 y 38–39: comprobar `rs1`/`rs2` independientemente, productor reciente disponible, `rd!=x0`, fuentes efectivamente usadas y bloqueo de un MEM/WB obsoleto ante load reciente coincidente sin dato. |
| `load-use` y stall entre supervivientes | Acuerdos 2, 4, 18–21, 29–32 y 41–42: retener PC/IF/ID, insertar bubble ID/EX, dejar progresar anteriores y aplicar stall solo si productor y consumidor sobreviven a la frontera. |
| Stores, WB→ID y forwarding posterior | Acuerdos 5, 7, 9–10, 23, 25, 32, 39 y 43, con `DEC-ARCH-007`: comprobar dirección en EX, `store_data` transportado por EX/MEM, bypass de WB solo para escritura elegible y prioridad posterior del productor más reciente en EX. |
| Cuatro latches, controles, `Result MUX`, `Target MUX` y `WB Value MUX` | Acuerdos 7, 11–14, 19–25, 29, 33–34, 37–38 y 42: campos/controles necesarios llegan a la etapa consumidora; `valid=0` deja inertes los residuos. Se comprueban selectores, enlace y selección de datos sin imponer empaquetado físico único de `ID/EX.control`. |
| Branches, `jal` y `jalr`; redirect | Acuerdos 6–8, 16–17, 22–27, 30–31 y 40–42: resolución en EX, target y enlace correctos, fault propio antes de redirect y descarte del camino joven al aplicar una redirección válida. |
| `halt`, faults IF/ID/EX y metadatos | Acuerdos 28–31, 35–36 y 40–44: confirmar solo candidatos elegibles del camino correcto, descartar causante de fault y jóvenes, retener PC y conservar `fault_cause`/`fault_pc` mientras drenan anteriores; `halt` no llega válido a EX/MEM. |
| Antigüedad, nueve acciones, enables e invalidaciones | Acuerdos 30–31 y 40–45: frontera EX → ID → IF excepcional; `act_ex_fault`, `act_halt`, `act_redirect`, `act_id_fault`, `act_if_fault_exception`, `act_load_use`, `act_normal`, `act_drain_load_use` y `act_drain_advance` excluyentes, aplicadas a PC y latches con valores preflanco y sin ciclo adicional de HOLD. |
| Gating RF/DMEM/fault/contador; `cpu_cycle_fire` | Acuerdos 36, 40 y 42–45: ningún efecto CPU sin ciclo, validez y control local; el writeback/store anterior a frontera joven completa una sola vez; el contador incrementa también en stall, redirect, frontera y drenado. |
| FSM de 14 estados, autorización y comandos | Acuerdos 36 y 40–45, con revisión expresa del 44: `global_state` es la fuente registrada de fases terminales AUTO/STEP; RESET > LOAD aceptado > preparación efectiva > ciclo CPU > HOLD, STEP > RUN entre comandos aceptados, solicitud de LOAD rechazada sin inhibir RUN. `PREPARING_READY && prepare_done` solo confirma imagen/sesión; `PREPARING_RUN/STEP && prepare_done` ejecuta primer ciclo solo con preparación preflanco completa. |
| Drenado y terminación | Acuerdos 28–31 y 36, 40–45: anteriores progresan en AUTO o por un STEP aceptado por ciclo; `pipeline_empty_next=1` con confirmación/vaciado final lleva a FINISHED o FAULT en ese flanco sin ciclo vacío. |
| Coincidencias globales e integración | Acuerdo 45: auditar RESET/LOAD/preparación, comandos concurrentes, fronteras/`load-use`, forwarding/selectores durante HOLD y drenado, commits anteriores y fetch IF + acceso MEM simultáneos sobre IMEM/DMEM independientes, sin hazard estructural artificial. |

Los invariantes conjuntos de aceptación son:

```text
cpu_cycle_fire=0                        → sin avance ni efecto CPU de la sesión
cpu_cycle_fire=1 && terminal_none      → exactamente una de siete acciones no terminales
cpu_cycle_fire=1 && drain_active       → exactamente una de dos acciones de drenado
en todo momento                        → $onehot0 de las nueve acciones
frontera con pipeline_empty_next=1     → FINISHED si halt; FAULT si fault
```

Una instrucción válida completa normalmente, causa una frontera (sin efectos propios prohibidos) o es más joven y queda descartada; las anteriores supervivientes conservan efectos elegibles incluso en el flanco de confirmación y durante drenado. `Command Arbiter` selecciona el comando aceptado, `Cycle Authorization` deriva `cpu_cycle_fire`, `Pipeline Hazard Control` escoge una acción y las ecuaciones de PC/latches/datapath efectúan la transición y los commits. La FSM decide sus estados y transiciones a partir de `pipeline_empty_next`, pero no ejecuta directamente acciones del datapath ni realimenta `next_state` hacia la autorización del mismo flanco. `terminal_none` y `drain_active` son predicados derivados del estado actual conforme al acuerdo 44, no registros terminales paralelos.

**Cierre:** no resta política de forwarding, hazard, prioridad, stall, flush, autorización o próximo estado del pipeline por decidir dentro de `DEC-ARCH-003`. El empaquetado de `ID/EX.control` es detalle de implementación RTL; la construcción y verificación física del CPU quedan por realizar y esta matriz no afirma que ya hayan pasado pruebas de hardware. La representación externa del estado y pipeline por Debug/UART permanece en `DEC-ARCH-009` y las decisiones de protocolo. Se **aprueba `DEC-ARCH-003`** con 46 acuerdos, conservando las revisiones históricas expresas del acuerdo 44.


</details>

#### Acuerdo 47 aprobado — confirmación de todo fetch fault en ID y revisión de AUD-001

**Fecha:** 2026-09-26

**Estado:** Aprobado por revisión explícita de DEC-ARCH-003.

**Motivo y alcance de la revisión:** AUD-001 demostró que confirmar un fetch más joven mientras su consumidor anterior permanece en ID puede impedir el redirect o el fault propio posterior de esa instrucción. Se sustituye esa política: **IF solo detecta candidatos; todo fetch fault se confirma arquitectónicamente en ID**, después de transportarse por IF/ID. Quedan revisados los acuerdos anteriores en sus referencias a esa confirmación anticipada, al número de acciones, a las ecuaciones dependientes y a los casos de verificación. La matriz del acuerdo 46 se actualiza conforme a este acuerdo. El texto anterior se conserva como historia expresamente revisada, no como una alternativa implementable.

**Política obligatoria:**

- Se elimina la antigua ruta de confirmación desde IF. No existe señal de confirmación ni acción de fault de esa etapa.
- Si coinciden `load_use_stall` e `if_fetch_fault_candidate`, **sin frontera anterior EX/ID prevaleciente**, se ejecuta solamente `act_load_use`: PC e IF/ID retienen íntegros sus valores, ID/EX recibe bubble y EX/MEM y MEM/WB capturan sus entradas anteriores. No se captura el candidato, no se publican causa/PC globales ni se inicia drenado por él.
- Mientras se retiene PC, el candidato se vuelve a detectar combinacionalmente en la misma dirección, sin registro adicional. En el siguiente avance normal se captura por la ruta **IF→IF/ID→ID**, con `valid=0`, `fetch_fault_valid=1`, `pc=PC` y la causa seleccionada. Si antes prevalece un redirect, fault o halt anterior, se descarta el candidato; no se exige capturar trabajo wrong-path.
- Cuando el candidato llega a ID, la instrucción consumidora anterior ya puede resolver su control o su fault en EX. La frontera EX prevalece y descarta el candidato joven; solo sin ella ID puede confirmar el fetch fault. `fault_pc` procede siempre de **IF/ID.pc** para fetch o ilegal ID; para faults propios EX procede de **ID/EX.pc**. Nunca se captura el PC global de IF como fuente directa de una confirmación de fetch.
- El Hazard Control tiene **ocho acciones: seis no terminales y dos de drenado**. No se agregan registros, campos de pipeline, selectores ni estados/FSM. Los cinco campos de IF/ID, las demás etapas, la FSM global de 14 estados, sus comandos, la autorización de ciclos, forwarding, códigos de causa, memorias y políticas externas conservan sus contratos.

**Confirmaciones y arbitraje vigentes.** Se mantienen los candidatos de los acuerdos 37–40, la selección de causa dentro de una operación y `ex_frontier`:

```text
ex_frontier = ex_fault_candidate || ex_halt_event || ex_redirect_event

ex_fault_confirm = cpu_cycle_fire && terminal_none && ex_fault_candidate
halt_confirm = cpu_cycle_fire && terminal_none
               && !ex_fault_candidate && ex_halt_candidate
redirect_apply = cpu_cycle_fire && terminal_none
                 && !ex_fault_candidate && !ex_halt_candidate
                 && redirect_requested
ex_frontier_selected = ex_fault_confirm || halt_confirm || redirect_apply

id_fault_candidate = (IF/ID.valid && !decode_legal)
                     || (!IF/ID.valid && IF/ID.fetch_fault_valid)
id_fault_confirm = cpu_cycle_fire && terminal_none
                   && !ex_frontier_selected && id_fault_candidate
fault_confirm = ex_fault_confirm || id_fault_confirm

load_use_apply = cpu_cycle_fire && terminal_none
                 && !ex_frontier_selected && !id_fault_confirm
                 && load_use_stall
normal_advance = cpu_cycle_fire && terminal_none
                 && !ex_frontier_selected && !id_fault_confirm
                 && !load_use_apply

drain_cycle = cpu_cycle_fire && drain_active
drain_load_use = drain_cycle && load_use_stall
drain_advance = drain_cycle && !load_use_stall

act_ex_fault       = ex_fault_confirm
act_halt           = halt_confirm
act_redirect       = redirect_apply
act_id_fault       = id_fault_confirm
act_load_use       = load_use_apply
act_normal         = normal_advance
act_drain_load_use = drain_load_use
act_drain_advance  = drain_advance

pipeline_action = act_ex_fault || act_halt || act_redirect
                  || act_id_fault || act_load_use || act_normal
                  || act_drain_load_use || act_drain_advance

$onehot0({act_ex_fault, act_halt, act_redirect, act_id_fault,
          act_load_use, act_normal, act_drain_load_use, act_drain_advance})
```

Durante `cpu_cycle_fire && terminal_none`, `ex_frontier_selected` equivale al `ex_frontier` combinacional; por tanto ID conserva la prioridad EX→ID. **IF no constituye una tercera frontera confirmante.** El candidato de IF no aparece en las ecuaciones de selección de acciones: solo decide qué se captura cuando hay `act_normal`. No se transforma un fault joven en una frontera por la existencia de un stall.

**Próximo estado vigente de PC y latches.** Todas las fuentes son preflanco; reset, LOAD aceptado y preparación efectiva conservan su prioridad. Estas ecuaciones sustituyen las correspondientes del acuerdo 42:

```text
pc_write_enable = act_normal || act_redirect
next_pc_sel = act_redirect
act_normal   → PC.next = PC + 4
act_redirect → PC.next = redirect_target
resto        → PC.next = PC

ifid_capture_if = act_normal
ifid_hold = act_load_use || act_drain_load_use
ifid_invalidate = act_redirect || act_halt || act_ex_fault
                  || act_id_fault || act_drain_advance

idex_capture_id = act_normal || act_drain_advance
idex_bubble = act_load_use || act_redirect || act_halt
              || act_ex_fault || act_id_fault || act_drain_load_use

exmem_capture_ex = act_normal || act_load_use || act_redirect
                   || act_id_fault || act_drain_load_use || act_drain_advance
exmem_invalidate = act_halt || act_ex_fault
memwb_capture_mem = pipeline_action
```

| Acción vigente | PC | IF/ID.next | ID/EX.next | EX/MEM.next | MEM/WB.next |
|---|---|---|---|---|---|
| `act_normal` | PC+4 | Capturar IF: instrucción o candidato | Capturar ID | Capturar EX | Capturar MEM |
| `act_load_use` | Retener | Retener los cinco campos | Bubble | Capturar EX | Capturar MEM |
| `act_redirect` | Target | Invalidar ambos flags | Bubble | Capturar EX válida | Capturar MEM |
| `act_halt` | Retener | Invalidar ambos flags | Bubble | Invalidar | Capturar MEM |
| `act_ex_fault` | Retener | Invalidar ambos flags | Bubble | Invalidar | Capturar MEM |
| `act_id_fault` | Retener | Invalidar ambos flags | Bubble | Capturar EX anterior | Capturar MEM |
| `act_drain_load_use` | Retener | Retener los cinco campos | Bubble | Capturar EX | Capturar MEM |
| `act_drain_advance` | Retener | Invalidar ambos flags | Capturar ID | Capturar EX | Capturar MEM |

Con `act_normal`, IF/ID captura `valid=1, fetch_fault_valid=0, instruction=if_instruction` si el fetch es válido, o `valid=0, fetch_fault_valid=1, instruction=32'b0` si hay candidato; siempre captura `pc=PC`. La causa es `if_fetch_fault_cause` para candidato y `3'b000` determinista sin significado de fault cuando el flag es cero. Retener conserva **los cinco campos**; invalidar limpia `valid` y `fetch_fault_valid`, permitiendo residuos de PC/instrucción/causa. Con `pipeline_action=0` y sin acción global superior, PC y los cuatro latches completos se retienen.

La captura ID/EX conserva el contrato del acuerdo 42: validez, PC, instrucción, índices, inmediato, valores posbypass WB→ID y las seis categorías de control desde ID preflanco. Bubble solo exige `valid_next=0`. EX/MEM toma validez/identidad/control de ID/EX previo, `ex_result` seleccionado entre ALU/inmediato/link y `store_data=rs2_effective`; invalidación exige `valid_next=0`. MEM/WB toma EX/MEM previo y `wb_value=is_load(EX/MEM.mem_op)?load_value:EX/MEM.ex_result`. Una entrada nueva invalidada no cancela efectos de la antigua MEM o WB.

Las dos acciones de drenado permanecen por contrato, sin simplificar ni añadir una FSM. Bajo la nueva política, las confirmaciones EX/ID invalidan IF/ID; ya no se inicia drenado con un consumidor válido retenido allí por un fetch más joven. Esto no autoriza cambiar las ecuaciones de drenado ni sus condiciones de autorización.

**Captura global y efectos.** Se revisa la ecuación del acuerdo 43:

```text
fault_capture_fire = fault_confirm = act_ex_fault || act_id_fault

if (ex_fault_confirm):
    fault_cause_in = ex_fault_cause
    fault_pc_in = ID/EX.pc
else if (id_fault_confirm):
    fault_cause_in = id_fault_cause
    fault_pc_in = IF/ID.pc

if (fault_capture_fire):
    fault_cause.next = fault_cause_in
    fault_pc.next = fault_pc_in
else:
    fault_cause.next = fault_cause
    fault_pc.next = fault_pc
```

Para fetch confirmado en ID, `id_fault_cause` copia `IF/ID.fetch_fault_cause` sin traducción; ilegal ID selecciona `010`. Las siete causas y su prioridad dentro de una operación se conservan. `rf_write_fire`, `dmem_store_fire`, `dmem_metadata_write_fire`, `redirect_commit`, `halt_commit` y `cycle_counter_increment=cpu_cycle_fire` no cambian. La FSM del acuerdo 44 consume las confirmaciones y `pipeline_empty_next` existentes: solo EX o ID pueden originar FAULT/DRAIN, y el vaciado sigue sin ciclo extra. HOLD no captura ni confirma candidatos.

**Matriz adicional obligatoria que revisa el acuerdo 46:**

| Caso | Evidencia exigida |
|---|---|
| Load-use con candidato IF y sin frontera EX/ID | Únicamente act_load_use; PC/IF/ID estables, bubble ID/EX, progreso EX/MEM/WB; fault_confirm=0 y metadatos estables |
| Stall terminado, candidato todavía en el mismo PC | act_normal captura candidato en IF/ID mientras el consumidor anterior pasa a EX; aún no hay fault por ese candidato |
| Consumidor branch tomado o jalr válido | En EX aplica redirect y descarta el candidato joven de IF/ID, incluido su flag, sin FAULT por él |
| Consumidor branch no tomado o ALU ordinaria | Sin frontera EX, candidato en ID confirma con causa registrada y fault_pc=IF/ID.pc; la EX anterior progresa |
| Consumidor load/store con fault propio, o jalr con target desalineado | ex_fault_confirm prevalece sobre candidato de fetch ID; la causante no entra válida a EX/MEM y sus efectos quedan inhibidos |
| Load productor con fault en EX | act_ex_fault descarta consumidor y candidato joven; no aplicar el stall de la dependencia descartada |
| Candidato frente a halt EX anterior | act_halt descarta candidato y termina por FINISHED tras drenado, no FAULT |
| RUN, STEP y HOLD intercalados | Un ciclo por STEP, incluido el stall; HOLD preserva cinco campos/PC/metadatos; redetección combinacional no confirma ni cuenta ciclos |
| Reset o LOAD aceptado frente a candidato retenido/registrado | La prioridad global invalida el candidato y suprime efectos de la sesión previa |
| Cobertura de acciones | Exactamente una de seis acciones no terminales o una de dos de drenado por ciclo procesable; $onehot0 de ocho siempre; cero acciones en HOLD o terminal vacío |

Contraejemplos de AUD-001 convertidos en regresión: con imagen de 8 bytes y DMEM inicial cero, `lw x1,0(x0); beq x1,x0,-4` debe repetir el loop sin confirmar el fetch especulativo en PC=8. Con `lw x1,0(x0); sw x1,2(x0)`, debe confirmarse el store desalineado con `fault_cause=110`, `fault_pc=4`, sin writes de datos ni metadata; el fetch PC=8 queda descartado. Repetir cambiando consumidor por un load inválido, jalr alineado/desalineado, branch no tomado y ALU dependiente para contrastar descarte y confirmación ID legítima.

**Cierre de la revisión:** DEC-ARCH-003 permanece Aprobada, ahora con **47 acuerdos**. Este acuerdo resuelve documentalmente AUD-001 y prevalece sobre todas las referencias históricas incompatibles, incluida la matriz 46. La implementación y la verificación RTL siguen futuras; no se cambian otras políticas arquitectónicas ni se declaran resueltos los demás hallazgos de la auditoría.

**Requisitos afectados:** `REQ-DOC-008`, `REQ-CPU-004` a `REQ-CPU-011`, `REQ-CPU-015`, `REQ-CPU-017`, `REQ-MEM-005`, `REQ-MEM-006`, `REQ-MEM-016`, `REQ-MEM-017`, `REQ-MEM-020`, `REQ-MEM-025`, `REQ-MEM-030`, `REQ-EXEC-001` a `REQ-EXEC-005`, `REQ-EXEC-009`, `REQ-EXEC-013`, `REQ-EXEC-015` a `REQ-EXEC-018`, `REQ-HAZ-001` a `REQ-HAZ-010`, especialmente `REQ-HAZ-002` a `REQ-HAZ-006`, `REQ-HAZ-007` a `REQ-HAZ-009`, `REQ-DBG-006` a `REQ-DBG-009`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-016` y `REQ-DBG-017`; la metadata CPU afecta también `REQ-MEM-029`.

**Reemplaza / Reemplazada por:** No aplica; las revisiones entre acuerdos se conservan dentro de este ADR.

---

### DEC-ARCH-004 — Instrucciones inválidas y accesos desalineados

**Estado:** Aprobada

**Dominio:** CPU / Semántica fuera del subconjunto

**Fecha de aprobación:** 2026-09-24

**Contexto:** La consigna no determina el tratamiento de palabras no soportadas, accesos desalineados ni destinos de control inválidos. La organización byte-addressed, los espacios independientes y los faults fuera de rango aprobados en `DEC-ARCH-001` requieren una política precisa, verificable y consistente con la resolución de control en EX, el descarte `wrong-path` y los ciclos efectivos de `DEC-ARCH-002` y `DEC-ARCH-008`.

**Opciones consideradas:**

1. Aceptar implícitamente codificaciones adicionales, o validar estrictamente el subconjunto RV32I y `halt`.
2. Admitir accesos desalineados mediante reconstrucción y múltiples accesos, o exigir alineación natural estricta.
3. Convertir toda detección combinacional en fault o confirmar solo el candidato válido del camino correcto que prevalece por antigüedad.
4. Vaciar todo el pipeline ante fault o drenar únicamente las instrucciones anteriores y descartar la causante y posteriores.
5. Confundir fault con finalización normal o conservar causa y PC observables hasta `FAULT`, con reset global como recuperación mínima.

**Revisión por AUD-001:** Las referencias de esta decisión a detección, confirmación y retención de candidatos de fetch se rigen por el acuerdo 47 de `DEC-ARCH-003`: detección solo en IF, confirmación solo en ID y ninguna confirmación durante load-use. No se alteran las restantes políticas.

**Decisión:** Se aprueban conjuntamente las doce subdecisiones siguientes. Las secciones 1 a 11 conservan los contratos previamente acordados y la sección 12 fija la atomicidad universal y el mínimo de verificación para cerrar arquitectónicamente esta decisión.

#### 1. Legalidad de codificaciones de instrucción

La legalidad de una palabra de instrucción de **32 bits** se determinará mediante una **whitelist estricta**: solo es legal si su codificación completa coincide con el patrón RV32I V2.2 de una de las instrucciones explícitamente soportadas o con la palabra custom exacta de `halt`. Una codificación no reconocida o no soportada es un **candidato de fault por instrucción inválida**, no una operación implícita ni una finalización normal.

El conjunto legal consta exactamente de las **32 instrucciones RV32I requeridas** y `halt`:

```text
jal  jalr
beq  bne
lb   lh   lw   lbu  lhu
sb   sh   sw
lui
add  sub  sll  srl  sra  and  or  xor  slt  sltu
addi andi ori  xori slti sltiu slli srli srai
halt
```

Para cada instrucción RV32I soportada, la coincidencia exige **todos** los campos y restricciones de su codificación según RISC-V User-Level ISA V2.2 (`opcode`, `funct3`, `funct7` y demás bits relevantes, cuando correspondan), admitiendo todos los valores de operandos e inmediatos permitidos por ese patrón. La referencia RV32I define la semántica y codificación de este subconjunto; no añade automáticamente otras instrucciones al conjunto implementado. `halt` solo es legal como la **word completa `0x0000000B`**, conforme a `DEC-SYS-001`: otra word de `custom-0`, aunque comparta el opcode, no es `halt` legal.

Son ilegales, entre otras, instrucciones RISC-V estándar no incluidas en el subconjunto, combinaciones no soportadas de campos funcionales o bits fijos, codificaciones reservadas, matches parciales de una instrucción soportada, palabras arbitrarias y `0x00000000`. Esta última **no** se interpreta como `halt`. La presencia de una word dentro de IMEM y del prefijo de programa confirmado demuestra que fue cargada y que su fetch puede estar dentro de rango, pero **no** que su codificación sea legal: la legalidad del contenido y el límite de imagen de `DEC-ARCH-001` son condiciones distintas. También se distingue de `valid` en los latches: detectar una codificación ilegal en trabajo joven descartado como `wrong-path` no confirma por sí solo un fault arquitectónico, conforme a `DEC-ARCH-002`.

Este primer acuerdo fija únicamente la **clasificación de la codificación** y la condición candidata de instrucción inválida. El quinto acuerdo sitúa su detección en ID y el sexto fija las condiciones de confirmación y la prioridad entre instrucciones; el séptimo distingue el fetch inválido de la instrucción ilegal, cuya codificación solo se valida tras un fetch válido; el octavo fija el drenado de instrucciones anteriores y `FAULT` tras su conclusión; el noveno impide que la causante de ID entre válidamente en ID/EX y retiene PC mientras drenan las anteriores. La eventual inspección preventiva de palabras por el loader es opcional; su alcance, el arbitraje RTL de coincidencias, la representación externa y las vías adicionales de recuperación desde `FAULT` corresponden a decisiones posteriores; el trigésimo séptimo acuerdo parcial de `DEC-ARCH-003` fija después el decoder combinacional único de ID y su salida `illegal_candidate` sin alterar la whitelist aprobada; `DEC-ARCH-003` ya fija parcialmente transporte/etapas de resolución y el undécimo acuerdo de esta decisión fija causa/PC persistentes y reset global como mínimo. Los acuerdos segundo, tercero y cuarto fijan por separado la alineación de accesos a Data Memory, Instruction Fetch y destinos de control; el tratamiento arquitectónico completo queda fijado por las doce subdecisiones, sin alterar la política de carga confirmada o la semántica de `halt` ya aprobadas.

#### 2. Alineación de accesos a Data Memory

**Aclaración aprobada de AUD-004 (2026-09-26):** la dirección efectiva es `(rs1_effective + immediate) mod 2^32`, con inmediato con signo extendido a 32 bits. Su carry no genera por sí solo un fault. Tanto la alineación como la validación de rango parten de ese resultado arquitectónico; solo la suma posterior `{1'b0, effective_address} + N <= DMEM_CAPACITY_BYTES` usa aritmética sin signo ensanchada a 33 bits para proteger todos los bytes, conforme a `DEC-ARCH-001`. Se conserva la prioridad de desalineación sobre access fault de una misma operación.

Todos los accesos CPU a Data Memory requerirán **alineación natural estricta** según el ancho solicitado por una instrucción de memoria válida:

| Instrucción | Ancho | Condición de alineación de la dirección efectiva |
|---|---:|---|
| `lb`, `lbu`, `sb` | 1 byte | Cualquier dirección cumple por alineación (`address mod 1 = 0`) |
| `lh`, `lhu`, `sh` | 2 bytes | `address[0] = 0` (`address mod 2 = 0`) |
| `lw`, `sw` | 4 bytes | `address[1:0] = 00` (`address mod 4 = 0`) |

Si la dirección efectiva de una instrucción de memoria válida no satisface su condición, se obtiene un **candidato de fault por acceso desalineado**. No se soportarán accesos multibyte desalineados: no se dividirá una operación entre dos words, no se combinarán posteriormente datos de dos words, no se efectuarán múltiples accesos internos para completarla y no se corregirá ni truncará la dirección para forzar alineación. En particular, un store desalineado **no podrá modificar parcialmente DMEM ni la metadata de validez por byte**; el cálculo de direcciones candidatas no habilita escrituras. Un load desalineado no obtiene un dato arquitectónico válido mediante el ensamblado de bytes candidatos.

El mapeo de cada byte candidato a `bank_i` y `row_i` aprobado en `DEC-ARCH-006` sigue siendo útil para describir direcciones, incluso si los bytes candidatos cruzan una frontera de word, pero **no vuelve legal** el acceso. Un halfword o word naturalmente alineado cabe en una misma word física de cuatro bytes: un candidato multibyte que cruce esa frontera es desalineado, no una transacción funcional `multi-row`. La legalidad por alineación y la validez por **rango de la región completa** de `DEC-ARCH-001` se evalúan como condiciones independientes; una operación puede ser candidata simultáneamente a ambas causas de fault. El séptimo acuerdo establece cuál causa prevalece cuando ambas coinciden en el mismo acceso.

Este acuerdo decide solo la **legalidad de alineación de accesos a DMEM** y la ausencia de efectos parciales de stores desalineados. El quinto acuerdo fija la detección del candidato en EX, el sexto las condiciones arquitectónicas de confirmación y prioridad entre instrucciones, el séptimo prioriza desalineación sobre acceso fuera de rango de una misma operación, el octavo dispone el drenado de instrucciones anteriores hasta `FAULT` y el noveno impide que una causante en EX pase válidamente a EX/MEM mientras MEM/WB y EX/MEM previos completan anteriores. El cuadragésimo acuerdo de `DEC-ARCH-003` fija después la detección y confirmación RTL de estos eventos; el cuadragésimo segundo acuerdo fija después los enables/flush de PC y latches para las ocho acciones; las coincidencias están cerradas por los acuerdos 44–47; las vías UART adicionales de recuperación permanecen diferidas, respetando la invalidez del trabajo `wrong-path` aprobada en `DEC-ARCH-002`. Los acuerdos tercero y cuarto definen separadamente la alineación de Instruction Fetch y de destinos de control; ninguna de estas reglas sustituye a las demás.

#### 3. Alineación de Instruction Fetch

Todo acceso CPU a Instruction Memory para obtener una instrucción de 32 bits deberá cumplir **alineación natural de word**:

```text
PC[1:0] = 2'b00   ⇔   PC mod 4 = 0
```

Un PC múltiplo de cuatro es legal **por alineación**; un PC que no sea múltiplo de cuatro genera un **candidato de fault por `instruction-address-misaligned`**. No se soportará fetch desalineado: no se redondeará ni corregirá automáticamente el PC, no se borrarán sus bits bajos para forzar alineación, no se reconstruirá una instrucción a partir de bytes de dos words y no se obtendrá arquitectónicamente una instrucción desde una dirección no múltiplo de cuatro. El índice conceptual `word_index = PC >> 2` de `DEC-ARCH-006` no autoriza a interpretar un PC desalineado como la word de un PC menor alineado; un valor combinacional residual de IMEM tampoco convierte ese fetch en instrucción válida.

La condición de alineación es **independiente** de la validez de rango e imagen de `DEC-ARCH-001`, que exige `image_valid` y la pertenencia completa de los cuatro bytes del fetch a IMEM y al prefijo confirmado, con aritmética ensanchada. Un mismo fetch puede ser candidato tanto por desalineación como por estar fuera de capacidad o imagen; el séptimo acuerdo prioriza la causa `instruction-address-misaligned` para ese mismo fetch. La legalidad de codificación de una word obtenida por fetch válido según la whitelist del primer acuerdo es otra clasificación distinta. Conforme a `DEC-ARCH-002`, si un fetch candidato del camino joven `wrong-path` es invalidado por un redirect anterior, la detección de desalineación no basta para confirmar un fault arquitectónico.

Se fija solo la **legalidad por alineación del Instruction Fetch**. El cuarto acuerdo define por separado la alineación de los **destinos** generados por `beq`, `bne`, `jal` y `jalr`; el séptimo impide redirigir a un target desalineado, por lo que no existe un fetch arquitectónico posterior desde ese destino. El quinto acuerdo fija la detección del candidato de fetch en IF, el sexto las condiciones de confirmación y la prioridad entre instrucciones, el séptimo la prioridad entre desalineación y acceso inválido de un mismo fetch, el octavo el drenado preciso hasta `FAULT` y el noveno, revisado por el acuerdo 47 de `DEC-ARCH-003`, descarta el candidato y trabajo joven al confirmarlo en ID, retiene PC y deja avanzar anteriores. Conforme al acuerdo 47 de `DEC-ARCH-003`, IF solo detecta candidatos: durante `load-use`, sin frontera EX/ID prevaleciente, solo se aplica `act_load_use`, se retienen PC y los cinco campos de IF/ID y no se confirma ni captura el candidato; al avanzar se redetecta en ese PC y se transporta por IF→IF/ID→ID, donde puede confirmarse con `fault_pc=IF/ID.pc` si no lo descarta una frontera EX anterior. El cuadragésimo acuerdo de `DEC-ARCH-003` fija después los candidatos de IF y las condiciones de confirmación; el cuadragésimo segundo acuerdo fija después los enables/flush de PC y latches para las ocho acciones; el acuerdo 45 de `DEC-ARCH-003` audita después las coincidencias funcionales; la representación externa y otras vías de recuperación permanecen en sus decisiones específicas; el undécimo acuerdo fija causa y PC persistentes y reset global como mínimo.

#### 4. Alineación de destinos de control

Toda instrucción de control **válida** que efectivamente pretenda modificar el PC deberá producir un destino arquitectónico de 32 bits alineado a cuatro bytes:

```text
target[1:0] = 2'b00   ⇔   target mod 4 = 0
```

Se conservarán las fórmulas de `DEC-ARCH-002` y los caminos de cálculo en EX de `DEC-ARCH-003`: `beq`/`bne` usan `ID/EX.pc + immediate_B`, `jal` usa `ID/EX.pc + immediate_J` y `jalr` usa `(rs1_effective + immediate_I) & 0xFFFFFFFE`. La **comprobación de alineación del destino** depende de que se pretenda utilizarlo:

| Instrucción válida | Condición para comprobar el target | Resultado por alineación |
|---|---|---|
| `beq`, `bne` no tomados | Ninguna: el target no se utiliza | No hay candidato por alineación de ese target, aunque sus bits combinacionales estén desalineados |
| `beq`, `bne` tomados | Condición del branch verdadera con operandos efectivos | `target[1:0] = 00` es legal por alineación; otro valor genera candidato |
| `jal` | Siempre, como salto incondicional válido | `target[1:0] = 00` es legal por alineación; otro valor genera candidato |
| `jalr` | Siempre, **después** de forzar `jalr_sum[0]` a cero | `target[1] = 0` es legal por alineación; `target[1] = 1` genera candidato |

El destino desalineado de un branch tomado, `jal` o `jalr` válidos genera un **candidato de fault por `instruction-address-misaligned`**. Para `jalr`, `jalr_sum[0] = 1` **no** es por sí solo un error: el bit 0 se borra conforme al ISA y se comprueba el target resultante, sin borrar adicionalmente `target[1]`. Tampoco se redondeará el destino a múltiplo de cuatro, se ejecutará desde una dirección desalineada ni se reconstruirán instrucciones desde dos words. Una entrada inválida en EX no puede generar un candidato arquitectónicamente confirmable por sus bits residuales; un branch no tomado no lo produce por un destino que no usa.

Esta regla clasifica la **legalidad del destino de control**; es distinta de la alineación del posterior Instruction Fetch y de la validez por rango e imagen de IMEM. No añade una condición de alineación a la ecuación combinacional nominal `redirect_valid` de `DEC-ARCH-003`; el séptimo acuerdo impide **aplicar** el redirect a un target desalineado, aunque pueda existir un resultado combinacional. El sexto acuerdo fija cuándo un candidato **puede confirmarse semánticamente** y qué instrucción prevalece por antigüedad: si el fault se confirma, la instrucción causante no escribe el enlace de `jal`/`jalr` y el noveno impide que avance válidamente a EX/MEM, reteniendo PC mientras drenan anteriores. El cuadragésimo acuerdo de `DEC-ARCH-003` fija después `target_misaligned_candidate`, `ex_fault_confirm` y `redirect_apply` en ciclo efectivo; el cuadragésimo segundo acuerdo fija después los enables/flush de PC y latches desde las acciones del cuadragésimo primero; el cuadragésimo quinto acuerdo audita después las coincidencias adicionales; no se admite fetch arquitectónico desde ese target.

#### 5. Detección de candidatos de fault

Cada condición candidata se detectará en la **primera etapa que disponga de todos los datos necesarios** para evaluarla correctamente:

| Condición candidata | Etapa de detección |
|---|---|
| Instruction Fetch fuera de capacidad IMEM o del prefijo de imagen confirmada | **IF** |
| Instruction Fetch desalineado | **IF** |
| Codificación de instrucción inválida frente a la whitelist completa | **ID** |
| Load/store fuera de rango DMEM | **EX** |
| Load/store desalineado | **EX** |
| Destino desalineado de `beq`/`bne` tomados o `jal`/`jalr` válidos | **EX** |

IF evaluará sobre el PC tanto la pertenencia de **los cuatro bytes** a IMEM y a la imagen confirmada como `PC[1:0] = 00`. Son condiciones independientes: un fetch puede presentar ambas causas candidatas simultáneamente y el séptimo acuerdo fija cuál prevalece. ID validará la **word completa** de IF/ID obtenida mediante fetch válido según el subconjunto aprobado y distinguirá el contenido ilegal de un fetch fuera de imagen o de bits residuales de una entrada inválida. Esta asignación de etapas no decide si el loader inspeccionará también la imagen ni asigna aquí etapa alguna al reconocimiento de `halt`.

Para loads y stores válidos, EX calculará primero `effective_address = (rs1_effective + immediate) mod 2^32`, sin fault por el carry de esa suma, y evaluará **sobre ese resultado de 32 bits** la alineación natural. Por separado, comprobará el rango de **toda la región solicitada** mediante `{1'b0, effective_address} + N <= DMEM_CAPACITY_BYTES`, con suma y comparación sin signo de 33 bits; esta segunda suma no admite wrap-around. Ambas condiciones se clasifican separadamente antes de que la operación pueda causar un acceso físico a DMEM; un store inválido no modifica parcialmente bytes ni metadata y un load inválido no escribe `rd`, conforme a `DEC-ARCH-001` y al segundo acuerdo. La dirección calculada conserva su recorrido nominal como `ex_result` sin que este acuerdo fije campos adicionales de EX/MEM ni el mecanismo de inhibición y transporte del candidato.

EX evaluará asimismo la alineación del **destino efectivo** solo después de resolver la condición del branch o calcular el target del salto: un branch no tomado no genera candidato por ese target; `jalr` comprueba el target tras poner su bit 0 en cero, sin borrar el bit 1. La ecuación nominal de `redirect_valid` permanece intacta, pero el séptimo acuerdo impide aplicar un redirect a ese target desalineado; si el fault propio se confirma, la causante carece de efectos arquitectónicos conforme al duodécimo acuerdo. La realización física del control queda para `DEC-ARCH-003`.

La detección produce únicamente un **candidato asociado a un fetch o instrucción concreta**, no un fault arquitectónico confirmado ni un cambio del estado global de ejecución. El sexto acuerdo fija las condiciones arquitectónicas para su confirmación y la prioridad por antigüedad entre instrucciones; el séptimo fija la prioridad desalineación sobre acceso inválido para causas concurrentes de un mismo fetch, load o store; el octavo define el drenado de instrucciones anteriores tras confirmarse un fault y el ingreso posterior a `FAULT`; el noveno fija la retención del PC y las invalidaciones selectivas de IF/ID, ID/EX y EX/MEM según dónde esté la causante, sin interrumpir anteriores. Cuando un redirect de una instrucción más antigua descarte trabajo joven `wrong-path`, también se descartan sus candidatos de IF o ID, sin efectos arquitectónicos. Las condiciones combinacionales pueden evaluarse durante HOLD, pero no aplican por sí solas transiciones: RUN y STEP solo las autorizan en ciclos efectivos conforme a `DEC-ARCH-008`. Conforme al acuerdo 47 de `DEC-ARCH-003`, IF solo detecta candidatos: durante `load-use`, sin frontera EX/ID prevaleciente, solo se aplica `act_load_use`, se retienen PC y los cinco campos de IF/ID y no se confirma ni captura el candidato; al avanzar se redetecta en ese PC y se transporta por IF→IF/ID→ID, donde puede confirmarse con `fault_pc=IF/ID.pc` si no lo descarta una frontera EX anterior. El cuadragésimo segundo acuerdo fija después los enables/flush de PC y latches para las acciones aprobadas; el cuadragésimo quinto acuerdo audita después las coincidencias funcionales; la representación externa de `fault_cause`/`fault_pc` y otras vías de recuperación siguen en sus decisiones específicas; el undécimo acuerdo fija su persistencia y reset global como mínimo.

#### 6. Confirmación arquitectónica y prioridad por antigüedad

La **mera detección** en IF, ID o EX no confirma un fault. Un candidato asociado a una operación solo podrá convertirse en fault arquitectónico cuando la operación siga siendo válida, pertenezca al camino correcto, no haya sido invalidada por una instrucción más antigua y no exista un evento arquitectónico de una instrucción anterior que deba prevalecer. El séptimo acuerdo selecciona una causa única cuando la misma operación presenta simultáneamente desalineación y acceso inválido, sin cambiar la prioridad por antigüedad **entre operaciones**. Conceptualmente:

```text
candidato de fault + operación válida + camino correcto
                   + ausencia de evento más antiguo prevaleciente
    → fault arquitectónico confirmado
```

Entre eventos o candidatos de **instrucciones distintas** rige prioridad estricta por **antigüedad de programa**: la instrucción más antigua tiene prioridad arquitectónica. La etapa donde se detectó cada condición no reemplaza el orden del flujo. Si EX alberga un load desalineado, ID una instrucción inválida e IF un fetch fuera de rango, y las tres operaciones son válidas y pertenecen al mismo flujo, tiene prioridad el evento del load en EX por ser el más antiguo. Si una instrucción de control más antigua en EX redirige mientras ID y IF detectan candidatos, las operaciones jóvenes pasan a `wrong-path`: sus candidatos se descartan sin fault arquitectónico ni modificación del estado global. También debe respetarse cualquier otro evento prevaleciente de una instrucción más antigua, sin convertir a un candidato joven en fault por su mera detección.

Una vez **confirmado** un fault, la operación causante y todas las instrucciones más jóvenes carecen de efectos arquitectónicos, conforme a `DEC-ARCH-001`; el octavo acuerdo fija que las **más antiguas** todavía activas completan normalmente y, tras su drenado, se alcanza `FAULT`. El noveno retiene PC, impide admisión y fija las transiciones selectivas por etapa sin vaciar latches con anteriores. Esta regla no asigna una etapa física única ni señal RTL `fault_confirm`, ni fija el ciclo de confirmación, el transporte de candidatos o la integración física de coincidencias con redirect, stalls y `halt`; el séptimo acuerdo sí prohíbe arquitectónicamente redirigir a un destino desalineado. Tampoco se confundirá la causa prevaleciente **dentro de una misma operación** con la prioridad por antigüedad entre operaciones distintas. Durante HOLD no se produce transición arquitectónica por una evaluación combinacional; RUN y STEP aplican transiciones solo en ciclos efectivos conforme a `DEC-ARCH-008`.

#### 7. Prioridad entre causas concurrentes de una misma operación

Cuando una **misma operación** presente simultáneamente desalineación y violación de rango o acceso inválido, prevalecerá arquitectónicamente **`misalignment > access fault`**. Ambas condiciones se comprueban de forma independiente y pueden detectarse en paralelo en la misma etapa; la prioridad determina una causa única y estable, no el orden temporal ni físico de evaluación:

| Operación | Condiciones concurrentes | Causa prevaleciente |
|---|---|---|
| Instruction Fetch en IF | PC desalineado y fetch fuera de IMEM o imagen confirmada | `instruction-address-misaligned` en lugar de `instruction-access-fault` |
| Load en EX | Dirección efectiva desalineada para su ancho y acceso fuera de DMEM | `load-address-misaligned` en lugar de `load-access-fault` |
| Store en EX | Dirección efectiva desalineada para su ancho y acceso fuera de DMEM | `store-address-misaligned` en lugar de `store-access-fault` |

Por convención se prioriza primero la legalidad de **forma** del acceso según su alineación natural y luego la pertenencia de la región completa al rango implementado, sin derivar de ello una necesidad física de evaluar secuencialmente ambas condiciones. Si solo se presenta una causa, esta conserva su clasificación. Esta prioridad **entre causas de una operación** no sustituye la prioridad **por antigüedad entre instrucciones distintas** del sexto acuerdo ni confirma por sí sola un fault de trabajo `wrong-path`.

En EX, un branch **tomado**, `jal` o `jalr` válido con destino efectivo desalineado genera un candidato `instruction-address-misaligned` **en la propia instrucción de control** y **no aplica el redirect**: no habrá fetch arquitectónico desde ese target. Un branch no tomado no usa su target. Para `jalr` se comprueba el destino *después* de borrar solo su bit 0. Si el target está alineado pero fuera de IMEM o de la imagen confirmada, se permite el redirect por alineación; el fetch **posterior** en IF detecta un candidato `instruction-access-fault` asociado a esa operación de fetch distinta, sujeto a validez del camino, prioridad por antigüedad y confirmación. Esta prohibición de redirigir a un target desalineado no prescribe una nueva ecuación para el `redirect_valid` combinacional nominal de `DEC-ARCH-003`, ni selecciona enable, flush, PC alternativo o comportamiento físico del enlace para la instrucción causante; si un fault se confirma, se mantiene la ausencia de efectos arquitectónicos de esa instrucción.

La taxonomía conceptual de causas es:

```text
instruction-address-misaligned
instruction-access-fault
illegal-instruction
load-address-misaligned
load-access-fault
store-address-misaligned
store-access-fault
```

La legalidad de fetch en IF y la legalidad de codificación en ID son distintas: **solo después de un fetch válido** se valida la word de 32 bits como instrucción y puede producirse `illegal-instruction`; los residuos de un fetch inválido no se decodifican arquitectónicamente. La codificación binaria común de causas se fija después en el trigésimo quinto acuerdo de `DEC-ARCH-003`; el decoder combinacional de ID se fija después en el trigésimo séptimo acuerdo de `DEC-ARCH-003`, mientras el cuadragésimo primer acuerdo de `DEC-ARCH-003` fija después el arbitraje combinacional de acciones; el cuadragésimo segundo acuerdo fija después los enables/flush de PC y latches para esas acciones; sigue pendiente el formato externo de reporte. Conforme al acuerdo 47 de `DEC-ARCH-003`, IF solo detecta candidatos: durante `load-use`, sin frontera EX/ID prevaleciente, solo se aplica `act_load_use`, se retienen PC y los cinco campos de IF/ID y no se confirma ni captura el candidato; al avanzar se redetecta en ese PC y se transporta por IF→IF/ID→ID, donde puede confirmarse con `fault_pc=IF/ID.pc` si no lo descarta una frontera EX anterior.

#### 8. Respuesta arquitectónica al fault y tratamiento de instrucciones anteriores

Un **fault arquitectónicamente confirmado** establece una frontera **precisa respecto del orden de programa**:

```text
instrucciones anteriores a la causante → continúan y completan normalmente
instrucción causante                → sin efectos arquitectónicos
instrucciones más jóvenes          → sin efectos arquitectónicos
instrucciones nuevas               → dejan de admitirse
```

La CPU drenará **únicamente** las instrucciones más antiguas que la operación causante que aún estén activas en el pipeline. Cuando todas hayan completado y el pipeline carezca de trabajo arquitectónico pendiente, entrará en el estado de error arquitectónico **`FAULT`**, distinto de `FINISHED`, DONE o cualquier finalización normal. La frontera resultante tiene todas las instrucciones anteriores completadas y la causante y posteriores sin efectos. Si no quedan instrucciones anteriores activas, no se requiere progreso de trabajo inexistente ni un ciclo artificial de drenado; el ciclo y mecanismo RTL concretos de confirmación/transición se integrarán después. Un **candidato** no confirmado, incluido uno del camino `wrong-path`, no inicia por sí solo este drenado ni detiene la admisión.

Por ejemplo, si MEM contiene `I1` (anterior válida), EX contiene `I2` (fault confirmado), ID contiene `I3` e IF contiene `I4`, `I1` completa sus efectos; `I2`, `I3` e `I4` no producen efectos, y no se admiten instrucciones nuevas mientras se drena `I1`. Otras instrucciones anteriores aún activas también deberán completar normalmente; no se fija una cantidad universal de ciclos.

Esta política complementa `DEC-ARCH-001` y distingue dos desenlaces de drenado:

```text
halt válido        → completan anteriores → pipeline vacío → FINISHED
fault confirmado   → completan anteriores → pipeline vacío → FAULT
```

El drenado requiere **ciclos efectivos** conforme a `DEC-ARCH-008`: bajo ejecución continua progresa con la autorización de RUN y, bajo paso a paso, necesita un nuevo STEP por ciclo; durante HOLD no avanza. El noveno acuerdo fija PC retenido, no admisión, invalidación selectiva de causante/jóvenes y progreso de anteriores hasta que los cuatro latches sean inválidos, sin exigir una señal o estado RTL `FAULT_DRAIN`, campos de datos limpiados ni ecuaciones de enable. El undécimo acuerdo fija la observabilidad del error, su causa y PC estables durante drenado y `FAULT`, y reset global como recuperación mínima. `DEC-ARCH-003` ya fija las etapas de resolución y el transporte mínimo; el acuerdo 45 de `DEC-ARCH-003` audita después las coincidencias funcionales; la representación externa detallada y las vías de recuperación adicionales quedan en sus decisiones respectivas. Un fault no activa `program_finished` ni DONE.

#### 9. Acciones del pipeline ante un fault confirmado

Una vez **confirmado arquitectónicamente** un fault, el pipeline separará las instrucciones **anteriores** de la **causante** y las **posteriores**. PC dejará de avanzar y quedará retenido durante todo el drenado; IF no admitirá nuevas instrucciones. Las anteriores todavía válidas continuarán progresando, con los stalls necesarios para sus dependencias, hasta completar sus efectos; la causante no se propagará como instrucción válida y las jóvenes se invalidarán. No se vaciarán indiscriminadamente los cuatro latches: MEM/WB y cualquier otra etapa con trabajo anterior conservan la capacidad de completar cada store o writeback exactamente una vez. Las salidas combinacionales residuales de IF no representan nuevas instrucciones admitidas.

Para una operación causante confirmada, las acciones en el **ciclo efectivo de confirmación** se describen desde el contenido **previo al flanco**. Conforme al acuerdo 47 de `DEC-ARCH-003`, IF solo detecta candidatos: durante `load-use`, sin frontera EX/ID prevaleciente, solo se aplica `act_load_use`, se retienen PC y los cinco campos de IF/ID y no se confirma ni captura el candidato; al avanzar se redetecta en ese PC y se transporta por IF→IF/ID→ID, donde puede confirmarse con `fault_pc=IF/ID.pc` si no lo descarta una frontera EX anterior.

| Causante | Instrucciones anteriores | Causante y trabajo más joven | PC / admisión |
|---|---|---|---|
| Fetch detectado en **IF** y confirmado en **ID** desde IF/ID | Las entradas previas de ID/EX, EX/MEM y MEM/WB siguen drenando, si son válidas | No se propaga el candidato de IF/ID a ID/EX: `ID/EX.next.valid=0`; IF/ID deja `valid=0` y limpia `fetch_fault_valid` | PC retenido; no se admiten fetches posteriores |
| Instrucción en **IF/ID (ID)** | ID/EX, EX/MEM y MEM/WB previos continúan drenando | La causante no entra válida en ID/EX (`ID/EX.next.valid=0`); `IF/ID.next.valid=0`, `IF/ID.next.fetch_fault_valid=0` y el fetch joven de IF se descarta | PC retenido; no hay admisión nueva |
| Instrucción en **ID/EX (EX)** | EX/MEM y MEM/WB previos continúan drenando | La causante no entra válida en EX/MEM (`EX/MEM.next.valid=0`); `ID/EX.next.valid=0`, `IF/ID.next.valid=0`, `IF/ID.next.fetch_fault_valid=0` y se descarta IF | PC retenido; no hay admisión nueva |

En particular, ante fault confirmado por destino desalineado de `jal` o `jalr` en EX, no se realiza redirect, no se escribe el enlace y la instrucción no avanza **válidamente** a EX/MEM. Las entradas inválidas pueden conservar bits residuales sin decodificarse ni producir efectos; `IF/ID.valid=0` con `fetch_fault_valid=1` es únicamente un candidato de fetch, mientras `valid=0` y el flag limpiado no confirma nada por residuos. Una instrucción anterior que ocupaba EX/MEM antes del flanco puede avanzar a MEM/WB aunque `EX/MEM.next.valid=0` para la causante. No se equiparará una salida combinacional de IF, una instrucción previa en IF/ID o una instrucción de EX/MEM a la nueva entrada de otro latch en ese mismo flanco. El décimo acuerdo, revisado por el 47 de `DEC-ARCH-003`, preserva al consumidor durante `load-use` sin confirmar el candidato IF. Este nunca ingresa como instrucción válida: se captura después con `valid=0, fetch_fault_valid=1` y solo puede confirmarse en ID.

Durante el drenado conceptual **`FAULT_DRAIN`**, PC permanece retenido, no se habilitan nuevos fetches ni se admiten instrucciones y solo progresan las anteriores todavía válidas, con los stalls que requieran para conservar sus dependencias. Estas fases semánticas se realizan con FAULT_DRAIN_AUTO/STEP en la FSM del acuerdo 44; su codificación binaria es libre. El progreso ocurre únicamente en ciclos CPU efectivos: bajo autorización continua de RUN se producen los ciclos de drenado y bajo paso a paso se requiere un STEP nuevo por ciclo; HOLD no actualiza PC, latches, registros ni memoria. Cuando hayan completado todas las anteriores y **`IF/ID.valid = ID/EX.valid = EX/MEM.valid = MEM/WB.valid = 0`**, el estado arquitectónico pasa a **`FAULT`**, conservando el pipeline vacío. Ni el ciclo de confirmación ni el drenado aplican cambios asíncronos o ciclos arquitectónicos ocultos; reset y LOAD conservan sus prioridades globales ya aprobadas.

El acuerdo fija solo estas acciones **tras confirmarse** el fault, sin convertir la mera detección de un candidato en drenado o retención del PC. El décimo acuerdo resuelve la interacción semántica con `redirect`, `halt` y `load-use stall`; el undécimo fija causa y PC observables y persistentes, distinción respecto de `FINISHED` y recuperación mínima por reset global. Las etapas y el transporte mínimo de candidatos se fijan en el vigésimo noveno acuerdo de `DEC-ARCH-003`; el cuadragésimo acuerdo fija después las ecuaciones RTL de detección/confirmación; el cuadragésimo segundo acuerdo fija después enables/flush de PC y latches para las acciones pactadas; el acuerdo 45 de `DEC-ARCH-003` resuelve después las coincidencias funcionales; la representación externa y otras vías de recuperación quedan en sus decisiones respectivas.

#### 10. Interacción entre fault, redirect, `halt` y `load-use stall`

No se adopta una prioridad universal `fault > redirect > halt > stall`. Primero se determina qué instrucciones permanecen válidas y en el camino correcto. Entre eventos de **instrucciones distintas** prevalece la instrucción más antigua en orden de programa:

| Frontera más antigua | Evento en instrucción más joven | Resultado arquitectónico |
|---|---|---|
| Redirect aplicable | Candidato de fault | El trabajo joven queda `wrong-path` y se descarta; el candidato no se confirma |
| Fault confirmado | Redirect | El redirect joven se descarta sin efecto; se drenan anteriores y se llega a `FAULT` |
| `halt` válido del camino correcto | Candidato de fault | Se descarta el candidato posterior; drenado normal hasta `FINISHED` |
| Fault confirmado | `halt` | Se descarta el `halt` posterior; se llega a `FAULT`, nunca a `FINISHED` por ese `halt` |

Un candidato de fault de una instrucción **no** confirma nada por su sola detección: debe satisfacer validez, camino correcto y ausencia de una frontera anterior prevaleciente. Si **la misma** instrucción de control, branch tomado, `jal` o `jalr`, tiene destino desalineado, su propio fault suprime sus efectos normales: **no hay redirect**, ni escritura de enlace en `jal`/`jalr`, ni efectos arquitectónicos de la causante. No es una comparación de antigüedad entre dos instrucciones; la señal combinacional nominal de redirect puede existir sin aplicar el destino. Un `halt` válido del camino correcto establece igualmente una frontera: ninguna instrucción posterior confirma un fault o produce efectos. No se asigna aquí etapa física al reconocimiento de `halt`.

Un `load-use stall` no establece una frontera arquitectónica: solo se aplica cuando sigue siendo necesario para **instrucciones anteriores supervivientes**. Conforme al acuerdo 47 de `DEC-ARCH-003`, IF solo detecta candidatos: durante `load-use`, sin frontera EX/ID prevaleciente, solo se aplica `act_load_use`, se retienen PC y los cinco campos de IF/ID y no se confirma ni captura el candidato; al avanzar se redetecta en ese PC y se transporta por IF→IF/ID→ID, donde puede confirmarse con `fault_pc=IF/ID.pc` si no lo descarta una frontera EX anterior. Cuando el valor esté disponible, el consumidor puede continuar con forwarding y completar una sola vez. Si el load en EX es la causante de fault y su consumidor está en ID, el consumidor se descarta, la causante no pasa válida a EX/MEM y no se mantiene el stall por esa dependencia. Tampoco se aplica un stall cuya consumidora es la propia causante o una instrucción posterior a un fault más antiguo.

Conceptualmente se filtran primero validez, camino correcto y antigüedad; se suprimen los efectos propios de la causante; se descarta el trabajo joven tras la frontera de fault, `halt` o redirect; y **solo** se aplican stalls necesarios para anteriores que sobreviven. Durante el drenado, las anteriores pueden necesitar retención, bubble y forwarding sin habilitar nuevas instrucciones ni perder el fault confirmado. RUN y STEP aplican esos pasos solo en ciclos CPU efectivos; HOLD no progresa. Conforme al acuerdo 47 de `DEC-ARCH-003`, IF solo detecta candidatos: durante `load-use`, sin frontera EX/ID prevaleciente, solo se aplica `act_load_use`, se retienen PC y los cinco campos de IF/ID y no se confirma ni captura el candidato; al avanzar se redetecta en ese PC y se transporta por IF→IF/ID→ID, donde puede confirmarse con `fault_pc=IF/ID.pc` si no lo descarta una frontera EX anterior. El cuadragésimo acuerdo de `DEC-ARCH-003` fija después las condiciones RTL de confirmación/aplicación por antigüedad; el cuadragésimo segundo acuerdo fija después las ecuaciones de enables/flush de PC y latches para esas acciones; el cuadragésimo cuarto acuerda después la FSM global y el cuadragésimo quinto audita las coincidencias funcionales. El trigésimo sexto había introducido registros terminales, reemplazados expresamente por la FSM del cuadragésimo cuarto.

#### 11. Estado observable, causa y recuperación del fault

Un fault **arquitectónicamente confirmado** será observable como condición de error durante el drenado conceptual **`FAULT_DRAIN`**, cuando haya anteriores activas, y en el estado final **`FAULT`**. Ambos se distinguirán semánticamente de RUN/STEP, del drenado de un `halt` válido (**`HALT_DRAIN`**) y de **`FINISHED`**. Los nombres designan categorías observables; no obligan a codificar una FSM con esos cinco estados ni a insertar un ciclo de drenado si no queda trabajo anterior. Solo tras completar anteriores y quedar los cuatro latches inválidos se alcanzará `FAULT`, manteniendo la condición de error y el pipeline vacío. Un fault no activará `program_finished`, DONE ni otra indicación reservada para terminación normal por `halt`.

Al **confirmarse** el fault se capturará y mantendrá, como mínimo, información conceptual **`fault_cause`** y **`fault_pc`** asociada a la operación causante:

| Información | Semántica mínima |
|---|---|
| `fault_cause` | Una causa arquitectónica inequívoca entre `instruction-address-misaligned`, `instruction-access-fault`, `illegal-instruction`, `load-address-misaligned`, `load-access-fault`, `store-address-misaligned` y `store-access-fault`. Se respetan la prioridad por antigüedad entre instrucciones y `misalignment > access fault` dentro de un mismo fetch, load o store. |
| `fault_pc` | PC de la instrucción causante ya obtenida, incluido el PC propio transportado hasta ID/EX para loads, stores y destinos de control en EX; para fetch detectado en IF y confirmado en ID, dirección del fetch causante preservada en `IF/ID.pc` conforme al acuerdo 47 de `DEC-ARCH-003`. No se sustituye por la dirección efectiva, el target problemático ni automáticamente por el PC global de IF, que puede corresponder a otra operación. |

La captura lógica está vinculada a la **confirmación arquitectónica**, no a la mera detección combinacional del candidato: un candidato `wrong-path`, invalidado o posterior a una frontera anterior no publica causa/PC como fault actual. Una vez confirmados, `fault_cause` y `fault_pc` permanecen **estables durante todo `FAULT_DRAIN` y en `FAULT`**; las instrucciones anteriores que drenan, las posteriores descartadas y nuevos candidatos no los sobrescriben. HOLD tampoco los modifica. Los datos forman parte del estado persistente observable de fault para snapshots coherentes cuando Debug pueda capturarlos, sin imponer snapshot arbitrario durante RUN, puertos o formato UART ni almacenamiento dentro de los cuatro latches. El trigésimo quinto acuerdo parcial de `DEC-ARCH-003` fija después `fault_cause[2:0]` y su codificación común con el candidato de IF/ID, sin cambiar esta persistencia. No se exige un `fault_address` independiente; otra decisión podrá agregarlo para Debug.

La **recuperación mínima obligatoria desde `FAULT` es el reset global** de `DEC-ARCH-008`. Cuando el reset funcional tome efecto en el flanco válido, se invalida la condición de fault y dejan de interpretarse `fault_cause` y `fault_pc` como datos de la sesión actual; el PC queda en `0x00000000`, IF/ID, ID/EX, EX/MEM y MEM/WB con `valid=0`, sin sesión ni imagen ejecutable activa (`loaded_image_size_bytes=0`, `image_valid=0`). Reset no produce `FINISHED`/DONE; después requiere preparación y commit normales de una nueva sesión antes de RUN o STEP. No se exige poner a cero los bits físicos de los metadatos invalidados, borrar memorias ni actualizar registros funcionales asíncronamente. El cuadragésimo cuarto acuerdo de `DEC-ARCH-003` aprueba después RUN/STEP desde `FAULT` para preparar una **sesión nueva y limpia** con la imagen confirmada; no reanuda la sesión fallada ni suprime reset global como vía mínima. La representación externa de causa/PC y el comando UART permanecen para Debug y protocolo.

Este acuerdo fija la persistencia observable, información mínima y recuperación por reset. El vigésimo noveno acuerdo de `DEC-ARCH-003` fija posteriormente el transporte/etapas mínimas de candidatos sin cambiar esa semántica; el trigésimo quinto fija el ancho y código de causa. El trigésimo sexto acuerdo introdujo `terminal_kind[1:0]` y `drain_auto` registrados, sustituidos **expresamente** por `global_state` en el cuadragésimo cuarto: clase terminal y modalidad de drenado se derivan de los 14 estados. Los acuerdos cuadragésimo primero y segundo fijan el arbitraje y los enables de PC/latches, y el cuadragésimo tercero el gating de efectos CPU. El cuadragésimo quinto acuerdo audita y resuelve después las coincidencias funcionales; la representación externa del estado global sigue en `DEC-ARCH-009`.

#### 12. Atomicidad y verificación mínima

**Regla general:** Toda operación causante de un **fault arquitectónicamente confirmado** tendrá **cero efectos arquitectónicos propios**. No se aplica esta supresión a las instrucciones anteriores supervivientes: completan exactamente una vez; las posteriores quedan descartadas. Un candidato no confirmado no inicia por sí mismo el drenado ni publica un fault.

| Operación causante | Efectos propios prohibidos |
|---|---|
| Load con fault | No escribe `rd` ni aporta un valor arquitectónico de la carga |
| Store con fault | No modifica **ningún byte** de DMEM ni su metadata de validez; no se habilita **ningún byte para escritura**, aun si algunos bytes candidatos están dentro de la capacidad |
| `jal`/`jalr` con target desalineado | No aplica redirect ni escribe el enlace |
| Branch tomado con target desalineado | No aplica redirect ni produce otros efectos arquitectónicos de esa instrucción |
| Instrucción inválida | No escribe RegFile ni DMEM, no aplica redirect y no inicia `halt` |

Un store defectuoso es atómico respecto de toda su región: se comprueban alineación y rango de **todos** sus bytes candidatos antes de habilitar DMEM; una región parcialmente dentro de rango no permite una escritura parcial, ni un byte enable parcialmente activo, ni una modificación de metadata. Se extiende a desalineación y demás faults la prohibición de efectos parciales de `DEC-ARCH-001`. Para loads tampoco se permite writeback de un valor residual; para saltos no se aplica un target desalineado aunque existan resultados combinacionales del datapath.

El drenado usa la disciplina de `DEC-ARCH-008`: en RUN las anteriores avanzan automáticamente por ciclos CPU efectivos, respetando stalls necesarios entre supervivientes; en STEP cada ciclo de drenado requiere un **STEP autorizado nuevo** y puede hacer falta más de uno; en HOLD no avanzan instrucciones ni se producen ciclos arquitectónicos ocultos. Si al confirmar no queda trabajo anterior, no se exige un ciclo de drenado vacío antes de `FAULT`.

**Matriz mínima obligatoria de verificación:**

| Área | Cobertura mínima |
|---|---|
| Legalidad ISA | Las 32 RV32I soportadas y `halt = 0x0000000B` completos se aceptan; se rechazan no soportadas, reservadas, matches parciales y `0x00000000` |
| Alineación DMEM | Byte en cualquier dirección; halfword y word alineados y desalineados, con la región completa validada |
| Fetch | `PC[1:0]=00` es legal por alineación; `01`, `10` y `11` generan candidato de misalignment |
| Branches | Target desalineado solo causa fault propio de branch válido y **tomado**, nunca de branch no tomado |
| `jal` | Target desalineado causa fault propio, sin redirect ni link |
| `jalr` | Borrar primero solo `target[0]`; comprobar después alineación a cuatro bytes, sin redirect/link si falla |
| Causas simultáneas | En el mismo fetch, load o store, misalignment y acceso fuera de rango eligen causa de misalignment |
| `wrong-path` | Candidato joven invalidado por evento anterior no confirma fault ni reemplaza causa/PC válidos |
| Antigüedad | Entre eventos de instrucciones distintas prevalece la anterior en orden de programa |
| Fault preciso | Todas las anteriores completan; la causante y posteriores carecen de efectos; latches vacíos antes de `FAULT` |
| Load defectuoso | `rd` no se escribe por el load causante |
| Store defectuoso | Ningún byte o metadata DMEM cambia ni se habilita un byte de escritura, incluso con acceso parcialmente dentro de rango |
| Control defectuoso | Fault propio de branch tomado o salto no aplica redirect; `jal`/`jalr` tampoco escriben link |
| Terminación | Fault llega a `FAULT`, no `FINISHED`/DONE; RUN/STEP drenan solo en ciclos efectivos, HOLD no progresa |
| Observabilidad | `fault_cause` y `fault_pc` capturados al confirmar persisten durante `FAULT_DRAIN` y `FAULT` |
| Recuperación | Reset global invalida fault y metadatos, PC vuelve a cero y pipeline/sesión quedan inválidos conforme a `DEC-ARCH-008`; el acuerdo 44 de `DEC-ARCH-003` permite después una nueva sesión limpia por RUN/STEP desde FAULT reutilizando la imagen confirmada |

**Justificación:** La validación estricta, la alineación natural y la confirmación por validez y antigüedad impiden tratar bits residuales, trabajo `wrong-path` o bytes parciales como operaciones arquitectónicas. Una frontera precisa permite completar las anteriores sin comprometer efectos de la causante; causa y PC persistentes distinguen error de terminación normal y permiten diagnosticarlo sin imponer un protocolo concreto.

**Consecuencias:** La política de faults arquitectónicos queda **conceptualmente cerrada**: las doce subdecisiones, la atomicidad universal y la matriz mínima anterior son obligatorias para la implementación y verificación. Un store inválido no habilita escrituras de datos ni metadata; un fault no produce `FINISHED`. La representación externa y la integración física deberán conservar las prioridades, el estado observable y el drenado establecidos aquí.

Conforme al acuerdo 47 de `DEC-ARCH-003`, IF solo detecta candidatos: durante `load-use`, sin frontera EX/ID prevaleciente, solo se aplica `act_load_use`, se retienen PC y los cinco campos de IF/ID y no se confirma ni captura el candidato; al avanzar se redetecta en ese PC y se transporta por IF→IF/ID→ID, donde puede confirmarse con `fault_pc=IF/ID.pc` si no lo descarta una frontera EX anterior. El trigésimo quinto acuerdo parcial de `DEC-ARCH-003` fija después el código de tres bits común para `IF/ID.fetch_fault_cause` y `fault_cause` confirmada. El trigésimo sexto acuerdo parcial de `DEC-ARCH-003` había fijado `terminal_kind[1:0]`, **revisado expresamente** por la FSM de 14 estados del cuadragésimo cuarto para distinguir NONE, HALT, FAULT y modalidad de drenado sin ese registro; el cuadragésimo acuerdo fija después las señales candidatas y las ecuaciones RTL de confirmación/aplicación de fault, `halt` y redirect por antigüedad, y el cuadragésimo primero, revisado por el 47, fija la selección combinacional de ocho acciones (seis no terminales y dos de drenado), y el cuadragésimo segundo fija los próximos estados de PC y latches derivados de ellas; el cuadragésimo tercero fija el gating de efectos CPU y el cuadragésimo cuarto las transiciones y autorización del ciclo global; el cuadragésimo quinto audita y resuelve las coincidencias funcionales, conservando las fronteras arquitectónicas aquí fijadas; el cuadragésimo sexto acuerdo completa la matriz final y cierra `DEC-ARCH-003`, con revisión explícita por el acuerdo 47. La recuperación por RUN/STEP desde FAULT mediante nueva sesión con imagen confirmada y la elegibilidad de LOAD en modos STEP se fijan en el cuadragésimo cuarto acuerdo; la representación externa de fault, campos opcionales de Debug, framing UART y otras vías adicionales de recuperación corresponden a `DEC-ARCH-009` y las decisiones de Debug/protocolo. Una inspección preventiva opcional de palabras por el loader no cambia la legalidad ni puede sustituir la confirmación durante ejecución. No se incorporan condiciones semánticas pendientes al identificador `DEC-ARCH-004`.

**Requisitos afectados:** `REQ-CPU-011`, `REQ-CPU-015`, `REQ-CPU-017`, `REQ-ISA-001` a `REQ-ISA-034`, especialmente `REQ-ISA-001`, `REQ-ISA-005`, `REQ-ISA-006`, `REQ-ISA-032` a `REQ-ISA-034`, `REQ-ISA-002` a `REQ-ISA-004` y `REQ-ISA-018` a `REQ-ISA-022`, `REQ-MEM-006`, `REQ-MEM-009`, `REQ-MEM-016` a `REQ-MEM-018`, `REQ-MEM-020`, `REQ-MEM-027` a `REQ-MEM-029`, `REQ-EXEC-013` a `REQ-EXEC-015`, `REQ-EXEC-018`, `REQ-HAZ-004`, `REQ-HAZ-010`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-ARCH-006 — Implementación física de las memorias

**Estado:** Aprobada

**Dominio:** CPU / Recursos FPGA

**Fecha de aprobación:** 2026-09-21

**Contexto:** `DEC-ARCH-001` fijó el comportamiento arquitectónico de Instruction Memory y Data Memory, pero dejó pendiente establecer un contrato físico inicial compatible con FPGA. Debían definirse la latencia observable, la estrategia base de implementación, la organización conceptual, la demanda mínima de puertos, la representación del cero lógico de DMEM, el estado persistente de la imagen y los perfiles utilizados para validar parametrización.

Esta decisión debe preservar direccionamiento por bytes, espacios Harvard lógicamente independientes, little-endian, validación previa a indexación, reprogramación segura y el pipeline conceptual de cinco etapas, respetando la FSM y control de los acuerdos 40–47 de `DEC-ARCH-003`, alineación de `DEC-ARCH-004` y clock de `DEC-ARCH-005`; el criterio de memoria utilizada por Debug permanece en `DEC-SYS-005`.

**Opciones consideradas:**

1. Lectura combinacional o registrada.
2. RTL inferido, XPM, primitivas o IP generado.
3. IMEM por bytes o por words de 32 bits.
4. DMEM monolítica o dividida conceptualmente en lanes de bytes.
5. Puertos concurrentes obligatorios o ownership exclusivo.
6. Borrado físico de DMEM, validez por word, validez por byte o representaciones equivalentes.
7. `image_valid` persistente independiente o derivado del tamaño confirmado.
8. Soportar todo el dominio arquitectónico o declarar perfiles concretos de validación.

**Decisión:** Se aprueba el siguiente alcance.

#### 1. Contrato físico aprobado

##### Latencia de lectura y escritura

Instruction Memory y Data Memory presentarán hacia la CPU lectura **combinacional**, sin salida registrada, handshake, latencia variable ni stalls atribuibles exclusivamente a la memoria.

Conceptualmente:

```text
PC / validación -> IMEM -> IF/ID
EX/MEM / validación -> DMEM -> selección/extensión -> MEM/WB
```

Las escrituras serán síncronas respecto del flanco activo habilitado. El loader escribirá Instruction Memory únicamente después de disponer de una instrucción completa y un store modificará Data Memory únicamente cuando la operación correspondiente sea válida y esté habilitada por el control.

La memoria no introducirá una etapa adicional entre IF e ID ni entre MEM y WB. Un backend cuya interfaz requiera necesariamente lectura registrada no satisface este contrato sin revisar explícitamente la decisión y sus dependencias.

##### Backend inicial

La implementación inicial de IMEM, DMEM y su lógica asociada se describirá mediante **RTL sintetizable e inferible**. La inferencia es la estrategia base, pero no promete que Vivado seleccione un tipo físico concreto de RAM.

XPM o primitivas específicas podrán evaluarse en el futuro si los resultados de síntesis, utilización o timing lo justifican. Cualquier alternativa deberá conservar exactamente:

- interfaces lógicas;
- lectura combinacional;
- escritura síncrona;
- direccionamiento y little-endian;
- ownership y concurrencia;
- semántica de imagen y de cero lógico;
- comportamiento observable por CPU, loader y Debug.

La selección concreta de una alternativa y su configuración se realizará únicamente cuando exista evidencia que la motive.

##### Organización conceptual

IMEM se organizará conceptualmente como un array de words de 32 bits:

```text
IMEM_WORD_COUNT = IMEM_CAPACITY_BYTES / 4
word_index       = PC >> 2
```

Cada entrada contendrá una instrucción completa. El loader reconstruirá la word antes de escribirla y el índice solo se utilizará después de validar la solicitud completa.

DMEM se organizará conceptualmente mediante cuatro lanes o bancos lógicos de bytes:

```text
DMEM_WORD_COUNT = DMEM_CAPACITY_BYTES / 4
bank_i          = byte_address_i[1:0]
row_i           = byte_address_i >> 2
```

Cada byte candidato se mapeará independientemente. Un store válido modificará únicamente los bytes seleccionados y un load reconstruirá los bytes en orden little-endian antes de aplicar sign o zero extension.

Esta organización no obliga a Vivado a materializar cuatro bloques RAM independientes ni fija la frontera exacta entre wrapper, LSU y arrays físicos.

##### Ownership y concurrencia

Cada memoria lógica admitirá como máximo un agente autorizado por vez. El contrato permite ciclos sin agente activo y no exige puertos concurrentes CPU/loader sobre IMEM ni CPU/Debug sobre DMEM.

Instruction Memory tendrá como agentes conceptuales a CPU y loader. Data Memory tendrá como agentes conceptuales a CPU y Debug. La lectura directa de Debug requerirá CPU quiescente; una implementación con mirror, shadow o snapshot aislado podrá desacoplar la observación.

IMEM y DMEM mantendrán interfaces lógicas independientes. Durante ejecución deberá ser posible atender en el mismo ciclo un fetch y una operación de load o store sin hazard estructural ni stall atribuible a tratarlas como un único recurso.

No se fija en esta decisión la codificación de ownership, los nombres de grants, la lógica concreta de muxes, los pulsos de compromiso ni el tratamiento temporal detallado de una colisión interna. El control deberá preservar la exclusión aprobada y las violaciones se comprobarán mediante assertions apropiadas durante la implementación.

##### Estado confirmado de Instruction Memory

`loaded_image_size_bytes` será la única fuente persistente de verdad sobre la imagen actualmente confirmada y ejecutable. `image_valid` se derivará combinacionalmente:

```text
image_valid = (loaded_image_size_bytes != 0)
```

El tamaño se expresará en bytes y deberá representar desde cero hasta `IMEM_CAPACITY_BYTES` inclusive:

```text
IMAGE_SIZE_WIDTH = max(1, ceil(log2(IMEM_CAPACITY_BYTES + 1)))
```

Los estados persistentes legales serán cero o un tamaño de imagen no vacío, múltiplo de cuatro y no mayor que IMEM. El progreso de LOAD permanecerá separado. Al aceptar una nueva carga se invalidará el tamaño confirmado; una solicitud rechazada no modificará por sí sola la imagen vigente.

La cantidad de instrucciones se derivará de `loaded_image_size_bytes / 4`. No existirá bitmap de validez por instrucción, bitmap por byte de IMEM, lista de regiones válidas ni metadata sparse. La imagen confirmada seguirá siendo un único prefijo contiguo desde `0x00000000`.

#### 2. Implementación de referencia

##### Cero lógico y metadata DMEM

La semántica obligatoria será:

```text
Todo byte no escrito durante la sesión actual se lee como 0x00.
```

La implementación de referencia utilizará un valid bit por byte:

```text
VALID_BIT_COUNT = DMEM_CAPACITY_BYTES
logical_byte[a] = valid[a] ? data[a] : 8'h00
```

Cada store válido actualizará atómicamente el dato y la validez de los bytes seleccionados. Los bytes no seleccionados conservarán ambos valores. Los loads aplicarán el filtro de validez byte por byte antes del ensamblado y extensión.

El bitmap de un bit por byte es una **implementación de referencia**, no una representación física universal obligatoria. Perfiles futuros podrán utilizar generation tags, metadata jerárquica u otra técnica equivalente sin revisar la arquitectura, siempre que preserven exactamente:

- cero para todo byte no escrito en la sesión;
- granularidad observable por byte;
- atomicidad de stores;
- aislamiento entre sesiones;
- latencia y comportamiento de loads;
- observación coherente por Debug.

El mecanismo concreto que establece el estado lógico inicial de una nueva sesión podrá ser paralelo, secuencial, mediante FSM o equivalente. La sesión no podrá confirmarse ni habilitar RUN/STEP hasta que DMEM presente la semántica de cero requerida, pero esta decisión no fija cantidad de bits por ciclo, señales ni secuencia de control.

La metadata podrá ser un insumo para Debug, pero no determina por sí misma qué posiciones se consideran memoria utilizada.

##### Perfiles

Se utilizarán los siguientes perfiles:

| Perfil | IMEM bytes | DMEM bytes | Compromiso |
|---|---:|---:|---|
| `REFERENCE` | 1024 | 2048 | Elaboración, simulación, síntesis, implementación y validación en hardware obligatorias |
| `ALT_1000` | 1000 | 1000 | Elaboración, simulación y smoke tests de parametrización no potencia de dos |

`REFERENCE` es el único perfil con compromiso físico completo en esta decisión. `ALT_1000` demuestra que índices, límites, metadata y validaciones no dependen de capacidades potencia de dos; no se exige todavía implementación física ni timing closure para este perfil.

Una configuración arquitectónicamente inválida deberá rechazarse claramente. Una configuración válida pero no declarada soportada también deberá producir un error claro, distinguible del caso inválido. Ampliar el conjunto de perfiles físicamente soportados requerirá una decisión posterior basada en evidencia.

#### 3. Aspectos explícitamente diferidos

Esta decisión no fija:

- polaridad, estrategia temporal, semántica de reset, prioridades y condiciones globales de enable, definidas por `DEC-ARCH-008` sin imponer FSM de carga ni secuencia RTL concreta de ownership;
- mecanismo físico de invalidación, cantidad de valid bits limpiados por ciclo ni señales de inicio/progreso/finalización de mantenimiento;
- nombres de puertos, grants, pulsos de compromiso o señales RTL concretas;
- política de alineación, accesos desalineados y prioridad de errores, que corresponden a `DEC-ARCH-004`;
- plataforma Basys 3 y objetivo inicial de 50 MHz, fijados por acuerdos parciales de `DEC-ARCH-005`; timing closure, frecuencia final y necesidad efectiva de un fallback físico continúan sujetos a sus resultados de implementación;
- criterio de memoria utilizada y mecanismo final de captura Debug, que corresponden a `DEC-SYS-005`;
- framing, orden de transporte y comandos UART, que corresponden a `DEC-PROTO-001` y decisiones relacionadas;
- tecnología física exacta que Vivado infiera;
- configuración concreta de XPM o primitivas si en el futuro se justifican.

**Justificación:** La lectura combinacional conserva las cinco etapas conceptuales y evita introducir una microarquitectura distinta de forma implícita. RTL inferido permite comenzar con una descripción portable y medir la realización real antes de introducir dependencias específicas del fabricante.

La organización por words coincide con fetches completos y la organización por lanes coincide con stores parciales. Ownership exclusivo satisface los flujos obligatorios sin convertir multiport en requisito, mientras la independencia lógica de IMEM y DMEM conserva la concurrencia IF/MEM.

La validez lógica por byte representa exactamente la semántica requerida para `sb`, `sh` y `sw`. Mantener el bitmap solo como referencia evita convertir una solución sencilla para el perfil actual en una restricción arquitectónica futura.

Derivar `image_valid` del tamaño elimina estado redundante. `ALT_1000` proporciona evidencia de parametrización no potencia de dos sin prometer prematuramente soporte físico completo.

**Consecuencias:**

- IMEM y DMEM presentan lectura combinacional y escritura síncrona;
- RTL inferido es el backend inicial;
- IMEM usa words conceptuales de 32 bits;
- DMEM usa cuatro lanes conceptuales de bytes;
- cada memoria viva admite como máximo un agente autorizado;
- IMEM y DMEM pueden atender simultáneamente sus demandas lógicas;
- cada byte DMEM no escrito en la sesión se lee como cero;
- la referencia usa un valid bit por byte, pero otras representaciones equivalentes permanecen permitidas;
- `loaded_image_size_bytes` es la única fuente persistente de imagen;
- `image_valid` se deriva del tamaño;
- IMEM no utiliza bitmap de validez;
- `REFERENCE=1024/2048` tiene compromiso físico completo;
- `ALT_1000=1000/1000` valida parametrización mediante elaboración, simulación y smoke tests;
- configuraciones inválidas o válidas no soportadas fallan claramente;
- XPM o primitivas futuras permanecen permitidas si evidencia física las justifica y preservan el contrato;
- control, invalidación concreta, señales, timing, alineación y Debug utilizado permanecen en sus decisiones correspondientes.

**Requisitos afectados:** `REQ-CPU-002` a `REQ-CPU-004`, `REQ-CPU-007`, `REQ-CPU-009`, `REQ-CPU-010`, `REQ-MEM-001` a `REQ-MEM-030`, `REQ-EXEC-009`, `REQ-EXEC-017`, `REQ-EXEC-018`, `REQ-TIM-003` a `REQ-TIM-007`, `REQ-DBG-010`, `REQ-DBG-015`, `REQ-DOC-007`, `REQ-DOC-009`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-ARCH-007 — Temporización del banco de registros

**Estado:** Aprobada

**Dominio:** CPU / Banco de registros

**Fecha de aprobación:** 2026-09-24

**Contexto:** Debía fijarse la interfaz y temporización del banco arquitectónico de 32 registros de 32 bits para un pipeline de cinco etapas, la semántica de lectura y escritura coincidentes, su interacción con forwarding y hazards, el control temporal en RUN/STEP/HOLD/reset/LOAD y las restricciones de implementación FPGA. Los ocho primeros acuerdos cerraron esos contratos funcionales y el noveno fija la verificación mínima y el cierre conceptual.

**Opciones consideradas:** lecturas combinacionales o síncronas con ciclo adicional; coincidencia WB→ID resuelta por bypass explícito o por el modo interno del almacenamiento; escritura solo desde WB o anticipada; primitiva FPGA obligatoria o neutralidad sujeta al contrato; cierre con o sin matriz verificable.

**Decisión:** Aprobar el Register File 32 × 32 con interfaz funcional 2R1W, dos lecturas combinacionales independientes en ID, escritura síncrona válida exclusivamente desde WB en ciclos CPU efectivos y bypass explícito independiente hacia cada lectura coincidente. `x0` siempre se lee como cero y no se escribe ni recibe bypass. El dato posbypass se captura como valor base en ID/EX; la Forwarding Unit sigue prefiriendo el productor más reciente disponible en EX/MEM o MEM/WB, y el hazard `load-use` conserva su stall nominal. Reset, LOAD, RUN, STEP, HOLD y ambos drenados obedecen las prioridades globales aprobadas en `DEC-ARCH-008`; cualquier recurso FPGA debe preservar esta interfaz y temporización. La matriz del noveno acuerdo es criterio mínimo obligatorio de aceptación, no evidencia de una implementación ya verificada.

Los nueve acuerdos de este identificador forman el contrato aprobado:

#### Acuerdo parcial aprobado — interfaz lógica del Register File

**Fecha:** 2026-09-24

El banco arquitectónico contiene **32 registros de 32 bits**, `x0` a `x31`, con una interfaz funcional de **dos puertos de lectura y uno de escritura (2R1W)**. ID dispone de ambas lecturas independientes para obtener simultáneamente los dos operandos fuente cuando la instrucción los usa:

| Puerto funcional | Dirección | Dato |
|---|---|---|
| Lectura 1 | `rs1[4:0]` | `rs1_value[31:0]` |
| Lectura 2 | `rs2[4:0]` | `rs2_value[31:0]` |
| Escritura | `rd[4:0]` | `wb_value[31:0]`, con condición de escritura válida |

Los valores leídos en ID se transportan a ID/EX junto con sus índices conforme a los campos aprobados en `DEC-ARCH-003`. El **único puerto funcional de escritura** recibe su dato, destino y condición de escritura válida desde **WB**, sin escritura arquitectónica anticipada desde EX o MEM, de acuerdo con `DEC-ARCH-002` y los campos de MEM/WB fijados en `DEC-ARCH-003`. Este acuerdo no altera la elegibilidad ya aprobada de escritura válida ni del forwarding externo.

`x0` deberá conservar permanentemente su valor cero conforme a `REQ-CPU-013`; el quinto acuerdo fija lectura cero, ausencia de modificación por intentos de escritura y exclusión del bypass, sin imponer una representación física concreta. Debug no exige aquí un puerto funcional adicional: la observación de los 32 registros podrá definirse mediante snapshot, multiplexado u otro mecanismo compatible con sus decisiones pendientes.

Este primer acuerdo fija solo **interfaz lógica y rutas funcionales**; el segundo fija la lectura combinacional, el tercero la escritura síncrona, el cuarto el valor nuevo observable ante coincidencia WB→ID, el quinto selecciona el bypass interno explícito, el sexto fija su frontera funcional con el forwarding externo y los hazards, el séptimo su integración temporal con los modos globales y el octavo exige que cualquier recurso físico preserve ese contrato. La realización RTL deberá conservar las prioridades de `DEC-ARCH-008`.

#### Acuerdo parcial aprobado — temporización de lectura del Register File

**Fecha:** 2026-09-24

Los dos puertos funcionales de lectura del Register File tendrán **salidas combinacionales en ID**. Los índices obtenidos de `IF/ID.instruction` determinarán directamente `rs1_value[31:0] = RF[rs1]` y `rs2_value[31:0] = RF[rs2]` **cuando no exista una escritura WB efectiva coincidente**; el cuarto acuerdo selecciona en ese caso el nuevo `wb_value` para cada puerto coincidente. La lectura no requiere flanco de clock ni ciclo adicional. La ruta conceptual es `IF/ID.instruction → rs1/rs2 → Register File → rs1_value/rs2_value → ID/EX`.

`ID/EX.rs1_value` y `ID/EX.rs2_value` conservarán funcionalmente los valores originales leídos en ID **solo cuando haya un ciclo CPU efectivo autorizado y corresponda capturar una nueva entrada válida en ID/EX**, de acuerdo con `DEC-ARCH-003` y `DEC-ARCH-008`. Esos valores sirven de respaldo para la selección posterior mediante forwarding; la lectura combinacional no introduce otra etapa ni cambia el contenido físico aprobado de ID/EX. En ciclos que introduzcan una bubble o invaliden la entrada, los bits residuales podrán capturarse o conservarse físicamente, pero no representan operandos de una instrucción válida.

Durante HOLD pueden variar las salidas combinacionales por cambios de sus entradas, pero ID/EX no captura, el pipeline no avanza y el banco no recibe writebacks originados por CPU. La evaluación combinacional por sí sola no produce una transición arquitectónica.

Este segundo acuerdo **solo fija la temporización de lectura**; el tercero fija la escritura síncrona en un ciclo CPU efectivo, el cuarto establece que la lectura ID coincidente observa el nuevo valor de WB y el quinto garantiza esa selección mediante bypass interno explícito. No se depende del modo read-first/write-first/no-change del almacenamiento ni se incorpora una fase física adicional de clock.

#### Acuerdo parcial aprobado — temporización de escritura del Register File

**Fecha:** 2026-09-24

El puerto funcional de escritura utilizará **escritura síncrona**. La escritura arquitectónica normal del CPU se efectuará solo en el flanco activo correspondiente a un **ciclo CPU efectivo autorizado**, con la instrucción y los campos de MEM/WB **previos al flanco**:

```text
if (cpu_effective_cycle && MEM/WB.valid && MEM/WB.reg_write && MEM/WB.rd != x0)
    RF[MEM/WB.rd] ← MEM/WB.wb_value
```

El destino es `MEM/WB.rd[4:0]` y el dato es `MEM/WB.wb_value[31:0]`, exclusivamente desde WB: no se escribe anticipadamente desde EX ni MEM. La instrucción presente en WB puede producir **como máximo una escritura arquitectónica en cada ciclo efectivo válido**. La captura simultánea de una entrada nueva en MEM/WB no sustituye los campos previos usados para el writeback de ese ciclo, de acuerdo con el avance aprobado en `DEC-ARCH-003`; su cuadragésimo tercer acuerdo expresa esta habilitación como `rf_write_fire` y la comparte con la elegibilidad del bypass WB→ID.

Durante **HOLD** no hay ciclo CPU efectivo ni writeback; el banco conserva su estado frente a la ejecución CPU aunque MEM/WB retenga una instrucción válida durante varios clocks físicos. Esa retención no repite la escritura en cada clock, conforme a `DEC-ARCH-008`. Las acciones prioritarias de reset global y preparación de LOAD conservan sus reglas propias: no se confunden con una escritura arquitectónica ordinaria desde WB.

Una entrada sin permiso de escritura arquitectónica no modifica el banco aunque `rd` o `wb_value` conserven bits residuales: stores, branches, `halt`, entradas inválidas o descartadas e instrucciones causantes de fault no producen writeback propio. Las instrucciones anteriores supervivientes a un fault conservan sus escrituras válidas conforme a `DEC-ARCH-004`. Una escritura destinada a `x0` tampoco modifica su valor arquitectónico; el mecanismo físico concreto de protección permanece abierto.

Este tercer acuerdo fija **solo la temporización síncrona y habilitación de la escritura normal del CPU**. El cuarto fija como resultado arquitectónico de una lectura ID coincidente el nuevo dato de WB y el quinto exige un bypass interno explícito para obtenerlo, independiente del modo del almacenamiento físico.

#### Acuerdo parcial aprobado — lectura y escritura simultáneas sobre el mismo registro

**Fecha:** 2026-09-24

Cuando en un **mismo ciclo CPU efectivo** WB tenga una escritura arquitectónica válida a un registro distinto de `x0` y una instrucción en ID lea ese registro, la lectura de ID observará el **nuevo `MEM/WB.wb_value`**, no el valor anterior almacenado. Para cada puerto se aplica independientemente la siguiente selección conceptual, con los campos de MEM/WB anteriores al flanco:

```text
write_enable_efectivo = cpu_effective_cycle && MEM/WB.valid && MEM/WB.reg_write && MEM/WB.rd != x0
rs1_value = (write_enable_efectivo && MEM/WB.rd == rs1) ? MEM/WB.wb_value : RF[rs1]
rs2_value = (write_enable_efectivo && MEM/WB.rd == rs2) ? MEM/WB.wb_value : RF[rs2]
```

Si WB escribe `x5 ← 100` e ID decodifica `add x7, x5, x5`, ambos puertos entregarán `100`. También se seleccionará `wb_value` cuando coincida **solo uno** de los índices; el otro puerto conservará su lectura arquitectónica ordinaria. Cuando corresponda capturar una nueva entrada válida en ID/EX en ese ciclo efectivo, `ID/EX.rs1_value` y `ID/EX.rs2_value` conservarán esos valores base correctos, sobre los que EX aplicará después el forwarding de productores más recientes conforme a `DEC-ARCH-003`.

No existe escritura arquitectónica ni selección de `wb_value` por mera coincidencia de bits si falta el ciclo efectivo, `MEM/WB.valid` o `MEM/WB.reg_write`, o si `MEM/WB.rd = x0`. Toda lectura de `rs1=x0` o `rs2=x0` entrega **cero**, incluso si WB presenta datos residuales para `x0`; `x0` queda excluido de la coincidencia WB→ID. HOLD no produce writeback ni captura ID/EX aunque puedan evaluarse señales combinacionales, conforme a `DEC-ARCH-008`. Instrucciones invalidadas o causantes de fault no aportan escrituras propias, preservando `DEC-ARCH-004`.

Este cuarto acuerdo fija **solo la semántica observable**: WB escribe `R` e ID lee `R` en el mismo ciclo efectivo → ID observa el nuevo valor. El quinto fija un bypass interno explícito `WB → Read Ports` independiente de la semántica del almacenamiento; el sexto fija su frontera funcional con forwarding externo y hazards y el octavo obliga a respetarla con cualquier primitiva física.

#### Acuerdo parcial aprobado — bypass interno explícito `WB → ID`

**Fecha:** 2026-09-24

La selección del valor nuevo de WB se implementará mediante un **bypass combinacional explícito hacia cada puerto de lectura** del Register File. Se usan los campos estables de MEM/WB previos al flanco y la condición efectiva de escritura arquitectónica del CPU ya aprobada, no una propiedad `write-first`, `read-first`, `no-change` u otra del recurso físico:

```text
wb_write_enable = cpu_effective_cycle && MEM/WB.valid && MEM/WB.reg_write && MEM/WB.rd != x0
bypass_rs1 = wb_write_enable && MEM/WB.rd == rs1
bypass_rs2 = wb_write_enable && MEM/WB.rd == rs2

rs1_value = bypass_rs1 ? MEM/WB.wb_value : RF[rs1]
rs2_value = bypass_rs2 ? MEM/WB.wb_value : RF[rs2]
```

Ambas selecciones son **independientes**: solo una puede coincidir, ambas pueden recibir `wb_value` si `rs1 = rs2 = MEM/WB.rd`, o ninguna puede coincidir. `ID/EX.rs1_value` e `ID/EX.rs2_value` conservarán funcionalmente los valores **posteriores a la selección** cuando se capture una nueva entrada válida en un ciclo efectivo, aunque difieran de las salidas crudas del almacenamiento físico. En ese mismo ciclo, el writeback normal modifica síncronamente el registro destino en el flanco usando los campos previos de MEM/WB; no requiere una etapa adicional ni captura de la nueva entrada de MEM/WB como fuente anticipada.

**Protección funcional de `x0`:** leer `rs1=x0` o `rs2=x0` siempre devuelve cero; un intento de escribir `rd=x0` **no modifica el banco ni activa ningún bypass**, aun si `wb_value` conserva bits residuales. `wb_write_enable` falso por HOLD, invalidez o ausencia de permiso de escritura tampoco activa el bypass por coincidencia de índices; durante HOLD no se capturan valores en ID/EX ni se realiza writeback. Se conserva la prioridad de reset/LOAD sobre ciclos CPU de `DEC-ARCH-008` y la ausencia de efectos propios de instrucciones causantes de fault de `DEC-ARCH-004`.

El bypass interno `WB → ID` selecciona los **valores base** leídos en ID, no reemplaza los muxes de forwarding externo `ID/EX`, `EX/MEM` y `MEM/WB` hacia EX aprobados en `DEC-ARCH-003`. El sexto acuerdo fija que la selección final en EX sigue prefiriendo al productor pendiente más reciente y que el bypass no evita ni crea stalls. Este quinto acuerdo fija el mecanismo interno y la protección funcional de `x0`, sin imponer nombres de señales RTL definitivas ni representación física del almacenamiento de `x0`.

#### Acuerdo parcial aprobado — interacción entre bypass interno y forwarding externo

**Fecha:** 2026-09-24

El bypass interno **`WB → ID`** resuelve exclusivamente coincidencias de escritura arquitectónica en WB y lectura del mismo registro en ID durante el mismo ciclo efectivo. Su resultado **posbypass** queda como valor base en `ID/EX.rs1_value` o `ID/EX.rs2_value` cuando corresponda capturar una nueva entrada válida. No reemplaza la Forwarding Unit ni sus muxes externos hacia EX aprobados en `DEC-ARCH-003`.

Al llegar la consumidora a EX, cada fuente usada continúa eligiendo la versión más reciente según **EX/MEM disponible > MEM/WB disponible > valor base de ID/EX**. Si un productor coincidente en EX/MEM es más reciente pero su dato aún no está disponible, la consumidora debe esperar: el valor base ya corregido por WB→ID **no** autoriza usar una versión anterior. Por ejemplo, con `I1` escribiendo `x5 = 10` en WB e `I2` más reciente produciendo `x5 = 20`, una `I4` que lea `x5` en ID puede capturar `ID/EX.rs1_value = 10` mediante bypass interno; cuando alcance EX, usará **20** si `I2` es el productor pendiente más reciente y su resultado está disponible para forwarding. La selección también se aplica independientemente a `rs2` cuando la instrucción la use.

El bypass interno **no elimina el stall `load-use`**: en `lw x5, ...; add x6, x5, x7`, el load en EX/MEM aún no puede entregar el dato cargado a EX; se mantiene la bubble y retención nominal de un ciclo y luego se reenvía desde MEM/WB conforme a `DEC-ARCH-003`. Tampoco sustituye la Forwarding Unit ni introduce un stall adicional. Si WB es el único productor relevante para una lectura coincidente en ID, el bypass ya entrega el dato correcto y **no se exige un stall adicional por esa coincidencia**.

Este sexto acuerdo fija la **frontera funcional**: WB→ID suministra el valor base; forwarding hacia EX decide el operando efectivo final por productor más reciente y disponibilidad. El séptimo aplica a esos caminos las condiciones temporales de RUN, STEP, HOLD, reset y nueva sesión, subordinadas a las reglas globales **ya aprobadas** en `DEC-ARCH-008`. No se modifican los stalls, prioridades, muxes ni campos de latches de `DEC-ARCH-003`.

#### Acuerdo parcial aprobado — comportamiento bajo RUN, STEP, HOLD, reset y nueva sesión

**Fecha:** 2026-09-24

El Register File aplicará la jerarquía conceptual **reset global > LOAD aceptado/preparación de sesión > ciclo CPU efectivo > HOLD**, ya aprobada en `DEC-ARCH-008`. La inicialización de sesión y el reset no se confunden con una escritura arquitectónica ordinaria de WB. `x0` conserva permanentemente cero bajo todos estos modos.

| Contexto | Comportamiento del Register File |
|---|---|
| **RUN** | En cada ciclo CPU efectivo, la instrucción **previa al flanco** en MEM/WB puede comprometer como máximo una escritura si `valid`, `reg_write` y `rd != x0`; un clock físico sin ciclo efectivo no repite la escritura. |
| **STEP** | Cada STEP aceptado autoriza exactamente **un** ciclo efectivo y cero o una escritura elegible de MEM/WB; otro writeback requiere un ciclo efectivo posterior autorizado por otro STEP. |
| **HOLD** | No hay writeback CPU; el banco conserva íntegramente su estado aunque MEM/WB retenga `valid`, `reg_write`, `rd` y `wb_value` durante múltiples clocks físicos. El write-enable efectivo es cero. |
| **Reset global** | Cuando el reset funcional toma efecto conforme a `DEC-ARCH-008`, `x0…x31` quedan **lógicamente en cero**. Reset prevalece sobre cualquier writeback CPU coincidente: ese writeback no se compromete. |
| **LOAD aceptado / preparación de sesión** | No se producen writebacks normales del pipeline CPU. Antes del commit de la nueva sesión, `x0…x31` quedan **lógicamente en cero**; una carga confirmada deja el CPU preparado sin iniciar RUN ni STEP. |
| **`HALT_DRAIN` / `FAULT_DRAIN`** | Las instrucciones anteriores válidas que sobreviven a la frontera pueden escribir al llegar a WB **solo en ciclos efectivos**; bajo contexto RUN el drenado progresa automáticamente y bajo paso a paso cada ciclo requiere un STEP nuevo. |

En un ciclo efectivo, el writeback elegible usa los campos **anteriores al flanco** de MEM/WB y no se duplica por retenerlos en HOLD; el bypass interno WB→ID solo se habilita para una escritura CPU realmente elegible. Reset o LOAD/preparación inhiben ese commit aunque MEM/WB conserve datos anteriores. Las instrucciones causantes de fault y las posteriores descartadas no escriben, mientras las anteriores supervivientes conservan su writeback una vez cuando corresponda, según `DEC-ARCH-004`. La finalización normal por `halt` tampoco detiene prematuramente las escrituras anteriores de su drenado. La validez del pipeline y los modos no habilitan por sí mismos escrituras fuera de ciclos efectivos.

El reset global deja al banco **lógicamente** en cero cuando toma efecto funcional; la preparación de LOAD garantizará ese mismo valor antes de publicar el commit de la nueva imagen. No se fija un clear paralelo, el borrado inmediato de todos los bits físicos ni otra técnica particular: cualquier realización debe preservar los valores observables y la prioridad aprobada. Los posibles ciclos de mantenimiento de LOAD no constituyen ciclos efectivos ni writebacks del pipeline CPU.

Este séptimo acuerdo fija la **integración temporal** del Register File con los modos globales. El octavo fija que cualquier tecnología física y sus detalles RTL deben preservarla, sin reabrir la semántica de `DEC-ARCH-008` ni el bypass y forwarding ya acordados.

#### Acuerdo parcial aprobado — contrato de implementación física en FPGA

**Fecha:** 2026-09-24

`DEC-ARCH-007` **no impone una primitiva física específica** para el Register File: registros, distributed RAM, LUT RAM, BRAM u otro recurso equivalente son admisibles únicamente si su realización conserva el contrato observable de los acuerdos anteriores. La elección concreta podrá realizarse después según utilización de FPGA, frecuencia alcanzable y resultados de síntesis, sin cambiar la arquitectura.

En cualquier realización deben mantenerse **32 registros de 32 bits**, dos lecturas simultáneas **combinacionales en ID**, un puerto de escritura **síncrona desde WB**, bypass combinacional explícito **WB→ID** por puerto, `x0` siempre igual a cero, ausencia de writeback en HOLD, ciclos CPU efectivos para RUN, STEP y drenados, y cero lógico del banco tras el reset funcional y antes del commit de una nueva sesión. El recurso elegido no puede cambiar silenciosamente la temporización, la interfaz 2R1W ni la prioridad global aprobada en `DEC-ARCH-008`.

Una primitiva que requiera **presentar la dirección, esperar un flanco y después obtener el dato** no puede sustituir directamente la lectura combinacional de ID si añade un ciclo o altera el pipeline. Se utilizará otra realización o lógica adicional que conserve exactamente los valores y tiempos aprobados, sin introducir otra etapa o un ciclo CPU oculto. La escritura normal sigue tomando los campos previos al flanco de MEM/WB en un ciclo efectivo, sin duplicarse por retención en HOLD.

La corrección de la lectura y escritura simultáneas del mismo registro **no dependerá** de si la memoria física es `write-first`, `read-first`, `no-change` u otra: el bypass explícito WB→ID seleccionará el nuevo `wb_value` para cada puerto coincidente cuando haya escritura efectiva, conforme al quinto acuerdo. El recurso físico es una elección de implementación; la interfaz y temporización observables son obligatorias.

Este octavo acuerdo fija la **neutralidad de primitiva y las restricciones de toda implementación FPGA**. El noveno acuerdo cierra los **casos límite, la matriz mínima de verificación y la decisión arquitectónica**; la selección concreta del recurso y las ecuaciones RTL finales quedarán para la implementación, sin reabrir estos acuerdos.

#### Acuerdo aprobado — verificación mínima y cierre

**Fecha:** 2026-09-24

La implementación de `DEC-ARCH-007` deberá superar como mínimo la siguiente matriz. Son **criterios de aceptación**, no resultados de pruebas ya ejecutadas:

| Área | Caso mínimo | Resultado esperado |
|---|---|---|
| Estructura | Acceso a `x0...x31` | Existen 32 registros arquitectónicos de 32 bits. |
| Lecturas simultáneas | `rs1 != rs2` | Ambos valores están disponibles simultáneamente en ID. |
| Misma fuente | `rs1 = rs2` | Ambos puertos entregan el mismo valor correcto. |
| Lectura combinacional | Cambio de `rs1`/`rs2` en ID | Las salidas reflejan el registro seleccionado dentro del mismo ciclo, sin flanco adicional. |
| Escritura síncrona | WB válido escribe `rd` | El estado almacenado cambia únicamente en el flanco de un ciclo CPU efectivo. |
| Entrada inválida | `MEM/WB.valid = 0` | No se modifica ningún registro. |
| Sin escritura arquitectónica | `reg_write = 0` | No se modifica ningún registro. |
| Protección de `x0` | Intento de escribir `x0` | `x0` permanece en cero. |
| Lectura de `x0` | `rs1=0` o `rs2=0` | Se obtiene `0x00000000`. |
| Bypass WB→ID en `rs1` | WB escribe el registro leído como `rs1` | ID recibe `wb_value` en ese puerto. |
| Bypass WB→ID en `rs2` | WB escribe el registro leído como `rs2` | ID recibe `wb_value` en ese puerto. |
| Bypass en ambos puertos | `rs1 = rs2 = wb_rd` | Ambos puertos reciben `wb_value`. |
| WB dirigido a `x0` | `wb_rd = 0` | No se activa bypass; las lecturas de `x0` permanecen en cero. |
| Productor más reciente | Coincidencia con WB y productor posterior en EX/MEM | EX utiliza el productor pendiente más reciente mediante forwarding cuando su dato esté disponible. |
| `load-use` | Load seguido inmediatamente por consumidor | Se conserva el stall nominal ya aprobado y después se utiliza el dato cargado. |
| Coincidencia solo con WB | Productor relevante únicamente en WB | El bypass interno evita un stall adicional. |
| HOLD | Escritor válido permanece físicamente en WB durante varios clocks sin ciclo efectivo | El Register File conserva su estado; no se produce ni se repite writeback. |
| STEP | Un STEP aceptado con escritor válido en WB | Se compromete exactamente el writeback elegible de ese ciclo efectivo, sin otro hasta un nuevo STEP. |
| RUN | Ciclos efectivos sucesivos | Cada escritor válido compromete como máximo una vez por ciclo efectivo. |
| Reset | Reset funcional coincide con WB válido | Reset prevalece y `x0...x31` quedan lógicamente en cero; no hay writeback coincidente. |
| Nueva sesión | Finaliza correctamente la preparación de LOAD | El banco queda lógicamente en cero antes del commit y de ejecutar la nueva imagen. |
| Drenado | Instrucción anterior válida alcanza WB en `HALT_DRAIN` o `FAULT_DRAIN` | Puede escribir exactamente una vez durante un ciclo efectivo autorizado por RUN o un STEP nuevo. |
| Implementación física | Cambio de primitiva manteniendo el contrato | No cambia la semántica ni aparece latencia adicional de lectura. |

En HOLD se verificará expresamente la conservación del estado del banco y la ausencia de **writebacks repetidos** durante clocks físicos sin ciclo efectivo, aunque MEM/WB retenga una instrucción escritora, conforme a `DEC-ARCH-008`. Las pruebas de productor más reciente y `load-use` comprueban la frontera de este banco con `DEC-ARCH-003`; no cierran su implementación RTL restante.

##### Contrato consolidado de `DEC-ARCH-007`

```text
Register File: 32 registros × 32 bits; interfaz funcional 2R1W.
Lectura: dos puertos combinacionales simultáneos en ID.
Escritura: síncrona desde WB, solo en un ciclo CPU efectivo
           con MEM/WB.valid, MEM/WB.reg_write y rd != x0;
           datos y controles previos al flanco.
Coincidencia WB → ID: cada puerto coincidente observa wb_value
                     mediante bypass combinacional explícito.
x0: lectura siempre cero, escrituras ignoradas, bypass inhibido.
ID/EX: conserva el valor base posbypass cuando captura entrada válida.
Forwarding EX: EX/MEM disponible > MEM/WB disponible > base de ID/EX;
               si el productor más reciente aún no tiene dato, esperar.
load-use: conserva el stall nominal y el forwarding posterior.
HOLD: sin writeback; banco inalterado aun con WB retenida.
RUN, STEP y drenados: writeback solo en ciclos CPU efectivos autorizados.
Reset funcional / nueva sesión: x0...x31 lógicamente en cero;
                                 LOAD preparado antes del commit.
FPGA: primitiva libre, sujeta a conservar toda la semántica y temporización.
```

Quedan **resueltas las ocho subdecisiones**: interfaz lógica, lectura, escritura, lectura/escritura simultáneas, bypass explícito WB→ID, interacción con forwarding y hazards, modos/reset/nueva sesión, neutralidad de implementación física y verificación mínima. `DEC-ARCH-007` queda **conceptualmente cerrada y aprobada**. La implementación RTL posterior de la política de hazards y control aprobada en `DEC-ARCH-003` deberá preservar este contrato.

**Justificación:** La lectura combinacional y el bypass explícito evitan depender de una primitiva FPGA o de su modo de colisión; escribir desde WB solo en ciclos efectivos mantiene resultados precisos y evita commits duplicados en HOLD. La matriz mínima permite comprobar los casos límite de interfaz, prioridad de productores y modos antes de aceptar una implementación.

**Consecuencias:** El banco y la integración con el pipeline deben superar los 23 casos mínimos sin introducir latencia extra ni alterar los stalls o el control global aprobados. La elección concreta de almacenamiento, protección física de `x0`, detalles RTL y observabilidad Debug siguen siendo detalles de implementación o de sus decisiones correspondientes; no se requiere una primitiva FPGA ni un puerto funcional extra. `DEC-ARCH-003` se aprobó después y conserva su dependencia de esta decisión.

**Requisitos afectados:** `REQ-CPU-005`, `REQ-CPU-008`, `REQ-CPU-012`, `REQ-CPU-013`, `REQ-CPU-016`, `REQ-HAZ-002` a `REQ-HAZ-006`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-ARCH-008 — Reset y enables

**Estado:** Aprobada

**Dominio:** CPU / Control global

**Fecha de aprobación:** 2026-09-22

**Contexto:** Debían fijarse la semántica global de reset, LOAD, RUN, STEP y HOLD; sus prioridades; las condiciones conceptuales de avance y commit; el ownership exclusivo de memorias; y una vía mínima de recuperación para RUN, sin convertir nombres explicativos en una FSM o interfaz RTL obligatoria. Los acuerdos consolidados separan reset global de inicialización de sesión, adoptan aserción asíncrona y desaserción sincronizada para el reset distribuido, fijan su polaridad y alcance, descartan un debouncer obligatorio inicial, seleccionan reset como recuperación mínima, rechazan LOAD durante ejecución continua y definen ciclos efectivos, HOLD, preparación y commit de sesión. Conforme a `DEC-ARCH-006`, el contrato garantiza un único agente por memoria, evita stores o escrituras duplicadas y bloquea LOAD, RUN y STEP hasta cumplir sus precondiciones, dejando la realización concreta para implementación.

**Opciones consideradas:**

1. Sincronizar aserción y desaserción, o asertar asíncronamente y liberar de forma sincronizada.
2. Unificar reset global e inicialización de sesión, o mantenerlos conceptualmente separados.
3. Aceptar LOAD durante RUN como aborto implícito, o rechazarlo y disponer de recuperación explícita.
4. Exigir una FSM, grants y enables concretos, o fijar únicamente el contrato observable.
5. Incorporar un debouncer obligatorio, o dejarlo como acondicionamiento opcional basado en evidencia física.

**Decisión:** Se aprueba el siguiente contrato consolidado.

#### 1. Separación entre reset global e inicialización de sesión

El reset global y la inicialización de una nueva sesión serán mecanismos conceptualmente distintos.

##### Reset global

El reset global llevará al sistema a un estado seguro sin programa ejecutable confirmado ni sesión activa. Su alcance funcional concreto queda establecido por la sección 3.

El sistema deberá quedar en una condición suficiente para aceptar posteriormente una operación de carga. Reset global e inicialización de sesión continuarán siendo eventos distintos aunque compartan mecanismos internos.

##### Inicialización y commit de una nueva sesión

Una nueva sesión podrá prepararse sin aplicar el reset global completo. Recibir y validar la imagen completa no constituirá por sí solo una carga exitosa. Antes del commit deberán estar preparados coherentemente:

```text
imagen completa recibida y validada
PC = 0x00000000
x0 ... x31 = 0
pipeline sin instrucciones válidas
DMEM lógicamente en cero
conjunto lógico de memoria utilizada vacío
contador lógico de ciclo = 0
estado de ejecución preparado pero detenido
```

Desde la aceptación de LOAD y durante toda la recepción, validación y preparación se mantendrá:

```text
loaded_image_size_bytes = 0
image_valid = 0
```

El único write no nulo de `loaded_image_size_bytes` constituirá el commit completo de sesión y ocurrirá solo cuando la imagen y todo el estado inicial requerido estén preparados. `image_valid` pasará entonces a uno por derivación combinacional. Esta frontera deberá exponer un estado coherente, pero no fija el orden interno ni obliga a que toda la preparación ocurra en un único ciclo.

Una carga vacía, truncada, inválida, sobredimensionada, interrumpida o fallida después de su aceptación no producirá el commit. Una solicitud rechazada antes de ser aceptada conservará la imagen vigente. RUN y STEP no harán avanzar la CPU antes del commit, y completarlo no iniciará automáticamente ninguno de esos modos.

La inicialización de sesión podrá reutilizar mecanismos internos empleados también por reset sin ser conceptualmente equivalente a aplicar el reset global. No se exige borrar físicamente las memorias ni reiniciar recursos ajenos al estado lógico requerido. IMEM podrá conservar residuos fuera de la imagen confirmada y DMEM podrá conservar datos anteriores siempre que no sean lógicamente válidos para la nueva sesión.

##### Aspectos diferidos sin bloquear la decisión

Esta decisión no fija:

- pin o fuente física definitiva de reset;
- nombres de puertos, codificación binaria de estados y FSM privadas; la FSM global se rige por el acuerdo 44;
- duración u orden temporal interno de la preparación;
- mecanismo, paralelismo o señales de invalidación DMEM;
- secuencias RTL concretas de ownership, grants o enables;
- tratamiento temporal de colisiones internas;
- secuencia temporal precisa de fault, que corresponde a las decisiones de pipeline, hazards, control y protocolo.

Estos puntos son detalles de implementación, integración o decisiones dependientes y no impiden cerrar `DEC-ARCH-008`.

#### 2. Estrategia temporal del reset global

La fuente física de reset podrá cambiar de estado sin relación temporal con el clock principal. Cualquiera sea su polaridad eléctrica, el wrapper la normalizará a una solicitud conceptual activa en alto antes del sincronizador, denominada aquí `reset_request_async` solo con fines descriptivos.

La señal externa sin acondicionar no se distribuirá directamente a CPU, pipeline, control, enables ni otros registros funcionales. La cadena de reset se asertará asíncronamente y su liberación se sincronizará respecto del dominio funcional principal.

##### Sincronizador de referencia

La implementación de referencia utilizará una cadena de dos etapas o un mecanismo funcionalmente equivalente:

```systemverilog
(* ASYNC_REG = "TRUE" *) logic [1:0] reset_sync;

always_ff @(posedge clk or posedge reset_request_async) begin
    if (reset_request_async)
        reset_sync <= 2'b11;
    else
        reset_sync <= {reset_sync[0], 1'b0};
end

assign reset = reset_sync[1];
```

El código es ilustrativo. La sintaxis, el nombre de las señales y el atributo específico de herramienta serán detalles de implementación. El atributo no sustituirá la revisión de CDC ni las restricciones temporales correspondientes.

Partiendo de un estado desasertado conocido, una solicitud externa válida producirá conceptualmente:

```text
aserción:     00 -> 11, sin esperar un flanco
desaserción:  11 -> 10 -> 00
```

La aserción utilizará el recurso asíncrono de ambas etapas para llevar inmediatamente la cadena y el reset distribuido al estado activo. Al retirar la solicitud, el cero atravesará las dos etapas; así la desaserción solo ocurrirá como resultado de flancos activos y no expondrá directamente la liberación asíncrona a la lógica funcional.

Dos etapas constituirán la implementación de referencia mínima. Podrá utilizarse un mecanismo equivalente con latencia distinta si documenta y verifica aserción asíncrona y liberación sincronizada.

##### Consumo por la lógica funcional

CPU, pipeline y control consumirán el reset interno de forma síncrona:

```systemverilog
always_ff @(posedge clk) begin
    if (reset)
        state <= RESET_VALUE;
    else
        state <= next_state;
end
```

Los efectos funcionales ocurrirán en el flanco en que cada registro observe activo el reset interno. No se adoptará como política general un reset asíncrono en los registros funcionales del procesador.

El reset distribuido podrá asertarse entre flancos, pero sus efectos sobre CPU, pipeline y control ocurrirán en el primer `posedge clk` en el que cada registro funcional lo observe activo. La desaserción sincronizada evita liberar esos consumidores directamente desde una transición externa asíncrona.

##### Límites y aspectos diferidos a integración

El acondicionador no garantiza pulsos externos que incumplan el ancho mínimo del recurso asíncrono ni constituye por sí mismo un debouncer. La fuente externa deberá cumplir los requisitos eléctricos y temporales del dispositivo; el valor concreto dependerá del clock, dispositivo y placa y se documentará en integración. La inicialización física de los registros al configurar la FPGA no se utilizará como sustituto de un evento de reset válido.

La relación semántica entre estabilidad indicada por `locked` y solicitud/liberación de reset se fija en el acuerdo parcial de `DEC-ARCH-005`; su conexión y temporización concretas corresponden a integración física. Su acuerdo parcial de dominio funcional establece un único clock para la implementación inicial; introducir otro dominio interno exigiría revisar esa decisión y documentar su CDC.

Esta subdecisión define la estrategia temporal del reset. Los acuerdos siguientes fijan alcance, prioridad y recuperación; su realización RTL concreta permanece libre mientras preserve el contrato.

#### 3. Alcance funcional del reset global

Este acuerdo reemplaza únicamente el alcance mínimo del reset global que figuraba en la primera subdecisión. No modifica la separación entre reset e inicialización de sesión, el commit atómico de LOAD ni la estrategia de sincronización aprobada.

Los efectos siguientes se aplicarán en el flanco activo en el que la lógica funcional observe activo el reset distribuido; no se producirán directamente por una transición de la entrada física asíncrona.

##### Estado funcional obligatorio

Como mínimo, el reset global establecerá:

```text
PC                         = 0x00000000
x0 ... x31                 = 0
contador lógico de ciclo   = 0
IF/ID.valid                = 0
ID/EX.valid                = 0
EX/MEM.valid               = 0
MEM/WB.valid               = 0
estado de ejecución        = sin ejecución activa y sin imagen válida
loaded_image_size_bytes    = 0
image_valid                = 0, por derivación
control interno            = condición segura sin operaciones pendientes
```

No existirá una sesión activa después del reset. RUN y STEP no producirán ejecución válida hasta que un LOAD posterior complete la preparación y el commit de una nueva sesión.

##### Instruction Memory

El reset global no borrará obligatoriamente Instruction Memory. Las instrucciones físicas residuales no serán ejecutables porque `loaded_image_size_bytes = 0` y, por derivación, `image_valid = 0`. Un LOAD posterior escribirá la nueva imagen y solo su commit completo publicará nuevamente un tamaño no nulo.

##### Data Memory y metadata

El reset global no borrará obligatoriamente el array físico de datos de DMEM ni deberá preparar inmediatamente su cero lógico para una nueva sesión. Los datos y la metadata podrán conservar residuos físicos, que no pertenecerán a una sesión ejecutable.

La inicialización de sesión deberá establecer antes de su commit la semántica según la cual todo byte todavía no escrito en esa sesión se lee como cero. La preparación podrá utilizar invalidación paralela, secuencial, una FSM de mantenimiento, tags de generación u otra técnica equivalente permitida por `DEC-ARCH-006`; este acuerdo no selecciona una.

El reset global no estará obligado a invalidar toda la metadata DMEM en un único ciclo ni a utilizar esa metadata como criterio de memoria utilizada por Debug.

##### Banco de registros y pipeline

Los registros arquitectónicos `x0` a `x31` quedarán lógicamente en cero. `x0` continuará siendo permanentemente cero independientemente del reset.

Los cuatro registros intermedios del pipeline quedarán lógicamente vacíos mediante sus bits de validez en cero. Los restantes campos podrán conservar bits físicos residuales y no se interpretarán como instrucciones activas mientras `valid = 0`.

##### Ejecución, control y Debug

El reset eliminará cualquier condición activa perteneciente a una ejecución anterior: RUN, STEP pendiente, drenado por `halt`, finalización normal, fault no persistente y LOAD parcial. Las FSMs y registros de control quedarán en estados seguros desde los cuales puedan aceptar las operaciones posteriores permitidas. Ninguna transacción anterior podrá producir efectos arquitectónicos después de que el reset funcional haya tomado efecto.

El acuerdo siguiente fija qué acción prevalece cuando reset coincide con otro enable. La estructura RTL concreta que implemente esa prioridad será un detalle de implementación, pero el estado observable posterior deberá satisfacer este contrato.

Debug deberá representar coherentemente el PC, banco de registros, contador, validez del pipeline, estado de ejecución y ausencia de imagen después del reset. Una operación o snapshot anterior no podrá presentarse sin distinción como estado actual. El valor, disponibilidad o interpretación del campo de memoria utilizada cuando no existe una sesión activa permanecerá pendiente para `DEC-SYS-005` y las decisiones de protocolo.

##### Diferencia respecto de la inicialización de sesión

El reset deja al sistema seguro, detenido y sin imagen ejecutable. La inicialización de sesión deberá además recibir y validar una imagen, preparar el cero lógico de DMEM y el criterio de memoria utilizada, y efectuar el commit que habilita posteriormente RUN o STEP. Podrá reutilizar parte de la lógica de reset sin ser equivalente a aplicarlo.

#### 4. Prioridad entre reset, LOAD y avance normal

Se adopta la siguiente prioridad conceptual global:

```text
1. RESET GLOBAL
2. LOAD ACEPTADO / PREPARACIÓN DE SESIÓN
3. CICLO EFECTIVO DE CPU
4. HOLD
```

Los nombres `session_init` y `cpu_enable` podrán utilizarse para explicar esta jerarquía, pero no serán señales RTL, puertos ni árboles físicos de enable obligatorios. Una FSM, enables distribuidos u otra realización equivalente será válida si preserva la misma semántica.

Este acuerdo global no imponía una estructura; el cuadragésimo cuarto acuerdo de `DEC-ARCH-003` selecciona posteriormente una FSM Moore de 14 estados y `Cycle Authorization` separado, sin alterar la jerarquía. En el flanco `PREPARING_RUN/STEP && prepare_done`, la preparación **ya concluyó antes del flanco** y no realiza escrituras concurrentes, por lo que corresponde a la clase ciclo CPU efectivo.

##### Prioridad de reset global

Reset dominará cualquier LOAD, mantenimiento, ciclo de CPU o HOLD coincidente. En el flanco dominado por reset:

- el estado alcanzará los valores definidos por el acuerdo de alcance funcional;
- no se aceptará ni confirmará un LOAD;
- un LOAD previamente aceptado quedará abandonado;
- no se escribirá un tamaño de imagen no nulo;
- ninguna instrucción, escritura del loader ni operación de mantenimiento producirá un nuevo efecto.

Reset es además la vía mínima obligatoria de recuperación invocable durante RUN definida en el acuerdo consolidado posterior.

##### LOAD aceptado y preparación de sesión

La segunda clase comenzará únicamente cuando una solicitud LOAD haya sido aceptada y abarcará:

```text
recepción de la imagen
reconstrucción y escrituras de IMEM
validación de la imagen
preparación lógica de DMEM
preparación del restante estado inicial
commit completo o fallo
```

Una solicitud LOAD no será aceptada mientras ya exista contexto de ejecución continua, incluido su drenado automático. Una solicitud rechazada no entra en esta clase, no invalida por sí sola la imagen vigente y no suprime el avance normal de RUN.

Una vez aceptado LOAD, ninguna solicitud RUN o STEP producirá un ciclo efectivo de CPU. No ocurrirán writebacks, stores ni incrementos del contador pertenecientes a la ejecución anterior. Loader y mantenimiento podrán progresar mediante sus propios enables y ownership, independientes de la autorización de avance del CPU.

Solo el commit completo terminará exitosamente esta clase y publicará un valor no nulo de `loaded_image_size_bytes`. Un fallo la terminará sin sesión válida y sin habilitar avance de CPU.

##### Ciclo efectivo de CPU

Un ciclo efectivo solo podrá autorizarse cuando exista una sesión confirmada y el control se encuentre en RUN, ante un STEP aceptado o en drenado habilitado conforme al modo de ejecución vigente.

En RUN podrán autorizarse ciclos sucesivos. Cada STEP aceptado autorizará exactamente un ciclo, incluso durante drenado. En drenado continuo los ciclos progresarán automáticamente; en drenado paso a paso continuará requiriéndose un STEP por ciclo, conforme a `DEC-SYS-001`.

La autorización global de un ciclo no obliga a actualizar todos los elementos del pipeline. Un stall seguirá siendo un ciclo efectivo y contará una vez aunque la lógica local retenga PC o latches, inserte una burbuja o permita avanzar solo un subconjunto. La política concreta de enables locales, forwarding, stalls, bubbles y flushes corresponde a `DEC-ARCH-003`.

Los writebacks, stores y actualizaciones de metadata originados por CPU deberán quedar cualificados por el ciclo efectivo y por la validez local correspondiente. Ninguno podrá repetirse por cada flanco físico durante una espera ni comprometerse más de una vez por el mismo avance lógico.

El cuadragésimo tercer acuerdo de `DEC-ARCH-003` fija después `rf_write_fire`, `dmem_store_fire`, `dmem_metadata_write_fire`, `fault_capture_fire` y `cycle_counter_increment=cpu_cycle_fire`. El cuadragésimo cuarto **revisa** sus escrituras registradas de `terminal_kind`/`drain_auto`, reemplazándolas por transiciones de FSM, y fija en un bloque separado la autorización de `cpu_cycle_fire`. Conserva commits anteriores válidos ante fronteras jóvenes y enables propios de loader/mantenimiento.

El contador lógico incrementará exactamente una vez por cada ciclo efectivo, incluidos stalls habilitados y drenado, y no por actividad exclusiva de UART, loader o mantenimiento.

##### HOLD

Cuando no exista reset, LOAD aceptado ni ciclo efectivo, el plano de ejecución CPU se encontrará en HOLD. PC, registros de pipeline, estado asociado al avance y contador conservarán su valor, sin writebacks, stores ni otros commits originados por CPU.

La sección siguiente precisa qué estado queda congelado, qué actividad externa puede continuar y desde qué situaciones resulta legal autorizar posteriormente otro ciclo.

##### Clock principal

La jerarquía se implementará mediante selección de próximo estado y enables síncronos. No se detendrá, gateará arbitrariamente ni generará manualmente el clock principal para implementar RUN, STEP, LOAD o HOLD. Ninguna de estas condiciones detendrá el clock cuando el generador proporcione flancos válidos; la pérdida de estabilidad se trata por reset global según `DEC-ARCH-005`.

#### 5. Semántica de HOLD y actividad permitida

Dentro de la clase de menor prioridad, HOLD será la condición en la que no ocurre un ciclo efectivo del CPU. Reset y LOAD aceptado tampoco producen ciclos CPU, pero conservan sus semánticas propias y no se reclasifican como HOLD. No será obligatorio representar HOLD mediante un modo RTL específico ni mediante una señal global denominada `cpu_enable = 0`.

##### Plano de ejecución congelado

Mientras no exista una acción de mayor prioridad ni un ciclo efectivo autorizado, conservarán su valor:

```text
PC
banco de registros arquitectónicos
IF/ID
ID/EX
EX/MEM
MEM/WB
contador lógico de ciclo
estado microarquitectónico cuyo progreso pertenece al CPU
progreso de drenado
estado de fault o finalización ya alcanzado
```

Durante HOLD no se capturará una instrucción nueva, no avanzará el pipeline y no se reconocerá ni progresará un nuevo evento de `halt`, fault o drenado. Tampoco se producirán writebacks, stores, actualizaciones de metadata originadas por CPU ni incrementos del contador.

Una instrucción podrá permanecer retenida en una etapa con un efecto pendiente, pero no lo repetirá durante los clocks físicos de espera. Cuando posteriormente se autorice un ciclo legal, el efecto podrá comprometerse una sola vez conforme a su validez y enable local.

##### Plano de control activo

El congelamiento anterior no se aplicará indiscriminadamente al plano de control externo. Mientras el CPU permanece sin avance podrán continuar:

- acondicionamiento del reset;
- UART RX y UART TX;
- recepción y decodificación de comandos;
- control necesario para aceptar un RUN o STEP legal o para evaluar una solicitud LOAD;
- captura, almacenamiento auxiliar y serialización de Debug;
- respuestas y demás lógica externa al avance del pipeline.

Estos cambios no constituirán ciclos efectivos ni incrementarán el contador. Si se acepta una acción de mayor prioridad o se autoriza un ciclo legal, el sistema abandonará HOLD y aplicará la clase correspondiente de la jerarquía global.

El acceso Debug continuará sujeto a coherencia y ownership. Su actividad no podrá modificar incorrectamente el estado funcional observado.

##### Memorias y lógica combinacional

No se exigirá que las señales combinacionales permanezcan físicamente constantes. IMEM, DMEM, ALU, comparadores, muxes, forwarding y detección de hazards podrán continuar evaluándose.

Las lecturas combinacionales de memoria podrán permanecer activas, pero ninguna evaluación producirá nuevo estado secuencial ni efectos arquitectónicos sin ciclo efectivo y validez local. En particular, un store retenido no volverá a escribir DMEM en cada flanco físico.

##### STEP, contador y Debug

Desde un estado legalmente reanudable, cada STEP aceptado autorizará exactamente un ciclo efectivo. Después de ese ciclo no se autorizará otro sin un nuevo STEP, salvo una transición válida a RUN u otra condición ya aprobada.

Durante drenado paso a paso seguirá siendo necesario un STEP por ciclo. La captura y transmisión posterior del snapshot no generarán avances adicionales. El contador permanecerá estable durante HOLD e incrementará una vez por cada ciclo efectivo autorizado, incluidos stalls y drenado.

##### Reanudación y estados no reanudables

Un sistema preparado para ejecutar o una espera de STEP podrá continuar desde el mismo estado CPU cuando el control autorice legalmente el siguiente ciclo. El tiempo físico transcurrido en HOLD no alterará la semántica del programa.

El acuerdo 44 de `DEC-ARCH-003` fija RESET > LOAD > STEP > RUN entre comandos elegibles. LOAD se admite desde NO_IMAGE, READY, STEPPING, HALT_DRAIN_STEP, FAULT_DRAIN_STEP, FINISHED y FAULT; se rechaza en RUNNING y drenado AUTO sin inhibir el ciclo vigente. RUN/STEP aceptados en FINISHED/FAULT preparan una sesión nueva y limpia con la imagen confirmada mediante PREPARING_RUN/STEP; no reanudan la sesión terminal. Sin imagen no se autoriza ejecución. Respuestas, payload y framing UART siguen pendientes.

Esta semántica no introduce comandos PAUSE o RESUME ni decide si podrá solicitarse pausa o captura durante RUN. La reprogramación no comenzará directamente durante un contexto continuo; su respuesta de rechazo y la recuperación previa necesaria permanecen para `DEC-PROTO-002` y las restantes subdecisiones de control.

#### 6. Semántica de ciclo lógico

`cpu_enable` será un nombre conceptual para el evento final que autoriza exactamente un ciclo lógico del procesador. Podrá denominarse descriptivamente `cpu_cycle_fire`, pero ninguno de ambos nombres constituirá una señal RTL o un puerto obligatorio.

Conceptualmente, el evento final solo podrá existir después de resolver la prioridad global:

```text
sin reset activo
AND sin LOAD aceptado en progreso
AND sesión confirmada
AND modo de ejecución autoriza un ciclo
-> exactamente un ciclo lógico de CPU
```

Una solicitud preliminar de RUN o STEP no será por sí sola un ciclo. Si coincide con reset, LOAD aceptado o una condición no ejecutable, no existirá evento final, no avanzará el CPU y no incrementará el contador. La respuesta de control o protocolo ante una solicitud suprimida, rechazada o ilegal permanece pendiente.

La ausencia del evento final tampoco implicará siempre HOLD: reset, LOAD aceptado y preparación efectiva aplican sus clases superiores. Las escrituras efectivas de preparación inhiben ciclos CPU. `prepare_active` identifica el modo; en PREPARING_RUN/STEP con `prepare_done`, la preparación ya terminó antes del flanco y no hay writes de mantenimiento/Loader concurrentes: ese flanco ejecuta el primer ciclo CPU y deja `cycle_count=1`. PREPARING_READY con `prepare_done` publica la sesión y queda READY sin ciclo CPU. Solo cuando no exista una acción superior se aplicará la semántica de HOLD acordada.

##### Stalls, bubbles y flushes

Un stall interno ocurrido dentro de un ciclo autorizado no cancelará ese ciclo:

```text
stall dentro de ciclo efectivo != HOLD
```

El ciclo contará aunque PC o algunos latches queden retenidos o se inserten bubbles/flushes. Los patrones vigentes son los aprobados en `DEC-ARCH-003`, acuerdo 47.

La autorización global definirá que existe una transición lógica; los enables locales decidirán qué elementos cambian durante ella. El control está fijado en `DEC-ARCH-003`, acuerdos 40–47: eventos, ocho acciones, próximo estado, efectos, autorización e integración; la matriz 46 está revisada por el 47. Resta implementar y verificar RTL conforme a ese contrato.

##### RUN, STEP y drenado

RUN autorizará eventos finales sucesivos mientras la ejecución deba continuar. Un STEP válido y aceptado autorizará exactamente uno. STEP significará un ciclo del procesador, no la finalización de una instrucción completa.

Si el ciclo autorizado contiene un stall, el STEP se considerará consumido y el contador incrementará una vez. Para otro ciclo será necesario un nuevo STEP, salvo una transición válida a RUN.

Después de reconocer un `halt` válido, el drenado requerirá ciclos efectivos. En RUN progresará automáticamente ciclo a ciclo; en STEP requerirá una nueva orden por ciclo. El pipeline no drenará durante HOLD.

##### Contador lógico

En operación normal se cumplirá:

```text
evento final de ciclo = 1 -> contador incrementa exactamente uno
evento final de ciclo = 0 -> contador conserva su valor
```

Reset e inicialización de sesión serán acciones de mayor prioridad que establecen el contador en cero sin constituir ciclos CPU.

Los ciclos efectivos con stalls, bubbles, flushes, invalidaciones o drenado contarán. Los ciclos del clock funcional con actividad exclusiva de UART, Debug, loader o mantenimiento no contarán. `cycle_count[63:0]` es unsigned e incrementa módulo `2^64` por `cpu_cycle_fire`, sin fault, cambio de `global_state`, detención ni flag adicional; el formato UART permanece pendiente conforme a la revisión de `DEC-SYS-006` del 2026-09-26.

#### 7. Generación desde RUN, STEP y drenado

La solicitud conceptual de un ciclo se obtendrá a partir de una autorización continua o de un STEP válido y aceptado:

```text
solicitud de ciclo = autorización continua OR STEP aceptado

evento final de ciclo =
    solicitud de ciclo
    AND sin prioridad de reset o LOAD aceptado/preparación
    AND sesión confirmada
    AND estado ejecutable
```

Las expresiones anteriores son semánticas. `run_active`, `step_pulse`, autorización continua, `cpu_enable` y `cpu_cycle_fire` no serán nombres obligatorios de estados, señales ni puertos RTL.

El cuadragésimo cuarto acuerdo de `DEC-ARCH-003` adopta después `cpu_cycle_fire` como señal combinacional de `Cycle Authorization` y sustituye el registro histórico `drain_auto` por estados globales AUTO/STEP, sin convertir esta expresión conceptual en un permiso para comprometer efectos CPU durante preparación efectiva.

##### Autorización continua

Un RUN válido desde una sesión preparada establecerá un contexto de avance continuo. Mientras la ejecución normal deba continuar, ese contexto solicitará ciclos sucesivos sin nuevos comandos.

Cuando se reconozca un `halt` válido, dejarán de admitirse instrucciones nuevas y el estado observable podrá pasar a DRAINING. Si el `halt` fue reconocido bajo contexto continuo, se conservará autorización automática para los ciclos de drenado sin exigir que el estado siga denominándose RUN ni que exista un flag `run_active` concreto.

El **avance normal** cesará al confirmar una frontera terminal de `halt` o fault, o ante una acción superior o intervención válida. Si el fault se confirma en un ciclo bajo contexto continuo, las anteriores aún válidas conservarán autorización de drenado automático hasta `FAULT` conforme a `DEC-ARCH-004`; el trigésimo sexto acuerdo de `DEC-ARCH-003` había fijado `drain_auto` para recordar ese origen; el cuadragésimo cuarto **sustituye** ese registro por estados `FAULT_DRAIN_AUTO/STEP`. Si se confirmó por STEP, cada ciclo posterior requiere otro STEP aceptado, salvo conversión por RUN aceptado. Ninguna de estas condiciones autoriza un ciclo durante HOLD, reset o LOAD aceptado. El cuadragésimo cuarto acuerdo precisa que `PREPARING_RUN/STEP && prepare_done` sí autoriza el primer ciclo en ese mismo flanco **solo** si la preparación ya terminó previamente y no hay escrituras de mantenimiento/Loader concurrentes.

##### STEP aceptado

Un STEP solo solicitará un ciclo si es válido, fue aceptado y el sistema se encuentra en un estado legalmente reanudable. Cada aceptación producirá exactamente una solicitud y no permanecerá activa durante clocks posteriores.

Si el ciclo contiene stall, bubble, flush o invalidación, el STEP igualmente quedará consumido. En drenado bajo control paso a paso no existirá autorización automática: cada ciclo requerirá un nuevo STEP.

Una solicitud STEP suprimida, rechazada o coincidente con reset o LOAD aceptado/preparación efectiva con writes no generará un evento CPU ni quedará diferida implícitamente para ejecutarse al retirar la prioridad. Su respuesta concreta permanecerá para control y protocolo.

##### HOLD y condición del pipeline

Sin autorización continua ni STEP aceptado, y sin acción superior, el plano CPU permanecerá en HOLD. La existencia de instrucciones válidas en el pipeline no autorizará por sí sola un ciclo.

DRAINING describirá una condición del pipeline, no una fuente autónoma de avance. El contexto continuo o un STEP aceptado determinarán si progresa. Del mismo modo, stall, bubble, flush e invalidación describirán qué sucede dentro de un ciclo ya autorizado y no generarán autorización global.

##### FINISHED y fault

FINISHED se alcanzará únicamente después de reconocer un `halt` válido y vaciar completamente el pipeline. Eliminará la autorización de la sesión terminada; RUN/STEP elegibles preparan una sesión nueva mediante PREPARING_RUN/STEP conforme al acuerdo 44.

Un fault confirmado impedirá ciclos normales posteriores y permanecerá distinguible de FINISHED. `DEC-ARCH-004` fija después que las anteriores supervivientes completen durante el drenado, con ciclos efectivos automáticos si la confirmación ocurrió bajo contexto continuo o con un STEP nuevo por ciclo si ocurrió en paso a paso; `DEC-ARCH-003` precisa las transiciones de latches y la representación terminal sin modificar la prioridad global aquí aprobada.

Reset y LOAD aceptado dominarán cualquier autorización continua o STEP. Una solicitud coincidente no contará, no incrementará el contador y no se convertirá en un ciclo latente.

#### 8. Secuencia conceptual de inicialización de sesión

La secuencia siguiente describe la sesión iniciada por LOAD. RUN/STEP desde FINISHED/FAULT también preparan una sesión nueva, reutilizando la imagen confirmada, conforme al acuerdo 44. La preparación por LOAD es potencialmente multiciclo entre aceptación y commit o fallo:

```text
LOAD aceptado
      -> invalidar imagen confirmada
      -> impedir ciclos CPU
      -> recibir, validar y escribir la nueva imagen
         junto con la preparación del estado de sesión
      -> commit completo o fallo
```

Esta secuencia es conceptual y no obliga a utilizar una FSM, estado o señal RTL denominada `session_init`.

##### Aceptación de LOAD

En el flanco en que LOAD sea aceptado se escribirá:

```text
loaded_image_size_bytes = 0
```

`image_valid` pasará a cero exclusivamente por derivación combinacional. La imagen anterior dejará de ser ejecutable y no habrá eventos finales de ciclo CPU hasta terminar el procedimiento. Una solicitud LOAD rechazada conservará por sí sola la sesión e imagen vigentes.

LOAD no podrá aceptarse mientras ya exista contexto de ejecución continua, incluido el drenado automático iniciado por RUN. Una vez aceptado desde una condición permitida, se aplicará la prioridad ya acordada sobre cualquier solicitud de avance.

##### Preparación multiciclo

Durante la fase podrán realizarse, en paralelo o secuencialmente:

- recepción, reconstrucción, validación y escrituras de la nueva imagen en IMEM;
- preparación del cero lógico de DMEM;
- puesta a cero del banco de registros;
- invalidación del pipeline;
- preparación de `PC = 0x00000000`;
- puesta a cero del contador lógico;
- eliminación de estados de ejecución no persistentes;
- preparación del conjunto lógico de memoria utilizada y demás metadata de sesión.

No se fija el orden físico interno, paralelismo, FSM privadas ni cantidad de ciclos; la FSM global y su autorización siguen el acuerdo 44. El contenido parcial ya escrito en IMEM y cualquier estado parcialmente preparado carecerán de semántica de sesión ejecutable mientras el tamaño confirmado permanezca en cero.

UART, loader y mantenimiento podrán progresar con sus propios enables. El pipeline no avanzará como ejecución, no se incorporarán instrucciones y no se comprometerán efectos de la sesión anterior.

##### Commit completo

Antes del commit deberán estar preparados coherentemente:

```text
imagen completa recibida, validada y escrita
PC = 0x00000000
x0 ... x31 = 0
pipeline sin instrucciones válidas
DMEM lógicamente en cero
conjunto lógico de memoria utilizada vacío
contador lógico de ciclo = 0
estado de ejecución inicial y detenido
```

Solo entonces el único write no nulo de `loaded_image_size_bytes` publicará el tamaño de la nueva imagen. `image_valid` pasará a uno por derivación; no se publicará ni almacenará como un estado persistente independiente.

El commit expondrá una frontera coherente de sesión, pero no exige que todas las tareas de preparación ocurran en ese mismo ciclo. El cuadragésimo cuarto acuerdo de `DEC-ARCH-003` lo ubica en `PREPARING_READY && prepare_done`: termina la carga sin ciclo CPU; después el sistema queda preparado y sin eventos CPU hasta recibir posteriormente un RUN o STEP válido. READY es un estado de la FSM global del acuerdo 44; HOLD describe ausencia de ciclo efectivo y no añade un estado.

##### Fallo, nueva tentativa y reset

Una carga vacía, incompleta, inválida, sobredimensionada, interrumpida o fallida no producirá commit. `loaded_image_size_bytes` permanecerá en cero y no existirá sesión ejecutable.

No se restaurará la imagen anterior ni se hará rollback del estado parcialmente preparado. Sus residuos físicos carecerán de validez de sesión. Una nueva solicitud válida podrá reiniciar el procedimiento completo.

Si reset ocurre durante cualquier fase, dominará la operación, impedirá nuevos writes de loader o mantenimiento en el flanco correspondiente y dejará el sistema en el estado global sin imagen definido anteriormente.

Los punteros, contadores y flags de progreso interno no constituirán evidencia de sesión confirmada. La única publicación persistente de una imagen ejecutable será el write no nulo del tamaño al commit completo.

#### 9. Convención de polaridad del reset

Toda solicitud y señal conceptual de reset utilizada dentro del diseño será activa en alto:

```text
reset = 1 -> reset solicitado o activo
reset = 0 -> funcionamiento normal
```

La polaridad eléctrica del pin o fuente física no formará parte del contrato interno. Una fuente activa en bajo se invertirá una única vez en el wrapper o top-level; una fuente activa en alto no requerirá inversión. Los módulos funcionales no dependerán de esa elección de placa.

La cadena conceptual será:

```text
pin o fuente física
        -> normalización única de polaridad en wrapper
        -> solicitud asíncrona normalizada activa en alto
        -> acondicionador con aserción asíncrona y desaserción sincronizada
        -> reset distribuido activo en alto
           (aserción asíncrona / desaserción sincronizada)
        -> consumo síncrono por CPU, pipeline y control
```

La normalización de polaridad no modificará la estrategia temporal aprobada: la solicitud válida asertará inmediatamente la cadena y el reset distribuido, mientras que su desaserción atravesará las dos etapas. Los registros funcionales seguirán aplicando los efectos de reset únicamente en `posedge clk`.

##### Nomenclatura

No se exigirá que todos los puertos o señales se denominen literalmente `reset`. Podrán utilizarse nombres inequívocos como `reset`, `rst`, `reset_request_async` u otros equivalentes si su semántica está documentada y permanece activa en alto.

El sufijo `_n` se reservará para señales activas en bajo, normalmente limitadas a la frontera física. No se permitirá que una misma señal interna sea interpretada con polaridades distintas por módulos diferentes.

Nombres como `reset_button_n` serán válidos para puertos físicos activos en bajo, pero deberán normalizarse antes de alcanzar el sincronizador y nunca se propagarán como convención funcional del CPU.

##### Aspectos de integración todavía abiertos

La convención interna queda cerrada. Permanecen para integración la selección del pin o fuente física, duración mínima y realización concreta de la relación con una eventual señal `locked` de generación de clock, definida semánticamente en `DEC-ARCH-005`.

#### 10. Rebotes y requisitos de la entrada física de reset

La implementación inicial no incorporará obligatoriamente un eliminador de rebotes digital dedicado para reset. Después de normalizar una única vez su polaridad, la entrada física alimentará el acondicionador ya aprobado:

```text
entrada física
        -> normalización única de polaridad
        -> solicitud asíncrona normalizada activa en alto
        -> aserción asíncrona / desaserción sincronizada en dos etapas
        -> reset distribuido activo en alto
           (aserción asíncrona / desaserción sincronizada)
        -> consumo funcional síncrono
```

El sincronizador resuelve el cruce de dominio de la solicitud asíncrona, pero no será presentado ni verificado como debouncer. Reset será una condición de nivel y no un evento que deba contabilizar exactamente una transición por pulsación.

##### Comportamiento permitido ante rebotes

Sin un filtro dedicado, una aserción física válida podrá activar la cadena sin esperar a ser muestreada por un flanco. Un pulso que no satisfaga el ancho mínimo del recurso asíncrono quedará fuera del contrato. Los rebotes podrán prolongar el reset interno, impedir temporalmente su liberación o producir una liberación sincronizada seguida de una nueva aserción asíncrona.

No se garantizará que todos los rebotes se reduzcan a un único intervalo continuo de reset. Toda nueva aserción que alcance el reset distribuido volverá a aplicar íntegramente el contrato de reset global y no constituirá una operación arquitectónica distinta.

##### Requisito de integración

La fuente externa deberá cumplir los requisitos eléctricos y temporales del dispositivo, incluido el ancho mínimo aplicable al recurso de aserción asíncrona. Pulsos arbitrariamente cortos quedarán fuera del contrato.

La duración concreta se expresará en tiempo o ciclos al definir clock, dispositivo, placa y constraints. El procedimiento de arranque y uso deberá esperar a que el reset se haya estabilizado antes de enviar comandos funcionales. La confiabilidad del mecanismo físico se validará repetidamente sobre la FPGA real.

##### Revisión futura basada en evidencia

Si la validación física demuestra un comportamiento inaceptable, podrá añadirse un filtro o debouncer en el wrapper de integración. No se fija ahora su realización ni su ubicación exacta respecto del sincronizador; dependerán del mecanismo seleccionado y requerirán el análisis CDC correspondiente.

Esa incorporación no modificará la polaridad conceptual activa en alto, la aserción asíncrona y desaserción sincronizada del reset distribuido, el consumo funcional síncrono, el alcance y prioridad del reset ni la ausencia de ciclos CPU durante su aplicación. Por ello será un detalle de integración y no una obligación arquitectónica inicial.

#### 11. Aceptación de LOAD durante ejecución continua

Una solicitud LOAD no será aceptada mientras ya exista un contexto de ejecución continua:

```text
contexto continuo activo
        + solicitud LOAD
        -> LOAD rechazado
        -> ejecución vigente continúa
```

La condición es semántica y no exige un estado o señal RTL denominado `RUN` o `run_active`. Incluye la ejecución normal y el drenado automático iniciado por RUN después de reconocer un `halt`, aunque el estado observable se denomine DRAINING. El rechazo se mantendrá mientras subsista esa autorización continua, hasta FINISHED, fault o una intervención externa válida según las prioridades fijadas en el acuerdo 44.

##### Efectos del rechazo

Una solicitud rechazada durante contexto continuo no deberá:

- modificar `loaded_image_size_bytes` ni su derivación `image_valid`;
- escribir IMEM ni transferir su ownership al loader;
- iniciar recepción, preparación lógica de DMEM o cualquier otra inicialización de sesión;
- modificar por sí misma PC, registros, pipeline, contador o estado de ejecución;
- introducir stall, bubble, flush, pausa, fault o finalización;
- cancelar la autorización continua ni su drenado.

La invalidación inmediata de la imagen anterior y la prioridad sobre el avance CPU se aplicarán únicamente a partir de una aceptación efectiva. Una mera solicitud rechazada no tendrá prioridad sobre el ciclo CPU que corresponda y no quedará latente para aceptarse automáticamente al terminar RUN; será necesaria una nueva solicitud válida.

##### Ownership y ausencia de aborto implícito

Durante el contexto continuo, la CPU conservará el flujo funcional de IMEM. El loader no obtendrá grant ni write enable y no podrá comenzar una nueva imagen. LOAD no constituirá un mecanismo implícito para pausar, abortar o recuperar RUN.

La recuperación mínima durante RUN será el reset global definido por el acuerdo consolidado siguiente. Protocolo podrá añadir otras intervenciones, pero LOAD no asumirá implícitamente esa función.

##### Fronteras delegadas a protocolo y control

La respuesta concreta de rechazo, el tratamiento del payload y el framing pertenecerán a protocolo y control. El acuerdo 44 de `DEC-ARCH-003` fija RESET > LOAD > STEP > RUN entre comandos elegibles. LOAD se admite desde NO_IMAGE, READY, STEPPING, HALT_DRAIN_STEP, FAULT_DRAIN_STEP, FINISHED y FAULT; se rechaza en RUNNING y drenado AUTO sin inhibir el ciclo vigente. RUN/STEP aceptados en FINISHED/FAULT preparan una sesión nueva y limpia con la imagen confirmada mediante PREPARING_RUN/STEP; no reanudan la sesión terminal. Sin imagen no se autoriza ejecución. Respuestas, payload y framing UART siguen pendientes.

La elegibilidad interna ya está cerrada por el acuerdo 44; protocolo solo definirá su transporte y respuestas externas.

#### 12. Reset global como recuperación mínima durante RUN

El reset global será la vía mínima obligatoria de recuperación externa para abandonar una ejecución RUN activa o no terminante. Podrá invocarse durante ejecución normal o drenado continuo y, por su máxima prioridad, no esperará `halt` ni el vaciado del pipeline.

Cuando la lógica funcional observe activo el reset distribuido:

- se abortarán RUN, STEP pendiente y drenado;
- el pipeline quedará inválido y no se admitirán efectos arquitectónicos posteriores de la ejecución abandonada;
- se cancelarán LOAD parcial, fault no persistente, finalización y operaciones pendientes conforme al alcance global ya aprobado;
- `loaded_image_size_bytes` quedará en cero e `image_valid` en cero por derivación;
- PC, banco de registros, contador y control alcanzarán los valores de reset definidos;
- el sistema quedará detenido, sin sesión ejecutable y capaz de aceptar posteriormente un nuevo LOAD.

La recuperación por reset constituirá un aborto externo, no FINISHED ni finalización normal. No activará `program_finished`, DONE ni ningún indicador reservado para un `halt` válido seguido de drenado completo. Los efectos ya comprometidos antes de que el reset funcional tome efecto pertenecen a la ejecución anterior; ningún efecto pendiente se comprometerá después.

LOAD continuará rechazándose mientras exista contexto continuo y no será una vía implícita de aborto. Después del reset será necesaria una nueva solicitud LOAD válida; una solicitud rechazada durante RUN no quedará latente.

Esta garantía satisface la recuperación mínima exigida por `REQ-EXEC-015`. `DEC-PROTO-002` podrá decidir si reset se expone adicionalmente mediante UART o si incorpora otros comandos de recuperación, pausa o aborto, sin reemplazar esta vía mínima.

##### Realización RTL no prescrita

La decisión fija semántica, prioridades, ownership y condiciones de enable. La FSM global de 14 estados, aceptación de comandos y autorización separada están fijadas por el acuerdo 44 de `DEC-ARCH-003`. Quedan libres la codificación binaria, nombres de puertos, FSM privadas, owners/grants, paralelismo físico de preparación e invalidación DMEM, respetando los enables y transiciones aprobados.

La implementación materializará la FSM global aprobada y sus enables; la organización de submódulos es libre dentro del contrato. Deberá preservar el contrato observable, exclusión de ownership, atomicidad del commit y ausencia de escrituras duplicadas. Los patrones locales de hazards corresponden a `DEC-ARCH-003`; la secuencia CPU de faults, a los acuerdos 40–47 ya aprobados; su reporte externo, a protocolo; y pin, duración mínima concreta y realización física de la relación con `locked`, a integración y `DEC-ARCH-005`.

**Aspectos diferidos:** pin o fuente física y duración mínima concreta de reset; realización física de la relación con `locked` fijada semánticamente en `DEC-ARCH-005`; realización RTL de estados, señales, grants y enables; mecanismo físico de invalidación DMEM; respuesta y framing de comandos. El arbitraje y la secuencia CPU de faults están cerrados por `DEC-ARCH-003`, acuerdos 40–47.

**Justificación:** La separación entre reset global e inicialización de sesión evita convertir toda reprogramación en un reset físico y permite preparar coherentemente una sesión multiciclo antes de publicarla. La jerarquía conceptual y el evento final de ciclo impiden avances o compromisos duplicados durante HOLD, STEP, stalls y carga.

La aserción asíncrona permite reaccionar aun cuando todavía no haya un flanco disponible, mientras la desaserción sincronizada evita liberar el dominio funcional directamente desde una transición externa. La polaridad única y el acondicionamiento localizado desacoplan el CPU de la placa.

Rechazar LOAD durante contexto continuo preserva ownership y evita un aborto implícito. Seleccionar reset global como recuperación mínima satisface la ejecución no terminante sin confundir intervención externa con finalización normal. Mantener libres la codificación de FSM, nombres de puertos y organización física permite realizar el contrato aprobado.

**Consecuencias:**

- reset global e inicialización de sesión son mecanismos distintos;
- el reset distribuido usa aserción asíncrona y desaserción sincronizada, con consumo funcional síncrono;
- reset es activo en alto dentro del diseño y su polaridad física se normaliza en el wrapper;
- no se exige debouncer inicial, pero puede añadirse en integración si la evidencia lo requiere;
- reset domina LOAD, avance CPU y HOLD;
- reset global es la recuperación mínima obligatoria durante RUN y no produce FINISHED ni DONE;
- LOAD se rechaza durante contexto continuo, incluido su drenado automático, y no queda latente;
- una LOAD aceptada invalida inmediatamente la imagen y solo el commit completo publica una nueva sesión;
- HOLD congela el plano CPU sin detener el clock ni impedir actividad externa permitida;
- RUN, STEP y drenado generan ciclos efectivos conforme al contrato y el contador cambia una vez por ciclo;
- ownership de memorias es exclusivo y los efectos requieren enable conceptual y validez local;
- se conserva la FSM global del acuerdo 44; codificación binaria, FSM privadas y distribución física de enables siguen libres;
- pin, duración mínima y realización física de la relación con `locked` quedan para integración y `DEC-ARCH-005`;
- hazards locales y temporización precisa de faults permanecen en sus decisiones correspondientes.

**Requisitos afectados:** `REQ-CPU-009` a `REQ-CPU-013`, `REQ-CPU-016`, `REQ-CPU-018`, `REQ-HAZ-004`, `REQ-HAZ-010`, `REQ-EXEC-001` a `REQ-EXEC-018`, `REQ-MEM-007`, `REQ-MEM-008`, `REQ-MEM-019`, `REQ-MEM-024`, `REQ-MEM-025`, `REQ-MEM-028` a `REQ-MEM-030`, `REQ-UART-002` a `REQ-UART-005`, `REQ-DBG-001` a `REQ-DBG-004`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015` a `REQ-DBG-017`, `REQ-TIM-001`, `REQ-TIM-002`, `REQ-TIM-007`, `REQ-DOC-004`, `REQ-DOC-009`.

**Reemplaza / Reemplazada por:** No aplica.

---

### DEC-ARCH-009 — Campos de pipeline expuestos por debug

**Estado:** Aprobada

**Dominio:** CPU / Debug / Representación externa

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La consigna requiere observar los registros interetapa. Se completa la selección de campos funcionales, su identificación externa y la interpretación de validez/candidatos junto al contexto global de ejecución.

**Opciones consideradas:** Exponer el mínimo valid/PC/instrucción o todos los campos funcionales registrados; identificar bloques por posición fija o agregar IDs; conservar estado registrado o filtrar campos por validez. Se seleccionan exposición completa, posiciones fijas y responsabilidad de interpretación del lector.

**Decisión:** Se transmiten los 34 campos funcionales de los cuatro latches, en el orden de su esquema en interfaces.md: IF/ID 5 campos/69 bits internos, ID/EX 15/193, EX/MEM 8/139 y MEM/WB 6/103. Sus longitudes externas son 11/30/20/15 bytes; los bloques se identifican por posición fija, sin IDs adicionales. Campos de 32 bits: cuatro bytes little-endian; campos pequeños: un byte propio con padding alto cero. Controles/causas conservan los códigos arquitectónicos ya definidos.

Debug expone los datos registrados y sus indicadores también con valid=0, sin sustituirlos por cero ni clasificarlos como residuos. Su vigencia se interpreta por el lector: valid indica instrucción activa; fetch_fault_valid de IF/ID identifica el candidato registrado y permite interpretar su PC/causa, sin convertirlo en fault global confirmado. No se exponen nuevos diagnósticos combinacionales ni se agregan campos internos.

Fuera de los latches, global_state ocupa un byte en offset cero del cuerpo y usa códigos 0x00–0x0D para los 14 estados según el [acuerdo de códigos externos](#acuerdo-parcial-de-dec-proto-001--códigos-externos-de-global_state). fault_cause y fault_pc globales están siempre presentes y se interpretan como fault vigente únicamente en los estados de fault aprobados. No hay registros terminal_kind, drain_auto ni fault_valid adicionales.

Los acuerdos de [contenido completo](#acuerdo-parcial-de-dec-arch-009--exposición-completa-de-campos-registrados-del-pipeline), [anchos externos](#acuerdo-parcial-de-dec-proto-001--representación-binaria-de-campos-del-snapshot), [orden/layout](#acuerdo-parcial-de-dec-proto-001--orden-y-delimitación-del-snapshot) y [responsabilidad del lector](#acuerdo-parcial-de-dec-proto-001--campos-registrados-e-interpretación-del-snapshot) completan el contrato. No se impone una codificación física a la FSM global.

**Justificación:** Exponer el estado funcional completo y registrado facilita seguir las instrucciones, operandos, resultados y controles; formato fijo y códigos existentes permiten interpretarlo sin agregar estado diagnóstico. Los indicadores separan trabajo activo, candidato y fault confirmado.

**Consecuencias:** Se cierran D03/D05 y DEC-ARCH-009. D06 define lectura directa del estado retenido y envío exclusivo tras STEP/final RUN; puertos y recorrido se concretan en diseño de bloques. El resto de reglas comunes, errores, esperas y perfil permanece en decisiones de protocolo. Esta aprobación no acredita implementación ni cierra todo D0.

**Requisitos afectados:** `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de selección y representación externa, sin modificar los esquemas funcionales ni decisiones de hazards/sesión.

---

## 4. Clock y timing

### DEC-ARCH-005 — Frecuencia objetivo y distribución de clock

**Estado:** Aprobada

**Dominio:** Clock / Timing

**Fecha de aprobación:** 2026-09-22

**Depende de:** `DEC-SYS-004`, `DEC-ARCH-006` y `DEC-ARCH-008`, ya aprobadas, clock de la placa, recursos disponibles y restricciones iniciales.

**Alcance aprobado:** La estrategia arquitectónica comprende un único dominio funcional, su generación desde el clock físico, la relación semántica entre estabilidad y reset, y el **objetivo de referencia de 50 MHz (20 ns)** para `REFERENCE=1024/2048` sobre Basys 3. Esta aprobación cierra la elección arquitectónica para M2 — Architecture Freeze; no afirma que la implementación ya haya alcanzado 50 MHz.

**Verificación posterior:** Timing closure determinará mediante reportes post-implementation WNS, TNS, WHS, THS, camino crítico, cobertura de constraints y frecuencia efectivamente alcanzada. Es la verificación del objetivo aprobado, no una precondición para aprobar este ADR. Si la evidencia muestra que 50 MHz no puede cumplirse razonablemente, se revisará explícitamente `DEC-ARCH-005`; la frecuencia no se reducirá silenciosamente. La selección/configuración concreta del recurso de clock, pin, XDC y conexión RTL con `locked` corresponden a integración y no bloquean Architecture Freeze.

**Contexto:** Los acuerdos siguientes fijan un único dominio de clock funcional con enables síncronos, el objetivo de referencia de 50 MHz para `REFERENCE` en Basys 3 a partir de su oscilador físico de 100 MHz, el criterio de verificación temporal y la relación semántica entre estabilidad del generador y reset global. El perfil `REFERENCE` deberá verificar timing a la frecuencia aprobada; `ALT_1000` no adquiere por esta decisión obligación de síntesis o implementación. El análisis considerará la demanda simultánea máxima de un fetch y un acceso de datos y cubrirá los caminos combinacionales de validación, IMEM, organización por lanes DMEM, filtro de validez, ensamblado y extensión acordados en `DEC-ARCH-006`. Una salida registrada no podrá introducirse para cerrar timing sin revisar esa decisión. Los reportes deberán identificar el recurso efectivamente inferido y justificar si resulta necesario evaluar XPM o primitivas. Si un backend comparte recursos físicos, deberá preservar concurrencia, ausencia de aliasing y lectura sin stalls.

Las referencias de los acuerdos originales a aspectos todavía pendientes o a una parte restante de esta decisión describen tareas de integración y verificación posteriores, no elecciones arquitectónicas abiertas para su aprobación.

#### Acuerdo parcial aprobado — dominio de clock funcional

**Fecha:** 2026-09-22

La implementación inicial utilizará un único dominio de clock funcional principal para todo el estado secuencial de:

- CPU y pipeline;
- control global y loader;
- escrituras y metadata de las memorias lógicas;
- Debug;
- UART.

Las lecturas combinacionales de IMEM y DMEM no constituirán dominios adicionales. Sus puntos de captura, escrituras y estructuras secuenciales asociadas pertenecerán al clock funcional principal.

##### Control de avance

RUN, STEP, HOLD, LOAD y mantenimiento no detendrán, gatearán, dividirán ni generarán clocks funcionales. Mientras el generador proporcione flancos válidos, el clock principal continuará activo y el avance se controlará mediante enables, selección de próximo estado y eventos síncronos conforme a `DEC-ARCH-008`.

Un STEP autorizará exactamente un ciclo lógico del CPU; no producirá un pulso de clock nuevo. Los conceptos de enable y evento no impondrán nombres RTL concretos.

##### Clock de placa y adaptación

La frontera conceptual será:

```text
clock físico de placa
        -> adaptación según plataforma
        -> único clock funcional principal
        -> todo el estado secuencial del sistema
```

Según la plataforma y frecuencia seleccionadas, la adaptación podrá consistir en conexión directa o en un recurso apropiado de generación de clock. En la plataforma Basys 3 de referencia se requerirá adaptar 100 MHz a 50 MHz mediante un recurso dedicado; su selección, configuración exacta y conexión física con reset se concretarán en integración conforme al acuerdo de estabilidad siguiente.

El clock físico de entrada de un eventual generador no constituirá por sí mismo un segundo dominio funcional del RTL de usuario.

##### UART

UART no utilizará un dominio de clock funcional independiente. Los ritmos de transmisión, recepción u oversampling se derivarán del clock principal mediante contadores, acumuladores, clock-enables o ticks síncronos equivalentes:

```text
clock funcional
        -> contador o acumulador
        -> baud_tick síncrono
        -> enable de UART
```

Un concepto como `baud_tick` será un evento de enable y no un clock distribuido. No se utilizará como `posedge` o `negedge` para crear otro dominio. Baud rate, oversampling y generación concreta permanecerán para `DEC-SYS-007` y la parte restante de `DEC-ARCH-005`.

##### Revisión futura

No se introducirán clocks funcionales adicionales en la implementación inicial. Si una necesidad física futura justificara otro dominio interno, deberá revisarse esta decisión y documentarse explícitamente la frontera CDC, sincronización o handshake, constraints, coherencia de Debug y memorias, impacto sobre reset y verificación.

#### Acuerdo parcial aprobado — plataforma y frecuencia funcional de referencia

**Fecha:** 2026-09-22

La plataforma FPGA de referencia será **Digilent Basys 3**, con **AMD/Xilinx Artix-7 XC7A35T-1CPG236C**. Su oscilador físico de **100 MHz** será la fuente primaria del clock de la implementación `REFERENCE=1024/2048` definida en `DEC-ARCH-006`.

El único dominio funcional tendrá como **frecuencia objetivo inicial** `fclk = 50 MHz`, equivalente a `Tclk = 20 ns`:

```text
oscilador Basys 3: 100 MHz
        -> recurso dedicado de generación y distribución de clock
        -> dominio funcional: objetivo 50 MHz (20 ns)
        -> CPU, pipeline, control, loader, memorias, Debug y UART
```

##### Generación y estabilidad

La conversión 100 → 50 MHz empleará un recurso de clock apropiado de la FPGA, como Clock Wizard, MMCM o equivalente soportado, y la salida utilizará distribución dedicada. No se distribuirá como clock funcional un divisor hecho con lógica ordinaria, por ejemplo un flip-flop divisor. No se fija el recurso, configuración, instancia ni pin concretos.

Si el generador seleccionado proporciona una indicación de estabilidad como `locked`, se aplicará la relación semántica con reset global definida más abajo. La conexión concreta, los tiempos y la realización física quedarán para integración sin alterar la aserción asíncrona, desaserción sincronizada y consumo funcional síncrono de `DEC-ARCH-008`.

##### Objetivo temporal y revisión

El objetivo de 50 MHz no equivale a timing ya aprobado. Para la Basys 3 se restringirán correctamente el clock primario de 100 MHz / 10 ns y el funcional generado de 50 MHz / 20 ns, considerando los constraints que aporte el recurso elegido y evitando dejar rutas relevantes sin analizar. `REFERENCE` se sintetizará e implementará; tras place-and-route se documentarán camino crítico, WNS, TNS, WHS, THS, skew, cobertura de constraints y cumplimiento del período objetivo conforme al criterio siguiente.

Si no se cumple el objetivo, primero se analizarán los caminos críticos y sus causas, se corregirá el diseño cuando corresponda y se repetirán las verificaciones. La frecuencia no se reducirá silenciosamente para declarar timing cerrado: cualquier objetivo revisado requerirá justificación y actualización documental explícitas. El contrato de lectura combinacional y concurrencia IF/MEM de `DEC-ARCH-006` permanecerá vigente; una lectura registrada o stall de memoria no será un atajo implícito de timing.

Los 50 MHz constituyen el objetivo de referencia hasta contar con evidencia post-implementación. `ALT_1000=1000/1000` continúa limitado a elaboración, simulación y smoke tests, sin obligación física nueva.

#### Acuerdo parcial aprobado — criterio de cumplimiento temporal

**Fecha:** 2026-09-22

La implementación `REFERENCE=1024/2048` sobre Basys 3 solo se considerará temporalmente válida a 50 MHz (`Tclk = 20 ns`) si el análisis de Vivado **post-implementation**, después de síntesis y place-and-route, demuestra para **todos los caminos relevantes restringidos** ausencia de violaciones de setup y hold:

```text
Setup: WNS >= 0 ns; TNS = 0 ns
Hold:  WHS >= 0 ns; THS = 0 ns
```

El criterio no se limita al subtotal del clock funcional: incluye los caminos relevantes asociados al clock primario de 100 MHz, al funcional generado de 50 MHz y a las interfaces que requieran constraints. Antes de interpretar los slacks se verificará que los clocks relevantes estén definidos, que los caminos síncronos pertinentes estén analizados y que no existan caminos o interfaces críticos relevantes sin restricciones temporales adecuadas. Toda excepción temporal deberá estar justificada, documentada y verificada; no podrá ocultar violaciones mediante excepciones genéricas.

No se exige margen positivo adicional: un slack nulo cumple el umbral y un margen positivo pequeño podrá señalarse sin considerarlo incumplimiento. La síntesis exitosa o la ausencia de errores generales no sustituyen un Timing Summary completo y favorable. Si hay violaciones de setup o hold, o cobertura relevante incompleta, se identificarán los caminos y sus causas, se corregirá el diseño cuando corresponda y se repetirá la verificación. Cualquier revisión de la frecuencia objetivo requerirá justificación y actualización documental explícitas, sin rebajarla silenciosamente ni eludir `DEC-ARCH-006`.

Este acuerdo define el **criterio**, no acredita todavía su cumplimiento: faltan los constraints concretos y los reportes post-implementation de la implementación de referencia.

#### Acuerdo parcial aprobado — estabilidad del generador y reset funcional

**Fecha:** 2026-09-22

Si el recurso de generación de clock proporciona una indicación de estabilidad como `locked`, su ausencia será una causa de solicitud de reset global, además de la solicitud externa. Conceptualmente:

```text
solicitud de reset = solicitud externa de reset OR generador sin estabilidad
```

La expresión y los nombres son ilustrativos, sin imponer señales, una FSM ni estructura RTL concreta. Cualquiera de las dos causas podrá asertar asíncronamente el reset distribuido de `DEC-ARCH-008`. La liberación solo podrá comenzar cuando la solicitud externa esté inactiva **y** el generador indique estabilidad. `locked = 1` retira una causa de reset, pero no libera directamente CPU, pipeline o control: la desaserción del reset distribuido permanece sincronizada con el clock funcional.

Durante arranque, mientras no haya estabilidad, el reset permanecerá asertado. Si se pierde `locked` durante RUN, STEP, LOAD, HOLD o drenado, se solicitará nuevamente reset global con su prioridad y semántica ya aprobadas. El reset distribuido podrá asertarse sin flancos, incluso si el clock funcional se detiene; **los efectos en registros funcionales ocurrirán solo en el primer flanco válido en que observen ese reset**, antes de permitir operación funcional normal. No se prometen cambios inmediatos en PC, pipeline, control o tamaño de imagen en ausencia de flancos válidos.

Al tomar efecto el reset funcional, se abortarán ejecución y cargas en curso, se invalidará la sesión (`loaded_image_size_bytes = 0`, `image_valid = 0` por derivación) y el sistema quedará detenido. Esta recuperación no será FINISHED ni DONE; después de recuperar estabilidad y liberar el reset correctamente podrá solicitarse una nueva LOAD, no reanudarse la sesión anterior. Los efectos ya comprometidos antes de que el reset funcional tome efecto conservarán el tratamiento de `DEC-ARCH-008`.

La selección/configuración del recurso, la conexión y secuencia RTL concretas, el pin, la duración mínima y los constraints seguirán correspondiendo a integración. Esta relación semántica no acredita todavía la estabilidad física ni el cierre temporal.

##### Aspectos todavía pendientes

Continúan abiertos dentro de `DEC-ARCH-005` o integración:

- frecuencia final sustentada por timing post-implementación;
- recurso y configuración concretos de generación;
- conexión física y secuencia RTL concretas de la indicación de estabilidad y reset;
- pin y constraints concretos de placa y clocks;
- evidencia de síntesis, implementación y cumplimiento post-implementation del criterio de setup, hold y cobertura de constraints.

**Opciones a analizar:** recurso dedicado para generar 50 MHz desde 100 MHz en Basys 3; configuración y constraints de integración; revisión justificada de frecuencia si falla el objetivo.

**Requisitos afectados:** `REQ-MEM-008`, `REQ-MEM-010`, `REQ-MEM-016` a `REQ-MEM-030`, `REQ-EXEC-011`, `REQ-UART-001` a `REQ-UART-005`, `REQ-TIM-001` a `REQ-TIM-007`, `REQ-DOC-009`.

**Reemplaza / Reemplazada por:** No aplica.

---

## 5. Debug y protocolo

### DEC-PROTO-001 — Formato detallado del protocolo

**Estado:** Aprobada.

**Dominio:** Debug / Protocolo.

**Fecha de aprobación:** 2026-10-01; consolidación de los acuerdos previos y revisión V01/V02/V03.

**Contexto:** El sistema necesita un contrato único para carga, ejecución, pasos, reset, disponibilidad y Debug automático. El usuario solicita terminar el diseño antes de programar y mantener el alcance proporcional al TP, con PC/FPGA diseñadas conjuntamente.

**Opciones consideradas:** Delimitación por tamaño o marcador; respuestas de aceptación/finalización diferenciadas; checksum/CRC; consultas Debug adicionales; copia de snapshot o lectura directa retenida; negociación de capacidades o perfil compartido previo. Los acuerdos parciales seleccionan tamaño explícito, cabecera común, Debug automático y perfil común, sin checksum ni negociación adicional.

**Decisión:** El contrato definitivo es [protocol.md](protocol.md). LOAD=0x01, RUN=0x02, STEP=0x03, RESET=0x04 y CHECK_READY=0x05 ocupan un byte. Toda respuesta empieza con eco de código y resultado de un byte, seguido del contenido correspondiente; tabla de doce resultados 0x01–0x0C y estados externos 0x00–0x0D.

LOAD declara N unsigned de cinco bytes little-endian, valida imagen no vacía/base cero/contigua/múltiplo de cuatro/dentro de IMEM y espera aceptación antes del contenido seguido. La aceptación invalida la imagen previa; solo preparación completa y commit publican imagen válida y DONE. Rechazos previos conservan imagen; fallo de carga aceptada no hace rollback. PC consulta disponibilidad antes de cada carga y FPGA valida independientemente, sin reserva por consulta.

RUN tiene aceptación y resultado terminal automático FINISHED/FAULT con Debug después de drain; STEP realizado tiene única respuesta DONE con snapshot posterior a un ciclo efectivo, incluidos stall/drain. RESET global se genera después del último Stop de su aceptación; botón físico es otra fuente directa. Solo durante ejecución RUN se permiten consultas y RESET antes de su resultado terminal, con respuestas completas y sin intercalar bytes.

Snapshot binario little-endian, estado retenido leído directamente y exclusión desde instante postciclo hasta último Stop; RX se consume/descarta durante exclusión. Se transmiten campos registrados sin filtrarlos por valid, interpretados por el lector. Contexto 19 bytes, RF 128, cuatro latches 76, cantidad unsigned de cinco bytes y lista de direcciones únicas crecientes/valores actuales escritos por stores comprometidos en la sesión. Cuerpo 228+5*K y respuesta 230+5*K; no marcador final ni consulta Debug extra.

Perfil REFERENCE por defecto o ALT_1000, seleccionado previamente e igual en PC/FPGA conforme a [memoria](architecture/memory_architecture.md#perfiles-definidos). Códigos/layout comunes; límites y tiempos por capacidad. Tiempos/recuperación según DEC-PROTO-003; servicios adicionales según DEC-PROTO-002. No se agrega configuración de PC ni negociación UART.

**Justificación:** Formatos por operación y cantidad delimitan mensajes sin ambigüedad para el cliente propio. Separar aceptación, commit y observación evita ejecutar una imagen parcial o mezclar estados mientras UART transmite. Conserva comprobaciones y recuperación básicas con alcance de laboratorio.

**Consecuencias:** [V01/V02](debug_protocol_audit.md) verifican recorridos, códigos, campos, offsets, ejemplos y cálculos; V03 consolida documentos y retira la checklist de 52 tareas al [archivo histórico](archive/protocolo_checklist_temporal_2026-10-01.md). DEC-PROTO-001 queda cerrada. Puertos físicos, generador UART, correcciones FSM TP2, arbitraje/serialización, ownership y preparación por recurso permanecen en DEC-SYS-007/diseño de bloques; aplicación y assembler en DEC-SYS-008/009. D0 del sistema completo sigue abierto. Esta revisión documental no acredita implementación ni mediciones.

**Requisitos afectados:** `REQ-MEM-003`, `REQ-MEM-008`, `REQ-MEM-010` a `REQ-MEM-012`, `REQ-MEM-015` a `REQ-MEM-019`, `REQ-MEM-021` a `REQ-MEM-024`, `REQ-MEM-027`, `REQ-MEM-029`, `REQ-MEM-030`, `REQ-EXEC-016` a `REQ-EXEC-018`, `REQ-UART-002` a `REQ-UART-011`, `REQ-DBG-001` a `REQ-DBG-017`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de formato, LOAD, RUN, STEP, respuestas, snapshot, códigos, intercambios, errores y perfil. Sus textos fechados se mantienen como historial; referencias a pendientes en esos acuerdos describen el momento de aprobación.

---

### DEC-PROTO-002 — Comandos adicionales

**Estado:** Aprobada

**Dominio:** Debug / Servicios de control y observación

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se completa la selección y secuencia de servicios auxiliares de LOAD/RUN/STEP, incluidos reset global desde PC, disponibilidad y obtención de Debug.

**Opciones consideradas:** Reset solo físico o también UART; disponibilidad espontánea o consultada; Debug explícito adicional o automático; servicios de pausa/aborto/reintento/capacidades. Se seleccionan reset UART más botón, consulta CHECK_READY y Debug automático, sin otros comandos.

**Decisión:** La lista final consta de LOAD 0x01, RUN 0x02, STEP 0x03, RESET 0x04 y CHECK_READY 0x05. RESET solicita el mismo reset global del botón: responde `04 01` (ACCEPTED) y genera reset al terminar físicamente el segundo byte incluido Stop. El botón lo solicita directamente y puede abortar una transmisión; no genera aceptación UART ni mensaje espontáneo de arranque.

CHECK_READY se solicita con `05` y responde `05 03` (READY) o `05 04` (BUSY). Expresa disponibilidad para LOAD, sin reserva ni garantía de imagen válida. PC consulta antes de LOAD; FPGA valida LOAD por condiciones actuales sin exigir recordar consulta previa. Después de reset o recuperación se reutiliza el mismo servicio.

Debug se envía automáticamente con cada STEP realizado y final RUN; no existe una solicitud adicional de snapshot ni captura durante ejecución continua. Una operación normal por vez, con CHECK_READY/RESET durante RUN efectivo; RESET reconocido abandona RUN previo. Cada respuesta se completa físicamente antes de otra. Durante contenido/tamaño LOAD, recuperación y envío exclusivo Debug se mantienen las reglas específicas; RESET UART se envía después de Debug y botón físico puede interrumpirlo. La PC retoma la comunicación tras un fallo con los plazos y ventana del [acuerdo de recuperación](#acuerdo-parcial-de-dec-proto-003--recuperación-de-pc-y-cabecera-final-de-run).

**Justificación:** Los servicios cubren carga, ejecución, observación, disponibilidad y recuperación de una sesión sin comandos redundantes. La aceptación antes del reset evita truncarla y el envío exclusivo conserva Debug coherente.

**Consecuencias:** Selección, formatos, códigos, exclusión y reacción ante fallos cerrados; puertos y FSM privadas se concretan en DEC-SYS-007/diseño de bloques. Perfil compartido y revisión/consolidación del protocolo permanecen en C07/V01–V03/DEC-PROTO-001. Esta aprobación no cierra todo D0 ni acredita implementación.

**Requisitos afectados:** `REQ-EXEC-012`, `REQ-EXEC-015`, `REQ-EXEC-018`, `REQ-MEM-019`, `REQ-MEM-028`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de reset, consulta, servicios Debug, lista final, códigos, intercambios y recuperación PC.

---

### DEC-PROTO-003 — Timeouts y recuperación

**Estado:** Aprobada

**Dominio:** Debug / Tiempos FPGA–PC y recuperación del enlace

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se completan los tiempos de recepción LOAD, recuperación RX, espera de respuestas PC y reacción ante comunicación incompleta, usando UART 19200 baud, 8N1 y clock funcional de 50 MHz.

**Opciones consideradas:** Timeout total de programa o inactividad por byte; recuperación por reset global o descarte/silencio; reenvío automático o reintento manual. Se seleccionan inactividad LOAD, recuperación RX por silencio y reintento manual; tiempos PC se calculan por mensaje/fase.

**Decisión:** FPGA usa T=100 ms (5.000.000 clocks) de inactividad para tamaño/contenido LOAD. El tamaño comienza tras opcode; el contenido después del fin físico de aceptación. Prioridad error UART, byte válido y vencimiento sin ambos. Recepción incompleta antes de aceptar conserva imagen; fallo posterior la deja inválida. RX se recupera por descarte y R=100 ms de silencio continuo, reiniciado por actividad, con línea en reposo, sin byte en curso y FIFO vacía. TX se conserva. Error UART en código fuera de LOAD usa ese R sin respuesta ni efecto CPU/imagen.

PC prepara el programa completo, envía exacto/seguido después de aceptación, escucha respuestas y detiene/cancela al fallar. Ventana LOAD W: tiempo nominal de N+6 bytes más T+R, redondeado arriba a múltiplos de 100 ms; W=800 ms para N=1024. Consulta tras W y repite W si falta respuesta; reintento manual con una nueva LOAD completa.

| Espera PC | Plazo aprobado |
|---|---|
| CHECK_READY, aceptación LOAD o RUN | 200 ms desde inicio de solicitud |
| Final LOAD | N*10*1000/19200 +201 ms desde inicio del contenido, REFERENCE/ALT_1000 |
| Aceptación RESET | 200 ms desde solicitud |
| Cabecera STEP completa | 200 ms desde solicitud |
| Terminación RUN antes de primer byte terminal | Sin timeout de duración |
| Completar cabecera final RUN ya comenzada | 200 ms desde su primer byte |
| Parte fija Debug de 228 bytes | 319 ms desde cabecera completa |
| Lista Debug, K>0 | ceil(5*K*10*1000/19200 +200) ms desde used_count |
| K=0 | Respuesta completa al terminar parte fija; sin otra espera |

LOAD dispone de presupuesto de preparación máximo 1 ms, incluido commit en READY, para REFERENCE/ALT_1000; no es una espera fija y futuros perfiles revisan esa cota. Los demás plazos se explican en el [acuerdo de recepción Debug](#acuerdo-parcial-de-dec-proto-003--plazos-de-reset-step-y-recepción-de-debug).

Ante timeout/desconexión/truncamiento PC informa fallo, descarta parcial, conserva observación anterior y detiene la secuencia sin repetir automáticamente STEP/RUN/RESET ni inferir rollback. Fuera del flujo LOAD, W_debug(C)=100*ceil((200+319+ceil(5*C*10*1000/19200+200))/100) ms; vale 6100 para REFERENCE y 3400 para ALT_1000. PC descarta RX durante la ventana, limpia pendiente local y consulta CHECK_READY; si no obtiene respuesta válida en 200 ms repite ventana/consulta. La consulta recupera comunicación; para sesión conocida, el usuario puede RESET y LOAD. Véase el [acuerdo de recuperación](#acuerdo-parcial-de-dec-proto-003--recuperación-de-pc-y-cabecera-final-de-run).

**Justificación:** Inactividad permite distintos tamaños sin castigar programas largos. Los presupuestos por fase distinguen transmisión y ejecución; el cálculo por perfil permite drenar una respuesta pendiente incluso si K se perdió. Repetir solo consultas y reintentar operaciones manualmente evita duplicar avances o resets.

**Consecuencias:** C06 y las elecciones de tiempos/recuperación quedan cerrados. Puertos UART, contadores, reconocimiento de actividad/en curso/fin físico y FSM privadas se concretan en DEC-SYS-007/diseño de bloques. C07/V01–V03 completan perfil y documento definitivo bajo DEC-PROTO-001. Los valores son contratos de diseño para la implementación futura, sin pruebas RTL ni mediciones de hardware en esta etapa.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-DBG-013`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de T/R, ventanas y envío LOAD, plazos PC, preparación LOAD, errores RX y recuperación de PC, conservando sus contextos y efectos.

---



### Acuerdo parcial de DEC-PROTO-001 — Tamaño declarado al iniciar LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La FPGA necesita conocer la cantidad de bytes de programa esperada para delimitar una carga. La PC dispone de la imagen ensamblada y puede conocer su tamaño antes de transmitirla.

**Opciones consideradas:** declarar la longitud antes del contenido; delimitar el contenido mediante una marca de finalización.

**Decisión:** Cada solicitud de inicio de LOAD declarará el tamaño total de la imagen en **bytes**, antes de transferir las instrucciones. Para una carga aceptada, el receptor llevará el progreso privado y reconocerá la recepción completa al alcanzar exactamente el tamaño declarado.

El tamaño anunciado deberá ser mayor que cero, múltiplo de cuatro y no mayor que la capacidad configurada de IMEM, conforme a las restricciones de imagen ya aprobadas. Por ejemplo, ocho instrucciones de 32 bits corresponden a 32 bytes.

La recepción completa no constituye por sí sola el commit de la imagen ni una confirmación de carga exitosa. Se mantienen la validación y preparación completa de sesión exigidas por `DEC-SYS-003`, `DEC-ARCH-003` y `DEC-ARCH-006`; una carga aceptada incompleta o fallida permanece sin imagen ejecutable válida.

**Justificación:** La longitud explícita permite conocer el límite del contenido desde el inicio, comprobar su tamaño y transportar cualquier valor de instrucción sin reservar una marca dentro de la imagen.

**Consecuencias y alcance pendiente:** Se selecciona únicamente el tamaño declarado como delimitación del contenido de LOAD. Los acuerdos siguientes fijan la aceptación previa al envío y la confirmación final de carga exitosa. Permanecen abiertos la codificación y el ancho del campo externo de longitud, el framing, el orden de bytes, la codificación de respuestas, el control del envío posterior a la aceptación, la integridad, los datos excedentes y los timeouts o mecanismos de recuperación. Este acuerdo no prescribe paquetes para otras operaciones ni nuevas señales o estados RTL. La longitud no sustituye una comprobación de integridad.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-012`, `REQ-MEM-024`, `REQ-MEM-030`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** No aplica; acuerdo parcial que restringe las opciones restantes de `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Aceptación previa al envío del programa

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** El inicio de una carga puede rechazarse por tamaño inválido o por falta de elegibilidad del sistema. La PC necesita conocer el resultado de la solicitud antes de transmitir las instrucciones.

**Opciones consideradas:** enviar el programa inmediatamente después de la solicitud; esperar una aceptación explícita de la FPGA.

**Decisión:** La PC enviará primero la solicitud de inicio de LOAD con el tamaño declarado y esperará una respuesta explícita de aceptación de la FPGA antes de enviar el contenido del programa. La FPGA aceptará solo si el tamaño satisface las restricciones de imagen y LOAD es elegible según el estado global aprobado. Ante una solicitud rechazada, responderá con un rechazo y la PC no enviará el programa.

La aceptación comunicada corresponde al inicio efectivo de LOAD, con la invalidación de la imagen anterior ya exigida por la arquitectura. Una solicitud rechazada conserva la imagen vigente y no cancela un ciclo de ejecución continua. La respuesta de aceptación inicial no significa que el programa haya sido recibido, validado ni confirmado como ejecutable.

**Justificación:** La aceptación previa permite resolver una solicitud incompatible antes de transferir las instrucciones y establece cuándo puede comenzar el envío del contenido.

**Consecuencias y alcance pendiente:** Se fija el intercambio solicitud → aceptación o rechazo → contenido solo tras aceptación. El acuerdo siguiente fija la confirmación final de carga exitosa. Permanecen abiertos los códigos y campos de respuesta, el framing, el tratamiento de contenido enviado sin aceptación, el control del ritmo de transferencia, la integridad y la recuperación ante pérdida de la respuesta. No se define un ACK por byte o bloque ni un nuevo estado global. Los timeouts y reintentos corresponden a `DEC-PROTO-003`.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-012`, `REQ-MEM-019`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** No aplica; complementa el acuerdo de tamaño declarado sin cerrar `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Confirmación final de carga exitosa

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La PC necesita distinguir la aceptación inicial de LOAD de la disponibilidad efectiva del nuevo programa para ejecutar.

**Opciones consideradas:** inferir el éxito al terminar el envío; recibir una confirmación explícita de la FPGA después de completar la carga y preparar la sesión.

**Decisión:** La FPGA enviará una respuesta final de carga completada correctamente después de recibir la cantidad declarada de bytes, superar la validación de carga y completar la preparación y el commit de la nueva sesión. Esta respuesta significará que la imagen está confirmada y el sistema está listo para ejecutar; no iniciará automáticamente RUN ni STEP.

La respuesta será distinguible de la aceptación inicial. Solo podrá emitirse después del commit aprobado `PREPARING_READY && prepare_done`, que publica el tamaño confirmado y lleva el sistema a `READY`. Recibir el último byte o activar `load_ok` no basta para emitirla. Una carga fallida no emitirá confirmación de éxito y conservará el comportamiento de fallo cerrado ya aprobado.

**Justificación:** Una confirmación final explícita permite saber que el programa está disponible para ejecutar y que terminó la preparación de sesión, además de la recepción del contenido.

**Consecuencias y alcance pendiente:** El flujo exitoso será solicitud con tamaño → aceptación → contenido → validación y preparación → confirmación final. Permanecen abiertos los códigos y campos de respuesta, la integridad, las respuestas de fallo y los mecanismos ante pérdida de la confirmación. La pérdida de la respuesta no implica rollback de una sesión ya comprometida ni permite inferir que la carga falló; timeouts y recuperación corresponden a `DEC-PROTO-003`. Este acuerdo no agrega estados globales ni fija la FSM privada del transporte.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-008`, `REQ-MEM-024`, `REQ-MEM-030`, `REQ-EXEC-017`, `REQ-DBG-012`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** No aplica; complementa los acuerdos de tamaño declarado y aceptación previa sin cerrar `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — LOAD sin checksum ni CRC

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La consigna no exige checksum ni CRC para cargar programas. El equipo no observó alteraciones del contenido recibido por la UART del TP2 ni recibió correcciones por ausencia de estas comprobaciones. Para el alcance del laboratorio se prioriza un protocolo de carga sencillo.

**Opciones consideradas:** incorporar una comprobación de integridad del programa mediante checksum o CRC; cargarlo sin esa comprobación adicional.

**Decisión:** LOAD no incorporará checksum ni CRC del contenido del programa. El diseño asumirá que los bytes recibidos sin errores informados por la UART corresponden a los enviados. Esto es un supuesto del enlace para el trabajo práctico, no una garantía de detección de cualquier alteración.

Se mantienen las comprobaciones de tamaño, elegibilidad, recepción completa y preparación de sesión, junto con el tratamiento de los errores que informe UART y de las transferencias incompletas. La política concreta de fallo, los timeouts y la recuperación continúan pendientes. Una alteración que conserve la longitud y no produzca un error UART puede pasar inadvertida; la confirmación final de LOAD acredita el cumplimiento de las comprobaciones acordadas, sin certificar igualdad del contenido mediante checksum o CRC.

**Justificación:** El beneficio de la comprobación adicional no justifica su complejidad en el contexto y alcance acordados. La ausencia de checksum o CRC no elimina la necesidad de controlar las condiciones de carga ya aprobadas.

**Consecuencias y alcance pendiente:** No se agregarán campos de checksum o CRC del programa, cálculo ni comparación de estos valores en PC o FPGA para LOAD. Esta elección resuelve la comprobación de integridad del contenido de LOAD mencionada como pendiente en los acuerdos anteriores. No define por sí sola la protección de otras operaciones ni el framing; permanecen abiertos el orden de bytes, las codificaciones de mensajes, el ritmo de transferencia y el tratamiento de errores de transporte. No se modifica el contenido ni la validez de las instrucciones del ISA.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el punto de integridad del contenido de LOAD de los acuerdos parciales anteriores, sin cerrar `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Instrucciones de LOAD en little-endian

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** Cada instrucción tiene 32 bits y UART transporta bytes. El emisor y el Loader necesitan un orden inequívoco para reconstruir la word, respetando el orden consecutivo de instrucciones de la imagen.

**Opciones consideradas:** transmitir los bytes de cada instrucción desde el menos significativo al más significativo (little-endian); transmitirlos en el orden inverso (big-endian).

**Decisión:** Las instrucciones de LOAD se transmitirán en little-endian: para una word `W[31:0]`, se enviarán en orden `W[7:0]`, `W[15:8]`, `W[23:16]` y `W[31:24]`. Las instrucciones se enviarán en orden de dirección creciente, comenzando por la correspondiente a la dirección cero. Por ejemplo, `0x00A585B3` se transmitirá como los cuatro bytes `B3 85 A5 00`.

El Loader reconstruirá una word completa de 32 bits antes de habilitar su escritura síncrona en IMEM. Para los bytes recibidos consecutivamente `b0`, `b1`, `b2`, `b3`, la word será `{b3, b2, b1, b0}`. No se escribirá una instrucción incompleta ni se modificará la codificación de la instrucción.

**Justificación:** El transporte coincide con el little-endian arquitectónico ya aprobado para memoria y mantiene una correspondencia directa entre bytes de la imagen y direcciones crecientes.

**Consecuencias y alcance pendiente:** Se fija únicamente el orden de los bytes del contenido de instrucciones de LOAD. No se extiende esta elección al campo de longitud, a direcciones externas, a respuestas ni a snapshots; su codificación y orden de bytes permanecen pendientes. Tampoco se cambia el orden de bits dentro de cada byte de la UART ni se fija el framing del protocolo.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-023`, `REQ-MEM-024`, `REQ-MEM-027`, `REQ-SW-004`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el orden de bytes de las instrucciones de LOAD mencionado como pendiente en los acuerdos anteriores, sin cerrar `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-003 — Timeout de recepción para LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y recuperación.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** Una carga aceptada puede dejar de recibir datos antes de alcanzar el tamaño declarado. La FPGA debe detectar esa interrupción. Como antecedente, el controlador de ALU del TP2 aplica `TRANSACTION_TIMEOUT_MS`, con valor predeterminado de 10 ms, mientras espera B o el opcode después de recibir parte de la transacción; recibir el siguiente byte reinicia la espera. Véase [alu_uart_controller.sv](../../tp2/rtl/alu_uart_controller.sv).

**Opciones consideradas:** permanecer esperando indefinidamente el contenido faltante; detectar la inactividad mediante un timeout de recepción en la FPGA.

**Decisión:** LOAD tendrá un timeout de recepción en la FPGA mientras esté pendiente contenido del programa. Si se supera el intervalo permitido sin recibir un nuevo byte del contenido de la carga, se declarará fallida la carga. Cada nuevo byte aceptado como contenido reiniciará el intervalo de inactividad mientras falten bytes. El timeout medirá inactividad de recepción, no la duración total de transferencia de una imagen.

Una carga fallida por timeout no publicará una imagen ejecutable ni emitirá la confirmación final de éxito. Se conserva la invalidación que ocurre al aceptar LOAD; no se restaura el programa anterior. Este timeout es un error de comunicación de LOAD y no un fault arquitectónico de una instrucción.

**Justificación:** La detección de una transferencia interrumpida evita que una carga incompleta permanezca esperando indefinidamente. Reutiliza el criterio de inactividad del TP2 sin depender del tamaño total del programa.

**Consecuencias y alcance pendiente:** El acuerdo siguiente de `DEC-PROTO-001` fija la existencia de una respuesta de fallo por recepción incompleta. Quedan pendientes el valor temporal, el instante inicial de activación alrededor de la aceptación y la espera del primer byte, la prioridad de coincidencias, la codificación de esa respuesta y la recuperación/resincronización, incluidos bytes tardíos y pendientes en FIFO. Los 10 ms del TP2 constituyen un antecedente, no un valor aprobado para TP3. No se adopta automáticamente el retorno a esperar una nueva transacción del controlador TP2; el transporte debe resolver la realineación antes de interpretar bytes residuales como comandos nuevos. Los timeouts de la PC, comandos incompletos y otras operaciones continúan pendientes. No se introduce un nuevo estado global ni se fija el contador o la FSM privada.

**Requisitos afectados:** `REQ-UART-002`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia de timeout de recepción para LOAD de los acuerdos anteriores, sin cerrar `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Respuesta de fallo por recepción incompleta

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** El timeout de recepción de LOAD ya está aprobado. La PC necesita conocer que la FPGA declaró fallida la carga y distinguirlo de una aceptación inicial o una carga exitosa.

**Opciones consideradas:** detectar el fallo únicamente por ausencia de confirmación final; emitir una respuesta explícita de fallo desde la FPGA.

**Decisión:** Cuando venza el timeout de recepción de contenido de una carga aceptada, la FPGA enviará una respuesta que identifique el fallo de LOAD por recepción incompleta. El significado lógico será «carga fallida: recepción incompleta», sin fijar una representación textual o binaria ni un código concreto.

El programa permanecerá inválido y no se emitirá la confirmación final de éxito. La respuesta de fallo será distinguible de la aceptación inicial y de la confirmación de carga completada. No será un fault arquitectónico de una instrucción ni una finalización de ejecución por `halt`.

**Justificación:** Una respuesta explícita comunica el resultado de la carga a la PC sin depender exclusivamente de que esta agote su propia espera.

**Consecuencias y alcance pendiente:** Quedan abiertos el framing, los códigos y campos, el envío ante TX ocupado, la pérdida de la respuesta, las respuestas a otros errores y la recuperación/resincronización. Informar el fallo no implica que el enlace ya pueda aceptar un comando nuevo ni garantiza que la PC haya recibido la respuesta. Estos aspectos se completarán en `DEC-PROTO-001` y `DEC-PROTO-003`.

**Requisitos afectados:** `REQ-UART-002`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia y significado de la respuesta de fallo por timeout de contenido de LOAD, sin cerrar `DEC-PROTO-001` ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-002 — Reset global desde PC y botón físico

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-002` permanece pendiente en sus aspectos restantes.

**Dominio:** Sistema / Debug / Protocolo de control.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** El usuario solicita poder resetear el sistema desde el software de PC y conservar el botón de la placa como otra forma de solicitar reset global. Esta capacidad es independiente de la recuperación específica de una carga incompleta.

**Opciones consideradas:** utilizar únicamente el reset físico; ofrecer además una solicitud de reset global mediante UART desde la PC.

**Decisión:** El protocolo ofrecerá una operación de reset global solicitada desde la PC mediante UART. El botón físico de la placa seguirá siendo otra fuente de solicitud del mismo reset global. Ambas vías producirán los efectos lógicos y la prioridad ya aprobados en `DEC-ARCH-008`, sin cambiar la semántica de reset ni la preparación posterior de sesión.

La operación UART, una vez recibida y reconocida válidamente, solicitará reset global también durante ejecución continua, sin esperar `halt`. El sistema quedará seguro, detenido y sin imagen ejecutable válida; una nueva ejecución requerirá una carga válida posterior. El reset del sistema no implica volver a sintetizar ni reconfigurar el bitstream de la FPGA.

**Justificación:** El control desde PC permite solicitar reset sin intervención sobre el botón, mientras la vía física mantiene disponible la recuperación externa cuando el enlace no está operativo.

**Consecuencias y alcance pendiente:** Se agrega reset global al conjunto de servicios UART. Quedan abiertos su codificación, respuestas, confirmación de disponibilidad posterior, tratamiento de bytes pendientes y reconocimiento durante carga o recuperación del transporte. Un byte de contenido de LOAD no podrá confundirse con este comando. La generación, duración y distribución concreta de la solicitud UART y del botón se definirán en integración, respetando el dominio común y el acondicionamiento aprobado. No se selecciona GUI, un comando UART de reset de recepción, un reintento automático ni el reset global como recuperación obligatoria de LOAD fallido.

**Requisitos afectados:** `REQ-UART-006`, `REQ-EXEC-015`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-012`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la exposición UART de reset global prevista como pendiente en `DEC-ARCH-008` y `DEC-PROTO-002`; conserva el reset físico y no cierra `DEC-PROTO-002`.

### Acuerdo parcial de DEC-PROTO-003 — Recuperación automática y reintento solicitado por el usuario

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y recuperación.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** Se deben separar la recuperación de la recepción después de una carga fallida y la decisión de reenviar el programa. El reset global solicitado por UART o botón constituye una operación independiente ya aprobada.

**Opciones consideradas:** requerir una intervención del usuario para recuperar la recepción; recuperar automáticamente la recepción y dejar el reenvío a elección del usuario; recuperar y reenviar automáticamente.

**Decisión:** Después de declarar fallida una carga, se recuperará automáticamente el estado de recepción y se resincronizará el enlace hasta dejarlo preparado para otra solicitud. Esta recuperación específica de LOAD no requerirá que el usuario solicite reset global ni presione el botón físico. Se descartará la recepción parcial y se resolverán los bytes pendientes del intento anterior antes de interpretar comandos nuevos.

El reenvío del programa será solicitado por el usuario desde la PC. La acción de reintentar se traducirá en una nueva operación LOAD completa: solicitud con tamaño, espera de aceptación, transferencia de todas las instrucciones desde el comienzo y confirmación final tras validación y preparación. No se reanudará desde el byte donde se interrumpió la carga ni se reenviará automáticamente. No se incorpora un comando adicional RETRY ni se selecciona el formato de interfaz de PC.

Durante la recuperación la imagen seguirá inválida y no se habilitarán RUN ni STEP. La PC y la FPGA deberán coordinar el cese del envío anterior y la eliminación o delimitación de sus datos pendientes antes de iniciar la nueva LOAD. La respuesta de fallo ya aprobada no acredita por sí sola que esa recuperación haya terminado.

**Justificación:** La recuperación automática evita exigir una intervención para liberar la recepción, mientras el reintento solicitado por el usuario mantiene explícita la decisión de repetir la carga y permite inspeccionar un fallo antes de reenviar.

**Consecuencias y alcance pendiente:** Se fija la política de recuperación y reintento. El acuerdo siguiente de `DEC-PROTO-001` fija una indicación común de disponibilidad para LOAD. Quedan abiertos el mecanismo de resincronización, la codificación y obtención de esa indicación por la PC, el tratamiento de bytes tardíos, vaciado de buffers y delimitación, los tiempos, la pérdida de respuestas y el papel de un posible comando de resincronización. No basta con vaciar una FIFO una sola vez y aceptar inmediatamente nuevos comandos si aún pueden llegar datos del intento anterior. El reset global conserva su función independiente y sus vías UART y física.

**Requisitos afectados:** `REQ-UART-002`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la política de recuperación y reintento de LOAD, sin cerrar el mecanismo concreto ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Disponibilidad común para iniciar LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y disponibilidad.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La PC necesita conocer la disponibilidad del receptor tanto antes de la primera carga como después de recuperar una transferencia fallida. El usuario propone generalizar el aviso para cubrir ambas situaciones y la disponibilidad posterior al reset global.

**Opciones consideradas:** indicar disponibilidad únicamente después de una carga fallida; utilizar una indicación común de disponibilidad para iniciar LOAD.

**Decisión:** El protocolo proporcionará a la PC una indicación con el significado «disponible para recibir una solicitud LOAD». La misma indicación se utilizará antes de la primera carga, cuando el sistema esté operativo tras arranque o reset global, y al completar la recuperación/resincronización de una carga fallida. Solo podrá indicar disponibilidad cuando el transporte permita interpretar una nueva solicitud y el estado global sea elegible para LOAD.

Esta indicación no significa que exista un programa válido ni que la CPU esté lista para ejecutarlo. Tampoco equivale a aceptar una carga concreta: después de obtener disponibilidad, la PC enviará la solicitud con tamaño y esperará su aceptación, que verificará tamaño y elegibilidad actual. No se introduce un nuevo estado global ni se identifica este aviso con el estado interno `READY` de una imagen confirmada.

**Justificación:** Una indicación común hace consistente el inicio de la primera carga y de un reintento, y permite observar que terminó la recuperación del receptor.

**Consecuencias y alcance pendiente:** El acuerdo siguiente de `DEC-PROTO-002` fija una consulta iniciada por la PC para obtener la disponibilidad. Quedan pendientes códigos, campos, framing, momentos permitidos, esperas y recuperación ante falta de respuesta. La indicación posterior a una carga fallida requerirá que la resincronización realmente haya terminado. La regla sobre consulta previa a LOAD se fija en el acuerdo de secuencia posterior.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-002`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia y significado común del aviso de disponibilidad para LOAD, sin cerrar su transporte ni `DEC-PROTO-001` o `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-002 — Consulta de disponibilidad iniciada por PC

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-002` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de control y disponibilidad.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** La PC puede conectarse cuando la FPGA ya está encendida. Una emisión única de disponibilidad durante el arranque no garantiza que la PC haya recibido esa información. El usuario aprueba obtener la disponibilidad mediante una consulta iniciada desde la PC.

**Opciones consideradas:** depender de un aviso espontáneo de la FPGA; consultar desde la PC y obtener una respuesta de disponibilidad.

**Decisión:** El protocolo ofrecerá una consulta de disponibilidad iniciada por la PC. Cuando el receptor pueda interpretar válidamente la consulta, la FPGA responderá si está disponible para recibir una solicitud LOAD, conforme al significado aprobado en `DEC-PROTO-001`. La consulta será informativa y repetible; no iniciará LOAD, no reseteará el sistema ni modificará la imagen o el estado arquitectónico de la CPU.

La PC podrá obtener así la disponibilidad al conectar, después de un reset y antes de reintentar una carga fallida, sin depender de haber escuchado una emisión durante el arranque. Se mantienen las respuestas ya aprobadas de aceptación, éxito y fallo de LOAD. La consulta no sustituye la solicitud con tamaño ni su aceptación.

**Justificación:** El intercambio iniciado por la PC permite obtener la información cuando la aplicación está escuchando y reutiliza la misma operación en conexión inicial, reset y recuperación.

**Consecuencias y alcance pendiente:** Quedan abiertos la codificación, respuestas, timeout de consulta, repetición ante falta de respuesta y tratamiento durante LOAD o resincronización. Un byte del programa no podrá interpretarse como consulta. El acuerdo siguiente fija la secuencia que debe seguir la PC y mantiene la validación de cada LOAD por la FPGA sin exigir memoria de una consulta anterior.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-002`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el mecanismo de obtención de disponibilidad por consulta de PC, sin cerrar `DEC-PROTO-002` ni las reglas restantes de secuencia.

### Acuerdo parcial de DEC-PROTO-001 — Secuencia de PC y validación independiente de LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y contrato de PC.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** Se debe precisar la secuencia del cliente y si una consulta de disponibilidad previa constituye una condición de aceptación de LOAD por la FPGA. El usuario aprueba distinguir la secuencia de PC de la validación de cada solicitud de carga.

**Opciones consideradas:** exigir una consulta previa y recordarla en la FPGA para habilitar LOAD; establecer la secuencia de PC y validar LOAD por sus propias condiciones actuales.

**Decisión:** Antes de cada intento de carga, incluido un reintento, la PC consultará disponibilidad y esperará una respuesta disponible. Luego solicitará LOAD con el tamaño en bytes y esperará su aceptación antes de enviar instrucciones. Tras transferir el contenido esperará la confirmación final o el fallo de la operación según las reglas aprobadas. Una respuesta ocupada o la ausencia de respuesta a la consulta no habilitará el envío del programa por el flujo de PC.

La FPGA validará cada solicitud LOAD según su formato válido, tamaño, elegibilidad actual del estado global y disponibilidad efectiva del receptor. La ausencia de una consulta previa no será por sí misma causa de rechazo de una LOAD que satisfaga sus condiciones. Una consulta anterior no reservará el receptor ni hará aceptable una solicitud incompatible; la aceptación de LOAD seguirá siendo la autorización concreta para transferir el contenido.

**Justificación:** El cliente sigue un flujo explícito y la FPGA comprueba las condiciones de la operación en el momento correspondiente. La consulta informativa no exige introducir un registro de consulta anterior, su caducidad ni nuevas condiciones de elegibilidad arquitectónica.

**Consecuencias y alcance pendiente:** No se agregará una condición de habilitación de LOAD basada en haber consultado previamente. Quedan pendientes la codificación, framing, esperas, respuesta a ocupado, pérdida de respuestas y resincronización. Se deberán verificar ambas reglas: el flujo de PC consulta y espera aceptación; la FPGA acepta o rechaza LOAD por sus condiciones actuales incluso cuando se omite la consulta o cuando existe una consulta anterior.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-007`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve las reglas de consulta previa y aceptación de LOAD pendientes en los acuerdos anteriores, sin cerrar el protocolo completo.

### Acuerdo parcial de DEC-PROTO-001 — Código de operación y tamaño de LOAD de cinco bytes

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Formato de solicitudes UART.

**Fecha de aprobación:** 2026-09-30.

**Contexto:** El receptor debe reconocer la operación solicitada y cuándo recibió todos sus campos. El usuario aprueba que el código determine el formato y que LOAD incluya cinco bytes de tamaño.

**Opciones consideradas:** solicitudes con formato conocido según el código; delimitar cada solicitud con una marca de finalización adicional. Para LOAD se selecciona un campo fijo capaz de representar la capacidad arquitectónica inclusive.

**Decisión:** En recepción alineada, cada solicitud comenzará con un código de operación de **un byte**. El código determinará los campos siguientes y su formato. Los valores de los códigos y los campos de las otras operaciones permanecen pendientes.

La solicitud LOAD tendrá exactamente **seis bytes de datos UART**: un byte de código LOAD seguido de cinco bytes que representan el tamaño total del programa en bytes como entero sin signo, en little-endian. Si esos cinco bytes son `b0` a `b4`, el tamaño será `b0 + (b1 << 8) + (b2 << 16) + (b3 << 24) + (b4 << 32)`, interpretado sin truncamiento en 40 bits. Por ejemplo, 32 bytes se anunciarán como `[código LOAD] 20 00 00 00 00`; el tamaño arquitectónico máximo de `2^32` bytes como `[código LOAD] 00 00 00 00 01`.

El receptor esperará los cinco bytes de tamaño antes de validar la solicitud. El tamaño recibido deberá ser mayor que cero, múltiplo de cuatro y no mayor que la capacidad activa de IMEM. Se validará el valor completo antes de reducirlo al ancho interno del perfil; valores altos no podrán truncarse y convertirse en tamaños aparentemente válidos. Los 40 bits del campo externo no amplían el límite arquitectónico de `2^32` bytes.

Una solicitud incompleta o rechazada no producirá el inicio de LOAD ni invalidará por sí sola la imagen vigente. Una solicitud completa aceptada aplicará la invalidación ya aprobada y enviará aceptación. Las instrucciones se transferirán posteriormente, después de que la PC reciba esa aceptación; no forman parte de los seis bytes de la solicitud.

**Justificación:** Un formato conocido por código permite determinar cuándo termina una solicitud correctamente alineada. Cinco bytes de tamaño cubren el límite arquitectónico inclusive y mantienen un formato fijo independiente del perfil sintetizado.

**Consecuencias y alcance pendiente:** Los bits físicos de Start/Stop de UART no se cuentan entre estos seis bytes ni en el tamaño del programa. El acuerdo posterior de `DEC-PROTO-003` fija timeout para la recepción incompleta de los cinco bytes de tamaño. Quedan abiertos los valores de códigos, campos de otras operaciones y respuestas, tratamiento de códigos desconocidos, duración y respuesta de ese timeout, datos excedentes y recuperación de alineación. Este formato no resuelve por sí solo la resincronización tras un error y no modifica los parámetros físicos UART del TP2 o TP3.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-MEM-012`, `REQ-MEM-024`, `REQ-MEM-030`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el formato de solicitudes y el ancho y orden de bytes del tamaño de LOAD pendientes en los acuerdos anteriores, sin cerrar el protocolo completo.

### Acuerdo parcial de DEC-PROTO-003 — Timeout de solicitud LOAD incompleta

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Recepción de solicitudes y recuperación.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Una solicitud LOAD comprende el código de operación y cinco bytes de tamaño. El envío puede interrumpirse después del código y antes de completar el tamaño, cuando la carga todavía no fue aceptada.

**Opciones consideradas:** esperar indefinidamente los bytes faltantes de tamaño; aplicar timeout a la solicitud parcial y descartarla.

**Decisión:** Después de reconocer el código LOAD, el receptor aplicará timeout de inactividad mientras falte alguno de los cinco bytes de tamaño. Cada byte aceptado como parte del tamaño reiniciará la espera mientras queden bytes pendientes. Si vence el timeout antes de completar el campo, se descartará la solicitud incompleta y su progreso privado.

Una solicitud descartada por este timeout no iniciará LOAD, no escribirá instrucciones ni invalidará la imagen vigente. Tampoco modificará por sí sola el estado de ejecución o el estado arquitectónico de la CPU; una ejecución ya activa podrá continuar según sus reglas ordinarias. Si no había imagen válida, el descarte no creará una. No se emitirá aceptación ni confirmación de carga exitosa para esa solicitud incompleta.

Este caso se distingue del timeout del contenido de una carga ya aceptada: solo la aceptación efectiva de LOAD invalida la imagen anterior, y una falla posterior deja al sistema sin imagen ejecutable. El timeout del tamaño no fuerza ese efecto ni exige reset global.

**Justificación:** El receptor puede abandonar una solicitud interrumpida sin quedar esperando indefinidamente ni producir efectos de una operación que todavía no fue aceptada.

**Consecuencias y alcance pendiente:** El acuerdo siguiente de `DEC-PROTO-001` fija una respuesta específica de solicitud LOAD incompleta y el acuerdo posterior de `DEC-PROTO-003` fija un valor temporal común con la recepción del contenido. Quedan pendientes la duración concreta, prioridad de coincidencias, codificación y entrega de la respuesta, bytes tardíos y mecanismo de resincronización. Descartar el tamaño parcial no basta para interpretar inmediatamente cualquier byte posterior como un comando nuevo. La respuesta de fallo de una carga aceptada conserva su significado separado. No se agrega un estado global ni se fija la FSM privada del receptor.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-MEM-024`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia y efecto del timeout de solicitud LOAD incompleta, sin cerrar su duración, respuesta o recuperación ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Respuesta de solicitud LOAD incompleta

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Respuestas a solicitudes UART.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se aprobó descartar por timeout una solicitud LOAD cuyo campo de tamaño no se completó, conservando la imagen vigente. La PC debe distinguir ese rechazo del fallo de una transferencia de instrucciones que ya fue aceptada.

**Opciones consideradas:** inferir el rechazo por falta de aceptación; emitir una respuesta explícita de solicitud incompleta.

**Decisión:** Si vence el timeout de recepción de los cinco bytes de tamaño después del código LOAD, la FPGA enviará una respuesta con el significado «solicitud LOAD incompleta». Será identificable como error de recepción de la solicitud, antes de la aceptación de carga, y distinguible de «carga fallida: recepción incompleta», que corresponde al contenido de una LOAD ya aceptada.

La solicitud se descartará sin aceptar LOAD, sin escribir instrucciones ni invalidar la imagen vigente. Se mantendrán los efectos aprobados del timeout de solicitud incompleta; esta respuesta no constituye un fault arquitectónico, un reset, una aceptación ni una confirmación de carga exitosa.

**Justificación:** Una respuesta explícita permite que la PC conozca el resultado de la solicitud y en qué fase ocurrió el error, con la semántica correspondiente de conservación de imagen.

**Consecuencias y alcance pendiente:** Se fija el significado de la respuesta, no un texto literal enviado por UART ni sus códigos, campos o longitud. Quedan abiertos el framing, la entrega ante TX ocupado, pérdida de la respuesta, tratamiento de bytes tardíos y recuperación de alineación. Informar el rechazo no indica por sí solo que el receptor ya esté preparado para recibir otro comando.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-MEM-024`, `REQ-DBG-001`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la existencia y significado de la respuesta al timeout de solicitud LOAD incompleta, sin cerrar su codificación, entrega o recuperación ni `DEC-PROTO-001` o `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Tiempo de inactividad común para tamaño y contenido

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Temporización de recepción de LOAD.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se aprobaron timeouts de inactividad tanto para completar el tamaño de la solicitud como para recibir el contenido de una carga aceptada. Ambas esperas detectan ausencia del próximo byte.

**Opciones consideradas:** duraciones independientes según la fase; utilizar una duración común para ambas esperas.

**Decisión:** Se utilizará un único valor temporal de timeout de inactividad para la recepción de los cinco bytes del tamaño y para la recepción del contenido de LOAD. El símbolo `T` identifica ese valor común sin fijar nombre de parámetro RTL, unidades de codificación ni duración numérica. Cada byte aceptado de la fase correspondiente reiniciará la espera mientras falten bytes.

El valor común no modifica las consecuencias específicas de cada fase: si vence mientras se recibe el tamaño, se descarta la solicitud, se informa solicitud LOAD incompleta y se conserva la imagen vigente; si vence durante el contenido de una LOAD ya aceptada, se informa carga fallida y se mantiene la imagen inválida. No se aplica un límite `T` a la duración total de transferencia del programa.

**Justificación:** Se detecta la misma condición de inactividad mediante un criterio temporal único, manteniendo separados los efectos de la solicitud parcial y de la carga aceptada.

**Consecuencias y alcance pendiente:** Quedan pendientes el valor numérico, conversión al clock funcional, activación inicial de la espera del contenido alrededor de la aceptación y el primer byte, prioridad de coincidencias, respuestas y recuperación. Compartir duración no exige un contador físico único ni una FSM específica. No se extiende automáticamente el mismo valor a timeouts de PC, consulta, transmisión o resincronización. Los 10 ms del TP2 siguen siendo un antecedente, sin aprobarse como duración de TP3.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el uso de un valor temporal común para las dos fases de recepción de LOAD, sin cerrar su duración ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Transferencia seguida del programa

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Transferencia del contenido de LOAD.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Debe definirse si el programa se transmite seguido después de aceptar LOAD o mediante bloques con confirmaciones intermedias. El usuario elige transmitirlo seguido para mantener sencillo el protocolo.

**Opciones consideradas:** transferencia seguida del contenido; bloques o instrucciones con confirmaciones intermedias.

**Decisión:** Después de recibir la aceptación de LOAD, la PC enviará el contenido completo anunciado como una única transferencia lógica de bytes en orden de dirección creciente y con cada instrucción en little-endian. No esperará confirmaciones por byte, instrucción o bloque. En el flujo exitoso, al terminar el envío esperará la confirmación final de carga tras validación, preparación y commit ya aprobados.

La FPGA recibirá el stream, reconstruirá cada word completa de cuatro bytes y podrá escribirla en IMEM durante la recepción, con el ownership aprobado. No se requiere acumular el programa completo en un buffer intermedio antes de escribir IMEM. La cantidad de bytes del contenido sigue siendo exactamente la anunciada; el contenido no se interpretará como códigos de operación.

Transferir seguido no exige que todos los bytes lleguen sin ningún intervalo ni realizar una única llamada al sistema desde la PC. Los buffers o fragmentaciones internas de PC y del adaptador no introducen bloques de protocolo ni confirmaciones intermedias. Las pausas permitidas y la duración del timeout común permanecen pendientes.

Se mantienen las respuestas de error, timeout, fallo cerrado y recuperación acordadas. Si la carga falla durante el envío, la PC deberá detener el intento anterior y coordinar su recuperación; el envío seguido no obliga a completar un intento que ya fue declarado fallido ni permite mezclar comandos nuevos con su contenido pendiente.

**Justificación:** El tamaño declarado delimita la transferencia y la aceptación autoriza el envío completo. Evitar confirmaciones intermedias simplifica el control de transmisión, recepción y progreso de la carga.

**Consecuencias y alcance pendiente:** El diseño de UART, FIFO y Loader deberá sostener el ritmo de bytes de la configuración elegida, con un presupuesto de latencia de consumo y buffers que evite desbordamiento durante una carga correcta. No se aprueba una profundidad de FIFO ni se acredita todavía ese presupuesto. Quedan pendientes baud/formato físico, pausas permitidas del emisor, dimensionado y manejo de buffers, errores de recepción y resincronización. El valor numérico del timeout se justificará después de cerrar esos contratos.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-009`, `REQ-MEM-024`, `REQ-MEM-027`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el modo de transferencia del programa y descarta confirmaciones intermedias de contenido, sin cerrar su temporización, buffers o recuperación ni `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-003 — Recuperación por descarte y silencio del enlace

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Recuperación de recepción y coordinación con PC.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Tras abandonar una recepción incompleta pueden llegar bytes del intento anterior. Interpretarlos inmediatamente como comandos nuevos perdería la alineación del protocolo. El usuario aprueba conjuntamente las seis decisiones propuestas para recuperar el enlace.

**Opciones consideradas:** volver inmediatamente a interpretar comandos después de limpiar la recepción parcial; descartar los datos pendientes y esperar silencio del enlace, coordinado con el cese del envío desde PC.

**Decisión:** Para recuperar los timeouts de tamaño y contenido de LOAD se aplicará el siguiente contrato:

1. **Limpieza inicial:** Se descartarán la solicitud o instrucción parcial y los bytes pendientes en la FIFO RX. Se conservará la vía TX para enviar la respuesta de error correspondiente. La limpieza de recepción no producirá reset global: antes de aceptar LOAD se conserva la imagen vigente y la ejecución puede continuar; después de aceptar LOAD la imagen permanece inválida.
2. **Descarte durante recuperación:** Se consumirán y descartarán todos los bytes que lleguen, incluidos aquellos cuyo valor coincida con una consulta, LOAD o reset UART. No se interpretarán comandos ni se anunciará disponibilidad durante esta fase. No se fija un estado adicional de la FSM global ni la implementación de la FSM privada de recepción.
3. **Cese del intento desde PC:** Al recibir el error, la PC dejará de transmitir el intento anterior y cancelará el envío pendiente en lo que permita el transporte. Aplicará también este procedimiento si vence su propia espera de respuesta. Los bytes ya en tránsito o que no puedan cancelarse quedarán cubiertos por el contrato temporal de recuperación.
4. **Silencio efectivo:** La espera de recuperación comenzará al entrar en esa fase y se reiniciará ante cualquier actividad de recepción. Solo finalizará después de un intervalo completo de silencio, con la línea en reposo, ningún byte en curso y la FIFO RX vacía. Vaciar la FIFO una sola vez no basta.
5. **Intervalo independiente:** El símbolo `R` identifica la duración de silencio, todavía sin valor numérico. Es independiente del timeout de recepción `T`. Su elección se justificará con la reacción y cancelación desde PC y el tiempo máximo de llegada de los bytes pendientes, incluidos los buffers del transporte.
6. **Retorno al flujo de PC:** Después de detener/cancelar el intento, la PC esperará una ventana acordada antes de consultar disponibilidad. Esa ventana deberá cubrir los datos pendientes, el timeout de recepción que aún pudiera estar activo si se perdió una respuesta y la recuperación por silencio. Si la consulta no recibe respuesta, la PC esperará nuevamente antes de repetirla; no enviará consultas continuamente que impidan completar el silencio. Una respuesta disponible habilita el flujo ya aprobado de nueva LOAD completa, solicitada por el usuario.

La recuperación depende de que la PC abandone el envío anterior y de un límite explícito para la llegada de sus bytes pendientes. El silencio por sí solo no garantiza alineación frente a datos arbitrariamente tardíos. Esos límites, `R` y las ventanas de PC deberán quedar justificados y cerrados antes del gate D0; no se aprueba una duración por defecto.

**Justificación:** El descarte elimina los restos de la operación abandonada y el silencio permite retornar a un límite entre solicitudes bajo el contrato temporal acordado, sin exigir reset global ni agregar un comando RETRY.

**Consecuencias y alcance pendiente:** Queda fijado el mecanismo de recuperación para los timeouts de LOAD y el tratamiento de consultas y reset UART durante esa recuperación. Quedan pendientes los valores y conversiones temporales, los límites del transporte, el dimensionado de buffers, las señales que permitan observar actividad y recepción en curso, las prioridades en coincidencias y la codificación/entrega de respuestas ante TX ocupado o pérdida. La política para otros errores UART, códigos desconocidos y datos excedentes se definirá aparte; no se extiende automáticamente este mecanismo a todos ellos. No se congela una lista nueva de puertos ni se acredita aún la viabilidad temporal.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el mecanismo pendiente de recuperación de los timeouts de LOAD y sus seis reglas de coordinación, conservando las políticas previas de imagen, respuestas y reintento. No cierra su temporización ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Errores básicos de LOAD y alcance del trabajo práctico

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` y `DEC-PROTO-003` permanecen pendientes en sus aspectos restantes.

**Dominio:** Debug / Protocolo de carga y alcance de diseño.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba las políticas propuestas para tamaño inválido, error UART y bytes adicionales, y establece que el diseño debe mantener un alcance proporcional al TP. La aplicación de PC y la FPGA serán diseñadas conjuntamente y se asume que la PC respeta el protocolo.

**Opciones consideradas:** comprobaciones y recuperación básicas bajo el contrato del cliente propio; ampliar el protocolo para cubrir emisores independientes y violaciones arbitrarias de ese contrato.

**Decisión:** Se adoptan las siguientes políticas:

1. **Tamaño inválido:** Recibidos los cinco bytes de tamaño, se rechaza LOAD si el valor es cero, no es múltiplo de cuatro o supera IMEM. La respuesta identifica «tamaño inválido» y se conserva la imagen anterior. Una solicitud completa y alineada rechazada por ese motivo no requiere recuperación por silencio; la PC no envía contenido.
2. **Error UART durante recepción de LOAD:** Se abandona inmediatamente la recepción y se aplica la recuperación por descarte y silencio ya aprobada. Si LOAD todavía no fue aceptada, se conserva la imagen anterior; si fue aceptada, queda inválida. La respuesta identifica «error de recepción UART» sin exigir distinguir error de trama y desbordamiento de RX.
3. **Bytes posteriores al contenido:** Solo se escriben los bytes anunciados. Desde la recepción del último byte hasta terminar la preparación y el envío de la confirmación final, se descartan los bytes adicionales sin interpretarlos como comandos ni modificar el programa. Si el contenido esperado se recibió correctamente y se completa la preparación, se mantiene el éxito de LOAD. Después de la confirmación se retorna a la interpretación normal de solicitudes.

El contrato de uso presupone que la PC envía exactamente el tamaño anunciado, espera aceptación antes del contenido y espera el resultado final antes de otra operación. No se agregan mecanismos ni nuevos pendientes para detectar sobrantes arbitrariamente tardíos o para protegerse de un cliente que incumple deliberadamente esa secuencia. Se conservan los timeouts y la recuperación básica acordados.

**Justificación:** Las comprobaciones cubren errores básicos de solicitud y recepción sin ampliar el diseño más allá del enlace de laboratorio y del cliente propio del TP.

**Consecuencias y alcance pendiente:** Quedan resueltas estas políticas y la extensión de la recuperación a errores UART durante la recepción de LOAD. Permanecen pendientes la codificación de respuestas, su integración temporal, los parámetros UART y los tiempos ya diferidos. El alcance no exige distinguir todas las causas físicas de recepción ni demostrar robustez ante emisores arbitrarios. No se agregan campos, comandos o estados globales por esos escenarios.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-EXEC-017`, `REQ-DBG-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve tamaño inválido, errores UART durante LOAD y descarte posterior al contenido. Delimita la robustez requerida al contexto del TP sin cerrar el protocolo completo.

### Acuerdo parcial de DEC-PROTO-001 — Numeración consecutiva de códigos de operación

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Codificación de solicitudes.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El formato ya aprobado establece un byte de código por solicitud, pero todavía falta cerrar el conjunto de comandos y algunos comportamientos. El usuario establece la regla de numeración y difiere la asignación concreta.

**Decisión:** Cada código de operación ocupará un byte binario. Los códigos se asignarán consecutivamente desde `0x01`: `0x01`, `0x02`, `0x03`, etc. La correspondencia entre esos valores y las operaciones se definirá cuando se cierre el conjunto de comandos.

La tabla propuesta de LOAD, RUN, STEP, READ_STATE, RESET y QUERY_READY no constituye una asignación aprobada. Se mantienen los servicios y comportamientos previamente acordados, sin fijar aquí nombres finales, operaciones adicionales ni sus valores individuales. Esta regla corresponde a solicitudes de PC hacia FPGA; no define los códigos de respuesta.

**Justificación:** Permite fijar una convención sencilla sin anticipar una tabla para operaciones cuyo diseño aún está abierto.

**Consecuencias y alcance pendiente:** Quedan pendientes la lista final de comandos, su orden en la tabla, la asignación individual y la codificación de respuestas. El ancho de un byte confirma el acuerdo anterior; no cambia el formato de seis bytes de la solicitud LOAD.

**Requisitos afectados:** `REQ-UART-008`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Fija la regla general de numeración sin cerrar la tabla ni `DEC-PROTO-001`.

### Acuerdo parcial de DEC-PROTO-001 — Cabecera común de respuestas y resultados de LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Formato de respuestas.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba que cada respuesta empiece con el código de la solicitud correspondiente y continúe con el contenido de respuesta, comenzando por un resultado. Se concreta ese formato para las respuestas básicas de LOAD, sin asignar todavía valores numéricos.

**Decisión:** Toda respuesta correspondiente a una solicitud tendrá la forma `[código de operación: 1 byte][resultado: 1 byte][datos, si corresponden]`. El primer byte repetirá el código de la solicitud; el segundo identificará el resultado y formará parte del contenido de respuesta. Los datos adicionales y su delimitación dependerán de la operación y del resultado, y se definirán al especificar esa respuesta.

Las respuestas de LOAD no llevarán datos adicionales: tendrán exactamente dos bytes y finalizarán al recibir el segundo. Se aprueban los siguientes resultados simbólicos, con los efectos ya acordados:

| Resultado | Significado |
|---|---|
| `ACEPTADA` | LOAD fue aceptada; la PC puede comenzar a enviar el programa. |
| `COMPLETADA` | Se recibió y validó el programa y se completó preparación y commit de sesión; el sistema está listo para ejecutar. |
| `TAMAÑO_INVALIDO` | Solicitud rechazada por tamaño cero, no múltiplo de cuatro o superior a IMEM. |
| `NO_DISPONIBLE` | El estado actual no permite aceptar LOAD. |
| `SOLICITUD_INCOMPLETA` | Venció la espera de los bytes del tamaño, antes de aceptar LOAD. |
| `CONTENIDO_INCOMPLETO` | Venció la espera del programa después de aceptar LOAD. |
| `ERROR_UART` | Se abandonó la recepción por un error informado por UART. |

En un flujo exitoso, la FPGA responde `[LOAD][ACEPTADA]` a la solicitud y, después de recibir el contenido y completar la preparación, responde `[LOAD][COMPLETADA]`. Los nombres son símbolos de documentación, no cadenas de texto enviadas por UART. Ambos campos serán bytes binarios.

**Justificación:** La cabecera identifica la operación y el resultado con un formato breve. LOAD utiliza respuestas de longitud fija; la misma cabecera permite incorporar posteriormente los datos requeridos por otras operaciones.

**Consecuencias y alcance pendiente:** Se resuelven P01 y L13 de la checklist: cabecera común, campos, longitudes y resultados de LOAD. Los códigos de operación y los valores de resultado siguen pendientes en C02/C03. El formato y la longitud de los datos de Debug siguen pendientes en D05; no se asume que toda respuesta del sistema tenga dos bytes. No se cambia la política de errores, recuperación, conservación de imagen ni el instante de confirmación final.

**Requisitos afectados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-005`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la estructura de respuestas y los formatos básicos de LOAD pendientes en los acuerdos anteriores, sin cerrar su codificación numérica ni el protocolo completo.

### Acuerdo parcial de DEC-PROTO-001 — Formato de consulta de disponibilidad

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-001` y `DEC-PROTO-002` permanecen pendientes en sus aspectos restantes.

**Dominio:** Debug / Consulta de disponibilidad para LOAD.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La consulta iniciada por PC y su significado están aprobados. El usuario aprueba ahora su formato mínimo, usando la cabecera común de respuestas.

**Decisión:** La solicitud de disponibilidad no tendrá parámetros: ocupará exactamente un byte, el código de esa operación. El nombre simbólico `CONSULTAR_DISPONIBILIDAD` se usa para documentar el intercambio, sin fijar todavía su código numérico.

Cuando el receptor pueda interpretar la consulta, responderá exactamente dos bytes: `[CONSULTAR_DISPONIBILIDAD][resultado]`. No habrá datos adicionales; el segundo byte completará la respuesta.

| Resultado simbólico | Significado |
|---|---|
| `DISPONIBLE` | El receptor puede atender una nueva solicitud y el estado global es elegible para LOAD. |
| `NO_DISPONIBLE` | En ese momento el sistema no puede aceptar LOAD, por ejemplo durante ejecución continua. |

La consulta no modificará la imagen ni la ejecución. Una respuesta disponible no reservará el sistema ni aceptará anticipadamente una carga: la FPGA volverá a comprobar las condiciones al recibir LOAD. Se mantienen el significado común antes de primera carga, tras reset y después de recuperación, y la ausencia de relación entre disponibilidad e imagen ejecutable válida.

Durante recuperación se descartarán los bytes de consulta sin respuesta, conforme a la política aprobada. Durante el contenido de LOAD los bytes serán datos del programa y no comandos; durante preparación y envío de confirmación se mantiene el descarte aprobado. La PC seguirá respetando las esperas acordadas antes de consultar.

**Justificación:** Un byte de solicitud y dos de respuesta proporcionan la información necesaria para iniciar el flujo de carga sin agregar parámetros ni datos de estado generales.

**Consecuencias y alcance pendiente:** Se resuelve L14 de la checklist. Quedan pendientes los valores numéricos en C02/C03, el timeout de consulta y las ventanas de recuperación/repetición ya diferidas. No se agrega reserva, reporte de capacidades ni snapshot a la consulta.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-011`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve los campos y longitudes de solicitud y respuesta de disponibilidad pendientes en los acuerdos anteriores, sin cerrar códigos, tiempos ni los identificadores generales del protocolo.

### Acuerdo parcial de DEC-PROTO-003 — Inicio del timeout de contenido tras transmitir aceptación

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Transición entre aceptación de LOAD y recepción del programa.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La PC debe recibir la aceptación antes de enviar contenido. El usuario aprueba comenzar la espera de contenido cuando la FPGA haya terminado de transmitir esa autorización, para no consumir parte del timeout durante su envío.

**Decisión:** Una vez recibida y validada la solicitud, la FPGA acepta LOAD, inicia la carga con sus efectos ya aprobados y transmite `[LOAD][ACEPTADA]`. El timeout de inactividad del contenido comenzará al terminar físicamente la transmisión del segundo byte de esa respuesta, incluido su bit de Stop.

Introducir la respuesta en la FIFO TX no constituye fin de transmisión ni inicia todavía esa espera. La aceptación efectiva de LOAD y la invalidación de la imagen anterior siguen ocurriendo al aceptar la solicitud, sin diferirse hasta el fin de TX.

La PC esperará la respuesta completa antes de enviar el programa. Se utilizará el mismo tiempo `T` para esperar el primer byte y los siguientes; cada byte de contenido recibido correctamente reiniciará la espera mientras falten bytes. No se incorpora un timeout separado para el primer byte ni un límite a la duración total de la transferencia.

El valor de `T` deberá cubrir la reacción normal de PC después de recibir la aceptación y el tiempo de recepción del primer byte. Su duración numérica sigue pendiente junto con los parámetros UART y del transporte.

**Justificación:** La autorización debe salir por el enlace antes de contar el tiempo disponible para que la PC reaccione y comience a transmitir. Se conserva un criterio común de inactividad para la recepción.

**Consecuencias y alcance pendiente:** Se resuelve L15 de la checklist. Quedan pendientes el valor y conversión de `T`, las prioridades si coinciden byte/error/vencimiento y el contrato concreto que permita identificar el fin físico de la respuesta desde la capa UART. No se fijan puertos ni contadores nuevos. El envío ante TX lleno se completará en U02 y la espera de aceptación en PC en L18.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-009`, `REQ-UART-011`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la activación inicial del timeout de contenido pendiente en los acuerdos previos de recepción de LOAD y tiempo común, sin cerrar su duración ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-SYS-007 — Configuración física UART de referencia

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-007` permanece pendiente en sus aspectos restantes.

**Dominio:** Sistema / UART y temporización del protocolo.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba conservar la configuración física del TP2 como base, adaptándola al clock funcional aprobado para TP3. Estos parámetros permiten continuar el dimensionado y la selección de tiempos de LOAD.

**Decisión:** La UART del TP3 utilizará baud rate nominal de **19200 baud**, formato **8N1** (ocho bits de datos, sin paridad, un bit de Stop) y sobremuestreo **16**. Se utilizará el clock funcional común con objetivo de **50 MHz**, conforme a `DEC-ARCH-005`, adaptando la generación de ticks a esa frecuencia. Los ticks serán enables síncronos y no un dominio de clock adicional.

El formato mantiene un bit de Start y un bit de Stop por cada byte, además de los ocho bits de datos. A la velocidad nominal, la duración de una trama de byte es `10 / 19200` segundos, aproximadamente **0,520833 ms**; transmitir 1024 bytes sin pausas requiere aproximadamente **0,533333 s** de contenido, sin incluir respuestas ni preparación.

**Justificación:** Reutilizar la configuración conocida del TP2 proporciona un ritmo suficiente para el uso previsto del TP y una referencia concreta para los contratos temporales de recepción y transmisión.

**Consecuencias y alcance pendiente:** Se resuelve U01 de la checklist. Quedan pendientes buffers, contrato de consumo y señales de fin/actividad en U02, transporte de PC en U03, correcciones de diseño de bloques UART mencionadas por el usuario y selección concreta de los tiempos. Las duraciones calculadas son nominales; al concretar el generador se tendrá en cuenta el redondeo del divisor. No se afirma que exista ya una implementación TP3 ni medición de hardware.

**Requisitos afectados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-009`, `REQ-UART-010`, `REQ-TIM-002`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve baud rate, formato físico, sobremuestreo y frecuencia de referencia para UART pendientes en `DEC-SYS-007`, conservando el dominio común aprobado y sin cerrar el conjunto de servicios o la integración UART.

### Acuerdo parcial de DEC-SYS-007 — Buffers y contrato de consumo UART

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-SYS-007` permanece pendiente en sus aspectos restantes.

**Dominio:** Sistema / UART, Loader y transmisión de respuestas.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba conservar las FIFO del TP2 y un contrato de consumo suficiente para el envío seguido de LOAD, junto con los eventos UART que necesita el protocolo.

**Decisión:** Se adoptan las siguientes reglas:

1. **Buffers independientes:** FIFO RX de cuatro bytes y FIFO TX de cuatro bytes, como en la configuración de referencia del TP2.
2. **Consumo RX:** Durante recepción normal de LOAD, cada byte se retirará y procesará antes de que llegue completo el siguiente. El consumo se realizará con el clock funcional común, sin depender de esperar un tick de baud ni de ciclos efectivos de CPU. En recepción continua nominal hay aproximadamente 0,520833 ms, unos 26042 clocks funcionales de 50 MHz, entre bytes completos consecutivos.
3. **Reconstrucción de instrucciones:** Se acumularán los cuatro bytes de la instrucción en un registro fuera de la FIFO RX, se escribirá la word completa en IMEM con el ownership aprobado y se continuará con la siguiente. El presupuesto del punto anterior incluye esa escritura. No se acumula el programa entero en la FIFO.
4. **TX llena:** La capa de transmisión conservará el byte pendiente y esperará espacio antes de introducirlo en TX, sin perderlo ni bloquear el consumo o descarte de RX. Las vías RX/TX seguirán siendo independientes y la limpieza de recepción conservará TX para informar el fallo.
5. **Eventos observables:** UART informará el fin físico de cada byte transmitido, incluido Stop. La capa de respuestas identificará el segundo byte de aceptación de LOAD y activará la espera aprobada en L15. También se dispondrá de información de actividad RX y recepción en curso para cumplir el criterio de silencio de recuperación.

**Justificación:** Con el consumo de cada byte antes del siguiente, cuatro lugares de RX son suficientes para el flujo normal de LOAD. El registro de reconstrucción separa la instrucción en formación del almacenamiento temporal de bytes. Esperar espacio TX sin bloquear RX conserva el progreso de recepción y recuperación.

**Consecuencias y alcance pendiente:** Se resuelve U02 de la checklist como contrato de diseño, sin acreditar todavía su realización. Al diseñar las máquinas de estado se comprobará que cumplen el presupuesto, incluida escritura IMEM y espera TX. Quedan pendientes las correcciones de bloques del TP2 que mencionó el usuario, la realización del generador y la lista exacta de puertos/señales de actividad, recepción en curso y fin físico de TX. El `uart_core` del TP2 ya tiene fin de byte TX interno, pero no expone todavía todos estos eventos. Las respuestas y snapshots se transmitirán usando el espacio disponible; el tamaño de TX no exige almacenar el mensaje completo en esa FIFO.

**Requisitos afectados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-002`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve las profundidades de FIFO, el contrato de consumo y los eventos necesarios para el protocolo pendientes en `DEC-SYS-007`, conservando los acuerdos de carga seguida y recuperación sin cerrar la realización de UART.

### Acuerdo parcial de DEC-PROTO-003 — Envío preparado y supervisado desde PC

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Contrato del transporte de PC para LOAD.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba concretar el envío desde PC para evitar trabajo de preparación durante una carga y permitir detener el intento al detectar un fallo. No se selecciona interfaz gráfica, lenguaje ni biblioteca de transporte.

**Decisión:** Se utilizará el siguiente contrato:

1. **Preparación previa:** La PC tendrá el programa completo preparado como bytes y conocerá su tamaño antes de solicitar LOAD. No ensamblará ni leerá archivos durante la transferencia.
2. **Inicio y continuidad:** Después de recibir la aceptación completa, comenzará automáticamente a enviar exactamente el contenido anunciado, seguido y sin pausas intencionales. Las fragmentaciones internas del sistema operativo o adaptador no constituyen bloques nuevos del protocolo ni requieren confirmaciones.
3. **Supervisión durante envío:** La PC escuchará respuestas mientras transmite. Si recibe un error o vence su espera, detendrá nuevos envíos y cancelará lo pendiente en lo que permita el transporte.
4. **Recuperación coordinada:** Los bytes ya en tránsito podrán terminar de llegar mientras la FPGA los descarta. La PC respetará la ventana acordada antes de consultar disponibilidad y mantendrá el reintento completo a elección del usuario.

Las pausas normales del sistema operativo y del adaptador quedarán cubiertas por el margen de `T`. La espera del primer byte contemplará la reacción del transporte y su recepción UART, sin incluir preparación del programa ni interacción adicional del usuario.

**Justificación:** Tener el contenido preparado permite iniciar el envío al recibir la autorización y sostenerlo. Supervisar simultáneamente las respuestas permite reaccionar al fallo sin esperar a completar deliberadamente un intento abandonado.

**Consecuencias y alcance pendiente:** Se resuelve U03 de la checklist como contrato de uso del cliente propio del TP. Quedan pendientes los tiempos `T`, `R`, ventanas y esperas de PC en L16–L18, con margen para el transporte de laboratorio. No se garantiza cancelación instantánea de bytes ya en tránsito ni se exige robustez frente a latencias arbitrarias. No se fija una única llamada al sistema, un mecanismo de concurrencia ni una implementación de la aplicación.

**Requisitos afectados:** `REQ-UART-009`, `REQ-UART-010`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la preparación, continuidad, supervisión y cese del envío desde PC pendientes en los acuerdos de carga seguida y recuperación, sin cerrar su temporización ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Duración y prioridades del timeout de LOAD

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Temporización de recepción de LOAD.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Se completaron la configuración UART y los contratos de consumo y envío desde PC. El usuario aprueba ahora el valor de T y las prioridades de recepción, después de haber diferido la propuesta inicial de duración.

**Decisión:** El timeout común de inactividad de tamaño y contenido de LOAD será **T = 100 ms**. Con el clock funcional de 50 MHz corresponde a **5.000.000 de ciclos físicos de clock**, independientes de `cpu_cycle_fire` y del contador lógico de la sesión. Un contador que represente ese intervalo requiere al menos 23 bits; esta derivación no fija la FSM ni obliga a compartir un contador físico entre fases.

Se mantienen los puntos de activación aprobados: espera del tamaño después de reconocer el código LOAD y espera del contenido después de terminar físicamente el segundo byte de aceptación, incluido Stop. Cada byte válido aceptado reinicia la espera mientras falten bytes; recibir el último completa su fase. T no limita la duración total de la transferencia.

Si coinciden eventos en un mismo flanco funcional, se aplicará esta prioridad:

1. **Error UART:** abandonar la recepción y aplicar la recuperación acordada, sin aceptar un byte coincidente como válido para continuar la operación.
2. **Byte válido recibido:** consumirlo y reiniciar T si faltan bytes, o completar la fase si es el último. Un byte válido en el límite evita el timeout.
3. **Vencimiento sin error ni byte válido:** declarar solicitud o contenido incompleto según la fase, con los efectos de imagen y respuestas ya aprobados.

**Justificación:** La trama nominal tarda aproximadamente 0,520833 ms, y el programa está preparado antes de LOAD, con inicio automático y envío sin pausas intencionales. Los 100 ms son un margen de diseño para la reacción de PC y las pausas normales del transporte, manteniendo una detección de interrupción rápida para el uso del TP. No constituyen una medición de latencia de PC ni un valor determinado únicamente por baud rate.

**Consecuencias y alcance pendiente:** Se resuelve L16. La propuesta inicial de 100 ms había quedado diferida; este acuerdo la selecciona después de concretar U01–U03 y L15. Quedan pendientes R, las ventanas de recuperación/consulta y las esperas de PC en L17/L18. La realización de UART/protocolo deberá cumplir la cuenta y prioridades, sin introducir un nuevo dominio de clock.

**Requisitos afectados:** `REQ-UART-008`, `REQ-UART-009`, `REQ-UART-010`, `REQ-SW-004`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve el valor numérico, conversión de referencia y coincidencias pendientes en los acuerdos de timeout y tiempo común. Sustituye la postergación de T, sin fijar R ni cerrar `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Silencio de recuperación y ventana de consulta desde PC

**Estado del acuerdo:** Aprobado como base de diseño. `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Temporización de recuperación de LOAD.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba la duración de silencio de FPGA y la espera de PC antes de volver a consultar, después de detener/cancelar un intento fallido. Se mantiene el alcance del transporte de laboratorio y del cliente propio.

**Decisión:** El intervalo de recuperación será **R = 100 ms de silencio continuo**, equivalente a 5.000.000 de clocks funcionales de 50 MHz. R y T representan intervalos independientes aunque tengan el mismo valor. Toda actividad de recepción reiniciará R; al finalizar deberán estar la línea en reposo, RX vacía y ningún byte en curso, conforme al criterio aprobado.

Después de detener/cancelar el intento, la PC esperará una ventana W antes de consultar disponibilidad. Se dimensionará mediante la estimación conservadora del tiempo de transmitir la solicitud LOAD y el programa completos, más T y R, redondeada hacia arriba a múltiplos de 100 ms:

```text
trama_nominal_ms = 1000 * 10 / 19200
W_ms = 100 * ceil(((N + 6) * trama_nominal_ms + T_ms + R_ms) / 100)
```

N es el tamaño en bytes del programa del intento; los seis bytes corresponden a la solicitud LOAD. Se usa el programa completo para evitar depender de conocer cuántos bytes quedaron pendientes tras cancelar. Para N = 1024, la estimación antes de redondear es aproximadamente 736,458 ms y W = 800 ms; para N = 32, W = 300 ms.

Al terminar W, la PC consultará disponibilidad. Si no recibe respuesta, esperará de nuevo la misma ventana W antes de repetir la consulta. Solo una respuesta disponible permite continuar el flujo de una nueva LOAD, cuyo reenvío sigue a elección del usuario.

**Justificación:** R conserva un margen de silencio simple para el TP. La ventana W contempla bytes pendientes, el posible timeout de recepción todavía activo si se perdió una respuesta y la recuperación posterior, sin exigir medir la ocupación exacta del transporte desde PC.

**Consecuencias y alcance pendiente:** Se resuelve L17. La ventana es una estimación de diseño para el envío preparado y seguido del transporte de laboratorio, no una garantía ante pausas arbitrarias del emisor. Se mantienen la cancelación en lo que permita el transporte y el descarte RX. Quedan pendientes las esperas de respuesta en L18 y la realización de los contratos UART, sin introducir un comando de recuperación adicional ni un estado global nuevo.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-010`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve R y las ventanas de consulta de recuperación pendientes en los acuerdos anteriores, conservando T, recuperación automática y reintento manual, sin cerrar todas las esperas de PC ni `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Esperas de respuesta de PC para LOAD

**Estado del acuerdo:** Aprobado como base de diseño. L18 y `DEC-PROTO-003` permanecen pendientes de completar el presupuesto máximo de preparación de sesión.

**Dominio:** Debug / Esperas del cliente durante carga.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario acuerda usar esperas breves para disponibilidad/aceptación y calcular la espera final según el tamaño del programa. La duración máxima de preparación todavía no está fijada y se conserva como dependencia explícita.

**Decisión:** La PC utilizará un plazo de **200 ms** para obtener respuesta a la consulta de disponibilidad y a la solicitud inicial LOAD. Esas respuestas son cortas y el plazo proporciona margen al transporte de laboratorio.

La espera de confirmación final se contará desde que la PC comienza a enviar el contenido. Se calculará para cada intento según N, el tamaño de programa en bytes:

```text
envio_nominal_ms = 1000 * N * 10 / 19200
plazo_final_ms = envio_nominal_ms + preparacion_max_ms + 200
```

El tiempo de envío corresponde al programa, después de la aceptación; los seis bytes de solicitud pertenecen al intercambio previo. La espera no será un valor fijo independiente de N. A baud nominal, 32 bytes requieren aproximadamente 16,667 ms, 256 bytes 133,333 ms y 1024 bytes 533,333 ms de contenido.

Si vence una espera o se recibe fallo, la PC aplicará el cese/cancelación y recuperación aprobados, con reintento solo solicitado por el usuario. La ausencia de confirmación final no certifica que la imagen haya quedado inválida: una imagen ya comprometida no se revierte por perder su respuesta.

**Justificación:** Los intercambios cortos necesitan un margen para comunicación; una carga completa necesita además el tiempo proporcional al tamaño enviado y la preparación previa al commit. Separar esos términos evita un timeout prematuro en programas mayores.

**Consecuencias y alcance pendiente:** Se aprueban los 200 ms de respuestas cortas y de margen final, el cálculo proporcional a N y el punto inicial de la espera final. Queda por fijar `preparacion_max_ms` mediante una cota o presupuesto de Session Preparation y el perfil compartido. L18 no se marca completo hasta resolver ese dato; L19 tampoco se adelanta. No se modifica el instante de éxito de LOAD ni se introduce un límite de ejecución de RUN.

**Requisitos afectados:** `REQ-UART-007`, `REQ-UART-009`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve parcialmente las esperas de PC pendientes en los acuerdos anteriores, sin inventar la cota de preparación ni cerrar L18 o `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-003 — Presupuesto máximo de preparación de sesión

**Estado del acuerdo:** Aprobado como base de diseño. Se completa L18; `DEC-PROTO-003` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Preparación posterior a LOAD y espera final de PC.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Después de recibir el programa, la FPGA prepara la sesión antes de confirmar el éxito. El usuario aprueba un presupuesto máximo de 1 ms para los perfiles actuales del TP, completando la dependencia de la espera final.

**Decisión:** Para los perfiles `REFERENCE` y `ALT_1000`, la preparación posterior a LOAD tendrá un **presupuesto máximo de 1 ms**, equivalente a **50.000 clocks funcionales de 50 MHz**. Se cuenta desde la entrada a `PREPARING_READY` hasta el flanco de commit que, con `prepare_done`, publica el tamaño y establece READY. El envío de la respuesta final se cubre con el margen de comunicación ya acordado.

La preparación debe dejar PC, RF, pipeline y contador en sus valores iniciales, DMEM en cero lógico y el conjunto utilizado vacío. Se confirma apenas termina efectivamente; no se espera deliberadamente 1 ms ni se sustituye `prepare_done` por un temporizador. Este presupuesto es un requisito de diseño, no una duración medida ni una nueva causa de fault o timeout en la FPGA.

La espera final de PC, desde el inicio del envío del contenido, queda para estos perfiles:

```text
preparacion_max_ms = 1
plazo_final_ms = 1000 * N * 10 / 19200 + 1 + 200
```

Para N = 32, 256 y 1024 bytes resulta aproximadamente 217,667 ms, 334,333 ms y 734,333 ms, respectivamente. Los plazos de disponibilidad y aceptación siguen siendo 200 ms. Se conservan recuperación y reintento manual ante vencimiento, sin inferir rollback por ausencia de respuesta final.

**Justificación:** A 50 MHz, recorrer las 2048 posiciones de DMEM de referencia a una posición por clock requiere 40,96 µs. Los 50.000 clocks proporcionan margen para el resto de la preparación. Este cálculo sustenta el presupuesto sin fijar todavía el orden de operaciones ni los puertos de mantenimiento.

**Consecuencias y alcance pendiente:** Se resuelve L18. Al diseñar Session Preparation se deberá verificar que la secuencia completa cumple el presupuesto, incluido el commit. Las capacidades arquitectónicamente admitidas no quedan restringidas por esta cota: un perfil futuro deberá revisar explícitamente su presupuesto y la configuración compartida con PC antes de utilizarse. Siguen pendientes L19, la realización de los bloques, las demás operaciones y sus esperas. No se inicia implementación.

**Requisitos afectados:** `REQ-EXEC-017`, `REQ-UART-009`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa `preparacion_max_ms` y el cierre de L18 pendientes en el acuerdo de esperas de PC, sin cambiar el instante de éxito de LOAD ni cerrar `DEC-PROTO-003`.

### Acuerdo parcial de DEC-PROTO-001 — Secuencia completa y cierre del intercambio LOAD

**Estado del acuerdo:** Aprobado como base de diseño. Se completa L19; `DEC-PROTO-001` permanece pendiente para las demás operaciones, códigos y reglas comunes.

**Dominio:** Debug / Intercambio completo de carga.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba reunir el recorrido completo y sus errores básicos antes de pasar a RUN. Se consolidan los formatos, tiempos y efectos ya acordados, y se precisa cuándo puede comenzar la siguiente solicitud.

**Decisión:** La PC prepara los N bytes del programa antes de solicitar LOAD. El intercambio exitoso sigue esta secuencia; los nombres de códigos/resultados son simbólicos hasta C02/C03:

| Paso | Mensaje o acción | Tiempo y efecto |
|---|---|---|
| 1 | PC → FPGA: `[CONSULTAR_DISPONIBILIDAD]` | Solicitud de un byte; PC espera hasta 200 ms. |
| 2 | FPGA → PC: `[CONSULTAR_DISPONIBILIDAD][DISPONIBLE]` | Dos bytes; informa elegibilidad actual sin reservar la carga ni modificar CPU/imagen. |
| 3 | PC → FPGA: `[LOAD][N: cinco bytes unsigned little-endian]` | Seis bytes; FPGA recibe el tamaño con T = 100 ms de inactividad desde el código y valida tamaño completo y elegibilidad. PC espera hasta 200 ms por la respuesta inicial. |
| 4 | FPGA → PC: `[LOAD][ACEPTADA]` | Dos bytes; al aceptar invalida la imagen anterior. El T de contenido empieza al finalizar físicamente el segundo byte, incluido Stop. |
| 5 | PC → FPGA: N bytes de contenido | Envío seguido, instrucciones little-endian y direcciones crecientes, sin confirmaciones intermedias. T se reinicia por cada byte correcto mientras falten bytes. |
| 6 | FPGA: preparación y commit | Recepción completa lleva a PREPARING_READY; preparación y commit en READY dentro del presupuesto de 1 ms para REFERENCE/ALT_1000. Se confirma la imagen y la sesión inicial sin ejecutar CPU. |
| 7 | FPGA → PC: `[LOAD][COMPLETADA]` | Dos bytes; PC espera hasta `1000 * N * 10 / 19200 + 201` ms desde el inicio del contenido en los perfiles actuales. |

La PC espera los dos bytes completos de COMPLETADA antes de enviar la siguiente operación. La FPGA mantiene el descarte de RX durante preparación y envío de esa confirmación; termina el intercambio de LOAD y vuelve a interpretar solicitudes cuando finaliza físicamente su segundo byte, incluido Stop. El commit en READY puede preceder al fin de transmisión: READY por sí solo no abre el receptor a una solicitud nueva durante la confirmación. Un intercambio exitoso no agrega una espera de silencio R.

Para N = 32, la solicitud de carga es `[LOAD][20 00 00 00 00]`, seguida de 32 bytes solo después de ACEPTADA; la espera final es aproximadamente 217,667 ms. Para N = 1024, el tamaño es `00 04 00 00 00` y la espera final aproximadamente 734,333 ms.

#### Errores básicos del recorrido LOAD

| Caso | Respuesta de FPGA | Imagen / sesión | Continuación |
|---|---|---|---|
| Consulta interpretada en estado no elegible | `[CONSULTAR_DISPONIBILIDAD][NO_DISPONIBLE]` | Conservadas. | PC no solicita LOAD mientras no obtenga DISPONIBLE. |
| Solicitud completa con tamaño inválido | `[LOAD][TAMAÑO_INVALIDO]` | Conservadas; no se acepta LOAD. | PC no envía contenido; no requiere recuperación por silencio. |
| Solicitud LOAD completa en estado no elegible | `[LOAD][NO_DISPONIBLE]` | Conservadas; la ejecución activa continúa. | PC no envía contenido; el rechazo completo no requiere recuperación por silencio. |
| Tamaño incompleto al vencer T | `[LOAD][SOLICITUD_INCOMPLETA]` | Conservadas; LOAD no fue aceptada. | Descarte y recuperación por silencio. |
| Contenido incompleto al vencer T | `[LOAD][CONTENIDO_INCOMPLETO]` | Sin imagen válida después de la aceptación. | Descarte y recuperación por silencio. |
| Error UART al recibir tamaño o contenido | `[LOAD][ERROR_UART]` | Conservadas antes de aceptar; sin imagen válida después. | Abandonar recepción y recuperar por silencio; error tiene prioridad sobre byte y timeout. |
| Vence la espera de PC o se pierde una respuesta | No se presupone una respuesta recibida. | No inferir rollback: perder COMPLETADA no revierte una imagen comprometida. | PC detiene/cancela el intento y aplica la espera de recuperación antes de consultar. |

En recuperación, la FPGA descarta RX sin borrar TX, incluidas consultas/reset UART, hasta R = 100 ms de silencio continuo, línea en reposo, ningún byte en curso y RX vacía. PC detiene/cancela ante fallo o vencimiento, espera `W_ms = 100 * ceil(((N + 6) * 1000 * 10 / 19200 + 100 + 100) / 100)` y consulta disponibilidad; si no obtiene respuesta, espera W nuevamente antes de repetir la consulta. El usuario solicita una nueva LOAD completa si desea reintentar. Para N = 1024, W = 800 ms. Se conserva el alcance del cliente propio y transporte de laboratorio.

**Consecuencias y alcance pendiente:** P01, L13–L19 y U01–U03 quedan completos, permitiendo continuar con R01. La asignación numérica de códigos/resultados permanece deliberadamente diferida. Se documentó el comportamiento; siguen pendientes la realización del receptor/UART/preparación, las demás operaciones y la revisión final del protocolo antes de D0.

**Requisitos afectados:** `REQ-UART-007` a `REQ-UART-011`, `REQ-EXEC-017`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos previos de LOAD y precisa el final físico de su intercambio antes de la siguiente solicitud, sin cambiar la política de imagen, los tiempos ni el reintento manual.

### Acuerdo parcial de DEC-PROTO-001 — Solicitud y aceptación de RUN

**Estado del acuerdo:** Aprobado como base de diseño. Se completa R01; `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Inicio o continuación de ejecución continua.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** LOAD deja una imagen confirmada y una sesión lista, sin ejecución automática. El usuario aprueba cómo solicitar RUN y qué acredita su respuesta inicial, utilizando la semántica arquitectónica existente.

**Decisión:** Una solicitud RUN ocupa exactamente un byte `[RUN]`, sin parámetros. Cuando el receptor interpreta esa solicitud como comando, su respuesta inicial ocupa exactamente dos bytes:

| Condición | Respuesta inicial | Efecto |
|---|---|---|
| Imagen válida y estado elegible | `[RUN][ACEPTADA]` | Toma la orden y realiza la ejecución continua correspondiente al contexto actual. |
| Sin imagen válida | `[RUN][SIN_IMAGEN]` | Rechazo; no inicia una ejecución. |
| Imagen válida y estado incompatible | `[RUN][NO_DISPONIBLE]` | Rechazo; conserva la sesión y no altera la ejecución vigente. |

Los nombres son simbólicos: la asignación numérica de códigos y resultados permanece pendiente en C02/C03. Se mantienen las reglas del receptor durante contenido, preparación/confirmación LOAD y recuperación: esos bytes no se interpretan como solicitudes RUN.

Los estados arquitectónicamente elegibles son `READY`, `STEPPING`, `HALT_DRAIN_STEP`, `FAULT_DRAIN_STEP`, `FINISHED` y `FAULT`, con imagen válida:

- Desde READY comienza la sesión preparada; el flanco de aceptación ya ejecuta su primer ciclo efectivo.
- Desde STEPPING continúa la sesión existente desde el punto alcanzado por los STEP, sin volver a inicializarla.
- Desde un drain STEP autoriza el ciclo actual de drenado y completa automáticamente el trabajo anterior que todavía quede, conforme a la arquitectura; no admite nuevas instrucciones.
- Desde FINISHED o FAULT inicia PREPARING_RUN con la misma imagen. Tras la preparación efectiva, ejecuta el primer ciclo y continúa automáticamente en una sesión nueva con estado inicial.

ACEPTADA certifica que la orden fue tomada y se realizará su ejecución continua, incluida la preparación previa cuando corresponda. No certifica que la preparación ya terminó, que el estado actual sea RUNNING ni que el programa haya finalizado. La aceptación no modifica la autorización de ciclos existente ni introduce una espera de transmisión UART antes de avanzar la CPU.

**Justificación:** Una orden sin parámetros alcanza para iniciar o continuar el programa confirmado. Separar aceptación, ausencia de imagen y estado incompatible permite a PC entender la respuesta inicial sin confundirla con el resultado arquitectónico de la ejecución.

**Consecuencias y alcance pendiente:** Se completa R01 y se continúa con R02. Quedan pendientes la notificación de terminación normal/fault y su contenido Debug, la comunicación durante ejecución, los plazos de PC y los valores numéricos. No se agrega una duración máxima de programa ni una captura durante RUN.

**Requisitos afectados:** `REQ-UART-003`, `REQ-EXEC-006`, `REQ-EXEC-017`, `REQ-DBG-001`, `REQ-DBG-003`, `REQ-SW-005`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa el formato y la respuesta inicial de RUN pendientes en el protocolo, conservando la elegibilidad y el control de ejecución aprobados.

### Acuerdo parcial de DEC-PROTO-001 — Resultado automático de RUN con estado de Debug

**Estado del acuerdo:** Aprobado como base de diseño. Se completa R02; `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Terminación de ejecución continua y observación final.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Después de aceptar RUN, la FPGA ejecuta continuamente. Confirmar halt o fault puede dejar instrucciones anteriores pendientes; la consigna requiere enviar el estado de Debug al finalizar la ejecución continua. El usuario aprueba informar automáticamente el resultado acompañado por ese estado.

**Decisión:** Un RUN aceptado que alcanza su estado terminal genera una respuesta final automática, sin exigir una consulta posterior de PC:

| Terminación | Condición arquitectónica | Respuesta final |
|---|---|---|
| Normal por halt | FINISHED, con pipeline vacío después del drenado necesario | `[RUN][FINALIZADA][estado de Debug]` |
| Excepcional por fault | FAULT, con pipeline vacío después del drenado necesario | `[RUN][FAULT][estado de Debug]` |

La cabecera mantiene el código de la solicitud RUN y un byte de resultado. Los nombres FINALIZADA y FAULT son simbólicos hasta C03; la representación binaria del estado de Debug, su longitud y delimitación se completarán en D05. La respuesta final no se reduce a dos bytes: incluye el snapshot acordado.

El snapshot corresponde a un único instante lógico posterior al drenado y al último commit de las instrucciones anteriores. Incluye RF, los cuatro latches, DMEM utilizada, PC global, contador de ciclos, estado terminal y demás información mínima aprobada; en FAULT incluye causa y PC de la instrucción causante. Mantiene la coherencia durante toda la serialización, conforme al contrato de Debug. No se anuncia FINALIZADA o FAULT por la mera confirmación inicial de halt/fault mientras quedan instrucciones anteriores.

El intercambio normal observado por PC es solicitud RUN → respuesta inicial ACEPTADA completa → respuesta final con Debug. Si el programa termina antes de transmitirse toda la aceptación, se conserva ese orden y se envía primero la aceptación; las respuestas no intercalan sus bytes. La realización de retención y serialización queda pendiente del diseño de bloques y D06.

Un RUN rechazado solo produce su respuesta inicial de rechazo. Un programa que continúa ejecutándose sin alcanzar un terminal no genera una respuesta final por el simple transcurso del tiempo. La interrupción por reset conserva sus efectos arquitectónicos y su intercambio se resolverá en Z02; no se presenta como finalización normal del programa.

**Justificación:** La entrega automática satisface la observación final requerida y permite a PC recibir aceptación, resultado y estado sin consultar periódicamente la terminación. Esperar el drenado asegura que el resultado incluye todos los efectos arquitectónicos anteriores.

**Consecuencias y alcance pendiente:** Se completa R02 y se continúa con R03. Se resuelve para RUN la entrega automática que figuraba abierta en D02; permanecen abiertas la observación de STEP y las consultas adicionales. Quedan pendientes códigos numéricos, campos/layout/longitud del snapshot, realización de captura/envío, solicitudes admitidas durante ejecución/envío, interacción con reset y plazos de PC. No se inicia implementación.

**Requisitos afectados:** `REQ-EXEC-005`, `REQ-EXEC-007`, `REQ-EXEC-018`, `REQ-UART-003`, `REQ-UART-005`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-005`, `REQ-SW-009`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa la notificación final de RUN y su entrega de Debug pendientes en los acuerdos anteriores, sin fijar todavía el layout ni cambiar halt, fault o drenado.

### Acuerdo parcial de DEC-PROTO-001 — Comunicación y espera de PC durante RUN

**Estado del acuerdo:** Aprobado como base de diseño. Se completa R03; `DEC-PROTO-001` y `DEC-PROTO-003` permanecen pendientes en sus aspectos restantes.

**Dominio:** Debug / Solicitudes durante ejecución continua y temporización de PC.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Después de ACEPTADA, un RUN puede continuar durante un tiempo indeterminado. El usuario aprueba las solicitudes que se atienden durante ejecución y drenado automático, y distingue el plazo de aceptación de la duración del programa.

**Decisión:** Mientras el sistema se encuentre en RUNNING, HALT_DRAIN_AUTO o FAULT_DRAIN_AUTO y el receptor interprete solicitudes, se aplica esta tabla:

| Solicitud | Resultado | Efecto |
|---|---|---|
| RESET | Aceptar el reset global ya acordado; formato/confirmación pendientes en Z02 | Abandonar la ejecución y aplicar sus efectos arquitectónicos. |
| CONSULTAR_DISPONIBILIDAD | `[CONSULTAR_DISPONIBILIDAD][NO_DISPONIBLE]` | Informar que LOAD no es elegible, sin modificar ejecución ni imagen. |
| LOAD | `[LOAD][NO_DISPONIBLE]` después de recibir su solicitud completa | No aceptar la carga ni recibir contenido de programa; conservar ejecución e imagen. |
| RUN | `[RUN][NO_DISPONIBLE]` | No iniciar otra ejecución; conservar la actual. |
| STEP | `[STEP][NO_DISPONIBLE]` | No insertar un paso ni alterar el avance continuo actual. |

Una solicitud LOAD conserva su formato de seis bytes y las reglas de solicitud incompleta/error UART ya aprobadas. La tabla no cambia el tratamiento de contenido LOAD o recuperación, donde los bytes no se interpretan como comandos, ni prescribe los campos futuros de STEP/RESET. Las solicitudes incompatibles no suprimen ciclos automáticos de CPU.

La PC dispone de **200 ms para recibir la respuesta inicial completa de RUN**, con origen al enviar la solicitud, usando el mismo margen de comunicación de las respuestas cortas. Esa respuesta puede ser ACEPTADA, SIN_IMAGEN o NO_DISPONIBLE, según R01.

Después de recibir ACEPTADA, la PC espera el resultado final con Debug **sin un timeout de duración del programa**. Si el programa continúa sin alcanzar halt/fault terminal, la ausencia de resultado final no se interpreta por el paso del tiempo como error de recepción ni como finalización. El usuario puede solicitar RESET para abandonar una ejecución que no termina; no se ordena reset automáticamente por su duración.

**Justificación:** Se mantienen disponibles el mecanismo mínimo de recuperación y la consulta informativa, mientras se rechazan órdenes incompatibles sin detener la CPU. Una respuesta inicial corta admite un plazo de comunicación; la duración de un programa depende de su ejecución y puede ser ilimitada.

**Consecuencias y alcance pendiente:** Se completa R03 y se continúa con S01. RUN queda definido en R01–R03 al nivel de intercambio acordado. Siguen pendientes los valores numéricos, el layout de Debug, la realización de bloques y las reglas mientras se serializa el snapshot en D06, además de orden/arbitraje de respuestas y reset en C04/Z02. El vencimiento de la espera inicial o las fallas de enlace se completarán en C06, sin asumir que perder una aceptación pruebe que RUN no se ejecutó. Esta decisión fija la espera inicial y la ausencia de límite de programa también para `DEC-PROTO-003`.

**Requisitos afectados:** `REQ-UART-003`, `REQ-UART-006`, `REQ-UART-007`, `REQ-EXEC-006`, `REQ-EXEC-012`, `REQ-EXEC-015`, `REQ-DBG-001`, `REQ-SW-005`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa la comunicación durante RUN y su plazo de respuesta inicial pendientes en los acuerdos de RUN, sin cerrar la transmisión de Debug ni el intercambio de reset.

### Acuerdo parcial de DEC-PROTO-001 — Solicitud STEP y respuesta con Debug de cada ciclo

**Estado del acuerdo:** Aprobado como base de diseño. Se completan S01 y S02; `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Avance de un ciclo y observación posterior.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario solicita aclarar dónde se transmite el Debug de cada paso y aprueba incluirlo en la misma respuesta STEP. Se reúnen solicitud, resultado del avance y observación, sin diferir la entrega de Debug a otra operación.

**Decisión:** STEP se solicita con exactamente un byte `[STEP]`, sin parámetros. Para un paso realizado, la FPGA responde una única vez, después de su ciclo efectivo:

```text
PC → FPGA: [STEP]
FPGA → PC: [STEP][COMPLETADO][estado de Debug]
```

No se envía una aceptación previa separada. La FPGA realiza un único ciclo, captura el estado posterior y transmite su snapshot junto con el resultado. COMPLETADO confirma que ocurrió el ciclo solicitado; no afirma que terminó el programa ni que se completó una instrucción. Los casos de halt/fault, drenado pendiente y terminal se completarán en S03.

La cabecera tiene código STEP y resultado de un byte cada uno. COMPLETADO es un nombre simbólico hasta C03. El estado de Debug contiene RF, PC global, contador de ciclos, estado global e imagen válida, los cuatro latches, DMEM utilizada y los metadatos de fault cuando sean vigentes, conforme al contenido mínimo aprobado. Todos sus campos corresponden al mismo instante posterior al ciclo, incluidos sus commits, avance o stall y cambios de estado. Layout, orden de campos/bytes, longitud y delimitación siguen pendientes en D05; realización de captura y serialización en D06.

Si no hay imagen válida, se rechaza con `[STEP][SIN_IMAGEN]`; con imagen válida en estado incompatible, se rechaza con `[STEP][NO_DISPONIBLE]`. Son respuestas de dos bytes sin snapshot, sin realizar el ciclo. Se mantienen las reglas del receptor que impiden interpretar bytes de contenido LOAD o recuperación como comandos.

La elegibilidad arquitectónica se conserva: READY, STEPPING, HALT_DRAIN_STEP, FAULT_DRAIN_STEP, FINISHED y FAULT con imagen válida. Desde terminales se prepara una sesión nueva con la misma imagen y luego se ejecuta el único ciclo solicitado; se responde con su estado posterior, no con el estado de preparación. Desde READY/STEPPING el ciclo se realiza al aceptar la orden; durante drain STEP avanza un solo ciclo de trabajo anterior. Un stall consume el paso y no autoriza un ciclo adicional.

La PC obtiene el paso y su Debug en una misma respuesta, sin una consulta adicional. La CPU vuelve al contexto de espera correspondiente; UART y Debug conservan su actividad funcional para transmitir el snapshot sin contar ciclos de CPU por esa transmisión.

**Justificación:** La observación automática de cada paso satisface la consigna y muestra exactamente el efecto del ciclo pedido. Una respuesta posterior al avance reúne resultado y observación sin un intercambio de aceptación adicional.

**Consecuencias y alcance pendiente:** Se completan S01/S02 y se continúa con S03. RUN y STEP tienen entrega automática de Debug aprobada; D02 conserva únicamente las consultas y momentos adicionales de captura por decidir. Siguen pendientes los resultados de pasos que confirman halt/fault, layout/longitud del snapshot, puertos/secuencia de realización, solicitudes durante envío y plazos/fallas de comunicación en C06. No se programa implementación.

**Requisitos afectados:** `REQ-UART-004`, `REQ-UART-005`, `REQ-EXEC-009`, `REQ-EXEC-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-006`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa solicitud y respuesta STEP con su Debug automático, conservando el único ciclo por paso y dejando explícitamente S03 y el layout pendientes.

### Acuerdo parcial de DEC-PROTO-001 — Halt, fault y drenado en respuestas STEP

**Estado del acuerdo:** Aprobado como base de diseño. Se completa S03; `DEC-PROTO-001` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Resultado arquitectónico de cada paso y drenado.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** Un STEP puede confirmar halt/fault y dejar instrucciones anteriores pendientes. El usuario aprueba representar esa situación mediante el estado global incluido en Debug, conservando el formato de la respuesta de cada ciclo.

**Decisión:** Todo STEP realizado, incluidos los ciclos que confirman halt/fault o completan drenado, conserva la única respuesta:

```text
[STEP][COMPLETADO][estado de Debug]
```

COMPLETADO acredita que ocurrió el ciclo solicitado. La situación de la ejecución se interpreta a partir del `global_state` del snapshot posterior al ciclo:

| Estado observado | Significado |
|---|---|
| STEPPING | La sesión espera el siguiente comando, sin frontera terminal confirmada. |
| HALT_DRAIN_STEP | Halt confirmado; quedan instrucciones anteriores por completar. |
| FINISHED | Terminación normal con pipeline vacío. |
| FAULT_DRAIN_STEP | Fault confirmado; quedan instrucciones anteriores por completar. |
| FAULT | Terminación por fault con pipeline vacío. |

FAULT_DRAIN_STEP y FAULT incluyen causa y PC de la instrucción causante como metadatos vigentes. La representación externa de estados y metadatos sigue pendiente en D05/C03, sin agregar otro resultado STEP para distinguir estas situaciones.

Durante drenado STEP, cada nuevo STEP realiza un único ciclo del trabajo anterior y devuelve su Debug posterior. Al completar la última instrucción anterior, ese mismo snapshot ya muestra FINISHED o FAULT; no se solicita un ciclo vacío adicional ni se genera una segunda respuesta terminal. Se mantienen HOLD entre pasos, el conteo de ciclos efectivos y la posibilidad arquitectónica de pasar a drenado automático con RUN.

Desde FINISHED/FAULT, un STEP posterior sigue iniciando una sesión nueva sobre la imagen confirmada, conforme a S01 y la arquitectura; no se reanuda la sesión terminal. Los rechazos conservan SIN_IMAGEN/NO_DISPONIBLE y no se presentan como ciclos realizados.

**Justificación:** Separar el resultado del comando (ciclo realizado) del estado de ejecución en Debug permite conservar un único formato STEP sin ocultar halt, fault ni trabajo pendiente. La observación refleja los efectos anteriores que efectivamente se comprometieron en ese ciclo.

**Consecuencias y alcance pendiente:** Se completa S03 y se continúa con Z02. S01–S03 quedan definidos al nivel de intercambio acordado. Siguen pendientes códigos numéricos, layout/longitud del snapshot, realización de captura/envío, solicitudes durante transmisión y esperas/fallas de PC. No se modifica la FSM global ni se inicia implementación.

**Requisitos afectados:** `REQ-EXEC-005`, `REQ-EXEC-009`, `REQ-EXEC-010`, `REQ-EXEC-018`, `REQ-UART-004`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-006`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa halt/fault y drenado de STEP pendientes en el acuerdo de STEP con Debug, conservando COMPLETADO y la semántica de un ciclo por paso.

### Acuerdo parcial de DEC-PROTO-002 — Intercambio RESET con aceptación antes del reset global

**Estado del acuerdo:** Aprobado como base de diseño. Se completa Z02; `DEC-PROTO-002` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Reset desde PC, confirmación y retorno al enlace.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El reset global también reinicia UART y sus buffers. El usuario aprueba transmitir primero la respuesta para evitar que el propio reset la borre, y usar después la consulta de disponibilidad para retomar el protocolo.

**Decisión:** RESET se solicita con exactamente un byte `[RESET]`, sin parámetros. Cuando se interpreta como comando válido, la FPGA responde exactamente dos bytes `[RESET][ACEPTADA]`, sin datos adicionales. Los valores numéricos permanecen pendientes en C02/C03.

La secuencia es:

1. PC envía RESET.
2. FPGA transmite la aceptación completa.
3. Al finalizar físicamente el segundo byte, incluido su Stop, genera la solicitud de reset global; encolar los bytes o retirarlos de FIFO no acredita ese final.
4. El reset aplica los mismos efectos arquitectónicos que el botón físico: sistema detenido en NO_IMAGE, sin imagen válida ni sesión anterior activa, con estado inicial de CPU y UART reiniciada según sus contratos.
5. PC abandona la espera del resultado de la ejecución anterior y consulta disponibilidad. Solo al recibir DISPONIBLE continúa con una nueva LOAD y su secuencia normal.

ACEPTADA confirma que se tomó la orden y precede a la aplicación efectiva del reset. La consulta posterior confirma que el receptor está disponible para LOAD; no agrega un mensaje espontáneo de arranque ni una segunda confirmación RESET. La ausencia de imagen tras este intercambio se deriva de los efectos del reset, no de un significado nuevo para DISPONIBLE.

Se distingue el reconocimiento de la orden UART de la generación de la solicitud global de reset: esta última se difiere hasta el final físico de la aceptación. Una vez generada, se conserva el acondicionamiento temporal y la prioridad global aprobados. No se agrega una pausa anticipada de la CPU ni un estado global nuevo para esperar la UART; la realización de este orden corresponde al diseño de protocolo/plataforma.

El botón físico aplica el reset directamente, sin esperar transmisión ni enviar una aceptación UART. Al retomar la comunicación después de un reset físico, PC abandona el intercambio anterior y vuelve a consultar disponibilidad. Este contrato no exige una notificación espontánea ni fija un mecanismo de detección automática del botón desde PC.

Se conservan las exclusiones de comandos durante contenido LOAD, preparación/confirmación de carga y recuperación por silencio. Reset y solicitudes mientras un snapshot está transmitiéndose se completarán en D06, junto con el arbitraje y las reglas de serialización; este acuerdo no presupone intercalar la aceptación de reset dentro de otro mensaje.

**Justificación:** Terminar la respuesta antes de reiniciar UART evita perder la aceptación o truncar su trama. La consulta posterior utiliza el mismo mecanismo de disponibilidad ya acordado para primera carga y recuperación, manteniendo un intercambio sencillo para el TP.

**Consecuencias y alcance pendiente:** Se completa Z02 y se continúa con D02. Formato, orden de confirmación/reset, abandono del intercambio previo y retorno a consulta quedan definidos. Siguen pendientes los tiempos y fallas de PC en C06, códigos numéricos, realización de generación/reset y fin físico TX, y la interacción durante snapshot en D06/C04. El efecto del reset y los estados de la FSM global permanecen sin cambios. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-006`, `REQ-UART-007`, `REQ-EXEC-015`, `REQ-DBG-001`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa el intercambio pendiente del reset global desde PC y su diferencia temporal con el botón, conservando los efectos arquitectónicos, el servicio de disponibilidad y las exclusiones LOAD/recuperación.

### Acuerdo parcial de DEC-PROTO-002 — Debug automático sin consultas adicionales

**Estado del acuerdo:** Aprobado como base de diseño. Se completa D02; `DEC-PROTO-002` permanece pendiente en sus aspectos restantes.

**Dominio:** Debug / Servicios de observación y momentos de captura.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** RUN ya entrega Debug al terminar y STEP después de cada ciclo. El usuario confirma que PC puede conservar el snapshot recibido y que, entre pasos sin otra operación de sesión, el estado retenido sería el mismo; no considera necesaria una retransmisión mediante otra consulta.

**Decisión:** El protocolo del TP obtiene Debug exclusivamente en los intercambios automáticos aprobados:

- Después de cada STEP realizado, en `[STEP][COMPLETADO][estado de Debug]`, incluidos confirmación de halt/fault y ciclos de drenado.
- Al finalizar RUN, después del drenado necesario, en `[RUN][FINALIZADA][estado de Debug]` o `[RUN][FAULT][estado de Debug]`.

No se agrega READ_STATE ni otra solicitud explícita de snapshot. No se ofrecen capturas mientras RUNNING o un drain AUTO continúan ejecutándose, ni capturas adicionales en READY, NO_IMAGE, carga, preparación o reset. Los estados del snapshot STEP son los posteriores a su ciclo efectivo; los de RUN son FINISHED/FAULT según R02. Se conserva la observación de fault pendiente/terminal en los pasos ya definidos.

La PC puede guardar y volver a mostrar el snapshot recibido. Mientras la sesión espera entre pasos, sin un avance ni una nueva operación de sesión, permanecen retenidos PC, RF, pipeline, DMEM y contador; UART/Debug pueden transmitir sin modificar ese estado arquitectónico. No se exige mantener un historial ni se selecciona aquí una implementación del software.

CONSULTAR_DISPONIBILIDAD conserva su función de informar elegibilidad de LOAD, sin contenido Debug ni captura de snapshot. Un reset o una nueva carga cambian el contexto; un snapshot conservado pertenece a su sesión original y no se interpreta como estado actual de otra sesión.

**Justificación:** Los snapshots automáticos satisfacen los recorridos requeridos por la consigna. Repetir el estado retenido entre pasos no aporta una observación nueva, y conservar la respuesta en PC permite reutilizarla sin otro intercambio UART.

**Consecuencias y alcance pendiente:** Se completa D02 y se continúa con D03. La lista final de comandos no incluirá una consulta Debug adicional. Siguen pendientes campos externos de latches, criterio de memoria utilizada, layout/longitud y realización de captura/envío en D03–D06, códigos/reglas comunes y demás decisiones de D0. Pausa/aborto u otros servicios no se agregan por este acuerdo. No se inicia implementación.

**Requisitos afectados:** `REQ-EXEC-007`, `REQ-EXEC-010`, `REQ-UART-005`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve la necesidad de consultas adicionales y los momentos de captura pendientes en D02, conservando el contenido y la coherencia mínimos aprobados.

### Acuerdo parcial de DEC-ARCH-009 — Exposición completa de campos registrados del pipeline

**Estado del acuerdo:** Aprobado como base de diseño. Se selecciona el contenido de D03; `DEC-ARCH-009` y D03 siguen pendientes de la representación binaria externa que se completará con D05.

**Dominio:** Debug / Campos de IF/ID, ID/EX, EX/MEM y MEM/WB.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba transmitir todos los campos registrados ya definidos en interfaces.md para interpretar los datos y controles que lleva cada instrucción por el pipeline. El orden y empaquetado UART se difieren explícitamente al layout del snapshot.

**Decisión:** Cada snapshot de Debug incluye los campos funcionales completos de los cuatro latches, con la semántica y anchos internos existentes:

| Latch | Campos expuestos | Cantidad y ancho interno total |
|---|---|---|
| IF/ID | `valid`, `pc[31:0]`, `instruction[31:0]`, `fetch_fault_valid`, `fetch_fault_cause[2:0]` | 5 campos, 69 bits |
| ID/EX | `valid`, `pc[31:0]`, `instruction[31:0]`, `rs1[4:0]`, `rs2[4:0]`, `rd[4:0]`, `rs1_value[31:0]`, `rs2_value[31:0]`, `immediate[31:0]`, `alu_op[5:0]`, `alu_src`, `result_sel[1:0]`, `flow_op[2:0]`, `mem_op[3:0]`, `reg_write` | 15 campos, 193 bits |
| EX/MEM | `valid`, `pc[31:0]`, `instruction[31:0]`, `rd[4:0]`, `reg_write`, `mem_op[3:0]`, `ex_result[31:0]`, `store_data[31:0]` | 8 campos, 139 bits |
| MEM/WB | `valid`, `pc[31:0]`, `instruction[31:0]`, `rd[4:0]`, `reg_write`, `wb_value[31:0]` | 6 campos, 103 bits |

Los 34 campos corresponden a 504 bits de estado interno. Este total no fija longitud UART, padding, orden ni packing externo. No se modifican los latches ni se agregan registros de diagnóstico, causas de invalidez o señales combinacionales al snapshot.

`valid` conserva la interpretación de instrucción activa. Con valid=0, los datos residuales no se presentan como una instrucción activa. IF/ID puede transportar el candidato separado `fetch_fault_valid=1`: su PC y causa describen un candidato de fetch, no un fault global confirmado. La condición de fault vigente sigue representada por global_state y `fault_cause`/`fault_pc` globales, según los acuerdos existentes.

Los controles de ID/EX se exponen por sus seis campos definidos; no se inventa un bus adicional llamado control. EX/MEM expone el resultado seleccionado y el dato de store registrados; no se agregan resultados alternativos ni operandos efectivos combinacionales. MEM/WB expone el valor de writeback registrado.

**Justificación:** Observar el contenido completo ya existente permite seguir tanto identidad de instrucciones como operandos, resultados y controles por etapa. Reutilizar los esquemas definidos evita crear otro subconjunto de campos registrado o diagnósticos adicionales.

**Consecuencias y alcance pendiente:** Queda aprobado qué campos de los latches viajan en Debug. Se continúa con D04 para memoria utilizada, y se vuelve a la representación externa de D03 en D05: orden/ancho UART, padding, codificación de controles, validez e identificación de latches. D03 y `DEC-ARCH-009` no se marcan completos hasta resolver esa representación. La serialización/captura se realiza luego en D06; no se inicia implementación.

**Requisitos afectados:** `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-014`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Selecciona exposición completa y resuelve la inclusión del candidato registrado de IF/ID, conservando la representación externa pendiente y los esquemas internos aprobados.

### Acuerdo parcial de DEC-SYS-005 — Memoria utilizada como bytes escritos en la sesión

**Estado del acuerdo:** Aprobado como base de diseño. Criterio, unidad y lista lógica de D04 aprobados; `DEC-SYS-005` y D04 siguen pendientes de la representación binaria externa que se completará con D05.

**Dominio:** Debug / Selección y representación lógica de DMEM utilizada.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba considerar utilizada la memoria que el programa escribió en la sesión actual, por byte, después de aclarar que se envía el contenido actual y que una escritura de cero también cuenta.

**Decisión:** El conjunto de memoria utilizada reúne las direcciones de los bytes escritos efectivamente por stores de CPU en la sesión actual. Se incorpora un byte al comprometerse el store, con la misma condición `dmem_store_fire` y selección de bytes ya definidas para DMEM; detectar/decodificar una instrucción store no basta.

- SB incorpora su único byte, SH sus dos bytes y SW sus cuatro bytes consecutivos, conforme a dirección y lanes validados.
- Escribir el valor cero incorpora el byte igual que cualquier otro valor.
- Leer una posición no la incorpora. Inicialización y mantenimiento de Session Preparation tampoco cuentan como stores del programa.
- Una nueva escritura conserva la pertenencia del byte y actualiza su valor; cada dirección aparece una sola vez en el snapshot.
- Cada sesión nueva comienza con el conjunto vacío, incluido el reinicio de ejecución de la misma imagen después de FINISHED/FAULT.

Cada snapshot contiene una lista en orden creciente de dirección, con un par lógico `(dirección del byte, valor actual de 8 bits)` por posición utilizada. El valor es el correspondiente al instante coherente de ese snapshot; no es un historial ni solo los cambios desde el paso anterior. Sin stores comprometidos, la lista está vacía. El layout, anchos externos de dirección/cantidad y representación binaria de la lista vacía se completarán en D05.

Las direcciones pertenecen a DMEM base cero y capacidad del perfil activo. Los valores respetan la semántica de memoria de la sesión, sin exponer residuos de una sesión anterior. No se incluyen huecos no escritos entre direcciones utilizadas ni se exige transmitir toda la capacidad.

Ejemplo: después de escribir 7 en el byte 0x10 y 0 en 0x20, el snapshot contiene `(0x10, 7)` y `(0x20, 0)`. Sobrescribir 0x10 con 9 produce posteriormente `(0x10, 9)` y `(0x20, 0)`. Leer 0x30 no agrega una entrada.

**Justificación:** El criterio por byte coincide con las escrituras y el cero lógico de la arquitectura, representa correctamente stores parciales y mantiene observables las escrituras de cero. La metadata de validez por byte de referencia puede reutilizarse para seleccionar la lista; el criterio externo se fija por este acuerdo y no por la mera existencia de un bitmap físico.

**Consecuencias y alcance pendiente:** Se aprueban criterio, granularidad, orden y contenido lógico de D04. Se continúa con D05 y se completa allí la cantidad/longitud y representación binaria de la lista, incluida la vacía, antes de cerrar D04 y `DEC-SYS-005`. Ownership, recorrido/captura y serialización se concretarán en D06 y el diseño de bloques, sin imponer un segundo bitmap ni un contador persistente nuevo. No se inicia implementación.

**Requisitos afectados:** `REQ-MEM-008`, `REQ-MEM-019`, `REQ-MEM-028`, `REQ-MEM-029`, `REQ-DBG-010`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-009`, `REQ-DOC-005`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Selecciona posiciones escritas, unidad byte y lista dirección/valor, conservando la representación binaria externa pendiente y los contratos de memoria/coherencia existentes.

### Acuerdo parcial de DEC-PROTO-001 — Representación binaria de campos del snapshot

**Estado del acuerdo:** Aprobado como base de diseño. Se completa P02; D05 y `DEC-PROTO-001` siguen pendientes del layout y delimitación restantes.

**Dominio:** Debug / Anchos externos, orden de bytes y representación escalar.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El contenido de latches y memoria utilizada está seleccionado. El usuario aprueba reglas comunes para representar los campos en bytes antes de fijar el orden de los bloques y la cantidad de entradas de memoria.

**Decisión:** El snapshot se transmite como datos binarios. Cada campo comienza en un byte propio; no se empaquetan campos pequeños distintos dentro del mismo byte:

- Campos de 32 bits, incluidos RF, PC, instrucciones, operandos, direcciones y resultados: cuatro bytes.
- Contador de ciclos de 64 bits: ocho bytes.
- Campos de ocho bits, incluidos valores de bytes DMEM: un byte.
- Flags y campos de menos de ocho bits, incluidos índices, controles y causas: un byte cada uno, con bits altos sobrantes en cero. Flags booleanos: 00 o 01.
- Todos los campos multibyte del protocolo usan little-endian, manteniendo también el tamaño y las instrucciones LOAD ya aprobados.

Los datos arquitectónicos conservan su patrón de bits, incluidos los valores de 32 bits interpretables con signo por una instrucción; no se convierten a texto ni se alteran por el padding de campos pequeños. El padding externo no agrega ni modifica bits registrados en los latches. Las codificaciones semánticas de resultados y estados pendientes no quedan asignadas por escoger un byte para transportarlas.

Ejemplo: 0x12345678 se transmite como `78 56 34 12`; un índice de registro 5, como `05`; un flag verdadero, como `01`. La causa interna de tres bits ocupa un byte con sus bits altos en cero; su interpretación sigue el campo y la validez correspondientes.

Las longitudes resultantes para el contenido ya aprobado de los latches son:

| Latch | Longitud externa de sus campos |
|---|---|
| IF/ID | 11 bytes |
| ID/EX | 30 bytes |
| EX/MEM | 20 bytes |
| MEM/WB | 15 bytes |

Los cuatro latches ocupan 76 bytes; RF completo ocupa 128 bytes. Estas longitudes no fijan todavía el orden de bloques/campos, identificadores adicionales, presencia de metadatos inactivos ni longitud total del snapshot. Cada entrada lógica de memoria utilizada tendrá dirección de cuatro bytes y valor de uno; cantidad de entradas, posición de esa cantidad y representación de lista vacía se completarán en D05.

**Justificación:** Anchos naturales, little-endian y un byte propio para cada campo pequeño permiten formar e interpretar los campos sin cruzarlos entre límites de bytes. Se conserva el orden multibyte utilizado por LOAD y memoria.

**Consecuencias y alcance pendiente:** Se completa P02. D03 ya dispone de campos y anchos externos; D04 de dirección/valor por byte, pero ambos continúan abiertos hasta su representación completa en D05. Se sigue con orden de bloques, identificación de RF/latches, cantidad/longitud de memoria, metadatos según validez, codificación de estados/resultados y delimitación del snapshot. La captura/envío se concreta en D06. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-005`, `REQ-DBG-005`, `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-016`, `REQ-DBG-017`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Resuelve endianness y representación escalar externos pendientes en P02 y parcialmente en D03–D05, sin cambiar campos internos ni asignar códigos numéricos pendientes.

### Acuerdo parcial de DEC-PROTO-001 — Orden y delimitación del snapshot

**Estado del acuerdo:** Aprobado como base de diseño. Completa el layout por posición y la lista binaria de D04; D03/D05 conservan pendientes de interpretación y códigos. Captura y envío se definirán en D06.

**Dominio:** Debug / Orden de campos y longitud del mensaje.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba ordenar contexto, RF, latches y memoria utilizada, con cantidad explícita de entradas y sin identificadores adicionales por registro o latch.

**Decisión:** Después de la cabecera común `[código de solicitud: 1][resultado: 1]`, el cuerpo del snapshot tiene este orden fijo. Los offsets siguientes comienzan en cero en el cuerpo, excluyendo los dos bytes de cabecera:

| Bloque / campo | Offset en el cuerpo | Longitud en bytes |
|---|---|---|
| `global_state` | 0 | 1 |
| `image_valid` | 1 | 1 |
| PC global | 2 | 4 |
| `cycle_count` | 6 | 8 |
| `fault_cause` global | 14 | 1 |
| `fault_pc` global | 15 | 4 |
| RF: x0, x1, …, x31 | 19 | 128 |
| IF/ID | 147 | 11 |
| ID/EX | 158 | 30 |
| EX/MEM | 188 | 20 |
| MEM/WB | 208 | 15 |
| `used_count` | 223 | 5 |
| Lista de memoria utilizada | 228 | `5 * used_count` |

RF identifica cada registro por posición: x_i comienza en `19 + 4*i`. Los latches se identifican por bloque y sus campos siguen exactamente el orden del esquema aprobado en `interfaces.md` y el acuerdo de exposición completa: IF/ID 5 campos, ID/EX 15, EX/MEM 8 y MEM/WB 6. No se agregan bytes de identificación ni campos nuevos. Cada campo conserva el ancho externo y little-endian del acuerdo de representación escalar.

`fault_cause` y `fault_pc` globales siempre ocupan sus posiciones. Solo se interpretan como fault vigente en FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP o FAULT. Su presencia no agrega un flag de fault ni exige borrar bits físicos cuando el estado no los valida.

`used_count` es unsigned de 40 bits, cinco bytes little-endian, y cuenta entradas de bytes escritos; no es la última dirección ni la longitud de un rango. Su dominio es de cero hasta la capacidad de DMEM, inclusive. Permite representar hasta 2^32 entradas: `00 00 00 00 01`. Cada entrada ocupa `[dirección de byte: 4 bytes little-endian][valor actual: 1 byte]`; todas las direcciones son únicas, pertenecen a DMEM y aparecen en orden creciente, conforme al criterio de DEC-SYS-005. Para `used_count=0`, los cinco bytes son cero y no sigue ninguna entrada.

La longitud del cuerpo es `228 + 5*used_count` bytes; la respuesta completa, incluida su cabecera, ocupa `230 + 5*used_count`. La PC recibe la parte fija, lee la cantidad y recibe exactamente las entradas indicadas; al terminar la última entrada termina el mensaje. No hay marcador final, longitud adicional, checksum ni padding entre bloques. Sin memoria escrita la respuesta completa ocupa 230 bytes; con dos entradas, 240 bytes. Con los 2048 bytes de DMEM del perfil REFERENCE escritos, ocupa 10470 bytes.

**Justificación:** El layout fijo identifica contexto, registros y latches por posición. La cantidad explicita tanto la lista vacía como el final de una lista de longitud variable, preservando todo el rango de capacidades admitido.

**Consecuencias y alcance pendiente:** Se completa D04 y se cierra DEC-SYS-005 como criterio y representación externa de memoria utilizada. D03/D05 mantienen pendientes de codificación semántica, interpretación de campos inactivos y tratamiento de snapshot truncado; los códigos numéricos globales y de resultados se asignarán en C03. D06 concretará captura, coherencia durante envío y solicitudes concurrentes. No se inicia implementación.

**Requisitos afectados:** `REQ-DBG-005`, `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-016`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-SW-009`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa orden, identificación por posición, cantidad y delimitación pendientes del acuerdo de representación binaria, sin cambiar los esquemas funcionales ni asignar códigos pendientes.

### Acuerdo parcial de DEC-PROTO-001 — Campos registrados e interpretación del snapshot

**Estado del acuerdo:** Aprobado como base de diseño. Completa códigos de control, exposición de campos inactivos y tratamiento de snapshot incompleto. D03 completo; asignación de códigos globales/resultados en C03, captura/envío en D06 y plazos/fallas restantes en C06.

**Dominio:** Debug / Representación externa y responsabilidad del lector.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario acepta reutilizar códigos arquitectónicos y descartar una observación incompleta, y precisa que determinar la relevancia de los campos según valid corresponde a quien lee la información Debug.

**Decisión:** Los controles y causas transmiten sus códigos funcionales ya definidos en la arquitectura, sin otra tabla de traducción: el campo ocupa un byte, conservando sus bits significativos y completando los superiores con cero. Esto incluye alu_op, alu_src, result_sel, flow_op, mem_op, reg_write y las causas de fetch/fault. Los códigos externos de global_state y resultados todavía se asignarán en C03; no se impone una codificación física a la FSM global por este acuerdo.

Debug expone todos los campos registrados aprobados, incluidos valid y fetch_fault_valid, en el formato fijo acordado. Para latches inválidos conserva los datos registrados; no filtra campos, no sustituye sus valores por cero y no agrega una clasificación de residuos. El padding externo de campos pequeños continúa aplicándose y no borra sus bits significativos.

La responsabilidad de interpretar los valores corresponde al lector o consumidor de Debug. valid indica una instrucción activa; cuando vale cero, los restantes datos no representan por sí solos una instrucción activa. En IF/ID, fetch_fault_valid indica separadamente un candidato y habilita interpretar el PC/causa correspondientes, sin presentarlo como fault global confirmado. El lector interpreta causa/PC globales como fault vigente solamente cuando global_state valida esa condición. Los indicadores existentes aportan el contexto; el emisor no decide cómo se muestra ni si se ocultan valores en la PC.

Una respuesta de Debug se admite como nueva observación solamente cuando se recibió completa según el layout y used_count. Ante respuesta incompleta, el consumidor descarta esa observación parcial y conserva la última completa, identificada con su ciclo y sesión anteriores; no la presenta como un estado nuevo. El plazo para declarar recepción incompleta y la recuperación del enlace se definirán en C06. No se agrega un checksum ni reenvío automático.

**Justificación:** Reutilizar códigos y exponer estado registrado conserva una representación directa y fija. Los indicadores permiten al lector distinguir datos activos, candidatos y valores sin vigencia. Exigir recepción completa evita combinar partes de estados diferentes o actualizar la observación con información parcial.

**Consecuencias y alcance pendiente:** D03 queda completo: contenido, anchos, orden, identificación por posición, códigos de campos y responsabilidad de interpretación. DEC-ARCH-009 conserva pendiente la asignación externa de global_state en C03. D05 conserva esa dependencia de códigos, que se retoma en C03; se avanza a D06 para captura y envío coherente. No se selecciona aquí una implementación de captura, una presentación de PC ni los plazos restantes.

**Requisitos afectados:** `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa las reglas pendientes del acuerdo de orden y delimitación; explicita responsabilidad del lector y preserva los esquemas funcionales y códigos arquitectónicos.

### Acuerdo parcial de DEC-PROTO-001 — Envío exclusivo de Debug con estado retenido

**Estado del acuerdo:** Aprobado como base de diseño. D06 completo en el nivel de contrato del protocolo; puertos, secuencia de recorrido y FSM privada quedan para el diseño de bloques. Códigos globales/resultados pendientes en C03 y plazos/fallas en C06.

**Dominio:** Debug / Coherencia, exclusión de solicitudes y reset durante envío.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba mantener el estado detenido durante la respuesta automática Debug, esperar la respuesta completa desde PC, descartar RX durante el envío y distinguir reset UART de botón físico.

**Decisión:** El instante observado es el estado posterior al flanco del único ciclo efectivo de STEP o al último ciclo efectivo de RUN que alcanza FINISHED/FAULT después del drenado. Incluye los commits de RF/DMEM y todos los valores registrados posteriores a ese flanco. Desde ese estado hasta terminar físicamente la respuesta, el transporte no admite nuevas solicitudes que puedan cambiar la sesión; la exclusión incluye espera previa a transmitir y toda la cabecera común y el cuerpo. RUN conserva el orden aprobado: primero aceptación completa, luego respuesta final con Debug, aunque alcance el terminal antes de finalizar la aceptación.

La CPU permanece sin nuevos ciclos efectivos; no comienza LOAD ni preparación de otra sesión. PC, RF, latches, contador, estado, imagen y DMEM de la sesión permanecen estables. UART, lectura Debug, recorrido de metadata y serialización siguen funcionando con el clock funcional común. Se selecciona lectura directa del estado retenido, respetando los puertos de lectura y ownership; no se necesita una copia completa adicional ni shadow de RF, latches y DMEM para garantizar coherencia. El registro de bytes, índices o cantidad necesario para recorrer/serializar se concretará en el diseño de bloques.

La PC espera la respuesta completa antes de enviar cualquier otra solicitud, incluida consulta de disponibilidad o RESET. Durante la exclusión, la FPGA consume y descarta los bytes RX sin interpretarlos como comandos, responderlos ni conservarlos para ejecutarlos después. No se encola una respuesta NO_DISPONIBLE entre bytes Debug. Un RESET enviado prematuramente por UART también se descarta; la PC debe enviarlo después del intercambio completo, y entonces rige su aceptación previa al reset global ya aprobada.

La admisión de solicitudes vuelve a habilitarse al finalizar físicamente el último byte de la respuesta Debug, incluido su bit de Stop; encolarlo en FIFO TX no basta. No se agrega un intervalo de silencio al envío correcto. El contrato supone una PC cooperativa y no incorpora mecanismos para emisores que continúen enviando solicitudes después de violar esa secuencia.

El botón físico conserva el reset global directo e inmediato conforme al acondicionamiento aprobado; puede interrumpir la transmisión. Se abandona el envío previo y no se continúa con datos de la nueva sesión dentro de esa respuesta. La PC descarta el snapshot incompleto y conserva la última observación completa como anterior. Al retomar el enlace, sigue el flujo ya aprobado de abandonar el intercambio previo y consultar disponibilidad; los plazos y la recuperación del enlace quedan para C06. No hay aceptación UART ni aviso espontáneo por el botón.

**Justificación:** Los momentos automáticos de Debug ya dejan la CPU detenida. Excluir operaciones de sesión permite leer directamente un estado estable durante una transferencia lenta y delimitar una sola respuesta. Consumir RX evita acumular solicitudes accidentales en FIFO; distinguir reset UART y físico conserva la prioridad y respuesta de cada mecanismo.

**Consecuencias y alcance pendiente:** Se cierra D06 como contrato de coherencia y transporte, sin agregar estados a la FSM global de 14 estados. La exclusión y el fin físico se coordinan en la capa de protocolo, antes de entregar comandos aceptados a la CPU. La realización de señales, puertos de lectura, cantidad/recorrido de bytes usados, control privado de Debug y distribución de recursos se completará antes de implementar. C01/C02/C03 concretan lista y códigos; C04 reúne elegibilidad e intercambios; C05/C06 completan errores y plazos. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-EXEC-012`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-016`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Selecciona estado retenido y lectura directa para los momentos automáticos aprobados; completa captura/envío y reset durante snapshot pendientes de acuerdos anteriores. Conserva las reglas de RESET reconocido fuera del envío, reset físico, sesión y prioridad funcional.

### Acuerdo parcial de DEC-PROTO-002 — Lista final y nombres de operaciones

**Estado del acuerdo:** Aprobado como base de diseño. C01 completo; asignación individual de códigos pendiente en C02.

**Dominio:** Debug / Servicios y nombres definitivos del protocolo.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario confirma las cinco operaciones acordadas y solicita nombres en inglés. Aprueba LOAD, RUN, STEP, RESET y CHECK_READY; esta última sustituye la etiqueta descriptiva provisional CONSULTAR_DISPONIBILIDAD.

**Decisión:** La lista final de solicitudes consta de cinco operaciones:

| Nombre definitivo | Servicio | Campos de solicitud ya aprobados |
|---|---|---|
| LOAD | Cargar el programa y preparar una sesión | Código de un byte y tamaño unsigned de cinco bytes little-endian; contenido de N bytes después de aceptación |
| RUN | Ejecución continua y resultado final con Debug | Código de un byte, sin parámetros |
| STEP | Un ciclo efectivo y respuesta con Debug | Código de un byte, sin parámetros |
| RESET | Reset global solicitado por PC, con aceptación antes de aplicarlo | Código de un byte, sin parámetros |
| CHECK_READY | Consultar disponibilidad para recibir LOAD | Código de un byte, sin parámetros |

CHECK_READY es la misma consulta informativa aprobada: devuelve `[CHECK_READY][DISPONIBLE / NO_DISPONIBLE]`, dos bytes, sin datos ni reserva de una carga. La PC consulta antes de LOAD; la FPGA valida LOAD por sus condiciones actuales y no exige recordar una consulta previa. Disponible no implica imagen ejecutable válida. Se conservan elegibilidad, tiempos, exclusión y descarte durante recuperación/envío Debug previamente aprobados.

Los nombres son etiquetas de diseño compartidas por PC y FPGA. En el enlace se transmiten códigos binarios de un byte, nunca las cadenas ASCII de los nombres. La numeración sigue siendo consecutiva desde 0x01; no se asigna un número concreto por operación en este acuerdo.

Debug se entrega automáticamente en las respuestas de STEP y final RUN. Reintentar consiste en otra LOAD completa solicitada por el usuario. La lista no incorpora solicitudes adicionales de snapshot, reintento, pausa/aborto ni negociación/reporte de capacidades.

**Justificación:** La lista consolida los servicios ya aprobados y permite asignar códigos sobre un conjunto definitivo. CHECK_READY conserva el significado específico de disponibilidad para LOAD y mantiene los nombres del protocolo en inglés.

**Consecuencias y alcance pendiente:** Se cierra C01 y la selección de servicios de DEC-SYS-007/DEC-PROTO-002. Estos identificadores siguen abiertos por realización de bloques y códigos/integración respectivamente. C02 asignará códigos; C03 resultados/estados; C04 reunirá elegibilidad y reglas de intercambios; C05/C06 errores y plazos; C07 perfil compartido. No se modifica la semántica de las operaciones ni se inicia implementación.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida las operaciones aprobadas y sustituye CONSULTAR_DISPONIBILIDAD como nombre provisional por CHECK_READY; conserva los formatos y comportamientos definidos en acuerdos anteriores.

### Acuerdo parcial de DEC-PROTO-001 — Códigos definitivos de solicitud

**Estado del acuerdo:** Aprobado como base de diseño. C02 completo; códigos de resultado y global_state pendientes en C03.

**Dominio:** Debug / Códigos binarios de operación.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba asignar los cinco códigos consecutivos desde 0x01 a la lista definitiva de operaciones, conservando la cabecera común de respuesta.

**Decisión:** Cada solicitud comienza con un byte binario de operación:

| Operación | Código hexadecimal |
|---|---|
| LOAD | 0x01 |
| RUN | 0x02 |
| STEP | 0x03 |
| RESET | 0x04 |
| CHECK_READY | 0x05 |

La respuesta comienza con ese mismo código y después un byte de resultado, seguido por los datos definidos para la operación. Esto rige tanto aceptación/final de LOAD y RUN como respuesta STEP, RESET y CHECK_READY. Los códigos no expresan prioridad y sus valores no se reutilizan automáticamente para codificar resultados.

Ejemplos de solicitudes completas: RUN `02`, STEP `03`, RESET `04`, CHECK_READY `05`. Una solicitud LOAD de 32 bytes es `01 20 00 00 00 00`; después de aceptación se envían exactamente sus 32 bytes de programa. En una respuesta LOAD los dos bytes son `[01][resultado]`; STEP realizado usa `[03][resultado][snapshot]`. Los símbolos de resultado conservan sus significados aprobados, pero su byte numérico se asignará en C03. Los formatos simbólicos existentes se interpretan mediante esta tabla; no representan cadenas ASCII.

**Justificación:** La tabla implementa la regla de un byte y numeración consecutiva aprobada, identifica inequívocamente las cinco solicitudes y permite completar la representación binaria de los ejemplos sin cambiar sus formatos.

**Consecuencias y alcance pendiente:** Se cierra C02. C03 asignará resultados y códigos externos de global_state, retomando la dependencia de D05/DEC-ARCH-009; C04/C05/C06/C07 completarán reglas comunes, errores, plazos y perfil. Se conservan todas las políticas de aceptación, reset, exclusión, recuperación y sesión aprobadas. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-008`, `REQ-UART-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa la asignación individual diferida por el acuerdo de códigos de un byte y la lista final de operaciones, sin asignar resultados ni estados.

### Acuerdo parcial de DEC-PROTO-001 — Códigos comunes de resultado

**Estado del acuerdo:** Aprobado como base de diseño. Tabla del segundo byte de respuesta aprobada; C03 permanece abierto únicamente por códigos externos de global_state. Errores restantes se concretarán en C05.

**Dominio:** Debug / Resultados binarios de solicitudes.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba una tabla común de once resultados con nombres en inglés. El código de operación identifica la solicitud; el código siguiente expresa aceptación, disponibilidad, éxito o tipo de fallo.

**Decisión:** El segundo byte de respuesta utiliza estos códigos:

| Código | Nombre definitivo | Significado aprobado |
|---|---|---|
| 0x01 | ACCEPTED | LOAD, RUN o RESET aceptado |
| 0x02 | DONE | LOAD completado o ciclo STEP realizado |
| 0x03 | READY | Disponible para recibir LOAD, respuesta CHECK_READY |
| 0x04 | BUSY | No disponible para la operación |
| 0x05 | NO_IMAGE | No hay imagen válida para ejecutar |
| 0x06 | INVALID_SIZE | Tamaño de LOAD inválido |
| 0x07 | INCOMPLETE_REQUEST | Solicitud LOAD recibida incompleta |
| 0x08 | INCOMPLETE_DATA | Contenido del programa LOAD recibido incompleto |
| 0x09 | UART_ERROR | Error UART durante recepción de LOAD |
| 0x0A | FINISHED | RUN terminó normalmente por halt |
| 0x0B | FAULT | RUN terminó por fault de CPU |

La cabecera continúa siendo `[código de operación][resultado]`. La presencia y longitud de datos dependen de la operación y resultado ya aprobados. DONE de LOAD termina tras dos bytes; DONE de STEP agrega Debug. Un STEP efectivamente realizado conserva DONE incluso si confirma halt/fault o avanza drenado: global_state y causa/PC del snapshot describen su estado arquitectónico. Solo RUN usa FINISHED/FAULT como resultado terminal automático. FAULT es una terminación de CPU, distinta de UART_ERROR del transporte.

Correspondencia con las etiquetas descriptivas anteriores: ACEPTADA → ACCEPTED; COMPLETADA y COMPLETADO → DONE; DISPONIBLE → READY; NO_DISPONIBLE → BUSY; SIN_IMAGEN → NO_IMAGE; TAMAÑO_INVALIDO → INVALID_SIZE; SOLICITUD_INCOMPLETA → INCOMPLETE_REQUEST; CONTENIDO_INCOMPLETO → INCOMPLETE_DATA; ERROR_UART → UART_ERROR; FINALIZADA → FINISHED. FAULT conserva nombre y significado. Los acuerdos históricos con esas etiquetas se interpretan mediante esta tabla.

Ejemplos de respuestas completas sin snapshot: CHECK_READY disponible `05 03`, no disponible `05 04`; aceptación LOAD `01 01`, carga completada `01 02`, tamaño inválido `01 06`; aceptación RUN `02 01`; RUN sin imagen `02 05`; STEP sin imagen `03 05`; aceptación RESET `04 01`. Respuestas con snapshot: STEP realizado `[03][02][snapshot]`, RUN normal `[02][0A][snapshot]` y RUN con fault `[02][0B][snapshot]`. Sus longitudes completas continúan siendo `230 + 5*used_count` bytes, incluidos los dos de cabecera.

No se asigna prioridad por el número de resultado ni se modifica la aceptación de solicitudes. READY/BUSY de CHECK_READY siguen expresando disponibilidad para LOAD, sin reserva ni garantía de imagen válida. Los códigos de estado del snapshot pertenecen a otro campo y se definirán a continuación.

**Justificación:** Una tabla compartida evita códigos redundantes para resultados equivalentes; el primer byte diferencia LOAD y STEP. Nombres en inglés mantienen consistencia con las operaciones y la separación de fallo de CPU/transporte permite interpretar cada respuesta sin un campo de motivo adicional.

**Consecuencias y alcance pendiente:** Resultados 0x01–0x0B quedan aprobados; se actualizan etiquetas en contratos actuales, conservando el historial. C03/D05 y DEC-ARCH-009 quedan pendientes solamente de códigos externos de global_state. C05 definirá errores fuera de LOAD y código desconocido, extendiendo el conjunto únicamente si se acuerda una respuesta adicional. C04/C06/C07 completan intercambios, esperas y perfil compartido. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-013`, `REQ-DBG-017`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Asigna códigos y nombres definitivos a los resultados aprobados, unifica las etiquetas de éxito LOAD/STEP en DONE y conserva sus formatos, efectos y reglas temporales.

### Acuerdo parcial de DEC-PROTO-001 — Códigos externos de global_state

**Estado del acuerdo:** Aprobado como base de diseño. Completa C03/D05 y la representación externa de DEC-ARCH-009.

**Dominio:** Debug / Estado global transmitido en el snapshot.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba asignar un código externo de un byte a cada uno de los 14 estados ya definidos de la FSM global.

**Decisión:** global_state ocupa el primer byte del cuerpo del snapshot, offset cero después de los dos bytes de cabecera, con esta tabla:

| Código | Estado |
|---|---|
| 0x00 | NO_IMAGE |
| 0x01 | LOADING |
| 0x02 | PREPARING_READY |
| 0x03 | READY |
| 0x04 | RUNNING |
| 0x05 | STEPPING |
| 0x06 | HALT_DRAIN_AUTO |
| 0x07 | HALT_DRAIN_STEP |
| 0x08 | FAULT_DRAIN_AUTO |
| 0x09 | FAULT_DRAIN_STEP |
| 0x0A | FINISHED |
| 0x0B | FAULT |
| 0x0C | PREPARING_RUN |
| 0x0D | PREPARING_STEP |

Son códigos de transporte; no imponen una codificación física a la FSM ni agregan estados o registros funcionales. Solicitudes, resultados y global_state ocupan campos diferentes. El lector usa la posición de cada byte para aplicar su tabla correspondiente, aunque sus valores numéricos coincidan.

Ejemplo: STEP que deja STEPPING comienza `03 02 05`: operación STEP, resultado DONE y global_state STEPPING. Si ese STEP alcanza FINISHED, comienza `03 02 0A`; si alcanza FAULT, `03 02 0B`. El resultado del STEP realizado sigue DONE, y el estado/causa/PC del snapshot indican terminación o fault. RUN terminado normalmente comienza `02 0A 0A`; RUN con fault, `02 0B 0B`. El resto del snapshot sigue su layout aprobado.

La tabla cubre todos los estados arquitectónicos, sin ampliar los momentos de transmisión: únicamente snapshots automáticos tras STEP y final RUN. Estados de carga/preparación y RUN/drain AUTO no adquieren un servicio adicional de captura por disponer de código. Causa/PC globales conservan su vigencia en FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP y FAULT; el candidato IF/ID sigue separado.

**Justificación:** Códigos externos consecutivos y completos permiten interpretar inequívocamente la FSM y conservar el layout de un byte. El orden de la tabla sigue la lista arquitectónica existente.

**Consecuencias y alcance pendiente:** Se cierran C03 y D05; DEC-ARCH-009 queda aprobada al completar selección y representación externa de latches/contexto. Captura coherente y envío exclusivo siguen el contrato de D06. C04/C05/C06/C07 y la revisión/consolidación del protocolo permanecen pendientes, junto con puertos y realización de bloques. No se inicia implementación.

**Requisitos afectados:** `REQ-DBG-006`, `REQ-DBG-007`, `REQ-DBG-008`, `REQ-DBG-009`, `REQ-DBG-013`, `REQ-DBG-014`, `REQ-DBG-017`, `REQ-SW-008`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa la dependencia de códigos externos de estado diferida a C03, conservando campos, longitudes, momentos de observación y semántica arquitectónica.

### Acuerdo parcial de DEC-PROTO-001 — Orden de intercambios y respuestas

**Estado del acuerdo:** Aprobado como base de diseño. C04 completo; errores básicos restantes, plazos y perfil en C05/C06/C07.

**Dominio:** Debug / Secuencia PC–FPGA y elegibilidad de solicitudes.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba una operación normal en curso por vez, la posibilidad de CHECK_READY/RESET mientras RUN ejecuta, respuestas completas sin intercalar bytes y exclusión durante Debug.

**Decisión:** La PC mantiene una operación normal en curso por vez. LOAD continúa siendo un único intercambio a través de aceptación, envío de contenido y confirmación/fallo; STEP termina al recibir su única respuesta completa con Debug; RESET exige aceptación y el flujo posterior de consulta de disponibilidad ya aprobado. CHECK_READY termina con su respuesta completa de dos bytes. La PC no adelanta otra solicitud durante estos intercambios.

RUN es la excepción: después de ACCEPTED puede continuar ejecutando mientras su resultado final queda pendiente. Durante RUNNING y drains AUTO, PC puede solicitar CHECK_READY o RESET y espera la respuesta de esa solicitud antes de enviar otra. Se mantienen los rechazos BUSY de LOAD/RUN/STEP durante ejecución, sin cancelar ciclos CPU. Un RESET válidamente reconocido abandona el intercambio previo de RUN; PC deja de esperar su resultado y sigue el intercambio RESET/consulta. La CPU no se pausa anticipadamente por reconocer RESET: el reset global se solicita al terminar físicamente su aceptación conforme al contrato existente.

Cada respuesta se transmite completa antes de comenzar otra, incluido el Stop del último byte; no se intercalan cabeceras ni datos. RUN mantiene aceptación completa antes de resultado terminal. Si el resultado automático de RUN queda pendiente mientras se transmite una respuesta breve ya iniciada, esa respuesta se completa y luego se envía el resultado terminal con su Debug coherente. Se retiene el estado terminal durante la espera según D06. La realización física del arbitraje y los registros privados de respuesta se concretarán en diseño de bloques; no se agrega una cola de comandos al contrato.

La tabla siguiente consolida reglas aprobadas. Las fases del transporte prevalecen sobre la elegibilidad arquitectónica; READY en el estado CPU no habilita recepción de comandos mientras todavía se transmite una confirmación o Debug.

| Situación / fase | LOAD | RUN / STEP | CHECK_READY | RESET UART |
|---|---|---|---|---|
| Transporte disponible, NO_IMAGE | Validar tamaño y aceptar si es correcto | NO_IMAGE, dos bytes y sin Debug | READY, sin imagen válida implícita | ACCEPTED; reset global después del último Stop |
| Transporte disponible, READY/STEPPING/drains STEP/FINISHED/FAULT | Validar tamaño y aceptar si es correcto | Aceptar con la semántica arquitectónica ya definida | READY, sin reserva de carga | ACCEPTED; reset global después del último Stop |
| RUNNING o drains AUTO, fuera de respuestas/Debug | BUSY tras recibir cabecera completa; no cancela CPU | BUSY, sin alterar CPU | BUSY, respuesta de dos bytes | ACCEPTED y abandono del intercambio RUN anterior |
| Recepción de tamaño LOAD | Los cinco bytes son tamaño de la solicitud en curso | No se interpretan comandos dentro del tamaño | No se interpreta como comando | No se interpreta como comando |
| Recepción de contenido LOAD aceptado | Los siguientes N bytes son programa | No se interpretan comandos dentro del programa | No se interpreta como comando | No se interpreta como comando |
| Preparación LOAD y envío de su confirmación final | PC espera DONE; RX adicional se descarta | RX adicional se descarta | RX adicional se descarta | RX adicional se descarta |
| Preparación RUN/STEP y respuesta inicial RUN o respuesta STEP pendiente | PC espera el intercambio correspondiente | Sin segunda operación de PC ni preparación superpuesta | PC espera antes de otra solicitud normal | PC espera; conserva reset físico directo |
| Transmisión de una respuesta breve | PC espera completa | PC espera completa; no se intercalan respuestas | PC espera completa | PC espera completa |
| Respuesta automática Debug pendiente o en transmisión | RX consumido/descartado, sin respuesta | RX consumido/descartado, sin respuesta | RX consumido/descartado, sin respuesta | RX consumido/descartado; PC lo envía después |
| Recuperación RX por silencio | RX consumido/descartado | RX consumido/descartado | RX consumido/descartado, sin respuesta | RX consumido/descartado, sin respuesta |

La preparación RUN/STEP mantiene las políticas de sesión existentes. La tabla no define manejo de clientes que violen la secuencia durante respuestas breves o preparaciones ni agrega timeouts de ejecución. Las excepciones RUN se aplican durante ejecución efectiva, fuera de exclusión Debug. El botón físico conserva el reset directo en todas las fases y puede abortar una transmisión; la PC descarta cualquier respuesta Debug incompleta y abandona el intercambio previo al retomar el enlace.

**Justificación:** Una secuencia cooperativa y un único mensaje TX por vez permiten identificar respuestas por sus cabeceras y longitudes. RUN necesita una excepción para poder resetear un programa que no termina; Debug exige exclusión para conservar el estado observado. Reunir reglas de transporte y estado evita confundir disponibilidad arquitectónica con admisión mientras existe una respuesta en curso.

**Consecuencias y alcance pendiente:** C04 completo, sin nuevos comandos, prioridades globales ni estados CPU. Errores de código desconocido/UART fuera de LOAD quedan en C05; esperas y recuperación desde PC en C06; perfil compartido en C07. Puertos y FSM privadas de protocolo/UART/Loader/Debug permanecen en diseño de bloques. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-UART-011`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida elegibilidad y exclusión de los acuerdos existentes; fija una operación normal por vez, excepción de RUN y serialización completa de respuestas.

### Acuerdo parcial de DEC-PROTO-001 — Errores básicos fuera de LOAD

**Estado del acuerdo:** Aprobado como base de diseño. C05 completo; esperas y recuperación desde PC en C06.

**Dominio:** Debug / Código desconocido y error UART al recibir una operación.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba responder a un código desconocido sin ejecutar una operación, recuperar RX tras error UART en un código y mantener el tratamiento LOAD existente. Las otras cuatro solicitudes constan de un único byte.

**Decisión:** Cuando el receptor está interpretando códigos de operación y recibe correctamente un byte distinto de LOAD/RUN/STEP/RESET/CHECK_READY, envía `[byte recibido][UNKNOWN_COMMAND]`, exactamente dos bytes. UNKNOWN_COMMAND se agrega a la tabla común con código 0x0C, siguiente resultado libre. Ejemplo: código desconocido 0x06 responde `06 0C`. No se ejecuta una operación ni se altera imagen/sesión; si RUN ya ejecuta, continúa. La PC identifica este resultado como error de la solicitud y no como nuevo comando.

Ante error UART al recibir un código de operación fuera de LOAD, se descarta esa recepción y el RX pendiente, y se aplica la misma recuperación de R = 100 ms de silencio continuo: reinicio por actividad RX, final con línea en reposo, ningún byte en curso y FIFO RX vacía. Durante recuperación se consume/descarta RX sin interpretar comandos. No se emite una respuesta para esa recepción, porque no hay un código válido y confiable para identificarla. No se resetea la CPU, no se invalida la imagen ni se modifica la sesión como efecto del error; una ejecución RUN continúa y las respuestas TX existentes se conservan. Si coinciden error y byte recibido, ese byte no se interpreta como una solicitud válida.

LOAD conserva sus controles de solicitud/tamaño/contenido y UART_ERROR 0x09 con los efectos según aceptación ya definidos. RUN, STEP, RESET y CHECK_READY ocupan un byte sin parámetros: al recibirlo correctamente la solicitud está completa, por lo que no se agrega timeout para campos inexistentes. Una trama UART fallada corresponde al error físico, no a una solicitud parcialmente decodificada.

La respuesta UNKNOWN_COMMAND solo corresponde a un byte recibido válidamente en contexto de comandos. Durante tamaño/contenido LOAD los bytes son campos/datos, y durante recuperación, preparación/confirmación LOAD o envío exclusivo Debug rige el descarte ya aprobado; no se convierte un byte de esas fases en comando desconocido. Un error RX durante la exclusión Debug no modifica el estado observado ni intercala una respuesta en TX.

**Justificación:** Eco del byte desconocido y un resultado definido mantienen la cabecera común. Ante trama no confiable, descartar y esperar silencio evita atribuir una operación incorrecta o fabricar una respuesta. Los formatos de un byte hacen innecesario un timeout adicional de campos y conservan el alcance de una PC cooperativa de laboratorio.

**Consecuencias y alcance pendiente:** C05 completo; tabla de resultados extendida a 0x01–0x0C, conservando códigos anteriores. R se reutiliza fuera de LOAD solo en recepción de código con error UART; las políticas LOAD y Debug permanecen intactas. C06 fija plazos de recepción/reacción de PC, C07 perfil compartido y V01/V02/V03 revisión/consolidación. Puertos y FSM privadas quedan para diseño de bloques. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-001`, `REQ-UART-008`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-011`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa tratamiento de código desconocido/UART fuera de LOAD y extiende el enum de resultados con UNKNOWN_COMMAND, sin nuevos comandos ni cambios arquitectónicos.

### Acuerdo parcial de DEC-PROTO-003 — Plazos de RESET, STEP y recepción de Debug

**Estado del acuerdo:** Aprobado como base de diseño. Plazos restantes registrados; C06 conserva pendiente reacción de PC ante timeout, desconexión o respuesta truncada, incluida cabecera final RUN incompleta.

**Dominio:** Debug / Esperas de recepción de PC.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba esperar aceptación RESET/cabecera STEP durante 200 ms, y dividir la recepción Debug en parte fija y lista de memoria. Los límites usan tamaños aprobados, 19200 baud nominales y diez bits de trama UART por byte, conservando margen de 200 ms.

**Decisión:** Los plazos son máximos de espera, no demoras obligatorias. Se avanza al recibir los bytes completos:

| Espera de PC | Inicio del plazo | Plazo máximo |
|---|---|---|
| Aceptación RESET completa, dos bytes | Inicio del envío de su byte de solicitud | 200 ms |
| Cabecera STEP completa, operación y resultado | Inicio del envío de su byte de solicitud | 200 ms |
| Parte fija del cuerpo Debug, 228 bytes | Recepción completa de la cabecera que anuncia Debug | 319 ms |
| Lista de memoria, 5*K bytes, con K > 0 | Recepción completa de used_count, al final de la parte fija | ceil(5*K*10*1000/19200 + 200) ms |

La cabecera STEP rechazada con NO_IMAGE/BUSY completa su respuesta en dos bytes; DONE anuncia el cuerpo Debug. Los 228 bytes fijos excluyen la cabecera común e incluyen contexto, RF, latches y used_count de cinco bytes, conforme a D05. K es used_count, cantidad de bytes DMEM utilizados; cada entrada ocupa cinco bytes. Con K=0, la respuesta termina al completar la parte fija, sin esperar una lista inexistente.

La parte fija ocupa nominalmente 228*10*1000/19200 = 118,75 ms. Al sumar 200 ms y redondear arriba a milisegundos enteros, su plazo es 319 ms. Ejemplos de lista variable: K=2, diez bytes y plazo 206 ms; K=1000, 5000 bytes y plazo 2805 ms; K=2048, 10240 bytes y plazo 5534 ms. El plazo de la lista depende de K, no de la última dirección ni de la capacidad entera cuando la lista es menor.

RUN conserva 200 ms para su respuesta inicial completa y, después de ACCEPTED, espera de terminación sin límite de duración de ejecución. Una vez recibida la cabecera final FINISHED/FAULT, la parte fija y lista Debug usan los mismos plazos que STEP. RESET conserva aceptación antes del reset físico y consulta CHECK_READY posterior con su plazo de 200 ms ya aprobado; la aceptación no acredita final de reset ni existencia de imagen válida.

La representación y el recorrido del snapshot deben respetar estos presupuestos de recepción. Se mantienen baud nominal y margen de diseño del TP; los puertos, lectura/cantidad de DMEM utilizada, preparación necesaria y serialización se concretarán antes de implementar. No se agrega timeout de duración de RUN ni de recepción de campos a solicitudes de un byte.

**Justificación:** Los plazos breves mantienen el margen de reacción existente. El tamaño fijo tiene tiempo calculable; K permite calcular el plazo de la lista variable sin penalizar siempre una memoria poco usada ni truncar una lista grande. Cada fase tiene inicio identificable en el formato ya aprobado.

**Consecuencias y alcance pendiente:** Se registra la parte de plazos de C06 sin cerrarlo completo. Pendientes reacción ante timeout/desconexión, abandono de observación parcial y recuperación de PC antes de otra solicitud, y cabecera final RUN que empieza pero queda incompleta. La ausencia de confirmación no demuestra que una operación no ocurrió, y no se reenvía automáticamente una operación potencialmente ejecutada. C07 y revisión/consolidación siguen pendientes. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa esperas de RESET/STEP y recepción del snapshot diferidas a C06; conserva disponibilidad/LOAD, espera inicial RUN, recuperación FPGA y ausencia de timeout de ejecución.

### Acuerdo parcial de DEC-PROTO-003 — Recuperación de PC y cabecera final de RUN

**Estado del acuerdo:** Aprobado como base de diseño. C06 completo; perfil compartido y revisión/consolidación pendientes en C07/V01–V03.

**Dominio:** Debug / Reacción ante fallo de enlace y reanudación conocida.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba informar el fallo, descartar observación parcial, no repetir operaciones potencialmente ejecutadas y recuperar comunicación con ventana de descarte y CHECK_READY. También aprueba limitar la recepción de la cabecera final RUN una vez comenzada.

**Decisión:** Ante timeout, desconexión o respuesta truncada, PC informa el fallo, abandona la respuesta parcial y conserva la última observación completa como anterior, sin presentarla como estado nuevo. Detiene la secuencia normal de ejecución y no repite automáticamente STEP, RUN ni RESET: una confirmación perdida no demuestra que la operación no se ejecutó. La imagen y sesión FPGA no hacen rollback por una espera vencida en PC.

Para recuperar nuevas fallas fuera del flujo LOAD ya definido, PC espera una ventana suficiente para completar cualquier respuesta Debug pendiente y descarta todo RX durante ella. Con capacidad DMEM del perfil C, la ventana en milisegundos es:

```text
B_lista(C) = ceil(5*C*10*1000/19200 + 200)
B_intercambio(C) = 200 + 319 + B_lista(C)
W_debug(C) = 100 * ceil(B_intercambio(C) / 100)
```

La ventana empieza después de abandonar el intercambio fallido; tras desconexión se aplica al retomar el enlace. Usa capacidad del perfil, pues la cantidad del snapshot puede no haberse recibido. REFERENCE: C=2048, lista máxima 5534 ms, intercambio 6053 ms y ventana 6100 ms. ALT_1000: C=1000, lista máxima 2805 ms, intercambio 3324 ms y ventana 3400 ms. Es una cota conservadora derivada de los presupuestos aprobados para el TP; no es un límite a la duración de RUN.

Al terminar la ventana, PC limpia los datos RX pendientes locales y envía CHECK_READY. Una respuesta completa válida `[05][03 o 04]` restablece la comunicación: READY permite solicitar LOAD, BUSY indica que todavía no es elegible. Ninguna de ellas prueba que haya imagen válida ni reconstruye cuántos ciclos se ejecutaron durante el intercambio fallido. Si no llega respuesta válida en el plazo de consulta de 200 ms, se repite ventana y consulta. Solo se repite esta consulta informativa, no la operación original. Si otra transmisión impide la consulta por exclusión Debug, se conserva esa regla y se vuelve a la recuperación; no se interpreta arbitrariamente el cuerpo de una respuesta como una cabecera CHECK_READY.

Para volver a una sesión conocida, el usuario puede solicitar RESET y una nueva LOAD, con las secuencias de aceptación/consulta ya aprobadas. No se reanuda automáticamente una ejecución de estado incierto ni se agrega READ_STATE, reenvío automático, historial obligatorio o reset global automático ante una falla del transporte. LOAD conserva su cese/cancelación, ventana W según N, consulta y reintento manual ya definidos; W_debug no reemplaza esas reglas.

RUN conserva espera de ejecución sin límite mientras su respuesta terminal no haya comenzado. Desde el primer byte de la cabecera final RUN, PC espera como máximo 200 ms para completar sus dos bytes. Si comienza pero no termina, se declara fallo y se aplica la recuperación anterior. Cabecera terminal completa FINISHED/FAULT da inicio a los plazos de parte fija y lista Debug de C06; no se reinicia este plazo de cabecera por bytes parciales.

**Justificación:** Evitar repetir operaciones preserva la incertidumbre real de una confirmación perdida. Una ventana calculada con el tamaño máximo del perfil permite drenar respuestas pendientes antes de consultar. CHECK_READY es informativa y permite recuperar comunicación sin ejecutar CPU; RESET/LOAD voluntarios establecen una sesión nueva conocida. Limitar una cabecera comenzada detecta truncamiento sin limitar el tiempo de ejecución RUN.

**Consecuencias y alcance pendiente:** Se cierra C06 y se consolidan DEC-PROTO-002/003. C07 fijará cómo se selecciona/comparten perfiles; V01/V02/V03 completarán recorridos, revisión de tablas y documento definitivo. El diseño de bloques bajo DEC-SYS-007 concretará puertos, FSM privadas, contadores y arbitraje para cumplir los contratos. No se inicia implementación.

**Requisitos afectados:** `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-UART-006`, `REQ-UART-007`, `REQ-DBG-013`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa reacción de PC y cabecera final RUN pendientes del acuerdo de plazos, preservando recuperación LOAD y los contratos de CPU/Debug.

### Acuerdo parcial de DEC-PROTO-001 — Perfil compartido de memoria y protocolo

**Estado del acuerdo:** Aprobado como base de diseño. C07 completo; revisión y consolidación pendientes en V01/V02/V03.

**Dominio:** Debug / Configuración común PC–FPGA.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario aprueba seleccionar a priori el mismo perfil en ambos extremos, usar una tabla común como fuente de verdad y conservar códigos/layout entre perfiles, sin negociación UART adicional.

**Decisión:** Los perfiles comunes son REFERENCE por defecto (IMEM 1024 bytes, DMEM 2048 bytes) y ALT_1000 (IMEM 1000 bytes, DMEM 1000 bytes). La fuente de capacidades es la [tabla de perfiles de la arquitectura de memoria](architecture/memory_architecture.md#perfiles-definidos), ya aprobada. El perfil se selecciona antes de usar el sistema y debe ser el mismo en la configuración de elaboración/síntesis FPGA y en la configuración PC del protocolo. Esta decisión no prescribe interfaz gráfica, CLI ni formato de archivo de configuración.

PC toma de esa tabla sus límites de LOAD, rango/cantidad de DMEM y cálculo de esperas dependientes de capacidad. FPGA usa las mismas capacidades para memorias y validadores. Los códigos de solicitud, resultado, global_state, anchos escalares, orden y longitud fija de Debug son únicos y no cambian entre perfiles; la cantidad variable de memoria depende de las escrituras de la sesión. Las ventanas de recuperación y límites de imagen se calculan con los parámetros del perfil.

REFERENCE es el perfil físico obligatorio; ALT_1000 conserva el alcance de elaboración/simulación para verificar que no se asuman potencias de dos. No se exige desplegar ALT_1000 en placa ni se agrega una consulta/negociación de capacidades, identificación de perfil en cada paquete o versión de protocolo. Ambos extremos cumplen la configuración acordada de antemano para el TP.

**Justificación:** Los perfiles existentes proporcionan capacidades compartidas y evitan constantes contradictorias en PC y FPGA. Layout/códigos únicos mantienen el intercambio y la interpretación iguales, con variación solo en los límites y tiempos que dependen de tamaño/capacidad.

**Consecuencias y alcance pendiente:** C07 completo. V01 revisará recorridos; V02 tablas, longitudes, códigos y tiempos; V03 consolidará protocol.md y cerrará DEC-PROTO-001 cuando no queden diferencias. Puertos/FSM privadas en DEC-SYS-007 y decisiones de aplicación/assembler en DEC-SYS-008/009 siguen pendientes. No se inicia implementación.

**Requisitos afectados:** `REQ-MEM-010`, `REQ-UART-002`, `REQ-UART-008`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-SW-004`, `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Completa configuración compartida de C07, conservando capacidades, alcance de perfiles y todas las decisiones de mensajes/recuperación.

### Acuerdo parcial de DEC-SYS-007 — Correcciones de diseño de FSM del TP2

**Estado del acuerdo:** Criterios establecidos por el usuario a partir de las correcciones docentes del TP2. DEC-SYS-007 continúa pendiente en el diseño de bloques.

**Dominio:** UART / Organización del control y de las acciones sobre datos.

**Fecha de registro:** 2026-10-01.

**Contexto:** El usuario informa dos correcciones: expresar las decisiones de las FSM mediante casez y patrones con condiciones irrelevantes, y separar la lógica de control de la lógica que captura, desplaza o actualiza datos. Estas indicaciones guían la adaptación del TP2 al TP3 antes de implementar.

**Contraste con el TP2 disponible:** uart_rx y uart_tx ya registran estado, contadores y datos en el flanco de clk. Su lógica combinacional utiliza case para el estado e if/else para condiciones; en ese mismo bloque calcula tanto next_state como los siguientes valores de contadores y datos. La corrección consiste en reorganizar esa descripción, sin afirmar que el estado actual se actualizaba combinacionalmente.

**Criterios de diseño:**

1. La lógica combinacional de transición y generación de controles se expresa mediante casez, haciendo explícitas las condiciones de cada decisión. En los patrones, los bits irrelevantes se representan mediante `?`; no mediante `x`. El comodín indica que esa condición no participa en la elección, no que un registro deba almacenar un valor desconocido. La [documentación de Verilator](https://verilator.org/guide/latest/warnings.html#casewithx) distingue ese uso.
2. La FSM calcula el siguiente estado y emite controles de acción. La actualización del registro de datos, los contadores y demás recursos corresponde a lógica diferenciada que consume esos controles. Para el receptor, la FSM ordena capturar un bit cuando corresponde muestrearlo; el registro de recepción realiza la captura en el flanco autorizado. Estar en DATA no basta para capturar en todos los clocks.
3. El estado actual permanece registrado en el flanco de clk; calcular next_state combinacionalmente sigue siendo correcto. La separación entre decisión y acción no exige un ciclo adicional: un control combinacional puede ser consumido por el registro en el flanco correspondiente.
4. La separación es funcional y debe verse en el diseño y en su futura realización. No exige por sí sola un archivo o módulo HDL independiente para cada FSM, contador o registro. Puertos, controles concretos, agrupación y codificación interna se definirán al diseñar los bloques.

**Consecuencias y alcance pendiente:** Se conocen las correcciones docentes que estaban pendientes de consultar al usuario. Falta aplicarlas al diseño del receptor, transmisor y lógica privada relacionada con UART, especificando estado, condiciones, controles y recursos receptores de cada acción. No cambia el protocolo, la FSM global CPU ni los contratos de clock/reset. Se trabaja únicamente en documentación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-003`, `REQ-UART-004`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la información pendiente sobre las correcciones del TP2; no aprueba todavía los puertos o FSM concretos del TP3.

### Acuerdo parcial de DEC-SYS-007 — Organización del receptor UART

**Estado del acuerdo:** Organización aprobada como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Receptor.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** El usuario acepta la organización propuesta a partir del receptor del TP2 y continuar con la definición de sus estados. La separación debe hacer explícitas las señales mediante las cuales la FSM ordena las acciones, conforme a las correcciones docentes registradas.

**Decisión:** El receptor diferencia cuatro partes funcionales: RX Control, Sample Counter, Bit Counter y RX Shift Register. RX Control conserva el estado registrado y calcula las transiciones y los controles de acción. Los contadores actualizan sus valores mediante órdenes de limpieza e incremento; el registro de desplazamiento incorpora la muestra recibida cuando el control habilita la captura, identificada como data_shift_enable.

Los controles se consumen en el flanco del clock funcional común, sin un ciclo adicional por la separación. La entrada serie sincronizada alimenta al control y al registro de recepción; los contadores aportan las condiciones de avance. El byte completo se entrega a la FIFO RX mediante el evento de recepción válida. La separación funcional no obliga a crear un módulo HDL por recurso.

**Justificación:** Los recursos existentes en el TP2 cubren la recepción 8N1 y permiten aplicar la corrección docente haciendo visible qué bloque decide una acción y qué recurso la realiza.

**Consecuencias y alcance pendiente:** La organización se desarrolla en [Receptor UART](architecture/uart_rx.md). La propuesta de estados y acciones se revisa en el paso siguiente y no queda aprobada por este acuerdo. Permanecen pendientes la codificación interna, los indicadores de actividad RX y recepción en curso y la integración del subsistema UART. El trabajo continúa únicamente en diseño.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aplica al receptor el criterio de separación entre control y acciones del acuerdo anterior; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Estados y agrupación del receptor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Receptor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar la división en módulos del TP2, con contadores y registro de recepción dentro del receptor, y los cinco estados de su FSM. La adaptación aplica las correcciones docentes sobre casez y señales de acción, manteniendo el comportamiento de recepción existente.

**Decisión:** Se conserva uart_rx como módulo receptor. RX Control, Sample Counter, Bit Counter y RX Shift Register son partes funcionales internas, con lógica diferenciada de control y actualización; los contadores y el registro de recepción no se convierten en módulos nuevos. Se mantiene la división en módulos del TP2 como referencia para el subsistema UART, con las adaptaciones necesarias al clock y a los contratos del TP3.

La FSM conserva IDLE, START, DATA, STOP y RECOVER. IDLE espera un posible comienzo de trama; START comprueba el nivel bajo después de ocho ticks de sobremuestreo; DATA ordena las ocho capturas separadas por dieciséis ticks; STOP comprueba el nivel alto dieciséis ticks después de D7 y anuncia el byte válido; RECOVER espera el retorno de la línea a alto después de un error. Se conserva el reporte de Start falso o Stop inválido y la entrega del byte solo con Stop válido.

Las transiciones y eventos mantienen el comportamiento del TP2, expresado mediante controles explícitos sobre los recursos. Las capturas, los incrementos, las limpiezas y el cambio de estado pueden ocurrir en el mismo flanco. La [tabla de estados y acciones](architecture/uart_rx.md#estados-y-transiciones) documenta las condiciones correspondientes. La recuperación de trama en RECOVER no reemplaza la recuperación por silencio de 100 ms del protocolo.

**Justificación:** Los estados existentes cubren las fases de la trama 8N1 y el retorno al reposo tras un error. Las correcciones docentes requieren reorganizar el control y las acciones, sin introducir nuevas fases de recepción ni módulos para cada recurso.

**Consecuencias y alcance pendiente:** Quedan conservados los estados y el comportamiento de recepción de referencia. Permanecen pendientes la codificación interna, los indicadores de actividad RX y recepción en curso y el diseño de los demás bloques e integración UART. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-002`, `REQ-UART-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa los estados y la agrupación pendientes del acuerdo de organización del receptor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Indicadores de recepción UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Observación de recepción y recuperación del protocolo.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta las condiciones propuestas para rx_receiving y rx_activity después de aclarar que las consume el control del protocolo dentro de la FPGA. Ese control interpreta los servicios del TP3 y realiza la recuperación por silencio; su responsabilidad difiere de la recepción de operandos del controlador del TP2.

**Decisión:** uart_rx genera dos indicadores de un bit. Fuera de reset, rx_receiving vale uno si el estado actual es START, DATA o STOP. rx_activity vale uno si la línea sincronizada cambia de nivel, permanece baja o rx_receiving está activo. No depende de que la trama produzca un byte válido; una línea baja en RECOVER también mantiene actividad.

La generación es combinacional, sin una etapa adicional en las salidas. Para detectar cambios se conserva un registro auxiliar de un bit con el nivel sincronizado anterior, actualizado en cada flanco del clock funcional e inicializado en uno. Durante reset ambos indicadores externos valen cero. La lógica auxiliar permanece dentro del receptor y no agrega estados ni módulos HDL independientes.

La integración UART expone los indicadores al control del protocolo. Durante recuperación, ese control reinicia la cuenta de silencio en cada flanco con rx_activity activo y permite avanzar cuando cesa. Al cumplir los 100 ms comprueba ausencia de actividad, línea en reposo, ningún byte en curso y FIFO RX vacía antes de admitir solicitudes. La actividad prevalece si coincide con el final de la cuenta. Se mantiene el contrato de [descarte y silencio](protocol.md#descarte-y-silencio).

**Justificación:** Observar solo bytes válidos no permite detectar una trama parcial, un error o una línea baja sostenida. Las condiciones aprobadas permiten al consumidor distinguir silencio efectivo de recepción activa manteniendo los estados existentes del TP2.

**Consecuencias y alcance pendiente:** Los indicadores y los [puertos del receptor](architecture/uart_rx.md#frontera-de-uart_rx) quedan documentados. Faltan la codificación interna de estados, el recorrido de las señales en la integración UART y la organización interna del control del protocolo, además del diseño de los demás bloques UART. El trabajo continúa únicamente en diseño.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa los indicadores pendientes de los acuerdos del receptor; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Codificación one-hot del receptor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Codificación privada del receptor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar la codificación one-hot utilizada por el receptor del TP2, después de definir sus cinco estados y los indicadores requeridos por el control del protocolo.

**Decisión:** El registro de estado del receptor tiene cinco bits. Los valores legales son IDLE=00001, START=00010, DATA=00100, STOP=01000 y RECOVER=10000. El reset lleva a IDLE. El siguiente estado se calcula combinacionalmente y se registra al flanco ascendente del clock funcional, conforme a los controles y transiciones ya documentados.

La codificación pertenece a la FSM privada de uart_rx. Se mantienen el comportamiento de recepción, las señales de acción y los indicadores aprobados. La representación externa de global_state y los mensajes del protocolo conservan sus contratos.

**Justificación:** Mantener la codificación del TP2 permite reconocer directamente cada fase de recepción en simulación y reutilizar la referencia de diseño al aplicar las correcciones docentes.

**Consecuencias y alcance pendiente:** La [tabla de codificación](architecture/uart_rx.md#codificación-del-estado) completa este detalle del receptor. El trabajo continúa con el transmisor, el generador de ticks, las FIFO y la integración UART, además del control del protocolo. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-010`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la codificación interna pendiente de los acuerdos del receptor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Organización del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Transmisor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar uart_tx del TP2 como módulo, manteniendo su FSM, los dos contadores, el registro del byte y el registro de salida, y aplicar la misma separación entre control y acciones adoptada para el receptor.

**Decisión:** El transmisor diferencia TX Control, Sample Counter, Bit Counter, TX Shift Register y TX Output Register como partes funcionales internas de uart_tx. La FSM calcula el siguiente estado y emite controles; la lógica de cada contador y registro realiza las actualizaciones al flanco del clock funcional común.

Se conservan el contador de duración de cuatro bits, el contador de datos de tres, el registro del byte de ocho y el registro de salida de un bit para la configuración 8N1 con factor 16. El registro del byte permite capturar el dato a transmitir; el registro de salida conserva el nivel de TX entre actualizaciones. La preparación del valor de salida pertenece al camino de datos, bajo selección de la FSM. La separación no exige módulos nuevos ni un ciclo adicional entre orden y acción.

**Justificación:** Los recursos del TP2 cubren la transmisión de un byte y permiten aplicar las correcciones docentes haciendo explícitas las órdenes sobre los registros y contadores. La salida registrada conserva la organización existente del nivel serie.

**Consecuencias y alcance pendiente:** La [arquitectura del transmisor](architecture/uart_tx.md) documenta la organización y propone controles para su desarrollo. Permanecen pendientes estados, transiciones, codificación, selector, puertos y temporización de eventos, además del diseño de los demás bloques e integración UART. El fin físico de Stop debe respetar el protocolo aprobado. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Aplica al transmisor el criterio de separación entre control y acciones y complementa el diseño del receptor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Estados del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Transmisión de trama y finalización física.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar IDLE, START, DATA y STOP del TP2 y anunciar la finalización mediante tx_done_tick después de completar todo el Stop. Las acciones se realizan mediante las órdenes de la FSM a los recursos ya definidos.

**Decisión:** IDLE conserva la línea alta y acepta el byte cuando tx_start está activo. En el flanco de aceptación se carga el registro del byte, se inicializan los contadores, se registra cero en TX y se pasa a START. START cuenta dieciséis ticks y luego presenta D0. DATA conserva cada bit durante dieciséis intervalos de tick y realiza siete transiciones de D0 a D7, ordenando el desplazamiento, el incremento de índice y la escritura del bit siguiente en el mismo flanco. Al terminar D7 se registra uno en TX y se pasa a STOP.

STOP conserva el nivel alto durante dieciséis intervalos completos de tick. tx_done_tick es un evento combinacional consumido una vez en el flanco que termina ese intervalo y devuelve la FSM a IDLE. tx_busy informa START, DATA y STOP. El reset lleva a IDLE, inicializa recursos y salida alta y suprime los indicadores de envío. La [descripción y tabla de acciones](architecture/uart_tx.md#estados-y-transiciones) documentan las condiciones y el uso de los datos previos al flanco, conservando el comportamiento del TP2.

El evento de finalización corresponde al fin físico del byte, incluido todo el Stop, según el [protocolo](protocol.md). La integración debe llevarlo al control del protocolo para coordinar los hitos que requieren una respuesta ya transmitida. Encolar el byte o comenzar su Stop no equivale a esa finalización.

**Justificación:** Los cuatro estados del TP2 cubren el envío 8N1. La separación entre control y acciones mantiene las fases existentes y hace explícita la relación entre actualizaciones del registro del byte, del pin y de los contadores. Completar Stop respeta los presupuestos y exclusiones aprobados del protocolo.

**Consecuencias y alcance pendiente:** Se concretan estados, transiciones, controles y temporización de eventos. Permanecen pendientes la codificación privada, la codificación del selector y los puertos e integración, además del diseño de los demás bloques UART. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa los estados y acciones pendientes del acuerdo de organización del transmisor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Codificación one-hot del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Codificación privada del transmisor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar los cuatro códigos one-hot del transmisor del TP2, luego de definir sus estados, transiciones y evento de finalización física.

**Decisión:** El registro de estado del transmisor tiene cuatro bits. Los valores legales son IDLE=0001, START=0010, DATA=0100 y STOP=1000. El reset lleva a IDLE. El siguiente estado se calcula combinacionalmente y se registra al flanco ascendente del clock funcional, conforme a los controles y transiciones ya documentados.

La codificación pertenece a la FSM privada de uart_tx. Se conservan el comportamiento de transmisión y los eventos aprobados; la representación externa de global_state y los mensajes del protocolo mantienen sus contratos.

**Justificación:** Mantener la codificación del TP2 permite reconocer directamente cada fase de transmisión en simulación y reutilizar la referencia existente al aplicar las correcciones docentes.

**Consecuencias y alcance pendiente:** La [tabla de codificación](architecture/uart_tx.md#codificación-del-estado) completa este detalle del transmisor. Permanecen pendientes la codificación del selector de salida, la frontera de puertos y la integración, además de los demás bloques UART y del control del protocolo. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la codificación privada pendiente del acuerdo de estados del transmisor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Selector de salida del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Selección del dato de salida.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta la propuesta de selector de dos bits mediante el cual la FSM elige el valor que debe registrar la salida TX, con un enable separado para autorizar su captura.

**Decisión:** tx_output_select[1:0] utiliza HIGH=00, LOW=01, CURRENT_BIT=10 y NEXT_BIT=11. HIGH prepara uno para reposo y Stop; LOW prepara cero para Start; CURRENT_BIT selecciona data_reg[0] para comenzar D0; NEXT_BIT selecciona data_reg[1] previo al flanco para comenzar D1 a D7 mientras se desplaza el registro del byte.

El selector controla la lógica combinacional de entrada del registro de salida. tx_write_enable autoriza la captura al flanco del clock funcional. Sin ese enable, el registro conserva su nivel. Ambos controles permanecen dentro de uart_tx; la FSM indica qué valor corresponde y la lógica del recurso realiza la selección y la actualización.

**Justificación:** Las cuatro alternativas cubren los niveles de Start, Stop y reposo y el recorrido de los bits de datos del TP2. Distinguir selección y captura hace explícita la separación entre control y acciones y conserva el uso de los datos previos al flanco.

**Consecuencias y alcance pendiente:** La [tabla de selección](architecture/uart_tx.md#selección-del-nivel-de-salida) completa la codificación de este control. La frontera de puertos se presenta para aprobación y su conexión se completará en la integración UART, junto con los demás bloques pendientes. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa el selector pendiente del diseño del transmisor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Puertos del transmisor UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Frontera del módulo transmisor.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar los puertos de uart_tx del TP2, después de definir sus recursos, FSM, controles de acción y selector de salida.

**Decisión:** uart_tx recibe clk, reset, tx_start y s_tick de un bit, y data_in de ocho bits. Produce tx, tx_busy y tx_done_tick de un bit. clk y reset pertenecen al dominio funcional común; s_tick es el pulso de sobremuestreo compartido. La integración UART aporta la solicitud de envío y el byte de la FIFO TX y consume la ocupación y la finalización física. tx alimenta la línea serial_tx mediante la integración.

El byte se captura al flanco que acepta tx_start estando en IDLE. La integración presenta data_in estable para ese flanco. La transmisión posterior utiliza el registro interno del byte; los controles de captura, desplazamiento, contadores y selección de salida permanecen dentro del módulo. tx_done_tick se consume al flanco final del Stop completo, según el acuerdo de estados.

**Justificación:** La interfaz existente del TP2 cubre la entrega de un byte, la solicitud de inicio, la salida serie y los avisos de ocupación y finalización. La separación interna entre control y acciones se realiza conservando esa frontera.

**Consecuencias y alcance pendiente:** La [frontera de puertos](architecture/uart_tx.md#frontera-de-uart_tx) completa este detalle del transmisor. El siguiente bloque a diseñar es el generador de ticks compartido. La coordinación de las FIFO, la exposición de los eventos al control del protocolo y el diseño de ese control siguen pendientes. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-005`, `REQ-UART-009`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la frontera de puertos pendiente del diseño del transmisor; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Generador de ticks UART

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Referencia temporal compartida.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar el generador del TP2 adaptado a 50 MHz, con un pulso de un clock cada 163 clocks y un contador de ocho bits que recorre de cero a 162.

**Decisión:** Se conserva baud_tick_gen con el cálculo de divisor entero redondeado al valor más cercano. Para CLK_FREQ_HZ=50.000.000, BAUD_RATE=19.200 y OVERSAMPLE=16, la frecuencia nominal de ticks es 307.200 Hz, el divisor ideal es 162,760416… y el entero seleccionado es 163. La cuenta y la salida registrada mantienen el comportamiento del TP2: el contador vuelve a cero al llegar a 162 y s_tick vale uno durante un clock; los demás flancos incrementan la cuenta y registran cero en s_tick.

Una única instancia alimenta a RX y TX. Ambos consumen el pulso en el flanco siguiente a su generación, dentro del mismo dominio funcional, y usan clk para registrar sus recursos. El generador permanece activo entre tramas y durante HOLD de CPU. El reset funcional pone contador y salida en cero; se conservan los puertos clk, reset y s_tick, todos de un bit.

El baud efectivo es aproximadamente 19.171,78, con error relativo de −0,147 % respecto del nominal. El protocolo, la configuración de PC y sus presupuestos conservan 19200 baud nominales y los márgenes ya aprobados.

**Justificación:** El redondeo existente del TP2 produce el divisor entero más próximo a la frecuencia objetivo y permite reutilizar el generador con la frecuencia funcional aprobada para el TP3. Compartir la referencia conserva la organización UART existente.

**Consecuencias y alcance pendiente:** La [arquitectura del generador](architecture/uart_baud_tick_gen.md) concreta la cuenta, el pulso, su consumo y la frontera del bloque. El diseño continúa con las FIFO y la integración UART y del control del protocolo. La plataforma física y la validación del enlace en simulación y FPGA siguen pendientes. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-009`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Completa la realización del generador pendiente de la configuración física UART; no cierra DEC-SYS-007 ni cambia el baud nominal del protocolo.

### Acuerdo parcial de DEC-SYS-007 — Funcionamiento de las FIFO UART

**Estado del acuerdo:** Aprobado como base de diseño. Suficiencia condicionada al contrato de consumo; DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Almacenamiento temporal de bytes.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta continuar con las FIFO del TP2 y mantener cuatro lugares por sentido después de revisar el fundamento de su capacidad. Se distingue la reutilización con margen de la demostración pendiente de las latencias del controlador del TP3.

**Decisión:** Se conserva el módulo fifo con dos instancias independientes, RX y TX, cada una de cuatro entradas de ocho bits. Cada instancia mantiene punteros de lectura y escritura de dos bits y ocupación de tres bits. wr escribe al flanco si existe espacio; read_data presenta el byte más antiguo, válido con empty en cero, y rd lo retira al flanco si hay datos. empty y full derivan de la ocupación. Se conservan las reglas de aceptación del TP2 usando flags previos al flanco; cuando ambas operaciones se aceptan, ambas ocurren y la ocupación permanece igual.

El reset pone ambos punteros y la ocupación en cero y suprime operaciones de ese flanco. Se conservan los puertos clk, reset, rd, wr, write_data, read_data, empty y full, con ancho de datos de ocho bits y un bit en las demás señales. Los productores y consumidores de RX y TX se concretarán en la integración UART.

La profundidad de cuatro bytes se mantiene como capacidad de referencia y margen, bajo el contrato ya aprobado de retirar y procesar cada byte de LOAD antes del siguiente, incluida la escritura IMEM. TX se produce progresivamente; esperar espacio conserva el byte pendiente y permite continuar con RX. Antes de implementar el control del protocolo se demostrará documentalmente la latencia máxima de consumo y la continuidad de recepción o descarte durante espera TX; después se verificarán en simulación.

**Justificación:** A 19200 baud nominales y 8N1 existe aproximadamente un intervalo de 0,520833 ms, unos 26.042 clocks de 50 MHz, entre bytes completos. Cumplir el contrato evita acumulación sostenida de RX, mientras un registro externo reúne los bytes de cada instrucción. TX no exige almacenar la respuesta completa. Cuatro no se presenta como un mínimo derivado de latencias todavía desconocidas.

**Consecuencias y alcance pendiente:** La [arquitectura de las FIFO](architecture/uart_fifo.md) concreta recursos, operaciones, flags, reset y puertos. La [comprobación de suficiencia](architecture/uart_fifo.md#fundamento-de-la-capacidad-y-comprobación-pendiente) queda como condición pendiente antes de implementar el controlador. El siguiente paso es la conexión de RX y TX en la integración UART. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta el funcionamiento de las FIFO del acuerdo de buffers y explicita la demostración pendiente del contrato de consumo; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Conexiones internas de uart_core

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Integración de caminos de bytes.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar las conexiones del TP2 dentro de uart_core: guardar cada byte RX válido, retirarlo desde el control del protocolo, introducir las respuestas en TX, comenzar cuando haya un byte pendiente y el transmisor esté libre, y retirar el byte TX al completar Stop.

**Decisión:** uart_core conserva la integración de serial_input_sync, baud_tick_gen, uart_rx, uart_tx y dos instancias fifo. El sincronizador alimenta la entrada RX y un único generador aporta el tick compartido. Los parámetros comunes se adaptan al dominio funcional de 50 MHz y a la configuración UART y profundidades aprobadas.

En RX, rx_done_tick solicita la escritura de received_data en la FIFO; el control del protocolo observa r_data y rx_empty y genera rd_uart para consumir o descartar. En TX, el control entrega w_data y wr_uart con espacio disponible, conservando el byte pendiente cuando tx_full está activo. El primer byte de FIFO alimenta uart_tx.data_in; fuera de reset, tx_start se activa cuando tx_empty y tx_busy valen cero. Durante reset se suprime el comienzo.

El byte TX permanece en la FIFO durante su transmisión. tx_done_tick solicita su retiro en el mismo flanco que completa Stop y devuelve el transmisor a IDLE. Después del flanco se presenta el nuevo primer byte y, si existe, se solicita el siguiente envío. La [arquitectura de integración](architecture/uart_core.md) documenta las conexiones y sus relaciones temporales.

La interpretación de comandos, el descarte por fase y la coordinación de respuestas corresponden al control del protocolo. Los caminos físicos RX y TX continúan independientes y no dependen de la autorización de ciclos CPU.

**Justificación:** La conexión del TP2 conserva el orden de los bytes y relaciona el retiro TX con la finalización física requerida por el protocolo. Separar las solicitudes de los dos caminos permite que el futuro controlador conserve la continuidad RX durante espera TX.

**Consecuencias y alcance pendiente:** Las conexiones de datos y solicitudes quedan definidas. La frontera ampliada con indicadores RX y fin TX y el reporte de error combinado permanecen como propuesta pendiente de aprobación. La FSM del control del protocolo, el seguimiento de respuestas y la demostración del presupuesto de consumo continúan pendientes. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la conexión de los bloques UART del TP2 con los recursos y contratos definidos para TP3; no cierra DEC-SYS-007.

### Acuerdo parcial de DEC-SYS-007 — Puertos y reporte de errores de uart_core

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Frontera con el control del protocolo.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta conservar los puertos del TP2, exponer los indicadores de actividad y recepción y el evento de fin físico TX, y mantener un único reporte para error de trama o desbordamiento RX.

**Decisión:** uart_core conserva las entradas clk, reset, serial_rx, rd_uart, w_data y wr_uart y las salidas serial_tx, r_data, rx_empty, tx_full y rx_error_tick. Agrega las salidas rx_activity, rx_receiving y tx_done_tick. w_data y r_data tienen ocho bits; las demás señales tienen uno. La frontera consta de seis entradas y ocho salidas.

Los dos indicadores RX y el evento de fin TX llegan directamente desde uart_rx y uart_tx al control del protocolo, sin registro adicional en uart_core. Conservan sus condiciones y flancos de consumo. El evento TX permite identificar el final físico de las respuestas siguiendo sus bytes en orden; la realización de ese seguimiento permanece pendiente.

rx_error_tick se activa ante frame_error_tick o ante rx_done_tick con rx_full previo al flanco. Se consume en el flanco correspondiente y vale cero durante reset. El reporte no distingue externamente entre error de trama y desbordamiento ni se repite por mantener RX llena. rx_full, rx_done_tick, tx_empty y tx_busy permanecen internos a uart_core.

**Justificación:** Los puertos del TP2 permiten intercambiar bytes y conocer la disponibilidad de las FIFO. Las tres salidas adicionales aportan la información ya requerida para recuperación por silencio, recepción en curso y finalización física de aceptación y Debug. El reporte combinado cubre las causas UART que el protocolo trata mediante la política de recuperación aprobada.

**Consecuencias y alcance pendiente:** La [frontera](architecture/uart_core.md#frontera-de-uart_core) y el [reporte de errores](architecture/uart_core.md#reporte-de-errores) quedan definidos, junto con las conexiones internas aprobadas previamente. Continúan pendientes la organización y FSM privadas del control del protocolo, sus puertos hacia los servicios, la serialización y seguimiento de respuestas y la demostración de latencia y continuidad RX durante espera TX. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-001`, `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Resuelve la propuesta de frontera ampliada y reporte combinado del acuerdo de conexiones internas de uart_core; no cierra DEC-SYS-007 ni modifica los formatos del protocolo.

### Acuerdo parcial de DEC-SYS-007 — Organización funcional del control del protocolo

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Interpretación de operaciones y coordinación de respuestas.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta distinguir control del protocolo, registros y contadores, y generación de respuestas antes de definir la agrupación en módulos, sus puertos y estados.

**Decisión:** El control interpreta las solicitudes y determina cuándo consumir o descartar RX, coordinando LOAD, RUN, STEP, RESET y CHECK_READY con los bloques correspondientes. Los registros y contadores conservan código, tamaño, progreso y tiempos de espera, y se actualizan mediante las señales de acción emitidas por la FSM. La generación de respuestas forma cabeceras y serializa Debug, conserva el byte pendiente durante TX llena y sigue la finalización física de las respuestas.

El Loader conserva la reconstrucción de words y la escritura IMEM. La FSM global CPU conserva el control de ejecución. La fase del transporte, los recursos privados del protocolo y la generación de respuestas permanecen activos en el dominio funcional común durante HOLD de CPU. La espera por TX no bloquea el consumo o descarte RX que corresponda a la fase.

Esta separación es funcional. No fija un módulo por responsabilidad, un módulo por registro, nombres de puertos ni una única FSM para todos los servicios.

**Justificación:** Distinguir interpretación, recursos y respuestas aplica la separación entre control y acciones indicada por el profesor y permite concretar el protocolo sin mezclar las responsabilidades del transporte, Loader y ejecución CPU.

**Consecuencias y alcance pendiente:** La [organización funcional](architecture/protocol_controller.md) registra las responsabilidades y su relación con los bloques existentes. Quedan pendientes la agrupación en módulos, las fronteras y recursos concretos, las FSM privadas, la coordinación de respuestas y reset y la demostración de las latencias de consumo. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-001`, `REQ-DBG-002`, `REQ-DBG-003`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la separación funcional del control pendiente después de definir uart_core; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Módulos del control del protocolo y respuestas

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Agrupación del control y serialización.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta agrupar las responsabilidades funcionales en protocol_controller y response_serializer, cada uno con sus controles y recursos internos, antes de definir la comunicación entre ambos.

**Decisión:** protocol_controller interpreta solicitudes, consume o descarta RX y coordina las operaciones con Loader y control de ejecución. Contiene su FSM, registros y contadores. response_serializer forma las cabeceras, recorre la información Debug y entrega los bytes a TX. Contiene los controles, registros y contadores necesarios para recorrer el mensaje y seguir su transmisión física.

El controlador indica qué respuesta enviar y el serializador comunica cuándo termina físicamente el último byte, incluido Stop. Durante espera por espacio TX, protocol_controller conserva el consumo o descarte RX de la fase. Los recursos se actualizan mediante señales de acción de sus controles respectivos; no se exige un módulo adicional por registro o contador.

El consumo RX y los indicadores de recepción corresponden al controlador. La producción TX, tx_full y tx_done_tick corresponden al serializador. Loader conserva la reconstrucción de instrucciones y escritura IMEM, y la FSM global CPU conserva ejecución. La ocupación TX no equivale por sí misma a HOLD de CPU.

**Justificación:** La agrupación permite atender RX mientras se produce una respuesta y concentra el recorrido y envío de Debug en un módulo específico. Mantiene la separación docente entre control y acciones sin mezclar el transporte con las responsabilidades de carga y ejecución.

**Consecuencias y alcance pendiente:** La [agrupación](architecture/protocol_controller.md#agrupación-en-módulos) y la [responsabilidad del serializador](architecture/response_serializer.md) quedan aprobadas. La comunicación de solicitud y finalización se presenta como propuesta pendiente; las demás fronteras, FSM privadas, recursos, coordinación de pendientes y demostración del presupuesto de consumo continúan abiertos. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-001`, `REQ-DBG-002`, `REQ-DBG-003`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la agrupación pendiente del acuerdo de organización funcional del control del protocolo; no cierra DEC-SYS-007 ni modifica los formatos del protocolo.

### Acuerdo parcial de DEC-SYS-007 — Solicitud y finalización de respuestas

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Comunicación entre controlador y serializador.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta solicitar una respuesta completa mediante código, resultado y selección de Debug, capturados por el serializador, y recibir ocupación y fin físico de la respuesta.

**Decisión:** protocol_controller presenta response_opcode[7:0], response_result[7:0] y response_with_debug y activa response_start durante un clock cuando response_serializer está libre. Fuera de reset, la solicitud se acepta al flanco con response_busy en cero. Los tres campos están estables para ese flanco y se capturan en registros internos del serializador; sus cambios posteriores en el controlador no alteran la respuesta en curso.

response_with_debug selecciona el cuerpo después de los dos bytes de cabecera para STEP realizado y RUN terminal. Las demás respuestas se limitan a la cabecera, incluidos rechazos y RUN / ACCEPTED. Las señales son internas y no agregan campos al enlace UART.

response_busy permanece activo desde la aceptación hasta el fin físico del último byte, incluidas producción, espera por espacio TX y salida de los bytes encolados. response_done_tick comunica una única finalización durante un clock y se consume en el flanco que completa el último Stop, con la misma referencia temporal de tx_done_tick. Después del flanco el serializador queda libre para una solicitud posterior. Durante reset se suprimen aceptación y finalización y se desactiva ocupación; un envío abortado por reset no se informa como terminado normalmente.

El serializador atiende una respuesta por vez. Los pendientes y el orden entre respuestas corresponden al controlador; no se agrega una cola de respuestas al serializador. El consumo o descarte RX continúa durante espera TX.

**Justificación:** Capturar la descripción evita depender de cambios posteriores en el controlador. Distinguir respuesta en curso y fin físico permite iniciar el timeout LOAD, aplicar RESET o liberar la exclusión Debug en el hito ya aprobado, sin confundir escritura en FIFO con transmisión completa.

**Consecuencias y alcance pendiente:** La [frontera y secuencia](architecture/response_serializer.md#comunicación-con-el-controlador) quedan aprobadas. Permanecen pendientes los recursos y controles internos, la identificación del último byte físicamente transmitido, la frontera y recorrido Debug, la coordinación de pendientes y reset y la demostración del presupuesto de consumo. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-009`, `REQ-UART-010`, `REQ-UART-011`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Resuelve la propuesta de comunicación pendiente del acuerdo de módulos del control del protocolo y respuestas; no cierra DEC-SYS-007 ni modifica el protocolo.

### Acuerdo parcial de DEC-SYS-007 — Organización interna del serializador

**Estado del acuerdo:** Aprobado como base de diseño. DEC-SYS-007 continúa pendiente.

**Dominio:** UART / Recursos de producción y seguimiento de respuestas.

**Fecha de aprobación:** 2026-10-02.

**Contexto:** El usuario acepta cinco grupos dentro de response_serializer para conservar la descripción, producir el próximo byte, recorrer el mensaje y reconocer su final físico, mediante una FSM separada de las actualizaciones de recursos.

**Decisión:** response_serializer contiene FSM de control, registro de descripción de 17 bits, registro del próximo byte de ocho bits con indicador de disponibilidad, recursos de recorrido y seguimiento de transmisión. El descriptor conserva código, resultado y selección de Debug. Los recursos de recorrido identifican sección, campo y byte; sus índices y anchos se definirán al concretar la secuencia.

El seguimiento contiene un contador de tres bits que recorre cero a cuatro bytes TX pendientes y un indicador de producción completa de un bit. La cuenta incluye el byte en transmisión, que permanece en la FIFO hasta terminar Stop, y excluye el próximo byte todavía no encolado. Aumenta con escritura TX aceptada y disminuye con fin físico; eventos simultáneos conservan la cuenta. Se inicia en cero con reset o nueva respuesta. La cota proviene de la FIFO TX de cuatro entradas, del único productor y de comenzar cada respuesta después del fin físico de la anterior.

La producción queda completa cuando el último byte se incorpora a TX. La condición de fin físico utiliza respuesta en curso, producción completa, un byte pendiente y tx_done_tick previo al flanco. El contador vacío mientras aún se producen bytes no finaliza la respuesta. La FSM emite las señales de acción y cada recurso realiza sus actualizaciones al flanco funcional.

**Justificación:** La organización permite producir el mensaje progresivamente y conservar el byte durante espera TX. Separar posición, producción completa y bytes pendientes evita confundir el último byte generado con su salida física y fundamenta el ancho del contador en la conexión de la FIFO aprobada.

**Consecuencias y alcance pendiente:** La [organización interna](architecture/response_serializer.md#organización-interna) y el [seguimiento](architecture/response_serializer.md#seguimiento-de-transmisión) concretan estos grupos. Siguen pendientes el recorrido, sus recursos e índices, los controles y estados de FSM, la frontera de lectura Debug y la coordinación del controlador. La demostración del presupuesto de consumo continúa pendiente. No se inicia implementación.

**Requisitos relacionados:** `REQ-UART-009`, `REQ-UART-011`, `REQ-DBG-005` a `REQ-DBG-010`, `REQ-DBG-015`, `REQ-DOC-001`.

**Reemplaza / Reemplazada por:** Concreta la organización interna del serializador pendiente después de definir la solicitud y finalización de respuestas; no cierra DEC-SYS-007 ni modifica los formatos del protocolo.
