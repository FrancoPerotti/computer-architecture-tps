`timescale 1ns / 1ps

// Ejecuta los escenarios físicos RX/reset de TEST-UART-001 con el core real.
module uart_core_canonical_tb;
  localparam integer DATA_WIDTH = system_pkg::UART_DATA_BITS;
  localparam
      integer DIVISOR = (system_pkg::FUNCTIONAL_CLOCK_HZ +
                         (system_pkg::UART_BAUD_RATE * system_pkg::UART_OVERSAMPLE_FACTOR) / 2) /
      (system_pkg::UART_BAUD_RATE * system_pkg::UART_OVERSAMPLE_FACTOR);
  localparam integer BIT_CYCLES = DIVISOR * system_pkg::UART_OVERSAMPLE_FACTOR;

  tp3_case_data data ();
  logic                    clk = 1'b0;
  logic                    reset = 1'b1;
  logic                    serial_rx = 1'b1;
  logic                    serial_tx;
  logic   [DATA_WIDTH-1:0] r_data;
  logic                    rd_uart = 1'b0;
  logic                    rx_empty;
  logic   [DATA_WIDTH-1:0] w_data = '0;
  logic                    wr_uart = 1'b0;
  logic                    tx_full;
  logic                    rx_error_tick;
  logic                    rx_activity;
  logic                    rx_receiving;
  logic                    tx_done_tick;
  integer                  reference_phase = 0;
  integer                  reference_cycles = 0;
  integer                  previous_tick_cycle = 0;
  integer                  rx_done_events = 0;
  integer                  rx_error_events = 0;
  integer                  tx_done_events = 0;
  integer                  start_cycle;
  integer                  guard;
  integer                  expected_byte;
  integer                  requested_phase;
  logic                    error_seen;

  uart_core dut (.*);
  always #10 clk = ~clk;

  always @(posedge clk) begin
    if (reset) begin
      reference_phase     = 0;
      reference_cycles    = 0;
      previous_tick_cycle = 0;
    end else begin
      reference_cycles++;
      if (reference_phase == DIVISOR - 1) begin
        reference_phase = 0;
      end else begin
        reference_phase++;
      end
      if (dut.s_tick !== dut.receiver.s_tick || dut.s_tick !== dut.transmitter.s_tick)
        fail("RX/TX no comparten s_tick");
      if (dut.s_tick) begin
        if (previous_tick_cycle == 0 && reference_cycles != DIVISOR + 1)
          fail("primer tick consumido fuera del flanco 164");
        if (previous_tick_cycle != 0 && reference_cycles - previous_tick_cycle != DIVISOR)
          fail("periodo del tick compartido distinto de 163 clocks");
        previous_tick_cycle = reference_cycles;
      end
      if (dut.receiver.rx_done_tick) rx_done_events++;
      if (rx_error_tick) rx_error_events++;
      if (tx_done_tick) tx_done_events++;
    end
  end

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic clocks(input integer count);
    repeat (count) begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic align_generator_phase(input integer phase_value);
    if (phase_value < 0 || phase_value >= DIVISOR)
      fail("requested phase is outside generator period");
    while (reference_phase != phase_value) @(negedge clk);
  endtask

  task automatic start_rx_body(input logic [DATA_WIDTH-1:0] value, input integer phase_value);
    integer bit_index;
    begin
      align_generator_phase(phase_value);
      serial_rx   = 1'b0;
      start_cycle = reference_cycles;
      #1;
      if (dut.synchronized_rx !== 1'b1 || rx_receiving)
        fail("asynchronous RX transition bypassed the two-flop synchronizer");

      @(posedge clk);
      #1;
      if (dut.synchronized_rx !== 1'b1 || rx_receiving)
        fail("RX changed after only the first synchronizer edge");
      @(posedge clk);
      #1;
      if (dut.synchronized_rx !== 1'b0)
        fail("second synchronizer stage did not capture the start level");
      @(posedge clk);
      #1;
      if (!rx_receiving || !rx_activity) fail("receiver did not report the synchronized start");
      repeat (BIT_CYCLES - 3) @(posedge clk);
      @(negedge clk);
      if (reference_cycles - start_cycle != BIT_CYCLES)
        fail("Start input width differs from 16 ticks");
      for (bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
        serial_rx = value[bit_index];
        if (!rx_receiving || !rx_activity) fail("RX indicators dropped during DATA");
        repeat (BIT_CYCLES) @(posedge clk);
        @(negedge clk);
      end
    end
  endtask

  task automatic wait_for_rx_done;
    begin
      serial_rx = 1'b1;
      guard     = 0;
      while (dut.rx_fifo.count != 1 && guard < 2 * BIT_CYCLES) begin
        clocks(1);
        guard++;
      end
      if (dut.rx_fifo.count != 1) fail("valid Stop did not enqueue one byte");
      if (rx_done_events != 1) fail("RX completion event did not occur exactly once");
      if (rx_error_events != 0) fail("valid frame produced an RX error");
      if (rx_receiving) fail("rx_receiving remained active after valid Stop");
      clocks(2);
      if (rx_activity) fail("RX activity remained high after line returned to idle");
    end
  endtask

  task automatic check_and_drain_rx(input integer value);
    begin
      if (rx_empty || r_data !== DATA_WIDTH'(value))
        fail($sformatf("decoded byte mismatch: expected %02h observed %02h", value, r_data));
      @(negedge clk);
      rd_uart = 1'b1;
      @(posedge clk);
      #1;
      if (!rx_empty || dut.rx_fifo.count != 0) fail("received byte did not drain exactly once");
      @(negedge clk);
      rd_uart = 1'b0;
    end
  endtask

  task automatic wait_frame_error;
    integer errors_before;
    begin
      errors_before = rx_error_events;
      guard         = 0;
      while (!dut.receiver.frame_error_tick && guard < BIT_CYCLES) begin
        clocks(1);
        guard++;
      end
      if (!dut.receiver.frame_error_tick) fail("frame_error_tick did not assert");
      @(posedge clk);
      #1;
      if (rx_error_events != errors_before + 1) fail("frame error did not pulse exactly once");
      if (dut.receiver.receiver_control.state !== 5'b10000)
        fail("invalid frame did not enter RECOVER");
      if (rx_done_events != 0 || dut.rx_fifo.count != 0)
        fail("invalid frame produced a valid byte");
    end
  endtask

  task automatic wait_recover_until_high;
    integer errors_before;
    begin
      errors_before = rx_error_events;
      if (serial_rx !== 1'b1) begin
        @(negedge clk);
        serial_rx = 1'b1;
      end
      guard = 0;
      while (dut.receiver.receiver_control.state !== 5'b00001 && guard < 8) begin
        clocks(1);
        guard++;
      end
      if (dut.receiver.receiver_control.state !== 5'b00001)
        fail("RECOVER did not return to IDLE when RX became high");
      clocks(2);
      if (rx_error_events != errors_before) fail("RECOVER repeated an error event");
    end
  endtask

  task automatic send_postreset_probe;
    begin
      start_rx_body(8'hC3, 0);
      wait_for_rx_done();
      check_and_drain_rx(8'hC3);
      if (dut.receiver.receiver_control.state !== 5'b00001 || serial_tx !== 1'b1)
        fail("UART did not resume normal idle operation after reset");
    end
  endtask

  task automatic run_nominal_rx;
    integer done_before;
    integer error_before;
    begin
      expected_byte   = data.get_integer("/inputs/byte");
      requested_phase = data.get_integer("/inputs/start_tick_phase");
      if (data.get_string("/inputs/direction") != "RX") fail("expected RX nominal vector");
      done_before  = rx_done_events;
      error_before = rx_error_events;
      start_rx_body(DATA_WIDTH'(expected_byte), requested_phase);
      wait_for_rx_done();
      if (rx_done_events != done_before + 1 || rx_error_events != error_before)
        fail("nominal RX event counts differ from expected one-done/no-error");
      if (!data.get_boolean("/expected/one_done"))
        fail("catalog does not expect one RX completion");
      check_and_drain_rx(data.get_integer("/expected/decoded_byte"));
    end
  endtask

  task automatic run_false_start;
    integer errors_before;
    begin
      errors_before = rx_error_events;
      align_generator_phase(0);
      serial_rx = 1'b0;
      #1;
      if (dut.synchronized_rx !== 1'b1) fail("false Start bypassed synchronization");
      repeat (BIT_CYCLES / 4) @(posedge clk);
      @(negedge clk);
      serial_rx = 1'b1;
      wait_frame_error();
      wait_recover_until_high();
      if (rx_error_events != errors_before + 1 || dut.rx_fifo.count != 0 || rx_done_events != 0)
        fail("false Start created a byte or repeated an error");
      if (data.get_boolean(
              "/expected/valid_byte"
          ) || !data.get_boolean(
              "/expected/frame_error"
          ) || !data.get_boolean(
              "/expected/recover_waits_high"
          ))
        fail("false-Start manifest expectations are inconsistent");
    end
  endtask

  task automatic run_bad_stop(input bit hold_low_until_recovery);
    integer errors_before;
    begin
      errors_before = rx_error_events;
      start_rx_body(8'h5A, 0);
      serial_rx = 1'b0;
      wait_frame_error();
      if (hold_low_until_recovery) begin
        clocks(BIT_CYCLES);
        if (dut.receiver.receiver_control.state !== 5'b10000 ||
            rx_error_events != errors_before + 1 || rx_done_events != 0)
          fail("RECOVER did not wait for a sustained-low RX line");
      end
      wait_recover_until_high();
      if (rx_error_events != errors_before + 1 || dut.rx_fifo.count != 0 || rx_done_events != 0)
        fail("bad Stop created a byte or repeated an error");
      if (data.get_boolean(
              "/expected/valid_byte"
          ) || !data.get_boolean(
              "/expected/frame_error"
          ) || !data.get_boolean(
              "/expected/recover_waits_high"
          ))
        fail("bad-Stop manifest expectations are inconsistent");
    end
  endtask

  task automatic enqueue_tx(input logic [DATA_WIDTH-1:0] value);
    begin
      @(negedge clk);
      w_data  = value;
      wr_uart = 1'b1;
      @(posedge clk);
      #1;
      @(negedge clk);
      wr_uart = 1'b0;
    end
  endtask

  task automatic decode_tx(input logic [DATA_WIDTH-1:0] value);
    integer done_before;
    integer timeout;
    begin
      done_before = tx_done_events;
      timeout     = 0;
      while (!dut.tx_busy && timeout < 16) begin
        clocks(1);
        timeout++;
      end
      if (!dut.tx_busy || serial_tx !== 1'b0) fail("TX did not begin with Start low");
      clocks(BIT_CYCLES / 2);
      if (serial_tx !== 1'b0) fail("TX Start duration/level incorrect");
      for (integer bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
        clocks(BIT_CYCLES);
        if (serial_tx !== value[bit_index]) fail("TX data bit/order mismatch");
      end
      clocks(BIT_CYCLES);
      if (serial_tx !== 1'b1 || !dut.tx_busy) fail("TX Stop did not remain high and busy");
      timeout = 0;
      while (tx_done_events == done_before && timeout < BIT_CYCLES) begin
        clocks(1);
        timeout++;
      end
      if (tx_done_events != done_before + 1 || dut.tx_busy || tx_done_tick)
        fail("TX completion did not occur once at the end of Stop");
    end
  endtask

  task automatic run_bad_stop_with_tx;
    integer errors_before;
    begin
      errors_before = rx_error_events;
      enqueue_tx(8'hA6);
      fork
        decode_tx(8'hA6);
        begin
          start_rx_body(8'h5A, 0);
          serial_rx = 1'b0;
          wait_frame_error();
          if (!dut.tx_busy || dut.transmitter.transmitter_control.state !== 4'b1000)
            fail("TX did not continue in STOP while RX recovered");
          clocks(BIT_CYCLES / 4);
          if (!dut.tx_busy || rx_error_events != errors_before + 1)
            fail("RX recovery interrupted TX or repeated its error");
          @(negedge clk);
          serial_rx = 1'b1;
          wait_recover_until_high();
        end
      join
      if (dut.tx_busy || tx_done_events != 1 || dut.rx_fifo.count != 0)
        fail("RX recovery did not remain independent of the completed TX frame");
    end
  endtask

  task automatic reset_during_rx_data;
    integer done_before;
    integer errors_before;
    begin
      done_before   = rx_done_events;
      errors_before = rx_error_events;
      align_generator_phase(0);
      serial_rx = 1'b0;
      guard     = 0;
      while (dut.receiver.receiver_control.state !== 5'b00100 && guard < BIT_CYCLES) begin
        clocks(1);
        guard++;
      end
      if (dut.receiver.receiver_control.state !== 5'b00100)
        fail("reset fixture did not reach RX DATA");
      @(negedge clk);
      reset = 1'b1;
      clocks(1);
      if (dut.receiver.receiver_control.state !== 5'b00001 || rx_activity || rx_receiving ||
          dut.receiver.rx_done_tick || rx_error_tick || rx_done_events != done_before ||
          rx_error_events != errors_before)
        fail("reset during RX DATA did not abort cleanly");
      if (data.get_boolean(
              "/expected/normal_done"
          ) || !data.get_boolean(
              "/expected/postreset_RX_IDLE"
          ) || data.get_integer(
              "/expected/postreset_TX"
          ) != 1)
        fail("RX reset manifest expectations are inconsistent");
      if (serial_tx !== 1'b1 || dut.tx_busy) fail("reset changed idle TX state");
      @(negedge clk);
      reset     = 1'b0;
      serial_rx = 1'b1;
      clocks(3);
      send_postreset_probe();
    end
  endtask

  task automatic reset_during_tx_stop;
    integer done_before;
    integer errors_before;
    begin
      done_before   = tx_done_events;
      errors_before = rx_error_events;
      enqueue_tx(8'h3C);
      guard = 0;
      while (dut.transmitter.transmitter_control.state !== 4'b1000 && guard < 12 * BIT_CYCLES) begin
        clocks(1);
        guard++;
      end
      if (dut.transmitter.transmitter_control.state !== 4'b1000 || !dut.tx_busy ||
          serial_tx !== 1'b1 || tx_done_tick)
        fail("reset fixture did not reach the active TX Stop interval");
      @(negedge clk);
      reset = 1'b1;
      #1;
      if (tx_done_tick || rx_activity || rx_receiving)
        fail("reset did not suppress UART status/events during TX Stop");
      clocks(1);
      if (serial_tx !== 1'b1 || dut.tx_busy || tx_done_tick || !rx_empty || rx_done_events != 0 ||
          rx_error_events != errors_before || tx_done_events != done_before)
        fail("reset during TX Stop emitted a completion or failed to clear resources");
      if (dut.receiver.receiver_control.state !== 5'b00001) fail("reset did not return RX to IDLE");
      if (data.get_boolean(
              "/expected/normal_done"
          ) || !data.get_boolean(
              "/expected/postreset_RX_IDLE"
          ) || data.get_integer(
              "/expected/postreset_TX"
          ) != 1)
        fail("TX reset manifest expectations are inconsistent");
      @(negedge clk);
      reset = 1'b0;
      clocks(3);
      send_postreset_probe();
    end
  endtask

  task automatic run_case;
    begin
      if (data.has_path("/inputs/direction")) begin
        run_nominal_rx();
      end else if (data.case_id == "TEST-UART-001/C026") begin
        run_false_start();
      end else if (data.case_id == "TEST-UART-001/C027") begin
        run_bad_stop_with_tx();
      end else if (data.case_id == "TEST-UART-001/C028") begin
        run_bad_stop(1'b1);
      end else if (data.case_id == "TEST-UART-001/C030") begin
        reset_during_rx_data();
      end else if (data.case_id == "TEST-UART-001/C031") begin
        reset_during_tx_stop();
      end else begin
        fail("case ID is not assigned to this integration bench");
      end
    end
  endtask

  initial begin
    data.load();
    clocks(2);
    if (serial_tx !== 1'b1 || !rx_empty || tx_full || rx_activity || rx_receiving ||
        rx_error_tick || tx_done_tick || dut.rx_fifo.count != 0 || dut.tx_fifo.count != 0)
      fail("reset did not initialize the physical UART core");
    @(negedge clk);
    reset = 1'b0;
    if (data.case_id == "TEST-UART-001/C001") begin
      fail("C001 belongs to uart_core_tb full regression bank");
    end else begin
      run_case();
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
