`timescale 1ns / 1ps

// Ejecuta las imágenes de placa por la interfaz normal de processor_top.
// Las observaciones se comparan en Python con el mismo oráculo usado para UART.
module board_acceptance_cpu_tb;
  import system_pkg::*;
  processor_test_harness cpu ();

  task automatic emit(input logic [63:0] value, input integer size);
    for (integer index = 0; index < size; index++) $write("%02x", 8'(value >> (8 * index)));
  endtask

  task automatic snapshot;
    integer       count;
    bit           used    [2048];
    logic   [7:0] contents[2048];
    count                 = 0;
    cpu.debug_read_select = 1'b1;
    for (integer address = 0; address < 2048; address++) begin
      cpu.debug_dmem_addr = 11'(address);
      #1;
      used[address]     = cpu.debug_dmem_used;
      contents[address] = cpu.debug_dmem_data;
      if (used[address]) count++;
    end

    $write("DEBUG ");
    emit(64'(cpu.global_state_code), 1);
    emit(64'(cpu.image_valid), 1);
    emit(64'(cpu.debug_pc), 4);
    emit(cpu.debug_cycle_count, 8);
    emit(64'(cpu.debug_fault_cause), 1);
    emit(64'(cpu.debug_fault_pc), 4);
    for (integer index = 0; index < 32; index++) begin
      cpu.debug_rf_addr = 5'(index);
      #1;
      emit(64'(cpu.debug_rf_data), 4);
    end
    emit(64'(cpu.observed_ifid.valid), 1);
    emit(64'(cpu.observed_ifid.pc), 4);
    emit(64'(cpu.observed_ifid.instruction), 4);
    emit(64'(cpu.observed_ifid.fetch_fault_valid), 1);
    emit(64'(cpu.observed_ifid.fetch_fault_cause), 1);
    emit(64'(cpu.observed_idex.valid), 1);
    emit(64'(cpu.observed_idex.pc), 4);
    emit(64'(cpu.observed_idex.instruction), 4);
    emit(64'(cpu.observed_idex.rs1), 1);
    emit(64'(cpu.observed_idex.rs2), 1);
    emit(64'(cpu.observed_idex.rd), 1);
    emit(64'(cpu.observed_idex.rs1_value), 4);
    emit(64'(cpu.observed_idex.rs2_value), 4);
    emit(64'(cpu.observed_idex.immediate), 4);
    emit(64'(cpu.observed_idex.alu_op), 1);
    emit(64'(cpu.observed_idex.alu_src), 1);
    emit(64'(cpu.observed_idex.result_sel), 1);
    emit(64'(cpu.observed_idex.flow_op), 1);
    emit(64'(cpu.observed_idex.mem_op), 1);
    emit(64'(cpu.observed_idex.reg_write), 1);
    emit(64'(cpu.observed_exmem.valid), 1);
    emit(64'(cpu.observed_exmem.pc), 4);
    emit(64'(cpu.observed_exmem.instruction), 4);
    emit(64'(cpu.observed_exmem.rd), 1);
    emit(64'(cpu.observed_exmem.reg_write), 1);
    emit(64'(cpu.observed_exmem.mem_op), 1);
    emit(64'(cpu.observed_exmem.ex_result), 4);
    emit(64'(cpu.observed_exmem.store_data), 4);
    emit(64'(cpu.observed_memwb.valid), 1);
    emit(64'(cpu.observed_memwb.pc), 4);
    emit(64'(cpu.observed_memwb.instruction), 4);
    emit(64'(cpu.observed_memwb.rd), 1);
    emit(64'(cpu.observed_memwb.reg_write), 1);
    emit(64'(cpu.observed_memwb.wb_value), 4);
    emit(64'(count), 5);
    for (integer address = 0; address < 2048; address++) begin
      if (used[address]) begin
        emit(64'(address), 4);
        emit(64'(contents[address]), 1);
      end
    end
    $display("");
    cpu.debug_read_select = 1'b0;
    @(negedge cpu.clk);
  endtask

  task automatic step_program;
    if (cpu.program_finished || cpu.fault_terminal) begin
      cpu.step_request = 1'b1;
      #1;
      if (!cpu.command_accepted || cpu.cpu_cycle_fire) $fatal(1, "STEP restart not accepted");
      cpu.tick();
      cpu.step_request = 1'b0;
      for (integer count = 0; count <= 2048 && cpu.prepare_active; count++) begin
        cpu.tick();
      end
      if (cpu.debug_cycle_count != 1) $fatal(1, "STEP restart did not execute one cycle");
    end else begin
      cpu.step_cycle();
    end
  endtask

  task automatic run_program;
    cpu.run_request = 1'b1;
    #1;
    if (!cpu.command_accepted || !cpu.cpu_cycle_fire) $fatal(1, "RUN not accepted");
    cpu.tick();
    cpu.run_request = 1'b0;
    for (integer count = 1; count < 20000; count++) begin
      if (cpu.program_finished || cpu.fault_terminal) return;
      cpu.tick();
    end
    $fatal(1, "RUN did not reach terminal");
  endtask

  initial begin
    string path;
    string operation;
    cpu.data.load();
    cpu.reset_cpu();
    for (integer index = 0; index < cpu.data.get_size("/actions"); index++) begin
      path      = $sformatf("/actions/%0d", index);
      operation = cpu.data.get_string({path, "/op"});
      if (operation == "load") begin
        cpu.load_program({path, "/words"});
        cpu.prepare_ready();
      end else if (operation == "step") begin
        step_program();
        snapshot();
      end else if (operation == "run") begin
        run_program();
        snapshot();
      end else if (operation == "reset") begin
        cpu.reset_cpu();
      end else begin
        $fatal(1, "Unexpected operation %s", operation);
      end
    end
    $display("PASS %s", cpu.data.case_id);
    $finish;
  end
endmodule
