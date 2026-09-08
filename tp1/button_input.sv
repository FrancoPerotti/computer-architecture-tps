// Sincroniza el nivel de un botón con el reloj de la placa.
module button_input (
    input  wire clk,
    input  wire button,
    output wire button_pressed
);

  // ASYNC_REG indica a Vivado que estos flip-flops forman un sincronizador.
  (* ASYNC_REG = "TRUE" *)reg button_meta = 1'b0;
  (* ASYNC_REG = "TRUE" *)reg button_sync = 1'b0;

  // La primera etapa captura el botón y la segunda toma esa muestra en el
  // siguiente ciclo. Esto reduce el riesgo de propagar metastabilidad.
  always @(posedge clk) begin
    button_meta <= button;
    button_sync <= button_meta;
  end

  // El nivel sincronizado habilita la carga mientras el botón esté presionado.
  assign button_pressed = button_sync;
endmodule
