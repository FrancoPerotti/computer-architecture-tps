`timescale 1ns / 1ps

// Comprueba preparación con recursos modelados y conexión opcional al control de sesión real.
module session_preparation_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_DMEM_CAPACITY_BYTES,
    parameter integer WITH_CONTROL = 0
);
  // Dimensiones del fixture DMEM y de su bus de mantenimiento.
  localparam integer CAPACITY           = DMEM_CAPACITY_BYTES;
  localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES);

  logic                            clk = 1'b0;
  logic                            reset = 1'b1;
  logic                            manual_active = 1'b0;
  logic                            prepare_active;
  logic                            control_prepare_active;
  logic                            prepare_init;
  logic                            prepare_clear;
  logic   [BYTE_ADDRESS_WIDTH-1:0] prepare_addr;
  logic                            prepare_done;
  logic                            load_request = 1'b0;
  logic                            run_request = 1'b0;
  logic                            step_request = 1'b0;
  logic                            halt_confirm = 1'b0;
  logic                            act_id_fault = 1'b0;
  logic                            command_accepted;
  logic                            load_start;
  logic                            loader_active;
  logic                            cpu_cycle_fire;
  logic   [                   7:0] state_code;
  logic   [                  10:0] load_size = 11'd16;
  logic   [                  10:0] remaining = 11'd16;
  logic   [                   9:0] byte_offset;
  logic                            byte_valid = 1'b0;
  logic   [                   7:0] byte_data = 8'd0;
  logic                            last_byte = 1'b0;
  logic   [                   7:0] load_bytes             [      16];
  logic   [                   7:0] dmem_physical          [CAPACITY];
  logic   [          CAPACITY-1:0] dmem_valid;
  logic   [                  31:0] registers              [      32];
  logic   [                  31:0] imem_fixture           [       4];
  logic   [                  31:0] expected_imem          [       4];
  logic   [                  31:0] pc;
  logic   [                   3:0] pipeline_valid;
  logic                            fetch_fault_valid;
  logic   [                   3:0] next_valid;
  logic   [                  31:0] fetched_pc;
  logic   [                  31:0] fetched_instruction;
  logic   [                  63:0] cycle_count;
  logic   [                  10:0] confirmed_size;
  logic                            image_valid;
  logic   [                   7:0] imem_write_index;
  logic   [                  31:0] imem_write_data;
  logic                            imem_write_enable;
  logic                            load_ok;
  logic                            load_fail;
  logic   [                  10:0] pending_size;
  integer                          address;
  integer                          register_index;
  integer                          word_index;
  integer                          clear_count;
  integer                          physical_modulus;
  integer                          expected_clears;
  integer                          expected_clocks;
  integer                          reset_after;
  logic   [                  31:0] dirty_register;
  logic   [                  31:0] dirty_pc;
  logic   [                  63:0] dirty_count;
  logic   [                  13:0] entry_state;
  string                           entry_kind;
  string                           finish_path;
  string                           terminal_kind;

  tp3_case_data data ();
  session_preparation #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk               (clk),
      .reset             (reset),
      .prepare_active    (prepare_active),
      .prepare_init      (prepare_init),
      .prepare_dmem_clear(prepare_clear),
      .prepare_dmem_addr (prepare_addr),
      .prepare_done      (prepare_done)
  );
  assign prepare_active = WITH_CONTROL ? control_prepare_active : manual_active;
  assign byte_offset = load_size - remaining;
  assign next_valid = (prepare_init || halt_confirm || act_id_fault) ? 4'b0000 :
      cpu_cycle_fire ? 4'b0001 : pipeline_valid;

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
      .id_fault_cause          (3'd2),
      .id_fault_pc             (32'd12),
      .ifid_next_valid         (next_valid[0]),
      .idex_next_valid         (next_valid[1]),
      .exmem_next_valid        (next_valid[2]),
      .memwb_next_valid        (next_valid[3]),
      .pending_image_size_bytes(pending_size),
      .command_accepted        (command_accepted),
      .load_start              (load_start),
      .cpu_cycle_fire          (cpu_cycle_fire),
      .loader_active           (loader_active),
      .prepare_active          (control_prepare_active),
      .drain_mode              (),
      .load_available          (),
      .program_finished        (),
      .fault_terminal          (),
      .global_state_code       (state_code),
      .loaded_image_size_bytes (confirmed_size),
      .image_valid             (image_valid),
      .fault_cause             (),
      .fault_pc                (),
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
      .load_abort              (1'b0),
      .imem_write_index        (imem_write_index),
      .imem_write_data         (imem_write_data),
      .imem_write_enable       (imem_write_enable),
      .load_ok                 (load_ok),
      .load_fail               (load_fail),
      .pending_image_size_bytes(pending_size)
  );

  always #10 clk = ~clk;

  // Cada consumidor aplica las órdenes al mismo flanco; no hay lógica de CPU real.
  always @(posedge clk) begin
    if (reset || prepare_init) begin
      pc                <= 32'd0;
      pipeline_valid    <= 4'b0000;
      fetch_fault_valid <= 1'b0;
      for (integer index = 0; index < 32; index = index + 1) registers[index] <= 32'd0;
    end else if (cpu_cycle_fire) begin
      fetched_pc <= pc;
      if (pc < 32'd16) fetched_instruction <= imem_fixture[pc>>2];
      pc             <= pc + 32'd4;
      pipeline_valid <= next_valid;
    end
    if (prepare_clear) dmem_valid[prepare_addr] <= 1'b0;
    if (imem_write_enable) begin
      if (imem_write_index >= 8'd4) $fatal(1, "Write outside fixture IMEM");
      imem_fixture[imem_write_index] <= imem_write_data;
    end
  end

  // Informa el ID y termina con error ante una discrepancia.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  // Lee números del catálogo con una única búsqueda de ruta.
  function automatic logic [63:0] number(input string path);
    integer        record_index;
    string         text_value;
    logic   [63:0] parsed;
    byte           extra;
    begin
      record_index = data.find(path);
      text_value   = data.texts[record_index];
      if (data.kinds[record_index] == "boolean") number = text_value == "true" ? 64'd1 : 64'd0;
      else if (data.kinds[record_index] == "integer") number = data.parse_integer(text_value);
      else begin
        if (text_value.len() < 3 || text_value.substr(0, 1) != "0x") $fatal(1, "Expected hex");
        text_value = text_value.substr(2, text_value.len() - 1);
        if ($sscanf(text_value, "%h%c", parsed, extra) != 1) $fatal(1, "Invalid hex");
        number = parsed;
      end
    end
  endfunction

  // Consume un flanco y devuelve el control después de las capturas registradas.
  task automatic tick;
    @(posedge clk);
    #1;
  endtask

  // Instala residuos observables, sin modificar el índice de preparación.
  task automatic dirty_resources;
    pc                       = dirty_pc;
    pipeline_valid           = 4'b1111;
    fetch_fault_valid        = 1'b1;
    control_inst.cycle_count = dirty_count;
    registers[0]             = 32'd0;
    for (register_index = 1; register_index < 32; register_index = register_index + 1) begin
      registers[register_index] = dirty_register;
    end
    dmem_valid = '1;
  endtask

  // Comprueba inicialización simultánea, también cuando DMEM tiene menos de 32 bytes.
  task automatic check_initialized;
    if (pc !== 32'd0 || cycle_count !== 64'd0 || pipeline_valid !== 4'b0000 ||
        fetch_fault_valid !== 1'b0)
      fail("CPU fixture not initialized on first clear");
    for (register_index = 0; register_index < 32; register_index = register_index + 1) begin
      if (registers[register_index] !== 32'd0) fail("RF not initialized simultaneously");
    end
  endtask

  // Las memorias físicas se conservan; el cero lógico depende de sus marcas.
  task automatic check_memory;
    if (dmem_valid !== '0) fail("DMEM still has valid bytes");
    for (address = 0; address < CAPACITY; address = address + 1) begin
      if (dmem_physical[address] !== 8'(address % physical_modulus)) fail("DMEM data changed");
    end
    for (word_index = 0; word_index < 4; word_index = word_index + 1) begin
      if (imem_fixture[word_index] !== expected_imem[word_index])
        fail("IMEM changed during preparation");
    end
  endtask

  // Recorre el rango esperado y consume done en un flanco sin mantenimiento.
  task automatic complete_service(input string destination);
    integer expected_state;
    integer expected_count;
    integer expected_publish;
    integer expected_fire;
    integer follow;
    integer completion_edges;
    begin
      clear_count      = 0;
      completion_edges = 0;
      for (
          integer next_address = 0; next_address < expected_clears; next_address = next_address + 1
      ) begin
        #1;
        if (prepare_clear !== 1'b1 || prepare_done !== 1'b0 || prepare_addr !==
            BYTE_ADDRESS_WIDTH'(next_address) || prepare_init !== (next_address == 0) ||
            cpu_cycle_fire !== 1'b0 || imem_write_enable !== 1'b0)
          fail("wrong clear address, init or exclusion");
        if (dut.g_valid_capacity.prepare_index !== next_address) fail("wrong registered index");
        tick();
        completion_edges = completion_edges + 1;
        clear_count      = clear_count + 1;
        if (dmem_valid[next_address] !== 1'b0) fail("selected mark not cleared");
        if (next_address + 1 < expected_clears && dmem_valid[next_address+1] !== 1'b1) begin
          fail("future mark cleared early");
        end
        check_initialized();
        @(negedge clk);
      end
      if (prepare_done !== 1'b1 || prepare_init !== 1'b0 || prepare_clear !== 1'b0 ||
          dut.g_valid_capacity.prepare_index !== expected_clears)
        fail("last clear not separated from done");
      check_memory();
      if (WITH_CONTROL) begin
        expected_state   = number({destination, "/state"});
        expected_count   = number({destination, "/count"});
        expected_publish = number({destination, "/publish"});
        expected_fire    = number({destination, "/fire"});
        if (cpu_cycle_fire !== 1'(expected_fire) || command_accepted !== 1'b0 || load_start !==
            1'b0 || control_inst.g_valid_capacity.image_publish !== 1'(expected_publish)) begin
          fail("completion controls differ from catalog");
        end
      end
      tick();
      completion_edges = completion_edges + 1;
      if (completion_edges != expected_clocks || clear_count != expected_clears)
        fail("wrong duration");
      if (WITH_CONTROL) begin
        if (state_code !== 8'(expected_state) || cycle_count !== 64'(expected_count) ||
            confirmed_size !== 11'(number(
                {destination, "/size"}
            )) || image_valid !== 1'b1) begin
          fail("wrong session completion state, size or count");
        end
        if (expected_fire && (fetched_pc !== 32'(number(
                {destination, "/fetch_pc"}
            )) || fetched_instruction !== expected_imem[0]))
          fail("first modeled fetch is not from zero");
      end else begin
        if (cycle_count !== 64'd0 || prepare_done !== 1'b1)
          fail("unit completion changed resources");
      end
      @(negedge clk);
      if (WITH_CONTROL) begin
        for (
            follow = 0; follow < data.get_size({destination, "/follow_counts"}); follow = follow + 1
        ) begin
          #1;
          if (prepare_init || prepare_clear || prepare_done || imem_write_enable)
            fail("maintenance after completion");
          tick();
          if (cycle_count !== number($sformatf("%s/follow_counts/%0d", destination, follow))) begin
            fail("wrong RUN continuity or STEP/READY hold");
          end
          @(negedge clk);
        end
      end else begin
        repeat (2) begin
          if (!prepare_done || prepare_clear || prepare_init) fail("done did not remain at limit");
          tick();
          if (dut.g_valid_capacity.prepare_index !== expected_clears)
            fail("index overflowed at limit");
          @(negedge clk);
        end
        manual_active = 1'b0;
        tick();
        @(negedge clk);
        if (dut.g_valid_capacity.prepare_index !== 0 || prepare_done || prepare_clear ||
            prepare_init) begin
          fail("inactive service did not rearm index zero");
        end
      end
    end
  endtask

  // Carga las cuatro palabras por Loader y entra naturalmente a PREPARING_READY.
  task automatic load_image;
    load_request = 1'b1;
    #1;
    if (!load_start || !command_accepted || cpu_cycle_fire) fail("LOAD not accepted");
    tick();
    @(negedge clk);
    load_request = 1'b0;
    for (integer offset = 0; offset < 16; offset = offset + 1) begin
      byte_valid = 1'b1;
      byte_data  = load_bytes[offset];
      remaining  = 11'(16 - offset);
      last_byte  = (offset == 15);
      #1;
      if (imem_write_enable !== (offset % 4 == 3) || load_ok !== (offset == 15) || cpu_cycle_fire ||
          prepare_clear || prepare_init)
        fail("wrong load/preparation boundary");
      if (imem_write_enable &&
          (imem_write_index !== 8'(offset / 4) || imem_write_data !== expected_imem[offset/4]))
        fail("wrong Loader word");
      tick();
      if (confirmed_size !== 11'd0) fail("image published before preparation");
      @(negedge clk);
    end
    byte_valid = 1'b0;
    last_byte  = 1'b0;
    remaining  = 11'd0;
    if (state_code !== 8'd2 || dut.g_valid_capacity.prepare_index !== 0) begin
      fail("last load write did not enter preparation at index zero");
    end
  endtask

  // Desde terminal, la solicitud conserva la imagen y solo inicia preparación.
  task automatic request_session;
    run_request  = number("/inputs/prep_fixture/run_request");
    step_request = number("/inputs/prep_fixture/step_request");
    #1;
    if (!command_accepted || cpu_cycle_fire || prepare_clear || prepare_init) begin
      fail("terminal request executed before preparation");
    end
    tick();
    @(negedge clk);
    run_request  = 1'b0;
    step_request = 1'b0;
    if (!prepare_active || dut.g_valid_capacity.prepare_index !== 0)
      fail("new session not rearmed");
  endtask

  initial begin
    data.load();
    expected_clears  = number("/expected/preparation/clear_count");
    expected_clocks  = number("/expected/preparation/completion_clocks");
    physical_modulus = number("/inputs/prep_fixture/physical_modulus");
    dirty_register   = number("/inputs/prep_fixture/register_pattern");
    dirty_pc         = number("/inputs/prep_fixture/pc");
    dirty_count      = number("/inputs/prep_fixture/count");
    entry_kind       = data.get_string("/inputs/prep_fixture/entry");
    entry_state      = number("/inputs/prep_fixture/entry_state_onehot");
    reset_after      = number("/inputs/prep_fixture/reset_after");
    finish_path      = "/expected/preparation/finish";
    if (DMEM_CAPACITY_BYTES !== number("/inputs/C_DMEM") || expected_clears != CAPACITY) begin
      fail("elaboration capacity differs from case");
    end
    for (address = 0; address < CAPACITY; address = address + 1) begin
      dmem_physical[address] = 8'(address % physical_modulus);
    end
    for (word_index = 0; word_index < 4; word_index = word_index + 1) begin
      expected_imem[word_index] =
          number($sformatf("/inputs/prep_fixture/image_words/%0d", word_index));
      imem_fixture[word_index] = expected_imem[word_index];
    end
    for (address = 0; address < 16; address = address + 1) begin
      load_bytes[address] = number($sformatf("/inputs/prep_fixture/load_bytes/%0d", address));
    end
    tick();
    @(negedge clk);
    reset = 1'b0;
    dirty_resources();
    if (!WITH_CONTROL) begin
      manual_active = 1'b1;
    end else if (entry_kind == "load" || entry_kind == "reuse") begin
      load_image();
      if (entry_kind == "reuse") begin
        complete_service("/expected/preparation/initial_load_finish");
        run_request = 1'b1;
        tick();
        @(negedge clk);
        run_request   = 1'b0;
        terminal_kind = data.get_string("/inputs/prep_fixture/terminal");
        halt_confirm  = (terminal_kind == "FINISHED");
        act_id_fault  = (terminal_kind == "FAULT");
        tick();
        @(negedge clk);
        halt_confirm = 1'b0;
        act_id_fault = 1'b0;
        if (state_code !== 8'(number("/expected/preparation/terminal_code")))
          fail("wrong modeled terminal");
        dirty_resources();
        request_session();
      end
    end else begin
      control_inst.g_valid_capacity.global_fsm_inst.global_state = entry_state;
      control_inst.loaded_image_size_bytes = 11'(number("/inputs/prep_fixture/confirmed_size"));
      if (entry_kind == "terminal") request_session();
    end
    if (reset_after > 0) begin
      for (integer cleared = 0; cleared < reset_after; cleared = cleared + 1) begin
        #1;
        if (!prepare_clear || prepare_addr !== BYTE_ADDRESS_WIDTH'(cleared))
          fail("wrong pre-reset clear");
        tick();
        @(negedge clk);
      end
      reset = 1'b1;
      #1;
      if (prepare_init || prepare_clear || prepare_done || cpu_cycle_fire ||
          imem_write_enable) begin
        fail("reset did not suppress preparation and CPU");
      end
      tick();
      if (dut.g_valid_capacity.prepare_index !== 0 || (WITH_CONTROL && state_code !== 8'd0)) begin
        fail("reset did not restart index/state");
      end
      if (dmem_valid[reset_after] !== 1'b1) fail("reset cleared a coincident mark");
      @(negedge clk);
      reset = 1'b0;
      dirty_resources();
      if (WITH_CONTROL) begin
        // El fixture restaura fase/imagen del destino, conservando el índice que dejó reset.
        control_inst.g_valid_capacity.global_fsm_inst.global_state = entry_state;
        control_inst.loaded_image_size_bytes = 11'(number("/inputs/prep_fixture/confirmed_size"));
      end
    end
    complete_service(finish_path);
    $display("PASS %s", data.case_id);
    $finish;
  end

  // El límite excede las dos preparaciones REFERENCE de las pruebas de reutilización.
  initial begin
    #1000000;
    fail("testbench timeout");
  end
endmodule

// Comprueba el índice inclusivo cerca del límite sin recorrer ni reservar una DMEM grande.
module session_preparation_capacity_tb #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd4
);
  // Ancho mínimo para transportar direcciones de byte válidas.
  localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES);
  logic                                   clk = 1'b0;
  logic                                   reset = 1'b1;
  logic                                   active = 1'b0;
  logic                                   init;
  logic                                   clear;
  logic          [BYTE_ADDRESS_WIDTH-1:0] address;
  logic                                   done;
  longint signed                          last_index;
  longint signed                          limit;
  tp3_case_data data ();
  session_preparation #(
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk               (clk),
      .reset             (reset),
      .prepare_active    (active),
      .prepare_init      (init),
      .prepare_dmem_clear(clear),
      .prepare_dmem_addr (address),
      .prepare_done      (done)
  );
  always #10 clk = ~clk;

  // Falla con marcador propio del caso para distinguir un rechazo de una aprobación.
  task automatic fail(input string reason);
    $display("FAIL %s %s", data.case_id, reason);
    $fatal(1, "%s", reason);
  endtask

  initial begin
    data.load();
    last_index = data.get_integer("/inputs/prep_capacity_probe/last_index");
    limit      = data.get_integer("/expected/prep_capacity_probe/limit");
    if (DMEM_CAPACITY_BYTES !== data.get_integer(
            "/inputs/C"
        ) || $bits(
            dut.g_valid_capacity.prepare_index
        ) != data.get_integer(
            "/expected/CAPACITY_INCLUSIVE_WIDTH"
        )) begin
      fail("capacity or inclusive width differs from catalog");
    end
    @(posedge clk);
    #1;
    @(negedge clk);
    reset  = 1'b0;
    active = 1'b1;
    #1;
    if (!init || !clear || done || address !== 0) fail("wrong first clear");
    @(posedge clk);
    #1;
    if (dut.g_valid_capacity.prepare_index !== 1) fail("index did not increment");
    @(negedge clk);
    dut.g_valid_capacity.prepare_index = last_index;
    #1;
    if (init || !clear || done || address !== last_index) fail("wrong last clear");
    @(posedge clk);
    #1;
    if (dut.g_valid_capacity.prepare_index !== limit || !done || init || clear) begin
      fail("inclusive completion aliased to a write address");
    end
    repeat (2) begin
      @(posedge clk);
      #1;
      if (dut.g_valid_capacity.prepare_index !== limit || !done || init || clear)
        fail("limit overflow");
    end
    @(negedge clk);
    active = 1'b0;
    #1;
    if (done || init || clear) fail("inactive service emitted a control");
    @(posedge clk);
    #1;
    if (dut.g_valid_capacity.prepare_index !== 0) fail("inactive service did not reset index");
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
