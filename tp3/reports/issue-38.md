# Issue 38: comparación de frecuencia del sistema completo

Las implementaciones ruteadas se comparan en este informe; ninguna frecuencia queda validada físicamente por estos resultados. Se conserva el perfil de memoria REFERENCE y el reloj de entrada de 100 MHz de Basys 3. El valor por defecto sigue siendo 50 MHz.

## Dependencias de reloj

Clocking Wizard selecciona los divisores del MMCM para la frecuencia solicitada. El script calcula la salida a partir de esos divisores, redondea a Hz y pasa ese valor como `CLK_FREQ_HZ` a `basys3_top`, UART y controlador de protocolo. El generador de baud redondea su divisor entero para 19200 baud y sobremuestreo 16; LOAD y recuperación usan 100 ms cada uno, expresados en ciclos. La CPU avanza por ciclos del mismo dominio. El primario permanece en 10 ns. Las cotas asíncronas RX y TX permanecen en 20 ns, como en issue 16; no son el período del reloj funcional. Las excepciones de reset permanecen sin cambios.

## Ejecución en Windows

Desde PowerShell, en `tp3`, con Vivado y Git para Windows en PATH y soporte para `xc7a35tcpg236-1`. Usar una copia de trabajo accesible para ambos programas. Los directorios deben ser nuevos; cambiar `ensayo-01` para otra repetición. Ejecutar las cuatro corridas independientemente permite conservar resultados aunque una falle:

