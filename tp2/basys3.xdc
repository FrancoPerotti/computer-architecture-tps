## Reloj de 100 MHz
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk -period 10.000 -waveform {0.000 5.000} [get_ports clk]

## Pulsador central utilizado como reset.
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btn_reset]

## Conversor USB-UART integrado.
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports serial_rx]
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports serial_tx]

## Resultado y flags: LED7..0=result, LED8=Z, LED9=C, LED10=V.
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {leds[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {leds[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {leds[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {leds[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {leds[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {leds[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {leds[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {leds[7]}]
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports {leds[8]}]
set_property -dict { PACKAGE_PIN V3 IOSTANDARD LVCMOS33 } [get_ports {leds[9]}]
set_property -dict { PACKAGE_PIN W3 IOSTANDARD LVCMOS33 } [get_ports {leds[10]}]

## Solo la primera etapa de cada sincronizador recibe estas entradas asincronas.
set_false_path -from [get_ports {btn_reset serial_rx}]

## UART y LEDs no poseen un reloj de captura externo sincrono con sys_clk.
set_false_path -to [get_ports {serial_tx leds[*]}]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
