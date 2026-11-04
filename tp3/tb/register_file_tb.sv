`timescale 1ns / 1ps

// Verifica lecturas CPU/Debug y escrituras del RF con estímulos externos.
module register_file_tb;
  import system_pkg::*;

  tp3_case_data data ();
  logic            clk = 1'b0;
  logic            reset = 1'b0;
  logic            prepare_init = 1'b0;
  logic            write_enable = 1'b0;
  logic            debug_read_select = 1'b0;
  register_index_t read_register_1 = '0;
  register_index_t read_register_2 = '0;
  register_index_t debug_rf_addr = '0;
  register_index_t write_register = '0;
  word_t           write_data = '0;
  word_t           rf_rs1_value;
  word_t           rf_rs2_value;
  word_t           debug_rf_data;
  string           operation;

  register_file dut (
      .clk              (clk),
      .reset            (reset),
      .prepare_init     (prepare_init),
      .read_register_1  (read_register_1),
      .read_register_2  (read_register_2),
      .debug_rf_addr    (debug_rf_addr),
      .debug_read_select(debug_read_select),
      .write_register   (write_register),
      .write_data       (write_data),
      .write_enable     (write_enable),
      .rf_rs1_value     (rf_rs1_value),
      .rf_rs2_value     (rf_rs2_value),
      .debug_rf_data    (debug_rf_data)
  );

  always #5 clk = ~clk;

  // Termina con un resultado explícito cuando una lectura o escritura difiere.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  // Acepta palabras enteras o hexadecimales y rechaza truncamientos del fixture.
  function automatic word_t get_word(input string path);
    longint signed   value;
    longint unsigned parsed;
    if (data.get_type(path) == "integer") begin
      value = data.get_integer(path);
      if (value < 0 || value > 64'hffffffff) begin
        $fatal(1, "word outside unsigned 32-bit range: %s", path);
      end
      return word_t'(value);
    end
    if ($sscanf(data.get_string(path), "0x%h", parsed) != 1 || parsed > 64'hffffffff) begin
      $fatal(1, "invalid 32-bit hexadecimal word: %s", path);
    end
    return word_t'(parsed);
  endfunction

  // Conserva el rango de los índices del banco antes de convertirlos a cinco bits.
  function automatic register_index_t get_index(input string path);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || value > 31) $fatal(1, "register index outside range: %s", path);
    return register_index_t'(value);
  endfunction

  // Rechaza controles distintos de cero o uno en lugar de truncarlos a un bit.
  function automatic logic get_control(input string path);
    longint signed value;
    value = data.get_integer(path);
    if (value != 0 && value != 1) $fatal(1, "control outside binary range: %s", path);
    return value == 1;
  endfunction

  // Contrasta ambas lecturas y el alias Debug con sus valores externos.
  task automatic check_reads(input word_t expected_first, input word_t expected_second);
    assert (rf_rs1_value === expected_first && rf_rs2_value === expected_second &&
            debug_rf_data === expected_first)
    else begin
      fail($sformatf(
           "expected reads %08h/%08h, observed %08h/%08h, debug %08h",
           expected_first,
           expected_second,
           rf_rs1_value,
           rf_rs2_value,
           debug_rf_data
           ));
    end
  endtask

  // Instala el patrón por el puerto funcional; cada caso parte de un reset propio.
  task automatic load_fixture();
    @(negedge clk);
    reset = 1'b1;
    @(posedge clk);
    #1;
    @(negedge clk);
    reset = 1'b0;
    for (int index = 1; index < data.get_size("/inputs/initial_rf"); index++) begin
      write_enable   = 1'b1;
      write_register = register_index_t'(index);
      write_data     = get_word($sformatf("/inputs/initial_rf/%0d", index));
      @(posedge clk);
      #1;
      @(negedge clk);
    end
    write_enable = 1'b0;
  endtask

  // Comprueba x0 y las escrituras habilitada/deshabilitada a ambos lados del flanco.
  task automatic check_write_probe();
    @(negedge clk);
    debug_read_select = 1'b0;
    read_register_1   = get_index("/inputs/write_probe/write_register");
    read_register_2   = read_register_1;
    write_register    = read_register_1;
    write_enable      = get_control("/inputs/write_probe/write_enable");
    write_data        = get_word("/inputs/write_probe/write_data");
    #1;
    check_reads(get_word("/expected/write_probe/before"), get_word("/expected/write_probe/before"));
    @(posedge clk);
    #1;
    check_reads(get_word("/expected/write_probe/after"), get_word("/expected/write_probe/after"));
    if (data.get_size("/expected/RF_after_probe") != 32) begin
      fail("expectation must contain 32 registers");
    end
    for (int index = 0; index < data.get_size("/expected/RF_after_probe"); index++) begin
      read_register_1 = register_index_t'(index);
      read_register_2 = read_register_1;
      #1ps;
      check_reads(get_word($sformatf("/expected/RF_after_probe/%0d", index)), get_word(
                  $sformatf("/expected/RF_after_probe/%0d", index)));
    end
    @(negedge clk);
    write_enable = 1'b0;
  endtask

  // Mantiene la colisión hasta el flanco y observa luego los 32 registros sin writes.
  task automatic check_initialization();
    @(negedge clk);
    read_register_1 = get_index("/inputs/write_register");
    read_register_2 = read_register_1;
    reset           = get_control("/inputs/reset");
    prepare_init    = get_control("/inputs/prepare_init");
    write_enable    = get_control("/inputs/write_enable");
    write_register  = read_register_1;
    write_data      = get_word("/inputs/write_data");
    #1;
    check_reads(get_word("/expected/before_init"), get_word("/expected/before_init"));
    @(posedge clk);
    #1;
    // Las 32 lecturas terminan antes del siguiente flanco de inicialización.
    for (int index = 0; index < data.get_size("/expected/RF"); index++) begin
      read_register_1 = register_index_t'(index);
      read_register_2 = register_index_t'(index);
      #1ps;
      check_reads(get_word($sformatf("/expected/RF/%0d", index)), get_word(
                  $sformatf("/expected/RF/%0d", index)));
    end
    @(negedge clk);
    reset        = 1'b0;
    prepare_init = 1'b0;
    write_enable = 1'b0;
  endtask

  initial begin
    data.load();
    operation = data.get_string("/inputs/operation");
    if (data.get_size("/inputs/initial_rf") != 32) fail("fixture must contain 32 registers");
    #1;
    check_reads(get_word("/expected/x0_before_init"), get_word("/expected/x0_before_init"));
    load_fixture();
    if (operation == "initialize") begin
      if (data.get_size("/expected/RF") != 32) fail("expectation must contain 32 registers");
      check_initialization();
    end else begin
      read_register_1   = get_index("/inputs/rs1");
      read_register_2   = get_index("/inputs/rs2");
      debug_rf_addr     = get_index("/inputs/debug_rf_addr");
      debug_read_select = get_control("/inputs/debug_read_select");
      #1;
      if (operation == "read_cpu") begin
        check_reads(get_word("/expected/read1"), get_word("/expected/read2"));
      end else if (operation == "read_debug") begin
        check_reads(get_word("/expected/debug_rf_data"), get_word("/expected/rf_rs2_value"));
        // La vuelta a CPU debe recuperar su dirección sin capturar otro estado.
        debug_read_select = 1'b0;
        #1;
        check_reads(get_word("/expected/cpu_read1"), get_word("/expected/rf_rs2_value"));
      end else begin
        fail({"unknown RF operation: ", operation});
      end
      if (!data.is_null("/inputs/write_probe")) check_write_probe();
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
