# Trabajo Práctico N.º 1 — ALU

## Descripción

Este trabajo presenta una unidad aritmético-lógica (ALU) parametrizable en SystemVerilog, con ocho operaciones e indicadores de cero, carry y overflow. La interfaz para la Basys 3 utiliza el reloj de 100 MHz para capturar los controles y cuenta con testbenches del núcleo, el sincronizador y el top. El diseño se verificó en simulación, se sintetizó y se implementó; la generación del bitstream y la prueba física quedan pendientes.

## Integrantes del grupo

| Apellido y nombre | Legajo |
|---|---|
| Arnaudo, Federico Andrés | _Completar_ |
| Perotti, Franco José | 42052766 |

## Datos de la asignatura

| Dato | Información |
|---|---|
| Materia | Arquitectura de Computadoras |
| Carrera | Ingeniería en Computación |
| Institución | Universidad Nacional de Córdoba |
| Facultad | Facultad de Ciencias Exactas, Físicas y Naturales |
| Docente | Martín Pereyra |
| Año | 2026 |

## Informe

El desarrollo completo, la explicación del código y los resultados de simulación, síntesis e implementación se encuentran disponibles en Markdown y en el informe final maquetado en LaTeX:

- [Informe en Markdown](INFORME.md)
- [Informe final en PDF](informe/tp1_alu.pdf)
- [Fuentes del informe en LaTeX](informe/tp1_alu.tex)

## Convención de nombres

Las señales, variables, módulos y tareas usan `snake_case`, por ejemplo `data_a`, `btn_load_a` y `check_result`. Los parámetros y constantes usan `UPPER_SNAKE_CASE`, como `NB_DATA`, `OP_ADD` y `LOAD_CYCLES`.

La regla de parámetros de Verible se configura en `.rules.verible_lint`. Para comprobar los archivos desde esta carpeta:

```sh
verible-verilog-lint --rules_config_search alu.sv alu_tb.sv button_input.sv button_input_tb.sv alu_top.sv alu_top_tb.sv
```

Para que el editor también lea esa configuración, el servidor debe iniciarse con `verible-verilog-ls --rules_config_search`.

## Simulación

Los tres testbenches cubren responsabilidades diferentes:

- `alu_tb.sv` verifica el resultado y los indicadores de la ALU con 814 casos dirigidos y pseudoaleatorios.
- `button_input_tb.sv` comprueba la propagación de los niveles del pulsador a través de las dos etapas de sincronización.
- `alu_top_tb.sv` verifica las cargas de A, B y opcode, la prioridad del reset y las salidas del circuito completo.

En Vivado, abrir el proyecto creado mediante el script, elegir el testbench deseado dentro de **Simulation Sources**, hacer clic derecho y seleccionar **Set as Top**. Después, ejecutar **Run Behavioral Simulation** y **Run All** hasta ver `PASS` en la consola. Los testbenches terminan con `$fatal` si encuentran alguna diferencia.

También pueden ejecutarse con Icarus Verilog desde la carpeta que contiene este README:

```sh
sim_dir=$(mktemp -d /tmp/tp1-sim.XXXXXX)
iverilog -g2012 -s alu_tb -o "$sim_dir/alu_tb" alu.sv alu_tb.sv
vvp "$sim_dir/alu_tb"
iverilog -g2012 -s button_input_tb -o "$sim_dir/button_input_tb" button_input.sv button_input_tb.sv
vvp "$sim_dir/button_input_tb"
iverilog -g2012 -s alu_top_tb -o "$sim_dir/alu_top_tb" alu.sv button_input.sv alu_top.sv alu_top_tb.sv
vvp "$sim_dir/alu_top_tb"
```

Los estímulos representan niveles digitales ideales. Por eso estas simulaciones comprueban el comportamiento lógico, pero no reproducen la metastabilidad, los rebotes eléctricos ni los tiempos físicos de propagación de la placa.

`alu.sv` y `alu_tb.sv` emplean construcciones de SystemVerilog. Al agregarlos manualmente a Vivado debe seleccionarse ese tipo de archivo; para Icarus se utiliza la opción `-g2012`, como muestran los comandos anteriores.

## Integración con la placa

`alu_top.sv` utiliza el reloj de 100 MHz de la Basys 3. Mientras un botón esté presionado, su nivel sincronizado habilita la carga del registro correspondiente en cada ciclo. Al soltarlo y propagarse la liberación por el sincronizador, el registro conserva el último dato. La ALU calcula el resultado a partir de los operandos y el opcode almacenados.

| Botón | Función |
|---|---|
| BTNL (izquierda) | Cargar A desde SW7–SW0 |
| BTNR (derecha) | Cargar B desde SW7–SW0 |
| BTNU (arriba) | Cargar opcode desde SW5–SW0 |
| BTNC (centro) | Borrar A, B y opcode |

El botón inferior queda sin usar. Los puertos se nombran por su función: `btn_load_a`, `btn_load_b`, `btn_load_opcode` y `btn_reset`. Su ubicación física se define en `basys3.xdc`.

`button_input.sv` contiene dos flip-flops conectados en serie. El primero captura el pin del botón y el segundo toma esa muestra en el siguiente ciclo. La salida `button_pressed` entrega el nivel sincronizado al `top`. Esta sincronización reduce el riesgo de propagar metastabilidad; los rebotes del botón pueden atravesarla y habilitar cargas repetidas.

