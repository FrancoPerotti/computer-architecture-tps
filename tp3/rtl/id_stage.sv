// Integra decodificación, RF y candidatos; entrega el payload combinacional de ID/EX.
module id_stage (
    input  logic                        clk,
    input  logic                        reset,
    input  logic                        prepare_init,
    input  system_pkg::if_id_t          ifid,
    input  logic                        idex_valid,
    input  system_pkg::register_index_t idex_rd,
    input  system_pkg::mem_op_t         idex_mem_op,
    input  system_pkg::register_index_t rf_write_addr,
    input  system_pkg::word_t           rf_write_data,
    input  logic                        rf_write_fire,
    input  logic                        bypass_rs1,
    input  logic                        bypass_rs2,
    input  logic                        debug_read_select,
    input  system_pkg::register_index_t debug_rf_addr,
    output system_pkg::id_ex_t          idex_input,
    output logic                        id_fault_candidate,
    output system_pkg::fault_cause_t    id_fault_cause,
    output system_pkg::word_t           id_fault_pc,
    output logic                        load_use_stall,
    output system_pkg::word_t           debug_rf_data
);
  import system_pkg::*;

  logic  decode_legal;
  logic  uses_rs1;
  logic  uses_rs2;
  word_t rf_rs1_value;
  word_t rf_rs2_value;

  // La identidad sigue a IF/ID; el control externo decide captura, bubble o retención.
  assign idex_input.valid       = ifid.valid;
  assign idex_input.pc          = ifid.pc;
  assign idex_input.instruction = ifid.instruction;
  assign idex_input.rs1         = ifid.instruction[19:15];
  assign idex_input.rs2         = ifid.instruction[24:20];
  assign idex_input.rd          = ifid.instruction[11:7];

  decoder decoder (
      .instruction (ifid.instruction),
      .decode_legal(decode_legal),
      .alu_op      (idex_input.alu_op),
      .alu_src     (idex_input.alu_src),
      .result_sel  (idex_input.result_sel),
      .flow_op     (idex_input.flow_op),
      .mem_op      (idex_input.mem_op),
      .reg_write   (idex_input.reg_write),
      .uses_rs1    (uses_rs1),
      .uses_rs2    (uses_rs2)
  );

  immediate_generator immediate_generator (
      .instruction(ifid.instruction),
      .immediate  (idex_input.immediate)
  );

  // RF recibe el writeback ya habilitado por WB y conserva su prioridad local de inicio.
  register_file register_file (
      .clk              (clk),
      .reset            (reset),
      .prepare_init     (prepare_init),
      .read_register_1  (idex_input.rs1),
      .read_register_2  (idex_input.rs2),
      .debug_rf_addr    (debug_rf_addr),
      .debug_read_select(debug_read_select),
      .write_register   (rf_write_addr),
      .write_data       (rf_write_data),
      .write_enable     (rf_write_fire),
      .rf_rs1_value     (rf_rs1_value),
      .rf_rs2_value     (rf_rs2_value),
      .debug_rf_data    (debug_rf_data)
  );

  // Cada mux aplica el selector de WB; Debug conserva la lectura base anterior al bypass.
  assign idex_input.rs1_value = bypass_rs1 ? rf_write_data : rf_rs1_value;
  assign idex_input.rs2_value = bypass_rs2 ? rf_write_data : rf_rs2_value;

  id_fault_check id_fault_check (
      .ifid_valid            (ifid.valid),
      .ifid_pc               (ifid.pc),
      .ifid_fetch_fault_valid(ifid.fetch_fault_valid),
      .ifid_fetch_fault_cause(ifid.fetch_fault_cause),
      .decode_legal          (decode_legal),
      .id_fault_candidate    (id_fault_candidate),
      .id_fault_cause        (id_fault_cause),
      .id_fault_pc           (id_fault_pc)
  );

  // Los usos son combinacionales: no se agregan campos al payload de ID/EX.
  load_use_detector load_use_detector (
      .ifid_valid    (ifid.valid),
      .rs1           (idex_input.rs1),
      .rs2           (idex_input.rs2),
      .uses_rs1      (uses_rs1),
      .uses_rs2      (uses_rs2),
      .idex_valid    (idex_valid),
      .idex_rd       (idex_rd),
      .idex_mem_op   (idex_mem_op),
      .load_use_stall(load_use_stall)
  );
endmodule
