`timescale 1ns / 1ps

// Proyecta vectores aritméticos y de forwarding a través de la etapa EX.
module ex_stage_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd2048
);
  import system_pkg::*;

  tp3_case_data data ();
  id_ex_t       idex;
  ex_mem_t      exmem_producer;
  mem_wb_t      memwb_producer;
  ex_mem_t      exmem_input;
  word_t        redirect_target;
  logic         redirect_requested;
  logic         ex_halt_candidate;
  logic         ex_fault_candidate;
  fault_cause_t ex_fault_cause;
  word_t        expected_result;
  word_t        expected_store_data;
  word_t        expected_target;
  logic         expected_redirect;
  logic         expected_halt;
  logic         expected_fault;
  fault_cause_t expected_cause;

  ex_stage #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .idex              (idex),
      .exmem_producer    (exmem_producer),
      .memwb_producer    (memwb_producer),
      .exmem_input       (exmem_input),
      .redirect_target   (redirect_target),
      .redirect_requested(redirect_requested),
      .ex_halt_candidate (ex_halt_candidate),
      .ex_fault_candidate(ex_fault_candidate),
      .ex_fault_cause    (ex_fault_cause)
  );

  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  function automatic word_t get_word(input string path);
    word_t value;
    if (data.get_type(path) == "string") begin
      if ($sscanf(data.get_string(path), "0x%h", value) != 1) begin
        $fatal(1, "invalid word in manifest at %s", path);
      end
    end else begin
      value = word_t'(data.get_integer(path));
    end
    return value;
  endfunction

  task automatic load_alu_fixture;
    idex.valid          = 1'b1;
    idex.rd             = 5'd3;
    idex.rs1            = 5'd1;
    idex.rs2            = 5'd2;
    idex.rs1_value      = get_word("/inputs/alu_a");
    idex.rs2_value      = get_word("/inputs/alu_b");
    idex.alu_op         = alu_op_t'(get_unsigned("/inputs/alu_op", 63));
    idex.alu_src        = ALU_SRC_RS2;
    idex.result_sel     = RESULT_SEL_ALU;
    idex.reg_write      = 1'b1;
    idex.mem_op         = MEM_OP_NONE;
    expected_store_data = idex.rs2_value;
  endtask

  task automatic load_forwarding_fixture;
    string source;
    string selector;
    word_t selected_value;
    source = data.get_string("/inputs/source");
    selector = data.get_string("/expected/selector");
    idex.valid = 1'(get_unsigned(data.has_path("/inputs/idex_valid") ? "/inputs/idex_valid" :
                                 "/inputs/consumer_valid", 1));
    idex.instruction = get_word("/inputs/word");
    idex.rs1 = idex.instruction[19:15];
    idex.rs2 = idex.instruction[24:20];
    idex.rs1_value = source == "A" ? get_word("/inputs/base") : '0;
    idex.rs2_value = source == "B" ? get_word("/inputs/base") : '0;
    idex.alu_op = ALU_OP_ADD;
    idex.alu_src = source == "A" ? ALU_SRC_IMMEDIATE : ALU_SRC_RS2;
    idex.immediate = '0;
    idex.result_sel = RESULT_SEL_ALU;
    idex.mem_op = MEM_OP_NONE;
    exmem_producer.valid = 1'(get_unsigned("/inputs/exmem_valid", 1));
    exmem_producer.rd = register_index_t'(get_unsigned("/inputs/exmem_rd", 31));
    exmem_producer.reg_write = 1'(get_unsigned("/inputs/exmem_reg_write", 1));
    exmem_producer.mem_op = mem_op_t'(get_unsigned("/inputs/exmem_mem_op", 15));
    exmem_producer.ex_result =
        get_word(data.has_path("/inputs/ex_value") ? "/inputs/ex_value" : "/inputs/ex_result");
    memwb_producer.valid = 1'(get_unsigned("/inputs/memwb_valid", 1));
    memwb_producer.rd = register_index_t'(get_unsigned("/inputs/memwb_rd", 31));
    memwb_producer.reg_write = 1'(get_unsigned("/inputs/memwb_reg_write", 1));
    memwb_producer.wb_value = get_word("/inputs/wb_value");

    if (data.has_path("/expected/effective_value")) begin
      selected_value = get_word("/expected/effective_value");
    end else begin
      if (selector == "00") begin
        selected_value = get_word("/inputs/base");
      end else if (selector == "01") begin
        selected_value = exmem_producer.ex_result;
      end else if (selector == "10") begin
        selected_value = memwb_producer.wb_value;
      end else begin
        $fatal(1, "reserved forwarding selector in manifest");
      end
    end
    if (source == "A") begin
      if (selector == "00") idex.rs1_value = get_word("/inputs/base");
      idex.rs2_value      = '0;
      expected_store_data = '0;
    end else begin
      idex.rs1_value = '0;
      if (selector == "00") idex.rs2_value = get_word("/inputs/base");
      expected_store_data = selected_value;
    end
    idex.reg_write  = 1'b0;
    expected_result = selected_value;
  endtask

  task automatic load_control_fixture;
    flow_op_t flow_op;
    logic     operands_equal;
    idex.valid = 1'(get_unsigned("/inputs/flow_control/valid", 1));
    flow_op = flow_op_t'(get_unsigned("/inputs/flow_control/flow_op", 7));
    idex.flow_op = flow_op;
    idex.pc = get_word("/inputs/pc");
    idex.rd = data.has_path("/inputs/rd") ? register_index_t'(get_unsigned("/inputs/rd", 31)) :
        register_index_t'(5'd0);
    idex.reg_write = data.has_path("/expected/writes_rd") ? data.get_boolean(
        "/expected/writes_rd") : (flow_op == FLOW_OP_JAL || flow_op == FLOW_OP_JALR);
    idex.result_sel = (flow_op == FLOW_OP_JAL || flow_op == FLOW_OP_JALR) ? RESULT_SEL_LINK :
        RESULT_SEL_ALU;
    idex.alu_op = ALU_OP_SUB;
    idex.alu_src = ALU_SRC_RS2;
    idex.rs1 = 5'd1;
    idex.rs2 = 5'd2;
    if (data.has_path("/inputs/x1")) begin
      idex.rs1_value = get_word("/inputs/x1");
      idex.rs2_value = data.has_path("/inputs/x2") ? get_word("/inputs/x2") : '0;
    end else if (data.has_path("/inputs/equal")) begin
      operands_equal = data.get_boolean("/inputs/equal");
      idex.rs1_value = '0;
      idex.rs2_value = operands_equal ? '0 : 32'd1;
    end else begin
      idex.rs1_value = '0;
      idex.rs2_value = '0;
    end
    if (flow_op == FLOW_OP_JALR) begin
      idex.instruction[6:0] = OPCODE_JALR;
    end else if (flow_op == FLOW_OP_JAL) begin
      idex.instruction[6:0] = OPCODE_JAL;
    end else begin
      idex.instruction[6:0] = OPCODE_BRANCH;
    end

    idex.immediate = data.has_path("/inputs/offset") ? get_word("/inputs/offset") :
        data.has_path("/inputs/imm") ? get_word("/inputs/imm") : '0;
    if (flow_op == FLOW_OP_JALR && data.has_path("/inputs/x1")) begin
      idex.rs1_value = get_word("/inputs/x1");
    end
    expected_target = data.has_path("/expected/target") ? get_word("/expected/target") :
        (flow_op == FLOW_OP_JALR ? idex.rs1_value + idex.immediate : idex.pc + idex.immediate);
    if (flow_op == FLOW_OP_JALR) expected_target[0] = 1'b0;
    expected_redirect = 1'(get_unsigned("/expected/redirect_requested", 1));
    expected_halt = 1'(get_unsigned("/expected/ex_halt_candidate", 1));
    expected_fault = data.has_path("/expected/fault") ? data.get_boolean("/expected/fault") : 1'b0;
    if (data.has_path("/expected/link")) begin
      expected_result = get_word("/expected/link");
    end
  endtask

  task automatic load_memory_fixture;
    string         operation;
    longint signed size;
    word_t         expected_address;
    operation = data.get_string("/inputs/operation");
    size      = data.get_integer("/inputs/size");
    if (operation == "load") begin
      case (size)
        1:       idex.mem_op = MEM_OP_LB;
        2:       idex.mem_op = MEM_OP_LH;
        4:       idex.mem_op = MEM_OP_LW;
        default: $fatal(1, "invalid load size in manifest");
      endcase
      idex.instruction[6:0] = OPCODE_LOAD;
    end else if (operation == "store") begin
      case (size)
        1:       idex.mem_op = MEM_OP_SB;
        2:       idex.mem_op = MEM_OP_SH;
        4:       idex.mem_op = MEM_OP_SW;
        default: $fatal(1, "invalid store size in manifest");
      endcase
      idex.instruction[6:0] = OPCODE_STORE;
    end else begin
      $fatal(1, "invalid memory operation in manifest");
    end

    idex.valid = 1'b1;
    idex.rs1 = 5'd1;
    idex.rs2 = 5'd2;
    idex.rs1_value = data.has_path("/inputs/EA") ? get_word("/inputs/EA") :
        get_word("/inputs/base");
    idex.immediate = data.has_path("/inputs/imm") ? get_word("/inputs/imm") : '0;
    idex.alu_op = ALU_OP_ADD;
    idex.alu_src = ALU_SRC_IMMEDIATE;
    idex.result_sel = RESULT_SEL_ALU;
    idex.reg_write = 1'b0;
    if (DMEM_CAPACITY_BYTES !== get_unsigned("/inputs/C", 64'h100000000)) begin
      $fatal(1, "elaborated DMEM capacity differs from manifest");
    end
    expected_address = data.has_path("/expected/EA") ?
        get_word("/expected/EA") : (idex.rs1_value + idex.immediate);
    expected_result = expected_address;
    expected_fault = !data.is_null("/expected/cause");
    if (expected_fault) expected_cause = fault_cause_t'(get_unsigned("/expected/cause", 7));
    expected_store_data = idex.rs2_value;
  endtask

  task automatic load_target_fixture;
    string    operation;
    logic     taken;
    word_t    target;
    flow_op_t flow_op;
    operation = data.get_string("/inputs/op");
    target    = get_word("/inputs/target");
    taken     = data.has_path("/inputs/taken") ? data.get_boolean("/inputs/taken") : 1'b1;
    if (operation == "BEQ") begin
      flow_op = FLOW_OP_BEQ;
    end else if (operation == "BNE") begin
      flow_op = FLOW_OP_BNE;
    end else if (operation == "JAL") begin
      flow_op = FLOW_OP_JAL;
    end else if (operation == "JALR") begin
      flow_op = FLOW_OP_JALR;
    end else begin
      $fatal(1, "invalid control operation in manifest");
    end
    idex.valid   = 1'b1;
    idex.flow_op = flow_op;
    idex.pc      = get_word("/inputs/pc");
    idex.rs1     = 5'd1;
    idex.rs2     = 5'd2;
    if (flow_op == FLOW_OP_BEQ) begin
      idex.rs1_value = '0;
      idex.rs2_value = taken ? '0 : 32'd1;
    end else if (flow_op == FLOW_OP_BNE) begin
      idex.rs1_value = '0;
      idex.rs2_value = taken ? 32'd1 : '0;
    end else if (flow_op == FLOW_OP_JALR) begin
      idex.rs1_value = target | 32'd1;
      idex.rs2_value = '0;
    end else begin
      idex.rs1_value = '0;
      idex.rs2_value = '0;
    end
    idex.instruction[6:0] = flow_op == FLOW_OP_JALR ? OPCODE_JALR :
        flow_op == FLOW_OP_JAL ? OPCODE_JAL : OPCODE_BRANCH;
    idex.immediate = flow_op == FLOW_OP_JALR ? '0 : target - idex.pc;
    idex.alu_op = ALU_OP_SUB;
    idex.alu_src = ALU_SRC_RS2;
    idex.result_sel = (flow_op == FLOW_OP_JAL || flow_op == FLOW_OP_JALR) ? RESULT_SEL_LINK :
        RESULT_SEL_ALU;
    idex.reg_write = flow_op == FLOW_OP_JAL || flow_op == FLOW_OP_JALR;
    idex.mem_op = MEM_OP_NONE;
    expected_target = target;
    expected_redirect = (flow_op == FLOW_OP_JAL || flow_op == FLOW_OP_JALR) ||
        ((flow_op == FLOW_OP_BEQ || flow_op == FLOW_OP_BNE) && taken);
    expected_halt = 1'b0;
    expected_fault = 1'(get_unsigned("/expected/ex_fault_candidate", 1));
    if (expected_fault) expected_cause = fault_cause_t'(get_unsigned("/expected/cause", 7));
    if (data.has_path("/expected/link")) expected_result = get_word("/expected/link");
  endtask

  initial begin
    data.load();
    idex           = '0;
    exmem_producer = '0;
    memwb_producer = '0;
    if (data.has_path("/inputs/alu_a")) begin
      load_alu_fixture();
      expected_result = get_word("/expected/alu_result");
    end else if (data.has_path("/inputs/flow_control")) begin
      load_control_fixture();
    end else if (data.has_path("/inputs/operation")) begin
      load_memory_fixture();
    end else if (data.has_path("/inputs/target")) begin
      load_target_fixture();
    end else begin
      load_forwarding_fixture();
    end
    #1;
    if (data.has_path(
            "/inputs/alu_a"
        ) || data.has_path(
            "/inputs/source"
        ) || data.has_path(
            "/inputs/operation"
        ) || data.has_path(
            "/expected/link"
        )) begin
      assert (exmem_input.ex_result === expected_result)
      else begin
        $display("FAIL %s exmem.ex_result: expected %08h, observed %08h", data.case_id,
                 expected_result, exmem_input.ex_result);
        $fatal(1, "EX result differs from manifest");
      end
    end
    if (data.has_path("/inputs/flow_control")) begin
      assert (redirect_target === expected_target && redirect_requested === expected_redirect &&
              ex_halt_candidate === expected_halt && ex_fault_candidate === expected_fault)
      else $fatal(1, "EX control outputs differ from manifest for %s", data.case_id);
    end else if (data.has_path("/inputs/operation")) begin
      assert (ex_fault_candidate === expected_fault && !redirect_requested && !ex_halt_candidate)
      else $fatal(1, "EX memory fault candidate differs from manifest for %s", data.case_id);
      if (expected_fault) begin
        assert (ex_fault_cause === expected_cause)
        else $fatal(1, "EX memory fault cause differs from manifest for %s", data.case_id);
      end
    end else if (data.has_path("/inputs/target")) begin
      assert (redirect_target === expected_target && redirect_requested === expected_redirect &&
              ex_fault_candidate === expected_fault && !ex_halt_candidate)
      else $fatal(1, "EX target/fault outputs differ from manifest for %s", data.case_id);
      if (expected_fault) begin
        assert (ex_fault_cause === expected_cause)
        else $fatal(1, "EX target fault cause differs from manifest for %s", data.case_id);
      end
    end else begin
      assert ((exmem_input.store_data === expected_store_data) && !redirect_requested &&
              !ex_halt_candidate && !ex_fault_candidate)
      else $fatal(1, "EX emitted an unexpected sideband value for %s", data.case_id);
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
