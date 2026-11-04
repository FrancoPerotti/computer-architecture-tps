`timescale 1ns / 1ps

// Compara las nueve salidas del decoder con las expectativas externas del caso.
module decoder_tb;
  import system_pkg::*;

  tp3_case_data data ();
  word_t       instruction;
  logic        decode_legal;
  alu_op_t     alu_op;
  alu_src_t    alu_src;
  result_sel_t result_sel;
  flow_op_t    flow_op;
  mem_op_t     mem_op;
  logic        reg_write;
  logic        uses_rs1;
  logic        uses_rs2;

  decoder dut (
      .instruction (instruction),
      .decode_legal(decode_legal),
      .alu_op      (alu_op),
      .alu_src     (alu_src),
      .result_sel  (result_sel),
      .flow_op     (flow_op),
      .mem_op      (mem_op),
      .reg_write   (reg_write),
      .uses_rs1    (uses_rs1),
      .uses_rs2    (uses_rs2)
  );

  // La comparación estricta también detecta controles desconocidos o incompletos.
  task automatic check_control(input string name, input logic [63:0] observed);
    longint signed expected_value;
    expected_value = data.get_integer({"/expected/", name});
    assert (observed === expected_value)
    else begin
      $display("FAIL %s %s: expected %0d, observed %0d", data.case_id, name, expected_value,
               observed);
      $fatal(1, "decoder control differs from manifest");
    end
  endtask

  initial begin
    data.load();
    if ($sscanf(data.get_string("/inputs/word"), "0x%h", instruction) != 1) begin
      $fatal(1, "invalid instruction word in manifest");
    end
    #1;
    check_control("decode_legal", decode_legal);
    check_control("alu_op", alu_op);
    check_control("alu_src", alu_src);
    check_control("result_sel", result_sel);
    check_control("flow_op", flow_op);
    check_control("mem_op", mem_op);
    check_control("reg_write", reg_write);
    check_control("uses_rs1", uses_rs1);
    check_control("uses_rs2", uses_rs2);
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
