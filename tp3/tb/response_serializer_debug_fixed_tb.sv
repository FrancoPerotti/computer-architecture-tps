module response_serializer_debug_fixed_tb;
  logic clk = 0;
  always #5 clk = ~clk;

  logic        reset;
  logic        tx_done_tick;
  logic        tx_full;
  logic        force_full;
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
  logic   [7:0] expected_bytes [256];
  integer       fifo_count;
  integer       accepted_count;
  integer       expected_count;
  integer       wait_cycles;
  integer       sim_cycle;
  logic         full_seen;
  logic         retained_seen;

  response_serializer dut (
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
      .debug_memwb_wb_value
  );

  assign tx_full       = force_full || (fifo_count == 4);
  assign debug_rf_data = debug_rf_addr == 0 ? 32'b0 : (32'h10203040 + debug_rf_addr);

  always @(negedge clk) begin
    tx_done_tick = !reset && fifo_count != 0 && (sim_cycle % 3 == 0);
  end

  always @(posedge clk) begin : model_fifo
    logic       do_pop;
    logic       do_push;
    logic [7:0] popped_byte;
    do_pop      = !reset && tx_done_tick && fifo_count > 0;
    do_push     = !reset && wr_uart && !tx_full;
    popped_byte = fifo[0];
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
    if (!reset && tx_full) full_seen = 1;
    if (!reset && dut.state == 10'b0000001000 && dut.next_byte_available && tx_full) begin
      retained_seen = 1;
      if (wr_uart) $fatal(1, "wr_uart asserted while TX full");
    end
  end

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic check(input logic condition, input string message);
    if (!condition) $fatal(1, "%s", message);
  endtask

  task automatic expect_byte(input logic [7:0] value);
    expected_bytes[expected_count] = value;
    expected_count                 = expected_count + 1;
  endtask

  task automatic expect_word(input logic [31:0] value);
    for (integer byte_index = 0; byte_index < 4; byte_index++)
      expect_byte(value >> (8 * byte_index));
  endtask

  task automatic expect_double_word(input logic [63:0] value);
    for (integer byte_index = 0; byte_index < 8; byte_index++)
      expect_byte(value >> (8 * byte_index));
  endtask

  function automatic logic [31:0] rf_value(input integer register_index);
    if (register_index == 0) rf_value = 32'b0;
    else rf_value = 32'h10203040 + register_index;
  endfunction

  task automatic build_expected_prefix;
    expected_count = 0;
    expect_byte(8'hA5);
    expect_byte(8'h5A);
    expect_byte(debug_state_code);
    expect_byte({7'b0, debug_image_valid});
    expect_word(debug_pc);
    expect_double_word(debug_cycle_count);
    expect_byte({5'b0, debug_fault_cause});
    expect_word(debug_fault_pc);
    for (integer register_index = 0; register_index < 32; register_index++)
      expect_word(rf_value(register_index));
    expect_byte({7'b0, debug_ifid_valid});
    expect_word(debug_ifid_pc);
    expect_word(debug_ifid_instruction);
    expect_byte({7'b0, debug_ifid_fetch_fault_valid});
    expect_byte({5'b0, debug_ifid_fetch_fault_cause});
    expect_byte({7'b0, debug_idex_valid});
    expect_word(debug_idex_pc);
    expect_word(debug_idex_instruction);
    expect_byte({3'b0, debug_idex_rs1});
    expect_byte({3'b0, debug_idex_rs2});
    expect_byte({3'b0, debug_idex_rd});
    expect_word(debug_idex_rs1_value);
    expect_word(debug_idex_rs2_value);
    expect_word(debug_idex_immediate);
    expect_byte({2'b0, debug_idex_alu_op});
    expect_byte({7'b0, debug_idex_alu_src});
    expect_byte({6'b0, debug_idex_result_sel});
    expect_byte({5'b0, debug_idex_flow_op});
    expect_byte({4'b0, debug_idex_mem_op});
    expect_byte({7'b0, debug_idex_reg_write});
    expect_byte({7'b0, debug_exmem_valid});
    expect_word(debug_exmem_pc);
    expect_word(debug_exmem_instruction);
    expect_byte({3'b0, debug_exmem_rd});
    expect_byte({7'b0, debug_exmem_reg_write});
    expect_byte({4'b0, debug_exmem_mem_op});
    expect_word(debug_exmem_ex_result);
    expect_word(debug_exmem_store_data);
    expect_byte({7'b0, debug_memwb_valid});
    expect_word(debug_memwb_pc);
    expect_word(debug_memwb_instruction);
    expect_byte({3'b0, debug_memwb_rd});
    expect_byte({7'b0, debug_memwb_reg_write});
    expect_word(debug_memwb_wb_value);
  endtask

  task automatic initialize_observation;
    debug_state_code             = 8'h91;
    debug_image_valid            = 1;
    debug_pc                     = 32'h12345678;
    debug_cycle_count            = 64'h0123456789ABCDEF;
    debug_fault_cause            = 3'b101;
    debug_fault_pc               = 32'h89ABCDEF;
    debug_ifid_valid             = 1;
    debug_ifid_pc                = 32'h10203040;
    debug_ifid_instruction       = 32'h50607080;
    debug_ifid_fetch_fault_valid = 1;
    debug_ifid_fetch_fault_cause = 3'b110;
    debug_idex_valid             = 1;
    debug_idex_pc                = 32'h11121314;
    debug_idex_instruction       = 32'h21222324;
    debug_idex_rs1               = 5'h11;
    debug_idex_rs2               = 5'h12;
    debug_idex_rd                = 5'h13;
    debug_idex_rs1_value         = 32'hA1B2C3D4;
    debug_idex_rs2_value         = 32'hE1F2A3B4;
    debug_idex_immediate         = 32'h1234ABCD;
    debug_idex_alu_op            = 6'h2D;
    debug_idex_alu_src           = 1;
    debug_idex_result_sel        = 2'h2;
    debug_idex_flow_op           = 3'h5;
    debug_idex_mem_op            = 4'hB;
    debug_idex_reg_write         = 1;
    debug_exmem_valid            = 1;
    debug_exmem_pc               = 32'h31323334;
    debug_exmem_instruction      = 32'h41424344;
    debug_exmem_rd               = 5'h15;
    debug_exmem_reg_write        = 1;
    debug_exmem_mem_op           = 4'hD;
    debug_exmem_ex_result        = 32'h51525354;
    debug_exmem_store_data       = 32'h61626364;
    debug_memwb_valid            = 1;
    debug_memwb_pc               = 32'h71727374;
    debug_memwb_instruction      = 32'h81828384;
    debug_memwb_rd               = 5'h1A;
    debug_memwb_reg_write        = 1;
    debug_memwb_wb_value         = 32'h91929394;
  endtask

  initial begin
    reset               = 1;
    tx_done_tick        = 0;
    response_start      = 0;
    response_opcode     = 8'hA5;
    response_result     = 8'h5A;
    response_with_debug = 1;
    force_full          = 0;
    fifo_count          = 0;
    accepted_count      = 0;
    expected_count      = 0;
    wait_cycles         = 0;
    sim_cycle           = 0;
    full_seen           = 0;
    retained_seen       = 0;
    initialize_observation();
    tick();
    reset = 0;

    // Captura del descriptor y prueba de la etapa fija desde el estado post-conteo.
    force_full     = 1;
    response_start = 1;
    tick();
    response_start = 0;
    check(dut.descriptor == {8'hA5, 8'h5A, 1'b1}, "17-bit descriptor captured");
    dut.state = 10'b0000000100;
    tick();
    check(dut.next_byte_available && dut.next_byte == 8'hA5 && !wr_uart,
          "opcode is retained while FIFO is full");
    force_full = 0;
    #1;
    build_expected_prefix();

    while (accepted_count < 225 && wait_cycles < 4000) begin
      tick();
      wait_cycles = wait_cycles + 1;
    end
    check(accepted_count == 225, "serializer emits the complete fixed prefix");
    check(expected_count == 225, "fixed prefix has the documented 225 bytes");
    for (integer byte_index = 0; byte_index < 225; byte_index++) begin
      if (accepted_bytes[byte_index] !== expected_bytes[byte_index])
        $fatal(
            1,
            "byte %0d mismatch: got %02x expected %02x",
            byte_index,
            accepted_bytes[byte_index],
            expected_bytes[byte_index]
        );
    end
    check(full_seen && retained_seen, "FIFO full and byte retention were exercised");
    check(dut.fixed_byte_index == 224 && dut.state == 10'b0000010000,
          "fixed prefix stops at the documented used_count boundary");
    check(response_busy && !response_done_tick && !dut.production_complete,
          "Debug response remains incomplete until the DMEM section is implemented");

    reset = 1;
    #1;
    check(!response_busy && !response_done_tick && !wr_uart,
          "reset aborts the partial Debug response without completion");
    tick();
    check(dut.state == 10'b0000000001, "reset returns the FSM to IDLE");
    $display("PASS response_serializer fixed Debug prefix");
    $finish;
  end
endmodule
