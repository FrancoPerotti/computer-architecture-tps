`timescale 1ns / 1ps

module uart_core_tb;
  localparam integer CLK_FREQ_HZ = 100_000;
  localparam integer BAUD_RATE = 2_500;
  localparam integer OVERSAMPLE = 4;
  localparam integer BIT_CYCLES = 40;

  reg clk = 1'b0;
  reg reset = 1'b1;
  reg serial_rx = 1'b1;
  wire serial_tx;
  wire [7:0] r_data;
  reg rd_uart = 1'b0;
  wire rx_empty;
  reg [7:0] w_data = 8'b0;
  reg wr_uart = 1'b0;
  wire tx_full;
  wire rx_error_tick;

  integer errors = 0;
  integer rx_errors = 0;
  integer bit_index;
  reg [7:0] received;

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (rx_error_tick) rx_errors = rx_errors + 1;
  end

  uart_core #(
      .CLK_FREQ_HZ   (CLK_FREQ_HZ),
      .BAUD_RATE     (BAUD_RATE),
      .OVERSAMPLE    (OVERSAMPLE),
      .FIFO_ADDR_WIDTH(2)
  ) dut (
      .clk          (clk),
      .reset        (reset),
      .serial_rx    (serial_rx),
      .serial_tx    (serial_tx),
      .r_data       (r_data),
      .rd_uart      (rd_uart),
      .rx_empty     (rx_empty),
      .w_data       (w_data),
      .wr_uart      (wr_uart),
      .tx_full      (tx_full),
      .rx_error_tick(rx_error_tick)
  );

  task automatic drive_serial_bit;
    input value;
    begin
      @(negedge clk);
      serial_rx = value;
      repeat (BIT_CYCLES) @(posedge clk);
    end
  endtask

  task automatic send_serial_byte;
    input [7:0] value;
    begin
      drive_serial_bit(1'b0);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        drive_serial_bit(value[bit_index]);
      end
      drive_serial_bit(1'b1);
    end
  endtask

  task automatic pop_rx;
    input [7:0] expected;
    begin
      wait (!rx_empty);
      @(negedge clk);
      if (r_data !== expected) begin
        errors = errors + 1;
        $display("ERROR: RX FIFO data=%h expected=%h", r_data, expected);
      end
      rd_uart = 1'b1;
      @(posedge clk);
      @(negedge clk);
      rd_uart = 1'b0;
    end
  endtask

  task automatic push_tx;
    input [7:0] value;
    begin
      @(negedge clk);
      w_data = value;
      wr_uart = 1'b1;
      @(posedge clk);
      @(negedge clk);
      wr_uart = 1'b0;
    end
  endtask

  task automatic receive_serial_byte;
    input [7:0] expected;
    reg [7:0] value;
    begin
      @(negedge serial_tx);
      repeat (BIT_CYCLES + (BIT_CYCLES / 2)) @(posedge clk);
      #1;
      value[0] = serial_tx;
      for (bit_index = 1; bit_index < 8; bit_index = bit_index + 1) begin
        repeat (BIT_CYCLES) @(posedge clk);
        #1;
        value[bit_index] = serial_tx;
      end
      repeat (BIT_CYCLES) @(posedge clk);
      #1;
      if (serial_tx !== 1'b1 || value !== expected) begin
        errors = errors + 1;
        $display("ERROR: TX byte=%h expected=%h stop=%b", value, expected, serial_tx);
      end
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    // Llena RX, provoca un overrun controlado y comprueba que se conserven
    // los cuatro bytes anteriores en orden.
    send_serial_byte(8'h11);
    send_serial_byte(8'h22);
    send_serial_byte(8'h33);
    send_serial_byte(8'h44);
    send_serial_byte(8'h55);
    repeat (20) @(posedge clk);
    if (rx_errors != 1) begin
      errors = errors + 1;
      $display("ERROR: RX overrun pulses=%0d expected=1", rx_errors);
    end
    pop_rx(8'h11);
    pop_rx(8'h22);
    pop_rx(8'h33);
    pop_rx(8'h44);
    if (!rx_empty) begin
      errors = errors + 1;
      $display("ERROR: RX FIFO not empty after four reads");
    end

    // Encola cuatro bytes mientras el primero se transmite y decodifica
    // la secuencia completa sobre la salida serial.
    fork
      begin
        receive_serial_byte(8'ha5);
        receive_serial_byte(8'h00);
        receive_serial_byte(8'hff);
        receive_serial_byte(8'h3c);
      end
      begin
        push_tx(8'ha5);
        push_tx(8'h00);
        push_tx(8'hff);
        push_tx(8'h3c);
        if (!tx_full) begin
          errors = errors + 1;
          $display("ERROR: TX FIFO did not become full");
        end
      end
    join

    repeat (20) @(posedge clk);
    if (tx_full) begin
      errors = errors + 1;
      $display("ERROR: TX FIFO remained full after transmissions");
    end

    if (errors != 0) $fatal(1, "FAIL: %0d UART core errors", errors);
    $display("PASS: UART core FIFOs, overrun and serialized output");
    $finish;
  end

  initial begin
    #1000000;
    $fatal(1, "FAIL: UART core testbench timeout");
  end
endmodule
