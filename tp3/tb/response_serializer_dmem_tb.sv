module response_serializer_dmem_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_DMEM_CAPACITY_BYTES,
    localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
);
  logic clk = 0;
  always #5 clk = ~clk;

  logic                             reset;
  logic                             tx_done_tick;
  logic                             tx_full;
  logic   [                    7:0] w_data;
  logic                             wr_uart;
  logic                             response_start;
  logic   [                    7:0] response_opcode;
  logic   [                    7:0] response_result;
  logic                             response_with_debug;
  logic                             response_busy;
  logic                             response_done_tick;
  logic   [ BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr;
  logic   [                    7:0] debug_dmem_data;
  logic                             debug_dmem_used;
  logic   [DMEM_CAPACITY_BYTES-1:0] used_map;
  logic   [                    7:0] dmem_contents          [DMEM_CAPACITY_BYTES];
  logic   [                    7:0] fifo                   [                  4];
  logic   [                    7:0] accepted_bytes         [              12000];
  integer                           fifo_count;
  integer                           accepted_count;
  integer                           sim_cycle;
  integer                           timeout_cycles;
  integer                           expected_count;
  integer                           expected_length;
  integer                           max_tx_pending;
  integer                           address_index;
  integer                           byte_index;
  logic                             done_seen;
  logic                             full_seen;
  logic                             retained_seen;
  logic                             tx_pending_four_seen;
  logic   [                   39:0] expected_count_field;
  logic   [                   31:0] expected_address_field;

  response_serializer #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
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
      .debug_dmem_addr,
      .debug_dmem_data,
      .debug_dmem_used
  );

  assign tx_full         = fifo_count == 4;
  assign debug_dmem_data = dmem_contents[debug_dmem_addr];
  assign debug_dmem_used = used_map[debug_dmem_addr];

  always @(negedge clk) begin
    tx_done_tick = !reset && fifo_count != 0 && (sim_cycle % 3 == 0);
  end

  always @(posedge clk) begin : model_fifo_and_transmitter
    logic do_pop;
    logic do_push;
    logic full_pre;
    do_pop   = !reset && tx_done_tick && fifo_count > 0;
    full_pre = tx_full;
    do_push  = !reset && wr_uart && !tx_full;
    if (reset) begin
      fifo_count     = 0;
      accepted_count = 0;
      done_seen      = 0;
    end else begin
      if (dut.tx_pending != fifo_count)
        $fatal(
            1, "tx_pending=%0d differs from FIFO outstanding count=%0d", dut.tx_pending, fifo_count
        );
      if (dut.tx_pending > 4) $fatal(1, "tx_pending exceeded the documented maximum of four");
      if (dut.tx_pending > max_tx_pending) max_tx_pending = dut.tx_pending;
      if (dut.tx_pending == 4) tx_pending_four_seen = 1;
      if (wr_uart && (!dut.next_byte_available || tx_full || reset))
        $fatal(1, "wr_uart violated byte availability, reset, or tx_full gating");
      if (response_done_tick && (!dut.production_complete || dut.tx_pending != 1 || !tx_done_tick))
        $fatal(1, "response_done_tick violated the final Stop conditions");
      if (response_done_tick) done_seen = 1;
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
    if (!reset && full_pre) full_seen = 1;
    if (!reset && dut.state == 10'b0000001000 && dut.next_byte_available && full_pre) begin
      retained_seen = 1;
      if (wr_uart) $fatal(1, "wr_uart asserted while TX full");
    end
    if (!reset && dut.state == 10'b0000100000 && dut.next_byte_available && full_pre) begin
      retained_seen = 1;
      if (wr_uart) $fatal(1, "wr_uart asserted while TX full");
    end
    if (!reset && dut.state == 10'b0100000000 && dut.next_byte_available && full_pre) begin
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

  task automatic clear_memory;
    for (integer index = 0; index < DMEM_CAPACITY_BYTES; index++) begin
      used_map[index]      = 0;
      dmem_contents[index] = 0;
    end
  endtask

  task automatic reset_serializer;
    reset = 1;
    tick();
    reset = 0;
    tick();
  endtask

  task automatic start_snapshot;
    response_opcode     = 8'h0B;
    response_result     = 8'h04;
    response_with_debug = 1;
    response_start      = 1;
    tick();
    response_start = 0;
  endtask

  task automatic check_snapshot(input integer expected_used);
    begin
      expected_count       = expected_used;
      expected_length      = 230 + (5 * expected_used);
      expected_count_field = expected_used;
      timeout_cycles       = 0;
      done_seen            = 0;
      accepted_count       = 0;
      start_snapshot();
      while (!done_seen && timeout_cycles < DMEM_CAPACITY_BYTES + expected_length * 12 + 100) begin
        tick();
        timeout_cycles = timeout_cycles + 1;
      end
      check(done_seen, "response_done_tick follows the last physical Stop");
      check(accepted_count == expected_length, "complete snapshot length matches 230 + 5*K");
      check(fifo_count == 0, "all snapshot bytes physically left the TX FIFO");
      for (integer count_byte = 0; count_byte < 5; count_byte++) begin
        if (accepted_bytes[225+count_byte] !==
            ((expected_count_field >> (8 * count_byte)) & 40'hFF))
          $fatal(
              1,
              "used_count byte %0d mismatch: got=%02x expected=%02x used_count=%0d",
              count_byte,
              accepted_bytes[225+count_byte],
              (expected_count_field >> (8 * count_byte)),
              dut.used_count
          );
      end
      address_index = 0;
      byte_index    = 230;
      for (integer address = 0; address < DMEM_CAPACITY_BYTES; address++) begin
        if (used_map[address]) begin
          expected_address_field = address;
          for (integer address_byte = 0; address_byte < 4; address_byte++) begin
            if (accepted_bytes[byte_index] !==
                ((expected_address_field >> (8 * address_byte)) & 32'hFF))
              $fatal(1, "DMEM address entry %0d byte %0d mismatch", address_index, address_byte);
            byte_index = byte_index + 1;
          end
          if (accepted_bytes[byte_index] !== dmem_contents[address])
            $fatal(1, "DMEM data entry %0d mismatch", address_index);
          byte_index    = byte_index + 1;
          address_index = address_index + 1;
        end
      end
      check(address_index == expected_used, "used DMEM positions are counted once");
      check(byte_index == expected_length, "DMEM list ends at the documented length");
      check(!response_busy && dut.state == 10'b0000000001,
            "serializer returns idle after physical completion");
    end
  endtask

  task automatic abort_snapshot;
    begin
      response_opcode     = 8'h0B;
      response_result     = 8'h04;
      response_with_debug = 1;
      response_start      = 1;
      tick();
      response_start = 0;
      timeout_cycles = 0;
      while (accepted_count < 20 && timeout_cycles < DMEM_CAPACITY_BYTES + 100) begin
        tick();
        timeout_cycles = timeout_cycles + 1;
      end
      check(response_busy && !done_seen, "response is active before reset");
      check(
          (dut.state == 10'b0000000100 || dut.state == 10'b0000001000) && dut.tx_pending > 0 &&
              fifo_count > 0,
          "production reset also interrupts bytes in physical transmission");
      reset = 1;
      #1;
      check(!response_busy && !response_done_tick && !wr_uart,
            "reset aborts DMEM response without normal completion");
      tick();
      reset = 0;
      check(dut.state == 10'b0000000001, "reset returns to IDLE");
    end
  endtask

  task automatic abort_during_count;
    begin
      response_opcode     = 8'h0B;
      response_result     = 8'h04;
      response_with_debug = 1;
      response_start      = 1;
      tick();
      response_start = 0;
      repeat (8) tick();
      check(dut.state == 10'b0000000010 && debug_dmem_addr == 8 && fifo_count == 0,
            "count reset occurs during the first DMEM traversal");
      check(!done_seen && dut.used_count == 0, "count reset precedes fixed snapshot production");
      reset = 1;
      #1;
      check(!response_busy && !response_done_tick && !wr_uart,
            "reset during count suppresses normal completion and TX writes");
      tick();
      reset = 0;
      check(dut.state == 10'b0000000001, "count reset returns the FSM to IDLE");
    end
  endtask

  initial begin
    reset                = 1;
    tx_done_tick         = 0;
    response_start       = 0;
    response_opcode      = 0;
    response_result      = 0;
    response_with_debug  = 0;
    fifo_count           = 0;
    accepted_count       = 0;
    sim_cycle            = 0;
    done_seen            = 0;
    full_seen            = 0;
    retained_seen        = 0;
    tx_pending_four_seen = 0;
    max_tx_pending       = 0;
    clear_memory();
    if (DMEM_CAPACITY_BYTES == 2048)
      check($bits(debug_dmem_addr) == 11 && $bits(dut.used_count) == 12,
            "REFERENCE address and count widths are 11 and 12 bits");
    if (DMEM_CAPACITY_BYTES == 1000)
      check($bits(debug_dmem_addr) == 10 && $bits(dut.used_count) == 10,
            "ALT_1000 address and count widths are 10 bits");
    tick();
    reset = 0;

    check_snapshot(0);

    reset_serializer();
    clear_memory();
    used_map[7]      = 1;
    dmem_contents[7] = 8'hB4;
    check_snapshot(1);

    reset_serializer();
    clear_memory();
    for (integer entry = 0; entry < 300; entry++) begin
      used_map[entry*2] = 1;
      if (entry % 7 == 0) dmem_contents[entry*2] = 0;
      else dmem_contents[entry*2] = 8'h80 + entry;
    end
    check_snapshot(300);

    reset_serializer();
    clear_memory();
    for (integer address = 0; address < DMEM_CAPACITY_BYTES; address++) begin
      used_map[address] = 1;
      if (address % 31 == 0) dmem_contents[address] = 0;
      else dmem_contents[address] = address;
    end
    check_snapshot(DMEM_CAPACITY_BYTES);

    reset_serializer();
    clear_memory();
    used_map[DMEM_CAPACITY_BYTES-1]      = 1;
    dmem_contents[DMEM_CAPACITY_BYTES-1] = 0;
    check_snapshot(1);

    reset_serializer();
    clear_memory();
    used_map[2]                          = 1;
    dmem_contents[2]                     = 0;
    used_map[17]                         = 1;
    dmem_contents[17]                    = 8'hA3;
    used_map[DMEM_CAPACITY_BYTES-1]      = 1;
    dmem_contents[DMEM_CAPACITY_BYTES-1] = 8'hFE;
    check_snapshot(3);
    check(full_seen && retained_seen, "FIFO full and pending-byte retention were exercised");
    check(tx_pending_four_seen && max_tx_pending == 4,
          "tx_pending reaches but never exceeds the four-byte FIFO bound");

    reset_serializer();
    clear_memory();
    abort_during_count();

    reset_serializer();
    clear_memory();
    used_map[4]      = 1;
    dmem_contents[4] = 8'h66;
    abort_snapshot();

    $display("PASS response_serializer DMEM profile capacity=%0d", DMEM_CAPACITY_BYTES);
    $finish;
  end
endmodule
