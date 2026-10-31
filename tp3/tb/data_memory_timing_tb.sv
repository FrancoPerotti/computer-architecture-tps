`timescale 1ns / 1ps

// Reutiliza los vectores temporales de memoria para comprobar la DMEM física.
module data_memory_timing_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd0,
    localparam int unsigned BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
);
  import system_pkg::*;

  tp3_case_data data ();
  logic        clk = 1'b0;
  logic        reset = 1'b1;
  word_t       address = '0;
  word_t       write_data = '0;
  logic        write_enable = 1'b0;
  logic  [3:0] byte_enable = 4'b1111;
  word_t       mem_read_data;

  data_memory #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk               (clk),
      .reset             (reset),
      .address           (address),
      .write_data        (write_data),
      .write_enable      (write_enable),
      .byte_enable       (byte_enable),
      .prepare_dmem_clear(1'b0),
      .prepare_dmem_addr ('0),
      .debug_read_select (1'b0),
      .debug_dmem_addr   ('0),
      .mem_read_data     (mem_read_data),
      .debug_dmem_data   (),
      .debug_dmem_used   ()
  );

  always #5 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  function automatic word_t get_word(input string path);
    return word_t'(data.get_integer(path));
  endfunction

  task automatic seed_words;
    for (int index = 0; index < data.get_size("/inputs/initial_words"); index++) begin
      @(negedge clk);
      reset        = 1'b0;
      address      = 4 * get_word($sformatf("/inputs/initial_words/%0d/index", index));
      write_data   = get_word($sformatf("/inputs/initial_words/%0d/data", index));
      write_enable = 1'b1;
      @(posedge clk);
      #1;
    end
    @(negedge clk);
    write_enable = 1'b0;
  endtask

  task automatic run_steps;
    word_t expected_before;
    word_t expected_after;
    for (int index = 0; index < data.get_size("/inputs/imem_steps"); index++) begin
      address = get_word($sformatf("/inputs/imem_steps/%0d/read_address", index));
      write_data = get_word($sformatf("/inputs/imem_steps/%0d/imem_write_data", index));
      write_enable = data.get_integer($sformatf("/inputs/imem_steps/%0d/imem_write_enable", index));
      expected_before = get_word($sformatf("/expected/imem_steps/%0d/before_edge", index));
      expected_after = get_word($sformatf("/expected/imem_steps/%0d/after_edge", index));
      #1;
      if (mem_read_data !== expected_before) begin
        fail($sformatf(
             "step %0d pre-edge expected %08h, observed %08h", index, expected_before, mem_read_data
             ));
      end
      if (data.get_integer($sformatf("/inputs/imem_steps/%0d/clock_edge", index))) begin
        @(posedge clk);
        #1;
      end
      if (mem_read_data !== expected_after) begin
        fail($sformatf(
             "step %0d post-edge expected %08h, observed %08h", index, expected_after, mem_read_data
             ));
      end
      @(negedge clk);
      write_enable = 1'b0;
    end
  endtask

  task automatic check_final_words;
    for (int index = 0; index < data.get_size("/expected/words_after"); index++) begin
      address = get_word($sformatf("/expected/words_after/%0d/address", index));
      #1;
      if (mem_read_data !== get_word($sformatf("/expected/words_after/%0d/data", index))) begin
        fail($sformatf("final word %0d differs", index));
      end
    end
  endtask

  initial begin
    data.load();
    if (DMEM_CAPACITY_BYTES !== data.get_integer("/inputs/C")) begin
      $fatal(1, "elaborated DMEM capacity differs from manifest");
    end
    @(posedge clk);
    seed_words();
    run_steps();
    check_final_words();
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
