module protocol_controller_run_tb;
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
  logic [ 7:0] response_opcode;
  logic [ 7:0] response_result;
  logic        response_with_debug;
  logic        load_request;
  logic        run_request;
  logic        step_request;
  logic [10:0] load_size_bytes;
  logic        load_byte_valid;
  logic [ 7:0] load_byte_data;
  logic [ 9:0] load_byte_offset;
  logic        load_last_byte;
  logic        load_abort;
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
  task automatic initialize;
    reset              = 1;
    rx_empty           = 1;
    rx_error_tick      = 0;
    rx_activity        = 0;
    response_busy      = 0;
    response_done_tick = 0;
    load_available     = 0;
    prepare_active     = 0;
    program_finished   = 0;
    fault_terminal     = 0;
    image_valid        = 0;
    command_accepted   = 0;
    cpu_cycle_fire     = 0;
    r_data             = 0;
    tick();
    reset = 0;
  endtask

  initial begin
    initialize();
    rx_empty         = 0;
    r_data           = CMD_RUN;
    command_accepted = 1;
    image_valid      = 1;
    #1;
    check(run_request && response_start && response_result == RESULT_ACCEPTED,
          "accepted RUN request and response");
    tick();
    check(dut.run_result_required, "accepted RUN marks terminal response pending");
    check(dut.protocol_state == 11'b00001000000, "waits for ACCEPTED physical end");
    response_busy    = 1;
    program_finished = 1;
    #1;
    check(debug_read_select && !dut.debug_hold, "terminal selects Debug before registering hold");
    check(!response_start, "does not start terminal response while ACCEPTED is busy");
    tick();
    check(dut.debug_hold, "Debug hold is registered");
    response_done_tick = 1;
    tick();
    check(dut.protocol_state == 11'b00100000000, "terminal observed before ACCEPTED end");
    response_done_tick = 0;
    response_busy      = 0;
    #1;
    check(response_start && response_with_debug && response_result == RESULT_FINISHED,
          "FINISHED Debug response starts after ACCEPTED");
    check(dut.run_result_required && debug_read_select,
          "Debug remains selected until capture edge");
    tick();
    response_busy    = 1;
    program_finished = 0;
    check(!dut.run_result_required && debug_read_select,
          "pending clears while Debug stays selected");
    response_done_tick = 1;
    tick();
    check(!dut.debug_hold && !debug_read_select, "physical Debug end releases hold");
    check(dut.protocol_state == 11'b00000000001, "RUN transaction completes");

    initialize();
    rx_empty         = 0;
    r_data           = CMD_RUN;
    command_accepted = 0;
    image_valid      = 0;
    #1;
    check(response_start && response_result == RESULT_NO_IMAGE && run_request,
          "RUN without image rejected");
    tick();
    initialize();
    rx_empty         = 0;
    r_data           = CMD_RUN;
    command_accepted = 0;
    image_valid      = 1;
    #1;
    check(response_start && response_result == RESULT_BUSY, "RUN unavailable reports BUSY");
    tick();

    initialize();
    rx_empty         = 0;
    r_data           = CMD_RUN;
    command_accepted = 1;
    image_valid      = 1;
    tick();
    rx_empty           = 1;
    response_busy      = 1;
    response_done_tick = 1;
    tick();
    response_done_tick = 0;
    response_busy      = 0;
    check(dut.protocol_state == 11'b00010000000, "RUN waits for terminal after ACCEPTED");
    fault_terminal = 1;
    #1;
    check(response_start && response_with_debug && response_result == RESULT_FAULT,
          "FAULT Debug response");
    tick();
    response_busy      = 1;
    fault_terminal     = 0;
    response_done_tick = 1;
    tick();
    check(!dut.debug_hold, "FAULT Debug completes physically");

    $display("PASS protocol_controller RUN");
    $finish;
  end
endmodule
