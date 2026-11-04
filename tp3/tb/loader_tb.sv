`timescale 1ns / 1ps

// Comprueba ensamblado, prioridad y escritura síncrona; opcionalmente conecta el control real.
module loader_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_IMEM_CAPACITY_BYTES,
    parameter integer WITH_CONTROL = 0
);
  // Anchos de los puertos de carga para la capacidad bajo prueba.
  localparam integer IMAGE_SIZE_WIDTH   = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES);
  localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(IMEM_CAPACITY_BYTES);
  localparam integer WORD_INDEX_WIDTH   = system_pkg::word_index_width(IMEM_CAPACITY_BYTES);

  logic                            clk = 1'b0;
  logic                            reset = 1'b1;
  logic                            load_request = 1'b0;
  logic                            run_request = 1'b0;
  logic                            step_request = 1'b0;
  logic                            manual_load_start = 1'b0;
  logic                            manual_loader_active = 1'b0;
  logic                            load_start;
  logic                            loader_active;
  logic   [  IMAGE_SIZE_WIDTH-1:0] load_size_bytes = '0;
  logic   [  IMAGE_SIZE_WIDTH-1:0] load_bytes_remaining = '0;
  logic                            load_byte_valid = 1'b0;
  logic   [                   7:0] load_byte_data = 8'd0;
  logic   [BYTE_ADDRESS_WIDTH-1:0] load_byte_offset;
  logic                            load_last_byte = 1'b0;
  logic                            load_abort = 1'b0;
  logic                            prepare_init = 1'b0;
  logic                            prepare_done = 1'b0;
  logic   [  WORD_INDEX_WIDTH-1:0] imem_write_index;
  logic   [                  31:0] imem_write_data;
  logic                            imem_write_enable;
  logic                            load_ok;
  logic                            load_fail;
  logic   [  IMAGE_SIZE_WIDTH-1:0] pending_image_size_bytes;
  logic                            command_accepted;
  logic                            cpu_cycle_fire;
  logic                            prepare_active;
  logic   [                   7:0] global_state_code;
  logic   [  IMAGE_SIZE_WIDTH-1:0] loaded_image_size_bytes;
  logic                            image_valid;
  logic   [                  63:0] cycle_count;
  logic   [                  31:0] imem_fixture                [2];
  logic   [                  63:0] monitored_index             [2];
  logic   [                  23:0] partial_before;
  logic   [                  31:0] word_before                 [2];
  integer                          write_count = 0;
  integer                          writes_before;
  integer                          index;
  integer                          slot;
  string                           input_path;
  string                           expected_path;

  tp3_case_data data ();
  loader #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) dut (
      .clk                     (clk),
      .reset                   (reset),
      .loader_active           (loader_active),
      .load_start              (load_start),
      .load_size_bytes         (load_size_bytes),
      .load_byte_valid         (load_byte_valid),
      .load_byte_data          (load_byte_data),
      .load_byte_offset        (load_byte_offset),
      .load_last_byte          (load_last_byte),
      .load_abort              (load_abort),
      .imem_write_index        (imem_write_index),
      .imem_write_data         (imem_write_data),
      .imem_write_enable       (imem_write_enable),
      .load_ok                 (load_ok),
      .load_fail               (load_fail),
      .pending_image_size_bytes(pending_image_size_bytes)
  );

  // Modela la resta del Controller en ancho de tamaño, antes de reducir a dirección.
  assign load_byte_offset = load_size_bytes - load_bytes_remaining;

  if (WITH_CONTROL) begin : g_with_control
    execution_control #(
        .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
    ) control_inst (
        .clk                     (clk),
        .reset                   (reset),
        .load_request            (load_request),
        .run_request             (run_request),
        .step_request            (step_request),
        .load_ok                 (load_ok),
        .load_fail               (load_fail),
        .prepare_done            (prepare_done),
        .prepare_init            (prepare_init),
        .halt_confirm            (1'b0),
        .act_ex_fault            (1'b0),
        .act_id_fault            (1'b0),
        .ex_fault_cause          (3'd0),
        .idex_pc                 (32'd0),
        .id_fault_cause          (3'd0),
        .id_fault_pc             (32'd0),
        .ifid_next_valid         (1'b0),
        .idex_next_valid         (1'b0),
        .exmem_next_valid        (1'b0),
        .memwb_next_valid        (1'b0),
        .pending_image_size_bytes(pending_image_size_bytes),
        .command_accepted        (command_accepted),
        .load_start              (load_start),
        .cpu_cycle_fire          (cpu_cycle_fire),
        .loader_active           (loader_active),
        .prepare_active          (prepare_active),
        .drain_mode              (),
        .load_available          (),
        .program_finished        (),
        .fault_terminal          (),
        .global_state_code       (global_state_code),
        .loaded_image_size_bytes (loaded_image_size_bytes),
        .image_valid             (image_valid),
        .fault_cause             (),
        .fault_pc                (),
        .cycle_count             (cycle_count)
    );
  end else begin : g_unit
    assign load_start    = manual_load_start;
    assign loader_active = manual_loader_active;
  end

  always #10 clk = ~clk;

  // Informa una discrepancia y termina la simulación con error.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  // Lee enteros, booleanos o hexadecimales de 64 bits sin búsquedas repetidas.
  function automatic logic [63:0] number(input string path);
    integer        record_index;
    string         text_value;
    logic   [63:0] parsed;
    byte           extra;
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

  // Cada paso reemplaza valores comunes del fixture, sin heredar pulsos anteriores.
  function automatic logic [63:0] stimulus(input string path, input string name);
    integer record_index;
    string  candidate;
    string  selected_path;
    begin
      candidate     = {path, "/", name};
      selected_path = {"/inputs/loader_fixture/defaults/", name};
      for (
          record_index = 0; record_index < data.record_count; record_index = record_index + 1
      ) begin
        if (data.paths[record_index] == candidate) selected_path = candidate;
      end
      stimulus = number(selected_path);
    end
  endfunction

  // null deja sin observar el dato combinacional cuando no hay escritura autorizada.
  task automatic expect_number(input logic [63:0] actual, input string path);
    if (!data.is_null(path) && actual !== number(path)) begin
      fail($sformatf("%s: expected %h, obtained %h", path, number(path), actual));
    end
  endtask

  // Las dos ubicaciones observadas evitan reservar arrays del tamaño de la capacidad.
  always @(posedge clk) begin
    if (imem_write_enable === 1'b1) begin
      if (imem_write_index == monitored_index[0]) begin
        imem_fixture[0] <= imem_write_data;
      end else if (imem_write_index == monitored_index[1]) begin
        imem_fixture[1] <= imem_write_data;
      end else begin
        fail("write outside the monitored fixture locations");
      end
      write_count <= write_count + 1;
    end
  end

  // Presenta controles y la entrega actual antes del flanco funcional.
  task automatic drive(input string path);
    reset                = stimulus(path, "reset");
    load_request         = stimulus(path, "load_request");
    run_request          = stimulus(path, "run_request");
    step_request         = stimulus(path, "step_request");
    manual_load_start    = stimulus(path, "load_start");
    manual_loader_active = stimulus(path, "loader_active");
    load_size_bytes      = stimulus(path, "size");
    load_bytes_remaining = stimulus(path, "remaining");
    load_byte_valid      = stimulus(path, "valid");
    load_byte_data       = stimulus(path, "byte");
    load_last_byte       = stimulus(path, "last");
    load_abort           = stimulus(path, "abort");
    prepare_init         = stimulus(path, "prepare_init");
    prepare_done         = stimulus(path, "prepare_done");
  endtask

  // Compara buses preflanco, captura parcial, escritura síncrona y publicación posterior.
  task automatic apply_and_check(input string inputs_at, input string expected_at);
    begin
      partial_before = dut.g_valid_capacity.partial_word;
      word_before[0] = imem_fixture[0];
      word_before[1] = imem_fixture[1];
      writes_before  = write_count;
      drive(inputs_at);
      #1;
      if (dut.g_valid_capacity.partial_word !== partial_before || imem_fixture[0] !== word_before[0]
          || imem_fixture[1] !== word_before[1] || write_count != writes_before) begin
        fail("registered resources changed without a clock edge");
      end
      expect_number(load_start, {expected_at, "/start"});
      expect_number(loader_active, {expected_at, "/active"});
      expect_number(load_byte_offset, {expected_at, "/offset"});
      expect_number(imem_write_enable, {expected_at, "/write"});
      expect_number(imem_write_index, {expected_at, "/index"});
      expect_number(imem_write_data, {expected_at, "/data"});
      expect_number(load_ok, {expected_at, "/ok"});
      expect_number(load_fail, {expected_at, "/fail"});
      expect_number(pending_image_size_bytes, {expected_at, "/pending_size"});
      if (load_ok === 1'b1 && load_fail === 1'b1) fail("simultaneous success and abort");
      if (WITH_CONTROL) begin
        expect_number(command_accepted, {expected_at, "/accepted"});
        expect_number(cpu_cycle_fire, {expected_at, "/fire"});
        expect_number(prepare_active, {expected_at, "/prepare_active"});
      end
      @(posedge clk);
      #1;
      expect_number(dut.g_valid_capacity.partial_word, {expected_at, "/partial_after"});
      expect_number(write_count, {expected_at, "/writes_after"});
      for (slot = 0; slot < 2; slot = slot + 1) begin
        expect_number(imem_fixture[slot], $sformatf("%s/memory_after/%0d", expected_at, slot));
      end
      if (WITH_CONTROL) begin
        expect_number(global_state_code, {expected_at, "/state_after"});
        expect_number(loaded_image_size_bytes, {expected_at, "/size_after"});
        expect_number(image_valid, {expected_at, "/image_valid_after"});
        expect_number(cycle_count, {expected_at, "/cycles_after"});
      end
    end
  endtask

  initial begin
    data.load();
    expect_number(IMEM_CAPACITY_BYTES, "/inputs/loader_capacity");
    for (slot = 0; slot < 2; slot = slot + 1) begin
      imem_fixture[slot]    = number($sformatf("/inputs/loader_fixture/memory/%0d", slot));
      monitored_index[slot] = number($sformatf("/inputs/loader_fixture/indices/%0d", slot));
    end
    @(posedge clk);
    #1;
    @(negedge clk);
    // Residuo artificial exclusivo del banco; el producto no tiene puertos de prueba.
    dut.g_valid_capacity.partial_word = number("/inputs/loader_fixture/partial_word");
    if (data.get_size("/inputs/loader_steps") != data.get_size("/expected/loader_steps")) begin
      fail("input and expectation lengths differ");
    end
    for (index = 0; index < data.get_size("/inputs/loader_steps"); index = index + 1) begin
      input_path    = $sformatf("/inputs/loader_steps/%0d", index);
      expected_path = $sformatf("/expected/loader_steps/%0d", index);
      apply_and_check(input_path, expected_path);
      @(negedge clk);
    end
    $display("PASS %s", data.case_id);
    $finish;
  end

  // Un DUT bloqueado nunca se interpreta como aprobación.
  initial begin
    #100000;
    fail("testbench timeout");
  end
endmodule
