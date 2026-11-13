module response_serializer_debug_fixed_tb;
  tp3_case_data data ();
  logic clk = 0;
  always #5 clk = ~clk;

  logic        reset;
  logic        tx_done_tick;
  logic        tx_full;
  logic [ 7:0] w_data;
  logic        wr_uart;
  logic        response_start;
  logic [ 7:0] response_opcode;
  logic [ 7:0] response_result;
  logic        response_with_debug;
  logic        response_busy;
  logic        response_done_tick;
  logic [ 7:0] debug_state_code;
  logic        debug_image_valid;
  logic [31:0] debug_pc;
  logic [63:0] debug_cycle_count;
  logic [ 2:0] debug_fault_cause;
  logic [31:0] debug_fault_pc;
  logic [ 4:0] debug_rf_addr;
  logic [31:0] debug_rf_data;
  logic        debug_ifid_valid;
  logic [31:0] debug_ifid_pc;
  logic [31:0] debug_ifid_instruction;
  logic        debug_ifid_fetch_fault_valid;
  logic [ 2:0] debug_ifid_fetch_fault_cause;
  logic        debug_idex_valid;
  logic [31:0] debug_idex_pc;
  logic [31:0] debug_idex_instruction;
  logic [ 4:0] debug_idex_rs1;
  logic [ 4:0] debug_idex_rs2;
  logic [ 4:0] debug_idex_rd;
  logic [31:0] debug_idex_rs1_value;
  logic [31:0] debug_idex_rs2_value;
  logic [31:0] debug_idex_immediate;
  logic [ 5:0] debug_idex_alu_op;
  logic        debug_idex_alu_src;
  logic [ 1:0] debug_idex_result_sel;
  logic [ 2:0] debug_idex_flow_op;
  logic [ 3:0] debug_idex_mem_op;
  logic        debug_idex_reg_write;
  logic        debug_exmem_valid;
  logic [31:0] debug_exmem_pc;
  logic [31:0] debug_exmem_instruction;
  logic [ 4:0] debug_exmem_rd;
  logic        debug_exmem_reg_write;
  logic [ 3:0] debug_exmem_mem_op;
  logic [31:0] debug_exmem_ex_result;
  logic [31:0] debug_exmem_store_data;
  logic        debug_memwb_valid;
  logic [31:0] debug_memwb_pc;
  logic [31:0] debug_memwb_instruction;
  logic [ 4:0] debug_memwb_rd;
  logic        debug_memwb_reg_write;
  logic [31:0] debug_memwb_wb_value;

  logic   [7:0] fifo           [  4];
  logic   [7:0] accepted_bytes [256];
  integer       fifo_count;
  integer       accepted_count;
  integer       wait_cycles;
  integer       sim_cycle;

  response_serializer #(
      .DMEM_CAPACITY_BYTES(64'd4)
  ) dut (
      .clk,
      .reset,
      .tx_full,
      .tx_done_tick,
      .w_data,
      .wr_uart,
      .response_start,
      .response_opcode,
      .response_result,
      .response_with_debug,
      .response_busy,
      .response_done_tick,
      .debug_state_code,
      .debug_image_valid,
      .debug_pc,
      .debug_cycle_count,
      .debug_fault_cause,
      .debug_fault_pc,
      .debug_rf_addr,
      .debug_rf_data,
      .debug_ifid_valid,
      .debug_ifid_pc,
      .debug_ifid_instruction,
      .debug_ifid_fetch_fault_valid,
      .debug_ifid_fetch_fault_cause,
      .debug_idex_valid,
      .debug_idex_pc,
      .debug_idex_instruction,
      .debug_idex_rs1,
      .debug_idex_rs2,
      .debug_idex_rd,
      .debug_idex_rs1_value,
      .debug_idex_rs2_value,
      .debug_idex_immediate,
      .debug_idex_alu_op,
      .debug_idex_alu_src,
      .debug_idex_result_sel,
      .debug_idex_flow_op,
      .debug_idex_mem_op,
      .debug_idex_reg_write,
      .debug_exmem_valid,
      .debug_exmem_pc,
      .debug_exmem_instruction,
      .debug_exmem_rd,
      .debug_exmem_reg_write,
      .debug_exmem_mem_op,
      .debug_exmem_ex_result,
      .debug_exmem_store_data,
      .debug_memwb_valid,
      .debug_memwb_pc,
      .debug_memwb_instruction,
      .debug_memwb_rd,
      .debug_memwb_reg_write,
      .debug_memwb_wb_value,
      .debug_dmem_data(8'd0),
      .debug_dmem_used(1'b0)
  );

  assign tx_full       = (fifo_count == 4);
  assign debug_rf_data = rf_value(int'(debug_rf_addr));

  always @(negedge clk) begin
    tx_done_tick = !reset && fifo_count != 0 && (sim_cycle % 3 == 0);
  end

  always @(posedge clk) begin : model_fifo
    logic do_pop;
    logic do_push;
    do_pop  = !reset && tx_done_tick && fifo_count > 0;
    do_push = !reset && wr_uart && !tx_full;
    if (reset) begin
      fifo_count     = 0;
      accepted_count = 0;
    end else begin
      if (do_pop) begin
        for (integer index = 0; index < 3; index++) fifo[index] = fifo[index+1];
        fifo_count = fifo_count - 1;
      end
      if (do_push) begin
        fifo[fifo_count]               = w_data;
        accepted_bytes[accepted_count] = w_data;
        accepted_count                 = accepted_count + 1;
        fifo_count                     = fifo_count + 1;
      end
    end
    sim_cycle = sim_cycle + 1;
  end

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic check(input logic condition, input string message);
    if (!condition) $fatal(1, "%s", message);
  endtask

  function automatic logic [31:0] rf_value(input integer register_index);
    return 32'h01010101 * 32'(register_index);
  endfunction

  function automatic longint signed latch_value(input string latch_name, input integer index);
    string base_path;
    string override_path;
    base_path = $sformatf("/latch_fixture/%s/%0d", latch_name, index);
    override_path = {
      "/inputs/latch_overrides/", latch_name, ".", data.get_string({base_path, "/name"})
    };
    if (data.has_path(override_path)) return data.get_integer(override_path);
    return data.get_integer({base_path, "/value"});
  endfunction

  task automatic initialize_observation;
    debug_state_code             = 8'(data.get_integer("/inputs/context/state"));
    debug_image_valid            = 1'(data.get_integer("/inputs/context/image_valid"));
    debug_pc                     = 32'(data.get_integer("/inputs/context/PC"));
    debug_cycle_count            = 64'(data.get_integer("/inputs/context/cycle_count"));
    debug_fault_cause            = 3'(data.get_integer("/inputs/context/cause"));
    debug_fault_pc               = 32'(data.get_integer("/inputs/context/fault_PC"));
    debug_ifid_valid             = 1'(latch_value("ifid", 0));
    debug_ifid_pc                = 32'(latch_value("ifid", 1));
    debug_ifid_instruction       = 32'(latch_value("ifid", 2));
    debug_ifid_fetch_fault_valid = 1'(latch_value("ifid", 3));
    debug_ifid_fetch_fault_cause = 3'(latch_value("ifid", 4));
    debug_idex_valid             = 1'(latch_value("idex", 0));
    debug_idex_pc                = 32'(latch_value("idex", 1));
    debug_idex_instruction       = 32'(latch_value("idex", 2));
    debug_idex_rs1               = 5'(latch_value("idex", 3));
    debug_idex_rs2               = 5'(latch_value("idex", 4));
    debug_idex_rd                = 5'(latch_value("idex", 5));
    debug_idex_rs1_value         = 32'(latch_value("idex", 6));
    debug_idex_rs2_value         = 32'(latch_value("idex", 7));
    debug_idex_immediate         = 32'(latch_value("idex", 8));
    debug_idex_alu_op            = 6'(latch_value("idex", 9));
    debug_idex_alu_src           = 1'(latch_value("idex", 10));
    debug_idex_result_sel        = 2'(latch_value("idex", 11));
    debug_idex_flow_op           = 3'(latch_value("idex", 12));
    debug_idex_mem_op            = 4'(latch_value("idex", 13));
    debug_idex_reg_write         = 1'(latch_value("idex", 14));
    debug_exmem_valid            = 1'(latch_value("exmem", 0));
    debug_exmem_pc               = 32'(latch_value("exmem", 1));
    debug_exmem_instruction      = 32'(latch_value("exmem", 2));
    debug_exmem_rd               = 5'(latch_value("exmem", 3));
    debug_exmem_reg_write        = 1'(latch_value("exmem", 4));
    debug_exmem_mem_op           = 4'(latch_value("exmem", 5));
    debug_exmem_ex_result        = 32'(latch_value("exmem", 6));
    debug_exmem_store_data       = 32'(latch_value("exmem", 7));
    debug_memwb_valid            = 1'(latch_value("memwb", 0));
    debug_memwb_pc               = 32'(latch_value("memwb", 1));
    debug_memwb_instruction      = 32'(latch_value("memwb", 2));
    debug_memwb_rd               = 5'(latch_value("memwb", 3));
    debug_memwb_reg_write        = 1'(latch_value("memwb", 4));
    debug_memwb_wb_value         = 32'(latch_value("memwb", 5));
  endtask

  initial begin
    integer response_length;
    data.load();
    reset               = 1;
    tx_done_tick        = 0;
    response_start      = 0;
    response_opcode     = 8'h03;
    response_result     = 8'h02;
    response_with_debug = 1;
    fifo_count          = 0;
    accepted_count      = 0;
    sim_cycle           = 0;
    wait_cycles         = 0;
    initialize_observation();
    tick();
    reset          = 0;
    response_start = 1;
    tick();
    response_start  = 0;
    response_length = data.get_size("/expected/response_bytes");

    while (!response_done_tick && wait_cycles < 10000) begin
      @(negedge clk);
      #2;
      wait_cycles++;
    end
    check(response_done_tick && response_busy, "response completes on the last Stop");
    check(accepted_count == response_length && response_length == 230, "complete snapshot length");
    for (integer index = 0; index < response_length; index++) begin
      if (accepted_bytes[index] !== 8'(data.get_integer(
              $sformatf("/expected/response_bytes/%0d", index)
          )))
        $fatal(1, "snapshot byte %0d mismatch: got %02x", index, accepted_bytes[index]);
    end
    tick();
    check(!response_busy, "last Stop releases the serializer");
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
