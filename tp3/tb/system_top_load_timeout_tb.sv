`timescale 1ns / 1ps

module system_top_load_timeout_tb #(
    parameter longint unsigned BAUD_RATE = system_pkg::UART_BAUD_RATE
);
  localparam integer LIMIT = 5_000_000;
  integer case_index;
  bit     content;
  integer group_index;
  integer partial_bytes;
  integer rx_frame_latency = 0;

  logic clk = 0;
  logic reset = 1;
  wire serial_rx, serial_tx, uart_reset_request;
  integer cycles = 0;
  integer start_cycle = 0;
  integer event_cycle = 0;
  integer deliveries = 0;
  integer last_rx_cycle = 0;
  bit     monitor = 0;

  system_uart_host #(.BAUD_RATE(BAUD_RATE)) host (.*);
  system_top #(.BAUD_RATE(BAUD_RATE)) dut (.*);
  always #10ns clk = ~clk;

  always @(posedge clk) begin
    cycles++;
    if (monitor && !reset) begin
      if (dut.rx_error_tick) $fatal(1, "unexpected UART error at timeout boundary");
      if (dut.rd_uart) last_rx_cycle = cycles;
      if (dut.response_start) event_cycle = cycles;
      if (dut.load_byte_valid) deliveries++;
    end
  end

  task automatic send_prior_image;
    host.load_header(40'd16);
    host.send_byte(8'h0b);
    repeat (14) host.send_byte(0);
    host.send_byte(0, 1);
    host.expect_header(1, 2);
  endtask

  initial begin : test
    integer expiry_cycle;
    integer before_deliveries;
    string  case_id;
    if (!$value$plusargs(
            "CASE=%s", case_id
        ) || $sscanf(
            case_id, "TEST-UART-005/C%d", case_index
        ) != 1 || case_index < 1 || case_index > 12)
      $fatal(1, "expected a system LOAD timeout case");
    content       = case_index >= 4;
    group_index   = (case_index - 1) % 3;
    partial_bytes = case_index <= 3 ? 2 : case_index <= 6 ? 1 : case_index <= 9 ? 3 : 4;
    repeat (10) @(negedge clk);
    reset = 0;
    send_prior_image();

    if (content) host.load_header(40'd8);
    else host.send_byte(8'h01);
    monitor = 1;
    for (integer index = 0; index < partial_bytes; index++) begin
      @(negedge clk);
      start_cycle = cycles;
      host.send_byte(!content && index == 0 ? 8'd8 : 8'd0);
      rx_frame_latency = last_rx_cycle - start_cycle;
    end
    @(negedge clk);
    start_cycle = last_rx_cycle;
    if (start_cycle == 0 || dut.image_valid !== !content ||
        dut.controller_inst.inactivity_count >= 23'd10000)
      $fatal(1, "LOAD setup did not start its timer on a delivered byte");
    expiry_cycle      = start_cycle + LIMIT;
    before_deliveries = deliveries;

    if (group_index == 0) begin
      while (cycles < expiry_cycle - 10001) @(negedge clk);
      fork
        host.send_byte(8'h00);
        host.expect_header(1, content ? 8'h08 : 8'h07);
      join
      if (event_cycle != expiry_cycle)
        $fatal(
            1, "LOAD inactivity deadline: expected %0d, observed %0d", expiry_cycle, event_cycle
        );
      if (dut.image_valid !== !content || deliveries != before_deliveries ||
          dut.controller_inst.protocol_state !== dut.controller_inst.RECOVER_RX)
        $fatal(1, "timeout published a partial image or skipped recovery");
    end else begin
      // At divisor 1 each Start at negedge has the same measured RX latency.
      while (cycles < expiry_cycle - (group_index == 1 ? 1 : 0) - rx_frame_latency) @(negedge clk);
      host.send_byte(0);
      @(negedge clk);
      if (last_rx_cycle != expiry_cycle - (group_index == 1 ? 1 : 0) || event_cycle != 0 ||
          dut.image_valid !== !content || deliveries != before_deliveries + int'(content) ||
          dut.controller_inst.inactivity_count >= 23'd10000)
        $fatal(
            1,
            "RX at %0d, expiry %0d, response at %0d, frame latency %0d",
            last_rx_cycle,
            expiry_cycle,
            event_cycle,
            rx_frame_latency
        );
    end

    $display("PASS TEST-UART-005/C%03d", case_index);
    $finish;
  end

  initial begin
    #135ms;
    $fatal(1, "LOAD timeout watchdog");
  end
endmodule
