`timescale 1ns / 1ps

// Verifica UART TX con baud_tick_gen real y fases canónicas del catálogo.
module uart_tx_phase_tb;
  localparam integer DATA_WIDTH = system_pkg::UART_DATA_BITS;
  localparam
      integer DIVISOR = (system_pkg::FUNCTIONAL_CLOCK_HZ +
                         (system_pkg::UART_BAUD_RATE * system_pkg::UART_OVERSAMPLE_FACTOR) / 2) /
      (system_pkg::UART_BAUD_RATE * system_pkg::UART_OVERSAMPLE_FACTOR);

  tp3_case_data data ();
  logic                    clk = 1'b0;
  logic                    reset = 1'b1;
  logic                    tx_start = 1'b0;
  logic   [DATA_WIDTH-1:0] data_in = '0;
  logic                    s_tick;
  logic                    tx;
  logic                    tx_busy;
  logic                    tx_done_tick;
  integer                  reference_phase = 0;
  integer                  reference_cycles = 0;
  integer                  previous_tick_cycle = 0;
  integer                  tick_events = 0;
  integer                  done_events = 0;
  integer                  tick_base;
  integer                  ticks_since_start;
  integer                  start_phase;
  integer                  tx_value;
  integer                  guard;

  baud_tick_gen tick_generator (.*);
  uart_tx transmitter (
      .clk,
      .reset,
      .tx_start,
      .s_tick,
      .data_in,
      .tx,
      .tx_busy,
      .tx_done_tick
  );

  always #10 clk = ~clk;

  always @(posedge clk) begin
    if (reset) begin
      reference_phase     = 0;
      reference_cycles    = 0;
      previous_tick_cycle = 0;
      tick_events         = 0;
      done_events         = 0;
    end else begin
      reference_cycles++;
      if (reference_phase == DIVISOR - 1) reference_phase = 0;
      else reference_phase++;
      if (s_tick) begin
        tick_events++;
        if (previous_tick_cycle == 0 && reference_cycles != DIVISOR + 1)
          fail("primer tick no se consumio en el flanco 164");
        if (previous_tick_cycle != 0 && reference_cycles - previous_tick_cycle != DIVISOR)
          fail("s_tick no conserva el periodo de 163 clocks");
        previous_tick_cycle = reference_cycles;
      end
      if (tx_done_tick) done_events++;
    end
  end

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic clock_step;
    @(posedge clk);
    #1;
  endtask

  task automatic clocks(input integer count);
    repeat (count) clock_step();
  endtask

  task automatic clocks_until_phase(input integer target_phase);
    if (target_phase < 0 || target_phase >= DIVISOR) fail("start phase outside generator period");
    while (reference_phase != target_phase) @(negedge clk);
  endtask

  task automatic advance_ticks(input integer total_ticks, input logic expected_level,
                               input logic final_completion);
    integer consumed;
    integer done_before;
    logic   prior_level;
    begin
      consumed    = tick_events - tick_base;
      done_before = done_events;
      prior_level = tx;
      if (consumed > total_ticks) fail("unexpected extra tick before a TX boundary");
      while (consumed < total_ticks) begin
        @(posedge clk);
        if (s_tick) begin
          consumed++;
          #1;
          if (consumed < total_ticks && tx !== prior_level)
            fail("TX level changed before the sixteenth oversample tick");
          prior_level = tx;
        end else begin
          #1;
          if (tx !== prior_level) fail("TX changed without a consumed s_tick");
        end
        if (tx_done_tick && !final_completion) fail("tx_done_tick asserted before final Stop tick");
      end
      if (tx !== expected_level) fail("TX level at bit boundary is incorrect");
      if (final_completion) begin
        if (done_events != done_before + 1 || tx_busy || tx_done_tick)
          fail("tx_done_tick/busy did not finish on the final Stop edge");
      end else if (!tx_busy || tx_done_tick) begin
        fail("TX busy/event state changed at a nonfinal boundary");
      end
    end
  endtask

  task automatic transmit_case(input integer value, input integer phase_value,
                               input bit busy_probe);
    integer                  completion_before;
    integer                  expected_first_tick_delay;
    integer                  first_tick_delay;
    integer                  bit_index;
    logic   [DATA_WIDTH-1:0] expected_data;
    begin
      expected_data = DATA_WIDTH'(value);
      clocks_until_phase(phase_value);
      start_phase       = reference_phase;
      completion_before = done_events;
      data_in           = expected_data;
      tx_start          = 1'b1;
      @(posedge clk);
      #1;
      tick_base = tick_events;
      if (!tx_busy || tx !== 1'b0 || transmitter.transmitter_datapath.data_reg !== expected_data)
        fail("tx_start did not capture the byte and begin Start immediately");
      @(negedge clk);
      tx_start = 1'b0;

      if (busy_probe) begin
        @(negedge clk);
        tx_start = data.get_integer("/inputs/tx_start_while_busy");
        data_in  = DATA_WIDTH'(data.get_integer("/inputs/new_data_while_busy"));
        @(posedge clk);
        #1;
        if (!tx_busy || tx !== 1'b0 || transmitter.transmitter_datapath.data_reg !== expected_data)
          fail("busy TX accepted a request or changed the byte already captured");
        @(negedge clk);
        tx_start          = 1'b0;
        ticks_since_start = tick_events - tick_base;
        if (data.get_boolean("/expected/additional_start_accepted"))
          fail("catalog expects an extra TX start while busy");
      end else begin
        expected_first_tick_delay = (start_phase == DIVISOR - 1) ? 1 : DIVISOR;
        first_tick_delay          = 0;
        while (tick_events == tick_base && first_tick_delay <= DIVISOR) begin
          @(posedge clk);
          first_tick_delay++;
          #1;
        end
        if (tick_events != tick_base + 1 || first_tick_delay != expected_first_tick_delay)
          fail($sformatf(
               "first consumed tick phase mismatch: expected delay %0d, observed %0d",
               expected_first_tick_delay,
               first_tick_delay
               ));
        ticks_since_start = 1;
      end

      advance_ticks(16, expected_data[0], 1'b0);
      ticks_since_start = 16;
      if (transmitter.transmitter_control.state !== 4'b0100)
        fail("Start did not transition to DATA after 16 ticks");
      for (bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
        if (tx !== expected_data[bit_index]) fail("D0-D7 order is incorrect");
        if (bit_index < DATA_WIDTH - 1) begin
          advance_ticks(ticks_since_start + 16, expected_data[bit_index+1], 1'b0);
          ticks_since_start += 16;
        end else begin
          advance_ticks(ticks_since_start + 16, 1'b1, 1'b0);
          ticks_since_start += 16;
          if (transmitter.transmitter_control.state !== 4'b1000)
            fail("D7 did not transition to STOP after its complete interval");
        end
      end

      advance_ticks(ticks_since_start + 15, 1'b1, 1'b0);
      ticks_since_start += 15;
      if (!tx_busy || done_events != completion_before)
        fail("TX completed before the full Stop interval");
      advance_ticks(ticks_since_start + 1, 1'b1, 1'b1);
      if (done_events != completion_before + 1)
        fail("TX did not produce exactly one completion event");
      if (busy_probe && data.get_integer("/expected/transmitted_byte") != value)
        fail("catalog TX byte differs from expected captured byte");
      if (tx !== 1'b1 || tx_busy || tx_done_tick) fail("TX did not return to idle-high");
      clocks(2);
      if (done_events != completion_before + 1 || tx_busy)
        fail("busy TX request caused an unintended second transmission");
    end
  endtask

  initial begin
    data.load();
    clocks_until_phase(0);
    clocks(2);
    if (tx !== 1'b1 || tx_busy || tx_done_tick) fail("TX reset state incorrect");
    @(negedge clk);
    reset = 1'b0;

    if (data.case_id == "TEST-UART-001/C029") begin
      tx_value = data.get_integer("/inputs/TX_byte");
      if (data.get_integer(
              "/inputs/new_data_while_busy"
          ) != 8'hAA || data.get_boolean(
              "/expected/additional_start_accepted"
          ))
        fail("C029 catalog fixture mismatch");
      transmit_case(tx_value, 0, 1'b1);
    end else begin
      tx_value    = data.get_integer("/inputs/byte");
      start_phase = data.get_integer("/inputs/start_tick_phase");
      if (data.get_string(
              "/inputs/direction"
          ) != "TX" || data.get_integer(
              "/expected/decoded_byte"
          ) != tx_value || !data.get_boolean(
              "/expected/one_done"
          ))
        fail("TX nominal vector differs from catalog");
      transmit_case(tx_value, start_phase, 1'b0);
    end

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
