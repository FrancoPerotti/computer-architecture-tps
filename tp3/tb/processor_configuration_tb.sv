`timescale 1ns / 1ps

// Comprueba parámetros y anchos de los hijos del CPU real.
module processor_configuration_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd1024,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd2048
);
  tp3_case_data data ();
  processor_top #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES),
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk              ('0),
      .reset            ('1),
      .load_request     ('0),
      .run_request      ('0),
      .step_request     ('0),
      .load_byte_valid  ('0),
      .load_last_byte   ('0),
      .load_abort       ('0),
      .debug_read_select('0),
      .load_size_bytes  ('0),
      .load_byte_data   ('0),
      .load_byte_offset ('0),
      .debug_rf_addr    ('0),
      .debug_dmem_addr  ('0)
  );

  initial begin
    data.load();
    #1;
    if (dut.g_valid_capacity.if_stage_inst.IMEM_CAPACITY_BYTES !== data.get_integer(
            "/inputs/IMEM_C"
        ) || dut.g_valid_capacity.loader_inst.IMEM_CAPACITY_BYTES !== data.get_integer(
            "/inputs/IMEM_C"
        ) || dut.g_valid_capacity.execution_control_inst.IMEM_CAPACITY_BYTES !== data.get_integer(
            "/inputs/IMEM_C"
        ))
      $fatal(1, "IMEM capacity not propagated");
    if (dut.g_valid_capacity.ex_stage_inst.DMEM_CAPACITY_BYTES !== data.get_integer(
            "/inputs/DMEM_C"
        ) || dut.g_valid_capacity.mem_stage_inst.DMEM_CAPACITY_BYTES !== data.get_integer(
            "/inputs/DMEM_C"
        ) || dut.g_valid_capacity.session_preparation_inst.DMEM_CAPACITY_BYTES !== data.get_integer(
            "/inputs/DMEM_C"
        ))
      $fatal(1, "DMEM capacity not propagated");
    if ($bits(
            dut.load_size_bytes
        ) != data.get_integer(
            "/expected/processor_widths/image_size"
        ) || $bits(
            dut.load_byte_offset
        ) != data.get_integer(
            "/expected/processor_widths/imem_byte"
        ) || $bits(
            dut.g_valid_capacity.imem_write_index
        ) != data.get_integer(
            "/expected/processor_widths/imem_word"
        ) || $bits(
            dut.debug_dmem_addr
        ) != data.get_integer(
            "/expected/processor_widths/dmem_byte"
        ) || $bits(
            dut.g_valid_capacity.session_preparation_inst.g_valid_capacity.prepare_index
        ) != data.get_integer(
            "/expected/processor_widths/prepare_index"
        ))
      $fatal(1, "Incorrect processor interface widths");
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule

// Exige rechazo del top antes de elaborar los recursos de capacidades ilegales.
module processor_configuration_invalid_tb #(
    parameter system_pkg::memory_capacity_t CAPACITY_BYTES = 64'd0
);
  string case_id;

  processor_top #(
      .IMEM_CAPACITY_BYTES(CAPACITY_BYTES),
      .DMEM_CAPACITY_BYTES(CAPACITY_BYTES)
  ) dut (
      .clk              ('0),
      .reset            ('1),
      .load_request     ('0),
      .run_request      ('0),
      .step_request     ('0),
      .load_byte_valid  ('0),
      .load_last_byte   ('0),
      .load_abort       ('0),
      .debug_read_select('0),
      .load_size_bytes  ('0),
      .load_byte_data   ('0),
      .load_byte_offset ('0),
      .debug_rf_addr    ('0),
      .debug_dmem_addr  ('0)
  );

  initial begin
    #1;
    if ($value$plusargs("CASE=%s", case_id)) $display("FAIL %s Invalid capacity accepted", case_id);
    $fatal(1, "Invalid processor capacity accepted");
  end

  final begin
    if (!system_pkg::memory_capacity_valid(CAPACITY_BYTES) && $value$plusargs("CASE=%s", case_id))
      $display("REJECT %s %s", case_id, system_pkg::CONFIG_INVALID_CAPACITY);
  end
endmodule
