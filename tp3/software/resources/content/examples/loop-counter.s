# Bucle con PC repetido.
    addi x1, x0, 2
loop:
    addi x1, x1, -1
    bne x1, x0, loop
    halt
