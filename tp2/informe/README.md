# Informe del TP2

Para compilar la memoria técnica:

~~~bash
cd tp2/informe
pdflatex -interaction=nonstopmode -halt-on-error tp2_uart.tex
pdflatex -interaction=nonstopmode -halt-on-error tp2_uart.tex
~~~

Para comprobar las fuentes con ChkTeX:

~~~bash
cd tp2/informe
CHKTEX_CONFIG="$PWD/.chktexrc" chktex -q tp2_uart.tex
~~~

El PDF resultante queda en `tp2/informe/tp2_uart.pdf`. La síntesis,
implementación y temporización ya están documentadas con los reportes de Vivado
2025.2. Solo la sección de validación física permanece pendiente hasta poder
programar una Basys 3 y conservar la salida de la suite y las fotografías.
