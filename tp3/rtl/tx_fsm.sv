`timescale 1ns / 1ps

// Controla la transmisión UART y emite acciones para tx_datapath.
module tx_fsm (
    input  logic       clk,
    input  logic       reset,
    input  logic       tx_start,
    input  logic       s_tick,
    input  logic       sample_done,
    input  logic       last_bit,
    output logic       sample_count_clear,
    output logic       sample_count_inc,
    output logic       bit_count_clear,
    output logic       bit_count_inc,
    output logic       data_load_enable,
    output logic       data_shift_enable,
    output logic       tx_write_enable,
    output logic [1:0] tx_output_select,
    output logic       tx_busy,
    output logic       tx_done_tick
);

  localparam logic [3:0] STATE_IDLE  = 4'b0001;
  localparam logic [3:0] STATE_START = 4'b0010;
  localparam logic [3:0] STATE_DATA  = 4'b0100;
  localparam logic [3:0] STATE_STOP  = 4'b1000;

  localparam logic [1:0] OUTPUT_HIGH        = 2'b00;
  localparam logic [1:0] OUTPUT_LOW         = 2'b01;
  localparam logic [1:0] OUTPUT_CURRENT_BIT = 2'b10;
  localparam logic [1:0] OUTPUT_NEXT_BIT    = 2'b11;

  (* fsm_encoding = "one_hot" *)logic [3:0] state = STATE_IDLE;
  logic [3:0] next_state;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= STATE_IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state;
    casez (state)
      STATE_IDLE: begin
        if (tx_start) next_state = STATE_START;
      end
      STATE_START: begin
        if (s_tick && sample_done) next_state = STATE_DATA;
      end
      STATE_DATA: begin
        if (s_tick && sample_done && last_bit) next_state = STATE_STOP;
      end
      STATE_STOP: begin
        if (s_tick && sample_done) next_state = STATE_IDLE;
      end
      default: next_state = STATE_IDLE;
    endcase
  end

  always_comb begin
    sample_count_clear = 1'b0;
    sample_count_inc   = 1'b0;
    bit_count_clear    = 1'b0;
    bit_count_inc      = 1'b0;
    data_load_enable   = 1'b0;
    data_shift_enable  = 1'b0;
    tx_write_enable    = 1'b0;
    tx_output_select   = OUTPUT_HIGH;
    tx_busy            = 1'b0;
    tx_done_tick       = 1'b0;

    if (!reset) begin
      casez (state)
        STATE_IDLE: begin
          sample_count_clear = 1'b1;
          tx_write_enable    = 1'b1;
          if (tx_start) begin
            bit_count_clear  = 1'b1;
            data_load_enable = 1'b1;
            tx_output_select = OUTPUT_LOW;
          end
        end
        STATE_START: begin
          tx_busy = 1'b1;
          if (s_tick) begin
            if (sample_done) begin
              sample_count_clear = 1'b1;
              tx_write_enable    = 1'b1;
              tx_output_select   = OUTPUT_CURRENT_BIT;
            end else begin
              sample_count_inc = 1'b1;
            end
          end
        end
        STATE_DATA: begin
          tx_busy = 1'b1;
          if (s_tick) begin
            if (sample_done) begin
              sample_count_clear = 1'b1;
              tx_write_enable    = 1'b1;
              if (last_bit) begin
                tx_output_select = OUTPUT_HIGH;
              end else begin
                bit_count_inc     = 1'b1;
                data_shift_enable = 1'b1;
                tx_output_select  = OUTPUT_NEXT_BIT;
              end
            end else begin
              sample_count_inc = 1'b1;
            end
          end
        end
        STATE_STOP: begin
          tx_busy         = 1'b1;
          tx_write_enable = 1'b1;
          if (s_tick) begin
            if (sample_done) begin
              sample_count_clear = 1'b1;
              tx_done_tick       = 1'b1;
            end else begin
              sample_count_inc = 1'b1;
            end
          end
        end
        default: begin
          sample_count_clear = 1'b1;
          tx_write_enable    = 1'b1;
        end
      endcase
    end
  end
endmodule
