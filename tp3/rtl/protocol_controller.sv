// Interpreta comandos UART y coordina sus respuestas.
module protocol_controller #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_IMEM_CAPACITY_BYTES,
    localparam integer IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES),
    localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(IMEM_CAPACITY_BYTES)
) (
    input  logic                          clk,
    reset,
    input  logic                          rx_empty,
    input  logic [                   7:0] r_data,
    input  logic                          rx_error_tick,
    rx_activity,
    input  logic                          response_busy,
    response_done_tick,
    input  logic                          load_available,
    prepare_active,
    program_finished,
    fault_terminal,
    input  logic                          image_valid,
    command_accepted,
    cpu_cycle_fire,
    output logic                          rd_uart,
    output logic                          response_start,
    output logic [                   7:0] response_opcode,
    response_result,
    output logic                          response_with_debug,
    output logic                          load_request,
    run_request,
    step_request,
    output logic [  IMAGE_SIZE_WIDTH-1:0] load_size_bytes,
    output logic                          load_byte_valid,
    output logic [                   7:0] load_byte_data,
    output logic [BYTE_ADDRESS_WIDTH-1:0] load_byte_offset,
    output logic                          load_last_byte,
    load_abort,
    output logic                          uart_reset_request,
    debug_read_select
);
  import system_pkg::*;

  (* fsm_encoding = "one_hot" *)logic [10:0] protocol_state;
  logic [10:0] next_state;
  logic        rx_byte_valid;

  localparam logic [10:0] WAIT_COMMAND           = 11'b00000000001;
  localparam logic [10:0] RECEIVE_LOAD_SIZE      = 11'b00000000010;
  localparam logic [10:0] WAIT_LOAD_ACCEPT_SENT  = 11'b00000000100;
  localparam logic [10:0] RECEIVE_LOAD_DATA      = 11'b00000001000;
  localparam logic [10:0] WAIT_PREP_DONE         = 11'b00000010000;
  localparam logic [10:0] WAIT_STEP_END          = 11'b00000100000;
  localparam logic [10:0] WAIT_RUN_ACCEPT_SENT   = 11'b00001000000;
  localparam logic [10:0] WAIT_RUN_END           = 11'b00010000000;
  localparam logic [10:0] WAIT_RESPONSE_SENT     = 11'b00100000000;
  localparam logic [10:0] WAIT_RESET_ACCEPT_SENT = 11'b01000000000;
  localparam logic [10:0] RECOVER_RX             = 11'b10000000000;

  always_ff @(posedge clk) begin
    if (reset) protocol_state <= WAIT_COMMAND;
    else protocol_state <= next_state;
  end

  always_comb begin
    next_state    = protocol_state;
    rd_uart       = !reset && !rx_empty;
    rx_byte_valid = !rx_empty && !rx_error_tick;

    response_start      = 1'b0;
    response_opcode     = '0;
    response_result     = '0;
    response_with_debug = 1'b0;

    load_request       = 1'b0;
    run_request        = 1'b0;
    step_request       = 1'b0;
    load_size_bytes    = '0;
    load_byte_valid    = 1'b0;
    load_byte_data     = '0;
    load_byte_offset   = '0;
    load_last_byte     = 1'b0;
    load_abort         = 1'b0;
    uart_reset_request = 1'b0;
    debug_read_select  = 1'b0;

    if (!reset) begin
      case (protocol_state)
        WAIT_COMMAND: begin
          if (rx_error_tick) begin
            next_state = RECOVER_RX;
          end else if (rx_byte_valid && r_data == CMD_CHECK_READY && !response_busy) begin
            response_start  = 1'b1;
            response_opcode = CMD_CHECK_READY;
            response_result = load_available ? RESULT_READY : RESULT_BUSY;
            next_state      = WAIT_RESPONSE_SENT;
          end
        end
        WAIT_RESPONSE_SENT: begin
          if (response_done_tick) next_state = WAIT_COMMAND;
        end
        default: begin
          // Las otras fases quedan reservadas para iteraciones posteriores.
        end
      endcase
    end
  end
endmodule
