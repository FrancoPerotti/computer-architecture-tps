`timescale 1ns / 1ps

// Comprueba la ALU de 32 bits con operandos y expectativas externas al DUT.
module alu_tb;
  import system_pkg::*;

  tp3_case_data data ();
  word_t   a;
  word_t   b;
  alu_op_t alu_op;
  word_t   alu_result;
  logic    zero;

  alu dut (
      .a         (a),
      .b         (b),
      .alu_op    (alu_op),
      .alu_result(alu_result),
      .zero      (zero)
  );

  // Rechaza valores que se truncarían al cargar el código de operación.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  // Convierte palabras hexadecimales conservando exactamente sus 32 bits.
  function automatic word_t get_word(input string path);
    word_t value;
    if ($sscanf(data.get_string(path), "0x%h", value) != 1) begin
      $fatal(1, "invalid word in manifest at %s", path);
    end
    return value;
  endfunction

  initial begin
    data.load();
    a      = get_word("/inputs/alu_a");
    b      = get_word("/inputs/alu_b");
    alu_op = alu_op_t'(get_unsigned("/inputs/alu_op", 63));
    #1;
    assert (alu_result === get_word("/expected/alu_result"))
    else begin
      $display("FAIL %s alu_result: expected %08h, observed %08h", data.case_id, get_word(
               "/expected/alu_result"), alu_result);
      $fatal(1, "ALU result differs from manifest");
    end
    assert (zero === 1'(get_unsigned("/expected/zero", 1)))
    else begin
      $display("FAIL %s zero: expected %0d, observed %0d", data.case_id, get_unsigned(
               "/expected/zero", 1), zero);
      $fatal(1, "ALU zero flag differs from manifest");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
