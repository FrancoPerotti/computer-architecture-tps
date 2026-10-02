# Invariantes arquitectónicas y criterios de verificación

## Función de este documento

Los documentos anteriores describen cómo funciona cada parte de la arquitectura. Las invariantes cumplen otra función: expresan propiedades que permanecen verdaderas cuando esas partes interactúan.

Son especialmente útiles en situaciones donde el comportamiento correcto no pertenece a un único módulo. Por ejemplo, que una instrucción descartada nunca escriba memoria depende de la validez transportada por el pipeline, de la selección de acciones, del control de MEM y de la autorización global del ciclo.

Una invariante resume ese comportamiento transversal en una propiedad verificable.

Las etiquetas `I01` a `I25` permiten referirse a cada propiedad desde assertions, scoreboards, testbenches o revisiones de arquitectura. No agregan decisiones nuevas: condensan contratos ya definidos en los documentos de pipeline, hazards, faults, memoria y control de ejecución.

## Qué clase de propiedades aparecen

Las invariantes se agrupan en cuatro familias: seguridad, coherencia temporal, precisión y alcanzabilidad. Salvo indicación contraria, describen ejecuciones alcanzables desde RESET y una preparación válida. Los valores utilizados por un efecto corresponden al estado anterior al flanco y el resultado registrado se observa después del flanco.

Las propiedades que implican progreso —por ejemplo, que trabajo anterior termine de drenar— presuponen que en el futuro se autorizan los ciclos necesarios y que RESET o un LOAD aceptado no abandonan la sesión antes.

---

# Validez y efectos arquitectónicos

La primera familia establece una regla central del pipeline: **solo el trabajo válido y autorizado produce efectos arquitectónicos**.

Los bits almacenados en una etapa pueden conservar residuos cuando su `valid=0`, pero esos residuos no representan una instrucción activa.

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I01` | Una entrada inválida no produce efectos normales | `valid=0` excluye writeback, store, forwarding como productor o consumidor y eventos propios de esa instrucción. `IF/ID.fetch_fault_valid` constituye una validez separada para el candidato de fetch y nunca convierte la word residual en una instrucción activa. |
| `I02` | Las instrucciones del camino descartado no producen efectos | Una instrucción posterior descartada por redirect no escribe RF o DMEM, no provoca la confirmación de `halt` o fault y no altera metadata. La invalidación también elimina un candidato de fetch posterior. |
| `I03` | La causante de un fault no produce efectos normales | Un fault confirmado en ID impide que la causante entre válida a ID/EX. Un fault confirmado en EX impide que entre válida a EX/MEM. No aplica redirect, enlace, store ni writeback posterior. |
| `I04` | Las instrucciones anteriores a `halt` o fault conservan sus efectos | Un store o writeback anterior puede hacer commit en el mismo ciclo en que se confirma el fault o `halt` de una instrucción posterior. Una instrucción anterior en EX también continúa cuando el fault se confirma en ID. |
| `I05` | Las instrucciones posteriores a `halt` o fault se descartan | Al confirmar `halt` o fault se descartan las instrucciones posteriores, y durante drain no se admite trabajo nuevo. |

Un redirect, `halt` o fault de una instrucción posterior no impide el commit de una anterior. Por ejemplo, pueden ser verdaderos en el mismo ciclo `dmem_store_fire=1` y `halt_confirm=1` si el store de MEM es anterior al `halt` de EX. Son efectos de instrucciones distintas, ordenados de acuerdo con el programa.

---

# Commit único de registros y memoria

Los efectos arquitectónicos permanentes tienen predicados de commit explícitos.

Los predicados de commit se definen en [WB para el Register File](stage_wb.md#condición-efectiva-de-writeback) y en [MEM para stores](stage_mem.md#dmem-write-control). Estas invariantes verifican su aplicación sobre cada instancia dinámica de instrucción.

Las propiedades correspondientes son:

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I06` | Cada store dinámico hace commit como máximo una vez | `dmem_store_fire` requiere ciclo efectivo, `EX/MEM.valid` y una operación store. HOLD no repite la escritura y el avance consume la entrada correspondiente. |
| `I07` | Cada writeback dinámico hace commit como máximo una vez | `rf_write_fire` requiere ciclo efectivo, `MEM/WB.valid`, `reg_write` y `rd!=0`. El valor escrito es el `wb_value` anterior al flanco. |

