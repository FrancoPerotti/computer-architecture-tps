`timescale 1ns / 1ps

// Verifica el RESET por los pines de placa con la UART nominal y el IP generado.
module basys3_reference_tb;
  bit board_clock;
  bit reset_button = 1;
  wire serial_rx, serial_tx;

  basys3_top dut (
      .clk_100mhz_i(board_clock),
      .reset_btn_i (reset_button),
      .uart_rx_i   (serial_rx),
      .uart_tx_o   (serial_tx)
  );

  system_uart_host #(
      .BAUD_RATE     (64'd19_200),
      .MAX_USED_BYTES(4)
  ) host (
      .serial_rx,
      .serial_tx
  );

  wire       clk = dut.gen_supported_profile.clk;
  wire       locked = dut.gen_supported_profile.locked;
  wire       reset = dut.gen_supported_profile.reset;
  wire       uart_reset_request = dut.gen_supported_profile.uart_reset_request;
  wire       response_done = dut.gen_supported_profile.system.response_done_tick;
  wire       tx_done = dut.gen_supported_profile.system.tx_done_tick;
  wire [7:0] state_code = dut.gen_supported_profile.system.global_state_code;
  bit        reset_command_sent;

  always #5ns board_clock = !board_clock;

  initial begin
    #1200ns;
    if (reset !== 1'b1 || locked !== 1'b0) $fatal(1, "button did not hold reset");
    reset_button = 0;
    wait (locked === 1'b1);
    wait (reset === 1'b0);

    // JAL x0,0 mantiene RUN activo durante la respuesta de aceptación.
    host.load_header(40'd4);
    host.send_byte(8'h6f);
    host.send_byte(8'h00);
    host.send_byte(8'h00);
    host.send_byte(8'h00, 1);
    host.expect_header(8'h01, 8'h02);
    host.send_byte(8'h02, 1);
    host.expect_header(8'h02, 8'h01);
    #60us;
    reset_command_sent = 1;
    host.send_byte(8'h04, 1);
    host.expect_header(8'h04, 8'h01);
    if (reset !== 1'b0 || state_code !== 8'h04) $fatal(1, "RESET interrupted ACCEPTED or RUN");
    @(posedge uart_reset_request);
    wait (reset === 1'b0);
    repeat (2) @(negedge clk);
    if (state_code !== 8'h00) $fatal(1, "RESET did not clear the session");

    host.send_byte(8'h05, 1);
    host.expect_header(8'h05, 8'h03);
    host.send_byte(8'h03, 1);
    host.expect_header(8'h03, 8'h05);
    $display("PASS TEST-UART-013/C001 Basys3 REFERENCE 19200 baud");
    $finish;
  end

  initial begin
    wait (reset_command_sent);
    // E consume el último Stop. E+1 consume reset y limpia la solicitud.
    // E+2 y E+3 liberan las dos etapas. E+4 es el primer flanco libre.
    @(posedge clk iff response_done);
    if (tx_done !== 1'b1 || reset !== 1'b0 || uart_reset_request !== 1'b0)
      $fatal(1, "RESET request preceded the final Stop");
    #1ps;
    if (uart_reset_request !== 1'b1 || reset !== 1'b1 || locked !== 1'b1)
      $fatal(1, "RESET did not assert immediately without disturbing locked");
    @(posedge clk);
    #1ps;
    if (uart_reset_request !== 1'b0 || reset !== 1'b1 || locked !== 1'b1)
      $fatal(1, "RESET request was not cleared by the common reset");
    @(posedge clk);
    #1ps;
    if (reset !== 1'b1 || locked !== 1'b1) $fatal(1, "RESET released on first stage");
    @(posedge clk);
    if (reset !== 1'b1) $fatal(1, "consumers saw RESET released before E+4");
    #1ps;
    if (reset !== 1'b0 || locked !== 1'b1) $fatal(1, "RESET did not release on second stage");
    @(posedge clk);
    if (reset !== 1'b0) $fatal(1, "consumers did not see RESET released on E+4");
  end

  initial begin
    #30ms;
    $fatal(1, "timeout in Basys3 reference simulation");
  end
endmodule
