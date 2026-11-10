`timescale 1ns / 1ps

// Verifica integración RX, recepción de una trama y detección de actividad.
module uart_rx_tb;
  localparam logic [7:0] SERIAL_BYTE = 8'hA5;
  tp3_case_data data ();
  logic       clk = 1'b0;
  logic       reset = 1'b1;
  logic       rx = 1'b1;
  logic       s_tick = 1'b0;
  logic [7:0] data_out;
  logic       rx_done_tick;
  logic       frame_error_tick;
  logic       rx_receiving;
  logic       rx_activity;
  int         done_events = 0;
  int         error_events = 0;

  uart_rx dut (.*);

  always #10 clk = ~clk;

  always @(posedge clk) begin
    if (rx_done_tick) done_events++;
    if (frame_error_tick) error_events++;
  end

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic clock_step;
    @(posedge clk);
    #1;
  endtask

  task automatic tick;
    @(negedge clk);
    s_tick = 1'b1;
    clock_step();
    @(negedge clk);
    s_tick = 1'b0;
    clock_step();
  endtask

  task automatic receive_false_start;
    @(negedge clk);
    rx = 1'b0;
    clock_step();
    if (!rx_receiving || !rx_activity) fail("start transition was not reported active");

    @(negedge clk);
    rx = 1'b1;
    clock_step();
    if (!rx_activity) fail("RX transition to idle level was not detected");

    repeat (7) tick();
    if (error_events != 0) fail("false start error occurred before the eighth tick");
    tick();
    if (error_events != 1 || done_events != 0) fail("false start did not produce one frame error");
    if (frame_error_tick || rx_done_tick) fail("event was not a one-cycle tick");
  endtask

  task automatic receive_valid_frame;
    @(negedge clk);
    rx = 1'b0;
    clock_step();
    if (!rx_receiving || !rx_activity) fail("valid frame was not marked as receiving");
    repeat (8) tick();
    if (error_events != 1) fail("valid start produced a frame error");

    for (int bit_index = 0; bit_index < 8; bit_index++) begin
      @(negedge clk);
      rx = SERIAL_BYTE[bit_index];
      repeat (16) tick();
    end
    if (data_out !== SERIAL_BYTE) fail("integrated datapath assembled the byte incorrectly");
    if (!rx_receiving) fail("receiver left receiving state before stop validation");

    @(negedge clk);
    rx = 1'b1;
    repeat (15) tick();
    if (done_events != 0) fail("valid stop completed before its sixteenth tick");
    tick();
    if (done_events != 1 || error_events != 1)
      fail("valid stop did not produce exactly one done event");
    if (rx_receiving) fail("receiver remained active after valid stop");
    if (rx_activity) fail("idle high line remained active after frame completion");
    if (rx_done_tick || frame_error_tick) fail("completion event lasted beyond its sampling cycle");
  endtask

  initial begin
    data.load();
    repeat (2) clock_step();
    if (data_out !== 8'h00 || rx_done_tick || frame_error_tick || rx_receiving || rx_activity) begin
      fail("reset did not initialize the integrated receiver and indicators");
    end

    @(negedge clk);
    reset = 1'b0;
    clock_step();
    if (rx_activity) fail("stable idle-high RX was reported active");

    receive_false_start();
    repeat (2) clock_step();
    if (rx_receiving || rx_activity) fail("receiver did not return to inactive idle");

    receive_valid_frame();

    // Reset during reception clears resources and suppresses all external events.
    @(negedge clk);
    rx = 1'b0;
    clock_step();
    if (!rx_receiving) fail("reset fixture did not enter START");
    @(negedge clk);
    reset  = 1'b1;
    s_tick = 1'b1;
    #1;
    if (rx_activity || rx_receiving || rx_done_tick || frame_error_tick) begin
      fail("reset did not suppress the external RX indicators");
    end
    clock_step();
    if (data_out !== 8'h00 || rx_receiving || rx_activity)
      fail("reset did not clear integrated RX state");

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
