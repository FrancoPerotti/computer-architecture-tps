`timescale 1ns / 1ps

// Verifica la transmisión física 8N1 a través de tx_fsm y tx_datapath reales.
module uart_tx_tb;
  localparam integer DATA_WIDTH = system_pkg::UART_DATA_BITS;
  tp3_case_data data ();
  logic                  clk = 1'b0;
  logic                  reset = 1'b1;
  logic                  tx_start = 1'b0;
  logic                  s_tick = 1'b0;
  logic [DATA_WIDTH-1:0] data_in = '0;
  logic                  tx;
  logic                  tx_busy;
  logic                  tx_done_tick;
  int                    done_events = 0;

  uart_tx dut (.*);

  always #10 clk = ~clk;

  always @(posedge clk) begin
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

  task automatic accept_byte(input logic [DATA_WIDTH-1:0] value);
    @(negedge clk);
    tx_start = 1'b1;
    data_in  = value;
    s_tick   = 1'b0;
    #1;
    if (tx !== 1'b1 || tx_busy || tx_done_tick) fail("UART not idle before tx_start");
    clock_step();
    if (!tx_busy || tx !== 1'b0 || dut.transmitter_datapath.data_reg !== value) begin
      fail("tx_start did not load the byte and begin START in one clock");
    end

    // Keep requesting another byte and change data_in while busy; neither may alter this frame.
    @(negedge clk);
    tx_start = 1'b1;
    data_in  = ~value;
    clock_step();
    if (!tx_busy || tx !== 1'b0 || dut.transmitter_datapath.data_reg !== value) begin
      fail("busy transmitter accepted a new byte or changed the captured data");
    end
  endtask

  task automatic sample_tick_expect(input logic expected_tx);
    @(negedge clk);
    s_tick = 1'b1;
    #1;
    if (tx_done_tick) fail("unexpected tx_done_tick before the final Stop tick");
    @(posedge clk);
    #1;
    s_tick = 1'b0;
    #1;
    if (tx !== expected_tx || !tx_busy || tx_done_tick) begin
      fail("TX level or busy state changed on an ordinary sample tick");
    end
    clock_step();
  endtask

  task automatic start_final_tick(input logic [DATA_WIDTH-1:0] value);
    @(negedge clk);
    s_tick = 1'b1;
    #1;
    if (dut.transmitter_control.state !== 4'b0010 || !dut.transmitter_datapath.sample_done) begin
      fail("START did not reach sample_done before tick sixteen");
    end
    @(posedge clk);
    #1;
    s_tick = 1'b0;
    #1;
    if (tx !== value[0] || !tx_busy || tx_done_tick ||
        dut.transmitter_control.state !== 4'b0100) begin
      fail("sixteenth START tick did not begin DATA at D0");
    end
    clock_step();
  endtask

  task automatic data_final_tick(input logic final_bit, input logic expected_tx,
                                 input logic [DATA_WIDTH-1:0] expected_shifted);
    @(negedge clk);
    s_tick = 1'b1;
    #1;
    if (dut.transmitter_control.state !== 4'b0100 || !dut.transmitter_datapath.sample_done) begin
      fail("data bit did not reach sample_done before its sixteenth tick");
    end
    @(posedge clk);
    #1;
    s_tick = 1'b0;
    #1;
    if (tx !== expected_tx || !tx_busy || tx_done_tick ||
        dut.transmitter_datapath.data_reg !== expected_shifted) begin
      fail("data boundary did not select the next bit or shift the captured byte correctly");
    end
    if (final_bit && dut.transmitter_control.state !== 4'b1000) begin
      fail("D7 did not begin STOP");
    end
    if (!final_bit && dut.transmitter_control.state !== 4'b0100) begin
      fail("D0-D6 did not remain in DATA");
    end
    clock_step();
  endtask

  task automatic stop_final_tick;
    @(negedge clk);
    s_tick   = 1'b1;
    tx_start = 1'b0;
    #1;
    if (dut.transmitter_control.state !== 4'b1000 || !dut.transmitter_datapath.sample_done ||
        !tx_busy || tx !== 1'b1 || !tx_done_tick) begin
      fail("final Stop tick did not assert tx_done_tick while TX remained busy");
    end
    @(posedge clk);
    #1;
    s_tick = 1'b0;
    #1;
    if (tx_busy || tx_done_tick || tx !== 1'b1 || dut.transmitter_control.state !== 4'b0001) begin
      fail("final Stop edge did not return to idle-high state");
    end
    clock_step();
  endtask

  task automatic transmit_byte(input logic [DATA_WIDTH-1:0] value);
    logic   [DATA_WIDTH-1:0] shifted;
    integer                  done_before;
    done_before = done_events;
    accept_byte(value);

    // Fifteen ticks increment the sample counter; tick sixteen starts D0.
    repeat (15) sample_tick_expect(1'b0);
    if (!dut.transmitter_datapath.sample_done)
      fail("START duration was shorter than sixteen ticks");
    start_final_tick(value);

    shifted = value;
    for (int bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
      if (dut.transmitter_datapath.data_reg !== shifted) fail("shift register lost bit order");
      repeat (15) sample_tick_expect(value[bit_index]);
      if (bit_index < DATA_WIDTH - 1) begin
        shifted = {1'b0, shifted[DATA_WIDTH-1:1]};
        data_final_tick(1'b0, value[bit_index+1], shifted);
      end else begin
        data_final_tick(1'b1, 1'b1, shifted);
      end
    end

    // Stop stays high and busy for fifteen ticks; the sixteenth consumes done.
    repeat (15) sample_tick_expect(1'b1);
    if (!tx_busy || done_events != done_before) fail("Stop ended before its sixteenth tick");
    stop_final_tick();
    if (done_events != done_before + 1) fail("byte completion did not occur exactly once");
  endtask

  initial begin
    data.load();
    repeat (2) clock_step();
    if (tx !== 1'b1 || tx_busy || tx_done_tick) fail("reset did not produce idle-high output");
    @(negedge clk);
    reset = 1'b0;

    transmit_byte(8'hA5);
    if (done_events != 1) fail("first completed byte did not produce one done event");

    transmit_byte(8'h3C);
    if (done_events != 2) fail("second byte could not start or completion count was incorrect");

    // Reset during DATA aborts the active frame without a completion event.
    accept_byte(8'h96);
    repeat (15) sample_tick_expect(1'b0);
    start_final_tick(8'h96);
    repeat (5) sample_tick_expect(1'b0);
    @(negedge clk);
    reset = 1'b1;
    #1;
    if (tx_busy || tx_done_tick) fail("reset did not immediately suppress TX status outputs");
    clock_step();
    if (tx !== 1'b1 || tx_busy || tx_done_tick || done_events != 2 ||
        dut.transmitter_datapath.data_reg !== 8'h00 ||
        dut.transmitter_control.state !== 4'b0001) begin
      fail("reset during transmission did not abort and clear the transmitter");
    end

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
