# Banco de ejemplos y guías

El banco contiene 59 programas autónomos: 33 entradas individuales, una por instrucción del TP3, dos ejemplos iniciales y 24 variantes de control, interacción y borde. Los programas usan el assembler público aprobado. Las expectativas son vectores de diseño pendientes de aceptación con FPGA.

Las fuentes usan el mismo formato que el editor: cuatro espacios de sangría para instrucciones sin etiqueta, etiquetas al margen izquierdo, un espacio después de cada coma y operandos de memoria como `offset(registro)`. El formato conserva comentarios y numeración de líneas. La prueba `assembly-format.test.cjs` comprueba que los 59 archivos ya estén formateados; al cambiar una fuente se deben actualizar sus huellas en el catálogo y en su guía. La normalización del banco conservó los bytes ensamblados, los mapas PC–línea y todas las expectativas de las guías.

`catalog.json` identifica título, objetivo, fuente, instrucciones relacionadas, perfiles compatibles, expectativas y ruta de guía. `focus_instruction_id` distingue los 33 ejemplos individuales de las interacciones; no implica que los demás carezcan de instrucciones auxiliares. `expected_state` documenta solamente los campos listados, sin completar los demás valores de una captura. Los bytes cero escritos se enumeran explícitamente.

Las guías en `guides/` tienen una huella SHA-256 de la fuente original, supuestos y una fila por ciclo CPU efectivo. Cada posición identifica un latch válido, su PC y una aparición dinámica. Retención, bubble, descartes y bucles se escriben en la guía; no se deducen de avanzar secuencialmente PCs en la aplicación. Un latch ausente de la tabla puede conservar bits residuales. `terminal` registra ciclo y clase de terminación, o queda nulo para el prefijo del bucle infinito. El fetch posterior a la imagen puede ser un candidato independiente de `valid`; las explicaciones lo distinguen de una instrucción normal.

La GUI muestra la tabla como referencia del programa original. Asocia una fila al contador recibido solo si el texto coincide exactamente y el perfil es compatible. Editar el programa conserva la referencia y sus supuestos, sin atribuirle una predicción de la variante. Las expectativas y las capturas se presentan por separado, sin calificar automáticamente los resultados ni generar capturas ausentes.

Los bordes de DMEM usan `REFERENCE` (2048 bytes), el perfil local aprobado. Esos dos ejemplos se excluyen cuando el core y la GUI utilizan `ALT_1000`; los otros 57 son compatibles con ambos perfiles. Cambiar la capacidad requiere revisar programas, perfiles compatibles, expectativas y guías de borde.

Desde `tp3`, ejecutar:

```sh
software/.venv/bin/python -m software.packaging.validate_examples
software/.venv/bin/python -m unittest software.tests.viewrv.test_examples
```

El validador ensambla los 59 programas y verifica las 33 instrucciones individuales, los escenarios requeridos, tamaños de imagen y direcciones de datos, huellas, secuencia de ciclos, apariciones y terminales. Las pruebas contrastan resultados y causas con vectores literales de la especificación y fronteras seleccionadas con las reglas normativas. No ejecutan un simulador de CPU ni acreditan hardware. La construcción de GUI verifica las fuentes/guías y registra todas sus huellas; la construcción completa de distribución también exige el validador con el assembler real.
