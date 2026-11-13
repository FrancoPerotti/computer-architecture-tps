`timescale 1ns / 1ps

module system_top_load_tb #(
    parameter integer          CASE_INDEX = 1,
    parameter longint unsigned BAUD_RATE  = 64'd3_125_000
);
  import system_pkg::*;

  localparam bit ALT_PROFILE = CASE_INDEX >= 10;
  localparam memory_capacity_t IMEM_BYTES = ALT_PROFILE ? ALT_1000_IMEM_CAPACITY_BYTES :
      REFERENCE_IMEM_CAPACITY_BYTES;
  localparam memory_capacity_t DMEM_BYTES = ALT_PROFILE ? ALT_1000_DMEM_CAPACITY_BYTES :
      REFERENCE_DMEM_CAPACITY_BYTES;
  logic clk = 0;
  logic reset = 1;
  wire  serial_rx;
  wire  serial_tx;
  wire  uart_reset_request;

  system_uart_host #(
      .BAUD_RATE     (BAUD_RATE),
      .MAX_USED_BYTES(4)
  ) host (
      .serial_tx,
      .serial_rx
  );
  system_top #(
      .IMEM_CAPACITY_BYTES(IMEM_BYTES),
      .DMEM_CAPACITY_BYTES(DMEM_BYTES),
      .BAUD_RATE          (BAUD_RATE)
  ) dut (
      .*
  );
  always #10ns clk = ~clk;

  function automatic integer valid_image_size;
    if (CASE_INDEX == 1 || CASE_INDEX == 10) valid_image_size = 4;
    else if (CASE_INDEX == 2) valid_image_size = 1024;
    else if (CASE_INDEX == 11) valid_image_size = 1000;
    else if (CASE_INDEX == 9 || CASE_INDEX == 18) valid_image_size = 4;
    else valid_image_size = 16;
  endfunction

  function automatic logic [39:0] requested_size;
    case (CASE_INDEX)
      3, 12: requested_size = 40'd0;
      4, 13: requested_size = 40'd6;
      5: requested_size = 40'd1028;
      14: requested_size = 40'd1004;
      6, 15: requested_size = 40'h0100_0000_00;
      7, 16: requested_size = 40'h0100_0000_04;
      8, 17: requested_size = 40'h8000_0000_00;
      default: requested_size = 40'(valid_image_size());
    endcase
  endfunction

  function automatic logic [31:0] image_word(input integer word_index);
    integer immediate_value;
    begin
      if (CASE_INDEX == 9 || CASE_INDEX == 18) image_word = 32'h0000_0000;
      else if (CASE_INDEX == 1 || CASE_INDEX == 10) image_word = 32'h0000_000b;
      else if (CASE_INDEX == 2 || CASE_INDEX == 11) begin
        if (word_index == valid_image_size() / 4 - 1) image_word = 32'h0000_000b;
        else begin
          immediate_value = word_index;
          image_word      = (32'(immediate_value) << 20) | 32'h0000_0093;
        end
      end else begin
        case (word_index)
          0: image_word = 32'h0070_0293;  // addi x5,x0,7
          1, 2: image_word = 32'h0000_0013;  // addi x0,x0,0
          3: image_word = 32'h0000_000b;
          default: image_word = '0;
        endcase
      end
    end
  endfunction

  integer        delivered = 0;
  integer        expected_size = 0;
  integer        cycle = 0;
  integer        publish_cycle = -1;
  logic   [31:0] expected_word;

  always @(posedge clk) begin
    cycle++;
    if (dut.load_request) begin
      if (!dut.command_accepted || dut.load_size_bytes != expected_size || !dut.response_start ||
          dut.response_opcode != 1 || dut.response_result != 1)
        $fatal(1, "LOAD handshake mismatch at clock %0d", cycle);
      delivered     = 0;
      publish_cycle = -1;
    end
    if (dut.load_byte_valid) begin
      expected_word = image_word(delivered / 4);
      if (dut.load_byte_offset != delivered || dut.load_byte_data !== expected_word[
          8*(delivered%4)+:8] || dut.load_last_byte !== (delivered == expected_size - 1) ||
          dut.processor_inst.g_valid_capacity.imem_write_enable !== (delivered % 4 == 3) ||
          dut.processor_inst.g_valid_capacity.load_ok !== (delivered == expected_size - 1) ||
          dut.image_valid || dut.cpu_cycle_fire)
        $fatal(1, "LOAD delivery mismatch at byte %0d", delivered);
      delivered++;
    end
    if (dut.processor_inst.g_valid_capacity.prepare_done) publish_cycle = cycle;
    if (dut.response_start && dut.response_opcode == 1 && dut.response_result == 2) begin
      if (publish_cycle != cycle - 1 || dut.prepare_active || !dut.image_valid ||
          dut.processor_inst.g_valid_capacity.loaded_image_size_bytes != expected_size ||
          delivered != expected_size || dut.global_state_code != 3 || dut.debug_cycle_count != 0)
        $fatal(1, "LOAD/DONE must follow publication by one clock");
    end
  end

  task automatic send_image(input integer image_size);
    integer        index;
    logic   [31:0] word_value;
    begin
      for (index = 0; index < image_size; index = index + 1) begin
        word_value = image_word(index / 4);
        host.send_byte(word_value[(index%4)*8+:8], index == image_size - 1);
      end
      host.expect_header(8'h01, 8'h02);
    end
  endtask

  task automatic send_valid_load(input integer image_size);
    expected_size = image_size;
    host.send_byte(8'h05, 1);
    host.expect_header(8'h05, 8'h03);
    host.load_header(40'(image_size));
    send_image(image_size);
  endtask

  task automatic send_invalid_load(input logic [39:0] image_size);
    host.send_byte(8'h05, 1);
    host.expect_header(8'h05, 8'h03);
    host.load_header(image_size, 8'h06);
    if (!dut.image_valid || dut.processor_inst.g_valid_capacity.loaded_image_size_bytes != 16)
      $fatal(1, "invalid LOAD changed the previous image");
  endtask

  task automatic run_and_read(input byte unsigned terminal_result);
    byte unsigned value;
    begin
      host.send_byte(8'h02, 1'b1);
      host.expect_header(8'h02, 8'h01);
      host.read_snapshot(8'h02, terminal_result);
      if (terminal_result == 8'h0a) begin
        if (host.response[0] !== 8'h0a) $fatal(1, "RUN did not finish normally");
        if (host.response[39] !== 8'd7 || host.response[40] !== 0 || host.response[41] !== 0 ||
            host.response[42] !== 0)
          $fatal(1, "preserved image x5 expected 7");
      end else begin
        if (host.response[0] !== 8'h0b || host.response[14] !== 8'd2 || host.response[15] !== 0 ||
            host.response[16] !== 0 || host.response[17] !== 0 || host.response[18] !== 0)
          $fatal(1, "loaded illegal word did not fault at PC zero");
      end
      value = host.response[1];
      if (!value[0]) $fatal(1, "RUN snapshot lost image_valid");
    end
  endtask

  initial begin : test
    byte unsigned        state_value;
    logic         [39:0] rejected_size;
    logic         [31:0] expected_first_word;
    #200ns;
    @(negedge clk);
    reset = 1'b0;

    if ((CASE_INDEX >= 3 && CASE_INDEX <= 8) || (CASE_INDEX >= 12 && CASE_INDEX <= 17)) begin
      send_valid_load(16);
      rejected_size = requested_size();
      send_invalid_load(rejected_size);
      run_and_read(8'h0a);
    end else begin
      send_valid_load(valid_image_size());
      if (CASE_INDEX == 9 || CASE_INDEX == 18) begin
        run_and_read(8'h0b);
      end else begin
        host.send_byte(8'h03, 1'b1);
        host.read_snapshot(8'h03, 8'h02);
        state_value = host.response[0];
        if (host.response[1] !== 8'h01) $fatal(1, "LOAD did not publish a valid image");
        if (host.cycles() !== 64'd1)
          $fatal(1, "LOAD publication caused a CPU cycle or STEP did not fire once");
        expected_first_word = (CASE_INDEX == 1 || CASE_INDEX == 10) ? 32'h0000_000b : 32'h0000_0093;
        if (!host.response[147][0] || host.response[148] != 0 || host.response[149] != 0 ||
            host.response[150] != 0 || host.response[151] != 0 ||
            {host.response[155], host.response[154], host.response[153], host.response[152]} !==
            expected_first_word)
          $fatal(1, "first instruction was not reconstructed at IMEM address zero");
        if (state_value !== 8'h05) $fatal(1, "first post-LOAD STEP did not remain in STEPPING");
      end
    end

    $display("PASS TEST-UART-004/C%03d", CASE_INDEX);
    $finish;
  end

  initial begin
    #(1400 * host.FRAME_TIME + 100us);
    $fatal(1, "TEST-UART-004 bounded timeout");
  end
endmodule
