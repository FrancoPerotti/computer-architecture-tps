// Sistema funcional: UART, protocolo, CPU y serialización de respuestas.
module system_top #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_IMEM_CAPACITY_BYTES,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_DMEM_CAPACITY_BYTES
) (
    input  logic clk,
    input  logic reset,
    input  logic serial_rx,
    output logic serial_tx,
    output logic uart_reset_request
);
  import system_pkg::*;
  localparam integer IMAGE_SIZE_WIDTH        = capacity_inclusive_width(IMEM_CAPACITY_BYTES);
  localparam integer IMEM_BYTE_ADDRESS_WIDTH = byte_address_width(IMEM_CAPACITY_BYTES);
  localparam integer DMEM_BYTE_ADDRESS_WIDTH = byte_address_width(DMEM_CAPACITY_BYTES);

  logic [7:0] r_data, w_data;
  logic rd_uart, rx_empty, wr_uart, tx_full, rx_error_tick, rx_activity, rx_receiving, tx_done_tick;
  logic response_busy, response_done_tick, response_start, response_with_debug;
  logic [7:0] response_opcode, response_result;
  logic
      load_request,
      run_request,
      step_request,
      load_byte_valid,
      load_last_byte,
      load_abort,
      debug_read_select;
  logic [       IMAGE_SIZE_WIDTH-1:0] load_size_bytes;
  logic [                        7:0] load_byte_data;
  logic [IMEM_BYTE_ADDRESS_WIDTH-1:0] load_byte_offset;
  logic
      command_accepted,
      load_available,
      prepare_active,
      program_finished,
      fault_terminal,
      cpu_cycle_fire,
      image_valid;
  logic debug_dmem_used;
  word_t debug_rf_data, debug_pc, debug_fault_pc;
  logic               [                        7:0] debug_dmem_data;
  global_state_code_t                               global_state_code;
  fault_cause_t                                     debug_fault_cause;
  logic               [                       63:0] debug_cycle_count;
  logic               [                        4:0] debug_rf_addr;
  logic               [DMEM_BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr;
  logic
      debug_ifid_valid,
      debug_ifid_fetch_fault_valid,
      debug_idex_valid,
      debug_idex_alu_src,
      debug_idex_reg_write;
  logic debug_exmem_valid, debug_exmem_reg_write, debug_memwb_valid, debug_memwb_reg_write;
  logic [31:0] debug_ifid_pc, debug_ifid_instruction, debug_idex_pc, debug_idex_instruction;
  logic [31:0] debug_idex_rs1_value, debug_idex_rs2_value, debug_idex_immediate;
  logic [31:0]
      debug_exmem_pc, debug_exmem_instruction, debug_exmem_ex_result, debug_exmem_store_data;
  logic [31:0] debug_memwb_pc, debug_memwb_instruction, debug_memwb_wb_value;
  logic [2:0] debug_ifid_fetch_fault_cause, debug_idex_flow_op;
  logic [4:0] debug_idex_rs1, debug_idex_rs2, debug_idex_rd, debug_exmem_rd, debug_memwb_rd;
  logic [5:0] debug_idex_alu_op;
  logic [1:0] debug_idex_result_sel;
  logic [3:0] debug_idex_mem_op, debug_exmem_mem_op;

  uart_core uart_inst (.*);
  protocol_controller #(.IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)) controller_inst (.*);
  processor_top #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES),
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) processor_inst (
      .*
  );
  response_serializer #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) serializer_inst (
      .clk,
      .reset,
      .tx_full,
      .tx_done_tick,
      .w_data,
      .wr_uart,
      .response_start,
      .response_opcode,
      .response_result,
      .response_with_debug,
      .response_busy,
      .response_done_tick,
      .debug_state_code (global_state_code),
      .debug_image_valid(image_valid),
      .debug_pc,
      .debug_cycle_count,
      .debug_fault_cause,
      .debug_fault_pc,
      .debug_rf_addr,
      .debug_rf_data,
      .debug_ifid_valid,
      .debug_ifid_pc,
      .debug_ifid_instruction,
      .debug_ifid_fetch_fault_valid,
      .debug_ifid_fetch_fault_cause,
      .debug_idex_valid,
      .debug_idex_pc,
      .debug_idex_instruction,
      .debug_idex_rs1,
      .debug_idex_rs2,
      .debug_idex_rd,
      .debug_idex_rs1_value,
      .debug_idex_rs2_value,
      .debug_idex_immediate,
      .debug_idex_alu_op,
      .debug_idex_alu_src,
      .debug_idex_result_sel,
      .debug_idex_flow_op,
      .debug_idex_mem_op,
      .debug_idex_reg_write,
      .debug_exmem_valid,
      .debug_exmem_pc,
      .debug_exmem_instruction,
      .debug_exmem_rd,
      .debug_exmem_reg_write,
      .debug_exmem_mem_op,
      .debug_exmem_ex_result,
      .debug_exmem_store_data,
      .debug_memwb_valid,
      .debug_memwb_pc,
      .debug_memwb_instruction,
      .debug_memwb_rd,
      .debug_memwb_reg_write,
      .debug_memwb_wb_value,
      .debug_dmem_addr,
      .debug_dmem_data,
      .debug_dmem_used
  );
endmodule
