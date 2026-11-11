`timescale 1ns / 1ps

// Verifica decisiones, acciones y eventos de la FSM RX con condiciones del datapath simuladas.
module rx_fsm_tb;
  tp3_case_data data ();
  logic clk = 1'b0;
  logic reset = 1'b1;
  logic rx = 1'b1;
  logic s_tick = 1'b0;
  logic sample_half = 1'b0;
  logic sample_done = 1'b0;
  logic last_bit = 1'b0;
  logic sample_count_clear;
  logic sample_count_inc;
  logic bit_count_clear;
  logic bit_count_inc;
  logic data_shift_enable;
  logic rx_done_tick;
  logic frame_error_tick;
  logic rx_receiving;
  logic sampled_count_clear;
  logic sampled_count_inc;
  logic sampled_bit_clear;
  logic sampled_bit_inc;
  logic sampled_shift;
  logic sampled_done;
  logic sampled_error;

  rx_fsm dut (.*);

  always #10 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic step;
    @(posedge clk);
    #1;
  endtask

  task automatic enter_start;
    @(negedge clk);
    rx = 1'b0;
    step();
    if (dut.state !== 5'b00010 || !rx_receiving) fail("IDLE did not enter START");
  endtask

  task automatic tick_sample(input logic half, input logic done, input logic final_bit);
    @(negedge clk);
    s_tick      = 1'b1;
    sample_half = half;
    sample_done = done;
    last_bit    = final_bit;
    #1;
    sampled_count_clear = sample_count_clear;
    sampled_count_inc   = sample_count_inc;
    sampled_bit_clear   = bit_count_clear;
    sampled_bit_inc     = bit_count_inc;
    sampled_shift       = data_shift_enable;
    sampled_done        = rx_done_tick;
    sampled_error       = frame_error_tick;
    step();
    @(negedge clk);
    s_tick      = 1'b0;
    sample_half = 1'b0;
    sample_done = 1'b0;
    last_bit    = 1'b0;
  endtask

  task automatic validate_start;
    repeat (7) begin
      tick_sample(1'b0, 1'b0, 1'b0);
      if (!sampled_count_inc || sampled_count_clear) fail("START tick action incorrect");
    end
    tick_sample(1'b1, 1'b0, 1'b0);
    if (dut.state !== 5'b00100 || !sampled_bit_clear || !rx_receiving) begin
      fail("valid START did not initialize DATA");
    end
  endtask

  task automatic receive_bits;
    for (int bit_index = 0; bit_index < 8; bit_index++) begin
      repeat (15) begin
        tick_sample(1'b0, 1'b0, 1'b0);
        if (sampled_shift || sampled_bit_inc) fail("DATA action without sample_done");
      end
      tick_sample(1'b0, 1'b1, bit_index == 7);
      if (!sampled_shift || !sampled_count_clear || sampled_done || sampled_error) begin
        fail("DATA sample did not produce one shift action");
      end
      if (bit_index < 7 && !sampled_bit_inc)
        fail("non-final data sample did not advance bit index");
      if (bit_index == 7 && dut.state !== 5'b01000) fail("D7 did not enter STOP");
    end
  endtask

  task automatic validate_stop(input logic stop_level);
    rx = stop_level;
    repeat (15) tick_sample(1'b0, 1'b0, 1'b0);
    tick_sample(1'b0, 1'b1, 1'b0);
    if (stop_level) begin
      if (!sampled_done || sampled_error || dut.state !== 5'b00001) begin
        fail("valid STOP did not produce rx_done_tick and return to IDLE");
      end
    end else begin
      if (sampled_done || !sampled_error || dut.state !== 5'b10000) begin
        fail("invalid STOP did not produce one frame error and enter RECOVER");
      end
      repeat (4) begin
        #1;
        if (frame_error_tick || rx_done_tick) fail("RECOVER repeated an event");
        step();
      end
      @(negedge clk);
      rx = 1'b1;
      step();
      if (dut.state !== 5'b00001) fail("RECOVER did not return to IDLE");
    end
  endtask

  task automatic reset_in_state(input logic [4:0] expected_state, input logic new_rx);
    @(negedge clk);
    rx    = new_rx;
    reset = 1'b1;
    #1;
    if (rx_receiving || rx_done_tick || frame_error_tick || sample_count_inc || bit_count_inc ||
        data_shift_enable)
      fail("reset did not suppress controls/events");
    step();
    if (dut.state !== 5'b00001) fail("reset did not return FSM to IDLE");
    @(negedge clk);
    reset = 1'b0;
  endtask

  initial begin
    data.load();
    repeat (2) step();
    if (dut.state !== 5'b00001 || rx_receiving) fail("reset/initial IDLE mismatch");
    @(negedge clk);
    reset = 1'b0;

    // Reset while in every state, including recover.
    enter_start();
    reset_in_state(5'b00010, 1'b0);

    enter_start();
    rx = 1'b1;
    repeat (7) tick_sample(1'b0, 1'b0, 1'b0);
    tick_sample(1'b1, 1'b0, 1'b0);
    if (!sampled_error || dut.state !== 5'b10000) fail("false START was not rejected");
    reset_in_state(5'b10000, 1'b0);

    rx = 1'b0;
    enter_start();
    validate_start();
    reset_in_state(5'b00100, 1'b0);

    rx = 1'b0;
    enter_start();
    validate_start();
    receive_bits();
    reset_in_state(5'b01000, 1'b0);

    rx = 1'b0;
    enter_start();
    validate_start();
    receive_bits();
    validate_stop(1'b1);

    rx = 1'b0;
    enter_start();
    validate_start();
    receive_bits();
    validate_stop(1'b0);

    // No sampling action is permitted without s_tick.
    @(negedge clk);
    rx = 1'b0;
    step();
    @(negedge clk);
    s_tick = 1'b0;
    #1;
    if (sample_count_inc || sample_count_clear || data_shift_enable || bit_count_inc) begin
      fail("actions occurred while s_tick was low in START");
    end
    reset_in_state(5'b00010, 1'b0);

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
