# openFPGALoader incluido

La construcción Linux genera aquí openFPGALoader 1.2.0, las bibliotecas que utiliza, licencias, el archivo fuente y un inventario de hashes. Ejecutar `software/packaging/build_programmer_linux.sh` desde `tp3`.

La receta y los 76 paquetes de herramientas/dependencias se fijan en `packaging/programmer-linux.lock.json`. Se utiliza la imagen Ubuntu 24.04 aprobada con rootfs de solo lectura; los paquetes se extraen dentro de `software/build`. No se instala un programador del sistema ni se modifica su PATH persistente.

Windows requiere un binario nativo con dependencias ajenas al sistema enlazadas estáticamente. Su construcción y comprobación siguen pendientes; el paquete no acepta un bundle Linux como sustituto Windows.
