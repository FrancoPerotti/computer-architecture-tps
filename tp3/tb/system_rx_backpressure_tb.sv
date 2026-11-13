`timescale 1ns / 1ps

module system_rx_backpressure_tb #(
    parameter integer CASE_INDEX = 2
);
  localparam longint unsigned BAUD_RATE = 64'd3_125_000;
  logic clk = 0;
  logic reset = 1;
  wire serial_rx, serial_tx, uart_reset_request;
  logic   [7:0] injected_byte = 8'h55;
  integer       clock_index = 0;
  integer       enqueue_edge = 0;
  integer       consume_edge = 0;
  bit           injecting = 0;

  system_uart_host #(.BAUD_RATE(BAUD_RATE)) host (.*);
  system_top #(.BAUD_RATE(BAUD_RATE)) dut (.*);
  always #10ns clk = ~clk;

  always @(posedge clk) begin
    clock_index++;
    if (injecting && dut.uart_inst.rx_fifo.wr) enqueue_edge = clock_index;
    if (injecting && dut.rd_uart) consume_edge = clock_index;
    if (injecting && dut.response_start) $fatal(1, "RX produced an extra response");
  end

  initial begin
    repeat (10) @(negedge clk);
    reset = 0;
    @(negedge clk);
    if (CASE_INDEX == 6) begin
      host.load_header(40'd4);
      host.send_byte(8'h0b);
      repeat (2) host.send_byte(0);
      host.send_byte(0, 1);
      host.expect_header(1, 2);
      @(negedge clk);
      dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_1[
          1] = 8'ha5;
      dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_1
          [1] = 1;
      host.send_byte(2, 1);
      host.expect_header(2, 1);
      fork
        host.read_snapshot(2, 10);
        begin
          wait (dut.debug_read_select);
          @(negedge clk);
          dut.controller_inst.protocol_state = dut.controller_inst.RECOVER_RX;
          wait (dut.serializer_inst.state == dut.serializer_inst.ENQUEUE_ENTRY &&
                dut.serializer_inst.shared_byte_index == 4 && dut.tx_full);
          @(negedge clk);
          injecting = 1;
          force dut.uart_inst.rx_fifo.wr = 1;
          force dut.uart_inst.rx_fifo.write_data = injected_byte;
          @(negedge clk);
          release dut.uart_inst.rx_fifo.wr;
          release dut.uart_inst.rx_fifo.write_data;
          repeat (3) begin
            if (!dut.tx_full || dut.wr_uart || dut.serializer_inst.next_byte !== 8'ha5 ||
                dut.debug_dmem_addr != 5 || !dut.debug_read_select || dut.cpu_cycle_fire)
              $fatal(1, "pending ENTRY or CPU changed during full TX");
            @(negedge clk);
          end
          while (dut.tx_full) @(negedge clk);
          if (!dut.wr_uart || dut.w_data !== 8'ha5 || consume_edge != enqueue_edge + 1 ||
              !dut.rx_empty)
            $fatal(1, "TX space or RX discard missed its edge");
        end
      join
      host.check_entry(0, 5, 8'ha5);
      if (host.used_count !== 1 || host.response[0] !== 10)
        $fatal(1, "RUN terminal snapshot changed during recovery");
      $display("PASS TEST-UART-009/C006");
      $finish;
    end
    // Artificial full and busy flags isolate the Controller from TX traffic.
    // The real RX FIFO still writes and retires the injected byte.
    force dut.serializer_inst.tx_full = 1;
    force dut.uart_inst.transmitter.tx_busy = 1;
    dut.controller_inst.protocol_state = CASE_INDEX == 2 ? dut.controller_inst.RECEIVE_LOAD_SIZE :
        dut.controller_inst.RECOVER_RX;
    injecting = 1;
    force dut.uart_inst.rx_fifo.wr = 1;
    force dut.uart_inst.rx_fifo.write_data = injected_byte;
    @(negedge clk);
    release dut.uart_inst.rx_fifo.wr;
    release dut.uart_inst.rx_fifo.write_data;
    repeat (2) @(negedge clk);
    if (enqueue_edge == 0 || consume_edge != enqueue_edge + 1 || !dut.rx_empty ||
        dut.controller_inst.load_size_received !== (CASE_INDEX == 2 ? 40'h55 : 40'h00) ||
        dut.controller_inst.size_byte_index !== (CASE_INDEX == 2 ? 3'd1 : 3'd0))
      $fatal(1, "RX did not advance independently of TX");
    $display("PASS TEST-UART-009/C%03d", CASE_INDEX);
    $finish;
  end

  initial begin
    #3ms;
    $fatal(1, "RX/TX backpressure watchdog");
  end
endmodule
