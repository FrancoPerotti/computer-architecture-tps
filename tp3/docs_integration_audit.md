# Auditoría final de integración documental — TP3

Fecha: 2026-09-30. Alcance: los catorce documentos de `docs/architecture`, los README del TP3 y del repositorio, y el contraste con decisiones, pendientes, requisitos, plan y auditorías anteriores. Las ubicaciones y citas de los hallazgos corresponden al estado anterior a las correcciones; las secciones permiten encontrarlas después de los cambios.

## Resultado de la fase 1

La arquitectura textual consolidada conserva los contratos CPU aprobados. Los defectos encontrados afectan diagramas, distribución de responsabilidades, referencias y precisión de algunas explicaciones. No requieren modificar arquitectura, ISA, FSM, hazards, forwarding, memoria, faults o Debug. No se encontró una contradicción funcional sin respaldo suficiente para resolverla documentalmente.

La inspección inicial no modificó archivos del proyecto. Se conservó una copia y un inventario SHA-256 en `/tmp/tp3-integration-audit/before` para contrastar la aplicación. El árbol ya contenía cambios del usuario: README raíz modificado y `tp3/` y `docs/` sin seguimiento de Git.

| Categoría | Hallazgos |
|---|---|
| A. Contradicciones funcionales | INT-002, INT-003 y la ambigüedad temporal INT-013 |
| B. Información obsoleta | INT-004, INT-011 |
| C. Duplicación problemática | INT-005, INT-006, INT-007 |
| D. Responsabilidad incorrecta | INT-003, INT-004, INT-012 |
| E. Terminología inconsistente | INT-008, INT-013 |
| F. Enlaces y referencias | INT-001, INT-004, INT-011, INT-012 |
| G. Diagramas | INT-002, INT-003, INT-009, INT-010 |
| H. Pendientes presentados como cerrados | Ninguno en la arquitectura consolidada; se verificaron los ocho pendientes existentes. |
| I. Cerrados presentados como pendientes | Ninguno en la arquitectura consolidada; INT-011 corresponde al estado histórico de una auditoría, no a un ADR CPU abierto. |

### INT-001 — Referencias a nombres de etapas inexistentes

- Severidad: alta. Categoría: F.
- Archivos: `datapath.md`, `control_and_hazards.md`, `faults_and_termination.md`, `memory_architecture.md` y las cinco etapas.
- Secciones: trazabilidad y enlaces del cuerpo; inventario inicial: 52 enlaces Markdown rotos.
- Problema y evidencia: `[Etapa EX](ex_stage.md)` aparece, por ejemplo, en `stage_if.md`, «Next PC MUX», pero el archivo real es `stage_ex.md`. El mismo intercambio de palabras afecta IF, ID, MEM y WB.
- Fuente de verdad: inventario de archivos vigentes `docs/architecture/stage_*.md`.
- Corrección propuesta: corregir destinos; conservar los nombres de archivos vigentes.

### INT-002 — Forward MUX A conectado al selector de B

- Severidad: alta. Categorías: A, G.
- Archivo y sección: `stage_ex.md`, «Organización general», diagrama inicial.
- Problema y evidencia: el diagrama contiene `MA --> AS` y `MA --> ALU`. El texto de «ALUSrc MUX» establece que B selecciona exclusivamente inmediato o `rs2_effective`, mientras A es `rs1_effective`.
- Fuente de verdad: el propio camino textual de EX; `datapath.md`, «Selección de operandos para la ALU»; DEC-ARCH-003, acuerdos 15 y 34.
- Corrección propuesta: eliminar `MA --> AS`, conservar A→ALU y B→selector→ALU, y mostrar inmediato/selector como entradas distintas.

### INT-003 — Selección de subword sin posición de byte explícita

