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

add_wave_divider "Detección de errores"
add_wave -name state -radix hex /uart_rx_tb/dut/state
add_wave -name sample_count -radix unsigned /uart_rx_tb/dut/sample_count
add_wave -name frame_error_tick /uart_rx_tb/frame_error_tick
add_wave -name rx_done_tick /uart_rx_tb/rx_done_tick
add_wave -name frame_error_count -radix unsigned /uart_rx_tb/frame_error_count
add_wave -name done_count -radix unsigned /uart_rx_tb/done_count

restart
run all
puts "CAPTURA LISTA: use microsegundos y muestre aproximadamente 6.95 us a 9.10 us."
