// Detecta dependencia del load inmediato; el control del pipeline aplica la espera.
module load_use_detector (
    input  logic                        ifid_valid,
    input  system_pkg::register_index_t rs1,
    input  system_pkg::register_index_t rs2,
    input  logic                        uses_rs1,
    input  logic                        uses_rs2,
    input  logic                        idex_valid,
    input  system_pkg::register_index_t idex_rd,
    input  system_pkg::mem_op_t         idex_mem_op,
    output logic                        load_use_stall
);
  import system_pkg::*;

  logic idex_is_load;
  logic rs1_dependency;
  logic rs2_dependency;

  // Solo estas cinco operaciones necesitan esperar el dato leído en MEM.
  always_comb begin
    case (idex_mem_op)
      MEM_OP_LB, MEM_OP_LH, MEM_OP_LW, MEM_OP_LBU, MEM_OP_LHU: idex_is_load = 1'b1;
      default: idex_is_load = 1'b0;
    endcase
  end

  // Una coincidencia de índices cuenta únicamente si la instrucción usa esa fuente.
  assign rs1_dependency = uses_rs1 && (rs1 == idex_rd);
  assign rs2_dependency = uses_rs2 && (rs2 == idex_rd);

  // Burbujas, candidatos de fetch y escrituras a x0 no generan dependencia de dato.
  assign load_use_stall = ifid_valid && idex_valid && idex_is_load && (idex_rd != '0) &&
      (rs1_dependency || rs2_dependency);
endmodule
