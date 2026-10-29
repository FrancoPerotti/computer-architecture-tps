// Selecciona el productor pendiente más reciente para cada fuente usada en EX.
module forwarding_unit (
    input  logic                        idex_valid,
    input  system_pkg::word_t           idex_instruction,
    input  system_pkg::register_index_t idex_rs1,
    input  system_pkg::register_index_t idex_rs2,
    input  logic                        exmem_valid,
    input  system_pkg::register_index_t exmem_rd,
    input  logic                        exmem_reg_write,
    input  system_pkg::mem_op_t         exmem_mem_op,
    input  logic                        memwb_valid,
    input  system_pkg::register_index_t memwb_rd,
    input  logic                        memwb_reg_write,
    output system_pkg::forward_sel_t    forward_a_sel,
    output system_pkg::forward_sel_t    forward_b_sel
);
  import system_pkg::*;

  opcode_t opcode;
  logic    idex_uses_rs1;
  logic    idex_uses_rs2;
  logic    exmem_is_load;
  logic    exmem_match_rs1;
  logic    exmem_match_rs2;
  logic    memwb_match_rs1;
  logic    memwb_match_rs2;

  assign opcode = idex_instruction[6:0];

  // Los usos se reconstruyen de la instrucción y no amplían el registro ID/EX.
  always_comb begin
    idex_uses_rs1 = 1'b0;
    idex_uses_rs2 = 1'b0;
    case (opcode)
      OPCODE_ALU_REG: begin
        idex_uses_rs1 = 1'b1;
        idex_uses_rs2 = 1'b1;
      end
      OPCODE_ALU_IMM, OPCODE_LOAD, OPCODE_JALR: idex_uses_rs1 = 1'b1;
      OPCODE_STORE, OPCODE_BRANCH: begin
        idex_uses_rs1 = 1'b1;
        idex_uses_rs2 = 1'b1;
      end
      default: begin
        idex_uses_rs1 = 1'b0;
        idex_uses_rs2 = 1'b0;
      end
    endcase
  end

  // EX/MEM contiene la dirección efectiva de un load, no el dato cargado.
  always_comb begin
    case (exmem_mem_op)
      MEM_OP_LB, MEM_OP_LH, MEM_OP_LW, MEM_OP_LBU, MEM_OP_LHU: exmem_is_load = 1'b1;
      default: exmem_is_load = 1'b0;
    endcase
  end

  assign exmem_match_rs1 = idex_valid && idex_uses_rs1 && exmem_valid && exmem_reg_write &&
      (exmem_rd != '0) && (exmem_rd == idex_rs1);
  assign exmem_match_rs2 = idex_valid && idex_uses_rs2 && exmem_valid && exmem_reg_write &&
      (exmem_rd != '0) && (exmem_rd == idex_rs2);
  assign memwb_match_rs1 = idex_valid && idex_uses_rs1 && memwb_valid && memwb_reg_write &&
      (memwb_rd != '0) && (memwb_rd == idex_rs1);
  assign memwb_match_rs2 = idex_valid && idex_uses_rs2 && memwb_valid && memwb_reg_write &&
      (memwb_rd != '0) && (memwb_rd == idex_rs2);

  // La coincidencia más reciente bloquea una versión vieja incluso si es un load.
  always_comb begin
    forward_a_sel = FORWARD_SEL_ID_EX;
    if (exmem_match_rs1 && !exmem_is_load) begin
      forward_a_sel = FORWARD_SEL_EX_MEM;
    end else if (!exmem_match_rs1 && memwb_match_rs1) begin
      forward_a_sel = FORWARD_SEL_MEM_WB;
    end

    forward_b_sel = FORWARD_SEL_ID_EX;
    if (exmem_match_rs2 && !exmem_is_load) begin
      forward_b_sel = FORWARD_SEL_EX_MEM;
    end else if (!exmem_match_rs2 && memwb_match_rs2) begin
      forward_b_sel = FORWARD_SEL_MEM_WB;
    end
  end
endmodule
