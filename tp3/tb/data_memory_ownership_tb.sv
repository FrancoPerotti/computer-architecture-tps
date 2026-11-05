`timescale 1ns / 1ps

// Proyecta prioridades y exclusión de ownership directamente sobre DMEM.
module data_memory_ownership_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd4,
    localparam int unsigned BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
);
  import system_pkg::*;

  tp3_case_data data ();
  logic                           clk = 1'b0;
  logic                           reset = 1'b1;
  word_t                          address = '0;
  word_t                          write_data = '0;
  logic                           write_enable = 1'b0;
  logic  [                   3:0] byte_enable = '0;
  logic                           prepare_dmem_clear = 1'b0;
  logic  [BYTE_ADDRESS_WIDTH-1:0] prepare_dmem_addr = '0;
  logic                           debug_read_select = 1'b0;
  logic  [BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr = '0;
  word_t                          mem_read_data;
  logic  [                   7:0] debug_dmem_data;
  logic                           debug_dmem_used;

  data_memory #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk               (clk),
      .reset             (reset),
      .address           (address),
      .write_data        (write_data),
      .write_enable      (write_enable),
      .byte_enable       (byte_enable),
      .prepare_dmem_clear(prepare_dmem_clear),
      .prepare_dmem_addr (prepare_dmem_addr),
      .debug_read_select (debug_read_select),
      .debug_dmem_addr   (debug_dmem_addr),
      .mem_read_data     (mem_read_data),
      .debug_dmem_data   (debug_dmem_data),
      .debug_dmem_used   (debug_dmem_used)
  );

  always #5 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic seed_memory;
    @(negedge clk);
    reset             = 1'b0;
    debug_read_select = 1'b0;
    address           = '0;
    write_data        = 32'h1122_3344;
    byte_enable       = 4'b1111;
    write_enable      = 1'b1;
    @(posedge clk);
    #1;
    @(negedge clk);
    write_enable = 1'b0;
  endtask

  task automatic check_lane(input int unsigned lane, input logic expected_used,
                            input logic [7:0] expected_data);
    debug_read_select = 1'b1;
    debug_dmem_addr   = BYTE_ADDRESS_WIDTH'(lane);
    #1;
    if (debug_dmem_used !== expected_used ||
        debug_dmem_data !== (expected_used ? expected_data : 8'b0)) begin
      fail($sformatf(
           "lane %0d expected used/data %0b/%02h, observed %0b/%02h",
           lane,
           expected_used,
           expected_data,
           debug_dmem_used,
           debug_dmem_data
           ));
    end
    debug_read_select = 1'b0;
  endtask

  task automatic check_original_word;
    check_lane(0, 1'b1, 8'h44);
    check_lane(1, 1'b1, 8'h33);
    check_lane(2, 1'b1, 8'h22);
    check_lane(3, 1'b1, 8'h11);
  endtask

  initial begin
    string phase;
    string conflict;
    data.load();
    phase    = "";
    conflict = "";
    if (data.has_path("/inputs/phase")) phase = data.get_string("/inputs/phase");
    if (data.has_path("/inputs/conflict")) conflict = data.get_string("/inputs/conflict");
    @(posedge clk);
    seed_memory();

    if (phase == "PREPARING_READY") begin
      @(negedge clk);
      prepare_dmem_addr  = '0;
      prepare_dmem_clear = 1'b1;
      @(posedge clk);
      #1;
      prepare_dmem_clear = 1'b0;
      check_lane(0, 1'b0, 8'h00);
      check_lane(1, 1'b1, 8'h33);
    end else if (phase == "DEBUG-exclusive") begin
      check_original_word();
    end else if (phase == "idle-no-agent") begin
      @(posedge clk);
      #1;
      check_original_word();
    end else if (conflict == "clear-store") begin
      @(negedge clk);
      prepare_dmem_clear = 1'b1;
      prepare_dmem_addr  = '0;
      address            = '0;
      write_data         = 32'haabb_ccdd;
      byte_enable        = 4'b1111;
      write_enable       = 1'b1;
      @(posedge clk);
      #1;
      prepare_dmem_clear = 1'b0;
      write_enable       = 1'b0;
      check_lane(0, 1'b0, 8'h00);
      check_lane(1, 1'b1, 8'h33);
      check_lane(2, 1'b1, 8'h22);
      check_lane(3, 1'b1, 8'h11);
    end else if (conflict == "reset-clear-store") begin
      @(negedge clk);
      reset              = 1'b1;
      prepare_dmem_clear = 1'b1;
      prepare_dmem_addr  = '0;
      write_data         = 32'haabb_ccdd;
      byte_enable        = 4'b1111;
      write_enable       = 1'b1;
      @(posedge clk);
      #1;
      reset              = 1'b0;
      prepare_dmem_clear = 1'b0;
      write_enable       = 1'b0;
      check_original_word();
    end else if (conflict == "DMEM-CPU-debug") begin
      @(negedge clk);
      debug_read_select = 1'b1;
      write_enable      = 1'b1;
      byte_enable       = 4'b1111;
      @(posedge clk);
      #1;
      fail("DMEM ownership conflict was not rejected");
    end else begin
      fail("case is outside the local DMEM ownership projection");
    end

    $display("PASS %s", data.case_id);
    $finish;
  end

  final begin
    if (data.loaded && data.case_id == "TEST-MEM-006/C010") begin
      $display("REJECT %s %s", data.case_id, data.get_string("/expected/result"));
    end
  end
endmodule
