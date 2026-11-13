`timescale 1ns / 1ps

// Modelo dirigido por el banco para ejercitar los eventos y solapamientos de reset.
module clock_generator (
    input  logic clk_in1,
    input  logic reset,
    output logic clk_out1 = 0,
    output logic locked
);
  bit lock_available;
  bit independent_sources;

  assign locked = lock_available && (independent_sources || !reset);

  always @(posedge clk_in1 or posedge reset) begin
    if (reset && !independent_sources) clk_out1 <= 0;
    else clk_out1 <= !clk_out1;
  end
endmodule
