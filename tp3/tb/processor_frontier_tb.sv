`timescale 1ns / 1ps

// Fronteras artificiales locales: prueba commits anteriores y el mux WB real por separado.
module processor_frontier_tb;
  import system_pkg::*;
  string kind;
  word_t fixture_load_value;
  processor_test_harness h ();

  function automatic if_id_t read_ifid;
    if_id_t value;
    begin
      value.valid = 1'(h.data.get_integer("/inputs/cpu_frontier/ifid/valid"));
      value.pc = 32'(h.data.get_integer("/inputs/cpu_frontier/ifid/pc"));
      value.instruction = 32'(h.data.get_integer("/inputs/cpu_frontier/ifid/instruction"));
      value.fetch_fault_valid =
          1'(h.data.get_integer("/inputs/cpu_frontier/ifid/fetch_fault_valid"));
      value.fetch_fault_cause =
          3'(h.data.get_integer("/inputs/cpu_frontier/ifid/fetch_fault_cause"));
      read_ifid = value;
    end
  endfunction

  function automatic id_ex_t read_idex;
    id_ex_t value;
    begin
      value.valid       = 1'(h.data.get_integer("/inputs/cpu_frontier/idex/valid"));
      value.pc          = 32'(h.data.get_integer("/inputs/cpu_frontier/idex/pc"));
      value.instruction = 32'(h.data.get_integer("/inputs/cpu_frontier/idex/instruction"));
      value.rs1         = 5'(h.data.get_integer("/inputs/cpu_frontier/idex/rs1"));
      value.rs2         = 5'(h.data.get_integer("/inputs/cpu_frontier/idex/rs2"));
      value.rd          = 5'(h.data.get_integer("/inputs/cpu_frontier/idex/rd"));
      value.rs1_value   = 32'(h.data.get_integer("/inputs/cpu_frontier/idex/rs1_value"));
      value.rs2_value   = 32'(h.data.get_integer("/inputs/cpu_frontier/idex/rs2_value"));
      value.immediate   = 32'(h.data.get_integer("/inputs/cpu_frontier/idex/immediate"));
      value.alu_op      = 6'(h.data.get_integer("/inputs/cpu_frontier/idex/alu_op"));
      value.alu_src     = 1'(h.data.get_integer("/inputs/cpu_frontier/idex/alu_src"));
      value.result_sel  = 2'(h.data.get_integer("/inputs/cpu_frontier/idex/result_sel"));
      value.flow_op     = 3'(h.data.get_integer("/inputs/cpu_frontier/idex/flow_op"));
      value.mem_op      = 4'(h.data.get_integer("/inputs/cpu_frontier/idex/mem_op"));
      value.reg_write   = 1'(h.data.get_integer("/inputs/cpu_frontier/idex/reg_write"));
      read_idex         = value;
    end
  endfunction

  function automatic ex_mem_t read_exmem;
    ex_mem_t value;
    begin
      value.valid       = 1'(h.data.get_integer("/inputs/cpu_frontier/exmem/valid"));
      value.pc          = 32'(h.data.get_integer("/inputs/cpu_frontier/exmem/pc"));
      value.instruction = 32'(h.data.get_integer("/inputs/cpu_frontier/exmem/instruction"));
      value.rd          = 5'(h.data.get_integer("/inputs/cpu_frontier/exmem/rd"));
      value.reg_write   = 1'(h.data.get_integer("/inputs/cpu_frontier/exmem/reg_write"));
      value.mem_op      = 4'(h.data.get_integer("/inputs/cpu_frontier/exmem/mem_op"));
      value.ex_result   = 32'(h.data.get_integer("/inputs/cpu_frontier/exmem/ex_result"));
      value.store_data  = 32'(h.data.get_integer("/inputs/cpu_frontier/exmem/store_data"));
      read_exmem        = value;
    end
  endfunction

  function automatic mem_wb_t read_memwb;
    mem_wb_t value;
    begin
      value.valid       = 1'(h.data.get_integer("/inputs/cpu_frontier/memwb/valid"));
      value.pc          = 32'(h.data.get_integer("/inputs/cpu_frontier/memwb/pc"));
      value.instruction = 32'(h.data.get_integer("/inputs/cpu_frontier/memwb/instruction"));
      value.rd          = 5'(h.data.get_integer("/inputs/cpu_frontier/memwb/rd"));
      value.reg_write   = 1'(h.data.get_integer("/inputs/cpu_frontier/memwb/reg_write"));
      value.wb_value    = 32'(h.data.get_integer("/inputs/cpu_frontier/memwb/wb_value"));
      read_memwb        = value;
    end
  endfunction

  task automatic check_older_commits;
    integer address;
    if (h.dut.g_valid_capacity.id_stage_inst.register_file.registers[8] !== 32'(h.data.get_integer(
            "/expected/cpu_frontier/rf_value"
        )))
      $fatal(1, "Boundary canceled the older RF commit");
    h.debug_read_select = 1'b1;
    for (integer lane = 0; lane < 4; lane = lane + 1) begin
      address           = 32'(h.data.get_integer("/expected/cpu_frontier/store_address")) + lane;
      h.debug_dmem_addr = 11'(address);
      #1;
      if (!h.debug_dmem_used || h.debug_dmem_data !== 8'(h.data.get_integer(
              "/expected/cpu_frontier/store_value"
          ) >> (8 * lane)))
        $fatal(1, "Boundary canceled the older store");
    end
    h.debug_read_select = 1'b0;
    @(negedge h.clk);
  endtask

  initial begin
    h.data.load();
    kind = h.data.get_string("/inputs/cpu_frontier/kind");
    h.reset_cpu();
    h.load_program("/inputs/cpu_frontier/words");
    h.prepare_ready();
    // READY exige latches vacíos; alcanza primero la espera STEP antes de instalar el fixture local.
    h.step_cycle();
    h.dut.g_valid_capacity.if_stage_inst.gen_valid_capacity.pc =
        32'(h.data.get_integer("/inputs/cpu_frontier/pc"));
    h.dut.g_valid_capacity.ifid_register.data_out = read_ifid();
    h.dut.g_valid_capacity.idex_register.data_out = read_idex();
    h.dut.g_valid_capacity.exmem_register.data_out = read_exmem();
    h.dut.g_valid_capacity.memwb_register.data_out = read_memwb();
    if (kind == "mux") begin
      // Aísla exclusivamente el operando de entrada del mux local 4.4; no acredita un load físico.
      fixture_load_value = 32'(h.data.get_integer("/inputs/cpu_frontier/load_value"));
      force h.dut.g_valid_capacity.mem_stage_inst.load_value = fixture_load_value;
      h.step_request = 1'b1;
      #1;
      if (h.dut.g_valid_capacity.memwb_input.wb_value !== 32'(h.data.get_integer(
              "/expected/cpu_frontier/value"
          )) || h.dut.g_valid_capacity.rf_write_fire)
        $fatal(1, "WB mux selected the wrong source or wrote the future value early");
      h.tick();
      h.step_request = 1'b0;
      release h.dut.g_valid_capacity.mem_stage_inst.load_value;
      if (!h.observed_memwb.valid || h.observed_memwb.wb_value !== 32'(h.data.get_integer(
              "/expected/cpu_frontier/value"
          )) || h.dut.g_valid_capacity.id_stage_inst.register_file.registers[2] !== 0)
        $fatal(1, "MEM/WB did not capture the pre-edge mux result");
      h.step_cycle();
      if (h.dut.g_valid_capacity.id_stage_inst.register_file.registers[2] !==
          32'(h.data.get_integer(
              "/expected/cpu_frontier/value"
          )))
        $fatal(1, "WB did not consume the registered value");
    end else begin
      h.step_request = 1'b1;
      #1;
      if (h.dut.g_valid_capacity.actions !== 8'(h.data.get_integer(
              "/expected/cpu_frontier/action"
          )) || h.dut.g_valid_capacity.act_id_fault || !h.dut.g_valid_capacity.rf_write_fire ||
              !h.dut.g_valid_capacity.mem_stage_inst.dmem_store_fire ||
              h.dut.g_valid_capacity.rf_write_addr != h.data.get_integer(
              "/expected/cpu_frontier/rf_register"
          ) || h.dut.g_valid_capacity.rf_write_data !== 32'(h.data.get_integer(
              "/expected/cpu_frontier/rf_value"
          )))
        $fatal(1, "Boundary priority or older effects changed");
      h.tick();
      h.step_request = 1'b0;
      if (h.observed_ifid.valid || h.observed_ifid.fetch_fault_valid || h.observed_idex.valid ||
          h.observed_exmem.valid !== 1'(h.data.get_integer(
              "/expected/cpu_frontier/exmem_valid"
          )) || h.debug_pc !== 32'(h.data.get_integer(
              "/expected/cpu_frontier/pc"
          )) || h.global_state_code !== 8'(h.data.get_integer(
              "/expected/cpu_frontier/state"
          )))
        $fatal(
            1,
            "Boundary state mismatch: ifid=%b fetch=%b idex=%b exmem=%b pc=%h state=%d",
            h.observed_ifid.valid,
            h.observed_ifid.fetch_fault_valid,
            h.observed_idex.valid,
            h.observed_exmem.valid,
            h.debug_pc,
            h.global_state_code
        );
      check_older_commits();
      repeat (50) begin
        #1;
        if (h.cpu_cycle_fire || h.dut.g_valid_capacity.rf_write_fire ||
            h.dut.g_valid_capacity.mem_stage_inst.dmem_store_fire || h.debug_cycle_count != 2)
          $fatal(1, "Boundary repeated an older commit during HOLD");
        h.tick();
      end
      check_older_commits();
    end
    $display("PASS %s", h.data.case_id);
    $finish;
  end
endmodule
