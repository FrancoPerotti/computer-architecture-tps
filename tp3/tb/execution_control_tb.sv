`timescale 1ns / 1ps

// Comprueba controles y recursos locales con estímulos y expectativas del catálogo.
module execution_control_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_IMEM_CAPACITY_BYTES
);
  // Ancho local de los tamaños, incluida la capacidad completa.
  localparam integer IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES);

  logic                          clk = 1'b0;
  logic                          reset = 1'b1;
  logic                          load_request = 1'b0;
  logic                          run_request = 1'b0;
  logic                          step_request = 1'b0;
  logic                          load_ok = 1'b0;
  logic                          load_fail = 1'b0;
  logic                          prepare_done = 1'b0;
  logic                          prepare_init = 1'b0;
  logic                          halt_confirm = 1'b0;
  logic                          act_ex_fault = 1'b0;
  logic                          act_id_fault = 1'b0;
  logic   [                 2:0] ex_fault_cause = 3'd0;
  logic   [                31:0] idex_pc = 32'd0;
  logic   [                 2:0] id_fault_cause = 3'd0;
  logic   [                31:0] id_fault_pc = 32'd0;
  logic                          ifid_next_valid = 1'b0;
  logic                          idex_next_valid = 1'b0;
  logic                          exmem_next_valid = 1'b0;
  logic                          memwb_next_valid = 1'b0;
  logic   [IMAGE_SIZE_WIDTH-1:0] pending_image_size_bytes = '0;
  logic                          command_accepted;
  logic                          load_start;
  logic                          cpu_cycle_fire;
  logic                          loader_active;
  logic                          prepare_active;
  logic                          drain_mode;
  logic                          load_available;
  logic                          program_finished;
  logic                          fault_terminal;
  logic   [                 7:0] global_state_code;
  logic   [IMAGE_SIZE_WIDTH-1:0] loaded_image_size_bytes;
  logic                          image_valid;
  logic   [                 2:0] fault_cause;
  logic   [                31:0] fault_pc;
  logic   [                63:0] cycle_count;
  integer                        index;
  integer                        repetition;
  integer                        repetitions;
  integer                        expected_repetition;
  string                         input_path;
  string                         expected_path;
  string                         drive_path;
  string                         controls_path;
  string                         fsm_source;

  tp3_case_data data ();
  execution_control #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) dut (
      .clk                     (clk),
      .reset                   (reset),
      .load_request            (load_request),
      .run_request             (run_request),
      .step_request            (step_request),
      .load_ok                 (load_ok),
      .load_fail               (load_fail),
      .prepare_done            (prepare_done),
      .prepare_init            (prepare_init),
      .halt_confirm            (halt_confirm),
      .act_ex_fault            (act_ex_fault),
      .act_id_fault            (act_id_fault),
      .ex_fault_cause          (ex_fault_cause),
      .idex_pc                 (idex_pc),
      .id_fault_cause          (id_fault_cause),
      .id_fault_pc             (id_fault_pc),
      .ifid_next_valid         (ifid_next_valid),
      .idex_next_valid         (idex_next_valid),
      .exmem_next_valid        (exmem_next_valid),
      .memwb_next_valid        (memwb_next_valid),
      .pending_image_size_bytes(pending_image_size_bytes),
      .command_accepted        (command_accepted),
      .load_start              (load_start),
      .cpu_cycle_fire          (cpu_cycle_fire),
      .loader_active           (loader_active),
      .prepare_active          (prepare_active),
      .drain_mode              (drain_mode),
      .load_available          (load_available),
      .program_finished        (program_finished),
      .fault_terminal          (fault_terminal),
      .global_state_code       (global_state_code),
      .loaded_image_size_bytes (loaded_image_size_bytes),
      .image_valid             (image_valid),
      .fault_cause             (fault_cause),
      .fault_pc                (fault_pc),
      .cycle_count             (cycle_count)
  );

  always #10 clk = ~clk;

  // Informa el caso y termina con error ante una discrepancia.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  // Admite enteros, booleanos y hexadecimales de hasta 64 bits, sin signo.
  function automatic logic [63:0] number(input string path);
    string         text_value;
    logic   [63:0] parsed;
    byte           extra;
    integer        record_index;
    begin
      record_index = data.find(path);
      text_value   = data.texts[record_index];
      if (data.kinds[record_index] == "boolean") begin
        number = text_value == "true" ? 64'd1 : 64'd0;
      end else if (data.kinds[record_index] == "integer") begin
        number = data.parse_integer(text_value);
      end else begin
        if (text_value.len() < 3 || text_value.substr(0, 1) != "0x") begin
          $fatal(1, "Expected hexadecimal at %s", path);
        end
        text_value = text_value.substr(2, text_value.len() - 1);
        if ($sscanf(text_value, "%h%c", parsed, extra) != 1) begin
          $fatal(1, "Invalid hexadecimal at %s", path);
        end
        number = parsed;
      end
    end
  endfunction

  // Reutiliza el valor común del fixture salvo que el paso lo reemplace explícitamente.
  function automatic string resource_path(input string path, input string name);
    integer record_index;
    string  candidate;
    begin
      candidate     = {path, "/", name};
      resource_path = {"/inputs/control_fixture/resource_defaults/", name};
      for (
          record_index = 0; record_index < data.record_count; record_index = record_index + 1
      ) begin
        if (data.paths[record_index] == candidate) resource_path = candidate;
      end
    end
  endfunction

  // null indica metadata todavía no capturada, cuyo residuo carece de significado.
  task automatic expect_number(input logic [63:0] actual, input string path);
    if (!data.is_null(path) && actual !== number(path)) begin
      fail($sformatf("%s: expected %h, obtained %h", path, number(path), actual));
    end
  endtask

  // Cada paso define todas las entradas; no quedan pulsos del paso anterior.
  task automatic drive(input string path);
    reset                    = number({path, "/reset"});
    load_request             = number({path, "/load_request"});
    run_request              = number({path, "/run_request"});
    step_request             = number({path, "/step_request"});
    load_ok                  = number({path, "/load_ok"});
    load_fail                = number({path, "/load_fail"});
    prepare_done             = number({path, "/prepare_done"});
    prepare_init             = number(resource_path(input_path, "prepare_init"));
    halt_confirm             = number({path, "/halt_confirm"});
    act_ex_fault             = number(resource_path(input_path, "act_ex_fault"));
    act_id_fault             = number(resource_path(input_path, "act_id_fault"));
    ex_fault_cause           = number(resource_path(input_path, "ex_fault_cause"));
    idex_pc                  = number(resource_path(input_path, "idex_pc"));
    id_fault_cause           = number(resource_path(input_path, "id_fault_cause"));
    id_fault_pc              = number(resource_path(input_path, "id_fault_pc"));
    ifid_next_valid          = number(resource_path(input_path, "ifid_next_valid"));
    idex_next_valid          = number(resource_path(input_path, "idex_next_valid"));
    exmem_next_valid         = number(resource_path(input_path, "exmem_next_valid"));
    memwb_next_valid         = number(resource_path(input_path, "memwb_next_valid"));
    pending_image_size_bytes = number(resource_path(input_path, "pending_image_size_bytes"));
    if (repetition > 0 && number(resource_path(input_path, "prepare_init_first_clock"))) begin
      prepare_init = 1'b0;
    end
    if (!data.is_null(resource_path(input_path, "counter_fire_override"))) begin
      // Solo los fixtures del contador presentan fire frente a reset/preparación.
      if (number(resource_path(input_path, "counter_fire_override")) == 64'd1) begin
        force dut.g_valid_capacity.global_fsm_inst.authorization_controls = 4'b0_0_1_0;
      end else begin
        force dut.g_valid_capacity.global_fsm_inst.authorization_controls = 4'b0_0_0_0;
      end
    end
  endtask

  // Comprueba la frontera combinacional antes de capturar el flanco.
  task automatic check_controls(input string path);
    expect_number(command_accepted, {path, "/command_accepted"});
    expect_number(load_start, {path, "/load_start"});
    expect_number(cpu_cycle_fire, {path, "/cpu_cycle_fire"});
    expect_number(loader_active, {path, "/loader_active"});
    expect_number(prepare_active, {path, "/prepare_active"});
    expect_number(drain_mode, {path, "/drain_mode"});
    expect_number(load_available, {path, "/load_available"});
    expect_number(program_finished, {path, "/program_finished"});
    expect_number(fault_terminal, {path, "/fault_terminal"});
    expect_number(global_state_code, {path, "/global_state_code"});
  endtask

  // Comprueba registros y la representación one-hot después del flanco.
  task automatic check_resources(input string path);
    logic [13:0] state_value;
    begin
      expect_number(global_state_code, {path, "/global_state_code"});
      expect_number(loaded_image_size_bytes, {path, "/loaded_image_size_bytes"});
      expect_number(image_valid, {path, "/image_valid"});
      expect_number(cycle_count, {path, "/cycle_count"});
      expect_number(fault_cause, {path, "/fault_cause"});
      expect_number(fault_pc, {path, "/fault_pc"});
      state_value = dut.g_valid_capacity.global_fsm_inst.global_state;
      if ((^state_value) === 1'bx || state_value == 14'd0 || (state_value & (state_value - 14'd1))
          != 14'd0 || (14'd1 << global_state_code) !== state_value) begin
        fail("registered state is not known one-hot or its code differs");
      end
    end
  endtask

  // Las inyecciones son exclusivas del banco y están declaradas en cada fixture.
  task automatic install_fixture;
    if (!data.is_null("/inputs/control_fixture/state_onehot")) begin
      dut.g_valid_capacity.global_fsm_inst.global_state =
          number("/inputs/control_fixture/state_onehot");
    end
    if (!data.is_null("/inputs/control_fixture/cycle_count")) begin
      dut.cycle_count = number("/inputs/control_fixture/cycle_count");
    end
    if (!data.is_null("/inputs/control_fixture/loaded_image_size_bytes")) begin
      dut.loaded_image_size_bytes = number("/inputs/control_fixture/loaded_image_size_bytes");
    end
    if (!data.is_null("/inputs/control_fixture/fault_cause")) begin
      dut.fault_cause = number("/inputs/control_fixture/fault_cause");
      dut.fault_pc    = number("/inputs/control_fixture/fault_pc");
    end
  endtask

  initial begin
    data.load();
    fsm_source = data.get_string("/inputs/control_fixture/fsm_source");
    expect_number(IMEM_CAPACITY_BYTES, "/inputs/control_fixture/imem_capacity_bytes");
    @(posedge clk);
    #1;
    if (global_state_code !== 8'd0 || loaded_image_size_bytes !== '0 || cycle_count !== 64'd0 ||
        image_valid !== 1'b0) begin
      fail("synchronous reset did not clear state, image and counter");
    end
    @(negedge clk);
    install_fixture();
    if (data.get_size("/inputs/control_steps") != data.get_size("/expected/control_steps")) begin
      fail("input and expectation lengths differ");
    end
    for (index = 0; index < data.get_size("/inputs/control_steps"); index = index + 1) begin
      input_path    = $sformatf("/inputs/control_steps/%0d", index);
      expected_path = $sformatf("/expected/control_steps/%0d", index);
      if (fsm_source == "vector") begin
        drive_path    = "/inputs";
        controls_path = "/expected";
        repetitions   = 1;
      end else if (fsm_source == "sequence") begin
        drive_path    = $sformatf("/inputs/fsm_steps/%0d", index);
        controls_path = $sformatf("/expected/fsm_steps/%0d", index);
        repetitions   = number({drive_path, "/clocks"});
      end else if (fsm_source == "custom") begin
        drive_path    = input_path;
        controls_path = {expected_path, "/before"};
        repetitions   = number({drive_path, "/clocks"});
      end else begin
        fail("unknown stimulus source");
      end
      if (repetitions < 1) fail("step has no clocks");
      if (data.get_size(
              {expected_path, "/after"}
          ) != 1 && data.get_size(
              {expected_path, "/after"}
          ) != repetitions) begin
        fail("missing per-clock resource expectations");
      end
      for (repetition = 0; repetition < repetitions; repetition = repetition + 1) begin
        drive(drive_path);
        #1;
        check_controls(controls_path);
        @(posedge clk);
        #1;
        expected_repetition = data.get_size({expected_path, "/after"}) == 1 ? 0 : repetition;
        check_resources($sformatf("%s/after/%0d", expected_path, expected_repetition));
        if (!data.is_null(resource_path(input_path, "counter_fire_override"))) begin
          release dut.g_valid_capacity.global_fsm_inst.authorization_controls;
        end
        @(negedge clk);
      end
    end
    $display("PASS %s", data.case_id);
    $finish;
  end

  // Un timeout nunca acredita el caso.
  initial begin
    #100000;
    fail("testbench timeout");
  end
endmodule
