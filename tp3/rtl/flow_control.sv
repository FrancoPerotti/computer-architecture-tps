// Clasifica los cambios de flujo y produce candidatos combinacionales para el control global.
module flow_control (
    input  logic                 valid,
    input  system_pkg::flow_op_t flow_op,
    input  logic                 zero,
    output logic                 target_sel,
    output logic                 redirect_requested,
    output logic                 ex_halt_candidate
);
  import system_pkg::*;

  logic branch_taken;

  assign target_sel = flow_op == FLOW_OP_JALR;
  assign branch_taken = (flow_op == FLOW_OP_BEQ && zero) || (flow_op == FLOW_OP_BNE && !zero);
  assign redirect_requested = valid &&
      (branch_taken || flow_op == FLOW_OP_JAL || flow_op == FLOW_OP_JALR);
  assign ex_halt_candidate = valid && flow_op == FLOW_OP_HALT;
endmodule
