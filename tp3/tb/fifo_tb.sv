`timescale 1ns / 1ps

// Verifica aceptación preflanco, orden, capacidad, wrap y reset de FIFO.
module fifo_tb;
  localparam integer DATA_WIDTH = system_pkg::UART_DATA_BITS;
  localparam integer CAPACITY   = system_pkg::UART_FIFO_DEPTH;
  tp3_case_data data ();
  logic                  clk = 1'b0;
  logic                  reset = 1'b1;
  logic                  rd = 1'b0;
  logic                  wr = 1'b0;
  logic [DATA_WIDTH-1:0] write_data = '0;
  logic [DATA_WIDTH-1:0] read_data;
  logic                  empty;
  logic                  full;

  fifo dut (.*);

  always #10 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic check_flags(input integer expected_count);
    if (dut.count !== expected_count) fail("occupancy count mismatch");
    if (empty !== (expected_count == 0)) fail("empty flag mismatch");
    if (full !== (expected_count == CAPACITY)) fail("full flag mismatch");
  endtask

  task automatic write_byte(input logic [DATA_WIDTH-1:0] value);
    logic   [DATA_WIDTH-1:0] old_head;
    integer                  old_count;
    @(negedge clk);
    if (full) fail("write_byte called while FIFO full");
    old_count  = dut.count;
    old_head   = read_data;
    wr         = 1'b1;
    write_data = value;
    @(posedge clk);
    #1;
    check_flags(old_count + 1);
    if (old_count == 0) begin
      if (read_data !== value) fail("write to empty FIFO did not expose new head");
    end else if (read_data !== old_head) begin
      fail("write changed the existing FIFO head");
    end
    @(negedge clk);
    wr = 1'b0;
  endtask

  task automatic read_byte(input logic [DATA_WIDTH-1:0] expected);
    integer old_count;
    @(negedge clk);
    if (empty) fail("read_byte called while FIFO empty");
    if (read_data !== expected) fail("read_data did not present the oldest byte");
    old_count = dut.count;
    rd        = 1'b1;
    @(posedge clk);
    #1;
    check_flags(old_count - 1);
    @(negedge clk);
    rd = 1'b0;
  endtask

  task automatic rejected_write(input logic [DATA_WIDTH-1:0] value);
    integer                  old_count;
    logic   [DATA_WIDTH-1:0] old_head;
    @(negedge clk);
    if (!full) fail("rejected_write fixture was not full");
    old_count  = dut.count;
    old_head   = read_data;
    wr         = 1'b1;
    write_data = value;
    @(posedge clk);
    #1;
    check_flags(old_count);
    if (read_data !== old_head) fail("full FIFO accepted an extra write");
    @(negedge clk);
    wr = 1'b0;
  endtask

  task automatic rejected_read;
    integer old_count;
    @(negedge clk);
    if (!empty) fail("rejected_read fixture was not empty");
    old_count = dut.count;
    rd        = 1'b1;
    @(posedge clk);
    #1;
    check_flags(old_count);
    @(negedge clk);
    rd = 1'b0;
  endtask

  task automatic simultaneous(input logic [DATA_WIDTH-1:0] value,
                              input logic [DATA_WIDTH-1:0] old_head,
                              input logic [DATA_WIDTH-1:0] next_head, input integer expected_count);
    @(negedge clk);
    if (empty || full) fail("simultaneous middle-occupancy fixture invalid");
    if (read_data !== old_head) fail("simultaneous operation started with wrong head");
    rd         = 1'b1;
    wr         = 1'b1;
    write_data = value;
    @(posedge clk);
    #1;
    check_flags(expected_count);
    if (read_data !== next_head) fail("simultaneous read/write did not expose next byte");
    @(negedge clk);
    rd = 1'b0;
    wr = 1'b0;
  endtask

  task automatic simultaneous_full(input logic [DATA_WIDTH-1:0] rejected_value,
                                   input logic [DATA_WIDTH-1:0] old_head,
                                   input logic [DATA_WIDTH-1:0] next_head);
    @(negedge clk);
    if (!full || read_data !== old_head) fail("full simultaneous fixture mismatch");
    rd         = 1'b1;
    wr         = 1'b1;
    write_data = rejected_value;
    @(posedge clk);
    #1;
    check_flags(CAPACITY - 1);
    if (read_data !== next_head) fail("full simultaneous operation did not accept read only");
    @(negedge clk);
    rd = 1'b0;
    wr = 1'b0;
  endtask

  task automatic simultaneous_empty(input logic [DATA_WIDTH-1:0] value);
    @(negedge clk);
    if (!empty) fail("empty simultaneous fixture mismatch");
    rd         = 1'b1;
    wr         = 1'b1;
    write_data = value;
    @(posedge clk);
    #1;
    check_flags(1);
    if (read_data !== value) fail("empty simultaneous operation did not accept write only");
    @(negedge clk);
    rd = 1'b0;
    wr = 1'b0;
  endtask

  task automatic reset_fifo;
    @(negedge clk);
    reset      = 1'b1;
    rd         = 1'b1;
    wr         = 1'b1;
    write_data = 8'hEE;
    @(posedge clk);
    #1;
    check_flags(0);
    if (dut.read_pointer !== '0 || dut.write_pointer !== '0) begin
      fail("reset did not clear FIFO pointers");
    end
    @(negedge clk);
    reset = 1'b0;
    rd    = 1'b0;
    wr    = 1'b0;
  endtask

  initial begin
    data.load();
    repeat (2) begin
      @(posedge clk);
      #1;
    end
    check_flags(0);

    @(negedge clk);
    reset = 1'b0;
    rejected_read();
    write_byte(8'h11);
    if (read_data !== 8'h11) fail("single-byte read_data mismatch");
    read_byte(8'h11);
    rejected_read();

    // Llenado, rechazo en lleno y simultaneidad en FIFO llena: solo retira.
    write_byte(8'h21);
    write_byte(8'h32);
    write_byte(8'h43);
    write_byte(8'h54);
    if (!full || read_data !== 8'h21) fail("FIFO did not fill with the expected head");
    rejected_write(8'h65);
    simultaneous_full(8'h76, 8'h21, 8'h32);
    read_byte(8'h32);
    read_byte(8'h43);
    read_byte(8'h54);
    check_flags(0);

    // En vacío, rd y wr simultáneos aceptan solamente la escritura.
    simultaneous_empty(8'h87);
    read_byte(8'h87);

    // En ocupación intermedia se aceptan ambas y se conserva el conteo.
    write_byte(8'h98);
    write_byte(8'hA9);
    simultaneous(8'hBA, 8'h98, 8'hA9, 2);
    read_byte(8'hA9);
    read_byte(8'hBA);

    // Recorrido circular con punteros desfasados y orden FIFO conservado.
    write_byte(8'hC1);
    write_byte(8'hC2);
    write_byte(8'hC3);
    write_byte(8'hC4);
    read_byte(8'hC1);
    read_byte(8'hC2);
    write_byte(8'hC5);
    write_byte(8'hC6);
    read_byte(8'hC3);
    read_byte(8'hC4);
    read_byte(8'hC5);
    read_byte(8'hC6);
    check_flags(0);

    // Reset sobre FIFO llena: punteros y ocupación se limpian sin borrar memoria.
    write_byte(8'hD1);
    write_byte(8'hD2);
    write_byte(8'hD3);
    write_byte(8'hD4);
    reset_fifo();
    if (!empty || full) fail("reset flags did not report an empty FIFO");

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
