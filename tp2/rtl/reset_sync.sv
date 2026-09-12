`timescale 1ns / 1ps

// Acondiciona un reset externo: se activa de inmediato y se desactiva después
// de dos flancos del reloj.
module reset_sync (
    input  wire clk,
    input  wire async_reset,
    output wire reset
);

  // ASYNC_REG indica a Vivado que estos dos registros forman un sincronizador.
  (* ASYNC_REG = "TRUE" *) reg [1:0] reset_pipe = 2'b11;

  // Si async_reset se pone en 1, el reset se activa sin esperar un flanco de clk.
  // Al volver a 0, reset_pipe pasa por 2'b10 y 2'b00 en los dos flancos siguientes.
  always @(posedge clk or posedge async_reset) begin
    if (async_reset) begin
      reset_pipe <= 2'b11;
    end else begin
      reset_pipe <= {reset_pipe[0], 1'b0};
    end
  end

  // Solo la salida de la segunda etapa se conecta con el resto del diseño.
  assign reset = reset_pipe[1];
endmodule
