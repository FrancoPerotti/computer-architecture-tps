close_sim -quiet
set_property top alu_uart_controller_tb [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral

set existing_waves [get_waves -quiet -recursive *]
if {[llength $existing_waves] > 0} {
  remove_wave -quiet $existing_waves
}

add_wave_divider "Entrada"
add_wave -name clk /alu_uart_controller_tb/clk
add_wave -name r_data -radix hex /alu_uart_controller_tb/r_data
add_wave -name rx_empty /alu_uart_controller_tb/rx_empty
add_wave -name rd_uart /alu_uart_controller_tb/rd_uart

add_wave_divider "Control y operacion"
add_wave -name state -radix hex /alu_uart_controller_tb/dut/state
add_wave -name data_a -radix hex /alu_uart_controller_tb/dut/data_a
add_wave -name data_b -radix hex /alu_uart_controller_tb/dut/data_b
add_wave -name opcode -radix hex /alu_uart_controller_tb/dut/opcode
add_wave -name capture_result /alu_uart_controller_tb/dut/capture_result
add_wave -name result_reg -radix hex /alu_uart_controller_tb/dut/result_reg

add_wave_divider "Respuesta"
add_wave -name tx_full /alu_uart_controller_tb/tx_full
add_wave -name w_data -radix hex /alu_uart_controller_tb/w_data
add_wave -name wr_uart /alu_uart_controller_tb/wr_uart
add_wave -name leds -radix hex /alu_uart_controller_tb/leds

restart
run all
puts "CAPTURA LISTA: muestre aproximadamente 0.18 us a 0.49 us."
