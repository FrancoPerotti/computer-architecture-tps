// Conserva contadores y muestras del receptor UART, sin lógica de control.
module rx_datapath (
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    input  logic       sample_count_clear,
    input  logic       sample_count_inc,
    input  logic       bit_count_clear,
    input  logic       bit_count_inc,
    input  logic       data_shift_enable,
    output logic       sample_half,
    output logic       sample_done,
    output logic       last_bit,
    output logic [7:0] data_out
);

  logic [3:0] sample_count = 4'b0000;
  logic [2:0] bit_count = 3'b000;
  logic [7:0] shift_register = 8'b0000_0000;

  always_ff @(posedge clk) begin
    if (reset) begin
      sample_count   <= 4'b0000;
      bit_count      <= 3'b000;
      shift_register <= 8'b0000_0000;
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

      if (data_shift_enable) begin
        shift_register <= {rx, shift_register[7:1]};
      end
    end
  end

  always_comb begin
    sample_half = (sample_count == 4'd7);
    sample_done = (sample_count == 4'd15);
    last_bit    = (bit_count == 3'd7);
    data_out    = shift_register;
  end
endmodule