```powershell
foreach ($mhz in 50, 51, 52, 53) {
    vivado -mode batch -nolog -nojournal -source scripts/build_bitstream.tcl `
        -tclargs "build/issue-38/ensayo-01/$mhz" reference $mhz
    Write-Host "${mhz} MHz: código $LASTEXITCODE"
}
```

También funciona la interfaz anterior con dos argumentos, que solicita 50 MHz. Para generar únicamente el proyecto, usar `scripts/create_project.tcl` con los mismos argumentos. El manifiesto usa Git con `safe.directory` limitado a esa invocación, sin cambiar la configuración global. En Windows calcula SHA-256 mediante PowerShell si falta `sha256sum`. Si Git no está en PATH, el flujo falla e indica la dependencia. Una ruta de WSL debe ser accesible por Vivado y Git de Windows; si no lo es, usar una copia del repositorio accesible desde Windows.

Cada directorio incluye `clock-generator.rpt`, `build-info.txt`, el proyecto y `reports/`. El manifiesto registra solicitud, divisores, Hz redondeados para RTL, período y frecuencia derivados tras ruteo, versión, commit, estado Git y hashes; el bitstream REFERENCE se genera solo después de las comprobaciones del script. Los reportes `timing-summary.rpt`, `setup.rpt` y `hold.rpt` contienen WNS/TNS/WHS/THS/WPWS, caminos y skew; `uart-rx.rpt` y `uart-tx.rpt` muestran las cotas y su margen. Revisar también `clocks.rpt`, `pulse-width.rpt`, `drc.rpt`, `route-status.rpt`, `check-timing.rpt`, `exceptions*.rpt` y `cdc.rpt`. El script verifica reloj y excepciones, y rechaza setup o hold negativos; revisar explícitamente pulse width, DRC, cobertura UART y routing antes de considerar la implementación aprobada.

La comprobación del período del reloj ruteado tolera 0,001 ns de redondeo de Vivado. Si no coincide con el valor calculado de los divisores, el flujo se detiene. La frecuencia efectiva de STA debe consultarse en el manifiesto y clocks.rpt, no inferirse de la frecuencia solicitada.

| Solicitada MHz | Efectiva MHz | Periodo STA ns | WNS / TNS ns | WHS / THS ns | WPWS ns | UART RX / TX ns | Routing | Bitstream |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 50 | 50 | 20,000 | +1,065 / 0 | +0,037 / 0 | +3,000 | +17,149 / +13,725 | Sin errores | Si |
| 51 | 51 | 19,608 | +1,100 / 0 | +0,051 / 0 | +3,000 | +16,968 / +13,301 | Sin errores | Si |
| 52 | 52 | 19,231 | +1,536 / 0 | +0,037 / 0 | +3,000 | +17,026 / +13,701 | Sin errores | Si |
| 53 | 53 | 18,868 | +0,584 / 0 | +0,073 / 0 | +3,000 | +17,120 / +14,005 | Sin errores | Si |

## Resultados del ensayo 01

Vivado 2026.1, build 6511674; part xc7a35tcpg236-1; perfil REFERENCE; commit `c5ef2cfb63ac928f539301c7d8c91fae27ea4641`. Los manifiestos registran un arbol con cambios locales; los hashes de RTL, scripts y restricciones son iguales en las cuatro corridas. La frecuencia efectiva proviene de los divisores MMCM; el periodo STA se muestra redondeado por Vivado. Los margenes UART corresponden a las cotas RX y TX de 20 ns.

Las cuatro corridas ruteadas reportan cero violaciones de setup, hold o pulse width, cero hallazgos DRC y cero errores de routing. Los reportes estan en `build/issue-38/ensayo-01/<MHz>/reports/`; el manifiesto y el bitstream estan un nivel arriba. Las ejecuciones de 51, 52 y 53 MHz terminaron con codigo 0; los logs y archivos de codigo de salida estan en `build/issue-38/ensayo-01/`. Un primer intento de 51 MHz en el sandbox fallo antes de crear el proyecto por el inicio de aplicaciones de Vivado; se conserva en `51-console.log` con codigo 1. La corrida exitosa esta en `51-retry-console.log`.

Caminos criticos; nombres abreviados desde la jerarquia de `gen_supported_profile.system`. Los retardos y skew estan en ns:

| MHz | Setup: origen a destino | Retardo / skew | Hold: origen a destino | Retardo / skew |
| --- | --- | --- | --- | --- |
| 50 | processor/exmem rd[1] a global_fsm state[11] | 18,865 / -0,017 | UART RX shift_register[0] a RX FIFO RAMA/I | 0,197 / +0,013 |
| 51 | processor/exmem rd[2] a global_fsm state[10] | 18,357 / -0,049 | processor IF pc_reg[27] a IF/ID pc[27] | 0,327 / +0,264 |
| 52 | processor/exmem instruction[7] a global_fsm state[8] | 17,557 / -0,034 | UART RX shift_register[0] a RX FIFO RAMA/I | 0,197 / +0,013 |
| 53 | processor ID/EX instruction[3] a MEM/WB instruction[0]/CE | 17,733 / -0,046 | processor loader partial_word[6] a IMEM RAMA/I | 0,233 / +0,013 |

Los endpoints completos y el detalle de cada camino estan en `setup.rpt` y `hold.rpt`; los margenes UART estan en `uart-rx.rpt` y `uart-tx.rpt`.

| MHz | SHA-256 de tp3-reference.bit |
| --- | --- |
| 50 | `CBBCDE423194B14AD20C036E9102BC9EC581C0064352D682C1D62348D4DF8106` |
| 51 | `BB0BC726824E49274A6DAABCED46784B0CF0DB1F2620F063711535F9D0174C54` |
| 52 | `7A73772206B1FADCCBCF689D24C95189AF65BC98CFAE3941690A1C6858758734` |
| 53 | `6EF7ACB692AE612EAF9C9716C72A4DA2153CA782D79A0629AED1E33F2C899FA4` |

El margen varia con placement y routing y estos resultados no establecen una frecuencia maxima garantizada. Quedan pendientes las pruebas de arranque, reset, UART, protocolo y CPU en placa; los tres puntos seleccionados para ellas se indican mas abajo.

## Exploracion post-routing: 55 a 65 MHz

Se ejecutaron seis implementaciones completas adicionales con Vivado 2026.1, build 6511674, part `xc7a35tcpg236-1`, perfil REFERENCE y commit `c5ef2cfb63ac928f539301c7d8c91fae27ea4641`. Los manifiestos `build-info.txt` guardan el estado del arbol con cambios locales y los hashes. Los hashes de RTL y restricciones coinciden en las seis corridas. Tras 55 y 60 se corrigio el selector de solo routing en `build_bitstream.tcl`; los hashes del script difieren, sin cambios en RTL ni restricciones.

| Solicitada MHz | Efectiva MHz | Periodo STA ns | WNS ns | TNS ns | WHS ns | THS ns | WPWS ns | UART RX / TX margen ns | DRC / routing | Resultado |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 55 | 55 | 18,182 | +0,549 | 0 | +0,061 | 0 | +3,000 | +17,248 / +14,314 | 0 / 0 | Cumple |
| 60 | 60 | 16,667 | +0,367 | 0 | +0,024 | 0 | +3,000 | +17,178 / +13,885 | 0 / 0 | Cumple |
| 62 | 62 | 16,129 | +0,035 | 0 | +0,027 | 0 | +3,000 | +16,921 / +13,218 | 0 / 0 | Cumple |
| 63 | 63 | 15,873 | +0,002 | 0 | +0,061 | 0 | +3,000 | +16,970 / +13,724 | 0 / 0 | Cumple por 2 ps |
| 64 | 64 | 15,625 | -0,721 | -21,901 | +0,061 | 0 | +3,000 | +16,977 / +13,806 | 0 / 0 | Falla setup: 171 endpoints |
| 65 | 65 | 15,385 | -0,346 | -8,024 | +0,054 | 0 | +3,000 | +17,168 / +14,193 | 0 / 0 | Falla setup: 96 endpoints |

La frecuencia efectiva se calculo de los divisores MMCM; el periodo STA esta redondeado por Vivado. Las columnas UART son margenes de las restricciones RX/TX de 20 ns. Todos los puntos reportaron cero hallazgos DRC y cero errores de routing. Los codigos de salida son 0 a 55, 60, 62 y 63 MHz, y 1 a 64 y 65 MHz por setup negativo. Los seis directorios contienen reportes, manifiestos y proyectos en `build/issue-38/ensayo-03/<MHz>/`; logs y codigos estan en `build/issue-38/ensayo-03/`. Los reportes completos de setup y hold identifican los endpoints jerarquicos.

| MHz | Setup: origen a destino abreviados | Retardo / skew ns | Hold: origen a destino abreviados | Retardo / skew ns |
| --- | --- | --- | --- | --- |
| 55 | EX/MEM rd[3] a global_fsm state[7] | 17,511 / -0,032 | loader partial_word[18] a IMEM RAMA/I | 0,221 / +0,013 |
| 60 | ID/EX instruction[0] a global_fsm state[7] | 16,159 / -0,037 | UART RX FIFO write_pointer[0] a RAMA/WADR0 | 0,347 / +0,013 |
| 62 | ID/EX instruction[21] a global_fsm state[11] | 15,952 / -0,043 | IF/ID pc[27] a ID/EX pc[27] | 0,358 / +0,265 |
| 63 | ID/EX instruction[20] a global_fsm state[10] | 15,742 / -0,040 | loader partial_word[18] a IMEM RAMA/I | 0,221 / +0,013 |
| 64 | ID/EX rs1[2] a global_fsm state[11] | 16,259 / -0,040 | loader partial_word[0] a IMEM RAMA/I | 0,221 / +0,013 |
| 65 | ID/EX instruction[0] a global_fsm state[11] | 15,604 / -0,028 | controlador inactivity_count[12] a [16] | 0,510 / +0,351 |

El extremo mas alto que cumple es 63 MHz y el menor que falla es 64 MHz, en estas implementaciones; la relacion no tiene por que ser monotona al cambiar placement y routing. Se seleccionan 50, 55 y 60 MHz para comparar en placa sin decidir todavia una frecuencia operativa. Ninguna de estas corridas demuestra funcionamiento en placa ni una frecuencia maxima garantizada.

Por un error en el selector de solo routing se generaron bitstreams a 55 y 60 MHz antes de corregirlo; se conservaron. Sus SHA-256 son respectivamente `025893CB5DDBF0008EF777A18570DE4409B63C46B8F533683C7EE82DF3C77AD7` y `1505D1FEC56D8318461C70F3510C73B6B72AC3BF9E5C5DC105FCC702791D8A1F`. A 62, 63, 64 y 65 MHz no se genero bitstream. El primer intento de 55 MHz en `ensayo-02` se interrumpio durante sintesis tras un reinicio; se conservo sin reutilizarlo. Una invocacion previa interpreto 55 y 60 como 5560 y fue rechazada antes de crear un proyecto; su log tambien se conserva.

Para repetir un punto desde `tp3` con Git y Vivado en PATH, elegir un directorio que no exista:

```powershell
$env:TP3_ROUTE_ONLY = '1'
vivado -mode batch -nolog -nojournal -source scripts/build_bitstream.tcl `
    -tclargs build/issue-38/nuevo-ensayo/63 reference 63
$codigo = $LASTEXITCODE
Remove-Item Env:TP3_ROUTE_ONLY
```

