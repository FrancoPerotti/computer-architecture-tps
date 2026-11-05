`timescale 1ns / 1ps

// Sesiones del CPU con las cinco etapas reales y expectativas externas de commits y trazas.
module processor_top_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd1024,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd2048,
    localparam integer IMAGE_SIZE_WIDTH = system_pkg::capacity_inclusive_width(IMEM_CAPACITY_BYTES),
    localparam integer IMEM_BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(
        IMEM_CAPACITY_BYTES
    ),
    localparam integer DMEM_BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES)
);
  import system_pkg::*;
  logic                                                         clk = '0;
  logic                                                         reset = '0;
  logic                                                         load_request = '0;
  logic                                                         run_request = '0;
  logic                                                         step_request = '0;
  logic                                                         load_byte_valid = '0;
  logic                                                         load_last_byte = '0;
  logic                                                         load_abort = '0;
  logic                                                         debug_read_select = '0;
  logic                           [       IMAGE_SIZE_WIDTH-1:0] load_size_bytes = '0;
  logic                           [                        7:0] load_byte_data = '0;
  logic                           [IMEM_BYTE_ADDRESS_WIDTH-1:0] load_byte_offset = '0;
  system_pkg::register_index_t                                  debug_rf_addr = '0;
  logic                           [DMEM_BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr = '0;
  logic                                                         command_accepted;
  logic                                                         load_available;
  logic                                                         prepare_active;
  logic                                                         program_finished;
  logic                                                         fault_terminal;
  logic                                                         cpu_cycle_fire;
  logic                                                         image_valid;
  logic                                                         debug_dmem_used;
  system_pkg::word_t                                            debug_rf_data;
  system_pkg::word_t                                            debug_pc;
  system_pkg::word_t                                            debug_fault_pc;
  logic                           [                        7:0] debug_dmem_data;
  system_pkg::global_state_code_t                               global_state_code;
  system_pkg::fault_cause_t                                     debug_fault_cause;
  logic                           [                       63:0] debug_cycle_count;
  if_id_t                                                       observed_ifid;
  id_ex_t                                                       observed_idex;
  ex_mem_t                                                      observed_exmem;
  mem_wb_t                                                      observed_memwb;
  integer                                                       cycle_index;
  string                                                        session_path;
  string                                                        expected_path;

  tp3_case_data data ();
  processor_top #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES),
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk                         (clk),
      .reset                       (reset),
      .load_request                (load_request),
      .run_request                 (run_request),
      .step_request                (step_request),
      .load_byte_valid             (load_byte_valid),
      .load_last_byte              (load_last_byte),
      .load_abort                  (load_abort),
      .debug_read_select           (debug_read_select),
      .load_size_bytes             (load_size_bytes),
      .load_byte_data              (load_byte_data),
      .load_byte_offset            (load_byte_offset),
      .debug_rf_addr               (debug_rf_addr),
      .debug_dmem_addr             (debug_dmem_addr),
      .command_accepted            (command_accepted),
      .load_available              (load_available),
      .prepare_active              (prepare_active),
      .program_finished            (program_finished),
      .fault_terminal              (fault_terminal),
      .cpu_cycle_fire              (cpu_cycle_fire),
      .image_valid                 (image_valid),
      .debug_dmem_used             (debug_dmem_used),
      .debug_rf_data               (debug_rf_data),
      .debug_pc                    (debug_pc),
      .debug_fault_pc              (debug_fault_pc),
      .debug_dmem_data             (debug_dmem_data),
      .global_state_code           (global_state_code),
      .debug_fault_cause           (debug_fault_cause),
      .debug_cycle_count           (debug_cycle_count),
      .debug_ifid_valid            (observed_ifid.valid),
      .debug_ifid_pc               (observed_ifid.pc),
      .debug_ifid_instruction      (observed_ifid.instruction),
      .debug_ifid_fetch_fault_valid(observed_ifid.fetch_fault_valid),
      .debug_ifid_fetch_fault_cause(observed_ifid.fetch_fault_cause),
      .debug_idex_valid            (observed_idex.valid),
      .debug_idex_pc               (observed_idex.pc),
      .debug_idex_instruction      (observed_idex.instruction),
      .debug_idex_rs1              (observed_idex.rs1),
      .debug_idex_rs2              (observed_idex.rs2),
      .debug_idex_rd               (observed_idex.rd),
      .debug_idex_rs1_value        (observed_idex.rs1_value),
      .debug_idex_rs2_value        (observed_idex.rs2_value),
      .debug_idex_immediate        (observed_idex.immediate),
      .debug_idex_alu_op           (observed_idex.alu_op),
      .debug_idex_alu_src          (observed_idex.alu_src),
      .debug_idex_result_sel       (observed_idex.result_sel),
      .debug_idex_flow_op          (observed_idex.flow_op),
      .debug_idex_mem_op           (observed_idex.mem_op),
      .debug_idex_reg_write        (observed_idex.reg_write),
      .debug_exmem_valid           (observed_exmem.valid),
      .debug_exmem_pc              (observed_exmem.pc),
      .debug_exmem_instruction     (observed_exmem.instruction),
      .debug_exmem_rd              (observed_exmem.rd),
      .debug_exmem_reg_write       (observed_exmem.reg_write),
      .debug_exmem_mem_op          (observed_exmem.mem_op),
      .debug_exmem_ex_result       (observed_exmem.ex_result),
      .debug_exmem_store_data      (observed_exmem.store_data),
      .debug_memwb_valid           (observed_memwb.valid),
      .debug_memwb_pc              (observed_memwb.pc),
      .debug_memwb_instruction     (observed_memwb.instruction),
      .debug_memwb_rd              (observed_memwb.rd),
      .debug_memwb_reg_write       (observed_memwb.reg_write),
      .debug_memwb_wb_value        (observed_memwb.wb_value)
  );

  always #10 clk = ~clk;

  task automatic fail(input string reason);
    $display("FAIL %s cycle=%0d %s", data.case_id, cycle_index, reason);
    $fatal(1, "%s", reason);
  endtask

  task automatic tick;
    @(posedge clk);
    #1;
    @(negedge clk);
  endtask

  function automatic logic [3:0] valid_mask;
    valid_mask = {
      observed_ifid.valid, observed_idex.valid, observed_exmem.valid, observed_memwb.valid
    };
  endfunction

  function automatic logic [503:0] pipeline_bits;
    pipeline_bits = {observed_ifid, observed_idex, observed_exmem, observed_memwb};
  endfunction

  // Observa la identidad de EX sin inyectar resultados ni datos de memoria.
  task automatic settle_stages;
    begin
      if (observed_idex.valid && observed_idex.instruction !== 32'(data.get_integer(
              $sformatf("%s/words/%0d", session_path, observed_idex.pc / 4)
          )))
        fail("EX received wrong instruction identity");
      #1;
    end
  endtask

  function automatic logic memory_used(input integer address);
    case (address % 4)
      0:
      memory_used = dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_0[
          address/4];
      1:
      memory_used = dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_1[
          address/4];
      2:
      memory_used = dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_2[
          address/4];
      default:
      memory_used = dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_3[
          address/4];
    endcase
  endfunction

  // Solo prepara residuos y precondiciones de memoria declaradas por el caso del catálogo.
  task automatic seed_memory_byte(input integer address, input logic [7:0] value);
    case (address % 4)
      0: begin
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_0[address/4] =
            value;
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_0[address/4] =
            1'b1;
      end
      1: begin
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_1[address/4] =
            value;
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_1[address/4] =
            1'b1;
      end
      2: begin
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_2[address/4] =
            value;
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_2[address/4] =
            1'b1;
      end
      default: begin
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.data_lane_3[address/4] =
            value;
        dut.g_valid_capacity.mem_stage_inst.data_memory.gen_valid_capacity.valid_lane_3[address/4] =
            1'b1;
      end
    endcase
  endtask

  task automatic hold_clocks(input integer clocks);
    logic               [503:0] before_pipeline;
    logic               [ 63:0] before_count;
    word_t                      before_pc;
    global_state_code_t         before_state;
    fault_cause_t               before_cause;
    word_t                      before_fault_pc;
    begin
      before_pipeline = pipeline_bits();
      before_count    = debug_cycle_count;
      before_pc       = debug_pc;
      before_state    = global_state_code;
      before_cause    = debug_fault_cause;
      before_fault_pc = debug_fault_pc;
      repeat (clocks) begin
        #1;
        if (cpu_cycle_fire !== 1'b0 || dut.g_valid_capacity.actions !== 8'd0 ||
            dut.g_valid_capacity.rf_write_fire !== 1'b0 ||
            dut.g_valid_capacity.mem_stage_inst.dmem_store_fire !== 1'b0)
          fail("HOLD repeated a CPU effect");
        tick();
        if (pipeline_bits() !== before_pipeline || debug_cycle_count !== before_count ||
            debug_pc !== before_pc || global_state_code !== before_state ||
            debug_fault_cause !== before_cause || debug_fault_pc !== before_fault_pc)
          fail("HOLD changed retained state");
      end
    end
  endtask

  task automatic reset_session(input string reset_context);
    begin
      reset = 1'b1;
      if (reset_context == "CPU") step_request = 1'b1;
      #1;
      if (cpu_cycle_fire !== 1'b0 || dut.g_valid_capacity.actions !== 8'd0 ||
          dut.g_valid_capacity.rf_write_fire !== 1'b0 ||
          dut.g_valid_capacity.mem_stage_inst.dmem_store_fire !== 1'b0 ||
          dut.g_valid_capacity.imem_write_enable !== 1'b0 ||
          dut.g_valid_capacity.load_ok !== 1'b0 || dut.g_valid_capacity.prepare_init !== 1'b0 ||
          dut.g_valid_capacity.prepare_dmem_clear !== 1'b0)
        fail("reset did not suppress a coincident resource action");
      tick();
      reset        = 1'b0;
      step_request = 1'b0;
      #1;
      if (global_state_code !== STATE_CODE_NO_IMAGE || image_valid !== 1'b0 || debug_pc !== 0 ||
          debug_cycle_count !== 0 || valid_mask() !== 0 || observed_ifid.fetch_fault_valid !== 1'b0)
        fail("reset did not initialize the session");
      for (integer index = 1; index < 32; index = index + 1) begin
        if (dut.g_valid_capacity.id_stage_inst.register_file.registers[index] !==
            32'(data.get_integer(
                $sformatf("%s/reset_result/rf/%0d", expected_path, index)
            )))
          fail("reset did not initialize RF");
      end
    end
  endtask

  task automatic load_image;
    integer size;
    word_t  word_value;
    begin
      size = 4 * data.get_size({session_path, "/words"});
      if (size < 4 || 64'(size) > IMEM_CAPACITY_BYTES) fail("invalid driver image size");
      load_size_bytes = IMAGE_SIZE_WIDTH'(size);
      if (data.get_string({session_path, "/start"}) != "continue_load") begin
        load_request = 1'b1;
        #1;
        if (command_accepted !== 1'b1 || cpu_cycle_fire !== 1'b0)
          fail("LOAD not accepted without a CPU cycle");
        tick();
        load_request = 1'b0;
      end
      if (image_valid !== 1'b0 || dut.g_valid_capacity.loaded_image_size_bytes !== 0)
        fail("old image survived LOAD");
      for (integer offset = 0; offset < size; offset = offset + 1) begin
        word_value = 32'(data.get_integer($sformatf("%s/words/%0d", session_path, offset / 4)));
        load_byte_valid = 1'b1;
        load_byte_offset = IMEM_BYTE_ADDRESS_WIDTH'(offset);
        load_byte_data = 8'(word_value >> (8 * (offset % 4)));
        load_last_byte = (offset == size - 1);
        #1;
        if (load_last_byte && data.get_string(
                {session_path, "/start"}
            ) == "reset_loader_last") begin
          reset_session("Loader");
        end else begin
          if (dut.g_valid_capacity.imem_write_enable !== (offset % 4 == 3) ||
              dut.g_valid_capacity.load_ok !== load_last_byte || cpu_cycle_fire !== 1'b0)
            fail("incorrect Loader boundary");
          if (offset % 4 == 3 && dut.g_valid_capacity.imem_write_data !== word_value)
            fail("incorrect little-endian image word");
          tick();
        end
      end
      load_byte_valid = 1'b0;
      load_last_byte  = 1'b0;
      if (data.get_string(
              {session_path, "/start"}
          ) != "reset_loader_last" && (prepare_active !== 1'b1 || image_valid !== 1'b0))
        fail("last byte published the image before preparation");
    end
  endtask

  task automatic prepare_image(input bit publish);
    integer clear_count;
    begin
      clear_count = data.get_integer({expected_path, "/prepare_clears"});
      for (integer address = 0; address < clear_count; address = address + 1) begin
        #1;
        if (prepare_active !== 1'b1 || cpu_cycle_fire !== 1'b0 || image_valid !== !publish ||
            dut.g_valid_capacity.prepare_dmem_clear !== 1'b1 ||
            dut.g_valid_capacity.prepare_dmem_addr !== DMEM_BYTE_ADDRESS_WIDTH'(address) ||
            dut.g_valid_capacity.prepare_init !== (address == 0))
          fail("incorrect preparation sequence");
        tick();
        if (debug_pc !== 0 || debug_cycle_count !== 0 || valid_mask() !== 4'd0 ||
            observed_ifid.fetch_fault_valid !== 1'b0)
          fail("preparation did not initialize CPU resources");
      end
      #1;
      if (dut.g_valid_capacity.prepare_done !== 1'b1 ||
          dut.g_valid_capacity.prepare_dmem_clear !== 1'b0 || cpu_cycle_fire !== !publish)
        fail("last clear overlaps publication");
      if (!publish) begin
        if (dut.g_valid_capacity.execution_control_inst.g_valid_capacity.image_publish !== 0)
          fail("reuse republished an image");
        for (integer index = 1; index < 32; index = index + 1) begin
          if (dut.g_valid_capacity.id_stage_inst.register_file.registers[index] !== 0)
            fail("reuse did not clear RF before its first cycle");
        end
        for (integer address = 0; address < clear_count; address = address + 1) begin
          if (memory_used(address) !== 1'b0)
            fail("reuse did not clear all DMEM marks before its first cycle");
        end
      end else begin
        tick();
        if (global_state_code !== STATE_CODE_READY || image_valid !== 1'b1 ||
            dut.g_valid_capacity.loaded_image_size_bytes !== load_size_bytes ||
            cpu_cycle_fire !== 0)
          fail("prepared image not published in READY");
        debug_read_select = 1'b1;
        for (integer index = 0; index < 32; index = index + 1) begin
          debug_rf_addr = 5'(index);
          #1;
          if (debug_rf_data !== 0) fail("RF not initialized by preparation");
        end
        for (integer address = 0; address < clear_count; address = address + 1) begin
          debug_dmem_addr = DMEM_BYTE_ADDRESS_WIDTH'(address);
          #1;
          if (debug_dmem_data !== 8'd0 || debug_dmem_used !== 1'b0)
            fail("preparation omitted a DMEM mark");
        end
        debug_read_select = 1'b0;
        @(negedge clk);
      end
    end
  endtask

  task automatic check_pre_edge(input string path);
    logic [3:0] next_mask;
    begin
      next_mask = {
        dut.g_valid_capacity.ifid_next_valid,
        dut.g_valid_capacity.idex_next_valid,
        dut.g_valid_capacity.exmem_next_valid,
        dut.g_valid_capacity.memwb_next_valid
      };
      if (cpu_cycle_fire !== 1'b1 || dut.g_valid_capacity.actions !== 8'(data.get_integer(
              {path, "/action"}
          )) || next_mask !== 4'(data.get_integer(
              {path, "/valid_mask"}
          )) || dut.g_valid_capacity.execution_control_inst.g_valid_capacity.pipeline_empty_next !==
              data.get_boolean(
              {path, "/empty_next"}
          ))
        fail("incorrect action or next.valid");
      if (dut.g_valid_capacity.ex_stage_inst.exmem_producer !== observed_exmem ||
          dut.g_valid_capacity.ex_stage_inst.memwb_producer !== observed_memwb ||
          dut.g_valid_capacity.wb_stage_inst.memwb !== observed_memwb)
        fail("a stage received a future or unrelated producer");
      // Expectativas externas para los consumidores que requieren forwarding real en EX.
      if (data.has_path({path, "/ex_check"})) begin
        if (dut.g_valid_capacity.ex_stage_inst.forward_a_sel !== 2'(data.get_integer(
                {path, "/ex_check/forward_a"}
            )) || dut.g_valid_capacity.ex_stage_inst.forward_b_sel !== 2'(data.get_integer(
                {path, "/ex_check/forward_b"}
            )) || dut.g_valid_capacity.exmem_input.ex_result !== 32'(data.get_integer(
                {path, "/ex_check/result"}
            )) || dut.g_valid_capacity.exmem_input.store_data !== 32'(data.get_integer(
                {path, "/ex_check/store_data"}
            )) || dut.g_valid_capacity.redirect_requested !== data.get_boolean(
                {path, "/ex_check/redirect"}
            ))
          fail("incorrect real EX forwarding or result");
        if (data.get_boolean(
                {path, "/ex_check/redirect"}
            ) && dut.g_valid_capacity.redirect_target !== 32'(data.get_integer(
                {path, "/ex_check/target"}
            )))
          fail("incorrect real EX redirect target");
      end
      if (dut.g_valid_capacity.rf_write_fire !== data.get_boolean({path, "/rf_commit/fire"}))
        fail("unexpected or missing RF commit");
      if (data.get_boolean({path, "/rf_commit/fire"})) begin
        if (observed_memwb.pc !== 32'(data.get_integer(
                {path, "/rf_commit/pc"}
            )) || dut.g_valid_capacity.rf_write_addr !== 5'(data.get_integer(
                {path, "/rf_commit/rd"}
            )) || dut.g_valid_capacity.rf_write_data !== 32'(data.get_integer(
                {path, "/rf_commit/value"}
            )))
          fail("incorrect RF commit identity, destination or data");
        $display("RF_COMMIT %s session=%s cycle=%0d pc=%h rd=%0d value=%h", data.case_id,
                 session_path, cycle_index + 1, observed_memwb.pc,
                 dut.g_valid_capacity.rf_write_addr, dut.g_valid_capacity.rf_write_data);
      end
      if (dut.g_valid_capacity.mem_stage_inst.dmem_store_fire !== data.get_boolean(
              {path, "/store_commit/fire"}
          ))
        fail("unexpected or missing store");
      if (data.get_boolean({path, "/store_commit/fire"})) begin
        if (observed_exmem.pc !== 32'(data.get_integer(
                {path, "/store_commit/pc"}
            )) || observed_exmem.ex_result !== 32'(data.get_integer(
                {path, "/store_commit/address"}
            )) || observed_exmem.store_data !== 32'(data.get_integer(
                {path, "/store_commit/value"}
            )))
          fail("incorrect store identity, address or data");
        $display("STORE_COMMIT %s session=%s cycle=%0d pc=%h address=%h value=%h", data.case_id,
                 session_path, cycle_index + 1, observed_exmem.pc, observed_exmem.ex_result,
                 observed_exmem.store_data);
      end
    end
  endtask

  function automatic word_t image_word(input word_t pc);
    image_word = 32'(data.get_integer($sformatf("%s/words/%0d", session_path, pc / 4)));
  endfunction

  task automatic check_post_edge(input string path);
    begin
      if (debug_pc !== 32'(data.get_integer(
              {path, "/pc"}
          )) || debug_cycle_count !== 64'(data.get_integer(
              {path, "/count"}
          )) || global_state_code !== 8'(data.get_integer(
              {path, "/state"}
          )) || valid_mask() !== 4'(data.get_integer(
              {path, "/valid_mask"}
          )) || observed_ifid.fetch_fault_valid !== data.get_boolean(
              {path, "/fetch_fault_valid"}
          ))
        fail("incorrect registered cycle state");
      if (observed_ifid.valid || observed_ifid.fetch_fault_valid) begin
        if (observed_ifid.pc !== 32'(data.get_integer({path, "/ifid_pc"})))
          fail("incorrect IF/ID identity");
        if (observed_ifid.fetch_fault_valid &&
            observed_ifid.fetch_fault_cause !== 3'(data.get_integer(
                {path, "/fetch_fault_cause"}
            )))
          fail("incorrect fetch candidate cause");
      end
      if (observed_idex.valid && observed_idex.pc !== 32'(data.get_integer({path, "/idex_pc"})))
        fail("incorrect ID/EX PC");
      if (observed_exmem.valid && observed_exmem.pc !== 32'(data.get_integer({path, "/exmem_pc"})))
        fail("incorrect EX/MEM PC");
      if (observed_memwb.valid && observed_memwb.pc !== 32'(data.get_integer({path, "/memwb_pc"})))
        fail("incorrect MEM/WB PC");
      if (data.get_boolean({path, "/fault_info_valid"})) begin
        if (debug_fault_cause !== 3'(data.get_integer(
                {expected_path, "/fault_cause"}
            )) || debug_fault_pc !== 32'(data.get_integer(
                {expected_path, "/fault_pc"}
            )))
          fail("incorrect or unstable fault metadata");
      end else if (global_state_code == STATE_CODE_FAULT_DRAIN_AUTO || global_state_code ==
                   STATE_CODE_FAULT_DRAIN_STEP || global_state_code == STATE_CODE_FAULT)
        fail("old fault metadata became valid in the new session");
      if ((observed_ifid.valid && observed_ifid.instruction !== image_word(
              observed_ifid.pc
          )) || (observed_idex.valid && observed_idex.instruction !== image_word(
              observed_idex.pc
          )) || (observed_exmem.valid && observed_exmem.instruction !== image_word(
              observed_exmem.pc
          )) || (observed_memwb.valid && observed_memwb.instruction !== image_word(
              observed_memwb.pc
          )))
        fail("a latch lost its instruction identity");
      if (data.get_boolean(
              {path, "/check_idex_operands"}
          ) && (observed_idex.rs1_value !== 32'(data.get_integer(
              {path, "/idex_rs1_value"}
          )) || observed_idex.rs2_value !== 32'(data.get_integer(
              {path, "/idex_rs2_value"}
          ))))
        fail("ID/EX did not capture the expected pre-edge operands after WB bypass");
      // Comprueba que los 34 cables Debug provengan del estado actual, incluidos residuos.
      if (observed_ifid !== dut.g_valid_capacity.ifid || observed_idex !==
          dut.g_valid_capacity.idex || observed_exmem !== dut.g_valid_capacity.exmem ||
          observed_memwb !== dut.g_valid_capacity.memwb)
        fail("Debug is not current latch state");
      $display("TRACE %s cycle=%0d state=%0d pc=%h valid=%b", data.case_id, cycle_index + 1,
               global_state_code, debug_pc, valid_mask());
    end
  endtask

  task automatic execute_image;
    string mode;
    string path;
    bit    from_prepare;
    begin
      mode         = data.get_string({session_path, "/mode"});
      from_prepare = (data.get_string({session_path, "/start"}) == "reuse");
      for (
          cycle_index = 0;
          cycle_index < data.get_size({expected_path, "/trace"});
          cycle_index = cycle_index + 1
      ) begin
        path = $sformatf("%s/trace/%0d", expected_path, cycle_index);
        if (data.has_path({session_path, "/commands"}))
          mode = data.get_string($sformatf("%s/commands/%0d", session_path, cycle_index));
        run_request = (mode == "RUN" && (data.has_path({session_path, "/commands"}) ||
                                         (cycle_index == 0 && !from_prepare)));
        step_request = (mode == "STEP" && (cycle_index > 0 || !from_prepare));
        settle_stages();
        if (command_accepted !==
            ((mode == "STEP" || (mode == "RUN" && (cycle_index == 0 || data.has_path(
                {session_path, "/commands"}
            )))) && !(from_prepare && cycle_index == 0)))
          fail("incorrect command acceptance");
        check_pre_edge(path);
        @(posedge clk);
        #1;
        check_post_edge(path);
        @(negedge clk);
        run_request  = 1'b0;
        step_request = 1'b0;
        if (mode == "STEP")
          hold_clocks(data.get_integer($sformatf("%s/holds/%0d", session_path, cycle_index)));
      end
      if (data.get_string({session_path, "/after_trace"}) == "reset") begin
        if (observed_exmem.valid !== 1'b1 || observed_memwb.valid !== 1'b1 ||
            observed_exmem.mem_op !== MEM_OP_SW || observed_memwb.reg_write !== 1'b1)
          fail("reset fixture did not reach simultaneous store and WB");
        settle_stages();
        reset_session("CPU");
      end
      if (global_state_code !== 8'(data.get_integer(
              {expected_path, "/terminal"}
          )) || program_finished !== (data.get_integer(
              {expected_path, "/terminal"}
          ) == 10) || fault_terminal !== (data.get_integer(
              {expected_path, "/terminal"}
          ) == 11) || cpu_cycle_fire !== 1'b0)
        fail("expected terminal on the last occupied cycle");
      hold_clocks(50);
    end
  endtask

  // LOAD aceptado abandona el pipeline retenido sin consumir sus efectos pendientes.
  task automatic abandon_to_load;
    logic         [503:0] saved_pipeline;
    word_t                saved_pc;
    logic         [ 63:0] saved_count;
    fault_cause_t         saved_cause;
    word_t                saved_fault_pc;
    begin
      saved_pipeline  = pipeline_bits();
      saved_pc        = debug_pc;
      saved_count     = debug_cycle_count;
      saved_cause     = debug_fault_cause;
      saved_fault_pc  = debug_fault_pc;
      load_size_bytes = IMAGE_SIZE_WIDTH'(4);
      load_request    = 1'b1;
      step_request    = 1'b1;
      run_request     = 1'b1;
      #1;
      if (!command_accepted || cpu_cycle_fire || dut.g_valid_capacity.actions != 0 ||
          dut.g_valid_capacity.rf_write_fire || dut.g_valid_capacity.mem_stage_inst.dmem_store_fire
          || dut.g_valid_capacity.execution_control_inst.g_valid_capacity.fault_capture_fire)
        fail("LOAD did not dominate pending CPU work");
      tick();
      load_request = 1'b0;
      step_request = 1'b0;
      run_request  = 1'b0;
      if (global_state_code != STATE_CODE_LOADING || image_valid || pipeline_bits() !==
          saved_pipeline || debug_pc !== saved_pc || debug_cycle_count !== saved_count ||
          debug_fault_cause !== saved_cause || debug_fault_pc !== saved_fault_pc)
        fail("LOAD changed abandoned latches or metadata before preparation");
    end
  endtask

  // Ejecuta programas completos contra commits y sondas escritos en el JSON.
  // El banco no calcula resultados ISA ni simula otra CPU como referencia.
  task automatic execute_program;
    string        mode;
    string        path;
    integer       rf_index;
    integer       store_index;
    integer       stalls;
    integer       cycles;
    integer       probe_count;
    if_id_t       before_ifid;
    word_t        before_pc;
    logic   [7:0] selected_action;
    begin
      mode        = data.get_string({session_path, "/mode"});
      cycles      = data.get_integer({expected_path, "/cycles"});
      rf_index    = 0;
      store_index = 0;
      stalls      = 0;
      probe_count = 0;
      for (cycle_index = 0; cycle_index < cycles; cycle_index = cycle_index + 1) begin
        if (data.has_path({session_path, "/commands"}))
          mode = data.get_string($sformatf("%s/commands/%0d", session_path, cycle_index));
        run_request = (mode == "RUN" &&
                       (cycle_index == 0 || data.has_path({session_path, "/commands"})));
        step_request = (mode == "STEP");
        load_request = 1'b0;
        if (data.has_path({session_path, "/load_requests"})) begin
          for (
              integer request_index = 0;
              request_index < data.get_size({session_path, "/load_requests"});
              request_index = request_index + 1
          )
          if (data.get_integer(
                  $sformatf("%s/load_requests/%0d", session_path, request_index)
              ) == cycle_index + 1)
            load_request = 1'b1;
        end
        #1;
        if (load_request && (dut.g_valid_capacity.load_start || command_accepted))
          fail("AUTO accepted a forbidden LOAD");
        if (!cpu_cycle_fire || command_accepted !==
            (mode == "STEP" || (mode == "RUN" && (cycle_index == 0 || data.has_path(
                {session_path, "/commands"}
            )))))
          fail("program cycle not authorized from current state");
        if (!$onehot(dut.g_valid_capacity.actions)) fail("actions are not one-hot");
        selected_action = dut.g_valid_capacity.actions;
        before_pc       = debug_pc;
        before_ifid     = observed_ifid;
        if (dut.g_valid_capacity.rf_write_fire) begin
          if (rf_index >= data.get_size({expected_path, "/rf_commits"})) fail("extra RF commit");
          path = $sformatf("%s/rf_commits/%0d", expected_path, rf_index);
          if (data.get_integer(
                  {path, "/cycle"}
              ) != cycle_index + 1 || observed_memwb.pc !== 32'(data.get_integer(
                  {path, "/pc"}
              )) || dut.g_valid_capacity.rf_write_addr !== 5'(data.get_integer(
                  {path, "/rd"}
              )) || dut.g_valid_capacity.rf_write_data !== 32'(data.get_integer(
                  {path, "/value"}
              )))
            fail("program RF commit does not match independent expectation");
          $display("RF_COMMIT %s cycle=%0d pc=%h rd=%0d value=%h", data.case_id, cycle_index + 1,
                   observed_memwb.pc, dut.g_valid_capacity.rf_write_addr,
                   dut.g_valid_capacity.rf_write_data);
          rf_index = rf_index + 1;
        end
        if (dut.g_valid_capacity.mem_stage_inst.dmem_store_fire) begin
          if (store_index >= data.get_size({expected_path, "/store_commits"})) fail("extra store");
          path = $sformatf("%s/store_commits/%0d", expected_path, store_index);
          if (data.get_integer(
                  {path, "/cycle"}
              ) != cycle_index + 1 || observed_exmem.pc !== 32'(data.get_integer(
                  {path, "/pc"}
              )) || observed_exmem.ex_result !== 32'(data.get_integer(
                  {path, "/address"}
              )) || observed_exmem.store_data !== 32'(data.get_integer(
                  {path, "/value"}
              )) || dut.g_valid_capacity.mem_stage_inst.byte_enable !== 4'(data.get_integer(
                  {path, "/byte_enable"}
              )))
            fail("program store does not match independent expectation");
          $display("STORE_COMMIT %s cycle=%0d pc=%h address=%h value=%h", data.case_id,
                   cycle_index + 1, observed_exmem.pc, observed_exmem.ex_result,
                   observed_exmem.store_data);
          store_index = store_index + 1;
        end
        if (data.has_path({expected_path, "/probes"})) begin
          for (
              integer probe = 0;
              probe < data.get_size({expected_path, "/probes"});
              probe = probe + 1
          ) begin
            path = $sformatf("%s/probes/%0d", expected_path, probe);
            if (data.get_integer({path, "/cycle"}) == cycle_index + 1) begin
              probe_count = probe_count + 1;
              if (data.has_path(
                      {path, "/idex_immediate"}
                  ) && (!observed_idex.valid || observed_idex.immediate !== 32'(data.get_integer(
                      {path, "/idex_immediate"}
                  ))))
                fail("CPU immediate does not match catalog");
              if (data.has_path(
                      {path, "/action"}
                  ) && selected_action !== 8'(data.get_integer(
                      {path, "/action"}
                  )))
                fail("program action does not match expected boundary");
              if (data.has_path(
                      {path, "/redirect_target"}
                  ) && dut.g_valid_capacity.redirect_target !== 32'(data.get_integer(
                      {path, "/redirect_target"}
                  )))
                fail("program target does not match catalog");
            end
          end
        end
        if (selected_action == 8 || selected_action == 2) stalls = stalls + 1;
        @(posedge clk);
        #1;
        if (debug_cycle_count !== 64'(cycle_index + 1))
          fail("program counter did not count effective cycle");
        if (data.has_path(
                {expected_path, "/pc_trace"}
            ) && debug_pc !== 32'(data.get_integer(
                $sformatf("%s/pc_trace/%0d", expected_path, cycle_index)
            )))
          fail("program PC trace does not match catalog");
        if ((selected_action == 8 || selected_action == 2) &&
            (debug_pc !== before_pc || observed_ifid !== before_ifid || observed_idex.valid))
          fail("load-use did not hold IF/ID and bubble ID/EX");
        if ((selected_action == 128 || selected_action == 64 || selected_action == 32 ||
             selected_action == 16) &&
            (observed_ifid.valid || observed_ifid.fetch_fault_valid || observed_idex.valid))
          fail("boundary did not discard younger pipeline work");
        if ((selected_action == 128 || selected_action == 64) && observed_exmem.valid)
          fail("fault or HALT entered EX/MEM");
        $display("TRACE %s cycle=%0d state=%0d pc=%h valid=%b action=%h", data.case_id,
                 cycle_index + 1, global_state_code, debug_pc, valid_mask(), selected_action);
        @(negedge clk);
        run_request  = 1'b0;
        step_request = 1'b0;
        load_request = 1'b0;
        if (mode == "STEP")
          hold_clocks(data.get_integer($sformatf("%s/holds/%0d", session_path, cycle_index)));
      end
      if (rf_index != data.get_size(
              {expected_path, "/rf_commits"}
          ) || store_index != data.get_size(
              {expected_path, "/store_commits"}
          ))
        fail("missing architectural commits");
      if (data.has_path(
              {expected_path, "/probes"}
          ) && probe_count != data.get_size(
              {expected_path, "/probes"}
          ))
        fail("a required observation was not reached");
      if (stalls != data.get_integer({expected_path, "/stalls"}))
        fail("incorrect load-use stall count");
      if (global_state_code !== 8'(data.get_integer(
              {expected_path, "/terminal"}
          )) || debug_pc !== 32'(data.get_integer(
              {expected_path, "/pc"}
          )))
        fail("incorrect program terminal or PC");
      if (global_state_code == STATE_CODE_FAULT && (debug_fault_cause !== 3'(data.get_integer(
              {expected_path, "/fault_cause"}
          )) || debug_fault_pc !== 32'(data.get_integer(
              {expected_path, "/fault_pc"}
          ))))
        fail("incorrect program fault cause or origin");
      if ((program_finished || fault_terminal) && valid_mask() != 0)
        fail("terminal before pipeline empty");
      if (program_finished || fault_terminal || mode == "STEP") hold_clocks(3);
      if (data.get_string(
              {session_path, "/after_trace"}
          ) == "reset_program" || data.get_string(
              {session_path, "/after_trace"}
          ) == "replace") begin
        for (integer index = 1; index < 32; index = index + 1) begin
          if (dut.g_valid_capacity.id_stage_inst.register_file.registers[index] !==
              32'(data.get_integer(
                  $sformatf("%s/observed_rf/%0d", expected_path, index)
              )))
            fail("incorrect RF at finite observation boundary");
        end
        if (data.get_string({session_path, "/after_trace"}) == "reset_program")
          reset_session("Program");
        else abandon_to_load();
      end
    end
  endtask

  task automatic check_final_state;
    integer       used_count;
    logic   [7:0] expected_byte;
    logic         expected_used;
    begin
      used_count        = data.get_size({expected_path, "/used_addresses"});
      debug_read_select = 1'b1;
      for (integer index = 0; index < 32; index = index + 1) begin
        debug_rf_addr = 5'(index);
        #1;
        if (debug_rf_data !== 32'(data.get_integer($sformatf("%s/rf/%0d", expected_path, index))))
          fail("incorrect final RF");
        $display("RF %s session=%s x%0d=%h", data.case_id, session_path, index, debug_rf_data);
      end
      for (integer address = 0; address < DMEM_CAPACITY_BYTES; address = address + 1) begin
        expected_byte = 8'd0;
        expected_used = 1'b0;
        for (integer item = 0; item < used_count; item = item + 1) begin
          if (address == data.get_integer(
                  $sformatf("%s/used_addresses/%0d", expected_path, item)
              )) begin
            expected_used = 1'b1;
            expected_byte =
                8'(data.get_integer($sformatf("%s/used_values/%0d", expected_path, item)));
          end
        end
        debug_dmem_addr = DMEM_BYTE_ADDRESS_WIDTH'(address);
        #1;
        if (debug_dmem_data !== expected_byte || debug_dmem_used !== expected_used)
          fail("incorrect final DMEM data or used mark");
        if (debug_dmem_used)
          $display(
              "DMEM_USED %s session=%s address=%0d data=%h",
              data.case_id,
              session_path,
              address,
              debug_dmem_data
          );
      end
      debug_read_select = 1'b0;
      @(negedge clk);
    end
  endtask

  initial begin
    data.load();
    cycle_index = 0;
    reset       = 1'b1;
    tick();
    reset = 1'b0;
    for (integer address = 0; 64'(address) < DMEM_CAPACITY_BYTES; address = address + 1)
    seed_memory_byte(address, 8'(address));
    for (
        integer session = 0; session < data.get_size("/inputs/processor"); session = session + 1
    ) begin
      session_path  = $sformatf("/inputs/processor/%0d", session);
      expected_path = $sformatf("/expected/processor/%0d", session);
      if (data.get_string({session_path, "/start"}) == "reuse") begin
        run_request  = (data.get_string({session_path, "/mode"}) == "RUN");
        step_request = !run_request;
        #1;
        if (command_accepted !== 1'b1 || cpu_cycle_fire !== 1'b0 ||
            dut.g_valid_capacity.load_start !== 1'b0)
          fail("terminal command did not start preparation alone");
        tick();
        run_request  = 1'b0;
        step_request = 1'b0;
        prepare_image(1'b0);
      end else begin
        load_image();
        if (data.get_string({session_path, "/start"}) == "reset_preparation") begin
          if (prepare_active !== 1'b1 || dut.g_valid_capacity.prepare_dmem_clear !== 1'b1)
            fail("reset fixture did not reach active preparation");
          reset_session("Preparation");
        end else if (data.get_string({session_path, "/start"}) != "reset_loader_last") begin
          prepare_image(1'b1);
          if (data.has_path({session_path, "/initial_memory"})) begin
            for (
                integer item = 0;
                item < data.get_size({session_path, "/initial_memory"});
                item = item + 1
            ) begin
              seed_memory_byte(32'(data.get_integer(
                               $sformatf("%s/initial_memory/%0d/address", session_path, item))),
                               8'(data.get_integer(
                               $sformatf("%s/initial_memory/%0d/value", session_path, item))));
            end
          end
          // El estado inicial adicional se inyecta solo donde el catálogo declara un fixture.
          for (integer index = 1; index < 32; index = index + 1) begin
            if (data.get_integer($sformatf("%s/initial_rf/%0d", session_path, index)) != 0)
              dut.g_valid_capacity.id_stage_inst.register_file.registers[index] =
                  32'(data.get_integer(
                  $sformatf("%s/initial_rf/%0d", session_path, index)
              ));
          end
        end
      end
      if (data.get_string(
              {session_path, "/start"}
          ) == "reset_loader_last" || data.get_string(
              {session_path, "/start"}
          ) == "reset_preparation") begin
        hold_clocks(50);
      end else begin
        if (data.has_path({expected_path, "/trace"})) execute_image();
        else execute_program();
        if (data.get_string({session_path, "/after_trace"}) != "replace") check_final_state();
      end
    end
    $display("PASS %s", data.case_id);
    $finish;
  end

  initial begin
    #10_000_000;
    $fatal(1, "processor_top session timeout");
  end
endmodule