- Severidad: alta. Categorías: A, D, G.
- Archivo y secciones: `stage_mem.md`, «Organización general», «Loads», «Data Memory» y «Load Select / Extend»; `datapath.md`, vista general y «Loads».
- Problema y evidencia: MEM solo lista `mem_read_data`, `access_size` y `load_unsigned` como entradas del selector; extrae siempre `[7:0]` o `[15:0]` y afirma: «La selección de bytes correspondiente a la dirección ya forma parte del acceso de DMEM». No define cómo esa interfaz entrega una subword desplazada. `memory_architecture.md`, «Organización little-endian», distingue lanes por `byte_address_i[1:0]` y exige reconstrucción de los bytes dirigidos. El datapath conecta DMEM directamente al WB Value MUX sin mostrar selección/extensión.
- Fuente de verdad: DEC-ARCH-001, «Endianness y selección de bytes»; DEC-ARCH-003, acuerdo 10; DEC-ARCH-006. Fijan selección/ensamblado/extensión en MEM y valores lógicos, sin imponer interfaz física de RAM.
- Corrección propuesta: explicitar como camino conceptual lectura lógica + bits bajos de dirección + tamaño + signo → selección/ensamblado/extensión → `load_value`. Describir bytes por su dirección y presentar la selección por lanes sin imponer un empaquetado físico nuevo para `mem_read_data`. Eliminar la atribución exclusiva e injustificada a DMEM.

### INT-004 — Decodificación remitida a un documento que ya no la contiene

- Severidad: media. Categorías: B, D, F.
- Archivos: `system_overview.md`, `cpu_pipeline.md`, `stage_id.md`, `stage_ex.md`, `stage_if.md`, `stage_mem.md`, `faults_and_termination.md`.
- Secciones: ISA, Decoder, ALU y trazabilidad.
- Problema y evidencia: `stage_id.md` afirma «La whitelist completa, los códigos de control y la correspondencia instrucción por instrucción se detallan en [Datapath y decodificación]». `datapath.md` se titula «Datapath» y excluye expresamente generación de control. Tampoco contiene esa whitelist ni códigos de ALU. La información aprobada existe en DEC-ARCH-003, acuerdos 34 y 37.
- Fuente de verdad: separación vigente del datapath; DEC-ARCH-003, acuerdos 34, 37 y 38; DEC-ARCH-004.
- Corrección propuesta: consolidar las tablas ya aprobadas de codificación y generación de control en la sección Decoder de `stage_id.md`; dirigir allí las referencias de política de decode. Reservar el nombre «Datapath» para recorridos de datos.

### INT-005 — Política de hazards y actualización repetida en las etapas

- Severidad: media. Categoría: C.
- Archivos: `stage_if.md`, `stage_id.md`, `stage_ex.md`, `stage_mem.md` y `control_and_hazards.md`.
- Secciones: Update Control; WB Bypass Control; Load-Use Detector; Forwarding Unit.
- Problema y evidencia: las ecuaciones completas de forwarding de EX y load-use de ID repiten las del control; las cuatro etapas vuelven a enumerar las ocho acciones y sus ecuaciones de actualización.
- Fuente de verdad: `control_and_hazards.md`, identificación/selección de productores, load-use, controles locales y ocho acciones; DEC-ARCH-003, acuerdos 32, 39 y 47.
- Corrección propuesta: conservar en las etapas propósito, entradas/salidas y explicación local; enlazar predicados y actualización al control. La captura durante drain sigue siendo la contractual, sin sustituirla por una simplificación.

### INT-006 — Confirmaciones, commits y vaciado con varias fuentes de verdad

- Severidad: media. Categoría: C.
- Archivos: `control_and_hazards.md`, `faults_and_termination.md`, `stage_id.md`, `stage_mem.md`, `stage_wb.md`, `memory_architecture.md`, `architectural_invariants.md`.
- Secciones: Confirmaciones, efectos anteriores, WB Bypass Control, stores, pipeline vacío e invariantes.
- Problema y evidencia: `rf_write_fire` se define dos veces dentro del control y también en ID, WB e invariantes; `dmem_store_fire` aparece dos veces en MEM, además de memoria/control; faults y control repiten confirmaciones completas; faults y sesión repiten el vaciado posterior.
- Fuente de verdad: faults para candidaturas/confirmación; control para selección de acciones y bypass; WB para el commit RF; MEM para el commit store; sesión para uso de `pipeline_empty_next`. DEC-ARCH-003, acuerdos 43, 44 y 47.
- Corrección propuesta: mantener cada predicado completo una vez en su documento responsable y referenciarlo desde los demás. Mantener visibles los commits anteriores supervivientes y los criterios verificables de invariantes.

### INT-007 — Esquemas completos de latches duplicados

