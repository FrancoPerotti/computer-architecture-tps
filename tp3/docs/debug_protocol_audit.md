# TP3 — Revisión del protocolo UART/Debug

**Fecha:** 2026-10-01. **Alcance:** revisión documental V01/V02/V03 de los acuerdos aprobados. Fuente consolidada: [protocol.md](protocol.md). No se implementaron bloques, software ni pruebas de simulación/hardware.

## 1. Recorridos completos — V01

Las secuencias se contrastaron con control de ejecución, memoria, interfaces y acuerdos de protocolo. Los bytes se expresan en hexadecimal; Debug representa el cuerpo completo definido en el documento definitivo.

| Recorrido | Mensajes esperados | Estado y condición de cierre |
|---|---|---|
| Conexión inicial y carga de 32 bytes | `05` → `05 03`; `01 20 00 00 00 00` → `01 01`; 32 bytes → `01 02` | NO_IMAGE es disponible para LOAD. Aceptación y DONE son distintas; imagen publicada solo al commit de preparación, READY sin ejecución automática. Próxima solicitud después de último Stop de DONE. |
| RUN normal después de LOAD | `02` → `02 01`; al terminar `02 0A` + Debug | Aceptación precede final; FINISHED y pipeline vacío después del último commit. Sin stores, respuesta final de 230 bytes con used_count=0. No se fija duración del programa. |
| Primer STEP y observación | `03` → `03 02` + Debug | Un ciclo efectivo, cycle_count=1 en la nueva sesión. Sin stores, respuesta de 230 bytes. No hay aceptación ni consulta Debug separadas. |
| STEP con stall, halt o fault y drenado | Cada `03` → `03 02` + Debug | Stall cuenta un ciclo; halt/fault conservan DONE, distinguidos por global_state. Cada paso de drain avanza un ciclo; el que vacía el pipeline ya muestra FINISHED/FAULT. |
| RUN con fault | `02` → `02 01`; al terminar `02 0B` + Debug | FAULT terminal después de drain, causa y PC globales vigentes. Se distingue de DONE de STEP y de FINISHED de RUN. |
| Nueva sesión de la misma imagen | Desde FINISHED/FAULT, RUN o STEP con sus respuestas anteriores | Preparación restablece PC/RF/DMEM lógicos, latches, contador y memoria utilizada. RUN continúa automáticamente; STEP informa el único primer ciclo. |
| Reprogramación | Consulta READY, nueva cabecera LOAD, aceptación, contenido y DONE | Aceptar invalida imagen/sesión anterior. LOAD rechazada antes de aceptación conserva ambas; una carga aceptada fallida no restaura el programa previo. |
| RESET UART y carga posterior | `04` → `04 01`; luego `05` → `05 03` y LOAD | Reset efectivo después del Stop de aceptación; NO_IMAGE. PC abandona el intercambio anterior. Durante Debug espera respuesta completa antes de RESET. |
| RESET físico | Botón; al retomar comunicación, consulta y LOAD | Puede abortar transmisión. PC descarta parcial; no espera aceptación ni aviso espontáneo del botón. |
| Cabecera LOAD incompleta | `01` y tamaño parcial; tras T, `01 07` | Conserva imagen anterior. RX se descarta hasta R de silencio; PC espera W_load, consulta y solo reintenta manualmente. |
| Contenido LOAD incompleto | Cabecera válida → `01 01`; payload parcial; tras T, `01 08` | Imagen inválida. Para N=32, W_load=300 ms; consulta después de recuperación y nueva LOAD completa por decisión del usuario. |
| Error UART y comando desconocido | LOAD: `01 09`; código con error fuera de LOAD: sin respuesta; código válido `06`: `06 0C` | Recuperación RX conserva TX; efecto de imagen según aceptación LOAD. Error en código no resetea CPU y RUN continúa. Byte desconocido no ejecuta operación. |
| Respuesta Debug truncada | Descartar parcial, esperar W_debug del perfil, limpiar RX local y `05` | Solo `05 03`/`05 04` completas restablecen comunicación. No se buscan cabeceras dentro del cuerpo ni se repite STEP/RUN/RESET automáticamente. |
| Consulta durante RUN y final concurrente | `05` → `05 04`; luego final RUN cuando corresponda | Una respuesta breve iniciada termina antes del resultado RUN; estado terminal retenido y sin intercalar bytes. Durante exclusión Debug RX se descarta. |

