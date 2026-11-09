`timescale 1ns / 1ps

// Integra el control y los recursos del receptor UART, además de detectar actividad RX.
module uart_rx (
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    input  logic       s_tick,
    output logic [7:0] data_out,
    output logic       rx_done_tick,
    output logic       frame_error_tick,
    output logic       rx_receiving,
    output logic       rx_activity
);

  logic sample_half;
  logic sample_done;
  logic last_bit;
  logic sample_count_clear;
  logic sample_count_inc;
  logic bit_count_clear;
  logic bit_count_inc;
  logic data_shift_enable;
  logic rx_previous = 1'b1;

  rx_fsm receiver_control (
      .clk,
      .reset,
      .rx,
      .s_tick,
      .sample_half,
      .sample_done,
      .last_bit,
      .sample_count_clear,
      .sample_count_inc,
      .bit_count_clear,
      .bit_count_inc,
      .data_shift_enable,
      .rx_done_tick,
      .frame_error_tick,
      .rx_receiving
  );

  rx_datapath receiver_datapath (
      .clk,
      .reset,
      .rx,
      .sample_count_clear,
      .sample_count_inc,
      .bit_count_clear,
      .bit_count_inc,
      .data_shift_enable,
      .sample_half,
      .sample_done,
      .last_bit,
      .data_out
  );

  always_ff @(posedge clk) begin
    if (reset) begin
      rx_previous <= 1'b1;
    end else begin
      rx_previous <= rx;
    end
  end

  always_comb begin
    rx_activity = 1'b0;
    if (!reset) begin
      rx_activity = (rx != rx_previous) || !rx || rx_receiving;
    end
  end
endmodule
