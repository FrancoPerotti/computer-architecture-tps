`timescale 1ns / 1ps

module fifo_tb;
  reg clk = 1'b0;
  reg reset = 1'b1;
  reg rd = 1'b0;
  reg wr = 1'b0;
  reg [7:0] write_data = 8'b0;
  wire [7:0] read_data;
  wire empty;
  wire full;
  integer errors = 0;

  always #5 clk = ~clk;

  fifo #(
      .DATA_WIDTH(8),
      .ADDR_WIDTH(2)
  ) dut (
      .clk       (clk),
      .reset     (reset),
      .rd        (rd),
      .wr        (wr),
      .write_data(write_data),
      .read_data (read_data),
      .empty     (empty),
      .full      (full)
  );

  task automatic push;
    input [7:0] value;
    begin
      @(negedge clk);
      write_data = value;
      wr = 1'b1;
      @(posedge clk);
      #1;
      @(negedge clk);
      wr = 1'b0;
    end
  endtask

  task automatic pop_and_check;
    input [7:0] expected;
    begin
      @(negedge clk);
      if (read_data !== expected) begin
        errors = errors + 1;
        $display("ERROR: FIFO head=%h expected=%h", read_data, expected);
      end
      rd = 1'b1;
      @(posedge clk);
      #1;
      @(negedge clk);
      rd = 1'b0;
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    if (!empty || full) begin
      errors = errors + 1;
      $display("ERROR: invalid flags after reset");
    end

    @(negedge clk);
    rd = 1'b1;
    @(posedge clk);
    #1;
    @(negedge clk);
    rd = 1'b0;
    if (!empty) begin
      errors = errors + 1;
      $display("ERROR: underflow changed empty flag");
    end

    push(8'h11);
    push(8'h22);
    push(8'h33);
    push(8'h44);
    if (!full) begin
      errors = errors + 1;
      $display("ERROR: FIFO did not become full");
    end

    // Esta escritura se ignora porque no existe una lectura simultanea.
    push(8'h99);
    pop_and_check(8'h11);
    pop_and_check(8'h22);

    // Fuerza wrap-around de ambos punteros.
    push(8'h55);
    push(8'h66);
    pop_and_check(8'h33);
    pop_and_check(8'h44);

    // En lleno, la lectura se acepta y la escritura simultanea se rechaza.
    push(8'h77);
    push(8'h88);
    @(negedge clk);
    if (read_data !== 8'h55) begin
      errors = errors + 1;
      $display("ERROR: simultaneous head=%h expected=55", read_data);
    end
    write_data = 8'h99;
    rd = 1'b1;
    wr = 1'b1;
    @(posedge clk);
    #1;
    @(negedge clk);
    rd = 1'b0;
    wr = 1'b0;
    if (full) begin
      errors = errors + 1;
      $display("ERROR: simultaneous read/write must release one position");
    end

    pop_and_check(8'h66);
    pop_and_check(8'h77);
    pop_and_check(8'h88);
    if (!empty) begin
      errors = errors + 1;
      $display("ERROR: FIFO did not become empty");
    end

    if (errors != 0) $fatal(1, "FAIL: %0d FIFO errors", errors);
    $display("PASS: FIFO boundary and ordering checks");
    $finish;
  end

  initial begin
    #5000;
    $fatal(1, "FAIL: FIFO testbench timeout");
  end
endmodule