El uso es: configurar el número en los switches, apretar y soltar el botón de carga, y después preparar el siguiente número. Los switches se conectan directamente a las entradas de datos de los registros. Como el número ya está establecido al habilitar la carga y permanece en la misma posición durante la pulsación y su liberación, las cargas repetidas guardan el mismo dato. Si se presionan varios botones de carga juntos, cada registro seleccionado captura los switches.

El reset usa el nivel sincronizado de BTNC y tiene prioridad sobre las cargas mientras permanezca activo. Si al soltar reset queda un botón de carga presionado, ese registro vuelve a cargar los switches. Los registros se ponen en cero en el primer ciclo de reloj tras la configuración.

### Indicadores de la ALU

La ALU calcula los indicadores junto con el resultado. El `top` conecta esas salidas a los LEDs:

| LEDs | Salida | Significado |
|---|---|---|
| LED7–LED0 | `o_result` | Resultado de 8 bits |
| LED8 | `o_zero` | Los ocho bits del resultado son cero |
| LED9 | `o_carry` | Acarreo de salida de ADD; cero en las demás operaciones |
| LED10 | `o_overflow` | Desbordamiento con signo de ADD o SUB; cero en las demás operaciones |

Para obtener carry, la suma se calcula con un bit adicional. Overflow se detecta con los signos: en ADD, los operandos tienen el mismo signo y el resultado cambia de signo; en SUB, los operandos tienen signos distintos y el resultado tiene un signo diferente al de A.

Los indicadores se actualizan con cada operación. Después del reset se enciende LED8 porque el resultado es cero. Un opcode inválido también produce resultado cero, con cero activo y carry y overflow apagados.

Ejemplos para probar en la placa; los operandos y el resultado se muestran en hexadecimal:

| A | B | Operación | Resultado | Cero | Carry | Overflow |
|---|---|---|---|---:|---:|---:|
| `05` | `03` | ADD | `08` | 0 | 0 | 0 |
| `FF` | `01` | ADD | `00` | 1 | 1 | 0 |
| `7F` | `01` | ADD | `80` | 0 | 0 | 1 |
| `80` | `80` | ADD | `00` | 1 | 1 | 1 |
| `80` | `01` | SUB | `7F` | 0 | 0 | 1 |
| `7F` | `FF` | SUB | `80` | 0 | 0 | 1 |
| `05` | `05` | SUB | `00` | 1 | 0 | 0 |

### Proyecto de Vivado

Desde la carpeta de este README, ejecutar:

```sh
vivado -mode batch -source scripts/create_sync_project.tcl -nojournal -nolog
```

El script crea `tp1_sync/tp1_sync.xpr` con `alu_top` como módulo superior y `basys3.xdc` como archivo de restricciones. Para trabajar sobre el proyecto generado, abrir ese `.xpr`. La simulación seleccionada es `alu_top_tb`; ejecutar **Run Behavioral Simulation** y esperar el mensaje `PASS`. Para simular `button_input_tb` o `alu_tb`, seleccionarlo con **Set as Top** en **Simulation Sources**.

El script se ejecuta una sola vez: si la carpeta `tp1_sync` ya existe, indica que se abra el proyecto existente.

Las fuentes del proyecto apuntan a los archivos `.sv` de esta carpeta. Al agregarlas manualmente, dejar desmarcada la opción **Copy sources into project** para que Vivado utilice los mismos archivos que se editan aquí.

La asignación del reloj a W5 y su período de 10 ns siguen el [archivo de restricciones de Digilent para la Basys 3](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc). Los sincronizadores de botones usan el atributo [ASYNC_REG de AMD](https://docs.amd.com/r/en-US/ug912-vivado-properties/ASYNC_REG). Las rutas de los botones hasta la primera etapa y las salidas hacia los LEDs se excluyen del análisis temporal. También se excluyen las entradas de los switches: su captura depende de que el usuario configure el dato antes de habilitar la carga y lo conserve hasta soltar el botón. Esa condición de uso no la verifica el análisis temporal. Las rutas entre registros siguen sujetas al reloj de 100 MHz.

### Pruebas del diseño

- `button_input_tb.sv`: comprueba las dos etapas de sincronización al presionar y soltar, el nivel con el botón sostenido y la propagación de una pulsación breve.
- `alu_top_tb.sv`: comprueba cargas por nivel, conservación de datos, resultado e indicadores en los once LEDs, rebotes con el número fijo en los switches, botones simultáneos, prioridad del reset y respuesta al detener y reanudar el reloj.

Verificación con XSim de Vivado 2025.2: 814 pruebas de la ALU, 38 del `top` y 14 del sincronizador aprobadas. Las capturas actuales documentan síntesis e implementación correctas y el cumplimiento de las restricciones temporales. Aunque se generó un bitstream en verificaciones anteriores, al actualizar el informe el archivo ya no estaba presente: queda ejecutar **Generate Bitstream** para la última implementación. La ruta de salida prevista es `tp1_sync/tp1_sync.runs/impl_1/alu_top.bit`. También queda pendiente la prueba física con una placa que entregue reloj.
