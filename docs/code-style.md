# Guía del estilo de código SystemVerilog

Esta guía describe las convenciones de código SystemVerilog observadas en el repositorio al 30 de septiembre de 2026. Está dirigida a personas y agentes que escriben o revisan módulos RTL y bancos de prueba. Su alcance son los 24 archivos propios implementados de TP1 y TP2; las variaciones locales forman parte del estilo observado. No establece nuevas reglas ni propone reformatear el código.

El [informe de análisis](code-style-analysis.md) contiene el relevamiento del repositorio y la evidencia que sustenta esta guía. Los identificadores G y SV remiten a los hallazgos de organización y SystemVerilog de su matriz.

## Organización, idioma y formato general

Los nombres de módulos, señales, parámetros e instancias están principalmente en inglés; los comentarios están principalmente en español. Los mensajes de simulación suelen usar inglés, como `ERROR`, `PASS` y `FAIL`. Véanse los comentarios del núcleo [alu.sv](../tp1/alu.sv) y las comprobaciones de [alu_tb.sv](../tp1/alu_tb.sv). (G1)

TP1 tiene sus tres módulos RTL y tres bancos de prueba en la raíz de [tp1](../tp1/). TP2 separa sus diez módulos en [rtl](../tp2/rtl/) y sus ocho bancos en [tb](../tp2/tb/). Las copias importadas en proyectos Vivado, como las de `tp1/tp1_sync/`, quedan fuera de las fuentes de referencia para describir el estilo. (G2)

No se observa un límite uniforme de longitud de línea en SystemVerilog. Las alineaciones verticales y continuaciones varían según el archivo. Las configuraciones locales de Verible en [TP1](../tp1/.rules.verible_lint) y [TP2](../tp2/.rules.verible_lint) expresan la capitalización de parámetros y constantes. (G3, SV2)

## Archivos, indentación y nombres

Los 24 archivos propios contienen un módulo por archivo, con nombre igual al nombre del archivo sin `.sv`. Los once bancos terminan en `_tb`. El cuerpo del módulo usa dos espacios por nivel; los parámetros y puertos de la cabecera usan cuatro espacios. Las conexiones nominales de instancias suelen quedar a seis espacios, como continuación de una declaración dentro del módulo. (SV1)

