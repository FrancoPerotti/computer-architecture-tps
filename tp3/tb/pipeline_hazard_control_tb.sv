`timescale 1ns / 1ps

// Comprueba selección y exclusión de acciones sin instanciar FSM, PC ni registros.
module pipeline_hazard_control_tb #(
    parameter integer TERMINAL_FIXTURE = 0,
    parameter integer PRIORITY_FIXTURE = 0
);
  logic        cpu_cycle_fire = 1'b0;
  logic        drain_mode = 1'b0;
  logic        ex_fault_candidate = 1'b0;
  logic        ex_halt_candidate = 1'b0;
  logic        redirect_requested = 1'b0;
  logic        id_fault_candidate = 1'b0;
  logic        load_use_stall = 1'b0;
  logic  [7:0] actions;
  logic  [7:0] expected_actions;
  string       selected_action;

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

  // Informa un único fallo del caso y termina con código distinto de cero.
  function automatic void fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endfunction

  // Traduce nombres del catálogo a salidas, sin resolver prioridades desde las entradas.
  function automatic logic [7:0] action_mask(input string name);
    if (name == "act_ex_fault" || name == "EX_fault") return 8'b10000000;
    if (name == "act_halt" || name == "halt") return 8'b01000000;
    if (name == "act_redirect" || name == "redirect") return 8'b00100000;
    if (name == "act_id_fault" || name == "ID_fault") return 8'b00010000;
    if (name == "act_load_use") return 8'b00001000;
    if (name == "act_normal") return 8'b00000100;
    if (name == "act_drain_load_use") return 8'b00000010;
    if (name == "act_drain_advance") return 8'b00000001;
    if (name == "ninguna") return 8'b00000000;
    fail({"unknown action expectation: ", name});
    return 'x;
  endfunction

  initial begin
    data.load();
    cpu_cycle_fire = data.get_integer("/inputs/cpu_cycle_fire");
    drain_mode     = data.get_integer("/inputs/drain_mode");
    if (TERMINAL_FIXTURE) begin
      // El fixture aporta FINISHED vacío; solo se comprueba la respuesta del árbitro.
      if (PRIORITY_FIXTURE || data.get_string(
              "/inputs/state"
          ) != "FINISHED" || cpu_cycle_fire !== 1'b0 || data.get_size(
              "/inputs/valids"
          ) != 4) begin
        fail("terminal fixture differs from the catalogue");
      end
      for (integer index = 0; index < 4; index = index + 1) begin
        if (data.get_integer($sformatf("/inputs/valids/%0d", index)) != 0) begin
          fail("terminal fixture must have four invalid latches");
        end
      end
    end else begin
      ex_fault_candidate = data.get_integer("/inputs/local_fixture/ex_fault_candidate");
      ex_halt_candidate  = data.get_integer("/inputs/local_fixture/ex_halt_candidate");
      redirect_requested = data.get_integer("/inputs/local_fixture/redirect_requested");
      id_fault_candidate = data.get_integer("/inputs/local_fixture/id_fault_candidate");
      load_use_stall     = data.get_integer("/inputs/local_fixture/load_use_stall");
    end
    if (PRIORITY_FIXTURE) begin
      selected_action = data.get_string("/expected/winner");
    end else begin
      selected_action = data.get_string("/expected/selected_action");
    end
    expected_actions = action_mask(selected_action);
    #1;
    if (actions !== expected_actions) begin
      fail($sformatf("actions=%b; expected=%b (%s)", actions, expected_actions, selected_action));
    end
    if ($onehot0(actions) !== 1'b1) fail("actions are not mutually exclusive");
    if (cpu_cycle_fire && $onehot(actions) !== 1'b1) begin
      fail("an effective cycle must select exactly one action");
    end
    if (!cpu_cycle_fire && actions !== 8'b00000000) fail("actions fired without a CPU cycle");
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
