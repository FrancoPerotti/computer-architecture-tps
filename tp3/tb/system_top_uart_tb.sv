`timescale 1ns / 1ps

module system_top_uart_tb #(
    parameter integer CASE_INDEX = 2
);
  localparam integer BIT_CYCLES   = 2608;
  localparam time    BIT_TIME     = 20ns * BIT_CYCLES;
  localparam integer MAX_RESPONSE = 1024;

  logic         clk = 1'b0;
  logic         reset = 1'b1;
  logic         serial_rx = 1'b1;
  logic         serial_tx;
  logic         uart_reset_request;
  byte unsigned response           [MAX_RESPONSE];
  byte unsigned first_step_snapshot[MAX_RESPONSE];
  integer       snapshot_length;
  integer       used_count;
  integer       steps;
  integer       first_length;

  system_top dut (.*);
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

  task automatic read_debug_snapshot(input byte unsigned opcode, input byte unsigned result,
                                     output integer length);
    byte unsigned value;
    integer       i;
    begin
      expect_header(opcode, result);
      // The serializer's fixed block includes the two-byte response header.
      // After expect_header, 223 fixed snapshot bytes remain, then used_count.
      for (i = 0; i < 223; i = i + 1) begin
        rx_byte(value);
        response[i] = value;
      end
      for (i = 0; i < 5; i = i + 1) begin
        rx_byte(value);
        response[223+i] = value;
      end
      used_count = response[223] | (response[224] << 8) | (response[225] << 16) |
          (response[226] << 24) | (response[227] << 32);
      if (used_count > 128) $fatal(1, "snapshot used_count out of range: %0d", used_count);
      for (i = 0; i < 5 * used_count; i = i + 1) begin
        rx_byte(value);
        response[228+i] = value;
      end
      length = 228 + 5 * used_count;
    end
  endtask

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
      tx_byte(8'h01);
      tx_byte(image_size());
      tx_byte(8'h00);
      tx_byte(8'h00);
      tx_byte(8'h00);
      tx_byte(8'h00, 1'b1);
      expect_header(8'h01, 8'h01);
      for (index = 0; index < image_size(); index = index + 1) begin
        word_value = image_word(index / 4);
        tx_byte(word_value[(index%4)*8+:8], index == image_size() - 1);
      end
      expect_header(8'h01, 8'h02);
    end
  endtask

  function automatic bit snapshot_has_word4;
    integer entry;
    integer address_value;
    begin
      snapshot_has_word4 = 1'b0;
      for (entry = 0; entry < used_count; entry = entry + 1) begin
        address_value = response[228+5*entry] | (response[229+5*entry] << 8) |
            (response[230+5*entry] << 16) | (response[231+5*entry] << 24);
        if (address_value == 4 && response[232+5*entry] === 8'd3) snapshot_has_word4 = 1'b1;
      end
    end
  endfunction

  function automatic bit snapshot_byte_is_meaningful(input integer index);
    begin
      snapshot_byte_is_meaningful = 1'b1;
      // Global fault metadata remains latched after its validity ends. The
      // protocol defines it as meaningful only while the global state is FAULT.
      if (index >= 14 && index <= 18 && response[0] != 8'h0b) snapshot_byte_is_meaningful = 1'b0;
      if (index >= 148 && index <= 155 && !response[147][0]) snapshot_byte_is_meaningful = 1'b0;
      if (index == 157 && !response[156][0]) snapshot_byte_is_meaningful = 1'b0;
      if (index >= 159 && index <= 187 && !response[158][0]) snapshot_byte_is_meaningful = 1'b0;
      if (index >= 189 && index <= 207 && !response[188][0]) snapshot_byte_is_meaningful = 1'b0;
      if (index >= 209 && index <= 222 && !response[208][0]) snapshot_byte_is_meaningful = 1'b0;
    end
  endfunction

  task automatic compare_architectural_snapshots(input integer length);
    integer i;
    begin
      if (length != first_length) $fatal(1, "new-session snapshot length differs");
      for (i = 0; i < length; i = i + 1) begin
        if (snapshot_byte_is_meaningful(i) && response[i] !== first_step_snapshot[i])
          $fatal(
              1,
              "new-session architectural snapshot differs at byte %0d: expected %02x got %02x",
              i,
              first_step_snapshot[i],
              response[i]
          );
      end
    end
  endtask

  initial begin : test
    byte unsigned value;
    integer       i;
    integer       length;
    #200ns;
    @(negedge clk);
    reset = 1'b0;

    send_load_image();

    if (CASE_INDEX == 1 || CASE_INDEX == 5) begin
      tx_byte(8'h02, 1'b1);
      expect_header(8'h02, 8'h01);
      read_debug_snapshot(8'h02, 8'h0a, length);
      if (response[0] !== 8'h0a) $fatal(1, "RUN snapshot state expected FINISHED");
      if (CASE_INDEX == 1) begin
        if (response[27] !== 8'd3 || response[28] !== 8'd0 || response[29] !== 8'd0 ||
            response[30] !== 8'd0)
          $fatal(1, "RUN snapshot x2 expected 3");
        if (!snapshot_has_word4()) $fatal(1, "RUN snapshot DMEM address 4 expected 3");
      end
      $display("PASS TEST-UART-010/C%03d", CASE_INDEX);
      $finish;
    end

    steps        = 0;
    first_length = 0;
    while (steps < 64) begin
      tx_byte(8'h03, 1'b1);
      read_debug_snapshot(8'h03, 8'h02, length);
      steps = steps + 1;
      if (steps == 1) begin
        first_length = length;
        for (i = 0; i < length; i = i + 1) first_step_snapshot[i] = response[i];
      end
      if ((CASE_INDEX == 3 || CASE_INDEX == 4) && response[0] == 8'h0b) begin
        if (response[14] !== 8'd2 || response[15] !== 8'd16 || response[16] !== 0 ||
            response[17] !== 0 || response[18] !== 0)
          $fatal(1, "FAULT snapshot metadata mismatch");
        break;
      end
      if ((CASE_INDEX == 2 || CASE_INDEX == 1 || CASE_INDEX == 5) && response[0] == 8'h0a) begin
        if (response[19+4*2] !== 8'd3 || response[20+4*2] !== 8'd0 || response[21+4*2] !== 8'd0 ||
            response[22+4*2] !== 8'd0)
          $fatal(1, "terminal snapshot x2 expected 3");
        if (!snapshot_has_word4()) $fatal(1, "snapshot DMEM address 4 expected 3");
        break;
      end
    end
    if (steps >= 64) $fatal(1, "TEST-UART-010 did not reach its terminal within 64 STEP commands");

    // C002 requires a new-session first STEP after the terminal response's final Stop.
    if (CASE_INDEX == 2 || CASE_INDEX == 4) begin
      tx_byte(8'h03, 1'b1);
      read_debug_snapshot(8'h03, 8'h02, length);
      compare_architectural_snapshots(length);
    end
    $display("PASS TEST-UART-010/C%03d", CASE_INDEX);
    $finish;
  end

  initial begin
    #2s;
    $fatal(1, "TEST-UART-010 bounded timeout");
  end
endmodule
