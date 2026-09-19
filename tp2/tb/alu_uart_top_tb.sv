`timescale 1ns / 1ps

module alu_uart_top_tb;
  localparam integer CLK_FREQ_HZ = 100_000;
  localparam integer BAUD_RATE = 2_500;
  localparam integer OVERSAMPLE = 4;
  localparam integer DIVISOR = 10;
  localparam integer BIT_CYCLES = DIVISOR * OVERSAMPLE;
  localparam integer TIMEOUT_MS = 10;
  localparam integer TIMEOUT_CYCLES = (CLK_FREQ_HZ / 1000) * TIMEOUT_MS;

  localparam logic [5:0] OP_ADD = 6'b100000;
  localparam logic [5:0] OP_SUB = 6'b100010;
  localparam logic [5:0] OP_AND = 6'b100100;
  localparam logic [5:0] OP_OR  = 6'b100101;
  localparam logic [5:0] OP_XOR = 6'b100110;
  localparam logic [5:0] OP_SRA = 6'b000011;
  localparam logic [5:0] OP_SRL = 6'b000010;
  localparam logic [5:0] OP_NOR = 6'b100111;

  reg clk = 1'b0;
  reg btn_reset = 1'b0;
  reg serial_rx = 1'b1;
  wire serial_tx;
  wire [10:0] leds;

  reg [5:0] operations[0:7];
  integer errors = 0;
  integer tests = 0;
  integer enqueued_results = 0;
  integer seed;
  integer operation_index;
  integer sample_index;

  always #5 clk = ~clk;

  alu_uart_top #(
      .CLK_FREQ_HZ           (CLK_FREQ_HZ),
      .BAUD_RATE             (BAUD_RATE),
      .OVERSAMPLE            (OVERSAMPLE),
      .FIFO_ADDR_WIDTH       (2),
      .TRANSACTION_TIMEOUT_MS(TIMEOUT_MS)
  ) dut (
      .clk      (clk),
      .btn_reset(btn_reset),
      .serial_rx(serial_rx),
      .serial_tx(serial_tx),
      .leds     (leds)
  );

  always @(posedge clk) begin
    if (dut.write_uart) enqueued_results = enqueued_results + 1;
  end

  function automatic [7:0] reference_result;
    input [7:0] test_a;
    input [7:0] test_b;
    input [5:0] test_opcode;
    begin
      case (test_opcode)
        OP_ADD: reference_result = test_a + test_b;
        OP_SUB: reference_result = test_a - test_b;
        OP_AND: reference_result = test_a & test_b;
        OP_OR:  reference_result = test_a | test_b;
        OP_XOR: reference_result = test_a ^ test_b;
        OP_SRA: reference_result = $signed(test_a) >>> test_b;
        OP_SRL: reference_result = test_a >> test_b;
        OP_NOR: reference_result = ~(test_a | test_b);
        default: reference_result = 8'b0;
      endcase
    end
  endfunction

  task automatic reference_flags;
    input [7:0] test_a;
    input [7:0] test_b;
    input [5:0] test_opcode;
    input [7:0] test_result;
    output [2:0] flags;
    reg [8:0] extended_sum;
    begin
      flags = 3'b000;
      flags[0] = (test_result == 8'b0);
      if (test_opcode == OP_ADD) begin
        extended_sum = {1'b0, test_a} + {1'b0, test_b};
        flags[1] = extended_sum[8];
        flags[2] = (test_a[7] == test_b[7]) && (test_result[7] != test_a[7]);
      end else if (test_opcode == OP_SUB) begin
        flags[2] = (test_a[7] != test_b[7]) && (test_result[7] != test_a[7]);
      end
    end
  endtask

  task automatic drive_serial_bit;
    input value;
    begin
      @(negedge clk);
      serial_rx = value;
      repeat (BIT_CYCLES) @(posedge clk);
    end
  endtask

  task automatic send_serial_byte;
    input [7:0] value;
    input valid_stop;
    integer bit_index;
    begin
      drive_serial_bit(1'b0);
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        drive_serial_bit(value[bit_index]);
      end
      drive_serial_bit(valid_stop);
      if (!valid_stop) begin
        @(negedge clk);
        serial_rx = 1'b1;
        repeat (BIT_CYCLES) @(posedge clk);
      end
    end
  endtask

  task automatic receive_serial_byte;
    output [7:0] value;
    integer bit_index;
    begin
      @(negedge serial_tx);
      repeat (BIT_CYCLES + (BIT_CYCLES / 2)) @(posedge clk);
      #1;
      value[0] = serial_tx;
      for (bit_index = 1; bit_index < 8; bit_index = bit_index + 1) begin
        repeat (BIT_CYCLES) @(posedge clk);
        #1;
        value[bit_index] = serial_tx;
      end
      repeat (BIT_CYCLES) @(posedge clk);
      #1;
      if (serial_tx !== 1'b1) begin
        errors = errors + 1;
        $display("ERROR: response stop bit is not high");
      end
    end
  endtask

  task automatic transact;
    input [7:0] test_a;
    input [7:0] test_b;
    input [7:0] opcode_byte;
    reg [7:0] received;
    reg [7:0] expected;
    reg [2:0] expected_flags;
    begin
      expected = reference_result(test_a, test_b, opcode_byte[5:0]);
      reference_flags(test_a, test_b, opcode_byte[5:0], expected, expected_flags);

      fork
        begin
          receive_serial_byte(received);
        end
        begin
          send_serial_byte(test_a, 1'b1);
          send_serial_byte(test_b, 1'b1);
          send_serial_byte(opcode_byte, 1'b1);
        end
      join

      tests = tests + 1;
      if (received !== expected || leds !== {expected_flags, expected}) begin
        errors = errors + 1;
        $display("ERROR: A=%h B=%h op=%h response=%h/%h LEDs=%h/%h", test_a, test_b,
                 opcode_byte, received, expected, leds, {expected_flags, expected});
      end
    end
  endtask

  initial begin
    operations[0] = OP_ADD;
    operations[1] = OP_SUB;
    operations[2] = OP_AND;
    operations[3] = OP_OR;
    operations[4] = OP_XOR;
    operations[5] = OP_SRA;
    operations[6] = OP_SRL;
    operations[7] = OP_NOR;
    seed = 32'h1a2b3c4d;
    seed = $urandom(seed);

    // El acondicionador mantiene reset activo durante el arranque.
    repeat (8) @(posedge clk);
    if (serial_tx !== 1'b1 || leds !== 11'b001_00000000) begin
      errors = errors + 1;
      $display("ERROR: top startup state TX=%b LEDs=%h", serial_tx, leds);
    end

    transact(8'h05, 8'h03, OP_ADD);
    transact(8'hff, 8'h01, OP_ADD);
    transact(8'h7f, 8'h01, OP_ADD);
    transact(8'h80, 8'h01, OP_SUB);
    transact(8'h80, 8'h01, OP_SRA);
    transact(8'h80, 8'h01, OP_SRL);
    transact(8'hf0, 8'h0f, OP_NOR);
    transact(8'h12, 8'h34, 8'h3f);
    transact(8'h01, 8'h02, 8'he0);

    // Un paquete parcial debe caducar sin producir una respuesta.
    send_serial_byte(8'haa, 1'b1);
    repeat (TIMEOUT_CYCLES + 20) @(posedge clk);
    if (enqueued_results != tests) begin
      errors = errors + 1;
      $display("ERROR: partial transaction produced a response");
    end
    transact(8'h09, 8'h02, OP_SUB);

    // Un stop invalido se descarta y permite una operacion posterior.
    send_serial_byte(8'h55, 1'b0);
    repeat (20) @(posedge clk);
    if (enqueued_results != tests) begin
      errors = errors + 1;
      $display("ERROR: malformed frame produced a response");
    end
    transact(8'h0c, 8'h0a, OP_AND);

    // Reset durante una trama cancela cualquier estado parcial.
    fork
      begin
        send_serial_byte(8'hde, 1'b1);
      end
      begin
        repeat (BIT_CYCLES * 3) @(posedge clk);
        @(negedge clk);
        btn_reset = 1'b1;
        repeat (3) @(posedge clk);
        @(negedge clk);
        btn_reset = 1'b0;
      end
    join
    // Se espera linea inactiva y vencimiento de cualquier paquete espurio que
    // haya comenzado con los bits restantes de la trama interrumpida.
    repeat (TIMEOUT_CYCLES + BIT_CYCLES) @(posedge clk);
    transact(8'haa, 8'h55, OP_XOR);

    // Regresion serial pseudoaleatoria de todas las operaciones.
    for (operation_index = 0; operation_index < 8; operation_index = operation_index + 1) begin
      for (sample_index = 0; sample_index < 100; sample_index = sample_index + 1) begin
        transact($urandom(), $urandom(), operations[operation_index]);
      end
    end

    if (tests != 812) $fatal(1, "FAIL: expected 812 top transactions, obtained %0d", tests);
    if (errors != 0) $fatal(1, "FAIL: %0d top errors in %0d transactions", errors, tests);
    $display("PASS: %0d complete serial ALU transactions", tests);
    $finish;
  end

  initial begin
    #30000000;
    $display("DEBUG: tests=%0d enqueued=%0d rx_state=%b tx_state=%b ctrl_state=%b rx_empty=%b tx_full=%b serial_rx=%b serial_tx=%b",
             tests, enqueued_results, dut.uart.receiver.state, dut.uart.transmitter.state,
             dut.controller.state, dut.rx_empty, dut.tx_full, serial_rx, serial_tx);
    $fatal(1, "FAIL: top integration testbench timeout");
  end
endmodule
