# Trabajos Prácticos — Arquitectura de Computadoras

Repositorio de trabajos prácticos de la materia Arquitectura de Computadoras de la Facultad de Ciencias Exactas, Físicas y Naturales de la Universidad Nacional de Córdoba.

Los proyectos reúnen el diseño, la simulación y la implementación de sistemas digitales descritos en SystemVerilog. Cada trabajo se encuentra en su propio directorio e incluye el código fuente, los bancos de pruebas, los archivos necesarios para utilizarlo en Vivado y su documentación.

## Trabajos prácticos

| Trabajo | Descripción | Documentación |
| --- | --- | --- |
| [TP1 — Unidad Aritmético-Lógica](tp1/) | ALU parametrizable implementada y validada sobre una placa Basys 3. | [Informe en PDF](tp1/informe/tp1_alu.pdf) |
| [TP2 — ALU con interfaz UART](tp2/) | Extensión de la ALU con UART, FIFO y control mediante máquinas de estado finitas. | [Informe en PDF](tp2/informe/tp2_uart.pdf) |
| [TP3 — Procesador RISC-V Pipeline](tp3/) | Procesador RISC-V de cinco etapas con carga, ejecución y depuración mediante UART. | [Mapa de arquitectura y documentación](tp3/README.md) |

## Estilo del repositorio

La [guía de estilo SystemVerilog](docs/code-style.md) describe las convenciones observadas para escribir y revisar módulos RTL y bancos de prueba. El [análisis del estilo](docs/code-style-analysis.md) reúne el relevamiento del repositorio, los hallazgos, sus evidencias y excepciones.
