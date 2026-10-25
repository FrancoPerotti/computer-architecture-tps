`timescale 1ns / 1ps

// Comprueba las decisiones locales de control de flujo con expectativas externas al DUT.
module flow_control_tb;
  import system_pkg::*;

  tp3_case_data data ();
  logic     valid;
  flow_op_t flow_op;
  logic     zero;
  logic     target_sel;
  logic     redirect_requested;
  logic     ex_halt_candidate;

  flow_control dut (
      .valid             (valid),
      .flow_op           (flow_op),
      .zero              (zero),
      .target_sel        (target_sel),
      .redirect_requested(redirect_requested),
      .ex_halt_candidate (ex_halt_candidate)
  );

  // Rechaza valores que se truncarían al cargar los puertos de la unidad.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  // La igualdad estricta hace fallar también salidas desconocidas.
  task automatic check_output(input string name, input logic observed);
    logic expected_value;
    expected_value = 1'(get_unsigned({"/expected/", name}, 1));
    assert (observed === expected_value)
    else begin
      $display("FAIL %s %s: expected %0b, observed %0b", data.case_id, name, expected_value,
               observed);
      $fatal(1, "flow control output differs from manifest");
    end
  endtask

  initial begin
    data.load();
    valid   = 1'(get_unsigned("/inputs/flow_control/valid", 1));
    flow_op = flow_op_t'(get_unsigned("/inputs/flow_control/flow_op", 7));
    zero    = 1'(get_unsigned("/inputs/flow_control/zero", 1));
    #1;
    check_output("target_sel", target_sel);
    check_output("redirect_requested", redirect_requested);
    check_output("ex_halt_candidate", ex_halt_candidate);
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
