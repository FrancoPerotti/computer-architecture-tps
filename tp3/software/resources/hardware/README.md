# Bitstream REFERENCE de Basys 3

La aceptación en Basys 3 de la #17 utilizó el bitstream REFERENCE construido desde la revisión RTL `d2ef373194b396f5a4367af22fe7e243ada5d49e`. Su SHA-256 es `660ae6ed81c864ebc30790af1184fdad2421da535bdc9f26e5f22648520e33af`.

El archivo `vivado/tp3-reference.bit` está dentro de `tp3-issue-17-evidencia.zip`, publicado en la [release de evidencia](https://github.com/FrancoPerotti/computer-architecture-tps/releases/tag/tp3-17-evidencia). Para incorporarlo a un checkout, extraer ese archivo y ejecutar desde `tp3`:

```sh
software/.venv/bin/python software/packaging/import_bitstream.py /ruta/extraida/tp3-reference.bit --source-revision d2ef373194b396f5a4367af22fe7e243ada5d49e --expected-sha256 660ae6ed81c864ebc30790af1184fdad2421da535bdc9f26e5f22648520e33af
```

La importación verifica la huella y conserva `processor.bit` y `processor.json`, ligados al perfil de recursos. El descriptor documenta la procedencia. El [informe de aceptación](../../../docs/verification/board_acceptance.md) conserva los resultados físicos de la #17.

La construcción del paquete de hardware exige ambos recursos válidos. La ejecución de desarrollo permite informar su ausencia y verificar los demás flujos; no acredita una placa preparada.
