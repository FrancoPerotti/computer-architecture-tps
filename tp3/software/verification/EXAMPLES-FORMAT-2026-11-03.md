# Formato uniforme del banco de ejemplos

Se aplicó el formatter del editor a los 59 archivos `.s`: cuatro espacios de sangría para instrucciones sin etiqueta, etiquetas al margen izquierdo, espacios después de comas y operandos de memoria sin espacios internos. Se conservaron comentarios, saltos de línea y orden de instrucciones.

Antes de escribir los archivos se ensamblaron las fuentes originales y formateadas con el assembler público. Los 59 pares produjeron exactamente los mismos bytes y mapas PC–línea. Se actualizaron las huellas SHA-256 en el catálogo y en las 59 guías; los demás metadatos, las expectativas y las 409 filas por ciclo permanecieron idénticos. La construcción regeneró el inventario de recursos derivado.

La prueba de formato ahora comprueba que todos los ejemplos estén normalizados con el mismo formatter que usa la GUI. Se actualizaron únicamente los espacios de los literales de fuente en las pruebas normativas de ejemplos, conservando sus resultados esperados.

Verificación realizada:

- Validador del banco: 59 programas, 33 instrucciones y 409 ciclos de guía.
- Python: 131 pruebas de ejemplos, contenido educativo, ayuda de instrucciones y assembler aprobadas.
- GUI: 41 pruebas unitarias, compilación con TypeScript estricto y comprobación de formato aprobadas.
- Ventana real: `examples-smoke`, `visual-feedback-smoke` y `debug-review-smoke` aprobados; evidencia en `software/build/gui-check/2026-11-04T02-17-04-891Z/`.

La comparación antes/después y una copia de las fuentes originales se conservaron en `software/build/examples-format-2026-11-03/`. Esta revisión comprueba equivalencia estática y presentación; no ejecuta una CPU simulada ni acredita una FPGA física.
