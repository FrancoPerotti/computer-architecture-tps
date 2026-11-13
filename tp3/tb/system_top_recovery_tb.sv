`timescale 1ns / 1ps

module system_top_recovery_tb;
  localparam integer BIT_CYCLES = 2608;
  localparam time    BIT_TIME   = 2ns * BIT_CYCLES;
  logic clk = 1'b0, reset = 1'b1, serial_rx = 1'b1;
  logic serial_tx, uart_reset_request;
  string case_id;
  system_top dut (.*);
  always #1ns clk = ~clk;

  task automatic tx_byte(input byte unsigned value, input bit response_follows = 1'b0);
    integer bit_index;
    begin
      serial_rx = 0;
      #(BIT_TIME);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        serial_rx = value[bit_index];
        #(BIT_TIME);
      end
      serial_rx = 1;
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
      if (value !== opcode) $fatal(1, "expected opcode %02x, got %02x", opcode, value);
      rx_byte(value);
      if (value !== result) $fatal(1, "expected result %02x, got %02x", result, value);
    end
  endtask

  task automatic tx_bad_stop(input byte unsigned value);
    integer bit_index;
    begin
      serial_rx = 0;
      #(BIT_TIME);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        serial_rx = value[bit_index];
        #(BIT_TIME);
      end
      serial_rx = 0;
      #(BIT_TIME);
      serial_rx = 1;
      #(1ns);
    end
  endtask

  initial begin : test
    byte unsigned value;
    bit           false_start_case;
    bit           load_size_error_case;
    bit           activity_recovery_case;
    #200ns;
    if (!$value$plusargs("CASE=%s", case_id)) $fatal(1, "missing canonical case ID");
    false_start_case       = case_id == "TEST-UART-006/C001";
    load_size_error_case   = case_id == "TEST-UART-006/C008";
    activity_recovery_case = case_id == "TEST-UART-006/C002";
    @(negedge clk);
    reset = 0;

    // addi x5,x0,7; halt
    tx_byte(8'h01);
    tx_byte(8'h08);
    tx_byte(8'h00);
    tx_byte(8'h00);
    tx_byte(8'h00);
    tx_byte(8'h00, 1'b1);
    expect_header(8'h01, 8'h01);
    tx_byte(8'h93);
    tx_byte(8'h02);
    tx_byte(8'h70);
    tx_byte(8'h00);
    tx_byte(8'h0b);
    tx_byte(8'h00);
    tx_byte(8'h00);
    tx_byte(8'h00, 1'b1);
    expect_header(8'h01, 8'h02);

    if (false_start_case) begin
      // False Start: RX rises before its center sample.
      serial_rx = 0;
      #(BIT_TIME / 4);
      serial_rx = 1;
      #(BIT_TIME);
    end else if (load_size_error_case) begin
      tx_byte(8'h01);
      fork
        tx_bad_stop(8'h08);
        expect_header(8'h01, 8'h09);
      join
    end else if (activity_recovery_case) begin
      tx_bad_stop(8'hA5);
      tx_byte(8'h05);
      tx_byte(8'h04);
      tx_byte(8'hA5);
      repeat (4_990_000) @(posedge clk);
      tx_byte(8'h05);
      serial_rx = 0;
      #(BIT_TIME * 3);
      serial_rx = 1;
      #(BIT_TIME);
      repeat (12 * BIT_CYCLES) @(posedge clk);
      @(negedge clk);
    end else begin
      tx_byte(8'h01);
      tx_byte(8'h08);
      tx_byte(8'h00);
      tx_byte(8'h00);
      tx_byte(8'h00);
      tx_byte(8'h00, 1'b1);
      expect_header(8'h01, 8'h01);
      fork
        tx_bad_stop(8'h93);
        expect_header(8'h01, 8'h09);
      join
    end

    repeat (5_000_005) @(posedge clk);
    @(negedge clk);
    if (activity_recovery_case && serial_tx !== 1'b1)
      $fatal(1, "discarded recovery traffic generated TX response");

    tx_byte(8'h05, 1'b1);
    expect_header(8'h05, 8'h03);
    if (case_id == "TEST-UART-006/C011") begin
      tx_byte(8'h02, 1'b1);
      expect_header(8'h02, 8'h05);
    end else begin
      tx_byte(8'h03, 1'b1);
      expect_header(8'h03, 8'h02);
      rx_byte(value);  // Debug state
      rx_byte(value);  // image_valid
      if (!value[0]) $fatal(1, "RX recovery invalidated the prior image");
    end

    $display("PASS %s", case_id);
    $finish;
  end

  initial begin
    #60ms;
    $fatal(1, "TEST-UART-006 bounded timeout");
  end
endmodule
