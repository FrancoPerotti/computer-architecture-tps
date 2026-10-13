### DEC-SYS-003 — Política general de reprogramación

**Contrato vigente de consulta:** [execution_control](../architecture/session/execution_control.md), [session_preparation](../architecture/session/session_preparation.md), [memory_architecture](../architecture/memory/memory_architecture.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Sistema / Reprogramación

**Fecha de aprobación:** 2026-09-20

**Contexto:** El sistema debe permitir cargar y ejecutar distintos programas sin volver a sintetizar la FPGA. Al comenzar una nueva programación puede existir estado residual de una ejecución anterior en el PC, banco de registros, memoria de datos, memoria de instrucciones, registros interetapa del pipeline, estado de ejecución y estructuras auxiliares de debug.

Como el trabajo práctico no requiere comunicación ni persistencia de estado entre programas distintos, conservar ese estado introduciría dependencias entre ejecuciones y dificultaría la reproducibilidad, la verificación y la depuración.

Esta decisión define el estado lógico que debe presentar el sistema cuando una reprogramación se completa correctamente. `DEC-ARCH-008` selecciona por separado el `reset` global como recuperación mínima de una ejecución no terminante y rechaza el inicio directo de `LOAD` mientras `RUN` permanece activo.

**Opciones consideradas:**

1. Conservar el estado arquitectónico y de memoria de la ejecución anterior, reemplazando únicamente la memoria de instrucciones.
2. Conservar selectivamente registros o memoria de datos para permitir persistencia entre programas.
3. Reinicializar el estado asociado a la ejecución anterior y tratar cada programa cargado como una nueva sesión independiente.
4. Dejar la política de reinicialización a criterio de cada módulo sin establecer una semántica global.

**Decisión:** Cada reprogramación completada correctamente establece una **nueva sesión de ejecución independiente** de cualquier programa ejecutado previamente.

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

La finalización correcta de la carga dejará al sistema en un estado preparado para comenzar una nueva ejecución, pero **no iniciará automáticamente `RUN` ni `STEP`**.

Desde que el sistema acepta el inicio de una nueva carga, la imagen ejecutable dejará de considerarse válida. Hasta que la carga finalice correctamente, `RUN` y `STEP` deberán rechazarse o permanecer sin efecto según el protocolo que se defina. Una carga incompleta, inválida o fallida no volverá ejecutable la imagen parcial nueva ni una mezcla de esta con instrucciones de la imagen anterior. El sistema permanecerá sin una imagen ejecutable válida hasta que una carga posterior se complete correctamente.

Esta política de fallo cerrado no exige conservar o restaurar atómicamente el programa anterior, implementar rollback ni disponer de doble almacenamiento para la memoria de instrucciones.

`DEC-ARCH-001` fija el punto de entrada en `0x00000000`. La lógica de reinicialización deberá garantizar que el PC quede preparado en ese punto.

Los mecanismos concretos utilizados para reinicializar memorias, registros, pipeline, PC y demás estructuras se definirán durante el diseño de arquitectura y microarquitectura.

Esta decisión no establece que la reprogramación sea el mecanismo obligatorio de recuperación de una ejecución no terminante. `DEC-ARCH-008` determina que `LOAD` se rechaza durante contexto continuo y que `reset` global lleva previamente al sistema a un estado controlado desde el cual puede solicitarse una nueva carga.

**Justificación:** Tratar cada programa como una nueva sesión independiente evita dependencias accidentales con ejecuciones anteriores y permite que un mismo programa, ejecutado bajo las mismas condiciones de entrada, comience desde el mismo estado observable.

Definir registros y memoria de datos con valor lógico inicial cero hace verificable la reproducibilidad sin imponer una estrategia física de limpieza. Del mismo modo, invalidar toda dirección que no pertenezca a la nueva imagen evita que un programa más corto ejecute accidentalmente instrucciones residuales de una imagen anterior.

La política de fallo cerrado impide ejecutar imágenes parciales o mezcladas sin exigir mecanismos costosos de rollback o doble buffer.

Esta política simplifica la comparación de los resultados esperados con la simulación y la FPGA real, reduce la cantidad de estados históricos que deben considerarse durante la depuración y evita que valores residuales en registros, memoria o pipeline oculten errores o alteren resultados.

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
- `RUN` y `STEP` continúan siendo operaciones separadas de la carga;
- desde que el sistema acepta el comienzo de `LOAD` y hasta su finalización exitosa no existe una imagen ejecutable válida;
- una carga parcial, inválida o fallida mantiene `RUN` y `STEP` rechazados o sin efecto hasta una carga válida posterior;
- no se exige rollback, conservación atómica de la imagen anterior ni doble buffer;
- no se prescribe si la limpieza se realizará mediante borrado físico, marcas de validez, generaciones u otro mecanismo equivalente;
- `DEC-ARCH-001` define el punto de entrada exacto y la semántica de posiciones de instrucciones no cargadas;
- `DEC-ARCH-008` define las condiciones de commit que exigen PC, pipeline y control en el estado inicial establecido, sin imponer una secuencia RTL concreta;
- reprogramar no es una vía implícita de aborto o recuperación durante `RUN`;
- `DEC-ARCH-008` rechaza `LOAD` mientras existe contexto continuo y selecciona `reset` global como recuperación mínima previa.

**Requisitos afectados:** `REQ-CPU-009` a `REQ-CPU-013`, `REQ-CPU-016`, `REQ-MEM-003` a `REQ-MEM-005`, `REQ-MEM-007` a `REQ-MEM-009`, `REQ-EXEC-016`, `REQ-EXEC-017`, `REQ-UART-002`, `REQ-DBG-002` a `REQ-DBG-012`, `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-011`, `REQ-DOC-002`.

**Reemplaza / Reemplazada por:** No aplica.

---
