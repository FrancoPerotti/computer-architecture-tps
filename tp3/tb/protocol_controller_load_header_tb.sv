module protocol_controller_load_header_tb #(
    parameter system_pkg::memory_capacity_t CAPACITY = system_pkg::REFERENCE_IMEM_CAPACITY_BYTES
);
  import system_pkg::*;
  localparam integer SIZE_WIDTH = system_pkg::capacity_inclusive_width(CAPACITY);
  logic clk = 0;
  always #5 clk = ~clk;
  logic                  reset;
  logic                  rx_empty;
  logic                  rx_error_tick;
  logic                  rx_activity;
  logic                  response_busy;
  logic                  response_done_tick;
  logic                  load_available;
  logic                  prepare_active;
  logic                  program_finished;
  logic                  fault_terminal;
  logic                  image_valid;
  logic                  command_accepted;
  logic                  cpu_cycle_fire;
  logic [           7:0] r_data;
  logic                  rd_uart;
  logic                  response_start;
  logic                  response_with_debug;
  logic [           7:0] response_opcode;
  logic [           7:0] response_result;
  logic                  load_request;
  logic                  run_request;
  logic                  step_request;
  logic                  load_byte_valid;
  logic                  load_last_byte;
  logic                  load_abort;
  logic [           7:0] load_byte_data;
  logic [           9:0] load_byte_offset;
  logic [SIZE_WIDTH-1:0] load_size_bytes;
  logic uart_reset_request, debug_read_select;
  logic [          39:0] valid_limit;
  logic [           7:0] observed_result;
  logic [           7:0] observed_opcode;
  logic                  observed_start;
  logic                  observed_load_request;
  logic [SIZE_WIDTH-1:0] observed_size;

  protocol_controller #(.IMEM_CAPACITY_BYTES(CAPACITY)) dut (.*);

  task automatic tick;
    @(posedge clk);
    #1;
  endtask
  task automatic check(input logic condition, input string message);
    if (!condition) $fatal(1, "%s", message);
  endtask
  task automatic restart;
    reset              = 1;
    rx_empty           = 1;
    rx_error_tick      = 0;
    response_busy      = 0;
    response_done_tick = 0;
    command_accepted   = 0;
    tick();
    reset = 0;
  endtask
  task automatic send_opcode;
    rx_empty = 0;
    r_data   = CMD_LOAD;
    tick();
    rx_empty = 1;
  endtask
  task automatic send_size(input logic [39:0] size);
    integer i;
    begin
      for (i = 0; i < 5; i = i + 1) begin
        rx_empty = 0;
        r_data   = size[8*i+:8];
        #1;
        if (i == 4) begin
          observed_start        = response_start;
          observed_opcode       = response_opcode;
          observed_result       = response_result;
          observed_load_request = load_request;
          observed_size         = load_size_bytes;
        end
        tick();
        rx_empty = 1;
      end
    end
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
    command_accepted   = 1;
    cpu_cycle_fire     = 0;
    r_data             = 0;
    valid_limit        = 40'(CAPACITY) & 40'hffff_ffff_fc;

    restart();
    send_opcode();
    check(dut.protocol_state == 11'b00000000010, "LOAD enters size reception");
    send_size(40'd4);
    check(dut.load_size_received == 40'd4, "little endian size captured");
    restart();
    send_opcode();
    command_accepted = 1;
    send_size(valid_limit);
    check(observed_start && observed_opcode == CMD_LOAD && observed_result == RESULT_ACCEPTED,
          "profile maximum accepted");
    check(observed_load_request && observed_size == SIZE_WIDTH'(valid_limit),
          "valid size request and width");
    check(dut.protocol_state == 11'b00000000100, "accepted header waits for ACCEPTED TX");
    restart();
    send_opcode();
    command_accepted = 1;
    send_size(40'd4);
    check(observed_result == RESULT_ACCEPTED && dut.protocol_state == 11'b00000000100,
          "small image accepted for content fixture");
    response_done_tick = 1;
    tick();
    response_done_tick = 0;
    check(dut.protocol_state == 11'b00000001000, "content starts after ACCEPTED physical end");
    check(load_size_bytes == SIZE_WIDTH'(4), "accepted size remains stable through content");
    begin
      integer byte_index;
      for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
        rx_empty = 0;
        r_data   = 8'hA0 + byte_index;
        #1;
        check(load_byte_valid && load_byte_data == r_data, "loader byte transfer");
        check(load_byte_offset == byte_index, "loader byte offset increments");
        check(load_last_byte == (byte_index == 3), "last byte marker");
        tick();
      end
    end
    rx_empty = 1;
    check(dut.protocol_state == 11'b00000010000, "last transfer enters preparation wait");
    prepare_active = 1;
    repeat (2) tick();
    check(!response_start, "DONE waits for preparation");
    prepare_active = 0;
    #1;
    check(response_start && response_opcode == CMD_LOAD && response_result == RESULT_DONE,
          "LOAD DONE descriptor after preparation");
    tick();
    check(dut.protocol_state == 11'b00100000000, "DONE waits for physical transmission");

    restart();
    send_opcode();
    send_size(40'd6);
    check(observed_start && observed_result == RESULT_INVALID_SIZE && !observed_load_request,
          "nonmultiple of four rejected");
    check(dut.protocol_state == 11'b00100000000, "invalid size waits for rejection TX");

    restart();
    send_opcode();
    send_size(40'd0);
    check(observed_result == RESULT_INVALID_SIZE, "zero size rejected");
    restart();
    send_opcode();
    send_size(valid_limit + 40'd4);
    check(observed_result == RESULT_INVALID_SIZE, "over-capacity size rejected");

    restart();
    send_opcode();
    command_accepted = 0;
    send_size(40'd4);
    check(
        observed_load_request && observed_result == RESULT_BUSY && observed_size == SIZE_WIDTH'(4),
        "valid but unavailable LOAD reports BUSY");

    restart();
    send_opcode();
    rx_empty = 0;
    r_data   = 8'h04;
    tick();
    rx_empty = 1;
    rx_empty = 0;
    r_data   = 8'h00;
    tick();
    rx_empty      = 1;
    rx_error_tick = 1;
    rx_empty      = 0;
    r_data        = 8'hff;
    #1;
    check(response_start && response_result == RESULT_UART_ERROR && !load_request,
          "UART error takes priority over byte");
    tick();
    check(dut.protocol_state == 11'b10000000000, "UART error recovers");

    restart();
    send_opcode();
    dut.inactivity_count = 23'd4_999_999;
    rx_empty             = 1;
    rx_error_tick        = 0;
    #1;
    check(response_start && response_result == RESULT_INCOMPLETE_REQUEST,
          "header timeout response");
    tick();
    check(dut.protocol_state == 11'b10000000000, "header timeout enters recovery");
    $display("PASS protocol_controller LOAD header capacity=%0d", CAPACITY);
    $finish;
  end
endmodule

module protocol_controller_load_header_reference_tb;
  protocol_controller_load_header_tb #(
      .CAPACITY(system_pkg::REFERENCE_IMEM_CAPACITY_BYTES)
  ) test ();
endmodule

module protocol_controller_load_header_alt_tb;
  protocol_controller_load_header_tb #(.CAPACITY(system_pkg::ALT_1000_IMEM_CAPACITY_BYTES)) test ();
endmodule
