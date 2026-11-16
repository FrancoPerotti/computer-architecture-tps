# Aceptación Basys 3 de la #17

La rama `feature/tp3-17-aceptacion-placa` está actualizada a
`7025925f949c16cbe1a5bd44bf17d9e9ed01a78c` de `origin/feature/tp3-riscv-pipeline`.
Esa rama remota es el destino del PR. [Issue #17](https://github.com/FrancoPerotti/computer-architecture-tps/issues/17)

La base incluye assembler (#13), viewrv 0.7.0 (#14), protocolo y serialización
(#11), sistema UART–Debug–CPU (#15) y plataforma Basys 3 (#16).
[PR #23](https://github.com/FrancoPerotti/computer-architecture-tps/pull/23) ·
[PR #33](https://github.com/FrancoPerotti/computer-architecture-tps/pull/33) ·
[PR #34](https://github.com/FrancoPerotti/computer-architecture-tps/pull/34) ·
[PR #35](https://github.com/FrancoPerotti/computer-architecture-tps/pull/35) ·
[PR #36](https://github.com/FrancoPerotti/computer-architecture-tps/pull/36)

La corrida final de la #16 produjo `tp3-reference.bit` con Vivado 2025.2 en
`tp3/build/reports/reference-final/reference/` del worktree
`feature/tp3-16-basys3-timing`. El build usa el commit RTL
`d2ef373194b396f5a4367af22fe7e243ada5d49e`, cuyo árbol coincide con el merge
`7025925`. Se verificó la huella
`660ae6ed81c864ebc30790af1184fdad2421da535bdc9f26e5f22648520e33af`
contra `build-info.txt`. El informe de timing registra WNS de +1,070 ns,
WHS de +0,026 ns y TNS/THS de 0 ns a 50 MHz.
[Informe de la #16](../../reports/issue-16.md)

## Preparación sin placa

Desde `tp3`, con Python 3.11 o posterior y Git:

~~~sh
python3 -m tools.board_acceptance --output build/board-acceptance/prepared
python3 -m tools.board_acceptance --simulate --output build/board-acceptance/transport
python3 -m unittest -v scripts.tests.test_board_acceptance
~~~

Cada ejecución usa un directorio nuevo. `--case TEST-PIPE-005/C008`, repetible,
permite seleccionar IDs completos. El recorrido inicial se selecciona con
`--case smoke`; comienza con reset y `NO_IMAGE`, ensambla A y comprueba
`CHECK_READY → LOAD → STEP → RUN`. Después carga B sobre la misma placa, ejecuta
un tercer programa que produce fault de fetch y verifica reset otra vez.

`prepared/status.json` enumera exactamente los 151 IDs de
[`replay_cases`](cases/platform/board-acceptance.json). `TEST-EXEC-004/C006` usa
ALT_1000 y queda fuera de la selección REFERENCE. `smoke` es una comprobación previa
del host, fuera de la selección canónica.

Cada ID tiene `plan.json`, imágenes binarias con SHA-256 y fuente o prefijo
Assembly donde corresponde. Para variantes dirigidas se conservan las palabras
del catálogo, incluidas las palabras ilegales que deben producir un fault.
El assembler integrado traduce los prefijos y los programas escritos para esta
sesión. Los valores del oráculo se toman de las expectativas del catálogo y del
contrato, con los ajustes siguientes:

- El prefijo materializa RF con LUI y ADDI y escribe DMEM con SB o SW, incluyendo
  bytes cero que deben quedar marcados. Restaura el registro temporal `x31`.
- El último JAL del prefijo redirige al bloque canónico. Se registran el PC de ese
  bloque y el costo en ciclos del prefijo más los dos ciclos de redirección. Los
  branches relativos mantienen su inmediato. Los destinos absolutos de JALR,
  los enlaces y los PC de fault se trasladan cuando corresponde.
- `TEST-UART-008/C005` recorre 2048 direcciones con SB y deja `x1=x2=2048`,
  `PC=28`, 10244 ciclos y un listado de 2048 entradas `(a, a mod 256)`.
  `C001` comprueba la lista antes y después de reiniciar la misma imagen con STEP.
- La captura terminal compara contexto, 32 registros, validez de los cuatro
  latches y la lista completa de DMEM. Los STEP dirigidos comprueban campos
  activos adicionales, por ejemplo el inmediato de LUI y la retención de IF/ID
  durante load-use. El registro conserva todos los campos recibidos. Los
  campos fuera de vigencia se interpretan según el protocolo.
- Las pruebas LOAD comparan los intercambios de aceptación y rechazo y observan
  la imagen mediante la ejecución posterior. El runner usa el cuerpo literal de
  TEST-UART-007/C001 para probar su decodificador en el host. Los eventos
  internos de publicación, el instante exacto de reset y las señales de
  exclusión corresponden a las simulaciones de sistema de la #15.

Con Icarus y las herramientas fijadas por [el entorno compartido](../development_environment.md),
desde `tp3`:

~~~sh
python3 -m tools.board_acceptance.check_cpu --output build/board-acceptance/rtl
make format-check lint validate test-infra test-software
bash scripts/run_tests.sh --test TEST-UART-004 --test TEST-UART-008 \
  --test TEST-UART-013 --format json > build/board-acceptance/uart-regression.json
~~~

El banco reutiliza las fuentes y el soporte del ejecutor común. Carga cada imagen
mediante Loader y preparación reales de `processor_top` y observa sus puertos
Debug. La comparación usa el mismo oráculo del plan UART. El banco vuelca los
campos de esos puertos y conserva los X en el log. Los X de campos fuera de
vigencia se sustituyen para decodificar la captura de simulación.

| Comprobación | Resultado local |
| --- | --- |
| Selección de TEST-PLAT-005 | 151 planes exportados, 150 recorridos preparados y 1 pendiente de instrumentación. |
| Host con transcript UART fijo | `smoke` pasó. Nueve pruebas del ejecutor verifican framing, recuperación al abrir el puerto, rechazos y truncamientos, los 34 campos del cuerpo canónico y el listado máximo de 10470 bytes. |
| CPU RTL por su frontera | Pasaron las proyecciones de 144 IDs con 188 capturas, más 4 capturas de `smoke`. `rtl/status.json` conserva el resultado por ID. Los casos con estímulo UART solo acreditan sus capturas proyectadas. |
| Casos sin proyección CPU ejecutada | `TEST-EXEC-008/C001`, `C002` y `TEST-UART-013/C001`, `C007`, `C008`, `C009`, `C010`. |
| viewrv 0.7.0 integrado | Pasaron 47 pruebas de protocolo y CLI/core con adaptadores controlados y pseudo-terminales Linux. |
| UART integrado | Pasaron 44 ejecuciones de TEST-UART-004, TEST-UART-008 y TEST-UART-013 en Icarus 13.0 sobre `7025925`. |
| Regresión general del TP3 | Sobre la base inicial `907c72f` pasaron 2481 ejecuciones RTL, 57 pruebas de infraestructura y 114 del assembler. En la base actual se repitieron las proyecciones CPU, el transporte simulado y las comprobaciones dirigidas de UART y viewrv. |
| Basys 3 | La sesión del 13 de noviembre de 2026 pasó el recorrido corto por UART y viewrv CLI. El estado por ID se registra en la sesión física. |

## Sesión física del 13 de noviembre de 2026

Franco y Federico usaron la Basys 3 Digilent `210183AA0DED` con `/dev/ttyUSB1`.
Viewrv 0.7.0 programó SRAM con el bitstream REFERENCE de la #16. El recorrido
CLI confirmó el primer STEP, RUN de A, reemplazo por B, fault de fetch,
interrupción del bucle y ejecución de recuperación. El recorrido UART corto
también pasó con el mismo bitstream.

Los resultados están en `build/board-acceptance/basys3-210183AA0DED-2026-11-13/`.
Allí se conservan los logs de viewrv, los bytes UART por ID, el bitstream, su
manifiesto y los reportes de Vivado. `status.json` consolida los intentos
automáticos y manuales. Pasaron 150 de las 151 variantes del catálogo en
placa, los 146 casos automáticos y cuatro con BTNC durante RUN, LOAD y Debug.
`TEST-UART-013/C009` quedó exceptuado de la ejecución física de esta entrega
por decisión de Franco. La ventana de aproximadamente 41 µs en
PREPARING_READY requiere un disparo sincronizado y una captura que ubique el
pulso respecto del último byte de LOAD.

C009 pasó en simulación de sistema (`system_top_session_tb`, sobre
`7025925`). El banco comprueba `prepare_active` antes del pulso, el retorno
de TX a reposo y la sesión limpia después del reset. El resultado se conserva
en `build/board-acceptance/uart-regression-7025925.json`. El ID sigue en
`replay_cases` y en el registro de la sesión con la excepción física.

## Sesión de los dos desarrolladores

1. Seleccionar un único build REFERENCE de la #16 con el sistema de la #15,
   revisar timing y conservar `tp3-reference.bit`, `build-info.txt` y
   `reports/` de esa corrida. Anotar identificación de la Basys 3, USB J4, puerto
   UART y las versiones de viewrv, Python, pySerial y Vivado. Programar SRAM una
   vez y conservar el log JTAG.
2. Una persona opera, la otra compara. Intercambiar funciones y registrar
   los turnos. Mantener el mismo bitstream al reemplazar imágenes o probar
   cualquiera de las fuentes de reset.
3. Cerrar el acceso al puerto desde viewrv antes de correr las pruebas UART
   directas. Usar 19200 baud, 8N1 y control de flujo desactivado. El ejecutor abre
   el puerto con exclusión en Linux.
4. Correr primero `smoke`, luego el lote automático y después los casos de botón
   preparados con `--manual` y `--case`. Registrar la excepción física de
   `TEST-UART-013/C009` y su resultado de simulación.

~~~sh
python3 -m tools.board_acceptance --case smoke \
  --port "$TP3_UART" --bitstream "$TP3_BITSTREAM" --rtl-commit "$TP3_RTL_SHA" \
  --operators Franco Federico --notes 'Basys 3; identificación y turno 1' \
  --output build/board-acceptance/plate-smoke
~~~

La CLI física usa pySerial 3.5, disponible en el entorno Python de viewrv.
Omitir `--case smoke` y usar otro directorio para correr el lote de TEST-PLAT-005.
`session.json` vincula el ensayo a commits, perfil, versión, SHA-256 del bitstream
y reportes de Vivado. Guardar los reportes y el bitstream con el directorio del
ensayo. Por ID, `uart.jsonl` registra los fragmentos TX/RX, los tiempos del host y
las capturas decodificadas. `result.json` y `status.json` se actualizan al
completar cada caso. El ejecutor se detiene ante una respuesta inesperada.
Conservar el intento y repetir los casos restantes en otro directorio. Los
timestamps del USB sirven para correlación con el host. Para verificar un Stop
físico, registrar una captura del enlace y conservarla junto al ID.

### Botón BTNC

- **RUN**. Con el loop `jal x0,0` y `02 01` completo, pulsar y soltar BTNC.
  Guardar el intervalo sin respuesta terminal y los intercambios `CHECK_READY`,
  `STEP/NO_IMAGE`, `RUN/NO_IMAGE` y la carga de recuperación.
- **LOAD**. El ejecutor declara 1024 bytes y envía solo 1020 después de `01 01`,
  en bloques separados por 70 ms desde el inicio de cada envío para dar tiempo
  al operador. Pulsar BTNC durante la transferencia y mantenerlo hasta el aviso.
  El comparador registra el pulso y el estímulo en `TEST-UART-013/C008/button-notes.txt`. Exigir
  ausencia de DONE y de respuesta de timeout, y luego la recuperación.
- **DEBUG**. La lista completa de DMEM dura unos 5,33 s después del cuerpo fijo.
  El ejecutor avisa cuando empieza a recibir la lista. Pulsar BTNC mientras hay
  bytes en vuelo y conservar la captura truncada y los rechazos `NO_IMAGE`.
- **PREPARING_READY**. Para `TEST-UART-013/C009`, partir de `NO_IMAGE`, enviar
  `05` y verificar `05 03`. Enviar `01 04 00 00 00 00`, esperar `01 01`
  y enviar el binario de `halt`, `0b 00 00 00`. Disparar el reset del botón
  durante la preparación, correlacionado con el final del último byte RX.
  La preparación recorre 2048 bytes a 50 MHz, unos 41 µs. Calibrar la ventana
  con la temporización real de RX/reset de la #15 antes del ensayo. Guardar junto al ID la
  traza temporal del estímulo y del reset, la ausencia de DONE y el posterior
  `CHECK_READY → NO_IMAGE al ejecutar → LOAD/RUN de recuperación`. La captura
  UART por sí sola no identifica esta fase. Este procedimiento documenta la
  instrumentación necesaria si se retoma la prueba física de C009.

### Recorrido desde viewrv

Usar el paquete o checkout de viewrv integrado con el bitstream de esa sesión.
En este worktree se importó el bitstream y se validaron su descriptor, su
huella y el inventario local de openFPGALoader 1.2.0 para Linux. En otro
checkout, repetir la importación con el SHA-256 de la #16 y su revisión RTL.
[Importador de bitstream de viewrv](../../software/resources/hardware/README.md)

El ejecutor UART directo queda disponible para cabeceras inválidas, abortos deliberados y transcripción byte a
byte. El cliente de producto conserva su adaptador UART y su registro de sesiones.

Para obtener las fuentes del recorrido, ejecutar `--case smoke` en modo
preparación. Los archivos `program-1.s`, `program-2.s` y `program-3.s`
corresponden a A, B y el fault. Para el loop usar
`TEST-EXEC-008/C001/program-1.s` del directorio preparado.

1. Abrir A, elegir **Ensamblar** y **Cargar**, y verificar la traducción y la
   confirmación de carga. En **Empezar debug**, avanzar un ciclo. Comparar
   ciclo 1, PC 4, RF y DMEM vacíos e IF/ID válido en PC 0. Continuar hasta
   FINISHED y conservar las vistas de registros, memoria y pipeline.
2. Finalizar la depuración, cargar A y ejecutar con **Correr**. Comparar
   FINISHED, ciclo 7, PC 20, `x1=7`, `x2=9` y los cuatro bytes de DMEM en
   0–3. Cargar y correr B con el mismo enlace. Comparar FINISHED, ciclo 3,
   PC 8, RF en cero y lista de DMEM vacía.
3. Cargar y correr el tercer programa. Comparar FAULT, causa 1, `fault_pc=4`,
   PC 8, ciclo 5 y `x1=1`. Cargar y correr el loop, detenerlo durante RUN y
   registrar el resultado de reset. Cargar B para verificar la recuperación.
4. Conservar capturas de la GUI, registros de sesión y versiones. Usar
   [TEST-PC-003, TEST-PC-004, TEST-PC-006, TEST-PC-008, TEST-PC-009, TEST-PC-014 y TEST-PC-023](../software/viewrv/verificacion.md)
   para registrar la evidencia por ID y los recorridos físicos del catálogo.

La CLI comparte el core y permite reproducir la sesión. `board prepare` es la
programación inicial del producto. Usar `board connect` al recuperar el mismo
enlace con la placa ya preparada. Para repetir desde CLI:

~~~sh
viewrv --version
viewrv --output json program assemble "$TP3_SOURCE"
viewrv --output json program load "$TP3_SOURCE"
viewrv --output json debug start --record --author Franco
viewrv --output json debug step
viewrv --output json session steps
viewrv --output json debug stop
viewrv --output json session logs > viewrv-step.json
viewrv --output json program load "$TP3_SOURCE"
viewrv --output json run start --record --author Franco
viewrv --output json session show
viewrv --output json session logs > viewrv-run.json
viewrv --output json board disconnect
~~~

Para el loop, usar `viewrv --output json run stop` desde una segunda terminal
mientras `run start` espera. Guardar su salida y el resultado terminal del trabajo
de CLI. Los registros progresivos quedan bajo `$XDG_STATE_HOME/viewrv/records/`
o la ubicación predeterminada del producto. Vincular cada `session_id` al ID de
aceptación y a `session.json` del ensayo. Guardar los intentos fallidos con sus
capturas y registrar las regresiones de los defectos que se corrijan.
