`timescale 1ns / 1ps

// Integra la UART, el protocolo de tres bytes y la ALU sobre la Basys 3.
module alu_uart_top #(
    parameter integer CLK_FREQ_HZ            = 100_000_000,
    parameter integer BAUD_RATE              = 19_200,
    parameter integer OVERSAMPLE             = 16,
    parameter integer FIFO_ADDR_WIDTH        = 2,
    parameter integer TRANSACTION_TIMEOUT_MS = 10
) (
    input  wire        clk,
    input  wire        btn_reset,
    input  wire        serial_rx,
    output wire        serial_tx,
    output wire [10:0] leds
);

  // Interconexión entre el núcleo UART y el controlador de transacciones.
  // El controlador solo observa bytes completos y el estado de ambos FIFO.
  wire reset;
  wire [7:0] read_data;
  wire read_uart;
  wire rx_empty;
  wire rx_error_tick;
  wire [7:0] write_data;
  wire write_uart;
  wire tx_full;

  // El pulsador activa el reset de inmediato y lo desactiva después de dos
  // flancos de clk desde que se lo suelta.
  reset_sync reset_conditioner (
      .clk        (clk),
      .async_reset(btn_reset),
      .reset      (reset)
  );

  // Este bloque contiene el sincronizador, el generador de baud, RX, TX y los FIFO.
  uart_core #(
      .CLK_FREQ_HZ    (CLK_FREQ_HZ),
      .BAUD_RATE      (BAUD_RATE),
      .OVERSAMPLE     (OVERSAMPLE),
      .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) uart (
      .clk          (clk),
      .reset        (reset),
      .serial_rx    (serial_rx),
      .serial_tx    (serial_tx),
      .r_data       (read_data),
      .rd_uart      (read_uart),
      .rx_empty     (rx_empty),
      .w_data       (write_data),
      .wr_uart      (write_uart),
      .tx_full      (tx_full),
      .rx_error_tick(rx_error_tick)
  );

  // El controlador recibe A, B y opcode, ejecuta la ALU y guarda la respuesta.
  alu_uart_controller #(
      .CLK_FREQ_HZ           (CLK_FREQ_HZ),
      .TRANSACTION_TIMEOUT_MS(TRANSACTION_TIMEOUT_MS)
  ) controller (
      .clk          (clk),
      .reset        (reset),
      .r_data       (read_data),
      .rd_uart      (read_uart),
      .rx_empty     (rx_empty),
      .rx_error_tick(rx_error_tick),
      .w_data       (write_data),
      .wr_uart      (write_uart),
      .tx_full      (tx_full),
      .leds         (leds)
  );
endmodule
