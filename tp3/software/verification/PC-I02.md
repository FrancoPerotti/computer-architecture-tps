# Evidencia de PC-I02: programas, editor y conservación

Fecha: 29 de octubre de 2026. Rama: `feature/tp3-14-aplicacion-pc`. Base: `f0c05f6`, con cambios locales sin publicar. Diseño aprobado de #12: `d488a82196e897d46905412a77f75512c9d4ac2e`, incorporado en la base; la referencia remota se volvió a comprobar durante esta entrega.

Se implementó PC-I02 con resultados de assembler controlados, conforme al alcance pedido. Se conservan los contratos públicos de revisiones, edición y almacenamiento. No se utilizó FPGA ni assembler real. Windows continúa pendiente por indicación expresa del usuario, que no dispone de equipo o VM. Esta evidencia no acredita PC-I08 ni casos de aceptación completos.

## Entorno y producto

| Campo | Valor |
|-------|-------|
| Host | Arch Linux x86_64, kernel 7.2.11-arch1-1; comprobaciones gráficas mediante X11 |
| Python / Node | CPython 3.14.9 convencional / Node 24.22.1 |
| Electron / React / TypeScript | 45.0.0 / 19.3.1 / 6.0.3 |
| FastAPI / Uvicorn / HTTPX / Click | 0.162.0 / 0.54.0 / 0.28.1 / 8.5.0 |
| PyInstaller / electron-builder | 6.22.3 / 26.18.0 |
| Base nativa de construcción | Ubuntu 24.04, `ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c` |
| Ubuntu mínimo de ejecución | `ubuntu@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852`, producto de solo lectura y red externa deshabilitada |
| Ventanas automatizadas | Playwright externo del runtime local de Codex; viewport 1440×1000 para editor y 1440×960 para base/visor; escala inicial de aplicación 1 |
| Producto | `software/gui/dist/viewrv-gui-0.2.0.tar.gz`, compresión store |
| SHA-256 del producto | e931932e16c3eeee77fbef9f274b2b58ff12bc127a5d6879f18e816bebab04c2 |
| Extracción comprobada | `software/build/extracted/viewrv-gui-0.2.0`; la extracción 0.1.0 anterior se conserva por separado |

Las dependencias permanecen fijadas en los dos bloqueos Python y en `gui/package-lock.json`. El producto conserva CLI y core onedir con runtimes independientes, GUI y recursos locales e inventario de hashes. No se incorporó un assembler ficticio al producto. El código de los dobles está exclusivamente en `software/tests/viewrv`. El HTTP 422 que aparece en el registro gráfico corresponde al diagnóstico de código controlado esperado.

## Comprobaciones

Los comandos Python y de Docker parten de `tp3`; los comandos npm y de ventana, de `tp3/software/gui`. El [README](../README.md) describe la preparación del entorno y los procedimientos.

| Comprobación | Comando o procedimiento | Resultado |
|--------------|-------------------------|-----------|
| Core, archivos, API/CLI y procesos | `software/.venv/bin/python -m unittest discover -s software/tests/viewrv -t . -v` | 66 pruebas correctas; código 0 |
| Cliente TypeScript | `npm test` | 15 pruebas correctas; código 0 |
| Tipos y construcción GUI | `npm run build` | TypeScript y electron-vite correctos; worker de Monaco local |
| Calidad Python propia | Ruff 0.17.1, formato y reglas E4/E7/E9/F/I sobre viewrv, pruebas y packaging | Correcto |
| GUI con core y assembler controlado | `node tests/programs-smoke.cjs` | Edición real, split del mismo modelo, guardado, ensamblado y diagnóstico, edición durante espera, ejemplos, preferencias, cierre y reapertura con otra instancia del core correctos |
| Conservación y resolución de cierre en GUI | `node tests/conservation-smoke.cjs` | Fallo mantiene la ventana; cancelar permite editar; reintentar conserva texto; descarte explícito conserva la copia anterior; archivo asociado ausente se guarda en otro destino antes de cerrar; CLI ajena permanece |
| Construcción Python nativa | `software/packaging/build_linux.sh` | CLI y core onedir construidos en Ubuntu 24.04 con CPython 3.14.9 |
| Empaquetado y extracción | `npm run package:linux -- --config.compression=store` | tar.gz 0.2.0 construido y extraído |
| Producto nativo, Arch | `software/.venv/bin/python software/packaging/smoke_package.py software/build/extracted/viewrv-gui-0.2.0` | Inventario, CLI/core, programas, guardado, recuperación, preferencias, fallo explícito del assembler ausente y cierre correctos |
| Producto nativo, Ubuntu mínimo | Mismo verificador, `--network none --read-only --tmpfs /tmp:exec`, producto montado de solo lectura | Mismo recorrido correcto con los binarios empaquetados; Python externo solo ejecuta el verificador |
| GUI empaquetada | `node tests/smoke.cjs` con `VIEWRV_PRODUCT` | Visor local, Monaco, HTTP/SSE, navegación, ausencia de solicitudes externas y cierre manteniendo la CLI correctos |
| Sandbox nativo de GUI | `node tests/sandbox-smoke.cjs` con `VIEWRV_PRODUCT` | Lanzamiento directo sin `--no-sandbox`, renderer sin Node y cierre del último uso correctos |
| Regresión existente | `make check` en la imagen TP3 fijada, con `--tmpfs /tmp:exec` | 40 pruebas de infraestructura y 2016 comprobaciones de simulación correctas; 375 pendientes; código 0 |
| Diferencias locales | `git diff --check` | Correcto |

