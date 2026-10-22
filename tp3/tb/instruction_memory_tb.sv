`timescale 1ns / 1ps

// Ejecuta transacciones explícitas de IMEM sin Loader, CPU ni validación de imagen.
module instruction_memory_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  localparam int unsigned     WORD_INDEX_WIDTH = word_index_width(IMEM_CAPACITY_BYTES);
  localparam longint unsigned INDEX_MAX        = (64'd1 << WORD_INDEX_WIDTH) - 64'd1;
  tp3_case_data data ();
  logic                         clk = 1'b0;
  logic                         reset = 1'b0;
  word_t                        read_address = '0;
  logic  [WORD_INDEX_WIDTH-1:0] imem_write_index = '0;
  word_t                        imem_write_data = '0;
  logic                         imem_write_enable = 1'b0;
  word_t                        instruction;

  instruction_memory #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) dut (
      .clk              (clk),
      .reset            (reset),
      .read_address     (read_address),
      .imem_write_index (imem_write_index),
      .imem_write_data  (imem_write_data),
      .imem_write_enable(imem_write_enable),
      .instruction      (instruction)
  );

  // Comprueba rangos antes de convertir los datos del catálogo al ancho del puerto.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  // Los datos esperados son externos; la comparación estricta rechaza X/Z.
  task automatic check_instruction(input string path);
    word_t expected_value;
    expected_value = word_t'(get_unsigned(path, 64'hffffffff));
    assert (instruction === expected_value)
    else begin
      $display("FAIL %s %s: expected %08h, observed %08h", data.case_id, path, expected_value,
               instruction);
      $fatal(1, "IMEM data differs from manifest");
    end
  endtask

  // Cada flanco consume las entradas ya estables; la salida permanece sin registrar.
  task automatic clock_edge();
    clk = 1'b1;
    #1;
    clk = 1'b0;
    #1;
  endtask

  initial begin
    data.load();
    if (IMEM_CAPACITY_BYTES !== get_unsigned("/inputs/C", 64'h100000000)) begin
      $fatal(1, "elaborated IMEM capacity differs from manifest");
    end
    if (data.get_size(
            "/inputs/imem_steps"
        ) == 0 || data.get_size(
            "/inputs/imem_steps"
        ) != data.get_size(
            "/expected/imem_steps"
        )) begin
      $fatal(1, "IMEM steps and expectations must have the same nonzero length");
    end

    // No se inicializa el array del DUT: el fixture escribe por el puerto de Loader.
    for (int index = 0; index < data.get_size("/inputs/initial_words"); index++) begin
      imem_write_index = WORD_INDEX_WIDTH
          '(get_unsigned($sformatf("/inputs/initial_words/%0d/index", index), INDEX_MAX));
      imem_write_data =
          word_t'(get_unsigned($sformatf("/inputs/initial_words/%0d/data", index), 64'hffffffff));
      imem_write_enable = 1'b1;
      #1;
      clock_edge();
    end
    imem_write_enable = 1'b0;

    for (int step = 0; step < data.get_size("/inputs/imem_steps"); step++) begin
      reset = 1'(get_unsigned($sformatf("/inputs/imem_steps/%0d/reset", step), 1));
      read_address = word_t
          '(get_unsigned($sformatf("/inputs/imem_steps/%0d/read_address", step), 64'hffffffff));
      imem_write_index = WORD_INDEX_WIDTH
          '(get_unsigned($sformatf("/inputs/imem_steps/%0d/imem_write_index", step), INDEX_MAX));
      imem_write_data = word_t
          '(get_unsigned($sformatf("/inputs/imem_steps/%0d/imem_write_data", step), 64'hffffffff));
      imem_write_enable =
          1'(get_unsigned($sformatf("/inputs/imem_steps/%0d/imem_write_enable", step), 1));
      #1;
      check_instruction($sformatf("/expected/imem_steps/%0d/before_edge", step));
      if (get_unsigned($sformatf("/inputs/imem_steps/%0d/clock_edge", step), 1)) begin
        clock_edge();
      end else begin
        #1;
      end
      check_instruction($sformatf("/expected/imem_steps/%0d/after_edge", step));
    end

    // Las comprobaciones finales cambian direcciones sin generar nuevos flancos.
    reset             = 1'b0;
    imem_write_enable = 1'b0;
    for (int index = 0; index < data.get_size("/expected/words_after"); index++) begin
      read_address = word_t
          '(get_unsigned($sformatf("/expected/words_after/%0d/address", index), 64'hffffffff));
      #1;
      check_instruction($sformatf("/expected/words_after/%0d/data", index));
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule

// El módulo real debe rechazar la configuración antes de elaborar su array.
module instruction_memory_config_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  word_t unused_instruction;
  string case_id;

  instruction_memory #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) dut (
      .clk              (1'b0),
      .reset            (1'b1),
      .read_address     ('0),
      .imem_write_index ('0),
      .imem_write_data  ('0),
      .imem_write_enable(1'b0),
      .instruction      (unused_instruction)
  );

  // Código cero detecta un rechazo ausente, aunque exista el marcador del final.
  initial begin
    #1;
    $finish;
  end

  final begin
    if (!memory_capacity_valid(IMEM_CAPACITY_BYTES) && $value$plusargs("CASE=%s", case_id)) begin
      $display("REJECT %s %s", case_id, CONFIG_INVALID_CAPACITY);
    end
  end
endmodule
