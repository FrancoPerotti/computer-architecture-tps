// Integra el control y los recursos del transmisor UART.
module uart_tx (
    input  logic                                  clk,
    input  logic                                  reset,
    input  logic                                  tx_start,
    input  logic                                  s_tick,
    input  logic [system_pkg::UART_DATA_BITS-1:0] data_in,
    output logic                                  tx,
    output logic                                  tx_busy,
    output logic                                  tx_done_tick
);

  logic       sample_done;
  logic       last_bit;
  logic       sample_count_clear;
  logic       sample_count_inc;
  logic       bit_count_clear;
  logic       bit_count_inc;
  logic       data_load_enable;
  logic       data_shift_enable;
  logic       tx_write_enable;
  logic [1:0] tx_output_select;

  tx_fsm transmitter_control (
      .clk,
      .reset,
      .tx_start,
      .s_tick,
      .sample_done,
      .last_bit,
      .sample_count_clear,
      .sample_count_inc,
      .bit_count_clear,
      .bit_count_inc,
      .data_load_enable,
      .data_shift_enable,
      .tx_write_enable,
      .tx_output_select,
      .tx_busy,
      .tx_done_tick
  );

  tx_datapath transmitter_datapath (
      .clk,
      .reset,
      .data_in,
      .sample_count_clear,
      .sample_count_inc,
      .bit_count_clear,
      .bit_count_inc,
      .data_load_enable,
      .data_shift_enable,
      .tx_write_enable,
      .tx_output_select,
      .sample_done,
      .last_bit,
      .tx
  );
endmodule
