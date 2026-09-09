`timescale 1ns / 1ps

module alu_top_tb;
  // Dos ciclos para sincronizar el botón y uno para cargar el registro.
  localparam integer LOAD_CYCLES = 3;

  reg            clk = 1'b0;
  reg            clock_enabled = 1'b1;

  reg     [ 7:0] switches = 8'b0;
  reg            btn_load_a = 1'b0;
  reg            btn_load_b = 1'b0;
  reg            btn_load_opcode = 1'b0;
  reg            btn_reset = 1'b0;

  wire    [10:0] leds;

  integer        tests = 0;
  integer        errors = 0;

  // Genera 100 MHz y permite detener el reloj durante la última prueba.
  always #5 begin
    if (clock_enabled) begin
      clk = ~clk;
    end
  end

  alu_top dut (
      .clk            (clk),
      .switches       (switches),
      .btn_load_a     (btn_load_a),
      .btn_load_b     (btn_load_b),
      .btn_load_opcode(btn_load_opcode),
      .btn_reset      (btn_reset),
      .leds           (leds)
  );

  // Espera la actualización de los registros antes de comprobar el resultado.
  task automatic tick;
    input integer cycles;

    begin
      repeat (cycles) begin
        @(posedge clk);
        #1;
      end
    end
  endtask

  task automatic check_state;
    input [8*96-1:0] description;
    input [7:0] expected_a;
    input [7:0] expected_b;
    input [5:0] expected_opcode;
    input [10:0] expected_leds;

    begin
      tests = tests + 1;

      if ({dut.data_a, dut.data_b, dut.opcode, leds} !==
          {expected_a, expected_b, expected_opcode, expected_leds}) begin
        errors = errors + 1;
        $display("ERROR: %0s", description);
        $display("  expected A=%h B=%h opcode=%b LED=%h", expected_a, expected_b, expected_opcode,
                 expected_leds);
        $display("  obtained A=%h B=%h opcode=%b LED=%h", dut.data_a, dut.data_b, dut.opcode, leds);
      end
    end
  endtask

  // Cambia los botones en el flanco descendente. La máscara es {reset, cargar A, cargar B, cargar opcode}.
  task automatic set_buttons;
    input [3:0] buttons;

    begin
      @(negedge clk);
      {btn_reset, btn_load_a, btn_load_b, btn_load_opcode} = buttons;
    end
  endtask

  // Configura los switches, presiona el botón y lo suelta antes del siguiente dato.
  task automatic press_load;
    input [3:0] buttons;
    input [7:0] value;

    begin
      @(negedge clk);
      switches = value;
      tick(3);

      set_buttons(buttons);
      tick(LOAD_CYCLES + 2);

      set_buttons(4'b0000);
      tick(LOAD_CYCLES);
    end
  endtask

  // Los tres bits superiores de leds son overflow, carry y cero, en ese orden.
  task automatic check_operation;
    input [8*96-1:0] description;
    input [7:0] test_a;
    input [7:0] test_b;
    input [5:0] test_opcode;
    input [7:0] expected_result;
    input [2:0] expected_flags;

    begin
      press_load(4'b0100, test_a);
      press_load(4'b0010, test_b);
      press_load(4'b0001, {2'b00, test_opcode});

      check_state(description, test_a, test_b, test_opcode, {expected_flags, expected_result});
    end
  endtask

  initial begin
    tick(1);
    check_state("Inicializacion en el primer ciclo", 8'd0, 8'd0, 6'd0, {3'b001, 8'd0});

    @(negedge clk);
    switches = 8'hff;
    tick(3);
    check_state("Switches sin botones conservan registros", 8'd0, 8'd0, 6'd0, {3'b001, 8'd0});

    press_load(4'b0100, 8'd5);
    check_state("Boton de A carga A", 8'd5, 8'd0, 6'd0, {3'b001, 8'd0});

    press_load(4'b0010, 8'd3);
    check_state("Boton de B carga B y conserva A", 8'd5, 8'd3, 6'd0, {3'b001, 8'd0});

    press_load(4'b0001, 8'b11100000);
    check_state("Boton de opcode carga ADD usando SW5 a SW0", 8'd5, 8'd3, 6'b100000, {3'b000, 8'd8
                });

    // Observa los dos ciclos de sincronización y el ciclo de carga.
    @(negedge clk);
    switches = 8'd10;
    tick(3);
    set_buttons(4'b0100);

    tick(1);
    check_state("Primera etapa del boton", 8'd5, 8'd3, 6'b100000, {3'b000, 8'd8});

    tick(1);
    check_state("Segunda etapa del boton", 8'd5, 8'd3, 6'b100000, {3'b000, 8'd8});

    tick(1);
    check_state("Carga habilitada por el boton sincronizado", 8'd10, 8'd3, 6'b100000, {3'b000, 8'd13
                });

    tick(10);
    check_state("Boton sostenido guarda el mismo dato", 8'd10, 8'd3, 6'b100000, {3'b000, 8'd13});

    // Simula rebotes al soltar con el número ya configurado en los switches.
    repeat (3) begin
      set_buttons(4'b0000);
      tick(1);
      set_buttons(4'b0100);
      tick(1);
    end
    set_buttons(4'b0000);
    tick(LOAD_CYCLES);
    check_state("Rebotes conservan el dato cargado", 8'd10, 8'd3, 6'b100000, {3'b000, 8'd13});

    @(negedge clk);
    switches = 8'd20;
    tick(4);
    check_state("Preparar otro numero con botones sueltos conserva A", 8'd10, 8'd3, 6'b100000, {
                3'b000, 8'd13});

    press_load(4'b0100, 8'd20);
    press_load(4'b0010, 8'd4);
    press_load(4'b0001, 8'b00100010);
    check_state("SUB: 20 - 4 = 16", 8'd20, 8'd4, 6'b100010, {3'b000, 8'd16});

    press_load(4'b0001, 8'hff);
    check_state("Opcode invalido", 8'd20, 8'd4, 6'b111111, {3'b001, 8'd0});

    press_load(4'b0100, 8'h80);
    press_load(4'b0010, 8'd1);
    press_load(4'b0001, 8'b00000011);
    check_state("SRA: 80 >>> 1 = C0", 8'h80, 8'd1, 6'b000011, {3'b000, 8'hc0});

    press_load(4'b0110, 8'd7);
    check_state("Botones de A y B juntos cargan ambos operandos", 8'd7, 8'd7, 6'b000011, {
                3'b001, 8'd0});

    press_load(4'b0001, 8'b00100000);
    check_state("ADD despues de carga simultanea", 8'd7, 8'd7, 6'b100000, {3'b000, 8'd14});

    set_buttons(4'b1000);
    tick(2);
    check_state("Reset atraviesa el sincronizador", 8'd7, 8'd7, 6'b100000, {3'b000, 8'd14});

    tick(1);
    check_state("Reset borra los tres registros", 8'd0, 8'd0, 6'd0, {3'b001, 8'd0});

    @(negedge clk);
    switches = 8'hff;
    tick(3);
    set_buttons(4'b1111);
    tick(LOAD_CYCLES + 2);
    check_state("Reset tiene prioridad sobre las cargas", 8'd0, 8'd0, 6'd0, {3'b001, 8'd0});

    // Al soltar reset, los botones sostenidos vuelven a habilitar las cargas.
    set_buttons(4'b0111);
    tick(LOAD_CYCLES);
    check_state("Cargas por nivel despues de soltar reset", 8'hff, 8'hff, 6'b111111, {3'b001, 8'd0
                });

    set_buttons(4'b0000);
    tick(LOAD_CYCLES);
    press_load(4'b0100, 8'd5);
    press_load(4'b0010, 8'd3);
    press_load(4'b0001, 8'b00100000);
    check_state("Se puede operar despues del reset", 8'd5, 8'd3, 6'b100000, {3'b000, 8'd8});

    // Los botones necesitan flancos de clk para sincronizarse y cargar los datos.
    @(negedge clk);
    clock_enabled = 1'b0;
    switches = 8'd9;
    btn_load_a = 1'b1;
    #200;
    check_state("Reloj detenido conserva registros", 8'd5, 8'd3, 6'b100000, {3'b000, 8'd8});

    clock_enabled = 1'b1;
    tick(LOAD_CYCLES);
    check_state("Al volver el reloj se carga A", 8'd9, 8'd3, 6'b100000, {3'b000, 8'd12});

    set_buttons(4'b0000);
    tick(LOAD_CYCLES);

    // Casos conocidos para comprobar cada indicador y su apagado al cambiar de operación.
    check_operation("ADD: carry y cero", 8'hff, 8'h01, 6'b100000, 8'h00, 3'b011);
    check_operation("AND: apaga carry", 8'hff, 8'h01, 6'b100100, 8'h01, 3'b000);
    check_operation("ADD: overflow positivo", 8'h7f, 8'h01, 6'b100000, 8'h80, 3'b100);
    check_operation("SUB: resultado dentro del rango", 8'h7f, 8'h01, 6'b100010, 8'h7e, 3'b000);
    check_operation("SUB: overflow negativo", 8'h80, 8'h01, 6'b100010, 8'h7f, 3'b100);
    check_operation("SUB: resta de negativos", 8'h80, 8'hff, 6'b100010, 8'h81, 3'b000);
    check_operation("SUB: overflow positivo", 8'h7f, 8'hff, 6'b100010, 8'h80, 3'b100);
    check_operation("ADD: los tres indicadores", 8'h80, 8'h80, 6'b100000, 8'h00, 3'b111);
    check_operation("SRL: cero sin carry ni overflow", 8'h80, 8'h80, 6'b000010, 8'h00, 3'b001);
    check_operation("SRA: replica el signo", 8'h80, 8'h80, 6'b000011, 8'hff, 3'b000);
    check_operation("OR: resultado no nulo", 8'h80, 8'h80, 6'b100101, 8'h80, 3'b000);
    check_operation("XOR: cero", 8'h80, 8'h80, 6'b100110, 8'h00, 3'b001);
    check_operation("NOR: resultado no nulo", 8'h80, 8'h80, 6'b100111, 8'h7f, 3'b000);
    check_operation("SUB: cero con carry apagado", 8'h80, 8'h80, 6'b100010, 8'h00, 3'b001);

    set_buttons(4'b1000);
    tick(LOAD_CYCLES);
    check_state("Reset deja encendido el indicador de cero", 8'd0, 8'd0, 6'd0, {3'b001, 8'd0});

    if (errors != 0) begin
      $fatal(1, "FAIL: %0d errors in %0d top checks", errors, tests);
    end

    $display("PASS: %0d top checks completed without errors", tests);
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "FAIL: top testbench timeout");
  end
endmodule
