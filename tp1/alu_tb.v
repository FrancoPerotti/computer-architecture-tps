`timescale 1ns / 1ps

module alu_tb;
  parameter NB_DATA = 8;
  parameter NB_OPCODE = 6;

  localparam [NB_OPCODE-1:0] OP_ADD = 6'b100000;
  localparam [NB_OPCODE-1:0] OP_SUB = 6'b100010;
  localparam [NB_OPCODE-1:0] OP_AND = 6'b100100;
  localparam [NB_OPCODE-1:0] OP_OR = 6'b100101;
  localparam [NB_OPCODE-1:0] OP_XOR = 6'b100110;
  localparam [NB_OPCODE-1:0] OP_SRA = 6'b000011;
  localparam [NB_OPCODE-1:0] OP_SRL = 6'b000010;
  localparam [NB_OPCODE-1:0] OP_NOR = 6'b100111;

  reg [NB_DATA-1:0] data_a;
  reg [NB_DATA-1:0] data_b;
  reg [NB_OPCODE-1:0] opcode;
  wire [NB_DATA-1:0] result;

  reg [NB_DATA-1:0] expected;
  reg [NB_OPCODE-1:0] operations[0:7];
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
      .i_data_a(data_a),
      .i_data_b(data_b),
      .i_data_opcode(opcode)
  );

  // Aplica un estímulo, calcula una referencia independiente y compara
  // automáticamente el resultado obtenido por la ALU.
  task check_result;
    input [NB_DATA-1:0] test_a;
    input [NB_DATA-1:0] test_b;
    input [NB_OPCODE-1:0] test_opcode;
    begin
      data_a = test_a;
      data_b = test_b;
      opcode = test_opcode;

      // Modelo de referencia utilizado por el testbench.
      case (test_opcode)
        OP_ADD:  expected = test_a + test_b;
        OP_SUB:  expected = test_a - test_b;
        OP_AND:  expected = test_a & test_b;
        OP_OR:   expected = test_a | test_b;
        OP_XOR:  expected = test_a ^ test_b;
        OP_SRA:  expected = $signed(test_a) >>> test_b;
        OP_SRL:  expected = test_a >> test_b;
        OP_NOR:  expected = ~(test_a | test_b);
        default: expected = {NB_DATA{1'b0}};
      endcase

      // Se espera la propagación de la lógica antes de comprobar la salida.
      #10;
      tests = tests + 1;
      if (result !== expected) begin
        errors = errors + 1;
        $display("ERROR op=%b A=%h B=%h expected=%h obtained=%h", test_opcode, test_a, test_b,
                 expected, result);
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
    errors = 0;
    tests = 0;
    data_a = 0;
    data_b = 0;
    opcode = 0;

    // Casos límite: overflow, desplazamientos, NOR y opcode inválido.
    check_result({NB_DATA{1'b1}}, {{(NB_DATA - 1) {1'b0}}, 1'b1}, OP_ADD);
    check_result({1'b1, {(NB_DATA - 1) {1'b0}}}, {{(NB_DATA - 1) {1'b0}}, 1'b1}, OP_SRA);
    check_result({1'b1, {(NB_DATA - 1) {1'b0}}}, {{(NB_DATA - 1) {1'b0}}, 1'b1}, OP_SRL);
    check_result({NB_DATA{1'b1}}, {NB_DATA{1'b0}}, OP_NOR);
    check_result({NB_DATA{1'b1}}, {NB_DATA{1'b1}}, {NB_OPCODE{1'b1}});

    // Cien pares aleatorios para cada una de las ocho operaciones válidas.
    for (i = 0; i < 8; i = i + 1)
    for (j = 0; j < 100; j = j + 1) check_result($random(seed), $random(seed), operations[i]);

    if (errors == 0) $display("PASS: %0d tests completed without errors", tests);
    else $display("FAIL: %0d errors in %0d tests", errors, tests);

    $finish;
  end
endmodule
