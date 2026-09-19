close_sim -quiet
set_property top alu_uart_top_tb [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral

set existing_waves [get_waves -quiet -recursive *]
if {[llength $existing_waves] > 0} {
  remove_wave -quiet $existing_waves
}

add_wave_divider "Puertos serie"
add_wave -name clk /alu_uart_top_tb/clk
add_wave -name serial_rx /alu_uart_top_tb/serial_rx
add_wave -name serial_tx /alu_uart_top_tb/serial_tx

add_wave_divider "Recepcion"
add_wave -name received_data -radix hex /alu_uart_top_tb/dut/uart/received_data
add_wave -name rx_done_tick /alu_uart_top_tb/dut/uart/rx_done_tick
add_wave -name rx_fifo_count -radix unsigned /alu_uart_top_tb/dut/uart/rx_fifo/count
add_wave -name rx_empty /alu_uart_top_tb/dut/rx_empty
add_wave -name read_uart /alu_uart_top_tb/dut/read_uart

add_wave_divider "Operacion y respuesta"
add_wave -name controller_state -radix hex /alu_uart_top_tb/dut/controller/state
add_wave -name write_data -radix hex /alu_uart_top_tb/dut/write_data
add_wave -name write_uart /alu_uart_top_tb/dut/write_uart
add_wave -name tx_fifo_count -radix unsigned /alu_uart_top_tb/dut/uart/tx_fifo/count
add_wave -name tx_full /alu_uart_top_tb/dut/tx_full
add_wave -name leds -radix hex /alu_uart_top_tb/leds

run 16.5 us
puts "CAPTURA LISTA: aplique Zoom Fit para mostrar 0 us a 16.5 us."
