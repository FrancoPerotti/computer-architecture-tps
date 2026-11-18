viewrv para Linux x86-64

Extraé el archivo .tar.gz completo en una carpeta de tu usuario.

Para abrir la aplicación desde esa carpeta, ejecutá

    ./viewrv-gui

Para agregar viewrv al menú de aplicaciones, ejecutá

    ./install.sh

La instalación queda en ~/.local/opt/viewrv. El acceso del menú se llama
viewrv. También se agrega la CLI en ~/.local/bin/viewrv.

Podés explorar el diagrama, abrir ejemplos y ensamblar programas desde la
aplicación. Para cargar y depurar instrucciones, conectá una Basys 3 por USB
y abrí Ver > Conexión con la placa. Allí elegí Preparar Basys 3.

La guía local de conexión está en resources/content/hardware-guide.html.
Consultala si tu distribución requiere permisos USB o de puerto serie.

Para actualizar, cerrá la aplicación y finalizá los trabajos de la CLI con
viewrv work finish. Extraé el nuevo paquete y ejecutá su ./install.sh.
Se conservan tus programas, preferencias y registros.

Para desinstalar, cerrá la aplicación, finalizá los trabajos de la CLI y ejecutá

    ~/.local/opt/viewrv/uninstall.sh

La desinstalación conserva tus datos de usuario.

Los avisos de terceros y sus fuentes están en resources/licenses/index.html
y también se pueden abrir desde Ayuda > Avisos y licencias.

La compatibilidad comprobada para cada versión se indica en sus notas de
publicación en https://github.com/FrancoPerotti/computer-architecture-tps/releases
