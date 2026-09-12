`timescale 1ns / 1ps

// Sincroniza la entrada serie externa con el reloj del sistema.
module serial_input_sync (
    input  wire clk,
    input  wire reset,
    input  wire serial_async,
    output wire serial_sync
);

  // Ambos registros comienzan en el nivel de reposo de la UART.
  // ASYNC_REG indica a Vivado que estos registros forman un sincronizador.
  (* ASYNC_REG = "TRUE" *)reg serial_meta = 1'b1;
  (* ASYNC_REG = "TRUE" *)reg serial_reg = 1'b1;

  // La primera etapa puede quedar metaestable; la segunda entrega al receptor
  // una señal estable y sincronizada con clk.
  always @(posedge clk) begin
    if (reset) begin
      serial_meta <= 1'b1;
      serial_reg  <= 1'b1;
    end else begin
      serial_meta <= serial_async;
      serial_reg  <= serial_meta;
    end
  end

  // Solo la segunda etapa se utiliza fuera del sincronizador.
  assign serial_sync = serial_reg;
endmodule
