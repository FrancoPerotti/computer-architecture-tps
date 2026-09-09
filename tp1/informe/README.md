# Informe en LaTeX

El archivo principal es `tp1_alu.tex`. Para compilar desde esta carpeta:

```sh
pdflatex -interaction=nonstopmode -halt-on-error tp1_alu.tex
pdflatex -interaction=nonstopmode -halt-on-error tp1_alu.tex
```

La segunda ejecución actualiza el índice y las referencias cruzadas. El documento generado es `tp1_alu.pdf`.

La instalación de TeX debe incluir los mismos paquetes que el informe de referencia, en particular `plex`, `listings`, `tcolorbox`, `xcolor`, `siunitx`, `booktabs`, `caption`, `float` y `tocloft`.
