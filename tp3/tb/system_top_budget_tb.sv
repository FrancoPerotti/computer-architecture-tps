`timescale 1ns / 1ps

module system_top_budget_tb #(
    parameter bit              ALT_PROFILE = 0,
    parameter longint unsigned BAUD_RATE   = system_pkg::UART_BAUD_RATE
);
  import system_pkg::*;
  localparam memory_capacity_t IMEM_BYTES = ALT_PROFILE ? 1000 : 1024;
  localparam memory_capacity_t DMEM_BYTES = ALT_PROFILE ? 1000 : 2048;
  integer case_index;
  integer variant;
  integer expected_used;
  integer image_bytes;
  localparam integer FRAME_BOUND = 26083;

  logic clk = 0;
  logic reset = 1;
  wire serial_rx, serial_tx, uart_reset_request;
  integer cycle = 0;
  integer prepared_clocks = 0;
  integer rx_push_cycle = -1;
  integer rx_peak = 0;
  integer response_start_cycle = 0;
  integer tx_count = 0;
  integer last_progress = 0;
  integer fixed_stop_cycle = 0;
  integer final_stop_cycle = 0;

  system_uart_host #(
      .BAUD_RATE     (BAUD_RATE),
      .MAX_USED_BYTES(int'(DMEM_BYTES))
  ) host (
      .*
  );
  system_top #(
      .IMEM_CAPACITY_BYTES(IMEM_BYTES),
      .DMEM_CAPACITY_BYTES(DMEM_BYTES),
      .BAUD_RATE          (BAUD_RATE)
  ) dut (
      .*
  );
  always #10ns clk = ~clk;

  function automatic logic [31:0] image_word(input integer index);
    if (variant == 0)
      return index == image_bytes / 4 - 1 ? 32'h0000000b : (32'(index) << 20) | 32'h00000093;
    if (variant == 2) return 32'h0000000b;
    if (variant == 3) begin
      case (index)
        0: return 32'h00000113;  // addi x2,x0,0
        1: return 32'h00200023;  // sb x2,0(x0)
        default: return 32'h0000000b;
      endcase
    end
    case (index)
      0: return 32'h00000093;  // addi x1,x0,0
      1: return 32'h00000113;  // addi x2,x0,0
      2: return (32'(DMEM_BYTES / 4) << 20) | 32'h00000193;
      3: return 32'h0020a023;  // sw x2,0(x1)
      4: return 32'h00408093;  // addi x1,x1,4
      5: return 32'hfff18193;  // addi x3,x3,-1
      6: return 32'hfe019ae3;  // bne x3,x0,-12
      default: return 32'h0000000b;
    endcase
  endfunction

  always @(posedge clk) begin
    cycle = cycle + 1;
    if (!reset) begin
      if (dut.prepare_active) prepared_clocks = prepared_clocks + 1;
      if (dut.uart_inst.rx_done_tick) begin
        rx_push_cycle = cycle;
        if (dut.load_byte_valid) $fatal(1, "RX push coincides with LOAD delivery");
      end
      if (dut.load_byte_valid) begin
        last_progress++;
        if (last_progress % 256 == 0)
          $display("LOAD progress: %0d bytes at %0d clocks", last_progress, cycle);
      end
      if (dut.rd_uart && cycle != rx_push_cycle + 1)
        $fatal(1, "RX consumed at %0d, pushed at %0d", cycle, rx_push_cycle);
      if (dut.rx_error_tick) $fatal(1, "Unexpected RX error");
      if (int'(dut.uart_inst.rx_fifo.count) > rx_peak) rx_peak = int'(dut.uart_inst.rx_fifo.count);
      if (dut.response_start) begin
        response_start_cycle = cycle;
        tx_count             = 0;
      end
      if (dut.tx_done_tick) begin
        tx_count = tx_count + 1;
        if (tx_count == 230) fixed_stop_cycle = cycle;
        if (tx_count % 1000 == 0) $display("TX progress: %0d bytes at %0d clocks", tx_count, cycle);
      end
      if (dut.response_done_tick) final_stop_cycle = cycle;
    end
  end

  initial begin : test
    logic   [31:0] word_value;
    time           request_start;
    time           content_start;
    integer        response_clocks;
    string         case_id;
    if (!$value$plusargs(
            "CASE=%s", case_id
        ) || $sscanf(
            case_id, "TEST-UART-014/C%d", case_index
        ) != 1)
      $fatal(1, "expected a TEST-UART-014 case ID");
    if (case_index < 1 || case_index > 10 || ALT_PROFILE != (case_index > 5))
      $fatal(1, "case and elaborated memory profile do not match");
    variant       = (case_index - 1) % 5;
    expected_used = variant == 4 ? int'(DMEM_BYTES) : (variant == 3 ? 1 : 0);
    image_bytes   = variant == 0 ? int'(IMEM_BYTES) : variant == 2 ? 4 : variant == 3 ? 12 : 32;
    #200ns;
    @(negedge clk);
    reset = 0;

    request_start = $time;
    if (variant == 1) begin
      host.send_byte(8'h05, 1);
      host.expect_header(8'h05, 8'h03);
      @(posedge dut.response_done_tick);
      @(posedge clk);
      @(negedge clk);
      response_clocks = final_stop_cycle - response_start_cycle;
      if (response_clocks <= 0 || tx_count != 2 || response_clocks > 2 * FRAME_BOUND + 16 ||
          $time - request_start > 200ms)
        $fatal(1, "CHECK_READY exceeded response budget");
      $display("short=%0d clocks, request to stop=%0t", response_clocks, $time - request_start);
    end else begin
      host.load_header(40'(image_bytes));
      @(posedge dut.response_done_tick);
      @(posedge clk);
      @(negedge clk);
      content_start = $time;
      for (integer index = 0; index < image_bytes; index++) begin
        word_value = image_word(index / 4);
        host.send_byte(word_value[8*(index%4)+:8], index == image_bytes - 1);
      end
      host.expect_header(8'h01, 8'h02);
      @(posedge dut.response_done_tick);
      @(posedge clk);
      @(negedge clk);
      if (prepared_clocks != int'(DMEM_BYTES) + 1 || rx_peak != 1)
        $fatal(1, "preparation=%0d, peak RX=%0d", prepared_clocks, rx_peak);
      if ($time - content_start > 201ms + (1s * image_bytes * 10) / 19200)
        $fatal(1, "LOAD/DONE exceeded response budget");
      $display("load=%0t, preparation=%0d clocks, peak RX=%0d", $time - content_start,
               prepared_clocks, rx_peak);

      if (variant >= 2) begin
        host.send_byte(8'h02, 1);
        host.expect_header(8'h02, 8'h01);
        host.read_snapshot(8'h02, 8'h0a);
        @(posedge dut.response_done_tick);
        @(posedge clk);
        @(negedge clk);
        if (host.response[0] !== 8'h0a || host.used_count !== 40'(expected_used))
          $fatal(1, "RUN state/used_count mismatch: %h/%0d", host.response[0], host.used_count);
        for (integer index = 0; index < expected_used; index++)
        host.check_entry(index, 32'(index), 0);
        if (tx_count != 230 + 5 * expected_used || fixed_stop_cycle - response_start_cycle >
            230 * FRAME_BOUND + int'(DMEM_BYTES) + 16 || final_stop_cycle - fixed_stop_cycle >
            (5 * expected_used + 1) * FRAME_BOUND + int'(DMEM_BYTES) + 16 ||
            final_stop_cycle - response_start_cycle >
            (230 + 5 * expected_used) * FRAME_BOUND + 2 * int'(DMEM_BYTES) + 16)
          $fatal(1, "Debug response exceeded budget");
        $display("debug_fixed=%0d clocks, debug_list=%0d clocks, bytes=%0d",
                 fixed_stop_cycle - response_start_cycle, final_stop_cycle - fixed_stop_cycle,
                 tx_count);
      end
    end
    $display("PASS TEST-UART-014/C%03d", case_index);
    $finish;
  end

  initial begin
    #7s;
    $fatal(1, "TEST-UART-014 timed out at %0t, TX bytes=%0d", $time, tx_count);
  end
endmodule
