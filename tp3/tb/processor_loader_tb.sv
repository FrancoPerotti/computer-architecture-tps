`timescale 1ns / 1ps

// Reproduce los vectores de Loader contra IMEM y control reales, sin memoria sustituta.
module processor_loader_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd1024
);
  import system_pkg::*;
  localparam integer SIZE_WIDTH    = capacity_inclusive_width(IMEM_CAPACITY_BYTES);
  localparam integer ADDRESS_WIDTH = byte_address_width(IMEM_CAPACITY_BYTES);
  string  input_path;
  string  expected_path;
  integer writes = 0;
  integer waited;
  integer physical_index;

  // El harness mantiene las interfaces públicas y el contenido físico de IMEM de producción.
  processor_test_harness #(.IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)) h ();

  function automatic logic [63:0] number(input string path);
    logic  [63:0] value;
    string        text_value;
    begin
      if (h.data.get_type(path) == "boolean") number = 64'(h.data.get_boolean(path));
      else if (h.data.get_type(path) == "integer") number = h.data.get_integer(path);
      else begin
        text_value = h.data.get_string(path);
        if ($sscanf(text_value, "0x%h", value) != 1) $fatal(1, "Invalid hexadecimal fixture");
        number = value;
      end
    end
  endfunction

  function automatic logic [63:0] stimulus(input string name);
    string path;
    begin
      path = {input_path, "/", name};
      if (!h.data.has_path(path)) path = {"/inputs/loader_fixture/defaults/", name};
      stimulus = number(path);
    end
  endfunction

  task automatic compare_before;
    if (h.dut.g_valid_capacity.load_start !== 1'(number(
            {expected_path, "/start"}
        )) || h.dut.g_valid_capacity.loader_active !== 1'(number(
            {expected_path, "/active"}
        )) || h.dut.g_valid_capacity.imem_write_enable !== 1'(number(
            {expected_path, "/write"}
        )) || h.dut.g_valid_capacity.imem_write_index !== number(
            {expected_path, "/index"}
        ) || h.dut.g_valid_capacity.load_ok !== 1'(number(
            {expected_path, "/ok"}
        )) || h.dut.g_valid_capacity.load_fail !== 1'(number(
            {expected_path, "/fail"}
        )) || h.command_accepted !== 1'(number(
            {expected_path, "/accepted"}
        )) || h.cpu_cycle_fire)
      $fatal(1, "Incorrect Loader/control boundary before edge");
    if (!h.data.is_null(
            {expected_path, "/data"}
        ) && h.dut.g_valid_capacity.imem_write_data !== 32'(number(
            {expected_path, "/data"}
        )))
      $fatal(1, "Incorrect fourth-byte little-endian word");
  endtask

  initial begin
    h.data.load();
    h.reset_cpu();
    // Los dos residuos y el parcial se toman del fixture publicado, no del RTL esperado.
    for (integer slot = 0; slot < 2; slot = slot + 1) begin
      physical_index = 32'(number($sformatf("/inputs/loader_fixture/indices/%0d", slot)));
      h.dut.g_valid_capacity.if_stage_inst.gen_valid_capacity.instruction_memory.gen_valid_capacity.
          words[physical_index] = 32'(number($sformatf("/inputs/loader_fixture/memory/%0d", slot)));
    end
    h.dut.g_valid_capacity.loader_inst.g_valid_capacity.partial_word =
        24'(number("/inputs/loader_fixture/partial_word"));
    for (integer item = 0; item < h.data.get_size("/inputs/loader_steps"); item = item + 1) begin
      input_path         = $sformatf("/inputs/loader_steps/%0d", item);
      expected_path      = $sformatf("/expected/loader_steps/%0d", item);
      h.reset            = 1'(stimulus("reset"));
      h.load_request     = 1'(stimulus("load_request"));
      h.run_request      = 1'(stimulus("run_request"));
      h.step_request     = 1'(stimulus("step_request"));
      h.load_size_bytes  = SIZE_WIDTH'(stimulus("size"));
      h.load_byte_offset = ADDRESS_WIDTH'(stimulus("size") - stimulus("remaining"));
      h.load_byte_valid  = 1'(stimulus("valid"));
      h.load_byte_data   = 8'(stimulus("byte"));
      h.load_last_byte   = 1'(stimulus("last"));
      h.load_abort       = 1'(stimulus("abort"));
      // El vector local de done se sustituye por la finalización del servicio físico real.
      if (stimulus("prepare_done")) begin
        waited = 0;
        while (!h.dut.g_valid_capacity.prepare_done) begin
          if (waited > 2048) $fatal(1, "Preparation did not complete");
          h.tick();
          waited = waited + 1;
        end
      end
      #1;
      compare_before();
      if (h.dut.g_valid_capacity.imem_write_enable) writes = writes + 1;
      h.tick();
      if (h.global_state_code !== 8'(number(
              {expected_path, "/state_after"}
          )) || h.image_valid !== 1'(number(
              {expected_path, "/image_valid_after"}
          )) || h.dut.g_valid_capacity.loaded_image_size_bytes !== SIZE_WIDTH'(number(
              {expected_path, "/size_after"}
          )) || h.debug_cycle_count !== number(
              {expected_path, "/cycles_after"}
          ) || writes != number(
              {expected_path, "/writes_after"}
          ) || h.dut.g_valid_capacity.loader_inst.g_valid_capacity.partial_word !== 24'(number(
              {expected_path, "/partial_after"}
          )))
        $fatal(1, "Incorrect Loader/control state after edge");
      for (integer slot = 0; slot < 2; slot = slot + 1) begin
        physical_index = 32'(number($sformatf("/inputs/loader_fixture/indices/%0d", slot)));
        if (h.dut.g_valid_capacity.if_stage_inst.gen_valid_capacity.instruction_memory
            .gen_valid_capacity.words[physical_index] !== 32'(number(
                $sformatf("%s/memory_after/%0d", expected_path, slot)
            )))
          $fatal(1, "Real IMEM differs from expected synchronous writes");
      end
    end
    $display("PASS %s", h.data.case_id);
    $finish;
  end
endmodule
