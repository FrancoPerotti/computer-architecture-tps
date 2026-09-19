`timescale 1ns / 1ps

// Receptor UART con sobremuestreo, trama 8N1 por defecto y validación de
// los bits de start y stop.
module uart_rx #(
    parameter integer DATA_BITS  = 8,
    parameter integer OVERSAMPLE = 16,
    parameter integer STOP_TICKS = 16
) (
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 rx,
    input  wire                 s_tick,
    output reg                  rx_done_tick,
    output reg                  frame_error_tick,
    output wire [DATA_BITS-1:0] data_out
);

  // Con codificación one-hot, cada estado de la trama tiene su propio flip-flop.
  localparam logic [4:0] STATE_IDLE    = 5'b00001;
  localparam logic [4:0] STATE_START   = 5'b00010;
  localparam logic [4:0] STATE_DATA    = 5'b00100;
  localparam logic [4:0] STATE_STOP    = 5'b01000;
  localparam logic [4:0] STATE_RECOVER = 5'b10000;

  // Cantidad de ciclos de sobremuestreo que se deben esperar para muestrear
  // un bit.
  localparam integer MAX_TICKS = (OVERSAMPLE > STOP_TICKS) ? OVERSAMPLE : STOP_TICKS;
  // Cantidad de bits necesarios para contar hasta MAX_TICKS.
  localparam integer SAMPLE_WIDTH = (MAX_TICKS <= 2) ? 1 : $clog2(MAX_TICKS);
  // Cantidad de bits necesarios para contar hasta DATA_BITS.
  localparam integer BIT_WIDTH = (DATA_BITS <= 2) ? 1 : $clog2(DATA_BITS);

  // Estado, contadores y registro de desplazamiento de la recepción actual.
  (* fsm_encoding = "one_hot" *) reg [4:0] state = STATE_IDLE;
  reg [4:0] next_state;
  reg [SAMPLE_WIDTH-1:0] sample_count = {SAMPLE_WIDTH{1'b0}};
  reg [SAMPLE_WIDTH-1:0] next_sample_count;
  reg [BIT_WIDTH-1:0] bit_count = {BIT_WIDTH{1'b0}};
  reg [BIT_WIDTH-1:0] next_bit_count;
  reg [DATA_BITS-1:0] data_reg = {DATA_BITS{1'b0}};
  reg [DATA_BITS-1:0] next_data;

  // Todos los registros se actualizan en el flanco ascendente.
  always @(posedge clk) begin
    if (reset) begin
      state        <= STATE_IDLE;
      sample_count <= {SAMPLE_WIDTH{1'b0}};
      bit_count    <= {BIT_WIDTH{1'b0}};
      data_reg     <= {DATA_BITS{1'b0}};
    end else begin
      state        <= next_state;
      sample_count <= next_sample_count;
      bit_count    <= next_bit_count;
      data_reg     <= next_data;
    end
  end

  // Los valores por defecto conservan los registros y mantienen los pulsos en
  // cero. Cada estado modifica solamente lo que necesita.
  always_comb begin
    next_state = state;
    next_sample_count = sample_count;
    next_bit_count = bit_count;
    next_data = data_reg;
    rx_done_tick = 1'b0;
    frame_error_tick = 1'b0;

    case (state)
      STATE_IDLE: begin
        next_sample_count = {SAMPLE_WIDTH{1'b0}};
        next_bit_count = {BIT_WIDTH{1'b0}};

        // Un nivel bajo puede indicar el comienzo de una trama, pero todavía
        // falta verificar que sea un bit de start válido.
        if (!rx) begin
          next_state = STATE_START;
        end
      end

      STATE_START: begin
        if (s_tick) begin
          if (sample_count == (OVERSAMPLE / 2) - 1) begin
            // Al llegar a OVERSAMPLE/2 se toma una muestra en el centro del
            // posible bit de start.
            next_sample_count = {SAMPLE_WIDTH{1'b0}};
            if (!rx) begin
              // Si estamos ante un nivel bajo, es un start válido y se pasa
              // a recibir los bits de datos.
              next_state = STATE_DATA;
              next_bit_count = {BIT_WIDTH{1'b0}};
            end else begin
              // Si estamos ante un nivel alto, es un falso start y se pasa
              // a recuperar la línea.
              next_state = STATE_RECOVER;
              frame_error_tick = 1'b1;
            end
          end else begin
            next_sample_count = sample_count + 1'b1;
          end
        end
      end

      STATE_DATA: begin
        if (s_tick) begin
          if (sample_count == OVERSAMPLE - 1) begin
            // Al llegar a OVERSAMPLE-1 se toma una muestra en el centro del
            // posible bit de datos.
            next_sample_count = {SAMPLE_WIDTH{1'b0}};

            // Los bits llegan desde D0 hasta D7. Cada muestra entra por la
            // izquierda y, después de ocho desplazamientos, forman el byte.
            next_data = {rx, data_reg[DATA_BITS-1:1]};

            // Al llegar al último bit de datos, se pasa a recibir el bit de
            // stop.
            if (bit_count == DATA_BITS - 1) begin
              next_state = STATE_STOP;
            end else begin
              next_bit_count = bit_count + 1'b1;
            end
          end else begin
            next_sample_count = sample_count + 1'b1;
          end
        end
      end

      STATE_STOP: begin
        if (s_tick) begin
          // El byte se entrega solamente si el bit de stop sigue alto al muestrearlo.
          if (sample_count == STOP_TICKS - 1) begin
            next_sample_count = {SAMPLE_WIDTH{1'b0}};
            if (rx) begin
              next_state   = STATE_IDLE;
              rx_done_tick = 1'b1;
            end else begin
              next_state = STATE_RECOVER;
              frame_error_tick = 1'b1;
            end
          end else begin
            next_sample_count = sample_count + 1'b1;
          end
        end
      end

      STATE_RECOVER: begin
        // Se espera que la línea vuelva a uno para no interpretar un nivel bajo
        // sostenido como varios bits de start.
        next_sample_count = {SAMPLE_WIDTH{1'b0}};
        next_bit_count = {BIT_WIDTH{1'b0}};
        if (rx) begin
          next_state = STATE_IDLE;
        end
      end

      default: begin
        // Ante una combinación one-hot inválida, se vuelve al estado de reposo.
        next_state = STATE_IDLE;
        next_sample_count = {SAMPLE_WIDTH{1'b0}};
        next_bit_count = {BIT_WIDTH{1'b0}};
        next_data = {DATA_BITS{1'b0}};
      end
    endcase
  end

  // data_out conserva el último byte recibido; rx_done_tick indica que es válido.
  assign data_out = data_reg;

  // El muestreo central necesita un factor par y al menos cuatro muestras.
  initial begin
    if (DATA_BITS < 2 || OVERSAMPLE < 4 || (OVERSAMPLE % 2) != 0 || STOP_TICKS <= 0) begin
      $error("Invalid uart_rx parameters");
    end
  end
endmodule
