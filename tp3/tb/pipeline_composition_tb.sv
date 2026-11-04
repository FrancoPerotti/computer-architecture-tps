`timescale 1ns / 1ps

// Conecta el árbitro y los cuatro registros con controles locales y un PC de fixture.
module pipeline_composition_tb #(
    parameter integer TERMINAL_FIXTURE = 0,
    parameter integer FRONTIER_FIXTURE = 0,
    parameter integer FILL_FIXTURE     = 0
);
  import system_pkg::*;

  logic                  clk = 1'b0;
  logic                  reset = 1'b1;
  logic                  preload_active = 1'b0;
  logic                  cpu_cycle_fire = 1'b0;
  logic                  drain_mode = 1'b0;
  logic                  ex_fault_candidate = 1'b0;
  logic                  ex_halt_candidate = 1'b0;
  logic                  redirect_requested = 1'b0;
  logic                  id_fault_candidate = 1'b0;
  logic                  load_use_stall = 1'b0;
  logic            [7:0] actions;
  word_t                 pc;
  word_t                 preload_pc;
  word_t                 redirect_target;
  if_id_t                seed_ifid;
  if_id_t                future_ifid;
  if_id_t                ifid_in;
  if_id_t                ifid_out;
  id_ex_t                seed_idex;
  id_ex_t                future_idex;
  id_ex_t                idex_in;
  id_ex_t                idex_out;
  ex_mem_t               seed_exmem;
  ex_mem_t               future_exmem;
  ex_mem_t               exmem_in;
  ex_mem_t               exmem_out;
  mem_wb_t               seed_memwb;
  mem_wb_t               future_memwb;
  mem_wb_t               memwb_in;
  mem_wb_t               memwb_out;
  logic                  ifid_capture;
  logic                  ifid_hold;
  logic                  ifid_invalidate;
  logic                  idex_capture;
  logic                  idex_bubble;
  logic                  exmem_capture;
  logic                  exmem_invalidate;
  logic                  memwb_capture;
  logic                  ifid_valid_next;
  logic                  idex_valid_next;
  logic                  exmem_valid_next;
  logic                  memwb_valid_next;
  logic                  pipeline_empty_next;
  word_t                 observed_store_data;
  word_t                 observed_wb_value;
  logic                  observed_mem_valid;
  logic                  observed_wb_valid;
  logic                  observed_wb_reg_write;
  register_index_t       observed_wb_rd;
  mem_op_t               observed_mem_op;

  tp3_case_data data ();
  pipeline_hazard_control dut (
      .cpu_cycle_fire    (cpu_cycle_fire),
      .drain_mode        (drain_mode),
      .ex_fault_candidate(ex_fault_candidate),
      .ex_halt_candidate (ex_halt_candidate),
      .redirect_requested(redirect_requested),
      .id_fault_candidate(id_fault_candidate),
      .load_use_stall    (load_use_stall),
      .act_ex_fault      (actions[7]),
      .act_halt          (actions[6]),
      .act_redirect      (actions[5]),
      .act_id_fault      (actions[4]),
      .act_load_use      (actions[3]),
      .act_normal        (actions[2]),
      .act_drain_load_use(actions[1]),
      .act_drain_advance (actions[0])
  );

  // El preload usa los puertos de captura existentes; estos controles solo viven en el banco.
  assign ifid_capture = preload_active || actions[2];
  assign ifid_hold = !preload_active && (actions[3] || actions[1]);
  assign ifid_invalidate = !preload_active &&
      (actions[7] || actions[6] || actions[5] || actions[4] || actions[0]);
  assign idex_capture = preload_active || actions[2] || actions[0];
  assign idex_bubble = !preload_active &&
      (actions[7] || actions[6] || actions[5] || actions[4] || actions[3] || actions[1]);
  assign exmem_capture = preload_active || actions[5] || actions[4] || actions[3] || actions[2] ||
      actions[1] || actions[0];
  assign exmem_invalidate = !preload_active && (actions[7] || actions[6]);
  assign memwb_capture = preload_active || (|actions);
  assign pipeline_empty_next =
      !(ifid_valid_next || idex_valid_next || exmem_valid_next || memwb_valid_next);

  if_id_register ifid_register (
      .clk         (clk),
      .reset       (reset),
      .prepare_init(1'b0),
      .capture     (ifid_capture),
      .hold        (ifid_hold),
      .invalidate  (ifid_invalidate),
      .data_in     (ifid_in),
      .data_out    (ifid_out),
      .valid_next  (ifid_valid_next)
  );
  id_ex_register idex_register (
      .clk         (clk),
      .reset       (reset),
      .prepare_init(1'b0),
      .capture     (idex_capture),
      .bubble      (idex_bubble),
      .data_in     (idex_in),
      .data_out    (idex_out),
      .valid_next  (idex_valid_next)
  );
  ex_mem_register exmem_register (
      .clk         (clk),
      .reset       (reset),
      .prepare_init(1'b0),
      .capture     (exmem_capture),
      .invalidate  (exmem_invalidate),
      .data_in     (exmem_in),
      .data_out    (exmem_out),
      .valid_next  (exmem_valid_next)
  );
  mem_wb_register memwb_register (
      .clk         (clk),
      .reset       (reset),
      .prepare_init(1'b0),
      .capture     (memwb_capture),
      .data_in     (memwb_in),
      .data_out    (memwb_out),
      .valid_next  (memwb_valid_next)
  );

  // Identidad y controles avanzan desde el estado actual; el resto llega por la frontera.
  assign ifid_in              = preload_active ? seed_ifid : future_ifid;
  assign idex_in.valid        = preload_active ? seed_idex.valid : ifid_out.valid;
  assign idex_in.pc           = preload_active ? seed_idex.pc : ifid_out.pc;
  assign idex_in.instruction  = preload_active ? seed_idex.instruction : ifid_out.instruction;
  assign idex_in.rs1          = preload_active ? seed_idex.rs1 : future_idex.rs1;
  assign idex_in.rs2          = preload_active ? seed_idex.rs2 : future_idex.rs2;
  assign idex_in.rd           = preload_active ? seed_idex.rd : future_idex.rd;
  assign idex_in.rs1_value    = preload_active ? seed_idex.rs1_value : future_idex.rs1_value;
  assign idex_in.rs2_value    = preload_active ? seed_idex.rs2_value : future_idex.rs2_value;
  assign idex_in.immediate    = preload_active ? seed_idex.immediate : future_idex.immediate;
  assign idex_in.alu_op       = preload_active ? seed_idex.alu_op : future_idex.alu_op;
  assign idex_in.alu_src      = preload_active ? seed_idex.alu_src : future_idex.alu_src;
  assign idex_in.result_sel   = preload_active ? seed_idex.result_sel : future_idex.result_sel;
  assign idex_in.flow_op      = preload_active ? seed_idex.flow_op : future_idex.flow_op;
  assign idex_in.mem_op       = preload_active ? seed_idex.mem_op : future_idex.mem_op;
  assign idex_in.reg_write    = preload_active ? seed_idex.reg_write : future_idex.reg_write;
  assign exmem_in.valid       = preload_active ? seed_exmem.valid : idex_out.valid;
  assign exmem_in.pc          = preload_active ? seed_exmem.pc : idex_out.pc;
  assign exmem_in.instruction = preload_active ? seed_exmem.instruction : idex_out.instruction;
  assign exmem_in.rd          = preload_active ? seed_exmem.rd : idex_out.rd;
  assign exmem_in.reg_write   = preload_active ? seed_exmem.reg_write : idex_out.reg_write;
  assign exmem_in.mem_op      = preload_active ? seed_exmem.mem_op : idex_out.mem_op;
  assign exmem_in.ex_result   = preload_active ? seed_exmem.ex_result : future_exmem.ex_result;
  assign exmem_in.store_data  = preload_active ? seed_exmem.store_data : future_exmem.store_data;
  assign memwb_in.valid       = preload_active ? seed_memwb.valid : exmem_out.valid;
  assign memwb_in.pc          = preload_active ? seed_memwb.pc : exmem_out.pc;
  assign memwb_in.instruction = preload_active ? seed_memwb.instruction : exmem_out.instruction;
  assign memwb_in.rd          = preload_active ? seed_memwb.rd : exmem_out.rd;
  assign memwb_in.reg_write   = preload_active ? seed_memwb.reg_write : exmem_out.reg_write;
  assign memwb_in.wb_value    = preload_active ? seed_memwb.wb_value : future_memwb.wb_value;

  // Modelo de PC exclusivo de simulación; no acredita el control real de processor_top.
  always_ff @(posedge clk) begin
    if (reset) begin
      pc <= '0;
    end else if (preload_active) begin
      pc <= preload_pc;
    end else if (actions[5]) begin
      pc <= redirect_target;
    end else if (actions[2]) begin
      pc <= pc + 32'd4;
    end
  end
  always #5 clk = ~clk;

  // Observa datos y elegibilidad preflanco; no implementa RF ni DMEM.
  always @(posedge clk) begin
    if (!reset && !preload_active) begin
      observed_store_data   = exmem_out.store_data;
      observed_wb_value     = memwb_out.wb_value;
      observed_mem_valid    = exmem_out.valid;
      observed_mem_op       = exmem_out.mem_op;
      observed_wb_valid     = memwb_out.valid;
      observed_wb_reg_write = memwb_out.reg_write;
      observed_wb_rd        = memwb_out.rd;
    end
  end

  // Informa un único fallo del caso y termina con código distinto de cero.
  function automatic void fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endfunction

  // Lee un campo del fixture actual o alternativo y comprueba ancho y rango antes de asignarlo.
  function automatic logic [63:0] payload_field(input string source, input string latch_name,
                                                input string field_name, input integer width);
    string         base;
    integer        found;
    longint signed value;
    base  = {"/latch_fixture/", latch_name};
    found = -1;
    for (integer index = 0; index < data.get_size(base); index = index + 1) begin
      if (data.get_string($sformatf("%s/%0d/name", base, index)) == field_name) begin
        if (found != -1) fail("duplicate fixture field");
        found = index;
      end
    end
    if (found == -1) fail({"missing fixture field: ", latch_name, ".", field_name});
    if (data.get_integer($sformatf("%s/%0d/width", base, found)) != width) begin
      fail({"fixture width differs for ", latch_name, ".", field_name});
    end
    if (source == "current") begin
      value = data.get_integer($sformatf("%s/%0d/value", base, found));
    end else begin
      value = data.get_integer({"/inputs/composition/payloads/", source, "/", latch_name, "/",
                                field_name});
    end
    if (value < 0 || (value >> width) != 0) fail("fixture value does not fit its field");
    return value;
  endfunction

  // Construye los cinco campos de IF/ID desde la fuente indicada en el JSON.
  function automatic if_id_t read_ifid(input string source);
    if_id_t value;
    value.valid = payload_field(source, "ifid", "valid", $bits(value.valid));
    value.pc = payload_field(source, "ifid", "pc", $bits(value.pc));
    value.instruction = payload_field(source, "ifid", "instruction", $bits(value.instruction));
    value.fetch_fault_valid =
        payload_field(source, "ifid", "fetch_fault_valid", $bits(value.fetch_fault_valid));
    value.fetch_fault_cause =
        payload_field(source, "ifid", "fetch_fault_cause", $bits(value.fetch_fault_cause));
    return value;
  endfunction

  // Construye los quince campos de ID/EX desde la fuente indicada en el JSON.
  function automatic id_ex_t read_idex(input string source);
    id_ex_t value;
    value.valid       = payload_field(source, "idex", "valid", $bits(value.valid));
    value.pc          = payload_field(source, "idex", "pc", $bits(value.pc));
    value.instruction = payload_field(source, "idex", "instruction", $bits(value.instruction));
    value.rs1         = payload_field(source, "idex", "rs1", $bits(value.rs1));
    value.rs2         = payload_field(source, "idex", "rs2", $bits(value.rs2));
    value.rd          = payload_field(source, "idex", "rd", $bits(value.rd));
    value.rs1_value   = payload_field(source, "idex", "rs1_value", $bits(value.rs1_value));
    value.rs2_value   = payload_field(source, "idex", "rs2_value", $bits(value.rs2_value));
    value.immediate   = payload_field(source, "idex", "immediate", $bits(value.immediate));
    value.alu_op      = payload_field(source, "idex", "alu_op", $bits(value.alu_op));
    value.alu_src     = payload_field(source, "idex", "alu_src", $bits(value.alu_src));
    value.result_sel  = payload_field(source, "idex", "result_sel", $bits(value.result_sel));
    value.flow_op     = payload_field(source, "idex", "flow_op", $bits(value.flow_op));
    value.mem_op      = payload_field(source, "idex", "mem_op", $bits(value.mem_op));
    value.reg_write   = payload_field(source, "idex", "reg_write", $bits(value.reg_write));
    return value;
  endfunction

  // Construye los ocho campos de EX/MEM desde la fuente indicada en el JSON.
  function automatic ex_mem_t read_exmem(input string source);
    ex_mem_t value;
    value.valid       = payload_field(source, "exmem", "valid", $bits(value.valid));
    value.pc          = payload_field(source, "exmem", "pc", $bits(value.pc));
    value.instruction = payload_field(source, "exmem", "instruction", $bits(value.instruction));
    value.rd          = payload_field(source, "exmem", "rd", $bits(value.rd));
    value.reg_write   = payload_field(source, "exmem", "reg_write", $bits(value.reg_write));
    value.mem_op      = payload_field(source, "exmem", "mem_op", $bits(value.mem_op));
    value.ex_result   = payload_field(source, "exmem", "ex_result", $bits(value.ex_result));
    value.store_data  = payload_field(source, "exmem", "store_data", $bits(value.store_data));
    return value;
  endfunction

  // Construye los seis campos de MEM/WB desde la fuente indicada en el JSON.
  function automatic mem_wb_t read_memwb(input string source);
    mem_wb_t value;
    value.valid       = payload_field(source, "memwb", "valid", $bits(value.valid));
    value.pc          = payload_field(source, "memwb", "pc", $bits(value.pc));
    value.instruction = payload_field(source, "memwb", "instruction", $bits(value.instruction));
    value.rd          = payload_field(source, "memwb", "rd", $bits(value.rd));
    value.reg_write   = payload_field(source, "memwb", "reg_write", $bits(value.reg_write));
    value.wb_value    = payload_field(source, "memwb", "wb_value", $bits(value.wb_value));
    return value;
  endfunction

  // Traduce la acción esperada del JSON sin usar candidatos ni salidas del árbitro.
  function automatic logic [7:0] action_mask(input string name);
    if (name == "act_ex_fault") return 8'b10000000;
    if (name == "act_halt") return 8'b01000000;
    if (name == "act_redirect") return 8'b00100000;
    if (name == "act_id_fault") return 8'b00010000;
    if (name == "act_load_use") return 8'b00001000;
    if (name == "act_normal") return 8'b00000100;
    if (name == "act_drain_load_use") return 8'b00000010;
    if (name == "act_drain_advance") return 8'b00000001;
    if (name == "ninguna") return '0;
    fail("unknown action expectation");
    return 'x;
  endfunction

  // Evalúa la validez esperada desde el modo de actualización y las copias preflanco.
  function automatic logic reference_valid(input string mode, input logic previous,
                                           input logic incoming);
    if (mode == "hold" || mode == "hold_all_5_fields") return previous;
    if (mode == "invalidate_flags" || mode == "bubble" || mode == "invalidate") return 1'b0;
    if (mode == "capture_IF" || mode == "capture_ID" || mode == "capture_EX" ||
        mode == "capture_MEM")
      return incoming;
    fail("unknown register update expectation");
    return 1'bx;
  endfunction

  // Aplica una observación del caso, con entrada IF/ID de instrucción o candidato.
  task automatic run_observation(input integer index);
    string         source;
    string         mode_pc;
    string         mode_ifid;
    string         mode_idex;
    string         mode_exmem;
    string         mode_memwb;
    word_t         previous_pc;
    word_t         expected_pc;
    if_id_t        previous_ifid;
    if_id_t        incoming_ifid;
    id_ex_t        previous_idex;
    id_ex_t        incoming_idex;
    ex_mem_t       previous_exmem;
    ex_mem_t       incoming_exmem;
    mem_wb_t       previous_memwb;
    mem_wb_t       incoming_memwb;
    logic    [3:0] expected_valids;
    @(negedge clk);
    reset          = 1'b0;
    cpu_cycle_fire = 1'b0;
    preload_active = 1'b1;
    source         = data.get_string($sformatf("/inputs/composition/preload_order/%0d", index));
    seed_ifid      = read_ifid(source);
    seed_idex      = read_idex(source);
    seed_exmem     = read_exmem(source);
    seed_memwb     = read_memwb(source);
    if (FRONTIER_FIXTURE) begin
      seed_exmem.valid      = data.get_integer("/inputs/composition/older_mem/valid");
      seed_exmem.mem_op     = data.get_integer("/inputs/composition/older_mem/mem_op");
      seed_exmem.reg_write  = data.get_integer("/inputs/composition/older_mem/reg_write");
      seed_exmem.store_data = data.get_integer("/inputs/older_MEM_store");
      seed_memwb.valid      = data.get_integer("/inputs/composition/older_wb/valid");
      seed_memwb.reg_write  = data.get_integer("/inputs/composition/older_wb/reg_write");
      seed_memwb.rd         = data.get_integer("/inputs/composition/older_wb/rd");
      seed_memwb.wb_value   = data.get_integer("/inputs/older_WB_value");
    end
    preload_pc      = data.get_integer("/inputs/composition/PC");
    redirect_target = data.get_integer("/inputs/composition/redirect_target");
    @(posedge clk);
    #1;
    if (ifid_out !== seed_ifid || idex_out !== seed_idex || exmem_out !== seed_exmem ||
        memwb_out !== seed_memwb || pc !== preload_pc)
      fail("preload failed through capture ports");
    @(negedge clk);
    previous_pc    = pc;
    previous_ifid  = ifid_out;
    previous_idex  = idex_out;
    previous_exmem = exmem_out;
    previous_memwb = memwb_out;
    preload_active = 1'b0;
    source         = data.get_string($sformatf("/inputs/composition/future_order/%0d", index));
    future_ifid    = read_ifid(source);
    future_idex    = read_idex(source);
    future_exmem   = read_exmem(source);
    future_memwb   = read_memwb(source);
    if (FRONTIER_FIXTURE) begin
      ex_fault_candidate = data.get_integer("/inputs/composition/events/ex_fault_candidate");
      ex_halt_candidate  = data.get_integer("/inputs/composition/events/ex_halt_candidate");
      redirect_requested = data.get_integer("/inputs/composition/events/redirect_requested");
      id_fault_candidate = data.get_integer("/inputs/composition/events/id_fault_candidate");
      load_use_stall     = data.get_integer("/inputs/composition/events/load_use_stall");
    end else if (!TERMINAL_FIXTURE) begin
      ex_fault_candidate = data.get_integer("/inputs/local_fixture/ex_fault_candidate");
      ex_halt_candidate  = data.get_integer("/inputs/local_fixture/ex_halt_candidate");
      redirect_requested = data.get_integer("/inputs/local_fixture/redirect_requested");
      id_fault_candidate = data.get_integer("/inputs/local_fixture/id_fault_candidate");
      load_use_stall     = data.get_integer("/inputs/local_fixture/load_use_stall");
      if (preload_pc != data.get_integer(
              "/inputs/local_fixture/PC"
          ) || redirect_target != data.get_integer(
              "/inputs/local_fixture/redirect_target"
          )) begin
        fail("composition PC fixture differs from the published witness");
      end
    end else begin
      if (data.get_string("/inputs/state") != "FINISHED" || previous_ifid.fetch_fault_valid) begin
        fail("terminal fixture is not empty");
      end
      for (integer latch_index = 0; latch_index < 4; latch_index = latch_index + 1) begin
        if (data.get_integer($sformatf("/inputs/valids/%0d", latch_index)) != 0) begin
          fail("terminal witness must contain four invalid latches");
        end
      end
      if (previous_ifid.valid || previous_idex.valid || previous_exmem.valid ||
          previous_memwb.valid)
        fail("terminal preload contains active work");
    end
    if (FRONTIER_FIXTURE) begin
      cpu_cycle_fire = data.get_integer("/inputs/composition/cpu_cycle_fire");
      drain_mode     = data.get_integer("/inputs/composition/drain_mode");
    end else begin
      cpu_cycle_fire = data.get_integer("/inputs/cpu_cycle_fire");
      drain_mode     = data.get_integer("/inputs/drain_mode");
    end
    mode_pc     = data.get_string("/expected/composition/next_updates/0");
    mode_ifid   = data.get_string("/expected/composition/next_updates/1");
    mode_idex   = data.get_string("/expected/composition/next_updates/2");
    mode_exmem  = data.get_string("/expected/composition/next_updates/3");
    mode_memwb  = data.get_string("/expected/composition/next_updates/4");
    expected_pc = previous_pc;
    if (mode_pc == "PC+4") begin
      expected_pc = previous_pc + 32'd4;
    end else if (mode_pc == "target") begin
      expected_pc = redirect_target;
    end else if (mode_pc != "hold") begin
      fail("unknown PC update expectation");
    end
    #1;
    incoming_ifid              = future_ifid;
    incoming_idex              = future_idex;
    incoming_exmem             = future_exmem;
    incoming_memwb             = future_memwb;
    incoming_idex.valid        = previous_ifid.valid;
    incoming_idex.pc           = previous_ifid.pc;
    incoming_idex.instruction  = previous_ifid.instruction;
    incoming_exmem.valid       = previous_idex.valid;
    incoming_exmem.pc          = previous_idex.pc;
    incoming_exmem.instruction = previous_idex.instruction;
    incoming_exmem.rd          = previous_idex.rd;
    incoming_exmem.reg_write   = previous_idex.reg_write;
    incoming_exmem.mem_op      = previous_idex.mem_op;
    incoming_memwb.valid       = previous_exmem.valid;
    incoming_memwb.pc          = previous_exmem.pc;
    incoming_memwb.instruction = previous_exmem.instruction;
    incoming_memwb.rd          = previous_exmem.rd;
    incoming_memwb.reg_write   = previous_exmem.reg_write;
    if (ifid_in !== incoming_ifid || idex_in !== incoming_idex || exmem_in !== incoming_exmem ||
        memwb_in !== incoming_memwb) begin
      fail("producer wiring differs from the independent pre-edge reference");
    end
    if (ifid_out !== previous_ifid || idex_out !== previous_idex || exmem_out !== previous_exmem ||
        memwb_out !== previous_memwb || pc !== previous_pc) begin
      fail("registered state changed before the rising edge");
    end
    if (actions !== action_mask(
            data.get_string("/expected/composition/selected_action")
        ) || $onehot0(
            actions
        ) !== 1'b1)
      fail("composition selected unexpected actions");
    if (FRONTIER_FIXTURE && actions[4] !== data.get_boolean("/expected/ID_confirm")) begin
      fail("a younger ID fault was confirmed");
    end
    expected_valids = {
      reference_valid(mode_ifid, previous_ifid.valid, incoming_ifid.valid),
      reference_valid(mode_idex, previous_idex.valid, incoming_idex.valid),
      reference_valid(mode_exmem, previous_exmem.valid, incoming_exmem.valid),
      reference_valid(mode_memwb, previous_memwb.valid, incoming_memwb.valid)
    };
    if ({ifid_valid_next, idex_valid_next, exmem_valid_next, memwb_valid_next} !==
        expected_valids || pipeline_empty_next !== !(|expected_valids))
      fail("next validity differs before the edge");
    @(posedge clk);
    #1;
    if (pc !== expected_pc) fail("PC update differs from expectation");
    if (FRONTIER_FIXTURE) begin
      if (data.get_string("/expected/winner") != "EX" || !cpu_cycle_fire) begin
        fail("frontier fixture must select an older EX event in an effective cycle");
      end
      if (observed_store_data !== previous_exmem.store_data ||
          observed_wb_value !== previous_memwb.wb_value || observed_store_data !== data.get_integer(
              "/inputs/older_MEM_store"
          ) || observed_wb_value !== data.get_integer(
              "/inputs/older_WB_value"
          )) begin
        fail("older store or WB data was replaced in the frontier edge");
      end
      if (data.get_boolean(
              "/expected/older_commits"
          ) && (observed_mem_valid !== 1'b1 || observed_mem_op !== MEM_OP_SW || observed_wb_valid
                !== 1'b1 || observed_wb_reg_write !== 1'b1 || observed_wb_rd == 0)) begin
        fail("the fixture lost eligibility of older work at the frontier");
      end
    end
    if (mode_ifid == "capture_IF") begin
      if (ifid_out !== incoming_ifid) fail("IF/ID did not capture its pre-edge producer");
    end else if (mode_ifid == "invalidate_flags") begin
      if (ifid_out.valid !== 1'b0 || ifid_out.fetch_fault_valid !== 1'b0) begin
        fail("IF/ID did not invalidate both flags");
      end
    end else if (mode_ifid == "hold" || mode_ifid == "hold_all_5_fields") begin
      if (ifid_out !== previous_ifid) fail("IF/ID did not retain all five fields");
    end else begin
      fail("invalid IF/ID update mode");
    end
    if (mode_idex == "capture_ID") begin
      if (idex_out !== incoming_idex) fail("ID/EX did not capture its pre-edge producer");
    end else if (mode_idex == "bubble") begin
      if (idex_out.valid !== 1'b0) fail("ID/EX did not insert a bubble");
    end else if (mode_idex == "hold") begin
      if (idex_out !== previous_idex) fail("ID/EX did not retain its payload");
    end else begin
      fail("invalid ID/EX update mode");
    end
    if (mode_exmem == "capture_EX") begin
      if (exmem_out !== incoming_exmem) fail("EX/MEM did not capture its pre-edge producer");
    end else if (mode_exmem == "invalidate") begin
      if (exmem_out.valid !== 1'b0) fail("EX/MEM did not invalidate its entry");
    end else if (mode_exmem == "hold") begin
      if (exmem_out !== previous_exmem) fail("EX/MEM did not retain its payload");
    end else begin
      fail("invalid EX/MEM update mode");
    end
    if (mode_memwb == "capture_MEM") begin
      if (memwb_out !== incoming_memwb) fail("MEM/WB did not capture its pre-edge producer");
    end else if (mode_memwb == "hold") begin
      if (memwb_out !== previous_memwb) fail("MEM/WB did not retain its payload");
    end else begin
      fail("invalid MEM/WB update mode");
    end
  endtask

  // Recorre cinco flancos de llenado con datos de etapas y traza independiente.
  task automatic run_fill;
    string       source;
    string       path;
    logic  [3:0] expected_valids;
    logic  [3:0] actual_valids;
    word_t       actual_pcs         [4];
    word_t       actual_instructions[4];
    @(negedge clk);
    reset           = 1'b0;
    preload_active  = 1'b1;
    preload_pc      = data.get_integer("/inputs/composition/PC");
    redirect_target = data.get_integer("/inputs/composition/redirect_target");
    source          = data.get_string("/inputs/composition/preload_source");
    seed_ifid       = read_ifid(source);
    seed_idex       = read_idex(source);
    seed_exmem      = read_exmem(source);
    seed_memwb      = read_memwb(source);
    @(posedge clk);
    #1;
    if (ifid_out !== seed_ifid || idex_out !== seed_idex || exmem_out !== seed_exmem ||
        memwb_out !== seed_memwb || pc !== preload_pc)
      fail("empty pipeline preload failed");
    for (
        integer index = 0;
        index < data.get_size("/inputs/composition/fetch_order");
        index = index + 1
    ) begin
      @(negedge clk);
      preload_active = 1'b0;
      cpu_cycle_fire = data.get_integer("/inputs/composition/cpu_cycle_fire");
      drain_mode     = data.get_integer("/inputs/composition/drain_mode");
      source         = data.get_string($sformatf("/inputs/composition/fetch_order/%0d", index));
      future_ifid    = read_ifid(source);
      future_idex    = read_idex(source);
      future_exmem   = read_exmem(source);
      future_memwb   = read_memwb(source);
      path           = $sformatf("/expected/fill_trace/%0d", index);
      for (integer slot = 0; slot < 4; slot = slot + 1) begin
        expected_valids[3-slot] = data.get_integer($sformatf("%s/valids/%0d", path, slot));
      end
      #1;
      if (actions !== action_mask(data.get_string("/expected/fill_action"))) begin
        fail("fill fixture did not select normal advance");
      end
      if ({ifid_valid_next, idex_valid_next, exmem_valid_next, memwb_valid_next} !==
          expected_valids || pipeline_empty_next !== !(|expected_valids)) begin
        fail("fill next validity differs from the published trace");
      end
      if (index + 1 < data.get_integer("/expected/first_writeback_cycle")) begin
        if (memwb_out.valid !== 1'b0) fail("WB became valid before the fifth cycle");
      end else begin
        if (memwb_out.valid !== 1'b1 || memwb_out.reg_write !== 1'b1 ||
            memwb_out.rd !== data.get_integer(
                "/expected/fifth_preedge_wb/rd"
            ) || memwb_out.pc !== data.get_integer(
                "/expected/fifth_preedge_wb/pc"
            ) || memwb_out.wb_value !== data.get_integer(
                "/expected/fifth_preedge_wb/wb_value"
            )) begin
          fail("fifth cycle did not expose the first instruction to WB");
        end
      end
      @(posedge clk);
      #1;
      if (pc !== data.get_integer({path, "/PC"}) || ifid_out.fetch_fault_valid !== 1'b0) begin
        fail("fill PC or fetch flag differs from the trace");
      end
      actual_valids          = {ifid_out.valid, idex_out.valid, exmem_out.valid, memwb_out.valid};
      actual_pcs[0]          = ifid_out.pc;
      actual_pcs[1]          = idex_out.pc;
      actual_pcs[2]          = exmem_out.pc;
      actual_pcs[3]          = memwb_out.pc;
      actual_instructions[0] = ifid_out.instruction;
      actual_instructions[1] = idex_out.instruction;
      actual_instructions[2] = exmem_out.instruction;
      actual_instructions[3] = memwb_out.instruction;
      if (actual_valids !== expected_valids) fail("fill stage validity differs");
      for (integer slot = 0; slot < 4; slot = slot + 1) begin
        if (expected_valids[3-slot]) begin
          if (actual_pcs[slot] !== data.get_integer(
                  $sformatf("%s/pcs/%0d", path, slot)
              ) || actual_instructions[slot] !== data.get_integer(
                  $sformatf("%s/instructions/%0d", path, slot)
              )) begin
            fail("instruction skipped or changed identity across a pipeline boundary");
          end
        end
      end
    end
  endtask

  initial begin
    data.load();
    @(posedge clk);
    #1;
    if (FILL_FIXTURE) begin
      run_fill();
    end else begin
      if (data.get_size(
              "/inputs/composition/preload_order"
          ) != data.get_size(
              "/inputs/composition/future_order"
          ))
        fail("fixture observation counts differ");
      for (
          integer index = 0;
          index < data.get_size("/inputs/composition/preload_order");
          index = index + 1
      ) begin
        run_observation(index);
      end
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