- Severidad: media. Categoría: C.
- Archivos: `cpu_pipeline.md` y las etapas IF, ID, EX y MEM.
- Secciones: Registro IF/ID, ID/EX, EX/MEM y MEM/WB; Campos.
- Problema y evidencia: las mismas listas de campos y anchos tienen dos presentaciones con carácter de contrato completo.
- Fuente de verdad: `cpu_pipeline.md`, cuatro tablas de registros; DEC-ARCH-003, acuerdos 11–14, 29, 33–35 y 47.
- Corrección propuesta: conservar las tablas completas en pipeline y enlazarlas desde las etapas, que mantienen la distribución local de entradas/salidas. Los datos resumidos del datapath y la interfaz consumida en WB sirven como explicaciones, sin añadir campos.

### INT-008 — Alias de operandos y nombres de bloques sin correspondencia explícita

- Severidad: baja. Categoría: E.
- Archivos: `datapath.md`, `stage_id.md`, `stage_ex.md` y referencias a datapath.
- Secciones: lectura RF, bypass, ID/EX y selector de ALU.
- Problema y evidencia: datapath usa `rs1_rf`/`rs1_base`, mientras ID y el contrato registrado usan `rf_rs1_value`/`rs1_value`; EX denomina «ALUSrc MUX» al «ALU Source MUX» del datapath; ID usa «Registers» para el Register File. Los rótulos «Datapath y decodificación» conservan un alcance anterior.
- Fuente de verdad: campos aprobados `ID/EX.rsN_value`; nombres consolidados Register File y ALU Source MUX.
- Corrección propuesta: unificar rótulos y valores base, manteniendo `rsN_effective` para la salida de forwarding. No renombrar campos aprobados.

### INT-009 — Targets y link mezclados en el diagrama de datos

- Severidad: media. Categoría: G.
- Archivo y sección: `datapath.md`, «Vista general del recorrido de datos».
- Problema y evidencia: un nodo único «Target / Link paths» alimenta Result path; no diferencia el target que llega al PC del link que llega a `ex_result`. Tampoco se dibuja el dato MEM/WB→bypass de ID.
- Fuente de verdad: `datapath.md`, «Caminos auxiliares de EX» y «JAL y JALR»; DEC-ARCH-003, acuerdos 25–27 y DEC-ARCH-007.
- Corrección propuesta: separar target relativo, JALR y link; llevar únicamente link al resultado; mostrar el retorno de target al camino de PC y el dato WB al bypass. Los selectores son entradas de datos; no se incorpora su arbitraje al datapath.

### INT-010 — Diagrama global ambiguo respecto del orden combinacional

- Severidad: media. Categoría: G.
- Archivo y sección: `execution_control.md`, «Por qué hace falta un control global».
- Problema y evidencia: las flechas FSM→autorización→CPU→hazards→CPU no distinguen estado actual de salida `next`, aunque el texto e I20 prohíben que `next_state` realimente el ciclo actual.
- Fuente de verdad: DEC-ARCH-003, acuerdo 44; `execution_control.md`, autorización; I20 y grafo de dependencias.
- Corrección propuesta: identificar `global_state` registrado actual, cálculo de próximo estado y señales hacia autorización/hazards/`valid_next`; dejar el cierre secuencial explícito en el flanco.

### INT-011 — Auditorías anteriores sin aviso actualizado de vigencia

- Severidad: media. Categorías: B, F.
- Archivos: `docs_audit.md`, `docs_audit_v2.md`.
- Secciones: encabezado, cierre AUD-003, referencias gráficas y conclusión AUD2-002.
- Problema y evidencia: la primera auditoría enlaza TeX/SVG retirados y los presenta como referencia siguiente; la segunda ya explica la migración a draw.io, pero termina declarando abierto AUD2-002. El estado actual de REQ-HAZ-004, plan de drain e I21 ya distingue cobertura legal y artificial.
- Fuente de verdad: árbol actual, `requirements.md` REQ-HAZ-004; `plan.md`, verificación de memoria/drain; `architectural_invariants.md`, I21; aclaración histórica AUD2-001.
- Corrección propuesta: añadir avisos fechados de alcance histórico y estado actual; convertir enlaces a archivos retirados en rutas históricas sin enlace. Conservar íntegra la evidencia de cada revisión. No restaurar figuras ni certificar el draw.io externo ausente.

### INT-012 — README sin mapa documental

- Severidad: media. Categorías: D, F.
- Archivos: `tp3/README.md`, `README.md` raíz.
- Problema y evidencia: el README del TP3 contiene solo título y descripción; la tabla raíz muestra «En desarrollo» sin acceso al mapa. No asignan responsabilidades ni orden de lectura.
- Fuente de verdad: documentos consolidados existentes y alcance solicitado.
- Corrección propuesta: mapa de los catorce documentos, responsabilidades, orden de lectura, fuentes de trazabilidad e informes de auditoría; describir sesión/RUN/STEP/preparación/drain/terminales y distinguir datapath de control. Enlazarlo desde la raíz.