Capturar la salida y `$codigo` en archivos nuevos como se hizo en `ensayo-03/run.ps1`. El script guarda los reportes antes de devolver error por setup o hold; revisar tambien pulse width, UART, DRC y routing. Para generar un bitstream en una corrida nueva que cumpla, ejecutar sin `TP3_ROUTE_ONLY`. Quedan pendientes pruebas de arranque, reset, UART, protocolo y CPU en Basys 3.

## Preparación de la validación física

Se seleccionan 50 MHz como referencia, 55 MHz como incremento moderado y
60 MHz como incremento mayor con setup positivo. Ninguna es una frecuencia
operativa definitiva. [Manifiesto de los tres bitstreams](issue-38-bitstreams.md):
incluye rutas, hashes, fuentes y procedencia de los reportes.

Para cada frecuencia, conservar el `.bit`, su `build-info.txt` y `reports/`,
verificar su SHA-256 y registrar placa, puerto, versiones y operador. Usar un
directorio de evidencia nuevo para cada caso. Seguir el recorrido existente en
[aceptación de placa](../docs/verification/board_acceptance.md), con UART a
19200 baud, 8N1 y sin control de flujo. `viewrv board prepare` programa el
**bitstream incluido en sus recursos**: no selecciona un `.bit` arbitrario por
un argumento de CLI. Antes de cada caso, importar el archivo seleccionado con
el [importador de bitstream](../software/resources/hardware/README.md),
verificar el descriptor y el SHA-256 incorporados y conservar los originales.
El commit indicado al importador es la base; para identificar las fuentes no
commiteadas también debe conservarse el manifiesto de la corrida. No sustituir
silenciosamente un recurso de producto ya aprobado.

