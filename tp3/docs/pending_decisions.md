# TP3 — Trabajo y decisiones pendientes

- **Tipo:** seguimiento de pendientes.
- **Estado documental:** documentación vigente.

**Actualización: 2026-10-06.** Este es el único seguimiento vigente. La arquitectura FPGA está consolidada y FPGA-01–06 cerrados en diseño documental. FPGA-07/08 siguen pendientes; después corresponde FPGA-09. Assembler/aplicación PC pospuestos hasta cerrar FPGA. Todavía no comienza implementación ni se cierra D0/M6 del sistema completo.

La entrada al diseño es [Diseño FPGA consolidado](architecture/system_overview.md). Los contratos aprobados están en los documentos de arquitectura, [Interfaces](interfaces.md) y [Protocolo](protocol.md); [Decisiones](decisions.md) registra acuerdos. Los informes en archive/audits conservan evidencia fechada y no se actualizan como listas de tareas.

**Índice**

- [Propósito y alcance](#propósito-y-alcance)
- [2. Convenciones](#2-convenciones)
- [3. Mapa cronológico](#3-mapa-cronológico)
- [4. Sistema y alcance](#4-sistema-y-alcance)
- [5. CPU y arquitectura](#5-cpu-y-arquitectura)
- [6. Debug y comunicación](#6-debug-y-comunicación)
- [7. Software de PC](#7-software-de-pc)
- [8. Trabajo posterior al diseño](#8-trabajo-posterior-al-diseño)
- [9. Revisión técnica posterior a la auditoría editorial](#9-revisión-técnica-posterior-a-la-auditoría-editorial)
- [Referencia histórica resuelta — 2026-10-06](#referencia-histórica-resuelta--2026-10-06)
- [Referencias y trazabilidad](#referencias-y-trazabilidad)

<a id="1-propósito"></a>

## Propósito y alcance

Reunir el trabajo de diseño pendiente y sus condiciones de cierre, incluidas las decisiones de software. `plan.md` describe el proceso y contiene insumos de pruebas; no es un segundo registro del avance actual. `continuidad_laptop.md` sirve para retomar la conversación y remite aquí.

Al cerrar un trabajo, actualice esta lista y su documento de diseño. Si se aprueba un ADR, registre decisión, justificación y consecuencias en `decisions.md` y actualice su vínculo en requisitos. Una comprobación futura que descubra un defecto debe incorporarse con fuente y efecto; no reabrir acuerdos por textos históricos.

## 2. Convenciones

Los estados distinguen **pendiente de diseño**, **cerrado documentalmente** y **trabajo posterior de implementación**. No confunda cierre documental con pruebas RTL, síntesis o placa. Los resultados FPGA agrupan trabajos; no requieren una aprobación por cada señal o bit.

## 3. Mapa cronológico

| Orden | Trabajo | Estado |
|---|---|---|
| 1 | FPGA-01–06: memoria, configuración, plataforma, composición y representación | Cerrado documentalmente |
| 2 | FPGA-07/08: plan de verificación y contrato del modelo de referencia | Pendiente de diseño |
| 3 | FPGA-09: revisión final con esos entregables | Pendiente |
| 4 | DEC-SYS-009 y DEC-SYS-008: assembler y aplicación PC | Pendientes, pospuestos |
| 5 | Cierre global D0/M6 antes de programar | Pendiente de todos los entregables anteriores |

DEC-SYS-009 conserva como condición de cierre M3 — ISA Freeze y antes de implementar el assembler; DEC-SYS-008 debe cerrarse antes de implementar la aplicación. La prioridad FPGA primero ordena el trabajo sin eliminar estas dependencias.

## 4. Sistema y alcance

No quedan ADR funcionales de sistema abiertos. La consolidación del 2026-10-06 contrastó 54 bloques, jerarquía de 45 tipos, registros interetapa de 34 campos/504 bits, las 32 instrucciones de la consigna más `halt` y catorce estados/códigos. No identificó un bloque funcional FPGA omitido ni una frontera relevante sin especificar. La conclusión es documental y no sustituye FPGA-09 ni garantiza ausencia de fallos futuros.

## 5. CPU y arquitectura

No quedan ADR funcionales CPU abiertos. Estos son los trabajos FPGA pendientes:

| ID | Entregable pendiente | Condición de cierre |
|---|---|---|
| FPGA-07 | Plan de verificación de hardware | Matriz requisito → contrato → prueba con estímulos, secuencia/resultado esperado, nivel y aceptación. Cubrir ISA, hazards, faults, RUN/STEP/HOLD, carga/aborto/commit, reset, Debug, errores RX, TX llena y ambos perfiles; UART integrado y servicios nuevos. Distinguir comportamiento alcanzable e inyección artificial de `act_drain_load_use`. No programar tests ahora. |
| FPGA-08 | Contrato del modelo de referencia y comparación | Definir entradas/salidas y cuándo comparar RF/DMEM, causa/PC causante y efectos comprometidos con el modelo secuencial RV32I del subconjunto. PC de fetch, ciclos, registros interetapa, FSM y STEP/Debug necesitan expectativas temporales propias; no compararlos indiscriminadamente con el PC secuencial. No es la aplicación PC ni el assembler. |
| FPGA-09 | Revisión documental final FPGA | Repetir contraste integral después de cerrar FPGA-07/08; comprobar conexiones, documentos/diagramas, referencias, cobertura y plan completo. Registrar qué quedó satisfecho. La organización arquitectónica ya realizada no basta para cerrar este resultado. Cerrar FPGA no cierra D0 mientras PC siga pendiente. |

Fuentes de trabajo: [Plan de verificación](plan.md#15-fase-12--plan-de-verificación), [Modelo de referencia](plan.md#18-fase-15--modelo-de-referencia), [Invariantes](architecture/architectural_invariants.md) y [Criterio de cierre de interfaces](interfaces.md#153-criterio-de-aceptación-documental-y-verificación-posterior).

Los trabajos cerrados conservan sus fuentes de diseño:

| ID cerrado | Fuente vigente |
|---|---|
| FPGA-01/02: acceso y mantenimiento de la misma DMEM | [Acceso DMEM](architecture/dmem_access.md) |
| FPGA-03: configuración común/tipos | [Configuración](architecture/common_configuration.md) |
| FPGA-04: clock/reset/pines/restricciones previstas | [Plataforma](architecture/platform_reference.md) |
| FPGA-05/06: composición y representación integrada | [Composición](architecture/system_composition.md#revisión-local-y-cierre-de-composición) e [Inventario](architecture/module_inventory.md) |

Las representaciones draw.io/HTML son complementarias; no se certificó cada cable de esas presentaciones. La representación integrada vigente está en composición, con cobertura del inventario/interfaces.

## 6. Debug y comunicación

<a id="dec-sys-007--servicios-y-parámetros-generales-de-uart"></a>

Sin decisiones abiertas. [DEC-SYS-007](decisions.md#dec-sys-007--servicios-y-parámetros-generales-de-uart) está aprobada desde el 2026-10-05. Los fundamentos vigentes están en [Integración UART](architecture/uart_core.md#presupuesto-de-integración), [LOAD](architecture/loader.md#presupuesto-de-load), [Preparación](architecture/session_preparation.md#duración-y-alcance-de-revisión) y [Transmisión/Debug](architecture/response_serializer.md#presupuesto-de-transmisión-y-debug). El ancla anterior conserva enlaces históricos; no es una decisión pendiente.

`cycle_count` conserva 64 bits unsigned, incremento módulo 2^64, ocho bytes little-endian y lectura del estado retenido. No se reabren ancho/semántica por falta de pruebas RTL. El contenido y exclusión Debug y los plazos del protocolo también están aprobados.

## 7. Software de PC

### DEC-SYS-009 — Estrategia del assembler

**Estado:** Pendiente

**Dominio:** Software / Assembler

**Debe resolverse antes de:** M3 — ISA Freeze y antes de implementar el assembler.

**Depende de:** `DEC-SYS-001`, `DEC-SYS-004`, `DEC-SYS-010` y `DEC-ARCH-001`, ya aprobadas.

**Contexto:** Debe decidirse si se implementará un assembler propio o se integrará una herramienta existente de manera controlada.

También debe decidirse en qué componente del toolchain se verificará que la imagen generada es una secuencia little-endian no vacía, contigua, sin huecos, con origen cero, tamaño múltiplo de cuatro y dentro de la capacidad soportada del perfil seleccionado. Esta responsabilidad no se asigna necesariamente de forma exclusiva al assembler y no deberá hardcodear los valores del perfil de referencia.

La estrategia deberá aceptar `halt` sin operandos y emitir exactamente `0x0000000B`, conforme a `DEC-SYS-001` y `REQ-SW-012`; integrar una herramienta RV32I conserva esa obligación custom.

**Opciones a analizar:** assembler propio para el subconjunto; herramienta externa; biblioteca existente con validación del subconjunto.

**Propuesta para revisión (sin aprobación):** [assembler propio en Python](assembler_strategy.md), dos pasadas para etiquetas, instrucciones del subconjunto más `halt` y empaquetado/validación de imagen según perfil. No autoriza implementar.

**Requisitos afectados:** `REQ-MEM-010` a `REQ-MEM-012`, `REQ-MEM-015`, `REQ-MEM-021` a `REQ-MEM-024`, `REQ-SW-002` a `REQ-SW-004`, `REQ-SW-010`, `REQ-SW-012`.

---

### DEC-SYS-008 — Formato de la aplicación de PC

**Estado:** Pendiente

**Dominio:** Software / Interfaz

**Debe resolverse antes de:** Implementar la interfaz de usuario.

**Depende de:** `DEC-SYS-006`, ya aprobada, y flujos de operación definidos por Debug y el protocolo.

**Contexto:** Debe seleccionarse una CLI, TUI, GUI o combinación para operar el sistema y presentar el snapshot aprobado sin acoplar la interfaz a señales combinacionales internas. La aplicación deberá mostrar un fault de memoria como ejecución anormal y no como finalización normal.

**Opciones a analizar:** CLI inicial; TUI; GUI; capas reutilizables con más de una interfaz.

**Requisitos afectados:** `REQ-SW-001`, `REQ-SW-005` a `REQ-SW-010`, `REQ-DBG-013` a `REQ-DBG-017`, `REQ-EXEC-018`.

## 8. Trabajo posterior al diseño

RTL, implementación de modelos/testbenches/assertions, regresiones, síntesis, inferencia/recursos, generación de IP/XDC efectivo, timing post-implementation y pruebas de placa siguen para después del cierre global. No son decisiones funcionales actualmente abiertas. Los clocks contados en modelos abstractos no acreditan que las rutas cierren físicamente a 50 MHz.

## 9. Revisión técnica posterior a la auditoría editorial

El informe editorial `editorial_report_20261006.md`, sección F «Casos no modificados», conserva el diagnóstico de la entrega editorial; ese archivo no está disponible en el árbol actual. Esta sección registra la revisión posterior de sus once casos; señalar una posible inconsistencia no confirma un defecto ni reabre por sí solo un ADR aprobado.

| Caso | Asunto | Estado de revisión |
|---|---|---|
| 1 | REQ-CPU-008: selección y escritura del resultado | Resuelto documentalmente: requisito y aceptación alineados con el reparto MEM/WB aprobado |
| 2 | Consigna §2.5: selección atribuida a WB | Resuelto documentalmente: enunciado conservado y nota de interpretación del reparto MEM/WB |
| 3 | Forwarding: comprobación atribuida a los muxes | Resuelto documentalmente: comprobación y generación de selectores atribuidas a Forwarding Unit |
| 4 | `ex_result`: alcance de valor resuelto | Resuelto documentalmente: origen seleccionado en EX, dirección para loads/stores y valor final formado en MEM |
| 5 | Stores: ausencia de `wb_value` frente a ausencia de escritura | Resuelto documentalmente: valor combinacional posible, sin escritura de registro ni forwarding |
| 6 | Debug: selección de estado observable todavía pendiente en el texto | Resuelto documentalmente: exposición completa y representación externa reconocidas como aprobadas |
| 7 | Protocolo: vigencia de aspectos internos por concretar | Resuelto documentalmente: seis aspectos enlazados a contratos vigentes, con implementación y validación pendientes |
| 8 | Interfaces: nombres físicos no fijados frente a nombres concretos | Resuelto documentalmente: etiquetas funcionales vinculadas a señales y composición aprobadas |
| 9 | Plan: FINISHED/DONE ante faults y STEP | Resuelto documentalmente: RUN termina con FAULT; STEP realizado responde DONE con estado de fault en Debug |
| 10 | Plan: DRAINING frente a estados concretos de drenado | Resuelto documentalmente: condición conceptual vinculada a los cuatro estados de drenado y a modos combinacionales |
| 11 | Plan: mirror/shadow condicional frente a lectura retenida | Resuelto documentalmente: pruebas alineadas con lectura directa y exclusión hasta el último Stop físico |

### Caso 1 — REQ-CPU-008

**Resolución, 2026-10-06:** El requisito conserva la obligación de seleccionar el resultado correcto y escribirlo cuando corresponda, pero sitúa la selección en MEM y la escritura en WB. Su aceptación ahora comprueba explícitamente la selección antes de capturar `MEM/WB`; conserva todas las condiciones anteriores de elegibilidad, valor previo al flanco, escritura única, `x0`, entradas inválidas, HOLD, bypass, reset/preparación y commits anteriores a halt/fault.

**Fundamento:** [DEC-ARCH-003 — selección del valor arquitectónico de Write Back en MEM](decisions.md#acuerdo-parcial-aprobado--selección-del-valor-arquitectónico-de-write-back-en-mem), aprobado el 2026-09-23, fija un único resultado seleccionado antes de capturar `MEM/WB`. El [WB Value MUX](architecture/stage_mem.md#wb-value-mux) realiza esa selección; [WB](architecture/stage_wb.md#función-de-la-etapa) usa directamente `MEM/WB.wb_value`. El cambio corrige la asignación de responsabilidad del requisito y no modifica el datapath ni requiere una decisión arquitectónica nueva. La interpretación de la consigna queda documentada por separado en el caso 2.

### Caso 2 — Consigna §2.5

**Resolución, 2026-10-06:** Se conserva la frase «Debe seleccionar el valor correcto a escribir y actualizar el registro destino cuando corresponda» en [§2.5 de la consigna](consigna.md#25-wb--write-back). Una nota identificada como interpretación del proyecto explica que la selección del resultado destinado a writeback ocurre en MEM antes de capturar `MEM/WB`, y que WB escribe el valor registrado cuando corresponde. La nota enlaza el acuerdo aprobado, los contratos de MEM/WB y REQ-CPU-008; distingue la interpretación aplicada de la redacción docente.

**Fundamento:** El acuerdo de DEC-ARCH-003 citado en el caso 1 ya determina la ubicación de la selección. El texto de la consigna y la realización aprobada asignan esa operación a etapas distintas; la nota hace explícito cómo el proyecto concreta las funciones de selección y escritura sin agregar otra selección en WB ni modificar la arquitectura. Este cierre documental registra la interpretación del proyecto; no acredita una validación docente adicional ni una prueba de implementación.

### Caso 3 — Forwarding hacia EX

**Resolución, 2026-10-06:** El párrafo introductorio de [Forwarding hacia EX](architecture/control_and_hazards.md#forwarding-hacia-ex) ahora atribuye la identificación del productor pendiente más reciente y la comprobación de disponibilidad a `Forwarding Unit`. La unidad genera `forward_a_sel` y `forward_b_sel`; `Forward MUX A/B` aplican esos selectores y producen los operandos efectivos. Se conservan las ecuaciones, la independencia entre fuentes, la prioridad de productores, la elegibilidad y el bloqueo de versiones antiguas ante un load más reciente sin dato disponible.

**Fundamento:** [DEC-ARCH-003 — realización física de la Forwarding Unit](decisions.md#acuerdo-parcial-aprobado--realización-física-de-la-forwarding-unit) asigna esas comprobaciones a la unidad combinacional, y el [contrato de interfaces 3.1–3.3](interfaces.md#bloque-3-1) distingue sus salidas de control de las entradas y salidas de datos de los muxes. La corrección alinea la explicación introductoria con los contratos aprobados; no añade señales, interlocks ni altera el stall load-use.

### Caso 4 — Alcance de `ex_result`

**Resolución, 2026-10-06:** La sección [El valor ex_result](architecture/datapath.md#el-valor-ex_result) ahora limita lo resuelto en EX a la selección entre ALU, inmediato y enlace. Para las instrucciones que escriben un registro sin acceder a DMEM, el campo contiene el resultado arquitectónico; para loads y stores, contiene la dirección efectiva. MEM todavía interpreta `EX/MEM.mem_op`, realiza el acceso cuando corresponde y selecciona `wb_value`; WB recibe el valor final desde `MEM/WB.wb_value`. Se retira la afirmación general de que MEM y WB no necesitan interpretar la clase de instrucción.

**Fundamento:** [DEC-ARCH-003 — selección física de ex_result](decisions.md#acuerdo-parcial-aprobado--realización-física-de-la-selección-de-ex_result) distingue resultado de registro y dirección efectiva. [MEM Decode](architecture/stage_mem.md#mem-decode) interpreta el control de memoria y determina los controles locales; [WB Value MUX](architecture/stage_mem.md#wb-value-mux) selecciona el dato final antes de capturar `MEM/WB`. La corrección precisa el significado de los valores ya aprobados; conserva campos, ecuaciones, recorridos y condiciones de elegibilidad. El caso 5 sobre stores se mantiene separado.

### Caso 5 — Stores y `wb_value`

**Resolución, 2026-10-06:** La sección [Stores del datapath](architecture/datapath.md#stores) conserva la ausencia de escritura de `rd` y precisa que el store escribe DMEM en MEM cuando su commit es elegible. Retira la afirmación de que no produce `wb_value`: el `WB Value MUX` puede presentar `EX/MEM.ex_result`, pero ese dato no habilita escritura en el banco de registros ni forwarding porque el store tiene `reg_write=0`.

**Fundamento:** El [contrato de WB Value MUX](architecture/stage_mem.md#wb-value-mux) selecciona `EX/MEM.ex_result` para operaciones no load y permite valores combinacionales sin efecto arquitectónico. [WB para instrucciones sin escritura de registro](architecture/stage_wb.md#instrucciones-que-no-escriben-un-registro) y [DEC-ARCH-003 — selección del valor de Write Back](decisions.md#acuerdo-parcial-aprobado--selección-del-valor-arquitectónico-de-write-back-en-mem) establecen la falta de escritura y forwarding para stores. El [commit de DMEM](architecture/stage_mem.md#dmem-write-control) conserva sus condiciones de validez y ciclo efectivo. La corrección distingue existencia de un valor y elegibilidad de su efecto; no exige poner `wb_value` en cero ni modifica señales, gating o recorrido de datos.

### Caso 6 — Campos del pipeline observables por Debug

**Resolución, 2026-10-06:** La sección [PC e instrucción](architecture/debug_architecture.md#pc-e-instrucción) retira «queda elegir qué parte de ese estado registrado forma parte de su representación de Debug». Reconoce la exposición completa de los campos funcionales ya definidos y enlaza el protocolo para anchos/orden externos y el serializador para lectura/selección de bytes. Se conservan los campos, códigos, layout y la transmisión de valores registrados también en entradas inactivas; la vigencia sigue interpretándose mediante sus indicadores.

**Fundamento:** [DEC-ARCH-009](decisions.md#dec-arch-009--campos-de-pipeline-expuestos-por-debug) está aprobada y expone los 34 campos funcionales de los cuatro registros interetapa. El [layout del protocolo](protocol.md#latches) y la [observación de los cuatro registros en el serializador](architecture/response_serializer.md#observación-y-selección-de-bytes-de-los-cuatro-latches) completan su representación y recorrido. La frase anterior era un pendiente documental desactualizado; corregirlo no modifica la selección aprobada ni acredita implementación o verificación RTL.

### Caso 7 — Límites del diseño de bloques en el protocolo

**Resolución, 2026-10-06:** La sección [Límites del diseño de bloques](protocol.md#límites-del-diseño-de-bloques) reconoce como concretados documentalmente los seis aspectos que antes enumeraba como pendientes: arbitraje/FSM, fin físico de respuestas, presupuesto y continuidad RX, puertos/recorrido DMEM, ownership y preparación. Cada punto enlaza su contrato vigente. Se conserva la distinción entre cierre del protocolo y cierre global, y se remite a FPGA-07/08/09 para los entregables de verificación y revisión pendientes.

**Fundamento:** [DEC-SYS-007](decisions.md#dec-sys-007--servicios-y-parámetros-generales-de-uart) está aprobada desde el 2026-10-05; el [presupuesto de integración UART](architecture/uart_core.md#presupuesto-de-integración) documenta conexiones, continuidad RX, conservación TX y fin físico. [Interfaces §15.2](interfaces.md#152-estado-de-los-detalles-de-realización-por-módulo) declara concretados esos detalles y conserva sus límites de comprobación. La lista anterior era un estado documental desactualizado; se actualiza sin modificar contratos, formatos, tiempos o condiciones del protocolo ni acreditar RTL, timing o placa.

### Caso 8 — Nombres y concreciones de interfaces

**Resolución, 2026-10-06:** [Instruction Memory §1.5](interfaces.md#bloque-1-5) reconoce la interfaz de carga concretada y vincula su etiqueta funcional con `imem_write_index`, `imem_write_data` e `imem_write_enable`. [Command Arbiter §8.1](interfaces.md#bloque-8-1) vincula las solicitudes `LOAD`, `STEP` y `RUN` con `load_request`, `step_request` y `run_request`. [Loader §9.1](interfaces.md#bloque-9-1) precisa el alias `pending_image_size_bytes` desde `load_size_bytes`, sin duplicar almacenamiento. La fila de DMEM en §10.3 reconoce la composición del top ya concretada.

**Fundamento:** [Loader](architecture/loader.md), las [señales del controlador](architecture/protocol_controller.md#señales-y-conexiones-aprobadas) y la [composición aprobada](architecture/system_composition.md#puertos-y-parámetros-de-los-tops) ya fijan los nombres y conexiones. Las notas anteriores confundían etiquetas conceptuales del mapa con nombres de integración todavía pendientes. Se conservan las etiquetas, productores, consumidores, anchos, condiciones, prioridad de reset y ausencia de registros duplicados; no se crean ni renombran señales. El cierre es documental, con implementación y validación RTL pendientes.

### Caso 9 — Faults, `FINISHED` y `DONE` en el plan

**Resolución, 2026-10-06:** Los criterios de faults en [el plan](plan.md) conservan la ausencia de `program_finished` y de terminación normal `FINISHED`, pero dejan de prohibir `DONE` de forma general. La comprobación UART distingue `[RUN][FAULT][Debug]` de `[STEP][DONE][Debug]`: cada paso realizado responde `DONE`, también durante confirmación o drenado de un fault, y Debug indica `FAULT_DRAIN_STEP` o `FAULT` con causa y PC vigentes. El paso que vacía el pipeline ya observa `global_state=FAULT`, sin paso adicional.

**Fundamento:** [RUN — aceptación y terminal](protocol.md#aceptación-y-terminal) y [STEP — halt, fault y drain por pasos](protocol.md#halt-fault-y-drain-por-pasos) fijan las respuestas; el [acuerdo de halt/fault en STEP](decisions.md#acuerdo-parcial-de-dec-proto-001--halt-fault-y-drenado-en-respuestas-step) confirma que `DONE` acredita el ciclo, no el tipo de terminación del programa. Se mantienen fault preciso, commits anteriores, descarte de causante/jóvenes, estabilidad de metadatos, modos de drenado y reset. El cambio corrige los resultados esperados de las pruebas futuras; no cambia el protocolo ni acredita pruebas ejecutadas.

### Caso 10 — Drenado conceptual y estados concretos en el plan

**Resolución, 2026-10-06:** La sección [Generación desde RUN, STEP y drenado](plan.md#generación-desde-run-step-y-drenado) vincula la condición conceptual de drenado con `HALT_DRAIN_AUTO`, `HALT_DRAIN_STEP`, `FAULT_DRAIN_AUTO` y `FAULT_DRAIN_STEP`. Las pruebas de halt y fault continuos observan el estado `AUTO` correspondiente cuando quedan anteriores; halt por pasos observa `HALT_DRAIN_STEP`.

La espera sin orden aceptada ni acción superior comprueba conservación de `HALT_DRAIN_STEP` o `FAULT_DRAIN_STEP` y ausencia de evento CPU. Si el ciclo confirmante ya deja vacío el pipeline, se alcanza directamente `FINISHED` o `FAULT`, sin exigir un drenado adicional.

`drain_mode` se reconoce como decodificación combinacional del estado, sin registro nuevo.

**Fundamento:** [DEC-SYS-002](decisions.md#dec-sys-002--comportamiento-ante-ausencia-de-stophalt) admite `DRAINING` como etiqueta conceptual. El [acuerdo de FSM global y autorización de ciclos](decisions.md#acuerdo-parcial-aprobado--fsm-global-de-ejecución-y-autorización-de-ciclos) concreta causa y modalidad en los estados aprobados; [Control de ejecución](architecture/execution_control.md#tabla-de-transiciones) fija avance, espera, conversión por `RUN` y llegada al terminal. Se conservan prioridades de reset/LOAD, un ciclo por STEP, commits de anteriores, descarte de causante/jóvenes y contador. La corrección precisa qué observan las pruebas futuras; no modifica la FSM, su codificación ni acredita verificación RTL.

### Caso 11 — Lectura retenida de Debug frente a mirror/shadow

**Resolución, 2026-10-06:** [Ownership y concurrencia](plan.md#ownership-y-concurrencia-1) y [Test 4 — lectura de estado simulado](plan.md#test-4--lectura-de-estado-simulado) comprueban el mecanismo elegido: lectura directa del estado posterior a `STEP` o terminal de `RUN`, retenido hasta el último Stop físico de la respuesta. Se sustituyen los escenarios condicionales de mirror/shadow y las alternativas de captura por comprobaciones de estabilidad, selección CPU/Debug de DMEM y exclusión durante espera y envío.

No hay nuevos ciclos CPU ni inicio de `LOAD` o preparación en esa ventana. El encolado del último byte no la termina; UART, lectura y serialización continúan con el clock funcional. Reset físico puede abortar el envío conforme al protocolo.

**Fundamento:** El [acuerdo de envío exclusivo con estado retenido](decisions.md#acuerdo-parcial-de-dec-proto-001--envío-exclusivo-de-debug-con-estado-retenido), aprobado el 2026-10-01, elige un mecanismo entre las alternativas generales de acuerdos anteriores. [Debug](architecture/debug_architecture.md#por-qué-la-coherencia-importa-con-uart), [la exclusión del controlador](architecture/protocol_controller.md#terminal-run-y-exclusión-debug) y [el serializador](architecture/response_serializer.md#seguimiento-físico-ocupación-y-reset) concretan retención y fin físico. Se conservan los contenidos del snapshot, los registros de recorrido/bytes y ownership exclusivo; la corrección del alcance de las pruebas no prohíbe por sí sola recursos físicos adicionales ni modifica los contratos aprobados. El cierre es documental; FPGA-07/08/09 y las comprobaciones RTL siguen pendientes.

## Referencia histórica resuelta — 2026-10-06

Las referencias al checklist temporal retirado `protocolo_checklist_temporal_2026-10-01.md` están anotadas en [Decisiones](decisions.md#dec-proto-001--formato-detallado-del-protocolo) y en la [nota editorial del informe V03](archive/audits/debug_protocol_audit.md#nota-editorial-sobre-una-referencia-retirada--2026-10-06). V03 acredita la consolidación en [Protocolo](protocol.md). Hallazgo de navegación resuelto; no deja una decisión técnica abierta ni cierra FPGA-07/08.

## Referencias y trazabilidad

- [Plan](plan.md): fases, hitos y condiciones globales de avance.
- [Decisiones](decisions.md): acuerdos aprobados y sus revisiones.
- [Diseño FPGA consolidado](architecture/system_overview.md): diseño actual y contratos relacionados.
