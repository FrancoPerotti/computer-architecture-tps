`timescale 1ns / 1ps

module protocol_load_priority_tb;
  import system_pkg::*;
  tp3_case_data data ();
  logic       clk = 0;
  logic       reset = 1;
  logic       rx_empty = 1;
  logic [7:0] r_data = 0;
  logic       rx_error_tick = 0;
  logic       response_done_tick = 0;
  wire command_accepted, rd_uart, response_start, response_with_debug;
  wire [7:0] response_opcode, response_result;
  wire load_request, run_request, step_request, load_byte_valid, load_last_byte, load_abort;
  wire [10:0] load_size_bytes;
  wire [ 9:0] load_byte_offset;
  wire [ 7:0] load_byte_data;
  assign command_accepted = load_request;

  protocol_controller dut (
      .clk,
      .reset,
      .rx_empty,
      .r_data,
      .rx_error_tick,
      .rx_activity       (1'b0),
      .response_busy     (1'b0),
      .response_done_tick,
      .load_available    (1'b1),
      .prepare_active    (1'b0),
      .program_finished  (1'b0),
      .fault_terminal    (1'b0),
      .image_valid       (1'b0),
      .command_accepted,
      .cpu_cycle_fire    (1'b0),
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
      .uart_reset_request(),
      .debug_read_select ()
  );

  always #10ns clk = ~clk;

  task automatic tick;
    @(posedge clk);
    @(negedge clk);
  endtask

  task automatic send(input logic [7:0] value);
    rx_empty = 0;
    r_data   = value;
    tick();
    rx_empty = 1;
  endtask

  initial begin : test
    bit     content;
    bit     last_byte;
    bit     error_wins;
    string  events;
    integer size_index;
    integer remaining;

    data.load();
    content    = data.get_string("/inputs/phase") == "RECEIVE_LOAD_DATA";
    last_byte  = data.get_boolean("/inputs/byte_completes_phase");
    error_wins = data.get_string("/expected/winner") == "error";
    events     = data.get_string("/inputs/events");
    tick();
    reset = 0;

    send(1);
    send(8);
    if (content || last_byte) repeat (3) send(0);
    if (content) begin
      send(0);
      response_done_tick = 1;
      tick();
      response_done_tick = 0;
      repeat (last_byte ? 7 : 3) send(0);
    end
    size_index = int'(dut.size_byte_index);
    remaining  = int'(dut.load_bytes_remaining);

    // These catalogue vectors align an artificial error and byte on one edge.
    dut.inactivity_count = events == "error+byte" ? 23'd25 : 23'd4999999;
    rx_empty             = 0;
    rx_error_tick        = error_wins;
    r_data               = 0;
    #1ns;
    if (!rd_uart || run_request || step_request || response_with_debug)
      $fatal(1, "coincident LOAD byte must be consumed as LOAD traffic");
    if (error_wins) begin
      if (!response_start || response_opcode !== 1 || response_result !== 9 ||
          load_abort !== content || load_request || load_byte_valid || load_last_byte)
        $fatal(1, "UART error lost arbitration");
    end else if (content) begin
      if (!load_byte_valid || load_byte_data !== 0 || load_last_byte !== last_byte ||
          load_byte_offset != (last_byte ? 7 : 3) || response_start || load_abort)
        $fatal(1, "content byte lost arbitration");
    end else if (last_byte) begin
      if (!load_request || !command_accepted || load_size_bytes != 8 || !response_start ||
          response_opcode !== 1 || response_result !== 1)
        $fatal(1, "fifth size byte lost arbitration");
    end else if (response_start || load_request || load_abort)
      $fatal(1, "partial size byte lost arbitration");
    tick();
    rx_empty      = 1;
    rx_error_tick = 0;
    if (dut.inactivity_count !== 0) $fatal(1, "arbitration did not clear timer");
    if (error_wins) begin
      if (dut.protocol_state !== dut.RECOVER_RX || dut.load_bytes_remaining != remaining ||
          dut.size_byte_index != size_index)
        $fatal(1, "error modified LOAD state");
    end else if (content) begin
      if (dut.load_bytes_remaining != remaining - 1 ||
          dut.protocol_state !== (last_byte ? dut.WAIT_PREP_DONE : dut.RECEIVE_LOAD_DATA))
        $fatal(1, "content byte did not update LOAD progress");
    end else if (last_byte) begin
      if (dut.protocol_state !== dut.WAIT_LOAD_ACCEPT_SENT || dut.load_bytes_remaining != 8)
        $fatal(1, "valid size did not enter acceptance");
    end else
        if (dut.protocol_state !== dut.RECEIVE_LOAD_SIZE || dut.size_byte_index != size_index + 1)
      $fatal(1, "partial size byte did not advance the cursor");
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
