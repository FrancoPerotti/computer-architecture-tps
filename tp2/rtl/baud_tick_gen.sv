`timescale 1ns / 1ps

// Genera el pulso de sobremuestreo de la UART a partir del reloj del sistema.
module baud_tick_gen #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 19_200,
    parameter integer OVERSAMPLE  = 16
) (
    input  wire clk,
    input  wire reset,
    output reg  s_tick
);

  // RX y TX necesitan OVERSAMPLE pulsos por cada bit de la trama.
  localparam integer TICK_FREQ_HZ = BAUD_RATE * OVERSAMPLE;

  // DIVISOR es la cantidad de ciclos de clk entre pulsos. Sumar la mitad de
  // TICK_FREQ_HZ antes de dividir redondea al entero más cercano.
  localparam integer DIVISOR = (CLK_FREQ_HZ + (TICK_FREQ_HZ / 2)) / TICK_FREQ_HZ;

  // Se reservan los bits necesarios para contar desde cero hasta DIVISOR-1.
  // El mínimo de un bit evita un vector de ancho cero cuando DIVISOR vale uno.
  localparam integer COUNTER_WIDTH = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

  reg [COUNTER_WIDTH-1:0] counter = {COUNTER_WIDTH{1'b0}};

  // El contador vuelve a cero cada DIVISOR ciclos y, en ese mismo flanco, pone
  // s_tick en uno durante un ciclo. En los demás ciclos, s_tick permanece en
  // cero.
  always @(posedge clk) begin
    if (reset) begin
      counter <= {COUNTER_WIDTH{1'b0}};
      s_tick  <= 1'b0;
    end else if (counter == DIVISOR - 1) begin
      counter <= {COUNTER_WIDTH{1'b0}};
      s_tick  <= 1'b1;
    end else begin
      counter <= counter + 1'b1;
      s_tick  <= 1'b0;
    end
  end

  // Con estos valores de parámetros no se podría generar un tick válido.
  initial begin
    if (CLK_FREQ_HZ <= 0 || BAUD_RATE <= 0 || OVERSAMPLE <= 1 || DIVISOR <= 0) begin
      $error("Invalid baud_tick_gen parameters");
    end
  end
endmodule
