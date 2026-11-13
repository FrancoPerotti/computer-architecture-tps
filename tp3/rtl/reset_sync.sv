// Acondicionador de TP2 con la interfaz de reset común de TP3.
module reset_sync (
    input  logic clk,
    input  logic async_reset_request,
    output logic reset
);
  (* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe = 2'b11;

  always_ff @(posedge clk or posedge async_reset_request) begin
    if (async_reset_request) begin
      reset_pipe <= 2'b11;
    end else begin
      reset_pipe <= {reset_pipe[0], 1'b0};
    end
  end

  assign reset = reset_pipe[1];
endmodule
