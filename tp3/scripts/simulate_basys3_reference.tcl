source [file join [file dirname [info script]] create_project.tcl]
if {$build_mode ne "reference"} {
    error "La simulación de placa requiere el sistema REFERENCE"
}

set bench basys3_reference_tb
set sim_files [list \
    [file join $tp3_dir tb system_uart_host.sv] \
    [file join $tp3_dir tb $bench.sv]]
add_files -fileset sim_1 $sim_files
set_property top $bench [get_filesets sim_1]
set_property -name xsim.elaborate.xelab.more_options -value {-timescale 1ns/1ps} \
    -objects [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
set log_path [file join [get_property DIRECTORY [current_project]] tp3_basys3.sim sim_1 behav xsim simulate.log]
set log [open $log_path r]
set result [read $log]
close $log
if {![regexp -line {^PASS TEST-UART-013/C001 Basys3 REFERENCE 19200 baud$} $result]} {
    error "Falló la simulación de plataforma. Revisar $log_path"
}
puts "PASS TEST-UART-013/C001 Basys3 REFERENCE 19200 baud"
