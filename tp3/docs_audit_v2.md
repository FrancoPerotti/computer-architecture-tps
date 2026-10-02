# Segunda auditoría arquitectónica adversarial — TP3

> **Actualización de vigencia — 2026-09-30.** Las conclusiones del cuerpo corresponden a la revisión original. AUD2-002 está resuelto documentalmente en el estado actual: REQ-HAZ-004 de [Requisitos](docs/requirements.md), los criterios de drain del [Plan](docs/plan.md) e I21 de [Invariantes](docs/architecture/architectural_invariants.md#alcanzabilidad-del-drain) separan drain legal y prueba artificial de `act_drain_load_use`. Se conserva abajo el hallazgo original y su evidencia sin atribuirle un bloqueo vigente. AUD2-001 sigue retirado; el draw.io externo no fue aportado al árbol. El alcance y la verificación actuales están en [la auditoría final de integración](docs_integration_audit.md).

Fecha: **2026-09-26**. Alcance: documentación y modelo de los contratos, **sin RTL ni correcciones de arquitectura**. Las citas corresponden al árbol de trabajo de esta fecha, no a los números de línea de la primera auditoría.

**Aclaración posterior del autor:** el diagrama se desarrolla por separado en draw.io y los archivos LaTeX/SVG anteriores se eliminaron deliberadamente. AUD2-001 queda retirado como defecto; el diagrama externo no fue revisado en esta auditoría. Permanece abierto AUD2-002.

## 1. Resumen ejecutivo

**No están corregidas y acreditadas todas las inconsistencias documentales.** La política funcional de AUD-001, la aritmética de AUD-004 y el contador de AUD-005 están propagados. No encontré un nuevo contraejemplo funcional de severidad HIGH/CRITICAL en el contrato CPU vigente. Tras la aclaración del autor sobre la migración del diagrama, queda un hallazgo documental abierto:

- **AUD2-001, retirado:** la ausencia de TeX/SVG responde a la migración deliberada a draw.io. No es una regresión del proyecto ni obliga a restaurar esos archivos. El nuevo diagrama queda fuera del alcance verificado.
- **AUD2-002, LOW:** el plan aún exige escenarios de stalls entre supervivientes durante drenado sin distinguir que son inalcanzables desde una sesión legal bajo el acuerdo 47. Puede originar cobertura imposible o pruebas artificiales presentadas como ejecución real.

Esto no significa que el hardware esté verificado ni que todos los pendientes del sistema estén cerrados. Se puede diagramar el núcleo CPU conforme a los contratos actuales. No está acreditada la preparación del sistema completo para RTL: faltan entregables de interfaces/diagramas y permanecen decisiones de integración explícitamente abiertas.

### Método y alcance de la evidencia

Se reconstruyeron dos modelos temporales: un intérprete secuencial sobre instrucciones con operandos concretos y un pipeline sobre words codificadas, decoder, forwarding, valores preflanco, acciones del acuerdo 47 y retiro de instrucciones. El intérprete no utiliza el decoder ni la función ALU del pipeline. Comparten el codificador de estímulos y convenciones básicas de ancho; esa independencia es parcial, no una certificación externa.

El pipeline se contrastó contra el intérprete mediante orden de retiro, RF, bytes escritos/validez lógica de DMEM, causa/PC y terminación. Se siguieron stores en MEM y escrituras en WB por identidad dinámica para detectar duplicación. Los programas dirigidos comienzan con RF/DMEM lógicamente en cero; los que necesitan datos distintos de cero los escriben mediante instrucciones del propio programa. No se presume una DMEM inicial incompatible con la política de sesión.

Las pruebas son ejecutables Python temporales fuera del proyecto. No constituyen RTL, simulación HDL ni prueba formal exhaustiva de todas las imágenes de 32 bits. Las demostraciones por inducción que se exponen se limitan a las ecuaciones documentadas y a estados alcanzables, con memoria de latencia fija y sesión estable. La implementación privada de Loader, preparación y snapshot sigue fuera de ese modelo.

| Comprobación ejecutada | Alcance / resultado |
| --- | --- |
| Pipeline diferencial principal | 13,120 ejecuciones: 40 programas dirigidos × 2 capacidades × RUN/STEP, 12.000 programas aleatorios y 960 vectores de ISA. Sin divergencias. |
| Ampliación dirigida | 12 programas × RUN/STEP = 24 ejecuciones adicionales; más 1 inyección explícita de PC=3 para el validador IF. Sin divergencias. |
| Aleatoriedad | Semilla 9262026; 2–8 instrucciones; hasta 100 ciclos efectivos por ejecución aleatoria; intérprete hasta 1.000 instrucciones. Branches/jumps, datos extremos, ilegales y halt. |
| Bucles dirigidos | 30 ciclos efectivos RUN y STEP/HOLD por caso; además, argumento de repetición del estado funcional para los bucles de dos instrucciones. |
| Contador | 280 repeticiones con 7 semillas de contador; 6 wraps dirigidos en stall, redirect, halt, fault EX/ID y drenado. Sin cambio del resto del estado. |
| Decoder | 393.216 combinaciones de campos fijos con tres elecciones de campos libres; 1.060.869 vectores de inmediatos I/S/B/J/U. 33 clases legales. |
| Control | 256 combinaciones booleanas de acciones; 512 de selección de forwarding; 1.296 de gating con validez/controles residuales. |
| FSM | 8.064 combinaciones de estado, comandos, reset, done, resultados de carga, frontera y vaciado; incluye entradas irrelevantes fuera de su modo. |
| Memoria | 162 vectores de región completa y 112 de ensamblado/extensión sobre todos los 16 patrones de validez de una word. |
| Sensibilidad de las pruebas | 8 mutaciones deliberadas de reglas del pipeline detectadas; se detallan abajo. |
| Dependencias | Grafo de 62 nodos y 144 aristas, con orden topológico; sin ciclo en la interfaz funcional documentada. |
| Diagramas presentes | 14 bloques Mermaid en plan.md y 3 en consigna.md revisados como esquemas generales. No hay archivos en docs/figures. |

Los 960 vectores de ISA ejercitan 32 instrucciones × 5 valores de primer operando × 6 valores del segundo operando/inmediato. `halt` tiene pruebas dirigidas propias. El barrido de decoder no enumera las 2^32 words; combina cobertura de campos fijos con comprobación de las máscaras y campos libres. Las tablas de acciones y FSM tampoco convierten coincidencias lógicamente imposibles en estados alcanzables.

Mutaciones detectadas: prioridad WB sobre EX/MEM reciente; omisión de bypass WB→ID; omisión del stall load-use; store con dato base obsoleto; enlace calculado desde PC global; fault_pc tomado de PC global; avance durante HOLD; y entrada válida a MEM de la causante de fault EX. Esto muestra que la batería puede detectar errores relevantes; no demuestra ausencia de cualquier otro error.

## 2. Verificación de AUD-001 a AUD-013

Categorías de texto residual: **A** historia explícitamente revisada; **B** historia o evidencia anterior presentada como vigente; **C** contrato/criterio actual incorrecto o no realizable. Una mención histórica no reabre automáticamente un hallazgo.

| Hallazgo | Estado actual | Evidencia y límite |
| --- | --- | --- |
| AUD-001 | Parcialmente resuelto documentalmente; política funcional resuelta | decisions:3120–3266; requirements:97,165; plan:31,1643. No excepción IF vigente. Resta precisar cobertura de drenado: AUD2-002. |
| AUD-002 | Resuelto | decisions:2899–2997 y ARCH-008:4294,4349–4430; plan:935,1225. Sesión nueva terminal, aceptación por estado y primer ciclo en prepare_done. |
| AUD-003 | Diagrama anterior retirado; nueva versión externa no auditada | El autor confirmó que eliminó TeX/SVG y desarrolla el diagrama en draw.io por separado. No se considera una regresión. El cierre gráfico anterior no certifica la nueva versión. |
| AUD-004 | Resuelto | decisions:655–676,2358–2370,3318–3334; requirements:128 (REQ-MEM-018); plan:1613. EA modular y extremo de región ensanchado. |
| AUD-005 | Resuelto | decisions:452–470,2995; requirements:193; plan:1866–1870; pending_decisions:3. Ancho y wrap cerrados, transporte UART abierto. |
| AUD-006 | Resuelto para las inconsistencias denunciadas | decisions:987–1011,3120–3266; plan:31,883,937,1991. Pendientes dentro del desarrollo histórico no son bloqueos actuales. |
| AUD-007 | Resuelto | plan:725 frente a decisions:2131–2136: jal/lui ADD+inmediato; halt ADD+RS2. |
| AUD-008 | Resuelto | plan:601,619–621 remite a agreements aprobados en decisions.md. |
| AUD-009 | Resuelto | Backlinks REQ-DOC-008 en ARCH-002/003; pending_decisions:169–185 incorpora SYS-001 y halt custom para SYS-009. |
| AUD-010 | Resuelto documentalmente | plan:2058–2069 exige modelo de siete causas, PC, efectos y distinción target/fetch. No afirma que ese modelo de producto ya exista. |
| AUD-011 | Resuelto | decisions:2062; plan:805. Cinco bits de shamt, SRA signed, separación de bits fijos de SRAI. |
| AUD-012 | Resuelto | plan:182,1451 y referencias de aceptación usan IDs correctos. |
| AUD-013 | Resuelto | pending_decisions:35: M1 — Decision Freeze. |

## 3. Nuevos hallazgos

### AUD2-001 — Retirado tras aclaración de migración a draw.io

**Estado actual:** retirado como defecto, sin severidad activa. **Clasificación inicial:** MEDIUM, evidencia gráfica ausente. Se conserva el identificador para trazabilidad.

**Aclaración del autor:** el diagrama se está haciendo por separado en draw.io; los archivos anteriores se eliminaron deliberadamente al abandonar LaTeX. La ausencia observada tiene una explicación compatible con el trabajo en curso.

**Documentos afectados:** `docs_audit.md`; entregables declarados `docs/figures/pipeline_datapath.tex` y `docs/figures/pipeline_datapath.svg`.

**Evidencia exacta:** `docs_audit.md:5` declara los trece hallazgos cerrados; `:17` declara datapath Rev. 03 y enlaza ambos archivos; `:42` afirma compilación, exportación e inspección; `:48–56` describe rutas y ordena reproducir desde `docs/figures`; `:75` presenta ese diagrama como referencia para continuar. El inventario actual (`rg --files` y comprobación de existencia) no contiene el directorio ni los archivos. Solo hay esquemas Mermaid generales en los documentos.

**Interpretación revisada:** las afirmaciones sobre Rev. 03 describen el artefacto anterior, no el diagrama nuevo de draw.io. Su ausencia no demuestra una inconsistencia arquitectónica ni una regresión. La nueva versión no estuvo disponible para esta auditoría y no se presume correcta o incorrecta.

**Alcance pendiente:** revisar el diagrama de draw.io contra los contratos vigentes cuando forme parte del material de revisión. Es trabajo de verificación del nuevo entregable, no un hallazgo por haber eliminado LaTeX.

**Acción documental aplicada:** se actualiza este informe para retirar el diagnóstico de regresión y distinguir el diagrama anterior de la versión externa en desarrollo. No se requiere restaurar TeX/SVG ni elegir una herramienta distinta de draw.io.

**Decisión humana:** ninguna pendiente por este hallazgo; el autor ya aclaró el cambio de herramienta. No hay contraejemplo temporal asociado.

### AUD2-002 — Cobertura de drenado exige escenarios inalcanzables sin identificarlos

**Severidad:** LOW. **Tipo:** criterio de verificación desactualizado tras revisión; no es un nuevo bug funcional del pipeline. **Categoría:** C en el criterio de cobertura, no en las ecuaciones de control.

**Evidencia exacta:** `docs/plan.md:1637` exige drenado «con los stalls necesarios»; `:1651` contempla estabilidad de metadata aunque «ocurra un stall load-use entre supervivientes»; `:1655` incluye ese stall dentro de estados HALT_DRAIN/FAULT_DRAIN. `docs/requirements.md:97` conserva la referencia general a stalls entre supervivientes durante drenado. No se distingue prueba combinacional con estado forzado de programa ejecutable desde reset. El acuerdo 47 conserva expresamente las dos acciones de drain (`decisions:3165–3175,3215–3223`), por lo que **no corresponde eliminar una acción** como arreglo.

**Demostración temporal e inductiva:**

1. Antes de confirmar frontera puede haber una EX anterior y etapas MEM/WB activas.
2. En toda confirmación EX o ID, `ifid_invalidate=1` e `idex_bubble=1` (`decisions:3200–3207`). Después del flanco, IF/ID.valid=0, fetch_fault_valid=0 e ID/EX.valid=0. Solo EX/MEM y MEM/WB pueden sobrevivir.
3. HOLD conserva esos ceros. `act_drain_advance` vuelve a invalidar IF/ID y captura su validez cero en ID/EX. `load_use_stall` exige ambas entradas válidas (`decisions:2238–2249`), por lo que permanece en cero.
4. Por inducción, `act_drain_load_use` y forwarding hacia una EX válida durante drenado son inalcanzables desde las inicializaciones y transiciones aprobadas. No hay una instrucción anterior pendiente de resolver en EX después de confirmar la frontera.

Ejemplo completo: `lw_alu` en §4 confirma fetch PC=8 en ciclo 5 con el consumidor en EX; después queda exclusivamente en EX/MEM y luego MEM/WB. Drena en 6–7 sin stall. `simultaneous_WB_MEM_fault` confirma con WB y store MEM simultáneos, y drena únicamente el store ya trasladado a WB. Estos ejemplos no sustituyen la inducción anterior.

**Impacto:** un cover de stall durante drain, exigido desde reset, nunca cierra. Forzar IF/ID e ID/EX válidos en drain oculta que se está probando un estado artificial; podría inducir cambios indebidos en el diseño para satisfacer el test.

**Dirección de solución:** mantener las ocho acciones y la FSM; probar las dos ramas combinacionalmente con entradas artificiales rotuladas; añadir una propiedad de alcanzabilidad que exija IF/ID e ID/EX vacíos durante drain. Reescribir los escenarios end-to-end para comprobar commits MEM/WB y HOLD/RUN/STEP. No se modificaron esos documentos.

**Decisión humana:** no; se deriva objetivamente de la revisión aprobada. No exige registros ni otra FSM.

## 4. Contraejemplos multiciclo intentados y resultado

No se encontró un contraejemplo funcional nuevo en la batería. Se conservan las trazas concretas para que esa conclusión sea revisable. Los nombres de caso son identificadores de ensayo, no decisiones nuevas.

**Convención:** cada fila muestra estado **preflanco** de PC/IF y los cuatro latches; la última columna muestra estado global previo→posterior. La fila siguiente es el estado posterior del pipeline; las acciones de §6 determinan el próximo PC. `pc:mnemonic#id` identifica instrucción y emisión dinámica. En las tablas, PC, direcciones y words están en hexadecimal; los números de ciclo/fila son decimales. En los objetos JSON de resultado, los números y claves de dirección son decimales y los valores de registros se expresan como strings hexadecimales. `F1@8` en IF/IFID es candidato; en la columna evento es confirmación. `-` significa entrada inválida; los bits residuales físicamente permitidos se omiten. `writes` son efectos de las entradas MEM/WB previas, no de las recién capturadas.

Las filas HOLD de STEP son clocks físicos sin `cpu_cycle_fire`; por eso no incrementan el contador CPU aunque sí numeran filas. En RUN la primera fila representa el RUN aceptado desde READY; en STEP, cada fila con fire=1 corresponde a una nueva orden y entre ellas se insertan dos HOLD. Una última fila terminal sin fire verifica ausencia de ciclo vacío adicional. El contador no se muestra como columna extra: arranca en 0 y su valor posterior es la suma de fire módulo 2^64, excepto los ensayos específicos de wrap.

Los bucles se muestran durante 30 ciclos efectivos. En `lw_beq_taken`, después del arranque se repite cada cinco ciclos el estado funcional del cuerpo (salvo contador e identidad de auditoría), con x1=0 y sin escrituras de memoria; la misma transición vuelve a descartar el fetch joven en cada iteración. Los otros bucles se comprueban de la misma manera con sus operandos constantes. La batería aleatoria es acotada y no implica una prueba universal de terminación.

<details>
<summary>lw_alu</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 00908113    addi x2,x1,9
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:addi#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | F1@8 | 4:addi#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | F1@8 | 4:addi#1 | - | 0:lw#0 | 1 | id_fault | x1=00000000 | F1@8 | RUNNING→FAULT_DRAIN_AUTO |
| 6 | c | F1@c | - | - | 4:addi#1 | - | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 7 | c | F1@c | - | - | - | 4:addi#1 | 1 | drain_advance | x2=00000009 | - | FAULT_DRAIN_AUTO→FAULT |
| 8 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [1, 8], "registers": {"x2": "00000009"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_beq_taken</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: fe008ee3    beq x1,x0,-4
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:beq#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:beq#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | F1@8 | 4:beq#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | F1@8 | 4:beq#1 | - | 0:lw#0 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 6 | 0 | 0:lw#3 | - | - | 4:beq#1 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 4 | 4:beq#4 | 0:lw#3 | - | - | 4:beq#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 8 | 8 | F1@8 | 4:beq#4 | 0:lw#3 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 9 | 8 | F1@8 | 4:beq#4 | - | 0:lw#3 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 10 | c | F1@c | F1@8 | 4:beq#4 | - | 0:lw#3 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 11 | 0 | 0:lw#6 | - | - | 4:beq#4 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 12 | 4 | 4:beq#7 | 0:lw#6 | - | - | 4:beq#4 | 1 | normal | - | - | RUNNING→RUNNING |
| 13 | 8 | F1@8 | 4:beq#7 | 0:lw#6 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 14 | 8 | F1@8 | 4:beq#7 | - | 0:lw#6 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 15 | c | F1@c | F1@8 | 4:beq#7 | - | 0:lw#6 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 16 | 0 | 0:lw#9 | - | - | 4:beq#7 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 17 | 4 | 4:beq#10 | 0:lw#9 | - | - | 4:beq#7 | 1 | normal | - | - | RUNNING→RUNNING |
| 18 | 8 | F1@8 | 4:beq#10 | 0:lw#9 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 19 | 8 | F1@8 | 4:beq#10 | - | 0:lw#9 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 20 | c | F1@c | F1@8 | 4:beq#10 | - | 0:lw#9 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 21 | 0 | 0:lw#12 | - | - | 4:beq#10 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 22 | 4 | 4:beq#13 | 0:lw#12 | - | - | 4:beq#10 | 1 | normal | - | - | RUNNING→RUNNING |
| 23 | 8 | F1@8 | 4:beq#13 | 0:lw#12 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 24 | 8 | F1@8 | 4:beq#13 | - | 0:lw#12 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 25 | c | F1@c | F1@8 | 4:beq#13 | - | 0:lw#12 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 26 | 0 | 0:lw#15 | - | - | 4:beq#13 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 27 | 4 | 4:beq#16 | 0:lw#15 | - | - | 4:beq#13 | 1 | normal | - | - | RUNNING→RUNNING |
| 28 | 8 | F1@8 | 4:beq#16 | 0:lw#15 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 29 | 8 | F1@8 | 4:beq#16 | - | 0:lw#15 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 30 | c | F1@c | F1@8 | 4:beq#16 | - | 0:lw#15 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |

Resultado: `{"state": "RUNNING", "fault": null, "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_beq_not</summary>

```asm
0000: 00700f93    addi x31,x0,7
0004: 01f02023    sw x31,0(x0)
0008: 00002083    lw x1,0(x0)
000c: fe008ee3    beq x1,x0,-4
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:beq#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:beq#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 1 | load_use | x31=00000007, M[0:4]=00000007 | - | RUNNING→RUNNING |
| 6 | 10 | F1@10 | c:beq#3 | - | 8:lw#2 | 4:sw#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 14 | F1@14 | F1@10 | c:beq#3 | - | 8:lw#2 | 1 | id_fault | x1=00000007 | F1@10 | RUNNING→FAULT_DRAIN_AUTO |
| 8 | 14 | F1@14 | - | - | c:beq#3 | - | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 9 | 14 | F1@14 | - | - | - | c:beq#3 | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT |
| 10 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [1, 16], "registers": {"x1": "00000007", "x31": "00000007"}, "memory": {"0": 7, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_bne_taken</summary>

```asm
0000: 00700f93    addi x31,x0,7
0004: 01f02023    sw x31,0(x0)
0008: 00002083    lw x1,0(x0)
000c: fe009ee3    bne x1,x0,-4
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:bne#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:bne#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 1 | load_use | x31=00000007, M[0:4]=00000007 | - | RUNNING→RUNNING |
| 6 | 10 | F1@10 | c:bne#3 | - | 8:lw#2 | 4:sw#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 14 | F1@14 | F1@10 | c:bne#3 | - | 8:lw#2 | 1 | redirect | x1=00000007 | - | RUNNING→RUNNING |
| 8 | 8 | 8:lw#5 | - | - | c:bne#3 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 9 | c | c:bne#6 | 8:lw#5 | - | - | c:bne#3 | 1 | normal | - | - | RUNNING→RUNNING |
| 10 | 10 | F1@10 | c:bne#6 | 8:lw#5 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 11 | 10 | F1@10 | c:bne#6 | - | 8:lw#5 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 12 | 14 | F1@14 | F1@10 | c:bne#6 | - | 8:lw#5 | 1 | redirect | x1=00000007 | - | RUNNING→RUNNING |
| 13 | 8 | 8:lw#8 | - | - | c:bne#6 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 14 | c | c:bne#9 | 8:lw#8 | - | - | c:bne#6 | 1 | normal | - | - | RUNNING→RUNNING |
| 15 | 10 | F1@10 | c:bne#9 | 8:lw#8 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 16 | 10 | F1@10 | c:bne#9 | - | 8:lw#8 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 17 | 14 | F1@14 | F1@10 | c:bne#9 | - | 8:lw#8 | 1 | redirect | x1=00000007 | - | RUNNING→RUNNING |
| 18 | 8 | 8:lw#11 | - | - | c:bne#9 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 19 | c | c:bne#12 | 8:lw#11 | - | - | c:bne#9 | 1 | normal | - | - | RUNNING→RUNNING |
| 20 | 10 | F1@10 | c:bne#12 | 8:lw#11 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 21 | 10 | F1@10 | c:bne#12 | - | 8:lw#11 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 22 | 14 | F1@14 | F1@10 | c:bne#12 | - | 8:lw#11 | 1 | redirect | x1=00000007 | - | RUNNING→RUNNING |
| 23 | 8 | 8:lw#14 | - | - | c:bne#12 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 24 | c | c:bne#15 | 8:lw#14 | - | - | c:bne#12 | 1 | normal | - | - | RUNNING→RUNNING |
| 25 | 10 | F1@10 | c:bne#15 | 8:lw#14 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 26 | 10 | F1@10 | c:bne#15 | - | 8:lw#14 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 27 | 14 | F1@14 | F1@10 | c:bne#15 | - | 8:lw#14 | 1 | redirect | x1=00000007 | - | RUNNING→RUNNING |
| 28 | 8 | 8:lw#17 | - | - | c:bne#15 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 29 | c | c:bne#18 | 8:lw#17 | - | - | c:bne#15 | 1 | normal | - | - | RUNNING→RUNNING |
| 30 | 10 | F1@10 | c:bne#18 | 8:lw#17 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |

Resultado: `{"state": "RUNNING", "fault": null, "registers": {"x1": "00000007", "x31": "00000007"}, "memory": {"0": 7, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_bne_not</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: fe009ee3    bne x1,x0,-4
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:bne#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:bne#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | F1@8 | 4:bne#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | F1@8 | 4:bne#1 | - | 0:lw#0 | 1 | id_fault | x1=00000000 | F1@8 | RUNNING→FAULT_DRAIN_AUTO |
| 6 | c | F1@c | - | - | 4:bne#1 | - | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 7 | c | F1@c | - | - | - | 4:bne#1 | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT |
| 8 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [1, 8], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_jalr</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 00108167    jalr x2,1(x1)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:jalr#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:jalr#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | F1@8 | 4:jalr#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | F1@8 | 4:jalr#1 | - | 0:lw#0 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 6 | 0 | 0:lw#3 | - | - | 4:jalr#1 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 4 | 4:jalr#4 | 0:lw#3 | - | - | 4:jalr#1 | 1 | normal | x2=00000008 | - | RUNNING→RUNNING |
| 8 | 8 | F1@8 | 4:jalr#4 | 0:lw#3 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 9 | 8 | F1@8 | 4:jalr#4 | - | 0:lw#3 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 10 | c | F1@c | F1@8 | 4:jalr#4 | - | 0:lw#3 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 11 | 0 | 0:lw#6 | - | - | 4:jalr#4 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 12 | 4 | 4:jalr#7 | 0:lw#6 | - | - | 4:jalr#4 | 1 | normal | x2=00000008 | - | RUNNING→RUNNING |
| 13 | 8 | F1@8 | 4:jalr#7 | 0:lw#6 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 14 | 8 | F1@8 | 4:jalr#7 | - | 0:lw#6 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 15 | c | F1@c | F1@8 | 4:jalr#7 | - | 0:lw#6 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 16 | 0 | 0:lw#9 | - | - | 4:jalr#7 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 17 | 4 | 4:jalr#10 | 0:lw#9 | - | - | 4:jalr#7 | 1 | normal | x2=00000008 | - | RUNNING→RUNNING |
| 18 | 8 | F1@8 | 4:jalr#10 | 0:lw#9 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 19 | 8 | F1@8 | 4:jalr#10 | - | 0:lw#9 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 20 | c | F1@c | F1@8 | 4:jalr#10 | - | 0:lw#9 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 21 | 0 | 0:lw#12 | - | - | 4:jalr#10 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 22 | 4 | 4:jalr#13 | 0:lw#12 | - | - | 4:jalr#10 | 1 | normal | x2=00000008 | - | RUNNING→RUNNING |
| 23 | 8 | F1@8 | 4:jalr#13 | 0:lw#12 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 24 | 8 | F1@8 | 4:jalr#13 | - | 0:lw#12 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 25 | c | F1@c | F1@8 | 4:jalr#13 | - | 0:lw#12 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |
| 26 | 0 | 0:lw#15 | - | - | 4:jalr#13 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 27 | 4 | 4:jalr#16 | 0:lw#15 | - | - | 4:jalr#13 | 1 | normal | x2=00000008 | - | RUNNING→RUNNING |
| 28 | 8 | F1@8 | 4:jalr#16 | 0:lw#15 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 29 | 8 | F1@8 | 4:jalr#16 | - | 0:lw#15 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 30 | c | F1@c | F1@8 | 4:jalr#16 | - | 0:lw#15 | 1 | redirect | x1=00000000 | - | RUNNING→RUNNING |

Resultado: `{"state": "RUNNING", "fault": null, "registers": {"x2": "00000008"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_jalr_bad</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 00308167    jalr x2,3(x1)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:jalr#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:jalr#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | F1@8 | 4:jalr#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | F1@8 | 4:jalr#1 | - | 0:lw#0 | 1 | ex_fault | x1=00000000 | F0@4 | RUNNING→FAULT |
| 6 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [0, 4], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_load</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 0000a103    lw x2,0(x1)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:lw#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:lw#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | F1@8 | 4:lw#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | F1@8 | 4:lw#1 | - | 0:lw#0 | 1 | id_fault | x1=00000000 | F1@8 | RUNNING→FAULT_DRAIN_AUTO |
| 6 | c | F1@c | - | - | 4:lw#1 | - | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 7 | c | F1@c | - | - | - | 4:lw#1 | 1 | drain_advance | x2=00000000 | - | FAULT_DRAIN_AUTO→FAULT |
| 8 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [1, 8], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_load_bad</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 0020a103    lw x2,2(x1)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:lw#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:lw#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | F1@8 | 4:lw#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | F1@8 | 4:lw#1 | - | 0:lw#0 | 1 | ex_fault | x1=00000000 | F4@4 | RUNNING→FAULT |
| 6 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [4, 4], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_store_data</summary>

```asm
0000: 09500f93    addi x31,x0,149
0004: 01f02023    sw x31,0(x0)
0008: 00002083    lw x1,0(x0)
000c: 00102223    sw x1,4(x0)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:sw#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:sw#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 1 | load_use | x31=00000095, M[0:4]=00000095 | - | RUNNING→RUNNING |
| 6 | 10 | F1@10 | c:sw#3 | - | 8:lw#2 | 4:sw#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 14 | F1@14 | F1@10 | c:sw#3 | - | 8:lw#2 | 1 | id_fault | x1=00000095 | F1@10 | RUNNING→FAULT_DRAIN_AUTO |
| 8 | 14 | F1@14 | - | - | c:sw#3 | - | 1 | drain_advance | M[4:4]=00000095 | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 9 | 14 | F1@14 | - | - | - | c:sw#3 | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT |
| 10 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [1, 16], "registers": {"x1": "00000095", "x31": "00000095"}, "memory": {"0": 149, "1": 0, "2": 0, "3": 0, "4": 149, "5": 0, "6": 0, "7": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_store_base</summary>

```asm
0000: 00400f93    addi x31,x0,4
0004: 01f02023    sw x31,0(x0)
0008: 00002083    lw x1,0(x0)
000c: 0000a023    sw x0,0(x1)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:sw#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:sw#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 1 | load_use | x31=00000004, M[0:4]=00000004 | - | RUNNING→RUNNING |
| 6 | 10 | F1@10 | c:sw#3 | - | 8:lw#2 | 4:sw#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 14 | F1@14 | F1@10 | c:sw#3 | - | 8:lw#2 | 1 | id_fault | x1=00000004 | F1@10 | RUNNING→FAULT_DRAIN_AUTO |
| 8 | 14 | F1@14 | - | - | c:sw#3 | - | 1 | drain_advance | M[4:4]=00000000 | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 9 | 14 | F1@14 | - | - | - | c:sw#3 | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT |
| 10 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [1, 16], "registers": {"x1": "00000004", "x31": "00000004"}, "memory": {"0": 4, "1": 0, "2": 0, "3": 0, "4": 0, "5": 0, "6": 0, "7": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_store_bad</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 00102123    sw x1,2(x0)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:sw#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | F1@8 | 4:sw#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | F1@8 | 4:sw#1 | - | 0:lw#0 | 1 | ex_fault | x1=00000000 | F6@4 | RUNNING→FAULT |
| 6 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [6, 4], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_store_bad_STEP</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 00102123    sw x1,2(x0)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→STEPPING |
| 2 | 4 | 4:sw#1 | 0:lw#0 | - | - | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 3 | 4 | 4:sw#1 | 0:lw#0 | - | - | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 4 | 4 | 4:sw#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | STEPPING→STEPPING |
| 5 | 8 | F1@8 | 4:sw#1 | 0:lw#0 | - | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 6 | 8 | F1@8 | 4:sw#1 | 0:lw#0 | - | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 7 | 8 | F1@8 | 4:sw#1 | 0:lw#0 | - | - | 1 | load_use | - | - | STEPPING→STEPPING |
| 8 | 8 | F1@8 | 4:sw#1 | - | 0:lw#0 | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 9 | 8 | F1@8 | 4:sw#1 | - | 0:lw#0 | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 10 | 8 | F1@8 | 4:sw#1 | - | 0:lw#0 | - | 1 | normal | - | - | STEPPING→STEPPING |
| 11 | c | F1@c | F1@8 | 4:sw#1 | - | 0:lw#0 | 0 | HOLD | - | - | STEPPING→STEPPING |
| 12 | c | F1@c | F1@8 | 4:sw#1 | - | 0:lw#0 | 0 | HOLD | - | - | STEPPING→STEPPING |
| 13 | c | F1@c | F1@8 | 4:sw#1 | - | 0:lw#0 | 1 | ex_fault | x1=00000000 | F6@4 | STEPPING→FAULT |
| 14 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [6, 4]}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_illegal</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: ffffffff    .word 0xffffffff
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:illegal#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:illegal#1 | 0:lw#0 | - | - | 1 | id_fault | - | F2@4 | RUNNING→FAULT_DRAIN_AUTO |
| 4 | 8 | F1@8 | - | - | 0:lw#0 | - | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 5 | 8 | F1@8 | - | - | - | 0:lw#0 | 1 | drain_advance | x1=00000000 | - | FAULT_DRAIN_AUTO→FAULT |
| 6 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [2, 4], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_alu_illegal</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 00908113    addi x2,x1,9
0008: 00000000    .word 0x00000000
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:illegal#2 | 4:addi#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | 8:illegal#2 | 4:addi#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | F1@c | 8:illegal#2 | 4:addi#1 | - | 0:lw#0 | 1 | id_fault | x1=00000000 | F2@8 | RUNNING→FAULT_DRAIN_AUTO |
| 6 | c | F1@c | - | - | 4:addi#1 | - | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 7 | c | F1@c | - | - | - | 4:addi#1 | 1 | drain_advance | x2=00000009 | - | FAULT_DRAIN_AUTO→FAULT |
| 8 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [2, 8], "registers": {"x2": "00000009"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_halt</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:lw#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | F1@c | F1@8 | 4:halt#1 | 0:lw#0 | - | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 5 | c | F1@c | - | - | - | 0:lw#0 | 1 | drain_advance | x1=00000000 | - | HALT_DRAIN_AUTO→FINISHED |
| 6 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>lw_fault_over_halt</summary>

```asm
0000: 00202083    lw x1,2(x0)
0004: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:lw#0 | - | - | 1 | ex_fault | - | F4@0 | RUNNING→FAULT |
| 4 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [4, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>halt_first</summary>

```asm
0000: 0000000b    halt
0004: 00102023    sw x1,0(x0)
0008: 00000000    .word 0x00000000
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:halt#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:halt#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:illegal#2 | 4:sw#1 | 0:halt#0 | - | - | 1 | halt | - | HALT | RUNNING→FINISHED |
| 4 | 8 | 8:illegal#2 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>simultaneous_WB_MEM_fault</summary>

```asm
0000: 05500093    addi x1,x0,85
0004: 00102023    sw x1,0(x0)
0008: 00202103    lw x2,2(x0)
000c: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 1 | ex_fault | x1=00000055, M[0:4]=00000055 | F4@8 | RUNNING→FAULT_DRAIN_AUTO |
| 6 | 10 | F1@10 | - | - | - | 4:sw#1 | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT |
| 7 | 10 | F1@10 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [4, 8], "registers": {"x1": "00000055"}, "memory": {"0": 85, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>simultaneous_WB_MEM_fault_STEP</summary>

```asm
0000: 05500093    addi x1,x0,85
0004: 00102023    sw x1,0(x0)
0008: 00202103    lw x2,2(x0)
000c: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→STEPPING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 3 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 4 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | STEPPING→STEPPING |
| 5 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 6 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 7 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | STEPPING→STEPPING |
| 8 | c | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 9 | c | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 0 | HOLD | - | - | STEPPING→STEPPING |
| 10 | c | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | STEPPING→STEPPING |
| 11 | 10 | F1@10 | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 0 | HOLD | - | - | STEPPING→STEPPING |
| 12 | 10 | F1@10 | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 0 | HOLD | - | - | STEPPING→STEPPING |
| 13 | 10 | F1@10 | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 1 | ex_fault | x1=00000055, M[0:4]=00000055 | F4@8 | STEPPING→FAULT_DRAIN_STEP |
| 14 | 10 | F1@10 | - | - | - | 4:sw#1 | 0 | HOLD | - | - | FAULT_DRAIN_STEP→FAULT_DRAIN_STEP |
| 15 | 10 | F1@10 | - | - | - | 4:sw#1 | 0 | HOLD | - | - | FAULT_DRAIN_STEP→FAULT_DRAIN_STEP |
| 16 | 10 | F1@10 | - | - | - | 4:sw#1 | 1 | drain_advance | - | - | FAULT_DRAIN_STEP→FAULT |
| 17 | 10 | F1@10 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [4, 8]}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>simultaneous_WB_MEM_halt</summary>

```asm
0000: 05500093    addi x1,x0,85
0004: 00102023    sw x1,0(x0)
0008: 0000000b    halt
000c: 00000000    .word 0x00000000
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:halt#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:illegal#3 | 8:halt#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:illegal#3 | 8:halt#2 | 4:sw#1 | 0:addi#0 | 1 | halt | x1=00000055, M[0:4]=00000055 | HALT | RUNNING→HALT_DRAIN_AUTO |
| 6 | 10 | F1@10 | - | - | - | 4:sw#1 | 1 | drain_advance | - | - | HALT_DRAIN_AUTO→FINISHED |
| 7 | 10 | F1@10 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000055"}, "memory": {"0": 85, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>forward_newest</summary>

```asm
0000: 01100093    addi x1,x0,17
0004: 01d00093    addi x1,x0,29
0008: 00108133    add x2,x1,x1
000c: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:add#2 | 4:addi#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:halt#3 | 8:add#2 | 4:addi#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:halt#3 | 8:add#2 | 4:addi#1 | 0:addi#0 | 1 | normal | x1=00000011 | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | F1@10 | c:halt#3 | 8:add#2 | 4:addi#1 | 1 | halt | x1=0000001d | HALT | RUNNING→HALT_DRAIN_AUTO |
| 7 | 14 | F1@14 | - | - | - | 8:add#2 | 1 | drain_advance | x2=0000003a | - | HALT_DRAIN_AUTO→FINISHED |
| 8 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "0000001d", "x2": "0000003a"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>load_masks_old</summary>

```asm
0000: 01d00f93    addi x31,x0,29
0004: 01f02023    sw x31,0(x0)
0008: 01100093    addi x1,x0,17
000c: 00002083    lw x1,0(x0)
0010: 00108133    add x2,x1,x1
0014: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:addi#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:lw#3 | 8:addi#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:add#4 | c:lw#3 | 8:addi#2 | 4:sw#1 | 0:addi#0 | 1 | normal | x31=0000001d, M[0:4]=0000001d | - | RUNNING→RUNNING |
| 6 | 14 | 14:halt#5 | 10:add#4 | c:lw#3 | 8:addi#2 | 4:sw#1 | 1 | load_use | - | - | RUNNING→RUNNING |
| 7 | 14 | 14:halt#5 | 10:add#4 | - | c:lw#3 | 8:addi#2 | 1 | normal | x1=00000011 | - | RUNNING→RUNNING |
| 8 | 18 | F1@18 | 14:halt#5 | 10:add#4 | - | c:lw#3 | 1 | normal | x1=0000001d | - | RUNNING→RUNNING |
| 9 | 1c | F1@1c | F1@18 | 14:halt#5 | 10:add#4 | - | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 10 | 1c | F1@1c | - | - | - | 10:add#4 | 1 | drain_advance | x2=0000003a | - | HALT_DRAIN_AUTO→FINISHED |
| 11 | 1c | F1@1c | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "0000001d", "x2": "0000003a", "x31": "0000001d"}, "memory": {"0": 29, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>WB_ID</summary>

```asm
0000: 01100093    addi x1,x0,17
0004: 00300193    addi x3,x0,3
0008: 00400213    addi x4,x0,4
000c: 00108133    add x2,x1,x1
0010: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:addi#2 | 4:addi#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:add#3 | 8:addi#2 | 4:addi#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:halt#4 | c:add#3 | 8:addi#2 | 4:addi#1 | 0:addi#0 | 1 | normal | x1=00000011 | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | 10:halt#4 | c:add#3 | 8:addi#2 | 4:addi#1 | 1 | normal | x3=00000003 | - | RUNNING→RUNNING |
| 7 | 18 | F1@18 | F1@14 | 10:halt#4 | c:add#3 | 8:addi#2 | 1 | halt | x4=00000004 | HALT | RUNNING→HALT_DRAIN_AUTO |
| 8 | 18 | F1@18 | - | - | - | c:add#3 | 1 | drain_advance | x2=00000022 | - | HALT_DRAIN_AUTO→FINISHED |
| 9 | 18 | F1@18 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000011", "x2": "00000022", "x3": "00000003", "x4": "00000004"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>dual_sources</summary>

```asm
0000: 01100093    addi x1,x0,17
0004: 01d00113    addi x2,x0,29
0008: 401101b3    sub x3,x2,x1
000c: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:sub#2 | 4:addi#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:halt#3 | 8:sub#2 | 4:addi#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:halt#3 | 8:sub#2 | 4:addi#1 | 0:addi#0 | 1 | normal | x1=00000011 | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | F1@10 | c:halt#3 | 8:sub#2 | 4:addi#1 | 1 | halt | x2=0000001d | HALT | RUNNING→HALT_DRAIN_AUTO |
| 7 | 14 | F1@14 | - | - | - | 8:sub#2 | 1 | drain_advance | x3=0000000c | - | HALT_DRAIN_AUTO→FINISHED |
| 8 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000011", "x2": "0000001d", "x3": "0000000c"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>chain</summary>

```asm
0000: 01100093    addi x1,x0,17
0004: 00c08093    addi x1,x1,12
0008: 00108133    add x2,x1,x1
000c: 001101b3    add x3,x2,x1
0010: 00302023    sw x3,0(x0)
0014: 00002203    lw x4,0(x0)
0018: 003202b3    add x5,x4,x3
001c: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:add#2 | 4:addi#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:add#3 | 8:add#2 | 4:addi#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:sw#4 | c:add#3 | 8:add#2 | 4:addi#1 | 0:addi#0 | 1 | normal | x1=00000011 | - | RUNNING→RUNNING |
| 6 | 14 | 14:lw#5 | 10:sw#4 | c:add#3 | 8:add#2 | 4:addi#1 | 1 | normal | x1=0000001d | - | RUNNING→RUNNING |
| 7 | 18 | 18:add#6 | 14:lw#5 | 10:sw#4 | c:add#3 | 8:add#2 | 1 | normal | x2=0000003a | - | RUNNING→RUNNING |
| 8 | 1c | 1c:halt#7 | 18:add#6 | 14:lw#5 | 10:sw#4 | c:add#3 | 1 | load_use | x3=00000057, M[0:4]=00000057 | - | RUNNING→RUNNING |
| 9 | 1c | 1c:halt#7 | 18:add#6 | - | 14:lw#5 | 10:sw#4 | 1 | normal | - | - | RUNNING→RUNNING |
| 10 | 20 | F1@20 | 1c:halt#7 | 18:add#6 | - | 14:lw#5 | 1 | normal | x4=00000057 | - | RUNNING→RUNNING |
| 11 | 24 | F1@24 | F1@20 | 1c:halt#7 | 18:add#6 | - | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 12 | 24 | F1@24 | - | - | - | 18:add#6 | 1 | drain_advance | x5=000000ae | - | HALT_DRAIN_AUTO→FINISHED |
| 13 | 24 | F1@24 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "0000001d", "x2": "0000003a", "x3": "00000057", "x4": "00000057", "x5": "000000ae"}, "memory": {"0": 87, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>redirect_wrongpath</summary>

```asm
0000: 00c000ef    jal x1,12
0004: 00102023    sw x1,0(x0)
0008: 00000000    .word 0x00000000
000c: 00108133    add x2,x1,x1
0010: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:jal#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:jal#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:illegal#2 | 4:sw#1 | 0:jal#0 | - | - | 1 | redirect | - | - | RUNNING→RUNNING |
| 4 | c | c:add#2 | - | - | 0:jal#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:halt#3 | c:add#2 | - | - | 0:jal#0 | 1 | normal | x1=00000004 | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | 10:halt#3 | c:add#2 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 18 | F1@18 | F1@14 | 10:halt#3 | c:add#2 | - | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 8 | 18 | F1@18 | - | - | - | c:add#2 | 1 | drain_advance | x2=00000008 | - | HALT_DRAIN_AUTO→FINISHED |
| 9 | 18 | F1@18 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000004", "x2": "00000008"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>redirect_halt</summary>

```asm
0000: 00c000ef    jal x1,12
0004: 0000000b    halt
0008: 00102023    sw x1,0(x0)
000c: 0040016f    jal x2,4
0010: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:jal#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:jal#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:sw#2 | 4:halt#1 | 0:jal#0 | - | - | 1 | redirect | - | - | RUNNING→RUNNING |
| 4 | c | c:jal#2 | - | - | 0:jal#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:halt#3 | c:jal#2 | - | - | 0:jal#0 | 1 | normal | x1=00000004 | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | 10:halt#3 | c:jal#2 | - | - | 1 | redirect | - | - | RUNNING→RUNNING |
| 7 | 10 | 10:halt#4 | - | - | c:jal#2 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 8 | 14 | F1@14 | 10:halt#4 | - | - | c:jal#2 | 1 | normal | x2=00000010 | - | RUNNING→RUNNING |
| 9 | 18 | F1@18 | F1@14 | 10:halt#4 | - | - | 1 | halt | - | HALT | RUNNING→FINISHED |
| 10 | 18 | F1@18 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000004", "x2": "00000010"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>redirect_older_commits</summary>

```asm
0000: 03700093    addi x1,x0,55
0004: 00102023    sw x1,0(x0)
0008: 0080016f    jal x2,8
000c: 00000000    .word 0x00000000
0010: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:jal#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:illegal#3 | 8:jal#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:halt#4 | c:illegal#3 | 8:jal#2 | 4:sw#1 | 0:addi#0 | 1 | redirect | x1=00000037, M[0:4]=00000037 | - | RUNNING→RUNNING |
| 6 | 10 | 10:halt#4 | - | - | 8:jal#2 | 4:sw#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 14 | F1@14 | 10:halt#4 | - | - | 8:jal#2 | 1 | normal | x2=0000000c | - | RUNNING→RUNNING |
| 8 | 18 | F1@18 | F1@14 | 10:halt#4 | - | - | 1 | halt | - | HALT | RUNNING→FINISHED |
| 9 | 18 | F1@18 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000037", "x2": "0000000c"}, "memory": {"0": 55, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>target_outside</summary>

```asm
0000: 040000ef    jal x1,64
0004: 00102023    sw x1,0(x0)
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:jal#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:jal#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:sw#1 | 0:jal#0 | - | - | 1 | redirect | - | - | RUNNING→RUNNING |
| 4 | 40 | F1@40 | - | - | 0:jal#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 44 | F1@44 | F1@40 | - | - | 0:jal#0 | 1 | id_fault | x1=00000004 | F1@40 | RUNNING→FAULT |
| 6 | 44 | F1@44 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [1, 64], "registers": {"x1": "00000004"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>target_bad</summary>

```asm
0000: 002000ef    jal x1,2
0004: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:jal#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:jal#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:jal#0 | - | - | 1 | ex_fault | - | F0@0 | RUNNING→FAULT |
| 4 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [0, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>not_taken_badtarget</summary>

```asm
0000: 00001163    bne x0,x0,2
0004: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:bne#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:bne#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:bne#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | F1@c | F1@8 | 4:halt#1 | 0:bne#0 | - | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 5 | c | F1@c | - | - | - | 0:bne#0 | 1 | drain_advance | - | - | HALT_DRAIN_AUTO→FINISHED |
| 6 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>beq_not_taken</summary>

```asm
0000: 00100093    addi x1,x0,1
0004: 00008463    beq x1,x0,8
0008: 02a00113    addi x2,x0,42
000c: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:beq#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:addi#2 | 4:beq#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:halt#3 | 8:addi#2 | 4:beq#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:halt#3 | 8:addi#2 | 4:beq#1 | 0:addi#0 | 1 | normal | x1=00000001 | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | F1@10 | c:halt#3 | 8:addi#2 | 4:beq#1 | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 7 | 14 | F1@14 | - | - | - | 8:addi#2 | 1 | drain_advance | x2=0000002a | - | HALT_DRAIN_AUTO→FINISHED |
| 8 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000001", "x2": "0000002a"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>bne_taken</summary>

```asm
0000: 00100093    addi x1,x0,1
0004: 00009463    bne x1,x0,8
0008: 00000000    .word 0x00000000
000c: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:bne#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:illegal#2 | 4:bne#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:halt#3 | 8:illegal#2 | 4:bne#1 | 0:addi#0 | - | 1 | redirect | - | - | RUNNING→RUNNING |
| 5 | c | c:halt#3 | - | - | 4:bne#1 | 0:addi#0 | 1 | normal | x1=00000001 | - | RUNNING→RUNNING |
| 6 | 10 | F1@10 | c:halt#3 | - | - | 4:bne#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 14 | F1@14 | F1@10 | c:halt#3 | - | - | 1 | halt | - | HALT | RUNNING→FINISHED |
| 8 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000001"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>EA_wrap</summary>

```asm
0000: fff00093    addi x1,x0,-1
0004: 07b00113    addi x2,x0,123
0008: 0020a0a3    sw x2,1(x1)
000c: 00002183    lw x3,0(x0)
0010: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:sw#2 | 4:addi#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:lw#3 | 8:sw#2 | 4:addi#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:halt#4 | c:lw#3 | 8:sw#2 | 4:addi#1 | 0:addi#0 | 1 | normal | x1=ffffffff | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | 10:halt#4 | c:lw#3 | 8:sw#2 | 4:addi#1 | 1 | normal | x2=0000007b, M[0:4]=0000007b | - | RUNNING→RUNNING |
| 7 | 18 | F1@18 | F1@14 | 10:halt#4 | c:lw#3 | 8:sw#2 | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 8 | 18 | F1@18 | - | - | - | c:lw#3 | 1 | drain_advance | x3=0000007b | - | HALT_DRAIN_AUTO→FINISHED |
| 9 | 18 | F1@18 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "ffffffff", "x2": "0000007b", "x3": "0000007b"}, "memory": {"0": 123, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>EA_underflow</summary>

```asm
0000: ffc02083    lw x1,-4(x0)
0004: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:lw#0 | - | - | 1 | ex_fault | - | F5@0 | RUNNING→FAULT |
| 4 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [5, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>store_range</summary>

```asm
0000: 000010b7    lui x1,0x1
0004: 0000a023    sw x0,0(x1)
0008: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lui#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:lui#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:halt#2 | 4:sw#1 | 0:lui#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | F1@c | 8:halt#2 | 4:sw#1 | 0:lui#0 | - | 1 | ex_fault | - | F7@4 | RUNNING→FAULT_DRAIN_AUTO |
| 5 | c | F1@c | - | - | - | 0:lui#0 | 1 | drain_advance | x1=00001000 | - | FAULT_DRAIN_AUTO→FAULT |
| 6 | c | F1@c | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [7, 4], "registers": {"x1": "00001000"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>first_illegal</summary>

```asm
0000: 00000000    .word 0x00000000
0004: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:illegal#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:illegal#0 | - | - | - | 1 | id_fault | - | F2@0 | RUNNING→FAULT |
| 3 | 4 | 4:halt#1 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [2, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>load_x0_fault</summary>

```asm
0000: 00202003    lw x0,2(x0)
0004: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:lw#0 | - | - | 1 | ex_fault | - | F4@0 | RUNNING→FAULT |
| 4 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [4, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>x0_no_hazard</summary>

```asm
0000: 00002003    lw x0,0(x0)
0004: 00700113    addi x2,x0,7
0008: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:halt#2 | 4:addi#1 | 0:lw#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | F1@c | 8:halt#2 | 4:addi#1 | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | F1@c | 8:halt#2 | 4:addi#1 | 0:lw#0 | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 6 | 10 | F1@10 | - | - | - | 4:addi#1 | 1 | drain_advance | x2=00000007 | - | HALT_DRAIN_AUTO→FINISHED |
| 7 | 10 | F1@10 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x2": "00000007"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>little_endian</summary>

```asm
0000: 80ff70b7    lui x1,0x80ff7
0004: 60108093    addi x1,x1,1537
0008: 00102023    sw x1,0(x0)
000c: 00300103    lb x2,3(x0)
0010: 00304183    lbu x3,3(x0)
0014: 00201203    lh x4,2(x0)
0018: 00205283    lhu x5,2(x0)
001c: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lui#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:lui#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:sw#2 | 4:addi#1 | 0:lui#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:lb#3 | 8:sw#2 | 4:addi#1 | 0:lui#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:lbu#4 | c:lb#3 | 8:sw#2 | 4:addi#1 | 0:lui#0 | 1 | normal | x1=80ff7000 | - | RUNNING→RUNNING |
| 6 | 14 | 14:lh#5 | 10:lbu#4 | c:lb#3 | 8:sw#2 | 4:addi#1 | 1 | normal | x1=80ff7601, M[0:4]=80ff7601 | - | RUNNING→RUNNING |
| 7 | 18 | 18:lhu#6 | 14:lh#5 | 10:lbu#4 | c:lb#3 | 8:sw#2 | 1 | normal | - | - | RUNNING→RUNNING |
| 8 | 1c | 1c:halt#7 | 18:lhu#6 | 14:lh#5 | 10:lbu#4 | c:lb#3 | 1 | normal | x2=ffffff80 | - | RUNNING→RUNNING |
| 9 | 20 | F1@20 | 1c:halt#7 | 18:lhu#6 | 14:lh#5 | 10:lbu#4 | 1 | normal | x3=00000080 | - | RUNNING→RUNNING |
| 10 | 24 | F1@24 | F1@20 | 1c:halt#7 | 18:lhu#6 | 14:lh#5 | 1 | halt | x4=ffff80ff | HALT | RUNNING→HALT_DRAIN_AUTO |
| 11 | 24 | F1@24 | - | - | - | 18:lhu#6 | 1 | drain_advance | x5=000080ff | - | HALT_DRAIN_AUTO→FINISHED |
| 12 | 24 | F1@24 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "80ff7601", "x2": "ffffff80", "x3": "00000080", "x4": "ffff80ff", "x5": "000080ff"}, "memory": {"0": 1, "1": 118, "2": 255, "3": 128}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>partial_zero</summary>

```asm
0000: fff00093    addi x1,x0,-1
0004: 001000a3    sb x1,1(x0)
0008: 00002103    lw x2,0(x0)
000c: 00101123    sh x1,2(x0)
0010: 00002183    lw x3,0(x0)
0014: 0000000b    halt
```

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sb#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lw#2 | 4:sb#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:sh#3 | 8:lw#2 | 4:sb#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:lw#4 | c:sh#3 | 8:lw#2 | 4:sb#1 | 0:addi#0 | 1 | normal | x1=ffffffff, M[1:1]=ffffffff | - | RUNNING→RUNNING |
| 6 | 14 | 14:halt#5 | 10:lw#4 | c:sh#3 | 8:lw#2 | 4:sb#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 18 | F1@18 | 14:halt#5 | 10:lw#4 | c:sh#3 | 8:lw#2 | 1 | normal | x2=0000ff00, M[2:2]=ffffffff | - | RUNNING→RUNNING |
| 8 | 1c | F1@1c | F1@18 | 14:halt#5 | 10:lw#4 | c:sh#3 | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 9 | 1c | F1@1c | - | - | - | 10:lw#4 | 1 | drain_advance | x3=ffffff00 | - | HALT_DRAIN_AUTO→FINISHED |
| 10 | 1c | F1@1c | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "ffffffff", "x2": "0000ff00", "x3": "ffffff00"}, "memory": {"1": 255, "2": 255, "3": 255}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>load_store_both</summary>

```asm
0000: 00400f93    addi x31,x0,4
0004: 01f02023    sw x31,0(x0)
0008: 00002083    lw x1,0(x0)
000c: 0010a023    sw x1,0(x1)
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:sw#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:sw#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 1 | load_use | x31=00000004, M[0:4]=00000004 | - | RUNNING→RUNNING |
| 6 | 10 | F1@10 | c:sw#3 | - | 8:lw#2 | 4:sw#1 | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 14 | F1@14 | F1@10 | c:sw#3 | - | 8:lw#2 | 1 | id_fault | x1=00000004 | F1@10 | RUNNING→FAULT_DRAIN_AUTO |
| 8 | 14 | F1@14 | - | - | c:sw#3 | - | 1 | drain_advance | M[4:4]=00000004 | - | FAULT_DRAIN_AUTO→FAULT_DRAIN_AUTO |
| 9 | 14 | F1@14 | - | - | - | c:sw#3 | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT |
| 10 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [1, 16], "registers": {"x1": "00000004", "x31": "00000004"}, "memory": {"0": 4, "1": 0, "2": 0, "3": 0, "4": 4, "5": 0, "6": 0, "7": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>forward_lui</summary>

```asm
0000: 123450b7    lui x1,0x12345
0004: 67808113    addi x2,x1,1656
0008: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lui#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:lui#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:halt#2 | 4:addi#1 | 0:lui#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | F1@c | 8:halt#2 | 4:addi#1 | 0:lui#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | F1@c | 8:halt#2 | 4:addi#1 | 0:lui#0 | 1 | halt | x1=12345000 | HALT | RUNNING→HALT_DRAIN_AUTO |
| 6 | 10 | F1@10 | - | - | - | 4:addi#1 | 1 | drain_advance | x2=12345678 | - | HALT_DRAIN_AUTO→FINISHED |
| 7 | 10 | F1@10 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "12345000", "x2": "12345678"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>jalr_rd_rs1</summary>

```asm
0000: 00d00093    addi x1,x0,13
0004: 000080e7    jalr x1,0(x1)
0008: 00000000    .word 0x00000000
000c: 00108133    add x2,x1,x1
0010: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:jalr#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:illegal#2 | 4:jalr#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:add#3 | 8:illegal#2 | 4:jalr#1 | 0:addi#0 | - | 1 | redirect | - | - | RUNNING→RUNNING |
| 5 | c | c:add#3 | - | - | 4:jalr#1 | 0:addi#0 | 1 | normal | x1=0000000d | - | RUNNING→RUNNING |
| 6 | 10 | 10:halt#4 | c:add#3 | - | - | 4:jalr#1 | 1 | normal | x1=00000008 | - | RUNNING→RUNNING |
| 7 | 14 | F1@14 | 10:halt#4 | c:add#3 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 8 | 18 | F1@18 | F1@14 | 10:halt#4 | c:add#3 | - | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 9 | 18 | F1@18 | - | - | - | c:add#3 | 1 | drain_advance | x2=00000010 | - | HALT_DRAIN_AUTO→FINISHED |
| 10 | 18 | F1@18 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "00000008", "x2": "00000010"}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>load_fault_wb</summary>

```asm
0000: 03700093    addi x1,x0,55
0004: 00102023    sw x1,0(x0)
0008: ffc02103    lw x2,-4(x0)
000c: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 1 | ex_fault | x1=00000037, M[0:4]=00000037 | F5@8 | RUNNING→FAULT_DRAIN_AUTO |
| 6 | 10 | F1@10 | - | - | - | 4:sw#1 | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT |
| 7 | 10 | F1@10 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [5, 8], "registers": {"x1": "00000037"}, "memory": {"0": 55, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>store_fault_wb</summary>

```asm
0000: 03700093    addi x1,x0,55
0004: 00102023    sw x1,0(x0)
0008: fe102e23    sw x1,-4(x0)
000c: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:sw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:halt#3 | 8:sw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:halt#3 | 8:sw#2 | 4:sw#1 | 0:addi#0 | 1 | ex_fault | x1=00000037, M[0:4]=00000037 | F7@8 | RUNNING→FAULT_DRAIN_AUTO |
| 6 | 10 | F1@10 | - | - | - | 4:sw#1 | 1 | drain_advance | - | - | FAULT_DRAIN_AUTO→FAULT |
| 7 | 10 | F1@10 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [7, 8], "registers": {"x1": "00000037"}, "memory": {"0": 55, "1": 0, "2": 0, "3": 0}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>store_align_and_range</summary>

```asm
0000: fe002fa3    sw x0,-1(x0)
0004: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:sw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:sw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:sw#0 | - | - | 1 | ex_fault | - | F6@0 | RUNNING→FAULT |
| 4 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [6, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>load_align_and_range</summary>

```asm
0000: fff02083    lw x1,-1(x0)
0004: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:lw#0 | - | - | 1 | ex_fault | - | F4@0 | RUNNING→FAULT |
| 4 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [4, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>load_last_word</summary>

```asm
0000: 80000fb7    lui x31,0x80000
0004: 081f8f93    addi x31,x31,129
0008: 3ff02223    sw x31,996(x0)
000c: 3e402083    lw x1,996(x0)
0010: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lui#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:lui#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:sw#2 | 4:addi#1 | 0:lui#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:lw#3 | 8:sw#2 | 4:addi#1 | 0:lui#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | 10:halt#4 | c:lw#3 | 8:sw#2 | 4:addi#1 | 0:lui#0 | 1 | normal | x31=80000000 | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | 10:halt#4 | c:lw#3 | 8:sw#2 | 4:addi#1 | 1 | normal | x31=80000081, M[3e4:4]=80000081 | - | RUNNING→RUNNING |
| 7 | 18 | F1@18 | F1@14 | 10:halt#4 | c:lw#3 | 8:sw#2 | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 8 | 18 | F1@18 | - | - | - | c:lw#3 | 1 | drain_advance | x1=80000081 | - | HALT_DRAIN_AUTO→FINISHED |
| 9 | 18 | F1@18 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "80000081", "x31": "80000081"}, "memory": {"996": 129, "997": 0, "998": 0, "999": 128}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>store_last_byte</summary>

```asm
0000: 07f00093    addi x1,x0,127
0004: 3e1003a3    sb x1,999(x0)
0008: 3e704103    lbu x2,999(x0)
000c: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:sb#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:lbu#2 | 4:sb#1 | 0:addi#0 | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 4 | c | c:halt#3 | 8:lbu#2 | 4:sb#1 | 0:addi#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | 10 | F1@10 | c:halt#3 | 8:lbu#2 | 4:sb#1 | 0:addi#0 | 1 | normal | x1=0000007f, M[3e7:1]=0000007f | - | RUNNING→RUNNING |
| 6 | 14 | F1@14 | F1@10 | c:halt#3 | 8:lbu#2 | 4:sb#1 | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 7 | 14 | F1@14 | - | - | - | 8:lbu#2 | 1 | drain_advance | x2=0000007f | - | HALT_DRAIN_AUTO→FINISHED |
| 8 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {"x1": "0000007f", "x2": "0000007f"}, "memory": {"999": 127}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>injected_PC_3</summary>

Ensayo **inyectado**, no programa alcanzable desde reset: imagen `halt; halt`, PC inicial forzado a 3. Verifica prioridad misalignment sobre access; no propone un entry point configurable.

Perfil DMEM: 2048 bytes (REFERENCE).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 3 | F0@3 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 7 | F0@7 | F0@3 | - | - | - | 1 | id_fault | - | F0@3 | RUNNING→FAULT |
| 3 | 7 | F0@7 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [0, 3]}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>faulting_load_with_consumer</summary>

```asm
0000: 00202083    lw x1,2(x0)
0004: 00108113    addi x2,x1,1
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:addi#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:addi#1 | 0:lw#0 | - | - | 1 | ex_fault | - | F4@0 | RUNNING→FAULT |
| 4 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [4, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>two_load_stalls</summary>

```asm
0000: 00002083    lw x1,0(x0)
0004: 0000a103    lw x2,0(x1)
0008: 001101b3    add x3,x2,x1
000c: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:lw#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:lw#1 | 0:lw#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | 8:add#2 | 4:lw#1 | 0:lw#0 | - | - | 1 | load_use | - | - | RUNNING→RUNNING |
| 4 | 8 | 8:add#2 | 4:lw#1 | - | 0:lw#0 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 5 | c | c:halt#3 | 8:add#2 | 4:lw#1 | - | 0:lw#0 | 1 | load_use | x1=00000000 | - | RUNNING→RUNNING |
| 6 | c | c:halt#3 | 8:add#2 | - | 4:lw#1 | - | 1 | normal | - | - | RUNNING→RUNNING |
| 7 | 10 | F1@10 | c:halt#3 | 8:add#2 | - | 4:lw#1 | 1 | normal | x2=00000000 | - | RUNNING→RUNNING |
| 8 | 14 | F1@14 | F1@10 | c:halt#3 | 8:add#2 | - | 1 | halt | - | HALT | RUNNING→HALT_DRAIN_AUTO |
| 9 | 14 | F1@14 | - | - | - | 8:add#2 | 1 | drain_advance | x3=00000000 | - | HALT_DRAIN_AUTO→FINISHED |
| 10 | 14 | F1@14 | - | - | - | - | 0 | HOLD | - | - | FINISHED→FINISHED |

Resultado: `{"state": "FINISHED", "fault": null, "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

<details>
<summary>branch_bad_target</summary>

```asm
0000: 00000163    beq x0,x0,2
0004: 0000000b    halt
```

Perfil DMEM: 1000 bytes (ALT_1000).

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:beq#0 | - | - | - | - | 1 | normal | - | - | READY→RUNNING |
| 2 | 4 | 4:halt#1 | 0:beq#0 | - | - | - | 1 | normal | - | - | RUNNING→RUNNING |
| 3 | 8 | F1@8 | 4:halt#1 | 0:beq#0 | - | - | 1 | ex_fault | - | F0@0 | RUNNING→FAULT |
| 4 | 8 | F1@8 | - | - | - | - | 0 | HOLD | - | - | FAULT→FAULT |

Resultado: `{"state": "FAULT", "fault": [0, 0], "registers": {}, "memory": {}}`. Los registros omitidos valen cero; memoria lista solo bytes escritos (los demás se leen como cero).

</details>

### Lectura adversarial de las trazas

- `lw_store_bad`: ciclo 3 solo stall; 4 captura candidato; 5 confirma **store misaligned, PC=4**, con WB anterior permitido. No se escribe ningún byte. Detecta la regresión original de prioridad temporal.
- `lw_alu`: el consumidor anterior escribe x2=9 **después** de confirmar el fault de fetch. Impedir ese WB sería un error de precisión. `pipeline_empty_next` alcanza FAULT en ese mismo último flanco.
- `lw_beq_taken`: el candidato en PC=8 se vuelve a detectar durante el stall, llega a IF/ID y se descarta por EX. No se necesita guardar el candidato fuera de IF/ID.
- `lw_beq_not` y `lw_bne_taken` inicializan explícitamente DMEM=7 con `addi; sw`; el fetch de fin de imagen ocurre en PC=16. No se reutiliza erróneamente PC=8 de un programa distinto.
- `lw_illegal`: la ilegal no utiliza rs1/rs2, de modo que **no puede** coincidir con un load-use causado por ella. Confirma ilegal ID; el load anterior termina. `lw_alu_illegal` comprueba un stall real previo a la ilegal.
- `load_masks_old`: x1 antiguo=17, load reciente=29, consumidor=58. Durante el ciclo en que el load está en MEM el consumidor aún no está en EX; no hay consumo del fallback residual.
- `WB_ID`: productor separado por dos instrucciones; cuando el consumidor se captura en ID/EX, el único dato nuevo está en WB. x2=34 detecta omitir el bypass.
- `dual_sources`: consumidor usa EX/MEM=29 y MEM/WB=17 en puertos distintos; resultado=12.
- `redirect_wrongpath` y `redirect_halt`: store, ilegal o halt jóvenes se invalidan antes de poder producir efectos; el enlace del salto correcto sí llega a WB.
- `target_outside`: JAL escribe enlace=4 y el fetch del target confirma causa 001, PC=64. `target_bad` no escribe enlace: el fault pertenece al JAL, PC=0.
- `jalr_rd_rs1`: se usa la base anterior x1=13, se limpia bit 0 y se salta a 12; el enlace nuevo x1=8 solo se escribe después. x2=16 verifica el resultado.
- `simultaneous_WB_MEM_fault/halt`: en el mismo flanco escriben x1 y un store anteriores, mientras se confirma la frontera joven. Los commits no se repiten en HOLD ni durante el avance restante.
- `EA_wrap`: base 0xffffffff más inmediato 1 produce dirección 0, store válido y lectura 123. `EA_underflow`, `load_align_and_range` y `store_align_and_range` cubren la clasificación opuesta.
- `partial_zero`: resultados 0x0000ff00 y 0xffffff00 prueban bytes no escritos en cero, stores parciales y visibilidad del store anterior para el load posterior.

## 5. Invariantes

**PASS** significa que la propiedad resulta de las ecuaciones vigentes bajo las precondiciones indicadas y no fue refutada por los ensayos; no equivale a una assertion formal ejecutada sobre RTL. **INCONCLUSIVE** identifica información de implementación que todavía no existe. No se marca FAIL a una propiedad correcta por introducir estados imposibles o por olvidar reset/aborto.

| # | Invariante | Estado | Justificación / condición |
| --- | --- | --- | --- |
| 1 | Entrada inválida sin efecto normal | PASS | Validez cualifica productor/consumidor, candidaturas EX, WB y store. IFID.fetch_fault_valid es una validez distinta y puede originar fault, nunca ejecución de sus residuos. |
| 2 | Wrong-path sin efecto | PASS | Cuando EX redirige, toda instrucción joven está en ID/IF. Se invalidan antes de EX/MEM. Store joven, ilegal y halt descartados en trazas. |
| 3 | Causante de fault sin efectos normales | PASS | Fault ID no entra en ID/EX; fault EX no entra en EX/MEM, ni aplica redirect/enlace. Confirmar metadata no es un efecto normal de la instrucción. |
| 4 | Anteriores completan exactamente una vez | PASS | La frontera deja avanzar MEM/WB y EX anterior en fault ID. Requiere futuros ciclos efectivos y ausencia de RESET/LOAD que aborte la sesión; en STEP no hay garantía de progreso sin nuevas órdenes. |
| 5 | Posteriores a frontera no completan | PASS | Toda frontera confirmada elimina IF/ID e ID/EX y detiene fetch nuevo. Durante drain solo quedan anteriores en MEM/WB. |
| 6 | Store como máximo una vez | PASS | Solo entrada EX/MEM previa y fire; en todo fire procesable MEM/WB captura y EX/MEM avanza/invalida. HOLD no vuelve a escribir. |
| 7 | WB como máximo una vez | PASS | Solo MEM/WB previa y fire; todo fire procesable consume esa entrada. No hay retención de WB durante un stall efectivo. |
| 8 | Cada fire incrementa una vez | PASS | Habilitación única; suma unsigned módulo 2^64. Un wrap sigue siendo incremento modular. |
| 9 | Sin fire no hay avance/efecto CPU | PASS | Gating y retención. RESET/LOAD/preparación pueden cambiar estado por su propia autoridad; esa excepción no es ejecución CPU. |
| 10 | Un STEP aceptado autoriza un ciclo | PASS | Inmediato en READY/STEPPING/drain STEP; diferido hasta done en sesión terminal. RESET puede cancelar el pendiente y preparación debe terminar. No prometer liveness incondicional. |
| 11 | Una de seis acciones no terminales | PASS | Para fire && terminal_none, cascada EX fault/halt/redirect, ID fault, stall o normal, exhaustiva y excluyente. |
| 12 | Una de dos acciones de drain | PASS | Para fire && drain_active, partición por load_use. En estados alcanzables solo drain_advance puede ser uno; HOLD tiene cero. |
| 13 | onehot0 de ocho acciones | PASS | Clases terminal_none y drain_active excluyentes; 256 combinaciones verificadas, incluso candidaturas incompatibles. |
| 14 | Productor más nuevo domina | PASS | Coincidencia EX/MEM cualificada precede a MEM/WB por fuente. x0 y campos no utilizados no crean productores. |
| 15 | Load no disponible no usa versión vieja | PASS | !exmem_match bloquea WB; el mux puede mostrar base residual. La pareja consumidora EX / load MEM dependiente es inalcanzable: prueba inductiva en §6. |
| 16 | Fault respeta edad | PASS | Al confirmar ID, toda instrucción anterior que aún pueda fallar/resolver flujo está en EX. MEM/WB ya superaron validación; EX tiene prioridad. Stall nunca deja confirmar IF. |
| 17 | Fetch wrong-path no confirma | PASS | Candidato solo confirma en ID tras prioridad EX. Redirect/halt/fault EX invalidan también fetch_fault_valid. |
| 18 | Sin pérdida/duplicación por stall/bubble/flush | PASS | Se conserva instrucción ID y PC en stall, avanza load, se inserta bubble; flush descarta exclusivamente trabajo autorizado. Retiro ordenado contrastado con intérprete. |
| 19 | empty_next refleja estado posterior | PASS | OR de cuatro valid_next, independientemente de datos residuales. La transición terminal ocurre tras consumir último válido, sin ciclo extra; candidato fetch aislado se discute en §8. |
| 20 | Sin lazo combinacional de control | PASS | Orden topológico del grafo de §7. next_state nunca alimenta aceptación/fire del mismo flanco. Limitado al contrato funcional; internals RTL aún no definidos. |

| Propiedad adicional | Estado | Motivo |
| --- | --- | --- |
| Snapshot atómico físicamente implementado | INCONCLUSIVE | Existe obligación de coherencia; no mecanismo de captura/serialización aprobado ni implementación. El wrap no invalida snapshot por contrato. |
| Preparación termina y cumple done | INCONCLUSIVE | Contrato de done preciso, pero no FSM privada/clear físico implementado; no se inventó una latencia. |
| Timing, CDC/reset y memoria inferida | INCONCLUSIVE | No RTL, constraints efectivos ni resultados físicos. La lectura combinacional es un compromiso que deberá verificarse. |
| Arquitectura textual sin nueva divergencia grave detectada | PASS dentro del alcance | Ensayos diferenciales y argumentos locales; no demostración automática universal del procesador. |

## 6. Matriz de control y hazards revisada

Las señales siguientes son aliases de acciones vigentes, con `cpu_cycle_fire` y modo incluidos. La prioridad es EX fault → EX halt → EX redirect → ID fault → load-use → normal. No existe confirmación de IF. Si se presentan candidatos incompatibles en un test de unidad, se aplica esa prioridad; su inclusión en el test no prueba que sean alcanzables desde el decoder.

| Acción | PC | IF/ID | ID/EX | EX/MEM | MEM/WB | Frontera |
| --- | --- | --- | --- | --- | --- | --- |
| ex_fault | Hold | Invalidar dos flags | Bubble | Invalidar | Capturar MEM | Fault EX |
| halt | Hold | Invalidar dos flags | Bubble | Invalidar | Capturar MEM | Halt EX |
| redirect | Target | Invalidar dos flags | Bubble | Capturar EX | Capturar MEM | Redirect |
| id_fault | Hold | Invalidar dos flags | Bubble | Capturar EX | Capturar MEM | Fault ID |
| load_use | Hold | Hold cinco campos | Bubble | Capturar EX | Capturar MEM | Ninguna |
| normal | PC+4 | Capturar IF/candidato | Capturar ID | Capturar EX | Capturar MEM | Ninguna |
| drain_load_use | Hold | Hold cinco campos | Bubble | Capturar EX | Capturar MEM | No confirmar; rama artificial en cobertura |
| drain_advance | Hold | Invalidar dos flags | Capturar ID inválida alcanzable | Capturar EX inválida alcanzable | Capturar MEM | Conservar tipo terminal |

`pipeline_action` es el OR de esas ocho acciones. `fault_capture_fire=ex_fault_confirm || id_fault_confirm`. Para cada latch, captura/retención/invalidez son mutuamente excluyentes; sin acción se retiene todo. Esto se comprobó sobre las 256 combinaciones del modelo de arbitraje.

**Prueba de que nunca se consume el fallback de un load no disponible:** supóngase EX/MEM load válido y EX consumidor válido dependiente después de un flanco. Si EX/MEM capturó el load desde EX anterior, para capturar simultáneamente al consumidor desde ID debía elegirse normal o drain_advance. En normal, esa misma pareja habría hecho load_use_stall=1, impidiendo normal e insertando bubble. En drain no existen D/E válidos (AUD2-002). Todas las demás acciones que podrían capturar el load insertan bubble en ID/EX. HOLD conserva la invariante; reset/preparación la establecen. Por inducción la pareja es inalcanzable. No se requiere un nuevo interlock en EX ni una cuarta entrada al mux.

**Forwarding por distancia:** productor inmediato no load se encuentra en EX/MEM; con una instrucción intermedia, en MEM/WB; con dos, escribió en el mismo flanco en que el consumidor capturó ID y se necesita WB→ID; más lejos ya está en RF. El stall añade una bubble al load inmediato, desplazándolo a MEM/WB antes del consumo. Los dos puertos se evalúan separadamente y el productor más nuevo enmascara al viejo aunque este coincida.

| Caso requerido | Ensayo / demostración | Resultado |
| --- | --- | --- |
| EX/MEM→EX | forward_newest, dual_sources, forward_lui | Datos 29/17/0x12345000; también link. |
| MEM/WB→EX | lw_alu, dual_sources | Load reciente y productor con separación. |
| Prioridad EX/MEM sobre WB | forward_newest | 29 domina 17; resultado 58. |
| Load no disponible | load_masks_old | Stall antes del consumo. |
| Sin fallback viejo | load_masks_old + inducción | Dato antiguo=17, nuevo=29; no se usa base antigua. |
| WB→ID | WB_ID | Dos instrucciones intermedias; resultado 34. |
| x0 | x0_no_hazard, load_x0_fault | Sin dependencia/escritura, pero load a x0 todavía puede fallar. |
| Store base | lw_store_base | Dirección tomada del load. |
| Store data | lw_store_data | Dato transportado en EX/MEM.store_data. |
| Branch operands | lw_beq_taken/not, lw_bne_taken/not | Comparación con resultado del load, no dato base. |
| JALR base | lw_jalr, jalr_rd_rs1 | Forward, limpieza de bit0 y rd==rs1. |
| Dos fuentes simultáneas | dual_sources, load_store_both | Fuentes distintas y ambas fuentes dependientes del mismo load. |
| Mismo rd consecutivo | forward_newest, load_masks_old | Productores con valores distintos. |
| Load-use seguido de dependencia | chain | Load→add y cadenas anteriores. |
| Tres o más productores | chain | 17→29→58→87; dato de store y siguiente load. |
| Stall en STEP | lw_store_bad_STEP | Dos HOLD entre ciclos; PC/candidato estables. |
| Forwarding durante drenado | No alcanzable hacia EX válida | Se prueban commits MEM/WB; selección combinacional aislada no implica consumo. |
| Forwarding hacia luego descartadas | redirect_wrongpath, redirect_halt | Los datos pueden existir combinacionalmente; validez impide efectos. |

`redirect_apply && load_use_stall` es inalcanzable para una entrada ID/EX legal: un load y un branch/jump tienen clases de control distintas. El árbitro igualmente concede prioridad a redirect en una prueba combinacional artificial. EX fault sí puede coincidir con load-use: load desalineado o fuera de rango descarta al consumidor, como `faulting_load_with_consumer` (ciclo 3: EX fault frente a load-use y candidato IF).

**Conservación de candidato IF cuando no captura:** HOLD y load-use conservan PC e imagen; la detección se repite sin estado adicional. Redirect cambia el camino y autoriza descartarlo. Fault/halt anterior dejan de admitir jóvenes. RESET/LOAD/preparación abandonan la sesión. Drain no acepta nuevas instrucciones. No queda un caso de retención correcta que requiera guardar el candidato en otro registro.

## 7. FSM global y cpu_cycle_fire

Se verificaron los 14 estados, sin introducir un decimoquinto ni registros `terminal_kind`/`drain_auto`. LOAD es elegible en NO_IMAGE, READY, STEPPING, ambos drain STEP y estados terminales. RUN/STEP lo son en ese conjunto salvo NO_IMAGE. Prioridad de aceptaciones: RESET > LOAD > STEP > RUN. Solicitar LOAD no equivale a aceptarlo.

| Estado previo | Avance CPU permitido | Transición relevante |
| --- | --- | --- |
| NO_IMAGE | No | LOAD→LOADING. |
| LOADING | No | ok→PREPARING_READY; fail→NO_IMAGE; no publicar tamaño. |
| PREPARING_READY | No | done→READY y commit de tamaño; count=0. |
| PREPARING_RUN | Solo done | Primer ciclo con estado ya limpio; count=1, origen continuo. |
| PREPARING_STEP | Solo done | Consume STEP diferido; count=1, origen STEP. |
| READY | RUN o STEP aceptado | Ejecuta un ciclo en ese flanco; LOAD domina. |
| RUNNING | Automático | LOAD/RUN/STEP rechazados no suprimen el ciclo. |
| STEPPING | RUN o STEP aceptado | Un STEP; RUN habilita continuidad; LOAD aborta. |
| HALT_DRAIN_AUTO | Automático | Vacío posterior→FINISHED. |
| HALT_DRAIN_STEP | RUN o STEP aceptado | RUN convierte resto a AUTO; LOAD aborta; vacío→FINISHED. |
| FAULT_DRAIN_AUTO | Automático | Vacío posterior→FAULT. |
| FAULT_DRAIN_STEP | RUN o STEP aceptado | RUN convierte resto a AUTO; LOAD aborta; vacío→FAULT. |
| FINISHED | No | RUN/STEP→PREPARING_RUN/STEP; LOAD→LOADING. |
| FAULT | No | Igual preparación nueva; nunca reanudar sesión fault. |

En todos los estados RESET→NO_IMAGE con fire=0. En toda fila que ejecuta un ciclo, el resultado es FAULT/FAULT_DRAIN si confirma fault, FINISHED/HALT_DRAIN si confirma halt, o RUNNING/STEPPING según origen. En drain no se confirma una nueva frontera. Si se consume el último válido, cambia al estado final en ese mismo flanco.

Se recorrieron **8.064 combinaciones**, incluidas solicitudes concurrentes, done, load_ok/load_fail excluyentes, eventos fault/halt excluyentes y los dos valores de empty_next. Los eventos de resultado fuera de un ciclo pertinente se ignoran; no se interpretaron todas esas combinaciones como estados físicos alcanzables. Los 14 reset y el rechazo de LOAD en los tres estados AUTO quedaron cubiertos.

### Trazas de comandos y preparación

Estas trazas son del control global; `done` es un certificado preflanco, no la última escritura de clear. `empty` en drain describe los valid_next del ciclo que se autoriza. Los datos privados de Loader/preparación no se implementaron.

**terminal_STEP**

| Flanco | Estado previo | Entradas | Aceptación | fire | Estado siguiente |
| --- | --- | --- | --- | --- | --- |
| 1 | FAULT | {"step": 1} | step | 0 | PREPARING_STEP |
| 2 | PREPARING_STEP | {} | - | 0 | PREPARING_STEP |
| 3 | PREPARING_STEP | {"done": 1} | - | 1 | STEPPING |
| 4 | STEPPING | {} | - | 0 | STEPPING |
| 5 | STEPPING | {"step": 1} | step | 1 | STEPPING |

**terminal_STEP_reset**

| Flanco | Estado previo | Entradas | Aceptación | fire | Estado siguiente |
| --- | --- | --- | --- | --- | --- |
| 1 | FINISHED | {"step": 1} | step | 0 | PREPARING_STEP |
| 2 | PREPARING_STEP | {"reset": 1} | - | 0 | NO_IMAGE |
| 3 | NO_IMAGE | {"done": 1} | - | 0 | NO_IMAGE |

**load_abort_drain**

| Flanco | Estado previo | Entradas | Aceptación | fire | Estado siguiente |
| --- | --- | --- | --- | --- | --- |
| 1 | FAULT_DRAIN_STEP | {"load": 1, "step": 1} | load | 0 | LOADING |
| 2 | LOADING | {"loadresult": "ok"} | - | 0 | PREPARING_READY |
| 3 | PREPARING_READY | {} | - | 0 | PREPARING_READY |
| 4 | PREPARING_READY | {"done": 1} | - | 0 | READY |
| 5 | READY | {"step": 1} | step | 1 | STEPPING |

**load_fail**

| Flanco | Estado previo | Entradas | Aceptación | fire | Estado siguiente |
| --- | --- | --- | --- | --- | --- |
| 1 | READY | {"load": 1} | load | 0 | LOADING |
| 2 | LOADING | {"loadresult": "fail"} | - | 0 | NO_IMAGE |
| 3 | NO_IMAGE | {"run": 1} | - | 0 | NO_IMAGE |

**run_drain**

| Flanco | Estado previo | Entradas | Aceptación | fire | Estado siguiente |
| --- | --- | --- | --- | --- | --- |
| 1 | HALT_DRAIN_STEP | {"run": 1} | run | 1 | HALT_DRAIN_AUTO |
| 2 | HALT_DRAIN_AUTO | {"empty": 1} | - | 1 | FINISHED |
| 3 | FINISHED | {} | - | 0 | FINISHED |
| 4 | FINISHED | {"run": 1} | run | 0 | PREPARING_RUN |
| 5 | PREPARING_RUN | {"done": 1} | - | 1 | RUNNING |

**rejected_load_auto**

| Flanco | Estado previo | Entradas | Aceptación | fire | Estado siguiente |
| --- | --- | --- | --- | --- | --- |
| 1 | RUNNING | {"load": 1} | - | 1 | RUNNING |
| 2 | RUNNING | {"load": 1, "event": "halt", "empty": 0} | - | 1 | HALT_DRAIN_AUTO |
| 3 | HALT_DRAIN_AUTO | {"load": 1, "empty": 1} | - | 1 | FINISHED |

La traza terminal_STEP_reset es un límite necesario de la frase «exactamente un ciclo por STEP»: el reset prioritario cancela una preparación pendiente. No es una violación del contrato de reset ni requiere una decisión nueva. Sin reset y con done eventual, el STEP pendiente se consume una sola vez. No se demostró que un mecanismo privado todavía inexistente siempre produzca done.

### Grafo de dependencias combinacionales

Se reconstruyeron dependencias de datos y control desde los registros **actuales**. Los nombres agrupan buses/campos para hacer legible el grafo; las relaciones hacia `.next` no vuelven al registro actual en el mismo ciclo. Una dependencia conservadora adicional no se utiliza para ocultar un ciclo.

| Nodo derivado | Depende de |
| --- | --- |
| modes | global_state |
| accept | global_state, requests, reset |
| cycle_request | modes, accept, prepare_done |
| cpu_cycle_fire | cycle_request, reset, accept |
| decode | IFID_instruction |
| rf_write_fire | cpu_cycle_fire, MEMWB |
| WB_ID | RF, MEMWB, decode, rf_write_fire |
| uses_EX | IDEX |
| forward_match | uses_EX, IDEX, EXMEM, MEMWB |
| forward_select | forward_match, EXMEM |
| operands | forward_select, IDEX, EXMEM, MEMWB |
| alu | operands, IDEX |
| target | operands, IDEX |
| EX_candidates | alu, target, IDEX |
| ID_candidates | decode, IFID_flags |
| IF_candidates | PC, loaded_image_size_bytes, capacity |
| IF_word | PC, IMEM, IF_candidates |
| load_use | decode, IFID_flags, IDEX |
| pipeline_empty | valid_current |
| drain_active | modes, pipeline_empty |
| confirmations | cpu_cycle_fire, modes, EX_candidates, ID_candidates |
| actions | confirmations, cpu_cycle_fire, modes, drain_active, load_use |
| EX_result | alu, IDEX |
| DMEM_load | EXMEM, DMEM_data, DMEM_valid, cpu_cycle_fire |
| WB_value | EXMEM, DMEM_load |
| PC_next | PC, actions, target, maintenance |
| IFID_next | IF_word, IF_candidates, PC, actions, maintenance |
| IDEX_next | decode, WB_ID, IFID_instruction, actions, maintenance |
| EXMEM_next | EX_result, operands, IDEX, actions, maintenance |
| MEMWB_next | WB_value, EXMEM, actions, maintenance |
| valid_next | actions, valid_current, IF_candidates, maintenance |
| pipeline_empty_next | valid_next |
| FSM_next | global_state, accept, reset, prepare_done, loader_events, confirmations, pipeline_empty_next |
| DMEM_write | cpu_cycle_fire, EXMEM |
| fault_metadata_next | confirmations, IDEX, IFID_instruction, IFID_flags, fault_metadata |
| count_next | cycle_count, cpu_cycle_fire, maintenance |
| maintenance | global_state, reset, accept, prepare_done, private_loader_state |
| RF_next | RF, rf_write_fire, MEMWB, maintenance |
| DMEM_next | DMEM_data, DMEM_valid, DMEM_write, EXMEM, maintenance |
| image_size_next | loaded_image_size_bytes, global_state, reset, accept, prepare_done, private_loader_state |
| snapshot_values | global_state, PC, RF, IFID_instruction, IFID_flags, IDEX, EXMEM, MEMWB, DMEM_data, DMEM_valid, cycle_count, fault_metadata, loaded_image_size_bytes |

Orden topológico obtenido por DFS con detección de nodos activos:

```text
global_state → modes → requests → reset → accept → prepare_done → cycle_request → cpu_cycle_fire → IFID_instruction → decode → MEMWB → rf_write_fire → RF → WB_ID → IDEX → uses_EX → EXMEM → forward_match → forward_select → operands → alu → target → EX_candidates → IFID_flags → ID_candidates → PC → loaded_image_size_bytes → capacity → IF_candidates → IMEM → IF_word → load_use → valid_current → pipeline_empty → drain_active → confirmations → actions → EX_result → DMEM_data → DMEM_valid → DMEM_load → WB_value → private_loader_state → maintenance → PC_next → IFID_next → IDEX_next → EXMEM_next → MEMWB_next → valid_next → pipeline_empty_next → loader_events → FSM_next → DMEM_write → fault_metadata → fault_metadata_next → cycle_count → count_next → RF_next → DMEM_next → image_size_next → snapshot_values
```

El camino más relevante es `global_state → aceptación → fire → confirmaciones/acción → valid_next → empty_next → FSM_next`. `FSM_next` solo se registra; no alimenta aceptación, fire ni las candidaturas del ciclo actual. WB→ID depende de fire, pero candidaturas de ID dependen de codificación/validez, no del dato posbypass; por ello no cierra un lazo. EX usa ID/EX registrado y fuentes EX/MEM/MEM/WB actuales, nunca sus próximos valores. La lectura de DMEM alimenta MEM/WB.next y no vuelve a EX del mismo ciclo.

**Límite:** private_loader_state, prepare_done y mantenimiento representan interfaces con contrato previo al flanco. Sus circuitos internos no están definidos. La aciclicidad demostrada es la del grafo funcional documentado, no de RTL futuro ni de una FSM privada inventada.

### Prioridad frente a efectos existentes

RESET y LOAD aceptado hacen fire=0 antes del gating de WB/store/fault/halt. Por ello un WB previo no escribe al aceptar LOAD y un store previo no se compromete durante RESET. Una solicitud LOAD rechazada en AUTO conserva fire. Durante preparación efectiva done=0, sin CPU; con done=1 en PREPARING_RUN/STEP se exige que todas las escrituras de preparación hayan terminado en flancos anteriores, habilitando el primer CPU. Un candidato combinacional durante HOLD/preparación no captura metadata.

Para imagen corta tras reprogramación: LOAD aceptado publica tamaño=0, Loader puede dejar residuos físicos, load_ok no publica imagen, y solo PREPARING_READY+done compromete el nuevo tamaño. Fetch usa ese tamaño; residuos posteriores al nuevo prefijo no se ejecutan. load_fail mantiene tamaño=0. RUN/STEP desde terminal retienen el tamaño confirmado pero limpian RF/DMEM/pipeline/count antes de done.

### RESET y LOAD aceptado frente a commits pendientes

Programa concreto de `simultaneous_WB_MEM_fault`: addi x1,85; sw x1,0(x0); lw x2,2(x0); halt. Se ejecutan cuatro STEP y en el quinto flanco se aplica la prioridad global. Ese flanco tendría simultáneamente WB, store y fault EX si se autorizara CPU. Estas dos trazas aplican fire=0 por reset/aceptación LOAD. Para LOAD no se elige un clear físico instantáneo: el estado se abandona y la preparación debe limpiar antes de done. Para RESET se muestran los valores funcionales obligatorios; DMEM física puede conservar residuos, sin sesión activa.

**RESET**

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes CPU | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→STEPPING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | STEPPING→STEPPING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | STEPPING→STEPPING |
| 4 | c | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | STEPPING→STEPPING |
| 5 | 10 | F1@10 | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 0 | RESET | - | - | STEPPING→NO_IMAGE |
| 6 | 0 | F1@0 | - | - | - | - | 0 | HOLD | - | - | NO_IMAGE→NO_IMAGE |

Postcondición: x1=0, ningún byte escrito por el store previo, sin fault capturado, image_size=0, estado NO_IMAGE. Contador=0; en LOAD no se impone todavía el flanco de inicialización del contador.

**LOAD_ACCEPT**

| Ciclo/fila | PC | IF | IF/ID | ID/EX | EX/MEM | MEM/WB | fire | Acción | Writes CPU | Fault/halt | global_state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0:addi#0 | - | - | - | - | 1 | normal | - | - | READY→STEPPING |
| 2 | 4 | 4:sw#1 | 0:addi#0 | - | - | - | 1 | normal | - | - | STEPPING→STEPPING |
| 3 | 8 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | - | 1 | normal | - | - | STEPPING→STEPPING |
| 4 | c | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | - | 1 | normal | - | - | STEPPING→STEPPING |
| 5 | 10 | F1@10 | c:halt#3 | 8:lw#2 | 4:sw#1 | 0:addi#0 | 0 | LOAD_ACCEPT | - | - | STEPPING→LOADING |

Postcondición: x1=0, ningún byte escrito por el store previo, sin fault capturado, image_size=0, estado LOADING. Contador=4; en LOAD no se impone todavía el flanco de inicialización del contador.

## 8. Faults precisos, halt y pipeline_empty_next

| Causa | Detección / confirmación | fault_pc | Ensayo |
| --- | --- | --- | --- |
| 000 instruction-address-misaligned | Target EX; alternativamente candidato IF transportado a ID | PC del branch/jump causante; PC del fetch para ruta IF/ID | target_bad, lw_jalr_bad; injected_PC_3 para ruta IF aislada |
| 001 instruction-access-fault | IF detecta, ID confirma | Dirección del fetch en IF/ID | lw_alu, target_outside |
| 010 illegal-instruction | ID | PC de word ilegal | first_illegal, lw_illegal |
| 100 load-address-misaligned | EX | ID/EX.pc | lw_load_bad, simultaneous_WB_MEM_fault, load_align_and_range |
| 101 load-access-fault | EX | ID/EX.pc | EA_underflow, load_fault_wb |
| 110 store-address-misaligned | EX | ID/EX.pc | lw_store_bad, store_align_and_range |
| 111 store-access-fault | EX | ID/EX.pc | store_range, store_fault_wb |

`011` no representa ausencia de fault: está reservado. La validez de metadata se deriva de FAULT_DRAIN_AUTO/STEP o FAULT. IF/ID solo transporta 000/001 para un candidato; una bubble sin flag no confirma ilegal por sus bits.

**Prueba de precisión por edad:** cuando ID confirma, todas las instrucciones anteriores están en EX/MEM/WB. La única que todavía puede resolver control o causar un fault nuevo está en EX, y prevalece por la ecuación del acuerdo 47. Si no hay frontera EX, esa instrucción anterior ha completado sus comprobaciones y pasa a MEM. Las anteriores ya en MEM/WB no vuelven a verificar rango ni pueden descubrir un nuevo fault tardío; capacidades e imagen no cambian dentro de una sesión en ejecución. Cuando EX confirma, MEM/WB son anteriores y conservan sus efectos. Las jóvenes no han alcanzado ninguna etapa de commit. La combinación de edad y etapas, no una prioridad global por tipo de causa, justifica el orden EX→ID.

La metadata se escribe solo con fault_confirm y terminal_none deja de ser cierto inmediatamente después. Aun si IF sigue mostrando un candidato, no hay segunda captura. Reset o LOAD invalidan la interpretación de metadata por el estado; no necesitan borrar los bits físicos. Misalignment domina access **dentro de la misma operación**; un fault joven por desalineación no puede adelantarse a uno anterior de otro tipo.

El PC global puede haber avanzado a 12 mientras fault_pc es 8 o 4: las trazas comprueban que no se utiliza el PC retenido de IF para metadata. El caso target fuera de imagen se distingue del target desalineado: el primero permite que el salto y su enlace completen; el segundo anula los efectos del propio salto.

**Halt:** solo 0x0000000B válida genera candidatura ID, y solo EX confirma. Halt primero alcanza FINISHED sin esperar un ciclo ficticio. Con store/WB anteriores, estos completan y pueden requerir drain posterior. Un fetch joven fuera de imagen se descarta. Un fault anterior elimina halt joven; redirect anterior elimina halt wrong-path. No hay combinación legal en la que una misma instrucción sea halt y load/store o jump con fault propio, aunque el árbitro conserva prioridad EX fault ante entradas artificiales incompatibles.

**Vaciado:** se calcula desde cuatro valid_next, no desde cuatro valid actuales ni desde el próximo estado de la FSM. Después de toda frontera IF/ID y ID/EX son inválidos; si no quedan MEM/WB válidos, el estado terminal se alcanza inmediatamente. Si la última instrucción superviviente es store, puede seguir válida en MEM/WB aunque su efecto ya haya ocurrido en MEM: el contrato conserva esa etapa y la observabilidad hasta el siguiente ciclo. Eso no es un ciclo extra con pipeline vacío.

Que `fetch_fault_valid` no integre pipeline_empty es seguro bajo las transiciones vigentes: un candidato aislado en IF/ID puede coexistir con los cuatro valid=0 **antes de confirmar**, pero en ese instante la FSM sigue no terminal y autoriza el ciclo normal/STEP que confirma en ID. La confirmación invalida el flag. No existe un terminal alcanzable que pierda un fetch fault pendiente por ignorar el flag en empty.

Los estados DRAIN alcanzables no tienen EX ni ID activos. Por lo tanto, «ignorar nuevas fronteras durante drain» no puede ocultar un fault/redirect de una instrucción anterior pendiente en EX. Precisamente esa propiedad no se cumplía con la antigua excepción de IF.

## 9. Memorias, direcciones y límites

IMEM y DMEM son recursos lógicos independientes: fetch y MEM simultáneos no compiten. Lecturas combinacionales y escrituras síncronas son condiciones del modelo y del contrato (`decisions:3584–3711`), pendientes de comprobar físicamente. El modelo no añade bypass DMEM→EX ni latencias variables.

La dirección efectiva es `(rs1_effective + immediate) & 0xffffffff`; la segunda suma es unsigned de 33 bits. Para cualquier dirección a de 32 bits y N∈{1,2,4}, `a+N<=C` es equivalente a que todos los bytes `a ... a+N-1` pertenezcan a `[0,C)`, sin reducción modular. El máximo extremo es 2^32+3 y cabe en 33 bits. Capacidad=2^32 también necesita 33 bits; truncarla a 32 produce un error de implementación.

| Perfil / dominio | IMEM bytes | DMEM bytes | Último fetch/word alineado | Observación |
| --- | --- | --- | --- | --- |
| REFERENCE | 1024 | 2048 | IF=1020; DMEM=2044 | Compromiso físico completo futuro. |
| ALT_1000 | 1000 | 1000 | IF/DMEM=996 | 1000 no es potencia de dos; no usar máscara como comprobación de región. |
| Mínimo arquitectónico | 4 | 4 | 0 | Prueba aritmética/configuración, no perfil físico adicional aprobado. |
| Límite arquitectónico | 2^32 | 2^32 | 0xfffffffc | Extremo exclusivo 2^32 y ancho imagen=33; no se materializó ese array. |

| Dirección relativa al límite C | Byte | Halfword | Word |
| --- | --- | --- | --- |
| C−4 | Válido | Válido | Válido |
| C−3 | Válido | Misaligned | Misaligned |
| C−2 | Válido | Válido | Misaligned (también fuera de región) |
| C−1 | Válido | Misaligned (también fuera de región) | Misaligned (también fuera de región) |
| C | Access fault | Access fault | Access fault |

Tabla para capacidades múltiplo de cuatro y direcciones efectivas ya calculadas. Se probaron 0,1,2,3,C−1,C−2,C−3,C−4,0x7fffffff,0x80000000,0xfffffffc,0xffffffff para C=4/1000/1024/2048/2^32, eliminando duplicados: 162 combinaciones con N. Por ejemplo, con C=1000, word en 996 es válida, en 1000 es access fault y en 998 es misaligned aun cuando también supera el rango.

`0xffffffff+1` al generar EA da 0 y puede ser válido. `0xfffffffc+4` al comprobar región da 2^32: inválido en REFERENCE/ALT_1000 y válido en el dominio de capacidad máxima. No hay aliasing hacia índice cero. `0xffffffff+4` produce 2^32+3 en el chequeo; no se trunca. Los índices se derivan **después** de validar la región y alineación.

IF valida simultáneamente capacidad y tamaño de imagen, con N=4 ensanchado. Una imagen de 8 bytes termina en PC=4; PC=8 es inválido aunque IMEM física sea mayor. Fetch parcialmente fuera de imagen se rechaza por región; con imagen múltiplo de cuatro y PC alineado no aparece parcialmente, pero sí al inyectar PC desalineado: entonces causa 000 prevalece. Los jumps no desalineados pueden alcanzar un target fuera de imagen; su fault posterior pertenece al fetch.

DMEM ensambla byte bajo en bits bajos, filtra cada byte por valid antes de sign/zero extension y actualiza dato+valid de los bytes seleccionados atómicamente. Se recorrieron 16 patrones de validez de word × 7 lecturas de distintos tamaños/offsets = 112 vectores. `little_endian` distingue LB/LBU/LH/LHU con bytes altos 0x80/0xff; `partial_zero` conserva bytes no seleccionados y deja cero los nunca escritos. Los ejemplos con stores demuestran también que loads posteriores ven los stores anteriores sin buffer ni hazard estructural adicional.

El mecanismo privado de limpiar metadata no está implementado. Por contrato no puede publicar done antes de que todos los bytes vuelvan a cero lógico. Un future test de generación de sesión deberá sembrar datos y validez antiguos, ejecutar LOAD/preparación y observar el nuevo prefijo y la nueva DMEM, en lugar de confiar en limpiar arrays dentro de un modelo abstracto.

## 10. ISA, decoder, datapath y suficiencia de campos

Se contrastaron los patrones y semántica con `decisions:2064–2305,3295–3316` y con la fuente primaria de [RISC-V User-Level ISA v2.2, capítulo RV32I](https://raw.githubusercontent.com/riscv/riscv-isa-manual/riscv-user-2.2/src/rv32.tex). La referencia externa respalda formato/sign extension, cinco bits de shift, enlaces y cálculo/alineación de destinos; la whitelist restringida, halt custom y política de faults del TP3 siguen siendo decisiones locales.

La tabla siguiente explicita las 32 instrucciones más halt. `src=0` selecciona rs2 y `src=1` el inmediato; `res` corresponde a ALU=00, IMM=01, LINK=10. `rd` se extrae de bits 11:7, pero solo se usa con wr=1 y rd≠0. Las words de ejemplo son estímulos de decoder; la ejecución diferencial empleó también valores extremos y programas completos.

| Instrucción | Word ejemplo | uses rs1/rs2 | ALU | src | res | flow | mem | wr |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| add | 002081b3 | 1/1 | ADD | 0 | ALU | NONE | NONE | 1 |
| sub | 402081b3 | 1/1 | SUB | 0 | ALU | NONE | NONE | 1 |
| sll | 002091b3 | 1/1 | SLL | 0 | ALU | NONE | NONE | 1 |
| slt | 0020a1b3 | 1/1 | SLT | 0 | ALU | NONE | NONE | 1 |
| sltu | 0020b1b3 | 1/1 | SLTU | 0 | ALU | NONE | NONE | 1 |
| xor | 0020c1b3 | 1/1 | XOR | 0 | ALU | NONE | NONE | 1 |
| srl | 0020d1b3 | 1/1 | SRL | 0 | ALU | NONE | NONE | 1 |
| sra | 4020d1b3 | 1/1 | SRA | 0 | ALU | NONE | NONE | 1 |
| or | 0020e1b3 | 1/1 | OR | 0 | ALU | NONE | NONE | 1 |
| and | 0020f1b3 | 1/1 | AND | 0 | ALU | NONE | NONE | 1 |
| addi | 00408193 | 1/0 | ADD | 1 | ALU | NONE | NONE | 1 |
| slli | 00409193 | 1/0 | SLL | 1 | ALU | NONE | NONE | 1 |
| slti | 0040a193 | 1/0 | SLT | 1 | ALU | NONE | NONE | 1 |
| sltiu | 0040b193 | 1/0 | SLTU | 1 | ALU | NONE | NONE | 1 |
| xori | 0040c193 | 1/0 | XOR | 1 | ALU | NONE | NONE | 1 |
| srli | 0040d193 | 1/0 | SRL | 1 | ALU | NONE | NONE | 1 |
| srai | 4040d193 | 1/0 | SRA | 1 | ALU | NONE | NONE | 1 |
| ori | 0040e193 | 1/0 | OR | 1 | ALU | NONE | NONE | 1 |
| andi | 0040f193 | 1/0 | AND | 1 | ALU | NONE | NONE | 1 |
| lb | 00408183 | 1/0 | ADD | 1 | ALU | NONE | LB | 1 |
| lh | 00409183 | 1/0 | ADD | 1 | ALU | NONE | LH | 1 |
| lw | 0040a183 | 1/0 | ADD | 1 | ALU | NONE | LW | 1 |
| lbu | 0040c183 | 1/0 | ADD | 1 | ALU | NONE | LBU | 1 |
| lhu | 0040d183 | 1/0 | ADD | 1 | ALU | NONE | LHU | 1 |
| sb | 00208223 | 1/1 | ADD | 1 | ALU | NONE | SB | 0 |
| sh | 00209223 | 1/1 | ADD | 1 | ALU | NONE | SH | 0 |
| sw | 0020a223 | 1/1 | ADD | 1 | ALU | NONE | SW | 0 |
| beq | 00208263 | 1/1 | SUB | 0 | ALU | BEQ | NONE | 0 |
| bne | 00209263 | 1/1 | SUB | 0 | ALU | BNE | NONE | 0 |
| jal | 004001ef | 0/0 | ADD | 1 | LINK | JAL | NONE | 1 |
| jalr | 004081e7 | 1/0 | ADD | 1 | LINK | JALR | NONE | 1 |
| lui | 800001b7 | 0/0 | ADD | 1 | IMM | NONE | NONE | 1 |
| halt | 0000000b | 0/0 | ADD | 0 | ALU | HALT | NONE | 0 |

ALU: ADD=100000, SUB=100010, SLL=000000, SRL=000010, SRA=000011, AND=100100, OR=100101, XOR=100110, SLT=101010, SLTU=101011. NOR no se emite. Memoria: NONE=0000, LB/LH/LW=0001/0010/0011, LBU/LHU=0100/0101, SB/SH/SW=0110/0111/1000. Flujo: NONE/BEQ/BNE/JAL/JALR/HALT=000/001/010/011/100/101. Los códigos reservados no se emiten para una instrucción válida.

**Inmediatos:** I concatena y extiende instruction[31:20]; S reordena [31:25] y [11:7]; B usa [31], [7], [30:25], [11:8], 0; J usa [31], [19:12], [20], [30:21], 0; U conserva [31:12] y doce ceros. Se enumeraron todos los I/S/B y offsets J legales, más extremos U: 1.060.869 vectores. Los campos rs2 aparentes de I y los índices aparentes de LUI/JAL no se consumen como fuentes.

**Shifts y signed:** SLL/SRL/SRA toman exclusivamente b[4:0]; cantidades 32/33/0xffffffff se convierten en 0/1/31. SRA usa operando con signo. En SRAI, el patrón fijo 0100000 no forma parte de shamt. SLT usa signed; SLTU usa unsigned, incluyendo inmediato sign-extended tratado después como patrón unsigned. Se contrastaron 0,1,0x7fffffff,0x80000000,0xffffffff contra 0,1,31,32,33,0xffffffff.

**Resultados especiales:** LUI toma IMM, aunque ALU tenga ADD determinista; JAL/JALR toman enlace desde ID/EX.pc+4 y lo llevan como ex_result hasta WB. Branch usa SUB y zero; el Target Adder usa el PC de la instrucción. JALR suma base efectiva+I, reduce a 32 bits, borra bit0 y luego comprueba bit1. Stores resuelven rs2 por forwarding aunque ALU use inmediato para la dirección. Loads a x0 no escriben RF, pero sus faults siguen vigentes.

**Legalidad:** R-type exige funct7/funct3 exactos, I aritmética deja sus doce bits variables, shifts inmediatos exigen bits fijos, JALR exige funct3=000. Solo word exacta 0000000b es halt. Defaults ilegales neutros no sustituyen el chequeo de valid. En IFID con fetch_fault_valid=1 y valid=0, una word residual no es una ilegal ni un halt. El barrido de campos fijos confirmó exactamente 33 nombres de clase.

| Registro | Información que se consume después | Resultado de suficiencia |
| --- | --- | --- |
| IF/ID | valid, pc, instruction, fetch_fault_valid, fetch_fault_cause | Suficiente: índices/uso/immediato se derivan en ID; PC identifica instrucción o candidato. |
| ID/EX | valid, pc, instruction, rs1/rs2/rd, dos valores posbypass, inmediato y seis categorías de control | Suficiente para ALU, comparación, targets/link, validación DMEM y rederivación de uses en EX. No necesita flags uses registrados. |
| EX/MEM | valid, pc, instruction, rd, ex_result, store_data, mem_op, reg_write | Suficiente para dirección, dato separado de store, tamaño/extensión de load y forwarding disponible. |
| MEM/WB | valid, pc, instruction, rd, wb_value, reg_write | Suficiente para writeback único y bypass. No necesita mem_op ni link separado. |
| Estado global | global_state, fault_cause, fault_pc, loaded_image_size_bytes, cycle_count | Modos y validez de fault/imagen se derivan. No se necesita registro de candidato IF adicional. |

No encontré una instrucción soportada que pierda un dato antes de su consumo. El contenido físico funcional y la representación externa de Debug son asuntos distintos: DEC-ARCH-009 pendiente no habilita añadir campos internos sin revisión.

## 11. Referencias y textos stale restantes

Se buscaron las cadenas retiradas en decisions, requirements, plan, pending_decisions y README. Resultado normativo actual: **cero referencias que autoricen confirmación directa en IF**, nueve acciones o siete no terminales. Lo encontrado en decisions queda dentro del desarrollo histórico de acuerdos previos y sus avisos de sustitución (`decisions:1011`, avisos locales y acuerdo 47); la matriz original 46 está archivada y revisada (`decisions:3043–3118`).

| Cadena literal | Líneas en decisions.md | Clasificación |
| --- | --- | --- |
| if_fault_exception_confirm | 2446, 2452, 2468, 2518, 2532, 2537, 2558, 2591 | A — historia revisada |
| act_if_fault_exception | 2558, 2573, 2607, 2629, 2663, 2696, 2719, 2745, 2823, 3022, 3097 | A — historia revisada |
| IF excepcional | 1025, 1758, 1810, 1854, 2038, 2056, 2078, 2151, 2251, 2315, 2478, 2524, 2654, 3016, 3017, 3097 | A — historia revisada |
| nueve acciones | 1334, 1941, 2478, 2551, 2602, 2719, 2881, 3006, 3097, 3109 | A — historia revisada |
| siete acciones no terminales | 3107 | A — historia revisada |
| 46 acuerdos | 3078, 3115 | A — historia revisada |

Las búsquedas de confirmación directa expresada en prosa se contrastaron además con `ARCH-004:3371–3491`: allí se remite a IF→IF/ID→ID y al acuerdo 47. Las referencias vigentes a 47 acuerdos y ocho acciones están en decisions:3135,3265; plan:31,937,1991 y requirements:165. Las frases históricas de control «todavía pendiente» dentro de acuerdos 1–46 se leen con el aviso global; no se extrapolan a requisitos actuales.

El archivo `docs_audit.md` contiene muchas menciones literales antiguas dentro de bloques HTML de historia desde :79–85: **A**, no nuevas autorizaciones. Su tabla vigente :69 cuenta 17 apariciones de «IF excepcional», pero enumera 16 líneas y la búsqueda actual encuentra 16; es una imprecisión menor del inventario anterior, sin cambio funcional. No se usa ese conteo como prueba de cierre. La referencia al cierre gráfico anterior describe una versión retirada por migración a draw.io; AUD2-001 ya no se considera un defecto activo. Las expectativas end-to-end de stalls durante drain son **C** de cobertura, AUD2-002.

Para cycle_count no queda vigente un pendiente de ancho/overflow: SYS-006:452–470 y su propagación lo fijan. El pendiente UART es legítimo. `plan:1868` pide retener sin fire, pero `:1870` establece expresamente que reset/inicialización prevalecen; se interpretan juntos, sin afirmar que mantenimiento inicial conserve un máximo antiguo.

Los Mermaid presentes son vistas de fases, flujo de información, pipeline conceptual, UART o herramientas. No describen la excepción antigua ni aparentan ser el datapath completo con arbitraje vigente. La omisión de back-edges/flush en un esquema conceptual no se eleva por sí misma a fallo funcional. El SVG anterior se eliminó deliberadamente; el nuevo diagrama externo de draw.io no fue revisado.

## 12. Preguntas que necesariamente requieren decisión humana

**Ninguna nueva elección arquitectónica es necesaria para corregir AUD2-002. AUD2-001 fue retirado tras la aclaración del autor.** Las tres resoluciones humanas anteriores bastan para el contrato CPU auditado. No se reabre ancho/overflow de contador, precisión de fetch ni aritmética de dirección.

Siguen siendo decisiones futuras ya registradas —no hallazgos nuevos— DEC-SYS-007 (servicios UART), DEC-SYS-009 (assembler), DEC-ARCH-009 (representación externa), DEC-SYS-005 (memoria utilizada), DEC-PROTO-001/002/003 y DEC-SYS-008 (software PC). Sus elecciones corresponden al equipo en los hitos existentes. Esta auditoría no eligió baud, framing, endianness UART, captura de snapshot ni comandos adicionales.

## 13. Áreas suficientemente cerradas para diagramar

- Datapath RV32 de cinco etapas y los campos funcionales de los cuatro latches.
- Dos muxes de forwarding y bypass WB→ID, con dato de store separado y disponibilidad de load.
- Control EX de branch/jumps, PC relativo/JALR, link y Result MUX.
- Candidato IF, transporte IF/ID, confirmación ID/EX, metadata y ocho acciones del acuerdo 47.
- FSM global de 14 estados y bloque separado de autorización, explicitando el flanco prepare_done.
- Interfaces conceptuales de memorias independientes, chequeo ensanchado, valid por byte de referencia y efecto síncrono de stores.
- Contador unsigned 64 bits, enable único y prioridad de inicialización.

No es necesario resolver UART para dibujar esos bloques. La lámina debe mostrar qué es combinacional, qué es registro y cuáles son señales preflanco. Debe representar drain_load_use como rama conservada del contrato sin sugerir que existe un programa legal que llegue a ella. La arquitectura de captura Debug y las FSM privadas de preparación/Loader solo pueden representarse por interfaces aprobadas, no como detalles ya elegidos.

## 14. Riesgos y trabajo antes de RTL

1. Corregir la cobertura imposible/ambigua de AUD2-002. No cambiar las ocho acciones para lograr un cover artificial. AUD2-001 no exige restaurar artefactos; el nuevo diagrama de draw.io se revisará como entregable independiente.
2. Consolidar diagramas e interfaces revisables por módulo conforme a `plan:37–48,129–136,338–340,459–461`. Hoy no existen los entregables detallados architecture/pipeline/interfaces en el árbol; su ausencia es trabajo planificado, no una contradicción nueva de política.
3. Llevar a assertions RTL las hipótesis que hacen válidas las pruebas: flags IF/ID excluyentes; controles legales con valid; consumidores de load no disponible inalcanzables en EX; D/E vacíos durante drain; metadata de fault única; equivalencia de enable de datos y valid.
4. Materializar prepare_done como certificado de estado **ya** preparado y sin writes concurrentes. Si se deriva del «último write que ocurrirá en este mismo flanco», se pierde el primer fetch correcto o se mezclan inicialización y CPU. Esa implementación sería contraria al contrato.
5. Evitar anchos implícitos/signados en constantes y sumas de capacidad. El test de Python usa enteros sin overflow accidental; SystemVerilog puede truncar antes de comparar. Verificar 33 bits en extremos y 64 en contador.
6. Verificar temporalmente RAM/RF inferidos, lectura combinacional, bypass, atomicidad de metadata y zero lógico. El modelo lógico no demuestra inferencia ni timing a 50 MHz.
7. Implementar un oráculo y regresión persistentes del proyecto cuando se autorice esa fase. Los scripts temporales de auditoría no son el testbench de entrega. Medir cobertura alcanzable y distinguir pruebas por inyección.
8. Respetar pendientes de M2/M3/M4 y del resto de integración antes de declarar sistema completo congelado. Los ocho ADR abiertos no impiden toda actividad del núcleo, pero sí impiden anunciar cerradas sus interfaces externas.

### Reproducibilidad y límites de esta pasada

Solo se crea `docs_audit_v2.md` en el proyecto. Los scripts y resultados auxiliares están en `/tmp/tp3-audit-v2/`: `check.py`, `contracts.py`, `extra.py`, `traces.json`, `results.json`, `contracts.json`, `extra.json`, `global_edges.py/json` y `wrap.py/json`. Son temporales; su permanencia no se presume. Las trazas, parámetros, límites y conclusiones relevantes se incorporan a este informe. Reejecución en esta sesión: `python check.py`, `python contracts.py`, `python extra.py`, `python global_edges.py`, `python wrap.py` en ese directorio, en ese orden. Los seis wraps dirigidos se describen en §1.

| Fuente de modelo temporal | SHA-256 |
| --- | --- |
| check.py | b55843f05b13363f9d9e20f834e3c711d3b931f0c900dae82c5182ad793f4653 |
| contracts.py | 9c9d69362af5714945c9f8aae5c85a81a50366b564d30ea81ebc76ee4203dda4 |
| extra.py | c926a5da687f4c47b78cc8c0efe3b55d5d8496d22696a3f81a4b6b299ac9ffa6 |
| global_edges.py | e45d68cacf9ac51c63b85cd7cfbe6a52718ba8e3acdd101109890e0dd9cc0460 |
| wrap.py | e807114bcd91599d71c1acaec4c30990c72e077cb17a26273f75949f1d5db3eb |

Se verifican hashes de los archivos originales contra el inventario tomado al comienzo para asegurar que esta pasada no alteró contratos, requisitos, plan, consigna ni informe previo. No se implementó RTL ni software de producto. No se ejecutaron síntesis, timing, CDC, pruebas de FPGA ni pruebas de transporte/snapshot.

## 15. Conclusión explícita

**A. Arquitectura lista para diagramas del núcleo CPU: sí.** Las tres revisiones humanas permiten una representación coherente del datapath, hazards, faults y FSM. No hay un nuevo bloqueo funcional demostrado. El diagrama se desarrolla por separado en draw.io; su revisión queda pendiente sin exigir recuperar la versión LaTeX.

**B. Sistema completo listo para RTL: no acreditado.** Faltan los entregables de interfaces/diagramas revisables y los cierres de integración ya programados (SYS-007 para M2, SYS-009 para M3, ARCH-009 para M4, más Debug/protocolo según su fase). Para RTL de un módulo CPU concreto puede prepararse su contrato de puertos y assertions a partir de estas decisiones; esta auditoría no autoriza declarar completo todo el sistema ni afirma pruebas de hardware que no existen.

**C. Bloqueos concretos:** AUD2-001 queda retirado y no constituye un bloqueo. AUD2-002 impide exigir cobertura end-to-end de stall durante drain como criterio realizable. El diagrama externo de draw.io aún no tiene revisión en esta auditoría. Los pendientes existentes bloquean sus respectivas interfaces externas, no la política CPU ya aprobada. No se necesita una cuarta resolución humana sobre fetch, dirección o contador.

La conclusión funcional es acotada pero adversarial: no apareció un nuevo fallo grave en las ecuaciones vigentes tras probar secuencias multiciclo con valores distintos, oráculo separado, límites y mutaciones. Tras la aclaración del autor, **queda un hallazgo documental abierto: AUD2-002**. La eliminación de los archivos LaTeX/SVG no es un defecto; la nueva versión de draw.io sigue fuera del alcance verificado.
