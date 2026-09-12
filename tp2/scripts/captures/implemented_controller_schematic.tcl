open_run impl_1

set controller_instance [get_cells -quiet controller]
if {[llength $controller_instance] != 1} {
  error "No se encontró la instancia controller en el diseño implementado"
}

current_instance $controller_instance
set controller_cells [get_cells -quiet *]
if {[llength $controller_cells] == 0} {
  current_instance
  error "No se encontraron celdas dentro de controller"
}

show_schematic $controller_cells
current_instance
