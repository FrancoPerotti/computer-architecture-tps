// Valida en EX las regiones de DMEM y los targets que solicitan redirect.
module ex_flow_check #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0
) (
    input  logic                     valid,
    input  system_pkg::mem_op_t      mem_op,
    input  system_pkg::word_t        rs1_effective,
    input  system_pkg::word_t        immediate,
    input  logic                     redirect_requested,
    input  system_pkg::word_t        redirect_target,
    output logic                     ex_fault_candidate,
    output system_pkg::fault_cause_t ex_fault_cause
);
  import system_pkg::*;

  generate
    if (!memory_capacity_valid(DMEM_CAPACITY_BYTES)) begin : gen_invalid_capacity
      initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
      assign ex_fault_candidate = 1'b1;
      assign ex_fault_cause     = FAULT_LOAD_ACCESS_FAULT;
    end else begin : gen_valid_capacity
      localparam logic [32:0] DMEM_LIMIT_BYTES = 33'(DMEM_CAPACITY_BYTES);

      word_t        effective_address;
      logic  [32:0] access_size_bytes;
      logic  [32:0] access_end;
      logic         is_load;
      logic         is_store;
      logic         access_aligned;
      logic         access_range_valid;
      logic         target_misaligned_candidate;
      logic         load_misaligned_candidate;
      logic         load_access_candidate;
      logic         store_misaligned_candidate;
      logic         store_access_candidate;

      // La dirección efectiva se forma primero con la aritmética modular de RV32.
      assign effective_address = rs1_effective + immediate;

      always_comb begin
        is_load           = 1'b0;
        is_store          = 1'b0;
        access_size_bytes = 33'd1;
        case (mem_op)
          MEM_OP_LB, MEM_OP_LBU: begin
            is_load           = 1'b1;
            access_size_bytes = 33'd1;
          end
          MEM_OP_LH, MEM_OP_LHU: begin
            is_load           = 1'b1;
            access_size_bytes = 33'd2;
          end
          MEM_OP_LW: begin
            is_load           = 1'b1;
            access_size_bytes = 33'd4;
          end
          MEM_OP_SB: begin
            is_store          = 1'b1;
            access_size_bytes = 33'd1;
          end
          MEM_OP_SH: begin
            is_store          = 1'b1;
            access_size_bytes = 33'd2;
          end
          MEM_OP_SW: begin
            is_store          = 1'b1;
            access_size_bytes = 33'd4;
          end
          default: begin
            is_load           = 1'b0;
            is_store          = 1'b0;
            access_size_bytes = 33'd1;
          end
        endcase
      end

      // El extremo conserva el carry y no vuelve al comienzo del espacio de direcciones.
      assign access_end         = {1'b0, effective_address} + access_size_bytes;
      assign access_range_valid = access_end <= DMEM_LIMIT_BYTES;

      assign access_aligned = (access_size_bytes == 33'd1) ||
          ((access_size_bytes == 33'd2) && (effective_address[0] == 1'b0)) ||
          ((access_size_bytes == 33'd4) && (effective_address[1:0] == 2'b00));

      assign target_misaligned_candidate = redirect_requested && (redirect_target[1:0] != 2'b00);
      assign load_misaligned_candidate   = valid && is_load && !access_aligned;
      assign load_access_candidate       = valid && is_load && !access_range_valid;
      assign store_misaligned_candidate  = valid && is_store && !access_aligned;
      assign store_access_candidate      = valid && is_store && !access_range_valid;

      assign ex_fault_candidate = target_misaligned_candidate || load_misaligned_candidate ||
          load_access_candidate || store_misaligned_candidate || store_access_candidate;

      // La prioridad local coincide con la clasificación arquitectónica de EX.
      always_comb begin
        if (target_misaligned_candidate) begin
          ex_fault_cause = FAULT_INSTRUCTION_ADDRESS_MISALIGNED;
        end else if (load_misaligned_candidate) begin
          ex_fault_cause = FAULT_LOAD_ADDRESS_MISALIGNED;
        end else if (load_access_candidate) begin
          ex_fault_cause = FAULT_LOAD_ACCESS_FAULT;
        end else if (store_misaligned_candidate) begin
          ex_fault_cause = FAULT_STORE_ADDRESS_MISALIGNED;
        end else if (store_access_candidate) begin
          ex_fault_cause = FAULT_STORE_ACCESS_FAULT;
        end else begin
          ex_fault_cause = FAULT_INSTRUCTION_ADDRESS_MISALIGNED;
        end
      end
    end
  endgenerate
endmodule
