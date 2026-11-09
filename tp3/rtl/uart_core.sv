`timescale 1ns / 1ps

// Integra los caminos físicos RX y TX, con ticks compartidos y FIFO independientes.
module uart_core #(
    parameter longint unsigned CLK_FREQ_HZ     = system_pkg::FUNCTIONAL_CLOCK_HZ,
    parameter longint unsigned BAUD_RATE       = system_pkg::UART_BAUD_RATE,
    parameter int unsigned     OVERSAMPLE      = system_pkg::UART_OVERSAMPLE_FACTOR,
    parameter int unsigned     FIFO_ADDR_WIDTH = $clog2(system_pkg::UART_FIFO_DEPTH)
) (
    input  logic                                  clk,
    input  logic                                  reset,
    input  logic                                  serial_rx,
    output logic                                  serial_tx,
    output logic [system_pkg::UART_DATA_BITS-1:0] r_data,
    input  logic                                  rd_uart,
    output logic                                  rx_empty,
    input  logic [system_pkg::UART_DATA_BITS-1:0] w_data,
    input  logic                                  wr_uart,
    output logic                                  tx_full,
    output logic                                  rx_error_tick,
    output logic                                  rx_activity,
    output logic                                  rx_receiving,
    output logic                                  tx_done_tick
);

  logic                                  synchronized_rx;
  logic                                  s_tick;
  logic [system_pkg::UART_DATA_BITS-1:0] received_data;
  logic                                  rx_done_tick;
  logic                                  frame_error_tick;
  logic                                  rx_full;
  logic [system_pkg::UART_DATA_BITS-1:0] transmit_data;
  logic                                  tx_empty;
  logic                                  tx_busy;
  logic                                  tx_start;

  serial_input_sync rx_synchronizer (
      .clk,
      .reset,
      .serial_async(serial_rx),
      .serial_sync (synchronized_rx)
  );

  baud_tick_gen #(
      .CLK_FREQ_HZ(CLK_FREQ_HZ),
      .BAUD_RATE  (BAUD_RATE),
      .OVERSAMPLE (OVERSAMPLE)
  ) baud_generator (
      .clk,
      .reset,
      .s_tick
  );

  uart_rx receiver (
      .clk,
      .reset,
      .rx      (synchronized_rx),
      .s_tick,
      .data_out(received_data),
      .rx_done_tick,
      .frame_error_tick,
      .rx_receiving,
      .rx_activity
  );

  fifo #(
      .DATA_WIDTH(system_pkg::UART_DATA_BITS),
      .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) rx_fifo (
      .clk,
      .reset,
      .rd        (rd_uart),
      .wr        (rx_done_tick),
      .write_data(received_data),
      .read_data (r_data),
      .empty     (rx_empty),
      .full      (rx_full)
  );

  fifo #(
      .DATA_WIDTH(system_pkg::UART_DATA_BITS),
      .ADDR_WIDTH(FIFO_ADDR_WIDTH)
  ) tx_fifo (
      .clk,
      .reset,
      .rd        (tx_done_tick),
      .wr        (wr_uart),
      .write_data(w_data),
      .read_data (transmit_data),
      .empty     (tx_empty),
      .full      (tx_full)
  );

  assign tx_start = !reset && !tx_empty && !tx_busy;

  uart_tx transmitter (
      .clk,
      .reset,
      .tx_start,
      .s_tick,
      .data_in(transmit_data),
      .tx     (serial_tx),
      .tx_busy,
      .tx_done_tick
  );

  assign rx_error_tick = frame_error_tick || (rx_done_tick && rx_full);

  initial begin
    if (OVERSAMPLE != system_pkg::UART_OVERSAMPLE_FACTOR) begin
      $error("uart_core submodules require the configured UART oversampling factor");
    end
  end
endmodule
