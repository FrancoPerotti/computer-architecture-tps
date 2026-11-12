module protocol_controller_step_tb;
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
  task automatic send_step(input logic accepted, input logic fire, input logic has_image);
    rx_empty         = 0;
    r_data           = CMD_STEP;
    command_accepted = accepted;
    cpu_cycle_fire   = fire;
    image_valid      = has_image;
    #1;
  endtask

  initial begin
    initialize();
    send_step(1, 1, 1);
    check(
        step_request && response_start && response_opcode == CMD_STEP &&
            response_result == RESULT_DONE && response_with_debug,
        "immediate STEP emits DONE with Debug");
    tick();
    check(dut.debug_hold && debug_read_select, "immediate STEP retains Debug");
    rx_empty           = 1;
    response_busy      = 1;
    response_done_tick = 1;
    tick();
    check(!dut.debug_hold && !debug_read_select, "immediate STEP releases after physical end");
    check(dut.protocol_state == 11'b00000000001, "immediate STEP completes");

    initialize();
    send_step(1, 0, 1);
    check(step_request && !response_start && dut.protocol_state == 11'b00000000001,
          "preparing STEP waits without ACCEPTED response");
    tick();
    check(dut.protocol_state == 11'b00000100000, "enters WAIT_STEP_END");
    rx_empty       = 1;
    cpu_cycle_fire = 0;
    repeat (2) tick();
    check(!response_start && !dut.debug_hold, "waits for effective CPU cycle");
    cpu_cycle_fire = 1;
    #1;
    check(response_start && response_result == RESULT_DONE && response_with_debug,
          "prepared STEP emits DONE with Debug");
    tick();
    check(dut.debug_hold, "prepared STEP holds observation");
    cpu_cycle_fire     = 0;
    response_busy      = 1;
    response_done_tick = 1;
    tick();
    check(!dut.debug_hold, "prepared STEP releases after physical response");

    initialize();
    send_step(0, 0, 0);
    check(
        step_request && response_start && response_result == RESULT_NO_IMAGE &&
            !response_with_debug,
        "rejected STEP without image");
    tick();
    initialize();
    send_step(0, 0, 1);
    check(response_start && response_result == RESULT_BUSY && !response_with_debug,
          "rejected STEP while busy");
    tick();

    $display("PASS protocol_controller STEP");
    $finish;
  end
endmodule