Se alinean nombres, anchos, conexiones y asignaciones cuando forman un grupo. La alineación no es exhaustiva: [alu_tb.sv de TP1](../tp1/alu_tb.sv#L49) alinea algunos parámetros de instancia y deja varias conexiones sin alinear. Las expresiones largas se distribuyen en continuaciones, pero sin un ancho máximo compartido. (SV1, G3)

Los parámetros y `localparam` usan mayúsculas con guiones bajos (`NB_DATA`, `CLK_FREQ_HZ`, `OP_ADD`, `STATE_IDLE`). Las señales, módulos e instancias usan minúsculas y `snake_case`, con abreviaturas como `clk`, `rd` y `wr`. (SV2)

La interfaz de la ALU usa `i_` y `o_`: `i_data_a`, `i_data_opcode`, `o_result`. Es una convención de ese núcleo, conservada en su [copia autocontenida del TP2](../tp2/rtl/alu.sv#L3). Los demás módulos usan nombres sin esos prefijos, como `serial_rx`, `data_in` y `rx_done_tick`. La duplicación de la ALU no es evidencia independiente de una regla general. (SV2)

Fragmento de [baud_tick_gen.sv](../tp2/rtl/baud_tick_gen.sv#L4), que muestra cabecera, tipos y alineación:

```systemverilog
module baud_tick_gen #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 19_200,
    parameter integer OVERSAMPLE  = 16
) (
    input  wire clk,
    input  wire reset,
    output reg  s_tick
);
```

## Tipos y descripción del hardware

Predominan `wire` para conexiones y salidas de asignación continua, y `reg` para variables escritas en bloques procedurales. `reg` también aparece en lógica combinacional, como las salidas de la ALU: su tipo no implica por sí solo un registro físico. Los usos de `logic` en las fuentes propias son declaraciones `localparam logic`, incluyendo constantes con signo en los bancos de la ALU. Los parámetros de anchos, frecuencias y contadores derivados suelen declararse `integer`. (SV3)

La lógica combinacional procedural usa `always_comb` con asignaciones bloqueantes (`=`). Los registros RTL usan `always @(posedge clk)` y asignaciones no bloqueantes (`<=`). [reset_sync.sv](../tp2/rtl/reset_sync.sv#L16) añade `posedge async_reset` para la aserción asíncrona. No aparece `always_ff` en las 24 fuentes implementadas. En los bancos, los estímulos y contadores de observación usan también asignaciones bloqueantes dentro de bloques temporizados. (SV4)

Las instancias conectan puertos y, cuando corresponde, parámetros por nombre. Los comentarios explican intención, ciclos, validación de tramas y condiciones de frontera, como la aceptación de lectura/escritura en [fifo.sv](../tp2/rtl/fifo.sv#L35). Los cinco módulos parametrizados nuevos que calculan o consumen límites internos (`baud_tick_gen`, `fifo`, `uart_rx`, `uart_tx` y `alu_uart_controller`) incluyen comprobaciones con `initial` y `$error`; no todos los módulos parametrizados las tienen. (SV4, SV5)

## Inicialización, reset y sincronización

Los valores iniciales se declaran en varios registros y también se cargan en ramas de reset. Su alcance depende del módulo: (SV5)

- [alu_top.sv](../tp1/alu_top.sv#L28) usa `startup_reset = 1'b1` para borrar operandos y opcode en el primer flanco. El reset tiene prioridad sobre las cargas.
- [button_input.sv](../tp1/button_input.sv#L8) inicializa sus dos etapas a cero y no tiene puerto de reset.
- [reset_sync.sv](../tp2/rtl/reset_sync.sv#L11) inicializa la cadena a `2'b11`; la activa asíncronamente y la libera después de dos flancos.
- [serial_input_sync.sv](../tp2/rtl/serial_input_sync.sv#L11) inicializa y resetea las dos etapas al nivel de reposo alto de la UART.
- [fifo.sv](../tp2/rtl/fifo.sv#L20) inicializa punteros y cantidad, y los limpia con reset; la memoria de datos no se inicializa ni se borra en esa rama.

`ASYNC_REG = "TRUE"` aparece en los tres sincronizadores anteriores de botón, reset y entrada serie. Hay una variación de espacio entre el atributo y `reg`: `*)reg` en botón/entrada serie y `*) reg` en reset. Las prioridades y los niveles de reposo se documentan por bloque, sin una regla única de reset para todo el repositorio. (SV5)

## Máquinas de estado del TP2

Las FSM de [uart_rx](../tp2/rtl/uart_rx.sv#L20), [uart_tx](../tp2/rtl/uart_tx.sv#L20) y [alu_uart_controller](../tp2/rtl/alu_uart_controller.sv#L25) comparten este patrón: (SV6)

- Constantes `STATE_*` con valores one-hot y atributo `fsm_encoding = "one_hot"` en `state`.
- Separación del bloque de registros y el bloque `always_comb`, con `next_state` y otros valores `next_*`.
- Valores combinacionales por defecto que conservan registros y apagan pulsos o enables antes del `case`.
- Rama `default` que recupera un estado de reposo y limpia los datos de control correspondientes.

Fragmento de [uart_tx.sv](../tp2/rtl/uart_tx.sv#L62):

```systemverilog
  // Los valores por defecto conservan los registros y hacen que tx_done_tick
  // permanezca en uno durante un solo ciclo.
  always_comb begin
    next_state = state;
    next_sample_count = sample_count;
    next_bit_count = bit_count;
    next_data = data_reg;
    next_tx = tx_reg;
    tx_done_tick = 1'b0;
```

Este fragmento ilustra formato y valores por defecto; la duración del pulso depende además de las ramas del `case`. La observación sobre one-hot se limita a esas tres FSM implementadas y no fija la codificación de futuras máquinas.

## Bancos de prueba

Los once bancos usan instancia `dut`, contador `errors`, comprobaciones con `!==`, mensajes `PASS`/`FAIL`, `$fatal` al fallar y `$finish` al completar. Las comparaciones estrictas permiten que un valor desconocido o de alta impedancia también produzca discrepancia. Algunos bancos mantienen además `tests`, contadores de respuestas o de pulsos. (SV7)

Diez bancos agrupan estímulos y comprobaciones en `task automatic`, con argumentos declarados después de la cabecera y un `begin` interno. [baud_tick_gen_tb.sv](../tp2/tb/baud_tick_gen_tb.sv) realiza las comprobaciones directamente en bloques `always` e `initial`. Los bancos secuenciales suelen cambiar estímulos en `negedge clk` y observar después de un flanco, a menudo con `#1`; el reloj suele generarse con `always #5`. (SV7)

Fragmento de [button_input_tb.sv](../tp1/button_input_tb.sv#L38):

```systemverilog
      if (button_pressed !== expected) begin
        errors = errors + 1;
        $display("ERROR: %0s; expected=%b, obtained=%b", description, expected, button_pressed);
      end
```

Los tres bancos con `$urandom` —las dos pruebas de ALU y [alu_uart_top_tb.sv](../tp2/tb/alu_uart_top_tb.sv)— fijan la semilla `32'h1a2b3c4d`. Ocho bancos tienen un `initial` de timeout separado; las dos pruebas combinacionales de ALU y la del generador de baud no lo tienen. Todos los bancos declaran `` `timescale 1ns / 1ps ``; también lo hacen los diez módulos RTL del TP2, mientras que los tres módulos RTL del TP1 lo omiten. (SV8)


## Alcance de TP3

[TP3](../tp3/) todavía no aporta fuentes SystemVerilog implementadas: sus directorios [rtl](../tp3/rtl/) y [tb](../tp3/tb/) contienen marcadores `.gitkeep`. El [ejemplo de reset del plan](../tp3/docs/plan.md#L1161) usa `logic` y `always_ff`: expresa una referencia para el diseño futuro y no describe el estilo de las fuentes actuales de TP1/TP2. Esta guía no decide los tipos ni las codificaciones de futuras FSM del TP3; sus contratos y [decisiones pendientes](../tp3/docs/pending_decisions.md) se consultan por separado. (G4)

## Consulta breve para escribir y revisar SystemVerilog

- Identificar el TP y módulo de referencia; consultar sus fuentes vecinas y el alcance de la evidencia antes de generalizar.
- Comparar indentación, alineación, nombres y comentarios con ese contexto; comprobar el nombre de módulo/archivo y las conexiones nominales.
- Revisar tipos procedurales, asignaciones bloqueantes y no bloqueantes, valores por defecto y actualizaciones de registros.
- Consultar la inicialización, los niveles de reposo y la prioridad de reset documentados para el módulo.
- En las FSM del TP2, cotejar estados `STATE_*`, codificación one-hot, señales `next_*` y recuperación mediante `default`.
- En bancos de prueba, consultar el patrón `dut`, comparaciones estrictas, contadores y finalización; comprobar si ese banco usa semilla fija, timeout y `timescale`.
- Distinguir las fuentes editables de las copias importadas y los ejemplos de diseño futuro de TP3.

Esta lista sirve para cotejar un cambio con el estilo existente; no agrega requisitos de herramientas, formato o diseño.
