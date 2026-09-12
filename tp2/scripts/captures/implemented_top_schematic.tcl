open_run impl_1
current_instance /

set top_cells [get_cells -quiet {reset_conditioner uart controller}]
if {[llength $top_cells] == 0} {
  error "No se encontraron las instancias del nivel superior"
}

show_schematic $top_cells
