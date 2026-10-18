# Análisis de costo y beneficio del assembler

- **Tipo:** análisis de alternativas para `DEC-SYS-009`.
- **Estado documental:** análisis de alternativas; elección y diseño completo aprobados en `DEC-SYS-009`.
- **Fecha:** 2026-10-13.

## Objetivo y conclusión

Seleccionar la implementación del [lenguaje assembler](assembler_language.md) que cumpla su contrato con el menor esfuerzo total de desarrollo, verificación, integración, instalación y mantenimiento. El aprendizaje de construir un assembler no se contabiliza como una razón para asumir más trabajo: el criterio prioritario indicado por el usuario es costo y funcionamiento correcto.

**Recomendación original — 2026-10-13:** implementar un assembler propio acotado al lenguaje del TP3, preferentemente en Python con su biblioteca estándar, y utilizar GNU Binutils como referencia independiente durante la verificación de las codificaciones RV32I. GNU no sería una dependencia de ejecución del assembler propio; sí sería una herramienta del entorno de verificación si se adopta esta comprobación. `halt` se comprobaría contra su palabra custom aprobada, no contra una semántica estándar de GNU.

Esta recomendación es una estimación de ingeniería basada en el alcance y en la documentación de las herramientas. No se construyeron implementaciones comparativas ni se midieron horas de desarrollo. La ventaja esperada del assembler propio proviene de que el lenguaje es pequeño y fijo, buena parte de su validación también sería necesaria con herramientas externas y la codificación restante utiliza seis formatos reutilizables. No se afirma que implementar desde cero sea más barato para cualquier assembler.

