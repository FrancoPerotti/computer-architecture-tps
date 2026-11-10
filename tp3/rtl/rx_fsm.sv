// Controla las decisiones de recepción UART; los recursos pertenecen a rx_datapath.
module rx_fsm (
    input  logic clk,
    input  logic reset,
    input  logic rx,
    input  logic s_tick,
    input  logic sample_half,
    input  logic sample_done,
    input  logic last_bit,
    output logic sample_count_clear,
    output logic sample_count_inc,
    output logic bit_count_clear,
    output logic bit_count_inc,
    output logic data_shift_enable,
    output logic rx_done_tick,
    output logic frame_error_tick,
    output logic rx_receiving
);

  localparam logic [4:0] STATE_IDLE    = 5'b00001;
  localparam logic [4:0] STATE_START   = 5'b00010;
  localparam logic [4:0] STATE_DATA    = 5'b00100;
  localparam logic [4:0] STATE_STOP    = 5'b01000;
  localparam logic [4:0] STATE_RECOVER = 5'b10000;

  (* fsm_encoding = "one_hot" *)logic [4:0] state = STATE_IDLE;
  logic [4:0] next_state;

  // El estado se registra; reset síncrono vuelve a IDLE.
  always_ff @(posedge clk) begin
    if (reset) begin
      state <= STATE_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Calcula transiciones usando condiciones del datapath y la línea RX.
  always_comb begin
    next_state = state;
    casez (state)
      STATE_IDLE: begin
        if (!rx) next_state = STATE_START;
      end
      STATE_START: begin
        if (s_tick && sample_half) begin
          if (!rx) next_state = STATE_DATA;
          else next_state = STATE_RECOVER;
        end
      end
      STATE_DATA: begin
        if (s_tick && sample_done && last_bit) next_state = STATE_STOP;
      end
      STATE_STOP: begin
        if (s_tick && sample_done) begin
          if (rx) next_state = STATE_IDLE;
          else next_state = STATE_RECOVER;
        end
      end
      STATE_RECOVER: begin
        if (rx) next_state = STATE_IDLE;
      end
      default: next_state = STATE_IDLE;
    endcase
  end

  // Emite acciones combinacionales que consume rx_datapath en este flanco.
  always_comb begin
    sample_count_clear = 1'b0;
    sample_count_inc   = 1'b0;
    bit_count_clear    = 1'b0;
    bit_count_inc      = 1'b0;
    data_shift_enable  = 1'b0;
    rx_done_tick       = 1'b0;
    frame_error_tick   = 1'b0;
    rx_receiving       = 1'b0;

    if (!reset) begin
      casez (state)
        STATE_IDLE: begin
          sample_count_clear = 1'b1;
          bit_count_clear    = 1'b1;
        end
        STATE_START: begin
          rx_receiving = 1'b1;
          if (s_tick) begin
            if (sample_half) begin
              sample_count_clear = 1'b1;
              if (!rx) bit_count_clear = 1'b1;
              else frame_error_tick = 1'b1;
            end else begin
              sample_count_inc = 1'b1;
            end
          end
        end
        STATE_DATA: begin
          rx_receiving = 1'b1;
          if (s_tick) begin
            if (sample_done) begin
              sample_count_clear = 1'b1;
              data_shift_enable  = 1'b1;
              if (!last_bit) bit_count_inc = 1'b1;
            end else begin
              sample_count_inc = 1'b1;
            end
          end
        end
        STATE_STOP: begin
          rx_receiving = 1'b1;
          if (s_tick) begin
            if (sample_done) begin
              sample_count_clear = 1'b1;
              if (rx) rx_done_tick = 1'b1;
              else frame_error_tick = 1'b1;
            end else begin
              sample_count_inc = 1'b1;
            end
          end
        end
        STATE_RECOVER: begin
          sample_count_clear = 1'b1;
          bit_count_clear    = 1'b1;
        end
        default: begin
          sample_count_clear = 1'b1;
          bit_count_clear    = 1'b1;
        end
      endcase
    end
  end
endmodule
