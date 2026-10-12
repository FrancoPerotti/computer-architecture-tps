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
- La formación combinacional y compartida de `global_state_code[7:0]` para el controlador UART y el serializador Debug.
- La derivación de las habilitaciones combinacionales existentes a partir del estado one-hot.
- Las condiciones de reset, la conservación de un único bit activo y los valores definidos para representaciones internas inválidas.

Este documento no redefine las transiciones de la FSM ni agrega estados de CPU. La lógica de sesión y ejecución se describe en [Control de ejecución y sesión](execution_control.md); el controlador UART y el serializador mantienen sus propias FSM. Los [códigos UART](../protocol.md#global_state) se conservan sin cambios: la codificación one-hot interna solo establece cómo se representa el estado dentro de la CPU y cómo se convierte para su observación externa.

## Estado registrado one-hot de catorce bits

El estado global utiliza `global_state[13:0]` con un bit activo por estado. El orden de bits sigue el orden de códigos UART existente:

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

## Código combinacional compartido

La CPU utiliza dos representaciones del mismo estado porque cumplen funciones distintas. Internamente, `global_state[13:0]` usa un bit activo por estado; hacia UART y Debug se necesita un byte compacto, como `0x03` para `READY` o `0x08` para `FAULT_DRAIN_AUTO`. El codificador combinacional funciona como puente entre ambas representaciones.

La lógica Moore global observa únicamente el estado one-hot actualmente registrado y genera `global_state_code[7:0]` según la tabla anterior. Por ejemplo, si `global_state[3]=1`, la salida es `0x03`; si `global_state[8]=1`, la salida es `0x08`. Como esta conversión es combinacional, no incorpora un segundo registro de estado, un contador ni otro flanco de captura.

`protocol_controller` recibe `global_state_code`, mientras que `response_serializer` recibe esa misma conexión con el nombre de entrada `debug_state_code`. Ambos consumidores observan el mismo código y no necesitan adaptadores separados. El codificador puede estar agrupado en la lógica de decodificación global. Los cuatro bits superiores del byte son cero porque los códigos legales solo abarcan `0x00`–`0x0D`.

El registro one-hot se actualiza en el flanco de la CPU y, durante el intervalo posterior, el código refleja ese nuevo estado. La exclusión de Debug y `terminal_due` observan el código actual, por lo que conservan el instante postciclo. El codificador no autoriza ciclos, no solicita reset y no modifica ningún estado; durante la retención de Debug, tanto el registro one-hot como su código permanecen estables.

## Decodificación de habilitaciones existentes

Estas señales son vistas combinacionales del estado global. No agregan información nueva ni guardan estado: permiten que otros bloques sepan si la CPU está cargando una imagen, preparando una sesión, en una condición terminal o conservando metadata de fault.

Como la codificación es one-hot, cada señal se obtiene observando uno o más bits de `global_state`. Para estados legales, las ecuaciones son:

```text
loader_active = global_state[1]
prepare_active = global_state[2] OR global_state[12] OR global_state[13]
program_finished = global_state[10]
fault_info_valid = global_state[8] OR global_state[9] OR global_state[11]
```

La interpretación de cada señal es:

- `loader_active` vale uno únicamente durante `LOADING`.
- `prepare_active` vale uno durante `PREPARING_READY`, `PREPARING_RUN` o `PREPARING_STEP`.
- `program_finished` vale uno únicamente en `FINISHED`.
- `fault_info_valid` vale uno durante los estados de drenado por fault y en `FAULT`, cuando la metadata del fault es válida.

Todas estas señales son combinacionales y conservan los contratos existentes; no son registros nuevos. El reset y las autorizaciones de escritura o de ciclo siguen suprimiendo los efectos normales cuando corresponde. En particular, que `prepare_active` esté activo no implica habilitar una escritura durante `prepare_done`.

El árbitro de comandos y la autorización de ciclo consumen el estado actual registrado. `next_state` describe el estado que se capturará en el próximo flanco, pero no se utiliza para autorizar ese mismo flanco.

En todas las transiciones legales, el diseño conserva exactamente un bit activo desde el reset. La comprobación futura de RTL debe verificar tanto esa invariante como la correspondencia entre la representación one-hot y el código externo.

Si aparece una representación interna inválida, la lógica utiliza valores por defecto definidos y nunca usa `x` como comodín RTL. Esa situación no agrega un estado de CPU ni genera un fault arquitectónico.

## Referencias y trazabilidad

- [Mapa de autoridad documental](system_overview.md#autoridad-documental-por-tema): contratos vigentes y origen de las decisiones.
- [Requisitos](../requirements.md): obligaciones y criterios de aceptación.
- [Pendientes](../pending_decisions.md): seguimiento actual del trabajo abierto.
