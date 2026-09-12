`timescale 1ns / 1ps

// Lee A, B y opcode desde la UART y envía el resultado de la ALU.
module alu_uart_controller #(
    parameter integer CLK_FREQ_HZ            = 100_000_000,
    parameter integer TRANSACTION_TIMEOUT_MS = 10
) (
    input wire clk,
    input wire reset,

    input  wire [7:0] r_data,
    output reg        rd_uart,
    input  wire       rx_empty,
    input  wire       rx_error_tick,

    output wire [7:0] w_data,
    output reg        wr_uart,
    input  wire       tx_full,

    output wire [10:0] leds
);

  // Hay un estado para recibir cada byte, otro para guardar el resultado y otro
  // para esperar que el FIFO TX tenga espacio antes de enviar la respuesta.
  localparam logic   [4:0] STATE_WAIT_A       = 5'b00001;
  localparam logic   [4:0] STATE_WAIT_B       = 5'b00010;
  localparam logic   [4:0] STATE_WAIT_OPCODE  = 5'b00100;
  localparam logic   [4:0] STATE_EXECUTE      = 5'b01000;
  localparam logic   [4:0] STATE_WAIT_TX      = 5'b10000;

  // Cantidad de ciclos de reloj que se esperan antes de descartar una
  // operación.
  localparam integer       TIMEOUT_CYCLES_RAW = (CLK_FREQ_HZ / 1000) * TRANSACTION_TIMEOUT_MS;
  // Se asegura que el tiempo límite sea al menos un ciclo de reloj.
  localparam integer       TIMEOUT_CYCLES     = (TIMEOUT_CYCLES_RAW <= 0) ? 1 : TIMEOUT_CYCLES_RAW;
  // Cantidad de bits necesarios para contar hasta TIMEOUT_CYCLES.
  localparam integer       TIMEOUT_WIDTH      = (TIMEOUT_CYCLES <= 1) ? 1 : $clog2(TIMEOUT_CYCLES);

  // Estado actual, próximo estado y contador de la transacción parcial.
  (* fsm_encoding = "one_hot" *) reg [4:0] state = STATE_WAIT_A;
  reg [4:0] next_state;
  reg [TIMEOUT_WIDTH-1:0] timeout_count = {TIMEOUT_WIDTH{1'b0}};
  reg [TIMEOUT_WIDTH-1:0] next_timeout_count;

  // Registros de operandos y señales que indican cuándo cargar cada dato.
  reg [7:0] data_a = 8'b0;
  reg [7:0] data_b = 8'b0;
  reg [5:0] opcode = 6'b0;
  reg load_a;
  reg load_b;
  reg load_opcode;
  reg capture_result;

  // La misma ALU combinacional utilizada en el TP1.
  wire [7:0] alu_result;
  wire alu_zero;
  wire alu_carry;
  wire alu_overflow;

  // El resultado y las banderas se guardan para que no cambien mientras se espera
  // que el FIFO TX tenga espacio.
  reg [7:0] result_reg = 8'b0;
  reg zero_reg = 1'b1;
  reg carry_reg = 1'b0;
  reg overflow_reg = 1'b0;

  alu #(
      .NB_DATA  (8),
      .NB_OPCODE(6)
  ) alu_core (
      .o_result     (alu_result),
      .o_zero       (alu_zero),
      .o_carry      (alu_carry),
      .o_overflow   (alu_overflow),
      .i_data_a     (data_a),
      .i_data_b     (data_b),
      .i_data_opcode(opcode)
  );

  // En cada flanco se actualizan el estado, el contador y los datos. Cada
  // registro cambia solamente cuando su señal de carga está activa.
  always @(posedge clk) begin
    if (reset) begin
      state         <= STATE_WAIT_A;
      timeout_count <= {TIMEOUT_WIDTH{1'b0}};
      data_a        <= 8'b0;
      data_b        <= 8'b0;
      opcode        <= 6'b0;
      result_reg    <= 8'b0;
      zero_reg      <= 1'b1;
      carry_reg     <= 1'b0;
      overflow_reg  <= 1'b0;
    end else begin
      state         <= next_state;
      timeout_count <= next_timeout_count;

      if (load_a) begin
        data_a <= r_data;
      end
      if (load_b) begin
        data_b <= r_data;
      end
      if (load_opcode) begin
        opcode <= r_data[5:0];
      end
      if (capture_result) begin
        result_reg   <= alu_result;
        zero_reg     <= alu_zero;
        carry_reg    <= alu_carry;
        overflow_reg <= alu_overflow;
      end
    end
  end

  // Los valores por defecto evitan latches. rd_uart y wr_uart solo se ponen en
  // uno durante el ciclo en el que se lee o se escribe un byte.
  always_comb begin
    next_state = state;
    next_timeout_count = timeout_count;
    rd_uart = 1'b0;
    wr_uart = 1'b0;
    load_a = 1'b0;
    load_b = 1'b0;
    load_opcode = 1'b0;
    capture_result = 1'b0;

    case (state)
      STATE_WAIT_A: begin
        // Sin transacción parcial, el primer byte disponible siempre es A.
        next_timeout_count = {TIMEOUT_WIDTH{1'b0}};
        if (!rx_empty) begin
          rd_uart = 1'b1;
          load_a = 1'b1;
          next_state = STATE_WAIT_B;
        end
      end

      STATE_WAIT_B: begin
        // Si ocurre un error o B no llega en diez milisegundos, se descarta A.
        if (rx_error_tick) begin
          next_state = STATE_WAIT_A;
          next_timeout_count = {TIMEOUT_WIDTH{1'b0}};
        end else if (!rx_empty) begin
          rd_uart = 1'b1;
          load_b = 1'b1;
          next_state = STATE_WAIT_OPCODE;
          next_timeout_count = {TIMEOUT_WIDTH{1'b0}};
        end else if (timeout_count == TIMEOUT_CYCLES - 1) begin
          next_state = STATE_WAIT_A;
          next_timeout_count = {TIMEOUT_WIDTH{1'b0}};
        end else begin
          next_timeout_count = timeout_count + 1'b1;
        end
      end

      STATE_WAIT_OPCODE: begin
        // Se lee todo el tercer byte, pero solo se guardan sus bits 5:0.
        if (rx_error_tick) begin
          next_state = STATE_WAIT_A;
          next_timeout_count = {TIMEOUT_WIDTH{1'b0}};
        end else if (!rx_empty) begin
          rd_uart = 1'b1;
          load_opcode = 1'b1;
          next_state = STATE_EXECUTE;
          next_timeout_count = {TIMEOUT_WIDTH{1'b0}};
        end else if (timeout_count == TIMEOUT_CYCLES - 1) begin
          next_state = STATE_WAIT_A;
          next_timeout_count = {TIMEOUT_WIDTH{1'b0}};
        end else begin
          next_timeout_count = timeout_count + 1'b1;
        end
      end

      STATE_EXECUTE: begin
        // Este ciclo separa la carga del opcode del guardado del resultado.
        capture_result = 1'b1;
        next_state = STATE_WAIT_TX;
      end

      STATE_WAIT_TX: begin
        // Mientras tx_full esté activo, el resultado y las banderas no cambian.
        if (!tx_full) begin
          wr_uart = 1'b1;
          next_state = STATE_WAIT_A;
        end
      end

      default: begin
        // Ante una combinación one-hot inválida, se descarta la operación parcial.
        next_state = STATE_WAIT_A;
        next_timeout_count = {TIMEOUT_WIDTH{1'b0}};
      end
    endcase
  end

  // Los LED muestran siempre la última operación completa, incluso después de
  // que su byte de respuesta haya sido transmitido.
  assign w_data = result_reg;
  assign leds   = {overflow_reg, carry_reg, zero_reg, result_reg};

  // La frecuencia y el tiempo límite deben ser mayores que cero.
  initial begin
    if (CLK_FREQ_HZ <= 0 || TRANSACTION_TIMEOUT_MS <= 0) begin
      $error("Invalid alu_uart_controller parameters");
    end
  end
endmodule
