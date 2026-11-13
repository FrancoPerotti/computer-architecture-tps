# Plataforma Basys 3 del TP3

La [issue #16](https://github.com/FrancoPerotti/computer-architecture-tps/issues/16)
se trabaja en `feature/tp3-16-basys3-timing` desde
`907c72f92c4a28f1aa596cd6d78fc758d3f3efeb` de `origin/feature/tp3-riscv-pipeline`.
La rama se actualizó a `75f1091`, que incorpora el protocolo y Debug de la #11
(`008b0ec`) y viewrv de la #14 (`75f1091`).
El PR apunta a `feature/tp3-riscv-pipeline`.

## Verificación RTL

Desde `tp3`, en el [entorno compartido](../docs/development_environment.md)
con Icarus Verilog 13.0 y Verilator 5.020:

```bash
mkdir -p build/reports
bash scripts/run_tests.sh --test TEST-PLAT-001 --test TEST-PLAT-002 \
  --test TEST-PLAT-003 --test TEST-PLAT-004 --test TEST-UART-013 --format json \
  --reports-dir build/reports/issue-16 >build/reports/issue-16.json
bash scripts/run_tests.sh --all --format json >build/reports/regression.json
make format-check lint validate review-cpu test-infra test-software
```

| Casos | Alcance de esta etapa |
| --- | --- |
| `TEST-PLAT-001/C001–C015` | Ejecuciones del catálogo en paquete y consumidores disponibles. `C001`, `C002` y `C014` también comprueban capacidades en la frontera de `system_top` para REFERENCE y ALT_1000 y rechazo de perfil antes de elaborar el IP o el sistema. |
| `TEST-PLAT-002/C001–C010` | Wrapper y `reset_sync` reales con modelos de Clocking Wizard y del consumidor síncrono. Cada variante guarda `platform.vcd` con `--reports-dir`. `C004` inyecta el evento de último Stop en el modelo y comprueba el orden desde la petición registrada. |
| `TEST-PLAT-003/C001` | `make review-cpu` verifica la porción CPU real en REFERENCE, ALT_1000 y mínimo genérico. Queda la composición completa y la revisión de dependencias con la #15. |
| `TEST-UART-013/C001–C016` | Intercambio `RESET/ACCEPTED` real y orden respecto del último Stop. Pendientes de la #15. |
| `TEST-PLAT-004/C001` | Síntesis e implementación de REFERENCE con el sistema completo. Pendiente de la #15. |

La selección de grupos pasó 74 ejecuciones. Los 18 casos pendientes son la
composición completa, la implementación REFERENCE y los 16 casos de reset UART.
La regresión `--all` pasó las 2494 ejecuciones implementadas. También pasaron
formato, lint, validación, `review-cpu`, las 49 pruebas del ejecutor y las 114
pruebas de software.

## Evidencia complementaria de síntesis

Con `sv2v` 0.0.13 y Yosys 0.66 se mapeó el RTL disponible a primitivas de Xilinx
7 Series con `synth_xilinx -family xc7 -noiopad -noclkbuf`. La elaboración de
`processor_top` deshabilitó la recodificación de `global_state` en Yosys para
conservar la codificación one-hot del RTL ante un error en su extractor de FSM.

| Bloque REFERENCE | Mapeo observado en Yosys |
| --- | --- |
| IMEM, 1024 B | 44 `RAM64M` |
| DMEM, 2048 B | 128 `RAM64M` |
| RF | 992 `FDRE` |
| CPU con sus cinco etapas | 172 `RAM64M`, 1688 `FDRE` y 2620 celdas lógicas estimadas |
| Acondicionador de reset | 2 `FDPE` |

Las netlists pasaron 43 ejecuciones de Icarus con primitivas simuladas a retardo
cero. Se reutilizaron `TEST-MEM-005/C001` para IMEM y DMEM de 1024 B,
`TEST-MEM-010/C002`, `C004`, `C006` y `C008` para IMEM REFERENCE y las 37 variantes
del banco de RF en `TEST-PIPE-002`. Estas corridas comprueban lecturas
combinacionales y efectos de escritura en el flanco para los vectores aplicados.
El `reset_sync` mapeado también pasó las diez variantes del banco de plataforma
con los mismos modelos de clock y consumidor.
Los comandos, netlists y logs locales quedan en `build/reports/synthesis-yosys/`.
La inferencia de Vivado, el ruteo y el timing se verifican con los pasos siguientes.

## Vivado

Usar Vivado ML Standard 2025.2 con soporte Artix-7 y el dispositivo
`xc7a35tcpg236-1`. Desde `tp3`, con `vivado` en `PATH`:

```bash
vivado -mode batch -nolog -nojournal -source scripts/synthesize_blocks.tcl \
  -tclargs build/vivado-blocks
vivado -mode batch -nolog -nojournal -source scripts/build_bitstream.tcl \
  -tclargs build/vivado-uart-fixture uart-fixture
```

En la máquina Arch Linux se añadió al `LD_LIBRARY_PATH` de cada invocación
`lib/lnx64.o/Ubuntu/24` dentro de la instalación de Vivado para cargar las
bibliotecas de compatibilidad incluidas por AMD. Se usó Vivado 2025.2 build
6299465 con Clocking Wizard 6.0.

La síntesis parcial toma IMEM, DMEM, RF y `processor_top`, con sus cinco etapas,
en configuración REFERENCE. Genera checkpoints y reportes de recursos e
inferencia, incluidos LUTRAM. El modo `uart-fixture` implementa el wrapper, el IP,
el reset y la UART RTL para revisar los pines y los endpoints de la netlist.
El fixture retransmite un byte y registra una solicitud de reset al completar el envío.
Ese modo entrega reportes del fixture.

### Resultados parciales en Vivado

| Bloque REFERENCE | LUT de slice | LUT como memoria | Registros | Bloques RAM |
| --- | ---: | ---: | ---: | ---: |
| IMEM, 1024 B | 252 | 176 | 0 | 0 |
| DMEM, 2048 B | 779 | 512 | 0 | 0 |
| RF | 615 | 0 | 992 | 0 |
| `processor_top` | 2714 | 688 | 1666 | 0 |

La síntesis fuera de contexto de los cuatro bloques terminó con cero errores y
cero advertencias críticas. El CPU emitió avisos `Synth 8-7129` por bits de
puertos de etapas sin carga. Los reportes y checkpoints están en
`build/vivado-blocks-final/`.

En XSim, las netlists funcionales de Vivado pasaron los mismos 43 vectores de
IMEM, DMEM de 1024 B y RF descritos arriba. Un estímulo adicional en la DMEM
REFERENCE de 2048 B comprobó lectura combinacional hasta la última palabra,
lectura Debug, borrado por byte y bloqueo de escritura durante reset. También
pasó una simulación con el Clocking Wizard generado, `basys3_top` y la UART RTL.
Midió un período funcional de 20 ns después del arranque y del botón, comprobó
la liberación sincronizada y retransmitió `0xA5` antes de pedir reset funcional
con el MMCM todavía enganchado. Los scripts de ejecución, bancos adaptados y
logs de estas corridas están en `build/vivado-functional/`.

La prueba exploratoria de la netlist DMEM de 1024 B con Icarus y las primitivas
UNISIM de AMD devolvió cero en la primera lectura de `TEST-MEM-005/C001`. El
mismo banco y netlist pasaron en XSim. El diagnóstico queda en
`build/vivado-functional/dmem-after-gsr-iverilog.log`.

El fixture ruteado reportó WNS de **+14,301 ns**, WHS de **+0,072 ns** y TNS/THS
de **0 ns**. El peor setup general fue TX a pin, con 5,699 ns de demora frente a
la cota de 20 ns. El peor setup interno fue de `baud_generator/s_tick_reg` a
`receiver_datapath/sample_count_reg[0]/R`, con 4,771 ns de demora y 0,027 ns de
skew. RX a la primera etapa usó 2,455 ns. Los reportes del fixture están en
`build/vivado-uart-fixture-final/reports/`.

El ruteo confirmó los cuatro pines LVCMOS33, el clock primario de 10 ns y su
salida funcional derivada de 20 ns. `report_drc` dio cero hallazgos, `report_cdc`
reconoció el reset asíncrono de dos etapas con `ASYNC_REG`, y las excepciones
aplicadas tuvieron cobertura de 100 % sin excepciones ignoradas. Vivado reportó
`LUTAR-1` por la LUT que combina las fuentes de reset y alimenta ambos PRE.
Los avisos de entrada de `check_timing` corresponden al botón y a RX, que son
asíncronos a la interfaz de placa.

### Verificación parcial después de la #11

Con el commit `008b0ec` de la #11, Vivado 2025.2 sintetizó por separado
`protocol_controller` y `response_serializer` para `xc7a35tcpg236-1` con los
parámetros REFERENCE. El controlador utilizó 201 LUT y 83 registros. El
serializador utilizó 451 LUT y 89 registros. Ambos terminaron con cero errores
y cero advertencias críticas.

En XSim pasaron el banco de RESET del controlador y los casos
`TEST-UART-009/C008` y `C009` del banco conjunto de controlador y serializador.
El banco conjunto usa modelos en las fronteras UART y CPU y comprueba que la
petición de reset siga al evento de fin de transmisión de ACCEPTED. Los
comandos, logs y reportes están en `build/debug-11-008b0ec/`. Quedan pendientes
los casos de sistema `TEST-UART-013/C001–C016` con `system_top` de la #15.

### Verificación sobre la rama común actualizada

Sobre `75f1091` pasaron las 74 ejecuciones de plataforma, los dos casos
`TEST-UART-009/C008–C009`, la validación del catálogo, las 50 pruebas del
ejecutor, las 114 de assembler y las 44 de protocolo de viewrv. La regresión
`--all` pasó las 2496 ejecuciones implementadas y registró 198 casos pendientes. Las pruebas
de simulación se ejecutaron con Icarus Verilog 13.0 para Arch Linux y los
requisitos fijados del validador y de viewrv. Los resultados y las trazas están
en `build/reports/base-75f1091/`.

La nueva corrida Vivado del fixture a 50 MHz reprodujo WNS de +14,301 ns,
WHS de +0,072 ns, TNS/THS de 0 ns y cero hallazgos de DRC. Los reportes están
en `build/vivado-uart-fixture-75f1091/reports/`.

### Sistema completo tras el merge de la #15

La rama de entrega de la #16 parte de `efb7da138b0bbfa04441e4c6b643970a198351bb`,
el merge del [PR #35](https://github.com/FrancoPerotti/computer-architecture-tps/pull/35).
La revisión de la #15 probada antes del merge (`d6e0791`) tiene el mismo árbol
de fuentes que `efb7da1`. El build de entrega se ejecuta desde un commit limpio
de `feature/tp3-16-basys3-timing`.

```bash
vivado -mode batch -nolog -nojournal -source scripts/build_bitstream.tcl \
  -tclargs build/reports/reference-final/reference reference
vivado -mode batch -nolog -nojournal -source scripts/simulate_basys3_reference.tcl \
  -tclargs build/reports/reference-final/reference-sim reference
```

Para generar solo el proyecto y el IP, usar `scripts/create_project.tcl` con los
mismos argumentos. Cada corrida utiliza un directorio nuevo. El modo `reference`
requiere el `rtl/system_top.sv` de la #15 y guarda `tp3-reference.bit` junto a los
reportes y a `build-info.txt`. Ese archivo registra versión de Vivado, part,
perfil, commit, estado del worktree y hashes de entradas y bitstream.

`constraints/basys3.xdc` define los cuatro pines y el clock primario. El flujo
usa la derivación de clocks del MMCM y deshabilita los XDC del IP. Los endpoints
asíncronos se resuelven en `constraints/basys3_paths.tcl` sobre la netlist. El
límite TX incluye el arco C→Q del registro y la ruta hasta el pin para mantener
la cota de 20 ns con un startpoint válido. Las excepciones de reset se limitan a
los pines asíncronos de las dos etapas. El flujo verifica en la netlist que el
botón es la única fuente de RST del MMCM. Vivado carece de un chequeo STA en ese
pin y rechaza su uso como endpoint de `set_false_path`.

El estímulo de botón de `TEST-PLAT-002/C002` dura 1 µs. En el Artix-7 de grado
`-1`, los mínimos especificados son 5 ns en RST del MMCM y 1,04 ns en SR de los
flip-flops de CLB. [AMD DS181, tablas 26 y 37](https://docs.amd.com/api/khub/documents/iAkxxTOk96ANLJqYf2hgrQ/content).

Los casos seleccionados de plataforma y reset pasaron 93 ejecuciones con
Icarus 13.0, incluidos los 16 casos de `TEST-UART-013` en los niveles de sistema
y unidad de la #15. XSim también pasó `TEST-UART-013/C001` con `basys3_top`, el
Clocking Wizard generado, CPU real y UART a 19200 baud. El banco carga un
programa en bucle, comprueba los bytes `04 01` durante RUN, verifica el reset
desde el último Stop hasta el primer flanco libre E+4 y comprueba CHECK_READY
y STEP sin imagen después del reset. `locked` permanece alto en esa secuencia.

`--all` registró 2692 de 2695 ejecuciones aprobadas con Icarus 13.0 y Verilator
5.054. Las tres ejecuciones de recuperación que dieron error con Verilator
5.054 (`TEST-UART-006/C001`, `C013` y `C014`) pasaron en la repetición con
Verilator 5.020, la versión fijada por el repo. Ambos resultados se conservan
en `regression.json` y `retry-5.020.json` dentro del directorio de evidencia.

`TEST-PLAT-003/C001` se revisó con la elaboración y el análisis combinacional
de `system_top` y `processor_top` en REFERENCE, ALT_1000 y mínimo genérico, y
con los reportes de jerarquía, clocks y timing del wrapper completo. Vivado
conservó las instancias de CPU, UART, controlador y serializador bajo
`system_top`, el MMCM y los dos registros de `reset_sync`. El Clocking Wizard
derivó el clock funcional de 20 ns y su feedback del primario de 10 ns.
`check_timing` registró cero endpoints internos sin restricción, cero registros
sin clock y cero lazos combinacionales o latches. Los casos estructural y
físico se documentan aquí junto con los reportes de Vivado. El runner RTL los
enumera como pendientes porque su evidencia se obtiene fuera de la simulación.

#### `TEST-PLAT-004/C001` en REFERENCE

Vivado 2025.2 ruteó el sistema completo a 50 MHz y generó `tp3-reference.bit`.
El manifiesto registra el commit de entrega y los hashes de las fuentes y del
bitstream.
Los resultados, el checkpoint y `build-info.txt` están en
`build/reports/reference-final/reference/`. La corrida previa al merge y su
regresión completa quedan en `build/reports/reference-pr35/`.

| WNS | TNS | WHS | THS | WPWS |
| ---: | ---: | ---: | ---: | ---: |
| +1,070 ns | 0 ns | +0,026 ns | 0 ns | +3,000 ns |

- El camino de setup va de `exmem_register/data_out_reg[rd][3]/C` a
  `global_fsm_inst/global_state_reg[10]/D`, con 18,845 ns de demora de datos,
  de los cuales 13,388 ns son ruteo, y −0,034 ns de skew. El margen sugiere
  unos 52,8 MHz por setup si se mantuvieran ruteo, skew e incertidumbre.
  El diseño y sus márgenes de hold, pulso y UART se comprobaron a 50 MHz.
- El peor hold va de `idex_register/data_out_reg[instruction][29]/C` a
  `exmem_register/data_out_reg[instruction][29]/D`, con 0,362 ns de demora de
  datos y 0,264 ns de skew según Vivado.
- El sistema utilizó 3466 LUT de slice (16,66 %) y 1893 registros (4,55 %),
  con un MMCM, dos BUFG, cuatro IOB y cero BRAM y DSP. Las 700 LUT de memoria
  se distribuyen en 176 de IMEM, 512 de DMEM y 12 de las FIFO UART. El RF
  conservó 992 registros. IMEM y DMEM mantienen sus lecturas combinacionales.
- Vivado reportó cero hallazgos DRC y cero errores de ruteo. Las cotas RX y TX
  de 20 ns tuvieron 100 % de cobertura y márgenes de +17,166 ns y +13,654 ns.
  Las excepciones del reset se limitan a ambos PRE y no hay excepciones
  ignoradas. CDC-9 reconoce el sincronizador de reset. `LUTAR-1` identifica
  la LUT que combina las fuentes asíncronas según el contrato de plataforma.
  Los 32 avisos `SYNTH-5` corresponden a las marcas de validez DMEM en LUTRAM.

El bitstream y los reportes de la misma corrida quedan disponibles para la
[prueba en placa de la #17](https://github.com/FrancoPerotti/computer-architecture-tps/issues/17).
