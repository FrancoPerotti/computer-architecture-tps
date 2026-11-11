# Verification case files

El índice [cases.json](../cases.json) conserva los metadatos y el fixture de
latches compartido. Sus entradas `groups` apuntan a un archivo por grupo, con
nombres en inglés. Ese archivo contiene los bancos, las relaciones y los casos
del grupo. Los grupos grandes apuntan además a listas pequeñas de casos.

```text
cases.json
cases/
  isa/arithmetic-and-logic.json
  pipeline/forwarding.json
  execution/program-reuse.json
  execution/program-reuse/cases-001-001.json
```

El índice tiene 387 líneas. En esta reorganización hay 66 archivos de grupo y
103 listas de casos; el archivo de datos más largo tiene 1567 líneas. Se
conservan los 66 grupos, 1484 casos y sus valores, estados, relaciones y orden.
No se genera ni se versiona otra copia completa del catálogo.

## Cómo localizar y editar una prueba

1. Buscar su grupo en la tabla de abajo y abrir el archivo correspondiente.
2. Si `cases` contiene referencias `file`, abrir la lista cuyo rango incluya el
   ID buscado. Los rangos describen el primer y último ID de la lista; los casos
   originales con numeración discontinua conservan sus IDs.
3. Editar las entradas o expectativas del caso. Para agregar un caso o grupo,
   actualizar también sus referencias y `case_count`.
4. Ejecutar `make validate` y las pruebas afectadas. La regresión completa sigue
   siendo `make check`, desde el entorno Docker del proyecto.

## Referencias de archivos

Una entrada de grupo del índice tiene esta forma:

```json
{"file": "cases/execution/program-reuse.json"}
```

Una entrada de `cases` en ese grupo puede contener una lista externa:

```json
{"file": "program-reuse/cases-001-001.json"}
```

Cada referencia se resuelve desde el archivo que la contiene. El archivo de
grupo contiene un objeto; el de casos, un array de casos completos. También se
admiten grupos y casos inline, como en los fixtures temporales del ejecutor.
Solo se interpretan referencias en `groups` y `cases`; un campo `file` dentro
de `inputs` o `expected` sigue siendo un dato de la prueba. Las referencias no
aplican herencia, mezclas ni valores predeterminados.

Las rutas `source` de los grupos mantienen su base en `docs/verification/`, y
las rutas `executions.sources` mantienen su base en `tp3/`. No se reinterpretan
al mover los datos. Los archivos JSON referenciados deben permanecer dentro
del directorio que contiene el índice. Los archivos ausentes, los ciclos, las
claves duplicadas y los documentos del tipo incorrecto producen un error.

El [cargador común](../../../scripts/verification_manifest.py) proporciona
`read_manifest()` para obtener el catálogo resuelto con biblioteca estándar,
`load_manifest()` para agregar validación de esquema y coherencia, y
`manifest_sources()` para enumerar sus archivos. Los consumidores deben usar
ese acceso para trabajar con grupos y casos. `json.load(cases.json)` obtiene
únicamente el índice. La CLI y sus selectores conservan su uso anterior.

El preparador protege todos los archivos del catálogo frente a `--output`.
El documento completo usado para validar el esquema es temporal y se elimina
al terminar la validación.

## Grupos

