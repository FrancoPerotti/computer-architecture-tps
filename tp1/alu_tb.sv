`timescale 1ns / 1ps

module alu_tb;
  parameter integer NB_DATA = 8;
  parameter integer NB_OPCODE = 6;

  localparam logic [NB_OPCODE-1:0] OP_ADD = 6'b100000;
  localparam logic [NB_OPCODE-1:0] OP_SUB = 6'b100010;
  localparam logic [NB_OPCODE-1:0] OP_AND = 6'b100100;
  localparam logic [NB_OPCODE-1:0] OP_OR = 6'b100101;
  localparam logic [NB_OPCODE-1:0] OP_XOR = 6'b100110;
  localparam logic [NB_OPCODE-1:0] OP_SRA = 6'b000011;
  localparam logic [NB_OPCODE-1:0] OP_SRL = 6'b000010;
  localparam logic [NB_OPCODE-1:0] OP_NOR = 6'b100111;

  reg [NB_DATA-1:0] data_a;
  reg [NB_DATA-1:0] data_b;
  reg [NB_OPCODE-1:0] opcode;

  wire [NB_DATA-1:0] result;
  wire zero;
  wire carry;
  wire overflow;

  reg [NB_DATA-1:0] expected;
  reg expected_zero;
  reg expected_carry;
  reg expected_overflow;

  reg signed [NB_DATA:0] signed_a;
  reg signed [NB_DATA:0] signed_b;
  reg signed [NB_DATA:0] signed_result;

  localparam logic [NB_DATA-1:0] ALL_ONES = {NB_DATA{1'b1}};
  localparam logic [NB_DATA-1:0] ONE = {{(NB_DATA - 1) {1'b0}}, 1'b1};
  localparam logic [NB_DATA-1:0] MIN_VALUE = {1'b1, {(NB_DATA - 1) {1'b0}}};
  localparam logic [NB_DATA-1:0] MAX_VALUE = {1'b0, {(NB_DATA - 1) {1'b1}}};
  localparam logic signed [NB_DATA:0] SIGNED_MIN = {1'b1, MIN_VALUE};
  localparam logic signed [NB_DATA:0] SIGNED_MAX = {1'b0, MAX_VALUE};

  reg [NB_OPCODE-1:0] operations[8];

  integer seed;
  integer errors;
  integer tests;
  integer i;
  integer j;

  // Dispositivo bajo prueba (DUT).
  alu #(
      .NB_DATA  (NB_DATA),
      .NB_OPCODE(NB_OPCODE)
  ) dut (
      .o_result(result),
      .o_zero(zero),
      .o_carry(carry),
      .o_overflow(overflow),

      .i_data_a(data_a),
      .i_data_b(data_b),
      .i_data_opcode(opcode)
  );

  // Aplica los operandos y compara el resultado y sus tres indicadores.
  task automatic check_result;
    input [NB_DATA-1:0] test_a;
    input [NB_DATA-1:0] test_b;
    input [NB_OPCODE-1:0] test_opcode;

    begin
      data_a = test_a;
      data_b = test_b;
      opcode = test_opcode;

      expected_carry = 1'b0;
      expected_overflow = 1'b0;

      signed_a = {test_a[NB_DATA-1], test_a};
      signed_b = {test_b[NB_DATA-1], test_b};
      signed_result = 0;

      // Modelo de referencia utilizado por el testbench.
      case (test_opcode)
        OP_ADD: begin
          expected = test_a + test_b;

          // Hay carry si A supera lo que falta para llegar al máximo sin signo.
          expected_carry = test_a > (ALL_ONES - test_b);

          signed_result = signed_a + signed_b;
          expected_overflow = (signed_result < SIGNED_MIN) || (signed_result > SIGNED_MAX);
        end

        OP_SUB: begin
          expected = test_a - test_b;

          // El resultado ampliado permite comprobar si se excede el rango con signo.
          signed_result = signed_a - signed_b;
          expected_overflow = (signed_result < SIGNED_MIN) || (signed_result > SIGNED_MAX);
        end

        OP_AND: expected = test_a & test_b;

        OP_OR: expected = test_a | test_b;

        OP_XOR: expected = test_a ^ test_b;

        OP_SRA: expected = $signed(test_a) >>> test_b;

        OP_SRL: expected = test_a >> test_b;

        OP_NOR: expected = ~(test_a | test_b);

        default: expected = {NB_DATA{1'b0}};
      endcase

      expected_zero = (expected == {NB_DATA{1'b0}});

      // Se espera la propagación de la lógica antes de comprobar la salida.
      #10;
      tests = tests + 1;

      if ({result, zero, carry, overflow} !==
          {expected, expected_zero, expected_carry, expected_overflow}) begin
        errors = errors + 1;
        $display("ERROR op=%b A=%h B=%h expected=%h obtained=%h", test_opcode, test_a, test_b,
                 expected, result);
        $display("  expected Z/C/V=%b%b%b, obtained=%b%b%b", expected_zero, expected_carry,
                 expected_overflow, zero, carry, overflow);
      end
    end
  endtask

  initial begin
    // Arreglo utilizado para recorrer todas las operaciones válidas.
    operations[0] = OP_ADD;
    operations[1] = OP_SUB;
    operations[2] = OP_AND;
    operations[3] = OP_OR;
    operations[4] = OP_XOR;
    operations[5] = OP_SRA;
    operations[6] = OP_SRL;
    operations[7] = OP_NOR;

    // La semilla fija permite reproducir exactamente los estímulos aleatorios.
    seed = 32'h1a2b3c4d;
    seed = $urandom(seed);

    errors = 0;
    tests = 0;

    data_a = 0;
    data_b = 0;
    opcode = 0;

    // Casos límite: carry, desplazamientos, NOR y opcode inválido.
    check_result({NB_DATA{1'b1}}, {{(NB_DATA - 1) {1'b0}}, 1'b1}, OP_ADD);
    check_result({1'b1, {(NB_DATA - 1) {1'b0}}}, {{(NB_DATA - 1) {1'b0}}, 1'b1}, OP_SRA);
    check_result({1'b1, {(NB_DATA - 1) {1'b0}}}, {{(NB_DATA - 1) {1'b0}}, 1'b1}, OP_SRL);
    check_result({NB_DATA{1'b1}}, {NB_DATA{1'b0}}, OP_NOR);
    check_result({NB_DATA{1'b1}}, {NB_DATA{1'b1}}, {NB_OPCODE{1'b1}});

    // Fronteras del rango con signo, acarreo y resultados cero.
    check_result({NB_DATA{1'b0}}, {NB_DATA{1'b0}}, OP_ADD);
    check_result(MAX_VALUE, ONE, OP_ADD);
    check_result(MIN_VALUE, MIN_VALUE, OP_ADD);
    check_result(MIN_VALUE, ALL_ONES, OP_ADD);
    check_result(MIN_VALUE, ONE, OP_SUB);
    check_result(MAX_VALUE, ALL_ONES, OP_SUB);
    check_result(ONE, ONE, OP_SUB);
    check_result({NB_DATA{1'b0}}, ONE, OP_SUB);
    check_result(ALL_ONES, ALL_ONES, OP_ADD);

    // Cien pares aleatorios para cada una de las ocho operaciones válidas.
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 100; j = j + 1) begin
        check_result($urandom(), $urandom(), operations[i]);
      end
    end

    if (errors != 0) begin
      $fatal(1, "FAIL: %0d errors in %0d tests", errors, tests);
    end

    $display("PASS: %0d tests completed without errors", tests);
    $finish;
  end
endmodule
