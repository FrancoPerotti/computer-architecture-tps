// Deriva los controles locales de MEM desde la operación registrada en EX/MEM.
module mem_decode (
    input  system_pkg::mem_op_t      mem_op,
    output logic                     is_store,
    output system_pkg::access_size_t access_size,
    output logic                     load_unsigned,
    output logic                     wb_value_sel
);
  import system_pkg::*;

  logic is_load;

  always_comb begin
    is_load       = 1'b0;
    is_store      = 1'b0;
    access_size   = ACCESS_SIZE_BYTE;
    load_unsigned = 1'b0;

    case (mem_op)
      MEM_OP_LB: is_load = 1'b1;
      MEM_OP_LH: begin
        is_load     = 1'b1;
        access_size = ACCESS_SIZE_HALFWORD;
      end
      MEM_OP_LW: begin
        is_load     = 1'b1;
        access_size = ACCESS_SIZE_WORD;
      end
      MEM_OP_LBU: begin
        is_load       = 1'b1;
        load_unsigned = 1'b1;
      end
      MEM_OP_LHU: begin
        is_load       = 1'b1;
        access_size   = ACCESS_SIZE_HALFWORD;
        load_unsigned = 1'b1;
      end
      MEM_OP_SB: is_store = 1'b1;
      MEM_OP_SH: begin
        is_store    = 1'b1;
        access_size = ACCESS_SIZE_HALFWORD;
      end
      MEM_OP_SW: begin
        is_store    = 1'b1;
        access_size = ACCESS_SIZE_WORD;
      end
      default: begin
        is_load       = 1'b0;
        is_store      = 1'b0;
        access_size   = ACCESS_SIZE_BYTE;
        load_unsigned = 1'b0;
      end
    endcase
  end

  assign wb_value_sel = is_load;
endmodule
