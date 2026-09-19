open_run impl_1

set uart_instance [get_cells -quiet uart]
if {[llength $uart_instance] != 1} {
  error "No se encontró la instancia uart en el diseño implementado"
}

current_instance $uart_instance
set uart_cells [get_cells -quiet *]
if {[llength $uart_cells] == 0} {
  current_instance
  error "No se encontraron celdas dentro de uart"
}

show_schematic $uart_cells
current_instance
