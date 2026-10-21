`timescale 1ns / 1ps

// Comprueba candidato y causa sin memoria, registro IF/ID ni arbitraje.
module fetch_fault_check_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  localparam int unsigned     IMAGE_SIZE_WIDTH = capacity_inclusive_width(IMEM_CAPACITY_BYTES);
  localparam longint unsigned IMAGE_SIZE_MAX   = (64'd1 << IMAGE_SIZE_WIDTH) - 64'd1;
  tp3_case_data data ();
  word_t                               pc;
  logic                                image_valid;
  logic         [IMAGE_SIZE_WIDTH-1:0] loaded_image_size_bytes;
  logic                                if_fetch_fault_candidate;
  fault_cause_t                        if_fetch_fault_cause;

  fetch_fault_check #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) dut (
      .pc                      (pc),
      .image_valid             (image_valid),
      .loaded_image_size_bytes (loaded_image_size_bytes),
      .if_fetch_fault_candidate(if_fetch_fault_candidate),
      .if_fetch_fault_cause    (if_fetch_fault_cause)
  );

  // Valida los enteros antes de reducirlos al ancho del puerto correspondiente.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  // La referencia procede del catálogo; no se recalcula el rango esperado en el banco.
  task automatic check_value(input string name, input logic [63:0] observed,
                             input longint unsigned expected_value);
    assert (observed === expected_value)
    else begin
      $display("FAIL %s %s: expected %0d, observed %0d", data.case_id, name, expected_value,
               observed);
      $fatal(1, "fetch fault output differs from manifest");
    end
  endtask

  initial begin
    data.load();
    if (IMEM_CAPACITY_BYTES !== get_unsigned("/inputs/C", 64'h100000000)) begin
      $fatal(1, "elaborated IMEM capacity differs from manifest");
    end
    pc = word_t'(get_unsigned("/inputs/PC", 64'hffffffff));
    image_valid = 1'(get_unsigned("/inputs/image_valid", 1));
    loaded_image_size_bytes = IMAGE_SIZE_WIDTH'(get_unsigned("/inputs/image_size", IMAGE_SIZE_MAX));
    #1;
    check_value("if_fetch_fault_candidate", if_fetch_fault_candidate, data.get_boolean(
                "/expected/if_fetch_fault_candidate"));
    // null indica metadata no consumida para un fetch sin candidato.
    if (!data.is_null("/expected/cause")) begin
      check_value("if_fetch_fault_cause", if_fetch_fault_cause, get_unsigned("/expected/cause", 7));
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule

// El DUT debe terminar por configuración inválida; llegar al timeout produciría código cero.
module fetch_fault_check_config_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  logic         unused_candidate;
  fault_cause_t unused_cause;
  string        case_id;

  fetch_fault_check #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) dut (
      .pc                      ('0),
      .image_valid             (1'b0),
      .loaded_image_size_bytes ('0),
      .if_fetch_fault_candidate(unused_candidate),
      .if_fetch_fault_cause    (unused_cause)
  );

  initial begin
    #1;
    $finish;
  end

  // final registra el rechazo aunque el $fatal del hijo ocurra al iniciar la simulación.
  final begin
    if (!memory_capacity_valid(IMEM_CAPACITY_BYTES) && $value$plusargs("CASE=%s", case_id)) begin
      $display("REJECT %s %s", case_id, CONFIG_INVALID_CAPACITY);
    end
  end
endmodule
