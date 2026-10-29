# Verificación de viewrv

- **Tipo:** verificación y aceptación.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Alcance y oráculos](#alcance-y-oráculos)
- [Ejecución de pruebas automatizadas](#ejecución-de-pruebas-automatizadas)
- [Entornos y datos que deben registrarse](#entornos-y-datos-que-deben-registrarse)
- [Casos de aceptación](#casos-de-aceptación)
- [Variantes técnicas obligatorias](#variantes-técnicas-obligatorias)
- [Vectores concretos de referencia](#vectores-concretos-de-referencia)
- [Vectores compartidos con la verificación del sistema](#vectores-compartidos-con-la-verificación-del-sistema)
- [Medición y revisión visual](#medición-y-revisión-visual)
- [Cobertura de los requisitos](#cobertura-de-los-requisitos)
- [Condición de aceptación y entrega](#condición-de-aceptación-y-entrega)

## Propósito y alcance

Define entradas, expectativas, niveles, entornos y evidencia para comprobar la aplicación y su integración con FPGA. Incluye 30 casos de aceptación y cobertura de los 74 requisitos específicos de la SRS. La especificación de las pruebas no acredita su ejecución.

## Alcance y oráculos

El objetivo es comprobar el producto definido y su fidelidad al procesador del TP. Se distinguen pruebas sin placa, integración empaquetada y aceptación física y visual. Las especificaciones de [integración](integracion_y_distribucion.md), [visor](gui_y_visor.md) y [diseño lógico](arquitectura.md) son entradas; no son evidencia de resultados obtenidos.

| Nivel | Método y oráculo independiente |
|-------|--------------------------------|
| Lógica del core | Adaptadores controlados de procesador, programador y archivos. Entradas y expectativas literales derivadas de contratos y trazas revisadas; no generar la expectativa con la función probada. |
| Protocolo | Secuencias de bytes, fases, tamaños y límites de [protocol.md](../../protocol.md). Comparar frames completos, parciales, rechazados y tardíos con fixtures independientes. |
| Assembler | Reutilizar el [catálogo definido](../assembler_tests.md) y sus bytes y mapas esperados; no derivarlos con el decoder del visor. |
| Interpretación | Capturas y transiciones construidas y revisadas aparte de las tablas de implementación, basadas en las etapas y [hazards](../../architecture/cpu/control_and_hazards.md). Contrastar también trazas de RTL o placa cuando estén disponibles. |
| Cliente y API | Verificar solicitud, contexto, resultado, salida y orden de eventos observando la frontera; rechazo sin UART y ninguna repetición automática incierta. |
| GUI y contenido | Acciones reales, observación del resultado, comparación con Penpot y revisión del grupo. No aprobar apariencia mediante igualdad de objetos de estado. |
| Entrega y FPGA | Artefactos reales en los sistemas de aceptación, sin entornos de desarrollo instalados; evidencia del programador y UART de la misma placa. |

Las pruebas automatizadas de Python utilizan unittest, incluido en la biblioteca estándar, con la organización y los comandos siguientes. Las comprobaciones visuales utilizan los mecanismos de observación disponibles en Electron y el sistema. Los casos acompañan las [entregas de implementación](../../implementation_plan.md#entregas-de-viewrv), que pueden avanzar en paralelo conforme a sus dependencias.

## Ejecución de pruebas automatizadas

### Ubicación y entorno

Las pruebas de viewrv se ubican bajo tp3/software/tests/viewrv, separadas de las pruebas del assembler. El directorio contiene un archivo __init__.py vacío y los cinco módulos de la tabla de comandos. Los paquetes software y software.tests conservan sus marcadores de importación definidos para el software del TP; los nombres completos de los módulos de prueba comienzan con software.tests.viewrv.

Los comandos se ejecutan desde la carpeta tp3, con el CPython y las dependencias de desarrollo de la aplicación definidos en [Integración y distribución](integracion_y_distribucion.md#dependencias-y-versiones). python3 identifica ese intérprete en Linux. En Windows se utiliza python cuando ese es el nombre del mismo intérprete configurado; el resto de argumentos se conserva. La versión efectiva se registra en la evidencia. Esta preparación pertenece al entorno de desarrollo; la persona que utiliza el producto distribuido no necesita instalar Python.

### Comandos

| Comando desde tp3 | Alcance |
|------------------|---------|
| `python3 -m unittest discover -s software/tests/viewrv -t . -v` | Ejecutar todas las pruebas automatizadas de Python de viewrv, sin placa. No incluye el catálogo independiente del assembler. |
| `python3 -m unittest -v software.tests.viewrv.test_core` | Programas, revisiones, admisión, sesiones, breakpoints y control exclusivo, mediante adaptadores controlados. |
| `python3 -m unittest -v software.tests.viewrv.test_protocol` | Codificación y decodificación UART, capturas, perfiles, fragmentación, plazos y recuperación con transporte y reloj controlados. |
| `python3 -m unittest -v software.tests.viewrv.test_api_cli` | Contrato HTTP/SSE y comportamiento del cliente CLI: argumentos, respuestas, observación, formatos y códigos de terminación. |
| `python3 -m unittest -v software.tests.viewrv.test_storage` | Archivos de código, autoguardado, recuperación, preferencias, evidencia JSONL y tratamiento de fallos de almacenamiento. |
| `python3 -m unittest -v software.tests.viewrv.test_interpretation` | Correspondencia de instrucciones, diferencias, participación funcional y seguimiento de una aparición con capturas y expectativas independientes. |

La opción -v muestra las pruebas individualmente. En el comando completo, -s selecciona el directorio de pruebas y -t fija tp3 como raíz de importación. Los comandos por módulo permiten investigar un área; cerrar una entrega requiere además las comprobaciones de los otros ámbitos afectados.

### Relación con el catálogo

Los módulos organizan el código de prueba; no crean otros identificadores de aceptación. Cada prueba identifica en su nombre o descripción visible el ID TEST-PC-NNN al que contribuye y la variante cuando corresponda. Un mismo caso puede requerir comprobaciones en varios módulos y niveles.

| Módulo | Casos del catálogo relacionados |
|--------|--------------------------------|
| test_core | [TEST-PC-002](#test-pc-002) a [TEST-PC-009](#test-pc-009), [TEST-PC-015](#test-pc-015) a [TEST-PC-017](#test-pc-017), [TEST-PC-021](#test-pc-021), [TEST-PC-023](#test-pc-023) a [TEST-PC-026](#test-pc-026), [TEST-PC-029](#test-pc-029) y [TEST-PC-030](#test-pc-030). |
| test_protocol | [TEST-PC-003](#test-pc-003), [TEST-PC-004](#test-pc-004), [TEST-PC-006](#test-pc-006), [TEST-PC-007](#test-pc-007), [TEST-PC-016](#test-pc-016), [TEST-PC-023](#test-pc-023), [TEST-PC-024](#test-pc-024) y [TEST-PC-025](#test-pc-025). |
| test_api_cli | [TEST-PC-003](#test-pc-003), [TEST-PC-005](#test-pc-005), [TEST-PC-007](#test-pc-007), [TEST-PC-008](#test-pc-008), [TEST-PC-013](#test-pc-013), [TEST-PC-015](#test-pc-015) a [TEST-PC-017](#test-pc-017), [TEST-PC-023](#test-pc-023) a [TEST-PC-026](#test-pc-026), [TEST-PC-029](#test-pc-029) y [TEST-PC-030](#test-pc-030). |
| test_storage | [TEST-PC-002](#test-pc-002), [TEST-PC-009](#test-pc-009), [TEST-PC-010](#test-pc-010), [TEST-PC-017](#test-pc-017), [TEST-PC-020](#test-pc-020), [TEST-PC-021](#test-pc-021), [TEST-PC-022](#test-pc-022), [TEST-PC-026](#test-pc-026) y la conservación de configuración de [TEST-PC-012](#test-pc-012). |
| test_interpretation | [TEST-PC-004](#test-pc-004), [TEST-PC-018](#test-pc-018) y las correspondencias del catálogo educativo de [TEST-PC-019](#test-pc-019). |

La relación indica la contribución automatizada de cada módulo. Las entradas, expectativas y variantes siguen definidas por cada caso y por la matriz de requisitos. Una comprobación de API no acredita la interacción real con la ventana Electron, y una prueba de archivos con un proceso interrumpido no acredita durabilidad frente a un corte eléctrico.

### Resultado y límites de la ejecución

Una ejecución satisfactoria de unittest termina con código 0; un fallo o error devuelve un código distinto de cero. La evidencia conserva comando, intérprete, entorno, revisión de fuentes, IDs y resultados. Una ejecución que no descubre pruebas no acredita verificación, y un caso sin la evidencia de todos sus niveles y variantes no se presenta como completo.

La revisión visual, la interacción con GUI, la instalación y desinstalación de paquetes y las pruebas sobre la placa siguen sus procedimientos y niveles de este documento. Los comandos anteriores no las ejecutan ni las declaran aprobadas. Los paquetes se prueban en los sistemas de aceptación y la integración con assembler y FPGA reales se comprueba en el flujo conjunto.

Estos comandos especifican la ejecución futura. Los módulos de pruebas se implementan junto con la aplicación; su enumeración no declara archivos creados ni pruebas ejecutadas.

## Entornos y datos que deben registrarse

La base de construcción Linux es Ubuntu 24.04 x86_64. Los destinos de aceptación son Arch Linux, Ubuntu y Windows, con Windows 11 como referencia. Las versiones y configuraciones efectivas deben registrarse al ejecutar las pruebas. La compatibilidad se declara para la matriz efectivamente comprobada.

La revisión visual comienza con 1366x768 y 1920x1080 como condiciones de diseño representativas, con zoom de sistema y de aplicación identificados y con editor en split. Deben contrastarse con los equipos reales; estas resoluciones no se atribuyen como inventario aportado por el grupo. Se utiliza al menos el equipo más limitado disponible para aceptación y se registran sus recursos.

| Dato del registro de prueba | Contenido requerido |
|----------------------------|---------------------|
| case_id y result | Caso, variantes, pass, fail o blocked y motivo. |
| release_id | Versión y huella del artefacto probado. |
| environment | Sistema, versión, kernel cuando corresponda, arquitectura, CPU, RAM y almacenamiento. |
| display | Resolución, escala del sistema y escala de aplicación. |
| hardware | Modelo y referencia de placa, identificación de JTAG y UART y condiciones de permisos o controlador. |
| bitstream | Revisión y SHA-256 del recurso realmente programado. |
| input | Fuente y revisión, pasos, opciones y estado de partida. |
| expected y observed | Expectativa previa y resultado obtenido, sin sustituir una por la otra. |
| evidence | Archivo o referencia de logs, capturas, trazas y mediciones pertinentes. |
| reviewer | Responsable de ejecución o revisión y fecha. |

Un doble serial permite verificar software sin placa, pero no acredita la implementación FPGA. Un corte de proceso permite estudiar recuperación de archivos, pero no acredita durabilidad ante corte eléctrico: esa garantía requiere el ensayo físico y el soporte de almacenamiento identificado.

## Casos de aceptación

Cada caso utiliza un ID TEST-PC-NNN y conserva su relación con el escenario SRS-PC-Axx de la SRS, como muestra la tabla. Los IDs identifican pruebas; los escenarios mantienen sus propios identificadores. Las variantes enumeradas son parte del caso y se conservan en su evidencia.

| Caso y escenario | Objetivo | Entrada y contexto | Resultado esperado | Nivel |
|------------------|----------|--------------------|--------------------|-------|
| <a id="test-pc-001"></a> TEST-PC-001 / SRS-PC-A01 | Exploración sin placa | Instalación local sin FPGA; recorrer cinco etapas, módulos y una instrucción. | Explicaciones y conexiones disponibles; navegación sin UART ni datos iniciales inventados. | Manual GUI; recursos |
| <a id="test-pc-002"></a> TEST-PC-002 / SRS-PC-A02 | Programas y edición | Crear dos borradores, copiar ejemplo, dividir vistas y usar teclado; ensamblar un caso correcto y otro inválido. | Un modelo por programa; ejemplos originales intactos; edición y completado acotado; resultado o diagnóstico con versión y mapa correctos. | Core aislado; GUI |
| <a id="test-pc-003"></a> TEST-PC-003 / SRS-PC-A03 | LOAD y RUN | Imagen de ADDI x1,x0,5 y HALT, con ocho bytes conocidos; repetir en GUI y CLI. | Solo DONE vincula imagen; RUN terminal coherente, x1=5 y contexto de fuente exacto en ambas interfaces. | Adaptador controlado; FPGA |
| <a id="test-pc-004"></a> TEST-PC-004 / SRS-PC-A04 | Solapamiento y dependencias | Programas independientes y dependencias de la tabla educativa; avanzar por STEP y Continuar. | Una captura completa por ciclo; RF, latches, memoria y mapa corresponden al mismo paso. El resaltado usa la referencia temporal correcta. | Core; FPGA; GUI |
| <a id="test-pc-005"></a> TEST-PC-005 / SRS-PC-A05 | Breakpoints y controles | Dos coincidencias en una captura, instrucción retenida por load-use y cambios de breakpoints en pausa. | Una sola detención con todas las coincidencias; nueva captura evalúa otra aparición; no hay cola de STEP; reinicio crea sesión nueva solo tras LOAD confirmado. | Core aislado; integración |
| <a id="test-pc-006"></a> TEST-PC-006 / SRS-PC-A06 | Terminal y drain | HALT y fault con una instrucción anterior que todavía debe escribir. | Se conservan commits anteriores; pasos de drain hasta FINISHED o FAULT; captura terminal inspeccionable y avance posterior rechazado. | Traza independiente; FPGA |
| <a id="test-pc-007"></a> TEST-PC-007 / SRS-PC-A07 | Espera y comunicación interrumpida | Demorar una respuesta completa y luego truncar otra; navegar y reabrir vistas mientras tanto. | La interfaz responde; no se publica el parcial; última captura completa se conserva como anterior y se informa incertidumbre. | Serial controlado; GUI |
| <a id="test-pc-008"></a> TEST-PC-008 / SRS-PC-A08 | Investigación por CLI y reproducción | Ejecutar y depurar un programa por CLI, obtener evidencia y repetirlo en GUI. | Misma revisión y condiciones documentadas; resultados comparables, fuente y evidencia identificadas sin requerir GUI para usar CLI. | Integración; paquete; FPGA |
| <a id="test-pc-009"></a> TEST-PC-009 / SRS-PC-A09 | Registro predeterminado | Ensayo RUN y debug, autor explícito y ausente, con registro por defecto; compartir los archivos. | start, observaciones y end válidos; texto exacto y autor; interrupciones identificadas; lectura independiente y retención sin limpieza automática. | Archivos; integración |
| <a id="test-pc-010"></a> TEST-PC-010 / SRS-PC-A10 | Borradores y caída | Borrador cerrado y otro abierto; cierre normal y caída con ediciones temporizadas. | Recuperación del texto confirmado y aperturas correspondientes; sin restaurar paneles ni CPU; pérdida de edición no mayor a dos segundos bajo las condiciones de aceptación. | Archivos; proceso; corte físico |
| <a id="test-pc-011"></a> TEST-PC-011 / SRS-PC-A11 | Uso autónomo y demostración | Persona del público previsto sin explicación personal recorre explorar, ejemplo, ensamblado, carga y debug; grupo demuestra al docente. | Registrar bloqueos y ayuda necesaria; no exigir manual ni repetir tour; el grupo comprueba exactitud de explicaciones y claridad del funcionamiento mostrado. | Evaluación humana; FPGA |
| <a id="test-pc-012"></a> TEST-PC-012 / SRS-PC-A12 | Entornos, red y presentación | Mismo artefacto Linux en Arch y Ubuntu; paquete Windows; resoluciones y zoom representativos; red externa deshabilitada. | Funciones equivalentes, español y tema coherente; recursos locales accesibles; ausencia de telemetría; zoom general y legibilidad en split. | Paquetes; GUI; red; revisión visual |
| <a id="test-pc-013"></a> TEST-PC-013 / SRS-PC-A13 | Personas y automatizaciones | Recorrer las 25 operaciones CLI con formato humano y JSON, incluidos errores y coincidencias múltiples; comprobar además ayuda y versión con y sin --output json. | Salida y códigos de proceso coherentes; sin prompts interactivos imprevistos; 0 para resultados válidos, 1 para fallos, 2 para uso y 130 para Ctrl+C. Ayuda y versión válidas siempre producen texto, terminan con 0 y no inician el core. | CLI; HTTP controlado; paquete |
| <a id="test-pc-014"></a> TEST-PC-014 / SRS-PC-A14 | Preparación desde el producto | Equipo sin Vivado, bitstream identificado y Basys 3; comprobar permisos, programación y UART. | Programador incluido; fases separadas y misma placa seleccionada; guía explícita para permisos o controladores; preservar UART; no aceptar sin evidencia física. | Paquetes; FPGA; sistemas reales |
| <a id="test-pc-015"></a> TEST-PC-015 / SRS-PC-A15 | Automatización no atendida | Argumentos válidos, puerto ambiguo o ausente, fallo de arranque y respuesta perdida después del envío. | Error explícito y formato estable; sin elegir primer candidato, esperar entrada humana ni repetir una operación con efectos inciertos. | CLI; procesos; dobles |
| <a id="test-pc-016"></a> TEST-PC-016 / SRS-PC-A16 | RUN con y sin límite | Programa terminado antes del límite y bucle que lo alcanza; repetir sin límite y con respuesta terminal ya iniciada. | El presupuesto empieza con ACCEPTED completo y termina al iniciar terminal; sin límite implícito; RESET confirmado distinto de resultado físico no confirmado. | Serial controlado; FPGA |
| <a id="test-pc-017"></a> TEST-PC-017 / SRS-PC-A17 | Versiones y foco | Ensamblar A, editar a B antes de LOAD y durante LOAD ya iniciado; cambiar el tab activo. Probar referencias correctas, parciales, ausentes y distintas de la imagen en RUN e inicio de debug. | Rechazo de traducción desactualizada antes de LOAD; carga iniciada de A sigue usando A y atajo puede ejecutar A, con diferencia visible respecto de B. GUI envía programa y revisión: omisión o par incompleto recibe INVALID_ARGUMENT; discrepancia con la imagen recibe SOURCE_VERSION_MISMATCH y no genera UART ni abre debug. CLI puede omitir el par y utiliza la imagen confirmada al admitir la operación. | Core; GUI; integración |
| <a id="test-pc-018"></a> TEST-PC-018 / SRS-PC-A18 | Correspondencia y seguimiento | Bucle, load-use, redirect, fault y pérdida de captura; seleccionar una aparición válida y otra anterior. | Observación fija predeterminada; no fusionar PCs repetidos; seguir solo transiciones justificadas, terminar ante gap o ambigüedad y conservar encuadre sin pausar Continuar. | Fixtures independientes; GUI; FPGA |
| <a id="test-pc-019"></a> TEST-PC-019 / SRS-PC-A19 | Cobertura educativa | Revisar las 33 instrucciones, sus 165 entradas de etapa y los programas de interacciones y casos de borde. | Todos los mnemónicos presentes; programas completos y resultados contrastados; explicar correctamente supuestos y distinguir inferencia de bits recibidos. | Revisión del grupo; assembler; FPGA |
| <a id="test-pc-020"></a> TEST-PC-020 / SRS-PC-A20 | Archivo asociado movido o eliminado | Conservar un programa, cerrar y mover su archivo fuera de la aplicación; recuperar y guardar con otro destino. | Conservar texto recuperable; informar asociación ausente; no recrear silenciosamente el archivo anterior. | Archivos; GUI |
| <a id="test-pc-021"></a> TEST-PC-021 / SRS-PC-A21 | Fallo de escritura de evidencia | Fallar escritura después de observaciones conservadas mientras continúa la sesión. | Registro failed; sin más escrituras a ese ensayo; conservar evidencia anterior, última observación y autoguardado de código; nuevos ensayos conservan su preferencia. | Storage controlado; integración |
| <a id="test-pc-022"></a> TEST-PC-022 / SRS-PC-A22 | Corte durante registro | Interrumpir después de una observación y durante otra línea; probar también una línea inválida intermedia. | Recuperar unidades válidas sin inventar las perdidas; mismo session_id y pasos originales; cierre ausente o cantidad discrepante indica incompleto. | Archivos; proceso; corte físico |
| <a id="test-pc-023"></a> TEST-PC-023 / SRS-PC-A23 | Desconexión durante RUN | Terminal completo, RESET confirmado y RESET sin confirmar en pruebas separadas. | Terminal iniciado conserva su resultado; RESET solo confirmado cuando hay ACK; cerrar enlace y sesión lógica conservando el conocimiento real. | Serial controlado; FPGA |
| <a id="test-pc-024"></a> TEST-PC-024 / SRS-PC-A24 | Desconexión durante LOAD y STEP | Solicitar desconexión en fases antes y después de ACCEPTED, durante STEP y entre pasos de Continuar. | Resolver el intercambio en curso según sus plazos y cerrar; ningún STEP siguiente; no reanudar el ensayo al reconectar; recuperación respeta la fase. | Serial controlado; FPGA |
| <a id="test-pc-025"></a> TEST-PC-025 / SRS-PC-A25 | Puerto y selección | Recordar un puerto confirmado y retirarlo con otro presente; proporcionar puerto explícito y varios dispositivos. | Prioridad explícita y luego recordada; ausencia y ambigüedad se informan; no sustituir el puerto recordado automáticamente. | Plataforma; dobles; FPGA |
| <a id="test-pc-026"></a> TEST-PC-026 / SRS-PC-A26 | Salida con código pendiente | Cerrar con guardado exitoso, fallo, nuevo destino y descarte explícito; mantener trabajo CLI ajeno. | Resolver conservación antes de cerrar; fallo mantiene GUI; descarte requiere acción explícita; conservar core si otro trabajo lo usa. | Storage controlado; GUI; procesos |
| <a id="test-pc-027"></a> TEST-PC-027 / SRS-PC-A27 | Respuesta visible | Escribir, cambiar tab y seleccionar módulo en equipos representativos durante esperas de FPGA. | Acciones habituales responden visiblemente en menos de 100 ms; no se espera que UART termine para responder; conservar todas las muestras y sus incidencias. | Instrumentación de GUI; equipo real |
| <a id="test-pc-028"></a> TEST-PC-028 / SRS-PC-A28 | Movimiento del diagrama | Diagrama completo, desplazamientos, zoom y animaciones con editor en split. | Objetivo de 60 cuadros/s y movimiento regular; conservar trazas de tiempos y congelamientos, sin aprobar por promedio que oculte tirones. | Instrumentación de GUI; revisión visual |
| <a id="test-pc-029"></a> TEST-PC-029 / SRS-PC-A29 | CLI controla, GUI observa | Iniciar debug por CLI y abrir, reconectar, saturar y cerrar la observación GUI durante la prueba. | Misma captura y fuente; GUI sin control ajeno; saturación solo cierra ese canal; continuidad física y del trabajo CLI. | HTTP/SSE; paquete; FPGA |
| <a id="test-pc-030"></a> TEST-PC-030 / SRS-PC-A30 | GUI controla, CLI observa | Avanzar varios pasos en GUI y consultar todos o after N desde varias invocaciones CLI. | Consultas finitas sin consumo por observador ni STEP implícito; índices originales y avisos de registros pendientes, desactivados o incompletos. | Integración; evidencia; FPGA |

## Variantes técnicas obligatorias

| Grupo | Variantes y expectativas |
|-------|-------------------------|
| Versiones | Edición durante ensamblado, antes de LOAD y después de LOAD iniciado; respuesta vieja no reemplaza texto posterior. Contrastar RUN individual y el RUN del atajo combinado con el programa y revisión que solicitan. Solapar una actualización de texto pendiente con ensamblar, guardar y cerrar: ninguna recepción tardía hace retroceder el texto ni vuelve a abrir un documento cerrado. |
| Texto antes de acciones | Demorar la confirmación de program/update y comprobar que ensamblar, cargar, guardar y cerrar esperan la recepción de su revisión elegida. Con B recibido y una acción sobre B en curso, editar y confirmar C: el resultado de B conserva su contexto y el texto sigue en C. La espera de recepción no exige guardado en disco ni suspende el autoguardado. Si la recepción falla, no se envía la acción dependiente. El cierre resuelve la revisión final sin actualizaciones posteriores de ese documento. |
| Selección | Sin puerto explícito ni recordado: un candidato inequívoco permite resolver; cero o varios producen PORT_SELECTION_REQUIRED. Un puerto recordado ausente no se sustituye aunque quede otro único. |
| Propiedad | Dos invocaciones CLI y GUI observadora; único controlador, trabajo CLI persistente, cierre de observador sin finalizar trabajo ajeno. |
| Arranque | Clientes simultáneos, archivo residual, bloqueo ocupado, identidad distinta y versión de contrato o perfil incompatible; no iniciar segundo servidor competidor. |
| HTTP | Los estados y error.code corresponden al motivo; FAULT completo es result; credencial, Host, Origin y preflight aplican el contrato. CLI sin Origin funciona. |
| SSE | state inicial sin hueco, cambios durante envío, bloques omitidos y vacíos, salto de revisión, mensaje antiguo e instancia distinta; no mezclar con respuesta HTTP atrasada. |
| Saturación | Frenar el envío del servidor hasta llenar pendientes; no basta bloquear el pintado mientras Electron recibe. Solo se cierra ese canal y la nueva suscripción entrega estado completo. |
| Keepalive | Comentarios sin datos JSON mantienen actividad; 45 segundos sin recepción activa el procedimiento, no un RESET; reintentos con esperas y cierre cancela pendientes. |
| Preferencias | Ausencia, JSON inválido, versión desconocida, permisos insuficientes y fallo de reemplazo; valores iniciales con aviso y original conservado; guardado fallido no publica otra configuración. |
| Evidencia | start válido, cero observaciones legítimo, líneas de otro ensayo o versión, JSON final parcial, línea intermedia inválida, índice saltado, cierre contradictorio, cantidad discrepante y fallo conocido. |
| Interpretación | Primera captura, contador con wrap, validez independiente, x0, forwarding joven, load-use, redirect, halt y drain. Captura contradictoria conserva valores y limita inferencia. |
| Seguimiento | Dos ubicaciones con igual PC e instrucción; retención no equivale a otra aparición, salida de MEM/WB no se reasigna al nuevo ocupante y gap termina continuidad. |
| Recursos | Invocar desde otro directorio, rutas con espacios, falta de bitstream o dependencia y huella incorrecta; no tomar otro ejecutable de PATH. |
| Mantenimiento | Instalación repetida, producto en uso, lanzamiento concurrente y desinstalación; no matar trabajos, no sustituir recursos activos ni borrar datos de usuario. |
| Preparación | Programación exitosa seguida de UART fallido, programador que no termina, salida de error y selector ambiguo; preservar fase y confirmaciones reales. |

Los valores iniciales de 32 pendientes, latidos y reintentos y presupuestos de arranque y programador se ajustan con estas observaciones. Un ajuste de parámetro no altera silenciosamente el contrato UART, el límite opcional de RUN ni un requisito de pérdida o respuesta.

## Vectores concretos de referencia

El programa ADDI x1,x0,5 seguido por HALT utiliza los bytes 93 00 50 00 0B 00 00 00. Debe distinguirse el tamaño binario de ocho bytes del texto. Los casos de error conservan un solo diagnóstico y ninguna traducción parcial. Esta expectativa procede del catálogo del assembler, no de una ejecución hecha en esta etapa.

Para los programas educativos se comprueban los resultados numéricos y bytes de memoria de la [tabla de ejemplos](gui_y_visor.md#banco-educativo-y-ejemplos-ejecutables), incluidos extensión con signo, link de JAL/JALR y camino descartado. Cada instrucción tiene al menos un programa ejecutable; los ejemplos de dependencias y faults añaden variantes y no sustituyen esa cobertura.

Para la interpretación temporal se preparan al menos: avance normal con cuatro entradas válidas distintas; consumidor retenido por load-use; productor más reciente EX/MEM frente a MEM/WB del mismo rd; escritura a x0; redirect con instrucción posterior descartada; store anterior que completa al confirmar fault posterior; drain legal sin ID/EX válido y wrap de cycle_count. Se guardan las capturas literales y la expectativa antes de implementar el evaluador.

## Vectores compartidos con la verificación del sistema

Los bytes, campos y expectativas siguientes se toman de los contratos y del catálogo de hardware. Se utilizan como entradas literales al probar PC; no se generan mediante el encoder o decoder que se está comprobando. Su reutilización no convierte un fixture artificial en una ejecución legal en placa.

| Caso PC | Entrada concreta | Expectativa independiente |
|---------|------------------|----------------------------|
| [TEST-PC-003](#test-pc-003) | LOAD de ocho bytes: cabecera 01 08 00 00 00 00; aceptación 01 01; imagen 93 00 50 00 0B 00 00 00; cierre 01 02. | No enviar imagen antes de aceptación; byte_count=8 y vínculo a fuente solo confirmado al recibir DONE. |
| [TEST-PC-003](#test-pc-003), [TEST-PC-015](#test-pc-015) | Tamaño 2^32: cabecera 01 00 00 00 00 01 frente a REFERENCE y ALT_1000. Respuesta 01 06. | El campo se representa en cinco bytes y no se trunca a cero. LOAD_REJECTED, sin contenido enviado ni invalidación atribuida a un rechazo anterior a ACCEPTED. |
| [TEST-PC-004](#test-pc-004), [TEST-PC-013](#test-pc-013) | response_bytes de TEST-UART-007/C001, divididos en cada frontera de campo y también byte por byte. | Snapshot idéntico: PC=305419896, cycle_count="72623859790382856", fault_pc=287454020, 32 RF y todos los campos de latches. No publicar observaciones de sus prefijos. Es fixture de serialización, no programa legal. |
| [TEST-PC-004](#test-pc-004), [TEST-PC-009](#test-pc-009) | Estado de memoria antes del reinicio de TEST-UART-008/C001: entradas (0,52), (1,86), (3,0). | used_count=3; conservar el cero escrito y ausencia de dirección 2. Mismos datos en GUI, JSON y JSONL. |
| [TEST-PC-007](#test-pc-007), [TEST-PC-016](#test-pc-016) | Cabecera STEP, parte fija y lista entregadas antes del vencimiento respectivo y después de él, en ensayos separados. | Cabecera: 200 ms; parte fija de 228 bytes: 319 ms; lista K=2048: 5534 ms. La fragmentación no reinicia el plazo de la fase y no se aplica el límite de RUN al cuerpo Debug. |
| [TEST-PC-007](#test-pc-007), [TEST-PC-023](#test-pc-023) | Recuperación con bytes pendientes que llegan antes de cumplir W_debug. | Reiniciar silencio continuo: REFERENCE=6100 ms; ALT_1000=3400 ms. No buscar un par READY o ACCEPTED dentro de esos bytes. |
| [TEST-PC-014](#test-pc-014), [TEST-PC-015](#test-pc-015) | Cliente y core con memory_profile distintos; inventario o recurso incoherente con la construcción. | CORE_INCOMPATIBLE antes de registrar trabajo cuando difieren los perfiles. Una configuración de core inválida no publica disponibilidad; el cliente informa CORE_START_FAILED. No se consulta capacidad a UART. |

### Traza de retención, avance y fault de fetch

[TEST-PC-018](#test-pc-018) reutiliza el fixture TEST-PIPE-010/C001: palabras 00002083 y 00108133, imagen de ocho bytes y palabra DMEM inicial 7. La memoria inicial no nula se inyecta únicamente en el fixture de CPU o interpretación; para una prueba física se utiliza un programa que inicialice datos mediante stores. El modo STEP conserva las mismas acciones y datos por ciclo que la variante RUN del catálogo, cambiando la modalidad de los estados de drain.

La tabla es una proyección de capturas posteriores al flanco, no un nuevo formato de snapshot. Un número en un latch identifica su PC válido; vacío significa valid=false, sin exigir borrar los demás bits. El candidato de fetch se indica por separado.

| step_index y cycle_count | PC global | IF/ID | ID/EX | EX/MEM | MEM/WB | Hecho esperado |
|--------------------------|-----------|-------|-------|--------|--------|----------------|
| 1 | 4 | 0 | vacío | vacío | vacío | Ingresó lw. |
| 2 | 8 | 4 | 0 | vacío | vacío | Seleccionar add en IF/ID. Primer hit del breakpoint (PC=4, IF/ID). |
| 3 | 8 | 4 | vacío | 0 | vacío | load-use retiene la aparición seleccionada. Segundo hit, distinto por step_index, sin crear otra instrucción dinámica. |
| 4 | 12 | vacío | 4 | vacío | 0 | La aparición seleccionada avanza a ID/EX; IF/ID.fetch_fault_valid=true con pc=8 y causa instruction-access-fault=1. |
| 5 | 12 | vacío | vacío | 4 | vacío | Confirmar fault de fetch en ID; x1=7 y add anterior continúa con resultado 14. Estado FAULT_DRAIN_STEP. |
| 6 | 12 | vacío | vacío | vacío | 4 | Seguimiento en MEM/WB. x2 todavía no fue escrito por ese latch posterior. |
| 7 | 12 | vacío | vacío | vacío | vacío | x2=14, estado FAULT, fault_pc=8 y causa 1. Seguimiento finished por retired. |

Los valores de cycle_count se representan como cadenas decimales en JSON. changes de la primera captura contiene el aviso de comparación no disponible; las siguientes comparan únicamente capturas completas consecutivas. En el paso 4 no se anuncia todavía un fault confirmado solo por el candidato de IF/ID. En el paso 5 no se atribuye EX a los operandos de un ocupante posterior.

### Traza de bucle con igual PC

Se carga únicamente beq x0,x0,0, palabra 00000063, desde sesión nueva. A y B son etiquetas del oráculo para dos apariciones, no IDs añadidos al protocolo o a todas las instrucciones.

| Paso | PC global | IF/ID | ID/EX | EX/MEM | MEM/WB | Expectativa de seguimiento de A |
|------|-----------|-------|-------|--------|--------|---------------------------------|
| 1 | 4 | A en PC 0 | vacío | vacío | vacío | Selección inicial posible. |
| 2 | 8 | candidato fetch PC 4 | A en PC 0 | vacío | vacío | A avanzó a ID/EX. |
| 3 | 0 | vacío | vacío | A en PC 0 | vacío | Redirect descarta el candidato joven y no confirma fault. |
| 4 | 4 | B en PC 0 | vacío | vacío | A en PC 0 | A y B tienen el mismo PC e instruction; A está en MEM/WB. |
| 5 | 8 | candidato fetch PC 4 | B en PC 0 | vacío | vacío | A terminó por retired. No reasignar el seguimiento a B. |

Una consulta repetida sin STEP conserva FollowState. Omitir un paso intermedio devuelve unavailable/gap; no se reconstruye la identidad por igual PC. Los casos de wrap usan ciclo previo "18446744073709551615" y actual "0", con índices consecutivos y transición válida. Una variante con salto de contador se limita explícitamente; no se inventa una comparación fiable.

## Medición y revisión visual

La latencia de [TEST-PC-027](#test-pc-027) se mide desde la acción hasta la primera actualización visible correspondiente. Se registran muestras, máximos y distribución, en frío y uso repetido, con y sin espera serial. El criterio de las acciones habituales es menos de 100 ms. Un promedio menor no oculta muestras que incumplen; las incidencias se registran para corregir o revisar expresamente.

[TEST-PC-028](#test-pc-028) conserva tiempos por cuadro, cadencia, cuadros prolongados y grabación de los recorridos. El objetivo es 60 cuadros/s con movimiento regular; cycle_count no mide esa frecuencia. La evaluación incluye notebook y split y no se limita al promedio de FPS.

La fidelidad visual se contrasta con Penpot y con el visor existente: tipografía, paleta, espaciado, tooltips, énfasis, cámara y legibilidad. La ubicación definitiva de valores requiere validación visual con el diagrama y el editor; implementar la prueba no satisface por sí solo ese criterio.

## Cobertura de los requisitos

La matriz cubre los 74 requisitos identificados en la SRS, mediante los 30 escenarios y sus variantes técnicas. Es cobertura de diseño de prueba, no porcentaje de pruebas superadas.

| Requisito | Casos de aceptación |
|-----------|---------------------|
| SRS-PC-V01 | [TEST-PC-001](#test-pc-001), [TEST-PC-011](#test-pc-011), [TEST-PC-019](#test-pc-019) |
| SRS-PC-V02 | [TEST-PC-001](#test-pc-001), [TEST-PC-011](#test-pc-011), [TEST-PC-019](#test-pc-019) |
| SRS-PC-V03 | [TEST-PC-001](#test-pc-001), [TEST-PC-011](#test-pc-011), [TEST-PC-019](#test-pc-019) |
| SRS-PC-V04 | [TEST-PC-001](#test-pc-001), [TEST-PC-011](#test-pc-011), [TEST-PC-019](#test-pc-019) |
| SRS-PC-V05 | [TEST-PC-001](#test-pc-001), [TEST-PC-011](#test-pc-011), [TEST-PC-019](#test-pc-019) |
| SRS-PC-E01 | [TEST-PC-002](#test-pc-002) |
| SRS-PC-E02 | [TEST-PC-002](#test-pc-002) |
| SRS-PC-E03 | [TEST-PC-002](#test-pc-002), [TEST-PC-010](#test-pc-010), [TEST-PC-020](#test-pc-020), [TEST-PC-021](#test-pc-021), [TEST-PC-026](#test-pc-026) |
| SRS-PC-E04 | [TEST-PC-002](#test-pc-002) |
| SRS-PC-E05 | [TEST-PC-002](#test-pc-002) |
| SRS-PC-E06 | [TEST-PC-002](#test-pc-002) |
| SRS-PC-E07 | [TEST-PC-002](#test-pc-002) |
| SRS-PC-E08 | [TEST-PC-003](#test-pc-003), [TEST-PC-017](#test-pc-017) |
| SRS-PC-E09 | [TEST-PC-010](#test-pc-010) |
| SRS-PC-O01 | [TEST-PC-003](#test-pc-003), [TEST-PC-014](#test-pc-014), [TEST-PC-015](#test-pc-015), [TEST-PC-017](#test-pc-017), [TEST-PC-023](#test-pc-023), [TEST-PC-024](#test-pc-024), [TEST-PC-025](#test-pc-025) |
| SRS-PC-O02 | [TEST-PC-003](#test-pc-003), [TEST-PC-014](#test-pc-014), [TEST-PC-017](#test-pc-017) |
| SRS-PC-O03 | [TEST-PC-003](#test-pc-003), [TEST-PC-014](#test-pc-014), [TEST-PC-017](#test-pc-017) |
| SRS-PC-O04 | [TEST-PC-016](#test-pc-016) |
| SRS-PC-O05 | [TEST-PC-016](#test-pc-016), [TEST-PC-023](#test-pc-023) |
| SRS-PC-O06 | [TEST-PC-014](#test-pc-014), [TEST-PC-025](#test-pc-025) |
| SRS-PC-O07 | [TEST-PC-014](#test-pc-014), [TEST-PC-025](#test-pc-025) |
| SRS-PC-O08 | [TEST-PC-016](#test-pc-016) |
| SRS-PC-O09 | [TEST-PC-023](#test-pc-023) |
| SRS-PC-O10 | [TEST-PC-024](#test-pc-024) |
| SRS-PC-D01 | [TEST-PC-004](#test-pc-004), [TEST-PC-005](#test-pc-005) |
| SRS-PC-D02 | [TEST-PC-004](#test-pc-004), [TEST-PC-005](#test-pc-005) |
| SRS-PC-D03 | [TEST-PC-004](#test-pc-004), [TEST-PC-005](#test-pc-005) |
| SRS-PC-D04 | [TEST-PC-004](#test-pc-004), [TEST-PC-005](#test-pc-005) |
| SRS-PC-D05 | [TEST-PC-005](#test-pc-005), [TEST-PC-017](#test-pc-017) |
| SRS-PC-D06 | [TEST-PC-005](#test-pc-005), [TEST-PC-017](#test-pc-017) |
| SRS-PC-D07 | [TEST-PC-005](#test-pc-005), [TEST-PC-017](#test-pc-017) |
| SRS-PC-D08 | [TEST-PC-004](#test-pc-004), [TEST-PC-018](#test-pc-018), [TEST-PC-029](#test-pc-029) |
| SRS-PC-D09 | [TEST-PC-004](#test-pc-004), [TEST-PC-018](#test-pc-018), [TEST-PC-029](#test-pc-029) |
| SRS-PC-D10 | [TEST-PC-006](#test-pc-006) |
| SRS-PC-D11 | [TEST-PC-007](#test-pc-007), [TEST-PC-029](#test-pc-029) |
| SRS-PC-I01 | [TEST-PC-004](#test-pc-004), [TEST-PC-018](#test-pc-018), [TEST-PC-028](#test-pc-028), [TEST-PC-029](#test-pc-029) |
| SRS-PC-I02 | [TEST-PC-004](#test-pc-004), [TEST-PC-018](#test-pc-018), [TEST-PC-028](#test-pc-028), [TEST-PC-029](#test-pc-029) |
| SRS-PC-I03 | [TEST-PC-018](#test-pc-018) |
| SRS-PC-I04 | [TEST-PC-018](#test-pc-018) |
| SRS-PC-C01 | [TEST-PC-008](#test-pc-008), [TEST-PC-013](#test-pc-013), [TEST-PC-015](#test-pc-015) |
| SRS-PC-C02 | [TEST-PC-008](#test-pc-008), [TEST-PC-013](#test-pc-013), [TEST-PC-015](#test-pc-015) |
| SRS-PC-C03 | [TEST-PC-008](#test-pc-008), [TEST-PC-013](#test-pc-013), [TEST-PC-015](#test-pc-015) |
| SRS-PC-C04 | [TEST-PC-008](#test-pc-008), [TEST-PC-013](#test-pc-013), [TEST-PC-015](#test-pc-015) |
| SRS-PC-C05 | [TEST-PC-008](#test-pc-008), [TEST-PC-013](#test-pc-013), [TEST-PC-015](#test-pc-015) |
| SRS-PC-C06 | [TEST-PC-008](#test-pc-008), [TEST-PC-013](#test-pc-013), [TEST-PC-015](#test-pc-015) |
| SRS-PC-C07 | [TEST-PC-029](#test-pc-029) |
| SRS-PC-C08 | [TEST-PC-030](#test-pc-030) |
| SRS-PC-R01 | [TEST-PC-009](#test-pc-009) |
| SRS-PC-R02 | [TEST-PC-008](#test-pc-008), [TEST-PC-009](#test-pc-009), [TEST-PC-017](#test-pc-017) |
| SRS-PC-R03 | [TEST-PC-009](#test-pc-009) |
| SRS-PC-R04 | [TEST-PC-009](#test-pc-009) |
| SRS-PC-R05 | [TEST-PC-009](#test-pc-009) |
| SRS-PC-R06 | [TEST-PC-021](#test-pc-021) |
| SRS-PC-R07 | [TEST-PC-022](#test-pc-022) |
| SRS-PC-Q01 | [TEST-PC-003](#test-pc-003), [TEST-PC-004](#test-pc-004), [TEST-PC-006](#test-pc-006), [TEST-PC-017](#test-pc-017), [TEST-PC-018](#test-pc-018), [TEST-PC-019](#test-pc-019), [TEST-PC-021](#test-pc-021), [TEST-PC-022](#test-pc-022) |
| SRS-PC-Q02 | [TEST-PC-007](#test-pc-007), [TEST-PC-027](#test-pc-027), [TEST-PC-028](#test-pc-028) |
| SRS-PC-Q03 | [TEST-PC-027](#test-pc-027), [TEST-PC-028](#test-pc-028) |
| SRS-PC-Q04 | [TEST-PC-011](#test-pc-011) |
| SRS-PC-Q05 | [TEST-PC-011](#test-pc-011) |
| SRS-PC-Q06 | [TEST-PC-012](#test-pc-012) |
| SRS-PC-Q07 | [TEST-PC-012](#test-pc-012) |
| SRS-PC-Q08 | [TEST-PC-012](#test-pc-012) |
| SRS-PC-Q09 | [TEST-PC-012](#test-pc-012) |
| SRS-PC-Q10 | [TEST-PC-012](#test-pc-012) |
| SRS-PC-Q11 | [TEST-PC-006](#test-pc-006), [TEST-PC-007](#test-pc-007), [TEST-PC-015](#test-pc-015), [TEST-PC-021](#test-pc-021) |
| SRS-PC-Q12 | [TEST-PC-010](#test-pc-010), [TEST-PC-020](#test-pc-020), [TEST-PC-026](#test-pc-026) |
| SRS-PC-Q13 | [TEST-PC-014](#test-pc-014) |
| SRS-PC-Q14 | [TEST-PC-012](#test-pc-012) |
| SRS-PC-Q15 | [TEST-PC-012](#test-pc-012) |
| SRS-PC-X01 | [TEST-PC-002](#test-pc-002), [TEST-PC-019](#test-pc-019) |
| SRS-PC-X02 | [TEST-PC-003](#test-pc-003), [TEST-PC-007](#test-pc-007), [TEST-PC-016](#test-pc-016), [TEST-PC-023](#test-pc-023), [TEST-PC-024](#test-pc-024) |
| SRS-PC-X03 | [TEST-PC-003](#test-pc-003), [TEST-PC-007](#test-pc-007), [TEST-PC-016](#test-pc-016), [TEST-PC-023](#test-pc-023), [TEST-PC-024](#test-pc-024) |
| SRS-PC-X04 | [TEST-PC-003](#test-pc-003), [TEST-PC-007](#test-pc-007), [TEST-PC-016](#test-pc-016), [TEST-PC-023](#test-pc-023), [TEST-PC-024](#test-pc-024) |
| SRS-PC-X05 | [TEST-PC-003](#test-pc-003), [TEST-PC-007](#test-pc-007), [TEST-PC-016](#test-pc-016), [TEST-PC-023](#test-pc-023), [TEST-PC-024](#test-pc-024) |

## Condición de aceptación y entrega

Cada caso identifica entrada, entorno, expectativa y evidencia. Un bloqueo se informa como blocked, no como pass. Los fallos críticos de datos, propiedad, control, conservación o coherencia educativa impiden aceptar el producto.

La preparación sin Vivado, la convivencia JTAG/UART y los permisos o controladores requieren pruebas con los binarios y la placa reales. Las garantías de compatibilidad y rendimiento se sustentan en los entornos medidos. Los bytes y fixtures compartidos con la verificación FPGA conservan su nivel de evidencia; una prueba del cliente no valida por sí sola la implementación del procesador.

La implementación avanza por las entregas funcionales de la guía, con sus comprobaciones locales e integraciones correspondientes. Los hitos conjuntos documentan la revisión del sistema completo y no sustituyen la evidencia de las entregas. La aceptación del producto requiere ejecutar las pruebas especificadas, incluida la validación visual del inspector. No existen resultados de ejecución de estas pruebas de aplicación acreditados por este documento.
