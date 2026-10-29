// Forma el writeback efectivo y los selectores de bypass WB hacia ID.
module wb_stage (
    input  system_pkg::mem_wb_t         memwb,
    input  logic                        cpu_cycle_fire,
    input  system_pkg::register_index_t ifid_rs1,
    input  system_pkg::register_index_t ifid_rs2,
    output system_pkg::register_index_t rf_write_register,
    output system_pkg::word_t           rf_write_data,
    output logic                        rf_write_fire,
    output logic                        bypass_rs1,
    output logic                        bypass_rs2
);
  assign rf_write_register = memwb.rd;
  assign rf_write_data     = memwb.wb_value;
  assign rf_write_fire     = cpu_cycle_fire && memwb.valid && memwb.reg_write && (memwb.rd != '0);
  assign bypass_rs1        = rf_write_fire && (memwb.rd == ifid_rs1);
  assign bypass_rs2        = rf_write_fire && (memwb.rd == ifid_rs2);
endmodule
