set tp2_dir [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $tp2_dir vivado tp2_uart]

if {[file exists $project_dir]} {
    error "Ya existe $project_dir. Abrir tp2_uart.xpr o eliminar el proyecto generado."
}

create_project tp2_uart $project_dir -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]

set rtl_files [list \
    [file join $tp2_dir rtl reset_sync.sv] \
    [file join $tp2_dir rtl serial_input_sync.sv] \
    [file join $tp2_dir rtl baud_tick_gen.sv] \
    [file join $tp2_dir rtl fifo.sv] \
    [file join $tp2_dir rtl uart_rx.sv] \
    [file join $tp2_dir rtl uart_tx.sv] \
    [file join $tp2_dir rtl uart_core.sv] \
    [file join $tp2_dir rtl alu.sv] \
    [file join $tp2_dir rtl alu_uart_controller.sv] \
    [file join $tp2_dir rtl alu_uart_top.sv]]

set simulation_files [glob -nocomplain [file join $tp2_dir tb *.sv]]

add_files -fileset sources_1 $rtl_files
set_property file_type SystemVerilog [get_files $rtl_files]
set_property top alu_uart_top [get_filesets sources_1]

add_files -fileset constrs_1 [file join $tp2_dir basys3.xdc]

add_files -fileset sim_1 $simulation_files
set_property file_type SystemVerilog [get_files $simulation_files]
set_property top alu_uart_top_tb [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Proyecto creado en $project_dir/tp2_uart.xpr"
