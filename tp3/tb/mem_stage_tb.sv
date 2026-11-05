`timescale 1ns / 1ps

// Verifica stores, cero lógico y loads a través de la integración completa de MEM.
module mem_stage_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd4,
    localparam int unsigned BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
);
  import system_pkg::*;

  tp3_case_data data ();
  logic                             clk = 1'b0;
  logic                             reset = 1'b1;
  logic                             cpu_cycle_fire = 1'b0;
  logic                             prepare_dmem_clear = 1'b0;
  logic                             debug_read_select = 1'b0;
  logic    [BYTE_ADDRESS_WIDTH-1:0] prepare_dmem_addr = '0;
  logic    [BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr = '0;
  logic    [                   7:0] debug_dmem_data;
  logic                             debug_dmem_used;
  mem_op_t                          selected_mem_op;
  ex_mem_t                          exmem = '0;
  mem_wb_t                          memwb_input;

  mem_stage #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk               (clk),
      .reset             (reset),
      .exmem             (exmem),
      .cpu_cycle_fire    (cpu_cycle_fire),
      .prepare_dmem_clear(prepare_dmem_clear),
      .prepare_dmem_addr (prepare_dmem_addr),
      .debug_read_select (debug_read_select),
      .debug_dmem_addr   (debug_dmem_addr),
      .memwb_input       (memwb_input),
      .debug_dmem_data   (debug_dmem_data),
      .debug_dmem_used   (debug_dmem_used)
  );

  always #5 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  function automatic word_t get_word(input string path);
    longint signed value;
    word_t         parsed;
    if (data.get_type(path) == "string") begin
      if ($sscanf(data.get_string(path), "0x%h", parsed) != 1) begin
        $fatal(1, "invalid word at %s", path);
      end
      return parsed;
    end
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > 64'hffff_ffff) begin
      $fatal(1, "word outside range at %s", path);
    end
    return word_t'(value);
  endfunction

  function automatic word_t get_physical(input string path);
    integer byte_0;
    integer byte_1;
    integer byte_2;
    integer byte_3;
    word_t  value;
    if ($sscanf(data.get_string(path), "%h %h %h %h", byte_0, byte_1, byte_2, byte_3) != 4) begin
      $fatal(1, "invalid physical byte fixture at %s", path);
    end
    value[7:0]   = byte_0[7:0];
    value[15:8]  = byte_1[7:0];
    value[23:16] = byte_2[7:0];
    value[31:24] = byte_3[7:0];
    return value;
  endfunction

  function automatic logic [3:0] get_bitmap(input string path);
    logic [3:0] value;
    if ($sscanf(data.get_string(path), "%b", value) != 1) begin
      $fatal(1, "invalid bitmap at %s", path);
    end
    return value;
  endfunction

  function automatic word_t get_isa_physical;
    integer byte_0;
    integer byte_1;
    integer byte_2;
    integer byte_3;
    word_t  value;
    if ($sscanf(data.get_string("/inputs/data"), "0x%h", value) == 1) return value;
    if ($sscanf(
            data.get_string("/inputs/data"), "%h %h %h %h", byte_0, byte_1, byte_2, byte_3
        ) != 4) begin
      $fatal(1, "invalid ISA memory data fixture");
    end
    value[7:0]   = byte_0[7:0];
    value[15:8]  = byte_1[7:0];
    value[23:16] = byte_2[7:0];
    value[31:24] = byte_3[7:0];
    return value;
  endfunction

  task automatic load_mem_op;
    string operation;
    operation       = data.get_string("/inputs/op");
    selected_mem_op = MEM_OP_NONE;
    if (operation == "LB") selected_mem_op = MEM_OP_LB;
    else if (operation == "LH") selected_mem_op = MEM_OP_LH;
    else if (operation == "LW") selected_mem_op = MEM_OP_LW;
    else if (operation == "LBU") selected_mem_op = MEM_OP_LBU;
    else if (operation == "LHU") selected_mem_op = MEM_OP_LHU;
    else if (operation == "SB") selected_mem_op = MEM_OP_SB;
    else if (operation == "SH") selected_mem_op = MEM_OP_SH;
    else if (operation == "SW") selected_mem_op = MEM_OP_SW;
    else $fatal(1, "unknown memory operation: %s", operation);
  endtask

  task automatic seed_memory(input word_t physical, input logic [3:0] bitmap);
    @(negedge clk);
    reset             = 1'b0;
    debug_read_select = 1'b0;
    exmem             = '0;
    exmem.valid       = 1'b1;
    exmem.mem_op      = MEM_OP_SW;
    exmem.store_data  = physical;
    cpu_cycle_fire    = 1'b1;
    @(posedge clk);
    #1;
    @(negedge clk);
    cpu_cycle_fire = 1'b0;
    exmem.valid    = 1'b0;
    for (int unsigned lane = 0; lane < 4; lane++) begin
      if (!bitmap[lane]) begin
        prepare_dmem_addr  = BYTE_ADDRESS_WIDTH'(lane);
        prepare_dmem_clear = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        prepare_dmem_clear = 1'b0;
      end
    end
  endtask

  task automatic check_memory(input word_t physical, input logic [3:0] bitmap);
    logic [7:0] expected_byte;
    debug_read_select = 1'b1;
    for (int unsigned lane = 0; lane < 4; lane++) begin
      debug_dmem_addr = BYTE_ADDRESS_WIDTH'(lane);
      #1;
      if (debug_dmem_used !== bitmap[lane]) begin
        fail($sformatf(
             "lane %0d used: expected %0b, observed %0b", lane, bitmap[lane], debug_dmem_used));
      end
      expected_byte = 8'b0;
      if (bitmap[lane]) expected_byte = physical[8*lane+:8];
      if (debug_dmem_data !== expected_byte) begin
        fail($sformatf(
             "lane %0d data: expected %02h, observed %02h", lane, expected_byte, debug_dmem_data));
      end
    end
    debug_read_select = 1'b0;
  endtask

  task automatic run_store_case;
    string       disabled_guard;
    word_t       expected_physical;
    logic  [3:0] expected_bitmap;
    disabled_guard = "ninguna";
    if (data.has_path("/inputs/disabled_guard")) begin
      disabled_guard = data.get_string("/inputs/disabled_guard");
    end
    @(negedge clk);
    exmem       = '0;
    exmem.valid = 1'b1;
    if (disabled_guard == "EXMEM_valid0") exmem.valid = 1'b0;
    load_mem_op();
    exmem.mem_op     = selected_mem_op;
    exmem.ex_result  = get_word("/inputs/EA");
    exmem.store_data = get_word("/inputs/data");
    cpu_cycle_fire   = 1'b1;
    if (disabled_guard == "fire0") cpu_cycle_fire = 1'b0;
    reset = 1'b0;
    if (disabled_guard == "reset1") reset = 1'b1;
    debug_read_select = 1'b0;
    @(posedge clk);
    #1;
    reset             = 1'b0;
    cpu_cycle_fire    = 1'b0;
    expected_physical = get_physical("/expected/physical_after");
    expected_bitmap   = get_bitmap("/expected/bitmap_after");
    check_memory(expected_physical, expected_bitmap);
  endtask

  task automatic run_load_case;
    word_t       expected_value;
    logic  [3:0] bitmap;
    @(negedge clk);
    exmem             = '0;
    exmem.valid       = 1'b1;
    exmem.pc          = 32'h10;
    exmem.instruction = 32'h0000_0003;
    exmem.rd          = 5'd7;
    exmem.reg_write   = 1'b1;
    load_mem_op();
    exmem.mem_op    = selected_mem_op;
    exmem.ex_result = get_word("/inputs/EA");
    cpu_cycle_fire  = 1'b1;
    #1;
    expected_value = get_word("/expected/load_value");
    if (memwb_input.wb_value !== expected_value) begin
      fail($sformatf(
           "load value: expected %08h, observed %08h", expected_value, memwb_input.wb_value));
    end
    if (memwb_input.valid !== exmem.valid || memwb_input.pc !== exmem.pc ||
        memwb_input.instruction !== exmem.instruction || memwb_input.rd !== exmem.rd ||
        memwb_input.reg_write !== exmem.reg_write) begin
      fail("MEM/WB identity or control fields differ from EX/MEM");
    end
    bitmap = get_bitmap("/inputs/bitmap");
    check_memory(get_physical("/inputs/physical"), bitmap);
  endtask

  task automatic run_isa_case;
    word_t       effective_address;
    word_t       physical;
    word_t       expected_physical;
    word_t       expected_load;
    word_t       shifted;
    logic  [3:0] bitmap;
    load_mem_op();
    effective_address = word_t
        '($signed(data.get_integer("/inputs/base")) + $signed(data.get_integer("/inputs/offset")));
    bitmap = get_bitmap("/inputs/bitmap");
    if (selected_mem_op == MEM_OP_SB || selected_mem_op == MEM_OP_SH ||
        selected_mem_op == MEM_OP_SW) begin
      physical = 32'hd4c3_b2a1;
    end else begin
      physical = get_isa_physical();
    end
    seed_memory(physical, bitmap);
    @(negedge clk);
    exmem             = '0;
    exmem.valid       = 1'b1;
    exmem.pc          = 32'h20;
    exmem.instruction = 32'h0000_0003;
    exmem.rd          = 5'd3;
    exmem.mem_op      = selected_mem_op;
    exmem.ex_result   = effective_address;
    cpu_cycle_fire    = 1'b1;
    if (selected_mem_op == MEM_OP_SB || selected_mem_op == MEM_OP_SH ||
        selected_mem_op == MEM_OP_SW) begin
      exmem.store_data  = get_word("/inputs/data");
      exmem.reg_write   = 1'b0;
      expected_physical = physical;
      case (selected_mem_op)
        MEM_OP_SB: expected_physical[8*effective_address[1:0]+:8] = exmem.store_data[7:0];
        MEM_OP_SH: expected_physical[16*effective_address[1]+:16] = exmem.store_data[15:0];
        MEM_OP_SW: expected_physical = exmem.store_data;
        default:   expected_physical = physical;
      endcase
      @(posedge clk);
      #1;
      cpu_cycle_fire = 1'b0;
      check_memory(expected_physical, 4'b1111);
      if (memwb_input.reg_write !== 1'b0) fail("store propagated a register write");
    end else begin
      exmem.reg_write = 1'b1;
      #1;
      shifted = physical >> (8 * effective_address[1:0]);
      case (selected_mem_op)
        MEM_OP_LB:  expected_load = {{24{shifted[7]}}, shifted[7:0]};
        MEM_OP_LH:  expected_load = {{16{shifted[15]}}, shifted[15:0]};
        MEM_OP_LW:  expected_load = physical;
        MEM_OP_LBU: expected_load = {24'b0, shifted[7:0]};
        MEM_OP_LHU: expected_load = {16'b0, shifted[15:0]};
        default:    expected_load = '0;
      endcase
      if (memwb_input.wb_value !== expected_load || memwb_input.reg_write !== 1'b1) begin
        fail($sformatf("ISA load: expected %08h, observed %08h", expected_load, memwb_input.wb_value
             ));
      end
      check_memory(physical, bitmap);
    end
    if (data.has_path("/expected/EA") && effective_address !== get_word("/expected/EA")) begin
      fail("negative offset did not form the expected effective address");
    end
    if (data.has_path("/expected/word")) begin
      if (selected_mem_op == MEM_OP_LW && memwb_input.wb_value !== get_word("/expected/word")) begin
        fail("negative-offset LW returned the wrong word");
      end
      if (selected_mem_op == MEM_OP_SW) begin
        check_memory(get_word("/expected/word"), 4'b1111);
      end
    end
  endtask

  initial begin
    word_t       physical;
    logic  [3:0] bitmap;
    data.load();
    @(posedge clk);
    #1;
    if (data.has_path("/inputs/base")) begin
      run_isa_case();
    end else if (data.has_path("/inputs/physical_before")) begin
      physical = get_physical("/inputs/physical_before");
      bitmap   = get_bitmap("/inputs/bitmap_before");
    end else begin
      physical = get_physical("/inputs/physical");
      bitmap   = get_bitmap("/inputs/bitmap");
    end
    if (!data.has_path("/inputs/base")) begin
      seed_memory(physical, bitmap);
      if (data.has_path("/expected/load_value")) begin
        run_load_case();
      end else begin
        run_store_case();
      end
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
