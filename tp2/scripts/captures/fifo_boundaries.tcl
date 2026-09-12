close_sim -quiet
set_property top fifo_tb [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -simset sim_1 -mode behavioral

set existing_waves [get_waves -quiet -recursive *]
if {[llength $existing_waves] > 0} {
  remove_wave -quiet $existing_waves
}

add_wave_divider "Operaciones"
add_wave -name clk /fifo_tb/clk
add_wave -name reset /fifo_tb/reset
add_wave -name wr /fifo_tb/wr
add_wave -name rd /fifo_tb/rd
add_wave -name write_data -radix hex /fifo_tb/write_data
add_wave -name read_data -radix hex /fifo_tb/read_data

add_wave_divider "Estado interno"
add_wave -name write_pointer -radix unsigned /fifo_tb/dut/write_pointer
add_wave -name read_pointer -radix unsigned /fifo_tb/dut/read_pointer
add_wave -name count -radix unsigned /fifo_tb/dut/count
add_wave -name write_accept /fifo_tb/dut/write_accept
add_wave -name read_accept /fifo_tb/dut/read_accept
add_wave -name full /fifo_tb/full
add_wave -name empty /fifo_tb/empty

restart
run all
puts "CAPTURA LISTA: muestre aproximadamente 0.02 us a 0.41 us."
