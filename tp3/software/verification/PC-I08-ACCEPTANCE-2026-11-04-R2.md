# PC-I08: matriz de aceptación integrada

Fecha: 2026-11-04. Evaluación de software y distribución; **PC-I08 no está aceptada**.

Esta tabla se genera a partir de [la evaluación curada](PC-I08-ACCEPTANCE-2026-11-04-R2.json). Pase local significa que se comprobó el alcance indicado en Linux, con el nivel de evidencia registrado; no convierte un adaptador controlado en FPGA ni acredita Windows. Parcial conserva comprobaciones positivas y nombra lo que falta. Pendiente identifica una condición que aún impide completar el recorrido. Fallo identifica una condición de entrega incumplida.

La trazabilidad de 30/30 casos y 74/74 requisitos no es un porcentaje de aceptación.

## Alcance y resultados

Revisión R2: mantenimiento Linux implementado y comprobado sobre un archivo nuevo de 282 archivos inventariados, generado desde el commit 2c0ae71 con fuentes limpias. Pasaron 266 pruebas viewrv (incluyen 13 de mantenimiento), 42 Node y tres ensayos con CLI nativa y sus 25 operaciones. Se probaron instalación, actualización, exclusión, datos y desinstalación congelada en Arch y userland Ubuntu; allí también GUI instalada, 33 instrucciones/165 etapas, 59 ejemplos y sandbox nativo. Se comprobó el rechazo con GUI y trabajo CLI/core abiertos, los tres arranques públicos bajo exclusión y los scripts después de borrar la descarga original. Las evidencias anteriores de assembler, 23 recorridos GUI, SSE, contenido y evaluación humana se conservan identificadas como previas; no se afirma equivalencia binaria del paquete nuevo ni se vuelven a contar como ejecuciones actuales. No hay FPGA, bitstream aprobado ni Windows. La aceptación sigue abierta, incluida la revisión de avisos de la entrega nueva.

Casos: 11 con pase local, 17 parciales, 2 pendientes y 0 fallos.

Requisitos: 36 con pase local, 35 parciales, 3 pendientes y 0 fallos.

## Comprobaciones de distribución

| Comprobación | Resultado | Observación |
|---|---|---|
| Paquete y recursos locales | Pase local | Archivo nuevo: SHA-256, extracción, modos/tamaños y 282 archivos verificados; marcado de verificación y probado con runtimes propios. No se afirma identidad con el paquete anterior. |
| Metadatos del lock | Pase local | Corregida versión declarada 0.6.0 a 0.5.0; código e integridad del tarball no cambiaron. El archivo actualizado contiene la huella correcta. |
| Avisos/licencias del producto | Fallo | Auditoría completa todavía pendiente. La revisión anterior registró 54 entradas sin coincidencia de aviso independiente, dos textos no localizados y tres ámbitos de atribución abiertos. El paquete nuevo incorpora mantenimiento y requiere cerrar y actualizar esa revisión; esos conteos no prueban ausencia de textos en bundles. |
| Instalación y desinstalación por usuario Linux | Pase local | Implementadas y comprobadas instalación, reinstalación, exclusión de aperturas, rechazo en uso, restauración, retirada de accesos propios y preservación de datos; perfiles temporales Arch y userland Ubuntu. |
| Aceptación física y Windows | Pendiente | Bitstream, placa y Windows no disponibles; se mantiene el aplazamiento solicitado por el usuario. |

## Pendientes identificados

| ID | Condición pendiente |
|---|---|
| HW | Basys 3, bitstream aprobado con revisión/huella y recorrido real JTAG/UART de la misma placa, incluidos fallos, permisos y reenumeración. |
| WIN | Paquete NSIS, instalación/desinstalación y ejecución Windows. Diferido por el usuario por falta de equipo o VM. |
| UBUNTU_DESKTOP | Ubuntu instalado con escritorio/compositor/GPU y acceso USB reales. El pase actual corresponde a userland Ubuntu con Xvfb y kernel Arch. |
| HUMAN | Persona del público previsto sin asistencia y revisión del grupo/docente sobre claridad, exactitud y utilidad; no hay aceptación humana formal registrada. |
| MODEST | Medición actual de respuesta visible/cadencia y revisión de todas las incidencias en equipo modesto identificado y condiciones representativas. |
| POWER | Corte eléctrico real con almacenamiento identificado para la garantía de pérdida máxima/durabilidad; matar un proceso no lo sustituye. |
| NOTICES | Completar e incorporar el inventario de avisos; revisar las 54 entradas sin coincidencia como archivo independiente, los dos textos completos no localizados y la atribución del bundle/GraphViewer/dependencias estáticas antes de distribuir. |

## Variantes técnicas obligatorias

