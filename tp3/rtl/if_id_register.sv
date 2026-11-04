// Conserva la instrucción o el candidato de fetch que IF entrega a ID.
module if_id_register (
    input  logic               clk,
    input  logic               reset,
    input  logic               prepare_init,
    input  logic               capture,
    input  logic               hold,
    input  logic               invalidate,
    input  system_pkg::if_id_t data_in,
    output system_pkg::if_id_t data_out,
    output logic               valid_next
);
  system_pkg::if_id_t next_data;

  always_comb begin
    next_data = data_out;
    if (reset || prepare_init || invalidate) begin
      // Descarta la instrucción y el candidato de fetch; los demás campos se conservan.
      next_data.valid             = 1'b0;
      next_data.fetch_fault_valid = 1'b0;
    end else if (capture && !hold) begin
      // Captura los cinco campos que IF entrega para el próximo ciclo.
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
