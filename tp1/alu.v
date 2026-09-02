module alu #(
    parameter NB_DATA   = 8,
    parameter NB_OPCODE = 6
) (
    output reg  [  NB_DATA-1:0] o_result,
    input  wire [  NB_DATA-1:0] i_data_a,
    input  wire [  NB_DATA-1:0] i_data_b,
    input  wire [NB_OPCODE-1:0] i_data_opcode
);

  // Códigos de operación
  localparam [NB_OPCODE-1:0] OP_ADD = 6'b100000;
  localparam [NB_OPCODE-1:0] OP_SUB = 6'b100010;
  localparam [NB_OPCODE-1:0] OP_AND = 6'b100100;
  localparam [NB_OPCODE-1:0] OP_OR  = 6'b100101;
  localparam [NB_OPCODE-1:0] OP_XOR = 6'b100110;
  localparam [NB_OPCODE-1:0] OP_SRA = 6'b000011;
  localparam [NB_OPCODE-1:0] OP_SRL = 6'b000010;
  localparam [NB_OPCODE-1:0] OP_NOR = 6'b100111;

  // Lógica puramente combinacional
  always @(*) begin
    case (i_data_opcode)
      OP_ADD:  o_result = i_data_a + i_data_b;
      OP_SUB:  o_result = i_data_a - i_data_b;
      OP_AND:  o_result = i_data_a & i_data_b;
      OP_OR:   o_result = i_data_a | i_data_b;
      OP_XOR:  o_result = i_data_a ^ i_data_b;
      // $signed permite que SRA replique el bit de signo por la izquierda.
      OP_SRA:  o_result = $signed(i_data_a) >>> i_data_b;
      OP_SRL:  o_result = i_data_a >> i_data_b;
      OP_NOR:  o_result = ~(i_data_a | i_data_b);
      // Define la salida para opcodes inválidos y evita inferir un latch.
      default: o_result = {NB_DATA{1'b0}};
    endcase
  end
endmodule
