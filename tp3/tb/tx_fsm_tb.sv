`timescale 1ns / 1ps

// Verifica temporización, acciones y eventos de tx_fsm con señales de datapath simuladas.
module tx_fsm_tb;
  tp3_case_data data ();
  logic       clk = 1'b0;
  logic       reset = 1'b1;
  logic       tx_start = 1'b0;
  logic       s_tick = 1'b0;
  logic       sample_done = 1'b0;
  logic       last_bit = 1'b0;
  logic       sample_count_clear;
  logic       sample_count_inc;
  logic       bit_count_clear;
  logic       bit_count_inc;
  logic       data_load_enable;
  logic       data_shift_enable;
  logic       tx_write_enable;
  logic [1:0] tx_output_select;
  logic       tx_busy;
  logic       tx_done_tick;
  int         load_events = 0;
  int         shift_events = 0;
  int         done_events = 0;
  int         shifts_before_complete;

  tx_fsm dut (.*);

  always #10 clk = ~clk;

  always @(posedge clk) begin
    if (data_load_enable) load_events++;
    if (data_shift_enable) shift_events++;
    if (tx_done_tick) done_events++;
  end

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic clock_step;
    @(posedge clk);
    #1;
  endtask

  task automatic accept_start;
    @(negedge clk);
    tx_start = 1'b1;
    s_tick   = 1'b0;
    #1;
    if (dut.state !== 4'b0001 || !sample_count_clear || !bit_count_clear || !data_load_enable ||
        !tx_write_enable || tx_output_select !== 2'b01 || tx_busy || tx_done_tick) begin
      fail("IDLE did not accept tx_start and select LOW without waiting for s_tick");
    end
    clock_step();
    if (dut.state !== 4'b0010 || !tx_busy) fail("accepted request did not enter busy START");
    @(negedge clk);
    tx_start = 1'b0;
  endtask

  task automatic tick_start;
    @(negedge clk);
    s_tick      = 1'b1;
    sample_done = 1'b0;
    last_bit    = 1'b0;
    #1;
    if (!sample_count_inc || sample_count_clear || tx_write_enable || data_load_enable ||
        data_shift_enable || !tx_busy) begin
      fail("START interval tick did not increment only the sample counter");
    end
    clock_step();
    if (dut.state !== 4'b0010) fail("START ended before its sixteenth tick");
    @(negedge clk);
    s_tick = 1'b0;
  endtask

  task automatic tick_start_done;
    @(negedge clk);
    s_tick      = 1'b1;
    sample_done = 1'b1;
    last_bit    = 1'b0;
    #1;
    if (!sample_count_clear || sample_count_inc || !tx_write_enable || tx_output_select !== 2'b10 ||
        !tx_busy) begin
      fail("sixteenth START tick did not select CURRENT_BIT");
    end
    clock_step();
    if (dut.state !== 4'b0100 || !tx_busy) fail("START did not transition into DATA");
    @(negedge clk);
    s_tick      = 1'b0;
    sample_done = 1'b0;
  endtask

  task automatic tick_data;
    @(negedge clk);
    s_tick      = 1'b1;
    sample_done = 1'b0;
    last_bit    = 1'b0;
    #1;
    if (!sample_count_inc || sample_count_clear || bit_count_inc || data_shift_enable ||
        tx_write_enable || !tx_busy) begin
      fail("DATA interval tick emitted an incorrect action");
    end
    clock_step();
    if (dut.state !== 4'b0100) fail("DATA changed state before sample_done");
    @(negedge clk);
    s_tick = 1'b0;
  endtask

  task automatic tick_data_done(input logic final_bit);
    @(negedge clk);
    s_tick      = 1'b1;
    sample_done = 1'b1;
    last_bit    = final_bit;
    #1;
    if (!sample_count_clear || sample_count_inc || !tx_write_enable || !tx_busy) begin
      fail("data boundary did not clear the sample count and update output");
    end
    if (final_bit) begin
      if (bit_count_inc || data_shift_enable || tx_output_select !== 2'b00) begin
        fail("D7 boundary shifted data or failed to select HIGH");
      end
    end else if (!bit_count_inc || !data_shift_enable || tx_output_select !== 2'b11) begin
      fail("D0-D6 boundary did not shift and select NEXT_BIT");
    end
    clock_step();
    if (final_bit) begin
      if (dut.state !== 4'b1000 || !tx_busy) fail("D7 did not enter busy STOP");
    end else if (dut.state !== 4'b0100 || !tx_busy) begin
      fail("non-final data bit did not remain in DATA");
    end
    @(negedge clk);
    s_tick      = 1'b0;
    sample_done = 1'b0;
    last_bit    = 1'b0;
  endtask

  task automatic tick_stop;
    @(negedge clk);
    s_tick      = 1'b1;
    sample_done = 1'b0;
    last_bit    = 1'b0;
    #1;
    if (!sample_count_inc || sample_count_clear || !tx_write_enable || tx_output_select !== 2'b00 ||
        !tx_busy || tx_done_tick) begin
      fail("STOP interval did not hold HIGH and increment the sample count");
    end
    clock_step();
    if (dut.state !== 4'b1000 || !tx_busy) fail("STOP ended before its sixteenth tick");
    @(negedge clk);
    s_tick = 1'b0;
  endtask

  task automatic tick_stop_done;
    @(negedge clk);
    s_tick      = 1'b1;
    sample_done = 1'b1;
    last_bit    = 1'b0;
    #1;
    if (!sample_count_clear || sample_count_inc || !tx_write_enable || tx_output_select !== 2'b00 ||
        !tx_busy || !tx_done_tick) begin
      fail("final STOP tick did not produce tx_done_tick while busy");
    end
    clock_step();
    if (dut.state !== 4'b0001 || tx_busy || tx_done_tick) begin
      fail("completed STOP did not return to inactive IDLE");
    end
    @(negedge clk);
    s_tick      = 1'b0;
    sample_done = 1'b0;
  endtask

  task automatic check_no_tick_actions;
    logic [3:0] held_state;
    @(negedge clk);
    held_state  = dut.state;
    s_tick      = 1'b0;
    sample_done = 1'b1;
    last_bit    = 1'b1;
    tx_start    = 1'b1;
    #1;
    if (sample_count_inc || sample_count_clear || bit_count_inc || data_load_enable ||
        data_shift_enable || tx_done_tick) begin
      fail("sample_done without s_tick caused an action");
    end
    clock_step();
    if (dut.state !== held_state || !tx_busy) fail("transmitter advanced without s_tick");
    @(negedge clk);
    tx_start    = 1'b0;
    sample_done = 1'b0;
    last_bit    = 1'b0;
  endtask

  task automatic reset_from_active;
    @(negedge clk);
    reset = 1'b1;
    #1;
    if (tx_busy || tx_done_tick || sample_count_clear || sample_count_inc || bit_count_clear ||
        bit_count_inc || data_load_enable || data_shift_enable || tx_write_enable) begin
      fail("reset did not suppress busy, events, and actions");
    end
    clock_step();
    if (dut.state !== 4'b0001 || tx_busy || tx_done_tick) fail("reset did not return FSM to IDLE");
    @(negedge clk);
    reset       = 1'b0;
    tx_start    = 1'b0;
    s_tick      = 1'b0;
    sample_done = 1'b0;
    last_bit    = 1'b0;
  endtask

  task automatic start_to_data;
    accept_start();
    repeat (15) tick_start();
    tick_start_done();
  endtask

  task automatic transmit_data_to_stop;
    for (int bit_index = 0; bit_index < 8; bit_index++) begin
      repeat (15) tick_data();
      tick_data_done(bit_index == 7);
    end
  endtask

  task automatic complete_stop;
    repeat (15) tick_stop();
    tick_stop_done();
  endtask

  initial begin
    data.load();
    repeat (2) clock_step();
    if (dut.state !== 4'b0001 || tx_busy || tx_done_tick || sample_count_clear ||
        tx_write_enable) begin
      fail("reset did not initialize IDLE and suppress outputs");
    end
    @(negedge clk);
    reset = 1'b0;
    #1;
    if (!sample_count_clear || !tx_write_enable || tx_output_select !== 2'b00 || tx_busy) begin
      fail("IDLE did not clear sample count and select HIGH");
    end

    // Accept without a tick, ignore a new request while busy, then reset START.
    accept_start();
    if (load_events != 1) fail("byte was not loaded exactly once on acceptance");
    check_no_tick_actions();
    reset_from_active();

    // Reset is also effective from DATA.
    start_to_data();
    check_no_tick_actions();
    reset_from_active();

    // Reach STOP, verify its full duration, then reset it before completion.
    start_to_data();
    transmit_data_to_stop();
    if (shift_events != 7) fail("one byte must issue exactly seven shifts");
    check_no_tick_actions();
    repeat (15) tick_stop();
    reset_from_active();
    if (done_events != 0) fail("reset during STOP produced tx_done_tick");

    // A complete byte has one load, seven shifts, and one physical completion.
    shifts_before_complete = shift_events;
    start_to_data();
    transmit_data_to_stop();
    if (shift_events - shifts_before_complete != 7)
      fail("complete byte did not produce seven shifts");
    if (load_events != 4) fail("active tx_start requests were not ignored");
    complete_stop();
    if (done_events != 1) fail("complete transmission did not produce exactly one done event");
    if (tx_busy || tx_done_tick) fail("completion remained asserted after the final edge");

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
