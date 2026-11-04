`timescale 1ns / 1ps

// Comprueba almacenamiento MEM/WB y consumo preflanco con un observador de elegibilidad WB.
module mem_wb_boundary_tb #(
    parameter integer MEM_SOURCE_FIXTURE = 0
);
  import system_pkg::*;

  logic    clk = 1'b0;
  logic    reset = 1'b1;
  logic    preload_active = 1'b1;
  logic    cpu_cycle_fire = 1'b0;
  logic    capture;
  logic    valid_next;
  logic    observed_eligible;
  mem_wb_t data_in;
  mem_wb_t data_out;
  mem_wb_t initial_payload;
  mem_wb_t future_payload;
  mem_wb_t observed_payload;

  tp3_case_data data ();
  assign capture = preload_active || cpu_cycle_fire;
  mem_wb_register dut (
      .clk         (clk),
      .reset       (reset),
      .prepare_init(1'b0),
      .capture     (capture),
      .data_in     (data_in),
      .data_out    (data_out),
      .valid_next  (valid_next)
  );
  always #5 clk = ~clk;

  // Este observador no escribe RF; permite contrastar los datos y guardas de su frontera.
  always @(posedge clk) begin
    if (!reset && !preload_active) begin
      observed_payload = data_out;
      observed_eligible = cpu_cycle_fire && data_out.valid && data_out.reg_write &&
          data_out.rd != 0;
    end
  end

  // Informa un único fallo del caso y termina con código distinto de cero.
  function automatic void fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endfunction

  // Lee los seis campos concretos del fixture desde el catálogo.
  function automatic mem_wb_t read_payload(input string path);
    mem_wb_t value;
    value.valid       = data.get_integer({path, "/valid"});
    value.pc          = data.get_integer({path, "/pc"});
    value.instruction = data.get_integer({path, "/instruction"});
    value.rd          = data.get_integer({path, "/rd"});
    value.reg_write   = data.get_integer({path, "/reg_write"});
    value.wb_value    = data.get_integer({path, "/wb_value"});
    return value;
  endfunction

  initial begin
    word_t expected_value;
    string text_value;
    data.load();
    initial_payload = read_payload("/inputs/boundary/initial");
    future_payload  = read_payload("/inputs/boundary/future");
    @(negedge clk);
    reset   = 1'b0;
    data_in = initial_payload;
    @(posedge clk);
    #1;
    if (data_out !== initial_payload) fail("initial MEM/WB capture differs");
    @(negedge clk);
    preload_active = 1'b0;
    data_in        = future_payload;
    cpu_cycle_fire = data.get_integer("/inputs/boundary/cpu_cycle_fire");
    #1;
    if (data_out !== initial_payload) fail("MEM/WB changed before the edge");
    if (valid_next !== (cpu_cycle_fire ? future_payload.valid : initial_payload.valid)) begin
      fail("MEM/WB next validity differs");
    end
    @(posedge clk);
    #1;
    if (observed_payload !== initial_payload) fail("WB observer consumed post-edge fields");
    if (data_out !== (cpu_cycle_fire ? future_payload : initial_payload)) begin
      fail("MEM/WB capture or hold differs");
    end
    if (MEM_SOURCE_FIXTURE) begin
      // El valor seleccionado se inyecta en la frontera; no se acredita el mux de MEM.
      text_value = data.get_string({"/inputs/", data.get_string("/inputs/source")});
      if ($sscanf(
              text_value, "0x%h", expected_value
          ) != 1 || future_payload.wb_value !== expected_value)
        fail("preselected MEM fixture differs");
      text_value = data.get_string("/expected/memwb_next_wb_value");
      if ($sscanf(text_value, "0x%h", expected_value) != 1) fail("invalid expected WB value");
      if (data_out.wb_value !== expected_value) fail("selected MEM value was not registered");
    end else begin
      if (observed_payload.wb_value !== data.get_integer(
              "/inputs/current_wb_value"
          ) || future_payload.wb_value !== data.get_integer(
              "/inputs/future_wb_value"
          )) begin
        fail("WB boundary values differ from the canonical case");
      end
      if (observed_eligible !== data.get_boolean("/expected/write_fire")) begin
        fail("WB fixture eligibility differs from the published guard");
      end
      if (observed_eligible) begin
        if (observed_payload.wb_value !== data.get_integer("/expected/written_value")) begin
          fail("WB fixture did not consume the previous value");
        end
      end else if (data.get_string("/expected/written_value") != "ninguno") begin
        fail("inactive WB fixture must not declare a written value");
      end
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
