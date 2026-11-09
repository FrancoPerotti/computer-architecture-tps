// Genera el pulso de sobremuestreo de la UART a partir del reloj funcional.
module baud_tick_gen #(
    parameter longint unsigned CLK_FREQ_HZ = system_pkg::FUNCTIONAL_CLOCK_HZ,
    parameter longint unsigned BAUD_RATE   = system_pkg::UART_BAUD_RATE,
    parameter int unsigned     OVERSAMPLE  = system_pkg::UART_OVERSAMPLE_FACTOR
) (
    input  logic clk,
    input  logic reset,
    output logic s_tick
);

  // RX y TX necesitan OVERSAMPLE pulsos por cada bit de la trama.
  localparam longint unsigned TICK_FREQ_HZ = BAUD_RATE * OVERSAMPLE;

  // Sumar la mitad de la frecuencia de ticks redondea al entero más cercano.
  localparam longint unsigned DIVISOR       = (CLK_FREQ_HZ + (TICK_FREQ_HZ / 2)) / TICK_FREQ_HZ;
  localparam int unsigned     COUNTER_WIDTH = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

  logic [COUNTER_WIDTH-1:0] counter = {COUNTER_WIDTH{1'b0}};

  // Genera un pulso registrado cada DIVISOR clocks funcionales.
  always_ff @(posedge clk) begin
    if (reset) begin
      counter <= {COUNTER_WIDTH{1'b0}};
      s_tick  <= 1'b0;
    end else if (counter == COUNTER_WIDTH'(DIVISOR - 1)) begin
      counter <= {COUNTER_WIDTH{1'b0}};
      s_tick  <= 1'b1;
    end else begin
      counter <= counter + 1'b1;
      s_tick  <= 1'b0;
    end
  end

  initial begin
    if (CLK_FREQ_HZ <= 0 || BAUD_RATE <= 0 || OVERSAMPLE <= 1 || DIVISOR <= 0) begin
      $error("Invalid baud_tick_gen parameters");
    end
  end
endmodule
