`timescale 1ns / 1ps

// UART que puede recibir y transmitir al mismo tiempo, con un FIFO para cada sentido.
module uart_core #(
    parameter integer CLK_FREQ_HZ     = 100_000_000,
    parameter integer BAUD_RATE       = 19_200,
    parameter integer OVERSAMPLE      = 16,
    parameter integer FIFO_ADDR_WIDTH = 2
) (
    input  wire clk,
    input  wire reset,
    input  wire serial_rx,
    output wire serial_tx,

    output wire [7:0] r_data,
    input  wire       rd_uart,
    output wire       rx_empty,

    input  wire [7:0] w_data,
    input  wire       wr_uart,
    output wire       tx_full,

    output wire rx_error_tick
);

  // Señales internas del camino de recepción.
  wire synchronized_rx;
  wire sample_tick;
  wire [7:0] received_data;
  wire rx_done_tick;
  wire frame_error_tick;
  wire rx_full;

  // Señales internas del camino de transmisión.
  wire [7:0] transmit_data;
  wire tx_empty;
  wire tx_done_tick;
  wire tx_busy;
  wire tx_start;

  // Solo esta cadena toma directamente el pin asíncrono serial_rx.
  serial_input_sync rx_synchronizer (
      .clk         (clk),
      .reset       (reset),
      .serial_async(serial_rx),
      .serial_sync (synchronized_rx)
  );

  // RX y TX comparten un pulso de sobremuestreo.
  baud_tick_gen #(
      .CLK_FREQ_HZ(CLK_FREQ_HZ),
      .BAUD_RATE  (BAUD_RATE),
      .OVERSAMPLE (OVERSAMPLE)
  ) baud_generator (
      .clk   (clk),
      .reset (reset),
      .s_tick(sample_tick)
  );

  // Si la trama es válida, el receptor entrega el byte y activa rx_done_tick.
  uart_rx #(
      .DATA_BITS (8),
      .OVERSAMPLE(OVERSAMPLE),
      .STOP_TICKS(OVERSAMPLE)
  ) receiver (
      .clk             (clk),
      .reset           (reset),
      .rx              (synchronized_rx),
      .s_tick          (sample_tick),
      .rx_done_tick    (rx_done_tick),
      .frame_error_tick(frame_error_tick),
      .data_out        (received_data)
  );

  // Cada byte recibido correctamente se guarda en el FIFO RX si hay espacio.
  fifo #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) rx_fifo (
      .clk       (clk),
      .reset     (reset),
      .rd        (rd_uart),
      .wr        (rx_done_tick),
      .write_data(received_data),
      .read_data (r_data),
      .empty     (rx_empty),
      .full      (rx_full)
  );

  // El transmisor toma el primer byte del FIFO y lo retira al terminar el stop.
  fifo #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) tx_fifo (
      .clk       (clk),
      .reset     (reset),
      .rd        (tx_done_tick),
      .wr        (wr_uart),
      .write_data(w_data),
      .read_data (transmit_data),
      .empty     (tx_empty),
      .full      (tx_full)
  );

  // Si hay un byte pendiente, la transmisión comienza cuando TX queda libre.
  assign tx_start = !tx_empty && !tx_busy;

  uart_tx #(
      .DATA_BITS (8),
      .OVERSAMPLE(OVERSAMPLE),
      .STOP_TICKS(OVERSAMPLE)
  ) transmitter (
      .clk         (clk),
      .reset       (reset),
      .tx_start    (tx_start),
      .s_tick      (sample_tick),
      .data_in     (transmit_data),
      .tx          (serial_tx),
      .tx_done_tick(tx_done_tick),
      .tx_busy     (tx_busy)
  );

  // Si llega un byte con el FIFO lleno, no se puede guardar. rx_error_tick
  // también informa un start falso o un bit de stop inválido.
  assign rx_error_tick = frame_error_tick || (rx_done_tick && rx_full);
endmodule
