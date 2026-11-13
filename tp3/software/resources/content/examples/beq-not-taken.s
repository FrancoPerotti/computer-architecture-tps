# BEQ: salto no tomado.
    addi x1, x0, 1
    addi x2, x0, 2
    beq x1, x2, target
    addi x3, x0, 9
target:
    addi x3, x0, 7
    halt
