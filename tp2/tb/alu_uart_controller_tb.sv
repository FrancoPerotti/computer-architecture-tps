`timescale 1ns / 1ps

module alu_uart_controller_tb;
  reg clk = 1'b0;
  reg reset = 1'b1;
  reg [7:0] r_data = 8'b0;
  reg rx_empty = 1'b1;
  reg rx_error_tick = 1'b0;
  reg tx_full = 1'b0;
  wire rd_uart;
  wire [7:0] w_data;
  wire wr_uart;
  wire [10:0] leds;

  integer errors = 0;
  integer responses = 0;
  reg [7:0] last_response = 8'b0;

  always #5 clk = ~clk;

  alu_uart_controller #(
      .CLK_FREQ_HZ          (1_000),
      .TRANSACTION_TIMEOUT_MS(3)
  ) dut (
      .clk          (clk),
      .reset        (reset),
      .r_data       (r_data),
      .rd_uart      (rd_uart),
      .rx_empty     (rx_empty),
      .rx_error_tick(rx_error_tick),
      .w_data       (w_data),
      .wr_uart      (wr_uart),
      .tx_full      (tx_full),
      .leds         (leds)
  );

  always @(posedge clk) begin
    if (wr_uart) begin
      responses = responses + 1;
      last_response = w_data;
    end
  end

  task automatic offer_byte;
    input [7:0] value;
    begin
      @(negedge clk);
      r_data = value;
      rx_empty = 1'b0;
      wait (rd_uart === 1'b1);
      @(posedge clk);
      @(negedge clk);
      rx_empty = 1'b1;
    end
  endtask

  task automatic expect_response;
    input [7:0] expected_result;
    input [2:0] expected_flags;
    integer previous_responses;
    begin
      previous_responses = responses;
      wait (responses == previous_responses + 1);
      @(negedge clk);
      if (last_response !== expected_result ||
          leds !== {expected_flags, expected_result}) begin
        errors = errors + 1;
        $display("ERROR: response=%h/%h LEDs=%h/%h", last_response, expected_result,
                 leds, {expected_flags, expected_result});
      end
    end
  endtask

  task automatic transact;
    input [7:0] test_a;
    input [7:0] test_b;
    input [7:0] test_opcode;
    input [7:0] expected_result;
    input [2:0] expected_flags;
    integer previous_responses;
    begin
      previous_responses = responses;
      offer_byte(test_a);
      offer_byte(test_b);
      offer_byte(test_opcode);
      wait (responses == previous_responses + 1);
      @(negedge clk);
      if (last_response !== expected_result ||
          leds !== {expected_flags, expected_result}) begin
        errors = errors + 1;
        $display("ERROR: A=%h B=%h op=%h response=%h expected=%h LEDs=%h expected=%h",
                 test_a, test_b, test_opcode, last_response, expected_result, leds,
                 {expected_flags, expected_result});
      end
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    if (leds !== 11'b001_00000000 || wr_uart || rd_uart) begin
      errors = errors + 1;
      $display("ERROR: controller reset state");
    end

    transact(8'h05, 8'h03, 8'h20, 8'h08, 3'b000);
    transact(8'hff, 8'h01, 8'h20, 8'h00, 3'b011);
    transact(8'h7f, 8'h01, 8'h20, 8'h80, 3'b100);
    transact(8'h80, 8'h01, 8'h03, 8'hc0, 3'b000);

    // El resultado no se pierde mientras la FIFO transmisora esta llena.
    tx_full = 1'b1;
    offer_byte(8'h0c);
    offer_byte(8'h0a);
    offer_byte(8'h24);
    repeat (5) @(posedge clk);
    if (wr_uart || responses != 4) begin
      errors = errors + 1;
      $display("ERROR: controller ignored TX backpressure");
    end
    @(negedge clk);
    tx_full = 1'b0;
    wait (responses == 5);
    @(negedge clk);
    if (last_response !== 8'h08 || leds !== 11'h008) begin
      errors = errors + 1;
      $display("ERROR: stalled response=%h LEDs=%h", last_response, leds);
    end

    // Un byte aislado caduca; la terna siguiente debe comenzar nuevamente en A.
    offer_byte(8'haa);
    repeat (5) @(posedge clk);
    transact(8'h09, 8'h02, 8'h22, 8'h07, 3'b000);

    // Un error de trama tambien abandona la operacion parcial.
    offer_byte(8'h55);
    @(negedge clk);
    rx_error_tick = 1'b1;
    @(posedge clk);
    @(negedge clk);
    rx_error_tick = 1'b0;
    transact(8'hf0, 8'h0f, 8'h27, 8'h00, 3'b001);

    // Los dos bits altos del byte de opcode son reservados e ignorados.
    transact(8'h01, 8'h02, 8'he0, 8'h03, 3'b000);
    transact(8'h12, 8'h34, 8'h3f, 8'h00, 3'b001);

    if (errors != 0) $fatal(1, "FAIL: %0d controller errors", errors);
    $display("PASS: ALU/UART controller protocol, stalls and recovery");
    $finish;
  end

  initial begin
    #20000;
    $fatal(1, "FAIL: controller testbench timeout");
  end
endmodule
