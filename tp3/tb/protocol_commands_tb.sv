`timescale 1ns / 1ps

module protocol_commands_tb;
  import system_pkg::*;
  tp3_case_data data ();
  logic       clk = 0;
  logic       reset = 1;
  logic       rx_empty = 1;
  logic [7:0] r_data = 0;
  logic       response_busy = 0;
  logic       response_done_tick = 0;
  logic       load_available;
  logic       prepare_active;
  logic       program_finished;
  logic       fault_terminal;
  logic       image_valid;
  logic       auto_cycle;
  logic       accept_execution;
  logic       immediate_cycle;
  wire command_accepted, cpu_cycle_fire, rd_uart;
  wire response_start, response_with_debug;
  wire [7:0] response_opcode, response_result;
  wire load_request, run_request, step_request, load_byte_valid, load_last_byte, load_abort;
  wire [10:0] load_size_bytes;
  wire [ 9:0] load_byte_offset;
  wire [ 7:0] load_byte_data;
  wire uart_reset_request, debug_read_select;

  assign command_accepted = load_request || ((run_request || step_request) && accept_execution);
  assign cpu_cycle_fire   = auto_cycle || ((run_request || step_request) && immediate_cycle);

  protocol_controller dut (
      .clk,
      .reset,
      .rx_empty,
      .r_data,
      .rx_error_tick(1'b0),
      .rx_activity  (!rx_empty),
      .response_busy,
      .response_done_tick,
      .load_available,
      .prepare_active,
      .program_finished,
      .fault_terminal,
      .image_valid,
      .command_accepted,
      .cpu_cycle_fire,
      .rd_uart,
      .response_start,
      .response_opcode,
      .response_result,
      .response_with_debug,
      .load_request,
      .run_request,
      .step_request,
      .load_size_bytes,
      .load_byte_valid,
      .load_byte_data,
      .load_byte_offset,
      .load_last_byte,
      .load_abort,
      .uart_reset_request,
      .debug_read_select
  );
  always #10ns clk = ~clk;

  task automatic tick;
    @(posedge clk);
    @(negedge clk);
  endtask

  task automatic require_response(input logic [7:0] opcode, input logic [7:0] result,
                                  input bit with_debug);
    if (!response_start || response_busy || response_opcode !== opcode ||
        response_result !== result || response_with_debug !== with_debug)
      $fatal(
          1,
          "unexpected descriptor for opcode %02x: %02x %02x debug=%b",
          opcode,
          response_opcode,
          response_result,
          response_with_debug
      );
  endtask

  task automatic discard;
    #1ns;
    if (!rd_uart || response_start || load_request || run_request || step_request ||
        load_byte_valid || load_abort || uart_reset_request || !cpu_cycle_fire)
      $fatal(1, "out-of-phase traffic affected RUN");
    tick();
    if (dut.protocol_state !== dut.RECOVER_RX || !dut.run_result_required)
      $fatal(1, "out-of-phase traffic lost the pending RUN");
  endtask

  initial begin : test
    string        phase;
    logic   [7:0] opcode;
    logic   [7:0] expected_result;
    bit           with_debug;
    bit           test_load_header;
    integer       count_before;

    data.load();
    phase            = data.get_string("/inputs/transport_phase");
    load_available   = data.get_boolean("/inputs/cpu_context/load_available");
    prepare_active   = data.get_boolean("/inputs/cpu_context/prepare_active");
    program_finished = data.get_boolean("/inputs/cpu_context/program_finished");
    fault_terminal   = data.get_boolean("/inputs/cpu_context/fault_terminal");
    image_valid      = data.get_boolean("/inputs/cpu_context/image_valid");
    auto_cycle       = data.get_boolean("/inputs/cpu_context/cpu_cycle_fire");
    accept_execution = 0;
    immediate_cycle  = 0;
    if (data.has_path("/inputs/cpu_reply_on_request/command_accepted")) begin
      accept_execution = data.get_boolean("/inputs/cpu_reply_on_request/command_accepted");
      immediate_cycle  = data.get_boolean("/inputs/cpu_reply_on_request/cpu_cycle_fire");
    end
    tick();
    reset = 0;
    tick();

    if (phase == "WAIT_COMMAND") begin
      opcode = 8'(data.get_integer("/inputs/opcode"));
      case (opcode)
        2: expected_result = accept_execution ? 1 : 5;
        3: expected_result = accept_execution ? 2 : 5;
        5: expected_result = 3;
        default: expected_result = 12;
      endcase
      with_debug = opcode == 3 && accept_execution;
      r_data     = opcode;
      rx_empty   = 0;
      #1ns;
      if (!rd_uart || run_request !== (opcode == 2) || step_request !== (opcode == 3) ||
          load_request || command_accepted !== accept_execution ||
          cpu_cycle_fire !== immediate_cycle)
        $fatal(1, "wrong request/acceptance at command edge");
      if (with_debug && !immediate_cycle) begin
        if (response_start || dut.debug_hold_set) $fatal(1, "STEP replied before preparation");
        tick();
        rx_empty = 1;
        if (dut.protocol_state !== dut.WAIT_STEP_END)
          $fatal(1, "STEP did not wait for preparation");
        prepare_active   = 1;
        program_finished = 0;
        fault_terminal   = 0;
        tick();
        auto_cycle = 1;
        #1ns;
      end
      require_response(opcode, expected_result, with_debug);
      if (dut.debug_hold_set !== with_debug) $fatal(1, "incorrect Debug retention action");
      tick();
      rx_empty = 1;
      if (with_debug && (!dut.debug_hold || !debug_read_select))
        $fatal(1, "STEP/DONE failed to retain Debug");
    end else if (phase == "WAIT_RUN_END") begin
      dut.protocol_state      = dut.WAIT_RUN_END;
      dut.run_result_required = 1;
      test_load_header        = data.has_path("/inputs/LOAD_header");
      opcode                  = test_load_header ? 8'd1 : 8'(data.get_integer("/inputs/opcode"));
      r_data                  = opcode;
      rx_empty                = 0;
      discard();
      if (test_load_header) begin
        r_data = 4;
        discard();
        r_data = 0;
        repeat (4) discard();
      end
      rx_empty             = 1;
      dut.inactivity_count = 23'd4999999;
      tick();
      if (dut.protocol_state !== dut.WAIT_RUN_END || response_start || uart_reset_request ||
          !dut.run_result_required || !cpu_cycle_fire)
        $fatal(1, "recovery did not restore the RUN window");
    end else begin
      opcode   = 8'(data.get_integer("/inputs/byte"));
      r_data   = opcode;
      rx_empty = 0;
      if (phase == "RECEIVE_LOAD_SIZE") begin
        dut.protocol_state     = dut.RECEIVE_LOAD_SIZE;
        dut.size_byte_index    = 1;
        dut.load_size_received = 40'd8;
      end else begin
        dut.protocol_state       = dut.RECEIVE_LOAD_DATA;
        dut.load_size_received   = 40'd8;
        dut.load_bytes_remaining = 4;
      end
      #1ns;
      count_before = int'(dut.load_bytes_remaining);
      if (!rd_uart || load_request || run_request || step_request || response_start ||
          uart_reset_request || load_abort)
        $fatal(1, "LOAD byte decoded as opcode");
      if (phase == "RECEIVE_LOAD_DATA" && (!load_byte_valid || load_byte_data !== opcode ||
                                           load_byte_offset != 4 || load_last_byte))
        $fatal(1, "LOAD content delivery mismatch");
      tick();
      if (phase == "RECEIVE_LOAD_SIZE" &&
          (dut.size_byte_index != 2 || dut.load_size_received[15:8] !== opcode))
        $fatal(1, "LOAD size capture mismatch");
      if (phase == "RECEIVE_LOAD_DATA" && dut.load_bytes_remaining != count_before - 1)
        $fatal(1, "LOAD content was not counted");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
