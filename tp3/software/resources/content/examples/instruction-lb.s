# LB: cargar y extender.
    lui x1, 0x8
    addi x1, x1, 255
    sw x1, 0(x0)
    lb x3, 0(x0)
    halt
