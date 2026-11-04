# Organización previa a PC-I08

Estado: limpieza estructural completada, con comprobación local de la GUI y commits separados. Se conserva la implementación funcional de PC-I01 a PC-I07; esta revisión no inicia PC-I08.

## Editor y estilos

`editor.tsx` pasó de 677 a 403 líneas. Conserva la composición de la vista y sus pickers; los modelos compartidos y su sincronización están en `editor-models.ts`, el registro/foco/comandos en `editor-commands.ts`, la interacción con mouse/teclado en `editor-interactions.ts` y los diagnósticos en `editor-diagnostics.ts`. Workbench consume esas responsabilidades explícitamente. Los modelos siguen compartidos entre splits y se conserva su liberación al cerrar el programa.

`theme.css.ts` pasó de 1.790 a 11 líneas y funciona como fachada de nombres públicos. Las reglas se distribuyen entre nueve módulos de `renderer/styles/`, sin ciclos de importación: base, controles, ventana, editor, resultados, diagrama, educación, diálogos y docking. Se compararon los árboles sintácticos de las 355 declaraciones, reglas y bucles trasladados: conservaron su contenido. Los nombres de clase generados por la herramienta pueden cambiar al cambiar de archivo; los recorridos verifican sus efectos visuales y funcionales.

El [mapa de módulos](../gui/README.md) explica la distribución y los puntos de entrada para modificar cada área.

## Preparación de pruebas

Se migraron 15 recorridos al ciclo de vida compartido de `gui-fixture.cjs`. Junto con los cuatro que ya usaban esa fixture, 19 de los 23 recorridos funcionales/visuales comparten el perfil XDG aislado, el core, el arranque de Electron, los errores de renderer y la limpieza. `withGuiEnvironment` permite preparar archivos o una sesión CLI antes de abrir la ventana; `withGui` conserva el acceso directo habitual.

Se preservaron viewport, configuración de GPU, módulo de core, traza literal y plazos de espera de cada recorrido. La limpieza finaliza las ventanas y el core y elimina exclusivamente el perfil temporal de esa prueba. Se conservaron las 301 comprobaciones de los 15 escenarios migrados. Un literal de la tabla de ensamblado se actualizó para incluir la sangría del banco de ejemplos ya normalizado.

Las pruebas de arranque, dibujo aislado, reapertura tras reiniciar el core y fallos de conservación mantienen sus preparaciones específicas. Los scripts separados de paquete nativo y rendimiento también conservan su ciclo especializado. No se incorpora ninguna fixture al producto.

## Verificación

`npm run check` terminó con código cero en una ejecución completa sobre las fuentes finales:

- Formato y compilación con TypeScript estricto aprobados.
- 41/41 pruebas unitarias aprobadas.
- 23/23 recorridos de GUI aprobados, ejecutados secuencialmente.
- `git diff --check` aprobado.

Evidencia: `software/build/gui-check/2026-11-04T02-38-10-481Z/`. El log completo y las auditorías estructurales se conservaron en `software/build/software-organization-2026-11-03/`. La primera ejecución y la repetición puntual se conservan por separado; la primera detectó el literal sin sangría antes de corregirlo.

No se repitieron las pruebas físicas ni las de Windows y no se reconstruyó el paquete distribuible. Sus pendientes permanecen en el [índice de evidencia](README.md).

## Registro en Git

La implementación que estaba acumulada sin registrar se organizó en cuatro commits locales:

- `101b18c`: recursos del visor y banco educativo.
- `a7efe87`: assembler, core compartido, CLI y herramientas nativas.
- `70908d8`: IDE de escritorio, depuración y verificación de GUI.
- `5a120c0`: documentación, evidencias y automatización de pruebas.

La limpieza se registró después en commits independientes:

- `a53376e`: separación de responsabilidades de Monaco.
- `f33fb06`: organización de estilos por área.
- `b9b4713`: ciclo de vida compartido de pruebas.
- Un último commit documental reúne este informe, el mapa de módulos y el índice de evidencias.

La rama existente conserva su nombre. No se publicaron los commits ni se alteraron otras ramas.
