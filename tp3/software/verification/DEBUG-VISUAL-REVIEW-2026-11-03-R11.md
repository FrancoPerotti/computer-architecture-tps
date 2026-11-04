# Notificaciones y estados sin captura — 3 de noviembre de 2026

La notificación distribuye icono de estado, mensaje y cierre en columnas independientes. El mensaje usa texto neutral legible; el error se identifica mediante un icono circular con acento rojo, distinto de la X de cierre. Los detalles técnicos permanecen bajo expansión y cuentan con fondo, padding y scroll propios. Se conservan roles de alerta/estado, acciones, duración y cierre de las notificaciones.

«Sin captura completa» y «Listo para el primer ciclo» comparten una tarjeta compacta con icono, título, explicación e indicación secundaria, alineados a la izquierda. El estado listo solo ofrece la indicación de avanzar cuando la sesión sigue abierta y en curso; un ensayo sin captura no muestra instrucciones de avance ni valores inventados.

Verificación:

- Formato, compilación/TypeScript y `git diff --check` correctos.
- 3/3 comprobaciones de GUI aprobadas: `programs-smoke`, `debug-review-smoke` y `processor-feedback-smoke`.
- Navegador integrado: error real del borrador existente con `sra`, detalles técnicos expandidos y cerrados, estado sin captura tras Detener y estado listo después de cargar el ejemplo original y abrir debug. No se ejecutó STEP ni se editó el código del usuario. Sin errores de consola.

La demo queda lista para el primer ciclo y conserva el borrador. Evidencia: `software/build/debug-visual-review-2026-11-03-r11/`, con capturas de los tres casos, registros y hashes de fuentes.
