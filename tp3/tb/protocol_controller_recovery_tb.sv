module protocol_controller_recovery_tb;
  import system_pkg::*;
  logic clk = 0;
  always #5 clk = ~clk;
  logic        reset;
  logic        rx_empty;
  logic        rx_error_tick;
  logic        rx_activity;
  logic        response_busy;
  logic        response_done_tick;
  logic        load_available;
  logic        prepare_active;
  logic        program_finished;
  logic        fault_terminal;
  logic        image_valid;
  logic        command_accepted;
  logic        cpu_cycle_fire;
  logic [ 7:0] r_data;
  logic        rd_uart;
  logic        response_start;
  logic        response_with_debug;
  logic [ 7:0] response_opcode;
  logic [ 7:0] response_result;
  logic        load_request;
  logic        run_request;
  logic        step_request;
  logic        load_byte_valid;
  logic        load_last_byte;
  logic        load_abort;
  logic [ 7:0] load_byte_data;
  logic [ 9:0] load_byte_offset;
  logic [10:0] load_size_bytes;
  logic        uart_reset_request;
  logic        debug_read_select;

  protocol_controller dut (.*);

  task automatic tick;
    @(posedge clk);
    #1;
  endtask
  task automatic check(input logic condition, input string message);
    if (!condition) $fatal(1, "%s", message);
  endtask

  initial begin
    reset              = 1;
    rx_empty           = 1;
    rx_error_tick      = 0;
    rx_activity        = 0;
    response_busy      = 0;
    response_done_tick = 0;
    load_available     = 1;
    prepare_active     = 0;
    program_finished   = 0;
    fault_terminal     = 0;
    image_valid        = 0;
    command_accepted   = 0;
    cpu_cycle_fire     = 0;
    r_data             = 0;
    tick();
    reset = 0;

    rx_empty = 0;
    r_data   = 8'hA7;
    #1;
    check(response_start && response_opcode == 8'hA7 && response_result == RESULT_UNKNOWN_COMMAND,
          "unknown opcode echoed");
    tick();
    check(dut.protocol_state == 11'b00100000000, "unknown response waits for TX");
    response_busy      = 1;
    response_done_tick = 0;
    repeat (2) begin
      tick();
      check(dut.protocol_state == 11'b00100000000, "no premature completion");
    end
    response_done_tick = 1;
    tick();
    check(dut.protocol_state == 11'b00000000001, "unknown response completes");

    response_done_tick = 0;
    response_busy      = 0;
    rx_error_tick      = 1;
    #1;
    check(!response_start, "UART error does not create a response");
    tick();
    check(dut.protocol_state == 11'b10000000000, "UART error starts recovery");
    rx_error_tick = 0;
    rx_empty      = 0;
    r_data        = CMD_CHECK_READY;
    #1;
    check(rd_uart && !response_start, "recovery discards command bytes");
    dut.inactivity_count = 23'd100;
    rx_activity          = 1;
    tick();
    check(dut.inactivity_count == 0, "activity restarts silence timer");
    rx_activity = 0;
    rx_empty    = 0;
    tick();
    check(dut.inactivity_count == 1 && dut.protocol_state == 11'b10000000000,
          "counting silence while draining RX");
    rx_empty             = 1;
    dut.inactivity_count = 23'd4_999_999;
    response_busy        = 1;
    #1;
    tick();
    check(dut.protocol_state == 11'b10000000000, "waits while response serializer busy");
    response_busy = 0;
    rx_empty      = 0;
    #1;
    tick();
    check(dut.protocol_state == 11'b10000000000, "requires empty RX after silence");
    rx_empty = 1;
    tick();
    check(dut.protocol_state == 11'b00000000001, "recovery completes after silence and idle TX");

    $display("PASS protocol_controller UNKNOWN_COMMAND and RECOVER_RX");
    $finish;
  end
endmodule
