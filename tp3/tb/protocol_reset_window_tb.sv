`timescale 1ns / 1ps

module protocol_reset_window_tb;
  tp3_case_data data ();
  logic clk = 0;
  logic reset = 1;
  logic rx_empty = 1;
  logic response_busy;
  logic response_done_tick = 0;
  logic prepare_active;
  logic cpu_cycle_fire;
  wire rd_uart, response_start, uart_reset_request;
  wire [7:0] response_opcode, response_result;
  wire load_request, run_request, step_request;
  wire debug_read_select;

  protocol_controller dut (
      .clk,
      .reset,
      .rx_empty,
      .r_data             (8'h04),
      .rx_error_tick      (1'b0),
      .rx_activity        (!rx_empty),
      .response_busy,
      .response_done_tick,
      .load_available     (1'b0),
      .prepare_active,
      .program_finished   (1'b0),
      .fault_terminal     (1'b0),
      .image_valid        (1'b1),
      .command_accepted   (1'b0),
      .cpu_cycle_fire,
      .rd_uart,
      .response_start,
      .response_opcode,
      .response_result,
      .response_with_debug(),
      .load_request,
      .run_request,
      .step_request,
      .load_size_bytes    (),
      .load_byte_valid    (),
      .load_byte_data     (),
      .load_byte_offset   (),
      .load_last_byte     (),
      .load_abort         (),
      .uart_reset_request,
      .debug_read_select
  );
  always #10ns clk = ~clk;

  task automatic tick;
    @(posedge clk);
    @(negedge clk);
  endtask

  initial begin : test
    string        phase;
    logic  [10:0] expected_phase;
    bit           pending_run;
    bit           discard;
    data.load();
    phase = data.get_string("/inputs/transport_phase");
    if (phase == "WAIT_COMMAND") expected_phase = dut.WAIT_COMMAND;
    else if (phase == "WAIT_RUN_ACCEPT_SENT") expected_phase = dut.WAIT_RUN_ACCEPT_SENT;
    else if (phase == "WAIT_RUN_END") expected_phase = dut.WAIT_RUN_END;
    else if (phase == "WAIT_LOAD_ACCEPT_SENT") expected_phase = dut.WAIT_LOAD_ACCEPT_SENT;
    else if (phase == "WAIT_PREP_DONE") expected_phase = dut.WAIT_PREP_DONE;
    else if (phase == "WAIT_STEP_END") expected_phase = dut.WAIT_STEP_END;
    else if (phase == "WAIT_RESPONSE_SENT") expected_phase = dut.WAIT_RESPONSE_SENT;
    else $fatal(1, "unsupported reset fixture %s", phase);
    pending_run    = data.get_boolean("/inputs/run_result_required");
    prepare_active = data.get_boolean("/inputs/prepare_active");
    response_busy  = data.get_boolean("/inputs/response_busy_before");
    discard        = data.has_path("/inputs/fixture_scope");
    cpu_cycle_fire = discard ? data.get_boolean("/inputs/cpu_cycle_fire") : pending_run;

    tick();
    reset                   = 0;
    dut.protocol_state      = expected_phase;
    dut.run_result_required = pending_run;
    rx_empty                = 0;
    #1ns;
    if (!rd_uart || uart_reset_request || load_request || run_request || step_request ||
        debug_read_select)
      $fatal(1, "RESET interfered with other services");
    if (discard) begin
      if (response_start) $fatal(1, "RESET started a response in %s", phase);
      tick();
      rx_empty = 1;
      if (dut.protocol_state !== expected_phase || dut.run_result_required !== pending_run ||
          uart_reset_request || response_start)
        $fatal(1, "discarded RESET changed protocol state");
    end else begin
      if (!response_start || response_opcode !== 4 || response_result !== 1)
        $fatal(1, "RESET was not recognized in %s", phase);
      tick();
      rx_empty      = 1;
      response_busy = 1;
      repeat (3) begin
        tick();
        if (dut.protocol_state !== dut.WAIT_RESET_ACCEPT_SENT || uart_reset_request ||
            dut.run_result_required || response_start)
          $fatal(1, "early reset or pending RUN");
      end
      response_done_tick = 1;
      tick();
      if (!uart_reset_request) $fatal(1, "final Stop did not register the reset request");
      reset = 1;
      tick();
      if (uart_reset_request || dut.protocol_state !== dut.WAIT_COMMAND)
        $fatal(1, "functional reset failed to clear the request");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
