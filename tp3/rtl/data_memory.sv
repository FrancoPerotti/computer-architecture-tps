// DMEM por lanes con cero lógico, mantenimiento por byte y lectura CPU/Debug compartida.
module data_memory #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0,
    localparam int unsigned BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
) (
    input  logic                                       clk,
    input  logic                                       reset,
    input  system_pkg::word_t                          address,
    input  system_pkg::word_t                          write_data,
    input  logic                                       write_enable,
    input  logic              [                   3:0] byte_enable,
    input  logic                                       prepare_dmem_clear,
    input  logic              [BYTE_ADDRESS_WIDTH-1:0] prepare_dmem_addr,
    input  logic                                       debug_read_select,
    input  logic              [BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr,
    output system_pkg::word_t                          mem_read_data,
    output logic              [                   7:0] debug_dmem_data,
    output logic                                       debug_dmem_used
);
  import system_pkg::*;

  generate
    if (!memory_capacity_valid(DMEM_CAPACITY_BYTES)) begin : gen_invalid_capacity
      initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
      assign mem_read_data   = '0;
      assign debug_dmem_data = '0;
      assign debug_dmem_used = 1'b0;
    end else begin : gen_valid_capacity
      localparam memory_capacity_t ROW_COUNT       = memory_word_count(DMEM_CAPACITY_BYTES);
      localparam int unsigned      ROW_INDEX_WIDTH = row_index_width(DMEM_CAPACITY_BYTES);

      logic [7:0] data_lane_0 [ROW_COUNT];
      logic [7:0] data_lane_1 [ROW_COUNT];
      logic [7:0] data_lane_2 [ROW_COUNT];
      logic [7:0] data_lane_3 [ROW_COUNT];
      logic       valid_lane_0[ROW_COUNT];
      logic       valid_lane_1[ROW_COUNT];
      logic       valid_lane_2[ROW_COUNT];
      logic       valid_lane_3[ROW_COUNT];

      word_t                                  read_address;
      memory_capacity_t                       read_row_full;
      logic             [ROW_INDEX_WIDTH-1:0] read_row;
      logic                                   read_row_in_range;
      memory_capacity_t                       write_row_full;
      logic             [ROW_INDEX_WIDTH-1:0] write_row;
      logic                                   write_row_in_range;
      memory_capacity_t                       prepare_address_full;
      logic             [ROW_INDEX_WIDTH-1:0] prepare_row;
      logic                                   prepare_address_in_range;
      logic             [                3:0] lane_mask;
      word_t                                  lane_write_data;
      logic             [                7:0] logical_lane_0;
      logic             [                7:0] logical_lane_1;
      logic             [                7:0] logical_lane_2;
      logic             [                7:0] logical_lane_3;

      assign read_address      = debug_read_select ? word_t'(debug_dmem_addr) : address;
      assign read_row_full     = memory_capacity_t'(read_address) >> 2;
      assign read_row          = read_address[ROW_INDEX_WIDTH+1:2];
      assign read_row_in_range = read_row_full < ROW_COUNT;

      assign write_row_full     = memory_capacity_t'(address) >> 2;
      assign write_row          = address[ROW_INDEX_WIDTH+1:2];
      assign write_row_in_range = write_row_full < ROW_COUNT;
      assign lane_mask          = byte_enable << address[1:0];
      assign lane_write_data    = write_data << (8 * address[1:0]);

      assign prepare_address_full     = memory_capacity_t'(prepare_dmem_addr);
      assign prepare_row              = ROW_INDEX_WIDTH'(prepare_address_full >> 2);
      assign prepare_address_in_range = prepare_address_full < DMEM_CAPACITY_BYTES;

      always_comb begin
        logical_lane_0 = '0;
        logical_lane_1 = '0;
        logical_lane_2 = '0;
        logical_lane_3 = '0;
        if (read_row_in_range) begin
          logical_lane_0 = valid_lane_0[read_row] ? data_lane_0[read_row] : 8'b0;
          logical_lane_1 = valid_lane_1[read_row] ? data_lane_1[read_row] : 8'b0;
          logical_lane_2 = valid_lane_2[read_row] ? data_lane_2[read_row] : 8'b0;
          logical_lane_3 = valid_lane_3[read_row] ? data_lane_3[read_row] : 8'b0;
        end
      end

      assign mem_read_data = {logical_lane_3, logical_lane_2, logical_lane_1, logical_lane_0};

      always_comb begin
        debug_dmem_data = '0;
        debug_dmem_used = 1'b0;
        if (read_row_in_range) begin
          case (read_address[1:0])
            2'd0: begin
              debug_dmem_data = logical_lane_0;
              debug_dmem_used = valid_lane_0[read_row];
            end
            2'd1: begin
              debug_dmem_data = logical_lane_1;
              debug_dmem_used = valid_lane_1[read_row];
            end
            2'd2: begin
              debug_dmem_data = logical_lane_2;
              debug_dmem_used = valid_lane_2[read_row];
            end
            default: begin
              debug_dmem_data = logical_lane_3;
              debug_dmem_used = valid_lane_3[read_row];
            end
          endcase
        end
      end

      always_ff @(posedge clk) begin
        if (!reset) begin
          assert (!(debug_read_select && (write_enable || prepare_dmem_clear)))
          else $fatal(1, "DMEM_OWNERSHIP_CONFLICT");
        end

        if (reset) begin
          // El reset bloquea actualizaciones; la preparación posterior restablece el cero lógico.
        end else if (prepare_dmem_clear && prepare_address_in_range) begin
          case (prepare_dmem_addr[1:0])
            2'd0: valid_lane_0[prepare_row] <= 1'b0;
            2'd1: valid_lane_1[prepare_row] <= 1'b0;
            2'd2: valid_lane_2[prepare_row] <= 1'b0;
            default: valid_lane_3[prepare_row] <= 1'b0;
          endcase
        end else if (write_enable && write_row_in_range) begin
          if (lane_mask[0]) begin
            data_lane_0[write_row]  <= lane_write_data[7:0];
            valid_lane_0[write_row] <= 1'b1;
          end
          if (lane_mask[1]) begin
            data_lane_1[write_row]  <= lane_write_data[15:8];
            valid_lane_1[write_row] <= 1'b1;
          end
          if (lane_mask[2]) begin
            data_lane_2[write_row]  <= lane_write_data[23:16];
            valid_lane_2[write_row] <= 1'b1;
          end
          if (lane_mask[3]) begin
            data_lane_3[write_row]  <= lane_write_data[31:24];
            valid_lane_3[write_row] <= 1'b1;
          end
        end
      end
    end
  endgenerate
endmodule