### INT-013 — Momento de entrada del consumidor después del stall

- Severidad: media. Categorías: A, E.
- Archivo y sección: `control_and_hazards.md`, «Efecto del stall».
- Problema y evidencia: «En el avance siguiente, el consumidor puede entrar a EX cuando el resultado del load ya alcanza MEM/WB» puede interpretarse como consumo del dato recién capturado en ese mismo flanco. ID describe correctamente primero la captura ID/EX y luego el consumo EX del MEM/WB preflanco.
- Fuente de verdad: capturas preflanco de `cpu_pipeline.md`; DEC-ARCH-003, acuerdos 10, 39 y 47.
- Corrección propuesta: explicar que el avance posterior al stall captura al consumidor en ID/EX y al resultado del load en MEM/WB; durante el ciclo posterior, EX consume el productor registrado. No introducir un segundo stall.

## Contratos contrastados

| Contrato | Evidencia de arquitectura vigente | Respaldo aprobado |
|---|---|---|
| Cinco etapas, cuatro latches, residuos inválidos sin efectos | Pipeline y cuatro tablas; I01 | ARCH-003, 11–14, 29, 33–35, 47 |
| Plano de datos separado del control | Datapath; acciones en control; sesión en ejecución | ARCH-003, 34, 43, 44, 47 |
| Prioridad EX fault > halt > redirect > ID fault > load-use > normal; ocho acciones onehot0 | Control, selección y tabla completa; I11–I13 | ARCH-003, 47 |
| EX/MEM > MEM/WB > base; bloqueo mediante exmem_match | Control, identificación/selección de productores; I14–I15 | ARCH-003, 32, 38, 39 |
| Load-use de un ciclo efectivo, ambas fuentes store, STEP consumido, sin DMEM→EX | Control, load-use; ID; MEM; sesión | ARCH-003, 3A/3B, 9, 10, 39, 44 |
| Siete causas, candidato IF→ID, prioridad por edad y misalignment en un mismo acceso | Faults, causas/transporte/confirmación | ARCH-004; ARCH-003, 35, 47 |
| Causante sin efectos; commits anteriores en el ciclo de frontera | Faults, efectos supervivientes; MEM/WB | ARCH-003, 43, 47; ARCH-004 |
| Drain legal solo EX/MEM y MEM/WB; rama artificial conservada | Control, drain; I21; REQ-HAZ-004 y plan actuales | Derivación del acuerdo 47; AUD2-002 |
| Harvard, base cero, bytes/little-endian, EA modular y región 33 bits | Memoria, formación/validación; I23 | ARCH-001, ARCH-006 y revisión AUD-004 |
| IMEM limitada por capacidad e imagen; DMEM cero lógico y stores dato/metadata atómicos | Memoria, imagen/validez/commit/preparación | ARCH-001, ARCH-006; ARCH-003, 43–44 |
| FSM con los catorce estados aprobados; sesiones nuevas desde terminal | Sesión, relato y tablas FSM | ARCH-003, 44; ARCH-008 |
| Tres solicitudes de ciclo, gating reset/LOAD, hazards no cancelan | Sesión, autorización y origen del ciclo | ARCH-003, 44; ARCH-008 |
| cycle_count unsigned 64, cero por sesión, incremento por fire, wrap sin fault | Sesión, contador; I08; Debug | SYS-006, revisión AUD-005 |
| Estado arquitectónico/persistente/snapshot/transporte; único instante lógico y mínimos observables | Debug, coherencia/contenido obligatorio | SYS-006 y ARCH-004 |
| Campos adicionales, DMEM utilizada y transporte siguen abiertos | Debug y ocho entradas de pendientes | ARCH-009, SYS-005/007/008/009, PROTO-001/002/003 |

## Fase 2 — Plan mínimo

Correcciones obligatorias, en orden de aplicación:

1. Corregir enlaces y referencias de responsabilidad, conservando filenames vigentes (INT-001, INT-004, INT-008).
2. Reparar diagramas de EX, datos, MEM y control global, y precisar selección de bytes y tiempo del load-use (INT-002, INT-003, INT-009, INT-010, INT-013).
3. Consolidar únicamente las tablas aprobadas del decoder en ID; conservar el datapath como plano de datos (INT-004).
4. Quitar fórmulas y esquemas duplicados de las etapas y documentos derivados, enlazando las fuentes responsables (INT-005, INT-006, INT-007).
5. Actualizar vigencia de auditorías y referencias a figuras retiradas, preservando historia (INT-011).
6. Completar el mapa y orden de lectura del README y su acceso desde la raíz (INT-012).

Mejoras editoriales opcionales: corregir la frase «tres grupos» del datapath que enumera cuatro; reemplazar explicaciones sobre cómo leer documentos por descripción del mecanismo. No se propone reescribir capítulos completos ni hacer una pasada general de estilo que amplíe el cambio.

No se propone modificar `decisions.md`, `pending_decisions.md`, `requirements.md` ni `plan.md`. Los criterios actuales de drain ya incorporan la corrección de AUD2-002; la evidencia del informe anterior se conserva como histórica.

## Inconsistencias pendientes y límites

No hay una inconsistencia CPU encontrada que necesite una decisión arquitectónica nueva. Siguen abiertos los ocho ADR existentes, incluido el mecanismo de snapshot, la selección de campos adicionales y el criterio de DMEM utilizada. La ubicación física exacta y el empaquetado de la selección de lanes no quedan decididos por esta corrección conceptual.

El diagrama externo de draw.io no está en el árbol y no puede certificarse aquí. Se revisan los diagramas Mermaid disponibles. Esta auditoría documental no acredita RTL, transporte UART, síntesis, timing ni FPGA.

## Fases 3 y 4 — Cambios aplicados

Los trece hallazgos quedaron corregidos documentalmente con las fuentes aprobadas identificadas arriba. INT-013 se resolvió como aclaración temporal, sin añadir espera. INT-003 se resolvió como contrato conceptual de selección por dirección, conservando la libertad física de la realización de memoria. Las tablas de la FSM, las acciones y los esquemas de latches permanecen iguales.

Se modificaron los siguientes 17 archivos existentes y se agregó este informe:

| Archivo | Cambio aplicado |
|---|---|
| [README del repositorio](../README.md) | Enlace al mapa documental del TP3. |
| [README del TP3](README.md) | Mapa de los catorce documentos, responsabilidad de cada uno, orden de lectura, fuentes y auditorías. |
| [system_overview.md](docs/architecture/system_overview.md) | ISA y decoder remiten a ID; reconstrucción y recorridos remiten al datapath. |
| [cpu_pipeline.md](docs/architecture/cpu_pipeline.md) | Referencias de decode, datos y writeback dirigidas al documento responsable; conserva todas sus tablas. |
| [datapath.md](docs/architecture/datapath.md) | Diagrama separa targets de link, muestra retorno al PC, dato WB→ID y selección/extensión de load; unifica nombres de operandos y corrige enlaces. Ajuste editorial de cuatro grupos de estado. |
| [stage_if.md](docs/architecture/stage_if.md) | Enlaces de etapas correctos; rango/alineación remiten a memoria; actualización a control y esquema IF/ID a pipeline. Mantiene formación y transporte del candidato. |
| [stage_id.md](docs/architecture/stage_id.md) | Whitelist y códigos aprobados consolidados en Decoder; Register File y nombres de operandos uniformes; inmediatos, bypass, load-use, actualización y esquema enlazados a sus fuentes. |
| [stage_ex.md](docs/architecture/stage_ex.md) | A alimenta directamente ALU; B e inmediato llegan al selector de B; rótulo uniforme. Políticas de forwarding, actualización y rango enlazadas; códigos remitidos a ID. |
| [stage_mem.md](docs/architecture/stage_mem.md) | Lectura, posición, tamaño y signo forman selección/ensamblado/extensión; elimina extracción fija injustificada. Conserva un predicado de store y enlaza códigos, actualización y esquema. Los códigos locales de tamaño reproducen el acuerdo 38. |
| [stage_wb.md](docs/architecture/stage_wb.md) | Conserva el predicado completo de commit RF y enlaza la selección de bypass al control; corrige enlaces de etapas. |
| [control_and_hazards.md](docs/architecture/control_and_hazards.md) | Conserva selección de forwarding/bypass, load-use, ocho acciones y actualización; confirmaciones y commits remiten a sus fuentes. Precisa captura ID/EX y consumo del load en el ciclo posterior. |
| [faults_and_termination.md](docs/architecture/faults_and_termination.md) | Conserva causas, confirmaciones, precisión y metadata; región remite a memoria, vaciado a sesión y whitelist a ID; corrige enlaces. |
| [memory_architecture.md](docs/architecture/memory_architecture.md) | Commit store enlazado a MEM; mantiene atomicidad dato/metadata, cero lógico, límites y ownership; enlaces de etapas corregidos. |
| [execution_control.md](docs/architecture/execution_control.md) | Diagrama diferencia estado registrado actual, autorización, hazards, valores next y captura de la FSM en el flanco. Relato de sesión, ecuaciones y tablas conservados. |
| [architectural_invariants.md](docs/architecture/architectural_invariants.md) | Propiedades remiten a predicados de commit y validación responsables; precisa que representación externa concreta sigue pendiente. Conserva I01–I25 y la distinción de drain legal/artificial. |
| [docs_audit.md](docs_audit.md) | Aviso de vigencia histórica y figuras retiradas sin enlaces inexistentes; conserva evidencia anterior. |
| [docs_audit_v2.md](docs_audit_v2.md) | Aviso fechado del cierre documental actual de AUD2-002 y del alcance gráfico no verificado; conserva el hallazgo y las trazas originales. |
| [docs_integration_audit.md](docs_integration_audit.md) | Reporte inicial A–I, evidencias, fuentes, plan obligatorio/opcional, aplicación, límites y verificación final. |

