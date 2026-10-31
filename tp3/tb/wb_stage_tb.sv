`timescale 1ns / 1ps

// Verifica el gating de writeback y los comparadores de bypass WB hacia ID.
module wb_stage_tb;
  import system_pkg::*;

  tp3_case_data data ();
  mem_wb_t         memwb;
  logic            cpu_cycle_fire;
  register_index_t ifid_rs1;
  register_index_t ifid_rs2;
  register_index_t rf_write_register;
  word_t           rf_write_data;
  logic            rf_write_fire;
  logic            bypass_rs1;
  logic            bypass_rs2;

  wb_stage dut (
      .memwb            (memwb),
      .cpu_cycle_fire   (cpu_cycle_fire),
      .ifid_rs1         (ifid_rs1),
      .ifid_rs2         (ifid_rs2),
      .rf_write_register(rf_write_register),
      .rf_write_data    (rf_write_data),
      .rf_write_fire    (rf_write_fire),
      .bypass_rs1       (bypass_rs1),
      .bypass_rs2       (bypass_rs2)
  );

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  function automatic logic get_control(input string path);
    if (data.get_type(path) == "boolean") return data.get_boolean(path);
    return data.get_integer(path) != 0;
  endfunction

  function automatic word_t get_word(input string path);
    word_t value;
    if (data.get_type(path) == "string") begin
      if ($sscanf(data.get_string(path), "0x%h", value) != 1) begin
        $fatal(1, "invalid word at %s", path);
      end
      return value;
    end
    return word_t'(data.get_integer(path));
  endfunction

  task automatic load_pipeline_bypass_case;
    string disabled_guard;
    memwb           = '0;
    memwb.valid     = 1'b1;
    memwb.reg_write = 1'b1;
    memwb.rd        = register_index_t'(data.get_integer("/inputs/id_steps/0/rf_write_addr"));
    memwb.wb_value  = get_word("/inputs/id_steps/0/rf_write_data");
    ifid_rs1        = register_index_t'(data.get_integer("/expected/id_steps/0/idex_input/rs1"));
    ifid_rs2        = register_index_t'(data.get_integer("/expected/id_steps/0/idex_input/rs2"));
    cpu_cycle_fire  = 1'b1;
    disabled_guard  = data.get_string("/inputs/disabled_guard");
    if (disabled_guard == "valid0") memwb.valid = 1'b0;
    else if (disabled_guard == "reg_write0") memwb.reg_write = 1'b0;
    else if (disabled_guard == "cpu_cycle_fire0") cpu_cycle_fire = 1'b0;
    #1;
    if (rf_write_fire !== get_control(
            "/inputs/id_steps/0/rf_write_fire"
        ) || bypass_rs1 !== get_control(
            "/inputs/id_steps/0/bypass_rs1"
        ) || bypass_rs2 !== get_control(
            "/inputs/id_steps/0/bypass_rs2"
        )) begin
      fail("writeback fire or bypass selectors differ from the canonical ID fixture");
    end
  endtask

  task automatic load_boundary_case;
    memwb.valid       = get_control("/inputs/boundary/initial/valid");
    memwb.pc          = get_word("/inputs/boundary/initial/pc");
    memwb.instruction = get_word("/inputs/boundary/initial/instruction");
    memwb.rd          = register_index_t'(data.get_integer("/inputs/boundary/initial/rd"));
    memwb.reg_write   = get_control("/inputs/boundary/initial/reg_write");
    memwb.wb_value    = get_word("/inputs/boundary/initial/wb_value");
    cpu_cycle_fire    = get_control("/inputs/boundary/cpu_cycle_fire");
    ifid_rs1          = memwb.rd;
    ifid_rs2          = memwb.rd;
    #1;
    if (rf_write_fire !== get_control("/expected/write_fire")) begin
      fail("writeback eligibility differs from the MEM/WB boundary fixture");
    end
  endtask

  initial begin
    data.load();
    memwb          = '0;
    cpu_cycle_fire = 1'b0;
    ifid_rs1       = '0;
    ifid_rs2       = '0;
    if (data.has_path("/inputs/id_steps/0/rf_write_addr")) begin
      load_pipeline_bypass_case();
    end else begin
      load_boundary_case();
    end
    if (rf_write_register !== memwb.rd || rf_write_data !== memwb.wb_value) begin
      fail("writeback address or data differs from MEM/WB");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
