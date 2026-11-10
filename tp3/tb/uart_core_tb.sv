`timescale 1ns / 1ps

// Verifica la integración física UART con sincronizador, tick, FIFO y RX/TX reales.
module uart_core_tb;
  localparam integer DATA_WIDTH = system_pkg::UART_DATA_BITS;
  localparam integer FIFO_DEPTH = system_pkg::UART_FIFO_DEPTH;
  localparam
      integer DIVISOR = (system_pkg::FUNCTIONAL_CLOCK_HZ +
                         (system_pkg::UART_BAUD_RATE * system_pkg::UART_OVERSAMPLE_FACTOR) / 2) /
      (system_pkg::UART_BAUD_RATE * system_pkg::UART_OVERSAMPLE_FACTOR);
  localparam integer BIT_CYCLES = DIVISOR * system_pkg::UART_OVERSAMPLE_FACTOR;

  tp3_case_data data ();
  logic                  clk = 1'b0;
  logic                  reset = 1'b1;
  logic                  serial_rx = 1'b1;
  logic                  serial_tx;
  logic [DATA_WIDTH-1:0] r_data;
  logic                  rd_uart = 1'b0;
  logic                  rx_empty;
  logic [DATA_WIDTH-1:0] w_data = '0;
  logic                  wr_uart = 1'b0;
  logic                  tx_full;
  logic                  rx_error_tick;
  logic                  rx_activity;
  logic                  rx_receiving;
  logic                  tx_done_tick;

  integer tick_edges = 0;
  integer rx_errors = 0;
  integer tx_completions = 0;
  integer cycle_count = 0;
  integer previous_tick_edge = 0;

  uart_core dut (.*);
  always #10 clk = ~clk;

  always @(posedge clk) begin
    if (reset) begin
      tick_edges         = 0;
      cycle_count        = 0;
      previous_tick_edge = 0;
    end else begin
      cycle_count++;
      if (dut.s_tick !== dut.receiver.s_tick || dut.s_tick !== dut.transmitter.s_tick)
        fail("RX y TX no comparten el mismo s_tick");
      if (dut.s_tick) begin
        if (tick_edges == 0 && cycle_count != DIVISOR + 1)
          fail("primer tick consumido fuera del flanco esperado");
        tick_edges++;
        if (previous_tick_edge != 0 && cycle_count - previous_tick_edge != DIVISOR)
          fail("periodo incorrecto del tick compartido");
        previous_tick_edge = cycle_count;
      end
      if (rx_error_tick) rx_errors++;
      if (tx_done_tick) tx_completions++;
    end
  end

  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic clocks(input integer count);
    repeat (count) begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic wait_rx_count(input integer expected);
    integer guard;
    guard = 0;
    while (dut.rx_fifo.count != expected && guard < (2 * BIT_CYCLES + 16)) begin
      clocks(1);
      guard++;
    end
    if (dut.rx_fifo.count != expected) fail("ocupacion RX no alcanzada");
  endtask

  task automatic wait_tx_count(input integer expected);
    integer guard;
    guard = 0;
    while (dut.tx_fifo.count != expected && guard < 8) begin
      clocks(1);
      guard++;
    end
    if (dut.tx_fifo.count != expected) fail("ocupacion TX no alcanzada");
  endtask

  task automatic send_rx_frame(input logic [DATA_WIDTH-1:0] value, input logic stop_level);
    @(negedge clk);
    serial_rx = 1'b0;
    repeat (2 * DIVISOR) @(posedge clk);
    #1;
    if (!rx_activity || !rx_receiving) fail("RX no indico actividad/inicio de trama");
    repeat (BIT_CYCLES - 2 * DIVISOR) @(posedge clk);
    @(negedge clk);
    for (integer bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
      serial_rx = value[bit_index];
      repeat (BIT_CYCLES) @(posedge clk);
      @(negedge clk);
    end
    serial_rx = stop_level;
    repeat (BIT_CYCLES) @(posedge clk);
    @(negedge clk);
    serial_rx = 1'b1;
  endtask

  task automatic enqueue_tx(input logic [DATA_WIDTH-1:0] value);
    @(negedge clk);
    w_data  = value;
    wr_uart = 1'b1;
    @(posedge clk);
    #1;
    @(negedge clk);
    wr_uart = 1'b0;
  endtask

  task automatic decode_tx(input logic [DATA_WIDTH-1:0] value,
                           input integer expected_count_before_done);
    integer guard;
    integer done_before;
    done_before = tx_completions;
    guard       = 0;
    while (!dut.tx_busy && guard < 10) begin
      clocks(1);
      guard++;
    end
    if (!dut.tx_busy || serial_tx !== 1'b0) fail("TX no comenzó con Start bajo");
    if (dut.tx_fifo.count != expected_count_before_done)
      fail("FIFO TX retiro el byte antes del fin fisico");

    clocks(BIT_CYCLES / 2);
    if (serial_tx !== 1'b0) fail("Start TX no permanecio bajo");
    for (integer bit_index = 0; bit_index < DATA_WIDTH; bit_index++) begin
      clocks(BIT_CYCLES);
      if (serial_tx !== value[bit_index]) fail("dato TX incorrecto o fuera de orden");
      if (dut.tx_fifo.count != expected_count_before_done)
        fail("FIFO TX retiro el byte antes de completar Stop");
    end
    clocks(BIT_CYCLES);
    if (serial_tx !== 1'b1) fail("Stop TX no estuvo alto");
    if (dut.tx_fifo.count != expected_count_before_done)
      fail("FIFO TX retiro el byte antes del final del Stop");

    guard = 0;
    while (tx_completions == done_before && guard < BIT_CYCLES) begin
      clocks(1);
      guard++;
    end
    if (tx_completions != done_before + 1) fail("tx_done_tick no ocurrio exactamente una vez");
    if (dut.tx_fifo.count != expected_count_before_done - 1)
      fail("FIFO TX no retiro el byte en el flanco de tx_done_tick");
  endtask

  task automatic read_rx_expect(input logic [DATA_WIDTH-1:0] value);
    @(negedge clk);
    if (rx_empty || r_data !== value) fail("dato u orden incorrecto en FIFO RX");
    rd_uart = 1'b1;
    @(posedge clk);
    #1;
    @(negedge clk);
    rd_uart = 1'b0;
  endtask

  integer errors_before;
  integer completions_before;
  initial begin
    data.load();
    clocks(2);
    if (serial_tx !== 1'b1 || !rx_empty || tx_full || rx_activity || rx_receiving ||
        rx_error_tick || tx_done_tick || dut.rx_fifo.count != 0 || dut.tx_fifo.count != 0)
      fail("reset no inicializo UART y ambas FIFO");
    @(negedge clk);
    reset = 1'b0;

    // Comprueba que la base de tiempo compartida mantiene su periodo nominal.
    clocks(3 * DIVISOR + 5);
    if (tick_edges < 3) fail("el generador compartido no funciona continuamente");

    // RX almacena bytes completos en orden y los presenta para lectura.
    send_rx_frame(8'hA6, 1'b1);
    wait_rx_count(1);
    send_rx_frame(8'h39, 1'b1);
    wait_rx_count(2);
    read_rx_expect(8'hA6);
    read_rx_expect(8'h39);
    clocks(2);
    if (!rx_empty) fail("FIFO RX no quedo vacia tras las lecturas");

    // Start falso: línea baja y vuelta al reposo antes del punto medio.
    errors_before = rx_errors;
    @(negedge clk);
    serial_rx = 1'b0;
    repeat (BIT_CYCLES / 4) @(posedge clk);
    @(negedge clk);
    serial_rx = 1'b1;
    clocks(BIT_CYCLES);
    if (rx_errors != errors_before + 1) fail("no se reporto start falso");

    // Stop bajo produce error de trama sin escribir la FIFO RX.
    errors_before = rx_errors;
    send_rx_frame(8'h5A, 1'b0);
    wait_rx_count(0);
    clocks(BIT_CYCLES / 4);
    if (rx_errors != errors_before + 1) fail("no se reporto Stop invalido");

    // Cinco bytes sin retirar llenan la FIFO de cuatro posiciones y reportan overflow.
    for (integer frame_index = 0; frame_index < FIFO_DEPTH + 1; frame_index++) begin
      send_rx_frame(8'h40 + frame_index, 1'b1);
      wait_rx_count((frame_index < FIFO_DEPTH) ? frame_index + 1 : FIFO_DEPTH);
    end
    if (!dut.rx_full || dut.rx_fifo.count != FIFO_DEPTH || rx_errors != errors_before + 2)
      fail("overflow RX no fue reportado o altero la capacidad");
    for (integer frame_index = 0; frame_index < FIFO_DEPTH; frame_index++)
    read_rx_expect(8'h40 + frame_index);

    // TX mantiene el byte en FIFO durante toda la trama y lo retira al fin de Stop.
    enqueue_tx(8'hD3);
    enqueue_tx(8'h81);
    if (dut.tx_fifo.count != 2) fail("escrituras TX no llegaron a la FIFO");
    decode_tx(8'hD3, 2);
    decode_tx(8'h81, 1);
    wait_tx_count(0);
    if (tx_full || tx_done_tick) fail("estado TX incorrecto al quedar inactivo");

    // RX y TX progresan simultáneamente con el mismo clock/tick.
    enqueue_tx(8'hC7);
    completions_before = tx_completions;
    fork
      send_rx_frame(8'h2D, 1'b1);
      decode_tx(8'hC7, 1);
    join
    wait_rx_count(1);
    read_rx_expect(8'h2D);
    if (tx_completions != completions_before + 1)
      fail("full-duplex no completo TX mientras recibia RX");

    // Reset aborta una trama activa, limpia ambas colas y suprime los indicadores.
    @(negedge clk);
    serial_rx = 1'b0;
    clocks(2 * DIVISOR);
    if (!rx_receiving) fail("RX no estaba activa antes del reset concurrente");
    enqueue_tx(8'hF0);
    while (!dut.tx_busy) clocks(1);
    @(negedge clk);
    reset = 1'b1;
    #1;
    if (rx_activity || rx_receiving || tx_done_tick) fail("reset no suprimio indicadores/eventos");
    clocks(1);
    if (serial_tx !== 1'b1 || !rx_empty || tx_full || dut.tx_fifo.count != 0 ||
        dut.rx_fifo.count != 0 || dut.tx_busy || tx_done_tick)
      fail("reset durante TX no recupero UART y FIFO");
    @(negedge clk);
    reset = 1'b0;
    send_rx_frame(8'h96, 1'b1);
    wait_rx_count(1);
    read_rx_expect(8'h96);

    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