`debug_architecture.md` fue auditado y no requirió edición: distingue correctamente estado, snapshot y representación, mantiene los mínimos observables y los pendientes. `decisions.md`, `pending_decisions.md`, `requirements.md`, `plan.md` y `consigna.md` conservan exactamente sus bytes iniciales, comprobados por SHA-256.

## Verificación final

La revisión cubrió los catorce documentos de arquitectura y contrastó los contratos de la matriz anterior con las revisiones aprobadas aplicables. Las siguientes comprobaciones se ejecutaron sobre el estado posterior a los cambios:

| Comprobación | Evidencia y resultado |
|---|---|
| Destinos y anchors Markdown | Todos los enlaces relativos y anchors de los 24 Markdown del TP3 y README raíz resuelven; se excluyen ejemplos literales y bloques de código. Los 52 enlaces rotos del conjunto vigente fueron corregidos. |
| Preservación de contratos registrados | Comparación exacta de las tablas de pipeline, FSM y acciones frente a la copia inicial: sin diferencias. |
| Whitelist | 33 instrucciones: las 32 exigidas por requisitos más `halt`; 25 patrones contrastados con tablas aprobadas y 8 con la prosa del decoder aprobado. |
| Controles | Diez códigos de ALU coinciden con el acuerdo 34; revisión de controles por clase, defaults y códigos de flujo/memoria frente a acuerdos 34/37/38. No se incorporaron instrucciones. |
| Autorización y contador | Relato, ecuaciones y tablas conservan las tres solicitudes, gating reset/LOAD, primer ciclo tras preparación y contador modular unsigned de 64 bits. |
| Precisión y drain | Se conservan ocho acciones, bloqueo por `exmem_match`, ausencia de DMEM→EX, siete causas, confirmación IF→ID, commits anteriores y drain legal solo en etapas finales; rama artificial conservada. |
| Diagramas | Revisión de conexiones de los 48 bloques Mermaid contra el texto. EX separa operandos A/B; datos separa target/link; MEM incorpora posición de byte; sesión explicita frontera registrada. Bloques Markdown balanceados. No se ejecutó un renderizador Mermaid ni se revisó el draw.io externo ausente. |
| Autoridad y pendientes | SHA-256 de los cinco documentos fuente sin cambios; los ocho identificadores pendientes siguen siendo exactamente los mismos. |
| Alcance de cambios | Revisión del diff frente a la copia inicial: solo documentación; ningún archivo RTL o software de producto modificado. |

El inventario inicial, diff, verificador documental y resultado están en `/tmp/tp3-integration-audit/` como auxiliares de esta sesión. La evidencia y los límites relevantes quedan registrados en este informe y no dependen de conservar esos temporales. Las comprobaciones de enlaces y tablas no equivalen a simulación, síntesis o validación física del procesador.

**No se introdujeron decisiones arquitectónicas nuevas ni se cerró ningún pendiente.** No queda una inconsistencia CPU encontrada sin resolver; los ocho pendientes externos conservan sus condiciones originales de cierre.
