set testbenches {
  alu_tb
  baud_tick_gen_tb
  fifo_tb
  uart_rx_tb
  uart_tx_tb
  uart_core_tb
  alu_uart_controller_tb
  alu_uart_top_tb
}

set completed {}
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]

foreach testbench $testbenches {
  close_sim -quiet
  set_property top $testbench [get_filesets sim_1]
  update_compile_order -fileset sim_1

  puts "RUN: $testbench"
  if {[catch {
    launch_simulation -simset sim_1 -mode behavioral
    run all
  } failure]} {
    puts "FAIL: $testbench"
    puts $failure
    error "Regression interrumpida en $testbench"
  }

  lappend completed $testbench
}

puts ""
puts "========== RESUMEN DE REGRESION =========="
foreach testbench $completed {
  puts "PASS: $testbench"
}
puts "PASS: [llength $completed]/[llength $testbenches] testbenches completados con XSim"
puts "==========================================="
