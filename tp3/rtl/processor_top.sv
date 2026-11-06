// Integra etapas, registros interetapa y servicios de sesión del procesador.
module processor_top #(
    // Cero exige que quien instancia el top indique ambas capacidades explícitamente.
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0,
    localparam integer IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES),
    localparam integer IMEM_BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(
        IMEM_CAPACITY_BYTES
    ),
    localparam integer DMEM_BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(
        DMEM_CAPACITY_BYTES
    ),
    localparam integer IMEM_WORD_INDEX_WIDTH = system_pkg::word_index_width(IMEM_CAPACITY_BYTES)
) (
    input logic clk,
    input logic reset,
    input logic load_request,
    input logic run_request,
    input logic step_request,

    input logic load_byte_valid,
    input logic load_last_byte,
    input logic load_abort,
    input logic debug_read_select,

    input logic [       IMAGE_SIZE_WIDTH-1:0] load_size_bytes,
    input logic [                        7:0] load_byte_data,
    input logic [IMEM_BYTE_ADDRESS_WIDTH-1:0] load_byte_offset,

    input system_pkg::register_index_t                               debug_rf_addr,
    input logic                        [DMEM_BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr,

    output logic command_accepted,
    output logic load_available,
    output logic prepare_active,
    output logic program_finished,
    output logic fault_terminal,
    output logic cpu_cycle_fire,
    output logic image_valid,

    output logic                    debug_dmem_used,
    output system_pkg::word_t       debug_rf_data,
    output system_pkg::word_t       debug_pc,
    output system_pkg::word_t       debug_fault_pc,
    output logic              [7:0] debug_dmem_data,

    output system_pkg::global_state_code_t        global_state_code,
    output system_pkg::fault_cause_t              debug_fault_cause,
    output logic                           [63:0] debug_cycle_count,

    output logic        debug_ifid_valid,
    output logic [31:0] debug_ifid_pc,
    output logic [31:0] debug_ifid_instruction,
    output logic        debug_ifid_fetch_fault_valid,
    output logic [ 2:0] debug_ifid_fetch_fault_cause,

    output logic        debug_idex_valid,
    output logic [31:0] debug_idex_pc,
    output logic [31:0] debug_idex_instruction,
    output logic [ 4:0] debug_idex_rs1,
    output logic [ 4:0] debug_idex_rs2,
    output logic [ 4:0] debug_idex_rd,
    output logic [31:0] debug_idex_rs1_value,
    output logic [31:0] debug_idex_rs2_value,
    output logic [31:0] debug_idex_immediate,
    output logic [ 5:0] debug_idex_alu_op,
    output logic        debug_idex_alu_src,
    output logic [ 1:0] debug_idex_result_sel,
    output logic [ 2:0] debug_idex_flow_op,
    output logic [ 3:0] debug_idex_mem_op,
    output logic        debug_idex_reg_write,

    output logic        debug_exmem_valid,
    output logic [31:0] debug_exmem_pc,
    output logic [31:0] debug_exmem_instruction,
    output logic [ 4:0] debug_exmem_rd,
    output logic        debug_exmem_reg_write,
    output logic [ 3:0] debug_exmem_mem_op,
    output logic [31:0] debug_exmem_ex_result,
    output logic [31:0] debug_exmem_store_data,

    output logic        debug_memwb_valid,
    output logic [31:0] debug_memwb_pc,
    output logic [31:0] debug_memwb_instruction,
    output logic [ 4:0] debug_memwb_rd,
    output logic        debug_memwb_reg_write,
    output logic [31:0] debug_memwb_wb_value
);
  import system_pkg::*;

  if (!memory_capacity_valid(
          IMEM_CAPACITY_BYTES
      ) || !memory_capacity_valid(
          DMEM_CAPACITY_BYTES
      )) begin : g_invalid_capacity
    initial $fatal(1, "%s", CONFIG_INVALID_CAPACITY);
  end else begin : g_valid_capacity
    // *_input es la salida combinacional de cada etapa; los otros buses son sus latches.
    if_id_t                                        ifid_input;
    if_id_t                                        ifid;
    id_ex_t                                        idex_input;
    id_ex_t                                        idex;
    ex_mem_t                                       exmem_input;
    ex_mem_t                                       exmem;
    mem_wb_t                                       memwb_input;
    mem_wb_t                                       memwb;
    word_t                                         redirect_target;
    word_t                                         id_fault_pc;
    word_t                                         rf_write_data;
    word_t                                         imem_write_data;
    register_index_t                               rf_write_addr;
    fault_cause_t                                  id_fault_cause;
    fault_cause_t                                  ex_fault_cause;
    logic                                          load_start;
    logic                                          loader_active;
    logic                                          load_ok;
    logic                                          load_fail;
    logic                                          prepare_done;
    logic                                          prepare_init;
    logic                                          prepare_dmem_clear;
    logic                                          drain_mode;
    logic                                          id_fault_candidate;
    logic                                          ex_fault_candidate;
    logic                                          ex_halt_candidate;
    logic                                          redirect_requested;
    logic                                          load_use_stall;
    logic                                          rf_write_fire;
    logic                                          bypass_rs1;
    logic                                          bypass_rs2;
    logic                                          imem_write_enable;
    logic                                          ifid_next_valid;
    logic                                          idex_next_valid;
    logic                                          exmem_next_valid;
    logic                                          memwb_next_valid;
    logic                                          ifid_capture;
    logic                                          ifid_hold;
    logic                                          ifid_invalidate;
    logic                                          idex_capture;
    logic                                          idex_bubble;
    logic                                          exmem_capture;
    logic                                          exmem_invalidate;
    logic                                          memwb_capture;
    logic                                          act_ex_fault;
    logic                                          act_halt;
    logic                                          act_redirect;
    logic                                          act_id_fault;
    logic                                          act_load_use;
    logic                                          act_normal;
    logic                                          act_drain_load_use;
    logic                                          act_drain_advance;
    logic            [                        7:0] actions;
    logic            [       IMAGE_SIZE_WIDTH-1:0] pending_image_size_bytes;
    logic            [       IMAGE_SIZE_WIDTH-1:0] loaded_image_size_bytes;
    logic            [  IMEM_WORD_INDEX_WIDTH-1:0] imem_write_index;
    logic            [DMEM_BYTE_ADDRESS_WIDTH-1:0] prepare_dmem_addr;

    // Hazards confirma como máximo una acción por ciclo; fuera de cpu_cycle_fire son cero.
    assign actions = {
      act_ex_fault,
      act_halt,
      act_redirect,
      act_id_fault,
      act_load_use,
      act_normal,
      act_drain_load_use,
      act_drain_advance
    };

    // Las acciones dependen del estado actual; next.valid solo alimenta la terminación.
    // Load-use retiene IF/ID e inserta una burbuja en ID/EX mientras avanza el productor.
    assign ifid_capture = act_normal;
    assign ifid_hold = act_load_use || act_drain_load_use;
    assign ifid_invalidate = act_ex_fault || act_halt || act_redirect || act_id_fault ||
        act_drain_advance;
    assign idex_capture = act_normal || act_drain_advance;
    assign idex_bubble = act_ex_fault || act_halt || act_redirect || act_id_fault || act_load_use ||
        act_drain_load_use;
    // Un redirect o fault de ID conserva la instrucción de EX; un fault de EX o HALT la quita.
    assign exmem_capture = act_redirect || act_id_fault || act_load_use || act_normal ||
        act_drain_load_use || act_drain_advance;
    assign exmem_invalidate = act_ex_fault || act_halt;
    // MEM/WB consume las instrucciones anteriores incluso durante el drenaje del pipeline.
    assign memwb_capture = |actions;

    // Las colisiones internas son errores de integración, sin una causa arquitectónica nueva.
    always_ff @(posedge clk) begin
      if (!reset) begin
        assert (!(imem_write_enable && (act_normal || act_redirect)))
        else $fatal(1, "IMEM_OWNERSHIP_CONFLICT");
        assert (!(debug_read_select && (cpu_cycle_fire || prepare_dmem_clear)))
        else $fatal(1, "DMEM_OWNERSHIP_CONFLICT");
      end
    end

    // Control de ejecución: coordina LOAD/RUN/STEP y conserva ciclos y metadatos de falla.
    execution_control #(
        .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
    ) execution_control_inst (
        .clk                     (clk),
        .reset                   (reset),
        .load_request            (load_request),
        .run_request             (run_request),
        .step_request            (step_request),
        .load_ok                 (load_ok),
        .load_fail               (load_fail),
        .prepare_done            (prepare_done),
        .prepare_init            (prepare_init),
        .act_ex_fault            (act_ex_fault),
        .act_id_fault            (act_id_fault),
        .ex_fault_cause          (ex_fault_cause),
        .id_fault_cause          (id_fault_cause),
        .id_fault_pc             (id_fault_pc),
        .ifid_next_valid         (ifid_next_valid),
        .idex_next_valid         (idex_next_valid),
        .exmem_next_valid        (exmem_next_valid),
        .memwb_next_valid        (memwb_next_valid),
        .pending_image_size_bytes(pending_image_size_bytes),
        .command_accepted        (command_accepted),
        .load_start              (load_start),
        .cpu_cycle_fire          (cpu_cycle_fire),
        .loader_active           (loader_active),
        .prepare_active          (prepare_active),
        .drain_mode              (drain_mode),
        .load_available          (load_available),
        .program_finished        (program_finished),
        .fault_terminal          (fault_terminal),
        .global_state_code       (global_state_code),
        .loaded_image_size_bytes (loaded_image_size_bytes),
        .image_valid             (image_valid),
        .halt_confirm            (act_halt),
        .idex_pc                 (idex.pc),
        .fault_cause             (debug_fault_cause),
        .fault_pc                (debug_fault_pc),
        .cycle_count             (debug_cycle_count)
    );

    // Loader: recibe los bytes del programa y arma las palabras que se escriben en IMEM.
    loader #(
        .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
    ) loader_inst (
        .clk                     (clk),
        .reset                   (reset),
        .loader_active           (loader_active),
        .load_start              (load_start),
        .load_size_bytes         (load_size_bytes),
        .load_byte_valid         (load_byte_valid),
        .load_byte_data          (load_byte_data),
        .load_byte_offset        (load_byte_offset),
        .load_last_byte          (load_last_byte),
        .load_abort              (load_abort),
        .imem_write_index        (imem_write_index),
        .imem_write_data         (imem_write_data),
        .imem_write_enable       (imem_write_enable),
        .load_ok                 (load_ok),
        .load_fail               (load_fail),
        .pending_image_size_bytes(pending_image_size_bytes)
    );

    // Preparación de sesión: inicializa PC/RF/latches y limpia las marcas de uso de DMEM.
    session_preparation #(
        .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
    ) session_preparation_inst (
        .clk               (clk),
        .reset             (reset),
        .prepare_active    (prepare_active),
        .prepare_init      (prepare_init),
        .prepare_dmem_clear(prepare_dmem_clear),
        .prepare_dmem_addr (prepare_dmem_addr),
        .prepare_done      (prepare_done)
    );

    // Control de hazards: prioriza fallas, HALT, saltos y load-use para elegir la acción del ciclo.
    // Durante el drenaje decide si retener por load-use o avanzar las instrucciones pendientes.
    pipeline_hazard_control pipeline_hazard_control_inst (
        .cpu_cycle_fire    (cpu_cycle_fire),
        .drain_mode        (drain_mode),
        .ex_fault_candidate(ex_fault_candidate),
        .ex_halt_candidate (ex_halt_candidate),
        .redirect_requested(redirect_requested),
        .id_fault_candidate(id_fault_candidate),
        .load_use_stall    (load_use_stall),
        .act_ex_fault      (act_ex_fault),
        .act_halt          (act_halt),
        .act_redirect      (act_redirect),
        .act_id_fault      (act_id_fault),
        .act_load_use      (act_load_use),
        .act_normal        (act_normal),
        .act_drain_load_use(act_drain_load_use),
        .act_drain_advance (act_drain_advance)
    );

    // Etapa IF: mantiene el PC y obtiene de IMEM la instrucción y su posible falla de fetch.
    if_stage #(
        .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
    ) if_stage_inst (
        .clk                    (clk),
        .reset                  (reset),
        .prepare_init           (prepare_init),
        .redirect_target        (redirect_target),
        .loaded_image_size_bytes(loaded_image_size_bytes),
        .imem_write_index       (imem_write_index),
        .imem_write_data        (imem_write_data),
        .imem_write_enable      (imem_write_enable),
        .debug_pc               (debug_pc),
        .act_normal             (act_normal),
        .act_redirect           (act_redirect),
        .ifid_input             (ifid_input)
    );

    // Etapa ID: decodifica, lee el banco de registros y detecta instrucciones ilegales y load-use.
    // Recibe de WB la escritura y el bypass para obtener los operandos actualizados.
    id_stage id_stage_inst (
        .clk               (clk),
        .reset             (reset),
        .prepare_init      (prepare_init),
        .ifid              (ifid),
        .rf_write_addr     (rf_write_addr),
        .rf_write_data     (rf_write_data),
        .rf_write_fire     (rf_write_fire),
        .bypass_rs1        (bypass_rs1),
        .bypass_rs2        (bypass_rs2),
        .debug_read_select (debug_read_select),
        .debug_rf_addr     (debug_rf_addr),
        .idex_input        (idex_input),
        .id_fault_candidate(id_fault_candidate),
        .id_fault_cause    (id_fault_cause),
        .id_fault_pc       (id_fault_pc),
        .load_use_stall    (load_use_stall),
        .debug_rf_data     (debug_rf_data),
        .idex_valid        (idex.valid),
        .idex_rd           (idex.rd),
        .idex_mem_op       (idex.mem_op)
    );

    // Etapa EX: calcula resultados y direcciones, y produce candidatos de salto, HALT o falla.
    // Recibe EX/MEM y MEM/WB para resolver el forwarding de operandos.
    ex_stage #(
        .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
    ) ex_stage_inst (
        .idex              (idex),
        .exmem_producer    (exmem),
        .memwb_producer    (memwb),
        .exmem_input       (exmem_input),
        .ex_fault_candidate(ex_fault_candidate),
        .ex_fault_cause    (ex_fault_cause),
        .ex_halt_candidate (ex_halt_candidate),
        .redirect_requested(redirect_requested),
        .redirect_target   (redirect_target)
    );

    // Etapa MEM: realiza las lecturas y escrituras de DMEM y entrega el resultado hacia WB.
    // También atiende la limpieza de sesión y las lecturas de Debug de esa memoria.
    mem_stage #(
        .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
    ) mem_stage_inst (
        .clk               (clk),
        .reset             (reset),
        .exmem             (exmem),
        .cpu_cycle_fire    (cpu_cycle_fire),
        .prepare_dmem_clear(prepare_dmem_clear),
        .prepare_dmem_addr (prepare_dmem_addr),
        .debug_read_select (debug_read_select),
        .debug_dmem_addr   (debug_dmem_addr),
        .debug_dmem_data   (debug_dmem_data),
        .debug_dmem_used   (debug_dmem_used),
        .memwb_input       (memwb_input)
    );

    // Etapa WB: entrega el valor y la habilitación de escritura al banco de registros en ID.
    // Genera además las selecciones de bypass para las dos fuentes de la instrucción en ID.
    wb_stage wb_stage_inst (
        .memwb            (memwb),
        .cpu_cycle_fire   (cpu_cycle_fire),
        .rf_write_register(rf_write_addr),
        .rf_write_data    (rf_write_data),
        .rf_write_fire    (rf_write_fire),
        .bypass_rs1       (bypass_rs1),
        .bypass_rs2       (bypass_rs2),
        .ifid_rs1         (ifid.instruction[19:15]),
        .ifid_rs2         (ifid.instruction[24:20])
    );

    // Registro IF/ID: conserva PC, instrucción y falla de fetch entre la búsqueda y la decodificación.
    if_id_register ifid_register (
        .clk         (clk),
        .reset       (reset),
        .prepare_init(prepare_init),
        .capture     (ifid_capture),
        .data_in     (ifid_input),
        .data_out    (ifid),
        .valid_next  (ifid_next_valid),
        .hold        (ifid_hold),
        .invalidate  (ifid_invalidate)
    );

    // Registro ID/EX: conserva operandos, inmediato y controles de la instrucción que ejecutará EX.
    id_ex_register idex_register (
        .clk         (clk),
        .reset       (reset),
        .prepare_init(prepare_init),
        .capture     (idex_capture),
        .data_in     (idex_input),
        .data_out    (idex),
        .valid_next  (idex_next_valid),
        .bubble      (idex_bubble)
    );

    // Registro EX/MEM: conserva el resultado de EX y el dato de store para el acceso a memoria.
    ex_mem_register exmem_register (
        .clk         (clk),
        .reset       (reset),
        .prepare_init(prepare_init),
        .capture     (exmem_capture),
        .data_in     (exmem_input),
        .data_out    (exmem),
        .valid_next  (exmem_next_valid),
        .invalidate  (exmem_invalidate)
    );

    // Registro MEM/WB: conserva el destino y el valor final que WB devolverá al banco de registros.
    mem_wb_register memwb_register (
        .clk         (clk),
        .reset       (reset),
        .prepare_init(prepare_init),
        .capture     (memwb_capture),
        .data_in     (memwb_input),
        .data_out    (memwb),
        .valid_next  (memwb_next_valid)
    );

    // Debug expone los latches actuales directamente, sin copias ni registros de snapshot.
    // Los campos de un latch solo representan una instrucción activa cuando valid es uno.
    assign debug_ifid_valid             = ifid.valid;
    assign debug_ifid_pc                = ifid.pc;
    assign debug_ifid_instruction       = ifid.instruction;
    assign debug_ifid_fetch_fault_valid = ifid.fetch_fault_valid;
    assign debug_ifid_fetch_fault_cause = ifid.fetch_fault_cause;
    assign debug_idex_valid             = idex.valid;
    assign debug_idex_pc                = idex.pc;
    assign debug_idex_instruction       = idex.instruction;
    assign debug_idex_rs1               = idex.rs1;
    assign debug_idex_rs2               = idex.rs2;
    assign debug_idex_rd                = idex.rd;
    assign debug_idex_rs1_value         = idex.rs1_value;
    assign debug_idex_rs2_value         = idex.rs2_value;
    assign debug_idex_immediate         = idex.immediate;
    assign debug_idex_alu_op            = idex.alu_op;
    assign debug_idex_alu_src           = idex.alu_src;
    assign debug_idex_result_sel        = idex.result_sel;
    assign debug_idex_flow_op           = idex.flow_op;
    assign debug_idex_mem_op            = idex.mem_op;
    assign debug_idex_reg_write         = idex.reg_write;
    assign debug_exmem_valid            = exmem.valid;
    assign debug_exmem_pc               = exmem.pc;
    assign debug_exmem_instruction      = exmem.instruction;
    assign debug_exmem_rd               = exmem.rd;
    assign debug_exmem_reg_write        = exmem.reg_write;
    assign debug_exmem_mem_op           = exmem.mem_op;
    assign debug_exmem_ex_result        = exmem.ex_result;
    assign debug_exmem_store_data       = exmem.store_data;
    assign debug_memwb_valid            = memwb.valid;
    assign debug_memwb_pc               = memwb.pc;
    assign debug_memwb_instruction      = memwb.instruction;
    assign debug_memwb_rd               = memwb.rd;
    assign debug_memwb_reg_write        = memwb.reg_write;
    assign debug_memwb_wb_value         = memwb.wb_value;
  end
endmodule
