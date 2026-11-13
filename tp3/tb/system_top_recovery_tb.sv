`timescale 1ns / 1ps

module system_top_recovery_tb;
  localparam integer BIT_CYCLES = 2608;
  localparam time    BIT_TIME   = 2ns * BIT_CYCLES;
  logic clk = 1'b0, reset = 1'b1, serial_rx = 1'b1;
  logic serial_tx, uart_reset_request;
  string case_id;
  integer cycle_counter = 0;
  system_top dut (.*);
  always #1ns clk = ~clk;
  always @(posedge clk) cycle_counter = cycle_counter + 1;

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
    bit           running_recovery_case;
    bit           terminal_recovery_case;
    bit           activity_at_debug_stop_case;
    integer       debug_index;
    integer       bad_stop_cycle;
    #200ns;
    if (!$value$plusargs("CASE=%s", case_id)) $fatal(1, "missing canonical case ID");
    false_start_case       = case_id == "TEST-UART-006/C001";
    load_size_error_case   = case_id == "TEST-UART-006/C008";
    activity_recovery_case = case_id == "TEST-UART-006/C002";
    running_recovery_case  = case_id == "TEST-UART-006/C005";
    terminal_recovery_case = (case_id == "TEST-UART-006/C013") ||
                             (case_id == "TEST-UART-006/C014");
    activity_at_debug_stop_case = case_id == "TEST-UART-006/C014";
    @(negedge clk);
    reset = 0;

    // addi x5,x0,7; halt
    tx_byte(8'h01);
    tx_byte(terminal_recovery_case ? 8'h20 : 8'h08);
    tx_byte(8'h00);
    tx_byte(8'h00);
    tx_byte(8'h00);
    tx_byte(8'h00, 1'b1);
    expect_header(8'h01, 8'h01);
    if (terminal_recovery_case) begin
      // Two nested counters keep RUN active until after its ACCEPTED response
      // and the injected framing error, but finish before R expires.
      tx_byte(8'h93); tx_byte(8'h00); tx_byte(8'h80); tx_byte(8'h0c); // addi x1,x0,200
      tx_byte(8'h13); tx_byte(8'h01); tx_byte(8'h80); tx_byte(8'h0c); // addi x2,x0,200
      tx_byte(8'h13); tx_byte(8'h01); tx_byte(8'hf1); tx_byte(8'hff); // addi x2,x2,-1
      tx_byte(8'he3); tx_byte(8'h1e); tx_byte(8'h01); tx_byte(8'hfe); // bne x2,x0,-4
      tx_byte(8'h13); tx_byte(8'h01); tx_byte(8'h80); tx_byte(8'h0c); // addi x2,x0,200
      tx_byte(8'h93); tx_byte(8'h80); tx_byte(8'hf0); tx_byte(8'hff); // addi x1,x1,-1
      tx_byte(8'he3); tx_byte(8'h98); tx_byte(8'h00); tx_byte(8'hfe); // bne x1,x0,-16
      tx_byte(8'h0b); tx_byte(8'h00); tx_byte(8'h00); tx_byte(8'h00, 1'b1); // halt
    end else if (running_recovery_case) begin
      tx_byte(8'h6f);
      tx_byte(8'h00);
      tx_byte(8'h00);
      tx_byte(8'h00);
      tx_byte(8'h0b);
      tx_byte(8'h00);
      tx_byte(8'h00);
      tx_byte(8'h00, 1'b1);
    end else begin
      tx_byte(8'h93);
      tx_byte(8'h02);
      tx_byte(8'h70);
      tx_byte(8'h00);
      tx_byte(8'h0b);
      tx_byte(8'h00);
      tx_byte(8'h00);
      tx_byte(8'h00, 1'b1);
    end
    expect_header(8'h01, 8'h02);

    if (terminal_recovery_case) begin
      tx_byte(8'h02, 1'b1);
      expect_header(8'h02, 8'h01);
      tx_bad_stop(8'hA5);
      bad_stop_cycle = cycle_counter;
      // ACCEPTED is already complete. FINISHED must arrive during recovery.
      expect_header(8'h02, 8'h0a);
      debug_index = 0;
      if (activity_at_debug_stop_case) begin
        for (debug_index = 0; debug_index < 228; debug_index = debug_index + 1) begin
          rx_byte(value);
          if (debug_index >= 223 && value !== 8'h00)
            $fatal(1, "expected empty Debug used_count, byte %0d was %02x", debug_index - 223, value);
          if (debug_index == 227) begin
            // rx_byte returns at the center of the final Stop bit. Start a new
            // RX frame one functional clock before that Stop physically ends.
            #(BIT_TIME / 2 - 2ns);
            tx_bad_stop(8'hA5);
          end
        end
      end else begin
        fork
          begin : receive_terminal_debug
          for (debug_index = 0; debug_index < 228; debug_index = debug_index + 1) begin
            rx_byte(value);
            if (debug_index >= 223 && value !== 8'h00)
              $fatal(1, "expected empty Debug used_count, byte %0d was %02x", debug_index - 223, value);
          end
          end
          begin : check_recovery_before_debug_stop
            wait (cycle_counter >= bad_stop_cycle + 5_000_000);
            if (debug_index >= 228)
              $fatal(1, "Debug Stop completed before the 5,000,000-clock recovery interval");
          end
        join
      end
      if (activity_at_debug_stop_case) begin
        repeat (5_000_005) @(posedge clk);
        @(negedge clk);
        tx_byte(8'h05, 1'b1);
        expect_header(8'h05, 8'h03);
      end else begin
        #(BIT_TIME / 2 + 1ns);
        tx_byte(8'h05, 1'b1);
        expect_header(8'h05, 8'h03);
        #(3 * BIT_TIME);
        if (serial_tx !== 1'b1) $fatal(1, "RUN terminal response was emitted more than once");
      end
    end else if (running_recovery_case) begin
      tx_byte(8'h02, 1'b1);
      expect_header(8'h02, 8'h01);
      tx_bad_stop(8'hA5);
    end else if (false_start_case) begin
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

    if (!terminal_recovery_case) begin
      repeat (5_000_005) @(posedge clk);
      @(negedge clk);
      if (activity_recovery_case && serial_tx !== 1'b1)
        $fatal(1, "discarded recovery traffic generated TX response");

      if (running_recovery_case) begin
        tx_byte(8'h05);
        #(3 * BIT_TIME);
        if (serial_tx !== 1'b1 || uart_reset_request !== 1'b0)
          $fatal(1, "RUN context was not retained after RX recovery");
      end else begin
        tx_byte(8'h05, 1'b1);
        expect_header(8'h05, 8'h03);
      end
      if (running_recovery_case) begin
        // The post-recovery CHECK_READY is consumed but ignored during RUN.
      end else if (case_id == "TEST-UART-006/C011") begin
        tx_byte(8'h02, 1'b1);
        expect_header(8'h02, 8'h05);
      end else begin
        tx_byte(8'h03, 1'b1);
        expect_header(8'h03, 8'h02);
        rx_byte(value);  // Debug state
        rx_byte(value);  // image_valid
        if (!value[0]) $fatal(1, "RX recovery invalidated the prior image");
      end
    end

    $display("PASS %s", case_id);
    $finish;
  end

  initial begin
    #60ms;
    $fatal(1, "TEST-UART-006 bounded timeout");
  end
endmodule
