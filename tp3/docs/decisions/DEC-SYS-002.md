### DEC-SYS-002 — Comportamiento ante ausencia de STOP/HALT

**Contrato vigente de consulta:** [faults_and_termination](../architecture/session/faults_and_termination.md), [memory_architecture](../architecture/memory/memory_architecture.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

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

**Decisión:** La única finalización normal del programa es la definida por `DEC-SYS-001`: reconocimiento de un `halt` válido perteneciente al flujo correcto seguido por el vaciado completo del pipeline.

La ausencia de `halt` no producirá autónomamente una finalización normal.

No se utilizarán como sustitutos implícitos de `halt`:

- alcanzar la última dirección cargada;
- acceder a memoria vacía;
- ejecutar `0x00000000`;
- superar una cantidad arbitraria de ciclos.

Un timeout utilizado por un testbench, una herramienta de simulación u otro entorno de prueba podrá interrumpir una prueba, pero no representará una finalización del DUT ni deberá producir la indicación normal de programa finalizado.

En modo **`RUN`**, el procesador continuará ejecutando mientras no ocurra alguna de las siguientes condiciones:

- reconocimiento de un `halt` válido;
- intervención externa;
- una condición de error definida explícitamente por una decisión posterior.

En modo **`STEP`**, cada comando continuará representando exactamente un ciclo de avance. En ausencia de nuevos comandos `STEP`, el estado de ejecución del procesador no avanzará, sin que ello implique detener o manipular el clock principal, y el programa no se considerará finalizado.

El sistema deberá disponer de al menos un mecanismo externo capaz de recuperar el control de una ejecución no terminante. El mecanismo seleccionado deberá poder invocarse mientras `RUN` esté activo y llevar el sistema a un estado controlado desde el cual pueda iniciarse el procedimiento documentado para una nueva ejecución. Podrá basarse en `reset`, reprogramación, una operación de control explícita u otro mecanismo equivalente; su forma concreta y sus efectos se definirán en decisiones posteriores.

Una intervención externa o una condición de error no equivaldrán a una finalización normal mediante `halt` y no deberán producir `program_finished` ni ningún indicador de protocolo que posteriormente se reserve para representar la finalización normal.

Los términos conceptuales `RUNNING`, `DRAINING`, `FINISHED` y, cuando resulte útil, `ABORTED` describen estados semánticos del sistema y no imponen una cantidad, codificación o estructura determinada de estados RTL.

**Justificación:** Mantener a `halt` como única causa de finalización normal proporciona una semántica inequívoca y evita que condiciones accidentales del sistema se interpreten como terminaciones válidas del programa.

Utilizar la longitud cargada, memoria vacía o una cantidad máxima de ciclos como criterio automático de finalización introduciría comportamientos que podrían ocultar errores de software o confundir programas legítimamente no terminantes con programas finalizados.

Al mismo tiempo, una ejecución continua sin `halt` no debe dejar al sistema sin posibilidad de recuperación. Por ello se exige una capacidad externa de recuperación, pero se difiere su mecanismo concreto hasta disponer de las decisiones de reprogramación, `reset` y protocolo necesarias.

La separación entre finalización normal, recuperación externa y error permitirá verificar cada situación independientemente y evitará que una condición excepcional sea reportada como si el programa hubiera ejecutado correctamente su `halt`.

**Consecuencias:**

- un programa que no alcance un `halt` válido no producirá finalización normal por sí mismo;
- alcanzar la última dirección cargada no finalizará el programa;
- acceder a memoria vacía no finalizará el programa;
- `0x00000000` no finalizará el programa;
- no existirá un límite arbitrario de ciclos como parte de la semántica normal del procesador;
- los timeouts utilizados por herramientas o testbenches serán externos al comportamiento funcional del DUT;
- en `RUN`, una ejecución no terminante continuará mientras no exista `halt`, intervención externa o una condición de error definida;
- en `STEP`, la ausencia de nuevos comandos impedirá el avance del estado de ejecución sin producir finalización normal y sin manipular el clock principal;
- el sistema deberá disponer de al menos un mecanismo externo de recuperación invocable durante `RUN`;
- `DEC-ARCH-008` selecciona posteriormente `reset` global como mecanismo mínimo y define sus efectos sobre PC, pipeline, registros, imagen y control;
- una recuperación externa no deberá emitir `program_finished` ni ningún indicador de protocolo que posteriormente se reserve para representar la finalización normal;
- una condición de error futura deberá distinguirse de la finalización normal;
- no se impone un estado RTL denominado `ABORTED`; la FSM global es la del acuerdo 44 de `DEC-ARCH-003`;
- `DEC-SYS-003` define la semántica de reprogramación sin establecer que pueda iniciarse directamente durante `RUN` ni adoptarla por sí sola como mecanismo de recuperación;
- `DEC-ARCH-008` selecciona el `reset` global como vía mínima concreta de recuperación invocable durante `RUN`;
- `DEC-PROTO-002` deberá decidir si la recuperación se expondrá como una operación UART;
- `DEC-ARCH-001` define el tratamiento de accesos fuera de rango y `DEC-ARCH-004` deberá definir por separado el de instrucciones inválidas y desalineación.

**Requisitos afectados:** `REQ-EXEC-005`, `REQ-EXEC-006`, `REQ-EXEC-008`, `REQ-EXEC-009`, `REQ-EXEC-012`, `REQ-EXEC-014`, `REQ-EXEC-015`, `REQ-DOC-004`.

**Reemplaza / Reemplazada por:** No aplica.

---
