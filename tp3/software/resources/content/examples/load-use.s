# Load-use: retención y bubble.
    addi x1, x0, 9
    sw x1, 0(x0)
    lw x2, 0(x0)
    add x3, x2, x2
    halt
