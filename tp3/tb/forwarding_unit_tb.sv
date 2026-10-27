`timescale 1ns / 1ps

// Comprueba selectores de forwarding a partir de productores y un payload ID/EX.
module forwarding_unit_tb;
  import system_pkg::*;

  tp3_case_data data ();
  logic            idex_valid;
  word_t           idex_instruction;
  register_index_t idex_rs1;
  register_index_t idex_rs2;
  logic            exmem_valid;
  register_index_t exmem_rd;
  logic            exmem_reg_write;
  mem_op_t         exmem_mem_op;
  logic            memwb_valid;
  register_index_t memwb_rd;
  logic            memwb_reg_write;
  forward_sel_t    forward_a_sel;
  forward_sel_t    forward_b_sel;

  forwarding_unit dut (
      .idex_valid      (idex_valid),
      .idex_instruction(idex_instruction),
      .idex_rs1        (idex_rs1),
      .idex_rs2        (idex_rs2),
      .exmem_valid     (exmem_valid),
      .exmem_rd        (exmem_rd),
      .exmem_reg_write (exmem_reg_write),
      .exmem_mem_op    (exmem_mem_op),
      .memwb_valid     (memwb_valid),
      .memwb_rd        (memwb_rd),
      .memwb_reg_write (memwb_reg_write),
      .forward_a_sel   (forward_a_sel),
      .forward_b_sel   (forward_b_sel)
  );

  assign idex_rs1 = idex_instruction[19:15];
  assign idex_rs2 = idex_instruction[24:20];

  // Rechaza valores que se truncarían al cargar los puertos de la unidad.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  // La igualdad estricta hace fallar también selectores desconocidos o reservados.
  task automatic check_selector(input string name, input forward_sel_t observed);
    forward_sel_t expected_value;
    expected_value = forward_sel_t'(get_unsigned({"/expected/", name}, 2));
    assert (observed === expected_value)
    else begin
      $display("FAIL %s %s: expected %02b, observed %02b", data.case_id, name, expected_value,
               observed);
      $fatal(1, "forwarding selector differs from manifest");
    end
  endtask

  initial begin
    data.load();
    if ($sscanf(data.get_string("/inputs/word"), "0x%h", idex_instruction) != 1) begin
      $fatal(1, "invalid instruction word in manifest");
    end
    idex_valid      = 1'(get_unsigned("/inputs/idex_valid", 1));
    exmem_valid     = 1'(get_unsigned("/inputs/exmem_valid", 1));
    exmem_rd        = register_index_t'(get_unsigned("/inputs/exmem_rd", 31));
    exmem_reg_write = 1'(get_unsigned("/inputs/exmem_reg_write", 1));
    exmem_mem_op    = mem_op_t'(get_unsigned("/inputs/exmem_mem_op", 15));
    memwb_valid     = 1'(get_unsigned("/inputs/memwb_valid", 1));
    memwb_rd        = register_index_t'(get_unsigned("/inputs/memwb_rd", 31));
    memwb_reg_write = 1'(get_unsigned("/inputs/memwb_reg_write", 1));
    #1;
    check_selector("forward_a_sel", forward_a_sel);
    check_selector("forward_b_sel", forward_b_sel);
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