Los directorios XDG de las pruebas están aislados; los verificadores cierran los procesos que crean. El visor importado conserva sus archivos y hashes originales: se corrigió el montaje de sus vistas en el wrapper para mantener las dimensiones mientras una sección está oculta, sin modificar GraphViewer.

Las últimas correcciones verificadas incluyen el orden entre una lectura ya pendiente y el autoguardado del mismo archivo, las confirmaciones de guardados anteriores frente a un destino nuevo, y la conservación de un programa recuperado después de finalizar la interfaz que poseía su revisión. Las respuestas antiguas no acreditan la conservación de texto posterior.

## Alcance de las pruebas y trazabilidad

| Caso | Evidencia de este tramo | Límite |
|------|------------------------|--------|
| TEST-PC-002 | Crear dos programas, abrir archivo ya abierto sin releer ni perder edición, copias independientes de ejemplo, split con modelo compartido, resultado correcto/controlado, diagnóstico y traducción vacía | La traducción no acredita el assembler real ni el banco completo de ejemplos |
| TEST-PC-010 | Temporizador desde el primer cambio sin debounce reiniciado; pendientes agrupados por programa/destino; JSON adicional duradero; caída SIGKILL y nueva instancia conservan texto, UUID y apertura confirmados; reapertura real de GUI | No se ejecutó un corte eléctrico ni una campaña en equipos/almacenamientos representativos |
| TEST-PC-012 | Preferencias ausentes o inválidas, respaldo exacto de originales, fallos de escritura sin publicar valores nuevos, autor persistente y recursos locales; producto ejecutado en Arch y Ubuntu | Windows, matriz de zoom/resoluciones y aceptación visual completa pendientes |
| TEST-PC-013 | `program assemble`, rutas relativas al invocador, formato humano/JSON, diagnóstico con detalles y continuidad del trabajo CLI; binarios independientes de Electron | Las 25 operaciones CLI se completan en PC-I05 |
| TEST-PC-017 | Una actualización GUI en vuelo por programa; último pendiente agrupado; acciones esperan recepción de su captura; fallo de recepción evita acción dependiente; editar durante ensamblado/guardado; respuesta o SSE anterior no retrocede texto; cierre congela última captura; cambio de instancia vuelve a confirmar texto sin repetir acciones | LOAD, RUN y debug pertenecen a los siguientes tramos |
| TEST-PC-020 | Asociación ausente no se recrea automáticamente; recuperación conserva texto; Guardar como cambia destino, confirmado en backend y GUI | Aceptación Windows pendiente |
| TEST-PC-026 | Guardado y cierre esperan resultados del core aun si desaparece el waiter HTTP; fallo bloquea cierre; reintento, cancelación, otro destino y descarte explícito; finalizar GUI no finaliza CLI | Sin FPGA; no se acreditan fases de cierre UART |

Los dobles entregan el vector aprobado ADDI x1,x0,5 + HALT: `93 00 50 00 0B 00 00 00`, con PC 0→línea 1 y PC 4→línea 2. También entregan diagnóstico, excepción interna, resultado vacío y resultado malformado. Son entradas literales controladas: el producto comprueba la forma y conserva contexto, sin afirmar que tradujo otros programas ni que ejecutó instrucciones.

La prueba gráfica observa la confirmación de autoguardado dentro de dos segundos desde el inicio de la escritura de su fixture; el tiempo exacto de la última ejecución queda en `gui.log`. La prueba de proceso mata el core después de confirmar recuperación y comprueba el texto al reiniciar. Estas mediciones y la secuencia fsync/reemplazo no certifican por sí solas la tolerancia a corte de energía ni el límite de pérdida bajo cualquier carga de E/S.

## Pendientes explícitos

- #13 debe entregar el módulo público `software.assembler`. El adaptador preparado invoca `assemble(source_text)` sin alterar `AssemblyResult`. #17 debe validar resultados, diagnóstico, catálogo y distribución con el módulo real, incluido su descubrimiento por PyInstaller; el producto actual informa `ASSEMBLY_INTERNAL_ERROR` ante su ausencia.
- Windows sigue pendiente por decisión del usuario: construcción NSIS, rutas y permisos de LocalAppData, durabilidad, recuperación y todos los recorridos con ejecutables nativos requieren un equipo o VM Windows.
- El ensayo físico de pérdida de alimentación y la medición bajo condiciones representativas de CPU, almacenamiento y carga pertenecen a la aceptación. No se equipara SIGKILL con un corte eléctrico.
- UART y recuperación de comunicación siguen en PC-I03; preparación de placa en PC-I04; sesiones y CLI completa en PC-I05; composición y flujos visuales en PC-I06; banco educativo completo y visor asociado a capturas en PC-I07.

Los registros de esta ejecución están en `software/build/evidence/pc-i02/`, excluidos de Git. Capturas: `software/build/gui-pc-i02.png` y `software/build/gui-pc-i02-base.png`. No se publicaron cambios ni se creó una PR.

Huella del diff binario local contra la base, excluyendo este informe: `1354b7240b5f34ed9a25d80e679f622c2e7fc40c627a5b9578977ab3859db37d`. Comando desde la raíz: `git diff --binary -- . ':(exclude)tp3/software/verification/PC-I02.md' | sha256sum`. La evidencia PC-I01 es histórica; su huella corresponde a aquella entrega.
