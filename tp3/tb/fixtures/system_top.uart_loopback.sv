// Fixture físico que retransmite un byte y pide reset cuando termina el envío.
module system_top #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 0,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 0
) (
    input  logic clk,
    input  logic reset,
    input  logic serial_rx,
    output logic serial_tx,
    output logic uart_reset_request = 1'b0
);
  logic [system_pkg::UART_DATA_BITS-1:0] received_byte;
  logic                                  rx_empty;
  logic                                  tx_full;
  logic                                  transfer;
  logic                                  tx_done_tick;

  assign transfer = !reset && !rx_empty && !tx_full;

  always_ff @(posedge clk) begin
    uart_reset_request <= !reset && tx_done_tick;
  end

  uart_core transport (
      .clk,
      .reset,
      .serial_rx,
      .serial_tx,
      .r_data       (received_byte),
      .rd_uart      (transfer),
      .rx_empty,
      .w_data       (received_byte),
      .wr_uart      (transfer),
      .tx_full,
      .rx_error_tick(),
      .rx_activity  (),
      .rx_receiving (),
      .tx_done_tick
  );
endmodule
