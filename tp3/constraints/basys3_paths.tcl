# Restricciones sobre la netlist. Fallar si se renombra o cambia un endpoint.
set rx_first [get_cells -quiet -hierarchical -filter {NAME =~ */rx_synchronizer/serial_meta_reg}]
set tx_register [get_cells -quiet -hierarchical -filter {NAME =~ */transmitter_datapath/tx_reg_reg}]
set reset_registers [get_cells -quiet -hierarchical -filter {NAME =~ *.reset_conditioner/reset_pipe_reg*}]
set rx_sync_regs [get_cells -quiet -hierarchical -filter {NAME =~ */rx_synchronizer/serial_meta_reg || NAME =~ */rx_synchronizer/serial_reg_reg}]
set rx_first_d [get_pins -quiet -of_objects $rx_first -filter {REF_PIN_NAME == D}]
set tx_clock [get_pins -quiet -of_objects $tx_register -filter {REF_PIN_NAME == C}]
set tx_q [get_pins -quiet -of_objects $tx_register -filter {REF_PIN_NAME == Q}]
set reset_async [get_pins -quiet -of_objects $reset_registers -filter {REF_PIN_NAME == PRE || REF_PIN_NAME == CLR}]

foreach {name objects expected} [list rx_first_d $rx_first_d 1 tx_clock $tx_clock 1 \
        tx_q $tx_q 1 rx_sync_regs $rx_sync_regs 2 reset_async $reset_async 2] {
    if {[llength $objects] != $expected} {
        error "Basys 3: $name requiere $expected endpoint(s); encontrados: $objects"
    }
}
foreach register [concat $rx_sync_regs $reset_registers] {
    if {![string is true -strict [get_property ASYNC_REG $register]]} {
        error "Falta ASYNC_REG en $register"
    }
}

set_max_delay 20.000 -datapath_only -from [get_ports uart_rx_i] -to $rx_first_d
# Arrancar en C y pasar por Q conserva el arco C→Q sin segmentar el registro TX.
set_max_delay 20.000 -datapath_only -from $tx_clock -through $tx_q -to [get_ports uart_tx_o]
set_false_path -to $reset_async
# RST del MMCM carece de un chequeo STA. Se verifica su conexión tras el ruteo.
