`timescale 1ns / 1ps

// Comprueba perfiles, capacidades, anchos derivados y rechazos de configuración.
module system_pkg_tb #(
    parameter system_pkg::memory_profile_t  MEMORY_PROFILE   = system_pkg::REFERENCE,
    parameter integer                       FORBID_RESOURCES = 0,
    parameter integer                       CHECK_CAPACITY   = 0,
    parameter system_pkg::memory_capacity_t CAPACITY_BYTES   = 64'd0
);
  import system_pkg::*;

  // Capacidades resueltas a partir del perfil seleccionado para la prueba.
  localparam memory_capacity_t IMEM_CAPACITY_BYTES = imem_capacity_bytes(MEMORY_PROFILE);
  localparam memory_capacity_t DMEM_CAPACITY_BYTES = dmem_capacity_bytes(MEMORY_PROFILE);

  tp3_case_data data ();

  // Informa el fallo del caso y termina la simulación con código distinto de cero.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  if (CHECK_CAPACITY) begin : g_capacity_checks
    // Dimensiones de elaboración calculadas para la capacidad bajo prueba.
    localparam integer BYTE_ADDRESS_WIDTH = byte_address_width(CAPACITY_BYTES);
    localparam integer WORD_INDEX_WIDTH = word_index_width(CAPACITY_BYTES);
    localparam integer ROW_INDEX_WIDTH = row_index_width(CAPACITY_BYTES);
    localparam integer CAPACITY_INCLUSIVE_WIDTH = capacity_inclusive_width(CAPACITY_BYTES);
    localparam memory_capacity_t WORD_COUNT = memory_word_count(CAPACITY_BYTES);

    if (memory_capacity_valid(CAPACITY_BYTES)) begin : g_valid_capacity
      if (FORBID_RESOURCES) begin : g_forbidden_resources
        capacity_resource_must_not_be_elaborated unexpected_resource ();
      end

      // Solo señales de hasta 33 bits; no se reserva un array de tamaño C.
      logic [      BYTE_ADDRESS_WIDTH-1:0] last_byte;
      logic [        WORD_INDEX_WIDTH-1:0] last_word;
      logic [         ROW_INDEX_WIDTH-1:0] last_row;
      logic [CAPACITY_INCLUSIVE_WIDTH-1:0] inclusive_capacity;

      initial begin
        data.load();
        if (CAPACITY_BYTES !== $unsigned(data.get_integer("/inputs/C"))) begin
          fail("elaborated capacity differs from manifest");
        end
        if (memory_capacity_diagnostic(CAPACITY_BYTES) != "") begin
          fail("valid capacity has a diagnostic");
        end
        if (BYTE_ADDRESS_WIDTH != data.get_integer(
                "/expected/BYTE_ADDRESS_WIDTH"
            ) || WORD_INDEX_WIDTH != data.get_integer(
                "/expected/WORD_INDEX_WIDTH"
            ) || ROW_INDEX_WIDTH != data.get_integer(
                "/expected/ROW_INDEX_WIDTH"
            ) || CAPACITY_INCLUSIVE_WIDTH != data.get_integer(
                "/expected/CAPACITY_INCLUSIVE_WIDTH"
            )) begin
          fail("derived widths differ from manifest");
        end
        if (WORD_COUNT != CAPACITY_BYTES / 64'd4) fail("word count differs from capacity / 4");

        last_byte          = CAPACITY_BYTES - 64'd1;
        last_word          = WORD_COUNT - 64'd1;
        last_row           = WORD_COUNT - 64'd1;
        inclusive_capacity = CAPACITY_BYTES;
        if (last_byte !== CAPACITY_BYTES - 64'd1 || last_word !== WORD_COUNT - 64'd1 ||
            last_row !== WORD_COUNT - 64'd1 || inclusive_capacity !== CAPACITY_BYTES) begin
          fail("derived vectors truncate a capacity or index");
        end
        $display("PASS %s", data.case_id);
        $finish;
      end
    end else begin : g_invalid_capacity
      initial begin
        data.load();
        if (CAPACITY_BYTES !== $unsigned(data.get_integer("/inputs/C"))) begin
          fail("elaborated capacity differs from manifest");
        end
        if (BYTE_ADDRESS_WIDTH < 1 || WORD_INDEX_WIDTH < 1 || ROW_INDEX_WIDTH < 1 ||
            CAPACITY_INCLUSIVE_WIDTH < 1 || WORD_COUNT < 1) begin
          fail("invalid capacity produced a nonpositive auxiliary dimension");
        end
        if (data.get_boolean("/expected/no_resource_elaboration") && !FORBID_RESOURCES) begin
          fail("resource elaboration guard is not enabled");
        end
        if (memory_capacity_diagnostic(
                CAPACITY_BYTES
            ) != data.get_string(
                "/expected/diagnostic"
            )) begin
          fail("unexpected capacity diagnostic");
        end
        if (basys3_memory_diagnostic(
                CAPACITY_BYTES, REFERENCE_DMEM_CAPACITY_BYTES
            ) != data.get_string(
                "/expected/diagnostic"
            ) || basys3_memory_diagnostic(
                REFERENCE_IMEM_CAPACITY_BYTES, CAPACITY_BYTES
            ) != data.get_string(
                "/expected/diagnostic"
            )) begin
          fail("physical target masked an invalid capacity");
        end
        $display("REJECT %s %s", data.case_id, memory_capacity_diagnostic(CAPACITY_BYTES));
        $fatal(1, "%s", memory_capacity_diagnostic(CAPACITY_BYTES));
      end
    end
  end else if (memory_profile_supported(MEMORY_PROFILE)) begin : g_supported_profile
    // Este módulo inexistente detecta una elaboración indebida en la prueba negativa.
    if (FORBID_RESOURCES) begin : g_forbidden_resources
      profile_resource_must_not_be_elaborated unexpected_resource ();
    end

    initial begin
      data.load();
      if ((MEMORY_PROFILE === REFERENCE && data.get_string(
              "/inputs/profile"
          ) != "REFERENCE") || (MEMORY_PROFILE === ALT_1000 && data.get_string(
              "/inputs/profile"
          ) != "ALT_1000")) begin
        fail("selected profile differs from manifest");
      end
      if ($bits(IMEM_CAPACITY_BYTES) != 64 || $bits(DMEM_CAPACITY_BYTES) != 64) begin
        fail("capacities must have 64 bits");
      end
      if (memory_capacity_t'(-1) <= 0) fail("capacities must be unsigned");
      if (IMEM_CAPACITY_BYTES !== $unsigned(data.get_integer("/inputs/IMEM_C"))) begin
        fail("IMEM capacity differs from manifest");
      end
      if (DMEM_CAPACITY_BYTES !== $unsigned(data.get_integer("/inputs/DMEM_C"))) begin
        fail("DMEM capacity differs from manifest");
      end
      if (memory_profile_diagnostic(MEMORY_PROFILE) != "") begin
        fail("supported profile has a diagnostic");
      end
      if (basys3_memory_supported(
              IMEM_CAPACITY_BYTES, DMEM_CAPACITY_BYTES
          ) !== (data.get_string(
              "/inputs/profile"
          ) == "REFERENCE")) begin
        fail("physical support differs from declared profiles");
      end
      if (MEMORY_PROFILE === REFERENCE && basys3_memory_diagnostic(
              IMEM_CAPACITY_BYTES, DMEM_CAPACITY_BYTES
          ) != "") begin
        fail("reference physical configuration has a diagnostic");
      end
      $display("PASS %s", data.case_id);
      $finish;
    end
  end else begin : g_unsupported_profile
    initial begin
      data.load();
      if (IMEM_CAPACITY_BYTES !== 64'd0 || DMEM_CAPACITY_BYTES !== 64'd0) begin
        fail("unsupported profile returned a capacity");
      end
      if (memory_profile_diagnostic(
              MEMORY_PROFILE
          ) != data.get_string(
              "/expected/diagnostic"
          )) begin
        fail("unexpected diagnostic");
      end
      $display("REJECT %s %s", data.case_id, memory_profile_diagnostic(MEMORY_PROFILE));
      $fatal(1, "%s", memory_profile_diagnostic(MEMORY_PROFILE));
    end
  end
endmodule

// Comprueba que una capacidad legal sin soporte físico se rechace sin reservar memoria.
module system_pkg_target_tb #(
    parameter system_pkg::memory_capacity_t CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  // Soporte declarado al aplicar la capacidad a IMEM o DMEM por separado.
  localparam bit IMEM_SUPPORTED = basys3_memory_supported(
      CAPACITY_BYTES, REFERENCE_DMEM_CAPACITY_BYTES
  );
  localparam bit DMEM_SUPPORTED = basys3_memory_supported(
      REFERENCE_IMEM_CAPACITY_BYTES, CAPACITY_BYTES
  );
  tp3_case_data data ();

  // Si cualquiera de las dos consultas acepta la capacidad, la elaboración debe fallar.
  // El centinela comprueba la exclusión de recursos sin intentar reservar un array grande.
  if (IMEM_SUPPORTED || DMEM_SUPPORTED) begin : g_forbidden_resources
    target_resource_must_not_be_elaborated unexpected_resource ();
  end

  // Informa el fallo del caso y termina la simulación con código distinto de cero.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  initial begin
    data.load();
    if (CAPACITY_BYTES !== $unsigned(data.get_integer("/inputs/C"))) begin
      fail("elaborated capacity differs from manifest");
    end
    if (data.get_string(
            "/inputs/target"
        ) != "Basys3-físico" || !data.get_boolean(
            "/inputs/physical_realization_required"
        )) begin
      fail("case does not request the Basys 3 physical target");
    end
    if (memory_capacity_valid(
            CAPACITY_BYTES
        ) !== data.get_boolean(
            "/expected/architecturally_legal"
        )) begin
      fail("architectural capacity validity differs from manifest");
    end
    if ((!IMEM_SUPPORTED && !DMEM_SUPPORTED) !== data.get_boolean(
            "/expected/no_giant_array_attempt"
        )) begin
      fail("resource exclusion differs from manifest");
    end
    if (basys3_memory_diagnostic(
            CAPACITY_BYTES, REFERENCE_DMEM_CAPACITY_BYTES
        ) != data.get_string(
            "/expected/diagnostic"
        ) || basys3_memory_diagnostic(
            REFERENCE_IMEM_CAPACITY_BYTES, CAPACITY_BYTES
        ) != data.get_string(
            "/expected/diagnostic"
        )) begin
      fail("physical target diagnostic differs from manifest");
    end
    $display("REJECT %s %s", data.case_id, basys3_memory_diagnostic(
             CAPACITY_BYTES, REFERENCE_DMEM_CAPACITY_BYTES));
    $fatal(1, "%s", basys3_memory_diagnostic(CAPACITY_BYTES, REFERENCE_DMEM_CAPACITY_BYTES));
  end
endmodule

// Consumidor de prueba para la elaboración mínima; no implementa una memoria funcional.
module system_pkg_minimum_memory_fixture #(
    parameter system_pkg::memory_capacity_t CAPACITY_BYTES = 64'd0
) (
    output wire positive_widths,
    output wire one_row
);
  import system_pkg::*;

  // Dimensiones de los vectores y del array auxiliar del consumidor de prueba.
  localparam integer           BYTE_ADDRESS_WIDTH       = byte_address_width(CAPACITY_BYTES);
  localparam integer           WORD_INDEX_WIDTH         = word_index_width(CAPACITY_BYTES);
  localparam integer           ROW_INDEX_WIDTH          = row_index_width(CAPACITY_BYTES);
  localparam integer           CAPACITY_INCLUSIVE_WIDTH = capacity_inclusive_width(CAPACITY_BYTES);
  localparam memory_capacity_t WORD_COUNT               = memory_word_count(CAPACITY_BYTES);

  logic [      BYTE_ADDRESS_WIDTH-1:0] byte_address;
  logic [        WORD_INDEX_WIDTH-1:0] word_index;
  logic [         ROW_INDEX_WIDTH-1:0] row_index;
  logic [CAPACITY_INCLUSIVE_WIDTH-1:0] inclusive_capacity;

  assign positive_widths = BYTE_ADDRESS_WIDTH > 0 && WORD_INDEX_WIDTH > 0 && ROW_INDEX_WIDTH > 0 &&
      CAPACITY_INCLUSIVE_WIDTH > 0 && $bits(
      byte_address
  ) == BYTE_ADDRESS_WIDTH && $bits(
      word_index
  ) == WORD_INDEX_WIDTH && $bits(
      row_index
  ) == ROW_INDEX_WIDTH && $bits(
      inclusive_capacity
  ) == CAPACITY_INCLUSIVE_WIDTH;

  // Este fixture solo reserva el array si la configuración produce una fila.
  if (memory_capacity_valid(CAPACITY_BYTES) && WORD_COUNT == 64'd1) begin : g_single_row
    word_t words[WORD_COUNT];
    assign one_row = $size(words) == 1;
  end else begin : g_other_configuration
    assign one_row = 1'b0;
  end
endmodule

// Comprueba los tipos packed de latches y las codificaciones compartidas de CPU.
module system_pkg_latches_tb;
  import system_pkg::*;

  // Ancho auxiliar para comparar el empaquetado conjunto de los cuatro latches.
  localparam integer PACKED_WIDTH = $bits(
      if_id_t
  ) + $bits(
      id_ex_t
  ) + $bits(
      ex_mem_t
  ) + $bits(
      mem_wb_t
  );
  tp3_case_data data ();
  if_id_t ifid, ifid_probe;
  id_ex_t idex, idex_probe;
  ex_mem_t exmem, exmem_probe;
  mem_wb_t memwb, memwb_probe;
  forward_sel_t forward_probe;
  access_size_t access_probe;
  integer       checked_controls = 0;
  integer       checked_selector_types = 0;
  integer       checked_selector_codes = 0;

  // Informa el fallo del caso y termina la simulación con código distinto de cero.
  function automatic void fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endfunction

  // Busca un campo por nombre en el fixture y exige que aparezca exactamente una vez.
  function automatic integer field_index(input string latch_name, input string field_name);
    integer found;
    string  base;
    base  = {"/latch_fixture/", latch_name};
    found = -1;
    for (integer index = 0; index < data.get_size(base); index = index + 1) begin
      if (data.get_string($sformatf("%s/%0d/name", base, index)) == field_name) begin
        if (found != -1) fail({"duplicate fixture field: ", latch_name, ".", field_name});
        found = index;
      end
    end
    if (found == -1) fail({"missing fixture field: ", latch_name, ".", field_name});
    field_index = found;
  endfunction

  // Obtiene del fixture el ancho esperado para un campo del latch.
  function automatic integer fixture_width(input string latch_name, input string field_name);
    fixture_width = data.get_integer(
        $sformatf("/latch_fixture/%s/%0d/width", latch_name, field_index(latch_name, field_name)));
  endfunction

  // Lee el estímulo del fixture y exige que su ancho coincida y el valor quepa en el campo.
  function automatic logic [63:0] fixture_value(input string latch_name, input string field_name,
                                                input integer actual_width);
    longint signed value;
    if (actual_width != fixture_width(latch_name, field_name)) begin
      fail({"field width differs from fixture: ", latch_name, ".", field_name});
    end
    value = data.get_integer(
        $sformatf("/latch_fixture/%s/%0d/value", latch_name, field_index(latch_name, field_name)));
    if (value < 0 || (value >> actual_width) != 0) begin
      fail({"fixture value does not fit field: ", latch_name, ".", field_name});
    end
    fixture_value = value;
  endfunction

  // Construye la máscara esperada del campo para comprobar su posición y la conservación de X.
  task automatic check_member_position(input string latch_name, input string field_name,
                                       input logic [PACKED_WIDTH-1:0] observed,
                                       input bit unknown_bits);
    logic   [PACKED_WIDTH-1:0] expected_mask;
    integer                    width;
    string                     base;
    base          = {"/latch_fixture/", latch_name};
    expected_mask = '0;
    for (integer index = 0; index < data.get_size(base); index = index + 1) begin
      width = data.get_integer($sformatf("%s/%0d/width", base, index));
      if (width < 1 || width > PACKED_WIDTH) fail("fixture width exceeds packed representation");
      expected_mask = expected_mask << width;
      if (data.get_string($sformatf("%s/%0d/name", base, index)) == field_name) begin
        expected_mask = expected_mask | ({PACKED_WIDTH{1'b1}} >> (PACKED_WIDTH - width));
      end
    end
    if (unknown_bits) begin
      for (integer index = 0; index < PACKED_WIDTH; index = index + 1) begin
        if (expected_mask[index]) expected_mask[index] = 1'bx;
      end
    end
    if (observed !== expected_mask) begin
      fail({
           "field position or four-state representation differs from fixture: ",
           latch_name,
           ".",
           field_name
           });
    end
  endtask

  // Reconstruye el valor packed desde el fixture y compara el ancho y el orden de campos.
  task automatic check_layout(input string latch_name, input integer actual_width,
                              input logic [PACKED_WIDTH-1:0] observed);
    logic   [PACKED_WIDTH-1:0] expected_packed;
    integer                    width;
    integer                    total_width;
    string                     base;
    base            = {"/latch_fixture/", latch_name};
    expected_packed = '0;
    total_width     = 0;
    for (integer index = 0; index < data.get_size(base); index = index + 1) begin
      width = data.get_integer($sformatf("%s/%0d/width", base, index));
      total_width = total_width + width;
      expected_packed = (expected_packed << width) |
          $unsigned(data.get_integer($sformatf("%s/%0d/value", base, index)));
    end
    if (actual_width != total_width || observed !== expected_packed) begin
      fail({"packed layout differs from fixture: ", latch_name});
    end
  endtask

  // Compara el ancho y la codificación de un control con las expectativas del caso.
  task automatic check_control(input string name, input integer actual_width,
                               input logic [63:0] observed, input integer expected_width);
    if (actual_width != expected_width || observed !== $unsigned(
            data.get_integer({"/expected/control_codes/", name})
        )) begin
      fail({"control encoding differs from manifest: ", name});
    end
    checked_controls = checked_controls + 1;
  endtask

  // Comprueba el ancho y el código de un selector dentro de su familia en el JSON.
  task automatic check_selector(input string selector_name, input string code_name,
                                input integer actual_width, input logic [63:0] observed);
    string base;
    base = {"/expected/selectors/", selector_name};
    if (actual_width != data.get_integer(
            {base, "/width"}
        ) || observed !== $unsigned(
            data.get_integer({base, "/codes/", code_name})
        )) begin
      fail({"selector encoding differs from manifest: ", code_name});
    end
    checked_selector_codes = checked_selector_codes + 1;
  endtask

  // Los nombres identifican miembros HDL; anchos, posiciones y valores vienen del JSON.
  `define CHECK_LATCH_FIELD(LATCH, FIELD) \
    LATCH.FIELD = fixture_value(`"LATCH`", `"FIELD`", $bits(LATCH.FIELD)); \
    LATCH``_probe = '0; \
    LATCH``_probe.FIELD = '1; \
    if (LATCH``_probe.FIELD < 0) begin \
      fail("latch fields must be unsigned"); end \
    check_member_position(`"LATCH`", `"FIELD`", LATCH``_probe, 1'b0); \
    LATCH``_probe.FIELD = 'x; \
    check_member_position(`"LATCH`", `"FIELD`", LATCH``_probe, 1'b1);

  `define CHECK_CONTROL(LATCH, FIELD, NAME) \
    check_control(`"NAME`", $bits(NAME), NAME, fixture_width(`"LATCH`", `"FIELD`"));

  `define CHECK_SELECTOR_TYPE(KEY, TYPE, PROBE) \
    if ($bits(TYPE) != data.get_integer({"/expected/selectors/", KEY, "/width"})) begin \
      fail({"selector width differs from manifest: ", KEY}); end \
    PROBE = '1; \
    if (PROBE < 0) begin \
      fail({"selector type must be unsigned: ", KEY}); end \
    PROBE = 'x; \
    if (PROBE !== 'x) begin \
      fail({"selector type must preserve X: ", KEY}); end \
    PROBE = 'z; \
    if (PROBE !== 'z) begin \
      fail({"selector type must preserve Z: ", KEY}); end \
    checked_selector_types = checked_selector_types + 1;

  `define CHECK_SELECTOR(KEY, NAME) \
    check_selector(KEY, `"NAME`", $bits(NAME), NAME);

  initial begin
    data.load();
    ifid  = '0;
    idex  = '0;
    exmem = '0;
    memwb = '0;

    `CHECK_LATCH_FIELD(ifid, valid)
    `CHECK_LATCH_FIELD(ifid, pc)
    `CHECK_LATCH_FIELD(ifid, instruction)
    `CHECK_LATCH_FIELD(ifid, fetch_fault_valid)
    `CHECK_LATCH_FIELD(ifid, fetch_fault_cause)

    `CHECK_LATCH_FIELD(idex, valid)
    `CHECK_LATCH_FIELD(idex, pc)
    `CHECK_LATCH_FIELD(idex, instruction)
    `CHECK_LATCH_FIELD(idex, rs1)
    `CHECK_LATCH_FIELD(idex, rs2)
    `CHECK_LATCH_FIELD(idex, rd)
    `CHECK_LATCH_FIELD(idex, rs1_value)
    `CHECK_LATCH_FIELD(idex, rs2_value)
    `CHECK_LATCH_FIELD(idex, immediate)
    `CHECK_LATCH_FIELD(idex, alu_op)
    `CHECK_LATCH_FIELD(idex, alu_src)
    `CHECK_LATCH_FIELD(idex, result_sel)
    `CHECK_LATCH_FIELD(idex, flow_op)
    `CHECK_LATCH_FIELD(idex, mem_op)
    `CHECK_LATCH_FIELD(idex, reg_write)

    `CHECK_LATCH_FIELD(exmem, valid)
    `CHECK_LATCH_FIELD(exmem, pc)
    `CHECK_LATCH_FIELD(exmem, instruction)
    `CHECK_LATCH_FIELD(exmem, rd)
    `CHECK_LATCH_FIELD(exmem, reg_write)
    `CHECK_LATCH_FIELD(exmem, mem_op)
    `CHECK_LATCH_FIELD(exmem, ex_result)
    `CHECK_LATCH_FIELD(exmem, store_data)

    `CHECK_LATCH_FIELD(memwb, valid)
    `CHECK_LATCH_FIELD(memwb, pc)
    `CHECK_LATCH_FIELD(memwb, instruction)
    `CHECK_LATCH_FIELD(memwb, rd)
    `CHECK_LATCH_FIELD(memwb, reg_write)
    `CHECK_LATCH_FIELD(memwb, wb_value)

    check_layout("ifid", $bits(if_id_t), ifid);
    check_layout("idex", $bits(id_ex_t), idex);
    check_layout("exmem", $bits(ex_mem_t), exmem);
    check_layout("memwb", $bits(mem_wb_t), memwb);

    `CHECK_CONTROL(idex, alu_op, ALU_OP_SLL)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_SRL)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_SRA)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_SLT)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_SLTU)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_ADD)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_SUB)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_AND)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_OR)
    `CHECK_CONTROL(idex, alu_op, ALU_OP_XOR)
    `CHECK_CONTROL(idex, alu_src, ALU_SRC_RS2)
    `CHECK_CONTROL(idex, alu_src, ALU_SRC_IMMEDIATE)
    `CHECK_CONTROL(idex, result_sel, RESULT_SEL_ALU)
    `CHECK_CONTROL(idex, result_sel, RESULT_SEL_IMMEDIATE)
    `CHECK_CONTROL(idex, result_sel, RESULT_SEL_LINK)
    `CHECK_CONTROL(idex, flow_op, FLOW_OP_NONE)
    `CHECK_CONTROL(idex, flow_op, FLOW_OP_BEQ)
    `CHECK_CONTROL(idex, flow_op, FLOW_OP_BNE)
    `CHECK_CONTROL(idex, flow_op, FLOW_OP_JAL)
    `CHECK_CONTROL(idex, flow_op, FLOW_OP_JALR)
    `CHECK_CONTROL(idex, flow_op, FLOW_OP_HALT)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_NONE)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_LB)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_LH)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_LW)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_LBU)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_LHU)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_SB)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_SH)
    `CHECK_CONTROL(idex, mem_op, MEM_OP_SW)
    `CHECK_CONTROL(ifid, fetch_fault_cause, FAULT_INSTRUCTION_ADDRESS_MISALIGNED)
    `CHECK_CONTROL(ifid, fetch_fault_cause, FAULT_INSTRUCTION_ACCESS_FAULT)
    `CHECK_CONTROL(ifid, fetch_fault_cause, FAULT_ILLEGAL_INSTRUCTION)
    `CHECK_CONTROL(ifid, fetch_fault_cause, FAULT_LOAD_ADDRESS_MISALIGNED)
    `CHECK_CONTROL(ifid, fetch_fault_cause, FAULT_LOAD_ACCESS_FAULT)
    `CHECK_CONTROL(ifid, fetch_fault_cause, FAULT_STORE_ADDRESS_MISALIGNED)
    `CHECK_CONTROL(ifid, fetch_fault_cause, FAULT_STORE_ACCESS_FAULT)

    if (checked_controls != data.get_size("/expected/control_codes")) begin
      fail("control catalogue contains unchecked entries");
    end

    `CHECK_SELECTOR_TYPE("forward_sel", forward_sel_t, forward_probe)
    `CHECK_SELECTOR_TYPE("access_size", access_size_t, access_probe)
    `CHECK_SELECTOR("forward_sel", FORWARD_SEL_ID_EX)
    `CHECK_SELECTOR("forward_sel", FORWARD_SEL_EX_MEM)
    `CHECK_SELECTOR("forward_sel", FORWARD_SEL_MEM_WB)
    `CHECK_SELECTOR("access_size", ACCESS_SIZE_BYTE)
    `CHECK_SELECTOR("access_size", ACCESS_SIZE_HALFWORD)
    `CHECK_SELECTOR("access_size", ACCESS_SIZE_WORD)
    if (checked_selector_types != data.get_size(
            "/expected/selectors"
        ) || checked_selector_codes != data.get_size(
            "/expected/selectors/forward_sel/codes"
        ) + data.get_size(
            "/expected/selectors/access_size/codes"
        )) begin
      fail("selector catalogue contains unchecked entries");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
  `undef CHECK_LATCH_FIELD
  `undef CHECK_CONTROL
  `undef CHECK_SELECTOR_TYPE
  `undef CHECK_SELECTOR
endmodule

// Comprueba la configuración compartida de clock, UART y tiempos del protocolo.
module system_pkg_clock_uart_tb;
  import system_pkg::*;
  tp3_case_data data ();
  integer checked_constants = 0;
  integer checked_times = 0;

  // Informa el fallo del caso y termina la simulación con código distinto de cero.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  // Lee la expectativa numérica o booleana y compara una constante de clock/UART.
  task automatic check_constant(input string name, input logic [63:0] observed);
    string        path;
    logic  [63:0] expected_value;
    path = {"/expected/clock_uart_configuration/", name};
    if (data.get_type(path) == "boolean") begin
      expected_value = data.get_boolean(path);
    end else begin
      expected_value = $unsigned(data.get_integer(path));
    end
    if (observed !== expected_value) begin
      fail({"shared clock/UART constant differs from manifest: ", name});
    end
    checked_constants = checked_constants + 1;
  endtask

  // Compara el valor y el ancho de un plazo de protocolo con los datos del caso.
  task automatic check_protocol_time(input string name, input integer actual_width,
                                     input logic [63:0] observed);
    if (actual_width != data.get_integer(
            "/expected/protocol_timing/width"
        ) || observed !== $unsigned(
            data.get_integer({"/expected/protocol_timing/constants/", name})
        )) begin
      fail({"protocol timing differs from manifest: ", name});
    end
    checked_times = checked_times + 1;
  endtask

  `define CHECK_CLOCK_UART(NAME) check_constant(`"NAME`", NAME);
  `define CHECK_PROTOCOL_TIME(NAME) \
    if (~NAME < 0) begin \
      fail({"protocol timing must be unsigned: ", `"NAME`"}); end \
    check_protocol_time(`"NAME`", $bits(NAME), NAME);
  initial begin
    data.load();
    `CHECK_CLOCK_UART(FUNCTIONAL_CLOCK_HZ)
    `CHECK_CLOCK_UART(UART_BAUD_RATE)
    `CHECK_CLOCK_UART(UART_DATA_BITS)
    `CHECK_CLOCK_UART(UART_PARITY_ENABLED)
    `CHECK_CLOCK_UART(UART_STOP_BITS)
    `CHECK_CLOCK_UART(UART_OVERSAMPLE_FACTOR)
    `CHECK_CLOCK_UART(UART_FIFO_DEPTH)
    if (checked_constants != data.get_size("/expected/clock_uart_configuration")) begin
      fail("clock/UART configuration contains unchecked entries");
    end
    `CHECK_PROTOCOL_TIME(PROTOCOL_LOAD_INACTIVITY_MS)
    `CHECK_PROTOCOL_TIME(PROTOCOL_RECOVERY_SILENCE_MS)
    `CHECK_PROTOCOL_TIME(PROTOCOL_LOAD_INACTIVITY_CYCLES)
    `CHECK_PROTOCOL_TIME(PROTOCOL_RECOVERY_SILENCE_CYCLES)
    if (checked_times != data.get_size("/expected/protocol_timing/constants")) begin
      fail("protocol timing catalogue contains unchecked entries");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
  `undef CHECK_CLOCK_UART
  `undef CHECK_PROTOCOL_TIME
endmodule

// Comprueba los códigos y tipos de comandos, resultados y estado externo.
module system_pkg_protocol_codes_tb;
  import system_pkg::*;
  tp3_case_data data ();
  protocol_opcode_t   opcode_probe;
  protocol_result_t   result_probe;
  global_state_code_t state_probe;
  integer             checked_types = 0;
  integer             checked_codes = 0;

  // Informa el fallo del caso y termina la simulación con código distinto de cero.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  // Comprueba el ancho y el valor de un código en su familia del protocolo.
  task automatic check_code(input string family, input string name, input integer actual_width,
                            input logic [63:0] observed);
    string base;
    base = {"/expected/protocol_codes/", family};
    if (actual_width != data.get_integer(
            {base, "/width"}
        ) || observed !== $unsigned(
            data.get_integer({base, "/codes/", name})
        )) begin
      fail({"protocol code differs from manifest: ", name});
    end
    checked_codes = checked_codes + 1;
  endtask

  `define CHECK_PROTOCOL_TYPE(KEY, TYPE, PROBE) \
    if ($bits(TYPE) != data.get_integer({"/expected/protocol_codes/", KEY, "/width"})) begin \
      fail({"protocol type width differs from manifest: ", KEY}); end \
    PROBE = '1; \
    if (PROBE < 0) begin \
      fail({"protocol type must be unsigned: ", KEY}); end \
    PROBE = 'x; \
    if (PROBE !== 'x) begin \
      fail({"protocol type must preserve X: ", KEY}); end \
    PROBE = 'z; \
    if (PROBE !== 'z) begin \
      fail({"protocol type must preserve Z: ", KEY}); end \
    checked_types = checked_types + 1;

  `define CHECK_PROTOCOL_CODE(KEY, NAME) check_code(KEY, `"NAME`", $bits(NAME), NAME);

  initial begin
    data.load();
    `CHECK_PROTOCOL_TYPE("opcode", protocol_opcode_t, opcode_probe)
    `CHECK_PROTOCOL_TYPE("result", protocol_result_t, result_probe)
    `CHECK_PROTOCOL_TYPE("state_code", global_state_code_t, state_probe)

    `CHECK_PROTOCOL_CODE("opcode", CMD_LOAD)
    `CHECK_PROTOCOL_CODE("opcode", CMD_RUN)
    `CHECK_PROTOCOL_CODE("opcode", CMD_STEP)
    `CHECK_PROTOCOL_CODE("opcode", CMD_RESET)
    `CHECK_PROTOCOL_CODE("opcode", CMD_CHECK_READY)
    `CHECK_PROTOCOL_CODE("result", RESULT_ACCEPTED)
    `CHECK_PROTOCOL_CODE("result", RESULT_DONE)
    `CHECK_PROTOCOL_CODE("result", RESULT_READY)
    `CHECK_PROTOCOL_CODE("result", RESULT_BUSY)
    `CHECK_PROTOCOL_CODE("result", RESULT_NO_IMAGE)
    `CHECK_PROTOCOL_CODE("result", RESULT_INVALID_SIZE)
    `CHECK_PROTOCOL_CODE("result", RESULT_INCOMPLETE_REQUEST)
    `CHECK_PROTOCOL_CODE("result", RESULT_INCOMPLETE_DATA)
    `CHECK_PROTOCOL_CODE("result", RESULT_UART_ERROR)
    `CHECK_PROTOCOL_CODE("result", RESULT_FINISHED)
    `CHECK_PROTOCOL_CODE("result", RESULT_FAULT)
    `CHECK_PROTOCOL_CODE("result", RESULT_UNKNOWN_COMMAND)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_NO_IMAGE)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_LOADING)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_PREPARING_READY)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_READY)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_RUNNING)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_STEPPING)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_HALT_DRAIN_AUTO)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_HALT_DRAIN_STEP)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_FAULT_DRAIN_AUTO)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_FAULT_DRAIN_STEP)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_FINISHED)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_FAULT)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_PREPARING_RUN)
    `CHECK_PROTOCOL_CODE("state_code", STATE_CODE_PREPARING_STEP)

    if (checked_types != data.get_size(
            "/expected/protocol_codes"
        ) || checked_codes != data.get_size(
            "/expected/protocol_codes/opcode/codes"
        ) + data.get_size(
            "/expected/protocol_codes/result/codes"
        ) + data.get_size(
            "/expected/protocol_codes/state_code/codes"
        )) begin
      fail("protocol code catalogue contains unchecked entries");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
  `undef CHECK_PROTOCOL_TYPE
  `undef CHECK_PROTOCOL_CODE
endmodule

// Comprueba los tamaños y offsets del transporte frente a las expectativas del caso.
module system_pkg_protocol_layout_tb;
  import system_pkg::*;
  tp3_case_data data ();
  integer checked_constants = 0;

  // Compara un tamaño u offset del transporte con el valor esperado del manifiesto.
  task automatic check_layout_constant(input string name, input logic [63:0] observed);
    if (observed !== $unsigned(data.get_integer({"/expected/protocol_layout/", name}))) begin
      $display("FAIL %s protocol layout differs from manifest: %s", data.case_id, name);
      $fatal(1, "protocol layout differs from manifest: %s", name);
    end
    checked_constants = checked_constants + 1;
  endtask

  `define CHECK_PROTOCOL_LAYOUT(NAME) check_layout_constant(`"NAME`", NAME);
  initial begin
    data.load();
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_CODE_BYTES)
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_WORD_BYTES)
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_COUNTER_BYTES)
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_SIZE_BYTES)
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_RESPONSE_OPCODE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_RESPONSE_RESULT_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_RESPONSE_HEADER_BYTES)
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_LOAD_SIZE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(PROTOCOL_LOAD_HEADER_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_STATE_CODE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IMAGE_VALID_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_PC_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_CYCLE_COUNT_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_FAULT_CAUSE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_FAULT_PC_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_CONTEXT_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_RF_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_RF_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IFID_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IFID_VALID_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IFID_PC_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IFID_INSTRUCTION_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IFID_FETCH_FAULT_VALID_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IFID_FETCH_FAULT_CAUSE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IFID_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_VALID_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_PC_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_INSTRUCTION_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_RS1_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_RS2_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_RD_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_RS1_VALUE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_RS2_VALUE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_IMMEDIATE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_ALU_OP_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_ALU_SRC_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_RESULT_SEL_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_FLOW_OP_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_MEM_OP_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_REG_WRITE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_IDEX_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_VALID_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_PC_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_INSTRUCTION_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_RD_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_REG_WRITE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_MEM_OP_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_EX_RESULT_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_STORE_DATA_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_EXMEM_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMWB_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMWB_VALID_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMWB_PC_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMWB_INSTRUCTION_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMWB_RD_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMWB_REG_WRITE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMWB_WB_VALUE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMWB_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_USED_COUNT_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_USED_COUNT_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMORY_LIST_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_FIXED_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_RESPONSE_FIXED_BYTES)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMORY_ADDRESS_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMORY_VALUE_OFFSET)
    `CHECK_PROTOCOL_LAYOUT(DEBUG_MEMORY_ENTRY_BYTES)
    if (checked_constants != data.get_size("/expected/protocol_layout")) begin
      $display("FAIL %s protocol layout contains unchecked entries", data.case_id);
      $fatal(1, "protocol layout contains unchecked entries");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
  `undef CHECK_PROTOCOL_LAYOUT
