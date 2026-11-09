// FIFO síncrona genérica para los caminos UART RX y TX.
module fifo #(
    parameter integer DATA_WIDTH = system_pkg::UART_DATA_BITS,
    parameter integer ADDR_WIDTH = $clog2(system_pkg::UART_FIFO_DEPTH)
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  rd,
    input  logic                  wr,
    input  logic [DATA_WIDTH-1:0] write_data,
    output logic [DATA_WIDTH-1:0] read_data,
    output logic                  empty,
    output logic                  full
);

  localparam integer                DEPTH       = 1 << ADDR_WIDTH;
  localparam logic   [ADDR_WIDTH:0] DEPTH_COUNT = {1'b1, {ADDR_WIDTH{1'b0}}};

  logic [DATA_WIDTH-1:0] memory             [DEPTH];
  logic [ADDR_WIDTH-1:0] read_pointer = '0;
  logic [ADDR_WIDTH-1:0] write_pointer = '0;
  logic [  ADDR_WIDTH:0] count = '0;
  logic                  read_accept;
  logic                  write_accept;

  always_comb begin
    empty        = (count == 0);
    full         = (count == DEPTH_COUNT);
    read_data    = memory[read_pointer];
    read_accept  = rd && !empty;
    write_accept = wr && !full;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      read_pointer  <= '0;
      write_pointer <= '0;
      count         <= '0;
    end else begin
      if (write_accept) begin
        memory[write_pointer] <= write_data;
        write_pointer         <= write_pointer + 1'b1;
      end

      if (read_accept) begin
        read_pointer <= read_pointer + 1'b1;
      end

      case ({
        write_accept, read_accept
      })
        2'b10:   count <= count + 1'b1;
        2'b01:   count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

  initial begin
    if (DATA_WIDTH <= 0 || ADDR_WIDTH <= 0) begin
      $error("Invalid FIFO parameters");
    end
  end
endmodule
