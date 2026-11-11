`timescale 1ns / 1ps

// Comprueba las fronteras RX/FIFO con la UART física completa y casos del catálogo.
module uart_fifo_boundary_tb;
  localparam integer DATA_WIDTH = system_pkg::UART_DATA_BITS;
  localparam integer FIFO_DEPTH = system_pkg::UART_FIFO_DEPTH;
  localparam integer ADDR_WIDTH = $clog2(FIFO_DEPTH);
  localparam
      integer DIVISOR = (system_pkg::FUNCTIONAL_CLOCK_HZ +
                         (system_pkg::UART_BAUD_RATE * system_pkg::UART_OVERSAMPLE_FACTOR) / 2) /
      (system_pkg::UART_BAUD_RATE * system_pkg::UART_OVERSAMPLE_FACTOR);
  localparam integer BIT_CYCLES = DIVISOR * system_pkg::UART_OVERSAMPLE_FACTOR;

  tp3_case_data data ();
  logic                    clk = 1'b0;
  logic                    reset = 1'b1;
  logic                    serial_rx = 1'b1;
  logic                    serial_tx;
  logic   [DATA_WIDTH-1:0] r_data;
  logic                    rd_uart = 1'b0;
  logic                    rx_empty;
  logic   [DATA_WIDTH-1:0] w_data = '0;
  logic                    wr_uart = 1'b0;
  logic                    tx_full;
  logic                    rx_error_tick;
  logic                    rx_activity;
  logic                    rx_receiving;
  logic                    tx_done_tick;
  integer                  count_before;
  integer                  count_after;
  integer                  expected_count;
  logic                    observed_error;
  logic                    observed_done;

  uart_core dut (.*);
  always #10 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic clocks(input integer cycles);
    repeat (cycles) begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic drive_frame_to_done(input logic [DATA_WIDTH-1:0] value);
    begin
      @(negedge clk);
      serial_rx = 1'b0;
      repeat (2 * DIVISOR) @(posedge clk);
      #1;
      repeat (BIT_CYCLES - 2 * DIVISOR) @(posedge clk);
      @(negedge clk);
      for (integer bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
        serial_rx = value[bit_index];
        repeat (BIT_CYCLES) @(posedge clk);
        @(negedge clk);
      end
      serial_rx = 1'b1;
      // rx_done_tick se activa tras el tick registrado; la FIFO lo consume
      // en el siguiente flanco, que es donde rd_uart debe estar alineado.
      wait (dut.receiver.rx_done_tick === 1'b1);
    end
  endtask

  task automatic finish_rx_event(input logic read_request, output logic done_seen,
                                 output logic error_seen);
    begin
      #1;
      count_before = dut.rx_fifo.count;
      done_seen    = dut.receiver.rx_done_tick;
      error_seen   = rx_error_tick;
      if (!done_seen) fail("test did not align with rx_done_tick");
      rd_uart = read_request;
      @(posedge clk);
      #1;
      count_after = dut.rx_fifo.count;
      @(negedge clk);
      rd_uart = 1'b0;
    end
  endtask

  task automatic receive_byte(input logic [DATA_WIDTH-1:0] value, input logic read_request,
                              output logic done_seen, output logic error_seen);
    begin
      drive_frame_to_done(value);
      finish_rx_event(read_request, done_seen, error_seen);
    end
  endtask

  task automatic expect_head(input logic [DATA_WIDTH-1:0] value);
    if (rx_empty || r_data !== value) fail("unexpected RX FIFO head/order");
  endtask

  task automatic read_head(input logic [DATA_WIDTH-1:0] value);
    begin
      @(negedge clk);
      expect_head(value);
      rd_uart = 1'b1;
      @(posedge clk);
      #1;
      @(negedge clk);
      rd_uart = 1'b0;
    end
  endtask

  task automatic prefill_rx_fifo;
    logic done_seen;
    logic error_seen;
    begin
      for (integer index = 0; index < FIFO_DEPTH; index++) begin
        receive_byte(DATA_WIDTH'(8'h11 + (index * 8'h11)), 1'b0, done_seen, error_seen);
        if (!done_seen || error_seen || dut.rx_fifo.count != index + 1)
          fail("physical RX prefill did not add exactly one valid byte");
      end
      if (!dut.rx_full || dut.rx_fifo.count != FIFO_DEPTH)
        fail("physical RX fixture did not fill the FIFO");
    end
  endtask

  task automatic run_overflow;
    logic done_seen;
    logic error_seen;
    begin
      if (data.get_integer("/inputs/rx_fifo_occupation") != FIFO_DEPTH)
        fail("catalog overflow fixture is not full");
      prefill_rx_fifo();
      receive_byte(8'hA5, data.get_integer("/inputs/rd_uart"), done_seen, error_seen);
      expected_count = data.get_integer("/inputs/rx_fifo_occupation");
      if (!done_seen || error_seen !== data.get_boolean("/expected/overflow_error"))
        fail("overflow event differs from catalog expectation");
      if (count_before != expected_count || count_after != expected_count ||
          dut.rx_fifo.count != expected_count)
        fail("overflow altered FIFO occupancy");
      if (dut.rx_fifo.write_pointer !== dut.rx_fifo.read_pointer)
        fail("overflow advanced write pointer");
      if (data.get_boolean("/expected/new_byte_stored")) fail("catalog expected no overflow");
      for (integer index = 0; index < FIFO_DEPTH; index++)
      read_head(DATA_WIDTH'(8'h11 + (index * 8'h11)));
      if (!rx_empty) fail("overflow byte was stored after the original queue");
    end
  endtask

  task automatic run_empty_simultaneous;
    logic done_seen;
    logic error_seen;
    begin
      if (data.get_integer("/inputs/occupation_before") != 0 || !rx_empty)
        fail("catalog empty-boundary fixture is not empty");
      receive_byte(8'hA5, data.get_integer("/inputs/rd_uart"), done_seen, error_seen);
      if (!done_seen || error_seen || count_before != 0 || count_after != 1 ||
          dut.rx_fifo.count != data.get_integer(
              "/expected/occupation_after"
          ))
        fail("empty simultaneous decision did not use preflop flags");
      if (data.get_boolean("/expected/read") || !data.get_boolean("/expected/write"))
        fail("catalog empty-boundary expectation is inconsistent");
      expect_head(8'hA5);
      read_head(8'hA5);
      if (!rx_empty) fail("empty-boundary byte was not consumed exactly once");
    end
  endtask

  task automatic run_full_simultaneous;
    logic   done_seen;
    logic   error_seen;
    integer old_read_pointer;
    integer old_write_pointer;
    begin
      if (data.get_integer("/inputs/occupation_before") != FIFO_DEPTH)
        fail("catalog full-boundary fixture is not full");
      prefill_rx_fifo();
      old_read_pointer  = dut.rx_fifo.read_pointer;
      old_write_pointer = dut.rx_fifo.write_pointer;
      receive_byte(8'hA5, data.get_integer("/inputs/rd_uart"), done_seen, error_seen);
      if (!done_seen || !error_seen) fail("full simultaneous overflow indication mismatch");
      if (count_before != FIFO_DEPTH || count_after != data.get_integer(
              "/expected/occupation_after"
          ) || dut.rx_fifo.count != FIFO_DEPTH - 1)
        fail("full simultaneous decision did not read only from preflop flags");
      if (dut.rx_fifo.read_pointer !== ADDR_WIDTH'(old_read_pointer + 1) ||
          dut.rx_fifo.write_pointer !== old_write_pointer)
        fail("full simultaneous pointers accepted the wrong operations");
      if (!data.get_boolean("/expected/read") || data.get_boolean("/expected/write"))
        fail("catalog full-boundary expectation is inconsistent");
      for (integer index = 1; index < FIFO_DEPTH; index++)
      read_head(DATA_WIDTH'(8'h11 + (index * 8'h11)));
      if (!rx_empty) fail("rejected incoming byte appeared in the FIFO");
    end
  endtask

  initial begin
    data.load();
    clocks(2);
    if (!rx_empty || tx_full || serial_tx !== 1'b1 || rx_activity || rx_receiving ||
        rx_error_tick || tx_done_tick || dut.rx_fifo.count != 0 || dut.tx_fifo.count != 0)
      fail("UART reset did not initialize core and FIFOs");
    @(negedge clk);
    reset = 1'b0;

    if (data.case_id == "TEST-UART-002/C019") begin
      run_overflow();
    end else if (data.case_id == "TEST-UART-002/C020") begin
      run_empty_simultaneous();
    end else if (data.case_id == "TEST-UART-002/C021") begin
      run_full_simultaneous();
    end else begin
      fail("unexpected TEST-UART-002 integration case");
    end

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
