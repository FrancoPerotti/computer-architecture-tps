# PC-I08 · Mantenimiento por usuario Linux

Fecha: 2026-11-04. Instalación, reinstalación, actualización y desinstalación Linux implementadas y comprobadas localmente. PC-I08 conserva sus pendientes de distribución y aceptación. Esta revisión complementa la [matriz anterior](PC-I08-ACCEPTANCE-2026-11-04.md); la [revisión R2](PC-I08-ACCEPTANCE-2026-11-04-R2.md) registra el estado actualizado.

## Implementación

El paquete incorpora `install.sh` y `uninstall.sh`, accesibles también desde `~/.local/opt/viewrv`. Instala allí el producto, crea `~/.local/bin/viewrv` y registra una entrada de escritorio por usuario. Respeta `XDG_DATA_HOME` absoluto para ese acceso, avisa si falta el directorio CLI en `PATH` y conserva la configuración de la shell. Rechaza ejecución administrativa y destinos o accesos ajenos.

Los cuatro puntos de entrada Linux —GUI, CLI, core y mantenimiento— usan un launcher C compilado en la base Ubuntu fijada, con GCC/sysroot del toolchain bloqueado del programador. Los tres primeros mantienen una exclusión compartida del kernel mientras vive su proceso nativo; el mantenimiento requiere exclusión exclusiva. Un supervisor conserva el bloqueo aunque Electron cierre descriptores heredados. La transmisión de señales utiliza `pidfd`, sin dirigirlas a un PID reutilizado.

El ayudante valida el descriptor heredado y conserva también `InstanceGuard`, la exclusión existente del core. Comprueba `/proc/*/exe` para detectar ejecutables reales de la instalación o fuente. Un PID escrito en descubrimiento no acredita actividad. El mantenimiento no finaliza trabajos; exige cerrar la GUI y finalizar explícitamente CLI/core. Los arranques públicos se rechazan mientras conserva la exclusión.

Los inventarios comprueban rutas, tipos, permisos, enlaces internos y SHA-256 de archivos propios. Una copia preparada se intercambia mediante `renameat2`; los accesos tienen reemplazos reversibles. Los errores de sustitución restauran producto y accesos. Si el sistema impide también la restauración, se conserva el respaldo y se informa su ruta. Los archivos ajenos se conservan, incluso dentro del directorio del producto; una colisión o modificación de archivos propios impide sobrescribirlos silenciosamente.

El ayudante congelado reutiliza el runtime CLI incluido y ejecuta la transacción desde una copia temporal privada. Así puede retirar su propia instalación. La desinstalación conserva Assembly, recovery, records, preferencias y datos ajenos. Si quedan archivos dentro del producto, conserva su directorio y un manifiesto de datos retenidos. Los bloqueos estables del estado por usuario no se eliminan. No modifica controladores, permisos USB ni componentes compartidos.

