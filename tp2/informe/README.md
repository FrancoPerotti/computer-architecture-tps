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
implementación y temporización están documentadas con los reportes de Vivado
2025.2. La validación física incluye las suites ejecutadas desde la GUI y las
fotografías de los LED de la Basys 3.
