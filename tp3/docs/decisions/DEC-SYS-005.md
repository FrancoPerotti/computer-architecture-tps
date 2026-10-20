### DEC-SYS-005 — Criterio de memoria de datos utilizada

**Contrato vigente de consulta:** [memory_architecture](../architecture/memory/memory_architecture.md), [debug_architecture](../architecture/debug/debug_architecture.md), [response_serializer](../architecture/debug/response_serializer.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Sistema / Debug / Memoria

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La consigna pide mostrar la memoria de datos utilizada. Es necesario fijar qué posiciones pertenecen a ese conjunto, cómo se representan stores parciales y ceros escritos, y cómo delimitar una lista vacía o de longitud variable.

**Opciones consideradas:** Selección por bytes escritos frente a palabras/rangos o valores distintos de cero; lista de dirección/valor actual frente a volcado completo o historial de cambios. Se seleccionaron bytes escritos y lista completa del estado actual durante la discusión de D04/D05.

**Decisión:** Son utilizados los bytes escritos por stores CPU comprometidos en la sesión actual, incluidos valores cero. `SB`/`SH`/`SW` incorporan 1/2/4 bytes al commit; lecturas y preparación no incorporan entradas. Sobrescribir actualiza el valor sin duplicar una dirección. Cada sesión nueva comienza vacía, incluido reiniciar la misma imagen desde `FINISHED`/`FAULT`.

Cada snapshot contiene la lista completa de direcciones utilizadas, únicas y crecientes, y sus valores actuales en el mismo instante coherente. No incluye huecos no escritos, historial ni deltas.

La lista se coloca al final del cuerpo con este formato:

| Elemento                            | Representación                                                                     |
|-------------------------------------|------------------------------------------------------------------------------------|
| `used_count`, antes de las entradas | Unsigned de cinco bytes little-endian, entre cero y la capacidad de DMEM inclusive |
| Dirección de cada entrada           | Cuatro bytes little-endian                                                         |
| Valor de cada entrada               | Un byte                                                                            |

Cantidad cero se representa con cinco bytes cero y ninguna entrada. La cantidad determina exactamente la longitud y el final.

El [acuerdo de criterio](#acuerdo-parcial-de-dec-sys-005--memoria-utilizada-como-bytes-escritos-en-la-sesión) y el [acuerdo de layout](../protocol.md#distribución-general) detallan selección, ejemplos, offsets y longitudes.

**Justificación:** La unidad byte representa stores parciales y conserva escrituras de cero. Dirección/valor actual evita confundir el contenido observable con historial; la cantidad de cinco bytes cubre capacidades hasta 2^32 sin un caso especial para la lista vacía.

**Consecuencias:** Pueden reutilizarse los metadatos de validez por byte de referencia; no se exige un segundo bitmap ni un contador persistente adicional. La captura, recorrido, ownership y serialización física se completan en D06 y diseño de bloques, respetando coherencia y semántica lógica de DMEM. Quedan fuera de este identificador los códigos y las reglas comunes todavía pendientes del protocolo. Esta aprobación cierra el diseño de criterio y representación; no acredita implementación.

**Requisitos afectados:** `REQ-MEM-008`, `REQ-MEM-019`, `REQ-MEM-028`, `REQ-MEM-029`, `REQ-DBG-010`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-009`, `REQ-DOC-005`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Consolida los acuerdos parciales de criterio y layout; conserva los contratos de memoria y coherencia aprobados.

---

### Acuerdo parcial de DEC-SYS-005 — Memoria utilizada como bytes escritos en la sesión

**Estado del acuerdo:** Aprobado como base de diseño. Criterio, unidad y lista lógica de D04 aprobados; `DEC-SYS-005` y D04 siguen pendientes de la representación binaria externa que se completará con D05.

**Dominio:** Debug / Selección y representación lógica de DMEM utilizada.

**Fecha de aprobación:** 2026-10-01.

**Contexto:** La lista DMEM representa bytes escritos durante la sesión actual y su valor presente. Una escritura de cero también marca el byte como utilizado.

**Decisión:** El conjunto de memoria utilizada reúne las direcciones de los bytes escritos efectivamente por stores de CPU en la sesión actual. Se incorpora un byte al comprometerse el store, con la misma condición `dmem_store_fire` y selección de bytes ya definidas para DMEM; detectar/decodificar una instrucción store no basta.

- `SB` incorpora su único byte, `SH` sus dos bytes y `SW` sus cuatro bytes consecutivos, conforme a dirección y lanes validados.
- Escribir el valor cero incorpora el byte igual que cualquier otro valor.
- Leer una posición no la incorpora. Inicialización y mantenimiento de `Session Preparation` tampoco cuentan como stores del programa.
- Una nueva escritura conserva la pertenencia del byte y actualiza su valor; cada dirección aparece una sola vez en el snapshot.
- Cada sesión nueva comienza con el conjunto vacío, incluido el reinicio de ejecución de la misma imagen después de `FINISHED`/`FAULT`.

Cada snapshot contiene una lista en orden creciente de dirección, con un par lógico `(dirección del byte, valor actual de 8 bits)` por posición utilizada. El valor es el correspondiente al instante coherente de ese snapshot; no es un historial ni solo los cambios desde el paso anterior. Sin stores comprometidos, la lista está vacía. El layout, anchos externos de dirección/cantidad y representación binaria de la lista vacía se completarán en D05.

Las direcciones pertenecen a DMEM base cero y capacidad del perfil activo. Los valores respetan la semántica de memoria de la sesión, sin exponer residuos de una sesión anterior. No se incluyen huecos no escritos entre direcciones utilizadas ni se exige transmitir toda la capacidad.

Ejemplo: después de escribir 7 en el byte 0x10 y 0 en 0x20, el snapshot contiene `(0x10, 7)` y `(0x20, 0)`. Sobrescribir 0x10 con 9 produce posteriormente `(0x10, 9)` y `(0x20, 0)`. Leer 0x30 no agrega una entrada.

**Justificación:** El criterio por byte coincide con las escrituras y el cero lógico de la arquitectura, representa correctamente stores parciales y mantiene observables las escrituras de cero. Los metadatos de validez por byte de referencia pueden reutilizarse para seleccionar la lista; el criterio externo se fija por este acuerdo y no por la mera existencia de un bitmap físico.

**Consecuencias y alcance pendiente:** Se aprueban criterio, granularidad, orden y contenido lógico de D04. Se continúa con D05 y se completa allí la cantidad/longitud y representación binaria de la lista, incluida la vacía, antes de cerrar D04 y `DEC-SYS-005`. Ownership, recorrido/captura y serialización se concretarán en D06 y el diseño de bloques, sin imponer un segundo bitmap ni un contador persistente nuevo. No se inicia implementación.

**Requisitos afectados:** `REQ-MEM-008`, `REQ-MEM-019`, `REQ-MEM-028`, `REQ-MEM-029`, `REQ-DBG-010`, `REQ-DBG-012`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-SW-009`, `REQ-DOC-005`, `REQ-DOC-006`.

**Reemplaza / Reemplazada por:** Selecciona posiciones escritas, unidad byte y lista dirección/valor, conservando la representación binaria externa pendiente y los contratos de memoria/coherencia existentes.
