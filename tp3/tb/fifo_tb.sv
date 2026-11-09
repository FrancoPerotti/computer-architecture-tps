`timescale 1ns / 1ps

// Ejecuta una variante canónica del contrato de FIFO indicada por el manifiesto.
module fifo_tb;
  localparam integer DATA_WIDTH = system_pkg::UART_DATA_BITS;
  localparam integer CAPACITY   = system_pkg::UART_FIFO_DEPTH;
  localparam integer ADDR_WIDTH = $clog2(CAPACITY);

  tp3_case_data data ();
  logic                    clk = 1'b0;
  logic                    reset = 1'b1;
  logic                    rd = 1'b0;
  logic                    wr = 1'b0;
  logic   [DATA_WIDTH-1:0] write_data = '0;
  logic   [DATA_WIDTH-1:0] read_data;
  logic                    empty;
  logic                    full;
  integer                  initial_count;
  integer                  expected_count;
  integer                  old_read;
  integer                  expected_write;
  integer                  expected_read;
  integer                  write_request;
  integer                  read_request;
  integer                  expected_value;
  integer                  sequence_size;
  integer                  read_wraps;
  integer                  write_wraps;

  fifo dut (.*);
  always #10 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic check_flags(input integer count_value);
    if (dut.count !== count_value) fail("occupancy mismatch");
    if (empty !== (count_value == 0)) fail("empty flag mismatch");
    if (full !== (count_value == CAPACITY)) fail("full flag mismatch");
  endtask

  task automatic write_accepted(input logic [DATA_WIDTH-1:0] value);
    @(negedge clk);
    if (full) fail("fixture attempted write while full");
    wr         = 1'b1;
    rd         = 1'b0;
    write_data = value;
    @(posedge clk);
    #1;
    @(negedge clk);
    wr = 1'b0;
    #1;
  endtask

  task automatic run_vector;
    integer index;
    integer read_pointer_before;
    integer write_pointer_before;
    begin
      initial_count = data.get_integer("/inputs/occupation_before");
      sequence_size = data.get_size("/inputs/data_sequence");
      if (initial_count != sequence_size) fail("catalog fixture count differs from sequence");

      for (index = 0; index < sequence_size; index++) begin
        write_accepted(DATA_WIDTH'(data.get_integer($sformatf("/inputs/data_sequence/%0d", index)
                       )));
        check_flags(index + 1);
      end
      reset = 1'b0;
      check_flags(initial_count);
      if (initial_count != 0 && read_data !== DATA_WIDTH'(data.get_integer(
              "/inputs/data_sequence/0"
          )))
        fail("preflop head differs from catalog sequence");

      write_request  = data.get_integer("/inputs/wr");
      read_request   = data.get_integer("/inputs/rd");
      expected_write = write_request && (initial_count < CAPACITY);
      expected_read  = read_request && (initial_count > 0);
      expected_count = data.get_integer("/expected/occupation_after");
      if (data.get_boolean("/expected/write_accepted") !== (expected_write != 0))
        fail("catalog write acceptance is inconsistent with request");
      if (data.get_boolean("/expected/read_accepted") !== (expected_read != 0))
        fail("catalog read acceptance is inconsistent with request");
      expected_value = data.get_integer("/inputs/new_byte");
      old_read       = initial_count == 0 ? -1 : data.get_integer("/inputs/data_sequence/0");

      @(negedge clk);
      rd                   = read_request;
      wr                   = write_request;
      write_data           = DATA_WIDTH'(expected_value);
      read_pointer_before  = dut.read_pointer;
      write_pointer_before = dut.write_pointer;
      if (dut.count != initial_count) fail("occupancy changed before request edge");
      if (expected_read) begin
        if (empty || read_data !== DATA_WIDTH'(old_read)) fail("wrong preflop read data");
      end
      if (expected_write && full) fail("catalog accepted write while full");
      if (!expected_write && wr && !full) fail("fixture acceptance expectation error");
      if (!expected_read && rd && !empty) fail("fixture read expectation error");
      @(posedge clk);
      #1;
      check_flags(expected_count);
      if (dut.read_pointer !== ADDR_WIDTH'(read_pointer_before + expected_read))
        fail("read pointer acceptance mismatch");
      if (dut.write_pointer !== ADDR_WIDTH'(write_pointer_before + expected_write))
        fail("write pointer acceptance mismatch");

      if (expected_read && !data.is_null(
              "/expected/read_consumed"
          ) && old_read != data.get_integer(
              "/expected/read_consumed"
          ))
        fail("preflop consumed byte differs from catalog expectation");
      if (expected_count > 0) begin
        if (expected_read && initial_count > 1) begin
          if (read_data !== DATA_WIDTH'(data.get_integer("/inputs/data_sequence/1")))
            fail("next FIFO head mismatch after accepted read");
        end else if (expected_read && initial_count == 1) begin
          if (read_data !== DATA_WIDTH'(expected_value))
            fail("simultaneous empty boundary lost write");
        end else if (read_data !== DATA_WIDTH'(old_read == -1 ? expected_value : old_read)) begin
          fail("FIFO head changed unexpectedly");
        end
      end
      @(negedge clk);
      rd = 1'b0;
      wr = 1'b0;
    end
  endtask

  task automatic run_wrap_scenario;
    integer index;
    integer before_read;
    integer before_write;
    integer expected_byte;
    begin
      sequence_size = data.get_size("/inputs/write_then_read_sequence");
      if (sequence_size != data.get_size("/expected/read_sequence"))
        fail("wrap input/output sequence sizes differ");
      read_wraps  = 0;
      write_wraps = 0;
      reset       = 1'b0;
      for (index = 0; index < sequence_size; index++) begin
        expected_byte = data.get_integer($sformatf("/inputs/write_then_read_sequence/%0d", index));
        @(negedge clk);
        before_write = dut.write_pointer;
        wr           = 1'b1;
        write_data   = DATA_WIDTH'(expected_byte);
        @(posedge clk);
        #1;
        if (before_write == CAPACITY - 1 && dut.write_pointer == 0) write_wraps++;
        check_flags(1);
        if (read_data !== DATA_WIDTH'(expected_byte)) fail("wrap scenario write head mismatch");

        @(negedge clk);
        before_read = dut.read_pointer;
        wr          = 1'b0;
        rd          = 1'b1;
        if (read_data !== DATA_WIDTH'(data.get_integer(
                $sformatf("/expected/read_sequence/%0d", index)
            )))
          fail("wrap scenario expected sequence differs from live head");
        @(posedge clk);
        #1;
        if (before_read == CAPACITY - 1 && dut.read_pointer == 0) read_wraps++;
        check_flags(0);
      end
      rd = 1'b0;
      if (!data.get_boolean("/expected/pointer_wraps") || read_wraps != 3 || write_wraps != 3)
        fail("read/write pointers did not wrap three times");
      if (dut.read_pointer !== '0 || dut.write_pointer !== '0)
        fail("pointers did not return to their initial position");
    end
  endtask

  task automatic run_reset_scenario;
    integer index;
    begin
      sequence_size = data.get_integer("/inputs/occupation_before");
      for (index = 0; index < sequence_size; index++) begin
        write_accepted(DATA_WIDTH'(8'h11 + index * 8'h11));
      end
      if (dut.count != data.get_integer("/inputs/occupation_before"))
        fail("reset fixture did not reach catalog occupancy");
      @(negedge clk);
      reset      = data.get_integer("/inputs/reset");
      rd         = data.get_integer("/inputs/rd");
      wr         = data.get_integer("/inputs/wr");
      write_data = 8'h55;
      @(posedge clk);
      #1;
      check_flags(data.get_integer("/expected/occupation_after"));
      if (dut.read_pointer !== '0 || dut.write_pointer !== '0 || data.get_integer(
              "/expected/pointers"
          ) != 0 || data.get_integer(
              "/expected/accepted_operations"
          ) != 0)
        fail("reset did not suppress requests and clear pointers");
      if (!empty || full) fail("reset flags are incorrect");
    end
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

    if (data.case_id == "TEST-UART-002/C017") begin
      run_wrap_scenario();
    end else if (data.case_id == "TEST-UART-002/C018") begin
      run_reset_scenario();
    end else begin
      run_vector();
    end

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
