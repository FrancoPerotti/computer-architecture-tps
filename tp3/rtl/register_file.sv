// Banco arquitectónico con dos lecturas combinacionales y escritura síncrona.
module register_file (
    input  logic                        clk,
    input  logic                        reset,
    input  logic                        prepare_init,
    input  system_pkg::register_index_t read_register_1,
    input  system_pkg::register_index_t read_register_2,
    input  system_pkg::register_index_t debug_rf_addr,
    input  logic                        debug_read_select,
    input  system_pkg::register_index_t write_register,
    input  system_pkg::word_t           write_data,
    input  logic                        write_enable,
    output system_pkg::word_t           rf_rs1_value,
    output system_pkg::word_t           rf_rs2_value,
    output system_pkg::word_t           debug_rf_data
);
  import system_pkg::*;

  // x0 es constante; solo x1 a x31 necesitan flip-flops.
  localparam int unsigned REGISTER_COUNT = 32;
  word_t           registers      [1:REGISTER_COUNT-1];
  register_index_t read_address_1;

  // Debug comparte el primer puerto mediante la selección de su dirección.
  assign read_address_1 = debug_read_select ? debug_rf_addr : read_register_1;

  // Las lecturas devuelven cero para x0, sin acceder al almacenamiento.
  assign rf_rs1_value = read_address_1 == '0 ? '0 : registers[read_address_1];
  assign rf_rs2_value = read_register_2 == '0 ? '0 : registers[read_register_2];

  // Debug observa el dato base del primer puerto, antes del bypass externo.
  assign debug_rf_data = rf_rs1_value;

  always_ff @(posedge clk) begin
    if (reset || prepare_init) begin
      // Inicialización síncrona en paralelo: x1 a x31 se ponen en cero en este mismo flanco.
      for (int unsigned index = 1; index < REGISTER_COUNT; index++) begin
        registers[index] <= '0;
      end
    end else if (write_enable && write_register != '0) begin
      // Captura el dato preflanco en el destino habilitado; las escrituras a x0 se ignoran.
      registers[write_register] <= write_data;
    end
  end
endmodule
