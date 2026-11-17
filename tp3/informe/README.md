# Informe del TP3

Este directorio contiene el informe del Trabajo Práctico N.º 3. El archivo
principal es `tp3_riscv_pipeline.tex`.

El informe identifica la base integrada `7025925f949c` y el aporte de
aceptación de la [PR #37](https://github.com/FrancoPerotti/computer-architecture-tps/pull/37),
revisión `cb3270b19b27`. Los comandos de aceptación en placa requieren
esa revisión o un checkout que ya la incorpore. El PDF enlaza la documentación
por commit y los [resultados publicados](https://github.com/FrancoPerotti/computer-architecture-tps/releases/tag/tp3-17-evidencia),
por lo que no depende de rutas locales para consultar sus referencias.

La compilación requiere pdfLaTeX y los paquetes usados en `librerias.tex`
(entre ellos Babel español, IBM Plex, siunitx, TikZ y tcolorbox). Los PDF
vectoriales de los diagramas están incluidos; no se necesita Node.js para
compilar el informe.

Para compilar desde esta carpeta se requiere también QPDF.

~~~bash
bash build.sh
~~~

El script compila tres veces para estabilizar el índice y las referencias,
normaliza los diccionarios de transparencia de los diagramas y verifica la
estructura del PDF. La salida queda en `tp3/informe/tp3_riscv_pipeline.pdf`.
Los archivos auxiliares se generan en un directorio temporal que se elimina al
terminar.

Los diagramas de alto nivel se renderizan con Pele desde
`diagrams/sources/*.mmd`. Las instrucciones para regenerarlos están en
`diagrams/README.md`.

Para comprobar las fuentes LaTeX con ChkTeX, si está disponible:

~~~bash
chktex -q tp3_riscv_pipeline.tex
~~~
