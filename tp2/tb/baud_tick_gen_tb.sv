`timescale 1ns / 1ps

module baud_tick_gen_tb;
  localparam integer CLK_FREQ_HZ = 1_000;
  localparam integer BAUD_RATE = 25;
  localparam integer OVERSAMPLE = 4;
  localparam integer EXPECTED_DIVISOR = 10;

  reg clk = 1'b0;
  reg reset = 1'b1;
  wire s_tick;
  integer cycles = 0;
  integer ticks = 0;
  integer last_tick_cycle = 0;
  integer errors = 0;

  always #5 clk = ~clk;

  baud_tick_gen #(
      .CLK_FREQ_HZ(CLK_FREQ_HZ),
      .BAUD_RATE  (BAUD_RATE),
      .OVERSAMPLE (OVERSAMPLE)
  ) dut (
      .clk   (clk),
      .reset (reset),
      .s_tick(s_tick)
  );

  always @(posedge clk) begin
    #1;
    if (!reset) begin
      cycles = cycles + 1;
      if (s_tick) begin
        ticks = ticks + 1;
        if ((cycles - last_tick_cycle) != EXPECTED_DIVISOR) begin
          errors = errors + 1;
          $display("ERROR: tick interval=%0d expected=%0d", cycles - last_tick_cycle,
                   EXPECTED_DIVISOR);
        end
        last_tick_cycle = cycles;
      end
    end
  end

  initial begin
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    repeat (35) @(posedge clk);
    #2;
    if (ticks != 3) begin
      errors = errors + 1;
      $display("ERROR: ticks=%0d expected=3", ticks);
    end

    @(negedge clk);
    reset = 1'b1;
    repeat (2) @(posedge clk);
    if (s_tick !== 1'b0) begin
      errors = errors + 1;
      $display("ERROR: tick must remain low during reset");
    end

    if (errors != 0) $fatal(1, "FAIL: %0d baud generator errors", errors);
    $display("PASS: baud tick generator");
    $finish;
  end
endmodule
