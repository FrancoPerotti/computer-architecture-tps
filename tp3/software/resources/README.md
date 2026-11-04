# Recursos locales del visor

`content/viewer/index.html` es una copia sin cambios del visor autónomo indicado por el usuario. `content/viewer/provenance.json` identifica la revisión de origen y la huella de cada archivo copiado. El repositorio de origen no se modifica.

El runtime GraphViewer conserva la huella aprobada `32c73b8e42e784d0ace7d59754cbea6c2a78a0f506d390e2a3870546b9242f7c`; su procedencia y licencia Apache-2.0 se registran en `runtime-manifest.json`. Las fuentes Inter e IBM Plex Mono incluyen sus licencias OFL. El HTML incorpora los recursos que necesita para funcionar sin red.

La [revisión de compatibilidad del 4 de noviembre de 2026](../verification/MIT-COMPATIBILITY-2026-11-04.md) identificó el runtime aprobado como draw.io 32.0.2, commit upstream `2201e54124bfbbf09d8addec60e6f8d73eed6f92`, mediante coincidencia íntegra de bytes. Complementa la procedencia histórica sin cambiar el manifiesto de importación ni el SDK. La revisión mantiene pendientes de atribución y distribución de componentes incorporados.

`viewer/source-diagram.drawio.xml` conserva el XML de origen `TP3_PIPELINE_COMPLETO.drawio.xml`. El XML canónico `diagram.drawio.xml` se obtiene del dibujo completo preparado dentro del HTML aprobado, sin mover bloques ni cables; así ambas vistas renderizan el mismo circuito. `diagram_bindings.json` conserva las 44 correspondencias del documento canónico de GUI y visor, incluidos los muxes de bypass y la lógica interna de pipeline vacío. `representations` identifica además la celda interna `tp3-exec-empty`; `processor_profile.json` describe exclusivamente campos publicados por UART. El adaptador de sesión consume estas correspondencias en PC-I07. No acredita señales ni capturas medidas.

Para repetir la importación, desde `tp3`:

```sh
software/.venv/bin/python software/packaging/import_viewer.py /ruta/al/visor_tp3
```

La importación exige la huella aprobada del runtime. Actualizar el origen requiere revisar el cambio; el build habitual utiliza los recursos ya conservados aquí y no depende de esa ruta externa.

`content/es/education.json` separa las explicaciones revisadas de las 33 instrucciones, sus 165 etapas, los módulos y los supuestos del recorrido. La extracción inicial usa el catálogo incluido en el HTML aprobado y conserva su procedencia; no ejecuta JavaScript ni cambia el repositorio de origen. El recurso admite correcciones editoriales sin cambiar reglas de interpretación o IDs semánticos. `external_signals` conserva las señales externas declaradas por el diseño; `links` reserva las referencias educativas y no confunde señales con enlaces. Las dos vistas preparadas consumen el contenido, incluido el selector de instrucciones y los supuestos.

Desde `tp3`, `software/.venv/bin/python -m software.packaging.prepare_education` valida el contenido guardado, las etapas y los IDs del dibujo. La opción `--extract` sirve para la incorporación inicial y rechaza sobrescribir un recurso español ya existente. No se usa como paso de construcción que elimine cambios editoriales.


Desde `software/gui`, `npm run build`, `npm run dev` y `npm test` ejecutan `packaging/build_viewer.cjs`. Genera `explore.html`, `session.html` y `generated.json`, archivos ignorados por Git, usando únicamente recursos locales. El manifiesto registra entradas, salidas y la huella del generador. Las vistas mantienen intacto el SDK incorporado al HTML aprobado; el adaptador propio se agrega al código de inicialización y su CSS se inserta fuera del runtime. La vista de sesión reutiliza una instancia del grafo y actualiza sus estilos sin reconstruir el modelo.

La construcción valida XML, referencias y bindings antes de actualizar automáticamente las dos huellas derivadas del perfil. `viewer_resources.cjs` adapta los metadatos aprobados a los IDs actuales; el SDK permanece intacto. Las explicaciones españolas pueden corregirse y construirse sin editar el runtime ni la interpretación del core.


