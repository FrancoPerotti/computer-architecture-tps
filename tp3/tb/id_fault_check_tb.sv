`timescale 1ns / 1ps

// Aplica entradas locales de IF/ID y Decoder sin confirmar ni arbitrar faults.
module id_fault_check_tb;
  import system_pkg::*;

  tp3_case_data data ();
  logic         ifid_valid;
  word_t        ifid_pc;
  logic         ifid_fetch_fault_valid;
  fault_cause_t ifid_fetch_fault_cause;
  logic         decode_legal;
  logic         id_fault_candidate;
  fault_cause_t id_fault_cause;
  word_t        id_fault_pc;

  id_fault_check dut (
      .ifid_valid            (ifid_valid),
      .ifid_pc               (ifid_pc),
      .ifid_fetch_fault_valid(ifid_fetch_fault_valid),
      .ifid_fetch_fault_cause(ifid_fetch_fault_cause),
      .decode_legal          (decode_legal),
      .id_fault_candidate    (id_fault_candidate),
      .id_fault_cause        (id_fault_cause),
      .id_fault_pc           (id_fault_pc)
  );

  // Valida el rango antes de reducir cada entero del catálogo al ancho del puerto.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  // Las expectativas vienen del catálogo y la comparación también rechaza X/Z.
  task automatic check_value(input string name, input logic [63:0] observed,
                             input longint unsigned expected_value);
    assert (observed === expected_value)
    else begin
      $display("FAIL %s %s: expected %0d, observed %0d", data.case_id, name, expected_value,
               observed);
      $fatal(1, "ID fault output differs from manifest");
    end
  endtask

  initial begin
    data.load();
    ifid_valid             = 1'(get_unsigned("/inputs/ifid_valid", 1));
    ifid_pc                = word_t'(get_unsigned("/inputs/ifid_pc", 32'hffffffff));
    ifid_fetch_fault_valid = 1'(get_unsigned("/inputs/ifid_fetch_fault_valid", 1));
    ifid_fetch_fault_cause = fault_cause_t'(get_unsigned("/inputs/ifid_fetch_fault_cause", 7));
    decode_legal           = 1'(get_unsigned("/inputs/decode_legal", 1));
    #1;
    check_value("id_fault_candidate", id_fault_candidate, data.get_boolean(
                "/expected/id_fault_candidate"));
    check_value("id_fault_pc", id_fault_pc, get_unsigned("/expected/id_fault_pc", 32'hffffffff));

    // null indica que el contrato no exige consumir la causa de una entrada inactiva.
    if (!data.is_null("/expected/id_fault_cause")) begin
      check_value("id_fault_cause", id_fault_cause, get_unsigned("/expected/id_fault_cause", 7));
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
