module response_serializer_dmem_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_DMEM_CAPACITY_BYTES,
    localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
);
  tp3_case_data data ();
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

  initial begin
    string  bitmap_kind;
    integer used_bytes;
    data.load();
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
    tick();
    reset = 0;

    bitmap_kind = data.get_string("/inputs/bitmap_kind");
    used_bytes  = int'(data.get_integer("/expected/used_count"));
    for (integer address = 0; address < DMEM_CAPACITY_BYTES; address++) begin
      used_map[address] = bitmap_kind == "all" ||
          ((bitmap_kind == "last-only" || bitmap_kind == "first-last") &&
           address == DMEM_CAPACITY_BYTES - 1) || (bitmap_kind == "first-last" && address == 0);
      dmem_contents[address] = 8'(address);
    end
    check_snapshot(used_bytes);
    check(accepted_count == data.get_integer("/expected/response_length"), "catalogue length");
    for (integer index = 0; index < 5; index++)
    check(accepted_bytes[225+index] == 8'(data.get_integer(
          $sformatf("/expected/count_bytes/%0d", index))), "catalogue count byte");
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
