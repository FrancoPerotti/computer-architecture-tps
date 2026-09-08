`timescale 1ns / 1ps

module button_input_tb;
  reg clk    = 1'b0;
  reg button = 1'b0;

  wire button_pressed;

  integer tests  = 0;
  integer errors = 0;

  // Período de 10 ns: reloj de 100 MHz.
  always #5 begin
    clk = ~clk;
  end

  button_input dut (
      .clk           (clk),
      .button        (button),
      .button_pressed(button_pressed)
  );

  // Espera un flanco y la actualización de los registros.
  task automatic tick;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic check;
    input [8*80-1:0] description;
    input expected;

    begin
      tests = tests + 1;

      if (button_pressed !== expected) begin
        errors = errors + 1;
        $display("ERROR: %0s; expected=%b, obtained=%b", description, expected, button_pressed);
      end
    end
  endtask

  initial begin
    tick;
    check("Boton suelto al iniciar", 1'b0);

    // El nivel atraviesa las dos etapas de sincronización.
    @(negedge clk);
    button = 1'b1;
    #1;
    check("El cambio del pin espera al reloj", 1'b0);

    tick;
    check("Primer flanco: captura en la primera etapa", 1'b0);

    tick;
    check("Segundo flanco: salida presionada", 1'b1);

    repeat (5) begin
      tick;
      check("Boton sostenido mantiene el nivel activo", 1'b1);
    end

    @(negedge clk);
    button = 1'b0;
    tick;
    check("Primer flanco al soltar", 1'b1);

    tick;
    check("Segundo flanco al soltar", 1'b0);

    // Una pulsación de un ciclo también se propaga por el sincronizador.
    @(negedge clk);
    button = 1'b1;
    tick;
    check("Inicio de pulsacion breve", 1'b0);

    @(negedge clk);
    button = 1'b0;
    tick;
    check("Pulsacion breve en la salida", 1'b1);

    tick;
    check("Fin de pulsacion breve", 1'b0);

    if (errors != 0) begin
      $fatal(1, "FAIL: %0d errors in %0d button checks", errors, tests);
    end

    $display("PASS: %0d button checks completed without errors", tests);
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "FAIL: button testbench timeout");
  end
endmodule