Las condiciones de LOAD y RUN/STEP coinciden con [control de ejecución](architecture/execution_control.md); la publicación de imagen y efecto de stores coinciden con [memoria](architecture/memory_architecture.md). La disponibilidad para LOAD no certifica imagen válida ni reserva una carga.

## 2. Tablas y cálculos — V02

Se comprobaron mediante lectura y cálculos estáticos efímeros, sin crear modelos de comportamiento ni testbenches:

- Cinco códigos de solicitud únicos 0x01–0x05; doce resultados únicos 0x01–0x0C; catorce estados externos únicos 0x00–0x0D. Cada tabla tiene su propio espacio de códigos.
- Los nombres, orden y anchos de todos los campos de latches coinciden con [Pipeline CPU](architecture/cpu_pipeline.md): IF/ID 5 campos/69 bits/11 bytes; ID/EX 15/193/30; EX/MEM 8/139/20; MEM/WB 6/103/15. Son 34 campos, 504 bits internos y 76 bytes externos, sin duplicar controles.
- Offsets continuos: contexto 19 bytes, RF 128, latches 76 y cantidad 5; parte fija 228. Lista comienza en offset 228 y cabecera común agrega dos bytes.
- Cinco bytes unsigned permiten tamaño/cantidad 2^32 (`00 00 00 00 01`); dirección de entrada sigue siendo de cuatro bytes. Validar tamaño completo antes de reducirlo evita truncamiento.
- REFERENCE y ALT_1000 comparten códigos/layout; capacidades y límites se toman de la tabla común. ALT_1000 no exige potencias de dos ni un segundo protocolo.
- La delimitación usa opcode para solicitudes y resultado/layout/cantidad para respuestas; Start/Stop siguen perteneciendo a cada byte físico. No se necesita checksum ni marcador adicional.

| Cálculo | Resultado |
|---|---:|
| Byte físico 8N1 a 19200 baud | 0,520833 ms nominales |
| T y R a 50 MHz | 100 ms = 5.000.000 clocks, cada uno |
| Preparación LOAD máxima, perfiles actuales | 1 ms = 50.000 clocks, incluido commit |
| Parte fija Debug | 228 bytes; 118,75 ms nominales; plazo 319 ms |
| Debug K=0 | 230 bytes completos; sin espera de lista |
| Debug K=2 | 240 bytes completos; plazo lista 206 ms |
| Debug K=1000 | 5230 bytes completos; plazo lista 2805 ms |
| Debug K=2048 | 10470 bytes completos; plazo lista 5534 ms |
| W_debug, REFERENCE | 6100 ms |
| W_debug, ALT_1000 | 3400 ms |
| LOAD N=32 | W_load=300 ms; plazo final desde payload=217,666667 ms |
| LOAD N=1000 | W_load=800 ms; plazo final=721,833333 ms |
| LOAD N=1024 | W_load=800 ms; plazo final=734,333333 ms |

Los plazos breves son 200 ms. Para RUN solo se limita completar la cabecera final una vez empezada; no se impone timeout de ejecución. Las cotas son contratos de diseño y deberán cumplirse al realizar los bloques, no mediciones realizadas.

## 3. Consolidación y límites — V03