La identidad utilizada en estas comprobaciones es la **instancia dinámica** de la instrucción. El PC por sí solo no alcanza para distinguir iteraciones de un loop.

`x0` permanece siempre en cero. Esto se refleja simultáneamente en la ausencia de writeback, forwarding, bypass WB→ID y dependencias `load-use` causadas por `rd=0`.

---

# Ciclo efectivo y HOLD

Los efectos de CPU están subordinados a `cpu_cycle_fire`.

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I08` | Cada ciclo de la CPU incrementa una vez `cycle_count` | Con `cpu_cycle_fire=1`, y sin una acción global superior, `cycle_count.next=(cycle_count+1) mod 2^64`. Esto incluye avance normal, stall, redirect, confirmación de `halt` o fault y drain. |
| `I09` | Sin ciclo efectivo no existe avance CPU | Con `cpu_cycle_fire=0`, PC, registros interetapa, RF, commits CPU y contador permanecen estables, salvo RESET o preparación con autoridad propia. |
| `I10` | Un STEP aceptado produce exactamente un ciclo de la CPU | Desde `READY`, `STEPPING` o drain STEP el ciclo ocurre en el flanco de aceptación. Desde un terminal queda pendiente durante preparación y ocurre con `prepare_done`. |

Un stall `load-use` satisface `I08` e `I10`: retiene parte del pipeline, pero sigue siendo un ciclo efectivo. HOLD satisface `I09`: puede existir actividad de UART, Loader o Debug, pero no ejecución de la CPU.

---

# Exclusión y cobertura de las acciones del pipeline

Durante un ciclo de la CPU, `Pipeline Hazard Control` selecciona una única forma coherente de actualizar el pipeline.

Fuera de drain, la prioridad es:

```text
EX fault
    >
halt EX
    >
redirect EX
    >
ID fault
    >
load-use
    >
normal
```

Durante drain existen dos ramas contractuales: `drain_load_use` y `drain_advance`.

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I11` | Cobertura de acciones fuera de drain y estados terminales | Si existe `cpu_cycle_fire` y no se ha confirmado previamente `halt` o fault, exactamente una de `act_ex_fault`, `act_halt`, `act_redirect`, `act_id_fault`, `act_load_use` o `act_normal` queda activa. |
| `I12` | Cobertura de acciones de drain | Si existe ciclo efectivo con drain activo, exactamente una de `act_drain_load_use` o `act_drain_advance` queda activa. |
| `I13` | Las ocho acciones son `onehot0` | En cualquier instante hay cero o una acción activa. Sin ciclo autorizado o con un terminal ya vacío, todas permanecen en cero. |

La forma compacta de la propiedad es:

```text
$onehot0({
    act_ex_fault,
    act_halt,
    act_redirect,
    act_id_fault,
    act_load_use,
    act_normal,
    act_drain_load_use,
    act_drain_advance
})
```

---

# Dependencias de datos

Las invariantes de forwarding garantizan que EX utilice la versión arquitectónicamente más reciente de cada operando.

Si EX/MEM y MEM/WB coinciden con la misma fuente, EX/MEM corresponde al productor más reciente:

```text
EX/MEM > MEM/WB > valor base ID/EX
```

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I14` | El productor más reciente domina | Para una fuente realmente utilizada, una coincidencia cualificada en EX/MEM oculta una coincidencia en MEM/WB. `rd=0` y fuentes no utilizadas no crean dependencia. |
| `I15` | Un load todavía no disponible no permite utilizar una versión anterior | `forward_memwb` se bloquea con `exmem_match`, no solamente con `forward_exmem`. Si EX/MEM contiene el load productor más reciente, un valor más viejo de MEM/WB nunca lo reemplaza. |

La segunda propiedad evita un error sutil. Para un load, `EX/MEM.ex_result` contiene la dirección efectiva, no el dato cargado. Ese valor no puede reenviarse como `rd`, pero tampoco puede sustituirse por una versión anterior del mismo registro que permanezca en MEM/WB.

La ejecución legal evita consumir el operando en ese estado mediante el stall `load-use`.

## Alcanzabilidad del caso load-use

Una ejecución legal no deja después de un flanco la combinación `EX/MEM = load productor` e `ID/EX = consumidor inmediato dependiente`.

El ciclo anterior detecta la dependencia mientras el load está en ID/EX y el consumidor en IF/ID. `act_load_use` retiene PC e IF/ID, introduce una bubble en ID/EX y permite que el load avance. Por eso el consumidor no alcanza EX mientras el load recién se encuentra en MEM.

HOLD conserva esta propiedad y las demás acciones que dejan avanzar al load también insertan una bubble o descartan el consumidor. No aparece un segundo interlock en EX para corregir una combinación que la arquitectura ya vuelve inalcanzable.

---

# Precisión de redirects, faults y `halt`

La precisión depende del orden de las instrucciones en el programa, además del tipo de evento.

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I16` | Los faults respetan el orden del programa | Confirmar un fault o `halt`, o aplicar un redirect en EX, tiene prioridad sobre confirmar un candidato en ID. La prioridad `misalignment > access fault` se aplica únicamente entre causas de una misma operación. |
| `I17` | Un fetch fault del camino descartado nunca se confirma | IF solo detecta y transporta el candidato. La confirmación ocurre en ID; un fault, `halt` o redirect de la instrucción anterior en EX descarta el candidato antes de que modifique el estado terminal. |
| `I18` | Stall, bubble y flush conservan las instrucciones que deben continuar | Un stall conserva el consumidor y permite avanzar a las instrucciones anteriores; un flush elimina exactamente las instrucciones que deben descartarse según la acción seleccionada. |
| `I19` | `pipeline_empty_next` representa los cuatro `valid` posteriores | Se calcula usando `valid_next` de IF/ID, ID/EX, EX/MEM y MEM/WB. No depende de datos residuales ni de `fetch_fault_valid`. |
| `I20` | El control combinacional permanece acíclico | La información fluye desde estado actual hacia aceptación, autorización, acción, valores `next`, `pipeline_empty_next` y finalmente `next_state`. `next_state` no realimenta el ciclo actual. |

La instrucción que provoca un fault se descarta antes de llegar a la etapa donde produciría su efecto: un fault en ID impide su entrada válida a EX y un fault en EX impide su entrada válida a MEM. Mientras tanto, una instrucción anterior puede hacer commit de su escritura en RF desde MEM/WB o en DMEM desde EX/MEM en ese mismo flanco.

No existe rollback: la precisión se obtiene descartando la instrucción que provoca el fault y las posteriores, y conservando los efectos de las anteriores.

---

# Alcanzabilidad del drain

En cualquier drain alcanzable desde una sesión legal se cumple:

```text
IF/ID.valid             = 0
IF/ID.fetch_fault_valid = 0
ID/EX.valid             = 0
load_use_stall          = 0
```

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I21` | Un drain legal contiene únicamente instrucciones anteriores en las etapas finales | Después de confirmar `halt` o fault solo pueden permanecer instrucciones válidas en EX/MEM o MEM/WB. Con ciclo efectivo, el comportamiento alcanzable utiliza `act_drain_advance`. |

Confirmar `halt` o fault invalida IF/ID e ID/EX y descarta las instrucciones que no deben continuar. HOLD conserva ese estado y los ciclos posteriores solo permiten avanzar a las instrucciones anteriores.

`act_drain_load_use` forma parte del contrato combinacional de las ocho acciones, pero no aparece en una ejecución legal desde RESET. Su verificación utiliza un estado artificial que fuerce simultáneamente drain activo, un load válido en ID/EX y un consumidor dependiente en IF/ID. Ese test comprueba la lógica de la rama, no su alcanzabilidad end-to-end.

---

# Metadata de fault

La causa y el PC de un fault sobreviven al drain para que el estado terminal pueda observarlos.

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I22` | La metadata de fault se captura una sola vez por sesión | Solo `fault_capture_fire` escribe `fault_cause` y `fault_pc`. Una vez activa la fase de terminación, no se confirma otro fault ni `halt`. Los candidatos descartados y HOLD no modifican el par. |

