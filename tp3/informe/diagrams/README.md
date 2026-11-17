# Diagramas del informe

Los diagramas de alto nivel se escriben en Mermaid y se renderizan con
[Pele](https://pele.run) para obtener SVG. Los diagramas detallados de
arquitectura se conservan en los SVG existentes de `tp3/docs/diagrams/generated`
y se convierten a PDF sin redibujarlos.

## Renderizado

Desde este directorio:

```bash
npm ci
npm run render
npm run render:existing
```

`npm run render` usa Pele 1.13.0 y `rsvg-convert` para generar:

- `svg/*.svg`: resultado editable de Pele.
- `pdf/*.pdf`: archivos vectoriales que incorpora LaTeX.

`npm run render:existing` usa Electron/Chromium para imprimir los SVG de
arquitectura que contienen `foreignObject`, de modo que las etiquetas se
conserven en el PDF.

La FSM global se presenta en tres vistas legibles en A4: `fsm-carga`,
`fsm-ejecucion` y `fsm-drenado`. Sus fuentes describen transiciones
resumidas; la prioridad de reset y LOAD elegible, las retenciones y la
terminación directa con pipeline vacío se explican en el capítulo de control.
El diagrama completo original se conserva como referencia en `fsm-global.pdf`.

## Tema

`render.mjs` fija las variables de Pele al estilo del informe:

| Variable | Valor |
| --- | --- |
| Fondo | `#ffffff` |
| Texto | `#1f1f1f` |
| Línea y borde | `#624096` |
| Superficie | `#fcfbff` |
| Superficie alternativa | `#f2f0fa` |
| Tipografía | IBM Plex Sans |

Los diagramas de Pele se incluyen desde `tp3/informe/capitulos` con
`\includegraphics{...}` y la ruta `diagrams/pdf/` declarada en
`librerias.tex`.