[DEC-PROTO-001](decisions.md#dec-proto-001--formato-detallado-del-protocolo) queda aprobada y consolidada; DEC-PROTO-002/003, DEC-ARCH-009 y DEC-SYS-005 ya estaban aprobadas. La checklist de 52 tareas queda completada y se conserva como [archivo histórico](archive/protocolo_checklist_temporal_2026-10-01.md); su ruta anterior remite a los documentos definitivos.

Se actualizaron requisitos, contratos de interfaces, arquitectura de Debug, plan y mapa de decisiones abiertas. La comprobación final de los 531 enlaces locales renderizados en 29 documentos no encontró archivos ni anchors faltantes; excluye ejemplos de sintaxis en código. Los registros históricos conservan sus estados fechados.

Continúan abiertas DEC-SYS-007 (realización UART y servicios), DEC-SYS-009 (assembler) y DEC-SYS-008 (aplicación PC). También deben concretarse los detalles físicos enumerados en [interfaces](interfaces.md#152-detalles-de-realización-que-deben-concretarse-por-módulo): preparación, ownership, observación/serialización y plataforma. Este cierre del protocolo no acredita D0 ni habilita comenzar a programar.

## 4. Revisión de redacción y diagramas

El documento definitivo fue reescrito siguiendo la organización y la redacción de los documentos de arquitectura: propósito de cada mecanismo, explicación de su funcionamiento y relación con los contratos del sistema. Se incorporaron veinte diagramas de secuencia Mermaid para operaciones, rechazos, drenado, reset, arbitraje de respuestas, Debug y recuperación; se retiraron los recorridos expresados mediante flechas en bloques de texto.

La comparación con la versión previa conserva las tablas de operaciones, resultados, estados y causas; el contenido y orden de campos de latches; los offsets y tamaños del snapshot; la tabla de plazos y las fórmulas de recuperación. Los diagramas se revisaron contra esas reglas y los veinte fueron aceptados por el parser de secuencias disponible localmente, sin generar diagramas ASCII. La comprobación de los 538 enlaces locales renderizados terminó sin archivos ni anchors faltantes. Esta revisión no modifica decisiones ni acredita simulación o pruebas de hardware.

## 5. Comparación técnica de la reescritura posterior

Se revisó la nueva redacción del usuario después de corregir la sintaxis de Mermaid. La comparación utiliza la copia de la versión consolidada conservada antes de la reescritura y las decisiones aprobadas como respaldo. Se revisaron tanto los campos y valores como las condiciones expresadas en prosa y diagramas.

### Contenido conservado

| Contrato anterior | Comprobación en la nueva redacción |
|---|---|
| UART y buffers | 19200 baud, 8N1, sobremuestreo 16, 50 MHz, diez bits por byte y FIFO RX/TX independientes de cuatro bytes. TX pendiente no bloquea consumo/descarte RX. |
| Perfiles | REFERENCE 1024/2048 y ALT_1000 1000/1000, fuente común, selección previa igual, formato único y ausencia de negociación UART. |
| Representación | Binario little-endian; 32 bits en cuatro bytes, contador en ocho, tamaños/cantidades en cinco; campo pequeño en byte propio, padding cero, flags 00/01, patrones signed conservados. Sin ASCII, checksum/CRC ni marcador final. |
| Solicitudes y resultados | Los cinco códigos de operación, los doce resultados, sus nombres y longitudes permanecen iguales. Se conserva cabecera común de dos bytes, aceptación/final RUN y única respuesta STEP. |
| CHECK_READY | READY expresa disponibilidad para LOAD, sin garantía de imagen válida ni reserva; consulta antes de cargar, BUSY durante ejecución y descarte durante exclusión/recuperación. La independencia respecto de una consulta previa requiere la aclaración indicada abajo. |
| Imagen LOAD | Cabecera de seis bytes, N unsigned de 40 bits, validación completa antes de reducir ancho, imagen no vacía/base cero/contigua/múltiplo de cuatro/dentro de IMEM. Sin entry point o huecos; legalidad ISA a cargo de CPU. |
| Transferencia LOAD | PC prepara todos los bytes, espera aceptación, transmite exactamente N seguido y escucha respuestas; sin confirmaciones intermedias. FPGA procesa cada byte antes del siguiente completo y reconstruye words antes de escribir IMEM. |
| Aceptación y sesión | Mismos estados elegibles. LOAD aceptada abandona sesión/invalida imagen/tamaño cero; rechazo o tamaño incompleto previo conserva imagen y sesión. Fallo posterior no restaura programa anterior. |
| Preparación y DONE | PREPARING_READY, estado inicial limpio y memoria utilizada vacía; prepare_done publica N y READY sin ciclo CPU. Presupuesto máximo 1 ms/50.000 clocks, incluido commit, sin espera fija. RX descartado hasta último Stop de DONE, sin silencio tras éxito y sin rollback por perder DONE. |
| T de LOAD | 100 ms/5.000.000 clocks; tamaño desde opcode, contenido desde fin físico ACCEPTED; reinicio por byte mientras falten bytes, fin de supervisión al completar fase. Prioridad error UART, byte válido y timeout sin ambos. |
| Errores LOAD | INVALID_SIZE, BUSY, INCOMPLETE_REQUEST, INCOMPLETE_DATA y UART_ERROR conservan sus códigos, efecto de imagen según aceptación y recuperación correspondiente. |
| RUN | Inicio/continuación/conversión de drain STEP/nueva sesión desde terminal; aceptación no espera ejecución ni preparación. Final automático FINISHED/FAULT después de drain y último commit, siempre tras aceptación completa. Sin timeout de duración; rechazos sin alterar ejecución. La nota del rechazo necesita la precisión indicada abajo. |
| STEP | Un ciclo efectivo, incluidos stall/drain, sin ACK separado. DONE también al confirmar halt/fault; estado y metadatos distinguen resultados. Último drain ya informa terminal, sin paso adicional; nueva sesión desde FINISHED/FAULT. |
| RESET | 04/04 01, reset después del Stop de aceptación, sin pausa anticipada ni estado global UART nuevo. Abandono del RUN previo, NO_IMAGE y consulta posterior. Botón directo puede abortar TX, sin aceptación ni aviso espontáneo; RESET UART durante Debug se descarta. |
| Orden y exclusión | Una operación normal; CHECK_READY/RESET durante RUN efectivo con espera de su respuesta. Respuestas completas sin intercalar; respuesta breve iniciada antes del final RUN, estado terminal retenido. Tabla de fases y elegibilidad conservada. |
| Captura Debug | Solo STEP/final RUN; estado posterior con commits/contador; CPU sin nuevos ciclos ni LOAD/preparación hasta último Stop. UART continúa, lectura directa sin copia completa adicional, exclusión desde espera previa y descarte RX sin respuesta/cola. |
| Interpretación Debug | Campos registrados también con valid=0, sin filtrar ni reemplazar por cero; lector interpreta actividad, candidato fetch separado y fault global. Sin next.valid ni diagnósticos combinacionales. |
| Estructura Debug | Trece posiciones de bloques/campos coincidentes; contexto 19, RF 128, latches 76 y cantidad 5 bytes. Mismos 34 campos de latches, orden, anchos internos 69/193/139/103 y externos 11/30/20/15. Controles registrados conservan sus códigos. |
| Estado, contador y fault | Catorce estados externos 0x00–0x0D, ocho posiciones de tabla de causas con 0x03 reservado, sin imponer enum físico o ampliar capturas. Contador unsigned64 módulo 2^64; metadatos siempre presentes, vigentes solo en estados de fault y sin NONE obligatorio. |
| DMEM utilizada | Bytes escritos por stores comprometidos, incluidos ceros, SB/SH/SW de 1/2/4 bytes. Lecturas/preparación no agregan entradas; sesión nueva vacía, sobrescritura actualiza sin duplicados. Lista creciente con cantidad unsigned40, dirección32 y valor8; sin historial/deltas/huecos y sin segundo bitmap obligatorio. |
| Longitud y recepción completa | Cuerpo 228+5*K y respuesta 230+5*K, K cero sin entradas; ejemplos 230/240/5230/10470. No se publica snapshot parcial, se conserva observación completa anterior. |
| Recuperación RX y otros códigos | R=100 ms reiniciado por toda actividad, línea idle/sin byte en curso/RX vacía; descarte RX y conservación TX, sin reset CPU. UNKNOWN_COMMAND eco+0x0C; código con error UART sin respuesta, RUN continúa. Operaciones de un byte sin timeout de campos. |
| Esperas PC | Mismos inicios y plazos: respuestas breves 200 ms; final LOAD N*10*1000/19200+201; ejecución RUN sin límite y cabecera final iniciada 200; fijo Debug 319 y lista ceil(5*K*10*1000/19200+200). K cero termina sin espera de lista. |
| Recuperación PC | W_load, B_lista y W_debug equivalentes pese a presentación multilineal; ejemplos 300/800 y 6100/3400 ms conservados. Cese/cancelación, descarte y consulta; reintento LOAD manual, sin repetir STEP/RUN/RESET o buscar cabeceras dentro de datos. READY/BUSY no reconstruye sesión; W_debug no limita RUN ni reemplaza W_load. |
| Frontera de implementación | UART, FSM privadas, lectura DMEM, ownership y preparación siguen pendientes en diseño de bloques; aplicación y assembler conservan sus decisiones abiertas. No se acredita D0 ni implementación. |

La comparación estática confirmó igualdad de los 39 pares código/nombre de operaciones, resultados, estados y causas, de los campos de latches y de sus anchos, y de los trece offsets. Se comprobó equivalencia de las tres fórmulas de recuperación y se contrastaron manualmente los inicios de todos los plazos y las reglas anteriores con decisiones e interfaces.

### Precisiones que conviene restituir

1. **Consulta previa y aceptación LOAD.** El texto anterior decía expresamente que la FPGA valida LOAD sin almacenar ni exigir una consulta previa. La nueva redacción mantiene consulta obligatoria en PC, ausencia de reserva y validación según estado actual, pero no expresa esa última condición. Para conservar el contrato inequívoco, después del párrafo de CHECK_READY puede agregarse: «La PC consulta antes de cada LOAD. La FPGA valida esa LOAD de forma independiente, sin almacenar ni exigir una consulta previa».
2. **Rechazo de una segunda RUN.** La nota del diagrama dice «El intercambio termina aquí, no queda Debug pendiente». Durante RUNNING, un RUN nuevo puede recibir BUSY mientras el RUN aceptado anteriormente todavía debe producir su resultado terminal y Debug. El rechazo elimina la respuesta final de la solicitud rechazada, sin cancelar la pendiente anterior. La nota debería decir: «Esta solicitud rechazada termina sin respuesta final ni Debug asociado». Puede completarse en prosa: «Si otra RUN estaba ejecutando, conserva su resultado terminal pendiente».

No se detectaron cambios en valores, campos, fórmulas o secuencias obligatorias. Estas dos precisiones afectan la explicitud y el alcance de frases; están respaldadas por los acuerdos de disponibilidad independiente y de rechazo/orden RUN. La revisión registra los hallazgos sin cambiar la reescritura del protocolo.

**Corrección posterior:** ambos hallazgos quedaron resueltos en `protocol.md`. CHECK_READY explicita la consulta previa de PC y la validación independiente de FPGA. El rechazo RUN limita la ausencia de respuesta final/Debug a la solicitud rechazada y conserva el intercambio terminal pendiente de una RUN anterior.

Como comprobación adicional, se revisaron 489 enlaces locales en los 27 documentos presentes. Se encontraron dos referencias a `archive/protocolo_checklist_temporal_2026-10-01.md`, archivo que ya no está en el árbol: una en DEC-PROTO-001 de `decisions.md` y otra en la sección 3 de este registro. Son referencias históricas a la checklist y no alteran el contenido del protocolo, pero deben actualizarse o recuperar su destino.
