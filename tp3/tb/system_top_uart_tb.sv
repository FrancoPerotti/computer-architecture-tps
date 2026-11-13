`timescale 1ns / 1ps

module system_top_uart_tb #(
    parameter integer          CASE_INDEX = 2,
    parameter longint unsigned BAUD_RATE  = 64'd3_125_000
);
  import system_pkg::*;

  logic         clk = 0;
  logic         reset = 1;
  wire          serial_rx;
  wire          serial_tx;
  wire          uart_reset_request;
  byte unsigned first_step_snapshot[DEBUG_FIXED_BYTES + 20];
  integer       first_length;

  system_uart_host #(
      .BAUD_RATE     (BAUD_RATE),
      .MAX_USED_BYTES(4)
  ) host (
      .serial_tx,
      .serial_rx
  );
  system_top #(.BAUD_RATE(BAUD_RATE)) dut (.*);
  always #10ns clk = ~clk;

  function automatic integer image_size;
    image_size = (CASE_INDEX == 5) ? 4 : 20;
  endfunction

  function automatic logic [31:0] image_word(input integer index);
    case (index)
      0: image_word = (CASE_INDEX == 5) ? 32'h0000_000b : 32'h0030_0113;
      // C005 uses only halt; other cases begin with addi x2,x0,3.
      1: image_word = 32'h00b0_0413;  // addi x8,x0,11
      2: image_word = 32'h00c0_0493;  // addi x9,x0,12
      3: image_word = 32'h0020_2223;  // sw x2,4(x0)
      4: image_word = (CASE_INDEX == 3 || CASE_INDEX == 4) ? 32'h0000_0000 : 32'h0000_000b;
      default: image_word = '0;
    endcase
  endfunction

  task automatic send_load_image;
    integer        index;
    logic   [31:0] word_value;
    begin
      host.send_byte(8'h01);
      host.send_byte(image_size());
      host.send_byte(8'h00);
      host.send_byte(8'h00);
      host.send_byte(8'h00);
      host.send_byte(8'h00, 1'b1);
      host.expect_header(8'h01, 8'h01);
      for (index = 0; index < image_size(); index = index + 1) begin
        word_value = image_word(index / 4);
        host.send_byte(word_value[(index%4)*8+:8], index == image_size() - 1);
      end
      host.expect_header(8'h01, 8'h02);
    end
  endtask

  task automatic check_effects;
    if (host.word_at(
            19 + 4 * 2
        ) !== 3 || host.word_at(
            19 + 4 * 8
        ) !== 11 || host.word_at(
            19 + 4 * 9
        ) !== 12 || host.used_count !== 4)
      $fatal(1, "snapshot RF or used_count differs from the program result");
    for (integer index = 0; index < 4; index++)
      host.check_entry(index, 32'(4 + index), index == 0 ? 8'd3 : 8'd0);
  endtask

  integer step_fires = 0;
  always @(posedge clk) begin
    if (!reset && dut.response_start && dut.response_opcode == 3 && dut.response_with_debug) begin
      if (!dut.cpu_cycle_fire || dut.response_busy)
        $fatal(1, "STEP/DONE was captured outside its CPU cycle");
      step_fires++;
    end
    if (!reset && dut.debug_read_select && (dut.cpu_cycle_fire || dut.prepare_active))
      $fatal(1, "Debug observation overlapped CPU or preparation");
  end

  function automatic bit snapshot_byte_is_meaningful(input integer index);
    begin
      snapshot_byte_is_meaningful = 1'b1;
      // Global fault metadata remains latched after its validity ends. The
      // protocol defines it as meaningful only during a fault drain or in FAULT.
      if (index >= 14 && index <= 18 && host.response[0] != 8'h08 && host.response[0] != 8'h09 &&
          host.response[0] != 8'h0b)
        snapshot_byte_is_meaningful = 1'b0;
      if (index >= 148 && index <= 151 && !(host.response[147][0] || host.response[156][0]))
        snapshot_byte_is_meaningful = 1'b0;
      if (index >= 152 && index <= 155 && !host.response[147][0])
        snapshot_byte_is_meaningful = 1'b0;
      if (index == 157 && !host.response[156][0]) snapshot_byte_is_meaningful = 1'b0;
      if (index >= 159 && index <= 187 && !host.response[158][0])
        snapshot_byte_is_meaningful = 1'b0;
      if (index >= 189 && index <= 207 && !host.response[188][0])
        snapshot_byte_is_meaningful = 1'b0;
      if (index >= 209 && index <= 222 && !host.response[208][0])
        snapshot_byte_is_meaningful = 1'b0;
    end
  endfunction

  task automatic compare_architectural_snapshots(input integer length);
    integer i;
    begin
      if (length != first_length) $fatal(1, "new-session snapshot length differs");
      for (i = 0; i < length; i = i + 1) begin
        if (snapshot_byte_is_meaningful(i) && host.response[i] !== first_step_snapshot[i])
          $fatal(
              1,
              "new-session architectural snapshot differs at byte %0d: expected %02x got %02x",
              i,
              first_step_snapshot[i],
              host.response[i]
          );
      end
    end
  endtask

  initial begin : test
    integer i;
    integer length;
    integer steps;
    #200ns;
    @(negedge clk);
    reset = 1'b0;

    host.send_byte(8'h05, 1);
    host.expect_header(8'h05, 8'h03);
    send_load_image();

    if (CASE_INDEX == 1 || CASE_INDEX == 3 || CASE_INDEX == 5) begin
      host.send_byte(8'h02, 1'b1);
      host.expect_header(8'h02, 8'h01);
      host.read_snapshot(8'h02, CASE_INDEX == 3 ? 8'h0b : 8'h0a);
      if (CASE_INDEX == 3) begin
        if (host.response[0] !== 8'h0b || host.response[14] !== 8'd2 ||
            {host.response[18], host.response[17], host.response[16], host.response[15]} !== 32'd16)
          $fatal(1, "RUN FAULT snapshot metadata mismatch");
      end else if (host.response[0] !== 8'h0a) $fatal(1, "RUN snapshot state expected FINISHED");
      if (CASE_INDEX != 5) check_effects();
      $display("PASS TEST-UART-010/C%03d", CASE_INDEX);
      $finish;
    end

    steps        = 0;
    first_length = 0;
    while (steps < 64) begin
      host.send_byte(8'h03, 1'b1);
      host.read_snapshot(8'h03, 8'h02);
      length = DEBUG_FIXED_BYTES + 5 * int'(host.used_count);
      steps  = steps + 1;
      if (host.cycles() !== 64'(steps) || step_fires != steps || host.response[1] !== 1)
        $fatal(1, "STEP %0d did not observe exactly one cycle", steps);
      if (steps == 1 && (host.word_at(
              2
          ) !== 32'd4 || host.response[147] !== 1 || host.word_at(
              148
          ) !== 0 || host.word_at(
              152
          ) !== image_word(
              0
          ) || host.response[158] !== 0 || host.response[188] !== 0 || host.response[208] !== 0))
        $fatal(1, "first STEP did not observe the post-fetch latches");
      if (steps == 1) begin
        first_length = length;
        for (i = 0; i < length; i = i + 1) first_step_snapshot[i] = host.response[i];
      end
      if (CASE_INDEX == 4 && host.response[0] == 8'h0b) begin
        if (host.response[14] !== 8'd2 || host.response[15] !== 8'd16 || host.response[16] !== 0 ||
            host.response[17] !== 0 || host.response[18] !== 0)
          $fatal(1, "FAULT snapshot metadata mismatch");
        break;
      end
      if (CASE_INDEX == 2 && host.response[0] == 8'h0a) break;
    end
    if (steps >= 64) $fatal(1, "TEST-UART-010 did not reach its terminal within 64 STEP commands");

    check_effects();

    // C002 and C004 require a new-session first STEP after the terminal response's final Stop.
    if (CASE_INDEX == 2 || CASE_INDEX == 4) begin
      host.send_byte(8'h03, 1'b1);
      host.read_snapshot(8'h03, 8'h02);
      length = DEBUG_FIXED_BYTES + 5 * int'(host.used_count);
      if (host.cycles() !== 64'd1 || step_fires != steps + 1)
        $fatal(1, "restart STEP did not execute the first cycle of the new session");
      compare_architectural_snapshots(length);
    end
    $display("PASS TEST-UART-010/C%03d", CASE_INDEX);
    $finish;
  end

  initial begin
    #(70 * 251 * host.FRAME_TIME + 100us);
    $fatal(1, "TEST-UART-010 bounded timeout");
  end
endmodule
