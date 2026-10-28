// Conserva la identidad, los operandos base y los controles que ID entrega a EX.
module id_ex_register (
    input  logic               clk,
    input  logic               reset,
    input  logic               prepare_init,
    input  logic               capture,
    input  logic               bubble,
    input  system_pkg::id_ex_t data_in,
    output system_pkg::id_ex_t data_out,
    output logic               valid_next
);
  system_pkg::id_ex_t next_data;

  always_comb begin
    next_data = data_out;
    if (reset || prepare_init || bubble) begin
      // Vacía la etapa sin exigir el borrado de los datos y controles inactivos.
      next_data.valid = 1'b0;
    end else if (capture) begin
      // Captura los quince campos, incluidos los operandos posbypass de ID.
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
