# Bitstream pendiente

El usuario confirmó que todavía no existe un bitstream aprobado de TP3. No se incluye un archivo de prueba en el producto.

Cuando el grupo lo genere, registrar su SHA-256 y revisión completa de RTL e incorporarlo desde `tp3`:

```sh
software/.venv/bin/python software/packaging/import_bitstream.py /ruta/real/processor.bit --source-revision SHA_GIT_COMPLETO --expected-sha256 SHA256_REGISTRADO
```

La importación verifica la huella y conserva `processor.bit` y `processor.json`, ligados al perfil de recursos. El descriptor documenta procedencia; la correspondencia física con Basys 3 se acepta en #17. La aplicación no sintetiza RTL ni genera ese archivo.

La construcción del paquete de hardware exige ambos recursos válidos. La ejecución de desarrollo permite informar su ausencia y verificar los demás flujos; no acredita una placa preparada.
