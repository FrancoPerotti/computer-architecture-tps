`timescale 1ns / 1ps

// Integra la sesión real; CPU, memorias y transporte son fixtures, sin ejecutar ISA.
module session_lifecycle_tb;
  localparam integer CAPACITY = system_pkg::REFERENCE_DMEM_CAPACITY_BYTES;
  logic                  clk = 1'b0;
  logic                  reset = 1'b1;
  logic                  load_request = 1'b0;
  logic                  run_request = 1'b0;
  logic                  step_request = 1'b0;
  logic                  halt_confirm = 1'b0;
  logic                  act_id_fault = 1'b0;
  logic   [         2:0] id_cause = 3'd0;
  logic   [        31:0] id_pc = 32'd0;
  logic                  command_accepted;
  logic                  load_start;
  logic                  loader_active;
  logic                  prepare_active;
  logic                  prepare_init;
  logic                  prepare_clear;
  logic   [        10:0] prepare_addr;
  logic                  prepare_done;
  logic                  cpu_cycle_fire;
  logic   [         7:0] state_code;
  logic   [        10:0] load_size = 11'd0;
  logic   [        10:0] confirmed_size;
  logic   [        10:0] remaining = 11'd0;
  logic   [         9:0] byte_offset;
  logic                  byte_valid = 1'b0;
  logic   [         7:0] byte_data = 8'd0;
  logic                  last_byte = 1'b0;
  logic                  load_abort = 1'b0;
  logic   [         7:0] imem_write_index;
  logic   [        31:0] imem_write_data;
  logic                  imem_write_enable;
  logic                  load_ok;
  logic                  load_fail;
  logic   [        10:0] pending_size;
  logic                  image_valid;
  logic   [        63:0] cycle_count;
  logic   [         2:0] fault_cause;
  logic   [        31:0] fault_pc;
  logic   [         3:0] next_valid = 4'b0001;
  logic                  stall_fixture = 1'b0;
  logic                  seed_fixture = 1'b0;
  logic   [        31:0] pc = 32'd0;
  logic   [        31:0] registers            [      32];
  logic   [CAPACITY-1:0] dmem_valid = '0;
  logic   [         7:0] dmem_physical        [CAPACITY];
  logic   [        31:0] imem_fixture         [       8];
  logic   [        31:0] load_words           [       8];
  integer                operation_index;
  string                 input_path;
  string                 expected_path;
  string                 operation;

  tp3_case_data data ();
  session_preparation dut (
      .clk               (clk),
      .reset             (reset),
      .prepare_active    (prepare_active),
      .prepare_init      (prepare_init),
      .prepare_dmem_clear(prepare_clear),
      .prepare_dmem_addr (prepare_addr),
      .prepare_done      (prepare_done)
  );
  assign byte_offset = load_size - remaining;
  execution_control control_inst (
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
      .act_ex_fault            (1'b0),
      .act_id_fault            (act_id_fault),
      .ex_fault_cause          (3'd0),
      .idex_pc                 (32'd0),
      .id_fault_cause          (id_cause),
      .id_fault_pc             (id_pc),
      .ifid_next_valid         (next_valid[0]),
      .idex_next_valid         (next_valid[1]),
      .exmem_next_valid        (next_valid[2]),
      .memwb_next_valid        (next_valid[3]),
      .pending_image_size_bytes(pending_size),
      .command_accepted        (command_accepted),
      .load_start              (load_start),
      .cpu_cycle_fire          (cpu_cycle_fire),
      .loader_active           (loader_active),
      .prepare_active          (prepare_active),
      .drain_mode              (),
      .load_available          (),
      .program_finished        (),
      .fault_terminal          (),
      .global_state_code       (state_code),
      .loaded_image_size_bytes (confirmed_size),
      .image_valid             (image_valid),
      .fault_cause             (fault_cause),
      .fault_pc                (fault_pc),
      .cycle_count             (cycle_count)
  );
  loader loader_inst (
      .clk                     (clk),
      .reset                   (reset),
      .loader_active           (loader_active),
      .load_start              (load_start),
      .load_size_bytes         (load_size),
      .load_byte_valid         (byte_valid),
      .load_byte_data          (byte_data),
      .load_byte_offset        (byte_offset),
      .load_last_byte          (last_byte),
      .load_abort              (load_abort),
      .imem_write_index        (imem_write_index),
      .imem_write_data         (imem_write_data),
      .imem_write_enable       (imem_write_enable),
      .load_ok                 (load_ok),
      .load_fail               (load_fail),
      .pending_image_size_bytes(pending_size)
  );

  always #10 clk = ~clk;

  // Los consumidores solo modelan enables y residuos observables, no instrucciones.
  always @(posedge clk) begin
    if (reset || prepare_init) begin
      pc <= 32'd0;
      for (integer index = 0; index < 32; index = index + 1) registers[index] <= 32'd0;
    end else if (cpu_cycle_fire && !stall_fixture) begin
      pc <= pc + 32'd4;
    end
    if (prepare_clear) dmem_valid[prepare_addr] <= 1'b0;
    if (seed_fixture) begin
      registers[1]     <= 32'd7;
      registers[2]     <= 32'd9;
      dmem_valid       <= {{(CAPACITY - 4) {1'b0}}, 4'b1111};
      dmem_physical[0] <= 8'd7;
      for (integer index = 1; index < 4; index = index + 1) dmem_physical[index] <= 8'd0;
    end
    if (imem_write_enable) begin
      if (imem_write_index >= 8) $fatal(1, "Write outside fixture IMEM");
      imem_fixture[imem_write_index] <= imem_write_data;
    end
  end

  task automatic fail(input string reason);
    $display("FAIL %s operation=%0d %s", data.case_id, operation_index, reason);
    $fatal(1, "%s", reason);
  endtask

  function automatic logic [63:0] number(input string path);
    integer        record_index;
    string         text_value;
    logic   [63:0] parsed;
    byte           extra;
    begin
      record_index = data.find(path);
      text_value   = data.texts[record_index];
      if (data.kinds[record_index] == "integer") number = data.parse_integer(text_value);
      else begin
        if (text_value.len() < 3 || text_value.substr(0, 1) != "0x") $fatal(1, "Expected hex");
        text_value = text_value.substr(2, text_value.len() - 1);
        if ($sscanf(text_value, "%h%c", parsed, extra) != 1) $fatal(1, "Invalid hex");
        number = parsed;
      end
    end
  endfunction

  // Todas las operaciones entran y salen en negedge, lejos de la captura del DUT.
  task automatic tick;
    @(posedge clk);
    #1;
    @(negedge clk);
  endtask

  // El reloj físico sigue activo durante HOLD y ante una petición rechazada.
  task automatic hold_clocks(input integer clocks);
    logic [63:0] count_before;
    logic [31:0] pc_before;
    begin
      count_before = cycle_count;
      pc_before    = pc;
      repeat (clocks) begin
        #1;
        if (cpu_cycle_fire || command_accepted || load_start || imem_write_enable)
          fail("unexpected authorization during HOLD/rejection");
        tick();
        if (cycle_count !== count_before || pc !== pc_before) fail("HOLD advanced CPU fixture");
      end
    end
  endtask

  // El fixture asume tamaño ya validado y entrega progreso; Loader conserva sus bytes.
  task automatic load_image;
    integer        size;
    integer        received;
    logic   [31:0] word_value;
    begin
      size     = number({input_path, "/size"});
      received = number({input_path, "/received"});
      for (
          integer word_index = 0;
          word_index < data.get_size({input_path, "/words"});
          word_index = word_index + 1
      ) begin
        load_words[word_index] = number($sformatf("%s/words/%0d", input_path, word_index));
      end
      load_size    = 11'(size);
      load_request = 1'b1;
      #1;
      if (!load_start || !command_accepted || cpu_cycle_fire) fail("LOAD not accepted alone");
      tick();
      load_request = 1'b0;
      if (confirmed_size !== 0 || image_valid) fail("old image survived LOAD acceptance");
      for (integer offset = 0; offset < received; offset = offset + 1) begin
        remaining  = 11'(size - offset);
        word_value = load_words[offset/4];
        byte_data  = 8'(word_value >> (8 * (offset % 4)));
        byte_valid = 1'b1;
        last_byte  = (offset == size - 1);
        #1;
        if (imem_write_enable !== (offset % 4 == 3) || load_ok !== last_byte || cpu_cycle_fire)
          fail("bad load word boundary");
        if (imem_write_enable &&
            (imem_write_index !== 8'(offset / 4) || imem_write_data !== word_value))
          fail("wrong word assembled by Loader");
        tick();
        if (confirmed_size !== 0 || image_valid) fail("published before preparation");
      end
      byte_valid = 1'b0;
      last_byte  = 1'b0;
      if (data.get_boolean({input_path, "/abort"})) begin
        load_abort = 1'b1;
        #1;
        if (!load_fail || imem_write_enable || load_ok) fail("bad abort controls");
        tick();
        load_abort = 1'b0;
      end
    end
  endtask

  // Exige todos los clears antes del flanco que publica la imagen.
  task automatic prepare_image;
    begin
      for (integer address = 0; address < CAPACITY; address = address + 1) begin
        #1;
        if (!prepare_active || !prepare_clear || prepare_addr !== 11'(address) || prepare_init !==
            (address == 0) || prepare_done || cpu_cycle_fire || imem_write_enable || image_valid)
          fail("bad preparation boundary or early publication");
        tick();
        if (cycle_count !== 0 || pc !== 0) fail("preparation advanced CPU/count");
        for (integer index = 0; index < 32; index = index + 1) begin
          if (registers[index] !== 0) fail("RF not initialized");
        end
      end
      #1;
      if (!prepare_done || prepare_clear || prepare_init || cpu_cycle_fire || dmem_valid !== '0)
        fail("preparation did not finish before first CPU cycle");
      tick();
    end
  endtask

  // Un stall del PC modelado consume igualmente una autorización y una cuenta reales.
  task automatic cpu_cycles;
    integer        cycles;
    integer        hold_count;
    integer        stall_at;
    string         mode;
    logic   [63:0] count_before;
    logic   [31:0] pc_before;
    begin
      cycles     = number({input_path, "/cycles"});
      hold_count = number({input_path, "/hold_clocks"});
      stall_at   = number({input_path, "/stall_at"});
      mode       = data.get_string({input_path, "/mode"});
      for (integer cycle_index = 0; cycle_index < cycles; cycle_index = cycle_index + 1) begin
        step_request  = (mode == "STEP");
        run_request   = (mode == "RUN" && state_code == 8'd3);
        stall_fixture = (cycle_index == stall_at);
        count_before  = cycle_count;
        pc_before     = pc;
        #1;
        if (!cpu_cycle_fire || imem_write_enable || prepare_clear ||
            command_accepted !== (step_request || run_request))
          fail("wrong cycle authorization");
        tick();
        if (cycle_count !== count_before + 1) fail("authorized cycle not counted once");
        if (stall_fixture && pc !== pc_before) fail("stall fixture did not hold PC");
        run_request   = 1'b0;
        step_request  = 1'b0;
        stall_fixture = 1'b0;
        hold_clocks(hold_count);
      end
    end
  endtask

  // Sustituye al productor de resultados de CPU por una confirmación explícita.
  task automatic terminal_cycle;
    string mode;
    string result;
    begin
      mode         = data.get_string({input_path, "/mode"});
      result       = data.get_string({input_path, "/result"});
      step_request = (mode == "STEP");
      halt_confirm = (result == "halt");
      act_id_fault = !halt_confirm;
      id_cause     = 3'(number({input_path, "/cause"}));
      id_pc        = 32'(number({input_path, "/fault_pc"}));
      next_valid   = 4'b0000;
      #1;
      if (!cpu_cycle_fire) fail("terminal result has no authorized cycle");
      tick();
      step_request = 1'b0;
      halt_confirm = 1'b0;
      act_id_fault = 1'b0;
      next_valid   = 4'b0001;
      if (result == "fault" && (fault_cause !== id_cause || fault_pc !== id_pc))
        fail("lost confirmed fault metadata");
      hold_clocks(3);
    end
  endtask

  task automatic check_number(input string field, input logic [63:0] actual);
    logic [63:0] expected_value;
    begin
      expected_value = number({expected_path, "/", field});
      if (actual !== expected_value) begin
        $display("%s: got %0d expected %0d", field, actual, expected_value);
        fail("unexpected session resource");
      end
    end
  endtask

  task automatic check_result;
    begin
      check_number("state", 64'(state_code));
      check_number("size", 64'(confirmed_size));
      check_number("count", cycle_count);
      check_number("pc", 64'(pc));
      check_number("rf1", 64'(registers[1]));
      check_number("rf2", 64'(registers[2]));
      if (dmem_valid !== CAPACITY'(number({expected_path, "/bitmap"})))
        fail("unexpected DMEM validity marks");
      for (
          integer index = 0; index < data.get_size({expected_path, "/imem"}); index = index + 1
      ) begin
        if (imem_fixture[index] !== 32'(number($sformatf("%s/imem/%0d", expected_path, index))))
          fail("IMEM changed outside loaded prefix");
      end
      if (image_valid !== (confirmed_size != 0)) fail("inconsistent image validity");
      if (data.get_boolean(
              {expected_path, "/physical_word_preserved"}
          ) && {dmem_physical[3], dmem_physical[2], dmem_physical[1], dmem_physical[0]} !== 32'd7)
        fail("preparation erased physical DMEM instead of marks");
    end
  endtask

  initial begin
    data.load();
    for (integer index = 0; index < 8; index = index + 1) imem_fixture[index] = 32'd0;
    for (integer index = 0; index < CAPACITY; index = index + 1) dmem_physical[index] = 8'hA5;
    tick();
    reset = 1'b0;
    for (
        operation_index = 0;
        operation_index < data.get_size("/inputs/session_steps");
        operation_index = operation_index + 1
    ) begin
      input_path    = $sformatf("/inputs/session_steps/%0d", operation_index);
      expected_path = $sformatf("/expected/session_steps/%0d", operation_index);
      operation     = data.get_string({input_path, "/op"});
      if (operation == "load") load_image();
      else if (operation == "prepare") prepare_image();
      else if (operation == "cpu") cpu_cycles();
      else if (operation == "terminal") terminal_cycle();
      else if (operation == "hold" || operation == "reject") begin
        hold_clocks(integer'(number({input_path, "/clocks"})));
      end else if (operation == "dirty") begin
        seed_fixture = 1'b1;
        tick();
        seed_fixture = 1'b0;
      end else if (operation == "no_image_requests") begin
        run_request  = 1'b1;
        step_request = 1'b1;
        hold_clocks(integer'(number({input_path, "/clocks"})));
        run_request  = 1'b0;
        step_request = 1'b0;
      end else if (operation == "reset") begin
        reset = 1'b1;
        #1;
        if (cpu_cycle_fire || command_accepted || load_start || imem_write_enable || prepare_clear)
          fail("reset did not suppress side effects");
        tick();
        reset = 1'b0;
      end else fail("unknown operation");
      #1;
      check_result();
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