La captura es:

```text
fault_capture_fire = fault_confirm
```

Si el fault se confirma en EX, el PC proviene de `ID/EX.pc`. Si se confirma en ID, proviene de `IF/ID.pc`.

La validez de esa información se deriva del estado global de fault, no del contenido aislado de los registros.

---

# Memoria y atomicidad

La arquitectura valida una región completa antes de indexar la memoria.

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I23` | Un acceso cubre todos sus bytes sin aliasing por truncamiento | La dirección efectiva se forma módulo `2^32`, pero `EA+N` se calcula y compara con aritmética unsigned de 33 bits antes de indexar. |

La [validación de toda la región](memory_architecture.md#validación-de-toda-la-región) usa la dirección efectiva modular y un extremo ensanchado; no reemplaza la comprobación de alineación.

Un store que falla alineación o rango no modifica ningún byte. Para un store válido, `dmem_metadata_write_fire = dmem_store_fire`; los bytes seleccionados actualizan conjuntamente dato y validez y los demás conservan ambos valores.

Esto mantiene la atomicidad observable de `SB`, `SH` y `SW`.

---

# Imagen, preparación y aislamiento entre sesiones

Una imagen parcialmente recibida nunca se vuelve ejecutable.

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I24` | Una imagen cargada parcialmente nunca se ejecuta | LOAD aceptado coloca el tamaño confirmado en cero. `load_ok` conserva todavía el tamaño como información privada. La publicación ocurre solamente después de la preparación completa en `PREPARING_READY`. |

`PREPARING_RUN` y `PREPARING_STEP` reutilizan una imagen ya confirmada. En ambos casos, `prepare_done=1` significa que el estado inicial está listo antes del flanco y que no existe una escritura de preparación concurrente con el primer ciclo de la CPU.

La separación entre imagen y sesión evita ejecutar una carga parcial y también evita continuar accidentalmente el estado de una sesión terminal anterior.

---

# Observación coherente

El estado observado externamente corresponde a una única situación lógica del procesador.

| ID | Propiedad | Criterio verificable |
|---|---|---|
| `I25` | La observación mantiene coherencia e aislamiento de sesión | Un snapshot no mezcla estados pertenecientes a momentos distintos ni presenta residuos de una sesión anterior como actuales. Los bytes no escritos de DMEM se observan como cero lógico y los agentes incompatibles no usan simultáneamente el mismo recurso. |

El significado y la coherencia observables se describen en [Arquitectura de Debug](debug_architecture.md); la representación externa concreta sigue en sus decisiones pendientes. Esta invariante fija únicamente la coherencia que esa representación conserva.

---

# Dependencias combinacionales

La organización del control conserva el siguiente sentido de dependencias:

```text
estado y latches actuales
        ↓
elegibilidad y aceptación de comandos
        ↓
solicitudes de ciclo y cpu_cycle_fire
        ↓
confirmaciones y acción del pipeline
        ↓
enables y valores next de PC/latches
        ↓
pipeline_empty_next
        ↓
next_state
```

`next_state` se captura en el flanco y no participa de la autorización o selección del ciclo que lo produjo.

Asimismo, WB→ID puede depender de `cpu_cycle_fire`; los candidatos de ID dependen de la word y de sus flags, no del valor después del bypass; DMEM combinacional alimenta el resultado de MEM, no un consumidor EX del mismo ciclo; y las escrituras de RF y DMEM ocurren en el flanco y no se transforman en nuevos productores combinacionales de ese mismo ciclo.

Estas relaciones sirven como guía para detectar lazos combinacionales cuando exista el RTL.

---

# Cobertura mínima derivada

Las invariantes anteriores se reflejan en familias de pruebas.