**Acuerdo posterior al análisis:** el usuario selecciona un assembler propio por el alcance reducido y el costo esperado de adaptación de las alternativas. [DEC-SYS-009](../decisions/DEC-SYS-009.md) conserva los acuerdos parciales y la aprobación del diseño completo. La comparación no demuestra cuál alternativa tiene el menor costo real: el esfuerzo de verificar los encoders propios y el de integrar GNU no fueron medidos. La elección permite continuar el diseño sin atribuir certeza experimental a esa estimación. El acuerdo del 2026-10-14 selecciona Python con biblioteca estándar por el menor esfuerzo de comprensión y desarrollo y la ausencia de requisitos de velocidad de ensamblado. La recomendación original de GNU como herramienta de verificación no se adopta como dependencia: el [catálogo aprobado](assembler_tests.md#expectativas-independientes) utiliza constantes independientes, contrastadas documentalmente con Clang.

**Alcance actualizado — 2026-10-14:** el acuerdo de responsabilidades de `DEC-SYS-009` limita el assembler a traducir. No recibe capacidad ni valida que el programa quepa en IMEM; esa comprobación permanece en FPGA antes de aceptar `LOAD`. Las referencias de este análisis a generación de imagen se refieren a producir los bytes del código, no a acreditar su tamaño para la placa.

## Costos que deben compararse

```text
costo total = validación del lenguaje
            + traducción y generación de la imagen
            + verificación de corrección
            + integración con la aplicación
            + instalación y mantenimiento
```

Se incluyen las pruebas y la resolución de discrepancias: producir una primera salida binaria no basta para considerar completa una alternativa. Todas deben cumplir las condiciones de aceptación del lenguaje, incluidas entradas que se rechazan y programas ensamblables que provocan faults durante la ejecución.

No se pretende atribuir beneficios del RTL, UART o la interfaz visual a una opción de assembler. Esos trabajos son compartidos por el sistema y se realizarán cualquiera sea la alternativa elegida.

### Trabajo común o que no desaparece al reutilizar una herramienta

| Trabajo requerido por el TP                                                             | Assembler propio                                   | GNU / biblioteca                                                                                                                                                                |
|-----------------------------------------------------------------------------------------|----------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Comprobar exactamente la whitelist y las formas explícitas de operandos                 | En el lector/validador propio                      | Capa de validación propia; aceptar RV32I en general no restringe al subconjunto del TP                                                                                          |
| Rechazar pseudoinstrucciones, directivas, expresiones y formas abreviadas               | En el lector/validador propio                      | Filtrado y validación previos a la herramienta                                                                                                                                  |
| Dar a `012` significado decimal y a `0xfff` valor positivo 4095                         | Lectura de literales propia                        | Normalización y validación para conservar el contrato                                                                                                                           |
| Validar registros, alias y límites de inmediatos                                        | Validación propia                                  | La herramienta puede detectar algunos errores; la capa propia debe garantizar los rechazos específicos del TP                                                                   |
| Conocer las direcciones y los límites de desplazamientos de etiquetas                   | Dos recorridos sobre el programa                   | GNU puede resolver símbolos, pero la adaptación debe garantizar rangos y una palabra por instrucción; la numeración propia de instrucciones ya permite calcular sus direcciones |
| Emitir `halt` exacto                                                                    | Una constante de 32 bits                           | Adaptación o extensión custom                                                                                                                                                   |
| Producir instrucciones contiguas desde cero, cuatro bytes little-endian por instrucción | Generación directa                                 | Control de la generación/extracción para respetar la representación                                                                                                             |
| Comprobar que el tamaño sea admisible para IMEM                                         | Se conserva en la FPGA; el assembler no la duplica | Se conserva en la FPGA; el assembler no la duplica                                                                                                                              |
| Informar errores asociados a las líneas originales                                      | Datos conservados por el lector                    | Conservación de líneas y traducción de diagnósticos del código generado cuando corresponda                                                                                      |
| Verificar aceptación, rechazos, etiquetas y bytes finales                               | Necesario                                          | Necesario: las pruebas deben cubrir la adaptación aunque la codificación externa sea fiable                                                                                     |

La capa propia para una herramienta externa no tiene que copiar todo su parser. Puede reconocer solo las formas del TP y producir código normalizado. Pero ese reconocimiento ya comprende la mayor parte de la lectura y de la validación necesarias para un assembler propio de este lenguaje.

## Alternativa A: assembler propio acotado

### Qué se construiría

1. Un lector de líneas y operandos para las formas ya especificadas, conservando la línea original.
2. Tablas de registros/alias e instrucciones admitidas con sus campos fijos, contrastadas con el ISA aprobado.
3. Un primer recorrido que registra etiquetas y asigna PCs mediante `4 * indice`.
4. Un segundo recorrido que resuelve destinos, valida inmediatos y emite las palabras.
5. Codificación reutilizable de los formatos **R, I, S, B, U y J**. Los shifts inmediatos utilizan I con sus bits fijos; `halt` utiliza una constante.
6. Empaquetado little-endian del código traducido. El tamaño frente al perfil se valida en FPGA durante `LOAD`, conforme al acuerdo de responsabilidades.

No se necesita un compilador, un linker, un lenguaje de expresiones, un sistema de secciones, un generador de parsers ni un framework extensible de ISA. Los alias son una tabla de nombres. La cantidad fija de cuatro bytes por instrucción elimina la resolución iterativa de tamaños y desplazamientos.

### Beneficios y costos

El beneficio principal es concentrar el contrato en código pequeño que se ejecuta dentro de la aplicación y produce los bytes requeridos sin procesos ni archivos intermedios obligatorios. No se instala otro assembler para operar el sistema. Las direcciones y los diagnósticos proceden del mismo programa analizado; conservar la relación PC–línea para el diseño posterior de Debug es directo.

El costo específico es escribir y **verificar** la tabla y los seis formatos. Los formatos B y J reparten los bits del inmediato, y los valores negativos, los límites y los shifts merecen comprobaciones independientes. Que la implementación sea breve no demuestra que sea correcta.

La recomendación incluye comparar las codificaciones con una referencia externa y con vectores calculados desde el estándar. No se generarán las expectativas mediante el mismo encoder que se verifica, ni se aceptará como prueba de corrección que assembler y CPU coincidan entre sí.

## Alternativa B: GNU Binutils

### Beneficio real

GNU aporta un assembler establecido, resolución de símbolos, diagnósticos y herramientas para convertir el resultado a un binario. Se evita desarrollar el empaquetado de los campos de cada formato de instrucción. La documentación permite seleccionar ISA, versión de la especificación y endianness, y controlar relajaciones de linker: [opciones RISC-V de GNU as](https://sourceware.org/binutils/docs/as/RISC_002dV_002dOptions.html).

Su ventaja aumenta si se desea aceptar un lenguaje GNU más amplio o trabajar con archivos objeto, múltiples secciones o enlace externo. Esas funciones no forman parte del alcance actual.

### Adaptación necesaria para el lenguaje del TP

- **Restricciones:** seleccionar RV32I no rechaza todas las instrucciones que nuestra CPU omite ni limita las directivas y formas de usuario. La capa propia conserva esa responsabilidad.
- **Literales:** GNU interpreta un entero con cero inicial como octal; el TP define `012` como decimal. Hay que interpretar y normalizar los literales antes de enviarlos. Fuente: [enteros de GNU as](https://sourceware.org/binutils/docs/as/Integers.html).
- **Destinos numéricos:** el TP recibe desplazamientos relativos al PC; GNU utiliza direcciones de destino en los branches. Una entrada numérica no debe pasarse sin adaptar. Esta diferencia y la expansión de branches se explican por los mantenedores en [riscv-gnu-toolchain, issue 637](https://github.com/riscv-collab/riscv-gnu-toolchain/issues/637). Es un antecedente de comportamiento; los detalles de la versión que se integre requieren verificación.
- **Una palabra por instrucción:** controlar relajaciones de linker no demuestra por sí solo que no haya expansiones en el assembler. El adaptador debe validar previamente los desplazamientos y comprobar la longitud final y la relación con las instrucciones originales. No se atribuye a GNU una incompatibilidad inevitable: se contabiliza el trabajo de garantizar el contrato.
- **`halt`:** puede generarse internamente mediante una directiva de instrucción numérica, por ejemplo `.insn 4, 0x0000000B`, con una versión compatible. El usuario continúa escribiendo `halt` y las directivas siguen rechazadas. Fuente: [directivas RISC-V](https://sourceware.org/binutils/docs/as/RISC_002dV_002dDirectives.html).
- **Imagen final:** `objcopy -O binary` permite extraer bytes, pero descarta símbolos y relocaciones. No sustituye la resolución de relocaciones pendientes ni acredita origen cero. La integración debe resolverlas si existen y controlar las secciones/direcciones antes de extraer la imagen. Fuente: [GNU objcopy](https://sourceware.org/binutils/docs/binutils/objcopy.html).
- **Operación de la aplicación:** localizar ejecutables, fijar una versión/configuración soportada, gestionar archivos temporales y procesos, interpretar errores y documentar la instalación en los sistemas usados por el equipo.

Para abaratar GNU se debería partir de binarios o paquetes existentes, no compilar todo el toolchain de GCC. Tampoco se necesita GCC para traducir los programas assembler del TP. Las alternativas de generar `.insn` internamente o de evitar el linker cuando no existan relocaciones son optimizaciones de integración posibles, no razones para asumir que todo el trabajo anterior es inevitable o que ya está resuelto.

### Balance

Se intercambia el costo de seis encoders y sus pruebas por adaptación, manejo de herramientas y pruebas de integración. GNU reduce el riesgo de errores en la codificación base, pero agrega diferencias de semántica de entrada y dependencias de operación. Con el lenguaje actual, el ahorro neto esperado es menor que el costo de esa integración; esta es una valoración de diseño, no una medición.

## Alternativa C: bibliotecas existentes

Se revisaron dos candidatas concretas. La evaluación corresponde a su documentación pública, no a todas las bibliotecas de RISC-V ni a una auditoría o ejecución de sus versiones distribuidas.

| Candidata                                                                         | Beneficio potencial                                                                 | Adaptación o incertidumbre relevante                                                                                                                                                                                                                            |
|-----------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [`riscv-assembler`, de celebi-pkg](https://github.com/celebi-pkg/riscv-assembler) | Python; documenta R, I, S, SB, U y UJ y conversión de programas                     | También admite pseudoinstrucciones y un lenguaje más amplio. Hay que imponer nuestro contrato y comprobar etiquetas, límites y bytes de salida. No se verificó una API de encoder con garantías suficientes para adoptar la biblioteca sin pruebas adicionales. |
| [TinyFive](https://github.com/OpenMachine-ai/tinyfive)                            | Python; documenta funciones de ensamblado y etiquetas, y permite extensiones custom | Su uso documentado ensambla llamadas desde Python sobre el estado/memoria de una máquina y utiliza NumPy. No lee directamente nuestro lenguaje textual; habría que conservar el parser propio y adaptar emisión/extracción o separar código del simulador.      |

Usar solamente los encoders de una biblioteca puede reducir esa adaptación. Sin embargo, hay que comprobar que la API sea utilizable, que la versión elegida codifique correctamente todos los casos requeridos y que el costo de integrar, auditar y distribuir esa dependencia sea menor que el de los seis encoders acotados. La revisión documental realizada no acredita ese ahorro.

No se descartan por ser pequeñas, por tener pocos usuarios o por no soportar `halt` nativamente. Se descartan como primera elección porque no se ha identificado un reemplazo directo del contrato y el beneficio esperado se concentra en una parte reducida de la implementación.

## Comparación de costos marginales

La tabla compara lo que cada alternativa agrega al trabajo común. Las categorías son cualitativas, no horas, porcentajes ni mediciones.

| Aspecto                                     | Propio acotado                                                         | GNU integrado                                                                                                | Bibliotecas revisadas                                                                             |
|---------------------------------------------|------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|
| Trabajo añadido                             | Tabla y seis encoders; resolución simple de símbolos                   | Generación de código normalizado, invocación, resolución/extracción de imagen y diagnósticos de herramientas | Adaptador de API/salida, dependencia y comprobación de compatibilidad; eventualmente correcciones |
| Verificación específica                     | Mayor para los bits de codificación                                    | Menor para la codificación base; mayor para la adaptación y generación final                                 | Compatibilidad de la biblioteca y de su adaptación; calidad aún no acreditada para nuestros casos |
| Instalación para operar el TP               | Python; sin dependencia externa de assembler                           | Binutils para RISC-V además del entorno de la aplicación                                                     | Paquete y dependencias de la candidata elegida                                                    |
| Ajuste al lenguaje                          | Directo                                                                | Requiere restringir y normalizar                                                                             | Requiere restringir o construir la lectura textual                                                |
| Cambios durante el TP                       | Se mantiene un módulo acotado                                          | Se mantiene adaptador y configuración/versión soportada                                                      | Se mantiene adaptador y dependencia; un fork trasladaría también su mantenimiento al equipo       |
| Beneficio de funciones adicionales          | No se desarrollan                                                      | Alto si el alcance crece hacia GNU/ELF; poco aprovechado hoy                                                 | Depende de funciones ajenas al alcance actual                                                     |
| Costo total esperado para el alcance actual | **Menor, condicionado a mantener el alcance y verificar los encoders** | Mayor por la adaptación, aunque con menor riesgo en la codificación base                                     | Ahorro no demostrado; incertidumbre mayor que en las otras opciones                               |

En el entorno consultado está disponible Python y no se encontraron `riscv64-unknown-elf-as`, `riscv64-linux-gnu-as` ni `llvm-mc` en `PATH`. Es un dato local de instalación, no una dificultad general de obtener GNU ni una condición impuesta a los demás integrantes.

## Condiciones para que funcione y para revisar la recomendación

El assembler propio solo se considerará completo al verificar todas las instrucciones y los rechazos del lenguaje, alias, etiquetas adelante/atrás, desplazamientos desde el PC correcto, inmediatos negativos y límites de codificación, formatos B/J, shifts, `halt` y endianness. También deben ensamblarse los programas legales que provocan faults en ejecución. La aceptación debe observar el resultado binario, no solo la ejecución sobre nuestra CPU. La traducción vacía y los programas que exceden IMEM siguen siendo traducibles; sus rechazos por tamaño se comprueban como parte de `LOAD` en FPGA, no como errores del assembler.

GNU se utilizaría en el entorno de verificación para comprobar los casos RV32I después de normalizar las diferencias de entrada identificadas. La comprobación de longitudes debe impedir que una expansión en esa referencia pase inadvertida. Los casos custom y los rechazos propios del TP se verifican por su contrato y por expectativas independientes.

La recomendación debe revisarse si:

- se amplía el lenguaje a pseudoinstrucciones complejas, expresiones, directivas, secciones o enlace de archivos;
- el equipo ya dispone de una integración GNU que cumple este contrato y cuya adaptación resulta menor que el trabajo estimado;
- aparece una biblioteca con encoders comprobados y una API que reduce el trabajo sin introducir reparaciones o dependencias desproporcionadas;
- la implementación propia deja de ser acotada o exige corregir una cantidad de errores que anula el ahorro esperado.

No se propone implementar tres alternativas ni mantener varios backends como precaución. Tampoco se propone escribir primero un assembler completo para averiguar si convenía: la comparación permite seleccionar una dirección de diseño, y la evidencia de implementación posterior deberá confirmar su viabilidad.

## Consecuencias para el diseño que sigue

Esta recomendación reemplaza la preferencia preliminar por GNU expresada antes de analizar el alcance concreto. La razón es costo total para el contrato actual, no preferencia por escribir código propio.

El diseño de la alternativa elegida está aprobado en [DEC-SYS-009](../decisions/DEC-SYS-009.md): responsabilidades e interfaces, etapas de traducción, tabla y fórmulas de codificación, empaquetado, diagnósticos, relación PC–línea, estructuras de datos, catálogo de pruebas y entorno. La validación de capacidad conserva el contrato FPGA. La selección del formato de aplicación sigue siendo `DEC-SYS-008`; elegir Python para el assembler no decide CLI, TUI o GUI.

La implementación permanece posterior al cierre global D0/M6 indicado en el [plan](../plan.md#condición-común-para-comenzar-implementación). Este análisis no acredita un assembler funcionando ni cierra la decisión por sí solo.
