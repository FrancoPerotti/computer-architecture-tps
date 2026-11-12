// Interpreta comandos UART y coordina sus respuestas.
module protocol_controller #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_IMEM_CAPACITY_BYTES,
    localparam integer IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES),
    localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(IMEM_CAPACITY_BYTES)
) (
    input  logic                          clk,
    input  logic                          reset,
    input  logic                          rx_empty,
    input  logic [                   7:0] r_data,
    input  logic                          rx_error_tick,
    input  logic                          rx_activity,
    input  logic                          response_busy,
    input  logic                          response_done_tick,
    input  logic                          load_available,
    input  logic                          prepare_active,
    input  logic                          program_finished,
    input  logic                          fault_terminal,
    input  logic                          image_valid,
    input  logic                          command_accepted,
    input  logic                          cpu_cycle_fire,
    output logic                          rd_uart,
    output logic                          response_start,
    output logic [                   7:0] response_opcode,
    output logic [                   7:0] response_result,
    output logic                          response_with_debug,
    output logic                          load_request,
    output logic                          run_request,
    output logic                          step_request,
    output logic [  IMAGE_SIZE_WIDTH-1:0] load_size_bytes,
    output logic                          load_byte_valid,
    output logic [                   7:0] load_byte_data,
    output logic [BYTE_ADDRESS_WIDTH-1:0] load_byte_offset,
    output logic                          load_last_byte,
    output logic                          load_abort,
    output logic                          uart_reset_request,
    output logic                          debug_read_select
);
  import system_pkg::*;

  (* fsm_encoding = "one_hot" *)logic [                10:0] protocol_state;
  logic [                10:0] next_state;
  logic                        rx_byte_valid;
  logic [                22:0] inactivity_count;
  logic                        timer_clear;
  logic                        timer_inc;
  logic                        timer_limit_reached;
  logic [                39:0] load_size_received;
  logic [                39:0] load_size_candidate;
  logic [                 2:0] size_byte_index;
  logic [IMAGE_SIZE_WIDTH-1:0] load_bytes_remaining;
  logic                        remaining_load;
  logic                        size_init;
  logic                        size_byte_capture;
  logic                        size_index_inc;
  logic                        load_size_valid;
  logic                        last_size_byte;

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

  always_ff @(posedge clk) begin
    if (reset || timer_clear) inactivity_count <= '0;
    else if (timer_inc && !timer_limit_reached) inactivity_count <= inactivity_count + 1'b1;
  end

  always_ff @(posedge clk) begin
    if (reset || size_init) begin
      load_size_received <= '0;
      size_byte_index    <= '0;
    end else begin
      if (size_byte_capture) begin
        load_size_received[8*size_byte_index+:8] <= r_data;
      end
      if (size_index_inc) size_byte_index <= size_byte_index + 1'b1;
    end
  end

  always_ff @(posedge clk) begin
    if (reset) load_bytes_remaining <= '0;
    else if (remaining_load) load_bytes_remaining <= IMAGE_SIZE_WIDTH'(load_size_candidate);
    else if (load_byte_valid) load_bytes_remaining <= load_bytes_remaining - 1'b1;
  end

  always_comb begin
    next_state = protocol_state;
    rd_uart = !reset && !rx_empty;
    rx_byte_valid = !rx_empty && !rx_error_tick;
    timer_clear = 1'b0;
    timer_inc = 1'b0;
    timer_limit_reached = (inactivity_count == 23'd4_999_999);
    load_size_candidate = {r_data, load_size_received[31:0]};
    last_size_byte = (size_byte_index == 3'd4);
    load_size_valid = (load_size_candidate != 40'd0) &&
        (load_size_candidate <= 40'(IMEM_CAPACITY_BYTES)) && (load_size_candidate[1:0] == 2'b00);
    size_init = 1'b0;
    size_byte_capture = 1'b0;
    size_index_inc = 1'b0;
    remaining_load = 1'b0;

    response_start      = 1'b0;
    response_opcode     = '0;
    response_result     = '0;
    response_with_debug = 1'b0;

    load_request = 1'b0;
    run_request = 1'b0;
    step_request = 1'b0;
    load_size_bytes =
        ((protocol_state == WAIT_LOAD_ACCEPT_SENT) || (protocol_state == RECEIVE_LOAD_DATA) ||
         (protocol_state == WAIT_PREP_DONE)) ? IMAGE_SIZE_WIDTH'(load_size_received) : '0;
    load_byte_valid = 1'b0;
    load_byte_data = '0;
    load_byte_offset = '0;
    load_last_byte = 1'b0;
    load_abort = 1'b0;
    uart_reset_request = 1'b0;
    debug_read_select = 1'b0;

    if (!reset) begin
      case (protocol_state)
        WAIT_COMMAND: begin
          if (rx_error_tick) begin
            next_state  = RECOVER_RX;
            timer_clear = 1'b1;
          end else if (rx_byte_valid && r_data == CMD_LOAD) begin
            next_state  = RECEIVE_LOAD_SIZE;
            size_init   = 1'b1;
            timer_clear = 1'b1;
          end else if (rx_byte_valid && r_data == CMD_CHECK_READY && !response_busy) begin
            response_start  = 1'b1;
            response_opcode = CMD_CHECK_READY;
            response_result = load_available ? RESULT_READY : RESULT_BUSY;
            next_state      = WAIT_RESPONSE_SENT;
          end else if (rx_byte_valid && !(r_data >= CMD_LOAD && r_data <= CMD_CHECK_READY) &&
                       !response_busy) begin
            response_start  = 1'b1;
            response_opcode = r_data;
            response_result = RESULT_UNKNOWN_COMMAND;
            next_state      = WAIT_RESPONSE_SENT;
          end
        end
        WAIT_RESPONSE_SENT: begin
          if (response_done_tick) next_state = WAIT_COMMAND;
        end
        WAIT_LOAD_ACCEPT_SENT: begin
          if (response_done_tick) begin
            next_state  = RECEIVE_LOAD_DATA;
            timer_clear = 1'b1;
          end
        end
        RECEIVE_LOAD_DATA: begin
          if (rx_error_tick) begin
            next_state      = RECOVER_RX;
            timer_clear     = 1'b1;
            load_abort      = 1'b1;
            response_start  = 1'b1;
            response_opcode = CMD_LOAD;
            response_result = RESULT_UART_ERROR;
          end else if (rx_byte_valid && load_bytes_remaining > 1) begin
            load_byte_valid = 1'b1;
            load_byte_data = r_data;
            load_byte_offset =
                BYTE_ADDRESS_WIDTH'(IMAGE_SIZE_WIDTH'(load_size_received) - load_bytes_remaining);
            timer_clear = 1'b1;
          end else if (rx_byte_valid && load_bytes_remaining == 1) begin
            load_byte_valid = 1'b1;
            load_last_byte = 1'b1;
            load_byte_data = r_data;
            load_byte_offset =
                BYTE_ADDRESS_WIDTH'(IMAGE_SIZE_WIDTH'(load_size_received) - load_bytes_remaining);
            timer_clear = 1'b1;
            next_state = WAIT_PREP_DONE;
          end else if (rx_empty && timer_limit_reached) begin
            next_state      = RECOVER_RX;
            timer_clear     = 1'b1;
            load_abort      = 1'b1;
            response_start  = 1'b1;
            response_opcode = CMD_LOAD;
            response_result = RESULT_INCOMPLETE_DATA;
          end else if (rx_empty) begin
            timer_inc = 1'b1;
          end
        end
        WAIT_PREP_DONE: begin
          if (!prepare_active && !response_busy) begin
            next_state      = WAIT_RESPONSE_SENT;
            response_start  = 1'b1;
            response_opcode = CMD_LOAD;
            response_result = RESULT_DONE;
          end
        end
        RECEIVE_LOAD_SIZE: begin
          if (rx_error_tick) begin
            next_state      = RECOVER_RX;
            timer_clear     = 1'b1;
            response_start  = 1'b1;
            response_opcode = CMD_LOAD;
            response_result = RESULT_UART_ERROR;
          end else if (rx_byte_valid && !last_size_byte) begin
            size_byte_capture = 1'b1;
            size_index_inc    = 1'b1;
            timer_clear       = 1'b1;
          end else if (rx_byte_valid && last_size_byte) begin
            size_byte_capture = 1'b1;
            timer_clear       = 1'b1;
            if (!load_size_valid) begin
              next_state      = WAIT_RESPONSE_SENT;
              response_start  = 1'b1;
              response_opcode = CMD_LOAD;
              response_result = RESULT_INVALID_SIZE;
            end else begin
              remaining_load  = command_accepted;
              load_request    = 1'b1;
              load_size_bytes = IMAGE_SIZE_WIDTH'(load_size_candidate);
              response_start  = 1'b1;
              response_opcode = CMD_LOAD;
              response_result = command_accepted ? RESULT_ACCEPTED : RESULT_BUSY;
              next_state      = command_accepted ? WAIT_LOAD_ACCEPT_SENT : WAIT_RESPONSE_SENT;
            end
          end else if (rx_empty && timer_limit_reached) begin
            next_state      = RECOVER_RX;
            timer_clear     = 1'b1;
            response_start  = 1'b1;
            response_opcode = CMD_LOAD;
            response_result = RESULT_INCOMPLETE_REQUEST;
          end else if (rx_empty) begin
            timer_inc = 1'b1;
          end
        end
        RECOVER_RX: begin
          if (rx_activity) begin
            timer_clear = 1'b1;
          end else begin
            timer_inc = !timer_limit_reached;
            if (timer_limit_reached && rx_empty && !response_busy) next_state = WAIT_COMMAND;
          end
        end
        default: begin
          // Las otras fases quedan reservadas para iteraciones posteriores.
        end
      endcase
    end
  end
endmodule