| ID | Archivo del grupo | Casos canónicos |
| --- | --- | ---: |
| `TEST-ISA-001` | [arithmetic-and-logic](isa/arithmetic-and-logic.json) | 20 |
| `TEST-ISA-002` | [shifts-and-comparisons](isa/shifts-and-comparisons.json) | 37 |
| `TEST-ISA-003` | [immediates-and-lui](isa/immediates-and-lui.json) | 24 |
| `TEST-ISA-004` | [decoder-whitelist](isa/decoder-whitelist.json) | 409 |
| `TEST-ISA-005` | [conditional-branches](isa/conditional-branches.json) | 8 |
| `TEST-ISA-006` | [jump-and-link](isa/jump-and-link.json) | 10 |
| `TEST-ISA-007` | [loads-and-stores](isa/loads-and-stores.json) | 22 |
| `TEST-ISA-008` | [invalid-flow-targets](isa/invalid-flow-targets.json) | 7 |
| `TEST-PIPE-001` | [pipeline-fill](pipeline/pipeline-fill.json) | 1 |
| `TEST-PIPE-002` | [register-file-and-bypass](pipeline/register-file-and-bypass.json) | 52 |
| `TEST-PIPE-003` | [forwarding](pipeline/forwarding.json) | 29 |
| `TEST-PIPE-004` | [forwarding-priority](pipeline/forwarding-priority.json) | 3 |
| `TEST-PIPE-005` | [load-use-stalls](pipeline/load-use-stalls.json) | 9 |
| `TEST-PIPE-006` | [operand-usage](pipeline/operand-usage.json) | 10 |
| `TEST-PIPE-007` | [pipeline-actions](pipeline/pipeline-actions.json) | 21 |
| `TEST-PIPE-008` | [wrong-path-boundaries](pipeline/wrong-path-boundaries.json) | 9 |
| `TEST-PIPE-009` | [writeback-and-hold](pipeline/writeback-and-hold.json) | 11 |
| `TEST-PIPE-010` | [fetch-and-load-use](pipeline/fetch-and-load-use.json) | 20 |
| `TEST-PIPE-011` | [load-use-detector](pipeline/load-use-detector.json) | 25 |
| `TEST-PIPE-012` | [decode-stage](pipeline/decode-stage.json) | 14 |
| `TEST-PIPE-013` | [fetch-stage](pipeline/fetch-stage.json) | 15 |
| `TEST-PIPE-014` | [if-id-register](pipeline/if-id-register.json) | 10 |
| `TEST-PIPE-015` | [id-ex-register](pipeline/id-ex-register.json) | 7 |
| `TEST-PIPE-016` | [ex-mem-register](pipeline/ex-mem-register.json) | 7 |
| `TEST-PIPE-017` | [mem-wb-register](pipeline/mem-wb-register.json) | 6 |
| `TEST-MEM-001` | [store-lanes](memory/store-lanes.json) | 18 |
| `TEST-MEM-002` | [load-extension](memory/load-extension.json) | 25 |
| `TEST-MEM-003` | [access-bounds](memory/access-bounds.json) | 78 |
| `TEST-MEM-004` | [instruction-fetch](memory/instruction-fetch.json) | 23 |
| `TEST-MEM-005` | [memory-timing](memory/memory-timing.json) | 3 |
| `TEST-MEM-006` | [memory-ownership](memory/memory-ownership.json) | 10 |
| `TEST-MEM-007` | [program-loader](memory/program-loader.json) | 9 |
| `TEST-MEM-008` | [image-replacement](memory/image-replacement.json) | 7 |
| `TEST-MEM-009` | [fetch-boundary-arithmetic](memory/fetch-boundary-arithmetic.json) | 18 |
| `TEST-MEM-010` | [instruction-memory](memory/instruction-memory.json) | 9 |
| `TEST-EXEC-001` | [command-arbitration](execution/command-arbitration.json) | 153 |
| `TEST-EXEC-002` | [session-preparation](execution/session-preparation.json) | 11 |
| `TEST-EXEC-003` | [run-step-and-hold](execution/run-step-and-hold.json) | 4 |
| `TEST-EXEC-004` | [precise-faults](execution/precise-faults.json) | 11 |
| `TEST-EXEC-005` | [halt-and-drain](execution/halt-and-drain.json) | 4 |
| `TEST-EXEC-006` | [drain-mode-transitions](execution/drain-mode-transitions.json) | 7 |
| `TEST-EXEC-007` | [program-reuse](execution/program-reuse.json) | 4 |
| `TEST-EXEC-008` | [nonterminating-programs](execution/nonterminating-programs.json) | 4 |
| `TEST-EXEC-009` | [cycle-counter](execution/cycle-counter.json) | 5 |
| `TEST-EXEC-010` | [reset-priority](execution/reset-priority.json) | 9 |
| `TEST-EXEC-011` | [decode-fault-check](execution/decode-fault-check.json) | 10 |
| `TEST-UART-001` | [serial-timing](uart/serial-timing.json) | 31 |
| `TEST-UART-002` | [receive-fifo](uart/receive-fifo.json) | 21 |
| `TEST-UART-003` | [binary-commands](uart/binary-commands.json) | 44 |
| `TEST-UART-004` | [program-transfer](uart/program-transfer.json) | 18 |
| `TEST-UART-005` | [load-timeout](uart/load-timeout.json) | 24 |
| `TEST-UART-006` | [silence-recovery](uart/silence-recovery.json) | 8 |
| `TEST-UART-007` | [fixed-snapshot](uart/fixed-snapshot.json) | 7 |
| `TEST-UART-008` | [used-memory-list](uart/used-memory-list.json) | 10 |
| `TEST-UART-009` | [transmit-backpressure](uart/transmit-backpressure.json) | 9 |
| `TEST-UART-010` | [execution-commands](uart/execution-commands.json) | 5 |
| `TEST-UART-011` | [debug-exclusion](uart/debug-exclusion.json) | 31 |
| `TEST-UART-012` | [response-order](uart/response-order.json) | 14 |
| `TEST-UART-013` | [reset-sequencing](uart/reset-sequencing.json) | 16 |
| `TEST-UART-014` | [link-budgets](uart/link-budgets.json) | 10 |
| `TEST-PLAT-001` | [memory-capacities](platform/memory-capacities.json) | 15 |
| `TEST-PLAT-002` | [clock-and-reset](platform/clock-and-reset.json) | 10 |
| `TEST-PLAT-003` | [rtl-composition](platform/rtl-composition.json) | 1 |
| `TEST-PLAT-004` | [implementation-timing](platform/implementation-timing.json) | 1 |
| `TEST-PLAT-005` | [board-acceptance](platform/board-acceptance.json) | 0 |
| `TEST-PLAT-006` | [documentation-review](platform/documentation-review.json) | 1 |
