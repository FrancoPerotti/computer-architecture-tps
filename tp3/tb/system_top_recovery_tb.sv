`timescale 1ns / 1ps

module system_top_recovery_tb #(
    parameter integer CASE_INDEX   = 1,
    parameter bit     FULL_SILENCE = 0
);
  localparam longint unsigned BAUD_RATE      = 64'd3_125_000;
  localparam integer          SILENCE_CLOCKS = 5_000_000;
  logic clk = 0;
  logic reset = 1;
  wire serial_rx, serial_tx, uart_reset_request;
  integer captures = 0;
  integer received_errors = 0;

  system_uart_host #(.BAUD_RATE(BAUD_RATE)) host (.*);
  system_top #(.BAUD_RATE(BAUD_RATE)) dut (.*);
  always #10ns clk = ~clk;

  always @(posedge clk) begin
    if (!reset && dut.response_start) captures++;
    if (!reset && dut.rx_error_tick) received_errors++;
  end

  task automatic ready_query;
    host.send_byte(8'h05, 1);
    host.expect_header(8'h05, 8'h03);
  endtask

  task automatic load_image(input logic [31:0] instruction);
    host.load_header(40'd16);
    for (integer index = 0; index < 16; index++) begin
      if (index < 4) host.send_byte(instruction[index*8+:8]);
      else host.send_byte(0, index == 15);
    end
    host.expect_header(8'h01, 8'h02);
  endtask

  task automatic provoke_overflow;
`ifndef VERILATOR
    wait (!dut.response_busy);
    @(negedge clk);
    // Preload coherent FIFO state. In normal use the Controller drains
    // every edge, so a full FIFO at this boundary is a local fixture.
    for (integer slot = 0; slot < 4; slot++) dut.uart_inst.rx_fifo.memory[slot] = 8'(slot + 6);
    dut.uart_inst.rx_fifo.read_pointer  = 0;
    dut.uart_inst.rx_fifo.write_pointer = 0;
    dut.uart_inst.rx_fifo.count         = 4;
    force dut.uart_inst.rx_fifo.rd = 0;
    dut.controller_inst.protocol_state = dut.controller_inst.WAIT_RESPONSE_SENT;
    fork
      host.send_byte(8'h55);
      begin
        while (!dut.uart_inst.rx_done_tick) @(negedge clk);
        dut.controller_inst.protocol_state = dut.controller_inst.WAIT_COMMAND;
        #1ns;
        if (!dut.rx_error_tick || dut.response_start) $fatal(1, "overflow preflank priority");
        @(negedge clk);
        if (dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX)
          $fatal(1, "overflow did not enter recovery");
        force dut.uart_inst.rx_fifo.rd = 1;
        repeat (4) @(negedge clk);
        release dut.uart_inst.rx_fifo.rd;
      end
    join
`else
    $fatal(1, "RX overflow fixture requires Icarus");
`endif
  endtask

  task automatic complete_silence;
    wait (!dut.rx_activity);
    @(negedge clk);
    // Reproduce the last four clocks of the real counter without spending
    // 5M event-simulation clocks on every UART recovery transaction.
    if (FULL_SILENCE) begin
      wait (dut.controller_inst.inactivity_count == 23'(SILENCE_CLOCKS - 4));
      @(negedge clk);
    end else dut.controller_inst.inactivity_count = 23'(SILENCE_CLOCKS - 4);
    repeat (3) begin
      @(negedge clk);
      if (dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX)
        $fatal(1, "recovery released before continuous silence completed");
    end
    @(negedge clk);
  endtask

  initial begin : test
    integer before_error;
    integer before_responses;
    bit     content;
    repeat (10) @(negedge clk);
    reset = 0;
    load_image(CASE_INDEX == 5 ? 32'h0000006f : 32'h0000000b);
    content = CASE_INDEX == 11;
    if (CASE_INDEX == 5) begin
      host.send_byte(8'h02, 1);
      host.expect_header(8'h02, 8'h01);
      wait (dut.controller_inst.protocol_state == dut.controller_inst.WAIT_RUN_END);
    end else if (content) begin
      host.load_header(40'd8);
      host.send_byte(8'h0b);
    end else if (CASE_INDEX == 8) begin
      host.send_byte(8'h01);
      host.send_byte(8'h08);
    end

    before_responses = captures;
    before_error     = received_errors;
    if (CASE_INDEX == 1) begin
      host.serial_rx = 0;
      #(host.BIT_TIME / 4);
      host.serial_rx = 1;
      wait (received_errors == before_error + 1);
    end else if (CASE_INDEX == 3) begin
      provoke_overflow();
    end else if (CASE_INDEX == 8 || CASE_INDEX == 11) begin
      host.send_byte(8'h00, 1, 0);
      host.expect_header(8'h01, 8'h09);
      host.serial_rx = 1;
    end else begin
      host.send_byte(8'h55, 0, 0);
      host.serial_rx = 1;
    end
    @(negedge clk);
    if (dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX ||
        dut.image_valid !== !content)
      $fatal(1, "LOAD timeout/error changed the wrong image or skipped recovery");
    if (received_errors != before_error + 1) $fatal(1, "physical RX error was not delivered once");

    if (CASE_INDEX != 1 && CASE_INDEX != 3) begin
      host.send_byte(8'h05);
      host.send_byte(8'h04);
    end
    repeat (5) @(negedge clk);
    @(negedge clk);
    if (captures != before_responses + ((CASE_INDEX == 8 || CASE_INDEX == 11) ? 1 : 0) ||
        uart_reset_request || !dut.rx_empty)
      $fatal(
          1,
          "recovery got %0d responses after %0d, RESET=%b, RX depth=%0d",
          captures,
          before_responses,
          uart_reset_request,
          dut.uart_inst.rx_fifo.count
      );
    if (CASE_INDEX == 2) begin
      host.send_byte(8'ha5);
      @(negedge clk);
      dut.controller_inst.inactivity_count = 23'(SILENCE_CLOCKS - 8);
      host.serial_rx                       = 0;
      #(2 * host.BIT_TIME);
      if (dut.controller_inst.inactivity_count !== 0 ||
          dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX)
        $fatal(1, "RX activity near expiry did not restart silence");
      host.serial_rx = 1;
    end
    complete_silence();
    if (CASE_INDEX == 5) begin
      if (dut.controller_inst.protocol_state !== dut.controller_inst.WAIT_RUN_END ||
          !dut.controller_inst.run_result_required || !dut.cpu_cycle_fire)
        $fatal(1, "recovery paused or canceled RUN");
    end else begin
      if (dut.controller_inst.protocol_state !== dut.controller_inst.WAIT_COMMAND)
        $fatal(1, "recovery did not reopen commands");
      ready_query();
      if (content) begin
        host.send_byte(8'h02, 1);
        host.expect_header(8'h02, 8'h05);
      end else begin
        host.send_byte(8'h03, 1);
        host.read_snapshot(8'h03, 8'h02);
        if (host.response[1] !== 1 || host.cycles() !== 1)
          $fatal(1, "recovery changed the prior executable image");
      end
    end
    $display("PASS TEST-UART-006/C%03d", CASE_INDEX);
    $finish;
  end

  initial begin
    #(FULL_SILENCE ? 105ms : 3ms);
    $fatal(1, "system recovery watchdog");
  end
endmodule
