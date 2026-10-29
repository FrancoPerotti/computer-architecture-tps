// Integra acceso DMEM, extensión de loads y formación del payload destinado a MEM/WB.
module mem_stage #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0,
    localparam int unsigned BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
) (
    input  logic                                         clk,
    input  logic                                         reset,
    input  system_pkg::ex_mem_t                          exmem,
    input  logic                                         cpu_cycle_fire,
    input  logic                                         prepare_dmem_clear,
    input  logic                [BYTE_ADDRESS_WIDTH-1:0] prepare_dmem_addr,
    input  logic                                         debug_read_select,
    input  logic                [BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr,
    output system_pkg::mem_wb_t                          memwb_input,
    output logic                [                   7:0] debug_dmem_data,
    output logic                                         debug_dmem_used
);
  import system_pkg::*;

  logic               is_store;
  access_size_t       access_size;
  logic               load_unsigned;
  logic               wb_value_sel;
  logic               dmem_store_fire;
  logic         [3:0] byte_enable;
  word_t              mem_read_data;
  word_t              load_value;

  mem_decode mem_decode (
      .mem_op       (exmem.mem_op),
      .is_store     (is_store),
      .access_size  (access_size),
      .load_unsigned(load_unsigned),
      .wb_value_sel (wb_value_sel)
  );

  dmem_write_control dmem_write_control (
      .cpu_cycle_fire (cpu_cycle_fire),
      .exmem_valid    (exmem.valid),
      .is_store       (is_store),
      .mem_op         (exmem.mem_op),
      .dmem_store_fire(dmem_store_fire),
      .byte_enable    (byte_enable)
  );

  data_memory #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) data_memory (
      .clk               (clk),
      .reset             (reset),
      .address           (exmem.ex_result),
      .write_data        (exmem.store_data),
      .write_enable      (dmem_store_fire),
      .byte_enable       (byte_enable),
      .prepare_dmem_clear(prepare_dmem_clear),
      .prepare_dmem_addr (prepare_dmem_addr),
      .debug_read_select (debug_read_select),
      .debug_dmem_addr   (debug_dmem_addr),
      .mem_read_data     (mem_read_data),
      .debug_dmem_data   (debug_dmem_data),
      .debug_dmem_used   (debug_dmem_used)
  );

  load_select_extend load_select_extend (
      .mem_read_data   (mem_read_data),
      .address_low_bits(exmem.ex_result[1:0]),
      .access_size     (access_size),
      .load_unsigned   (load_unsigned),
      .load_value      (load_value)
  );

  assign memwb_input.valid       = exmem.valid;
  assign memwb_input.pc          = exmem.pc;
  assign memwb_input.instruction = exmem.instruction;
  assign memwb_input.rd          = exmem.rd;
  assign memwb_input.reg_write   = exmem.reg_write;
  assign memwb_input.wb_value    = wb_value_sel ? load_value : exmem.ex_result;
endmodule
