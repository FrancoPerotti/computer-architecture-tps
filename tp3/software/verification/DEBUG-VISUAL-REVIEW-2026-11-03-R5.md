# Jerarquía y movimiento del debugger — 3 de noviembre de 2026

Se implementan las nueve observaciones sobre la vista convencional sin cambiar la estética de viewrv, el protocolo ni el control de ejecución.

| Observación | Resultado |
|---|---|
| Explicación repetida de `valid=0` | Retirada de las tarjetas y del inspector del diagrama. Se conservan los campos recibidos y los avisos de fallos reales. |
| PC de fetch repetido | Retirado del encabezado; permanece en el estado global. |
| Memoria | Contador, búsqueda con icono, limpieza del filtro y estados diferenciados de captura sin datos y búsqueda sin coincidencias. No se inventan bytes. |
| Estado global | Sección siempre abierta con título, sin control de expansión. |
| Gris ↔ amarillo | Barrido plano de izquierda a derecha en ambas direcciones, con rebote leve al terminar; duración de 360 ms. El texto se actualiza inmediatamente y permanece quieto. |
| Indicadores de instrucción | Transición de opacidad y escala de 200 ms entre instrucción válida, ausencia de instrucción y fallo de fetch. |
| Guía educativa | Resultado final esperado, referencia del ciclo y captura recibida separados. Explicaciones extensas bajo expansión progresiva y comparación apilada en paneles angostos. |
| Actividad inferida | Lista de etapas con nombre, estado y bloques participantes; se mantiene explícito que es inferencia y no medición combinacional. |
| Vista convencional | Espaciado consistente, títulos alineados y tarjetas interetapa en dos columnas cuando el panel resulta angosto. |

## Criterios de diseño

Se adaptan criterios de [espaciado](https://www.carbondesignsystem.com/building-blocks/foundations/spacing/overview), [movimiento](https://www.carbondesignsystem.com/building-blocks/foundations/motion/overview) y [acordeones](https://www.carbondesignsystem.com/building-blocks/core/components/accordion/guidelines) de Carbon: proximidad entre elementos relacionados, separación entre grupos, jerarquía y acceso directo al contenido principal. Esto no constituye una migración a componentes Carbon ni una afirmación de conformidad completa.

El rebote leve responde a la preferencia visual solicitada. No hay gradientes. Ambas animaciones se omiten con movimiento reducido, y se cancelan inmediatamente si esa preferencia se activa durante una transición. También se limpian al actualizar o desmontar el componente.

## Organización del código

Se extraen `ValueCell`, `InstructionStatus`, `MemoryPanel` y `CycleActivity` de la vista de resultados. `feedback-motion.ts` centraliza cancelación, limpieza y preferencia de movimiento reducido. El diagrama comparte `ValueCell` directamente, sin depender del componente de resultados. La guía conserva la procedencia de los datos y sus advertencias de versiones/perfiles.

## Verificación

- Formato y compilación correctos; 38/38 pruebas unitarias aprobadas.
- 22/22 comprobaciones funcionales y visuales aprobadas. La ejecución completa se interrumpió tras 14 aprobadas; las ocho restantes se completaron en otra ejecución. Los registros separados y un índice combinado conservan esa distinción.
- La nueva prueba `processor-feedback-smoke.cjs` usa once capturas STEP literales de los fixtures de suma y memoria: barrido en ambos sentidos, cambios de validez y fallo real, cancelación por movimiento reducido, jerarquía, filtro/limpieza de memoria y panel angosto. Inspeccionar la presentación no envía STEP adicionales.
- Pruebas existentes de dibujo, seguimiento, breakpoints, autocompletado, ejemplos y conservación aprobadas. La prueba de arrastre espera dos frames después del cambio de tamaño para medir la geometría estable.
- Revisión del navegador integrado a 1280×720: guía, actividad, memoria vacía y estado global. Sin errores de consola. La pestaña modificada del usuario se conserva.
- `git diff --check` correcto. Documentación del debugger actualizada en `tp3/docs/software/viewrv/gui_y_visor.md`.

Evidencia: `software/build/debug-visual-review-2026-11-03-r5/`, con registros, entorno, índice de resultados, capturas nativas/del navegador y hashes de las fuentes. Los frames intermedios de animación se inspeccionan pausando las animaciones nativas únicamente desde la prueba.

La demo de `http://127.0.0.1:5175/` continúa disponible con capturas predefinidas. Esta revisión no valida hardware físico, Windows, empaquetado distribuible ni ejecución de programas arbitrarios en la demo.
