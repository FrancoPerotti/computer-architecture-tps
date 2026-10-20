# Trabajo Práctico N.º 3 — Procesador RISC-V con pipeline

Diseño en SystemVerilog de un procesador RISC-V de 32 bits con pipeline de cinco etapas para la placa Basys 3. El sistema permite cargar programas por UART, controlar la ejecución en modo continuo o paso a paso y consultar el estado del procesador desde una computadora.

El proyecto dispone de `system_pkg` y de infraestructura de compilación y pruebas en contenedores. La documentación describe el diseño de las etapas del pipeline, el manejo de riesgos, las memorias, el control de ejecución y la interfaz UART.

[Ver el índice general de documentación](docs/README.md)

[Preparar el entorno compartido de compilación y simulación](docs/development_environment.md)

Dentro del contenedor, desde `tp3`, `make check` ejecuta formato, lint,
validación del catálogo y todas las pruebas implementadas. `make help` muestra
los comandos y ejemplos de selección. Los mismos controles se usan en CI.

[Ver la documentación de arquitectura](docs/architecture/system_overview.md)
