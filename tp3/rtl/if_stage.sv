// Frente de búsqueda: PC registrado y payload combinacional para el registro IF/ID externo.
module if_stage #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0,
    localparam int unsigned WORD_INDEX_WIDTH = system_pkg::word_index_width(IMEM_CAPACITY_BYTES),
    localparam int unsigned IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(
        IMEM_CAPACITY_BYTES
    )
) (
    input  logic                                      clk,
    input  logic                                      reset,
    input  logic                                      prepare_init,
    input  logic                                      act_normal,
    input  logic                                      act_redirect,
    input  system_pkg::word_t                         redirect_target,
    input  logic               [IMAGE_SIZE_WIDTH-1:0] loaded_image_size_bytes,
    input  logic               [WORD_INDEX_WIDTH-1:0] imem_write_index,
    input  system_pkg::word_t                         imem_write_data,
    input  logic                                      imem_write_enable,
    output system_pkg::if_id_t                        ifid_input,
    output system_pkg::word_t                         debug_pc
);
  import system_pkg::*;

  generate
    if (!memory_capacity_valid(IMEM_CAPACITY_BYTES)) begin : gen_invalid_capacity
      // La rama inválida no instancia IMEM ni sus recursos.
      initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
      assign ifid_input = '0;
      assign debug_pc   = '0;
    end else begin : gen_valid_capacity
      word_t        pc;
      word_t        pc_plus_4;
      word_t        next_pc;
      word_t        instruction;
      logic         pc_write_enable;
      logic         next_pc_sel;
      logic         image_valid;
      logic         if_fetch_fault_candidate;
      fault_cause_t if_fetch_fault_cause;

      // Las acciones llegan seleccionadas y autorizadas por el control del pipeline.
      assign pc_write_enable = act_normal || act_redirect;
      assign next_pc_sel     = act_redirect;
      assign pc_plus_4       = pc + 32'd4;
      assign next_pc         = next_pc_sel ? redirect_target : pc_plus_4;
      assign debug_pc        = pc;

      // Reset y preparación inicializan PC; las demás acciones lo retienen sin enable.
      always_ff @(posedge clk) begin
        if (reset || prepare_init) begin
          pc <= '0;
        end else if (pc_write_enable) begin
          pc <= next_pc;
        end
      end

      instruction_memory #(
          .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
      ) instruction_memory (
          .clk              (clk),
          .reset            (reset),
          .read_address     (pc),
          .imem_write_index (imem_write_index),
          .imem_write_data  (imem_write_data),
          .imem_write_enable(imem_write_enable),
          .instruction      (instruction)
      );

      // El tamaño confirmado es la única fuente de validez de la imagen.
      assign image_valid = loaded_image_size_bytes != '0;
      fetch_fault_check #(
          .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
      ) fetch_fault_check (
          .pc                      (pc),
          .image_valid             (image_valid),
          .loaded_image_size_bytes (loaded_image_size_bytes),
          .if_fetch_fault_candidate(if_fetch_fault_candidate),
          .if_fetch_fault_cause    (if_fetch_fault_cause)
      );

      // El top captura solo en act_normal y conserva el PC preflanco en IF/ID.
      // IF transporta el candidato; no confirma faults ni registra otro latch.
      always_comb begin
        ifid_input.valid             = !if_fetch_fault_candidate;
        ifid_input.pc                = pc;
        ifid_input.instruction       = if_fetch_fault_candidate ? '0 : instruction;
        ifid_input.fetch_fault_valid = if_fetch_fault_candidate;
        ifid_input.fetch_fault_cause = if_fetch_fault_candidate ? if_fetch_fault_cause : '0;
      end
    end
  endgenerate
endmodule
