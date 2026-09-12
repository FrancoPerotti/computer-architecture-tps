`timescale 1ns / 1ps

// Transmisor UART. La salida solo cambia cuando termina el tiempo de cada bit.
module uart_tx #(
    parameter integer DATA_BITS  = 8,
    parameter integer OVERSAMPLE = 16,
    parameter integer STOP_TICKS = 16
) (
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 tx_start,
    input  wire                 s_tick,
    input  wire [DATA_BITS-1:0] data_in,
    output wire                 tx,
    output reg                  tx_done_tick,
    output wire                 tx_busy
);

  // Cada estado one-hot representa una sección de la trama 8N1.
  localparam logic [3:0] STATE_IDLE = 4'b0001;
  localparam logic [3:0] STATE_START = 4'b0010;
  localparam logic [3:0] STATE_DATA = 4'b0100;
  localparam logic [3:0] STATE_STOP = 4'b1000;

  // Cantidad de ciclos de sobremuestreo que se deben esperar para muestrear
  // un bit.
  localparam integer MAX_TICKS = (OVERSAMPLE > STOP_TICKS) ? OVERSAMPLE : STOP_TICKS;
  // Cantidad de bits necesarios para contar hasta MAX_TICKS.
  localparam integer SAMPLE_WIDTH = (MAX_TICKS <= 2) ? 1 : $clog2(MAX_TICKS);
  // Cantidad de bits necesarios para contar hasta DATA_BITS.
  localparam integer BIT_WIDTH = (DATA_BITS <= 2) ? 1 : $clog2(DATA_BITS);

  // Estado, contadores, byte en curso y nivel registrado del pin TX.
  (* fsm_encoding = "one_hot" *) reg [3:0] state = STATE_IDLE;
  reg [3:0] next_state;
  reg [SAMPLE_WIDTH-1:0] sample_count = {SAMPLE_WIDTH{1'b0}};
  reg [SAMPLE_WIDTH-1:0] next_sample_count;
  reg [BIT_WIDTH-1:0] bit_count = {BIT_WIDTH{1'b0}};
  reg [BIT_WIDTH-1:0] next_bit_count;
  reg [DATA_BITS-1:0] data_reg = {DATA_BITS{1'b0}};
  reg [DATA_BITS-1:0] next_data;
  reg tx_reg = 1'b1;
  reg next_tx;

  // El reset devuelve la interfaz al nivel de reposo alto en el próximo flanco.
  always @(posedge clk) begin
    if (reset) begin
      state        <= STATE_IDLE;
      sample_count <= {SAMPLE_WIDTH{1'b0}};
      bit_count    <= {BIT_WIDTH{1'b0}};
      data_reg     <= {DATA_BITS{1'b0}};
      tx_reg       <= 1'b1;
    end else begin
      state        <= next_state;
      sample_count <= next_sample_count;
      bit_count    <= next_bit_count;
      data_reg     <= next_data;
      tx_reg       <= next_tx;
    end
  end

  // Los valores por defecto conservan los registros y hacen que tx_done_tick
  // permanezca en uno durante un solo ciclo.
  always_comb begin
    next_state = state;
    next_sample_count = sample_count;
    next_bit_count = bit_count;
    next_data = data_reg;
    next_tx = tx_reg;
    tx_done_tick = 1'b0;

    case (state)
      STATE_IDLE: begin
        next_tx = 1'b1;
        next_sample_count = {SAMPLE_WIDTH{1'b0}};

        // El byte se guarda antes de comenzar el start para que data_in
        // pueda cambiar durante la transmisión sin alterar la trama.
        if (tx_start) begin
          next_state = STATE_START;
          next_data = data_in;
          next_bit_count = {BIT_WIDTH{1'b0}};
          next_tx = 1'b0;
        end
      end

      STATE_START: begin
        if (s_tick) begin
          // La línea se mantiene baja durante OVERSAMPLE ticks para enviar el start.
          if (sample_count == OVERSAMPLE - 1) begin
            next_state = STATE_DATA;
            next_sample_count = {SAMPLE_WIDTH{1'b0}};
            next_tx = data_reg[0];
          end else begin
            next_sample_count = sample_count + 1'b1;
          end
        end
      end

      STATE_DATA: begin
        if (s_tick) begin
          if (sample_count == OVERSAMPLE - 1) begin
            next_sample_count = {SAMPLE_WIDTH{1'b0}};
            if (bit_count == DATA_BITS - 1) begin
              next_state = STATE_STOP;
              next_tx = 1'b1;
            end else begin
              // El registro se desplaza a la derecha: primero sale D0 y después
              // queda preparado el bit siguiente.
              next_bit_count = bit_count + 1'b1;
              next_data = {1'b0, data_reg[DATA_BITS-1:1]};
              next_tx = data_reg[1];
            end
          end else begin
            next_sample_count = sample_count + 1'b1;
          end
        end
      end

      STATE_STOP: begin
        // La salida permanece alta durante toda la duración del bit de stop.
        next_tx = 1'b1;
        if (s_tick) begin
          if (sample_count == STOP_TICKS - 1) begin
            next_state = STATE_IDLE;
            next_sample_count = {SAMPLE_WIDTH{1'b0}};
            tx_done_tick = 1'b1;
          end else begin
            next_sample_count = sample_count + 1'b1;
          end
        end
      end

      default: begin
        // Ante una combinación one-hot inválida, la línea vuelve al reposo.
        next_state = STATE_IDLE;
        next_sample_count = {SAMPLE_WIDTH{1'b0}};
        next_bit_count = {BIT_WIDTH{1'b0}};
        next_data = {DATA_BITS{1'b0}};
        next_tx = 1'b1;
      end
    endcase
  end

  // tx_busy evita aceptar otro byte antes de finalizar el stop actual.
  assign tx = tx_reg;
  assign tx_busy = (state != STATE_IDLE);

  // Los parámetros deben permitir representar al menos dos bits de datos.
  initial begin
    if (DATA_BITS < 2 || OVERSAMPLE < 2 || STOP_TICKS <= 0) begin
      $error("Invalid uart_tx parameters");
    end
  end
endmodule
