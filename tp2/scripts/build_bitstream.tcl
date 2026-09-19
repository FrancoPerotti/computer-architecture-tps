set tp2_dir [file normalize [file join [file dirname [info script]] ..]]
set project_file [file join $tp2_dir vivado tp2_uart tp2_uart.xpr]
set report_dir [file join $tp2_dir reports]
set build_dir [file join $tp2_dir build]

if {![file exists $project_file]} {
    source [file join $tp2_dir scripts create_project.tcl]
} else {
    open_project $project_file
}

file mkdir $report_dir
file mkdir $build_dir

reset_runs synth_1
launch_runs synth_1 -jobs 4
wait_on_runs synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
set synth_progress [get_property PROGRESS [get_runs synth_1]]
if {$synth_progress ne "100%" || ![string match "*Complete*" $synth_status]} {
    error "La sintesis no se completo: $synth_status ($synth_progress)."
}

open_run synth_1
report_utilization -file [file join $report_dir synthesis_utilization_summary.rpt]
report_utilization -hierarchical -file [file join $report_dir synthesis_utilization.rpt]
report_methodology -file [file join $report_dir synthesis_methodology.rpt]

launch_runs impl_1 -jobs 4
wait_on_runs impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
set impl_progress [get_property PROGRESS [get_runs impl_1]]
if {$impl_progress ne "100%" || ![string match "*Complete*" $impl_status]} {
    error "La implementacion no se completo: $impl_status ($impl_progress)."
}

open_run impl_1
report_utilization -file [file join $report_dir implementation_utilization_summary.rpt]
report_utilization -hierarchical -file [file join $report_dir implementation_utilization.rpt]
report_methodology -file [file join $report_dir implementation_methodology.rpt]
report_timing_summary -delay_type min_max -report_unconstrained \
    -file [file join $report_dir timing_summary.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_drc -file [file join $report_dir drc.rpt]
write_bitstream -force [file join $build_dir alu_uart_top.bit]

puts "Bitstream: $build_dir/alu_uart_top.bit"
puts "Reportes: $report_dir"
