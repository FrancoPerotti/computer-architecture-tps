# Representación física del estado global

- **Tipo:** arquitectura.
- **Estado documental:** especificación vigente.
- **Estado:** Diseño aprobado el 2026-10-05.

<a id="estado-y-alcance"></a>

## Propósito y alcance

Este documento define la representación física del estado global de la CPU y su correspondencia con el código de estado que se informa por UART y Debug. La [FSM global CPU](execution_control.md#tabla-de-transiciones) ya tiene aprobados sus catorce estados, condiciones y destinos; aquí se especifica cómo se codifican y cómo se conectan ambas representaciones.

El alcance comprende:

- La implementación de `global_state[13:0]` como un registro one-hot, con un bit activo por estado.
- La correspondencia entre cada bit, el estado de la CPU y su código UART de ocho bits.
- La formación combinacional de `global_state_code[7:0]` para la entrada `debug_state_code` de `Response Serializer`.
- La derivación de las salidas Moore a partir del estado one-hot y su relación con las salidas Mealy de control.
- Las condiciones de reset, la conservación de un único bit activo y los valores definidos para representaciones internas inválidas.

Este documento no redefine las transiciones de la FSM ni agrega estados de CPU. La lógica de sesión y ejecución se describe en [Control de ejecución y sesión](execution_control.md); el controlador UART y el serializador mantienen sus propias FSM. Los [códigos UART](../../protocol.md#global_state) se conservan sin cambios: la codificación one-hot interna solo establece cómo se representa el estado dentro de la CPU y cómo se convierte para su observación externa.

## Estado registrado one-hot de catorce bits

El estado global utiliza `global_state[13:0]`, un registro interno de `Global FSM` dentro de `Execution Control`, con un bit activo por estado. El orden de bits sigue el orden de códigos UART existente:

| Bit activo | Estado CPU         | Código UART de ocho bits |
|-----------:|--------------------|--------------------------|
|          0 | `NO_IMAGE`         | 0x00                     |
|          1 | `LOADING`          | 0x01                     |
|          2 | `PREPARING_READY`  | 0x02                     |
|          3 | `READY`            | 0x03                     |
|          4 | `RUNNING`          | 0x04                     |
|          5 | `STEPPING`         | 0x05                     |
|          6 | `HALT_DRAIN_AUTO`  | 0x06                     |
|          7 | `HALT_DRAIN_STEP`  | 0x07                     |
|          8 | `FAULT_DRAIN_AUTO` | 0x08                     |
|          9 | `FAULT_DRAIN_STEP` | 0x09                     |
|         10 | `FINISHED`         | 0x0A                     |
|         11 | `FAULT`            | 0x0B                     |
|         12 | `PREPARING_RUN`    | 0x0C                     |
|         13 | `PREPARING_STEP`   | 0x0D                     |

La tabla anterior solo relaciona tres representaciones del mismo estado: el bit one-hot interno, el nombre del estado de CPU y el código UART. No define funciones, condiciones ni destinos nuevos; esos aspectos son los de la [tabla de transiciones aprobada](execution_control.md#tabla-de-transiciones), y no se agregan fases adicionales.

Después de un reset, queda activo únicamente el bit cero, que representa `NO_IMAGE`. A partir de allí, el estado actual se conserva en el registro `global_state`; el estado siguiente y las órdenes asociadas se calculan combinacionalmente mediante `casez` y `?`. Las actualizaciones de los recursos de la sesión se mantienen diferenciadas de la actualización de la FSM.

Este criterio de representación y transición es el mismo que se aplica en la UART, el controlador y el serializador.

One-hot usa catorce bits de estado; una codificación binaria compacta usaría cuatro. El diseño utiliza one-hot por coherencia del criterio de FSM y acceso directo a estados individuales, sin afirmar que use menos área o alcance más frecuencia que binario antes de síntesis.

## Código combinacional para Debug

La CPU utiliza dos representaciones del mismo estado porque cumplen funciones distintas. Internamente, `global_state[13:0]` usa un bit activo por estado; hacia UART y Debug se necesita un byte compacto, como `0x03` para `READY` o `0x08` para `FAULT_DRAIN_AUTO`. El codificador combinacional funciona como puente entre ambas representaciones.

`Global FSM` observa únicamente el estado one-hot actualmente registrado y genera la salida Moore `global_state_code[7:0]` según la tabla anterior. Por ejemplo, si `global_state[3]=1`, la salida es `0x03`; si `global_state[8]=1`, la salida es `0x08`. La conversión es combinacional y refleja el estado actual durante el mismo intervalo de clock.

`Execution Control` entrega el código a `Response Serializer` mediante su entrada `debug_state_code[7:0]`. `Protocol Controller` recibe las señales de control `load_available`, `prepare_active`, `program_finished` y `fault_terminal` para decidir disponibilidad, preparación y terminación. Los cuatro bits superiores del código son cero porque los valores legales solo abarcan `0x00`–`0x0D`.

El registro one-hot se actualiza en el flanco positivo del `clk` y, durante el intervalo posterior, el código y las salidas Moore reflejan ese nuevo estado. Durante la retención de Debug, tanto el registro one-hot como su código permanecen estables.

## Decodificación de salidas Moore

Las seis salidas Moore de control de `Global FSM` indican carga, preparación, modo de drenado, disponibilidad para `LOAD` y terminación normal o por fault. Se decodifican combinacionalmente del estado registrado actual.

Como la codificación es one-hot, cada señal se obtiene observando uno o más bits de `global_state`. Para estados legales, las ecuaciones son:

```text
loader_active = global_state[1]
prepare_active = global_state[2] OR global_state[12] OR global_state[13]
drain_mode = global_state[6] OR global_state[7] OR global_state[8] OR global_state[9]
load_available = global_state[0] OR global_state[3] OR global_state[5]
                 OR global_state[7] OR global_state[9] OR global_state[10] OR global_state[11]
program_finished = global_state[10]
fault_terminal = global_state[11]
```

La interpretación de cada señal es:

- `loader_active` vale uno únicamente durante `LOADING`.
- `prepare_active` vale uno durante `PREPARING_READY`, `PREPARING_RUN` o `PREPARING_STEP`.
- `drain_mode` vale uno durante los cuatro estados de drenado.
- `load_available` vale uno en los estados que permiten iniciar `LOAD` y llega a `Protocol Controller` para responder `CHECK_READY`.
- `program_finished` vale uno únicamente en `FINISHED`.
- `fault_terminal` vale uno únicamente en `FAULT`.

Para la observación Debug, el predicado `fault_info_valid` indica vigencia de la metadata durante el drenado por fault y en `FAULT`:

```text
fault_info_valid = global_state[8] OR global_state[9] OR global_state[11]
```

Todas estas señales son combinacionales y conservan los contratos existentes; no son registros nuevos. El reset y las autorizaciones de escritura o de ciclo siguen suprimiendo los efectos normales cuando corresponde. En particular, que `prepare_active` esté activo no implica habilitar una escritura durante `prepare_done`.

Las salidas Mealy `command_accepted`, `load_start`, `cpu_cycle_fire` e `image_publish` combinan el estado actual y las entradas, según las [condiciones de la FSM](execution_control.md#tabla-de-transiciones). `Global FSM` resuelve la aceptación y la autorización del ciclo antes de consultar las confirmaciones y el vacío futuro del pipeline. `next_state` describe el estado que se capturará en el próximo flanco.

En todas las transiciones legales, el diseño conserva exactamente un bit activo desde el reset. La comprobación futura de RTL debe verificar tanto esa invariante como la correspondencia entre la representación one-hot y el código externo.

Si aparece una representación interna inválida, la lógica utiliza valores por defecto definidos y nunca usa `x` como comodín RTL. Esa situación no agrega un estado de CPU ni genera un fault arquitectónico.

## Referencias y trazabilidad

- [Mapa de autoridad documental](../system_overview.md#autoridad-documental-por-tema): contratos vigentes y origen de las decisiones.
- [Requisitos](../../requirements.md): obligaciones y criterios de aceptación.
- [Decisiones pendientes](../../decisions/pending_decisions.md): decisiones de diseño abiertas y condiciones de cierre.
