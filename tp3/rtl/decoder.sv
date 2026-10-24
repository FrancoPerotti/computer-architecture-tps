// Reconoce la whitelist y forma los controles combinacionales de la instrucción.
module decoder (
    input  system_pkg::word_t       instruction,
    output logic                    decode_legal,
    output system_pkg::alu_op_t     alu_op,
    output system_pkg::alu_src_t    alu_src,
    output system_pkg::result_sel_t result_sel,
    output system_pkg::flow_op_t    flow_op,
    output system_pkg::mem_op_t     mem_op,
    output logic                    reg_write,
    output logic                    uses_rs1,
    output logic                    uses_rs2
);
  import system_pkg::*;

  // Combinaciones de funct7/funct3 de ALU registro y shifts inmediatos.
  localparam logic [9:0] FUNCT_ADD  = 10'b0000000_000;
  localparam logic [9:0] FUNCT_SUB  = 10'b0100000_000;
  localparam logic [9:0] FUNCT_SLL  = 10'b0000000_001;
  localparam logic [9:0] FUNCT_SLT  = 10'b0000000_010;
  localparam logic [9:0] FUNCT_SLTU = 10'b0000000_011;
  localparam logic [9:0] FUNCT_XOR  = 10'b0000000_100;
  localparam logic [9:0] FUNCT_SRL  = 10'b0000000_101;
  localparam logic [9:0] FUNCT_SRA  = 10'b0100000_101;
  localparam logic [9:0] FUNCT_OR   = 10'b0000000_110;
  localparam logic [9:0] FUNCT_AND  = 10'b0000000_111;

  // Funciones aritméticas inmediatas sin restricciones sobre los bits de inmediato.
  localparam logic [2:0] FUNCT3_ADDI  = 3'b000;
  localparam logic [2:0] FUNCT3_SLTI  = 3'b010;
  localparam logic [2:0] FUNCT3_SLTIU = 3'b011;
  localparam logic [2:0] FUNCT3_XORI  = 3'b100;
  localparam logic [2:0] FUNCT3_ORI   = 3'b110;
  localparam logic [2:0] FUNCT3_ANDI  = 3'b111;

  // Funciones que distinguen tamaño y extensión de los accesos a memoria.
  localparam logic [2:0] FUNCT3_LB  = 3'b000;
  localparam logic [2:0] FUNCT3_LH  = 3'b001;
  localparam logic [2:0] FUNCT3_LW  = 3'b010;
  localparam logic [2:0] FUNCT3_LBU = 3'b100;
  localparam logic [2:0] FUNCT3_LHU = 3'b101;
  localparam logic [2:0] FUNCT3_SB  = 3'b000;
  localparam logic [2:0] FUNCT3_SH  = 3'b001;
  localparam logic [2:0] FUNCT3_SW  = 3'b010;

  // Funciones de flujo admitidas y única palabra legal de halt.
  localparam logic  [2:0] FUNCT3_BEQ       = 3'b000;
  localparam logic  [2:0] FUNCT3_BNE       = 3'b001;
  localparam logic  [2:0] FUNCT3_JALR      = 3'b000;
  localparam word_t       HALT_INSTRUCTION = 32'h0000000b;

  opcode_t       opcode;
  logic    [2:0] funct3;
  logic    [9:0] funct7_funct3;

  assign opcode        = instruction[6:0];
  assign funct3        = instruction[14:12];
  assign funct7_funct3 = {instruction[31:25], instruction[14:12]};

  always_comb begin
    decode_legal = 1'b0;
    alu_op       = ALU_OP_ADD;
    alu_src      = ALU_SRC_RS2;
    result_sel   = RESULT_SEL_ALU;
    flow_op      = FLOW_OP_NONE;
    mem_op       = MEM_OP_NONE;
    reg_write    = 1'b0;
    uses_rs1     = 1'b0;
    uses_rs2     = 1'b0;

    // Se validan todos los campos fijos antes de habilitar el uso de operandos.
    case (opcode)
      OPCODE_ALU_REG: begin
        case (funct7_funct3)
          FUNCT_ADD: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_ADD;
          end
          FUNCT_SUB: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_SUB;
          end
          FUNCT_SLL: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_SLL;
          end
          FUNCT_SLT: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_SLT;
          end
          FUNCT_SLTU: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_SLTU;
          end
          FUNCT_XOR: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_XOR;
          end
          FUNCT_SRL: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_SRL;
          end
          FUNCT_SRA: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_SRA;
          end
          FUNCT_OR: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_OR;
          end
          FUNCT_AND: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_AND;
          end
          default: begin
          end
        endcase
      end
      OPCODE_ALU_IMM: begin
        case (funct3)
          FUNCT3_ADDI: decode_legal = 1'b1;
          FUNCT3_SLTI: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_SLT;
          end
          FUNCT3_SLTIU: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_SLTU;
          end
          FUNCT3_XORI: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_XOR;
          end
          FUNCT3_ORI: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_OR;
          end
          FUNCT3_ANDI: begin
            decode_legal = 1'b1;
            alu_op       = ALU_OP_AND;
          end
          default: begin
            case (funct7_funct3)
              FUNCT_SLL: begin
                decode_legal = 1'b1;
                alu_op       = ALU_OP_SLL;
              end
              FUNCT_SRL: begin
                decode_legal = 1'b1;
                alu_op       = ALU_OP_SRL;
              end
              FUNCT_SRA: begin
                decode_legal = 1'b1;
                alu_op       = ALU_OP_SRA;
              end
              default: begin
              end
            endcase
          end
        endcase
      end
      OPCODE_LOAD: begin
        case (funct3)
          FUNCT3_LB:  mem_op = MEM_OP_LB;
          FUNCT3_LH:  mem_op = MEM_OP_LH;
          FUNCT3_LW:  mem_op = MEM_OP_LW;
          FUNCT3_LBU: mem_op = MEM_OP_LBU;
          FUNCT3_LHU: mem_op = MEM_OP_LHU;
          default: begin
          end
        endcase
        decode_legal = mem_op != MEM_OP_NONE;
      end
      OPCODE_STORE: begin
        case (funct3)
          FUNCT3_SB: mem_op = MEM_OP_SB;
          FUNCT3_SH: mem_op = MEM_OP_SH;
          FUNCT3_SW: mem_op = MEM_OP_SW;
          default: begin
          end
        endcase
        decode_legal = mem_op != MEM_OP_NONE;
      end
      OPCODE_BRANCH: begin
        case (funct3)
          FUNCT3_BEQ: flow_op = FLOW_OP_BEQ;
          FUNCT3_BNE: flow_op = FLOW_OP_BNE;
          default: begin
          end
        endcase
        decode_legal = flow_op != FLOW_OP_NONE;
        if (decode_legal) alu_op = ALU_OP_SUB;
      end
      OPCODE_JAL: begin
        decode_legal = 1'b1;
        flow_op      = FLOW_OP_JAL;
      end
      OPCODE_JALR: begin
        case (funct3)
          FUNCT3_JALR: begin
            decode_legal = 1'b1;
            flow_op      = FLOW_OP_JALR;
          end
          default: begin
          end
        endcase
      end
      OPCODE_LUI: decode_legal = 1'b1;
      OPCODE_CUSTOM_0: begin
        if (instruction == HALT_INSTRUCTION) begin
          decode_legal = 1'b1;
          flow_op      = FLOW_OP_HALT;
        end
      end
      default: begin
      end
    endcase

    // Los controles de clase permanecen neutros para cualquier palabra ilegal.
    if (decode_legal) begin
      case (opcode)
        OPCODE_ALU_REG: begin
          reg_write = 1'b1;
          uses_rs1  = 1'b1;
          uses_rs2  = 1'b1;
        end
        OPCODE_ALU_IMM, OPCODE_LOAD: begin
          alu_src   = ALU_SRC_IMMEDIATE;
          reg_write = 1'b1;
          uses_rs1  = 1'b1;
        end
        OPCODE_STORE: begin
          alu_src  = ALU_SRC_IMMEDIATE;
          uses_rs1 = 1'b1;
          uses_rs2 = 1'b1;
        end
        OPCODE_BRANCH: begin
          uses_rs1 = 1'b1;
          uses_rs2 = 1'b1;
        end
        OPCODE_JAL, OPCODE_JALR: begin
          alu_src    = ALU_SRC_IMMEDIATE;
          result_sel = RESULT_SEL_LINK;
          reg_write  = 1'b1;
          uses_rs1   = flow_op == FLOW_OP_JALR;
        end
        OPCODE_LUI: begin
          alu_src    = ALU_SRC_IMMEDIATE;
          result_sel = RESULT_SEL_IMMEDIATE;
          reg_write  = 1'b1;
        end
        default: begin
        end
      endcase
    end
  end
endmodule
