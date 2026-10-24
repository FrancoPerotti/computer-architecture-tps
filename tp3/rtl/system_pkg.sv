package system_pkg;
  // Frecuencia del dominio funcional y configuración del enlace UART y sus FIFO.
  localparam longint unsigned FUNCTIONAL_CLOCK_HZ    = 64'd50_000_000;
  localparam longint unsigned UART_BAUD_RATE         = 64'd19_200;
  localparam int unsigned     UART_DATA_BITS         = 8;
  localparam bit              UART_PARITY_ENABLED    = 1'b0;
  localparam int unsigned     UART_STOP_BITS         = 1;
  localparam int unsigned     UART_OVERSAMPLE_FACTOR = 16;
  localparam int unsigned     UART_FIFO_DEPTH        = 4;

  // Plazos de inactividad durante LOAD y de silencio para recuperar la recepción.
  // Se expresan en milisegundos y ciclos con aritmética unsigned de 64 bits.
  localparam longint unsigned PROTOCOL_LOAD_INACTIVITY_MS = 64'd100;
  localparam longint unsigned PROTOCOL_RECOVERY_SILENCE_MS = 64'd100;
  localparam longint unsigned PROTOCOL_LOAD_INACTIVITY_CYCLES =
      FUNCTIONAL_CLOCK_HZ * PROTOCOL_LOAD_INACTIVITY_MS / 64'd1000;
  localparam longint unsigned PROTOCOL_RECOVERY_SILENCE_CYCLES =
      FUNCTIONAL_CLOCK_HZ * PROTOCOL_RECOVERY_SILENCE_MS / 64'd1000;

  typedef logic [31:0] word_t;  // Palabra de datos, instrucción o dirección.
  typedef logic [6:0] opcode_t;  // Clase de instrucción codificada en los siete bits bajos.
  typedef logic [4:0] register_index_t;  // Índice del banco de registros.
  typedef logic [5:0] alu_op_t;  // Operación de la ALU.
  typedef logic alu_src_t;  // Origen del segundo operando de la ALU.
  typedef logic [1:0] result_sel_t;  // Origen del resultado de EX.
  typedef logic [2:0] flow_op_t;  // Operación de control de flujo.
  typedef logic [3:0] mem_op_t;  // Operación de memoria.
  typedef logic [2:0] fault_cause_t;  // Causa de fallo de la CPU.
  typedef logic [1:0] forward_sel_t;  // Fuente del operando por forwarding.
  typedef logic [1:0] access_size_t;  // Tamaño del acceso a memoria.
  typedef logic [7:0] protocol_opcode_t;  // Código de comando UART.
  typedef logic [7:0] protocol_result_t;  // Código de resultado UART.
  typedef logic [7:0] global_state_code_t;  // Código externo del estado de ejecución.

  // Códigos de las solicitudes que el controlador recibe por UART.
  localparam protocol_opcode_t CMD_LOAD        = 8'h01;
  localparam protocol_opcode_t CMD_RUN         = 8'h02;
  localparam protocol_opcode_t CMD_STEP        = 8'h03;
  localparam protocol_opcode_t CMD_RESET       = 8'h04;
  localparam protocol_opcode_t CMD_CHECK_READY = 8'h05;

  // Resultados de las operaciones, transportados en la cabecera de respuesta.
  localparam protocol_result_t RESULT_ACCEPTED           = 8'h01;
  localparam protocol_result_t RESULT_DONE               = 8'h02;
  localparam protocol_result_t RESULT_READY              = 8'h03;
  localparam protocol_result_t RESULT_BUSY               = 8'h04;
  localparam protocol_result_t RESULT_NO_IMAGE           = 8'h05;
  localparam protocol_result_t RESULT_INVALID_SIZE       = 8'h06;
  localparam protocol_result_t RESULT_INCOMPLETE_REQUEST = 8'h07;
  localparam protocol_result_t RESULT_INCOMPLETE_DATA    = 8'h08;
  localparam protocol_result_t RESULT_UART_ERROR         = 8'h09;
  localparam protocol_result_t RESULT_FINISHED           = 8'h0a;
  localparam protocol_result_t RESULT_FAULT              = 8'h0b;
  localparam protocol_result_t RESULT_UNKNOWN_COMMAND    = 8'h0c;

  // Codificación externa del estado de ejecución para las observaciones Debug.
  localparam global_state_code_t STATE_CODE_NO_IMAGE         = 8'h00;
  localparam global_state_code_t STATE_CODE_LOADING          = 8'h01;
  localparam global_state_code_t STATE_CODE_PREPARING_READY  = 8'h02;
  localparam global_state_code_t STATE_CODE_READY            = 8'h03;
  localparam global_state_code_t STATE_CODE_RUNNING          = 8'h04;
  localparam global_state_code_t STATE_CODE_STEPPING         = 8'h05;
  localparam global_state_code_t STATE_CODE_HALT_DRAIN_AUTO  = 8'h06;
  localparam global_state_code_t STATE_CODE_HALT_DRAIN_STEP  = 8'h07;
  localparam global_state_code_t STATE_CODE_FAULT_DRAIN_AUTO = 8'h08;
  localparam global_state_code_t STATE_CODE_FAULT_DRAIN_STEP = 8'h09;
  localparam global_state_code_t STATE_CODE_FINISHED         = 8'h0a;
  localparam global_state_code_t STATE_CODE_FAULT            = 8'h0b;
  localparam global_state_code_t STATE_CODE_PREPARING_RUN    = 8'h0c;
  localparam global_state_code_t STATE_CODE_PREPARING_STEP   = 8'h0d;

  // Tamaños en bytes de los campos binarios que transportan las solicitudes y respuestas.
  localparam int unsigned PROTOCOL_CODE_BYTES    = 1;
  localparam int unsigned PROTOCOL_WORD_BYTES    = 4;
  localparam int unsigned PROTOCOL_COUNTER_BYTES = 8;
  localparam int unsigned PROTOCOL_SIZE_BYTES    = 5;

  // Posiciones y longitud de la cabecera común a todas las respuestas.
  localparam int unsigned PROTOCOL_RESPONSE_OPCODE_OFFSET = 0;
  localparam int unsigned PROTOCOL_RESPONSE_RESULT_OFFSET = PROTOCOL_RESPONSE_OPCODE_OFFSET +
      PROTOCOL_CODE_BYTES;
  localparam int unsigned PROTOCOL_RESPONSE_HEADER_BYTES = PROTOCOL_RESPONSE_RESULT_OFFSET +
      PROTOCOL_CODE_BYTES;

  // Posición del tamaño de imagen y longitud de la cabecera de carga.
  localparam int unsigned PROTOCOL_LOAD_SIZE_OFFSET = PROTOCOL_CODE_BYTES;
  localparam
      int unsigned PROTOCOL_LOAD_HEADER_BYTES = PROTOCOL_LOAD_SIZE_OFFSET + PROTOCOL_SIZE_BYTES;

  // Distribución del contexto global; los offsets parten del cuerpo, sin cabecera.
  localparam int unsigned DEBUG_STATE_CODE_OFFSET = 0;
  localparam int unsigned DEBUG_IMAGE_VALID_OFFSET = DEBUG_STATE_CODE_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_PC_OFFSET = DEBUG_IMAGE_VALID_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_CYCLE_COUNT_OFFSET = DEBUG_PC_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_FAULT_CAUSE_OFFSET = DEBUG_CYCLE_COUNT_OFFSET + PROTOCOL_COUNTER_BYTES;
  localparam int unsigned DEBUG_FAULT_PC_OFFSET = DEBUG_FAULT_CAUSE_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_CONTEXT_BYTES = DEBUG_FAULT_PC_OFFSET + PROTOCOL_WORD_BYTES;

  // Inicio y longitud del bloque que transporta el banco de registros completo.
  localparam int unsigned DEBUG_RF_OFFSET = DEBUG_CONTEXT_BYTES;
  localparam int unsigned DEBUG_RF_BYTES  = 32 * PROTOCOL_WORD_BYTES;

  // Distribución de los campos de IF/ID en el cuerpo del snapshot.
  localparam int unsigned DEBUG_IFID_OFFSET = DEBUG_RF_OFFSET + DEBUG_RF_BYTES;
  localparam int unsigned DEBUG_IFID_VALID_OFFSET = DEBUG_IFID_OFFSET;
  localparam int unsigned DEBUG_IFID_PC_OFFSET = DEBUG_IFID_VALID_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_IFID_INSTRUCTION_OFFSET = DEBUG_IFID_PC_OFFSET + PROTOCOL_WORD_BYTES;
  localparam int unsigned DEBUG_IFID_FETCH_FAULT_VALID_OFFSET = DEBUG_IFID_INSTRUCTION_OFFSET +
      PROTOCOL_WORD_BYTES;
  localparam int unsigned DEBUG_IFID_FETCH_FAULT_CAUSE_OFFSET =
      DEBUG_IFID_FETCH_FAULT_VALID_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_IFID_BYTES =
      DEBUG_IFID_FETCH_FAULT_CAUSE_OFFSET + PROTOCOL_CODE_BYTES - DEBUG_IFID_OFFSET;

  // Distribución de los campos de ID/EX en el cuerpo del snapshot.
  localparam int unsigned DEBUG_IDEX_OFFSET = DEBUG_IFID_OFFSET + DEBUG_IFID_BYTES;
  localparam int unsigned DEBUG_IDEX_VALID_OFFSET = DEBUG_IDEX_OFFSET;
  localparam int unsigned DEBUG_IDEX_PC_OFFSET = DEBUG_IDEX_VALID_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_IDEX_INSTRUCTION_OFFSET = DEBUG_IDEX_PC_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_IDEX_RS1_OFFSET = DEBUG_IDEX_INSTRUCTION_OFFSET + PROTOCOL_WORD_BYTES;
  localparam int unsigned DEBUG_IDEX_RS2_OFFSET = DEBUG_IDEX_RS1_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_IDEX_RD_OFFSET = DEBUG_IDEX_RS2_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_IDEX_RS1_VALUE_OFFSET = DEBUG_IDEX_RD_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_IDEX_RS2_VALUE_OFFSET = DEBUG_IDEX_RS1_VALUE_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_IDEX_IMMEDIATE_OFFSET = DEBUG_IDEX_RS2_VALUE_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_IDEX_ALU_OP_OFFSET = DEBUG_IDEX_IMMEDIATE_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_IDEX_ALU_SRC_OFFSET = DEBUG_IDEX_ALU_OP_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_IDEX_RESULT_SEL_OFFSET = DEBUG_IDEX_ALU_SRC_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_IDEX_FLOW_OP_OFFSET = DEBUG_IDEX_RESULT_SEL_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_IDEX_MEM_OP_OFFSET = DEBUG_IDEX_FLOW_OP_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_IDEX_REG_WRITE_OFFSET = DEBUG_IDEX_MEM_OP_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_IDEX_BYTES = DEBUG_IDEX_REG_WRITE_OFFSET + PROTOCOL_CODE_BYTES -
      DEBUG_IDEX_OFFSET;

  // Distribución de los campos de EX/MEM en el cuerpo del snapshot.
  localparam int unsigned DEBUG_EXMEM_OFFSET = DEBUG_IDEX_OFFSET + DEBUG_IDEX_BYTES;
  localparam int unsigned DEBUG_EXMEM_VALID_OFFSET = DEBUG_EXMEM_OFFSET;
  localparam int unsigned DEBUG_EXMEM_PC_OFFSET = DEBUG_EXMEM_VALID_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_EXMEM_INSTRUCTION_OFFSET = DEBUG_EXMEM_PC_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_EXMEM_RD_OFFSET = DEBUG_EXMEM_INSTRUCTION_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_EXMEM_REG_WRITE_OFFSET = DEBUG_EXMEM_RD_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_EXMEM_MEM_OP_OFFSET = DEBUG_EXMEM_REG_WRITE_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_EXMEM_EX_RESULT_OFFSET = DEBUG_EXMEM_MEM_OP_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_EXMEM_STORE_DATA_OFFSET = DEBUG_EXMEM_EX_RESULT_OFFSET +
      PROTOCOL_WORD_BYTES;
  localparam int unsigned DEBUG_EXMEM_BYTES = DEBUG_EXMEM_STORE_DATA_OFFSET + PROTOCOL_WORD_BYTES -
      DEBUG_EXMEM_OFFSET;

  // Distribución de los campos de MEM/WB en el cuerpo del snapshot.
  localparam int unsigned DEBUG_MEMWB_OFFSET = DEBUG_EXMEM_OFFSET + DEBUG_EXMEM_BYTES;
  localparam int unsigned DEBUG_MEMWB_VALID_OFFSET = DEBUG_MEMWB_OFFSET;
  localparam int unsigned DEBUG_MEMWB_PC_OFFSET = DEBUG_MEMWB_VALID_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_MEMWB_INSTRUCTION_OFFSET = DEBUG_MEMWB_PC_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_MEMWB_RD_OFFSET = DEBUG_MEMWB_INSTRUCTION_OFFSET + PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_MEMWB_REG_WRITE_OFFSET = DEBUG_MEMWB_RD_OFFSET + PROTOCOL_CODE_BYTES;
  localparam
      int unsigned DEBUG_MEMWB_WB_VALUE_OFFSET = DEBUG_MEMWB_REG_WRITE_OFFSET + PROTOCOL_CODE_BYTES;
  localparam int unsigned DEBUG_MEMWB_BYTES = DEBUG_MEMWB_WB_VALUE_OFFSET + PROTOCOL_WORD_BYTES -
      DEBUG_MEMWB_OFFSET;

  // Ubicación de la cantidad y la lista de memoria, y longitudes fijas de Debug.
  localparam int unsigned DEBUG_USED_COUNT_OFFSET = DEBUG_MEMWB_OFFSET + DEBUG_MEMWB_BYTES;
  localparam int unsigned DEBUG_USED_COUNT_BYTES = PROTOCOL_SIZE_BYTES;
  localparam
      int unsigned DEBUG_MEMORY_LIST_OFFSET = DEBUG_USED_COUNT_OFFSET + DEBUG_USED_COUNT_BYTES;
  localparam int unsigned DEBUG_FIXED_BYTES = DEBUG_MEMORY_LIST_OFFSET;
  localparam
      int unsigned DEBUG_RESPONSE_FIXED_BYTES = PROTOCOL_RESPONSE_HEADER_BYTES + DEBUG_FIXED_BYTES;

  // Distribución de cada entrada dirección/valor, con offsets relativos a su inicio.
  localparam int unsigned DEBUG_MEMORY_ADDRESS_OFFSET = 0;
  localparam int unsigned DEBUG_MEMORY_VALUE_OFFSET = PROTOCOL_WORD_BYTES;
  localparam
      int unsigned DEBUG_MEMORY_ENTRY_BYTES = DEBUG_MEMORY_VALUE_OFFSET + PROTOCOL_CODE_BYTES;

  // Opcodes compartidos por la decodificación y la selección del formato de inmediato.
  localparam opcode_t OPCODE_ALU_REG  = 7'b0110011;
  localparam opcode_t OPCODE_ALU_IMM  = 7'b0010011;
  localparam opcode_t OPCODE_LOAD     = 7'b0000011;
  localparam opcode_t OPCODE_STORE    = 7'b0100011;
  localparam opcode_t OPCODE_BRANCH   = 7'b1100011;
  localparam opcode_t OPCODE_JAL      = 7'b1101111;
  localparam opcode_t OPCODE_JALR     = 7'b1100111;
  localparam opcode_t OPCODE_LUI      = 7'b0110111;
  localparam opcode_t OPCODE_CUSTOM_0 = 7'b0001011;

  // Operaciones que seleccionan el cálculo de la ALU.
  localparam alu_op_t ALU_OP_SLL  = 6'b000000;
  localparam alu_op_t ALU_OP_SRL  = 6'b000010;
  localparam alu_op_t ALU_OP_SRA  = 6'b000011;
  localparam alu_op_t ALU_OP_SLT  = 6'b101010;
  localparam alu_op_t ALU_OP_SLTU = 6'b101011;
  localparam alu_op_t ALU_OP_ADD  = 6'b100000;
  localparam alu_op_t ALU_OP_SUB  = 6'b100010;
  localparam alu_op_t ALU_OP_AND  = 6'b100100;
  localparam alu_op_t ALU_OP_OR   = 6'b100101;
  localparam alu_op_t ALU_OP_XOR  = 6'b100110;

  // Origen del segundo operando de la ALU.
  localparam alu_src_t ALU_SRC_RS2       = 1'b0;
  localparam alu_src_t ALU_SRC_IMMEDIATE = 1'b1;

  // Origen del resultado producido por la etapa EX.
  localparam result_sel_t RESULT_SEL_ALU       = 2'b00;
  localparam result_sel_t RESULT_SEL_IMMEDIATE = 2'b01;
  localparam result_sel_t RESULT_SEL_LINK      = 2'b10;

  // Fuentes de los multiplexores de forwarding; 2'b11 queda reservado.
  localparam forward_sel_t FORWARD_SEL_ID_EX  = 2'b00;
  localparam forward_sel_t FORWARD_SEL_EX_MEM = 2'b01;
  localparam forward_sel_t FORWARD_SEL_MEM_WB = 2'b10;

  // Tamaños de acceso a memoria; 2'b11 queda reservado.
  localparam access_size_t ACCESS_SIZE_BYTE     = 2'b00;
  localparam access_size_t ACCESS_SIZE_HALFWORD = 2'b01;
  localparam access_size_t ACCESS_SIZE_WORD     = 2'b10;

  // Operaciones de control de flujo reconocidas por la CPU.
  localparam flow_op_t FLOW_OP_NONE = 3'b000;
  localparam flow_op_t FLOW_OP_BEQ  = 3'b001;
  localparam flow_op_t FLOW_OP_BNE  = 3'b010;
  localparam flow_op_t FLOW_OP_JAL  = 3'b011;
  localparam flow_op_t FLOW_OP_JALR = 3'b100;
  localparam flow_op_t FLOW_OP_HALT = 3'b101;

  // Clases de acceso que distinguen las lecturas y escrituras de memoria.
  localparam mem_op_t MEM_OP_NONE = 4'b0000;
  localparam mem_op_t MEM_OP_LB   = 4'b0001;
  localparam mem_op_t MEM_OP_LH   = 4'b0010;
  localparam mem_op_t MEM_OP_LW   = 4'b0011;
  localparam mem_op_t MEM_OP_LBU  = 4'b0100;
  localparam mem_op_t MEM_OP_LHU  = 4'b0101;
  localparam mem_op_t MEM_OP_SB   = 4'b0110;
  localparam mem_op_t MEM_OP_SH   = 4'b0111;
  localparam mem_op_t MEM_OP_SW   = 4'b1000;

  // Causas de fallo que acompañan a los eventos de error de la CPU.
  localparam fault_cause_t FAULT_INSTRUCTION_ADDRESS_MISALIGNED = 3'b000;
  localparam fault_cause_t FAULT_INSTRUCTION_ACCESS_FAULT       = 3'b001;
  localparam fault_cause_t FAULT_ILLEGAL_INSTRUCTION            = 3'b010;
  localparam fault_cause_t FAULT_LOAD_ADDRESS_MISALIGNED        = 3'b100;
  localparam fault_cause_t FAULT_LOAD_ACCESS_FAULT              = 3'b101;
  localparam fault_cause_t FAULT_STORE_ADDRESS_MISALIGNED       = 3'b110;
  localparam fault_cause_t FAULT_STORE_ACCESS_FAULT             = 3'b111;

  // Datos de búsqueda que IF entrega a ID, incluido el candidato de fallo de fetch.
  typedef struct packed {
    logic         valid;
    word_t        pc;
    word_t        instruction;
    logic         fetch_fault_valid;
    fault_cause_t fetch_fault_cause;
  } if_id_t;

  // Instrucción decodificada, operandos y controles que ID entrega a EX.
  typedef struct packed {
    logic            valid;
    word_t           pc;
    word_t           instruction;
    register_index_t rs1;
    register_index_t rs2;
    register_index_t rd;
    word_t           rs1_value;
    word_t           rs2_value;
    word_t           immediate;
    alu_op_t         alu_op;
    alu_src_t        alu_src;
    result_sel_t     result_sel;
    flow_op_t        flow_op;
    mem_op_t         mem_op;
    logic            reg_write;
  } id_ex_t;

  // Resultado de EX, dato de store y controles que MEM necesita para completar la operación.
  typedef struct packed {
    logic            valid;
    word_t           pc;
    word_t           instruction;
    register_index_t rd;
    logic            reg_write;
    mem_op_t         mem_op;
    word_t           ex_result;
    word_t           store_data;
  } ex_mem_t;

  // Resultado y destino que MEM entrega a WB para la escritura en el banco de registros.
  typedef struct packed {
    logic            valid;
    word_t           pc;
    word_t           instruction;
    register_index_t rd;
    logic            reg_write;
    word_t           wb_value;
  } mem_wb_t;

  // Identificadores de elaboración; no son códigos del protocolo UART.
  typedef logic [31:0] memory_profile_t;  // Identificador del perfil de memorias.
  typedef longint unsigned memory_capacity_t;  // Capacidad de memoria en bytes.

  // Perfiles de elaboración disponibles para seleccionar las capacidades de memoria.
  localparam memory_profile_t REFERENCE = 32'd0;
  localparam memory_profile_t ALT_1000  = 32'd1;

  // Capacidades en bytes de IMEM y DMEM para cada perfil.
  localparam memory_capacity_t REFERENCE_IMEM_CAPACITY_BYTES = 64'd1024;
  localparam memory_capacity_t REFERENCE_DMEM_CAPACITY_BYTES = 64'd2048;
  localparam memory_capacity_t ALT_1000_IMEM_CAPACITY_BYTES  = 64'd1000;
  localparam memory_capacity_t ALT_1000_DMEM_CAPACITY_BYTES  = 64'd1000;

  // Límites del dominio arquitectónico de capacidades de memoria, expresados en bytes.
  localparam memory_capacity_t MIN_MEMORY_CAPACITY_BYTES = 64'd4;
  localparam memory_capacity_t MAX_MEMORY_CAPACITY_BYTES = 64'h0000000100000000;

  // Diagnósticos que distinguen una capacidad inválida de una configuración sin soporte.
  localparam string CONFIG_INVALID_CAPACITY = "CONFIG_INVALID_CAPACITY";
  localparam string CONFIG_UNSUPPORTED      = "CONFIG_UNSUPPORTED";

  // Comprueba que la capacidad esté entre 4 y 2^32 bytes y sea múltiplo de cuatro.
  function automatic bit memory_capacity_valid(input memory_capacity_t capacity);
    memory_capacity_valid = capacity >= MIN_MEMORY_CAPACITY_BYTES &&
        capacity <= MAX_MEMORY_CAPACITY_BYTES && capacity % 64'd4 == 0;
  endfunction

  // Devuelve una cadena vacía para una capacidad válida o CONFIG_INVALID_CAPACITY.
  function automatic string memory_capacity_diagnostic(input memory_capacity_t capacity);
    if (memory_capacity_valid(capacity)) begin
      memory_capacity_diagnostic = "";
    end else begin
      memory_capacity_diagnostic = CONFIG_INVALID_CAPACITY;
    end
  endfunction

  // Indica si las capacidades válidas de ambas memorias coinciden con el perfil
  // REFERENCE, único par con soporte físico declarado para Basys 3.
  function automatic bit basys3_memory_supported(input memory_capacity_t imem_capacity,
                                                 input memory_capacity_t dmem_capacity);
    basys3_memory_supported = memory_capacity_valid(imem_capacity) &&
        memory_capacity_valid(dmem_capacity) && imem_capacity == REFERENCE_IMEM_CAPACITY_BYTES &&
        dmem_capacity == REFERENCE_DMEM_CAPACITY_BYTES;
  endfunction

  // Distingue capacidades inválidas de pares válidos sin soporte físico declarado;
  // devuelve una cadena vacía cuando el par está admitido.
  function automatic string basys3_memory_diagnostic(input memory_capacity_t imem_capacity,
                                                     input memory_capacity_t dmem_capacity);
    if (!memory_capacity_valid(imem_capacity) || !memory_capacity_valid(dmem_capacity)) begin
      basys3_memory_diagnostic = CONFIG_INVALID_CAPACITY;
    end else if (!basys3_memory_supported(imem_capacity, dmem_capacity)) begin
      basys3_memory_diagnostic = CONFIG_UNSUPPORTED;
    end else begin
      basys3_memory_diagnostic = "";
    end
  endfunction

  // Devuelve la cantidad de palabras de 32 bits; para una capacidad inválida usa
  // el centinela 1, que mantiene dimensiones positivas hasta emitir el diagnóstico.
  function automatic memory_capacity_t memory_word_count(input memory_capacity_t capacity);
    memory_word_count = memory_capacity_valid(capacity) ? capacity / 64'd4 : 64'd1;
  endfunction

  // Calcula los bits para direccionar los bytes de la memoria; devuelve 1 si es inválida.
  function automatic int unsigned byte_address_width(input memory_capacity_t capacity);
    byte_address_width = memory_capacity_valid(capacity) ? $clog2(capacity) : 1;
  endfunction

  // Calcula los bits del índice de palabra, con mínimo de uno incluso para una
  // sola palabra; devuelve 1 cuando la capacidad es inválida.
  function automatic int unsigned word_index_width(input memory_capacity_t capacity);
    int unsigned width;
    width            = $clog2(memory_word_count(capacity));
    word_index_width = width > 0 ? width : 1;
  endfunction

  // Usa el ancho del índice de palabra para las filas: al menos un bit y 1 para
  // capacidades inválidas.
  function automatic int unsigned row_index_width(input memory_capacity_t capacity);
    row_index_width = word_index_width(capacity);
  endfunction

  // Calcula los bits para representar valores desde cero hasta la capacidad
  // inclusive, conservando C + 1 en 64 bits; devuelve 1 si la capacidad es inválida.
  function automatic int unsigned capacity_inclusive_width(input memory_capacity_t capacity);
    capacity_inclusive_width = memory_capacity_valid(capacity) ? $clog2(capacity + 64'd1) : 1;
  endfunction

  // Reconoce los perfiles disponibles y rechaza identificadores desconocidos o con X/Z.
  function automatic bit memory_profile_supported(input memory_profile_t profile);
    case (profile)
      REFERENCE, ALT_1000: memory_profile_supported = 1'b1;
      default:             memory_profile_supported = 1'b0;
    endcase
  endfunction

  // Resuelve la capacidad de IMEM en bytes; devuelve cero como centinela si el
  // perfil no está admitido y debe rechazarse antes de elaborar recursos.
  function automatic memory_capacity_t imem_capacity_bytes(input memory_profile_t profile);
    case (profile)
      REFERENCE: imem_capacity_bytes = REFERENCE_IMEM_CAPACITY_BYTES;
      ALT_1000:  imem_capacity_bytes = ALT_1000_IMEM_CAPACITY_BYTES;
      // El consumidor debe rechazar el perfil antes de elaborar recursos.
      default:   imem_capacity_bytes = 64'd0;
    endcase
  endfunction

  // Resuelve la capacidad de DMEM en bytes; devuelve cero como centinela si el
  // perfil no está admitido y debe rechazarse antes de elaborar recursos.
  function automatic memory_capacity_t dmem_capacity_bytes(input memory_profile_t profile);
    case (profile)
      REFERENCE: dmem_capacity_bytes = REFERENCE_DMEM_CAPACITY_BYTES;
      ALT_1000:  dmem_capacity_bytes = ALT_1000_DMEM_CAPACITY_BYTES;
      default:   dmem_capacity_bytes = 64'd0;
    endcase
  endfunction

  // Devuelve una cadena vacía para perfiles admitidos o CONFIG_UNSUPPORTED para los demás.
  function automatic string memory_profile_diagnostic(input memory_profile_t profile);
    if (memory_profile_supported(profile)) begin
      memory_profile_diagnostic = "";
    end else begin
      memory_profile_diagnostic = CONFIG_UNSUPPORTED;
    end
  endfunction
endpackage