| Familia | Casos representativos |
|---|---|
| Forwarding | EX/MEM, MEM/WB, operandos provenientes de productores distintos, productores consecutivos sobre el mismo `rd`, load ocultando un productor viejo, WB→ID y `x0`. |
| Load-use | Consumidor ALU, branch, JALR, load y ambas fuentes de store; STEP consumido por stall; productor con fault. |
| Redirect | Branch tomado/no tomado, JAL/JALR, trabajo wrong-path y candidato de fetch posterior. |
| Faults | Siete causas, prioridad EX sobre ID, misalignment frente a access fault, fault con store/writeback anterior y metadata estable durante drain. |
| `halt` | `halt` wrong-path, confirmación en EX, drain con trabajo anterior y terminación directa con pipeline vacío. |
| RUN / STEP / HOLD | Primer ciclo, STEP único, stall que consume STEP, cambio STEP→RUN, drain STEP, conversión a AUTO y HOLD sin commits repetidos. |
| Sesión | RESET, LOAD aceptado, `load_fail`, imagen nueva más corta, reutilización de imagen desde terminal y primer ciclo con `cycle_count: 0→1`. |
| Memoria | Perfiles `REFERENCE` y `ALT_1000`, límites de byte/halfword/word, carry modular de EA, extremo ensanchado, atomicidad de stores y cero lógico. |
| Contador | Valores cercanos a wrap y wrap durante distintos tipos de acción sin modificar control ni estado terminal. |
| Drain | End-to-end para `I21`; prueba artificial separada para `act_drain_load_use` sin atribuirle alcanzabilidad legal. |

---

# Resumen de invariantes

| ID | Propiedad |
|---|---|
| `I01` | Una entrada inválida no produce efectos normales. |
| `I02` | El trabajo wrong-path no produce efectos. |
| `I03` | La causante de fault no produce efectos normales. |
| `I04` | Las instrucciones anteriores a `halt` o fault conservan sus efectos. |
| `I05` | Las instrucciones posteriores a `halt` o fault se descartan. |
| `I06` | Cada store dinámico hace commit como máximo una vez. |
| `I07` | Cada writeback dinámico hace commit como máximo una vez. |
| `I08` | Cada ciclo de la CPU incrementa una vez `cycle_count`. |
| `I09` | Sin ciclo efectivo no existe avance CPU. |
| `I10` | Un STEP aceptado produce exactamente un ciclo de la CPU. |
| `I11` | Las acciones cubren todo ciclo fuera de drain y estados terminales. |
| `I12` | Las dos ramas de drain cubren el contrato de drain. |
| `I13` | Las ocho acciones cumplen `onehot0`. |
| `I14` | El productor más reciente domina el forwarding. |
| `I15` | Un load reciente no permite utilizar una versión vieja. |
| `I16` | Los faults respetan el orden del programa. |
| `I17` | Un fetch fault del camino descartado nunca se confirma. |
| `I18` | Stall, bubble y flush conservan las instrucciones que deben continuar. |
| `I19` | `pipeline_empty_next` representa los cuatro `valid_next`. |
| `I20` | El control combinacional permanece acíclico. |
| `I21` | El drain legal contiene únicamente trabajo anterior en EX/MEM y MEM/WB. |
| `I22` | La metadata de fault se captura una sola vez. |
| `I23` | Los accesos de memoria validan toda su región sin aliasing. |
| `I24` | Una sesión parcial nunca ejecuta. |
| `I25` | La observación mantiene coherencia e aislamiento entre sesiones. |

## Trazabilidad

- [Pipeline CPU](cpu_pipeline.md): validez, registros interetapa y avance.
- [Control del pipeline y hazards](control_and_hazards.md): acciones, forwarding, load-use y redirects.
- [Faults, redirects y terminación](faults_and_termination.md): precisión, metadata y drain.
- [Arquitectura de memoria](memory_architecture.md): rango, atomicidad, imagen y cero lógico.
- [Control de ejecución y sesión](execution_control.md): `cpu_cycle_fire`, STEP, HOLD, preparación y estados terminales.
- [Arquitectura de Debug](debug_architecture.md): snapshot y observación externa.
