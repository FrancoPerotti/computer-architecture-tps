`timescale 1ns / 1ps

// Conservación de sesión ante tamaños rechazados por la frontera y aborto de LOAD aceptada.
module processor_reprogramming_tb;
  import system_pkg::*;
  integer         requested_size;
  logic   [503:0] saved_pipeline;
  word_t          saved_pc;
  logic   [ 63:0] saved_count;

  // CPU de producción; el driver cumple la validación de tamaño previa a load_request.
  processor_test_harness h ();

  task automatic check_old_session;
    if (!h.image_valid || h.dut.g_valid_capacity.loaded_image_size_bytes != 16 ||
        h.global_state_code != STATE_CODE_FINISHED || h.debug_cycle_count != 7 ||
        h.dut.g_valid_capacity.id_stage_inst.register_file.registers[1] !== 7 ||
        h.dut.g_valid_capacity.id_stage_inst.register_file.registers[2] !== 9)
      $fatal(1, "Old session was not preserved");
  endtask

  initial begin
    h.data.load();
    h.reset_cpu();
    h.load_program("/inputs/cpu_old_image");
    h.prepare_ready();
    h.run_request = 1'b1;
    h.tick();
    h.run_request = 1'b0;
    repeat (6) h.tick();
    check_old_session();
    saved_pipeline = {h.observed_ifid, h.observed_idex, h.observed_exmem, h.observed_memwb};
    saved_pc       = h.debug_pc;
    saved_count    = h.debug_cycle_count;
    if (h.data.has_path("/inputs/requested_N")) begin
      requested_size = 32'(h.data.get_integer("/inputs/requested_N"));
      if (requested_size >= 4 && requested_size <= 1024 && requested_size % 4 == 0)
        $fatal(1, "Invalid-size fixture is legal");
      // El Controller no emite la petición validada: el CPU no agrega una validación duplicada.
      h.load_size_bytes = 11'(requested_size);
      h.load_request    = 1'b0;
      repeat (5) begin
        #1;
        if (h.command_accepted || h.dut.g_valid_capacity.load_start || h.cpu_cycle_fire ||
            h.dut.g_valid_capacity.imem_write_enable)
          $fatal(1, "Rejected size altered CPU ownership");
        h.tick();
        check_old_session();
        if ({h.observed_ifid, h.observed_idex, h.observed_exmem, h.observed_memwb} !==
            saved_pipeline || h.debug_pc !== saved_pc || h.debug_cycle_count !== saved_count)
          $fatal(1, "Rejected request altered retained CPU state");
      end
      h.debug_read_select = 1'b1;
      for (integer address = 0; address < 2048; address = address + 1) begin
        h.debug_dmem_addr = 11'(address);
        #1;
        if (h.debug_dmem_used !== (address < 4) ||
            h.debug_dmem_data !== (address == 0 ? 8'd7 : 8'd0))
          $fatal(1, "Rejected request changed logical DMEM");
      end
    end else begin
      h.begin_load(8);
      h.send_byte(0, 8'h0b, 1'b0);
      h.send_byte(1, 8'h00, 1'b0);
      h.send_byte(2, 8'h00, 1'b0);
      h.load_abort = 1'b1;
      #1;
      if (!h.dut.g_valid_capacity.load_fail || h.dut.g_valid_capacity.imem_write_enable)
        $fatal(1, "Timeout abort did not suppress the partial word");
      h.tick();
      h.load_abort   = 1'b0;
      h.run_request  = 1'b1;
      h.step_request = 1'b1;
      #1;
      if (h.image_valid || h.command_accepted || h.cpu_cycle_fire ||
          h.global_state_code != STATE_CODE_NO_IMAGE)
        $fatal(1, "Aborted LOAD restored the old image or allowed execution");
      h.tick();
      h.run_request  = 1'b0;
      h.step_request = 1'b0;
      h.begin_load(4);
      for (integer offset = 0; offset < 4; offset = offset + 1)
      h.send_byte(offset, offset == 0 ? 8'h0b : 8'h00, offset == 3);
      h.prepare_ready();
      if (h.dut.g_valid_capacity.loaded_image_size_bytes != 4 || h.debug_pc != 0 ||
          h.debug_cycle_count != 0 || h.observed_ifid.valid || h.observed_ifid.fetch_fault_valid ||
          h.observed_idex.valid || h.observed_exmem.valid || h.observed_memwb.valid)
        $fatal(1, "Recovery did not prepare the short image");
      for (integer index = 1; index < 32; index = index + 1)
      if (h.dut.g_valid_capacity.id_stage_inst.register_file.registers[index] !== 0)
        $fatal(1, "Recovery retained old RF");
      for (integer address = 0; address < 2048; address = address + 1)
      if (h.memory_used(address) !== 1'b0) $fatal(1, "Recovery retained old DMEM marks");
      repeat (3) h.step_cycle();
      if (h.global_state_code != STATE_CODE_FINISHED || h.debug_cycle_count != 3)
        $fatal(1, "Recovered short image did not execute independently");
    end
    $display("PASS %s", h.data.case_id);
    $finish;
  end
endmodule
