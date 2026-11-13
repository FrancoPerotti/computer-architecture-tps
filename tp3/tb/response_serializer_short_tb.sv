module response_serializer_short_tb;
  logic clk = 0;
  always #5 clk = ~clk;
  logic         reset;
  logic         tx_done_tick;
  logic   [7:0] w_data;
  logic         wr_uart;
  logic         response_start;
  logic   [7:0] response_opcode;
  logic   [7:0] response_result;
  logic         response_with_debug;
  logic         response_busy;
  logic         response_done_tick;
  logic         tx_full;
  logic         force_full;
  logic   [7:0] fifo                [ 4];
  logic   [7:0] accepted_bytes      [16];
  integer       fifo_count;
  integer       accepted_count;
  integer       transmitted_count;
  logic   [7:0] transmitted_bytes   [16];

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
      .response_done_tick
  );

  assign tx_full = force_full || (fifo_count == 4);

  // Modelo síncrono FIFO/TX; el testbench decide cuándo acaba cada Stop.
  always @(posedge clk) begin : model_fifo_transmitter
    logic       do_pop;
    logic       do_push;
    logic [7:0] popped_byte;
    do_pop      = !reset && tx_done_tick && fifo_count > 0;
    do_push     = !reset && wr_uart && !tx_full;
    popped_byte = fifo[0];
    if (reset) begin
      fifo_count        = 0;
      accepted_count    = 0;
      transmitted_count = 0;
    end else begin
      if (do_pop) begin
        transmitted_bytes[transmitted_count] = popped_byte;
        transmitted_count                    = transmitted_count + 1;
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
  end

  task automatic tick;
    @(posedge clk);
    #1;
  endtask
  task automatic check(input logic condition, input string message);
    if (!condition) $fatal(1, "%s", message);
  endtask
  task automatic drain_one;
    tx_done_tick = 1;
    tick();
    tx_done_tick = 0;
    #1;
  endtask
  task automatic start_short(input logic [7:0] opcode, input logic [7:0] result);
    response_opcode     = opcode;
    response_result     = result;
    response_with_debug = 0;
    response_start      = 1;
    tick();
    response_start = 0;
  endtask

  initial begin
    reset               = 1;
    tx_done_tick        = 0;
    response_start      = 0;
    response_opcode     = 0;
    response_result     = 0;
    response_with_debug = 0;
    force_full          = 0;
    fifo_count          = 0;
    accepted_count      = 0;
    transmitted_count   = 0;
    tick();
    reset = 0;

    // Ocupa la FIFO para demostrar que PREPARE conserva el byte sin escribirlo.
    force_full = 1;
    start_short(8'hA2, 8'h5C);
    check(response_busy, "busy begins on descriptor capture");
    tick();
    check(dut.next_byte_available && dut.next_byte == 8'hA2 && !wr_uart, $sformatf(
          "opcode retained while FIFO is full (avail=%b byte=%02x wr=%b state=%b desc=%h full=%b)",
          dut.next_byte_available,
          dut.next_byte,
          wr_uart,
          dut.state,
          dut.descriptor,
          tx_full
          ));
    force_full = 0;
    #1;
    check(wr_uart && w_data == 8'hA2, "opcode enqueued when FIFO space appears");
    tick();
    check(dut.fixed_byte_index == 1 && dut.tx_pending == 1, "opcode acceptance advances one byte");
    tick();
    check(dut.next_byte_available && dut.next_byte == 8'h5C, "result prepared after opcode");

    // El Stop del opcode coincide con el enqueue del segundo byte.
    tx_done_tick = 1;
    #1;
    check(wr_uart && w_data == 8'h5C, "result enqueue coincides with first Stop");
    tick();
    tx_done_tick = 0;
    #1;
    check(dut.production_complete && dut.tx_pending == 1 && !response_done_tick, $sformatf(
          "production ends before physical response (prod=%b pending=%0d done=%b state=%b)",
          dut.production_complete,
          dut.tx_pending,
          response_done_tick,
          dut.state
          ));
    check(accepted_bytes[0] == 8'hA2 && accepted_bytes[1] == 8'h5C,
          "short response enqueue order is exact");
    check(response_busy, "busy remains through final Stop");
    tx_done_tick = 1;
    #1;
    check(response_done_tick && response_busy,
          "completion coincides with final physical Stop while busy");
    tick();
    tx_done_tick = 0;
    #1;
    check(transmitted_bytes[0] == 8'hA2 && transmitted_bytes[1] == 8'h5C,
          "short response physical transmission order is exact");
    check(dut.state == 10'b0000000001 && !response_busy && !response_done_tick,
          "completion is one cycle and serializer returns idle");

    // Una segunda respuesta inicia sin pendiente de la primera.
    start_short(8'h03, 8'h02);
    tick();
    check(wr_uart && w_data == 8'h03, "second response opcode");
    tick();
    tick();
    check(wr_uart && w_data == 8'h02, "second response result");
    tick();
    check(dut.tx_pending == 2 && dut.production_complete,
          "second response tracks two pending bytes");
    drain_one();
    check(!response_done_tick && response_busy, "second response waits after first Stop");
    tx_done_tick = 1;
    #1;
    check(response_done_tick && response_busy, "second response ends at its last Stop");
    tick();
    tx_done_tick = 0;
    #1;
    check(!response_busy && !response_done_tick, "second response returns idle");

    // Reset aborta una respuesta completa que todavía espera los Stops físicos.
    start_short(8'h04, 8'h01);
    tick();
    tick();
    tick();
    tick();
    check(
        dut.state == 10'b1000000000 && dut.production_complete && dut.tx_pending == 2 &&
            fifo_count == 2,
        "reset case waits for physical transmission after production completes");
    reset = 1;
    #1;
    check(!response_busy && !response_done_tick && !wr_uart,
          "reset suppresses completion while the last bytes are pending");
    tick();
    check(!response_busy && !response_done_tick && dut.state == 10'b0000000001,
          "reset aborts the response without normal completion");
    reset = 0;

    $display("PASS response_serializer short responses");
    $finish;
  end
endmodule
