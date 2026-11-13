source [file join [file dirname [info script]] vivado_common.tcl]

if {$argc != 2 || [lindex $argv 1] ni {reference uart-fixture}} {
    error "Uso: -tclargs <directorio-nuevo> <reference|uart-fixture>"
}
lassign $argv output_path build_mode

set sources [rtl_files]
set system_top [file join $tp3_dir rtl system_top.sv]
if {$build_mode eq "reference"} {
    if {![file isfile $system_top]} {
        error "El build REFERENCE requiere el system_top real de la issue #15"
    }
} else {
    set sources [lsearch -all -inline -not -exact $sources $system_top]
    lappend sources [file join $tp3_dir tb fixtures system_top.uart_loopback.sv]
}

set output_dir [create_output_dir $output_path]
create_project tp3_basys3 [file join $output_dir project] -part $basys3_part
set_property target_language Verilog [current_project]
add_files -fileset sources_1 $sources
set_property top basys3_top [get_filesets sources_1]
# Conservar los nombres de los endpoints de timing de UART y reset.
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]

set board_xdc [file join $tp3_dir constraints basys3.xdc]
set paths_tcl [file join $tp3_dir constraints basys3_paths.tcl]
add_files -fileset constrs_1 [list $board_xdc $paths_tcl]
set_property FILE_TYPE Tcl [get_files $paths_tcl]
set_property USED_IN_SYNTHESIS false [get_files $paths_tcl]
set_property PROCESSING_ORDER LATE [get_files $paths_tcl]

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clock_generator
set wizard [get_ips clock_generator]
set_property -dict [list \
    CONFIG.PRIMITIVE MMCM \
    CONFIG.PRIM_IN_FREQ 100.000 \
    CONFIG.PRIM_SOURCE {Single ended clock capable pin} \
    CONFIG.NUM_OUT_CLKS 1 \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 50.000 \
    CONFIG.CLKOUT1_REQUESTED_PHASE 0.000 \
    CONFIG.CLKOUT1_REQUESTED_DUTY_CYCLE 50.000 \
    CONFIG.CLKOUT1_DRIVES BUFG \
    CONFIG.USE_LOCKED true \
    CONFIG.USE_RESET true \
    CONFIG.RESET_TYPE ACTIVE_HIGH \
    CONFIG.USE_DYN_RECONFIG false \
    CONFIG.USE_DYN_PHASE_SHIFT false \
    CONFIG.USE_SPREAD_SPECTRUM false] $wizard

# La síntesis global deriva el clock del MMCM a partir del único clock de placa.
set wizard_xci [get_files clock_generator.xci]
set_property GENERATE_SYNTH_CHECKPOINT false $wizard_xci
generate_target all $wizard
set wizard_xdc [get_files -of_objects $wizard_xci -filter {FILE_TYPE == XDC}]
if {[llength $wizard_xdc] == 0} {
    error "Clocking Wizard no generó los XDC esperados para revisar la definición primaria"
}
set_property IS_ENABLED false $wizard_xdc
update_compile_order -fileset sources_1

set flow_inputs [list $board_xdc $paths_tcl [get_property NAME $wizard_xci]]
foreach script {create_project.tcl build_bitstream.tcl vivado_common.tcl} {
    lappend flow_inputs [file join $tp3_dir scripts $script]
}
write_build_info $output_dir $build_mode [concat $sources $flow_inputs]
report_compile_order -constraints -file [file join $output_dir constraints-order.rpt]
report_property -file [file join $output_dir clock-generator.rpt] $wizard
puts "Proyecto generado en $output_dir/project/tp3_basys3.xpr"
