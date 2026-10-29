// Coordina la sesión y conserva imagen, ciclos y metadatos de fault.
module execution_control #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_IMEM_CAPACITY_BYTES,
    localparam integer IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES)
) (
    input  logic                                                  clk,
    input  logic                                                  reset,
    input  logic                                                  load_request,
    input  logic                                                  run_request,
    input  logic                                                  step_request,
    input  logic                                                  load_ok,
    input  logic                                                  load_fail,
    input  logic                                                  prepare_done,
    input  logic                                                  prepare_init,
    input  logic                                                  halt_confirm,
    input  logic                                                  act_ex_fault,
    input  logic                                                  act_id_fault,
    input  system_pkg::fault_cause_t                              ex_fault_cause,
    input  system_pkg::word_t                                     idex_pc,
    input  system_pkg::fault_cause_t                              id_fault_cause,
    input  system_pkg::word_t                                     id_fault_pc,
    input  logic                                                  ifid_next_valid,
    input  logic                                                  idex_next_valid,
    input  logic                                                  exmem_next_valid,
    input  logic                                                  memwb_next_valid,
    input  logic                           [IMAGE_SIZE_WIDTH-1:0] pending_image_size_bytes,
    output logic                                                  command_accepted,
    output logic                                                  load_start,
    output logic                                                  cpu_cycle_fire,
    output logic                                                  loader_active,
    output logic                                                  prepare_active,
    output logic                                                  drain_mode,
    output logic                                                  load_available,
    output logic                                                  program_finished,
    output logic                                                  fault_terminal,
    output system_pkg::global_state_code_t                        global_state_code,
    output logic                           [IMAGE_SIZE_WIDTH-1:0] loaded_image_size_bytes,
    output logic                                                  image_valid,
    output system_pkg::fault_cause_t                              fault_cause,
    output system_pkg::word_t                                     fault_pc,
    output logic                           [                63:0] cycle_count
);
  import system_pkg::*;

  if (!memory_capacity_valid(IMEM_CAPACITY_BYTES)) begin : g_invalid_capacity
    initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
  end else begin : g_valid_capacity
    logic         image_publish;
    logic         fault_confirm;
    logic         fault_capture_fire;
    fault_cause_t fault_cause_in;
    word_t        fault_pc_in;
    logic         pipeline_empty_next;

    // Hazards entrega acciones confirmadas; los candidatos no habilitan captura.
    assign fault_confirm      = act_ex_fault || act_id_fault;
    assign fault_capture_fire = fault_confirm;
    assign fault_cause_in     = act_ex_fault ? ex_fault_cause : id_fault_cause;
    assign fault_pc_in        = act_ex_fault ? idex_pc : id_fault_pc;

    // Usa los próximos valid del datapath, sin consultar next_state de la FSM.
    assign pipeline_empty_next =
        !(ifid_next_valid || idex_next_valid || exmem_next_valid || memwb_next_valid);
    assign image_valid = (loaded_image_size_bytes != '0);

    global_fsm global_fsm_inst (
        .clk                (clk),
        .reset              (reset),
        .load_request       (load_request),
        .run_request        (run_request),
        .step_request       (step_request),
        .load_ok            (load_ok),
        .load_fail          (load_fail),
        .prepare_done       (prepare_done),
        .halt_confirm       (halt_confirm),
        .fault_confirm      (fault_confirm),
        .pipeline_empty_next(pipeline_empty_next),
        .command_accepted   (command_accepted),
        .load_start         (load_start),
        .cpu_cycle_fire     (cpu_cycle_fire),
        .image_publish      (image_publish),
        .loader_active      (loader_active),
        .prepare_active     (prepare_active),
        .drain_mode         (drain_mode),
        .load_available     (load_available),
        .program_finished   (program_finished),
        .fault_terminal     (fault_terminal),
        .global_state_code  (global_state_code)
    );

    always_ff @(posedge clk) begin
      if (reset) begin
        loaded_image_size_bytes <= '0;
      end else if (load_start) begin
        loaded_image_size_bytes <= '0;
      end else if (image_publish) begin
        loaded_image_size_bytes <= pending_image_size_bytes;
      end
    end

    always_ff @(posedge clk) begin
      if (reset) begin
        cycle_count <= 64'd0;
      end else if (prepare_init) begin
        cycle_count <= 64'd0;
      end else if (cpu_cycle_fire) begin
        cycle_count <= cycle_count + 64'd1;
      end
    end

    // Reset invalida la interpretación por estado; no necesita borrar estos bits.
    always_ff @(posedge clk) begin
      if (!reset && fault_capture_fire) begin
        fault_cause <= fault_cause_in;
        fault_pc    <= fault_pc_in;
      end
    end
  end
endmodule
