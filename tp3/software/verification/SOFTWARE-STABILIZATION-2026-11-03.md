# Estabilización de la GUI — 3 de noviembre de 2026

Se cierran los cuatro pendientes de la revisión de calidad: recorridos gráficos desactualizados, integración frágil con Monaco, carga del catálogo sin manejo completo de errores y código de interfaz excesivamente comprimido.

## Cambios

- **Pruebas gráficas vigentes.** Los recorridos usan los nombres de archivo, indicadores accesibles y controles actuales. Se conserva la comprobación de sincronización fuente/PC/registro/diagrama, identidad de apariciones, preservación de borradores, carga de la revisión exacta y ausencia de STEP adicionales. El recorrido que provoca un error de ensamblado cierra explícitamente su notificación persistente antes de continuar; no fuerza clics a través de ella. Se comprueban también los breakpoints al detener y reabrir debug.
- **Monaco aislado.** `monaco-completion.ts` concentra la compatibilidad con Monaco 0.57.0. Se eliminó el reemplazo de `toggleDetails`: la apertura utiliza el comando del editor y una acción pública con contexto de autocompletado para los atajos. Se mantiene un acceso de lectura a eventos y estado internos, porque no hay un evento público equivalente de foco de sugerencia. La frontera valida sus capacidades antes de suscribirse, dispone suscripciones y acción al destruir el editor y conserva el autocompletado nativo si la superficie deja de ser compatible. Una actualización de Monaco requiere repetir las pruebas; no se presenta esa dependencia como eliminada.
- **Recursos validados y recuperables.** `instruction-resource.ts` comprueba respuesta HTTP, JSON, campos de instrucciones y operandos, notas y unicidad de mnemónicos. El editor y el catálogo usan ese contrato común. La vista del catálogo muestra carga, error accesible y reintento; ignora respuestas de montajes o intentos anteriores. Un error no se presenta como un catálogo vacío válido. La inicialización del editor conserva su pantalla de error y reintento si falla este recurso.
- **Responsabilidades y formato.** Se separan la configuración del lenguaje, las decoraciones del código y los diálogos de ejemplos y recuperación. Se preservan el modelo de documentos, los contratos de sesión y el comportamiento visual acordado. `ui-tokens.ts` centraliza colores y escala de espaciado sin cambiar sus valores. Prettier queda fijado y aplicado al código propio, pruebas y scripts; no modifica GraphViewer ni el XML aprobado.

## Verificación reproducible

Desde `tp3/software/gui`, ejecutar `npm run check`. El comando comprueba formato, construye con TypeScript estricto, ejecuta las pruebas unitarias y después los 21 recorridos gráficos secuencialmente. `npm test` sigue significando solo pruebas unitarias. `npm run test:gui -- nombre-del-recorrido` permite repetir un caso sobre la construcción existente.

Playwright 1.62.1 y Prettier 3.9.10 están fijados en el archivo de bloqueo. El ejecutor guarda versiones de entorno, resultados, duraciones y logs por recorrido bajo `software/build/gui-check/`. Los ensayos de paquete nativo, rendimiento, Windows y hardware tienen procedimientos separados y no se incorporan a este comando como si estuvieran verificados.

El workflow `.github/workflows/viewrv-gui.yml` prepara Node y Python fijados por el proyecto, instala dependencias bloqueadas y ejecuta el mismo comando con Xvfb en Linux. Las acciones están fijadas por commit y sus permisos son de lectura. Se comprobaron su sintaxis YAML, los commits fijados y el comando de revisión; su ejecución remota queda pendiente de publicar los cambios. Referencias de configuración: [setup-node](https://github.com/actions/setup-node) y [setup-python](https://github.com/actions/setup-python).

## Resultado del cierre

- `npm run check`: **aprobado**, incluyendo formato y compilación.
- **38/38 pruebas unitarias**, incluidas validación/reintento del recurso y compatibilidad/disposición del adaptador de Monaco.
- **21/21 recorridos gráficos** en una misma ejecución: arranque, programas, conservación, preparación, sesiones, IDE, dibujo, diagrama, inspección gráfica, bucles, ejemplos, revisiones visuales, espaciado, seguimiento desde el código, visibilidad de breakpoints, autocompletado y fallos del catálogo.
- Autocompletado probado con LUI, stores, HALT, shifts y JALR, navegación por flechas, Ctrl+Space, cierre/reapertura y paneles de 1528, 1301 y 615 px. No se reemplazan métodos del widget.
- Catálogo probado frente a HTTP fallido, JSON inválido, contrato inválido y fallo de carga, seguido de reintento satisfactorio y búsqueda entre las 33 instrucciones. La inyección de transporte se limita al renderer aislado de la prueba, porque el protocolo local de Electron no pasa por el enrutamiento HTTP de Playwright.
- `npm ci --dry-run --ignore-scripts`: correcto; comprobación del archivo de bloqueo, sin presentarla como una reinstalación completa.
- Navegador integrado: construcción actual, catálogo completo y sin errores de consola; se conserva la pestaña modificada del usuario.
- `git diff --check`: correcto.

Entorno ejecutado: Linux x64, Node 24.22.1, Electron 45.0.0, Monaco 0.57.0 y Playwright local 1.62.1. Se usan perfiles aislados y adaptadores/capturas UART de prueba; no se ejecuta un simulador de CPU en producción.

Evidencia de la ejecución completa: `software/build/gui-check/2026-11-03T19-28-05-282Z/`. Copia de cierre, capturas e identificación de fuentes: `software/build/software-stabilization-2026-11-03/`. No se reconstruyó el paquete distribuible ni se realizaron verificaciones físicas o de Windows.
