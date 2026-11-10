`timescale 1ns / 1ps

// Verifica contadores, registros, selección de nivel y desplazamiento TX.
module tx_datapath_tb;
  localparam integer                  DATA_WIDTH  = system_pkg::UART_DATA_BITS;
  localparam logic   [DATA_WIDTH-1:0] SERIAL_BYTE = 8'hA5;
  tp3_case_data data ();
  logic                  clk = 1'b0;
  logic                  reset = 1'b1;
  logic [DATA_WIDTH-1:0] data_in = '0;
  logic                  sample_count_clear = 1'b0;
  logic                  sample_count_inc = 1'b0;
  logic                  bit_count_clear = 1'b0;
  logic                  bit_count_inc = 1'b0;
  logic                  data_load_enable = 1'b0;
  logic                  data_shift_enable = 1'b0;
  logic                  tx_write_enable = 1'b0;
  logic [           1:0] tx_output_select = 2'b00;
  logic                  sample_done;
  logic                  last_bit;
  logic                  tx;
  int                    transmitted_shifts = 0;
  logic [DATA_WIDTH-1:0] expected_shift;
  logic                  expected_tx;

  tx_datapath dut (.*);

  always #10 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic apply_controls(
      input logic reset_value, input logic sample_clear, input logic sample_inc,
      input logic bit_clear, input logic bit_inc, input logic load_enable, input logic shift_enable,
      input logic tx_enable, input logic [1:0] tx_select, input logic [DATA_WIDTH-1:0] input_value);
    @(negedge clk);
    reset              = reset_value;
    sample_count_clear = sample_clear;
    sample_count_inc   = sample_inc;
    bit_count_clear    = bit_clear;
    bit_count_inc      = bit_inc;
    data_load_enable   = load_enable;
    data_shift_enable  = shift_enable;
    tx_write_enable    = tx_enable;
    tx_output_select   = tx_select;
    data_in            = input_value;
    @(posedge clk);
    #1;
    @(negedge clk);
    reset              = 1'b0;
    sample_count_clear = 1'b0;
    sample_count_inc   = 1'b0;
    bit_count_clear    = 1'b0;
    bit_count_inc      = 1'b0;
    data_load_enable   = 1'b0;
    data_shift_enable  = 1'b0;
    tx_write_enable    = 1'b0;
  endtask

  task automatic check_counters(input logic [3:0] expected_sample, input logic [2:0] expected_bit);
    if (dut.sample_count !== expected_sample || dut.bit_count !== expected_bit) begin
      fail("counter value mismatch");
    end
    if (sample_done !== (expected_sample == 4'd15)) fail("sample_done mismatch");
    if (last_bit !== (expected_bit == 3'd7)) fail("last_bit mismatch");
  endtask

  task automatic write_selected(input logic [1:0] selection, input logic expected_tx,
                                input logic shift_enable,
                                input logic [DATA_WIDTH-1:0] expected_data);
    apply_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, shift_enable, 1'b1, selection, data_in);
    if (tx !== expected_tx) fail("TX output selection result mismatch");
    if (dut.data_reg !== expected_data) fail("simultaneous TX write/shift data mismatch");
  endtask

  initial begin
    data.load();
    repeat (2) @(posedge clk);
    #1;
    check_counters(4'd0, 3'd0);
    if (dut.data_reg !== 8'h00 || tx !== 1'b1)
      fail("reset did not clear datapath and idle TX high");

    // Sample count increments, retains, reaches fifteen, and clears before increment.
    for (int sample_index = 0; sample_index < 15; sample_index++) begin
      apply_controls(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, '0);
    end
    check_counters(4'd15, 3'd0);
    apply_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, '0);
    check_counters(4'd15, 3'd0);
    apply_controls(1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, '0);
    check_counters(4'd0, 3'd0);

    // Bit count likewise advances, retains and clears with priority over increment.
    for (int bit_index = 0; bit_index < 7; bit_index++) begin
      apply_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 2'b00, '0);
    end
    check_counters(4'd0, 3'd7);
    apply_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, '0);
    check_counters(4'd0, 3'd7);
    apply_controls(1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 2'b00, '0);
    check_counters(4'd0, 3'd0);

    // Load captures the byte, independent of later input changes; load wins over shift.
    apply_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, SERIAL_BYTE);
    if (dut.data_reg !== SERIAL_BYTE) fail("data load failed");
    apply_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 8'h3C);
    if (dut.data_reg !== SERIAL_BYTE) fail("data_in change altered the captured byte");
    apply_controls(1'b0, 1'b0, 0, 0, 0, 1, 1, 0, 2'b00, 8'h96);
    if (dut.data_reg !== 8'h96) fail("data load did not take priority over shift");
    apply_controls(1'b0, 1'b0, 0, 0, 0, 0, 1, 0, 2'b00, 8'h00);
    if (dut.data_reg !== 8'h4B) fail("right shift did not insert zero at the MSB");

    // The four mux encodings select HIGH, LOW, current bit and next bit.
    apply_controls(1'b0, 0, 0, 0, 0, 1, 0, 0, 2'b00, 8'h96);
    write_selected(2'b00, 1'b1, 1'b0, 8'h96);
    write_selected(2'b01, 1'b0, 1'b0, 8'h96);
    write_selected(2'b10, 1'b0, 1'b0, 8'h96);
    write_selected(2'b11, 1'b1, 1'b0, 8'h96);
    apply_controls(1'b0, 0, 0, 0, 0, 0, 0, 0, 2'b01, 8'h00);
    if (tx !== 1'b1) fail("TX output changed without tx_write_enable");

    // D0 is selected without shifting; each following bit uses old data_reg[1] and shifts together.
    apply_controls(1'b0, 0, 0, 0, 0, 1, 0, 0, 2'b00, SERIAL_BYTE);
    write_selected(2'b10, SERIAL_BYTE[0], 1'b0, SERIAL_BYTE);
    expected_shift = SERIAL_BYTE;
    for (int data_index = 1; data_index < DATA_WIDTH; data_index++) begin
      expected_tx    = expected_shift[1];
      expected_shift = {1'b0, expected_shift[DATA_WIDTH-1:1]};
      write_selected(2'b11, expected_tx, 1'b1, expected_shift);
      transmitted_shifts++;
    end
    if (transmitted_shifts != 7 || dut.data_reg !== 8'h01) begin
      fail("conceptual D0-D7 sequence duplicated or omitted a shift");
    end

    // Reset overrides all requests, clears data/counters and restores idle-high output.
    apply_controls(1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 2'b01, 8'hFF);
    check_counters(4'd0, 3'd0);
    if (dut.data_reg !== 8'h00 || tx !== 1'b1) fail("reset did not override datapath operations");

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
