# Trabajo Práctico N.º 2 — ALU con interfaz UART

Implementación en SystemVerilog de una interfaz UART para comunicar una computadora con la ALU del TP1 sobre la placa Basys 3. El sistema recibe dos operandos y un código de operación, devuelve el resultado por el enlace serie y muestra el último resultado y sus banderas en los LED.

El proyecto incluye los módulos de recepción y transmisión UART, los FIFO, el controlador de transacciones, el módulo superior y sus respectivos bancos de pruebas. El circuito fue verificado mediante simulación, sintetizado e implementado con Vivado y quedó preparado para su validación física sobre la placa.

[Ver el informe completo en PDF](informe/tp2_uart.pdf)

## Aplicación de escritorio

[UART Lab](tools/README.md) permite operar la ALU con bits interactivos,
inspeccionar resultados, ejecutar suites de pruebas y guardar la sesión. Incluye
un modo de simulación local para explorar la interfaz sin una placa.

Desde la raíz del repositorio, con las dependencias instaladas:

```bash
python tp2/tools/uart_alu_gui.py --demo
```
