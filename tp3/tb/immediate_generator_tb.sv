`timescale 1ns / 1ps

// Comprueba la reconstrucción combinacional del inmediato contra su valor externo.
module immediate_generator_tb;
  import system_pkg::*;

  tp3_case_data data ();
  word_t instruction;
  word_t immediate;
  word_t expected_immediate;

  immediate_generator dut (
      .instruction(instruction),
      .immediate  (immediate)
  );

  initial begin
    data.load();
    if ($sscanf(
            data.get_string("/inputs/word"), "0x%h", instruction
        ) != 1 || $sscanf(
            data.get_string("/expected/immediate"), "0x%h", expected_immediate
        ) != 1) begin
      $fatal(1, "invalid word or immediate in manifest");
    end
    #1;
    assert (immediate === expected_immediate)
    else begin
      $display("FAIL %s immediate: expected %08h, observed %08h", data.case_id, expected_immediate,
               immediate);
      $fatal(1, "immediate differs from manifest");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
