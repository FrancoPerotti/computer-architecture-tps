`timescale 1ns / 1ps

module system_top_load_tb #(
    parameter integer CASE_INDEX = 1
);
  import system_pkg::*;

  localparam bit ALT_PROFILE = CASE_INDEX >= 10;
  localparam memory_capacity_t IMEM_BYTES = ALT_PROFILE ? ALT_1000_IMEM_CAPACITY_BYTES :
      REFERENCE_IMEM_CAPACITY_BYTES;
  localparam memory_capacity_t DMEM_BYTES = ALT_PROFILE ? ALT_1000_DMEM_CAPACITY_BYTES :
      REFERENCE_DMEM_CAPACITY_BYTES;
  localparam integer BIT_CYCLES = 2608;
  localparam time BIT_TIME = 20ns * BIT_CYCLES;
  localparam integer MAX_RESPONSE = 1024;

  logic         clk = 1'b0;
  logic         reset = 1'b1;
  logic         serial_rx = 1'b1;
  logic         serial_tx;
  logic         uart_reset_request;
  byte unsigned response           [MAX_RESPONSE];
  integer       used_count;

  system_top #(
      .IMEM_CAPACITY_BYTES(IMEM_BYTES),
      .DMEM_CAPACITY_BYTES(DMEM_BYTES)
  ) dut (
      .*
  );
  always #10ns clk = ~clk;

  task automatic tx_byte(input byte unsigned value, input bit response_follows = 1'b0);
    integer bit_index;
    begin
      serial_rx = 1'b0;
      #(BIT_TIME);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        serial_rx = value[bit_index];
        #(BIT_TIME);
      end
      serial_rx = 1'b1;
      if (response_follows) #(1ns);
      else #(BIT_TIME);
    end
  endtask

  task automatic rx_byte(output byte unsigned value);
    integer bit_index;
    begin
      @(negedge serial_tx);
      #(BIT_TIME + BIT_TIME / 2);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        value[bit_index] = serial_tx;
        #(BIT_TIME);
      end
      if (serial_tx !== 1'b1) $fatal(1, "UART TX stop bit was low");
    end
  endtask

  task automatic expect_header(input byte unsigned opcode, input byte unsigned result);
    byte unsigned value;
    begin
      rx_byte(value);
      if (value !== opcode) $fatal(1, "response opcode expected %02x got %02x", opcode, value);
      rx_byte(value);
      if (value !== result) $fatal(1, "response result expected %02x got %02x", result, value);
    end
  endtask

  task automatic read_debug_snapshot(input byte unsigned opcode, input byte unsigned result);
    byte unsigned value;
    integer       index;
    begin
      expect_header(opcode, result);
      for (index = 0; index < 223; index = index + 1) begin
        rx_byte(value);
        response[index] = value;
      end
      for (index = 0; index < 5; index = index + 1) begin
        rx_byte(value);
        response[223+index] = value;
      end
      used_count = response[223] | (response[224] << 8) | (response[225] << 16) |
          (response[226] << 24) | (response[227] << 32);
      if (used_count > 128) $fatal(1, "snapshot used_count out of range: %0d", used_count);
      for (index = 0; index < 5 * used_count; index = index + 1) begin
        rx_byte(value);
        response[228+index] = value;
      end
    end
  endtask

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

  task automatic send_image(input integer image_size);
    integer        index;
    logic   [31:0] word_value;
    begin
      for (index = 0; index < image_size; index = index + 1) begin
        word_value = image_word(index / 4);
        tx_byte(word_value[(index%4)*8+:8], index == image_size - 1);
      end
      expect_header(8'h01, 8'h02);
    end
  endtask

  task automatic send_valid_load(input integer image_size);
    begin
      tx_byte(8'h01);
      tx_byte(8'(image_size));
      tx_byte(8'(image_size >> 8));
      tx_byte(8'(image_size >> 16));
      tx_byte(8'(image_size >> 24));
      tx_byte(8'h00, 1'b1);
      expect_header(8'h01, 8'h01);
      send_image(image_size);
    end
  endtask

  task automatic send_invalid_load(input logic [39:0] image_size);
    integer index;
    begin
      tx_byte(8'h01);
      for (index = 0; index < 5; index = index + 1) tx_byte(image_size[index*8+:8], index == 4);
      expect_header(8'h01, 8'h06);
    end
  endtask

  task automatic run_and_read(input byte unsigned terminal_result);
    byte unsigned value;
    begin
      tx_byte(8'h02, 1'b1);
      expect_header(8'h02, 8'h01);
      read_debug_snapshot(8'h02, terminal_result);
      if (terminal_result == 8'h0a) begin
        if (response[0] !== 8'h0a) $fatal(1, "RUN did not finish normally");
        if (response[39] !== 8'd7 || response[40] !== 0 || response[41] !== 0 || response[42] !== 0)
          $fatal(1, "preserved image x5 expected 7");
      end else begin
        if (response[0] !== 8'h0b || response[14] !== 8'd2 || response[15] !== 0 ||
            response[16] !== 0 || response[17] !== 0 || response[18] !== 0)
          $fatal(1, "loaded illegal word did not fault at PC zero");
      end
      value = response[1];
      if (!value[0]) $fatal(1, "RUN snapshot lost image_valid");
    end
  endtask

  initial begin : test
    byte unsigned        state_value;
    integer              cycle_count;
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
        tx_byte(8'h03, 1'b1);
        read_debug_snapshot(8'h03, 8'h02);
        state_value = response[0];
        cycle_count = response[6] | (response[7] << 8) | (response[8] << 16) | (response[9] << 24);
        if (response[1] !== 8'h01) $fatal(1, "LOAD did not publish a valid image");
        if (cycle_count != 1)
          $fatal(1, "LOAD publication caused a CPU cycle or STEP did not fire once");
        expected_first_word = (CASE_INDEX == 1 || CASE_INDEX == 10) ? 32'h0000_000b : 32'h0000_0093;
        if (!response[147][0] || response[148] != 0 || response[149] != 0 || response[150] != 0 ||
            response[151] != 0 ||
            {response[155], response[154], response[153], response[152]} !== expected_first_word)
          $fatal(1, "first instruction was not reconstructed at IMEM address zero");
        if (state_value !== 8'h05) $fatal(1, "first post-LOAD STEP did not remain in STEPPING");
      end
    end

    $display("PASS TEST-UART-004/C%03d", CASE_INDEX);
    $finish;
  end

  initial begin
    #10s;
    $fatal(1, "TEST-UART-004 bounded timeout");
  end
endmodule
