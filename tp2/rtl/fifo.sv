`timescale 1ns / 1ps

// FIFO síncrona con 2**ADDR_WIDTH lugares y acceso directo al primer dato.
module fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ADDR_WIDTH = 2
) (
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  rd,
    input  wire                  wr,
    input  wire [DATA_WIDTH-1:0] write_data,
    output wire [DATA_WIDTH-1:0] read_data,
    output wire                  empty,
    output wire                  full
);

  // Un bit adicional en count permite distinguir vacío de lleno aun cuando
  // los punteros de lectura y escritura tengan el mismo valor.
  localparam integer DEPTH = 1 << ADDR_WIDTH;

  reg [DATA_WIDTH-1:0] memory[0:DEPTH-1];
  reg [ADDR_WIDTH-1:0] read_pointer = {ADDR_WIDTH{1'b0}};
  reg [ADDR_WIDTH-1:0] write_pointer = {ADDR_WIDTH{1'b0}};
  reg [ADDR_WIDTH:0] count = {(ADDR_WIDTH + 1) {1'b0}};

  wire read_accept;
  wire write_accept;

  assign empty = (count == 0);
  assign full = (count == DEPTH);

  // read_data muestra el dato más antiguo; solo se lo retira cuando se acepta rd.
  assign read_data = memory[read_pointer];

  // Una lectura en vacío o una escritura en lleno se ignoran. Si el FIFO está
  // lleno y llegan ambas juntas, se acepta solamente la lectura.
  assign read_accept = rd && !empty;
  assign write_accept = wr && !full;

  // Cada operación aceptada avanza su propio puntero. Al llegar al último lugar,
  // el ancho del puntero hace que vuelva automáticamente a cero.
  always @(posedge clk) begin
    if (reset) begin
      read_pointer  <= {ADDR_WIDTH{1'b0}};
      write_pointer <= {ADDR_WIDTH{1'b0}};
      count         <= {(ADDR_WIDTH + 1) {1'b0}};
    end else begin
      if (write_accept) begin
        memory[write_pointer] <= write_data;
        write_pointer <= write_pointer + 1'b1;
      end

      if (read_accept) begin
        read_pointer <= read_pointer + 1'b1;
      end

      // Si se lee y escribe a la vez, la cantidad de datos no cambia.
      case ({
        write_accept, read_accept
      })
        2'b10:   count <= count + 1'b1;
        2'b01:   count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

  // El FIFO necesita al menos un bit de dirección y uno de datos.
  initial begin
    if (DATA_WIDTH <= 0 || ADDR_WIDTH <= 0) begin
      $error("Invalid FIFO parameters");
    end
  end
endmodule
