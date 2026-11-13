`timescale 1ns / 1ps

module system_top_exclusion_tb;
  import system_pkg::*;
  localparam longint unsigned BAUD_RATE = 64'd3_125_000;
  tp3_case_data data ();
  logic clk = 0;
  logic reset = 1;
  wire serial_rx, serial_tx, uart_reset_request;
  logic   [  7:0] injected_byte;
  integer         discards = 0;
  integer         expected_discards = 0;
  integer         tx_completed = 0;
  integer         descriptor_count = 0;
  bit             discarded_on_last_stop = 0;
  bit             debug_stop_seen = 0;
  bit             check_retention = 0;
  logic   [ 63:0] held_cycles;
  logic   [ 31:0] held_pc;
  logic   [  7:0] held_state;
  logic   [503:0] held_latches;

  system_uart_host #(.BAUD_RATE(BAUD_RATE)) host (.*);
  system_top #(.BAUD_RATE(BAUD_RATE)) dut (.*);
  always #10ns clk = ~clk;

  wire [503:0] latches = {
    dut.processor_inst.g_valid_capacity.ifid,
    dut.processor_inst.g_valid_capacity.idex,
    dut.processor_inst.g_valid_capacity.exmem,
    dut.processor_inst.g_valid_capacity.memwb
  };

  always @(posedge clk) begin
    if (!reset && dut.response_start) descriptor_count++;
    if (!reset && dut.tx_done_tick) tx_completed++;
    if (check_retention && !reset) begin
      if (!dut.debug_read_select || dut.cpu_cycle_fire || dut.prepare_active || dut.load_request ||
          dut.step_request || dut.run_request || uart_reset_request ||
          dut.debug_cycle_count !== held_cycles || dut.debug_pc !== held_pc ||
          dut.global_state_code !== held_state || latches !== held_latches)
        $fatal(1, "Debug ownership or held state changed before the final Stop");
      if (dut.rd_uart) begin
        discards++;
        if (dut.response_done_tick) discarded_on_last_stop = 1;
      end
      if (dut.response_done_tick && dut.serializer_inst.descriptor[0]) begin
        debug_stop_seen <= 1;
        check_retention <= 0;
      end
    end
  end

  // The catalogue specifies bytes at the real FIFO input on consecutive
  // edges. The production serializer, FIFO TX and physical Stop stay live.
  task automatic push_rx(input logic [7:0] value);
    injected_byte = value;
    force dut.uart_inst.rx_fifo.wr = 1'b1;
    force dut.uart_inst.rx_fifo.write_data = injected_byte;
    @(negedge clk);
    release dut.uart_inst.rx_fifo.wr;
    release dut.uart_inst.rx_fifo.write_data;
  endtask

  task automatic inject_command(input string point, input logic [7:0] opcode);
    integer tx_before;
    tx_before = tx_completed;
    if (point == "body") begin
      wait (tx_completed >= tx_before + 16);
      @(negedge clk);
    end else if (point == "last-Stop") begin
      wait (dut.serializer_inst.state == dut.serializer_inst.WAIT_TX_DONE &&
            dut.serializer_inst.tx_pending == 1);
      while (!(dut.uart_inst.transmitter.transmitter_control.state == 4'b1000 &&
               dut.uart_inst.transmitter.transmitter_datapath.sample_count ==
               (opcode == 1 ? 4'd9 : 4'd14)))
      @(negedge clk);
    end
    push_rx(opcode);
    if (opcode == 1) begin
      push_rx(4);
      repeat (4) push_rx(0);
    end
  endtask

  task automatic start_retention;
    wait (dut.debug_read_select);
    @(negedge clk);
    held_cycles     = dut.debug_cycle_count;
    held_pc         = dut.debug_pc;
    held_state      = dut.global_state_code;
    held_latches    = latches;
    check_retention = 1;
  endtask

  task automatic seed_memory(input integer used_bytes);
    if (used_bytes == 1) begin
      dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_1[
          1] = 8'ha5;
      dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_1
          [1] = 1;
    end else begin
      for (integer row = 0; row < 512; row++) begin
        dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity
            .data_lane_0[row] = 8'(4 * row);
        dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity
            .data_lane_1[row] = 8'(4 * row + 1);
        dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity
            .data_lane_2[row] = 8'(4 * row + 2);
        dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity
            .data_lane_3[row] = 8'(4 * row + 3);
        dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity
            .valid_lane_0[row] = 1;
        dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity
            .valid_lane_1[row] = 1;
        dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity
            .valid_lane_2[row] = 1;
        dut.processor_inst.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity
            .valid_lane_3[row] = 1;
      end
    end
  endtask

  initial begin : test
    bit           run_context;
    string        point;
    integer       used_bytes;
    integer       before_descriptors;
    logic   [7:0] opcode;
    data.load();
    run_context = data.get_string("/inputs/context") != "postSTEP";
    point       = data.get_string("/inputs/point");
    used_bytes  = int'(data.get_integer("/inputs/K"));

    repeat (10) @(negedge clk);
    reset = 0;
    host.load_header(40'd4);
    host.send_byte(8'h0b);
    repeat (2) host.send_byte(0);
    host.send_byte(0, 1);
    host.expect_header(1, 2);
    @(negedge clk);
    seed_memory(used_bytes);
    before_descriptors = descriptor_count;
    host.send_byte(run_context ? 8'd2 : 8'd3, 1);

    if (!data.has_path("/inputs/opcode")) begin
      host.expect_header(3, 2);
      if (!dut.debug_read_select) $fatal(1, "missing Debug hold");
      @(negedge clk);
      reset = 1;
      repeat (3) @(negedge clk);
      if (!serial_tx || dut.image_valid || dut.debug_read_select || dut.response_busy)
        $fatal(1, "physical reset did not abort Debug");
      reset = 0;
    end else begin
      opcode            = 8'(data.get_integer("/inputs/opcode"));
      expected_discards = opcode == 1 ? 6 : 1;
      fork
        begin
          start_retention();
          if (run_context && (dut.controller_inst.debug_hold || !dut.response_busy))
            $fatal(1, "RUN terminal must select Debug during ACCEPTED");
          inject_command(point, opcode);
          wait (debug_stop_seen);
          @(negedge clk);
          if (dut.debug_read_select) @(negedge clk);
        end
        begin
          if (run_context) host.expect_header(2, 1);
          host.read_snapshot(run_context ? 8'd2 : 8'd3, run_context ? 8'd10 : 8'd2);
        end
      join
      if (dut.debug_read_select || discards != expected_discards || discarded_on_last_stop !== (
          point == "last-Stop") || descriptor_count - before_descriptors != (run_context ? 2 : 1) ||
          host.used_count !== 40'(used_bytes) || host.cycles() !== held_cycles || host.word_at(
              2
          ) !== held_pc || host.response[0] !== held_state)
        $fatal(
            1,
            "Debug exclusion: RX %0d/%0d last=%b, descriptors=%0d K=%0d held=%b",
            discards,
            expected_discards,
            discarded_on_last_stop,
            descriptor_count - before_descriptors,
            host.used_count,
            dut.debug_read_select
        );
      if (used_bytes == 1) host.check_entry(0, 5, 8'ha5);
      else
        for (integer index = 0; index < used_bytes; index++)
        host.check_entry(index, 32'(index), 8'(index));
    end

    host.send_byte(5, 1);
    host.expect_header(5, 3);
    host.send_byte(3, 1);
    if (data.has_path("/inputs/opcode")) host.read_snapshot(3, 2);
    else host.expect_header(3, 5);
    $display("PASS %s", data.case_id);
    $finish;
  end

  initial begin
    #40ms;
    $fatal(1, "exclusion watchdog at %0t, TX Stops=%0d", $time, tx_completed);
  end
endmodule
