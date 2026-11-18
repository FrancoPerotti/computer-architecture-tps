# Manifiesto de bitstreams para las pruebas de la issue 38

Los tres archivos permanecen en sus directorios originales, ignorados por Git.
No se ha realizado la validación física de estas tres implementaciones.
Las rutas son relativas a `tp3`; cada directorio conserva `build-info.txt`,
el proyecto y `reports/` de la misma corrida.

| Solicitada / efectiva | Bitstream | SHA-256 | Timing ruteado |
| --- | --- | --- | --- |
| 50 / 50 MHz | `build/issue-38/ensayo-01/50/tp3-reference.bit` | `CBBCDE423194B14AD20C036E9102BC9EC581C0064352D682C1D62348D4DF8106` | Cumple; WNS +1,065 ns, WHS +0,037 ns |
| 55 / 55 MHz | `build/issue-38/ensayo-03/55/tp3-reference.bit` | `025893CB5DDBF0008EF777A18570DE4409B63C46B8F533683C7EE82DF3C77AD7` | Cumple; WNS +0,549 ns, WHS +0,061 ns |
| 60 / 60 MHz | `build/issue-38/ensayo-03/60/tp3-reference.bit` | `1505D1FEC56D8318461C70F3510C73B6B72AC3BF9E5C5DC105FCC702791D8A1F` | Cumple; WNS +0,367 ns, WHS +0,024 ns |

Las tres corridas usaron Vivado 2026.1, SW build 6511674, part
`xc7a35tcpg236-1`, perfil REFERENCE y commit base
`c5ef2cfb63ac928f539301c7d8c91fae27ea4641`, con cambios locales. El
`build-info.txt` de cada corrida identifica las fuentes y registra el estado
Git y los SHA-256 individuales. Se contrastaron contra el árbol actual las
48 entradas de RTL y restricciones de cada manifiesto: antes de la revisión
Docker coincidían. Posteriormente se formatearon `basys3_top.sv`,
`system_top.sv` y `protocol_controller.sv` y se corrigió en este último el
ancho de una comparación del temporizador. Sus hashes actuales difieren de
los tres builds físicos: **estos bitstreams deben considerarse de la revisión
anterior a esa corrección**, no evidencia de implementación del RTL actual.
Los scripts también cambiaron después de producirlos; los hashes históricos
figuran en cada manifiesto. El commit base por sí solo no identifica los
contenidos no commiteados con los que se generaron los archivos.

El SHA-256 de cada `.bit` se verificó nuevamente contra su manifiesto. No se
copiaron ni renombraron los archivos. Ver [issue-38.md](issue-38.md) para los
reportes de timing y el procedimiento pendiente de placa.
