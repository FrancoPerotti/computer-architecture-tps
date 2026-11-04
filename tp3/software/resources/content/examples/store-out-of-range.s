# Store fuera de DMEM REFERENCE.
    lui x1, 1
    addi x1, x1, -2048
    sw x0, 0(x1)
    halt
