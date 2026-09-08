set tp1_dir [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $tp1_dir tp1_sync]

if {[file exists $project_dir]} {
    error "Ya existe $project_dir. Abrir tp1_sync.xpr para usar ese proyecto."
}

create_project tp1_sync $project_dir -part xc7a35tcpg236-1
add_files -fileset sources_1 [list \
    [file join $tp1_dir alu.sv] \
    [file join $tp1_dir button_input.sv] \
    [file join $tp1_dir alu_top.sv]]
set_property top alu_top [get_filesets sources_1]
add_files -fileset constrs_1 [file join $tp1_dir basys3.xdc]
add_files -fileset sim_1 [list \
    [file join $tp1_dir alu_tb.sv] \
    [file join $tp1_dir button_input_tb.sv] \
    [file join $tp1_dir alu_top_tb.sv]]
set_property top alu_top_tb [get_filesets sim_1]
set_property file_type SystemVerilog [get_files [list \
    [file join $tp1_dir alu.sv] \
    [file join $tp1_dir alu_tb.sv]]]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
