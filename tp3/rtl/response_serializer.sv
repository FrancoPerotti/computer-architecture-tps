// Serializa respuestas cortas y, en iteraciones posteriores, snapshots Debug.
module response_serializer #(
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES =
        system_pkg::REFERENCE_DMEM_CAPACITY_BYTES,
    localparam integer BYTE_ADDRESS_WIDTH = system_pkg::byte_address_width(DMEM_CAPACITY_BYTES),
    localparam integer USED_COUNT_WIDTH = system_pkg::capacity_inclusive_width(DMEM_CAPACITY_BYTES)
) (
    input  logic                          clk,
    input  logic                          reset,
    input  logic                          tx_full,
    input  logic                          tx_done_tick,
    output logic [                   7:0] w_data,
    output logic                          wr_uart,
    input  logic                          response_start,
    input  logic [                   7:0] response_opcode,
    input  logic [                   7:0] response_result,
    input  logic                          response_with_debug,
    output logic                          response_busy,
    output logic                          response_done_tick,
    input  logic [                   7:0] debug_state_code,
    input  logic                          debug_image_valid,
    input  logic [                  31:0] debug_pc,
    input  logic [                  63:0] debug_cycle_count,
    input  logic [                   2:0] debug_fault_cause,
    input  logic [                  31:0] debug_fault_pc,
    output logic [                   4:0] debug_rf_addr,
    input  logic [                  31:0] debug_rf_data,
    input  logic                          debug_ifid_valid,
    input  logic [                  31:0] debug_ifid_pc,
    input  logic [                  31:0] debug_ifid_instruction,
    input  logic                          debug_ifid_fetch_fault_valid,
    input  logic [                   2:0] debug_ifid_fetch_fault_cause,
    input  logic                          debug_idex_valid,
    input  logic [                  31:0] debug_idex_pc,
    input  logic [                  31:0] debug_idex_instruction,
    input  logic [                   4:0] debug_idex_rs1,
    input  logic [                   4:0] debug_idex_rs2,
    input  logic [                   4:0] debug_idex_rd,
    input  logic [                  31:0] debug_idex_rs1_value,
    input  logic [                  31:0] debug_idex_rs2_value,
    input  logic [                  31:0] debug_idex_immediate,
    input  logic [                   5:0] debug_idex_alu_op,
    input  logic                          debug_idex_alu_src,
    input  logic [                   1:0] debug_idex_result_sel,
    input  logic [                   2:0] debug_idex_flow_op,
    input  logic [                   3:0] debug_idex_mem_op,
    input  logic                          debug_idex_reg_write,
    input  logic                          debug_exmem_valid,
    input  logic [                  31:0] debug_exmem_pc,
    input  logic [                  31:0] debug_exmem_instruction,
    input  logic [                   4:0] debug_exmem_rd,
    input  logic                          debug_exmem_reg_write,
    input  logic [                   3:0] debug_exmem_mem_op,
    input  logic [                  31:0] debug_exmem_ex_result,
    input  logic [                  31:0] debug_exmem_store_data,
    input  logic                          debug_memwb_valid,
    input  logic [                  31:0] debug_memwb_pc,
    input  logic [                  31:0] debug_memwb_instruction,
    input  logic [                   4:0] debug_memwb_rd,
    input  logic                          debug_memwb_reg_write,
    input  logic [                  31:0] debug_memwb_wb_value,
    output logic [BYTE_ADDRESS_WIDTH-1:0] debug_dmem_addr,
    input  logic [                   7:0] debug_dmem_data,
    input  logic                          debug_dmem_used
);
  import system_pkg::*;

  localparam logic [BYTE_ADDRESS_WIDTH-1:0] LAST_DMEM_ADDR =
      BYTE_ADDRESS_WIDTH'(DMEM_CAPACITY_BYTES - 1'b1);

  localparam logic [9:0] IDLE          = 10'b0000000001;
  localparam logic [9:0] COUNT_DMEM    = 10'b0000000010;
  localparam logic [9:0] PREPARE_FIXED = 10'b0000000100;
  localparam logic [9:0] ENQUEUE_FIXED = 10'b0000001000;
  localparam logic [9:0] PREPARE_COUNT = 10'b0000010000;
  localparam logic [9:0] ENQUEUE_COUNT = 10'b0000100000;
  localparam logic [9:0] SCAN_DMEM     = 10'b0001000000;
  localparam logic [9:0] PREPARE_ENTRY = 10'b0010000000;
  localparam logic [9:0] ENQUEUE_ENTRY = 10'b0100000000;
  localparam logic [9:0] WAIT_TX_DONE  = 10'b1000000000;

  (* fsm_encoding = "one_hot" *)logic [                   9:0] state;
  logic [                   9:0] next_state;
  logic [                  16:0] descriptor;
  logic [                   7:0] next_byte;
  logic [                   7:0] fixed_selected_byte;
  logic [                   6:0] rf_relative_index;
  logic [                  39:0] used_count_extended;
  logic [                  31:0] dmem_addr_extended;
  logic                          next_byte_available;
  logic [BYTE_ADDRESS_WIDTH-1:0] dmem_addr;
  logic [  USED_COUNT_WIDTH-1:0] used_count;
  logic [                   2:0] shared_byte_index;
  logic [  USED_COUNT_WIDTH-1:0] entry_count;
  logic [                   7:0] fixed_byte_index;
  logic [                   2:0] tx_pending;
  logic                          production_complete;
  logic                          response_init;
  logic                          byte_load;
  logic                          byte_consume;
  logic                          fixed_index_inc;
  logic                          dmem_addr_inc;
  logic                          used_count_inc;
  logic                          shared_index_inc;
  logic                          shared_index_clear;
  logic                          list_init;
  logic                          entry_count_inc;
  logic                          production_complete_set;
  logic                          tx_pending_inc;
  logic                          tx_pending_dec;
  logic                          write_accepted;

  function automatic logic [7:0] select_byte32(input logic [31:0] value,
                                               input logic [7:0] byte_index);
    select_byte32 = value[byte_index[1:0]*8+:8];
  endfunction

  function automatic logic [7:0] select_byte64(input logic [63:0] value,
                                               input logic [7:0] byte_index);
    select_byte64 = value[byte_index[2:0]*8+:8];
  endfunction

  always_ff @(posedge clk) begin
    if (reset) state <= IDLE;
    else state <= next_state;
  end

  always_ff @(posedge clk) begin
    if (reset) descriptor <= '0;
    else if (response_init) descriptor <= {response_opcode, response_result, response_with_debug};
  end

  always_ff @(posedge clk) begin
    if (reset || response_init) begin
      next_byte           <= '0;
      next_byte_available <= 1'b0;
    end else begin
      if (byte_load) begin
        next_byte           <= fixed_selected_byte;
        next_byte_available <= 1'b1;
      end
      if (byte_consume) next_byte_available <= 1'b0;
    end
  end

  always_ff @(posedge clk) begin
    if (reset || response_init) fixed_byte_index <= '0;
    else if (fixed_index_inc) fixed_byte_index <= fixed_byte_index + 1'b1;
  end

  always_ff @(posedge clk) begin
    if (reset || response_init) production_complete <= 1'b0;
    else if (production_complete_set) production_complete <= 1'b1;
  end

  always_ff @(posedge clk) begin
    if (reset || response_init) tx_pending <= '0;
    else if (tx_pending_inc && tx_pending_dec) tx_pending <= tx_pending;
    else if (tx_pending_inc) tx_pending <= tx_pending + 1'b1;
    else if (tx_pending_dec) tx_pending <= tx_pending - 1'b1;
  end

  always_ff @(posedge clk) begin
    if (reset || response_init) begin
      dmem_addr         <= '0;
      used_count        <= '0;
      shared_byte_index <= '0;
      entry_count       <= '0;
    end else if (list_init) begin
      dmem_addr         <= '0;
      shared_byte_index <= '0;
      entry_count       <= '0;
    end else begin
      if (dmem_addr_inc) dmem_addr <= dmem_addr + 1'b1;
      if (used_count_inc) used_count <= used_count + 1'b1;
      if (shared_index_clear) shared_byte_index <= '0;
      else if (shared_index_inc) shared_byte_index <= shared_byte_index + 1'b1;
      if (entry_count_inc) entry_count <= entry_count + 1'b1;
    end
  end

  always_comb begin
    next_state              = state;
    response_init           = 1'b0;
    byte_load               = 1'b0;
    byte_consume            = 1'b0;
    fixed_index_inc         = 1'b0;
    dmem_addr_inc           = 1'b0;
    used_count_inc          = 1'b0;
    shared_index_inc        = 1'b0;
    shared_index_clear      = 1'b0;
    list_init               = 1'b0;
    entry_count_inc         = 1'b0;
    production_complete_set = 1'b0;
    tx_pending_inc          = 1'b0;
    tx_pending_dec          = 1'b0;
    write_accepted          = 1'b0;
    wr_uart                 = 1'b0;
    w_data                  = next_byte;
    fixed_selected_byte     = '0;
    response_busy           = !reset && (state != IDLE);
    response_done_tick      = 1'b0;
    debug_rf_addr           = '0;
    debug_dmem_addr         = dmem_addr;
    used_count_extended     = {{(40 - USED_COUNT_WIDTH) {1'b0}}, used_count};
    dmem_addr_extended      = {{(32 - BYTE_ADDRESS_WIDTH) {1'b0}}, dmem_addr};
    rf_relative_index       = '0;

    if (!reset) begin
      if (descriptor[0] && fixed_byte_index >= 21 && fixed_byte_index <= 148) begin
        rf_relative_index = fixed_byte_index[6:0] - 7'd21;
        debug_rf_addr     = rf_relative_index[6:2];
      end

      if (fixed_byte_index == 0) fixed_selected_byte = descriptor[16:9];
      else if (fixed_byte_index == 1) fixed_selected_byte = descriptor[8:1];
      else if (fixed_byte_index == 2) fixed_selected_byte = debug_state_code;
      else if (fixed_byte_index == 3) fixed_selected_byte = {7'b0, debug_image_valid};
      else if (fixed_byte_index >= 4 && fixed_byte_index <= 7)
        fixed_selected_byte = select_byte32(debug_pc, fixed_byte_index - 8'd4);
      else if (fixed_byte_index >= 8 && fixed_byte_index <= 15)
        fixed_selected_byte = select_byte64(debug_cycle_count, fixed_byte_index - 8'd8);
      else if (fixed_byte_index == 16) fixed_selected_byte = {5'b0, debug_fault_cause};
      else if (fixed_byte_index >= 17 && fixed_byte_index <= 20)
        fixed_selected_byte = select_byte32(debug_fault_pc, fixed_byte_index - 8'd17);
      else if (fixed_byte_index >= 21 && fixed_byte_index <= 148)
        fixed_selected_byte = debug_rf_data[rf_relative_index[1:0]*8+:8];
      else if (fixed_byte_index == 149) fixed_selected_byte = {7'b0, debug_ifid_valid};
      else if (fixed_byte_index >= 150 && fixed_byte_index <= 153)
        fixed_selected_byte = select_byte32(debug_ifid_pc, fixed_byte_index - 8'd150);
      else if (fixed_byte_index >= 154 && fixed_byte_index <= 157)
        fixed_selected_byte = select_byte32(debug_ifid_instruction, fixed_byte_index - 8'd154);
      else if (fixed_byte_index == 158) fixed_selected_byte = {7'b0, debug_ifid_fetch_fault_valid};
      else if (fixed_byte_index == 159) fixed_selected_byte = {5'b0, debug_ifid_fetch_fault_cause};
      else if (fixed_byte_index == 160) fixed_selected_byte = {7'b0, debug_idex_valid};
      else if (fixed_byte_index >= 161 && fixed_byte_index <= 164)
        fixed_selected_byte = select_byte32(debug_idex_pc, fixed_byte_index - 8'd161);
      else if (fixed_byte_index >= 165 && fixed_byte_index <= 168)
        fixed_selected_byte = select_byte32(debug_idex_instruction, fixed_byte_index - 8'd165);
      else if (fixed_byte_index == 169) fixed_selected_byte = {3'b0, debug_idex_rs1};
      else if (fixed_byte_index == 170) fixed_selected_byte = {3'b0, debug_idex_rs2};
      else if (fixed_byte_index == 171) fixed_selected_byte = {3'b0, debug_idex_rd};
      else if (fixed_byte_index >= 172 && fixed_byte_index <= 175)
        fixed_selected_byte = select_byte32(debug_idex_rs1_value, fixed_byte_index - 8'd172);
      else if (fixed_byte_index >= 176 && fixed_byte_index <= 179)
        fixed_selected_byte = select_byte32(debug_idex_rs2_value, fixed_byte_index - 8'd176);
      else if (fixed_byte_index >= 180 && fixed_byte_index <= 183)
        fixed_selected_byte = select_byte32(debug_idex_immediate, fixed_byte_index - 8'd180);
      else if (fixed_byte_index == 184) fixed_selected_byte = {2'b0, debug_idex_alu_op};
      else if (fixed_byte_index == 185) fixed_selected_byte = {7'b0, debug_idex_alu_src};
      else if (fixed_byte_index == 186) fixed_selected_byte = {6'b0, debug_idex_result_sel};
      else if (fixed_byte_index == 187) fixed_selected_byte = {5'b0, debug_idex_flow_op};
      else if (fixed_byte_index == 188) fixed_selected_byte = {4'b0, debug_idex_mem_op};
      else if (fixed_byte_index == 189) fixed_selected_byte = {7'b0, debug_idex_reg_write};
      else if (fixed_byte_index == 190) fixed_selected_byte = {7'b0, debug_exmem_valid};
      else if (fixed_byte_index >= 191 && fixed_byte_index <= 194)
        fixed_selected_byte = select_byte32(debug_exmem_pc, fixed_byte_index - 8'd191);
      else if (fixed_byte_index >= 195 && fixed_byte_index <= 198)
        fixed_selected_byte = select_byte32(debug_exmem_instruction, fixed_byte_index - 8'd195);
      else if (fixed_byte_index == 199) fixed_selected_byte = {3'b0, debug_exmem_rd};
      else if (fixed_byte_index == 200) fixed_selected_byte = {7'b0, debug_exmem_reg_write};
      else if (fixed_byte_index == 201) fixed_selected_byte = {4'b0, debug_exmem_mem_op};
      else if (fixed_byte_index >= 202 && fixed_byte_index <= 205)
        fixed_selected_byte = select_byte32(debug_exmem_ex_result, fixed_byte_index - 8'd202);
      else if (fixed_byte_index >= 206 && fixed_byte_index <= 209)
        fixed_selected_byte = select_byte32(debug_exmem_store_data, fixed_byte_index - 8'd206);
      else if (fixed_byte_index == 210) fixed_selected_byte = {7'b0, debug_memwb_valid};
      else if (fixed_byte_index >= 211 && fixed_byte_index <= 214)
        fixed_selected_byte = select_byte32(debug_memwb_pc, fixed_byte_index - 8'd211);
      else if (fixed_byte_index >= 215 && fixed_byte_index <= 218)
        fixed_selected_byte = select_byte32(debug_memwb_instruction, fixed_byte_index - 8'd215);
      else if (fixed_byte_index == 219) fixed_selected_byte = {3'b0, debug_memwb_rd};
      else if (fixed_byte_index == 220) fixed_selected_byte = {7'b0, debug_memwb_reg_write};
      else if (fixed_byte_index >= 221 && fixed_byte_index <= 224)
        fixed_selected_byte = select_byte32(debug_memwb_wb_value, fixed_byte_index - 8'd221);

      if (state == PREPARE_COUNT) fixed_selected_byte = used_count_extended[shared_byte_index*8+:8];
      else if (state == PREPARE_ENTRY) begin
        if (shared_byte_index == 4) fixed_selected_byte = debug_dmem_data;
        else fixed_selected_byte = dmem_addr_extended[shared_byte_index*8+:8];
      end

      case (state)
        IDLE: begin
          if (response_start) begin
            response_init = 1'b1;
            if (response_with_debug) next_state = COUNT_DMEM;
            else next_state = PREPARE_FIXED;
          end
        end
        PREPARE_FIXED: begin
          byte_load  = 1'b1;
          next_state = ENQUEUE_FIXED;
        end
        ENQUEUE_FIXED: begin
          wr_uart        = next_byte_available && !tx_full;
          write_accepted = wr_uart && !tx_full;
          if (write_accepted) begin
            byte_consume = 1'b1;
            if (fixed_byte_index == 1 && !descriptor[0]) begin
              production_complete_set = 1'b1;
              next_state              = WAIT_TX_DONE;
            end else if (fixed_byte_index == 224 && descriptor[0]) begin
              shared_index_clear = 1'b1;
              next_state         = PREPARE_COUNT;
            end else begin
              fixed_index_inc = 1'b1;
              next_state      = PREPARE_FIXED;
            end
          end
        end
        WAIT_TX_DONE: begin
          if (production_complete && tx_pending == 1 && tx_done_tick) begin
            tx_pending_dec     = 1'b1;
            response_done_tick = 1'b1;
            next_state         = IDLE;
          end
        end
        COUNT_DMEM: begin
          if (debug_dmem_used) used_count_inc = 1'b1;
          if (dmem_addr == LAST_DMEM_ADDR) next_state = PREPARE_FIXED;
          else dmem_addr_inc = 1'b1;
        end
        PREPARE_COUNT: begin
          byte_load  = 1'b1;
          next_state = ENQUEUE_COUNT;
        end
        ENQUEUE_COUNT: begin
          wr_uart        = next_byte_available && !tx_full;
          write_accepted = wr_uart && !tx_full;
          if (write_accepted) begin
            byte_consume = 1'b1;
            if (shared_byte_index == 4) begin
              if (used_count == 0) begin
                production_complete_set = 1'b1;
                next_state              = WAIT_TX_DONE;
              end else begin
                list_init  = 1'b1;
                next_state = SCAN_DMEM;
              end
            end else begin
              shared_index_inc = 1'b1;
              next_state       = PREPARE_COUNT;
            end
          end
        end
        SCAN_DMEM: begin
          if (debug_dmem_used) next_state = PREPARE_ENTRY;
          else if (dmem_addr != LAST_DMEM_ADDR) dmem_addr_inc = 1'b1;
        end
        PREPARE_ENTRY: begin
          byte_load  = 1'b1;
          next_state = ENQUEUE_ENTRY;
        end
        ENQUEUE_ENTRY: begin
          wr_uart        = next_byte_available && !tx_full;
          write_accepted = wr_uart && !tx_full;
          if (write_accepted) begin
            byte_consume = 1'b1;
            if (shared_byte_index < 4) begin
              shared_index_inc = 1'b1;
              next_state       = PREPARE_ENTRY;
            end else begin
              entry_count_inc = 1'b1;
              if (entry_count + 1'b1 == used_count) begin
                production_complete_set = 1'b1;
                next_state              = WAIT_TX_DONE;
              end else begin
                dmem_addr_inc      = 1'b1;
                shared_index_clear = 1'b1;
                next_state         = SCAN_DMEM;
              end
            end
          end
        end
        default: begin
          // Reserved for illegal states.
        end
      endcase

      if (write_accepted) tx_pending_inc = 1'b1;
      if (tx_done_tick && tx_pending != 0) tx_pending_dec = 1'b1;
    end
  end
endmodule
