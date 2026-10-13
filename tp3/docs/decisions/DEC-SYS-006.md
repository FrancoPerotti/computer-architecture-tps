### DEC-SYS-006 — Información observable mediante Debug

**Contrato vigente de consulta:** [debug_architecture](../architecture/debug/debug_architecture.md), [cpu_pipeline](../architecture/cpu/cpu_pipeline.md), [response_serializer](../architecture/debug/response_serializer.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Sistema / Debug

**Fecha de aprobación:** 2026-09-20

**Contexto:** La consigna requiere una unidad de Debug capaz de permitir la observación del estado del procesador desde el software de PC, incluyendo como mínimo el banco de registros, los registros interetapa del pipeline y la memoria de datos utilizada.

Para que esta observabilidad sea útil tanto durante el desarrollo como durante la ejecución paso a paso, es necesario definir qué información constituye el estado observable del sistema antes de establecer el formato concreto del protocolo UART o la representación exacta de los registros interetapa.

La Debug Unit debe proporcionar suficiente información para reconstruir e interpretar el estado del pipeline en un ciclo determinado, sin convertirse en una exposición indiscriminada de todas las señales combinacionales internas del procesador.

La decisión debe mantener una separación clara entre:

- el **estado que conceptualmente debe ser observable**;
- la **representación física de dicho estado dentro del procesador**;
- el **formato utilizado para transportarlo por UART**;
- la **forma en que el software de PC lo presenta al usuario**.

**Opciones consideradas:**

1. Exponer únicamente la información mínima explícitamente exigida por la consigna: banco de registros, memoria de datos utilizada y una identificación básica de las instrucciones presentes en el pipeline.
2. Exponer para cada etapa únicamente `instruction`, `PC` y una indicación de validez.
3. Exponer de manera indiscriminada el contenido completo de todos los registros interetapa y numerosas señales internas del datapath y control.
4. Exponer el estado arquitectónico completo y una representación semánticamente suficiente del estado registrado del pipeline, incluyendo información adicional de contexto, pero excluyendo por defecto las señales puramente combinacionales internas.

**Decisión:** Se adopta la opción 4.

La Debug Unit deberá permitir obtener una representación coherente del estado observable del sistema, denominada conceptualmente **snapshot de Debug**.

Cada snapshot deberá contener, como mínimo:

- un identificador del **ciclo de ejecución** al que corresponde;
- el **PC actual** del procesador;
- el **estado global de ejecución**;
- una indicación de si existe una **imagen de programa válida y ejecutable**;
- el contenido de los **32 registros arquitectónicos** `x0` a `x31`;
- el estado observable de los cuatro registros interetapa del pipeline:
  - `IF/ID`;
  - `ID/EX`;
  - `EX/MEM`;
  - `MEM/WB`;
- el subconjunto de **`Data Memory` considerado utilizado**, conforme al criterio que establezca `DEC-SYS-005`.

Para cada registro interetapa del pipeline deberá ser observable, como mínimo:

- una indicación explícita de **validez**;
- el **PC asociado a la instrucción** almacenada en dicho registro;
- la **instrucción de 32 bits** asociada;
- los demás datos y señales de control **registrados** que sean necesarios para interpretar correctamente el estado y la evolución de esa instrucción dentro del pipeline.

La lista exacta de campos adicionales de cada registro interetapa no se fija en esta decisión. Será definida por `DEC-ARCH-009` una vez establecida la estructura concreta de los registros interetapa del pipeline.

La indicación de validez deberá distinguir entre una instrucción activa y una entrada inactiva. Con `valid = 0`, los demás bits del registro interetapa no representarán una instrucción activa, aunque conserven contenido residual.

No será obligatorio que Debug distinga la causa por la que una entrada se encuentra inactiva. Una bubble, una entrada invalidada por un flush, una posición vacía durante el llenado o drenado y otras causas podrán compartir la misma representación inactiva.

El **PC global** y el **PC asociado a cada registro interetapa** son conceptos diferentes y ambos deberán poder representarse:

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

El identificador de ciclo será un contador lógico de avances efectivos del procesador dentro de la sesión actual. Comenzará en cero al preparar cada nueva sesión (por `LOAD` o por `RUN`/`STEP` desde `FINISHED`/`FAULT`) e incrementará exactamente una vez por cada ciclo habilitado de ejecución, tanto en `RUN` como en `STEP`. También contará ciclos habilitados en los que exista un stall y ciclos de drenado.

El contador no avanzará mientras el procesador espere un nuevo `STEP`, durante una carga o reprogramación ni por ciclos del clock funcional con actividad exclusiva de UART o control externo. Su ancho y overflow quedan fijados por la revisión aprobada siguiente.

#### Revisión aprobada de DEC-SYS-006 — contador lógico de 64 bits (AUD-005)

**Fecha:** 2026-09-26. **Estado:** Aprobada como revisión de esta decisión, sin nuevo identificador.

Se cierra el pendiente original de ancho y overflow: `cycle_count[63:0]` será **unsigned de 64 bits**. La referencia original que difería estos aspectos queda sustituida por esta revisión.

```text
reset o inicialización efectiva de una nueva sesión → cycle_count = 0
cpu_cycle_fire = 1 → cycle_count.next = (cycle_count + 1) mod 2^64
sin acción superior y cpu_cycle_fire = 0 → cycle_count.next = cycle_count
0xFFFFFFFFFFFFFFFF + 1 → 0x0000000000000000
```

Cuenta exactamente una vez por ciclo CPU efectivo, incluidos stalls, bubbles, redirects, confirmaciones y drenado. `HOLD` y la actividad exclusiva de Loader, UART, Debug o mantenimiento no incrementan el contador. Reset e inicialización conservan su prioridad; antes del primer ciclo de toda sesión el valor es cero y después es uno.

Conforme al acuerdo 44 de `DEC-ARCH-003`, la finalización de preparación distingue estos casos:

| Condición | Resultado en el flanco |
|---|---|
| `PREPARING_RUN/STEP && prepare_done` | La preparación ya terminó antes del flanco; ese flanco ejecuta el primer ciclo |
| `PREPARING_READY && prepare_done` | Queda en `READY` con el contador en cero |

El wrap-around **no constituye un fault**, no detiene ni altera la ejecución, no modifica `global_state`, no genera flags y no requiere estado persistente adicional. Se eligen 64 bits para que el wrap sea irrelevante en ejecuciones prácticas, sin lógica especial de saturación u overflow. El contador continúa siendo un identificador lógico observable por Debug; no es un identificador ilimitado o globalmente único entre sesiones.

El orden de bytes, framing y demás representación UART de los 64 bits permanecen pendientes en las decisiones de protocolo. Esta revisión no los fija.

#### Coherencia y representación del snapshot

Todo snapshot deberá ser **internamente coherente**: los registros, PC, registros interetapa, estado de ejecución, memoria utilizada y demás información dinámica que lo integran deberán representar un mismo estado lógico del procesador.

No deberá producirse un snapshot que combine, por ejemplo, registros correspondientes a un ciclo con registros interetapa correspondientes a otro ciclo como consecuencia del tiempo requerido para transmitir la información por UART.

El mecanismo concreto para garantizar esta coherencia —captura temporal, congelamiento, shadow registers, lectura mientras el procesador está detenido u otra estrategia equivalente— se definirá posteriormente.

Esta decisión no obliga a que los snapshots puedan solicitarse arbitrariamente mientras el procesador ejecuta en modo continuo. Los momentos en los que Debug puede capturar o transmitir información y su interacción con `RUN` y `STEP` se definirán junto con las interfaces y el protocolo.

Las capacidades configuradas de `Instruction Memory` y `Data Memory` no forman parte de la información obligatoria de Debug ni necesitan incluirse en el snapshot. Para esta decisión es suficiente que el software utilice una configuración externa coherente con el perfil sintetizado conforme a `DEC-SYS-004`. Una decisión posterior podrá permitir reportar opcionalmente capacidades o un identificador de perfil.

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
- formato interno exacto de cada registro interetapa;
- representación física de `valid`;
- representación visual en el software de PC;
- criterio exacto de `Data Memory` utilizada;
- frecuencia o momento en que se permite solicitar información durante una ejecución continua;
- mecanismo concreto por el que el software conoce el perfil de memoria sintetizado.

**Justificación:** Exponer únicamente la instrucción presente en cada etapa permite una visualización simple del pipeline, pero resulta insuficiente para diagnosticar errores en operandos, resultados de ALU, accesos a memoria, writeback o propagación de señales de control.

En el extremo opuesto, exponer indiscriminadamente todas las señales internas acoplaría excesivamente Debug a la implementación concreta del datapath y aumentaría innecesariamente el volumen de información, la complejidad del protocolo y la dependencia del software respecto del RTL.

La solución adoptada utiliza como frontera principal el **estado registrado** entre etapas. Los registros interetapa representan puntos naturales de observación porque contienen el estado persistente que una instrucción transporta de una etapa a la siguiente.

Incluir explícitamente `valid`, PC e instrucción facilita la interpretación humana del pipeline y permite distinguir correctamente instrucciones activas de entradas inactivas sin imponer metadatos adicionales sobre la causa de cada invalidación.

La observación de los demás campos registrados relevantes permite además diagnosticar errores internos sin necesidad de exponer todas las señales combinacionales del procesador.

El PC global proporciona contexto sobre el frente de búsqueda, mientras que los PCs asociados a las instrucciones permiten seguir una instrucción concreta a medida que avanza por el pipeline.

Un identificador lógico de ciclo facilita la correlación entre hardware, simulación, testbench, software de PC y las secuencias esperadas de las pruebas sin confundir el avance del procesador con la actividad del clock físico durante pausas, carga o comunicación.

Finalmente, exigir coherencia interna del snapshot evita que la lentitud relativa de UART produzca una representación que nunca haya existido realmente en el procesador.

**Consecuencias:**

- Debug deberá disponer de acceso al banco completo de registros;
- deberá disponer del PC global;
- deberá poder observar los cuatro registros interetapa del pipeline;
- cada registro interetapa deberá disponer de una noción observable de validez binaria;
- las instrucciones deberán poder asociarse con su PC mientras atraviesan el pipeline;
- los registros interetapa deberán exponer suficiente estado registrado para interpretar el procesamiento de cada instrucción;
- `DEC-ARCH-009` deberá definir exactamente qué campos forman parte de cada registro interetapa y cuáles de ellos constituyen su representación de Debug;
- la arquitectura deberá permitir construir snapshots coherentes aunque la transmisión UART sea mucho más lenta que el procesador;
- Debug deberá permitir distinguir una imagen válida de la ausencia de programa ejecutable;
- el software podrá identificar el estado global de ejecución sin inferirlo indirectamente a partir de otros datos;
- el contador lógico de ciclo comenzará en cero con cada nueva sesión y contará únicamente ciclos habilitados de ejecución;
- la memoria reportada por Debug no queda definida simplemente como toda la capacidad de `Data Memory`; dependerá de `DEC-SYS-005`;
- no se obliga a exponer todas las señales combinacionales internas;
- no se obliga a reportar capacidades de memoria ni un identificador de perfil mediante Debug;
- el protocolo posterior deberá poder representar todo el contenido aprobado por esta decisión;
- el software de PC deberá ser capaz de interpretar y presentar esta información;
- la implementación concreta del snapshot no queda fijada en esta decisión;
- la existencia del snapshot no obliga a permitir consultas arbitrarias durante `RUN`.

**Requisitos afectados:** `REQ-CPU-009` a `REQ-CPU-012`, `REQ-CPU-016`, `REQ-EXEC-007`, `REQ-EXEC-010`, `REQ-UART-005`, `REQ-DBG-004` a `REQ-DBG-010`, `REQ-DBG-012` a `REQ-DBG-016`, `REQ-SW-006` a `REQ-SW-010`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** No aplica.

---
