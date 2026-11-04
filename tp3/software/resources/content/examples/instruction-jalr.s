# JALR: destino indirecto.
    addi x1, x0, 12
    jalr x3, 0(x1)
    addi x4, x0, 9
    halt
