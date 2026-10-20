### DEC-ARCH-006 — Implementación física de las memorias

**Contrato vigente de consulta:** [memory_architecture](../architecture/memory/memory_architecture.md), [dmem_access](../architecture/memory/dmem_access.md), [common_configuration](../architecture/common_configuration.md), [module_inventory](../architecture/module_inventory.md), [system_composition](../architecture/system_composition.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** CPU / Recursos FPGA

**Fecha de aprobación:** 2026-09-21

**Contexto:** `DEC-ARCH-001` fijó el comportamiento arquitectónico de `Instruction Memory` y `Data Memory`, pero dejó pendiente establecer un contrato físico inicial compatible con FPGA. Debían definirse la latencia observable, la estrategia base de implementación, la organización conceptual, la demanda mínima de puertos, la representación del cero lógico de DMEM, el estado persistente de la imagen y los perfiles utilizados para validar parametrización.

Esta decisión debe preservar direccionamiento por bytes, espacios Harvard lógicamente independientes, little-endian, validación previa a indexación, reprogramación segura y el pipeline conceptual de cinco etapas, respetando la FSM y control de los acuerdos 40–48 de `DEC-ARCH-003`, alineación de `DEC-ARCH-004` y clock de `DEC-ARCH-005`; el criterio de memoria utilizada por Debug permanece en `DEC-SYS-005`.

**Opciones consideradas:**

1. Lectura combinacional o registrada.
2. RTL inferido, XPM, primitivas o IP generado.
3. IMEM por bytes o por palabras de 32 bits.
4. DMEM monolítica o dividida conceptualmente en lanes de bytes.
5. Puertos concurrentes obligatorios o ownership exclusivo.
6. Borrado físico de DMEM, validez por palabra, validez por byte o representaciones equivalentes.
7. `image_valid` persistente independiente o derivado del tamaño confirmado.
8. Soportar todo el dominio arquitectónico o declarar perfiles concretos de validación.

**Decisión:** Se aprueba el siguiente alcance. La [revisión de agrupación del control global](#revisión-de-dec-arch-006--agrupación-del-control-global-de-ejecución) actualiza la organización y los conteos de módulos.

#### 1. Contrato físico aprobado

##### Latencia de lectura y escritura

`Instruction Memory` y `Data Memory` presentarán hacia la CPU lectura **combinacional**, sin salida registrada, handshake, latencia variable ni stalls atribuibles exclusivamente a la memoria.

Conceptualmente:

```text
PC / validación -> IMEM -> IF/ID
EX/MEM / validación -> DMEM -> selección/extensión -> MEM/WB
```

Las escrituras serán síncronas respecto del flanco activo habilitado. El loader escribirá `Instruction Memory` únicamente después de disponer de una instrucción completa y un store modificará `Data Memory` únicamente cuando la operación correspondiente sea válida y esté habilitada por el control.

La memoria no introducirá una etapa adicional entre IF e ID ni entre MEM y WB. Un backend cuya interfaz requiera necesariamente lectura registrada no satisface este contrato sin revisar explícitamente la decisión y sus dependencias.

##### Backend inicial

La implementación inicial de IMEM, DMEM y su lógica asociada se describirá mediante **RTL sintetizable e inferible**. La inferencia es la estrategia base, pero no promete que Vivado seleccione un tipo físico concreto de RAM.

XPM o primitivas específicas podrán evaluarse en el futuro si los resultados de síntesis, utilización o timing lo justifican. Cualquier alternativa deberá conservar exactamente:

- interfaces lógicas;
- lectura combinacional;
- escritura síncrona;
- direccionamiento y little-endian;
- ownership y concurrencia;
- semántica de imagen y de cero lógico;
- comportamiento observable por CPU, loader y Debug.

La selección concreta de una alternativa y su configuración se realizará únicamente cuando exista evidencia que la motive.

##### Organización conceptual

IMEM se organizará conceptualmente como un array de palabras de 32 bits:

```text
IMEM_WORD_COUNT = IMEM_CAPACITY_BYTES / 4
word_index       = PC >> 2
```

Cada entrada contendrá una instrucción completa. El loader reconstruirá la palabra antes de escribirla y el índice solo se utilizará después de validar la solicitud completa.

DMEM se organizará conceptualmente mediante cuatro lanes o bancos lógicos de bytes:

```text
DMEM_WORD_COUNT = DMEM_CAPACITY_BYTES / 4
bank_i          = byte_address_i[1:0]
row_i           = byte_address_i >> 2
```

Cada byte candidato se mapeará independientemente. Un store válido modificará únicamente los bytes seleccionados y un load reconstruirá los bytes en orden little-endian antes de aplicar sign o zero extension.

Esta organización no obliga a Vivado a materializar cuatro bloques RAM independientes ni fija la frontera exacta entre wrapper, LSU y arrays físicos.

##### Ownership y concurrencia

Cada memoria lógica admitirá como máximo un agente autorizado por vez. El contrato permite ciclos sin agente activo y no exige puertos concurrentes CPU/loader sobre IMEM ni CPU/Debug sobre DMEM.

`Instruction Memory` tendrá como agentes conceptuales a CPU y loader. `Data Memory` tendrá como agentes conceptuales a CPU y Debug. La lectura directa de Debug requerirá CPU quiescente; una implementación con mirror, shadow o snapshot aislado podrá desacoplar la observación.

IMEM y DMEM mantendrán interfaces lógicas independientes. Durante ejecución deberá ser posible atender en el mismo ciclo un fetch y una operación de load o store sin hazard estructural ni stall atribuible a tratarlas como un único recurso.

No se fija en esta decisión la codificación de ownership, los nombres de grants, la lógica concreta de muxes, los pulsos de compromiso ni el tratamiento temporal detallado de una colisión interna. El control deberá preservar la exclusión aprobada y las violaciones se comprobarán mediante assertions de exclusión durante la implementación.

##### Estado confirmado de Instruction Memory

`loaded_image_size_bytes` será la única fuente persistente de verdad sobre la imagen actualmente confirmada y ejecutable. `image_valid` se derivará combinacionalmente:

```text
image_valid = (loaded_image_size_bytes != 0)
```

El tamaño se expresará en bytes y deberá representar desde cero hasta `IMEM_CAPACITY_BYTES` inclusive:

```text
IMAGE_SIZE_WIDTH = max(1, ceil(log2(IMEM_CAPACITY_BYTES + 1)))
```

Los estados persistentes legales serán cero o un tamaño de imagen no vacío, múltiplo de cuatro y no mayor que IMEM. El progreso de `LOAD` permanecerá separado. Al aceptar una nueva carga se invalidará el tamaño confirmado; una solicitud rechazada no modificará por sí sola la imagen vigente.

La cantidad de instrucciones se derivará de `loaded_image_size_bytes / 4`. No existirá bitmap de validez por instrucción, bitmap por byte de IMEM, lista de regiones válidas ni metadatos sparse. La imagen confirmada seguirá siendo un único prefijo contiguo desde `0x00000000`.

#### 2. Implementación de referencia

##### Cero lógico y metadata DMEM

La semántica obligatoria será:

```text
Todo byte no escrito durante la sesión actual se lee como 0x00.
```

La implementación de referencia utilizará un `valid` bit por byte:

```text
VALID_BIT_COUNT = DMEM_CAPACITY_BYTES
logical_byte[a] = valid[a] ? data[a] : 8'h00
```

Cada store válido actualizará atómicamente el dato y la validez de los bytes seleccionados. Los bytes no seleccionados conservarán ambos valores. Los loads aplicarán el filtro de validez byte por byte antes del ensamblado y extensión.

El bitmap de un bit por byte es una **implementación de referencia**, no una representación física universal obligatoria. Perfiles futuros podrán utilizar generation tags, metadatos jerárquicos u otra técnica equivalente sin revisar la arquitectura, siempre que preserven exactamente:

- cero para todo byte no escrito en la sesión;
- granularidad observable por byte;
- atomicidad de stores;
- aislamiento entre sesiones;
- latencia y comportamiento de loads;
- observación coherente por Debug.

El mecanismo concreto que establece el estado lógico inicial de una nueva sesión podrá ser paralelo, secuencial, mediante FSM o equivalente. La sesión no podrá confirmarse ni habilitar `RUN`/`STEP` hasta que DMEM presente la semántica de cero requerida, pero esta decisión no fija cantidad de bits por ciclo, señales ni secuencia de control.

Los metadatos podrán ser un insumo para Debug, pero no determinan por sí mismos qué posiciones se consideran memoria utilizada.

##### Perfiles

Se utilizarán los siguientes perfiles:

| Perfil      | IMEM bytes | DMEM bytes | Compromiso                                                                              |
|-------------|-----------:|-----------:|-----------------------------------------------------------------------------------------|
| `REFERENCE` |       1024 |       2048 | Elaboración, simulación, síntesis, implementación y validación en hardware obligatorias |
| `ALT_1000`  |       1000 |       1000 | Elaboración, simulación y smoke tests de parametrización no potencia de dos             |

`REFERENCE` es el único perfil con compromiso físico completo en esta decisión. `ALT_1000` demuestra que índices, límites, metadatos y validaciones no dependen de capacidades potencia de dos; no se exige todavía implementación física ni timing closure para este perfil.

Una configuración arquitectónicamente inválida deberá rechazarse claramente. Una configuración válida pero no declarada soportada también deberá producir un error claro, distinguible del caso inválido. Ampliar el conjunto de perfiles físicamente soportados requerirá una decisión posterior basada en evidencia.

#### 3. Aspectos explícitamente diferidos

Esta decisión no fija:

- polaridad, estrategia temporal, semántica de `reset`, prioridades y condiciones globales de enable, definidas por `DEC-ARCH-008` sin imponer FSM de carga ni secuencia RTL concreta de ownership;
- mecanismo físico de invalidación, cantidad de `valid` bits limpiados por ciclo ni señales de inicio/progreso/finalización de mantenimiento;
- nombres de puertos, grants, pulsos de compromiso o señales RTL concretas;
- política de alineación, accesos desalineados y prioridad de errores, que corresponden a `DEC-ARCH-004`;
- plataforma Basys 3 y objetivo inicial de 50 MHz, fijados por acuerdos parciales de `DEC-ARCH-005`; timing closure, frecuencia final y necesidad efectiva de un fallback físico continúan sujetos a sus resultados de implementación;
- criterio de memoria utilizada y mecanismo final de captura Debug, que corresponden a `DEC-SYS-005`;
- framing, orden de transporte y comandos UART, que corresponden a `DEC-PROTO-001` y decisiones relacionadas;
- tecnología física exacta que Vivado infiera;
- configuración concreta de XPM o primitivas si en el futuro se justifican.

**Justificación:** La lectura combinacional conserva las cinco etapas conceptuales y evita introducir una microarquitectura distinta de forma implícita. RTL inferido permite comenzar con una descripción portable y medir la realización real antes de introducir dependencias específicas del fabricante.

La organización por palabras coincide con fetches completos y la organización por lanes coincide con stores parciales. Ownership exclusivo satisface los flujos obligatorios sin convertir multiport en requisito, mientras la independencia lógica de IMEM y DMEM conserva la concurrencia IF/MEM.

La validez lógica por byte representa exactamente la semántica requerida para `sb`, `sh` y `sw`. Mantener el bitmap solo como referencia evita convertir una solución sencilla para el perfil actual en una restricción arquitectónica futura.

Derivar `image_valid` del tamaño elimina estado redundante. `ALT_1000` proporciona evidencia de parametrización no potencia de dos sin prometer prematuramente soporte físico completo.

**Consecuencias:**

- IMEM y DMEM presentan lectura combinacional y escritura síncrona;
- RTL inferido es el backend inicial;
- IMEM usa palabras conceptuales de 32 bits;
- DMEM usa cuatro lanes conceptuales de bytes;
- cada memoria viva admite como máximo un agente autorizado;
- IMEM y DMEM pueden atender simultáneamente sus demandas lógicas;
- cada byte DMEM no escrito en la sesión se lee como cero;
- la referencia usa un `valid` bit por byte, pero otras representaciones equivalentes permanecen permitidas;
- `loaded_image_size_bytes` es la única fuente persistente de imagen;
- `image_valid` se deriva del tamaño;
- IMEM no utiliza bitmap de validez;
- `REFERENCE=1024/2048` tiene compromiso físico completo;
- `ALT_1000=1000/1000` valida parametrización mediante elaboración, simulación y smoke tests;
- configuraciones inválidas o válidas no soportadas fallan claramente;
- XPM o primitivas futuras permanecen permitidas si evidencia física las justifica y preservan el contrato;
- control, invalidación concreta, señales, timing, alineación y Debug utilizado permanecen en sus decisiones correspondientes.

**Requisitos afectados:** `REQ-CPU-002` a `REQ-CPU-004`, `REQ-CPU-007`, `REQ-CPU-009`, `REQ-CPU-010`, `REQ-MEM-001` a `REQ-MEM-030`, `REQ-EXEC-009`, `REQ-EXEC-017`, `REQ-EXEC-018`, `REQ-TIM-003` a `REQ-TIM-007`, `REQ-DBG-010`, `REQ-DBG-015`, `REQ-DOC-007`, `REQ-DOC-009`.

**Reemplaza / Reemplazada por:** No aplica.

---

### Acuerdo de concreción de DEC-ARCH-006 — Lectura DMEM alineada y selección en MEM

**Estado del acuerdo:** Aprobado; concreción parcial de FPGA-01. No cierra todavía FPGA-01/02 ni el diseño global.

**Dominio:** DMEM / Interfaz CPU / `Load Select/Extend`.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** CPU y Debug necesitan seleccionar fila DMEM. Entregar palabra alineada y seleccionar byte/extensión en MEM distribuye responsabilidades según las interfaces; no implica superioridad física sin síntesis.

**Decisión:** Adoptar el [empaquetado de lectura](../architecture/memory/dmem_access.md#lectura-de-cpu): DMEM entrega `mem_read_data[31:0]` con los cuatro bytes lógicos de la palabra alineada que contiene la dirección. Dirección alta identifica fila y dos bits bajos posición. `Load Select/Extend`, fuera del módulo DMEM y dentro de MEM, usa posición/tamaño para extraer byte/halfword/word y realizar extensión signed/unsigned ya aprobada. Se conserva cero lógico por marca individual, little-endian y consulta Debug de byte/marca. Lectura y selección son combinacionales, sin registro ni ciclo adicionales.

**Justificación:** Conserva interfaz de 32 bits y consumidor de `address_low_bits` previstos. Mantiene lectura de fila y metadatos en DMEM y selección/extensión CPU en el bloque correspondiente. Mover selección dentro de DMEM era funcionalmente válido; no se afirma mejor área/frecuencia sin síntesis.

**Comprobación:** El modelo abstracto previo de seis capacidades verificó palabra lógica, posiciones y extensión en 572.936 lecturas sobre los patrones de la propuesta. No valida RTL, inferencia ni timing.

**Consecuencias y alcance pendiente:** Se concretan lectura CPU y ubicación de selección; escrituras/máscara relativa de cuatro bits, organización física de metadatos y mantenimiento siguen propuestas para revisión conjunta. No inferir su aprobación de este acuerdo; tampoco cerrar FPGA-01/02 ni implementar.

**Requisitos relacionados:** REQ-MEM-006/023/025/027/029, REQ-CPU-007 y requisitos ISA de loads.

**Reemplaza / Reemplazada por:** Resuelve la alternativa de empaquetado/ubicación antes abierta, preservando contratos funcionales y decisiones de memoria/sesión/Debug.

### Acuerdo de concreción de DEC-ARCH-006 — Máscara y alineación de escritura DMEM

**Estado del acuerdo:** Aprobado; concreción parcial de FPGA-01. FPGA-01/02 aún abiertos para mantenimiento y revisión conjunta.

**Dominio:** `DMEM Write Control` / Datos y marcas de stores.

**Fecha de aprobación:** 2026-10-05.

**Contexto:** La escritura utiliza máscara relativa de cuatro bits y alinea máscara/dato dentro de DMEM. `SB` en dirección 5 transforma 0001 en 0010 y actualiza byte/marca juntos.

**Decisión:** `byte_enable[3:0]` es máscara relativa al dato, generada combinacionalmente por `DMEM Write Control`: `SB`=0001, `SH`=0011, `SW`=1111, otros `mem_op`=0000. DMEM aplica Address[1:0]: `lane_mask`=`byte_enable`<<offset, en cuatro bits; `lane_write_data`=Write Data<<(8*offset), en 32. En `dmem_store_fire` efectivo captura los bytes seleccionados y pone esas mismas marcas en uno, conservando los demás datos/marcas. Usa dirección/dato `EX/MEM` preflanco; no agrega registro, ciclo, FSM ni entrada de dirección a `DMEM Write Control`. Alineación y región completa legales siguen garantizadas por EX y su `valid`; no se corrigen stores inválidos truncando máscaras.

**Justificación:** Mantiene las entradas del controlador de escritura y la dirección en DMEM; acomoda bytes/dato localmente con señales combinacionales y conserva atomicidad de dato/validez.

**Comprobación:** Modelo abstracto previo de seis capacidades verificó 44.072 stores, máscaras y sustituciones parciales, incluyendo valores cero que activan marca. No RTL/síntesis/timing.

**Consecuencias y alcance pendiente:** Máscara y alineación aprobadas; el siguiente bloque concreta almacenamiento de marcas y su ruta compartida con limpieza de preparación, prioridades/índices y revisión final local. No cerrar FPGA-01/02 todavía ni implementar.

**Requisitos relacionados:** REQ-MEM-006/017/023/027/029 y requisitos ISA de `SB`/`SH`/`SW`.

**Reemplaza / Reemplazada por:** Resuelve ancho/códigos y ubicación de adaptación de escritura previamente parciales; preserva commit de stores y semántica de sesión/Debug.

### Acuerdo de concreción de DEC-ARCH-006 — Camino compartido de marcas y mantenimiento DMEM

**Estado:** Aprobada.

**Dominio:** DMEM / Metadatos y preparación.

**Fecha:** 2026-10-05.

**Contexto:** CPU y preparación comparten la actualización de marcas mediante `prepare_dmem_clear`. Seleccionar dirección CPU no autoriza por sí solo store; limpieza y habilitación efectiva deben distinguirse.

**Decisión:** El camino de escritura de metadatos de cada `lane` comparte selección combinacional: `prepare_dmem_clear` elige fila de preparación y marca cero; en su ausencia elige fila CPU y marca uno. La habilitación afecta solo al byte preparado o a los lanes del store efectivo. Preparación conserva los datos físicos; store captura datos y marcas en el mismo flanco. Las cuatro agrupaciones por `lane` distribuyen el único bitmap por byte utilizado para cero lógico y Debug. No se agrega registro de propietario, FSM, contador ni copia de marcas.

**Concreción del contrato existente:** Prioridad `reset` > clear > store, derivada del control global; `reset` suprime ambas clases de escritura. CPU/preparación/Debug conservan exclusión aprobada. `prepare_done` no coincide con escrituras de mantenimiento. Índices completos se comprueban antes de estrecharlos para impedir alias; esto no introduce nuevas causas de fault ni sustituye la validación EX.

**Comprobación:** Modelo abstracto independiente por bytes, 10.279 flancos en seis capacidades, direcciones CPU/preparación distintas, todas las combinaciones `reset`/clear/store y recorridos completos. Revisión local de conexiones y flancos junto con lectura/escritura ya comprobadas; no RTL/síntesis/timing.

**Consecuencias y alcance pendiente:** [Acceso DMEM](../architecture/memory/dmem_access.md) consolida los tres acuerdos. FPGA-01/02 cerrados en diseño documental; plataforma, configuración/composición, representación, plan de verificación y revisión final FPGA permanecen abiertos. No se habilita implementación.

**Reemplaza / Reemplazada por:** Resuelve el camino compartido de metadatos/mantenimiento pendiente del acuerdo de escritura; conserva la semántica de preparación, `reset` y Debug.

### Acuerdo de concreción de DEC-ARCH-006 — Paquete común y propagación de configuración

**Estado:** Aprobada.

**Fecha:** 2026-10-05.

**Contexto:** Los perfiles y capacidades requieren una fuente común, separando constantes compartidas y privadas. Paquetes/parámetros SystemVerilog son una práctica documentada en UG901 e Ibex.

**Decisión:** Un paquete SystemVerilog `system_pkg` (futuro archivo `system_pkg.sv`) reúne definiciones compartidas: perfiles/capacidades y funciones comunes, configuración fija clock/UART, códigos de controles CPU/protocolo y tipos compartidos necesarios. Constantes privadas de una FSM/módulo quedan locales; anchos dependientes de capacidad se derivan por instancia, no se congelan al perfil por defecto. Paquete compilado antes de importadores; ninguna copia de estado ni recurso registrado nuevo.

**Ajuste de nombre (2026-10-06):** Se aprueba `system_pkg` / `system_pkg.sv` como denominación del paquete común. El alcance y la organización aprobados se conservan.

**Distribución:** El wrapper selecciona `MEMORY_PROFILE` una sola vez (`REFERENCE` por defecto), resuelve IMEM/DMEM y pasa ambas al sistema; padres las reenvían explícitamente a cada consumidor. Capacidades longint unsigned de 64 bits, extremos/límites de 33, direcciones arquitectónicas de 32 y anchos derivados positivos. Se conserva validación completa del tamaño UART de 40 bits. Parámetros omitidos/ilegales se rechazan antes de ejecutar; soporte de build diferenciado de dominio arquitectónico válido. Pines/constraints mantienen autoridad en XDC.

**Comprobación:** [Configuración común](../architecture/common_configuration.md) registra 89 capacidades, 623 comparaciones de anchos/extremos y nueve valores inválidos, incluidos mínimos, no potencias de dos y 2^32 sin asignar arrays enormes. Revisión de consumidores/anchos completada; no es elaboración ni simulación RTL.

**Consecuencias:** FPGA-03 cerrado en diseño documental. Continúan FPGA-05/06 composición/representación, FPGA-07/08 verificación/oráculo y FPGA-09 revisión final. Perfiles y valores ya aprobados se conservan; formato de configuración PC pospuesto, sin negociar perfil por UART ni habilitar implementación.

### Acuerdo de concreción de DEC-ARCH-006 — Jerarquía por etapas y agrupación selectiva de bloques

> **Revisado por la [agrupación del control global](#revisión-de-dec-arch-006--agrupación-del-control-global-de-ejecución) (2026-10-16).** Este acuerdo conserva la aprobación del 2026-10-06. La ubicación de las funciones del control global y los conteos se actualizan en la revisión posterior.

**Estado:** Aprobada.

**Fecha:** 2026-10-06.

**Contexto:** La jerarquía debe identificar los 54 bloques y justificar su agrupación. Se evaluaron organización monolítica, correspondencia uno a uno y etapas con submódulos seleccionados; se adopta esta última con `WB Bypass Control` explícito en WB.

**Decisión:** `basys3_top` integra placa, `clock_generator` (IP Clocking Wizard), `reset_sync` y `system_top`. `system_top` conecta `uart_core`, `protocol_controller`, `response_serializer` y `processor_top`. `processor_top` conecta `if_stage`/`id_stage`/`ex_stage`/`mem_stage`/`wb_stage`, cuatro módulos de registros interetapa, hazards, `execution_control`, Loader y preparación. `system_pkg` conserva su alcance aprobado. [Composición](../architecture/system_composition.md) concreta puertos, parámetros, aliases y representación integrada.

**Agrupación aprobada:** Los [54 bloques originales](../architecture/module_inventory.md#los-54-bloques-uno-por-uno) conservan archivo/ubicación explícitos: 26 como módulos específicos y 28 como lógica/estado local. Catálogo de 45 tipos incluido IP, con dos instancias `fifo`. El criterio es responsabilidad/reglas/valor de comprobación, no un archivo por bloque ni un número objetivo de módulos. Las unidades como `load_use_detector` y validadores se separan; muxes/sumadores simples, controles pequeños y recursos globales indicados quedan locales. `WB Bypass Control` se implementa íntegro en `wb_stage.sv`, no se agrega un submódulo que solo envuelva esa responsabilidad. `WB Value MUX` permanece en MEM y los cuatro registros interetapa en `processor_top`. Cada módulo propio usa archivo homónimo; la tabla es autoridad de nombres/ubicación, sin alterar señales ni contratos.

**Límites:** Se conservan los cuatro registros interetapa/campos, FSM global de 14 estados, recursos, latencias de memorias, puertos compartidos, preparación, faults y prioridades de ciclo. No se agregan registros, FSM o clocks por modularizar. Recursos internos UART/controlador/serializador conservan las agrupaciones aprobadas. La alternativa de un módulo por bloque se evaluó y no se adoptó.

**Comprobación y representación:** [Revisión local](../architecture/system_composition.md#revisión-local-y-cierre-de-composición) registra cobertura única de 54 IDs, padres/nombres, parámetros, comandos/carga, WB, `next.valid`, preparación/DMEM, Debug/faults, transporte y plataforma; 34 campos de registros interetapa suman 504 bits. Mermaid y tablas integradas remiten al detalle de los 54 contratos; los dibujos de presentación son complementarios y no se certifican todos sus cables. No se modifica RTL ni se presenta evidencia de elaboración/simulación/síntesis/timing/placa.

**Consecuencias:** FPGA-05/06 cerrados en diseño documental. Continúan FPGA-07/08 (plan de verificación/oráculo) y FPGA-09 (revisión final integral). Assembler/aplicación PC pospuestos y D0/M6 global sigue abierto; no se habilita implementación.

### Revisión de DEC-ARCH-006 — Agrupación del control global de ejecución

**Estado:** Aprobada.

**Fecha:** 2026-10-16.

**Contexto:** El [acuerdo 48 de DEC-ARCH-003](DEC-ARCH-003.md#acuerdo-48-aprobado--integración-del-control-global-de-ejecución) integra selección de comandos, autorización de ciclos y salidas Moore/Mealy en `Global FSM`. La jerarquía y el inventario concretan esa organización.

**Decisión:** `Execution Control` se realiza en `execution_control.sv` y contiene el submódulo `global_fsm.sv`. Las funciones se ubican así:

| Función                                                                                   | Archivo / ubicación                                              |
|-------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| Fase de sesión, selección de comandos, autorización de ciclos y decodificación de salidas | `global_fsm.sv`, hijo de `execution_control`                     |
| Selección de metadatos y evento de captura de fault                                       | Lógica combinacional local en `execution_control.sv`             |
| Registros de causa/PC de fault, tamaño confirmado y contador de ciclos                    | Estado local en `execution_control.sv`                           |
| Reducción de los cuatro próximos `valid` para `pipeline_empty_next`                       | Lógica combinacional local en `execution_control.sv`             |
| Loader y preparación de sesión                                                            | `loader.sv` y `session_preparation.sv`, hijos de `processor_top` |

**Totales revisados:** Los 51 bloques vigentes de Interfaces se distribuyen en 23 módulos específicos y 28 bloques de lógica/estado local. `Execution Control` reúne siete bloques: un submódulo y seis bloques locales. Los 19 tipos de integración, transporte y placa completan un catálogo de 42 tipos, incluido el IP de clock. Corresponden 41 archivos `.sv` de módulos propios, más `system_pkg.sv` como paquete compartido; `fifo` conserva dos instancias.

**Contratos conservados:** La agrupación mantiene los catorce estados de sesión, las prioridades y efectos del pipeline, las latencias de memorias, ownership, cero lógico, publicación de imagen, preparación y observación Debug. Las acciones sobre los recursos se realizan al consumir sus habilitaciones.

**Comprobación:** El [inventario vigente](../architecture/module_inventory.md#bloques-cpu-uno-por-uno) y la [composición](../architecture/system_composition.md#cobertura-de-los-bloques-cpu) relacionan cada ID con su módulo, archivo y ubicación. Se contrastan nombres únicos, padres, cobertura por ubicación y totales. La comprobación es documental.

**Reemplaza / Reemplazada por:** Revisa la ubicación de las funciones del control global y los conteos del acuerdo de jerarquía del 2026-10-06. Los acuerdos de memoria y configuración conservan su alcance.
