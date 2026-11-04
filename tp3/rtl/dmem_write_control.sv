// Autoriza el commit de stores y genera una máscara relativa al dato de escritura.
module dmem_write_control (
    input  logic                      cpu_cycle_fire,
    input  logic                      exmem_valid,
    input  logic                      is_store,
    input  system_pkg::mem_op_t       mem_op,
    output logic                      dmem_store_fire,
    output logic                [3:0] byte_enable
);
  import system_pkg::*;

  assign dmem_store_fire = cpu_cycle_fire && exmem_valid && is_store;

  always_comb begin
    case (mem_op)
      MEM_OP_SB: byte_enable = 4'b0001;
      MEM_OP_SH: byte_enable = 4'b0011;
      MEM_OP_SW: byte_enable = 4'b1111;
      default:   byte_enable = 4'b0000;
    endcase
  end
endmodule
