// Selecciona el dato little-endian de un load y aplica extensión de signo o cero.
module load_select_extend (
    input  system_pkg::word_t              mem_read_data,
    input  logic                     [1:0] address_low_bits,
    input  system_pkg::access_size_t       access_size,
    input  logic                           load_unsigned,
    output system_pkg::word_t              load_value
);
  import system_pkg::*;

  word_t        aligned_data;
  logic  [ 7:0] selected_byte;
  logic  [15:0] selected_halfword;

  assign aligned_data      = mem_read_data >> (8 * address_low_bits);
  assign selected_byte     = aligned_data[7:0];
  assign selected_halfword = aligned_data[15:0];

  always_comb begin
    case (access_size)
      ACCESS_SIZE_BYTE: begin
        load_value = load_unsigned ? word_t'({24'b0, selected_byte}) :
            word_t'({{24{selected_byte[7]}}, selected_byte});
      end
      ACCESS_SIZE_HALFWORD: begin
        load_value = load_unsigned ? word_t'({16'b0, selected_halfword}) :
            word_t'({{16{selected_halfword[15]}}, selected_halfword});
      end
      ACCESS_SIZE_WORD: load_value = mem_read_data;
      default:          load_value = '0;
    endcase
  end
endmodule
