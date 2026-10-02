# Auditoría integral de documentación

> **Vigencia de esta evidencia — 2026-09-30.** Este informe conserva las comprobaciones y conclusiones de las revisiones anteriores. El mapa y estado documental actuales están en [README](README.md) y en [la auditoría final de integración](docs_integration_audit.md). La Rev. 03 de TeX/SVG fue retirada por migración a draw.io, según la aclaración registrada en AUD2-001 de [la segunda auditoría](docs_audit_v2.md); sus resultados y comandos de reproducción describen el artefacto histórico, no una figura disponible actualmente ni una certificación de la versión externa.

> **Actualización posterior — interfaces.** [docs/interfaces.md](docs/interfaces.md) ya existe y formaliza el mapa de bloques; la mención a su ausencia como entregable futuro más abajo describe el estado histórico auditado. Su [verificación documental](docs/interfaces_audit.md) no acredita cierre global de interfaces, RTL ni simulación.

## Reauditoría consolidada — 2026-09-26

**Resultado: AUD-001 a AUD-013 cerrados documentalmente.** Se propagaron las tres resoluciones aprobadas y las diez correcciones objetivas. No queda ninguno de los tres hallazgos iniciales esperando una decisión humana. No se detectaron contradicciones residuales vigentes de esos hallazgos en esta reauditoría; esto no declara implementado ni verificado el RTL.

AUD-005 se formalizó como **revisión de DEC-SYS-006**, sin crear un ADR nuevo. `cycle_count[63:0]` es unsigned: cero antes del primer ciclo de cada sesión, uno después; incrementa una vez por `cpu_cycle_fire` módulo `2^64`. El máximo pasa a cero sin fault, detención, cambio de `global_state`, flag de overflow ni estado persistente adicional. HOLD conserva el valor. Reset e inicialización efectiva mantienen prioridad; el orden de bytes y framing UART siguen pendientes.

### Cierre por hallazgo

Las ubicaciones siguientes corresponden a esta revisión. Cada fila tiene estado **cerrado documentalmente**; los criterios de prueba RTL agregados al plan siguen siendo trabajo futuro.

| Hallazgo | Corrección y contrato vigente | Evidencia |
|---|---|---|
| AUD-001 | Acuerdo 47: IF detecta; todo fetch fault confirma en ID; ocho acciones y matriz 46 revisada. | `docs/decisions.md:3120` |
| AUD-002 | Sesión nueva desde FINISHED/FAULT, LOAD elegible por estado y primer ciclo en prepare_done propagados a ARCH-008 y pruebas. | `docs/decisions.md:4294`; `docs/plan.md:1225` |
| AUD-003 | Datapath Rev. 03 histórico: rutas corregidas, alcance visible y SVG regenerado desde el TeX; control incluido. | Archivos retirados: `docs/figures/pipeline_datapath.tex` / `docs/figures/pipeline_datapath.svg` |
| AUD-004 | Dirección efectiva modular de 32 bits; región comprobada en 33 bits; carry inicial sin fault. | `docs/decisions.md:655`; `docs/plan.md:1613` |
| AUD-005 | Revisión explícita de SYS-006: cycle_count unsigned de 64 bits, incremento módulo 2^64 sin efectos extra; solo UART pendiente. | `docs/decisions.md:452`; `docs/requirements.md:193` |
| AUD-006 | Resúmenes/gates remiten al control aprobado 40–47, matriz cerrada y FSM 44; reset limpia el candidato IF/ID y terminal_write_enable es alias de evento. | `docs/plan.md:883`; `docs/requirements.md:150` |
| AUD-007 | Prueba del decoder: ADD/IMMEDIATE para jal/lui, ADD/RS2 para halt, según la tabla aprobada. | `docs/plan.md:725` |
| AUD-008 | Referencias a acuerdos 3A y 37 apuntan a decisions, donde están aprobados. | `docs/plan.md:601`; `docs/plan.md:621` |
| AUD-009 | Backlinks DOC-008 en ARCH-002/003; SYS-009 depende de SYS-001, incluye SW-012 y conserva halt custom. | `docs/pending_decisions.md:169` |
| AUD-010 | Modelo de referencia contempla siete causas, PC causante, ausencia de efectos y distinción target/fetch. | `docs/plan.md:2058` |
| AUD-011 | ALU RV32 usa shamt de cinco bits; SRA signed y bits fijos SRAI excluidos. Adaptación sin cambiar TPs anteriores. | `docs/decisions.md:2062`; `docs/plan.md:805` |
| AUD-012 | Ejemplos usan CPU-002, EXEC-009, DBG-005, ISA-008/018 y HAZ-004; comando conceptual STEP. | `docs/plan.md:182`; `docs/plan.md:1451` |
| AUD-013 | M1 se denomina Decision Freeze de forma consistente. | `docs/pending_decisions.md:35` |

### Alcance y verificación ejecutada

Se cruzaron las correcciones con `decisions.md`, `requirements.md`, `plan.md`, `pending_decisions.md` y las figuras; se buscaron afirmaciones residuales de las trece incidencias y se revisaron las ecuaciones afectadas. Se conservaron **160 requisitos, 14 decisiones aprobadas, 8 decisiones pendientes y 47 acuerdos en DEC-ARCH-003**. No se modificaron la consigna, los TPs anteriores ni políticas UART/Debug aún abiertas.

| Comprobación | Resultado |
|---|---|
| AUD-001: ecuaciones extraídas del acuerdo 47 | 1.536 combinaciones: exclusión/cobertura de ocho acciones, confirmación EX/ID y partición de enables; todas correctas |
| AUD-001: secuencias temporales documentales | 18 trazas RUN y STEP/HOLD; branch tomado descarta fetch PC=8; store desalineado confirma causa 110, PC=4, sin entrar válido a MEM |
| AUD-002: ecuaciones de Cycle Authorization del acuerdo 44 | 448 combinaciones de 14 estados, solicitudes, reset y prepare_done, aplicando elegibilidad y prioridad de comandos; todas correctas |
| AUD-004: aritmética y límites | 11 vectores del plan y 144 comparaciones de región completa contra cada byte; todas correctas |
| AUD-005: contador | 8 vectores de cero, máximo, incremento, HOLD e inicialización dominante; incluido máximo→0 sin saturación |
| AUD-011: shifts RV32 | 15 resultados SLL/SRL/SRA para cantidades 0, 31, 32, 33 y 0xFFFFFFFF; selección de cinco bits correcta |
| IDs y trazabilidad | 160 IDs únicos; todas las referencias REQ/DEC numéricas existen; backlinks DOC-008 y SW-012 presentes; ningún ADR nuevo |
| Estructura documental | Bloques Markdown y detalles históricos balanceados; conteos vigentes y referencias corregidos |
| Diagrama Rev. 03 | TeX compilado a una página sin warnings de layout; SVG exportado desde ese PDF, XML válido e inspección visual de rutas/rótulos |

Las comprobaciones de ecuaciones y trazas son modelos documentales temporales, no simulaciones del CPU. Las trazas de AUD-001 fijan condiciones/resultados de operandos para comprobar orden y validez, sin simular el datapath completo. Los vectores del contador verifican su aritmética; el plan exige además comprobar en RTL que su wrap no afecta otros estados. El modelo secuencial completo, testbenches, síntesis, timing y validación física aún no existen en este TP3.

Para el dibujo se preservó el contrato funcional con nets etiquetadas: Next-PC MUX tiene PC+4 y target; el inmediato llega a ID/EX y al selector de ALU; branches usan SUB/ALU.zero; Result MUX selecciona ALU/IMM/LINK; Target Adder y JALR Adder alimentan Target MUX; dirección y store_data llegan a DMEM separados. Forwarding, bypass WB→ID y controles tienen referencias explícitas. La lámina declara sus omisiones de cables individuales, interior de validadores y tecnología física; no pospone los campos internos a DEC-ARCH-009. Se usa TikZ con la biblioteca local, sin requerir CircuitikZ para esta lámina.

Reproducción de la exportación desde `docs/figures` (crear antes el directorio temporal):

```sh
mkdir -p /tmp/tp3-diagram
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=/tmp/tp3-diagram pipeline_datapath.tex
pdftocairo -svg /tmp/tp3-diagram/pipeline_datapath.pdf pipeline_datapath.svg
```

### Referencias residuales e historia

**Cero referencias normativas vigentes** a la confirmación directa de fetch en IF, a nueve acciones, a siete acciones no terminales o al ancho/overflow de cycle_count como pendiente. La búsqueda incluye texto y ecuaciones; la historia no se toma como contrato implementable. UART continúa abierto exclusivamente en su representación de los 64 bits.

Los acuerdos históricos de ARCH-003 conservan sus avisos de revisión, y las auditorías anteriores se archivan debajo íntegramente. Por eso una búsqueda literal todavía encuentra los términos retirados en historia y en este inventario; no significan que la excepción siga vigente. Ubicaciones históricas en el `decisions.md` actual:

| Término retirado | Apariciones históricas | Líneas |
|---|---:|---|
| `if_fault_exception_confirm` | 8 | 2446, 2452, 2468, 2518, 2532, 2537, 2558, 2591 |
| `act_if_fault_exception` | 11 | 2558, 2573, 2607, 2629, 2663, 2696, 2719, 2745, 2823, 3022, 3097 |
| `IF excepcional` | 17 | 1025, 1758, 1810, 1854, 2038, 2056, 2078, 2151, 2251, 2315, 2478, 2524, 2654, 3016, 3017, 3097 |
| `nueve acciones` | 10 | 1334, 1941, 2478, 2551, 2602, 2719, 2881, 3006, 3097, 3109 |

Las afirmaciones originales de que AUD-001/004/005 requerían decisión y las propuestas aún «no aplicadas» que aparecen en el archivo histórico describen exclusivamente la auditoría inicial. Las reauditorías parciales de AUD-001 y AUD-004 también conservan su estado y sus números de línea de aquel momento; este cierre consolidado las sucede. Las anotaciones nuevas sobre contador, shifts y región explicitan las aclaraciones aprobadas sin borrar el desarrollo histórico de ARCH-003.

### Pendientes reales conservados

Siguen abiertos los ocho ADR ya registrados: **DEC-SYS-007, DEC-SYS-009, DEC-ARCH-009, DEC-SYS-005, DEC-PROTO-001, DEC-PROTO-002, DEC-PROTO-003 y DEC-SYS-008**. Abarcan comunicación, assembler, representación externa del pipeline, criterio de memoria utilizada, protocolo y aplicación PC. El ancho y overflow del contador ya no son parte de esos pendientes; solo su transporte UART debe integrarse al protocolo. No se cambian sus condiciones de cierre ni se declaran alcanzados M2–M6 por esta auditoría documental.

Los siguientes pasos son cerrar los ADR necesarios para cada hito y ejecutar el plan de implementación/verificación. La documentación revisada y el diagrama Rev. 03 constituyen la referencia para ese trabajo; no sustituyen sus pruebas.

## Archivo de auditorías anteriores

**Historia anterior a este cierre consolidado.** Sus estados, citas, números de línea y propuestas deben leerse en la fecha/revisión que documentan, no como restricciones vigentes. Se conserva íntegro el contenido anterior para trazabilidad.

<details>
<summary>Auditoría inicial y cierres parciales anteriores a la resolución de AUD-005 y las diez correcciones</summary>

## Estado vigente tras las resoluciones aprobadas

**Actualizado: 2026-09-26.** AUD-001 y AUD-004 están resueltos documentalmente. **AUD-005 es el único hallazgo de esta auditoría que todavía requiere una decisión humana:** ancho y comportamiento ante overflow de `cycle_count`. No se asume ancho, wrap ni saturación. Los otros diez hallazgos conservan su estado pendiente de corrección/verificación; no requieren una nueva política según la auditoría inicial.

## Cierre de AUD-004 — dirección modular y región ensanchada

**Resolución aprobada y aplicada (2026-09-26).** Se aclaran `DEC-ARCH-001` y `DEC-ARCH-004`, los criterios relacionados de REQ-MEM-017, la obligación y aceptación de REQ-MEM-018 y las pruebas del plan. Se añade una anotación de alcance a las ecuaciones históricas del acuerdo 40 de `DEC-ARCH-003`; el acuerdo 47 permanece intacto.

```text
effective_address = (rs1_effective + immediate) mod 2^32
rango DMEM válido = ({1'b0, effective_address} + N <= DMEM_CAPACITY_BYTES)
```

La primera suma usa el inmediato con signo extendido a 32 bits y la aritmética arquitectónica de 32 bits. **Su carry no constituye por sí mismo un fault.** La segunda suma y su comparación son sin signo de 33 bits, con `N=1/2/4` y capacidad sin truncamiento: se comprueban todos los bytes antes de indexar memoria, sin reducir el extremo módulo `2^32`. La alineación parte de la dirección efectiva modular y conserva su prioridad sobre access fault cuando ambas condiciones fallan.

**Verificación ejecutada:** los once vectores de aceptación agregados al plan coinciden con las ecuaciones; además, 144 combinaciones de dirección/ancho/capacidad contrastan la comparación del extremo con la pertenencia individual de todos los bytes. Incluyen capacidades no potencia de dos y el límite conceptual `2^32`, sin asignar una memoria física de ese tamaño. En particular:

- `0xFFFFFFFF + 1`, BYTE y capacidad 2048: dirección efectiva 0, rango y alineación válidos; el carry no rechaza el acceso.
- `0xFFFFFFFC + 4`, WORD y capacidad 2048: dirección efectiva 0, acceso válido bajo las restantes condiciones.
- Dirección efectiva `0xFFFFFFFF`, N=2 y capacidad `2^32`: extremo `0x100000001`, rango inválido; también desalineado, por lo que conserva la causa de desalineación.
- Dirección efectiva `0xFFFFFFFF`, N=1 y capacidad `2^32`: extremo exactamente `2^32`, rango válido; ese límite exclusivo no se trunca a cero.

Se comprobaron la conservación de los 160 identificadores de requisitos, del acuerdo 47 y de todas las líneas que definen o difieren la política de `cycle_count`. La búsqueda de la prohibición ambigua ya no la encuentra en contratos vigentes; permanece citada únicamente como evidencia de la auditoría inicial archivada. La suma abreviada del acuerdo 40 se conserva como historia con una anotación explícita de su interpretación modular. Estas son comprobaciones documentales y aritméticas, no simulación RTL.

**Resultado: AUD-004 resuelto.** No se agrega causa de fault por carry, registro ni cambio a la política de alineación, atomicidad, confirmación o drenado.

## Reauditoría de AUD-001 — acuerdo 47 aplicado

