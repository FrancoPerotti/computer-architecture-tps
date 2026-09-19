`timescale 1ns / 1ps

module uart_rx_tb;
  localparam integer OVERSAMPLE = 16;

  reg clk = 1'b0;
  reg reset = 1'b1;
  reg rx = 1'b1;
  reg s_tick = 1'b1;
  wire rx_done_tick;
  wire frame_error_tick;
  wire [7:0] data_out;
  integer errors = 0;
  integer done_count = 0;
  integer frame_error_count = 0;

  always #5 clk = ~clk;

  always @(posedge clk) begin
    #1;
    if (rx_done_tick) done_count = done_count + 1;
    if (frame_error_tick) frame_error_count = frame_error_count + 1;
  end

  uart_rx #(
      .DATA_BITS (8),
      .OVERSAMPLE(OVERSAMPLE),
      .STOP_TICKS(OVERSAMPLE)
  ) dut (
      .clk             (clk),
      .reset           (reset),
      .rx              (rx),
      .s_tick          (s_tick),
      .rx_done_tick    (rx_done_tick),
      .frame_error_tick(frame_error_tick),
      .data_out        (data_out)
  );

  task automatic hold_bit;
    input value;
    begin
      @(negedge clk);
      rx = value;
      repeat (OVERSAMPLE) @(posedge clk);
    end
  endtask

  task automatic send_frame;
    input [7:0] value;
    input valid_stop;
    integer bit_index;
    begin
      hold_bit(1'b0);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        hold_bit(value[bit_index]);
      end
      hold_bit(valid_stop);
      hold_bit(1'b1);
    end
  endtask

  task automatic check_valid_frame;
    input [7:0] value;
    integer done_before;
    begin
      done_before = done_count;
      send_frame(value, 1'b1);
      if (done_count != done_before + 1 || data_out !== value) begin
        errors = errors + 1;
        $display("ERROR: RX value=%h obtained=%h done delta=%0d", value, data_out,
                 done_count - done_before);
      end
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    check_valid_frame(8'h00);
    check_valid_frame(8'hff);
    check_valid_frame(8'ha5);
    check_valid_frame(8'h3c);

    // Pulso bajo menor a medio bit: debe descartarse como falso start.
    @(negedge clk);
    rx = 1'b0;
    repeat (4) @(posedge clk);
    @(negedge clk);
    rx = 1'b1;
    repeat (OVERSAMPLE) @(posedge clk);
    if (frame_error_count != 1 || done_count != 4) begin
      errors = errors + 1;
      $display("ERROR: false start handling done=%0d errors=%0d", done_count,
               frame_error_count);
    end

    send_frame(8'h5a, 1'b0);
    if (frame_error_count != 2 || done_count != 4) begin
      errors = errors + 1;
      $display("ERROR: invalid stop handling done=%0d errors=%0d", done_count,
               frame_error_count);
    end

    check_valid_frame(8'h69);

    if (errors != 0) $fatal(1, "FAIL: %0d UART RX errors", errors);
    $display("PASS: UART receiver valid and malformed frames");
    $finish;
  end

  initial begin
    #200000;
    $fatal(1, "FAIL: UART RX testbench timeout");
  end
endmodule
