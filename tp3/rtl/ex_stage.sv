// Integra forwarding, ejecución, destinos y candidatos de eventos de EX.
module ex_stage #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0
) (
    input  system_pkg::id_ex_t       idex,
    input  system_pkg::ex_mem_t      exmem_producer,
    input  system_pkg::mem_wb_t      memwb_producer,
    output system_pkg::ex_mem_t      exmem_input,
    output system_pkg::word_t        redirect_target,
    output logic                     redirect_requested,
    output logic                     ex_halt_candidate,
    output logic                     ex_fault_candidate,
    output system_pkg::fault_cause_t ex_fault_cause
);
  import system_pkg::*;

  forward_sel_t forward_a_sel;
  forward_sel_t forward_b_sel;
  word_t        rs1_effective;
  word_t        rs2_effective;
  word_t        alu_operand_b;
  word_t        alu_result;
  logic         alu_zero;
  word_t        link_value;
  word_t        pc_relative_target;
  word_t        jalr_sum;
  word_t        jalr_target;
  word_t        ex_result;
  logic         target_sel;

  forwarding_unit forwarding_unit (
      .idex_valid      (idex.valid),
      .idex_instruction(idex.instruction),
      .idex_rs1        (idex.rs1),
      .idex_rs2        (idex.rs2),
      .exmem_valid     (exmem_producer.valid),
      .exmem_rd        (exmem_producer.rd),
      .exmem_reg_write (exmem_producer.reg_write),
      .exmem_mem_op    (exmem_producer.mem_op),
      .memwb_valid     (memwb_producer.valid),
      .memwb_rd        (memwb_producer.rd),
      .memwb_reg_write (memwb_producer.reg_write),
      .forward_a_sel   (forward_a_sel),
      .forward_b_sel   (forward_b_sel)
  );

  assign rs1_effective = forward_a_sel == FORWARD_SEL_EX_MEM ? exmem_producer.ex_result :
      forward_a_sel == FORWARD_SEL_MEM_WB ? memwb_producer.wb_value : idex.rs1_value;
  assign rs2_effective = forward_b_sel == FORWARD_SEL_EX_MEM ? exmem_producer.ex_result :
      forward_b_sel == FORWARD_SEL_MEM_WB ? memwb_producer.wb_value : idex.rs2_value;

  assign alu_operand_b = idex.alu_src == ALU_SRC_IMMEDIATE ? idex.immediate : rs2_effective;

  alu alu (
      .a         (rs1_effective),
      .b         (alu_operand_b),
      .alu_op    (idex.alu_op),
      .alu_result(alu_result),
      .zero      (alu_zero)
  );

  assign link_value         = idex.pc + word_t'(4);
  assign pc_relative_target = idex.pc + idex.immediate;
  assign jalr_sum           = rs1_effective + idex.immediate;
  assign jalr_target        = {jalr_sum[31:1], 1'b0};

  assign ex_result = idex.result_sel == RESULT_SEL_ALU ? alu_result :
      idex.result_sel == RESULT_SEL_IMMEDIATE ? idex.immediate :
      idex.result_sel == RESULT_SEL_LINK ? link_value : word_t'(32'b0);

  flow_control flow_control (
      .valid             (idex.valid),
      .flow_op           (idex.flow_op),
      .zero              (alu_zero),
      .target_sel        (target_sel),
      .redirect_requested(redirect_requested),
      .ex_halt_candidate (ex_halt_candidate)
  );

  assign redirect_target = target_sel ? jalr_target : pc_relative_target;

  ex_fault_check #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) ex_fault_check (
      .valid             (idex.valid),
      .mem_op            (idex.mem_op),
      .rs1_effective     (rs1_effective),
      .immediate         (idex.immediate),
      .redirect_requested(redirect_requested),
      .redirect_target   (redirect_target),
      .ex_fault_candidate(ex_fault_candidate),
      .ex_fault_cause    (ex_fault_cause)
  );

  // El control externo decide captura/invalidez; EX entrega siempre el payload candidato.
  assign exmem_input.valid       = idex.valid;
  assign exmem_input.pc          = idex.pc;
  assign exmem_input.instruction = idex.instruction;
  assign exmem_input.rd          = idex.rd;
  assign exmem_input.reg_write   = idex.reg_write;
  assign exmem_input.mem_op      = idex.mem_op;
  assign exmem_input.ex_result   = ex_result;
  assign exmem_input.store_data  = rs2_effective;
endmodule
