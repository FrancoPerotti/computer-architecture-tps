# Evidencia de PC-I01: base ejecutable

Fecha: 29 de octubre de 2026. Rama: `feature/tp3-14-aplicacion-pc`. Base de fuentes: `f0c05f6`, con los cambios locales de esta entrega, todavía sin publicar. El diseño de #12 está incorporado mediante el segundo padre `d488a82` de esa base.

El alcance comprobado es construcción y comunicación local inicial. Windows queda expresamente pendiente por indicación del usuario, que informó no disponer actualmente de equipo o VM. Esto no acredita la aceptación multiplataforma ni PC-I08.

## Entorno y artefactos

| Campo | Valor comprobado |
|-------|------------------|
| Host gráfico | Arch Linux x86_64; sesión X11 utilizada por las comprobaciones automatizadas |
| CPython | 3.14.9 convencional, python-build-standalone; entorno local `software/.venv` |
| Node de construcción | 24.22.1 |
| Electron / React / TypeScript | 45.0.0 / 19.3.1 / 6.0.3 |
| FastAPI / Uvicorn / HTTPX / Click | 0.162.0 / 0.54.0 / 0.28.1 / 8.5.0 |
| PyInstaller / electron-builder | 6.22.3 / 26.18.0 |
| Dependencias resueltas | `requirements-linux.lock`, `requirements-windows.lock` y `gui/package-lock.json` |
| Base de construcción Python | Ubuntu 24.04, imagen TP3 `ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c` |
| Ubuntu mínimo de ejecución | `ubuntu@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852`, sin red externa; intérprete externo montado únicamente para el verificador |
| Producto | `software/gui/dist/viewrv-gui-0.1.0.tar.gz`; compresión store para esta comprobación inicial |
| SHA-256 del tar.gz | `ae8c50ccc5d6d596177ccafdad546b0abfce9526e032bb75cd7ba417e2135430` |
| Visor importado | Revisión `1b409f30f166b94683db317324a7e302b4bda27f` de la ruta indicada por el usuario; procedencia y hashes en `resources/content/viewer/provenance.json` |

El verificador del paquete confirma las huellas de `release.json`. Los ejecutables reales de CLI y core usan conjuntos onedir separados y recursos fuera de ASAR. La copia extraída se utilizó desde un directorio de trabajo ajeno al producto.

## Comprobaciones ejecutadas

Los comandos Python y de Docker parten de `tp3`; los comandos npm y de ventana parten de `tp3/software/gui`. Los scripts de construcción y los procedimientos completos se explican en el [README](../README.md).

| Comprobación | Comando o procedimiento | Resultado |
|--------------|-------------------------|-----------|
| Core, HTTP/CLI y procesos | `software/.venv/bin/python -m unittest discover -s software/tests/viewrv -t . -v` | 27 pruebas correctas; código 0 |
| Cliente TypeScript | `npm test` | 7 pruebas correctas; código 0 |
| Tipos y construcción GUI | `npm run build` | TypeScript y electron-vite correctos; worker Monaco local generado |
| Calidad del código Python propio | Ruff 0.17.1, reglas E4/E7/E9/F/I y formato, sobre viewrv, sus pruebas y packaging | Correcto |
| Script Linux | ShellCheck sobre `software/packaging/build_linux.sh` | Correcto |
| Construcción nativa Python | `software/packaging/build_linux.sh` | CLI y core onedir construidos en Ubuntu 24.04 con CPython 3.14.9 |
| Empaquetado GUI y Python | `npm run package:linux -- --config.compression=store` | tar.gz construido y extraído correctamente |
| Paquete nativo, Arch | `software/.venv/bin/python software/packaging/smoke_package.py software/build/extracted/viewrv-gui-0.1.0` | Inventario, CLI, arranque, continuidad y cierre correctos |
| Paquete nativo, Ubuntu mínimo | Mismo verificador con producto de solo lectura y `--network none` en la imagen Ubuntu indicada | Correcto; CLI y core ejecutan sus binarios empaquetados |
| GUI de desarrollo construida | `node tests/smoke.cjs` | Core/SSE, interacción del visor, Monaco, ausencia de solicitudes externas y cierre correctos |
| GUI del producto extraído | Mismo comando con `VIEWRV_PRODUCT` apuntando al producto | Correcto; al cerrar GUI permanece el trabajo CLI, que luego se consulta y finaliza con el ejecutable empaquetado |
| Arranque gráfico con sandbox nativo | `node tests/sandbox-smoke.cjs`, con `VIEWRV_PRODUCT` | Correcto; renderer sin `window.require`, cierre del último uso y retirada del descubrimiento |
| Regresión existente | `make check` en la imagen TP3 fijada, con `--tmpfs /tmp:exec` | 40 pruebas de infraestructura y 2016 comprobaciones de simulación correctas; 375 casos pendientes; código 0 |
| Diferencias | `git diff --check` | Correcto; los snapshots externos conservan sus bytes y whitespace mediante `.gitattributes` |