**Fecha:** 2026-09-26. **Resultado: AUD-001 resuelto documentalmente.** La resolución aprobada se incorporó como revisión explícita de `DEC-ARCH-003`, acuerdo 47. La confirmación anticipada desde IF deja de ser una política implementable. Esta reauditoría evaluó únicamente AUD-001; AUD-004 se cierra en la resolución registrada arriba. Los otros once hallazgos conservan su estado previo.

### Contrato vigente y propagación

- **IF solo detecta candidatos y todo fetch fault se confirma en ID**, tras IF→IF/ID→ID. Durante load-use sin frontera anterior EX/ID solo se aplica `act_load_use`: PC/IF/ID retenidos, bubble ID/EX y avance del load. El mismo PC permite redetectar y capturar después el candidato, sin registro adicional.
- `fault_confirm = ex_fault_confirm || id_fault_confirm`; `fault_capture_fire = fault_confirm`. Para fetch confirmado se captura `IF/ID.pc`, nunca el PC global de IF. La frontera EX del consumidor anterior precede a ID.
- Ocho acciones: seis no terminales y dos de drenado. Se revisaron listas, `$onehot0`, `pipeline_action`, enables de IF/ID, ID/EX y EX/MEM, captura MEM/WB y metadatos globales. Se conservan las dos acciones de drenado, sin nueva FSM, registros o campos.
- [decisions.md](docs/decisions.md): acuerdo 47, resumen vigente de 47 acuerdos, matriz 46 revisada y referencias de `DEC-ARCH-004`. Los cuerpos históricos de acuerdos 1–45 se conservaron literalmente, agregando avisos de revisión donde corresponde; la versión original del 46 se archivó junto a su matriz vigente.
- [requirements.md](docs/requirements.md): criterios de REQ-CPU-010/011, REQ-HAZ-004/010, REQ-MEM-016 y REQ-EXEC-018. Se preservaron los 160 identificadores, tipos, descripciones y fuentes.
- [plan.md](docs/plan.md): política vigente, acciones y ecuaciones, pruebas de PC/latches, metadatos, arbitraje y secuencias de stall/confirmación/drenado. Las pruebas ya no esperan entrar en FAULT_DRAIN durante el stall del candidato IF.

Se revisaron también README, consigna, pending_decisions y los diagramas de `docs/figures`. No describen la excepción retirada y no necesitaron cambios por AUD-001. Los defectos de diagramas registrados en AUD-003 quedan fuera de esta revisión. No se cambiaron otras políticas arquitectónicas.

### Comprobaciones ejecutadas

Se extrajeron las ecuaciones del acuerdo 47 y se evaluaron **1.536 combinaciones booleanas**: autorización de ciclo; contexto no terminal, drenado o terminal vacío; candidatos EX; validez/candidato/decodificación ID; load-use y candidato IF. Se verificaron exclusión y cobertura de ocho acciones, equivalencia de `pipeline_action`, confirmación exclusiva EX/ID y partición captura/retención/invalidez de los latches. El candidato IF no interviene en la selección de acciones.

Además se evaluaron **18 trazas documentales**: nueve consumidores/fronteras (branch tomado/no tomado, ALU, jalr alineado/desalineado, store desalineado, load desalineado/fuera de rango y halt), en RUN y en secuencia de ciclos STEP con HOLD intercalado. Se comprobaron las identidades y validez preflanco/postflanco, la etapa confirmante y causa/PC; no se simularon instrucciones RTL ni el datapath completo. Las entradas de branch, dirección y resultado de forwarding se fijaron según cada escenario.

Los contraejemplos originales con imagen de 8 bytes y load en PC=0 quedan así:

| Ciclo efectivo | Estado previo | Acción / resultado revisado |
|---|---|---|
| 3 | Load EX, consumidor ID, candidato IF en PC=8 | `act_load_use`; retener PC/IF/ID, bubble ID/EX; ninguna confirmación ni captura del candidato |
| 4 | Load MEM, consumidor ID, candidato todavía en PC=8 | `act_normal`; consumidor a ID/EX y candidato a IF/ID; PC=12; todavía sin fault |
| 5, branch tomado | Branch EX, candidato ID, load WB | `act_redirect` al PC=0; descartar candidato, sin FAULT especulativo; load anterior completa |
| 5, store desalineado | Store EX, candidato ID, load WB | `act_ex_fault`; causa `110`, PC=4; store no entra válido a EX/MEM y no habilita escritura; load anterior completa |
| 5, ALU o branch no tomado | Consumidor EX sin frontera, candidato ID | `act_id_fault`; causa `001`, PC=8 desde IF/ID; consumidor anterior progresa y completa |

La diferencia entre PC global=12 y fault_pc=8 en el último caso comprueba la fuente de metadatos. HOLD no selecciona acciones ni captura el fault. Con el nuevo contrato las confirmaciones EX/ID invalidan IF/ID e ID/EX: no comienza un drenado con el consumidor anterior retenido en ID por el fetch joven. Se mantuvieron las ecuaciones de las dos acciones de drenado aprobadas.

Se verificó además la conservación literal de la historia de los acuerdos y de las columnas de identidad/trazabilidad de los 160 requisitos. **Esto valida la revisión documental y los escenarios evaluados; la implementación y verificación RTL siguen pendientes.**

### Referencias residuales solicitadas

La búsqueda literal sobre todos los archivos del TP3 y la revisión semántica de confirmaciones, fuentes de PC y secuencias temporales no encontraron ninguna afirmación **vigente** que permita confirmar un fetch fault en IF. En requirements, plan, README, pending_decisions, consigna y fuentes de figuras hay **cero** apariciones de los cuatro términos siguientes.

Las coincidencias conservadas en decisions están exclusivamente dentro de acuerdos históricos rotulados como revisados por el 47 o de la versión archivada del acuerdo 46. Las coincidencias de la auditoría inicial se conservan abajo como evidencia anterior a la revisión. Las menciones de esta tabla son un inventario, no señales o acciones vigentes.

| Referencia literal | Normativa vigente | Historia de decisions | Auditoría inicial archivada |
|---|---:|---:|---:|
| `if_fault_exception_confirm` | 0 | 8 | 1 |
| `act_if_fault_exception` | 0 | 11 | 0 |
| `IF excepcional` | 0 | 17 | 0 |
| `nueve acciones` | 0 | 10 | 2 |

Ubicaciones de esas coincidencias en `docs/decisions.md` (líneas de esta revisión; una línea puede contener más de una aparición):

- `if_fault_exception_confirm`: 2424, 2430, 2446, 2496, 2510, 2515, 2536, 2569.
- `act_if_fault_exception`: 2536, 2551, 2585, 2607, 2641, 2674, 2697, 2723, 2801, 3000, 3075.
- `IF excepcional`: 1005, 1738, 1790, 1834, 2018, 2036, 2056, 2129, 2229, 2293, 2456, 2502, 2632, 2994, 2995, 3075.
- `nueve acciones`: 1314, 1921, 2456, 2529, 2580, 2697, 2859, 2984, 3075, 3087.

Las descripciones históricas de confirmación directa en IF y las antiguas prioridades EX→ID→IF se conservan bajo los mismos avisos de revisión; ninguna prescribe el comportamiento actual. El conteo vigente es **47 acuerdos, ocho acciones y seis acciones no terminales**. Las menciones históricas a 46 acuerdos y a los conteos anteriores se mantienen expresamente como historia revisada. Se conservaron los conteos ajenos a esta revisión, como las siete causas de fault y los nueve códigos válidos de `mem_op`.

### Auditoría inicial conservada como historia

El informe siguiente describe la documentación **anterior al acuerdo 47 y a la aclaración aprobada de AUD-004**. Sus citas, números de línea, diagnósticos de vigencia y propuestas reflejan ese momento; especialmente AUD-001, las ecuaciones de la excepción y la ambigüedad de AUD-004 quedan sustituidos por las resoluciones anteriores. Su conservación permite rastrear el problema y no restablece la política retirada. Los demás hallazgos conservan su estado previo.

<details>
<summary>Informe original del 2026-09-26, anterior a la revisión aprobada de AUD-001</summary>

## 1. Resumen ejecutivo

Auditoría del TP3 realizada el **2026-09-26**. Se identificaron **13 hallazgos: 1 CRITICAL, 2 HIGH, 8 MEDIUM y 2 LOW**. Requieren decisión o aclaración humana **AUD-001, AUD-004 y AUD-005**. Los otros diez admiten correcciones documentales basadas en acuerdos existentes; sus parches se proponen en §8 y **no se aplicaron**.

| Severidad | Cantidad | Hallazgos |
|---|---:|---|
| CRITICAL | 1 | AUD-001 |
| HIGH | 2 | AUD-002, AUD-003 |
| MEDIUM | 8 | AUD-004 a AUD-011 |
| LOW | 2 | AUD-012, AUD-013 |

**No conviene congelar el control ni comenzar su RTL con la documentación actual.** La confirmación excepcional de un fault en IF puede adelantarse a un branch dependiente todavía en ID, impedir su redirect y convertir un fetch especulativo en error definitivo. Con un store dependiente, puede además habilitarse una escritura que debería fallar. No es una diferencia editorial ni queda resuelta por la exclusión mutua de acciones.

La arquitectura tiene una base documental extensa y mayormente coherente. Una vez resuelto ese caso temporal, aclarados los dos pendientes humanos restantes y propagadas las correcciones objetivas, será razonable elaborar los diagramas arquitectónicos completos. El paso posterior a RTL requiere además los contratos y gates del plan: no equivale a declarar M2–M6 cumplidos ni a resolver por adelantado UART, protocolo, Debug o software.

**Alcance y método.** Se leyeron completos `README.md`, `docs/consigna.md` (745 líneas), `docs/requirements.md` (243), `docs/decisions.md` (4512), `docs/pending_decisions.md` (199), `docs/plan.md` (2594), `docs/figures/pipeline_components.tex` (75) y `docs/figures/pipeline_datapath.tex` (189). El SVG de 7299 líneas se analizó como XML completo y se renderizó para inspeccionar sus rutas y rótulos; sus textos están convertidos en trazados, no en nodos de texto. También se revisaron el README del directorio padre y la ALU de TP1/TP2 **solo para comprobar la referencia de reutilización de la documentación**, sin auditar ni modificar esos proyectos. `.gitignore` y los `.gitkeep` no contienen contratos arquitectónicos adicionales. En TP3 no hay implementación ni bancos de prueba, solo directorios preparados.

Se cruzaron **160 requisitos, 14 decisiones aprobadas y 8 pendientes**, incluidos sus identificadores, orígenes y listas de requisitos afectados. Se contrastaron tablas de decode, campos, códigos, ecuaciones de control, transiciones preflanco/postflanco, límites de memoria y casos adversariales. Las evaluaciones puntuales de ecuaciones son comprobaciones de la especificación, **no simulación de RTL ni prueba formal exhaustiva**. Las líneas citadas corresponden a los originales anteriores a este informe.

Se preservó la jerarquía solicitada: consigna como obligación externa; requirements como obligaciones trazables; decisions como elecciones aprobadas; pending_decisions como asuntos abiertos; plan como proceso. Se distingue **A: historia legítima**, **B: historia o resumen engañosamente vigente**, **C: incompatibilidad vigente**. En particular, `decisions.md:977` conserva expresamente los acuerdos 1–45 como historia y hace prevalecer las revisiones posteriores: no se contabilizó cada antigua mención de «pendiente» como un error independiente.

## 2. Hallazgos

