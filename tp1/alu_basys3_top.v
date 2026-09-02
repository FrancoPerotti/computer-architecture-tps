module alu_basys3_top (
    input  wire [7:0] sw,
    input  wire       btnU,
    input  wire       btnL,
    input  wire       btnR,
    input  wire       btnD,
    output wire [7:0] led
);
  // Los registros permiten reutilizar los mismos switches para cargar A, B y Op.
  reg [7:0] data_a = 8'b0;
  reg [7:0] data_b = 8'b0;
  reg [5:0] opcode = 6'b0;

  // Cada pulsador carga directamente uno de los registros. BTND funciona como
  // reset asíncrono.
  always @(posedge btnU or posedge btnD) begin
    if (btnD) data_a <= 8'b0;
    else data_a <= sw;
  end

  always @(posedge btnL or posedge btnD) begin
    if (btnD) data_b <= 8'b0;
    else data_b <= sw;
  end

  always @(posedge btnR or posedge btnD) begin
    if (btnD) opcode <= 6'b0;
    else opcode <= sw[5:0];
  end

  // El resultado combinacional del núcleo se muestra directamente en los LEDs.
  alu #(
      .NB_DATA  (8),
      .NB_OPCODE(6)
  ) alu_core (
      .o_result(led),
      .i_data_a(data_a),
      .i_data_b(data_b),
      .i_data_opcode(opcode)
  );
endmodule
