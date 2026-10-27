// Conserva la identidad y el valor final que MEM entrega a WB.
module mem_wb_register (
    input  logic                clk,
    input  logic                reset,
    input  logic                prepare_init,
    input  logic                capture,
    input  system_pkg::mem_wb_t data_in,
    output system_pkg::mem_wb_t data_out,
    output logic                valid_next
);
  system_pkg::mem_wb_t next_data;

  always_comb begin
    next_data = data_out;
    if (reset || prepare_init) begin
      // Invalida la entrada sin exigir el borrado de datos y controles inactivos.
      next_data.valid = 1'b0;
    end else if (capture) begin
      // Captura los seis campos de MEM, incluido el valor ya seleccionado para WB.
      next_data = data_in;
    end
  end

  always_ff @(posedge clk) begin
    // Actualiza el estado registrado únicamente en el flanco ascendente.
    data_out <= next_data;
  end

  // Anticipa la validez posterior al flanco sin agregar estado registrado.
  assign valid_next = next_data.valid;
endmodule
