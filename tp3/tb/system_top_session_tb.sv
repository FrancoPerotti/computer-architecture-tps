`timescale 1ns / 1ps

module system_top_session_tb #(
    parameter integer          CASE_INDEX = 1,
    parameter longint unsigned BAUD_RATE  = 64'd3_125_000
);
  import system_pkg::*;
  logic       clk = 0;
  logic       button = 1;
  logic [1:0] reset_pipe = 2'b11;
  wire serial_rx, serial_tx, uart_reset_request;
  wire    reset = reset_pipe[1];
  wire    reset_request = button || uart_reset_request;
  integer clock_index = 0;
  integer reset_ack_clock = -1;
  integer first_free_clock = -1;

  system_uart_host #(
      .BAUD_RATE     (BAUD_RATE),
      .MAX_USED_BYTES(4)
  ) host (
      .*
  );
  system_top #(.BAUD_RATE(BAUD_RATE)) dut (.*);

  always #10ns clk = ~clk;
  // Functional model of the platform's common reset conditioner.
  always @(posedge clk or posedge reset_request) begin
    if (reset_request) reset_pipe <= 2'b11;
    else reset_pipe <= {reset_pipe[0], 1'b0};
  end

  always @(posedge clk) begin
    clock_index = clock_index + 1;
    if (!reset && dut.response_done_tick && dut.serializer_inst.descriptor[16:9] == 8'h04)
      reset_ack_clock = clock_index;
    if (!reset && clock_index > reset_ack_clock && reset_ack_clock >= 0 && first_free_clock < 0)
      first_free_clock = clock_index;
  end

  task automatic check_ready;
    host.send_byte(8'h05, 1);
    host.expect_header(8'h05, 8'h03);
  endtask

  task automatic load_word(input logic [31:0] instruction);
    host.load_header(40'd4);
    for (integer index = 0; index < 4; index++) host.send_byte(instruction[8*index+:8], index == 3);
    host.expect_header(8'h01, 8'h02);
  endtask

  task automatic check_cleared_session;
    if (dut.image_valid !== 0 || dut.global_state_code !== 8'h00 || dut.debug_pc !== 0 ||
        dut.debug_cycle_count !== 0 || dut.debug_ifid_valid !== 0 || dut.debug_idex_valid !== 0 ||
        dut.debug_exmem_valid !== 0 || dut.debug_memwb_valid !== 0 || dut.debug_read_select !== 0 ||
        !dut.rx_empty || !dut.uart_inst.tx_empty)
      $fatal(1, "reset failed to clear the functional session");
    check_ready();
    host.send_byte(8'h03, 1);
    host.expect_header(8'h03, 8'h05);
  endtask

  initial begin : test
    #200ns;
    @(negedge clk);
    button = 0;
    repeat (3) @(negedge clk);

    case (CASE_INDEX)
      1: begin
        load_word(32'h0000006f);  // jal x0,0
        host.send_byte(8'h02, 1);
        host.expect_header(8'h02, 8'h01);
        host.send_byte(8'h04, 1);
        host.expect_header(8'h04, 8'h01);
        if (reset || dut.global_state_code !== 8'h04)
          $fatal(1, "RESET truncated ACCEPTED or paused RUN");
        @(posedge uart_reset_request);
        wait (first_free_clock >= 0);
        repeat (3) @(negedge clk);
        if (first_free_clock != reset_ack_clock + 4)
          $fatal(1, "RESET Stop at %0d, first free edge %0d", reset_ack_clock, first_free_clock);
        check_cleared_session();
        $display("PASS TEST-UART-013/C001");
      end
      2: begin
        load_word(32'h00000000);
        host.send_byte(8'h02, 1);
        host.expect_header(8'h02, 8'h01);
        host.read_snapshot(8'h02, 8'h0b);
        host.send_byte(8'h04, 1);
        host.expect_header(8'h04, 8'h01);
        @(posedge uart_reset_request);
        wait (first_free_clock >= 0);
        repeat (3) @(negedge clk);
        if (first_free_clock != reset_ack_clock + 4)
          $fatal(1, "RESET Stop at %0d, first free edge %0d", reset_ack_clock, first_free_clock);
        check_cleared_session();
        $display("PASS TEST-UART-013/C002");
      end
      7, 8, 9, 10: begin
        if (CASE_INDEX == 7) begin
          load_word(32'h0000006f);
          host.send_byte(8'h02, 1);
          host.expect_header(8'h02, 8'h01);
          if (!dut.cpu_cycle_fire) $fatal(1, "expected continuous RUN");
        end else if (CASE_INDEX == 8 || CASE_INDEX == 9) begin
          host.load_header(40'd4);
          if (CASE_INDEX == 8) begin
            host.send_byte(8'h0b);
            if (dut.global_state_code !== 8'h01) $fatal(1, "expected LOADING");
          end else begin
            host.send_byte(8'h0b);
            repeat (3) host.send_byte(8'h00);
            if (!dut.prepare_active) $fatal(1, "expected PREPARING_READY");
          end
        end else begin
          load_word(32'h0000000b);
          host.send_byte(8'h03, 1);
          host.expect_header(8'h03, 8'h02);
          if (!dut.debug_read_select) $fatal(1, "expected an active Debug response");
        end
        @(negedge clk);
        button = 1;
        repeat (3) @(negedge clk);
        if (!serial_tx) $fatal(1, "physical reset did not return TX to idle");
        button = 0;
        repeat (3) @(negedge clk);
        check_cleared_session();
        $display("PASS TEST-UART-013/C%03d", CASE_INDEX);
      end
      default: $fatal(1, "unsupported CASE_INDEX %0d", CASE_INDEX);
    endcase
    $finish;
  end

  initial begin
    #15ms;
    $fatal(1, "TEST-UART-013 bounded timeout, case %0d", CASE_INDEX);
  end
endmodule
