### DEC-SYS-008 — Aplicación de PC

**Estado:** Aprobada.

**Dominio:** Software de PC e integración del sistema.

**Contratos vigentes de consulta:** [Documentación de viewrv](../software/viewrv/README.md), [arquitectura](../software/viewrv/arquitectura.md), [contratos y funcionamiento](../software/viewrv/contratos.md). Los documentos especializados definen los campos, operaciones, versiones y criterios de aceptación de cada tema.

**Contexto:** La aplicación permite comprender el pipeline del TP3 y comprobar su implementación sobre la FPGA. La exploración educativa y la preparación de programas deben poder realizarse sin placa. La ejecución y la depuración reales requieren una placa preparada y conectada; sus observaciones deben conservar una correspondencia inequívoca con el programa y la revisión utilizados.

La operación debe estar disponible mediante una interfaz visual y mediante comandos para personas, agentes externos y automatizaciones deterministas. Ambas interfaces necesitan las mismas reglas de admisión, ejecución, recuperación y conservación, con un único control de la placa y resultados coherentes.

**Decisión:** viewrv es una aplicación de escritorio local para Linux y Windows x86_64. Integra un visor educativo y una IDE gráfica, una CLI y un core local compartido.

| Parte | Responsabilidad |
|-------|-----------------|
| Core | Mantener la autoridad sobre programas, revisiones, preparación de placa, conexión, sesiones, interpretación y conservación. |
| GUI | Presentar el visor, el editor, las vistas de depuración y las interacciones de escritorio; comunicar las acciones al core. |
| CLI | Interpretar comandos y presentar resultados humanos o JSON; utilizar el mismo core sin iniciar Electron. |

El core utiliza puertos y adaptadores en un único proceso. La lógica compartida permanece independiente de HTTP, UART, programación física y almacenamiento. Las abstracciones se limitan a fronteras que necesitan separación, sustitución o prueba. Las cuatro áreas de lógica son programas y traducciones, preparación y conexión, sesiones y resultados y conservación del código y la evidencia.

GUI y CLI son clientes pares. El core se inicia bajo demanda y mantiene su estado entre invocaciones CLI. Su ciclo de vida depende de los trabajos registrados; terminar un comando o cerrar una GUI observadora no termina un trabajo ajeno. Cada trabajo conserva sus obligaciones de cierre explícito y el core impone el control exclusivo de la placa.

La comunicación local utiliza HTTP con FastAPI y Uvicorn en un único proceso servidor, escuchando en loopback. SSE proporciona a cada GUI una vista inicial coherente y actualizaciones ordenadas. La CLI utiliza consultas y acciones finitas. El descubrimiento privado, la credencial por instancia, la identidad del trabajo y las revisiones de estado mantienen las reglas del contrato compartido.

El hilo de aplicación conserva la autoridad sobre el estado lógico. UART se ejecuta en un hilo serial con pySerial; almacenamiento y ensamblado utilizan sus trabajadores dedicados. La programación del bitstream utiliza un proceso hijo supervisado. Los resultados se incorporan en el hilo de aplicación antes de publicarse; una respuesta parcial nunca se convierte en una captura actual.

#### Herramientas y recursos

| Área | Selección |
|------|-----------|
| Ventana y presentación | Electron, React y TypeScript; Zustand para estado compartido de presentación. |
| Controles y estilo | Base UI, vanilla-extract y Lucide, adaptados a Penpot. |
| Editor y espacio de trabajo | Monaco Editor con @monaco-editor/react y FlexLayout. |
| Visor | Motor GraphViewer existente de draw.io, integrado mediante un adaptador que conserva apariencia e interacciones. |
| Core y CLI | Python; FastAPI y Uvicorn para el canal local, Click para comandos y HTTPX síncrono para CLI. |
| Acceso a la placa | pySerial para UART y openFPGALoader incluido en el producto para programar el bitstream. |
| Construcción y distribución | electron-vite, PyInstaller y electron-builder. Entrega tar.gz con instalación opcional por usuario en Linux y NSIS por usuario en Windows. |
| Verificación automatizada de Python | unittest, con pruebas separadas del assembler y comandos definidos en el catálogo de viewrv. |

Las versiones, dependencias y rutas de recursos tienen su única definición en [Integración y distribución](../software/viewrv/integracion_y_distribucion.md). La GUI conserva la referencia visual de Penpot y el tema inicial del visor. La escala se aplica a la interfaz completa. Español es el idioma inicial; contenido, estilo y lógica se separan para permitir la incorporación posterior del inglés.

El diagrama mantiene geometría y estilos en XML, correspondencias semánticas en bindings y explicaciones en recursos de contenido separados. El core utiliza identificadores funcionales del procesador; el adaptador gráfico los relaciona con las celdas del dibujo. Los recursos del visor, fuentes, iconos y ejemplos se incluyen localmente.

#### Fronteras y conservación

