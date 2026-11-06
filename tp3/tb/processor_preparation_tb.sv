`timescale 1ns / 1ps

// Inicialización y barrido sobre los recursos reales, incluida la reutilización RUN/STEP.
module processor_preparation_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd2048
);
  import system_pkg::*;
  string  requested_state;
  integer reset_after;

  // Se conserva IMEM de referencia y se propaga la capacidad de cada variante a DMEM.
  processor_test_harness #(.DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)) h ();

  function automatic logic [7:0] physical_byte(input integer address);
    case (address % 4)
      0:
      physical_byte =
          h.dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_0[
          address/4];
      1:
      physical_byte =
          h.dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_1[
          address/4];
      2:
      physical_byte =
          h.dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_2[
          address/4];
      default:
      physical_byte =
          h.dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_3[
          address/4];
    endcase
  endfunction

  // Fixtures de residuos publicados: se preparan estados, nunca respuestas ni resultados de etapas.
  task automatic dirty_resources;
    for (integer address = 0; 64'(address) < DMEM_CAPACITY_BYTES; address = address + 1)
      h.seed_memory_byte(address, 8'(address));
    for (integer index = 1; index < 32; index = index + 1)
      h.dut.g_valid_capacity.id_stage_inst.register_file.registers[index] = 32'ha5a5a5a5;
    h.dut.g_valid_capacity.if_stage_inst.gen_valid_capacity.pc = 32'd64;
    h.dut.g_valid_capacity.execution_control_inst.cycle_count  = 64'd99;
    h.dut.g_valid_capacity.ifid_register.data_out              = '1;
    h.dut.g_valid_capacity.idex_register.data_out              = '1;
    h.dut.g_valid_capacity.exmem_register.data_out             = '1;
    h.dut.g_valid_capacity.memwb_register.data_out             = '1;
  endtask

  task automatic check_clean;
    for (integer index = 1; index < 32; index = index + 1)
      if (h.dut.g_valid_capacity.id_stage_inst.register_file.registers[index] !== 0)
        $fatal(1, "Preparation did not clear RF");
    for (integer address = 0; 64'(address) < DMEM_CAPACITY_BYTES; address = address + 1) begin
      if (h.memory_used(address) !== 1'b0 || physical_byte(address) !== 8'(address))
        $fatal(1, "Preparation changed physical data or retained a used mark");
    end
  endtask

  task automatic finish_halt;
    repeat (3) h.step_cycle();
    if (h.global_state_code != STATE_CODE_FINISHED || h.debug_cycle_count != 3)
      $fatal(1, "HALT setup did not reach terminal");
  endtask

  task automatic start_reuse;
    h.run_request  = (requested_state == "PREPARING_RUN");
    h.step_request = (requested_state == "PREPARING_STEP");
    #1;
    if (!h.command_accepted || h.cpu_cycle_fire || h.dut.g_valid_capacity.load_start)
      $fatal(1, "Reuse command did not start preparation alone");
    h.tick();
    h.run_request  = 1'b0;
    h.step_request = 1'b0;
    if (!h.prepare_active || !h.image_valid)
      $fatal(1, "Reuse invalidated image or skipped preparation");
  endtask

  task automatic clear_prefix(input integer count);
    for (integer address = 0; address < count; address = address + 1) begin
      #1;
      if (!h.prepare_active || h.cpu_cycle_fire || !h.dut.g_valid_capacity.prepare_dmem_clear ||
          h.dut.g_valid_capacity.prepare_dmem_addr !== address ||
          h.dut.g_valid_capacity.prepare_init !== (address == 0))
        $fatal(1, "Incorrect preparation controls");
      h.tick();
      if (h.debug_pc != 0 || h.debug_cycle_count != 0 || h.observed_ifid.valid ||
          h.observed_ifid.fetch_fault_valid || h.observed_idex.valid || h.observed_exmem.valid ||
          h.observed_memwb.valid)
        $fatal(1, "Preparation did not initialize CPU resources");
    end
  endtask

  task automatic finish_reuse;
    clear_prefix(32'(DMEM_CAPACITY_BYTES));
    check_clean();
    #1;
    if (!h.dut.g_valid_capacity.prepare_done || !h.cpu_cycle_fire ||
        h.dut.g_valid_capacity.prepare_dmem_clear || h.command_accepted ||
        h.dut.g_valid_capacity.execution_control_inst.g_valid_capacity.image_publish)
      $fatal(1, "Reuse done did not authorize first fetch alone");
    h.tick();
    if (h.global_state_code !== 8'(h.data.get_integer(
            "/expected/preparation/finish/state"
        )) || h.debug_cycle_count != 1 || h.debug_pc != 4 || !h.observed_ifid.valid ||
            h.observed_ifid.pc != 0)
      $fatal(1, "Reuse first fetch missing or repeated");
    if (requested_state == "PREPARING_RUN") repeat (2) h.tick();
    else repeat (2) h.step_cycle();
    if (h.global_state_code != STATE_CODE_FINISHED || h.debug_cycle_count != 3)
      $fatal(1, "Reuse did not finish HALT");
  endtask

  initial begin
    h.data.load();
    requested_state = h.data.get_string("/inputs/state");
    reset_after = h.data.has_path("/inputs/reset_after_clears") ?
        32'(h.data.get_integer("/inputs/reset_after_clears")) : 0;
    h.reset_cpu();
    h.load_program("/inputs/cpu_preparation_words");
    if (requested_state != "PREPARING_READY") begin
      h.prepare_ready();
      if (h.data.get_string("/inputs/prep_fixture/terminal") == "FAULT") begin
        // El fixture publicado conserva HALT en PC0 y un PC residual fuera de esa imagen.
        h.dut.g_valid_capacity.if_stage_inst.gen_valid_capacity.pc = 32'd64;
        h.run_request                                              = 1'b1;
        h.tick();
        h.run_request = 1'b0;
        h.tick();
        if (h.global_state_code != STATE_CODE_FAULT)
          $fatal(1, "Fixture did not reach fault before reuse");
      end else finish_halt();
      start_reuse();
    end
    dirty_resources();
    if (reset_after != 0) begin
      clear_prefix(reset_after);
      h.reset_cpu();
      // Tras reset, una carga nueva debe reiniciar el barrido desde la dirección cero.
      h.load_program("/inputs/cpu_preparation_words");
      if (requested_state == "PREPARING_READY") begin
        dirty_resources();
        h.prepare_ready();
        check_clean();
      end else begin
        // Restaura legalmente la imagen y vuelve al destino RUN/STEP del caso tras reset.
        h.prepare_ready();
        finish_halt();
        start_reuse();
        dirty_resources();
        finish_reuse();
      end
    end else if (requested_state == "PREPARING_READY") begin
      h.prepare_ready();
      check_clean();
      finish_halt();
    end else begin
      finish_reuse();
    end
    $display("PASS %s", h.data.case_id);
    $finish;
  end
endmodule
