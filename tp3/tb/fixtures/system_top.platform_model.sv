`timescale 1ns / 1ps

// Consumidor síncrono del reset y modelo de la frontera de la #15.
module system_top #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 0,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 0
) (
    input  logic clk,
    input  logic reset,
    input  logic serial_rx,
    output logic serial_tx,
    output logic uart_reset_request
);
  bit response_done_tick;
  bit injected_request;
  bit registered_request;
  bit functional_operation;

  assign uart_reset_request = registered_request || injected_request;
  assign serial_tx          = reset || serial_rx;

  always @(posedge clk) begin
    registered_request   <= !reset && response_done_tick;
    functional_operation <= !reset;
  end
endmodule
