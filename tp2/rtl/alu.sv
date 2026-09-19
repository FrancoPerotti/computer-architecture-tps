`timescale 1ns / 1ps

// Copia autocontenida del núcleo validado en el TP1.
module alu #(
    parameter integer NB_DATA   = 8,
    parameter integer NB_OPCODE = 6
) (
    output reg  [NB_DATA-1:0] o_result,
    output wire               o_zero,
    output reg                o_carry,
    output reg                o_overflow,

    input wire [  NB_DATA-1:0] i_data_a,
    input wire [  NB_DATA-1:0] i_data_b,
    input wire [NB_OPCODE-1:0] i_data_opcode
);

  // Códigos de operación conservados del trabajo anterior.
  localparam logic [NB_OPCODE-1:0] OP_ADD = 6'b100000;
  localparam logic [NB_OPCODE-1:0] OP_SUB = 6'b100010;
  localparam logic [NB_OPCODE-1:0] OP_AND = 6'b100100;
  localparam logic [NB_OPCODE-1:0] OP_OR  = 6'b100101;
  localparam logic [NB_OPCODE-1:0] OP_XOR = 6'b100110;
  localparam logic [NB_OPCODE-1:0] OP_SRA = 6'b000011;
  localparam logic [NB_OPCODE-1:0] OP_SRL = 6'b000010;
  localparam logic [NB_OPCODE-1:0] OP_NOR = 6'b100111;

  // Lógica puramente combinacional.
  always_comb begin
    o_carry = 1'b0;
    o_overflow = 1'b0;

    case (i_data_opcode)
      OP_ADD: begin
        // El bit adicional conserva el acarreo de la suma sin signo.
        {o_carry, o_result} = {1'b0, i_data_a} + {1'b0, i_data_b};

        // Overflow: operandos del mismo signo y resultado de signo contrario.
        o_overflow = (i_data_a[NB_DATA-1] == i_data_b[NB_DATA-1]) &&
                     (o_result[NB_DATA-1] != i_data_a[NB_DATA-1]);
      end

      OP_SUB: begin
        o_result = i_data_a - i_data_b;

        // Overflow: operandos de signos distintos y resultado de signo diferente al de A.
        o_overflow = (i_data_a[NB_DATA-1] != i_data_b[NB_DATA-1]) &&
                     (o_result[NB_DATA-1] != i_data_a[NB_DATA-1]);
      end

      OP_AND: o_result = i_data_a & i_data_b;

      OP_OR: o_result = i_data_a | i_data_b;

      OP_XOR: o_result = i_data_a ^ i_data_b;

      // $signed permite que SRA replique el bit de signo por la izquierda.
      OP_SRA: o_result = $signed(i_data_a) >>> i_data_b;

      OP_SRL: o_result = i_data_a >> i_data_b;

      OP_NOR: o_result = ~(i_data_a | i_data_b);

      // Define la salida para opcodes inválidos y evita inferir un latch.
      default: o_result = {NB_DATA{1'b0}};
    endcase
  end

  // Se enciende cuando todos los bits del resultado son cero.
  assign o_zero = (o_result == {NB_DATA{1'b0}});
endmodule
