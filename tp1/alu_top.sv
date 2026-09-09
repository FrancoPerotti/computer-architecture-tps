// Guarda A, B y el opcode con los botones y muestra el resultado de la ALU en LEDs.
module alu_top (
    input wire       clk,
    input wire [7:0] switches,

    input wire btn_load_a,
    input wire btn_load_b,
    input wire btn_load_opcode,
    input wire btn_reset,

    output wire [10:0] leds
);

  // Estas señales representan el nivel sincronizado de cada botón.
  wire load_a;
  wire load_b;
  wire load_opcode;
  wire reset_pressed;

  reg [7:0] data_a;
  reg [7:0] data_b;
  reg [5:0] opcode;

  // Su valor inicial provoca el borrado de los registros en el primer flanco de clk.
  reg startup_reset = 1'b1;

  // Cada botón habilita la carga de su registro.
  button_input button_a (
      .clk           (clk),
      .button        (btn_load_a),
      .button_pressed(load_a)
  );

  button_input button_b (
      .clk           (clk),
      .button        (btn_load_b),
      .button_pressed(load_b)
  );

  button_input button_opcode (
      .clk           (clk),
      .button        (btn_load_opcode),
      .button_pressed(load_opcode)
  );

  // Reset mantiene los registros en cero mientras su nivel sincronizado esté activo.
  button_input button_reset (
      .clk           (clk),
      .button        (btn_reset),
      .button_pressed(reset_pressed)
  );

  // Todos los registros se actualizan en el flanco ascendente del reloj.
  // El reset tiene prioridad sobre las cargas.
  always @(posedge clk) begin
    // En este ciclo el if todavía evalúa el valor anterior de startup_reset.
    startup_reset <= 1'b0;

    if (startup_reset || reset_pressed) begin
      data_a <= 8'b0;
      data_b <= 8'b0;
      opcode <= 6'b0;
    end else begin
      // Mientras el botón esté presionado, se guarda el dato en cada ciclo.
      // Al desactivarse su nivel sincronizado, el registro conserva el último dato.
      if (load_a) begin
        data_a <= switches;
      end

      if (load_b) begin
        data_b <= switches;
      end

      if (load_opcode) begin
        opcode <= switches[5:0];
      end
    end
  end

  // La ALU calcula a partir de los valores guardados y actualiza los LEDs
  // cuando cambia alguno de sus operandos o el opcode.
  alu #(
      .NB_DATA  (8),
      .NB_OPCODE(6)
  ) alu_core (
      .o_result     (leds[7:0]),
      .o_zero       (leds[8]),
      .o_carry      (leds[9]),
      .o_overflow   (leds[10]),
      .i_data_a     (data_a),
      .i_data_b     (data_b),
      .i_data_opcode(opcode)
  );
endmodule