Enumerar dispositivo y puerto con `viewrv board devices` y `viewrv board ports`;
programar y comprobar UART mediante `viewrv board prepare --device <id> --port
<puerto>`. Comprobar arranque y reset con el recorrido documentado, incluido
BTNC y la recuperación del enlace. Preparar el programa A del caso `smoke`
con `python3 -m tools.board_acceptance --case smoke --output <directorio-nuevo>`;
usar el `program-1.s` generado. Su fuente es `addi x1,x0,7`, `sw x1,0(x0)`,
`addi x2,x0,9`, `halt`.

Con el archivo preparado como `$TP3_SOURCE`, seguir los comandos reales de la
sección «Recorrido desde viewrv» del documento de aceptación: ensamblar y
cargar con `viewrv --output json program assemble "$TP3_SOURCE"` y
`viewrv --output json program load "$TP3_SOURCE"`; iniciar debug con
`viewrv --output json debug start --record --author Franco`, avanzar con
`viewrv --output json debug step` y consultar `viewrv --output json session
steps`. El primer STEP esperado tiene ciclo 1, PC 4 e IF/ID válido en PC 0.
Finalizar debug con `viewrv --output json debug stop`, volver a cargar A y
ejecutar `viewrv --output json run start --record --author Franco`; consultar
`viewrv --output json session show` y conservar `session logs`. El resultado
esperado del RUN es FINISHED, ciclo 7, PC 20, x1=7, x2=9 y DMEM 0–3 igual a
`07 00 00 00`. Registrar respuestas, capturas y evidencia de programación.

