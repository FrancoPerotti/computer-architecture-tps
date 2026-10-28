`timescale 1ns / 1ps

// Prueba el detector con entradas directas o en integración local con Decoder.
module load_use_detector_tb #(
    parameter bit USE_DECODER = 1'b0
);
  import system_pkg::*;

  tp3_case_data data ();
  logic            ifid_valid;
  register_index_t rs1;
  register_index_t rs2;
  logic            uses_rs1;
  logic            uses_rs2;
  logic            idex_valid;
  register_index_t idex_rd;
  mem_op_t         idex_mem_op;
  logic            load_use_stall;
  word_t           instruction;
  logic            decode_legal;
  register_index_t direct_rs1;
  register_index_t direct_rs2;
  logic            direct_uses_rs1;
  logic            direct_uses_rs2;

  load_use_detector dut (
      .ifid_valid    (ifid_valid),
      .rs1           (rs1),
      .rs2           (rs2),
      .uses_rs1      (uses_rs1),
      .uses_rs2      (uses_rs2),
      .idex_valid    (idex_valid),
      .idex_rd       (idex_rd),
      .idex_mem_op   (idex_mem_op),
      .load_use_stall(load_use_stall)
  );

  // El parámetro separa la unidad aislada de las conexiones reales con Decoder.
  generate
    if (USE_DECODER) begin : gen_decoder
      decoder consumer_decoder (
          .instruction (instruction),
          .decode_legal(decode_legal),
          .alu_op      (),
          .alu_src     (),
          .result_sel  (),
          .flow_op     (),
          .mem_op      (),
          .reg_write   (),
          .uses_rs1    (uses_rs1),
          .uses_rs2    (uses_rs2)
      );
      assign rs1 = instruction[19:15];
      assign rs2 = instruction[24:20];
    end else begin : gen_direct
      assign rs1      = direct_rs1;
      assign rs2      = direct_rs2;
      assign uses_rs1 = direct_uses_rs1;
      assign uses_rs2 = direct_uses_rs2;
    end
  endgenerate

  // Rechaza valores que se truncarían al cargar los puertos del detector.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  // Compara con expectativas externas y rechaza también valores desconocidos.
  task automatic check_value(input string name, input logic [63:0] observed,
                             input longint unsigned maximum);
    longint unsigned expected_value;
    expected_value = get_unsigned({"/expected/", name}, maximum);
    assert (observed === expected_value)
    else begin
      $display("FAIL %s %s: expected %0d, observed %0d", data.case_id, name, expected_value,
               observed);
      $fatal(1, "load-use output differs from manifest");
    end
  endtask

  initial begin
    data.load();
    ifid_valid  = 1'(get_unsigned("/inputs/ifid_valid", 1));
    idex_valid  = 1'(get_unsigned("/inputs/idex_valid", 1));
    idex_rd     = register_index_t'(get_unsigned("/inputs/idex_rd", 31));
    idex_mem_op = mem_op_t'(get_unsigned("/inputs/idex_mem_op", 15));
    if (USE_DECODER) begin
      if ($sscanf(data.get_string("/inputs/word"), "0x%h", instruction) != 1) begin
        $fatal(1, "invalid instruction word in manifest");
      end
    end else begin
      direct_rs1      = register_index_t'(get_unsigned("/inputs/rs1", 31));
      direct_rs2      = register_index_t'(get_unsigned("/inputs/rs2", 31));
      direct_uses_rs1 = 1'(get_unsigned("/inputs/uses_rs1", 1));
      direct_uses_rs2 = 1'(get_unsigned("/inputs/uses_rs2", 1));
    end
    #1;
    if (USE_DECODER) begin
      check_value("decode_legal", decode_legal, 1);
      check_value("uses_rs1", uses_rs1, 1);
      check_value("uses_rs2", uses_rs2, 1);
      check_value("rs1", rs1, 31);
      check_value("rs2", rs2, 31);
    end
    check_value("load_use_stall", load_use_stall, 1);
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
