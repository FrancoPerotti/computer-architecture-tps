`timescale 1ns / 1ps

module serializer_pending_byte_tb;
  tp3_case_data data ();
  logic       clk = 0;
  logic       reset = 1;
  logic       rd = 0;
  logic [7:0] preload_byte = 0;
  logic       preload = 1;
  logic       response_start = 0;
  logic [7:0] rf_data = 0;
  logic [7:0] dmem_data = 0;
  wire full, empty, wr_uart, response_busy, response_done_tick;
  wire [7:0] w_data, r_data;
  wire [ 4:0] debug_rf_addr;
  wire [10:0] debug_dmem_addr;

  fifo queue (
      .clk,
      .reset,
      .rd,
      .wr        (preload || wr_uart),
      .write_data(preload ? preload_byte : w_data),
      .read_data (r_data),
      .empty,
      .full
  );
  response_serializer #(
      .DMEM_CAPACITY_BYTES(64'd2048)
  ) dut (
      .clk,
      .reset,
      .tx_full            (full),
      .tx_done_tick       (rd && !empty),
      .w_data,
      .wr_uart,
      .response_start,
      .response_opcode    (8'd3),
      .response_result    (8'd2),
      .response_with_debug(1'b1),
      .response_busy,
      .response_done_tick,
      .debug_state_code   (8'd5),
      .debug_image_valid  (1'b1),
      .debug_pc           (32'd0),
      .debug_cycle_count  (64'd0),
      .debug_fault_cause  (3'd0),
      .debug_fault_pc     (32'd0),
      .debug_rf_addr,
      .debug_rf_data      ({24'd0, rf_data}),
      .debug_dmem_addr,
      .debug_dmem_data    (dmem_data),
      .debug_dmem_used    (1'b0)
  );

  always #10ns clk = ~clk;
  task automatic tick;
    @(posedge clk);
    @(negedge clk);
  endtask

  initial begin : test
    integer       case_index;
    logic   [7:0] expected_byte;
    logic   [7:0] fixed_index;
    logic   [2:0] shared_index;
    logic   [9:0] enqueue_state;
    data.load();
    if ($sscanf(data.case_id, "TEST-UART-009/C%d", case_index) != 1)
      $fatal(1, "missing canonical case index");
    expected_byte = 8'(data.get_integer("/inputs/prepared_byte"));
    tick();
    reset = 0;
    repeat (case_index == 7 ? 2 : 4) tick();
    preload        = 0;
    response_start = 1;
    tick();
    response_start = 0;

    // Install a prepared serializer state with a corresponding real TX FIFO.
    dut.tx_pending = queue.count;
    if (case_index == 3) begin
      dut.state      = dut.PREPARE_COUNT;
      dut.used_count = 12'(expected_byte);
    end else if (case_index == 5) begin
      dut.state             = dut.PREPARE_ENTRY;
      dut.shared_byte_index = 4;
      dmem_data             = expected_byte;
    end else begin
      dut.state            = dut.PREPARE_FIXED;
      dut.fixed_byte_index = 21;
      rf_data              = expected_byte;
    end
    tick();
    fixed_index   = dut.fixed_byte_index;
    shared_index  = dut.shared_byte_index;
    enqueue_state = dut.state;
    rf_data       = 8'h55;
    dmem_data     = 8'h55;
    if (case_index == 3) dut.used_count = 0;

    if (case_index != 7) begin
      repeat (3) begin
        #1ns;
        if (!full || wr_uart || dut.next_byte !== expected_byte || !dut.next_byte_available ||
            dut.state !== enqueue_state || dut.fixed_byte_index !== fixed_index ||
            dut.shared_byte_index !== shared_index)
          $fatal(1, "full TX did not hold the prepared byte and cursor");
        tick();
      end
      rd = 1;
      #1ns;
      if (wr_uart) $fatal(1, "write incorrectly used next-cycle FIFO space");
      tick();
      rd = 0;
      #1ns;
      if (!wr_uart || w_data !== expected_byte) $fatal(1, "prepared byte was not resumed");
      tick();
      if (queue.count != 4 || dut.next_byte_available) $fatal(1, "retained byte enqueued twice");
      rd = 1;
      repeat (3) tick();
      if (r_data !== expected_byte) $fatal(1, "wrong byte reached the tail of the FIFO");
    end else begin
      rd = 1;
      #1ns;
      if (full || !wr_uart || w_data !== expected_byte) $fatal(1, "simultaneous enqueue not set");
      tick();
      if (dut.tx_pending != 2 || queue.count != 2) $fatal(1, "pending count changed on push/pop");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
