// Valida los cuatro bytes del fetch y forma un candidato; IF no confirma faults.
module fetch_fault_check #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0,
    localparam int unsigned IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(
        IMEM_CAPACITY_BYTES
    )
) (
    input  system_pkg::word_t                               pc,
    input  logic                                            image_valid,
    input  logic                     [IMAGE_SIZE_WIDTH-1:0] loaded_image_size_bytes,
    output logic                                            if_fetch_fault_candidate,
    output system_pkg::fault_cause_t                        if_fetch_fault_cause
);
  import system_pkg::*;

  // El centinela cero permite diagnosticar un parámetro omitido sin elegir un perfil.
  generate
    if (!memory_capacity_valid(IMEM_CAPACITY_BYTES)) begin : gen_invalid_capacity
      initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
      assign if_fetch_fault_candidate = 1'b1;
      assign if_fetch_fault_cause     = FAULT_INSTRUCTION_ACCESS_FAULT;
    end else begin : gen_valid_capacity
      // La conversión se hace solo después de validar el dominio de la capacidad.
      localparam logic [32:0] IMEM_LIMIT_BYTES = 33'(IMEM_CAPACITY_BYTES);
      logic [32:0] fetch_end;
      logic        fetch_aligned;
      logic        fetch_range_valid;

      // El bit adicional conserva el acarreo: el extremo no vuelve a cero al sumar.
      assign fetch_end     = {1'b0, pc} + 33'd4;
      assign fetch_aligned = pc[1:0] == 2'b00;

      // La región completa debe pertenecer tanto a IMEM como a la imagen confirmada.
      assign fetch_range_valid = image_valid && (fetch_end <= IMEM_LIMIT_BYTES) &&
          (fetch_end <= 33'(loaded_image_size_bytes));
      assign if_fetch_fault_candidate = !fetch_aligned || !fetch_range_valid;

      // Desalineación tiene prioridad; la causa solo se consume cuando hay candidato.
      assign if_fetch_fault_cause = fetch_aligned ? FAULT_INSTRUCTION_ACCESS_FAULT :
          FAULT_INSTRUCTION_ADDRESS_MISALIGNED;
    end
  endgenerate
endmodule