| Frontera | Condición |
|----------|-----------|
| Assembler | Se utiliza su interfaz pública de traducción de texto a imagen y mapa PC–línea o diagnóstico. Su diseño, implementación y pruebas conservan su entrega independiente. La FPGA mantiene la validación autoritativa de capacidad de LOAD. |
| FPGA y UART | Se conserva el protocolo existente: comandos, bytes, campos, perfiles, plazos y recuperación. Las identidades de programas, trabajos y ensayos pertenecen a PC y no se agregan al mensaje UART. |
| Programación de placa | Se utiliza el bitstream del procesador previamente generado y versionado como recurso. Programarlo y comprobar después UART es distinto de cargar instrucciones. La aplicación no sintetiza RTL ni exige la suite completa de Vivado para programar ese recurso. |
| Código fuente | Los archivos del usuario conservan texto Assembly normal. El core mantiene además copias internas JSON de recuperación, separadas de la instalación y asociadas a programa y revisión. |
| Evidencia | Cada ensayo registrado conserva fuente, revisión, contexto, observaciones completas y desenlace disponible en JSON Lines. El registro está activo por defecto, puede desactivarse y se conserva hasta eliminación explícita. |
| Explicación educativa | La interpretación funcional se separa de los valores medidos. El seguimiento identifica únicamente la aparición seleccionada mediante capturas consecutivas y no utiliza el PC aislado como identidad dinámica. |
| Agentes y automatizaciones | Utilizan la CLI y los contratos comunes. GUI y CLI pueden observar una sesión controlada desde la otra interfaz sin generar pasos ni transferir control. El producto no incorpora un agente de IA ni un simulador de programas. |

Las acciones conservan la revisión tomada para su entrada. GUI confirma la recepción del texto antes de las operaciones que lo utilizan, mantiene la edición y el autoguardado durante las operaciones permitidas y no aplica resultados antiguos como texto nuevo. El RUN del atajo combinado utiliza la revisión de su LOAD confirmada aunque el editor cambie durante la transferencia. El inicio de depuración conserva la protección de edición definida.

La CLI presenta texto legible por defecto y JSON por selección explícita. Ayuda y versión son excepciones y siempre presentan texto. Los comandos no requieren preguntas interactivas cuando se proporcionan los datos necesarios. La interrupción de la espera del cliente no cancela implícitamente una operación del core.

**Justificación:** Un core compartido concentra las reglas que deben ser iguales en GUI y CLI y conserva la conexión y las sesiones entre invocaciones. La separación entre lógica y recursos permite comprobar el comportamiento sin placa mediante adaptadores controlados. La observación desde ambas interfaces utiliza una misma fuente de estado y evita coordinar conexiones UART competidoras.

Electron proporciona un entorno de presentación común para conservar la composición visual prevista en ambos sistemas operativos. La integración de Monaco y FlexLayout cubre edición y espacio de trabajo; mantener el motor existente del visor permite conservar su apariencia e interacciones mientras sus detalles se encapsulan. Los recursos locales y el programador incluido reducen las dependencias del usuario final.

**Consecuencias:** El core y ambos clientes deben conservar los mismos contratos, códigos y asociaciones de revisión. Los mecanismos de concurrencia, almacenamiento y publicación deben mantener la respuesta de la GUI durante las esperas y la coherencia de cada observación. La distribución debe permitir ejecutar CLI y core sin Electron, localizar recursos desde la instalación y mantenerlos disponibles mientras el core los utilice.

Los procedimientos de instalación, permisos USB y controladores se comprueban por plataforma. La conservación frente a interrupciones, la fluidez y la fidelidad visual requieren la evidencia prevista en el catálogo. Las posiciones y proporciones sujetas a validación visual se resuelven mediante esa comprobación, sin cambiar las reglas compartidas de sesión.

#### Fuentes de detalle y trazabilidad

| Documento | Autoridad |
|-----------|-----------|
| [Requisitos de viewrv](../software/viewrv/requisitos.md) | Producto, alcance, 74 requisitos y 30 escenarios de aceptación. |
| [Arquitectura](../software/viewrv/arquitectura.md) | Procesos, responsabilidades, trabajadores y coordinación. |
| [Contratos y funcionamiento](../software/viewrv/contratos.md) | Operaciones, CLI, HTTP, JSON, SSE, errores, sesiones y evidencia. |
| [GUI y visor](../software/viewrv/gui_y_visor.md) | Interacciones, referencia visual, correspondencia con el pipeline e interpretación educativa. |
| [Integración y distribución](../software/viewrv/integracion_y_distribucion.md) | Dependencias y versiones, ubicaciones de código y recursos, preparación física y entrega. |
| [Verificación](../software/viewrv/verificacion.md) | TEST-PC-001 a TEST-PC-030, variantes, expectativas, niveles, comandos y cobertura. |

**Requisitos afectados:** REQ-SW-001, REQ-SW-002 y REQ-SW-004 a REQ-SW-011; presentación y uso desde PC del estado de REQ-DBG-013 a REQ-DBG-017 y del desenlace anormal de REQ-EXEC-018. La trazabilidad de cada obligación se consulta en [Requisitos](../requirements.md#8-software-de-pc), la [matriz del sistema](../verification/coverage.md) y la cobertura de la SRS. Las responsabilidades de traducción de REQ-SW-003 y REQ-SW-012 conservan [DEC-SYS-009](DEC-SYS-009.md).

**Dependencias:** [DEC-SYS-006](DEC-SYS-006.md), [DEC-SYS-009](DEC-SYS-009.md), [Protocolo UART](../protocol.md) y los contratos de CPU, Debug, memoria, sesión y plataforma enlazados desde el [diseño FPGA](../architecture/system_overview.md).

**Estado de realización y verificación:** La aprobación corresponde al diseño especificado. La implementación y ejecución de sus pruebas se realizan en las entregas correspondientes; esta decisión no acredita compilaciones, pruebas de plataforma ni aceptación física. La revisión del PR y la incorporación de la entrega de diseño conservan sus condiciones propias de cierre de la issue #12.
