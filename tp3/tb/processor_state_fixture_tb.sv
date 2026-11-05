`timescale 1ns / 1ps

// Fixtures publicados de PC inválido y contador próximo al wrap sobre el CPU real.
module processor_state_fixture_tb;
  import system_pkg::*;
  string         scenario;
  string         text_value;
  logic   [63:0] initial_count;
  logic   [63:0] controls;
  logic   [63:0] reference_controls;
  if_id_t        reference_ifid;
  id_ex_t        reference_idex;

  // Los fixtures modifican solo el estado inicial indicado por el catálogo.
  processor_test_harness h ();

  task automatic check_no_commit;
    if (h.dut.g_valid_capacity.rf_write_fire ||
        h.dut.g_valid_capacity.mem_stage_inst.dmem_store_fire)
      $fatal(1, "State fixture produced an architectural commit");
  endtask

  initial begin
    h.data.load();
    scenario = h.data.get_string("/inputs/cpu_state_fixture");
    if (scenario == "fetch") begin
      h.reset_cpu();
      h.load_program("/inputs/cpu_state_words");
      h.prepare_ready();
      h.dut.g_valid_capacity.if_stage_inst.gen_valid_capacity.pc =
          32'(h.data.get_integer("/inputs/PC"));
      h.step_cycle();
      if (h.observed_ifid.valid || !h.observed_ifid.fetch_fault_valid ||
          h.observed_ifid.fetch_fault_cause !== 3'(h.data.get_integer(
              "/expected/cause"
          )) || h.observed_ifid.pc !== 32'(h.data.get_integer(
              "/expected/fault_pc"
          )) || h.observed_ifid.instruction !== 0)
        $fatal(1, "Fetch candidate was truncated or classified as illegal");
      h.step_request = 1'b1;
      #1;
      check_no_commit();
      if (!h.dut.g_valid_capacity.act_id_fault || h.dut.g_valid_capacity.act_ex_fault)
        $fatal(1, "Fetch candidate was not confirmed from ID");
      h.tick();
      h.step_request = 1'b0;
      if (h.global_state_code != STATE_CODE_FAULT || h.debug_cycle_count != 2 ||
          h.debug_fault_cause !== 3'(h.data.get_integer(
              "/expected/cause"
          )) || h.debug_fault_pc !== 32'(h.data.get_integer(
              "/expected/fault_pc"
          )))
        $fatal(1, "Incorrect precise fetch metadata");
    end else if (scenario == "counter") begin
      for (integer comparison = 0; comparison < 2; comparison = comparison + 1) begin
        h.reset_cpu();
        h.load_program("/inputs/cpu_state_words");
        h.prepare_ready();
        h.run_request = 1'b1;
        h.tick();
        h.run_request = 1'b0;
        // Alcanza RUNNING normalmente antes de instalar el contador y PC del fixture.
        h.dut.g_valid_capacity.if_stage_inst.gen_valid_capacity.pc =
            32'(h.data.get_integer("/inputs/local_fixture/PC"));
        if (comparison == 0) initial_count = 64'(h.data.get_integer("/inputs/comparison_count"));
        else begin
          text_value = h.data.get_string("/inputs/count");
          if ($sscanf(text_value, "0x%h", initial_count) != 1) $fatal(1, "Invalid counter fixture");
        end
        h.dut.g_valid_capacity.execution_control_inst.cycle_count = initial_count;
        #1;
        check_no_commit();
        if (!h.cpu_cycle_fire || h.command_accepted || h.dut.g_valid_capacity.actions !== 8'd4 ||
            h.dut.g_valid_capacity.execution_control_inst.g_valid_capacity.fault_capture_fire)
          $fatal(1, "Counter changed current-state authorization");
        controls = {
          h.global_state_code,
          h.dut.g_valid_capacity.actions,
          h.cpu_cycle_fire,
          h.command_accepted,
          h.dut.g_valid_capacity.drain_mode,
          h.image_valid,
          h.dut.g_valid_capacity.ifid_next_valid,
          h.dut.g_valid_capacity.idex_next_valid,
          h.dut.g_valid_capacity.exmem_next_valid,
          h.dut.g_valid_capacity.memwb_next_valid,
          h.dut.g_valid_capacity.rf_write_fire,
          h.dut.g_valid_capacity.mem_stage_inst.dmem_store_fire
        };
        if (comparison == 0) reference_controls = controls;
        else if (controls !== reference_controls) $fatal(1, "Wrap changed control outputs");
        h.tick();
        if (h.debug_pc !== 32'h44 || h.global_state_code != STATE_CODE_RUNNING ||
            h.debug_cycle_count !== (comparison == 0 ? 64'(h.data.get_integer(
                "/expected/comparison_count_next"
            )) : 64'(h.data.get_integer(
                "/expected/count_next"
            ))))
          $fatal(1, "Counter did not wrap independently of datapath");
        if (comparison == 0) begin
          reference_ifid = h.observed_ifid;
          reference_idex = h.observed_idex;
        end else if (h.observed_ifid !== reference_ifid || h.observed_idex !== reference_idex)
          $fatal(1, "Wrap changed active latch payloads");
      end
      h.reset_cpu();
    end else $fatal(1, "Unknown CPU state fixture");
    $display("PASS %s", h.data.case_id);
    $finish;
  end
endmodule
