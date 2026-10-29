# GUI y visor de viewrv

- **Tipo:** interfaz de usuario y contenido educativo.
- **Estado documental:** especificación vigente.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [Referencia visual y estilo](#referencia-visual-y-estilo)
- [Composición general de la aplicación](#composición-general-de-la-aplicación)
- [Entrada al modo IDE](#entrada-al-modo-ide)
- [Pestañas y programa cargado en la FPGA](#pestañas-y-programa-cargado-en-la-fpga)
- [Archivos y guardado](#archivos-y-guardado)
- [Banco de ejemplos](#banco-de-ejemplos)
- [Editor y ayuda al escribir](#editor-y-ayuda-al-escribir)
- [Catálogo de instrucciones](#catálogo-de-instrucciones)
- [Ensamblado](#ensamblado)
- [Conexión con la FPGA](#conexión-con-la-fpga)
- [Carga del programa](#carga-del-programa)
- [Ejecución con Correr](#ejecución-con-correr)
- [Entrada a la depuración](#entrada-a-la-depuración)
- [Diagrama durante la depuración](#diagrama-durante-la-depuración)
- [Espacio de trabajo durante la depuración](#espacio-de-trabajo-durante-la-depuración)
- [Información del debugger convencional](#información-del-debugger-convencional)
- [Separación de datos, contenido y dibujo](#separación-de-datos-contenido-y-dibujo)
- [Catálogo funcional y correspondencia inicial](#catálogo-funcional-y-correspondencia-inicial)
- [Asociación de los valores observados](#asociación-de-los-valores-observados)
- [Participación funcional del ciclo](#participación-funcional-del-ciclo)
- [Seguimiento de una aparición seleccionada](#seguimiento-de-una-aparición-seleccionada)
- [Adaptador gráfico y recursos locales](#adaptador-gráfico-y-recursos-locales)
- [Banco educativo y ejemplos ejecutables](#banco-educativo-y-ejemplos-ejecutables)
- [Mantenibilidad y revisión](#mantenibilidad-y-revisión)
- [Inspector de valores y validación visual](#inspector-de-valores-y-validación-visual)

## Propósito y alcance

Describe la composición, interacciones y presentación de la GUI y la asociación entre el diagrama, las capturas y el contenido educativo. La lógica de ejecución y sus contratos pertenecen al core; las vistas comparten las mismas observaciones completas.

## Referencia visual y estilo

La tipografía utiliza Inter para la interfaz e IBM Plex Mono para el contenido monoespaciado, con recursos locales. La referencia visual es [Penpot](https://design.penpot.app/#/workspace?team-id=41725af0-a889-809a-8008-d6f44ce4eed0&file-id=685eebd9-2ce2-80a4-8008-d6f5fdc5ed3d&page-id=3d21ebe3-631e-802a-8008-d6f5d3c9730e&layout=layers). La GUI conserva su tipografía, paleta, espaciado, proporciones e interacciones, con el tema actual como único tema inicial. El [manual de identidad visual](recursos/viewrv_manual_identidad_visual_v0.9.pdf) es una referencia conceptual de marca en borrador y no reemplaza el diseño de las pantallas.

Los recursos visuales comunes se definen mediante vanilla-extract y alimentan los estilos de componentes y las adaptaciones de Base UI, FlexLayout, Monaco y el visor. Las APIs que no reciben variables CSS utilizan esos mismos valores a través de su adaptador. Las reglas globales se limitan al área correspondiente. Los iconos Lucide se incluyen localmente, con sus avisos de licencia.

Los controles deshabilitados conservan una explicación por tooltip y acceso al foco cuando corresponda. La edición admite los comandos habituales de teclado. El zoom ajusta textos y componentes de toda la interfaz, no solo el código. Español es el idioma inicial; los textos se separan de la lógica para incorporar inglés seleccionable.

## Composición general de la aplicación

### Navegación lateral y espacio de trabajo

La referencia principal de composición es VS Code. Las capturas de la aplicación de escritorio y de OpenCode sirven como referencias complementarias. Se toma su disposición de áreas, tabs y splits; el estilo visual continúa basado en el visor actual.

La aplicación se organiza en dos áreas principales:

- Una barra lateral izquierda de navegación general, con acceso a **Visor interactivo**, **IDE** y **Ajustes**.
- A su derecha, el contenido de la sección elegida. En la IDE, contiene una barra superior de acciones y el área de trabajo de tabs y splits.

La barra superior de acciones permanece visible durante el modo IDE, por encima de todos los grupos de tabs. Contiene las acciones definidas de ensamblado, carga, ejecución y depuración según el contexto. Su permanencia se refiere a la IDE; el visor educativo conserva sus controles específicos.

El área de trabajo se organiza en grupos de tabs. Cada grupo permite seleccionar cuál de sus tabs se ve; los splits permiten ver varios grupos al mismo tiempo, a izquierda-derecha o arriba-abajo. Esto sirve tanto para trabajar con varios programas como para combinar código, documentación e información de depuración.

Las tabs también pueden arrastrarse hacia los bordes izquierdo, derecho, superior o inferior de un área de trabajo para colocarlas allí mediante un split, siguiendo la referencia de interacción de VS Code. Esta interacción complementa las opciones del menú **Ver**.

La barra lateral general sirve para navegar entre secciones. La presentación de los valores y explicaciones de un componente del circuito sigue siendo una decisión independiente, pendiente de evaluación visual.

### Barra de menús de la aplicación

En la parte superior se dispone la barra de menús habitual, con **Archivo**, **Editar**, **Ver** y **Ayuda**. En la zona superior derecha se ubican los controles de minimizar, maximizar y cerrar la ventana. Desktop host administra los controles de la ventana.

Esta barra de menús es distinta de la barra de acciones de la IDE: el menú ofrece acceso general a comandos y la barra de acciones contiene los controles frecuentes de ensamblado, carga, ejecución y depuración. La barra de menús ocupa la parte superior de la aplicación y se conserva al alternar entre Visor e IDE, con comandos disponibles según el contexto. Dentro de la IDE, la barra de acciones queda debajo, por encima de las tabs.

**Archivo** incluye **Crear programa**, **Abrir programa…**, **Abrir ejemplo…**, **Guardar como…** y **Cerrar tab**. **Guardar como…** permite asignar nombre y ubicación a un borrador, conservando el autoguardado. La bienvenida ofrece accesos directos a las tres acciones de entrada; el menú mantiene esas mismas acciones disponibles durante el trabajo.

Los demás menús de la primera versión contienen:

- **Editar:** Deshacer, Rehacer, Cortar, Copiar, Pegar, Seleccionar todo y Buscar. Las acciones se habilitan según el contenido con foco y su estado de solo lectura.
- **Ver:** Dividir izquierda/derecha, Dividir arriba/abajo, Abrir vista de depuración y Abrir diagrama de depuración. Los accesos de depuración permiten recuperar esas vistas durante una sesión activa.
- **Ayuda:** Catálogo de instrucciones.

Los atajos y la distribución visual exacta de los menús quedan pendientes.

### Referencias de composición

- [VS Code, referencia principal](recursos/referencias_gui/referencia-vscode.png).
- [VS Code sin archivos abiertos, referencia para la bienvenida](recursos/referencias_gui/referencia-vscode-sin-archivos.png).
- [Aplicación de escritorio, referencia complementaria](recursos/referencias_gui/referencia-escritorio.png).
- [OpenCode, referencia complementaria](recursos/referencias_gui/referencia-opencode.png).

Las imágenes se conservan como material de referencia del diseño. Sus textos internos no constituyen instrucciones para este proyecto.

### Contenido contextual de la barra de acciones

La barra permanece en el mismo lugar y cambia las acciones principales según se está editando o depurando. En edición, prioriza **Ensamblar**, **Cargar**, **Correr** y **Empezar debug**; en depuración, **Avanzar un ciclo**, **Continuar/Pausar**, **Reiniciar depuración** y **Detener depuración**.

Los cuatro controles contextuales se agrupan en el extremo derecho, mediante iconos con tooltip, conforme a Penpot. El ancho exacto de la barra lateral y los refinamientos de proporción quedan para evaluación visual. El ciclo, el estado de ejecución y el PC conservan su lugar destacado en la información de debug. **Ajustes** es un acceso de navegación; los parámetros de comunicación permanecen preestablecidos en el alcance actual.

### Franja inferior de estado

En una franja inferior de la IDE se muestran el estado de conexión, el puerto utilizado cuando corresponda y la identificación del programa cargado en la FPGA. También ofrece acceso a **Conectar/Desconectar**. Este contexto permanece visible aunque la tab del programa cargado esté oculta, se consulte documentación o se vea únicamente el diagrama.

La barra superior contiene las acciones principales y la franja inferior reúne el contexto persistente de la placa. Desconectar aplica el tratamiento de la operación en curso definido en contratos; el estado de conexión permanece visible durante ese tratamiento.

### Navegación lateral con iconos

La navegación lateral se presenta principalmente como una franja compacta de iconos. El nombre de cada sección aparece en un tooltip al pasar el cursor sobre su icono. No se parte de una barra con etiquetas de texto permanentes.

Los iconos se toman de Lucide y su distribución se contrasta con Penpot. La navegación es compacta y no requiere una variante expandida con nombres.

### La navegación no pausa la ejecución

Si el usuario activa **Continuar** y cambia al visor educativo para consultar algo, la depuración sigue avanzando. Cambiar de sección no pausa, termina ni reinicia la sesión. Se mantienen las condiciones definidas de detención por breakpoint, pausa explícita, terminación o fallo de comunicación.

Al volver a la IDE, se muestra la última captura completa y el estado alcanzado; no se exige permanecer mirando la IDE para que avance la secuencia de pasos.

Si se alcanza un breakpoint o termina el programa mientras se consulta otra sección, el resultado queda disponible al regresar a la IDE, sin cambiar automáticamente de sección. La notificación discreta con acceso para volver a la IDE es opcional; su presentación queda pendiente de evaluación visual.

La elección de notificar o no y la posible presencia del estado de ejecución en una franja común durante esta situación siguen abiertas. La barra completa de acciones sigue perteneciendo al modo IDE.

## Entrada al modo IDE

Al entrar sin un programa abierto, se muestra una pantalla de bienvenida, parecida en su función a la entrada de Visual Studio Code. El editor aparece después de elegir con qué trabajar.

Las tres opciones de entrada son:

- **Abrir ejemplo:** abrir un selector interno de la aplicación para elegir un programa del banco de ejemplos. Al abrirlo, se trabaja sobre una copia editable, conservando el original.
- **Abrir programa:** abrir el selector de archivos del sistema operativo para elegir un programa existente.
- **Crear programa:** abrir una tab nueva con un borrador para escribir desde cero, sin exigir nombre ni ubicación iniciales.

El modelo de trabajo es simple: la FPGA ejecuta un programa por vez y los programas son independientes. La primera entrega no incorpora proyectos ni relaciones entre programas.

### Bienvenida en el espacio vacío

Cuando la IDE no tiene contenido abierto, el área central muestra los tres botones anteriores, tomando como referencia la composición de VS Code sin archivos abiertos. Los accesos a comandos o atajos de la captura de referencia se sustituyen por estas tres acciones. No se incorpora una tab **Inicio** permanente.

La forma y disposición exactas de los botones quedan sujetas a evaluación visual. La barra de acciones y la franja inferior conservan sus lugares; la habilitación de acciones depende del contexto disponible.

### Acceso con contenido abierto

**Crear programa**, **Abrir programa** y **Abrir ejemplo** siguen disponibles desde **Archivo** cuando la bienvenida ya fue reemplazada por tabs. No se requiere añadir otro control de apertura junto a las tabs para resolver ese acceso.

## Pestañas y programa cargado en la FPGA

El editor permite tener varios programas abiertos en pestañas. Esto facilita comparar instrucciones, guías o resultados esperados y alternar entre programas sin tener que cerrar y volver a abrir archivos.

La documentación también puede abrirse en una pestaña, para alternar entre la consulta y la escritura dentro del mismo espacio de trabajo. Las pestañas pueden organizarse en splits para consultar contenido en paralelo; la distribución exacta de la interfaz queda pendiente.

Los splits son una capacidad general del espacio de trabajo, también fuera de la depuración. Permiten colocar dos programas distintos uno al lado del otro tanto para compararlos como para trabajar y editar ambos, alternando el foco como en un editor de código. Cada programa conserva su contenido y autoguardado de forma independiente. Esto no supone ejecutar ambos ni establecer una relación entre sus sesiones en la FPGA.

Las pestañas deben permitir identificar qué programa está cargado actualmente en la FPGA. La pestaña seleccionada y el programa cargado son conceptos distintos; cambiar de pestaña no debe confundirse con cambiar el programa de la FPGA.

También se distingue la versión de trabajo de la versión cargada: editar o guardar un programa no actualiza la FPGA. Cargar una versión en la FPGA es una acción independiente y explícita. El indicador debe comunicar cuando el programa fue modificado desde su carga.

### Foco y destino de las acciones

**Ensamblar** y **Cargar** actúan sobre el programa de la pestaña con foco, aunque haya varios grupos visibles. La secuencia combinada parte de ese mismo programa.

Antes de ensamblar, cargar, guardar o cerrar un documento, la GUI confirma que el core recibió la revisión elegida, conforme a la [coordinación del texto](contratos.md#coordinación-del-texto-antes-de-acciones). La edición y el autoguardado continúan durante ensamblado, carga y guardado; cada operación conserva su copia de entrada. Para cerrar se resuelve la última revisión sin dejar actualizaciones para enviar después del cierre.

**Correr** solo se habilita si el programa con foco corresponde al cargado en la FPGA, además de cumplir las condiciones de conexión y ejecución. Si la FPGA tiene `A.s` y el foco está en `B.s`, **Correr** está deshabilitado y se indica que ese programa no está cargado. La secuencia combinada permite ensamblar, cargar y ejecutar `B.s`.

La correspondencia incluye la versión del código, no solo el nombre del archivo. Si se modifica el mismo programa después de cargarlo, **Correr** y **Empezar debug** quedan deshabilitados hasta ensamblar y cargar la versión actual. El tooltip indica **El programa fue modificado desde la última carga**. La acción combinada **Ensamblar, cargar y correr** conserva su función de preparar y ejecutar esa versión actual.

Las solicitudes individuales envían program_id y source_version del documento sobre el que se pidió la acción. El RUN del atajo combinado conserva esos dos campos del resultado de su LOAD confirmada, aunque el editor haya cambiado durante la carga. El core comprueba la coincidencia con la imagen antes de operar, según el [contrato de identificación de revisión](contratos.md#identificación-de-la-revisión-al-iniciar-run-o-debug). La GUI indica cuándo la ejecución corresponde a una revisión distinta de la que muestra el editor.

Los controles de una depuración ya iniciada mantienen como destino su sesión, incluso al consultar otras pestañas. Cambiar de foco no cambia la sesión depurada.

### Foco en una tab de documentación

En modo edición, al enfocar una tab de documentación, **Ensamblar**, **Cargar**, **Correr** y **Empezar debug** quedan deshabilitados. Su tooltip indica **Seleccioná un programa**. No se elige implícitamente un programa que haya quedado en segundo plano.

Si ya hay una depuración activa, sus controles comunes siguen actuando sobre esa sesión aunque se consulte documentación, según la regla definida de destino de los controles de debug.

### Identificación independiente del programa cargado

La franja inferior conserva la identificación del programa cargado en la FPGA aunque su tab esté oculta, se cierre o el foco pase a documentación. El estado detallado del archivo con foco se presenta por separado, a la derecha de esa franja. La identificación de la imagen cargada no depende de la tab activa.

## Archivos y guardado

Se usa autoguardado por defecto para simplificar el trabajo: el contenido del editor se guarda automáticamente y la distinción principal queda entre la versión de trabajo y la versión cargada en la FPGA.

El autoguardado no carga ni ejecuta el programa en la FPGA.

Se puede empezar a escribir sin elegir nombre ni ubicación. Los programas nuevos y las variantes de ejemplos se conservan como borradores recuperables hasta que el usuario decida asignarles nombre y destino. El autoguardado de un ejemplo se aplica a su copia de trabajo y conserva el original del banco.

Los borradores deben poder recuperarse al volver a abrir la aplicación. Cerrar una pestaña conserva su borrador; descartarlo exige otra acción explícita según [Conservación de borradores](contratos.md#código-recuperable). Se reabren los programas que seguían abiertos al salir según [Reapertura de programas](contratos.md#código-recuperable); la interacción concreta de recuperación y descarte queda por especificar.

El core coordina el autoguardado y confirma cada versión conservada. La GUI muestra el resultado o el fallo; editar, guardar y cargar son operaciones independientes.

### Informar errores de guardado

Si falla el autoguardado, la interfaz debe mostrar un mensaje de error. Al solicitar salir de la aplicación, el guardado pendiente se completa antes del cierre. Si falla, la aplicación permanece abierta, identifica el contenido afectado y permite reintentar o guardarlo en otro destino. Salir con contenido sin conservar requiere una acción explícita del usuario, según [Cierre con código pendiente](contratos.md#código-recuperable). La presentación concreta de los avisos y las interacciones de cierre de pestañas quedan por especificar.

## Banco de ejemplos

Los ejemplos forman parte central de la experiencia para principiantes. El primer programa que una persona lea, ejecute y depure puede ser un ejemplo incluido en la aplicación.

### Selector interno de ejemplos

El selector interno se presenta como una ventana de la aplicación con una lista de ejemplos, cada uno con un nombre orientado al propósito y una descripción breve de qué se aprende. Por ejemplo, **Sumar dos números** o **Una dependencia entre instrucciones**. Al elegir uno y pulsar **Abrir**, el selector se cierra y se abre una tab con su copia editable. El código completo, la guía y los resultados detallados se consultan después de abrir el ejemplo.

### Contenido de cada ejemplo

Cada ejemplo incluye:

- Un propósito claro y comprensible.
- Un programa corto y comentado, que relacione las instrucciones con lo que se quiere hacer.
- Un resultado final esperado, expresado mediante registros o memoria cuando corresponda.
- Una guía del recorrido del programa, con explicaciones y resultados esperados durante sus etapas o ciclos, además del resultado final.

Los ejemplos deben ser concretos y de complejidad acotada, suficiente para explicar el funcionamiento del pipeline. No necesitan demostrar programas grandes. Después, el usuario puede usar el set de instrucciones como abstracción para escribir programas más complejos.

La guía permite entender qué se va a probar, cómo está escrito y qué debería ocurrir. La idea es que el mismo programa acompañe el aprendizaje desde la escritura hasta la ejecución y la depuración.

La guía se organiza por ciclos, como granularidad mínima para entender la evolución del pipeline. Dentro de cada ciclo se explica qué ocurre en las etapas relevantes, contemplando las instrucciones que están en vuelo simultáneamente. Las formas de concentrarse en una instrucción o una etapa podrán apoyarse en esa referencia temporal común.

### Abrir, modificar y guardar un ejemplo

Abrir un ejemplo lo presenta como un archivo editable dentro del editor, con el que se puede trabajar y que se puede ejecutar en la FPGA. El ejemplo original del banco se conserva.

Si se modifica y se guarda, se guarda como un programa aparte; el usuario puede elegir su nombre. No se sobrescribe el ejemplo original.

El propósito, la guía y los resultados esperados corresponden a la versión original del ejemplo. No se consideran resultados válidos para una variante modificada ni se recalculan automáticamente. La interfaz comunica esta relación mediante el aviso asociado al acceso a la información del ejemplo.

### Acceso a la información del ejemplo desde el editor

Los programas abiertos desde el banco de ejemplos disponen de un acceso **Acerca del ejemplo** a la derecha de la franja que muestra la ruta del archivo, inmediatamente debajo de las tabs y encima del código.

Al abrirlo, la información se despliega debajo de esa franja, dentro de la misma tarjeta del programa, y desplaza el código hacia abajo. Al plegarla, el editor recupera ese espacio. Incluye el propósito y el resultado final esperado; el recorrido organizado por ciclos corresponde a la experiencia de depuración, cuya presentación se trata aparte.

Cuando se modifica el programa, se conserva ese acceso y se muestra un pequeño icono informativo o de advertencia junto a él. Su tooltip aclara: **Referencia del ejemplo original. Modificaste el programa; estos resultados esperados corresponden al código original.** La aclaración también queda disponible al desplegar la información. La elección gráfica entre un círculo con una «i», un triángulo u otro símbolo equivalente queda para evaluación visual.

### Contenido educativo: punto de partida y cobertura

El banco inicial parte de cuatro tipos de ejemplo: una operación simple, varias instrucciones independientes en vuelo, una dependencia entre instrucciones y lectura/escritura de memoria. Son un punto de partida; no se consideran suficientes para completar el banco.

El contenido deberá incluir ejemplos de todas las instrucciones soportadas por el procesador y de las distintas situaciones que puedan ocurrir en el pipeline. La elaboración de ese contenido es una tarea distinta de la composición de la GUI. La selección exacta de programas y la guía de cada uno quedan para ese trabajo de contenido; no se fija un límite de cuatro ejemplos.

La cantidad final y la organización del banco siguen abiertas.

### Explicación del ciclo dentro de la vista de debug

La guía por ciclos se consulta mediante una sección desplegable **Explicación del ciclo** dentro de la tab de debug, debajo del encabezado de ciclo y PC. Al desplegarla, muestra qué debería ocurrir en ese ciclo y qué conviene observar; al plegarla, se recupera el espacio para los valores. Esta ubicación está sujeta a validación visual.

La sección existe solamente para los ejemplos preparados del banco. No aparece para los demás programas escritos por el usuario ni se genera automáticamente una guía para ellos.

Durante la depuración del ejemplo original, la explicación corresponde al ciclo de la última captura completa. La guía describe qué debería ocurrir, qué partes del pipeline conviene observar y qué valores se esperan en ese momento. La interfaz distingue esa referencia preparada del estado efectivamente recibido de la FPGA.

Los controles comunes siguen gobernando el avance del procesador. Leer o seleccionar información de la guía no ejecuta ciclos. La guía no incorpora comparación automática de corrección.

La sincronización solo corresponde al ejemplo original. Si se trabaja con una variante modificada, la guía original puede seguir consultándose como referencia, pero no se presenta como descripción sincronizada ni como resultado esperado de esa variante. El acceso **Acerca del ejemplo** y su advertencia conservan las reglas definidas para las copias modificadas. Los detalles visuales y el estado inicial de desplegado de la explicación del ciclo quedan por evaluar.

## Editor y ayuda al escribir

Se busca un autocompletado acotado de instrucciones:

- Al escribir un prefijo, aparecen las instrucciones que coinciden.
- Se pueden recorrer con el teclado o el mouse.
- La sugerencia seleccionada muestra una explicación breve de lo que hace.
- Se puede aceptar una sugerencia e insertar la instrucción.

Esta ayuda usa un catálogo conocido de instrucciones. No se busca asistencia generativa ni sugerencias del estilo Copilot.

La asistencia contextual más amplia —sugerir operandos según la posición, analizar etiquetas o detectar operandos incorrectos mientras se escribe— queda fuera del alcance inicial del editor. Los mensajes que produce el ensamblador se presentan según lo definido en la sección de resultado del ensamblado.

### Integración local del editor

Monaco utiliza un único modelo de texto por programa y puede tener varias vistas del mismo modelo. @monaco-editor/react recibe la instancia de Monaco incluida en el producto; el loader se configura antes de iniciar el editor para evitar su CDN predeterminado. El editor, los workers y los recursos de idioma se distribuyen localmente. Mover u ocultar una vista conserva modelo, selección e historial de edición durante el uso; cerrar la última vista libera únicamente los recursos que ya no necesitan otros paneles.

Las sugerencias insertan mnemónicos, registros y alias en minúsculas conforme al lenguaje del assembler. El proveedor se limita a las 32 instrucciones soportadas más halt, sin pseudoinstrucciones ni directivas. Los marcadores y la explicación bajo la línea corresponden al único diagnóstico de la revisión ensamblada; una respuesta anterior no se atribuye al texto editado después.

## Catálogo de instrucciones

Además del autocompletado, debe existir una sección pequeña de documentación donde consultar las instrucciones disponibles. Una persona que todavía no sabe qué puede escribir necesita poder descubrirlas sin probar letras al azar.

El contenido existente del visor es una base para esa documentación y para las descripciones de las sugerencias. Habrá que revisar qué información corresponde específicamente al lenguaje definido por el ensamblador.

### Acceso desde Ayuda

**Ayuda → Catálogo de instrucciones** abre una tab de documentación dentro del mismo espacio de trabajo. Puede colocarse junto al código mediante un split o consultarse alternando tabs.

El catálogo presenta las instrucciones del lenguaje del TP3 y reutiliza el contenido educativo. La consulta desde Ayuda abre una pestaña de documentación; no ejecuta ni modifica el programa.

## Ensamblado

La aplicación ofrece acciones propias de **Ensamblar**, **Cargar**, **Correr** y **Empezar debug**. Durante la depuración, la barra contextual muestra **Avanzar un ciclo**, **Continuar/Pausar**, **Reiniciar depuración** y **Detener depuración**, con los comportamientos definidos en las secciones de debug.

### Acciones individuales y una secuencia combinada

Se conservan las acciones individuales y se ofrece, como opción adicional, una acción o atajo explícito de **Ensamblar, cargar y correr**. No requiere separar usuarios en modos principiante y avanzado.

**Correr** ejecuta el programa cargado en la FPGA y requiere que el programa con foco corresponda a ese programa. La acción combinada trabaja con el programa de la pestaña activa y recorre las tres operaciones, mostrando su avance. Si una operación falla, no se continúa con la siguiente.

Los pasos y sus resultados son visibles aunque se soliciten mediante una sola acción. **Ensamblar, cargar y correr** se ofrece en un pequeño desplegable junto al icono de **Correr**, conservando los cuatro botones principales. El botón habitual sigue ejecutando el programa cargado; elegir la opción del desplegable solicita explícitamente la secuencia completa. El atajo queda por definir. Las acciones individuales conservan su responsabilidad.

### Resultado del ensamblado

Si hay errores, se marcan en rojo las líneas afectadas directamente en el editor. Una notificación discreta en una esquina informa que el ensamblado falló. La explicación se integra debajo del código de la misma línea, como una extensión de ella, desplazando las líneas siguientes, conforme a Penpot. No se usa un diálogo bloqueante para enumerar los errores ni un panel separado para esa explicación.

El contrato del assembler devuelve un diagnóstico por llamada, con línea y mensaje. Con ese contrato, se presenta el error recibido; el diseño visual no implica obtener todos los errores simultáneamente.

Si tiene éxito, una notificación discreta informa que el programa quedó ensamblado e incluye una acción para abrir la vista ensamblada. Esa vista también puede abrirse después, aunque se ignore o desaparezca la notificación.

La vista ensamblada es opcional y relaciona direcciones, instrucciones y código máquina generado. Permite relacionar la traducción con los PCs de depuración sin exigir abrirla para cargar o ejecutar.

### Cambios posteriores al ensamblado

**Cargar** requiere un ensamblado exitoso correspondiente al contenido actual del programa. Si lo que está en el editor y se conserva mediante autoguardado no coincide con lo ensamblado, no se permite cargar el resultado anterior. Se indica que el ensamblado está desactualizado y hace falta ensamblar la versión actual.

El autoguardado no implica volver a ensamblar. La secuencia combinada ya incluye el ensamblado previo y solo continúa hacia la carga si esa operación tiene éxito.

## Conexión con la FPGA

La placa debe conectarse antes de cargar un programa. Sin conexión, la carga no está habilitada. Conectar y cargar son operaciones diferentes: establecer la comunicación no transfiere automáticamente un programa.

La acción de conectar abre un espacio donde se puede establecer la conexión con la placa. Su presentación como pestaña, diálogo o ventana flotante todavía no está elegida.

La carga requiere tanto una conexión disponible como un ensamblado exitoso vigente. Conectar habilita la carga únicamente si también se cumple ese requisito de ensamblado.

Los parámetros de comunicación vienen preestablecidos según el TP y no son editables en el alcance actual. La configuración manual no forma parte del espacio de conexión inicial. A futuro podría incorporarse mediante una pestaña o un submenú de opciones, sin que eso sea un requisito para esta versión.

## Carga del programa

Se reutiliza el patrón de información discreta definido para el ensamblado: mostrar que la carga está en curso, informar su resultado y actualizar la identificación del programa cargado únicamente después de que la FPGA confirme el éxito de la operación.

Mientras se transfiere, se muestra **Cargando…**. Si la carga termina correctamente, aparece una notificación discreta de éxito. Si falla, una notificación informa el problema y permite consultar detalles; no se continúa automáticamente con la ejecución. El tratamiento exacto del estado de la FPGA después de un fallo debe ajustarse al protocolo.

La carga individual deja el programa listo para una acción posterior de correr o empezar debug, conservando la separación entre operaciones. Durante la carga se impiden nuevas cargas y acciones de ejecución para evitar superponerlas.

### Pendiente

Definir si el progreso se representa mediante una barra o un indicador de actividad y qué otras interacciones permanecen disponibles durante la transferencia.

## Ejecución con Correr

### Play se transforma en Stop durante RUN

El control **Correr** usa el icono de Play. Al iniciar la ejecución con RUN, ese mismo control pasa a un icono cuadrado de Stop. La acción de Stop solicita **RESET** a la placa, respetando las reglas del protocolo; actúa sobre la ejecución en curso.

Este control se distingue de **Pausar** en el modo debug por pasos. Su tooltip debe comunicar que detener implica reiniciar la placa. Tras confirmar RESET, la GUI invalida la identificación de imagen ejecutable y requiere volver a cargar antes de correr o depurar. El código y su ensamblado en la computadora no se invalidan por ese reset.

El control vuelve a Play al finalizar la ejecución o confirmarse su interrupción. Después de RESET, Play permanece deshabilitado hasta tener nuevamente una imagen cargada y cumplir las condiciones habituales de ejecución.

### Apertura automática de resultados

Al terminar la ejecución y recibir la información de debug completa, los resultados se muestran automáticamente. No hace falta abrirlos desde una notificación. Su presentación como pestaña o panel todavía no está definida.

### Representación de valores

Los valores se presentan en hexadecimal por defecto. Cada valor permite elegir de forma independiente otra representación, como decimal con signo, decimal sin signo o binario. La elección es por elemento, sin obligar a cambiar la representación de los demás.

La elección de formato es local a cada elemento; las preferencias persistentes se limitan al objeto definido en integración y distribución.

## Entrada a la depuración

Para un programa recién cargado, **Empezar debug** simplemente abre el modo depuración de la IDE. No ejecuta automáticamente ningún ciclo. El primer ciclo se ejecuta recién al pulsar **Avanzar un ciclo**. Cada acción de ese control solicita un `STEP` y muestra la captura posterior al ciclo cuando se recibe completa.

El protocolo no entrega un snapshot inicial después de `LOAD`: antes del primer `STEP`, la interfaz debe distinguir que todavía no dispone de una captura de esa sesión. Las reglas para continuar, reiniciar, detener y tratar una sesión finalizada se definen en contratos y se presentan mediante los controles siguientes.

### Indicador de espera durante STEP

Mientras está pendiente la respuesta de un STEP, mostrar **Esperando respuesta de la FPGA…** junto al contador de ciclos. Si existe una captura completa anterior de la sesión actual, conservarla visible durante la espera. Si todavía no existe, mantener la indicación de que aún no se recibió la primera captura.

Cuando se recibe la respuesta completa, actualizar los valores y el contador de ciclos juntos, usando el estado recibido. La espera de comunicación no se presenta como nuevos ciclos ejecutados.

### Continuar y pausar la depuración

Además de **Avanzar un ciclo**, se ofrecen **Continuar** y **Pausar**. Continuar solicita una secuencia de `STEP`, recibe cada captura completa y comprueba si debe detenerse por un breakpoint, una solicitud de pausa o la terminación del programa.

Pausar detiene el envío de nuevos pasos después de completar el paso y la respuesta que estuvieran en curso. Este control corresponde a la secuencia de pasos de la GUI; no presupone que `RUN` tenga una orden de pausa.

### Breakpoint como instrucción y registro interetapa

Un breakpoint se define mediante una instrucción y un registro interetapa. Al marcar una línea, se abre un menú similar al de autocompletado para elegir `IF/ID`, `ID/EX`, `EX/MEM` o `MEM/WB`.

La condición consiste en que el registro seleccionado tenga una entrada válida con el PC de la instrucción buscada. Esto se corresponde directamente con los campos recibidos en el snapshot y las tarjetas del debugger.

Cuando la condición se cumple, se detiene el avance y se muestra el estado observable completo del sistema, incluidas las demás instrucciones en vuelo. Los efectos que otras instrucciones ya realizaron permanecen visibles.

| Registro | Interpretación del punto observado |
|---|---|
| `IF/ID` | Después de IF, a la entrada de ID. |
| `ID/EX` | Después de ID, a la entrada de EX. |
| `EX/MEM` | Después de EX, a la entrada de MEM. |
| `MEM/WB` | Después de MEM, a la entrada de WB. |

Las opciones pueden acompañarse de una descripción de su posición en el recorrido, como **ID/EX · entrada a ejecución**. Nombrar el registro evita la ambigüedad entre detenerse antes o después de procesar una etapa. Los estados se observan después de un ciclo: la presencia en `ID/EX` no significa que el ciclo de EX de esa instrucción ya se haya realizado.

Este menú no incluye una captura anterior al primer fetch ni una detención posterior a WB: no hay registros interetapa correspondientes a esos dos puntos. El primer punto registrado de una instrucción es `IF/ID`. La condición de breakpoint tampoco garantiza por sí misma que la instrucción hará commit.

### Varios breakpoints sobre una línea

Una instrucción puede asociarse a varios registros interetapa mediante breakpoints independientes. Por ejemplo, detenerla primero en `ID/EX` y luego en `EX/MEM`. Se detiene cuando se cumple cualquiera de las condiciones activas, sin exigir que se cumplan simultáneamente.

### Reanudar y evaluar cada nuevo ciclo

Al pulsar **Continuar** después de una detención, solicitar un nuevo `STEP` y evaluar los breakpoints sobre la nueva captura completa. No volver a evaluar la captura anterior como si fuera un nuevo avance.

Si la condición del mismo breakpoint sigue cumpliéndose después del nuevo ciclo, volver a detenerse. Esto incluye una instrucción retenida por un stall: la nueva detención corresponde a otro ciclo observado, aunque la instrucción siga en el mismo registro. Las otras partes del pipeline pueden haber cambiado.

Se evalúa la presencia de la instrucción en el registro en cada captura; no se suprimen coincidencias consecutivas ni se exige que la instrucción abandone el registro para volver a detenerse.

Si ninguna condición se cumple y no hay pausa ni terminación, **Continuar** solicita el siguiente paso. Si varios breakpoints se cumplen en la misma captura completa, el avance se detiene una sola vez y se informan todos los coincidentes sobre ese mismo estado observable, sin ejecutar ciclos adicionales para examinarlos. Al pulsar Continuar se solicita el siguiente STEP y se evalúa la nueva captura, según [Coincidencias de breakpoints](contratos.md#breakpoints). La revisión de viabilidad confirma que el lenguaje actual admite como máximo una instrucción por línea, sin expansiones, y que el resultado del assembler entrega el mapa PC–línea; no existe en ese lenguaje el caso pendiente de varias instrucciones de máquina generadas por una misma línea.

### Reiniciar la depuración

Se ofrece **Reiniciar depuración** para volver al inicio de la misma versión del programa que pertenece a la sesión, conservando breakpoints, pestañas y disposición del espacio de trabajo. Una modificación posterior del editor no se incorpora silenciosamente a ese reinicio.

La nueva sesión vuelve a su estado inicial y espera **Avanzar un ciclo** o **Continuar**; reiniciar no ejecuta por sí mismo el primer ciclo. Las capturas anteriores dejan de presentarse como estado actual de la nueva sesión. Como después de una carga, no hay snapshot inicial hasta realizar el primer paso.

Reiniciar utiliza una nueva LOAD de la imagen de la misma revisión y espera la primera orden de avance. RESET invalida la imagen y STEP terminal incluye un ciclo; no sustituyen esa operación.

### Terminación de la sesión depurada

Cuando la FPGA informa `FINISHED` o `FAULT`, el debugger permanece abierto con la captura terminal para inspeccionar el resultado. Se muestra si la terminación fue normal o por fault, con su causa y PC cuando corresponda. **Avanzar un ciclo** y **Continuar** quedan deshabilitados para esa sesión; **Reiniciar depuración** permanece disponible cuando la conexión lo permite.

Esta distinción evita enviar involuntariamente un `STEP` desde un estado terminal, que en el protocolo inicia una nueva sesión y ejecuta su primer ciclo. La intención de empezar otra ejecución se expresa mediante la acción de reiniciar.

El drain por HALT o fault no se presenta todavía como sesión finalizada: los ciclos pendientes siguen observándose y avanzándose en modo debug hasta alcanzar el estado terminal.

### Edición del programa depurado

Las marcas de instrucciones y los breakpoints deben corresponder a la versión cargada que pertenece a la sesión. Insertar o modificar líneas del archivo de trabajo no modifica la imagen de la FPGA ni garantiza que siga siendo válida la correspondencia entre PCs y líneas del código visible.

El código del programa depurado permanece en solo lectura durante todo el modo debug. Se permite consultar y seleccionar texto y administrar breakpoints; modificar el programa requiere salir del modo debug y después ensamblar y cargar la nueva versión. Los demás programas abiertos siguen siendo editables.

No se incorpora una edición paralela de la versión de trabajo del programa depurado ni una vista adicional de su versión cargada para resolver modificaciones durante la sesión.

### Detener la depuración y volver a editar

Se ofrece **Detener depuración** para terminar la sesión de debug y volver a la edición, desbloqueando el programa. Si hay una secuencia de pasos activa, se deja de enviar nuevos `STEP` y se completa la captura pendiente antes de terminar la transición.

Detener termina la sesión lógica: al volver a iniciar una ejecución o depuración se prepara una sesión nueva, sin reanudar silenciosamente el estado anterior. Entrar de nuevo en debug sigue esperando la primera orden de avance, sin ejecutar un primer ciclo. **Pausar** conserva la sesión y permite continuarla; **Reiniciar depuración** comienza de nuevo permaneciendo en modo debug.

La preparación se difiere hasta el siguiente inicio que la requiera, según el contrato de sesiones. Una sesión no terminal abandonada requiere nueva LOAD para comenzar desde el inicio.

Si se modifica el código después de detener la depuración, se mantienen los requisitos de ensamblar y cargar la nueva versión. **Empezar debug** queda deshabilitado hasta que la versión actual vuelva a corresponder con la imagen cargada, según la regla de correspondencia de versiones definida.

### Presentación de la pérdida de comunicación

Al perder la comunicación durante la depuración, conservar la última captura completa visible e identificarla como **Último estado recibido · ciclo N**. No presentarla como una observación del estado actual del procesador.

Mostrar un aviso persistente dentro de la vista de debug con el texto **Se perdió la comunicación con la FPGA**. El aviso no se presenta en una ventana que tape los datos. La barra inferior indica si se está recuperando la comunicación o si la recuperación falló.

Interrumpir la secuencia de nuevos pasos y deshabilitar las acciones que requieren comunicación mientras se recupera el enlace. El usuario conserva su código, breakpoints y disposición de trabajo.

### Nueva sesión tras una depuración interrumpida

Si una pérdida de comunicación interrumpe la depuración, después de recuperar el enlace la GUI requiere volver a cargar el programa e iniciar una sesión nueva. No se reanuda automáticamente la sesión anterior ni se ejecuta automáticamente la nueva carga. El usuario conserva el código, los breakpoints y la disposición de trabajo.

Si hubo reset confirmado, volver a cargar es necesario porque se invalidó la imagen. Si la consulta recuperó el enlace sin reset, el protocolo no obliga a recargar en todos los casos; la GUI adopta este criterio adicional para volver a depurar desde un estado conocido.

### Resultado de la recuperación en el mismo aviso

Al terminar la recuperación, actualizar el mismo aviso dentro de la vista de debug:

- **Comunicación recuperada:** indicar **Volvé a cargar el programa para iniciar una nueva depuración**. La carga sigue siendo una acción explícita del usuario.
- **Recuperación fallida:** indicar **No se pudo restablecer la comunicación** y ofrecer **Reintentar conexión**. El nuevo intento requiere esa acción explícita; no se repite automáticamente la operación interrumpida.

Si hubo un reinicio confirmado de la placa, el aviso también lo aclara. La última captura conserva su identificación como observación anterior, incluso después de recuperar el enlace.

## Diagrama durante la depuración

### Visor adaptado en una pestaña de la misma sesión

El diagrama interactivo durante la depuración se ofrece como otra pestaña del mismo espacio de trabajo, reutilizando el visor existente y adaptando su interfaz a la depuración. Puede compartir un split con el código o con la información convencional de debug.

El diagrama usa la misma sesión y las mismas capturas que las otras vistas. Abrirlo o cambiar de pestaña no inicia otra sesión ni ejecuta ciclos. Los controles de depuración siguen en el área común.

El visor educativo existente conserva su función de exploración sin conectar la FPGA. La distinción entre explicaciones conceptuales y valores observados durante la ejecución debe ser clara. La pestaña en debug no necesita reproducir todos los controles del visor educativo; los controles se limitan a la exploración visual y no duplican la coordinación de ejecución del core.

### Explorar el circuito y consultar su estado

Dentro de la pestaña del diagrama, el usuario puede recorrer el circuito, seleccionar módulos y consultar los valores disponibles asociados a ellos. Al avanzar la ejecución, puede seguir viendo cómo cambian esos valores. El objetivo es relacionar el comportamiento del programa con sus componentes físicos, usando la misma sesión de debug.

### Alcance inicial de los valores del debugger interactivo

La primera versión muestra los valores que llegan directamente de la FPGA: PC, campos de los registros interetapa, banco de registros y memoria de datos observable. Los valores adicionales calculados por la GUI, como salidas de multiplexores no transmitidas en Debug, se dejan para una iteración posterior.

Este recorte se refiere a los valores adicionales reconstruidos. El resaltado general por instrucción y etapa pertenece a la primera entrega. Las reglas de interpretación y seguimiento se describen en este documento y se comprueban mediante verificación.

### Participación de bloques en cada ciclo

Se resaltan las partes del diagrama que participaron en el ciclo ejecutado. Por ejemplo, si una `ADDI` se procesó en EX, destacar el camino de operandos utilizado y la suma en la ALU; para otra instrucción, el recorrido que corresponda. Este énfasis busca mostrar cómo cambia la participación de los componentes durante la ejecución.

### Alcance inicial del resaltado

La primera versión conserva el resaltado general de los bloques involucrados según la instrucción y la etapa. Se reutilizan los recorridos conceptuales existentes; no es necesario calcular valores adicionales para identificar esa participación funcional.

El detalle exacto de las ramas que requiera reconstrucción adicional, como qué entrada de cada multiplexor de forwarding se utilizó, queda para una ampliación. Este alcance debe respetar stalls y descartes y distinguir el estado posterior a un STEP del trabajo realizado durante el ciclo recién completado. No representa una medición independiente de todas las señales físicas.

### Criterios de interpretación y coherencia temporal

Un mismo ciclo puede involucrar varias instrucciones en distintas etapas. Por defecto se muestra la participación general del ciclo y se permite concentrarse en una instrucción o zona seleccionada. La participación funcional, la selección del usuario y el cambio de valor son conceptos diferentes y necesitan representaciones distinguibles.

La captura recibida después de un `STEP` describe el estado posterior al ciclo. Para explicar la actividad del ciclo recién ejecutado hay que relacionarla con el estado previo, en lugar de atribuir esa actividad a las instrucciones que acaban de entrar a cada registro. Por ejemplo, una instrucción que queda en `ID/EX` está a la entrada de EX; si completó EX y avanzó válidamente, aparece en `EX/MEM`.

El protocolo transmite principalmente estado registrado, no todas las señales combinacionales. La participación que se reconstruya debe justificarse con la información observable y la arquitectura, distinguiéndola de los valores recibidos. Los recorridos conceptuales del visor no se asumen automáticamente como una traza exacta ante stalls, redirects, forwarding, drain o faults. La primera transición utiliza únicamente las garantías de preparación conocidas y mantiene la ausencia de captura medida inicial.

Los recorridos por instrucción y etapa existentes en el visor son la base que se reutiliza: ya identifican módulos, conexiones y funciones. Para el resumen del ciclo se relacionan los recorridos de las instrucciones que participaron simultáneamente. La selección de una instrucción permite concentrarse en su contribución.

El catálogo actual explica ejemplos independientes con supuestos documentados. La aplicación de esos recorridos a una ejecución real requiere interpretar validez y controles, y ajustar los caminos que dependan del contexto. Por ejemplo, el forwarding puede cambiar el origen de un operando de una misma instrucción. Se conserva el catálogo como conocimiento de la arquitectura, sin asumir que elegir el opcode basta para recuperar toda la actividad de hardware.

### Correlación entre código y vistas de debug

Seleccionar una instrucción desde sus marcas en el editor o desde la tarjeta del registro que la contiene permite localizarla en las otras vistas de la misma captura. Por ejemplo, seleccionar la instrucción de `ID/EX` señala su línea de assembly en el editor y el registro `ID/EX` que la contiene en el diagrama. El vínculo también puede usarse desde las marcas del editor hacia las otras vistas.

Es una ayuda para relacionar código, estado convencional y circuito. No ejecuta ciclos ni cambia el programa cargado.

Las vistas conservan la selección por aparición y registro interetapa; una misma línea puede tener varias apariciones simultáneas. La navegación visual no modifica el avance de la sesión.

### Observación fija y seguimiento

Se ofrecen dos comportamientos compatibles:

- **Observar un componente:** conservar seleccionado un registro, como `ID/EX`, y mostrar los cambios de su contenido en cada captura. La cámara permanece en ese componente.
- **Seguir una instrucción:** acompañar una aparición concreta de una instrucción mientras pasa de un registro interetapa a otro, relacionando las marcas del editor, las tarjetas y el diagrama.

La observación fija es el comportamiento predeterminado. El seguimiento se activa mediante una acción explícita, como **Seguir esta instrucción**. Elegir qué observar no modifica cuánto avanza el procesador: los controles de avance siguen siendo los mismos.

El seguimiento corresponde a una aparición concreta de la instrucción: no salta automáticamente a una nueva iteración de la misma línea en un bucle. Para lograrlo se deben considerar retenciones y descartes; no se supone que el PC por sí solo identifique una aparición única durante toda la ejecución. La continuidad se calcula con FollowState y capturas consecutivas, según el contrato de seguimiento.

### Fin del seguimiento

Cuando la instrucción seguida termina, se informa el fin del seguimiento mediante un aviso breve y se conserva el encuadre, sin elegir otra instrucción automáticamente. Este evento no termina por sí mismo la sesión ni agrega una pausa a **Continuar**: el avance sigue gobernado por los controles, breakpoints y estados terminales definidos.

Si la instrucción deja de estar activa por un descarte o fault, el seguimiento debe reflejarlo sin inventar un paso a otro registro. La explicación del motivo se ofrece cuando la información disponible permite determinarlo; no se asume que todo `valid=0` tenga una causa observable.

La presentación exacta de este aviso y qué queda seleccionado después todavía no están definidas.

## Espacio de trabajo durante la depuración

### Pestañas, splits y controles comunes

La información de debug se presenta como una pestaña que puede compartir el espacio de trabajo con el editor. Se puede colocar en una división izquierda-derecha o arriba-abajo, o mantenerla como una pestaña oculta mientras se consulta otra.

La depuración puede continuar observando solo el editor, solo la información de debug o ambos al mismo tiempo. La sesión y el estado recibido son los mismos en todas esas disposiciones; cambiar la distribución o la pestaña visible no inicia otra sesión.

Los controles de depuración están fuera de los splits, en un área común que permanece accesible independientemente de la vista seleccionada. Actúan sobre la sesión del programa cargado en la FPGA, no sobre cualquier programa cuya pestaña se seleccione.

### Disposición inicial

Al entrar por primera vez en depuración, se presenta código a la izquierda e información de debug a la derecha, con los controles comunes arriba. El usuario puede reorganizar las vistas después.

### Alcance de la primera versión: sin persistencia de la disposición

No se incluye guardar ni restaurar la distribución personalizada de tabs, splits y tamaños entre sesiones. Se mantiene la posibilidad de reorganizar el espacio durante el uso.

Esta decisión se refiere a la disposición del espacio de trabajo; no cambia las reglas definidas sobre la sesión de depuración activa ni sobre cerrar y volver a abrir sus vistas.

### Cerrar y volver a abrir la vista de depuración

Cerrar la tab de depuración retira esa vista del espacio de trabajo. La sesión conserva su estado y continúa si estaba avanzando, con las mismas condiciones de detención definidas. Los controles comunes siguen disponibles arriba; el usuario puede seguir depurando desde el código o el diagrama.

La vista puede volver a abrirse desde **Ver → Depuración**, mostrando el último estado recibido de la misma sesión. La acción **Detener depuración** termina la sesión según su comportamiento definido. Cerrar la tab por sí solo no equivale a detenerla.

## Información del debugger convencional

### Jerarquía educativa

El debugger convencional debe permitir entender el pipeline mediante una jerarquía visual clara, aun sin el diagrama arquitectónico. La presentación organiza el estado para explicar la ejecución y evita reducir la experiencia a un listado uniforme de campos.

La información se organiza con la siguiente jerarquía:

- Encabezado compacto con ciclo observado, estado de ejecución y PC global de fetch.
- Área principal para los registros interetapa.
- Área complementaria para el banco de registros.
- Memoria consultable, con mayor protagonismo al analizar cargas y stores.

Para entender el avance del pipeline, la prioridad es registros interetapa, PC de fetch y banco de registros. Para revisar el resultado final, registros y memoria adquieren mayor protagonismo. La prioridad de la información no exige que el PC tenga un panel grande: puede permanecer siempre visible en el encabezado.

Los PCs de las instrucciones en vuelo se distinguen del PC global de fetch. El banco de registros muestra efectos ya efectivos, mientras los registros interetapa pueden contener resultados todavía pendientes de writeback.

### Tarjetas desplegables con celdas

Los registros interetapa se presentan como cuatro tarjetas desplegables con celdas, ordenadas según el recorrido: `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`. Cada una permite identificar su validez, PC e instrucción y consultar sus demás campos.

Los registros dibujados en el visor actual sirven como referencia conceptual por su organización en bloques con campos internos. La apariencia, proporciones y distribución de las celdas siguen abiertas; las tarjetas no requieren copiar literalmente las formas del diagrama.

El PC global se identifica por separado como frente de fetch. Una entrada inválida no se presenta como una instrucción activa aunque conserve bits residuales.

### Destacar cambios entre ciclos

Se destacan las celdas cuyos valores cambiaron respecto de la captura anterior para facilitar la lectura del efecto de cada avance. Este énfasis indica una diferencia de valores; por sí solo no explica su causa ni implica un error. La comparación entre capturas sucesivas no requiere navegación histórica ni cambia la experiencia principal en vivo.

### Colores: alcance actual

Se toma amarillo como color para destacar valores que cambiaron respecto de la captura anterior.

Rojo y verde quedan sin semántica asignada a las celdas hasta identificar una necesidad concreta. La comparación automática contra los resultados esperados de los ejemplos no es un requisito definido y no se incorpora al alcance actual.

Un valor inesperado, un bit `valid=0` o un stall no son por sí mismos errores. La selección de una celda debe seguir siendo distinguible del énfasis por cambios. Los tonos exactos y los indicadores de texto todavía no están definidos.

### Vínculo entre código y pipeline

Se muestran junto a las líneas del editor indicadores de las etapas ocupadas por sus instrucciones, actualizados con cada captura. Esto permite seguir la depuración desde el código aunque la pestaña de información de debug esté oculta. La apariencia exacta de las marcas queda pendiente.

La interacción con cada celda y el comportamiento exacto del desplegado todavía no están definidos.

## Separación de datos, contenido y dibujo

| Recurso previsto | Responsabilidad |
|------------------|-----------------|
| processor_profile.json | Identidad de perfil, campos observables, instrucciones y reglas de participación funcional. |
| diagram.drawio.xml | Geometría, conexiones y estilos de la única vista completa utilizada por el adaptador. |
| diagram_bindings.json | Correspondencia entre identificadores funcionales y celdas, grupos o campos del dibujo. |
| content/es/ | Explicaciones de módulos, señales, instrucciones, situaciones y enlaces educativos. |
| examples/ | Programas Assembly completos y metadatos de objetivo y observaciones esperadas. |

Estos son destinos de recursos que se prepararán al implementar; esta etapa documenta sus estructuras y correspondencias, sin crear un nuevo runtime. Las convenciones de datos y validaciones utilizan JSON y XML con las bibliotecas ya disponibles.

| Campo del descriptor de perfil | Contenido |
|------------------------------|-----------|
| schema_version | 1. |
| profile_id | Identificador del procesador de este TP; inicialmente tp3-riscv. |
| revision | Revisión semántica del perfil; inicialmente 1. No cambia por mover bloques o traducir texto. |
| memory_profile | REFERENCE en la entrega Basys 3; ALT_1000 únicamente para los entornos de prueba previstos por el contrato. |
| architecture_source | Revisión de la documentación normativa del procesador. |
| diagram_sha256 | Huella del XML preparado. |
| bindings_sha256 | Huella de las correspondencias preparadas. |
| instruction_ids | Catálogo de los 33 mnemónicos soportados. |

El objeto compartido processor_profile contiene profile_id, revision y memory_profile. core/info añade ese objeto para que la GUI compruebe su compatibilidad con el perfil local antes de asociar datos al circuito. start del registro de ensayo conserva el mismo objeto como metadato del contrato utilizado. Describe el perfil de interpretación del software, no una identidad leída de la FPGA. Una incompatibilidad impide vincular la vista viva y utiliza CORE_INCOMPATIBLE, conservando la preparación explícita de placa ya definida.

La selección memory_profile pertenece al recurso del producto y no se modifica desde preferencias, GUI ni CLI. El core resuelve sus capacidades desde la tabla normativa de memoria y las usa para interpretar cantidades y calcular recuperación. La entrega y su bitstream corresponden a REFERENCE; una construcción de prueba ALT_1000 debe identificarse como tal y no se declara soportada físicamente. El inventario de entrega conserva ese mismo perfil. La comprobación entre clientes y core incluye los tres campos y no presume que UART los informe.

Los identificadores de bloques son semánticos y estables. El core devuelve esos nombres en cycle_activity.blocks; solo el adaptador gráfico los traduce a celdas. El texto traducible no identifica un componente y cambiar su título no altera la lógica.

## Catálogo funcional y correspondencia inicial

La tercera columna es una referencia del dibujo, no un identificador de negocio. Las celdas hijas y rótulos pertenecen al módulo mediante los metadatos de propiedad existentes.

| block_id | Nombre actual | Celda raíz o representación |
|----------|---------------|------------------------------|
| latch.id_ex | ID/EX | PeWG_VKsY-f66Zm0Bl_l-288 |
| latch.ex_mem | EX/MEM | PeWG_VKsY-f66Zm0Bl_l-337 |
| latch.mem_wb | MEM/WB | d6Z_Gf_YBklqbeCfQCJ9-135 |
| latch.if_id | IF/ID | PeWG_VKsY-f66Zm0Bl_l-214 |
| if.pc | PC | PeWG_VKsY-f66Zm0Bl_l-192 |
| if.instruction_memory | Instruction Memory | PeWG_VKsY-f66Zm0Bl_l-193 |
| rf.register_file | Registers | PeWG_VKsY-f66Zm0Bl_l-198 |
| if.pc_adder | PC Adder | PeWG_VKsY-f66Zm0Bl_l-212 |
| if.next_pc_mux | Next PC MUX | PeWG_VKsY-f66Zm0Bl_l-213 |
| id.immediate_generator | Immediate Generator | PeWG_VKsY-f66Zm0Bl_l-223 |
| ex.alu | ALU | PeWG_VKsY-f66Zm0Bl_l-251 |
| mem.data_memory | Data Memory | PeWG_VKsY-f66Zm0Bl_l-254 |
| ex.forward_mux_a | Forward MUX A | PeWG_VKsY-f66Zm0Bl_l-335 |
| ex.forward_mux_b | Forward MUX B | PeWG_VKsY-f66Zm0Bl_l-336 |
| ex.target_adder | Target Adder | PeWG_VKsY-f66Zm0Bl_l-352 |
| ex.alu_source_mux | ALUSrc MUX | PeWG_VKsY-f66Zm0Bl_l-363 |
| ex.jalr_adder | JALR Adder | PeWG_VKsY-f66Zm0Bl_l-392 |
| ex.clear_bit_zero | Clear bit 0 | PeWG_VKsY-f66Zm0Bl_l-397 |
| ex.target_mux | Target MUX | PeWG_VKsY-f66Zm0Bl_l-400 |
| ex.link_adder | Link Adder | cTusTiFrEAaOMj2go4Ax-1 |
| ex.result_mux | Result MUX | cTusTiFrEAaOMj2go4Ax-5 |
| mem.load_select_extend | Load Select/Extend | cTusTiFrEAaOMj2go4Ax-49 |
| if.fault_check | IF Fault Check | d6Z_Gf_YBklqbeCfQCJ9-3 |
| if.input_logic | IF/ID Input Logic | d6Z_Gf_YBklqbeCfQCJ9-20 |
| if.pc_update | PC Update Control | d6Z_Gf_YBklqbeCfQCJ9-51 |
| id.fault_check | ID Fault Check | d6Z_Gf_YBklqbeCfQCJ9-90 |
| id.rs1_bypass_mux | RS1 Bypass MUX | d6Z_Gf_YBklqbeCfQCJ9-111 |
| id.rs2_bypass_mux | RS2 Bypass MUX | d6Z_Gf_YBklqbeCfQCJ9-113 |
| id.load_use_detector | Load-Use Detector | d6Z_Gf_YBklqbeCfQCJ9-123 |
| id.wb_bypass_control | WB Bypass Control | d6Z_Gf_YBklqbeCfQCJ9-132 |
| mem.wb_value_mux | WB Value MUX | d6Z_Gf_YBklqbeCfQCJ9-145 |
| ex.flow_control | Flow Control | d6Z_Gf_YBklqbeCfQCJ9-227 |
| ex.forwarding_unit | Forwarding Unit | d6Z_Gf_YBklqbeCfQCJ9-248 |
| ex.fault_check | EX Fault Check | d6Z_Gf_YBklqbeCfQCJ9-280 |
| mem.write_control | DMEM Write Control | d6Z_Gf_YBklqbeCfQCJ9-325 |
| id.id_ex_update | ID/EX Update Control | d6Z_Gf_YBklqbeCfQCJ9-388 |
| ex.ex_mem_update | EX/MEM Update Control | d6Z_Gf_YBklqbeCfQCJ9-394 |
| mem.mem_wb_update | MEM/WB Update Control | d6Z_Gf_YBklqbeCfQCJ9-399 |
| control.pipeline_hazard | Pipeline Hazard Control | d6Z_Gf_YBklqbeCfQCJ9-404 |
| if.if_id_update | IF/ID Update Control | d6Z_Gf_YBklqbeCfQCJ9-555 |
| mem.decode | MEM Decode | d6Z_Gf_YBklqbeCfQCJ9-305 |
| id.decoder | Decoder | PeWG_VKsY-f66Zm0Bl_l-300 |
| session.pipeline_empty | Pipeline Empty Logic | tp3-exec-control (interno) |
| session.execution_control | Execution Control | tp3-exec-control |

Un bloque puede tener varias representaciones gráficas y un bloque interno puede exponerse dentro del inspector de su propietario. La importación no crea puertos ni conexiones físicas por coincidencia de coordenadas o cruce de cables. Las referencias faltantes se detectan al preparar recursos y bloquean la aceptación del contenido afectado.

## Asociación de los valores observados

| Datos del snapshot | Asociación |
|--------------------|------------|
| pc | if.pc y encabezado del ciclo; no se confunde con los PCs de instrucciones en vuelo. |
| cycle_count | Encabezado del ciclo observado. |
| global_state, image_valid, fault_cause, fault_pc | Estado de sesión y contenido contextual de control; se conservan los valores originales y su vigencia. |
| registers | rf.register_file, con 32 posiciones. |
| if_id, id_ex, ex_mem, mem_wb | Sus cuatro bloques latch, con exactamente los campos del protocolo. |
| used_count y memory | mem.data_memory; solo las direcciones recibidas, incluidos bytes cero escritos. |

Cada campo del inspector se identifica por una ruta del snapshot y su ancho lógico conforme al protocolo. Los índices y códigos conservan sus números; el formato visual hexadecimal inicial, decimal o binario pertenece a cada vista. No se llena un campo con cero para representar ausencia de captura. valid y fetch_fault_valid conservan sus habilitaciones independientes.

Los campos se consultan mediante el inspector del componente seleccionado; su posición y validación se describen en Inspector de valores y validación visual.

## Participación funcional del ciclo

instruction_locations se obtiene de los registros válidos posteriores al flanco y del mapa PC–línea de la revisión ejecutada. changes compara capturas completas consecutivas de la misma sesión, sin memoria inventada. cycle_activity describe el ciclo que produjo la captura actual y utiliza el estado previo cuando está disponible.

La interpretación se implementa como función pura del core, separada de UART y del motor gráfico. Su entrada contiene contexto de sesión, imagen y mapa, captura previa disponible, captura actual e índices. Su salida conserva la estructura interpretation definida. Los contratos de etapas, controles y hazards son la fuente normativa, sin usar el texto de los ejemplos como una traza de ejecución.

Para reconocer el tipo de transición se contrastan las acciones candidatas de la tabla arquitectónica con validez, identidad de las instrucciones, PC, estado global y evolución observada. No se simula un procesador alternativo ni se publica una reconstrucción de señales combinacionales. Solo se resaltan los bloques cuya participación es justificable. Cuando varias transiciones son compatibles se conserva lo común que pueda justificarse y se marca como no disponible lo ambiguo.

| Etapa o familia | Participación que se fundamenta |
|-----------------|--------------------------------|
| IF | PC, incremento y selección, búsqueda y captura cuando la acción admite ingreso; retención o descarte se explican por sus controles. |
| ID | Decoder, fuentes realmente utilizadas, banco, bypass, inmediato y controles de actualización conforme a la instrucción y la acción. |
| EX R e I | Camino de ALU y operandos utilizados, con forwarding funcional sin afirmar la rama exacta no observada. |
| EX LUI | Selección del inmediato por Result MUX; no se atribuye una suma funcional a LUI. |
| EX branches | Comparación mediante los bloques existentes, generación de target y controles solo con la evidencia y prioridad correspondientes. |
| EX JAL y JALR | Link Adder y target; JALR incluye base reenviable, JALR Adder y Clear bit 0. |
| MEM | Decode, memoria, extensión de load o escritura de store según mem_op, validez y ciclo efectivo. |
| WB | Writeback efectivo si la entrada es válida, reg_write y rd distinto de cero; los cambios de RF se presentan por separado. |
| halt, fault y drain | Control de frontera, invalidaciones y avance del trabajo anterior conforme a la tabla normativa. Un drenado legal no incorpora instrucciones nuevas. |

El primer STEP puede utilizar las garantías lógicas de una LOAD confirmada para establecer el contexto permitido, sin mostrarlas como captura medida. Una contradicción con la observación conserva los bits recibidos y limita la inferencia. Un mismo valor antes y después no prueba ausencia de participación, y un cambio no constituye por sí solo un error.

### Catálogo de limitaciones

Se concreta el catálogo de interpretación sin alterar la envoltura de errores de operación.

| code | section | Motivo |
|------|---------|--------|
| NO_PREVIOUS_SNAPSHOT | changes | Primera captura sin comparación anterior. |
| NONCONSECUTIVE_SNAPSHOT | changes o cycle_activity | No existe continuidad de un STEP y contador compatible. |
| SOURCE_MAPPING_UNAVAILABLE | instruction_locations | PC sin correspondencia conocida en esa revisión. |
| UNSUPPORTED_INSTRUCTION | cycle_activity | La instrucción observada no se reconoce con el perfil. |
| ACTIVITY_UNDETERMINED | cycle_activity | Evidencia insuficiente para decidir la participación. |
| TRANSITION_INCONSISTENT | cycle_activity | La evolución recibida no coincide con una transición justificable del modelo. |
| PROFILE_MISMATCH | cycle_activity | No se puede vincular el perfil de interpretación con el contenido local. |

Los avisos no sustituyen snapshot, no inventan un fault de CPU ni ocultan un resultado inesperado del hardware. No se incorpora observación de señales combinacionales adicionales.

## Seguimiento de una aparición seleccionada

La selección y cámara pertenecen a GUI. La regla de continuidad permanece en el core compartido y se consulta como cálculo sin avance físico, evitando implementarla otra vez en JavaScript.

| Solicitud | Entrada | Salida |
|-----------|---------|--------|
| POST /api/v1/interpretation/follow | Credencial y trabajo solicitante; exactamente selection o follow. | FollowState en result, o error común. No requiere ser controlador de la placa. |

| Campo de selection | Contenido |
|--------------------|-----------|
| session_id | Sesión debug observada. |
| step_index | Captura completa actual sobre la que se selecciona. |
| latch | IF/ID, ID/EX, EX/MEM o MEM/WB válido. |

| Campo de FollowState | Contenido |
|----------------------|-----------|
| session_id, program_id, source_version | Contexto del ensayo. |
| origin_step_index y origin_latch | Origen seleccionado; no cambian durante el seguimiento. |
| step_index | Última captura evaluada. |
| last_latch | Última ubicación cuya continuidad quedó justificada; permite conservar el encuadre al terminar. |
| pc e instruction | Identidad observada de la aparición en origen. |
| status | following, finished o unavailable. |
| reason | null mientras continúa; retired, discarded, terminal, ambiguous o gap cuando corresponda con fundamento. |

follow contiene el FollowState previo. El core valida contexto y la captura previa disponible; sin nuevo STEP devuelve el mismo estado. Con exactamente un STEP nuevo comprueba las transiciones ya definidas: IF/ID a ID/EX o retención load-use o descarte; ID/EX a EX/MEM o consumo justificado; EX/MEM a MEM/WB; MEM/WB sale aunque el nuevo ocupante repita PC e instrucción. Se comprueba el incremento de cycle_count con wrap de 64 bits.

Una selección inicial anterior o inválida recibe INVALID_ARGUMENT. Una sesión inexistente utiliza SESSION_NOT_FOUND y RUN utiliza SESSION_MODE_MISMATCH. Si falta continuidad después de iniciar, se devuelve unavailable con motivo explícito y no se vuelve a asociar otra iteración. Una salida justificada devuelve finished. Si el mismo paso también alcanza un terminal, retired o discarded prevalecen cuando esa salida quedó justificada; terminal se usa cuando el fin de sesión impide continuar sin una salida más precisa. Una falta de continuidad no se convierte en retired por haber terminado la sesión. El cálculo no agrega identidades a todas las instrucciones ni conserva un historial de capturas en RAM; utiliza el contexto enviado y las capturas completas actual y previa que ya necesita la interpretación. Un contexto que no pueda verificarse no se acepta por coincidencia aislada de PC.

El endpoint no modifica la sesión, no incrementa state_revision ni agrega un bloque SSE de selección. La GUI solicita el cálculo para la aparición elegida al recibir otra observación, conserva su estado visual y finaliza el seguimiento ante un gap, reinicio, fin o ambigüedad. Los avisos no pausan Continuar. La cámara conserva su último encuadre.

## Adaptador gráfico y recursos locales

| Operación del adaptador | Contrato |
|------------------------|----------|
| mount(container, resources) | Crear una instancia GraphViewer sobre el XML completo y datos identificados del producto. |
| setObservation(context) | Incorporar la observación y contexto de una sola revisión coherente. |
| selectComponent(block_id) | Selección local de un componente e inspector. |
| setFocus(block_ids) | Aplicar énfasis funcional traducido por bindings, sin avanzar la CPU. |
| resize() | Adaptar el área disponible conservando el contexto visual. |
| dispose() | Retirar observadores y listeners, tooltips y recursos de la instancia; no detener la sesión. |

Se preservan tooltips, inspección, cámara y máscaras del visor, encapsulando sus referencias a graph y al DOM. No se reemplaza el dibujo por posiciones calculadas desde los datos. Cambiar de captura modifica contenido y estilos, no reconstruye el grafo completo. La instancia se mantiene mientras su vista exista y se libera al desmontar, incluso con los montajes repetidos de React en desarrollo. Los controles de FlexLayout y las vistas Monaco conservan sus adaptadores y propiedad del documento.

Todos los recursos, motor, fuentes y contenido se incluyen localmente y se identifican en release.json. Las explicaciones usan texto seguro y no ejecutan el contenido de un programa Assembly. Los enlaces educativos explícitos se abren mediante Desktop bridge. Los textos y metadatos del perfil se separan para permitir la futura traducción sin cambiar reglas ni bloques.

## Banco educativo y ejemplos ejecutables

El material existente aporta 33 entradas de instrucción y cinco etapas por entrada. Se conserva como explicación de ejemplos con sus supuestos, no como una traza universal de cualquier programa real. Las narraciones que mencionan registros o constantes del ejemplo no se presentan como si describieran otra ejecución.

Cada ejemplo ejecutable tiene example_id, title, objective, source_path, expected_observations y related_instruction_ids. La primera entrega prepara un programa completo por cada instrucción y los escenarios de interacción de la tabla siguiente; no se limita a cuatro ejemplos. Los metadatos están en español y los identificadores en inglés.

| Grupo de ejemplos | Programa y expectativa de diseño |
|-------------------|---------------------------------|
| R: add, sub, sll, slt, sltu, xor, srl, sra, or, and | Preparar x1=8 y x2=2, operar a x3 y finalizar con halt. Resultados respectivos: 10, 6, 32, 0, 0, 10, 2, 2, 10 y 0. |
| I: addi, slti, sltiu, xori, ori, andi, slli, srli, srai | Preparar x1=8, inmediato 2 y destino x3; resultados respectivos: 10, 0, 0, 10, 10, 0, 32, 2 y 2. |
| lui | lui x3, 0x12345 seguido por halt; x3 final 0x12345000. |
| lb, lbu, lh, lhu, lw | Preparar memoria con sw del valor 0x000080ff en dirección cero. Resultados: 0xffffffff, 0x000000ff, 0xffff80ff, 0x000080ff y 0x000080ff. |
| sb, sh, sw | Preparar 0x12345678 y almacenar en dirección cero. Observar respectivamente 0x78; 0x78 0x56; 0x78 0x56 0x34 0x12 como bytes little-endian. |
| beq y bne | Preparar operandos iguales o distintos para salto tomado a target, dejar una escritura de x3=9 en el camino descartado y escribir x3=7 en target; comparar también una variante no tomada. |
| jal | PC inicial cero, jal x3,target, una escritura descartada a x4 y halt en target a PC=8; x3=4 y x4=0. |
| jalr | Preparar x1=12; jalr x3,0(x1) en PC=4, escritura descartada a x4 en PC=8 y halt en PC=12; x3=8 y x4=0. |
| halt | halt como programa y otra variante con instrucciones anteriores pendientes; FINISHED tras su drenado y sin ejecutar el trabajo descartado. |
| Flujo paralelo | Varias instrucciones independientes para reconocer simultáneamente las cinco etapas. |
| Dependencias | Forwarding desde EX/MEM y MEM/WB, dos fuentes distintas y prioridad del productor más reciente sobre otro del mismo rd. |
| Load-use | lw seguido por consumidor real de rd distinto de x0; retención de IF/ID, bubble y avance del trabajo anterior. |
| Bypass y x0 | Dependencia WB a ID y variantes con rd=x0; distinguir escritura efectiva y ausencia de dependencia falsa. |
| Bucles y seguimiento | Repetición de PC, incluido beq x0,x0,0; dos apariciones del mismo PC pueden coexistir y el seguimiento no se reasigna a la nueva. |
| Casos de borde | Comparación y shift con negativos, accesos desalineados o fuera de rango, salto inválido y fetch posterior al final de imagen sin halt. Se documentan las causas conforme al contrato. |

Las expectativas son vectores de diseño, no resultados de programas ya ejecutados. Los operandos y terminación se preparan de forma que el ejemplo sea ejecutable por sí solo; las direcciones de borde se toman del perfil real, no de una capacidad supuesta. La comprobación del contenido y de cada resultado se asigna al plan de verificación.

## Mantenibilidad y revisión

| Cambio | Lugares que deben cambiar |
|--------|--------------------------|
| Mover bloques o cables sin cambiar semántica | XML y, si cambiaron sus IDs, bindings. |
| Corregir una explicación o traducirla | Contenido del idioma y sus referencias; no el protocolo ni la lógica. |
| Cambiar campos observables | Protocolo, DTO y perfil de campos; revisión de compatibilidad y verificación de decodificación. |
| Cambiar comportamiento de una instrucción o hazard | Arquitectura normativa, reglas de interpretación y ejemplos; bindings solo si cambió el dibujo. |
| Agregar una instrucción | Encoder definido, decodificación/perfil, catálogo y ejemplos; los casos de conformidad comprueban que coincidan. |

El perfil es una fuente de interpretación del contrato del TP, no un diseñador de procesadores incorporado al producto. El assembler conserva su módulo y su interfaz; la correspondencia de encodings se comprueba contra la especificación, evitando importar sus funciones privadas desde GUI.

## Inspector de valores y validación visual

La base de presentación utiliza un inspector en la parte inferior de la pestaña del diagrama, con tooltips como consulta complementaria. Su posición definitiva se valida con el diagrama completo, campos y valores representativos y el editor en split. La condición provisional de esa ubicación no modifica los datos observables ni el funcionamiento del seguimiento.

La fidelidad a Penpot, la legibilidad y los movimientos del diagrama se comprueban con los casos de verificación. El diagrama conserva su geometría; actualizar una captura modifica contenido y estilos sin reconstruir el grafo completo.
