`timescale 1ns / 1ps

// Frontera de pruebas compartida: todos los módulos instanciados pertenecen al RTL real.
module processor_test_harness #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd1024,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd2048,
    localparam integer IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES),
    localparam integer IMEM_BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(
        IMEM_CAPACITY_BYTES
    ),
    localparam integer DMEM_BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
);
  import system_pkg::*;
  logic                                                         clk = '0;
  logic                                                         reset = '0;
  logic                                                         load_request = '0;
  logic                                                         run_request = '0;
  logic                                                         step_request = '0;
  logic                                                         load_byte_valid = '0;
  logic                                                         load_last_byte = '0;
  logic                                                         load_abort = '0;
  logic                                                         debug_read_select = '0;
  logic                           [       IMAGE_SIZE_WIDTH-1:0] load_size_bytes = '0;
  logic                           [                        7:0] load_byte_data = '0;
  logic                           [IMEM_BYTE_ADDRESS_WIDTH-1:0] load_byte_offset = '0;
  system_pkg::register_index_t                                  debug_rf_addr = '0;
  logic                           [DMEM_BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr = '0;
  logic                                                         command_accepted;
  logic                                                         load_available;
  logic                                                         prepare_active;
  logic                                                         program_finished;
  logic                                                         fault_terminal;
  logic                                                         cpu_cycle_fire;
  logic                                                         image_valid;
  logic                                                         debug_dmem_used;
  system_pkg::word_t                                            debug_rf_data;
  system_pkg::word_t                                            debug_pc;
  system_pkg::word_t                                            debug_fault_pc;
  logic                           [                        7:0] debug_dmem_data;
  system_pkg::global_state_code_t                               global_state_code;
  system_pkg::fault_cause_t                                     debug_fault_cause;
  logic                           [                       63:0] debug_cycle_count;
  if_id_t                                                       observed_ifid;
  id_ex_t                                                       observed_idex;
  ex_mem_t                                                      observed_exmem;
  mem_wb_t                                                      observed_memwb;

  string session_path;
  string expected_path;

  tp3_case_data data ();
  processor_top #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES),
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk                         (clk),
      .reset                       (reset),
      .load_request                (load_request),
      .run_request                 (run_request),
      .step_request                (step_request),
      .load_byte_valid             (load_byte_valid),
      .load_last_byte              (load_last_byte),
      .load_abort                  (load_abort),
      .debug_read_select           (debug_read_select),
      .load_size_bytes             (load_size_bytes),
      .load_byte_data              (load_byte_data),
      .load_byte_offset            (load_byte_offset),
      .debug_rf_addr               (debug_rf_addr),
      .debug_dmem_addr             (debug_dmem_addr),
      .command_accepted            (command_accepted),
      .load_available              (load_available),
      .prepare_active              (prepare_active),
      .program_finished            (program_finished),
      .fault_terminal              (fault_terminal),
      .cpu_cycle_fire              (cpu_cycle_fire),
      .image_valid                 (image_valid),
      .debug_dmem_used             (debug_dmem_used),
      .debug_rf_data               (debug_rf_data),
      .debug_pc                    (debug_pc),
      .debug_fault_pc              (debug_fault_pc),
      .debug_dmem_data             (debug_dmem_data),
      .global_state_code           (global_state_code),
      .debug_fault_cause           (debug_fault_cause),
      .debug_cycle_count           (debug_cycle_count),
      .debug_ifid_valid            (observed_ifid.valid),
      .debug_ifid_pc               (observed_ifid.pc),
      .debug_ifid_instruction      (observed_ifid.instruction),
      .debug_ifid_fetch_fault_valid(observed_ifid.fetch_fault_valid),
      .debug_ifid_fetch_fault_cause(observed_ifid.fetch_fault_cause),
      .debug_idex_valid            (observed_idex.valid),
      .debug_idex_pc               (observed_idex.pc),
      .debug_idex_instruction      (observed_idex.instruction),
      .debug_idex_rs1              (observed_idex.rs1),
      .debug_idex_rs2              (observed_idex.rs2),
      .debug_idex_rd               (observed_idex.rd),
      .debug_idex_rs1_value        (observed_idex.rs1_value),
      .debug_idex_rs2_value        (observed_idex.rs2_value),
      .debug_idex_immediate        (observed_idex.immediate),
      .debug_idex_alu_op           (observed_idex.alu_op),
      .debug_idex_alu_src          (observed_idex.alu_src),
      .debug_idex_result_sel       (observed_idex.result_sel),
      .debug_idex_flow_op          (observed_idex.flow_op),
      .debug_idex_mem_op           (observed_idex.mem_op),
      .debug_idex_reg_write        (observed_idex.reg_write),
      .debug_exmem_valid           (observed_exmem.valid),
      .debug_exmem_pc              (observed_exmem.pc),
      .debug_exmem_instruction     (observed_exmem.instruction),
      .debug_exmem_rd              (observed_exmem.rd),
      .debug_exmem_reg_write       (observed_exmem.reg_write),
      .debug_exmem_mem_op          (observed_exmem.mem_op),
      .debug_exmem_ex_result       (observed_exmem.ex_result),
      .debug_exmem_store_data      (observed_exmem.store_data),
      .debug_memwb_valid           (observed_memwb.valid),
      .debug_memwb_pc              (observed_memwb.pc),
      .debug_memwb_instruction     (observed_memwb.instruction),
      .debug_memwb_rd              (observed_memwb.rd),
      .debug_memwb_reg_write       (observed_memwb.reg_write),
      .debug_memwb_wb_value        (observed_memwb.wb_value)
  );

  always #10 clk = ~clk;

  function automatic logic memory_used(input integer address);
    case (address % 4)
      0:
      memory_used = dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_0[
          address/4];
      1:
      memory_used = dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_1[
          address/4];
      2:
      memory_used = dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_2[
          address/4];
      default:
      memory_used = dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_3[
          address/4];
    endcase
  endfunction

  // Solo prepara residuos y precondiciones de memoria declaradas por el caso del catálogo.
  task automatic seed_memory_byte(input integer address, input logic [7:0] value);
    case (address % 4)
      0: begin
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_0[address/4] =
            value;
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_0[address/4] =
            1'b1;
      end
      1: begin
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_1[address/4] =
            value;
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_1[address/4] =
            1'b1;
      end
      2: begin
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_2[address/4] =
            value;
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_2[address/4] =
            1'b1;
      end
      default: begin
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_3[address/4] =
            value;
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_3[address/4] =
            1'b1;
      end
    endcase
  endtask


  task automatic tick;
    @(posedge clk);
    #1;
    @(negedge clk);
  endtask

  task automatic reset_cpu;
    reset = 1'b1;
    #1;
    if (cpu_cycle_fire || dut.g_valid_capacity.rf_write_fire ||
        dut.g_valid_capacity.imem_write_enable || dut.g_valid_capacity.prepare_dmem_clear)
      $fatal(1, "Reset did not suppress resources");
    tick();
    reset = 1'b0;
    if (global_state_code != STATE_CODE_NO_IMAGE || image_valid || debug_pc != 0 ||
        debug_cycle_count != 0)
      $fatal(1, "CPU did not reset");
  endtask

  task automatic begin_load(input integer size);
    load_size_bytes = IMAGE_SIZE_WIDTH'(size);
    load_request    = 1'b1;
    #1;
    if (!command_accepted || cpu_cycle_fire) $fatal(1, "LOAD not accepted alone");
    tick();
    load_request = 1'b0;
    if (image_valid || global_state_code != STATE_CODE_LOADING) $fatal(1, "Old image retained");
  endtask

  task automatic send_byte(input integer offset, input logic [7:0] value, input bit last);
    load_byte_offset = IMEM_BYTE_ADDRESS_WIDTH'(offset);
    load_byte_data   = value;
    load_last_byte   = last;
    load_byte_valid  = 1'b1;
    #1;
    if (dut.g_valid_capacity.imem_write_enable !== (offset % 4 == 3) ||
        dut.g_valid_capacity.load_ok !== last || cpu_cycle_fire)
      $fatal(1, "Incorrect fourth byte or Loader ownership");
    tick();
    load_byte_valid = 1'b0;
    load_last_byte  = 1'b0;
  endtask

  task automatic load_program(input string path);
    integer count;
    word_t  value;
    count = data.get_size(path);
    begin_load(4 * count);
    for (integer offset = 0; offset < 4 * count; offset = offset + 1) begin
      value = 32'(data.get_integer($sformatf("%s/%0d", path, offset / 4)));
      send_byte(offset, 8'(value >> (8 * (offset % 4))), offset == 4 * count - 1);
    end
    if (!prepare_active || image_valid) $fatal(1, "LOAD published without preparation");
  endtask

  task automatic prepare_ready;
    for (integer address = 0; 64'(address) < DMEM_CAPACITY_BYTES; address = address + 1) begin
      #1;
      if (!prepare_active || cpu_cycle_fire || !dut.g_valid_capacity.prepare_dmem_clear ||
          dut.g_valid_capacity.prepare_dmem_addr !== DMEM_BYTE_ADDRESS_WIDTH'(address) ||
          dut.g_valid_capacity.prepare_init !== (address == 0))
        $fatal(1, "Incorrect preparation order or ownership");
      tick();
      if (debug_pc != 0 || debug_cycle_count != 0 || observed_ifid.valid || observed_idex.valid ||
          observed_exmem.valid || observed_memwb.valid)
        $fatal(1, "Preparation retained CPU state");
    end
    #1;
    if (!dut.g_valid_capacity.prepare_done || dut.g_valid_capacity.prepare_dmem_clear ||
        cpu_cycle_fire)
      $fatal(1, "Last clear overlaps first CPU cycle");
    tick();
    if (global_state_code != STATE_CODE_READY || !image_valid || debug_cycle_count != 0)
      $fatal(1, "Incorrect publication");
  endtask

  task automatic step_cycle;
    step_request = 1'b1;
    #1;
    if (!command_accepted || !cpu_cycle_fire) $fatal(1, "STEP not accepted");
    tick();
    step_request = 1'b0;
  endtask

  initial begin
    #20_000_000;
    $fatal(1, "CPU harness timeout");
  end
endmodule
