`timescale 1ns / 1ps

// Comprueba el registro IF/ID aislado con secuencias y expectativas externas.
module if_id_register_tb;
  import system_pkg::*;

  logic   clk = 1'b0;
  logic   reset = 1'b1;
  logic   prepare_init = 1'b0;
  logic   capture = 1'b0;
  logic   hold = 1'b0;
  logic   invalidate = 1'b0;
  if_id_t data_in = '0;
  if_id_t data_out;
  logic   valid_next;

  tp3_case_data data ();
  if_id_register dut (
      .clk         (clk),
      .reset       (reset),
      .prepare_init(prepare_init),
      .capture     (capture),
      .hold        (hold),
      .invalidate  (invalidate),
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

  // Reconstruye los cinco campos sin depender del orden de las claves JSON.
  function automatic if_id_t read_payload(input string path);
    if_id_t payload;
    payload.valid             = data.get_integer({path, "/valid"});
    payload.pc                = data.get_integer({path, "/pc"});
    payload.instruction       = data.get_integer({path, "/instruction"});
    payload.fetch_fault_valid = data.get_integer({path, "/fetch_fault_valid"});
    payload.fetch_fault_cause = data.get_integer({path, "/fetch_fault_cause"});
    return payload;
  endfunction

  // Compara el payload completo o solo las valideces cuando los datos son inactivos.
  task automatic check_state(input string path, input if_id_t previous);
    string mode;
    if (data.get_type(path) == "object") begin
      if (data_out !== read_payload(path)) fail({"payload differs at ", path});
    end else begin
      mode = data.get_string(path);
      if (mode == "retained") begin
        if (data_out !== previous) fail({"register did not retain all five fields at ", path});
      end else if (mode == "invalidated") begin
        if (data_out.valid !== 1'b0 || data_out.fetch_fault_valid !== 1'b0) begin
          fail({"both validity flags must be clear at ", path});
        end
      end else begin
        fail({"unknown state expectation at ", path});
      end
    end
  endtask

  // Cambia controles entre flancos y contrasta próximo estado y estado registrado por separado.
  task automatic run_step(input integer index);
    string  input_path;
    string  expected_path;
    if_id_t previous;
    integer cycles;
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
      hold         = data.get_boolean({input_path, "/hold"});
      invalidate   = data.get_boolean({input_path, "/invalidate"});
      data_in      = read_payload({input_path, "/data"});
      #1;
      if (data_out !== previous) fail("registered state changed before the rising edge");
      if (valid_next !== data.get_boolean({expected_path, "/valid_next"})) begin
        fail({"combinational valid_next differs at ", expected_path});
      end
      @(posedge clk);
      #1;
      check_state({expected_path, "/state"}, previous);
      if (data_out.valid && data_out.fetch_fault_valid) begin
        fail("legal inputs produced simultaneous instruction and fetch candidate");
      end
    end
  endtask

  initial begin
    data.load();
    if ($bits(data_out) != data.get_integer("/expected/width")) begin
      fail("IF/ID width differs from manifest");
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