| Caso | Programación y arranque | Reset y UART | LOAD / STEP | RUN y resultado | Estado físico |
| --- | --- | --- | --- | --- | --- |
| 50 MHz | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente de ejecución física |
| 55 MHz | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente de ejecución física |
| 60 MHz | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente de ejecución física |

## Revisión final sin placa

Se verificaron los reportes ruteados y SHA-256 de 50, 55 y 60 MHz. Sus 48
hashes de RTL y restricciones coincidían con el árbol antes de la revisión
Docker; después se corrigió el ancho de la comparación del temporizador y se
formatearon tres archivos RTL, cuyos hashes cambiaron. Los bitstreams existentes
corresponden a la versión anterior; para acreditar físicamente el RTL actual
se deben generar nuevas implementaciones y volver a revisar los reportes.
Los scripts de build posteriores también tienen hashes distintos: los
manifiestos originales conservan sus versiones. El flujo genera reportes de pulse width,
DRC y routing, que deben revisarse; la detención automática por slack negativo
comprueba setup y hold. No se debe interpretar el código 0 como aprobación
automática de DRC, pulse width o routing.

En Ubuntu WSL, Python 3.12.3: `python3 -m unittest
software.tests.test_assembler` pasó 114 de 114; `python3 -m unittest -v
scripts.tests.test_board_acceptance` pasó 9 de 9. La validación del catálogo
`python3 scripts/run_tests.py --validate` y la selección `--test TEST-PLAT-002
--test TEST-UART-006 --test TEST-UART-009 --format json` no arrancaron por
ausencia de `check-jsonschema` (cero ejecuciones de simulación). En este entorno
no se encontraron make, Icarus, Verilator ni las herramientas de formato y
lint fijadas por el repositorio: formato, lint, revisión estructural y
regresión RTL completa permanecen sin ejecutar. La verificación de espacios
`git diff --check` pasó. Estas pruebas de host no acreditan funcionamiento de
UART o CPU RTL en placa.

La ejecución general `python3 -m unittest discover -s scripts/tests` se
interrumpió después de observar fallos y errores; no se dispone de un conteo
final y no se considera aprobada. Como diagnóstico, `python3 -m unittest -f
scripts.tests.test_verification_manifest` ejecutó una prueba y falló porque
no se encontró `check-jsonschema`. Es necesario repetir la suite completa en
el entorno fijado y evaluar cualquier fallo restante; no se atribuyen todos
los fallos observados a esa única dependencia sin evidencia.

### Comprobación posterior con Docker

La imagen publicada fijada en `docker/image.ref` permitió ejecutar formato,
lint, validación y revisión estructural sobre una copia temporal del checkout
con finales LF (el checkout Windows tenía CRLF). Tras corregir el ancho de la
comparación del temporizador y aplicar el formato del proyecto, los cuatro
controles pasaron. La imagen publicada no contenía `g++`, necesario para la
regresión RTL; se construyó la imagen local desde `tp3/docker/Dockerfile`.
Con ella pasaron 60 pruebas de infraestructura y 114 de software. Se detuvo
la regresión RTL completa a petición del usuario, por lo que no tiene un
resultado global. Una selección dirigida de `TEST-PLAT-002/C001`,
`TEST-UART-001/C001` y `TEST-UART-006/C013` pasó 12 de 12 ejecuciones, sin
fallos ni errores. Las simulaciones dirigidas usan el reloj predeterminado;
no acreditan comportamiento de UART ni timeouts a 55 o 60 MHz en placa.
Los logs están en `build/issue-38-docker-02/` y `build/issue-38-docker-04/`;
la ejecución interrumpida queda en `build/issue-38-docker-03/`.