endmodule

// Comprueba la elaboración de los consumidores de prueba con las capacidades mínimas.
module system_pkg_minimum_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0
);
  tp3_case_data data ();
  wire imem_positive_widths, dmem_positive_widths;
  wire imem_one_row, dmem_one_row;

  system_pkg_minimum_memory_fixture #(
      .CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) imem (
      .positive_widths(imem_positive_widths),
      .one_row        (imem_one_row)
  );
  system_pkg_minimum_memory_fixture #(
      .CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dmem (
      .positive_widths(dmem_positive_widths),
      .one_row        (dmem_one_row)
  );

  // Informa el fallo del caso y termina la simulación con código distinto de cero.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  initial begin
    data.load();
    if (IMEM_CAPACITY_BYTES !== $unsigned(
            data.get_integer("/inputs/IMEM_C")
        ) || DMEM_CAPACITY_BYTES !== $unsigned(
            data.get_integer("/inputs/DMEM_C")
        )) begin
      fail("elaborated capacities differ from manifest");
    end
    if (!system_pkg::memory_capacity_valid(
            IMEM_CAPACITY_BYTES
        ) || !system_pkg::memory_capacity_valid(
            DMEM_CAPACITY_BYTES
        )) begin
      fail("minimum configuration has an invalid capacity");
    end
    #1;
    if ((imem_positive_widths && dmem_positive_widths) !== data.get_boolean(
            "/expected/positive_widths"
        )) begin
      fail("consumer vector widths differ from manifest");
    end
    if ((imem_one_row && dmem_one_row) !== data.get_boolean("/expected/one_row")) begin
      fail("consumer row counts differ from manifest");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
