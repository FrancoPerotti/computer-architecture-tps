source [file join [file dirname [info script]] create_project.tcl]

proc run_to_completion {name args} {
    launch_runs $name {*}$args
    wait_on_runs $name
    set run [get_runs $name]
    set status [get_property STATUS $run]
    if {[get_property PROGRESS $run] ne "100%" || ![string match "*Complete*" $status]} {
        error "Falló $name: $status. Revisar [get_property DIRECTORY $run]/runme.log"
    }
    open_run $name
}

set report_dir [file join $output_dir reports]
file mkdir $report_dir
run_to_completion synth_1
report_utilization -hierarchical -file [file join $report_dir synthesis-utilization.rpt]
report_ram_utilization -include_lutram -file [file join $report_dir synthesis-ram.rpt]
close_design

run_to_completion impl_1 -to_step route_design
report_clocks -file [file join $report_dir clocks.rpt]
report_clock_utilization -file [file join $report_dir clock-utilization.rpt]
report_clock_interaction -file [file join $report_dir clock-interaction.rpt]
report_io -file [file join $report_dir io.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_route_status -file [file join $report_dir route-status.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_utilization -hierarchical -file [file join $report_dir utilization-hierarchy.rpt]
report_ram_utilization -include_lutram -file [file join $report_dir ram.rpt]
report_exceptions -coverage -file [file join $report_dir exceptions.rpt]
report_exceptions -ignored -file [file join $report_dir exceptions-ignored.rpt]
check_timing -verbose -file [file join $report_dir check-timing.rpt]
report_pulse_width -file [file join $report_dir pulse-width.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $report_dir timing-summary.rpt]
report_timing -delay_type max -max_paths 10 -file [file join $report_dir setup.rpt]
report_timing -delay_type min -max_paths 10 -file [file join $report_dir hold.rpt]

set board_clock [get_clocks -quiet -of_objects [get_ports clk_100mhz_i]]
set uart_clock_pin [get_pins -quiet -hierarchical -filter {NAME =~ */rx_synchronizer/serial_meta_reg/C}]
set functional_clock [get_clocks -quiet -of_objects $uart_clock_pin]
if {$board_clock ne "clk_board_100" || [get_property PERIOD $board_clock] != 10.0 ||
        [llength $functional_clock] != 1 || [get_property PERIOD $functional_clock] != 20.0 ||
        [get_property MASTER_CLOCK $functional_clock] ne $board_clock} {
    error "Se requieren clk_board_100 y su derivado de 50 MHz. Revisar clocks.rpt"
}

# Verificar las dos cotas UART por separado, también si el peor camino es interno.
set rx_d [get_pins -hierarchical -filter {NAME =~ */rx_synchronizer/serial_meta_reg/D}]
set tx_c [get_pins -hierarchical -filter {NAME =~ */transmitter_datapath/tx_reg_reg/C}]
set uart_routes [list \
    rx [get_ports uart_rx_i] $rx_d \
    tx $tx_c [get_ports uart_tx_o]]
foreach {name from to} $uart_routes {
    set path [get_timing_paths -from $from -to $to -delay_type max -max_paths 1]
    if {[llength $path] != 1 || [get_property REQUIREMENT $path] != 20.0} {
        error "Falta la cota activa de 20 ns para UART $name"
    }
    report_timing -from $from -to $to -delay_type max -file [file join $report_dir uart-$name.rpt]
}

set button [get_ports reset_btn_i]
set mmcm [get_cells -quiet -hierarchical -filter {REF_NAME == MMCME2_ADV || REF_NAME == MMCME2_BASE}]
if {[llength $mmcm] != 1} {
    error "Basys 3 requiere un MMCM; encontrados: $mmcm"
}
set mmcm_reset [get_pins -of_objects $mmcm -filter {REF_PIN_NAME == RST}]
set mmcm_reset_sources [all_fanin -flat -startpoints_only -to $mmcm_reset]
if {$mmcm_reset_sources ne $button} {
    error "RST del MMCM debe recibir solo el botón; encontrados: $mmcm_reset_sources"
}
set reset_async [get_pins -quiet -hierarchical -filter {NAME =~ *.reset_conditioner/reset_pipe_reg*/PRE || NAME =~ *.reset_conditioner/reset_pipe_reg*/CLR}]
if {[llength $reset_async] != 2} {
    error "Se requieren dos pines asíncronos de reset_sync; encontrados: $reset_async"
}
foreach pin $reset_async {
    if {[llength [get_timing_paths -quiet -user_ignored -from $button -to $pin -max_paths 1]] != 1} {
        error "Falta la excepción de reset asíncrono para $pin"
    }
}

foreach delay {max min} {
    set worst [get_timing_paths -delay_type $delay -max_paths 1]
    if {[llength $worst] != 1 || [get_property SLACK $worst] < 0} {
        error "El análisis $delay no cumple timing. Revisar timing-summary.rpt"
    }
}

if {$build_mode eq "reference"} {
    set bitstream [file join $output_dir tp3-reference.bit]
    write_bitstream $bitstream
    set manifest [open [file join $output_dir build-info.txt] a]
    puts $manifest "SHA-256 del bitstream:"
    puts $manifest [exec sha256sum -- $bitstream]
    close $manifest
    puts "Bitstream REFERENCE: $bitstream"
}
puts "Reportes $build_mode: $report_dir"
