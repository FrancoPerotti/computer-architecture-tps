`timescale 1ns / 1ps

module alu_tb;
  localparam integer NB_DATA = 8;
  localparam integer NB_OPCODE = 6;
  localparam logic [5:0] OP_ADD = 6'b100000;
  localparam logic [5:0] OP_SUB = 6'b100010;
  localparam logic [5:0] OP_AND = 6'b100100;
  localparam logic [5:0] OP_OR  = 6'b100101;
  localparam logic [5:0] OP_XOR = 6'b100110;
  localparam logic [5:0] OP_SRA = 6'b000011;
  localparam logic [5:0] OP_SRL = 6'b000010;
  localparam logic [5:0] OP_NOR = 6'b100111;

  reg [7:0] data_a = 8'b0;
  reg [7:0] data_b = 8'b0;
  reg [5:0] opcode = 6'b0;
  wire [7:0] result;
  wire zero;
  wire carry;
  wire overflow;

  reg [7:0] expected;
  reg expected_zero;
  reg expected_carry;
  reg expected_overflow;
  reg signed [8:0] signed_a;
  reg signed [8:0] signed_b;
  reg signed [8:0] signed_result;
  reg [5:0] operations[0:7];
  integer seed;
  integer tests = 0;
  integer errors = 0;
  integer operation_index;
  integer sample_index;

  alu dut (
      .o_result     (result),
      .o_zero       (zero),
      .o_carry      (carry),
      .o_overflow   (overflow),
      .i_data_a     (data_a),
      .i_data_b     (data_b),
      .i_data_opcode(opcode)
  );

  task automatic check_result;
    input [7:0] test_a;
    input [7:0] test_b;
    input [5:0] test_opcode;
    begin
      data_a = test_a;
      data_b = test_b;
      opcode = test_opcode;
      expected_carry = 1'b0;
      expected_overflow = 1'b0;
      signed_a = {test_a[7], test_a};
      signed_b = {test_b[7], test_b};
      signed_result = 0;

      case (test_opcode)
        OP_ADD: begin
          expected = test_a + test_b;
          expected_carry = test_a > (8'hff - test_b);
          signed_result = signed_a + signed_b;
          expected_overflow = (signed_result < -128) || (signed_result > 127);
        end
        OP_SUB: begin
          expected = test_a - test_b;
          signed_result = signed_a - signed_b;
          expected_overflow = (signed_result < -128) || (signed_result > 127);
        end
        OP_AND: expected = test_a & test_b;
        OP_OR:  expected = test_a | test_b;
        OP_XOR: expected = test_a ^ test_b;
        OP_SRA: expected = $signed(test_a) >>> test_b;
        OP_SRL: expected = test_a >> test_b;
        OP_NOR: expected = ~(test_a | test_b);
        default: expected = 8'b0;
      endcase

      expected_zero = (expected == 8'b0);
      #1;
      tests = tests + 1;
      if ({result, zero, carry, overflow} !==
          {expected, expected_zero, expected_carry, expected_overflow}) begin
        errors = errors + 1;
        $display("ERROR: A=%h B=%h op=%h result=%h/%h ZCV=%b%b%b/%b%b%b",
                 test_a, test_b, test_opcode, result, expected, zero, carry, overflow,
                 expected_zero, expected_carry, expected_overflow);
      end
    end
  endtask

  initial begin
    operations[0] = OP_ADD;
    operations[1] = OP_SUB;
    operations[2] = OP_AND;
    operations[3] = OP_OR;
    operations[4] = OP_XOR;
    operations[5] = OP_SRA;
    operations[6] = OP_SRL;
    operations[7] = OP_NOR;
    seed = 32'h1a2b3c4d;
    seed = $urandom(seed);

    check_result(8'hff, 8'h01, OP_ADD);
    check_result(8'h7f, 8'h01, OP_ADD);
    check_result(8'h80, 8'h80, OP_ADD);
    check_result(8'h80, 8'h01, OP_SUB);
    check_result(8'h7f, 8'hff, OP_SUB);
    check_result(8'h01, 8'h01, OP_SUB);
    check_result(8'h00, 8'h01, OP_SUB);
    check_result(8'h80, 8'h01, OP_SRA);
    check_result(8'h80, 8'h01, OP_SRL);
    check_result(8'hff, 8'h00, OP_NOR);
    check_result(8'h00, 8'h00, OP_ADD);
    check_result(8'hff, 8'hff, OP_ADD);
    check_result(8'h80, 8'hff, OP_ADD);
    check_result(8'hff, 8'hff, 6'h3f);

    for (operation_index = 0; operation_index < 8; operation_index = operation_index + 1) begin
      for (sample_index = 0; sample_index < 100; sample_index = sample_index + 1) begin
        check_result($urandom(), $urandom(), operations[operation_index]);
      end
    end

    if (tests != 814) $fatal(1, "FAIL: expected 814 ALU checks, obtained %0d", tests);
    if (errors != 0) $fatal(1, "FAIL: %0d ALU errors in %0d tests", errors, tests);
    $display("PASS: %0d ALU checks", tests);
    $finish;
  end
endmodule
