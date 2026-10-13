### DEC-SYS-004 — Capacidades iniciales de memoria

**Contrato vigente de consulta:** [memory_architecture](../architecture/memory/memory_architecture.md), [common_configuration](../architecture/common_configuration.md). Este ADR conserva la aprobación y su evolución; las especificaciones consolidadas incorporan las revisiones aplicables.

**Estado:** Aprobada

**Dominio:** Sistema / Memorias

**Fecha de aprobación:** 2026-09-20

**Contexto:** El sistema requiere una memoria de instrucciones para almacenar los programas cargados y una memoria de datos para soportar las operaciones de acceso a memoria del procesador.

La consigna exige documentar sus capacidades, pero no establece valores concretos. El proyecto necesita, por lo tanto, definir una configuración de referencia reproducible para desarrollo, simulación, síntesis, validación y ejecución sobre FPGA, sin convertir dichos valores en constantes rígidas distribuidas por toda la implementación.

Al mismo tiempo, debe preservarse la posibilidad de sintetizar configuraciones con capacidades diferentes sin modificar la lógica funcional del procesador.

Por `DEC-SYS-003`, la capacidad máxima disponible en `Instruction Memory` es independiente de la cantidad de instrucciones pertenecientes a la imagen actualmente cargada. Una posición físicamente disponible no se considera válida por el solo hecho de encontrarse dentro de la capacidad implementada.

**Opciones consideradas:**

1. Fijar capacidades constantes y hardcodeadas independientemente en cada módulo.
2. Permitir capacidades parametrizables sin establecer una configuración común de referencia.
3. Definir capacidades parametrizables en tiempo de elaboración o síntesis junto con un perfil de referencia aprobado para el TP.
4. Permitir modificar dinámicamente las capacidades de las memorias durante la ejecución.

**Decisión:** Las capacidades de `Instruction Memory` y `Data Memory` son **configurables en tiempo de elaboración o síntesis**, mediante parámetros o una configuración autoritativa equivalente.

Se establece como **perfil de referencia del TP**:

- **`Instruction Memory`:** `1024 bytes` de capacidad lógica;
- **`Data Memory`:** `2048 bytes` de capacidad lógica.

Dado que el conjunto de instrucciones soportado actualmente utiliza instrucciones de 32 bits y no incorpora instrucciones comprimidas, los `1024 bytes` de `Instruction Memory` permiten almacenar como máximo **256 instrucciones** en el perfil de referencia.

Esta equivalencia expresa únicamente capacidad y no impone que la memoria de instrucciones deba organizarse físicamente como un array de palabras de 32 bits.

Las capacidades configuradas permanecerán constantes durante toda la ejecución del bitstream. Modificar dichas capacidades podrá requerir una nueva síntesis e implementación de la FPGA.

Las dimensiones, límites, contadores, comparaciones y demás elementos que dependan de estas capacidades deberán derivarse de una configuración autoritativa y no de constantes numéricas independientes repetidas en distintos componentes.

CPU, memorias, lógica de carga, Debug, protocolo, verificación y software de PC deberán operar con límites coherentes con el perfil sintetizado. El mecanismo concreto mediante el cual dichos componentes compartirán o conocerán esa configuración se definirá posteriormente.

Una imagen de programa que exceda la capacidad configurada de `Instruction Memory` no podrá considerarse cargada exitosamente.

Para el perfil de referencia:

- una imagen de hasta `256` instrucciones puede caber en `Instruction Memory`;
- una imagen de más de `256` instrucciones no puede finalizar con una carga exitosa.

Esta regla define únicamente la condición de capacidad. El mecanismo de detección, la respuesta del protocolo y el código de error correspondiente se definirán posteriormente.

Una imagen más corta que la capacidad máxima solo hará válidas las palabras que efectivamente formen parte de la nueva imagen cargada, conforme a `DEC-SYS-003`. La capacidad no determina por sí sola la validez de las posiciones restantes.

`DEC-ARCH-001` define la granularidad, los anchos derivados y los límites legales de configuraciones alternativas. La política de alineación de cada acceso permanece separada en `DEC-ARCH-004`.

Esta decisión no determina:

- organización interna en bytes o palabras;
- ancho concreto de los buses de dirección;
- direcciones base ni mapa de memoria;
- punto de entrada numérico;
- comportamiento ante accesos fuera de rango;
- cantidad, tipo o arbitraje de puertos;
- lectura síncrona o combinacional;
- utilización de BRAM, RAM distribuida, registros o IP;
- mecanismo físico de inicialización o limpieza;
- representación concreta de validez de instrucciones o datos;
- formato del protocolo de carga o de sus errores.

**Justificación:** Una configuración de referencia concreta permite que simulación, testbenches, síntesis, FPGA y software trabajen sobre límites conocidos y reproducibles.

El perfil de `1024 bytes` de `Instruction Memory` proporciona espacio para hasta `256` instrucciones del ISA actualmente soportado, cantidad suficiente como configuración inicial para programas de prueba, diagnóstico y demostración del trabajo práctico.

Los `2048 bytes` de `Data Memory` proporcionan un espacio de datos razonable para cargas, almacenamientos, arreglos y programas de prueba sin sobredimensionar prematuramente los recursos de FPGA.

Estas capacidades no implican que Debug deba transmitir la memoria completa. La definición de qué posiciones de memoria de datos se consideran utilizadas permanece separada y se resolverá posteriormente.

Parametrizar las capacidades evita que una elección realizada durante esta etapa se convierta innecesariamente en una restricción estructural permanente. Una configuración distinta puede obtenerse mediante elaboración o resíntesis sin exigir cambios en la lógica funcional, siempre que respete las restricciones arquitectónicas que se definan posteriormente.

Derivar límites y dimensiones de una configuración autoritativa reduce además el riesgo de inconsistencias entre RTL, loader, Debug, tests y software.

Finalmente, separar capacidad lógica de organización física evita comprometer anticipadamente una tecnología concreta de memoria antes de analizar recursos, temporización e inferencia sobre FPGA.

**Consecuencias:**

- el perfil oficial de referencia del TP utiliza `1024 bytes` de `Instruction Memory` y `2048 bytes` de `Data Memory`;
- en dicho perfil, `Instruction Memory` tiene capacidad máxima equivalente a `256` instrucciones de 32 bits;
- las capacidades son parámetros de elaboración o síntesis y no variables modificables durante ejecución;
- cambiar las capacidades puede requerir generar un nuevo bitstream;
- reprogramar el contenido dentro de la capacidad ya sintetizada no requiere modificar dicha capacidad;
- los límites dependientes de memoria deben derivarse de una configuración autoritativa;
- no deben mantenerse números mágicos independientes para representar las mismas capacidades en distintos componentes;
- el loader del perfil de referencia no puede confirmar exitosamente una imagen que exceda `1024 bytes` de instrucciones;
- una imagen con menos de `256` instrucciones no convierte automáticamente las posiciones restantes en instrucciones válidas;
- capacidad máxima e imagen válida actual son conceptos diferentes;
- la capacidad total de `Data Memory` es independiente del subconjunto de posiciones que posteriormente se considere utilizado;
- Debug, protocolo, tests y software deberán permanecer coherentes con el perfil sintetizado;
- una configuración alternativa deberá poder obtenerse sin modificar la lógica funcional dependiente únicamente de capacidad;
- la síntesis del perfil de referencia deberá utilizarse posteriormente para evaluar utilización de recursos y timing;
- no se fija todavía organización, direccionamiento, tecnología, puertos, temporización ni representación física de las memorias;
- `DEC-ARCH-001` transforma estas capacidades en una organización y esquema de direccionamiento concretos;
- `DEC-ARCH-006` selecciona el contrato físico inicial, el perfil físico obligatorio y el perfil alternativo de validación;
- las decisiones posteriores de Debug, UART, protocolo y software deberán respetar la capacidad configurada sin asumir que los valores del perfil de referencia son universales.

**Requisitos afectados:** `REQ-MEM-001`, `REQ-MEM-002`, `REQ-MEM-003`, `REQ-MEM-004`, `REQ-MEM-005`, `REQ-MEM-009`, `REQ-MEM-010`, `REQ-MEM-011`, `REQ-MEM-012`, `REQ-EXEC-017`, `REQ-UART-002`, `REQ-DBG-002`, `REQ-SW-004`, `REQ-SW-010`, `REQ-DOC-007`.

**Reemplaza / Reemplazada por:** No aplica.

---
