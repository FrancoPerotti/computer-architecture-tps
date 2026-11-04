// Emite controles para inicializar la sesión y limpiar una marca de DMEM por flanco.
module session_preparation #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_DMEM_CAPACITY_BYTES,
    // El índice incluye C, además de las direcciones 0 a C-1.
    localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES),
    localparam integer PREP_INDEX_WIDTH = system_pkg::capacity_inclusive_width(DMEM_CAPACITY_BYTES)
) (
    input  logic                          clk,
    input  logic                          reset,
    input  logic                          prepare_active,
    output logic                          prepare_init,
    output logic                          prepare_dmem_clear,
    output logic [BYTE_ADDRESS_WIDTH-1:0] prepare_dmem_addr,
    output logic                          prepare_done
);
  import system_pkg::*;

  if (!memory_capacity_valid(DMEM_CAPACITY_BYTES)) begin : g_invalid_capacity
    initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
  end else begin : g_valid_capacity
    // Cantidad de marcas que se deben limpiar.
    localparam logic [PREP_INDEX_WIDTH-1:0] PREP_LIMIT = PREP_INDEX_WIDTH'(DMEM_CAPACITY_BYTES);
    logic [PREP_INDEX_WIDTH-1:0] prepare_index;
    logic                        prepare_index_inc;

    // Inicializa PC, RF, pipeline y contador junto con la primera limpieza.
    assign prepare_init = !reset && prepare_active && prepare_index == '0;

    assign prepare_dmem_clear = !reset && prepare_active && prepare_index < PREP_LIMIT;
    assign prepare_dmem_addr  = BYTE_ADDRESS_WIDTH'(prepare_index);

    // La FSM consume done después del último clear, sin mantenimiento concurrente.
    assign prepare_done      = !reset && prepare_active && prepare_index == PREP_LIMIT;
    assign prepare_index_inc = prepare_dmem_clear;

    always_ff @(posedge clk) begin
      if (reset || !prepare_active) begin
        prepare_index <= '0;
      end else if (prepare_index_inc) begin
        prepare_index <= prepare_index + PREP_INDEX_WIDTH'(1);
      end
    end
  end
endmodule
