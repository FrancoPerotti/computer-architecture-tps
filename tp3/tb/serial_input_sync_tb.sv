`timescale 1ns / 1ps

// Comprueba latencia de dos flancos, ambas polaridades y reset del sincronizador RX.
module serial_input_sync_tb;
  tp3_case_data data ();
  logic clk = 1'b0;
  logic reset = 1'b1;
  logic serial_async = 1'b1;
  logic serial_sync;

  serial_input_sync dut (
      .clk         (clk),
      .reset       (reset),
      .serial_async(serial_async),
      .serial_sync (serial_sync)
  );

  always #10 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic check_transition(input logic new_level);
    serial_async = new_level;
    #1;
    if (serial_sync !== ~new_level) fail("asynchronous input bypassed both stages");

    @(posedge clk);
    #1;
    if (dut.serial_meta !== new_level || dut.serial_reg !== ~new_level ||
        serial_sync !== ~new_level) begin
      fail("first stage did not capture input while second stage held prior value");
    end

    @(posedge clk);
    #1;
    if (dut.serial_meta !== new_level || dut.serial_reg !== new_level ||
        serial_sync !== new_level) begin
      fail("second stage did not reflect input on second clock edge");
    end
  endtask

  initial begin
    data.load();
    repeat (2) @(posedge clk);
    #1;
    if (dut.serial_meta !== 1'b1 || dut.serial_reg !== 1'b1 || serial_sync !== 1'b1) begin
      fail("reset did not initialize both stages to UART idle high");
    end

    @(negedge clk);
    reset = 1'b0;
    check_transition(1'b0);
    check_transition(1'b1);

    @(negedge clk);
    serial_async = 1'b0;
    @(posedge clk);
    #1;
    if (dut.serial_meta !== 1'b0 || dut.serial_reg !== 1'b1) begin
      fail("failed to prepare reset during a pending transition");
    end
    @(negedge clk);
    reset = 1'b1;
    @(posedge clk);
    #1;
    if (dut.serial_meta !== 1'b1 || dut.serial_reg !== 1'b1 || serial_sync !== 1'b1) begin
      fail("reset did not restore UART idle high");
    end

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
