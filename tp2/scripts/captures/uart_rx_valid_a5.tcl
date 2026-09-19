# Prepara en XSim la recepción válida de 8'hA5 ejecutada por uart_rx_tb.
# Este script se ejecuta desde la consola Tcl del proyecto tp2_uart.

if {[llength [get_projects -quiet]] == 0} {
  error "Abra tp2/vivado/tp2_uart/tp2_uart.xpr antes de ejecutar este script."
}

close_sim -quiet
set_property top uart_rx_tb [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral

set existing_waves [get_waves -quiet -recursive *]
if {[llength $existing_waves] > 0} {
  remove_wave -quiet $existing_waves
}

add_wave_divider "Entrada"
add_wave -name clk /uart_rx_tb/clk
add_wave -name rx /uart_rx_tb/rx

add_wave_divider "Recepción"
add_wave -name state -radix hex /uart_rx_tb/dut/state
add_wave -name sample_count -radix unsigned /uart_rx_tb/dut/sample_count
add_wave -name bit_count -radix unsigned /uart_rx_tb/dut/bit_count
add_wave -name data_reg -radix hex /uart_rx_tb/dut/data_reg

add_wave_divider "Salida"
add_wave -name data_out -radix hex /uart_rx_tb/data_out
add_wave -name rx_done_tick /uart_rx_tb/rx_done_tick

restart
run all
puts "CAPTURA LISTA: seleccione el intervalo 3.50 us a 5.40 us."
