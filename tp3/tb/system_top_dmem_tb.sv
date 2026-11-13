`timescale 1ns / 1ps

module system_top_dmem_tb;
  localparam longint unsigned BAUD_RATE = 64'd3_125_000;
  logic clk = 0;
  logic reset = 1;
  wire serial_rx, serial_tx, uart_reset_request;

  system_uart_host #(
      .BAUD_RATE     (BAUD_RATE),
      .MAX_USED_BYTES(3)
  ) host (
      .*
  );
  system_top #(.BAUD_RATE(BAUD_RATE)) dut (.*);
  always #10ns clk = ~clk;

  function automatic logic [31:0] instruction(input integer index);
    case (index)
      0: return 32'h000001a3;  // sb x0,3(x0)
      1: return 32'h00001137;  // lui x2,1
      2: return 32'h23410113;  // addi x2,x2,0x234
      3: return 32'h00201023;  // sh x2,0(x0)
      4: return 32'h05600113;  // addi x2,x0,0x56
      5: return 32'h002000a3;  // sb x2,1(x0)
      6: return 32'h00200183;  // lb x3,2(x0)
      default: return 32'h0000000b;  // halt
    endcase
  endfunction

  initial begin
    logic [31:0] word_value;
    repeat (10) @(negedge clk);
    reset = 0;
    host.load_header(40'd32);
    for (integer index = 0; index < 32; index++) begin
      word_value = instruction(index / 4);
      host.send_byte(word_value[8*(index%4)+:8], index == 31);
    end
    host.expect_header(8'h01, 8'h02);
    host.send_byte(8'h02, 1);
    host.expect_header(8'h02, 8'h01);
    host.read_snapshot(8'h02, 8'h0a);
    if (host.used_count !== 3 || host.word_at(19 + 3 * 4) !== 0)
      $fatal(1, "DMEM reads or overwrites changed the used-byte count");
    host.check_entry(0, 0, 8'h34);
    host.check_entry(1, 1, 8'h56);
    host.check_entry(2, 3, 8'h00);

    host.send_byte(8'h03, 1);
    host.read_snapshot(8'h03, 8'h02);
    if (host.used_count !== 0 || host.cycles() !== 1 || host.word_at(19 + 2 * 4) !== 0)
      $fatal(1, "session restart did not clear DMEM ownership and RF");

    host.load_header(40'd4);
    host.send_byte(8'h0b);
    repeat (2) host.send_byte(0);
    host.send_byte(0, 1);
    host.expect_header(8'h01, 8'h02);
    host.send_byte(8'h02, 1);
    host.expect_header(8'h02, 8'h01);
    host.read_snapshot(8'h02, 8'h0a);
    if (host.used_count !== 0 || host.word_at(19 + 2 * 4) !== 0)
      $fatal(1, "replacement image ran with stale state");
    $display("PASS TEST-UART-008/C001");
    $finish;
  end

  initial begin
    #6ms;
    $fatal(1, "system DMEM watchdog");
  end
endmodule
