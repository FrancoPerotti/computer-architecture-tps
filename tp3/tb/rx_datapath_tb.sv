`timescale 1ns / 1ps

// Comprueba contadores, comparadores y orden de bits del datapath RX.
module rx_datapath_tb;
  localparam logic [7:0] SERIAL_BYTE = 8'hA5;
  tp3_case_data data ();
  logic       clk = 1'b0;
  logic       reset = 1'b1;
  logic       rx = 1'b0;
  logic       sample_count_clear = 1'b0;
  logic       sample_count_inc = 1'b0;
  logic       bit_count_clear = 1'b0;
  logic       bit_count_inc = 1'b0;
  logic       data_shift_enable = 1'b0;
  logic       sample_half;
  logic       sample_done;
  logic       last_bit;
  logic [7:0] data_out;

  rx_datapath dut (.*);

  always #10 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic clock_step;
    @(posedge clk);
    #1;
  endtask

  task automatic set_controls(input logic sclear, input logic sinc, input logic bclear,
                              input logic binc, input logic shift_enable);
    @(negedge clk);
    sample_count_clear = sclear;
    sample_count_inc   = sinc;
    bit_count_clear    = bclear;
    bit_count_inc      = binc;
    data_shift_enable  = shift_enable;
    clock_step();
    @(negedge clk);
    sample_count_clear = 1'b0;
    sample_count_inc   = 1'b0;
    bit_count_clear    = 1'b0;
    bit_count_inc      = 1'b0;
    data_shift_enable  = 1'b0;
  endtask

  initial begin
    data.load();
    repeat (2) clock_step();
    if (dut.sample_count !== 4'd0 || dut.bit_count !== 3'd0 || data_out !== 8'h00 || sample_half ||
        sample_done || last_bit) begin
      fail("reset did not clear datapath resources");
    end
    @(negedge clk);
    reset = 1'b0;

    // Test retained state, increments, boundary flags, and clear priority.
    repeat (7) set_controls(1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
    if (!sample_half || sample_done) fail("sample_half boundary mismatch at seven");
    repeat (8) set_controls(1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
    if (!sample_done || sample_half) fail("sample_done boundary mismatch at fifteen");
    set_controls(1'b1, 1'b1, 1'b1, 1'b1, 1'b0);
    if (dut.sample_count !== 4'd0 || dut.bit_count !== 3'd0) begin
      fail("clear did not take priority over increment");
    end
    if (sample_half || sample_done || last_bit) fail("clear left a boundary flag asserted");

    // Bit counter advances to seven, holds, clears, then tests modulo width.
    repeat (7) set_controls(1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
    if (!last_bit) fail("last_bit boundary mismatch at seven");
    set_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    if (!last_bit) fail("bit counter did not retain its value");
    set_controls(1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
    if (dut.bit_count !== 3'd0 || last_bit) fail("bit clear priority mismatch");

    // Capture 0xA5 least-significant bit first; result must be D7..D0 = A5.
    for (int bit_index = 0; bit_index < 8; bit_index++) begin
      rx = SERIAL_BYTE[bit_index];
      set_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
    end
    if (data_out !== 8'hA5) fail("serial samples were not shifted into D7..D0 order");
    rx = ~rx;
    set_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    if (data_out !== 8'hA5) fail("shift register changed while disabled");

    // Reset wins over simultaneous counter and shift requests.
    @(negedge clk);
    sample_count_inc  = 1'b1;
    bit_count_inc     = 1'b1;
    data_shift_enable = 1'b1;
    rx                = 1'b1;
    reset             = 1'b1;
    clock_step();
    if (dut.sample_count !== 4'd0 || dut.bit_count !== 3'd0 || data_out !== 8'h00) begin
      fail("reset did not override simultaneous resource updates");
    end
    if (sample_half || sample_done || last_bit) fail("reset boundary flags were not cleared");

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
