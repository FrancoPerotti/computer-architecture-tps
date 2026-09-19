close_sim -quiet
set_property top uart_tx_tb [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral

set existing_waves [get_waves -quiet -recursive *]
if {[llength $existing_waves] > 0} {
  remove_wave -quiet $existing_waves
}

add_wave_divider "Solicitud"
add_wave -name clk /uart_tx_tb/clk
add_wave -name tx_start /uart_tx_tb/tx_start
add_wave -name data_in -radix hex /uart_tx_tb/data_in

add_wave_divider "Transmisión"
add_wave -name state -radix hex /uart_tx_tb/dut/state
add_wave -name sample_count -radix unsigned /uart_tx_tb/dut/sample_count
add_wave -name bit_count -radix unsigned /uart_tx_tb/dut/bit_count
add_wave -name tx /uart_tx_tb/tx
add_wave -name tx_busy /uart_tx_tb/tx_busy
add_wave -name tx_done_tick /uart_tx_tb/tx_done_tick

restart
run all
puts "CAPTURA LISTA: muestre aproximadamente 0.02 us a 1.75 us."
