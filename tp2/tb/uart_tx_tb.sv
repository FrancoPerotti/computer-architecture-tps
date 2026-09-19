`timescale 1ns / 1ps

module uart_tx_tb;
  localparam integer OVERSAMPLE = 16;

  reg clk = 1'b0;
  reg reset = 1'b1;
  reg tx_start = 1'b0;
  reg s_tick = 1'b1;
  reg [7:0] data_in = 8'b0;
  wire tx;
  wire tx_done_tick;
  wire tx_busy;
  integer errors = 0;
  integer done_count = 0;
  integer bit_index;

  always #5 clk = ~clk;

  always @(posedge clk) begin
    #1;
    if (tx_done_tick) done_count = done_count + 1;
  end

  uart_tx #(
      .DATA_BITS (8),
      .OVERSAMPLE(OVERSAMPLE),
      .STOP_TICKS(OVERSAMPLE)
  ) dut (
      .clk         (clk),
      .reset       (reset),
      .tx_start    (tx_start),
      .s_tick      (s_tick),
      .data_in     (data_in),
      .tx          (tx),
      .tx_done_tick(tx_done_tick),
      .tx_busy     (tx_busy)
  );

  task automatic expect_level;
    input expected;
    input integer cycles;
    integer cycle_index;
    begin
      for (cycle_index = 0; cycle_index < cycles; cycle_index = cycle_index + 1) begin
        @(negedge clk);
        if (tx !== expected) begin
          errors = errors + 1;
          $display("ERROR: TX=%b expected=%b at cycle %0d", tx, expected, cycle_index);
        end
      end
    end
  endtask

  task automatic send_and_check;
    input [7:0] value;
    integer done_before;
    begin
      done_before = done_count;
      @(negedge clk);
      data_in = value;
      tx_start = 1'b1;
      @(posedge clk);
      #1;
      @(negedge clk);
      tx_start = 1'b0;

      // El primer intervalo del start ya transcurrio entre el flanco que
      // acepto tx_start y este flanco descendente.
      if (tx !== 1'b0) begin
        errors = errors + 1;
        $display("ERROR: TX did not enter start bit");
      end
      expect_level(1'b0, OVERSAMPLE - 1);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        expect_level(value[bit_index], OVERSAMPLE);
      end
      expect_level(1'b1, OVERSAMPLE);
      @(posedge clk);
      #1;

      if (done_count != done_before + 1 || tx_busy || tx !== 1'b1) begin
        errors = errors + 1;
        $display("ERROR: TX completion value=%h done delta=%0d busy=%b tx=%b", value,
                 done_count - done_before, tx_busy, tx);
      end
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    if (tx !== 1'b1 || tx_busy) begin
      errors = errors + 1;
      $display("ERROR: TX not idle after reset");
    end

    send_and_check(8'ha5);
    send_and_check(8'h00);
    send_and_check(8'hff);

    if (errors != 0) $fatal(1, "FAIL: %0d UART TX errors", errors);
    $display("PASS: UART transmitter framing and timing");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "FAIL: UART TX testbench timeout");
  end
endmodule
