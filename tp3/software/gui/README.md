# Organización de la GUI

La aplicación usa Electron con renderer React y Monaco. La GUI y la CLI consumen el mismo core local; la GUI no decide el estado físico de la placa ni simula la CPU.

## Responsabilidades

| Área | Archivos | Responsabilidad |
|---|---|---|
| Ventana y permisos | `src/main/`, `src/preload/` | Arranque, protocolo local, diálogos, portapapeles y puente mínimo al renderer. |
| Comunicación | `core-client.ts`, `live-state.ts` | Descubrimiento, contratos, HTTP/SSE, sincronización y cierre. |
| Documentos | `documents.ts`, `document-sync.ts` | Revisiones, confirmaciones, conservación, archivos y coordinación con el core. |
| Composición | `workbench.tsx`, `ide-state.ts`, `menus.tsx` | Tabs, splits, foco lógico, navegación y acciones de la aplicación. |
| Editor | `editor.tsx` | Composición del editor, pickers y selección/seguimiento de instrucciones. |
| Modelos de Monaco | `editor-models.ts` | Un modelo por programa, compartido entre splits y enlazado con DocumentSync. |
| Comandos de Monaco | `editor-commands.ts` | Registro de vistas, restauración de foco, edición, portapapeles y formato. |
| Interacción del editor | `editor-interactions.ts` | Hover, margen, acciones de teclado y adaptación del autocompletado. |
| Diagnósticos y decoraciones | `editor-diagnostics.ts`, `source-decorations.ts` | Marcadores de ensamblado y representación de capturas/breakpoints. |
| Lenguaje | `assembly-language.ts`, `assembly-format.ts`, `instructions.ts` | Configuración de Assembly, formato y documentación de instrucciones. |
| Depuración y circuito | `results.tsx`, `diagram.tsx`, `inspection.ts`, `graph-adapter.ts` | Representación de la observación recibida y seguimiento explícito. |
| Contenido educativo | `examples.ts`, `example-guide.tsx`, `instruction-catalog.tsx` | Recursos locales, referencia original y presentación educativa. |

Los archivos del renderer están en `src/renderer/`. Los contratos compartidos con el puente están en `src/shared/`.

## Estilos

`ui-tokens.ts` concentra colores y espaciado. `theme.css.ts` es la fachada de nombres públicos; las reglas viven en `src/renderer/styles/`:

- `base.css.ts`: fuentes, reglas nativas y scrollbars.
- `controls.css.ts`: botones, menús, búsqueda y acciones compartidas.
- `shell.css.ts`: ventana, navegación, bienvenida y barra de estado.
- `editor.css.ts`: editor, overlays, breakpoints y seguimiento.
- `results.css.ts`: estado global, registros, latches, memoria y capturas.
- `diagram.css.ts`: diagrama de sesión e inspector.
- `education.css.ts`: catálogo y guías educativas.
- `dialogs.css.ts`: conexión, ejemplos, recuperación, preferencias y notificaciones.
- `docking.css.ts`: integración visual con FlexLayout.

Las áreas pueden importar estilos compartidos concretos, sin ciclos ni importar su propia fachada. Las modificaciones de apariencia se verifican con los recorridos gráficos existentes. Los estilos del visor aprobado siguen siendo un recurso independiente.

## Pruebas y entornos

Desde este directorio:

```sh
npm run check
npm run test:gui -- formatter-smoke
```

`check` comprueba formato, construye con TypeScript estricto, ejecuta las pruebas unitarias y los 24 recorridos funcionales/visuales, secuencialmente. Versiones y logs se guardan en `../build/gui-check/`.

`tests/gui-fixture.cjs` posee el perfil XDG aislado, el proceso del core y las ventanas de las pruebas funcionales. `withGui` abre una ventana normal; `withGuiEnvironment` permite preparar CLI o archivos antes de abrirla mediante `launch`. Cada recorrido conserva su viewport, uso de GPU, módulo de hardware controlado y plazos de espera. La fixture conserva una captura ante fallo y finaliza las ventanas y el core antes de eliminar exclusivamente su perfil temporal.

Los escenarios de arranque nativo, aislamiento del dibujo, reapertura tras reiniciar el core, fallos de conservación y medición de rendimiento tienen ciclos de vida especiales. Mantienen sus preparaciones explícitas para comprobar esos comportamientos, sin mezclar fixtures de pruebas con el producto.

`stream-lifecycle-smoke` utiliza el core de pruebas y una ventana real para comprobar comentarios SSE, el watchdog de 45 segundos, reconexión y cierre durante reintento. El reloj del renderer se controla y pausa, mientras el servidor emite sus comentarios reales de 15 segundos; no simula la CPU. Se verifica que el ciclo de observación no envíe comandos de procesador ni termine el trabajo CLI ajeno.

Los tests utilizan adaptadores o capturas literales de hardware; no acreditan Basys 3 ni Windows. El estado vigente y la evidencia histórica se consultan en el [índice de verificación](../verification/README.md).
