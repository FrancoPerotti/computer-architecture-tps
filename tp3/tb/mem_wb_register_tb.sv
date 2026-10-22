`timescale 1ns / 1ps

// Comprueba el registro MEM/WB aislado con secuencias y expectativas externas.
module mem_wb_register_tb;
  import system_pkg::*;

  logic    clk = 1'b0;
  logic    reset = 1'b1;
  logic    prepare_init = 1'b0;
  logic    capture = 1'b0;
  mem_wb_t data_in = '0;
  mem_wb_t data_out;
  logic    valid_next;

  tp3_case_data data ();
  mem_wb_register dut (
      .clk         (clk),
      .reset       (reset),
      .prepare_init(prepare_init),
      .capture     (capture),
      .data_in     (data_in),
      .data_out    (data_out),
      .valid_next  (valid_next)
  );

  always #5 clk = ~clk;

  // Informa un único fallo del caso y termina con código distinto de cero.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  // Reconstruye los seis campos sin depender del orden de las claves JSON.
  function automatic mem_wb_t read_payload(input string path);
    mem_wb_t payload;
    payload.valid       = data.get_integer({path, "/valid"});
    payload.pc          = data.get_integer({path, "/pc"});
    payload.instruction = data.get_integer({path, "/instruction"});
    payload.rd          = data.get_integer({path, "/rd"});
    payload.reg_write   = data.get_integer({path, "/reg_write"});
    payload.wb_value    = data.get_integer({path, "/wb_value"});
    return payload;
  endfunction

  // Compara el payload completo o solo valid cuando los datos son inactivos.
  task automatic check_state(input string path, input mem_wb_t previous);
    string mode;
    if (data.get_type(path) == "object") begin
      if (data_out !== read_payload(path)) fail({"payload differs at ", path});
    end else begin
      mode = data.get_string(path);
      if (mode == "retained") begin
        if (data_out !== previous) fail({"register did not retain all six fields at ", path});
      end else if (mode == "invalidated") begin
        if (data_out.valid !== 1'b0) fail({"valid must be clear at ", path});
      end else begin
        fail({"unknown state expectation at ", path});
      end
    end
  endtask

  // Cambia controles entre flancos y contrasta próximo estado y estado registrado por separado.
  task automatic run_step(input integer index);
    string   input_path;
    string   expected_path;
    mem_wb_t previous;
    integer  cycles;
    input_path    = $sformatf("/inputs/steps/%0d", index);
    expected_path = $sformatf("/expected/steps/%0d", index);
    cycles        = data.get_integer({input_path, "/cycles"});
    if (cycles < 1) fail("a step must contain at least one clock cycle");
    for (integer cycle = 0; cycle < cycles; cycle = cycle + 1) begin
      @(negedge clk);
      previous     = data_out;
      reset        = data.get_boolean({input_path, "/reset"});
      prepare_init = data.get_boolean({input_path, "/prepare_init"});
      capture      = data.get_boolean({input_path, "/capture"});
      data_in      = read_payload({input_path, "/data"});
      #1;
      if (data_out !== previous) fail("registered state changed before the rising edge");
      if (valid_next !== data.get_boolean({expected_path, "/valid_next"})) begin
        fail({"combinational valid_next differs at ", expected_path});
      end
      @(posedge clk);
      #1;
      check_state({expected_path, "/state"}, previous);
    end
  endtask

  initial begin
    data.load();
    if ($bits(data_out) != data.get_integer("/expected/width")) begin
      fail("MEM/WB width differs from manifest");
    end
    if (data.get_size("/inputs/steps") != data.get_size("/expected/steps")) begin
      fail("stimulus and expectation step counts differ");
    end
    @(posedge clk);
    #1;
    check_state("/expected/startup", data_out);
    for (integer index = 0; index < data.get_size("/inputs/steps"); index = index + 1) begin
      run_step(index);
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