| ID | Severidad | Tipo | Archivo(s) | Ubicación | Problema | Impacto | Resolución sugerida |
|---|---|---|---|---|---|---|---|
| AUD-001 | CRITICAL | PIPELINE_TIMING | decisions, requirements, plan | ARCH-003 acuerdos 29–46; ARCH-004 §prioridad | Fault IF se confirma antes de resolver al consumidor anterior | Redirect perdido o store defectuoso habilitado | Revisar humanamente la frontera temporal y volver a validar sus ecuaciones |
| AUD-002 | HIGH | STALE_STATE | decisions, plan | ARCH-008; plan fases 11 y 14 | Reglas antiguas de comandos, preparación y recuperación contradicen el acuerdo 44 | FSM y pruebas con comportamiento distinto | Propagar la FSM vigente y conservar historia rotulada |
| AUD-003 | HIGH | STALE_STATE | figures/*.tex, *.svg | Datapath Rev. 02 | Dibujo incompleto y rutas diferentes de las aprobadas; SVG no actualizado respecto del TeX | Implementación imposible de varias instrucciones si se toma como contrato | Marcarlo provisional y actualizar rutas conforme a ADR, sin nuevas decisiones |
| AUD-004 | MEDIUM | FORMULA_OR_WIDTH | requirements, decisions, plan | REQ-MEM-018; dirección efectiva | No se delimita qué suma está protegida contra overflow | Interpretaciones distintas de base+offset y extremo de región | Aclarar alcance y vectores límite mediante revisión humana |
| AUD-005 | MEDIUM | MISSING_DECISION | decisions, pending_decisions, plan | SYS-006; ARCH-003 acuerdo 44 | Ancho/overflow de cycle_count diferidos a una decisión ya aprobada y ausentes del registro de pendientes | Interfaz observable incompleta | Asignar responsable y cerrar política sin inventar valor |
| AUD-006 | MEDIUM | STALE_STATE | decisions, requirements, plan | Contexto ARCH-003; gates y resúmenes | Ecuaciones y matriz cerradas siguen presentadas como pendientes | Bloqueos ficticios y reapertura accidental | Actualizar resúmenes y distinguir cierre documental de verificación ejecutada |
| AUD-007 | MEDIUM | CONTRADICTION | plan, decisions | plan:723; decoder acuerdo 37 | Prueba exige RS2 para jal/lui pese a alu_src=1 | Test falla ante decoder correcto | Corregir expectativas a IMMEDIATE para jal/lui |
| AUD-008 | MEDIUM | BROKEN_REFERENCE | plan | 599, 619 | Acuerdos aprobados se buscan en pending_decisions | Referencias sin destino semántico | Apuntar a decisions y acuerdo correspondiente |
| AUD-009 | MEDIUM | TRACEABILITY | decisions, pending_decisions | DOC-008; SYS-009 | Falta vínculo de hazards con DOC-008 y de assembler con halt | Cobertura incompleta en matrices por ADR | Añadir backlinks y dependencia SYS-001 sin cambiar políticas |
| AUD-010 | MEDIUM | DOCUMENTATION | plan | Fase 15, 2034–2041 | Modelo de referencia omite ilegal y target desalineado como resultados explícitos | Oráculo parcial de faults y PC causante | Ampliar contrato del modelo con semántica ya aprobada |
| AUD-011 | MEDIUM | AMBIGUITY | decisions, plan | Contrato de ALU heredada | Adaptación de shifts a cinco bits queda implícita | Reutilización literal conserva shifts incorrectos para RV32 | Explicitar shamt RV32 y pruebas de adaptación |
| AUD-012 | LOW | TRACEABILITY | plan | 179–187, 1449–1454 | Ejemplos usan IDs ajenos o asignados a otro requisito | Matrices copiadas quedan mal trazadas | Usar identificadores reales |
| AUD-013 | LOW | TERMINOLOGY | pending_decisions, plan | M1 | System Freeze frente a Decision Freeze | Nombres diferentes para el mismo hito | Unificar nombre sin cambiar su condición |

### AUD-001 — La excepción de fault IF viola la antigüedad a través de varios ciclos

**Severidad:** CRITICAL  
**Tipo:** PIPELINE_TIMING  
**Archivos afectados:** `docs/decisions.md`, `docs/requirements.md`, `docs/plan.md`.

**Evidencia exacta:**

- `decisions.md:2376–2379`: `if_fault_exception_confirm = cpu_cycle_fire && terminal_none && !ex_frontier && !id_fault_candidate && load_use_stall && if_fetch_fault_candidate`.
- `decisions.md:2360–2370`: tanto `ex_fault_confirm` como `redirect_apply` requieren `terminal_none`.
- `decisions.md:2585`: `idex_capture_id = act_normal || act_drain_advance`.
- `decisions.md:2620–2628`: `act_drain_advance` habilita `exmem_capture_ex`, que asigna `EX/MEM.next.valid = ID/EX.valid`.
- `requirements.md:127`: `dmem_store_fire=cpu_cycle_fire && EX/MEM.valid && is_store(EX/MEM.mem_op)` y «Las comprobaciones arquitectónicas no se repiten en MEM».
- `decisions.md:2852`: «Para ciclos de drenado ya terminales no se confirma otra frontera».
- `decisions.md:3128`: «prioridad estricta por **antigüedad de programa**» y «La etapa donde se detectó cada condición no reemplaza el orden del flujo».
- `requirements.md:165`: «**Todas las anteriores aún activas completan normalmente**».

**Por qué es inconsistente:** Es **C**, una contradicción temporal vigente. La selección EX→ID→IF ordena correctamente los eventos visibles *en un ciclo*, pero el consumidor retenido en ID es más antiguo que IF y todavía puede producir una redirección o su propio fault cuando llegue a EX. «Sin frontera EX/ID» no prueba que ese consumidor vaya a sobrevivir sin otra frontera. Tras confirmar IF, el drenado le permite avanzar, pero le prohíbe confirmar su evento posterior.

Contraejemplo A, con perfil REFERENCE, imagen confirmada de **8 bytes**, DMEM inicial lógica cero y ejecución RUN:

```asm
# PC 0
lw  x1, 0(x0)
# PC 4
beq x1, x0, -4       # destino 0, tomado porque x1 recibe cero
```

No se exige un halt en la imagen; este loop es admisible por DEC-SYS-002.

| Ciclo efectivo | Estado relevante antes del flanco | Consecuencia de las ecuaciones vigentes |
|---|---|---|
| 1 | PC=0, pipeline vacío | Captura lw; PC=4 |
| 2 | lw en ID, fetch branch en PC=4 | lw pasa a EX; branch queda en IF/ID; PC=8 |
| 3 | lw válido en EX, branch dependiente en ID, IF fuera del prefijo | load-use=1; sin fault propio EX ni ilegal ID; se confirma fault IF, causa 001, fault_pc=8; branch retenido; bubble ID/EX |
| 4 | FAULT_DRAIN_AUTO; load en MEM, branch en ID | load pasa a MEM/WB; branch pasa a ID/EX sin fetch nuevo |
| 5 | branch en EX, load en WB | Forwarding entrega cero; redirect_requested=1 y target=0, pero terminal_none=0 fuerza redirect_apply=0 |
| Posteriores | Drenado de las entradas restantes | Se alcanza FAULT con PC causante 8, aunque el fetch era del camino que el branch debía descartar |

El test con consumidor ALU ordinario pasa; no detecta el defecto. Tampoco lo detecta `$onehot0`, porque en cada ciclo puede seguir habiendo exactamente una acción.

Contraejemplo B: reemplazar la segunda instrucción por `sw x1, 2(x0)`. El uso real de rs2 conserva el load-use del ciclo 3. En el ciclo 5 el store presenta `store_misaligned_candidate=1`; es más antiguo que el fetch PC=8. Sin embargo, `ex_fault_confirm=0` durante drenado y `act_drain_advance` lo captura **válido** en EX/MEM. En el siguiente ciclo se obtiene **dmem_store_fire=1** para un store desalineado. El mapping concreto de esos bytes defectuosos no está definido ni hace falta asumirlo: habilitar el commit ya contradice la obligación de inhibir todos sus bytes y metadata. También se conserva indebidamente `(cause=001, pc=8)` frente al fault más antiguo `(cause=110, pc=4)`.

Se evaluaron puntualmente las ecuaciones con esos valores: confirmación IF=1 en ciclo 3; redirect_apply/ex_fault_confirm=0 en ciclo 5; EX/MEM.next.valid=1 y dmem_store_fire=1 para el segundo ejemplo. Es evidencia sobre el contrato escrito, no una ejecución del procesador.

**Cuál parece ser la política vigente:** ARCH-004 exige faults precisos y descarte wrong-path; ARCH-003 conserva expresamente esa obligación, pero sus ecuaciones aprobadas no la satisfacen en esta excepción. Ninguna revisión posterior declara abandonada la prioridad por antigüedad.

**Corrección documental propuesta:** Reabrir **este caso** de ARCH-003 y su matriz 46, documentar cuándo IF puede confirmarse frente a un consumidor anterior aún no resuelto, y propagar la solución a requisitos y pruebas. La solución debe cubrir consumidor ALU, branch tomado/no tomado, jalr y load/store con fault propio, en RUN/STEP/HOLD. No se selecciona aquí si diferir confirmación, restringir elegibilidad o revisar el tratamiento terminal: cualquiera exige revisar el contrato aprobado y sus consecuencias. No alcanza con añadir un veto aislado en MEM, porque seguirían incorrectos control y metadatos.

**¿Requiere una decisión humana nueva?:** **Sí**, revisión explícita de una decisión aprobada; no se crea un ID nuevo ni se aplica una solución.

### AUD-002 — El contrato de sesión y sus pruebas no propagan íntegramente la FSM vigente

**Severidad:** HIGH  
**Tipo:** STALE_STATE  
**Archivos afectados:** `docs/decisions.md` — ARCH-008; `docs/plan.md` — contratos y regresión.

**Evidencia exacta:**

- `decisions.md:2820`: LOAD «es elegible desde `NO_IMAGE`, `READY`, `STEPPING`, ambos drenados STEP, `FINISHED` y `FAULT`».
- `decisions.md:2847`: FINISHED/FAULT con STEP/RUN → PREPARING_STEP/PREPARING_RUN.
- `decisions.md:2822`: con `PREPARING_RUN/STEP && prepare_done`, el flanco «es un flanco de **ciclo CPU**».
- `decisions.md:4185`: después de citar PREPARING_READY, «READY y HOLD serán descripciones semánticas, no estados RTL obligatorios».
- `decisions.md:4302`: «permanecerán pendientes el arbitraje entre solicitudes nuevas RUN y LOAD» y «la elegibilidad exacta de LOAD».
- `plan.md:1237`: «La elegibilidad de LOAD directo desde `FAULT` y otras vías adicionales permanecen para protocolo/control».
- `plan.md:1856`: «intentar RUN y STEP sin imagen, en FINISHED y en fault, y comprobar ausencia de autorización».
- `plan.md:1227`: «Reset y LOAD aceptado o preparación activa tampoco generan ciclos CPU».

**Por qué es inconsistente:** Es **B**: los contratos/pruebas actuales repiten restricciones históricas sin remitir a sus excepciones aprobadas. El acuerdo 44 distingue recuperación de una sesión nueva de reanudación de la fallada, acepta LOAD desde FAULT y fija RESET>LOAD>STEP>RUN. Un lector del plan puede rechazar órdenes que otro lector implementará mediante preparación. Además, `prepare_active` es un modo Moore, no un veto incondicional al ciclo de `prepare_done`.

«FINISHED/FAULT no ejecuta directamente un ciclo» **sí es correcto**. El error consiste en convertirlo en prohibición de aceptar RUN/STEP y preparar una sesión nueva, o en mantener abierta la elegibilidad. Del mismo modo, la codificación binaria de la FSM sigue libre, pero la existencia de sus 14 estados ya no lo está.

**Cuál parece ser la política vigente:** Acuerdo 44 y auditoría 45: estados y aceptación cerrados; wire format, respuestas UART y codificación binaria aún pendientes. LOAD terminal reemplaza imagen; RUN/STEP terminal reutiliza la imagen confirmada y limpia la sesión. Reset sigue siendo recuperación mínima y anula la imagen. RUN aceptado durante drenado STEP convierte el avance restante a AUTO.

**Corrección documental propuesta:** Actualizar ARCH-008 y las pruebas del plan con esas distinciones. Separar preparación **efectiva con escrituras** de `prepare_active && prepare_done`. Conservar como historia las elecciones originales. Revisar especialmente plan:872, 1237, 1241, 1265, 1310, 1800–1915 y ARCH-008:4185, 4302–4331. No modificar consigna ni inventar comandos externos.

**¿Requiere una decisión humana nueva?:** **No**.

### AUD-003 — El datapath Rev. 02 no es una representación suficiente de la arquitectura aprobada

**Severidad:** HIGH  
**Tipo:** STALE_STATE  
**Archivos afectados:** `docs/figures/pipeline_datapath.tex`, `docs/figures/pipeline_datapath.svg`; biblioteca `pipeline_components.tex` como soporte gráfico.

**Evidencia exacta:**

- TeX:32–34: «DATAPATH DE CINCO ETAPAS», «Esquema funcional», «Rev. 02».
- TeX:43–46: «sólo campos representativos»; IF/ID muestra `valid`, `pc [31:0]`, `instr [31:0]`.
- TeX:100–105: bloques `Branch cmp` y `Target` separados; PC+4 de enlace aparece como rótulo.
- TeX:115–131: operandos reenviados alimentan ALU y comparador; `(CMP.east) -- (TARGET.west)` y `(ALU-result)` hacia EX/MEM.
- `decisions.md:2058–2069`: jal/lui requieren result_sel LINK/IMMEDIATE y alu_src=1; branches usan resta y ALU.zero.
- `plan.md:532–536,785`: Result MUX, Link Adder, Target Adder, JALR Adder y Target MUX aprobados.

**Por qué es inconsistente:** Es **B**, con rutas que resultarían incompatibles si se toman como implementación. La leyenda de campos representativos evita exigir cada bit en un dibujo de alto nivel, pero no explica las rutas ausentes o sustituidas:

- PC+4 de IF no tiene retorno al PC mediante Next-PC MUX; el dibujo muestra solo redirect entrando en PC.
- Immediate Generator no entrega su salida a ID/EX; en EX falta la selección RS2/immediate antes de ALU.
- Falta Result MUX para ALU/immediate/link; la ALU va directamente a EX/MEM. El rótulo de link no constituye una ruta.
- Branch cmp separado no representa la comparación aprobada por SUB y ALU.zero; Target no tiene entradas PC/immediate/rs1 que expliquen branch/jal/jalr.
- La entrada DMEM rotulada «addr / store_data» recibe una línea proveniente de ex_result; no representa inequívocamente el dato registrado independiente.
- No se advierte visiblemente que se omiten validación/faults, enables, Hazard Control y autorización global, todos necesarios para interpretar las flechas.

Además, el **SVG renderizado no muestra el bloque Control ni las rutas WB/M/EX que sí existen en el TeX:79–93**, aunque ambos usan Rev. 02. Fuente y exportación no representan la misma revisión.

**Cuál parece ser la política vigente:** Los ADR y el plan actualizado fijan las rutas funcionales; ARCH-009 decide exposición externa, no pospone esos componentes internos ni autoriza otro comparador.

**Corrección documental propuesta:** Rotular el dibujo como ilustración parcial desactualizada hasta actualizarlo; después representar las rutas aprobadas y regenerar SVG desde la misma fuente, con revisión distinguible. Especificar las omisiones intencionales. No añadir un diseño alternativo de control ni cerrar Debug al hacer el diagrama.

**¿Requiere una decisión humana nueva?:** **No**; es propagación gráfica de decisiones existentes. AUD-001 debe resolverse antes de congelar su diagrama de faults.

### AUD-004 — La prohibición de overflow no delimita suma de dirección y suma de extensión

**Severidad:** MEDIUM  
**Tipo:** FORMULA_OR_WIDTH  
**Archivos afectados:** `docs/requirements.md`, `docs/decisions.md`, `docs/plan.md`.

**Evidencia exacta:**

- `requirements.md:128`: «las sumas que desbordan el ancho arquitectónico nunca acceden a la posición truncada».
- `requirements.md:127`: `effective_address=rs1_effective+ID/EX.immediate` y `dmem_range_valid=({1'b0,effective_address}+mem_nbytes)<=DMEM_CAPACITY_BYTES`.
- `decisions.md:1893`: ALU «a datos de **32 bits**»; `plan.md:536` transporta dirección efectiva en `EX/MEM.ex_result[31:0]`.
- `plan.md:1599–1606`: pruebas de límite, bits bajos y «suma de dirección y ancho con overflow».

**Por qué es inconsistente:** Es una **ambigüedad de alcance**, no una afirmación de que la suma ensanchada de región esté mal. Esa suma sí evita aliasing. La redacción general puede interpretarse como veto adicional al carry de **rs1+inmediato**, mientras el camino aprobado obtiene primero una dirección efectiva de 32 bits y recién luego la extiende para comprobar sus N bytes. Son operaciones distintas.

Ejemplo discriminante: `rs1=0xFFFFFFFF`, inmediato `+1`, acceso BYTE. El resultado de 32 bits es dirección 0 y su región `[0,1)` cabe en DMEM. Si se exige detectar el carry de la suma original para rechazarlo, las ecuaciones de rango actuales no lo hacen. Diferente es dirección efectiva `0xFFFFFFFF`, N=2: la comprobación ensanchada debe rechazar la región, incluso con capacidad conceptual `2^32`.

La referencia normativa calcula dirección a partir de rs1 y offset con signo y describe aritmética XLEN; esto refuerza la necesidad de separar ambas operaciones. La interpretación del alcance del requisito del proyecto sigue necesitando aclaración, no una sustitución silenciosa por una regla «típica». Véase [fuente oficial de RV32I de la versión adoptada, secciones de aritmética y loads/stores](https://raw.githubusercontent.com/riscv/riscv-isa-manual/riscv-user-2.2/src/rv32.tex).

**Cuál parece ser la política vigente:** El conjunto de ecuaciones apunta a dirección arquitectónica de 32 bits y validación ensanchada del **extremo de la región**, antes del índice físico. El requisito no acota textualmente su prohibición a esa segunda suma.

**Corrección documental propuesta:** Confirmar el alcance, escribir explícitamente el ancho/significado de ambas sumas e incorporar los dos vectores anteriores a aceptación. Si se pretendía rechazar carry de base+offset, revisar el datapath y su relación con SYS-010; si solo se protege dirección+N, acotar REQ-MEM-018. No se escoge entre estas interpretaciones.

**¿Requiere una decisión humana nueva?:** **Sí**, aclaración de política vigente conforme a la regla de dudas solicitada.

### AUD-005 — El contador tiene una política observable pendiente sin responsable abierto

**Severidad:** MEDIUM  
**Tipo:** MISSING_DECISION  
**Archivos afectados:** `docs/decisions.md`, `docs/pending_decisions.md`, `docs/plan.md`; afecta REQ-DBG-013/016.

**Evidencia exacta:**

- `decisions.md:450`: «Su ancho y comportamiento ante overflow se definirán posteriormente».
- `decisions.md:481`: SYS-006 no determina «el ancho ni la política de overflow del contador de ciclos».
- `decisions.md:2918`: «Su ancho y política de overflow siguen pendientes de `DEC-SYS-006`».
- `decisions.md:371`: SYS-006 tiene `Estado: Aprobada`.
- `plan.md:839,1249`: reiteran el pendiente; ninguna de las ocho entradas de `pending_decisions.md` lo asigna explícitamente.

**Por qué es inconsistente:** La aprobación de SYS-006 es legítima porque define **qué** observar. El problema es devolver un aspecto expresamente excluido a esa misma decisión aprobada, sin responsable ni momento de cierre. Overflow no es solo elección privada de implementación: altera el contador transmitido y puede afectar la identificación de snapshots en programas sin halt. No debe confundirse con el CSR cycle de un RISC-V completo, fuera del subconjunto.

**Cuál parece ser la política vigente:** Incremento por cpu_cycle_fire y cero inicial cerrados; ancho y overflow realmente abiertos. No hay evidencia para asumir 32/64 bits, saturación ni wrap.

**Corrección documental propuesta:** Asignar humanamente el asunto a un pendiente existente pertinente o a una revisión explícita de SYS-006, con dependencia de la representación Debug/protocolo y criterio verificable. Mantener aprobado lo ya cerrado. No crear automáticamente un ADR nuevo ni elegir el valor.

**¿Requiere una decisión humana nueva?:** **Sí**.

### AUD-006 — Resúmenes y gates conservan pendientes ya cerrados

**Severidad:** MEDIUM  
**Tipo:** STALE_STATE  
**Archivos afectados:** `docs/decisions.md`, `docs/requirements.md`, `docs/plan.md`.

**Evidencia exacta:**

- `decisions.md:963`: «la matriz final del cuadragésimo sexto queda pendiente».
- `decisions.md:969–977,2963–2995`: aprobación, interpretación histórica de acuerdos 1–45 y matriz final de cierre.
- `plan.md:771`: «solo resta la matriz final de cierre».
- `plan.md:829`: «continúa abierta la generación del ciclo global».
- `plan.md:1221`: «la generación global de la autorización permanece abierta».
- `requirements.md:165`: «El acuerdo 44 fija la generación del ciclo global; otras coincidencias siguen pendientes».
- `plan.md:937`: «La matriz final del cuadragésimo sexto acuerdo cierra formalmente `DEC-ARCH-003`».

**Por qué es inconsistente:** Es **B**. El descargo histórico de los acuerdos 1–45 no vuelve histórica toda frase del contexto introductorio, del requisito actual o de un gate del plan. Estos textos describen falsamente tareas documentales pendientes. El acuerdo 46 es una matriz de verificación aprobada; no es evidencia de tests ya ejecutados y tampoco neutraliza el contraejemplo AUD-001.

**Cuál parece ser la política vigente:** Ecuaciones locales, autorización y matriz documentadas; ARCH-003 aprobado. Quedan implementación, verificación y la revisión concreta detectada por la auditoría. Las referencias a otros temas externos realmente pendientes deben conservarse.

**Corrección documental propuesta:** Actualizar contexto y gates; sustituir pendientes genéricos por referencias a acuerdos 40–46. En textos históricos conservar «quedaba pendiente en ese momento». No borrar los acuerdos ni reabrir toda la arquitectura. Incluir en la revisión las repeticiones del plan:785,789,829,880–890,1221,1819,1965–1967,1982–1990 y los resúmenes de SYS-001/ARCH-001/002/004 cuando remiten genéricamente a control todavía por decidir.

**¿Requiere una decisión humana nueva?:** **No** para corregir estado documental; AUD-001 se resuelve por separado.

### AUD-007 — Una prueba del decoder exige el alu_src incorrecto para jal y lui

**Severidad:** MEDIUM  
**Tipo:** CONTRADICTION  
**Archivos afectados:** `docs/plan.md`; contraste con `docs/decisions.md`.

**Evidencia exacta:**

- `plan.md:723`: «incluidos ADD/RS2 deterministas pero no consumidos en `jal`, `lui` o `halt`».
- `decisions.md:2064–2067`: `jal` y `lui` tienen `alu_src=1`; `halt` tiene `alu_src=0`.
- `decisions.md:1907`: `0 = RS2`, `1 = IMMEDIATE`.

**Por qué es inconsistente:** Es **C** entre tabla y expectativa de prueba. Aunque ALU no aporte el resultado arquitectónico de jal/lui, la tabla eligió valores deterministas, no don't-care. Un test que siga literalmente el plan rechazaría el decoder aprobado.

**Cuál parece ser la política vigente:** ADD con IMMEDIATE para jal/lui; ADD con RS2 para halt; todos sin consumo funcional de ALU en esas tres clases.

**Corrección documental propuesta:** Cambiar exclusivamente esa expectativa y conservar los demás campos/códigos.

**¿Requiere una decisión humana nueva?:** **No**.

### AUD-008 — Dos referencias buscan acuerdos aprobados en el archivo de pendientes

**Severidad:** MEDIUM  
**Tipo:** BROKEN_REFERENCE  
**Archivos afectados:** `docs/plan.md`.

**Evidencia exacta:**

- `plan.md:599`: «El acuerdo parcial 3A […] en `pending_decisions.md`».
- `plan.md:619`: «la tabla exhaustiva de este trigésimo séptimo acuerdo en `pending_decisions.md`».
- `pending_decisions.md:9–11`: al aprobar una decisión, «se elimina de este archivo» y «se incorpora en `decisions.md`».

**Por qué es inconsistente:** El archivo existe, pero el contenido referido ya no está allí. ARCH-003 fue trasladada correctamente; falló la propagación de sus referencias.

**Cuál parece ser la política vigente:** Acuerdos 3A/3B y 37 dentro de ARCH-003 en decisions.

**Corrección documental propuesta:** Reemplazar ambos destinos por `decisions.md`, manteniendo el número y el identificador del ADR para localización inequívoca.

**¿Requiere una decisión humana nueva?:** **No**.

### AUD-009 — La trazabilidad omite la documentación de hazards y el halt del assembler

**Severidad:** MEDIUM  
**Tipo:** TRACEABILITY  
**Archivos afectados:** `docs/decisions.md`, `docs/pending_decisions.md`.

**Evidencia exacta:**

- `requirements.md:242`: REQ-DOC-008 exige «documentarse los mecanismos elegidos para resolver dependencias y cambios de flujo».
- Las listas `Requisitos afectados` de ARCH-002 (`decisions.md:947`) y ARCH-003 (`:2997`) no incluyen REQ-DOC-008; tampoco lo incluye ningún otro ADR.
- `requirements.md:213`: REQ-SW-012 exige que el assembler genere `0x0000000B` para `halt`.
- `pending_decisions.md:175,181`: SYS-009 depende de SYS-004/SYS-010/ARCH-001 y enumera SW-002 a SW-004 y SW-010, sin SW-012 ni SYS-001.

**Por qué es inconsistente:** No falta la política de hazards ni la codificación de halt. Falta su trazabilidad en las listas que se usan para seleccionar cobertura. Una herramienta externa puede soportar RV32I y no aceptar el mnemónico custom: SYS-009 debe considerar ese contrato existente al escoger estrategia. No se encontró un ADR sin ningún requisito asociado.

**Cuál parece ser la política vigente:** ARCH-002/003 satisfacen documentalmente DOC-008; SYS-001 ya impone el contrato del assembler para SW-012. SYS-009 sigue abierta solo para decidir cómo realizarlo.

**Corrección documental propuesta:** Añadir DOC-008 a las decisiones de flujo/hazards; agregar SYS-001 como dependencia aprobada y SW-012 como requisito afectado de SYS-009, explicitando que la integración elegida debe preservar halt. DOC-001, el otro requisito sin backlink a un ADR específico, es una obligación transversal de mantener el registro: no necesita una nueva decisión arquitectónica.

**¿Requiere una decisión humana nueva?:** **No**.

### AUD-010 — El contrato del modelo funcional enumera solo una parte de los faults

**Severidad:** MEDIUM  
**Tipo:** DOCUMENTATION  
**Archivos afectados:** `docs/plan.md`, fase 15.

**Evidencia exacta:**

- `plan.md:2034–2039` enumera únicamente «finalización normal por `halt`», «fault de fetch», «fault de load», «fault de store».
- `plan.md:2041`: «No será necesario modelar todavía códigos de reporte».
- `decisions.md:3039–3045,3120–3128` define instrucción ilegal y faults de control, distintos del fetch posterior.
- `requirements.md:165` fija siete causas internas y `fault_pc` de la operación causante.

**Por qué es inconsistente:** Es **B**, una especificación de verificación que quedó corta. No debe interpretarse «fault de fetch» como destino desalineado de jal/jalr: el último pertenece al salto, inhibe su enlace y usa su PC. Una instrucción ilegal tampoco es fault de lectura. El plan no dice que esa lista sea solo un subconjunto inicial y presenta al modelo como oráculo del comportamiento arquitectónico.

**Cuál parece ser la política vigente:** Deben distinguirse las siete clases, su PC causante, prioridad de alineación sobre acceso y ausencia de efectos. No hacen falta formato UART ni drenado de pipeline para un modelo secuencial.

**Corrección documental propuesta:** Completar los resultados del modelo y comparar causa/PC y efectos junto con registros/memoria. Aclarar que puede usar categorías simbólicas equivalentes a los códigos internos, sin diseñar el transporte externo.

**¿Requiere una decisión humana nueva?:** **No**.

### AUD-011 — La adaptación de la ALU heredada deja implícita la selección de shamt

**Severidad:** MEDIUM  
**Tipo:** AMBIGUITY  
**Archivos afectados:** `docs/decisions.md`, `docs/plan.md`; referencia externa local a `../tp1/alu.sv` y `../tp2/rtl/alu.sv`.

**Evidencia exacta:**

- `decisions.md:1893–1903`: conservar códigos de operaciones existentes e incorporar «SLL, SLT y SLTU».
- `plan.md:613`: «SLL, SLT y SLTU requieren implementación para el CPU, sin alterar códigos existentes».
- `../tp2/rtl/alu.sv` (casos OP_SRA/OP_SRL): `$signed(i_data_a) >>> i_data_b` e `i_data_a >> i_data_b`.
- `requirements.md:85`: semántica RV32I V2.2; `decisions.md:2041`: el shift inmediato contiene `shamt` de cinco bits.

**Por qué es inconsistente:** No se demuestra un RTL TP3 incorrecto, porque todavía no existe. El riesgo documental concreto es presentar la adaptación como cambio de ancho y agregado de tres operaciones, dejando sin advertir que la ALU referenciada desplaza por **todo** i_data_b. El contrato de forwarding y alu_src transporta datos de 32 bits. Reutilizarlo literalmente falla, por ejemplo, en `srl` con rs1=0x80000000 y rs2=32: en RV32 el desplazamiento es cero y conserva el dato; el núcleo heredado desplazará 32 posiciones.

RV32 emplea cinco bits de cantidad tanto para shifts por registro como inmediatos. La regla está en la [fuente oficial RV32I, apartados de shifts inmediatos y Register-Register Operations](https://raw.githubusercontent.com/riscv/riscv-isa-manual/riscv-user-2.2/src/rv32.tex). La ubicación física de la adaptación puede seguir siendo detalle de implementación.

**Cuál parece ser la política vigente:** SYS-010 obliga a la semántica RV32; preservar **opcodes** no exige conservar el comportamiento no RV32 de un núcleo genérico anterior.

**Corrección documental propuesta:** Explicitar que SLL/SRL/SRA consumen solo los cinco bits bajos del operando de cantidad seleccionado y añadir casos 0,31,32,33 y bits altos activos. Para SRAI comprobar que los bits fijos del encoding no integren la cantidad. No elegir entre adaptación interna o wrapper ni escribir RTL.

**¿Requiere una decisión humana nueva?:** **No**; la semántica ya está fijada normativamente.

### AUD-012 — Los ejemplos de requisitos usan identificadores incorrectos

**Severidad:** LOW  
**Tipo:** TRACEABILITY  
**Archivos afectados:** `docs/plan.md`.

**Evidencia exacta:**

- `plan.md:180–187`: CPU-001 se usa para cinco etapas, EXEC-002 para un ciclo por NEXT y DBG-003 para lectura de registros.
- `requirements.md:26–27,149,156,180,182`: los correspondientes IDs reales son CPU-002, EXEC-009 y DBG-005.
- `plan.md:1451–1454`: `REQ-ISA-ADD`, `REQ-ISA-LB`, `REQ-HAZ-LOAD`, `REQ-EXEC-STEP` no existen en requirements.

**Por qué es inconsistente:** Son ejemplos, por lo que no crean obligaciones nuevas; sí pueden copiarse como matrices válidas. NEXT añade otro nombre innecesario al comando conceptual STEP, cuyo opcode externo sigue abierto.

**Cuál parece ser la política vigente:** El catálogo estable de 160 REQ numéricos de requirements.

**Corrección documental propuesta:** Usar los IDs reales y el nombre conceptual STEP, manteniendo los nombres de tests como ejemplos futuros.

**¿Requiere una decisión humana nueva?:** **No**.

### AUD-013 — M1 tiene dos nombres

**Severidad:** LOW  
**Tipo:** TERMINOLOGY  
**Archivos afectados:** `docs/pending_decisions.md`, `docs/plan.md`.

**Evidencia exacta:** `pending_decisions.md:33`: «M1 — System Freeze»; `plan.md:2538`: «M1 — Decision Freeze».

**Por qué es inconsistente:** No se declaran hitos distintos ni equivalencia; los dos nombres se usan para M1. Es una diferencia editorial, no un bloqueo técnico adicional.

**Cuál parece ser la política vigente:** M1 es el cierre de decisiones globales críticas, según la tabla formal del plan.

**Corrección documental propuesta:** Usar «M1 — Decision Freeze» en el mapa de pendientes.

**¿Requiere una decisión humana nueva?:** **No**.

## 3. Requisitos sin cobertura o trazabilidad dudosa

**No se encontraron identificadores duplicados ni decisiones de origen inexistentes.** Todos los orígenes explícitos apuntan a decisiones aprobadas y tienen backlink desde su ADR. El símbolo `—` significa que el requisito no fue generado por una elección interna; no significa automáticamente que sea huérfano.

Los únicos requisitos ausentes de todas las listas `Requisitos afectados` son **REQ-DOC-001** y **REQ-DOC-008**. DOC-001 está cubierto por el proceso transversal de registrar y justificar decisiones; DOC-008 tiene contenido suficiente en ARCH-002/003 pero carece del vínculo explícito, AUD-009.

Requisitos afectados directamente por hallazgos, además de las obligaciones generales de documentación:

| Hallazgo | REQ afectados o cuya evidencia resulta comprometida |
|---|---|
| AUD-001 | CPU-011/017; ISA-002/003/004/005/006/018–022/032; HAZ-002/004/005/006/007/009/010; MEM-016/017/018/029; EXEC-018; DBG-015/017 |
| AUD-002 | CPU-016/018; MEM-008/024/030; EXEC-008/009/015/016/017; DBG-012/016/017 |
| AUD-003 | CPU-004/005/006/007/009/010/011/014/015/017; ISA-001/007/023–032; HAZ-003/006/007/009; DOC-008/009 |
| AUD-004 | MEM-017/018; ISA-033 |
| AUD-005 | DBG-013/016; SW-010; DOC-006 |
| AUD-006 | CPU-015; EXEC-018; DOC-001/008/009 |
| AUD-007 | CPU-015; ISA-001/007/034 |
| AUD-008 | HAZ-002/003/004/005/006; CPU-015; DOC-008 |
| AUD-009 | DOC-008; SW-003/012 |
| AUD-010 | CPU-015/017; ISA-001/005/006/032/033/034; EXEC-018; DBG-017 |
| AUD-011 | CPU-006; ISA-010/011/012/029/030/031/033 |
| AUD-012 | CPU-001/002; EXEC-002/009; DBG-003/005; ISA-008/018; HAZ-004 |
| AUD-013 | Ningún requisito funcional cambia; afecta identificación de gate |

Los prefijos de esa tabla abrevian `REQ-`; los intervalos incluyen cada identificador intermedio. Los requisitos de UART/Debug/software con decisiones todavía abiertas tienen cobertura **parcial legítima**, no un diseño terminado. Particularmente: UART-001–005; DBG-001–003/006–011/013–017 según formato, captura y memoria utilizada; SW-001–012 según aplicación, assembler y transporte; DOC-005/006. TIM-002–007 y DOC-009 exigen evidencia de implementación futura, que todavía no existe.

La siguiente matriz registra **cada uno de los 160 REQ**. `Snnn`, `Annn` y `Pnnn` abrevian DEC-SYS, DEC-ARCH y DEC-PROTO respectivamente. La columna de decisiones enumera backlinks documentales existentes, **no certificados de cumplimiento completo**. `?` identifica un ADR pendiente. Los hallazgos anteriores limitan las filas afectadas aun cuando tengan muchas referencias. Fuente y criterio detallados permanecen en la línea indicada de requirements; se contrastaron con consigna y los acuerdos aplicables.

| Requisito | Línea | Origen interno | Decisiones que lo referencian | Evaluación |
|---|---:|---|---|---|
| REQ-CPU-001 | 26 | — | S010 | Cobertura documental disponible |
| REQ-CPU-002 | 27 | — | A006 | Cobertura documental disponible |
| REQ-CPU-003 | 28 | — | A001, A006 | Cobertura documental disponible |
| REQ-CPU-004 | 29 | — | A001, A003, A006 | Cobertura documental disponible |
| REQ-CPU-005 | 30 | — | A003, A007 | Cobertura documental disponible |
| REQ-CPU-006 | 31 | — | A001, A003 | Cobertura documental disponible |
| REQ-CPU-007 | 32 | — | A001, A003, A006 | Cobertura documental disponible |
| REQ-CPU-008 | 33 | — | A002, A003, A007 | Cobertura documental disponible |
| REQ-CPU-009 | 34 | — | S003, S006, A002, A003, A006, A008 | Cobertura documental disponible |
| REQ-CPU-010 | 35 | — | S003, S006, A002, A003, A006, A008 | Cobertura documental disponible |
| REQ-CPU-011 | 36 | — | S001, S003, S006, A001, A002, A003, A004, A008 | Cobertura documental disponible; AUD-001 |
| REQ-CPU-012 | 37 | — | S003, S006, A007, A008 | Cobertura documental disponible |
| REQ-CPU-013 | 38 | — | S003, S010, A002, A007, A008 | Cobertura documental disponible |
| REQ-CPU-014 | 39 | — | S010, A001 | Cobertura documental disponible |
| REQ-CPU-015 | 40 | — | S001, S010, A003, A004 | Cobertura documental disponible; AUD-006/007 |
| REQ-CPU-016 | 41 | S003 | S003, S006, A001, A007, A008 | Cobertura documental disponible; AUD-002 |
| REQ-CPU-017 | 42 | A001 | A001, A002, A003, A004 | Cobertura documental disponible; AUD-001 |
| REQ-CPU-018 | 43 | A001 | A001, A008 | Cobertura documental disponible; AUD-002 |
| REQ-ISA-001 | 53 | — | S010, A001, A002, A004 | Cobertura documental disponible; AUD-007 |
| REQ-ISA-002 | 54 | — | S010, A001, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-003 | 55 | — | S010, A001, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-004 | 56 | — | S010, A001, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-005 | 57 | — | S010, A001, A002, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-006 | 58 | — | S010, A001, A002, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-007 | 59 | — | S010, A004 | Cobertura documental disponible; AUD-007 |
| REQ-ISA-008 | 60 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-009 | 61 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-010 | 62 | — | S010, A004 | Cobertura documental disponible; AUD-011 |
| REQ-ISA-011 | 63 | — | S010, A004 | Cobertura documental disponible; AUD-011 |
| REQ-ISA-012 | 64 | — | S010, A004 | Cobertura documental disponible; AUD-011 |
| REQ-ISA-013 | 65 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-014 | 66 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-015 | 67 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-016 | 68 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-017 | 69 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-018 | 70 | — | S010, A001, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-019 | 71 | — | S010, A001, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-020 | 72 | — | S010, A001, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-021 | 73 | — | S010, A001, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-022 | 74 | — | S010, A001, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-023 | 75 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-024 | 76 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-025 | 77 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-026 | 78 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-027 | 79 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-028 | 80 | — | S010, A004 | Cobertura documental disponible |
| REQ-ISA-029 | 81 | — | S010, A004 | Cobertura documental disponible; AUD-011 |
| REQ-ISA-030 | 82 | — | S010, A004 | Cobertura documental disponible; AUD-011 |
| REQ-ISA-031 | 83 | — | S010, A004 | Cobertura documental disponible; AUD-011 |
| REQ-ISA-032 | 84 | — | S010, A001, A002, A004 | Cobertura documental disponible; AUD-001 |
| REQ-ISA-033 | 85 | S010 | S010, A001, A004 | Cobertura documental disponible; AUD-004/011 |
| REQ-ISA-034 | 86 | S001 | S001, A004 | Cobertura documental disponible; AUD-007 |
| REQ-HAZ-001 | 94 | — | A001, A003 | Cobertura documental disponible |
| REQ-HAZ-002 | 95 | — | A003, A007 | Cobertura documental disponible; AUD-001 |
| REQ-HAZ-003 | 96 | — | A003, A007 | Cobertura documental disponible |
| REQ-HAZ-004 | 97 | — | A003, A004, A007, A008 | Cobertura documental disponible; AUD-001 |
| REQ-HAZ-005 | 98 | — | A003, A007 | Cobertura documental disponible; AUD-001 |
| REQ-HAZ-006 | 99 | — | A002, A003, A007 | Cobertura documental disponible; AUD-001 |
| REQ-HAZ-007 | 100 | — | A002, A003 | Cobertura documental disponible; AUD-001 |
| REQ-HAZ-008 | 101 | — | A002, A003 | Cobertura documental disponible |
| REQ-HAZ-009 | 102 | — | S010, A002, A003 | Cobertura documental disponible; AUD-001 |
| REQ-HAZ-010 | 103 | — | S001, A002, A003, A004, A008 | Cobertura documental disponible; AUD-001 |
| REQ-MEM-001 | 111 | — | S004, A001, A006 | Cobertura documental disponible |
| REQ-MEM-002 | 112 | — | S004, A001, A006 | Cobertura documental disponible |
| REQ-MEM-003 | 113 | — | S003, S004, A001, A006, P001? | Cobertura documental disponible |
| REQ-MEM-004 | 114 | — | S003, S004, A001, A006 | Cobertura documental disponible |
| REQ-MEM-005 | 115 | — | S003, S004, A001, A003, A006 | Cobertura documental disponible |
| REQ-MEM-006 | 116 | — | S010, A001, A003, A004, A006 | Cobertura documental disponible |
| REQ-MEM-007 | 117 | — | S003, A001, A006, A008 | Cobertura documental disponible |
| REQ-MEM-008 | 118 | S003 | S003, A001, A006, A008, A005, S005?, P001? | Cobertura documental disponible; AUD-002 |
| REQ-MEM-009 | 119 | S003 | S003, S004, A001, A004, A006 | Cobertura documental disponible |
| REQ-MEM-010 | 120 | S004 | S004, A001, A006, A005, P001?, S009? | Cobertura documental disponible |
| REQ-MEM-011 | 121 | S004 | S004, A001, A006, P001?, S009? | Cobertura documental disponible |
| REQ-MEM-012 | 122 | S004 | S004, A001, A006, P001?, S009? | Cobertura documental disponible |
| REQ-MEM-013 | 123 | A001 | A001, A006 | Cobertura documental disponible |
| REQ-MEM-014 | 124 | A001 | A001, A006 | Cobertura documental disponible |
| REQ-MEM-015 | 125 | A001 | A001, A006, P001?, S009? | Cobertura documental disponible |
| REQ-MEM-016 | 126 | A001 | A001, A002, A003, A004, A006, A005, P001? | Cobertura documental disponible; AUD-001 |
| REQ-MEM-017 | 127 | A001 | A001, A003, A004, A006, A005, P001? | Cobertura documental disponible; AUD-001, AUD-004 |
| REQ-MEM-018 | 128 | A001 | A001, A004, A006, A005, P001? | Cobertura documental disponible; AUD-001, AUD-004 |
| REQ-MEM-019 | 129 | A001 | A001, A006, A008, A005, S005?, P001?, P002? | Cobertura documental disponible |
| REQ-MEM-020 | 130 | A001 | A001, A003, A004, A006, A005 | Cobertura documental disponible |
| REQ-MEM-021 | 131 | A001 | A001, A006, A005, P001?, S009? | Cobertura documental disponible |
| REQ-MEM-022 | 132 | A001 | A001, A006, A005, P001?, S009? | Cobertura documental disponible |
| REQ-MEM-023 | 133 | A001 | A001, A006, A005, P001?, S009? | Cobertura documental disponible |
| REQ-MEM-024 | 134 | A001 | A001, A006, A008, A005, P001?, S009? | Cobertura documental disponible; AUD-002 |
| REQ-MEM-025 | 135 | A006 | A003, A006, A008, A005 | Cobertura documental disponible |
| REQ-MEM-026 | 136 | A006 | A006, A005 | Cobertura documental disponible |
| REQ-MEM-027 | 137 | A006 | A004, A006, A005, P001? | Cobertura documental disponible |
| REQ-MEM-028 | 138 | A006 | A004, A006, A008, A005, S005?, P002? | Cobertura documental disponible |
| REQ-MEM-029 | 139 | A006 | A003, A004, A006, A008, A005, S005?, P001? | Cobertura documental disponible; AUD-001 |
| REQ-MEM-030 | 140 | A006 | A003, A006, A008, A005, P001? | Cobertura documental disponible; AUD-002 |
| REQ-EXEC-001 | 148 | — | S001, A003, A008 | Cobertura documental disponible |
| REQ-EXEC-002 | 149 | — | S001, A003, A008 | Cobertura documental disponible |
| REQ-EXEC-003 | 150 | — | S001, A003, A008 | Cobertura documental disponible |
| REQ-EXEC-004 | 151 | — | S001, A003, A008 | Cobertura documental disponible |
| REQ-EXEC-005 | 152 | — | S001, S002, A003, A008 | Cobertura documental disponible |
| REQ-EXEC-006 | 153 | — | S001, S002, A008 | Cobertura documental disponible |
| REQ-EXEC-007 | 154 | — | S001, S006, A008 | Cobertura documental disponible |
| REQ-EXEC-008 | 155 | — | S001, S002, A008 | Cobertura documental disponible; AUD-002 |
| REQ-EXEC-009 | 156 | — | S001, S002, A003, A006, A008 | Cobertura documental disponible; AUD-002 |
| REQ-EXEC-010 | 157 | — | S001, S006, A008 | Cobertura documental disponible |
| REQ-EXEC-011 | 158 | — | A008, A005 | Cobertura documental disponible |
| REQ-EXEC-012 | 159 | — | S002, A008, P002? | Cobertura documental disponible |
| REQ-EXEC-013 | 160 | S001 | S001, A002, A003, A004, A008 | Cobertura documental disponible |
| REQ-EXEC-014 | 161 | S002 | S002, A001, A004, A008 | Cobertura documental disponible |
| REQ-EXEC-015 | 162 | S002 | S002, A003, A004, A008, P002? | Cobertura documental disponible; AUD-002 |
| REQ-EXEC-016 | 163 | S003 | S003, A003, A008, S007?, P001? | Cobertura documental disponible; AUD-002 |
| REQ-EXEC-017 | 164 | S003 | S003, S004, A001, A003, A006, A008, S007?, P001? | Cobertura documental disponible; AUD-002 |
| REQ-EXEC-018 | 165 | A001 | A001, A002, A003, A004, A006, A008, P001?, P002?, S008? | Cobertura documental disponible; AUD-001 |
| REQ-UART-001 | 173 | — | A005, S007? | Obligación coherente; realización pendiente |
| REQ-UART-002 | 174 | — | S003, S004, A008, A005, S007?, P001? | Obligación coherente; realización pendiente |
| REQ-UART-003 | 175 | — | A008, A005, S007?, P001?, P002? | Obligación coherente; realización pendiente |
| REQ-UART-004 | 176 | — | A008, A005, S007?, P001?, P002? | Obligación coherente; realización pendiente |
| REQ-UART-005 | 177 | — | S006, A008, A005, S007?, P001?, P002? | Obligación coherente; realización pendiente |
| REQ-DBG-001 | 178 | — | A008, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-002 | 179 | — | S003, S004, A008, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-003 | 180 | — | S003, A008, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-004 | 181 | — | S003, S006, A008, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-005 | 182 | — | S003, S006, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-006 | 183 | — | S003, S006, A003, A009?, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-007 | 184 | — | S003, S006, A003, A009?, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-008 | 185 | — | S003, S006, A003, A009?, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-009 | 186 | — | S003, S006, A003, A009?, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-010 | 187 | — | S003, S006, A001, A006, S005?, P001? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-011 | 188 | — | S003, P001?, P003? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-012 | 189 | S003 | S003, S006, A004, A008, S005?, P001? | Mínimo definido; detalles externos abiertos; AUD-002 |
| REQ-DBG-013 | 190 | S006 | S006, A001, A003, A004, A008, S007?, S005?, P001?, P002?, S008? | Mínimo definido; detalles externos abiertos; AUD-005 |
| REQ-DBG-014 | 191 | S006 | S006, A003, S007?, A009?, P001?, S008? | Mínimo definido; detalles externos abiertos |
| REQ-DBG-015 | 192 | S006 | S006, A001, A004, A006, A008, S007?, S005?, P001?, P002?, S008? | Mínimo definido; detalles externos abiertos; AUD-001 |
| REQ-DBG-016 | 193 | S006 | S006, A003, A008, S007?, P001?, S008? | Mínimo definido; detalles externos abiertos; AUD-005, AUD-002 |
| REQ-DBG-017 | 194 | A001 | A001, A003, A004, A008, A009?, P001?, P002?, S008? | Mínimo definido; detalles externos abiertos; AUD-001, AUD-002 |
| REQ-SW-001 | 202 | — | S008? | Obligación coherente; realización pendiente |
| REQ-SW-002 | 203 | — | S009? | Obligación coherente; realización pendiente |
| REQ-SW-003 | 204 | — | S001, S010, S009? | Obligación coherente; realización pendiente; AUD-009 |
| REQ-SW-004 | 205 | — | S003, S004, P001?, S009? | Obligación coherente; realización pendiente |
| REQ-SW-005 | 206 | — | S008? | Obligación coherente; realización pendiente |
| REQ-SW-006 | 207 | — | S006, S008? | Obligación coherente; realización pendiente |
| REQ-SW-007 | 208 | — | S006, S008? | Obligación coherente; realización pendiente |
| REQ-SW-008 | 209 | — | S006, A009?, S008? | Obligación coherente; realización pendiente |
| REQ-SW-009 | 210 | — | S006, S005?, S008? | Obligación coherente; realización pendiente |
| REQ-SW-010 | 211 | — | S003, S004, S006, P001?, P002?, P003?, S009?, S008? | Obligación coherente; realización pendiente |
| REQ-SW-011 | 212 | — | S003, P001?, P003? | Obligación coherente; realización pendiente |
| REQ-SW-012 | 213 | S001 | S001 | Obligación coherente; realización pendiente; AUD-009 |
| REQ-TIM-001 | 221 | — | A008, A005 | Política disponible; evidencia física futura |
| REQ-TIM-002 | 222 | — | A008, A005 | Política disponible; evidencia física futura |
| REQ-TIM-003 | 223 | — | A006, A005 | Política disponible; evidencia física futura |
| REQ-TIM-004 | 224 | — | A006, A005 | Política disponible; evidencia física futura |
| REQ-TIM-005 | 225 | — | A006, A005 | Política disponible; evidencia física futura |
| REQ-TIM-006 | 226 | — | A006, A005 | Política disponible; evidencia física futura |
| REQ-TIM-007 | 227 | — | A006, A008, A005 | Política disponible; evidencia física futura |
| REQ-DOC-001 | 235 | — | Proceso transversal | Obligación transversal; registro existente |
| REQ-DOC-002 | 236 | — | S003 | Cobertura documental disponible |
| REQ-DOC-003 | 237 | — | S001 | Cobertura documental disponible |
| REQ-DOC-004 | 238 | — | S002, A008 | Cobertura documental disponible |
| REQ-DOC-005 | 239 | — | S005? | Pendiente declarado |
| REQ-DOC-006 | 240 | — | S006, S007?, P001? | Pendiente declarado |
| REQ-DOC-007 | 241 | — | S004, A001, A006 | Cobertura documental disponible |
| REQ-DOC-008 | 242 | — | Falta backlink | Cubierto en contenido; falta vínculo; AUD-009 |
| REQ-DOC-009 | 243 | — | A006, A008, A005 | Entrega final futura |

## 4. Decisiones y dependencias

Los identificadores son únicos: **14 aprobadas exclusivamente en decisions y 8 pendientes exclusivamente en pending_decisions**. No hay una decisión que deba retirarse todavía de la lista de pendientes por estar ya aprobada. Los títulos de las entradas no presentan colisiones. Las discrepancias de «pendiente» detectadas corresponden a contenido/resúmenes, no al estado formal de dos registros duplicados.

En la tabla, «semánticas» indica contratos que se cruzaron durante la auditoría; no inventa un campo `Depende de` ausente ni exige reaprobar dependencias ya satisfechas. Las dependencias formales pendientes se transcriben con sus estados actuales.

| Decisión | Estado que debería tener | Documento actual | Dependencias | Problemas |
|---|---|---|---|---|
| DEC-SYS-001 — Representación y semántica de STOP/HALT | Aprobada | decisions:28 | Semánticas: ISA SYS-010; refinamiento de etapa/control por ARCH-002/003/004 | Halt único coherente; resúmenes de etapa pendiente necesitan remisión vigente (AUD-006) |
| DEC-SYS-002 — Comportamiento ante ausencia de STOP/HALT | Aprobada | decisions:88 | SYS-001; recuperación mínima concretada por ARCH-008 | No exige halt obligatorio ni timeout de programa; contraejemplo de loop AUD-001 |
| DEC-SYS-003 — Política general de reprogramación | Aprobada | decisions:170 | Semánticas: capacidades, imagen ARCH-001/006 y preparación ARCH-008/003 | Política fail-closed coherente; distinguir LOAD de reinicio con imagen retenida, AUD-002 |
| DEC-SYS-004 — Capacidades iniciales de memoria | Aprobada | decisions:261 | Refinada por ARCH-001/006 y compromiso físico ARCH-005 | Sin bloqueo nuevo: REFERENCE y ALT_1000 tienen compromisos diferentes |
| DEC-SYS-006 — Información observable mediante Debug | Aprobada, con exclusiones explícitas | decisions:369 | Expone contratos SYS-003, ARCH-003/004; detalles futuros SYS-005/ARCH-009/protocolo | No está pendiente el snapshot mínimo; contador sin responsable abierto, AUD-005 |
| DEC-SYS-010 — Versión del ISA | Aprobada | decisions:539 | Referencia RV32I de User-Level ISA V2.2 y subconjunto de consigna | No exige implementar todo RV32I; aclaración aritmética AUD-004 y adaptación ALU AUD-011 |
| DEC-ARCH-001 — Organización y comportamiento de las memorias | Aprobada | decisions:576 | Semánticas SYS-003/004/010; realizaciones ARCH-004/006/008 | Capacidad, imagen y espacio independientes coherentes; alcance overflow AUD-004 |
| DEC-ARCH-002 — Etapa de resolución de branches y jumps | Aprobada | decisions:810 | SYS-001/010; PC ARCH-001; refinamientos ARCH-003/004 | EX y política secuencial provisional coherentes; propagación gráfica y backlink AUD-003/009 |
| DEC-ARCH-003 — Política de hazards | Registrada Aprobada; requiere revisión puntual por AUD-001 | decisions:953 | Formales resueltas: ARCH-001/002/004/007; integra memorias y reset ARCH-006/008 | AUD-001 impide usar su cierre como garantía funcional; AUD-006 corrige resúmenes, no este defecto |
| DEC-ARCH-004 — Instrucciones inválidas y accesos desalineados | Aprobada | decisions:3003 | Whitelist SYS-001/010; memoria ARCH-001; flujo ARCH-002; realización ARCH-003 | Contrato preciso incompatible con excepción IF, AUD-001; no cambiarlo silenciosamente |
| DEC-ARCH-005 — Frecuencia objetivo y distribución de clock | Aprobada | decisions:4364 | Explícitas: SYS-004, ARCH-006/008 aprobadas; placa/clock/restricciones disponibles | No depende de haber obtenido timing closure; integración física y reportes siguen futuros |
| DEC-ARCH-006 — Implementación física de las memorias | Aprobada | decisions:3286 | SYS-003/004; ARCH-001; enables/reset ARCH-008 | Inferencia y latencia cerradas; reportes físicos no existen todavía y no se presumen |
| DEC-ARCH-007 — Temporización del banco de registros | Aprobada | decisions:3487 | ISA/registros; validez y WB→ID integrados con ARCH-003/008 | Sin inconsistencia relevante en bypass, x0 o prioridad reset |
| DEC-ARCH-008 — Reset y enables | Aprobada con remisiones actualizadas | decisions:3706 | SYS-003; ownership ARCH-001/006; clock ARCH-005; FSM posterior ARCH-003/44 | AUD-002: comandos y preparación no deben seguir abiertos en su resumen |
| DEC-SYS-007 — Servicios y parámetros generales de UART | Pendiente; siguiente por cronología | pending:57 | SYS-003/004/006 aprobadas y clock/placa disponibles mediante ARCH-005 | Prerrequisitos disponibles; no heredar automáticamente baud/framing del TP2 |
| DEC-SYS-009 — Estrategia del assembler | Pendiente | pending:167 | SYS-004/010 y ARCH-001 aprobadas; falta explicitar SYS-001, también aprobada | AUD-009; la corrección no añade un bloqueo |
| DEC-ARCH-009 — Campos de pipeline expuestos por debug | Pendiente | pending:75 | SYS-006/ARCH-004 aprobadas y especificación definitiva de latches | Campos funcionales ya documentados en ARCH-003; falta representación externa, no volver a diseñar latches. Considerar resultado de AUD-001 antes de congelar |
| DEC-SYS-005 — Criterio de memoria de datos utilizada | Pendiente | pending:93 | SYS-003/004/006, ARCH-001/006 aprobadas | Debe respetar comienzo vacío, cero lógico, ownership; el bitmap no escoge criterio |
| DEC-PROTO-001 — Formato detallado del protocolo | Pendiente, dependencias abiertas | pending:111 | SYS-003/004/006, ARCH-001/006/008 aprobadas; SYS-005/007 y ARCH-009 pendientes | No puede cerrarse ignorando esos tres pendientes. ARCH-003/44 ya fija comportamiento interno; transporte permanece abierto |
| DEC-PROTO-002 — Comandos adicionales | Pendiente, dependencia abierta | pending:129 | SYS-002/003/006, ARCH-006/008 aprobadas; SYS-007 pendiente | No debe redeterminar el arbitraje interno ya aprobado. Pausa, aborto, consulta y captura RUN sí siguen abiertos |
| DEC-PROTO-003 — Timeouts y recuperación | Pendiente, dependencias abiertas | pending:147 | PROTO-001 y PROTO-002 pendientes | No es timeout de ejecución del programa; distinguir mensajes incompletos de terminación CPU |
| DEC-SYS-008 — Formato de la aplicación de PC | Pendiente | pending:185 | SYS-006 aprobada y flujos Debug/protocolo aún por definir | CLI/TUI/GUI abierta; recomendación CLI del plan no es una aprobación |

La referencia mutua entre decisiones que fijan contratos y decisiones que luego los realizan **no demuestra por sí misma un ciclo bloqueante**. Por ejemplo, ARCH-003 usa la temporización del RF aprobada en ARCH-007, y ARCH-007 remite al gating de ARCH-003; ambos están aprobados. Igualmente, ARCH-005 concreta la relación con locked que ARCH-008 deja a integración. No se identificó una dependencia formal pendiente que apunte a un ID inexistente.

Las entradas de protocolo **sí tienen prerrequisitos abiertos**, correctamente visibles; no deben presentarse como listas para aprobar. Para mayor trazabilidad conviene mencionar explícitamente ARCH-003 en ARCH-009/PROTO-001/002 y ARCH-005 en SYS-007, sin convertir esos vínculos aprobados en nuevas decisiones pendientes.

| Hito/gate | Lectura vigente después de las correcciones objetivas |
|---|---|
| M0 — Requirements Freeze | Hay catálogo numerado de 160 REQ; aplicar correcciones y resolver ambigüedades antes de tratarlo como contrato coherente congelado |
| M1 — Decision Freeze | No hay decisiones pendientes en esa fila del mapa; unificar nombre (AUD-013). No significa que todas las decisiones futuras estén cerradas |
| M2 — Architecture Freeze | Próximo pendiente cronológico: SYS-007. ARCH-005 ya aprobada, sin esperar reportes post-implementation para aprobar el ADR |
| M3 — ISA Freeze | Whitelist/decode aprobados; sigue pendiente estrategia SYS-009 y el entregable ISA detallado del plan |
| M4 — Pipeline Freeze | Latches y datapath funcional documentados; ARCH-009 sigue pendiente para representación Debug; diagramas actuales no bastan (AUD-003) y control requiere AUD-001 |
| M5 — Hazard Freeze | Existe aprobación formal y matriz 46. Quitar «matriz pendiente»; la corrección temporal AUD-001 debe revalidar ese cierre, sin confundir aprobación con tests ejecutados |
| M6 — Verification Ready | No hay verification_plan.md ni bancos de prueba, solo .gitkeep; la extensa lista del plan y la matriz 46 aportan criterios, no ejecución ni el entregable completo |
| M7 — CPU Functional | No alcanzado: no hay RTL CPU ni regresión |
| M8 — Debug Functional | No alcanzado: UART/Debug no implementados y decisiones propias abiertas |
| M9 — Full Integration | Futuro; requiere M7/M8 y software |
| M10 — Timing Closure | Futuro; REFERENCE debe demostrar los cuatro slacks/agregados y cobertura, no solo síntesis |
| M11 — Hardware Acceptance | Futuro; requiere validación FPGA real |
| M12 — Release | Futuro; documentación y código final consistentes |

`architecture.md`, `isa.md`, `pipeline.md`, `interfaces.md`, `hazards.md`, `verification_plan.md` y `protocol.md` aparecen como **entregables futuros**. Su ausencia no se contabiliza como siete enlaces rotos ni como siete decisiones arquitectónicas omitidas. Sí impide afirmar que sus gates de entrega estén satisfechos.

## 5. Términos y señales

| Término/señal | Definición vigente o distinción necesaria | Resultado de la revisión |
|---|---|---|
| PC / PC host / instruction_PC / latch.pc / fault_pc | PC global es frente IF; PC host es computadora; latch.pc sigue a la instrucción; fault_pc identifica la causante, no su dirección efectiva ni target | Definidos contextualmente; no fusionarlos |
| valid / fetch_fault_valid | valid habilita una instrucción; IF/ID con valid=0 y fetch_fault_valid=1 transporta un candidato, no una bubble ordinaria | Cinco campos IF/ID cerrados; figura desactualizada, AUD-003 |
| IF/ID.instr frente a instruction | Abreviatura gráfica de la misma word de 32 bits | No es un campo adicional; conveniente uniformar al actualizar figura |
| ID/EX.control | Agrupación semántica de seis categorías; no exige bus ni séptimo control | Historia legítima, revisada explícitamente |
| uses_rs1 / uses_rs2 | Salidas locales de decode, derivadas de fuentes realmente usadas | No son campos registrados; stores usan ambas aunque ALU use inmediato |
| alu_src / Result MUX / WB Value MUX | Primero elige segundo operando ALU; segundo elige resultado EX; tercero el valor arquitectónico en MEM | No intercambiables; AUD-003/007 |
| ex_result / alu_result / wb_value / link_value | ex_result puede ser ALU, inmediato, link o dirección; wb_value es el único resultado hacia WB; link_value no se registra aparte | Coherentes en ADR; dibujo no los refleja completos |
| redirect_valid / redirect_requested / redirect_apply / redirect_commit | Los dos primeros nombran solicitud combinacional; apply es aplicación autorizada; commit es alias de apply | Alias explícito en acuerdo 40; no requiere rename arquitectónico |
| halt_candidate / ex_halt_candidate / halt_confirm / halt_commit | Candidato ID, candidato EX por flow_op, confirmación efectiva EX y alias de confirmación | No detener IF por mera candidatura ID |
| fault_candidate / fault_confirm / fault_capture_fire | Detección local, frontera arquitectónica y captura autorizada | Bien separados nominalmente; AUD-001 demuestra fallo temporal de la excepción |
| fault_cause / fetch_fault_cause | Tres bits con misma tabla; global persistente frente a candidato solo IF/ID | 011 reservado; 000 es causa válida, no NONE |
| terminal_kind / drain_auto | Históricamente registros; sustituidos por estado y predicados combinacionales en acuerdo 44 | No implementar registros redundantes ni viejos enables de escritura |
| terminal_write_enable | A lo sumo alias de evento fault_confirm OR halt_confirm | Sin registro terminal_kind de destino; redacción abreviada de REQ-EXEC-003 puede aclararse |
| fault_valid / finished / image_valid | No registros globales independientes | fault_info_valid/program_finished derivan del estado; image_valid del tamaño |
| global_state / next_state | Estado Moore persistente frente al próximo estado combinacional | Catorce estados semánticos cerrados; codificación binaria libre |
| cpu_enable / cpu_cycle_fire | Alias conceptual de ciclo final efectivo | No confundir con clock físico, enable preliminar ni los enables locales |
| cycle_from_continuous | Procedencia del ciclo actual; significativa con cpu_cycle_fire | Combinacional; puede cambiar al aceptar RUN durante drenado STEP |
| prepare_active / prepare_done | Modo Moore frente a certificación preflanco de preparación ya realizada | prepare_active no veta automáticamente el primer ciclo; AUD-002 |
| load_ok / commit de imagen | Recepción/validación completadas frente a publicación tras preparación | load_ok no publica tamaño ni habilita ejecutar |
| pipeline_empty / pipeline_empty_next | Cuatro valid actuales frente a los cuatro valid_next de la acción actual | fetch_fault_valid no cuenta como ocupación; finalización sin ciclo extra |
| HOLD / stall / bubble / flush | Ausencia de ciclo; retención local dentro de ciclo; entrada inválida; descarte por frontera | Stall cuenta; HOLD no. Invalidar entrada nueva no elimina commit anterior |
| DRAINING / HALT_DRAIN / FAULT_DRAIN | Categorías semánticas que la FSM divide en AUTO/STEP | No son estados adicionales a los catorce ni flags persistentes extra |
| STEP / NEXT | STEP es nombre conceptual; NEXT aparece solo en ejemplo viejo | AUD-012; no fija opcode UART |
| memoria utilizada / valid bitmap / cero lógico | Criterio Debug pendiente; mecanismo de validez por byte aprobado; lectura de no escritos igual a cero | No son sinónimos; no elegir criterio a partir del bitmap |
| sesión / imagen | Imagen confirmada puede reutilizarse para sesión limpia en PREPARING_RUN/STEP | AUD-002: no todo reinicio de sesión es LOAD |
| overflow | Extremo ensanchado de región frente a suma que produce dirección; también política separada de cycle_count | AUD-004/005; no mezclar ambos problemas |
| REFERENCE / ALT_1000 | 1024/2048 bytes con compromiso físico; 1000/1000 con validación de parametrización | No imponer timing físico a ALT_1000 |
| M1 System Freeze / Decision Freeze | Mismo identificador de gate | AUD-013 |

Anchos/campos contrastados: IF/ID tiene **5 campos**, EX/MEM **8**, MEM/WB **6**; ID/EX tiene **10 elementos funcionales** si `control` se cuenta como una agrupación, no diez señales físicas obligatorias. Al expandir las seis categorías, los presupuestos de bits se derivan como IF/ID=69, ID/EX=193, EX/MEM=139 y MEM/WB=103; son sumas de campos del contrato, **no formatos UART ni obligación de empaquetado**. No se detectó una discrepancia de anchos entre los ADR vigentes. Sí faltan ancho/overflow de cycle_count (AUD-005).

`alu_op[5:0]`, `alu_src` de un bit, `result_sel[1:0]`, `flow_op[2:0]`, `mem_op[3:0]` y `reg_write` de un bit alcanzan todas sus categorías sin colisiones. `flow_op` reserva 110/111; `result_sel` reserva 11; `mem_op` reserva 1001–1111. Los códigos `fault_cause` son 000/001/010/100/101/110/111, con 011 reservado. No se debe introducir NONE dentro del código de causa; validez/estado expresa ausencia.

## 6. Aspectos correctamente cerrados

Estos puntos fueron revisados, no se presumen por ausencia de hallazgos. Se exceptúan expresamente los casos de los AUD referidos.

**Obligaciones externas y alcance.** La documentación conserva cinco etapas solapadas, 32 registros con x0 cero, memorias de instrucciones/datos, reprogramación sin nuevo bitstream, ejecución RUN y STEP por ciclo, snapshots y software de PC. No se encontró una obligación explícita de la consigna descartada silenciosamente. Las extensiones de robustez se distinguen de la consigna; faults y halt custom no se confunden con implementar privilegios o todo RV32I.

**Cobertura ISA y decode.** Se contrastó el conjunto completo, no solo los saltos:

| Familia | Instrucciones revisadas | Resultado |
|---|---|---|
| R, 10 | add, sub, sll, srl, sra, and, or, xor, slt, sltu | Pares funct7/funct3 distintos, ambas fuentes, resultado ALU y escritura rd; adaptación heredada de shifts requiere AUD-011 |
| I aritmética, 6 | addi, andi, ori, xori, slti, sltiu | Usa rs1/immediato, sin falso rs2; inmediato con signo también para comparación unsigned |
| I shifts, 3 | slli, srli, srai | Bits fijos y shamt de cinco bits; cantidad no debe incluir campos fijos, AUD-011 |
| Loads, 5 | lb, lh, lw, lbu, lhu | Tamaño/extensión, dirección EX, dato en MEM y WB; no forwarding de la dirección como resultado load |
| Stores, 3 | sb, sh, sw | rs1 base y rs2 dato, forwarding EX para ambos, mem_op y dato registrados hasta MEM |
| Branches, 2 | beq, bne | SUB/zero y PC relativo en EX; no fault de target si no tomado; excepción temporal AUD-001 |
| Otros, 3 | jal, jalr, lui | Link propio PC+4, jalr borra solo bit 0, U-immediate; prueba de alu_src requiere AUD-007 |
| Custom, 1 | halt | Solo word completa 0x0000000B, sin operandos ni writes; custom-0 parcial y cero son ilegales |

Total: **32 RV32I requeridas más halt**. No aparece una instrucción requerida imposible de realizar con el **datapath textual aprobado**; la figura incompleta no debe sustituir ese contrato. AUIPC, otros branches, CSR, FENCE y EBREAK no se incorporan automáticamente por la referencia normativa. El zero de ALU no se toma como condición general de halt.

**Pipeline, forwarding y RF.** EX/MEM precede a MEM/WB para el mismo registro, excluyendo x0 y productores inválidos/sin escritura. Un load más reciente no disponible bloquea usar un valor anterior incorrecto. Hay dos muxes independientes hacia EX y bypass WB→ID de valores previos al flanco. El stall load-use nominal es un ciclo, no congela etapas posteriores, usa fuentes semánticas y alcanza datos de store y branches/jalr. No se exige bypass combinacional DMEM→EX ni store-data adicional en MEM. x0 tiene prioridad de lectura cero y no acepta writes. Se revisó la matriz de 23 casos de RF: el nuevo MEM/WB capturado al flanco no se usa retroactivamente como WB preflanco.

**Campos y next-state.** PC e instrucción viajan en los cuatro latches. EX/MEM conserva una única ex_result y store_data separada; MEM/WB conserva una única wb_value. Bubble/flush permiten residuos sin actividad. Invalidar ID/EX.next no invalida la instrucción preflanco que avanza a EX/MEM. Stores MEM y writes WB más antiguos conservan su commit en el ciclo de una frontera joven. Las nueve acciones distinguen correctamente hold, capture e invalidate **localmente**; esa coherencia local no resuelve AUD-001.

**Control global.** La FSM de catorce estados tiene salidas Moore y un bloque separado de autorización. RESET domina; LOAD aceptado domina; LOAD rechazado no detiene RUN. STEP tiene prioridad sobre RUN entre comandos elegibles. Se separan captura/commit de imagen y primer ciclo de una sesión reutilizada. `pipeline_empty_next` permite finalizar en el mismo flanco que vacía el último valid, sin realimentar next_state al ciclo actual. Los estados y ecuaciones más recientes son internamente coherentes en ese aspecto; los textos viejos requieren AUD-002/006.

**Halt y faults nominales.** Halt se detecta como candidato ID y confirma en EX, sin necesidad de que el programa lo contenga. Los loops no terminan por timeout ni por fin de imagen. Ilegal ID y fetch candidato son distintos; causas de EX usan el PC propio. La prioridad de desalineación sobre acceso pertenece a la misma operación, no es una prioridad global por tipo. Target alineado fuera de imagen puede redirigir y fallar después en IF; target desalineado falla en el salto sin redirect ni link. El par global causa/PC permanece válido en drenado y FAULT, distinto de FINISHED. **La prioridad temporal completa no está cerrada correctamente por AUD-001**.

**Memorias e imagen.** Harvard lógico, bases cero, direcciones en bytes, little-endian y acceso simultáneo IF/MEM son coherentes. IMEM usa words de 32 bits; DMEM cuatro lanes lógicos, sin exigir cuatro RAM físicas. Rango completo y alineación se comprueban antes de índice físico; un store inválido debe inhibir todos los bytes. Capacidad válida entre 4 y 2^32 inclusive y múltiplo de cuatro, sin exigir potencia de dos. Perfil válido no soportado no equivale a parámetro arquitectónicamente inválido.

`loaded_image_size_bytes` es la única fuente global persistente, image_valid se deriva; no hay bitmap IMEM ni instruction count redundante. El ancho inclusivo produce **3,10,11,33 bits** para capacidades **4,1000,1024,2^32**, respectivamente; se recalcularon esos valores. Imagen contigua no vacía, tamaño múltiplo de cuatro, entrada cero; una imagen más corta invalida su sufijo residual. LOAD aceptado pone tamaño cero; load_ok no lo publica; commit completo sí. No se exige rollback.

Lecturas combinacionales y escrituras síncronas son consistentes con cinco etapas y forwarding. No hay handshake ready ni stall por memoria. DMEM no escrita devuelve cero por byte antes de ensamblado/extensión; valid bits se actualizan atómicamente con datos. Ownership exige **a lo sumo uno**, permite ningún agente y no exige CPU/Debug directo concurrentes. Un mirror no cambia ese contrato.

**Reset, clock y timing.** Reset interno activo alto, normalización física única, acondicionamiento de dos etapas con aserción asíncrona/desaserción sincronizada y consumo funcional síncrono son compatibles. La secuencia 11→10→00 del sincronizador coincide con la asignación escrita. El reset funcional puede necesitar el primer flanco válido tras pérdida de clock; locked no elude el acondicionamiento. No se exige un debouncer ni se promete capturar pulsos arbitrariamente cortos. Reset y preparación de sesión son eventos distintos; no es necesario borrar arrays físicos durante reset. La invalidez de candidatos IF/ID está exigida en los contratos posteriores: al consolidar la tabla de reset conviene escribir también fetch_fault_valid=0, sin cambiar política.

Basys 3, entrada de 100 MHz y dominio funcional único objetivo de 50 MHz corresponden a ARCH-005. Los ticks UART son enables, no clocks distribuidos. WNS≥0, TNS=0, WHS≥0 y THS=0 se exigen post-implementation para caminos relevantes restringidos, junto con cobertura y excepciones justificadas. Elegir 50 MHz no demuestra cumplirlo; timing closure no es prerrequisito retroactivo para aprobar el ADR. No se acepta cambiar silenciosamente latencia de memoria para cerrar timing.

**Debug, UART y software.** El snapshot mínimo, coherencia de un único estado lógico y distinción de PC global/latches/fault están definidos suficientemente para continuar las decisiones abiertas. No se exige capturar durante RUN ni transmitir memorias completas. Representación externa, criterio de memoria utilizada, captura, baud, framing y timeouts permanecen pendientes según su ámbito; no se han elegido en esta auditoría. La alternativa de CLI del plan es recomendación. Endianness arquitectónico no fija endianness UART. Los valores por defecto del TP2 no se trasladan automáticamente al TP3.

**Historia legítima.** Los primeros IF/ID de tres campos, terminal_kind/drain_auto registrados y controles todavía sin códigos se conservan como etapas anteriores explícitamente revisadas por los acuerdos 29,33–35 y44. No se propone borrarlos. Las listas de pruebas, matrices y aprobaciones no se confundieron con evidencia de RTL/hardware ejecutado. Los detalles de packing, nombres de señales, recursos inferidos, cantidad de bits limpiados por ciclo, FSM privadas del loader y pin/XDC concretos no generan por sí solos decisiones arquitectónicas faltantes.

## 7. Pendientes reales después de la auditoría

Aplicar solamente correcciones objetivas **no resuelve AUD-001/004/005**. Antes de congelar control/contratos deben atenderse:

1. **Revisión de ARCH-003 por AUD-001:** preservar antigüedad a través de la excepción IF y revalidar matriz 46 frente a ARCH-004.
2. **Aclaración de ARCH-001/REQ-MEM-018 por AUD-004:** alcance de overflow sin cambiar silenciosamente SYS-010.
3. **Asignación y cierre del pendiente de contador por AUD-005:** ancho y comportamiento observable. No se impone un ID nuevo.

Después, el orden de decisiones ya registradas, conforme a hitos y dependencias, sigue siendo:

| Orden | Decisión pendiente real | Condición para avanzar |
|---|---|---|
| 1 | DEC-SYS-007 | Es la primera fila pendiente (M2); clock/placa y contratos previos disponibles |
| 2 | DEC-SYS-009 | M3; respetar subconjunto, imagen, perfil y halt custom ya aprobados |
| 3 | DEC-ARCH-009 | M4; definir representación externa de campos y estado, respetando resultado de revisión de control |
| 4 | DEC-SYS-005 | Antes de diseñar Debug/protocolo; criterio de utilizada y observación coherente con ownership |
| 5 | DEC-PROTO-001 | Cerrar después de SYS-005/007/ARCH-009; integrar la política del contador cuando se asigne |
| 6 | DEC-PROTO-002 | Requiere SYS-007; puede trabajarse junto a PROTO-001 sin imponer entre ambos una dependencia inexistente |
| 7 | DEC-PROTO-003 | Después de PROTO-001/002; recuperación de transporte |
| 8 | DEC-SYS-008 | Con flujos Debug/protocolo definidos; puede avanzar en paralelo con tareas que no condicionen su elección |

Este es el orden de cierre documental recomendado, no una prohibición de trabajo independiente: SYS-005 ya tiene sus prerequisitos aprobados, aunque su deadline sea posterior. Ninguno de los ocho IDs debe eliminarse por el solo hecho de que el CPU textual esté avanzado. La política interna de RUN/STEP/LOAD ya aprobada no se vuelve pendiente al diseñar su representación UART.

Tras resolver los hallazgos y pendientes que correspondan al hito, se pueden preparar diagramas coherentes. Para comenzar RTL por módulo siguen haciendo falta contratos revisables y verificación prevista según el plan. La auditoría no reemplaza simulación, síntesis, timing ni validación física.

## 8. Parches recomendados

**Propuestas únicamente; no aplicadas a los documentos originales.** Los cambios siguientes no eligen políticas nuevas. AUD-001, AUD-004 y AUD-005 quedan excluidos de parches automáticos: sus preguntas y criterios están desarrollados en §2.

### AUD-002 — Propagar sesión, aceptación y preparación

En ARCH-008, sustituir el cierre de `decisions.md:4185`:

```diff
- READY y HOLD serán descripciones semánticas, no estados RTL obligatorios.
+ READY es un estado de la FSM global aprobada en DEC-ARCH-003, acuerdo 44.
+ HOLD describe ausencia de ciclo efectivo y no añade otro estado a esa FSM.
```

Sustituir las afirmaciones de arbitraje/elegibilidad todavía pendiente de `decisions.md:4302–4304,4331` y `plan.md:872,1237,1310` por:

> El acuerdo 44 de DEC-ARCH-003 fija RESET > LOAD > STEP > RUN entre comandos elegibles y admite LOAD desde NO_IMAGE, READY, STEPPING, HALT_DRAIN_STEP, FAULT_DRAIN_STEP, FINISHED y FAULT; no lo admite en RUNNING ni drenado AUTO. RUN/STEP aceptados en FINISHED/FAULT preparan una sesión nueva y limpia con la imagen confirmada mediante PREPARING_RUN/STEP; no reanudan la sesión terminal. Reset global sigue siendo recuperación mínima y, al invalidar la imagen, requiere LOAD posterior. Respuesta, payload, framing y vías UART adicionales permanecen en las decisiones de protocolo.

En el resumen de alcance `decisions.md:4327`:

```diff
- DEC-ARCH-003 fija después únicamente la representación registrada de la frontera terminal y el modo de drenado.
+ DEC-ARCH-003, acuerdo 44, fija la FSM global de 14 estados, aceptación de
+ comandos y autorización separada del ciclo. La codificación binaria,
+ FSM privadas y realización física de enables siguen sin imponerse aquí.
```

Donde el plan vete todo ciclo por «preparación activa» (`:1227,1241` y pruebas equivalentes), usar:

> Las escrituras efectivas de preparación inhiben ciclos CPU. prepare_active identifica el modo; en PREPARING_RUN/STEP con prepare_done, la preparación ya está completa antes del flanco y no hay writes concurrentes de mantenimiento/Loader: ese flanco ejecuta el primer ciclo CPU y deja cycle_count=1. PREPARING_READY con prepare_done publica la sesión y queda READY sin ciclo CPU.

Sustituir la prueba ambigua repetida de RUN/STEP en FINISHED/fault (`plan.md:1812,1830,1838,1856`, localizando la frase si la línea cambia) por:

> Sin imagen, RUN/STEP no ejecutan ni preparan una sesión ejecutable. En FINISHED/FAULT con imagen confirmada, un RUN/STEP elegible no ejecuta la sesión anterior: acepta la orden, entra a PREPARING_RUN/STEP y consume su primer ciclo al cumplirse prepare_done. En drenado STEP, STEP ejecuta uno y RUN puede convertir a AUTO; en drenado AUTO se aplican las reglas del contexto continuo.

Las menciones de «no prescribir arbitraje RUN/LOAD» en `plan.md:1900,1915` se limitan al **formato/respuesta de transporte**; para el arbitraje interno remiten al acuerdo 44.

### AUD-003 — Distinguir ilustración y contrato, y regenerar la exportación

Cambio textual inmediato propuesto, visible en TeX y SVG:

> ILUSTRACIÓN PARCIAL DESACTUALIZADA — Rev. 02. No usar como contrato de implementación. Rutas y campos vigentes: DEC-ARCH-003, acuerdos 11–14, 18–27, 29 y 33–44; faults sujetos a revisión AUD-001. DEC-ARCH-009 solo define representación externa.

Para la siguiente revisión gráfica, aplicar este cambio conceptual de conexiones, todas derivadas de acuerdos existentes:

```text
PC+4 y redirect_target -> Next-PC MUX -> PC (con pc_write_enable)
Immediate Generator -> ID/EX.immediate
rs2_effective e ID/EX.immediate -> ALU Source MUX -> ALU.B
ALU(SUB).zero -> decisión BEQ/BNE
ID/EX.pc+immediate y (rs1_effective+immediate)&~1 -> Target MUX
ID/EX.pc+4 -> link_value
alu_result / immediate / link_value -> Result MUX -> EX/MEM.ex_result
EX/MEM.ex_result -> DMEM.address
EX/MEM.store_data -> DMEM.write_data
```

Añadir IF/ID.fetch_fault_valid/fetch_fault_cause y EX/MEM.mem_op, o declarar explícitamente que son campos omitidos de una vista parcial. Mostrar en una lámina de control separada o mediante referencias inequívocas Hazard Control, autorización, validación/faults y enables; no fingir que flechas de datos los reemplazan. Conservar las rutas de forwarding y WB aprobadas. Regenerar SVG desde el TeX corregido y verificar que Control y sus conexiones sean iguales en ambas representaciones; actualizar Rev. No aplicar este patch gráfico dentro de la auditoría.

### AUD-006 — Actualizar resúmenes y gates sin borrar historia

En contexto de ARCH-003 (`decisions.md:961,963`), reemplazar las afirmaciones vigentes de matriz/integración pendiente por:

> Los acuerdos 40–45 fijan confirmación, acciones, enables, efectos CPU, autorización global y coincidencias; el acuerdo 46 documenta la matriz final y el cierre formal de la decisión. Los acuerdos 1–45 conservan su estado histórico. El cierre documental no demuestra verificación RTL ejecutada; la revisión puntual identificada en AUD-001 debe resolverse antes de utilizar este contrato para implementación.

En `plan.md:771`:

```diff
- solo resta la matriz final de cierre.
+ la matriz final está documentada en el acuerdo 46. Resta ejecutar la
+ verificación sobre RTL y resolver la revisión temporal AUD-001.
```

En `plan.md:829,1221`, sustituir «generación del ciclo global abierta» por «generación del ciclo global fijada en el acuerdo 44». En `requirements.md:165`:

```diff
- El acuerdo 44 fija la generación del ciclo global; otras coincidencias siguen pendientes.
+ El acuerdo 44 fija la generación del ciclo global; el acuerdo 45 audita
+ las coincidencias y el 46 recoge la matriz final. La revisión AUD-001
+ debe preservar las obligaciones de fault preciso de este requisito.
```

Para los demás resúmenes que difieren enables/flush/control ya cerrado, usar referencias concretas a acuerdos 40 (eventos), 41 (nueve acciones), 42 (next-state), 43 (efectos), 44 (autorización) y 45–46 (integración/matriz). Mantener pendientes reales de Debug/protocolo y detalles físicos. Dentro de historia legítima, basta «en ese momento quedaba pendiente; resuelto posteriormente en acuerdo N», sin borrar texto.

Como aclaraciones asociadas a propagación, sin nuevas políticas: en las tablas consolidadas de reset escribir `IF/ID.fetch_fault_valid=0` junto con valid=0, conforme a requirements:194; en REQ-EXEC-003 aclarar que `terminal_write_enable` es alias de evento y no habilita un registro terminal_kind.

### AUD-007 — Corregir expectativa del decoder

En `plan.md:723`:

```diff
- incluidos ADD/RS2 deterministas pero no consumidos en jal, lui o halt
+ incluidos alu_op=ADD y alu_src=1 (IMMEDIATE) para jal/lui,
+ y alu_op=ADD y alu_src=0 (RS2) para halt, deterministas y sin
+ consumo funcional de la ALU en esas tres clases
```

### AUD-008 — Corregir destinos de referencias

```diff
# plan.md:599
- el uso de rs1 y rs2 por instrucción en pending_decisions.md
+ el uso de rs1 y rs2 por instrucción en decisions.md, DEC-ARCH-003, acuerdo 3A

# plan.md:619
- la tabla exhaustiva de este trigésimo séptimo acuerdo en pending_decisions.md
+ la tabla exhaustiva del acuerdo 37 de DEC-ARCH-003 en decisions.md
```

### AUD-009 — Completar trazabilidad existente

```diff
# decisions.md, Requisitos afectados de DEC-ARCH-002 y DEC-ARCH-003
+ REQ-DOC-008

# pending_decisions.md, DEC-SYS-009, Depende de
+ DEC-SYS-001, ya aprobada

# pending_decisions.md, DEC-SYS-009, Requisitos afectados
+ REQ-SW-012
```

Añadir al contexto de SYS-009:

> La estrategia elegida deberá aceptar halt sin operandos y emitir exactamente 0x0000000B, conforme a DEC-SYS-001 y REQ-SW-012; integrar una herramienta RV32I no elimina esa obligación custom.

No cambiar el `—` de DOC-001 a un origen inventado. Se puede documentar su cobertura transversal mediante el registro completo de decisiones.

### AUD-010 — Completar el contrato del modelo de referencia

Reemplazar la lista de `plan.md:2034–2041` por:

> El modelo distinguirá finalización por halt y las siete causas internas: instruction-address-misaligned, instruction-access-fault, illegal-instruction, load-address-misaligned, load-access-fault, store-address-misaligned y store-access-fault. Conservará el PC causante y suprimirá todos los efectos de la instrucción defectuosa. Distinguirá target desalineado de control —sin redirect ni link— del fetch posterior a un target alineado fuera de imagen. Aplicará prioridad de desalineación sobre acceso dentro de una operación. Puede usar categorías simbólicas equivalentes a fault_cause; no necesita modelar pipeline, drenado ni formato UART. En las pruebas de fault se compararán causa, PC y ausencia de efectos, además de registros y memoria.

### AUD-011 — Documentar adaptación de shifts

Añadir después de `decisions.md:1903` y remitir desde `plan.md:613`:

> Preservar códigos de la ALU de TP1/TP2 no implica reutilizar sin adaptación todas sus operaciones. En el contrato RV32, SLL/SRL/SRA emplean exclusivamente los cinco bits bajos del operando de cantidad seleccionado, tanto por registro como por inmediato. SRA interpreta con signo el dato desplazado; los bits fijos de SRAI no forman parte de shamt. La adaptación puede realizarse dentro de la ALU o en su frontera sin cambiar el resultado observable ni los opcodes aprobados.

Añadir a verificación:

> Con dato 0x80000000 y cantidades 0,31,32,33 y 0xFFFFFFFF, contrastar SRL/SRA y los casos equivalentes de SLL; repetir con cantidad reenviada. Comprobar SRAI legal con shamt pequeño para detectar uso indebido de sus bits fijos como cantidad. No cambiar la semántica de los TPs anteriores para satisfacer el contrato CPU.

### AUD-012 — Usar identificadores reales en ejemplos

```diff
# plan.md:179–187
- REQ-CPU-001 — pipeline de cinco etapas
+ REQ-CPU-002 — etapas IF, ID, EX, MEM y WB
- REQ-EXEC-002 — NEXT permite un ciclo
+ REQ-EXEC-009 — STEP permite exactamente un ciclo
- REQ-DBG-003 — enviar 32 registros
+ REQ-DBG-005 — transmitir los 32 registros con índice y valor

# plan.md:1451–1454
- REQ-ISA-ADD
+ REQ-ISA-008
- REQ-ISA-LB
+ REQ-ISA-018
- REQ-HAZ-LOAD
+ REQ-HAZ-004
- REQ-EXEC-STEP
+ REQ-EXEC-009
```

Mantener explícitamente que nombres de tests y sus estados son ejemplos, no pruebas ejecutadas.

### AUD-013 — Unificar nombre del hito

```diff
# pending_decisions.md:33
- M1 — System Freeze
+ M1 — Decision Freeze
```

**Control de alcance:** este informe es el único archivo creado en TP3. Se conservaron los documentos, diagramas y fuentes originales; las propuestas anteriores quedan para revisión posterior. No se escribió RTL ni se eligieron UART, protocolo, assembler o interfaz de usuario.

</details>

</details>
