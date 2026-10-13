### DEC-ARCH-001 — Organización y comportamiento de las memorias

**Contrato vigente de consulta:** [memory_architecture](../architecture/memory/memory_architecture.md), [loader](../architecture/session/loader.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** CPU / Memorias

**Fecha de aprobación:** 2026-09-21

**Contexto:** Las capacidades de `Instruction Memory` y `Data Memory` aprobadas en `DEC-SYS-004` deben transformarse en un contrato arquitectónico inequívoco. Para ello se deben definir:

- la unidad de direccionamiento;
- el mapa lógico;
- el punto de entrada;
- la relación entre capacidad e imagen cargada;
- los límites de acceso;
- la concurrencia mínima;
- las restricciones de parametrización;
- el orden de bytes;
- la representación de validez de una imagen.

La organización debe preservar la reinicialización lógica y el fallo cerrado establecidos por `DEC-SYS-003`, distinguir faults de la finalización normal de `DEC-SYS-001` y `DEC-SYS-002`, y evitar que decisiones de conveniencia física se conviertan en restricciones arquitectónicas innecesarias.

**Opciones consideradas:**

1. Direccionamiento por palabras o direccionamiento por bytes.
2. Un único espacio de memoria o espacios Harvard lógicamente independientes.
3. Truncar direcciones fuera de rango, permitir wrap-around o validar explícitamente la región completa de cada acceso.
4. Exigir memorias multiport o definir solamente ownership y demanda lógica mínima.
5. Admitir cualquier capacidad positiva, exigir potencias de dos, exigir múltiplos de cuatro o fijar únicamente el perfil de referencia.
6. Utilizar little-endian, big-endian u órdenes diferentes entre `Instruction Memory` y `Data Memory`.
7. Representar la imagen cargada mediante borrado físico, un bitmap por instrucción o un prefijo contiguo descrito por tamaño y validez global.

**Decisión:** Se adopta el siguiente contrato integral.

#### Unidad direccionable, mapa y punto de entrada

`Instruction Memory` y `Data Memory` serán arquitectónicamente **byte-addressed**. El PC, los destinos de control y las direcciones efectivas de loads y stores representarán posiciones medidas en bytes.

El ISA soportado contiene únicamente instrucciones de 32 bits y no incluye instrucciones comprimidas. Por ello, el flujo secuencial avanzará mediante `PC + 4` y cada fetch obtendrá una instrucción completa de 32 bits.

Los accesos de `Data Memory` tendrán las siguientes granularidades:

- `lb`, `lbu` y `sb`: 1 byte;
- `lh`, `lhu` y `sh`: 2 bytes;
- `lw` y `sw`: 4 bytes.

El sistema utilizará una arquitectura **Harvard lógica**, con espacios independientes para `Instruction Memory` y `Data Memory`:

```text
IMEM_BASE   = 0x00000000
DMEM_BASE   = 0x00000000
ENTRY_POINT = 0x00000000
```

El mismo valor numérico de dirección podrá identificar simultáneamente posiciones distintas de IMEM y DMEM sin aliasing entre ambos espacios.

Los rangos lógicos se derivarán de las capacidades configuradas:

```text
0 <= imem_address < IMEM_CAPACITY_BYTES
0 <= dmem_address < DMEM_CAPACITY_BYTES
```

En el perfil de referencia, IMEM ocupa `0x00000000` a `0x000003FF`, sus comienzos alineados de instrucción llegan hasta `0x000003FC`, y DMEM ocupa `0x00000000` a `0x000007FF`. Estos valores no serán constantes universales.

Después de una carga exitosa, el PC quedará preparado en `0x00000000` sin iniciar automáticamente `RUN` ni `STEP`. No se requiere un punto de entrada configurable.

#### Validación de rango y faults de memoria

**Aclaración aprobada de AUD-004 (2026-09-26):** la generación de la dirección efectiva y la validación de su región son dos sumas distintas. Para loads/stores, con el inmediato con signo extendido a 32 bits y el operando tras forwarding:

```text
effective_address = (rs1_effective + immediate) mod 2^32
```

La primera suma sigue la aritmética arquitectónica de 32 bits. **El carry de `rs1 + immediate` no constituye por sí mismo un fault**; el resultado modular es la dirección arquitectónica que se comprueba. La prohibición de wrap-around/aliasing al acceder a memoria se aplica a la región y a la indexación física, no a esta generación de dirección.

La validez de rango se comprobará después sobre todos los bytes del acceso, antes de transformar la dirección arquitectónica en un índice interno. Para DMEM, con `N=1/2/4` bytes, se exige:

```text
{1'b0, effective_address} + N <= DMEM_CAPACITY_BYTES
```

Esta segunda suma y la comparación son sin signo y ensanchadas a **33 bits**, con `N` y la capacidad representados sin truncamiento; pueden representar el límite exclusivo `2^32` y detectar un extremo que lo exceda. No se reduce `effective_address + N` módulo `2^32`. En forma general, para IMEM o DMEM se verifica con esa aritmética ensanchada una condición equivalente a:

```text
address + N <= CAPACITY_BYTES
```

o `address <= CAPACITY_BYTES - N` bajo las precondiciones correspondientes.

Un fetch candidato será válido por rango únicamente si sus cuatro bytes se encuentran dentro de IMEM y pertenecen a la imagen confirmada. La alineación se verificará separadamente conforme a `DEC-ARCH-004`.

Una posición dentro de capacidad pero fuera de la imagen no expondrá una instrucción residual, no se interpretará como `halt` ni entregará una instrucción ejecutable. Un fetch fuera de imagen o capacidad generará un candidato de fault.

Cada byte de DMEM dentro de capacidad que no haya sido escrito durante la sesión devolverá cero lógico conforme a `DEC-SYS-003`. Loads y stores validarán todos los bytes antes de acceder:

- un store inválido no modificará ningún byte;
- un load inválido no escribirá `rd`;
- no habrá efectos parciales, wrap-around de la región ni aliasing por truncamiento al formar índices físicos; se conserva el wrap arquitectónico normal al generar la dirección efectiva.

Un candidato de fault solo se convertirá en fault arquitectónico si la operación pertenece al flujo válido. Si una instrucción anterior descarta la operación por branch, jump, `halt` u otra causa, el candidato también se descartará.

Un fault aceptado será distinto de `FINISHED`. La operación causante y todas las instrucciones posteriores carecerán de efectos arquitectónicos. El tratamiento de anteriores, detección, prioridad y detención está fijado por `DEC-ARCH-004` y los acuerdos 40–47 de `DEC-ARCH-003`; el reporte externo corresponde a protocolo.

#### Ownership, puertos y concurrencia

`Instruction Memory` tendrá como agentes conceptuales a la CPU, que realiza fetch, y al loader, que escribe durante carga. No se requerirá acceso simultáneo de ambos sobre la IMEM viva: durante ejecución el loader no escribirá, y durante una carga aceptada no habrá fetch válido ni avance de CPU.

`Data Memory` tendrá como agentes conceptuales a la CPU y a Debug. No se requerirá acceso directo simultáneo sobre la DMEM viva. Debug podrá utilizar exclusión temporal, captura, mirror, shadow storage, un puerto adicional coherente u otro mecanismo equivalente.

La CPU demandará como máximo una solicitud por memoria y ciclo. IMEM y DMEM serán recursos lógicos independientes y deberán poder sostener en el mismo ciclo una solicitud de fetch y una solicitud de load o store, sin introducir un hazard estructural obligatorio por tratarlas como un único recurso no concurrente.

Puertos adicionales, mirrors y shadow storage estarán permitidos, pero no serán requisitos arquitectónicos. Una colisión de ownership prohibida será una violación de invariante interno, no un fault de programa obligatorio.

#### Restricciones y derivaciones de parametrización

La capacidad en bytes será la única entrada autoritativa para cada memoria. Ambas capacidades deberán cumplir independientemente:

```text
4 <= CAPACITY_BYTES <= 2^32
CAPACITY_BYTES % 4 == 0
```

No será necesario que sean potencias de dos. El límite superior ocupa hasta el último offset `0xFFFFFFFF`; el dominio de configuración y cálculo deberá poder representar matemáticamente `2^32`, aunque ese valor no sea una dirección de 32 bits.

Para `Instruction Memory` se derivará:

```text
IMEM_INSTRUCTION_COUNT = IMEM_CAPACITY_BYTES / 4
```

Para `Data Memory`, `DMEM_CAPACITY_BYTES / 4` podrá utilizarse como cantidad lógica de palabras sin imponer una organización física por palabras.

También se derivarán desde la capacidad los límites, anchos de índices, comparadores, contadores, tamaños de metadatos y límites utilizados por loader, Debug, software y testbenches. No existirán parámetros configurables redundantes para propiedades derivables.

Las derivaciones deberán admitir una única palabra sin crear vectores de ancho cero, capacidades no potencia de dos y el límite `2^32`. Cuando una representación exija ancho positivo se utilizará una regla equivalente a `max(1, ceil(log2(element_count)))`.

Se distinguirá una configuración **arquitectónicamente válida** de una configuración **soportada por la implementación**. `DEC-ARCH-006` define `REFERENCE=1024/2048` como perfil físico obligatorio y `ALT_1000=1000/1000` para validar parametrización no potencia de dos mediante elaboración, simulación y smoke tests. Una configuración inválida deberá rechazarse antes de ejecución y una configuración válida pero no soportada deberá producir un error claro de build.

#### Endianness y selección de bytes

`Instruction Memory` y `Data Memory` utilizarán semántica arquitectónica **little-endian**. En todo valor multibyte, la dirección menor contendrá los bits menos significativos.

Una palabra `0x12345678` almacenada desde `A` se representará conceptualmente como:

```text
A + 0 -> 0x78  bits  7:0
A + 1 -> 0x56  bits 15:8
A + 2 -> 0x34  bits 23:16
A + 3 -> 0x12  bits 31:24
```

Por tanto, `lw A` reconstruirá `0x12345678`. `sb` escribirá los ocho bits menos significativos; `sh` y `sw` distribuirán sus bytes desde LSB a MSB en direcciones crecientes. Los loads realizarán la reconstrucción inversa y aplicarán después sign extension para `lb` y `lh`, zero extension para `lbu` y `lhu`, o conservarán los 32 bits para `lw`.

`Instruction Memory` aplicará la misma regla. La instrucción `0x00A585B3` ubicada en `PC = 0x00000000` corresponderá a:

```text
IMEM[0] = 0xB3
IMEM[1] = 0x85
IMEM[2] = 0xA5
IMEM[3] = 0x00
```

y el fetch reconstruirá `0x00A585B3`.

Esta semántica no impone bancos, byte enables ni una organización física específica. Tampoco decide el orden de bytes del protocolo UART: `DEC-PROTO-001` podrá elegir cualquier orden inequívoco, pero loader y software deberán transformarlo para preservar la representación arquitectónica little-endian.

#### Validez y commit de la imagen ejecutable

Toda imagen confirmada será un prefijo contiguo, no vacío y sin huecos de `Instruction Memory`, comenzando en `0x00000000`. Su pertenencia se representará conceptualmente mediante:

```text
image_valid
loaded_image_size_bytes
```

Con una imagen válida se cumplirán:

```text
image_valid = 1
4 <= loaded_image_size_bytes <= IMEM_CAPACITY_BYTES
loaded_image_size_bytes % 4 == 0
loaded_instruction_count = loaded_image_size_bytes / 4
```

Los bytes pertenecientes a la imagen serán:

```text
[0, loaded_image_size_bytes)
```

Como el límite es exclusivo, `loaded_image_size_bytes` deberá poder representar `2^32`. La validez completa de un fetch requerirá una condición equivalente a:

```text
image_valid
AND PC + 4 <= IMEM_CAPACITY_BYTES
AND PC + 4 <= loaded_image_size_bytes
```

con aritmética ensanchada, además de la política de alineación que defina `DEC-ARCH-004`.

No se admitirán imágenes sparse ni múltiples secciones de código discontinuas. No se utilizará ni requerirá un bitmap de validez por instrucción. Que una palabra pertenezca a la imagen no determina si su codificación es legal para el ISA; ese tratamiento corresponde a `DEC-ARCH-004`.

Al aceptar una nueva carga se establecerá conceptualmente:

```text
image_valid = 0
loaded_image_size_bytes = 0
```

El loader escribirá instrucciones secuencialmente desde cero. El progreso de recepción o escritura será estado separado del tamaño confirmado y ninguna escritura parcial habilitará ejecución.

Recibir y validar la imagen completa no bastará para publicarla. Solo después de preparar también DMEM y el restante estado inicial de la nueva sesión se escribirá atómicamente el tamaño recibido. En el cuadragésimo cuarto acuerdo de `DEC-ARCH-003`, `load_ok` deja el tamaño privado del Loader y `PREPARING_READY && prepare_done` realiza ese único commit, sin ejecutar CPU. Ese único write no nulo constituirá el commit completo y hará que `image_valid = 1` por derivación. Una carga vacía, truncada, inválida, sobredimensionada o fallida conservará el tamaño en cero y mantendrá `RUN` y `STEP` inhabilitados hasta una carga válida posterior.

No se exige rollback, restaurar la imagen anterior, borrar físicamente IMEM ni utilizar doble buffer. Si un programa nuevo es más corto, el contenido residual posterior al límite confirmado será irrelevante y no ejecutable.

`loaded_image_size_bytes` es estado conceptual necesario para determinar pertenencia, pero no será un campo obligatorio del snapshot mínimo de Debug.

La organización física, inferencia, latencia, ownership, metadatos y perfiles se definen en `DEC-ARCH-006`. La polaridad, estrategia temporal, semántica y prioridades de `reset` y enables se definen en `DEC-ARCH-008`, sin imponer señales o secuencias RTL concretas. La alineación, codificaciones inválidas y prioridad entre errores están aprobadas en `DEC-ARCH-004`.

**Justificación:** El direccionamiento por byte y little-endian mantienen coherencia con RV32I y permiten una única semántica para instrucciones y datos. Los espacios Harvard independientes permiten atender las demandas lógicas simultáneas de IF y MEM sin exigir una tecnología física concreta.

La validación ensanchada de la región completa evita aliasing, wrap-around de sus bytes y efectos parciales, sin prohibir la generación modular de la dirección efectiva. Admitir capacidades múltiplos de cuatro no potencia de dos evita convertir una simplificación de indexación en una restricción arquitectónica y obliga a preservar comparaciones de rango correctas.

Una imagen como prefijo contiguo satisface los programas requeridos por el TP y permite invalidar limpiamente residuos de imágenes anteriores con dos valores escalares, sin borrar toda IMEM ni mantener metadatos por instrucción. Separar el progreso del tamaño confirmado y publicar la imagen solo al éxito garantiza que una carga parcial nunca se vuelva ejecutable.

**Consecuencias:**

- PC, destinos de control y direcciones de datos se expresan en bytes;
- el flujo secuencial utiliza `PC + 4`;
- IMEM y DMEM son espacios lógicos independientes con base cero;
- el entry point es fijo en `0x00000000`;
- todo acceso valida su región completa antes de indexar memoria;
- un fetch fuera de imagen o capacidad y un acceso DMEM fuera de rango producen candidatos de fault;
- los candidatos del camino incorrecto se descartan;
- la operación causante de un fault y las posteriores no producen efectos arquitectónicos;
- IMEM y DMEM deben sostener simultáneamente las demandas lógicas de IF y MEM;
- no se exigen accesos concurrentes CPU/loader ni CPU/Debug sobre una misma memoria viva;
- las capacidades son múltiplos de cuatro entre 4 y `2^32` bytes y pueden no ser potencias de dos;
- toda propiedad derivable procede de la capacidad autoritativa en bytes;
- IMEM y DMEM son little-endian;
- el endianness UART continúa separado;
- una imagen ejecutable es un prefijo contiguo no vacío desde cero;
- `image_valid` y `loaded_image_size_bytes` determinan la pertenencia a la imagen;
- una carga aceptada invalida inmediatamente la imagen y pone el tamaño confirmado en cero;
- tamaño y validez se publican atómicamente solo al completar exitosamente la carga;
- no se soportan imágenes sparse ni se requiere bitmap de validez por instrucción;
- no es necesario borrar físicamente el sufijo residual de IMEM;
- pertenencia a la imagen y legalidad de la codificación ISA son conceptos distintos;
- alineación y clock están aprobados en `DEC-ARCH-004` y `DEC-ARCH-005`; el protocolo detallado permanece pendiente; `reset` y enables se fijan semánticamente en `DEC-ARCH-008` y la implementación física de memorias en `DEC-ARCH-006`.

**Requisitos afectados:** `REQ-CPU-003`, `REQ-CPU-004`, `REQ-CPU-006`, `REQ-CPU-007`, `REQ-CPU-011`, `REQ-CPU-014`, `REQ-CPU-016` a `REQ-CPU-018`, `REQ-ISA-001` a `REQ-ISA-006`, `REQ-ISA-018` a `REQ-ISA-022`, `REQ-ISA-032`, `REQ-ISA-033`, `REQ-HAZ-001`, `REQ-MEM-001` a `REQ-MEM-024`, `REQ-EXEC-014`, `REQ-EXEC-017`, `REQ-EXEC-018`, `REQ-DBG-010`, `REQ-DBG-013`, `REQ-DBG-015`, `REQ-DBG-017`, `REQ-DOC-007`.

**Reemplaza / Reemplazada por:** No aplica.

---