El [banco ejecutable](content/examples/README.md) contiene 59 fuentes y sus guías estáticas. El generador de vistas valida su asociación por huella y agrega catálogo, fuentes y guías al manifiesto de entradas. El core carga solamente los ejemplos compatibles con su perfil y rechaza fuentes cuya huella no coincide con el catálogo. La validación completa mediante `software.packaging.validate_examples` utiliza el assembler público real; no ejecuta los programas para producir expectativas.


## Editar el dibujo

Mover bloques, campos o puntos de cables se hace en `content/diagram.drawio.xml`. El dibujo contiene también vértices separados para los campos de algunos latches: el movimiento debe incluir esos elementos en el XML, tal como se editaría el módulo completo en el editor del dibujo. La aplicación renderiza la geometría guardada y no recoloca campos ni decide conexiones a partir de proximidad.

Si cambian IDs, actualizar únicamente `content/diagram_bindings.json`:

- `blocks`: ID actual de cada uno de los 44 bloques semánticos.
- `representations`: IDs actuales de representaciones internas, como `tp3-exec-empty`.
- `source_blocks` y `source_representations`: referencia estable de los IDs de la copia aprobada; conservarla al renombrar el dibujo actual.
- `cell_ids`: correspondencias explícitas entre un ID original de campo, cable u otro elemento referenciado y su ID actual. No hace falta una entrada para los IDs que permanecen iguales.

Después ejecutar `npm run build` o `npm run dev` desde `software/gui`. No es necesario editar a mano las huellas del perfil, el HTML aprobado ni la lógica del procesador. La preparación rechaza IDs inexistentes, repetidos o contradictorios y cambios de extremos de una conexión que se intenten presentar como un movimiento de layout. Un cambio semántico requiere su revisión arquitectónica; el adaptador no lo infiere de posiciones. La cámara de un dibujo editado se encuadra usando los estados del renderer nativo sin modificar el modelo. El dibujo original conserva sus encuadres revisados.

`import_viewer.py --output /ruta/a/contenido-temporal` permite repetir una importación de forma aislada. La extracción del idioma usa las referencias de origen para mantener los IDs semánticos aunque el dibujo actual haya sido renombrado. Las pruebas `drawing-resources.test.cjs` y `drawing-smoke.cjs` comprueban movimiento e IDs usando una copia privada, sin cambiar el recurso aprobado.

## Editar explicaciones

`es/education.json` conserva instrucciones y etapas, explicaciones generales y contextuales de módulos, presentación de etapas, señales y conexiones. `module_explanations` usa IDs semánticos; las explicaciones de conexión usan los identificadores estables `connection-*`, conservando cadenas y máscaras en los metadatos del dibujo. Las notas de contexto de conexiones inactivas también son editables. El build combina esos textos con el grafo actual; una corrección no exige editar JavaScript, protocolo o lógica de inferencia.

El manifiesto de preparación registra también la huella de `viewer_resources.cjs` y del adaptador de cámara. Las comprobaciones de procedencia siguen comparando el SDK incorporado a las vistas con la copia aprobada, byte por byte.


## Cámara y rendimiento

`camera-adapter.js` conserva los estados nativos en coordenadas del dibujo y actualiza la transformación de la vista sin validar de nuevo todas las celdas durante cada gesto. La escala conserva precisión para movimientos pequeños del trackpad. El tamaño desplazable que calcula el visor se aplica a un separador sin interacción; el SVG mantiene el tamaño del viewport para evitar recalcular todos sus rótulos al hacer zoom. Los trazos de selección mantienen sus variables de escala en sus propios paths. Ninguna de estas operaciones escribe geometrías, conexiones, valores UART ni instrucciones.

`drawing-smoke.cjs` comprueba un campo clicable después de desplazar el dibujo y ampliar la cámara; `graphical-smoke.cjs` comprueba selección, memoria, encuadre y docking al 125 %. `performance-smoke.cjs` conserva entradas entregadas, cambios de cámara, cuadros y trazas, además de una grabación opcional en ejecución separada. Sus avisos de cuadros mayores a 25 ms deben revisarse junto con las muestras; no equivalen a medir la frecuencia del procesador.

## Avisos y fuentes de terceros

`licenses` conserva los textos y la procedencia revisados del material de distribución. El [procedimiento Linux](../packaging/LICENSES.md) agrega las fuentes exactas desde una caché verificada, genera el índice sin red y valida los runtimes y el bundle antes de empaquetar. El recurso aprobado de GraphViewer y su manifiesto de importación permanecen intactos.