| Grupo | Resultado local | Evidencia y alcance |
|---|---|---|
| Versiones | Pase local | [PY](#evidencia-py), [NODE](#evidencia-node), [GUI_ARCH](#evidencia-gui_arch). A/B/C, respuestas tardías, cierre y ensamblado sobre revisión capturada comprobados. |
| Texto antes de acciones | Pase local | [NODE](#evidencia-node), [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch). Recepción de texto antes de la acción, fallo de recepción y respuesta vieja sin retroceso comprobados. |
| Selección | Parcial | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch). HW, WIN: Prioridad explícita/recordada y ambigüedad cubiertas con enumeración controlada; falta reenumeración física. |
| Propiedad | Pase local | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native), [GUI_ARCH](#evidencia-gui_arch). Control único y observadores sin finalizar ni mutar el trabajo ajeno comprobados. |
| Arranque | Pase local | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native), [NATIVE_ARCH](#evidencia-native_arch), [UBUNTU_GUI](#evidencia-ubuntu_gui). Exclusión, arranque concurrente, restos de descubrimiento, identidad/API/perfil y runtime nativo comprobados. |
| HTTP | Pase local | [PY](#evidencia-py). Autenticación, Host, Origin, preflight, estados/envoltura y CLI sin Origin comprobados. |
| SSE | Pase local | [PY](#evidencia-py), [NODE](#evidencia-node), [SSE_CLIENT](#evidencia-sse_client). Estado inicial, bloques vacíos/omitidos, gap, instancia y reconexión sin reemplazo por HTTP viejo comprobados. |
| Saturación | Pase local | [SSE_SERVER](#evidencia-sse_server), [PY](#evidencia-py). Se bloqueó el send real de ASGI hasta superar los 32 pendientes; el otro canal continuó y la resuscripción entregó estado completo. |
| Keepalive | Pase local | [PY](#evidencia-py), [SSE_CLIENT](#evidencia-sse_client). Comentarios reales preservan actividad; el reloj del renderer controla el umbral de 45 s y los reintentos. Cerrar cancela la espera, sin UART/RESET. |
| Preferencias | Pase local | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch). Ausencia, invalidez, conservación del original y reemplazo fallido sin publicar valores no guardados comprobados. |
| Evidencia | Pase local | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native). Cero observaciones, identidades/esquemas distintos, truncado, índices, contradicciones y fallo conocido cubiertos con archivos/procesos. |
| Interpretación | Parcial | [PY](#evidencia-py), [EDUCATION](#evidencia-education). HW: Validez, wrap, forwarding, x0, stall, redirect y drain contrastados con oráculos; falta capturar FPGA real. |
| Seguimiento | Parcial | [PY](#evidencia-py), [NODE](#evidencia-node), [GUI_ARCH](#evidencia-gui_arch). HW: PC repetido, retención, retiro de WB y gap sin reasignar aparición cubiertos; falta continuidad física. |
| Recursos | Pase local | [PACKAGE](#evidencia-package), [PY](#evidencia-py), [NATIVE_ARCH](#evidencia-native_arch), [UBUNTU_GUI](#evidencia-ubuntu_gui). Rutas ajenas/con espacios, huellas, recursos faltantes y ejecutables locales sin fallback de PATH comprobados. |
| Mantenimiento | Pase local | [MAINTENANCE](#evidencia-maintenance), [INSTALL_UNIT](#evidencia-install_unit), [INSTALL_ARCH](#evidencia-install_arch), [INSTALL_NO_DOWNLOAD](#evidencia-install_no_download), [UBUNTU_GUI](#evidencia-ubuntu_gui). Pase local Linux: instalación repetida, rechazo con GUI/CLI/core activos, arranques concurrentes, sustitución/reversión, scripts sin descarga original, retirada de accesos y conservación de datos. Windows sigue diferido en WIN. |
| Preparación | Parcial | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch). HW, WIN: Fase programador/UART, timeout/terminación del hijo, errores y selección ambigua comprobados; falta placa/controladores. |

## Casos

| Caso | Resultado local | Evidencia | Pendientes y evaluación |
|---|---|---|---|
| [**TEST-PC-001**](../../docs/software/viewrv/verificacion.md#test-pc-001) · Exploración sin placa | Pase local | [NATIVE_ARCH](#evidencia-native_arch), [UBUNTU_GUI](#evidencia-ubuntu_gui), [PY](#evidencia-py) | Navegación conceptual y recursos locales: 33 instrucciones y cinco etapas, sin UART ni capturas inventadas. |
| [**TEST-PC-002**](../../docs/software/viewrv/verificacion.md#test-pc-002) · Programas y edición | Pase local | [PY](#evidencia-py), [ASM](#evidencia-asm), [NODE](#evidencia-node), [GUI_ARCH](#evidencia-gui_arch), [NATIVE_ARCH](#evidencia-native_arch), [UBUNTU_GUI](#evidencia-ubuntu_gui) | Borradores, copias, modelos compartidos, splits, teclado/completado y ensamblado válido/diagnóstico comprobados en software. |
| [**TEST-PC-003**](../../docs/software/viewrv/verificacion.md#test-pc-003) · LOAD y RUN | Parcial | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native), [GUI_ARCH](#evidencia-gui_arch) | HW: Imagen literal de ocho bytes, fases LOAD/DONE y RUN cubiertos con serial controlado; falta contrastar x1=5 en placa por ambas interfaces. |
| [**TEST-PC-004**](../../docs/software/viewrv/verificacion.md#test-pc-004) · Solapamiento y dependencias | Parcial | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch), [EDUCATION](#evidencia-education) | HW: Capturas completas, valores, diferencias y temporalidad contrastados con vectores independientes; faltan programas reales en FPGA. |
| [**TEST-PC-005**](../../docs/software/viewrv/verificacion.md#test-pc-005) · Breakpoints y controles | Pase local | [PY](#evidencia-py), [NODE](#evidencia-node), [GUI_ARCH](#evidencia-gui_arch) | Coincidencias múltiples, retención, pausa sin cola, controles/reinicio y solo lectura comprobados con core/serial controlados e interacción GUI. |
| [**TEST-PC-006**](../../docs/software/viewrv/verificacion.md#test-pc-006) · Terminal y drain | Parcial | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch), [EDUCATION](#evidencia-education) | HW: HALT/fault, drain y terminal inspeccionable cubiertos con trazas; faltan commits y drain físicos. |
| [**TEST-PC-007**](../../docs/software/viewrv/verificacion.md#test-pc-007) · Espera y comunicación interrumpida | Pase local | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch), [PERFORMANCE](#evidencia-performance) | Fragmentación/truncación y espera de comunicación probadas; edición/navegación siguen disponibles y no se publica una captura parcial. No implica aceptar rendimiento en equipo modesto. |
| [**TEST-PC-008**](../../docs/software/viewrv/verificacion.md#test-pc-008) · Investigación por CLI y reproducción | Parcial | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native), [GUI_ARCH](#evidencia-gui_arch), [NATIVE_ARCH](#evidencia-native_arch) | HW: Contexto, registros y observación/reproducción controlada entre clientes comprobados; falta repetir investigación física con iguales condiciones. |
| [**TEST-PC-009**](../../docs/software/viewrv/verificacion.md#test-pc-009) · Registro predeterminado | Pase local | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native) | Autor explícito/ausente, start/observaciones/end, fallos y retención de JSONL comprobados con archivos y sesiones controladas. |
| [**TEST-PC-010**](../../docs/software/viewrv/verificacion.md#test-pc-010) · Borradores y caída | Parcial | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch), [NATIVE_ARCH](#evidencia-native_arch), [UBUNTU_GUI](#evidencia-ubuntu_gui) | POWER: Recuperación ante cierre y pérdida de proceso, aperturas y conservación temporizada cubiertas; falta corte eléctrico del almacenamiento de aceptación. |
| [**TEST-PC-011**](../../docs/software/viewrv/verificacion.md#test-pc-011) · Uso autónomo y demostración | Pendiente | [VISUAL](#evidencia-visual), [SOURCE](#evidencia-source) | HUMAN, HW: Las revisiones visuales previas no documentan un recorrido autónomo del público previsto ni una demostración física al docente. |
| [**TEST-PC-012**](../../docs/software/viewrv/verificacion.md#test-pc-012) · Entornos, red y presentación | Parcial | [PACKAGE](#evidencia-package), [UBUNTU_GUI](#evidencia-ubuntu_gui), [UBUNTU_SANDBOX](#evidencia-ubuntu_sandbox), [SANDBOX_ARCH](#evidencia-sandbox_arch), [GUI_ARCH](#evidencia-gui_arch), [SOURCE](#evidencia-source), [ENV](#evidencia-env) | WIN, UBUNTU_DESKTOP, HUMAN: Misma carga útil en Arch y userland Ubuntu, recursos locales, red aislada, español/zoom y presentación comprobados dentro de esos alcances. |
| [**TEST-PC-013**](../../docs/software/viewrv/verificacion.md#test-pc-013) · Personas y automatizaciones | Pase local | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native), [NPM_TREE](#evidencia-npm_tree) | 25 operaciones en humano/JSON, ayuda/versión locales, errores de uso y Ctrl+C/códigos de proceso comprobados; la CLI nativa no requiere Electron. |
| [**TEST-PC-014**](../../docs/software/viewrv/verificacion.md#test-pc-014) · Preparación desde el producto | Pendiente | [PY](#evidencia-py), [NATIVE_ARCH](#evidencia-native_arch), [PACKAGE](#evidencia-package), [SOURCE](#evidencia-source), [LICENSES](#evidencia-licenses), [MAINTENANCE](#evidencia-maintenance) | HW, WIN, NOTICES: Programador nativo, errores/fases y mantenimiento Linux comprobados; faltan preparación física, distribución final con bitstream, avisos completos y Windows. |
| [**TEST-PC-015**](../../docs/software/viewrv/verificacion.md#test-pc-015) · Automatización no atendida | Pase local | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native) | Selección inequívoca, errores de arranque/identidad, ausencia de prompts y no repetición de operaciones inciertas comprobadas. |
| [**TEST-PC-016**](../../docs/software/viewrv/verificacion.md#test-pc-016) · RUN con y sin límite | Parcial | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native) | HW: Plazos de RUN y terminal/RESET contrastados con reloj, serial y procesos controlados; falta validar terminación/límite contra el procesador real. |
| [**TEST-PC-017**](../../docs/software/viewrv/verificacion.md#test-pc-017) · Versiones y foco | Pase local | [PY](#evidencia-py), [NODE](#evidencia-node), [GUI_ARCH](#evidencia-gui_arch) | Versiones A/B/C, recepción antes de acciones, LOAD ya iniciado, foco y referencias inválidas comprobados sin UART adicional ni retroceso de texto. |
| [**TEST-PC-018**](../../docs/software/viewrv/verificacion.md#test-pc-018) · Correspondencia y seguimiento | Parcial | [PY](#evidencia-py), [NODE](#evidencia-node), [GUI_ARCH](#evidencia-gui_arch), [EDUCATION](#evidencia-education) | HW: Load-use, bucle con PC repetido, redirect, fault, wrap/gap y seguimiento sin reasignar identidad cubiertos con oráculos literales; falta FPGA. |
| [**TEST-PC-019**](../../docs/software/viewrv/verificacion.md#test-pc-019) · Cobertura educativa | Parcial | [PY](#evidencia-py), [ASM](#evidencia-asm), [NODE](#evidencia-node), [GUI_ARCH](#evidencia-gui_arch), [NATIVE_ARCH](#evidencia-native_arch), [UBUNTU_GUI](#evidencia-ubuntu_gui), [EDUCATION](#evidencia-education) | HW, HUMAN: 33 mnemónicos, 165 etapas, 59 programas y guías comprobados; falta contraste físico y validación pedagógica del grupo. |
| [**TEST-PC-020**](../../docs/software/viewrv/verificacion.md#test-pc-020) · Archivo asociado movido o eliminado | Pase local | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch) | Fuente asociada movida/eliminada: recuperación y guardar con otro destino comprobados; no se recrea silenciosamente el archivo ausente. |
| [**TEST-PC-021**](../../docs/software/viewrv/verificacion.md#test-pc-021) · Fallo de escritura de evidencia | Pase local | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch) | Fallo de registro conserva unidades previas, estado consultable y autoguardado; no sigue escribiendo el mismo ensayo ni bloquea continuar. |
| [**TEST-PC-022**](../../docs/software/viewrv/verificacion.md#test-pc-022) · Corte durante registro | Parcial | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native) | POWER: Caída de proceso y líneas finales/intermedias dañadas recuperan índices/identidad sin inventar datos; falta ensayo de corte eléctrico. |
| [**TEST-PC-023**](../../docs/software/viewrv/verificacion.md#test-pc-023) · Desconexión durante RUN | Parcial | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native), [GUI_ARCH](#evidencia-gui_arch) | HW: Terminal iniciado y RESET confirmado/no confirmado se distinguen con serial/procesos controlados; falta desconectar hardware real. |
| [**TEST-PC-024**](../../docs/software/viewrv/verificacion.md#test-pc-024) · Desconexión durante LOAD y STEP | Parcial | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch) | HW: Fases LOAD/STEP y pausa de Continuar antes del siguiente STEP cubiertas con serial controlado; falta UART física. |
| [**TEST-PC-025**](../../docs/software/viewrv/verificacion.md#test-pc-025) · Puerto y selección | Parcial | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch) | HW, WIN: Prioridad explícita/recordada y ambigüedad cubiertas; falta retirada/reenumeración de dispositivos y controladores en los sistemas reales. |
| [**TEST-PC-026**](../../docs/software/viewrv/verificacion.md#test-pc-026) · Salida con código pendiente | Pase local | [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch), [NATIVE_ARCH](#evidencia-native_arch), [UBUNTU_GUI](#evidencia-ubuntu_gui), [CLI_NATIVE](#evidencia-cli_native) | Cierre exitoso/fallido, reintento, otro destino, descarte explícito y continuidad del trabajo CLI ajeno comprobados. |
| [**TEST-PC-027**](../../docs/software/viewrv/verificacion.md#test-pc-027) · Respuesta visible | Parcial | [PERFORMANCE](#evidencia-performance), [PY](#evidencia-py), [GUI_ARCH](#evidencia-gui_arch), [ENV](#evidencia-env) | MODEST: Hay muestras anteriores y pruebas de respuesta durante espera; falta medir la GUI actual en el equipo modesto de aceptación. |
| [**TEST-PC-028**](../../docs/software/viewrv/verificacion.md#test-pc-028) · Movimiento del diagrama | Parcial | [PERFORMANCE](#evidencia-performance), [GUI_ARCH](#evidencia-gui_arch), [ENV](#evidencia-env) | MODEST, UBUNTU_DESKTOP: Las muestras históricas conservan incidencias y cámara real; Xvfb no sirve para aceptar 60 FPS ni la regularidad en equipos reales. |
| [**TEST-PC-029**](../../docs/software/viewrv/verificacion.md#test-pc-029) · CLI controla, GUI observa | Parcial | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native), [GUI_ARCH](#evidencia-gui_arch), [SSE_SERVER](#evidencia-sse_server), [SSE_CLIENT](#evidencia-sse_client) | HW: Observación, reconexión/keepalive e inactividad y saturación frenando ASGI send comprobadas. Solo se cierra el canal afectado, no se emite RESET y las identidades permanecen; falta sesión física. |
| [**TEST-PC-030**](../../docs/software/viewrv/verificacion.md#test-pc-030) · GUI controla, CLI observa | Parcial | [PY](#evidencia-py), [CLI_NATIVE](#evidencia-cli_native), [GUI_ARCH](#evidencia-gui_arch) | HW: Consultas CLI finitas/todos/after N y observadores sin consumo ni STEP implícito cubiertos; falta compararlas con depuración física GUI. |

## Requisitos

Los resultados se evaluaron por criterio; no se hereda un pase por mencionar un caso de prueba.

| Requisito | Resultado local | Casos normativos | Pendientes y evaluación |
|---|---|---|---|
| **SRS-PC-V01** | Parcial | 001, 011, 019 | HUMAN, HW: Cobertura y explicaciones presentes; revisión pedagógica y contraste físico de resultados aún pendientes. |
| **SRS-PC-V02** | Pase local | 001, 011, 019 | Recorrido conceptual y catálogo con sintaxis, operandos y función comprobados; el recorrido se distingue de ejecución física. |
| **SRS-PC-V03** | Pase local | 001, 011, 019 | Recorrido conceptual y catálogo con sintaxis, operandos y función comprobados; el recorrido se distingue de ejecución física. |
| **SRS-PC-V04** | Parcial | 001, 011, 019 | HUMAN, HW: Cobertura y explicaciones presentes; revisión pedagógica y contraste físico de resultados aún pendientes. |
| **SRS-PC-V05** | Parcial | 001, 011, 019 | HUMAN, HW: Cobertura y explicaciones presentes; revisión pedagógica y contraste físico de resultados aún pendientes. |
| **SRS-PC-E01** | Pase local | 002 | Edición/copias, teclado, completado, documentación y traducción/mapa o diagnóstico comprobados en el alcance Linux registrado. |
| **SRS-PC-E02** | Pase local | 002 | Edición/copias, teclado, completado, documentación y traducción/mapa o diagnóstico comprobados en el alcance Linux registrado. |
| **SRS-PC-E03** | Parcial | 002, 010, 020, 021, 026 | POWER: Autoguardado, recuperación y fallos de conservación comprobados; falta durabilidad y pérdida máxima ante corte eléctrico real. |
| **SRS-PC-E04** | Pase local | 002 | Edición/copias, teclado, completado, documentación y traducción/mapa o diagnóstico comprobados en el alcance Linux registrado. |
| **SRS-PC-E05** | Pase local | 002 | Edición/copias, teclado, completado, documentación y traducción/mapa o diagnóstico comprobados en el alcance Linux registrado. |
| **SRS-PC-E06** | Pase local | 002 | Edición/copias, teclado, completado, documentación y traducción/mapa o diagnóstico comprobados en el alcance Linux registrado. |
| **SRS-PC-E07** | Pase local | 002 | Edición/copias, teclado, completado, documentación y traducción/mapa o diagnóstico comprobados en el alcance Linux registrado. |
| **SRS-PC-E08** | Parcial | 003, 017 | HW: Versiones e imagen confirmada diferenciadas con core/serial controlados; falta confirmar el vínculo en una carga física. |
| **SRS-PC-E09** | Pase local | 010 | Cerrar tab conserva borrador recuperable; descartar requiere acción diferente y explícita. |
| **SRS-PC-O01** | Parcial | 003, 014, 015, 017, 023, 024, 025 | HW: Semántica, fases, admisión y errores cubiertos con serial controlado y pseudo-terminal; falta confirmar efectos en la Basys 3. |
| **SRS-PC-O02** | Parcial | 003, 014, 017 | HW: Semántica, fases, admisión y errores cubiertos con serial controlado y pseudo-terminal; falta confirmar efectos en la Basys 3. |
| **SRS-PC-O03** | Parcial | 003, 014, 017 | HW: Semántica, fases, admisión y errores cubiertos con serial controlado y pseudo-terminal; falta confirmar efectos en la Basys 3. |
| **SRS-PC-O04** | Parcial | 016 | HW: Semántica, fases, admisión y errores cubiertos con serial controlado y pseudo-terminal; falta confirmar efectos en la Basys 3. |
| **SRS-PC-O05** | Parcial | 016, 023 | HW: Semántica, fases, admisión y errores cubiertos con serial controlado y pseudo-terminal; falta confirmar efectos en la Basys 3. |
| **SRS-PC-O06** | Parcial | 014, 025 | HW: Programación/confirmación UART separadas y programador nativo presentes; bitstream aprobado y preparación física pendientes. |
| **SRS-PC-O07** | Parcial | 014, 025 | HW: Programación/confirmación UART separadas y programador nativo presentes; bitstream aprobado y preparación física pendientes. |
| **SRS-PC-O08** | Parcial | 016 | HW: Semántica, fases, admisión y errores cubiertos con serial controlado y pseudo-terminal; falta confirmar efectos en la Basys 3. |
| **SRS-PC-O09** | Parcial | 023 | HW: Semántica, fases, admisión y errores cubiertos con serial controlado y pseudo-terminal; falta confirmar efectos en la Basys 3. |
| **SRS-PC-O10** | Parcial | 024 | HW: Semántica, fases, admisión y errores cubiertos con serial controlado y pseudo-terminal; falta confirmar efectos en la Basys 3. |
| **SRS-PC-D01** | Pase local | 004, 005 | Comandos, breakpoints, protección y navegación comprobados en sesiones controladas; no se atribuye una ejecución a FPGA. |
| **SRS-PC-D02** | Parcial | 004, 005 | HW: Capturas completas, datos, cambios y terminal correctos en vectores revisados; falta contraste con capturas del procesador real. |
| **SRS-PC-D03** | Pase local | 004, 005 | Comandos, breakpoints, protección y navegación comprobados en sesiones controladas; no se atribuye una ejecución a FPGA. |
| **SRS-PC-D04** | Pase local | 004, 005 | Comandos, breakpoints, protección y navegación comprobados en sesiones controladas; no se atribuye una ejecución a FPGA. |
| **SRS-PC-D05** | Pase local | 005, 017 | Comandos, breakpoints, protección y navegación comprobados en sesiones controladas; no se atribuye una ejecución a FPGA. |
| **SRS-PC-D06** | Pase local | 005, 017 | Comandos, breakpoints, protección y navegación comprobados en sesiones controladas; no se atribuye una ejecución a FPGA. |
| **SRS-PC-D07** | Pase local | 005, 017 | Comandos, breakpoints, protección y navegación comprobados en sesiones controladas; no se atribuye una ejecución a FPGA. |
| **SRS-PC-D08** | Parcial | 004, 018, 029 | HW: Capturas completas, datos, cambios y terminal correctos en vectores revisados; falta contraste con capturas del procesador real. |
| **SRS-PC-D09** | Parcial | 004, 018, 029 | HW: Capturas completas, datos, cambios y terminal correctos en vectores revisados; falta contraste con capturas del procesador real. |
| **SRS-PC-D10** | Parcial | 006 | HW: Capturas completas, datos, cambios y terminal correctos en vectores revisados; falta contraste con capturas del procesador real. |
| **SRS-PC-D11** | Pase local | 007, 029 | Comandos, breakpoints, protección y navegación comprobados en sesiones controladas; no se atribuye una ejecución a FPGA. |
| **SRS-PC-I01** | Parcial | 004, 018, 028, 029 | HW: Diagrama, selección y seguimiento conservan la temporalidad y distinguen apariciones en oráculos controlados; falta validar capturas físicas. |
| **SRS-PC-I02** | Parcial | 004, 018, 028, 029 | HW: Diagrama, selección y seguimiento conservan la temporalidad y distinguen apariciones en oráculos controlados; falta validar capturas físicas. |
| **SRS-PC-I03** | Parcial | 018 | HW: Diagrama, selección y seguimiento conservan la temporalidad y distinguen apariciones en oráculos controlados; falta validar capturas físicas. |
| **SRS-PC-I04** | Parcial | 018 | HW: Diagrama, selección y seguimiento conservan la temporalidad y distinguen apariciones en oráculos controlados; falta validar capturas físicas. |
| **SRS-PC-C01** | Pase local | 008, 013, 015 | Cobertura de 25 operaciones, formatos, errores y semántica compartida comprobados con cliente nativo y core de pruebas. |
| **SRS-PC-C02** | Parcial | 008, 013, 015 | HW: Investigación y observación en ambas direcciones cubiertas en software; falta reproducción y continuidad con la FPGA. |
| **SRS-PC-C03** | Pase local | 008, 013, 015 | Cobertura de 25 operaciones, formatos, errores y semántica compartida comprobados con cliente nativo y core de pruebas. |
| **SRS-PC-C04** | Pase local | 008, 013, 015 | Cobertura de 25 operaciones, formatos, errores y semántica compartida comprobados con cliente nativo y core de pruebas. |
| **SRS-PC-C05** | Pase local | 008, 013, 015 | Cobertura de 25 operaciones, formatos, errores y semántica compartida comprobados con cliente nativo y core de pruebas. |
| **SRS-PC-C06** | Pase local | 008, 013, 015 | Cobertura de 25 operaciones, formatos, errores y semántica compartida comprobados con cliente nativo y core de pruebas. |
| **SRS-PC-C07** | Parcial | 029 | HW: Investigación y observación en ambas direcciones cubiertas en software; falta reproducción y continuidad con la FPGA. |
| **SRS-PC-C08** | Parcial | 030 | HW: Investigación y observación en ambas direcciones cubiertas en software; falta reproducción y continuidad con la FPGA. |
| **SRS-PC-R01** | Pase local | 009 | Registro, contexto/autor, interrupciones, retención y fallo de escritura cubiertos sin reemplazar el resultado por errores de registro. |
| **SRS-PC-R02** | Pase local | 008, 009, 017 | Registro, contexto/autor, interrupciones, retención y fallo de escritura cubiertos sin reemplazar el resultado por errores de registro. |
| **SRS-PC-R03** | Pase local | 009 | Registro, contexto/autor, interrupciones, retención y fallo de escritura cubiertos sin reemplazar el resultado por errores de registro. |
| **SRS-PC-R04** | Pase local | 009 | Registro, contexto/autor, interrupciones, retención y fallo de escritura cubiertos sin reemplazar el resultado por errores de registro. |
| **SRS-PC-R05** | Pase local | 009 | Registro, contexto/autor, interrupciones, retención y fallo de escritura cubiertos sin reemplazar el resultado por errores de registro. |
| **SRS-PC-R06** | Pase local | 021 | Registro, contexto/autor, interrupciones, retención y fallo de escritura cubiertos sin reemplazar el resultado por errores de registro. |
| **SRS-PC-R07** | Parcial | 022 | POWER: Recuperación de observaciones guardadas tras caída de proceso comprobada; el corte eléctrico requiere otro ensayo. |
| **SRS-PC-Q01** | Parcial | 003, 004, 006, 017, 018, 019, 021, 022 | HW, HUMAN: Bits recibidos e inferencias se distinguen en vectores independientes; faltan contraste físico y revisión educativa formal. |
| **SRS-PC-Q02** | Pase local | 007, 027, 028 | Edición/navegación y consultas siguen disponibles durante espera serial; el umbral de rendimiento se evalúa aparte en Q03. |
| **SRS-PC-Q03** | Parcial | 027, 028 | MODEST, UBUNTU_DESKTOP: Mediciones históricas conservadas con incidencias; no se aceptan los objetivos actuales por promedio ni en Xvfb. |
| **SRS-PC-Q04** | Pendiente | 011 | HUMAN, HW: Falta evaluación autónoma del flujo completo y repetido por el público previsto, con la placa preparada. |
| **SRS-PC-Q05** | Pendiente | 011 | HUMAN, HW: Falta evaluación autónoma del flujo completo y repetido por el público previsto, con la placa preparada. |
| **SRS-PC-Q06** | Parcial | 012 | WIN, UBUNTU_DESKTOP: Carga útil equivalente en Arch y userland Ubuntu aislado; Windows y escritorio Ubuntu real permanecen pendientes. |
| **SRS-PC-Q07** | Pase local | 012 | Funcionamiento local con red externa deshabilitada desde el arranque; revisión de fuentes sin envío automático/telemetría configurados. |
| **SRS-PC-Q08** | Pase local | 012 | Funcionamiento local con red externa deshabilitada desde el arranque; revisión de fuentes sin envío automático/telemetría configurados. |
| **SRS-PC-Q09** | Pase local | 012 | Interfaz y contenido disponibles en español, con preferencias de idioma separadas; se conservan nombres técnicos del diagrama aprobado. |
| **SRS-PC-Q10** | Parcial | 012 | HUMAN, WIN, UBUNTU_DESKTOP: Resoluciones/zoom y split revisados localmente; falta legibilidad en los equipos y escritorios finales de aceptación. |
| **SRS-PC-Q11** | Pase local | 006, 007, 015, 021 | Fallos y mensajes de conservación, transporte y registro comprobados, con la revisión visual documentada y contratos preservados. |
| **SRS-PC-Q12** | Pase local | 010, 020, 026 | Reapertura automática de programas abiertos y borradores tras core nuevo comprobada; no se restaura CPU ni disposición de paneles. |
| **SRS-PC-Q13** | Pendiente | 014 | HW, WIN, NOTICES: Runtimes, programador y mantenimiento Linux incluidos y comprobados; faltan avisos completos y aceptación física/Windows de preparación y distribución. |
| **SRS-PC-Q14** | Pase local | 012 | Escala general por teclado/persistencia y tema único comprobados y revisados localmente; no se exige selector de temas. |
| **SRS-PC-Q15** | Pase local | 012 | Escala general por teclado/persistencia y tema único comprobados y revisados localmente; no se exige selector de temas. |
| **SRS-PC-X01** | Pase local | 002, 019 | Assembler real entrega traducción completa y mapa o un diagnóstico; errores internos/lectura se mantienen distintos. |
| **SRS-PC-X02** | Parcial | 003, 007, 016, 023, 024 | HW: Bytes normativos, perfiles, plazos, captura completa y recuperaciones cubiertos con serial/PTY controlados; falta confirmación física. |
| **SRS-PC-X03** | Parcial | 003, 007, 016, 023, 024 | HW: Bytes normativos, perfiles, plazos, captura completa y recuperaciones cubiertos con serial/PTY controlados; falta confirmación física. |
| **SRS-PC-X04** | Parcial | 003, 007, 016, 023, 024 | HW: Bytes normativos, perfiles, plazos, captura completa y recuperaciones cubiertos con serial/PTY controlados; falta confirmación física. |
| **SRS-PC-X05** | Parcial | 003, 007, 016, 023, 024 | HW: Bytes normativos, perfiles, plazos, captura completa y recuperaciones cubiertos con serial/PTY controlados; falta confirmación física. |

## Evidencia

### Evidencia PY

[build/evidence/pc-i08-linux-maintenance-2026-11-04/python.log](../build/evidence/pc-i08-linux-maintenance-2026-11-04/python.log) · current_run.

266 pruebas Python aprobadas, incluidas las 13 de instalación Linux, core/API/CLI y hardware controlado; no FPGA.

### Evidencia ASM

[build/evidence/pc-i08-acceptance-2026-11-04/assembler.log](../build/evidence/pc-i08-acceptance-2026-11-04/assembler.log) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. 114 pruebas del assembler real pasadas; bytes, mapa PC–línea y diagnósticos.

### Evidencia NODE

[build/evidence/pc-i08-linux-maintenance-2026-11-04/node.log](../build/evidence/pc-i08-linux-maintenance-2026-11-04/node.log) · current_run.

42 pruebas Node aprobadas. No se modificaron componentes de la GUI en este incremento.

### Evidencia AUDIT_TESTS

[build/evidence/pc-i08-acceptance-2026-11-04/audit-tests.log](../build/evidence/pc-i08-acceptance-2026-11-04/audit-tests.log) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. 2 regresiones del reconocimiento de avisos: fuentes, avisos Chromium, programador y exclusión de módulos de código llamados licenses.

### Evidencia GUI_ARCH

[build/gui-check/2026-11-04T02-38-10-481Z/summary.json](../build/gui-check/2026-11-04T02-38-10-481Z/summary.json) · prior_evidence.

Evidencia histórica de los 23 recorridos GUI previos sobre el paquete anterior. No repetida ni contada como ejecución actual; no acredita equivalencia binaria del archivo nuevo. El recorrido nativo actual de GUI instalada está en UBUNTU_GUI.

### Evidencia NATIVE_ARCH

[build/pc-i08-linux-native-ide.log](../build/pc-i08-linux-native-ide.log) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. GUI ASAR, core y CLI del archivo fbd93a8c…: 33 instrucciones/165 etapas, 59 ejemplos, assembler, split, autoguardado, reapertura tras core nuevo y guardado de borrador. Sin placa; restricción de red por proxy después del arranque.

### Evidencia SANDBOX_ARCH

[build/pc-i08-linux-sandbox.log](../build/pc-i08-linux-sandbox.log) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. Arranque directo del archivo fbd93a8c… con sandbox nativo, renderer sin Node y cierre correcto.

### Evidencia UBUNTU_GUI

[build/evidence/pc-i08-linux-maintenance-2026-11-04/ubuntu-installation.log](../build/evidence/pc-i08-linux-maintenance-2026-11-04/ubuntu-installation.log) · current_run.

GUI y core/CLI desde instalación por usuario del archivo nuevo: 33 instrucciones/165 etapas, 59 ejemplos, assembler, splits/guardado/recuperación y cierre; mantenimiento rechazado con GUI abierta. Ubuntu 24.04.5 userland/Xvfb y kernel Arch, red aislada.

### Evidencia UBUNTU_SANDBOX

[build/evidence/pc-i08-linux-maintenance-2026-11-04/ubuntu-installation.log](../build/evidence/pc-i08-linux-maintenance-2026-11-04/ubuntu-installation.log) · current_run.

El mismo recorrido registra arranque directo de GUI instalada con sandbox nativo, renderer sin Node y cierre correcto.

### Evidencia CLI_NATIVE

[build/evidence/pc-i08-linux-maintenance-2026-11-04/native-cli.log](../build/evidence/pc-i08-linux-maintenance-2026-11-04/native-cli.log) · current_run.

Tres ensayos sobre CLI/runtime del archivo nuevo: 25 operaciones humano/JSON, Ctrl+C 130 sin detener el core y consulta tras caída. Core con hardware controlado.

### Evidencia PACKAGE

[build/evidence/pc-i08-linux-maintenance-2026-11-04/package-audit.json](../build/evidence/pc-i08-linux-maintenance-2026-11-04/package-audit.json) · current_audit.

Archivo e626c350…: extracción, SHA-256, tamaño y modo de 282 archivos, cuatro entradas nativas y manifiestos verificados. Sin .bit ni release.json; fuente 2c0ae71 limpia.

### Evidencia LICENSES

[build/evidence/pc-i08-acceptance-2026-11-04/licenses-current/audit.json](../build/evidence/pc-i08-acceptance-2026-11-04/licenses-current/audit.json) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. 68 entradas conservadoras: 12 con archivos de avisos incluidos, 54 sin coincidencia exacta de archivos independientes y 2 sin archivo de aviso completo localizado. La búsqueda por SHA-256 no prueba ausencia dentro de HTML concatenado, ASAR o bundles; se recopilaron textos disponibles y quedan tres ámbitos de revisión abiertos.

### Evidencia LOCK

[build/evidence/pc-i08-acceptance-2026-11-04/npm-lock-mismatch.json](../build/evidence/pc-i08-acceptance-2026-11-04/npm-lock-mismatch.json) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. La URL, el SHA-512 del tarball de caché y su package.json confirman @base-ui/utils 0.5.0. Se corrigió el dato 0.6.0 del lock y se archivó su caché de metadatos anterior; no se reemplazó código de node_modules.

### Evidencia NPM_TREE

[build/evidence/pc-i08-acceptance-2026-11-04/npm-production-tree.json](../build/evidence/pc-i08-acceptance-2026-11-04/npm-production-tree.json) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. npm ls --omit=dev --all --json terminó con código 0 después de corregir el lock y retirar su caché de metadatos inconsistente.

### Evidencia EDUCATION

[verification/EXAMPLES-FORMAT-2026-11-03.md](../verification/EXAMPLES-FORMAT-2026-11-03.md) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. 59 fuentes normalizadas con bytes, PC–línea, comentarios y referencias de guía conservados; 409 ciclos de guías sin alterar. No acredita los resultados en FPGA ni revisión pedagógica del grupo.

### Evidencia PERFORMANCE

[verification/PC-I07.md](../verification/PC-I07.md) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. Muestras históricas de latencia, cuadros, cámara y video, incluidas incidencias. No se extrapolan al código visual posterior, al userland Xvfb ni a equipos modestos.

### Evidencia VISUAL

[verification/DEBUG-VISUAL-REVIEW-2026-11-03-R11.md](../verification/DEBUG-VISUAL-REVIEW-2026-11-03-R11.md) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. Última ronda documentada de notificaciones y estados vacíos, junto con las revisiones anteriores enlazadas por el índice. No sustituye la evaluación humana de aceptación.

### Evidencia SOURCE

[build/evidence/pc-i08-acceptance-2026-11-04/source-review.json](../build/evidence/pc-i08-acceptance-2026-11-04/source-review.json) · prior_evidence.

Revisión histórica de fuentes y de pendientes del paquete anterior. El faltante Linux allí descrito queda reemplazado por MAINTENANCE, INSTALL_UNIT, INSTALL_ARCH e INSTALL_NO_DOWNLOAD; conserva valor histórico para el resto del alcance anterior.

### Evidencia ENV

[build/evidence/pc-i08-acceptance-2026-11-04/environment.json](../build/evidence/pc-i08-acceptance-2026-11-04/environment.json) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. Host Ultra 9 185H, 22 CPUs lógicas; datos de RAM/disco, userland Ubuntu, Xvfb y archivo probado. Este equipo no se presenta como equipo estudiantil modesto.

### Evidencia UBUNTU_PACKAGES

[build/evidence/pc-i08-acceptance-2026-11-04/ubuntu-packages.tsv](../build/evidence/pc-i08-acceptance-2026-11-04/ubuntu-packages.tsv) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. Bibliotecas Ubuntu del snapshot firmado 20261018T000000Z. dpkg --configure -a finalizó y dpkg --audit no informó paquetes pendientes; preparación aislada, sin instalar paquetes del host.

### Evidencia SSE_SERVER

[build/evidence/pc-i08-acceptance-2026-11-04/sse-backpressure.log](../build/evidence/pc-i08-acceptance-2026-11-04/sse-backpressure.log) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. 1 ensayo del endpoint HTTP/ASGI real: el send del canal se bloquea, su cola se satura, solo ese canal se cierra y la nueva suscripción entrega estado completo. No es un bloqueo del pintado del navegador.

### Evidencia SSE_CLIENT

[build/gui-check/2026-11-04T14-15-16-987Z/stream-lifecycle-smoke.log](../build/gui-check/2026-11-04T14-15-16-987Z/stream-lifecycle-smoke.log) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. Nuevo recorrido GUI: comentarios SSE reales de 15 s, watchdog de 45 s con reloj del renderer controlado/pausado, reconexión con estado completo y mismas identidades, sin UART/RESET y cierre durante reintento. El core conserva reloj real; no se simula CPU.

### Evidencia MATRIX_CHECKS

[build/evidence/pc-i08-acceptance-2026-11-04/matrix-negative-checks.json](../build/evidence/pc-i08-acceptance-2026-11-04/matrix-negative-checks.json) · prior_evidence.

Evidencia de la revisión anterior, conservada con su alcance original. 8 controles negativos del verificador: IDs faltantes/repetidos, trazabilidad cambiada, pase con pendientes, variante ausente, evidencia alterada/fuera del workspace y cierre automático de la aceptación son rechazados.

### Evidencia MAINTENANCE

[verification/PC-I08-LINUX-MAINTENANCE-2026-11-04.md](../verification/PC-I08-LINUX-MAINTENANCE-2026-11-04.md) · current_review.

Implementación, paquete, bloqueo por kernel/core/ejecutable real, transacciones reversibles, preservación y límites del mantenimiento por usuario Linux.

### Evidencia INSTALL_UNIT

[build/evidence/pc-i08-linux-maintenance-2026-11-04/unit.log](../build/evidence/pc-i08-linux-maintenance-2026-11-04/unit.log) · current_run.

13 pruebas aprobadas de inventarios y preservación, accesos ajenos, procesos y bloqueos reales, arranques durante mantenimiento, señales, restauración y respaldo si esta falla.

### Evidencia INSTALL_ARCH

[build/evidence/pc-i08-linux-maintenance-2026-11-04/arch-installation.log](../build/evidence/pc-i08-linux-maintenance-2026-11-04/arch-installation.log) · current_run.

Paquete extraído: instalación/reinstalación, CLI/core, rechazo ocupado, arranques públicos bajo exclusión, conservación de datos y desinstalación desde runtime congelado propio en HOME temporal.

### Evidencia INSTALL_NO_DOWNLOAD

[build/evidence/pc-i08-linux-maintenance-2026-11-04/without-download.log](../build/evidence/pc-i08-linux-maintenance-2026-11-04/without-download.log) · current_run.

Instalación desde una copia privada, borrado de esa descarga y posterior uso de CLI/core y scripts instalados; mismos rechazos y preservación aprobados.

### Evidencia ENV_CURRENT

[build/evidence/pc-i08-linux-maintenance-2026-11-04/environment.json](../build/evidence/pc-i08-linux-maintenance-2026-11-04/environment.json) · environment.

Host Arch; Ubuntu 24.04.5 userland con Xvfb privado, imagen y snapshot fijados, red aislada, perfiles descartables. No acredita escritorio/USB físicos.

## Repetición y límites

Desde tp3: `software/.venv/bin/python software/packaging/acceptance_matrix.py software/verification/PC-I08-ACCEPTANCE-2026-11-04.json --verify-evidence --render`. Las fuentes de la matriz contienen el hash de la especificación usada; un cambio normativo exige una nueva evaluación. La preparación/repetición de Ubuntu y del inventario de avisos se detalla en [el informe del entorno](PC-I08-ENVIRONMENTS-LICENSES-2026-11-04.md). Los errores iniciales de preparación y del fixture CLI se conservaron como diagnóstico y no se contabilizan como pases.

Las huellas de especificaciones, logs y archivo están en el JSON. El verificador comprueba IDs completos, vínculos normativos, referencias y coherencia de estados; `--verify-evidence` comprueba además los bytes. No ejecuta pruebas ni convierte su lectura en un pase.
