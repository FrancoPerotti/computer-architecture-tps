# Material de licencias de Linux

`licenses-linux.lock.json` es el inventario revisado del material de distribución. `resources/licenses` conserva textos y atribuciones; los archivos grandes de fuentes se descargan en `build/license-sources`, fuera de Git. Los constructores empaquetan ambos conjuntos bajo `resources/licenses` y generan un índice HTML sin JavaScript que abre Ayuda → Avisos y licencias. Se incluye la licencia MIT con Franco Perotti y Federico Arnaudo como titulares del código propio.

Desde `tp3`, preparar una vez la caché de fuentes con sus huellas fijadas:

```sh
software/.venv/bin/python software/packaging/licenses.py --fetch
```

La descarga es explícita y usa HTTPS. Solo se conservan como válidos archivos de tamaño y SHA-256 coincidentes; un fallo no reemplaza un archivo válido. La construcción normal no descarga nada. Si falta una fuente, un texto o cambió una entrada revisada, termina con error.

Después de construir GUI y CLI/core, el constructor de verificación y el hook de electron-builder agregan automáticamente el material antes de generar el inventario completo Linux. El hook de Windows lo rechaza hasta disponer de una revisión nativa de esa plataforma. La falta de bitstream sigue bloqueando la distribución de hardware.

Para generar también el índice de desarrollo desde un producto verificado:

```sh
software/.venv/bin/python software/packaging/licenses.py --preview /ruta/absoluta/al/producto
```

El destino `software/build/licenses` debe ser nuevo. El menú de la GUI de desarrollo y el preview de navegador utilizan ese directorio; el producto distribuido utiliza su propia copia bajo `resources/licenses`. Los borradores y perfiles de la aplicación no intervienen.

## Actualizar componentes

El lock conserva entradas revisadas (locks Python/npm, recursos aprobados y fuentes de atribución), hashes de los textos, archivos fuente, archivos nativos y procedencia. Una actualización exige revisar su composición, licencias y avisos; regenerar hashes por sí solo no acredita esa revisión. Para la GUI se utiliza `audit_gui_modules.cjs` contra el ASAR construido; un paquete final con dependencias adicionales requiere ampliar el inventario. El guard de composición rechaza módulos externos inesperados y archivos npm fuera del bundle revisado.

Las fuentes Ubuntu corresponden al snapshot firmado `20261018T000000Z`; se conservaron hashes de sus índices Sources y las revisiones exactas con parches de distribución. FFmpeg corresponde a la revisión Chromium fijada por Electron 45.0.0, con el parche de Electron y su configuración Linux. `REBUILDING.md` explica el uso de esas fuentes y el reemplazo local. certifi conserva MPL y sus archivos fuente exactos.

El inventario adicional de Pydantic Core conserva el SBOM del editor y los avisos de sus 101 crates. El commit Rust identificado dentro del binario permite incorporar también el lock de su biblioteca estándar y los avisos de 30 entradas de registro. Ambos conjuntos incluyen paquetes de otras plataformas y construcción que pueden no contribuir al binario Linux. La presencia de esos avisos no demuestra que se enlace cada crate. Las alternativas permisivas y las atribuciones Unicode se conservan sin atribuir GPL al programa por una alternativa no elegida de una dependencia. Los avisos SGX/WASI/VEX de ese lock no acreditan código de esas plataformas en el binario Linux.

La construcción comprueba la integridad de los archivos y la cobertura del inventario técnico revisado; no constituye una certificación jurídica.
