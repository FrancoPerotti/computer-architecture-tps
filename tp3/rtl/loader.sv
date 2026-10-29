// Ensambla bytes little-endian y habilita la escritura al recibir el cuarto.
module loader #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_IMEM_CAPACITY_BYTES,
    // Anchos derivados para tamaño inclusive, posición de byte e índice de palabra.
    localparam integer IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES),
    localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(IMEM_CAPACITY_BYTES),
    localparam integer WORD_INDEX_WIDTH = system_pkg::word_index_width(IMEM_CAPACITY_BYTES)
) (
    input  logic                          clk,
    input  logic                          reset,
    input  logic                          loader_active,
    input  logic                          load_start,
    input  logic [  IMAGE_SIZE_WIDTH-1:0] load_size_bytes,
    input  logic                          load_byte_valid,
    input  logic [                   7:0] load_byte_data,
    input  logic [BYTE_ADDRESS_WIDTH-1:0] load_byte_offset,
    input  logic                          load_last_byte,
    input  logic                          load_abort,
    output logic [  WORD_INDEX_WIDTH-1:0] imem_write_index,
    output logic [                  31:0] imem_write_data,
    output logic                          imem_write_enable,
    output logic                          load_ok,
    output logic                          load_fail,
    output logic [  IMAGE_SIZE_WIDTH-1:0] pending_image_size_bytes
);
  import system_pkg::*;

  if (!memory_capacity_valid(IMEM_CAPACITY_BYTES)) begin : g_invalid_capacity
    initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
  end else begin : g_valid_capacity
    logic [23:0] partial_word;
    logic [ 1:0] byte_lane;
    logic        byte_capture;

    assign byte_lane                = load_byte_offset[1:0];
    assign imem_write_index         = WORD_INDEX_WIDTH'(load_byte_offset >> 2);
    assign imem_write_data          = {load_byte_data, partial_word};
    assign pending_image_size_bytes = load_size_bytes;

    assign byte_capture      = loader_active && load_byte_valid && !reset && !load_abort;
    assign imem_write_enable = byte_capture && byte_lane == 2'd3;
    assign load_ok           = imem_write_enable && load_last_byte;
    assign load_fail         = loader_active && load_abort && !reset;

    // load_start no necesita borrar residuos: los lanes 0–2 los reemplazan.
    always_ff @(posedge clk) begin
      if (byte_capture) begin
        case (byte_lane)
          2'd0: partial_word[7:0] <= load_byte_data;
          2'd1: partial_word[15:8] <= load_byte_data;
          2'd2: partial_word[23:16] <= load_byte_data;
          default: begin
            // El lane 3 se consume directamente en la escritura de IMEM.
          end
        endcase
      end
    end
  end
endmodule
