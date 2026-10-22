// Conserva la fase de sesión y autoriza comandos y ciclos desde el estado actual.
module global_fsm (
    input  logic                           clk,
    input  logic                           reset,
    input  logic                           load_request,
    input  logic                           run_request,
    input  logic                           step_request,
    input  logic                           load_ok,
    input  logic                           load_fail,
    input  logic                           prepare_done,
    input  logic                           halt_confirm,
    input  logic                           fault_confirm,
    input  logic                           pipeline_empty_next,
    output logic                           command_accepted,
    output logic                           load_start,
    output logic                           cpu_cycle_fire,
    output logic                           image_publish,
    output logic                           loader_active,
    output logic                           prepare_active,
    output logic                           drain_mode,
    output logic                           load_available,
    output logic                           program_finished,
    output logic                           fault_terminal,
    output system_pkg::global_state_code_t global_state_code
);
  import system_pkg::*;

  // Un bit por fase; la modalidad de drain y la orden pendiente viven en el estado.
  localparam logic [13:0] STATE_NO_IMAGE         = 14'b00000000000001;
  localparam logic [13:0] STATE_LOADING          = 14'b00000000000010;
  localparam logic [13:0] STATE_PREPARING_READY  = 14'b00000000000100;
  localparam logic [13:0] STATE_READY            = 14'b00000000001000;
  localparam logic [13:0] STATE_RUNNING          = 14'b00000000010000;
  localparam logic [13:0] STATE_STEPPING         = 14'b00000000100000;
  localparam logic [13:0] STATE_HALT_DRAIN_AUTO  = 14'b00000001000000;
  localparam logic [13:0] STATE_HALT_DRAIN_STEP  = 14'b00000010000000;
  localparam logic [13:0] STATE_FAULT_DRAIN_AUTO = 14'b00000100000000;
  localparam logic [13:0] STATE_FAULT_DRAIN_STEP = 14'b00001000000000;
  localparam logic [13:0] STATE_FINISHED         = 14'b00010000000000;
  localparam logic [13:0] STATE_FAULT            = 14'b00100000000000;
  localparam logic [13:0] STATE_PREPARING_RUN    = 14'b01000000000000;
  localparam logic [13:0] STATE_PREPARING_STEP   = 14'b10000000000000;

  // Controles en orden: aceptación, inicio LOAD, ciclo CPU, publicación de imagen.
  localparam logic [3:0] CTRL_NONE         = 4'b0_0_0_0;
  localparam logic [3:0] CTRL_LOAD         = 4'b1_1_0_0;
  localparam logic [3:0] CTRL_ACCEPT_CYCLE = 4'b1_0_1_0;
  localparam logic [3:0] CTRL_ACCEPT_ONLY  = 4'b1_0_0_0;
  localparam logic [3:0] CTRL_CYCLE_ONLY   = 4'b0_0_1_0;
  localparam logic [3:0] CTRL_PUBLISH      = 4'b0_0_0_1;

  (* fsm_encoding = "one_hot" *)logic [13:0] global_state;
  logic [13:0] next_state;
  logic [ 3:0] authorization_controls;
  logic [18:0] authorization_inputs;
  logic [23:0] transition_inputs;

  // El reloj funcional actualiza la FSM incluso durante carga, preparación y HOLD.
  always_ff @(posedge clk) begin
    global_state <= next_state;
  end

  assign authorization_inputs = {
    global_state, reset, load_request, step_request, run_request, prepare_done
  };
  assign transition_inputs = {
    global_state,
    reset,
    load_request,
    step_request,
    run_request,
    load_ok,
    load_fail,
    prepare_done,
    fault_confirm,
    halt_confirm,
    pipeline_empty_next
  };
  assign {command_accepted, load_start, cpu_cycle_fire, image_publish} = authorization_controls;

  always_comb begin
    next_state             = global_state;
    authorization_controls = CTRL_NONE;
    loader_active          = 1'b0;
    prepare_active         = 1'b0;
    drain_mode             = 1'b0;
    load_available         = 1'b0;
    program_finished       = 1'b0;
    fault_terminal         = 1'b0;
    global_state_code      = STATE_CODE_NO_IMAGE;
    // Salidas Moore.
    case (global_state)
      STATE_NO_IMAGE: begin
        load_available    = 1'b1;
        global_state_code = STATE_CODE_NO_IMAGE;
      end
      STATE_LOADING: begin
        loader_active     = 1'b1;
        global_state_code = STATE_CODE_LOADING;
      end
      STATE_PREPARING_READY: begin
        prepare_active    = 1'b1;
        global_state_code = STATE_CODE_PREPARING_READY;
      end
      STATE_READY: begin
        load_available    = 1'b1;
        global_state_code = STATE_CODE_READY;
      end
      STATE_RUNNING: begin
        global_state_code = STATE_CODE_RUNNING;
      end
      STATE_STEPPING: begin
        load_available    = 1'b1;
        global_state_code = STATE_CODE_STEPPING;
      end
      STATE_HALT_DRAIN_AUTO: begin
        drain_mode        = 1'b1;
        global_state_code = STATE_CODE_HALT_DRAIN_AUTO;
      end
      STATE_HALT_DRAIN_STEP: begin
        drain_mode        = 1'b1;
        load_available    = 1'b1;
        global_state_code = STATE_CODE_HALT_DRAIN_STEP;
      end
      STATE_FAULT_DRAIN_AUTO: begin
        drain_mode        = 1'b1;
        global_state_code = STATE_CODE_FAULT_DRAIN_AUTO;
      end
      STATE_FAULT_DRAIN_STEP: begin
        drain_mode        = 1'b1;
        load_available    = 1'b1;
        global_state_code = STATE_CODE_FAULT_DRAIN_STEP;
      end
      STATE_FINISHED: begin
        load_available    = 1'b1;
        program_finished  = 1'b1;
        global_state_code = STATE_CODE_FINISHED;
      end
      STATE_FAULT: begin
        load_available    = 1'b1;
        fault_terminal    = 1'b1;
        global_state_code = STATE_CODE_FAULT;
      end
      STATE_PREPARING_RUN: begin
        prepare_active    = 1'b1;
        global_state_code = STATE_CODE_PREPARING_RUN;
      end
      STATE_PREPARING_STEP: begin
        prepare_active    = 1'b1;
        global_state_code = STATE_CODE_PREPARING_STEP;
      end
      default: begin
        global_state_code = STATE_CODE_NO_IMAGE;
      end
    endcase

    // Autorización: estado | reset_LOAD_STEP_RUN_done.
    // No consulta confirmaciones ni próximos valid del pipeline.
    // verilog_format: off
    casez (authorization_inputs)
      {14'b??????????????,     5'b1_?_?_?_?}: authorization_controls = CTRL_NONE;

      // LOAD elegible domina las solicitudes de ejecución de las filas siguientes.
      {STATE_NO_IMAGE,         5'b0_1_?_?_?}: authorization_controls = CTRL_LOAD;
      {STATE_READY,            5'b0_1_?_?_?}: authorization_controls = CTRL_LOAD;
      {STATE_STEPPING,         5'b0_1_?_?_?}: authorization_controls = CTRL_LOAD;
      {STATE_HALT_DRAIN_STEP,  5'b0_1_?_?_?}: authorization_controls = CTRL_LOAD;
      {STATE_FAULT_DRAIN_STEP, 5'b0_1_?_?_?}: authorization_controls = CTRL_LOAD;
      {STATE_FINISHED,         5'b0_1_?_?_?}: authorization_controls = CTRL_LOAD;
      {STATE_FAULT,            5'b0_1_?_?_?}: authorization_controls = CTRL_LOAD;

      // STEP o RUN ejecuta un ciclo en una sesión preparada o detenida.
      {STATE_READY,            5'b0_?_1_?_?}: authorization_controls = CTRL_ACCEPT_CYCLE;
      {STATE_READY,            5'b0_?_0_1_?}: authorization_controls = CTRL_ACCEPT_CYCLE;
      {STATE_STEPPING,         5'b0_?_1_?_?}: authorization_controls = CTRL_ACCEPT_CYCLE;
      {STATE_STEPPING,         5'b0_?_0_1_?}: authorization_controls = CTRL_ACCEPT_CYCLE;
      {STATE_HALT_DRAIN_STEP,  5'b0_?_1_?_?}: authorization_controls = CTRL_ACCEPT_CYCLE;
      {STATE_HALT_DRAIN_STEP,  5'b0_?_0_1_?}: authorization_controls = CTRL_ACCEPT_CYCLE;
      {STATE_FAULT_DRAIN_STEP, 5'b0_?_1_?_?}: authorization_controls = CTRL_ACCEPT_CYCLE;
      {STATE_FAULT_DRAIN_STEP, 5'b0_?_0_1_?}: authorization_controls = CTRL_ACCEPT_CYCLE;

      // Desde un terminal solo se acepta; la preparación conserva la orden.
      {STATE_FINISHED,         5'b0_?_1_?_?}: authorization_controls = CTRL_ACCEPT_ONLY;
      {STATE_FINISHED,         5'b0_?_0_1_?}: authorization_controls = CTRL_ACCEPT_ONLY;
      {STATE_FAULT,            5'b0_?_1_?_?}: authorization_controls = CTRL_ACCEPT_ONLY;
      {STATE_FAULT,            5'b0_?_0_1_?}: authorization_controls = CTRL_ACCEPT_ONLY;

      // Ciclo automático o primer ciclo de la imagen reutilizada.
      {STATE_RUNNING,          5'b0_?_?_?_?}: authorization_controls = CTRL_CYCLE_ONLY;
      {STATE_HALT_DRAIN_AUTO,  5'b0_?_?_?_?}: authorization_controls = CTRL_CYCLE_ONLY;
      {STATE_FAULT_DRAIN_AUTO, 5'b0_?_?_?_?}: authorization_controls = CTRL_CYCLE_ONLY;
      {STATE_PREPARING_RUN,    5'b0_?_?_?_1}: authorization_controls = CTRL_CYCLE_ONLY;
      {STATE_PREPARING_STEP,   5'b0_?_?_?_1}: authorization_controls = CTRL_CYCLE_ONLY;

      {STATE_PREPARING_READY,  5'b0_?_?_?_1}: authorization_controls = CTRL_PUBLISH;
      default: authorization_controls = CTRL_NONE;
    endcase
    // verilog_format: on

    // Los resultados solo seleccionan el destino del ciclo ya autorizado.
    // Columnas: estado | reset_LOAD_STEP_RUN | ok_fail_done | fault_halt_empty.
    // verilog_format: off
    casez (transition_inputs)
      // Prioridades globales: RESET > LOAD elegible > reglas del estado.
      {14'b??????????????,     4'b1_?_?_?, 3'b???,   3'b???  }: next_state = STATE_NO_IMAGE;
      {STATE_NO_IMAGE,         4'b0_1_?_?, 3'b???,   3'b???  }: next_state = STATE_LOADING;
      {STATE_READY,            4'b0_1_?_?, 3'b???,   3'b???  }: next_state = STATE_LOADING;
      {STATE_STEPPING,         4'b0_1_?_?, 3'b???,   3'b???  }: next_state = STATE_LOADING;
      {STATE_HALT_DRAIN_STEP,  4'b0_1_?_?, 3'b???,   3'b???  }: next_state = STATE_LOADING;
      {STATE_FAULT_DRAIN_STEP, 4'b0_1_?_?, 3'b???,   3'b???  }: next_state = STATE_LOADING;
      {STATE_FINISHED,         4'b0_1_?_?, 3'b???,   3'b???  }: next_state = STATE_LOADING;
      {STATE_FAULT,            4'b0_1_?_?, 3'b???,   3'b???  }: next_state = STATE_LOADING;

      // NO_IMAGE: Espera una imagen; RUN y STEP no tienen efecto.
      {STATE_NO_IMAGE,         4'b0_?_?_?, 3'b???,   3'b???  }: next_state = STATE_NO_IMAGE;

      // LOADING
      {STATE_LOADING,          4'b0_?_?_?, 3'b1_?_?, 3'b???  }: next_state = STATE_PREPARING_READY;
      {STATE_LOADING,          4'b0_?_?_?, 3'b0_1_?, 3'b???  }: next_state = STATE_NO_IMAGE;
      {STATE_LOADING,          4'b0_?_?_?, 3'b0_0_?, 3'b???  }: next_state = STATE_LOADING;

      // PREPARING_READY: Publica la imagen después de terminar preparación.
      {STATE_PREPARING_READY,  4'b0_?_?_?, 3'b?_?_1, 3'b???  }: next_state = STATE_READY;
      {STATE_PREPARING_READY,  4'b0_?_?_?, 3'b?_?_0, 3'b???  }: next_state = STATE_PREPARING_READY;

      // READY: El primer ciclo solo realiza fetch; STEP domina RUN.
      {STATE_READY,            4'b0_?_1_?, 3'b???,   3'b???  }: next_state = STATE_STEPPING;
      {STATE_READY,            4'b0_?_0_1, 3'b???,   3'b???  }: next_state = STATE_RUNNING;
      {STATE_READY,            4'b0_?_0_0, 3'b???,   3'b???  }: next_state = STATE_READY;

      // RUNNING: fault tiene prioridad sobre halt.
      {STATE_RUNNING,          4'b0_?_?_?, 3'b???,   3'b1_?_1}: next_state = STATE_FAULT;
      {STATE_RUNNING,          4'b0_?_?_?, 3'b???,   3'b1_?_0}: next_state = STATE_FAULT_DRAIN_AUTO;
      {STATE_RUNNING,          4'b0_?_?_?, 3'b???,   3'b0_1_1}: next_state = STATE_FINISHED;
      {STATE_RUNNING,          4'b0_?_?_?, 3'b???,   3'b0_1_0}: next_state = STATE_HALT_DRAIN_AUTO;
      {STATE_RUNNING,          4'b0_?_?_?, 3'b???,   3'b???  }: next_state = STATE_RUNNING;

      // STEPPING: Una orden ejecuta un ciclo; su resultado decide terminal o drain.
      {STATE_STEPPING,         4'b0_?_1_?, 3'b???,   3'b1_?_1}: next_state = STATE_FAULT;
      {STATE_STEPPING,         4'b0_?_0_1, 3'b???,   3'b1_?_1}: next_state = STATE_FAULT;
      {STATE_STEPPING,         4'b0_?_0_1, 3'b???,   3'b1_?_0}: next_state = STATE_FAULT_DRAIN_AUTO;
      {STATE_STEPPING,         4'b0_?_1_?, 3'b???,   3'b1_?_0}: next_state = STATE_FAULT_DRAIN_STEP;
      {STATE_STEPPING,         4'b0_?_1_?, 3'b???,   3'b0_1_1}: next_state = STATE_FINISHED;
      {STATE_STEPPING,         4'b0_?_0_1, 3'b???,   3'b0_1_1}: next_state = STATE_FINISHED;
      {STATE_STEPPING,         4'b0_?_0_1, 3'b???,   3'b0_1_0}: next_state = STATE_HALT_DRAIN_AUTO;
      {STATE_STEPPING,         4'b0_?_1_?, 3'b???,   3'b0_1_0}: next_state = STATE_HALT_DRAIN_STEP;
      {STATE_STEPPING,         4'b0_?_1_?, 3'b???,   3'b???  }: next_state = STATE_STEPPING;
      {STATE_STEPPING,         4'b0_?_0_1, 3'b???,   3'b???  }: next_state = STATE_RUNNING;
      {STATE_STEPPING,         4'b0_?_0_0, 3'b???,   3'b???  }: next_state = STATE_STEPPING;

      // HALT_DRAIN_AUTO: El único WB remanente termina en este ciclo.
      {STATE_HALT_DRAIN_AUTO,  4'b0_?_?_?, 3'b???,   3'b???  }: next_state = STATE_FINISHED;

      // HALT_DRAIN_STEP: Espera una orden; el drain legal termina en un ciclo.
      {STATE_HALT_DRAIN_STEP,  4'b0_?_1_?, 3'b???,   3'b?_?_1}: next_state = STATE_FINISHED;
      {STATE_HALT_DRAIN_STEP,  4'b0_?_0_1, 3'b???,   3'b?_?_1}: next_state = STATE_FINISHED;
      // Con empty=0 forzado, conserva STEP o cambia a AUTO según la orden.
      {STATE_HALT_DRAIN_STEP,  4'b0_?_1_?, 3'b???,   3'b?_?_0}: next_state = STATE_HALT_DRAIN_STEP;
      {STATE_HALT_DRAIN_STEP,  4'b0_?_0_1, 3'b???,   3'b?_?_0}: next_state = STATE_HALT_DRAIN_AUTO;
      {STATE_HALT_DRAIN_STEP,  4'b0_?_0_0, 3'b???,   3'b???  }: next_state = STATE_HALT_DRAIN_STEP;

      // FAULT_DRAIN_AUTO: Avanza automáticamente hasta consumir el último válido.
      {STATE_FAULT_DRAIN_AUTO, 4'b0_?_?_?, 3'b???,   3'b?_?_1}: next_state = STATE_FAULT;
      {STATE_FAULT_DRAIN_AUTO, 4'b0_?_?_?, 3'b???,   3'b?_?_0}: next_state = STATE_FAULT_DRAIN_AUTO;

      // FAULT_DRAIN_STEP: RUN convierte el resto a AUTO; STEP avanza un ciclo.
      {STATE_FAULT_DRAIN_STEP, 4'b0_?_1_?, 3'b???,   3'b?_?_1}: next_state = STATE_FAULT;
      {STATE_FAULT_DRAIN_STEP, 4'b0_?_0_1, 3'b???,   3'b?_?_1}: next_state = STATE_FAULT;
      {STATE_FAULT_DRAIN_STEP, 4'b0_?_1_?, 3'b???,   3'b?_?_0}: next_state = STATE_FAULT_DRAIN_STEP;
      {STATE_FAULT_DRAIN_STEP, 4'b0_?_0_1, 3'b???,   3'b?_?_0}: next_state = STATE_FAULT_DRAIN_AUTO;
      {STATE_FAULT_DRAIN_STEP, 4'b0_?_0_0, 3'b???,   3'b???  }: next_state = STATE_FAULT_DRAIN_STEP;

      // FINISHED: Conserva la imagen; otra ejecución requiere preparación.
      {STATE_FINISHED,         4'b0_?_1_?, 3'b???,   3'b???  }: next_state = STATE_PREPARING_STEP;
      {STATE_FINISHED,         4'b0_?_0_1, 3'b???,   3'b???  }: next_state = STATE_PREPARING_RUN;
      {STATE_FINISHED,         4'b0_?_0_0, 3'b???,   3'b???  }: next_state = STATE_FINISHED;

      // FAULT: Retiene el terminal hasta LOAD, RESET o una nueva ejecución.
      {STATE_FAULT,            4'b0_?_1_?, 3'b???,   3'b???  }: next_state = STATE_PREPARING_STEP;
      {STATE_FAULT,            4'b0_?_0_1, 3'b???,   3'b???  }: next_state = STATE_PREPARING_RUN;
      {STATE_FAULT,            4'b0_?_0_0, 3'b???,   3'b???  }: next_state = STATE_FAULT;

      // PREPARING_RUN: El fin de preparación autoriza el primer ciclo continuo.
      {STATE_PREPARING_RUN,    4'b0_?_?_?, 3'b?_?_1, 3'b???  }: next_state = STATE_RUNNING;
      {STATE_PREPARING_RUN,    4'b0_?_?_?, 3'b?_?_0, 3'b???  }: next_state = STATE_PREPARING_RUN;

      // PREPARING_STEP: El fin de preparación autoriza un único primer ciclo.
      {STATE_PREPARING_STEP,   4'b0_?_?_?, 3'b?_?_1, 3'b???  }: next_state = STATE_STEPPING;
      {STATE_PREPARING_STEP,   4'b0_?_?_?, 3'b?_?_0, 3'b???  }: next_state = STATE_PREPARING_STEP;

      default: next_state = STATE_NO_IMAGE;
    endcase
    // verilog_format: on
  end
endmodule
