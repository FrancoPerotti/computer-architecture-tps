`timescale 1ns / 1ps

// Comprueba vectores de arbitraje y secuencias locales con resultados de productores simulados.
module global_fsm_tb #(
    parameter integer CHECK_SEQUENCE = 0
);
  logic          clk = 1'b0;
  logic          reset = 1'b1;
  logic          load_request = 1'b0;
  logic          run_request = 1'b0;
  logic          step_request = 1'b0;
  logic          load_ok = 1'b0;
  logic          load_fail = 1'b0;
  logic          prepare_done = 1'b0;
  logic          halt_confirm = 1'b0;
  logic          fault_confirm = 1'b0;
  logic          pipeline_empty_next = 1'b1;
  logic          command_accepted;
  logic          load_start;
  logic          cpu_cycle_fire;
  logic          image_publish;
  logic          loader_active;
  logic          prepare_active;
  logic          drain_mode;
  logic          load_available;
  logic          program_finished;
  logic          fault_terminal;
  logic   [ 7:0] global_state_code;
  integer        index;
  integer        repetition;
  integer        repetitions;
  string         input_path;
  string         expected_path;
  logic   [13:0] fixture_state;

  tp3_case_data data ();
  global_fsm dut (
      .clk                (clk),
      .reset              (reset),
      .load_request       (load_request),
      .run_request        (run_request),
      .step_request       (step_request),
      .load_ok            (load_ok),
      .load_fail          (load_fail),
      .prepare_done       (prepare_done),
      .halt_confirm       (halt_confirm),
      .fault_confirm      (fault_confirm),
      .pipeline_empty_next(pipeline_empty_next),
      .command_accepted   (command_accepted),
      .load_start         (load_start),
      .cpu_cycle_fire     (cpu_cycle_fire),
      .image_publish      (image_publish),
      .loader_active      (loader_active),
      .prepare_active     (prepare_active),
      .drain_mode         (drain_mode),
      .load_available     (load_available),
      .program_finished   (program_finished),
      .fault_terminal     (fault_terminal),
      .global_state_code  (global_state_code)
  );

  always #10 clk = ~clk;

  // El mismo protocolo de resultado sirve para todos los IDs del catálogo.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  // Traduce nombres externos a la representación física fija, sin usar constantes del DUT.
  function automatic logic [13:0] state_mask(input string name);
    if (name == "NO_IMAGE") state_mask = 14'h0001;
    else if (name == "LOADING") state_mask = 14'h0002;
    else if (name == "PREPARING_READY") state_mask = 14'h0004;
    else if (name == "READY") state_mask = 14'h0008;
    else if (name == "RUNNING") state_mask = 14'h0010;
    else if (name == "STEPPING") state_mask = 14'h0020;
    else if (name == "HALT_DRAIN_AUTO") state_mask = 14'h0040;
    else if (name == "HALT_DRAIN_STEP") state_mask = 14'h0080;
    else if (name == "FAULT_DRAIN_AUTO") state_mask = 14'h0100;
    else if (name == "FAULT_DRAIN_STEP") state_mask = 14'h0200;
    else if (name == "FINISHED") state_mask = 14'h0400;
    else if (name == "FAULT") state_mask = 14'h0800;
    else if (name == "PREPARING_RUN") state_mask = 14'h1000;
    else if (name == "PREPARING_STEP") state_mask = 14'h2000;
    else begin
      $fatal(1, "Unknown manifest state: %s", name);
      state_mask = 14'h0000;
    end
  endfunction

  // Los casos existentes expresan flags como booleanos o enteros cero/uno.
  function automatic logic flag(input string path);
    longint signed value;
    begin
      if (data.get_type(path) == "boolean") begin
        flag = data.get_boolean(path);
      end else begin
        value = data.get_integer(path);
        if (value != 0 && value != 1) $fatal(1, "Invalid flag at %s", path);
        flag = (value == 1);
      end
    end
  endfunction

  // Cada paso reemplaza todas las entradas; no hereda pulsos del paso anterior.
  task automatic drive_inputs(input string path);
    reset               = flag({path, "/reset"});
    load_request        = flag({path, "/load_request"});
    run_request         = flag({path, "/run_request"});
    step_request        = flag({path, "/step_request"});
    load_ok             = flag({path, "/load_ok"});
    load_fail           = flag({path, "/load_fail"});
    prepare_done        = flag({path, "/prepare_done"});
    halt_confirm        = flag({path, "/halt_confirm"});
    fault_confirm       = flag({path, "/fault_confirm"});
    pipeline_empty_next = flag({path, "/pipeline_empty_next"});
  endtask

  // Exige un bit conocido y comprueba el encoder después de cada actualización registrada.
  task automatic check_state(input logic [13:0] expected_state);
    if (dut.global_state !== expected_state) begin
      fail($sformatf("state: expected %h, obtained %h", expected_state, dut.global_state));
    end
    if ((^dut.global_state) === 1'bx || dut.global_state == 14'd0 ||
        (dut.global_state & (dut.global_state - 14'd1)) != 14'd0) begin
      fail("state is not known one-hot");
    end
    if ((^global_state_code) === 1'bx || global_state_code > 8'd13 ||
        (14'd1 << global_state_code) !== expected_state) begin
      fail("state code differs from registered one-hot state");
    end
  endtask

  // Todas las expectativas de controles se leen del JSON, antes del flanco.
  task automatic check_outputs(input string path);
    if (command_accepted !== flag(
            {path, "/command_accepted"}
        ) || load_start !== flag(
            {path, "/load_start"}
        ) || cpu_cycle_fire !== flag(
            {path, "/cpu_cycle_fire"}
        ) || image_publish !== flag(
            {path, "/image_publish"}
        )) begin
      fail({path, ": Mealy controls differ from manifest"});
    end
    if (loader_active !== flag(
            {path, "/loader_active"}
        ) || prepare_active !== flag(
            {path, "/prepare_active"}
        ) || drain_mode !== flag(
            {path, "/drain_mode"}
        ) || load_available !== flag(
            {path, "/load_available"}
        ) || program_finished !== flag(
            {path, "/program_finished"}
        ) || fault_terminal !== flag(
            {path, "/fault_terminal"}
        )) begin
      fail({path, ": Moore controls differ from manifest"});
    end
    if (global_state_code !== data.get_integer({path, "/global_state_code"})) begin
      fail({path, ": current state code differs from manifest"});
    end
  endtask

  // El estado no cambia por entradas combinacionales; solo el flanco captura el destino.
  task automatic apply_and_check(input string inputs_at,  // Estímulo del flanco.
                                 input string expected_at  // Controles y destino esperados.
                                     );
    logic [13:0] state_before;
    begin
      state_before = dut.global_state;
      drive_inputs(inputs_at);
      #1;
      if (dut.global_state !== state_before) fail("state changed without a clock edge");
      check_outputs(expected_at);
      @(posedge clk);
      #1;
      check_state(state_mask(data.get_string({expected_at, "/next_state"})));
    end
  endtask

  initial begin
    data.load();
    @(posedge clk);
    #1;
    check_state(14'h0001);
    if (CHECK_SEQUENCE) begin
      if (data.get_size("/inputs/fsm_steps") != data.get_size("/expected/fsm_steps")) begin
        fail("sequence input and expectation lengths differ");
      end
      for (index = 0; index < data.get_size("/inputs/fsm_steps"); index = index + 1) begin
        input_path    = $sformatf("/inputs/fsm_steps/%0d", index);
        expected_path = $sformatf("/expected/fsm_steps/%0d", index);
        repetitions   = data.get_integer({input_path, "/clocks"});
        if (repetitions < 1) fail("sequence step has no clocks");
        for (repetition = 0; repetition < repetitions; repetition = repetition + 1) begin
          @(negedge clk);
          apply_and_check(input_path, expected_path);
        end
      end
    end else begin
      @(negedge clk);
      fixture_state = data.get_integer("/inputs/state_onehot");
      if (fixture_state !== state_mask(data.get_string("/inputs/state"))) begin
        fail("manifest state name and one-hot fixture disagree");
      end
      // Inyección exclusiva del banco; el producto conserva sus puertos funcionales.
      dut.global_state = fixture_state;
      #1;
      check_state(fixture_state);
      apply_and_check("/inputs", "/expected");
    end
    $display("PASS %s", data.case_id);
    $finish;
  end

  // Un bloqueo del DUT nunca se interpreta como aprobación del caso.
  initial begin
    #100000;
    fail("testbench timeout");
  end
endmodule
