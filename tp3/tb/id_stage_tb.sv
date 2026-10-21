`timescale 1ns / 1ps

// Comprueba la etapa con secuencias explícitas de WB, IF/ID, productor y Debug.
module id_stage_tb;
  import system_pkg::*;

  tp3_case_data data ();
  logic            clk = 1'b0;
  logic            reset = 1'b0;
  logic            prepare_init = 1'b0;
  if_id_t          ifid = '0;
  logic            idex_valid = 1'b0;
  register_index_t idex_rd = '0;
  mem_op_t         idex_mem_op = MEM_OP_NONE;
  register_index_t rf_write_addr = '0;
  word_t           rf_write_data = '0;
  logic            rf_write_fire = 1'b0;
  logic            bypass_rs1 = 1'b0;
  logic            bypass_rs2 = 1'b0;
  logic            debug_read_select = 1'b0;
  register_index_t debug_rf_addr = '0;
  id_ex_t          idex_input;
  logic            id_fault_candidate;
  fault_cause_t    id_fault_cause;
  word_t           id_fault_pc;
  logic            load_use_stall;
  word_t           debug_rf_data;

  id_stage dut (
      .clk               (clk),
      .reset             (reset),
      .prepare_init      (prepare_init),
      .ifid              (ifid),
      .idex_valid        (idex_valid),
      .idex_rd           (idex_rd),
      .idex_mem_op       (idex_mem_op),
      .rf_write_addr     (rf_write_addr),
      .rf_write_data     (rf_write_data),
      .rf_write_fire     (rf_write_fire),
      .bypass_rs1        (bypass_rs1),
      .bypass_rs2        (bypass_rs2),
      .debug_read_select (debug_read_select),
      .debug_rf_addr     (debug_rf_addr),
      .idex_input        (idex_input),
      .id_fault_candidate(id_fault_candidate),
      .id_fault_cause    (id_fault_cause),
      .id_fault_pc       (id_fault_pc),
      .load_use_stall    (load_use_stall),
      .debug_rf_data     (debug_rf_data)
  );

  always #5 clk = ~clk;

  // Conserva el rango antes de convertir enteros, booleanos o palabras hexadecimales.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed   integer_value;
    longint unsigned value;
    if (data.get_type(path) == "integer") begin
      integer_value = data.get_integer(path);
      if (integer_value < 0) $fatal(1, "negative unsigned value at %s", path);
      value = $unsigned(integer_value);
    end else if (data.get_type(path) == "boolean") begin
      value = 64'(data.get_boolean(path));
    end else if (data.get_type(path) == "string") begin
      if ($sscanf(data.get_string(path), "0x%h", value) != 1) begin
        $fatal(1, "invalid hexadecimal word at %s", path);
      end
    end else begin
      $fatal(1, "unsupported numeric value at %s", path);
    end
    if (value > maximum) $fatal(1, "value outside port range at %s", path);
    return value;
  endfunction

  // Toda expectativa se obtiene del JSON; la comparación estricta también rechaza X/Z.
  task automatic check_value(input string path, input logic [63:0] observed,
                             input longint unsigned maximum = 64'hffffffff);
    longint unsigned expected_value;
    expected_value = get_unsigned(path, maximum);
    assert (observed === expected_value)
    else begin
      $display("FAIL %s %s: expected %0h, observed %0h", data.case_id, path, expected_value,
               observed);
      $fatal(1, "ID stage output differs from manifest");
    end
  endtask

  // Cada caso reinicia y carga RF por la interfaz funcional que recibirá WB.
  task automatic load_fixture();
    if (data.get_size("/inputs/initial_rf") != 32) begin
      $fatal(1, "RF fixture must contain 32 registers");
    end
    @(negedge clk);
    reset = 1'b1;
    @(posedge clk);
    #1;
    @(negedge clk);
    reset = 1'b0;
    for (int index = 1; index < data.get_size("/inputs/initial_rf"); index++) begin
      rf_write_fire = 1'b1;
      rf_write_addr = register_index_t'(index);
      rf_write_data =
          word_t'(get_unsigned($sformatf("/inputs/initial_rf/%0d", index), 64'hffffffff));
      @(posedge clk);
      #1;
      @(negedge clk);
    end
    rf_write_fire = 1'b0;
  endtask

  // Presenta el siguiente contexto entre flancos; no calcula decisiones de WB o hazards.
  task automatic apply_step(input string path);
    reset                  = 1'(get_unsigned({path, "/reset"}, 1));
    prepare_init           = 1'(get_unsigned({path, "/prepare_init"}, 1));
    ifid.valid             = 1'(get_unsigned({path, "/ifid/valid"}, 1));
    ifid.pc                = word_t'(get_unsigned({path, "/ifid/pc"}, 64'hffffffff));
    ifid.instruction       = word_t'(get_unsigned({path, "/ifid/instruction"}, 64'hffffffff));
    ifid.fetch_fault_valid = 1'(get_unsigned({path, "/ifid/fetch_fault_valid"}, 1));
    ifid.fetch_fault_cause = fault_cause_t'(get_unsigned({path, "/ifid/fetch_fault_cause"}, 7));
    idex_valid             = 1'(get_unsigned({path, "/idex_valid"}, 1));
    idex_rd                = register_index_t'(get_unsigned({path, "/idex_rd"}, 31));
    idex_mem_op            = mem_op_t'(get_unsigned({path, "/idex_mem_op"}, 15));
    rf_write_addr          = register_index_t'(get_unsigned({path, "/rf_write_addr"}, 31));
    rf_write_data          = word_t'(get_unsigned({path, "/rf_write_data"}, 64'hffffffff));
    rf_write_fire          = 1'(get_unsigned({path, "/rf_write_fire"}, 1));
    bypass_rs1             = 1'(get_unsigned({path, "/bypass_rs1"}, 1));
    bypass_rs2             = 1'(get_unsigned({path, "/bypass_rs2"}, 1));
    debug_read_select      = 1'(get_unsigned({path, "/debug_read_select"}, 1));
    debug_rf_addr          = register_index_t'(get_unsigned({path, "/debug_rf_addr"}, 31));
  endtask

  // Observa los quince campos antes de la captura externa de ID/EX.
  task automatic check_step(input string path);
    check_value({path, "/idex_input/valid"}, idex_input.valid, 1);
    check_value({path, "/idex_input/pc"}, idex_input.pc);
    check_value({path, "/idex_input/instruction"}, idex_input.instruction);
    check_value({path, "/idex_input/rs1"}, idex_input.rs1, 31);
    check_value({path, "/idex_input/rs2"}, idex_input.rs2, 31);
    check_value({path, "/idex_input/rd"}, idex_input.rd, 31);
    check_value({path, "/idex_input/rs1_value"}, idex_input.rs1_value);
    check_value({path, "/idex_input/rs2_value"}, idex_input.rs2_value);
    check_value({path, "/idex_input/immediate"}, idex_input.immediate);
    check_value({path, "/idex_input/alu_op"}, idex_input.alu_op, 63);
    check_value({path, "/idex_input/alu_src"}, idex_input.alu_src, 1);
    check_value({path, "/idex_input/result_sel"}, idex_input.result_sel, 3);
    check_value({path, "/idex_input/flow_op"}, idex_input.flow_op, 7);
    check_value({path, "/idex_input/mem_op"}, idex_input.mem_op, 15);
    check_value({path, "/idex_input/reg_write"}, idex_input.reg_write, 1);
    check_value({path, "/id_fault_candidate"}, id_fault_candidate, 1);
    check_value({path, "/id_fault_pc"}, id_fault_pc);
    if (!data.is_null({path, "/id_fault_cause"})) begin
      check_value({path, "/id_fault_cause"}, id_fault_cause, 7);
    end
    check_value({path, "/load_use_stall"}, load_use_stall, 1);
    check_value({path, "/debug_rf_data"}, debug_rf_data);
  endtask

  initial begin
    data.load();
    if (data.get_size(
            "/inputs/id_steps"
        ) != data.get_size(
            "/expected/id_steps"
        ) || data.get_size(
            "/inputs/id_steps"
        ) == 0) begin
      $fatal(1, "ID steps and expectations must have the same nonzero length");
    end
    if (data.get_size("/expected/id_rf_after") != 32) begin
      $fatal(1, "RF expectation must contain 32 registers");
    end
    load_fixture();
    for (int step = 0; step < data.get_size("/inputs/id_steps"); step++) begin
      apply_step($sformatf("/inputs/id_steps/%0d", step));
      #1;
      check_step($sformatf("/expected/id_steps/%0d", step));
      @(posedge clk);
      #1;
      @(negedge clk);
    end

    // Revisa el estado final por Debug, sin otro flanco de escritura o inicialización.
    rf_write_fire     = 1'b0;
    reset             = 1'b0;
    prepare_init      = 1'b0;
    debug_read_select = 1'b1;
    for (int index = 0; index < data.get_size("/expected/id_rf_after"); index++) begin
      debug_rf_addr = register_index_t'(index);
      #1ps;
      check_value($sformatf("/expected/id_rf_after/%0d", index), debug_rf_data);
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
