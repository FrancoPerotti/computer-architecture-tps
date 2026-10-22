// Conserva el resultado de EX y el dato de store que MEM necesita por separado.
module ex_mem_register (
    input  logic                clk,
    input  logic                reset,
    input  logic                prepare_init,
    input  logic                capture,
    input  logic                invalidate,
    input  system_pkg::ex_mem_t data_in,
    output system_pkg::ex_mem_t data_out,
    output logic                valid_next
);
  system_pkg::ex_mem_t next_data;

  always_comb begin
    next_data = data_out;
    if (reset || prepare_init || invalidate) begin
      // Invalida la entrada sin exigir el borrado de datos y controles inactivos.
      next_data.valid = 1'b0;
    end else if (capture) begin
      // Captura los ocho campos de EX, con resultado y dato de store separados.
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
