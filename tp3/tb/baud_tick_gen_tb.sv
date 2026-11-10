`timescale 1ns / 1ps

// Comprueba divisor, periodicidad, anchura y reinicio del generador UART.
module baud_tick_gen_tb;
  localparam integer DIVISOR = 163;

  tp3_case_data data ();
  logic   clk = 1'b0;
  logic   reset = 1'b1;
  wire    s_tick;
  integer edge_count = 0;
  integer tick_count = 0;
  integer previous_tick_edge = 0;

  baud_tick_gen dut (
      .clk   (clk),
      .reset (reset),
      .s_tick(s_tick)
  );

  always #10 clk = ~clk;
  always @(posedge clk) edge_count = edge_count + 1;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  initial begin
    data.load();
    if (dut.DIVISOR != DIVISOR) fail("default divisor is not 163");
    repeat (2) @(posedge clk);
    #1;
    if (s_tick !== 1'b0 || dut.counter !== '0) fail("reset did not clear state");
    @(negedge clk);
    reset = 1'b0;

    while (tick_count < 3) begin
      @(posedge clk);
      #1;
      if (s_tick) begin
        tick_count = tick_count + 1;
        if (tick_count == 1 && edge_count != DIVISOR + 2) begin
          fail("first tick did not follow 163 free-running clocks");
        end
        if (tick_count > 1 && edge_count - previous_tick_edge != DIVISOR) begin
          fail("consecutive ticks are not 163 clocks apart");
        end
        previous_tick_edge = edge_count;
      end
    end
    @(posedge clk);
    #1;
    if (s_tick !== 1'b0) fail("tick lasted more than one clock");

    repeat (37) @(posedge clk);
    @(negedge clk);
    reset = 1'b1;
    @(posedge clk);
    #1;
    if (s_tick !== 1'b0 || dut.counter !== '0) fail("mid-count reset failed");
    @(negedge clk);
    reset = 1'b0;
    repeat (DIVISOR - 1) begin
      @(posedge clk);
      #1;
      if (s_tick !== 1'b0) fail("tick appeared before a full post-reset period");
    end
    @(posedge clk);
    #1;
    if (s_tick !== 1'b1) fail("post-reset tick did not arrive after 163 clocks");

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
