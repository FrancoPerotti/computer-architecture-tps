`timescale 1ns / 1ps

// Ownership por fases legales y rechazos de colisiones artificiales, con el CPU real.
module processor_ownership_tb;
  import system_pkg::*;
  logic          expecting_rejection = 1'b0;
  string         scenario;
  word_t         instruction;
  logic  [503:0] saved_pipeline;
  word_t         saved_pc;
  logic  [ 63:0] saved_count;

  // La frontera compartida instancia las cinco etapas y los servicios reales de sesión.
  processor_test_harness h ();

  initial begin
    h.data.load();
    h.reset_cpu();
    if (h.data.has_path("/inputs/phase")) scenario = h.data.get_string("/inputs/phase");
    else scenario = h.data.get_string("/inputs/conflict");
    if (scenario == "IMEM-fetch-loader") begin
      expecting_rejection = 1'b1;
      // Solicitudes incompatibles locales: no se presenta como una sesión alcanzable.
      force h.dut.g_valid_capacity.imem_write_enable = 1'b1;
      force h.dut.g_valid_capacity.act_normal = 1'b1;
      h.tick();
      expecting_rejection = 1'b0;
      $display("FAIL %s IMEM conflict was accepted", h.data.case_id);
      $fatal(1, "Expected IMEM ownership rejection");
    end else if (scenario == "DMEM-CPU-debug") begin
      expecting_rejection = 1'b1;
      force h.dut.cpu_cycle_fire = 1'b1;
      h.debug_read_select = 1'b1;
      h.tick();
      expecting_rejection = 1'b0;
      $display("FAIL %s DMEM conflict was accepted", h.data.case_id);
      $fatal(1, "Expected DMEM ownership rejection");
    end else if (scenario == "idle-no-agent") begin
      repeat (50) begin
        if (h.cpu_cycle_fire || h.dut.g_valid_capacity.actions != 0 ||
            h.dut.g_valid_capacity.imem_write_enable || h.prepare_active ||
            h.dut.g_valid_capacity.mem_stage_inst.dmem_store_fire)
          $fatal(1, "Idle authorized a memory agent");
        h.tick();
      end
    end else if (scenario == "LOADING") begin
      h.begin_load(12);
      instruction = 32'(h.data.get_integer("/inputs/cpu_ownership_words/0"));
      for (integer offset = 0; offset < 4; offset = offset + 1) begin
        if (h.cpu_cycle_fire || h.dut.g_valid_capacity.actions != 0 || h.debug_read_select ||
            h.dut.g_valid_capacity.prepare_dmem_clear ||
            h.dut.g_valid_capacity.mem_stage_inst.dmem_store_fire)
          $fatal(1, "LOAD overlaps CPU, preparation or Debug");
        h.send_byte(offset, 8'(instruction >> (8 * offset)), 1'b0);
      end
      h.load_abort = 1'b1;
      #1;
      if (!h.dut.g_valid_capacity.load_fail || h.dut.g_valid_capacity.imem_write_enable)
        $fatal(1, "Abort did not suppress Loader");
      h.tick();
      h.load_abort = 1'b0;
      if (h.image_valid || h.global_state_code != STATE_CODE_NO_IMAGE)
        $fatal(1, "Abort restored an image");
    end else begin
      h.load_program("/inputs/cpu_ownership_words");
      h.prepare_ready();
      for (integer address = 0; address < 2048; address = address + 1)
      if (h.memory_used(address) !== 1'b0) $fatal(1, "Preparation omitted a valid mark");
      if (scenario == "RUNNING") begin
        h.run_request = 1'b1;
        h.tick();
        h.run_request = 1'b0;
        repeat (3) h.tick();
        #1;
        if (!h.cpu_cycle_fire || !h.dut.g_valid_capacity.mem_stage_inst.dmem_store_fire ||
            !(h.dut.g_valid_capacity.act_normal || h.dut.g_valid_capacity.act_redirect) ||
            h.dut.g_valid_capacity.imem_write_enable || h.dut.g_valid_capacity.prepare_dmem_clear ||
            h.debug_read_select)
          $fatal(1, "IF/MEM coexistence or ownership violated");
        h.tick();
        h.reset_cpu();
      end else if (scenario == "STEP-cycle" || scenario == "DEBUG-exclusive") begin
        repeat (5) h.step_cycle();
        h.debug_read_select = 1'b1;
        h.debug_dmem_addr   = '0;
        #1;
        if (!h.debug_dmem_used || h.debug_dmem_data !== 8'd1)
          $fatal(1, "STEP store not visible to Debug");
        saved_pipeline = {h.observed_ifid, h.observed_idex, h.observed_exmem, h.observed_memwb};
        saved_pc       = h.debug_pc;
        saved_count    = h.debug_cycle_count;
        repeat (50) begin
          if (h.cpu_cycle_fire || h.dut.g_valid_capacity.actions != 0 || h.dut.g_valid_capacity
              .mem_stage_inst.dmem_store_fire || h.dut.g_valid_capacity.prepare_dmem_clear)
            $fatal(1, "Debug overlaps another memory agent");
          h.tick();
          if ({h.observed_ifid, h.observed_idex, h.observed_exmem, h.observed_memwb} !==
              saved_pipeline || h.debug_pc !== saved_pc || h.debug_cycle_count !== saved_count)
            $fatal(1, "Debug changed retained CPU state");
        end
      end else if (scenario != "PREPARING_READY") $fatal(1, "Unknown ownership scenario");
    end
    $display("PASS %s", h.data.case_id);
    $finish;
  end
  final begin
    if (expecting_rejection)
      $display(
          "REJECT %s %s", h.data.case_id, h.data.get_string("/expected/cpu_ownership_diagnostic")
      );
  end
endmodule
