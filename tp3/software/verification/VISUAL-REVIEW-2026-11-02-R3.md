# Tercera revisión visual — 2 de noviembre de 2026

Implementación de los ocho comentarios de la tercera ronda. Compilación de desarrollo 0.7.0 y vista previa existente, con sus programas conservados.

| Comentario | Cambio |
| --- | --- |
| 1 · Uso de instrucciones en autocompletado | La documentación muestra primero la sintaxis; sigue con la operación, los parámetros y sus rangos, un ejemplo de uso y notas de alineación/memoria cuando corresponden. Mantiene la selección por teclado y la descripción expandida. |
| 2 · Icono de información | Padding explícito cero y SVG de bloque dentro del botón centrado. Se comprobó el centro geométrico del icono respecto del botón. |
| 3 · Información en el mismo grupo | La información se agrega como una pestaña junto al editor desde el que se abrió. No crea una división. Cada programa conserva su referencia, incluso con varios grupos. Si la pestaña ya se arrastró a otro lugar, volver a abrirla la selecciona sin moverla. Se mantiene el arrastre y acoplamiento de FlexLayout. Esta decisión sustituye la apertura lateral solicitada en la primera ronda. |
| 4 · Flecha de ejecución | Padding cero, ancho de 22 px y centrado explícito heredado del botón de icono. El separador vertical se dibuja sobre el grupo, independiente de los botones. El hover conserva el centro y usa el estilo de los demás iconos. |
| 5 · Referencia más completa | Catálogo y autocompletado leen el mismo recurso local de 33 instrucciones, con sintaxis, operandos, descripción ampliada, ejemplo y notas. |
| 6 · Marca compacta | `v│rv` en el extremo izquierdo, con el mismo estilo monoespaciado y separador índigo. Corresponde a la firma compacta del manual de marca. |
| 7 · Título central | `viewrv` en texto simple, centrado respecto de la ventana. Se oculta por debajo de 700 px para evitar superponerse a menús y controles. |
| 8 · Catálogo en lista | Una entrada por fila, a todo el ancho disponible. Cada entrada presenta sintaxis destacada, descripción, parámetros y ejemplo de uso; las notas quedan debajo. La búsqueda incluye también parámetros, sintaxis, ejemplos y notas. Conserva los filtros por familia. |

## Contenido técnico

`resources/content/instructions.json` incorpora los campos `syntax`, `operands`, `example` y `notes`. Los roles y rangos se contrastaron con `software/assembler.py`; los ejemplos se tomaron del recurso educativo local. Se documentan, entre otros, los inmediatos con signo, shamt de 0 a 31, el campo U sin desplazar, los destinos relativos, el dato de stores y HALT sin operandos. No se añaden instrucciones que el ensamblador no admita.

El frontend comparte el tipo y la presentación Markdown del recurso mediante `instructions.ts`. El código del ensamblador y del core no cambió.

## Verificación realizada

- `npm run build`: TypeScript y compilación correctos.
- `npm test`: 33 pruebas aprobadas.
- `test_instruction_help.py`: tres pruebas aprobadas. Verifican cobertura exacta del ensamblador, roles de operandos y ensamblado real de los 33 ejemplos publicados.
- `tests/visual-round3-smoke.cjs`: marca compacta y título centrado; centro geométrico de los dos iconos, incluido hover; apertura de la información en el mismo grupo; referencias independientes de dos ejemplos en grupos distintos; documentación enriquecida de LUI, SW, HALT, SLLI y JALR; lista única de las 33 instrucciones y detalle LUI con parámetros y ejemplo.
- `tests/examples-smoke.cjs`: filtros, apertura de ejemplos, referencia original y variantes editadas, restauración y siete ciclos recibidos del caso literal de suma. Adaptado al cambio autorizado de panel lateral a pestaña.
- `tests/visual-feedback-smoke.cjs`: regresión de visor, conexión flotante, ejemplos, títulos, información como pestaña, cierre de grupos vacíos, hover, autocompletado, catálogo y Ajustes a 1301×639 y documentación estrecha a 615×639.
- Vista previa del navegador integrada actualizada y catálogo ampliado inspeccionado; sin errores de consola en la revisión final.
- `git diff --check` correcto.

La evidencia usa Electron/core desde fuente con perfiles temporales y fixtures explícitos donde interviene UART. No representa una nueva aceptación física de FPGA ni un paquete de distribución reconstruido.

Capturas locales: `software/build/visual-round3-*.png`. Resultados y hashes: `software/build/visual-review-2026-11-02-r3/`. Las rondas anteriores conservan su alcance original.
