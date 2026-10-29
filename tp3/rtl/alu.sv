// Ejecuta las operaciones aritméticas, lógicas y de comparación usadas por EX.
module alu (
    input  system_pkg::word_t   a,
    input  system_pkg::word_t   b,
    input  system_pkg::alu_op_t alu_op,
    output system_pkg::word_t   alu_result,
    output logic                zero
);
  import system_pkg::*;

  // La asignación a word_t conserva naturalmente los 32 bits bajos de la aritmética.
  always_comb begin
    case (alu_op)
      ALU_OP_ADD:  alu_result = a + b;
      ALU_OP_SUB:  alu_result = a - b;
      ALU_OP_AND:  alu_result = a & b;
      ALU_OP_OR:   alu_result = a | b;
      ALU_OP_XOR:  alu_result = a ^ b;
      ALU_OP_SLL:  alu_result = a << b[4:0];
      ALU_OP_SRL:  alu_result = a >> b[4:0];
      ALU_OP_SRA:  alu_result = $signed(a) >>> b[4:0];
      ALU_OP_SLT:  alu_result = {31'b0, $signed(a) < $signed(b)};
      ALU_OP_SLTU: alu_result = {31'b0, a < b};
      default:     alu_result = '0;
    endcase
  end

  assign zero = alu_result == '0;
endmodule
