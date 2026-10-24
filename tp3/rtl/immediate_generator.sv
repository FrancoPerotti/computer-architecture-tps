// Reconstruye el inmediato en bytes; la legalidad se comprueba en el decoder.
module immediate_generator (
    input  system_pkg::word_t instruction,
    output system_pkg::word_t immediate
);
  import system_pkg::*;

  opcode_t opcode;
  assign opcode = instruction[6:0];

  always_comb begin
    case (opcode)
      OPCODE_ALU_IMM, OPCODE_LOAD, OPCODE_JALR: begin
        immediate = {{20{instruction[31]}}, instruction[31:20]};
      end
      OPCODE_STORE: begin
        immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
      end
      OPCODE_BRANCH: begin
        immediate = {
          {19{instruction[31]}},
          instruction[31],
          instruction[7],
          instruction[30:25],
          instruction[11:8],
          1'b0
        };
      end
      OPCODE_LUI: immediate = {instruction[31:12], 12'b0};
      OPCODE_JAL: begin
        immediate = {
          {11{instruction[31]}},
          instruction[31],
          instruction[19:12],
          instruction[20],
          instruction[30:21],
          1'b0
        };
      end
      default: immediate = 32'b0;
    endcase
  end
endmodule
