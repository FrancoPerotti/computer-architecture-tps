// IMEM por palabras: lectura combinacional y carga síncrona desde Loader.
module instruction_memory #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0,
    localparam int unsigned WORD_INDEX_WIDTH = system_pkg::word_index_width(IMEM_CAPACITY_BYTES)
) (
    input  logic                                     clk,
    input  logic                                     reset,
    input  system_pkg::word_t                        read_address,
    input  logic              [WORD_INDEX_WIDTH-1:0] imem_write_index,
    input  system_pkg::word_t                        imem_write_data,
    input  logic                                     imem_write_enable,
    output system_pkg::word_t                        instruction
);
  import system_pkg::*;

  generate
    if (!memory_capacity_valid(IMEM_CAPACITY_BYTES)) begin : gen_invalid_capacity
      // El array no se elabora para capacidades inválidas o un parámetro omitido.
      initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
      assign instruction = '0;
    end else begin : gen_valid_capacity
      localparam memory_capacity_t        WORD_COUNT       = memory_word_count(IMEM_CAPACITY_BYTES);
      localparam logic             [32:0] IMEM_LIMIT_BYTES = 33'(IMEM_CAPACITY_BYTES);
      word_t        words              [WORD_COUNT];
      logic  [32:0] read_end;
      logic         read_address_valid;

      // Se valida la dirección completa antes de reducirla al índice de palabra.
      assign read_end           = {1'b0, read_address} + 33'd4;
      assign read_address_valid = (read_address[1:0] == 2'b00) && (read_end <= IMEM_LIMIT_BYTES);

      always_comb begin
        // Cero define el bus fuera de rango; no representa una instrucción válida.
        instruction = '0;
        if (read_address_valid) begin
          instruction = words[read_address[WORD_INDEX_WIDTH+1:2]];
        end
      end

      // Loader entrega la habilitación de ownership y una palabra ya ensamblada.
      // Reset bloquea la escritura, pero conserva el contenido físico del array.
      always_ff @(posedge clk) begin
        if (!reset && imem_write_enable &&
            (memory_capacity_t'(imem_write_index) < WORD_COUNT)) begin
          words[imem_write_index] <= imem_write_data;
        end
      end
    end
  endgenerate
endmodule
