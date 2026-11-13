module protocol_controller_response_serializer_tb;
  import system_pkg::*;

  localparam integer TX_DEPTH          = 4;
  localparam integer EXPECTED_CAPACITY = 4096;
  localparam integer RX_CAPACITY       = 4;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic         reset;
  logic         rx_error_tick;
  logic         rx_activity;
  logic   [7:0] rx_fifo       [RX_CAPACITY];
  integer       rx_count;
  logic         rx_push;
  logic   [7:0] rx_push_data;
  logic         rx_empty;
  logic   [7:0] r_data;
  logic         rd_uart;

  logic   [7:0] tx_fifo       [TX_DEPTH];
  integer       tx_count;
  logic         force_tx_full;
  logic         pause_tx;
  integer       tx_wait;
  logic         tx_full;
  logic         tx_done_tick;
  logic   [7:0] w_data;
  logic         wr_uart;

  logic       response_start;
  logic [7:0] response_opcode;
  logic [7:0] response_result;
  logic       response_with_debug;
  logic       response_busy;
  logic       response_done_tick;

  logic        load_available;
  logic        prepare_active;
  logic        program_finished;
  logic        fault_terminal;
  logic        image_valid;
  logic        command_accepted;
  logic        cpu_cycle_fire;
  logic        load_request;
  logic        run_request;
  logic        step_request;
  logic [10:0] load_size_bytes;
  logic        load_byte_valid;
  logic [ 7:0] load_byte_data;
  logic [ 9:0] load_byte_offset;
  logic        load_last_byte;
  logic        load_abort;
  logic        uart_reset_request;
  logic        debug_read_select;
  logic [ 4:0] debug_rf_addr;
  logic [10:0] debug_dmem_addr;

  logic   [7:0] expected_bytes           [EXPECTED_CAPACITY];
  integer       expected_count;
  integer       transmitted_count;
  integer       load_data_seen;
  logic         debug_response_in_flight;
  string        selected_case;

  assign rx_empty     = (rx_count == 0);
  assign r_data       = rx_empty ? 8'h00 : rx_fifo[0];
  assign tx_full      = force_tx_full || (tx_count == TX_DEPTH);
  assign tx_done_tick = !reset && !pause_tx && (tx_count != 0) && (tx_wait == 0);

  protocol_controller #(
      .IMEM_CAPACITY_BYTES(REFERENCE_IMEM_CAPACITY_BYTES)
  ) controller (
      .clk,
      .reset,
      .rx_empty,
      .r_data,
      .rx_error_tick,
      .rx_activity,
      .response_busy,
      .response_done_tick,
      .load_available,
      .prepare_active,
      .program_finished,
      .fault_terminal,
      .image_valid,
      .command_accepted,
      .cpu_cycle_fire,
      .rd_uart,
      .response_start,
      .response_opcode,
      .response_result,
      .response_with_debug,
      .load_request,
      .run_request,
      .step_request,
      .load_size_bytes,
      .load_byte_valid,
      .load_byte_data,
      .load_byte_offset,
      .load_last_byte,
      .load_abort,
      .uart_reset_request,
      .debug_read_select
  );

  response_serializer #(
      .DMEM_CAPACITY_BYTES(REFERENCE_DMEM_CAPACITY_BYTES)
  ) serializer (
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
      .debug_state_code            (8'h00),
      .debug_image_valid           (1'b0),
      .debug_pc                    (32'h0),
      .debug_cycle_count           (64'h0),
      .debug_fault_cause           (3'h0),
      .debug_fault_pc              (32'h0),
      .debug_rf_addr,
      .debug_rf_data               (32'h0),
      .debug_ifid_valid            (1'b0),
      .debug_ifid_pc               (32'h0),
      .debug_ifid_instruction      (32'h0),
      .debug_ifid_fetch_fault_valid(1'b0),
      .debug_ifid_fetch_fault_cause(3'h0),
      .debug_idex_valid            (1'b0),
      .debug_idex_pc               (32'h0),
      .debug_idex_instruction      (32'h0),
      .debug_idex_rs1              (5'h0),
      .debug_idex_rs2              (5'h0),
      .debug_idex_rd               (5'h0),
      .debug_idex_rs1_value        (32'h0),
      .debug_idex_rs2_value        (32'h0),
      .debug_idex_immediate        (32'h0),
      .debug_idex_alu_op           (6'h0),
      .debug_idex_alu_src          (1'b0),
      .debug_idex_result_sel       (2'h0),
      .debug_idex_flow_op          (3'h0),
      .debug_idex_mem_op           (4'h0),
      .debug_idex_reg_write        (1'b0),
      .debug_exmem_valid           (1'b0),
      .debug_exmem_pc              (32'h0),
      .debug_exmem_instruction     (32'h0),
      .debug_exmem_rd              (5'h0),
      .debug_exmem_reg_write       (1'b0),
      .debug_exmem_mem_op          (4'h0),
      .debug_exmem_ex_result       (32'h0),
      .debug_exmem_store_data      (32'h0),
      .debug_memwb_valid           (1'b0),
      .debug_memwb_pc              (32'h0),
      .debug_memwb_instruction     (32'h0),
      .debug_memwb_rd              (5'h0),
      .debug_memwb_reg_write       (1'b0),
      .debug_memwb_wb_value        (32'h0),
      .debug_dmem_addr,
      .debug_dmem_data             (8'h0),
      .debug_dmem_used             (1'b0)
  );

  // Abstract RX FIFO and TX FIFO/transmitter. A tx_done_tick removes the
  // oldest queued byte only after the modeled Stop interval.
  always @(posedge clk) begin : model_uart
    logic       pop_rx;
    logic       push_rx;
    logic       pop_tx;
    logic       push_tx;
    logic [7:0] completed_byte;

    pop_rx         = !reset && rd_uart && (rx_count != 0);
    push_rx        = !reset && rx_push && (rx_count < RX_CAPACITY);
    pop_tx         = !reset && tx_done_tick && (tx_count != 0);
    push_tx        = !reset && wr_uart && !tx_full;
    completed_byte = tx_fifo[0];

    if (reset) begin
      rx_count                 <= 0;
      tx_count                 <= 0;
      tx_wait                  <= 2;
      transmitted_count        <= 0;
      load_data_seen           <= 0;
      debug_response_in_flight <= 1'b0;
    end else begin
      if (pop_rx) begin
        for (integer index = 0; index < RX_CAPACITY - 1; index++)
        rx_fifo[index] <= rx_fifo[index+1];
        rx_count <= rx_count - 1;
      end
      if (push_rx) begin
        rx_fifo[rx_count-(pop_rx ? 1 : 0)] <= rx_push_data;
        rx_count                           <= rx_count + (pop_rx ? 0 : 1);
      end

      if (pop_tx) begin
        if (transmitted_count >= expected_count)
          $fatal(
              1,
              "unexpected physical TX byte %02x at position %0d",
              completed_byte,
              transmitted_count
          );
        if (completed_byte !== expected_bytes[transmitted_count])
          $fatal(
              1,
              "TX byte[%0d]=%02x expected %02x",
              transmitted_count,
              completed_byte,
              expected_bytes[transmitted_count]
          );
        transmitted_count <= transmitted_count + 1;
        for (integer index = 0; index < TX_DEPTH - 1; index++) tx_fifo[index] <= tx_fifo[index+1];
        tx_count <= tx_count - 1;
        tx_wait  <= 2;
      end else if (tx_count != 0 && !pause_tx && tx_wait != 0) begin
        tx_wait <= tx_wait - 1;
      end
      if (push_tx) begin
        tx_fifo[tx_count-(pop_tx ? 1 : 0)] <= w_data;
        tx_count                           <= tx_count + (pop_tx ? 0 : 1);
      end

      if (response_start && response_busy) $fatal(1, "response_start asserted while response_busy");
      if (force_tx_full && wr_uart) $fatal(1, "serializer wrote while TX full");

      if (load_byte_valid) begin
        case (load_data_seen)
          0:
          if (load_byte_offset != 0 || load_byte_data != 8'h11 || load_last_byte)
            $fatal(1, "LOAD byte 0 mismatch");
          1:
          if (load_byte_offset != 1 || load_byte_data != 8'h22 || load_last_byte)
            $fatal(1, "LOAD byte 1 mismatch");
          2:
          if (load_byte_offset != 2 || load_byte_data != 8'h33 || load_last_byte)
            $fatal(1, "LOAD byte 2 mismatch");
          3:
          if (load_byte_offset != 3 || load_byte_data != 8'h44 || !load_last_byte)
            $fatal(1, "LOAD last byte mismatch");
          default: $fatal(1, "unexpected extra LOAD byte");
        endcase
        load_data_seen <= load_data_seen + 1;
      end

      if (debug_response_in_flight && !debug_read_select)
        $fatal(1, "Debug observation released before physical response completion");
      if (response_start && response_with_debug) debug_response_in_flight <= 1'b1;
      if (response_done_tick && debug_response_in_flight) debug_response_in_flight <= 1'b0;
    end
  end

  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  task automatic check(input logic condition, input string message);
    if (!condition) $fatal(1, "%s", message);
  endtask

  task automatic add_short(input logic [7:0] opcode, input logic [7:0] result);
    expected_bytes[expected_count]   = opcode;
    expected_bytes[expected_count+1] = result;
    expected_count                   = expected_count + 2;
  endtask

  task automatic add_debug(input logic [7:0] opcode, input logic [7:0] result);
    expected_bytes[expected_count]   = opcode;
    expected_bytes[expected_count+1] = result;
    // With every mocked Debug source zero and no DMEM marks, the fixed
    // snapshot contributes 223 zero bytes and its five-byte count is zero.
    for (integer index = 0; index < 228; index++) expected_bytes[expected_count+2+index] = 8'h00;
    expected_count = expected_count + 230;
  endtask

  task automatic send_rx(input logic [7:0] value);
    begin
      @(negedge clk);
      while (rx_count == RX_CAPACITY) @(negedge clk);
      rx_push      = 1'b1;
      rx_push_data = value;
      rx_activity  = 1'b1;
      @(negedge clk);
      rx_push     = 1'b0;
      rx_activity = 1'b0;
    end
  endtask

  task automatic wait_response_idle;
    integer cycles;
    integer quiet_cycles;
    begin
      cycles = 0;
      while (!response_start && !response_busy && cycles < 20000) begin
        tick();
        cycles = cycles + 1;
      end
      check(response_start || response_busy, "response begins");
      if (response_start && !response_busy) begin
        tick();
        cycles = cycles + 1;
      end
      quiet_cycles = 0;
      while (quiet_cycles < 5 && cycles < 20000) begin
        tick();
        cycles = cycles + 1;
        if (response_busy || response_start || tx_count != 0) quiet_cycles = 0;
        else quiet_cycles = quiet_cycles + 1;
      end
      check(!response_busy && tx_count == 0, "response reaches physical idle");
    end
  endtask

  task automatic wait_rx_idle;
    integer cycles;
    begin
      cycles = 0;
      while (rx_count != 0 && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      check(rx_count == 0, "RX FIFO drains");
    end
  endtask

  task automatic pulse_rx_error;
    begin
      @(negedge clk);
      rx_error_tick = 1'b1;
      tick();
      rx_error_tick = 1'b0;
    end
  endtask

  task automatic check_scoreboard_complete;
    begin
      check(transmitted_count == expected_count, $sformatf(
            "scoreboard complete: transmitted=%0d expected=%0d", transmitted_count, expected_count
            ));
    end
  endtask

  initial begin
    reset                    = 1'b1;
    rx_error_tick            = 1'b0;
    rx_activity              = 1'b0;
    rx_push                  = 1'b0;
    rx_push_data             = 8'h00;
    rx_count                 = 0;
    tx_count                 = 0;
    tx_wait                  = 2;
    force_tx_full            = 1'b0;
    pause_tx                 = 1'b0;
    expected_count           = 0;
    transmitted_count        = 0;
    debug_response_in_flight = 1'b0;
    load_available           = 1'b1;
    prepare_active           = 1'b0;
    program_finished         = 1'b0;
    fault_terminal           = 1'b0;
    image_valid              = 1'b1;
    command_accepted         = 1'b0;
    cpu_cycle_fire           = 1'b0;
    repeat (2) tick();
    reset = 1'b0;

    // CHECK_READY -> READY and BUSY; RX bytes arriving under a full TX queue
    // are still consumed and cannot become commands during WAIT_RESPONSE_SENT.
    add_short(CMD_CHECK_READY, RESULT_READY);
    load_available = 1'b1;
    send_rx(CMD_CHECK_READY);
    force_tx_full = 1'b1;
    repeat (4) tick();
    send_rx(CMD_RUN);
    send_rx(CMD_STEP);
    wait_rx_idle();
    force_tx_full = 1'b0;
    wait_response_idle();
    add_short(CMD_CHECK_READY, RESULT_BUSY);
    load_available = 1'b0;
    send_rx(CMD_CHECK_READY);
    wait_response_idle();

    // LOAD ACCEPTED, four payload bytes, then LOAD DONE after preparation.
    add_short(CMD_LOAD, RESULT_ACCEPTED);
    add_short(CMD_LOAD, RESULT_DONE);
    command_accepted = 1'b1;
    send_rx(CMD_LOAD);
    send_rx(8'h04);
    send_rx(8'h00);
    send_rx(8'h00);
    send_rx(8'h00);
    send_rx(8'h00);
    wait_response_idle();
    check(load_size_bytes == 11'd4, "LOAD reconstructs the little-endian size");
    prepare_active = 1'b1;
    send_rx(8'h11);
    send_rx(8'h22);
    send_rx(8'h33);
    send_rx(8'h44);
    wait_rx_idle();
    check(load_data_seen == 4, "Loader receives exactly four ordered payload bytes");
    repeat (2) tick();
    prepare_active = 1'b0;
    wait_response_idle();
    command_accepted = 1'b0;

    // Rejected RUN -> NO_IMAGE.
    add_short(CMD_RUN, RESULT_NO_IMAGE);
    image_valid      = 1'b0;
    command_accepted = 1'b0;
    send_rx(CMD_RUN);
    wait_response_idle();

    // Accepted RUN whose terminal arrives before ACCEPTED's final Stop.
    // Physical TX is paused to force the real controller/serializer overlap.
    add_short(CMD_RUN, RESULT_ACCEPTED);
    add_debug(CMD_RUN, RESULT_FINISHED);
    image_valid      = 1'b1;
    command_accepted = 1'b1;
    pause_tx         = 1'b1;
    send_rx(CMD_RUN);
    wait_rx_idle();
    begin : wait_run_accept
      integer cycles;
      cycles = 0;
      while (!response_busy && !response_start && cycles < 100) begin
        tick();
        cycles = cycles + 1;
      end
      check(response_busy || response_start, $sformatf(
            "accepted RUN response starts, controller state=%b rx_count=%0d",
            controller.protocol_state,
            rx_count
            ));
    end
    if (response_start && !response_busy) tick();
    program_finished = 1'b1;
    repeat (3) tick();
    check(!response_start && debug_read_select,
          "RUN terminal is retained while ACCEPTED awaits physical TX");
    pause_tx = 1'b0;
    wait_response_idle();
    program_finished = 1'b0;
    command_accepted = 1'b0;

    // RUN terminal FAULT and a separate STEP with immediate cycle fire.
    add_short(CMD_RUN, RESULT_ACCEPTED);
    add_debug(CMD_RUN, RESULT_FAULT);
    command_accepted = 1'b1;
    send_rx(CMD_RUN);
    wait_rx_idle();
    wait_response_idle();
    fault_terminal = 1'b1;
    wait (response_busy || response_start);
    wait_response_idle();
    fault_terminal   = 1'b0;
    command_accepted = 1'b0;

    add_debug(CMD_STEP, RESULT_DONE);
    command_accepted = 1'b1;
    cpu_cycle_fire   = 1'b1;
    send_rx(CMD_STEP);
    wait_rx_idle();
    cpu_cycle_fire = 1'b0;
    wait_response_idle();
    command_accepted = 1'b0;

    // STEP accepted after preparation: no separate ACCEPTED response.
    add_debug(CMD_STEP, RESULT_DONE);
    command_accepted = 1'b1;
    cpu_cycle_fire   = 1'b0;
    prepare_active   = 1'b1;
    send_rx(CMD_STEP);
    wait_rx_idle();
    repeat (2) tick();
    prepare_active = 1'b0;
    cpu_cycle_fire = 1'b1;
    tick();
    cpu_cycle_fire = 1'b0;
    wait_response_idle();
    command_accepted = 1'b0;

    // Unknown opcode is echoed; UART error enters RECOVER_RX and subsequent
    // bytes are consumed/discarded. The fixed 100 ms timer boundary is checked
    // by seeding its documented terminal count rather than simulating 5M clocks.
    add_short(8'hA7, RESULT_UNKNOWN_COMMAND);
    send_rx(8'hA7);
    wait_rx_idle();
    wait_response_idle();
    pulse_rx_error();
    check(controller.protocol_state == 11'b10000000000, "UART error enters RECOVER_RX");
    send_rx(CMD_CHECK_READY);
    send_rx(CMD_LOAD);
    wait_rx_idle();
    check(controller.protocol_state == 11'b10000000000,
          "recovery consumes RX without recognizing commands");
    controller.inactivity_count = 23'd4_999_999;
    tick();
    check(controller.protocol_state == 11'b00000000001,
          "RECOVER_RX exits after a full silent interval");

    // RESET response remains the only activity until ACCEPTED physically ends.
    add_short(CMD_RESET, RESULT_ACCEPTED);
    pause_tx = 1'b1;
    send_rx(CMD_RESET);
    wait_rx_idle();
    wait (response_busy);
    repeat (3) tick();
    check(!uart_reset_request, "RESET request waits for final physical Stop");
    pause_tx = 1'b0;
    wait_response_idle();
    tick();
    check(uart_reset_request, "RESET request follows completed ACCEPTED");

    check_scoreboard_complete();
    if (!$value$plusargs("CASE=%s", selected_case)) $fatal(1, "missing +CASE=<case-id>");
    if (selected_case != "TEST-UART-009/C008" && selected_case != "TEST-UART-009/C009")
      $fatal(1, "unsupported integration case %s", selected_case);
    $display("PASS %s", selected_case);
    $finish;
  end
endmodule