El acceso de escritorio se comprobó con GIO y rutas que contienen espacios, comillas, dólar, backticks y porcentaje. Aplica las dos capas de escape de la [especificación Desktop Entry](https://specifications.freedesktop.org/desktop-entry/latest/exec-variables.html). Usa `/usr/bin/env --` para que GIO expanda el porcentaje literal del argumento de ruta antes de ejecutar el producto, sin evaluar una shell.

## Artefacto comprobado

- Código de aplicación: commit `2c0ae7110f91ffd73f926a2bac03875e69b56945`; manifiesto con `source_dirty: false`.
- [Archivo de verificación 0.7.0](../build/native-gui-0.7.0-PvZzgn.tar.gz), con [SHA-256 separado](../build/native-gui-0.7.0-PvZzgn.tar.gz.sha256).
- SHA-256: `e626c3507fea772ffb97aa1f525e44ffcd53d6030eccf22446697ecea2b875e0`.
- Raíz: `viewrv-0.7.0-linux-x64-verification`. Los 282 archivos inventariados se comprobaron después de extraer el archivo: bytes, tamaños y modos.
- [Auditoría del paquete](../build/evidence/pc-i08-linux-maintenance-2026-11-04/package-audit.json) y [manifiesto completo](../build/evidence/pc-i08-linux-maintenance-2026-11-04/verification-manifest.json). Incluyen las huellas de las herramientas externas utilizadas para verificarlo.

Es un paquete de verificación sin bitstream aprobado ni `release.json`. Los paquetes anteriores permanecen separados. La construcción de distribución mantiene su exigencia de programador y bitstream reales; este incremento no relaja esa condición.

## Comprobaciones

| Comprobación | Resultado y evidencia |
|---|---|
| Suite Python | [266 pruebas aprobadas](../build/evidence/pc-i08-linux-maintenance-2026-11-04/python.log), incluidas las 13 específicas de mantenimiento. |
| Suite Node y construcción GUI | [42 pruebas aprobadas](../build/evidence/pc-i08-linux-maintenance-2026-11-04/node.log), [construcción y TypeScript](../build/evidence/pc-i08-linux-maintenance-2026-11-04/gui-build.log). |
| Arch · instalación real | [Instalación, actualización, core/CLI y desinstalación congelada aprobadas](../build/evidence/pc-i08-linux-maintenance-2026-11-04/arch-installation.log), siempre con HOME/XDG temporales. |
| Ausencia de descarga original | [Recorrido aprobado](../build/evidence/pc-i08-linux-maintenance-2026-11-04/without-download.log): copia inicial del paquete, instalación, borrado de esa descarga y posterior uso de CLI/core y scripts instalados. |
| CLI nativa | [Tres pruebas de procesos aprobadas](../build/evidence/pc-i08-linux-maintenance-2026-11-04/native-cli.log): 25 operaciones en humano/JSON, Ctrl+C con código 130, continuidad del core, caída y consulta de registros incompletos con hardware controlado. |
| Ubuntu · GUI instalada | [Recorrido completo aprobado](../build/evidence/pc-i08-linux-maintenance-2026-11-04/ubuntu-installation.log): 33 instrucciones/165 etapas, 59 ejemplos, ensamblado real, split, guardado, recuperación y cierre independiente de GUI/CLI. |
| Exclusión real | En el mismo recorrido Ubuntu se rechazaron instalar y desinstalar con la GUI abierta. En Arch/Ubuntu se rechazó el mantenimiento con trabajo CLI/core activo y se rechazaron los tres arranques públicos bajo exclusión de mantenimiento. |
| Sandbox nativo | El recorrido Ubuntu incluye arranque directo de la GUI instalada sin `--no-sandbox`, renderer sin Node y cierre correcto. |
| Fallos y preservación | [13 pruebas específicas aprobadas](../build/evidence/pc-i08-linux-maintenance-2026-11-04/unit.log): archivos y accesos ajenos, fuente/instalación alteradas, rutas peligrosas, proceso real sin PID/bloqueo residual, copia de datos, señales, fallo inicial, restauración y conservación del respaldo ante restauración bloqueada. |
| Calidad | [Ruff y formato aprobados](../build/evidence/pc-i08-linux-maintenance-2026-11-04/quality.log), sintaxis Bash y `git diff --check`. |

Ubuntu corresponde al userland 24.04.5 y snapshot firmado `20261018T000000Z`, con Xvfb privado, red externa aislada y kernel del host Arch. El [entorno registrado](../build/evidence/pc-i08-linux-maintenance-2026-11-04/environment.json) conserva la imagen fijada. No acredita escritorio, compositor, GPU ni USB de un Ubuntu instalado físicamente. El primer intento gráfico en Arch se conserva como diagnóstico por falta de Xvfb; el recorrido gráfico se ejecutó en el entorno Ubuntu preparado.

Las pruebas de instalación usan perfiles descartables y no instalan el producto en el HOME real. El preview visual existente conserva su perfil. Los procesos de prueba finalizaron; no se detuvieron trabajos ajenos.

## Repetición y pendientes

Los comandos de [construcción e instalación](../README.md#instalación-por-usuario-linux) permiten repetir el recorrido. La base requiere las primitivas Linux de las plataformas aprobadas; una sustitución que el sistema no soporte se rechaza. La consistencia por huellas no constituye autenticación del editor. Las pruebas de sustitución y reversión no acreditan durabilidad ante corte eléctrico ni un adversario con control de la misma cuenta.

Continúan pendientes la revisión e incorporación completa de avisos/atribuciones, el bitstream y la Basys 3, Windows, la revisión humana y las condiciones de rendimiento/almacenamiento ya identificadas en la matriz. No se transforma la evidencia controlada de depuración en ejecución FPGA ni se cierra PC-I08.