Para los scripts gráficos se utilizó Playwright del runtime local de Codex, resuelto mediante `PLAYWRIGHT_MODULE`. Las comprobaciones de procesos y paquetes aíslan XDG y cierran los procesos que crean. No se utilizó FPGA ni assembler real.

La primera ejecución de la regresión agotó el espacio del rootfs de Docker; otra ejecución con tmpfs sin permiso de ejecución impidió utilizar un wrapper de prueba. La ejecución final usa tmpfs con `exec` y es la que acredita la fila anterior. Se retiraron exclusivamente los contenedores fallidos creados durante esta tarea.

Los registros completos de esta ejecución están en `software/build/evidence/`, excluidos del control de versiones. La captura de comprobación está en `software/build/gui-pc-i01.png`.

## Correspondencia con PC-I01

| Obligación | Evidencia y límite |
|------------|-------------------|
| Core, CLI y ventana Electron construibles | Construcción Python nativa, comprobación TypeScript/electron-vite y pruebas de ejecutables extraídos |
| Instancia única y descubrimiento validado | Arranques concurrentes, flock efectivo, publicación atómica, permisos 0700/0600, residuo anterior, identidad/API/perfil y bloqueo ocupado sin publicación |
| Registro y continuidad de trabajos | Un trabajo CLI por instancia, registro GUI idempotente por apertura, consultas sin crear trabajo y finalización explícita del contexto identificado |
| Consulta de estado | Estado conocido de placa y trabajo; ausencia explícita de imagen física confirmada y capturas |
| SSE conectado y coherente | Ocho bloques iniciales, copia y alta indivisibles, revisiones consecutivas, reemplazo de bloques, rechazo de discontinuidades, keepalive real y saturación de una suscripción sin bloquear otras |
| Frontera HTTP | Destino/origen exactos, Bearer, preflight sin efectos, envolturas de error, encabezados 401/405 y consultas finitas |
| Clientes locales | Validación previa del destino, sin redirecciones ni proxies de entorno; GUI con sesión de red directa y estado vivo alimentado por SSE |
| CLI independiente de Electron | Invocaciones nativas desde el producto extraído y entorno Ubuntu sin Node; ayuda y versión sin arrancar core |
| Recursos locales de GUI | Monaco y su worker, FlexLayout, fuentes y GraphViewer aprobado; visor autónomo sin cambios dentro de una vista aislada |
| Cierre | GUI conserva CLI ajena; último uso resuelve su respuesta antes del cierre; una consulta inicial sin trabajos no deja un core abierto sin uso |
| Empaquetado inicial Linux | onedir, tar.gz, inventario y pruebas desde la extracción en Arch y Ubuntu |
| Empaquetado y comportamiento Windows | Preparación de dependencias y script nativo; ejecución y aceptación pendientes por indicación del usuario |

Las pruebas contribuyen parcialmente a TEST-PC-008, TEST-PC-013, TEST-PC-014, TEST-PC-015 y TEST-PC-017. No declaran completos esos casos ni los 30 escenarios o 74 requisitos. Los tres módulos canónicos de protocolo, almacenamiento e interpretación se materializarán con sus implementaciones. Los seis comandos futuros del catálogo mantienen su alcance original.

PC-I02 incorpora programas, edición y conservación persistente. PC-I03 incorpora UART. La CLI completa, sesiones, flujos completos de IDE y asociación de capturas al visor conservan sus entregas posteriores. El mapa inicial de bindings está importado, pero su validación funcional completa corresponde a PC-I07. La implementación y entrega del assembler siguen en #13; la integración y aceptación con assembler y FPGA reales corresponden a #17.

Identificación de las fuentes locales: SHA-256 del diff binario contra la base, excluyendo este informe: `a48855f4591a577d0e1a68109d86f72becda462fbaea11fc7fbedeec1c44fb53`. Se obtiene con `git diff --binary -- . ':(exclude)tp3/software/verification/PC-I01.md' | sha256sum`.
