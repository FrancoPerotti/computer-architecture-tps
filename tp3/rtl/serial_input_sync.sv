`timescale 1ns / 1ps

// Sincroniza la entrada serie externa con el reloj funcional.
module serial_input_sync (
    input  logic clk,
    input  logic reset,
    input  logic serial_async,
    output logic serial_sync
);

  // Ambos registros comienzan en el nivel de reposo UART y forman el CDC.
  (* ASYNC_REG = "TRUE" *)logic serial_meta = 1'b1;
  (* ASYNC_REG = "TRUE" *)logic serial_reg = 1'b1;

  always_ff @(posedge clk) begin
    if (reset) begin
      serial_meta <= 1'b1;
      serial_reg  <= 1'b1;
    end else begin
      serial_meta <= serial_async;
      serial_reg  <= serial_meta;
    end
  end

  // Solo FF2 alimenta al receptor.
  assign serial_sync = serial_reg;
endmodule
