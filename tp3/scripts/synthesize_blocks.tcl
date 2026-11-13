source [file join [file dirname [info script]] vivado_common.tcl]

if {$argc != 1} {
    error "Uso: -tclargs <directorio-nuevo>"
}
set output_dir [create_output_dir [lindex $argv 0]]
set wrapper [file join $tp3_dir rtl basys3_top.sv]
set sources [lsearch -all -inline -not -exact [rtl_files] $wrapper]
write_build_info $output_dir synthesis-partial [concat $sources [list \
    [file normalize [info script]] [file join $tp3_dir scripts vivado_common.tcl]]]

# processor_top conserva las cinco etapas y las memorias en su contexto real.
foreach {top generics} {
    instruction_memory {IMEM_CAPACITY_BYTES=1024}
    data_memory {DMEM_CAPACITY_BYTES=2048}
    register_file {}
    processor_top {IMEM_CAPACITY_BYTES=1024 DMEM_CAPACITY_BYTES=2048}
} {
    set generic_args {}
    foreach generic $generics {
        lappend generic_args -generic $generic
    }
    # Aislar el fileset para que Vivado no arrastre generics del bloque anterior.
    create_project -in_memory -part $basys3_part
    read_verilog -sv $sources
    synth_design -top $top -part $basys3_part -mode out_of_context {*}$generic_args
    report_utilization -file [file join $output_dir $top-utilization.rpt]
    report_utilization -hierarchical -file [file join $output_dir $top-hierarchy.rpt]
    report_ram_utilization -include_lutram -file [file join $output_dir $top-ram.rpt]
    write_checkpoint [file join $output_dir $top.dcp]
    close_project
}
