// Genera éxitos y fallos artificiales para verificar el ejecutor con casos temporales.
module runner_smoke_tb #(
    parameter integer OFFSET = 0
);
  import runner_smoke_pkg::*;
  tp3_case_data data ();
  string         mode;
  longint signed observed;
  longint signed expected_value;

  initial begin
    data.load();
    mode = data.get_string("/inputs/mode");
    if (mode == "hang") begin
      forever #1;
    end
    if (mode == "silent") $finish;
    if (mode == "wrong_id") begin
      $display("PASS TEST-SMOKE-999/C999");
      $finish;
    end
    if (mode == "duplicate") begin
      $display("PASS %s", data.case_id);
      $display("PASS %s", data.case_id);
      $finish;
    end
    if (mode == "pass_nonzero") begin
      $display("PASS %s", data.case_id);
      $fatal(1, "intentional nonzero exit after PASS");
    end
    if (mode == "fail_zero") begin
      $display("FAIL %s intentional failure with zero exit", data.case_id);
      $finish;
    end
    if (mode == "contradictory") begin
      $display("PASS %s", data.case_id);
      $display("FAIL %s contradictory result", data.case_id);
      $fatal(1, "intentional contradictory results");
    end
    if (mode == "stderr_only") begin
      $fdisplay(32'h80000002, "PASS %s", data.case_id);
      $finish;
    end
    if (mode == "no_reason") begin
      $display("FAIL %s", data.case_id);
      $fatal(1, "intentional missing explanation");
    end
    if (mode == "fatal_only") $fatal(1, "SMOKE_REJECTION");
    if (mode == "reject" || mode == "reject_zero" || mode == "reject_duplicate" ||
        mode == "reject_wrong_id") begin
      if (mode == "reject_wrong_id") begin
        $display("REJECT TEST-SMOKE-999/C999 SMOKE_REJECTION");
      end else begin
        $display("REJECT %s SMOKE_REJECTION", data.case_id);
      end
      if (mode == "reject_duplicate") $display("REJECT %s SMOKE_REJECTION", data.case_id);
      if (mode == "reject_zero") $finish;
      $fatal(1, "SMOKE_REJECTION");
    end
    observed       = add(data.get_integer("/inputs/a"), data.get_integer("/inputs/b")) + OFFSET;
    expected_value = data.get_integer("/expected/result");
    assert (observed === expected_value)
    else begin
      $display("FAIL %s expected %0d, observed %0d", data.case_id, expected_value, observed);
      $fatal(1, "intentional assertion failure");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule

// La selección explícita del top debe impedir que se ejecute esta raíz ajena a la prueba.
module runner_unselected_top;
  initial $fatal(1, "runner did not select the requested top");
endmodule
