`timescale 1ns / 1ps

// Conserva los recursos de transmisión UART, sin lógica de control.
module tx_datapath (
    input  logic                                  clk,
    input  logic                                  reset,
    input  logic [system_pkg::UART_DATA_BITS-1:0] data_in,
    input  logic                                  sample_count_clear,
    input  logic                                  sample_count_inc,
    input  logic                                  bit_count_clear,
    input  logic                                  bit_count_inc,
    input  logic                                  data_load_enable,
    input  logic                                  data_shift_enable,
    input  logic                                  tx_write_enable,
    input  logic [                           1:0] tx_output_select,
    output logic                                  sample_done,
    output logic                                  last_bit,
    output logic                                  tx
);

  logic [                           3:0] sample_count = 4'b0000;
  logic [                           2:0] bit_count = 3'b000;
  logic [system_pkg::UART_DATA_BITS-1:0] data_reg = '0;
  logic                                  tx_reg = 1'b1;
  logic                                  tx_value;

  always_comb begin
    sample_done = (sample_count == 4'd15);
    last_bit    = (bit_count == 3'd7);

    case (tx_output_select)
      2'b00:   tx_value = 1'b1;
      2'b01:   tx_value = 1'b0;
      2'b10:   tx_value = data_reg[0];
      2'b11:   tx_value = data_reg[1];
      default: tx_value = 1'b1;
    endcase

    tx = tx_reg;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      sample_count <= 4'b0000;
      bit_count    <= 3'b000;
      data_reg     <= '0;
      tx_reg       <= 1'b1;
    end else begin
      if (sample_count_clear) begin
        sample_count <= 4'b0000;
      end else if (sample_count_inc) begin
        sample_count <= sample_count + 4'b0001;
      end

      if (bit_count_clear) begin
        bit_count <= 3'b000;
      end else if (bit_count_inc) begin
        bit_count <= bit_count + 3'b001;
      end

      if (data_load_enable) begin
        data_reg <= data_in;
      end else if (data_shift_enable) begin
        data_reg <= {1'b0, data_reg[system_pkg::UART_DATA_BITS-1:1]};
      end

      if (tx_write_enable) begin
        tx_reg <= tx_value;
      end
    end
  end
endmodule
