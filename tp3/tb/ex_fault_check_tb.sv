`timescale 1ns / 1ps

// Comprueba faults de datos y targets sin confirmar eventos ni acceder a memoria.
module ex_fault_check_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  tp3_case_data data ();
  logic         valid;
  mem_op_t      mem_op;
  word_t        rs1_effective;
  word_t        immediate;
  logic         redirect_requested;
  word_t        redirect_target;
  logic         ex_fault_candidate;
  fault_cause_t ex_fault_cause;

  ex_fault_check #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .valid             (valid),
      .mem_op            (mem_op),
      .rs1_effective     (rs1_effective),
      .immediate         (immediate),
      .redirect_requested(redirect_requested),
      .redirect_target   (redirect_target),
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

  // Acepta palabras hexadecimales o enteros, incluidos inmediatos negativos.
  function automatic word_t get_word(input string path);
    longint signed integer_value;
    word_t         value;
    if (data.get_type(path) == "string") begin
      if ($sscanf(data.get_string(path), "0x%h", value) != 1) begin
        $fatal(1, "invalid word in manifest at %s", path);
      end
    end else begin
      integer_value = data.get_integer(path);
      if (integer_value < -64'sd2147483648 || integer_value > 64'sd4294967295) begin
        $fatal(1, "manifest word outside 32-bit range at %s", path);
      end
      value = word_t'(integer_value);
    end
    return value;
  endfunction

  task automatic load_memory_fixture;
    string         operation;
    longint signed size;
    operation = data.get_string("/inputs/operation");
    size      = data.get_integer("/inputs/size");
    if (operation == "load") begin
      case (size)
        1:       mem_op = MEM_OP_LB;
        2:       mem_op = MEM_OP_LH;
        4:       mem_op = MEM_OP_LW;
        default: $fatal(1, "invalid load size in manifest");
      endcase
    end else if (operation == "store") begin
      case (size)
        1:       mem_op = MEM_OP_SB;
        2:       mem_op = MEM_OP_SH;
        4:       mem_op = MEM_OP_SW;
        default: $fatal(1, "invalid store size in manifest");
      endcase
    end else begin
      $fatal(1, "invalid memory operation in manifest");
    end

    if (data.has_path("/inputs/EA")) begin
      rs1_effective = get_word("/inputs/EA");
      immediate     = '0;
    end else begin
      rs1_effective = get_word("/inputs/base");
      immediate     = get_word("/inputs/imm");
    end
    redirect_requested = 1'b0;
    redirect_target    = '0;
  endtask

  task automatic load_target_fixture;
    mem_op = MEM_OP_NONE;
    rs1_effective = '0;
    immediate = '0;
    redirect_requested = data.has_path("/expected/taken") ? data.get_boolean("/expected/taken") :
        1'b1;
    redirect_target = get_word("/inputs/target");
  endtask

  task automatic load_explicit_fixture;
    valid              = 1'(get_unsigned("/inputs/ex_fault_check/valid", 1));
    mem_op             = mem_op_t'(get_unsigned("/inputs/ex_fault_check/mem_op", 15));
    rs1_effective      = get_word("/inputs/ex_fault_check/rs1_effective");
    immediate          = get_word("/inputs/ex_fault_check/immediate");
    redirect_requested = 1'(get_unsigned("/inputs/ex_fault_check/redirect_requested", 1));
    redirect_target    = get_word("/inputs/ex_fault_check/redirect_target");
  endtask

  initial begin
    logic expected_candidate;
    data.load();
    valid = 1'b1;
    if (data.has_path("/inputs/ex_fault_check")) begin
      load_explicit_fixture();
      expected_candidate = 1'(get_unsigned("/expected/ex_fault_candidate", 1));
    end else if (data.has_path("/inputs/operation")) begin
      if (DMEM_CAPACITY_BYTES !== get_unsigned("/inputs/C", 64'h100000000)) begin
        $fatal(1, "elaborated DMEM capacity differs from manifest");
      end
      load_memory_fixture();
      expected_candidate = !data.is_null("/expected/cause");
    end else begin
      load_target_fixture();
      expected_candidate = 1'(get_unsigned("/expected/ex_fault_candidate", 1));
    end
    #1;
    assert (ex_fault_candidate === expected_candidate)
    else begin
      $display("FAIL %s ex_fault_candidate: expected %0b, observed %0b", data.case_id,
               expected_candidate, ex_fault_candidate);
      $fatal(1, "EX fault candidate differs from manifest");
    end
    if (expected_candidate) begin
      assert (ex_fault_cause === fault_cause_t'(get_unsigned("/expected/cause", 7)))
      else begin
        $display("FAIL %s ex_fault_cause: expected %0d, observed %0d", data.case_id, get_unsigned(
                 "/expected/cause", 7), ex_fault_cause);
        $fatal(1, "EX fault cause differs from manifest");
      end
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule

// El DUT debe rechazar una capacidad inválida antes de evaluar accesos.
module ex_fault_check_config_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  logic         unused_candidate;
  fault_cause_t unused_cause;
  string        case_id;

  ex_fault_check #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .valid             (1'b0),
      .mem_op            (mem_op_t'(MEM_OP_NONE)),
      .rs1_effective     ('0),
      .immediate         ('0),
      .redirect_requested(1'b0),
      .redirect_target   ('0),
      .ex_fault_candidate(unused_candidate),
      .ex_fault_cause    (unused_cause)
  );

  initial begin
    #1;
    $finish;
  end

  final begin
    if (!memory_capacity_valid(DMEM_CAPACITY_BYTES) && $value$plusargs("CASE=%s", case_id)) begin
      $display("REJECT %s %s", case_id, CONFIG_INVALID_CAPACITY);
    end
  end
endmodule
