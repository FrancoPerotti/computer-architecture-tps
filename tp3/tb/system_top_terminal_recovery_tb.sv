`timescale 1ns / 1ps

module system_top_terminal_recovery_tb;
  import system_pkg::*;
  localparam integer SILENCE_CLOCKS = 5_000_000;
  localparam time    CLOCK_PERIOD   = 20ns;
  localparam integer IMAGE_WORDS    = 8;

  logic clk = 0;
  logic reset = 1;
  wire serial_rx, serial_tx, uart_reset_request;
  integer tx_bytes = 0;
  integer rx_errors = 0;

  system_uart_host #(.BAUD_RATE(UART_BAUD_RATE)) host (.*);
  system_top dut (.*);
  always #(CLOCK_PERIOD / 2) clk = ~clk;

  always @(posedge clk) begin
    if (!reset && dut.tx_done_tick) tx_bytes++;
    if (!reset && dut.rx_error_tick) rx_errors++;
    if (!reset && dut.response_start && dut.response_opcode == CMD_RUN &&
        dut.response_result == RESULT_FINISHED) begin
      if (dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX ||
          !dut.controller_inst.run_result_required || !dut.response_with_debug)
        $fatal(1, "RUN terminal result was not captured during recovery");
    end
  end

  function automatic logic [31:0] image_word(input integer index);
    // Nested counters leave enough time for RUN/ACCEPTED and the bad Stop.
    case (index)
      0: return 32'h0c800093;  // addi x1,x0,200
      1: return 32'h0c800113;  // addi x2,x0,200
      2: return 32'hfff10113;  // addi x2,x2,-1
      3: return 32'hfe011ee3;  // bne x2,x0,-4
      4: return 32'h0c800113;  // addi x2,x0,200
      5: return 32'hfff08093;  // addi x1,x1,-1
      6: return 32'hfe0098e3;  // bne x1,x0,-16
      default: return 32'h0000000b;  // halt
    endcase
  endfunction

  task automatic check_reopened_after_silence;
    wait (!dut.rx_activity);
    @(negedge clk);
    if (dut.controller_inst.inactivity_count !== 0) $fatal(1, "recovery did not restart silence");
    repeat (SILENCE_CLOCKS - 1) @(negedge clk);
    if (dut.controller_inst.inactivity_count !== 23'(SILENCE_CLOCKS - 1) ||
        dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX)
      $fatal(1, "recovery must wait for the full uninterrupted silence interval");
    @(negedge clk);
  endtask

  task automatic check_last_stop(input integer expected_tx_bytes, input bit activity_near_stop);
    wait (tx_bytes == expected_tx_bytes - 1);
    @(negedge serial_tx);  // Start of the final byte (zero, the last byte of used_count).
    @(posedge serial_tx);  // Start of its Stop bit.
    fork
      begin
        if (activity_near_stop) begin
          // Two clocks for the RX synchronizer, then one to consume activity.
          // The Controller must consume it one edge before the final TX Stop.
          #(host.BIT_TIME - 3 * CLOCK_PERIOD - CLOCK_PERIOD / 2);
          host.send_byte(CMD_CHECK_READY);
        end
      end
      begin
        #(host.BIT_TIME - CLOCK_PERIOD - CLOCK_PERIOD / 2);
        if (dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX ||
            !dut.controller_inst.debug_hold || !dut.response_busy ||
            dut.controller_inst.run_result_required || dut.controller_inst.inactivity_count !==
            23'(SILENCE_CLOCKS - 1) || dut.rx_activity !== activity_near_stop)
          $fatal(1, "wrong recovery/Debug state one edge before the final Stop");
        @(negedge clk);
        if (!dut.tx_done_tick || !dut.response_done_tick || !dut.controller_inst.debug_hold ||
            dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX ||
            dut.controller_inst.inactivity_count !==
            (activity_near_stop ? 23'd0 : 23'(SILENCE_CLOCKS - 1)))
          $fatal(1, "wrong recovery state at the final Stop");
        @(negedge clk);
        if (dut.controller_inst.debug_hold || dut.response_busy ||
            dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX)
          $fatal(1, "final Stop did not release Debug while preserving recovery");
        if (activity_near_stop) check_reopened_after_silence();
        else @(negedge clk);
        if (dut.controller_inst.protocol_state !== dut.controller_inst.WAIT_COMMAND)
          $fatal(1, "recovery did not reopen commands after both conditions were met");
      end
    join
  endtask

  initial begin : test
    string         case_id;
    bit            activity_near_stop;
    logic   [31:0] word_value;
    integer        expected_tx_bytes;
    if (!$value$plusargs(
            "CASE=%s", case_id
        ) || (case_id != "TEST-UART-006/C013" && case_id != "TEST-UART-006/C014"))
      $fatal(1, "expected TEST-UART-006/C013 or TEST-UART-006/C014");
    activity_near_stop = case_id == "TEST-UART-006/C014";
    repeat (10) @(negedge clk);
    reset = 0;

    host.load_header(40'(IMAGE_WORDS * 4));
    for (integer index = 0; index < IMAGE_WORDS * 4; index++) begin
      word_value = image_word(index / 4);
      host.send_byte(word_value[8*(index%4)+:8], index == IMAGE_WORDS * 4 - 1);
    end
    host.expect_header(CMD_LOAD, RESULT_DONE);
    host.send_byte(CMD_RUN, 1);
    host.expect_header(CMD_RUN, RESULT_ACCEPTED);
    wait (dut.controller_inst.protocol_state == dut.controller_inst.WAIT_RUN_END);
    @(negedge clk);
    if (dut.prepare_active || dut.program_finished || !dut.controller_inst.run_result_required)
      $fatal(1, "RUN must be executing when the framing error arrives");
    expected_tx_bytes = tx_bytes + int'(DEBUG_RESPONSE_FIXED_BYTES);

    host.send_byte(8'ha5, 0, 0);  // Invalid Stop on the RX wire.
    host.serial_rx = 1;
    @(negedge clk);
    if (rx_errors != 1 || dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX ||
        dut.program_finished)
      $fatal(1, "framing error did not enter recovery while RUN was executing");

    fork
      host.read_snapshot(CMD_RUN, RESULT_FINISHED);
      check_last_stop(expected_tx_bytes, activity_near_stop);
    join
    if (host.response[DEBUG_STATE_CODE_OFFSET] !== STATE_CODE_FINISHED ||
        host.response[DEBUG_IMAGE_VALID_OFFSET] !== 8'd1 || host.word_at(
            DEBUG_RF_OFFSET + PROTOCOL_WORD_BYTES
        ) !== 32'd0 || host.used_count !== 0 || tx_bytes != expected_tx_bytes || !dut.rx_empty)
      $fatal(1, "expected one complete terminal snapshot from the loaded program");

    host.send_byte(CMD_CHECK_READY, 1);
    host.expect_header(CMD_CHECK_READY, RESULT_READY);
    #(2 * host.FRAME_TIME);
    if (tx_bytes != expected_tx_bytes + int'(PROTOCOL_RESPONSE_HEADER_BYTES) ||
        serial_tx !== 1'b1 || rx_errors != 1 || uart_reset_request)
      $fatal(1, "unexpected traffic, framing error or reset during recovery");
    $display("PASS %s", case_id);
    $finish;
  end

  initial begin
    #300ms;
    $fatal(1, "terminal recovery watchdog");
  end
endmodule
