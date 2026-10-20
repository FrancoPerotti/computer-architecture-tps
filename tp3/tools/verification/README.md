# Modelos abstractos de protocolo

Desde el directorio `tp3`, con Python 3.10 o posterior y sin dependencias adicionales:

```sh
python3 -B tools/verification/check_models.py
```

La salida debe terminar en `OK`; un fallo devuelve un código distinto de cero.

- `controller_model.py` representa las 11 fases del [Controller](../../docs/architecture/debug/protocol_controller.md), la coordinación Global y las fronteras de Loader y serializador. Los estímulos recorren las 14 fases Global y ambos perfiles, definidos en `PROFILES`.
- `pc_recovery_model.py` representa la [recuperación fuera de LOAD](../../docs/protocol.md#perder-una-respuesta-o-conexión), con reloj virtual en milisegundos, silencio continuo y un único RESET.
- `check_models.py` contiene los estímulos y expectativas, reutiliza entradas de [cases.json](../../docs/verification/cases.json) y comprueba prioridades, cierres con/sin Debug, reset, fragmentación y los cruces PC–FPGA. También recalcula las cotas de TEST-UART-014 y las contrasta con los plazos para todos los tamaños LOAD y cantidades K legales de ambos perfiles. No agrega variantes al catálogo.

`CatalogChecks` comprueba IDs, conteos, reutilizaciones y referencias del manifiesto, incluidas las fuentes, requisitos y contratos de cada grupo según la [convención de trazabilidad](../../docs/verification/verification_plan.md#identificación-de-especificaciones-y-variantes). Esa comprobación documental no ejecuta los casos del catálogo.

Se inyectan confirmaciones CPU, vacío de pipeline, fin de preparación y último Stop de respuesta. Los límites del contador FPGA se precargan; las ventanas PC avanzan con tiempo virtual. Algunos contextos son fixtures locales y no demuestran alcanzabilidad por UART físico.

Estos modelos comprueban los contratos abstractos. No ejecutan instrucciones ni serializan el cuerpo Debug; no verifican RTL, tramas 8N1, delays, timing, placa ni una implementación del cliente PC.
